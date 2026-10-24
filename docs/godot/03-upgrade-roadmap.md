# 03 · Upgrade roadmap — from placeholder geometry to a high-fidelity cultivation world

This page logs what the port and the analysis of the demo taught us, and turns it into a concrete plan for the next
iterations in Godot + Blender: real forests from the asset libraries, rebuilt sects, finer terrain. Everything here keeps
two things from the demo: **the 青绿 ink look** and **data-driven placement** (the exported masks decide *where*; the
assets decide *what*).

Asset library referenced throughout: [`kk20054/ThreeJS-Stylized-World-Assets`](https://github.com/kk20054/ThreeJS-Stylized-World-Assets)
— 135 Temple GLBs (*Stylized Chinese Lost Temple*) + 381 Meadow glTF variants (*Meadow Environment 1.6*), metres, +Y up.

---

## 0. Findings that shape the plan

| finding | consequence |
|---|---|
| **47 % of the 1 415 963 trees are pines** (kind 0), 41 % broadleaf, 3.7 % bamboo, 3 % 黄山松, 2.5 % blossom, 1.8 % willow, 1.2 % reeds (measured from `trees.bin`) | the Meadow library has **birch and oak only** — no conifer, bamboo, willow, blossom or reed. Conifers are the single biggest asset gap. |
| The demo's trees are **diorama-sized**: median scale 1.24 × ~22 = **27 丈** high. The asset pack is placed at **10 丈 per metre** (PACK_M), so a Meadow birch (9.5 m) would be 95 丈, an oak (13 m) 130 丈. | Either scale library trees to ~0.3–0.6 (keeps the miniature, painted read from 1650 丈) or keep them real-size and lower the density ×4–8. Decide per biome; see §1.3. |
| Meadow trees are **4 k–17 k triangles** each (birch 4–10 k, oak 13–17 k). 1.4 M × 6 k = 8 billion. The demo's 5 248 pack instances alone were already **5.8 M triangles**. | Only a ring around the camera can be real meshes. Beyond it: impostors, then the stylised low-poly kinds, then nothing (the demo's own density curve). |
| The demo already has **seasons**: a winter country round 古剑门/云梦山 (6 % of pines), an autumn country round 百巧院 (10 % of pines, 13 % of 黄山松) — `season.png` | Meadow ships **Summer / Autumn / Winter material variants** of every tree and bush: pick the variant from `season.png` per tree. |
| The demo paints the ground with **5 tiles** (grass, dry, snow, cliff, mud) at 150 丈 per tile; Meadow ships **6 terrain layers** (Grass, DryGrass, Mud, MudSnow, Snow, Cliffs) with normal + mask maps | a direct 1 : 1 upgrade of the ground's detail, splatted by biome / season / slope (§3.2). |
| Zoning: **59 % sea, 29 % meadow (草甸), 6 % broadleaf wood, 0.9 % conifer wood**, the rest small (bamboo, flower seas, marsh, farmland, towns, cliffs) — `meta.json → biome.stats` | meadow ground cover (grass/flowers) is the largest visible surface after water — worth GPU scatter (§1.5). |
| The sects are **procedural FacetBuf kits** (~45 k triangles each) with a flat colour per face and ink on chosen edges; the Temple pack is a **metric modular kit** (2 m walls, 3×5 roofs, 5×5 foundations, red stairs, doors, lattices, bells, lanterns) | rebuild each sect hall-for-hall from the build sheets in [05](../05-sects-architecture-cities.md) §2, placed on the exported sect ground (§2). |
| Colour maths in the demo is **display-space**; Godot's Compatibility renderer does not convert the output, Forward+ does (`OUTPUT_IS_SRGB`) | keep the `ALBEDO = OUTPUT_IS_SRGB ? col : to_linear(col)` ending in every new shader; convert Blender's linear colours with `to_srgb` when baking vertex colours (`bake_ink_layout.py` does). |
| Barycentric ink needs **unshared triangle corners**; Godot's importer and auto-LOD weld/collapse them | for the hero assets use `bake_ink_layout.py` + load with GLTFDocument (or import with LODs off); for foliage rely on the **depth ink-edge pass** (`post_ink.gdshader`) instead. |

---

## 1. Forests that feel like real forests

### 1.1 Species table — (demo kind × colour slot × season) → library asset

`trees.bin` gives every tree its **kind** (shape) and **colour slot**; `season.png` gives winter/autumn. Map them to
species lists (weights in brackets). ✗ = no asset in the library yet.

| demo kind / slot | count | summer | autumn | winter | gap & proposal |
|---|---:|---|---|---|---|
| 0 pine / `pine` | 659 908 | ✗ | ✗ | ✗ | **model 3–4 stylised pines in Blender** (Meadow bark + needle cards, same palette `#4e6d60`); or license a stylised conifer pack. Highest priority. |
| 0 pine / `frostpine` | 6 618 | — | — | ✗ (snowy pine) | same pines with a snow-cap material (the demo's frost pine gets snow on up-facing facets) |
| 1 broadleaf / `green`, `young` | 560 925 | `MEADOW_SM_OakTree_01–07` (0.5), `MEADOW_SM_BirchTree_01–07` (0.3), `MEADOW_SM_BirchBush_01–05` (0.2, edges of woods) | `…__P_…_Autumn` variants | `…__P_…_Winter` variants | ✔ ready |
| 1 broadleaf / `maple`, `autumn` | 8 917 | Temple `SM_RedLeaves`, birch Autumn | birch/oak Autumn | Winter | ✔ |
| 2 tall / `bamboo` | 51 746 | ✗ | ✗ | ✗ | model a bamboo clump (instanced culms + leaf cards) — 竹林 near 落云宗 |
| 3 黄山松 / `pine`, `cypress` | 43 089 | ✗ | ✗ | ✗ | one or two hero 迎客松-style pines on cliffs (Blender, hand-made; few instances so they can be detailed) |
| 4 willow / `willow` | 25 379 | ✗ | ✗ | ✗ | weeping willow (Blender curve-hair or card skirt) along rivers and the 韵州城 causeways |
| 5 blossom / `peach`, `pear` | 35 424 | ✗ (tint `MEADOW_SM_BirchTree_*` pink/white as a stop-gap) | — | — | blossom trees near villages and 落云宗 |
| 6 spirit / `spirit` | 125 | — | — | — | hero assets: glowing jade crowns (keep the demo's glow term) |
| 7 lotus | 1 242 | Temple `SM_LilyPad`, `SM_Water_Lilies(_B/_C)`, `SM_LotusStatue` (ponds) | | | ✔ |
| 8 reeds | 16 408 | Meadow `Grass_02_*`/`Plants` stretched, or Blender reed cards | | | small gap |

Shrub layer and edges of woods: `MEADOW_SM_BirchBush_*`, Temple `SM_Bush_01–04`. Forest floor: Meadow `Mushrooms`, `Leaves`,
`Rocks` (`RockGroup_*`), logs/stumps (already in the demo's pack: `log1`, `stump1`, `mush*`).

### 1.2 How to wire it in Godot

1. **`ForestSpawner`** (replace `trees.gd`'s mesh choice): for every tree record pick a species from the table with a
   hash of its position (stable across runs), the season variant from `season.png`, keep yaw and scale.
2. Bucket by **(2600-丈 chunk × species × LOD)** into MultiMeshes (the current code already buckets by chunk × kind and
   writes the buffer in one go — extend the key).
3. **Three rings** with `visibility_range_*` per MultiMeshInstance3D:

   | ring | distance | what |
   |---|---|---|
   | near | 0 – 1 500 丈 | the library mesh, LOD0/LOD1 (Blender Decimate to ~30 %, keep the silhouette) |
   | mid | 1 500 – 8 000 丈 | **octahedral impostors** baked from each species (8×8 views, albedo + normal) |
   | far | 8 000 – 16 000 丈 | the current low-poly kinds (`tree_kit.gd`), coloured by slot — cheap and on-style from altitude |

   Keep the demo's thinning (`k = (1400/A)^1.35`, `kd = (1.25A/d)²`) — at 1650 丈 the camera never needs all 1.4 M.
4. **Shading**: keep `tree.gdshader`'s *idea* (flat tones from sphere normals, sunlit rim, haze) but sample the library's
   albedo texture: `base = texture(albedo, UV).rgb * slot_tint`. Set custom normals in Blender to point away from the
   crown centre (Normal Edit modifier, radial) so a whole crown shades as one painted mass — the trick that makes the demo's
   low-poly trees read as 写意 rather than as polygon soup. Wind: the demo's sway formula in `vertex()`, weighted by height
   (or the Meadow vertex-colour wind mask if present).
5. **Ink**: foliage gets its outline from `post_ink` (depth edges); optionally an inverted-hull pass on the near ring only.

### 1.3 Scale and density per biome

| biome | demo density | proposal |
|---|---|---|
| 阔叶林 broadleaf wood (6.1 %) | dense clusters, edges sparse | real-size oaks/birches ×0.6, density ×0.4, bushes on the margins (distance-to-edge from `ground.png` R) |
| 针叶林 conifer wood (0.9 %) + mountain pines | scattered on slopes | stylised pines ×0.5, keep the demo's slope placement |
| 草甸 meadow (28.7 %) | lone trees + plant cards | real oaks as landmark trees (×1.0, a few per km²), grass/flower scatter (§1.5) |
| 竹林 bamboo (0.2 %) | dense | bamboo clumps, cluster by noise |
| 村镇 / 农田 | orchards, willows by water | blossom + willow, fences (`fence*` already in the pack) |

### 1.4 Clustering (the "real forest" look)

The demo places trees densely in the middle of a wood and sparsely at its edge, with clearings. When re-placing with
bigger assets: use the woods mask (`ground.png` R) blurred twice → `inner = smoothstep(.5,.9)`, `edge = band`; inner gets
big trees + understorey, edge gets bushes and young trees, clearings (noise < 0.2) get grass + rocks + a log. Rotate the
species per cluster (one oak grove, one birch grove) instead of per tree — real woods are patchy.

### 1.5 Ground cover

The demo scatters 1.77 M impostor cards (443 k meadow/verge). In Godot: a **camera-centred scatter** — a grid of
MultiMeshes (e.g. 16 × 16 cells of 50 丈) that re-fills as the camera moves, sampling `biome_weights.png`
(R flowers → `MEADOW_SM_Flower_*`, A lushness → grass density) and `ground.png` (no grass on yards/fields). Grass
`MEADOW_SM_Grass_0x_0y` (16–108 tris) and `CoverPlant_*` (40–52 tris) are cheap enough for ~100 k instances near the camera.
Fade by distance into the ground shader's flower dabs (the demo's `flowerField`, still to port).

---

## 2. Rebuilding the sects

Per sect the docs already have a **build sheet** ([05](../05-sects-architecture-cities.md) §2: structures, sizes in 丈,
relative placement, looks, animated parts, lights). The workflow:

1. `blender --python tools/blender/import_world.py -- --sect luoyun --out luoyun.blend` — the sect's 13.3-丈 ground, the
   current procedural halls (as reference, in place), trees, places and paths, at **0.1 BU per 丈 = the Temple kit's
   native metres**. Model on top of the reference, delete it when done.
2. Build halls from the Temple modules: `SM_Foundation1_5x5` / `_C_` / `_D_` (须弥座 plinths), `SM_Wall2x2`, `SM_Wall3x3`,
   `SM_KingsTempleWall2x2*`, `SM_BigWall_WoodWindow*`, `SM_Lattice`, `SM_Door1/2`, `SM_Roof3x5`, `SM_Temple_BigRoof`,
   `SM_BigRoof(_Wave/_Angle)`, `SM_SmallRoof*`, `SM_RedStairs`, `SM_Stairs`, `SM_Bell_B`, lanterns, banners, `SM_Bridge(_02)`,
   pillars (`models/Pillar`). Keep each sect's **look** (ice / jade / gold / phoenix / earth / water palettes, doc 05 §1.2)
   with material variants or a per-object tint.
3. Bring the demo's xianxia set-pieces as **shaders and scripts**, not meshes: the 护山大阵 dome (doc 05 §3.1 has the GLSL
   and a Godot translation), spirit lights (GPUParticles3D, §3.2), light columns and pulse rings (§3.3–3.5), the
   animated parts (spinners, bobbing islands, boats — doc 05 §4 + Appendix C GDScript sketches).
4. Export the sect as one glTF (`sect_luoyun.glb`), run `bake_ink_layout.py` first if you want the crisp facet ink on
   architecture, and drop it into `godot/data/world/meshes/` — `props.gd` loads it in place of the procedural one.
   Floating islands: model the rock undersides in Blender (the demo's tapered rings are in doc 04 §2).
5. Budget: a hero sect can afford 300–800 k triangles if the rest of the world uses visibility ranges; merge static
   modules per building, keep LOD1 at ~30 % with `visibility_range_end ≈ 4 000 丈`.

Cities (封日城, 韵州城): the same kit for gate towers, walls (`SM_BigWall_*`), houses; streets and wards from doc 05 §2.9.

---

## 3. Terrain

1. **Resolution.** The world heightfield is 40 丈 (≈ 133 m) per cell, the sect patches 13.3 丈. For flying low over real
   forests, re-derive a 5–10 丈 field: either run the drainage model (doc 03 has a numpy port) at higher resolution
   seeded from `height.png`, or take `height.png` into Gaea / World Machine / Blender's geometry nodes for erosion and add
   detail only below the sect patches. Keep the big forms (they are the map's geography).
2. **Ground textures.** Splat the six Meadow terrain layers in `terrain.gdshader`: Grass (草甸, 谷地), DryGrass (autumn +
   steppe: `season.png` G/A), Snow + MudSnow (winter: `season.png` R, flat_k), Mud (marsh, roads, yards: `biome_weights` B,
   `ground.png` B), Cliffs (slope > ~35°, **triplanar** to avoid stretching). Use them as luminance/detail over the demo's
   painted colour (the demo does exactly this with its 5 tiles: luminance relative to the mean, ×2.6, 22–42 % hue transfer)
   so the painting stays in charge.
3. **Earth banks 土崖 and shores.** Port `buildBanks` (marching squares on `water_sd.png`, doc 04 §2.6) instead of the
   current dive, and dress sea cliffs with Meadow `SM_Rock_01–07` scaled ×20–60.
4. **Horizon.** `MEADOW_SM_Mountain_01–04` / `Hill_01–02` (800 m / 500 m, 9–14 k tris) as distant ranges outside the world
   rect, tinted into the haze — the demo fades to mist there.
5. **Roads and rivers in 3D.** `paths.json` has every road/river/stream polyline: build ribbon meshes (doc 04 §5.7) or
   Path3D + a custom extruder; stone bridges where `bridges` says (Temple `SM_Bridge`).

## 4. Water, sky and life (the ✗ rows of the port)

In order of visual payoff: card clouds and the near-camera fly-through (doc 06 §1) → god rays + cirrus (§3) → mirror water
under the sects (doc 04 §4.2) and upland lakes → waterfalls and cloud falls → cranes, NPC flyers (§9) → walkers, carts,
boats, deer (§10). All have full GLSL and parameters in the docs.

## 5. A cultivator to fly

The demo has a procedural figure (doc 06 §6: proportions, joint targets per state hover / 御空 / 遁光, verlet ribbons).
In Blender: a low-poly robed figure with a simple armature (lean, shoulders, elbows) + two sash bones chains; in Godot an
`AnimationTree` blend space driven by speed and boost, the ribbons as a `SpringBoneSimulator3D` (Godot 4.4+) or the demo's
verlet chain in GDScript. Fade it into the 遁光 while boosting as the demo does (`dunK`).

## 6. Performance budget (target: 60 fps at 1440p on a mid GPU)

| layer | budget |
|---|---|
| terrain | ≤ 1.5 M tris on screen (4 LODs already) |
| near forest ring | ≤ 3 M tris, ≤ 300 draw calls (MultiMesh per species × chunk) |
| impostor ring | ≤ 200 k quads |
| ground cover | ≤ 100 k instances, 2–3 MultiMeshes per cell |
| hero sect in view | ≤ 1 M tris |
| post | ink edge + one blur pass; tilt-shift from mips (current) |

Auto-quality (`main.gd`) lowers `scaling_3d_scale` by ×0.8 below 48 fps; add a second step that halves the near-ring radius.

## 7. Suggested milestones

1. **Forest v1** — pines + bamboo + willow modelled; species table + seasons in `ForestSpawner`; near ring real meshes,
   far ring low-poly. Fly over the 云梦 woods.
2. **Ground v1** — Meadow terrain layers splatted; camera-centred grass/flower scatter.
3. **落云宗 v1** — the first sect rebuilt from the Temple kit on its exported ground, with its dome, lights and spinners.
4. Impostor ring; the other five sects; banks and shores; 3D roads and rivers.
5. Clouds and sky (cards, god rays, cirrus), mirror water.
6. The cultivator figure; life (flyers, cranes, boats).

## 8. Smaller ideas logged along the way

- The 舆图 overlay is a raster (the demo paints 2048 px; the port 4096). For crisp roads at every zoom, draw roads and
  rivers as **signed-distance lines in `map2d.gdshader`** from a segment texture, or as Line2D-like meshes on the map plane.
- `hotspots.json` lets you re-pin places without code — keep that contract in Godot (`places.json` is already data).
- The debug panel's **pick mode** (click → base-map pixel → hotspot JSON) is worth porting for level design.
- The intro reveal (`intro_mix`) is a simplified port; the demo's three colour seeds with wet fronts (doc 04 §1.9) give a
  much richer 先勾后染 — port it once the world is final.
- The demo's places carry **long lore texts** (`body`, `note`, `lead`) — reuse them for quest/codex screens.
- `tools/export-world` can export the demo's 1.77 M Meadow ground cards too (`--eco`), if you want to reuse its exact
  flower placement.
- Watch float precision: the world spans 131 800 丈 from an origin near 落云宗; Godot single-precision is fine at 0.1 BU
  per 丈 in Blender and 1 unit per 丈 in Godot (≈ 0.008 丈 resolution at the far edge). If you go to metres at full
  scale (×3.33), consider a floating origin or Godot's double-precision build.
