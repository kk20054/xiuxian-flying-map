"""Rock types and structures — the 'geological map' the terrain is grown from.

A plan is two files (see tools/terrain/plan/):
    lithology.png   RGB, one colour per rock type (LITHO[...]["color"]), cell-centred over the world rect, any size
                    (make_plan.py writes 1648×1003 = 80 丈/px). Paint it in Krita / Photoshop / Blender; colours snap to the
                    nearest palette entry.
    geology.json    structures that a raster can't express: fold belts (strike, dip, bed thickness), faults, volcanoes,
                    the glacier line, karst water table, uplift edits, and the per-rock parameter overrides.

Why per-rock parameters matter (the core idea): the same uplift and rivers give very different land depending on what
the rock lets erosion do. K (erodibility) sets how fast rivers cut and therefore how high the rock stands; Sc
(critical slope) sets how steep it can stand — granite and quartz sandstone hold vertical walls, alluvium and loess
tops cannot; the landform operator adds what stream power alone doesn't make (towers, mesas, pillars, dolines…).
"""
import json
import math

import numpy as np

from . import noise
from .world import read_png

# K: erodibility multiplier on the calibrated K0 · Sc: steepest stable slope (tan) on the 40-丈 grid · talus: angle of
# repose (tan) for loose debris · D: hillslope diffusion multiplier · op: landform operator (landforms.py)
LITHO = {
    "alluvium":   {"id": 0, "cn": "冲积层", "color": [216, 207, 156], "K": 3.0, "Sc": 0.12, "talus": 0.3, "D": 2.0, "op": "alluvial"},
    "loess":      {"id": 1, "cn": "黄土", "color": [224, 184, 112], "K": 2.2, "Sc": 1.4, "talus": 0.8, "D": 1.0, "op": "loess"},
    "metamorphic": {"id": 2, "cn": "变质岩（板岩·片岩）", "color": [138, 143, 122], "K": 1.0, "Sc": 1.3, "talus": 0.85, "D": 1.0, "bedded": True, "op": "fold"},
    "granite":    {"id": 3, "cn": "花岗岩", "color": [201, 196, 189], "K": 0.35, "Sc": 6.0, "talus": 1.5, "D": 0.4, "op": "granite"},
    "quartz_sandstone": {"id": 4, "cn": "石英砂岩", "color": [185, 169, 138], "K": 0.5, "Sc": 8.0, "talus": 1.8, "D": 0.3, "bedded": True, "op": "pillars"},
    "redbed":     {"id": 5, "cn": "丹霞红层", "color": [192, 88, 58], "K": 0.9, "Sc": 5.0, "talus": 1.3, "D": 0.5, "bedded": True, "op": "danxia"},
    "limestone":  {"id": 6, "cn": "石灰岩", "color": [159, 179, 182], "K": 0.6, "Sc": 4.0, "talus": 1.3, "D": 0.6, "bedded": True, "op": "karst"},
    "volcanic":   {"id": 7, "cn": "火山岩", "color": [91, 79, 87], "K": 0.5, "Sc": 2.2, "talus": 1.0, "D": 0.6, "op": "volcanic"},
    "lacustrine": {"id": 8, "cn": "湖沼沉积", "color": [111, 127, 79], "K": 3.5, "Sc": 0.06, "talus": 0.2, "D": 2.5, "op": "wetland"},
}
BY_ID = {v["id"]: k for k, v in LITHO.items()}
PALETTE = np.array([LITHO[BY_ID[i]]["color"] for i in range(len(LITHO))], np.float32)


def litho_ids_from_rgb(rgb):
    """Snap an RGB plan image to rock ids (nearest palette colour)."""
    rgb = rgb[..., :3].astype(np.float32)
    d = ((rgb[..., None, :] - PALETTE[None, None]) ** 2).sum(-1)
    return d.argmin(-1).astype(np.uint8)


def rgb_from_ids(ids):
    return PALETTE[ids].astype(np.uint8)


class Plan:
    def __init__(self, plan_dir, world):
        self.dir = plan_dir
        with open(f"{plan_dir}/geology.json", encoding="utf-8") as f:
            self.g = json.load(f)
        for name, over in self.g.get("lithology", {}).items():   # parameter overrides
            LITHO[name].update(over)
        ids = litho_ids_from_rgb(read_png(f"{plan_dir}/lithology.png"))
        self.ids_plan = ids
        self.ids = world.resample(ids)                            # on the height grid
        self.world = world
        self.seed = int(self.g.get("seed", 7))

    def field(self, key):
        """Per-cell value of a rock parameter (K, Sc, talus, D) on the height grid."""
        table = np.array([LITHO[BY_ID[i]][key] for i in range(len(LITHO))], np.float64)
        return table[self.ids]

    def mask(self, name, soft=0):
        m = (self.ids == LITHO[name]["id"]).astype(np.float32)
        if soft:
            m = box_blur(m, soft)
        return m

    # ---- structures ----------------------------------------------------------------------------------------------
    def strata_phase(self, h):
        """Bed index (float) of every cell inside fold belts: beds dip `dip`° toward strike+90°, `bed` 丈 thick,
        folded with wavelength `wave` (anticline / syncline axes along strike). Soft beds (frac in the band
        [0, soft)) erode fast → strike valleys; hard beds stand as ridges → trellis drainage and hogbacks."""
        X, Z = self.world.xz
        phase = np.zeros(X.shape)
        w = np.zeros(X.shape)
        for fb in self.g.get("structures", {}).get("folds", []):
            th = math.radians(fb["strike"])
            along = X * math.cos(th) + Z * math.sin(th)
            across = -X * math.sin(th) + Z * math.cos(th)
            wx, wz = noise.warp(along, across, fb.get("warp", 900.0), 6000.0, self.seed + 31)
            fold = fb.get("amp", 300.0) * np.sin(2 * math.pi * wz / fb.get("wave", 7000.0))   # the folded bedding surface
            dip = math.radians(fb.get("dip", 30.0))
            depth = wz * math.sin(dip) + (h - fold) * math.cos(dip)
            inside = region_weight(fb, X, Z)
            phase += inside * depth / fb.get("bed", 60.0)
            w = np.maximum(w, inside)
        return phase, w

    def fold_K(self, h):
        """Erodibility multiplier from the bedding: alternating hard/soft beds inside fold belts (bedded rocks only —
        a granite batholith or a lava pile inside the belt is not layered)."""
        phase, w = self.strata_phase(h)
        bedded = np.array([LITHO[BY_ID[i]].get("bedded", False) for i in range(len(LITHO))])[self.ids]
        w = w * bedded
        if not w.any():
            return np.ones_like(h, np.float64)
        contrast = max([fb.get("contrast", 0.65) for fb in self.g["structures"]["folds"]] or [0.65])
        soft = 0.5 + 0.5 * np.sin(2 * math.pi * phase)                 # 1 in soft shale, 0 in hard sandstone/quartzite
        return 1.0 + w * contrast * (2.0 * soft - 1.0)

    def faults(self):
        return self.g.get("structures", {}).get("faults", [])

    def fault_fields(self):
        """(uplift multiplier, erodibility multiplier, distance to the nearest fault trace in 丈). The upthrown side
        rises (horst / range front: triangular facets, waterfalls off the scarp), the crushed zone erodes fast
        (fault-line valleys) — where 灵脉 run, and where 灵眼 springs sit at fault crossings."""
        X, Z = self.world.xz
        Um = np.ones(X.shape); Km = np.ones(X.shape); dmin = np.full(X.shape, 1e9)
        for f in self.faults():
            pts = np.asarray(f["pts"], np.float64)
            d, side = polyline_signed_distance(pts, X, Z)
            dmin = np.minimum(dmin, np.abs(d))
            wdt = f.get("width", 250.0)
            # "up": the compass side that is thrown up (N / S / E / W; the map is north-up, z grows to the south)
            mid = pts[len(pts) // 2 - 1: len(pts) // 2 + 1].mean(0)
            off = {"N": (0, -400), "S": (0, 400), "E": (400, 0), "W": (-400, 0)}[f.get("up", "N")]
            _, up_side = polyline_signed_distance(pts, np.array([mid[0] + off[0]]), np.array([mid[1] + off[1]]))
            ramp = 0.5 + 0.5 * np.tanh(np.abs(d) * np.where(side == up_side[0], 1.0, -1.0) / wdt)   # 1 upthrown, 0 down
            reach = np.exp(-np.abs(d) / f.get("reach", 9000.0))
            tip = fault_tip_weight(pts, X, Z, f.get("tip", 1500.0))      # throw dies out past the fault's ends
            Um *= 1.0 + f.get("throw", 0.35) * (ramp - 0.5) * 2 * reach * tip
            Km *= 1.0 + f.get("crush", 1.2) * np.exp(-(d / wdt) ** 2) * tip
        return Um, Km, dmin

    def volcanoes(self):
        return self.g.get("structures", {}).get("volcanoes", [])

    def uplift_edits(self, U):
        """Painted uplift: points {x, z, r, du} and ridge lines {pts, width, du} — a 龙脉 drawn as a polyline is an
        anticlinal axis that keeps rising, so erosion cannot cut the ridge through (a 过峡 saddle stays a saddle)."""
        X, Z = self.world.xz
        for e in self.g.get("structures", {}).get("uplift", []):
            if "pts" in e:
                d, _ = polyline_signed_distance(np.asarray(e["pts"], np.float64), X, Z)
                U = U + e["du"] * np.exp(-(d / e.get("width", 1200.0)) ** 2)
            else:
                r = e["r"]
                U = U + e["du"] * np.exp(-((X - e["x"]) ** 2 + (Z - e["z"]) ** 2) / (r * r))
        return np.maximum(U, 0)


def region_weight(fb, X, Z):
    """1 inside a structure's region: {"ellipse": [x, z, rx, rz, rot°]} or {"poly": [[x,z]…]} (soft 'feather' edge)."""
    fe = fb.get("feather", 2500.0)
    if "ellipse" in fb:
        x, z, rx, rz, rot = fb["ellipse"]
        c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        u = ((X - x) * c + (Z - z) * s) / rx
        v = (-(X - x) * s + (Z - z) * c) / rz
        d = (np.sqrt(u * u + v * v) - 1.0) * min(rx, rz)
    elif "poly" in fb:
        d = -polygon_signed_distance(np.asarray(fb["poly"], np.float64), X, Z)
    else:
        return np.ones(X.shape)
    t = np.clip(d / fe, 0, 1)
    return 1 - t * t * (3 - 2 * t)


def polyline_signed_distance(P, X, Z):
    """Distance to a polyline, signed by the side (left of the direction of travel = +)."""
    best = np.full(X.shape, 1e18); side = np.zeros(X.shape)
    for a, b in zip(P[:-1], P[1:]):
        dx, dz = b - a
        L2 = dx * dx + dz * dz
        t = np.clip(((X - a[0]) * dx + (Z - a[1]) * dz) / L2, 0, 1)
        px = a[0] + t * dx - X; pz = a[1] + t * dz - Z
        d2 = px * px + pz * pz
        cr = dx * (Z - a[1]) - dz * (X - a[0])
        m = d2 < best
        best = np.where(m, d2, best); side = np.where(m, np.sign(cr), side)
    return np.sqrt(best) * np.where(side == 0, 1, side), side


def fault_tip_weight(P, X, Z, tip):
    """1 alongside a fault trace, falling to 0 within `tip` 丈 beyond either end (a real fault's throw dies out)."""
    out = np.zeros(X.shape)
    for a, b in ((P[0], P[1]), (P[-1], P[-2])):
        d = (a - b) / max(np.hypot(*(a - b)), 1e-9)
        out = np.maximum(out, (X - a[0]) * d[0] + (Z - a[1]) * d[1])   # how far past this end
    t = np.clip(out / tip, 0, 1)
    return 1 - t * t * (3 - 2 * t)


def polygon_signed_distance(P, X, Z):
    """+ inside a closed polygon, − outside."""
    d, _ = polyline_signed_distance(np.vstack([P, P[:1]]), X, Z)
    d = np.abs(d)
    inside = np.zeros(X.shape, bool)
    x0, z0 = P[:, 0], P[:, 1]
    x1, z1 = np.roll(x0, -1), np.roll(z0, -1)
    for a, b, c, e in zip(x0, z0, x1, z1):
        cond = ((b > Z) != (e > Z)) & (X < (c - a) * (Z - b) / (e - b + 1e-12) + a)
        inside ^= cond
    return np.where(inside, d, -d)


def box_blur(a, r):
    """Separable box blur, radius r cells, clamp-to-edge."""
    a = np.asarray(a, np.float64)
    for ax in (0, 1):
        pad = [(0, 0), (0, 0)]; pad[ax] = (r + 1, r)
        c = np.cumsum(np.pad(a, pad, mode="edge"), axis=ax)
        a = (np.take(c, range(2 * r + 1, c.shape[ax]), axis=ax) - np.take(c, range(0, c.shape[ax] - 2 * r - 1), axis=ax)) / (2 * r + 1)
    return a
