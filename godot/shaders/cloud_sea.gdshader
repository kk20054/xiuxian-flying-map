// 云海 (demo 07c, L12279–12497): a continuous slab of cloud whose top is a mesh; each surface pixel marches down
// through the slab (~9 steps) through a planned 2D density, a vertical profile and a tileable 3D noise, with one tap
// toward the sun for light. The march stops on the terrain, so peaks and floating islands pierce the sea with a soft
// skirt. It opens round the player at low altitude, thins to a veil inside a sect, and fades near the camera.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, blend_mix, depth_draw_never;

#include "res://shaders/land_common.gdshaderinc"

global uniform vec2 wind;
uniform sampler2D dens_tex : filter_linear, repeat_disable;   // the plan (cloud_sea.png), blurred
uniform sampler3D noise3 : filter_linear, repeat_enable;
uniform float top = 175.0;         // cloudSea.height
uniform float amp = 1.0;           // billow
uniform float thick = 150.0;
uniform float dens_k = 1.0;
uniform float alpha_k = 1.0;
uniform int steps = 9;
uniform vec2 part = vec2(0.0);     // the opening round the player (inner, outer radius); off when part.y < 1
uniform vec2 target = vec2(0.0);
uniform vec4 sites[6];             // x, z, R·1.6, the sect's cloud top
uniform vec3 c_lit = vec3(0.992, 0.976, 0.941);    // #fdf9f0
uniform vec3 c_shade = vec3(0.812, 0.847, 0.871);  // #cfd8de
uniform vec3 c_deep = vec3(0.604, 0.667, 0.71);    // #9aaab5

varying vec3 v_wp;
varying float v_top;
varying float v_d;
varying float v_swell;

float swell_h(vec2 p, float t) { vec2 q = p + wind * t * 6.0; return fbm3(q / 1300.0) - 0.5 + (vnoise(q / 520.0 + 4.3) - 0.5) * 0.45; }

float lift_at(vec2 xz) {
	float l = 0.0;
	for (int i = 0; i < 6; i++) {
		float w = 1.0 - smoothstep(sites[i].z * 0.45, sites[i].z * 0.75, length(xz - sites[i].xy));
		l = max(l, (sites[i].w - top) * w);
	}
	return l;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	float d = textureLod(dens_tex, world_uv(wp.xz), 0.0).r;
	float lift = lift_at(wp.xz);
	float sect_k = smoothstep(10.0, 60.0, lift);
	wp.y = top + lift
		+ (d - 0.6) * mix(40.0, 14.0, sect_k) * amp
		+ swell_h(wp.xz, t) * mix(90.0, 26.0, sect_k) * amp * smoothstep(0.0, 0.45, d)
		- (1.0 - smoothstep(0.0, 0.28, d)) * mix(120.0, 40.0, sect_k);
	v_top = wp.y;
	v_d = d;
	vec2 sun_h = normalize(sun_dir.xz + vec2(1e-4));
	v_swell = clamp(1.0 + (swell_h(wp.xz, t) - swell_h(wp.xz + sun_h * 140.0, t)) * 1.8, 0.5, 1.34);
	wp.y *= 1.0 - map_k;
	v_wp = wp;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}

float dens(vec3 p, float tp, vec3 drift) {
	float d = texture(dens_tex, world_uv(p.xz)).r;
	if (d < 0.01) return 0.0;
	vec3 q = p + drift;
	float n = texture(noise3, q / 760.0).r * 0.6 + texture(noise3, q / 230.0 + 0.37).r * 0.4;
	float hgt = (p.y - (tp - thick)) / thick;
	float line = 0.45 + 0.55 * d - (n - 0.5) * 1.3;
	float v = smoothstep(line, line - 0.28, hgt) * smoothstep(-0.05, 0.2, hgt);
	return v * smoothstep(0.03, 0.35, d + (n - 0.5) * 0.4);
}

void fragment() {
	if (map_k > 0.995 || cloud_in < 0.004) discard;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 ro = v_wp, rd = normalize(v_wp - cam);
	float cam_d = length(v_wp - cam);
	float L = min(thick / max(-rd.y, 0.12), thick * 4.0);
	float ds = L / float(steps);
	float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy + vec2(fract(TIME * 0.37) * 13.0, 0.0), vec2(0.06711056, 0.00583715))));
	float sigma = dens_k * 0.045 * alpha_k;
	vec2 suv = world_uv(v_wp.xz);
	vec2 sun_h = normalize(sun_dir.xz + vec2(1e-4));
	float shadow = mix(0.74, 1.0, smoothstep(0.3, 0.7, sun_at(v_wp.xz).g));
	float d_sun = texture(dens_tex, suv + sun_h * 520.0 / world_rect.zw).r;
	shadow *= (1.0 - 0.4 * smoothstep(0.0, 0.3, d_sun - v_d)) * (1.0 + 0.16 * smoothstep(0.0, 0.3, v_d - d_sun)) * v_swell;
	// gates: the opening round the player, a veil inside the sects, thinning near the camera
	float keep = 0.0, veil = 1.0;
	for (int i = 0; i < 6; i++) {
		float ki = 1.0 - smoothstep(sites[i].z * 0.7, sites[i].z, length(v_wp.xz - sites[i].xy));
		keep = max(keep, ki);
		veil = min(veil, mix(1.0, mix(0.45, 1.0, smoothstep(sites[i].w + 120.0, sites[i].w + 380.0, cam.y)), ki));
	}
	float pk = smoothstep(part.x, part.y, length(v_wp.xz - target) + (vnoise(v_wp.xz / 420.0) - 0.5) * 240.0);
	float gate = mix(1.0, mix(pk, mix(veil, 1.0, pk), keep), step(1.0, part.y)) * smoothstep(cam.y * 0.22, cam.y * 0.6, cam_d);
	vec3 drift = vec3(wind.x, 0.0, wind.y) * TIME * 6.0;
	float T = 1.0; vec3 acc = vec3(0.0);
	float p_dn = 0.0, p_air = 0.0; vec3 p_c = vec3(0.0);
	for (int i = 0; i < 24; i++) {
		if (i >= steps) break;
		vec3 p = ro + rd * (ds * (float(i) + jit));
		float g = pillar_h(p.xz, height_at(p.xz)) * relief;   // tLand has the 天柱山 pillar in it (L5395)
		float air = p.y - (g - 1.0);
		if (air < 0.0) {     // in rock: the last step counts only for its fraction in air → a soft skirt on the cliffs
			if (p_dn > 0.0) { float a = 1.0 - exp(-p_dn * sigma * ds * clamp(p_air / max(p_air - air, 1e-3), 0.0, 1.0)); acc += T * a * p_c; T *= 1.0 - a; }
			p_dn = 0.0; break;
		}
		if (p_dn > 0.0) { float a = 1.0 - exp(-p_dn * sigma * ds); acc += T * a * p_c; T *= 1.0 - a; p_dn = 0.0; if (T < 0.015) break; }
		float dn = dens(p, v_top, drift) * gate;
		if (dn < 0.002) continue;
		float occ = dens(p + sun_dir * 95.0, v_top, drift);
		float lt = exp(-occ * 1.6) * shadow;
		float lee = dens(p + vec3(sun_h.x, 0.3, sun_h.y) * 70.0, v_top, drift);
		lt *= 1.0 + 0.55 * clamp((dn - lee) * 2.2, -0.6, 1.0);
		float depth_k = clamp((p.y - (v_top - thick)) / thick, 0.0, 1.0);
		p_c = mix(c_deep, mix(c_shade, c_lit, lt), 0.2 + 0.8 * depth_k * depth_k);
		p_dn = dn; p_air = air;
	}
	if (p_dn > 0.0) { float a = 1.0 - exp(-p_dn * sigma * ds); acc += T * a * p_c; T *= 1.0 - a; }
	float a = (1.0 - T) * cloud_in * (1.0 - map_k);
	if (a < 0.004) discard;
	vec3 col = acc / max(1.0 - T, 1e-3);
	col = mix(col, haze_col, smoothstep(cam.y * 1.2, cam.y * 3.6, cam_d) * haze_k * 0.45);
	ALBEDO = OUTPUT_IS_SRGB ? (col) : to_linear(col);
	ALPHA = a;
}
