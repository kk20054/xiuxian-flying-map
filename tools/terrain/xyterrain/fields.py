"""Small raster helpers shared by the operators: smoothstep, separable min/max filters, slope, blur, nearest-source map."""
import numpy as np

from .flow import njit
from .geology import box_blur  # noqa: F401  (re-exported)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


@njit(cache=True)
def _run_minmax(a, r, axis, take_max):
    H, W = a.shape
    out = np.empty_like(a)
    if axis == 1:
        for j in range(H):
            for i in range(W):
                v = a[j, i]
                for d in range(max(0, i - r), min(W, i + r + 1)):
                    x = a[j, d]
                    if (x > v) if take_max else (x < v):
                        v = x
                out[j, i] = v
    else:
        for j in range(H):
            for i in range(W):
                v = a[j, i]
                for d in range(max(0, j - r), min(H, j + r + 1)):
                    x = a[d, i]
                    if (x > v) if take_max else (x < v):
                        v = x
                out[j, i] = v
    return out


def min_filter(a, r):
    """Square min filter of radius r cells (separable)."""
    a = np.ascontiguousarray(a, np.float64)
    return _run_minmax(_run_minmax(a, r, 1, False), r, 0, False)


def max_filter(a, r):
    a = np.ascontiguousarray(a, np.float64)
    return _run_minmax(_run_minmax(a, r, 1, True), r, 0, True)


def slope(h, cell):
    gz, gx = np.gradient(h, cell)
    return np.hypot(gx, gz)


def local_base(h, r_cells, blur=None):
    """The level the land drains to locally: a min filter (valley floors) smoothed — the water table for karst, the
    plain a mesa rises from. r ≈ half the spacing of the main valleys."""
    b = min_filter(h, r_cells)
    return box_blur(b, blur or max(1, r_cells // 2))


@njit(cache=True)
def nearest_source(mask, cell):
    """Chamfer distance to the nearest True cell AND that cell's flat index (to read its height / area)."""
    H, W = mask.shape
    INF = 1e18
    d = np.full((H, W), INF)
    src = np.full((H, W), -1, np.int64)
    for j in range(H):
        for i in range(W):
            if mask[j, i]:
                d[j, i] = 0.0; src[j, i] = j * W + i
    a, b = cell, cell * 1.41421356
    for j in range(H):
        for i in range(W):
            for dj, di, w in ((0, -1, a), (-1, 0, a), (-1, -1, b), (-1, 1, b)):
                jj = j + dj; ii = i + di
                if 0 <= jj and 0 <= ii < W and d[jj, ii] + w < d[j, i]:
                    d[j, i] = d[jj, ii] + w; src[j, i] = src[jj, ii]
    for j in range(H - 1, -1, -1):
        for i in range(W - 1, -1, -1):
            for dj, di, w in ((0, 1, a), (1, 0, a), (1, 1, b), (1, -1, b)):
                jj = j + dj; ii = i + di
                if jj < H and 0 <= ii < W and d[jj, ii] + w < d[j, i]:
                    d[j, i] = d[jj, ii] + w; src[j, i] = src[jj, ii]
    return d, src


def rotate(X, Z, deg, cx=0.0, cz=0.0):
    c, s = np.cos(np.radians(deg)), np.sin(np.radians(deg))
    return (X - cx) * c + (Z - cz) * s, -(X - cx) * s + (Z - cz) * c
