"""Landform operators: what stream power alone does not make, one per rock type (geology.LITHO[...]["op"]).

Each operator gets the context `c` (height c.h being built, the original c.h0, coordinates, drainage, water) and a soft
weight `w` (0–1) of where its rock is, and blends its result in by w. Parameters come from geology.json
"operators" → {op name: {key: value}} and fall back to the defaults below (丈). Dimensions are real-world ones scaled
about ×1.5 (the map is a 仙侠 diorama: everything a little taller and sheerer than life, nothing physically absurd).

Features thinner than ~2 grid cells (80 丈) cannot live in a 40-丈 heightfield; they are emitted as rock instances
(c.rocks) that the engine draws as meshes standing on a low plinth — the same split real games use (heightmap for the
ground, a rock kit for towers, pillars and stacks).
"""
import math

import numpy as np

from . import noise
from .fields import box_blur, local_base, max_filter, nearest_source, rotate, slope, smoothstep

ROCK_KINDS = ["karst_tower", "sandstone_pillar", "stone_blade", "sea_stack", "granite_spire", "basalt_column", "danxia_butte"]
ROCK = {k: i for i, k in enumerate(ROCK_KINDS)}

DEFAULTS = {
    "karst": {"base_r": 1200, "t0": 40, "t1": 120, "cone_spacing": 210, "cone_h": 150, "cone_p": 1.35, "cone_q": 1.7,
              "tower_spacing": 300, "tower_keep": 0.42, "tower_h": [20, 70], "tower_r": [22, 55], "plinth": 0.22,
              "strike": 25},
    "danxia": {"base_r": 1500, "bed": 55, "cliff": 0.28, "joint": 430, "joint_w": 42, "joint_depth": 0.75, "strike": -20,
               "butte_keep": 0.18},
    "pillars": {"base_r": 1300, "major": [520, 640], "minor": [78, 92], "angle": 12, "trunk_area": 250,
                "stage_near": 300, "stage_far": 2600, "floor": 0.16, "r": [11, 30], "max_h": 200, "max_rocks": 60000},
    "granite": {"cell": 270, "sharpen": 0.55, "dome": 0.25, "spire_keep": 0.12, "spire_h": [30, 95]},
    "loess": {"table_r": 2000, "table_q": 0.62, "flat": 0.18, "a0": 60, "depth": 24, "depth_max": 130, "width": 38,
              "width_max": 300},
    "volcanic": {"field_spacing": 950, "field_keep": 0.22, "cone_r": [70, 150], "cone_h": [30, 85], "crater": 0.28},
    "alluvial": {"fan_area": 2500, "fan_slope": 0.035, "fan_r": [600, 2600], "fan_max": 18, "terraces": [260, 820, 1700],
                 "riser": 4.0, "swell": 6.0},
    "wetland": {"base_r": 900, "lift": 0.6},
    "fold": {},
    "glacial": {"ela": 650, "tongue": 320, "ice_area": 80, "deepen": 45, "width": 10.0, "width_max": 360, "lower_max": 120},
    "coast": {"stack_spacing": 140, "stack_keep": 0.35, "stack_h": [20, 70], "stack_r": [10, 26], "reach": 160},
}


class Ctx:
    def __init__(self, world, h, h0, area, wet, sd, ids, plan_g, seed):
        self.world = world
        self.h = h; self.h0 = h0; self.area = area; self.wet = wet; self.sd = sd; self.ids = ids
        self.X, self.Z = world.xz
        self.cell = world.cell
        self.seed = seed
        self.params = plan_g.get("operators", {})
        self.rocks = []                                  # [x, y0, z, r, h, kind, yaw, var]
        self.layers = {}                                 # named extra rasters (redness, strata, sinks…)

    def p(self, op):
        q = dict(DEFAULTS[op]); q.update(self.params.get(op, {}))
        return q

    def ground(self, x, z):
        i = np.clip(np.round((x - self.world.x0) / self.cell).astype(int), 0, self.world.W - 1)
        j = np.clip(np.round((z - self.world.z0) / self.cell).astype(int), 0, self.world.H - 1)
        return self.h[j, i]

    def add_rocks(self, x, z, r, hgt, kind, seed):
        if len(x) == 0:
            return
        y0 = self.ground(x, z)
        yaw = noise.cell_hash(np.round(x).astype(np.int64), np.round(z).astype(np.int64), seed) * 2 * math.pi
        var = noise.cell_hash(np.round(x).astype(np.int64), np.round(z).astype(np.int64), seed + 1)
        k = np.full(len(x), ROCK[kind], np.float32)
        self.rocks.append(np.stack([x, y0, z, r, hgt, k, yaw, var], 1).astype(np.float32))


def _bbox(w, pad):
    """Row/col slices covering w > 0 plus a pad (cells), or None."""
    on = w > 0.001
    if not on.any():
        return None
    rows = np.where(on.any(1))[0]; cols = np.where(on.any(0))[0]
    H, W = w.shape
    return (slice(max(0, rows[0] - pad), min(H, rows[-1] + pad + 1)), slice(max(0, cols[0] - pad), min(W, cols[-1] + pad + 1)))


def _profile(t, p, q):
    """(1 − t^p)^q on t ∈ [0,1]: p small → cone, p large → flat-topped tower; q > 1 flares the foot."""
    t = np.clip(t, 0, 1)
    return (1 - t ** p) ** q


# ---- karst ---------------------------------------------------------------------------------------------------------
def karst(c, w):
    """South-China karst. Height above the local water table decides the form (Guilin–Yangshuo): well above it, 峰丛
    (fengcong) — cones on a shared rock base with closed dolines between them; near it, 峰林 (fenglin) — isolated
    towers rising from a flat alluvial plain, which is the water-table level itself."""
    P = c.p("karst")
    bb = _bbox(w, 40)
    if bb is None:
        return
    h = c.h[bb]; X = c.X[bb]; Z = c.Z[bb]; ww = w[bb]
    env = box_blur(h, 5)                                           # the massif keeps its ridges and valleys (> 400 丈)
    B = local_base(h, int(P["base_r"] / c.cell))
    hb = box_blur(np.maximum(env - B, 0), 8)
    cong = smoothstep(P["t0"], P["t1"], hb)                       # 0 → fenglin plain, 1 → fengcong upland
    u, v = rotate(X, Z, P["strike"])
    # fengcong: a cone per Voronoi cell riding on the massif; where three cones meet, a closed doline
    s = P["cone_spacing"]
    f1, f2, cid, px, pz = noise.worley(u / s, v / s, 0.85, c.seed + 401)
    A = c.area.reshape(c.h.shape)[bb] / (c.cell * c.cell)
    valley = smoothstep(math.log(60), math.log(900), np.log(np.maximum(box_blur(A, 1), 1)))   # 槽谷: karst valleys
    cluster = 0.45 + 0.55 * smoothstep(-0.35, 0.35, noise.fbm(X / 2600 + 2.2, Z / 2600 - 5.1, 3, c.seed + 403))
    ch = np.minimum(hb * 0.45, P["cone_h"]) * (0.7 + 0.6 * cid) * cluster * (1 - 0.85 * valley)
    doline = smoothstep(0.08, 0.0, f2 - f1) * ch * 0.25
    hcong = env + ch * (_profile(f1 / 0.62, P["cone_p"], P["cone_q"]) - 0.45) - doline
    # fenglin: the plain at the water table, towers in a sparse subset of cells
    st = P["tower_spacing"]
    g1, g2, gid, gx, gz = noise.worley(u / st + 31.7, v / st - 12.4, 0.9, c.seed + 409)
    keep = gid < P["tower_keep"] * (1 - 0.5 * cong)
    th = P["tower_h"][0] + (P["tower_h"][1] - P["tower_h"][0]) * noise.cell_hash(np.round(gx * 97).astype(np.int64), np.round(gz * 97).astype(np.int64), 3)
    tr = (P["tower_r"][0] + (P["tower_r"][1] - P["tower_r"][0]) * gid / max(P["tower_keep"], 1e-3)) / st
    plain = B + 1.5 * noise.fbm(X / 900, Z / 900, 2, c.seed + 5)
    plinth = np.where(keep, th * P["plinth"] * _profile(g1 / (tr * 1.9), 1.2, 1.5), 0)
    hlin = plain + plinth
    hk = hlin * (1 - cong) + hcong * cong
    c.h[bb] = h * (1 - ww) + hk * ww
    # the towers themselves as rock instances (one per kept cell centre, where the plain dominates)
    cx = (gx * st); cz = (gz * st)
    sel = keep & (g1 < 0.06) & (ww > 0.5) & (cong < 0.6) & ~c.wet[bb]
    if sel.any():
        _, first = np.unique(np.round(cx[sel] * 7 + cz[sel] * 13).astype(np.int64), return_index=True)
        uu = cx[sel][first]; vv = cz[sel][first]
        ang = math.radians(P["strike"])
        x = uu * math.cos(ang) - vv * math.sin(ang); z = uu * math.sin(ang) + vv * math.cos(ang)
        c.add_rocks(x, z, (tr[sel][first] * st), th[sel][first] * (1 - 0.6 * cong[sel][first]), "karst_tower", c.seed + 411)
    c.layers.setdefault("karst_form", np.zeros_like(c.h))[bb] = np.where(ww > 0, 1 + cong, c.layers.get("karst_form", np.zeros_like(c.h))[bb])


# ---- danxia --------------------------------------------------------------------------------------------------------
def danxia(c, w):
    """Red-bed Danxia (丹霞): horizontal continental sandstone/conglomerate, cut by vertical joints. '顶平、身陡、麓缓' —
    flat caprock tops, sheer red walls, gentle talus feet. Bedding → stepped mesas; joints → 巷谷 / 一线天 slots that
    split mesas into 石堡, 石墙 and 石柱 (stage rises toward the big rivers); isolated buttes become rock instances."""
    P = c.p("danxia")
    bb = _bbox(w, 40)
    if bb is None:
        return
    h = c.h[bb]; X = c.X[bb]; Z = c.Z[bb]; ww = w[bb]
    B = local_base(h, int(P["base_r"] / c.cell))
    rel = np.maximum(box_blur(h, 2) - B, 0)
    T = P["bed"] * (1 + 0.25 * noise.fbm(X / 5000 + 3, Z / 5000 - 1, 2, c.seed + 501))
    q = rel / T
    f = q - np.floor(q)
    riser = smoothstep(1 - P["cliff"], 1.0, f)                    # a wall at the top of every bed, a flat tread below it
    stepped = B + (np.floor(q) + riser) * T
    foot = smoothstep(0.0, 1.2, q)                                 # the lowest bed keeps its gentle apron
    hd = B + rel * (1 - foot) + (stepped - B) * foot
    # two joint sets, wandering and broken into lengths so slots end inside the mesas
    u0, v0 = rotate(X, Z, P["strike"])
    u = u0 + 0.4 * P["joint"] * noise.fbm(u0 / 1300 + 2.3, v0 / 1300, 2, c.seed + 513)
    v = v0 + 0.4 * P["joint"] * noise.fbm(u0 / 1300 - 6.1, v0 / 1300 + 1.4, 2, c.seed + 515)
    J, Wj = P["joint"], P["joint_w"]
    du = np.abs((u / J) - np.round(u / J)) * J
    dv = np.abs((v / (J * 1.3)) - np.round(v / (J * 1.3))) * J * 1.3
    gate_u = noise.fbm(v / 1100 + 7, np.round(u / J) * 3.1, 2, c.seed + 503) > -0.15
    gate_v = noise.fbm(u / 1100 - 2, np.round(v / (J * 1.3)) * 2.3, 2, c.seed + 507) > 0.05
    slot = np.maximum(smoothstep(Wj, Wj * 0.35, du) * gate_u, smoothstep(Wj, Wj * 0.35, dv) * gate_v)
    hd = hd - slot * np.maximum(hd - B, 0) * P["joint_depth"] * smoothstep(0.8, 2.0, q)
    c.h[bb] = h * (1 - ww) + hd * ww
    red = c.layers.setdefault("redness", np.zeros_like(c.h))
    red[bb] = np.maximum(red[bb], ww * smoothstep(0.3, 1.0, q))
    # isolated buttes (石柱) where joints of both sets cross near the bed tops
    s = J
    g1, g2, gid, gx, gz = noise.worley(u / s + 5.5, v / s - 3.3, 0.8, c.seed + 509)
    sel = (gid < P["butte_keep"]) & (g1 < 0.05) & (q > 1.5) & (ww > 0.6)
    if sel.any():
        _, first = np.unique(np.round(gx[sel] * 11 + gz[sel] * 17).astype(np.int64), return_index=True)
        uu, vv = gx[sel][first] * s, gz[sel][first] * s
        ang = math.radians(P["strike"])
        x = uu * math.cos(ang) - vv * math.sin(ang); z = uu * math.sin(ang) + vv * math.cos(ang)
        c.add_rocks(x, z, np.full(len(x), 28.0), np.minimum(rel[sel][first] * 0.8, 160), "danxia_butte", c.seed + 511)


# ---- quartz-sandstone pillar forest ---------------------------------------------------------------------------------
def pillars(c, w):
    """Wulingyuan (张家界) quartz-sandstone peak forest: thick horizontal beds and two near-vertical joint sets. Erosion
    widens the joints in stages — plateau (台地) → walls (方山 / 石墙) → pillars (峰林 / 石柱) → stumps (残林) — fastest
    next to the big streams (headward erosion), so the stage grows toward the trunk valleys. Two scales: the major
    joints (~500 丈 apart) are deep gorges in the heightfield (金鞭溪-like); the minor joints (~80 丈) split the blocks
    into pillars 10–30 丈 across, which only meshes can show — they become rock instances on a talus plinth."""
    P = c.p("pillars")
    bb = _bbox(w, 30)
    if bb is None:
        return
    h = c.h[bb]; X = c.X[bb]; Z = c.Z[bb]; ww = w[bb]
    A = c.area.reshape(c.h.shape)[bb] / (c.cell * c.cell)
    B = local_base(h, int(P["base_r"] / c.cell))
    top = box_blur(max_filter(h, 5), 5)                            # the bedding top the plateau keeps
    floor = B + (top - B) * P["floor"]
    dch, _ = nearest_source(A > P["trunk_area"], c.cell)
    stage = 3.0 * smoothstep(P["stage_far"], P["stage_near"], dch + 500 * noise.fbm(X / 2400, Z / 2400, 2, c.seed + 601))
    stage = stage * smoothstep(40, 160, top - B)                   # no peak forest without relief to cut
    u0, v0 = rotate(X, Z, P["angle"])
    Jx, Jz = P["major"]
    # real joint sets wander, change spacing and die out: warp the joint frame and gate each joint along its length
    u = u0 + 0.22 * Jx * noise.fbm(u0 / 2200 + 1.7, v0 / 2200, 2, c.seed + 603)
    v = v0 + 0.22 * Jz * noise.fbm(u0 / 2200 - 4.1, v0 / 2200 + 2.2, 2, c.seed + 605)
    fu = np.abs(u / Jx - np.round(u / Jx)) * 2                     # 0 on a major joint, 1 mid-block
    fv = np.abs(v / Jz - np.round(v / Jz)) * 2
    gate_u = noise.fbm(v0 / 900 + np.round(u / Jx) * 3.7, 0.5, 1, c.seed + 607) > -0.2
    gate_v = noise.fbm(u0 / 900 + np.round(v / Jz) * 2.9, 1.5, 1, c.seed + 609) > -0.05
    wg = smoothstep(0.2, 1.2, stage) * 0.16 + smoothstep(1.2, 2.6, stage) * 0.22
    gorge = np.maximum(smoothstep(wg + 0.02, wg - 0.04, fu) * gate_u, smoothstep(wg * 0.8 + 0.02, wg * 0.8 - 0.04, fv) * gate_v) * (stage > 0.15)
    pill = smoothstep(1.6, 2.0, stage)                             # blocks broken into pillars
    stump = smoothstep(2.4, 3.0, stage)
    bid = noise.cell_hash(np.round(u / Jx).astype(np.int64), np.round(v / Jz).astype(np.int64), c.seed + 3)
    block = top - 15 * bid - stump * (top - floor) * 0.6
    level = block * (1 - pill) + (floor + (block - floor) * 0.14) * pill
    hp = level * (1 - gorge) + floor * gorge
    c.h[bb] = h * (1 - ww) + hp * ww
    c.layers.setdefault("pillar_stage", np.zeros_like(c.h))[bb] = np.where(ww > 0.3, stage, 0)
    # the pillars: one per minor-joint block inside the broken blocks, sampled on a lattice in joint coordinates
    jx, jz = P["minor"]
    um = np.arange(u.min(), u.max(), jx); vm = np.arange(v.min(), v.max(), jz)
    U_, V_ = np.meshgrid(um + jx / 2, vm + jz / 2)
    ang = math.radians(P["angle"])
    x = U_ * math.cos(ang) - V_ * math.sin(ang); z = U_ * math.sin(ang) + V_ * math.cos(ang)
    x, z = x.ravel(), z.ravel()
    jitter = noise.cell_hash(np.round(x).astype(np.int64), np.round(z).astype(np.int64), c.seed + 21) - 0.5
    x = x + jitter * jx * 0.35; z = z - jitter * jz * 0.3
    i = np.clip(np.round((x - c.X[bb][0, 0]) / c.cell).astype(int), 0, h.shape[1] - 1)
    j = np.clip(np.round((z - c.Z[bb][0, 0]) / c.cell).astype(int), 0, h.shape[0] - 1)
    st = c.layers["pillar_stage"][bb][j, i]
    sel = (pill[j, i] > 0.5) & (ww[j, i] > 0.5) & (gorge[j, i] < 0.3) & ~c.wet[bb][j, i]
    sel &= noise.cell_hash(np.round(x).astype(np.int64), np.round(z).astype(np.int64), c.seed + 23) > 0.18 + 0.4 * smoothstep(2.4, 3.0, st)
    if sel.any():
        ht = (block[j, i] - floor[j, i])[sel] * (0.55 + 0.45 * noise.cell_hash(np.round(x[sel]).astype(np.int64), 7, c.seed + 25))
        ht = np.minimum(ht, P["max_h"])
        r = P["r"][0] + (P["r"][1] - P["r"][0]) * noise.cell_hash(np.round(z[sel]).astype(np.int64), 9, c.seed + 27)
        keep = ht > 25
        idx = np.nonzero(keep)[0][: P["max_rocks"]]
        c.add_rocks(x[sel][idx], z[sel][idx], r[idx], ht[idx], "sandstone_pillar", c.seed + 611)


# ---- granite -------------------------------------------------------------------------------------------------------
def granite(c, w):
    """Huangshan / Huashan granite: a resistant batholith (low K, so it already stands highest) whose crests are cut by
    widely spaced joints into spires, with smooth exfoliation domes between. Sharpen the crests, dome some joint
    blocks, and stand the thinnest spires up as rock instances (迎仙松-type crags carry the pines)."""
    P = c.p("granite")
    bb = _bbox(w, 30)
    if bb is None:
        return
    h = c.h[bb]; X = c.X[bb]; Z = c.Z[bb]; ww = w[bb]
    hi = h - box_blur(h, 5)
    crest = smoothstep(0, 1, (h - box_blur(h, 25)) / 120)
    hg = h + P["sharpen"] * hi * (0.4 + crest)
    s = P["cell"]
    f1, f2, cid, px, pz = noise.worley(X / s, Z / s, 0.9, c.seed + 701)
    joint = smoothstep(0.1, 0.0, f2 - f1)                          # joint traces between blocks
    hg = hg - joint * crest * 26
    dome = (cid < P["dome"]) & (crest > 0.3)
    dome_h = np.sqrt(np.clip(1 - (f1 / 0.55) ** 2, 0, 1))
    hg = np.where(dome, np.maximum(hg, box_blur(h, 4) + 18 * dome_h * crest), hg)
    c.h[bb] = h * (1 - ww) + hg * ww
    sel = (cid > 1 - P["spire_keep"]) & (f1 < 0.05) & (crest > 0.55) & (ww > 0.5)
    if sel.any():
        _, first = np.unique(np.round(px[sel] * 13 + pz[sel] * 7).astype(np.int64), return_index=True)
        x, z = px[sel][first] * s, pz[sel][first] * s
        ht = P["spire_h"][0] + (P["spire_h"][1] - P["spire_h"][0]) * cid[sel][first] ** 3
        c.add_rocks(x, z, np.full(len(x), 16.0), ht, "granite_spire", c.seed + 711)


# ---- loess ---------------------------------------------------------------------------------------------------------
def loess(c, w):
    """Loess plateau (黄土高原): wind-laid silt over older relief. Tops are levelled into 塬 (tablelands); dense dendritic
    gullies with near-vertical walls (loess stands in vertical joints) cut them into 梁 (ridges) and 峁 (domes) as
    the gully density grows."""
    P = c.p("loess")
    bb = _bbox(w, 30)
    if bb is None:
        return
    h = c.h[bb]; ww = w[bb]
    A = c.area.reshape(c.h.shape)[bb] / (c.cell * c.cell)
    r = int(P["table_r"] / c.cell)
    big = box_blur(h, r)
    T = big + (box_blur(max_filter(h, r // 2), r // 2) - big) * P["table_q"]
    hl = np.where(h > T, T + (h - T) * P["flat"], h)
    chan = A > P["a0"]
    d, src = nearest_source(chan, c.cell)
    a_src = A.ravel()[np.maximum(src, 0)].reshape(A.shape)
    wid = np.minimum(P["width"] * (a_src / P["a0"]) ** 0.3, P["width_max"])
    dep = np.minimum(P["depth"] * np.log(np.maximum(a_src / P["a0"], 1)) ** 0.8, P["depth_max"])
    fl = hl.ravel()[np.maximum(src, 0)].reshape(A.shape) - dep
    wall = np.clip(d / np.maximum(wid, 1), 0, 1) ** 0.35           # steep walls, narrow floor
    carved = fl + (hl - fl) * wall
    hl = np.where((src >= 0) & (d < wid), np.minimum(hl, carved), hl)
    c.h[bb] = h * (1 - ww) + hl * ww


# ---- volcanic ------------------------------------------------------------------------------------------------------
def volcanic(c, w, volcanoes=()):
    """Volcanic ground: the named volcanoes of geology.json (strato cones with a summit crater, calderas with a lake
    floor) plus a scattered cinder-cone field on the rest of the volcanic rock (the 地火 country a refining sect wants)."""
    P = c.p("volcanic")
    bb = _bbox(w, 40)
    if bb is not None:
        h = c.h[bb]; X = c.X[bb]; Z = c.Z[bb]; ww = w[bb]
        s = P["field_spacing"]
        f1, f2, cid, px, pz = noise.worley(X / s, Z / s, 0.9, c.seed + 801)
        keep = cid < P["field_keep"]
        r = (P["cone_r"][0] + (P["cone_r"][1] - P["cone_r"][0]) * cid / P["field_keep"]) / s
        ch = P["cone_h"][0] + (P["cone_h"][1] - P["cone_h"][0]) * noise.cell_hash(np.round(px * 31).astype(np.int64), np.round(pz * 31).astype(np.int64), 5)
        t = f1 / r
        cone = ch * (_profile(t, 1.0, 1.4) - 0.6 * smoothstep(P["crater"] + 0.08, 0.0, t))
        c.h[bb] = h + np.where(keep & (t < 1), cone, 0) * ww
    X, Z = c.X, c.Z
    for v in volcanoes:
        d = np.hypot(X - v["x"], Z - v["z"])
        R = v["r"]
        m = d < R * 1.3
        if not m.any():
            continue
        t = d[m] / R
        g = c.h[m]
        kind = v.get("kind", "strato")
        if kind == "caldera":
            # an old eroded rim: wandering radius, uneven crest, breached wherever a big stream leaves the basin
            ang = np.arctan2(Z[m] - v["z"], X[m] - v["x"])
            wob = 0.1 * noise.fbm(np.cos(ang) * 2.2 + 5.0, np.sin(ang) * 2.2, 3, c.seed + 811)
            t = t / (1 + wob)
            crest = 0.65 + 0.35 * noise.fbm(np.cos(ang) * 3.1, np.sin(ang) * 3.1 - 2.0, 2, c.seed + 813)
            A = c.area.reshape(c.h.shape)[m] / (c.cell * c.cell)
            breach = smoothstep(math.log(40), math.log(600), np.log(np.maximum(A, 1)))
            rim = v["h"] * crest * np.exp(-((t - 0.8) / 0.13) ** 2) * (1 - 0.9 * breach) * smoothstep(30, 140, g)   # rims stand on high ground
            if "open" in v:                                        # [azimuth°, half-width°]: a sector the rim stays out of
                bearing = np.degrees(np.arctan2(X[m] - v["x"], -(Z[m] - v["z"])))          # clockwise from north
                off = np.abs((bearing - v["open"][0] + 540) % 360 - 180)
                rim = rim * smoothstep(v["open"][1] * 0.6, v["open"][1], off)
            floor = v.get("floor", 0.25) * v["h"] * smoothstep(0.75, 0.45, t)
            new = np.where(t < 0.68, np.minimum(g, floor + 0.2 * rim + 0.3 * g), np.maximum(g, g * 0.55 + rim))
        else:                                                      # stratovolcano: concave flanks, a summit crater
            prof = np.exp(-3.2 * t) * (1 - smoothstep(0.9, 1.3, t))
            crater = v.get("crater", 0.08)
            cone = v["h"] * prof - v["h"] * 0.12 * smoothstep(crater, 0, t)
            k = v.get("blend", 0.75) * smoothstep(1.25, 0.6, t)
            new = g * (1 - k) + np.maximum(cone, g * 0.25) * k
        c.h[m] = new


# ---- alluvial plains ------------------------------------------------------------------------------------------------
def alluvial(c, w):
    """Plains are not flat: alluvial fans spread where mountain streams leave the range (the cone apex at the canyon
    mouth, 2–4 % slope), the great rivers are flanked by stepped terraces, and a low swell rolls between them."""
    P = c.p("alluvial")
    bb = _bbox(w, 60)
    if bb is None:
        return
    H, W = c.h.shape
    A = c.area.reshape(H, W) / (c.cell * c.cell)
    mountain = (c.ids != 0) & (c.ids != 8) & (c.h > 30)
    front = max_filter(mountain.astype(np.float64), 2) > 0
    mouth = front & ~mountain & (A > P["fan_area"]) & (w > 0.5) & ~c.wet
    js, is_ = np.nonzero(mouth)
    order = np.argsort(-A[js, is_])
    taken = []
    fan = np.zeros_like(c.h)
    for k in order[:400]:
        x, z = c.X[js[k], is_[k]], c.Z[js[k], is_[k]]
        if any((x - a) ** 2 + (z - b) ** 2 < 1500 ** 2 for a, b in taken):
            continue
        taken.append((x, z))
        R = min(max(P["fan_r"][0], 30 * math.sqrt(A[js[k], is_[k]])), P["fan_r"][1])
        r = int(R / c.cell) + 1
        j0, j1, i0, i1 = max(0, js[k] - r), min(H, js[k] + r + 1), max(0, is_[k] - r), min(W, is_[k] + r + 1)
        d = np.hypot(c.X[j0:j1, i0:i1] - x, c.Z[j0:j1, i0:i1] - z)
        # the fan opens away from the mountains: direction from the nearest uphill mass
        up = np.unravel_index(np.argmax(np.where(mountain[j0:j1, i0:i1], c.h[j0:j1, i0:i1], -1)), d.shape)
        dx, dz = x - c.X[j0 + up[0], i0 + up[1]], z - c.Z[j0 + up[0], i0 + up[1]]
        n = math.hypot(dx, dz) or 1
        cosang = ((c.X[j0:j1, i0:i1] - x) * dx + (c.Z[j0:j1, i0:i1] - z) * dz) / (np.maximum(d, 1) * n)
        sector = smoothstep(-0.2, 0.45, cosang)
        apex = min(P["fan_max"], P["fan_slope"] * R * 0.5)
        cone = apex * np.clip(1 - d / R, 0, 1) ** 1.6 * sector
        fan[j0:j1, i0:i1] = np.maximum(fan[j0:j1, i0:i1], cone)
    # terraces along the rivers: steps at fixed distances from the water
    dw = np.maximum(-c.sd, 0)
    ter = sum(P["riser"] * smoothstep(t - 40, t + 40, dw) for t in P["terraces"])
    swell = P["swell"] * (0.5 + 0.5 * noise.fbm(c.X / 4200, c.Z / 4200, 3, c.seed + 901)) * smoothstep(300, 2500, dw)
    lift = (fan + ter + swell) * w * ~c.wet
    c.h += lift


def wetland(c, w):
    """Lacustrine / swamp basins (a fault-bounded graben, 绿踪沼泽): flatten to the basin floor, a hand's breadth above
    the water, with low islands of reeds."""
    P = c.p("wetland")
    bb = _bbox(w, 20)
    if bb is None:
        return
    h = c.h[bb]; ww = w[bb]
    B = local_base(h, int(P["base_r"] / c.cell))
    hm = B + P["lift"] * (1 + noise.fbm(c.X[bb] / 300, c.Z[bb] / 300, 2, c.seed + 951))
    c.h[bb] = h * (1 - ww) + np.minimum(h, hm) * ww


def fold(c, w):
    """Fold belts are made by the erosion itself (geology.Plan.fold_K: hard and soft beds → strike ridges, hogbacks,
    trellis drainage); nothing to add here."""


# ---- glacial (global, by altitude) ----------------------------------------------------------------------------------
def glacial(c, rec, stack, ela=None):
    """Pleistocene glaciers above the (palaeo) snow line: valleys the ice filled are widened to a U and over-deepened;
    their heads become cirques. Tributary valleys left hanging above the trunk floor are where 飞瀑 fall."""
    P = c.p("glacial")
    ela = ela or P["ela"]
    H, W = c.h.shape
    A = c.area.reshape(H, W) / (c.cell * c.cell)
    ice_src = (c.h > ela)
    if not ice_src.any():
        return
    # ice flows down the drainage from its sources until it melts `tongue` 丈 below the ELA
    ice = ice_src.ravel().copy()
    hv = c.h.ravel()
    for p in range(stack.size):
        k = stack[stack.size - 1 - p]
        r = rec[k]
        if ice[k] and r != k and hv[r] > ela - P["tongue"]:
            ice[r] = True
    ice = ice.reshape(H, W)
    trunk = ice & (A > P["ice_area"])
    if not trunk.any():
        return
    d, src = nearest_source(trunk, c.cell)
    a_src = A.ravel()[np.maximum(src, 0)].reshape(H, W)
    wid = np.minimum(P["width"] * np.sqrt(a_src), P["width_max"])
    floor = c.h.ravel()[np.maximum(src, 0)].reshape(H, W) - P["deepen"] * smoothstep(P["ice_area"], P["ice_area"] * 6, a_src)
    u = floor + (c.h - floor) * np.clip(d / np.maximum(wid, 1), 0, 1) ** 2   # parabolic (U) cross-section
    m = (src >= 0) & (d < wid) & ice
    u = np.maximum(u, c.h - P["lower_max"])                         # ice widens a valley, it does not plane a range
    c.h = np.where(m, np.minimum(c.h, u), c.h)
    c.layers["glacier"] = ice.astype(np.float32)


def coast(c):
    """Sea stacks off cliffed headlands of hard rock: rock instances in the water within `reach` of a steep shore."""
    P = c.p("coast")
    hard = np.isin(c.ids, [3, 4, 5, 6, 7])
    sl = slope(c.h, c.cell)
    cliff = hard & (c.sd < 0) & (c.sd > -120) & (sl > 0.5)
    if not cliff.any():
        return
    near = max_filter(cliff.astype(np.float64), int(P["reach"] / c.cell) + 1) > 0
    sea = near & c.wet & (c.sd > 10) & (c.sd < P["reach"])
    s = P["stack_spacing"]
    f1, f2, cid, px, pz = noise.worley(c.X / s, c.Z / s, 0.9, c.seed + 991)
    sel = sea & (cid < P["stack_keep"]) & (f1 < 0.12)
    if sel.any():
        _, first = np.unique(np.round(px[sel] * 7 + pz[sel] * 11).astype(np.int64), return_index=True)
        x, z = px[sel][first] * s, pz[sel][first] * s
        r = P["stack_r"][0] + (P["stack_r"][1] - P["stack_r"][0]) * cid[sel][first] / P["stack_keep"]
        ht = P["stack_h"][0] + (P["stack_h"][1] - P["stack_h"][0]) * noise.cell_hash(np.round(x).astype(np.int64), 1, 77)
        c.add_rocks(x, z, r, ht, "sea_stack", c.seed + 993)


OPERATORS = {"karst": karst, "danxia": danxia, "pillars": pillars, "granite": granite, "loess": loess,
             "volcanic": volcanic, "alluvial": alluvial, "wetland": wetland, "fold": fold}
