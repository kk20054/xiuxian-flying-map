extends MeshInstance3D
## The painted 舆图 plane (demo buildMap2D L13250) and its overlay (paintMap L13273): one PlaneMesh three times the
## world's size at y = 1, drawn over everything while map_k > 0; the roads, villages, posts, arrays and cities are
## painted once into a SubViewport (MapOverlay) and sampled as t_over.

var mat: ShaderMaterial
var overlay: SubViewport


func build() -> void:
	var R := World.rect
	var size := 3.0 * maxf(R.size.x, R.size.y)
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mesh = pm
	position = Vector3(R.get_center().x, 1.0, R.get_center().y)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/map2d.gdshader")
	mat.set_shader_parameter("cell", World.cell)
	mat.render_priority = 60
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-size / 2, -10, -size / 2), Vector3(size, 20, size))
	visible = false
	overlay = SubViewport.new()
	overlay.size = Vector2i(4096, int(4096.0 * R.size.y / R.size.x))   # the demo paints 2048 wide; 4096 keeps the roads crisper close up
	overlay.transparent_bg = true
	overlay.disable_3d = true
	overlay.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := preload("res://scripts/world/map_overlay.gd").new()
	painter.size = Vector2(overlay.size)
	overlay.add_child(painter)
	add_child(overlay)
	await RenderingServer.frame_post_draw
	var img := overlay.get_texture().get_image()
	img.generate_mipmaps()
	mat.set_shader_parameter("t_over", ImageTexture.create_from_image(img))


func _process(_dt: float) -> void:
	visible = Game.map_k > 0.001
