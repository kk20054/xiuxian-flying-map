extends CanvasLayer
## 调试面板 (demo §13, DEBUG L14620–14830): ` toggles it. Rows are built from DEFS (key, label, min, max, step, unit),
## each writing Cfg; the world systems listen to Cfg.changed. "恢复默认" restores the exported CONFIG, "导出参数" dumps
## it as JSON; the stats line shows fps, draw calls and where you are.

const DEFS := [
	["飞行", [["flight.speed", "飞行速度", 0.05, 0.4, 0.005, "×高"], ["flight.boostMul", "疾遁倍数", 1.2, 5.0, 0.1, "×"], ["flight.accel", "起步惯性", 0.05, 2.0, 0.05, "秒"],
		["flight.glide", "滑翔距离", 0.1, 4.0, 0.05, "秒"], ["flight.fling", "拖动甩出", 0.0, 1.5, 0.05, ""], ["flight.lightHeight", "离地高度", 0.05, 0.5, 0.01, "×高"], ["flight.bob", "上下浮动", 0.0, 3.0, 0.1, ""]]],
	["镜头与缩放", [["camera.lookAhead", "超前看", 0.0, 2.0, 0.05, "秒"], ["camera.follow", "跟随缓动", 0.02, 1.5, 0.02, "秒"], ["camera.boostPull", "疾遁拉远", 0.0, 0.4, 0.01, ""],
		["camera.fov", "视场角", 20, 70, 1, "°"], ["camera.pitchLow", "低空俯角", 25, 70, 1, "°"], ["camera.pitchMid", "中空俯角", 25, 75, 1, "°"], ["camera.pitchHigh", "高空俯角", 30, 85, 1, "°"],
		["camera.pitchTop", "最高处俯角", 30, 89, 1, "°"], ["zoom.low", "低空高度", 400, 1600, 10, "丈"], ["zoom.mid", "中空高度", 800, 3000, 10, "丈"], ["zoom.high", "高空高度", 3000, 11000, 50, "丈"],
		["zoom.mapAt", "收图高度", 6000, 16000, 100, "丈"], ["zoom.keyRate", "升降速度", 0.2, 2.5, 0.05, ""], ["zoom.ease", "升降缓动", 0.02, 1.0, 0.02, "秒"]]],
	["山与水", [["terrain.relief", "山高倍数", 0.3, 2.0, 0.05, "×"], ["terrain.soft", "山体柔和", 0.0, 1.0, 0.05, ""], ["terrain.cun", "顺坡皴笔", 0.0, 2.0, 0.05, ""],
		["terrain.creaseInk", "皴线墨色", 0.0, 1.5, 0.05, ""], ["terrain.footInk", "山脚墨线", 0.0, 1.5, 0.05, ""], ["water.ripples", "墨线水纹", 0.0, 2.0, 0.05, ""],
		["water.waves", "波浪", 0.0, 3.0, 0.05, ""], ["water.seaMotion", "海面动态", 0.2, 4.0, 0.1, ""], ["water.steps", "水色色阶", 1, 8, 1, ""],
		["trees.density", "树木疏密", 0.0, 1.5, 0.05, ""], ["trees.size", "树木大小", 0.4, 2.5, 0.05, "×"], ["trees.sway", "树随风动", 0.0, 2.5, 0.05, ""]]],
	["日照", [["sun.azimuth", "太阳方位", 90, 330, 1, "°"], ["sun.elevation", "太阳高度", 15, 70, 1, "°"], ["sun.shadow", "山影浓淡", 0.0, 1.0, 0.05, ""], ["sun.contrast", "明暗反差", 0.0, 1.6, 0.05, ""]]],
	["云海", [["cloudSea.amount", "云海浓淡", 0.0, 1.2, 0.05, ""], ["cloudSea.height", "云顶高度", 80, 320, 5, "丈"], ["cloudSea.billow", "云涛起伏", 0.0, 2.0, 0.05, ""],
		["cloudSea.thick", "云层厚度", 60, 300, 5, "丈"], ["cloudSea.density", "云的密度", 0.3, 3.0, 0.05, ""], ["cloudSea.steps", "体积步进", 4, 20, 1, ""]]],
	["遁光", [["light.size", "光的大小", 0.3, 3.0, 0.05, "×"], ["light.tail", "拖尾长短", 0.2, 3.0, 0.05, "×"], ["light.intensity", "亮度", 0.2, 1.6, 0.05, ""], ["light.breath", "呼吸", 0.0, 0.3, 0.01, ""]]],
	["画面", [["look.tiltShift", "移轴", 0.0, 2.5, 0.05, ""], ["look.focusBand", "清晰带", 0.0, 0.4, 0.01, ""], ["look.paper", "绢纹", 0.0, 0.8, 0.01, ""],
		["look.vignette", "暗角", 0.0, 1.0, 0.01, ""], ["look.haze", "远景雾", 0.0, 1.5, 0.05, ""], ["look.edgeInk", "勾边墨线", 0.0, 1.5, 0.05, ""],
		["cinema.grade", "调色", 0.0, 1.5, 0.05, ""], ["cinema.warmth", "暖调", 0.0, 1.0, 0.05, ""], ["cinema.valleyMist", "谷中雾", 0.0, 1.5, 0.05, ""], ["cinema.vignette", "调色暗角", 0.0, 1.0, 0.05, ""]]],
]

@onready var panel: Control = %DebugRoot
@onready var rows_box: VBoxContainer = %Rows
@onready var out: TextEdit = %Out
@onready var stats: Label = %Stats
var rows := []
var _st := 0.0


func _ready() -> void:
	panel.visible = false
	%Reset.pressed.connect(_reset)
	%CloseDbg.pressed.connect(func(): _toggle(false))
	%Export.pressed.connect(func(): out.text = JSON.stringify(Cfg.data, "  "))
	%CopyOut.pressed.connect(func(): DisplayServer.clipboard_set(out.text))
	get_viewport().size_changed.connect(_fit)
	_fit()
	for g in DEFS:
		var gt := Label.new()
		gt.text = g[0]
		gt.label_settings = UIUtil.ls(UIUtil.spaced(UIUtil.serif(400), 11, 0.3), 11, UIUtil.CHROME_DIM)
		rows_box.add_child(gt)
		for d in g[1]:
			rows_box.add_child(_row(d))


func _row(d: Array) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var name := Label.new()
	name.text = d[1]
	name.custom_minimum_size.x = 84
	name.label_settings = UIUtil.ls(UIUtil.serif(400), 13, Color("#d9d4c6"))
	var sl := HSlider.new()
	sl.min_value = d[2]; sl.max_value = d[3]; sl.step = d[4]
	sl.value = Cfg.f(d[0], d[2])
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := Label.new()
	val.custom_minimum_size.x = 60
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.label_settings = UIUtil.ls(UIUtil.serif(400), 12, UIUtil.JADE_HI)
	h.add_child(name); h.add_child(sl); h.add_child(val)
	var row := {"d": d, "slider": sl, "val": val}
	rows.append(row)
	_show(row)
	sl.value_changed.connect(_changed.bind(row))
	return h


func _changed(v: float, row: Dictionary) -> void:
	Cfg.s(row.d[0], v)
	_show(row)


func _show(row: Dictionary) -> void:
	var v: float = row.slider.value
	var d: Array = row.d
	row.val.text = ("%d" % v if d[4] >= 1 else ("%.3f" % v if d[4] < 0.01 else "%.2f" % v)) + " " + d[5]


func _reset() -> void:
	Cfg.reset()
	for r in rows:                         # per key, so every system that listens re-applies its default
		var v := Cfg.f(r.d[0], r.d[2])
		r.slider.set_value_no_signal(v)
		Cfg.s(r.d[0], Cfg.g(r.d[0], v))
		_show(r)


## max-height: calc(100vh − 110px) (CSS L151)
func _fit() -> void:
	panel.size.y = minf(760.0, panel.get_viewport_rect().size.y - 110.0)


func _toggle(on: bool) -> void:
	panel.visible = on
	Game.debug_open = on


func _input(ev: InputEvent) -> void:
	if ev.is_action_pressed("toggle_debug"):
		_toggle(not panel.visible)
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if not panel.visible:
		return
	_st -= dt
	if _st > 0.0:
		return
	_st = 0.5
	var d := UIUtil.director()
	if d == null:
		return
	var L: Dictionary = World.meta.get("layout", {"origin": [0, 0], "k": 1.0})
	var bx: float = d.pos.x / float(L.k) + float(L.origin[0]); var by: float = d.pos.z / float(L.k) + float(L.origin[1])
	stats.text = "%d 帧 · 绘制 %d 次 · %dk 面\n位置 世界 %d, %d · 底图像素 %d, %d\n高度 %d 丈 · 俯角 %.1f°" % [
		Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		d.pos.x, d.pos.z, bx, by, d.A, d.pitch_of(d.a_eff)]
