extends Node
## The world the demo generated (exported by tools/export-world): heights, water, colours, places, roads and rivers.
## Loads once at startup, keeps CPU copies for sampling (hAt, groundClear — the flight needs them) and GPU textures
## that every world shader reads through global shader uniforms (t_height, t_water, t_mcolor, t_ground, t_biome).

signal progress(k: float, label: String)
signal ready_world

const DIR := "res://data/world/"

var meta: Dictionary = {}
var rect := Rect2()             # x0, z0, width, depth (丈)
var cell := 40.0                # heightfield spacing
var nx := 0
var nz := 0
var heights := PackedFloat32Array()
var patches: Array = []         # [{x0, z0, x1, z1, cell, w, h, H: PackedFloat32Array}] — 13.3-丈 detail around the six sects
var places: Array = []          # dictionaries straight from places.json, plus "x", "z" floats
var by_id: Dictionary = {}
var by_name: Dictionary = {}
var paths: Dictionary = {}      # roads / rivers / streams / bridges / villages
var layout: Dictionary = {}     # sects, marks (landmarks), peaks, pillar, vortex…
var start_pos := Vector2.ZERO
var loaded := false

var t_height: ImageTexture
var t_height_blur: ImageTexture
var t_water: ImageTexture
var t_mcolor: ImageTexture
var t_ground: ImageTexture
var t_biome: ImageTexture
var water_img: Image
var mcolor_img: Image

# the six sects' detail patches cover their mountains with finer meshes (the GLBs): terrain chunks skip these rects
var patch_rects: Array[Rect2] = []


func load_all() -> void:
	meta = _json("meta.json")
	if meta.is_empty():
		push_error("World: no export in %s — run `npm run export` in tools/export-world" % DIR)
		return
	var R: Dictionary = meta.rect
	rect = Rect2(R.x0, R.z0, R.x1 - R.x0, R.z1 - R.z0)
	start_pos = Vector2(meta.startPos[0], meta.startPos[1])
	var H: Dictionary = meta.height
	cell = H.cell; nx = H.w; nz = H.h
	progress.emit(0.05, "展卷中 5%")
	await get_tree().process_frame

	# heights: raw IEEE half floats (Godot strips 16-bit PNGs to 8 bits, so the raw file is what we read)
	var himg := _half_image(H.raw.file, nx, nz)
	t_height = ImageTexture.create_from_image(himg)
	var cpu: Image = himg.duplicate()
	cpu.convert(Image.FORMAT_RF)
	heights = cpu.get_data().to_float32_array()
	# the blurred heights (≈ the demo's tLand.g, a 5-cell box blur): shrink and grow back
	var blur: Image = cpu.duplicate()
	blur.resize(maxi(1, nx / 5), maxi(1, nz / 5), Image.INTERPOLATE_BILINEAR)
	blur.resize(nx, nz, Image.INTERPOLATE_CUBIC)
	blur.convert(Image.FORMAT_RH)
	t_height_blur = ImageTexture.create_from_image(blur)
	progress.emit(0.25, "展卷中 25%")
	await get_tree().process_frame

	for P in meta.patches:
		var pimg := _half_image(P.raw, P.w, P.h)
		pimg.convert(Image.FORMAT_RF)
		patches.append({"x0": P.x0, "z0": P.z0, "x1": P.x1, "z1": P.z1, "cell": P.cell, "w": P.w, "h": P.h, "H": pimg.get_data().to_float32_array()})
		patch_rects.append(Rect2(P.x0, P.z0, P.x1 - P.x0, P.z1 - P.z0))

	water_img = _png(meta.water.tex.file)
	t_water = ImageTexture.create_from_image(water_img)
	progress.emit(0.45, "展卷中 45%")
	await get_tree().process_frame
	mcolor_img = _png(meta.mountainColor.file)
	t_mcolor = ImageTexture.create_from_image(mcolor_img)
	t_ground = ImageTexture.create_from_image(_png(meta.ground.file))
	t_biome = ImageTexture.create_from_image(_png(meta.biome.file))
	progress.emit(0.6, "展卷中 60%")
	await get_tree().process_frame

	places = _json("places.json")
	for p in places:
		p.x = float(p.pos[0]); p.z = float(p.pos[2])
		by_id[p.id] = p
		by_name[p.name] = p
	paths = _json("paths.json")
	layout = _json("layout.json")

	var rs := RenderingServer
	rs.global_shader_parameter_set("t_height", t_height)
	rs.global_shader_parameter_set("t_height_blur", t_height_blur)
	rs.global_shader_parameter_set("t_water", t_water)
	rs.global_shader_parameter_set("t_mcolor", t_mcolor)
	rs.global_shader_parameter_set("t_ground", t_ground)
	rs.global_shader_parameter_set("t_biome", t_biome)
	rs.global_shader_parameter_set("world_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	# the height texture's texels sit on grid points: texel centre i ↔ x0 + i·cell, so its rect is one cell wider
	rs.global_shader_parameter_set("height_rect", Vector4(rect.position.x - cell * 0.5, rect.position.y - cell * 0.5, nx * cell, nz * cell))
	loaded = true
	progress.emit(0.7, "展卷中 70%")
	ready_world.emit()


## Terrain height at (x, z) in 丈 — the demo's hAt (L1850): the sect patches first, then the 40-丈 grid, bilinear, never below 0.
func h_at(x: float, z: float) -> float:
	for P in patches:
		if x <= P.x0 or x >= P.x1 or z <= P.z0 or z >= P.z1:
			continue
		return maxf(0.0, _bilerp(P.H, P.w, P.h, (x - P.x0) / P.cell, (z - P.z0) / P.cell))
	if heights.is_empty():
		return 0.0
	return maxf(0.0, _bilerp(heights, nx, nz, (x - rect.position.x) / cell, (z - rect.position.y) / cell))


## The light's clearance over the ground (demo groundClear L14121): the highest ground around and ahead of (x, z).
func ground_clear(x: float, z: float, vx := 0.0, vz := 0.0) -> float:
	var h := h_at(x, z)
	h = maxf(h, h_at(x + 90.0, z)); h = maxf(h, h_at(x - 90.0, z))
	h = maxf(h, h_at(x, z + 90.0)); h = maxf(h, h_at(x, z - 90.0))
	h = maxf(h, h_at(x + vx * 0.6, z + vz * 0.6)); h = maxf(h, h_at(x + vx * 1.2, z + vz * 1.2))
	var P = layout.get("pillar")
	if P is Dictionary and P.has("x"):
		if Vector2(x - P.x, z - P.z).length() < float(P.get("r", 300.0)) + 260.0:
			h = maxf(h, float(P.get("h", 1300.0)) + 190.0)
	return h * Cfg.f("terrain.relief", 1.0)


## 0..1 water coverage and the shore distance (丈, + in water) at (x, z), from the demo's packed water texture.
func water_at(x: float, z: float) -> Vector2:
	if water_img == null:
		return Vector2.ZERO
	var u := (x - rect.position.x) / rect.size.x
	var v := (z - rect.position.y) / rect.size.y
	if u < 0.0 or v < 0.0 or u >= 1.0 or v >= 1.0:
		return Vector2(1.0, 254.0)
	var c := water_img.get_pixel(int(u * water_img.get_width()), int(v * water_img.get_height()))
	return Vector2(c.a, (c.r * 255.0 - 128.0) * 2.0)


func uv_of(x: float, z: float) -> Vector2:
	return Vector2((x - rect.position.x) / rect.size.x, (z - rect.position.y) / rect.size.y)


func _bilerp(H: PackedFloat32Array, w: int, h: int, fx: float, fz: float) -> float:
	fx = clampf(fx, 0.0, w - 1.001); fz = clampf(fz, 0.0, h - 1.001)
	var i := int(fx); var j := int(fz)
	var tx := fx - i; var tz := fz - j
	var k := j * w + i
	return lerpf(lerpf(H[k], H[k + 1], tx), lerpf(H[k + w], H[k + w + 1], tx), tz)


func _half_image(file: String, w: int, h: int) -> Image:
	var bytes := FileAccess.get_file_as_bytes(DIR + file)
	return Image.create_from_data(w, h, false, Image.FORMAT_RH, bytes)


func _png(file: String) -> Image:
	var img := Image.load_from_file(DIR + file)
	if img == null:
		push_error("World: cannot read " + file)
	return img


func _json(file: String):
	var f := FileAccess.open(DIR + file, FileAccess.READ)
	if f == null:
		return {}
	return JSON.parse_string(f.get_as_text())
