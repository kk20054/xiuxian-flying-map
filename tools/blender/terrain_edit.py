"""Open a piece of the terrain in Blender for hand editing — the sculpt-by-hand half of the terrain round trip.

    blender --python tools/blender/terrain_edit.py -- --site luoyun --half 3000
    blender --python tools/blender/terrain_edit.py -- --region 2000,-4000,9000,2000 --terrain godot/data/terrain
    blender --background --python tools/blender/terrain_edit.py -- --site gujian --out gujian_edit.blend

It builds "XY Terrain Edit": one vertex per height sample (40 丈 grid, so the bake back is exact), with
  - the rock map as the colour attribute "Litho" (paint it in Vertex Paint with the palette in docs/terrain/04-tools.md;
    colours snap to the nearest rock when baked),
  - the heights it started from in the attribute "h0" (the bake writes only what you changed),
  - its grid placement in custom properties (xy_i0, xy_j0, xy_w, xy_h, xy_cell, xy_scale, xy_terrain, xy_plan).
Sculpt it (Sculpt mode: Draw / Clay Strips / Smooth / Pinch / Flatten; keep the topology — no Dyntopo or Remesh, or
the bake falls back to ray casting), then run tools/blender/terrain_bake.py.

Scale and axes as import_world.py: --scale Blender units per 丈 (default 0.1); demo (x, y up, z south) → Blender
(x, −z, y). Heights are exaggerated by --zx (default 1) for sculpting comfort and divided back on bake.
"""
import json
import os
import sys

import bpy
import numpy as np

try:
    HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:
    HERE = os.getcwd()
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "terrain"))
from xyterrain.geology import PALETTE, litho_ids_from_rgb  # noqa: E402
from xyterrain.world import World, read_png               # noqa: E402


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    a = {"data": os.path.join(ROOT, "godot", "data", "world"), "terrain": None, "plan": os.path.join(ROOT, "tools", "terrain", "plan"),
         "site": None, "half": "3000", "region": None, "scale": "0.1", "zx": "1", "out": None}
    for i in range(0, len(argv) - 1, 2):
        a[argv[i].lstrip("-")] = argv[i + 1]
    return a


def load_heights(a, w):
    if a["terrain"]:
        return np.fromfile(os.path.join(a["terrain"], "height_f16.bin"), "<f2").astype(np.float32).reshape(w.H, w.W)
    return w.height


def main():
    a = parse_args()
    w = World(a["data"])
    H = load_heights(a, w)
    s, zx = float(a["scale"]), float(a["zx"])
    if a["region"]:
        x0, z0, x1, z1 = [float(v) for v in a["region"].split(",")]
    else:
        site = next(q for q in w.sites() if q["id"] == (a["site"] or "luoyun"))
        hf = float(a["half"])
        x0, z0, x1, z1 = site["x"] - hf, site["z"] - hf, site["x"] + hf, site["z"] + hf
    i0 = max(0, int((x0 - w.x0) // w.cell)); i1 = min(w.W - 1, int((x1 - w.x0) // w.cell) + 1)
    j0 = max(0, int((z0 - w.z0) // w.cell)); j1 = min(w.H - 1, int((z1 - w.z0) // w.cell) + 1)
    g = H[j0:j1 + 1, i0:i1 + 1]
    rows, cols = g.shape
    X, Z = np.meshgrid(w.x0 + np.arange(i0, i1 + 1) * w.cell, w.z0 + np.arange(j0, j1 + 1) * w.cell)
    verts = np.stack([X * s, -Z * s, g * s * zx], -1).reshape(-1, 3)
    idx = np.arange(rows * cols).reshape(rows, cols)
    faces = np.stack([idx[:-1, :-1].ravel(), idx[1:, :-1].ravel(), idx[1:, 1:].ravel(), idx[:-1, 1:].ravel()], -1)
    me = bpy.data.meshes.new("XY Terrain Edit")
    me.vertices.add(len(verts)); me.vertices.foreach_set("co", verts.ravel())
    me.loops.add(faces.size); me.loops.foreach_set("vertex_index", faces.ravel())
    me.polygons.add(len(faces)); me.polygons.foreach_set("loop_start", np.arange(0, faces.size, 4)); me.polygons.foreach_set("loop_total", np.full(len(faces), 4))
    me.update(calc_edges=True)
    h0 = me.attributes.new("h0", "FLOAT", "POINT"); h0.data.foreach_set("value", g.ravel().astype(np.float32))
    # the rock map (plan pixels → nearest vertex)
    plan_png = os.path.join(a["plan"], "lithology.png")
    ids = w.resample(litho_ids_from_rgb(read_png(plan_png)))[j0:j1 + 1, i0:i1 + 1] if os.path.exists(plan_png) else np.zeros_like(g, np.uint8)
    col = PALETTE[ids].reshape(-1, 3) / 255.0
    lit = me.color_attributes.new("Litho", "FLOAT_COLOR", "POINT")
    lit.data.foreach_set("color", np.concatenate([col, np.ones((len(col), 1))], 1).astype(np.float32).ravel())
    me.color_attributes.active_color = lit
    ob = bpy.data.objects.new("XY Terrain Edit", me)
    bpy.context.scene.collection.objects.link(ob)
    for k, v in {"xy_i0": i0, "xy_j0": j0, "xy_w": cols, "xy_h": rows, "xy_cell": w.cell, "xy_scale": s, "xy_zx": zx,
                 "xy_x0": w.x0, "xy_z0": w.z0, "xy_terrain": a["terrain"] or a["data"], "xy_data": a["data"], "xy_plan": a["plan"]}.items():
        ob[k] = v
    mat = bpy.data.materials.new("XY Litho")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "Litho"
    nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    me.materials.append(mat)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    print(f"terrain edit: {rows}×{cols} vertices, grid i {i0}…{i1}, j {j0}…{j1}")
    if a["out"]:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(a["out"]))


main()
