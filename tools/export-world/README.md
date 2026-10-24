# export-world

Runs the Three.js demo headless and writes the world it generates to `godot/data/world/` (or `--out`).

```bash
npm install          # playwright, three@0.170.0 (the demo's version), pngjs — and Chromium via playwright
npm run export       # ~2–4 min
node export_world.js --eco --terrain-mesh --out /tmp/world --demo ../../demo
```

| flag | |
|---|---|
| `--out <dir>` | output folder (default `../../godot/data/world`) |
| `--demo <dir>` | the demo folder (default `../../demo`) |
| `--no-meshes` | skip the GLBs |
| `--eco` | also `eco.bin`: the 443 k ground-plant cards of `WORLD.ecoGround` (meadows, verges, village gardens; not the 1.33 M eco-tree cards), float32 × 10 each: model id (`meta.eco.names`), x, y, z, scale, tint r g b + grey, ground flag |
| `--terrain-mesh` | also `meshes/terrain.glb`: the demo's faceted terrain tiles, finest level (≈ 80 MB), listed as `meta.meshes.terrain` (not in `files`, which `props.gd` draws with the facet shader) |

How it works: serves `demo/` on a free port, routes the page's jsDelivr three.js import to `node_modules/three`, loads
`index.html?test` (no render loop), wraps `window.__ym.WORLD.trees` / `.ecoGround` with setters to keep the lists the
demo frees after building, waits for `__ym.loaded`, then reads the arrays out of the page in base64 slices and writes
PNG / raw / JSON / GLB. Before the meshes it renders one frame (`__ym.render(1)`), so what the demo poses per frame
(floating stones, boats) is in place; 水影宗's mirror copies are skipped. The file formats are documented at the top of `export_world.js` and in
[docs/godot/01-pipeline-and-blender.md](../../docs/godot/01-pipeline-and-blender.md).

Needs a machine where Chromium can start (SwiftShader software WebGL is fine; it is what CI-less runs use).

## Known issues in the shipped export (fixed in the exporter; re-export to clear)

The data in `godot/data/world` was written before these exporter fixes. What could be repaired exactly by hand was
(listed in `meta.json → repaired`): `sect_shuiying_surroundings.glb` taken out of `meta.meshes.files` and deleted, `meta.eco`, `meta.water.sd.centres`, the darkened tile-edge lines of
`mountain_color.png` (restored to within one colour level) and `layout.json → sites[].look`. Still in the shipped
files until the next `npm run export`:

- **`sect_shuiying_surroundings.glb`** (deleted) held only exact copies of `sect_shuiying.glb` and
  `sect_shuiying_ground.glb` (水影宗's mirror images, buildMirrors L5842–5853, share their geometry and reflect only in
  their shader; 127 k triangles). A re-export no longer writes it.
- **Per-frame-posed meshes at their unposed place.** `?test` never runs a frame, so 天柱山's nine floating stones
  (updateLore L11308–11312, nodes 10–18 of `sect_gujian_surroundings.glb`) sit at the world origin, buried, and so do
  nodes 7–8 (two small pieces with no transform, most likely 水影宗's two 灵舟, which updateSects L8403 places). The
  exporter now renders one frame first and takes every world matrix fresh (a mesh under a positioned group, like the
  demo's yawed wheels, would otherwise lose the group's offset).
- **Misfiled anim pieces.** Meshes were sorted by their *local* bounding-sphere centre, so every piece built at its own
  origin and then positioned (the sects' turning and bobbing pieces) went to the sect nearest the world origin, 古剑门:
  e.g. nodes 5–6 of `sect_gujian_surroundings.glb` stand at 鸾鸣宗 (x ≈ 70 400). Godot draws them in the right place
  (the node transforms are right); only the per-sect grouping is wrong, so `import_world.py --sect luanming` drags in
  the whole 古剑门 surroundings file.
- `water_sd.png` point-samples mask texel (2i, 2j) instead of averaging the 2×2 block (centres in `meta.water.sd`).
- `mountain_color.png`'s repaired lines may differ from a fresh export by one level per channel (the skirt colour was
  `round(col × 0.8)`, so the original is ambiguous by one step).
