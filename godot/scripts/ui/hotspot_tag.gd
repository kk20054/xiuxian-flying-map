extends VBoxContainer
## A sect tag (demo .lb-sect / .hs, L66–71 and L180–186): a vertical name on a blue slip, a white pin under it and,
## in flight, the "按 E 落脚" prompt that appears when the light is near. Anchored at the bottom of the pin.

signal pressed(place: Dictionary)

@onready var tag: PanelContainer = %Tag
@onready var tag_label: Label = %TagLabel
@onready var pin: Panel = %Pin
@onready var prompt: Control = %Prompt

var place: Dictionary = {}
var minor := false
var near := false
var selected := false


func setup(p: Dictionary, is_minor: bool, with_prompt: bool) -> void:
	place = p
	minor = is_minor
	tag_label.text = UIUtil.vertical(p.name)
	prompt.visible = with_prompt
	prompt.modulate.a = 0.0
	_style()


func set_near(on: bool) -> void:
	if on == near:
		return
	near = on
	_style()
	create_tween().tween_property(prompt, "modulate:a", 1.0 if on else 0.0, 0.3)


func set_selected(on: bool) -> void:
	if on != selected:
		selected = on
		_style()


func _style() -> void:
	var v := "SectTagNear" if near else ("SectTagMinor" if minor else ("SectTagSel" if selected else "SectTag"))
	tag.theme_type_variation = v
	pin.theme_type_variation = "PinSel" if (near or selected) else "Pin"


## The screen point the tag hangs from (the bottom of the pin) relative to this control.
func anchor_offset() -> Vector2:
	return Vector2(size.x * 0.5, pin.position.y + pin.size.y)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		pressed.emit(place)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER and not near and not minor:
		tag.theme_type_variation = "SectTagSel"
	elif what == NOTIFICATION_MOUSE_EXIT:
		_style()
