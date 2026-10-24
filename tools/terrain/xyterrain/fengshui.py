"""Score a site the way a 形势派 geomancer reads land (藏风聚气, 背山面水), on a heightfield.

The terms (docs/terrain/02-landforms.md §风水 lists the sources; thresholds are tunable starting values):
    向    facing: the best azimuth within ±60° of south (the camera looks north, so a south-facing sect shows its front)
    穴    the site itself: gentle (2–12°), not a crest or a channel, above the water
    玄武  back mountain: the highest of the four sectors, 20–60 丈+ above the site within 0.5–4 R
    青龙 / 白虎  flank ridges (east / west when facing south): 0.2–0.5 × the back height, lower than it; 青龙 ≥ 白虎
    明堂  open level ground in front (0.5–3 R)
    案山 / 朝山  a low hill in front at 2–6 R, higher hills far in front at 10–40 R (small elevation angles)
    水    water or a stream crossing the front at 0.5–3 R, spread across it (玉带), not aimed straight at the site
    藏风  enclosure: horizon angle ≥ 5° on most azimuths out to ~1500 丈, back and flanks ≥ 10°, the front open
    龙脉  the incoming dragon: the site joins the regional summit (祖山) along high ground — the lowest col on the best
          ridge path from the 祖山 to the site (a widest-path search) is close to or above the site's height
Total = weighted sum in [0, 1].
"""
import math

import numpy as np

from .flow import _heap_pop, _heap_push, njit

WEIGHTS = {"玄武": 0.20, "龙脉": 0.15, "砂": 0.15, "水": 0.15, "明堂": 0.10, "藏风": 0.10, "案朝": 0.05, "向": 0.05, "穴": 0.05}


def _ss(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def widest_path(h, j0, i0, mask):
    """For every cell, the highest possible 'lowest point' on a path from (j0, i0) — the col a ridge walker must cross."""
    return _widest(h, j0, i0, mask)[0]


@njit(cache=True)
def _widest(h, j0, i0, mask):
    H, W = h.shape
    parent = np.full(H * W, -1, np.int64)
    best = np.full(H * W, -1e18)
    done = np.zeros(H * W, np.bool_)
    hk = np.empty(H * W * 4, np.int64); hv = np.empty(H * W * 4, np.float64); n = 0
    s = j0 * W + i0
    best[s] = h[j0, i0]
    n = _heap_push(hk, hv, n, s, -best[s])
    while n > 0:
        c, v, n = _heap_pop(hk, hv, n)
        if done[c]:
            continue
        done[c] = True
        i = c % W; j = c // W
        for dj in range(-1, 2):
            for di in range(-1, 2):
                ni = i + di; nj = j + dj
                if (di == 0 and dj == 0) or ni < 0 or nj < 0 or ni >= W or nj >= H or not mask[nj, ni]:
                    continue
                q = nj * W + ni
                b = min(best[c], h[nj, ni])
                if b > best[q] and n < hk.size:
                    best[q] = b
                    parent[q] = c
                    n = _heap_push(hk, hv, n, q, -b)
    return best.reshape(H, W), parent


class Geomancer:
    def __init__(self, h, x0, z0, cell, wet=None, area=None):
        self.h = h; self.x0 = x0; self.z0 = z0; self.cell = cell
        self.wet = wet if wet is not None else np.zeros(h.shape, bool)
        self.area = area

    def sample(self, x, z, arr=None):
        arr = self.h if arr is None else arr
        fi = np.clip((x - self.x0) / self.cell, 0, arr.shape[1] - 1.001); fj = np.clip((z - self.z0) / self.cell, 0, arr.shape[0] - 1.001)
        i = fi.astype(int); j = fj.astype(int); tx = fi - i; tz = fj - j
        a = arr.astype(np.float64)
        return (a[j, i] * (1 - tx) + a[j, i + 1] * tx) * (1 - tz) + (a[j + 1, i] * (1 - tx) + a[j + 1, i + 1] * tx) * tz

    def dragon(self, x, z, radius):
        """龙脉 col height between the site and the highest summit within `radius`."""
        r = int(radius / self.cell)
        ci = int(round((x - self.x0) / self.cell)); cj = int(round((z - self.z0) / self.cell))
        j0, j1, i0, i1 = max(0, cj - r), min(self.h.shape[0], cj + r + 1), max(0, ci - r), min(self.h.shape[1], ci + r + 1)
        sub = self.h[j0:j1, i0:i1].astype(np.float64)
        land = ~self.wet[j0:j1, i0:i1]
        top = np.unravel_index(np.argmax(np.where(land, sub, -1e9)), sub.shape)
        best = widest_path(sub, top[0], top[1], land | True)
        return float(best[min(cj - j0, sub.shape[0] - 1), min(ci - i0, sub.shape[1] - 1)]), float(sub[top]), (self.x0 + (i0 + top[1]) * self.cell, self.z0 + (j0 + top[0]) * self.cell)

    def trace(self, x, z, radius):
        """The 龙脉 route from the 祖山 to the site: [(x, z, h)…] along the widest path, and the index of its col."""
        r = int(radius / self.cell)
        ci = int(round((x - self.x0) / self.cell)); cj = int(round((z - self.z0) / self.cell))
        j0, i0 = max(0, cj - r), max(0, ci - r)
        sub = self.h[j0:min(self.h.shape[0], cj + r + 1), i0:min(self.h.shape[1], ci + r + 1)].astype(np.float64)
        top = np.unravel_index(np.argmax(np.where(~self.wet[j0:j0 + sub.shape[0], i0:i0 + sub.shape[1]], sub, -1e9)), sub.shape)
        _, parent = _widest(sub, top[0], top[1], np.ones(sub.shape, np.bool_))
        k = (cj - j0) * sub.shape[1] + (ci - i0)
        route = []
        while k >= 0:
            jj, ii = divmod(k, sub.shape[1])
            route.append((self.x0 + (i0 + ii) * self.cell, self.z0 + (j0 + jj) * self.cell, float(sub[jj, ii])))
            k = parent[k]
        route.reverse()
        return route, int(np.argmin([p[2] for p in route]))

    def score(self, x, z, R=320.0, facing=None):
        """Scores for a site at (x, z) with hall radius R. Returns (total, terms dict, best facing in degrees)."""
        hp = float(self.sample(np.array([x]), np.array([z]))[0])
        n_az = 72
        az = np.radians(np.arange(n_az) * 360.0 / n_az)            # clockwise from north
        rs = R * np.geomspace(0.25, 40, 48)
        A, Rr = np.meshgrid(az, rs, indexing="ij")
        X = x + Rr * np.sin(A); Z = z - Rr * np.cos(A)
        Hs = self.sample(X, Z)
        Ws = self.sample(X, Z, self.wet.astype(np.float32)) > 0.5
        dh = Hs - hp
        elev = np.degrees(np.arctan2(dh, Rr))
        cand = [facing] if facing is not None else list(range(120, 241, 15))
        best = None
        for phi in cand:
            t = self._terms(phi, az, Rr, dh, elev, Ws, R, hp, x, z)
            tot = sum(WEIGHTS[k] * t[k] for k in WEIGHTS if k != "龙脉")
            if best is None or tot > best[0]:
                best = (tot, t, phi)
        tot, t, phi = best
        col, top_h, top_xz = self.dragon(x, z, 40 * R)
        t["龙脉"] = float(_ss(-120, 20, col - hp) * _ss(hp + 30, hp + 200, top_h))
        t["_col"] = round(col - hp, 1); t["_祖山"] = [round(top_xz[0]), round(top_xz[1]), round(top_h)]
        tot = sum(WEIGHTS[k] * t[k] for k in WEIGHTS)
        return float(tot), t, phi

    def _terms(self, phi, az, Rr, dh, elev, Ws, R, hp, x, z):
        rel = (np.degrees(az) - phi + 540) % 360 - 180               # 0 = front, ±180 = back, −90 left (青龙), +90 right
        relg = rel[:, None] * np.ones_like(Rr)
        front = np.abs(relg) <= 45; back = np.abs(relg) >= 135
        left = (relg > -135) & (relg < -45); right = (relg > 45) & (relg < 135)
        near = (Rr >= 0.5 * R) & (Rr <= 4 * R)
        def mx(m):
            v = dh[m & near]
            return float(v.max()) if v.size else 0.0
        b, l, r_, f = mx(back), mx(left), mx(right), mx(front)
        t = {}
        t["玄武"] = float(_ss(10, 60, b) * (1.0 if b >= max(l, r_, f) else 0.6))
        sl = lambda s: float(_ss(0.12, 0.45, s / max(b, 1.0)) * (1.0 if s <= b else 0.5))
        t["砂"] = 0.55 * sl(l) + 0.45 * sl(r_) + (0.0 if l >= r_ * 0.8 else -0.1)
        fr = front & (Rr >= 0.5 * R) & (Rr <= 3 * R)
        flat = np.abs(np.gradient(dh, axis=1) / np.maximum(np.gradient(Rr, axis=1), 1)) < 0.09
        t["明堂"] = float(_ss(0.2, 0.6, (flat & fr & (dh < 2) & (dh > -40) & ~Ws).sum() / max(fr.sum(), 1)))
        an = front & (Rr >= 2 * R) & (Rr <= 6 * R); ch = front & (Rr >= 10 * R)
        an_e = elev[an].max() if an.any() else -90; ch_e = elev[ch].max() if ch.any() else -90
        t["案朝"] = float(0.5 * (_ss(-1, 0.5, an_e) * _ss(9, 4, an_e)) + 0.5 * (_ss(0.5, 2.5, ch_e) * _ss(14, 9, ch_e)))
        wf = Ws & front & (Rr >= 0.5 * R) & (Rr <= 3 * R)
        spread = np.unique(np.nonzero(wf)[0]).size / max(np.unique(np.nonzero(front)[0]).size, 1)
        aimed = (Ws & (np.abs(relg) < 12) & (Rr < 0.5 * R)).any()
        t["水"] = float(np.clip(_ss(0.0, 0.5, spread) - (0.3 if aimed else 0.0), 0, 1))
        hor = np.where(Rr <= 1500, elev, -90).max(axis=1)
        relh = rel
        enc = (hor >= 5).mean()
        bf = hor[np.abs(relh) >= 60].min() if (np.abs(relh) >= 60).any() else 0
        fo = hor[np.abs(relh) < 30]
        t["藏风"] = float(0.5 * _ss(0.4, 0.75, enc) + 0.3 * _ss(3, 10, bf) + 0.2 * float(np.mean((fo > -2) & (fo < 10))))
        t["向"] = float(_ss(60, 30, abs(phi - 180)))
        s0 = np.abs(dh[:, Rr[0] <= 0.3 * R + 1] / (0.3 * R)).mean() if (Rr[0] <= 0.3 * R + 1).any() else 0
        t["穴"] = float(_ss(0.0, 0.035, s0) * _ss(0.4, 0.2, s0) * (0.0 if hp < 0.5 else 1.0))
        return t
