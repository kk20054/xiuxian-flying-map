"""Re-sculpt the world's terrain from a geological plan (see docs/terrain/04-tools.md).

    python3 tools/terrain/sculpt.py                                  # plan/ → godot/data/terrain/ (+ previews)
    python3 tools/terrain/sculpt.py --steps 40 --out /tmp/t2 --no-preserve
    godot --path godot -- --terrain=res://data/terrain               # fly over the result

Needs numpy (and numba for speed: `pip install numba` — without it the run takes hours instead of ~2 min).
Writes into --out:
    height_f16.bin, height.png, terrain.json   the new 40-丈 heightfield (same grid and formats as data/world)
    lithology.png                               the rock map on the height grid (8-bit ids, see terrain.json "litho")
    rocks.bin                                   rock instances (float32 × 8: x, y, z, radius, height, kind, yaw, var)
    layers/*.png                                redness (Danxia), pillar stage, karst form, glacier (8-bit)
    preview/*.png                               shaded relief before / after, close-ups of the named places
"""
import argparse
import json
import os
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xyterrain import preview                                  # noqa: E402
from xyterrain.geology import LITHO, Plan                      # noqa: E402
from xyterrain.landforms import ROCK_KINDS                     # noqa: E402
from xyterrain.sculpt import sculpt                            # noqa: E402
from xyterrain.world import World, write_png                   # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CLOSEUPS = [("yunmeng", 9000), ("luoyun", 4500), ("baiqiao", 5000), ("sunshi", 3000), ("luanming", 7000),
            ("nihang", 6000), ("shuiying", 6000), ("yunzhoucheng", 7000), ("minzhou", 4000), ("qiling", 9000)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(ROOT, "godot", "data", "world"))
    ap.add_argument("--plan", default=os.path.join(HERE, "plan"))
    ap.add_argument("--out", default=os.path.join(ROOT, "godot", "data", "terrain"))
    ap.add_argument("--steps", type=int, default=24, help="stream-power steps (more = further from the exported land)")
    ap.add_argument("--no-preserve", action="store_true", help="also re-shape the land round the sect patches and cities")
    ap.add_argument("--no-operators", action="store_true", help="erosion only, no landform operators")
    ap.add_argument("--no-preview", action="store_true")
    a = ap.parse_args()
    t0 = time.time()
    w = World(a.data)
    plan = Plan(a.plan, w)
    print(f"world {w.W}×{w.H} @ {w.cell:g} 丈, plan {a.plan}")
    h, rocks, layers, info = sculpt(w, plan, steps=a.steps, preserve=not a.no_preserve, operators=not a.no_operators)
    out = a.out
    os.makedirs(out, exist_ok=True)
    gi = os.path.join(out, ".gdignore")
    if not os.path.exists(gi):
        open(gi, "w").close()
    rocks.astype("<f4").tofile(os.path.join(out, "rocks.bin"))
    write_png(os.path.join(out, "lithology.png"), plan.ids.astype(np.uint8))
    os.makedirs(os.path.join(out, "layers"), exist_ok=True)
    for name, arr in layers.items():
        v = arr / max(1e-6, float(arr.max()))
        write_png(os.path.join(out, "layers", name + ".png"), (np.clip(v, 0, 1) * 255).astype(np.uint8))
    counts = {k: int((rocks[:, 5] == i).sum()) for i, k in enumerate(ROCK_KINDS)} if len(rocks) else {}
    w.save_height(out, h, {
        "source": "tools/terrain/sculpt.py", "plan": os.path.relpath(a.plan, ROOT), "steps": a.steps, "solver": info,
        "litho": {"file": "lithology.png", "encoding": "8-bit id per height sample", "ids": {k: v["id"] for k, v in LITHO.items()},
                  "colors": {k: v["color"] for k, v in LITHO.items()}},
        "rocks": {"file": "rocks.bin", "count": int(len(rocks)), "layout": "float32 LE × 8: x, y (ground), z, radius, height, kind, yaw, var",
                  "kinds": ROCK_KINDS, "per_kind": counts},
        "layers": {k: f"layers/{k}.png" for k in layers}})
    print(f"wrote {out}  ({time.time() - t0:.0f}s)  rocks {counts}")
    if a.no_preview:
        return
    pv = os.path.join(out, "preview")
    os.makedirs(pv, exist_ok=True)
    wet, _ = w.water()
    before = preview.render(w.height, w.cell, wet, plan.ids)
    after = preview.render(h, w.cell, wet, plan.ids, rocks, w)
    write_png(os.path.join(pv, "after.png"), preview.downsample(after, 2))
    write_png(os.path.join(pv, "before.png"), preview.downsample(before, 2))
    pos = {p["id"]: w.place_xz(p) for p in w.places}
    for pid, half in CLOSEUPS:
        if pos.get(pid):
            x, z = pos[pid]
            preview.save_compare(os.path.join(pv, f"cmp_{pid}.png"), preview.crop(w, before, x, z, half), preview.crop(w, after, x, z, half))
    print("previews in", pv)


if __name__ == "__main__":
    main()
