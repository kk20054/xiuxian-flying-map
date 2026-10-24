extends Node3D
## 1.4 million trees (demo 06 · buildTrees L6326): nine low-poly kinds, grouped per (2600-丈 chunk × kind) into
## MultiMeshInstance3Ds, shuffled so cutting visible_instance_count thins a wood evenly as you climb (updateProps L6822).
## Wind, colour slot, glow and snow are in tree.gdshader. The instance list comes from data/world/trees.bin.

const CHUNK := 2600.0
const RELIEF_MAX := 2.0         # the sliders' tops (山高倍数, 树木大小): the bounds hold the trees at any setting
const SIZE_MAX := 2.5
const PERIOD := 0.25            # update() walks the groups in slices: each is thinned again within 0.25 s at any frame rate
# TREE_COLS (L6325)
const COLS := ["#4e6d60", "#6a9573", "#b45a3e", "#c9a04c", "#52705f", "#77a884", "#c4d2d0", "#c6773b",
	"#dfa9b0", "#e6e3d8", "#8fb27a", "#8ccfbe", "#5f8a5a", "#a8a274", "#3f5e52", "#86ad6c"]

var material: ShaderMaterial
var groups: Array = []          # [{mm, n, centre, shown}]
var _thread: Thread
var _buckets := {}
var _next := 0
var count := 0


func build() -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/tree.gdshader")
	var cols: Array[Vector3] = []
	for h in COLS:
		var c := Color(h)
		cols.append(Vector3(c.r, c.g, c.b))
	material.set_shader_parameter("cols", cols)
	material.set_shader_parameter("size_k", Cfg.f("trees.size", 1.0))
	material.set_shader_parameter("sway", Cfg.f("trees.sway", 1.0))
	material.set_shader_parameter("soft_k", Cfg.f("terrain.soft", 0.85))
	var meta: Dictionary = World.meta.get("trees", {})
	if not meta.has("file"):
		return
	_thread = Thread.new()
	_thread.start(_parse.bind(World.DIR + meta.file, float(meta.scaleMax)))
	while _thread.is_alive():
		await get_tree().process_frame
	_buckets = _thread.wait_to_finish()
	var meshes := []
	for k in 9:
		meshes.append(TreeKit.mesh(k))
	var i := 0
	for key in _buckets:
		var b: Dictionary = _buckets[key]
		var kind: int = key % 16
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[kind]
		mm.instance_count = b.n
		mm.buffer = b.buf
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.position = Vector3.ZERO
		# the tallest kind (27 local units, crowns ≤ 11 across + sway) at the largest instance scale and 树木大小, on ground
		# raised by 山高倍数; no distance limit (the demo culls trees by the frustum only: far groves keep a thinned sample,
		# updateProps L6829)
		var sk := float(meta.scaleMax) * SIZE_MAX
		var pad := 14.0 * sk
		mmi.custom_aabb = AABB(Vector3(b.lo.x - pad, -10.0, b.lo.z - pad), Vector3(b.hi.x - b.lo.x + 2.0 * pad, maxf(0.0, b.hi.y) * RELIEF_MAX + 28.0 * sk + 10.0, b.hi.z - b.lo.z + 2.0 * pad))
		add_child(mmi)
		groups.append({"mm": mm, "n": b.n, "centre": (b.lo + b.hi) * 0.5, "shown": b.n})
		count += b.n
		i += 1
		if i % 200 == 0:
			await get_tree().process_frame
	_buckets = {}


## (worker thread) read the 8-byte records, plant each tree on the ground, bucket by chunk and kind, write the
## MultiMesh buffers: 12 floats of transform + 4 of custom data (kind, colour slot, yaw, hash) per instance.
func _parse(path: String, smax: float) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	var n := bytes.size() / 8
	var R := World.rect
	var ncx := int(ceil(R.size.x / CHUNK)) + 1
	var lists := {}
	for i in n:
		var o := i * 8
		var x := R.position.x + bytes.decode_u16(o) / 65535.0 * R.size.x
		var z := R.position.y + bytes.decode_u16(o + 2) / 65535.0 * R.size.y
		var kind := bytes[o + 4]
		var key := (int((z - R.position.y) / CHUNK) * ncx + int((x - R.position.x) / CHUNK)) * 16 + kind
		if not lists.has(key):
			lists[key] = PackedInt32Array()
		lists[key].append(i)
	var out := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 6326
	for key in lists:
		var idx: PackedInt32Array = lists[key]
		# shuffle so truncating the instance count thins evenly
		for a in range(idx.size() - 1, 0, -1):
			var b := rng.randi_range(0, a)
			var t := idx[a]; idx[a] = idx[b]; idx[b] = t
		var buf := PackedFloat32Array()
		buf.resize(idx.size() * 16)
		var lo := Vector3(INF, INF, INF); var hi := -lo
		var w := 0
		for i in idx:
			var o := i * 8
			var x := R.position.x + bytes.decode_u16(o) / 65535.0 * R.size.x
			var z := R.position.y + bytes.decode_u16(o + 2) / 65535.0 * R.size.y
			var y := World.h_at(x, z) - 0.3
			var yaw := bytes[o + 6] / 256.0 * TAU
			var s := bytes[o + 7] / 255.0 * smax
			var c := cos(yaw) * s; var sn := sin(yaw) * s
			# Transform3D rows: basis = rotY(yaw)·scale(s); origin (x, y, z)
			buf[w] = c; buf[w + 1] = 0.0; buf[w + 2] = sn; buf[w + 3] = x
			buf[w + 4] = 0.0; buf[w + 5] = s; buf[w + 6] = 0.0; buf[w + 7] = y
			buf[w + 8] = -sn; buf[w + 9] = 0.0; buf[w + 10] = c; buf[w + 11] = z
			buf[w + 12] = bytes[o + 4]; buf[w + 13] = bytes[o + 5]; buf[w + 14] = yaw; buf[w + 15] = fposmod(x * 0.1031 + z * 0.0973, 1.0)
			w += 16
			lo = lo.min(Vector3(x, y, z)); hi = hi.max(Vector3(x, y, z))
		out[key] = {"n": idx.size(), "buf": buf, "lo": lo, "hi": hi}
	return out


## Thin the woods with height and distance, as the demo does (updateProps L6826–6833: k = (1400/A)^1.35 · density,
## kd = (1.25A/d)^2, never more than the group has). A rolling slice of the groups each frame (a fifteenth at 60 fps),
## so no frame walks all ~3400.
func update(alt: float, target: Vector3) -> void:
	visible = Game.map_k < 0.995          # the 舆图 covers them (tree.gdshader discards there too)
	if groups.is_empty() or not visible:
		return
	var k := clampf(pow(1400.0 / maxf(alt, 1.0), 1.35), 0.07, 1.0) * clampf(Cfg.f("trees.density", 1.0), 0.0, 2.0)
	var N := groups.size()
	var step := mini(N, ceili(N * clampf(get_process_delta_time() / PERIOD, 0.0, 1.0)))
	for q in step:
		var g: Dictionary = groups[(_next + q) % N]
		var d := maxf(1.0, Vector2(g.centre.x - target.x, g.centre.z - target.z).length() - 1300.0)
		var kd := clampf(pow(alt * 1.25 / d, 2.0), 0.12, 1.0)
		var n := mini(g.n, int(round(g.n * k * kd)))
		if n != g.shown:
			g.shown = n
			g.mm.visible_instance_count = n
	_next = (_next + step) % N
