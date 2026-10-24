extends Node3D
## Rock instances from a re-sculpted terrain (tools/terrain/sculpt.py → <terrain>/rocks.bin, float32 × 8:
## x, y (ground), z, radius, height, kind, yaw, var): karst towers, sandstone pillars, sea stacks… One MultiMesh per
## (4000-丈 chunk × kind × variant), drawn with the facet ink material; they fold flat with the world on the 舆图.

const RockKit := preload("res://scripts/world/rock_kit.gd")
const CHUNK := 4000.0
const VARIANTS := 4
const SINK := 0.25                 # bury the foot by a quarter radius so a tower stands in its talus, not on it

var material: ShaderMaterial


func build(path: String, facet: ShaderMaterial) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	var data := f.get_buffer(f.get_length()).to_float32_array()
	var n := data.size() / 8
	if n == 0:
		return 0
	material = facet
	var meshes := {}
	var buckets := {}
	for k in n:
		var o := k * 8
		var kind := int(data[o + 5])
		var variant := mini(int(data[o + 7] * VARIANTS), VARIANTS - 1)
		var key := Vector4i(int(floor(data[o] / CHUNK)), int(floor(data[o + 2] / CHUNK)), kind, variant)
		if not buckets.has(key):
			buckets[key] = PackedInt32Array()
		buckets[key].append(o)
	for key: Vector4i in buckets:
		var mk := Vector2i(key.z, key.w)
		if not meshes.has(mk):
			meshes[mk] = RockKit.build(RockKit.KINDS[clampi(key.z, 0, RockKit.KINDS.size() - 1)], key.w)
		var idx: PackedInt32Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[mk]
		mm.instance_count = idx.size()
		var buf := PackedFloat32Array()
		buf.resize(idx.size() * 12)
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for i in idx.size():
			var o: int = idx[i]
			var x := data[o]; var y := data[o + 1]; var z := data[o + 2]
			var r := data[o + 3]; var h := data[o + 4]; var yaw := data[o + 6]
			var b := Basis(Vector3.UP, yaw).scaled(Vector3(r, h + r * SINK, r))
			var p := Vector3(x, y - r * SINK, z)
			var t := Transform3D(b, p)
			var w := i * 12
			buf[w] = t.basis.x.x; buf[w + 1] = t.basis.y.x; buf[w + 2] = t.basis.z.x; buf[w + 3] = t.origin.x
			buf[w + 4] = t.basis.x.y; buf[w + 5] = t.basis.y.y; buf[w + 6] = t.basis.z.y; buf[w + 7] = t.origin.y
			buf[w + 8] = t.basis.x.z; buf[w + 9] = t.basis.y.z; buf[w + 10] = t.basis.z.z; buf[w + 11] = t.origin.z
			lo = lo.min(Vector3(x - r, y - r, z - r)); hi = hi.max(Vector3(x + r, y + h, z + r))
		mm.buffer = buf
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = material
		mi.custom_aabb = AABB(lo - Vector3(0, 0, 0), (hi - lo) * Vector3(1, 2.0, 1))   # 2× height: the relief slider
		mi.visibility_range_end = 22000.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	return n
