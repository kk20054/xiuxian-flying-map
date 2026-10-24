extends MeshInstance3D
## The cloud sea's top surface: a grid over the world rect, quads only where the plan has cloud (demo 07c buildCloudSea).
## The shader does the rest; update() opens the sea round the player at low altitude (updateCloudSea L12485).

const CELL := 200.0

var mat: ShaderMaterial


func build() -> void:
	var meta: Dictionary = World.meta.get("cloudSea", {})
	if not meta.has("file"):
		visible = false
		return
	var plan := Image.load_from_file(World.DIR + meta.file)
	plan.convert(Image.FORMAT_L8)
	# blur the plan a little (the demo: a 7×7 box away from the sects)
	var blurred: Image = plan.duplicate()
	blurred.resize(plan.get_width() / 3, plan.get_height() / 3, Image.INTERPOLATE_BILINEAR)
	blurred.resize(plan.get_width(), plan.get_height(), Image.INTERPOLATE_CUBIC)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/cloud_sea.gdshader")
	mat.set_shader_parameter("dens_tex", ImageTexture.create_from_image(blurred))
	var noise := NoiseTexture3D.new()
	noise.width = 48; noise.height = 48; noise.depth = 48
	noise.seamless = true
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	fn.frequency = 0.08
	fn.fractal_octaves = 3
	noise.noise = fn
	mat.set_shader_parameter("noise3", noise)
	var sites: Array[Vector4] = []
	for S in World.layout.get("sites", []):
		if not S.get("noSea", false):          # 水影宗 has no sea of its own: it neither lifts nor veils (L12474)
			sites.append(Vector4(S.x, S.z, float(S.R) * 1.6, float(S.cloud)))
	while sites.size() < 6:
		sites.append(Vector4(1e9, 1e9, 1.0, 0.0))
	mat.set_shader_parameter("sites", sites)
	for k in [["height", "top"], ["billow", "amp"], ["thick", "thick"], ["density", "dens_k"], ["amount", "alpha_k"]]:
		mat.set_shader_parameter(k[1], Cfg.f("cloudSea." + k[0], 1.0))
	mat.set_shader_parameter("steps", int(Cfg.f("cloudSea.steps", 9)))
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# the top surface: shared vertices, quads where any corner has cloud
	var R := World.rect
	var nx := int(R.size.x / CELL) + 1
	var nz := int(R.size.y / CELL) + 1
	var pw := blurred.get_width(); var ph := blurred.get_height()
	var on := PackedByteArray(); on.resize(nx * nz)
	for j in nz:
		for i in nx:
			var v := blurred.get_pixel(mini(pw - 1, int(float(i) / nx * pw)), mini(ph - 1, int(float(j) / nz * ph))).r
			on[j * nx + i] = 1 if v > 2.0 / 255.0 else 0
	var vid := PackedInt32Array(); vid.resize(nx * nz); vid.fill(-1)
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			var k := j * nx + i
			if on[k] + on[k + 1] + on[k + nx] + on[k + nx + 1] == 0:
				continue
			var q := [k, k + 1, k + nx + 1, k + nx]
			for c in q:
				if vid[c] < 0:
					vid[c] = verts.size()
					verts.append(Vector3(R.position.x + (c % nx) * CELL, 0, R.position.y + (c / nx) * CELL))
			idx.append_array([vid[q[0]], vid[q[1]], vid[q[2]], vid[q[0]], vid[q[2]], vid[q[3]]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	if verts.size() > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = m
	custom_aabb = AABB(Vector3(R.position.x, -200, R.position.y), Vector3(R.size.x, 1200, R.size.y))


func update(alt: float, target: Vector3) -> void:
	if mat == null:
		return
	var mid := Cfg.f("zoom.mid", 1650)
	var k := 1.0 - smoothstep(1.4 * mid, 2.6 * mid, alt)
	var ap := minf(alt, 1.4 * mid)
	mat.set_shader_parameter("part", Vector2(0.3 * ap * k, 0.95 * ap * k))
	mat.set_shader_parameter("target", Vector2(target.x, target.z))
