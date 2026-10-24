"""Deterministic noise on numpy arrays: 2-D simplex, fbm, ridged multifractal, domain warp, Worley (cellular).

All functions take world coordinates already divided by a feature scale, and a seed. Same seed → same terrain.
"""
import numpy as np

from .flow import njit

_F2 = 0.5 * (np.sqrt(3.0) - 1.0)
_G2 = (3.0 - np.sqrt(3.0)) / 6.0
_GRAD = np.array([[1, 1], [-1, 1], [1, -1], [-1, -1], [1, 0], [-1, 0], [0, 1], [0, -1]], np.float64)


def _perm(seed):
    p = np.random.default_rng(seed).permutation(256)
    return np.concatenate([p, p]).astype(np.int64)


@njit(cache=True)
def _simplex(x, y, perm):
    out = np.empty(x.size)
    xf = x.ravel(); yf = y.ravel()
    for k in range(x.size):
        s = (xf[k] + yf[k]) * _F2
        i = np.floor(xf[k] + s); j = np.floor(yf[k] + s)
        t = (i + j) * _G2
        x0 = xf[k] - (i - t); y0 = yf[k] - (j - t)
        if x0 > y0:
            i1, j1 = 1, 0
        else:
            i1, j1 = 0, 1
        x1 = x0 - i1 + _G2; y1 = y0 - j1 + _G2
        x2 = x0 - 1.0 + 2.0 * _G2; y2 = y0 - 1.0 + 2.0 * _G2
        ii = int(i) & 255; jj = int(j) & 255
        n = 0.0
        t0 = 0.5 - x0 * x0 - y0 * y0
        if t0 > 0:
            g = perm[ii + perm[jj]] & 7
            n += t0 ** 4 * (_GRAD[g, 0] * x0 + _GRAD[g, 1] * y0)
        t1 = 0.5 - x1 * x1 - y1 * y1
        if t1 > 0:
            g = perm[ii + i1 + perm[jj + j1]] & 7
            n += t1 ** 4 * (_GRAD[g, 0] * x1 + _GRAD[g, 1] * y1)
        t2 = 0.5 - x2 * x2 - y2 * y2
        if t2 > 0:
            g = perm[ii + 1 + perm[jj + 1]] & 7
            n += t2 ** 4 * (_GRAD[g, 0] * x2 + _GRAD[g, 1] * y2)
        out[k] = 70.0 * n
    return out.reshape(x.shape)


def simplex(x, y, seed=0):
    """2-D simplex noise in about [−1, 1]."""
    x = np.asarray(x, np.float64); y = np.asarray(y, np.float64)
    x, y = np.broadcast_arrays(x, y)
    return _simplex(np.ascontiguousarray(x), np.ascontiguousarray(y), _perm(seed))


def fbm(x, y, octaves=4, seed=0, lac=2.03, gain=0.5):
    a, f, tot, norm = 1.0, 1.0, 0.0, 0.0
    for o in range(octaves):
        tot = tot + a * simplex(x * f + 19.1 * o, y * f - 7.7 * o, seed + o)
        norm += a; a *= gain; f *= lac
    return tot / norm


def ridged(x, y, octaves=4, seed=0, lac=2.07, gain=0.52):
    """Ridged multifractal (Musgrave): sharp crests in about [0, 1]; weight feedback keeps valleys smooth."""
    a, f, w, tot, norm = 1.0, 1.0, 1.0, 0.0, 0.0
    for o in range(octaves):
        s = (1.0 - np.abs(simplex(x * f + 3.1 * o, y * f + 5.3 * o, seed + 11 * o))) ** 2 * w
        w = np.clip(2.0 * s, 0.0, 1.0)
        tot = tot + a * s
        norm += a; a *= gain; f *= lac
    return tot / norm


def warp(x, y, amount, scale, seed=0):
    """Domain warp: (x, y) displaced by a smooth noise field (same units as x, y)."""
    return (x + amount * fbm(x / scale + 4.7, y / scale - 1.3, 2, seed + 101),
            y + amount * fbm(x / scale - 8.1, y / scale + 2.9, 2, seed + 202))


@njit(cache=True)
def _hash(i, j, seed):
    h = (i * 374761393 + j * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFFFF) / 16777216.0


@njit(cache=True)
def worley(x, y, jitter, seed):
    """Cellular noise on a unit jittered grid. Returns f1, f2 (distances to the nearest / second feature points),
    the nearest point's cell id (as a float hash in [0,1)) and its position (px, py)."""
    n = x.size
    xf = x.ravel(); yf = y.ravel()
    f1 = np.empty(n); f2 = np.empty(n); cid = np.empty(n); px = np.empty(n); py = np.empty(n)
    for k in range(n):
        ci = int(np.floor(xf[k])); cj = int(np.floor(yf[k]))
        b1 = 1e9; b2 = 1e9; bid = 0.0; bx = 0.0; by = 0.0
        for dj in range(-1, 2):
            for di in range(-1, 2):
                gi = ci + di; gj = cj + dj
                fx = gi + 0.5 + (_hash(gi, gj, seed) - 0.5) * jitter
                fy = gj + 0.5 + (_hash(gi, gj, seed + 7) - 0.5) * jitter
                d = np.sqrt((xf[k] - fx) ** 2 + (yf[k] - fy) ** 2)
                if d < b1:
                    b2 = b1; b1 = d; bid = _hash(gi, gj, seed + 13); bx = fx; by = fy
                elif d < b2:
                    b2 = d
        f1[k] = b1; f2[k] = b2; cid[k] = bid; px[k] = bx; py[k] = by
    s = x.shape
    return f1.reshape(s), f2.reshape(s), cid.reshape(s), px.reshape(s), py.reshape(s)


def cell_hash(i, j, seed):
    """Vectorised version of the Worley hash, for per-feature randomness outside numba."""
    i = np.asarray(i, np.int64); j = np.asarray(j, np.int64)
    h = (i * 374761393 + j * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFFFF) / 16777216.0
