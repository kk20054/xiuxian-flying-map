extends VBoxContainer
## 遁光所在 — the player's place on the 舆图: a jade dot that pulses (CSS mepulse 2.2 s: ring 3→6 px, glow 10→20 px).

@onready var dot: Control = %MeDot
var t := 0.0


func _ready() -> void:
	dot.draw.connect(_draw_dot)


func _process(dt: float) -> void:
	if visible:
		t += dt
		dot.queue_redraw()


func _draw_dot() -> void:
	var c := dot.size * 0.5
	var k := 0.5 - 0.5 * cos(t / 2.2 * TAU)
	var glow := lerpf(10.0, 20.0, k)
	for i in 6:
		var f := float(i + 1) / 6.0
		dot.draw_circle(c, 6.0 + glow * f, Color(111 / 255.0, 224 / 255.0, 192 / 255.0, lerpf(0.55, 0.8, k) * 0.12 * (1.0 - f)))
	dot.draw_circle(c, 6.0 + lerpf(3.0, 6.0, k), Color(63 / 255.0, 155 / 255.0, 134 / 255.0, lerpf(0.35, 0.18, k)))
	dot.draw_circle(c, 6.0, UIUtil.JADE_HI)
