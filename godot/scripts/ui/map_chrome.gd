extends CanvasLayer
## The 舆图's chrome (demo #map, L58–115; buildLabels L14357, updateLabels L14381, search L14449, legend/zoom L14552).
## Everything is placed by projecting world points through the live camera, so it rides the fly→map transition.

const TAG := preload("res://ui/hotspot_tag.tscn")
const ICON := {"mount": "△", "secret": "✦", "city": "◆", "feat": "·"}

@onready var map_root: Control = %MapRoot
@onready var plate: Control = %Plate
@onready var labels: Control = %Labels
@onready var trail: Control = %Trail
@onready var q: LineEdit = %Q
@onready var results: PanelContainer = %Results
@onready var result_list: VBoxContainer = %ResultList
@onready var btn_trail: Button = %BtnTrail
@onready var legend: Container = %LegendButtons
@onready var unroll: Label = %Unroll
@onready var me: Control = %Me

var items: Array = []            # [{place, node, sect}]
var on := false
var plate_rect := Rect2()


func _ready() -> void:
	map_root.modulate.a = 0.0
	map_root.visible = false
	unroll.modulate.a = 0.0
	results.visible = false
	plate.draw.connect(_draw_plate)
	trail.draw.connect(_draw_trail)
	q.text_changed.connect(_search)
	q.text_submitted.connect(func(_t): _pick_first())
	q.gui_input.connect(_q_input)
	btn_trail.toggled.connect(_trail_toggled)
	for b in legend.get_children():
		if b is Button:
			b.toggled.connect(_legend_toggled.bind(b))
	%ZIn.pressed.connect(_zoom.bind(1.0 / 1.5))
	%ZOut.pressed.connect(_zoom.bind(1.5))
	%ZHome.pressed.connect(_zoom.bind(0.0))
	World.ready_world.connect(_build)
	if World.loaded:
		_build()


func _build() -> void:
	for p in World.places:
		var n: Control
		var sect: bool = p.cat == "sect"
		if sect:
			n = TAG.instantiate()
			labels.add_child(n)
			n.setup(p, false, false)
			n.pressed.connect(_select)
		else:
			var l := Label.new()
			l.text = (ICON[p.cat] + " " if ICON.has(p.cat) else "") + p.name
			l.label_settings = _settings(p.cat)
			l.mouse_filter = Control.MOUSE_FILTER_STOP
			l.gui_input.connect(_label_input.bind(p))
			if p.id in Game.MINOR:
				l.modulate.a = 0.9
			labels.add_child(l)
			n = l
		items.append({"place": p, "node": n, "sect": sect})
	labels.move_child(me, -1)


func _settings(cat: String) -> LabelSettings:
	var halo := Color("#1b2523")
	match cat:
		"mount": return UIUtil.ls(UIUtil.serif(600), 13, UIUtil.MOUNT, Color(0.08, 0.12, 0.11, 0.9), 6, halo, 3)
		"secret": return UIUtil.ls(UIUtil.serif(600), 13, UIUtil.SECRET, Color(0.08, 0.12, 0.11, 0.9), 6, halo, 3)
		"city": return UIUtil.ls(UIUtil.serif(600), 13, UIUtil.CITY, Color(0.08, 0.12, 0.11, 0.9), 6, halo, 3)
		"feat": return UIUtil.ls(UIUtil.serif(400), 12, UIUtil.WATER, Color(0.08, 0.12, 0.11, 0.9), 6, halo, 3)
		"region": return UIUtil.ls(UIUtil.spaced(UIUtil.serif(900), 22, 0.12), 22, Color("#f7f2e4"), Color(0.08, 0.12, 0.11, 0.8), 10, Color("#1d2725"), 4)
		"state": return UIUtil.ls(UIUtil.spaced(UIUtil.serif(400), 14, 0.1), 14, Color("#d8d1bf"), Color(0.08, 0.12, 0.11, 0.8), 6, Color("#1d2725"), 3)
		"alliance": return UIUtil.ls(UIUtil.spaced(UIUtil.serif(700), 34, 0.9), 34, Color(28 / 255.0, 40 / 255.0, 38 / 255.0, 0.55))
		"sea": return UIUtil.ls(UIUtil.spaced(UIUtil.serif(600), 34, 1.0), 34, Color(186 / 255.0, 214 / 255.0, 214 / 255.0, 0.55))
	return UIUtil.ls(UIUtil.serif(400), 12, UIUtil.CHROME_DIM, Color(0.06, 0.12, 0.11), 4)


func _process(_dt: float) -> void:
	var d := UIUtil.director()
	if d == null:
		return
	# the chrome fades in late in the to-map transition (t > 0.8) and out at once when leaving
	var want: bool = Game.mode == Game.Mode.MAP or (Game.mode == Game.Mode.TO_MAP and d.trans > 0.8)
	if want != on:
		on = want
		create_tween().tween_property(map_root, "modulate:a", 1.0 if on else 0.0, 0.7)
		if not on:
			results.visible = false
			q.release_focus()
	map_root.visible = map_root.modulate.a > 0.01
	unroll.modulate.a = move_toward(unroll.modulate.a, 1.0 if (Game.mode == Game.Mode.TO_MAP and d.trans > 0.25 and d.trans < 0.86) else 0.0, _dt / 0.4)
	if not map_root.visible:
		return
	var cam: Camera3D = d.cam
	var vp := map_root.get_viewport_rect().size
	# the plate: the world rect on screen
	var a := cam.unproject_position(Vector3(World.rect.position.x, 0, World.rect.position.y))
	var b := cam.unproject_position(Vector3(World.rect.end.x, 0, World.rect.end.y))
	plate_rect = Rect2(a, b - a).abs()
	plate.queue_redraw()
	if Game.trail:
		trail.queue_redraw()
	var minor_cut: float = 3400.0 * float(World.meta.layout.S)
	for it in items:
		var p: Dictionary = it.place
		var n: Control = it.node
		var hide: bool = Game.map_k < 0.6 or Game.label_hidden(p) or (p.id in Game.MINOR and d.map_view > minor_cut)
		var s := cam.unproject_position(Vector3(p.x, 0, p.z))
		if not hide:
			hide = s.x < -120 or s.x > vp.x + 120 or s.y < -80 or s.y > vp.y + 80
		n.visible = not hide
		if hide:
			continue
		if it.sect:
			n.set_selected(Game.selected == p)
			n.position = s - n.anchor_offset()
		else:
			n.position = s - n.size * 0.5
	# the player marker
	var ms := cam.unproject_position(Vector3(d.pos.x, 0, d.pos.z))
	me.visible = Game.map_k > 0.3
	me.modulate.a = smoothstep(0.3, 0.8, Game.map_k)
	me.position = ms - Vector2(me.size.x * 0.5, 6.0)


func _draw_plate() -> void:
	var vp := plate.get_viewport_rect().size
	var r := plate_rect
	var dark := Color(11 / 255.0, 22 / 255.0, 24 / 255.0, 0.94)
	# everything outside the world rect sinks into a dark teal (CSS box-shadow 0 0 0 200vmax)
	plate.draw_rect(Rect2(0, 0, vp.x, r.position.y), dark)
	plate.draw_rect(Rect2(0, r.end.y, vp.x, vp.y - r.end.y), dark)
	plate.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dark)
	plate.draw_rect(Rect2(r.end.x, r.position.y, vp.x - r.end.x, r.size.y), dark)
	var gold := Color(214 / 255.0, 180 / 255.0, 110 / 255.0)
	plate.draw_rect(r, Color(gold, 0.35), false, 1.0)
	plate.draw_rect(r.grow(7.0), Color(gold, 0.55), false, 1.0)
	var L := 18.0
	var corners := [[r.position + Vector2(-12, -12), Vector2(1, 1)], [Vector2(r.end.x + 12, r.position.y - 12), Vector2(-1, 1)],
		[Vector2(r.position.x - 12, r.end.y + 12), Vector2(1, -1)], [r.end + Vector2(12, 12), Vector2(-1, -1)]]
	for c in corners:
		var o: Vector2 = c[0]; var dd: Vector2 = c[1]
		plate.draw_line(o, o + Vector2(dd.x * L, 0), Color(gold, 0.7), 2.0)
		plate.draw_line(o, o + Vector2(0, dd.y * L), Color(gold, 0.7), 2.0)


## 韩立行迹: a dashed gold line through the three stations, numbered (demo #trailSvg L85–87).
func _draw_trail() -> void:
	if not Game.trail or Game.map_k < 0.6:
		return
	var d := UIUtil.director()
	var pts := PackedVector2Array()
	for st in Game.TRAIL:
		var p = World.by_id.get(st[0])
		if p != null:
			pts.append(d.cam.unproject_position(Vector3(p.x, 0, p.z)))
	var gold := Color("#f2d58a")
	for i in range(pts.size() - 1):
		trail.draw_dashed_line(pts[i] + Vector2(1, 1), pts[i + 1] + Vector2(1, 1), Color(0, 0, 0, 0.35), 3.0, 7.0)
		trail.draw_dashed_line(pts[i], pts[i + 1], gold, 2.2, 7.0)
	var font := UIUtil.serif(700)
	for i in pts.size():
		trail.draw_circle(pts[i], 6.5, Color("#2b2416"))
		trail.draw_circle(pts[i], 5.0, gold)
		var text: String = Game.TRAIL[i][1]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var at := pts[i] + Vector2(-w * 0.5, 21)
		trail.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color("#1b2220"))
		trail.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f6e7bd"))


# ── search (L14449): plain substring over name, breadcrumb and lead; first 8 ──
func _search(text: String) -> void:
	for c in result_list.get_children():
		c.queue_free()
	text = text.strip_edges()
	if text == "":
		results.visible = false
		return
	var hits := World.places.filter(func(p): return p.name.contains(text) or String(p.get("crumb", "")).contains(text) or String(p.get("lead", "")).contains(text)).slice(0, 8)
	if hits.is_empty():
		var b := Button.new()
		b.text = "没有找到「%s」" % text
		b.disabled = true
		b.theme_type_variation = "ResultButton"
		result_list.add_child(b)
	for i in hits.size():
		var p: Dictionary = hits[i]
		var b := Button.new()
		b.theme_type_variation = "ResultButtonAct" if i == 0 else "ResultButton"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s    %s" % [p.name, p.get("type", "")]
		b.pressed.connect(_result_pressed.bind(p))
		result_list.add_child(b)
	results.visible = true


func _result_pressed(p: Dictionary) -> void:
	_select(p)
	q.text = ""
	results.visible = false


func _pick_first() -> void:
	for c in result_list.get_children():
		if c is Button and not c.disabled:
			c.pressed.emit()
			return


func _q_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		q.text = ""; results.visible = false; q.release_focus()
		q.accept_event()


func _unhandled_input(ev: InputEvent) -> void:
	if Game.mode == Game.Mode.MAP and ev.is_action_pressed("focus_search"):
		q.grab_focus()
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed:
		results.visible = false


## + / − / ⌂ (factor 0 = home), only while the chrome is on
func _zoom(factor: float) -> void:
	if not on:
		return
	if factor == 0.0:
		UIUtil.director().map_home_view()
	else:
		UIUtil.director().zoom_map(factor)


func _label_input(ev: InputEvent, p: Dictionary) -> void:
	if on and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_select(p)


func _select(p: Dictionary) -> void:
	if on:
		UIUtil.director().select_place(p, true)


func _trail_toggled(v: bool) -> void:
	Game.trail = v
	btn_trail.modulate.a = 1.0 if v else 0.42
	trail.queue_redraw()


func _legend_toggled(pressed: bool, b: Button) -> void:
	Game.hidden_cats[b.get_meta("cat")] = not pressed
	b.modulate.a = 1.0 if pressed else 0.42
	Game.legend_changed.emit()
