> **Research dossier** (appendix to [docs/terrain](../README.md)). Compiled with limited web access: most page
> contents and numbers come from search-engine extracts of the linked pages, and every item carries its source tag
> ([V] page opened, [S#]/[N]/[H]/[W]/[F]/[D] source kinds, "(unverified — from memory)", "(derived)"). Check a page
> before relying on a single number or quote.

# R3 · Landform geology, painting and geomancy for the xianxia terrain generator

Research note for the per-rock-type landform operators that sit on top of the stream-power relief
(`docs/03-terrain-generation.md` §1 for the coarse relief, §6 for the sect styles `pillars / granite / volcanic / karst / hill / loess`).
The repository was not modified.

---

## 0. Method, limits and conventions

**What the web allowed (read this first).**
- `WebFetch` failed for every host with `getaddrinfo ENOTFOUND` (whc.unesco.org, en.wikipedia.org, worldheritageoutlook.iucn.org,
  thesalmons.org). `curl` through the agent proxy was refused with `CONNECT 403` (egress policy) for whc.unesco.org and
  en.wikipedia.org. **No primary page (UNESCO dossier, IUCN evaluation, paper PDF) could be opened.**
- `WebSearch` worked. Every number tagged **[S#]** comes from a search-engine extract that quotes or summarises the cited page.
  It is "sourced", but read from an extract, not from the full document. The search budget (200 calls per turn, shared across
  agents) ran out near the end, so a few planned look-ups (Leye–Dashiwei tiankeng group, Libo cone heights) were not done.
- Anything not found is marked **(unverified — from memory)**. Where a whole bullet list is from memory, the heading of the
  list carries the tag. Numbers I computed from sourced numbers are marked **(derived)**.
- If a number will be load-bearing, confirm it in the primary document. The highest-value ones to open are the UNESCO
  nomination files for South China Karst (1248), China Danxia (1335), Wulingyuan (640), Huangshan (547), Sanqingshan (1292),
  Waltham's "Fengcong, fenglin, cone karst and tower karst", May et al. 2018 (ESPL 43:639–653), Gunn et al. 2019
  (Cave & Karst Science 46(2)) and Leopold & Wolman 1957 (USGS PP 282-B).

**Units.** 1 丈 ≈ 3.33 m, so 1 m ≈ 0.30 丈, 100 m ≈ 30 丈, 1 km ≈ 300 丈. The world is 132,000 × 80,000 丈 ≈ 440 × 267 km.

**Resolution rule of thumb.** A landform needs about 3 cells across to read as a shape.
| grid | cell | smallest resolvable feature |
|---|---|---|
| coarse relief (`CONFIG.relief.cell`) | 100 丈 = 333 m | ≈ 300 丈 ≈ 1 km |
| the 40-丈 heightfield named in the brief | 40 丈 = 133 m | ≈ 120 丈 ≈ 400 m |
| sect fine grid (§6.4) | 15 丈 = 50 m | ≈ 45 丈 ≈ 150 m |

Anything below that (stone-forest pinnacles, columnar joints, Danxia alcoves, slot canyons, loess rills) must be meshes, decals
or shader detail, not heightfield.

**Height scale coincidence worth knowing.** The relief's 97th percentile is 540 丈 ≈ 1,800 m and the cap is 950 丈 ≈ 3,165 m.
Huangshan's three main peaks are just over 1,800 m [S43], and the sect cloud anchors (472–482 丈 ≈ 1,573–1,607 m) sit at the
cloud-top band where only Huangshan's main peaks emerge [S43]. The world is close to real scale for Chinese mid-mountains.

---

# Part 1 · Landforms

## 1. Fold mountains and fault blocks

### 1.1 Folds, hogbacks and cuestas
**Formation.** Compression folds a layered sequence. Erosion then picks out the resistant beds (sandstone, quartzite, limestone)
as ridges and the weak beds (shale, mudstone) as valleys. The more resistance contrast between beds, the stronger the structural
control and the relief [S78].

**Young versus old fold belts (topographic inversion).**
- Young folds: anticlines are ridges and synclines are valleys. NASA describes the Zagros as ridge-and-valley relief of about
  1,200 m, with the synclines mostly buried by sediment shed off the anticlines [S80]. Zagros "whaleback" anticlines are often
  more than 100 km long, in resistant Tertiary and Mesozoic limestone [S80].
- Old folds: breached anticlines become valleys and synclines can be left as ridges. In the Kurdistan Zagros, synclines form
  nearly half of the mountains while erosion removes anticlines [S80].
- Lines of unusually long, high-aspect-ratio folds crossed by several wind gaps track underlying thrusts [S80].

**Chinese example: the eastern Sichuan fold belt (川东褶皱带).** Jura-type folds. North-west of the Qiyueshan fault the folds
are *ejective* (隔档式): tight, nearly upright chevron anticlines (Huaying Shan 华蓥山, Mingyue Shan, Fangdou Shan) separated by
broad box synclines. South-east of it they are *trough-like* (隔槽式) [S81]. On a map this reads as long, narrow, parallel
NNE ridges with wide flat-floored valleys between them.
- (unverified — from memory) Anticline ridges in the ejective belt are spaced roughly 20–40 km apart and are a few km wide.
  Zagros fold wavelengths are of order 10–20 km. Appalachian Valley-and-Ridge ridges are a few km apart.

**Hogback, homoclinal ridge and cuesta (dip slope versus scarp slope).** A dipping resistant bed gives an asymmetric ridge: the
*dip slope* is the bedding surface itself, and the *scarp slope* is the erosion face that cuts across the beds [S78].
The thresholds differ by source:
| source | cuesta | homoclinal ridge | hogback |
|---|---|---|---|
| MIT glossary [S78] | dip < 20° | — | dip > 20° |
| Wikipedia "Hogback" [S78] | — | — | dips > 30–40° |
| Indian geography notes [S78] | 10–25° (flashcard sources) | 25–45° | > 45°, slopes become nearly symmetric |

Use: cuesta for dip ≲ 20°, homoclinal ridge for 20–40°, hogback for ≳ 40°.
- (unverified — from memory) The scarp slope is typically 25–60°, steeper where the cap bed is thick. The dip slope equals the
  bed dip. Cuesta spacing is set by the thickness of the resistant/weak pair divided by sin(dip).

**Drainage.** Trellis: main streams run along the strike valleys on weak beds, and short tributaries run down the dip and scarp
slopes at right angles [S79]. **Water gaps** are steep-walled narrow valleys cut through ridges by streams [S79]. They form by
*antecedence* (the river keeps its course while the ridge rises) or *superimposition* (the river cuts down through a cover and
is locked onto the buried ridge). Both require a river older than the ridge [S79]. The Potomac and New rivers cut gaps
perpendicular to Appalachian ridges and are thought to predate them [S79].
- (unverified — from memory) A *wind gap* is an abandoned water gap left high and dry after stream capture.

### 1.2 Fault scarps, horsts, grabens and range fronts
- Basin and Range: about 400 mountain blocks, with fault spacing of roughly 20–40 km [S82]. In world units that is
  6,000–12,000 丈, so the 440-km world could hold about 11–22 such ranges across its width (derived).
- **Mountain-front sinuosity** `Smf = L_front / L_straight`. Near 1.0 means a straight, fault-dominated, active front. Higher
  values mean erosion has embayed it [S82, citing Bull & McFadden 1977].
  (unverified — from memory) Active fronts are typically Smf ≈ 1.0–1.6, inactive fronts > 3.
- **Triangular facets** and scarps mark fault segments. On the Sangre de Cristo front, segments are about 15–20 km long with
  5–10 km subsegments [S82].
- **Scarp degradation.** The free face collapses first, until the scarp slope reaches the angle of repose of cohesionless
  material, 30–35° [S83]. After that the profile degrades by diffusion. For Holocene scarps a few metres high in loose alluvium
  in arid climates, the diffusivity is 1–6 m²/kyr [S83]. Evidence of the initial shape is lost when the apparent diffusion age
  reaches about twice the initial value [S83]. Linear diffusion alone cannot date scarps younger than about 1,000 years,
  because the mass-failure phase comes first [S83].
  (unverified — from memory) A fresh free face is about 60–90°.
- **Chinese example: Huashan 华山 and the Weihe Graben 渭河地堑.** The Qinling Northern Piedmont Fault (~200 km) and the Huashan
  Piedmont Fault (~150 km) bound the Weihe Graben. The 1556 M 8.5 Huaxian earthquake happened here [S46]. The Huashan Piedmont
  Fault is a steeply dipping normal fault [S46]. Apatite fission-track ages on the Huashan batholith, sampled from 520 m to
  1,950 m elevation, are about 20.6–29.3 Ma, giving uplift rates of about 0.019–0.189 mm/a [S47].
  This is the "horst-edge" granite massif: a sheer range front over a graben plain.

### 1.3 Range-front alluvial fans
- Fan area scales as a power of drainage-basin area, `A_fan = c · A_basin^n`, with **n < 1**. A storm of a given recurrence is
  less likely to cover a big basin than a small one [S84, after Bull 1964 and Denny 1965].
  (unverified — from memory) n ≈ 0.7–1.0, commonly ~0.9.
- Fan slope is set mainly by debris size and water discharge, and it falls as fan area grows. In 490 Japanese fans, large source
  basins give small, nearly constant slopes, with the lowest about 0.4° [S84]. For a given drainage area, arid fans are steeper
  than humid ones [S84].
- (unverified — from memory) Typical fan slopes are 1–6°, debris-flow fans up to 10–15°. The plan is a cone sector with its apex
  at the canyon mouth. The radial profile is concave-up and the cross-profile convex. Channels are radial and distributary.
  Coalesced fans form a *bajada* along the front.

**Operator hints.** (1) Fold ridges: an anisotropic, strike-parallel bed-resistance field `K(x)` (alternate low-K / high-K bands
across strike) fed into the existing `K` in §1.4 step 15, rather than painted ridges. The stream-power solver then produces
trellis drainage and water gaps by itself wherever an old river already crosses the bands. (2) Cuesta asymmetry: tilt the
bands and use a one-sided profile, dip slope = dip angle, scarp slope 25–60°. (3) Fault fronts: a step in uplift `U` along a
line with segment lengths 5–20 km (1,500–6,000 丈), plus a fan operator at each catchment outlet that crosses the step.

---

## 2. River landforms

### 2.1 V-valleys and gorges
- Valley cross-sections are fitted with `z = a·|y|^b`. **b ≈ 1** gives straight V flanks, and higher b gives a more U-shaped
  valley. In the Southern Alps the mean b is 1.28 (fluvial Marlborough) versus 1.54 (glacial Fiordland) [S70].
- **Three Gorges 三峡.** The total is usually given as about 193 km, and sources disagree [S88]. Qutang 瞿塘峡 is about 8 km
  long, the shortest; at its narrowest the river was about 150 m (500 ft) wide, with peaks to about 1,200–1,300 m [S88].
  Wu 巫峡 is 40–45 km long [S88]. Xiling 西陵峡 is 66–100 km long, depending on the source [S88].
  - (unverified — from memory) The gorges are cut where the Yangtze crosses limestone anticlines of the eastern Sichuan /
    western Hubei fold belt (Wushan), and Xiling's lower end crosses the Huangling dome of granite and metamorphic rock.
    The pattern is: narrow, cliff-walled gorge in limestone, wider valley in shale/sandstone between the anticlines.

### 2.2 Incised meanders
- (unverified — from memory) Incised meanders are inherited from a former floodplain and cut down during uplift or a base-level
  fall. *Entrenched* meanders are symmetric (fast incision). *Ingrown* meanders have a gentle slip-off slope on the inside bend
  and a cliff on the outside (slow incision with lateral migration). Chinese example: the Yellow River's 乾坤湾 in the
  Shanxi–Shaanxi gorge.
- Planform geometry (applies to free and incised meanders): Leopold & Wolman found meander wavelength **7–12 × channel width**
  [S85]. A secondary summary gives 10–14 widths, averaging 11 [S85]. The **radius of curvature is 2–3 widths** for most bends
  [S85, "River Meanders" 1960].

### 2.3 Braided rivers
- At a given discharge, meanders occur at smaller slopes than braids. At the same slope, braided channels go with higher
  bankfull discharges [S85].
- (unverified — from memory) The Leopold & Wolman threshold is often quoted as `S = 0.012 Q^-0.44` (Q bankfull, ft³/s).
  The search did not confirm the coefficient. Braiding also needs abundant coarse bedload and erodible banks: proglacial
  outwash, alluvial fans and mountain-front rivers.

### 2.4 River terraces
- Yellow River near Lanzhou: at least eight terraces (T1–T9 in one scheme). T9 ≈ 1.7 Ma and T8 ≈ 1.5 Ma [S87]. The 1.6-Ma
  terrace surfaces stand **105–200 m** above the river in the Lanzhou block, versus about 400 m in the Gonghe block [S87].
  Upstream (Gonghe basin, Longyang gorge), long-term incision rates are reported as "2–6 mm a⁻¹" (the unit is garbled in the
  extract) [S87]. Uplift pulsed: rates around 0.15–0.20 Ma were 2–6 × the other periods [S87].
- Control switches over time: from tectonic (T9–T4) to climatic (between T4 ≈ 0.86 Ma and T3 ≈ 0.14 Ma), tied to a stronger
  East Asian summer monsoon [S87]. On the upper Weihe, cyclic Quaternary climate change drives strath-terrace formation, with
  episodic uplift on top [S87].
- (unverified — from memory) Terraces are flat treads with steep risers. Paired terraces mean steady vertical incision.
  Unpaired ones mean incision while the channel swings laterally.

### 2.5 Alluvial fans
See §1.3.

### 2.6 Deltas
- Galloway's ternary scheme classifies deltas by the dominant process, wave, tide or river [S86].
  - River-dominated (bird's-foot): indented shore, many distributaries, marshes, bays or tidal flats between them. Example:
    the Mississippi birdfoot lobe [S86].
  - Wave-dominated: smooth coast, about one distributary. Examples: Nile, Senegal, São Francisco [S86].
  - Tide-dominated: trumpet-shaped (funnel) channels, because tidal discharge falls exponentially upstream. Examples: Fly,
    Ganges–Brahmaputra [S86].
- (unverified — from memory) Chinese examples: the Yellow River delta is river-dominated, lobate, switches lobes every few
  decades and progrades fast. The Pearl River delta is an island-studded drowned-valley embayment with many outlets. The
  Yangtze mouth is tide-influenced and funnel-shaped.

### 2.7 Waterfalls, knickpoints and hanging valleys
- Classic mechanism: a resistant caprock over weaker rock. The weak layer is undercut, the cap fails in blocks, and the blocks
  deepen the plunge pool. Retreat rates can reach about 1.5 m/yr [S89].
- At Niagara the cantilever analysis says the caprock should stay stable until the undercut reaches tens to over a hundred
  metres, but real notches are at most about 10 m. Gradual erosion of the falls face may matter more than episodic collapse [S89].
- In jointed sandstone (Zhangjiajie), dissection advances by headward knickpoint propagation along joints and faults [S34].
- Hanging valleys: tributaries fall from glacially truncated side valleys into a trough (Yosemite) [S89, low authority].
- Chinese falls usable as targets: Shizhangdong 十丈洞 (Chishui, Danxia) **76 m high, 80 m wide**, the largest Danxia
  waterfall [S28]. Dalongqiu 大龙湫 (Yandangshan, rhyolite) **197 m** (190 m in another source) [S50].
  (unverified — from memory) Huangguoshu 黄果树 (karst) ≈ 78 m high, ≈ 100 m wide. Hukou 壶口 (Yellow River) is a knickpoint
  gorge in flat-lying sandstone.

**Operator hints.** (1) Waterfalls appear naturally where the `K` field steps from low to high downstream (caprock); add a
plunge-pool dig of depth ≈ 0.2–0.5 × fall height (unverified — from memory). (2) Terraces: run the existing steady-state
solve at 2–4 successively lower base levels and keep the older valley floor as a tread outside the new channel belt
(`terraceH` on the valley-floor field `low`). (3) Meander width rules: λ ≈ 7–12 w, Rc ≈ 2–3 w.

---

## 3. Glacial landforms

### 3.1 U-valleys
- Cross-section `z = a·y^b`: b near 1 is a V (fluvial). Higher b is progressively more U-shaped, and b ≈ 2 is the parabola that
  valleys approach as glacial erosion goes on [S70, S71]. Measured means: 1.28 fluvial versus 1.54 glacial (Southern Alps);
  one glacial flank fitted b = 1.95 [S70].
- Form ratio `FR = depth / top width`. A large FR means overdeepening [S71]. Across 21,412 valleys (Patagonia, Southern Alps,
  Pyrenees), more intense and longer glaciation gives larger, wider parabolic cross-sections [S71].
- (unverified — from memory) Associated forms: truncated spurs, hanging tributary valleys whose floors stand tens to hundreds of
  metres above the trunk floor, rock steps and basins along the long profile, ribbon lakes in the basins.

### 3.2 Cirques, arêtes, horns, tarns
- A cirque is a semicircular hollow open downslope, with a steep headwall and a gently sloping floor. Rotational ice flow plus
  rock debris abrades the floor more than the walls and overdeepens it, which leaves a tarn [S74].
- Two cirques eroding toward each other leave an **arête** (or a col where they meet). Horns form where cirque glaciers attack a
  peak from several directions, usually three or more [S74].
- **Aspect preference.** Most cirque populations worldwide face poleward [S72]. Kamchatka has a very strong north bias, from
  insolation [S72, S73]. In the Black Sea Mountains, 66.5 % of cirques face north [S73]. In the Qilian Shan the aspect is
  predominantly north [S73]. Where wind dominates (Transantarctic Mountains) the bias is weak and lee-side, because snow is
  redistributed onto lee slopes [S72].
  - (unverified — from memory) In mid-latitude Northern Hemisphere ranges with westerly winds the mode is usually N to NE
    (shade plus snow drifted from the west). Cirques are typically 0.3–2 km long, the length/width ratio is near 1, headwalls are
    30–60°+, and floors are tilted back 5–20°.
- **Moraines.** (unverified — from memory) Terminal and recessional moraines are arcuate ridges across the valley. Lateral
  moraines are sharp-crested ridges along the valley walls, tens of metres high (over 100 m in the Himalaya). Medial moraines
  are dark stripes where two glaciers join.

### 3.3 ELA and snow line (Chinese numbers)
- **Taibai Shan 太白山 (Qinling, summit ≈ 3,767 m).** A short-lived late-Pleistocene ice cap with five outlet glaciers. The
  lowest late-Pleistocene snowline was **3,250–3,300 m**, from the lowest moraines, which is a depression of about 1,000–1,300 m
  relative to the present [S75]. There are no Pleistocene glacial remains below about 2,800 m in the mountains south of the
  Loess Plateau, and no older remnants below 2,600 m elsewhere in the Qinling [S75].
- Qilian Shan moraines reach down to about 2,300 m, and one reconstruction puts the Ice-Age ELA 1,100–1,600 m lower than
  today. That reconstruction is contested [S76].
- Present-day ELAs exist for 58,570 glaciers in the Second Chinese Glacier Inventory dataset [S77].
  (unverified — from memory) Present ELAs are roughly 3,800–4,400 m in the Tianshan, 4,500–5,100 m in the Qilian, and
  5,500–6,200 m on the interior plateau.

**Operator hints.** (1) Apply glacial carving only above an ELA parameter. The game's granite style already has
`snowLine 690 丈` (2,300 m), far below any real Chinese ELA, so treat it as a stylistic cold-mountain choice. (2) Cirques: seed
them on slopes facing within ±60° of north (or the lee of the prevailing wind), just above the ELA, carve a bowl with a
steep back wall and a back-tilted floor, and leave a tarn. (3) U-valleys: below each cirque, deepen and widen the existing
channel to a power-law section with b ≈ 1.6–2.0, and leave tributaries hanging.

---

## 4. Karst

### 4.1 峰丛 fengcong, 峰林 fenglin and 孤峰 isolated peaks
**Definitions.**
- The South China Karst nomination names *fengcong* (cone karst) as linked conical hills with depressions, valleys and gorges,
  and *fenglin* (tower karst) as isolated cones or towers on broad plains [S1].
- Waltham: *fenglin* are isolated hills rising from a plain that is normally limestone bedrock under a veneer of alluvium.
  *Fengcong* and *fenglin* are genetic terms and take precedence, while "cone" and "tower" should be descriptive only [S3].

**Base level and evolution (the key rule for a generator).**
- Fenglin developed where the water table was shallow, and fengcong where it was deeper. The two can develop at the same time
  [S2]. This is the "Guilin model".
- Fenglin evolves from fengcong through slow, continuous tectonic uplift with even slower erosion of the towers [S4].
- So the map rule is: **fengcong on the uplands, well above local base level, with closed depressions. Fenglin on the plain at
  base level, where the depression floors have joined into an alluviated corrosion plain at the water table.** 孤峰 isolated
  peaks are the last stage of fenglin.
  - (unverified — from memory) Fenglin towers carry foot caves and notches at plain level, cut by swamp water and floods, and
    their walls are steep to overhanging.

**Numbers.**
| quantity | value | source |
|---|---|---|
| Guilin–Yangshuo tower height (central basin) | **30–80 m** (9–24 丈) | [S3, S4] |
| Tower height near the fengcong margin | up to **300 m** (90 丈) | [S4] |
| Fengcong relief on the Li River | typically **100–300 m**, over **500 m** in places | [S3] |
| Cone slope, western Guizhou (Xiong 1992) | **45–47°**, uniform for all sizes; steeper elsewhere in Guizhou | [S3] |
| Fenglin slope, small Yangshuo sample | mean **75°** | [S3] |
| Fenglin vs fengcong slope | no significant difference in the small samples | [S3] |
| Guilin fengcong depressions (DEM, 188 depressions) | mean area **0.14 km²**; density **≈ 2.5 per km²** (unit ambiguous in the extract); **94 %** shallower than **60 m** and smaller than **0.5 km²** | [S5] |
| Tower vs cockpit separation | DEM contour, slope and centroid metrics work | [S6] |

Derived consistency check: 2.5 depressions/km² means a spacing of about 1/√2.5 ≈ 630 m (190 丈). A 0.14 km² depression is
about 420 m across (127 丈). A 45° cone with 100–300 m relief has a base radius about equal to its relief, so a base diameter of
200–600 m (60–180 丈). Cones 200–600 m across on a 630-m lattice fit together (derived).

**Plan view and drainage.**
- (unverified — from memory) Fengcong is "polygonal karst" (Williams): each closed depression drains to its own sink, and the
  depression catchments tile the ground like Voronoi cells. Cone summits sit near the cell vertices and saddles on the cell edges.
  Drainage is internal (centripetal into sinks, then underground). Underground rivers resurge as springs at the foot of the
  upland, on the fenglin plain, and allogenic rivers cross the plain meandering between towers.
- Colours (unverified — from memory): grey to white limestone with black and orange streaks (algae, iron) on walls, red terra
  rossa soils in depression floors, evergreen broadleaf scrub on towers, paddy and water on the plain.
- Climate (unverified — from memory): humid subtropical monsoon, about 1,300–2,000 mm/yr.

### 4.2 Dolines, uvalas, poljes
- Doline diameters range from about 1 m to several hundred metres. Size and distribution depend on lithology, tectonics,
  glaciation, climate and time [S13]. One Spanish massif with 3,100 depressions follows a fractal size law [S13].
- Uvalas are intermediate between dolines and poljes, km-scale, elongated or irregular, several hundred metres to several km
  long. The boundary between the terms is fuzzy [S12].
- A polje is a large closed karst basin with a **flat floor, karst drainage and steep marginal slopes** (Gams), and the rim is
  higher than the floor all round (Grund 1903) [S12]. Example: Livno polje has a 300 km² floor at 700–710 m, 69 km long and
  7–15 km wide [S12].
- (unverified — from memory) Poljes often flood seasonally (ponors overwhelmed) and are farmed. Doline depths are typically a
  few metres to about 100 m, depth/diameter about 0.1–0.3 for solution dolines and near 1 for collapse dolines.

### 4.3 天坑 tiankeng
- Definition (2005, from the South China Karst work): extremely large, deep closed depressions, originally tied to a collapse
  into a large underground river. Revised by Gunn et al. 2019: **more than 100 m wide and deep**, **diameter/depth ≈ 0.5–2.0**,
  steep or vertical walls, formed largely by collapse (an underground river is no longer required) [S7]. Zhu Xuewen's version:
  at least 100 m wide and deep, steep sides, an underground river along or once along the floor [S8].
- **Xiaozhai 小寨天坑 (Fengjie, Chongqing):** 626 m × 537 m, depth **511–662 m**, vertical walls [S9].
  (Derived: diameter/depth ≈ 0.9–1.2; in 丈, 188 × 161 丈 and 153–199 丈 deep.)
- **Dashiwei 大石围 (Leye, Guangxi):** width 599 m and depth 612 m [S10, low authority].
  (unverified — from memory) Depth 613 m, about 600 m E–W by 420 m N–S. The Leye group holds a few dozen tiankeng, and the
  floors carry primary forest.
- (unverified — from memory) Wulong's Houping tiankeng group and the Three Bridges tiankeng are part of the South China Karst
  property.

### 4.4 Natural bridges
| bridge | total height | deck thickness | length (along) | clearance | opening width | source |
|---|---|---|---|---|---|---|
| Tianlong 天龙桥 (Wulong) | 235 m | 150 m | 147 m | 96 m | 34 m | [S11] |
| Qinglong 青龙桥 (Wulong) | 281 m | — | — | — | 31 m | [S11] |
| Heilong 黑龙桥 (Wulong) | 223 m | — | — | — | 28 m | [S11] |
| Tianqiao Shengkong 天桥生空 (Wulingyuan, quartz sandstone) | 357 m above the valley floor | | | | | [S35] |

Travel sites give "spans" of 300–450 m for the Wulong bridges. These are probably the length of the whole arch and gorge
system, not the opening [S11]. In shape terms, a Wulong bridge is the remnant roof between two collapse tiankeng on one
underground river: a thick deck with a narrow slot underneath.

### 4.5 石林 stone forest (Shilin, Yunnan)
- Lithology: Middle Permian dolomitic limestone of the Qixia and Maokou Formations. It is a plateau karst with pinnacles carrying
  deep, sharp karren [S14].
- Genesis: the pillars began as **subsoil karren** under soil and sediment. The surfaces record shaping under cover, then the
  lowering of the cover, then reworking of the tops by rain. Thick, evenly composed beds favour it [S15]. The area was once
  under basalt [S17]. Fissure orientations follow regional faults and the late-Pleistocene to present stress field [S16].
- Heights: commonly 20–30 m, tallest about 30–40 m (popular sources) [S17].
- For the generator: these are 6–12 丈, far below even the 15-丈 grid. Use instanced pinnacle meshes or a displacement shader on
  a gently undulating plateau. A good rule is "exhume as cover is stripped": pinnacles are taller where the soil cover is thinner.

### 4.6 Travertine terraces (Huanglong, Jiuzhaigou)
- **Huanglong 黄龙:** travertine formations about **3.6 km** long [S18], more than 3,300 [S18] to 3,400 pools down about a
  **600 m** elevation gain (visitor guide) [S18]. Derived mean gradient ≈ 600/3,600 ≈ 0.17, about 9–10°. Deposition comes from
  calcium-bicarbonate water and is helped biologically [S18]. IUCN called the terraces unique in Asia and among the three most
  outstanding in the world [S18].
- **Jiuzhaigou 九寨沟:** fluvial travertine shoals, waterfalls, pool dams and multicoloured lakes at **2,200–2,900 m**. Dams grow
  across the flow, helped by algae and plants. Deposition is seasonal (wet spring–summer) [S19].
- (unverified — from memory) Rimstone dams are centimetres to a few metres high, with lake surfaces stepping down in a staircase.
  Colours: milky turquoise to deep blue water over cream-gold travertine, under conifer forest.

**Operator hints.** (1) Compute height above local base level `hb = h − low` (the repo already has `low`). Use
fengcong where hb is large and fenglin plus a flat plain where hb is small (the water table). (2) Fengcong: blue-noise sinks at
~190 丈 spacing, a cone field with peaks at Voronoi vertices, 45° flanks, depressions as local sinks excluded from
`floodRoute` (internal drainage). (3) Fenglin: the existing `towerField` profile `(1 − t^p)^q` with a base notch, on a
flattened plain. (4) Tiankeng and bridges are rare hand-placed operators: a vertical-walled cylinder ≥ 30 丈 across and deep,
two in a row on one underground river with a deck between them.

---

## 5. Danxia 丹霞

### 5.1 Definition, lithology and setting
- Danxia is landform made mainly of **continental red beds** and characterised by **steep cliffs** [S20]. Peng Hua et al.:
  an erosional landscape on red beds, characterised by scarp slopes [S21]. The genesis and controls are still debated [S20].
- Danxiashan 丹霞山 (the type locality): reddish Late Cretaceous conglomerate and sandstone, laid down in alluvial-fan and desert
  settings in a faulted basin, then uplifted and dissected [S25]. The geopark covers 290 km², about half of it Danxia, and the
  highest peak, Bazhai 巴寨, is 619 m [S25].
- Chishui 赤水: Jurassic and Cretaceous fluvial-lacustrine red beds at the edge of the Yunnan–Guizhou Plateau, where it drops to
  the Sichuan Basin [S28]. Wuyishan 武夷山: red, horizontal or slightly inclined strata, Jurassic to Tertiary [S31].
- The six China Danxia components form an arc about 1,700 km across six provinces, with subtropical evergreen broadleaf forest
  [S22]. IUCN lists peaks, towers, mesas, cuestas, cliffs, valleys, caves and arches, shaped by uplift, weathering and erosion
  since the Neogene [S22].
- **"顶平、身陡、麓缓"** (flat top, steep body, gentle foot). (unverified — from memory) This is the standard Chinese
  textbook formula for a Danxia hill. It translates into a three-part profile: a flat or gently domed cap (often forested), a
  near-vertical cliff of thick sandstone or conglomerate, and a concave talus/footslope on weaker interbeds.

### 5.2 Small forms
- Experiments on 122 samples from Danxiashan's horizontal grooves, honeycomb caves and through-caves point to several processes:
  differential erosion due to lithology, solution and recrystallisation, freeze–thaw, acid corrosion, weathering, lateral river
  erosion and tectonic uplift [S26].
- Mudstone with high clay content tends to collapse, and sandstone with high clay content weathers into grooves [S27].
- Slot canyons: Taining's Jiulongtan canyon is 5,000 m long, 100 m at its widest and less than 1 m at its narrowest [S30].
- (unverified — from memory) Alcoves (岩槽, 额状洞) are recesses at the weak interbeds, metres to tens of metres deep, often with
  temples built in them. 一线天 slots follow single vertical joints, are about 0.5–2 m wide and tens to a few hundred metres
  long. Cliffs carry black vertical streaks where water runs and pale scars where slabs fell.

### 5.3 Stages: youth → maturity → old age
- The six components show a sequence from least to most eroded: "young", "mature", "old age" [S22]. In young sites, valleys are
  deep and narrow. As the landform ages, valleys widen and isolated towers and ridges are left [S23].
- Stages per component:
| component | stage | type | source |
|---|---|---|---|
| Chishui 赤水 (Guizhou) | early youth | plateau–canyon | [S22] |
| Taining 泰宁 (Fujian) | late youth | peak-cluster canyon | [S22] |
| Langshan 崀山 (Hunan) | early mature | dense peak cluster | [S22] |
| Danxiashan 丹霞山 (Guangdong) | late mature | peak cluster / peak forest | (unverified — from memory) |
| Longhushan 龙虎山 (Jiangxi) | old age | peak forest, isolated peaks on wide valley floors | (unverified — from memory) |
| Jianglangshan 江郎山 (Zhejiang) | old age | isolated giant pillars (孤峰) | (unverified — from memory) |
- **Hypsometric thresholds** (Qiaoba–Zhongdu study): infant stage **HI > 0.6**, mature **0.4–0.6**, old **HI < 0.4** [S24].
  The authors warn that stage cannot be judged from present shape alone, because neotectonics affects slope failure [S24].
  This is directly usable as a generator dial.
- Sizes:
  - Jianglangshan's three pillars (郎峰, 亚峰, 灵峰) exceed 300 m in height: Yafeng 305 m, Lingfeng 298 m. The main peak stands
    at 816.8–819.1 m elevation [S29].
  - Langshan's peak elevation is 818 m [S29].
  - Wuyishan: 36 peaks and 99 rocks along the Nine-Bend Stream (九曲溪), about 9–10 km long [S31].
  - (unverified — from memory) Langshan's 辣椒峰 "chilli peak" is a pillar of about 180 m. Danxia cliff heights commonly run
    from tens of metres to about 200–300 m.

### 5.4 Why Zhangye 张掖 is different
- Zhangye's rocks are mainly siltstone and sandstone interbedded with mudstone, with **low cementation and poor resistance to
  weathering**. They fragment, so steep slopes and cliffs hardly form. Instead they make gently rounded, relatively low hills
  [S32].
- The colours (red, purplish red, yellow-green, grey-green, grey-black) come from iron minerals whose oxidation state changed with
  alternating oxidising and reducing conditions [S32]. Red is hematite, yellow is limonite, and pale green to blue-grey is
  chlorite and chalcedony (popular source) [S32]. One study argues the strata are a palaeosol sequence and ties the colour
  contrast across a syncline to later weathering and burial position relative to groundwater [S33].
- (unverified — from memory) The climate is arid, about 100–200 mm/yr, so slopes are bare and the banding is visible. The
  stripes follow folded bedding, so they curve and dip, unlike the flat-lying Danxia of the south.
- **For the generator:** Zhangye is a *badland-hill* style (rounded ridges, dense rills, dipping coloured bands, no vegetation),
  not a cliff operator. It is closer to the loess operator with folded colour bands than to Danxia.

**Operator hints.** (1) Danxia cap-rock profile: `H = plateau` above the cap, a near-vertical wall through the sandstone
package, a talus fillet at 25–35° (unverified — from memory) below, which is "顶平身陡麓缓". (2) Stage dial: drive the joint-
widening and valley-floor lowering until the local HI hits 0.6 (youth canyons), 0.5 (mature peak clusters) or 0.35 (old-age
isolated peaks on a plain). (3) Horizontal grooves and alcoves at weak interbeds: a shader band every few metres plus a few
inward notches in the wall profile. (4) Colour: red to purple-red rock, black water streaks, green flat tops.

---

## 6. Quartz-sandstone peak forest (Wulingyuan / Zhangjiajie 张家界)

### 6.1 Formation
- More than 3,000 narrow quartz-sandstone pillars and peaks, many over 200 m high [S35]. The rock is about **95 % quartz**,
  vertical joints are well developed and allow deep river incision, and low tectonic activity lets the pillars stand [S36].
- Devonian quartz sandstone in near-horizontal beds, shaped mainly by running water, gravity collapse and weathering into
  angular, tall pillar forests [S39]. Joint sets trend **NNW, ENE and NE** [S37]. Uplift, a densely spaced joint pattern and
  uniform sandstone beds are the prerequisites [S38].
- Stratigraphy (low-authority source): the peak forest sits in the Devonian Yuntaiguan 云台观组 and Huangjiadeng 黄家磴组
  formations, over about 86 km² [S39].

### 6.2 Shape and numbers
| quantity | value | source |
|---|---|---|
| Pillars and peaks | > 3,000 (WCMC: > 3,100) | [S35] |
| Pillars over 200 m | > 1,000 | [S39] |
| Tallest | Jinbianyan 金鞭岩 ≈ 350 m; peak walls up to 350 m | [S34, S39] |
| Height range | tens of metres to 400 m | [S39] |
| Landform levels | four levels between 300 and 1,000 m elevation, stepping down from a high platform to the valley floors | [S37] |
| Planation surface | first-order surface at 1,100–1,300 m (late Tertiary); sandstone platforms below it, late Pliocene to early Pleistocene | [S40] |
| Height/diameter | "large height/diameter ratio, high pillar density" (no number given) | [S39] |
- Pillar diameter was not found. (unverified — from memory) Typical pillar widths are about 10–50 m and height/width is
  often 3–10.
- Derived density: 3,000 pillars over the ~86 km² core (low authority) gives ≈ 35 per km², a spacing of about 170 m
  (≈ 50 丈). Over the full property area (unverified — from memory, ~264 km²) it is ≈ 11 per km², a spacing of about 300 m
  (≈ 90 丈).

### 6.3 Evolution
- Chinese sequence: **平台 platform → 方山 mesa → 峰墙 peak wall → 峰林 peak forest → 峰丛 peak cluster → 残林 remnant forest**
  [S39]. Another source gives 平台 → 方山 → 峰墙 → 峰林 → 残林 [S39].
- May et al. 2018 (cosmogenic nuclides plus GIS) [S34]:
  1. slow lowering after uplift;
  2. fast plateau dissection by **headward knickpoint propagation along joints and faults**;
  3. growing wall retreat while overall denudation falls;
  4. consumption of the pillars and peak forest.
  Peak-forest formation started in the **Pliocene**.
- **Erosion rates** [S34]:
| site | rate |
|---|---|
| narrow channels and valleys at pillar bases | **83–122 mm/kyr** |
| vertical walls and pillars | **30–84 mm/kyr** |
| peak-wall tops | **≈ 2.5 mm/kyr** |
| catchment-wide (river sediment) | 26–96 mm/kyr, matching wall retreat |
  Derived: channels cut about 35–50 × faster than tops, so the tops are essentially frozen. The pillar summits keep the old
  plateau surface as a **concordant summit envelope**, and only the walls and channels move.
- Natural bridges: Tianqiao Shengkong rises 357 m above the valley floor [S35].
- Climate, colours and vegetation (unverified — from memory): humid subtropical, about 1,400 mm/yr, frequent mist. Pale grey to
  buff sandstone with dark water streaks, pines (*Pinus massoniana*) and shrubs on every ledge and summit.

**Operator hints.** (1) Start from a flat plateau (`plateau` style) at the summit envelope. (2) Cut a joint network: 2–3
straight joint sets at fixed azimuths (for example NNW, ENE, NE), not isotropic Worley cells. Spacing 50–90 丈 (derived).
(3) Lower the channels along joints toward base level, retreat walls in proportion to their exposure, and leave the tops
nearly untouched (rate ratio ~40:1). (4) Stage by time: the walls (峰墙) are joints cut in one set only, the forest is both sets
cut, and the remnants are pillars thinned below a minimum width and dropped. The repo's existing Worley pillars are a
reasonable stand-in, but a joint-set version gives the real straight streets and walls.

---

## 7. Granite: Huangshan, Huashan, Sanqingshan

### 7.1 Facts
- **Huangshan 黄山:** a small Early Cretaceous composite batholith, main phase about **127 Ma**, a later alkali-feldspar phase about
  **105 Ma** [S41]. Primary joints in one unit run perpendicular to its contacts [S41]. One study argues the peaks come from
  differential erosion rather than episodic uplift [S41]. Lotus Peak 莲花峰 is **1,864 m**; Lotus Peak, Guangmingding 光明顶 and
  Tiandu 天都峰 all exceed 1,800 m [S42, S43]. The rock breaks along vertical planes, giving sheer cliffs and narrow spires [S42].
- **Sanqingshan 三清山:** **48 granite peaks and 89 granite pillars**; Mount Huaiyu 1,817 m [S44], Yujing Peak 1,819.9 m
  [S45]. The Python pillar 巨蟒出山 is **128 m** tall (120 m in one source), flat-topped like a head and tapering at the base [S45].
  An island of temperate forest sits above the subtropical landscape [S44].
- **Huashan 华山:** a granite block on the Weihe Graben margin, bounded by a steep normal fault (§1.2) [S46, S47].
  (unverified — from memory) South Peak 2,154.9 m; walls of several hundred metres, the "天下险" mountain.
- **Exfoliation domes.** Sheeting joints open where surface-parallel compression meets a convex surface. Curvature and slope,
  not relief, are the key geometric factors (Martel) [S48]. About 90 % of a studied Yosemite dome surface is convex in at least
  one direction [S48]. A Korean granite dome exfoliates at an average **5.6 cm/ka** [S48]. Cyclic thermal stress on curved
  surfaces may also drive it [S48].
- (unverified — from memory) **Tors** form in two stages: deep chemical weathering along joints, then stripping of the
  weathered grus leaves core-stone stacks. **Spires versus domes:** dense vertical joints (spacing metres to tens of metres) give
  spires and pinnacles (Huangshan, Sanqingshan). Sparse joints give bornhardts and exfoliation domes. Drainage is rectangular
  (joint-controlled) in spire fields and radial on domes. Huangshan's famous peak count is 72.

### 7.2 Shape signature
- (unverified — from memory) Steep walls 60–90° on joint planes. Summit forms are rounded knobs (domes) or narrow fins and
  needles (spires). Lower slopes have block fields and grus fans. Colours: light grey to pinkish granite, darker where wet,
  lichen-stained. Pines root in joints (Huangshan pine *Pinus hwangshanensis*).

**Operator hints.** (1) The repo's `needles` (cell 46 丈, h 26–84 丈 = 87–280 m) covers the Sanqingshan pillar scale (Python ≈
38 丈). (2) Add a joint-aligned version: two orthogonal joint sets plus a sub-horizontal sheeting set, carve slots along the
vertical sets and make convex caps (dome profile) where joint spacing is large. (3) Exfoliation dome: an elliptic convex cap
`h = H·(1 − (r/R)²)^0.5..1`, plus onion-skin terrace lines in the shader.

---

## 8. Volcanic

### 8.1 Rhyolite: Yandangshan 雁荡山
- A Cretaceous rhyolitic volcanic field with a **resurgent caldera**. It records four major events: eruption, collapse,
  overflow and resurgent eruption [S49]. The caldera formed about 100 Ma (another source: 120–100 Ma) [S49].
- The highest peak, Baigangjian 百岗尖, is 1,056.5 m (other sources give 1,108 m and 1,150 m) [S49].
- Dalongqiu waterfall drops **197 m** (190 m in Frommer's) [S50]. Lingfeng 灵峰, Lingyan 灵岩 and Dalongqiu are the
  "Three Wonders" [S49].
- (unverified — from memory) The landforms are cut in flat-lying welded tuffs and rhyolite lavas with vertical cooling and
  tectonic joints: stacked walls (嶂), pillars and peaks, gate-like gaps (门), caves and alcoves (洞), and plunging falls over
  resistant ignimbrite sheets. Colours: pale grey, lilac and pinkish rhyolite, dark where wet.

### 8.2 Stratovolcano and caldera lake: Changbaishan 长白山 Tianchi 天池
- Structure in three parts [S52]:
  1. a basaltic, shield-like **lava plateau**, Pliocene to early Pleistocene (~5–1 Ma);
  2. a polygenetic **trachyte / pantellerite cone**, late Pliocene to Pleistocene, with small basaltic scoria cones (~1–0.01 Ma);
  3. a **summit caldera**, Holocene, **5 km wide and 850 m deep**, holding Tianchi.
- Peak elevation 2,749 m [S52]. The Millennium eruption of 946 CE was VEI 6–7 and ejected 40–120 km³ of tephra [S51]. An
  earthquake during it collapsed the inner caldera wall into the lake, which overflowed [S52].
- Tianchi: surface **2,189 m**, area **9.82 km²**, **4.85 km N–S × 3.35 km E–W**, maximum depth **373 m** (384 m in another
  source), mean depth 204–213 m [S51].
- **Stratovolcano profiles (Karátson et al. 2010):** the lower half of a regular stratovolcano always fits a **logarithmic**
  curve. The upper half is either straight (C-type cone) or concave (P-type, probably shaped by lava flows) [S53].
- **Shield versus stratovolcano (Grosse & Kervyn 2018):** shields have height/basal width 0.01–0.1 and average slopes 1–15°.
  The approximate threshold between them is an **average slope of 12° and H/W_B = 0.10** [S54].
  (unverified — from memory) Upper cone slopes on stratovolcanoes reach 30–35°.
- Drainage (unverified — from memory): radial (centrifugal) off a cone, centripetal into a caldera, with a single outlet notch
  (Tianchi drains north through a breach to the Erdaobai River and a waterfall).

### 8.3 Basalt plateaus and columnar joints
- "Traps" are named from Swedish *trappa*, staircase. Canyons in flood basalt have stair-like slopes: the lower parts of flows
  form cliffs, and flow tops or interbeds form slopes [S56].
- Flow lobes: modal thickness **8 m** in thin-lobe formations and **17 m** in sheet-lobe formations (Deccan, Columbia River).
  Sheet lobes of 75–80 m are rare, and > 100 m is exceptional [S55]. Ethiopian Traps: median flow thickness about 15 m in the
  lower and upper 400 m, about 4 m in the middle [S55]. Labrador steps are about 50–70 m, one flow or a series of flows [S56].
- **Columnar joints:** column radius is proportional to stria size and inversely proportional to the cooling rate [S57].
  Giant's Causeway: about 40,000 columns, tallest about 12 m, lava up to 28 m thick, column sides 8–18 in (20–46 cm), mostly
  hexagonal with some 4–8 sided [S58].
- (unverified — from memory) Chinese examples: Linjin and Zhangzhou coastal columnar basalt (Fujian), Liuhe 六合 basalt columns
  (Nanjing), Jingpo Lake 镜泊湖 (lava-dammed lake with the Diaoshuilou fall), Wudalianchi 五大连池 (cinder cones and lava-dammed
  lakes), the Emeishan basalt that caps Emei's summit cliff.

**Operator hints.** (1) Stratocone: radial profile `h(r) = a − b·ln(r)` for the lower flank, a straight or concave upper cone,
H/W_B > 0.1 and average slope > 12°. (2) Caldera: subtract a flat-floored cylinder of width ≈ 0.2–0.3 of the base (Changbai:
5 km caldera on a cone a few tens of km across, unverified — from memory), fill with a lake to an outlet notch. (3) Basalt
plateau: `terraceH` with step 2.5–5 丈 (single flows) or 15–21 丈 (composite). The repo's volcanic bench step of 17 丈 = 57 m
matches the composite Labrador steps. (4) Columns are a shader or mesh detail (20–46 cm), never heightfield.

---

## 9. Loess 黄土

### 9.1 Facts
- Dongzhi tableland 董志塬: a loess platform of about **900 km²** with loess thicker than **200 m**. Loess tablelands are large
  platforms with flat tops in the centre of the Loess Plateau [S59].
- Breakup: gully headward retreat of about **0.5–6.6 m/yr** for large gullies over the past 2,000 years [S59].
- **Evolution 塬 → 梁 → 峁:** as erosion progresses, tableland area shrinks fast or vanishes and the dominant types become loess
  ridge and loess hill [S64]. A residual tableland evolves into a branched loess ridge [S65]. Yuan, liang and mao are the meso and
  micro landform units that define land types in northern Shaanxi [S69].
- **Gully density** (km of gully per km²):
| setting | density | source |
|---|---|---|
| aeolian/dune site → loess ridge-hill site | 3.4 → 6.8 | [S60] |
| 46 watersheds | mean 3.41, max 21.92 | [S61] |
| Chabagou 岔巴沟, middle reaches | mostly 7–11 | [S62] |
| older documents | ~6, at most 8; remote sensing found up to 30 in northern Shaanxi | [S63] |
  Derived: a drainage density D means a typical distance between channels of about 1/D. At D = 5 km/km², gullies sit about
  200 m (≈ 60 丈) apart, which is under 2 cells on a 40-丈 grid. Main gullies need the 15-丈 grid. Side gullies and rills are
  shader detail.
- **Vertical walls:** original vertical joints are non-tectonic and closely tied to loess anisotropy. They drive erosion, gully
  growth and landform fragmentation on the plateau [S67]. Open vertical joints weaken loess more than closed ones, and joints
  longer than about 5 m (up to 15 m) lower slope safety [S66]. Cohesive fine sediment like loess holds vertical walls with
  episodic mass failure, especially under a more resistant cap [S68].
- A 30-m landform dataset now classifies the Loess Plateau into 28 types at three levels [S69].

### 9.2 Shapes (unverified — from memory)
- **塬 yuan:** broad flat tableland, top slopes about < 3–5°, edged by sharp rims that drop into steep gully heads.
- **梁 liang:** long, narrow ridges with convex cross-sections, crests tens to a few hundred metres wide, side slopes about
  15–35°, branching in plan.
- **峁 mao:** isolated, round to oval domes a few hundred metres across with convex profiles, the last stage.
- **沟 gullies:** walls 35° to vertical, flat floors with check-dam silts (淤地坝), V-heads with sinkholes and tunnel erosion.
  Main gullies are often 50–200 m deep. Colour: buff-yellow loess with reddish palaeosol bands one to a few metres thick.
  Fields on terraces (梯田) and cave dwellings (窑洞) cut into vertical walls. Climate is semi-arid, about 300–600 mm/yr,
  with summer storms.
- Drainage: very dense dendritic to pinnate, with gully heads eating back into the tableland edge.

**Operator hints.** (1) Stage by loess-thickness-to-relief: a flat 塬 with only peripheral gully heads → branched 梁 when
gullies cut through → isolated 峁 when interfluves are below a width threshold. (2) Gully walls with `terraceH` at half weight
(as now) plus vertical-joint slabs. (3) Keep gully depth below loess thickness (> 200 m ≈ 60 丈 at Dongzhi). The repo's hand
gullies are 66–108 丈 (220–360 m) deep, which only makes sense if they cut into bedrock below the loess.

---

## 10. Coasts and islands

### 10.1 Cliffs, platforms, stacks and arches
- Shore platforms (Sunamura): **Type A** slopes gently from the cliff foot to below sea level with no clear break. **Type B**
  is horizontal or nearly so and ends seaward at a marked scarp [S90]. Type A forms where cliffs are soft, with uniaxial
  compressive strength at or below about 5 MPa [S90].
- A New Zealand Type B study measured widths of **80–270 m** and gradients of **0.2–1.3°** [S90]. In the laboratory, wave
  erosion at the cliff foot drops once the platform reaches about 60 m wide [S90]. Platforms can reach a temporary static
  width, and rock resistance mainly sets platform height and type [S90]. One proposed path goes from Type B to Type A by loss of
  the low-tide cliff and downwearing [S90].
- (unverified — from memory) Headland sequence on jointed rock: crack → sea cave → arch → stack → stump, with stacks left on the
  platform tens to a few hundred metres off the cliff. Bays form in weak rock between headlands of resistant rock.

### 10.2 Tombolos
- A tombolo forms when the island's (or breakwater's) alongshore length L divided by its offshore distance D exceeds **about
  1.0**. Below that, a salient forms instead [S91]. Breakwater studies give salients at L/D < 0.6–0.7 and tombolos at
  L/D > 0.9–1.0 [S91]. Artificial islands: a D/L threshold of 0.44–0.9 [S91].
- Length alone is not decisive where swell refraction or reefs dominate [S91].
- (unverified — from memory) Chinese example: Zhifu Island 芝罘岛 at Yantai, a large land-tied island on a sand tombolo.

### 10.3 Volcanic island arcs
- Arc volcanoes are subregularly spaced, **30–100 km** apart depending on the arc, and most arcs have a characteristic average
  [S92]. Cook Inlet volcanoes stand about 70 km apart, the Alaska Peninsula about 50 km [S92]. In the Kermadec arc the spacing
  rises from 30 km to 58 km northward [S92]. Central American centres average about 27 km [S92].
- Derived: 30–100 km is 9,000–30,000 丈, so a world-crossing arc would hold about 4–15 volcanoes.
- (unverified — from memory) Arcs are curved, convex toward the trench, with the volcanic front about 100–200 km from the trench.

### 10.4 Atolls
- An atoll is a ring of coral reef around a lagoon. There are about 440, most in the Pacific [S93]. Darwin's model is a fringing
  reef that keeps growing up while its volcano sinks [S93]. Purdy & Winterer note that barrier-reef and atoll lagoons have
  similar depths, which subsidence does not predict, and argue that rainfall-driven solution of exposed reef (antecedent karst)
  shapes the lagoon [S93]. Darwin gives 25 fathoms (~46 m) at one point in the Keeling lagoon [S93].
- (unverified — from memory) Lagoons are typically 20–80 m deep. Reef flats are a few hundred metres wide, with islets (motu)
  on the windward rim and passes on the leeward side. Atolls range from about 1 km to over 50 km across.

**Operator hints.** (1) Platforms: a near-flat bench at about sea level, 24–81 丈 wide, in front of resistant cliffs. (2) Stacks
from joint cells near headlands. (3) Tombolo test: link an island to shore with a low sand bar when L/D > 1. (4) Arc: place
cones every 9,000–30,000 丈 along a curved line, offset 30,000–60,000 丈 from a trench (unverified — from memory).

---

## 11. Mist and cloud-sea climatology 云海

### 11.1 Physics
- A sea of clouds is an overcast layer of stratocumulus seen from above, with a fairly uniform top and wave-like undulations.
  It forms in valleys or over seas in very stable air (an inversion), with saturation below and dry air above [S94].
- Nocturnal cold-air pools: in the Peter Sinks basin (Utah) the inversion reached **22 K within 100 m** on clear, dry nights
  [S95]. Valley and basin inversions generally deepen and strengthen overnight [S95]. In winter, cold-air pools can persist for
  long periods. In late winter and spring the nocturnal inversion is destroyed nearly every day by the growing convective
  boundary layer [S95].
- Orographic cloud: on a Chinese mountain (Jiuxian Shan) water vapour condenses through entrainment and mixing in an updraft from
  orographic lifting, and an inversion forms during the maintenance stage [S96]. Emei 峨眉 averages **more than 300 fog days a
  year**, because the monsoon flow is blocked and forced up the slope (upslope fog) [S97].
- China-wide, fog is more frequent in autumn and winter than in spring and summer, and fog days have generally fallen since the
  1980s [S98].
- In summer the cloud sea usually forms at night or early morning, while in winter it can also last through the day [S94].

### 11.2 Huangshan
- Fog days: about 255–260 per year (travel sources; 259 in one with 7.9 °C mean temperature, 2,369 mm precipitation and
  180.6 rain days at the summit) [S42]. "200+ days a year in cloud" (Wikivoyage) [S42]. Official 1991–2020 normals for the
  1,840 m station exist but could not be read [S42].
- Season: the cloud sea is most common from **November to May**, especially when skies clear after rain or snow [S43].
- **Cloud-top classes used by local guides** [S43]:
| cloud top | what stands above it |
|---|---|
| < 800 m | lower viewpoints already see the sea |
| < 1,600 m | high viewpoints (Guangmingding, Pingtian 平天) look over it |
| 1,600–1,800 m | only the main summits (Lotus, Guangmingding, Tiandu, all > 1,800 m) stand out as islands |
- The sea is named by sector: East, South, West, North and the central Tianhai 天海 [S43].

### 11.3 Where cloud seas form (generator rules)
- Sourced mechanism plus derived rules: (1) closed or semi-closed basins and valleys (cold-air pooling) → the fog top is level,
  close to the basin's spill point, so the sea surface should be one height per basin, flat with slight undulation.
  (2) Windward slopes of ranges facing the moist flow → orographic cloud banks on the slope, higher and more broken.
  (3) After rain, under clear skies, in autumn to spring → highest frequency.
- The repo's per-sect cloud anchors (472–482 丈 ≈ 1,573–1,607 m) match Huangshan's "1,600 m" class, where only the main summits
  break through. This is a good default; a "1,600–1,800 m" variant hides all but the very top.

---

# Part 2 · Painting and geomancy

## (a) 皴法 texture strokes → real rocks → shader hints

The core link is sourced: cun strokes were devised to give "geologic credence" to outlined mountain forms [S99], the strokes
are named for what they look like and were chosen to suit the mountain [S101], and many landscape skills depend on the rock
type [S100]. Hemp-fibre suits gentle slopes and axe-cut suits hard rocky surfaces [S100]. The rock/landform columns below go
further; anything not tagged is my interpretation.

| 皴 stroke | masters (sourced where tagged) | what it looks like | rock / landform it reads as | shader / generator hint |
|---|---|---|---|---|
| **披麻皴** hemp-fibre | 董源 (created it), 巨然 [S99, S101]; 赵孟頫 looser, dry brush [S102]; (unverified — from memory) 黄公望 《富春山居图》 long hemp-fibre | long, slightly sinuous, broken, mostly centre-tip lines [S100, S101] | soft, soil-mantled Jiangnan earth hills (土山) [S101, S103]: deeply weathered granite, sandstone or shale with regolith, rounded crests and dense parallel rills | long strokes along the steepest-descent direction on 10–30° slopes, low contrast; for `hill`, karst uplands, loess gully sides |
| **雨点皴** raindrop | 范宽 《溪山行旅图》 [S99, S108] | dense short vertical dots and ticks | northern rock with "more stone than soil" [S101]: massive cliffs of the 关陕 region (Huashan, Zhongnan); one essayist compares it to the Danxia conglomerate of Zhaojin 照金 [S108] | stipple density ∝ slope on steep walls; for granite walls and Danxia cliffs |
| **卷云皴** rolling cloud | 郭熙 (after 李成), 《早春图》 [S99, S104] | curling, cloud-like contours on rounded masses | rounded, deeply weathered knobs and boulders (granite core-stones, eroded rounded hills) | curvature-driven arcs on convex knobs (use plan curvature); granite domes, volcanic knobs |
| **斧劈皴** axe-cut | 李唐 [S99]; (unverified — from memory) 马远, 夏圭 大斧劈 | broad, side-brush wedges | hard, angular, joint-bounded rock [S100]: granite walls, quartz sandstone, rhyolite and columnar volcanics, Taihang-type cliffs | wedge strokes aligned to joint planes / facet normals, hard light–dark break; for `granite`, `pillars`, `volcanic` |
| **折带皴** folded belt | 倪瓒 (坡石以折帶皴, 《楓落吳江圖》) [S103] | horizontal strokes that turn down at a right angle | (interpretation) horizontally bedded rock with vertical joints: the low banks and hills of Taihu, flat sandstone and limestone ledges | stepped contour strokes: horizontal along contours, dropping at cliff edges; for Danxia, Wulingyuan, karst ledges, loess benches |
| **米点皴** Mi dots | 米芾, 米友仁 [S103] | wet horizontal dots | misty, forested, low Jiangnan hills [S103] | horizontal elliptical dabs fading with fog depth; for `hill` and karst in mist |
| **解索皴** untied rope | 王蒙 (with 牛毛) [S106]; 赵孟頫 on the side peaks of 华不注 [S102]; common in literati painting [S103] | long curling strands like unravelled rope | deeply dissected, convoluted ridges with continuous 气脉 (王蒙 《青卞隐居图》 1366, where scholars speak of its 龙脉) [S105] | sinuous lines along ridgelines and gullies |
| **牛毛皴** ox-hair | 王蒙: long hemp-fibre broken into fine short curly strokes [S105] | dense, fine, curly hatching | dense, forested, soil-covered mountains | high-frequency curly hatching, low amplitude |
| **荷叶皴** lotus-leaf | 赵孟頫 《鹊华秋色图》, the front of 华不注山 [S102] | strokes running down from the peak and branching like lotus-leaf veins [S102] | a sharp, conical (twin-peaked) hill [S102, S107]; 华不注 is Mesozoic intrusive monzonite/gabbro [S107]; in shape terms, **radial gullies on a cone** | radial strokes from the summit following the flow directions; for karst cones, volcanic cones, inselbergs |
| 刮铁皴 iron-scrape | (named alongside 斧劈, 折带 for hard rock) [S101] | dry, scraped strokes | hard, splitting rock | a harsher variant of 斧劈 |

Suggested style mapping for the repo: `pillars` → 斧劈 + 折带; `granite` → 斧劈 (walls) + 卷云 (domes) + 雨点 (great faces);
`volcanic` → 斧劈 + 折带 (stacked tuff 叠嶂); `karst` → 米点 + 荷叶 (cones) + 披麻; `hill` → 披麻 + 牛毛 + 米点;
`loess` → 折带 (benches) + 披麻 (gully walls); red Danxia → 折带 + 雨点.

## (b) 郭熙 《林泉高致》 composition rules for a map

**三远 (sourced).** "山有三远：自山下而仰山巅，谓之高远；自山前而窥山后，谓之深远；自近山而望远山，谓之平远。" [S109]
The same passage gives different colour and momentum demands for each distance [S109].
(unverified — from memory) Those demands are: 高远之色清明，深远之色重晦，平远之色有明有晦；高远之势突兀，深远之意重叠，
平远之意冲融而缥缥缈缈。 韩拙 (《山水纯全集》) added 阔远, 迷远 and 幽远 for "six distances" [S110].

**可行、可望、可游、可居 (sourced).** Guo Xi ranks landscapes one can dwell in and wander in above those one can only pass
through or look at [S111].

**Other 林泉高致 rules (unverified — from memory, quoted from the standard text):**
- 大山堂堂为众山之主，所以分布以次冈阜林壑，为远近大小之宗主也。
- 山欲高，尽出之则不高，烟霞锁其腰则高矣；水欲远，尽出之则不远，掩映断其派则远矣。
- 山以水为血脉，以草木为毛发，以烟云为神彩。
- 山近看如此，远数里看又如此……所谓山形步步移也；山正面如此，侧面又如此……所谓山形面面看也。
- 春山淡冶而如笑，夏山苍翠而如滴，秋山明净而如妆，冬山惨淡而如睡。

**王原祁's 龙脉 (sourced).** In 王原祁's theory the 龙脉 is the central idea of 经营位置 (composition) [S112]. The Met
describes his rock forms as connected and coalescing into undulating dragon veins through which the mountain's 气势 flows
[S112]. (unverified — from memory) The 《雨窗漫笔》 text pairs 龙脉 with 开合 (open–close) and 起伏 (rise–fall).

**Translated into map-layout rules (my proposals):**
| rule | measurable layout criterion |
|---|---|
| 宗主: one master mountain per region | each sect region has one summit ≥ 1.2–1.5 × the next highest within 3R; secondary peaks at 0.6–0.85 of its relief, arranged asymmetrically |
| 烟霞锁其腰 | the cloud band sits at 0.4–0.65 of the master peak's local relief (above `Lv`), so the summit floats |
| 掩映断其派 | rivers are hidden by interlocking spurs: from any viewpoint, a river is seen in 2+ separate segments (spur overlap > 0 along the valley) |
| 高远 | pillar or cliff fields where a viewer at the foot sees a skyline elevation angle > 45° |
| 深远 | 3–5 overlapping ridge layers in depth along the main approach views |
| 平远 | at least one lake or plain per region with a low horizon (skyline < 5°) and far hills |
| 步步移, 面面看 | avoid radial symmetry and repeated shapes; masses anisotropic (aspect 1.2–2) with different faces per side |
| 可行可望可游可居 | each region has a path network, viewpoints, a scenic loop and habitable flats (slope < 10°) |
| 龙脉, 开合, 起伏 | every massif has a continuous main ridge from the master peak with alternating highs and saddles, opening into basins and closing into gorges |
| 四时 | seasonal palette targets: spring pale and light, summer saturated green, autumn clear and warm, winter grey and muted |

## (c) 风水 形势派 → measurable site criteria

**Sourced anchors.**
- 《葬书》 (attributed to 郭璞; probably Tang or Song in fact): 气乘风则散，界水则止 is the origin of the term 风水 [S113].
- Form School (形势派) works on the physical shape of landscape features, at scales from city siting down to building
  orientation [S117]. Fengshui is a system of terrain-based inference [S118].
- 明堂 is the flat ground where 气 gathers, with the 穴 at its centre; a meandering river runs through it, and in front lie the
  案山 and 朝山 [S116]. 明堂宽大为有福，水口收藏积万金 [S116].
- A GIS study of Ming and Qing imperial tombs reduced the siting ideas (龙, 砂, 水, 穴, 向) to eight indicators from DEM, river
  network and remote sensing. Elevation, surface roughness, aspect, distance to the river network and the water mouth (水口)
  controlled siting [S114]. A Wudang temple study reads fengshui as early environmental science (geomorphology, hydrology,
  climatology) [S115]. A Tibetan settlement study describes the ideal "山–林–屋–水–林" pattern and 藏风得水 [S120].
- Geomorphology of a bend: the outer (concave) bank flows fast and erodes, and the inner (convex) bank flows slowly and
  deposits [S119]. This is why 玉带 / 金城环抱 (water curving round the site, site on the inner bank) is safe and 反弓 (outer bank)
  is not.

**Classical terms (unverified — from memory).** 《葬书》 also says 夫葬以左为青龙，右为白虎，前为朱雀，后为玄武；玄武垂头，
朱雀翔舞，青龙蜿蜒，白虎驯俯 and 风水之法，得水为上，藏风次之. The dragon hierarchy runs 祖山 (ancestral range) → 少祖山 →
父母山 → 束气/过峡 (a narrow neck) → 穴. 案山 should be close and low (folk rule: 高不过眉，低不过心 at the standing site), and
朝山 farther and higher. 水口 should be closed off (关锁) by hills, ideally with 罗星, 华表 or 捍门 hillocks in the gap. 穴 forms
are 窝, 钳, 乳, 突. Folk saying: 宁可青龙高万丈，不可白虎抬头望. 《地理五诀》 names 龙, 穴, 砂, 水, 向.

**Scoring a candidate site p on the heightfield (proposed; thresholds are tunable starting values, not sourced).**
Let `φ` be the facing azimuth (clockwise from north; default the local downslope aspect, preferring south). Sectors are
relative to `φ`: front `φ ± 45°`; back `φ + 180° ± 45°`; left (青龙) `φ − 90° ± 45°`; right (白虎) `φ + 90° ± 45°`. Facing
south, left is east and right is west. `R` is the site radius (the hall footprint, about 150–400 丈 for a sect).
| element | criterion (soft thresholds via smoothstep) |
|---|---|
| **向** aspect | `φ` within ±30° of south (full score), ±60° (half) |
| **穴** platform | slope 2–10° over radius 0.3R; plan curvature concave or flat (a nest, 窝), not a crest or a channel; above the river by 5–30 m (2–10 丈), not more than ~100 m |
| **玄武** back | max height in the back sector at 0.5R–4R is ≥ 60–200 m (20–60 丈) above p and is the highest of the four sectors; **垂头**: the spur between them descends toward p (unit downslope vector of the spur · direction to p > 0.7), with slopes 15–35° (not a cliff) |
| **龙脉** incoming dragon | follow the ridge uphill from the back mountain. It should stay on a continuous divide for ≥ 10R (≥ 5–20 km at sect scale), climb through ≥ 2 intermediate summits (父母山, 少祖山) to a regional maximum (祖山), with ≥ 3 rise–fall cycles (起伏), ridge sinuosity 1.1–1.5 (蜿蜒), and a saddle narrower than 0.5 × the mean ridge width within 1–3R behind p (束气/过峡) |
| **青龙 / 白虎** flanks | each lateral sector has a ridge ≥ 0.2–0.5 × the back height above p; both ridges reach forward at least abreast of p (forward offset ≥ 0) and curve inward (环抱); left ≥ right; both lower than 玄武 |
| **明堂** | in the front sector within 0.5–3R, ≥ 50 % of cells have slope < 5°, lying 2–30 m below p; inner 明堂 small and enclosed, outer 明堂 larger |
| **案山 / 朝山** | 案山: a low hill in the front sector at 2–6R whose top subtends 0–5° from p; 朝山: higher hills at 10–40R in front subtending 2–10° |
| **水** 玉带 | a channel (drainage area > stream threshold) crosses the front sector between p and 案山 at 0.5–3R, roughly perpendicular to `φ`, with p on its convex inner bank (the channel's centre of curvature on p's side). Penalise outer-bank (反弓) sites and channels aimed straight at p |
| **来水 / 去水** | the upstream inflow is visible from p, the downstream exit is not (line of sight blocked by a flank ridge) |
| **水口** | the basin outlet is narrow: valley width at the outlet ÷ mean 明堂 width ≤ 0.3, closed off by hills; a hillock or islet in the gap is a bonus |
| **藏风** enclosure | horizon angle α(θ) out to ~5 km: ≥ 75 % of azimuths have α ≥ 5°; back and flanks α ≥ 10°; the front opening ≤ 90° wide with α 2–8° (open view); winter-wind sector (N–NW in China) fully blocked |

Total score: a weighted sum, for example 0.20 玄武 + 0.15 龙脉 + 0.15 (青龙+白虎) + 0.15 水 + 0.10 明堂 + 0.10 藏风 + 0.05 水口 +
0.05 案朝 + 0.05 向, each term in [0,1]. The repo already does 背山面水 for city hills (§1.4 step 12), and its sect masses sit at
negative `v` (north, since +z is south) behind the halls. That looks like a 玄武-behind layout already, so the scorer can
check existing sites as well as choose new ones.

---

# Part 3 · Reality check against the current `NAT_STYLES`

| repo value | in metres | real analogue | comment |
|---|---|---|---|
| karst `towerField` h 70–210 丈 | 233–700 m | Guilin plain towers 30–80 m, up to 300 m at the fengcong edge [S3, S4] | repo towers are 3–8 × taller than the plain towers; for realism use h ≈ 10–90 丈 with the tallest near the uplands |
| karst `towerField` r 38–84 丈 | 127–280 m radius | 45° cones have base radius ≈ relief (derived) | h/r of 1.8–2.5 suits steep fenglin towers (75° walls) rather than 45° cones |
| `pillars` Worley cell 118 丈, keep 0.56 | 393 m cells, ~525 m effective | Wulingyuan ≈ 170–300 m pillar spacing (derived, area uncertain) | sparser than real by about 2–3 ×; joint-set cutting would add the straight "streets" |
| `pillars` height above floor | ~75–120+ 丈 = 250–400 m | 1,000+ pillars over 200 m, walls up to 350 m [S34, S39] | consistent |
| `granite` needles h 26–84 丈 | 87–280 m | Sanqingshan Python pillar 120–128 m [S45] | consistent |
| `volcanic` bench step 17 丈 | 57 m | flood-basalt composite steps 50–70 m; single lobes 8–17 m [S55, S56] | consistent with composite steps |
| `loess` bench step 7 丈 | 23 m | loess terraced fields and slump benches (unverified — from memory) | plausible |
| loess gullies d 66–108 丈 | 220–360 m | Dongzhi loess > 200 m thick [S59] | deeper than the loess; fine only if they cut into bedrock |
| granite `snowLine` 690 丈 | 2,300 m | Taibai LGM snowline 3,250–3,300 m; no Qinling glaciers today [S75] | stylised cold; key the cirque operator to it |
| sect `cloud` 472–482 丈 | 1,573–1,607 m | Huangshan cloud-top class "< 1,600 m" [S43] | matches |
| relief p97 540 丈 / cap 950 丈 | 1,800 / 3,165 m | Huangshan main peaks > 1,800 m [S42] | real-scale |

---

# Part 4 · Generator parameters

Heights are relative to the local base (valley floor or plain) unless marked "elev". 丈 values are rounded (1 m ≈ 0.3 丈).
"Grid" says what resolves on a 40-丈 (G40) or 15-丈 (G15) grid. Tags: [S#] sourced, (d) derived or proposed from sourced numbers, (m) unverified — from memory.

| landform | relative height | diameter / width / spacing | wall / slope angle | profile hints | base-level relation | grid |
|---|---|---|---|---|---|---|
| Young fold ridge (anticline) | ~1,200 m ridge–valley relief, Zagros (360 丈) [S80] | lengths often > 100 km [S80]; wavelength 10–20 km (m) | flanks ≈ bed dip | anticline = ridge, syncline = valley; inverts with age [S80] | trellis on weak beds [S79] | G40 |
| Ejective fold belt (川东) | 500–1,000 m (m) | narrow ridges, spacing 20–40 km (m) | steep chevron cores [S81] | narrow tight anticlines, broad box synclines [S81] | strike valleys | G40 |
| Cuesta / homocline / hogback | set by cap-bed thickness | spacing = bed-pair thickness ÷ sin(dip) (m) | dip slope = dip: cuesta < 20°, hogback > 30–45° [S78]; scarp 25–60° (m) | asymmetric, one-sided | trellis, water gaps [S79] | G40 |
| Fault-block range front | uplift step; Huashan block uplift 0.02–0.19 mm/a [S47] | range spacing 20–40 km (6,000–12,000 丈) [S82]; segments 5–20 km [S82] | free face 60–90° (m) → 30–35° repose [S83] | diffusion `erf` profile, κ 1–6 m²/kyr [S83]; Smf ≈ 1 active [S82] | fans at every outlet | G40 |
| Alluvial fan | apex at canyon mouth | A_fan ∝ A_basin^n, n < 1 [S84] | ≥ 0.4° for large basins [S84]; 1–6°, debris fans to 15° (m) | cone sector, concave radial profile (m) | spreads onto the plain | G40 |
| V-valley | — | — | — | `z ∝ |y|^b`, b ≈ 1.0–1.3 [S70] | to base level | G40 |
| Meandering channel | — | λ = 7–12 w [S85]; Rc = 2–3 w [S85] | — | sinusoid-like with skew | floodplain | G15 for w > 50 m |
| River terraces | 105–200 m for 1.6 Ma at Lanzhou (30–60 丈) [S87] | ≥ 8 levels [S87] | risers steep (m) | flat treads, steep risers | older base levels | G40 |
| Waterfall | 76 m Danxia [S28]; 190–197 m rhyolite [S50] | Shizhangdong 80 m wide [S28] | vertical | caprock over weak rock [S89] | knickpoint; retreat ≤ 1.5 m/yr [S89] | G15 |
| U-valley (glacial trough) | FR = D/W large when overdeepened [S71] | — | — | `z ∝ |y|^b`, b ≈ 1.5–2.0 [S70, S71] | hanging tributaries (m) | G40 |
| Cirque | headwall 30–60°+ (m) | 0.3–2 km (90–600 丈) (m) | floor tilted back 5–20° (m) | bowl + tarn [S74] | just above the ELA; poleward aspect [S72, S73] | G40 |
| ELA reference | Taibai LGM 3,250–3,300 m elev (980 丈) [S75] | — | — | — | glacial operators above it | — |
| 峰丛 fengcong | 100–300 m, > 500 m locally (30–90, > 150 丈) [S3] | depressions ≈ 2.5 /km², spacing ≈ 630 m (190 丈) (d); depression ≈ 420 m across (d) [S5]; cone base 200–600 m (d) | cones 45–47° [S3] | linear cone flanks (`p ≈ 1, q ≈ 1` in `(1 − t^p)^q`); Voronoi sinks (m) | well above the water table [S2]; internal drainage | G40 |
| 峰林 fenglin | 30–80 m, up to 300 m near fengcong (9–24, ≤ 90 丈) [S3, S4] | isolated on a plain | mean 75° [S3] | steep `(1 − t^p)^q`, p ≈ 4–8, q ≈ 0.3–0.6 (d) + base notch (m) | towers on an alluviated plain at the water table [S2, S3] | G15 |
| 天坑 tiankeng | ≥ 100 m deep; Xiaozhai 511–662 m (153–199 丈) [S7, S9] | ≥ 100 m wide; 626 × 537 m [S9] | vertical | diameter/depth 0.5–2.0 [S7] | on an underground river [S7, S8] | G15 |
| Natural bridge | 223–281 m total; 96 m clearance (Tianlong) [S11] | opening 28–34 m; deck 150 m thick, 147 m long [S11] | vertical | roof remnant between two collapses | underground river | G15 / mesh |
| 石林 stone forest | 20–30 m, ≤ 40 m (6–12 丈) [S17] | dense pinnacle fields | vertical, sharp karren [S14] | exhumed subsoil karren [S15] | under a stripped cover | mesh |
| Travertine terraces | Huanglong ≈ 600 m drop over 3.6 km [S18] | 3,300–3,400 pools [S18] | mean ≈ 9–10° (d) | stepped rimstone dams across the flow [S19] | spring-fed valley | shader + G15 steps |
| Danxia mesa / peak | pillars ≈ 300 m (Jianglangshan, 90 丈) [S29] | slot canyons < 1–100 m wide, 5 km long [S30] | cliffs near-vertical (m); talus 25–35° (m) | 顶平身陡麓缓 three-part profile (m) | stage by HI: > 0.6 young, 0.4–0.6 mature, < 0.4 old [S24] | G15 |
| Zhangye coloured hills | low rounded hills [S32] | dense rills (m) | gentle; no cliffs [S32] | convex badland ridges | arid surface | G15 + shader |
| Zhangjiajie peak forest | tens of m to 400 m; > 1,000 over 200 m; walls ≤ 350 m [S34, S39] | spacing 170–300 m (50–90 丈) (d); widths 10–50 m (m) | vertical walls | concordant flat tops (top erosion 2.5 vs 83–122 mm/kyr at the base) [S34] | channels to base level along NNW/ENE/NE joints [S34, S37] | G15 (pillars ≥ 50 m) |
| Granite spires (Huangshan, Sanqingshan) | Sanqingshan pillar 120–128 m (36–38 丈) [S45]; summits > 1,800 m elev [S42] | 48 peaks + 89 pillars in one park [S44] | 60–90° on joints (m) | joint slots + convex caps | rectangular drainage (m) | G15 |
| Exfoliation dome | — | — | convex everywhere (90 % convex) [S48] | `h = H(1 − (r/R)²)^0.5..1` (m); sheets ~5.6 cm/ka [S48] | radial drainage (m) | G40 |
| Stratovolcano | H/W_B > 0.10, mean slope > 12° [S54] | Changbai summit 2,749 m elev [S52] | upper cone 30–35° (m) | lower half logarithmic, upper straight or concave [S53] | radial drainage (m) | G40 |
| Caldera lake | Changbai caldera 850 m deep (255 丈); lake ≤ 373–384 m deep [S51, S52] | caldera 5 km (1,500 丈); lake 4.85 × 3.35 km [S51, S52] | steep inner walls (m) | flat-floored pit + lake to an outlet notch | lake at 2,189 m elev [S51] | G40 |
| Basalt plateau / traps | flows 8–17 m modal (2.5–5 丈); steps 50–70 m (15–21 丈) [S55, S56] | plateau-scale | cliff on flow base, slope on flow top [S56] | `terraceH` stairs | mesa edges | G15 |
| Columnar joints | columns ≤ 12 m tall [S58] | sides 20–46 cm [S58] | vertical | hexagonal; size ∝ 1/cooling rate [S57] | — | shader |
| Rhyolite walls (Yandang) | falls 190–197 m [S50]; peaks ≈ 1,056–1,150 m elev [S49] | — | vertical joints (m) | stacked walls 叠嶂 (m) | resurgent caldera [S49] | G15 |
| 塬 loess tableland | loess > 200 m thick (60 丈) [S59] | ≈ 900 km² (Dongzhi) [S59] | top < 3–5° (m); rims 35–90° (m) | flat top, sharp rim | gully heads retreat 0.5–6.6 m/yr [S59] | G40 |
| 梁 / 峁 loess | gully depths 50–200 m (m) | gully density 3–11 km/km², up to 20–30 [S60–S63]; gully spacing ≈ 1/D ≈ 100–330 m (d) | sides 15–35° (m); walls to vertical [S68] | convex ridges / domes (m) | 塬 → 梁 → 峁 with erosion [S64, S65] | G15 + shader |
| Shore platform | at sea level | Type B 80–270 m wide (24–81 丈) [S90] | 0.2–1.3° [S90] | flat bench + seaward scarp (Type B) [S90] | sea level | G15 |
| Tombolo | low sand bar | forms when L/D > ~1 [S91] | — | bar from shore to island | sea level | G15 |
| Island arc | cones | spacing 30–100 km (9,000–30,000 丈) [S92] | — | curved line of cones (m) | — | G40 |
| Atoll | rim islets a few m (m) | ~1 to > 50 km across (m) | — | ring reef, lagoon 20–80 m deep (m) | sea level | G40 |
| Cloud sea | top at the inversion; Huangshan classes < 800 / < 1,600 / 1,600–1,800 m [S43] | one level per basin (d) | — | flat top with undulation [S94] | fills basins; Nov–May, after rain [S43]; ~200–260 fog days [S42] | volume |

---

# Sources

All were read through search-engine extracts only (see §0). "Low authority" marks travel or popular sites.

**Karst**
- [S1] IUCN evaluation 2007, South China Karst phase I — https://whc.unesco.org/document/152163
- [S2] UNESCO/IUCN evaluation 2014, South China Karst phase II (water-table statement) — https://whc.unesco.org/document/152165
- [S3] T. Waltham, "Fengcong, fenglin, cone karst and tower karst" — https://digitalcommons.usf.edu/kip_articles/4802/ ; https://www.researchgate.net/publication/279573535_Fengcong_fenglin_cone_karst_and_tower_karst
- [S4] Li River (Wikipedia) — https://en.wikipedia.org/wiki/Li_River
- [S5] Saddle-position depression extraction in fengcong, ISPRS IJGI 7(4):136 (2018) — https://doaj.org/article/4fad7578993c4f6d825904fd9f62f824
- [S6] Huang, Deng & Day 2014, Env. Earth Sci. 72:407–416 — https://www.researchgate.net/publication/278086063
- [S7] Gunn et al. 2019, Cave and Karst Science 46(2), tiankeng definition — https://www.bcra.org.uk/cks137
- [S8] Sixth Tone, quoting Zhu Xuewen — https://www.sixthtone.com/news/1014201
- [S9] Xiaozhai Tiankeng (Wikipedia) — https://en.wikipedia.org/wiki/Xiaozhai_Tiankeng
- [S10] detik.com sinkhole list (low authority) — https://inet.detik.com/fotoinet/d-6629844/deretan-sinkhole-terbesar-di-dunia-takjub-sekaligus-ngeri
- [S11] Three Natural Bridges (Wikipedia) — https://en.wikipedia.org/wiki/Three_Natural_Bridges ; showcaves.com — https://showcaves.com/english/cn/karst/Sanqiao.html
- [S12] Gams polje definition (Acta Carsologica) — https://ojs.zrc-sazu.si/carsologica/article/download/341/330/672 ; NP Sjeverni Velebit — https://www.np-sjeverni-velebit.hr/www/en/nature-and-cultural-heritage/inanimate-nature/geomorfology
- [S13] LiDAR doline morphometry, Remote Sensing 16(5):737 (2024) — https://www.mdpi.com/2072-4292/16/5/737
- [S14] IUGS Geoheritage, Shilin Karst — https://iugs-geoheritage.org/geoheritage_sites/shilin-karst/
- [S15] Knez, Slabe & Liu 2012, Acta Carsologica — https://ojs.zrc-sazu.si/carsologica/article/view/558
- [S16] Šebela & Liu, Acta Carsologica — https://ojs.zrc-sazu.si/carsologica/article/view/572
- [S17] Stone Forest (Wikipedia) and travel guides (heights, low authority) — https://en.wikipedia.org/wiki/Stone_Forest
- [S18] Huanglong WCMC sheet — https://thesalmons.org/lynn/wh-wcmc/China%20-%20Huanglong.pdf ; https://www.worldheritagesite.org/list/id/638 ; https://goasia.cc/en/article/huanglong-scenic-area (low authority)
- [S19] Lugli et al. 2017, J. Sedimentary Research (Jiuzhaigou) — https://iris.unimore.it/handle/11380/1129521

**Danxia**
- [S20] IAG Red Beds and Danxia Geomorphology Working Group — https://www.geomorph.org/danxia-geomorphology-working-group/
- [S21] Peng, Ren & Pan, "A review of Danxia landforms in China" — https://www.schweizerbart.de//papers/zfg_suppl/detail/59/84659/A_review_of_Danxia_landforms_in_China
- [S22] China Danxia: UNESCO 1335, IUCN Outlook, WII summary — https://whc.unesco.org/en/list/1335 ; https://worldheritageoutlook.iucn.org/node/1162 ; https://c2c.wii.gov.in/china-danxia
- [S23] Bournemouth University news 2009 — https://assets.bournemouth.ac.uk/news-archive/conservation/newsandevents/NewsJun09/news_170609.html
- [S24] Qiaoba–Zhongdu Danxia stage study (HI), Open Geosciences — https://www.degruyterbrill.com/document/doi/10.1515/geo-2022-0709/html
- [S25] Danxiashan, Int. J. Geoheritage and Parks 2022 — https://doaj.org/article/a3aad2acafd74649bc50d87bd95a9076 ; GGN — https://www.globalgeopark.org/GeoparkMap/geoparks/China/12499.htm
- [S26] Danxia morphogenesis experiments, J. Geogr. Sci. 25(8):943–966 (2015) — https://experts.umn.edu/en/publications/experimental-studies-on-the-danxia-landscape-morphogenesis-in-mt-/
- [S27] Mudstone/sandstone weathering, AMNS 2024 — https://doaj.org/article/9ea20d9831da4507a7c1b6fcda5d4d5b
- [S28] Guizhou government, Shizhangdong — https://www.eguizhou.gov.cn/2018-12/04/c_368392.htm
- [S29] Zhejiang Culture & Tourism, Jianglangshan — https://ct.zj.gov.cn/art/2019/8/5/art_1664685_36385572.html ; Mount Langshan (Wikipedia) — https://en.wikipedia.org/wiki/Mount_Langshan
- [S30] China Daily Fujian, Taining canyon — https://regional.chinadaily.com.cn/fujian/2022-03/03/c_721540.htm
- [S31] Wuyishan paper on a UNESCO-hosted site — https://www.unesco-hist.org/uploads/files/lunwenjizhaiyao/16_Fu%20BH_Unique%20Landscape%20and%20Eco-system%20of%20%20Rock%20Tea%20in%20the%20Wuyi%20Mountain.pdf
- [S32] UNESCO tentative list 6841 (Zhangye) — https://whc.unesco.org/en/tentativelists/6841 ; ExplorersWeb — https://explorersweb.com/2021/02/16/natural-wonders-chinas-zhangye-danxia/
- [S33] Zhangye palaeosol study (Macquarie) — https://researchers.mq.edu.au/en/publications/paleosol-characteristics-of-zhangye-cretaceous-colourful-danxia-a/

**Wulingyuan**
- [S34] May et al. 2018, ESPL 43:639–653 — https://ro.uow.edu.au/smhpapers/5124 ; https://apo.ansto.gov.au/dspace/handle/10238/12499
- [S35] Wulingyuan UNESCO 640, IUCN 1992 evaluation, IUCN Outlook — https://whc.unesco.org/en/list/640 ; https://worldheritageoutlook.iucn.org/node/1057
- [S36] Pursuit (University of Melbourne) — https://pursuit.unimelb.edu.au/articles/creating-pandora-on-earth
- [S37] Yang et al. 2012, Env. Earth Sci. — https://ro.uow.edu.au/scipapers/4772
- [S38] EGU2013-13358 — https://meetingorganizer.copernicus.org/EGU2013/EGU2013-13358.pdf
- [S39] University of Sydney ecotourism page — https://ecotourism-arts.sydney.edu.au/china/china-3.html ; evolution sequence (low authority) — https://lxs.cncn.com/18208/n792230 ; Xinhua — https://www.news.cn/photo/20250227/fc6914b1686a467abbe7f56904946883/c.html
- [S40] Zhangjiajie planation surfaces, Geoscience 2011 — https://www.geoscience.net.cn/CN/Y2011/V25/I4/789

**Granite**
- [S41] Huangshan batholith age — https://digitalcommons.unl.edu/geosciencefacpub/97 ; https://goldschmidtabstracts.info/2024/21446.pdf
- [S42] Huangshan climate and peaks (travel, low authority) — https://welcometochina.com.au/mount-huangshan-anhui-chinas-most-beautiful-mountain-travel-guide-6722.html ; https://en.wikivoyage.org/wiki/Huangshan ; https://www.chinavigators.com/huangshan-travel-guide/
- [S43] Huangshan cloud-top viewing guide (low authority) — https://lxs.cncn.com/78108/n394112 ; https://studycli.org/zh-CN/travel-china/yellow-mountain-travel-guide/
- [S44] Sanqingshan, IUCN — https://worldheritageoutlook.iucn.org/node/1152 ; https://iucn.org/sites/default/files/import/downloads/china__mount_sanqingshan_national_park__fact_sheet.pdf
- [S45] Sanqingshan Python pillar and Yujing Peak — https://www.travelchina.org.cn/en/article/TZCs9Ilhm2eA ; https://www.chinaxiantour.com/jiangxi-tours/2-days-sanqing-mountain-hiking-tour
- [S46] Weihe Graben faults — https://research.vu.nl/en/publications/seismic-assessment-of-the-weihe-graben-central-china-insights-fro ; Huashan Piedmont Fault — https://www.dzdz.ac.cn/EN/Y2017/V39/I3/587
- [S47] Huashan apatite fission track — https://www.dzdz.ac.cn/EN/Y2000/V22/I1/53
- [S48] Sheeting joints: Physics Today — https://physicstoday.aip.org/news/explaining-sheeting-joints-on-yosemites-half-dome ; Mitchell 2010 — https://www.soest.hawaii.edu/GG/academics/theses/MS_2010_Mitchell.pdf ; Korean dome — https://researchmap.jp/7000001010/published_papers/12483200 ; GSA 2025 — https://gsameetings.secure-platform.com/connects25/solicitations/103002/sessiongallery/schedule/items/95303/application/7566

**Volcanic**
- [S49] UNESCO Global Geopark nominations (Yandangshan) — https://unesdoc.unesco.org/ark:/48223/pf0000397215 ; https://engeopark.wzyds.com/GeoparkBackground/index.jhtml ; https://en.wikipedia.org/wiki/Yandang_Mountains
- [S50] Dalongqiu — https://www.buddhiststamp.com/stamps/5fb382ceb1d1ae7a16736247 ; https://www.frommers.com/destinations/yandangshan/things-to-do/
- [S51] Tianchi — https://livescience.com/planet-earth/geology/heaven-lake-chinas-deepest-lake-sits-atop-a-colossal-volcano-and-belongs-mostly-to-north-korea ; https://www.wikipedia.com/wiki/Chon_Lake ; https://www.theworldofchinese.com/2022/01/the-sacred-white-mountain-on-the-china-dprk-border/ ; https://volcanolive.com/paekdu.html
- [S52] Changbaishan structure — https://www.earth-prints.org/bitstream/2122/15582/1/Yi%20et%20al%202021%20Geoscience%20Frontiers.pdf ; https://volcano.si.edu/volcano.cfm?vn=305060 ; https://eos.org/research-spotlights/new-details-about-a-very-old-eruption-and-flood
- [S53] Karátson et al. 2010, stratovolcano profiles — https://www.earth-prints.org/handle/2122/6679
- [S54] Grosse & Kervyn 2018, shield morphometry — https://ri.conicet.gov.ar/handle/11336/81219
- [S55] Flood-basalt lobe thickness, Frontiers in Earth Science 2021 — https://www.frontiersin.org/journals/earth-science/articles/10.3389/feart.2020.630604/full
- [S56] NASA, Labrador traps — https://earthobservatory.nasa.gov/blogs/earthmatters/2020/02/28/step-up-close-to-the-labrador-traps/ ; Trap basalt — https://en.Wikipedia.com/wiki/Trap_basalt
- [S57] Goehring & Morris 2008 JGR — https://www.physics.utoronto.ca/nonlinear/abstracts/GM_JGR08abstract.html ; Goehring, Mahadevan & Morris 2009 PNAS — https://pmc.ncbi.nlm.nih.gov/articles/PMC2615021/
- [S58] Giant's Causeway — https://mathshistory.st-andrews.ac.uk/Gaz/Giants_Causeway/ ; https://www.discoveringbritain.org/activities/northern-ireland/1814/britain-from-the-air-giants-causeway.html

**Loess**
- [S59] Dongzhi tableland, Frontiers in Earth Science 2022 — https://www.frontiersin.org/journals/earth-science/articles/10.3389/feart.2022.812609/pdf
- [S60] Gully density by landform, Frontiers of Earth Science 2019 — https://academic.hep.com.cn/fesci/EN/Y2019/V13/I2/410
- [S61] EGU21-3676 — https://meetingorganizer.copernicus.org/EGU21/EGU21-3676.html
- [S62] EGU22-1289 (Chabagou) — https://presentations.copernicus.org/EGU22/EGU22-1289_presentation-h669320.pdf
- [S63] ACRS 1990 — https://a-a-r-s.org/proceeding/ACRS1990/Papers/PS290-4.htm
- [S64] ISPRS IJGI 10(10):693 (2021) — https://www.mdpi.com/2220-9964/10/10/693
- [S65] Geographical Research 39(8) 2020 — https://m.researching.cn/articles/OJa525847dd1130b17
- [S66] Vertical joints and loess slope stability, Sci. Rep. 2023 — https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10017714/
- [S67] Original vertical joints, Earth-Science Reviews 2021 — https://pure.psu.edu/en/publications/the-genesis-development-and-evolution-of-original-vertical-joints/
- [S68] Gully headwall review (KU) — https://kuscholarworks.ku.edu/server/api/core/bitstreams/48d777d3-de98-4a3c-aa07-b576b77f025b/content
- [S69] Liu Yinhan 1985, Acta Geogr. Sinica — https://www.geog.com.cn/EN/abstract/article/0375-5444/20257 ; Loess Plateau landform dataset, Sci. Data 2024 — https://doaj.org/article/9ef87dffb12349939157e4a2d988aba8

**Glacial**
- [S70] Valley cross-section shape, Southern Alps, Nature Communications 6:8028 (2015) — https://www.nature.com/articles/ncomms9028
- [S71] Coles 2014 thesis — https://etheses.whiterose.ac.uk/5452/1/Coles_2014.pdf ; valley cross-section evolution (Svensson lineage) — https://arxiv.org/pdf/0901.1177
- [S72] Cirques in the Transantarctic Mountains, Geomorphology 2023 — https://e-space.mmu.ac.uk/632996/
- [S73] Barr & Spagnolo 2013, Kamchatka cirques — https://people.wou.edu/~taylors/g322/barr_2013_cirques_morphometric_kamchatka.pdf ; Eastern Black Sea Mountains cirques — https://openaccess.mku.edu.tr/items/eb35394f-3884-478f-a02e-4b77169f750f/full
- [S74] Ankara University lecture notes — https://acikders.ankara.edu.tr/mod/resource/view.php?id=175889
- [S75] Rost 1993, Erdkunde (Taibai Shan) — https://www.erdkunde.uni-bonn.de/article/view/2279 ; Tian & Huang 1990 — https://www.dlyj.ac.cn/EN/abstract/article/1000-0585/10614
- [S76] Kuhle 1988 (Tibet, Qilian) — https://www.uni-goettingen.de/de/document/download/1af320da2cfdde1b0b76d37a0a7e5cf5.pdf/
- [S77] ELA dataset, Second Chinese Glacier Inventory — https://geodoi.ac.cn/edoi.aspx?Id=948

**Structure and rivers**
- [S78] Hogback (Wikipedia) — https://en.wikipedia.org/wiki/Hogback_(geology) ; Homocline — https://en.wikipedia.org/wiki/Homocline ; MIT — https://web.mit.edu/oeit/pgt/index-part=6.3.0.html ; WB notes — https://wbsche.wb.gov.in/assets/pdf/geography/drainage-development-on-uniclinal-and-folded-structure.pdf
- [S79] Earth@Home — https://earthathome.org/topography-ib/ ; Radford University — https://sites.radford.edu/~jtso/GeologyofVirginia/Weathering/GeologyOfVAWeathering5-3c.html ; Korea University — https://scholar.korea.ac.kr/handle/2021.sw.korea/141940
- [S80] Zagros syncline inversion, Arab. J. Geosci. — https://link.springer.com/10.1007/s12517-017-3163-1 ; NASA SRTM Zagros — https://www.jpl.nasa.gov/images/pia04956-zagros-mountains-iran-srtm-shaded-relief/ ; GSA 2007 — https://gsa.confex.com/gsa/2007AM/webprogram/Paper126097.html ; the "> 100 km whalebacks" line came from the same Zagros search (page not pinned)
- [S81] Eastern Sichuan fold belt — https://meetingorganizer.copernicus.org/EGU2015/EGU2015-2735.pdf ; https://www.frontiersin.org/journals/earth-science/articles/10.3389/feart.2022.897882/full ; https://ogg.pepris.com/en/article/doi/10.11743/ogg20200512/
- [S82] Basin and Range spacing, GSA 2002 — https://gsa.confex.com/gsa/2002AM/webprogram/Paper45615.html ; Smf — https://www.balkangeophysoc.gr/online-journal/1999_V2/may1999/v-2-2-2.pdf ; NMGS — https://nmgs.nmt.edu/publications/guidebooks/details.cfml?ID=12113 ; https://geology.teacherfriendlyguide.org/index.php/topography-w/topography-region1-w
- [S83] Scarp degradation — https://meetings.copernicus.org/www.cosis.net/abstracts/EGU2008/05060/EGU2008-A-05060.pdf ; Andrews & Hanks 1985 — https://pubs.usgs.gov/publication/70012346 ; https://umimpact.umt.edu/en/publications/a-mass-failure-model-for-the-initial-degradation-of-fault-scarps-/
- [S84] Alluvial fans — https://thesis.caltech.edu/1396/ ; https://www2.jpgu.org/meeting/2010_disc1/program/PDF/H-TT032/HTT032-P02_e.pdf ; https://opac.geologie.ac.at/ais312/dokumente/EGU/EGU2015-12233.pdf
- [S85] Leopold & Wolman 1957, USGS PP 282-B — https://pubs.usgs.gov/publication/pp282B ; "River meanders" 1960 — https://pubs.usgs.gov/publication/70185557 ; lecture summary — https://uomustansiriyah.edu.iq/media/lectures/5/5_2019_11_03!11_27_27_AM.pdf
- [S86] Delta classification — https://geo.libretexts.org/Bookshelves/Oceanography/Coastal_Dynamics_(Bosboom_and_Stive)/02%3A_Large-scale_geographical_variation_of_coasts/2.07%3A_Process-based_classification/2.7.3%3A_Classification_of_deltas ; https://coastalwiki.org/wiki/Wave-dominated_river_deltas
- [S87] Yellow River terraces — https://research.vu.nl/en/publications/differential-tectonic-movements-in-the-confluence-area-of-the-hua/ ; https://www.dzdz.ac.cn/EN/Y2003/V25/I1/133 ; https://ites.unistra.fr/websites/eost/ites/Pages_Perso/Jeromevdw/publications/Perrineauetal_GSLsp_2011-FleuveJaune.pdf ; Weihe strath terraces — https://resolve-he.cambridge.org/core/journals/quaternary-research/article/climatic-and-tectonic-controls-on-strath-terraces-along-the-upper-weihe-river-in-central-china/53B8A4EED34DD2990E07331DCFB7B2EE
- [S88] Three Gorges — https://en.wikipedia.org/wiki/Three_Gorges ; https://en.wikipedia.org/wiki/Xiling_Gorge ; https://www.chinatravel.com/yichang/attraction/qutang-groge ; https://www.imperialtours.net/three-gorges-of-the-yangzi-river/
- [S89] Waterfall (Wikipedia) — https://www.wikipedia.org/wiki/Waterfall ; Niagara recession (Tsukuba) — https://tsukuba.repo.nii.ac.jp/record/21252/files/EG_116-1.pdf

**Coasts**
- [S90] Shore platforms — https://pmc.ncbi.nlm.nih.gov/articles/PMC4754505 ; https://researchspace.auckland.ac.nz/handle/2292/19986 ; https://meetingorganizer.copernicus.org/EGU2012/EGU2012-10687.pdf ; https://esurf.copernicus.org/preprints/esurf-2016-42/esurf-2016-42-AC3.pdf
- [S91] Tombolos — https://journals.flvc.org/jcr/article/view/80236 ; https://www.matec-conferences.org/10.1051/matecconf/201820301007/pdf ; https://www.mdpi.com/2073-4441/14/13/2016 ; https://www.mdpi.com/2077-1312/13/11/2211
- [S92] Arc volcano spacing — https://www.gi.alaska.edu/alaska-science-forum/volcano-spacing ; https://booksite.elsevier.com/9780126431407/netscape4/Contents/Chapt43_02.htm ; https://nora.nerc.ac.uk/id/eprint/154964/ ; https://pages.mtu.edu/~raman/papers2/CentralAmer/CarrRefs/CarretalAGU.pdf
- [S93] Atolls — https://www.wikipedia.org/wiki/Atoll ; Darwin — https://gutenberg.org/files/4022/4022-h/4022-h.htm ; Purdy & Winterer — https://repository.geologyscience.ru/bitstreams/c7491e37-df3c-4dd0-8669-55871250df48/download

**Clouds**
- [S94] Sea of clouds (Wikipedia) — https://en.wikipedia.org/wiki/Sea_of_clouds ; https://www.alpenwild.com/Alpshiking/mountain-clouds-a-sea-of-clouds/
- [S95] Clements, Whiteman & Horel 2003 — https://www.inscc.utah.edu/~whiteman/homepage/articles/Clements2003J%20Appl%20Meteorol.pdf ; Whiteman 2010 — https://home.chpc.utah.edu/~whiteman/homepage/articles/Whiteman2010Journal%20of%20Applied.pdf ; Whiteman 1999 — https://home.chpc.utah.edu/~whiteman/homepage/articles/Whiteman1999J%20Appl%20Meteorol.pdf
- [S96] Orographic cloud, Jiuxian Mountain, Atmosphere 15(2):207 — https://www.mdpi.com/2073-4433/15/2/207
- [S97] Hong Kong Observatory, upslope fog (Emei) — https://www.hko.gov.hk/en/education/weather/visibility/00084-upslope-fog.html
- [S98] Fog in China, Acta Geogr. Sinica — https://www.geog.com.cn/EN/abstract/article/0375-5444/19304

**Painting**
- [S99] Asian Art Museum education — https://education.asianart.org/resources/the-development-of-landscape-painting-in-china-through-the-tang-dynasty-618-906/
- [S100] Way & Shih 2001, "The synthesis of rock textures in Chinese landscape painting" — https://diglib.eg.org/handle/10.2312/8856
- [S101] The Paper, on 皴法 — https://www.thepaper.cn/newsDetail_forward_11364194
- [S102] Sohu, 赵孟頫 皴法 — https://www.sohu.com/a/419358205_717746
- [S103] Taiwan digital archives (NPM catalogue, 倪瓒 折带皴) — https://catalog.digitalarchives.tw/item/00/03/fb/27.html
- [S104] 汉典, 郭熙 — https://www.zdic.net/hans/郭熙
- [S105] HKUST Library, 王蒙 — https://library.hkust.edu.hk/wp-content/uploads/2017/05/1495510125.pdf
- [S106] NetEase, 王蒙 解索 牛毛 — https://www.163.com/dy/article/F3GKGJSC0514PBG0.html
- [S107] Que Hill / Hua Hill (Wikipedia) — https://en.wikipedia.org/wiki/Que_Hill ; https://wikipedia.com/wiki/Hua_Hill
- [S108] The Paper, 范宽 《溪山行旅图》 — https://www.thepaper.cn/newsDetail_forward_2542801
- [S109] Aisthesis (Mimesis), 三远 quote — https://mimesisjournals.com/ojs/index.php/aisthesis/article/download/4221/3320
- [S110] NetEase, 韩拙 六远 — https://m.163.com/dy/article/DOPHCIF80514EGJ4.html
- [S111] The News Lens, 可行可望可游可居 — https://www.thenewslens.com/article/88817
- [S112] Met Museum, Wang Yuanqi — https://www.metmuseum.org/art/collection/search/49186 ; 张舜翔 2010 — https://cart.ntua.edu.tw/uploads/root/成果發表/出版刊物/造形藝術學刊/造形藝術學刊2010/02.張舜翔-王原祁的《雨窗漫筆》與《題畫錄》的理論與實踐.pdf ; 龙脉说 paper — https://search.napstic.cn/literature/periodical/010ysts202405006

**Fengshui**
- [S113] 《葬书》 — https://simplelits.com/books/classical/classical-09018-葬书
- [S114] Ming–Qing imperial tomb siting, AAG 2024 — https://aag.secure-platform.com/aag2024/gallery/rounds/74/details/58380
- [S115] Wudang temples, Land 14(7):1441 (2025) — https://www.mdpi.com/2073-445X/14/7/1441
- [S116] Taichung government document (明堂, 案山, 朝山) — https://rdnet.taichung.gov.tw/media/427858/21020102113.pdf
- [S117] Form School and integrated design (CIB) — https://www.irbnet.de/daten/iconda/CIB14390.pdf
- [S118] R. J. Smith, "Fengshui: The Ways of Wind and Water" — https://video.afe.easia.columbia.edu/wp-content/uploads/2024/01/Fengshui-The-Ways-of-Wind-and-Water-Presentation-PDF.pdf
- [S119] Taiwan geography course notes (凹岸 / 凸岸) — https://www.openclass.chc.edu.tw/years/113/plans/82912/reviews/課程資料.pdf
- [S120] 扎尕那 settlement study, Acta Ecologica Sinica — https://search.napstic.cn/literature/periodical/010stxb201121001
