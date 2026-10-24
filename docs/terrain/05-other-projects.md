# 05 · How other projects do it — and what we took

A condensed version of the survey in [research/r1_tools_projects.md](research/r1_tools_projects.md) (which has the
versions, licences, sources and source tags). Verified-page facts are marked there with [V]; treat everything else as a
lead to check.

## 1. The pattern every large world converges on

1. **A physics-based heightfield for the macro landform** — uplift + stream-power erosion + hillslope diffusion, drainage
   to base level. Academic: Cordonnier et al. 2016 (tectonic uplift + fluvial erosion), Schott et al. 2023 (the same model,
   interactive on the GPU — [StreamPowerErosion](https://github.com/H-Schott/StreamPowerErosion), MIT), Génevaux et al.
   2013 (rivers first). Tools: World Machine, Gaea, World Creator, Houdini heightfields all centre on erosion nodes.
   **Ours**: the demo already had it (03a); `tools/terrain` keeps it and adds per-rock K and critical slopes.
2. **Rock layers decide the forms** — Cordonnier et al. 2018 *Sculpting Mountains* (subsurface geology drives erosion);
   Houdini's *stratify* / Gaea's *Stratify*, *Terraces*; SoilMachine's layer stacks
   ([weigert/SoilMachine](https://github.com/weigert/SoilMachine)). **Ours**: the lithology plan, fold-belt beds with dip
   (K depends on the bed at the current height), the per-rock operators.
3. **Masks from the terrain drive everything after** — flow, slope, curvature, wear/deposit, height bands (the standard
   Gaea / World Machine / Houdini outputs). **Ours**: drainage area, the pillar stage, karst form, redness, glacier
   layers; the biome rules of 03d already work this way.
4. **Vertical features are meshes on a heightfield.** Talks and breakdowns of large worlds (The Witcher 3 GDC 2014,
   Horizon Zero Dawn's GPU placement GDC 2017 — the two the survey could confirm; Far Cry 5's Houdini pipeline, Ghost of
   Tsushima, Genshin's Liyue pillars from memory) all keep cliffs, pillars and arches as modular rock meshes placed by
   rules. **Ours**: `rocks.bin` + the Godot rock kit (`godot/scripts/world/rock_kit.gd`, `rocks.gd`).
5. **Scatter offline, deterministically, from the same masks** (HZD's density logic; ProtonScatter / Spatial Gardener
   for hand touch-ups). **Ours**: the demo's `planTrees` already does; trees re-seat on the new heights automatically
   (`trees.bin` has no y).

## 2. Godot

| project | what | fit for us |
|---|---|---|
| [Terrain3D](https://github.com/TokisanGames/Terrain3D) (MIT) | clipmap terrain, regions (64–2048), `vertex_spacing`, 32-texture control map, holes, instancer; v1.0.2 for Godot 4.4–4.7 | adopt only for in-editor sculpting/painting. Our map spans ~440 km: plan a **floating origin** (jitter beyond ~10–40 km in single precision — its own docs) and import with `Terrain3DData.import_images` (16-bit PNGs read as 8-bit in Godot — use EXR/R16) |
| [HTerrain](https://github.com/Zylann/godot_heightmap_plugin) | heightmap terrain; Godot 4.6+, bug fixes only | no |
| [MTerrain](https://github.com/mohsenph69/Godot-MTerrain-plugin) | large terrain, ~16 km limit | no |
| [godot_voxel](https://github.com/Zylann/godot_voxel) (MIT) | Transvoxel / SDF voxels | only for hero caves (灵眼之树's cavern) |
| [ProtonScatter](https://github.com/HungryProton/scatter), [Spatial Gardener](https://github.com/dreadpon/godot_spatial_gardener) (MIT) | rule / brush scattering | touch-ups inside sect patches |
| GPU erosion | no maintained library — proofs of concept only (e.g. compute-shader experiments) | not needed: our solve is offline |

**Decision**: keep the port's own GPU-displaced chunk terrain (it matches the demo's look and runs on 4.7.1); feed it the
sculpted heights with `--terrain=…` ([04](04-tools.md) §6).

## 3. Blender

- [A.N.T. Landscape](https://extensions.blender.org/add-ons/antlandscape) (extension, Blender 4.2+): noise terrain with a
  simple eroder — fine for props, not for a 132 000-丈 world.
- [BlenderGIS](https://github.com/domlysz/BlenderGIS) (GPL-3): real DEMs (SRTM 30/90 m through OpenTopography, API key) —
  the way to bring **reference stamps** of Zhangjiajie, Guilin, Danxiashan… into a scene ([r1 §F](research/r1_tools_projects.md)
  lists the coordinates).
- Baking heights back: read grid vertices directly (exact), ray-cast with `mathutils.bvhtree` after topology changes, or
  render an orthographic Position-Z pass to a 32-bit EXR. **Ours**: `tools/blender/terrain_edit.py` /
  `terrain_bake.py` do the first two.

## 4. Offline libraries and techniques worth borrowing

| project | technique | how we would use it |
|---|---|---|
| [fastscapelib](https://github.com/fastscape-lem/fastscapelib) 0.3 (GPL-3) | `SPLEroder`, `DiffusionADIEroder`, `MultiFlowRouter`, **`MSTSinkResolver`** (keeps lakes instead of filling them) | a drop-in replacement for `xyterrain/flow.py` offline (GPL is fine for a tool that is not shipped); MST sinks would let karst dolines and the 绿踪 basin stay closed |
| [Landlab](https://github.com/landlab/landlab) 2.11 (MIT) | landscape-evolution components (flexure, lithology, glaciers…) | experiments with more processes |
| [Schott MultiScaleErosion](https://github.com/H-Schott/MultiScaleErosion) (MIT) | multi-scale erosion amplification | upsample sect surroundings to 10–20 丈 tiles |
| runevision's erosion filter ([blog, Mar 2026](https://blog.runevision.com/2026/03/); Bevy crate [bevy_erosion_filter](https://docs.rs/bevy_erosion_filter); a Godot port is reported) | per-point erosion-like detail | far detail in the terrain shader without more data |
| [mapgen4](https://github.com/redblobgames/mapgen4), [Azgaar FMG](https://github.com/Azgaar/Fantasy-Map-Generator), [mewo2/terrain](https://github.com/mewo2/terrain) | map-scale generators (rivers from elevation, painted elevation) | ideas for a painted-uplift editor |
| [SimpleHydrology](https://github.com/weigert/SimpleHydrology), [Sebastian Lague's Hydraulic-Erosion](https://github.com/SebLague/Hydraulic-Erosion), [terrain-erosion-3-ways](https://github.com/dandrino/terrain-erosion-3-ways) | particle / grid hydraulic erosion | fine gullies on 10–20-丈 tiles |
| [aparis69](https://github.com/aparis69): Karst-Synthesis, Rock-fracturing, Implicit-Volumetric-Terrains, Desertscapes | cave networks, fractured blocks, arches & overhangs as SDFs | the rock kit: SDF pillars with joint sets and bedding notches → GLB variants |
| [oargudo](https://github.com/oargudo): orometry-terrains, terrain-descriptors, glaciers | peak prominence / isolation statistics; glacier simulation | validation: compare our zones with real DEM stamps |
| [mgaillard/Noise](https://github.com/mgaillard/Noise) (Dendry) | dendritic patterns | loess gully networks |

## 5. What to do next, in order

1. **Validate against real land.** Pull Copernicus GLO-30 tiles (free, attribution) for the reference sites, compute
   slope / drainage / prominence histograms (terrain-descriptors), and tune each operator until our zone's statistics sit
   in the real range — stamps as statistical targets, not 1:1 at 40 丈.
2. **A procedural rock kit in Blender** (SDF → mesh → decimate → GLB variants, 10–30 per landform, impostors far away)
   to replace the GDScript prisms; keep the facet vertex layout (`tools/blender/bake_ink_layout.py`) for the ink.
3. **Amplify near the camera**: 10–20-丈 tiles round sects and routes (MultiScaleErosion or a numpy port), the erosion
   filter in the shader beyond.
4. **Closed basins**: MST sink resolution so karst dolines, tiankeng and 绿踪 keep their water.
5. **Collision for the rock instances** (a flying game needs it; Terrain3D's instancer has none).
