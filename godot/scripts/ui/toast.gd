extends CanvasLayer
## A short message top centre (demo #toast L148): slides down 8 px and fades in, gone after 3.4 s.

@onready var panel: Control = %ToastPanel
@onready var label: Label = %ToastLabel
var _gen := 0


func _ready() -> void:
	panel.modulate.a = 0.0
	Game.toast.connect(show_text)


func show_text(text: String) -> void:
	_gen += 1
	var g := _gen
	label.text = text
	await get_tree().process_frame
	var vp := panel.get_viewport_rect().size
	var x := (vp.x - panel.size.x) * 0.5
	panel.position = Vector2(x, 10)
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "modulate:a", 1.0, 0.4)
	tw.tween_property(panel, "position:y", 18.0, 0.4)
	await get_tree().create_timer(3.4).timeout
	if g == _gen:
		var tw2 := create_tween().set_parallel()
		tw2.tween_property(panel, "modulate:a", 0.0, 0.4)
		tw2.tween_property(panel, "position:y", 10.0, 0.4)
