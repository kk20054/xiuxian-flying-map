extends Node3D
## Boot and the frame (demo §14 boot L14882–14929, renderFrame L14931): load the exported world, bake the sun, build
## the ground, water, architecture, trees, cloud sea and the 舆图 plane, then hand over to the Director for the intro.
## Per frame it updates what depends on altitude (trees, cloud sea, post) and routes the debug panel's changes.

@onready var director: Node = $Director
@onready var cam: Camera3D = $Camera3D
@onready var terrain: Node3D = $World/Terrain
@onready var water: MeshInstance3D = $World/Water
@onready var props: Node3D = $World/Props
@onready var trees: Node3D = $World/Trees
@onready var cloud_sea: MeshInstance3D = $World/CloudSea
@onready var map_plane: MeshInstance3D = $World/MapPlane
@onready var sun_bake: Node = $SunBake
@onready var post: ColorRect = $Post/Screen
@onready var ink: MeshInstance3D = $Camera3D/InkEdge

var quality := {"scale": 1.0, "acc": 0.0, "frames": 0, "hist": [], "cool": 4.0}
var _rebake := -1.0


func _ready() -> void:
	director.add_to_group("director")
	Game.mode = Game.Mode.LOADING
	await get_tree().process_frame
	await World.load_all()
	if not World.loaded:
		Game.toast.emit("没有找到导出的世界数据：请先运行 tools/export-world")
		return
	World.progress.emit(0.72, "展卷中 72%")
	await sun_bake.bake()
	terrain.build()
	World.release_boot_data()
	_build_water()
	World.progress.emit(0.78, "展卷中 78%")
	await get_tree().process_frame
	cloud_sea.build()
	await map_plane.build()
	World.progress.emit(0.82, "运模型")
	await props.build()
	terrain.apply_ground(props.facet_ground)   # the sects' fine ground paints the same biome ground as the range round it
	if World.terrain_dir != "":
		var rocks := Node3D.new()
		rocks.name = "Rocks"
		rocks.set_script(preload("res://scripts/world/rocks.gd"))
		$World.add_child(rocks)
		print("XY rocks: ", rocks.build(World.terrain_dir + "rocks.bin", props.facet))
	World.progress.emit(0.9, "种树")
	await trees.build()
	Cfg.changed.connect(_on_cfg)
	director.setup()
	print("XY boot: terrain chunks %d, props meshes %d, trees %d" % [terrain.count, props.meshes, trees.count])


func _build_water() -> void:
	var R := World.rect
	var pm := PlaneMesh.new()
	pm.size = R.size + Vector2(18000, 18000)
	pm.subdivide_width = 219
	pm.subdivide_depth = 179
	water.mesh = pm
	water.position = Vector3(R.get_center().x, 0, R.get_center().y)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	for k in [["depth", "inland_depth"], ["seaDepth", "sea_depth"], ["steps", "steps"], ["waves", "waves"], ["ripples", "ripples"], ["seaMotion", "sea_motion"]]:
		m.set_shader_parameter(k[1], Cfg.f("water." + k[0], 1.0))
	water.material_override = m
	water.custom_aabb = AABB(Vector3(-pm.size.x / 2, -40, -pm.size.y / 2), Vector3(pm.size.x, 80, pm.size.y))


func _process(dt: float) -> void:
	if Game.mode == Game.Mode.LOADING:
		return
	var alt: float = director.current_alt()
	trees.update(alt, director.rig_target)
	cloud_sea.update(alt, director.rig_target)
	_update_post(alt)
	_sample_quality(dt)
	if _rebake > 0.0:
		_rebake -= dt
		if _rebake <= 0.0:
			sun_bake.bake()


## updatePost (L13127): tilt-shift strongest low down, focus row pulled toward the light; grade grows with altitude.
func _update_post(alt: float) -> void:
	var lo := Cfg.f("zoom.low", 950); var mid := Cfg.f("zoom.mid", 1650); var hi := Cfg.f("zoom.high", 8000)
	var low_k := 1.0 - smoothstep(lo, mid, alt)
	var cin := Game.cloud_in
	var k := (0.32 + 0.5 * low_k) * (1.0 - 0.8 * smoothstep(mid, hi, alt)) * Cfg.f("look.tiltShift", 1.0) * (1.0 - Game.map_k) * cin
	var lp: Vector3 = director.light_p
	var fy := 0.5
	if not cam.is_position_behind(lp):
		fy = clampf(lerpf(0.5, cam.unproject_position(lp).y / maxf(1.0, get_viewport().get_visible_rect().size.y), 0.4), 0.3, 0.7)
	var m: ShaderMaterial = post.material
	m.set_shader_parameter("tilt", k)
	m.set_shader_parameter("focus", fy)
	m.set_shader_parameter("band", Cfg.f("look.focusBand", 0.18) * (1.25 + 0.5 * (1.0 - low_k)))
	var wash := Game.wash
	m.set_shader_parameter("grade", Cfg.f("cinema.grade", 1.0) * (0.12 + 0.88 * smoothstep(0.9 * mid, hi, alt)) * (1.0 - Game.map_k) * wash)
	m.set_shader_parameter("vig", Cfg.f("cinema.vignette", 0.35))
	m.set_shader_parameter("paper", Cfg.f("look.paper", 0.24) * (1.0 - 0.4 * Game.map_k))
	m.set_shader_parameter("css_vignette", Cfg.f("look.vignette", 0.38) * (1.0 - Game.map_k))
	var im: ShaderMaterial = ink.material_override
	im.set_shader_parameter("strength", Cfg.f("look.edgeInk", 0.7))
	im.set_shader_parameter("cam_far", cam.far)
	RenderingServer.global_shader_parameter_set("haze_k", Cfg.f("look.haze", 0.5))
	RenderingServer.global_shader_parameter_set("valley_k", Cfg.f("cinema.valleyMist", 0.8))


## Auto quality (QUALITY L14850): in steady flight, if the average over 2.5 s stays under 48 fps, lower the 3D render
## scale by ×0.8 (floor 0.6) and say so. Never scales back up.
func _sample_quality(dt: float) -> void:
	if Game.mode != Game.Mode.FLIGHT or "--no-autoquality" in OS.get_cmdline_user_args():
		return
	quality.cool -= dt
	if quality.cool > 0.0:
		return
	quality.acc += dt; quality.frames += 1
	if quality.acc < 2.5:
		return
	var fps: float = quality.frames / quality.acc
	quality.acc = 0.0; quality.frames = 0
	quality.hist.append(fps)
	if quality.hist.size() > 3:
		quality.hist.pop_front()
	var avg := 0.0
	for f in quality.hist:
		avg += f
	avg /= quality.hist.size()
	if quality.hist.size() >= 2 and avg < 48.0 and quality.scale > 0.6:
		quality.scale = maxf(0.6, quality.scale * 0.8)
		quality.hist.clear(); quality.cool = 3.0
		get_viewport().scaling_3d_scale = quality.scale
		Game.toast.emit("帧率偏低（%d），渲染倍率降到 ×%.2f" % [int(avg), quality.scale])


func _on_cfg(path: String, value) -> void:
	# the bake follows the sun's direction, the relief and the cloud-sea height (its G channel and the sects' lift: the demo
	# re-bakes on azimuth / elevation / cloudSea.height, L5555); shadow strength and contrast are only the flat tones
	if path in ["sun.azimuth", "sun.elevation", "terrain.relief", "cloudSea.height", ""]:
		_rebake = 0.3
	elif path in ["sun.shadow", "sun.contrast"]:
		sun_bake.set_toon()
	if path == "terrain.relief" or path == "":
		RenderingServer.global_shader_parameter_set("relief", Cfg.f("terrain.relief", 1.0))
	var tm: ShaderMaterial = terrain.material
	var key := {"terrain.soft": "soft_k", "terrain.footInk": "foot_ink", "terrain.cun": "cun_k"}
	if key.has(path):
		# the land's uniforms (LU, L4229–4241) are shared by the ranges, the sects' fine ground and facets, and (soft) the trees
		tm.set_shader_parameter(key[path], value)
		props.facet.set_shader_parameter(key[path], value); props.facet_ground.set_shader_parameter(key[path], value)
		if path == "terrain.soft":
			trees.material.set_shader_parameter("soft_k", value)
	if path == "terrain.creaseInk":
		props.facet.set_shader_parameter("crease_ink", value); props.facet_ground.set_shader_parameter("crease_ink", value)
	if path.begins_with("water."):
		var wk := {"water.ripples": "ripples", "water.waves": "waves", "water.seaMotion": "sea_motion", "water.steps": "steps"}
		if wk.has(path):
			(water.material_override as ShaderMaterial).set_shader_parameter(wk[path], value)
	if path.begins_with("trees."):
		trees.material.set_shader_parameter("size_k", Cfg.f("trees.size", 1.0))
		trees.material.set_shader_parameter("sway", Cfg.f("trees.sway", 1.0))
	if path.begins_with("cloudSea.") and cloud_sea.mat:
		var ck := {"cloudSea.amount": "alpha_k", "cloudSea.height": "top", "cloudSea.billow": "amp", "cloudSea.thick": "thick", "cloudSea.density": "dens_k"}
		if ck.has(path):
			cloud_sea.mat.set_shader_parameter(ck[path], value)
		if path == "cloudSea.steps":
			cloud_sea.mat.set_shader_parameter("steps", int(value))
