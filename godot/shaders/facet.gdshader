// Faceted, ink-lined meshes: the sects' halls and terraces, the cities, landmarks and the sects' fine ground — a port of
// the demo's FACET_VS/FS (L4505–4675). Vertex layout of the exported GLBs (tools/export-world):
//   COLOR.rgb = face colour (display-space sRGB)    COLOR.a = ink weight of the edge opposite corner C
//   UV        = barycentric (x, y) of the corner     UV2     = ink weights of the edges opposite corners A and B
// The ink is drawn where a barycentric goes to 0, a constant ~1 px wide because the threshold is measured in fwidth.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

#include "res://shaders/land_common.gdshaderinc"
#include "res://shaders/patch_common.gdshaderinc"
#include "res://shaders/ground_common.gdshaderinc"

uniform float crease_ink = 0.75;      // terrain.creaseInk
uniform float foot_ink = 0.8;
uniform float line_w = 1.05;
uniform float soft_k = 0.85;         // terrain.soft
uniform float cun_k = 1.0;            // terrain.cun
uniform bool ground = false;          // the sects' fine ground: blend toward the heightfield's smooth normal like the mountains
uniform float glow = 0.0;

varying vec3 v_wp;
varying vec3 v_bary;
varying vec3 v_crease;
varying vec3 v_col;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (wp.y > 0.0) wp.y *= relief;
	wp.y *= 1.0 - map_k;
	v_wp = wp;
	v_bary = vec3(UV, 1.0 - UV.x - UV.y);
	v_crease = vec3(UV2, COLOR.a);
	v_col = COLOR.rgb;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}

void fragment() {
	if (map_k > 0.995) discard;
	vec3 wp = v_wp;
	vec3 Nf = normalize(cross(dFdx(wp), dFdy(wp)));
	if (dot(Nf, CAMERA_POSITION_WORLD - wp) < 0.0) Nf = -Nf;
	vec3 fw = fwidth(v_bary);
	float fmax = max(fw.x, max(fw.y, fw.z));
	float small = smoothstep(0.07, 0.16, fmax);
	vec3 s = sun_at(wp.xz);
	float soft = 0.0;
	vec3 N = Nf;
	vec3 Ns = Nf;
	if (ground) {
		// the smooth normal of the patch's own 13.3-丈 heights (the demo's aN: sN in meshGrid L4971); off the patches the grid's
		int ip = patch_at(wp.xz, 0.0);
		float e = ip >= 0 ? patch_cell : 20.0;
		Ns = ip >= 0
			? normalize(vec3(patch_h(wp.xz - vec2(e, 0), ip) - patch_h(wp.xz + vec2(e, 0), ip), 2.0 * e, patch_h(wp.xz - vec2(0, e), ip) - patch_h(wp.xz + vec2(0, e), ip)))
			: normalize(vec3(height_at(wp.xz - vec2(e, 0)) - height_at(wp.xz + vec2(e, 0)), 2.0 * e, height_at(wp.xz - vec2(0, e)) - height_at(wp.xz + vec2(0, e))));
		soft = max(soft_k, small) * 0.8;
		N = normalize(mix(Nf, Ns, soft));
	}
	float t = min(mix(tones(Nf), soft_tones(dot(N, sun_dir)), soft), cast_light(s.r));
	vec3 base = v_col;
	if (ground) {
		// the same painted ground as the range round it, so no seam at the patch edge (FACET_FS L4627–4642): the woods'
		// canopy green on the gentle slopes, the biome's grass, the season
		float wood = smoothstep(0.06, 0.5, texture(t_ground, world_uv(wp.xz)).r + (vnoise(wp.xz / 36.0) - 0.5) * 0.24) * smoothstep(0.55, 0.8, N.y) * (1.0 - smoothstep(380.0, 460.0, wp.y));
		base = mix(base, wood_col(wp.xz), wood * 0.8);
		base = biome_ground(base, wp, Ns, wood);
		base = season_ground(base, wp, Ns);
	}
	vec3 col = ao_mul(tone_col(base, t), s.b) + vec3(0.016, 0.02, 0.018) * N.y;
	if (ground) col *= 1.0 - cun(wp, N) * (0.17 - 0.11 * t) * cun_k;
	col = mix(col, v_col * 1.14, glow * smoothstep(0.55, 0.8, dot(v_col, vec3(0.3, 0.55, 0.15))));
	// ink on the creases: constant screen width; tiny facets get no strokes, only colour
	vec3 e3 = smoothstep(fw * 0.25, fw * line_w, v_bary);
	float line = max(max((1.0 - e3.x) * v_crease.x, (1.0 - e3.y) * v_crease.y), (1.0 - e3.z) * v_crease.z) * crease_ink * mix(1.0, 0.32, soft);
	line *= 1.0 - smoothstep(0.075, 0.17, fmax);
	float fy = max(fwidth(wp.y), 1e-3);
	float foot = (1.0 - smoothstep(fy * 0.9, fy * 2.4, wp.y)) * foot_ink * step(-0.2, wp.y) * (ground ? 1.0 : 0.0);
	foot *= smoothstep(3.0, 24.0, texture(t_height_blur, height_uv(wp.xz)).r);   // only real mountains, not the faint swells (L4654)
	col = mix(col, ink_col, clamp(max(line, foot), 0.0, 1.0) * 0.82);
	col = light_on_ground(col, wp);
	col = intro_mix(col, line, (1.0 - t) * 0.32 + 0.06, wp, vec2(11027.0, 792.0), 22236.0);
	col = haze_mix(col, wp, CAMERA_POSITION_WORLD);
	ALBEDO = OUTPUT_IS_SRGB ? (col) : to_linear(col);
}
