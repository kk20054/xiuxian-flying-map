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
| `--eco` | also `eco.bin`: the 1.77 M Meadow ground cards (model id, x, y, z, scale, tint) |
| `--terrain-mesh` | also `meshes/terrain.glb`: the demo's faceted terrain tiles, finest level (≈ 80 MB) |

How it works: serves `demo/` on a free port, routes the page's jsDelivr three.js import to `node_modules/three`, loads
`index.html?test` (no render loop), wraps `window.__ym.WORLD.trees` / `.ecoGround` with setters to keep the lists the
demo frees after building, waits for `__ym.loaded`, then reads the arrays out of the page in base64 slices and writes
PNG / raw / JSON / GLB. The file formats are documented at the top of `export_world.js` and in
[docs/godot/01-pipeline-and-blender.md](../../docs/godot/01-pipeline-and-blender.md).

Needs a machine where Chromium can start (SwiftShader software WebGL is fine; it is what CI-less runs use).
