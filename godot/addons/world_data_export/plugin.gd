@tool
extends EditorPlugin
## data/world (the export) and data/terrain (a re-sculpt) are .gdignore'd, so a normal export leaves them out even when
## the include filter matches; this adds them to the pack as raw files (FileAccess, Image.load_from_file and
## GLTFDocument read them in the build). See docs/godot/01-pipeline-and-blender.md, "Shipping an exported build".

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = WorldDataExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)


class WorldDataExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "WorldDataExport"

	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		for d in ["res://data/world/", "res://data/terrain/"]:
			if DirAccess.dir_exists_absolute(d):
				_add_dir(d)

	func _add_dir(dir: String) -> void:
		for f in DirAccess.get_files_at(dir):
			if f != ".gdignore":
				add_file(dir + f, FileAccess.get_file_as_bytes(dir + f), false)
		for d in DirAccess.get_directories_at(dir):
			if d != "preview":
				_add_dir(dir + d + "/")
