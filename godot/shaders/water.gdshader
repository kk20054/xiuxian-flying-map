// The sea, rivers and lakes as one sunken sheet (demo 05 · WATER_VS/FS L5567–5737, after WaterThreeJS's technique,
// not its realism): depth = the shore-distance field, posterised into a few flat colour steps; 11 summed Gerstner waves
// only shade (no displacement); a Fresnel tint of sky; sun glints; ink ripple lines that run along the shores.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

#include "res://shaders/land_common.gdshaderinc"

#define NWAVES 11
uniform float inland_depth = 7.0;
uniform float sea_depth = 20.0;
uniform vec3 water_light = vec3(0.659, 0.831, 0.804);   // #a8d4cd
uniform vec3 water_mid = vec3(0.451, 0.694, 0.737);     // #73b1bc
uniform vec3 water_deep = vec3(0.247, 0.486, 0.592);    // #3f7c97
uniform vec3 sky = vec3(0.933, 0.945, 0.925);           // #eef1ec
uniform vec3 line_col = vec3(0.247, 0.353, 0.384);      // #3f5a62
uniform float steps = 4.0;
uniform float waves = 1.0;
uniform float ripples = 1.0;
uniform float flow_k = 1.0;
uniform float sea_motion = 1.8;
uniform vec3 mist = vec3(0.902, 0.886, 0.867);          // #e6e2dd, the world's edge

varying vec3 v_wp;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sea = textureLod(t_water, world_uv(wp.xz), 0.0).a;
	wp.y = -mix(inland_depth, sea_depth, sea) * (1.0 - map_k);
	v_wp = wp;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}

vec4 ocean(vec2 pos, float amp0, float freq0, float speed, float spread, vec2 wd) {
	float base_angle = atan(wd.y, wd.x), freq = freq0, amp = amp0, h = 0.0, jxx = 1.0, jzz = 1.0, jxz = 0.0;
	vec2 sl = vec2(0.0);
	for (int i = 0; i < NWAVES; i++) {
		float fi = float(i), r0 = hash12(vec2(fi, 1.7)), r1 = hash12(vec2(fi, 9.1));
		float ang = base_angle + (r0 * 2.0 - 1.0) * spread;
		vec2 d = vec2(cos(ang), sin(ang));
		float ph = sqrt(9.81 * freq) * speed, arg = freq * dot(d, pos) + TIME * ph + r1 * 6.2831853;
		float s = sin(arg), c = cos(arg), WA = freq * amp, Q = 0.7 / max(WA * float(NWAVES), 1e-3);
		sl += d * WA * c; h += amp * s;
		jxx -= Q * d.x * d.x * WA * s; jzz -= Q * d.y * d.y * WA * s; jxz -= Q * d.x * d.y * WA * s;
		freq *= 1.19; amp *= 0.82;
	}
	return vec4(sl, jxx * jzz - jxz * jxz, h);
}

void fragment() {
	vec2 xz = v_wp.xz;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec2 uv = world_uv(xz);
	vec4 w = texture(t_water, uv);
	float sd = (w.r * 255.0 - 128.0) * 2.0;
	// under the land the ground covers it; near the shore it reaches in under the plain's cut edge, so a grazing view
	// through a river never finds a gap below the bank (the earth banks, BANK_FS, are not ported)
	if (sd < -3.2 * mix(inland_depth, sea_depth, w.a) && uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) discard;
	float d = max(sd, 0.0);
	vec2 flow = (w.gb * 255.0 - 128.0) / 127.0;
	float sea = w.a;
	float spd = clamp(length(flow) * 1.4 - 0.4, 0.0, 1.0) * (1.0 - smoothstep(0.2, 0.6, sea));
	float lake = (1.0 - sea) * (1.0 - spd);
	float px = max(fwidth(d), 1e-3), dist = length(cam - v_wp);
	float k = 1.0 - exp(-d * mix(mix(1.0 / 46.0, 1.0 / 18.0, spd), 1.0 / 150.0, sea));
	float q = k * steps + (fbm3(xz * 0.0045 + TIME * 0.006) - 0.5) * 0.4;
	float qs = (floor(q) + smoothstep(0.42, 0.58, fract(q))) / steps;
	vec3 col = mix(mix(water_light, water_mid, smoothstep(0.0, 0.55, qs)), water_deep, smoothstep(0.5, 1.0, qs));
	float motion = mix(mix(0.35, 0.6, spd), sea_motion, sea);
	vec2 wd = normalize(vec2(0.9, 0.25));
	vec4 o = ocean(xz, mix(0.5, 1.3, sea) * waves, mix(0.11, 0.065, sea), 0.55 * motion, 0.95, wd);
	vec2 sl = o.xy * mix(1.0, 0.2, smoothstep(1800.0, 4500.0, cam.y));
	vec3 N = normalize(vec3(-sl.x, 1.0, -sl.y)), V = normalize(cam - v_wp);
	float F = 0.02 + 0.98 * pow(1.0 - max(dot(N, V), 0.0), 5.0);
	col = mix(col, sky, clamp(F * 2.6, 0.0, 0.16));
	col *= 1.0 + clamp(dot(sl, -normalize(sun_dir.xz)), -0.3, 0.3) * 0.16;
	float det_fade = exp(-dist / max(cam.y * 1.6, 1.0));
	col += vec3(0.98, 0.97, 0.92) * smoothstep(0.996, 0.9995, dot(N, normalize(V + sun_dir))) * 0.42 * (sea + 0.45 * lake) * det_fade;
	// white caps on the open sea where the waves fold (Jacobian < threshold)
	col = mix(col, vec3(0.95, 0.96, 0.93), smoothstep(0.55, 0.2, o.z) * sea * 0.35 * det_fade);
	// ink ripple lines running along the shores (L5669–5696)
	float sp = mix(mix(15.0, 12.0, spd), 18.0, sea);
	float ph = d / sp + TIME * mix(0.06, 0.24, sea) * motion * (1.0 - spd);
	float ld = min(fract(ph), 1.0 - fract(ph)) * sp;
	float line_k = 1.0 - smoothstep(px * 0.55, px * 1.55, ld);
	float band = mix(smoothstep(40.0, 4.0, d), 1.0, spd);
	vec2 drift = flow * flow_k * 26.0 + wd * mix(3.0, 9.0, sea);
	float T = 3.0, p1 = fract(TIME / T), p2 = fract(TIME / T + 0.5), ring = floor(ph) * 7.13;
	float n1 = vnoise((xz - drift * p1 * T) * 0.034 + ring), n2 = vnoise((xz - drift * p2 * T) * 0.034 + ring + 3.7);
	float brk = smoothstep(0.36, 0.6, mix(n1, n2, abs(1.0 - 2.0 * p1)));
	float shore_ink = line_k * band * brk * smoothstep(2.5, 5.0, sp / px) * smoothstep(0.0, 1.2, d);
	col = mix(col, line_col, clamp(shore_ink * 0.5 * ripples, 0.0, 1.0));
	// the shoreline itself
	col = mix(col, ink_col, (1.0 - smoothstep(px * 0.6, px * 1.8, d)) * 0.5);
	col = light_on_ground(col, v_wp);
	// the world fades into mist at its edge
	vec2 ed = min(uv, 1.0 - uv) / 0.05;
	col = mix(mist, col, clamp(min(ed.x, ed.y) + (vnoise(xz * 0.0004) - 0.5) * 0.6, 0.0, 1.0));
	col = intro_mix(col, 0.0, 0.1, v_wp, vec2(11027.0, 792.0), 22236.0);
	col = haze_mix(col, v_wp, cam);
	ALBEDO = OUTPUT_IS_SRGB ? (col) : to_linear(col);
}
