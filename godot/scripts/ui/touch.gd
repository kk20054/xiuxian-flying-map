extends CanvasLayer
## Touch controls (demo #pad / #boostBtn L139–141, input L14561): a 116-px stick bottom left (knob travel 46 px)
## and a 70-px 疾 button bottom right; shown only on touch screens (CSS pointer:coarse).

@onready var pad: Control = %Pad
@onready var knob: Control = %Knob
@onready var boost: Button = %Boost
var touch_id := -1


func _ready() -> void:
	var on := DisplayServer.is_touchscreen_available()
	pad.visible = on
	boost.visible = on
	pad.gui_input.connect(_pad_input)
	boost.button_down.connect(func(): _d().touch.boost = true)
	boost.button_up.connect(func(): _d().touch.boost = false)
	_centre()


func _d() -> Node:
	return UIUtil.director()


func _centre() -> void:
	knob.position = (pad.size - knob.size) * 0.5


func _pad_input(e: InputEvent) -> void:
	var d := _d()
	if d == null:
		return
	if e is InputEventScreenTouch:
		if e.pressed and touch_id == -1:
			touch_id = e.index
			if Game.mode == Game.Mode.INTRO:
				d.skip_intro()
			_move(e.position)
		elif not e.pressed and e.index == touch_id:
			touch_id = -1
			d.touch.mx = 0.0; d.touch.mz = 0.0
			_centre()
	elif e is InputEventScreenDrag and e.index == touch_id:
		_move(e.position)


func _move(p: Vector2) -> void:
	var v: Vector2 = (p - pad.size * 0.5).limit_length(46.0)
	knob.position = pad.size * 0.5 + v - knob.size * 0.5
	var d := _d()
	d.touch.mx = v.x / 46.0
	d.touch.mz = -v.y / 46.0
