#!/usr/bin/env node
// Export the world the Three.js demo generates into files Godot and Blender can read.
//
// The demo builds everything procedurally at boot (heights, rivers, roads, zoning, trees, sect and city meshes). Rather than
// re-implementing ~15k lines of generation, this runs the demo headless in Chromium, waits for it to finish building, and reads
// its arrays straight out of memory through the demo's own test hook (window.__ym).
//
//   node export_world.js [--demo ../../demo] [--out ../../godot/data/world] [--no-meshes] [--eco] [--terrain-mesh]
//
// Output (all world positions in 丈, the demo's unit; +x east, +z south, +y up; origin = the centre of the 云梦 three sects):
//   meta.json            rect, grid sizes, value ranges, layout constants, the demo's CONFIG, biome names/colours, stats
//   height.png           16-bit grey, the heightfield on the 40-丈 grid (h = v / 65535 * meta.height.max)
//   height_patch_N.png   16-bit grey, the 13.3-丈 detail patches around the six sects (same encoding, own rect in meta)
//   height_f16.bin       the same heights as raw IEEE half floats (Godot reads these directly; also height_patch_N_f16.bin)
//   mountain_color.png   RGBA8 on the height grid: the mountains' colour ramp read back from the demo's terrain tiles
//   water_tex.png        RGBA8, the demo's packed water texture (R shore distance, GB flow, A sea) — what its water shader samples
//   water_mask.png       8-bit, water coverage (sea, rivers, lakes, moats) over the world rect
//   water_sd.png         16-bit, signed distance to the shore (+ in water): d = (v - 32768) / 8 丈, half the mask's resolution
//   sea_depth.png        8-bit, 0 inland water .. 255 open sea (the water sheet sinks from water.depth to water.seaDepth)
//   biome.png            8-bit biome id per cell (meta.biome.names), biome_preview.png the same in the demo's debug colours
//   ground.png           RGBA: R woods, G fields, B bare ground of yards/lanes, A the lie of the fields
//   places.json          the 28 places (sects, cities, secret realms, mountains...) with names, texts and world positions
//   paths.json           roads, rivers, streams (polylines [x, z, (y)]), bridges, villages
//   layout.json          sect sites, landmarks, peaks, pools, falls, moats, clusters
//   trees.bin            8 bytes per tree: uint16 x, z over the rect, uint8 kind, colour, yaw, scale (meta.trees)
//   eco.bin              (--eco) float32 × 7 per ground plant card: model id, x, y, z, scale, tint, 1  (meta.eco.names)
//   meshes/*.glb         the procedural sect and city meshes and landmarks (vertex layout below); --terrain-mesh adds
//                        meshes/terrain.glb, the demo's own faceted terrain tiles (finest level, ~1.5M triangles, indexed)
//
// Vertex layout of the exported facet meshes (so the ink-line shader survives the trip through glTF):
//   POSITION, NORMAL (flat), COLOR_0.rgb = face colour, COLOR_0.a = ink weight of the edge opposite corner C,
//   TEXCOORD_0 = barycentric (x, y) of the corner (z = 1 - x - y), TEXCOORD_1 = ink weights of the edges opposite corners A, B.
const http = require('http'), fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const { PNG } = require('pngjs');

const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : d; };
const DEMO = path.resolve(__dirname, arg('--demo', '../../demo'));
const OUT = path.resolve(__dirname, arg('--out', '../../godot/data/world'));
const MESHES = !process.argv.includes('--no-meshes'), ECO = process.argv.includes('--eco'), TERRAIN_MESH = process.argv.includes('--terrain-mesh');
const THREE_DIR = path.join(__dirname, 'node_modules', 'three');
fs.mkdirSync(path.join(OUT, 'meshes'), { recursive: true });

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp' };
const server = http.createServer((q, r) => {
  const f = path.join(DEMO, decodeURIComponent(q.url.split('?')[0]).replace(/^\/$/, '/index.html'));
  if (!f.startsWith(DEMO)) { r.writeHead(403); return r.end(); }
  fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); r.end(); } else { r.writeHead(200, { 'content-type': TYPES[path.extname(f)] || 'application/octet-stream' }); r.end(d); } });
});

const write = (name, buf) => { fs.writeFileSync(path.join(OUT, name), buf); console.log('  wrote', name, (buf.length / 1048576).toFixed(1), 'MB'); };
// float32 → IEEE half (Godot reads these straight into an Image with FORMAT_RH; its PNG loader would strip 16-bit PNGs to 8 bits)
function toHalf(f32) {
  const out = Buffer.alloc(f32.length * 2), fb = new Float32Array(1), ib = new Uint32Array(fb.buffer);
  for (let i = 0; i < f32.length; i++) {
    fb[0] = f32[i]; const x = ib[0], s = (x >>> 16) & 0x8000; let e = ((x >>> 23) & 0xff) - 127 + 15, m = x & 0x7fffff, h;
    if (e <= 0) h = s; else if (e >= 31) h = s | 0x7c00; else { h = s | (e << 10) | (m >>> 13); if (m & 0x1000) h++; }
    out.writeUInt16LE(h, i * 2);
  }
  return out;
}
const json = (name, obj) => write(name, Buffer.from(JSON.stringify(obj, null, 1)));
function png(name, w, h, data, { bits = 8, channels = 1 } = {}) {
  const p = new PNG({ width: w, height: h, bitDepth: bits, colorType: channels === 4 ? 6 : 0, inputColorType: channels === 4 ? 6 : 0, inputHasAlpha: channels === 4 });
  p.data = Buffer.from(data.buffer, data.byteOffset, data.byteLength);
  // 16-bit: pngjs reads the samples as a platform-endian Uint16Array over the whole buffer (from offset 0) and writes
  // them big-endian itself, so hand it an unshared copy — swapping here would store every sample byte-swapped
  if (bits === 16) p.data = Buffer.from(new Uint16Array(data).buffer);
  write(name, PNG.sync.write(p, { bitDepth: bits, colorType: channels === 4 ? 6 : 0, inputColorType: channels === 4 ? 6 : 0, inputHasAlpha: channels === 4 }));
}

(async () => {
  await new Promise((ok) => server.listen(0, ok));
  const port = server.address().port;
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 640, height: 400 } });
  page.on('console', (m) => { if (/^YM|rror/.test(m.text())) console.log('  [demo]', m.text().slice(0, 200)); });
  // the demo imports three.js from jsDelivr; serve it from node_modules instead (same version, works offline)
  await page.route(/cdn\.jsdelivr\.net\/npm\/three@0\.170\.0\/(.*)/, (rt) => rt.fulfill({ path: path.join(THREE_DIR, rt.request().url().replace(/.*three@0\.170\.0\//, '')), contentType: 'text/javascript' }));
  // the tree and ground-plant lists are dropped once they are in the instance buffers: keep a copy as they are set
  await page.addInitScript(() => {
    let ym;
    Object.defineProperty(window, '__ym', { configurable: true, get: () => ym, set(v) {
      ym = v;
      const W = v.WORLD; let trees = null, eco = null;
      Object.defineProperty(W, 'trees', { get: () => trees, set(t) { trees = t; if (t) window.__keepTrees = t; } });
      Object.defineProperty(W, 'ecoGround', { get: () => eco, set(t) { eco = t; if (t) window.__keepEco = t; } });
    } });
  });
  console.log('booting the demo (about a minute in software rendering)...');
  await page.goto(`http://localhost:${port}/?test`, { timeout: 120000 });
  await page.waitForFunction(() => window.__ym && (window.__ym.loaded || window.__ym.error), null, { timeout: 900000, polling: 1000 });
  const err = await page.evaluate(() => window.__ym.error);
  if (err) throw new Error(err);

  // binary transfer: the page hands back base64 slices of a typed array it parked on window
  async function pull(expr, Type) {
    const n = await page.evaluate((e) => { const a = eval(e); window.__pull = new Uint8Array(a.buffer, a.byteOffset, a.byteLength); return window.__pull.length; }, expr);
    const out = Buffer.alloc(n), step = 4 << 20;
    for (let s = 0; s < n; s += step) {
      const b64 = await page.evaluate(([s, e]) => { const u = window.__pull.subarray(s, e); let t = ''; for (let i = 0; i < u.length; i += 0x8000) t += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000)); return btoa(t); }, [s, Math.min(n, s + step)]);
      Buffer.from(b64, 'base64').copy(out, s);
    }
    return new Type(out.buffer, out.byteOffset, n / Type.BYTES_PER_ELEMENT);
  }

  console.log('reading the world...');
  const meta = await page.evaluate(() => {
    const Y = window.__ym, W = Y.WORLD, L = Y.LAYOUT;
    const strip = (o) => JSON.parse(JSON.stringify(o, (k, v) => (typeof v === 'function' ? undefined : v instanceof Object && v.isVector3 ? [v.x, v.y, v.z] : v)));
    // the heightfield, with the six sect patches folded into their own (finer) grids
    let hmax = 0; for (let i = 0; i < W.H.length; i++) if (W.H[i] > hmax) hmax = W.H[i];
    for (const P of W.patches) for (let i = 0; i < P.H.length; i++) if (P.H[i] > hmax) hmax = P.H[i];
    hmax = Math.ceil(hmax + 1);
    const q16 = (H) => { const o = new Uint16Array(H.length); for (let i = 0; i < H.length; i++) o[i] = Math.round((Math.max(0, H[i]) / hmax) * 65535); return o; };
    window.__h16 = q16(W.H); window.__p16 = W.patches.map((P) => q16(P.H));
    // shore distance at half the mask's resolution, as 16-bit (+32768 bias, 1/8 丈 steps — the demo's own quantum)
    const mw = W.maskW >> 1, mh = W.maskH >> 1, sd = new Uint16Array(mw * mh);
    for (let j = 0; j < mh; j++) for (let i = 0; i < mw; i++) sd[j * mw + i] = Math.max(0, Math.min(65535, W.sd[(j * 2) * W.maskW + i * 2] + 32768));
    window.__sd16 = sd;
    window.__biome = W.biome.id instanceof Uint8Array ? W.biome.id : Uint8Array.from(W.biome.id);
    const prev = document.createElement('canvas'); window.__biomePrev = Y.biomeMap(1);
    return {
      units: '丈 (1 丈 ≈ 3.33 m). +x east, +z south, +y up. Origin: the centre of the 云梦 three sects.',
      rect: W.rect, startPos: L.startPos,
      layout: { S: L.S, k: L.k, origin: L.origin, note: 'world = (basemap_px - origin) * k; basemap px are the 1490x812 云梦山 screenshot of selfmate 人界舆图' },
      height: { file: 'height.png', w: W.nx, h: W.nz, cell: W.g, x0: W.rect.x0, z0: W.rect.z0, max: hmax, encoding: 'uint16 grey, h = v / 65535 * max; sample (i, j) sits at (x0 + i*cell, z0 + j*cell)' },
      patches: W.patches.map((P, k) => ({ file: `height_patch_${k}.png`, w: P.nx, h: P.nz, cell: P.g, x0: P.x0, z0: P.z0, x1: P.x1, z1: P.z1 })),
      water: { mask: { file: 'water_mask.png', w: W.maskW, h: W.maskH }, sd: { file: 'water_sd.png', w: mw, h: mh, encoding: 'uint16, d = (v - 32768) / 8 丈, + inside water' }, seaDepth: { file: 'sea_depth.png', w: W.seaLo.w, h: W.seaLo.h }, depth: Y.CONFIG.water.depth, seaDepthMax: Y.CONFIG.water.seaDepth, note: 'pixel centres: x = rect.x0 + (i + 0.5) / w * (rect.x1 - rect.x0)' },
      biome: { file: 'biome.png', w: W.biome.w, h: W.biome.h, names: ['海', '海滩', '河滩', '沼泽', '花海', '草甸', '农田', '村镇', '阔叶林', '针叶林', '竹林', '崖壁', '高山', '灵地', '宗门', '谷地', '荒原'], colors: ['#3d6f8e', '#e2d3a2', '#bfc9a0', '#5b6b3a', '#e6a1c4', '#9fcf6a', '#d8c26a', '#b07a55', '#3f7d3a', '#2f5b44', '#7fb36a', '#8a8a86', '#eef2f4', '#8fd6d0', '#c94f3d', '#5fae4e', '#d6c08a'], stats: W.stats.biome },
      ground: { file: 'ground.png', w: W.ground.w, h: W.ground.h, channels: 'R woods, G fields, B bare ground (yards, lanes), A the lie of the fields' },
      trees: { file: 'trees.bin', stride: 7, fields: ['x', 'y', 'z', 'scale', 'kind', 'colour', 'yaw'], count: window.__keepTrees ? window.__keepTrees.length / 7 : 0 },
      eco: { stride: 7, fields: ['model', 'x', 'y', 'z', 'scale', 'tint', 'flag'], count: window.__keepEco ? window.__keepEco.length / 7 : 0 },
      config: strip(Y.CONFIG),
      stats: strip(W.stats),
    };
  });
  // places, paths, layout: plain JSON
  const extra = await page.evaluate(() => {
    const Y = window.__ym, W = Y.WORLD, r1 = (v) => Math.round(v * 10) / 10;
    const strip = (o) => JSON.parse(JSON.stringify(o, (k, v) => (typeof v === 'function' ? undefined : v && v.isVector3 ? [r1(v.x), r1(v.y), r1(v.z)] : typeof v === 'number' ? r1(v) : v)));
    const pts = (P) => P.map((p) => p.map(r1));
    return {
      places: strip(Y.POIS),
      paths: {
        roads: W.roads.map((r) => ({ kind: r.kind, w: r.w, pts: pts(r.pts) })),
        rivers: W.rivers.map((r) => ({ name: r.name, great: !!r.great, pts: pts(r.pts) })),
        streams: W.streams.map((s) => ({ ended: s.ended, w: s.w, area: s.area, pts: pts(s.pts) })),
        bridges: W.bridges.map((b) => ({ road: W.roads.indexOf(b.road), a: b.a, b: b.b, p0: b.p0.map(r1), p1: b.p1.map(r1) })),
        villages: W.villages.map((v) => ({ x: r1(v.x), z: r1(v.z), n: v.n, yaw: v.yaw, seed: v.seed, road: W.roads.indexOf(v.road), at: v.at })),
      },
      layout: { sects: strip(Y.dev.sects()), marks: strip(Y.dev.marks()), peaks: strip(W.peaks.slice(0, 4000)), pools: strip(W.pools), falls: strip(W.falls), moats: strip(W.moats), clusters: strip(W.clusters), mainPeak: strip(W.mainPeak), pillar: strip(W.pillar), vortex: strip(W.vortex) },
    };
  });
  // the sect sites (centre, radius, look, cloud-sea top) and the cloud sea's planned density grid (07c)
  extra.layout.sites = await page.evaluate(() => window.__ym.WORLD.sites.map((S) => ({ id: S.id, x: Math.round(S.x * 10) / 10, z: Math.round(S.z * 10) / 10, R: S.R, look: S.look, cloud: S.cloud, base: S.base })));
  json('places.json', extra.places); json('paths.json', extra.paths); json('layout.json', extra.layout);
  const cs = await page.evaluate(() => { const P = window.__ym.WORLD.cloudSea; window.__cs = P.data; return { w: P.w, h: P.h, c: P.c }; });
  meta.cloudSea = { file: 'cloud_sea.png', w: cs.w, h: cs.h, cell: cs.c, encoding: '8-bit planned density over the world rect (0 = open sky, 255 = full sea)' };
  png('cloud_sea.png', cs.w, cs.h, await pull('window.__cs', Uint8Array));

  // the mountains' colour ramp (facetColor: 赭石 foot → 石绿 flanks → 石青 tops → snow), read back from the terrain tiles' vertex colours
  // onto the 40-丈 grid; A = 255 where a tile has a vertex (mountain), 0 on the plain (the plain has its own shader colours)
  const colInfo = await page.evaluate(() => {
    const Y = window.__ym, W = Y.WORLD, R = W.rect, g = W.g, nx = W.nx, nz = W.nz, out = new Uint8Array(nx * nz * 4);
    let scene = Y.LAND.chunks[0]; while (scene.parent) scene = scene.parent;
    const seen = new Set(); let n = 0;
    scene.traverse((o) => {
      if (!o.isMesh || o.isInstancedMesh) return; const a = o.geometry.attributes;
      if (!(a.aCol && a.aN && !a.bary && o.geometry.index) || seen.has(a.position)) return; seen.add(a.position);
      const P = a.position.array, C = a.aCol.array;
      for (let v = 0; v < a.position.count; v++) {
        const i = Math.round((P[v * 3] - R.x0) / g), j = Math.round((P[v * 3 + 2] - R.z0) / g);
        if (i < 0 || j < 0 || i >= nx || j >= nz) continue;
        const k = (j * nx + i) * 4; if (out[k + 3] && P[v * 3 + 1] < -30) continue;   // skirt vertices (sunk 70, darker) never overwrite
        out[k] = C[v * 3]; out[k + 1] = C[v * 3 + 1]; out[k + 2] = C[v * 3 + 2]; out[k + 3] = 255; n++;
      }
    });
    window.__mcol = out; return { w: nx, h: nz, tiles: seen.size, verts: n };
  });
  meta.mountainColor = { file: 'mountain_color.png', w: colInfo.w, h: colInfo.h, cell: meta.height.cell, encoding: 'RGBA8 on the height grid: rgb = the demo facetColor ramp (display-space sRGB), a = 255 where mountains are' };
  png('mountain_color.png', colInfo.w, colInfo.h, await pull('window.__mcol', Uint8Array), { channels: 4 });

  png('height.png', meta.height.w, meta.height.h, await pull('window.__h16', Uint16Array), { bits: 16 });
  write('height_f16.bin', toHalf(await pull('window.__ym.WORLD.H', Float32Array)));
  meta.height.raw = { file: 'height_f16.bin', format: 'IEEE half, little-endian, row-major w×h, value = height in 丈 (Godot: Image.create_from_data(w, h, false, Image.FORMAT_RH, bytes))' };
  for (let k = 0; k < meta.patches.length; k++) { meta.patches[k].raw = `height_patch_${k}_f16.bin`; write(meta.patches[k].raw, toHalf(await pull(`window.__ym.WORLD.patches[${k}].H`, Float32Array))); }
  png('water_tex.png', meta.water.mask.w, meta.water.mask.h, await pull('window.__ym.WORLD.waterData', Uint8Array), { channels: 4 });
  meta.water.tex = { file: 'water_tex.png', w: meta.water.mask.w, h: meta.water.mask.h, encoding: "the demo's own water texture: R shore distance (128 = shore, 2 丈 per step, > 128 in water), G/B drift/flow (128 = still), A sea factor" };
  for (let k = 0; k < meta.patches.length; k++) png(meta.patches[k].file, meta.patches[k].w, meta.patches[k].h, await pull(`window.__p16[${k}]`, Uint16Array), { bits: 16 });
  png('water_mask.png', meta.water.mask.w, meta.water.mask.h, await pull('window.__ym.WORLD.mask', Uint8Array));
  png('water_sd.png', meta.water.sd.w, meta.water.sd.h, await pull('window.__sd16', Uint16Array), { bits: 16 });
  png('sea_depth.png', meta.water.seaDepth.w, meta.water.seaDepth.h, await pull('window.__ym.WORLD.seaLo.m', Uint8Array));
  png('biome.png', meta.biome.w, meta.biome.h, await pull('window.__biome', Uint8Array));
  // the ground shader's own inputs (03c/03d): biome weights (R flowers, G sand, B marsh, A lushness), the flower drifts
  // (rgb the dominant flower's colour, a the drift) and the seasons (R winter, G autumn, B spirit land, A dry steppe)
  const bt = await page.evaluate(() => { const B = window.__ym.WORLD.biome, S = window.__ym.WORLD.season; return { w: B.w, h: B.h, w2: B.w2, h2: B.h2, sw: S.w, sh: S.h }; });
  png('biome_weights.png', bt.w, bt.h, await pull('window.__ym.WORLD.biome.tex', Uint8Array), { channels: 4 });
  png('flower_drift.png', bt.w2, bt.h2, await pull('window.__ym.WORLD.biome.tex2', Uint8Array), { channels: 4 });
  png('season.png', bt.sw, bt.sh, await pull('window.__ym.WORLD.season.data', Uint8Array), { channels: 4 });
  meta.biome.weights = { file: 'biome_weights.png', w: bt.w, h: bt.h, channels: 'R flower field, G sand/pebbles, B marsh, A lushness' };
  meta.biome.drift = { file: 'flower_drift.png', w: bt.w2, h: bt.h2, channels: 'rgb dominant flower colour, a drift' };
  meta.season = { file: 'season.png', w: bt.sw, h: bt.sh, channels: 'R winter, G autumn, B spirit land, A dry steppe' };
  png('ground.png', meta.ground.w, meta.ground.h, await pull('window.__ym.WORLD.ground.data', Uint8Array), { channels: 4 });
  write('biome_preview.png', Buffer.from((await page.evaluate(() => window.__biomePrev)).split(',')[1], 'base64'));
  if (meta.trees.count) {
    // 8 bytes per tree: uint16 x, uint16 z (over the world rect), uint8 kind, uint8 colour, uint8 yaw (×2π/256), uint8 scale (×scaleMax/255)
    // — y is left out: plant each tree on the heightfield (the demo puts them at hAt(x, z), sunk a little)
    const q = await page.evaluate(() => {
      const T = window.__keepTrees, R = window.__ym.WORLD.rect, n = T.length / 7, b = new ArrayBuffer(n * 8), v = new DataView(b);
      let smax = 0; for (let i = 0; i < n; i++) smax = Math.max(smax, T[i * 7 + 3]);
      const kinds = {};
      for (let i = 0; i < n; i++) {
        const o = i * 7, ux = (T[o] - R.x0) / (R.x1 - R.x0), uz = (T[o + 2] - R.z0) / (R.z1 - R.z0);
        v.setUint16(i * 8, Math.round(Math.min(1, Math.max(0, ux)) * 65535), true); v.setUint16(i * 8 + 2, Math.round(Math.min(1, Math.max(0, uz)) * 65535), true);
        v.setUint8(i * 8 + 4, T[o + 4]); v.setUint8(i * 8 + 5, T[o + 5]); v.setUint8(i * 8 + 6, Math.round((((T[o + 6] % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI)) / (2 * Math.PI) * 255));
        v.setUint8(i * 8 + 7, Math.round((T[o + 3] / smax) * 255)); kinds[T[o + 4]] = (kinds[T[o + 4]] || 0) + 1;
      }
      window.__treeQ = new Uint8Array(b); return { smax, kinds };
    });
    meta.trees = { file: 'trees.bin', count: meta.trees.count, bytesPerTree: 8, layout: 'uint16 x, uint16 z (0..65535 over rect), uint8 kind, uint8 colour, uint8 yaw (v/256*2π), uint8 scale (v/255*scaleMax), little-endian', scaleMax: q.smax, kinds: q.kinds };
    write('trees.bin', Buffer.from((await pull('window.__treeQ', Uint8Array)).buffer));
  }
  if (ECO && meta.eco.count) { meta.eco.file = 'eco.bin'; write('eco.bin', Buffer.from((await pull('Float32Array.from(window.__keepEco)', Float32Array)).buffer)); }

  if (MESHES) {
    console.log('exporting meshes...');
    // (in the page) turn each facet mesh into a plain glTF mesh with the vertex layout described at the top, and export GLB
    await page.evaluate((t) => { window.__terrainMesh = t; }, TERRAIN_MESH);
    const list = await page.evaluate(async () => {
      const THREE = await import('three');
      const { GLTFExporter } = await import('three/addons/exporters/GLTFExporter.js');
      const Y = window.__ym, out = [];
      // a facet mesh (FacetBuf: unindexed, per-corner barycentrics + per-edge ink) → glTF with the layout at the top of this file.
      // Compact types: COLOR_0 as normalised uint8 RGBA, TEXCOORD_0/1 as normalised uint16 (both allowed by core glTF 2.0)
      const facet = (src, name) => {
        const a = src.geometry.attributes; if (!a.position || !a.aCol || !a.bary) return null;
        const g = src.geometry.index ? src.geometry.toNonIndexed() : src.geometry, A = g.attributes, n = A.position.count;
        const col = new Uint8Array(n * 4), uv0 = new Uint16Array(n * 2), uv1 = new Uint16Array(n * 2), C = A.aCol, B = A.bary, K = A.crease;
        const u8 = (v) => Math.round(Math.min(1, Math.max(0, v)) * 255), u16 = (v) => Math.round(Math.min(1, Math.max(0, v)) * 65535);
        for (let i = 0; i < n; i++) {
          col[i * 4] = u8(C.getX(i)); col[i * 4 + 1] = u8(C.getY(i)); col[i * 4 + 2] = u8(C.getZ(i)); col[i * 4 + 3] = K ? u8(K.getZ(i)) : 0;
          uv0[i * 2] = u16(B.getX(i)); uv0[i * 2 + 1] = u16(B.getY(i));
          uv1[i * 2] = K ? u16(K.getX(i)) : 0; uv1[i * 2 + 1] = K ? u16(K.getY(i)) : 0;
        }
        const e = new THREE.BufferGeometry();
        e.setAttribute('position', new THREE.BufferAttribute(new Float32Array(A.position.array), 3));
        e.setAttribute('color', new THREE.BufferAttribute(col, 4, true)); e.setAttribute('uv', new THREE.BufferAttribute(uv0, 2, true)); e.setAttribute('uv1', new THREE.BufferAttribute(uv1, 2, true));
        e.computeVertexNormals();   // unindexed: these are the flat facet normals
        const m = new THREE.Mesh(e, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 1, metalness: 0, name: 'facet' }));
        m.name = name; src.updateMatrixWorld(); m.applyMatrix4(src.matrixWorld);
        return m;
      };
      // a terrain tile (04: one shared vertex buffer, three index buffers for the detail levels) → indexed glTF, finest level only
      const tile = (src) => {
        const a = src.geometry.attributes, n = a.position.count, e = new THREE.BufferGeometry();
        const col = new Uint8Array(n * 4), nrm = new Float32Array(n * 3);
        for (let i = 0; i < n; i++) { col[i * 4] = a.aCol.array[i * 3]; col[i * 4 + 1] = a.aCol.array[i * 3 + 1]; col[i * 4 + 2] = a.aCol.array[i * 3 + 2]; col[i * 4 + 3] = 0;
          const x = a.aN.getX(i), y = a.aN.getY(i), z = a.aN.getZ(i), l = Math.hypot(x, y, z) || 1; nrm[i * 3] = x / l; nrm[i * 3 + 1] = y / l; nrm[i * 3 + 2] = z / l; }
        e.setAttribute('position', new THREE.BufferAttribute(new Float32Array(a.position.array), 3)); e.setAttribute('normal', new THREE.BufferAttribute(nrm, 3));
        e.setAttribute('color', new THREE.BufferAttribute(col, 4, true)); e.setIndex(new THREE.BufferAttribute(Uint32Array.from(src.geometry.index.array), 1));
        const m = new THREE.Mesh(e, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 1, metalness: 0, name: 'terrain' }));
        src.updateMatrixWorld(); m.applyMatrix4(src.matrixWorld); m.name = 'tile'; return m;
      };
      // the scene is not on the test hook, but every terrain chunk hangs off it
      let scene = Y.LAND.chunks[0]; while (scene.parent) scene = scene.parent;
      const city = new Set(Y.CITY.meshes || []), props = new Set(Y.PROPS.meshes || []), land = new Set([...(Y.LAND.chunks || []), Y.LAND.plains, Y.LAND.banks]);
      const groups = {}, sects = Y.dev.sects(), tiles = new Map();
      const nearest = (o, max) => { const b = o.geometry.boundingSphere || (o.geometry.computeBoundingSphere(), o.geometry.boundingSphere); let best = null, bd = max; for (const id in sects) { const d = Math.hypot(b.center.x - sects[id].x, b.center.z - sects[id].z); if (d < bd) { bd = d; best = id; } } return best; };
      const add = (key, m) => { if (m) (groups[key] = groups[key] || []).push(m); };
      scene.traverse((o) => {
        if (!o.isMesh || o.isInstancedMesh) return;
        const a = o.geometry.attributes;
        if (land.has(o)) {                                         // the sects' fine ground patches (13 丈 grid, facet + ink) go with their sect
          if (a.bary && (Y.LAND.chunks || []).includes(o)) { const s = nearest(o, 8000); add('sect_' + (s || 'misc') + '_ground', facet(o, 'ground')); }
          return;
        }
        if (a.aCol && a.aN && !a.bary && o.geometry.index) {      // a terrain tile: keep the level with the most triangles per shared buffer
          const k = a.position, t = tiles.get(k); if (!t || o.geometry.index.count > t.geometry.index.count) tiles.set(k, o); return;
        }
        if (!a.bary) return;                                       // instanced templates, trails, sprites: built at runtime in Godot
        let key = o.userData && o.userData.site ? 'sect_' + o.userData.site : null;
        if (!key && city.has(o)) key = 'cities';
        if (!key) { const s = nearest(o, props.has(o) ? 6000 : 4000); key = s ? 'sect_' + s + '_surroundings' : 'props'; }
        add(key, facet(o, o.name || key));
      });
      if (window.__terrainMesh) for (const o of tiles.values()) add('terrain', tile(o));
      const exporter = new GLTFExporter();
      window.__glb = {};
      for (const key in groups) {
        const root = new THREE.Scene(); root.name = key; for (const m of groups[key]) root.add(m);
        const tris = groups[key].reduce((s, m) => s + (m.geometry.index ? m.geometry.index.count : m.geometry.attributes.position.count) / 3, 0);
        const ab = await exporter.parseAsync(root, { binary: true });
        window.__glb[key] = new Uint8Array(ab);
        out.push({ key, meshes: groups[key].length, tris, bytes: ab.byteLength });
      }
      return out;
    });
    meta.meshes = { vertexLayout: 'COLOR_0.rgb face colour, COLOR_0.a ink weight of edge opposite corner C, TEXCOORD_0 barycentric (x,y), TEXCOORD_1 ink weights of edges opposite A,B', files: [] };
    for (const g of list) {
      const file = `meshes/${g.key}.glb`;
      write(file, Buffer.from((await pull(`window.__glb[${JSON.stringify(g.key)}]`, Uint8Array)).buffer));
      meta.meshes.files.push({ file, meshes: g.meshes, triangles: g.tris });
    }
  }
  json('meta.json', meta);
  await browser.close(); server.close();
  console.log('done:', OUT);
})().catch((e) => { console.error(e); process.exit(1); });
