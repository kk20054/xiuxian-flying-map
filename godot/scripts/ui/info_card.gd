extends CanvasLayer
## The info card (demo #panel, L116–138; fillCard L14414; openCard/selectPoi/closePanel L14426–14447).

@onready var card: Control = %Card
@onready var body: VBoxContainer = %Body
@onready var scroll: ScrollContainer = %Scroll
@onready var go: Button = %Go
@onready var copy: Button = %Copy

var place: Dictionary = {}
var home_x := 0.0
var open := false


func _ready() -> void:
	card.modulate.a = 0.0
	card.visible = false
	Game.card_open.connect(_open)
	Game.card_close.connect(_close)
	%Close.pressed.connect(Game.close_card)
	go.pressed.connect(func(): UIUtil.director().fly_to(place))
	copy.pressed.connect(_copy)
	get_viewport().size_changed.connect(_layout)
	_layout()


## top 78 / right 16 / bottom 16, width min(420, w − 32); a bottom sheet (62 % high) under 640 px.
func _layout() -> void:
	var vp := card.get_viewport_rect().size
	var w := minf(420.0, vp.x - 32.0)
	if vp.x <= 640.0:
		card.position = Vector2(16, vp.y * 0.38 - 16)
		card.size = Vector2(vp.x - 32, vp.y * 0.62)
	else:
		card.position = Vector2(vp.x - 16 - w, 78)
		card.size = Vector2(w, vp.y - 78 - 16)
	home_x = card.position.x


func _open(p: Dictionary, from_flight: bool) -> void:
	place = p
	_fill(p)
	go.visible = not from_flight and Game.can_fly_to(p)
	scroll.scroll_vertical = 0
	if not open:
		open = true
		_layout()
		card.visible = true
		card.position.x = home_x + 24
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.35)
		tw.tween_property(card, "position:x", home_x, 0.35)


func _close() -> void:
	if not open:
		return
	open = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 0.0, 0.35)
	tw.tween_property(card, "position:x", home_x + 24, 0.35)
	tw.chain().tween_callback(func(): card.visible = open)


func _copy() -> void:
	DisplayServer.clipboard_set(String(place.get("name", "")).replace(" ↗", ""))
	copy.text = "已复制"
	await get_tree().create_timer(1.4).timeout
	copy.text = "复制地名"


func _fill(p: Dictionary) -> void:
	for c in body.get_children():
		c.queue_free()
	# .meta: type · [ally pill]
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 10)
	meta.add_child(_label(p.get("type", ""), UIUtil.serif(400), 13, UIUtil.CHROME_DIM))
	if p.has("ally") and p.ally:
		var pill := PanelContainer.new()
		pill.theme_type_variation = "Pill"
		pill.add_child(_label("● " + p.ally, UIUtil.serif(400), 12, UIUtil.CHROME_TEXT))
		meta.add_child(pill)
	body.add_child(meta)
	var h2 := _label(String(p.name).replace(" ↗", ""), UIUtil.brush(), 44, UIUtil.CHROME_TEXT)
	body.add_child(_spaced(h2, 10, 2))
	if p.has("crumb"):
		body.add_child(_label(p.crumb, UIUtil.serif(400), 13, UIUtil.CHROME_DIM))
	if p.has("lead"):
		body.add_child(_spaced(_label(p.lead, UIUtil.serif(600), 17, UIUtil.CHROME_TEXT, true, 10), 18, 10))
	for para in p.get("body", []):
		body.add_child(_spaced(_label(para, UIUtil.serif(400), 15, Color("#d9d4c6"), true, 12), 0, 12))
	if p.has("note"):
		body.add_child(_sub("图中所绘"))
		var tex := _card_image(p.id)
		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			body.add_child(img)
		var qp := PanelContainer.new()
		qp.theme_type_variation = "Quote"
		qp.add_child(_label(p.note, UIUtil.serif(400), 14, Color("#cfd6d2"), true, 11))
		body.add_child(qp)
	if p.has("chips") and p.chips is Array and not p.chips.is_empty():
		body.add_child(_sub("境内"))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for name in p.chips:
			var b := Button.new()
			b.text = name
			b.theme_type_variation = "Chip"
			b.pressed.connect(_chip.bind(name))
			flow.add_child(b)
		body.add_child(flow)


func _chip(name: String) -> void:
	if World.by_name.has(name):
		UIUtil.director().select_place(World.by_name[name], true)


func _card_image(id: String) -> Texture2D:
	var path := "res://ui/cards/card_%s.jpg" % id
	return load(path) if ResourceLoader.exists(path) else null


func _label(text: String, font: Font, size: int, col: Color, wrap := false, line_gap := 0) -> Label:
	var l := Label.new()
	l.text = text
	var s := UIUtil.ls(font, size, col)
	s.line_spacing = line_gap
	l.label_settings = s
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.custom_minimum_size.x = 10
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _spaced(c: Control, top: int, bottom: int) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.add_child(c)
	return m


## .sub: a small spaced title followed by a hairline (CSS ::after flex line)
func _sub(text: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := _label(text, UIUtil.spaced(UIUtil.serif(400), 13, 0.2), 13, UIUtil.CHROME_DIM)
	h.add_child(l)
	var line := ColorRect.new()
	line.color = UIUtil.CHROME_LINE
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(line)
	return _spaced(h, 18, 10)
