# D · Rendering of terrain, water and objects (index.html L4208–6835)

Source: `demo/index.html`. All line numbers refer to that file.
World unit = 丈 (zhang). Y up, +Z = south (L4214 comment "z points south"), Three.js right-handed, so the
axes carry over to Godot unchanged (Godot is also right-handed, Y up, -Z forward).

Outside this range but used by it (only quoted where needed):
- `GLSL_NOISE` L491–499 (hash12, hash22, vnoise, fbm3, fbm5)
- shared uniforms `U` L480–489: `uInkCol (0.24,0.27,0.31)`, `uMist (0.86,0.87,0.84)`, `uPaper (0.925,0.905,0.85)`,
  `uWind (0.9,0.25)`, `uAlt 1650`, `uInk/uWash/uMap/uFocus/uTime`
- `veil(mat)` L472–476: premultiplied-ish blending that writes "how much is hidden" into dest alpha so a separate
  **ink-edge post pass** (not in this range) does not draw outlines through clouds.
- `CONFIG.palette` L365–370, `CONFIG.sun` L373, `CONFIG.terrain` L332, `CONFIG.water` L353, `CONFIG.trees` L354,
  `CONFIG.look` L380 (`paper: 0.24` = the silk overlay strength; the silk/paper overlay, vignette and tilt-shift are
  a post-process outside this range — inside this range `uPaper` is only used by the intro reveal `introMix`).
- Water texture packing L1993–2009; grid jitter L1784–1789 (`WORLD.jq = 2*facetJitter*g`, jitter hashed back on
  demand by `gridX/gridZ`, so vertex jitter is a horizontal per-grid-point hash offset, not stored).

---------------------------------------------------------------------------------------------------------------------

## 0. Pipeline overview (what draws, in what order)

| Mesh | Builder | Material | renderOrder | Notes |
|---|---|---|---|---|
| Coarse range tiles (3 LOD each) | `buildTerrainTiles` L5050 | `terrainMaterial` (TERRAIN_VS/FS L4678–4791) | 1 | indexed, per-vertex colour + smooth normal, **no barycentrics**; ridges from heightmap curvature |
| Sect fine patches | `meshGrid` L4922 | `facetMaterial()` (FACET_VS/FS L4505–4675) | 1 | non-indexed FacetBuf, barycentric ink per edge |
| Floating-island undersides | `buildIslandBottoms` L5021 | same facet mat | 1 | tapered rings to a tip |
| Plains | `buildPlains` L5271 | PLAINS_VS/FS L5155–5270 | 2 | one big quad, `discard` where water |
| Earth banks (土崖) | `buildBanks` L5324 | BANK_VS/FS L5295–5323 | 3 | marching squares along SDF=0 |
| Sea/river/lake sheet | `buildWater` L5739 | WATER_VS/FS L5567–5737 | 4 | 220×180 subdivided plane |
| Mirror lagoon | `buildMirrors` L5800 | WATER_FS + `#define LAGOON` | 5 | + mirrored copies (order 0) + sky backdrop (order 0) |
| Upland lakes | `buildUplands` L5909 | UPLAND_VS/FS L5875–5901 | 3 | transparent, polygonOffset |
| Props (city, pillar, spires, spirit tree) | `buildProps` L6769 | facetMaterial variants | 1 | |
| Spirit halo | `buildSpiritHalo` L6172 | HALO_VS/FS L6169–6171 | 6 | additive ellipsoid |
| Trees (9 kinds, instanced) | `buildTrees` L6326 | TREE_VS/FS L6228–6279 | 1 | InstancedBufferGeometry per 2600-丈 chunk × kind |
| Roads | `buildRoads` L6409 | ROAD_VS/FS L6379–6408 | 3 | ribbons, alpha edges |
| Streams | `buildStreams` L6472 | STREAM_VS/FS L6442–6471 | 3 | ribbons, flow foam |
| Villages/roadside/bridges | `buildSettlements` L6563 | facetMaterial({lift:false}) | 1 | uses `archKit` (06b, outside range) |
| Waterfalls | `buildFalls` L6596 | FALL_VS/FS L6579–6595 | 6 | transparent, DoubleSide |
| Formation rings | `buildFormations` L6633 | FORMATION_FS L6618 | 7 | additive plane |

Every land/water material **spreads the shared uniform object `LU`** (L4227–4250) so one slider updates every
material (comment L4226). `LAND.mats` collects them (L4673, 4789, …). `updateLand(cam)` L5533–5556 writes the
per-frame values. Every material is a raw `THREE.ShaderMaterial` — **no Three.js lights are used for any of this**;
all lighting is analytic in the fragment shader from `uSunDir` and a baked sun texture.

Entry: `buildLand(scene)` L5523–5532 = `buildLandTextures()` → `bakeSun()` → `buildMountains()` → `buildPlains()` →
`buildBanks()`. Props: `buildProps(scene)` L6769–6820 (the "all of it" assembly; header at L6648).

---------------------------------------------------------------------------------------------------------------------

## 1. Art direction recipe (青绿山水 look)

### 1.1 Palette

`CONFIG.palette` (L366–369), converted to `PAL` (0..1 rgb arrays) by `refreshPalette()` L4217–4219:

| key | hex | role |
|---|---|---|
| ink | `#363d41` | (palette ink; shaders use `U.uInkCol = (0.24,0.27,0.31)` L484) |
| azurite 石青 | `#3f5866` | high tops |
| azuriteLit | `#5d7f8d` | high tops facing up (ny>0.74) |
| malachite 石绿 | `#6c9b97` | flanks |
| malachiteDeep | `#527f7b` | flanks variation / wet valleys |
| ochre 赭石 | `#a88969` | foot |
| ochreDeep | `#8b6c4f` | bare low rock, bank deep earth |
| plains | `#b6bd99` | plain base |
| plainsGreen | `#9db08a` | plain green / mountain foot |
| waterLight | `#a8d4cd` | shallow water |
| water | `#73b1bc` | mid water |
| waterDeep | `#3f7c97` | deep water |
| mist | `#e6e2dd` | |
| pine/tree/maple/ginkgo/frostPine/bamboo | `#4e6d63 #6f9a86 #a65a42 #b39560 #8fa8a6 #6f9f88` | |
| snow | `#e9eeee` | |
| rockRed / rockPale | `#b45c3f` / `#cdc8b7` | 火云峰 / 白凤峰 tint (`rockTint` L4854) |

Other fixed colours inside the range:
- Haze: `uHazeCol (0.86,0.88,0.86)` L4228 (overwritten each frame by `U.uMist` L5547), `uHazeWarm (0.93,0.88,0.80)` L4245.
- Toon tints: `uShadeTint (0.8,0.9,1.1)` (cool shadows), `uLitTint (1.05,1.0,0.92)` (warm light) L4240.
- Glow (escape light): `uGlowCol (0.25,0.85,0.69)` L4231.
- Sect stones `SITE_LOOK` L4863–4871 (`ice/jade/gold/phoenix/earth/water`, each rock / rockDeep / top / cap hex).
- Plains: `uPlainWarm #cfc4a6`, `uFoot #97a98c`, `uField #b9b48f`, `uSwamp #8fa287`, crops `uRice #82ae58`,
  `uYoung #9bc05c`, `uWheat #c8b55e`, `uRape #d6c24a`, `uFallow #a38f62`, `uYard #d3c7a8` (L5281–5284).
- Banks: `uEarth #b4987a`, `uEarthDeep = ochreDeep`, `uWet #5e5a4c` (L5368).
- Water: `uSky #eef1ec`, `uLineCol #3f5a62` (L5752); foam whites `vec3(0.95,0.96,0.93)` etc.
- Streams: `uWaterCol #9fc3c6`, `uRiverCol #7db4bc`, `uFoam #eef4f2` (L6498). Upland: `uFoam #eef4f2` (L5939).
- Roads: `uRoad #b59b72`, `uRoadEdge #87714f` (L6433).
- Architecture `AC` L5951–5955 (wall `[0.9,0.88,0.82]`, red `[0.62,0.35,0.29]`, pillar `[0.55,0.3,0.25]`,
  roof `[0.3,0.38,0.43]`, roofJade `[0.36,0.55,0.52]`, roofGrey `[0.4,0.43,0.45]`, roofDark `[0.27,0.31,0.34]`,
  stone `[0.87,0.85,0.78]`, stoneSide `[0.75,0.72,0.64]`, trunk `[0.38,0.3,0.24]`, house `[0.83,0.8,0.72]`, …).
- `VILLAGE_LOOK` L6507–6508, `THATCH [0.62,0.53,0.38]` L6509.
- Tree colour slots `TREE_COLS` L6325 (16 entries, see §5.6).

**Colour space note**: these are raw `ShaderMaterial`s writing `gl_FragColor` with no colorspace chunk, so all
maths happens on the hex values as if they were display (sRGB) values. Reproduce that in Godot (§6.1).

### 1.2 Sun

`updateSunDir()` L4212–4215:
```js
SUN.set(sin(az)*cos(el), sin(el), -cos(az)*cos(el))   // azimuth clockwise from north, z = south
```
Default `azimuth 140, elevation 40` (L373): sun in the south-east, behind-right of a camera flying north. Comment
L4209–4210: south and east slopes lit, west slopes in shade, shadows fall north-west.

### 1.3 Three flat tones (toon) — GLSL_LIGHT L4277–4307

```glsl
// three flat tones from a facet's normal: 0 shadow, 0.5 half-lit, 1 sun
float tones(vec3 N){ float nl = dot(N, uSunDir);
  return mix(0.0, mix(0.5, 1.0, smoothstep(0.5, 0.56, nl)), smoothstep(0.1, 0.16, nl)); }
// same on a smooth surface, edges washed soft (没骨 rather than 界画)
float softTones(float nl){ return mix(0.0, mix(0.5, 1.0, smoothstep(0.4, 0.66, nl)), smoothstep(0.0, 0.26, nl)); }
vec3 sunAt(vec2 xz){ return texture2D(tSun, (xz - uSunRect.xy) / uSunRect.zw).rgb; }   // r ground shadow, g cloud-sea shadow, b sky openness
float castLight(float s){ return mix(1.0, smoothstep(0.36, 0.64, s), uToon.w); }
vec3 toneCol(vec3 base, float t){
  vec3 sh = base * uToon.x * uShadeTint, mid = base * uToon.y, lit = base * uToon.z * uLitTint;
  return t < 0.5 ? mix(sh, mid, t * 2.0) : mix(mid, lit, t * 2.0 - 1.0);
}
vec3 facetLight(vec3 base, vec3 N, vec3 wp){
  vec3 s = sunAt(wp.xz);
  float t = min(tones(N), castLight(s.r));
  return toneCol(base, t) * mix(1.0, mix(0.84, 1.0, s.b), uAO) + vec3(0.016, 0.02, 0.018) * N.y;
}
```
`uToon` is set every frame in `updateLand` L5551–5552:
`uToon = (1 - 0.44c, 1 - 0.16c, 1 + 0.1c, sun.shadow)` with `contrast c = 1`, `shadow = 0.85` →
**(0.56, 0.84, 1.10, 0.85)** (same as the default L4240). `uAO = sun.ao = 0.5`.
So: shadow = 0.56·base·(0.8,0.9,1.1); half = 0.84·base; sun = 1.1·base·(1.05,1,0.92). Plus a tiny sky fill
`+ (0.016,0.02,0.018)·N.y`. Cast shadow can only *lower* the tone (`min`). AO: valley darkening up to −16 %·uAO.

Flat ground (plains/roads/streams/uplands) uses `tones(vec3(0,1,0))` (≈ half-lit→lit, dot = sin 40° = 0.643 → 1.0)
scaled by `mix(0.25, 1.0, castLight(s.r))`, then **divides by `uToon.z·0.96`** so flat lit ground = its own base
colour (L5257–5258, L6401–6402, L6462–6463, L5893–5894). The terrain shader does the same divide for low
ground (`plainK`, L4760–4763) so hill feet don't form a bright shelf against the plain.

### 1.4 Facet vs smooth blending (the "painted masses" trick)

Fragment computes the true facet normal from derivatives and blends toward the vertex's smooth heightfield normal:
```glsl
vec3 Nf = normalize(cross(dFdx(vWp), dFdy(vWp)));            // L4614 / L4705
float soft = max(uSoft, small);                               // uSoft = terrain.soft = 0.85
vec3 N = normalize(mix(Nf, normalize(vN), soft));
float t = mix(tones(Nf), softTones(dot(N, uSunDir)), soft);   // L4622 / L4712
t = min(t, castLight(s.r));
```
`small` (facets only a few px): facet `smoothstep(0.07,0.16,max(fwidth(vBary)))` L4616; terrain
`smoothstep(16,40, length(fwidth(vWp.xz)))` L4707. Buildings carry no smooth normal (`aN` = 0 → `hasN` false,
L4619) so they stay crisp flat-shaded.

### 1.5 Vertex colour ramp — `facetColor(h, ny, r, x, z)` L4876–4920 (CPU, per vertex)

"青绿 colouring after 千里江山图: 赭石 at the foot, 石绿 up the flanks, 石青 on the high tops, snow above the snow line"
(L4873–4875). With `n = simplex(x·0.0009)`, `n2 = simplex(x·0.0021)`, `t = h + (n-0.5)·60 + (r-0.5)·10`,
`steep = smoothstep(0.62, 0.32, ny)`:
```js
c = mix(plainsGreen, ochre, smoothstep(4, 26, t) * 0.75);                                  // foot
c = mix(c, mix(malachite, malachiteDeep, smoothstep(-0.2,0.6,n2)*0.7), smoothstep(40,150, t + 40*(1-steep)));  // flanks
c = mix(c, mix(ochreDeep, ochre, 0.5), steep * (1 - smoothstep(60,220,t)) * 0.55);        // bare low sheer rock
c = mix(c, ny>0.74 && n2>0 ? azuriteLit : azurite, smoothstep(330, 560, t + 50*n2));       // tops
// drainage (wetAt): valleys hold green, crests go blue sooner
if (h > 8) { c = mix(c, mix(malachiteDeep, plainsGreen, .35), wet*0.42*(1-smoothstep(380,600,h)));
             c = mix(c, ny>0.7 ? azuriteLit : azurite, (1-wet)*smoothstep(260,520,t)*0.24); }
// sect stone (siteLookAt, SITE_LOOK) with sin strata bands, moss caps above the cloud, damp foot band   L4890–4910
// landform colour hook (LF.color) L4912–4913; named-peak tint L4914–4915
snow = smoothstep(snl-30, snl+30, t + 70*(ny-0.55) + 40*(n2-0.1)) * smoothstep(0.3, 0.52, ny);   // snowLineAt L4846
c = mix(c, ny>0.7 ? snow : mix(snow, azuriteLit, .25), snow);
j = 0.985 + 0.03*((r*7.31)%1);   // ±1.5% per-vertex brightness jitter, "no facet confetti"
```
Snow line: `CONFIG.terrain.snowLine 820` minus 60·regions.snow near 古剑门, minus up to 160 in the winter country;
landforms override (L4846–4852).

### 1.6 Ink

Three different ink mechanisms:

1. **Crease ink via barycentrics** (FacetBuf meshes only — sect patches, props, buildings), FACET_FS L4647–4650:
```glsl
vec3 fw = fwidth(vBary);
vec3 e = smoothstep(fw * 0.25, fw * uLineW, vBary);           // uLineW default 1.05 (facetMaterial L4667)
float line = max(max((1.0-e.x)*vCrease.x, (1.0-e.y)*vCrease.y), (1.0-e.z)*vCrease.z)
           * uCreaseInk * mix(1.0, 0.32, soft);               // uCreaseInk = terrain.creaseInk 0.75
line *= 1.0 - smoothstep(0.075, 0.17, max(fw.x, max(fw.y, fw.z)));   // tiny facets: no strokes, just colour
```
   Constant screen width (≈1 px band ×uLineW) because the threshold is in units of `fwidth`. `vCrease.i` = ink
   weight of the edge **opposite vertex i** (bary component i → 0 on that edge).
2. **Foot ink** where slope meets plain (y≈0), both shaders, L4652–4654 / L4774–4777:
```glsl
float fy = max(fwidth(vWp.y), 1e-3);
float foot = (1.0 - smoothstep(fy*0.9, fy*2.4, vWp.y)) * uFootInk * step(-0.2, vWp.y);   // uFootInk 0.8
foot *= smoothstep(40.0, 110.0, texture2D(tLand, uv).g);   // terrain: only round real mountains (facet: 3..24)
col = mix(col, uInkCol, foot * 0.82);
```
3. **Ridge light/dark from heightmap curvature** (coarse terrain; replaces mesh crease ink there), L4766–4772:
```glsl
vec2 e = vec2(64.0) / uRect.zw;                            // 64 丈 stencil
float hc  = texture2D(tLand, uv).r;
float lap = h(+x) + h(-x) + h(+z) + h(-z) - 4.0*hc;
float crest = smoothstep(12.0, 38.0, -lap) * smoothstep(40.0, 150.0, hc) * (1.0 - smoothstep(60.0, 140.0, px));
col = mix(col, col*1.1 + vec3(0.035,0.03,0.02), crest * smoothstep(0.45,0.8,t) * 0.55 * uRidgeLight);  // lit crest brightens
col = mix(col, mix(col, uInkCol, 0.35), crest * (1.0 - smoothstep(0.2,0.55,t)) * 0.5 * uRidgeLight);     // shaded crest inks
```
4. Shore ink lines: plains `shore = 1 - smoothstep(px*0.8, px*2.2, -sd)` → `mix(c, uInkCol, shore*0.75)` (L5250, 5263);
   bank top line (L5318–5319); upland edge (L5891); fall edges (L6591–6592); water ripple lines (§4.1).
5. Separate post-process ink edge pass (outside range; see `veil` L470–476).

### 1.7 Brush textures (皴, strata, grain)

- **披麻/斧劈 cun strokes** `cun(wp, N)` L4528–4536 (dup L4695–4703): dry strokes along the fall line:
```glsl
vec2 dh = N.xz; float sl = length(dh); if (sl < 0.12) return 0.0;
dh /= sl; vec2 tg = vec2(-dh.y, dh.x);
vec2 p = vec2(dot(wp.xz, tg) * 0.085, (wp.y + dot(wp.xz, dh) * 0.35) * 0.015);   // narrow across, long down-slope
float n = vnoise(p) * 0.62 + vnoise(p * vec2(2.6, 1.9) + 5.3) * 0.38;
float fade = 1.0 - smoothstep(0.3, 0.8, fwidth(p.x));
return smoothstep(0.56, 0.84, n) * smoothstep(0.12, 0.45, sl) * fade;
// applied: col *= 1.0 - cun(...) * (0.17 - 0.11 * t) * uCun;    (darker in shadow)  L4645 / L4765
```
- **岩层 strata** on steep faces (Ns.y<0.72), L4632–4640 / L4719–4725: `sb = sin(y·0.085 + warp)`; dark seams
  `×(0.78,0.76,0.74)` and pale ledges `×(1.14,1.12,1.08)`, faded by `fwidth(y)`.
- **groundDetail** L4350–4378: five painted tiling textures `tDetail0..4` (grass, dry grass, snow, cliff, mud) at
  150 丈/tile + 610 丈 second octave, used as **luminance only** relative to their mean (`uDetailMean`), amplified
  ×2.6, clamped 0.5–1.7; 22–42 % hue transfer. Fades out where `px` >14–40 丈/px.
- Ground variety mottles (terrain L4728–4736), 点苔 dots (plains L5233–5236), wood canopy floor `woodCol` L4309–4318.
- **Biome ground** L4398–4425 (Ghibli/“Meadow pack” greens `gLight (0.5,0.64,0.25)`, `gMid (0.36,0.55,0.21)`,
  `gDeep (0.25,0.45,0.22)`, steppe, sand `(0.84,0.77,0.6)`, marsh mud), **flowerField** dabs L4430–4453, **marshGround**
  L4464–4501 (own little water shader with Fresnel/ripple for marsh pools), **seasonGround** snow/autumn L4381–4392,
  terraces 梯田 L4743–4756.

### 1.8 Atmosphere — `hazeMix` L4321–4335

```glsl
float d = length(wp - uCamPos);
float k = smoothstep(uCamPos.y*1.2, uCamPos.y*3.4, d) * uHaze * 0.62 * (1.0 + 0.8*uAltK);   // distance haze scaled by altitude
float low = exp(-max(wp.y,0.0) / (240.0 + 160.0*uAltK));                                    // height fog: low ground milky
float v = uValley * low * smoothstep(uCamPos.y*0.4, uCamPos.y*2.4, d) * (0.3 + 0.7*uAltK);
k = 1.0 - (1.0-k) * (1.0 - v*0.6);
vec3 hz = mix(uHazeCol, uHazeWarm, uCine);
// + per-sect air tints (uReg) and 6 landform air discs (uLandAir / uLandAirCol)
return mix(c, hz, clamp(k, 0.0, 1.0));
```
`uHaze = look.haze 0.5`, `uValley = cinema.valleyMist 0.8`, `uAltK = smoothstep(zoom.mid, zoom.high, alt)`,
`uCine = warmth·altK` (L5549–5550). The fog distances scale with camera height, so it works from any altitude.
Lifting the camera also cools/deepens land (`×(0.88,0.96,0.86)·uAltK·0.55`, L4761, L5254).

Edge of world: plains/water mix to `uMist` inside `uEdge = look.edgeFade 0.05` of the rect, noise-broken (L5267–5268, L5724–5725).

### 1.9 Intro reveal 先勾后染 — `introMix` L4255–4276

Ink lines appear radially from `uFocus` (radius `uIntroScale 22000`, fbm-wobbled), then a mid-tone ink wash, then
colour blooms from three seeds `uSeeds[i] = (x, z, radius, delay)` with a dark "wet front" ring
(`exp(-((prog-d)/0.035)^2)`). Inputs per material: `line` (ink mask) and `tone` (`(1-tones(N))·0.32+0.06`).
Before the wash the scene is `mix(uPaper, uInkCol, max(line·inkR, tone·toneR))` — i.e. the paper/silk colour with
ink drawing. After `uWash >= 0.999` the function is a no-op.

### 1.10 Other per-ground effects

- `lightOnGround` L4337–4342: escape-light (遁光) blob shadow `uShadowP` and jade glow `uGlowP` projected on ground.
- Cloud shadows: `col *= 1 - uShadowK * tShadow(uv + uWind·uTime·4e-6).r` (`uShadowK = clouds.shadows 0.16`) L4764, L5260–5261.
- `uMap` flattens everything to the 舆图 map view (`p.y *= 1-uMap` in every VS).
- `uRelief` scales positive heights (`p.y>0 ? p.y*uRelief : p.y`), L4514, L4684.

---------------------------------------------------------------------------------------------------------------------

## 2. Mesh generation

### 2.1 FacetBuf (L4793–4841) — growable, non-indexed triangle soup

Storage per **vertex** (3 components each):

| array | type | attribute | normalized | meaning |
|---|---|---|---|---|
| `P` | Float32 | `position` | – | xyz |
| `B` | Uint8 | `bary` | yes → 0/1 | (255,0,0),(0,255,0),(0,0,255) per corner (L4808) |
| `C` | Uint8 | `aCol` | yes | rgb 0..1 |
| `K` | Uint8 | `crease` | yes | ink weight of edge opposite a, b, c; **same for all 3 verts** of the tri (L4811–4812) |
| `N` | Int8 | `aN` | yes (−1..1, ×127) | smooth normal (0 = none → crisp) via `normals(na,nb,nc)` L4797 |
| `M` | Int8 (lazy) | `aMat` | yes | `(matId, tangent.x, tangent.z)`; matId decoded `floor(vMat.x*127+0.5)` L4625 |

Capacity default `3*4096` vertices; `grow()` doubles (L4795). API:
- `tri(a, b, c, col, wa, wb, wc, up)` L4799–4821. `up` = a direction the face should look toward; if
  `cross(b-a, c-a)·up < 0` swap b/c **and** swap wb/wc, set `this.flipped` (L4800–4804). If `this.mat` is set,
  stores pattern id + horizontal face tangent (`(-nz, nx)/|n.xz|` when the face is not floor-like, `hl>0.3`) L4813–4819.
- `triC(a,b,c, ca,cb,cc, …)` L4823–4827: per-corner colour (respects `flipped`).
- `quad(a,b,c,d,col,w=0.9,up)` L4829: `tri(a,b,c,w,0,w)` + `tri(a,c,d,w,w,0)` → the diagonal carries **no ink**.
- `geometry(a,b)` L4830–4840: slices into a `BufferGeometry` (a range = one sect's share).

FACET_VS L4505–4519: passes `aN`, `bary`, `crease`, `aCol`, world pos; rotates `aMat.yz` tangent by `mat3(modelMatrix)`;
`uLift` toggles relief scaling (props use `lift:false`).

`facetMaterial(opt)` L4663–4675: `{lift, lineW, glow, polygonOffset}`.

### 2.2 Building surface patterns — `archPattern(base, mat, tg, wp)` L4541–4612

Planar UV in world units: wall/roof `uv = (dot(wp.xz, tg/|tg|), wp.y)`, floor `uv = wp.xz`. Each pattern
analytically anti-aliased with `px = max |d(u,v)|` and fades to its average colour when a cell is a few pixels:
1 格扇 lattice (1.1 cell, stile every 4, rail every 6; paper `(0.82,0.78,0.68)`), 2 roof tiles (1.4 rolls, 1.2
courses), 3 paving (5 丈 slabs), 4 ashlar (2.2 courses, 4–6 long), 5 彩画 (blue `(0.2,0.36,0.52)`, green
`(0.22,0.46,0.38)`, gold `(0.88,0.72,0.36)` bands per 9 丈), 6 plaster (noise), 7 直棂窗 bars (1.25), 8 cast bronze
panels (5.2×3.6, bevel, studs), 9 门钉 gilt studs (2.4 grid). → In Godot: same code in fragment (or bake to textures
in Blender, see §6.9).

### 2.3 Coarse terrain tiles — `buildTerrainTiles(scene, skip)` L5047–5129

- `TERRAIN = { T: 96 cells per tile, level: [5200, 10500] }` L5049. Grid spacing `WORLD.g` (`terrain.grid` 40 丈).
- Height mapping `Y(k) = H>0 ? H : (H<-5 ? H : SINK=-1.5)` L5055: zero-height points pushed 1.5 below the plain so
  the plain (at y=0) cuts a clean outline at each foot; underwater ground (< −5) kept.
- A cell is active if any of its 4 corners has H>0 (L5061–5066); cells covered by a sect's fine patch are skipped
  (`patch=true`, tile never LODs).
- **One vertex buffer per tile** (`(cw+1)(ch+1)` + skirt ring) with `position` (Float32), `aCol` (Uint8 norm, from
  `facetColor` with smooth slope `1/l`), `aN` (Int8 norm smooth normal by central differences, L5079–5081).
  Positions use `gridX(k)/gridZ(k)` → **includes the hashed horizontal jitter** (facetJitter 0.32 → ±0.32 g).
- **Three index buffers** for strides `st = 1, 2, 4` (L5095–5124), all sharing the vertex attributes. Per
  (st×st) super-cell choose the shorter-height-difference diagonal (L5103–5104). Uint16 or Uint32 index.
- **Skirt**: ring of duplicated edge vertices at `y - SK` (`SK = 70`), colour ×0.8 (L5085–5090); skirt quads emitted
  per LOD at that LOD's spacing wherever the edge cell is active (L5106–5115).
- Bounding sphere set by hand (L5120). Level meshes missing → reuse coarser (L5125).
- `updateTerrainLOD(cam)` L5131–5140: `d = |cam - tileCentre| - 0.6·rad`; `lv = d<5200·lod ? 0 : d<10500·lod ? 1 : 2`;
  only that mesh visible; hidden entirely on the map (`uMap≥0.999`).

### 2.4 Sect fine patches — `meshGrid(G, scene, mat, tile, seed)` L4922–5019

FacetBuf facets with real ink. Steps:
1. Per cell pick diagonal (shorter |ΔY|), compute 2 face normals (forced y-up) L4936–4946. Floating-island `cut`:
   cells below `cut` dropped; their undersides built by `buildIslandBottoms` (L5021–5046; 18-gon rings at 1, 0.8,
   0.5 radius → tip at depth 1.5–2× mean radius).
2. `owner(c, side)` + `nb(i,j,side)` find the neighbouring face across each side (UP if neighbour is plain) L4948–4957.
3. **Crease weight** per edge, L4958–4969:
```js
tone = (n) => d=n·SUN; d>0.53 ? 2 : d>0.13 ? 1 : 0;
crease(na, nb, cen, mid, hEdge):
  if (nb === UP) return 0;
  ang = acos(na·nb); convex = (mid-cen)·nb > 0;               // ridge if far face bends away
  w = smoothstep(0.36, 0.85, ang) * (convex ? 1 : 0.55);      // ~21°..49°, valleys at 55%
  if (tone(na) != tone(nb)) w = max(w, |Δtone|==2 ? 0.75 : 0.38);   // light→shadow boundaries are inked
  return w * smoothstep(10, 60, hEdge);                        // little ink on low hills
```
4. Per-vertex colour cached `VC` (flows across facets, `triC`), smooth normal `sN` per vertex (`normals()`), flipped
   order if `buf.flipped` (L5008–5009).
5. Tiled into meshes of `tile` cells (patches use `1e9` → one mesh) L4984–5017.

### 2.5 Plains — L5154–5292

One `PlaneGeometry` covering world rect + 9000 margin, **no subdivision**, at y=0 (L5273–5275). Fragment samples
`tWater`; `sd = (R*255-128)*2` (丈 to shore, + in water); `if (sd > 0.0) discard;` (L5170–5172) → the hole where
water and banks show through. All colour is procedural (fbm patches, gentle fake relief normal from fbm lit by sun
L5178–5180, foot green from blurred heights `tLand.g`, places `uPlaces[10]` (x,z,r,type: 1 city, 2 swamp, 3 spirit
tree basin) L5187–5193, field patchwork from `tGround` (g farm cover, a field angle, b yards, r woods) L5197–5231
with rows offset by 37 丈 + hash so it never reads as a chessboard, 96×56 丈 fields, hedges; shore bands: lush
green 14–70 丈, pale sand lip 2–18 丈, ink shore line).

### 2.6 Earth banks 土崖 — `buildBanks` L5324–5378

Marching squares over the water SDF (`WORLD.sd / SDQ`, SDQ=8 → 1/8 丈 per step, L1976), all 16 cases incl.
saddle disambiguation by centre average (L5345–5361). For each contour segment `seg()` L5331–5342: skip where a
mountain runs into the water (`hAt(mid)>40 && ends>25`); set back `OUT=2.5` 丈 under the plain edge against the
SDF gradient; emit a vertical quad from y=0 to `bottom = -(max(seaDepth 20, depth 7)+4) = -24`; normal = gradient
(faces the water); winding chosen to face water. BANK_FS L5298–5323: depth ratio `k = y / waterLevel`, earth→deep
earth, two wavering dark seams at 36 % and 70 %, wet band near water `uWet`, lit with `tones(N + (0,0.35,0))`,
ink line along the top (`-y < 2 px`).

---------------------------------------------------------------------------------------------------------------------

## 3. Textures & the sun bake

### 3.1 `buildLandTextures()` L5381–5476

| Texture | Format | Size | Channels | Built |
|---|---|---|---|---|
| `tWater` | RGBA8 UNorm, Linear, clamp | `maskW×maskH` (`water.maskSize 4608`) | R signed shore distance: 128 = shore, **2 丈/step**, + = water; G,B flow / sea drift `(v-128)/127` (rivers get downstream flow from `WORLD.flowData`); A sea factor 0..1 | L1993–2009, L5383–5385 |
| `tLand` | **RG half float**, Linear | `1.5·nx × 1.5·nz` (1.5 texels per grid cell, texel centres) | R height (incl. sect fine patches and 天柱山 pillar `(P.h+120)` disc), G height box-blurred r=5 cells (11-tap separable box, ≈±200 丈) | L5386–5425 (custom float→half `toH` L5402) |
| `tShadow` | Canvas RGBA8 | 1024 × (1024·H/W) | R: soft radial blots (alpha 0.45→0.2→0) under cloud clusters of kind 2, offset **down-sun** by `(SUN.xz/SUN.y)·height` | L5427–5438 |
| `tSun` | RGBA8 render target | `nx × nz` (one texel per grid point) | R ground cast-shadow, G cloud-sea-height shadow, B sky openness (AO) | `bakeSun` L5501–5522 |
| `tGround` | RGBA8 | `WORLD.ground` | r wood, g farm, b yard, a field angle/π | L5443 |
| `tBiome` / `tBiome2` | RGBA8 | | r flowers, g sand, b marsh, a lushness / rgb flower colour + a drift | L5448–5455 |
| `tSeason` | RGBA8 | | r winter, g autumn, b spirit ground, a arid steppe | L5463–5467 |
| `tMarsh` | RGBA8 mipmapped | `M.n²` | r marsh SDF (+water, ½丈/step), g reeds, b marsh mask | L5457–5461 |
| `tDetail0..4` | painted images (loaded elsewhere) | 150 丈/tile | luminance grain | LU L4248 |

`uRect = uSunRect = (x0, z0, width, depth)` of the world (L5439–5440); all ground lookups are
`(xz - rect.xy)/rect.zw`.

### 3.2 Sun bake — SUN_BAKE_FS L5478–5500 (GPU, full-screen quad into `nx×nz` RT)

```glsl
float Hh(vec2 xz){ return texture2D(tLand, (xz - uRect.xy) / uRect.zw).r; }
void main(){
  vec2 xz = uRect.xy + vUv * uRect.zw;
  float h0 = max(Hh(xz), 0.0);
  float cy = uCloudY;                                      // cloud sea 175; a sect's own sea stands higher (uSites[i].w)
  for (int i = 0; i < NSITES; i++) cy = max(cy, uCloudY + uSites[i].w * (1.0 - smoothstep(uSites[i].z*0.7, uSites[i].z*1.08, length(xz - uSites[i].xy))));
  vec2 d = normalize(uSun.xz); float tanE = uSun.y / max(length(uSun.xz), 1e-3);
  float s0 = 1.0, s1 = 1.0, t = 20.0, st = 20.0;
  for (int i = 0; i < 120; i++) {
    float hp = Hh(xz + d * t), pen = t * 0.03 + 5.0;       // penumbra widens with distance
    s0 = min(s0, clamp((h0 + 4.0 + t*tanE - hp) / pen + 0.5, 0.0, 1.0));      // ground
    s1 = min(s1, clamp((max(h0, cy) + t*tanE - hp) / pen + 0.5, 0.0, 1.0));   // cloud-sea surface
    t += st; st *= 1.028;                                   // geometric steps: 120 steps reach ≈19 000 丈
    if (min(h0 + 4.0, cy) + t*tanE > 1800.0) break;         // ray above every peak
  }
  float occ = 0.0;                                          // valley openness: 8 dirs × radii 140/280/420
  for (int k = 0; k < 8; k++) { float a = float(k)*0.785398 + 0.3; vec2 dd = vec2(cos(a), sin(a));
    for (int r = 1; r <= 3; r++) { float rr = float(r)*140.0; occ += clamp((Hh(xz + dd*rr) - h0) / rr, 0.0, 1.2); } }
  gl_FragColor = vec4(s0, s1, clamp(1.0 - occ / 24.0, 0.0, 1.0), 1.0);
}
```
- RT: `UnsignedByte RGBA, Linear, no depth, no mips` (L5506–5507). Ortho quad `gl_Position = vec4(position.xy,0,1)`.
- `uSites[NSITES=6]` = (x, z, R, sectCloudY − cloudSea.height) (L5511).
- Re-baked whenever sun azimuth/elevation or cloud-sea height changes (L5554–5555).
- Consumption: `castLight(s.r)` → `smoothstep(0.36,0.64)` softened shadow edge, strength `uToon.w 0.85`; `s.b`
  → AO `mix(1, mix(0.84,1,s.b), uAO)`; `s.g` used by the cloud sea (outside range).

---------------------------------------------------------------------------------------------------------------------

## 4. Water

### 4.1 Main water sheet (05) — WATER_VS/FS L5567–5737, `buildWater` L5739–5762

Design note L5558–5566: borrowed from WaterThreeJS (depth gradient `mix(shallow,deep,1-exp(-depth·falloff))`,
procedural Gerstner sum with hashed dirs, freq ×1.19 / amp ×0.82 per octave, dispersion √(g·k), fold Jacobian,
Schlick F0=0.02, shoreline band, wind-stretched streaks, distance-faded detail normals). Changed: "depth" = **distance
from the shore** (SDF) — there's no seabed; flat 花青 colour steps; foam → ink ripple lines; waves only tilt shading,
**no displacement, no refraction, caustics, underwater or light shafts**.

Mesh: `PlaneGeometry(world+18000, 220×180 segs)`. VS sets `y = -mix(depth 7, seaDepth 20, sea)` via `textureLod(tWater)`
(L5571–5573): inland water 7 below the plain, sea 20 below. renderOrder 4, opaque.

Uniforms (L5746–5755): `uWaterLight/uWater/uWaterDeep` = palette, `uSky #eef1ec`, `uLineCol #3f5a62`,
`uRipples 1, uWaves 1, uFlow 1, uSeaMotion 1.8, uSteps 4`, `uWindDir = normalize(uWind)`, `uVortex`, mirror set.

Fragment, in order:
```glsl
vec4 w = texture2D(tWater, uv);
float d = max((w.r*255.0 - 128.0)*2.0, 0.0);            // 丈 from shore
vec2 flow = (w.gb*255.0 - 128.0)/127.0;
float sea = w.a, spd = clamp(length(flow)*1.4 - 0.4, 0.0, 1.0) * (1.0 - smoothstep(0.2, 0.6, sea));   // river factor
float lake = (1.0-sea)*(1.0-spd);
// 1. flat colour steps
float falloff = mix(mix(1.0/46.0, 1.0/18.0, spd), 1.0/150.0, sea);
float k = 1.0 - exp(-d*falloff);
float q = k*uSteps + (fbm3(xz*0.0045 + uTime*0.006) - 0.5)*0.4;           // wavering step edges
float qs = (floor(q) + smoothstep(0.42, 0.58, fract(q))) / uSteps;          // posterize with soft edges
vec3 col = mix(uWaterLight, uWater, smoothstep(0.0, 0.55, qs));
col = mix(col, uWaterDeep, smoothstep(0.5, 1.0, qs));
// 2. analytic Gerstner normal (11 waves) + detail slope; fade from high up
vec4 o = ocean(xz, mix(0.5,1.3,sea)*uWaves, mix(0.11,0.065,sea), 0.55*motion, 0.95);
float detFade = exp(-dist / max(uCamPos.y*1.6, 1.0));
vec2 sl = (o.xy + detailSlope(xz*0.07, uTime*0.6*motion)*0.035*uWaves*detFade) * mix(1.0, 0.2, smoothstep(1800.0, 4500.0, uCamPos.y));
vec3 N = normalize(vec3(-sl.x, 1.0, -sl.y)), V = normalize(uCamPos - vWp);
float F = 0.02 + 0.98*pow(1.0 - max(dot(N,V),0.0), 5.0);
col = mix(col, uSky, clamp(F*2.6, 0.0, 0.16));                              // painted sky reflection, capped at 16 %
col *= 1.0 + clamp(dot(sl, -normalize(uSunDir.xz)), -0.3, 0.3)*0.16;
col += vec3(0.98,0.97,0.92) * smoothstep(0.996, 0.9995, dot(N, normalize(V+uSunDir))) * 0.42 * (sea + 0.45*lake) * detFade;  // glints
```
`ocean()` L5588–5606: per wave i: `ang = atan(wind) + (hash12(i,1.7)*2-1)*spread`, `ph = sqrt(9.81*freq)*speed`,
`arg = freq*dot(d,pos) + t*ph + hash12(i,9.1)*2π`; accumulates slope `d·freq·amp·cos`, height, Jacobian with
`Q = 0.7/(WA·N)`; returns `(slope.xz, det J, h)`. `motion = mix(mix(0.35,0.6,spd), uSeaMotion, sea)` L5630.

Sea extras (`seaK = smoothstep(0.3,0.7,sea)`, `wvis` px<6–14) L5644–5663: two long swell sine bands (260 / 170 丈,
domain-warped by 900-丈 noise) shading ±4.5 %/2.5 %; **white caps** = hashed cells 96×64 丈 scrolling downwind,
each a curved dash with a life cycle `fract(t*0.075+hash)`; **breakers** = lines `sin(d/30 + t·0.3)` within 2–105 丈
of shore. **Surf** L5665–5667: foam band `< 5..15 丈 + noise` pulsing `sin(d*0.45 - t*1.3)`, not on rivers.

**Ink shore ripples** L5669–5696 (the stylised "foam"):
```glsl
float sp = mix(mix(15.0, 12.0, spd), 18.0, sea);                     // line spacing 丈
float ph = d/sp + uTime*mix(0.06,0.24,sea)*motion*(1.0-spd);          // lapping in toward the shore
float ld = min(fract(ph), 1.0-fract(ph))*sp;
float lineK = 1.0 - smoothstep(px*0.55, px*1.55, ld);                 // ~1px iso-distance lines
float band = mix(smoothstep(40.0, 4.0, d), 1.0, spd);                 // 2–3 lines off a shore; a river is all shore
// broken into strokes by noise advected with a two-phase flow map (period 3 s) along flow+wind
vec2 fl = flow*uFlow*26.0, wd = uWindDir*mix(3.0,9.0,sea);
float T = 3.0, p1 = fract(uTime/T), p2 = fract(uTime/T + 0.5);
float n1 = vnoise((xz - (fl+wd)*p1*T)*0.034 + ring), n2 = vnoise((xz - (fl+wd)*p2*T)*0.034 + ring + 3.7);
float brk = smoothstep(0.36, 0.6, mix(n1, n2, abs(1.0 - 2.0*p1)));
float lod = smoothstep(2.5, 5.0, sp/px);
float shoreInk = lineK*band*brk*lod*smoothstep(0.0, 1.2, d);
col = mix(col, uLineCol, clamp(shoreInk*0.5*uRipples, 0.0, 1.0));
```
(The swell crest iso-line ink `crestInk` is still computed L5685–5694 but **not applied** — comment L5697.)

Marsh water tint near `uSwampP` (L5698–5704). **Vortex 大漩涡** L5707–5720: 3- and 7-arm log spiral foam
`sin(3(ang - 2.2 log r) - 0.9t)`, darkening to `uWaterDeep*0.7`, jade eye `(0.62,0.92,0.86)`. Then
`lightOnGround`, `hazeMix`, `introMix`, edge mist. Note water is **not** lit by the toon tones or the sun bake — only
Fresnel/glints.

### 4.2 Mirror water 镜水 (05b) — L5769–5865

No render-to-texture. Technique (comment L5770–5775):
1. **Mask** `tMirror` R8 512² over the landform disc (`lf.mirror.mask`) L5810–5821.
2. **Lagoon sheet**: same WATER_VS/FS with `defines: { LAGOON: 1 }`, transparent, 96² plane (L5826–5829). Main
   water discards where `mm >= 0.5`; lagoon discards where `mm < 0.5` and outputs
   `alpha = 1 - uMirrorK*smoothstep(0.5,0.95,mm)` (k default 0.55, landform 0.6 L4204) L5730–5736.
3. **Sky backdrop** deep under the water (y = water − 1500, shifted −2500 z) whose colour depends on view pitch;
   it ray-intersects the water plane to darken under a deep 水眼 `uEye` (L5831–5840).
4. **Mirrored copies**: every nearby land/sect mesh drawn again with a **material whose vertex shader is patched by
   regex** (`mirrorMaterialOf` L5778–5799):
```glsl
float mDepth = max(wp.y - uMirY, 0.0); vMirH = wp.y - uMirY; wp.y = 2.0*uMirY - wp.y;    // reflect about water plane
wp.xz += vec2(sin(wp.z*0.041 + uMirT*1.25) + 0.5*sin(wp.z*0.13 - uMirT*2.1), sin(wp.x*0.037 + uMirT*1.05))
         * uMirWob * clamp(mDepth*0.012, 0.0, 1.5);                                        // ripple grows with image depth
gl_Position = projectionMatrix * viewMatrix * wp;
// fragment prepended: if (vMirH < 0.0) discard;   (what was under water has no image)
```
   `side: DoubleSide` (mirroring flips winding), `uMirWob = mirror.wobble 1.6`, renderOrder 0. Visibility: only near
   the lagoon, never on the map; terrain-tile copies follow their tile's LOD (`sync`) L5859–5865.

### 4.3 Upland lakes/pools/canals (05c) — L5867–5946

`WORLD.uplands: [{poly, y, deep, shallow, turbid}]` or ribbons `{inner, outer, y, deep, shallow}` (L5873–5874).
Mesh: shore ring (edge 0) → ring at 60 % toward centroid (edge 0.45) → centre (edge 1) (L5922–5930); ribbons:
inner/mid/outer with mid edge `min(0.75, 0.3+0.25·t)` (L5916–5920). Attributes `aEdge, aDeep, aShal, aTurb`.
Material: transparent, depthWrite, polygonOffset −1/−2, DoubleSide, `veil`.
FS L5885–5901: `c = mix(shallow, deep, smoothstep(0.04,0.62,e))`; drifting two-octave ripples to foam ×0.2
(×0.3 if turbid); lapping fringe `e<0.08`; ink edge `e<0.025` ×0.4; flat-ground toon; glint `pow(H.y, 80)*0.22`;
`alpha = uWash`.

### 4.4 Streams (06) — STREAM_VS/FS L6442–6505

Ribbon along `st.pts` (x, z, …; `a[2]` used as height for slope), width lerp `st.w[0]→w[1]` by `(i/n)^0.7`, y = max
ground of centre/left/right +1; cut out where a waterfall takes over (`st.falls`). Attributes `aUv(across, arc length)`,
`aSlope`. FS: foam streaks `vnoise(u*4, v*0.07 - t*2.4*flowK)` more on rapids (`smoothstep(0.08,0.4,slope)`),
river colour on level reaches, pale fringe at edges, flat toon, glint `pow(H.y,60)*0.18`, alpha soft edges
`1 - smoothstep(0.78,1,u+noise)`. transparent, no depth write, polygonOffset −2/−4.

### 4.5 Waterfalls 飞练 — FALL_VS/FS L6579–6616

Ribbon per fall from brink down the face (`f.pts`), width `f.w*(0.8+0.5t)` widening downward; across-vector
`(f.ax ?? f.nz, f.az ?? -f.nx)`; `uv.y = 1 - t`; `aIce` (frozen falls stand still). FS:
```glsl
float x = abs(vUv.x*2.0-1.0), tt = uTime*(1.0 - vIce);
float body = 1.0 - smoothstep(0.55, 1.0, x + (vnoise(vec2(vUv.x*6.0, vUv.y*3.0 + tt*0.6)) - 0.5)*0.3);
float streak = vnoise(vec2(vUv.x*14.0, vUv.y*mix(9.0,1.6,vIce) + tt*2.6));
vec3 c = mix(vec3(0.86,0.9,0.9), vec3(0.98,0.99,0.97), smoothstep(0.3,0.8,streak));
c = mix(c, mix(vec3(0.62,0.78,0.88), vec3(0.9,0.96,1.0), smoothstep(0.25,0.85,streak)), vIce);
float edge = smoothstep(0.62,0.8,x)*(1.0-smoothstep(0.8,0.98,x)); c = mix(c, uInkCol, edge*0.35);   // ink outline
float a = body*smoothstep(0.0,0.06,vUv.y)*(0.75+0.25*streak)*uWash;
gl_FragColor = vec4(c, a*mix(0.92,0.97,vIce));
```
Transparent, depthWrite false, DoubleSide, `veil`, renderOrder 6.

---------------------------------------------------------------------------------------------------------------------

## 5. Object generators (06) — "Everything here is generated (no assets)" L5949

### 5.1 Building kit `kit(buf)` L5957–6068 (on FacetBuf)

| fn | geometry | default ink |
|---|---|---|
| `box(x,y0,z,w,h,d,col,top,ink=0.9)` | 5 quads (no bottom) | 0.9 |
| `slab(p0,p1,w,t,col,top)` | sloped plank/bridge deck | 0.85 |
| `prism(x,y0,z,r,h,n,col,top,ink,taper,rot,sideInk)` | n-gon frustum; side seams inked only if n≤8 (else ×0.25) | 0.8 |
| `cone(x,y0,z,r,h,n,col,ink,rot,baseInk)` | | 0.5 / base 0.8 |
| `hip(x,y0,z,w,d,h,col,ov=6)` | hip roof, ridge along long side, eaves overhang `ov`, dark eave underside ×0.55 no ink | 0.9 |
| `pyramid(...)` | 4-sided | 0.9 |
| `hall(x,y0,z,w,d,h,wall,roof,tiers)` | box + pillar row every ~26 丈 + hip; 2 tiers for grand | |
| `pavilion(x,y0,z,s,roof,n)` | n=4 box+pyramid; else posts + n-prism + cone | |
| `pagoda(x,y0,z,s,levels,…)` | stacked boxes+hips shrinking ×0.86 + spire cone | |
| `wheel(...)` | rim/spokes/hub in x-y plane | |
| `blob(x,y,z,rx,ry,rz,col,rnd,ink=0)` | icosahedron detail 0 (20 faces), per-face ±8 % brightness | 0 |

Every face passes an `up` direction (outward) so FacetBuf winds it correctly. `archKit` (the richer roof kit with
`K.roof`, `K.frame`, `K.stele`, `K.gateArch`, `K.archBridge`, `K.free`) lives in 06b — outside this range.

### 5.2 City fallback — `buildCity(K, p, half, rnd, gates)` L6071–6096

Used only if `buildCities` (06e) has no plans (L6776–6777). Square walls (14 thick, 24 high), 30×34 corner towers
with pyramids, gate towers 66×26 red + hip, stone bridges (`slab`) over the moat, blocks of 2–4 houses per
~60-丈 cell avoiding the two avenues, a 56×26 drum tower at the crossing. Returns label height 90.

### 5.3 灵眼之树 spirit tree — `buildSpiritTree` L6100–6157

- `tube(pts, r0, r1, n)` L6103–6118: Catmull-Rom (`catmullPts` L6159–6167, 5 samples/segment) → rings with a
  frame from tangent × world-up; quads with light ink 0.25; colours between bark `(0.4,0.31,0.24)` and barkLit.
- Trunk: 4 control pts from y −14 to 142, r 38→20, 10 sides. 8 buttress roots out to r≈112, r 11→3.
- 9 boughs from y 90–136, reach 150–220, lift 60–120, sag; each forks once (±0.55 rad) → 3 lobes per bough;
  plus 5 crown lobes at y 192–238, r 50–78.
- Lobes: icosahedron detail 1 (80 faces), flattened (`ry = r·(0.5..0.66)·k`), vertices jittered via a shared-vertex
  map (watertight jitter) L6137–6145; colour by face height: under `(0.7,0.5,0.3)`, deep `(0.82,0.62,0.38)`,
  pale `(0.98,0.9,0.66)` 35 %, amber `(0.95,0.82,0.54)`; each place = 1 big lobe + 2–4 smaller piled on.
- Glow: own mesh `facetMaterial({lift:false, glow:0.6})` (L6790); FACET_FS glows only bright-ish colours:
  `col = mix(col, vCol*1.14, uGlow*smoothstep(0.55,0.8, dot(vCol,(0.3,0.55,0.15))))` L4646.
- `sectGlow` sprites (outside range) for amber inner light + 58 motes; a formation ring r 160; halo ellipsoid
  `(rx 290, ry 120, rz 290)` at y 190.
- Halo HALO_FS L6170–6171 (additive, FrontSide, depthWrite false):
  `f = 1 - |N·V|; a = (0.1 + 0.4 f²)(1 - f⁶)(0.85 + 0.15 sin(0.7t))·uA(0.4)` → colour `(1,0.82,0.5)·a`.

### 5.4 天柱山 column — `buildPillar(buf, P, rnd)` L6181–6207

16 sides × 24 rings from y 40 to `P.h+120`; profile `prof(t)` L6184 (1→0.76 by 25 %, →0.6 waist at 62 %, swell 0.66
at 82 %, 0.46 at top) × `1.12·P.r`; **fluting**: odd vertices at 0.84 radius; twist 0.035 rad/ring, ±0.06 rad
angular and ±7 丈 vertical hash jitter. Colour ramp up the column: ochre→malachite (12–36 %)→azurite (50–80 %)→snow
(93–99 %). Ink: ridge edges 0.7, valley edges 0.25, ring edges 0.08–0.12. Crown: fan to a point +30, 4 rock-tooth
cones. Drawn with `facetMaterial({lift:true})` in the `rock` buffer (L6793–6796). (The pillar is also written into
`tLand` so it casts a baked shadow, L5394–5396.)

### 5.5 笋石 spires — `buildSpires(buf)` L6208–6220

`WORLD.spires: [x, z, h, r, rr]`: 5–6-sided, 3 rings (r, 0.72r at 42 %, 0.38r at 78 %), tip offset; ochre sides,
alternating malachite/ochre top facets.

### 5.6 Trees — 9 low-poly kinds, instanced (L6222–6377)

Kinds (L6223–6225): 0 pine (trunk prism + 3 cones), 1 broadleaf (prism + ico blob 10×8.2), 2 tall (bamboo/cypress
narrow blob), 3 黄山松 (bent struts + 3 flat octahedral pads), 4 willow (blob + 9-quad hanging skirt), 5 blossom
(wide blob + pad), 6 spirit (slender prism + 2 crowns, glows), 7 lotus (pads on water + flower cone), 8 reeds
(9 blades). Geometry `treeGeometry(kind)` L6280–6324 in local units (height ~20–28).

Per-vertex attributes: `position`, `aPart` (0 trunk, 1 crown, 2 flower), `aNrm` = **sphere normal** from the part's
centre with y divided by `sy` (ellipsoidal) — `mark(p, cx, cy, cz, sy)` L6282. Crown vertices x/z jittered ×0.94–1.06
(L6318). Colour is NOT baked: the geometry uses `AC.trunk` as placeholder; colour comes from instance slot.

Colour slots `TREE_COLS` L6325 (index → hex): 0 pine `#4e6d60`, 1 green `#6a9573`, 2 maple `#b45a3e`, 3 ginkgo
`#c9a04c`, 4 frost pine `#52705f` (gets snow), 5 bamboo `#77a884`, 6 snow-white `#c4d2d0`, 7 autumn orange `#c6773b`,
8 peach `#dfa9b0`, 9 pear `#e6e3d8`, 10 willow `#8fb27a`, 11 spirit jade `#8ccfbe` (glows), 12 lotus `#5f8a5a`,
13 reed `#a8a274`, 14 dark cypress `#3f5e52`, 15 young green `#86ad6c`. Trunk `(0.36,0.3,0.25)`, flower `(0.93,0.62,0.68)`.

Instancing (L6339–6376): `WORLD.trees` stride 7 = `[x, y, z, scale, kind, colourSlot, yaw]` (+ `SECTS.trees`).
Some broadleaves are diverted to the "Meadow pack" glTF tree cards (`ecoTreeFor`, `EcoList`, `buildEco` — 02c,
outside range) L6340–6358. The rest grouped by **(2600-丈 chunk, kind)**, shuffled (so truncating `instanceCount`
thins evenly), one `InstancedBufferGeometry` per group with
`iPos = (x, y, z, scale)` and `iData = (kind, colourSlot, yaw, hash)`; bounding sphere by hand.

TREE_VS L6228–6253:
```glsl
float s = iPos.w * uSize, a = iData.z, c = cos(a), sn = sin(a);
vec3 p = position * s; p.xz = mat2(c, -sn, sn, c) * p.xz;
vec3 n = aNrm; n.xz = mat2(c, -sn, sn, c) * n.xz; vN = n;
vec3 base = iPos.xyz; base.y *= uRelief;
float crown = step(0.5, aPart) * step(aPart, 1.5), hk = max(position.y - 3.0, 0.0) / 22.0;
float gust = 0.55 + 0.45 * sin(uTime*0.31 + dot(base.xz, vec2(0.0019, 0.0012)));          // gusts roll across the land
float sw = sin(uTime*1.5 + iData.w*6.2832 + base.x*0.011)*0.65 + sin(uTime*2.6 + iData.w*3.1 + base.z*0.017)*0.25;
vec2 wd = normalize(uWind + vec2(1e-4, 0.0));
p.xz += (wd*(0.35 + sw)*gust + vec2(-wd.y, wd.x)*sw*0.25) * hk*hk * s * 0.8 * uSway * crown;  // lean + sway, quadratic in height
vec3 wp = base + p; wp.y *= 1.0 - uMap;
vH = clamp(position.y / 22.0, 0.0, 1.0);
vec3 fc = uCols[int(iData.y + 0.5)]; float v = iData.w;
vCol = aPart > 1.5 ? uFlower : mix(uTrunk, fc*(0.88 + 0.24*v) + vec3(0.03,0.02,-0.02)*(v-0.5), aPart);
vGlow = ci == 11 ? crown : 0.0;  vSnow = ci == 4 ? crown : 0.0;
```
TREE_FS L6254–6279: facet/sphere normal blend `k = 0.35 + 0.6·uSoft`; `t = mix(t, 0.55, 0.4)` (less contrast than
rock); cast shadow; crown darker underneath `×mix(0.8,1.07,smoothstep(0.2,0.9,vH))`; snow on frost pines by facet
normal + noise; toon + AO; **sunlit rim** `pow(1-|Ns·V|,3)·smoothstep(0.05,0.6,Ns·sun)·step(0.3,vH)·0.32`;
spirit glow; haze; intro.

Density LOD `updateProps(A)` L6822–6834 (A = camera altitude):
```js
k  = clamp((1400 / A)^1.35, 0.07, 1) * trees.density;
d  = max(1, |chunkCentre - camTarget| - 1300);  kd = clamp((A*1.25 / d)^2, 0.12, 1);
instanceCount = round(n * k * kd);
```

### 5.7 Roads — L6379–6440

Ribbon of width `r.w` along `r.pts` ([x,z]); breaks over water (bridges carry it); y = ground + lift
(`0.7 + min(6, |hl-hr|·0.4 + 1.5 if on hills)`). `aUv = (0|1, arc length)`. ROAD_FS: earthen tan centre → darker
edge, two worn ruts at |u|≈0.42, intermittent grass strip in the middle, grass tufts at edges, winter snow, flat
toon, alpha edge `1-smoothstep(0.7,1,u+noise)`. transparent, no depth write, polygonOffset −2/−4.

### 5.8 Villages, roadside, bridges — L6506–6577

`buildVillage` L6518–6537: up to `n` houses in two loose rows along a lane (placement rejected on slope >4 丈 height,
near water `sdAt>-14`, or occupied `K.free`), 30 % thatch, 35 % walled yards, a well, lamp glows, a wooden gateway.
`buildHouse` L6512–6517. `buildRoadside` L6538–6562: 茶棚 tea shed, 凉亭 pavilion + stele, 驿站 post station, 牌坊
arch. Bridges `K.archBridge`. One FacetBuf (cap 3·16384) → `facetMaterial({lift:false})`.

### 5.9 Formation rings — FORMATION_FS L6618–6632

Plane `2r×2r` on the ground; texture `BASE.formationTex` (alpha × luminance) rotated by `uTime·uSpin`, or a
procedural fallback (rings at r 0.92/0.7/0.4 + 4 spokes `abs(sin(4·ang))`); `pulse = 0.8+0.2 sin(1.3t)`;
additive. Sites: spirit tree (tint `(0.95,0.83,0.56)`, spin 0.025) and 地脉 node `dimai` (r 170, tint `(0.4,0.72,0.62)`,
spin 0.06) L6803–6806.

### 5.10 "All of it" — `buildProps(scene)` L6769–6820 (header L6648)

Order: sects (06b) → cities (06e or fallback) → 听云亭 (pack `temple` model or `K.pavilion`) → 古修洞府 stone door
(boxes) → 迎仙松 giant pine (prism + slab + 5 cones) → spirit tree (own mesh, glow) + halo → main props mesh →
`rock` buffer (pillar + spires, `lift:true`) → `buildPackLandmarks` L6653–6694 (glTF "pack" props: lilies, giant
mushrooms, logs, stumps, withered trees in the swamp; pillar clusters; statues/columns; boulders; village fences)
→ `buildMeadowProps` L6698–6768 (fences along lanes with flowers, a Bezier plank boardwalk across the marsh,
boulders every 380 eco plants, outcrops on a 760-丈 jittered grid on 50–330 丈 slopes, logs at wood edges) →
`buildPack` → labels → formations → `buildLore` (06d) → `buildFormations` → `buildTrees` → `buildRoads` →
`buildStreams` → `buildUplands` → `buildSettlements` → `buildFalls` → `buildCloudFalls` (07e) → vortex beam
(`beamMesh`, h 2600) → frees `WORLD.trees` (L6818).

Note the split: **procedural** = kit/FacetBuf geometry (all architecture fallback, pillar, spires, spirit tree,
9 tree kinds, ribbons); **asset models** = `PACK.place(name, …)` / `ECO.place` (glTF packs loaded elsewhere:
temple, lilies, mush5/7/12, log1/2, stump1/2, maple, treeOrange, pillarCluster, statue, column, rock1–11,
rgroup4/6, fence2/6/8 (+W/A season variants), plank1/2, flower cards).

---------------------------------------------------------------------------------------------------------------------

## 6. Godot 4 mapping

### 6.1 Global conventions

- Use **`render_mode unshaded, fog_disabled`** on every land/water/tree material and do the lighting by hand as the
  source does (it never uses engine lights). This is the most faithful route; §6.6 shows the alternative with
  `DirectionalLight3D`.
- Colour space: the source does all maths on display-space (sRGB) values and writes them raw. In Godot:
  (a) declare colour uniforms **without** `source_color` (so no sRGB→linear conversion), keep vertex colours as the
  raw 0..1 values, do the maths, then at the end `ALBEDO = pow(col, vec3(2.2));` (or exact sRGB→linear) so Godot's
  output conversion gives back the same display value; (b) Environment → Tonemap **Linear**, exposure 1, no glow/adjust.
- Shared uniforms: put the `LU` set into **global shader uniforms** (Project Settings → Shader Globals) —
  `global uniform vec3 sun_dir; global uniform vec4 toon; global uniform sampler2D t_sun; …` — the equivalent of
  `LU`'s one-object-per-uniform sharing. Update from GDScript with `RenderingServer.global_shader_parameter_set()`.
- Shared GLSL chunks → `res://shaders/land_common.gdshaderinc` and `#include` it (Godot 4 supports `#include`).
  GLSL → Godot: `texture2D`→`texture`, `gl_FragColor`→`ALBEDO`/`ALPHA`, `varying` same, `modelMatrix`→`MODEL_MATRIX`,
  `uCamPos`→`CAMERA_POSITION_WORLD` (fragment/vertex built-in in 4.x), `uTime`→`TIME` (or a global if you need the
  source's own clock).
- World position varying: `varying vec3 v_wp; void vertex(){ v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }`.
- Flat normal from derivatives: `vec3 Nf = normalize(cross(dFdx(v_wp), dFdy(v_wp)));` — the sign depends on the
  API's screen-y convention (Vulkan differs from WebGL), so **orient it**: `if (dot(Nf, smooth_n) < 0.0) Nf = -Nf;`
  (for buildings with no smooth normal, compare with `NORMAL` turned to world space, or with `CAMERA_POSITION_WORLD - v_wp`).

`land_common.gdshaderinc` (direct port of L491–499 and L4277–4335, trimmed to the core):
```glsl
global uniform vec3 sun_dir;          // SUN (L4214)
global uniform vec4 toon;             // (0.56, 0.84, 1.10, 0.85)
global uniform vec3 shade_tint;       // (0.8, 0.9, 1.1)
global uniform vec3 lit_tint;         // (1.05, 1.0, 0.92)
global uniform float ao_k;            // 0.5
global uniform sampler2D t_sun : filter_linear, repeat_disable;
global uniform vec4 world_rect;       // x0, z0, w, d
global uniform vec3 haze_col;         // U.uMist (0.86,0.87,0.84)
global uniform vec3 haze_warm;        // (0.93,0.88,0.80)
global uniform float haze_k;          // 0.5
global uniform float valley_k;        // 0.8
global uniform float alt_k;           // 0..1
global uniform float cine_k;
global uniform vec3 ink_col;          // (0.24,0.27,0.31)

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec2 hash22(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973)); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.xx + p3.yz) * p3.zy); }
float vnoise(vec2 p){ vec2 i = floor(p), f = fract(p), u = f*f*(3.0-2.0*f);
  return mix(mix(hash12(i), hash12(i+vec2(1,0)), u.x), mix(hash12(i+vec2(0,1)), hash12(i+vec2(1,1)), u.x), u.y); }
float fbm3(vec2 p){ float s = 0.5*vnoise(p); p = p*2.03 + 17.1; s += 0.25*vnoise(p); p = p*2.01 + 5.3; s += 0.125*vnoise(p); return s/0.875; }

vec2 world_uv(vec2 xz){ return (xz - world_rect.xy) / world_rect.zw; }
vec3 sun_at(vec2 xz){ return texture(t_sun, world_uv(xz)).rgb; }
float tones(vec3 N){ float nl = dot(N, sun_dir);
  return mix(0.0, mix(0.5, 1.0, smoothstep(0.5, 0.56, nl)), smoothstep(0.1, 0.16, nl)); }
float soft_tones(float nl){ return mix(0.0, mix(0.5, 1.0, smoothstep(0.4, 0.66, nl)), smoothstep(0.0, 0.26, nl)); }
float cast_light(float s){ return mix(1.0, smoothstep(0.36, 0.64, s), toon.w); }
vec3 tone_col(vec3 base, float t){
  vec3 sh = base * toon.x * shade_tint, mid = base * toon.y, lit = base * toon.z * lit_tint;
  return t < 0.5 ? mix(sh, mid, t * 2.0) : mix(mid, lit, t * 2.0 - 1.0);
}
vec3 ao_mul(vec3 c, float sb){ return c * mix(1.0, mix(0.84, 1.0, sb), ao_k); }
vec3 haze_mix(vec3 c, vec3 wp, vec3 cam){
  float d = length(wp - cam);
  float k = smoothstep(cam.y*1.2, cam.y*3.4, d) * haze_k * 0.62 * (1.0 + 0.8*alt_k);
  float low = exp(-max(wp.y, 0.0) / (240.0 + 160.0*alt_k));
  float v = valley_k * low * smoothstep(cam.y*0.4, cam.y*2.4, d) * (0.3 + 0.7*alt_k);
  k = 1.0 - (1.0 - k) * (1.0 - v*0.6);
  return mix(c, mix(haze_col, haze_warm, cine_k), clamp(k, 0.0, 1.0));
}
float cun(vec3 wp, vec3 N){                                 // L4528
  vec2 dh = N.xz; float sl = length(dh); if (sl < 0.12) return 0.0;
  dh /= sl; vec2 tg = vec2(-dh.y, dh.x);
  vec2 p = vec2(dot(wp.xz, tg) * 0.085, (wp.y + dot(wp.xz, dh) * 0.35) * 0.015);
  float n = vnoise(p) * 0.62 + vnoise(p * vec2(2.6, 1.9) + 5.3) * 0.38;
  return smoothstep(0.56, 0.84, n) * smoothstep(0.12, 0.45, sl) * (1.0 - smoothstep(0.3, 0.8, fwidth(p.x)));
}
vec3 to_linear(vec3 c){ return pow(max(c, vec3(0.0)), vec3(2.2)); }
```
(The per-sect `uReg`/`uLandAir` tints, `introMix`, biome/season/marsh/flower functions port 1:1 the same way; they
only need their textures as more global samplers.)

### 6.2 Facet material with barycentric ink (FACET_VS/FS)

Godot gives no barycentrics, so carry them as vertex data exactly like the source. Two packing options:

**A. glTF-friendly (recommended if you build meshes in Blender):** only standard attributes:
- `COLOR.rgb` = aCol, `COLOR.a` = crease.z
- `UV`  = crease.xy  (constant across the triangle)
- `UV2` = bary.xy    (bary.z = 1 − x − y; corners (1,0),(0,1),(0,0))
- `NORMAL` = smooth normal `aN` (zero vector not allowed in practice → use a flag instead: e.g. `UV2` offset or
  put "has smooth normal" in `CUSTOM0.w`), `TANGENT.xyz` = archPattern tangent, matId in `CUSTOM0.x` or a
  separate surface/material per pattern.

**B. Godot-generated (`ArrayMesh`) with custom channels** (mirrors FacetBuf's Uint8 packing):
```gdscript
# FacetBuf → ArrayMesh. Non-indexed triangle soup, like the source.
var arrays := []
arrays.resize(Mesh.ARRAY_MAX)
arrays[Mesh.ARRAY_VERTEX] = positions            # PackedVector3Array
arrays[Mesh.ARRAY_NORMAL] = smooth_normals       # PackedVector3Array (aN)
arrays[Mesh.ARRAY_COLOR]  = colors               # PackedColorArray (aCol, a = 1)
arrays[Mesh.ARRAY_CUSTOM0] = bary_mat_bytes      # PackedByteArray, 4 bytes/vert: bary.xyz*255, matId
arrays[Mesh.ARRAY_CUSTOM1] = crease_bytes        # PackedByteArray, 4 bytes/vert: crease.xyz*255, hasN*255
var fmt := (Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
         | (Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
```
Shader (`facet.gdshader`):
```glsl
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;
#include "res://shaders/land_common.gdshaderinc"
uniform float crease_ink = 0.75;   // terrain.creaseInk
uniform float foot_ink = 0.8;
uniform float line_w = 1.05;
uniform float soft_k = 0.85;       // terrain.soft
uniform float glow = 0.0;          // 0.6 for the spirit-tree crown
uniform float relief = 1.0;
uniform bool lift = true;
global uniform sampler2D t_land : filter_linear;   // RG half (RGH)
varying vec3 v_wp; varying vec3 v_bary; varying vec3 v_crease; varying vec3 v_col; varying vec3 v_n; varying float v_has_n;

void vertex(){
  vec3 p = VERTEX;
  if (lift && p.y > 0.0) p.y *= relief;
  v_wp = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
  v_bary = CUSTOM0.xyz; v_crease = CUSTOM1.xyz; v_has_n = CUSTOM1.w;
  v_col = COLOR.rgb; v_n = NORMAL;           // smooth normal (mesh space; mountains have identity model matrix)
  POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v_wp, 1.0);
}
void fragment(){
  vec3 Ns = normalize(v_n);
  vec3 Nf = normalize(cross(dFdx(v_wp), dFdy(v_wp)));
  bool hasN = v_has_n > 0.5;
  if (dot(Nf, hasN ? Ns : (CAMERA_POSITION_WORLD - v_wp)) < 0.0) Nf = -Nf;
  vec3 fw = fwidth(v_bary);
  float small = smoothstep(0.07, 0.16, max(fw.x, max(fw.y, fw.z)));
  vec3 s = sun_at(v_wp.xz);
  float soft = hasN ? max(soft_k, small) : 0.0;
  vec3 N = hasN ? normalize(mix(Nf, Ns, soft)) : Nf;
  float t = min(mix(tones(Nf), soft_tones(dot(N, sun_dir)), soft), cast_light(s.r));
  vec3 base = v_col;                                       // (+ archPattern, wood, biome, strata, detail… as L4625–4643)
  vec3 col = ao_mul(tone_col(base, t), s.b) + vec3(0.016, 0.02, 0.018) * N.y;
  if (hasN) col *= 1.0 - cun(v_wp, Ns) * (0.17 - 0.11 * t);
  col = mix(col, v_col * 1.14, glow * smoothstep(0.55, 0.8, dot(v_col, vec3(0.3, 0.55, 0.15))));
  // ink on the creases: constant screen width
  vec3 e = smoothstep(fw * 0.25, fw * line_w, v_bary);
  float line = max(max((1.0 - e.x) * v_crease.x, (1.0 - e.y) * v_crease.y), (1.0 - e.z) * v_crease.z)
             * crease_ink * mix(1.0, 0.32, soft);
  line *= 1.0 - smoothstep(0.075, 0.17, max(fw.x, max(fw.y, fw.z)));
  float fy = max(fwidth(v_wp.y), 1e-3);
  float foot = (1.0 - smoothstep(fy * 0.9, fy * 2.4, v_wp.y)) * foot_ink * step(-0.2, v_wp.y);
  foot *= smoothstep(3.0, 24.0, texture(t_land, world_uv(v_wp.xz)).g);
  col = mix(col, ink_col, clamp(max(line, foot), 0.0, 1.0) * 0.82);
  col = haze_mix(col, v_wp, CAMERA_POSITION_WORLD);
  ALBEDO = to_linear(col);
}
```
Important: barycentric ink requires **non-indexed** (or at least unshared-corner) triangles — keep FacetBuf's triangle
soup; do not let Godot's importer merge vertices (glTF import: vertex welding happens only for identical attributes,
and bary differs per corner, so it's safe). Do not enable automatic mesh LOD on these meshes (it would collapse
facets and break the bary layout).

### 6.3 Coarse terrain material (TERRAIN_VS/FS) and tiles/LOD

Same as 6.2 minus barycentrics; ridge ink from the Laplacian of `t_land` (copy L4766–4772 verbatim with
`texture()`), cloud shadows `t_shadow` scrolled by wind, foot ink with `smoothstep(40,110, t_land.g)`, the
`plainK` normalisation L4760–4763. Mesh data: `ARRAY_VERTEX`, `ARRAY_NORMAL` (smooth), `ARRAY_COLOR` (facetColor) — all
standard, so these can be generated in GDScript or exported from Blender.

Tiles & LOD in Godot:
- Per tile create three `MeshInstance3D`s sharing the vertex arrays but with different index arrays (ArrayMesh
  `ARRAY_INDEX` per LOD; three separate ArrayMeshes is simplest).
- Use **visibility ranges** instead of a per-frame script: LOD0 `visibility_range_end = 5200`, LOD1
  `begin 5200 / end 10500`, LOD2 `begin 10500`. Godot measures from the node origin, while the source uses
  `distance − 0.6·tileRadius` from the tile centre; set the node origin at the tile centre (or subtract
  `0.6·rad` from the ranges). Optional `visibility_range_fade_mode = SELF` for dithered transitions.
- Keep the 70-丈 skirt (colour ×0.8) so the coarser neighbour never opens a crack. Patch-covered tiles: LOD0 only.
- `custom_aabb` per tile (source sets bounding spheres by hand, L5120).

### 6.4 Plains / banks / roads / streams / uplands

All are `unshaded` spatial shaders porting the GLSL 1:1. Specifics:
- Plains: `if (sd > 0.0) discard;` → Godot: `if (sd > 0.0) { discard; }`. A single huge quad at y=0
  (`PlaneMesh`, size world+18000, subdivide 0). `extra_cull_margin` large or `custom_aabb`, as the source sets
  `frustumCulled=false`.
- Banks: generate in GDScript (marching squares on the SDF image, port L5324–5361) or in Blender from the coastline
  curve extruded down 24; shader uses `NORMAL` → world normal.
- Roads/streams: ribbons from polylines — Godot `Path3D` + `CSGPolygon3D` is too heavy for thousands of points;
  generate `ArrayMesh` strips in GDScript (copy L6413–6427 / L6476–6491). Material: `render_mode unshaded,
  blend_mix, depth_draw_never, cull_disabled`; replace `polygonOffset` by lifting the ribbon (+0.7..1 丈 already in the
  source) and/or `render_priority` higher than the ground; ALPHA from the shader.
- Uplands: `blend_mix, depth_draw_always` (source: transparent + depthWrite) + `render_priority 1`.
- Render order: the source relies on `renderOrder` (1 land, 2 plains, 3 banks/roads/streams/uplands, 4 water, 5 lagoon,
  6 falls/halo, 7 formations). In Godot opaque order is depth-sorted automatically; for transparent ones use
  `material.render_priority` in the same order.

### 6.5 Sun / shadow bake

Option 1 (faithful, recommended for the terrain): bake `tSun` once (and whenever the sun or cloud-sea height
changes), sample it in every ground shader exactly like `sunAt`.
- Offline/startup on CPU in GDScript or C# reading the height `Image` (port L5481–5499; 120 march steps × nx·nz is
  heavy in GDScript — use C#/GDExtension or a compute shader).
- GPU: `SubViewport` (size `nx × nz`, `transparent_bg`, `render_target_update_mode = UPDATE_ONCE`, no 3D) with a
  full-rect `ColorRect` using a **canvas_item** shader:
```glsl
shader_type canvas_item;
uniform sampler2D t_land : filter_linear, repeat_disable;   // R = height (FORMAT_RGH / RF)
uniform vec4 world_rect; uniform vec3 sun; uniform float cloud_y = 175.0;
uniform vec4 sites[6];                                       // x, z, R, extra cloud height
float Hh(vec2 xz){ return texture(t_land, (xz - world_rect.xy) / world_rect.zw).r; }
void fragment(){
  vec2 xz = world_rect.xy + UV * world_rect.zw;
  float h0 = max(Hh(xz), 0.0), cy = cloud_y;
  for (int i = 0; i < 6; i++) cy = max(cy, cloud_y + sites[i].w * (1.0 - smoothstep(sites[i].z*0.7, sites[i].z*1.08, length(xz - sites[i].xy))));
  vec2 d = normalize(sun.xz); float tanE = sun.y / max(length(sun.xz), 1e-3);
  float s0 = 1.0, s1 = 1.0, t = 20.0, st = 20.0;
  for (int i = 0; i < 120; i++) {
    float hp = Hh(xz + d * t), pen = t * 0.03 + 5.0;
    s0 = min(s0, clamp((h0 + 4.0 + t*tanE - hp) / pen + 0.5, 0.0, 1.0));
    s1 = min(s1, clamp((max(h0, cy) + t*tanE - hp) / pen + 0.5, 0.0, 1.0));
    t += st; st *= 1.028;
    if (min(h0 + 4.0, cy) + t*tanE > 1800.0) break;
  }
  float occ = 0.0;
  for (int k = 0; k < 8; k++) { float a = float(k)*0.785398 + 0.3; vec2 dd = vec2(cos(a), sin(a));
    for (int r = 1; r <= 3; r++) { float rr = float(r)*140.0; occ += clamp((Hh(xz + dd*rr) - h0) / rr, 0.0, 1.2); } }
  COLOR = vec4(s0, s1, clamp(1.0 - occ/24.0, 0.0, 1.0), 1.0);
}
```
  Then `var img = viewport.get_texture().get_image()` → `ImageTexture` (so it survives), set as the global `t_sun`.
  Watch the UV y direction: canvas UV y runs top→bottom; keep (x0,z0) ↔ UV (0,0) consistent with the ground lookup
  (`world_uv`) or flip once. Disable the viewport's HDR/sRGB conversions (`use_hdr_2d` off; data is linear 0..1).
- Height texture in Godot: `Image.create_from_data(w, h, false, Image.FORMAT_RGH, bytes)` (half-float RG) — matches
  `RGFormat + HalfFloatType` (L5423). Water SDF: `FORMAT_RGBA8` with filter linear, clamp.
- Cloud shadows: paint radial blots into an `Image` (or a SubViewport with radial gradient sprites) offset by
  `(sun.xz/sun.y)·height` like L5431–5437.

Option 2 (engine shadows): a `DirectionalLight3D` with rotation from (azimuth, elevation) and a **custom `light()`**
for stepped toon:
```glsl
shader_type spatial;
render_mode diffuse_toon, specular_disabled, ambient_light_disabled;   // or write light() yourself
void light(){
  float nl = dot(NORMAL, LIGHT);
  float t = mix(0.0, mix(0.5, 1.0, smoothstep(0.5, 0.56, nl)), smoothstep(0.1, 0.16, nl));
  t = min(t, mix(1.0, smoothstep(0.36, 0.64, ATTENUATION), 0.85));     // engine shadow map → stepped cast light
  vec3 k = t < 0.5 ? mix(0.56*vec3(0.8,0.9,1.1), vec3(0.84), t*2.0) : mix(vec3(0.84), 1.1*vec3(1.05,1.0,0.92), t*2.0-1.0);
  DIFFUSE_LIGHT = k * LIGHT_COLOR / PI;    // the PI factor depends on Godot's light conventions — calibrate so a sunlit flat = 1.1·albedo
}
```
  Caveats: at flight altitude with a 10⁴–10⁵-丈 world, PSSM shadow distance/resolution can't cover the view the way the
  baked map does; the bake also gives the **cloud-sea shadow layer** (G) and **valley AO** (B) that engine shadows
  don't. Recommended hybrid: baked `t_sun` for terrain/plains/water/trees (cheap, painterly penumbra), engine
  DirectionalLight3D shadows only for close-up buildings, with `light()` as above, `shadow_max_distance` ~2000.
  `DirectionalLight3D` direction: the light shines along its −Z, so set its basis z = `SUN` (the vector toward the
  sun) — e.g. `look_at(-sun_dir)` from origin.

### 6.6 Water (05) as a Godot spatial shader

The source needs **neither SCREEN_TEXTURE nor DEPTH_TEXTURE**: depth = shore distance from the SDF texture; no
refraction. Port:
```glsl
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;
#include "res://shaders/land_common.gdshaderinc"
#define NWAVES 11
uniform sampler2D t_water : filter_linear, repeat_disable;   // RGBA8: R sdf (128 = shore, 2 丈/step), GB flow, A sea
uniform float inland_depth = 7.0; uniform float sea_depth = 20.0;
uniform vec3 water_light = vec3(0.659, 0.831, 0.804);       // #a8d4cd
uniform vec3 water_mid   = vec3(0.451, 0.694, 0.737);       // #73b1bc
uniform vec3 water_deep  = vec3(0.247, 0.486, 0.592);       // #3f7c97
uniform vec3 sky = vec3(0.933, 0.945, 0.925);               // #eef1ec
uniform vec3 line_col = vec3(0.247, 0.353, 0.384);          // #3f5a62
uniform vec2 wind_dir = vec2(0.9638, 0.2677);               // normalize(0.9, 0.25)
uniform float steps = 4.0; uniform float waves = 1.0; uniform float ripples = 1.0; uniform float flow_k = 1.0; uniform float sea_motion = 1.8;
varying vec3 v_wp;

void vertex(){
  vec4 wp = MODEL_MATRIX * vec4(VERTEX, 1.0);
  float sea = textureLod(t_water, world_uv(wp.xz), 0.0).a;
  wp.y = -mix(inland_depth, sea_depth, sea);
  v_wp = wp.xyz;
  POSITION = PROJECTION_MATRIX * VIEW_MATRIX * wp;
}
vec4 ocean(vec2 pos, float amp0, float freq0, float speed, float spread){
  float baseAngle = atan(wind_dir.y, wind_dir.x), freq = freq0, amp = amp0, h = 0.0, jxx = 1.0, jzz = 1.0, jxz = 0.0;
  vec2 sl = vec2(0.0);
  for (int i = 0; i < NWAVES; i++){
    float fi = float(i), r0 = hash12(vec2(fi, 1.7)), r1 = hash12(vec2(fi, 9.1));
    float ang = baseAngle + (r0*2.0 - 1.0)*spread; vec2 d = vec2(cos(ang), sin(ang));
    float ph = sqrt(9.81*freq)*speed, arg = freq*dot(d, pos) + TIME*ph + r1*6.2831853;
    float s = sin(arg), c = cos(arg), WA = freq*amp, Q = 0.7/max(WA*float(NWAVES), 1e-3);
    sl += d*WA*c; h += amp*s;
    jxx -= Q*d.x*d.x*WA*s; jzz -= Q*d.y*d.y*WA*s; jxz -= Q*d.x*d.y*WA*s;
    freq *= 1.19; amp *= 0.82;
  }
  return vec4(sl, jxx*jzz - jxz*jxz, h);
}
void fragment(){
  vec2 xz = v_wp.xz; vec3 cam = CAMERA_POSITION_WORLD;
  vec4 w = texture(t_water, world_uv(xz));
  float d = max((w.r*255.0 - 128.0)*2.0, 0.0);
  vec2 flow = (w.gb*255.0 - 128.0)/127.0;
  float sea = w.a, spd = clamp(length(flow)*1.4 - 0.4, 0.0, 1.0)*(1.0 - smoothstep(0.2, 0.6, sea)), lake = (1.0-sea)*(1.0-spd);
  float px = max(fwidth(d), 1e-3), dist = length(cam - v_wp);
  float k = 1.0 - exp(-d*mix(mix(1.0/46.0, 1.0/18.0, spd), 1.0/150.0, sea));
  float q = k*steps + (fbm3(xz*0.0045 + TIME*0.006) - 0.5)*0.4;
  float qs = (floor(q) + smoothstep(0.42, 0.58, fract(q)))/steps;
  vec3 col = mix(mix(water_light, water_mid, smoothstep(0.0, 0.55, qs)), water_deep, smoothstep(0.5, 1.0, qs));
  float motion = mix(mix(0.35, 0.6, spd), sea_motion, sea);
  vec4 o = ocean(xz, mix(0.5, 1.3, sea)*waves, mix(0.11, 0.065, sea), 0.55*motion, 0.95);
  vec2 sl = o.xy * mix(1.0, 0.2, smoothstep(1800.0, 4500.0, cam.y));   // (+ detailSlope as L5607–5611, L5633)
  vec3 N = normalize(vec3(-sl.x, 1.0, -sl.y)), V = normalize(cam - v_wp);
  float F = 0.02 + 0.98*pow(1.0 - max(dot(N, V), 0.0), 5.0);
  col = mix(col, sky, clamp(F*2.6, 0.0, 0.16));
  col *= 1.0 + clamp(dot(sl, -normalize(sun_dir.xz)), -0.3, 0.3)*0.16;
  float detFade = exp(-dist/max(cam.y*1.6, 1.0));
  col += vec3(0.98, 0.97, 0.92)*smoothstep(0.996, 0.9995, dot(N, normalize(V + sun_dir)))*0.42*(sea + 0.45*lake)*detFade;
  // … sea swells / white caps / breakers / surf: copy L5644–5667 verbatim (uTime → TIME)
  // ink shore ripples (L5669–5696):
  float sp = mix(mix(15.0, 12.0, spd), 18.0, sea);
  float ph = d/sp + TIME*mix(0.06, 0.24, sea)*motion*(1.0 - spd);
  float ld = min(fract(ph), 1.0 - fract(ph))*sp;
  float lineK = 1.0 - smoothstep(px*0.55, px*1.55, ld);
  float band = mix(smoothstep(40.0, 4.0, d), 1.0, spd);
  vec2 drift = flow*flow_k*26.0 + wind_dir*mix(3.0, 9.0, sea);
  float T = 3.0, p1 = fract(TIME/T), p2 = fract(TIME/T + 0.5), ring = floor(ph)*7.13;
  float n1 = vnoise((xz - drift*p1*T)*0.034 + ring), n2 = vnoise((xz - drift*p2*T)*0.034 + ring + 3.7);
  float brk = smoothstep(0.36, 0.6, mix(n1, n2, abs(1.0 - 2.0*p1)));
  float shoreInk = lineK*band*brk*smoothstep(2.5, 5.0, sp/px)*smoothstep(0.0, 1.2, d);
  col = mix(col, line_col, clamp(shoreInk*0.5*ripples, 0.0, 1.0));
  col = haze_mix(col, v_wp, cam);
  ALBEDO = to_linear(col);
}
```
Mesh: `PlaneMesh` world+18000, `subdivide_width 219, subdivide_depth 179` (≈220×180 segments). Vertex texture fetch
works in Godot (`textureLod` in `vertex()`).

If you later want true depth-based shoreline/refraction (not in the source), Godot 4 uses
`uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;` and
`uniform sampler2D depth_tex : hint_depth_texture;` (the old `SCREEN_TEXTURE/DEPTH_TEXTURE` built-ins are gone in 4.x):
```glsl
float raw = texture(depth_tex, SCREEN_UV).r;
vec4 ndc = vec4(SCREEN_UV*2.0 - 1.0, raw, 1.0);           // Vulkan: z in 0..1 (Godot ≥4.3 reverse-Z: raw near=1)
vec4 view = INV_PROJECTION_MATRIX * ndc; view.xyz /= view.w;
float thickness = -view.z - (-VERTEX.z);                   // metres of water behind this fragment
```
That only makes sense if the plains no longer cut a hole and a real seabed exists; with the source's "sunken sheet"
design keep the SDF.

### 6.7 Mirror water (05b) in Godot

Two options:
1. **Source technique** (cheap, no extra render pass): duplicate the nearby land/sect `MeshInstance3D`s, give the
   copies a `ShaderMaterial` variant whose `vertex()` reflects the world position about `mir_y` and wobbles
   (L5784–5786), `render_mode cull_disabled` (mirroring flips winding), and in `fragment()` `if (v_mir_h < 0.0) discard;`.
   Build variants with shader `#define MIRROR` + `#ifdef` instead of the source's regex patching. Draw a sky
   backdrop plane below; draw the lagoon sheet with the water shader under `#define LAGOON`, `blend_mix`, alpha
   `1 - k·mask`, and make the main water discard inside the mask.
2. Godot-native: a planar reflection camera in a `SubViewport` mirrored about the water plane, fed to the lagoon shader
   as a sampler; more expensive, and the source deliberately avoided RTT.

### 6.8 Trees → MultiMeshInstance3D

- One `MultiMesh` per (chunk 2600 丈 × kind) like the source, `transform_format = TRANSFORM_3D`,
  `use_custom_data = true`, `use_colors = false`. Put **position + yaw + uniform scale in the instance transform**
  and `INSTANCE_CUSTOM = (kind, colourSlot, yaw, hash)` via `multimesh.set_instance_custom_data(i, Color(...))`.
- Per-vertex: `aPart` → `UV.x` (or `COLOR.r`), sphere normal `aNrm` → `NORMAL`. In Blender: model the 9 kinds,
  set custom split normals to "point away from crown centre" (Normal Edit modifier, radial, with y squash = 1/sy),
  store part index in a vertex-colour or UV channel.
- Density thinning: shuffle instances on build, then per frame `multimesh.visible_instance_count = round(n·k·kd)`
  (formula §5.6). Or use per-MMI `visibility_range_end` for coarse culling.
```glsl
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;
#include "res://shaders/land_common.gdshaderinc"
uniform vec3 cols[16];           // TREE_COLS
uniform vec3 trunk = vec3(0.36, 0.3, 0.25);
uniform vec3 flower = vec3(0.93, 0.62, 0.68);
uniform float sway = 1.0; uniform float soft_k = 0.85;
global uniform vec2 wind;        // (0.9, 0.25)
varying vec3 v_wp; varying vec3 v_col; varying vec3 v_n; varying float v_h; varying float v_glow; varying float v_snow;

void vertex(){
  float part = UV.x;                                  // 0 trunk, 1 crown, 2 flower
  vec4 ic = INSTANCE_CUSTOM;                          // kind, colour slot, yaw, hash
  vec3 base = MODEL_MATRIX[3].xyz;                    // instance origin (MultiMesh: MODEL_MATRIX includes the instance)
  float s = length(MODEL_MATRIX[0].xyz);              // instance scale
  float crown = step(0.5, part) * step(part, 1.5), hk = max(VERTEX.y - 3.0, 0.0) / 22.0;
  float gust = 0.55 + 0.45 * sin(TIME * 0.31 + dot(base.xz, vec2(0.0019, 0.0012)));
  float sw = sin(TIME * 1.5 + ic.w * 6.2832 + base.x * 0.011) * 0.65 + sin(TIME * 2.6 + ic.w * 3.1 + base.z * 0.017) * 0.25;
  vec2 wd = normalize(wind + vec2(1e-4, 0.0));
  vec2 off = (wd * (0.35 + sw) * gust + vec2(-wd.y, wd.x) * sw * 0.25) * hk * hk * s * 0.8 * sway * crown;   // world-space offset
  v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + vec3(off.x, 0.0, off.y);
  v_n = normalize(mat3(MODEL_MATRIX) * NORMAL);
  v_h = clamp(VERTEX.y / 22.0, 0.0, 1.0);
  int ci = int(ic.y + 0.5);
  vec3 fc = cols[ci];
  v_col = part > 1.5 ? flower : mix(trunk, fc * (0.88 + 0.24 * ic.w) + vec3(0.03, 0.02, -0.02) * (ic.w - 0.5), part);
  v_glow = ci == 11 ? crown : 0.0; v_snow = ci == 4 ? crown : 0.0;
  POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v_wp, 1.0);
}
void fragment(){
  vec3 Ns = normalize(v_n);
  vec3 Nf = normalize(cross(dFdx(v_wp), dFdy(v_wp))); if (dot(Nf, Ns) < 0.0) Nf = -Nf;
  float k = 0.35 + 0.6 * soft_k;
  vec3 N = normalize(mix(Nf, Ns, k));
  float t = mix(mix(tones(Nf), soft_tones(dot(N, sun_dir)), k), 0.55, 0.4);
  vec3 s = sun_at(v_wp.xz);
  t = min(t, cast_light(s.r));
  vec3 base = v_col * mix(0.8, 1.07, smoothstep(0.2, 0.9, v_h));
  base = mix(base, vec3(0.9, 0.93, 0.97), v_snow * 0.9 * smoothstep(0.3, 0.7, Nf.y + 0.42 * (vnoise(v_wp.xz * 0.21 + v_wp.y * 0.33) - 0.5)));
  vec3 col = ao_mul(tone_col(base, t), s.b);
  vec3 V = normalize(CAMERA_POSITION_WORLD - v_wp);
  col += base * pow(1.0 - abs(dot(Ns, V)), 3.0) * smoothstep(0.05, 0.6, dot(Ns, sun_dir)) * step(0.3, v_h) * 0.32 * cast_light(s.r);
  col = mix(col, base * 1.12 + vec3(0.05, 0.09, 0.08), v_glow * 0.55);
  ALBEDO = to_linear(haze_mix(col, v_wp, CAMERA_POSITION_WORLD));
}
```
(The source applies yaw/scale in the shader from `iPos/iData` because Three's InstancedBufferGeometry has no
transform; in Godot the MultiMesh transform does it. The wind offset in the source is in rotated-local space scaled
by `s`; applying it in world space as above is equivalent since the offset is horizontal and isotropic in yaw.)
Keep `relief` scaling of `base.y` if you keep the relief slider. Add `custom_aabb` per MultiMesh.

### 6.9 Halo, falls, formations, roads in Godot

- Halo: `render_mode unshaded, blend_add, depth_draw_never, cull_back;` sphere mesh scaled (290,120,290);
  `ALBEDO = vec3(1.0,0.82,0.5)*a` (ALPHA unnecessary with blend_add). Fresnel term from `NORMAL` (view space) and
  `VIEW`: `f = 1.0 - abs(dot(NORMAL, VIEW))`.
- Falls: `blend_mix, depth_draw_never, cull_disabled`, `ALPHA = a`; ribbon mesh from GDScript (or Blender curve →
  mesh with UV along length). `vIce` → `COLOR.r` or `UV2.x`.
- Formation: `PlaneMesh`, `blend_add, depth_draw_never`, rotate UV by `TIME*spin`; replace polygonOffset by +0.4 丈.
- Roads/streams: §6.4.

### 6.10 What to model in Blender vs generate

Generate (in Godot GDScript/C#, or Blender Geometry Nodes/Python, but data-driven):
- The **world heightfield and everything derived from it**: terrain tiles + 3 LODs + skirts, per-vertex
  `facetColor`, smooth normals, crease weights, sect patches, island undersides; plains plane; banks (marching
  squares on SDF); all textures (`tWater` SDF/flow/sea, `tLand` RG16F, `tShadow`, `tGround`, biome/season/marsh,
  `tSun` bake). These are algorithmic and tied to the layout; regenerating keeps everything consistent.
  If you do it in Blender (Python/GN), export glTF with: POSITION, NORMAL (smooth), COLOR_0 (facetColor rgb +
  crease.z in a), TEXCOORD_0 (crease.xy), TEXCOORD_1 (bary.xy) — option A of §6.2 — and **disable** "merge
  vertices"/auto-smooth that would weld corners.
- Ribbons (roads, streams, falls, upland water, mirror lagoon) from the world polylines.
- Tree placement (instance lists) and density thinning.
- Water, haze, ink, intro: shaders only.

Model in Blender (hand-authored assets, low-poly faceted, flat colour per face):
- The 9 tree kinds (reproduce `treeGeometry` L6280–6324: pine 3 cones, ico-blob crowns, 黄山松 pads, willow skirt,
  lotus, reeds) with radial custom normals and a part channel.
- Architecture kit pieces (halls, hip roofs, pavilions, pagodas, gate towers, walls, houses, bridges, wheel) — or port
  `kit()` to GDScript; for Blender assets bake per-face crease weights (edges with ink 0.9 on outlines, 0 on quad
  diagonals) into the bary/crease channels with a small Python script, and archPattern ids per face (or replace
  archPattern with tiling textures: lattice, tiles, paving, ashlar, 彩画, bronze, studs).
- Hero props: 灵眼之树 (spline trunk/boughs + 80-face lobes; easy as Blender curves with bevel + ico spheres),
  天柱山 column (16-sided fluted lofted profile `prof(t)`), 迎仙松, 洞府 door, spires (or generate — they're simple).
- The "pack" models already used as glTF (temple, lilies, mushrooms, logs, stumps, rocks, rock groups, fences with
  seasonal variants, planks, statues, columns, pillar clusters, flower cards) — import directly.
- Painted detail tiles `tDetail0..4` and the formation texture (2D art).

---------------------------------------------------------------------------------------------------------------------

## 7. Quick constants table

| constant | value | line |
|---|---|---|
| grid spacing `terrain.grid` | 40 丈 | L332 |
| facetJitter | 0.32 (×g, both signs) | L332, L1789 |
| terrain tile size | 96 cells | L5049 |
| LOD distances | 5200 / 10500 × `terrain.lod` | L5049, L5132 |
| skirt depth | 70 | L5054 |
| SINK for zero-height pts | −1.5 | L5055, L4923 |
| plains margin | 9000 | L5273 |
| inland / sea water level | −7 / −20 | L353, L5573 |
| bank bottom | −24, set-back 2.5 | L5328 |
| water SDF encoding | R: 128 = shore, 2 丈/step | L1993, L5616 |
| tLand | RG16F, 1.5 texel/cell, blur r=5 cells | L5397–5425 |
| tShadow | 1024 wide canvas | L5427 |
| tSun | nx×nz RGBA8 | L5506 |
| sun march | 120 steps, t0=20, ×1.028, pen = 0.03t+5, cutoff 1800 | L5488–5495 |
| AO | 8 dirs × {140,280,420}, /24 | L5496–5498 |
| uToon | (0.56, 0.84, 1.10, 0.85) | L5552 |
| shade / lit tint | (0.8,0.9,1.1) / (1.05,1.0,0.92) | L4240 |
| uSoft / uCun / uStrata | 0.85 / 1 / 1 | L332 |
| creaseInk / footInk / lineW | 0.75 / 0.8 / 1.05 | L332, L4667 |
| water steps / seaMotion | 4 / 1.8 | L353 |
| Gerstner | 11 waves, ×1.19 freq, ×0.82 amp, F0 0.02 | L5578, L5603, L5636 |
| tree chunk | 2600 丈 | L6339 |
| tree density | k = clamp((1400/A)^1.35, 0.07, 1); kd = clamp((1.25A/d)^2, 0.12, 1) | L6827–6831 |
| mirror wobble | 1.6 | L379, L5792 |
| cloud sea height | 175 | L351 |
