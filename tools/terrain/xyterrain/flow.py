"""Drainage and erosion kernels (numba; a pure-Python fallback runs the same code, ~100× slower).

Grids are (rows = z, cols = x) float arrays, row-major, square cells of `cell` 丈. Flat index k = j * W + i.

    fill_route(h, base)            priority-flood + ε (Barnes et al. 2014) → filled surface, D8 receivers, stack, area
    spl_step(...)                  one implicit stream-power step, n = 1 (Braun & Willett 2013, the FastScape solver),
                                   with a critical-slope cap per cell (threshold hillslopes: cliffs where rock allows)
    diffuse(h, D, ...)             linear hillslope diffusion (explicit, sub-stepped)
    thermal(h, talus, ...)         talus creep: material above the angle of repose slides to lower neighbours
    chamfer(mask)                  distance (丈) to the nearest True cell, 3-4 chamfer
    ridge_area(h, base)            "drainage area" of the inverted surface: high on main divides (龙脉 spines)
"""
import math

import numpy as np

try:
    from numba import njit
except ImportError:                                  # works without numba, just slowly — fine for small regions
    def njit(*a, **k):
        if a and callable(a[0]):
            return a[0]
        return lambda f: f

DI = np.array([1, -1, 0, 0, 1, 1, -1, -1], np.int64)
DJ = np.array([0, 0, 1, -1, 1, -1, 1, -1], np.int64)
DL = np.array([1, 1, 1, 1, math.sqrt(2), math.sqrt(2), math.sqrt(2), math.sqrt(2)])


@njit(cache=True)
def _heap_push(hk, hv, n, k, v):
    hk[n] = k; hv[n] = v
    c = n
    while c > 0:
        p = (c - 1) >> 1
        if hv[p] <= hv[c]:
            break
        hk[p], hk[c] = hk[c], hk[p]
        hv[p], hv[c] = hv[c], hv[p]
        c = p
    return n + 1


@njit(cache=True)
def _heap_pop(hk, hv, n):
    k = hk[0]; v = hv[0]
    n -= 1
    hk[0] = hk[n]; hv[0] = hv[n]
    c = 0
    while True:
        l = 2 * c + 1
        if l >= n:
            break
        r = l + 1
        s = r if (r < n and hv[r] < hv[l]) else l
        if hv[c] <= hv[s]:
            break
        hk[s], hk[c] = hk[c], hk[s]
        hv[s], hv[c] = hv[c], hv[s]
        c = s
    return k, v, n


@njit(cache=True)
def _rnd(k, seed):
    x = (k * 2654435761 + seed * 40503 + 12345) & 0xFFFFFFFF
    x = ((x ^ (x >> 15)) * 2246822519) & 0xFFFFFFFF
    return ((x ^ (x >> 13)) & 0xFFFFFF) / 16777216.0


@njit(cache=True)
def fill_route(h, base, cell, eps=1e-3, rho8=-1):
    """Fill pits (priority-flood + ε), route D8 steepest descent on the filled surface, accumulate area (丈²).

    rho8 ≥ 0 (a seed) switches to Rho8 (Fairfield & Leymarie 1991): a diagonal drop is measured over (2 − r)·cell with r
    random per cell, so over many cells flow takes every direction — no 8-pointed stars on cones and domes.

    base: cells that are outlets (sea, lakes, rivers, sinks, map edge) — they keep their height and are their own receiver.
    Returns (hf, rec, stack, area): stack lists every cell after its receiver (pop order is non-decreasing in hf)."""
    H, W = h.shape
    N = H * W
    hf = h.astype(np.float64).ravel().copy()
    b = base.ravel()
    seen = np.zeros(N, np.bool_)
    stack = np.empty(N, np.int64)
    ns = 0
    hk = np.empty(N, np.int64)
    hv = np.empty(N, np.float64)
    nh = 0
    for k in range(N):
        if b[k]:
            seen[k] = True
            stack[ns] = k; ns += 1
            i = k % W; j = k // W
            for d in range(8):                       # only frontier outlets enter the queue
                ni = i + DI[d]; nj = j + DJ[d]
                if 0 <= ni < W and 0 <= nj < H and not b[nj * W + ni]:
                    nh = _heap_push(hk, hv, nh, k, hf[k])
                    break
    while nh > 0:
        c, v, nh = _heap_pop(hk, hv, nh)
        if not b[c]:
            stack[ns] = c; ns += 1
        i = c % W; j = c // W
        for d in range(8):
            ni = i + DI[d]; nj = j + DJ[d]
            if 0 <= ni < W and 0 <= nj < H:
                q = nj * W + ni
                if not seen[q]:
                    seen[q] = True
                    if hf[q] <= hf[c] + eps:
                        hf[q] = hf[c] + eps
                    nh = _heap_push(hk, hv, nh, q, hf[q])
    # cells no outlet can reach (an island without sea around it in a cropped grid) become their own outlet
    for k in range(N):
        if not seen[k]:
            stack[ns] = k; ns += 1
    rec = np.arange(N)
    dist = np.full(N, cell)
    for k in range(N):
        if b[k]:
            continue
        i = k % W; j = k // W
        best = 0.0
        r8 = 2.0 - _rnd(k, rho8) if rho8 >= 0 else 1.41421356
        for d in range(8):
            ni = i + DI[d]; nj = j + DJ[d]
            if 0 <= ni < W and 0 <= nj < H:
                q = nj * W + ni
                L = DL[d] * cell
                s = (hf[k] - hf[q]) / (cell * r8 if d >= 4 else cell)
                if s > best:
                    best = s; rec[k] = q; dist[k] = L
    area = np.full(N, cell * cell)
    for p in range(ns - 1, -1, -1):
        k = stack[p]
        r = rec[k]
        if r != k:
            area[r] += area[k]
    return hf.reshape(H, W), rec, stack[:ns], area, dist


@njit(cache=True)
def spl_step(h, U, K, m, dt, rec, stack, area, dist, Sc, fixed):
    """One implicit step of dh/dt = U − K A^m S (n = 1), solved upstream along the stack, then each cell is capped at
    its receiver + Sc · L (rock that cannot stand steeper than Sc slumps). fixed cells (outlets, preserved ground) stay."""
    hv = h.ravel()
    Uv = U.ravel(); Kv = K.ravel(); Sv = Sc.ravel(); fv = fixed.ravel()
    for p in range(stack.size):
        k = stack[p]
        r = rec[k]
        if r == k or fv[k]:
            continue
        L = dist[k]
        F = Kv[k] * dt * area[k] ** m / L
        z = (hv[k] + dt * Uv[k] + F * hv[r]) / (1.0 + F)
        cap = hv[r] + Sv[k] * L
        if z > cap:
            z = cap
        if z < hv[r] + 1e-4:
            z = hv[r] + 1e-4
        hv[k] = z
    return h


@njit(cache=True)
def _diffuse_pass(h, out, k, fixed):
    H, W = h.shape
    for j in range(1, H - 1):
        for i in range(1, W - 1):
            if fixed[j, i]:
                out[j, i] = h[j, i]
            else:
                out[j, i] = h[j, i] + k[j, i] * (h[j, i - 1] + h[j, i + 1] + h[j - 1, i] + h[j + 1, i] - 4.0 * h[j, i])


def diffuse(h, D, dt, cell, fixed):
    """Linear hillslope diffusion ∂h/∂t = D ∇²h (D in 丈²/step-unit, may be a field), sub-stepped for stability."""
    D = np.broadcast_to(np.asarray(D, np.float64), h.shape)
    steps = max(1, int(math.ceil(float(D.max()) * dt / (cell * cell) / 0.2)))
    k = D * dt / steps / (cell * cell)
    out = h.copy()
    for _ in range(steps):
        _diffuse_pass(h, out, k, fixed)
        h, out = out, h
    return h


@njit(cache=True)
def _thermal_pass(h, talus, cell, rate, fixed):
    H, W = h.shape
    dh = np.zeros_like(h)
    for j in range(1, H - 1):
        for i in range(1, W - 1):
            if fixed[j, i]:
                continue
            tot = 0.0
            mx = 0.0
            for d in range(8):
                L = DL[d] * cell
                x = h[j, i] - h[j + DJ[d], i + DI[d]] - talus[j, i] * L
                if x > 0:
                    tot += x
                    if x > mx:
                        mx = x
            if tot <= 0:
                continue
            move = rate * mx * 0.5
            dh[j, i] -= move
            for d in range(8):
                L = DL[d] * cell
                x = h[j, i] - h[j + DJ[d], i + DI[d]] - talus[j, i] * L
                if x > 0:
                    dh[j + DJ[d], i + DI[d]] += move * x / tot
    return h + dh


def thermal(h, talus, cell, iters=20, rate=0.5, fixed=None):
    """Talus creep: wherever the drop to a neighbour exceeds talus · L, half of the largest excess slides downhill,
    shared by the neighbours in proportion to their excess. talus = tan(angle of repose) per cell."""
    talus = np.broadcast_to(np.asarray(talus, np.float64), h.shape).copy()
    fixed = np.zeros(h.shape, np.bool_) if fixed is None else fixed
    for _ in range(iters):
        h = _thermal_pass(h, talus, cell, rate, fixed)
    return h


@njit(cache=True)
def chamfer(mask, cell):
    """Distance (丈) from every cell to the nearest True cell (two-pass 3-4 chamfer, ≤ 8 % error)."""
    H, W = mask.shape
    INF = 1e18
    d = np.where(mask, 0.0, INF)
    a, b = cell, cell * 1.41421356
    for j in range(H):
        for i in range(W):
            v = d[j, i]
            if i > 0 and d[j, i - 1] + a < v: v = d[j, i - 1] + a
            if j > 0:
                if d[j - 1, i] + a < v: v = d[j - 1, i] + a
                if i > 0 and d[j - 1, i - 1] + b < v: v = d[j - 1, i - 1] + b
                if i < W - 1 and d[j - 1, i + 1] + b < v: v = d[j - 1, i + 1] + b
            d[j, i] = v
    for j in range(H - 1, -1, -1):
        for i in range(W - 1, -1, -1):
            v = d[j, i]
            if i < W - 1 and d[j, i + 1] + a < v: v = d[j, i + 1] + a
            if j < H - 1:
                if d[j + 1, i] + a < v: v = d[j + 1, i] + a
                if i < W - 1 and d[j + 1, i + 1] + b < v: v = d[j + 1, i + 1] + b
                if i > 0 and d[j + 1, i - 1] + b < v: v = d[j + 1, i - 1] + b
            d[j, i] = v
    return d


def ridge_area(h, base, cell):
    """Area draining 'uphill': route the inverted surface. Large values trace the main divides from the highest massif
    outward — the 来龙 (incoming dragon) spines a feng-shui reading follows."""
    top = np.zeros(h.shape, np.bool_)
    top[np.unravel_index(np.argmax(np.where(base, -1e9, h)), h.shape)] = True
    inv = np.where(base, h.max() + 1.0, h.max() - h)
    _, rec, stack, area, _ = fill_route(inv, top | edge_mask(h.shape), cell)
    return area.reshape(h.shape)


def edge_mask(shape):
    m = np.zeros(shape, np.bool_)
    m[0, :] = m[-1, :] = m[:, 0] = m[:, -1] = True
    return m
