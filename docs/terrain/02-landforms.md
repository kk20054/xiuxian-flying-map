# 02 · Landforms with real geological logic — the recipes

Real land is the product of **structure** (how the rock is folded, faulted and jointed), **rock** (how hard it is, how it
weathers), **process** (rivers, ice, dissolution, wind, the sea) and **stage** (how long it has been at it). A believable
仙侠 map keeps that chain intact and exaggerates only the end of it: the walls are a little sheerer, the pillars a little
taller, the cloud sea a little more dependable — but every peak still stands where the rock lets it, and every valley
still drains somewhere.

Numbers below are tagged as in the research notes: **[r3 S#]** = sourced in
[research/r3_landform_geology.md](research/r3_landform_geology.md) (mostly read through search extracts — check before
quoting), *(d)* derived, *(m)* from memory / unverified, **(ours)** = the value our operator uses. 1 丈 ≈ 3.33 m.

---------------------------------------------------------------------------------------------------------------------------

## 0. Four rules the tools follow

1. **Rivers first.** The 舆图's rivers, lakes and coast are fixed base level. The relief is grown *toward* them, so every
   valley is graded to a river that is already on the map (the idea of Génevaux et al. 2013; the demo's 03a already uses
   sea and great rivers as base level).
2. **Rock decides height and steepness.** Stream power `∂h/∂t = U − K·A^m·S` with a per-rock erodibility **K** (hard rock
   stands high) and a per-rock **critical slope Sc** (granite and quartz sandstone hold vertical walls, loess tops and
   alluvium do not). Same uplift, different rock → different land.
3. **Two scales.** The 40-丈 heightfield holds everything wider than ~2–3 cells (80–120 丈). Narrower vertical forms —
   karst towers, sandstone pillars, sea stacks, granite spires, stone-forest blades — are **rock instances**: meshes
   standing on a talus plinth the heightfield provides (the pattern of every large open world: [05](05-other-projects.md)).
4. **One exaggeration, documented.** Macro relief stays real-scale (p97 ≈ 1 800 m). Small vertical forms are ×1.5–2 of
   their real counterparts (the diorama reads them from altitude); walls never exceed vertical, nothing floats unless the
   lore makes it float (落云宗's 浮空岛 are 法阵, not geology).

## 1. The engine: stream power with rock

`tools/terrain/xyterrain/sculpt.py`, `flow.py`.

```
U   uplift       a regional field over the massifs: blur(max_filter(h_export, 18 cells), 30 cells), normalised
                 — NOT the topography itself: valleys and saddles inside a range rise as fast as its peaks. Deriving U
                 from the height made rivers cut every saddle (found by the feng-shui check, 04 §5).
                 × fault throw ramps, + painted uplift (points and 龙脉 ridge lines).
K   erodibility  K0 · K_rock · K_fold(beds, h) · K_fault(crushed zone) · (1 + 0.2 fbm)
                 K0 is calibrated so the exported land is near equilibrium: median of U / (A^m S) on mountain cells.
m   0.45         the demo's drainage-area exponent; n = 1
Sc  per rock     after each implicit step a cell may stand at most Sc · L above its receiver
D   per rock     linear hillslope diffusion, sub-stepped
base             every water cell of the layout + the map edge; sect patches and city cores are fixed
```

Each step: priority-flood + ε fill → **Rho8** receivers (Fairfield & Leymarie 1991: a diagonal drop is measured over
(2 − r)·cell with r random, so cones get true radial drainage instead of 8-pointed stars) → area → the implicit FastScape
n = 1 solve upstream along the stack (Braun & Willett 2013) → critical-slope cap → diffusion. 24 steps ≈ 2 min on the
full 3296 × 2005 grid with numba. More steps = further from the exported land.

| rock | K × | Sc (tan) | talus | D × | operator | why |
|---|---|---|---|---|---|---|
| alluvium 冲积层 | 3.0 | 0.12 | 0.3 | 2.0 | alluvial | loose gravel and silt: low gradients, no cliffs |
| loess 黄土 | 2.2 | 1.4 | 0.8 | 1.0 | loess | erodes fast, yet stands in vertical joints at gully walls |
| metamorphic 变质岩 | 1.0 | 1.3 | 0.85 | 1.0 | fold | the reference rock of the fold belts (slate, phyllite, schist) |
| granite 花岗岩 | 0.35 | 6.0 | 1.5 | 0.4 | granite | the hardest: stands highest, sheer joint walls |
| quartz sandstone 石英砂岩 | 0.5 | 8.0 | 1.8 | 0.3 | pillars | ≈ 95 % quartz, walls up to 350 m (Wulingyuan) [r3 S34–S35] |
| red beds 丹霞红层 | 0.9 | 5.0 | 1.3 | 0.5 | danxia | weakly cemented, but cliff-forming through bedding + joints |
| limestone 石灰岩 | 0.6 | 4.0 | 1.3 | 0.6 | karst | mechanically strong, chemically weak — dissolution does the shaping |
| volcanic 火山岩 | 0.5 | 2.2 | 1.0 | 0.6 | volcanic | lava and welded tuff: hard, columnar cliffs |
| lacustrine 湖沼沉积 | 3.5 | 0.06 | 0.2 | 2.5 | wetland | lake and swamp mud: flat |

## 2. Structures

### 2.1 Fold belts → strike ridges, hogbacks, trellis drainage

Folded beds of alternating hard (sandstone, quartzite) and soft (shale) rock crop out in bands along the **strike**. Soft
bands erode into strike valleys, hard bands stand as ridges; dipping beds give **hogbacks/cuestas** — a gentle dip slope
on one side, a steep scarp on the other (cuesta < 20°, hogback > 30–45° [r3 S78]) — and the drainage becomes **trellis**,
with water gaps where a river cuts through a hard band [r3 S79]. Young anticlines are ridges, synclines valleys (they
invert with age [r3 S80]).

**Operator** (`geology.Plan.fold_K`): inside each fold belt, the bed index of every cell is
`(across·sin(dip) + (h − fold(across))·cos(dip)) / bed`, with the folded bedding surface `fold = amp·sin(2π·across/wave)`
on a domain-warped strike frame. `K × (1 ± contrast)` alternates between soft and hard beds; because the index depends on
`h`, the outcrop pattern shifts as the land is lowered — the hogbacks *emerge* from the erosion rather than being stamped.
Only bedded rocks are affected (a granite batholith or a lava pile inside the belt is not layered). **(ours)** `bed` must
be formation-thick: ≥ 250 丈 (outcrop bands ≥ 10 cells) — at 70 丈 the bands alias into 3-cell stripes.

### 2.2 Faults → range fronts, scarps, grabens, spirit veins

A normal fault lifts one block against the other: a **range front** with triangular facets and a free face of 60–90°
relaxing to the 30–35° angle of repose [r3 S83], alluvial fans at every outlet; two facing faults drop a **graben**
(a structural basin — poorly drained, filled with lake mud: 绿踪沼泽). Fault zones are crushed rock: rivers follow them
(fault-line valleys), springs rise along them.

**Operator** (`geology.Plan.fault_fields`): per fault polyline, `U × (1 ± throw)` across a `tanh` ramp of width `width`,
fading with distance (`reach`); `K × (1 + crush)` in the crushed zone; **both die out within `tip` 丈 beyond the ends**
(a real fault's throw goes to zero at its tips — without that, a short graben fault drops a band across the whole map).
The upthrown side is given as a compass side (`"up": "N" | "S" | "E" | "W"`).

**仙侠 reading**: 灵脉 run along deep faults; 灵眼 well up where faults cross, or where a karst river resurges — the canon's
地脉 / 灵眼 vocabulary has a geological home ([03](03-world-plan.md) §4).

### 2.3 Painted uplift and 龙脉 ridges

`structures.uplift` entries: points `{x, z, r, du}` (a dome) and **ridge lines** `{pts, width, du}` — an anticlinal axis
that keeps rising, so erosion cannot cut the ridge through. Use it to keep a sect's dragon vein continuous
(`fengshui.py --trace` shows where it breaks, [04](04-tools.md) §5).

## 3. Rock by rock

### 3.1 Granite — 花岗岩 (古剑门's 主脉, the 封日城 headland)

- **Geology.** Huangshan granite: a composite batholith, ≈ 127 and 105 Ma phases [r3 S41]; sheet joints and widely spaced vertical joints cut
  the batholith into walls, spires and domes; Sanqingshan has 48 peaks and 89 pillars, its Python pillar 120–128 m
  [r3 S44–S45]. Exfoliation domes are convex everywhere [r3 S48]. Huangshan sees ~200–260 fog days a year [r3 S42].
- **Signature.** The highest, sharpest crests; joint-bounded slots; smooth convex domes between; rectangular drainage.
- **Operator** (`landforms.granite`). Low K (stands highest), Sc 6 (walls). Crests sharpened by a high-pass
  (`h += 0.55·(h − blur5)·(0.4 + crest)`); Worley joint traces (cell 270 丈) incised 26 丈 at the crests; 25 % of joint
  blocks domed (`√(1 − (f1/0.55)²)`); the thinnest crests stand up as **granite_spire** rock instances (h 30–95 丈).
- **皴**: 斧劈皴 on the walls, 卷云皴 on the domes, 雨点皴 on great faces (范宽).
- **仙侠**: sword peaks (剑峰) for 古剑门; 迎仙松 is the crag pine on a jointed spur.

### 3.2 Quartz-sandstone peak forest — 石英砂岩峰林 (落云宗's 东脉)

- **Geology.** Wulingyuan: > 3 000 pillars, > 1 000 above 200 m, walls to 350 m, ≈ 95 % quartz [r3 S35, S39]. Thick
  horizontal Devonian beds, two near-vertical joint sets; the channels at the pillar bases erode 83–122 mm/kyr against
  ~2.5 on the tops, so the summits stay level with the old plateau [r3 S34]. Evolution: **plateau → mesa → walls → peak
  forest → remnant stumps** [r3 §6.3].
- **Signature.** Concordant flat tops; straight "streets" along the joints; deep narrow gorges (金鞭溪); pillars 10–50 m
  across *(m)*, spacing 170–300 m *(d)*.
- **Operator** (`landforms.pillars`). Two scales. **Major joints** (520 × 640 丈, domain-warped, gated along their length so
  they wander and die out) are gorges in the heightfield; the **stage** (0–3) grows toward the trunk valleys
  (`smoothstep(2600, 300, distance to channels with A > 250 cells)` + noise) — headward erosion. Stage < 1.6: plateau and
  walls; ≥ 1.6: the block becomes a pillar field — the heightfield drops to the valley floor + a 14 % talus plinth and the
  **minor joints** (78 × 92 丈) place **sandstone_pillar** instances (r 11–30 丈, h ≤ 200 丈, sparser and lower in the
  stump stage). ~1 850 pillars on the current plan.
- **皴**: 斧劈 on the walls, 折带 on the bedded tops.
- **仙侠**: the Hallelujah-mountain look — pillars rising out of the cloud sea; 子母峰 as a mother-and-child pair.

### 3.3 Danxia — 丹霞 (鸾鸣宗's red basin)

- **Geology.** Continental red beds (sandstone, conglomerate) with steep cliffs [r3 S20–S22]; slot canyons < 1–100 m wide
  and up to 5 km long [r3 S30]; Jianglangshan pillars ≈ 300 m [r3 S29]. Stages Chishui (early youth) → Taining (late
  youth) → Langshan (early maturity) → … ; the hypsometric integral is a usable dial: > 0.6 young, 0.4–0.6 mature, < 0.4 old
  [r3 S24]. **Zhangye** is different: weak siltstone/mudstone weathers to rounded rainbow hills, not cliffs [r3 S32].
- **Signature.** 顶平、身陡、麓缓 — flat caprock top, sheer red body, gentle talus foot; 石堡 / 石墙 / 石柱; alcoves and
  horizontal grooves at the soft layers (overhangs → meshes).
- **Operator** (`landforms.danxia`). Relief above the local base is quantised into beds (`bed` 55 丈 ± 25 %): a wall in
  the top 28 % of every bed, a flat tread below, the lowest bed left as a gentle apron. Two joint sets (430 丈, gated)
  cut **一线天** slots 42 丈 wide through the mesas; isolated **danxia_butte** instances where joints cross near the tops.
  Writes a `redness` layer for shaders.
- **皴**: 折带皴 (horizontal beds turning down at the cliff edges), 雨点皴 on the walls.
- **仙侠**: 丹 cinnabar + 霞 rosy cloud — red walls for the phoenix sect 鸾鸣宗.

### 3.4 Karst — 喀斯特 (南山 below 韵州城, 笋石林 / 灵眼, the east coast, 水影宗)

- **Geology.** The form depends on height above the **water table** [r3 S2]: well above it, **峰丛 fengcong** — cone
  clusters on a shared rock base with closed depressions (relief 100–300 m, > 500 m locally; cones 45–47°; ≈ 2.5
  depressions/km², ≈ 190 丈 apart) [r3 S3, S5]; near it, **峰林 fenglin** — isolated towers on an alluvial plain (30–80 m,
  to 300 m near the fengcong; walls ≈ 75°) [r3 S3, S4]. Both can form at once. **天坑** ≥ 100 m wide and deep, diameter/depth
  0.5–2 (Xiaozhai 626 × 537 m, 511–662 m deep) [r3 S7, S9]; natural bridges 223–281 m high [r3 S11]; **石林** blades
  20–30 m (≤ 40) [r3 S17]; travertine terraces (Huanglong ≈ 600 m drop over 3.6 km) [r3 S18].
- **Operator** (`landforms.karst`). Water table `B` = local valley floor (min filter, r 1 200 丈, blurred). Height of the
  massif *envelope* above B decides fengcong ↔ fenglin (`smoothstep(40, 120)`). **Fengcong**: Worley cones (spacing
  210 丈, linear-ish flanks `(1 − t^1.35)^1.7`) *riding on the massif envelope* (so the range keeps its ridges and
  valleys), sized by local relief, grouped in clusters (fbm) and suppressed along the drainage (**槽谷** karst valleys),
  dolines where three cones meet. **Fenglin**: the plain at the water table + **karst_tower** instances (spacing 300 丈,
  42 % kept, h 20–70 丈, r 22–55 丈) on a 22 % talus plinth.
- **Not yet**: tiankeng and stone forests as operators (the demo's 灵眼 basin and 笋石林 landmark are preserved); the
  canon's 灵眼 cavern ([03](03-world-plan.md) §2) wants a tiankeng + a hero cave mesh.
- **皴**: 米点皴 in mist, 荷叶皴 on the cones (radial gullies), 披麻皴 on the soil-covered flanks.

### 3.5 Volcanic — 火山 (百巧院's 西脉, 七灵岛)

- **Geology.** Changbaishan: basalt shield → trachyte cone → a 5 km × 850 m caldera, Tianchi 4.85 × 3.35 km and
  373–384 m deep [r3 S51–S52]; shield vs stratovolcano at ≈ 12° mean slope, H/W 0.1 [r3 S54]; flood-basalt steps
  8–17 m single flows, 50–70 m composite [r3 S55–S56]; Yandangshan rhyolite falls 190–197 m [r3 S50].
- **Operator** (`landforms.volcanic`). The named volcanoes of `geology.json`: **strato** — concave flanks `e^(−3.2t)` with
  a summit crater, blended into the existing island so the coastline stays; **caldera** — an *eroded* rim (radius wobble
  ±10 %, uneven crest, **breached where a big stream leaves**, standing only on high ground) around a lowered floor. A
  cinder-cone field (spacing 950 丈, 22 % kept, h 30–85 丈, craters) on the rest of the volcanic rock.
- **皴**: 斧劈 + 折带 (stacked tuff, 叠嶂).
- **仙侠**: 地火 / 地肺火池 under a refining sect; islands that "rose from the sea" (七灵岛 浮出).

### 3.6 Loess — 黄土 (倪航斋)

- **Geology.** Loess > 200 m thick (Dongzhi tableland ≈ 900 km²) [r3 S59]; gully density 3–11 km/km² (to 20–30)
  [r3 S60–S63]; gully heads retreat 0.5–6.6 m/yr [r3 S59]; erosion turns **塬 → 梁 → 峁** [r3 S64–S65].
- **Operator** (`landforms.loess`). Tops above a local level are flattened into **塬** (×0.18); channels with
  A > 60 cells cut gullies `depth = 24·ln(A/A0)^0.8` (≤ 130 丈), `width = 38·(A/A0)^0.3` (≤ 300 丈) with near-vertical walls
  (`(d/w)^0.35`).
- **皴**: 折带 on the benches, 披麻 on the gully walls.

### 3.7 Alluvial plains, fans, terraces — 冲积平原

- **Geology.** Fans spread from canyon mouths, area ∝ basin area^n (n < 1), slopes 1–6° (debris fans to 15°) [r3 S84];
  terraces record older base levels (Lanzhou: 105–200 m over 1.6 Ma, ≥ 8 levels) [r3 S87]; meanders λ = 7–12 w,
  Rc = 2–3 w [r3 S85].
- **Operator** (`landforms.alluvial`). Fan apexes where a channel (A > 2 500 cells) leaves the mountains: a cone sector
  opening away from the range (radius ∝ √A, 600–2 600 丈, ≤ 18 丈 high); three terrace steps of 4 丈 at 260 / 820 /
  1 700 丈 from the water; a 6-丈 swell between rivers. Low K and Sc keep the plain's gradient gentle.

### 3.8 Swamps and grabens — 湖沼 (绿踪沼泽)

A graben between two faults ([2.2](#22-faults--range-fronts-scarps-grabens-spirit-veins)) filled with lake mud:
`landforms.wetland` flattens to the basin floor + 0.6 丈 with reed islets. Miasma is a shader / particle matter.

### 3.9 Glacial — 冰川 (云梦's summits)

- **Geology.** U-valley cross-sections `z ∝ |y|^b` with b ≈ 1.5–2 vs ≈ 1–1.3 for V-valleys [r3 S70–S71]; cirques face
  the pole [r3 S72–S73]; the Taibai Shan Ice-Age snow line was 3 250–3 300 m [r3 S75]. Tributaries left **hanging** above
  an over-deepened trunk are where the great waterfalls fall.
- **Operator** (`landforms.glacial`). Palaeo-ELA 650 丈 (below the demo's 820 snow line): ice flows down the drainage
  from cells above it until 320 丈 below; ice-filled valleys (A > 80 cells ≈ 1.4 km²) get a parabolic cross-section
  `floor + (h − floor)(d/w)²`, w = 10·√A (≤ 360 丈), over-deepened up to 45 丈, never lowered by more than 120 丈 (ice
  widens a valley, it does not plane a range). On the current relief that is ~670 cells on 云梦's summits (mean 20 丈):
  cirques and short troughs, as a mid-latitude range of this height would have. Writes a `glacier` layer.
- **仙侠**: 飞瀑 from hanging valleys — water falling from the sky.

### 3.10 Coasts — 海岸

Hard-rock headlands retreat as cliffs; shore platforms 80–270 m wide [r3 S90]; stacks and arches stand off them.
`landforms.coast`: **sea_stack** instances in the water within 160 丈 of steep hard-rock shores (r 10–26, h 20–70 丈).

## 4. The cloud sea, physically

Cloud seas form under a temperature **inversion**: cold air pools in basins at night, the fog top is flat at the inversion
height, one level per basin *(d)*, densest November–May and after rain; Huangshan's classes are < 800 / < 1 600 /
1 600–1 800 m [r3 S43]. The demo's sect cloud tops (472–482 丈 ≈ 1 600 m) sit right in that band. Rule for the generator:
the cloud sea fills each basin up to its own spill level (the demo's `RELIEF.low` valley-floor field already does this),
and peaks above it float — 郭熙: 山欲高，尽出之则不高，烟霞锁其腰则高矣.

## 5. Painting: 皴法 and composition

The texture strokes were invented to give outlined mountains "geologic credence" [r3 S99] and were chosen to suit the
rock [r3 S100–S101] — a ready-made style guide for the ink shader (`facet.gdshader`'s 皴 term) per rock type:

| 皴 | master | reads as | use on |
|---|---|---|---|
| 披麻皴 hemp-fibre | 董源, 巨然 [r3 S99] | soil-mantled Jiangnan hills | hill, karst flanks, loess gully sides — long strokes down the fall line |
| 雨点皴 raindrop | 范宽 [r3 S108] | massive northern cliffs | granite faces, Danxia walls — stipple ∝ slope |
| 卷云皴 rolling cloud | 郭熙 [r3 S104] | rounded weathered masses | granite domes, volcanic knobs — curvature arcs |
| 斧劈皴 axe-cut | 李唐 [r3 S99] | hard, joint-bounded rock | granite, quartz-sandstone pillars, columnar volcanics — wedges along facet normals |
| 折带皴 folded belt | 倪瓒 [r3 S103] | horizontal beds with vertical joints | Danxia, Wulingyuan tops, karst ledges, loess benches — stepped contours |
| 米点皴 Mi dots | 米芾, 米友仁 [r3 S103] | misty forested low hills | karst and hills in mist |
| 荷叶皴 lotus leaf | 赵孟頫 [r3 S102] | radial gullies on a cone | karst cones, volcanoes, inselbergs |
| 解索 / 牛毛皴 | 王蒙 [r3 S105–S106] | dissected ridges / dense forested slopes | metamorphic fold belts |

Layout rules from 郭熙's 《林泉高致》 and 王原祁's 龙脉 theory, as checks a map can pass
([research r3 Part 2 (b)](research/r3_landform_geology.md)): one master mountain per region (宗主); the cloud band at
0.4–0.65 of the master peak's relief (烟霞锁其腰); rivers hidden by interlocking spurs (掩映断其派); 高远 (pillar or cliff
fields with skylines > 45° from their foot), 深远 (3–5 ridge layers along the main approach), 平远 (a lake or plain per
region with a low horizon); no radial symmetry (步步移, 面面看); every massif with a continuous main ridge that rises and
falls, opens into basins and closes into gorges (龙脉, 起伏, 开合).

## 6. Feng shui — reading a site

`tools/terrain/fengshui.py` scores a sect site the way a 形势派 geomancer reads land; the terms are measurable
([r3 Part 2 (c)](research/r3_landform_geology.md)): **玄武** a back mountain, highest of the four sectors; **青龙 / 白虎**
flank ridges at 0.2–0.5 × its height (青龙 ≥ 白虎); **明堂** level ground in front; **案山 / 朝山** a low hill near, higher
hills far in front; **水** water crossing the front (玉带 — on the inner, depositing bank, not the eroding outer one: the
geomorphology of a bend [r3 S119]); **藏风** horizon enclosure; **向** facing south; **龙脉** — the site joined to the 祖山
along high ground (the lowest col on the best ridge path). Weights 0.20 玄武, 0.15 龙脉, 0.15 砂, 0.15 水, 0.10 明堂,
0.10 藏风, 0.05 案朝, 0.05 向, 0.05 穴.

Note the happy coincidence: the camera always faces **north** and a 坐北朝南 sect faces **south** — every well-sited sect
presents its front to the player with its 靠山 rising behind it.

## 7. Reality check

| form | real | demo styles | the new operators |
|---|---|---|---|
| karst plain towers | 30–80 m (9–24 丈), ≤ 300 m near fengcong [r3 S3–S4] | 70–210 丈 | 20–70 丈 (×2), tallest near the uplands |
| fengcong depression spacing | ≈ 190 丈 *(d)* | — | cone spacing 210 丈 |
| Wulingyuan pillar spacing | 50–90 丈 *(d)* | Worley 118 丈 (2–3 × sparser) | minor joints 78 × 92 丈 |
| pillar heights | > 1 000 over 200 m; walls ≤ 350 m [r3 S34, S39] | 75–120 丈 | ≤ 200 丈 (×1.5–2) |
| granite pillars | 120–128 m (36–38 丈) [r3 S45] | 26–84 丈 | 30–95 丈 |
| caldera | 5 km × 850 m (1 500 × 255 丈) [r3 S51] | — | 百巧院 rim r 3 800, h 260 |
| loess gullies | depth 50–200 m *(m)* | 66–108 丈 | ≤ 130 丈 (cuts into bedrock) |
| cloud tops | Huangshan < 1 600 m class [r3 S43] | 472–482 丈 | unchanged |
