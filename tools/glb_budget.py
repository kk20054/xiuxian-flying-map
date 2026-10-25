"""Triangle / draw-call / material / texture inventory of GLB files — checks a sect against its budget
(docs/godot/04-sects-and-spirit-tree-plan.md §2.2).

    python3 tools/glb_budget.py                                   # every GLB of the exported world
    python3 tools/glb_budget.py godot/sects/luoyun/*.glb          # a rebuilt sect
    python3 tools/glb_budget.py sect_luoyun.glb --lod0 250000     # flag a LOD0 over budget

Per file: triangles, primitives (≈ draw calls before batching), meshes, materials, textures (count and stored bytes),
file size; nodes named *_LOD0 / *_LOD1 / *_LOD2 are counted per LOD level. No dependencies beyond Python 3.
"""
import argparse
import glob
import json
import os
import re
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
BUDGET = {0: 250_000, 1: 60_000, 2: 8_000}


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, _, _ = struct.unpack("<4sII", data[:12])
    if magic != b"glTF":
        raise ValueError("not a GLB")
    n = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20:20 + n])


def tris_of(gltf, mesh):
    t = 0
    for p in mesh["primitives"]:
        if p.get("mode", 4) != 4:
            continue
        acc = gltf["accessors"][p["indices"]] if "indices" in p else gltf["accessors"][p["attributes"]["POSITION"]]
        t += acc["count"] // 3
    return t


def inventory(path):
    g = read_glb(path)
    meshes = g.get("meshes", [])
    mtris = [tris_of(g, m) for m in meshes]
    lod = {}
    for node in g.get("nodes", []):
        if "mesh" not in node:
            continue
        m = re.search(r"_LOD(\d)", node.get("name", ""))
        k = int(m.group(1)) if m else None
        lod[k] = lod.get(k, 0) + mtris[node["mesh"]]
    tex_bytes = 0
    for img in g.get("images", []):
        if "bufferView" in img:
            tex_bytes += g["bufferViews"][img["bufferView"]]["byteLength"]
    return {"file": os.path.basename(path), "tris": sum(lod.values()) or sum(mtris),
            "prims": sum(len(m["primitives"]) for m in meshes), "meshes": len(meshes),
            "materials": len(g.get("materials", [])), "textures": len(g.get("images", [])), "tex_mb": tex_bytes / 1e6,
            "mb": os.path.getsize(path) / 1e6, "lod": lod}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--lod0", type=int, default=BUDGET[0])
    a = ap.parse_args()
    files = a.files or sorted(glob.glob(os.path.join(HERE, "..", "godot", "data", "world", "meshes", "*.glb")))
    budget = dict(BUDGET); budget[0] = a.lod0
    print(f"{'file':34s} {'tris':>9s} {'prims':>6s} {'mats':>5s} {'tex':>4s} {'tex MB':>7s} {'MB':>6s}  LODs")
    tot = 0
    for f in files:
        r = inventory(f)
        tot += r["tris"]
        lods = "  ".join(f"LOD{k} {v / 1000:.0f}k{' OVER' if v > budget.get(k, 1e12) else ''}"
                         for k, v in sorted(r["lod"].items(), key=lambda kv: (kv[0] is None, kv[0])) if k is not None)
        print(f"{r['file']:34s} {r['tris']:9d} {r['prims']:6d} {r['materials']:5d} {r['textures']:4d} {r['tex_mb']:7.1f} {r['mb']:6.1f}  {lods}")
    print(f"{'total':34s} {tot:9d}")


if __name__ == "__main__":
    main()
