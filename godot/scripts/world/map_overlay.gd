extends Control
## The 舆图's linework, painted once (demo paintMap L13273–13305): streams, roads (main dashed), the 天道盟小国 border,
## villages, post stations, towns, teleport arrays and the cities. Coordinates: world rect → this Control's pixels.

func _w(x: float, z: float) -> Vector2:
	var R := World.rect
	return Vector2((x - R.position.x) / R.size.x * size.x, (z - R.position.y) / R.size.y * size.y)


func _poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_w(p[0], p[1]))
	return out


func _draw() -> void:
	var P: Dictionary = World.paths
	var N := size.x   # world-proportional sizes (cities, the border label) scale with the canvas; line widths stay in pixels
	for s in P.get("streams", []):
		var pl := _poly(s.pts)
		if pl.size() > 1:
			draw_polyline(pl, Color(80 / 255.0, 118 / 255.0, 128 / 255.0, 0.85), 1.2, true)
	for r in P.get("rivers", []):
		var pl := _poly(r.pts)
		if pl.size() > 1:
			draw_polyline(pl, Color(80 / 255.0, 118 / 255.0, 128 / 255.0, 0.85), 2.0 if r.get("great", false) else 1.2, true)
	var road_col := Color(122 / 255.0, 74 / 255.0, 46 / 255.0, 0.78)
	for r in P.get("roads", []):
		var pl := _poly(r.pts)
		var main: bool = r.get("kind", "") == "main"
		# dashes along the polyline: main roads [7, 5] at 2.2 px, the rest [3, 4] at 1.3 px
		_dashed(pl, road_col, 2.2 if main else 1.3, 7.0 if main else 3.0, 5.0 if main else 4.0)
	# the 天道盟小国 border (GEO.border, L340) — given in base-map pixels
	var L: Dictionary = World.meta.layout
	var border := [1750.0, -15.0, 1608.0, 340.0, 1675.0, 390.0, 2225.0, 300.0, 2208.0, 145.0, 2330.0, -130.0]
	var bp := PackedVector2Array()
	for i in range(0, border.size(), 2):
		bp.append(_w((border[i] - L.origin[0]) * L.k, (border[i + 1] - L.origin[1]) * L.k))
	_dashed(bp, Color(70 / 255.0, 150 / 255.0, 120 / 255.0, 0.8), 2.4, 9.0, 6.0)
	var font: Font = load("res://fonts/NotoSerifSC-700.ttf")
	if bp.size() > 3:
		draw_string(font, bp[2] + Vector2(N / 60.0, -N / 160.0), "天道盟小国", HORIZONTAL_ALIGNMENT_LEFT, -1, int(N / 110.0), Color(60 / 255.0, 120 / 255.0, 100 / 255.0, 0.9))
	for v in P.get("villages", []):
		var c := _w(v.x, v.z)
		draw_circle(c, 4.2, Color(214 / 255.0, 196 / 255.0, 160 / 255.0, 0.95))
		draw_arc(c, 4.2, 0, TAU, 16, Color(110 / 255.0, 70 / 255.0, 44 / 255.0, 0.9), 1.2, true)
	for p in World.places:
		if p.cat != "city":
			continue
		var s := N * (0.008 if p.id == "minzhou" else 0.006)
		var c := _w(p.x, p.z)
		var r := Rect2(c - Vector2(s, s), Vector2(2 * s, 2 * s))
		draw_rect(r, Color(230 / 255.0, 214 / 255.0, 180 / 255.0, 0.92))
		draw_rect(r, Color(128 / 255.0, 58 / 255.0, 40 / 255.0, 0.95), false, 2.2)
		draw_line(c - Vector2(s, 0), c + Vector2(s, 0), Color(128 / 255.0, 58 / 255.0, 40 / 255.0, 0.95), 1.1)
		draw_line(c - Vector2(0, s), c + Vector2(0, s), Color(128 / 255.0, 58 / 255.0, 40 / 255.0, 0.95), 1.1)


func _dashed(pl: PackedVector2Array, col: Color, w: float, on: float, off: float) -> void:
	var carry := 0.0
	var drawing := true
	for i in range(pl.size() - 1):
		var a := pl[i]; var b := pl[i + 1]
		var seg := a.distance_to(b)
		var t := 0.0
		while t < seg:
			var left := (on if drawing else off) - carry
			var step := minf(left, seg - t)
			if drawing:
				draw_line(a.lerp(b, t / seg), a.lerp(b, (t + step) / seg), col, w, true)
			t += step
			carry += step
			if carry >= (on if drawing else off) - 1e-4:
				carry = 0.0
				drawing = not drawing
