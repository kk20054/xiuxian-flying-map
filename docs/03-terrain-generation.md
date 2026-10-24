# C · Terrain generation (03a, 03b, 03c, 03d, 03e, 03l): technical notes for a Godot 4 + Blender rebuild

Source: `demo/index.html`, lines 2381–4207. A few out-of-scope helpers are cited where the
in-scope code depends on them (CONFIG at 332–361, noise at 1040–1061, `hash2i`/`mulberry32` at 456–468, `smoothstep` at 453,
`baseHeight` at 1668–1693, the boot order at 2347–2379, the per-sect `land` definitions at 1244–1412).

Units: every distance and height is in **丈** (zhang), the world unit. The axes are x (east) and z (south, positive down
the map), and y is up. `WORLD.rect = {x0,x1,z0,z1}` is the world rectangle, taken from `LAYOUT.rect` (line 432 and line 2351).
The biome grid comment (line 3537) says "≈86 丈 a cell" at W=1536, which implies the world is about 132,000 丈 wide. That is
an inference from the comment; read the exact numbers from `LAYOUT.rect` at runtime.

Conventions used below:
- `smoothstep(a,b,x)` is the GLSL Hermite on `clamp((x-a)/(b-a),0,1)` (line 453). **Reversed edges (a>b) are used a lot**
  and give a falling ramp. For example `smoothstep(S.R*3.4, S.R*1.5, d)` is 1 near the centre and 0 far out.
- `hash2i(i,j,seed)` is an integer hash returning a value in [0,1) (lines 464–468). `mulberry32(seed)` is a seeded RNG (456–463).
- `NZ.simplex2` is 2D simplex in about [-1,1]. `NZ.fbm(x,y,oct)` uses lacunarity 2.03, gain 0.5, per-octave offsets (+19.1i, −7.7i),
  and is normalised by the amplitude sum. `NZ.ridged(x,y,oct)` computes `s=(1-|simplex|)^2*w` with weight feedback `w=clamp(2s,0,1)`,
  frequency ×2.07, amplitude ×0.52, normalised, range about [0,1] (lines 1042–1059).
- Arrays are row-major, `k = j*W + i` (j = z row, i = x column).

---------------------------------------------------------------------------------------------------------------------------

## 0. Where this runs: boot order (lines 2347–2379)

```
loadGeo → planCoast → planSites, planTerrain, planCities
→ planRelief()                       (03a)  coarse eroded relief, drainage
→ for each site with a landform: LF(S).afterRelief(S)   (03l) fine 15-丈 sect ground
→ buildHeightfield()                 (04,   out of scope) samples baseHeight/terrainHeight onto the 40-丈 grid WORLD.H
→ buildPatches, planSectClouds
→ planFalls, planReliefRivers()      (03b)  streams and rivers from the drainage; carveStreams() edits WORLD.H
→ planWater, paintWaterMask, buildWaterField, planMarsh, carveWater
→ planRoads()                        (03b)  A* roads, villages, bridges, roadside buildings
→ planGround()                       (03b)  RGBA woods/fields/yards map
→ planSeasons()                      (03c)  RGBA season map
→ planBiomes()                       (03d)  biome class map plus weight textures
→ planSectSpots, planSectZones
→ planTrees()                        (03b)  instance list
→ planEcoGround()                    (03c)  Meadow ground-plant instance list
→ planClouds, planCloudSea, planSpires
```
Every step is deterministic: hashes, seeded RNGs and simplex with a fixed permutation. If you port it faithfully you get
the same world.

Height lookups used throughout:
- `reliefAt(x,z)` gives the coarse eroded relief, Catmull-Rom interpolated (2633–2644).
- `baseHeight(x,z)` (1668–1693) is `reliefAt` + `reliefDetail` + designed peaks + hills + marks + `sectFloor` + city relief,
  then `max(0,h-2.5)*1.004`, × clearFactor, then the landform's `height()` over its disc.
- `hAt(x,z)` (line 1850) is the final baked 40-丈 heightfield lookup (`WORLD.H`). It is what 03b/03c/03d read.

---------------------------------------------------------------------------------------------------------------------------

## 1. 03a: mountain system (lines 2381–2660)

### 1.1 Concept (comment, lines 2381–2389)
The selfmate mountain-density map is treated as **tectonic uplift U**. The model is the stream power law `E = K·A^m·S^n`
with n = 1. At steady state, uplift equals erosion, so the slope is `S = (U/K)·A^(−m)`. Heights are integrated upstream from
the base level (sea, plains, map edge, great-river corridors), using a priority-flood receiver tree (Barnes et al. 2014)
and the FastScape n=1 steady-state solution (Braun & Willett 2013). The code alternates routing and integration for
`iters` rounds.

**Important:** there is **no time-stepping or implicit solver** here. Each round is the closed-form steady-state
integral along the receiver tree. That is equivalent to the n=1 FastScape implicit solve taken to equilibrium, but it is
direct and has no `dt`.

### 1.2 Config (line 342)
```
CONFIG.relief = { cell: 100, iters: 5, m: 0.45, height: 540, cap: 950, maskLo: 0.1, maskHi: 0.62, front: 1.8,
  spine: 0.55, plain: 0.1, detail: 0.5, sectRise: 1.15, spurLow: 0.2, mainMassif: 0.6, trend: 15, rock: 0.55,
  grain: 0.18, soften: 6, streamArea: 150, riverArea: 420 }
CONFIG.terrain.peakHeight = 1.0 (line 332)
CONFIG.sects.crestUp = 85 (line 346)
```
Line-334–337 comments explain each key: cell is the coarse grid side; iters are the rounds of network/terrain adjustment;
m is the drainage-area exponent; height is the 97th-percentile height; cap is the soft ceiling; maskLo/maskHi map density to
uplift; plain is the density threshold for plains; front is how gradual the range front is; spine is the main-crest band
strength; trend is the range strike in degrees; rock/grain set the erodibility variation; soften is the number of ridge-rounding
passes; streamArea is the channel threshold in cells. `riverArea` is read at line 2762 (`RA`) but **never used**.

### 1.3 Grid (lines 2454–2456)
```
C = 100 (丈)
W = ceil((x1-x0)/C) + 1,  H = ceil((z1-z0)/C) + 1,  N = W*H
X(i) = x0 + i*C,  Z(j) = z0 + j*C        (node-centred: cell i sits ON x0+i*C)
```
Output, stored in the global `RELIEF` (2390, filled at 2628):
`{C,W,H,x0,z0, h (Float32 relief), A (drainage cells), rec (Int32 receiver), order, cnt, base (Uint8), kind (Uint8),
U, A2, rec2 (lowland routing), logA, low (valley-floor level), rivD (distance to great rivers)}`.

`kind` codes are 0 = mountain (non-base), 1 = sea, 2 = plain, 3 = enclosed/sect/landform core, 4 = map edge, 5 = great-river
corridor. In `reliefZones` (2443–2452), kind 0 means "uplift damped only, never base".

### 1.4 Step 1: inputs and the uplift field U, erodibility K, base mask (2457–2535)

**Density** (2458–2460): `D0[k] = densityAt(X,Z)` (selfmate density, line 1100), then `D = boxBlurF(D0, W,H, r=2)`.
`boxBlurF` (2437–2442) is a separable running-sum box blur with radius r and clamp-to-edge.

**Great-river distance** (2465–2478): for each polyline in `GEO.rivers` (flat `[x,y,x,y,…]` in base-map px, converted
with `LAYOUT.toWorld`), each segment's bounding box ±6 cells gets a point-segment distance. `rivD[k]` is the minimum
over all segments (init 1e9). It is stored as `RELIEF.rivD` and read later by `rivDAt` (3721–3725, bilinear).

**Zones** (`reliefZones`, 2444–2452): an array of `[x, z, r0, r1, kind, id]`:
- Cities: `cityZones()` if city plans exist, else POIs with `cat==='city'`: minzhou `r0=1900, r1=4200`, others `1500, 3400`, kind 2, id 'city'.
- `lvzong 1000/2500 k2`, `lingyan 620/1500 k3`, `sunshi 620/1500 k3`, `dimai 260/1000 k3`
- `feilian 0/1700 k0`, `yingxian 0/1200 k0`, `tingyun 0/1100 k0`, `guxiu 0/1500 k0`

**Per-cell classification and uplift**, in this order (2481–2535), for cell (x,z):
1. Border cell: `base=1, kind=4`, continue.
2. `seaDist(x,z) > -40` (in the sea or within 40 of the shore): `base=1, kind=1`.
3. `rivD < 1.6*C` (160 丈): `base=1, kind=5` (great-river corridor).
4. `m = smoothstep(maskLo=0.1, maskHi=0.62, D[k])`, and `cu = cityHillU(x,z)` if city plans exist, else 0.
5. Open plain: if `m < plain*0.5 (=0.05)` and `cu < 0.02` and the cell is not within `S.land.R` (or `S.R*3.4`) of any site, and is
   more than 7000 丈 from 云梦山 (`yunmeng`), then `base=1, kind=2`.
6. Main crests (anisotropic, warped ridged field):
   ```
   th = trend*π/180 (15°), ct=cos th, st=sin th
   wx = simplex2(x/11000+2.3, z/11000-5.1)*2600 ; wz = simplex2(x/11000-7.7, z/11000+1.9)*2600
   along  = ((x+wx)*ct + (z+wz)*st) / 9500
   across = (-(x+wx)*st + (z+wz)*ct) / 3600
   spine  = ridged(along+11.3, across-4.2, 3)
   u = m^front(1.8) * (0.62 + 0.38*(fbm(x/9000+4.1, z/9000-2.7, 2)*0.5+0.5)) * lerp(1-spine(0.45), 1+spine*0.4(1.22), spine)
   ```
   (`lerp(1-RC.spine, 1+RC.spine*0.4, spine)` uses RC.spine = 0.55, so it runs from 0.45 to 1.22.)
7. Main massif round 云梦山: `u = max(u, mainMassif(0.6) * exp(-(d/3400)^2) * smoothstep(0.05,0.3,D+0.2))`.
8. For each site S:
   - **Landform site (`S.land`, all six sects in the current data, lines 1248–1400):** skip if `d > S.land.R`. Otherwise
     `wl = 1 - smoothstep(R*edge, R, d)` and `u = lerp(u, LF.reliefU(S,x,z,u) or 0.03, wl)`. If `wl > 0.5`, set `kind=3`.
     `reliefU` (3826–3830) is
     `max(u*0.82, max_m (m.u0 ?? 1.1) * exp(-1.35 * dm^2))` for `dm < 2.6`, where `dm` is the mass's elliptical distance in
     its own radii (3824): `a=(dx cs+dz sn)/(r*ax), b=(-dx sn+dz cs)/r, dm=hypot(a,b)`.
   - **Legacy non-landform sect** (dormant while every sect has `land`): only applies when `d <= 3.6R`. Spurs give
     `g = q.s*exp(-da²/(2 q.w²))` with angular offset `da = a - q.a - q.curve*sin(d/q.wl+q.ph)`, and `sp = max g`. Then
     `front = smoothstep(0.1,0.85, dz/d)`, `rise = smoothstep(3.6R,0.4R,d)^0.85`, and
     `u2 = sectRise(1.15)*rise*lerp(spurLow 0.2,1,sp)*(1-0.25 front)`, giving `u = lerp(u,u2,smoothstep(3.4R,1.5R,d))`.
     If `d < 1.1R`, set `kind=3`.
9. Great-river valley sides: if `rivD < 6C`, `u *= smoothstep(1.6C, 6C, rivD)`.
10. 天柱山 isolation: `u *= lerp(0.42,1,smoothstep(1300,4200,d_tz))`. 子母峰: `u *= lerp(0.35,1,smoothstep(900,2300,d_zm))`.
11. Zones: for each zone with `d <= r1`, `u *= smoothstep(r0,r1,d)`. If `d < r0` and the cell is not already base, it becomes
    `base=1, kind=kd||2` (so kind 0 zones only damp).
12. City hills (背山面水): if `cu > u`, set `u = cu`, and if the cell was a kind-2 plain base it is un-based (`base=0`).
13. Range-front plains: if not base and `m < plain (0.1)` and `u < 0.05`, set `base=1, kind=2`.
14. `U[k] = u`.
15. Rock: `kn = fbm(x/4200+1.9, z/4200+6.1, 2)`, `tr = sin((x ct + z st)/1500 + 2.2*simplex2(x/7000, z/7000+3))`,
    `K[k] = exp(rock(0.55)*kn + grain(0.18)*tr)`.

Note that cells which `continue` early (steps 1–3, 5) keep `U=0, K=0`. K=0 is never divided by, because base cells
get `h=0`.

### 1.5 Step 2: steady state (2536–2552)
```
e[k] = base ? 0 : U*300*(0.55 + 0.45*ridged(X/2400+0.7, Z/2400-0.3, 2))       # initial surface for the first routing
for it in 0..iters-1 (5):
    e[k] = (it ? h[k] : e[k]) + hash2i(k, it, 31)*0.02                        # tiny jitter breaks flats/ties
    cnt = floodRoute(W,H,e,base,rec,order, eps=1e-3)                          # priority-flood + ε, fills e in place
    A[:] = 1
    for q = cnt-1 .. 0:  c=order[q]; r=rec[c]; if r>=0: A[r] += A[c]           # drainage area in CELLS (not 丈²)
    for q = 0 .. cnt-1:
        c=order[q]; r=rec[c]
        if r<0: h[c]=0; continue
        L = (diag ? C*√2 : C)            # diag = column AND row differ
        h[c] = h[r] + L * (U[c]/K[c]) * A[c]^(-m)        # m = 0.45
```
`floodRoute` (2412–2436) works as follows:
- `seen` starts at 1 for every base cell. **Only frontier base cells are pushed**, meaning base cells that have at least one
  non-base 8-neighbour, with priority `elev[k]`. Interior sea and plain cells never enter the heap and get no `order` entry.
- Pop the minimum. Append it to `order`. For each 8-neighbour q not yet `seen`: mark it seen, set `rec[q] = c`, and if
  `elev[q] <= elev[c]` raise it to `elev[c] + eps` (pit fill with ε gradient). Push q with its (possibly raised) elevation.
- The neighbour order is `_DI=[1,-1,0,0,1,1,-1,-1], _DJ=[0,0,1,-1,1,-1,1,-1]` (4 orthogonal, then 4 diagonal), line 2409.
- **The receiver is the flood parent** (the cell that first reached q from the lowest point of the priority queue). It is not
  the D8 steepest-descent neighbour. On a filled surface this is close to D8, but if you want identical networks, port it
  exactly as written. The heap is a binary min-heap on (Int32 idx, Float32 priority) (2392–2408). Tie order depends on the
  heap implementation, which is why the jitter is there.
- Root cells (frontier base cells) keep `rec = -1`.

### 1.6 Step 3: hillslope diffusion, scaling, sect crest normalisation (2553–2589)
**Near-sect weight** (2555–2556): `nearW = max over non-land sites of smoothstep(2.6R, 1.0R, d)`. It is 0 wherever every
sect has a landform.

**Diffusion** (2557–2560): `soften = 6` Jacobi passes on interior non-base cells:
```
e = h.copy()
h[k] = e[k] + 0.22*(1 - 0.7*nearW[k]) * ((e[k-1]+e[k+1]+e[k-W]+e[k+W])*0.25 - e[k])
```
**Scaling to world heights** (2561–2564):
```
vals = [h[k] for k in 0,3,6,…  if !base[k] and h[k] > 1 and nearW[k] <= 0], sorted
p97  = vals[floor(len*0.97)]
s    = (height 540 * peakHeight 1.0) / max(1, p97)
cap  = cap 950 * peakHeight 1.0
h[k] = base ? 0 : cap * tanh(h[k]*s / cap)          # soft ceiling at 950 丈
```
`WORLD.stats.reliefMax = round(max(vals)*s)` (2630).

**Legacy per-sect crest normalisation** (2568–2589, skipped for `S.land`). Box ±2.8R. Take `ring` = the h values at
0.55R < d < 0.95R, and `p90` = its 90th percentile. Then `f = clamp((S.cloud + crestUp*S.k)/p90, 0.5, 1.9)`,
`capCore = (S.cloudBase ?? S.cloud) + crestUp*S.k`, and `crown = max(plat.h) - 90*S.k`. Per cell:
`v = min(h*lerp(1,f,smoothstep(2.8R,1.0R,d)), capCore + 900*smoothstep(0.68R,1.0R,d))`. If `v > crown`,
`v = lerp(v, crown+(v-crown)*0.12, 1-smoothstep(2.0R,2.8R,d))`.

### 1.7 Step 4: lowland routing for rivers on the plains (2590–2621)
- `isMt(k) = !base[k] || kind[k]===3`. `outlet(k) = kind ∈ {1 sea, 4 edge, 5 great river}`.
- (a) `geo` is a Dijkstra cost-distance from all outlets over 8 neighbours. The step cost is `C` or `C√2`, times **6** when
  entering a mountain cell (2596–2605). The heap has an initial capacity of N>>3.
- (b) `dm` is a two-pass chamfer distance (C, C√2) to the nearest mountain cell (2607–2610).
- (c) The routing surface (2611–2618):
  ```
  outlet: base2=1, e=0
  plain:     v = 0.0022*geo + 9*exp(-dm/1500) + 4*(fbm(x/2800+8.1, z/2800-2.2, 3)*0.5+0.5)   # tilt to outlet + fans + swell
  mountain:  v = 0.0022*geo + h + 12
  kind==3:   v = 4000                                   # sect/landform/enclosed cores repel the rivers
  city zone with d < r0*0.55: v = max(v, 400)           # city cores are kept out
  e = v + hash2i(i,j,77)*0.05
  ```
- `floodRoute(W,H,e,base2,rec2,order2,1e-3)` gives `A2` (accumulated the same way, initialised to 1).

### 1.8 Derived fields (2622–2631)
- `logA = ln(A)`. `wetAt(x,z) = smoothstep(1.2, 6.5, reliefLin(logA))` gives 0 on crests and 1 in big valleys (2660). It feeds the colour.
- `low` is the valley-floor level. It is a separable min filter of ±4 cells (9×9, ≈ 900 丈 window, "~400 丈" in the comment)
  followed by `boxBlurF(r=3)` (2624–2627). It is read by `sectWoodsK` (2236) and the cloud sea: valleys fill with cloud to this level.

### 1.9 Samplers (2632–2660)
- `reliefAt(x,z)`: Catmull-Rom, 4×4 taps, `cr(p0..p3,t) = p1 + 0.5 t (p2-p0 + t(2p0-5p1+4p2-p3 + t(3(p1-p2)+p3-p0)))`.
  It returns 0 if `fx<1 || fz<1 || fx>W-3 || fz>H-3`, or if the sum of all 16 taps is ≤ 0. Otherwise it returns `max(0, value)`.
- `reliefLin(x,z,arr)` is bilinear and clamped.
- `reliefDetail(x,z,h)` adds crags and gullies at 40-丈 resolution, applied in `baseHeight` when h > 0.5 (line 1673):
  ```
  amp = min(h,650)*detail(0.5); if amp < 2: 0
  for non-land sites within 2.6R: amp *= 1 + smoothstep(2.6R, 1.0R, d)
  r = ridged(x/560+3.7, z/560-1.3, 2); g = simplex2(x/190+7.7, z/190+2.2)
  return amp*(0.16*(r-0.42) + 0.045*g)
  ```

### 1.10 Faithful Python (numpy) port of 03a for offline baking

```python
import numpy as np, heapq, math

DI = [1,-1,0,0,1,1,-1,-1]; DJ = [0,0,1,-1,1,-1,1,-1]

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0); return t*t*(3 - 2*t)

def box_blur(src, r):                     # separable, clamp-to-edge, same as boxBlurF (2437)
    H, W = src.shape
    pad = np.pad(src, ((0,0),(r,r)), mode='edge'); c = np.cumsum(np.pad(pad,((0,0),(1,0))), axis=1)
    tmp = (c[:, 2*r+1:] - c[:, :-2*r-1]) / (2*r+1)
    pad = np.pad(tmp, ((r,r),(0,0)), mode='edge'); c = np.cumsum(np.pad(pad,((1,0),(0,0))), axis=0)
    return (c[2*r+1:, :] - c[:-2*r-1, :]) / (2*r+1)

def flood_route(elev, base, eps=1e-3):
    """priority-flood + eps (floodRoute, 2412). elev: (H,W) float32, modified in place. base: bool (H,W).
    returns rec (flat int32, -1 for roots) and order (flat cell ids, each after its receiver)."""
    H, W = elev.shape; N = H*W; e = elev.reshape(-1); b = base.reshape(-1)
    seen = b.copy(); rec = np.full(N, -1, np.int32); order = []; heap = []
    for k in np.flatnonzero(b):                       # seed only frontier base cells
        i, j = k % W, k // W
        for d in range(8):
            ni, nj = i+DI[d], j+DJ[d]
            if 0 <= ni < W and 0 <= nj < H and not b[nj*W+ni]:
                heapq.heappush(heap, (np.float32(e[k]), k)); break
    while heap:
        p, c = heapq.heappop(heap); order.append(c)
        i, j = c % W, c // W; ec = e[c]
        for d in range(8):
            ni, nj = i+DI[d], j+DJ[d]
            if not (0 <= ni < W and 0 <= nj < H): continue
            q = nj*W+ni
            if seen[q]: continue
            seen[q] = True; rec[q] = c
            if e[q] <= ec: e[q] = ec + eps
            heapq.heappush(heap, (np.float32(e[q]), q))
    return rec, np.array(order, np.int64)
    # NOTE: heapq breaks ties by cell id; the JS heap breaks them by its sift order. Expect tiny network differences
    # at exact ties unless you port makeHeap (2392) literally (same push/pop sift code on parallel arrays).

def accumulate(rec, order, N):
    A = np.ones(N, np.float32)
    for c in order[::-1]:
        r = rec[c]
        if r >= 0: A[r] += A[c]
    return A

def steady_state(U, K, base, C, m, iters, e0, hash_fn):
    H, W = U.shape; N = H*W; Uf, Kf = U.reshape(-1), K.reshape(-1)
    h = np.zeros(N, np.float32); e = e0.reshape(-1).astype(np.float32).copy()
    for it in range(iters):
        jit = hash_fn(np.arange(N), it, 31) * 0.02          # hash2i(k, it, 31): note k (flat index) as ix, it as iy
        e = (h if it else e) + jit
        e2 = e.reshape(H, W).copy()
        rec, order = flood_route(e2, base, 1e-3)
        A = accumulate(rec, order, N)
        for c in order:                                    # upstream integration (FastScape n=1 steady state)
            r = rec[c]
            if r < 0: h[c] = 0; continue
            diag = (c % W != r % W) and (c // W != r // W)
            L = C*math.sqrt(2) if diag else C
            h[c] = h[r] + L * (Uf[c]/Kf[c]) * A[c]**(-m)
    return h.reshape(H, W), rec, order, A

def soften_and_scale(h, base, nearW, passes=6, height=540, cap=950, peak=1.0):
    for _ in range(passes):
        e = h.copy()
        lap = (e[1:-1,:-2]+e[1:-1,2:]+e[:-2,1:-1]+e[2:,1:-1])*0.25 - e[1:-1,1:-1]
        upd = e[1:-1,1:-1] + 0.22*(1-0.7*nearW[1:-1,1:-1])*lap
        inner = ~base[1:-1,1:-1]
        h[1:-1,1:-1] = np.where(inner, upd, e[1:-1,1:-1])
    flat = h.reshape(-1); bflat = base.reshape(-1); nw = nearW.reshape(-1)
    idx = np.arange(0, flat.size, 3)
    vals = np.sort(flat[idx][(~bflat[idx]) & (flat[idx] > 1) & (nw[idx] <= 0)])
    p97 = vals[int(len(vals)*0.97)] if len(vals) else 1.0
    s = height*peak / max(1.0, p97); c = cap*peak
    return np.where(base, 0.0, c*np.tanh(h*s/c)).astype(np.float32)
```
The U/K/base/kind construction (§1.4) is a per-cell loop you port line by line. It needs `densityAt` (the selfmate density
raster), `seaDist`, the GEO river polylines, the site list and the layout marks. Port `NZ` (simplex with its `perm` table,
lines ~1030–1061) and `hash2i` with exact 32-bit integer semantics (`np.uint32` multiply with wraparound, which matches
`Math.imul`), or the noise will not match.

The upstream integration loop is O(N) in Python but slow at N ≈ 1.7 M (with W ≈ 1321 if the world is about 132k 丈 wide).
Use `numba.njit` for `flood_route`, `accumulate` and the integration. Alternatively use the `richdem` / `fastscapelib`
priority-flood. Be aware that their receivers are steepest-descent, not flood-parent.

**Practical recommendation:** the most faithful bake is to **run the demo headless (Chrome/Puppeteer) and dump the arrays**
(`RELIEF.h`, `WORLD.H`, `WORLD.ground.data`, `WORLD.biome.id/tex/tex2`, `WORLD.season.data`, `WORLD.trees`, and the road,
river and stream polylines) instead of re-implementing. Use the Python port only when you want to change parameters offline.

---------------------------------------------------------------------------------------------------------------------------

## 2. 03b: settlement layer (lines 2662–3257)

### 2.1 Grid helper and A* (2669–2706)
`gridOf(C)` (2670–2673) is cell-centred: `W = ceil((x1-x0)/C)` (no +1), `x(i) = x0+(i+0.5)C`, and `i(x) = clamp(floor((x-x0)/C))`.

`astar(G, cost, s, goal, tgt, climb)` (2674–2706):
- 8 neighbours with step lengths `dl = 1` (orthogonal) or `1.414` (diagonal).
- Edge cost: `g = gS[cur] + (cost[cur]+cost[n])*0.5*dl (+ climb(cur,n) if given)`. Cells with `cost = Infinity` are impassable.
- Heuristic: `hypot(di,dj)*0.92` in grid cells. Because every cell cost is ≥ ~1 (§2.4), this is admissible.
- Closed set, binary heap with lazy deletion, iteration cap `900000`. Returns the list of cell ids from start to goal, or null.

`smoothPath(G, cells, step, ends)` (2708–2721): cell centres become a polyline. The first and last points are replaced by
the exact node positions. Then 3 rounds of Chaikin (¼/¾ corner cutting, endpoints kept), then an arc-length resample at
`step`, giving n = ceil(T/step) segments.

`meanderPath(P, A, seed)` (2724–2737) is the lateral road wander:
```
skip if len(P) < 8
o_i = A*(0.75*simplex2(L_i/460 + seed, 0.37) + 0.25*simplex2(L_i/170 - seed, 4.1)) * smoothstep(0,180,L_i)*smoothstep(0,180,T-L_i)
o_i = 0 if hAt(P_i)>3 or hAt(displaced)>3 or waterAt(displaced)>0.1 or sdAt(displaced)>-30     # only on open level dry ground
4 smoothing passes  off_i = (off_{i-1} + 2off_i + off_{i+1})/4
P_i += normal_i * off_i     (normal = (-dz, dx)/l from P_{i-1}→P_{i+1})
```
Helpers: `chaikin(P, rounds=3)` (2743–2750) works on N-D points. `resamplePath(P, step)` (2751–2756) interpolates every
component, including the width channel.

### 2.2 Rivers and streams from the drainage (`planReliefRivers`, 2757–2854)
Gated by `CONFIG.ground.rivers` (1). `SA = streamArea(150) * ground.streams(1.0)`, measured in cells.

1. **Channel heads** (2765–2769): a channel cell is `!base && A >= SA`. `hasIn[rec[k]] = 1` for each channel cell. Heads
   are channel cells with no channel inflow. They are sorted by relief height, highest first.
2. **Segments** (2770–2783): from each head, walk `rec`. Stop when you reach a cell already `used` (a confluence: add it and
   set `join=true`) or a base cell (include it, then stop). Mark visited cells `used = segIndex`. Drop segments shorter than 3 cells.
3. **Mountain streams** (2784–2797): points are the node coordinates `X(k)=x0+(k%W)C`, `Z(k)=z0+floor(k/W)C`. Cut at the
   first point inside any sect (`d < 0.98 S.R`); drop the segment if it starts inside. Apply a 5-tap moving average
   (interior points), `chaikin(·,3)`, then `resamplePath(·, 24)`.
   Width is `wOf(a) = 8 + 0.85*sqrt(A)` at the head and at the end, giving `w:[w0,w1]`. `ended` is `'join' | 'sea' | 'plain'`.
   The record is pushed to `WORLD.streams` as `{pts:[[x,z,0]…], ended, w, area}`.
4. **Lowland continuation** (2800–2810): if the stream did not join and its end cell is `base` with `kind===2` (plain),
   follow `rec2` for at most 4000 steps. Stop at `kind ∈ {1,4,5}`, or at an already `used2` cell (a join). Keep runs of ≥ 3 cells.
5. **Lowland rivers** (2812–2828): width `wl(a) = clamp(9 + 0.52*sqrt(A2), 11, 110)` per cell. Apply a 7-tap moving average,
   `chaikin(·,4)`, then `resamplePath(·,40)`. Meander for 3 ≤ i ≤ n−3:
   `m = (0.7*simplex2(i*0.05+qi*3.1, 3.7) + 0.3*simplex2(i*0.14+qi, 9.1)) * lerp(60,170, min(1, 3t))`, with `t=i/(n-1)`.
   Displace along the normal. Revert the displacement if `hAt > 6` or (`seaDist > -60` and `t < 0.92`).
   Rivers are sorted by point count. The names are `['韵水','绿踪溪','西溪','北溪','清河','白沙河']`, then `'支流'`.
   Point layout: `[x, z, width]`.
6. **Great rivers** (2832–2851) from `GEO.rivers`: `chaikin(3)`, `resample(60)`, and a meander amplitude of
   `110*(0.7*simplex2(i*0.045+qi*7.1,2.7)+0.3*simplex2(i*0.13+qi*3,8.1))`. Clip to the part inside the rect (±30 margin),
   up to where `seaDist` reaches ≥ 40. Width is `lerp(90,130,i/(m-1))`, the name is `'鸾水' | '天水'`, and `great:true`.
7. `carveStreams()`.

`carveStreams` (2856–2893) edits the 40-丈 `WORLD.H` grid (`g`, `nx`, `nz`):
- The water level per stream point is `max(0, hAt-0.5)`, forced monotone non-increasing downstream.
- Carve radius is `RAD = 30 + 0.9*w1`. For each point with `ph >= 2`, every grid cell within RAD that has `H > 2` and is not
  inside a sect fine-mesh patch gets `f = 1 - d/RAD`, `bed = ph - 2 - 6f`, `target = max(bed, H - 16f)`, and
  `H = max(1, target)` if lower. This gives a V-shaped bed, at most 16 deep.
- Water levels are then re-laid: `min(level, hAt-0.5)`, monotone again.
- Falls: a run of consecutive samples (24-丈 spacing) each dropping more than **9** 丈, with total drop ≥ **24**, is a fall.
  It is pushed to `WORLD.falls` as `{x,z,bx,bz,top,bottom,w=lerp(w0,w1,i/n)*1.5, nx,nz (unit flow dir), stream:true,
  pts:[[x,y+1.5,z]…]}`.

`paintRivers(g, P, flow)` (2895–2908) draws the rivers on the water mask canvas as white round-capped strokes of width
`max(1.2, width*scale)`. The flow canvas stroke is width+3 with colour `rgb(128+127*dx, 128+127*dz, 255)`, i.e. a
flow-direction texture with R,G = direction*0.5+0.5 and B = 1.

### 2.3 Road network (`planRoads`, 2910–3027)
Gated by `CONFIG.ground.roads`. The grid is `gridOf(100)`; `h` = `hAt` sampled at the cell centres.

**Cost per cell** (2916–2929):
```
seaDist > -60                          → Infinity
c  = 1 + 0.32*(fbm(x/2600+1.9, z/2600-4.1, 3) + 1)          # gentle meander noise, range ~[1, 1.64]
sl = max |h(neighbour) - h| over the 4 neighbours (flat index ±1, ±W, clamped) / 100
if h > 5:  c += 0.8 + h/60 + sl*16                         # hills only where it must
if waterAt > 0.5: c += 28                                  # cross rivers (bridges), never follow them
d(lvzong) < 1000: c += 5                                   # swamp
d(lingyan) < 1400: Infinity                                # 灵眼之树 forbidden
for each site: d < 0.9R → Infinity ; d < 1.2R → c += 3
d(WORLD.pillar) < 700 → Infinity                            # 天柱山
cityKeepClear(x,z,-60) → Infinity                           # walls and moat
```
**Nodes** (2931–2943):
- Each sect: `S.ridge` start minus 40 along its axis (`[ridge.x0 - ux*40, ridge.z0 - uz*40]`), or for a landform sect
  `S + def.roadFoot*S.k`. For example 水影宗 has `roadFoot:[0,1400]` (line 1411).
- 韵州城 (`yunzhoucheng`) gates N/S/E from `cityPlan().gate()`, else POI ±400. 封日城 (`minzhou`) W/S/N/E gates, else ±560.
- `zimu: [zm.x-260, zm.z+520]`. `south: [yz.x+900, z1-40]`. `sw: [baiqiao.x-2600, z1-40]`. `east: [x1-40, Pm.z+Pm.ewV-300]`.

**Links** `[a, b, width]` (2944–2945):
```
luoyun–yzN 14, luoyun–gujian 14, gujian–baiqiao 14, yzS–south 13, yzE–mzS 13, baiqiao–sw 12, luoyun–zimu 9, mzE–east 12,
mzE–luanming 13, luanming–nihang 12, nihang–shuiying 12
```
`road(a,b,w,kind)` (2946–2955): start and end cells that are Infinity are forced to cost 4. A* runs with the target
heuristic. Then `meanderPath(smoothPath(G,cells,12,[A,B]), kind==='lane'?8:20, roads.length*7.3)`. Afterwards
**the cost of every cell on the path is multiplied by 0.55 (floored at 1)**, so later roads tend to share and merge.
The record is `{a,b,w,kind,pts:[[x,z]…]}` with points 12 丈 apart.

### 2.4 Villages (2957–2983)
RNG `mulberry32(3131)`. `okAt(x,z,pad)` requires all of the following:
- `seaDist ≤ -300`, `sdAt ≤ -90` (away from water), `hAt ≤ 3` (level).
- All 6 probes at radius `pad` (angles 0..5 rad) have `hAt ≤ 6`.
- Not within `S.R+900` of a sect, 1500 of a city POI, `P.flatR+900` of a city plan, 1100 of any layout mark, or **2300** of
  another village.

Walk each main road (a snapshot `WORLD.roads.slice()`). Start a countdown at `s = 1500+1500r`. When it reaches ≤ 0 at
point i: try both sides (random order) at offset `230+140r` along the normal. On the first `okAt(...,220)` success, push the
village `{x,z,n: 9+floor(9r) houses, yaw: road dir ± 0.25 rad, seed, road, at:i}` and build a **lane**
`road([Pi], [village], 8, 'lane')`. Then reset `s = 2600+2000r`, whether or not a village was placed.

### 2.5 Bridges (2984–2992)
Along each road (lanes included), a "wet" point is `waterAt > 0.4 && seaAt < 0.5`. Each wet run from inW to i gives a bridge
`{road, a: inW-2, b: i+1, p0: P[a], p1: P[b]}`.

### 2.6 Roadside buildings: inns, tea sheds, pavilions, arches (2993–3011)
For each main road: `s = 1200+800r` (small-building countdown), `st = 3800+2000r` (post-station countdown), and `alt` is a
coin flip. For i in [2, len-2), decrement both countdowns by the segment length. When either reaches ≤ 0:
- `big = st <= 0`. Side is random. Offset is `62` for a big building, else `24+6r`.
- Reject if `nearNode(900)` (within 900 of any node, 500 of a village, or 200 of a bridge start), or `sdAt > -40`, or
  `hAt > (big ? 4 : 30)`. On rejection, retry soon (`s=300` / `st=500`).
- `hilly = hAt>6 || hAt(160 further out)>20`. Type is `'station'` (big), else `'pavilion'` if `hilly||alt`, else `'teashed'`.
- Push `{type,x,z,y:hAt,face: -normal*side (faces the road), road}`. Next countdown: `st = 5200+2400r` for a big building,
  else `s = 2000+1200r` and flip `alt`.

Arch (牌坊): for the city gate nodes `yzN, yzS, yzE, mzW, mzS, mzE`, at the 14th point of the road leaving the gate (≈168 丈),
facing outward.

`WORLD.roadDist(x,z)` (3013–3026) uses a spatial hash with 200-丈 buckets (key `i*100003+j`). It returns the minimum of
segment distance − w/2 over a 3×3 bucket block, i.e. the signed distance to the road edge.

### 2.7 The RGBA ground map: woods / fields / bare ground / field orientation (`planGround`, 3029–3103)
**Pass 1, wood density F** on `FW=768 × FH=round(768*(z1-z0)/(x1-x0))`, cell-centred:
- `hh` = `hAt` at the cell centres. `hb = blur(blur(hh,3),2)` (≈600 丈 lie of the land). `hb2 = blur(hh,2)` (ridge vs gully).
- Settled places become `farms[]` (3040–3046):
  - City POIs: `r = 2300` (minzhou) or `1800`, `yard 0`, `ang = 0.12 (+0.5 minzhou)`.
  - `cityFarms(farms)` adds more.
  - Villages: `r = 650 + 30n`, `yard = 90 + 5n`, `ang = yaw mod π`.
  - Stations: `r 0`, `yard 70`.
  - Landform `farms` hooks.
- Per cell (skip if `seaDist > -120` or `sdAt > -30`):
  ```
  warp = fbm(x/6000+2.2, z/6000-7.1, 2)*0.3
  n    = fbm(x/1700+warp+3.3, z/1700-warp-1.7, 4)
  f    = smoothstep(0.02,0.26, n+0.12*(forests-1)) * (0.4 + 0.75*smoothstep(-0.25,0.35, fbm(x/9000+1.1, z/9000-3.3, 2)))
  foot = smoothstep(5,32,hb) * (1 - smoothstep(200,330,hb))                 # foothill belt
  f    = max(f*(0.38+0.62*smoothstep(2,22,hb)), foot*smoothstep(-0.2,0.14, n+0.12*(forests-1))*0.95)
  riverside strip: if -190 < sdAt < -30 and seaDist < -300 and h < 60: f = max(f, smoothstep(-0.1,0.3, simplex2(x/520+4.4, z/520-1.9))*0.75)
  new country (!inOldFrame): f = max(f*0.6, smoothstep(0.12,0.5, woodHintAt)*0.95*smoothstep(-0.3,0.1,n)); f *= 1-0.85*aridAt
  if h>30: f *= 1 - smoothstep(300,430,h)                                    # high flanks bare rock
  sl = (|hh[k+1]-hh[k-1]| + |hh[k+FW]-hh[k-FW]|)/(2*fx);  f *= 1 - smoothstep(0.7,1.3,sl)
  sites: landform → f = lerp(f, LF.woods(S,x,z,h,sl,f), landWOf);  else d<0.9R → 0, d<2.4R → lerp(f, sectWoodsK(S,x,z,h,h-hb2,sl), 1-smoothstep(1.9R,2.4R,d))
  lvzong: f *= smoothstep(500,900,d);  lingyan: d<700 → f = max(0.3f, 0.35*(1-smoothstep(300,650,d)))
  cities: within the moat square (Chebyshev) moat1+380 → 0  (fallback: radius 1100/800)
  F = clamp(f,0,1)
  ```
**Pass 2, the output map** `GW=1536 × GH` (2× the forest grid; the comment says "4×", line 3077, but 1536/768 = 2 per axis),
RGBA8:
- For each farm within its bbox: `w = 1 - smoothstep(0.5r, r, d + simplex2(x/500,z/500)*260)`, giving FA (field weight).
  `AA` (angle) comes from the farm with the highest weight. `YA` (yard) is `1 - smoothstep(0.6y, 1.2y, d + simplex2(x/90,z/90)*30)`.
- Roads: each road point stamps a 3×3 block in `RD`, with 2 at the centre and 1 around it.
- Per texel: `cityYard` can raise the yard and reduce the farm (`farm *= 1-cy`). Fields and yards are kept only on level dry
  ground: `flat = (1-smoothstep(1,6,hAt))*smoothstep(-25,-70,sdAt)`, then `farm *= flat*farms`, `yard *= flat`.
  `f = Fat(bilinear F) * (1 - min(1, 1.3 farm + yard))`. Roads multiply f by 0.15 at the centre and 0.6 next to it.
- **Channels:** `R = woods f`, `G = farm`, `B = yard / bare ground`, `A = (field angle / π)*255` (field-row orientation, 0..π).
- `WORLD.ground = {w,h,data}`, `WORLD.forest.at(x,z)` (bilinear R channel), `WORLD.groundAt(x,z)` (nearest RGB / 255).

### 2.8 Trees (`planTrees`, 3104–3257)
Output: `WORLD.trees`, a Float32Array with **7 floats per tree**: `[x, y, z, scale, kind, col, yaw]`, where
`yaw = hash2i(round(3x), round(3z), 18)*2π` (3113).
- kind (from usage): 0 pine (stacked cones), 1 broadleaf, 2 tall (bamboo/cypress), 3 黄山松 crag pine, 4 willow,
  5 flowering tree, 6 spirit tree, 7 lotus, 8 reed.
- col slots (comment 3105): 0 pine, 1 green broadleaf, 2 maple red, 3 ginkgo gold, 4 frost pine, 5 bamboo, 6 snow-white,
  7 autumn orange. Further ids used in code are 8/9 (peach/pear blossom), 10 willow, 11 spirit, 12 lotus, 13 reed, 14, 15.

`species(x,z,h,r1,r2)` (3115–3126), first match wins:
1. Landform disc weight > 0.45 → `LF.species`.
2. Regions (with `regionK` = 1-smoothstep(r0,r1,d), line 2076, rr = regions.radius):
   - baiqiao (1900rr, 3800rr)*maple, if `kb>0.12 && r1<0.9kb`: `[1, r2<0.42?2 : r2<0.72?7 : 3]`.
   - gujian (1700rr, 3400rr)*snow: `r2<0.08?[1,6]:[0,4]`.
   - luoyun (1600rr, 3200rr), if `r1<0.75kl`: `r2<0.55?[2,5]:[1,1]`.
3. `h>150 && r1<0.13` → `[3, r2<0.8?0:14]`. `h>40` → `r2<0.78?[0,0] : r2<0.86?[1,15] : [1,1]`.
4. `h<14 && r1<0.5 && sdAt>-120 && seaDist<-250` → willow `[4,10]`. `r1<0.05` → blossom `[5, r2<0.55?8:9]`.
5. Otherwise `r2<0.3?[0,0] : r2<0.8?[1,1] : r2<0.93?[1,15] : [2,5]`.

Filters (3127–3130):
- `slopeOK`: the normal's y component `1/hypot(gx,1,gz) > 0.58` (≈ < 54.5°), with an e=9 central difference, or h<3.
- `blocked`: `sdAt>-22` or `inSiteCore(0.9)` or `roadDist<9` or `groundAt.B > 0.25` or a sect spot.
- `hCap`: 450, or `max(450, sectTreeline(S))` within 2.4R of a sect. `sectTreeline = S.cloud + SECT_TREELINE[look]*k`, with
  `SECT_TREELINE = {ice:150, jade:290, gold:240, phoenix:270, earth:200, water:290}` (2232–2233).

Passes:
1. **Woods** (3131–3148): a jittered lattice, `sp = 21/sqrt(max(0.3, density))`, jitter ±0.475sp (hash seeds 11/12).
   - Skip if `f=forest.at < 0.05`.
   - In the new country, skip 38% (`hash>0.62`).
   - Clearings: `gap = smoothstep(-0.42,-0.12, simplex2(px/340+9.1, pz/340-2.7))`.
   - Keep probability `p = smoothstep(0.05,0.42,f)*(0.3+0.7gap)*(0.82+0.18*smoothstep(0.3,0.7,f))`, test `hash13 > p`.
   - Scale `(1+0.45 r7)*(0.9+0.3f)*(1-0.3 edge)*giant*(kind2?0.9:1)`, with `edge=1-smoothstep(0.08,0.4,f)` and
     `giant = 1.45 if r7>0.93 && f>0.5`. y = h−1.5.
2. **Mountain pines** (3149–3158): lattice 52, h in [25, 420].
   - Keep if `hash23 ≤ 0.34*D*(1-smoothstep(280,420,h))`, times `0.55*(1-0.8 arid)` in the new country.
   - Skip if `forest > 0.3`. Scale `0.8+0.4r`.
3. **Sect mountains (legacy, non-landform)** (3159–3182): lattice 24 inside 0.96R.
   - Height band `[S.cloud-70, treeline]`. Skip gradient > 1.1 (walls). Skip `gr<0.12 && h>cloud+150` (terraces). Skip
     within 18 of a platform, on the ridge stair, or on spots.
   - `crest = h - mean(hAt ±55)`. Keep if `hash63 ≤ (0.12+0.78*sectWoodsK(..., crest*1.6, gr))*D`.
   - Kind from `SECT_TREEKIND[look]` (line 6874: `ice:[0,4], gold:[1,2], jade:[2,5], phoenix:[1,1], earth:[1,7], water:[1,1]`)
     80% of the time, else broadleaf. Landform sects call `LF.plant` instead (3163).
4. **Roads** (3183–3193): RNG `mulberry32(919)`. Alternate on/off runs: on for `150+400r`, off for `800+1800r`, with
   `left -= 48` every 4th point. Each side has a 45% chance. Offset `w/2+8+14r`. Skip `sdAt>-14` or `hAt>60`.
   Willows `[4,10]` if `sdAt>-160`, else broadleaf `[1,1]`.
   **Villages:** one old tree at (+18,+10) with scale 2.1; 5 blossom trees at 60–150; 14 trees at 120–230 by species (pines become broadleaf).
5. **Groves** (3200–3207): `900*D` candidates.
   - New-country skip probability `0.3+0.6 arid`.
   - Require h ≤ 3, seaDist ≤ -300, forest ≤ 0.15, ground.G ≤ 0.3, and outside `inSiteCore(1.1)`.
   - Radius `40+80r`, count `round(8+34r*(r/120))`. 80% of trees use the grove's species.
6. **Lone trees** (3208–3214): `5600*D` candidates with h ≤ 2, forest ≤ 0.1, G ≤ 0.4, y = −1 (snapped later).
7. **Spirit trees** (3215–3221): 40 per site at `d ∈ [1.25R, 2.35R]`, h in [20,380], kind 6 col 11. Also 26 round 灵眼
   (`lingyan`) at 260–600 (kind 6 or 5).
8. **Water plants** (3222–3254):
   - Lotus (kind 7 col 12, y = -water.depth+0.15) on moats (every 9 along 4 sides, noise-gated) and in pools.
   - Reeds (kind 8 col 13) round the pool rims.
   - Marsh: an 8-丈 lattice inside lvzong `r*1.06`. Reeds where `-14 < marshSd < 1.2` (55%) or on reed beds; lotus on open
     water `4<ms<40` (6%).
   - River banks: every 2nd point with 22% probability, both sides, stepping 0–30, reeds where `-12<sdAt<2`.

---------------------------------------------------------------------------------------------------------------------------

## 3. 03c: seasons and plants (lines 3259–3484)

### 3.1 Season map (`planSeasons`, 3280–3306)
Config is `CONFIG.eco = {trees:1, ground:1, winter:[4600,7000], autumn:[5800,9200], spirit:1, lowPines:1, meadows:1,
verges:1}` (line 358).

Grid: `W=768 × H` (aspect-matched), cell-centred, RGBA8:
```
n1 = fbm(x/5200+3.1, z/5200-1.7, 3); n2 = fbm(x/6100-4.4, z/6100+2.2, 3)
nm = fbm(x/1500+8.3, z/1500-2.6, 2); np = 0.7*simplex2(x/620-5.1, z/620+1.9) + 0.3*simplex2(x/260+2.2, z/260-7.7)
w = 1 - smoothstep(4600, 7000, d(gujian)  + n1*1700 + nm*820)          # winter around 古剑门
a = 1 - smoothstep(5800, 9200, d(baiqiao) + n2*2100 + nm*900)          # autumn around 百巧院
w = clamp(w + np*0.5*4*w*(1-w)); a likewise                             # patches inside the border band
if w+a > 1: normalise
p = max(1-smoothstep(500,1400, d(lingyan)+n2*200), 1-smoothstep(300,900, d(dimai)+n1*150),
        max_S 0.32*smoothstep(0.95R,1.25R,d)*(1-smoothstep(1.5R,2.1R,d)))   # 灵地: basin, node, rings round sects
R = w, G = a, B = p*spirit, A = aridAt (dry steppe)
```
`WORLD.season.at(x,z)` returns bilinear `[w,a,p]`.

`seasonPick(x,z,h,r)` (3309–3317):
- `w = max(smoothstep(0.5,0.78,w0), smoothstep(snl-130, snl-40, h)*0.85*(1-0.95a))`, where `snl = snowLineAt` (line 4846).
- Return 'S' if both are < 0.004.
- Otherwise `rr = clamp(0.5 + (0.5*simplex2(x/260+5.5, z/260-1.3) + 0.12*simplex2(x/85-2.1, z/85+7.4))*1.3 + (r-0.5)*0.3, 0, 0.9999)`,
  and return `rr<w ? 'W' : rr<w+a(1-w) ? 'A' : 'S'`. This makes stands turn together (≈250 丈 groves).

### 3.2 Meadow library tree substitution (`ecoTreeFor`, 3320–3354)
Libraries: `ECO_TREES[S|A|W]` = birch2/4/6 + oak3/5/6 with a season suffix (3267–3271). Tints `ECO_TINT` (3277), where
w=2 means "frost shader mode".
- kind 6 → `spirit2|spirit4`.
- kind 5 (blossom):
  - S → spirit1/spirit4 tinted peach or pear.
  - W → 45% spirit1 tinted plum, else a winter birch/oak with frost.
  - A → `mapleR|mapleO`.
- kind 1, or kind 0 when `r3 < (y<150 ? 0.82 : y<290 ? 0.36 : 0)*(col4?0.5:1)*lowPines`:
  - On spirit ground (`sp>0.42 && r3<(sp-0.3)*0.5`) → spirit trees.
  - Otherwise birch vs oak stands: `stand = 0.8*simplex2(x/430+5.5,z/430-3.1) + 0.25*simplex2(x/150-2.2,z/150+7.7)`,
    `wet = (sdAt>-180?0.45:0) + (y>200?0.3:0)`, and `birch = stand+wet-0.15+(r1-0.5)*0.35 > 0`.
  - Winter: snowy procedural pines where `simplex2(x/320-7.7,z/320+2.9)+(r3-0.5)*0.5 > 0.05` (returns `ECO_PINE`), else frost tint.
  - Autumn non-birch with `r3>0.55` → maples.
- Size: `24*s*trees.size`, normalised by the model height and times width factors (oak 1.08, birch 1.22, maple 0.95,
  other 1.15). Autumn birch/oak get the warm tint `[1.07j, 0.99j, 0.84j, -0.28]`.

### 3.3 Ground plants (`planEcoGround`, 3362–3473; `ecoUnderstory`, 3476–3484)
Output is an `EcoList` (`id, x, y, z, scale, tint, flag`), RNG `mulberry32(8080)`. `ECO_SCALE` (3357) in 丈 per model metre:
`flower 16, grass 16, cover 17, fern 13, bush 6.5, sbush 6.5, sgrass 16`. Winter grass is `grass1W` 74% of the time, else
2W/3W, with rime tints (3360–3361).

`okGround`: `sdAt<-16`, `seaDist<-150`, not `inSiteCore(1.02)`, not within moat1+120 of a city, and `marshSd<-3`.

1. **By biome** (3381–3439): density table `DENS[biome] = [spacing 丈, keep prob]`:
   `FLOWER [14, 0.85*meadows]`, `MEADOW [32, 0.08]`, `VALLEY [20, 0.3*meadows]`, `BANK [18, 0.36]`, `MARSH [13, 0.5]`,
   `SPIRIT [18, 0.45]`, `BEACH [30, 0.1]`, `ARID [36, 0.07]`.
   - Blocks are B=240 丈. Probe 5 points per block and use the minimum spacing `sp0 /= sqrt(max(0.25, ground))`.
   - Per point: jitter. The class is read off-point, offset by `70*simplex(/160) + ±32` per axis, to dither borders.
   - `keep = D[1]*min(1, sp0²/D[0]² * max(0.25,ground))`. Clumping: FLOWER uses `0.2+0.8*smoothstep(0.3,0.6,drift)`, others
     `0.4+0.6*smoothstep(-0.3,0.35,simplex(/70))`.
   - Reject if h<-0.5 or h>380, `ground R>0.45 | G>0.25 | B>0.2`, `slopeY<0.84`, or `!okGround`.
   - Per-biome mixes (3408–3436):
     - FLOWER inside a drift (>0.45): dominant flower 72%, second flower 12%, grass otherwise. Between drifts: flower 20%,
       grass 72%, cover 8%.
     - MEADOW: grass 72%, flower 14%, then cover/bush.
     - VALLEY: grass 58%, flower 20%, fern 12%, cover/bush.
     - BANK: grass 50%, cover 25%, fern 15%, bush 10%.
     - MARSH: grass, fern, bush (spirit capped at 0.3).
     - SPIRIT: spirit grass/bush (sp≥0.6).
     - ARID: dry tufts 70%, `bush4A` 20%, `cover4A` 10%.
2. **Verges** (3440–3459):
   - Both sides of each road, 3 tries per point, each with probability `0.78*verges`.
   - Offset `w/2+1.5+(q==0 ? 5r : 4+12r)`.
   - Flower runs of `8–30` points share one flower species (`runF`). In woods (`f>0.35`, 30% of the time) ferns or bushes.
3. **Village gardens** (3460–3471): 70 tries at `d = 50+170√r`. Flowers 55%, grass 30%, bushes 15%.
4. `ecoUnderstory`: at wood edges (`0.06<f<0.6`), one bush, fern or cover plant 8–18 丈 from a tree.

---------------------------------------------------------------------------------------------------------------------------

## 4. 03d: terrain zoning (biome) map (lines 3486–3659)

### 4.1 Encoding
`BIOME = {SEA:0, BEACH:1, BANK:2, MARSH:3, FLOWER:4, MEADOW:5, FARM:6, TOWN:7, FOREST:8, PINE:9, BAMBOO:10, CLIFF:11,
ALPINE:12, SPIRIT:13, SECT:14, VALLEY:15, ARID:16}` (3497). Names are at 3498 and debug colours at 3499.

Grid: **W=1536 × H** (aspect-matched; "≈86 丈 a cell", line 3537), cell-centred. Outputs (`WORLD.biome`, 3647):
- `id`: Uint8 class per cell. `at(x,z)` is a nearest-cell lookup.
- `tex`: RGBA8 at W×H (the **tBiome** shader texture). R = flower-field weight, G = sand/pebble (beach and bank),
  B = marsh, A = lushness. `weights(x,z)` is bilinear.
- `tex2`: RGBA8 at **2W×2H** (≈43 丈, the **tBiome2** texture). RGB = the dominant flower's wash colour, A = the drift
  mask (×0.3 in winter). It is only written where the blurred flower weight is ≥ 0.03.
- `count`, and `WORLD.stats.biome` (% per class).

### 4.2 Inputs per cell (3539–3546, 3573–3580)
- `land = seaDist<0 && sdAt<0`, so water cells are SEA (rivers and lakes included).
- `h = max(0,hAt)`, slope `|∇h|` with a half-cell central difference.
- `hb = blur(blur(h,4),2)`. `valley = clamp((hb-h)/45,0,1)*(1-smoothstep(180,300,h))`.
- `sd = sdAt`, `seaD = seaDist`, `snl = snowLineAt`, `se = season.at`, `F = forest.at`, `G = groundAt`.
- `n1 = fbm(x/1400+3.3, z/1400-7.7, 3)`, `n2 = simplex2(x/520-1.1, z/520+2.9)`.
- Marsh distance: `dsw = d(lvzong) + simplex2(x/700,z/700)*0.18*swR`, with `swR = lvzong.r || 1500`.

**Flower seas** (3555–3568): candidates on an 1100-丈 lattice, 2000 in from the edges. Reject if `seaDist>-1500`, `h>70`,
`winter>0.35`, `forest>0.2`, `fields>0.1`, within 1.1·land.R (or 2.8R) of a sect, or within 3200 of a city.
Score = number of the 4 probes at ±700 that are open and level (`forest<0.25`, `|Δh|<30`) + `simplex2(x/3000,z/3000)`.
Take the best, at most **7**, at least **6500** apart, with radius `1000+650*hash`. 灵眼 (`lingyan`, r 900) is added.
`seaK = max over seas of 1-smoothstep(0.55r, r, d + simplex2(x/600+…, z/600)*0.35r)`.

### 4.3 Rules, first match wins (3583–3595)
| # | class | condition |
|---|---|---|
| 1 | SECT | `inSiteCore(x,z,1.0)` (inside any site radius) |
| 2 | MARSH | `dsw < 0.92*swR` |
| 3 | ALPINE | `h > snl - 70 + n2*40` |
| 4 | CLIFF | `sl > 1.05` or (`sl > 0.72` and `h > 140`) |
| 5 | BEACH | `seaD > -170` and `h < 10` and `sl < 0.25` |
| 6 | BANK | `sd > -70` and `h < 60` and `sl < 0.3` and `seaAt < 0.5` |
| 7 | TOWN | `groundAt.B > 0.25` |
| 8 | FARM | `groundAt.G > 0.3` |
| 9 | SPIRIT | `season.B > 0.45` and `sl < 0.5` |
| 10 | PINE / BAMBOO / FOREST | `F > 0.3`. PINE if `h > 230` or (`winter > 0.6` and `n2 > -0.2`). BAMBOO if within 7500 of 落云宗 (`luoyun`) and `n1 > 0.12` and `h < 230`. Else FOREST |
| 11 | FLOWER | `sl < 0.36` and `h < 280` and (`seaK > 0.45` or `n1 > 0.5` or (`valley + 0.12 n2 > 0.5` and `n2 > 0.25`)) |
| 12 | VALLEY | `valley > 0.42` and `sl < 0.45` and `h < 300` |
| 13 | MEADOW | otherwise |

Post rules:
- ARID override (3598–3599), only for MEADOW/VALLEY/FLOWER, when `ar > 0.2` and
  `ar + 0.18 n2 + 0.1 n1 - (VALLEY ? 0.15 : 0) - (sd > -400 ? 0.2*(1-smoothstep(-400,-120,sd)) : 0) > 0.5`.
- Landform override (3601–3602): if the cell is in a landform disc and `lnd.w + 0.25 n2 > 0.5` (and the class is not SECT),
  then `c = LF.biome(S,x,z,h,c,sl)` (§6.6).
- Lushness `wL = clamp(0.8 valley + (sd>-260 ? 0.35*(1-smoothstep(-260,-60,sd)) : 0) + (MARSH ? 0.6 : 0) + 0.25F, 0, 1)`,
  ×0.2 if ARID.

**Despeckle** (3606–3616): 2 passes over a 5×5 neighbourhood (24 neighbours). FLOWER with fewer than 12 flower neighbours
becomes MEADOW. MEADOW with more than 16 becomes FLOWER.

**Weights** (3617–3627):
- `wF`: FLOWER 1, MEADOW `0.2*smoothstep(0.38,0.52,n1)`, VALLEY 0.3, SPIRIT 0.5.
- `wS`: BEACH 1, BANK 0.75, ARID 0.22.
- `wM`: MARSH 1.
- Softened with a double box blur: `sF r2`, `sS r1`, `sM r2`, `sL r3`.

**Flower drift** (3500–3535):
- `flowerPatch` picks a pairing per warped 900-丈 cell (`hash2i(ci,cj,41)`).
- `flowerDrift` = `smoothstep(-0.06,0.22, fbm(u/900+4.4, v/380-1.9, 2) + 0.08*simplex2(u/240-2.2, v/120+6.6))` in a frame
  rotated by `a = 1.6*simplex2(x/5000+1.3, z/5000-2.1)` and warped by ±150.
- Pairings `FLOWER_PAIRS` are per season S/A/W, plus P for spirit ground (3507–3512). Colours are `FLOWER_WASH[1..10]` (3506).

### 4.4 Who reads the biome map
- 03c `planEcoGround` uses `BM.at` for the class and `flowerDriftAt` (tex2.a, 3530–3535).
- The ground shader (04, `flowerField`) uses tBiome/tBiome2 (comment 3495–3505).
- `biomeImage()` is the debug figure (3651–3659). Placement elsewhere reads `WORLD.biome` as well (the comment at 3487
  says "every placement and the ground's colour read this one map").

---------------------------------------------------------------------------------------------------------------------------

## 5. 03e: landform motif framework (lines 3661–3727)

Each sect site may carry `S.land = {kind, R, edge, core, …}`. `R` and `edge` are fractions in the definitions
(e.g. `R: 1.6, edge: 0.72`, lines 1248–1400), and the code reads `S.land.R` as an absolute radius. The comment at 3734 says
"compact disc (1.5–1.6 R)", so the scaling by S.R happens in `planSites`, outside this scope.

`LF(S)` returns `LANDFORMS[S.land.kind]` (3675).

Hooks (comment 3664–3671): `height(S,x,z,h,w)`, `water(S,x,z)`, `color(S,c,h,ny,x,z,w,r)`, `biome(S,x,z,h,c)`,
`woods(S,x,z,h)`, `plant(S,push,rnd)`, `clouds(S,clusters)`, `seaDens(S,x,z)`, `setup(S)`. 03l adds `reliefU`,
`afterRelief`, `species`, `seaCore`, `seaCoreField`, `farms` and `mirror`.

- `landOf(x,z)` (3677–3684) returns `[S, w = 1-smoothstep(R*edge, R, d), d]` for the first disc containing the point (unless
  `L.off`). `landWOf(S,x,z)` (3686) is the same weight for a given site.
- Toolbox:
  - `terraceH(h, step, soft=0.12, jit=0)` (3691–3694): `q=(h+jit)/step`, then `(floor q + smoothstep(0.5-0.5soft-0.001,
    0.5+0.5soft+0.001, frac q))*step - jit`.
  - `scatterIn(cx,cz,r0,r1,n,gap,ok,rnd,tries=40)` (3696–3708): dart throwing in an annulus (area-uniform radius),
    with a hash grid for the minimum distance.
  - `featureGrid(list, cell=200)` (3710–3716): buckets features by their reach.
  - `smin(a,b,k) = -smax(-a,-b,k)` (3718), with `smax` at 1070.
  - `rivDAt` (3721–3725): bilinear over `RELIEF.rivD`.
  - `ellipseF(u,v,cu,cv,a,b,rot)` (3727): normalised elliptical distance − 1.

---------------------------------------------------------------------------------------------------------------------------

## 6. 03l: sect mountains grown from the big map (lines 3729–4206)

### 6.1 Concept (comment 3730–3743)
1. The coarse relief gets the sect's masses as uplift (`reliefU`), so the erosion grows the group (§1.4 step 8).
2. A **15 丈** fine grid over the disc is re-routed. A stream-power profile high-pass gives gullies and spurs.
3. Heights are remapped between two anchors: valley floors go under the cloud sea, and each mass's summit goes to its target height.
4. A per-style rock treatment.
5. Pads, benches and terraces are cut for the halls.

The disc edge blends back to the coarse ground, so there are no seams.

### 6.2 Styles (`NAT_STYLES`, 3765–3779)
```
pillars  (落云宗):  detail 16, smooth 0, pillar {cell 118, fis [9,17], keep 0.56, jitter 130, above -55, floor 75}
granite  (古剑门):  detail 34, smooth 1, sharpen 0.4, needles {cell 46, p 0.22, above 150, h [26,84]}
volcanic (百巧院):  detail 26, smooth 2, bench {step 17, soft 0.42, k 0.55}
karst    (水影宗):  detail 8,  smooth 1
hill     (鸾鸣宗):  detail 20, smooth 2
loess    (倪航斋):  detail 36, smooth 0, plateau {band 16, k 0.1}, bench {step 7, soft 0.36, k 0.5}
```
Landform kinds (4200–4206). Each sets `{style, snowLine, ground, air:{col,k}, grade:[r,g,b,amt]}`:
| kind | style | snowLine | ground | air col / k | grade |
|---|---|---|---|---|---|
| natPillars | pillars | 3000 | 0.45 | [0.96,1.02,1.0] / 0.55 | [0.98,1.03,1.0,0.025] |
| natGranite | granite | **690** | 0.5 | [0.98,1.0,1.03] / 0.5 | [1.0,1.0,1.02,0.03] |
| natVolcanic | volcanic | 3000 | 0.62 | [1.06,0.98,0.9] / 0.65 | [1.05,0.99,0.92,0.03] |
| natKarst | karst | 3000 | 0.5 | [0.96,1.02,1.04] / 0.55 | [0.98,1.02,1.03,0.025], plus `mirror {k 0.6, tint 0.3, mask = smoothstep(0.03,0.12,lakeAt)}` |
| natHill | hill | 3000 | 0.5 | [1.03,0.99,0.97] / 0.5 | [1.02,1.0,0.98,0.025] |
| natLoess | loess | 3000 | 0.92 | [1.06,1.0,0.9] / 0.65 | [1.05,1.0,0.92,0.03] |

Per-sect data (out of scope, lines 1244–1412, summarised so you can rebuild):
| sect | kind | S.R | cloud / base | land R, edge, core, coreValley | masses (id: u,v,r,h,u0) | features |
|---|---|---|---|---|---|---|
| 古剑门 gujian (look ice) | natGranite | 1250 | 482 / 324 | 1.6, 0.72, 0.86, 0.55 | taibai (60,-580,340,940,1.65), jiange, dongling, beiling, xiqian, dongqian, shanmen, xiling, dongfeng (1250–1254) | bench `court` 400×420, rise 176, steps gate/arena/main/rear/crown/yards (1257–1262); pads jiange, dongling, stele |
| 落云宗 luoyun (jade) | natPillars | 1250 | 472 / 326 | 1.6, 0.72, 0.92, 0.5 | tianquan, huoyun (red 丹霞), beifeng, baifeng, yinjian, huanshi, suoyan, p1–p6 (1281–1287) | pads on pillar tops (`cellNear`) (1290–1293) |
| 百巧院 baiqiao (gold) | natVolcanic | 1250 | 476 / 330 | 1.6, 0.72, 0.86, 0.55 | fengwo (0,-580,380,946,1.65), west, east, shelf, sw, se (1314–1316) | `face {u0 -270, u1 270, v -362, bow 24, top 830, drop 26, cut:false}` (1318); bench `yard` 540×420 backSoft 18 |
| 鸾鸣宗 luanming (phoenix) | natHill | 1250 | 128 / 10 | 1.5, 0.72, 0.82, 0.5, warp 0.46, aspect 1.2, low 'keep' | luan (0,-300,520,344,1.3), dong, xi, qian (1345–1346) | bench `palace` 300×460 rise 190; pad summit |
| 倪航斋 nihang (earth) | natLoess | 1250 | 182 / 120 | 1.5, 0.72, 0.8, 0.7, low 116, top 262, under 40 | yuan, bei, liang1, liang2, mao (1378–1380) | 8 gullies `{pts, w 44–74, d 66–108}` (1372–1375); bench `bao` 520×380 |
| 水影宗 shuiying (water) | natKarst | 1250 | 14 / 6 | 1.5, 0.72, low 'keep' | dao (0,-40,200,96,0.9), bei (1402) | lake `{u 40, v -130, rx 1000, rz 660, rot 0.18, shore 30, arms…}` (1401); towerField `n 26, clusters 4, r [38,84], h [70,210], islets 10` (1403); bench `isle` 4 steps; pad pier h 7 |

### 6.3 `setup(S)` (3781–3822)
- All local coordinates `(u,v)` are scaled by `S.k` and offset by the site position.
- masses: `{x,z,r,h,ax,cs,sn}`.
- padDefs.
- benchDefs: `{x,z,w,d,rise,soft(110 default)*k,h,yaw,cs,sn, slope = rise/d}`.
- faceW: `{x0,x1,z,bow,top,drop(26)}`.
- lakeW: `{x,z,rx,rz,cs,sn,shore(30),arms}`.
- **Karst tower field** (3795–3816), RNG `mulberry32(S.idx*9151+77)`:
  - Clusters `[cu,cv,cr,cn]`: area-uniform positions with v squashed ×0.8. `r = lerp(r0,r1,rnd)`.
    `h = lerp(h0,h1,rnd^0.7)*(1-0.45 d/cr)*(1-0.4*smoothstep(-200,400,v))`.
  - Non-overlap: separation > `(r+r')*1.08`, and the `keep` discs are avoided.
  - Islets: 10 at ring 360–700 (×1.3 in u), `r = 20+18rnd`, `h = 30+45rnd`, `lob 0.22`.
- towerDefs: per tower `p = 2+2.2hash`, `q = 0.45+0.35hash`, lean `lx, lz ∈ ±0.25`, `lob 0.16` default.
- `S.patchRect = ±0.93 L.R`, which is where the fine mesh covers the ground. `L.cloudCore = (core||1.15)*S.R`. Soft plats are dropped.

### 6.4 `afterRelief(S)`: the fine sect terrain (3831–3983)
Grid: `c = 15*k`, `E = L.R`, `n = ceil(2E/c)+1` (square, node-centred from `S-E`). With L.R = 1.6×1250 = 2000 and k = 1,
that is n = 268. Data: `hc` (n²) = `baseHeight` with this landform switched off (`L.off = true`, 3835–3838).

**Step 1: fine drainage high-pass** (3839–3861)
```
base = d > 0.985E or border;  e = hc + hash2i(i,j,401+S.idx)*0.6
floodRoute(n,n,e,base,rec,order,1e-3); A accumulate
hs[c] = hs[r] + (diag?1.414:1) * exp(0.5*fbm(X/900+2.3*idx, Z/900-1.1, 2)) * A^-0.5         # unit-free profile, m = 0.5
hp = hs - boxBlurF(hs, r=5)                     # high-pass (≈75*k 丈 radius)
hpS = 1 / p95(|hp|) sampled every 7th cell
amp = detail*k * smoothstep(cloud-220k, cloud+40k, hc) * (0.45 + 0.55*smoothstep(0.05, 0.5, |∇hc|))
H = hc + amp * clamp(hp*hpS, -1.4, 1.4)
```
**Step 2: two-anchor remap** (3862–3880)
```
Lv = p25 of H inside 1.05 S.R (every 3rd cell)
TL = low=='keep' ? Lv : low!=null ? low*k : min(Lv, cloud - (under ?? 70)*k)
m.hm = max H where dm(m) < 0.55, floored at Lv + 20k
per cell: w_m = exp(-1.6 dm²)+1e-4 ; hh = Σw hm / Σw ; th = Σw m.h / Σw
t  = (H - Lv)/max(20k, hh - Lv)
h2 = H <= Lv ? H - (Lv - TL) : TL + t*(th - TL)
H  = lerp(H, h2, 1 - smoothstep(1.18 S.R, 0.97E, d))         # fade back to the coarse ground at the rim
```
**Step 3: rock style**, applied in this order (3881–3973):
1. `smooth` passes: `H = lerp(H, boxBlur(H,1), 0.5)`.
2. `sharpen` (granite): `H += (H-cloud)*0.4*clamp(hp*hpS, -0.6, 1)` above the cloud.
3. `bench` (volcanic, loess): above `cloud-30k`, `H = lerp(H, terraceH(H, step*k, soft, 6k*simplex(x/120,z/120)), k_b*(1-smoothstep(0.25,0.9,slope)))`.
4. `face` (百巧院, cut:false, a scarp). The face line is
   `zf = F.z + bow*4u(1-u) + 22k*simplex(x/90) + 12k*simplex(x/33) + 34k*simplex(x/170)`.
   Behind it (`s=z-zf<0`), the ground is raised toward `tt = lerp(top-160k, top, 1-0.55(2u-1)²) + 30k*noise - 70k(1-couloir)…`
   over `smoothstep(-300k,-150k,s)*(1-smoothstep(-10k,0,s))`. The cut:true variant digs instead.
5. `plateau` (loess): `T = top*k - band*k`. Above T, `H = T + (H-T)*0.1 + 2.5k*simplex(/260)`. Within 70k below T,
   `H = T - rb*((T-H)/rb)^0.55` (a sharp rim).
6. Loess gullies: polyline distance `bd` and normalised position `bt`. Width `w*(1-0.55bt)*(1+0.18 noise)`, floor
   `T - d*k*(1-0.6bt)`, weight `1-smoothstep(0.42,1,bd/width)`. Walls get `terraceH(H, 8k, 0.36, …)` at half weight.
7. Lake (karst): inside `lakeAt > 0`, for cells with `H ≤ shore`, lerp toward 0. `lakeAt` (4059–4065) is a lobed ellipse,
   `d·(1+0.12 sin3a+0.08 sin5a+0.05 sin9a) + 0.09 fbm`, combined with the inflow arms by min, and returns `1-d`.
8. Karst towers: `rr = r(1 + lob sin(3a+ph) + 0.08 sin(5a-ph) + 0.06 noise)`, with a lean offset. Profile
   `(1 - t^p)^q`, then `H = max(H, g0 + h*prof*notch)`, where g0 is the ground height at the tower centre.
9. Pillars (落云宗), 3945–3963:
   - Worley over a frame rotated by `0.55+0.3*idx` and squashed 0.82, with cell `118k`. Zone
     `smoothstep(cloud-55k, cloud+25k, H)`; benches and pads are kept out.
   - Joint width `fis = lerp(9,17,hash)*k`, `p = smoothstep(fis, fis+7k, (f2-f1)/2)`.
   - `keep = hash < 0.56*(1-0.35*smoothstep(0.7,1.5,nearest dm))`.
   - `floor = min(H, cloud-(75+45 noise)k)`. `top = keep ? H+(hash2-0.5)*130k : lerp(floor,H,0.32)` (collapsed stubs).
   - `H = lerp(H, lerp(floor,top,p), zone*ko)`. Kept cells are recorded in `L.cells {x,z,id,r=0.32cs,h}`.
10. Needles (granite): Worley cell `46k`, `p 0.22`, where H exceeds `cloud+150k`.
    `H += lerp(26,84,hash)*k * pf² * smoothstep(0,60k,up)`, with `pf = 1-smoothstep(0.08cs, 0.42cs, f1)`.

**Step 4: benches, terraces, pads** (3974–3982, helpers 3993–4057):
- `_bench`: the level `L0` is the mean of a 5×5 sample over ±0.42 of the footprint (slope-corrected), or the fixed `h`.
  It is floored at `cloud + (above ?? 50)k`. Blend inside a rounded rect (corner `min(w,d)*0.34`, or round) whose rim
  wanders with `rag = 30k*simplex(/230)+11k*simplex(/70)` (inward capped at `notch 22k`) over `soft` (`backSoft` gives a
  sheer back wall). Target `L0 + clamp(a)*slope`.
- `_terrace`: a level pad at `L0 + a*slope + dy`, with a skirt (7k default). Registered as a soft plat (`S.plats`, `L.pads`).
- `_pad`: search 16 directions × radius steps of 10k for the highest point (with a −0.08 per 丈 distance penalty), or the
  nearest kept pillar (`cellNear`). It shrinks r ×0.8 (up to 5 times) while the summit is too narrow. The level is the rim's
  `pct` percentile (0.3 default) minus `drop`, floored at `cloud+16k`. Pillar pads below `cloud+28k` are skipped.
  Below the pad, fill extends `max(10k, 0.45r)`; above it, a 5k bank cut.
- Result `L.F = {x0,z0,c,n,H}`. `height()` returns `lerp(h, bilinear(L.F.H), w)` (4076–4079), and `baseHeight` calls it last.

### 6.5 Colours per style (`color`, 4081–4120)
`steep = smoothstep(0.82, 0.5, ny)`, where ny is the normal's y component.
- **pillars:** top green `[0.42,0.56,0.34]…[0.34,0.47,0.3]`, sandstone walls `[0.66,0.63,0.55]/[0.5,0.49,0.44]` streaked
  `[0.38,0.37,0.33]`. On the `huoyun` mass, red 丹霞 bands `[0.74,0.39,0.27]/[0.63,0.31,0.22]` every 13k.
- **karst:** grey limestone walls, green crowns, paddy `[0.52,0.66,0.42]` below 14k.
- **hill:** grass/rock with `steep*0.85`.
- **loess:** walls banded every 6k (`[0.8,0.66,0.46]/[0.74,0.6,0.41]`). The top is strip fields rotated 0.42 rad, 150k×64k
  plots, with six crop colours.
- **granite:** rock `[0.56,0.58,0.62]…`. White caps above `cloud+230..330k`. Snow on gentle ground at `cloud+50..130k` (×0.62).
- **volcanic:** basalt with an ochre band every third 15k, autumn-litter ground, and a banded tuff on the face.
- The weight w is reduced on the hill/karst plain (`h - Lv < 10..34k`) and for loess (`16..64k`).

### 6.6 Biome / woods / species / plant / clouds hooks (4121–4197)
- `biome`:
  - `sl>0.85` → CLIFF.
  - hill/karst plain (`h-Lv < 22k`, not lake) → keep the country's class.
  - `h < cloud-10k` → FOREST.
  - karst: `h<10k` → MEADOW, else FOREST.
  - loess: `h > (top-34)k` → FARM, else ARID.
  - granite: `h > cloud+260k` → ALPINE, else PINE.
  - otherwise FOREST.
- `woods`:
  - 0 on pads. On the hill/karst plain, the country's own f0 (0 on the lake).
  - 0 in a band `|h-cloud+14k| < 24k` (the sea surface). 0.12 under the sea.
  - pillars: `sl>0.9` → 0.04, else 0.75.
  - karst: `h<8k` → 0.04, `sl>1.25` → 0.06, else 0.82.
  - hill: `sl>1` → 0.05, else 0.55.
  - loess: `sl>0.8` → 0.02, tableland 0.08, gullies 0.3.
  - granite: `sl>0.95` → 0, high 0.08, else 0.42.
  - volcanic: `sl>1` → 0.03, else 0.64.
- `species` (4144–4152):
  - pillars: 62% 黄山松 `[3,0]`, 12% blossom, 8% snow-white, else broadleaf.
  - granite: above `cloud-20k` frost pine 70% / crag pine, below pine/broadleaf.
  - karst: broadleaf / bamboo / pine / willow.
  - hill: gold, red, green, blossom.
  - loess: jujube/elm `[1,13]`, willow, `[1,7]`.
  - volcanic: maple, ginkgo, bamboo, pine.
- `plant`: every pillar cell with `h ≥ cloud+30k` gets 2–6 trees (85% crag pine) within 0.75r, if they stand within 25k of the top.
- `clouds`: wisps round the pillars, rings round tall masses, mid-height mist bands, lake mist and tower-foot mist, mist under
  bench lips, and island rings.
- `seaCoreField` (4165–4175): the sea core is inside `Rc*(1 + coreValley*clamp((blur-h)/80k, -1, 1))`, on a domain warped by
  `coreWarp*Rc*fbm(/760)` with `coreAspect`. Valleys let the sea reach further out.

---------------------------------------------------------------------------------------------------------------------------

## 7. Godot 4 / Blender mapping

### 7.1 What to bake offline (recommended file set)
| asset | source | resolution / format | channel layout |
|---|---|---|---|
| Coarse relief (optional, for LOD/far terrain) | `RELIEF.h` | W×H at 100 丈, **EXR float32** (single R) | height in 丈 |
| **Final heightmap** | `WORLD.H` (40 丈 grid, after `carveStreams` and `carveWater`) plus the per-sect fine 15-丈 `L.F.H` patches | EXR R32 or **R16** (normalise by the max ≈ 950–1300 丈; store min/max in JSON). Tile it, e.g. 1024² regions | height |
| Sect detail patches | `S.land.F` (n×n at 15k 丈) for each of the 6 sects, `S.patchRect` | EXR float per sect | height |
| Drainage | `RELIEF.logA` | EXR at the relief grid | ln(cells), for wetness / valley tint (`smoothstep(1.2,6.5,·)`) |
| Valley-floor level | `RELIEF.low` | EXR | cloud-sea fill level |
| **Ground splat** | `WORLD.ground.data` | 1536×GH RGBA8 PNG | R woods, G fields, B yards/bare, A field-row angle/π |
| **Season map** | `WORLD.season.data` | 768×H RGBA8 | R winter, G autumn, B spirit, A arid |
| **Biome class** | `WORLD.biome.id` | 1536×H **R8 PNG (nearest, no filtering)** | class 0–16 |
| **Biome weights** (tBiome) | `WORLD.biome.tex` | 1536×H RGBA8 | R flower, G sand, B marsh, A lush |
| Flower wash (tBiome2) | `WORLD.biome.tex2` | 3072×2H RGBA8 | RGB flower colour, A drift |
| Water mask / flow | `paintRivers` canvas (and `water.maskSize 4608`, line 353) | RGBA8 | mask white; flow RG = dir*0.5+0.5 |
| Roads | `WORLD.roads[]` `{a,b,w,kind,pts}` | JSON polylines (12-丈 spacing) | y from the heightmap |
| Rivers / streams | `WORLD.rivers[]` `[x,z,width]`, `WORLD.streams[]` `[x,z,waterY]` with `w:[w0,w1]`, `falls` | JSON | |
| Villages, roadside, bridges | `WORLD.villages`, `WORLD.roadside`, `WORLD.bridges` | JSON | transform + type |
| Trees | `WORLD.trees` Float32 ×7 | binary (`.bin`) | x,y,z,scale,kind,col,yaw |
| Ground plants | `WORLD.ecoGround` (EcoList) | binary | id,x,y,z,scale,tint |

The easiest and most faithful way to produce all of these is a **Puppeteer script** that loads `index.html`, waits for
`WORLD.ready`, and serialises the typed arrays (`Float32Array` → `.bin`, `Uint8Array` RGBA → PNG via an
`OffscreenCanvas`/`ImageData` or raw). Re-implementing in numpy (§1.10) is only needed to iterate on parameters.

### 7.2 Blender
- Import the heightmap as a displaced grid (Geometry Nodes "Grid" + "Set Position" sampling the EXR image texture), or
  use the A.N.T. Landscape add-on with a custom image. Scale 1 丈 to whatever metre scale you choose; the demo is a
  "sandbox" scale where peaks are about 950 丈.
- Do the sect fine patches in Blender. Merge the 15-丈 `L.F.H` patches into the 40-丈 base with the same `w` blend
  (`1-smoothstep(R*edge, R, d)`), or keep them as separate higher-density meshes, as the demo does (`S.patchRect`, `buildPatches`).
- Reproduce the ink/axe-cut facet look with a low-poly decimated mesh (the demo uses `terrain.grid 40` faceting). Bake
  curvature/AO for the ridge ink lines if desired.
- Road and river curves: import the JSON as Bezier/poly curves (Python `bpy`). Shrinkwrap them to the terrain, then sweep
  a profile (width = `w`) for ribbons, and export as glTF.

### 7.3 Godot 4
- **Terrain:**
  - **Terrain3D** (GDExtension) imports EXR/R16 heightmaps per region, supports a control map (a splat index), and is
    LOD/clipmap-based. It is well suited to a world of 132k 丈 at 40 丈 per vertex (≈3300² vertices), at a vertex spacing ≈ 40 丈 in your scale.
    Feed it the biome class as its texture IDs and the season/ground maps as extra global shader textures.
  - Alternatively, build a **custom chunked `ArrayMesh`** (e.g. 128×128-vertex chunks plus a far LOD from `RELIEF.h`).
    This is preferable if you want the faceted flat-shaded ink style, which a smooth clipmap terrain fights against. The
    sect fine patches become their own denser chunks.
- **Splat / shader:** one `ShaderMaterial` sampling the ground (R/G/B/A), season, biome tBiome and tBiome2 textures in
  world-XZ UVs (`uv = (xz - rect.xy)/rect.size`). Biome class: sample with `filter_nearest`.
- **Roads:** `Path3D` + `Curve3D` per road (points from JSON, y = height + 0.3). Draw them with `CSGPolygon3D` in Path mode
  (prototype) or a generated ribbon `ArrayMesh` (production), or paint them into the splat (the demo clears woods along roads
  and has a `roadDist` field; bake a road SDF texture).
- **Rivers:** `Path3D` ribbons with a flow-map shader (bake the flow RG texture). Great rivers and lakes go in a water plane
  masked by the water mask. Falls are separate meshes or particles along `falls[].pts`.
- **Instances:** `MultiMeshInstance3D`, one per (kind, col) or per Meadow library model. Transform = translate(x,y,z) ·
  rotY(yaw) · scale(s × base size; ecoTreeFor uses 24·s). Use per-instance custom data for tint (`ECO_TINT`, with w=2 for
  frost mode) and season. Chunk the MultiMeshes spatially (e.g. 2k 丈 tiles) and set `visibility_range` for culling.
  Ground plants (hundreds of thousands) are better as GPU particles or chunked MultiMesh with impostor cards.
- **Buildings and props:** villages, roadside buildings and bridges become `PackedScene` instances placed from JSON, with
  orientation from `face`/`yaw`. Bridges span `p0→p1`.

### 7.4 Bake pipeline: step order (mirrors `buildWorld`, 2347–2379)
1. Inputs: selfmate density raster, sea polygon / `seaDist`, GEO rivers, layout marks, sites (with `land` defs), cities.
2. **03a relief:** U/K/base/kind → 5 × (flood-route → accumulate → integrate) → diffuse ×6 → p97 scale + tanh cap →
   lowland routing (rec2/A2) → logA, low. Export `RELIEF.*`.
3. **03l** for each landform sect: the fine 15-丈 grid. Sample baseHeight without the landform, then high-pass erosion
   detail, two-anchor remap, rock style, benches/terraces/pads. Export `L.F`.
4. **Heightfield (04, out of scope):** `baseHeight`/`terrainHeight` on the 40-丈 grid, giving `WORLD.H`.
5. **03b water:** streams, rivers, great rivers. `carveStreams` edits H, falls are detected, then water mask, marsh and
   `carveWater` (out of scope). Export the final H after this step.
6. **03b roads:** cost grid (100 丈) → A* per link (with cost sharing) → villages + lanes → bridges → roadside buildings →
   arches → roadDist.
7. **03b ground map:** forest F (768), then the RGBA 1536 map.
8. **03c seasons** (768 RGBA).
9. **03d biomes** (1536 class + tBiome + tBiome2).
10. **03b trees** (needs ground, seasons, biomes and sect spots) → **03c ecoGround** (needs biomes and roads).
11. Export the instance lists and splines, then import into Blender (meshes, curves) and Godot (Terrain3D or chunks,
    Path3D, MultiMesh).

### 7.5 Gotchas for a faithful port
- Node-centred relief grid (`+1`, `X=x0+iC`) vs the cell-centred `gridOf`, ground, season and biome grids (`+0.5`).
- The receiver is the flood parent, not D8 steepest descent. Drainage area is counted in cells (A starts at 1), not 丈².
- Integer hashing must reproduce `Math.imul` and `>>>` semantics exactly.
- The biome rules are order-dependent, as is the despeckle (2 passes, 5×5, thresholds 12/16).
- `riverArea` is unused. The legacy non-landform sect branches in 03a and 03b are dormant with the current data (all six
  sites define `land`; this is inferred from lines 1248–1400).
- The ground-map comment says "4×" (line 3077), but the code is 2× per axis (768 → 1536).
- The biome comment says "~65 丈 a cell" (line 3488), but the code comment says ≈86 丈 (line 3537) after the v4.1 world enlargement.
