# 修仙御空 · 云梦山舆图 — Xiuxian Flying Map

A living 青绿山水 map of the 凡人修仙传 human realm (天南 · 溪国 · 云梦山 and the 天道盟 east) that you fly over as a
streak of light and fold into a painted 舆图 — the original **Three.js demo**, a **Godot 4 port** with the full UI, the
**tools** that move its generated world into Godot and Blender, and **documentation** of how every part works.

| demo (Three.js) | Godot 4 port |
|---|---|
| ![](docs/screenshots/05_info_card.png) | ![](docs/screenshots/godot/05_info_card.png) |
| ![](docs/screenshots/06b_map_home.png) | ![](docs/screenshots/godot/06b_map_home.png) |

## What's here

| path | |
|---|---|
| [`demo/`](demo) | the complete Three.js demo as published (index.html + its 84 asset files) |
| [`docs/`](docs/README.md) | how the map is made: overview + six chapters covering all ~15 000 lines with line references, plus the Godot guides |
| [`godot/`](godot) | Godot 4.4+ project (verified on 4.7.1): the exported world, flight & camera, fly ⇄ 舆图, painted map, every UI screen |
| [`tools/export-world/`](tools/export-world) | runs the demo headless and exports its generated world (heights, water, zoning, trees, sect/city meshes) |
| [`tools/blender/`](tools/blender) | import a region of the world into Blender; give your own meshes the ink-line vertex layout; hand-edit terrain and bake it back |
| [`tools/terrain/`](tools/terrain) | the geological re-sculpt: a paintable rock plan → stream power + landform operators → a new terrain for Godot ([docs](docs/terrain/README.md)) |

## Run the demo

```bash
cd demo && python3 -m http.server 8000     # then open http://localhost:8000  (?skip skips the intro)
```
WASD fly · Shift 疾遁 · Space/Q or wheel climb/descend · drag to pan · E 落脚 near a sect · M 收图/御空 · / search · ` debug.

## Run the Godot port

Open `godot/project.godot` in Godot 4.4+ and press F5 (same controls). See [docs/godot](docs/godot/README.md) for the
layout, what is ported, and how to extend it with Blender assets.

## Read the docs

Start with **[01 · Overview](docs/01-overview-architecture.md)** — the core idea (the map *is* the world: geography
traced from a reference 舆图 → a grown terrain → one value that flattens it back into a painted map), the coordinate
system, the boot pipeline and the frame. Then, by topic: [world data](docs/02-world-data-and-coordinates.md) ·
[terrain generation](docs/03-terrain-generation.md) · [rendering](docs/04-rendering-terrain-water-objects.md) ·
[sects & architecture](docs/05-sects-architecture-cities.md) · [clouds, light, post, life](docs/06-clouds-light-post-life.md) ·
[UI, flight, the 舆图](docs/07-ui-flight-camera-map.md). For the Godot/Blender work: [port guide](docs/godot/README.md) ·
[pipeline & Blender](docs/godot/01-pipeline-and-blender.md) · [UI recreation](docs/godot/02-ui-recreation.md) ·
[upgrade roadmap](docs/godot/03-upgrade-roadmap.md) (real forests from the asset libraries, rebuilt sects, finer terrain).
Terrain and level editing with real geological logic, aligned with the novel: [docs/terrain](docs/terrain/README.md)
(tools in `tools/terrain`; fly over the re-sculpted land with `godot --path godot -- --terrain=res://data/terrain`).

## Licences and assets

- `demo/assets/ym_pack.json`, `demo/assets/tex/*`, `demo/assets/eco*` contain models and textures from **Stylized Chinese
  Lost Temple** (Stylarts) and **Meadow Environment** (ANGRY MESH), via `kk20054/ThreeJS-Stylized-World-Assets`; the
  file's own copyright line says the rights stay with the original packages. These are commercial assets — check your
  licences before keeping this repository public or redistributing builds.
- `godot/fonts/` are subsets of Ma Shan Zheng and Noto Serif SC under the SIL Open Font License (`godot/fonts/LICENSE-OFL.txt`).
- The world geography is traced from the selfmate 人界舆图; place names and lore are from 凡人修仙传.
