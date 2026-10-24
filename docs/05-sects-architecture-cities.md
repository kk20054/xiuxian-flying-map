# E · Sects, architecture kit, spirit lights, ornaments, cities (index.html L6836–12115)

Source: `demo/index.html`. All line numbers are from that file. Units are 丈 (world units).
Axes are three.js: +Y up; the kit's "front" is **+Z = south, toward the camera** (L10684 "All prefabs face +z (south, toward the camera)").
`k` = `S.k`, a per-sect scale factor (set in 03, outside this range); most sect dimensions are written `N * k`.
`uMap` (0..1) is the global "map mode" blend: nearly every shader/animation multiplies world y by `(1 - uMap)` and fades alpha by it.

Section map of the range:

| Section | Lines | Content |
|---|---|---|
| 06b | 6836–8428 | SECTS state, colours (SC, SECT_LOOK), `archKit` (L6878–7742), placement helpers, seasons/pack props, spur halls, courtyard, BQY wheel/boat/armillary meshes, puppet v1, moving islands (`buildIsle`), **formation dome shader** (L8287–8347), `buildSects` (L8348), `updateSects` (L8403) |
| 06bb | 8430–8629 | `limb`, puppet v2 (傀儡金刚), 万剑阵 ring mesh, 丹鼎, 药田, 地火炉, lava channel/pool, anvil, weapon rack, quench pool, stone lantern |
| 06bc | 8631–9041 | `SECT_STYLE` (roof line + ornaments per sect), GOLD/HUI palettes, batter, frontStair, swordRail, roundRoof, gableRoof, per-sect halls (剑殿, 剑阙, 剑庐, 藏剑阁, 剑门 / 落云殿, 丹房, 药王阁, 弟子居 / 天工殿, 炉塔, 马头墙, 宗祠), hovering sword + artifact ring meshes |
| 06bd | 9043–9874 | floating islands (`fitIslands` spiral placement, `isleBody`, carpet/green), falls, 浮空阵台 `formPlat`, 浮石阶 `floatSteps`, `archLink`, ring meshes, beam & lava shaders, `buildIsland` by kind, 凌霄剑宫, **v4.0 builders `buildGujian/Luoyun/Baiqiao` (L9559–9786, now unused)**, zones |
| 06be | 9876–9961 | 鸾 statue, pulse rings, nest / mirror islands, 栖鸾台, loess cave mouth |
| 06bf | 9963–10022 | lathe rocks: karst tower, caprock pillar, plume spire |
| 06bg | 10024–10060 | fire cave, ground pool, downhill |
| 06bh | 10062–10422 | v4.4 natural-ground helpers + **古剑门 / 落云宗 / 百巧院 builders (live)** |
| 06bi | 10424–10668 | v4.4 **鸾鸣宗 / 倪航斋 / 水影宗 builders (live)** |
| 06bj | 10670–10875 | `ARCH` prefabs (podium, towerHall, grandHall, courtyard, arcCorridor, roundPlaza, cornerTower, qilin, waterPavilion, moonWall, dress) |
| 06bk | 10878–11069 | `ARCH2` prefabs (garden, siheyuan, yaoyuan, beacon, granary, travertine pools, islet, flyingShip, spiritPillar) |
| 06c | 11071–11136 | spirit-light point sprites (additive) |
| 06d | 11138–11313 | lore: teleport arrays, cave dwellings, spirit fields, hill pagodas, giant sword, 天柱山 floating stones |
| 06e | 11315–12114 | cities 封日城 / 韵州城 |

**Which builders actually run (v4.4):** `buildSects` (L8357) maps all six sects to `build*Natural` (06bh/06bi); the v4.0 `buildGujian/buildLuoyun/buildBaiqiao` (L9559/9624/9705) are defined but never called (grep: only definitions). `isleProps/packSectProps/cliffPines/sectSurface/sectZones` run only `if (!S.land)` (L8364); all six SITE_DEFS have `land` (L1248…L1400), so in v4.4 these do not run either. They are still documented briefly because the parts they use (islands, platforms, halls) are reused.

---

## 1. The architecture kit (`archKit`, L6878–7742)

### 1.1 Geometry back-end and local frame
- Everything is flat-shaded triangles in a `FacetBuf` (class at L4793). `buf.tri(a,b,c,col,wa,wb,wc,up)` (L4799): per-face RGB colour, three **ink weights** (edge-opposite-vertex, 0..1, drawn as ink lines by `facetMaterial` in 04 via a barycentric attribute `B` + weight attribute `K`), `up` = a hint direction to fix winding. `buf.mat` (set by `K.mat(AM.X)`) tags faces with a surface-pattern id plus a horizontal tangent (L4813–4818).
- Surface pattern ids `AM` (L6876): `LATTICE 1, TILE 2, PAVE 3, ASHLAR 4, BEAM 5 (painted beams 彩画), PLASTER 6, SLIT 7 (直棂窗), METAL 8 (cast bronze panels), STUD 9 (门钉 studded doors)`. These are procedural patterns in the facet fragment shader (04, `archPattern`) — in Blender they become **material slots / texture sets** (see §5).
- Local frame (L6879–6889): `K.frame(x, z, yaw)` sets an origin and yaw; every point is transformed `x' = ox + dx·cos(yaw) − dz·sin(yaw)`, `z' = oz + dx·sin(yaw) + dz·cos(yaw)`; `K.reset()` clears it. **This equals three.js / Godot `rotation.y = −yaw`** (Ry(θ): x' = x cosθ + z sinθ). Most builders do `K.frame(x, z, yaw)` then draw in axis-aligned coordinates around (x, z).
- Occupancy: `K.taken(x,z,r)` records discs (world space) in `K.occ`; `K.free(x,z,r)` tests them (L6889–6891). `K.gaps` = openings where bridges arrive (terrace rails skip them, L7804). Godot: not needed at runtime; use as a placement rule in the editor tool.
- `K.L` = the colour "look" (SECT_LOOK / CITY_LOOK / VILLAGE_LOOK); `K.q` = 1 lofted curved roofs (sects), 0 flat-faceted (cities, villages) (L6968–6971); `K.style` = SECT_STYLE row (ornaments); `K.season` = SEASON row (asset-pack picks).

### 1.2 Colour looks
`SC` shared (L6843): white `[.9,.89,.84]`, stoneDark `[.46,.47,.46]`, ink `[.22,.24,.26]`, wood `[.45,.33,.25]`, bronze `[.42,.48,.40]`, bronzeLit `[.55,.6,.48]`, steel `[.8,.86,.9]`, pool `[.55,.78,.76]`.
`SECT_LOOK` (L6848–6870), slots `roof roofLit ridge wall wallSide pillar lattice bracket wood stone stoneSide floor trim glow lamp rail` + `tree` index:

| look (sect) | roof | ridge | wall | pillar | stone | trim | glow (lights) | lamp |
|---|---|---|---|---|---|---|---|---|
| ice (古剑门) | .78,.62,.34 gold | .94,.86,.60 | .92,.92,.90 | .20,.20,.22 black lacquer | .80,.81,.81 | .90,.78,.46 | 1.0,.94,.78 | 1.0,.95,.84 |
| jade (落云宗) | .24,.50,.46 green-glaze | .74,.86,.80 | .92,.92,.88 | .56,.23,.17 vermilion | .87,.89,.86 | .80,.90,.84 | .50,1.0,.78 | .90,1.0,.84 |
| gold (百巧院) | .34,.33,.33 iron tile | .86,.70,.40 gold | .88,.84,.76 | .56,.24,.17 | .66,.63,.59 basalt | .90,.76,.46 | 1.0,.72,.38 | 1.0,.84,.56 |
| phoenix (鸾鸣宗) | .45,.48,.52 grey-silver | .90,.86,.78 | .95,.93,.90 | .34,.32,.34 | .93,.93,.90 white jade | .93,.77,.57 rose gold | 1.0,.70,.62 | 1.0,.84,.74 |
| earth (倪航斋) | .36,.39,.42 blue-grey | .70,.68,.60 | .88,.82,.68 loess | .32,.27,.22 | .84,.82,.76 | .52,.56,.46 old bronze | 1.0,.86,.56 | 1.0,.90,.66 |
| water (水影宗) | .30,.31,.32 charcoal | .84,.85,.84 | .95,.94,.90 | .15,.14,.14 black | .80,.81,.78 | .86,.88,.88 silver | .55,.86,1.0 | .90,.95,1.0 |

Extra palettes: `GOLD` (L8661: gilt .82,.63,.30; giltD; tile .86,.68,.32; ridge; iron .30,.28,.27; fire 1,.56,.22; bronze .52,.38,.24), `HUI` (L8662: Huizhou white walls .93,.92,.88, cap .24,.25,.27, tile .32,.33,.35, brick .46,.40,.36), `MARBLE` (L10685: top .94,.94,.91, side .81, waist .66, rail .96), `LOESS` (L9948), `LOESS_EARTH` (L10493), `CITY_LOOK` and `CC` (L11327–11338).

### 1.3 Per-sect roof line + ornaments — `SECT_STYLE` (L8650–8660)
Roof parameters feed `roofLoft/skirtLoft/tentLoft/roundRoof/gableRoof`: `sag` (concavity exponent p = 1+sag), `liftK` (corner upsweep ∝ half-depth), `flare` (corner outward push), `hK` (height multiplier).

| look | sag | liftK | flare | hK | ridgeEnd | ridge mid | corner | finial | lattice | ornCol |
|---|---|---|---|---|---|---|---|---|---|---|
| ice | 0.14 | 0.12 | 0.035 | 1.2 | blade | sword | blade | sword | slit | .92,.80,.50 |
| jade | 0.92 | 0.46 | 0.10 | 0.95 | scroll | gourd | curl | gourd | — | .90,.76,.40 |
| gold | 0.55 | 0.30 | 0.075 | 1.0 | chiwen | pearl | beasts | pearl | — | .92,.74,.34 |
| phoenix | 0.50 | 0.44 | 0.14 | 0.84 | bird | flame | plume | flame | — | .93,.77,.57 |
| earth | 0.12 | 0.10 | 0.04 | 0.74 | horn | seal | tusk | seal | — | .52,.56,.46 |
| water | 0.45 | 0.20 | 0.12 | 0.78 | wave | pearl | curl | pearl | — | .86,.88,.88 |

Ornament geometry (all built with `limb` tapered prisms; `t` = ridge thickness = max(1.5, B·0.06)):
- ridgeEnd (L7073–7107): `blade` base box 1.8t, blade limb to +7.2t high, guard bar 2.6t; `scroll` 3-limb curl to 3.5t; `chiwen` base 2.6t, 3-limb curl up to 6.3t, a sword through its back; `bird` 鸾: body, neck to 2.6t, head/beak, crest, 3 tail plumes, 2 half-raised wings; `horn` blunt 2-limb horn to 4.6t; `wave` 4-limb curl to 3.6t, white tips, two spray limbs; default: 4-sided spike prism h 3.4t.
- ridgeMid (L7121, only if half-depth B ≥ 10): sword `spireBlade(h = 0.62B)`, gourd `r = 0.1B`, pearl `r = 0.095B`, flame `h = 0.3B`, seal `s = 0.11B`.
- cornerTip (L7131, only if B ≥ 6, at each eave corner, pointing out along the diagonal): blade limb 0.2B out +0.07B up; curl (two limbs); beasts = 4 small boxes stepping up the hip (s = 0.028B); plume = 3 feathers; tusk = 2-limb curve.
- finial (L7150): sword max(6, 2.4h); gourd max(0.9, 1.7r); pearl max(0.9, 1.6r); flame max(3, 1.5h); seal max(1.2, 2.2r).
- Primitive ornaments: `spireBlade(h)` grip 0.05h×0.16h, guard 0.26h×0.035h×0.07h, 4-sided blade to h (L7160); `gourd(r)` 5 stacked prisms + stalk, total 3.07r (L7167); `pearl(r)` lotus seat + pearl + flame cone, 2.8r (L7177); `flame(h)` (L7109); `seal(s)` 1.6s (L7117).

### 1.4 Primitive modules (dimensions are function parameters unless given)
Core solids:
- `box(x,y0,z,w,h,d,col,top,ink)` L6893: axis-aligned in frame, footprint centred, y0..y0+h, **no bottom face**.
- `prism(x,y0,z,r,h,n,col,top,ink,taper,rot)` L6902: n-gon frustum (top radius r·taper), optional top cap; side ink weakened for n > 8.
- `cone(x,y0,z,r,h,n,…)` L6908; `crystal(x,y,z,r,h,col,n=5)` L6913: bipyramid, apex +0.62h, bottom −0.38h (spirit stones).
- `slab3(p0,p1,w,t,col,top)` L7412: a slab whose top centre-line runs p0→p1 (any slope), w wide, t thick downward — the workhorse for rails, beams, stair treads, decks, walls.
- `limb(K,a,b,r0,r1,n,col,ink,capCol)` L8440: tapered n-gon prism along a segment, capped.
- `quad4` per-edge ink quad (L6973).

Roofs (all take **half extents** W, D and height H; return ridge/top y):
- `roofFlat` L6919 (庑殿, cheap): corner lift = 0.26·B; ridge half-length `rl = max(0, A − 0.92B)·ridgeK`; dark underside at y0+lift/2; ridge box t = max(1.5, 0.06B) plus two 4-sided end spikes.
- `roofLoft` L6998 (sects, curved): 4 rings at t ∈ {0.30, 0.62, 0.86, 1}; ring half-sizes a = rl + (A−rl)t, b = Bt; height **y = y0 + H·(1−t)^(1+sag)**; corner weight `cw = smoothstep(0.3,1,|s|)^1.6` (s ∈ −1..1 along a side, m = 5 points/side); outward flare `f = 1 + flare·cw·t²`; corner lift `+ lift·cw·t³` with `lift = B·liftK`. Ridge → first ring triangles; TILE pattern; dark eave soffit; 4 hip ridges (垂脊, ribbon width max(1.2, 0.045B)); corner tips; 正脊 box + ridge ends + mid ornament; `o.gable` → 歇山 gable triangles at tb = 0.44 (`gables`, L7186) with barge boards; rl ≤ 0 → 攒尖 finial.
- `skirtLoft` L7031 (lower eave of 重檐): rings t ∈ {0, .45, .78, 1} from inner half-size (w0,d0 @ y1) to outer (w1,d1 @ y0); lift = min(w1,d1)·liftK·0.667; sag·0.91; flare·0.86. `skirtFlat` L6943.
- `tentLoft` L7044 (n-sided pavilion roof): rings t ∈ {0.36, 0.7, 1}, m = 3/side, lift = r·liftK·0.867, finial r·0.06 / 0.24r. `tentFlat` L6954.
- `roundRoof(x,y0,z,rOut,rIn,h,col,{n=24,sag})` L8698: sagging cone ring rOut→rIn, rings t ∈ {0,.3,.58,.82,1}, pale ribs every 3 segments; n = 6/8 for 亭/塔.
- `gableRoof(x,y0,z,W,D,H,{rolled})` L8717: two-slope along x, **W full length, D full eave span**; profile from 9 (or 10 rolled) stations; straight for ice (sag < 0.25 → p = 1.04), else p = 1 + 0.75·sag; 卷棚 rolled crest; gable walls; ridge box + ends + mid.
- `doorHood` L8743 (门罩 for clan halls).

Buildings (faces +z in frame):
- **`hall(x,y0,z,w,d,h,o)` L7196** — the main 殿 module. Stone base `w+10 × (base+2) × d+10` from y0−2, `base = o.base ?? 0.24h` (ASHLAR). Eave overhang `ov = max(8, 0.42h)` (lofted) else 9. Front 踏跺 stair if base > 3: width min(0.3w, 40), ns = max(3, round(base/1.8)) steps of 2.4 run, with side cheeks. Body `w−6 × h × d−10` at z−3 (PLASTER) + stone dado 0.13h. Columns 3.2×h×3.2 + 柱础 4.8×1.3 at `np = max(3, round(w/20))` bays front and back, side columns every ~22 (`ns = max(2, round(d/22))`). Front bays: 裙板 (0.2h at 0.13h) + lattice doors (0.48h at 0.33h) set back 7.4 from front face; ice style = doors in middle 3 bays only, other bays wall + 直棂窗 (SLIT, 0.34h at 0.43h). Back lattice band 0.32h. Plaque `min(0.17w,24)` × 0.13h at 0.66h. Painted beams 0.11h at 0.78h; 斗拱 brackets `nb = max(3np, round((w−6)/6))` at 0.89h/0.94h. `o.tiers === 2`: skirt from y1+h to y1+1.3h (inner half 0.38w×0.36d → outer w/2+ov), upper storey `0.72w × 0.58h × 0.68d` at y1+1.18h with lattice windows, roof at **y1+1.76h**, half (0.36w+ov, 0.34d+0.9ov), H 0.76h; single tier: roof at y1+h, half (w/2+ov, d/2+0.9ov), H 0.8h. Options: wall/roof/col/lattice colours, wallMat, doorMat, `pillar` callback, gable, ridgeCol, door:false.
- `pavilion(x,y0,z,r,{n=4,h=1.05r,rot})` L7265: base prism 1.05r × (0.16r+2), n columns 2.6 at 0.78r, tent roof r·1.24 / h 0.8r.
- `pagoda(x,y0,z,s,levels,{n=4,taper=0.84})` L7272: base prism 0.78s × (0.22s+2) (8-gon); storey heights 0.56s first, 0.4s others; each storey's roof half (sz/2+0.24sz) H 0.28sz (or tent for n ≠ 4); next y += hh + 0.17sz; sz *= taper; finial 0.95s (or sect finial).
- `tower(x,y0,z,w,d,floors,h)` L7291 (楼阁): base w+8 × 0.22h+2; floors box w·s × h × d·s, 4 corner posts 2.6; between floors skirt to (ww/2+7) and +0.22h, s *= 0.86, front rail 2.6; roof half (w·s/2+8), H 0.9h.
- `corridor(p0,p1,y,{w=10,h=9,bay=11,out=±1})` L7312 (回廊): plinth slab w+2.4 × 3.6; posts 1.6 every bay both sides; outer plastered wall 0.5H + lattice band 0.26H; court-side rail; painted beams; two-slope roof (eave ov 2.6, ridge height 0.36w), gable triangles, lanterns every other bay (sectGlow 5.5).
- `gateTower(x,y0,z,w,d,h)` L7338 (门楼): base 0.22h; passage width 0.28w (dark) to 0.74h; plaque; lintel; skirt; upper storey 0.72w × 0.62h × 0.62d at y1+1.16h; balcony rail; roof half (0.38w+6, 0.33d+5), H 0.72h.
- `stelePavilion(r)` L7357 (碑亭): base 2.4r; 4 columns at ±0.84r, height 1.15r; turtle shell prism 0.5r; stele 0.34r×0.72r; roof half 1.32r H 0.8r.
- `bellTower(s,{drum})` L7370 (钟/鼓楼): base s+6; lower box s × 0.6s; skirt; open upper with 4 posts at ±0.36s, 0.5s tall; bell prism r 0.17s or red drum r 0.2s; roof half 0.64s, H 0.44s.
- `gateArch(x,y0,z,span)` L7386 (牌坊, 3 bays): unit G = span/92; posts at u = ±16G, ±46G, 5.5G square, inner 50G tall, outer 38G; centre lintel 38G×6G×5G at 42G with roof half (24G, 6.5G) H 10G at 48G; side lintels 30G at 31G with roofs half (17G, 6G) H 8G at 36G.
- `stele(w,h)` L7393: base 1.5w × 0.14h × 0.9w; slab w × h × 0.35w; cap 1.25w × 0.1h. `lampPost(h,glowCol,size=9)` L7394: shaft 1.6, head 3.6×3.4. `cauldron(r)` L7397. `huabiao(h)` L7515: r = 0.05h, base 2.4r, shaft r × 0.84h, cloud board 5.4r at 0.72h, cap, beast.
- `sword(x,y0,z,h,rot)` L7399 (planted point-down): blade half-width 0.07h from 0.06h to 0.72h, point at −0.05h, fuller, guard 0.34h × 0.035h at 0.72h, grip 0.045h × 0.17h, pommel at 0.925h.
- `rail(pts,y,h=4)` L7421 (slab 1.8 wide). `balustrade(P,off,{rail,step=7,h=5.2})` L7525: posts 2×h×2 every `step`, top rail 1.3×1.1 at h−0.6, low rail 0.9 at 1.8.
- `banner(h,col,yaw)` L7655 (幡): pole 1.2, finial, 5.5 arm, two-sided cloth from h−1.4 down to 0.38h.

Ways (bridges / stairs):
- `steps(pts,w,{rail,lamps,stringer,col,side})` L7489: per segment `ns = max(1, round(max(|rise|/3.2, run/9)))` blocks, each a slab of thickness |rise|/ns + 2.5; rails 1.2×3.2 at +4; lamps every `o.lamps` treads (sectGlow 6 at +6); stringer slab 0.86w × 7 under air spans; registers a walk path (w ≥ 9).
- `grandStair(p0,p1,w,{flight=34,stringer,gate,floor,side})` L7639 (天阶): `nf = ceil(|rise|/flight)` flights, landings `lp = min(0.14·run/(nf−1), 0.8w)`, balustrades, 御路 middle strip 0.24w in trim colour, 10-tall lamp posts at landing corners, pack stone lamps at foot/head of each flight, optional 牌坊 (w·1.3) at the foot.
- `archBridge(p0,p1,w,{arch=0.05·span})` L7424: n = max(4, round(span/18)) slabs 5 thick, parabolic camber `arch·4t(1−t)`, parapets 1.5×3.5, lamps every 3rd segment.
- `jadeBridge(p0,p1,w,o)` L7547 (玉桥): deck thickness 4.5+0.14w, camber min(0.022·span, 8), n = round(span/14) segments, moulded band w+2.6, middle way 0.3w; under = `arch` if span < 240 (spandrel rise min(80, 0.24·span)) else `piers` (np = round(span/90)−1 square piers 0.42w down to min(y)−190, spandrels between); balustrades; lamp posts every ~52 (9+0.12w tall); ends = 华表 pairs (22+0.5w tall) or 牌坊 (1.25w). `spandrel` L7534.
- `gallery(p0,p1,w)` L7585 (廊桥 on a jade bridge): posts 2.2 × (9+0.32w), roof ridge 0.42w, double-eaved mid pavilion if span > 160.
- `coveredBridge` L7433: n = max(3, round(span/14)), H = 8+0.22w, ridge 0.36w, arch min(0.035·span,10), mid pavilion if span > 190.
- `stairGallery` L7458 (爬山廊): ns = max(4, round(|rise|/3.4)) steps, H 8+0.2w.
- `chainBridge` L7479 (索桥): sag 0.055·span, planks n = max(8, round(span/3.4)) 1.2 thick, chains 4.8 above, corner posts 2.4×11 with lamps.
- `planks(pts,w,cx,cz)` L7725 (栈道 on brackets), `pier(p0,ux,uz,len,w)` L7688 (悬空码头 with struts).
- `disc(x,y,z,r,o)` L7603 (浮台, round floating platform): deck thickness max(5, 0.12r), glowing rim band (r·1.035, 2.6 tall), stepped underside → crystal at the point (or a stilt), 14 rim glows, formation decal `{r 0.86r, spin 0.04}`, balustrade with gaps, centre = cauldron | pavilion | crystal | pool.

Props: `spiritBoat(x,y,z,L,yaw)` L7664 (beam 0.26L, freeboard 0.07L, bow up 2.6h, rune band glowing, deck pavilion r 0.11L if L > 30, mast 0.3L + flag, 5 rune glows per side); `furnace(r)` L7698 (drum r × 1.1r, bronze hood, mouth glow, chimney 1.9r, smoke); `cog(r,t,n=12)` L7708; `crane(h)` L7714.

### 1.5 06bb sect parts (L8430–8629)
- `buildPuppet2(K,x,z,h,yaw,y0)` L8457 (傀儡金刚): all proportions × h (full height): boots 0.075×0.05×0.14; greaves to 0.25h; thighs to 0.44h; skirt of plates prism r 0.135h at 0.35h (verdigris `vg` [.4,.55,.48]); belt 0.465h; breastplate r 0.112h, h 0.19h taper 1.26; **spirit-core mirror** at (0, 0.615h, +0.118..0.142h) r 0.052h + glow 13; pauldrons; arms; helmet at 0.73h; face plate; **eyes** glows at ±0.017h, 0.768h; plume to 0.9h; **halberd** shaft at (0.205h, 0, 0.1h) up to 1.06h, point to 1.17h, blade 0.085h out. Colours bronze [.5,.41,.27], dark [.3,.26,.21], gold = look trim.
- `buildPuppet(K,x,z,h)` L8226 (older robed guardian, prism stack, holding a sword point-down): not called in v4.4 (`S.def.puppets` empty, L1331).
- `swordRingMesh(o)` L8498: n swords on radius r, each `sword(len)` at y = sin(3a)·0.06len − 0.4len, rotated −a+π/2 (flats to the centre), own mesh, glow 0.55.
- `danDing(K,x,y0,z,r)` L8512 (丹鼎): hearth prism 1.25r; 3 beast legs (limbs) from 0.5r @ +0.78r to 0.72r @ ground; belly (0.7r/0.98r), gilt band at 1.02r, shoulder, rim at 1.49r; 2 upright ears at ±0.72r up to 1.95r; domed lid at 1.58r; jade finial crystal at 2.12r; 3 fire glows under (r·0.6, kind 1, 1.1), jade glow on top; smoke at 2.3r.
- `herbTerraces(K,x,z,yaw,rows,w,d,rnd,y0)` L8534 (药田): `rows` beds of `w × d`, each a stone-edged box levelled to the highest corner (skipped if slope > 16), rows of crop boxes every ~3.2 (5 crop colours, L8535), 60% chance of a mote glow (kind 3). On an island (y0 given) each row is 2.4 higher toward the back.
- `earthForge(K,x,y0,z,r)` L8557 (地火炉): octagonal stone base r × 0.3r; bronze body 0.8r, 0.9r tall, taper 0.72; 2 gilt bands; flaring mouth to 1.66r with fire disc; 4 fire-mouths (0.42r × 0.4r) round the base; glows r·1.2 at 1.9r, plus kind-3 motes at 2.6r/3.4r; smoke.
- `lavaChannel(p0,p1,y,w)` L8578 (dark lip w+2.4, glowing fill, glows every 16), `lavaPool(r)` L8585, `anvil(s)` L8592, `weaponRack(w)` L8602 (h = 0.55w, n = round(w/3) blades/spears), `quenchPool(w,d)` L8612 (steam smoke), `stoneLantern(h)` L8619 (6-sided: base 0.2h, shaft 0.07h, firebox at 0.6h with glow max(5, 0.42h), cap 0.26h at 0.76h).

### 1.6 06bc per-sect halls (L8664–9041)
Shared: `batter(W0,D0,W1,D1,h)` L8666 battered (inward-leaning) platform — 城台/墩台; `frontStair(x,y0,zt,h,w,run=2.5)` L8675 (ns = max(3, round(h/2.2)) blocks + 垂带 side slabs); `swordRail(W,D,gap,step=8.5)` L8683 (stone course 1.9 high + steel blade limbs from 2.35 to 8.4 every 8.5, gilt guards).
- 古剑门: `swordHall(w,d,h)` L8752 (batter W0 = w+36, D0 = d+28, top w+26/d+20, height 0.3h; stair width min(0.28w, 38); sword rail; `hall(tiers 2, base 0.06h)`; relief sword 0.5h on the upper storey + glow 20; anim `hoverSword` at top + 1.1h, len 1.9h, spin 0.07). `queTower(s)` L8768 (剑阙: batter 1.15s→0.92s, 1.25s tall; white storey 0.72s × 0.62s with slit windows; skirt; upper 0.48s × 0.34s; 4-sided tent 0.5s/0.66s; spireBlade 0.85s). `swordLodge(w,d,h)` L8786 (剑庐: stone lower storey 0.32h, plaster above, slit windows, steep gableRoof `w+6 × d+9 × 0.62d`, weapon rack in front). `swordTower(s,floors,fh)` L8802 (藏剑阁: batter 1.22s→1.04s × 1.1fh; floors ww × fh, ww *= 0.88/floor; slit windows all four faces; big (s > 45) gets balconies + deeper eaves; roof ridgeK 0). `swordGate(span,h)` L8824 (two giant swords h tall at ±span/2 on stone footings + glow).
- 落云宗: `cloudRail(r)` L8837 (round jade balustrade, cloud-knob posts, gap toward +z); `cloudHall(R,h)` L8850 (落云殿, 祈年殿-type: 3 round tiers radii 1.5R/1.37R/1.24R × 4.2 each with rails; front stair 14 wide; 16 vermilion columns at R; round lattice wall 0.84R; beam ring; 32 brackets; three round roofs: R+ov → 0.6R (h 0.42h), 0.6R+0.75ov → 0.36R (0.34h), 0.36R+0.58ov → point (0.6h) over two drums; gilt gourd r = max(2.4, 0.078R) + glow 16; 8 red lanterns under the first eave). `danFang(r,h)` L8882 (octagonal 丹房, 8 columns, lattice walls, 8-sided tent r·1.34/0.78r, furnace stack at (0.42r, −0.28r) 0.95r tall smoking). `herbPavilion(r,h)` L8900 (hexagonal 2-storey 药王阁). `discipleHall(w,d,h)` L8915 (long 卷棚: bays every ~12, rolled gableRoof `w+6 × d+8 × 0.42d`).
- 百巧院: `bronzeColumn(h)` L8928 (8-gon r 1.9, gilt bands at .08/.5/.9); `goldHall(w,d,h)` L8934 (天工殿: iron 须弥座 two steps W0 = w+26, D0 = d+22, height 0.32h with glowing fire slots; `hall(tiers 2, wall gilt METAL, doors STUD, gold tile roof, gable 歇山, bronze columns)`; anim `artifactRing` r 0.36w at top+0.62h spin 0.05); `furnaceTower(r,levels)` L8953 (炉塔: iron base 1.38r; bronze 8-gon storeys 1.25r then 0.92r, rr *= 0.86, fire windows rotating 45° per storey, gold roundRoof per storey n 8; open crown with fire glow 26 + smoke); `horseWall` L8976 (马头墙 stepped gables: 3 or 5 steps, white 2.4-thick walls rising 3.6–4.5 above the roof, dark caps, 印斗 blocks); `clanHall(w,d,h,steps=3)` L8992 (宗祠: white box walls, small dark windows, studded door + hood, gableRoof H = 0.36d without gable walls, 马头墙 both ends; steps 5 = 五岳朝天).
- Animated meshes: `hoverSwordMesh(len)` L9012 (two crossed swords, centred so it hangs point-down, glow 0.6); `artifactRingMesh(r)` L9022 (8 artifacts at radius r, size s = max(6, 0.12r): 钟 bell, 镜 mirror, 印 seal, 鼎 tripod, 环 ring, 塔 pagoda, 扇 fan, 瓶 flask; y = sin(2a)·0.4s).

### 1.7 06bj `ARCH` prefabs (v4.4, L10685–10875) — the live building vocabulary
- `podium(x,y0,z,w,d,h,{stairW,gate,round,open,back,rail,stair,marble})` L10689 (须弥座): plinth `w+5 × 0.3h+3`, recessed waist `w−2 × 0.45h`, cap `w+2.4 × 0.25h`; white balustrade (h 4.2, step 6) round the top, open for the stair; front grandStair width `stairW ?? min(0.32w, 34)`, run max(8, 1.7h); `gate` = arched 城台 gate (width min(0.18w,18), height min(0.62h, 26), stepped arch); `round` = 32-gon version with stairs at bearings `open`. Returns top y.
- `towerHall(x,y0,z,w,d,floors,h,{porch,cross,roof,wall,step=0.84,gable=true})` L10732 (楼阁): eave overhang ov = max(7, 0.55h); each floor box `(w·s−4) × h × (d·s−4)` (ground PLASTER, upper LATTICE), columns every ~13 front/back + sides, ground-floor lattice doors 0.46w and plaque; beams 0.16h at 0.84h; between floors skirt (to ww/2+ov) and a 平座 balcony slab `wn+6 × 1.6` at +0.3h with balustrade (h 3.4, step 5); s *= step; top roof half `(w·s/2+ov, d·s/2+0.9ov)`, H 0.9h, 歇山 gables by default. `porch` 抱厦 0.5w × 0.34d with 0.72h roof; `cross` side wings 0.36w × 0.62d (lake-sect cross plan).
- `grandHall(w,d,h,{podH=0.55h,marble,tiers=2})` L10773: podium `w+26 × d+30` + paved 月台 0.7w × 14 + `K.hall(tiers 2, base 3)`.
- `courtyard(cx,y,cz,w,d,{mainH=14,tiers,roof,wall,treeKind,treeCol,incense})` L10780 (院落): paved floor; main hall `0.58w × 0.27d × mainH` at back; gate hall `0.34w × 0.15d × 0.66mainH`; two side halls `0.36d × 0.17w × 0.62mainH` facing in; four corridors (w = max(6, 0.07w), h = 0.42mainH); tree; incense stand + cauldron.
- `arcCorridor(cx,y,cz,r,a0,a1,{w=9,h=8,seg=22,endR=8})` L10793 (环廊 + end pavilions).
- `roundPlaza(x,y,z,r,{center,open,lamps=8,step=1.6,gap=9,tint,floor})` L10801: 40-gon floor, darker inner ring 0.62r, balustrade (h 3.8, step 6) with openings at bearings, lamps at 0.86r; centre = `taiji` (taijiFloor R 0.55r, L10149), `water` (ring pool 0.36r–0.62r + 4 bridges), `formation` (decal r 0.8r spin 0.03 alpha 0.5), `crystal` (crystal 0.6r + glow + decal), `altar`, `dial` (12 trim spokes + gnomon).
- `cornerTower(x,y,z,s,{baseH=1.5s,floors=2})` L10824 (阙/角楼): white base `1.1s × baseH`, cap 1.22s, balustrade, towerHall `0.72s × 0.72s × floors × 0.42s` without gables.
- `qilin(x,y,z,s,yaw)` L10831 (瑞兽 on plinth 1.6s × 0.7s × 2.2s; body of boxes, horns, tail).
- `waterPavilion(x,wy,z,r,{lift=4,n=6})` L10846 (水榭: 4 piers, 2r deck, balustrade, pavilion 0.62r).
- `moonWall(a,b,y,h,{moon,moonR=7,col,cap})` L10854 (粉墙 2.6 thick + 4.4 tile cap; optional 月洞门 of radius moonR in the middle).
- `dress(x,y,z,w,{h=7})` L10867 (a stone lantern either side at ±0.5w).

### 1.8 06bk `ARCH2` prefabs (L10884–11069)
- `garden(K,S,x,y,z,r,rnd,{pavilion,trees=3,pavR=6k,deep,shallow})` L10886: noisy oval pond 0.62r × 0.4r (`uplandOval`, registered in `WORLD.uplands` for the water shader), stone kerb, arched bridge 4.6 wide over its waist (arch 0.1r), lotus, pavilion at ~0.98r, blossom trees, 2 rocks.
- `siheyuan(x,y,z,s,yaw,rnd,{wall,roof,h=max(5,0.17s),yb})` L10902 (四合院, flat roofs, cheap): step-up court s+2; main house 0.74s × 0.26s at −0.33s; wings 0.2s × 0.4s at ±0.36s; walls (h 0.62h) with front gate house 0.22s; tree.
- `yaoyuan(x,y,z,n,yaw,rnd,{bay=10,depth=15,h=10,yard=18})` L10924 (箍窑院: earth block `n·bay+4 × H × D` with flat roof, n arched doorways + paper lattices, walled yard, gate posts, millstone, jujube).
- `beacon(x,y,z,s,{smoke})` L10946 (烽燧: 4-sided earth frustum 0.62s × 1.5s taper 0.74, parapet, hut + roof; returns y + 2.04s).
- `granary(r)` L10957 (round earth drum r × 1.15r, conical thatch 1.28r × 0.95r).
- `travertine(K,S,cx,cz,{levels,spans,avoid,w=30,wMin=7,rIn,rOut,pavEvery,da=0.03,maxRun=26})` L10968 + `_pool` L10992 (水台阶 / 钙华池): for each water level (high→low) and bearing span, walk bearings in 0.03 rad steps, find the contour radius where ground drops below the level (binary search), pool width min(wMax·(0.8+0.4·(0.5+0.5 sin(7a+2.1li))), gap to next contour − 1.2k); runs ≥ 4 samples become a pool (water polygon inner/outer pushed to `WORLD.uplands`), white rim wall down to the ground + cap slab, end walls, lotus, a pavilion every `pavEvery` pools, a little fall (two crossed ribbons into `WORLD.falls`) where the rim stands > 4k above the next level.
- `islet(K,S,x,y,z,r,rnd,{kind})` L11021 (碎岛: `isleBody` in small; kind 0/3 blossom trees, 1 pine + rock, 2 pavilion, 3 also a lamp).
- `flyingShip(x,y,z,s,yaw)` L11033 (飞舟: 6 hull stations X = [.5,.36,.16,−.1,−.32,−.46]·s, beam B = 0.22s, keel depth D = 0.16s, sheer/width tables; red sheer band; deck house at −0.28s; mast 0.46s with batten sail; bow/stern lamps; under-keel glow s·0.5).
- `spiritPillar(x,y,z,h)` L11057 (灵柱: r = max(1.3, 0.024h); plinth 2.6r; shaft 0.86h taper 0.84; gilt bands at .34/.62/.86; capital 2.1r at 0.92h; lantern box 1.5r × 1.9r; 8-sided tent roof 2.6r; glow 9+0.06h).

### 1.9 Natural-ground helpers (06bh, L10071–10163)
- Terrain "pads" come from `S.land.pads` (03l, outside range). Each pad: x, z, h (level), and either r (round) or hw/hd + yaw (cs/sn). `padXZ(P,s,a)` L10078: s across (east at yaw 0), a along the axis **toward the back (north = −z)**: `x = P.x + s·cs + a·sn`, `z = P.z + s·sn − a·cs`.
- `terraceStone(K,S,P,{rail,gap=16,depth=18,lift=0.5,floor,side})` L10091: one ASHLAR block from below the lowest surrounding ground (rimLow − 3k, but at most `depth·k` deep) up to P.h + 0.5k — the cut-and-fill retaining wall; optional white balustrade (h 3.8k, step 6k) on chosen sides ('front','left','right','back' or true = front+left+right), open `gap·k` wide in the middle of the front.
- `axisStairs(K,S,list,w)` L10113: between successive pads on the axis, a grandStair from the lower pad up to the next pad's front edge with run = max(1.7·rise, 10k), flights ≤ 28k.
- `groundWall(pts,h,{th=3.2,step=12,cap,col})` L10123 (stepped wall following the ground, tile cap), `treesRound` L10137, `taijiFloor` L10149, `ringPool` L10158.

---

## 2. Build sheets

General per-sect pipeline (`buildSects`, L8348–8402): one `FacetBuf(3·65536)` for all sects, each sect a separate index range → **one mesh per sect** (`SECTS.siteMesh[id]`, culled per sect, L8379–8383); `K.L = SECT_LOOK[look]`, `K.q = 1`, `K.style = SECT_STYLE[look]`, `K.season = SEASON[look]` (L8361–8362); builder returns its top y; animated parts are pushed to `anim` and built after as separate meshes (L8384–8397); molten falls → one `lavaMesh` (L8398); domes last (L8399).

Sect placement data is in `SITE_DEFS` (L1235–1415, outside range but needed): each sect R = 1250 (× k), local (u, v) offsets → world via `W(u,v)` (L1581–1584). `cloud` / `base` = cloud-sea top / old cloud line (× k).

### 2.1 古剑门 Gujian — look `ice` (snow, gold-on-white, black lacquer)
- Location: SITE_DEFS.gujian L1246: land `natGranite`; masses 太白 (u60, v−580, r340, h940), 剑阁 (−310,−330, h806), 东岭 (390,−340, h784), 北岭, 西前, 东前, 山门 (110, 470, h566)…; cloud sea at 482k (base 324k). Snow `snow: 1`.
- Bench `court` (u40, v−210, 400 × 420, rise 176): pads along the axis (a = along, s = across): gate (a −185, 110 × 36), arena (a −110, r 62), main (a −2, 236 × 92), rear (a 96, 196 × 72), crown (a 170, 112 × 44); side yards westYard/eastYard (a −110, s ∓140, 96 × 104), westUp/eastUp (a 70, s ∓165, 86 × 76). Pads jiange, dongling (r 20 summits), stele (110, 470, r 24).
- Builder `buildGujianNatural` L10172–10239:
  - terraceStone on all pads with rails (gate: left+right; west yards front+left; east front+right; others front+left+right); arena no rail (L10177–10178). axisStairs width 22k (L10179). Side-yard stairs 12k (L10181).
  - 山门殿: `gateTower(66k × 22k × 24k)` at gate (L10184); pair of qilin (s 4.2k) at ±42k; moonWall runs from ±36k to ±150k along the bench lip, 12k tall (L10185).
  - Approach: 14-point winding steps (9k wide, lamps) from gate down to the `stele` pad, `gateArch(36k)` there (L10187–10194).
  - 论剑台: `roundPlaza(r = A.r − 2k, center 'formation', tint [.92,.95,1], openings N/S, 8 lamps)`; **hoverSword len 16k at A.h + 36k, spin 0.4** (L10197–10200).
  - 凌霄剑宫: `ARCH.grandHall(92k × 42k × 22k, podH 9k)` at main, zh = M.z − 0.28·hd (L10204); side halls `hall(40k × 20k × 13k)` facing in at ±0.78·hw, corridors (7k) to the main hall, bell towers 12k at ±0.5·hw front (L10205–10210); dress 40k; **3 hover swords len 12k at x = (i−1)·46k, y = M.h + 74k (+10k for i = 1), spin 0.25/0.35/0.45** (L10212); glow 42k (L10213).
  - 藏剑阁 at rear: `podium(56k × 44k × 5k)` + `towerHall(40k × 30k, 3 floors, 12k, porch)`; 2 pavilions (8k, hex) at the corners (L10216–10220).
  - crown: `hall(44k × 22k × 13k, tiers 2)` (L10221).
  - West yard: `courtyard(1.84·hw × 1.8·hd, mainH 12k)`; east yard: courtyard + cauldron 4k + smoke (alchemy court); westUp: `towerHall(34k × 26k × 2 × 11k)` (藏书阁); eastUp: `hall(46k × 22k × 12k, 2 tiers)` + hex pavilion 6k (L10223–10226).
  - Frost pines round each terrace (12 round main, 7 others, not in front) (L10228).
  - Summits: jiange → towerHall (2 floors, 7k) + **hoverSword len 18k at +52k, spin 0.5**; dongling → pavilion (n 4) (L10230–10237).
- Formation dome: `{u40, v−260, rx = rz = 760, ry 700, color #eef0f2, alpha 0.32}` (L1271).
- Lights: all lamps L.lamp [1,.95,.84]; plaza and hall glows L.glow [1,.94,.78]; ice-blue sword lights [.78,.94,1] in older parts.

### 2.2 落云宗 Luoyun — look `jade` (green glaze, vermilion columns, white jade), the floating sect
- Location L1277: `natPillars` — sandstone pillar clusters 天泉 NW (−600,−560), 火云 NE (600,−540, red 丹霞), 北峰 (0,−930), 白凤 E (860, 90), 隐剑 W (−860, 40), 幻石 SSW, 锁烟 S, p1–p6; cloud 472k. Pads on pillar tops tqTop, hyTop, bfTop, yjTop, hsTop, syTop, bkTop (r 22–32). `noDrift: true`. No dome (`dome: null`, L1304).
- Islands (fixed/fitted, L1297–1303; y × k): main (0, −215, **y 716, r 130, ex 1.25**, fixed), gate (0, 50, y 636, r 46, fixed), sutra (−245,−330, y760, r60), alchemy (245,−310, y734, r58), elder (−80,−600, y848, r52), lodge (380,70, y648, r62), herbs (−380,70, y624, r72), arena (−20,340, y590, r50). `fitIslands` (L9069) spirals non-fixed ones off rock/terraces/each other.
- Island body `isleBody` (L9125): flat grass top, stone lip, cliff tiers down to a hanging point; depth `isleDepth = min(1.9r, 70 + 0.9r)` (L9063); outline n = 26 / 18 / 14 points by size; rings `[1.0, 0], [1.05, −min(6, 0.08r)], [0.92, −0.2dep], [0.7, −0.42dep], [0.44, −0.66dep], [0.2, −0.86dep]` then tip at −dep (procedural) — or the pack rock `rockT1` hung upside down (roll π) scaled to r·0.96 and dep·0.98 (L9134–9154); 3–5 hanging spikes; ragged turf fringe over the lip; moss band on the sunny side; 2–3 glowing spirit crystals under it (L9166–9169).
- Builder `buildLuoyunNatural` L10247–10333:
  - main island: `podium(128k × 70k × 10k, stair 30k)` at zb = M.z − 0.48r; **落云殿 = towerHall(96k × 50k, 3 floors, 15k, porch)**; side towers `towerHall(30k × 28k × 2 × 11k)` at ±0.88r with corridors (8k) to the hall (L10256–10263); round 太极 plaza r 42k at M.z + 0.22r with 4 openings and 8 lamps (L10264–10265); side halls 40k × 18k × 11k facing in; 华表 26k; gardens (r 24k) at ±104k, +74k; **spirit pillars 72k tall** at ±76k (two rows); lamp posts; two qilin islets (r 19k, 26k below the deck, ±150k, +128k) each with a round podium 22k + qilin 7k (L10268–10280); `gateArch(44k)` at the lip; paved way 16k–18k (L10281–10285); 18 blossom trees round the rim; **two falls** off the lip (widths 9k, 7k) (L10288); glow 54k.
  - gate island: `gateTower(48k × 18k × 18k)`, lamp posts, **grandStair 16k (flight 30k, stringer)** up to the main island (L10291–10296).
  - sutra: podium 46k × 40k × 4k + towerHall 34k × 26k × 3 × 11k (藏经阁), arch bridge to main if gap < 130k, fall. alchemy: octagonal pagoda 24k × 2 + smoke + cauldron 5k (丹房), bridge if near. herbs: herbTerraces (4 rows, 1.1r × 0.3r) + hall 30k + herbPavilion 7k + fall. lodge: courtyard (1.3r × 1.1r) + **flyingShip (66k) moored off it with a gangplank** (L10305–10306). elder: towerHall 28k × 24k × 2 × 11k + fall. arena: roundPlaza 0.8r centre 'crystal' (L10301–10308).
  - 碎岛: up to 10 `ARCH2.islet` (r 9–19k) randomly within u ±760, v −780..440, between the islands' height range, never bridged (L10311–10322).
  - Pillar tops: tqTop/bkTop `towerHall` (≤ 18k, 2 floors, 8k); others pavilion (≤ 11k, n 4); glow 10k (L10325–10331).
- Bridges: `archLink(A,B,11k)` = pack bridge model stretched if span < 150 and level, else `jadeBridge(under arch)` (L9276–9285).
- Lights: lamp [.9,1,.84], glow jade [.5,1,.78]; red lanterns [1,.62,.42] in older parts.

### 2.3 百巧院 Baiqiao — look `gold` (basalt, iron tile, gold ridges, vermilion; maples)
- Location L1310: `natVolcanic`; 蜂窝 honeycomb mountain (0,−580, h 946), west/east ridges (±450, h 762/744), lava shelf (0,−150, h 604); a sheer tuff face `face: {u −270..270, v −362, top 830}` (L1318); cloud 476k; maples.
- Bench `yard` (u0, v−150, 540 × 420, rise 36): gate (a −170, 150 × 40), front (a −112, 270 × 66), round (a −24, r 64), main (a 104, 250 × 104, dy 6), westCourt / eastCourt (a 24, s ∓200, 120 × 176). Pads ta (−232,−322, r 28), westTop, eastTop.
- Builder `buildBaiqiaoNatural` L10340–10422:
  - terraceStone (front rails left/right; main floor [.66,.62,.56]); axisStairs 30k for gate→front and round→main (L10344–10347).
  - Outer wall: groundWall 9k tall from x0 = min(G.x − 140k, W left edge − 10k) to x1, front line with a 76k gap at the gate, sides and back (L10349–10354).
  - Gate hall `gateTower(70k × 24k × 24k)`; **two 机关傀儡 `buildPuppet2(h = 34k)` at ±56k, 14k in front of the gate** (L10356–10357).
  - Front plaza: gateArch 54k; stone lanterns 11k at ±62k; two ground pools 74k × 66k outside the front pad with 9 trees each and a waterPavilion 8k (L10359–10368).
  - Round water court: roundPlaza(r − 2k, center 'water', openings N/S, 6 lamps) (L10370).
  - 天工殿: `podium(128k × 62k × 10k, stair 32k)` + `towerHall(100k × 44k, 3 floors, 15k, porch)`; two arcCorridors (radius Rd.r + 30k, 8k wide) embracing the water court from bearing −0.68π→−1.08π and −0.32π→+0.08π; dress 56k (L10372–10377).
  - Honeycomb: up to 13 `fireCave` (w 7–13k, h 10–17k, 35% with timber eaves, glow [1,.62,.3]) scattered up the tuff face 24–174k above the bench, plank ledges between neighbours; smoke (L10378–10393).
  - Clan courts: moonWalls 8k on front/back/outer side (outer side with moon gate r 7k); west: towerHall 40k × 28k × 2 × 12k + courtyard; east: octagonal pagoda 26k × 3 (炼器室) + `furnaceTower(9k, 3)` + smoke + discipleHall 44k (L10395–10408).
  - 镇火塔: pagoda 22k × 5 storeys, 8-sided, dark, glow [1,.7,.4] (L10410–10411). Watchtowers `cornerTower(16k, baseH 10k)` on westTop/eastTop (L10413). 46 maples round the walls (L10415–10420).
- Dome `{u0, v−200, rx 720, rz 660, ry 640, #f2cd8f, alpha 0.24}` (L1332; "fainter… over the furnace mouth", L8345).
- Lights: lamp [1,.84,.56], glow [1,.72,.38], fire GOLD.fire [1,.56,.22].

### 2.4 鸾鸣宗 Luanming — look `phoenix` (grey-silver tile, white jade, rose gold; vermilion only on the 凤 tower)
- Location L1340: `natHill` broad green hill (mass luan r 520, h 344); low cloud 128k; river 鸾水 via points (L1342).
- Bench `palace` (0,−170, 300 × 460, rise 190): gate (a −205, 150 × 40), t1 (a −130, 244 × 70), t2 (a −40, 214 × 70), main (a 56, 222 × 92), back (a 160, 150 × 60); pad summit (0,−500, r 40).
- Forms (floating platforms, L1359–1362): perch (−330,−330, y 366, r 34, kind 'perch'), cloud (330,−320, y 356, r 32, 'gathering'), gateway (0,−690, y 426, r 36, 'teleport').
- Builder `buildLuanmingNatural` L10434–10488:
  - terraceStone on 5 pads (rails, gap 32); axisStairs 30k.
  - gate: gateArch 56k (rose-gold columns) + gateTower 54k × 18k × 20k + qilin pair 4.4k (L10440–10444).
  - t1: **twin towers 龙 (west, roof [.5,.54,.58]) and 凤 (east, roof vermilion [.72,.24,.2])** at ±0.68·hw: podium 46k × 46k × 5k + towerHall 32k × 32k, **4 floors**, 12k, porch; glows at T1.h + 66k (cool / warm) (L10445–10450).
  - t2: side halls 46k × 22k × 14k (2 tiers) facing in at ±0.7·hw; dress 46k (L10451–10452). Covered stair galleries `stairGallery(9k)` up both sides t1→t2→main (L10453–10456).
  - 和鸣殿: `podium(120k × 64k × 16k, gate: true, stair 30k)` (城台 with arched gate) + side grand stairs 14k up to the podium top + `towerHall(90k × 48k, 4 floors, 13k, porch)`; **bronze 鸾 statue (luanBird s = 14k, col [.86,.66,.4])** on the ridge; white corner towers `cornerTower(22k, baseH 26k, 2 floors)` at the back corners joined by moonWalls (14k, marble) (L10457–10469).
  - back: pagoda 18k × 3 (8-sided). Spirit pillars 48k (t1) / 60k (main). Summit pavilion (n 8). Trees: gold 梧桐 / red maples / purple 紫薇 (colour indices [3,3,2,7,8]) (L10470–10478).
  - Floating platforms: `fitIslands` then `formPlat` for each; floatSteps (arch 14k–16k) from main's sides to perch and cloud and from back to gateway (L10481–10486).
- Dome `{u0, v−280, rx = rz 760, ry 520, #f2b8a8, alpha 0.22}` (L1363).

### 2.5 倪航斋 Nihang — look `earth` (rammed earth, blue-grey tile, old bronze; no red, no gilt)
- Location L1368: `natLoess` tableland (塬), top 262, low 116, 8 gullies with terraced walls (L1371–1376); cloud 182k.
- Bench `bao` (0,−100, 520 × 380, rise 10): gate (a −120, 120 × 36), front (a −60, 262 × 72), main (a 30, 242 × 92), back (a 112, 200 × 56).
- Builder `buildNihangNatural` L10494–10599:
  - terraceStone (earth floor [.74,.68,.56]); axisStairs 24k.
  - 堡 wall: groundWall 12k high, 6 thick, loess colour, from x0 = G.x − 160k to x1 = G.x + 160k, front (with 64k gate gap) and back (zb = B.z − B.hd − 14k); **4 corner towers `cornerTower(18k, baseH 16k, 1 floor, earth marble)`**; gateTower 60k × 22k × 24k (L10501–10508).
  - 五色土 altar on front pad: two stepped ASHLAR squares (2·26k + 10k / +4k, 3k each), balustrade, five-earth triangles (E green, S red, W white, N black, centre yellow box) (L10510–10519); bell + drum towers 15k at ±0.74·hw (L10520).
  - 乾元殿: `grandHall(92k × 42k × 22k, podH 8k, earth)` + side halls 40k × 20k × 12k + corridors (L10522–10530). Back: towerHall 46k × 26k × 2 × 12k (藏经楼) (L10531).
  - Village: inside the wall 廊房 long rooms (15k × 42k) along the side walls every 50k, granaries (r 8k) in the back corners; outside: siheyuan (s 42–50k) in two columns each side and three either side of the approach; paved way 15k for 130k with gateArch 40k at its foot (L10533–10569).
  - Tableland: up to 9 箍窑院 `yaoyuan` (3–5 bays) 250–530k out, sometimes paired; **3 beacons `beacon(13k)` on the highest rim points, the first smoking** (L10570–10584).
  - Cave dwellings: up to 22 groups of 3 `caveMouth(6k × 8k)` (the middle one with a timber eave) in steep gully walls under the rim (L10586–10597).
- Dome `{u0, v−100, rx = rz 640, ry 460, #e8cf9a, alpha 0.2}` (L1391).

### 2.6 水影宗 Shuiying — look `water` (charcoal tile, white walls, black posts, silver; colour lives in the water)
- Location L1397: `natKarst` tower karst round a lake (lake u40, v−130, rx 1000, rz 660, rot 0.18, two arms), island mass dao (0,−40, r 200, h 96); towerField 26 towers r 38–84, h 70–210 (L1403; the towers are `karstTower` lathe rocks, 06bf L9994); cloud 14k (barely). No dome.
- Bench `isle` (0,−60, 230 × 250, rise 66): t1 (a −92, 210 × 50), t2 (a −32, 176 × 50), t3 (a 28, 144 × 50), top (a 92, 124 × 58); pad pier (0, 560, r 64, h 7).
- Builder `buildShuiyingNatural` L10606–10668:
  - terraceStone in marble (top rail all round, others front only, gap 24); axisStairs 22k; lotus gardens either side on t1, t2 (L10611–10614).
  - **水台阶 travertine pools** round the island centre (Dm = mass dao): levels every 7.5k from min(T2.h − 2k, T1.h + 14k) down to 4k; spans bearings [−1.15, 1.13] and [2.01, 4.3]; w 28; rIn 30k; rOut 420k; a pavilion every 4th pool (L10618–10624).
  - Willows (≤ 26) along the shore (L10625–10630). t2 pavilions (hex 8k) at ±0.86·hw; t3 side halls 34k × 18k × 11k (2 tiers) (L10631–10632).
  - 水影阁: `podium(92k × 60k × 16k, gate)` (城台) + side stairs 12k + `towerHall(50k × 38k, 3 floors, 13k, cross, porch)` (L10633–10638).
  - West: `coveredBridge(12k)` at y 3.5 from the island's west shore over the water to the bank + a waterPavilion 9k (L10641–10645).
  - South: grandStair 18k down to the water, then **arched spans (archBridge 12k, arch 9k) every ~95k to the pier, each intermediate stone pier an 8-gon marble prism with a pavilion (6k, n 4)** (L10647–10656).
  - Gate pier: terraceStone (marble), roundPlaza (r − 3k, centre 'dial', 8 lamps), gateArch 40k facing the lake, two cornerTowers 18k (baseH 20k, 2 floors), a waterPavilion (L10658–10664).
  - Boats: two `boat` anims on the west lake (L 22k and 18k, speed 0.022/0.03, y 2.5) (L10665–10666).

### 2.7 Legacy v4.0 layouts (defined, not called) — for reference only
`buildGujian` L9559 (凌霄剑宫 `swordPalace(172k × 70k × 44k)` L9526 with 5-storey 剑阁, hover sword len 3h and two sword rings n 14 / n 26), `buildLuoyun` L9624 (cloudHall R 64k with lotusRing r 124k, n 14; dock boat ellipse rx 520k rz 170k), `buildBaiqiao` L9705 (goldHall 240k × 80k × 50k, floating 炼天鼎 `cauldron` r 40k spin 0.035 and artifactRing r 112k, two furnace towers, 须弥台 with earthForge r 28k and 4 lava channels). Island kinds for `buildIsland` L9388: swordTomb, lodge, bell, trial, sword, fall, grove, rocks, shrine, deer, dorms, herbs, lotus, spiritTree, dock, pavilion, library, forge, clan, vault, puppetYard, lavaRock, nest (L9911), mirror (L9924). Moving bobbing islands `buildIsle` L8242 (kinds pavilion/pagoda/crystal/sword/tree/maple, optional thin fall ribbon) are created only from `S.def.isles` or bobbing drifters — none in v4.4 (all `isles: []`, `noDrift` or no `fitIslands` call).

### 2.8 浮空阵台 (formation platforms) — `formPlat` L9217 (used by 鸾鸣宗)
Octagon (n 8, rot π/8), radius r: paved deck thickness t = max(4, 0.1r); trim band 1.06r × 3.2 with 16 rim glows (5 + 0.05r); inverted stepped pyramid: 3 tiers each h = 0.17r, radius ×0.7, trim bands 1.8 between; cone to −0.42r; crystal at the point (r 0.07r+1, h 0.42r) + glow 12 + 0.16r; formation decal `{r 0.92r, spin ±0.04 (teleport ±0.08), alpha 0.46 (teleport 0.62)}`; pack octagon floor `templeBase1` if present. Kinds:
- `teleport` (传送阵): 8 ASHLAR posts 3.6 × 0.34r at 0.8r with crystals (2 × 7) and glows; anim `beam` r 0.55r, h 260; centre glow 30.
- `swordArray`: 8 great swords (len 1.05r) at 1.16r; anim `swordRing` r 0.62r, n 10, len 0.42r, spin 0.16, at y + 0.9r; stele.
- `gathering` (聚云台): lotus base + crystal 0.55r; anim `lotusRing` r 1.1r, n 9, s max(4, 0.11r), spin 0.07.
- `refinery`: furnace 0.2r, smoke, anim `artifactRing` r 0.85r spin −0.09.
- `perch` (栖鸾台, L9936): pillar 0.9r tall with a 鸾 (s 0.26r) on top, 4 lesser perches at 0.66r; anims `lotusRing` (r 1.05r, n 8, spin 0.06) and `pulse` (r 1.6r, n 2, speed 0.3, alpha 0.4) at the crest.
- default rune: 4 rune stones at 0.62r, crystal, anim `stoneRing` r 1.25r, n 6, s max(3, 0.09r), spin 0.1.
`floatSteps(A,B,{step=15,r=5.5,wob=6,arch=5})` L9264: n = round(run/15) octagonal slabs (r 5.5 ± 15%, 2.4 thick) on hanging rock spikes, lateral wobble `sin(2πt + ph)·6`, vertical arch `sin(πt)·arch` + ±0.6 jitter, a light under every 3rd.
**Island/platform placement (spiral)** `fitIslands` L9069: for each non-fixed island/form, try lift = 0, 20, … 120 and k = 0..139 spiral points `a = k·2.39996 (golden angle), d = 16·√k`; accept when (a) inside 0.97R of the sect, (b) bottom (y − isleDepth) is ≥ 22 above the max ground sampled on 28 sunflower points within 1.22r, (c) clear of terraces by r + 34 unless far above/below, (d) clear of placed islands by Q.r + I.r + 26 unless vertically separated by 40; else skipped.

### 2.9 Cities (06e, L11315–12114)
`CITY_DEFS` L11341–11361 (all in 丈, offsets u = east, v = south from the city centre):

| | 封日城 `minzhou` (sea fortress, 闵州) | 韵州城 `yunzhoucheng` (lake city) |
|---|---|---|
| wall half-size `half` | 620 (shift +170, −40 from POI) | 400 |
| inner terrace [cu,cv,hw,hd] / height | [0,−60,236,226] / 12 | [0,−40,150,142] / 10 |
| palace terrace / height | [0,−196,132,80] / +14 | [0,−122,86,52] / +12 |
| wallH / wallT / moat width | 30 / 22 / 58 | 25 / 18 / 48 |
| E–W avenue at v | 330 | 205 |
| hills behind (dir, span, r0–r1, uplift) | −0.32 rad, 1.5, 1550–5400, 0.5 | −1.75, 1.6, 1350–4300, 0.46 |
| knolls | pagoda 1950, temple 2150, beacon 3300 | 3 pagodas, temple, beacon |
| specials | `seaCity` (水城 basin, beacon tip, salt pans, quay, north-shore polyline), towns 3 | `lake` (u −1330, a 640, b 520), 2 causeways w 36, 3 islands, `annex`, `axisTo: 'luoyun'`, towns 2 |
| pearl / arrayIn / ascendIn / wardBeams | all false | all false |

Derived (planCities L11366): moat0 = half + 96, moat1 = moat0 + moat, flat radius `flatR = moat1·√2 + 150`; gates S (0, +g), N (0, −g), E/W (±g, ewV), g = moat1 + 70.
`buildCityOf` L11606–11829 (K.L = CITY_LOOK, K.q = 0 flat roofs):
1. Walls `cityWallRun` L11537: brick box L × wallH × wallT on a dark footing, 垛口 merlons 5 × 4.2 × 2.2 every 9.5 on the outer edge, inner parapet, **马面 bastions 26 × wallH × 16 every ~130** (not at gates). Corner 角楼: brick 50 × (wallH+2) × 50 + `tower(30,30, 2 floors, 12)` + lamp (L11615–11620).
2. Four gates: 城台 92 × (wallH+1.5) × (T+12), dark passages 12 × 16, gate hall `hall(70 × 26 × 15, 2 tiers, red walls)` on top; south gate gets a **瓮城** (side walls 16 × bd 70, front wall bw 120 + 16) with a 箭楼 (64 × 22 × 16, two rows of 7 arrow slits, roof); moat bridges `jadeBridge(w 30, arch, rise 9, camber 5, huabiao, brick)` (L11621–11643). Moat revetments (L11645).
3. Streets: N–S avenue 46, E–W avenue 38 at v = ewV, ring street 16 at `ring = H − T/2 − 10`, lanes 13; **blocks 104 × 104 on a 117 pitch** out from the two avenues (L11647–11665).
4. Block uses (L11680–11686): 4 market blocks (nearest (0.3H, ewV+150)), 1 temple, (array if arrayIn), 2 gardens near the north wall, ascension/granaries/warehouses for the big city. Market: shop rows all round + one 拍卖行 `tower(0.5·min(w,d), 3 floors, 14)` with 6 banners 22 tall and 8 lamps, other market blocks stalls (L11691–11706). Temple: ochre walls, pack temple or `hall(2 tiers, green tile)`, bell tower 16, **pagoda 20+0.008H, 9 storeys (7 small city)** (L11708–11716). Garden: lake 0.36·min(w,d), island pavilion, zigzag bridge, 太湖石, lotus (L11739–11749). Granary/warehouse sheds (L11751). Houses: lots ~50, 7% mini-gardens, 13% two-storey houses, else `cityCourtyard` (四合院, L11506) facing the nearest street; shop rows (`cityShopRow` L11523: houses 13–21 wide, 16–22 deep, 8–10 tall, awnings, banners 30%, lamps 35%) along avenue faces (L11756–11771).
5. Street trees every 34–36, red lanterns every 70 down the avenue (L11774–11776).
6. **钟鼓楼** at the avenue crossing: brick 56 × 17 × 56 with cross passages + `hall(40 × 40 × 13, 2 tiers)` (L11778).
7. Inner city: brick terrace (2·ihw × innerH × 2·ihd), red walls 9 high with 4 gates (gate halls 52/40 × 18 × 11, green tile), marble grand stairs (40 S, 26 others), corner pavilions, lamp posts, offices = green-tiled courtyards (L11779–11799).
8. **城主府**: marble second terrace (palaceH), balustrade, grand stair 40, main `hall(0.95·phw × 0.62·phd × 22, 2 tiers)`, two side halls, behind it **天机楼 `tower(tw = 42/32, floors 6/5, 18/15)`**; pearl (disabled in both, L11809) else a lamp glow; `landmarkY = towerTop + 40` (L11800–11817). Ward beams (disabled) (L11819).
9. Specials: `buildSeaCity` / `buildHarbor`, suburbs (`buildSuburb` L12011: shop rows ±13 and courtyards ±62 along each gate road up to ~620·(1.15|0.9)), `buildCityLake`, `buildCityAnnex`, `buildCityAxis` (L11821–11827).

- **封日城 sea fortress** `buildSeaCity` L11877: 水城 basin rectangle u 1772–1862, v 300–722 (90 × 422), brick walls 14 thick to y 22 with merlons every 12, quay walks; **水门**: two gate towers 30 × 30 on the mouth + `tower(18,18,2,9)`, a span with gate hall 60 × 16 × 11 (2 tiers); 平浪台 70 × 64; breakwater 130 long + glow; 5 ships in the basin (`cityShip` L34–46); seven sect agencies (courtyards 110 × 64 with banners in 7 sect colours, L11898) along the quay (u 1990→2920); 4 slipways with hulls and sheds; salt pans 46 + 6 grid on the neck (u 960–1640, v −640–220); watch towers every ~1000 along the north shore polyline (4-sided brick 13 × 30, timber room, roof, glow); **封日塔** at (440, 1430): 8-sided pagoda 15 × 9 storeys, gilded sun disc (r 8) on a pole, glows 30 / 14; 星海坊 light tower (12-gon, 70 + 4 + 12, cone cap, glow) at (0.62·half, −0.7·half) (L11883–11936).
- **韵州城 lake** `buildCityLake` L11833: causeways = slab3 width 0.62·36, top 1.6, brick sides, willows every 22 both sides, lamps every 120, a high jadeBridge (52 long, rise 8) mid-run; islands = brick 16-gon r·0.92 with pavilion court / pagoda (13, 5 storeys) / shrine hall + 10 trees; lakeside waterfront plaza 130 × 64 with rails, landing stair, gateArch 40, two `tower(16,16,2,9)`; 6 furled boats (L11835–11872).
- **Cultivator annex** `buildCityAnnex` L11940: 300 north of the N gate — teleport array (marble tiers r 70/54, pedestal, crystal 14, 6 steles at 62, decal r 46, `cityBeam` r 18 h 300 alpha 0.18), 落云宗 recruitment `hall(92 × 40 × 16, 2 tiers, green)` with 4 jade banners, three sect stores (courtyards 86 × 80 with jade / gold / steel banners).
- **Pilgrim axis** `buildCityAxis` L11955: along the main road from the N gate to 落云宗: a `gateArch(30)` at 700 then every 1000 丈, up to 6 two-storey inns (36 × 22 × 9) beside them (70%), a lamp post (9 tall, glow 5.5) every 150 alternating sides.
- Harbour (non-sea-city variant, unused by current defs since minzhou has seaCity) L11972, towns `buildTown` L12040 (shop street 2·(150+90n) long, courtyards ±66, 牌坊 at both ends, pagoda 13 × 7 or temple; fishing village variant), hill knolls `buildCityHills` L12076 (pagoda 16 × 7 on a brick base / temple / smoking beacon tower + 26 trees).
- Meshes: per city one FacetBuf(3·65536) + one for towns & hills (L12093–12104). Beams added separately (L12106).

### 2.10 06d lore ornaments (`buildLore`, L11146–11307; K.L = VILLAGE_LOOK)
- **传送阵** at each sect foot (170 along the road out) and city: optional stone footing + 12-gon base r 48 × 3.2, inner ring 40 × 1.6, **8 posts 4.2 × 18 at r 39 with crystals (2.2 × 8.5) at +25**, decal `{r 39, spin 0.18, alpha 0.55}`, 12 rising motes (kind 3), centre glow 30, stele + 2 lamp posts (L11177–11199).
- **灵田** beside sect arrays: bed 170 × 104, ridges every 12, a herb light every 8.5 (sizes 4.5–6, kinds 1, colours herbA [.66,.95,.82] / herbB [.78,.74,.96]), wattle fence, keeper's hut (L11201–11214); a ring of 70 herb lights round 灵眼之树 + 24 motes (L11217–11221).
- **洞府** (≤ 34·amount): on steep (slope 0.55–1.6) faces at h 110–560, mostly facing south, ≥ 650 apart; ledge 16s × 12s, frame 11s × 12s, dark door 7s × 9.5s, s = 1.3 (1.9 big with posts + roof), lamp glow 6 (L11224–11250).
- **古塔** (≤ 6): on hill crowns 40–230 high, ≥ 3600 apart, 5–7 storeys, s 15–19, lamp in the top storey (L11252–11272).
- **古战场巨剑**: between 古剑门 and 落云宗, `sword(h 210)` planted at hillside −40, rot 0.6, 7 rune glows up the blade, 5 broken steles (L11274–11290).
- **天柱山浮石**: 9 blob rocks r 10–22 orbiting the pillar (see §4) (L11293–11305).

---

## 3. Shaders in this range (GLSL) and Godot 4 translations

### 3.1 Formation dome 护山大阵 (L8287–8347)
Geometry: `SphereGeometry(1, 64, 24, 0, TAU, 0, π/2)` — a unit upper hemisphere — positioned at (D.x, 0, D.z), scaled (rx, ry, rz) (L8335–8344); transparent, depthWrite false, DoubleSide, renderOrder 9.
Vertex (L8288): passes `vL = position` (unit-sphere local coords), world pos with `wp.y *= 1 − uMap`, world normal.
Fragment (L8290–8332), key terms:
```glsl
float facing = abs(dot(N, V)); float rim = pow(1.0 - facing, 2.2);
float el = asin(clamp(vL.y,-1.,1.)) / 1.5708, az = atan(vL.z, vL.x) / 6.2831853;   // elevation 0..1, azimuth 0..1
float t = uTime * uFlow;
vec2 hp = vec2(az * 54.0, el * 15.0 - t * 0.12);                                    // hex lattice drifting up
float hexk = 1.0 - smoothstep(px*0.6, px*1.8, hexLine(hp));                          // AA'd by fwidth
// 3 rune bands at el = 0.30, 0.52, 0.74 (half-width 0.07), alternate scroll directions, tRune.a or a procedural dash
float swell = smoothstep(0.45, 0.85, fbm3(vec2(az*6., el*3.) + vec2(t*.05, -t*.08)));
float rp = fract(t * 0.07);
float ripple = exp(-pow((1.0 - el - rp*1.3) / 0.035, 2.0)) * (1.0 - rp) * uRipple;   // a ring sliding down from the apex every ~14 s
float ground = max(texture2D(tLand, (vWp.xz - uRect.xy) / uRect.zw).r, uCloudY);    // terrain height or cloud top
float hgt = vWp.y - ground;
float seam = exp(-max(hgt,0.)/30.) * smoothstep(-8., 2., hgt) * (0.45 + 0.55*smoothstep(.3,.7,vnoise(vec2(az*80.+t*.3, t*.2))));
float lowFade = smoothstep(0.0, 70.0, hgt);
float a = 0.025 + rim*0.4 + hexk*(0.025 + 0.11*rim) + rune*(0.08 + 0.24*rim) + swell*0.045 + ripple*0.22;
a = a*lowFade + seam*0.34;
a *= uAlpha * uWash * (1.0 - uMap) * mix(1.0, 0.55, uLow);
vec3 c = mix(uCol, vec3(1.0), 0.12 + 0.12*rim + 0.35*seam + 0.25*ripple);
c *= gl_FrontFacing ? 1.0 : 0.85;
```
`hexLine(p)`: `p.x *= 1.1547; p.y += mod(floor(p.x),2.)*0.5; f = abs(fract(p)-0.5); return abs(max(f.x*1.5+f.y, f.y*2.) - 1.)` (L8295–8299). Per-frame uniforms (L8421–8426): `uAlpha = CONFIG.sects.dome · D.alpha`, `uFlow = CONFIG.sects.flow`, `uRipple = CONFIG.sects.ripple`, `uLow = 1 − smoothstep(zoom.low·0.9, zoom.mid, A)` (A = camera altitude); `uCloudY = S.cloud − 25`.

Godot 4 spatial shader (MeshInstance3D with a hemisphere mesh, scale (rx, ry, rz); seam from the depth buffer instead of a height texture — or keep a `heightmap` sampler with a world rect):
```glsl
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
uniform vec3 dome_col : source_color = vec3(0.93,0.94,0.95);
uniform float alpha_k = 0.32; uniform float flow = 1.0; uniform float ripple_k = 1.0; uniform float low = 0.0;
uniform sampler2D rune_tex : hint_default_transparent; uniform bool has_rune = false;
uniform sampler2D height_tex; uniform vec4 world_rect;  // xz origin, size (or use depth fade below)
uniform float cloud_y = 457.0;
uniform sampler2D depth_tex : hint_depth_texture;
global uniform float map_mode;   // = uMap
varying vec3 vL; varying vec3 wpos;
float hexLine(vec2 p){ p.x *= 1.1547; p.y += mod(floor(p.x),2.0)*0.5; vec2 f = abs(fract(p)-0.5); return abs(max(f.x*1.5+f.y, f.y*2.0)-1.0); }
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float vnoise(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
  return mix(mix(hash(i),hash(i+vec2(1,0)),f.x), mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x), f.y); }
float fbm3(vec2 p){ return 0.5*vnoise(p)+0.25*vnoise(p*2.03)+0.125*vnoise(p*4.01); }
void vertex(){ vL = VERTEX; wpos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment(){
  vec3 N = normalize(NORMAL); vec3 V = normalize(VIEW);            // view space is fine for facing
  float facing = abs(dot(N, V)), rim = pow(1.0 - facing, 2.2);
  float el = asin(clamp(vL.y,-1.0,1.0))/1.5708, az = atan(vL.z, vL.x)/6.2831853;
  float t = TIME * flow;
  vec2 hp = vec2(az*54.0, el*15.0 - t*0.12); float px = fwidth(hp.x)+fwidth(hp.y);
  float hexk = 1.0 - smoothstep(px*0.6, px*1.8, hexLine(hp));
  float rune = 0.0;
  for (int i = 0; i < 3; i++){ float h0 = 0.3+float(i)*0.22, bw = 0.07;
    float inb = 1.0 - smoothstep(bw*0.7, bw, abs(el-h0));
    vec2 ruv = vec2(fract(az*(10.0-float(i)*2.0) + t*0.02*(mod(float(i),2.0)*2.0-1.0)), (el-h0)/(bw*2.0)+0.5);
    float r = has_rune ? texture(rune_tex, ruv).a : smoothstep(0.1,0.0,abs(fract(ruv.x*3.0)-0.5)-0.38)*smoothstep(0.45,0.3,abs(ruv.y-0.5));
    rune = max(rune, r*inb); }
  float swell = smoothstep(0.45,0.85, fbm3(vec2(az*6.0, el*3.0) + vec2(t*0.05, -t*0.08)));
  float rp = fract(t*0.07);
  float rip = exp(-pow((1.0-el-rp*1.3)/0.035, 2.0))*(1.0-rp)*ripple_k;
  float ground = max(texture(height_tex, (wpos.xz - world_rect.xy)/world_rect.zw).r, cloud_y);
  float hgt = wpos.y - ground;
  float seam = exp(-max(hgt,0.0)/30.0)*smoothstep(-8.0,2.0,hgt)*(0.45+0.55*smoothstep(0.3,0.7,vnoise(vec2(az*80.0+t*0.3, t*0.2))));
  float a = (0.025 + rim*0.4 + hexk*(0.025+0.11*rim) + rune*(0.08+0.24*rim) + swell*0.045 + rip*0.22) * smoothstep(0.0,70.0,hgt) + seam*0.34;
  a *= alpha_k * (1.0 - map_mode) * mix(1.0, 0.55, low);
  vec3 c = mix(dome_col, vec3(1.0), 0.12 + 0.12*rim + 0.35*seam + 0.25*rip) * (FRONT_FACING ? 1.0 : 0.85);
  if (a < 0.003) discard;
  ALBEDO = c; ALPHA = a;
}
```
(Depth alternative for the seam: `float scene_z = linearized texture(depth_tex, SCREEN_UV).r` vs `VERTEX.z`; seam ≈ `exp(-abs(scene_z - frag_z)/30)`.) Map-mode flatten: in `vertex()` add `wpos.y *= 1.0 - map_mode` via world-space vertex (`render_mode world_vertex_coords`).

### 3.2 Spirit lights 灵光 (06c, L11071–11136)
Data per light (L11073, `sectGlow` L7746): `[x, y, z, size 丈, r, g, b, kind, phase, strength]`; kinds: **0 steady lamp (slight flicker), 1 formation eye / spirit stone (slow pulse), 2 lotus lamp drifting, 3 spirit mote rising and fading**. Phase = `hash2i(round(7x), round(3z), 77)`.
Rendered as one `THREE.Points` (renderOrder 7, after land, before the cloud sea), AdditiveBlending, depthWrite false, depthTest true (L11102–11115). Each bobbing island / animated mesh gets its own Points child so its lights ride with it (L11124–11125).
Vertex (L11075–11091):
```glsl
if (kind==2) { p.y += sin(uTime*0.7 + ph*6.283)*3.5; p.x += sin(uTime*0.21 + ph*9.1)*7.0; p.z += cos(uTime*0.17 + ph*5.3)*7.0; }
if (kind==3) { float t = fract(uTime*0.07 + ph); p.y += t*150.0; p.x += sin(t*6.0 + ph*20.0)*9.0; a *= sin(t*3.14159); }   // rises 150 丈 every ~14.3 s
float pulse = (kind==1) ? 0.68 + 0.32*sin(uTime*1.6 + ph*6.283) : 0.9 + 0.1*sin(uTime*2.7 + ph*6.283);
gl_PointSize = clamp(size*1.9*uScale/max(dist,1.0), 2.5, 80.0);          // uScale = bufferHeight / (2·tan(fov/2))
vA = a*pulse*uWash*(1.0-uMap)*uGain*(1.0 - smoothstep(uFar*0.55, uFar, dist));
```
Fragment (L11092–11100): `r2 = |pointCoord·2−1|²; core = exp(−16 r2); halo = exp(−3.4 r2) − exp(−3.4); c = col·halo·0.75 + mix(col, 1, 0.55)·core·1.2; out = c·vA` (premultiplied, additive).
Per frame (L11128–11135): `uGain = CONFIG.sects.glow · (1 − 0.75·smoothstep(zoom.mid·1.3, zoom.high, A))`, `uFar = max(4000, 4.2A)`.

Godot 4: static lights → **MultiMeshInstance3D** of a camera-facing quad (use_colors + use_custom_data: CUSTOM = (size, kind, phase, strength)); size in world units (no pixel clamp needed, or emulate with distance). Shader:
```glsl
shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled, shadows_disabled;
global uniform float map_mode;
uniform float gain = 1.0; uniform float far_dist = 6000.0;
varying vec4 col_a;
void vertex(){
  vec4 d = INSTANCE_CUSTOM; float kind = d.y, ph = d.z, a = d.w;
  vec3 o = vec3(0.0);
  if (kind > 1.5 && kind < 2.5) o += vec3(sin(TIME*0.21+ph*9.1)*7.0, sin(TIME*0.7+ph*6.283)*3.5, cos(TIME*0.17+ph*5.3)*7.0);
  if (kind > 2.5) { float t = fract(TIME*0.07+ph); o += vec3(sin(t*6.0+ph*20.0)*9.0, t*150.0, 0.0); a *= sin(t*3.14159); }
  float pulse = (kind > 0.5 && kind < 1.5) ? 0.68+0.32*sin(TIME*1.6+ph*6.283) : 0.9+0.1*sin(TIME*2.7+ph*6.283);
  vec3 c = (MODEL_MATRIX * vec4(0,0,0,1)).xyz + o;                         // instance centre, world
  c.y *= 1.0 - map_mode;
  vec4 vc = VIEW_MATRIX * vec4(c, 1.0);
  float s = d.x * 0.95;                                                     // quad half-size ~ size/2 (PointSize used diameter 1.9·size/dist px)
  vc.xy += VERTEX.xy * s;                                                   // billboard in view space; quad verts in [-1,1]
  POSITION = PROJECTION_MATRIX * vc;
  float dist = -vc.z;
  col_a = vec4(COLOR.rgb, a*pulse*gain*(1.0-map_mode)*(1.0 - smoothstep(far_dist*0.55, far_dist, dist)));
}
void fragment(){
  vec2 q = UV*2.0-1.0; float r2 = dot(q,q); if (r2 > 1.0 || col_a.a < 0.004) discard;
  float core = exp(-r2*16.0), halo = exp(-r2*3.4) - exp(-3.4);
  ALBEDO = (col_a.rgb*halo*0.75 + mix(col_a.rgb, vec3(1.0), 0.55)*core*1.2) * col_a.a;
}
```
Kind 3 motes and kind 2 lotus lamps can alternatively be **GPUParticles3D** (emission shape = points baked from the light list; lifetime 14.3 s, velocity +10.5 丈/s up, sinusoidal x via turbulence, alpha curve sin(πt)). Put lights of moving parts in a MultiMesh that is a child of the moving node.

### 3.3 Light columns — 传送阵 beam (L9334–9349) and city beam (L11560–11580)
Array beam: open `CylinderGeometry(0.7r, r, h=260, 20)` translated so the base is at y 0; additive (src·alpha + dst, alpha untouched):
`a = (1−up)^2.2 · (0.55 + 0.45 sin(40 up − 3 t)) · 0.22 + (1−up)^6 · 0.25` (up = uv.y) (L9338–9339).
City beam: cylinder (0.7r, r, h, 12), additive: `a = uA · (1−vT)^1.6 · (0.25 + 0.75·face²) · (0.82 + 0.18 sin(30 vT − 2.2 t)) · smoothstep(0, 0.04, vT)` with `face = |N·V|` (L11567–11569); city annex beam r 18, h 300, a 0.18 (L11947).
Godot: `render_mode blend_add, unshaded, cull_disabled, depth_draw_never;` `float up = UV.y; ALBEDO = col; ALPHA = …` (same formulas, `TIME`). In Godot CylinderMesh UV.y runs top→bottom: use `up = 1.0 − UV.y`.

### 3.4 Molten-metal falls (L9351–9373) and island waterfall ribbons
`LAVA_FS`: `x = |2u−1|; body = 1 − smoothstep(0.5, 1, x + (vnoise(vec2(5u, 2.5v + 0.35t)) − 0.5)·0.35); streak = vnoise(vec2(10u, 6v + 1.2t)); c = mix([.95,.38,.10], [1,.86,.42], smoothstep(.35,.85,streak)·(1 − 0.6x)); a = body · smoothstep(0, .05, v) · (1 − 0.6·smoothstep(.75, 1, 1−v)) · 0.95`. Geometry = two crossed ribbons per fall along 10 points `out = 3 + 30 t^0.65`, `y = lerp(top, bottom, t^0.9)`, width `w·(0.85 + 0.35t)` (L9204–9211, L9362–9372). Water falls use the global `FALL_VS/FALL_FS` (outside range). Godot: a ribbon mesh (ImmediateMesh/ArrayMesh or a Blender-authored curve-ribbon) + this shader with `UV`, `TIME`, `blend_mix`, `cull_disabled`.

### 3.5 Pulse rings (鸾鸣's sound, 水影's ripples) L9900–9907
n `RingGeometry(0.9, 1.0, 64)` laid flat, MeshBasicMaterial additive, opacity animated (§4). Godot: a flat ring mesh + `blend_add` unshaded material with `albedo.a` driven by script or a shader computing `f = fract(TIME*speed + idx/n)`.

### 3.6 Facet material (outside range, used everywhere)
`facetMaterial({lift:false, glow})` (L4663): flat colour + inked edges from per-face weights + AM patterns; `glow` raises emissive (rune bands, swords: glow 0.55–0.8). For Godot: vertex colour albedo, `ink` = barycentric edge mask in a custom attribute (CUSTOM0 = barycentric, CUSTOM1 = 3 ink weights) or simply bake ink as a Freestyle/Line Art texture in Blender; emission = `glow · albedo`.

---

## 4. Animation (all in `updateSects` L8403–8428, `updateGlow` L11128, `updateLore` L11308, `updateCities` L12110)
`t = uTime` seconds; `map = uMap`.
- Generic spinners (wheel, armillary, swordRing, hoverSword, artifactRing, stoneRing, lotusRing, cauldron): `rotation[axis] += spin · dt · (ring ? CONFIG.sects.ringSpin(=1) : 1)` (L8417). Those with `ring` also bob: **`y = (ring.y + 3·sin(0.4t + ring.r)) · (1 − map)`**, hidden when map ≥ 0.999 (L8418). ring.r = 5 for hoverSword, 9 for artifactRing, 3 for cauldron, a.r for stone/lotus rings (L8389–8394).
  - wheel: axis z, spin 0.12 default (L8385); armillary: axis y, 0.18 (L8387); beam: static (L8395).
- Spin values in live v4.4 sects: 古剑门 hoverSwords 0.4 (论剑台, len 16k), 0.25/0.35/0.45 (three over 剑宫, len 12k), 0.5 (剑阁, len 18k) (L10199, L10212, L10236). 鸾鸣宗 platforms: lotusRing 0.07 (gathering, n 9) and 0.06 (perch, n 8); beam (teleport); pulse on perch (L9243–9259, L9943–9944). formPlat swordArray ring 0.16, refinery ring −0.09, rune stoneRing 0.1 (L9245, L9254, L9259).
- **Spirit boats** (`boat` anim, L8405–8409): `θ = t·speed + ph`; `position = (cx + cos θ·rx, (y + 4·sin(0.5t + ph))·(1 − map), cz + sin θ·rz)`; `rotation.y = atan2(−sin θ·rx, cos θ·rz) + π` (nose along the tangent); `rotation.z = 0.03·sin(0.4t)` (roll). 水影宗: two boats (L10666).
- **Pulse rings** (L8411–8415): `f_i = (t·speed + i/n) mod 1`; `scale = r·(0.15 + 0.85 f)`; `opacity = (1 − f)·(flat ? 2f : 1)·a·(1 − map)`.
- **Bobbing islands** (`SECTS.isles`, L8427): `y = (u.y + 6·sin(t·sp + ph))·(1 − map)`, `sp = 0.3 + 0.2·rnd`; `rotation.y = 0.25·sin(0.06t + ph)` (L8264).
- **Domes** uniforms (L8421–8426) — see §3.1; the shader flows (hex drift 0.12/s, rune scroll 0.02/s, ripple period 1/0.07 ≈ 14.3 s).
- **Spirit lights** — in shader (§3.2).
- **天柱山 floating stones** (L11308–11313): per stone `a = a0 + t·w` (w 0.028–0.040 rad/s), `position = (P.x + cos a·R, (y + 12·sin(0.4t + ph))·(1 − map), P.z + 0.9·sin a·R)`, R = P.r·(1.7–2.4), y = P.h·(0.62–0.87), `rotation.y = t·spin` (spin ±0.2).
- City beams: visible when map < 0.999 and CONFIG.city.beams > 0.01; alpha `uA = a0·CONFIG.city.beams` (L12110–12114).
- Smoke columns are pushed to `WORLD.smokes` (`{kind:'smoke', x, y, z, soft}`) for 11 (outside range): furnaces, cauldrons, forge vents, beacon, quench pools.
- Formation floor decals are pushed to `PROPS.sectFormations` / `PROPS.formationSites` as `{x, y, z, r, tint, spin, a}` (rendered outside this range): rotate at `spin` rad/s.

---

## 5. Godot / Blender mapping

### 5.1 Units and axes
- 1 丈 = 1 Godot unit (keep the numbers in this doc as-is). The demo's sects span R = 1250·k; heights up to ~950·k — set camera far ≥ 20 000 and use `Environment` fog; consider LOD (`visibility_range`) per sect.
- Kit front +Z (south) = glTF +Z. In Blender (Z-up), model every module **facing −Y** (front view); the glTF exporter (+Y up) converts Blender (x, y, z) → glTF (x, z, −y), so Blender −Y → +Z. Pivot at the **footprint centre, ground (y0) level** — matching `box/hall/pavilion` which take (x, y0, z) as footprint centre at base height. Exceptions: slab/rail/bridge modules pivot at segment start (p0) and are scaled along +X to span length.
- Kit yaw → Godot `rotation.y = −yaw` (see §1.1).

### 5.2 Blender modular kit — naming convention and module list
Convention `SM_<set>_<module>_<variant>` with sets `KIT` (shared), `ICE GJ`, `JADE LY`, `GOLD BQ`, `PHX LM`, `EARTH NH`, `WATER SY`, `CITY`, `LORE`; materials `M_<AM>_<look>` (e.g. `M_TILE_jade`, `M_PLASTER_ice`, `M_LATTICE_gold`, `M_ASHLAR_earth`, `M_BEAM_water`, `M_SLIT_ice`, `M_METAL_gold`, `M_STUD_gold`, `M_PAVE_*`), plus `M_ink` (or Line Art), `M_glow_<look>` emissive. Colour per look from §1.2 — one material set per look, or one atlas with a per-look palette row and vertex-colour tint.
Parametric modules whose proportions scale with one parameter can be authored once at a reference size and **scaled** (scale is uniform only where the source is proportional — see "scales with"):

| Module (Blender name) | Source | Reference dims (丈) | Scales with |
|---|---|---|---|
| SM_KIT_Roof_Hip_<look> (庑殿/歇山 lofted) | roofLoft L6998 | half W×D, H; 4 rings, m 5 | non-uniform (W, D, H) — author 3 aspect variants (1:1, 2:1, 3:1) per look; ridge length = max(0, A−0.92B) |
| SM_KIT_RoofSkirt_<look> (腰檐) | skirtLoft L7031 | inner/outer half sizes | non-uniform |
| SM_KIT_RoofTent{4,6,8}_<look> | tentLoft L7044 | r, h | uniform |
| SM_KIT_RoofRound{24,8,6}_<look> | roundRoof L8698 | rOut, rIn, h | non-uniform |
| SM_KIT_RoofGable_{straight,sag,rolled} | gableRoof L8717 | W, D, H | non-uniform |
| SM_<set>_RidgeEnd / RidgeMid / CornerTip / Finial | L7073–7158 | ∝ t = max(1.5, 0.06B) or B | uniform; 6 sets (blade/scroll/chiwen/bird/horn/wave …) |
| SM_KIT_Hall_{1t,2t}_<look> (殿) | hall L7196 | e.g. w 92, d 42, h 22 | rebuild per size (bay count np = round(w/20)); better: assemble from Column, Wall, DoorBay, SlitBay, Bracket, Plaque, Base, Steps sub-modules |
| SM_KIT_Column (3.2 sq + base 4.8) / SM_BQ_BronzeColumn (r 1.9) | L7214, L8928 | h | Y only |
| SM_KIT_DoorBay_Lattice / SM_ICE_SlitBay | L7224–7231 | bay ~ w/np | X, Y |
| SM_KIT_Bracket (斗拱) | L7244–7245 | 2.4×0.05h×3.4 + 4.2×0.06h×5 | MultiMesh |
| SM_KIT_Pavilion{4,6,8} | pavilion L7265 | r (h = 1.05r) | uniform |
| SM_KIT_Pagoda{4,6,8}_L{3,5,7,9} | pagoda L7272 | s, taper 0.84–0.9 | uniform |
| SM_KIT_Tower (楼阁 old) / SM_KIT_TowerHall_F{2,3,4}_{porch,cross} | L7291, L10732 | w, d, h/floor, step 0.84 | per floors |
| SM_KIT_Podium_{rect,round,gate} (须弥座) | ARCH.podium L10689 | w, d, h; bands 0.3/0.45/0.25 | non-uniform (rail as separate MultiMesh) |
| SM_KIT_Corridor_Bay (回廊 1 bay = 11) | corridor L7312 | w 10, h 9, bay 11 | tile along X |
| SM_KIT_GateTower (门楼) | L7338 | w, d, h | uniform-ish |
| SM_KIT_Paifang (牌坊) | gateArch L7386 | span 92 (G = 1) | uniform (G) |
| SM_KIT_StelePavilion / Stele / Huabiao / LampPost / StoneLantern / Banner | L7357, L7393, L7515, L7394, L8619, L7655 | as in §1.4/1.5 | uniform |
| SM_KIT_BellTower / DrumTower | L7370 | s | uniform |
| SM_KIT_Balustrade_Post (2×5.2×2) + _Rail (1 unit) | balustrade L7525 | step 7 (6 on podiums) | MultiMesh along path |
| SM_KIT_Stair_Step (2.4 run) / grand stair flight | steps/grandStair L7489/L7639 | rise ≤ 3.2/step, flight ≤ 34 (28k on axes) | procedural in Godot (Path3D + MultiMesh) |
| SM_KIT_Bridge_{arch,jade_arch,jade_piers,covered,chain,gallery} | L7424–7600 | span, w | Path-based; author a 1-segment module and repeat |
| SM_KIT_FloatDisc / SM_KIT_FormPlat8 (浮空阵台) | disc L7603 / formPlat L9217 | r | uniform |
| SM_KIT_FloatStone (浮石阶 slab r 5.5 + spike) | floatSteps L9264 | r 5.5 | MultiMesh |
| SM_KIT_Island_{S,M,L} (浮空岛 body) | isleBody L9125 | r, depth min(1.9r, 70+0.9r) | uniform; 3–4 variants, randomise yaw |
| SM_KIT_Islet (碎岛) | ARCH2.islet L11021 | r 9–19k | uniform |
| SM_KIT_Courtyard (院落) | ARCH.courtyard L10780 | w, d, mainH 14 | non-uniform |
| SM_KIT_RoundPlaza_{taiji,water,formation,crystal,dial,altar} | L10801 | r | uniform |
| SM_KIT_CornerTower (阙/角楼) | L10824 | s, baseH | uniform |
| SM_KIT_Qilin / WaterPavilion / MoonWall_{plain,moon} | L10831/L10846/L10854 | s / r / h | uniform / tile |
| SM_KIT_Garden / Siheyuan / Yaoyuan_B{2..5} / Beacon / Granary / FlyingShip / SpiritPillar | ARCH2 L10886–11067 | see §1.8 | uniform |
| SM_GJ_SwordHall / QueTower / SwordLodge / SwordTower / SwordGate / SwordRail_Seg / Sword | L8752–8833, L7399 | §1.6 | uniform |
| SM_LY_CloudHall / DanFang / HerbPavilion / DiscipleHall / DanDing / HerbBed | L8850–8924, L8512, L8534 | §1.6 | uniform |
| SM_BQ_GoldHall / FurnaceTower / HorseWall / ClanHall / EarthForge / LavaChannel / Anvil / WeaponRack / QuenchPool / Puppet2 / FireCave | L8934–9008, L8557–8617, L8457, L10030 | §1.5–1.6 | uniform |
| SM_LM_LuanBird / PerchPillar | L9883, L9936 | s | uniform |
| SM_NH_CaveMouth / FiveEarthAltar | L9951, L10510 | w, h | uniform |
| SM_SY_TravertinePool (rim segment) | L10992 | per contour | procedural (see below) |
| SM_CITY_WallRun_Seg (10 丈) / Merlon / Mamian / CornerTower / GateHall / Wengcheng / Ship_{2,3mast} / Shop / Courtyard / House_{1,2} | L11537–11604 | §2.9 | tile / MultiMesh |
| Animated: SM_GJ_HoverSword, SM_GJ_SwordRing_N{10,14,26}, SM_BQ_ArtifactRing, SM_BQ_Cauldron, SM_KIT_StoneRing, SM_LY_LotusRing, SM_KIT_SpiritBoat, SM_BQ_Wheel, SM_BQ_Armillary | L9012, L8498, L9022, L9317, L9289, L9303, L8202, L8186, L8208 | §1.6, §2.8 | separate glTF nodes, pivot at ring centre |

Notes for the artist: keep everything low-poly flat-shaded (the demo is "crisply faceted… every real edge inked", L6841); mark ink edges as Freestyle/sharp or use Godot outline; tile/lattice/ashlar look comes from patterns, so a simple tileable texture per AM id is enough.

### 5.3 Scene composition (Godot)
- One **PackedScene per sect** `res://sects/<id>.tscn`: root Node3D at the sect centre (S.x, S.z), children:
  - `Terrain` patch (from 03l — outside this range).
  - `Static` — the merged static building mesh(es) (mirror of `SECTS.siteMesh[id]`): either individual module instances placed by an editor @tool script that ports the builder logic (pads → terraceStone → prefabs), or one baked glTF per sect.
  - `MultiMesh` nodes for repeated parts: balustrade posts/rails, brackets, columns, merlons, lamp posts, steps, floating stepping stones, trees (sectTree / pack trees), herb rows, city shops/courtyards, salt pans.
  - `Animated` — one Node3D per anim entry (hoverSword, swordRing, lotusRing, stoneRing, artifactRing, cauldron, boat, pulse, beam) with a tiny script implementing §4 formulas; their lights as a child MultiMesh (so they ride along, as in L11125).
  - `Lights` — MultiMeshInstance3D with the spirit-light shader (§3.2), built from the `sectGlow` list; optionally a few real OmniLight3D for the biggest glows (sizes ≥ 30: hall glows, spirit trees).
  - `Dome` — hemisphere MeshInstance3D (scale rx, ry, rz; centre from SITE_DEFS dome u/v × k) with the dome shader (§3.1) for gujian, baiqiao, luanming, nihang.
  - `Water` — upland pools (`WORLD.uplands` polygons from groundPool/ringPool/garden/travertine) as flat meshes with a water shader; falls as ribbon meshes (§3.4).
  - `Smoke` — GPUParticles3D at each `WORLD.smokes` point.
  - `Formations` — decal quads (or Decal nodes) from `PROPS.sectFormations` with a rotating rune texture.
- Cities `res://cities/<id>.tscn`: Walls (tiled segments), Gates, Streets (Path3D-generated meshes), Blocks (MultiMesh courtyards/shops), InnerCity, Palace, Specials (SeaCity / Lake / Annex / Axis), Towns, Hills, Beams.
- Global uniform `map_mode` (= uMap) declared in Project Settings → Shader Globals; scripts multiply y by (1 − map_mode) and hide at ≥ 0.999.

### 5.4 Particles / MultiMesh guidance
- **GPUParticles3D** for: kind-3 rising motes (lifetime 14.3 s, 150 丈 rise, sin x-wander 9 丈, alpha sin(πt)), lotus-lamp drifters (kind 2: orbit ±7 xz, ±3.5 y, periods 2π/0.21, 2π/0.17, 2π/0.7 s), smoke from furnaces/cauldrons/vents, teleport-array motes (12 per array, L11194), the 灵田 herb lights (could be MultiMesh instead).
- **MultiMesh** for: all kind-0/1 static glows, balustrade posts (every 6–7), steps, brackets, merlons (every 9.5), city houses (variants by colour via instance colour: tileGrey/Dark/Blue/Brown/Green), trees, crops, floating stones, salt pans, swords in the sword tomb / sword rings (or a single animated mesh per ring as the demo does).
- Use `visibility_range_end` + fade on Lights so they fade like `uGain` (drop by 75% from zoom.mid·1.3 to zoom.high) and `uFar = max(4000, 4.2·altitude)`.

### 5.5 Porting the procedural placement (if not hand-placing)
- Port as Godot @tool scripts in this order: (1) pads/benches (03l, outside range) → (2) `terraceStone` + `axisStairs` → (3) per-sect builder (§2) instancing the Blender modules with the same dimensions → (4) `fitIslands` golden-angle spiral (§2.8) for any free islands → (5) `floatSteps`/bridges between `isleEnd` points (rim point toward the target, stepped in by `back`) → (6) lights list → MultiMesh.
- Keep the random seeds (`mulberry32(S.idx * 7919 + 3)` etc., e.g. L10173, L10248, L10341, L10435, L10495, L10607) if you want identical layouts.

---

## Appendix A · Anim entry schema (what builders push to `anim`, consumed at L8384–8397)

| kind | fields | mesh builder | update |
|---|---|---|---|
| `wheel` | x, y, z, r, yaw, spin (0.12) | wheelMesh L8186 (bronze rim 0.84–1.0 r, 16 teeth, 8 spokes) | rot.z += spin·dt |
| `boat` | cx, cz, rx, rz, y, L, speed, ph | boatMesh L8202 (spiritBoat at origin; its lamps dropped) | ellipse + bob + roll (§4) |
| `armillary` | x, y, z, r | armillaryMesh L8208 (4 hoops: tilt π/2; 0; yaw π/2; 0.41/0.6 + crystal) | rot.y += 0.18·dt |
| `swordRing` | x, y, z, r, n, len, spin | swordRingMesh L8498 | rot.y + bob (ring = the entry itself: ring.y = a.y, ring.r = a.r) |
| `hoverSword` | x, y, z, len, spin | hoverSwordMesh L9012 | rot.y + bob (ring.r 5) |
| `artifactRing` | x, y, z, r, spin | artifactRingMesh L9022 | rot.y + bob (ring.r 9) |
| `stoneRing` | x, y, z, r, n, s, spin, col, glow | stoneRingMesh L9289 (n crystals 0.5s × 3.2s + glow collars, y = sin(3a)·0.5s) | rot.y + bob (ring.r = r) |
| `lotusRing` | x, y, z, r, n, s, spin | lotusRingMesh L9303 (leaf pad 1.25s, 8 pink petals to 0.95s, light 8+0.8s) | rot.y + bob |
| `cauldron` | x, y, z, r, spin | cauldronMesh L9317 (7 flame cones, 3 legs, belly 0.92r, gilt lip 1.02r, ears, 4 饕餮 bosses) | rot.y + bob (ring.r 3) |
| `beam` | x, y, z, r, h, col | beamMesh L9342 | static (shader animates) |
| `pulse` | x, y, z, r, n, speed, col, a, flat | pulseRingMesh L9900 | scale/opacity (§4) |

Note on `swordRing`: L8388 passes `ring: a` (the whole entry), so its bob uses `a.y` and phase `a.r`.

## Appendix B · Light inventory (sizes in 丈, kind, strength) — for sizing Godot billboards / OmniLights
- Hall/plaza aura: 古剑门 剑宫 42k k0 0.55 (L10213); 落云殿 54k k0 0.5 (L10289); 和鸣殿 52k (L10468); 水影阁 40k (L10637); 五色土 altar 26k k1 0.45 (L10519).
- Spirit trees: 30 k1 0.7 at 7·sc + 18 k3 0.6 at 4·sc (L8003, L9461).
- Furnaces: earthForge r·1.2 k1 1.3 + motes (L8573); furnaceTower crown 26 k1 (L8971); fire caves max(6, 0.55w) k1 0.75 (L10042); lava channel w·1.6 k0 0.85 every 16 (L8582).
- Formation platform: rim 16 × (5+0.05r) k1 0.8; point crystal 12+0.16r k1 0.9; teleport posts 9 k1 0.85 + centre 30 k1 0.7 (L9230–9242).
- Lamps: lampPost 9 (default) / 6–7 on plazas; corridor lanterns 5.5; bridge lamps 6–7; stone lantern max(5, 0.42h) k0 0.9; spirit pillar 9+0.06h k0 0.9 (L7394, L7332, L7430, L8627, L11065).
- Puppet: mirror 13 k1 0.9, eyes 6 k1 1.0 (L8472, L8485).
- Island crystals: 9+0.08r k1 0.85 (L9168); disc underside 10+0.12r k1 0.9 (L7617).
- City: corner towers 8 k0 0.8; gate lamps 7 k0 0.9; auction 7 × 8; temple cauldron 8 k1; annex array 18 k1 1.1; 封日塔 30 k1 1.3 + 14 k0 0.9; watch towers 8 k1 0.9 (L11619–11935).
- Lore: array posts 10 k1 0.85, centre 30 k1 0.6, motes 5 k3 0.55; herb lights 4.5–6 k1 0.55–0.8; cave lamps 6 k0 0.8; pagoda top 8 k0 0.7; giant sword runes 6 k1 0.5 (L11191–11286).

## Appendix C · Godot animator scripts (GDScript sketches of §4)
```gdscript
# Spinner.gd — hoverSword / swordRing / lotusRing / stoneRing / artifactRing / cauldron
extends Node3D
@export var spin := 0.1          # rad/s (kit value)
@export var axis := Vector3.UP
@export var bob := true
@export var base_y := 0.0        # anim y
@export var bob_phase := 0.0     # ring.r (5 hoverSword, 9 artifactRing, 3 cauldron, r for rings)
func _process(dt):
	rotate_object_local(axis, spin * dt)   # three.js rotation.y += spin*dt (same handedness)
	var m: float = RenderingServer.global_shader_parameter_get("map_mode")
	if bob:
		var t := Time.get_ticks_msec() / 1000.0
		position.y = (base_y + 3.0 * sin(0.4 * t + bob_phase)) * (1.0 - m)
	visible = m < 0.999

# SpiritBoat.gd — ellipse path
extends Node3D
@export var cx := 0.0; @export var cz := 0.0; @export var rx := 100.0; @export var rz := 60.0
@export var y := 2.5; @export var speed := 0.03; @export var ph := 0.0
func _process(_dt):
	var T := Time.get_ticks_msec() / 1000.0
	var m: float = RenderingServer.global_shader_parameter_get("map_mode")
	var th := T * speed + ph
	position = Vector3(cx + cos(th) * rx, (y + sin(T * 0.5 + ph) * 4.0) * (1.0 - m), cz + sin(th) * rz)
	rotation = Vector3(0.0, atan2(-sin(th) * rx, cos(th) * rz) + PI, sin(T * 0.4) * 0.03)
	visible = m < 0.999

# PulseRings.gd — children are flat ring meshes with a StandardMaterial3D (blend add, unshaded)
extends Node3D
@export var r := 50.0; @export var speed := 0.3; @export var a := 0.4; @export var flat := false
func _process(_dt):
	var T := Time.get_ticks_msec() / 1000.0
	var m: float = RenderingServer.global_shader_parameter_get("map_mode")
	var n := get_child_count()
	for i in n:
		var c := get_child(i) as MeshInstance3D
		var f := fmod(T * speed + float(i) / n, 1.0)
		var s := r * (0.15 + 0.85 * f)
		c.scale = Vector3(s, 1.0, s)
		var mat := c.get_active_material(0) as StandardMaterial3D
		mat.albedo_color.a = (1.0 - f) * (2.0 * f if flat else 1.0) * a * (1.0 - m)
	visible = m < 0.999
```
Bobbing islands (if you add any): `y = (base + 6·sin(t·sp + ph))·(1−m)`, `rot.y = 0.25·sin(0.06t + ph)`, sp 0.3–0.5 (L8264, L8427).

## Appendix D · Season / pack picks per look (`SEASON` L7867, `SECT_ECO` L7882, `SECT_GROUND` L8112, `ISLE_TOP` L9054)
- ice: winter birches (birchW/W2), cold rocks (rock1W/3W/5), lamp stoneLamp2, no lantern, tint PACK_TINT.ice, tree scale 3.4–5.0, frosted grass + white flowers [9,5,9], island top grass [.86,.90,.92].
- jade: summer oaks/birch, rocks rock1/5/6, lantern lanternC (red), tree 4.2–5.8, flowers [3,5,6,2,10,3] + ferns, island grass [.45,.64,.46].
- gold: autumn birches/oak + maples (red/orange/golden), rocks rockT1/T2/3, lantern lanternB, tree 3.6–5.2, flowers [4,7,8,1,4], island grass [.70,.60,.36].
- phoenix: summer + blossom maples (rose tint), lantern lanternA; earth: autumn ochre oaks + treeOrange, lantern lanternB, no ferns; water: summer birches by the water, lantern lanternC, tint PACK_TINT.lake.
- Procedural tree kinds per look `SECT_TREEKIND` (L6874): ice [0 frost pine, col 4], gold [1 broadleaf, 2], jade [2 bamboo, 5], phoenix [1, 1], earth [1, 7], water [1, 1]. These are the `sectTree(x,y,z,scale,kind,colourIndex)` entries (L7747) planted by 06 (outside range) — in Godot, MultiMesh per (kind, colour).
