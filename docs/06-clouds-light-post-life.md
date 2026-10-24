# F — Clouds, FX, Figure, Post-processing, Ambience, NPCs, Life

Source: `demo/index.html`. Scope: lines 12116–13142 (07, 07c, 07d, 07e, 08, 08b, 09) and 13307–14077 (11, 11b, 11c).
A few referenced definitions outside the scope were looked up and are cited as such (CONFIG at 320–383, `veil()` 472, `U` shared uniforms 480–489, `GLSL_NOISE` 491–499, tone helpers 4291–4330, frame loop 14938–14963, player dun state 14213–14216).

Units: world units are 丈 (zhang). `A` is the camera rig's effective altitude (`CAMERA_RIG.Aeff`, frame loop 14938) and is the main input to almost every system here.

---

## 0. Shared context (outside scope, needed to read everything below)

### 0.1 Altitude bands, CONFIG (lines 320–383)

| key | value | line |
|---|---|---|
| `zoom` | `low 950, mid 1650, high 8000, mapAt 11000, start 1650` | 327 |
| `flight` | `speed 0.12` (cruise speed = `0.12*A` 丈/s), `boostMul 3.0`, `dunIn 0.22`, `dunOut 0.55` | 320 |
| `figure` | `on false, size 1.5, lean 30 (deg), boostLean 66 (deg), bank 22 (deg), fade 0.22` | 323 |
| `life` | `amount 1, people 1, traffic 1, boats 1, ships 1, flyboats 1, deer 28, scale 1.15, far 3000, motes 180` | 341 |
| `cloudSea` | `amount 1.0, height 175, billow 1.0, speed 1.0, spread 1.0, thick 150, density 1.0, steps 9, valley 75, hollow 1.0, hollowLo 30, hollowHi 150` | 351 |
| `lore` | `amount 1.0, flyers 8, flyerSpeed 340` | 363 |
| `light` | `core '#e8fff6', glow '#3fd9b0', size 1.0, tail 1.0, breath 0.08, intensity 0.85, shadow 0.32, speedLines 0.6` | 375 |
| `clouds` | `amount 1.0, speed 1.0, banks 1.0, mist 0.5, nearEvery 10, nearOpacity 0.5, shadows 0.16, wall 1.0` | 377 |
| `look` | `tiltShift 1.0, focusBand 0.18, paper 0.24, vignette 0.38, edgeFade 0.05, detail 1.0, pixelRatio 1.0, haze 0.5, edgeInk 0.7, ground 1.0` | 380 |
| `cinema` | `grade 1.0, valleyMist 0.8, shafts 1.0, cirrus 1.0, warmth 0.6, vignette 0.35, region 1.0` | 383 |

### 0.2 Global mode uniforms (`U`, 480–489)
- `uTime`, `uInk` (ink-line strength in the intro), `uWash` (0→1 as the opening ink wash completes), `uCloudIn` (0→1 clouds fade in during the opening), `uMap` (0 = flight, 1 = 舆图 map mode).
- `uMist = (0.86, 0.87, 0.84)` the painting's mist white; `uInkCol = (0.24, 0.27, 0.31)`; `uWind = (0.9, 0.25)`.
- **Map-mode convention used everywhere:** vertex shaders do `y *= 1.0 - uMap` (e.g. 12131, 12309, 12511, 12608, 12640, 13328, 13480, 13762) — the whole 3D world collapses onto the y=0 plane as you go to map view, and most FX also multiply their alpha by `(1 - uMap)`.

### 0.3 `veil()` blending (472–476)
```js
mat.blending = CustomBlending; blendEquation = Add; blendSrc = SrcAlpha; blendDst = OneMinusSrcAlpha;
blendEquationAlpha = Add; blendSrcAlpha = Zero; blendDstAlpha = OneMinusSrcAlpha;
```
Colour is ordinary alpha-over, but the **alpha channel accumulates transmittance**: `dstA *= (1 - srcA)`. After all veiled transparents, the target alpha = how much of the opaque scene is still visible. The ink-edge pass (09) multiplies its outline by this (`edge *= c.a`, 13044), so outlines never show through clouds. Used by: card clouds (12183), cloud sea (12480), cirrus (12606), cloud falls (12691).

### 0.4 Noise (491–499)
`hash12`, `vnoise` (value noise, smoothstep fade), `fbm3` (3 octaves, lacunarity 2.03/2.01, offsets 17.1/5.3, normalised /0.875), `fbm5` (5 octaves, ×2.02 + (13.7,5.1)). All 2D.

### 0.5 Frame-loop order (14946–14963)
```
updateClouds(dt, camera, A, PLAYER.vel)   // 07
updateCloudSea(A)                         // 07c (+ cloud-fall alpha)
updateSky(camera, A)                      // 07d
... updateSects, updateCities, updateLore
updateFlyers(dt, camera, A)               // 11b
updateLife(dt, A, camera)                 // 11c (+ motes, deer)
updateGlow(camera, A)
updateAtmos(dt, camera, A)                // 11
fy = clamp(lerp(0.5, lightScreenY*0.5+0.5, 0.4), 0.3, 0.7)   // tilt-shift focus row (14957–14958)
updatePost(A, fy)                         // 09
composer.render(dt)
```
The light (`DG.update`) and figure (`FIG.update`) are called from the player/mode code (14167, 14227–14228, 14338, 14351). Camera clip planes: `near = max(5, camY*0.05)`, `far = camY*40 + 30000` (14940).

### 0.6 Render-order map (Three.js `renderOrder`, low draws first)
| order | object | line |
|---|---|---|
| 2 | life movers (walkers, carts, …, deer) | 13930, 13962 |
| 5 | cranes (opaque) | 13376 |
| 7 | cloud falls | 12691 |
| 8 | cloud sea | 12481 |
| 9 | god-ray shafts; spirit motes | 12576, 14050 |
| 10 | mist/bank/belt card clouds | 12200 |
| 11 | sword light; spirit halo; NPC flyer tails & heads | 13392, 13455, 13525, 13529 |
| 12 | edge cloud wall | 12222 |
| 13 | cirrus; furnace smoke cards | 12612, 13425 |
| 37 / 38 | figure ink shell / figure parts & ribbons | 12889, 12888, 12924 |
| 39 | ink speed lines | 12756 |
| 40 | dun-light trail | 12749 |
| 41 / 42 / 44 | halo glow / inner glow + beam / head glow | 12735, 12742 |
| 50 | near fly-through cloud cards (depthTest off) | 12230 |

---

## 1. 07 · Card clouds (12116–12277)

### 1.1 Technique
Every cloud is a **camera-facing billboard instanced from one `PlaneGeometry(1,1)`** (`InstancedBufferGeometry`, 12168–12174). Three layers (`cloudLayer(n, order, fadeNear, fadeFar, depthTest)`, 12167):

| layer | capacity | order | fadeNear/Far (initial) | depthTest | built at |
|---|---|---|---|---|---|
| `CLOUDS.mist` (kinds 0,1,2,3) | Σ ceil(c.n·max(0.2, amount)) | 10 | 160 / 700 | true | 12200 |
| `CLOUDS.wall` (kind 6) | 3 per wall point | 12 | 600 / 3000 | true | 12222 |
| `CLOUDS.near` (kind 5) | 6 | 50 | 120 / 900 | **false** | 12230 |
| smoke (kind 7, §5.3) | 7 per source | 13 | 60 / 300 | true | 13425 |

All: `transparent: true, depthWrite: false`, `veil()` blending, `frustumCulled = false` (12181–12184).

### 1.2 Per-instance attributes (12121–12123, writer `setCloud` 12188–12193)
- `iPos = (x, y, z, sway)`
- `iSize = (w, h, flip, 0)` — `flip = seed > 0.5 ? 1 : 0` (12191)
- `iData = (seed, opacity, kind, driftPhase)` — `driftPhase = (seed*7.31) % 1` (12192)
- Kinds: 0 mist, 1 bank, 2 belt, 3 sect mist, 5 near, 6 wall, 7 smoke.

### 1.3 Vertex shader `CLOUD_VS` (12120–12137)
```glsl
vec3 c = iPos.xyz;
float t = uTime * uSpeed;
c.xz += uWind * sin(t * 0.045 + iData.w * 6.283) * iPos.w;   // slow sway along wind, amplitude = sway
c.y *= 1.0 - uMap;
vec3 right = vec3(viewMatrix[0][0], viewMatrix[1][0], viewMatrix[2][0]);
vec3 up    = vec3(viewMatrix[0][1], viewMatrix[1][1], viewMatrix[2][1]);
vec3 wp = c + right * position.x * iSize.x + up * position.y * iSize.y;   // full spherical billboard
```
Sway amounts: banks (kind 1) 120, others 40 (12212); wall 140 (12226); near 0.

### 1.4 Fragment shader `CLOUD_FS` (12138–12165)
Two shape paths:
```glsl
float n = fbm3(uv * vec2(3.2, 1.8) + seed + uTime * 0.012);          // seed = iData.x*37
if (uHasTex > 0.5) {                                                   // cloud.png brush texture available
  vec4 t = texture2D(tCloud, uv);
  a = t.a * smoothstep(0.02, 0.62, t.a + (n - 0.5) * 0.3);           // noise-eroded, soft edge
  col = mix(uShade, uMist * 1.06, smoothstep(0.3, 0.95, dot(t.rgb, vec3(0.33)) + (uv.y - 0.5) * 0.25));
} else {                                                               // procedural blob
  vec2 p = (uv - 0.5) * vec2(2.0, 2.6);
  float body = 1.0 - smoothstep(0.35, 1.0, length(p * vec2(0.85, 1.0)) + (n - 0.5) * 0.9);
  a = body * smoothstep(0.0, 0.25, uv.y);                              // flat-ish bottom fade
  col = mix(uShade, uMist * 1.05, smoothstep(0.15, 0.85, uv.y + (n - 0.5) * 0.4));  // shaded bottom → lit top
}
float d = length(vWp - uCamPos);
a *= smoothstep(uFadeNear, uFadeFar, d);                               // thins as camera approaches (fly-through)
if (vData.z < 4.5) a *= mix(1.0, smoothstep(uPart.x, uPart.y, length(vWp.xz - uTarget)),
                            step(0.5, vData.z) * step(vData.z, 1.5));  // ONLY kind 1 (banks) part around the light
a *= vData.y * uGlobal;
if (a < 0.004) discard;
```
Uniform defaults (12176–12180): `uShade = (0.68, 0.73, 0.74)`, `uMist = U.uMist`, `uPart = (300, 800)`, `uGlobal = 1`, `uSpeed = 1`, `tCloud = BASE.cloudTex` (`uHasTex` = 1 if it loaded).

Note: although the comment says "banks part round the light", the step logic restricts parting to kind == 1 exactly.

### 1.5 Placement (`buildClouds`, 12194–12235)
Source = `WORLD.clusters` (planned outside scope, lines ~2082–2121 and ~4180–4196). Each cluster: `{x, z, r, n, y0, y1, w0, w1, op, kind, ring}`. Examples from the planner: pillar belt ring `n 11, w 300–520, op 0.92, kind 2` (2082); peak-waist belt rings `w 220–420, op 0.82, kind 2` (2085); sect hazes `kind 3, op 0.5 / 0.42` (2095, 2097); valley mist `kind 0, op = CONFIG.clouds.mist` (2108); waterfall spray at fall foot `kind 0, op 0.5/0.65, y = bottom+6..+40` (2119).

Per cluster, `n = max(1, round(c.n * amount))` cards (12203):
- **ring** clusters: angle `(k/n)·2π + rnd·0.4`, radius `c.r`, z squashed ×0.8 (12206) → a belt around a peak's waist.
- otherwise: uniform disc `r·sqrt(rnd)`, z squashed ×0.75 (12207).
- width `w = lerp(w0, w1, rnd)`; height `h = w·(0.42+0.12rnd)` for banks, `w·(0.28+0.1rnd)` for others (12208).
- `y = lerp(y0, y1, rnd) + 0.25h`; mist (kind 0) is lifted so its card bottom clears ground: `y = max(y, max(0, hAt(x,z)) + 0.48h + 3)` (12210).
- opacity `op = (kind 0 ? clouds.mist : c.op) · (0.6 + 0.4 rnd)` (12211).
- RNG: `mulberry32(2024)` (12197) — deterministic.

**Edge cloud wall** (12216–12228): along the four edges of `LAYOUT.rect` pushed out by `m = 400`, a point every `step = 1300` 丈 with outward normal; for each point 3 rows `r = 0..2`:
`w = 3200 + 3600 rnd`, depth outward `d = r·1300 + rnd·700`, jitter ±350, `y = 150 + r·380 + rnd·380`, `h = w·(0.34+0.1rnd)`, op `(0.75+0.25rnd)·clouds.wall`, kind 6, sway 140 (12225–12226). Hides the world's end.

**Near pool** (12230–12232): 6 cards parked at y = −9999, CPU pool of `{life, x,y,z, w, vx, vz, op, seed}`.

### 1.6 Per-frame (`updateClouds`, 12236–12277)
```
hi   = smoothstep(zoom.mid, zoom.mapAt, A)      // 1650 → 11000
lowK = 1 - smoothstep(zoom.low, zoom.mid, A)    // 1 below 950, 0 above 1650
mist.uGlobal  = cloudIn·(1-map)·(1-0.15·hi)·(1-0.4·lowK)      // low down valley mist thins to 60%
mist.uFadeNear/Far = 0.32A / 0.78A
mist.uPart = (0.42·Ap, 0.95·Ap), Ap = min(A, 2400); uTarget = CAMERA_RIG.target.xz
wall.uGlobal  = cloudIn·(1 - 0.85·map);  wall.uFade = 0.3A / 0.9A        // wall persists faintly in map mode
near.uGlobal  = cloudIn·(1-map)·clouds.nearOpacity·(1-hi);  near.uFade = 0.1A / 0.42A
```
All fade distances scale with A, so the "camera passes through clouds" look is altitude-invariant.

Near fly-through spawner (12250–12276):
- Timer `nearT -= dt·(0.4 + 1.2·smoothstep(0, flight.speed·A, horizSpeed))` — spawns faster when moving.
- When `nearT ≤ 0 && map < 0.01 && cloudIn > 0.99`: reset to `nearEvery·(0.6+0.8rand)` (≈6–14 s) and take a free pool slot.
- Placement: along the velocity dir (or −z if speed ≤ 5): `ahead = A·(0.9+0.5r)`, `side = (r-0.5)·0.9A`; `y = A·(0.4+0.22r)` (below the camera); `w = A·(0.45+0.35r)`, `h = 0.42w`; velocity = `uWind·8`; `op = 0.7+0.3r`.
- Lifetime: fade-in `smoothstep(0, 1.6, age)`; starts dying (`life -= 0.8·dt`) when `(c.z - cam.z) > 0.2A` (passed behind, assumes camera looks toward −z) or `age > 26`.
- Written to iPos/iSize/iData each frame; free slots get opacity 0.

---

## 2. 07c · Cloud sea (12279–12497) — detailed

### 2.1 Concept (comment 12280–12286)
A continuous horizontal **slab** of cloud whose **top surface is a mesh**; the fragment shader **raymarches down** from each surface pixel through the slab (~9 steps) using: a 2D planned density texture, a vertical profile, a baked tileable 3D noise, Beer–Lambert extinction, and one tap toward the sun for lighting. The march stops on terrain (a heightmap), so peaks and floating islands pierce the sea with a soft skirt instead of a hard cut line.

### 2.2 Inputs
- `WORLD.cloudSea = {w, h, c, data}` (planned in section 03, outside scope): Uint8 density grid over `WORLD.rect`, cell size `c` (the comment "7×7 box ≈ 560 丈" at 12427 implies c ≈ 80 丈). Plan: full over mountain country, thinner over plains, thickest around sects, open over cities and landmarks (12280–12281).
- `LAND.tLand` — ground-height texture (`.r` = ground height in 丈; used as `air = p.y - (g - 1.0)`, 12371–12372).
- `LU.tSun` — baked sun texture; `.g` channel used as peak-shadow over the sea (12346; per 4295: r ground shadows, g cloud-sea height, b sky openness).
- `WORLD.sites[]` → `uSites[i] = (x, z, R·1.6, S.cloud)` (sect cloud top height) and per-sect tint `uSiteTint` from `SEA_TINT` (12398, 12474–12476). `NSITES = 6` (450).

### 2.3 Density texture bake (12427–12440)
Box blur of the plan: radius 3 (7×7) everywhere, radius 1 (3×3) near sects (`near > 0.5` where `near = smoothstep(2.6R, 2.0R, dist)`) so sect sea edges follow ridges. → `DataTexture` R8, linear filtering.

### 2.4 3D noise bake (`cloudNoiseTexture`, 12400–12423)
48³ R8, `mulberry32(4711)`. Three octaves of periodic value noise on lattices P = 4, 8, 16 with weights 0.55, 0.30, 0.15; quintic fade `t³(t(6t−15)+10)`; lattice wraps (`% P`) → tileable; normalised min–max to 0–255; `RepeatWrapping` on all three axes, linear filtering.

### 2.5 Mesh (12441–12465)
- Regular grid, **100 丈 cells**, over `WORLD.rect`; a quad is emitted only if any of its 4 corners has blurred density > 2 (of 255) (12444–12452). Shared vertices via `vid` map. Index Uint32 if > 65535 verts.
- Per-vertex `aLift` (12456–12463): base = `cloudSea.height` (175). In high valleys the sea follows the local low relief: `lv = clamp(reliefLin(x,z,RELIEF.low) + cloudSea.valley(75), base, base+330)`; then under sects `seaTopAt(x,z,lv)` (2259–2262: `max(lv, lerp(lv, sectTop, w))`) lifts it to the sect's cloud top. `aLift = seaTop - base`.
- `renderOrder 8`, `transparent, depthWrite false`, `veil`, frustumCulled false (12478–12481).

### 2.6 Vertex shader `CS_VS` (12287–12312)
```glsl
// CS_COMMON
float swellH(vec2 p, float t){ vec2 q = p + uWind * t * 6.0;
  return fbm3(q / 1300.0) - 0.5 + (vnoise(q / 520.0 + 4.3) - 0.5) * 0.45; }

float d = textureLod(tDens, (wp.xz - uRect.xy) / uRect.zw, 0.0).r;
float sectK = smoothstep(10.0, 60.0, aLift);            // inside a sect's raised sea
wp.y = uTop + aLift
     + (d - 0.6) * mix(40.0, 14.0, sectK) * uAmp                                   // denser = higher
     + swellH(wp.xz, t) * mix(90.0, 26.0, sectK) * uAmp * smoothstep(0.0, 0.45, d) // broad swell, ±~45–90 丈
     - (1.0 - smoothstep(0.0, 0.28, d)) * mix(120.0, 40.0, sectK);                 // edges sink (feather down)
vTop = wp.y;
vec2 sunH = normalize(uSun.xz + vec2(1e-4));
vSwell = clamp(1.0 + (swellH(wp.xz, t) - swellH(wp.xz + sunH * 140.0, t)) * 1.8, 0.5, 1.34); // sun-facing slope lit
wp.y *= 1.0 - uMap;
```
`uTop = cloudSea.height`, `uAmp = billow`. Sect seas swell less so billows "lap at terrace walls" (12301–12303).

### 2.7 Fragment shader `CS_FS` (12313–12396)

**Density function** (12323–12334):
```glsl
float dens(vec3 p, float top, vec3 drift){
  vec2 uv = (p.xz - uRect.xy) / uRect.zw;
  float d = texture2D(tDens, uv).r; if (d < 0.01) return 0.0;
  vec3 q = p + drift;
  float n = texture(tNoise, q / 760.0).r * 0.6 + texture(tNoise, q / 230.0 + 0.37).r * 0.4;  // 2 scales of 3D noise
  float hgt = (p.y - (top - uThick)) / uThick;                // 0 slab bottom … 1 top
  float line = 0.45 + 0.55 * d - (n - 0.5) * 1.3;             // effective top: lower where plan thins, noise-cut
  float v = smoothstep(line, line - 0.28, hgt) * smoothstep(-0.05, 0.2, hgt);
  v *= smoothstep(0.03, 0.35, d + (n - 0.5) * 0.4);
  return v;
}
```
Drift: `vec3(uWind.x, 0, uWind.y) * t * 6.0` (12338). Slab thickness `uThick = 150`.

**Ray setup** (12336–12344):
```glsl
vec3 ro = vWp, rd = normalize(vWp - uCamPos);
float L  = min(uThick / max(-rd.y, 0.12), uThick * 4.0);  // through the slab; grazing capped at 4× thick
float ds = L / float(uSteps);
float jit = fract(52.9829189 * fract(dot(gl_FragCoord.xy + vec2(fract(t*0.37)*13.0, 0.0),
                                         vec2(0.06711056, 0.00583715))));   // interleaved-gradient noise
float sigma = uDensK * 0.045 * uAlpha;                     // extinction per 丈 at full density
```

**Large-scale lighting from the plan** (12345–12351):
```glsl
float shadow = mix(0.74, 1.0, smoothstep(0.3, 0.7, texture2D(tSunC, suv).g));   // baked peak shadows on the sea
float dSun = texture2D(tDens, suv + sunH * 520.0 / uRect.zw).r;                  // plan density 520 丈 sunward
shadow *= (1.0 - 0.4 * smoothstep(0.0, 0.3, dSun - vD))     // thicker cloud sunward → in its shade
        * (1.0 + 0.16 * smoothstep(0.0, 0.3, vD - dSun))    // we are the thick one → lit
        * vSwell;
```

**Gates — parting, sect veil, near-camera thinning** (12356–12360):
```glsl
float keep = 0.0, veil = 1.0;
for (i < NSITES) { float ki = 1.0 - smoothstep(uSites[i].z * 0.7, uSites[i].z, length(vWp.xz - uSites[i].xy));
  keep = max(keep, ki);
  veil = min(veil, mix(1.0, mix(0.45, 1.0, smoothstep(uSites[i].w + 120.0, uSites[i].w + 380.0, uCamPos.y)), ki)); }
float part = smoothstep(uPart.x, uPart.y, length(vWp.xz - uTarget) + (vnoise(vWp.xz / 420.0) - 0.5) * 240.0);
float gate = mix(1.0, mix(part, mix(veil, 1.0, part), keep), step(1.0, uPart.y))
           * smoothstep(uCamPos.y * 0.22, uCamPos.y * 0.6, camD);
```
- Outside sects: the sea **opens** (hole) round the player's target, radius `uPart`.
- Inside a sect (`keep`): instead of opening it only thins to a veil (density ×0.45) and only when the camera comes within 120–380 丈 above the sect's cloud top.
- Fragments closer than `0.22·camY`–`0.6·camY` to the camera fade (no wall of cloud in your face).

**Region tint** (12362–12363): `regionTint` = mix toward `uSiteTint[i]` within `0.6·R'`–`1.6·R'`. `SEA_TINT` (12398): ice (0.97,0.99,1.02), jade (0.97,1.01,1.0), gold (1.05,1.0,0.92), water (0.93,1.0,1.02), earth (1.04,1.0,0.95), phoenix (1.04,0.98,0.98).

**March loop** (12364–12389), max 24 iterations, breaks at `uSteps`:
```glsl
float T = 1.0; vec3 acc = vec3(0.0);
float pDn = 0.0, pAir = 0.0; vec3 pC = vec3(0.0);
for (int i = 0; i < 24; i++) {
  if (i >= uSteps) break;
  vec3 p = ro + rd * (ds * (float(i) + jit));
  float g = texture2D(tLand, (p.xz - uRect.xy) / uRect.zw).r;
  float air = p.y - (g - 1.0);
  if (air < 0.0) {     // hit rock: the previous step counts only for its fraction in air → continuous skirt
    if (pDn > 0.0) { float a = 1.0 - exp(-pDn * sigma * ds * clamp(pAir / max(pAir - air, 1e-3), 0.0, 1.0));
                     acc += T * a * pC; T *= 1.0 - a; }
    pDn = 0.0; break;
  }
  if (pDn > 0.0) { float a = 1.0 - exp(-pDn * sigma * ds); acc += T * a * pC; T *= 1.0 - a; pDn = 0.0;
                   if (T < 0.015) break; }
  float dn = dens(p, vTop, drift) * gate;
  if (dn < 0.002) continue;
  float occ = dens(p + uSun * 95.0, vTop, drift);                 // ONE sun tap, 95 丈
  float light = exp(-occ * 1.6) * shadow;
  float lee = dens(p + vec3(sunH.x, 0.3, sunH.y) * 70.0, vTop, drift);
  light *= 1.0 + 0.55 * clamp((dn - lee) * 2.2, -0.6, 1.0);       // sun-facing billow slopes brighter
  float depthK = clamp((p.y - (vTop - uThick)) / uThick, 0.0, 1.0);
  pC = mix(uDeep, mix(uShade, uLit, light), 0.2 + 0.8 * depthK * depthK) * regionTint;
  pDn = dn; pAir = air;
}
if (pDn > 0.0) { float a = 1.0 - exp(-pDn * sigma * ds); acc += T * a * pC; T *= 1.0 - a; }
float a = (1.0 - T) * uCloudIn * (1.0 - uMap);
if (a < 0.004) discard;
vec3 col = acc / max(1.0 - T, 1e-3);                               // un-premultiply
float hz = smoothstep(uCamPos.y * 1.2, uCamPos.y * 3.6, camD) * uHaze;
col = mix(col, uHazeCol, hz * 0.45);                               // aerial perspective
gl_FragColor = vec4(col, a);
```
Key point: **samples are integrated one step late** so that when the next sample is in rock, the last step's contribution is scaled by the fraction of the step that was in air (`pAir/(pAir-air)`), producing a continuous fade against cliffs.

Colours (12471): `uLit #fdf9f0`, `uShade #cfd8de`, `uDeep #9aaab5`. Deep colour dominates lower in the slab (`0.2 + 0.8·depthK²`).

### 2.8 How peaks pierce it
1. The mesh exists only where plan density > 2; landmark/city holes are in the plan.
2. Terrain occlusion in the march (`tLand`), giving soft skirts.
3. The scene depth buffer (sea is drawn after opaques with depthTest on — default for ShaderMaterial) occludes the sea surface behind peaks that stand in front.
4. Sect seas are lifted (`aLift`) so islands/terraces stand half in them.

### 2.9 Per-frame (`updateCloudSea`, 12485–12497)
```
uTop=height, uAmp=billow, uSpeed=speed, uThick=thick, uDensK=density
uSteps = clamp(round(steps · (LITE ? 0.6 : 1)), 3, 24)          // 9 by default, ~5 in LITE
uAlpha = clamp(amount, 0, 1.5)
k  = 1 - smoothstep(1.4·mid, 2.6·mid, A)     // 2310 → 4290
Ap = min(A, 1.4·mid)
uPart = (0.3·Ap·k, 0.95·Ap·k)                // opening vanishes when high; gate disabled when uPart.y < 1
uTarget = CAMERA_RIG.target.xz
visible = amount > 0.01;  cloud-fall uAlpha and visibility follow (12496)
```
Fade with altitude is therefore: **opening around the player shrinks to nothing above ~4300 丈**; the near-camera thinning scales with camY; haze toward `uHazeCol` grows with distance relative to camY. There is no explicit global altitude fade — the sea is always present (except map mode / intro).

---

## 3. 07d · God rays + cirrus (12499–12630)

### 3.1 Shafts (Tyndall beams)
**Planning** (`planShafts`, 12529–12549, `mulberry32(5151)`): candidate rejected unless ≥ 2400 from other shafts, outside `1.3·R` of every sect, and inland (`seaDist < -400`). Each: `y0 = max(hAt+30, 70)`, `len = 2300 + 1400r`, `w = (340+380r)·k`.
- Over every city POI (offset ±250 x, −300…−600 z).
- Over landmarks `lingyan, feilian, sunshi, guxiu` (k 0.8).
- Through gaps in the cloud sea: up to 4000 random cells, accepted if cell density ≤ 40 but max within ±6 cells ≥ 150 (thin here, thick nearby), k 0.9; total ≤ 16.

**Geometry** (12550–12579): per shaft **two crossed vertical strips** (one across the sun azimuth `(-SUN.z, SUN.x)`, one along it), 6 segments; at param t: `y = y0 + len·t`, half-width `w(0.55+0.45t)/2` (widens upward), centre leans toward the sun: `cx = x + (SUN.x/SUN.y)·len·t`. Attribs `aUv (0|1, t)`, `aN` (strip normal), `aSeed`.

**Shader** (12507–12528): additive, double-sided, depthWrite off, order 9.
```glsl
float x = abs(vUv.x * 2.0 - 1.0);
float n = fbm3(vec2(vUv.x * 2.6 + vSeed * 9.0, vUv.y * 1.4 - uTime * 0.012 + vSeed));
float edge = 1.0 - smoothstep(0.15, 1.0, x + (n - 0.5) * 0.6);
float streaks = 0.55 + 0.45 * vnoise(vec2(vUv.x * 11.0 + vSeed * 31.0, vUv.y * 0.6 - uTime * 0.02));
float along = smoothstep(0.0, 0.12, vUv.y) * (1.0 - smoothstep(0.45, 1.0, vUv.y));
float facing = 0.3 + 0.7 * abs(dot(normalize(uCamPos - vWp), normalize(vN)));   // fade edge-on
float near = smoothstep(uNear * 0.5, uNear, length(uCamPos - vWp));            // fade when flying into one
float a = edge * streaks * along * facing * near * uGain;
gl_FragColor = vec4(uCol * a, a);       // uCol = (1.0, 0.93, 0.78)
```
**Update** (12616–12623): `on = cloudIn·(1-map)`; `uNear = max(400, 0.35A)`;
`uGain = cinema.shafts · 0.14 · smoothstep(low, 1.1·mid, A) · (0.55 + 0.45·smoothstep(mid, high, A)) · on` → absent below 950, ramps in by 1815, peaks in the global view (8000+).

### 3.2 Cirrus (high thin cloud)
Single `PlaneGeometry` covering rect + 6000 margin at `CIRRUS_Y = 4300` (12581, 12602–12614), veil-blended, double-sided, order 13.
```glsl
vec2 xz = vWp.xz + uWind * uTime * 14.0;
vec2 w = normalize(uWind + vec2(1e-4)), p = vec2(dot(xz, w), dot(xz, vec2(-w.y, w.x)));  // wind-aligned frame
vec2 q = p * vec2(1.0 / 16000.0, 1.0 / 5200.0);                        // stretched 3:1 along wind
float cov = fbm5(q + 3.1) * 0.7 + fbm3(q * 3.1 + 7.7) * 0.3;
float a = smoothstep(0.47, 0.66, cov);
float wisp = vnoise(p * vec2(1.0/3200.0, 1.0/420.0) + 1.3) * 0.6 + vnoise(p * vec2(1.0/1400.0, 1.0/260.0) + 7.1) * 0.4;
a *= smoothstep(0.3, 0.8, wisp);                                      // combed streaks
a *= smoothstep(400.0, 1400.0, abs(uCamPos.y - vWp.y));               // no lid when passing through
vec2 ed = min(xz - uRect.xy, uRect.xy + uRect.zw - xz) / (uRect.zw * uEdge * 2.0);
a *= smoothstep(0.0, 1.0, min(ed.x, ed.y) + 0.3);                     // world-edge fade
a *= uGain * 0.55;
vec3 c = mix(vec3(0.95, 0.96, 0.96), vec3(1.0, 0.99, 0.96), smoothstep(0.4, 0.8, wisp));
```
Update (12624–12629): `uGain = cinema.cirrus · smoothstep(0.75·4300, 1.45·4300, camY) · on` → only visible when the camera is above ~3225–6235 (i.e. looking down through it).

---

## 4. 07e · Cloud falls (12632–12694)

Cloud spilling through a pass and down a lee slope, evaporating. Source: per landform `LF(S).cloudFalls(S)` → `[{pts: centreline [x,z,(seaY?)] from lip down, w0, w1, lift0, lift1, t0}]` (12634–12636, 12665).

**Geometry** (12667–12684): for each fall, **3 stacked sheets** `LY = [[wk, lk, la]] = [[1, 1, 0], [0.84, 1.9, 5], [0.62, 2.9, 11]]` (narrower, higher, fainter). Along the polyline (n points) × 13 across (`M = 13`):
- `d = max(0, t-t0)/max(1-t0, 0.05)` (0 at lip, 1 at end).
- width: `lerp(0.9w0, lerp(w0, w1, d^0.8), t0 ? min(1, t/t0) : 1) · wk`.
- lift above ground: `lerp(lift0, lift1, d)·lk + la`; plus centre bow `(1-4s²)·w·0.05`.
- `y = max(hAt(x,z) + lift, seaY + la) + bow` (on the sea top before the lip, draped on the slope after).
- attribs `aUv (across, t)`, `aLayer`, `aT0`.

**Shader** `CLOUDFALL_FS` (12641–12660):
```glsl
float x = abs(vUv.x * 2.0 - 1.0), t = vUv.y, f = uTime * 0.06 * uSpeedK;
float d = max(t - vT0, 0.0) / max(1.0 - vT0, 0.05);
float n  = fbm3(vec2(vUv.x * 3.6 + vLayer * 5.0, t * 2.6 - f * 5.0));          // billows scroll downhill
float st = vnoise(vec2(vUv.x * 13.0 + vLayer * 3.1, t * 1.3 - f * 2.4));        // streaks
float n2 = vnoise(vec2(vUv.x * 10.0 + 3.0 + vLayer * 7.0, t * 6.5 - f * 9.0));
float body = 1.0 - smoothstep(0.42, 1.0, x + (n - 0.5) * 0.55 + (st - 0.5) * 0.3 - (1.0 - d) * 0.08);
float fade = 1.0 - smoothstep(0.38, 0.96, d + (st - 0.5) * 0.5 + (n - 0.5) * 0.25);   // frays into fingers
float a = body * fade * smoothstep(0.0, 0.5, t / max(vT0, 0.05)) * (0.66 + 0.34 * mix(n2, st, 0.5))
        * (1.0 - 0.22 * vLayer) * uAlpha;
vec3 c = mix(uShadeC, uLitC, smoothstep(0.12, 0.7, n * 0.55 + st * 0.25 + (1.0 - d) * 0.3 + vLayer * 0.08));
c = hazeMix(c, vWp);
gl_FragColor = vec4(c, a * uWash);
```
`uLitC #fbf8f1`, `uShadeC #c9d3d8` (12686). Double-sided, veil, order 7, registered in `LAND.mats` (so land uniforms update it). Alpha follows cloud-sea `amount` (12496).

---

## 5. 08 · 遁光 escape light (12696–12833)

`buildLight(scene)` returns `{pos, reset(), update(dt, p, vel, cam, A, boost, visible, shadowK)}`.
- `visible` = how much the light is shown: with a figure enabled, `PLAYER.dunK + PLAYER.flare·0.7` (14227); without figure, 1. `shadowK` = figure ground-shadow weight.
- All light parts: `transparent, depthTest: false, depthWrite: false`, **normal blending** (comment 12728: additive would vanish on pale paper).

### 5.1 Scale
`K = light.size · (A/1650)^0.92` (12775) — near screen-constant size across altitude.
Speeds: `cruise = flight.speed·A`; `sp01 = clamp(speed / (cruise·boostMul), 0, 1)`.
`idleK → (speed < 0.08·cruise ? 1 : 0)` with rate 3/s; `boostK → (boost && speed > 0.5·cruise)` rate 4/s; heading `dir` slerps to velocity at rate 8/s (12778–12780). (`x = lerp(x, target, 1 - exp(-dt·rate))` throughout.)

### 5.2 Glow quads — halo, inner, head (12731–12735, 12785–12787)
Camera-facing quads (view-space offset `mv.xy += position.xy * uSize`). FS:
```glsl
vec2 p = vUv * 2.0 - 1.0; float r2 = dot(p, p);
float a = exp(-r2 * uFall) * (1.0 - smoothstep(0.8, 1.0, sqrt(r2)));
```
| quad | colour | uFall | size | alpha |
|---|---|---|---|---|
| halo (41) | glow `#3fd9b0` | 3.2 | `90K·breath·(1+0.2 boostK)` | `0.5·I·(0.92+0.08 breath)` |
| inner (42) | mix(glow, core, 0.45) | 5.0 | `34K·breath` | `0.85·I` |
| head (44) | core `#e8fff6` | 6.0 | `15K·(1+0.4(breath-1))` | `1.0·I` |

`breath = 1 + light.breath(0.08)·idleK·sin(2.3t)` — breathing when stopped. `I = intensity(0.85)·visible`.

### 5.3 Beam (12736–12742, 12788–12791)
4-vertex strip rebuilt on the CPU (`strip()`, 12762–12768): axis = `dir`, side = `normalize(dir × (cam - p))·wid`, extends `len·(1-front)` behind and `len·front` ahead (`front = 0.18`).
`len = (26 + 130 sp01 + 90 boostK)·K·tail·(1 - 0.35 idleK)`, `wid = (9 + 4 sp01)·K`, `alpha = I·(1 - 0.4 idleK)`.
```glsl
float x = vUv.x * 2.0 - 1.0, y = vUv.y;              // y: 0 tail → 1 head
float taper = mix(0.12, 1.0, pow(y, 0.6));
float body = exp(-x*x*7.0/(taper*taper))  * smoothstep(0.0, 0.4, y) * (1.0 - smoothstep(0.9, 1.0, y));
float core = exp(-x*x*55.0/(taper*taper)) * smoothstep(0.3, 0.9, y) * (1.0 - smoothstep(0.96, 1.0, y));
float flick = 0.9 + 0.1 * sin(y * 26.0 - uTime * 20.0);
vec3 col = mix(uGlow, uCore, clamp(core * 1.4, 0.0, 1.0));
gl_FragColor = vec4(col, clamp(body * flick * 0.62 + core, 0.0, 1.0) * uAlpha);
```

### 5.4 Tapered trail (12743–12749, 12792–12805)
Ribbon of `TN = 96` cross-sections (192 verts), attributes `aT = k/95`, `aSide = ±1`.
- History: `hist.unshift({p, t})` every frame; pop while `> 96` entries or oldest older than `keep = (0.55 + 0.75 sp01 + 0.4 boostK)·tail` s.
- Section k: tangent `h[k-1] - h[k+1]` (fallback dir), side = `normalize(tangent × (cam - h))`, half-width `(10 + 6 sp01)·K·(1 - k/96)^0.9`. Unused tail entries clamp to the oldest point.
- `alpha = I · smoothstep(0.02, 0.25, sp01 + 0.05)` (no trail when still).
```glsl
float s = 1.0 - min(abs(vSide), 1.0);
float fade = pow(1.0 - vT, 1.7);
float flow = 0.75 + 0.25 * vnoise(vec2(vT * 22.0 - uTime * 7.0, vSide * 1.5));
float inner = pow(s, 7.0) * (1.0 - smoothstep(0.0, 0.5, vT));
vec3 c = mix(mix(uCore, uGlow, smoothstep(0.0, 0.3, vT)), uCore, inner);
gl_FragColor = vec4(c, clamp(pow(s, 1.4) * flow * 0.55 + inner * 0.6, 0.0, 1.0) * fade * uAlpha);
```

### 5.5 Ink speed lines on boost (12750–12757, 12806–12824)
28 quads (`NL = 28`), ink colour, normal blending, depthTest off, order 39.
- Strength `lk = speedLines(0.6)·boostK·min(1, visible)`.
- Spawn: free stroke with `lk > 0.05` and `rand < 9·dt` → `life 1, u ∈ [-1,1] (side), v ∈ [1, 1.6] (ahead), h ∈ ±0.3 (vertical), len 0.5–1.3, sp 2.2–3.7`.
- Update: `life -= 1.6dt; v -= sp·dt` (streams backward past the light). `R = 150K`: start `c = pos + dir·v·R + side·u·0.9R; c.y += h·0.6R`; length `len·0.9R`, half-width `1.1K`.
- Alpha `sin(life·π)·0.32·lk·smoothstep(0.15, 0.6, |u|+0.2)` (thin near the centre line).
- FS: `(1 - smoothstep(0.2, 1, |x|)) * smoothstep(0, 0.25, v) * smoothstep(1, 0.55, v)`.

### 5.6 Ground ink shadow & glow (12825–12830)
Fed to the ground shader (`GROUND.shadowP`, `GROUND.glowP`, defined outside scope):
```
hgt = max(1, p.y);  sy = max(SUN.y, 0.3)
shadowP = (p.x - SUN.x/sy·hgt·0.45, p.z - SUN.z/sy·hgt·0.45,          // shortened throw away from the sun
           radius (26 + 0.08·hgt)·K·1.4,
           strength light.shadow(0.32)·shadowK·0.55·(1 - 0.5·smoothstep(200, 1400, hgt)))
glowP   = (p.x, p.z + 0.1·hgt, radius (60 + 0.22·hgt)·K, strength 0.07·I);  glowCol = glow
```

### 5.7 Player dun state (outside scope, 14213–14216)
On Shift press `flare = 1`, decays `flare -= dt/0.4`; `dunK → boosting ? 1 : 0` with time constant `dunIn 0.22` s / `dunOut 0.55` s.

---

## 6. 08b · The cultivator figure (12835–13014)

### 6.1 Overview
Procedural hierarchy of ~30 low-poly primitives, **no animation clips**: each state names joint targets, joints ease exponentially (`ease(cur, to, dt, tau) = lerp(cur, to, 1 - exp(-dt/tau))`, 12932). Flat "white model" toon shading + inverted-hull ink outline. Screen-constant size. Only built when `CONFIG.figure.on` (default false at 323).

### 6.2 Materials (12847–12880)
- `FIG_VS`: `p = position + normal * uOutline` (inverted hull when `uOutline > 0`).
- `FIG_FS`: line shell → `mix(uLineCol, uTint, uTintK*0.7)`; body → `softTones(dot(N, uSunDir))` → `toneCol(uCol, t) + 0.02·max(N.y,0)`; rim `pow(1 - |N·V|, 3)` adds `uTint` by `uTintK·(0.45 + 0.55 rim)`; `hazeMix`.
- Outline material: `BackSide`, `uOutline 0.012` (figure units; ×H in world), renderOrder 37. Fill: `FrontSide`, renderOrder 38. Both `transparent: true, depthWrite: true` (so parts occlude each other when faded, 12877).
- `softTones(nl) = mix(0, mix(0.5, 1, smoothstep(0.4, 0.66, nl)), smoothstep(0, 0.26, nl))` (4294).
- Palette `COL` (12872): robe (0.93,0.92,0.88), robeD (0.84,0.83,0.78), skin (0.92,0.84,0.76), hair (0.16,0.17,0.2), sash (0.3,0.56,0.5), shoe (0.3,0.3,0.32); hairpin (0.5,0.42,0.3).

### 6.3 Hierarchy and proportions (figure height = 1, +z forward, origin at the feet) (12882–12918)
`root` (world pos/scale/facing) → `lean` (pitch = lean, roll = bank; **pivot at the feet**) → parts:

| node | parent | local pos | geometry (radiusTop, radiusBottom, height, segs) | abs. y |
|---|---|---|---|---|
| torso | lean | (0, 0.60, 0) | Cylinder(0.10, 0.085, 0.30, 7) | 0.60 (0.45–0.75) |
| chest | torso | (0, 0.12, 0.004) | Cylinder(0.105, 0.10, 0.10, 7) robeD | 0.72 |
| collar | torso | (0, 0.165, 0.006) | Cylinder(0.052, 0.07, 0.05, 6) robeD | 0.765 |
| neck | torso | (0, 0.19, 0.01) | Cylinder(0.026, 0.03, 0.07, 6) skin | 0.79 |
| head | torso | (0, 0.27, 0.012) | Icosahedron(0.068, 1) skin | 0.87 |
| hair shell | head | (0, 0.018, −0.016) | Icosa(0.072, 1) | |
| topknot | head | (0, 0.082, −0.01) | Icosa(0.034, 1) | ~0.95 |
| hairpin | head | (0, 0.082, −0.01) | Box(0.11, 0.006, 0.006) | |
| belt | lean | (0, 0.46, 0) | Cylinder(0.10, 0.10, 0.03, 8) sash | 0.46 |
| robe | lean | (0, 0.225, 0) | open Cylinder(0.10, 0.25, 0.47, 10, 4 height segs) | −0.01–0.46 |
| robeDark (overlap) | lean | (0, 0.43, 0) | open Cylinder(0.102, 0.108, 0.06, 10) | 0.43 |
| shoulder L/R (pivot) | torso | (∓0.105, 0.14, 0) | — | 0.74 |
| upper arm | shoulder | (0, −0.10, 0) | Cylinder(0.03, 0.026, 0.20, 6) | |
| sleeve | shoulder | (0, −0.17, 0) | open Cylinder(0.034, 0.10, 0.26, 7) — bell sleeve | |
| elbow (pivot) | shoulder | (0, −0.20, 0) | — | 0.54 |
| forearm | elbow | (0, −0.085, 0) | Cylinder(0.024, 0.02, 0.17, 6) robeD | |
| hand | elbow | (0, −0.185, 0) | Icosa(0.026, 0) skin | 0.355 |
| feet L/R | lean | (∓0.04, −0.01, 0.02) | Box(0.05, 0.03, 0.10) shoe | −0.01 |

Arms: index 0 = left (sd −1), index 1 = right (sd +1) (12908).

### 6.4 Joints and defaults (12930)
`J = { lean 0.05, bank 0, shX [0.2,0.2], shZ [-0.12,0.12], elX [-0.4,-0.4], elZ [1.3,-1.3], flutter 0.03, trail 0.05, fade 1, tint 0, scale 1 }` (radians).
- `shX` +: arm swings back; `shZ`: out to the side (signed per arm); `elX` bends forearm; `elZ` folds inward.
- Applied (12966–12967): `lean.rotation = (J.lean, 0, J.bank)`; `shoulder.rotation = (shX[i], 0, shZ[i])`; `elbow.rotation = (elX[i], 0, elZ[i])`; `sleeve.rotation.z = sd·0.1·(1 - sp01)`. Three.js Euler order XYZ.

### 6.5 Inputs per frame (12938–12945)
- `H = figure.size·100·(A/1650)^0.92` — figure height in 丈 (150 at A = 1650).
- `spC = clamp(speed / cruise, 0, 1.2)`, `sp01 = clamp(speed/(cruise·boostMul), 0, 1)`.
- heading `dir` → velocity at rate 6/s when `speed > 0.03·cruise`.
- `turn = clamp((dir.z·acc.x − dir.x·acc.z) / (2.2·cruise), −1, 1)` (lateral acceleration from finite-difference velocity).
- `climb = clamp(st.climb·6, −1, 1)` where `st.climb = log(PLAYER.At / A)` (14228; target altitude vs current).
- `st = {dunK, flare, boosting, climb, vis}`.

### 6.6 State machine (12947–12956)
```
next = (dunK > 0.35 || (boosting && flare > 0.5)) ? 'dun'
     : spC > 0.12 ? 'cruise' : 'hover'
on change: t0 = now;  since = now - t0
```
| target | hover (袖手, hands folded) | cruise (御空) | dun (遁光; gather = 1 − smoothstep(0.08, 0.3, since)) |
|---|---|---|---|
| lean | `0.04 + 0.02 sin(1.1t)` | `lean(30°)·(0.6+0.4spC) − 0.25·climb` | `lerp(66°, −0.15, gather) − 0.2·climb` |
| shX | [0.2, 0.2] | `0.95 + 0.3spC` both | `lerp(1.55, 0.3, gather)` both |
| shZ | [−0.12, 0.12] | [−0.25, 0.25] | `[lerp(−0.1, −0.9, g), lerp(0.1, 0.9, g)]` |
| elX | [−0.4, −0.4] | [−0.3, −0.3] | `lerp(0.05, −0.6, g)` both |
| elZ | [1.3, −1.3] | [0.2, −0.2] | [0, 0] |
| flutter | 0.025 | `0.05 + 0.08spC` | 0.16 |
| trail | 0.02 | `0.12 + 0.3spC` | 0.55 |
| fade | 1 | 1 | `lerp(1, figure.fade 0.22, dunK)` |
| tint | 0 | 0 | `0.75·dunK` |
| scale | 1 | 1 | `1 + 0.06·gather` |
All states: `bank = −turn·bank(22°)·(0.4 + 0.6spC)`.

Dun sequence: first 0.08 s "gathering" (leans back −0.15 rad, arms out wide ±0.9, slightly scaled up), blending by 0.3 s into the stretched dive (66° forward, arms swept back 1.55 rad, straight).

**Easing time constants** (12958–12961): `tauJ = dun ? 0.12 : 0.28` for lean and all arm joints; bank 0.35; flutter/trail 0.3; fade/tint 0.2; scale 0.12.

### 6.7 Secondary motion (12963–12980)
- `root.position = p − 0.02H·ŷ`; `root.scale = H·J.scale`; `root.lookAt(p + dir·1000)` (level facing).
- Breathing: `torso.scale = (b, 1, b)`, `b = 1 + 0.012 sin(1.6t)·(hover ? 1 : 0.3)`.
- Head: `rot.x = −0.6·J.lean + (hover ? 0.06 sin(0.7t) : 0.1)`, `rot.y = hover ? 0.12 sin(0.5t) : 0`.
- Feet: `rot.x = 0.35 sp01 + 0.2 dunK`, `pos.z = 0.02 − 0.03 dunK`.
- **Robe** (CPU vertex deformation of the open cone, 12973–12980), per base vertex (x0,y0,z0):
```js
w   = clamp((0.235 - y0) / 0.47, 0, 1)          // 0 top ring → 1 hem
ph  = atan2(z0, x0)
rip = sin(ph*3 + t*(9 + 8spC) + y0*6) * flutter * w*w + sin(ph*5 - t*(13 + 10spC)) * flutter * 0.4 * w
x = x0*(1 + 0.8rip) + sin(3.1t + ph) * flutter * 0.3 * w
y = y0 + 0.5 * rip * w
z = z0*(1 + 0.8rip) - trail * w*w                 // hem trails behind (−z)
```
then `computeVertexNormals()`.

### 6.8 Ribbons — verlet chains (12919–12927, 12981–13006)
Three chains, world-space, billboarded strips:
| ribbon | points n | half-width (×H) | anchor (lean-local) | segment length |
|---|---|---|---|---|
| sash end L | 12 | 0.035 | (−0.04, 0.45, −0.10) | `0.075H` |
| sash end R | 12 | 0.035 | (0.04, 0.45, −0.10) | `0.075H` |
| hair tail | 8 | 0.028 | (0, 0.88, −0.07) | `0.075H·0.7` |

Per frame:
```js
segL = 0.075H; upwash = (1 - spC)*1.6H; kd = 0.9; g = -0.6H
A0 = anchor transformed by lean.matrixWorld
if (!init || H changed by >1.5x) reset chain: p[k] = A0 - dir*k*sl; p[k].y -= 0.3*k*sl; q = p
p[0] = A0
for k in 1..n-1:                                 // verlet integrate
  w = ( -vel.x*0.55 + sin(7t + 0.9k + anchorX*40)*0.9H,
         g + upwash + sin(5t + 1.3k)*0.5H,
        -vel.z*0.55 + cos(6t + 1.1k)*0.9H )      // "acceleration": relative wind + gravity + updraft + flutter
  vel_k = (p - q)*kd;  q = p;  p += vel_k + w*dt*dt
repeat 2 times: for k in 1..n-1: p[k] = p[k-1] + normalize(p[k]-p[k-1]) * sl     // one-sided distance constraint (FTL)
mesh: for each k, tangent = p[k+1]-p[k-1]; side = normalize(tangent × (cam - p)); halfW = w*H*(1 - 0.6k/n)
      verts p ± side*halfW; normals = toCamera
```
- Note the horizontal force uses the **player velocity** (丈/s) directly as an acceleration (stylised "wind of the way"); vertical: gravity −0.6H, updraft up to +1.6H when hovering (so ribbons float upward at rest, stream back in flight).
- Visible when `vis > 0.01 && J.fade > 0.05`.

### 6.9 Fade/tint inside the light (13007–13011)
`alpha = vis·J.fade`; tint colour = `light.glow·1.3`; `uTintK = J.tint`; outline thickness `0.012·(1 − 0.8·J.tint)`. `root.visible = alpha > 0.01`.

---

## 7. 09 · Post-processing (13016–13141)

### 7.1 Chain (`buildPost`, 13093–13104)
`EffectComposer` with a non-MSAA RGBA8 target, no depth (13095–13096):
1. **SceneInkPass** — renders the scene into its own **MSAA (samples = 4)** RGBA8 target with a `DepthTexture` (UnsignedInt), then draws the ink-edge shader into the chain (13049–13065). `needsSwap = false` (writes to readBuffer).
2. **Tilt-shift H** (pair 1)
3. **Tilt-shift V** (pair 1)
4. **Tilt-shift H** (pair 2, only at strong blur)
5. **Tilt-shift V** (pair 2)
6. **GRADE** — filmic grade + region cast + vignette
7. **OutputPass** — three.js addon (tone mapping + sRGB conversion per renderer settings; renderer config not in scope).

### 7.2 Ink edge (`INK_EDGE`, 13025–13047)
Depth-based silhouette lines, constant ~2 px, drawn only on the **near side** of an edge:
```glsl
float lin(vec2 uv){ float d = texture2D(tDepth, uv).x; return (uNear * uFar) / (uFar - d * (uFar - uNear)); }
vec4 c = texture2D(tDiffuse, vUv);
if (uOn < 0.5) { gl_FragColor = vec4(c.rgb, 1.0); return; }
vec2 o = uTexel * 1.7;
float z = lin(vUv), zl = lin(vUv - vec2(o.x,0)), zr = lin(vUv + vec2(o.x,0)), zd = lin(vUv - vec2(0,o.y)), zu = lin(vUv + vec2(0,o.y));
float far = max(max(zl, zr), max(zd, zu));
float lap = (zl + zr + zd + zu - 4.0 * z) / z;                 // >0: this pixel is in front of its surroundings
float edge = smoothstep(0.012, 0.05, lap) * smoothstep(0.008, 0.03, (far - z) / z);
edge *= 1.0 - smoothstep(uFar * 0.55, uFar * 0.9, z);           // not on the horizon
edge *= c.a;                                                    // veil transmittance: no lines through clouds
gl_FragColor = vec4(mix(c.rgb, uInk, edge * uK), 1.0);
```
Uniforms: `uInk (0.24,0.27,0.31)`, `uK 0.75` default; per frame (13108–13112): `uTexel = 1/canvas`, `uNear/uFar = camera`, `uK = look.edgeInk(0.7)·(1−map)·uInk`, `uOn = edgeInk > 0.01 && map < 0.99`. Transparent layers write no depth so they are never outlined.

### 7.3 Tilt-shift with clear band (`tiltShader`, 13017–13024)
Patches three.js `HorizontalTiltShiftShader` / `VerticalTiltShiftShader` (imported 274–275): adds `uniform float band` and replaces `float hh = h * abs(r - vUv.y);` with
```glsl
float hh = h * smoothstep(0.0, 0.5, max(abs(r - vUv.y) - band, 0.0)) * 0.5;
```
so rows within `band` of the focus row `r` are perfectly sharp, ramping to full blur 0.5 beyond. (The underlying addon is a 9-tap separable Gaussian with offsets −4..+4 × hh — that kernel lives in the three.js addon, not this file.)

Per frame (13127–13139):
```
lowK = 1 - smoothstep(low 950, mid 1650, A)
k = (0.32 + 0.5·lowK) · (1 - 0.8·smoothstep(mid, high 8000, A)) · look.tiltShift · (1 - map) · cloudIn
pair1 kk = (k > 0.55 ? k : 1.25k);  pair2 kk = 0.75k
h = kk·9 / W,  v = kk·9 / H;  r = focusY (0.3–0.7, pulled 40% toward the light's screen row)
band = look.focusBand(0.18) · (1.25 + 0.5·(1 - lowK))         // 0.225 low, 0.315 at cruise+
pair1 enabled if k > 0.02; pair2 only if k > 0.55
```
Resulting strength: A ≤ 950 → k 0.82 (two pairs: 0.82, 0.615); A = 1650 → k 0.32 (one pair at 0.40); A ≥ 8000 → k 0.064 (one pair at 0.08). Variance-matched switch (comment 13134).

### 7.4 Cinema grade (`GRADE`, 13066–13091, update 13114–13126)
```glsl
// regional cast (sect air) first
if (uRegion.w > 0.002) { float l0 = luma(c); c = mix(c, c * uRegion.rgb, uRegion.w);
  c = mix(vec3(luma(c)), c, 1.0 + uRegSat * uRegion.w); c *= l0 / max(luma(c), 1e-3); }   // luminance-preserving
if (uK < 0.002) { out c; }
vec3 s = c * c * (3.0 - 2.0 * c);                    // S-curve
vec3 g = mix(c, s, uContrast * uK);                  // uContrast 0.5
g = mix(g, g * uShadow, (1.0 - smoothstep(0.05, 0.6, l)) * 0.6 * uK);   // uShadow (0.9, 0.95, 1.04) cool shadows
g = mix(g, g * uHigh,  smoothstep(0.4, 0.95, l) * 0.7 * uK);            // uHigh (1.05, 1.0, 0.93) warm highs
g = mix(vec3(luma(g)), g, 1.0 + (uSat - 1.0) * uK);                      // uSat 1.12
vec2 q = (vUv - 0.5) * vec2(uAspect, 1.0) / vec2(max(uAspect, 1.0));
g *= 1.0 - uVig * uK * smoothstep(0.3, 0.9, length(q) * 1.6);
```
Update: `uK = cinema.grade·(0.12 + 0.88·smoothstep(0.9mid, high, A))·(1−map)·uWash`; `uVig = cinema.vignette(0.35)`. Region: nearest sect by `k = 1 − smoothstep(R0, R1, dist)` with `R0/R1 = land.R·0.55/1.05` (or `R·1.0/1.9`); colour from the landform's `LF.grade` or defaults `ice (0.93,0.97,1.06, sat −0.1)`, `jade (0.97,1.02,0.985, +0.02)`, `gold (1.06,1.0,0.92, +0.06)`; `rk = bk·0.6·(1−map)·cinema.region`. Pass disabled when both weights are ~0.
There are also DOM overlays (silk paper texture, CSS vignette) set in the frame loop (14960–14961) — not part of the GL chain.

---

## 8. 11 · Weather & ambience (13307–13464)

### 8.1 Cranes (13311–13378)
Instanced flat-shaded triangle crane (`craneGeometry`, 13341–13360; model x = wings, z = body, beak at −z, ~14 units wingspan before scale): body, neck, red crown/beak (0.75,0.25,0.2), black trailing legs, two-segment wings with black primaries. `aWing` per-vertex (0 body, up to ±1 at tip).
Per-instance `iOrbit = (cx, cz, R, height)`, `iMove = (angularSpeed, phase, scale, flapPhase)`.
VS (13312–13331):
```glsl
float th = iMove.y + iMove.x * uTime;
vec3 c = vec3(iOrbit.x + cos(th) * iOrbit.z, iOrbit.w + 18.0 * sin(uTime * 0.31 + iMove.y * 3.0),
              iOrbit.y + sin(th) * iOrbit.z * 0.72);                          // elliptical orbit, ±18 bob
vec2 dir = normalize(vec2(-sin(th) * sign(iMove.x), cos(th) * 0.72 * sign(iMove.x)));
float fl = sin(uTime * 3.2 + iMove.w) * (0.25 + 0.75 * step(0.0, sin(uTime * 0.37 + iMove.w * 2.0)));  // flap/glide
p.y += abs(aWing) * fl * 0.45 * iMove.z * 6.0 - abs(aWing) * 0.6;
vec3 wp = c + vec3(p.x * -dir.y - p.z * dir.x, p.y, p.x * dir.x - p.z * dir.y);
```
FS: faceted normal from `dFdx/dFdy`, `l = 0.9 + 0.16·|N·sun|`, opaque, discard when `uWash < 0.5 || uMap > 0.9`.
Flocks (13364–13370), `add(x, z, R, h, n, dir)` → each bird: `R·(0.92+0.16r)`, `h ± 25`, `ω = dir·(0.05+0.02r)·(900/R)`, phase `w + i·0.09 + 0.03r` (so the flock strings out in a line), scale `3.4–4.2`:
luoyun (z−100) R 820 h 430 n 5 cw; gujian (z−400) 700/560/4 ccw; baiqiao (z−200) 760/380/3; yunmeng mark 1300/820/4 ccw; tianzhu mark 700/900/3; luanming 420/340/9.
Visible when `uMap < 0.95` (13463).

### 8.2 Sword light (13379–13421)
Ribbon of 29 sections (N = 28), additive, double-sided, order 11.
- Launch every `7 + 6·rand` s when `wash > 0.99 && map < 0.01` (13406): two different random spires of 古剑门 (`S.cols` with `spire` or id `jiange`), quadratic Bézier `P0 = spireA top+20`, `P2 = spireB top+20`, `P1 = mid + (0, 160+140r, 240(r−0.2))`; `dur = 1.5 + 0.6r` s.
- Each frame `t += dt/dur`; head = min(1, t), tail = max(0, head − 0.45); sections sampled along [tail, head]; camera-facing side `(tangent × toCam)`, width `w·(0.3 + 0.7i/N)`, `w = 5 + 3 sin(9t)`. Ends at t = 1.35; `uA = 0.75·(1 − smoothstep(1, 1.35, t))`.
- FS: `a = pow(u, 2.2)·smoothstep(0, 0.6, across)·uA`; colour (0.75,0.9,0.95) → white at the head.

### 8.3 Furnace smoke (13422–13444)
A card-cloud layer (`cloudLayer(src·7, 13, 60, 300, true)`) with its own `uMist (0.86,0.85,0.82)` and `uShade (0.58,0.58,0.57)`. Source = `WORLD.smokes` (chimneys). 7 puffs per source, life 9 s, initial `age = k·1.3` (staggered conveyor).
Per frame: `t = age/life`, `w = 30 + 120t`, `h = 0.62w`, pos `(s.x + wind.x·70t, s.y + 20 + 230·sqrt(t), s.z + wind.y·70t)`, opacity `0.55·smoothstep(0, 0.12, t)·(1 − smoothstep(0.55, 1, t))`, kind 7. Layer `uGlobal = cloudIn·(1−map)·(1 − 0.7·smoothstep(mid, high, A))`; fades `0.12A / 0.4A`.

### 8.4 Spirit glow halo (13445–13457)
Billboard 260 丈 at (lingyan.x, 160, lingyan.z), additive: `a = exp(−4d²)·(0.36 + 0.1 sin(1.1t))·wash·(1−map)`, colour (0.62,0.92,0.84).

---

## 9. 11b · NPC cultivators (13466–13579)

- **Nodes** (`flyerNodes`, 13499–13506): every sect `(x, z + 0.32R, y = S.cloud + 420, sect look)`; every city `(x, z+300, 260)`; marks `lingyan, tingyun, zimu, dimai, guxiu, feilian, sunshi` at `ground + 260`; every lore array `y + 200`.
- **Count** `N = clamp(round(lore.flyers), 0, 16)` = 8; `SEG = 16`. Per flyer: `spd = flyerSpeed(340)·(0.8–1.2)`, initial wait 2–9 s (13510–13513, `mulberry32(2626)`).
- **Set off** (13531–13541): from = previous destination (or random), to = random node ≥ 1800 away (10 tries); `dur = dist/spd`; `arc = 120 + 220r`, `sway = ±300`. Colour: from a sect → ice `FL_COLS[0] (0.7,0.88,1.0)` / jade `[1] (0.6,0.94,0.8)` / otherwise amber `[2] (1.0,0.8,0.55)`; from non-sect: 50% pick white/mint/lilac `[3..5]`.
- **Movement** (13552–13565), `t += dt/dur`:
```js
e = t<0.1 ? t/0.1 : t>0.9 ? (1-t)/0.1 : 1               // take-off / landing ramps
x = lerp(from.x,to.x,t) + sin(πt)*sway*0.3;  z = lerp(from.z,to.z,t) + sin(πt)*sway*0.2
cruise = max(lerp(from.y,to.y,t) + sin(πt)*arc, hAt(x,z) + 170)     // climbs with the ranges
y = lerp(hAt(x,z) + 30, cruise, smoothstep(0,1,e))
```
  On arrival: off, wait `3 + 9r` s.
- **Trail**: history pushed every 0.05 s, max 17 points → ~0.8 s tail; last point always = current head. One merged ribbon mesh for all flyers (N·17·2 verts), unused sections collapse to the oldest point; `aOn = min(1, n/6)` ramps in.
  - VS: `p = position + cameraRight * aSide * uW * (0.25 + 0.75 * aAlong)` (screen-aligned, widens toward head), `uW = 7 + 0.0055A`.
  - FS: `a = aAlong² · smoothstep(0, 0.7, across) · uGain(0.7) · vOn`, whitening near head. Additive.
- **Heads**: `THREE.Points`, `gl_PointSize = clamp(30·uScale/viewDist, 5, 30)`, `uScale = bufferHeight / (2 tan(fov/2))`; FS core `exp(−9r²)` + halo `exp(−2.6r²) − exp(−2.6)`, additive.
- Visible when `wash > 0.99 && map < 0.98 && mode != 'intro'`. No LOD beyond pixel-size clamps.

---

## 10. 11c · Life: pedestrians, carts, riders, boats, flying boats, deer, motes (13581–14077)

### 10.1 Architecture (13582–13591)
- Every route polyline is **resampled to N = 256 points at equal arc length** and stored as one row of an **RGBA32F DataTexture** (`xyz` + arc length in `w`), Nearest filtering (13783–13791, 13886–13891).
- Each mover kind (per group) = one instanced mesh, one draw call. The **vertex shader** walks the route with `texelFetch`, faces along the tangent and animates limbs procedurally. Only deer are CPU-simulated.

### 10.2 Routes (`lifeRoutes`, 13866–13880)
- City paths (`CITY.paths`): kinds avenue/street/market/plaza/pier/town…; bridge/stair/steps → `cityway`; width default avenue 36, market 8, others 10; `loop` flag.
- Sect paths (`SECTS.paths`) → `sect`, w 12, tagged with nearest site within 1.6R.
- Roads (`WORLD.roads`) y = ground + 0.9, chunked to ≤ 2600 丈 (`lifeChunks`, 13793) → `road` (main) / `lane`.
- Rivers: points where `waterAt > 0.35` and inland, y = −water.depth + 0.25, chunked ≤ 4000 → `river`.
- Sea lanes (`lifeSeaLanes`, 13808–13839): two curving lanes out of 封日城's harbour (5 × 1100 丈 steps with bend −0.5 / +0.35, Catmull–Rom ×8); coastal lanes 700 丈 offshore, pieces ≤ 9000 丈, decimated ×3, Catmull ×4; y = −seaDepth + 0.3.
- Sky lanes (`lifeSkyLanes`, 13840–13865): 10 fixed pairs between sects (approached over their front, `z + 0.5R`) and cities at y 420–700; 7 control points with lateral bow `±0.08L` and lift `sin(πt)·min(520, 0.05L) + 160`; Catmull ×10.
- `catmull(P, n, closed)` (13799–13807) is uniform Catmull–Rom.

### 10.3 Instances (`buildLife`, 13881–13937; `mulberry32(4321)`)
Per instance: `iA = (row, s0 ∈ [0, 2L), speed (sign = direction), L)`, `iB = (laneOffset, size·(0.88–1.12), loop, phase)`, `iC = colour` (13895–13902). Direction random ± when `both`.

| kind | routes | count | speed 丈/s | lane width | size | colours |
|---|---|---|---|---|---|---|
| walker | city kinds by density/丈: avenue 0.06, street 0.028, market 0.1, plaza 0.07, pier 0.035, town 0.05, cityway 0.035 (×people) | L·dens | 2.0–3.4 | max(2, w−6) | 1 | 85% folk / 15% cult |
| walker | sect paths | max(1, 0.03L) | 1.8–3.0 | max(2, w−6) | 1 | sect palette |
| walker | road/lane near a city (< flatR + 2600) | 0.012L | 2.0–3.2 | 6 | 1 | folk |
| cart (ox) | road | L/1300·traffic | 3.2–4.8 | 4 | 1 | canopy |
| cart | lane (50%) | 1 | 3–4.4 | 2 | 1 | canopy |
| rider | road | L/2600·traffic (+0/1) | 9–14 | 4 | 1 | folk + cult |
| sampan | river | max(1, L/1500) | 2.2–4.2 | 4 | 1.6 | canopy |
| junk | sea | max(1, L/4500) | 7–11 | 60 | 1 | sail |
| flyboat | sky | max(1, n·2) | 38–58 | 30 | 1 | 3 fixed |

Walkers are **grouped** by city / site / town / 8000-丈 road cell (13898) so each group is a separate mesh with its own bounding sphere (padding: flyboat 200, junk 120, else 60) → frustum culling works per neighbourhood (13921–13922, `frustumCulled = true`).

`KINDS` (13916): `[shader KIND id, GAIT constant, far]`: walker [0, 2.6, far], cart [1, 1.6, 1.6far], rider [2, 1.2, 1.7far], sampan [3, 1, 1.8far], junk [4, 1, 3.4far], flyboat [5, 1, 6far]; deer [6, 1.6, 1.3far]. (`far = 3000`.)

### 10.4 Models (`lifeModel`, 13602–13694)
Built from boxes/frustums/hex wheels/triangles in 丈, +z forward. `aPart`: 0 still, 1/2 alternating legs, 3/4 arms, 5 wheel, 6 glow, **+10 = take instance colour**.
- walker: two legs (0.36×1.45), robe frustum r 0.66→0.46 h 1.85 (tinted), shoulders, arms (parts 13/14 tinted), head 0.5, hair → ~3.3 tall.
- cart: ox body + head + yoke, 4 legs, wooden bed, tinted canopy, shafts, two hex wheels r 0.95 (part 5), drover walking beside.
- rider: horse body, neck, head, tail, 4 legs; tinted rider torso + arms, head, conical hat.
- sampan: L 7, B 1.6, keeled hull, tinted cabin, standing boatman with hat, pole (part 3).
- junk: L 40, B 11, raised stern, deckhouse, 3 masts with tinted battened sails (part 11).
- flyboat: L 62, B 13, swept-up bow/stern, 2-storey cabin with jade swept roofs, glowing rune keel and prow lamp (part 6), 4 wing-sails per side pair (part 11).
- deer: tinted body/neck/head, 4 fawn legs, tail, glowing antlers (part 6).

### 10.5 Vertex shader `LIFE_VS` (13695–13766)
```glsl
vec3 pathPt(float row, float s, float L){
  float f = clamp(s / max(L, 1e-3), 0.0, 1.0) * (uN - 1.0); float i0 = min(floor(f), uN - 2.0); float t = f - i0;
  vec3 a = texelFetch(tPath, ivec2(int(i0), int(row)), 0).xyz, b = texelFetch(tPath, ivec2(int(i0) + 1, int(row)), 0).xyz;
  return mix(a, b, t); }
// route walking
float L = iA.w, v = iA.z, run = iA.y + uTime * abs(v), s, dirS;
if (iB.z > 0.5) { s = mod(run, L); dirS = 1.0; }                                    // loop
else { float m = mod(run, 2.0 * L); s = m < L ? m : 2.0 * L - m; dirS = m < L ? 1.0 : -1.0; }  // ping-pong
if (v < 0.0) { s = L - s; dirS = -dirS; }
p = pathPt(iA.x, s, L);
vec3 q = pathPt(iA.x, clamp(s + dirS * 3.0, 0.0, L), L) - p;                        // look-ahead 3 丈
fw = normalize(q.xz + vec2(1e-5, 0.0)); travelled = run;
vec3 Z = vec3(fw.x, 0.0, fw.y), X = vec3(fw.y, 0.0, -fw.x);
p += X * iB.x;                                                                      // lane offset
float gait = travelled / max(sc, 0.01) * GAIT + ph * 6.2832;                        // phase from distance walked
```
Per-kind animation (rotX about a pivot (y,z), rotZ roll):
- KIND 0 walker: legs `rotX(pivot y 1.45, ±sin(gait)·0.55)`, arms `rotX(2.5, ∓sin(gait)·0.42)`, bob `|sin(gait)|·0.1`.
- KIND 1 cart: ox legs `rotX(1.05, z 3.6/1.8, sin·0.4)`, wheels `rotX(0.95, −1.1, −travelled/(0.95sc))` (rolling without slip), ox bob 0.05.
- KIND 2 rider: legs `rotX(1.5, ±1.0, sin·0.6)`, bob 0.22.
- KIND 3 sampan: roll `rotZ(0.3, sin(1.3t+9ph)·0.06)`, pole `rotX(1.1, −2.4, sin(0.9t+5ph)·0.35)`.
- KIND 4 junk: roll 0.035, pitch 0.02, sails (part 1 after mod 10) bulge sideways `(0.4+0.3 sin)·smoothstep(5,25,y)`.
- KIND 5 flyboat: heave `sin(0.6t)·3`, roll 0.05, pitch 0.03, wing-sails beat `smoothstep(6,22,|x|)·sin(1.2t)·3.5`.
- KIND 6 deer: legs scaled by speed `iB.x`, head down when grazing `rotX(1.9, 0.6, (1−iB.x)·0.55·smoothstep(0.6,1.4,z))`.

**Distance fade + pixel-size boost (LOD)** (13757–13761):
```glsl
float dist = length(p - cameraPosition);
float fade = (1.0 - smoothstep(uFar * 0.62, uFar, dist)) * (1.0 - uMap) * uGain;   // shrinks to nothing far away
float px = sc * 3.6 * uPxK / max(dist, 1.0), boost = clamp(uMinPx / max(px, 1e-3), 1.0, uBoost);
vec3 wp = p + (X * pos.x + vec3(0.0, pos.y, 0.0) + Z * pos.z) * sc * fade * boost;
```
`uPxK = innerHeight / (2 tan(fov/2))` (14001); `uMinPx`: walker 3.6, cart/rider/sampan 4.5, others 0, deer 4.2; `uBoost`: walker 1.7, others 1.5, deer 1.6 (13927, 13959). So tiny figures are enlarged up to 1.5–1.7× to stay ≥ ~4 px.
FS (13767–13781): faceted normal via derivatives, `tones(N)` 3-tone toon, `castLight(sunAt(xz).r)` ground-shadow, floor 0.15, glow parts `vCol·1.25`, `hazeMix`. Opaque, double-sided.

### 10.6 Per-frame (`updateLife`, 13999–14012)
Altitude ceilings `top`: walker 3600, deer 4200, cart/rider 6000, sampan 6500, junk 14000, flyboat 30000; `gain = life.amount·(1 − smoothstep(0.7top, top, A))·smoothstep(0.6, 1, wash)`. `uFar = kind.far·(life.far/3000)`. Mesh hidden when `gain ≤ 0.01`, map mode, or its group bounding sphere is farther than `1.2·uFar` horizontally from the camera (coarse CPU LOD).

### 10.7 Deer (13938–13998)
Meadows: lingyan (+120 z, r 380) plus up to 3 of 7 seeded try-points: 40 random samples within ±1500 accepted if `2 < h < 260`, inland, (`sdAt > -80` rejects), flat (6 probes at 160 丈 differ ≤ 26), not within 120 of a road → r 240.
Herd: `max(4, round(28/meadows))` per meadow, start within `0.5r`; colour white at lingyan, else 30% pale / 70% fawn.
Steering per deer (dt capped 0.1):
```
graze > 0: v *= 1 - min(1, 3dt)                                  // stand and graze
else: wa += (rand-0.5)*3*dt                                      // wander angle jitter
      a += (heading*6 + (cos wa, sin wa)*4) * 0.6                // wander
      if dist_to_meadow > 0.6r: a += dirToCentre * (dist - 0.6r) * 0.08   // leash
      if graze < -8 - 10ph: graze = 3 + 7rand                    // walk ~8–18 s, graze 3–10 s
separation (O(n²)): if d < 10: a += away * (10 - d) * 0.8
v += a dt; clamp |v| ≤ 7; x += v dt; yaw = atan2(vx, vz) if |v| > 0.4; k += |v| dt
iA = (x, max(hAt,0) - 0.2, z, yaw), iB.x = clamp(|v|/3, 0, 1), iB.z = k (distance for gait)
```
Shader `WANDER` path uses `fw = (sin yaw, cos yaw)`. Updated only when visible.

### 10.8 Spirit motes — wrapped field (14014–14065)
180 points (`life.motes`), each with `aSeed ∈ [0,1)^4`; box `uBox = (1300, 700, 1300)` centred 700 ahead of the camera (`cam.pos + forward·700`).
```glsl
vec3 drift = vec3(sin(uTime*0.11 + ph)*40.0 + uTime*5.0, uTime*(4.0 + aSeed.w*7.0), cos(uTime*0.09 + ph*1.3)*40.0);
vec3 p = aSeed.xyz * uBox + drift;
p = mod(p - uCenter + uBox * 0.5, uBox) - uBox * 0.5 + uCenter;           // wrap into box around camera
float tw = 0.55 + 0.45 * sin(uTime * (1.1 + aSeed.w) + ph * 3.0);        // twinkle
float edge = 1.0 - smoothstep(0.72, 1.0, max(q.x, max(q.y, q.z)));       // fade at box faces (hide wrap pops)
vA = tw * edge * smoothstep(60.0, 220.0, dist) * uGain * (1.0 - uMap);
vCol = mix(vec3(0.72, 0.96, 1.0), vec3(1.0, 0.9, 0.7), step(0.72, fract(aSeed.w * 13.7)));   // 28% warm
vCol = mix(vCol, uRegTint.rgb, uRegTint.w * 0.8);
gl_PointSize = clamp(uScale * (4.0 + 5.0 * fract(aSeed.w * 7.3)) * 700.0 / max(dist, 1.0), 1.2, 9.0);
```
FS: `exp(−3.6r²)·vA·0.55`, additive. Update: `gain = amount·(1 − smoothstep(1300, 2300, A))·smoothstep(0.6, 1, wash)` (only low flight); region tint per sect look `ice (0.8,0.93,1.0)`, `jade (0.6,1.0,0.8)`, `gold (1.0,0.8,0.5)` with `bk = 1 − smoothstep(0.9R, 1.8R, dist)`; `uGain *= 1 + 0.9bk` (denser inside sects).

`lifeWhere(kind, i)` (14067–14076) duplicates the VS route arithmetic on the CPU for tests — reuse it if you need gameplay queries ("where is cart 3").

---

## 11. Godot 4 mapping

General: keep the shared "global" uniforms (`time`, `map_k`, `cloud_in`, `wash`, `wind`, `alt_A`) as **global shader uniforms** (Project Settings → Shader Globals; `global uniform float map_k;`) and update them from one autoload each frame (`RenderingServer.global_shader_parameter_set`). This mirrors the shared `U` object.

Scale: 丈 world units are big (cruise A = 1650, world ~40 000 wide). Set Camera3D `near = max(5, y*0.05)`, `far = y*40 + 30000` each frame like 14940; Godot handles large far planes fine with reversed-Z (4.3+).

### 11.1 Card clouds → MultiMeshInstance3D + billboard shader (not FogVolume)
**Why not FogVolume / volumetric fog:** Godot's volumetric fog is a froxel grid bounded by `Environment.volumetric_fog_length` (default 64 m, practical max a few hundred units) — far too short for clouds 700–3000 丈 away, and its resolution would blur the brush-card look. Use FogVolumes only for an optional close-up valley haze at the lowest altitude band. Use **cards** for everything in §1.

Packing (one QuadMesh 1×1, MultiMesh `use_custom_data = true`):
- instance transform origin = `iPos.xyz`; basis scale x = w, y = h (read back with `length(MODEL_MATRIX[0].xyz)`).
- `INSTANCE_CUSTOM = (seed, opacity, kind, phase)`. `flip` and `sway` are derivable: flip = seed > 0.5 (12191), sway by kind (bank 120, wall 140, near 0, else 40).
- Set `MultiMesh.custom_aabb` large (original disables culling).

```glsl
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
global uniform float time_s; global uniform vec2 wind; global uniform float map_k;
uniform sampler2D cloud_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_tex = true;
uniform float u_global = 1.0, u_speed = 1.0, fade_near = 160.0, fade_far = 700.0;
uniform vec3 mist : source_color = vec3(0.86, 0.87, 0.84);
uniform vec3 shade : source_color = vec3(0.68, 0.73, 0.74);
uniform vec2 part = vec2(300.0, 800.0); uniform vec2 target_xz;
varying vec3 v_wp; varying vec4 v_data;
#include "res://shaders/noise.gdshaderinc"   // vnoise / fbm3 ported 1:1 from lines 491-499

void vertex() {
  v_data = INSTANCE_CUSTOM;
  vec3 c = MODEL_MATRIX[3].xyz;
  float w = length(MODEL_MATRIX[0].xyz), h = length(MODEL_MATRIX[1].xyz);
  float kind = v_data.z;
  float sway = kind > 5.5 ? 140.0 : (abs(kind - 1.0) < 0.5 ? 120.0 : (abs(kind - 5.0) < 0.5 ? 0.0 : 40.0));
  c.xz += wind * sin(time_s * u_speed * 0.045 + v_data.w * 6.283) * sway;
  c.y *= 1.0 - map_k;
  vec3 right = INV_VIEW_MATRIX[0].xyz, up = INV_VIEW_MATRIX[1].xyz;   // = viewMatrix rows in three.js
  v_wp = c + right * VERTEX.x * w + up * VERTEX.y * h;
  POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v_wp, 1.0);
  if (v_data.x > 0.5) UV.x = 1.0 - UV.x;
}
void fragment() {
  vec2 uv = vec2(UV.x, 1.0 - UV.y);      // Godot UV.y is top-down; three.js uv.y is bottom-up
  float n = fbm3(uv * vec2(3.2, 1.8) + v_data.x * 37.0 + time_s * 0.012);
  float a; vec3 col;
  if (has_tex) { vec4 t = texture(cloud_tex, uv);
    a = t.a * smoothstep(0.02, 0.62, t.a + (n - 0.5) * 0.3);
    col = mix(shade, mist * 1.06, smoothstep(0.3, 0.95, dot(t.rgb, vec3(0.33)) + (uv.y - 0.5) * 0.25));
  } else { vec2 p = (uv - 0.5) * vec2(2.0, 2.6);
    a = (1.0 - smoothstep(0.35, 1.0, length(p * vec2(0.85, 1.0)) + (n - 0.5) * 0.9)) * smoothstep(0.0, 0.25, uv.y);
    col = mix(shade, mist * 1.05, smoothstep(0.15, 0.85, uv.y + (n - 0.5) * 0.4)); }
  a *= smoothstep(fade_near, fade_far, length(v_wp - CAMERA_POSITION_WORLD));
  if (abs(v_data.z - 1.0) < 0.5) a *= smoothstep(part.x, part.y, length(v_wp.xz - target_xz));
  a *= v_data.y * u_global;
  if (a < 0.004) discard;
  ALBEDO = col; ALPHA = a;
}
```
Use separate MultiMeshInstance3D nodes (and `render_priority`) for mist/wall/near/smoke; for the near layer set `render_mode ... depth_test_disabled`. Port `updateClouds` (§1.6) to GDScript setting `fade_near/far`, `u_global`, `part`, `target_xz`; the near-cloud pool updates 6 instances via `multimesh.set_instance_transform/custom_data`. Use the camera-relative forward vector rather than world −z for the "behind" test (the original's `c.z - cam.z > 0.2A` assumes a north-facing camera).

Smoke (§8.3) is the same shader with `mist (0.86,0.85,0.82)`, `shade (0.58,0.58,0.57)`. Alternative for smoke: GPUParticles3D with a billboard ParticleProcessMaterial (lifetime 9, amount 7/source, `scale_curve` 30→150, gravity 0, initial velocity up ~25 丈/s easing out via `damping`, alpha curve 0→0.55→0) — visually close, less code.

### 11.2 Cloud sea → ArrayMesh + raymarching spatial shader
Mesh: build the 100-丈 grid in GDScript exactly as 12441–12465 (only cells with density > 2); put `aLift` in `UV2.x` (or `CUSTOM0`). Textures: density as `Image.FORMAT_R8` (box-blurred as §2.3), ground height as `FORMAT_RF`, sun bake as `FORMAT_RGBA8`, 3D noise as `ImageTexture3D` (48³ R8, build as §2.4; set `repeat_enable`).

```glsl
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
global uniform float time_s; global uniform vec2 wind; global uniform float map_k; global uniform float cloud_in;
uniform sampler2D dens_tex : filter_linear, repeat_disable;
uniform sampler2D land_tex : filter_linear, repeat_disable;   // r = ground height (丈)
uniform sampler2D sun_tex  : filter_linear, repeat_disable;   // g = peak shadow on the sea
uniform sampler3D noise3d  : filter_linear, repeat_enable;
uniform vec4 rect;                     // x0, z0, width, depth
uniform float top_y = 175.0, amp = 1.0, speed = 1.0, thick = 150.0, dens_k = 1.0, alpha_k = 1.0;
uniform int steps = 9;
uniform vec3 sun_dir;
uniform vec3 lit : source_color = vec3(0.992, 0.976, 0.941);    // #fdf9f0
uniform vec3 shade_c : source_color = vec3(0.812, 0.847, 0.871); // #cfd8de
uniform vec3 deep : source_color = vec3(0.604, 0.667, 0.710);    // #9aaab5
uniform vec3 haze_col : source_color; uniform float haze = 0.5;
uniform vec2 part; uniform vec2 target_xz;
uniform vec4 sites[6]; uniform vec3 site_tint[6];
varying vec3 v_wp; varying float v_d; varying float v_top; varying float v_swell;
#include "res://shaders/noise.gdshaderinc"

float swellH(vec2 p, float t){ vec2 q = p + wind * t * 6.0; return fbm3(q / 1300.0) - 0.5 + (vnoise(q / 520.0 + 4.3) - 0.5) * 0.45; }
vec2 ruv(vec2 xz){ return (xz - rect.xy) / rect.zw; }

void vertex() {
  vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
  float lift = UV2.x;
  float d = textureLod(dens_tex, ruv(wp.xz), 0.0).r;
  float t = time_s * speed, sk = smoothstep(10.0, 60.0, lift);
  wp.y = top_y + lift + (d - 0.6) * mix(40.0, 14.0, sk) * amp
       + swellH(wp.xz, t) * mix(90.0, 26.0, sk) * amp * smoothstep(0.0, 0.45, d)
       - (1.0 - smoothstep(0.0, 0.28, d)) * mix(120.0, 40.0, sk);
  v_top = wp.y;
  vec2 sunH = normalize(sun_dir.xz + vec2(1e-4));
  v_swell = clamp(1.0 + (swellH(wp.xz, t) - swellH(wp.xz + sunH * 140.0, t)) * 1.8, 0.5, 1.34);
  wp.y *= 1.0 - map_k;
  v_wp = wp; v_d = d;
  POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}
float dens(vec3 p, float top, vec3 drift){
  float d = texture(dens_tex, ruv(p.xz)).r; if (d < 0.01) return 0.0;
  vec3 q = p + drift;
  float n = texture(noise3d, q / 760.0).r * 0.6 + texture(noise3d, q / 230.0 + 0.37).r * 0.4;
  float hgt = (p.y - (top - thick)) / thick;
  float line = 0.45 + 0.55 * d - (n - 0.5) * 1.3;
  float v = smoothstep(line, line - 0.28, hgt) * smoothstep(-0.05, 0.2, hgt);
  return v * smoothstep(0.03, 0.35, d + (n - 0.5) * 0.4);
}
void fragment() {
  vec3 cam = CAMERA_POSITION_WORLD;
  vec3 ro = v_wp, rd = normalize(v_wp - cam);
  float t = time_s * speed; vec3 drift = vec3(wind.x, 0.0, wind.y) * t * 6.0;
  float camD = length(v_wp - cam);
  float L = min(thick / max(-rd.y, 0.12), thick * 4.0), ds = L / float(steps);
  float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy + vec2(fract(t * 0.37) * 13.0, 0.0), vec2(0.06711056, 0.00583715))));
  float sigma = dens_k * 0.045 * alpha_k;
  vec2 suv = ruv(v_wp.xz), sunH = normalize(sun_dir.xz + vec2(1e-4));
  float shadow = mix(0.74, 1.0, smoothstep(0.3, 0.7, texture(sun_tex, suv).g));
  float dSun = texture(dens_tex, suv + sunH * 520.0 / rect.zw).r;
  shadow *= (1.0 - 0.4 * smoothstep(0.0, 0.3, dSun - v_d)) * (1.0 + 0.16 * smoothstep(0.0, 0.3, v_d - dSun)) * v_swell;
  float keep = 0.0, veil = 1.0; vec3 tint = vec3(1.0);
  for (int i = 0; i < 6; i++) {
    float dd = length(v_wp.xz - sites[i].xy);
    float ki = 1.0 - smoothstep(sites[i].z * 0.7, sites[i].z, dd); keep = max(keep, ki);
    veil = min(veil, mix(1.0, mix(0.45, 1.0, smoothstep(sites[i].w + 120.0, sites[i].w + 380.0, cam.y)), ki));
    tint = mix(tint, site_tint[i], 1.0 - smoothstep(sites[i].z * 0.6, sites[i].z * 1.6, dd));
  }
  float pt = smoothstep(part.x, part.y, length(v_wp.xz - target_xz) + (vnoise(v_wp.xz / 420.0) - 0.5) * 240.0);
  float gate = mix(1.0, mix(pt, mix(veil, 1.0, pt), keep), step(1.0, part.y)) * smoothstep(cam.y * 0.22, cam.y * 0.6, camD);
  float T = 1.0; vec3 acc = vec3(0.0); float pDn = 0.0, pAir = 0.0; vec3 pC = vec3(0.0);
  for (int i = 0; i < 24; i++) {
    if (i >= steps) break;
    vec3 p = ro + rd * (ds * (float(i) + jit));
    float air = p.y - (texture(land_tex, ruv(p.xz)).r - 1.0);
    if (air < 0.0) {
      if (pDn > 0.0) { float a = 1.0 - exp(-pDn * sigma * ds * clamp(pAir / max(pAir - air, 1e-3), 0.0, 1.0)); acc += T * a * pC; T *= 1.0 - a; }
      pDn = 0.0; break;
    }
    if (pDn > 0.0) { float a = 1.0 - exp(-pDn * sigma * ds); acc += T * a * pC; T *= 1.0 - a; pDn = 0.0; if (T < 0.015) break; }
    float dn = dens(p, v_top, drift) * gate;
    if (dn < 0.002) continue;
    float light = exp(-dens(p + sun_dir * 95.0, v_top, drift) * 1.6) * shadow;
    float lee = dens(p + vec3(sunH.x, 0.3, sunH.y) * 70.0, v_top, drift);
    light *= 1.0 + 0.55 * clamp((dn - lee) * 2.2, -0.6, 1.0);
    float dk = clamp((p.y - (v_top - thick)) / thick, 0.0, 1.0);
    pC = mix(deep, mix(shade_c, lit, light), 0.2 + 0.8 * dk * dk) * tint;
    pDn = dn; pAir = air;
  }
  if (pDn > 0.0) { float a = 1.0 - exp(-pDn * sigma * ds); acc += T * a * pC; T *= 1.0 - a; }
  float a = (1.0 - T) * cloud_in * (1.0 - map_k);
  if (a < 0.004) discard;
  vec3 col = acc / max(1.0 - T, 1e-3);
  col = mix(col, haze_col, smoothstep(cam.y * 1.2, cam.y * 3.6, camD) * haze * 0.45);
  ALBEDO = col; ALPHA = a;
}
```
Notes: Godot's opaque depth buffer still occludes the sea surface behind peaks (default depth test). Set MeshInstance3D `custom_aabb` (the original disables culling). Colours: if your project is in linear space with `source_color`, enter the sRGB hex values and let Godot convert; three.js `new Color('#hex')` with ColorManagement also converts to linear. An optional cheaper alternative to `land_tex`: sample `hint_depth_texture` to stop the march at the scene depth (handles islands/props too, but loses the "fraction in air" skirt precision for off-screen rock).

`updateCloudSea` → GDScript: `part = Vector2(0.3, 0.95) * min(A, 1.4*mid) * (1 - smoothstep(1.4*mid, 2.6*mid, A))`, `target_xz = rig target`, `steps = clamp(round(9 * lite_k), 3, 24)`.

### 11.3 God rays / cirrus / cloud falls
- **Shafts:** ArrayMesh built as §3.1 (two crossed strips × 6 segments, lean toward sun). Shader: `render_mode unshaded, blend_add, depth_draw_never, cull_disabled;` port SHAFT_FS verbatim (`ALBEDO = col*a; ALPHA = a` or premultiplied with `blend_premul_alpha`). Godot's built-in Environment **volumetric fog + light** god rays don't reach this scale; these cards are the right tool. (Also consider WorldEnvironment `glow` off for these to keep the paper look.)
- **Cirrus:** one PlaneMesh at y 4300, size rect + 12000, CIRRUS_FS port; gain from camera height (§3.2).
- **Cloud falls:** ArrayMesh from the landform fall polylines with 3 layers × 13 columns (§4); CLOUDFALL_FS port with `blend_mix, depth_draw_never, cull_disabled`.

### 11.4 Escape light, trails, NPC flyers
- **Glows:** 3 `MeshInstance3D` QuadMesh with `billboard` (`render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never`), FS `a = exp(-r2*fall) * (1 - smoothstep(0.8,1,sqrt(r2)))`; set quad size per frame (§5.2). `render_priority` to reproduce order 40–44.
- **Beam & trail:** use an `ImmediateMesh` (or an `ArrayMesh` with `surface_update_vertex_region`) rebuilt per frame — camera-facing strips need the camera vector, which GPUParticles3D `RibbonTrailMesh` cannot do (its shapes are FLAT/CROSS in particle space, not view-aligned). GPUParticles3D with `trail_enabled` + RibbonTrailMesh (shape CROSS) is an acceptable shortcut for NPC flyers where the tail is thin.

```gdscript
# DunTrail.gd — port of 12792-12805
extends MeshInstance3D
const TN := 96
var hist: Array = []          # [{p: Vector3, t: float}]
@onready var im := ImmediateMesh.new()
func _ready(): mesh = im
func update_trail(p: Vector3, t: float, dir: Vector3, cam: Vector3, K: float, sp01: float, boostK: float, tail := 1.0) -> void:
    hist.push_front({p = p, t = t})
    var keep := (0.55 + 0.75 * sp01 + 0.4 * boostK) * tail
    while hist.size() > TN or (hist.size() > 2 and t - hist.back().t > keep):
        hist.pop_back()
    var n := hist.size()
    im.clear_surfaces()
    im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
    for k in TN:
        var h: Vector3 = hist[min(k, n - 1)].p
        var tan: Vector3 = hist[clampi(k - 1, 0, n - 1)].p - hist[min(k + 1, n - 1)].p
        if tan.length_squared() < 1e-6: tan = dir
        var side := tan.cross(cam - h).normalized()
        var w := (10.0 + 6.0 * sp01) * K * pow(1.0 - float(k) / TN, 0.9)
        var vt := float(k) / (TN - 1)
        im.surface_set_uv(Vector2(-1.0, vt)); im.surface_add_vertex(h - side * w)   # UV.x = aSide, UV.y = aT
        im.surface_set_uv(Vector2( 1.0, vt)); im.surface_add_vertex(h + side * w)
    im.surface_end()
```
(Positions are world-space: keep the node at the origin with identity transform, `top_level = true`.) Trail shader = DG_TRAIL_FS with `vSide = UV.x`, `vT = UV.y`.
- **Speed lines:** 28 quads in one ImmediateMesh, spawn logic §5.5 in GDScript.
- **Ground shadow:** pass `shadowP`/`glowP` as global shader params to the terrain shader (or use a `Decal` node with a soft blob texture, size `(26 + 0.08h)·K·1.4·2`, offset away from the sun by `0.45h/sunY`, modulate alpha `0.32·0.55·(1 − 0.5 smoothstep(200,1400,h))`).
- **NPC flyers:** GDScript port of §9 (nodes, setOff, movement). Heads: one `MultiMeshInstance3D` of billboard quads (or a `PRIMITIVE_POINTS` mesh with `render_mode` + `POINT_SIZE` in the shader, needs `use_point_size` flag on the material); tails: one ImmediateMesh for all 8 with the `cameraRight * aSide * w * (0.25+0.75 along)` widening done in the vertex shader via `INV_VIEW_MATRIX[0].xyz`. Alternatively `Path3D` per flight is unnecessary — the analytic lerp+sin path is simpler.

### 11.5 Figure: Blender rig + Godot
**Blender build** (1 unit = figure height; scale in Godot by H each frame — or keep a real-size model and scale the root by `H/height`):
- Bones (rest pose, +Y forward in Blender → export so the figure faces Godot −Z or +Z consistently; the original faces +z): `root` (0,0,0) → `lean` head at (0,0,0) (pitch/roll pivot is the **feet**) → `torso` head (0,0.45) tail (0,0.75) → `neck` (0,0.755)→(0,0.825) → `head` (0,0.825)→(0,0.95); `shoulder.L/R` at (∓0.105, 0.74, 0) child of torso → `elbow.L/R` at (∓0.105, 0.54) → `hand` at (∓0.105, 0.355); `foot.L/R` at (∓0.04, −0.01, 0.02), child of `lean`; `robe` bones optional (the robe is shader-deformed, see below).
- Ribbon anchor sockets (BoneAttachment3D or Marker3D under `lean`): sash.L (−0.04, 0.45, −0.10), sash.R (0.04, 0.45, −0.10), hair (0, 0.88, −0.07).
- Rotation conventions to reproduce: lean bone X = pitch forward (+), Z = bank; shoulder X + = arm swings back, shoulder Z = abduction (left negative, right positive); elbow X = bend, elbow Z = fold inward (left +1.3, right −1.3 in hover). Euler XYZ.
- Shading: flat 3-tone toon (`softTones`) + inverted hull outline: in Godot add `next_pass` material `render_mode unshaded, cull_front; void vertex(){ VERTEX += NORMAL * outline; }` with `outline = 0.012 * (1 - 0.8*tint)` (model units), colour `ink (0.24,0.27,0.31)` mixed to tint.

**Pose driving — two options**
1. *Faithful (recommended):* skip clips; keep the original's procedural easing in GDScript and write rotations with `Skeleton3D.set_bone_pose_rotation()` (or a custom `SkeletonModifier3D` in 4.4+ so it runs in the skeleton update). AnimationTree is then only used for idle micro-loops if you add them.
2. *AnimationTree:* author 3 poses in Blender as 1-frame actions — `hover` (shX 0.2, shZ ∓0.12, elX −0.4, elZ ±1.3, lean 0.04), `cruise` (shX 1.1, shZ ∓0.25, elX −0.3, elZ ±0.2, lean 30°·0.8), `dun_gather` (lean −0.15, shX 0.3, shZ ∓0.9, elX −0.6), `dun_dive` (lean 66°, shX 1.55, shZ ∓0.1, elX 0.05, elZ 0). AnimationTree StateMachine `hover ↔ cruise ↔ dun`; the original's exponential easing with τ reaches 95% in 3τ → use xfade ≈ 0.8 s (τ 0.28) for hover/cruise and ≈ 0.35 s (τ 0.12) into/out of dun; inside `dun`, a BlendSpace1D `gather→dive` driven by `1 - smoothstep(0.08, 0.3, time_in_state)`. Bank and climb-pitch go on top as an **Add2** with additive lean/bank poses, amounts `bank = -turn·22°·(0.4+0.6 spC)`, `climb·-0.25`.

```gdscript
# FigurePose.gd — port of 12938-12961 (option 1)
extends Node3D
@export var skel: Skeleton3D
var J := {lean=0.05, bank=0.0, shX=[0.2,0.2], shZ=[-0.12,0.12], elX=[-0.4,-0.4], elZ=[1.3,-1.3], flutter=0.03, trail=0.05, fade=1.0, tint=0.0, scale=1.0}
var state := "hover"; var t0 := 0.0; var prev_v := Vector3.ZERO; var dir := Vector3(0,0,-1)
const LEAN := deg_to_rad(30.0); const BOOST_LEAN := deg_to_rad(66.0); const BANK := deg_to_rad(22.0); const FADE := 0.22
static func ease(cur: float, to: float, dt: float, tau: float) -> float:
    return lerpf(cur, to, 1.0 - exp(-dt / max(0.01, tau)))
func step(dt: float, t: float, vel: Vector3, cruise: float, boost_mul: float, dunK: float, flare: float, boosting: bool, climb_in: float) -> void:
    var speed := Vector2(vel.x, vel.z).length()
    var spC := clampf(speed / cruise, 0.0, 1.2)
    if speed > cruise * 0.03:
        dir = dir.lerp(Vector3(vel.x, 0, vel.z) / speed, 1.0 - exp(-dt * 6.0)).normalized()
    var acc := (vel - prev_v) / max(dt, 1e-4); prev_v = vel
    var turn := clampf((dir.z * acc.x - dir.x * acc.z) / (cruise * 2.2), -1.0, 1.0)
    var climb := clampf(climb_in * 6.0, -1.0, 1.0)
    var nxt := "dun" if (dunK > 0.35 or (boosting and flare > 0.5)) else ("cruise" if spC > 0.12 else "hover")
    if nxt != state: state = nxt; t0 = t
    var since := t - t0
    var T := {}
    match state:
        "hover":
            T = {lean=0.04 + 0.02*sin(t*1.1), shX=[0.2,0.2], shZ=[-0.12,0.12], elX=[-0.4,-0.4], elZ=[1.3,-1.3], flutter=0.025, trail=0.02, fade=1.0, tint=0.0, scale=1.0}
        "cruise":
            var s := 0.95 + 0.3*spC
            T = {lean=LEAN*(0.6+0.4*spC) - 0.25*climb, shX=[s,s], shZ=[-0.25,0.25], elX=[-0.3,-0.3], elZ=[0.2,-0.2], flutter=0.05+0.08*spC, trail=0.12+0.3*spC, fade=1.0, tint=0.0, scale=1.0}
        _:
            var g := 1.0 - smoothstep(0.08, 0.3, since)
            var sx := lerpf(1.55, 0.3, g); var ex := lerpf(0.05, -0.6, g)
            T = {lean=lerpf(BOOST_LEAN, -0.15, g) - 0.2*climb, shX=[sx,sx], shZ=[lerpf(-0.1,-0.9,g), lerpf(0.1,0.9,g)], elX=[ex,ex], elZ=[0.0,0.0], flutter=0.16, trail=0.55, fade=lerpf(1.0, FADE, dunK), tint=0.75*dunK, scale=1.0+0.06*g}
    var bankT := -turn * BANK * (0.4 + 0.6*spC)
    var tau := 0.12 if state == "dun" else 0.28
    J.lean = ease(J.lean, T.lean, dt, tau); J.bank = ease(J.bank, bankT, dt, 0.35)
    J.flutter = ease(J.flutter, T.flutter, dt, 0.3); J.trail = ease(J.trail, T.trail, dt, 0.3)
    J.fade = ease(J.fade, T.fade, dt, 0.2); J.tint = ease(J.tint, T.tint, dt, 0.2); J.scale = ease(J.scale, T.scale, dt, 0.12)
    for i in 2:
        for k in ["shX","shZ","elX","elZ"]:
            J[k][i] = ease(J[k][i], T[k][i], dt, tau)
    _apply()
func _apply() -> void:
    skel.set_bone_pose_rotation(skel.find_bone("lean"), Quaternion.from_euler(Vector3(J.lean, 0, J.bank)))
    for i in 2:
        var sfx := ".L" if i == 0 else ".R"
        skel.set_bone_pose_rotation(skel.find_bone("shoulder"+sfx), Quaternion.from_euler(Vector3(J.shX[i], 0, J.shZ[i])))
        skel.set_bone_pose_rotation(skel.find_bone("elbow"+sfx), Quaternion.from_euler(Vector3(J.elX[i], 0, J.elZ[i])))
```
(Godot's `from_euler` uses YXZ order; for these joints with zero Y rotation the difference from XYZ is only in the X/Z composition — use `Basis.from_euler(v, EULER_ORDER_XYZ)` to match exactly. Mind the axis flip if Blender export rotates +Y-forward bones.)

**Robe** → vertex shader on the robe mesh (keeps CPU free), uniforms `flutter`, `trail`, `spC`, `time`; requires the robe's local space to match the original cone (centre at y 0.225, y0 ∈ [−0.235, 0.235]):
```glsl
uniform float flutter; uniform float trail_k; uniform float spC; global uniform float time_s;
void vertex() {
  vec3 b = VERTEX; float w = clamp((0.235 - b.y) / 0.47, 0.0, 1.0), ph = atan(b.z, b.x), t = time_s;
  float rip = sin(ph*3.0 + t*(9.0+8.0*spC) + b.y*6.0) * flutter * w*w + sin(ph*5.0 - t*(13.0+10.0*spC)) * flutter * 0.4 * w;
  VERTEX = vec3(b.x*(1.0+rip*0.8) + sin(t*3.1+ph)*flutter*0.3*w, b.y + rip*0.5*w, b.z*(1.0+rip*0.8) - trail_k*w*w);
}
```
(Trail is toward local −z = behind, since the figure faces +z; flip sign if your model faces −z.) Normals: either recompute analytically or accept the original's flat-ish toon look with `NORMAL` unchanged — the toon steps hide it mostly.

**Ribbons — GDScript verlet** (port of 12981–13005):
```gdscript
# VerletRibbon.gd — attach one per ribbon; world-space, top_level
extends MeshInstance3D
@export var n := 12
@export var half_w := 0.035        # × H
@export var seg_k := 1.0           # 0.7 for the hair tail
@export var anchor_local := Vector3(-0.04, 0.45, -0.1)
var p := PackedVector3Array(); var q := PackedVector3Array(); var inited := false; var last_h := 1.0
@onready var im := ImmediateMesh.new()
func _ready(): top_level = true; global_transform = Transform3D.IDENTITY; mesh = im; p.resize(n); q.resize(n)
func step(dt: float, t: float, lean_xf: Transform3D, H: float, dir: Vector3, vel: Vector3, spC: float, cam: Vector3) -> void:
    var sl := H * 0.075 * seg_k
    var upwash := (1.0 - spC) * H * 1.6
    var kd := 0.9; var g := -H * 0.6
    var a0 := lean_xf * anchor_local                       # anchor in world (lean.matrixWorld)
    if not inited or H / last_h > 1.5 or last_h / H > 1.5:
        for k in n:
            p[k] = a0 - dir * k * sl + Vector3(0, -k * sl * 0.3, 0); q[k] = p[k]
        inited = true
    last_h = H
    p[0] = a0
    for k in range(1, n):
        var w := Vector3(-vel.x * 0.55 + sin(t*7.0 + k*0.9 + anchor_local.x*40.0) * H * 0.9,
                         g + upwash + sin(t*5.0 + k*1.3) * H * 0.5,
                         -vel.z * 0.55 + cos(t*6.0 + k*1.1) * H * 0.9)
        var v := (p[k] - q[k]) * kd
        q[k] = p[k]
        p[k] = p[k] + v + w * dt * dt
    for it in 2:
        for k in range(1, n):
            var d := p[k] - p[k-1]; var l := maxf(d.length(), 1e-6)
            p[k] = p[k-1] + d * (sl / l)
    im.clear_surfaces(); im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
    for k in n:
        var tng := p[min(k+1, n-1)] - p[max(k-1, 0)]
        if tng.length_squared() < 1e-8: tng = dir
        var to_cam := (cam - p[k]).normalized()
        var side := tng.cross(to_cam).normalized()
        var w2 := half_w * H * (1.0 - 0.6 * float(k) / n)
        im.surface_set_normal(to_cam); im.surface_add_vertex(p[k] - side * w2)
        im.surface_set_normal(to_cam); im.surface_add_vertex(p[k] + side * w2)
    im.surface_end()
```
Material: same toon shader, `cull_disabled`, sash colour (0.3, 0.56, 0.5), hair (0.16, 0.17, 0.2). Run with a fixed dt (e.g. in `_physics_process` at 60 Hz) if frame rates vary widely — the original uses raw frame dt with no substeps. `anchor_local.x*40` gives the two sash ends different flutter phases.

### 11.6 Post-processing → Viewport MSAA + CompositorEffect (or a full-screen quad)
- **MSAA:** Project Settings `rendering/anti_aliasing/quality/msaa_3d = 4x` (matches `samples 4`, 13092). Leave TAA/FXAA off (they would smear the ink lines).
- **WorldEnvironment:** `background_mode = Color` or a simple sky (the paper/ink look comes from materials); `tonemap_mode = Linear` or `Filmic` with `tonemap_exposure 1` to approximate OutputPass (verify the three renderer's toneMapping, outside scope); `glow_enabled = false`; `fog_enabled = false` (aerial haze is done per material via `hazeMix`, which is camera-height relative — Godot's depth fog is not). If you want an engine-side approximation: `fog_mode = Exponential`, `fog_light_color = uHazeCol`, `fog_density` scaled by 1/camY each frame, plus `fog_height`/`fog_height_density` for the low-valley milkiness. `adjustment_enabled` contrast/saturation can stand in for the static part of GRADE, but the altitude-dependent S-curve and the regional cast need the shader.
- **Ink edge order trick:** the original multiplies the edge by veil transmittance (`edge *= c.a`). In Godot the exact equivalent is to apply the outline **before transparents are drawn**: a `CompositorEffect` with `effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE` — clouds then composite over the inked opaque image with their own alpha, which equals `mix(c, ink, edge·k)` attenuated by transmittance. Set `access_resolved_depth = true` (and `access_resolved_color = true`) so it works with MSAA.
- **Tilt-shift + grade:** a second CompositorEffect at `EFFECT_CALLBACK_TYPE_POST_TRANSPARENT` (two separable passes into a temp texture, then grade). Godot ≥ 4.3.

Compute shader for the ink edge (GLSL for RenderingDevice):
```glsl
#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8) in;
layout(rgba16f, set = 0, binding = 0) uniform image2D color_img;
layout(set = 0, binding = 1) uniform sampler2D depth_tex;
layout(push_constant, std430) uniform P { vec2 size; float near; float far; vec4 ink; float k; float pad0, pad1, pad2; } pc;
float lin(vec2 uv){ float d = texture(depth_tex, uv).r;                // Godot 4.3+: reversed-Z (1 = near)
  return pc.near * pc.far / (pc.near + d * (pc.far - pc.near)); }
void main(){
  ivec2 px = ivec2(gl_GlobalInvocationID.xy); if (px.x >= int(pc.size.x) || px.y >= int(pc.size.y)) return;
  vec2 uv = (vec2(px) + 0.5) / pc.size, o = 1.7 / pc.size;
  float z = lin(uv), zl = lin(uv - vec2(o.x,0)), zr = lin(uv + vec2(o.x,0)), zd = lin(uv - vec2(0,o.y)), zu = lin(uv + vec2(0,o.y));
  float far_ = max(max(zl, zr), max(zd, zu));
  float lap = (zl + zr + zd + zu - 4.0 * z) / z;
  float e = smoothstep(0.012, 0.05, lap) * smoothstep(0.008, 0.03, (far_ - z) / z);
  e *= 1.0 - smoothstep(pc.far * 0.55, pc.far * 0.9, z);
  vec4 c = imageLoad(color_img, px);
  imageStore(color_img, px, vec4(mix(c.rgb, pc.ink.rgb, e * pc.k), c.a));
}
```
GDScript skeleton:
```gdscript
@tool
extends CompositorEffect
class_name InkEdgeEffect
var rd: RenderingDevice; var shader: RID; var pipeline: RID
@export var ink := Color(0.24, 0.27, 0.31); @export var k := 0.7
@export var near := 5.0; @export var far := 100000.0   # set each frame from the camera script
func _init():
    effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE
    access_resolved_color = true; access_resolved_depth = true
    rd = RenderingServer.get_rendering_device()
    var src: RDShaderFile = load("res://post/ink_edge.glsl")
    shader = rd.shader_create_from_spirv(src.get_spirv()); pipeline = rd.compute_pipeline_create(shader)
func _render_callback(_t: int, data: RenderData) -> void:
    var bufs := data.get_render_scene_buffers() as RenderSceneBuffersRD
    var size := bufs.get_internal_size()
    for view in bufs.get_view_count():
        var color := bufs.get_color_layer(view); var depth := bufs.get_depth_layer(view)
        var u0 := RDUniform.new(); u0.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE; u0.binding = 0; u0.add_id(color)
        var samp := rd.sampler_create(RDSamplerState.new())
        var u1 := RDUniform.new(); u1.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE; u1.binding = 1; u1.add_id(samp); u1.add_id(depth)
        var set := UniformSetCacheRD.get_cache(shader, 0, [u0, u1])
        var pc := PackedFloat32Array([size.x, size.y, near, far, ink.r, ink.g, ink.b, 1.0, k, 0, 0, 0])
        var cl := rd.compute_list_begin()
        rd.compute_list_bind_compute_pipeline(cl, pipeline); rd.compute_list_bind_uniform_set(cl, set, 0)
        rd.compute_list_set_push_constant(cl, pc.to_byte_array(), pc.size() * 4)
        rd.compute_list_dispatch(cl, (size.x + 7) / 8, (size.y + 7) / 8, 1); rd.compute_list_end()
```
(Expose `near`, `far`, `k` as exported vars updated by a script each frame: `k = edgeInk·(1−map)·inkK`. Cache the sampler RID instead of creating it per frame. API names per Godot 4.3 Compositor docs — verify against your version, especially MSAA-resolved buffer access.)

Tilt-shift compute (per pass, H then V; run 1 or 2 pairs per §7.3): 9 taps, `offset = h * smoothstep(0, 0.5, max(|r - uv.y| - band, 0)) * 0.5` per tap, Gaussian weights from the three.js addon (0.051, 0.0918, 0.12245, 0.1531, 0.1633, mirrored). Needs a ping-pong texture: create with `bufs.create_texture(&"tilt", &"tmp", format, usage, ...)`.

**Simpler prototype path (no RenderingDevice):** a `MeshInstance3D` with a 2×2 QuadMesh in front of the camera, `extra_cull_margin` huge, shader:
```glsl
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 ink : source_color = vec3(0.24, 0.27, 0.31);
uniform float ink_k = 0.7, focus_y = 0.5, band = 0.225, blur_k = 0.32, grade_k = 0.0;
void vertex(){ POSITION = vec4(VERTEX.xy, 1.0, 1.0); }      // 4.3+ reversed-Z: z = 1 is the near plane
float lin(vec2 uv, mat4 ip){ float d = texture(depth_tex, uv).r; vec4 v = ip * vec4(uv * 2.0 - 1.0, d, 1.0); return -v.z / v.w; }
void fragment(){
  vec2 uv = SCREEN_UV, o = 1.7 / VIEWPORT_SIZE;
  float z = lin(uv, INV_PROJECTION_MATRIX);
  float zl = lin(uv - vec2(o.x,0), INV_PROJECTION_MATRIX), zr = lin(uv + vec2(o.x,0), INV_PROJECTION_MATRIX);
  float zd = lin(uv - vec2(0,o.y), INV_PROJECTION_MATRIX), zu = lin(uv + vec2(0,o.y), INV_PROJECTION_MATRIX);
  float lap = (zl + zr + zd + zu - 4.0 * z) / z, far_ = max(max(zl, zr), max(zd, zu));
  float e = smoothstep(0.012, 0.05, lap) * smoothstep(0.008, 0.03, (far_ - z) / z);
  // tilt-shift via screen mip chain (cheap approximation of the separable 9-tap blur)
  float bl = smoothstep(0.0, 0.5, max(abs(focus_y - (1.0 - uv.y)) - band, 0.0));
  vec3 c = textureLod(screen_tex, uv, bl * blur_k * 6.0).rgb;
  c = mix(c, ink, e * ink_k * (1.0 - bl));
  ALBEDO = c;
}
```
Caveats: Godot copies the screen texture once before the transparent pass, so in this path clouds drawn after the copy are not blurred and outlines will draw **over** clouds (no veil equivalent) — which is why the CompositorEffect route above is the faithful one. `uv.y` is flipped relative to three.js (`focus_y` measured from bottom).

GRADE: port the GLSL 1:1 into the last compute pass (or the quad shader). Inputs per frame: `uK = grade·(0.12 + 0.88·smoothstep(0.9mid, high, A))·(1−map)·wash`, region colour/weight from nearest sect (§7.4).

### 11.7 Ambience
- **Cranes:** MultiMesh of the crane ArrayMesh (built from the triangle list at 13346–13353; store `aWing` in `CUSTOM0.x` or UV.x and colour in `COLOR`), instance data `iOrbit`, `iMove` in `INSTANCE_CUSTOM` + a second packed into the instance transform (or a per-instance data texture read with `texelFetch(tex, ivec2(INSTANCE_ID, row), 0)`). Port CRANE_VS: orbit, bob, flap/glide, heading. Opaque, flat normal via `NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)))` in fragment.
- **Sword light:** GDScript quadratic Bézier + ImmediateMesh strip, `blend_add`; timer 7–13 s.
- **Halo:** QuadMesh `billboard_mode` enabled, 260 size, additive shader.
- **Motes:** either the wrapped-field shader on a `PRIMITIVE_POINTS` ArrayMesh with 180 vertices (positions unused; seed in `CUSTOM0` or `COLOR`), `render_mode unshaded, blend_add, depth_draw_never` and `POINT_SIZE` (enable `use_point_size` in the ShaderMaterial / write `POINT_SIZE` in vertex), or `GPUParticles3D` with `amount 180`, `lifetime` long, `local_coords = false`, emission box 1300×700×1300 attached to a node 700 ahead of the camera, `turbulence_enabled` for the drift — less exact (no wrap; particles respawn instead) but zero code. The shader port is exact:
```glsl
void vertex(){
  vec4 s = CUSTOM0; float ph = s.w * 6.2832;
  vec3 drift = vec3(sin(time_s*0.11 + ph)*40.0 + time_s*5.0, time_s*(4.0 + s.w*7.0), cos(time_s*0.09 + ph*1.3)*40.0);
  vec3 p = s.xyz * box + drift;
  p = mod(p - center + box * 0.5, box) - box * 0.5 + center;
  vec4 mv = VIEW_MATRIX * vec4(p, 1.0); float dist = -mv.z;
  ...  // twinkle, edge, alpha, colour exactly as 14027-14032
  POINT_SIZE = clamp(scale_k * (4.0 + 5.0 * fract(s.w * 7.3)) * 700.0 / max(dist, 1.0), 1.2, 9.0);
  POSITION = PROJECTION_MATRIX * mv;
}
```
### 11.8 Life movers → MultiMesh + route texture
- Build routes and resample to 256 in GDScript (`lifeResample`, `catmull`, `lifeChunks` are straightforward ports). Store in an `Image.create(256, rows, false, Image.FORMAT_RGBAF)` → `ImageTexture`; sample with `texelFetch(path_tex, ivec2(i, row), 0)` and a `filter_nearest` sampler.
- Per kind/group: `MultiMeshInstance3D`, mesh from the `lifeModel` triangle lists (export from Blender instead if you want nicer models — keep the `aPart` ids in vertex `CUSTOM0.x` or in vertex colour alpha, since the shader animates by part), `instance_count = n`, identity transforms; per-instance `iA` in `INSTANCE_CUSTOM`, `iB` and `iC` in a per-group data texture indexed by `INSTANCE_ID` (MultiMesh only has one custom vec4 + one colour; `COLOR` can hold `iC`, leaving only `iB` for the texture). Set `multimesh.custom_aabb` to the group bounds + pad (13921–13922) so Godot frustum-culls per group like the original.
- Shader: port LIFE_VS; `#define KIND` → separate shader files or a `uniform int kind` with `if` branches (uniform branches are cheap). `cameraPosition` → `CAMERA_POSITION_WORLD`. Pixel-size boost with `px_k = viewport_height / (2·tan(fov/2))`.
- Visibility LOD: GDScript per frame (§10.6) toggles `visible` by altitude ceiling and distance; or use `visibility_range_end = uFar·1.2` with `visibility_range_end_margin` for fade (`visibility_range_fade_mode = Self`) — note the shader already shrinks movers to zero size between `0.62·far` and `far`.
- Deer: CPU steering in GDScript (§10.7, n ≈ 28, O(n²) separation is fine), write `multimesh.set_instance_custom_data(i, Color(x, y, z, yaw))` and speed/distance into the data texture or `set_instance_color`. Or use NavigationAgent3D avoidance for separation (overkill).
- Carts/riders as Path3D + PathFollow3D would also work for a handful, but hundreds of walkers need the shader approach.

### 11.9 Altitude/mode summary table (for wiring a single `AltitudeBands` autoload)
| system | low (A < 950) | cruise (≈1650) | high (8000+) | map (`uMap`→1) |
|---|---|---|---|---|
| valley mist cards | ×0.6 | ×~1 | ×0.85 | 0 |
| near fly-through cards | on | on | 0 | 0 |
| edge wall | on | on | on | ×0.15 |
| cloud sea | opening r ≈ 0.3–0.95·A | opening | no opening above ~4300 | flattened, 0 |
| shafts | 0 | ~0.55 gain | full | 0 |
| cirrus | 0 | 0 | on when camY > ~3200 | 0 |
| tilt-shift k | 0.82 (2 pairs) | 0.32 | 0.064 | 0 |
| grade uK | 0.12·… | ~0.12 | 1.0 | 0 |
| walkers / deer | on | on | off above 3600 / 4200 | off |
| carts, riders / sampans | on | on | off above 6000 / 6500 | off |
| junks / flyboats | on | on | off above 14000 / 30000 | off |
| motes | on | fading (1300–2300) | off | off |
| figure / light size | ∝ A^0.92 | ∝ A^0.92 | ∝ A^0.92 | hidden |
