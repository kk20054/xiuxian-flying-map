"""Read the exported world (godot/data/world, written by tools/export-world) and write terrain back in the same formats.

Height grid: node-centred, sample (i, j) at (x0 + i·cell, z0 + j·cell), cell = 40 丈, W×H = 3296×2005, heights in 丈.
Other rasters (water, biome…) are cell-centred over meta.rect; `resample()` maps them onto the height grid.
"""
import json
import os
import struct
import zlib

import numpy as np

try:
    from PIL import Image
except ImportError:                                  # Blender's Python has no PIL: PNGs are read/written by hand
    Image = None


def read_png(path):
    """8- or 16-bit grey/RGB(A) PNG → numpy (uint8 or uint16, rows top-down). PIL if present, else a minimal decoder."""
    if Image is not None:
        im = Image.open(path)
        if im.mode in ("I;16", "I;16B", "I"):
            return np.array(im).astype(np.uint16)
        return np.array(im)
    with open(path, "rb") as f:
        data = f.read()
    pos, idat, hdr = 8, b"", None
    while pos < len(data):
        n, typ = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if typ == b"IHDR":
            hdr = struct.unpack(">IIBBBBB", body)
        elif typ == b"IDAT":
            idat += body
        pos += 12 + n
    w, h, depth, ctype = hdr[:4]
    ch = {0: 1, 2: 3, 4: 2, 6: 4}[ctype]
    bpp = ch * depth // 8
    raw = zlib.decompress(idat)
    stride = w * bpp
    out = np.zeros((h, stride), np.uint8)
    prev = np.zeros(stride, np.int32)
    for y in range(h):
        ft = raw[y * (stride + 1)]
        line = np.frombuffer(raw, np.uint8, stride, y * (stride + 1) + 1).astype(np.int32)
        if ft == 1:
            line = line.copy()
            for x in range(bpp, stride):
                line[x] = (line[x] + line[x - bpp]) & 255
        elif ft == 2:
            line = (line + prev) & 255
        elif ft == 3:
            line = line.copy()
            for x in range(stride):
                a = line[x - bpp] if x >= bpp else 0
                line[x] = (line[x] + (a + prev[x]) // 2) & 255
        elif ft == 4:
            line = line.copy()
            for x in range(stride):
                a = line[x - bpp] if x >= bpp else 0
                c = prev[x - bpp] if x >= bpp else 0
                p = a + prev[x] - c
                pa, pb, pc = abs(p - a), abs(p - prev[x]), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else prev[x] if pb <= pc else c)) & 255
        out[y] = line
        prev = line
    if depth == 16:
        arr = out.view(">u2").astype(np.uint16).reshape(h, w, ch)
    else:
        arr = out.reshape(h, w, ch)
    return arr[..., 0] if ch == 1 else arr


def write_png(path, arr):
    """uint8 (H,W[,3|4]) or uint16 (H,W) → PNG, no dependencies (16-bit is big-endian as the format requires)."""
    arr = np.ascontiguousarray(arr)
    h, w = arr.shape[:2]
    ch = 1 if arr.ndim == 2 else arr.shape[2]
    depth = 16 if arr.dtype == np.uint16 else 8
    ctype = {1: 0, 3: 2, 4: 6}[ch]
    rows = arr.astype(">u2").tobytes() if depth == 16 else arr.tobytes()
    stride = w * ch * depth // 8
    raw = b"".join(b"\0" + rows[y * stride:(y + 1) * stride] for y in range(h))

    def chunk(t, b):
        return struct.pack(">I", len(b)) + t + b + struct.pack(">I", zlib.crc32(t + b) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, depth, ctype, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


class World:
    def __init__(self, data_dir):
        self.dir = data_dir
        self.meta = self.json("meta.json")
        self.layout = self.json("layout.json")
        self.places = self.json("places.json")
        H = self.meta["height"]
        self.W, self.H, self.cell = H["w"], H["h"], float(H["cell"])
        self.x0, self.z0 = float(H["x0"]), float(H["z0"])
        self.rect = self.meta["rect"]
        self.height = np.fromfile(self.path(H["raw"]["file"]), "<f2").astype(np.float32).reshape(self.H, self.W)
        self._xz = None

    def path(self, name):
        return os.path.join(self.dir, name)

    def json(self, name):
        with open(self.path(name), encoding="utf-8") as f:
            return json.load(f)

    @property
    def xz(self):
        """World x and z of every height sample (two (H,W) arrays)."""
        if self._xz is None:
            xs = self.x0 + np.arange(self.W) * self.cell
            zs = self.z0 + np.arange(self.H) * self.cell
            self._xz = np.meshgrid(xs, zs)
        return self._xz

    def ij(self, x, z):
        return (np.asarray(x) - self.x0) / self.cell, (np.asarray(z) - self.z0) / self.cell

    def resample(self, arr):
        """A cell-centred raster over meta.rect (any size) → the height grid, nearest sample."""
        h, w = arr.shape[:2]
        X, Z = self.xz
        R = self.rect
        u = np.clip(((X - R["x0"]) / (R["x1"] - R["x0"]) * w).astype(np.int64), 0, w - 1)
        v = np.clip(((Z - R["z0"]) / (R["z1"] - R["z0"]) * h).astype(np.int64), 0, h - 1)
        return arr[v, u]

    # ---- the layout's fixed parts ------------------------------------------------------------------------------
    def water(self):
        """(water bool, signed distance to the shore in 丈, + inside water) on the height grid."""
        sd16 = read_png(self.path(self.meta["water"]["sd"]["file"]))
        sd = (self.resample(sd16).astype(np.float32) - 32768.0) / 8.0
        mask = read_png(self.path(self.meta["water"]["mask"]["file"]))
        if mask.ndim == 3:
            mask = mask[..., 0]
        wet = self.resample(mask) > 127
        return wet | (sd > 0), sd

    def sites(self):
        return self.layout["sites"]

    def marks(self):
        return self.layout["marks"]

    def cities(self):
        return [p for p in self.places if p.get("cat") == "city"]

    def patch_rects(self):
        return [(p["x0"], p["z0"], p["x1"], p["z1"]) for p in self.meta["patches"]]

    def place_xz(self, p):
        """World position of a place: its own x/z, else its sect or mark."""
        if "x" in p:
            return p["x"], p["z"]
        at = p.get("at")
        if at in self.layout["sects"]:
            s = self.layout["sects"][at]
            return s["x"], s["z"]
        for m in self.layout["marks"]:
            if m["id"] == at:
                return m["x"], m["z"]
        if "pos" in p:
            return p["pos"][0], p["pos"][2]
        return None

    def preserve_mask(self, pad=420.0, feather=900.0, city_r=1700.0, mark_r=0.0):
        """Weight 1 where the existing ground must stay (sect patches + pad, city cores), fading to 0 over `feather`.
        The Godot port and the Blender importer cut the terrain inside the patch rects and use the sects' own meshes,
        so the land round them has to meet those meshes."""
        X, Z = self.xz
        d = np.full(X.shape, 1e9, np.float32)
        for (x0, z0, x1, z1) in self.patch_rects():
            dx = np.maximum(np.maximum(x0 - pad - X, X - x1 - pad), 0)
            dz = np.maximum(np.maximum(z0 - pad - Z, Z - z1 - pad), 0)
            d = np.minimum(d, np.hypot(dx, dz))
        for c in self.cities():
            xz = self.place_xz(c)
            if xz:
                d = np.minimum(d, np.maximum(np.hypot(X - xz[0], Z - xz[1]) - city_r, 0))
        if mark_r > 0:
            for m in self.marks():
                d = np.minimum(d, np.maximum(np.hypot(X - m["x"], Z - m["z"]) - mark_r, 0))
        t = np.clip(d / feather, 0, 1)
        return (1 - t * t * (3 - 2 * t)).astype(np.float32)

    # ---- output ------------------------------------------------------------------------------------------------
    def save_height(self, out_dir, h, extra_meta=None):
        """height_f16.bin (what Godot reads) + height.png (16-bit, for Blender / Terrain3D) + terrain.json."""
        os.makedirs(out_dir, exist_ok=True)
        h = h.astype(np.float32)
        h.astype("<f2").tofile(os.path.join(out_dir, "height_f16.bin"))
        top = float(max(1.0, np.ceil(h.max())))
        write_png(os.path.join(out_dir, "height.png"), (np.clip(h, 0, None) / top * 65535 + 0.5).astype(np.uint16))
        info = {"w": self.W, "h": self.H, "cell": self.cell, "x0": self.x0, "z0": self.z0, "max": top,
                "min": float(h.min()), "raw": "height_f16.bin", "png": "height.png",
                "encoding": "height_f16.bin: IEEE half LE, row-major W×H, 丈; height.png: uint16, h = v/65535·max (≥ 0 only)"}
        info.update(extra_meta or {})
        with open(os.path.join(out_dir, "terrain.json"), "w", encoding="utf-8") as f:
            json.dump(info, f, ensure_ascii=False, indent=1)
