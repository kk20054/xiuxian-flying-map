# tools/terrain — geological re-sculpt of the world

Grows the exported land (`godot/data/world`) again from a geological plan: per-rock stream-power erosion graded to the
舆图's rivers, then landform operators per rock (karst, Danxia, sandstone pillars, granite, loess, volcanic, alluvial
fans, glacial troughs, sea stacks), with the sect patches, cities and landmarks kept. Full guide:
[docs/terrain](../../docs/terrain/README.md) (tools: [04-tools.md](../../docs/terrain/04-tools.md)).

```bash
pip install numpy numba pillow
python3 make_plan.py                  # plan/lithology.png + plan/geology.json (the editable layer)
python3 sculpt.py                     # → ../../godot/data/terrain/  (height, lithology, rocks, layers, previews)
python3 fengshui.py [--terrain DIR] [--trace SITE] [--search SITE]
```

| file | |
|---|---|
| `make_plan.py` | writes the default plan for this map (regions, folds, faults, volcanoes, 龙脉 ridges — each with its reason) |
| `sculpt.py` | the CLI: plan + export → new terrain folder + previews |
| `fengshui.py` | scores sect sites (玄武, 龙脉, 砂, 水, 明堂, 藏风, 案朝, 向, 穴), traces dragon veins, searches for better sites |
| `xyterrain/world.py` | reads/writes the exported world (no PIL needed — works in Blender's Python) |
| `xyterrain/flow.py` | numba kernels: priority-flood + Rho8 routing, implicit stream power with critical slopes, diffusion, talus, chamfer |
| `xyterrain/geology.py` | rock table (K, Sc, talus, D, operator), the plan, fold beds, faults (with tips), painted uplift and ridges |
| `xyterrain/landforms.py` | the operators and their defaults (`DEFAULTS`), rock instance kinds |
| `xyterrain/sculpt.py` | the pipeline (uplift → calibrate K0 → solve → envelope → operators → glacial → talus → preserve) |
| `xyterrain/fengshui.py` | the geomancer (polar sampling + widest-path 龙脉) |
| `xyterrain/noise.py`, `fields.py`, `preview.py` | simplex / fbm / ridged / Worley; filters; shaded-relief previews |

The Blender half of the round trip is `tools/blender/terrain_edit.py` / `terrain_bake.py`; the Godot side is
`--terrain=<dir>` (`godot/scripts/autoload/world.gd`, `scripts/world/rocks.gd`, `rock_kit.gd`).
