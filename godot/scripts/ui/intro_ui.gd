extends CanvasLayer
## The opening title (demo #intro / #skip, L50–55; updateIntro L14140): a vertical 云梦山 in brush with its seal and
## subtitle, fading in at 0.15 s and out at 3.3 s (CSS 1.2 s transition); "点击或按任意键跳过" under it.

@onready var title: Control = %Title
@onready var skip: Label = %Skip
@onready var holder: Control = %IntroRoot


func _ready() -> void:
	title.modulate.a = 0.0
	get_viewport().size_changed.connect(_layout)
	_layout()


## padding max(9vh, 64px) 0 0 max(12vw, 24px); centred with 96 px on top under 640 px.
func _layout() -> void:
	var vp := holder.get_viewport_rect().size
	await get_tree().process_frame
	if vp.x <= 640.0:
		title.position = Vector2((vp.x - title.size.x) * 0.5, 96.0)
	else:
		title.position = Vector2(maxf(vp.x * 0.12, 24.0), maxf(vp.y * 0.09, 64.0))


func _process(dt: float) -> void:
	var d := UIUtil.director()
	var t: float = d.t if d else 0.0
	var title_r: Array = Cfg.g("intro.title", [0.15, 3.3])
	var want := 0.0
	if Game.mode == Game.Mode.LOADING:
		want = 1.0
	elif Game.mode == Game.Mode.INTRO:
		want = 1.0 if (t > title_r[0] and t < title_r[1]) else 0.0
	title.modulate.a = move_toward(title.modulate.a, want, dt / 1.2)
	skip.modulate.a = 0.85 if Game.mode == Game.Mode.INTRO else move_toward(skip.modulate.a, 0.0, dt * 4.0)
	holder.visible = title.modulate.a > 0.005 or skip.modulate.a > 0.005
