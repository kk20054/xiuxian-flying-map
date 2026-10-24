extends Node
## Bakes t_sun once (and again when the sun sliders move): a SubViewport the size of the height grid (halved, it is
## a soft signal), one ColorRect running sun_bake.gdshader, read back into an ImageTexture that every ground shader
## samples through the global `t_sun`.

const SCALE := 0.5


static func sun_vector() -> Vector3:
	var az := deg_to_rad(Cfg.f("sun.azimuth", 140)); var el := deg_to_rad(Cfg.f("sun.elevation", 40))
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))       # azimuth clockwise from north; z points south


func bake() -> void:
	var sun := sun_vector()
	var rs := RenderingServer
	rs.global_shader_parameter_set("sun_dir", sun)
	var c := Cfg.f("sun.contrast", 1.0)
	rs.global_shader_parameter_set("toon", Vector4(1.0 - 0.44 * c, 1.0 - 0.16 * c, 1.0 + 0.1 * c, Cfg.f("sun.shadow", 0.85)))
	var w := maxi(16, int(World.nx * SCALE)); var h := maxi(16, int(World.nz * SCALE))
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := ColorRect.new()
	rect.size = Vector2(w, h)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sun_bake.gdshader")
	mat.set_shader_parameter("heights", World.t_height)
	mat.set_shader_parameter("rect", Vector4(World.rect.position.x - World.cell * 0.5, World.rect.position.y - World.cell * 0.5, World.nx * World.cell, World.nz * World.cell))
	mat.set_shader_parameter("sun", sun)
	mat.set_shader_parameter("cloud_y", Cfg.f("cloudSea.height", 175))
	mat.set_shader_parameter("relief", Cfg.f("terrain.relief", 1.0))
	var sites: Array[Vector4] = []
	for S in World.layout.get("sites", []):
		sites.append(Vector4(S.x, S.z, S.R, maxf(0.0, float(S.cloud) - Cfg.f("cloudSea.height", 175))))
	while sites.size() < 6:
		sites.append(Vector4(1e9, 1e9, 1.0, 0.0))
	mat.set_shader_parameter("sites", sites)
	rect.material = mat
	vp.add_child(rect)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if OS.has_feature("editor") and "--dump-sun" in OS.get_cmdline_user_args():
		img.save_png("user://t_sun.png")
		print("t_sun saved to ", ProjectSettings.globalize_path("user://t_sun.png"), " ", img.get_size(), " centre ", img.get_pixel(img.get_width() / 2, img.get_height() / 2))
	rs.global_shader_parameter_set("t_sun", ImageTexture.create_from_image(img))
	vp.queue_free()
