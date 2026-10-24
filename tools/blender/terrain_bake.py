"""Write a hand-edited "XY Terrain Edit" back into the terrain (and its painted rocks back into the plan).

    blender edit.blend --background --python tools/blender/terrain_bake.py
    blender edit.blend --background --python tools/blender/terrain_bake.py -- --out /tmp/terrain_edited --no-litho

The heights go into <terrain>/height_f16.bin (+ height.png) — the folder terrain_edit.py read (the object's xy_terrain),
or a copy of it in --out. Only the cells whose height you changed are written (|Δ| > 0.05 丈), so a terrain re-sculpted
since then keeps everything else. If the mesh still has one vertex per sample, heights are read straight off the
vertices (exact); after Dyntopo / Remesh they are ray-cast from above at every sample (BVH).
The Litho colours are snapped to the nearest rock and painted into <plan>/lithology.png over the edited area.

Re-run tools/terrain/sculpt.py after repainting rocks (the operators read the plan); after height edits alone you can
load the folder in Godot directly (--terrain=…).
"""
import os
import shutil
import sys

import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

try:
    HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:
    HERE = os.getcwd()
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "terrain"))
from xyterrain.geology import litho_ids_from_rgb, rgb_from_ids  # noqa: E402
from xyterrain.world import World, read_png, write_png           # noqa: E402


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    a = {"out": None, "litho": True, "object": "XY Terrain Edit"}
    i = 0
    while i < len(argv):
        k = argv[i].lstrip("-")
        if k == "no-litho":
            a["litho"] = False; i += 1
        else:
            a[k] = argv[i + 1]; i += 2
    return a


def main():
    a = parse_args()
    ob = bpy.data.objects[a["object"]]
    me = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    i0, j0, cols, rows = ob["xy_i0"], ob["xy_j0"], ob["xy_w"], ob["xy_h"]
    cell, s, zx = ob["xy_cell"], ob["xy_scale"], ob["xy_zx"]
    src = ob["xy_terrain"]
    w = World(ob["xy_data"])
    out = a["out"] or src
    if out != src:
        shutil.copytree(src, out, dirs_exist_ok=True)
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    mw = np.array(ob.matrix_world)
    co = co @ mw[:3, :3].T + mw[:3, 3]
    if len(co) == rows * cols:
        z = co[:, 2].reshape(rows, cols) / (s * zx)
        how = "vertices"
    else:                                                          # topology changed: cast down at every sample
        bvh = BVHTree.FromObject(ob, bpy.context.evaluated_depsgraph_get())
        z = np.zeros((rows, cols), np.float32)
        top = float(co[:, 2].max()) + 10
        for j in range(rows):
            for i in range(cols):
                x = (ob["xy_x0"] + (i0 + i) * cell) * s; y = -(ob["xy_z0"] + (j0 + j) * cell) * s
                hit = bvh.ray_cast((x, y, top), (0, 0, -1))
                z[j, i] = hit[0].z / (s * zx) if hit[0] is not None else np.nan
        how = "ray casts"
    h0 = np.empty(rows * cols, np.float32)
    if "h0" in me.attributes and len(me.attributes["h0"].data) == rows * cols:
        me.attributes["h0"].data.foreach_get("value", h0)
    raw = os.path.join(out, "height_f16.bin")
    H = np.fromfile(raw, "<f2").astype(np.float32).reshape(w.H, w.W)
    cur = H[j0:j0 + rows, i0:i0 + cols]
    base = h0.reshape(rows, cols) if "h0" in me.attributes else cur
    changed = np.isfinite(z) & (np.abs(z - base) > 0.05)
    cur[changed] = z[changed]
    H[j0:j0 + rows, i0:i0 + cols] = cur
    H.astype("<f2").tofile(raw)
    top = float(max(1.0, np.ceil(H.max())))
    write_png(os.path.join(out, "height.png"), (np.clip(H, 0, None) / top * 65535 + 0.5).astype(np.uint16))
    print(f"terrain bake ({how}): {int(changed.sum())} of {rows * cols} samples changed → {raw}")
    if a["litho"] and "Litho" in me.color_attributes:
        lit = me.color_attributes["Litho"]
        c = np.empty(len(lit.data) * 4, np.float32); lit.data.foreach_get("color", c)
        if len(c) // 4 == rows * cols:
            ids = litho_ids_from_rgb((c.reshape(rows, cols, 4)[..., :3] * 255).round())
            plan_png = os.path.join(ob["xy_plan"], "lithology.png")
            P = litho_ids_from_rgb(read_png(plan_png))
            ph, pw = P.shape
            R = w.rect
            px = R["x0"] + (np.arange(pw) + 0.5) * (R["x1"] - R["x0"]) / pw
            pz = R["z0"] + (np.arange(ph) + 0.5) * (R["z1"] - R["z0"]) / ph
            ii = np.round((px - ob["xy_x0"]) / cell).astype(int) - i0
            jj = np.round((pz - ob["xy_z0"]) / cell).astype(int) - j0
            okx = (ii >= 0) & (ii < cols); okz = (jj >= 0) & (jj < rows)
            sub = ids[np.clip(jj, 0, rows - 1)][:, np.clip(ii, 0, cols - 1)]
            m = okz[:, None] & okx[None, :]
            n = int((P[m] != sub[m]).sum())
            P[m] = sub[m]
            write_png(plan_png, rgb_from_ids(P))
            print(f"litho bake: {n} plan pixels repainted → {plan_png}")
    ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()


main()
