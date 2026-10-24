extends CanvasLayer
## "展卷中 N%" with a jade spinner, top right under the switch (demo #loading L190–193).

@onready var root: Control = %LoadingRoot
@onready var label: Label = %LoadingLabel
@onready var spinner: Control = %Spinner
var _a := 0.0


func _ready() -> void:
	World.progress.connect(func(_k, text): label.text = text)
	spinner.draw.connect(_draw_spinner)


func set_text(text: String) -> void:
	label.text = text


func _process(dt: float) -> void:
	_a += dt * TAU
	spinner.queue_redraw()
	var want := 0.9 if Game.mode == Game.Mode.LOADING else 0.0
	root.modulate.a = move_toward(root.modulate.a, want, dt / 0.6)
	root.visible = root.modulate.a > 0.01


func _draw_spinner() -> void:
	var c := spinner.size * 0.5
	spinner.draw_arc(c, 6.0, 0, TAU, 24, Color(63 / 255.0, 155 / 255.0, 134 / 255.0, 0.25), 2.0, true)
	spinner.draw_arc(c, 6.0, _a, _a + PI * 0.5, 8, UIUtil.JADE, 2.0, true)
