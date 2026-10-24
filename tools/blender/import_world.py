"""Bring a region of the exported Xiuxian world into Blender (4.2+ / 5.x).

    blender --background --python tools/blender/import_world.py -- --sect luoyun --out luoyun.blend
    blender --python tools/blender/import_world.py -- --region -2000,-5000,3000,0          # opens in the UI
    (or run it from Blender's Text Editor after setting ARGS below)

What it builds (all from godot/data/world, written by tools/export-world):
  Terrain      a grid mesh over the region from height_f16.bin (40-丈 grid) — or the sect's 13.3-丈 patch where there is
               one — with the demo's colour ramp (mountain_color.png) and the painted ground as a "Col" colour attribute
  Water        a plane at the demo's water level (−7 丈 inland, −20 at sea) clipped to the region
  GLBs         the sect / city / landmark meshes that touch the region (vertex layout: see facet.gdshader)
  Places       an empty per place (sect, city, mountain…) named after it, with the place id as a custom property
  Paths        roads and rivers as curves
  Trees        one point per tree with attributes kind / colour / yaw / scale, instanced by a Geometry Nodes modifier
               from the collection "XY Tree Kinds" (9 children, in kind order: pine, broadleaf, tall, 黄山松, willow,
               blossom, spirit, lotus, reeds). Replace those children with your asset-library trees and the whole
               forest updates — this is the hook for high-fidelity forests.

Scale: --scale is Blender units per 丈. The default 0.1 puts the world at the *model* scale of the asset pack: the demo
places pack models at 10 丈 per metre (PACK_M, L667), so at 0.1 a 1-m model in the pack is 1 Blender unit, i.e. your
Stylarts / Meadow assets drop in at their native size. Axes: demo/Godot (x, y up, z south) → Blender (x, −z, y), the same
conversion the glTF importer applies, so imported GLBs line up with the terrain.
"""
import json
import math
import os
import sys

import bpy
import numpy as np

try:
    HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:                                    # run from Blender's Text Editor: pass --data explicitly
    HERE = os.getcwd()
DEFAULT_DATA = os.path.normpath(os.path.join(HERE, "..", "..", "godot", "data", "world"))
KIND_NAMES = ["pine", "broadleaf", "tall", "huangshan_pine", "willow", "blossom", "spirit", "lotus", "reeds"]
TREE_COLS = ["#4e6d60", "#6a9573", "#b45a3e", "#c9a04c", "#52705f", "#77a884", "#c4d2d0", "#c6773b",
             "#dfa9b0", "#e6e3d8", "#8fb27a", "#8ccfbe", "#5f8a5a", "#a8a274", "#3f5e52", "#86ad6c"]


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    a = {"data": DEFAULT_DATA, "scale": 0.1, "region": None, "sect": None, "out": None, "trees": True, "glb": True, "step": 1}
    i = 0
    while i < len(argv):
        k = argv[i].lstrip("-")
        if k in ("no-trees", "no-glb"):
            a[k.replace("no-", "")] = False
            i += 1
            continue
        v = argv[i + 1]
        a[k] = v
        i += 2
    a["scale"] = float(a["scale"])
    a["step"] = int(a["step"])
    return a


def load(data, name):
    with open(os.path.join(data, name), encoding="utf-8") as f:
        return json.load(f)


def half_grid(path, w, h):
    return np.fromfile(path, dtype="<f2").astype(np.float32).reshape(h, w)


def image_rgba(path):
    img = bpy.data.images.load(path, check_existing=True)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, 4)[::-1]            # Blender stores images bottom-up; flip so row 0 = north (z0)


def to_bl(x, y, z, s):
    return (x * s, -z * s, y * s)


def new_collection(name, parent=None):
    c = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if c.name not in (parent or bpy.context.scene.collection).children:
        (parent or bpy.context.scene.collection).children.link(c)
    return c


def link(obj, coll):
    for c in obj.users_collection:
        c.objects.unlink(obj)
    coll.objects.link(obj)


def build_terrain(a, meta, R, root):
    data, s = a["data"], a["scale"]
    H = meta["height"]
    cell = H["cell"]
    heights = half_grid(os.path.join(data, H["raw"]["file"]), H["w"], H["h"])
    x0, z0 = H["x0"], H["z0"]
    i0 = max(0, int((R[0] - x0) // cell)); i1 = min(H["w"] - 1, int((R[2] - x0) // cell) + 1)
    j0 = max(0, int((R[1] - z0) // cell)); j1 = min(H["h"] - 1, int((R[3] - z0) // cell) + 1)
    grid, gx0, gz0, gcell = heights[j0:j1 + 1, i0:i1 + 1], x0 + i0 * cell, z0 + j0 * cell, cell
    # a sect patch covering the whole region is finer: use it
    for P in meta["patches"]:
        if P["x0"] <= R[0] and P["z0"] <= R[1] and P["x1"] >= R[2] and P["z1"] >= R[3]:
            ph = half_grid(os.path.join(data, P["raw"]), P["w"], P["h"])
            pi0 = max(0, int((R[0] - P["x0"]) // P["cell"])); pi1 = min(P["w"] - 1, int((R[2] - P["x0"]) // P["cell"]) + 1)
            pj0 = max(0, int((R[1] - P["z0"]) // P["cell"])); pj1 = min(P["h"] - 1, int((R[3] - P["z0"]) // P["cell"]) + 1)
            grid, gx0, gz0, gcell = ph[pj0:pj1 + 1, pi0:pi1 + 1], P["x0"] + pi0 * P["cell"], P["z0"] + pj0 * P["cell"], P["cell"]
            print("terrain: using the sect patch at", round(gcell, 2), "丈")
            break
    st = max(1, a["step"])
    grid = grid[::st, ::st]
    gcell *= st
    rows, cols = grid.shape
    xs = gx0 + np.arange(cols) * gcell
    zs = gz0 + np.arange(rows) * gcell
    X, Z = np.meshgrid(xs, zs)
    Y = np.maximum(grid, 0.0) * float(meta["config"]["terrain"].get("relief", 1))
    # under water the ground dives (the demo cuts the plain and drops earth banks)
    wt = image_rgba(os.path.join(data, meta["water"]["tex"]["file"]))
    wh, ww = wt.shape[:2]
    u = np.clip(((X - meta["rect"]["x0"]) / (meta["rect"]["x1"] - meta["rect"]["x0"]) * ww).astype(int), 0, ww - 1)
    v = np.clip(((Z - meta["rect"]["z0"]) / (meta["rect"]["z1"] - meta["rect"]["z0"]) * wh).astype(int), 0, wh - 1)
    sd = (wt[v, u, 0] * 255.0 - 128.0) * 2.0
    Y = np.where(Y <= 0.0, -26.0 * np.clip((sd + 6.0) / 20.0, 0.0, 1.0), Y)
    verts = np.stack([X * s, -Z * s, Y * s], axis=-1).reshape(-1, 3)
    idx = np.arange(rows * cols).reshape(rows, cols)
    a_, b_, c_, d_ = idx[:-1, :-1].ravel(), idx[:-1, 1:].ravel(), idx[1:, 1:].ravel(), idx[1:, :-1].ravel()
    faces = np.stack([a_, d_, c_, b_], axis=-1)            # winding for +Z normals after the −z flip
    me = bpy.data.meshes.new("XY Terrain")
    me.vertices.add(len(verts)); me.vertices.foreach_set("co", verts.ravel())
    me.loops.add(faces.size); me.loops.foreach_set("vertex_index", faces.ravel())
    me.polygons.add(len(faces)); me.polygons.foreach_set("loop_start", np.arange(0, faces.size, 4)); me.polygons.foreach_set("loop_total", np.full(len(faces), 4))
    me.update(calc_edges=True)
    # colour: the mountains' ramp where there are mountains, a plain green elsewhere
    mc = image_rgba(os.path.join(data, meta["mountainColor"]["file"]))
    mh, mw = mc.shape[:2]
    mi = np.clip(np.round((X - x0) / cell).astype(int), 0, mw - 1); mj = np.clip(np.round((Z - z0) / cell).astype(int), 0, mh - 1)
    col = mc[mj, mi, :3]
    plain = np.array([0.616, 0.69, 0.541], dtype=np.float32)
    k = np.clip((Y - 1.0) / 13.0, 0.0, 1.0)[..., None] * (mc[mj, mi, 3:4] > 0.5)
    col = plain * (1 - k) + col * k
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    rgba = np.concatenate([col.reshape(-1, 3), np.ones((rows * cols, 1), dtype=np.float32)], axis=1)
    attr.data.foreach_set("color", rgba.ravel())
    ob = bpy.data.objects.new("XY Terrain", me)
    link(ob, root)
    mat = bpy.data.materials.get("XY Vertex Colour") or bpy.data.materials.new("XY Vertex Colour")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    if bsdf and not any(n.type == "VERTEX_COLOR" for n in nt.nodes):
        vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "Col"
        nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 1.0
    me.materials.append(mat)
    print("terrain:", rows, "×", cols, "vertices")
    return ob


def build_water(a, meta, R, root):
    s = a["scale"]
    me = bpy.data.meshes.new("XY Water")
    level = -float(meta["config"]["water"].get("depth", 7))
    vs = [to_bl(R[0], level, R[1], s), to_bl(R[2], level, R[1], s), to_bl(R[2], level, R[3], s), to_bl(R[0], level, R[3], s)]
    me.from_pydata(vs, [], [(0, 3, 2, 1)])
    ob = bpy.data.objects.new("XY Water", me)
    mat = bpy.data.materials.get("XY Water") or bpy.data.materials.new("XY Water")
    mat.diffuse_color = (0.451, 0.694, 0.737, 0.85)
    me.materials.append(mat)
    link(ob, root)


def import_glbs(a, meta, R, root):
    s = a["scale"]
    coll = new_collection("XY Architecture", root)
    for f in meta.get("meshes", {}).get("files", []):
        path = os.path.join(a["data"], f["file"])
        name = os.path.basename(f["file"])
        if name == "terrain.glb" or not os.path.exists(path):
            continue
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path, merge_vertices=False)
        new = [o for o in bpy.data.objects if o not in before]
        keep = False
        for o in new:
            if o.parent is None:                 # scale the roots only: children inherit it
                o.scale = (o.scale[0] * s, o.scale[1] * s, o.scale[2] * s); o.location = (o.location[0] * s, o.location[1] * s, o.location[2] * s)
        bpy.context.view_layer.update()
        for o in new:
            vs = o.data.vertices if o.type == "MESH" else []
            bb = [o.matrix_world @ vs[i].co for i in range(0, len(vs), max(1, len(vs) // 64))]
            if any(R[0] * s <= p.x <= R[2] * s and -R[3] * s <= p.y <= -R[1] * s for p in bb):
                keep = True
        if keep:
            for o in new:
                link(o, coll)
            print("glb:", name)
        else:
            for o in new:
                bpy.data.objects.remove(o, do_unlink=True)


def build_places(a, R, root):
    s = a["scale"]
    coll = new_collection("XY Places", root)
    for p in load(a["data"], "places.json"):
        x, z = p["pos"][0], p["pos"][2]
        if not (R[0] <= x <= R[2] and R[1] <= z <= R[3]):
            continue
        e = bpy.data.objects.new(p["name"], None)
        e.empty_display_type = "SINGLE_ARROW"; e.empty_display_size = 60 * s
        e.location = to_bl(x, float(p.get("labelY", 60)), z, s)
        e["place_id"] = p["id"]; e["category"] = p["cat"]
        link(e, coll)


def build_paths(a, R, root):
    s = a["scale"]
    coll = new_collection("XY Paths", root)
    P = load(a["data"], "paths.json")
    for kind in ("roads", "rivers", "streams"):
        cu = bpy.data.curves.new("XY " + kind, "CURVE"); cu.dimensions = "3D"
        n = 0
        for r in P[kind]:
            pts = [p for p in r["pts"] if R[0] <= p[0] <= R[2] and R[1] <= p[1] <= R[3]]
            if len(pts) < 2:
                continue
            sp = cu.splines.new("POLY"); sp.points.add(len(pts) - 1)
            for i, p in enumerate(pts):
                y = p[2] if len(p) > 2 else 1.0
                sp.points[i].co = (*to_bl(p[0], y, p[1], s), 1.0)
            n += 1
        if n:
            link(bpy.data.objects.new("XY " + kind, cu), coll)


def tree_kinds_collection(root, s):
    """Nine placeholder trees (cones / ico blobs), in kind order — replace the children with real assets."""
    coll = bpy.data.collections.get("XY Tree Kinds")
    if coll:
        return coll
    coll = new_collection("XY Tree Kinds", root)
    coll.hide_render = True
    for k, name in enumerate(KIND_NAMES):
        h = 22.0 * s
        if name in ("pine", "huangshan_pine", "tall"):
            bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=6 * s if name != "tall" else 3.5 * s, depth=h, location=(0, 0, h / 2))
        elif name in ("lotus",):
            bpy.ops.mesh.primitive_cylinder_add(vertices=7, radius=3 * s, depth=0.4 * s, location=(0, 0, 0.2 * s))
        elif name in ("reeds",):
            bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.5 * s, depth=9 * s, location=(0, 0, 4.5 * s))
        else:
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=8 * s, location=(0, 0, 13 * s))
        o = bpy.context.active_object
        o.name = f"{k}_{name}"
        link(o, coll)
        o.location.x = k * 40 * s               # spread out (Separate Children resets the positions on instancing)
    return coll


def build_trees(a, meta, R, root):
    s = a["scale"]
    T = meta["trees"]
    raw = np.fromfile(os.path.join(a["data"], T["file"]), dtype=np.uint8).reshape(-1, 8)
    rect = meta["rect"]
    xs = rect["x0"] + raw[:, 0:2].copy().view("<u2")[:, 0] / 65535.0 * (rect["x1"] - rect["x0"])
    zs = rect["z0"] + raw[:, 2:4].copy().view("<u2")[:, 0] / 65535.0 * (rect["z1"] - rect["z0"])
    m = (xs >= R[0]) & (xs <= R[2]) & (zs >= R[1]) & (zs <= R[3])
    if not m.any():
        return
    xs, zs, sel = xs[m], zs[m], raw[m]
    # plant them on the heightfield (bilinear on the 40-丈 grid; the sect patches are finer but this is close enough to snap later)
    H = meta["height"]
    heights = half_grid(os.path.join(a["data"], H["raw"]["file"]), H["w"], H["h"])
    fx = np.clip((xs - H["x0"]) / H["cell"], 0, H["w"] - 1.001); fz = np.clip((zs - H["z0"]) / H["cell"], 0, H["h"] - 1.001)
    i, j = fx.astype(int), fz.astype(int); tx, tz = fx - i, fz - j
    ys = (heights[j, i] * (1 - tx) + heights[j, i + 1] * tx) * (1 - tz) + (heights[j + 1, i] * (1 - tx) + heights[j + 1, i + 1] * tx) * tz
    ys = np.maximum(ys, 0.0) - 0.3
    verts = np.stack([xs * s, -zs * s, ys * s], axis=-1).astype(np.float32)
    me = bpy.data.meshes.new("XY Trees")
    me.vertices.add(len(verts)); me.vertices.foreach_set("co", verts.ravel())
    for name, vals, typ in (("kind", sel[:, 4].astype(np.int32), "INT"), ("colour", sel[:, 5].astype(np.int32), "INT"),
                            ("yaw", sel[:, 6] / 256.0 * 2 * math.pi, "FLOAT"), ("scale", sel[:, 7] / 255.0 * T["scaleMax"], "FLOAT")):
        at = me.attributes.new(name, typ, "POINT")
        at.data.foreach_set("value", vals.astype(np.int32 if typ == "INT" else np.float32))
    ob = bpy.data.objects.new("XY Trees", me)
    link(ob, root)
    kinds = tree_kinds_collection(root, s)
    # Geometry Nodes: instance the kind's tree on every point, yawed and scaled
    ng = bpy.data.node_groups.new("XY Forest", "GeometryNodeTree")
    ng.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    ng.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    N, L = ng.nodes, ng.links
    gi, go = N.new("NodeGroupInput"), N.new("NodeGroupOutput")
    ci = N.new("GeometryNodeCollectionInfo"); ci.inputs["Collection"].default_value = kinds
    ci.inputs["Separate Children"].default_value = True; ci.inputs["Reset Children"].default_value = True
    iop = N.new("GeometryNodeInstanceOnPoints"); iop.inputs["Pick Instance"].default_value = True
    def named(name, typ):
        n = N.new("GeometryNodeInputNamedAttribute"); n.data_type = typ; n.inputs["Name"].default_value = name
        return n
    kind_a, yaw_a, scale_a = named("kind", "INT"), named("yaw", "FLOAT"), named("scale", "FLOAT")
    comb = N.new("ShaderNodeCombineXYZ")
    L.new(yaw_a.outputs["Attribute"], comb.inputs["Z"])
    eul = N.new("FunctionNodeEulerToRotation")
    L.new(comb.outputs["Vector"], eul.inputs["Euler"])
    real = N.new("GeometryNodeRealizeInstances")
    L.new(gi.outputs[0], iop.inputs["Points"])
    L.new(ci.outputs["Instances"], iop.inputs["Instance"])
    L.new(kind_a.outputs["Attribute"], iop.inputs["Instance Index"])
    L.new(eul.outputs["Rotation"], iop.inputs["Rotation"])
    L.new(scale_a.outputs["Attribute"], iop.inputs["Scale"])
    L.new(iop.outputs["Instances"], go.inputs[0])
    real.mute = True   # unmute to make the forest real geometry (heavy)
    mod = ob.modifiers.new("XY Forest", "NODES"); mod.node_group = ng
    print("trees:", len(verts))


def main():
    a = parse_args()
    meta = load(a["data"], "meta.json")
    if a["sect"]:
        S = next(x for x in load(a["data"], "layout.json")["sites"] if x["id"] == a["sect"])
        r = float(S["R"]) * 1.6
        R = [S["x"] - r, S["z"] - r, S["x"] + r, S["z"] + r]
        for P in meta["patches"]:                       # the sect's own fine ground: use its rect, so the 13.3-丈 patch is used
            if P["x0"] < S["x"] < P["x1"] and P["z0"] < S["z"] < P["z1"]:
                R = [P["x0"] + 1, P["z0"] + 1, P["x1"] - 1, P["z1"] - 1]
    elif a["region"]:
        R = [float(v) for v in a["region"].split(",")]
    else:
        raise SystemExit("give --sect <id> or --region x0,z0,x1,z1 (丈)")
    print("region (丈):", [round(v) for v in R], "scale", a["scale"], "BU/丈")
    root = new_collection("XY World")
    build_terrain(a, meta, R, root)
    build_water(a, meta, R, root)
    if a["glb"]:
        import_glbs(a, meta, R, root)
    build_places(a, R, root)
    build_paths(a, R, root)
    if a["trees"]:
        build_trees(a, meta, R, root)
    if a["out"]:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(a["out"]))
        print("saved", a["out"])


if __name__ == "__main__":
    main()
