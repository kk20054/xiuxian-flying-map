"""Give Blender meshes the demo's ink-line vertex layout, so they render with godot/shaders/facet.gdshader exactly like the
exported sect meshes (crisp ~1-px ink on chosen edges, none on flat diagonals).

    blender my_hall.blend --background --python tools/blender/bake_ink_layout.py -- --angle 25 --out my_hall_ink.glb
    (or select objects in the UI and run it from the Text Editor; with no --out it only writes the attributes)

Per mesh it: triangulates a copy, un-shares every corner (barycentric ink needs each triangle's own three corners), and
writes the layout facet.gdshader reads:
    COLOR_0.rgb  face colour (the material's base colour, or an existing "Col" colour attribute), COLOR_0.a = ink weight
                 of the edge opposite corner C
    UV  (TEXCOORD_0)  barycentric (x, y) of the corner: A = (1, 0), B = (0, 1), C = (0, 0)
    UV1 (TEXCOORD_1)  ink weights of the edges opposite corners A and B
Ink weight of an edge: 1.0 if it is marked Freestyle or Sharp, or the faces meet at more than --angle degrees, or it is a
boundary (an outline); 0.0 on flat interior edges (quad diagonals, coplanar splits). The demo uses 0.35–0.9 by part
(roof ridges strong, wall panels light): paint a float face attribute "ink" (0..1) to scale it per face.
"""
import math
import os
import sys

import bpy
import bmesh


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    a = {"angle": 25.0, "out": None}
    for i in range(0, len(argv) - 1, 2):
        a[argv[i].lstrip("-")] = argv[i + 1]
    a["angle"] = float(a["angle"])
    return a


def to_srgb(c):
    """Blender colours are scene-linear; the facet shader (like the demo) works on display-space values."""
    return [12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055 for x in c]


def face_colour(ob, bm, f, col_layer):
    if col_layer is not None:
        c = [0.0, 0.0, 0.0]
        for loop in f.loops:
            v = loop[col_layer]
            c = [c[k] + v[k] for k in range(3)]
        return [x / len(f.loops) for x in c]
    if f.material_index < len(ob.material_slots) and ob.material_slots[f.material_index].material:
        m = ob.material_slots[f.material_index].material
        bsdf = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
        if bsdf:
            return list(bsdf.inputs["Base Color"].default_value)[:3]
        return list(m.diffuse_color)[:3]
    return [0.8, 0.8, 0.8]


def bake(ob, angle_deg):
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.normal_update()
    thr = math.radians(angle_deg)
    fs_layer = bm.edges.layers.int.get("freestyle_edge")
    col_layer = bm.loops.layers.float_color.get("Col") or bm.loops.layers.color.get("Col")
    ink_layer = bm.faces.layers.float.get("ink")

    def edge_ink(e):
        if len(e.link_faces) < 2:
            return 1.0
        if not e.smooth or (fs_layer is not None and e[fs_layer]):
            return 1.0
        a = e.link_faces[0].normal.angle(e.link_faces[1].normal, 0.0)
        return 1.0 if a > thr else 0.0

    # gather the unshared corner soup
    tris = []
    for f in bm.faces:
        v = [l.vert.co.copy() for l in f.loops]
        # edge opposite corner i joins the other two corners
        opp = []
        for i in range(3):
            a_, b_ = f.loops[(i + 1) % 3].vert, f.loops[(i + 2) % 3].vert
            e = next(e for e in f.edges if set(e.verts) == {a_, b_})
            opp.append(edge_ink(e) * (f[ink_layer] if ink_layer is not None else 1.0))
        tris.append((v, to_srgb(face_colour(ob, bm, f, col_layer)), opp))
    bm.free()

    new = bpy.data.meshes.new(me.name + "_ink")
    verts, faces = [], []
    for t, (v, _, _) in enumerate(tris):
        verts.extend(v)
        faces.append((3 * t, 3 * t + 1, 3 * t + 2))
    new.from_pydata([tuple(p) for p in verts], [], faces)
    uv0 = new.uv_layers.new(name="UVMap")
    uv1 = new.uv_layers.new(name="UVMap.001")
    col = new.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    bary = [(1.0, 0.0), (0.0, 1.0), (0.0, 0.0)]
    for t, (_, c, opp) in enumerate(tris):
        for i in range(3):
            li = 3 * t + i
            uv0.data[li].uv = bary[i]
            uv1.data[li].uv = (opp[0], opp[1])
            col.data[li].color = (c[0], c[1], c[2], opp[2])
    new.materials.clear()
    for slot in ob.material_slots:
        new.materials.append(slot.material)
    ob.data = new
    return len(tris)


def main():
    a = args()
    obs = [o for o in (bpy.context.selected_objects or bpy.context.scene.objects) if o.type == "MESH"]
    total = 0
    for ob in obs:
        total += bake(ob, a["angle"])
    print("ink layout written:", len(obs), "meshes,", total, "triangles")
    if a["out"]:
        bpy.ops.export_scene.gltf(filepath=os.path.abspath(a["out"]), export_format="GLB", use_selection=False,
                                  export_attributes=True, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
        print("exported", a["out"])


if __name__ == "__main__":
    main()
