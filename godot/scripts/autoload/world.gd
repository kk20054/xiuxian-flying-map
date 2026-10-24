extends Node
## The world the demo generated (exported by tools/export-world): heights, water, colours, places, roads and rivers.
## Loads once at startup, keeps CPU copies for sampling (hAt, groundClear — the flight needs them) and GPU textures
## that every world shader reads through global shader uniforms (t_height, t_height_blur, t_water, t_mcolor, t_ground, t_biome).

signal progress(k: float, label: String)
signal ready_world

const DIR := "res://data/world/"

## A re-sculpted terrain (tools/terrain/sculpt.py output, e.g. `-- --terrain=res://data/terrain`): its heights replace the
## exported ones (same grid), its rock map becomes t_litho, its rocks.bin feeds rocks.gd. Empty = the exported land.
var terrain_dir := ""
var t_litho: ImageTexture

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
var t_patch_h: Texture2DArray   # the six patches' heights, one layer each (padded to the largest), texel (i, j) = patch vertex (i, j)
var water_img: Image            # CPU copy for water_at while the terrain is built (release_boot_data drops it)

# the six sects' detail patches cover their mountains with finer meshes (the GLBs): the terrain skips them where they have ground
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
	_terrain_override(himg)
	var cpu: Image = himg.duplicate()
	cpu.convert(Image.FORMAT_RF)
	heights = cpu.get_data().to_float32_array()

	# the sects' 13.3-丈 patches: CPU copies for h_at, and one texture array (a layer each) for the shaders that need the
	# fine ground (terrain: where the patch GLB has ground; facet: the fine ground's smooth normal)
	var layers: Array[Image] = []
	var lw := 0; var lh := 0
	for P in meta.patches:
		lw = maxi(lw, int(P.w)); lh = maxi(lh, int(P.h))
	for P in meta.patches:
		var pimg := _half_image(P.raw, P.w, P.h)
		var layer := Image.create_empty(lw, lh, false, Image.FORMAT_RH)
		layer.blit_rect(pimg, Rect2i(0, 0, P.w, P.h), Vector2i.ZERO)
		layers.append(layer)
		pimg.convert(Image.FORMAT_RF)
		var PH := pimg.get_data().to_float32_array()
		patches.append({"x0": P.x0, "z0": P.z0, "x1": P.x1, "z1": P.z1, "cell": P.cell, "w": P.w, "h": P.h, "H": PH})
		patch_rects.append(Rect2(P.x0, P.z0, P.x1 - P.x0, P.z1 - P.z0))
		# fold the patch into the 40-丈 heights at the grid points inside it, as the demo's tLand does (L5393)
		var sub := int(round(cell / float(P.cell)))
		var i0 := int(round((float(P.x0) - rect.position.x) / cell)); var j0 := int(round((float(P.z0) - rect.position.y) / cell))
		var i1 := i0 + (int(P.w) - 1) / sub; var j1 := j0 + (int(P.h) - 1) / sub
		for j in range(j0 + 1, j1):
			for i in range(i0 + 1, i1):
				himg.set_pixel(i, j, Color(maxf(0.0, PH[(j - j0) * sub * int(P.w) + (i - i0) * sub]), 0, 0))
	if not layers.is_empty():
		t_patch_h = Texture2DArray.new()
		t_patch_h.create_from_images(layers)
	t_height = ImageTexture.create_from_image(himg)
	progress.emit(0.25, "展卷中 25%")
	await get_tree().process_frame

	water_img = _png(meta.water.tex.file)
	t_water = ImageTexture.create_from_image(water_img)
	progress.emit(0.45, "展卷中 45%")
	await get_tree().process_frame
	t_mcolor = ImageTexture.create_from_image(_png(meta.mountainColor.file))
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
	_mark_no_sea()

	var rs := RenderingServer
	var PL = layout.get("pillar")
	if PL is Dictionary and PL.has("x"):
		rs.global_shader_parameter_set("pillar", Vector4(PL.x, PL.z, float(PL.get("h", 1300.0)), float(PL.get("r", 230.0))))
	# the blurred heights (tLand.g): baked on the GPU; without a renderer (headless) a shrink-and-grow stand-in
	t_height_blur = await _bake_blur(himg)
	if t_height_blur == null:
		var blur: Image = himg.duplicate()
		blur.convert(Image.FORMAT_RF)
		blur.resize(maxi(1, nx / 5), maxi(1, nz / 5), Image.INTERPOLATE_BILINEAR)
		blur.resize(nx, nz, Image.INTERPOLATE_CUBIC)
		blur.convert(Image.FORMAT_RH)
		t_height_blur = ImageTexture.create_from_image(blur)
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


## The shore distance (丈, + in water) and the 0..1 sea factor at (x, z), from the demo's packed water texture — the same
## order as land_common's water_at(). Only while booting: release_boot_data() drops the CPU image afterwards.
func water_at(x: float, z: float) -> Vector2:
	if water_img == null:
		return Vector2(254.0, 1.0)
	var u := (x - rect.position.x) / rect.size.x
	var v := (z - rect.position.y) / rect.size.y
	if u < 0.0 or v < 0.0 or u >= 1.0 or v >= 1.0:
		return Vector2(254.0, 1.0)
	var c := water_img.get_pixel(int(u * water_img.get_width()), int(v * water_img.get_height()))
	return Vector2((c.r * 255.0 - 128.0) * 2.0, c.a)


## The 52 MB water image is only sampled while the terrain chunks are built; the GPU keeps t_water.
func release_boot_data() -> void:
	water_img = null


## The 11 × 11 box blur of the heights (height_blur.gdshader) in one GPU pass, read back as half floats. Null without a
## renderer that draws (headless).
func _bake_blur(himg: Image) -> ImageTexture:
	var vp := SubViewport.new()
	vp.size = Vector2i(nx, nz)
	vp.use_hdr_2d = true            # a half-float target: the heights keep their precision
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var r := ColorRect.new()
	r.size = Vector2(nx, nz)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/height_blur.gdshader")
	m.set_shader_parameter("heights", ImageTexture.create_from_image(himg))
	m.set_shader_parameter("grid0", rect.position)
	m.set_shader_parameter("cell", cell)
	r.material = m
	vp.add_child(r)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty() or img.get_size() != Vector2i(nx, nz):
		return null
	img.convert(Image.FORMAT_RH)
	return ImageTexture.create_from_image(img)


## A sect without a cloud sea of its own (demo SECTS.shuiying `sea: false` → S.noSea, L1541): its seaDens is 0 (L4161), so
## the exported plan is empty over the site. Marks layout.sites[i].noSea for the cloud sea and the sun bake.
func _mark_no_sea() -> void:
	var CS: Dictionary = meta.get("cloudSea", {})
	if not CS.has("file"):
		return
	var plan := _png(CS.file)
	if plan == null:
		return
	for S in layout.get("sites", []):
		var acc := 0.0; var n := 0
		for j in range(-4, 5):
			for i in range(-4, 5):
				if Vector2(i, j).length() > 4.0:
					continue
				var uv := uv_of(float(S.x) + i * float(S.R) * 0.2, float(S.z) + j * float(S.R) * 0.2)
				acc += plan.get_pixel(clampi(int(uv.x * plan.get_width()), 0, plan.get_width() - 1), clampi(int(uv.y * plan.get_height()), 0, plan.get_height() - 1)).r
				n += 1
		S.noSea = acc / maxf(1.0, n) < 0.02


func uv_of(x: float, z: float) -> Vector2:
	return Vector2((x - rect.position.x) / rect.size.x, (z - rect.position.y) / rect.size.y)


func _bilerp(H: PackedFloat32Array, w: int, h: int, fx: float, fz: float) -> float:
	fx = clampf(fx, 0.0, w - 1.001); fz = clampf(fz, 0.0, h - 1.001)
	var i := int(fx); var j := int(fz)
	var tx := fx - i; var tz := fz - j
	var k := j * w + i
	return lerpf(lerpf(H[k], H[k + 1], tx), lerpf(H[k + w], H[k + w + 1], tx), tz)


func _half_image(file: String, w: int, h: int) -> Image:
	var bytes := FileAccess.get_file_as_bytes(file if file.contains("/") else DIR + file)
	return Image.create_from_data(w, h, false, Image.FORMAT_RH, bytes)


## --terrain=<dir>: swap in a re-sculpted heightfield (same grid as the export) and its rock map.
func _terrain_override(himg: Image) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--terrain="):
			terrain_dir = a.substr(10).trim_suffix("/") + "/"
	if terrain_dir == "":
		return
	var info = JSON.parse_string(FileAccess.get_file_as_string(terrain_dir + "terrain.json"))
	if not info is Dictionary or int(info.get("w", 0)) != nx or int(info.get("h", 0)) != nz:
		push_error("World: %s is not a terrain for this world (needs %d×%d, see tools/terrain/sculpt.py)" % [terrain_dir, nx, nz])
		terrain_dir = ""
		return
	himg.copy_from(_half_image(terrain_dir + "height_f16.bin", nx, nz))
	var lit := Image.load_from_file(terrain_dir + "lithology.png")
	if lit:
		lit.convert(Image.FORMAT_R8)
		t_litho = ImageTexture.create_from_image(lit)
		RenderingServer.global_shader_parameter_set("t_litho", t_litho)
		RenderingServer.global_shader_parameter_set("litho_on", true)
	print("World: terrain from ", terrain_dir)


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
