extends Node3D
## The procedural architecture and landmarks of the demo (06 / 06b–06e), exported as GLBs in world coordinates:
## each sect (sect_<id>.glb), its fine ground (sect_<id>_ground.glb) and what stands round it (_surroundings), the cities,
## the landmarks (props.glb). Loaded at runtime with GLTFDocument (data/world is .gdignore'd, so no import step and no
## importer welding the facet corners), then every surface gets the facet ink shader.
##
## To replace them with Blender models: keep the same vertex layout (see facet.gdshader) or give your meshes any
## material you like — the scene only needs MeshInstance3Ds at world positions.

signal loaded_one(name: String)

var facet: ShaderMaterial
var facet_ground: ShaderMaterial
var meshes := 0


func build() -> void:
	facet = ShaderMaterial.new()
	facet.shader = load("res://shaders/facet.gdshader")
	facet.set_shader_parameter("crease_ink", Cfg.f("terrain.creaseInk", 0.75))
	facet_ground = facet.duplicate()
	facet_ground.set_shader_parameter("ground", true)
	var files: Array = World.meta.get("meshes", {}).get("files", [])
	for f in files:
		var path: String = World.DIR + f.file
		if not FileAccess.file_exists(path):
			continue
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) != OK:
			push_warning("props: cannot read " + path)
			continue
		var root := doc.generate_scene(state)
		if root == null:
			continue
		var ground: bool = String(f.file).ends_with("_ground.glb")
		root.name = String(f.file).get_file().get_basename()
		_apply(root, facet_ground if ground else facet)
		add_child(root)
		loaded_one.emit(root.name)
		await get_tree().process_frame


func _apply(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		n.material_override = mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.extra_cull_margin = 200.0
		meshes += 1
	for c in n.get_children():
		_apply(c, mat)
