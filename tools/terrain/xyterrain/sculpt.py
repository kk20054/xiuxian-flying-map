"""The re-sculpt: grow the existing layout's land again from a geological plan.

    1. Uplift U from the layout's own massifs (the smoothed exported relief), × fault throws, + plan uplift edits.
       Base level = every water cell of the layout (sea, lakes, rivers) and the map edge: the 舆图's rivers stay where
       they are and the new valleys are graded to them ("rivers first", as in Génevaux et al. 2013).
    2. K0 is calibrated so the exported terrain is close to equilibrium; each rock multiplies it (granite resists,
       alluvium yields), fold belts alternate hard and soft beds, fault zones are crushed. Then `steps` implicit
       stream-power steps with critical slopes per rock and hillslope diffusion.
    3. The massif envelope is pulled back toward the layout's (so 云梦山 stays the highest), then the landform operator
       of each rock runs (karst, danxia, pillars …), glaciers above the snow line, talus, sea stacks.
    4. The sect patches and city cores are blended back to the exported ground (the engine's sect meshes sit there),
       water cells keep their beds.
"""
import time

import numpy as np

from . import flow, landforms, noise
from .fields import box_blur, max_filter, smoothstep
from .geology import LITHO

M = 0.45                                          # drainage-area exponent (the demo's relief.m)


def sculpt(world, plan, steps=24, preserve=True, operators=True, log=print):
    t0 = time.time()
    cell = world.cell
    H0 = world.height.astype(np.float64)
    wet, sd = world.water()
    base = wet | flow.edge_mask(H0.shape)
    pres = world.preserve_mask(mark_r=450.0) if preserve else np.zeros(H0.shape, np.float32)
    fixed = base | (pres > 0.985)
    X, Z = world.xz
    seed = plan.seed

    # 1. uplift: a regional field over the massifs, not the topography itself — valleys and saddles inside a range
    #    are uplifted as much as its peaks (the demo derives it from the 舆图's mountain density for the same reason)
    U = box_blur(max_filter(np.maximum(H0, 0), 18), 30)
    U = U / max(1e-6, np.percentile(U[U > 1], 99))
    U = np.maximum(U, 0.01) * ~base
    U = plan.uplift_edits(U)
    Uf, Kf, dfault = plan.fault_fields()
    U = U * Uf

    # 2. erodibility, calibrated on the exported terrain
    hf, rec, stack, area, dist = flow.fill_route(H0, base, cell)
    S = (hf.ravel() - hf.ravel()[rec]) / dist
    mt = (~base.ravel()) & (S > 0.02) & (H0.ravel() > 40)
    K0 = float(np.median(U.ravel()[mt] / (area[mt] ** M * S[mt])))
    dt = 0.5 * cell / (K0 * float(np.median(area[mt] ** M)))
    Kr = plan.field("K") * Kf * (1 + 0.2 * noise.fbm(X / 4200, Z / 4200, 2, seed + 1))
    Sc = plan.field("Sc")
    D = plan.field("D") * 0.5 * cell * cell / (dt * max(steps, 1))
    log(f"  calibrated K0 = {K0:.3e}, dt = {dt:.3g}, {int(mt.sum())} mountain cells ({time.time() - t0:.1f}s)")
    h = H0.copy()
    for s in range(steps):
        if s % 6 == 0:
            K = K0 * Kr * plan.fold_K(h)                  # dipping beds: which bed crops out depends on the height
        hf, rec, stack, area, dist = flow.fill_route(h, base, cell, 1e-3, seed * 1000 + s)
        flow.spl_step(h, U, K, M, dt, rec, stack, area, dist, Sc, fixed)
        h = flow.diffuse(h, D, dt, cell, fixed)
        if s % 6 == 5 or s == steps - 1:
            log(f"  step {s + 1}/{steps}  max {h.max():.0f}  ({time.time() - t0:.1f}s)")

    # 3. keep the layout's massif envelope (the map's 云梦山 is the highest range, the plains stay plains)
    mtn = smoothstep(20, 120, box_blur(np.maximum(H0, 0), 6))
    env0 = box_blur(np.maximum(H0, 0), 30); env1 = box_blur(np.maximum(h, 0), 30)
    ratio = np.clip(env0 / np.maximum(env1, 1.0), 0.6, 1.7) ** 0.75
    h = np.where(h > 0, h * (1 + (ratio - 1) * mtn), h)

    hf, rec, stack, area, dist = flow.fill_route(h, base, cell)
    c = landforms.Ctx(world, h, H0, area, wet, sd, plan.ids, plan.g, seed)
    if operators:
        order = ["wetland", "alluvial", "loess", "danxia", "karst", "pillars", "granite", "volcanic", "fold"]
        for op in order:
            for name, L in LITHO.items():
                if L["op"] != op:
                    continue
                w = plan.mask(name, soft=3)
                if w.max() <= 0:
                    continue
                tt = time.time()
                if op == "volcanic":
                    landforms.volcanic(c, w, plan.volcanoes())
                else:
                    landforms.OPERATORS[op](c, w)
                log(f"  {op:9s} on {name:16s} {float((w > 0.5).mean()) * 100:5.1f} % of the map  ({time.time() - tt:.1f}s)")
        hf, rec, stack, area, dist = flow.fill_route(c.h, base, cell)
        glac = plan.g.get("structures", {}).get("glacier", {})
        landforms.glacial(c, rec, stack, glac.get("ela"))
        landforms.coast(c)
    h = c.h
    h = flow.thermal(h, plan.field("talus") * 1.0, cell, iters=6, rate=0.4, fixed=fixed)

    # 4. back to the fixed ground
    h = h * (1 - pres) + H0 * pres
    h = np.where(wet, H0, h)
    h = np.where(~wet & (H0 >= 0), np.maximum(h, 0.0), h)
    cap = 1250.0
    h = np.where(h > 900, 900 + (cap - 900) * np.tanh((h - 900) / (cap - 900)), h)

    rocks = np.concatenate(c.rocks) if c.rocks else np.zeros((0, 8), np.float32)
    if len(rocks):
        ri = np.clip(np.round((rocks[:, 0] - world.x0) / cell).astype(int), 0, world.W - 1)
        rj = np.clip(np.round((rocks[:, 2] - world.z0) / cell).astype(int), 0, world.H - 1)
        kind = rocks[:, 5].astype(int)
        in_water_ok = np.isin(kind, [landforms.ROCK["sea_stack"], landforms.ROCK["karst_tower"]])
        keep = (pres[rj, ri] < 0.3) & (~wet[rj, ri] | in_water_ok)
        rocks = rocks[keep]
        rocks[:, 1] = h[rj[keep], ri[keep]]                # re-seat on the final ground
    log(f"  done: {len(rocks)} rock instances, height {h.min():.0f}…{h.max():.0f} 丈 ({time.time() - t0:.1f}s)")
    return h.astype(np.float32), rocks, c.layers, {"K0": K0, "dt": dt, "steps": steps}
