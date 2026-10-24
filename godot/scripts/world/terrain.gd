extends Node3D
## The ground in chunks (demo 04 · buildTerrainTiles L5047: 96-cell tiles, three index buffers, a 70-丈 skirt).
## Here every chunk shares four flat grid meshes (one per level of detail, skirt included) and the vertex shader lifts
## them from the height texture, so building the whole 132 000 × 80 000-丈 world is instant; Godot's visibility ranges
## pick the level by distance (the demo switches at 5200 / 10500 丈).

const CELLS := 64                       # cells per chunk side at full detail (64 × 40 丈 = 2560 丈)
const LODS := [64, 32, 16, 8]           # segments per side
const RANGES := [0.0, 5200.0, 10500.0, 26000.0, 0.0]
const RELIEF_MAX := 2.0                 # the 山高倍数 slider's top: the bounds hold the ground at any relief

var material: ShaderMaterial
var ground_params := {}                 # the painted ground's inputs (ground_common.gdshaderinc), shared with the sects' fine ground
var chunk_size := 2560.0
var count := 0


func build() -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/terrain.gdshader")
	var pr: Array[Vector4] = []
	for r in World.patch_rects:
		pr.append(Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
	while pr.size() < 6:
		pr.append(Vector4(1e9, 1e9, 1e9, 1e9))
	material.set_shader_parameter("patches", pr)
	material.set_shader_parameter("patch_count", World.patch_rects.size())
	material.set_shader_parameter("t_patch_h", World.t_patch_h)
	material.set_shader_parameter("intro_focus", World.start_pos)
	material.set_shader_parameter("intro_scale", 9000.0 * float(World.meta.layout.S))
	for k in ["soft", "footInk", "ridgeLight", "cun"]:
		var v = Cfg.g("terrain." + k)
		if v != null:
			material.set_shader_parameter({"soft": "soft_k", "footInk": "foot_ink", "ridgeLight": "ridge_light", "cun": "cun_k"}[k], float(v))

	# the painted ground's inputs (biome weights, flower drifts, seasons), when the export has them
	var B: Dictionary = World.meta.get("biome", {})
	if B.has("weights") and World.meta.has("season"):
		for t in [["t_bweights", B.weights.file], ["t_drift", B.drift.file], ["t_season", World.meta.season.file]]:
			var img := Image.load_from_file(World.DIR + t[1])
			if img:
				ground_params[t[0]] = ImageTexture.create_from_image(img)
		ground_params["biome_on"] = true
	# woodCol's regions (uReg, buildLandTextures L5446): frost round 古剑门, jade round 落云宗, red and gold round 百巧院
	var rr := Cfg.f("regions.radius", 1.0)
	var reg: Array[Vector4] = []
	for q in [["gujian", 1700.0, 3400.0], ["luoyun", 1600.0, 3200.0], ["baiqiao", 1900.0, 3800.0]]:
		var S = World.layout.get("sects", {}).get(q[0])
		reg.append(Vector4(S.x, S.z, q[1] * rr, q[2] * rr) if S is Dictionary else Vector4(1e9, 1e9, 1.0, 2.0))
	ground_params["regions"] = reg
	apply_ground(material)
	chunk_size = CELLS * World.cell
	var meshes := []
	for segs in LODS:
		meshes.append(_grid(segs, chunk_size))
	var R := World.rect
	var ncx := int(ceil(R.size.x / chunk_size))
	var ncz := int(ceil(R.size.y / chunk_size))
	for cj in ncz:
		for ci in ncx:
			var x0 := R.position.x + ci * chunk_size
			var z0 := R.position.y + cj * chunk_size
			var hmax := _chunk_max(x0, z0)
			if hmax < 0.0:
				continue                 # open sea: the water sheet covers it
			var centre := Vector3(x0 + chunk_size * 0.5, 0, z0 + chunk_size * 0.5)
			for l in LODS.size():
				var mi := MeshInstance3D.new()
				mi.mesh = meshes[l]
				mi.material_override = material
				mi.position = centre
				mi.custom_aabb = AABB(Vector3(-chunk_size * 0.5, -80.0, -chunk_size * 0.5), Vector3(chunk_size, hmax + 80.0, chunk_size))
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				# exactly complementary ranges: with fading off, a margin is hysteresis, and a chunk first seen inside the
				# band would show neither level (updateTerrainLOD L5131 has no band either)
				mi.visibility_range_begin = RANGES[l]
				mi.visibility_range_end = RANGES[l + 1]
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				add_child(mi)
			count += 1


## Hand the painted ground's inputs to another material that includes ground_common.gdshaderinc.
func apply_ground(m: ShaderMaterial) -> void:
	for k in ground_params:
		m.set_shader_parameter(k, ground_params[k])


## The chunk's highest ground (at the relief slider's top, with room for what the 4-cell sampling misses), or −1 when it
## is all open sea: no land and nowhere within 120 丈 of a shore (a sample is at most 113 丈 from any point).
func _chunk_max(x0: float, z0: float) -> float:
	var hmax := 0.0
	var land := false
	var step := World.cell * 4.0
	var z := z0
	while z <= z0 + chunk_size:
		var x := x0
		while x <= x0 + chunk_size:
			var h := World.h_at(x, z)
			hmax = maxf(hmax, h)
			if h > 0.0 or World.water_at(x, z).x < 120.0:
				land = true
			x += step
		z += step
	return (hmax + 80.0) * RELIEF_MAX if land else -1.0


## A flat grid of segs × segs quads centred on the origin, plus a skirt round its edge (UV2.x = 1 on the hanging ring).
func _grid(segs: int, size: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := segs + 1
	var h := size * 0.5
	for j in n:
		for i in n:
			verts.append(Vector3(-h + size * i / segs, 0, -h + size * j / segs))
			uv2.append(Vector2.ZERO)
	for j in segs:
		for i in segs:
			var a := j * n + i
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	# the skirt: a ring of vertices under the edge
	var ring := []
	for i in segs: ring.append(i)
	for j in segs: ring.append(j * n + segs)
	for i in range(segs, 0, -1): ring.append(segs * n + i)
	for j in range(segs, 0, -1): ring.append(j * n)
	var base := verts.size()
	for v in ring:
		verts.append(verts[v]); uv2.append(Vector2(1, 0))
	var m := ring.size()
	for r in m:
		var a: int = ring[r]; var b: int = ring[(r + 1) % m]
		var sa := base + r; var sb := base + (r + 1) % m
		idx.append_array([a, sa, b, b, sa, sb])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
