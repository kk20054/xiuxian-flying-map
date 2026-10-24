extends Node3D
## The procedural architecture and landmarks of the demo (06 / 06b–06e), exported as GLBs in world coordinates:
## each sect (sect_<id>.glb), its fine ground (sect_<id>_ground.glb) and what stands round it (_surroundings), the cities,
## the landmarks (props.glb). Loaded at runtime with GLTFDocument (data/world is .gdignore'd, so no import step and no
## importer welding the facet corners), then every surface gets the facet ink shader.
##
## To replace them with Blender models: bake the ink layout with tools/blender/bake_ink_layout.py (COLOR + UV2, see
## facet.gdshader) to get the facet ink; meshes without COLOR + UV2 keep their own glTF materials.

signal loaded_one(name: String)

const RELIEF_MAX := 2.0          # the 山高倍数 slider's top: facet.gdshader raises y > 0 by the relief

var facet: ShaderMaterial
var facet_ground: ShaderMaterial
var meshes := 0


func build() -> void:
	facet = ShaderMaterial.new()
	facet.shader = load("res://shaders/facet.gdshader")
	# the facet material shares the land's uniforms with the ranges (LU: uCreaseInk, uFootInk, uSoft, uCun, L4229–4241)
	for k in [["creaseInk", "crease_ink", 0.75], ["footInk", "foot_ink", 0.8], ["soft", "soft_k", 0.85], ["cun", "cun_k", 1.0]]:
		facet.set_shader_parameter(k[1], Cfg.f("terrain." + k[0], k[2]))
	facet_ground = facet.duplicate()
	facet_ground.set_shader_parameter("ground", true)
	var pr: Array[Vector4] = []
	for r in World.patch_rects:
		pr.append(Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
	while pr.size() < 6:
		pr.append(Vector4(1e9, 1e9, 1e9, 1e9))
	facet_ground.set_shader_parameter("patches", pr)
	facet_ground.set_shader_parameter("patch_count", World.patch_rects.size())
	facet_ground.set_shader_parameter("t_patch_h", World.t_patch_h)
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
		# GLTFDocument stores positions as 16 bits over each mesh's AABB (up to 2 丈 off on the world-spanning meshes):
		# rebuild the meshes from the uncompressed arrays
		var exact := {}
		for gm: GLTFMesh in state.get_meshes():
			var am := ArrayMesh.new()
			for si in gm.mesh.get_surface_count():
				am.add_surface_from_arrays(gm.mesh.get_surface_primitive_type(si), gm.mesh.get_surface_arrays(si))
				am.surface_set_material(si, gm.mesh.get_surface_material(si))
			exact[gm.mesh.get_mesh()] = am
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if exact.has(mi.mesh):
				mi.mesh = exact[mi.mesh]
		var ground: bool = String(f.file).ends_with("_ground.glb")
		root.name = String(f.file).get_file().get_basename()
		_apply(root, facet_ground if ground else facet)
		add_child(root)
		loaded_one.emit(root.name)
		await get_tree().process_frame


func _apply(n: Node, mat: Material, xf := Transform3D.IDENTITY) -> void:
	if n is Node3D:
		xf = xf * n.transform
	if n is MeshInstance3D:
		# the facet ink needs the baked layout (COLOR + UV2); anything else keeps the material it came with
		var am := (n as MeshInstance3D).mesh as ArrayMesh
		var need := Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV2
		if am != null and am.get_surface_count() > 0 and (am.surface_get_format(0) & need) == need:
			n.material_override = mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# room for the relief slider: the shader lifts everything above y = 0 (a 1000-丈 sect rises 1000 at relief 2)
		var top: float = (xf * (n as MeshInstance3D).get_aabb()).end.y
		n.extra_cull_margin = 200.0 + maxf(0.0, top) * (RELIEF_MAX - 1.0)
		meshes += 1
	for c in n.get_children():
		_apply(c, mat, xf)
