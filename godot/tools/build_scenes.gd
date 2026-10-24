extends Node
## Generates the UI theme and every scene of the port from code, so they are valid and editable in the Godot editor:
##   godot --headless --path godot --script res://tools/build_scenes.gd
## Re-run after changing the look here; or edit the saved .tscn/.tres in the editor and stop using this script.
## All values come from the demo's CSS (index.html L9–204).

const U := preload("res://scripts/ui/ui_util.gd")

var theme := Theme.new()


func _ready() -> void:
	_theme()
	ResourceSaver.save(theme, "res://ui/theme/ink_theme.tres")
	_save(_hotspot_tag(), "res://ui/hotspot_tag.tscn")
	_save(_hud(), "res://ui/hud.tscn")
	_save(_hotspots(), "res://ui/hotspots.tscn")
	_save(_map_chrome(), "res://ui/map_chrome.tscn")
	_save(_info_card(), "res://ui/info_card.tscn")
	_save(_intro(), "res://ui/intro.tscn")
	_save(_mode_switch(), "res://ui/mode_switch.tscn")
	_save(_debug(), "res://ui/debug_panel.tscn")
	_save(_toast(), "res://ui/toast.tscn")
	_save(_loading(), "res://ui/loading.tscn")
	_save(_touch(), "res://ui/touch.tscn")
	_save(_main(), "res://scenes/main.tscn")
	print("built theme and scenes")
	get_tree().quit()


# ───────────────────────── theme ─────────────────────────

func _sb(bg: Color, r := 0, bw := 0, bc := Color(0, 0, 0, 0), m := Vector4.ZERO) -> StyleBoxFlat:
	return U.box(bg, r, bw, bc, m)


func _variation(name: String, base: String, style: StyleBox, prop := "panel") -> void:
	theme.set_type_variation(name, base)
	theme.set_stylebox(prop, name, style)


func _button(name: String, normal: StyleBox, hover: StyleBox, font: Font, size: int, col: Color, hover_col := Color(0, 0, 0, 0), pressed: StyleBox = null) -> void:
	theme.set_type_variation(name, "Button")
	theme.set_stylebox("normal", name, normal)
	theme.set_stylebox("hover", name, hover)
	theme.set_stylebox("pressed", name, pressed if pressed else hover)
	theme.set_stylebox("hover_pressed", name, pressed if pressed else hover)
	theme.set_stylebox("disabled", name, normal)
	var f := StyleBoxFlat.new(); f.draw_center = false; f.set_border_width_all(2); f.border_color = U.JADE_HI; f.set_corner_radius_all(normal.corner_radius_top_left if normal is StyleBoxFlat else 8); f.expand_margin_left = 2; f.expand_margin_right = 2; f.expand_margin_top = 2; f.expand_margin_bottom = 2
	theme.set_stylebox("focus", name, f)
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, col)
	theme.set_color("font_hover_color", name, hover_col if hover_col.a > 0 else col)
	theme.set_color("font_pressed_color", name, hover_col if hover_col.a > 0 else col)
	theme.set_color("font_hover_pressed_color", name, hover_col if hover_col.a > 0 else col)
	theme.set_color("font_focus_color", name, col)
	theme.set_color("font_disabled_color", name, U.CHROME_DIM)


func _theme() -> void:
	theme.default_font = U.serif(400)
	theme.default_font_size = 14
	var chrome := _sb(U.CHROME, 12, 1, U.CHROME_LINE)
	chrome.shadow_color = Color(0, 0, 0, 0.28); chrome.shadow_size = 12; chrome.shadow_offset = Vector2(0, 8)
	_variation("Chrome", "PanelContainer", chrome)
	var chrome_pad := chrome.duplicate(); chrome_pad.content_margin_left = 4; chrome_pad.content_margin_right = 4; chrome_pad.content_margin_top = 4; chrome_pad.content_margin_bottom = 4
	_variation("ChromePad", "PanelContainer", chrome_pad)
	_variation("ChromeNoShadow", "PanelContainer", _sb(U.CHROME, 12, 1, U.CHROME_LINE, Vector4(4, 4, 4, 4)))
	var seal := _sb(U.CINNABAR, 6, 2, Color(1, 0.925, 0.863, 0.35), Vector4(2, 2, 2, 2))
	seal.shadow_color = Color(0, 0, 0, 0.25); seal.shadow_size = 2; seal.shadow_offset = Vector2(0, 1)
	_variation("Seal", "PanelContainer", seal)
	var seal46 := seal.duplicate(); seal46.set_corner_radius_all(7)
	_variation("Seal46", "PanelContainer", seal46)
	# sect tags: blue slip with a 1 px ring and a soft drop shadow (box-shadow 0 0 0 1px ring, 0 3px 10px)
	var tag := _sb(U.SECT, 3, 1, U.SECT_LINE, Vector4(3, 8, 3, 6))
	tag.shadow_color = Color(0, 0, 0, 0.35); tag.shadow_size = 5; tag.shadow_offset = Vector2(0, 3)
	_variation("SectTag", "PanelContainer", tag)
	var tag_sel := tag.duplicate(); tag_sel.bg_color = Color("#6a90b8")
	_variation("SectTagSel", "PanelContainer", tag_sel)
	var tag_near := tag.duplicate(); tag_near.bg_color = U.JADE; tag_near.border_color = U.JADE_HI; tag_near.shadow_color = Color(0.435, 0.878, 0.753, 0.55); tag_near.shadow_size = 14; tag_near.shadow_offset = Vector2.ZERO
	_variation("SectTagNear", "PanelContainer", tag_near)
	var tag_minor := tag.duplicate(); tag_minor.bg_color = Color("#5d7a72"); tag_minor.border_color = Color("#87a59c")
	_variation("SectTagMinor", "PanelContainer", tag_minor)
	_variation("Pin", "Panel", _sb(Color.WHITE, 4, 2, Color("#2d4560")))
	_variation("PinSel", "Panel", _sb(U.JADE_HI, 4, 2, Color("#2d4560")))
	_variation("PromptPill", "PanelContainer", _sb(Color(17 / 255.0, 31 / 255.0, 29 / 255.0, 0.82), 999, 1, Color(0.435, 0.878, 0.753, 0.45), Vector4(10, 3, 10, 3)))
	_variation("HintPanel", "PanelContainer", _sb(Color(0.965, 0.941, 0.878, 0.72), 10, 1, Color(0.314, 0.259, 0.173, 0.18), Vector4(14, 10, 14, 10)))
	var key := _sb(Color(0.149, 0.137, 0.122, 0.08), 5, 1, Color(0.149, 0.137, 0.122, 0.2), Vector4(5, 0, 5, 0)); key.border_width_bottom = 2
	_variation("KeyCap", "PanelContainer", key)
	_variation("Pill", "PanelContainer", _sb(Color(0, 0, 0, 0), 999, 1, Color(0.627, 0.784, 0.745, 0.35), Vector4(10, 2, 10, 2)))
	var quote := _sb(Color(1, 1, 1, 0.04), 0, 0, U.JADE, Vector4(14, 10, 14, 10)); quote.border_width_left = 2; quote.corner_radius_top_right = 8; quote.corner_radius_bottom_right = 8
	_variation("Quote", "PanelContainer", quote)
	_variation("ToastPanel", "PanelContainer", _sb(U.CHROME, 10, 1, U.CHROME_LINE, Vector4(14, 8, 14, 8)))
	var dh := _sb(U.CHROME_SOLID, 0, 0, U.CHROME_LINE, Vector4(14, 12, 14, 8)); dh.border_width_bottom = 1; dh.corner_radius_top_left = 12; dh.corner_radius_top_right = 12
	_variation("DebugHeader", "PanelContainer", dh)
	var foot := _sb(Color(0, 0, 0, 0), 0, 0, U.CHROME_LINE, Vector4(24, 14, 24, 18)); foot.border_width_top = 1
	_variation("CardFooter", "PanelContainer", foot)
	_variation("PadPanel", "Panel", _sb(Color(0.965, 0.941, 0.878, 0.35), 58, 1, Color(0.235, 0.196, 0.118, 0.25)))
	_variation("KnobPanel", "Panel", _sb(Color(0.247, 0.608, 0.525, 0.55), 23, 1, Color(1, 1, 1, 0.6)))
	# buttons
	var clear := _sb(Color(0, 0, 0, 0), 8, 0, Color(0, 0, 0, 0), Vector4(12, 8, 12, 8))
	var hov := _sb(U.CHROME_2, 8, 0, Color(0, 0, 0, 0), Vector4(12, 8, 12, 8))
	_button("LegendButton", clear, hov, U.serif(400), 15, U.CHROME_TEXT)
	var zc := _sb(Color(0, 0, 0, 0), 8); var zh := _sb(U.CHROME_2, 8)
	_button("ZoomButton", zc, zh, U.serif(400), 20, U.CHROME_TEXT)
	var rc := _sb(Color(0, 0, 0, 0), 8, 0, Color(0, 0, 0, 0), Vector4(10, 8, 10, 8)); var rh := _sb(U.CHROME_2, 8, 0, Color(0, 0, 0, 0), Vector4(10, 8, 10, 8))
	_button("ResultButton", rc, rh, U.serif(400), 14, U.CHROME_TEXT)
	_button("ResultButtonAct", rh, rh, U.serif(400), 14, U.CHROME_TEXT)
	var seg := _sb(Color(0, 0, 0, 0), 9, 0, Color(0, 0, 0, 0), Vector4(14, 9, 14, 8))
	var seg_on := _sb(U.CHROME_2, 9, 1, Color(0.627, 0.784, 0.745, 0.18), Vector4(14, 9, 14, 8))
	_button("ModeSeg", seg, seg, U.spaced(U.brush(), 19, 0.1), 19, U.CHROME_DIM, U.CHROME_TEXT)
	_button("ModeSegOn", seg_on, seg_on, U.spaced(U.brush(), 19, 0.1), 19, U.CHROME_TEXT)
	var go := _sb(U.JADE, 9, 1, U.JADE, Vector4(14, 8, 14, 8)); var go_h := go.duplicate(); go_h.bg_color = U.JADE.lightened(0.12)
	_button("GoButton", go, go_h, U.serif(400), 14, Color("#f4fffb"))
	var fb := _sb(Color(1, 1, 1, 0.03), 9, 1, U.CHROME_LINE, Vector4(14, 8, 14, 8)); var fb_h := fb.duplicate(); fb_h.bg_color = Color(1, 1, 1, 0.08)
	_button("FooterButton", fb, fb_h, U.serif(400), 14, U.CHROME_TEXT)
	var chip := _sb(Color(1, 1, 1, 0.04), 999, 1, U.CHROME_LINE, Vector4(12, 5, 12, 5)); var chip_h := chip.duplicate(); chip_h.bg_color = U.CHROME_2
	_button("Chip", chip, chip_h, U.serif(400), 14, U.CHROME_TEXT)
	var cl := _sb(Color(0, 0, 0, 0), 8); var cl_h := _sb(U.CHROME_2, 8)
	_button("CloseButton", cl, cl_h, U.serif(400), 22, U.CHROME_DIM, U.CHROME_TEXT)
	var small := _sb(Color(0, 0, 0, 0), 7, 1, U.CHROME_LINE, Vector4(9, 3, 9, 3)); var small_h := small.duplicate(); small_h.bg_color = U.CHROME_2
	_button("SmallButton", small, small_h, U.serif(400), 12, U.CHROME_DIM, U.CHROME_TEXT)
	var boost := _sb(Color(0.247, 0.608, 0.525, 0.45), 35, 1, Color(0.235, 0.196, 0.118, 0.25))
	_button("BoostButton", boost, boost, U.brush(), 22, Color.WHITE)
	# search field: transparent LineEdit on the chrome
	theme.set_type_variation("SearchEdit", "LineEdit")
	var le := StyleBoxEmpty.new()
	theme.set_stylebox("normal", "SearchEdit", le); theme.set_stylebox("focus", "SearchEdit", le); theme.set_stylebox("read_only", "SearchEdit", le)
	theme.set_font("font", "SearchEdit", U.serif(400)); theme.set_font_size("font_size", "SearchEdit", 15)
	theme.set_color("font_color", "SearchEdit", U.CHROME_TEXT); theme.set_color("font_placeholder_color", "SearchEdit", U.CHROME_DIM)
	theme.set_color("caret_color", "SearchEdit", U.JADE_HI); theme.set_color("selection_color", "SearchEdit", Color(U.JADE, 0.5))
	# sliders and text in the debug panel
	var track := _sb(U.CHROME_2, 3, 0); track.content_margin_top = 2; track.content_margin_bottom = 2
	var fill := _sb(U.JADE, 3, 0); fill.content_margin_top = 2; fill.content_margin_bottom = 2
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	theme.set_stylebox("normal", "TextEdit", _sb(Color("#0d1917"), 6, 1, U.CHROME_LINE, Vector4(6, 6, 6, 6)))
	theme.set_color("font_color", "TextEdit", Color("#ccffee"))
	theme.set_font_size("font_size", "TextEdit", 11)
	var sc := _sb(Color(1, 1, 1, 0.06), 3); var scg := _sb(Color(1, 1, 1, 0.22), 3)
	theme.set_stylebox("scroll", "VScrollBar", sc); theme.set_stylebox("grabber", "VScrollBar", scg)
	theme.set_stylebox("grabber_highlight", "VScrollBar", scg); theme.set_stylebox("grabber_pressed", "VScrollBar", scg)


# ───────────────────────── node helpers ─────────────────────────

var _root: Node


func _own(n: Node, unique := "") -> Node:
	if unique != "":
		n.name = unique
	if _root and n != _root:
		n.owner = _root
		if unique != "":
			n.unique_name_in_owner = true
	return n


func _add(parent: Node, n: Node, unique := "") -> Node:
	parent.add_child(n)
	if unique != "":
		n.name = unique
	_own(n, unique)
	return n


func _set_owner_rec(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		_set_owner_rec(c, owner)


func _label(text: String, s: LabelSettings) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = s
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _layer(name: String, layer: int, script_path: String) -> CanvasLayer:
	var c := CanvasLayer.new()
	c.name = name
	c.layer = layer
	if script_path != "":
		c.set_script(load(script_path))
	_root = c
	return c


func _full(parent: Node, name: String, filter := Control.MOUSE_FILTER_IGNORE) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = filter
	_add(parent, c, name)
	return c


func _save(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed: " + path)
	ResourceSaver.save(ps, path)
	root.free()


# ───────────────────────── scenes ─────────────────────────

func _seal(parent: Node, text: String, size: int, font_size: int, variation := "Seal") -> PanelContainer:
	var s := PanelContainer.new()
	s.theme_type_variation = variation
	s.custom_minimum_size = Vector2(size, size)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(parent, s)
	var l := _label(U.vertical(text), U.ls(U.brush(), font_size, Color("#fbeee2")))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.label_settings.line_spacing = -font_size * 0.18
	_add(s, l)
	return s


func _hotspot_tag() -> Node:
	var v := VBoxContainer.new()
	v.name = "HotspotTag"
	v.set_script(load("res://scripts/ui/hotspot_tag.gd"))
	v.add_theme_constant_override("separation", 3)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	_root = v
	var tag := PanelContainer.new(); tag.theme_type_variation = "SectTag"; tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; tag.mouse_filter = Control.MOUSE_FILTER_PASS
	_add(v, tag, "Tag")
	var s := U.ls(U.serif(700), 14, Color("#f4f6f8")); s.line_spacing = 1
	var l := _label("宗\n门", s); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(tag, l, "TagLabel")
	var pin := Panel.new(); pin.theme_type_variation = "Pin"; pin.custom_minimum_size = Vector2(9, 9); pin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; pin.mouse_filter = Control.MOUSE_FILTER_PASS
	_add(v, pin, "Pin")
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 8); gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(v, gap)
	var pr := PanelContainer.new(); pr.theme_type_variation = "PromptPill"; pr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(v, pr, "Prompt")
	_add(pr, _label("按 E 落脚", U.ls(U.spaced(U.serif(400), 12, 0.15), 12, Color("#f4fffb"))))
	return v


func _hud() -> Node:
	var c := _layer("Hud", 5, "res://scripts/ui/hud.gd")
	var root := _full(c, "HudRoot")
	var glow8 := U.SILK_HI
	# brand, top-left 16/16
	var brand := HBoxContainer.new(); brand.position = Vector2(16, 16); brand.add_theme_constant_override("separation", 10); brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, brand, "Brand")
	_seal(brand, "云梦", 40, 17)
	var bt := VBoxContainer.new(); bt.add_theme_constant_override("separation", 4); bt.alignment = BoxContainer.ALIGNMENT_CENTER; bt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(brand, bt)
	_add(bt, _label("云梦山", U.ls(U.brush(), 26, U.INK, glow8, 8)), "BrandTitle")
	_add(bt, _label("天南 › 溪国 · 西部灵脉", U.ls(U.spaced(U.serif(400), 12, 0.12), 12, U.INK_SOFT, glow8, 6)), "BrandSub")
	# banner, top 70 centred
	var ban := VBoxContainer.new(); ban.set_anchors_preset(Control.PRESET_CENTER_TOP); ban.offset_top = 70; ban.offset_left = -300; ban.offset_right = 300
	ban.alignment = BoxContainer.ALIGNMENT_BEGIN; ban.mouse_filter = Control.MOUSE_FILTER_IGNORE; ban.add_theme_constant_override("separation", 2)
	_add(root, ban, "Banner")
	var bn := _label("落云宗", U.ls(U.brush(), 44, U.INK, glow8, 14)); bn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(ban, bn, "BannerName")
	var bs := _label("云梦山 · 东脉", U.ls(U.spaced(U.serif(400), 13, 0.3), 13, U.INK_SOFT, glow8, 8)); bs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(ban, bs, "BannerSub")
	var rule := ColorRect.new(); rule.color = Color(U.CINNABAR, 0.8); rule.custom_minimum_size = Vector2(44, 2); rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rm := MarginContainer.new(); rm.add_theme_constant_override("margin_top", 8); rm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(ban, rm); _add(rm, rule, "BannerRule")
	# key hint, bottom-left
	var hint := PanelContainer.new(); hint.theme_type_variation = "HintPanel"; hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN; hint.offset_left = 16; hint.offset_bottom = -16; hint.offset_top = -16; hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, hint, "Hint")
	var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 4)
	_add(hint, grid)
	var rows := [[["W", "A", "S", "D"], "御光飞行"], [["Shift"], "疾遁加速"], [["Space", "/", "Q"], "升 / 降"], [["滚轮 · 拖动"], "升降 · 平移"],
		[["E"], "落脚（近宗门时）"], [["M"], "收图 / 御空"], [["`"], "调试面板"]]
	for r in rows:
		var keys := HBoxContainer.new(); keys.add_theme_constant_override("separation", 2)
		_add(grid, keys)
		for k in r[0]:
			if k == "/" or k == "滚轮 · 拖动":
				_add(keys, _label(k if k != "/" else " / ", U.ls(U.serif(400), 13, U.INK)))
			else:
				var kc := PanelContainer.new(); kc.theme_type_variation = "KeyCap"
				_add(keys, kc)
				_add(kc, _label(k, U.ls(U.serif(700), 12, U.INK)))
		_add(grid, _label(r[1], U.ls(U.serif(400), 13, U.INK)))
	# readout, bottom-right
	var ro := VBoxContainer.new(); ro.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); ro.grow_horizontal = Control.GROW_DIRECTION_BEGIN; ro.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ro.offset_right = -16; ro.offset_bottom = -16; ro.offset_left = -16; ro.offset_top = -16; ro.alignment = BoxContainer.ALIGNMENT_END; ro.mouse_filter = Control.MOUSE_FILTER_IGNORE; ro.add_theme_constant_override("separation", 0)
	_add(root, ro, "Readout")
	var arow := HBoxContainer.new(); arow.alignment = BoxContainer.ALIGNMENT_END; arow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(ro, arow)
	_add(arow, _label("—", U.ls(U.brush(), 18, U.INK, glow8, 6)), "Alt")
	_add(arow, _label(" 丈", U.ls(U.spaced(U.serif(400), 12, 0.08), 12, U.INK_SOFT, glow8, 6)), "AltBand")
	var spd := _label("遁速 0", U.ls(U.spaced(U.serif(400), 12, 0.08), 12, U.INK_SOFT, glow8, 6)); spd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add(ro, spd, "Spd")
	return c


func _hotspots() -> Node:
	var c := _layer("Hotspots", 4, "res://scripts/ui/hotspots.gd")
	_full(c, "HotRoot")
	return c


func _legend_button(parent: Node, text: String, icon: String, cat: String, unique := "") -> Button:
	var b := Button.new()
	b.theme_type_variation = "LegendButton"
	b.toggle_mode = true
	b.button_pressed = cat != ""
	b.text = (icon + "  " if icon != "" else "") + text
	if cat != "":
		b.set_meta("cat", cat)
	b.focus_mode = Control.FOCUS_NONE
	_add(parent, b, unique)
	return b


func _map_chrome() -> Node:
	var c := _layer("MapChrome", 10, "res://scripts/ui/map_chrome.gd")
	var root := _full(c, "MapRoot")
	_full(root, "Plate")
	_full(root, "Labels")
	_full(root, "Trail")
	# the player marker (遁光所在): a pulsing jade dot over a caption
	var me := VBoxContainer.new(); me.mouse_filter = Control.MOUSE_FILTER_IGNORE; me.add_theme_constant_override("separation", 4); me.set_script(load("res://scripts/ui/me_marker.gd"))
	_add(root.get_node("Labels"), me, "Me")
	var dot := Control.new(); dot.custom_minimum_size = Vector2(12, 12); dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(me, dot, "MeDot")
	_add(me, _label("遁光所在", U.ls(U.spaced(U.serif(400), 11, 0.2), 11, U.JADE_HI, Color("#0b1513"), 6, Color("#0b1513"), 3)))
	# title top centre
	var tt := VBoxContainer.new(); tt.set_anchors_preset(Control.PRESET_CENTER_TOP); tt.offset_top = 20; tt.offset_left = -250; tt.offset_right = 250; tt.mouse_filter = Control.MOUSE_FILTER_IGNORE; tt.add_theme_constant_override("separation", 0)
	_add(root, tt, "MTitle")
	var t1 := _label("溪国 · 云梦山舆图", U.ls(U.brush(), 30, U.CHROME_TEXT, Color(0.04, 0.08, 0.07, 0.9), 8)); t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(tt, t1)
	var t2 := _label("天南 · 天道盟", U.ls(U.spaced(U.serif(400), 12, 0.4), 12, U.CHROME_DIM, Color(0.04, 0.08, 0.07, 0.9), 6)); t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(tt, t2)
	# top-left: seal + search
	var top := HBoxContainer.new(); top.position = Vector2(16, 16); top.add_theme_constant_override("separation", 10); top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, top, "MTop")
	_seal(top, "人界", 46, 19, "Seal46")
	var sv := VBoxContainer.new(); sv.add_theme_constant_override("separation", 6); sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(top, sv)
	var search := PanelContainer.new(); search.theme_type_variation = "Chrome"; search.custom_minimum_size = Vector2(360, 46)
	_add(sv, search, "Search")
	var sm := MarginContainer.new(); sm.add_theme_constant_override("margin_left", 12); sm.add_theme_constant_override("margin_right", 12)
	_add(search, sm)
	var sh := HBoxContainer.new(); sh.add_theme_constant_override("separation", 8)
	_add(sm, sh)
	var mag := Control.new(); mag.custom_minimum_size = Vector2(18, 18); mag.size_flags_vertical = Control.SIZE_SHRINK_CENTER; mag.mouse_filter = Control.MOUSE_FILTER_IGNORE; mag.set_script(load("res://scripts/ui/magnifier.gd"))
	_add(sh, mag)
	var q := LineEdit.new(); q.theme_type_variation = "SearchEdit"; q.placeholder_text = "搜索地名，如 落云宗"; q.size_flags_horizontal = Control.SIZE_EXPAND_FILL; q.clear_button_enabled = false
	_add(sh, q, "Q")
	var kb := PanelContainer.new(); kb.add_theme_stylebox_override("panel", U.box(Color(0, 0, 0, 0), 4, 1, U.CHROME_LINE, Vector4(6, 1, 6, 1))); kb.size_flags_vertical = Control.SIZE_SHRINK_CENTER; kb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(sh, kb, "Kbd")
	_add(kb, _label("/", U.ls(U.serif(400), 12, U.CHROME_DIM)))
	var res := PanelContainer.new(); res.theme_type_variation = "ChromePad"; res.custom_minimum_size = Vector2(360, 0)
	_add(sv, res, "Results")
	var rl := VBoxContainer.new(); rl.add_theme_constant_override("separation", 2)
	_add(res, rl, "ResultList")
	# legend bottom-left
	var lg := HBoxContainer.new(); lg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); lg.grow_vertical = Control.GROW_DIRECTION_BEGIN; lg.offset_left = 16; lg.offset_bottom = -16; lg.offset_top = -16
	lg.add_theme_constant_override("separation", 10); lg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, lg, "MLegend")
	var g1 := PanelContainer.new(); g1.theme_type_variation = "ChromePad"
	_add(lg, g1)
	var g1h := HBoxContainer.new(); g1h.add_theme_constant_override("separation", 2)
	_add(g1, g1h)
	var bt := _legend_button(g1h, "韩立行迹", "⋰", "", "BtnTrail")
	bt.button_pressed = false; bt.modulate.a = 0.42
	var g2 := PanelContainer.new(); g2.theme_type_variation = "ChromePad"
	_add(lg, g2)
	var g2h := HBoxContainer.new(); g2h.add_theme_constant_override("separation", 2)
	_add(g2, g2h, "LegendButtons")
	for e in [["宗门", "▮", "sect"], ["城池", "◆", "city"], ["秘境", "✦", "secret"], ["山川", "△", "mount"], ["势力", "◩", "force"]]:
		_legend_button(g2h, e[0], e[1], e[2])
	# zoom bottom-right
	var zp := PanelContainer.new(); zp.theme_type_variation = "ChromePad"; zp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); zp.grow_horizontal = Control.GROW_DIRECTION_BEGIN; zp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	zp.offset_right = -16; zp.offset_bottom = -16; zp.offset_left = -16; zp.offset_top = -16
	_add(root, zp, "MZoom")
	var zv := VBoxContainer.new(); zv.add_theme_constant_override("separation", 2)
	_add(zp, zv)
	for z in [["+", "ZIn", 20], ["−", "ZOut", 20], ["⌂", "ZHome", 15]]:
		var b := Button.new(); b.theme_type_variation = "ZoomButton"; b.text = z[0]; b.custom_minimum_size = Vector2(40, 40); b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", z[2])
		_add(zv, b, z[1])
	# 舆图展开中 (its own layer, 12)
	var ul := CanvasLayer.new(); ul.layer = 12
	_add(c, ul, "UnrollLayer")
	var un := _label("舆图展开中", U.ls(U.spaced(U.brush(), 22, 0.5), 22, U.CHROME_TEXT, Color(0.04, 0.08, 0.07, 0.9), 12))
	un.set_anchors_preset(Control.PRESET_CENTER); un.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; un.grow_horizontal = Control.GROW_DIRECTION_BOTH; un.grow_vertical = Control.GROW_DIRECTION_BOTH
	_add(ul, un, "Unroll")
	return c


func _info_card() -> Node:
	var c := _layer("InfoCard", 22, "res://scripts/ui/info_card.gd")
	var card := PanelContainer.new(); card.theme_type_variation = "Chrome"; card.size = Vector2(420, 700); card.position = Vector2(1004, 78)
	_add(c, card, "Card")
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0)
	_add(card, v)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_add(v, sc, "Scroll")
	var m := MarginContainer.new(); m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", 24); m.add_theme_constant_override("margin_right", 24); m.add_theme_constant_override("margin_top", 22); m.add_theme_constant_override("margin_bottom", 12)
	_add(sc, m)
	var body := VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 0)
	_add(m, body, "Body")
	var foot := PanelContainer.new(); foot.theme_type_variation = "CardFooter"
	_add(v, foot)
	var fh := HBoxContainer.new(); fh.add_theme_constant_override("separation", 10)
	_add(foot, fh)
	var go := Button.new(); go.theme_type_variation = "GoButton"; go.text = "御空前往"
	_add(fh, go, "Go")
	var cp := Button.new(); cp.theme_type_variation = "FooterButton"; cp.text = "复制地名"
	_add(fh, cp, "Copy")
	# the × sits over the panel's top-right corner
	var close := Button.new(); close.theme_type_variation = "CloseButton"; close.text = "×"; close.custom_minimum_size = Vector2(32, 32)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END; close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; close.focus_mode = Control.FOCUS_NONE
	var cm := MarginContainer.new(); cm.add_theme_constant_override("margin_top", 14); cm.add_theme_constant_override("margin_right", 14); cm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cm.size_flags_horizontal = Control.SIZE_SHRINK_END; cm.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_add(card, cm)
	_add(cm, close, "Close")
	return c


func _intro() -> Node:
	var c := _layer("Intro", 15, "res://scripts/ui/intro_ui.gd")
	var root := _full(c, "IntroRoot")
	var t := HBoxContainer.new(); t.add_theme_constant_override("separation", 18); t.mouse_filter = Control.MOUSE_FILTER_IGNORE; t.position = Vector2(172, 81)
	_add(root, t, "Title")
	var sw := VBoxContainer.new(); sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(t, sw)
	var sm := MarginContainer.new(); sm.add_theme_constant_override("margin_top", 6); sm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(sw, sm)
	_seal(sm, "人界", 34, 14)
	var big := U.ls(U.brush(), 88, U.INK, U.SILK_HI, 18); big.line_spacing = 88 * 0.18 - 14
	_add(t, _label(U.vertical("云梦山"), big), "TitleText")
	var sub_w := VBoxContainer.new(); sub_w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(t, sub_w)
	var sub_m := MarginContainer.new(); sub_m.add_theme_constant_override("margin_top", 18); sub_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(sub_w, sub_m)
	var small := U.ls(U.serif(400), 15, U.INK_SOFT, U.SILK_HI, 10); small.line_spacing = 15 * 0.42 - 4
	_add(sub_m, _label(U.vertical("凡人修仙传·溪国西部灵脉"), small))
	var sk := CanvasLayer.new(); sk.layer = 16
	_add(c, sk, "SkipLayer")
	var skip := _label("点击或按任意键跳过", U.ls(U.spaced(U.serif(400), 12, 0.3), 12, U.INK_SOFT, U.SILK_HI, 8))
	skip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); skip.grow_horizontal = Control.GROW_DIRECTION_BOTH; skip.grow_vertical = Control.GROW_DIRECTION_BEGIN; skip.offset_bottom = -20
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(sk, skip, "Skip")
	return c


func _mode_switch() -> Node:
	var c := _layer("ModeSwitch", 20, "res://scripts/ui/mode_switch.gd")
	var p := PanelContainer.new(); p.theme_type_variation = "ChromePad"; p.set_anchors_preset(Control.PRESET_TOP_RIGHT); p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -16; p.offset_top = 16; p.offset_left = -16
	var shadow: StyleBoxFlat = theme.get_stylebox("panel", "ChromePad").duplicate(); shadow.shadow_size = 10; shadow.shadow_offset = Vector2(0, 6); shadow.shadow_color = Color(0, 0, 0, 0.25)
	p.add_theme_stylebox_override("panel", shadow)
	_add(c, p, "Switch")
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 2)
	_add(p, h)
	var f := Button.new(); f.theme_type_variation = "ModeSegOn"; f.text = "御空"; f.focus_mode = Control.FOCUS_NONE
	_add(h, f, "SegFly")
	var m := Button.new(); m.theme_type_variation = "ModeSeg"; m.text = "收图"; m.focus_mode = Control.FOCUS_NONE
	_add(h, m, "SegMap")
	return c


func _debug() -> Node:
	var c := _layer("Debug", 25, "res://scripts/ui/debug_panel.gd")
	var p := PanelContainer.new(); p.theme_type_variation = "Chrome"; p.position = Vector2(16, 78); p.custom_minimum_size = Vector2(330, 0); p.size = Vector2(330, 760)
	_add(c, p, "DebugRoot")
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0)
	_add(p, v)
	var head := PanelContainer.new(); head.theme_type_variation = "DebugHeader"
	_add(v, head)
	var hh := HBoxContainer.new()
	_add(head, hh)
	var ht := _label("调试面板", U.ls(U.spaced(U.brush(), 20, 0.1), 20, U.CHROME_TEXT)); ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add(hh, ht)
	var rb := Button.new(); rb.theme_type_variation = "SmallButton"; rb.text = "恢复默认"
	_add(hh, rb, "Reset")
	var xb := Button.new(); xb.theme_type_variation = "SmallButton"; xb.text = "×"
	_add(hh, xb, "CloseDbg")
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(0, 560); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_add(v, sc)
	var m := MarginContainer.new(); m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["margin_left", "margin_right"]: m.add_theme_constant_override(k, 14)
	m.add_theme_constant_override("margin_top", 8); m.add_theme_constant_override("margin_bottom", 4)
	_add(sc, m)
	var inner := VBoxContainer.new(); inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL; inner.add_theme_constant_override("separation", 5)
	_add(m, inner)
	var rows := VBoxContainer.new(); rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation", 5)
	_add(inner, rows, "Rows")
	_add(inner, _label("工具", U.ls(U.spaced(U.serif(400), 11, 0.3), 11, U.CHROME_DIM)))
	var tools := HBoxContainer.new(); tools.add_theme_constant_override("separation", 6)
	_add(inner, tools)
	for b in [["导出参数", "Export"], ["复制", "CopyOut"]]:
		var bb := Button.new(); bb.theme_type_variation = "SmallButton"; bb.text = b[0]
		_add(tools, bb, b[1])
	var out := TextEdit.new(); out.custom_minimum_size = Vector2(0, 96); out.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_add(inner, out, "Out")
	var st := _label("", U.ls(U.serif(400), 11, U.CHROME_DIM)); st.label_settings.line_spacing = 4
	_add(inner, st, "Stats")
	return c


func _toast() -> Node:
	var c := _layer("Toast", 30, "res://scripts/ui/toast.gd")
	var p := PanelContainer.new(); p.theme_type_variation = "ToastPanel"; p.mouse_filter = Control.MOUSE_FILTER_IGNORE; p.position = Vector2(600, 10)
	_add(c, p, "ToastPanel")
	_add(p, _label("", U.ls(U.spaced(U.serif(400), 13, 0.06), 13, U.CHROME_TEXT)), "ToastLabel")
	return c


func _loading() -> Node:
	var c := _layer("Loading", 31, "res://scripts/ui/loading.gd")
	var h := HBoxContainer.new(); h.set_anchors_preset(Control.PRESET_TOP_RIGHT); h.grow_horizontal = Control.GROW_DIRECTION_BEGIN; h.offset_right = -16; h.offset_top = 70; h.offset_left = -16
	h.add_theme_constant_override("separation", 8); h.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.alignment = BoxContainer.ALIGNMENT_END
	_add(c, h, "LoadingRoot")
	var sp := Control.new(); sp.custom_minimum_size = Vector2(14, 14); sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER; sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(h, sp, "Spinner")
	_add(h, _label("展卷中", U.ls(U.spaced(U.serif(400), 12, 0.2), 12, U.INK_SOFT, U.SILK_HI, 6)), "LoadingLabel")
	return c


func _touch() -> Node:
	var c := _layer("Touch", 6, "res://scripts/ui/touch.gd")
	var pad := Panel.new(); pad.theme_type_variation = "PadPanel"; pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pad.offset_left = 26; pad.offset_bottom = -26; pad.offset_top = -26 - 116; pad.offset_right = 26 + 116
	_add(c, pad, "Pad")
	var knob := Panel.new(); knob.theme_type_variation = "KnobPanel"; knob.size = Vector2(46, 46); knob.position = Vector2(35, 35); knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(pad, knob, "Knob")
	var b := Button.new(); b.theme_type_variation = "BoostButton"; b.text = "疾"; b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_right = -26; b.offset_bottom = -64; b.offset_left = -26 - 70; b.offset_top = -64 - 70
	_add(c, b, "Boost")
	return c


func _main() -> Node:
	var m := Node3D.new()
	m.name = "Main"
	m.set_script(load("res://scripts/main.gd"))
	_root = m
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#dcddd6")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	_add(m, env, "WorldEnvironment")
	var cam := Camera3D.new(); cam.fov = 40; cam.near = 5; cam.far = 200000; cam.current = true
	_add(m, cam, "Camera3D")
	var ink := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	ink.mesh = q
	var im := ShaderMaterial.new(); im.shader = load("res://shaders/post_ink.gdshader"); im.render_priority = -100
	ink.material_override = im
	ink.extra_cull_margin = 16384
	ink.position = Vector3(0, 0, -10)
	_add(cam, ink, "InkEdge")
	ink.unique_name_in_owner = false
	var dir := Node.new(); dir.set_script(load("res://scripts/director.gd"))
	_add(m, dir, "Director")
	dir.set("camera_path", NodePath("../Camera3D"))
	dir.set("light_path", NodePath("../World/Light"))
	var sb := Node.new(); sb.set_script(load("res://scripts/world/sun_bake.gd"))
	_add(m, sb, "SunBake")
	var w := Node3D.new()
	_add(m, w, "World")
	for spec in [["Terrain", Node3D, "res://scripts/world/terrain.gd"], ["Water", MeshInstance3D, ""], ["Props", Node3D, "res://scripts/world/props.gd"],
			["Trees", Node3D, "res://scripts/world/trees.gd"], ["CloudSea", MeshInstance3D, "res://scripts/world/cloud_sea.gd"],
			["MapPlane", MeshInstance3D, "res://scripts/world/map_plane.gd"], ["Light", Node3D, "res://scripts/world/light_trail.gd"]]:
		var n: Node = spec[1].new()
		if spec[2] != "":
			n.set_script(load(spec[2]))
		_add(w, n, spec[0])
	var post := CanvasLayer.new(); post.layer = 1
	_add(m, post, "Post")
	var scr := ColorRect.new(); scr.set_anchors_preset(Control.PRESET_FULL_RECT); scr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new(); pm.shader = load("res://shaders/post_screen.gdshader")
	scr.material = pm
	_add(post, scr, "Screen")
	var shots := Node.new(); shots.set_script(load("res://scripts/shots.gd"))
	_add(m, shots, "Shots")
	shots.unique_name_in_owner = false
	for s in ["hotspots", "hud", "touch", "map_chrome", "intro", "mode_switch", "info_card", "debug_panel", "toast", "loading"]:
		var inst: Node = load("res://ui/%s.tscn" % s).instantiate()
		m.add_child(inst)
		inst.owner = m
	# unique names only matter inside each scene; keep the main scene's paths plain
	for n in [cam, dir, sb, w, post, scr, env]:
		n.unique_name_in_owner = false
	return m
