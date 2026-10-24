# 01 · Pipeline: demo → exported world → Godot / Blender

```
demo/index.html ──(tools/export-world: Playwright runs the demo headless, reads window.__ym)──► godot/data/world/
        │                                                                                       │
        │                                              ┌────────────────────────────────────────┤
        ▼                                              ▼                                        ▼
  the reference look                       Godot (godot/, runtime loaders)       Blender (tools/blender/import_world.py)
                                                                                        │ model / replace assets
                                                                                        ▼
                                                              GLB back into godot/data/world/meshes (props.gd loads them)
```

Why export rather than re-implement: the generation is ~10 000 lines of tuned, interdependent code (drainage relief,
landforms per sect, A* roads, zoning, placement). Reading its result out of the running demo gives **exactly** the same
world in Godot and Blender, and the demo stays the editable source of the geography. The algorithms are still documented
in chapters [02](../02-world-data-and-coordinates.md)–[03](../03-terrain-generation.md) (with a numpy port of the relief)
for when you want to change them.

## Running the exporter

```bash
cd tools/export-world
npm install                 # playwright 1.63, three 0.170.0 (same as the demo), pngjs; installs Chromium
npm run export              # → godot/data/world (about 2–4 minutes; most of it is the demo booting)
node export_world.js --eco            # also the 1.77 M Meadow ground cards (eco.bin)
node export_world.js --terrain-mesh   # also meshes/terrain.glb: the demo's own faceted terrain tiles (≈ 80 MB)
node export_world.js --out /some/dir --demo ../../demo
```
It serves `demo/` on a local port, routes the jsDelivr three.js import to `node_modules/three` (works offline), keeps
copies of the tree and ground-card lists before the demo frees them, and transfers typed arrays out of the page in
base64 slices.

## What is in `godot/data/world`

All positions in 丈, +x east, +z south, +y up; the world rect is in `meta.json → rect`.

| file | format | content | read it in Godot | in Blender / Python |
|---|---|---|---|---|
| `meta.json` | JSON | rect, grid sizes, encodings, layout constants, the demo's **CONFIG**, biome names/colours, stats, file list | `World.meta`, `Cfg` | `json.load` |
| `height_f16.bin` | IEEE half, w×h (3296 × 2005), 40 丈 | the heightfield (`h = value` 丈) | `Image.create_from_data(w,h,false,FORMAT_RH,bytes)` | `np.fromfile(dtype='<f2').reshape(h,w)` |
| `height.png` | 16-bit grey | same, `h = v/65535·max` (max in meta) | — (Godot strips 16-bit PNGs) | Displace modifier / Terrain3D / Gaea import |
| `height_patch_N(_f16.bin/.png)` | same, 13.3 丈 | the six sect patches (rects in `meta.patches`) | `World.patches` | `import_world.py` uses them |
| `mountain_color.png` | RGBA8 on the height grid | the demo's 青绿 ramp per grid point (rgb display-space), a = mountain | `t_mcolor` | vertex colours |
| `water_tex.png` | RGBA8 4608 × 2801 | **the demo's water texture**: R shore distance (128 = shore, 2 丈 per step), GB flow, A sea | `t_water` | `sd = (R·255−128)·2` |
| `water_mask.png`, `water_sd.png`, `sea_depth.png` | 8-bit / 16-bit / 8-bit | coverage, signed distance (`(v−32768)/8` 丈), sea factor | — | masks |
| `biome.png` + `biome_preview.png` | 8-bit ids 1536 × 934 | 17 zones (`meta.biome.names`) | — (debug) | scatter masks |
| `biome_weights.png` | RGBA8 | R flower field, G sand, B marsh, A lushness | terrain `t_bweights` | |
| `flower_drift.png` | RGBA8 3072 × 1868 | rgb dominant flower colour, a drift | terrain `t_drift` | |
| `season.png` | RGBA8 | R winter, G autumn, B spirit land, A dry steppe | terrain `t_season` | season variants |
| `ground.png` | RGBA8 1536 × 934 | R woods, G fields, B bare ground (yards/lanes), A the lie of the fields | `t_ground` | scatter masks |
| `cloud_sea.png` | 8-bit 1648 × 1002, 80 丈 | the cloud sea's planned density | `cloud_sea.gd` | |
| `places.json` | JSON | 28 places: id, name, cat, ally, type, sub, crumb, lead, body[], note, chips[], pos, labelY, banner radius, hotspot | `World.places` | empties |
| `paths.json` | JSON | roads (kind, width, pts), rivers (name, great), streams, bridges, villages | overlay | curves |
| `layout.json` | JSON | sect sites (x, z, R, look, cloud top), landmarks, peaks, pillar, vortex, pools, falls, moats | `World.layout` | |
| `trees.bin` | 8 B per tree | uint16 x, z over the rect · uint8 kind, colour slot, yaw/256·2π, scale/255·scaleMax | `trees.gd` (thread) | `import_world.py` (Geometry Nodes) |
| `meshes/sect_<id>.glb` | glTF | each sect's architecture (one merged mesh) | `props.gd` | glTF import |
| `meshes/sect_<id>_ground.glb` | glTF | each sect's fine ground (13.3-丈 facets) | `props.gd` (ground ink) | |
| `meshes/sect_<id>_surroundings.glb`, `cities.glb`, `props.glb` | glTF | landmarks near a sect, the two cities, everything else (spirit tree, 天柱山, settlements, roads' bridges…) | `props.gd` | |

### The facet vertex layout (all GLBs)

| attribute | content |
|---|---|
| `POSITION`, `NORMAL` | world position (丈), flat facet normal |
| `COLOR_0` (uint8 RGBA) | rgb = face colour (display-space sRGB), a = ink weight of the edge **opposite corner C** |
| `TEXCOORD_0` (uint16) | barycentric (x, y) of the corner — A (1,0), B (0,1), C (0,0) |
| `TEXCOORD_1` (uint16) | ink weights of the edges opposite corners A and B |

`facet.gdshader` draws ink where a barycentric → 0, weighted by that edge's ink, at a constant ~1 px (`fwidth`). Keep the
triangles unshared (no vertex welding) and no automatic LOD on these meshes.

## Blender

### Import a region: `tools/blender/import_world.py`

```bash
blender --background --python tools/blender/import_world.py -- --sect luoyun --out luoyun.blend
blender --python tools/blender/import_world.py -- --region -2000,-5000,3000,0 --step 2
#   --scale 0.1 (BU per 丈; default)   --data <dir>   --no-trees   --no-glb   --step N (thin the terrain grid)
```
Builds, in a collection **XY World**: `XY Terrain` (grid from the 40-丈 field — or the 13.3-丈 patch for `--sect` — with a
`Col` colour attribute from `mountain_color.png` and a vertex-colour material), `XY Water`, the GLBs touching the region
(**XY Architecture**), an empty per place (**XY Places**, custom props `place_id`, `category`), roads/rivers/streams as
curves (**XY Paths**), and **XY Trees**: one point per tree with `kind`, `colour`, `yaw`, `scale` attributes and a
Geometry Nodes modifier *XY Forest* that instances from the collection **XY Tree Kinds** (9 placeholder children in kind
order). **Replace those children with your asset-library trees** (keep the order, origin at the trunk foot) and the
forest updates — unmute *Realize Instances* in the node group to bake it to geometry.

Verified with Blender 5.2 (bpy) on 落云宗: 283 × 283 patch terrain, sect ground + halls + cities GLBs, 4 443 trees —
render: [`../screenshots/blender_import_luoyun.png`](../screenshots/blender_import_luoyun.png).

**Scale.** At the default 0.1 BU/丈, 1 BU = 1 m of the asset pack's own scale: the demo places pack models at 10 丈 per
metre (`PACK_M`, L667), so Temple/Meadow assets drop in at native size. (Real-world 1 丈 ≈ 3.33 m — the demo is a
diorama; its mountains are ~1 000 丈 = 100 m at model scale.)

**Axes.** Godot/demo (x, y up, z south) → Blender (x, −z, y) — the glTF importer's own conversion, so GLBs line up.

### Give your own meshes the ink: `tools/blender/bake_ink_layout.py`

```bash
blender hall.blend --background --python tools/blender/bake_ink_layout.py -- --angle 25 --out hall_ink.glb
```
Triangulates, un-shares every corner, writes barycentrics + per-edge ink weights + face colours (converted to sRGB) in
the layout above. Ink = 1 on boundary, Sharp or Freestyle-marked edges and where faces meet at more than `--angle`°,
0 on flat diagonals; paint a float face attribute `ink` (0..1) to scale it per part (the demo uses ~0.9 on ridges and
outlines, ~0.35 on panel seams).

### Exporting back to Godot

- glTF 2.0 binary, +Y up (default), apply transforms, **merge vertices off** for ink-layout meshes.
- Put a replacement sect at `godot/data/world/meshes/sect_<id>.glb` (world coordinates ×10 if you modelled at 0.1 BU/丈:
  export with scale 10, or scale the root by 10 — Godot works in 丈).
- For assets you want the editor to import (materials, LODs, collisions): put them under `godot/assets/` instead (no
  `.gdignore`), import with *Generate LODs* only for non-ink meshes, and instance them in scenes.

## Re-running everything

```bash
cd tools/export-world && npm run export                                  # world data
godot --headless --path godot res://tools/build_scenes.tscn              # UI scenes + theme (only if you changed the builder)
godot --path godot --rendering-driver opengl3 -- --shots=/tmp/shots      # visual check
```
