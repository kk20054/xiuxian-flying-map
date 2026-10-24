class_name TreeKit
## The demo's nine low-poly tree kinds (treeGeometry L6280–6324), local units (height ~20–28, ×instance scale):
## 0 pine, 1 broadleaf, 2 tall cypress/bamboo, 3 黄山松, 4 willow, 5 blossom, 6 spirit, 7 lotus, 8 reeds.
## Normals are the "sphere normals" of each part (pointing out of its centre, squashed by sy) so crowns shade round;
## UV.x carries the part (0 trunk, 1 crown, 2 flower). Replace with Blender models freely — keep UV.x and the normals.

static var _st: SurfaceTool


static func mesh(kind: int) -> ArrayMesh:
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6280 + kind
	match kind:
		0:   # pine: a trunk prism and three stacked cones
			_prism(Vector3.ZERO, 1.1, 0.7, 7.0, 5, 0.0)
			for k in 3:
				_cone(Vector3(0, 5.0 + k * 5.2, 0), 6.2 - k * 1.6, 8.0 - k * 0.9, 7, 1.0, Vector3(0, 9.0, 0))
		1:   # broadleaf: trunk and an icosahedral blob
			_prism(Vector3.ZERO, 1.0, 0.7, 8.0, 5, 0.0)
			_blob(Vector3(0, 13.0, 0), Vector3(10.0, 8.2, 10.0), rng, 1.0)
		2:   # tall and narrow
			_prism(Vector3.ZERO, 0.8, 0.5, 6.0, 5, 0.0)
			_blob(Vector3(0, 15.0, 0), Vector3(4.2, 12.0, 4.2), rng, 1.0)
		3:   # 黄山松: a bent trunk and three flat pads
			_prism(Vector3.ZERO, 1.2, 0.6, 10.0, 5, 0.0, Vector3(2.5, 0, 0))
			for p in [Vector3(4.0, 11.0, 0.0), Vector3(-3.0, 13.0, 2.0), Vector3(1.0, 15.5, -2.0)]:
				_blob(p, Vector3(7.0, 1.8, 6.0), rng, 1.0, 1)
		4:   # willow: a blob and a hanging skirt
			_prism(Vector3.ZERO, 1.0, 0.7, 7.0, 5, 0.0)
			_blob(Vector3(0, 12.0, 0), Vector3(8.5, 6.5, 8.5), rng, 1.0)
			for k in 9:
				var a := TAU * k / 9.0
				var p := Vector3(cos(a) * 7.0, 8.0, sin(a) * 7.0)
				var t := Vector3(-sin(a), 0, cos(a)) * 2.4
				_quad(p - t, p + t, p + t * 0.6 + Vector3(0, -7.0, 0) + p.normalized() * 1.5, p - t * 0.6 + Vector3(0, -7.0, 0) + p.normalized() * 1.5, Vector3(0, 12, 0), 1.0)
		5:   # blossom: a wide blob and a pad of flowers
			_prism(Vector3.ZERO, 1.0, 0.7, 6.0, 5, 0.0)
			_blob(Vector3(0, 11.0, 0), Vector3(10.5, 6.5, 10.5), rng, 1.0)
			_blob(Vector3(0, 15.0, 0), Vector3(7.0, 2.6, 7.0), rng, 2.0, 1)
		6:   # spirit tree: slender, two crowns (glows jade)
			_prism(Vector3.ZERO, 0.8, 0.4, 14.0, 5, 0.0)
			_blob(Vector3(0, 14.0, 0), Vector3(6.0, 5.0, 6.0), rng, 1.0)
			_blob(Vector3(0, 22.0, 0), Vector3(4.0, 4.0, 4.0), rng, 1.0)
		7:   # lotus: pads on the water and a flower
			for k in 5:
				var a := TAU * k / 5.0 + 0.3
				_disc(Vector3(cos(a) * 3.0, 0.2, sin(a) * 3.0), 2.4, 7, 1.0)
			_cone(Vector3(0, 0.3, 0), 1.2, 2.6, 6, 2.0, Vector3(0, 1.2, 0))
		8:   # reeds: nine blades
			for k in 9:
				var a := rng.randf() * TAU
				var r := rng.randf() * 2.5
				var b := Vector3(cos(a) * r, 0, sin(a) * r)
				var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * 1.5
				_quad(b - Vector3(0.35, 0, 0), b + Vector3(0.35, 0, 0), b + lean + Vector3(0.05, 9.0, 0), b + lean - Vector3(0.05, 9.0, 0) * Vector3(1, -1, 1), b + Vector3(0, 4, 0), 1.0)
	_st.index()
	return _st.commit()


static func _v(p: Vector3, centre: Vector3, part: float, sy := 1.0) -> void:
	var n := p - centre
	n.y /= sy
	_st.set_normal(n.normalized() if n.length() > 1e-4 else Vector3.UP)
	_st.set_uv(Vector2(part, 0))
	_st.add_vertex(p)


static func _tri(a: Vector3, b: Vector3, c: Vector3, centre: Vector3, part: float, sy := 1.0) -> void:
	_v(a, centre, part, sy); _v(b, centre, part, sy); _v(c, centre, part, sy)


static func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, centre: Vector3, part: float) -> void:
	_tri(a, b, c, centre, part); _tri(a, c, d, centre, part)


static func _prism(base: Vector3, r0: float, r1: float, h: float, n: int, part: float, lean := Vector3.ZERO) -> void:
	for i in n:
		var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
		var p0 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p1 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var q0 := base + lean + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var q1 := base + lean + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		_quad(p0, q0, q1, p1, base + Vector3(0, h * 0.5, 0), part)


static func _cone(base: Vector3, r: float, h: float, n: int, part: float, centre_off: Vector3) -> void:
	var apex := base + Vector3(0, h, 0)
	var c := base + centre_off * 0.5
	for i in n:
		var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
		var p0 := base + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := base + Vector3(cos(a1) * r, 0, sin(a1) * r)
		_tri(p0, apex, p1, c, part, 0.6)
		_tri(p1, base, p0, base + Vector3(0, 3, 0), part)


static func _disc(c: Vector3, r: float, n: int, part: float) -> void:
	for i in n:
		var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
		_tri(c, c + Vector3(cos(a1) * r, 0, sin(a1) * r), c + Vector3(cos(a0) * r, 0, sin(a0) * r), c - Vector3(0, 6, 0), part)


## An ellipsoidal blob from an icosahedron (subdivided once for the big crowns), corners jittered ×0.94–1.06.
static func _blob(c: Vector3, s: Vector3, rng: RandomNumberGenerator, part: float, sub := 1) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var V := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var F := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var verts: Array = []
	for v in V:
		verts.append((v as Vector3).normalized())
	for _s in sub:
		var nf := []
		var mid := {}
		for f in F:
			var m := []
			for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
				var key: int = mini(e[0], e[1]) * 1000 + maxi(e[0], e[1])
				if not mid.has(key):
					mid[key] = verts.size(); verts.append(((verts[e[0]] + verts[e[1]]) * 0.5).normalized())
				m.append(mid[key])
			nf.append_array([[f[0], m[0], m[2]], [f[1], m[1], m[0]], [f[2], m[2], m[1]], [m[0], m[1], m[2]]])
		F = nf
	var P := []
	for v in verts:
		P.append(c + (v as Vector3) * s * rng.randf_range(0.94, 1.06))
	for f in F:
		_tri(P[f[0]], P[f[1]], P[f[2]], c, part, s.y / s.x)
