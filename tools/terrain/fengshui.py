"""Read the land like a 形势派 geomancer: score the sect sites (and find better ones) on a heightfield.

    python3 tools/terrain/fengshui.py                                    # the six sects on the exported terrain
    python3 tools/terrain/fengshui.py --terrain godot/data/terrain       # … on a re-sculpted one
    python3 tools/terrain/fengshui.py --search luoyun --radius 6000      # best sites within 6000 丈 of 落云宗 (+ heatmap)

Terms and weights: xyterrain/fengshui.py. The scores are a design aid — a site that scores low is not wrong, but the
reader of a 仙侠 map expects a sect to sit 背山面水, in a 藏风聚气 bowl, on a 龙脉 that comes down from the 祖山.
"""
import argparse
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xyterrain.fengshui import WEIGHTS, Geomancer       # noqa: E402
from xyterrain.world import World, write_png            # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
NAMES = {"gujian": "古剑门", "luoyun": "落云宗", "baiqiao": "百巧院", "luanming": "鸾鸣宗", "nihang": "倪航斋", "shuiying": "水影宗"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(ROOT, "godot", "data", "world"))
    ap.add_argument("--terrain", help="a sculpt.py output folder (default: the exported heights)")
    ap.add_argument("--R", type=float, default=320.0, help="hall radius 丈")
    ap.add_argument("--search", help="a site id: score a grid of candidates round it and write a heatmap")
    ap.add_argument("--radius", type=float, default=6000)
    ap.add_argument("--step", type=float, default=400)
    ap.add_argument("--trace", help="a site id: print its 龙脉 route from the 祖山 (every ~1000 丈) and the col on it")
    ap.add_argument("--json")
    a = ap.parse_args()
    w = World(a.data)
    h = w.height
    if a.terrain:
        h = np.fromfile(os.path.join(a.terrain, "height_f16.bin"), "<f2").astype(np.float32).reshape(w.H, w.W)
    wet, _ = w.water()
    g = Geomancer(h, w.x0, w.z0, w.cell, wet)
    keys = list(WEIGHTS)
    out = {}
    if a.trace:
        s = next(q for q in w.sites() if q["id"] == a.trace)
        route, ci = g.trace(s["x"], s["z"], 40 * a.R)
        step = max(1, int(1000 / w.cell))
        print(f"龙脉 of {NAMES.get(a.trace, a.trace)}: {len(route)} cells from the 祖山 ({route[0][0]:.0f}, {route[0][1]:.0f}) (h {route[0][2]:.0f}); "
              f"col {route[ci][2]:.0f} at ({route[ci][0]:.0f}, {route[ci][1]:.0f}); site h {route[-1][2]:.0f}")
        print("  " + "  ".join(f"({x:.0f},{z:.0f}) {h:.0f}" for x, z, h in route[::step] + [route[-1]]))
        return
    if not a.search:
        print(f"{'site':8s} {'total':>6s} {'向°':>4s} " + " ".join(f"{k:>4s}" for k in keys) + "   祖山 col")
        for s in w.sites():
            tot, t, phi = g.score(s["x"], s["z"], a.R)
            out[s["id"]] = {"total": round(tot, 3), "facing": phi, **{k: (round(v, 2) if isinstance(v, float) else v) for k, v in t.items()}}
            print(f"{NAMES.get(s['id'], s['id']):6s} {tot:6.2f} {phi:4.0f} " + " ".join(f"{t[k]:4.2f}" for k in keys) + f"   {t['_祖山']} {t['_col']:+.0f}")
    else:
        s = next(q for q in w.sites() if q["id"] == a.search)
        xs = np.arange(s["x"] - a.radius, s["x"] + a.radius + 1, a.step)
        zs = np.arange(s["z"] - a.radius, s["z"] + a.radius + 1, a.step)
        grid = np.zeros((len(zs), len(xs)))
        cands = []
        for j, z in enumerate(zs):
            for i, x in enumerate(xs):
                if g.sample(np.array([x]), np.array([z]), wet.astype(np.float32))[0] > 0.5:
                    continue
                tot, t, phi = g.score(x, z, a.R)
                grid[j, i] = tot
                cands.append((tot, x, z, phi))
        cands.sort(reverse=True)
        for tot, x, z, phi in cands[:8]:
            print(f"  ({x:8.0f}, {z:8.0f})  facing {phi:3.0f}°  score {tot:.2f}")
        img = (np.clip(grid / max(grid.max(), 1e-6), 0, 1) * 255).astype(np.uint8)
        path = os.path.join(a.terrain or HERE, f"fengshui_{a.search}.png")
        write_png(path, np.kron(img, np.ones((8, 8), np.uint8)))
        print("heatmap", path)
        out = {"site": a.search, "best": [{"x": float(x), "z": float(z), "facing": phi, "score": round(t, 3)} for t, x, z, phi in cands[:20]]}
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
