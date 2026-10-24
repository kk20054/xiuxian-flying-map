extends Node3D
## 遁光 — the player is a streak of light (demo 08 · buildLight L12696–12833; the cultivator figure of 08b is off by default).
## Three glow quads (halo, inner, head) and a tapered trail from the light's recent positions. Its size scales with
## altitude ((A/1650)^0.92) so it stays about the same on screen.

const TN := 96

var halo: MeshInstance3D
var inner: MeshInstance3D
var head: MeshInstance3D
var trail: MeshInstance3D
var trail_mat: ShaderMaterial
var hist: Array = []                 # [{p, t}]
var dir := Vector3(0, 0, -1)
var idle_k := 1.0
var boost_k := 0.0
var t := 0.0
var pos := Vector3.ZERO


func _ready() -> void:
	var glow := Color(Cfg.g("light.glow", "#3fd9b0")); var core := Color(Cfg.g("light.core", "#e8fff6"))
	halo = _quad(Vector3(glow.r, glow.g, glow.b), 3.2)
	inner = _quad(Vector3(glow.r, glow.g, glow.b).lerp(Vector3(core.r, core.g, core.b), 0.45), 5.0)
	head = _quad(Vector3(core.r, core.g, core.b), 6.0)
	trail = MeshInstance3D.new()
	trail.mesh = ImmediateMesh.new()
	trail_mat = ShaderMaterial.new()
	trail_mat.shader = load("res://shaders/light_trail.gdshader")
	trail_mat.set_shader_parameter("core", Vector3(core.r, core.g, core.b))
	trail_mat.set_shader_parameter("glow", Vector3(glow.r, glow.g, glow.b))
	trail.material_override = trail_mat
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.extra_cull_margin = 16384.0
	trail.sorting_offset = 10.0
	add_child(trail)


func _quad(col: Vector3, fall: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/light_glow.gdshader")
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("fall", fall)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4096.0
	add_child(mi)
	return mi


func reset() -> void:
	hist.clear()


func update_light(dt: float, p: Vector3, vel: Vector3, cam: Camera3D, A: float, boost: bool, visible_k: float) -> void:
	t += dt
	pos = p
	var K := Cfg.f("light.size", 1.0) * pow(A / 1650.0, 0.92)
	var cruise := maxf(1.0, Cfg.f("flight.speed", 0.12) * A)
	var speed := Vector2(vel.x, vel.z).length()
	var sp01 := clampf(speed / (cruise * Cfg.f("flight.boostMul", 3.0)), 0.0, 1.0)
	idle_k = lerpf(idle_k, 1.0 if speed < 0.08 * cruise else 0.0, 1.0 - exp(-dt * 3.0))
	boost_k = lerpf(boost_k, 1.0 if (boost and speed > 0.5 * cruise) else 0.0, 1.0 - exp(-dt * 4.0))
	if speed > 1.0:
		dir = dir.slerp(Vector3(vel.x, 0, vel.z).normalized(), 1.0 - exp(-dt * 8.0)).normalized()
	var I := Cfg.f("light.intensity", 0.85) * visible_k
	var breath := 1.0 + Cfg.f("light.breath", 0.08) * idle_k * sin(2.3 * t)
	for q in [halo, inner, head]:
		q.global_position = p
	_set_q(halo, 90.0 * K * breath * (1.0 + 0.2 * boost_k), 0.5 * I * (0.92 + 0.08 * breath))
	_set_q(inner, 34.0 * K * breath, 0.85 * I)
	_set_q(head, 15.0 * K * (1.0 + 0.4 * (breath - 1.0)), 1.0 * I)

	# the trail: history of positions, kept for (0.55 + 0.75·sp01 + 0.4·boostK)·tail seconds
	hist.push_front({"p": p, "t": t})
	var keep := (0.55 + 0.75 * sp01 + 0.4 * boost_k) * Cfg.f("light.tail", 1.0)
	while hist.size() > TN or (hist.size() > 2 and t - hist[-1].t > keep):
		hist.pop_back()
	var im: ImmediateMesh = trail.mesh
	im.clear_surfaces()
	var a := I * smoothstep(0.02, 0.25, sp01 + 0.05)
	trail_mat.set_shader_parameter("alpha", a)
	if hist.size() < 3 or a < 0.01:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var camp := cam.global_position
	for k in TN:
		var h: Vector3 = hist[mini(k, hist.size() - 1)].p
		var prev: Vector3 = hist[maxi(0, mini(k - 1, hist.size() - 1))].p
		var next: Vector3 = hist[mini(k + 1, hist.size() - 1)].p
		var tg := prev - next
		if tg.length() < 1e-3:
			tg = -dir
		var side := tg.cross(camp - h).normalized()
		var w := (10.0 + 6.0 * sp01) * K * pow(1.0 - float(k) / TN, 0.9)
		var ta := float(k) / (TN - 1)
		im.surface_set_uv(Vector2(ta, -1)); im.surface_add_vertex(h - side * w)
		im.surface_set_uv(Vector2(ta, 1)); im.surface_add_vertex(h + side * w)
	im.surface_end()


func _set_q(q: MeshInstance3D, size: float, alpha: float) -> void:
	var m: ShaderMaterial = q.material_override
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("alpha", alpha)
	q.visible = alpha > 0.005
