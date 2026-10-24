# Documentation

How the Xiuxian Flying Map demo (`demo/index.html`) is built, and how to rebuild and extend it in Godot + Blender.

## The demo, part by part

1. [Overview & architecture](01-overview-architecture.md) — the idea, coordinates, boot pipeline, frame loop, section index.
2. [World data & coordinates](02-world-data-and-coordinates.md) — GEO, CONFIG (every key), layout, places, assets, world planning (coast SDF, peaks, heightfield, water, clouds).
3. [Terrain generation](03-terrain-generation.md) — the drainage-carved ranges (with a numpy port), rivers, A* roads, villages, seasons, the 17-class zoning, per-sect landforms.
4. [Rendering: terrain, water, objects](04-rendering-terrain-water-objects.md) — the 青绿 look (palette, flat tones, ink, 皴, haze), FacetBuf, terrain LOD, sun bake, water, mirrors, trees; Godot shader ports.
5. [Sects, architecture, cities](05-sects-architecture-cities.md) — the architecture kit, a build sheet per sect and city, formation domes, spirit lights, animation; Blender kit conventions.
6. [Clouds, light, post, life](06-clouds-light-post-life.md) — card clouds, the ray-marched cloud sea, god rays, cirrus, cloud falls, the 遁光, the cultivator figure, post chain, cranes, NPC flyers, walkers/carts/boats/deer.
7. [UI, flight, camera, the 舆图](07-ui-flight-camera-map.md) — every UI element with exact values, the state machine, the flight model, the fly⇄map transition, the map painting, boot, debug panel, test API.

## Godot + Blender

- [Port guide](godot/README.md) — run it, project layout, what maps to what, techniques, screenshots.
- [Pipeline & Blender](godot/01-pipeline-and-blender.md) — the exporter, every exported file, the facet vertex layout, Blender import/ink tools.
- [UI recreation](godot/02-ui-recreation.md) — theme variations, element-by-element map, CSS → Godot.
- [Upgrade roadmap](godot/03-upgrade-roadmap.md) — findings and a plan: real forests from the asset libraries, sects from the Temple kit, terrain, budgets, milestones.

## Terrain & level editing

- [Terrain & level editing](terrain/README.md) — how the land is made and edited today; landforms with real geological
  logic (stream power with rock, folds, faults, 峰丛 / 峰林 karst, Wulingyuan pillars, Danxia, granite, loess, volcanoes,
  glacial troughs, fans and terraces); the world plan aligned with 《凡人修仙传》; the tools (`tools/terrain`: plan → sculpt →
  feng-shui reader → Blender round trip → Godot `--terrain`); how other projects do it; three sourced research dossiers.

## Images

- `screenshots/` — the demo (`01_intro` … `11_mobile_map`), `screenshots/godot/` — the port in the same states,
  `screenshots/blender_import_luoyun.png` — `import_world.py --sect luoyun` rendered in Blender.
- `img/density.png`, `img/hint.png` — the two data maps embedded in the demo (mountain density; aridity/woods).

Line numbers ("L1234") refer to `demo/index.html`.
