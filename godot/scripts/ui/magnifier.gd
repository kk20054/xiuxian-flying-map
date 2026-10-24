extends Control
## The search field's magnifier (the demo's inline SVG: circle r 6.5 at (10.5, 10.5), handle to (21, 21), stroke 2).

func _draw() -> void:
	var s := size.x / 24.0
	var col := Color(UIUtil.CHROME_TEXT, 0.85)
	draw_arc(Vector2(10.5, 10.5) * s, 6.5 * s, 0, TAU, 24, col, 2.0, true)
	draw_line(Vector2(15.5, 15.5) * s, Vector2(21, 21) * s, col, 2.0, true)
