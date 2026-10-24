# B — GEO data, CONFIG, layout/coordinates, assets, and world planning (index.html L277–2380)

Source: `demo/index.html` (Three.js r170 via importmap, L267; GLTFLoader import L276).
Scope: sections 00 (GEO), 01 (CONFIG, layout, coordinate conversion, utils, uniforms, GLSL noise), 02 (optional assets, POIs),
02b (model pack), 02c (Meadow impostor cards), 03 (world planning: noise, density, coast SDF, peaks, sect defs, landmarks,
heightfield, water, marsh, clouds, cloud sea, spires, falls, `buildWorld`).
Line numbers are 1-based for that file. Functions *called* from this range but defined later are listed in §12 with their line.

---------------------------------------------------------------------------------------------------------------------------------

## 0. TL;DR for the Godot/Blender rebuild

- Everything is generated from one **GEO** object (L282–309) in **"base-map pixel" space** (pixels of a 1490×812 screenshot of
  the 云梦山 region of selfmate's 人界舆图, extended beyond that frame). World unit = **1 丈**. **+x = east, +z = south, +y up**
  (comment L312). Camera always faces north (−z) (CONFIG.camera comment L324) — this is exactly Godot's default forward (−Z).
- Pixel→world: `world = (px − origin) · k` with **k ≈ 58.0602 丈/px**, **origin ≈ (570.3333, 394.3333) px** (centroid of the
  three 云梦 sect pins). World rect ≈ x ∈ [−29 630, 102 167], z ∈ [−63 537, 16 586] 丈 (131.8 k × 80.1 k 丈).
- The terrain is a height field on a **40 丈 grid** (3296 × 2005 ≈ 6.6 M vertices, with hashed per-vertex jitter) plus finer
  per-sect patches (×3 subdivision). Height = composition of: mountain relief (erosion sim, 03a, out of scope) + designed peaks
  (`(1−q^a)^b` with lobed ridge profile) + plains hills + landmark shapes + city relief + sect landforms; then the sea / pools
  carve it.
- Water: sea polygon + 7 island holes rasterised to a 4608×2801 mask (≈28.6 丈/texel), chamfer SDF in 1/8-丈 Int16; sea surface at
  −20 丈, inland water at −7 丈; sea floor under cliffs −26 丈.
- Clouds: card-cloud clusters + an 80-丈 cloud-sea density grid + per-sect 50-丈 "sea field" (top height + density).
- **Bake offline** (Python/Blender): density/hint PNG decode, coast ring with detail, sea mask & SDF, the whole heightfield
  (plus 03a erosion relief), water mask/flow texture, marsh texture, cloud-sea density, sect sea fields, POI world positions.
  Ship them to Godot as EXR/PNG16 + JSON. Compute at runtime only shading, LOD/culling, the impostor card selection, and wind.

---------------------------------------------------------------------------------------------------------------------------------

## 1. Coordinate systems

### 1.1 Spaces

| Space | Units | Axes | Where |
|---|---|---|---|
| **GEO / base-map pixel** ("云梦山截图像素") | px of the 1490×812 云梦山 screenshot, extended | +x east, +y south (image rows) | GEO (L282–309), comments L277–281 |
| **World** | 丈 (1 world unit = 1 丈, L312) | +x east, +z south, +y up | everything in 03+ |
| **World rect** `LAYOUT.rect` = `WORLD.rect` | 丈 | — | L431–432, L1711, L2350 |
| **Density/hint texel** | 757×460 px over `GEO.frame` | u east, v south | `geoSample` L1094–1099 |
| **Water mask texel** | `CONFIG.water.maskSize`=4608 wide, H = round(4608·Δz/Δx) = 2801 | over world rect | L1882 |
| **Coarse sea SDF** | `WORLD.seaC`=100 丈 cells (1318×802) | over world rect | L1141–1145 |
| **Cloud-sea grid** | 80 丈 cells (1648×1002) | over world rect | L2127 |
| **Sect sea field** | 50 丈 cells, square ±2.4 R round each sect | — | L2192 |
| **Sect-local (u, v)** | 丈 × `CONFIG.sects.scale`; u east, v south ("toward camera") | relative to sect centre | L1225–1233 |
| **Model pack** | metres, +Y up (baked) → 丈 via `PACK_M = 10` | — | L660, L667 |
| **Eco card** | metres → 丈 via per-card `scale` | — | L850–853 |

`FRAME` (L442–446) is a facade: `w: 1490, h: 812` are nominal only (not used in math); `FRAME.toBase = LAYOUT.toGeo`,
`FRAME.toWorld = LAYOUT.toWorld`. The 打点 (pin) mode and hotspots.json use base-map pixels.

### 1.2 Frames (L283–284)

```
GEO.frame    = { x0: 60, y0: -700, x1: 2330, y1: 680 }   // v4.1 enlarged frame (px)
GEO.oldFrame = { x0: 60, y0:   20, x1: 1220, y1: 680 }   // the world through v4.0; inOldFrame() L1105 tests against it
```
Negative y = north of the original screenshot (the 无边海, 七灵岛, 大漩涡).

### 1.3 Scale factor k and origin — `computeLayout()` L394–434

```
cruise = CONFIG.flight.speed * CONFIG.zoom.mid           = 0.12 * 1650 = 198 丈/s    (L396)
k      = gujianLuoyunSec * cruise * spacing / |G − L|     (L397)
       = 62 * 198 * 1.0 / hypot(559−768, 351−383) = 12276 / 211.436 = 58.06024 丈 per px
origin = ((G+L+B)/3)  = ((559+768+384)/3, (351+383+449)/3) = (570.3333, 394.3333) px   (L398)
LAYOUT.S = k / 23.5 = 2.47065   // relative to v3 scale, used for sizes that grew with the world (L400)
toWorld(px, py) = [(px − ox)·k, (py − oy)·k]             (L402)
toGeo(x, z)     = [x/k + ox, z/k + oy]                    (L403)
```
where G = pins.gujian, L = pins.luoyun, B = pins.baiqiao. Changing `CONFIG.layout.*`, `flight.speed` or `zoom.mid` rescales the
whole world (refresh needed). Travel table (`travelSummary` L435–438; d/cruise and d/(cruise·boostMul)):

| edge | distance 丈 | cruise s | boost s |
|---|---|---|---|
| 古剑门–落云宗 | 12 276 | 62.0 | 20.7 |
| 古剑门–百巧院 | 11 645 | 58.8 | 19.6 |
| 百巧院–落云宗 | 22 622 | 114.3 | 38.1 |

World rect (L431–432): `x0 = (60−ox)k = −29 630.1`, `x1 = (2330−ox)k = 102 166.7`, `z0 = (−700−oy)k = −63 537.3`,
`z1 = (680−oy)k = 16 585.9`. One density texel ≈ 174.1 丈.

Start position (L429): `startPos = [luoyun.x − 450, luoyun.z + 1450]` = (11 026.6, 792.0) — south of 落云宗 looking north.

### 1.4 Godot axis mapping

World (x, y, z) → Godot (x, y, z) **unchanged**: Godot is right-handed, +Y up, −Z forward; here north = −z, so the never-turning
camera looking north is Godot's default orientation. Blender is Z-up: Blender (X, Y, Z) = (x, −z, y) (north = +Y in Blender), and
the glTF exporter converts back to Y-up automatically.
Precision: |x| up to ~102 k units; float32 spacing at 65 536–131 072 is 0.0078 — usable, but consider a **double-precision Godot
build** or **floating origin** (recentre every N k 丈) or simply a uniform rescale (e.g. 1 Godot unit = 10 丈) if jitter appears
in vertex shaders/shadows. Alternatively shift the origin so the region of interest is near 0.

---------------------------------------------------------------------------------------------------------------------------------

## 2. GEO data model (L282–309)

All coordinates are base-map px. Polylines/polygons are **flat arrays `[x0,y0,x1,y1,…]`**.

| Key | Line | Content |
|---|---|---|
| `frame` | 283 | `{x0:60,y0:-700,x1:2330,y1:680}` |
| `oldFrame` | 284 | `{x0:60,y0:20,x1:1220,y1:680}` |
| `pins` | 286 | 13 named pins `id: [px, py]` (table below) |
| `coast` | 288 | **one closed ring, 756 vertices (1512 numbers)**, sea interior. Starts `60,-700, 60,79.5, 78,79.5…`, ends `…2330,-193.5, 2330,-700`. Vertices lying on the frame edge (within 0.7 px) mean "the sea continues past the world" (comment L287, handled L1110–1116) |
| `islands` | 290–298 | 7 rings `{id, pts}`: `lingao`(灵鳌岛), `isle1`, `isle2`, `qiling`(七灵岛 main), `isle4`, `linggui`(灵龟岛), `lingfeng`(灵凤岛). Land inside the sea; drawn as holes (even-odd fill) |
| `rivers` | 300–303 | 2 centre-lines, ordered upstream → sea (L299). River 0 (109 pts): source (1295.4, 999.4) south of the frame, runs NE past 鸾鸣宗 and reaches the coast at (2045.1, 45.7) next to 水影宗 (鸾水 / 天水入海处). River 1 (91 pts): from (1563.8, 10.9) — just inland of the north coast (y = 0 there is sea; point-in-polygon checked) — runs south and ends at (1449.5, 828.2), which is on river 0 (river 0 has (1449.3, 831.8)): a **tributary joining river 0**. 03a steers drainage along them |
| `border` | 305 | 天道盟小国 border polyline: `[1750,-15, 1608,340, 1675,390, 2225,300, 2208,145, 2330,-130]` |
| `density` | 306 | `{w:757, h:460, png:'data:image/png;base64,…'}` 70 KB line. **Greyscale (mode L)**, mountain density 0..1 over `GEO.frame` (mean 0.075, 31 % non-zero) |
| `hint` | 308 | `{w:757, h:460, png:…}` 44 KB line. **RGB**: R = aridity (姜国/天凌国 steppe), G = woods selfmate paints, B unused (=0). Zero inside the old frame (comment L307) |

Decoded copies for inspection were written to
[`img/density.png`](img/density.png) and [`img/hint.png`](img/hint.png)
(extract with `re.search(r"base64,([A-Za-z0-9+/=]+)", line)` on lines 306/308 — never print the line).

### 2.1 Pins (L286) and their world positions (computed with k, origin above)

| pin | px | world x, z (丈) | meaning |
|---|---|---|---|
| gujian | 559, 351 | −658, −2516 | 古剑门 |
| luoyun | 768, 383 | 11 477, −658 | 落云宗 |
| baiqiao | 384, 449 | −10 819, 3174 | 百巧院 |
| tianzhu | 240, 404 | −19 179, 561 | 天柱山 |
| yunmeng | 570, 406 | −19, 677 | 云梦山 main summit |
| yunzhou | 777, 506 | 11 999, 6483 | 韵州(城) |
| xiguo | 852, 498 | 16 354, 6019 | 溪国 label |
| fengri | 1118, 182 | 31 798, −12 328 | 封日城 pin (POI uses geo 1127,179) |
| shuiying | 2078, 21 | 87 535, −21 676 | 水影宗 (moved 22 px S onto shore, L285) |
| nihang | 2232.1, 251.4 | 96 483, −8299 | 倪航斋 |
| luanming | 1788.2, 503.5 | 70 710, 6338 | 鸾鸣宗 (moved 22 px E off 鸾水 bank) |
| qiling | 1083.7, −450 | 29 806, −49 022 | 七灵岛 |
| vortex | 1083.7, −625.3 | 29 806, −59 200 | 大漩涡 (`WORLD.vortex` r = 1500, L1752) |

### 2.2 Density / hint decoding and sampling

`loadGeo()` L1076–1092: decode the data-URI PNG through an `Image` → 2D canvas → `getImageData`; `out[i] = px[i*4+ch]/255`.
Density uses channel 0 (R; greyscale expands to RGB); hint uses ch 0 → `WORLD.hintArid`, ch 1 → `WORLD.hintWood`. On failure
density stays zeros (warning "only the designed mountains will stand") and hints stay null.

`geoSample(arr, W, H, x, z)` L1094–1099 (bilinear, texel-centre convention, clamped):
```
q  = toGeo(x, z)
fx = clamp((q.x − F.x0)/(F.x1 − F.x0) · W − 0.5, 0, W − 1.001)
fy = clamp((q.y − F.y0)/(F.y1 − F.y0) · H − 0.5, 0, H − 1.001)
return bilerp(arr, floor(fx), floor(fy), frac(fx), frac(fy))
```
`densityAt` L1100, `aridAt` L1102, `woodHintAt` L1103 (0 when hint missing), `inOldFrame` L1105.

**Godot:** decode once offline to `density.exr`/`hint.png` (or keep PNG; `Image.get_pixel` returns 0..1), store the frame and
(k, origin) in a JSON resource; port `geoSample` as a static func. In a shader use a `sampler2D` with `filter_linear` and
UV = `(toGeo(xz) − F0)/(F1 − F0)` (the −0.5 texel offset is the hardware convention already).

---------------------------------------------------------------------------------------------------------------------------------

## 3. CONFIG reference (L313–388)

`CONFIG_DEFAULT` = deep copy (L389). "刷新生效" = needs page reload (rebuild); others are live. Comments translated/condensed.

### assets (L315) — all optional
| key | value |
|---|---|
| details | `'details.json'` |
| hotspots | `'hotspots.json'` |
| cloud | `'cloud.png'` (cloud brush texture) |
| formation | `'formation.png'` (formation/array pattern) |
| pack | `'assets/ym_pack.json'` |
| ground | `'assets/ground_{name}.jpg'` (name ∈ grass, dry, snow, cliff, mud) |
| eco | `'assets/eco.json'` |
| ecoAlbedo | `'assets/eco_albedo.webp'` |
| ecoNormal | `'assets/eco_normal.webp'` |

### layout (L318) — distances (refresh)
`gujianLuoyunSec: 62` (cruise seconds 古剑门↔落云宗), `spacing: 1.0` (extra global multiplier).

### flight (L320)
| key | value | meaning |
|---|---|---|
| speed | 0.12 | velocity = speed × current altitude (丈/s per 丈) |
| boostMul | 3.0 | Shift boost multiplier |
| accel | 0.5 | start-up time constant (s) |
| glide | 1.25 | glide decay (s) |
| fling | 0.85 | fling/inertia |
| lightHeight | 0.24 | 遁光 height (fraction) |
| bob | 1.0 | bobbing |
| dunIn | 0.22 | how fast the escape light wraps the figure on Shift (v4.1) |
| dunOut | 0.55 | how fast it peels away |

### figure (L323) — cultivator figure (v4.1)
`on: false, size: 1.5` (×100 丈 at mid altitude, screen-constant), `lean: 30`°, `boostLean: 66`°, `bank: 22`°, `fade: 0.22` (0 gone, 1 solid inside the light).

### camera (L325) — always faces north, never turns; pitch varies with altitude
`fov: 40, lookAhead: 0.6, follow: 0.3, pitchLow: 38, pitchMid: 45, pitchHigh: 54, pitchTop: 60` (degrees), `boostPull: 0.1, lead: 0.1`.

### zoom (L327) — altitude = zoom (丈)
`low: 950` (see sects), `mid: 1650` (cruise), `high: 8000` (see all three sects), `mapAt: 11000` (auto switch to 舆图 map),
`start: 1650, wheel: 0.0013, keyRate: 0.95, ease: 0.28`.

### terrain (L332)
| key | value | meaning |
|---|---|---|
| relief | 1.0 | mountain height multiplier (live) |
| grid | 40 | low-poly grid edge (丈) → `WORLD.g` (refresh) |
| peakHeight | 1.0 | designed peaks height multiplier (`ph`) |
| mainPeak | 580 | 云梦山 main summit height |
| pillar | 1300 | 天柱山 column height |
| siteDetail | 3 | sect patch subdivision (3 = 3×3 per cell) |
| snowLine | 820 | snow line |
| hills | 1.0 | plains-hill frequency |
| creaseInk | 0.75 | ridge ink lines |
| footInk | 0.8 | mountain-foot ink |
| facetJitter | 0.32 | vertex jitter (fraction of cell) |
| soft | 0.85 | shading softness (0 = v3 hard facets, 1 = smooth; 3-tone bands remain) |
| cun | 1.0 | 皴 slope brush strokes |
| strata | 1.0 | cliff strata lines |
| lod | 1 | far mesh decimation (0 off) |
| ridgeLight | 1.0 | lit-ridge highlight |

### city (L339) `beams: 1, terraces: 1`
### life (L341) `amount: 1, people: 1, traffic: 1, boats: 1, ships: 1, flyboats: 1, deer: 28, scale: 1.15, far: 3000, motes: 180`

### relief (L342) — 03a erosion mountains (refresh); comments L333–336
| key | value | meaning |
|---|---|---|
| cell | 100 | coarse grid edge (丈) (`RELIEF.C`) |
| iters | 5 | drainage↔terrain iterations |
| m | 0.45 | drainage-area exponent (stream power) |
| height | 540 | height at the 97th percentile of mountain land |
| cap | 950 | soft cap of max height |
| maskLo / maskHi | 0.1 / 0.62 | density → uplift mapping |
| front | 1.8 | how fast the mountain front rises (bigger = wider hills) |
| spine | 0.55 | main-ridge band strength |
| plain | 0.1 | below this density + tiny uplift = plain (base level) |
| detail | 0.5 | cliff/gully relief on the 40 丈 grid |
| sectRise | 1.15 | ranges rising toward sects |
| spurLow | 0.2 | valleys between spurs (relative) |
| mainMassif | 0.6 | main summit block uplift |
| trend | 15 | range trend (deg) |
| rock | 0.55 | lithology undulation |
| grain | 0.18 | trend grain |
| soften | 6 | ridge rounding passes |
| streamArea | 150 | cells of drainage for a stream |
| riverArea | 420 | drainage still enough for a river out of the hills |

### sects (L346) — comments L343–345
| key | value | meaning |
|---|---|---|
| scale | 1.0 | sect region & halls scale `k` (refresh) |
| dome | 1.0 | protective array dome opacity |
| flow | 1.0 | array pattern flow |
| ripple | 1.0 | qi ripple |
| clouds | 1.0 | sect cloud sea amount (refresh) |
| glow | 1.0 | emissive points |
| cloudGap | 14 | cloud top under lowest deck (丈) (only used when D.base missing, L1571) |
| ringSpin | 1.0 | 古剑门 sword ring spin (live) |
| cloudFall | 0.5 | sect cloud top drop per 丈 outward from the sect outline |
| cloudSink | 240 | after the top sinks this far the cloud is gone |
| floorBack / floorFront | −20 / −70 | sect floor vs cloud top (back/front) |
| crestUp | 85 | ridge crest at 0.55–0.95 R vs cloud top |
| spurs | 6 | number of spurs converging on a sect |
| leanK | 1.3 | peak wall outward lean multiplier |
| foot | 0.34 | talus height ratio |
| rockMix | 0.35 | sect rock colour vs surroundings |

### regions (L348) `snow: 1.0, maple: 1.0, radius: 1.0`
### cloudSea (L351) — comments L349–350
`amount: 1.0, height: 175` (cloud top 丈), `billow: 1.0, speed: 1.0, spread: 1.0` (>1 bigger seas), `thick: 150` (丈),
`density: 1.0, steps: 9` (volume steps), `valley: 75` (top above valley floor in high valleys), `hollow: 1.0` (0 ignore terrain;
1 only where ground lies hollowLo..hollowHi under ridges within 500 丈), `hollowLo: 30, hollowHi: 150`.
### water (L353)
`depth: 7` (inland water sunk, 丈), `seaDepth: 20`, `ripples: 1.0, waves: 1.0, flow: 1.0, seaMotion: 1.8, steps: 4` (colour steps), `maskSize: 4608`.
### trees (L354) `density: 1.0, size: 1.0, sway: 1.0`
### eco (L358) — Meadow library (comments L355–357)
`trees: 1.0` (share of library birch/oak; 0 = procedural), `ground: 1.0` (flowers/grass density), `winter: [4600, 7000]` and
`autumn: [5800, 9200]` (range in 丈: full → gone, noisy boundary; winter round 古剑门, autumn round 百巧院), `spirit: 1.0`,
`lowPines: 1.0, meadows: 1.0, verges: 1.0`.
### ground (L361) `rivers: 1, forests: 1.0, farms: 1.0, roads: 1, streams: 1.0`
### lore (L363) `amount: 1.0, flyers: 8, flyerSpeed: 340` (丈/息)
### palette (L365–372)
```
ink #363d41  azurite #3f5866  azuriteLit #5d7f8d  malachite #6c9b97  malachiteDeep #527f7b  ochre #a88969  ochreDeep #8b6c4f
plains #b6bd99  plainsGreen #9db08a  waterLight #a8d4cd  water #73b1bc  waterDeep #3f7c97  mist #e6e2dd
pine #4e6d63  tree #6f9a86  maple #a65a42  ginkgo #b39560  frostPine #8fa8a6  bamboo #6f9f88  snow #e9eeee  rockRed #b45c3f  rockPale #cdc8b7
```
### sun (L373) `azimuth: 140` (deg from N clockwise = SE; light from camera's right-back), `elevation: 40, shadow: 0.85, contrast: 1.0, ao: 0.5`
### light (L375) 遁光 `core: '#e8fff6', glow: '#3fd9b0', size: 1.0, tail: 1.0, breath: 0.08, intensity: 0.85, shadow: 0.32, speedLines: 0.6`
### clouds (L377) `amount: 1.0, speed: 1.0, banks: 1.0, mist: 0.5, nearEvery: 10` (s), `nearOpacity: 0.5, shadows: 0.16, wall: 1.0`
### mirror (L379) `wobble: 1.6` (v4.2 reflection ripple bend)
### look (L380) `tiltShift: 1.0, focusBand: 0.18, paper: 0.24, vignette: 0.38, edgeFade: 0.05, detail: 1.0, pixelRatio: 1.0, haze: 0.5, edgeInk: 0.7, ground: 1.0`
### cinema (L383) `grade: 1.0, valleyMist: 0.8, shafts: 1.0, cirrus: 1.0, warmth: 0.6, vignette: 0.35, region: 1.0`
### intro (L385) `duration: 4.6, ink: [0.05, 1.35], wash: [1.0, 3.05], clouds: [2.7, 3.8], lightIn: [3.35, 4.55], title: [0.15, 3.3], startAlt: 2700`
### hotspot (L386) `radius: 700, labelMaxAlt: 4200, prompt: '按 E 落脚'`
### map (L387) `fov: 20, minView: 2400, maxView: 42000`

**Godot:** make a `Resource` script `XiuxianConfig.gd` with `@export` groups mirroring these blocks (keeps inspector tuning); or a
JSON `config.json` loaded into a Dictionary. Split "bake-time" keys (layout, terrain.grid/peakHeight/mainPeak/pillar/siteDetail/
hills/facetJitter, relief.*, sects.scale/clouds/cloudFall/cloudSink/spurs…, cloudSea.spread/hollow*, water.maskSize/depth/seaDepth,
ground.*, eco.*) from runtime keys (look, cinema, sun, light, flight, camera, zoom, clouds speed, sway…).

---------------------------------------------------------------------------------------------------------------------------------

## 4. Utilities, shared uniforms, GLSL noise (L448–500)

- `TAU = 2π` (L449); `NSITES = 6` (sects carried by shaders, L450).
- `clamp, lerp, smoothstep (Hermite 3t²−2t³), easeInOut (cubic), easeOut = 1−(1−t)³` (L451–455).
- `mulberry32(a)` PRNG (L456–463):
  ```
  a = (a + 0x6d2b79f5) | 0
  t = imul(a ^ (a >>> 15), 1 | a)
  t = (t + imul(t ^ (t >>> 7), 61 | t)) ^ t
  return ((t ^ (t >>> 14)) >>> 0) / 2^32
  ```
  GDScript port: use `int` and mask `& 0xFFFFFFFF`; emulate `Math.imul` as `((a*b) & 0xFFFFFFFF)` then convert to signed
  (`if v >= 0x80000000: v -= 0x100000000`). In Python use the same with `& 0xFFFFFFFF`. Byte-exact port is needed only if you
  want the *identical* layout (tree positions, peak lobes) — recommended to keep seeds reproducible.
- `hash2i(ix, iy, seed)` (L464–468): `h = imul(ix,374761393) + imul(iy,668265263) + imul(seed,1442695041)`; `h = imul(h ^ (h>>>13), 1274126177); h ^= h>>>16; return (h>>>0)/2^32`.
- `veil(mat)` (L472–476): custom blending — colour `src·α + dst·(1−α)`, alpha `dst·(1−α)` (alpha channel accumulates
  "how much is hidden" so the ink-edge pass doesn't draw outlines through clouds). In Godot: no direct equivalent in spatial
  shaders; emulate with a separate "occlusion" buffer (e.g. SubViewport pass writing coverage) used by the edge post effect.
- `hexRGB` (L477).
- Shared uniforms `U` (L480–489): `uTime, uInk, uWash, uCloudIn, uMap` (intro/map blends), `uFocus` (vec2), `uInkCol (0.24,0.27,0.31)`,
  `uMist (0.86,0.87,0.84)`, `uPaper (0.925,0.905,0.85)`, `uWind (0.9,0.25)`, `uAlt 1650`. Godot: **global shader uniforms**
  (Project Settings → Shader Globals; `RenderingServer.global_shader_parameter_set`).
- `GLSL_NOISE` (L491–500): `hash12` / `hash22` (Dave Hoskins "hash without sine"), `vnoise` (value noise, smoothstep fade),
  `fbm3` (3 octaves, lacunarity 2.03/2.01, offsets 17.1/5.3, normalised /0.875), `fbm5` (5 oct, ×2.02 + (13.7,5.1), /Σa).
  Ports 1:1 to Godot shading language (`fract`, `mix`, `dot` identical; put them in a `.gdshaderinc`).

---------------------------------------------------------------------------------------------------------------------------------

## 5. Optional assets (02, L502–562) and what happens when missing

- `BASE` (L502–506): `cloudTex, formationTex, hotspots, cards{}`, `anisotropy: 8`.
- `FILE_PAGE = location.protocol === 'file:'` (L507): when opened from disk **nothing external is loaded** (all loaders return null/false).
- `loadImage(url)` (L508–517) → `Image` or null (never throws). `loadJSON(url)` (L518–521) → object or null (`cache:'no-cache'`).
- `texFrom(source, opt)` (L522–533): `flipY=false`, `NoColorSpace` (textures treated as raw/linear values — colours were authored
  for a non-colour-managed pipeline; in Godot use `source_color` only if you want sRGB decode; to match, sample without
  `source_color` and output without tonemapping, or convert), clamp wrap by default, mipmaps + trilinear, anisotropy.
- `applyHotspots(js)` (L535–551): accepts `{ "name|id": [x,y] }` or `[{id|name, x, y}]` in base-map px; for each matching POI
  (id, name, or name without " ↗") converts with `FRAME.toWorld`; if moved ≥ 1 丈: sets `p.pos`, `p.fixed = true`, and also moves
  `LAYOUT.sects[p.at]` / `LAYOUT.marks` with the same id, then re-targets `TRAIL`. Must run **before** world planning to move sects.
- `loadOptional()` (L552–562): parallel `details.json`, `hotspots.json`, `cloud.png`, `formation.png`. details → `BASE.cards[id]=file`.

### 5.1 Data files

`hotspots.json` (215 B): `{"古剑门":[559,351],"落云宗":[768,383],"百巧院":[384,449],"天柱山":[240,404],"云梦山":[570,406],
"灵眼之树":[498,473],"韵州城":[777,506],"封日城":[1127,179]}` — **identical to the built-in pins/geo**, so it moves nothing (<1 丈
test). Keep as an override file in Godot.

`details.json` (273 B): `[{id:'gujian',file:'card_gujian.jpg'},{luoyun},{baiqiao},{lingyan},{minzhou}]` → info-card paintings
`demo/card_*.jpg` (~115–145 KB each).

`cloud.png` (341 KB), `formation.png` (262 KB): brush/pattern textures; fallbacks are built-in/procedural (elsewhere).

`assets/ground_{grass,dry,snow,cliff,mud}.jpg` (2–18 KB): **all five or none** (`loadGround` L690–700: if any missing → false);
loaded with repeat wrap, aniso 4, into `LU.tDetail0..4`, `LU.uDetail = CONFIG.look.ground`, `PACK.ground = true`. Ground shader
skips them until present.

---------------------------------------------------------------------------------------------------------------------------------

## 6. Places (02, L564–647)

POI schema: `{ id, name, cat, ally?, type, at? | geo?, banner (label altitude-ish, 丈), sub, crumb, lead, body[], note?, chips?, hotspot? }`.
Position resolution `placePois()` L643–646: `geo` (px) → `toWorld`; else `at` → `LAYOUT.sects[at]` or `LAYOUT.marks[id==at]`; else (0,0,0).
`p.pos = [x, 0, z]`. `POI_BY` by name (L637); `LEGEND_OF` cat→legend class (L638); `MINOR` = route stops (L639);
`TRAIL` 韩立行迹 = luoyun '入落云宗', lingyan '试剑大会', zimu '子母峰洞府' (L641).
`CRUMB = '天南 › 溪国 › 云梦山'` (L564), `CRUMB_E = '天南 › 天道盟 › 封日城以东'` (L611).

### 6.1 Complete place list

| # | id | name | cat | type | position source | world x, z | banner | hotspot | lead (abridged) |
|---|---|---|---|---|---|---|---|---|---|
| 1 | gujian | 古剑门 | sect (天道盟) | 宗门 | at gujian | −658, −2516 | 1500 | ✓ | 云梦三宗之一，坐镇主脉，以御剑立派 (L566–570) |
| 2 | luoyun | 落云宗 | sect | 宗门 | at luoyun | 11 477, −658 | 1500 | ✓ | 据云梦山东脉 (L571–575) |
| 3 | baiqiao | 百巧院 | sect | 宗门 | at baiqiao | −10 819, 3174 | 1500 | ✓ | 据西脉，以炼器闻名 (L576–580) |
| 4 | yunmeng | 云梦山 | mount | 山川 | at yunmeng (mark mainPeak) | −19, 677 | 1600 | ✓ | 溪国西部灵气圣脉; chips list (L581–584) |
| 5 | tianzhu | 天柱山 | mount | 山川 | at tianzhu | −19 179, 561 | 1500 | ✓ | 孤峰，传说高达万余丈 (L585–586) |
| 6 | lingyan | 灵眼之树 | secret | 秘境 | at lingyan (px 498,473) | −4200, 4567 | 1200 | ✓ | 三大神木之一 (L587–590) |
| 7 | swamp | 绿踪沼泽 | secret | 秘境 | at lvzong (px 652,425, r 1500) | 4742, 1781 | 1300 | — | 古剑门与落云宗交界 (L591–592) |
| 8 | zimu | 子母峰 | mount | 山川 | at zimu (px 852,402) | 16 354, 445 | 1200 | — | 韩立洞府所在 (L593–594) |
| 9 | tingyun | 听云亭 | feat | 途中地名 | at tingyun (706,374) | 7877, −1181 | 900 | — | 古剑门→落云宗 (L595) |
| 10 | feilian | 飞练崖 | feat | 途中地名 | at feilian (506,366, yaw −0.25) | −3735, −1645 | 950 | — | 古剑门→百巧院 陡崖 (L596) |
| 11 | guxiu | 古修洞府 | feat | 途中地名 | at guxiu (448,398) | −7103, 213 | 900 | — | 废弃古修洞府 (L597) |
| 12 | sunshi | 笋石林 | feat | 途中地名 | at sunshi (448,437) | −7103, 2477 | 950 | — | 石峰密如竹笋 (L598) |
| 13 | yingxian | 迎仙松 | feat | 途中地名 | at yingxian (514,426) | −3271, 1839 | 900 | — | 崖顶古松 (L599) |
| 14 | dimai | 地脉灵眼 | feat | 途中地名 | at dimai (690,396) | 6948, 97 | 950 | — | 灵脉节点 (L600) |
| 15 | yunzhoucheng | 韵州城 | city | 城池 | geo 777,506 | 11 999, 6483 | 1200 | ✓ | 落云宗正南七千丈 (L601) |
| 16 | xiguo | 溪国 | region (天道盟) | 国度 | geo 852,520 | 16 354, 7296 | — | — | 天南最北部的国家 (L602–604) |
| 17 | yunzhou | 韵州 | state | 州府 | geo 800,548 | 13 335, 8922 | — | — | 溪国诸州之一 (L605) |
| 18 | tiandao | 天道盟 | alliance | 势力 | geo 1010,262 | 25 527, −7683 | — | — | 天南四大势力之一 (L606) |
| 19 | sea | 无边海 | sea | 海域 | geo 820,110 | 14 496, −16 508 | — | — | 天南北面的大海 (L607) |
| 20 | minzhou | 封日城 | city | 城池 | geo 1127,179 | 32 320, −12 502 | 1500 | ✓ | 闵州州府 (L608) |
| 21 | luanming | 鸾鸣宗 | sect (天道盟) | 宗门 | at luanming | 70 710, 6338 | 1500 | ✓ | 天道盟三大宗门之一 (L613–616) |
| 22 | nihang | 倪航斋 | sect | 宗门 | at nihang | 96 483, −8299 | 1500 | ✓ | 据东部大山; 乾土功 (L617–620) |
| 23 | shuiying | 水影宗 | sect | 宗门 | at shuiying | 87 535, −21 676 | 1500 | ✓ | 临无边海 (L621–624) |
| 24 | qiling | 七灵岛 | secret | 秘境 | geo 1090,−445 | 30 172, −48 732 | 1700 | ✓ | 大漩涡以南七座灵岛 (L625–628) |
| 25 | lingao | 灵鳌岛 | mount | 岛屿 | geo 1143,−356 | 33 249, −43 565 | 1300 | — | 韩立所得之岛 (L629) |
| 26 | linggui | 灵龟岛 | mount | 岛屿 | geo 1177,−521 | 35 223, −53 144 | 1300 | — | 太真门所占 (L630) |
| 27 | lingfeng | 灵凤岛 | mount | 岛屿 | geo 1043,−543 | 27 443, −54 422 | 1300 | — | 合欢宗所占 (L631) |
| 28 | vortex | 大漩涡 | secret | 秘境 | geo 1084,−625 | 29 824, −59 183 | 1800 | ✓ | 封印大阵阵眼被破坏后形成 (L632–635) |

The `body` / `note` strings (long Chinese descriptions of each sect's diorama layout — terraces, halls, rocks) are design specs
for the Blender modelling of each sect; copy them verbatim from L566–635 into the Godot POI JSON (`pois.json`), keeping `lead`,
`body[]`, `note`, `chips[]`.

### 6.2 Landmarks `LAYOUT.marks` (computeLayout L414–427)
`mk(id, type, px, extra)`; world positions as in table above:
`tianzhu:'tianzhu'`, `yunmeng:'mainPeak'`, `lvzong:'swamp' {r:1500}`, `lingyan:'spiritTree'`, `zimu:'zimuPeak'`,
`tingyun:'cloudPavilion'`, `feilian:'fallCliff' {yaw:-0.25}`, `guxiu:'caveAbode'`, `sunshi:'stoneForest'`,
`yingxian:'ancientPine'`, `dimai:'spiritNode'`.
`LAYOUT.sects` = gujian, luoyun, baiqiao (+ luanming, nihang, shuiying from pins, L410). `LAYOUT.edges` = three 云梦 edges with length (L411).

---------------------------------------------------------------------------------------------------------------------------------

## 7. Model pack — `assets/ym_pack.json` (02b, L652–811)

### 7.1 File format (inspected with python -I json)
- Standard **glTF 2.0 JSON** (`asset.generator: 'yunmeng pack builder'`, copyright: Stylized Chinese Lost Temple (Stylarts) and
  Meadow Environment (ANGRY MESH), via kk20054/ThreeJS-Stylized-World-Assets). Built by `tools/pack/build_pack.py` (comment L657).
- 1 scene, **79 root nodes** each `{name, mesh, scale:[1,1,1]}` (no translation/rotation — transforms baked), 79 meshes,
  109 primitives (identical meshes share accessors: 304 accessors = 76 unique prims × 4), **268 514 triangles** total.
- Attributes: `POSITION`, `NORMAL` (float VEC3), `TEXCOORD_0` (float VEC2), indices uint16. No tangents, no skins, no extensions.
- **1 buffer, 7 903 076 bytes, inlined as `data:application/octet-stream;base64`** (that's why the JSON is 10 MB).
- 108 materials: all `doubleSided: true`, metallic 0, roughness 1, `baseColorTexture` + `baseColorFactor`; 84 OPAQUE, 24 MASK
  (e.g. `alphaCutoff: 0.3`, leaves). Base colour only.
- 66 textures/images → `tex/<hash>-<size>.jpg|png` (all 66 present in `assets/tex/`; sizes 256…1024), 1 sampler (linear,
  LinearMipmapLinear, REPEAT).
- Node names (models): temple, bell, bridge, bridge2, stoneLamp2, lanternC, tablet1, tablet2, lotusStatue, potA, potC, vase3,
  rockT1, rockT2, pillarCluster, lilies, liliesB, liliesC, treeOrange, column, birchW, birchW2, birchA, birchA2, birchS, oakS,
  oakS2, oakA, spiritCyan, spiritRed, spiritBlue, spiritBushCyan, spiritBushPink, bushW, rock1, rock3, rock5, rock6, rock1W,
  rock3W, mush5, mush7, mush12, stump1, log1, fence6, statue, fence2, fence2W, fence8, fence8A, fence8W, plank1, plank2, log2,
  log1W, stump2, stump1W, rgroup4, rgroup4W, rgroup6, rgroup6W, rock2, rock2A, rock4, rock4A, rock7, rock7W, rock9, rock11,
  templeBase1, banner, templeBase2, roundBase, deer, lanternA, lanternB, stoneLamp1, maple.

### 7.2 Loading (`loadPack` L668–688)
GLTFLoader `loadAsync`; for each root node: collect mesh prims, compute `Box3`/size, `PACK.models[name] = {prims:[{geo,mat}], box,
size, tris}`. `PACK.ready` if any model and `PACK.open !== false` (late arrival after boot gave up → unused). Errors → `ready=false`.
`PACK.has(name)` (L689) gates every use; **builders fall back to procedural geometry when missing**.

### 7.3 Placement API
- `PACK_M = 10` 丈 per metre (L667) — "a 12 m temple becomes a 120 丈 hall". (Real 1 丈 ≈ 3.33 m; this is a stylised diorama scale.)
- `PACK.place(name, x, y, z, yaw=0, s=PACK_M, tint=[1,1,1,0], o={sx,sy,roll,pitch})` (L705–711): appends to
  `PACK.placements[name@floor(x/3000),floor(z/3000)]` (3000-丈 culling cells).
- `PACK.sizeOf(name, s)` (L713) = size × s; `PACK.baseY(name)` = box.min.y (L714).
- `buildPack(scene)` (L769–797): one `InstancedMesh` per (cell group, primitive); Euler order **'YXZ'** (pitch, yaw, roll);
  scale `(s·sx, s·sy, s)`; per-instance `aTint` vec4 attribute; `leaf` = name matches `/^(birch|oak|bush|maple|spirit|redLeaves)/`
  and material alphaTest>0; `far` = name starts with `mountain`; maple trunks untinted. `renderOrder 1`, frustum culled.
- `PACK_TINT` (L799–806) rgb multiply + w = desaturate-first amount:
  `ice [0.84,0.92,1.04,0.45]`, `jade [0.96,1.02,0.98,0.05]`, `gold [1.1,0.96,0.8,0.12]`, `none [1,1,1,0]`, `red [1,0.36,0.22,0]`,
  `orange [1,0.62,0.26,0]`, `golden [1,0.86,0.38,0]`, `green [0.56,0.76,0.4,0]`, `frost [0.94,0.98,1.04,0.3]`, `rime [1.3,1.36,1.44,0.92]`,
  `rose [1.06,0.94,0.94,0.08]`, `ochre [1.1,1.0,0.82,0.18]`, `lake [0.9,1.0,1.06,0.12]`, `blossom [1.0,0.68,0.74,0]`.

### 7.4 Pack material (PACK_VS/PACK_FS L714–749, `packMaterial` L750–765)
VS: world pos = model·instance·pos; `wp.y *= 1 − uMap` (flattens everything when switching to the 2-D map). FS:
```
tx = (hasMap ? tex(uv) : 1) * uBase;  if tx.a < uCutoff discard
lum = dot(base,(0.3,0.59,0.11)); base = mix(base, mix(base, lum, tint.w) * tint.rgb, uTintK)
N = faceforward; N = normalize(mix(N, up, uLeaf*0.55))      // leaves lit as one crown
s = sunAt(xz)  (baked mountain shadow map: r=cast light, b=AO)
t = min(softTones(dot(N,sunDir)), castLight(s.r))
col = toneCol(base,t) * mix(1, mix(0.84,1,s.b), uAO) + (0.016,0.02,0.018)*max(N.y,0)
col = lightOnGround(col, xz); col = mix(col, hazeMix(col,wp), uHazeK /*0.42 far, 1 near*/)
col = introMix(col, 0, (1−t)*0.32+0.06, xz)
```
(`GLSL_LIGHT` L4277, `GLSL_INTRO` L4255, `LU` L4227 — out of scope.) Cached by (map uuid, alphaTest, side, leaf/far/untinted, colour).

**Godot mapping:** import `ym_pack.json` directly — Godot 4 imports `.gltf` with embedded data URIs and external images (rename to
`.gltf`, keep `tex/` beside it). In Blender: File → Import glTF, then each root object is a model; scale ×10 when instancing in 丈.
Use **MultiMeshInstance3D** per (model, surface, 3000-丈 cell) with `use_custom_data` = tint (rgb, w) → read `INSTANCE_CUSTOM` in a
shared ShaderMaterial (the toon 3-tone + baked shadow + haze). Or bake placements offline into `placements.json` and spawn
MultiMeshes at load. Set `visibility_range_end` on far cells instead of the JS cell skip.

---------------------------------------------------------------------------------------------------------------------------------

## 8. Meadow impostor cards — `assets/eco.json` + atlases (02c, L813–1025)

### 8.1 Files
- `eco.json` (34.5 KB): `{ atlas: [2048, 2048], models: {73 entries}, frames: [216 entries] }`.
  - `frames[i] = [u, v, w, h, a0, a1, v0, v1]`: atlas rect in UV (0..1) and the image's extents in metres (horizontal a0..a1,
    vertical v0..v1, relative to the plant's foot). E.g. frame 0 = `[0.324707,0.098145,0.053223,0.091797,-2.632,2.6746,-0.4396,8.713]`.
  - `models[name] = { src (Meadow asset name), kind: tree|bush|plant, pitches: [35,60] (trees/bushes) or [48] (plants),
    frames: [[f_pitch0, f_pitch1], …] one row per "turn" (2 turns each), h (m), r (m), crown {c:[x,y,z], e:[x,y,z]} }`.
  - Kinds: 25 trees, 10 bushes, 38 plants. Names = `ECO_NAMES` (L816–825, 73 names; suffix S summer, A autumn, W winter, D dry;
    spirit*, sbush*, sgrass* = 灵地 coloured; mapleR/O/G).
- `eco_albedo.webp` (297 KB, RGBA: colour + coverage alpha) and `eco_normal.webp` (1.45 MB, RGB normal in card space, **A = AO/
  occlusion** used as `nm.a`). Baked by `tools/impostor/bake.py` from the camera side (south, looking north) at 35° and 60° (L808–812).

### 8.2 Loading (`loadEco` L827–848)
Needs all three (json + two images) else `false` → trees stay procedural, **no flowers**. Builds `tFrames`: a `n*3 × 1` RGBA32F
DataTexture, 3 texels per frame: `[u,v,w,h]`, `[a0,a1,v0,v1]`, `[sin(pitch), cos(pitch), pitch, 0]` (pitch from the model's
`pitches[pi]` per column of each turn row). Nearest filter.

### 8.3 Instance lists
`EcoList` (L854–866): flat Float32Array, **10 floats per card**: `id, x, y, z, scale, tint r, g, b, w, groundFlag`. `ECO.place`
(L868–872) → `ECO.extra`; the planners (03c, out of scope) produce more lists. `ECO.heightOf(name)` = model `h` (m).

`buildEco(scene, lists)` (L965–1008): cells of **2600 丈**, trees and ground plants separate (`key = (ci*1000+cj)*2+ground`);
counting pass then inside-out shuffle (seed `mulberry32(4242)`) so the first n of each cell are a random subset (used for density
thinning by `instanceCount`). Packed per instance: `iPos` float4 (x,y,z,scale), `iData` uint16×4 (frame pitch0, frame pitch1, 0,
r·65535), `iTint` unorm8×4 (rgb·0.5, (w+1)·0.25). Bounding sphere per cell.

### 8.4 Card vertex/fragment shader (ECO_VS L871–904, ECO_FS L905–942)
VS: `pa = clamp(asin(dirToCam.y), 0.12, 1.45)`; frame = steep one if `pa > mix(P0.z, P1.z, 0.35+0.3·r)` (per-card threshold →
no global pop); card stands at the plant's front: `rf = max(0, −E.z / max(P.x, 0.2))`, `h0 = (E.z + rf·P.x)/cos(pa)`,
`h1 = (E.w + rf·P.x)/cos(pa)` (stretched by 1/cos(pitch) so it appears as drawn); horizontal from E.x..E.y along the camera-right
vector `Rw = (Fh.y, 0, −Fh.x)`; wind: `gust = 0.55+0.45 sin(0.31t + dot(xz,(0.0019,0.0012)))`,
`sw = 0.65 sin(1.5t + 6.2832r + 0.011x) + 0.25 sin(2.6t + 3.1r + 0.017z)`, displacement ∝ `corner.y² · uSway · min(1,(E.w−E.z)·0.12)`.
FS: reconstruct atlas uv from card-space (a, v); discard outside; alpha-to-coverage when MSAA (`POST.samples>0`) else cutoff 0.5;
normal from atlas mapped to (Rv, Uv, Fv) basis; tint w>1.5 → snow on up-facing leaves (`ECO_TINT.frost`), ground plants lit as a
flat dab `tn = mix(tn, 0.78, 0.42)`.
`updateEco(A)` (L1011–1025) thinning by altitude A: trees `kt = clamp((1400/A)^1.35, 0.07, 1)·density·eco.trees`; ground
`kg = clamp((1300/A)^2.2,0,1)·eco.ground·(1−smoothstep(2600,3600,A))`; distance factor `kd = clamp((near/d)², 0.12, 1)` (trees,
near = 1.25A) or `clamp((0.9A/d)², 0.06, 1)` (ground), d = cell centre distance − 1300.

**Godot mapping:** reproduce with **MultiMeshInstance3D** per 2600-丈 cell, a quad mesh, `INSTANCE_CUSTOM` = (frame0, frame1, r,
tint packed) and `COLOR` = tint; frames table as a small `Texture2D` (RGBAF, `texelFetch`) or a uniform array; set
`multimesh.visible_instance_count` per frame for thinning (exactly like `instanceCount`). Billboard logic must be in the vertex
shader (not `billboard` flag) because of the foot offset and 1/cos stretch. Alternatively in Blender re-bake impostors with
"Octahedral Impostors" addon — but since the camera never yaws, the 2-pitch atlas is sufficient and much cheaper.

---------------------------------------------------------------------------------------------------------------------------------

## 9. Section 03 — world planning algorithms

Build order (`buildWorld` L2347–2379):
```
loadGeo → planCoast → planSites → planTerrain → planCities(L11366) → planRelief(03a L2453) → LF.afterRelief(S) (03l)
→ buildHeightfield → buildPatches → planSectClouds → planFalls → planReliefRivers(L2757) → planWater → paintWaterMask
→ buildWaterField → planMarsh → carveWater → planRoads(L2910) → planGround(L3029) → planSeasons(L3280) → planBiomes(L3536)
→ planSectSpots(L8043) → planSectZones(L9815) → planTrees(L3107) → planEcoGround(L3362) → planClouds → planCloudSea → planSpires
```
Each step is timed into `WORLD.stats.t` (and heap MB). `WORLD` state object: L1063–1068.

### 9.1 JS noise `NZ` (L1034–1061)
- Permutation: 256 entries shuffled by Fisher–Yates with an inline mulberry32 seeded **977**; `perm[i] = p[i & 255]` for 512.
- `simplex2(x, y)`: classic 2-D simplex (Gustavson), `F2 = 0.5(√3−1)`, `G2s = (3−√3)/6`, gradient table
  `G2 = [1,1, -1,1, 1,-1, -1,-1, 1,0, -1,0, 0,1, 0,-1]` indexed `(perm[...] & 7)*2`, falloff `t = 0.5 − x² − y²`, contribution
  `t⁴ · dot(g, d)`, result `70·Σ` ∈ ≈[−1, 1].
- `fbm(x, y, oct)`: `Σ am·simplex2(x·f + 19.1 i, y·f − 7.7 i) / Σ am`, `am *= 0.5`, `f *= 2.03`.
- `ridged(x, y, oct)`: `s = (1 − |simplex2(x·freq + 31.7 i, y·freq − 17.3 i)|)²·w; w = clamp(2s, 0, 1); sum += s·amp`;
  `freq *= 2.07, amp *= 0.52`; returns `sum/Σamp` ∈ [0,1].
- **Port:** Godot's `FastNoiseLite` simplex is *not* identical (different gradients/scale). For a faithful bake, port this exact
  code to Python (numpy-vectorised) — 40 lines. GDScript port is straightforward but slow for 6.6 M samples → bake offline.

### 9.2 Helpers (L1070–1073)
- `smax(a, b, k)`: polynomial smooth max `h = clamp(0.5 + 0.5(b−a)/k, 0, 1); lerp(a,b,h) + k·h(1−h)`.
- `hunion(a, b, k)`: if b ≤ 0 → a; `kk = min(k, 0.5·min(a,b))`; kk > 1 ? smax(a,b,kk) : max(a,b) — blend narrows near the plain
  so mountain feet don't swell.
- `SEA_FLOOR = −26` 丈.

### 9.3 Coast: detail + signed distance (`planCoast` L1108–1146, `rasterSea` L1147–1161, `chamfer` L1169–1186, `seaDist` L1162–1168)

```
onF(px,py) = |px−F.x0|<0.7 or |px−F.x1|<0.7 or |py−F.y0|<0.7 or |py−F.y1|<0.7
pushOut(px,py) = toWorld(px,py) pushed 4000 丈 outward along each frame side it lies on
ring(C, s0, amp):                       # C flat px array; s = running arc length (world)
  for each edge A→B (closed):
    if onF(A): emit pushOut(A)
    if onF(A) and onF(B): continue      # edge along frame: no shoreline
    L = |B−A| (丈); m = max(1, ceil(L/45)); n̂ = ((B.z−A.z)/L, −(B.x−A.x)/L)
    for k in (1 if onF(A) else 0) .. m−1:
      t = k/m; ss = s + L·t
      d = amp·(62·fbm(ss/1150 + 3.1, 0.7, 3) + 17·simplex2(ss/205, 5.5))
      emit lerp(A,B,t) + n̂·d
    s += L
WORLD.coast     = ring(GEO.coast, 0, 1)                    # ~±80 丈 coves/headlands, resampled every ≤45 丈
WORLD.isleRings = ring(island.pts, 9000·(i+1), 0.5) each   # + centroid (x,z) and r = max vertex distance
```
Coarse SDF on 100-丈 cells over the rect: `m = rasterSea(W,H,0)` (canvas fill, **even-odd**: coast ring + island rings → 255 sea);
`inD = chamfer(m, water=true, cap 90)`, `outD = chamfer(m, water=false, cap 90)`;
`sea[i] = (m≥128 ? inD−0.5 : 0.5−outD)·100` → **+ inside sea, − on land**, saturates at ±9000 丈. `seaDist(x,z)` bilinear.

`chamfer` = two-pass 3×3 (1, √2) distance transform: pixels of the target class start at `cap`, others 0; forward pass uses
W, N, NW, NE; backward uses E, S, SE, SW.

**Python/Blender bake:** use `shapely` / `matplotlib.path` or `PIL.ImageDraw.polygon` with even-odd (draw sea, then XOR islands),
`scipy.ndimage.distance_transform_edt` on both classes for an exact SDF (better than chamfer; results differ ≤ ~8 %). Save as
float32 EXR (`sea_sdf.exr`, 1318×802) or encode signed 16-bit.

### 9.4 Peaks: lobed profile `(1 − q^a)^b` (`makePeak` L1188–1207, `peakH` L1208–1217, `indexPeaks` L1219–1226)

```
makePeak(x, z, h, r, o):
  rnd = mulberry32(((round(x·7.3)·73856093) ^ (round(z·3.1)·19349663) ^ (o.seed||0)) >>> 0)
  sword = o.kind == 'sword'
  lobes = o.lobes || (sword ? 3 + floor(rnd·2) : 4 + floor(rnd·4))
  amp   = o.spur ?? (sword ? 0.16 + 0.08 rnd : 0.2 + 0.14 rnd);  ph = rnd·2π
  for i in 0..15: a = i/16·2π; lobe = |cos(a·lobes/2 + ph)|^1.6
                  prof[i] = 1 − amp + 1.55·amp·lobe + (rnd − 0.5)·0.16;  prof[16] = prof[0]
  ang = o.ang ?? rnd·π
  reach = r·max(prof)·(o.ax ? 1 : 1.02)
  ax = o.ax || (sword ? 1.45 + 0.35 rnd : 1 + 0.32 rnd)      # elongation across the ridge axis
  a  = o.a  || (sword ? 1.02 + 0.1 rnd  : 1.18 + 0.55 rnd)   # shoulder sharpness
  b  = o.b  || (sword ? 1.45 + 0.25 rnd : 1.15 + 0.35 rnd)   # summit pointiness
  (NB: rnd() call order matters — lobes, amp, ph, 16×prof jitter, ang, ax, a, b)
peakH(p, x, z):
  if dist² ≥ reach²: 0
  u =  dx·c + dz·s;  v = (dz·c − dx·s)·ax;  d = √(u²+v²);  if d < 1e-3: h
  f = (atan2(v,u)/2π + 1)·16 mod 16 → i, t;  pr = lerp(prof[i], prof[i+1], t)
  q = d / (r·pr)
  return q ≥ 1 ? 0 : h·(1 − q^a)^b
```
Ridges ("余脉") arise because the radial profile `pr(θ)` has `lobes` maxima: the footprint is a star; with `b > 1` the flanks are
concave, between lobes are gullies. Spatial index: `WORLD.pcell = 500` 丈 buckets keyed `i*100003+j` (L1218).

Designed peaks (`planTerrain` L1710–1778; `ph = terrain.peakHeight`):
| feature | centre | peaks (dx, dz, h, r) & options | line |
|---|---|---|---|
| 云梦山主峰 | mark yunmeng | (0,0, MP=580, 0.56 MP) `{a:1.32,b:1.22,lobes:6,spur:0.3,ax:1.08,seed:1,name:'云梦山'}` + 3 shoulders (−640,−300, .72MP, .4MP), (620,−360, .68, .38), (60,−760, .66, .36) seeds round(dx+dz) | 1732–1737 |
| 天柱山 base | mark tianzhu | (0,0, 380·ph, 900) `{a:1.45,b:1.25,lobes:7,spur:0.26,ax:1.05,seed:61}`; `WORLD.pillar = {h: 1300, r: 230}` (column mesh elsewhere) | 1739 |
| 古修洞府 | mark guxiu | (0,0,270,220), (−210,80,175,150), (190,110,158,140) seeds 71.. `{a:1.25,b:1.3}` | 1741 |
| 子母峰 | mark zimu | (0,0,560,300) name '子母峰', (340,110,262,160), (−260,270,242,150), (−60,−370,282,170) seeds 51.. | 1743 |
| 七灵岛 | each isle ring centroid + 0.12 r offset at random angle | spec h, r-fraction: lingfeng 380, 0.42 {a1.3 b1.2 lobes5 spur.22}; linggui 170, 0.6 {1.1,1.1,6,.12}; lingao 300, 0.5 {1.2,1.2,6,.2}; qiling 240, 0.46; others 200+60rnd, 0.45; if r > 1600 a second knob (90+60rnd)·ph, 0.22 r at the opposite side | 1746–1751 |
| 大漩涡 | pin vortex | `WORLD.vortex = {x,z,r:1500}` | 1752 |

Exclusion discs `WORLD.excl` (L1715–1729): each sect R+560; yunmeng 1700; tianzhu 1500; zimu 1250; marks swamp 2100, spiritTree
2000, fallCliff 1150, caveAbode 950, stoneForest 1100, ancientPine 900, spiritNode 950, cloudPavilion 850; cities yunzhoucheng 1600,
minzhou 1500; startPos 700.
Clearings `WORLD.clear` (L1755–1758): yunzhoucheng r0 760, minzhou 900 (r1 = r0+480); swamp r0 700, r1 1350.
`clearFactor(x,z)` (L1661–1665) = Π smoothstep(r0, r1, d) inside r1.

### 9.5 Plains hills (`WORLD.hillAt` L1760–1775)
Cells of 430 丈, lazily cached. Centre `((i + 0.2 + 0.6·hash2i(i,j,71))·430, (j + 0.2 + 0.6·hash2i(i,j,72))·430)`.
```
D = densityAt(c); foot = smoothstep(0.06,0.2,D)·(1−smoothstep(0.3,0.5,D))
grp = smoothstep(0.35,0.62, fbm(cx/5200+3.3, cz/5200−1.1, 2))·(1−smoothstep(0.25,0.45,D))
p = terrain.hills·(0.06·foot + 0.05·grp)
accept if hash2i(i,j,73) < p and seaDist < −500 and !blocked(c, −300) and clearFactor > 0.95
r3 = hash2i(..74); a = (simplex2(cx/3000, cz/3000)+1)·1.6 + hash2i(..76)·0.8; r = 200 + 170·hash2i(..75)
hill = {h: 30 + 60·r3², r, r2: r·(0.4 + 0.3·hash2i(..77)), c: cos a, s: sin a}
height (baseHeight L1676–1684, only where h < 40): u = (dx c + dz s)/r, v = (−dx s + dz c)/r2, t2 = u²+v²; h = max(h, hill.h·(1−t2)^1.4)
```

### 9.6 Landmark shapes (`markHeight` L1615–1660; d = distance to mark)
- **cloudPavilion 听云亭** (d < 380): `t = d/150`; `max(h, 300·(t<0.6 ? 1−0.05t : max(0, 1 − smoothstep(0.6,2.4,t)^0.55)))` — a pillar with a flat crown.
- **fallCliff 飞练崖** (|u|≤900, |v|≤760 in yaw frame): `along = smoothstep(900,520,|u|)`; `top = 290 + 30·simplex2(0.0035u,1.3) + 14·simplex2(0.018u,4.1)`;
  `back = top − max(0,−v)·0.42`; `front = v>0 ? top − (v/16)^1.6·60 : back`; `f = max(0, v>0?front:back)·along`;
  `lim = lerp(h, min(h,40), smoothstep(460,320,v)·smoothstep(−40,40,v)·smoothstep(1000,800,|u|))` (keeps the plunge pool clear); return `max(lim, f)`.
- **caveAbode**: unchanged (its 3 crags are peaks).
- **ancientPine 迎仙松** (d<520): `t = d/260`; `max(h, 160·max(0, 1 − min(1, t/1.9)^1.3))`.
- **spiritNode 地脉灵眼** (d<420): broken ring: `brk = smoothstep(−0.2,0.35, simplex2(1.8cos a + 4.2, 1.8 sin a))`;
  `ring = max(0, (60 + 34·ridged(2.5cos a, 2.5 sin a, 2))·brk·exp(−((d−165)/(48 + 14·simplex2(2a,1)))²))`;
  `max(lerp(h, min(h,6), smoothstep(280,170,d)), ring)`.
- **spiritTree 灵眼之树** (d<1300): basin open to the south: `open = smoothstep(0.55,1.25, |wrap(a − π/2)|)`;
  `crag = 0.62 + 0.6·ridged(0.0025x+3.1, 0.0025z−1.7, 3)`;
  `ring = (300 + 60·simplex2(2cos a, 2 sin a))·crag·exp(−((d−860)/(170 + 50·simplex2(1.5a,2.2)))²)·lerp(0.12,1,open)`;
  `max(d<640 ? 0 : h·smoothstep(860,1250,d), ring)`.
- **stoneForest 笋石林** (d<760): `max(d<700 ? min(h,30) : h, 30·max(0, 1−d/760))` (spires are separate meshes, §9.13).

### 9.7 Sect definitions `SITE_DEFS` (L1235–1415) and `planSites` (L1487–1589)

Local frame: u east, v south, units 丈 × `k = CONFIG.sects.scale`. In v4.4 **every sect has `land: {kind: nat*}`** and
`cols: []`, so the old column/link/ridge/plat machinery (`makeCol` L1417, `colH` L1430, `colWall` L1451, `makeLink` L1462,
`linkH` L1468, `ridgeH` L1481, `siteHeight` L1590, `sectFloor` L1696) is **dormant** — `siteHeight` returns h unchanged (no cols,
links, ridge or hard plats; landform plats are `soft`), and `baseHeight` skips `sectFloor` for sites with `S.land` (L1687). The
actual sect ground comes from the landform system `LANDFORMS[kind]` (03e L3661 / 03l L3729, `LANDFORMS.nat*` L4200–4206) — see
the other notes file. The defs below are its input data.

| sect | R | look | cloud | base | land.kind / R mult | masses (id u v r h u0 [ax rot]) | benches / pads / extras | dome |
|---|---|---|---|---|---|---|---|---|
| gujian 古剑门 (granite, snow:1) | 1250 | ice | 482 | 324 | natGranite, 1.6, edge .72 core .86 coreValley .55 | taibai 60 −580 340 940 1.65 1.3 0.1; jiange −310 −330 210 806 1.4 1.35 1.35; dongling 390 −340 220 784 1.35 1.35 1.75; beiling −150 −1010 320 840 1.4 1.7 −0.2; xiqian −330 110 200 640 1.05 1.3 1.2; dongqian 370 90 190 624 1.0 1.3 1.9; shanmen 110 470 200 566 0.9; xiling −900 −220 250 666 1.05 1.4 1.2; dongfeng 880 −80 240 642 1.0 | bench `court` (40,−210) w400 d420 rise176 soft120 above100, steps gate(a−185 w110 d36), arena(a−110 r62), main(a−2 w236 d92), rear(a96 w196 d72), crown(a170 w112 d44), west/eastYard(a−110 s∓140 w96 d104), west/eastUp(a70 s∓165 w86 d76); pads jiange/dongling r20 search60 pct.45, stele (110,470) r24 search90 pct.4; roadFoot [100,1260] | (40,−260) rx760 rz760 ry700 #eef0f2 α.32 |
| luoyun 落云宗 (sandstone pillars) | 1250 | jade | 472 | 326 | natPillars 1.6, core .92 coreValley .5 | tianquan −600 −560 300 790 1.5 1.1 −0.6; huoyun 600 −540 280 756 1.45 1.15 0.5; beifeng 0 −930 300 812 1.5 1.5; baifeng 860 90 250 664 1.25; yinjian −860 40 230 654 1.2 1.6 1.4; huanshi −420 600 240 600 1.1; suoyan 380 640 220 588 1.05; p1..p6 small pillars (±190..550, r105–120, h542–610) | pads tqTop/hyTop/bfTop/yjTop/hsTop/syTop/bkTop (cellNear); **islands** main (0,−215) y716 r130 ex1.25 kind luoMain fixed; gate (0,50) y636 r46; sutra (−245,−330) y760 r60; alchemy (245,−310) y734 r58; elder (−80,−600) y848 r52; lodge (380,70) y648 r62; herbs (−380,70) y624 r72; arena (−20,340) y590 r50; noDrift; roadFoot [0,1300] | none |
| baiqiao 百巧院 (volcanic, maple:1) | 1250 | gold | 476 | 330 | natVolcanic 1.6 | fengwo 0 −580 380 946 1.65 1.6 0; west −450 −230 240 762 1.4 1.5 1.45; east 450 −210 240 744 1.4 1.5 1.65; shelf 0 −150 300 604 1.05 1.4; sw −380 200 160 566 .95; se 400 190 160 556 .95 | face {u0 −270 u1 270 v −362 bow 24 top 830 drop 26 cut false}; bench yard (0,−150) w540 d420 rise36 soft120 backSoft18 above92 steps gate/front/round(r64)/main(dy6)/west/eastCourt(s∓200); pads ta (−232,−322), westTop, eastTop; puppets []; roadFoot [60,1300] | (0,−200) 720/660/640 #f2cd8f α.24 |
| luanming 鸾鸣宗 (green hill) | 1250 | phoenix | 128 | 10 | natHill 1.5, coreWarp .46 coreAspect 1.2 low 'keep'; riverR 0; seaFloor false; **riverVia** 11 pts (−3300,3050)…(2650,−3450) | luan 0 −300 520 344 1.3 1.2; dong 560 −560 260 238 1.0; xi −580 −520 270 252 1.0; qian 0 130 260 150 .8 1.4 | bench palace (0,−170) w300 d460 rise190 soft110 above30 steps gate/t1/t2/main/back; pad summit (0,−500); forms perch (−330,−330) y366, cloud (330,−320) y356 'gathering', gateway (0,−690) y426 'teleport'; roadFoot [380,1500] | (0,−280) 760/760/520 #f2b8a8 α.22 |
| nihang 倪航斋 (loess 塬) | 1250 | earth | 182 | 120 | natLoess 1.5 core .8 coreValley .7 low 116 top 262 under 40; riverR 0; seaFloor false | yuan 0 −90 470 300 1.2 1.3 0.2; bei −160 −880 380 320 1.25 1.6; liang1 −620 120 240 270 1.0 1.8 0.7; liang2 600 60 240 266 1.0 1.8 −0.6; mao 120 640 200 236 .9 | **gullies** 8 polylines with width w 44–74 and depth d 66–108 (L1374–1379); bench bao (0,−100) w520 d380 rise10 soft90 above34 rag .5 steps gate/front/main/back; roadFoot [0,1500] | (0,−100) 640/640/460 #e8cf9a α.2 |
| shuiying 水影宗 (tower karst lake) | 1250 | water | 14 | 6 | natKarst 1.5 low 'keep'; sea:false (→ S.noSea); riverR 0; riverVia 5 pts | dao 0 −40 200 96 .9 1.2; bei −60 −1000 420 110 .9 2.0 | **lake** (40,−130) rx1000 rz660 rot .18 shore30 arms [[−560,300,−860,600,150],[620,−420,860,−640,140]]; **towerField** n26 clusters [[−640,−760,330,9],[260,−980,300,7],[900,−330,240,5],[−1050,−120,200,3]] r[38,84] h[70,210] islets10 isletRing[360,700] keep discs; bench isle (0,−60) w230 d250 rise66 steps t1/t2/t3/top; pad pier (0,560) r64 h7; roadFoot [0,1400] | none |

`planSites` details:
1. **Great rivers bend** once (`GEO.riversBent`, L1497–1510): convert each GEO river to world, `resamplePath(P, 300)` (L2751),
   offset each point along its normal by
   `m = (0.65·simplex2(s/9000 + 7.3qi, 1.7) + 0.35·simplex2(s/3500 + 2.1qi, 5.3))·700·smoothstep(0,4000,s)·smoothstep(0,4000,Ltot−s)`
   (normal = (−dz, dx)/l), store back in px. **Mutates GEO.rivers.**
2. **riverVia** (L1513–1527): for sects with `riverVia`, the run of the river within `reach = max|via|·k + 300k` is replaced by
   the via points (reversed if needed to keep direction).
3. **Push rivers off eastern sects** (L1528–1535): for luanming/nihang/shuiying, points within `Rm = (riverR ?? 2300)·k` are
   pushed radially to Rm (all three have riverR 0 → no-op now).
4. Per sect `S` (L1536–1588): `{id, idx, x, z, k, R: D.R·k, def, seed: idx·3.7+1.1, cols, col}`; `S.land = {edge 0.72, ...D.land,
   R: (D.land.R || 3)·S.R}` (so landform disc radius = 1.5–1.6 × 1250 = 1875–2000 丈); `S.noSea = D.sea === false`;
   spurs (6 random spurs; cleared when land); ledges/approach (none); `S.cloudBase = D.base·k`, `S.cloud = D.cloud·k`,
   `S.cutY = −1e9`; links from `D.range` (none); isles/islands/forms/dome converted to world with `y·k, r·k`;
   `S.patchRect = c ± (D.patch || 1250)·k` (fine-mesh rect); then `LF(S).setup(S)`.

`platDist(P,x,z)` (L1603–1609): rounded-box / disc SDF, optional yaw (`P.cs, P.sn`). `colH` (if ever used): fluted, lobed column
`wall = top − d/lean`, talus `top·foot·(1 − smoothstep(0, 0.55 top, d))`, spire cap `top + cap·q^0.75` or dome `top + dome·(1−(1−q)²)`.
`linkH`: crest `lerp(sA,sB,t) − dip·sin(πt)^1.2 + 15·simplex2(s/140)+6·simplex2(s/42)`, flank slope 1.25+0.3·sharp, gullies
`−22·smoothstep(12,70,dp)·ridged(x/115, z/115, 2)`. `ridgeH`: `hc = lerp(h0,h1,t^1.6) + 26 sin(πt)k`, sides fall 2.6 per 丈.

### 9.8 Heightfield composition (`baseHeight` L1668–1691, `terrainHeight` L1703–1707)

```
baseHeight(x, z):
  sd  = seaDist(x, z)
  lnd = landOf(x, z)                         # [S, weight] if inside a sect landform disc (L3677)
  if sd > 520: return lnd && LF(S).sea ? max(0, LF.height(S, x, z, 0, w)) : 0      # open sea
  h = reliefAt(x, z)                         # 03a erosion mountains (L2633)
  if h > 0.5: h += reliefDetail(x, z, h)     # cliffs & gullies on 40-丈 scale (L2652)
  for peak p in pgrid cell(x,z): v = peakH(p,x,z); if v > h − 60: h = hunion(h, v, 60)
  if h < 40: plains hills (§9.5, 3×3 cells of 430 丈)
  for mark in WORLD.marks: h = markHeight(mark, x, z, h)
  for S in sites without land, d < 1.1 R: h = max(h, sectFloor(S, …))   # dormant in v4.4
  h = cityRelief(x, z, h)                    # 06e (defined elsewhere, optional)
  h = max(0, h − 2.5)·1.004                  # faint swells stay plain
  h *= clearFactor(x, z)
  if lnd: h = max(0, LF(S).height(S, x, z, h, w))
  return h
terrainHeight(x, z) = baseHeight then for S with d² < R²: siteHeight(S, x, z, h)     # (identity in v4.4)
```
Heights are "above the plain" (plain = 0; water at −7/−20; sea cliffs −26).

### 9.9 Height grid (`buildHeightfield` L1783–1816, `gridX/gridZ` L1780–1781, `buildPatches` L1818–1848, `hAt` L1850–1859)
- `nx = ceil(Δx/g)+1 = 3296`, `nz = 2005` at g = 40 → 6.6 M Float32 (26 MB).
- Vertex jitter (not stored): interior vertices offset by `(hash2i(i,j,1|2) − 0.5)·jq`, `jq = 2·facetJitter·g = 25.6 丈`; rim
  vertices unjittered. Heights are sampled **at the jittered positions** — the mesh's faceted look depends on this.
- Sparse evaluation: 8×8-cell blocks marked occupied by any feature's reach (peaks reach+60, relief cells with h > 0.3 × 2.2 C,
  city hills, landform discs R+40, marks 1350, hills r+60); unmarked blocks stay 0. Async yields every 24 ms. Final: `H < 0.5 → 0`.
- Patches: for each sect, rect `S.patchRect` snapped to the coarse grid, subdivided `sub = siteDetail = 3`; edge vertices are
  bilinear from the coarse mesh (seamless, coarse uses −1.5 for 0 → "Y"), interior jittered by `hash2i(pi,pj,41|51+idx)·2·0.8·jit·g/sub`
  and evaluated with `terrainHeight`; `keep` flag = ground not raised by sect peaks (never cut). Patch `g/sub ≈ 13.3 丈`.
- `hAt(x,z)`: bilinear in patches if inside, else coarse grid (ignores jitter; "good to a few 丈").

### 9.10 Water

**planWater** (L1862–1879): moats from `WORLD.cityPlans` (or fallback squares half 420 minzhou / 270 others, r0 = half+40,
r1 = half+102); pools: 飞练崖 plunge pool at `fl + (−sin yaw, cos yaw)·380`, r 200, k 0.7; city lakes (`lakeRim`); 封日城 harbour
basin (`basinPoly`, harbour:true). Round pools get a 64-pt rim `r·(1 + 0.2·simplex2(1.3cos a + seed, 1.3 sin a) + 0.08·simplex2(3.1…))`,
z scaled by k.

**paintWaterMask** (L1881–1928): canvas `W = 4608`, `H = 2801` (≈28.6 丈/texel; the "≈22" comment predates v4.1). White = water:
coast ring + island holes (even-odd), pools; black (land) city-lake causeways (stroked polylines width w) and islands (ellipses);
moats as square annuli (even-odd); rivers `paintRivers` (L2895) onto mask + a flow canvas (`rgb(128,128,0)` base; R,G = flow
direction, B = river flag). Then landform water `lf.water(S,x,z,w)` max-merged per texel inside each disc (`landWOf` weight L3686).
`WORLD.seaLo` = sea-only raster 768×467 with 3 px blur.

**buildWaterField** (L1977–2010): chamfer in/out (cap 40 px) → SDF per texel `s = m≥128 ? inD−0.5 : 0.5−outD`, but for
anti-aliased coverage 0.02<c<0.98: `s = c − 0.5`; stored **Int16 in 1/8 丈** (`SDQ = 8`, L1976) → `WORLD.sd`. RGBA8 texture
`WORLD.waterData`: **R = 128 + sd/(2·SDQ)** (2 丈 per step, 128 = shore), **G,B = 128 + round(40·wind̂·sea)** (sea drift, or the
river flow direction where flow B > 200 and sea < 0.5), **A = sea factor·255** (bilinear from seaLo).
Accessors: `sdAt` (L2011, bilinear /SDQ), `seaAt` (L2017, nearest on seaLo), `waterLevelAt` (L2024: `−lerp(depth 7, seaDepth 20, sea)`),
`waterAt` (L2030; outside mask → seaDist>0).

**greatRiverD** (L2040–2050): 400-丈 bucket grid of great-river segments (pad 300); point-segment distance. `landRiverCarve` (L2038):
`lf.carveRiver` or `greatRiverD < 240`.

**carveWater** (L2052–2074), per coarse vertex with H>0:
```
if any landform and inside one and !landRiverCarve: skip
s = sdAt(x,z)
if s < −260: skip                                   # far inland
if seaAt > 0.5: if s > 0: H = SEA_FLOOR (−26)        # mountains plunging into the sea → cliffs
                continue
if s > −70: H = 0  else H *= smoothstep(−70, −260, s)   # banks ease down within 260 丈 of inland water
封日城 basin bbox (+margins) → SEA_FLOOR
```

**Marsh 绿踪沼泽** (`marshWet` L1932–1942, `marshReedField` L1943–1946, `planMarsh` L1947–1966):
```
marshWet(x,z): d = |p − sw|/R0 (R0 = 1500)
  (wx,wz) = p + 55·(simplex2(x/340+.7, z/340), simplex2(x/340+3.3, z/340−1.1))
  core = 1 − smoothstep(0.45, 1.0, d + 0.16·simplex2(x/700+9.1, z/700−3.3))
  big = fbm(w/330 + (5.1,−2.7), 2); med = simplex2(w/120 + (−3.7, 8.2)); sml = simplex2(w/40 + (1.1,−6.6)); mere = simplex2(w/700 + (−8.1,2.4))
  w = 0.62 big + 0.36 med + 0.14 sml − 0.3 + 0.18 core + max(0, mere−0.25)·0.9·core
  ch = 1 − |simplex2(w/900 + (1.7,−5.2))|; cw = 0.972 + 0.012·simplex2(w/260)
  w = max(w, (ch − cw)·14·smoothstep(0.2, 0.6, core))          # thin winding channels
  return w − (1 − core)·0.55                                    # > 0 = water
marshReedField(x,z,w) = clamp(max(smoothstep(−0.3,−0.04,w), smoothstep(0.05,0.17, fbm(x/210+2.2, z/210−9.1, 3) + 0.12 simplex2(x/60,z/60)))·smoothstep(−0.75,−0.4,w), 0, 1)
planMarsh: grid n = 560 over size = 2.3·R0 = 3450 丈 (c ≈ 6.16 丈); sd ≈ w/|∇w| clamped ±60; K = 1 − smoothstep(0.88,1.06, d + noise);
  K<0.5 → s = min(s, −60+120K); tex RGBA8 = (128 + 2s, reed·255, K·255, 255)
```
`marshSd` / `marshReedAt` bilinear (L1967–1975).

**Godot:** bake `water_mask.png` (L8), `water_field.png` (RGBA8 as above) and `marsh.png` (RGBA8 560²) offline; water surface =
large planes at y = −7 (inland) and −20 (sea) or a single plane whose vertex y reads the A channel; shore foam / colour bands from
R (SDF). Use `HeightMapShape3D`/collision only if you need landing on water edges.

### 9.11 Trees (only the region helpers are in range)
`regionK(id,x,z,r0,r1) = 1 − smoothstep(r0, r1, |p − sect|)` (L2076); `inSiteCore(x,z,f=0.86)` true inside 0.86 R of any sect
(sect peaks get their own trees, 06b) (L2077). `SECT_TREELINE` (L2232): ice 150, jade 290, gold 240, phoenix 270, earth 200,
water 290 → `sectTreeline(S) = S.cloud + treeline·k` (L2233). `sectWoodsK(S,x,z,h,crest,sl)` (L2235–2242):
```
lv = clamp(reliefLin(x,z,RELIEF.low) + cloudSea.valley, cloudSea.height, cloudSea.height + 330)
T = seaTopAt(x,z,lv); tl = sectTreeline(S)
band   = smoothstep(T − 60, T + 12, h)·(1 − smoothstep(tl − 90, tl, h))
stands = smoothstep(−0.2, 0.2, fbm(x/520 + 5.3 idx, z/520 − 1.7, 3) + 0.1·simplex2(x/140, z/140 + 3.3))
crestK = 1 − 0.45·smoothstep(30,110,crest); gully = smoothstep(8,55,−crest); steep = 1 − smoothstep(0.95,1.45,sl)
return clamp(band·steep·((0.12 + 0.88 stands)·crestK·0.95 + 0.3 gully), 0, 1)
```
The actual planting is `planTrees` L3107 (out of scope).

### 9.12 Clouds

**planClouds** (L2079–2121) → `WORLD.clusters[]` of `{x, z, r, n (cards), y0, y1, w0, w1 (card width range), op, kind, ring?}`
(kind 0 valley mist, 1 vortex spray, 2 waist belt ring, 3 sect wisps), seed `mulberry32(17)`:
- 天柱山 belt: r = 2.1·230, n 11, y 0.5–0.6·1300, w 300–520, op .92, ring.
- main peak belt: r = 0.42·580, n 10, y 0.4–0.5 h, w 320–560, op .9.
- per sect: waist belts on named cols (none exist in v4.4), skirts for `c\d` cols (none), then **`LF(S).clouds(S, clusters, rnd)`
  replaces** the generic wisps for landform sects (all of them now). Generic path: 4 wisps (r 140, n 2, y cloud+5..+45, op .5,
  kind 3); 落云宗 9 extra veils.
- 子母峰 ring at 0.45 h (op .75, n 6).
- 大漩涡: 10 spray clusters at r·(0.9–1.4), y 10..150, op .55, kind 1.
- Valley mist: up to 46 of 6000 random tries where `40 < hAt < 320`, `wetAt ≥ 0.55` (03a drainage), `seaDist ≤ −300`, not within
  1.2 R of a sect: r 220–440, y h+25..h+110, op = clouds.mist.
- Marsh: 9 clusters y 4–34, op .42.
- Falls: spray at the plunge (sect falls at cloud level; others at bottom+6..+40).

**planCloudSea** (L2125–2184) → `WORLD.cloudSea = {w:1648, h:1002, c:80, data: Uint8}` density 0..255:
```
h  = hAt at cell centres; hb = box(box(h,6),6)  (separable box r=6 cells twice ≈ 1000 丈 blur); hx = max-filter(h, 6) (±480 丈)
open discs: cities (minzhou 1500→2600, others 1300→2300); lingyan 1250→1900, feilian 700→1200, sunshi 800→1300, dimai 450→900, guxiu 500→900, yingxian 300→700
per cell (skip if seaDist > −200):
  massif = smoothstep(0.26, 0.5, density); among = smoothstep(12, 80, hb)
  big = fbm(x/4600+9.1, z/4600−4.4, 3); fine = fbm(x/1500+2.2, z/1500+7.7, 3)
  gather = smoothstep(−0.12, 0.34, big + 0.3 fine + 0.25(massif − 0.5) + 0.3(spread − 1))
  hollow = lerp(1, smoothstep(hollowLo 30, hollowHi 150, hx − h), cloudSea.hollow)
  v = max(massif·among, 0.4·massif)·gather·hollow
  puffs = smoothstep(−0.2,0.32, fbm(x/1050+3.1, z/1050−7.7, 3))·(0.75 + 0.25 smoothstep(−0.3,0.3, simplex2(x/420+1.3, z/420−2.9)))
  banks = smoothstep(0.5, 0.74, fbm(x/3200+5.5, z/3200−1.1, 3) + 0.15(spread−1))·(1 − massif)·0.55·(0.3 + 0.7 puffs)
  v = max(v, banks)
  ss = sectSeaAt(x,z); if ss.top > −1e8:
     lv = clamp(reliefLin(RELIEF.low) + valley, height, height+330); lifted = smoothstep(0, 60, ss.top − lv)·ss.w
     v = max(v·(1 − lifted), ss.dens·sects.clouds)
  v *= Π smoothstep(r0, r1, d) over open discs
  if landOf: v = lerp(v, lf.seaDens ? lf.seaDens(S,x,z,v) : 0, w)
  out = round(clamp(v·amount, 0, 1)·255)
```

**planSectClouds** (L2187–2229) → per sect `S.seaField = {x0, z0, c: 50, n, top[], dens[]}` covering ±2.4 R (n = ceil(4.8R/50)+1 = 121):
```
inside = landform seaCoreField/seaCore if provided, else discs: (S, 0.42R), cols r+150k, islands/forms r+170k, massif box
d = outward chamfer distance (丈) from inside
per cell:
  lv  = clamp(reliefLin(x,z,RELIEF.low) + cloudSea.valley, cloudSea.height, cloudSea.height + 330)   # 175..505
  w1 = fbm(x/640 + 3.1 idx + 0.7, z/640 − 1.9, 3); w2 = simplex2(x/230 − 5.3, z/230 + 2.1 idx)
  dn = max(0, d + (130 w1 + 35 w2)k − 40k)                     # ragged outline distance
  t  = max(seaFloor===false ? −1e9 : min(lv, S.cloud), S.cloud − dn·cloudFall(0.5))
  under = t − hAt(x,z); core = 1 − smoothstep(0, 110k, dn); open = smoothstep(6, 70, under)
  thin = 1 − smoothstep(0.45 sink, sink, S.cloud − t + 45 w1)   # sink = cloudSink 240·k
  fray = S.land ? 1 − smoothstep(0, (def.fray ?? 380)k, dn·(0.65 + 0.7·(0.5+0.5 simplex2(x/210 + 7.1 idx, z/210 − 3.3)))) : 1
  top = t; dens = max(core, open·thin·fray)
```
`sectSeaAt(x,z)` (L2244–2257): bilinear in each field, picks the highest top; border fade over 6 cells (`edge`).
`seaTopAt(x,z,lv) = s.top > −1e8 ? max(lv, lerp(lv, s.top, s.w)) : lv` (L2259–2262).
Sect cloud tops: gujian 482, luoyun 472, baiqiao 476, luanming 128, nihang 182; shuiying has no sea (noSea).

**Godot:** bake `cloudsea.png` (R8, 1648×1002) and per-sect `seafield_<id>.exr` (RG32F: top, dens; 121×121). The volumetric
cloud-sea itself (raymarch, `steps: 9`, `thick: 150`) can be a Godot spatial shader on a large plane/box at y ≈ top reading these
textures (or FogVolume with a density 3D texture — but a custom raymarch shader matches better). Card clouds → MultiMesh of
camera-facing quads with `cloud.png`.

### 9.13 Stone forest & waterfalls
`planSpires` (L2265–2274): 34 tries, seed `mulberry32(23)`, `a = rnd·2π`, `r = 620·√rnd` around the stoneForest mark; skip if
`waterAt > 0.1`; spire = `[x, z, height (90 + 190 rnd)(1 − 0.45 r/620), radius 26 + 26 rnd, rnd]`.

`thinPath(pts, n)` (L2276–2283): arc-length resample to n points (3-D).

`planFalls` (L2304–2345):
- 飞练崖: 3 falls at u ∈ {−300 (w34), 40 (w46), 330 (w28)} along the crest; `top = max(120, hAt − 6)`, bottom = −water.depth;
  9-pt path `out = 6 + 44·t^0.7` outward along (−sin yaw, cos yaw), y lerp top→bottom.
- Sect falls from `S.def.falls` (all empty in v4.4) — col-wall falls snapped to flutes, walking down 5-丈 steps until the floor;
  `rangeFall` (L2285–2302) for link falls (steepest-descent among ±0.5 rad, 5 丈 steps, stop under cloud − 90k). Falls starting
  below `S.cloud + 25k` are dropped. Record: `{x, z, top, bottom, w, nx, nz, site, cloud, pts(≤10), range?, ice?}`.

---------------------------------------------------------------------------------------------------------------------------------

## 10. Porting pseudocode (Python bake, numpy) — skeleton

```python
# bake_world.py  (run with: blender --background --python bake_world.py  or plain python -I)
import json, math, numpy as np
from PIL import Image
K = 62*0.12*1650/math.hypot(559-768, 351-383)         # 58.06024
OX, OY = (559+768+384)/3, (351+383+449)/3
FR = dict(x0=60, y0=-700, x1=2330, y1=680)
to_world = lambda px, py: ((px-OX)*K, (py-OY)*K)
to_geo   = lambda x, z: (x/K+OX, z/K+OY)
RECT = dict(x0=(FR['x0']-OX)*K, x1=(FR['x1']-OX)*K, z0=(FR['y0']-OY)*K, z1=(FR['y1']-OY)*K)

def geo_sample(arr, x, z):                              # arr: HxW float32
    H, W = arr.shape; gx, gy = to_geo(x, z)
    fx = np.clip((gx-FR['x0'])/(FR['x1']-FR['x0'])*W-0.5, 0, W-1.001)
    fy = np.clip((gy-FR['y0'])/(FR['y1']-FR['y0'])*H-0.5, 0, H-1.001)
    i, j = fx.astype(int), fy.astype(int); tx, ty = fx-i, fy-j
    a = arr[j, i]*(1-tx)+arr[j, i+1]*tx; b = arr[j+1, i]*(1-tx)+arr[j+1, i+1]*tx
    return a*(1-ty)+b*ty

def peak_h(p, x, z):                                    # vectorised version of peakH (L1208)
    dx, dz = x-p['x'], z-p['z']
    u = dx*p['c']+dz*p['s']; v = (dz*p['c']-dx*p['s'])*p['ax']; d = np.hypot(u, v)
    f = (np.arctan2(v, u)/(2*np.pi)+1)*16 % 16; i = f.astype(int); t = f-i
    pr = p['prof'][i]+(p['prof'][i+1]-p['prof'][i])*t
    q = d/(p['r']*pr)
    out = np.where(q < 1, p['h']*np.power(np.clip(1-np.power(q, p['a']), 0, 1), p['b']), 0)
    return np.where(dx*dx+dz*dz < p['reach']**2, out, 0)

def hunion(a, b, k):                                    # L1072
    kk = np.minimum(k, np.minimum(a, b)*0.5)
    h = np.clip(0.5+0.5*(b-a)/np.maximum(kk, 1e-6), 0, 1)
    sm = a+(b-a)*h+kk*h*(1-h)
    return np.where(b <= 0, a, np.where(kk > 1, sm, np.maximum(a, b)))
```
GDScript equivalents (for an EditorScript / tool that re-bakes inside Godot):
```gdscript
const K := 58.0602404593806
const ORIGIN := Vector2(570.3333333, 394.3333333)
static func to_world(px: Vector2) -> Vector2: return (px - ORIGIN) * K       # returns (x, z)
static func to_geo(xz: Vector2) -> Vector2: return xz / K + ORIGIN
static func peak_h(p: Dictionary, x: float, z: float) -> float:
    var dx := x - p.x; var dz := z - p.z
    if dx*dx + dz*dz >= p.reach*p.reach: return 0.0
    var u := dx*p.c + dz*p.s; var v := (dz*p.c - dx*p.s)*p.ax; var d := sqrt(u*u + v*v)
    if d < 1e-3: return p.h
    var f := fposmod((atan2(v, u)/TAU + 1.0)*16.0, 16.0); var i := int(f); var t := f - i
    var pr: float = lerp(p.prof[i], p.prof[i+1], t)
    var q := d/(p.r*pr)
    return 0.0 if q >= 1.0 else p.h * pow(1.0 - pow(q, p.a), p.b)
```
mulberry32 in GDScript (64-bit ints):
```gdscript
class Mulberry32:
    var a: int
    func _init(seed: int): a = seed & 0xFFFFFFFF
    static func imul(x: int, y: int) -> int:
        var r := ((x & 0xFFFFFFFF) * (y & 0xFFFFFFFF)) & 0xFFFFFFFF
        return r - 0x100000000 if r >= 0x80000000 else r
    func next() -> float:
        a = (a + 0x6d2b79f5) & 0xFFFFFFFF
        var t := imul(a ^ (a >> 15), 1 | a)
        t = ((t + imul(t ^ ((t & 0xFFFFFFFF) >> 7), 61 | t)) ^ t) & 0xFFFFFFFF
        return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0
```
(`>>>` on a 32-bit value = mask first, then `>>`; take care that `a ^ (a>>>15)` uses the unsigned a.)

---------------------------------------------------------------------------------------------------------------------------------

## 11. Godot / Blender mapping per topic

| Topic | Offline (Python / Blender) | Runtime (Godot 4) |
|---|---|---|
| GEO, pins, POIs | Export `geo.json` (frame, pins, coast, islands, rivers (post-bend!), border), `pois.json` (all 28 rows + texts, plus world pos) | Load as JSON → custom `Resource` (`GeoData.tres`) with `PackedVector2Array`s; helper autoload `Geo.gd` with `to_world/to_geo/density_at` |
| Density / hint | Decode PNG lines 306/308 → `density.png` (L8), `hint.png` (RG) | `Image` sampling in GDScript for gameplay; `sampler2D` in shaders (biome tint) |
| Coast + islands | Run `ring()` with the exact NZ noise → `coast_world.json` (polygon) | `Polygon2D`/`CSGPolygon` not needed; use baked SDF texture |
| Sea SDF / water mask / water field | Raster + EDT → `sea_sdf.exr` (100 丈), `water_mask.png` 4608×2801, `water_field.png` RGBA8, `marsh.png` | Water: one big `MeshInstance3D` plane per level (−7, −20), ShaderMaterial reads field; `waterLevelAt` via A channel |
| Heightfield | Port `baseHeight` + 03a relief to numpy; evaluate the jittered 40-丈 grid → `height.exr` (R32F 3296×2005, 26 MB) + sect patches `patch_<id>.exr` (13.3 丈) | **Option A (faithful low-poly look):** chunked `MeshInstance3D` (e.g. 64×64 cells = 2560 丈 chunks, ~1300 chunks) built in a tool script from the EXR with the same hashed jitter and flat normals (`ShaderMaterial` with `render_mode` + `NORMAL` from `dFdx/dFdy` or duplicated vertices); LOD via `visibility_range` + decimated far chunks. **Option B:** Terrain3D plugin (heightmap import, clipmap LOD) — fast, but loses the jittered facets and needs ≤ 1 unit vertex spacing scaling (set region/vertex spacing 40). **Collision:** `HeightMapShape3D` per chunk from the same EXR (no jitter needed). Blender: import EXR as displacement on a grid for authoring sect dioramas in context |
| Peaks / landmarks / sect landforms | Part of the height bake; also export `peaks.json` (x,z,h,r,prof,a,b,ax,ang) for snow/label logic | Main-peak / pillar / spires as separate meshes (Blender) |
| Sect sites | Export `SITE_DEFS` verbatim to `sites.json` (masses, benches, pads, islands, domes, lake, gullies, towerField) for Blender layout scripts | Domes = ellipsoid meshes with array shader; islands = Blender models placed at (x, y·k, z) |
| Model pack | Import `ym_pack.json` (glTF) in Blender or straight into Godot; scale 10 丈/m at placement | `MultiMeshInstance3D` per model×surface×3000-丈 cell, custom data = tint |
| Eco cards | Keep atlases + `eco.json`; optionally re-bake | MultiMesh quads per 2600-丈 cell, vertex-shader impostor, `visible_instance_count` thinning |
| Ground detail textures | — | 5 tiling textures in the terrain shader (grass/dry/snow/cliff/mud) |
| Cloud sea | Bake `cloudsea.png` + `seafield_*.exr` | Raymarched spatial shader slab (top from field, thickness 150) or FogVolume |
| Card clouds | Export clusters JSON | MultiMesh billboards with `cloud.png`, `veil`-like blending → alpha blend + depth-prepass off |
| Config | `config.json` | `XiuxianConfig` Resource; global shader params for `U.*` |

Memory/size notes: height EXR 26 MB (could store as R16 with scale 1/16 丈 since max ≈ 1300; use 16-bit PNG: h·50 → 0..65535 ≈ 1310 丈
max; or EXR half). Water field RGBA8 4608×2801 = 52 MB raw → PNG compresses well.

---------------------------------------------------------------------------------------------------------------------------------

## 12. External dependencies referenced from this range (defined elsewhere)

| symbol | line | role |
|---|---|---|
| `RELIEF`, `planRelief`, `reliefAt`, `reliefLin`, `reliefDetail`, `wetAt` | 2390, 2453, 2633, 2646, 2652, 2660 | 03a erosion relief (main mountain body) |
| `resamplePath`, `planReliefRivers`, `paintRivers` | 2751, 2757, 2895 | 03b rivers |
| `planRoads`, `planGround`, `planTrees` | 2910, 3029, 3107 | 03b |
| `planSeasons`, `planEcoGround` | 3280, 3362 | 03c |
| `planBiomes` | 3536 | 03d |
| `LANDFORMS`, `LF`, `landOf`, `landWOf` | 3674, 3675, 3677, 3686 | 03e landform dispatch |
| `LANDFORMS.nat*` | 4200–4206 | 03l natural sect mountains |
| `LAND`, `LU`, `GLSL_INTRO`, `GLSL_LIGHT` | 4221, 4227, 4255, 4277 | 04 land material/uniforms |
| `planSectSpots`, `planSectZones`, `planCities` | 8043, 9815, 11366 | 06b/06bd/06e |
| `cityRelief` | (referenced L1688 via `typeof`; no `function cityRelief` declaration found by grep — likely assigned dynamically or absent) | 06e |
| `POST`, `CAMERA_RIG` | 13092, 14083 | post-processing, camera |

## 13. Gotchas found

1. `planSites` **mutates `GEO.rivers`** (bend + riverVia), guarded by `GEO.riversBent/riversVia` flags — export the post-mutation
   rivers if you want what is rendered.
2. In v4.4 all six sects use landforms, so `cols/links/ridge/sectFloor/siteHeight` are effectively dead code (kept for v3 data).
3. Water mask comment says ≈22 丈/px but at v4.1 world size it is 28.6 丈/px.
4. `hotspots.json` equals the built-in positions; it is a no-op override.
5. Textures are loaded with `NoColorSpace` (no sRGB decode) — matching the look in Godot requires the same (don't mark albedo as
   `source_color`, or compensate).
6. Everything is world-flattened by `wp.y *= 1 − uMap` for the 舆图 (2-D map) mode — the map is the same scene squashed, viewed
   with `map.fov 20`, view 2400–42000.
7. `ground_*.jpg`: all-or-nothing load. `eco`: all three files or nothing. `PACK`: per-model fallbacks via `PACK.has`.
8. Exact reproduction of placements needs bit-exact `mulberry32`, `hash2i` and `NZ.simplex2` (seeded 977) ports.
