extends CanvasLayer
## 御空 / 收图 — the segmented switch top right (demo #modeSwitch L44–47). The lit segment follows the mode you are
## going to, from the start of a transition.

@onready var fly: Button = %SegFly
@onready var map: Button = %SegMap


func _ready() -> void:
	fly.pressed.connect(_toggle)
	map.pressed.connect(_toggle)
	Game.mode_changed.connect(_sync)
	_sync(Game.mode)


func _toggle() -> void:
	var d := UIUtil.director()
	if d:
		d.toggle_map()
	_sync(Game.mode)


func _sync(m) -> void:
	var to_map: bool = m == Game.Mode.MAP or m == Game.Mode.TO_MAP
	fly.theme_type_variation = "ModeSeg" if to_map else "ModeSegOn"
	map.theme_type_variation = "ModeSegOn" if to_map else "ModeSeg"
