extends RefCounted
## Procedural rock meshes for the terrain's rock instances (tools/terrain → rocks.bin): karst towers, sandstone pillars,
## stone blades, sea stacks, granite spires, basalt columns, Danxia buttes — the vertical landforms a 40-丈 heightfield
## cannot hold. Unit size (radius 1, height 1, base at y = 0); rocks.gd scales each instance to its radius and height.
## Vertex layout = the facet ink shader's (facet.gdshader): COLOR.rgb face colour, COLOR.a / UV2 edge ink, UV barycentric.
## Replace a kind with a Blender model by giving rocks.gd a mesh with the same layout (tools/blender/bake_ink_layout.py).

const KINDS := ["karst_tower", "sandstone_pillar", "stone_blade", "sea_stack", "granite_spire", "basalt_column", "danxia_butte"]

# per kind: sides, ring heights (0…1), ring radii, colours of the bands (display sRGB), top colour, jitter
const SPEC := {
	"karst_tower": {"n": 9, "t": [0.0, 0.22, 0.5, 0.72, 0.86, 0.95], "r": [1.0, 0.93, 0.9, 0.84, 0.66, 0.38],
		"band": [Color(0.58, 0.61, 0.58), Color(0.66, 0.68, 0.64), Color(0.55, 0.58, 0.56)], "top": Color(0.33, 0.46, 0.32), "green": 0.8, "jit": 0.13},
	"sandstone_pillar": {"n": 7, "t": [0.0, 0.18, 0.4, 0.62, 0.84, 0.97], "r": [1.15, 1.0, 0.95, 0.97, 0.9, 0.86],
		"band": [Color(0.66, 0.62, 0.53), Color(0.58, 0.55, 0.48), Color(0.71, 0.66, 0.56)], "top": Color(0.3, 0.44, 0.3), "green": 0.96, "jit": 0.16},
	"stone_blade": {"n": 5, "t": [0.0, 0.35, 0.7], "r": [1.0, 0.6, 0.22], "band": [Color(0.56, 0.58, 0.57), Color(0.63, 0.65, 0.63)],
		"top": Color(0.5, 0.52, 0.5), "green": 2.0, "jit": 0.25},
	"sea_stack": {"n": 8, "t": [0.0, 0.07, 0.16, 0.5, 0.88], "r": [1.0, 0.82, 0.98, 0.9, 0.8],
		"band": [Color(0.42, 0.42, 0.4), Color(0.5, 0.49, 0.46), Color(0.56, 0.55, 0.51)], "top": Color(0.45, 0.55, 0.36), "green": 0.88, "jit": 0.14},
	"granite_spire": {"n": 6, "t": [0.0, 0.3, 0.6, 0.85], "r": [1.0, 0.72, 0.45, 0.2], "band": [Color(0.67, 0.68, 0.7), Color(0.74, 0.75, 0.77)],
		"top": Color(0.78, 0.79, 0.8), "green": 2.0, "jit": 0.18},
	"basalt_column": {"n": 6, "t": [0.0, 0.95], "r": [1.0, 0.97], "band": [Color(0.3, 0.29, 0.31)], "top": Color(0.36, 0.35, 0.36), "green": 2.0, "jit": 0.04},
	"danxia_butte": {"n": 8, "t": [0.0, 0.08, 0.3, 0.55, 0.8, 0.96], "r": [1.3, 1.02, 1.0, 0.98, 0.96, 0.93],
		"band": [Color(0.72, 0.36, 0.25), Color(0.62, 0.3, 0.21), Color(0.76, 0.42, 0.29)], "top": Color(0.36, 0.48, 0.3), "green": 0.95, "jit": 0.1},
}


static func build(kind: String, variant: int) -> ArrayMesh:
	var S: Dictionary = SPEC[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + variant * 7919
	var n: int = S.n
	var ts: Array = S.t
	var rs: Array = S.r
	var jit: float = S.jit
	var phase := rng.randf() * TAU
	var rings: Array = []
	for k in ts.size():
		var ring: Array[Vector3] = []
		for i in n:
			var a := phase + TAU * float(i) / n + rng.randf_range(-0.18, 0.18) / n * TAU
			var r: float = rs[k] * (1.0 + rng.randf_range(-jit, jit))
			ring.append(Vector3(cos(a) * r, float(ts[k]), sin(a) * r))
		rings.append(ring)
	var apex := Vector3(rng.randf_range(-0.08, 0.08), 1.0, rng.randf_range(-0.08, 0.08))
	var pos := PackedVector3Array(); var col := PackedColorArray(); var uv := PackedVector2Array(); var uv2 := PackedVector2Array()
	var bands: Array = S.band
	for k in ts.size() - 1:
		var t_mid := (float(ts[k]) + float(ts[k + 1])) * 0.5
		var c0: Color = bands[k % bands.size()]
		if t_mid > float(S.green):
			c0 = S.top
		for i in n:
			var p00: Vector3 = rings[k][i]; var p10: Vector3 = rings[k][(i + 1) % n]
			var p01: Vector3 = rings[k + 1][i]; var p11: Vector3 = rings[k + 1][(i + 1) % n]
			var c := c0.lerp(Color(0, 0, 0), rng.randf_range(0.0, 0.08))
			var h_ink := 0.35 if k > 0 else 0.0
			# two triangles; ink on the vertical (crease) edges and the band joints, none on the quad diagonal
			_tri(pos, col, uv, uv2, p00, p10, p11, c, h_ink, 0.65, 0.0)
			_tri(pos, col, uv, uv2, p00, p11, p01, c.lerp(Color(1, 1, 1), 0.03), 0.0, 0.35, 0.65)
	var top: Array = rings[ts.size() - 1]
	for i in n:
		_tri(pos, col, uv, uv2, top[i], top[(i + 1) % n], apex, Color(S.top).lerp(Color(0, 0, 0), rng.randf_range(0.0, 0.1)), 0.5, 0.0, 0.0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos; arr[Mesh.ARRAY_COLOR] = col; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_TEX_UV2] = uv2
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## One un-shared triangle A B C. ink_ab / ink_bc / ink_ca = how much ink the edge carries (the shader reads the weight of
## the edge opposite each corner: C → COLOR.a, A → UV2.x, B → UV2.y).
static func _tri(pos: PackedVector3Array, col: PackedColorArray, uv: PackedVector2Array, uv2: PackedVector2Array,
		a: Vector3, b: Vector3, c: Vector3, colour: Color, ink_ab: float, ink_bc: float, ink_ca: float) -> void:
	var k := Color(colour.r, colour.g, colour.b, ink_ab)
	for p in [a, b, c]:
		pos.append(p)
		col.append(k)
		uv2.append(Vector2(ink_bc, ink_ca))
	uv.append(Vector2(1, 0)); uv.append(Vector2(0, 1)); uv.append(Vector2(0, 0))
