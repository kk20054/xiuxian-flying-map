# 01 · The terrain today: how it is built, how it is edited, what it lacks

This chapter summarises how the demo makes its land and what "editing the level" means right now. It is the baseline the
geological re-sculpt ([04 · tools](04-tools.md)) builds on. The full algorithmic detail is in
[docs/03-terrain-generation.md](../03-terrain-generation.md) (03a relief, 03l sect landforms) and
[docs/02-world-data-and-coordinates.md](../02-world-data-and-coordinates.md) (GEO data, layout, CONFIG).

## 1. The layers, bottom to top

| # | layer | what it is | where (demo `index.html`) | editable how |
|---|---|---|---|---|
| 1 | **GEO** | the traced 舆图: coast polygon, river polylines, the selfmate *mountain-density* raster, pins | §00, L282–309 | edit the arrays (base-map px) |
| 2 | **Layout** | pins → world positions (k = 58.06 丈/px), sect sites, landmarks (`LAYOUT.marks`), cities | `computeLayout` L394–434 | edit pins |
| 3 | **Designed shapes** | lobed peaks `(1−q^a)^b`, landmark shapes (天柱山 pillar, 子母峰…), city hills (背山面水) | `makePeak` L1188, `markHeight` L1615, `cityHillU` | edit `SITE_DEFS` / mark types |
| 4 | **03a relief** | steady-state **stream-power** erosion: density → uplift U, rock K = noise, priority-flood routing, 5 rounds, 6 diffusion passes, p97 → 540 丈, soft cap 950 | L2381–2660 | `CONFIG.relief` (cell 100, m 0.45, trend 15°, rock, grain…) |
| 5 | **03l sect landforms** | a 15-丈 grid per sect disc (1.5–1.6 R): fine drainage high-pass, two-anchor remap to the cloud level, one of six rock styles (pillars, granite, volcanic, karst, hill, loess), benches and pads for the halls | L3729–4206 | `SITE_DEFS[*].land` + `NAT_STYLES` |
| 6 | **Heightfield** | `baseHeight` on the 40-丈 grid (3296 × 2005), then streams and water carved in | `buildHeightfield` L1783, `carveStreams` | — |
| 7 | **Zoning** | biome classes (17), seasons, ground map, trees from the final heights | 03b–03d | rules in code |

Everything is deterministic (fixed hashes and seeds), which is why the exporter can dump the arrays and the Godot port
gets an identical world (`godot/data/world`, written by `tools/export-world`).

## 2. What "editing the level" means today

- **Where things are** (coast, rivers, sect sites, landmarks): edit the GEO arrays or pins in `index.html` and reload —
  no visual editor, no undo, one 40-s rebuild per try.
- **How mountainous a region is**: the selfmate density raster plus `CONFIG.relief` keys. There is one structural grain
  for the whole map (`trend` 15°) and rock hardness is a noise field, not a geological map.
- **A sect's own ground**: `SITE_DEFS` masses (u, v, r, h), benches, pads, lake / face / tower-field definitions and the
  style in `NAT_STYLES` — careful hand-written data, only inside each sect's disc.
- **Runtime tuning**: the debug panel (山高倍数, 山体柔和, 皴笔 …) — live, but not saved and not shape-changing.
- **Godot port**: reads the export; no terrain editing. **Blender** (`tools/blender/import_world.py`): imports a region to
  look at and to model sects on, but nothing comes back.

So there is no round trip: you cannot paint where limestone is, draw a fault, sculpt a valley in Blender and see it in
the game. That is what the new tools add ([04](04-tools.md)).

## 3. What is good (and kept)

- **Drainage-consistent mountains.** The 03a model is real geomorphology (Braun & Willett 2013 FastScape solution,
  Barnes 2014 priority-flood): every valley drains somewhere, ridges are divides, tributaries join at the right angles.
  The new pipeline keeps this physics and extends it ([02](02-landforms.md) §1).
- **Designed sect sites** on fine grids, with halls, benches and pads that the sect meshes sit on. The re-sculpt
  preserves them exactly (`World.preserve_mask`: patch rects + 420 丈, feathered over 900 丈; city cores; landmark marks).
- **A real-scale macro relief.** p97 540 丈 ≈ 1 800 m, cap 950 丈 ≈ 3 200 m, sect cloud tops 472–482 丈 ≈ 1 600 m — the
  band where only Huangshan's main summits clear the cloud sea ([research r3](research/r3_landform_geology.md), Part 3).

## 4. What is missing (measured on the exported heightfield)

![exported terrain, shaded relief](img/current_hillshade.png)

| # | issue | evidence | consequence |
|---|---|---|---|
| 1 | **One rock everywhere** outside the six sect discs | K = `exp(0.55·fbm + 0.18·sin)`; no lithology map | no hard caps, no karst, no Danxia, no granite batholith — ranges all read alike |
| 2 | **One structural grain** | `CONFIG.relief.trend = 15°` for every range | no fold belts with their own strike, no trellis drainage, no hogbacks |
| 3 | **No faults or basins** | uplift = density only | no range-front scarps, no grabens; 绿踪沼泽 is a flat disc painted onto the relief |
| 4 | **Flat plains** | 89 % of all samples ≤ 0 丈 (sea included); plain cells are exactly 0 | no alluvial fans at the range fronts, no river terraces, no swell between rivers |
| 5 | **Artificial islands** | 七灵岛: seven lobed cones with 8-pointed "star" crests | reads as stamps, not as young volcanoes |
| 6 | **Rock styles only inside the discs** | `S.land.R` ≈ 2 000 丈 | the 水影宗 karst stops at its disc edge; nothing karstic anywhere else |
| 7 | **Scale of vertical forms** | karst towers 70–210 丈 (233–700 m) vs Guilin plain towers 30–80 m; pillar spacing 2–3 × sparser than Wulingyuan (r3 Part 3) | towers read as mountains |
| 8 | **Sub-grid features** | the 40-丈 grid cannot hold pillars 10–30 丈 across, stone forests, sea stacks | they need meshes standing on the heightfield |
| 9 | **A data bug** | the exporter wrote 16-bit PNGs byte-swapped (height.png, patches, water_sd.png) | fixed in `export_world.js`, shipped files repaired (commit "export-world: 16-bit PNGs…") |

The rest of this folder answers each row: the geology to use ([02](02-landforms.md)), the plan for this map and its canon
([03](03-world-plan.md)), the tools ([04](04-tools.md)) and how other projects solve the same problems ([05](05-other-projects.md)).
