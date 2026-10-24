extends Node
## The camera and the modes (demo §12, L14078–14611): intro → flight ⇄ 舆图. One scene, one camera: the map is the same world
## flattened by map_k while the camera rises, pitches straight down and narrows its field of view.
##
## Flight (L14181–14236): W is always north, the camera never turns; altitude doubles as zoom (speed ∝ altitude, so the
## ground's speed on screen stays the same). Every smoothing is frame-rate independent: x = lerp(x, target, 1 − e^(−dt/τ)).

signal flew_to(place: Dictionary)

@export var camera_path: NodePath
@export var light_path: NodePath

var cam: Camera3D
var light: Node                     # LightTrail (遁光), optional

# player (the ground point under the light) — PLAYER in the demo
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var A := 1650.0                     # altitude (smoothed); also the zoom
var At := 1650.0                    # altitude target
var boost_k := 0.0
var dun_k := 0.0
var flare := 0.0
var last_boost := false
var boosting := false
var clear := 0.0                    # smoothed ground clearance under the light
var map_cooldown := 0.0
var light_p := Vector3.ZERO

# camera rig
var rig_target := Vector3.ZERO
var a_eff := 1650.0

# 舆图
var map_cx := 0.0
var map_cz := 0.0
var map_view := 36000.0
var map_goal = null                 # {cx, cz, view} or null
var map_home := {}

# transitions
var t := 0.0                        # intro clock
var skipping := false
var trans := 0.0
var trans_dur := 2.4
var trans_to := Game.Mode.MAP
var from_xf := Transform3D()
var from_fov := 40.0

# input
var drag := {}                      # flight: {grab, last, v}; map: {last}
var touch := {"mx": 0.0, "mz": 0.0, "boost": false}
var touches := {}                  # touch index → screen position (for the pinch)
var pinch_d := 0.0
var keys_down := {}

const MAPQ := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))   # looking straight down, north up (L14094)


func _ready() -> void:
	add_to_group("director")              # before the UI scenes' _ready (they are later siblings) look it up
	cam = get_node(camera_path)
	if light_path:
		light = get_node_or_null(light_path)
	process_priority = -10


func setup() -> void:
	# start where the demo starts (L14590): 450 丈 west and 1450 south of 落云宗, high, then the intro descends
	pos = Vector3(World.start_pos.x, 0, World.start_pos.y)
	clear = World.ground_clear(pos.x, pos.z)
	A = Cfg.f("intro.startAlt", 2700); At = A
	rig_target = pos; a_eff = A
	# MAP_HOME (L4089): from 天柱山 to 倪航斋, centred a little north
	var x0: float = World.by_id.tianzhu.x - 2500.0 if World.by_id.has("tianzhu") else World.rect.position.x
	var x1: float = World.by_id.nihang.x + 4500.0 if World.by_id.has("nihang") else World.rect.end.x
	map_home = {"cx": (x0 + x1) / 2.0, "cz": -14000.0, "view": maxf(7000.0, (x1 - x0) / 2.0 / 1.7)}
	map_cx = map_home.cx; map_cz = map_home.cz; map_view = map_home.view
	_apply(flight_pose(rig_target, a_eff))
	t = 0.0
	Game.mode = Game.Mode.INTRO
	if "--skip-intro" in OS.get_cmdline_user_args():
		t = Cfg.f("intro.duration", 4.6) - 0.3


# ───────────────────────── poses ─────────────────────────

func pitch_of(a: float) -> float:
	var la := log(maxf(a, 1.0))
	var lo := Cfg.f("zoom.low", 950); var mid := Cfg.f("zoom.mid", 1650); var hi := Cfg.f("zoom.high", 8000); var top := Cfg.f("zoom.mapAt", 11000)
	if a <= mid:
		return lerpf(Cfg.f("camera.pitchLow", 38), Cfg.f("camera.pitchMid", 45), smoothstep(log(lo), log(mid), la))
	if a <= hi:
		return lerpf(Cfg.f("camera.pitchMid", 45), Cfg.f("camera.pitchHigh", 54), smoothstep(log(mid), log(hi), la))
	return lerpf(Cfg.f("camera.pitchHigh", 54), Cfg.f("camera.pitchTop", 60), smoothstep(log(hi), log(top), la))


## The flight pose (L14107): south of the target, pitched down, never yawed; frames a point lead·A north of the target.
func flight_pose(target: Vector3, a: float) -> Transform3D:
	var p := deg_to_rad(pitch_of(a))
	var o := Vector3(target.x, a, target.z - Cfg.f("camera.lead", 0.1) * a + a / tan(p))
	return Transform3D(Basis.from_euler(Vector3(-p, 0, 0)), o)


## The 舆图 pose (L14114): straight down; map_view = half the shorter screen side in 丈.
func map_pose() -> Transform3D:
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var h := map_view / (tan(deg_to_rad(Cfg.f("map.fov", 20)) * 0.5) * minf(1.0, aspect))
	return Transform3D(MAPQ, Vector3(map_cx, h, map_cz))


func _apply(xf: Transform3D) -> void:
	cam.global_transform = xf


# ───────────────────────── the frame ─────────────────────────

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	match Game.mode:
		Game.Mode.INTRO:
			_update_intro(dt)
		Game.Mode.FLIGHT:
			_update_flight(dt)
		Game.Mode.TO_MAP, Game.Mode.TO_FLIGHT:
			_update_transition(dt)
		Game.Mode.MAP:
			_update_map(dt)
	# near/far planes follow the camera height (L14940)
	cam.near = maxf(5.0, cam.global_position.y * 0.05)
	cam.far = cam.global_position.y * 40.0 + 30000.0
	var alt := a_eff if Game.mode in [Game.Mode.FLIGHT, Game.Mode.INTRO] else maxf(a_eff, cam.global_position.y * 0.8)
	RenderingServer.global_shader_parameter_set("alt_k", smoothstep(Cfg.f("zoom.mid", 1650), Cfg.f("zoom.high", 8000), alt))
	RenderingServer.global_shader_parameter_set("cine_k", Cfg.f("cinema.warmth", 0.6) * smoothstep(Cfg.f("zoom.mid", 1650), Cfg.f("zoom.high", 8000), alt))


func current_alt() -> float:
	return a_eff if Game.mode in [Game.Mode.FLIGHT, Game.Mode.INTRO] else maxf(a_eff, cam.global_position.y * 0.8)


# ── intro: ink lines → wash → clouds → the light flies in (L14140–14178) ──
func _update_intro(dt: float) -> void:
	t += dt * (4.0 if skipping else 1.0)
	var dur := Cfg.f("intro.duration", 4.6)
	var ink: Array = Cfg.g("intro.ink", [0.05, 1.35]); var wash: Array = Cfg.g("intro.wash", [1.0, 3.05])
	var clouds: Array = Cfg.g("intro.clouds", [2.7, 3.8]); var li_r: Array = Cfg.g("intro.lightIn", [3.35, 4.55])
	Game.set_reveal(smoothstep(ink[0], ink[1], t), smoothstep(wash[0], wash[1], t), smoothstep(clouds[0], clouds[1], t))
	var k := _ease_in_out(clampf(t / dur, 0.0, 1.0))
	A = exp(lerpf(log(Cfg.f("intro.startAlt", 2700)), log(Cfg.f("zoom.mid", 1650)), k)); At = A; a_eff = A
	rig_target = Vector3(pos.x, 0, pos.z - 0.25 * A * (1.0 - k))
	_apply(flight_pose(rig_target, a_eff))
	var li := smoothstep(li_r[0], li_r[1], t)
	var to := _light_pos(Time.get_ticks_msec() / 1000.0)
	var from := pos + Vector3(-1.3 * A, Cfg.f("flight.lightHeight", 0.24) * A * 1.8, 0.9 * A)
	var e := _ease_out(li)
	light_p = from.lerp(to, e); light_p.y += sin(e * PI) * 0.12 * A
	var v := (to - from) * 1.2 * (1.0 - e) if li < 1.0 else Vector3.ZERO
	if light:
		light.update_light(dt, light_p, Vector3(v.x, 0, v.z), cam, A, false, smoothstep(0.0, 0.15, li))   # fully lit after 15 % of the arc (L14166)
	if t >= dur:
		finish_intro()


func finish_intro() -> void:
	Game.set_reveal(1.0, 1.0, 1.0)
	A = Cfg.f("zoom.mid", 1650); At = A; a_eff = A; rig_target = pos
	_apply(flight_pose(rig_target, a_eff))
	Game.mode = Game.Mode.FLIGHT


func skip_intro() -> void:
	if Game.mode == Game.Mode.INTRO:
		skipping = true


# ── flight (L14181–14236) ──
func _update_flight(dt: float) -> void:
	var typing := _typing()
	var f := 0.0; var s := 0.0; var u := 0.0; var boost := false
	if not typing:
		f = Input.get_axis("fly_back", "fly_fwd"); s = Input.get_axis("fly_left", "fly_right"); u = Input.get_axis("descend", "climb")
		boost = Input.is_action_pressed("boost")
	f = clampf(f + touch.mz, -1, 1); s = clampf(s + touch.mx, -1, 1); boost = boost or touch.boost
	if u != 0.0:
		At *= exp(u * Cfg.f("zoom.keyRate", 0.95) * dt)
	var map_at := Cfg.f("zoom.mapAt", 11000)
	if At > map_at and map_cooldown <= 0.0:
		At = map_at
		start_transition(Game.Mode.MAP)
		return
	At = clampf(At, Cfg.f("zoom.low", 950), map_at * 1.02)
	A = exp(lerpf(log(A), log(At), 1.0 - exp(-dt / maxf(0.02, Cfg.f("zoom.ease", 0.28)))))
	map_cooldown -= dt

	var cruise := Cfg.f("flight.speed", 0.12) * A * (Cfg.f("flight.boostMul", 3.0) if boost else 1.0)
	var w := Vector2(s, -f)
	if w.length() > 1.0:
		w = w.normalized()
	if w.length() > 0.01:
		var k := 1.0 - exp(-dt / maxf(0.02, Cfg.f("flight.accel", 0.5)))
		vel.x += (w.x * cruise - vel.x) * k; vel.z += (w.y * cruise - vel.z) * k
	elif drag.is_empty():
		var gk := exp(-dt / maxf(0.02, Cfg.f("flight.glide", 1.25)))
		vel.x *= gk; vel.z *= gk
	if drag.is_empty():
		pos += Vector3(vel.x, 0, vel.z) * dt
	_push_from_edges(dt)

	boosting = boost and w.length() > 0.01
	boost_k = lerpf(boost_k, 1.0 if boosting else 0.0, 1.0 - exp(-2.5 * dt))
	if boosting and not last_boost:
		flare = 1.0
	last_boost = boosting
	flare = maxf(0.0, flare - dt / 0.4)
	dun_k = lerpf(dun_k, 1.0 if boosting else 0.0, 1.0 - exp(-dt / (Cfg.f("flight.dunIn", 0.22) if boosting else Cfg.f("flight.dunOut", 0.55))))

	# the light floats over the ground: rises fast, sinks slowly (L14125)
	var want_c := World.ground_clear(pos.x, pos.z, vel.x, vel.z)
	clear = lerpf(clear, want_c, 1.0 - exp(-(6.0 if want_c > clear else 1.2) * dt))
	light_p = _light_pos(Time.get_ticks_msec() / 1000.0)

	# camera rig (L14217): rise fast, settle slowly; look ahead along the velocity
	var want := maxf(A * (1.0 + Cfg.f("camera.boostPull", 0.1) * boost_k), _sight_lift(A))
	a_eff = lerpf(a_eff, want, 1.0 - exp(-dt / (0.35 if want > a_eff else 1.4)))
	var la := Cfg.f("camera.lookAhead", 0.6)
	var ahead := Vector3(pos.x + vel.x * la, 0, pos.z + vel.z * la)
	rig_target = rig_target.lerp(ahead, 1.0 - exp(-dt / maxf(0.02, Cfg.f("camera.follow", 0.3))))
	_apply(flight_pose(rig_target, a_eff))
	var floor_y := World.ground_clear(cam.global_position.x, cam.global_position.z) + 120.0
	if cam.global_position.y < floor_y:
		cam.global_position.y = floor_y
	cam.fov = lerpf(cam.fov, Cfg.f("camera.fov", 40) + 4.0 * boost_k, 1.0 - exp(-3.0 * dt))
	if light:
		light.update_light(dt, light_p, vel, cam, A, boosting, 1.0)
	RenderingServer.global_shader_parameter_set("light_pos", Vector4(light_p.x, light_p.y, light_p.z, 1.0))
	Game.hint_t -= dt


func _light_pos(time: float) -> Vector3:
	var cruise := maxf(1.0, Cfg.f("flight.speed", 0.12) * A)
	var still := 1.0 - smoothstep(0.05, 0.3, Vector2(vel.x, vel.z).length() / cruise)
	var bob := sin(1.7 * time) * A * 0.012 * Cfg.f("flight.bob", 1.0) * (0.4 + 0.6 * still)
	var y := maxf(Cfg.f("flight.lightHeight", 0.24) * A, clear + 70.0) + bob
	return Vector3(pos.x + sin(0.9 * time) * A * 0.004 * still, y, pos.z)


## Lift the camera so ridges between it and the light never hide the light (L14238).
func _sight_lift(a: float) -> float:
	var p := deg_to_rad(pitch_of(a))
	var back := a / tan(p) - 0.1 * a
	var ly := light_p.y
	var need := 0.0
	for i in range(1, 8):
		var tt := i / 8.0
		var g := World.ground_clear(rig_target.x, rig_target.z + back * tt) + 50.0
		if g > ly + (a - ly) * tt:
			need = maxf(need, ly + (g - ly) / tt)
	return minf(need, 2.2 * a)


func _push_from_edges(dt: float) -> void:
	var R := World.rect
	var m := 900.0
	var lo := Vector2(R.position.x + m, R.position.y + m * 1.8)
	var hi := Vector2(R.end.x - m, R.end.y - m)
	if pos.x < lo.x: pos.x += (lo.x - pos.x) * minf(1.0, 3.0 * dt); vel.x *= 0.9
	if pos.x > hi.x: pos.x += (hi.x - pos.x) * minf(1.0, 3.0 * dt); vel.x *= 0.9
	if pos.z < lo.y: pos.z += (lo.y - pos.z) * minf(1.0, 3.0 * dt); vel.z *= 0.9
	if pos.z > hi.y: pos.z += (hi.y - pos.z) * minf(1.0, 3.0 * dt); vel.z *= 0.9
	pos.x = clampf(pos.x, R.position.x, R.end.x); pos.z = clampf(pos.z, R.position.y, R.end.y)


# ── fly ⇄ map (L14306–14340) ──
func toggle_map() -> void:
	match Game.mode:
		Game.Mode.INTRO:
			finish_intro(); start_transition(Game.Mode.MAP)
		Game.Mode.FLIGHT:
			start_transition(Game.Mode.MAP)
		Game.Mode.MAP:
			At = minf(A, Cfg.f("zoom.mapAt", 11000) * 0.8); A = At
			start_transition(Game.Mode.FLIGHT)


func start_transition(to: Game.Mode) -> void:
	from_xf = cam.global_transform; from_fov = cam.fov
	trans = 0.0
	trans_to = to
	trans_dur = 2.4 if to == Game.Mode.MAP else 2.0
	if to == Game.Mode.MAP:
		map_goal = null
		vel = Vector3.ZERO
		map_cx = pos.x; map_cz = pos.z - 0.15 * A
		map_view = clampf(1.15 * A, Cfg.f("map.minView", 2400), Cfg.f("map.maxView", 42000))
		if Game.card_from_flight:
			Game.close_card()
		Game.mode = Game.Mode.TO_MAP
	else:
		Game.close_card()
		rig_target = pos; a_eff = A
		map_cooldown = 1.2
		Game.mode = Game.Mode.TO_FLIGHT


func _update_transition(dt: float) -> void:
	trans = minf(1.0, trans + dt / trans_dur)
	var to_map := trans_to == Game.Mode.MAP
	var e := _ease_in_out(trans)
	var to := map_pose() if to_map else flight_pose(rig_target, a_eff)
	var fp := from_xf.origin; var tp := to.origin
	var xz := Vector2(fp.x, fp.z).lerp(Vector2(tp.x, tp.z), _ease_out(1.05 * trans) if to_map else e)
	var y := exp(lerpf(log(maxf(20.0, fp.y)), log(maxf(20.0, tp.y)), e))
	var rk := _ease_in_out(clampf(1.2 * trans if to_map else 1.1 * trans - 0.1, 0.0, 1.0))
	var q := from_xf.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), rk)
	cam.global_transform = Transform3D(Basis(q), Vector3(xz.x, y, xz.y))
	cam.fov = lerpf(from_fov, Cfg.f("map.fov", 20) if to_map else Cfg.f("camera.fov", 40), e)
	Game.map_k = smoothstep(0.32, 0.92, trans) if to_map else 1.0 - smoothstep(0.04, 0.66, trans)
	_follow_light(dt, 1.0 - Game.map_k)
	if trans >= 1.0:
		Game.mode = Game.Mode.MAP if to_map else Game.Mode.FLIGHT


func _update_map(dt: float) -> void:
	if map_goal != null:
		var k := 1.0 - exp(-dt * 4.0)
		map_cx = lerpf(map_cx, map_goal.cx, k); map_cz = lerpf(map_cz, map_goal.cz, k); map_view = lerpf(map_view, map_goal.view, k)
		if absf(map_view - map_goal.view) < 2.0 and Vector2(map_cx - map_goal.cx, map_cz - map_goal.cz).length() < 2.0:
			map_goal = null
	var R := World.rect
	map_cx = clampf(map_cx, R.position.x - 1500.0, R.end.x + 1500.0)
	map_cz = clampf(map_cz, R.position.y - 2200.0, R.end.y + 2200.0)
	_apply(map_pose())
	cam.fov = Cfg.f("map.fov", 20)
	_follow_light(dt, 0.0)


## Off flight the light still sits over the player (lightPos() each transition/map frame), only faded.
func _follow_light(dt: float, visible_k: float) -> void:
	light_p = _light_pos(Time.get_ticks_msec() / 1000.0)
	RenderingServer.global_shader_parameter_set("light_pos", Vector4(light_p.x, light_p.y, light_p.z, visible_k))
	if light:
		light.update_light(dt, light_p, Vector3.ZERO, cam, A, false, visible_k)


## 御空前往 (L14442): land 320 丈 south of the place so it is in view to the north, at cruising height.
func fly_to(p: Dictionary) -> void:
	pos = Vector3(p.x, 0, p.z + 320.0)
	vel = Vector3.ZERO
	A = Cfg.f("zoom.mid", 1650); At = A
	dun_k = 0.0; flare = 0.0
	clear = World.ground_clear(pos.x, pos.z)
	if light and light.has_method("reset"):
		light.reset()
	flew_to.emit(p)
	start_transition(Game.Mode.FLIGHT)


## A card opened in flight (E near a hotspot, or a click on its tag): brake to a quarter speed (openCard L14433–14439).
func open_card_in_flight(p: Dictionary) -> void:
	Game.open_card(p, true)
	vel *= 0.25


## Select a place on the map (L14426): centre on it, zooming in but never out.
func select_place(p: Dictionary, center := true) -> void:
	Game.open_card(p, false)
	if center and Game.mode == Game.Mode.MAP:
		var big: bool = p.cat in ["region", "sea", "alliance", "edge"]
		map_goal = {"cx": p.x, "cz": p.z, "view": minf(map_view, (5200.0 if big else 2600.0) * float(World.meta.layout.S))}


func zoom_map(factor: float) -> void:
	var lo := Cfg.f("map.minView", 2400); var hi := Cfg.f("map.maxView", 42000)
	var g = map_goal if map_goal != null else {"cx": map_cx, "cz": map_cz, "view": map_view}
	map_goal = {"cx": g.cx, "cz": g.cz, "view": clampf(g.view * factor, lo, hi)}


func map_home_view() -> void:
	map_goal = map_home.duplicate()


## Wheel / pinch (L14509): in flight the altitude target, on the map the view; zooming in past the closest view drops you into flight.
func zoom_by(factor: float) -> void:
	match Game.mode:
		Game.Mode.FLIGHT:
			At *= factor
		Game.Mode.MAP:
			var lo := Cfg.f("map.minView", 2400)
			if factor < 1.0 and map_view <= lo * 1.01:
				pos = Vector3(map_cx, 0, map_cz + lo * 0.12); vel = Vector3.ZERO
				A = clampf(lo * 1.6, Cfg.f("zoom.low", 950), Cfg.f("zoom.mapAt", 11000) * 0.8); At = A
				clear = World.ground_clear(pos.x, pos.z)
				start_transition(Game.Mode.FLIGHT)
			else:
				map_goal = null
				map_view = clampf(map_view * factor, lo, Cfg.f("map.maxView", 42000))


# ───────────────────────── input (L14465–14576) ─────────────────────────

func _unhandled_input(ev: InputEvent) -> void:
	if Game.mode == Game.Mode.LOADING:
		return
	# during the intro every key / click / touch only speeds it up ×4 (keydown L14527); the 收图 button still toggles
	if Game.mode == Game.Mode.INTRO and (ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.is_pressed():
		if not ev.is_action("toggle_debug"):
			skip_intro()
		return
	# a click on the 3D view takes focus away from the search box or a debug slider, as clicking the canvas blurs the
	# focused input in the demo — otherwise WASD/M would stay captured by the control
	if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.pressed:
		get_viewport().gui_release_focus()
	if ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		_touch_input(ev)
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if _typing():
			return                                                  # a focused slider/field keeps the keys (L14525)
		if ev.is_action("toggle_map"):
			toggle_map()
		elif ev.is_action("land") and Game.mode == Game.Mode.FLIGHT and Game.near != null:
			if Game.selected == Game.near:
				Game.close_card()
			else:
				open_card_in_flight(Game.near)
		elif ev.is_action("toggle_hint"):
			Game.hint_t = 30.0 if Game.hint_t <= 0.0 else -1.0
		elif ev.keycode == KEY_ESCAPE:
			if Game.selected != null:
				Game.close_card()
			elif Game.mode == Game.Mode.MAP:
				toggle_map()
	elif ev is InputEventMouseButton:
		# one notch ≈ a browser deltaY of 100; high-resolution wheels and touchpads report fractions of a notch in factor
		var notch: float = 100.0 * (ev.factor if ev.factor > 0.0 else 1.0)
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			zoom_by(exp(-notch * Cfg.f("zoom.wheel", 0.0013)))
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			zoom_by(exp(notch * Cfg.f("zoom.wheel", 0.0013)))
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_drag_start(ev.position)
			else:
				_drag_end()
	elif ev is InputEventMouseMotion and not drag.is_empty():
		_drag_move(ev.position, ev.relative)
	elif ev is InputEventPanGesture:
		zoom_by(exp(ev.delta.y * 30.0 * Cfg.f("zoom.wheel", 0.0013)))
	elif ev is InputEventMagnifyGesture:
		zoom_by(1.0 / maxf(ev.factor, 0.01))


## Two-finger pinch (pointer tracking L14470–14485): the second finger cancels the grab and zooms by the change in spread.
## One finger arrives as emulated mouse events (input_devices/pointing/emulate_mouse_from_touch) and drives the grab.
func _touch_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			touches[ev.index] = ev.position
		else:
			touches.erase(ev.index)
		pinch_d = 0.0
		if touches.size() == 2:
			var ps := touches.values()
			pinch_d = (ps[0] as Vector2).distance_to(ps[1])
			drag = {}
	elif ev is InputEventScreenDrag and touches.has(ev.index):
		touches[ev.index] = ev.position
		if touches.size() == 2:
			var ps := touches.values()
			var d := (ps[0] as Vector2).distance_to(ps[1])
			if pinch_d > 0.0 and d > 0.0:
				zoom_by(pinch_d / d)
			pinch_d = d


func _ground_at(sp: Vector2):
	return Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(sp), cam.project_ray_normal(sp))


func _drag_start(sp: Vector2) -> void:
	if Game.mode == Game.Mode.FLIGHT:
		var g = _ground_at(sp)
		if g != null:
			drag = {"grab": g, "last": Time.get_ticks_msec(), "v": Vector3.ZERO}
	elif Game.mode == Game.Mode.MAP:
		drag = {"map": true}


func _drag_move(sp: Vector2, rel: Vector2) -> void:
	if drag.has("map"):
		var wpp := 2.0 * cam.global_position.y * tan(deg_to_rad(cam.fov) * 0.5) / get_viewport().get_visible_rect().size.y
		map_cx -= rel.x * wpp; map_cz -= rel.y * wpp; map_goal = null
		return
	if Game.mode != Game.Mode.FLIGHT:
		return
	var g = _ground_at(sp)
	if g == null:
		return
	var d: Vector3 = g - drag.grab
	var now := Time.get_ticks_msec()
	var dtt := maxf(1.0, float(now - drag.last)) / 1000.0
	drag.v = Vector3(-d.x / dtt, 0, -d.z / dtt); drag.last = now
	pos.x -= d.x; pos.z -= d.z; rig_target.x -= d.x; rig_target.z -= d.z
	_apply(flight_pose(rig_target, a_eff))
	var g2 = _ground_at(sp)
	if g2 != null:
		drag.grab = g2


func _drag_end() -> void:
	if drag.has("grab"):
		var fresh: bool = Time.get_ticks_msec() - int(drag.last) < 90
		var fl := Cfg.f("flight.fling", 0.85)
		vel = Vector3(drag.v.x * fl, 0, drag.v.z * fl) if fresh else Vector3.ZERO
	drag = {}


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit or f is Range


# ───────────────────────── helpers ─────────────────────────

## 低空 / 中空 / 高空 halfway between the zoom levels (bandName L14105), so the readout follows the sliders.
func band_name(a: float) -> String:
	var lo := Cfg.f("zoom.low", 950); var mid := Cfg.f("zoom.mid", 1650); var hi := Cfg.f("zoom.high", 8000)
	return "低空" if a < (lo + mid) * 0.5 else ("中空" if a < (mid + hi) * 0.5 else "高空")


static func _ease_in_out(x: float) -> float:
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)
