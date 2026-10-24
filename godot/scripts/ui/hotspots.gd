extends CanvasLayer
## Flight hotspots (demo #hot, buildHotspots L14267, updateHotspots L14281): vertical tags over the sects and the
## named landmarks, shown at low and middle altitude, lit when the 遁光 is within 700 丈; E or a click opens the card.

const TAG := preload("res://ui/hotspot_tag.tscn")

@onready var root: Control = %HotRoot
var tags: Array = []


func _ready() -> void:
	World.ready_world.connect(_build)
	if World.loaded:
		_build()


func _build() -> void:
	for p in World.places:
		if not p.get("hotspot", false):
			continue
		var t: Control = TAG.instantiate()
		root.add_child(t)
		t.setup(p, p.cat != "sect", true)
		t.pressed.connect(_on_pressed)
		tags.append(t)


func _on_pressed(p: Dictionary) -> void:
	if Game.mode == Game.Mode.FLIGHT:
		UIUtil.director().open_card_in_flight(p)       # brakes like E (openCard L14438)


func _process(_dt: float) -> void:
	var d := UIUtil.director()
	if d == null or tags.is_empty():
		return
	var cam: Camera3D = d.cam
	var max_alt := Cfg.f("hotspot.labelMaxAlt", 4200)
	var show := 1.0 - smoothstep(0.85 * max_alt, max_alt, d.A) if Game.mode == Game.Mode.FLIGHT else 0.0
	root.modulate.a = lerpf(root.modulate.a, show, 0.2)
	root.visible = root.modulate.a > 0.02
	# the nearest hotspot within the radius
	var near = null
	var nd := Cfg.f("hotspot.radius", 700)
	for t in tags:
		var p: Dictionary = t.place
		var dist := Vector2(d.pos.x - p.x, d.pos.z - p.z).length()
		if dist < nd:
			nd = dist; near = p
	if near != Game.near:
		Game.near = near
		Game.near_changed.emit(near)
	# a card opened in flight closes when you fly away from it
	if Game.selected != null and Game.card_from_flight:
		var cp: Dictionary = Game.selected
		if Vector2(d.pos.x - cp.x, d.pos.z - cp.z).length() > 2.4 * Cfg.f("hotspot.radius", 700):
			Game.close_card()
	if not root.visible:
		return
	var vp := root.get_viewport_rect().size
	for t in tags:
		var p: Dictionary = t.place
		var w := Vector3(p.x, float(p.get("labelY", 60.0)) * (1.0 - Game.map_k), p.z)
		if cam.is_position_behind(w):
			t.visible = false
			continue
		var s := cam.unproject_position(w)
		t.visible = s.x > -80 and s.x < vp.x + 80 and s.y > -120 and s.y < vp.y + 60
		t.set_near(p == near)
		t.position = s - t.anchor_offset()
