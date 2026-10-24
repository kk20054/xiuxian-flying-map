// Trees (demo TREE_VS/FS L6228–6279): colour from the instance's slot, the crown sways in gusts that roll across the
// land (quadratic in height), soft round tones from the sphere normals, a sunlit rim, snow on frost pines, jade glow
// on spirit trees. INSTANCE_CUSTOM = (kind, colour slot, yaw, hash); UV.x = part (0 trunk, 1 crown, 2 flower).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

#include "res://shaders/land_common.gdshaderinc"

global uniform vec2 wind;
uniform vec3 cols[16];
uniform vec3 trunk = vec3(0.36, 0.3, 0.25);
uniform vec3 flower = vec3(0.93, 0.62, 0.68);
uniform float sway = 1.0;
uniform float size_k = 1.0;
uniform float soft_k = 0.85;

varying vec3 v_wp;
varying vec3 v_col;
varying vec3 v_n;
varying float v_h;
varying float v_glow;
varying float v_snow;

void vertex() {
	float part = UV.x;
	vec4 ic = INSTANCE_CUSTOM;
	vec3 base = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz) * size_k;
	float crown = step(0.5, part) * step(part, 1.5), hk = max(VERTEX.y - 3.0, 0.0) / 22.0;
	float gust = 0.55 + 0.45 * sin(TIME * 0.31 + dot(base.xz, vec2(0.0019, 0.0012)));
	float sw = sin(TIME * 1.5 + ic.w * 6.2832 + base.x * 0.011) * 0.65 + sin(TIME * 2.6 + ic.w * 3.1 + base.z * 0.017) * 0.25;
	vec2 wd = normalize(wind + vec2(1e-4, 0.0));
	vec2 off = (wd * (0.35 + sw) * gust + vec2(-wd.y, wd.x) * sw * 0.25) * hk * hk * s * 0.8 * sway * crown;
	vec3 local = (MODEL_MATRIX * vec4(VERTEX * size_k, 0.0)).xyz;
	vec3 wp = vec3(base.x, base.y * relief, base.z) + local + vec3(off.x, 0.0, off.y);
	wp.y *= 1.0 - map_k;
	v_wp = wp;
	v_n = normalize(mat3(MODEL_MATRIX) * NORMAL);
	v_h = clamp(VERTEX.y / 22.0, 0.0, 1.0);
	int ci = int(ic.y + 0.5);
	vec3 fc = cols[clamp(ci, 0, 15)];
	v_col = part > 1.5 ? flower : mix(trunk, fc * (0.88 + 0.24 * ic.w) + vec3(0.03, 0.02, -0.02) * (ic.w - 0.5), part);
	v_glow = ci == 11 ? crown : 0.0;
	v_snow = ci == 4 ? crown : 0.0;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}

void fragment() {
	if (map_k > 0.995) discard;
	vec3 Ns = normalize(v_n);
	vec3 Nf = normalize(cross(dFdx(v_wp), dFdy(v_wp)));
	if (dot(Nf, Ns) < 0.0) Nf = -Nf;
	float k = 0.35 + 0.6 * soft_k;
	vec3 N = normalize(mix(Nf, Ns, k));
	float t = mix(mix(tones(Nf), soft_tones(dot(N, sun_dir)), k), 0.55, 0.4);
	vec3 s = sun_at(v_wp.xz);
	t = min(t, cast_light(s.r));
	vec3 base = v_col * mix(0.8, 1.07, smoothstep(0.2, 0.9, v_h));
	base = mix(base, vec3(0.9, 0.93, 0.97), v_snow * 0.9 * smoothstep(0.3, 0.7, Nf.y + 0.42 * (vnoise(v_wp.xz * 0.21 + v_wp.y * 0.33) - 0.5)));
	vec3 col = ao_mul(tone_col(base, t), s.b);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wp);
	col += base * pow(1.0 - abs(dot(Ns, V)), 3.0) * smoothstep(0.05, 0.6, dot(Ns, sun_dir)) * step(0.3, v_h) * 0.32 * cast_light(s.r);
	col = mix(col, base * 1.12 + vec3(0.05, 0.09, 0.08), v_glow * 0.55);
	col = intro_mix(col, 0.0, (1.0 - t) * 0.32 + 0.06, v_wp, vec2(11027.0, 792.0), 22236.0);
	col = haze_mix(col, v_wp, CAMERA_POSITION_WORLD);
	ALBEDO = OUTPUT_IS_SRGB ? col : to_linear(col);
}
