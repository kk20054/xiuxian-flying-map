> **Research dossier** (appendix to [docs/terrain](../README.md)). Compiled with limited web access: most page
> contents and numbers come from search-engine extracts of the linked pages, and every item carries its source tag
> ([V] page opened, [S#]/[N]/[H]/[W]/[F]/[D] source kinds, "(unverified — from memory)", "(derived)"). Check a page
> before relying on a single number or quote.

# R1: How other projects, tools and papers author large stylized terrain with geological logic

Survey compiled 2026-10-24 for the xiuxian-flying-map terrain pipeline (Godot 4.7.1 port, Blender 5.x / bpy, offline
Python/numpy). The repo itself was not modified.

## How to read the sources (important)

Web access was **partly restricted** in this session:

- **WebFetch** could open only `github.com`, `raw.githubusercontent.com` and (via curl) `pypi.org`. Every other host
  failed DNS or was refused by the egress proxy: readthedocs, blender.org, sidefx.com, quadspinner.com, Wikipedia,
  arXiv, doi.org, HAL, github.io, itch.io and GDC Vault.
- **WebSearch** worked until the shared per-turn budget ran out partway through (sections D and E were affected most).
  Claims sourced from search are marked **[S]**. That means the link appeared in a search result and the claim comes from
  that result's snippet or summary; I did not read the page itself.
- **[V]** means I opened and read the page (GitHub, raw GitHub or the PyPI JSON API).
- **(unverified — from memory)** means I could not check it this session. Treat these as leads, not facts. I left out
  URLs I could not verify instead of guessing them.

GitHub release pages show dates without a year. Where I give a year next to a GitHub release, I worked it out from the
Godot versions the release supports, and I mark it "(year inferred)".

---

## 0. Our scale, for context (derived from the brief, not from sources)

| quantity | value | metres (1 丈 ≈ 3.33 m) |
|---|---|---|
| world | 132,000 × 80,000 丈 | ≈ 440 × 266 km |
| heightfield cell | 40 丈 (3296 × 2005 samples) | ≈ 133 m |
| max height | ~1,300 丈 | ≈ 4.3 km |
| smallest feature a heightfield can carry well (≈ 3 cells) | ~120 丈 | ≈ 400 m |

What follows from this: anything narrower than about 100–150 丈, or steeper than about 60–70° across a cell, cannot live
in the 40-丈 heightfield. That includes Zhangjiajie quartz-sandstone pillars, Shilin limestone columns, Huangshan granite
spires, sheer Danxia walls and the overhangs of tiankeng rims. These have to be **meshes or SDF solids placed on top of
the heightfield**, or the heightfield has to be amplified locally to 5–20 丈. Every game in section E solves the problem
this way.

---

## A. Godot terrain and scattering

### A.1 Terrain3D (TokisanGames)

| item | finding | source |
|---|---|---|
| Licence | MIT | [V] [repo](https://github.com/TokisanGames/Terrain3D) |
| Stable release | **v1.0.2-stable**, 19 May (2026, year inferred): "Supports Godot 4.4-4.7. Use 1.0.0 for 4.3." This covers our 4.7.1. | [V] [release](https://github.com/TokisanGames/Terrain3D/releases/tag/v1.0.2-stable) |
| Next release | **v1.1.0-rc1**, 17 Oct (2026, year inferred): "Supports Godot 4.5-4.8+". Adds C# bindings, an ocean mesh, height displacement from textures with tessellation, AO, slope colourizer, contour shader and a compressed colour map. Instancer MMIs are now RenderingServer resources instead of nodes. API changes are listed in a "1.1 API Changes" discussion I did not open. | [V] [release](https://github.com/TokisanGames/Terrain3D/releases/tag/v1.1.0-rc1) |
| Older releases | v1.0.0-stable (Godot 4.3–4.4), v1.0.1-stable (4.4+) | [V] [releases](https://github.com/TokisanGames/Terrain3D/releases) |
| World size | "supports terrains from 64x64m up to 65.5x65.5km" at `vertex_spacing` 1. `vertex_spacing` defaults to 1.0 and is "settable up to 100". Per the double-precision doc it can "expand this up to 100x". | [V] [class_terrain3d.rst](https://raw.githubusercontent.com/TokisanGames/Terrain3D/main/doc/api/class_terrain3d.rst), [V] [double_precision.md](https://raw.githubusercontent.com/TokisanGames/Terrain3D/main/doc/docs/double_precision.md) |
| Regions | `REGION_MAP_SIZE = 32` gives a 32 × 32 grid of 1024 regions, region locations (−16,−16)…(15,15). `region_size` options are 64, 128, 256 (default), 512, 1024 and 2048. A region is that many vertices and pixels per side. Regions can be sparse. | [V] [class_terrain3ddata.rst](https://raw.githubusercontent.com/TokisanGames/Terrain3D/main/doc/api/class_terrain3ddata.rst), [V] [class_terrain3d.rst](https://raw.githubusercontent.com/TokisanGames/Terrain3D/main/doc/api/class_terrain3d.rst) |
| Mesh | Geometry clipmap. `mesh_lods` defaults to 7. `mesh_size` defaults to 48, and LOD0 has 4·mesh_size+2 quads per side. The vertex shader displaces by the heightmap. | [V] same, [V] [system_architecture.md](https://raw.githubusercontent.com/TokisanGames/Terrain3D/main/doc/docs/system_architecture.md) |
| Precision | Single-precision builds "start to show jitter and rendering corruption" at roughly **10k–40k m from origin**. Double precision is supported, but Godot, godot-cpp and Terrain3D must all be built from source with `precision=double`. | [V] [double_precision.md](https://raw.githubusercontent.com/TokisanGames/Terrain3D/main/doc/docs/double_precision.md) |
| Import formats | **EXR** (recommended; real heights, 16/32-bit float, RGB), **R16** (normalized 0–65535, with min/max and size kept outside the file; `.raw` is read as r16), and HTerrain `.res`. **PNG is effectively unusable** because Godot reads it as 8-bit. | [V] [import_export.md](https://raw.githubusercontent.com/TokisanGames/Terrain3D/main/doc/docs/import_export.md) |
| Importer tool | `addons/terrain_3d/tools/importer.tscn` takes `import_position` (rounded to `region_size`), `height_offset` and `import_scale`. Region size must be larger than image width / 32. | [V] same |
| Script API (current main) | `Terrain3DData.import_images(images: Array[Image], global_position: Vector3 = Vector3(0,0,0), offset: float = 0.0, scale: float = 1.0)`. `images` is a TYPE_MAX-sized array of **Height, Control, Color**, and entries "can be blank or null". It "does NOT normalize values". Also `export_image(file_name, map_type, mode)` with r16/raw, exr, png, webp, res and tres; `get_height`/`set_height`/`get_surface_height` (NAN in holes); `add_region_blank(p)`; `get_maps`; `layered_to_image` (max 16384²); `update_maps`; `calc_height_range`. The ordering of offset and scale is inconsistent across the docs: the API doc says scale is applied after offset, the importer doc says scale first. Test both. | [V] [class_terrain3ddata.rst](https://raw.githubusercontent.com/TokisanGames/Terrain3D/main/doc/api/class_terrain3ddata.rst) |
| Control map | One 32-bit uint per pixel. **Base texture id** bits 32–28 (0–31), **overlay id** 27–23, **blend** 22–15 (0–255), UV angle 14–11, UV scale 10–8, reserved 7–4, **hole** bit 3, **navigation** bit 2, **autoshader** bit 1. That allows 32 textures. Exported as EXR and only reimportable through the tool. | [V] [controlmap_format.md](https://raw.githubusercontent.com/TokisanGames/Terrain3D/main/doc/docs/controlmap_format.md) |
| Holes | Hole bit in the control map. `get_surface_height` returns NAN there. | [V] as above |
| Foliage instancer | Transforms are stored in region files. Each region is split into **32 × 32 m cells, one MultiMesh per cell**. Up to 10 LODs (4 recommended), switched per cell. `shadow_impostor` and `last_shadow_lod`. **No collision**. Single mesh and single material override only. Scene transforms are ignored. No wind (bring your own shader). Script API: `add_transforms()` and `add_multimesh()`. | [V] [instancer.md](https://raw.githubusercontent.com/TokisanGames/Terrain3D/main/doc/docs/instancer.md) |
| Displacement | Tessellation Level 0–6 around the camera, using height-packed textures. Per the doc, at Displacement Scale 1.0 vertices move at most about ±0.5 m from the collision mesh. The doc recommends Vertex Spacing 1.0. | [V] [displacement.md](https://raw.githubusercontent.com/TokisanGames/Terrain3D/main/doc/docs/displacement.md) |
| Heightmap tools it recommends | wgen (Rust, MIT, 16-bit png/exr), HTerrain, Gaea/World Machine/World Creator/Houdini/Instant Terra (heightmaps only, "Control maps need a custom converter"), Copernicus DEM, VTBuilder, TouchTerrain | [V] [heightmaps.md](https://github.com/TokisanGames/Terrain3D/blob/main/doc/docs/heightmaps.md) |
| Third-party bridge | World Creator 2025.3 added a Godot bridge that **uses Terrain3D** to display terrain. It syncs terrain only, objects are not supported yet, and layer blends look sharper in Godot. | [S] [WC Godot bridge docs](https://docs.world-creator.com/reference/export/bridge-tools/godot-bridge), [S] [digitalproduction](https://digitalproduction.com/2025/11/28/world-creator-2025-3-adds-orbx-godot-bridge-and-caves/) |

**How our world would fit (derived).** At `vertex_spacing = 40` (1 unit = 1 丈), the 3296-px-wide map needs
`region_size ≥ 128` (3296/32 ≈ 103). 32 regions × 128 × 40 = 163,840 丈, which covers 132,000 丈. If we amplify to
20 丈 (6592 × 4010 px), we need `region_size ≥ 256`. The world's edges sit about 66,000 丈 from its centre, which is past
Terrain3D's single-precision jitter threshold. We would need a floating origin, a double-precision build, or acceptance
of some jitter at the map edges.

### A.2 Other Godot terrain, voxel and scatter add-ons

| project | status / versions | licence | notes | source |
|---|---|---|---|---|
| **HTerrain** (Zylann `godot_heightmap_plugin`) | README: "Heightmap-based terrain for Godot 4.6+". The author says it is "not in "active" development" and he does "only bug fixes these days". Pure GDScript. | MIT | Resolution must be 2ⁿ+1 (513…4097). RAW 16/32-bit uint import (PNG is 8-bit). Generator with Perlin noise plus morphological erosion/dilation and experimental slope-direction erosion over shader passes. Holes are visual only (the collider is unaffected). `HTerrainDetailLayer` grass. | [V] [repo](https://github.com/Zylann/godot_heightmap_plugin), [V] [LICENSE](https://raw.githubusercontent.com/Zylann/godot_heightmap_plugin/master/LICENSE.md), [V] [docs index](https://raw.githubusercontent.com/Zylann/godot_heightmap_plugin/master/addons/zylann.hterrain/doc/docs/index.md) |
| **MTerrain** (mohsenph69) | Latest v0.18.2-alpha (25 Nov, year not shown). v0.16 was "only works with Godot4.3", and v0.17 notes mention a GDExtension build for 4.4.1. | MIT | Octree LOD, "up to 16 km x 16 km". Grass with collision. Navigation painting. Bezier paths with mesh deformation (roads, rivers). Heightmap/splatmap import/export. | [V] [repo](https://github.com/mohsenph69/Godot-MTerrain-plugin), [V] [releases](https://github.com/mohsenph69/Godot-MTerrain-plugin/releases) |
| **godot_voxel** (Zylann) | C++ module, plus a GDExtension that "will work with an official build of Godot (4.4.1 or later)" | MIT | Smooth terrain via **Transvoxel** with LOD, plus blocky meshing. Graph generators are built around **SDF** output. `VoxelGeneratorImage` (heightmap), `VoxelGeneratorNoise` (3-D noise with overhangs) and `VoxelGeneratorGraph`. Supports "overhangs, tunnels". Paged, unbounded worlds. | [V] [repo](https://github.com/Zylann/godot_voxel), [V] [generators.md](https://raw.githubusercontent.com/Zylann/godot_voxel/master/doc/source/generators.md), [V] [getting_the_module.md](https://raw.githubusercontent.com/Zylann/godot_voxel/master/doc/source/getting_the_module.md) |
| **ProtonScatter** (HungryProton `scatter`) | Godot 4 rewrite. The GitHub repo is a mirror and the canonical repo is on Codeberg. GitHub release "4.0" says Godot 4.0–4.2 "at the time of writing". | MIT (the demo textures carry other terms) | Modifier stack. Shapes (box, sphere, path, negative). Project-on-colliders. Arrays. | [V] [repo](https://github.com/HungryProton/scatter), [V] [releases](https://github.com/HungryProton/scatter/releases) |
| **Spatial Gardener** (dreadpon) | v1.4.1-stable for Godot 4.4 (v1.4.0 for 4.3) | MIT | Paints foliage and props on arbitrary 3-D surfaces. Suited to finite, medium-sized scenes. | [V] [repo](https://github.com/dreadpon/godot_spatial_gardener), [V] [releases](https://github.com/dreadpon/godot_spatial_gardener/releases) |
| **Terrainer** (TopScales) | Godot 4, "Efficient GPU-based terrain generation" | ? | Search did not mention erosion | [S] [repo](https://github.com/TopScales/terrainer) |

### A.3 Godot GPU / compute-shader erosion projects

I found no maintained, general-purpose Godot erosion library. What exists:

- **zhfr7/terrain-gen**: Godot (C# project files), an in-editor compute-shader generator using FBM, then hydraulic and
  thermal erosion, with clipmap rendering. MIT. The author calls it a proof of concept from Acerola's Dirt Jam (July 2025)
  with known bugs. It has 1 commit. [V] [repo](https://github.com/zhfr7/terrain-gen)
- **"Erosion simulator" (atif85, itch.io)**: Godot 4 compute shaders, hydraulic and thermal erosion, heatmap view, PNG
  export, inspired by Sebastian Lague. The GitHub link was not visible. [S] [itch page](https://atif85.itch.io/erosion-simulator)
- **SimplexTerrain (Godot Asset Store)**: a node graph with a hydraulic-erosion node, dispatched as Vulkan compute through
  `RenderingDevice`. Store asset, not open source. [S] [store page](https://store.godotengine.org/asset/prajwal-m/simplexterrain/)
- **compute-shader-plus** (DevPoodle): a ComputeHelper wrapper for compute shaders, not an eroder.
  [S] [repo](https://github.com/DevPoodle/compute-shader-plus)
- **"Fast and Gorgeous Erosion Filter" Godot forum thread**: a basic GDScript implementation of runevision's filter
  (see C.3). [S] [forum](https://forum.godotengine.org/t/fast-and-gorgeous-erosion-filter/136436)
- **H-Schott/MultiScaleErosion**: OpenGL 4.3 compute, C++, MIT (see D). It is the most portable reference for a
  `RenderingDevice` port. [V] [repo](https://github.com/H-Schott/MultiScaleErosion)

---

## B. Blender

### B.1 A.N.T. Landscape (now an extension)

- Bundled with Blender up to 4.1. Now an extension, **v0.2.0, Blender 4.2+**, described as "maintained by the community,
  no support expected". Presets were lost when it moved to an extension and later restored. GPL. [S]
  [extension page](https://extensions.blender.org/add-ons/antlandscape), [S]
  [versions](https://extensions.blender.org/add-ons/antlandscape/versions/), [S]
  [project](https://projects.blender.org/extensions/ant_landscape)
- **Landscape Eroder** (`mesh.eroder`, also in Weight Paint ▸ Weights). Options as defined in the legacy add-on source
  [V] [blender-addons mirror, ant_functions.py](https://raw.githubusercontent.com/blender/blender-addons/main/ant_landscape/ant_functions.py).
  The extension may differ slightly (unverified).
  - Iteration counts: `Iterations` (1), `IterRiver` River Iterations (30), `IterAva` Avalanche Iterations (5),
    `IterDiffuse` Diffuse Iterations (5).
  - Rain: `Ef` "Rain on Plains" (0 means more rain on mountain tops), `Kr` rain amount, `Kv` rain variance,
    `userainmap` (the active vertex group is the rain map).
  - Thermal: `Kd` thermal diffusion rate, `Kt` max stable talus angle (60°).
  - Fluvial: `Ks` soil solubility, `Kdep` deposition, `Kz` fluvial erosion rate, `Kc` carrying capacity, `Ka` slope
    dependence ("not used"), `Kev` evaporation.
  - Probabilities: `Pd` diffusion, `Pa` avalanche, `Pw` river.
  - It writes vertex groups you can use as masks.
- In short, it is a small CPU grid eroder that is fine for test tiles and too slow and too simple for a 6.6-M-vertex world.
  It descends from the ErosionR add-on ([V] [nerk987/ErosionR](https://github.com/nerk987/ErosionR)).

### B.2 BlenderGIS (domlysz) for DEM import

- GPL-3.0 [V] [LICENSE](https://raw.githubusercontent.com/domlysz/BlenderGIS/master/LICENSE). README says the minimum is
  Blender 2.83. I did not check 5.x compatibility. [V] [repo](https://github.com/domlysz/BlenderGIS)
- "Get SRTM" / "Get elevation" servers, as found in `prefs.py` [V]
  [prefs.py](https://raw.githubusercontent.com/domlysz/BlenderGIS/master/prefs.py):
  - **"OpenTopography SRTM 30m"** (`globaldem?demtype=SRTMGL1…&API_Key={API_KEY}`)
  - **"OpenTopography SRTM 90m"** (`SRTMGL3`)
  - **"Marine-geo.org GMRT"**
  - The list is stored as JSON in the preferences (`demServerJson`). My inference is that you can add a COP30 or AW3D30
    entry using the same OpenTopography URL pattern (unverified).
- An OpenTopography API key is required, and the code warns that SRTM does not exist beyond 60°N or 56°S. [V]
  [io_get_dem.py](https://raw.githubusercontent.com/domlysz/BlenderGIS/master/operators/io_get_dem.py).
  GeoTIFFs import through "Import DEM grid / Georaster relief". [V] [wiki SRTM](https://github.com/domlysz/BlenderGIS/wiki/SRTM)

### B.3 Geometry-Nodes and other Blender terrain/erosion add-ons

| add-on | type | erosion | licence / price | source |
|---|---|---|---|---|
| **Quick Erosion Filter** (node group) | GN, instant (< 1 s) | runevision's analytic erosion filter (strength, scale, shape, rounding, seed) | free, MPL-2.0 with the author's permission | [S] [BlenderNation 2026-05-05](https://www.blendernation.com/2026/05/05/free-download-quick-erosion-filter/) |
| **Easy Terrain Generator** | GN add-on | added the erosion filter in 3.0 (04-29-26) | paid (Superhive/Gumroad) | [S] [versions](https://superhivemarket.com/products/easy-terrain-generator/versions) |
| **World Blender** | GN landscape generator | "particle-based erosion engine … hydraulic and thermal weathering" (Pro) | paid | [S] [Superhive](https://superhivemarket.com/products/world-blender-2025) |
| **Geoscape Terrain Nodes** | GN library | "procedural and simulated hydraulic erosion, procedural river generation" | $34.99 | [S] [Superhive](https://superhivemarket.com/products/geoscapes) |
| **Terrain Mixer** (Boonika) | GN/Cycles. Free extension plus paid bundles. Pro (alpha) listed for Blender 5.1–5.2. | "Erosion Mixer" (2.10, 2023) blends up to 4 height maps | free / $19–59. Pro GPL $59. | [S] [extension](https://extensions.blender.org/add-ons/terrainmixer/), [S] [Pro FAQ](https://superhivemarket.com/products/terrain-mixer-pro/faq), [S] [CGChannel 2023](https://www.cgchannel.com/?p=150817) |
| **TerraScape** | add-on | procedural erosion, can erode imported heightmaps | $6.99, MIT | [S] [Superhive](https://superhivemarket.com/products/terrascape-procedural-terrain-generator-erosion-tool) |
| **Erosion Add-On** (NM-8) | add-on | flow-based, works on any mesh | $59–79 | [S] [Superhive](https://superhivemarket.com/products/erosion-add-on) |
| **Terrain Erosion – GeoNodes Simulation** | free example .blend | hydraulic erosion in GN simulation (Blender 4.1.1) | free | [S] [Gumroad](https://dnslv.gumroad.com/l/erosionGN) |
| **Realistic Terrain** (TLabAltoh) | add-on, DX11 compute (Windows only, Blender 3.4 / Py 3.10) | Lague-style droplet erosion | LICENSE file present, type not shown | [V] [repo](https://github.com/TLabAltoh/realistic_terrain) |

### B.4 Baking a heightmap back out of Blender

1. **Read grid vertices directly.** If the mesh is still our regular grid (built by `tools/blender/import_world.py`),
   `mesh.vertices.foreach_get("co", arr)` and a reshape give an exact, lossless round-trip. This is the cheapest and best
   option. (Standard bpy API, unverified — from memory.)
2. **BVH ray casting.** `mathutils.bvhtree.BVHTree.FromObject(obj, depsgraph)` evaluates modifiers. Then
   `ray_cast(origin, direction, distance)` returns `(location, normal, index, distance)`, or all `None` on a miss. Origin
   and direction are in **object space**. In Blender 5.0 the optional parameters are keyword-only. [S]
   [API 5.0](https://docs.blender.org/api/5.0/mathutils.bvhtree.html), [S]
   [API 4.5](https://docs.blender.org/api/4.5/mathutils.bvhtree.html).
   Cast straight down per texel. It works for sculpted, non-grid meshes, and it is exact but CPU-bound.
3. **Orthographic top-down render.** Use an emission shader that outputs world Z (Position.z), with the view transform set
   to **Standard** (not AgX or Filmic), output **OpenEXR 32-bit float**, and no lights or tonemapping. Make the camera's
   ortho scale match the tile. Forum guidance warns that colour management corrupts heights.
   [S] [blenderartists](https://blenderartists.org/t/baking-out-height-map-texture-in-2-80-how/1182515),
   [S] [Planetside thread](https://planetside.co.uk/forums/index.php?msg=265653).
   Additional pitfalls: pixel-filter blur (set the filter width to its minimum) and pixel-centre vs pixel-corner alignment
   (unverified — from memory).
4. **Geometry Nodes resample.** Build a grid at the target spacing, use *Raycast* or *Sample Nearest Surface* against the
   sculpt, store Z, and read it back as in method 1 (unverified — from memory).

Always write float heights in 丈 (EXR or raw float32) with a JSON sidecar holding origin, spacing and size. R16 needs
min/max stored outside the file, as Terrain3D's docs note ([V] [import_export.md](https://raw.githubusercontent.com/TokisanGames/Terrain3D/main/doc/docs/import_export.md)).

---

## C. Standalone tools and open source

### C.1 Commercial node-based tools: what is "standard"

| tool | latest found | erosion / geology nodes | licence model | source |
|---|---|---|---|---|
| **Gaea** (QuadSpinner) | **2.3** (CGChannel, 15 Jun 2026): macros and 16K baking. 2.4 and 3.0 were announced and then delayed. | **Erosion_2** runs fully on the GPU with "hydraulic, thermal, and gravitational forces". 2.2 (Jul 2025) added **selective precipitation** (rain limited by mask, slope or altitude) and orographic rain-shadow. Erosion outputs **Wear, Deposits, Flow** maps. Hydro node (lateral/ventral). Water bodies (lakes, rivers, coasts) exported as separate heightfields. | Perpetual. Revenue tiers: Indie < $100k, Pro < $1M, Enterprise. Community edition is free, builds up to 4096² and **exports only up to 1024²** (stated for 2.0.5.3). | [S] [CGChannel 2.3](https://www.cgchannel.com/?p=176494), [S] [Gaea 2.2 blog](https://blog.quadspinner.com/gaea-2-2-released/), [S] [Erosion guide](https://docs.quadspinner.com/Guide/Using-Gaea/Erosion.html), [S] [features](https://quadspinner.com/Gaea/Features), [S] [FAQ](https://quadspinner.com/FAQ), [S] [download](https://quadspinner.com/Download) |
| **World Machine** | **4059 "Dragontail Peak"** (2026): VDM-based "true 3D" terrain, new viewport, native macOS and Linux | Erosion, snow (the snow device was overhauled in the 2018 "Mt. Daniel" release), water | commercial | [S] [CGChannel](https://www.cgchannel.com/tag/build-4058/), [S] [CGPress Mt Daniel](https://cgpress.org/archives/world-machine-mt-daniel-released.html) |
| **World Creator** (BiteTheBytes) | **2026.1** (Jan 2026). 2025.1 added biomes and asset scatter. 2025.3 added hole painting (caves) and the **Godot bridge**. | GPU real-time filters: erosion, sediment, Terrace, Dunes, "Advanced Erosion / Wide Flows" | perpetual $149–1,699, rental $99–1,290/yr (Jan 2026 coverage) | [S] [CGChannel 2026.1](https://www.cgchannel.com/2026/01/bitethebytes-releases-world-creator-2026-1/), [S] [CGChannel 2025.3](https://www.cgchannel.com/2025/11/bitethebytes-releases-world-creator-2025-3/), [S] [Wide Flows doc](https://docs.world-creator.com/reference/terrain/filters/advanced-erosion/wide-flows) |
| **Instant Terra** (Wysilab) | 2.5 (Mar 2022): Road node | hydraulic (1.0); "mountain erosion" weathering (1.5); sediment smoothing and multi-erosion (1.7); **thermal, multi-scale erosion, mountain aging** (2.3, 2021) | commercial | [S] [80.lv 2.3](https://80.lv/articles/instant-terra-2-3-from-wysilab-is-out), [S] [Rebusfarm](https://rebusfarm.net/news/wysilab-released-instant-terra-2-3), [S] [v1.7 notes](https://instantterrapro.wysilab.com/instant-terra-releases/wysilab-releases-v1-7) |
| **Houdini heightfields** (SideFX) | Houdini 21 SOP heightfields. The **Erode SOP was rewritten in 21**. Houdini 22 adds **Copernicus (COP) heightfields**. | **HeightField Erode** produces channels plus layers `sediment`, `debris`, `flow`, `flowdir` (bedrock is the reference for how much was eroded). **Flow fields** produce `flow` and `flowdir`. **Mask by Feature** (slope by default; also height, direction and so on). **Terrace** (height plus mask input). **Slump** (Smooth/Granular with repose angle; the COP version adds Rainfall and a flow output). Erode Hydro and Erode Thermal (since 17.0). Every node takes a mask as its second input. | commercial (an Indie tier exists, unverified) | [S] [erosion](https://www.sidefx.com/docs/houdini/heightfields/erosion.html), [S] [flowfields](https://www.sidefx.com/docs/houdini/heightfields/flowfields.html), [S] [masking](https://www.sidefx.com/docs/houdini/heightfields/masking.html), [S] [slump](https://www.sidefx.com/docs/houdini/heightfields/slump.html), [S] [COP workflows](https://www.sidefx.com/docs/houdini/heightfields_cop/workflows.html) |

**Concepts these tools share** (a synthesis of the rows above; the "standard vocabulary" to copy into our Python
pipeline):

1. **Primitives.** Ridged, billow and cellular noise; mountain, volcano and crater primitives; **DEM stamps**.
2. **Domain warp, distort and "fold/shear"** for tectonic grain.
3. **Strata.** *Terrace* and *Stratify* with a per-layer hardness that feeds erosion. Houdini's Terrace takes a mask.
4. **Erosion family.**
   - Hydraulic: particle or grid based.
   - Fluvial stream-power at large scale.
   - **Thermal/talus** using a repose angle.
   - Sediment deposition and fans.
   - Snow and glacial.
   - "Selective" erosion driven by masks or rain maps (Gaea 2.2, the A.N.T. rain map).
5. **Derived masks.** Height bands, **slope**, **curvature** (convex and concave), **aspect**, **flow accumulation**,
   **wear/deposit/debris/sediment**, occlusion, and distance to water.
6. **Outputs.** Height (R16/EXR), splat or weight masks, water bodies as separate heightfields, flow maps, and scatter
   point sets (World Creator biomes, Houdini scatter).

### C.2 Open-source landscape-evolution libraries (offline Python)

| project | technique | language | licence | maintained? | what we could borrow | source |
|---|---|---|---|---|---|---|
| **fastscapelib** | LEM toolkit. Grids: `RasterGrid`, `TriMesh`, `ProfileGrid`, `HealpixGrid`. `FlowGraph(grid, [SingleFlowRouter() or MultiFlowRouter(slope_exp)], sink resolvers PFloodSinkResolver / MSTSinkResolver)` with `update_routes()` and `accumulate()`. Eroders: **`SPLEroder`** (stream power, any grid), **`DiffusionADIEroder`** (linear hillslope diffusion, raster only), and `FlowKernelEroder` (custom Numba kernels, added in 0.3). Configurable base levels and masks for sea or lakes. | C++ with Python bindings | **GPL-3.0** | **0.3.0 on PyPI, 2025-06-25**. Release notes list v0.4.0 as "Unreleased". | A drop-in, tested replacement for our hand-written priority-flood plus SPL. Gives transient runs, variable K (lithology), hillslope diffusion, **MSTSinkResolver to keep lakes**, and multi-flow masks. GPL is fine for an offline tool whose output we ship (the code is not shipped). | [V] [repo](https://github.com/fastscape-lem/fastscapelib), [V] [guide_flow](https://raw.githubusercontent.com/fastscape-lem/fastscapelib/main/doc/source/guide_flow.md), [V] [eroder API](https://raw.githubusercontent.com/fastscape-lem/fastscapelib/main/doc/source/api_python/eroder.rst), [V] [grid API](https://raw.githubusercontent.com/fastscape-lem/fastscapelib/main/doc/source/api_python/grid.rst), [V] [release notes](https://raw.githubusercontent.com/fastscape-lem/fastscapelib/main/doc/source/release_notes.md), [V] PyPI JSON |
| **fastscape** (xarray-simlab model) | ready-made LEM built on xarray-simlab | Python | BSD-3 | 0.1.0 (2023-09-25) | quick experiments | [V] PyPI JSON (`pypi.org/pypi/fastscape`) |
| **Landlab** | modular Earth-surface process components (flow routing, stream power, diffusion, lithology…) | Python | MIT | **2.11.0, 2026-04-06**, very active | `FlowAccumulator`, `FastscapeEroder`, `SpaceLargeScaleEroder`, `LinearDiffuser`, `Lithology`/`LithoLayers` for layered rock (component names unverified — from memory) | [V] [repo](https://github.com/landlab/landlab), [V] PyPI JSON |
| **terrainbento** | multi-model LEM suite on Landlab | Python | MIT | 2.0.1 (2024-09-11) | prebuilt model variants | [V] PyPI JSON; [V] cited in fastscapelib refs (DOI 10.5194/gmd-12-1267-2019) |
| **Badlands** | TIN-based basin and landscape dynamics: tectonics (vertical and horizontal), SPL and transport-capacity incision, hillslope diffusion, **carbonate/reef growth**, sea level, turbidity | Python | GPL-3.0 per PyPI (GitHub lists LGPL-3.0 and GPL texts) | 2.3.1, 2026-05-01 | inspiration for coastal and carbonate platforms. Its sibling **gospl** (global, GPL, 2026.7.14) works at planet scale. | [V] [repo](https://github.com/badlands-model/badlands), [V] PyPI JSON |
| **RichDEM** | priority-flood, depression filling and breaching, flow metrics | C++/Python | GPLv3 | 0.3.4 (2018), stale | breach instead of fill for river corridors | [V] PyPI JSON |
| **pysheds** | flow direction, accumulation, watershed delineation | Python | (not stated on PyPI) | 0.5 (2025-08-14) | cheap flow and catchment masks | [V] PyPI JSON |

### C.3 Open-source generators and erosion tricks (techniques to borrow)

| project | technique | language | licence | maintained? | borrow | source |
|---|---|---|---|---|---|---|
| **mapgen4** (Red Blob Games) | Dual Delaunay/Voronoi mesh. Elevation is shaped to the desired look ("not realism"), then rainfall, biomes and rivers are derived. Paint-to-regenerate in real time. Web workers. | TypeScript | Apache-2.0 | "updated in 2023", carries an *unmaintained* badge | the painted-control idea (paint mountain/valley intent, recompute rivers instantly) | [V] [repo](https://github.com/redblobgames/mapgen4) |
| **Azgaar Fantasy Map Generator** | Voronoi-cell world with heightmap templates, rivers, biomes and states (cites O'Leary and Patel) | JS → TS | MIT | active (2,602 commits) | template-based macro layout | [V] [repo](https://github.com/Azgaar/Fantasy-Map-Generator), [V] [LICENSE](https://raw.githubusercontent.com/Azgaar/Fantasy-Map-Generator/master/LICENSE) |
| **Martin O'Leary terrain** (`mewo2/terrain`) | Algorithm behind @unchartedatlas: mesh-based erosion and contour-style coastlines, with notes at mewo2.com/notes/terrain | JavaScript (D3) | MIT | "finished", not maintained | simple erosion-by-flux on irregular meshes | [V] [repo/README](https://raw.githubusercontent.com/mewo2/terrain/master/README.md) |
| **SimpleHydrology** (Nick McDonald) | Particle hydraulic erosion with **momentum and discharge maps**, which produce **meandering streams and pools**. Vegetation. The flooding system was removed in Jan 2023. | C++ | MIT | last dated update Jan 2023 | discharge-map rivers for our streams. [blog](https://nickmcd.me/2020/04/15/procedural-hydrology/) | [V] [repo](https://github.com/weigert/SimpleHydrology) |
| **SoilMachine** (Nick McDonald) | **Layered terrain**: run-length-encoded soil and rock columns per cell, several soil types, "erosion chains" | C++ | MIT | 61 commits, inactive (my judgement) | the per-cell layer stack data structure for strata-aware erosion (Danxia, cuestas) | [V] [repo](https://github.com/weigert/SoilMachine) |
| **Hydraulic-Erosion** (Sebastian Lague) | Droplet erosion (70k iterations shown). References the Beyer thesis "implementation of a methode for hydraulic erosion" and ranmantaru's blog. | Unity C# | MIT | not archived | standard droplet kernel; easy to port to a Godot compute shader | [V] [README](https://raw.githubusercontent.com/SebLague/Hydraulic-Erosion/master/README.md) |
| **terrain-erosion-3-ways** (dandrino) | (1) grid simulation (about 10 constants, cost roughly N³), (2) progressive GAN trained on USGS DEMs, (3) **river network first, terrain fitted around it** (O(N² log N)) | Python/NumPy | MIT | 28 commits, inactive | the river-network-first method suits our "rivers are designed" sites | [V] [repo](https://github.com/dandrino/terrain-erosion-3-ways) |
| **runevision erosion filter** (Rune Skovbo Johansen) | "Fast and Gorgeous Erosion Filter" (blog post 30 Mar 2026 with a video). A noise-like **filter applied on top of any height function**, giving branching gullies and ridges. **Each point is evaluated in isolation**, so it is GPU and chunk friendly. Shadertoy `wXcfWn`. Ports: Bevy WGSL crate, Blender GN node group, Godot GDScript. Not "2025": the write-up is dated 2026. | GLSL (Shadertoy) | **MPL-2.0** (as reported by the Blender port) | new (2026) | **runtime close-range erosion detail in our Godot terrain shader**, or a detail pass when upsampling 40 → 10 丈 | [S] [blog](https://blog.runevision.com/2026/03/), [S] [bevy crate](https://docs.rs/bevy_erosion_filter), [S] [Godot forum](https://forum.godotengine.org/t/fast-and-gorgeous-erosion-filter/136436), [S] [BlenderNation](https://www.blendernation.com/2026/05/05/free-download-quick-erosion-filter/) |
| **Clay John "Eroded Terrain Noise"** (2018 Shadertoy) and **Fewes** (2023 Shadertoy) | Single-pass noise whose gradient-aligned gully octaves imitate erosion. This is the lineage runevision builds on. A World Machine forum post instead credits an IQ concept, so the attribution conflicts. | GLSL | Shadertoy default (unverified) | n/a | same use as above | [S] runevision blog (above), [S] [WM forum](https://forum.world-machine.com/t/erosion-noise-a-device-generating-noise-that-looks-like-eroded-terrain/8275) |
| **Inigo Quilez noise derivatives** | Analytic-derivative noise in which octaves are attenuated by accumulated gradient (1/(1+‖∇‖²)), so peaks get rough and slopes and valleys smooth ("Elevated", "more noise" article) | GLSL | articles | n/a | cheap erosion look for distant terrain | (unverified — from memory) |
| **Dendry** (Gaillard et al., I3D 2019) | Locally computable dendritic function: the distance to an implicit tree built on the fly gives consistent river networks. About 10 s for 512² on 4 CPU cores. | C++ (Qt, OpenCV) | GPL-3.0 | research release | river or gully networks at chosen locations without global simulation. DOI 10.1145/3306131.3317020 | [V] [repo](https://github.com/mgaillard/Noise), [S] [paper PDF](https://www.cs.purdue.edu/cgvlab/www/resources/papers/Gaillard-2019-Dendry_A_Procedural_Model_for_Dendritic_Patterns.pdf) |
| **LayerProcGen** (runevision) | Layer-based infinite procedural generation with dependent layers in chunks | C# | MPL-2.0 | active (my judgement) | a model for our boot-order dependency chain if we ever stream the world | [V] [runevision repos](https://github.com/runevision?tab=repositories) |
| **wgen** | heightmap generator, 16-bit png/exr export | Rust | MIT | ? | quick base maps | [V] cited in [Terrain3D heightmaps.md](https://github.com/TokisanGames/Terrain3D/blob/main/doc/docs/heightmaps.md) |

---

## D. Academic work (one line each: what it does, why it matters to us)

| paper | what it does / why it matters for us | link |
|---|---|---|
| **Galin, Guérin, Peytavie, Cordonnier, Cani, Benes, Gain, 2019, "A Review of Digital Terrain Modeling"**, CGF 38(2), Eurographics STAR | Taxonomy of procedural, simulation-based, example-based and sketch-based terrain plus amplification. Our reading list and vocabulary. | DOI 10.1111/cgf.13657 (unverified — from memory) |
| **Génevaux, Galin, Guérin, Peytavie, Benes, 2013, "Terrain Generation Using Procedural Models Based on Hydrology"**, ACM TOG 32(4) | Builds the river network first from a coastline and sketch, then composes terrain from river- and ridge-aligned primitives. Suits sites where rivers are designed. | [S] [PDF (Purdue)](https://www.cs.purdue.edu/homes/bbenes/papers/Genevaux13ToG.pdf); DOI 10.1145/2461912.2461996 (unverified — from memory) |
| **Cordonnier, Braun, Cani, Benes, Galin, Peytavie, Guérin, 2016, "Large Scale Terrain Generation from Tectonic Uplift and Fluvial Erosion"**, CGF 35(2) | User uplift map plus stream-power erosion gives mountain ranges with consistent drainage. **This is the method our 03a relief already uses** (same physics, but we use the steady-state closed form). | DOI 10.1111/cgf.12820 (unverified — from memory) |
| **Cordonnier, Cani, Benes, Braun, Galin, 2018, "Sculpting Mountains: Interactive Terrain Modeling Based on Subsurface Geology"**, IEEE TVCG 24(5) | Sketched folds and faults define a layered subsurface. Erosion uses per-layer resistance, so cliffs, hogbacks and cuestas appear where hard layers outcrop. **This is the template for Danxia red beds and stepped cliffs.** | DOI 10.1109/TVCG.2017.2689022 (unverified — from memory) |
| **Argudo, Galin, Peytavie, Paris, Gain, Guérin, 2019, "Orometry-based Terrain Analysis and Synthesis"**, ACM TOG 38(6) | Peaks-and-saddles "Divide Tree" statistics (prominence, isolation) from real DEMs, used to synthesise terrains that match them. Lets us check that our peak fields resemble Huangshan or Huashan statistics. MIT code. | [V] [code](https://github.com/oargudo/orometry-terrains), DOI [10.1145/3355089.3356535](https://doi.org/10.1145/3355089.3356535) [V via README] |
| **Schott, Paris, Fournier, Guérin, Galin, 2023, "Large-scale terrain authoring through interactive erosion simulation"**, ACM TOG | Paint uplift and the stream-power equation erodes continuously, so ridges form where uplift is high. **An interactive version of our 03a model**, open source. | [V] [code (MIT)](https://github.com/H-Schott/StreamPowerErosion), HAL hal-04049125 [V via README] |
| **Schott, Galin, Guérin, Peytavie, Paris, 2024, "Terrain Amplification using Multi-Scale Erosion"**, ACM TOG (SIGGRAPH 2024) | Upsample ×2, then alternate stream-power, thermal and deposition passes. GPU (GL 4.3). **Amplifies our 40-丈 field to 10–20 丈 with erosion-consistent detail.** | [V] [code (MIT)](https://github.com/H-Schott/MultiScaleErosion), [V] [author publication list](https://raw.githubusercontent.com/H-Schott/H-Schott.github.io/main/index.html) |
| **Paris, Galin, Peytavie, Guérin, Argudo, 2019, "Desertscapes Simulation"**, CGF 38(7) (PG 2019) | Wind-driven sand: dunes, nabkha and yardangs on bedrock with layered sand. Our deserts and steppes, and Zhangye-like yardang badlands. | [V] [code (MIT)](https://github.com/aparis69/Desertscapes-Simulation) |
| **Paris, Guérin, Peytavie, Collon, Galin, 2021, "Synthesizing Geologically Coherent Cave Networks"**, CGF 40(7) (PG 2021) | Karst cave skeletons constrained by inception horizons, fractures and water tables. Gives the caves under our karst and the logic for where **tiankeng** (collapsed chambers) go. | [V] [code (MIT)](https://github.com/aparis69/Karst-Synthesis), [V] [author PDF on HAL](https://hal.archives-ouvertes.fr/hal-03331697/file/2021-caves-author.pdf) (link from README) |
| **Paris, Galin, Peytavie, Guérin, Gain, 2019, "Terrain Amplification with Implicit 3D Features"**, ACM TOG 38(5) | Adds implicit (SDF) arches, overhangs and **hoodoos** (shape-grammar growth) on top of a heightfield. **The closest published method to procedural pillars.** | [V] [code (MIT, hoodoo grammar not included)](https://github.com/aparis69/Implicit-Volumetric-Terrains) |
| **Paris, Peytavie, Guérin, Dischler, Galin, 2020, "Modeling Rocky Scenery using Implicit Blocks"**, The Visual Computer 36(10) | Fracture networks cut rock into implicit blocks, giving jointed cliffs and boulder fields. **Suits Huangshan's jointed granite and the blocky walls of Danxia and Zhangjiajie.** | [V] [code (MIT)](https://github.com/aparis69/Rock-fracturing) |
| **Argudo, Guérin, Schott, Galin, 2025, "Terrain Descriptors for Landscape Synthesis, Analysis and Simulation"**, CGF 44(2) (EG STAR) | A survey with code for slope, light accessibility, drainage area, TPI, prominence and isolation, and ridge and river networks. **Our mask library and validation metrics.** | [V] [code (MIT)](https://github.com/oargudo/terrain-descriptors), DOI [10.1111/cgf.70080](https://doi.org/10.1111/cgf.70080) [V via README] |
| **Argudo et al., 2020, "Simulation, Modeling, and Authoring of Glaciers"** (SIGGRAPH Asia 2020) | Glacier simulation on terrain, for Changbaishan or high-range valley glaciers. | [V] [code](https://github.com/oargudo/glaciers) (listed on [profile](https://github.com/oargudo)) |
| **Huftier, Schott, Galin, Argudo, Peytavie, Guérin, 2026, "Terrain synthesis and authoring based on iso-contours"**, CGF (EG 2026) | Contour-based authoring. Relevant because our map UI is contour and ink styled. | [V] [author publication list](https://raw.githubusercontent.com/H-Schott/H-Schott.github.io/main/index.html) |
| **Galin, Hubert-Brierre, Schott, Cani, Peytavie, Guérin, 2026, "The PhaseTree: Multiphase Signed Distance Fields"**, ACM TOG (SIGGRAPH 2026) | Multiphase SDF (several materials in one field). A possible future representation for rock, sand and water landforms with overhangs. | [V] same list |
| **Gaillard et al., 2019, "Dendry"**, I3D 2019 | see C.3 | DOI 10.1145/3306131.3317020 [S] |
| **Braun & Willett, 2013**, Geomorphology | The O(n) implicit FastScape stream-power solver our model reproduces | DOI 10.1016/J.GEOMORPH.2012.10.008 [V via fastscapelib refs](https://raw.githubusercontent.com/fastscape-lem/fastscapelib/main/doc/source/references.bib) |
| **Barnes, Lehman, Mulla, 2014**, Computers & Geosciences | Priority-flood, which we use | DOI 10.1016/j.cageo.2013.04.024 [V same] |
| **Cordonnier, Bovy, Braun, 2019**, Earth Surface Dynamics | Linear-complexity flow routing through depressions (the MST sink resolver). **Keeps lakes instead of filling them.** | DOI 10.5194/esurf-7-549-2019 [V same] |
| **Tzathas, Gailleton, Steer, Cordonnier, 2024, "Physically-based analytical erosion for fast terrain generation"**, CGF (EG 2024) | Analytical (closed-form) stream-power solution with transient behaviour. Very close to our steady-state integral and worth reading for a time-dependent extension. | (unverified — from memory) |
| **Cordonnier et al., 2023, "Forming Terrains by Glacial Erosion"**, ACM TOG 42(4) | Glacial valleys, cirques and U-shapes for high ranges | (unverified — from memory) |
| **Peytavie, Galin, Grosjean, Mérillou, 2009, "Arches: a Framework for Modeling Complex Terrains"**, CGF 28(2) | Layered material stacks (rock, sand, …) with overhangs and arches. A precursor to SoilMachine's stack. | (unverified — from memory) |
| **Guérin et al., 2017, "Interactive Example-Based Terrain Authoring with Conditional GANs"**, ACM TOG 36(6) | Sketch-to-terrain cGAN trained on DEMs | (unverified — from memory) |
| **Natali, Lidal, Viola, Patel, Sousa, Ebert, 2013, "Modeling Terrains and Subsurface Geology"**, Eurographics STAR | Survey of geology-aware terrain modelling: strata, faults, folds | (unverified — from memory) |
| **Procedural karst towers, Danxia or sandstone pillars** | I found **no CG paper dedicated to fenglin/fengcong towers, Danxia or Zhangjiajie pillars**. The search budget ran out before I could look thoroughly. The closest are Paris 2019 (hoodoos), Paris 2020 (fractured blocks), Cordonnier 2018 (strata) and Peytavie 2009 (stacks). The geomorphology literature on Danxia and Zhangjiajie is in geoscience journals I could not reach. | gap (unverified) |

---

## E. Games: how big open worlds build vertical features

| game | talk / article | technique (what matters for us) | status |
|---|---|---|---|
| **The Witcher 3** (CD Projekt RED) | Marcin Gollent, **"Landscape Creation and Rendering in REDengine 3"**, GDC 2014. [slides PDF](https://ubm-twvideo01.s3.amazonaws.com/o1/vault/GDC2014/Presentations/Gollent_Marcin_Landscape_Creation_and.pdf). I found the link cited in a GitHub issue ([V] [CatDogEngine #365](https://github.com/meta4d-me/CatDogEngine/issues/365)) and did not open the PDF. | Tiled heightmap clipmap terrain with tessellation. Terrain material uses a **background + overlay texture per texel with slope-driven blend**, the same idea as Terrain3D's base/overlay/blend control map. Cliffs are rock meshes on the heightfield. | link [V-indirect]; technique (unverified — from memory) |
| **Horizon Zero Dawn** (Guerrilla) | Jaap van Muijden, **"GPU-Based Procedural Placement in Horizon Zero Dawn"**, GDC 2017. A third-party issue links the video as [youtu.be/ToCozpl1sYY](https://youtu.be/ToCozpl1sYY) ([V] [Alchemy issue #81](https://github.com/Alchemy-Engine-Demon-Byte/AlchemyDocumentation/issues/81)). | Placement density is computed per asset type from **world data maps** (height, slope, curvature, painted biome, distance to roads and water). Logic graphs are evaluated on the GPU in tiles around the player, at runtime, with dithered footprints. | video link [V-indirect]; speaker, year and details (unverified — from memory) |
| **Far Cry 5** (Ubisoft) | Etienne Carrier, **"Procedural World Generation of Far Cry 5"**, GDC 2018 | **Houdini Engine inside the Dunia editor.** Terrain erosion, freshwater (lakes and rivers), **cliff-mesh generation on steep slopes**, biome painting and line tools (fences, power lines) all run as HDAs. A companion GDC 2018 talk covered terrain rendering. | (unverified — from memory) |
| **Ghost of Tsushima** (Sucker Punch) | "Samurai Landscapes: Building and Rendering Tsushima Island on PS4", GDC 2021 | Heightfield terrain with procedural, data-driven vegetation and grass. Long view distances. Wind-driven art direction. | (unverified — from memory) |
| **Genshin Impact – Liyue** (HoYoverse) | No technical talk found on how the pillars are built | Liyue's stone forests and karst pillars are widely described as inspired by **Zhangjiajie, Guilin and Huanglong**. What you see in game: pillars are **reused, scaled rock meshes** placed on heightfield terrain, with stylized rock shading. | (unverified — from memory) |
| **Black Myth: Wukong** (Game Science) | No primary source found | **Photogrammetry of real Chinese temples, statues and landscapes** (much of it reported in Shanxi), UE5 with Nanite | (unverified — from memory) |
| **Where Winds Meet / 燕云十六声** (Everstone / NetEase) | No public terrain talk found | — | (unverified) |
| **Avatar: Frontiers of Pandora** (Massive, bonus: floating mountains) | Massive blog **"Crafting Pandora's breathtaking landscape with Snowdrop"**: [massive.se](https://www.massive.se/blog/games-technology/snowdrop/crafting-pandoras-breathtaking-landscape-with-snowdrop/) (link [V-indirect], same Alchemy issue) | Snowdrop's procedural scattering of landscape features | content not read |
| **Unreal Engine** (reference tech) | ["Introduction to Mesh Terrain"](https://dev.epicgames.com/community/learning/knowledge-base/nK7J/unreal-engine-introduction-to-mesh-terrain), [PCG overview](https://dev.epicgames.com/documentation/unreal-engine/procedural-content-generation-overview) (links [V-indirect]) | Mesh-based (non-heightfield) terrain for overhangs, plus a rule-graph PCG scatter | content not read |

**Common pattern** (a synthesis, consistent across the talks as I remember them; unverified detail):

- The **heightfield** carries the macro landform and the masks.
- **Modular rock and cliff kits**, with 5–30 variants each, triplanar materials and an optional height-blend into the
  terrain, are placed **by rules on masks** (slope, curvature, height band, flow, biome) and then hand-curated.
- **Hero landmarks** are sculpted or scanned meshes.
- **Overhangs and caves** are separate meshes (or mesh terrain or voxels) only where gameplay needs them.
- **Density and scatter** are evaluated from the same masks, offline or on the GPU near the camera.

---

## F. Real DEM sources as reference "stamps"

### F.1 Datasets and access

| DEM | resolution / type | licence | access | source |
|---|---|---|---|---|
| **SRTM GL1 v003** | 1″ (≈30 m), 60°N–56°S, radar DSM (voids in steep karst; unverified — from memory) | NASA LP DAAC: "openly shared, without restriction". One catalogue lists CC-BY 4.0. Cite LP DAAC. | EarthExplorer (NASA Earthdata and USGS logins), OpenTopography `SRTMGL1` | [S] [data.gov](https://catalog.data.gov/dataset/nasa-shuttle-radar-topography-mission-global-1-arc-second-v003-fc966), [S] [researchdata.edu.au](https://researchdata.edu.au/srtmgl1v003-dsm/3405258), [S] [Earthdata](https://www.earthdata.nasa.gov/es/data/catalog/lpcloud-srtmgl1-003?page=6%2C0) |
| **Copernicus DEM GLO-30** | 30 m **DSM** (includes buildings and vegetation) | free worldwide licence. Required attribution "© DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018". Some country tiles are not yet released (list on AWS). | AWS Open Data, Copernicus Data Space, Google Earth Engine, OpenTopography `COP30` | [S] [licence PDF](https://documentation.dataspace.copernicus.eu/APIs/SentinelHub/Data/DEM/resources/license/License-COPDEM-30.pdf), [S] [AWS registry](https://registry.opendata.aws/copernicus-dem/), [S] [GEE](https://developers.google.com/earth-engine/datasets/catalog/COPERNICUS_DEM_GLO30_2024_1) |
| **ALOS AW3D30** (JAXA) | ≈30 m DSM from PRISM. v4.1 covers the globe except Japan and Antarctica. Coverage 82°N–82°S. | free for commercial and non-commercial use under JAXA's Terms of Use | JAXA EORC portal, OpenTopography `AW3D30` | [S] [JAXA](https://www.eorc.jaxa.jp/ALOS/en/dataset/aw3d30/aw3d30_e.htm), [S] [GEE](https://developers.google.com/earth-engine/datasets/catalog/JAXA_ALOS_AW3D30_V2_1) |
| **NASADEM** | reprocessed SRTM | (NASA) | OpenTopography `NASADEM` | [S] [OT announcement](https://opentopography.org/node/3404) |
| **OpenTopography global API** | serves SRTMGL1/GL3, AW3D30, NASADEM, COP30… as GeoTIFF | free API key. **200 calls/24 h for academics, 50/24 h for others.** Plus tier $30/mo. Keys may not be shared or embedded. | `portal.opentopography.org/API/globaldem?demtype=…` (URL pattern [V] in BlenderGIS prefs) | [S] [developers](https://opentopography.org/node/3158), [S] [API keys blog](https://opentopography.org/blog/introducing-api-keys-access-opentopography-global-datasets), [S] [getting started](https://www.opentopography.org/start), [S] [SAGA tool doc](https://saga-gis.sourceforge.io/saga_tool_doc/9.13.0/io_webservices_4.html) |

At our 40-丈 (133 m) grid, a 30 m DEM is about 4.4× finer. Stamps are therefore good for **shape statistics and regional
10–20-丈 tiles**, not for resolving pillars. Zhangjiajie columns are much narrower than 30 m DEM cells (unverified —
from memory). Copernicus is generally regarded as the best of the free 30 m set in steep terrain (unverified — from
memory).

### F.2 Reference sites (approximate centres, WGS84)

| site | landform | lat, lon | source |
|---|---|---|---|
| Zhangjiajie – Wulingyuan | quartz-sandstone pillar forest | **29.333°N, 110.500°E** (latlong.net gives 29.3355, 110.4811) | [S] [Wikipedia](https://en.wikipedia.org/wiki/Wulingyuan), [S] [latlong.net](https://www.latlong.net/place/wulingyuan-scenic-area-zhangjiajie-china-27336.html) |
| Guilin–Yangshuo (Li River) | fenglin karst towers on alluvial plain | Yangshuo **24.783°N, 110.500°E**. Li River scenic band ≈ 24°38′–25°04′N, 110°10′–110°41′E (travel-site figure). Xingping ≈ 24.92°N, 110.52°E (unverified — from memory). | [S] [Wikipedia Yangshuo](https://en.wikipedia.org/wiki/Yangshuo_County), [S] [trip.com post](https://ae.trip.com/moments/detail/lingchuan-3064-131896521) |
| Danxiashan (Renhua, Guangdong) | type-locality Danxia red-bed mesas | WHS component **24.965°N, 113.703°E**. Scenic area 24°51′48″–25°04′12″N, 113°36′25″–113°47′53″E. | [S] [Wikipedia Danxia landform](https://en.wikipedia.org/wiki/Danxia_landform), [S] [China Daily](https://govt.chinadaily.com.cn/s/201812/17/WS5ce75ce0498e079e68021962/danxia-mountain-chinas-red-stone-park-shaoguan.html) |
| Zhangye Danxia (Gansu) | banded red-bed badlands (arid) | **38.916°N, 100.133°E** | [S] [Wikipedia](https://en.wikipedia.org/wiki/Zhangye_National_Geopark) |
| Huangshan | jointed granite spires | Lotus Peak 1,864 m, summit GPS **30.127°N, 118.166°E** | [S] [Wikipedia](https://en.wikipedia.org/wiki/Huangshan), [S] [summit log](https://www.ii.uib.no/~petter/mountains/1500mtn/huangshan.html) |
| Huashan | granite massif, sheer walls | **34.483°N, 110.083°E** (South Peak 2,154.9 m) | [S] [Wikipedia](https://en.wikipedia.org/wiki/Mount_Hua) |
| Wuyishan | Danxia (Nine-Bend Stream) and granite highland (north) | WHS component 1 **27.726°N, 117.725°E** (N27°43′35″ E117°43′31″). Jiuqu Xi mouth (Danxia scenic area) **27.641°N, 117.969°E**. | [S] [UNESCO maps](https://whc.unesco.org/en/list/911/maps), [S] [Wikipedia Jiuqu Xi](https://en.wikipedia.org/wiki/Jiuqu_Xi) |
| Libo karst (Xiaoqikong) | fengcong cone karst and forested gorges | **25.277°N, 107.714°E** | [S] [UNESCO periodic report](https://whc.unesco.org/document/164582) |
| Wulong (Three Natural Bridges / tiankeng) | tiankeng and natural bridges | **29.434°N, 107.801°E** | [S] [Wikipedia](https://en.wikipedia.org/wiki/Three_Natural_Bridges) |
| Shilin (Stone Forest, Yunnan) | limestone pinnacle karst | **24.825°N, 103.324°E**. Park 24°30′–25°03′N, 103°10′–103°40′E. | [S] [Wikipedia mirror](https://loongese.com/blog/heritages/stone_forest), [S] [UNESCO plan](https://whc.unesco.org/document/104803) |
| Huanglong (Sichuan) | travertine terraces | **32.743°N, 103.833°E** | [S] [Wikipedia](https://en.wikipedia.org/wiki/Huanglong_Scenic_and_Historic_Interest_Area) |
| Yandangshan (Zhejiang) | rhyolite caldera cliffs and pinnacles | Baigangjian **28.37°N, 121.06°E** | [S] [Wikipedia](https://en.wikipedia.org/wiki/Yandang_Mountains) |
| Changbaishan Tianchi | volcanic crater lake (surface 2,189 m) | **42.006°N, 128.057°E** | [S] [Wikipedia](https://en.wikipedia.org/wiki/Heaven_Lake) |
| Loess Plateau gullies (Ansai, Shaanxi) | loess hilly-gully, "over 90%" gullies and ridges | Ansai station **36.87°N, 109.32°E**. Watershed ≈ 36°52′–37°19′N, 108°47′–109°25′E. | [S] [PMC8296048](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8296048/), [S] [geog.com.cn](https://www.geog.com.cn/EN/abstract/article/0375-5444/18860) (these two give different bounding boxes) |

---

## G. Recommendations for our pipeline (my view)

### G.1 Base heightfield (offline Python, deterministic)

1. **Keep the steady-state stream-power relief as the macro generator.** Cordonnier 2016, Schott 2023 and FastScape all
   use the same physics, so the approach is sound. Re-express it on **fastscapelib 0.3** (offline only, so GPL is fine)
   to gain:
   - spatially variable **K from a lithology map**: granite low K, limestone medium K plus a karst rule, red sandstone
     medium, loess very high;
   - **hillslope diffusion** (`DiffusionADIEroder`), so ridges round where they should;
   - **`MSTSinkResolver` with explicit base levels**, so designed lakes survive instead of being priority-filled;
   - **`MultiFlowRouter`** for smooth flow-accumulation masks.
2. **Add a 2.5-D strata model** (after Cordonnier 2018, using a SoilMachine-style stack): a few layers with dip and
   strike, thickness, hardness and talus angle. Erode with K(z) and a **per-layer thermal pass**. Resistant caps then
   produce **mesas, cuestas and stepped Danxia walls** by themselves, and terraces come from geology rather than a global
   terrace filter.
3. **Landform zones as rule masks**, written down so they can be checked (geomorphology rules are from memory,
   unverified):
   - **fengcong**: cone karst with closed depressions, on limestone far above base level;
   - **fenglin**: isolated towers, on limestone near base level or alluvial plains, as at Guilin;
   - **pillar forest**: thick horizontal quartz sandstone, dissected plateau edge, high drainage density, as at
     Zhangjiajie;
   - **Danxia**: red-bed outcrop band with a slope threshold;
   - **granite spires**: pluton mask with high relief, as at Huangshan and Huashan;
   - **loess gullies**: very high K with low-threshold channels plus Dendry-style dendritic gullies.
4. **Amplify locally, not globally.** Keep 40 丈 for the whole world. Where the camera gets close (sects, routes,
   landmarks), upsample to **10–20 丈 tiles** with **Schott 2024 multi-scale erosion** (MIT, C++/GL compute) or a numpy
   port. For the farthest detail, run the **runevision erosion filter** (MPL-2.0, per-point) in the Godot terrain shader.
   Its per-point evaluation fits our existing chunked GPU-displaced terrain.
5. **Validate against real stamps.** Pull Copernicus GLO-30 tiles for the F.2 sites through the OpenTopography API
   (`COP30`), compute the **terrain-descriptors** metrics (slope, drainage area, TPI, prominence and isolation; MIT code)
   and orometry stats for both the real site and our zone, and compare histograms. Use stamps as **statistical targets
   and occasional blended stamps on 10–20-丈 tiles**, never 1:1 at 40 丈.

### G.2 Vertical rock features (anything under ~120 丈 wide or over ~65°)

1. **The heightfield carries the plinth and the masks; meshes carry the walls.** This is the pattern every big open world
   in section E uses.
   - Zhangjiajie pillars, Shilin columns and Huangshan spires are **pure mesh**.
   - Guilin towers and Danxia mesas are **hybrid**: a heightfield bump plus a cliff-mesh shell.
   - Tiankeng are a heightfield pit plus wall meshes. Caves only where needed (Karst-Synthesis skeletons, then a mesh).
2. **Generate the rock kit procedurally in Python/Blender as SDF, then mesh it.**
   - Pillar = an extruded **joint-set polygon** (two orthogonal vertical joint families) with bedding-plane notches,
     weathered with SDF noise (Paris 2019 and 2020 ideas, MIT code).
   - Mesh with marching cubes, then decimate, bake normal and AO maps, and export **GLB variants with LODs**: 10–30 per
     landform, plus a cheap impostor for distance.
   - This fits our ink/facet look better than photogrammetry. Black Myth-style scans are a realism choice.
3. **Placement by rules.** Use Poisson-disk sampling inside the zone masks, with **orientation and spacing taken from a
   regional joint field** (pillars line up along joints), height from local relief, and density from slope and flow
   (the HZD-style density logic).
   - Write instance lists offline, as `planTrees()` already does.
   - Render with a per-chunk **MultiMesh**, the same pattern as `trees.gd`.
   - Give near pillars simple collision shapes, because a flying game needs rock collision. Terrain3D's instancer has
     none.
4. **Avoid voxels for the whole world.** godot_voxel (Transvoxel/SDF, MIT) is excellent but costly at 440 km. Use it, or
   static meshes, only for hero caves or tiankeng interiors.

### G.3 Scattering

- **Offline and deterministic first.** Use the same masks as section C.1 item 5 (slope, curvature, flow, wear/deposit,
  TPI, height band, biome), with seeded density functions, written to the existing instance-list format. This keeps the
  demo and the Godot port in lockstep.
- **Editor-time touch-ups.** ProtonScatter (MIT, Godot 4) for rule-based local spots. Spatial Gardener (MIT, 4.4) for
  painting inside sect patches.
- **Terrain3D instancer** only if we adopt Terrain3D, and only for non-colliding grass and small rocks. It is limited to
  single-mesh assets and has no collision ([V] instancer.md).

### G.4 Godot terrain host

- The current custom chunked GPU-displaced terrain already works on 4.7.1 and matches the demo's look, so **keep it as
  the runtime**.
- Adopt **Terrain3D 1.0.2** (Godot 4.4–4.7, MIT) only if we want in-editor sculpting, holes, texture painting and the
  32-texture control map. If so:
  - `vertex_spacing` 40 (or 20 after amplification);
  - `region_size` ≥ 128 (≥ 256 at 20 丈);
  - import with `Terrain3DData.import_images([height_img, null, null], Vector3(x0, 0, z0), offset, scale)`;
  - write the control map ourselves using the bit layout in A.1.
- Either way, plan a **floating origin** or accept edge jitter, because our map edges sit far past the documented
  single-precision limit.

### G.5 Blender round-trips (bpy 5.x)

- **Python/numpy is the source of truth; Blender is for sculpting and the rock kit.**
- **In:** keep `tools/blender/import_world.py` (regular grid built with `foreach_set`). For big areas, use float EXR on a
  subdivided plane with a Displace modifier (colour space *Non-Color*), tile by tile.
- **Out:**
  - grid meshes: `foreach_get("co")` (exact);
  - free-form sculpts: `BVHTree.FromObject` plus downward `ray_cast` per texel;
  - a fast preview: an ortho render of Position.z with the Standard view transform to 32-bit EXR.
  - Store float32 heights in 丈 with a JSON sidecar (origin, spacing). Use R16 only for third-party tools and record
    min/max.
- **Erosion stays in Python** (fastscapelib, Schott codes). Use A.N.T.'s eroder and the Geometry-Nodes add-ons only for
  look-dev. The free **Quick Erosion Filter** GN node is handy for previewing what the runtime erosion filter will add.
- **Commercial tools are optional.** Gaea or World Creator could serve as look-dev references for strata, selective
  erosion and wear/deposit masks. Gaea's free tier exports only 1024², and World Creator's Godot bridge requires
  Terrain3D. Our own Python stack covers the same ground with full control and determinism.
