// The painted 舆图 (demo §10 MAP_FS, L13149–13249): one big plane over the flattened world, painted from the same
// heights and water the sandbox uses. Silk; water with 鱼鳞纹 wave scales; the plain with 点苔 dots for woods; mist at
// the mountain feet; the ranges in two flat tones with hatching on the shaded flanks and an ink terminator line; an ink
// shore; the roads/villages/cities overlay; and an "ink-seep" reveal — the map appears in patches as map_k rises.
shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

#include "res://shaders/land_common.gdshaderinc"

uniform sampler2D t_over : filter_linear_mipmap, repeat_disable;    // roads, villages, cities (map_overlay.gd)
uniform float ready_k = 1.0;
uniform float cell = 40.0;

varying vec2 v_p;

void vertex() {
	v_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hs_at(vec2 xz) { return mix(height_at(xz), texture(t_height_blur, height_uv(xz)).r, 0.45); }

void fragment() {
	vec2 P = v_p;
	vec2 wuv = world_uv(P);
	bool inside = wuv.x >= 0.0 && wuv.x <= 1.0 && wuv.y >= 0.0 && wuv.y <= 1.0;
	vec2 qx = clamp(wuv, 0.0, 1.0) * world_rect.zw + world_rect.xy;
	vec3 ink = vec3(0.2, 0.22, 0.25);
	// 1 · silk
	float mott = 0.6 * fbm3(P * 0.00021 + 3.0) + 0.4 * fbm3(P * 0.0011 + 9.0);
	vec3 silk = mix(vec3(0.9, 0.85, 0.72), vec3(0.84, 0.78, 0.63), smoothstep(0.35, 0.75, mott));
	vec2 ed = min(wuv, 1.0 - wuv);
	silk *= 1.0 - 0.1 * (1.0 - smoothstep(0.0, 0.18, min(ed.x, ed.y) + (vnoise(P * 0.0007) - 0.5) * 0.05));
	vec3 c = silk;
	if (inside) {
		float h = height_at(qx);
		vec4 wt = texture(t_water, wuv);
		float sd = (wt.r * 255.0 - 128.0) * 2.0, sea = wt.a;
		vec4 gr = texture(t_ground, wuv);
		// 2 · water
		float water = smoothstep(-4.0, 4.0, sd);
		float deep = smoothstep(20.0, 320.0, sd) * (0.4 + 0.6 * sea);
		vec3 wcol = mix(vec3(0.64, 0.73, 0.70), vec3(0.42, 0.56, 0.60), deep);
		wcol = mix(wcol, vec3(0.6, 0.72, 0.73), (1.0 - sea) * 0.5);
		// 3 · 鱼鳞纹 wave scales on the sea
		vec2 sq = P / 130.0;
		sq.x += mod(floor(sq.y), 2.0) * 0.5;
		vec2 fq = fract(sq);
		float arc = abs(length((fq - vec2(0.5, 0.0)) * vec2(1.0, 1.4)) - 0.46);
		float fw = max(fwidth(arc), 1e-4);
		float scales = (1.0 - smoothstep(fw * 0.6, fw * 1.6, arc)) * step(0.0, fq.y) * (1.0 - smoothstep(0.08, 0.2, fwidth(sq.x)));
		wcol = mix(wcol, ink, scales * 0.22 * smoothstep(40.0, 160.0, sd) * sea);
		wcol = mix(wcol, vec3(0.9, 0.93, 0.9), 0.25 * (1.0 - smoothstep(0.0, 40.0, sd)) * sea);
		// 4 · the plain, fields, 点苔 woods
		vec3 plain = mix(vec3(0.84, 0.80, 0.63), vec3(0.76, 0.76, 0.58), 0.7 * fbm3(P * 0.00048));
		plain = mix(plain, plain * vec3(0.92, 1.0, 0.86), gr.g * 0.6);
		plain = mix(plain, vec3(0.5, 0.6, 0.47), gr.r * 0.32);
		vec2 dc = P / 46.0, di = floor(dc), dfp = fract(dc) - 0.5 - (hash22(di) - 0.5) * 0.5;
		float dr = 0.16 + 0.06 * hash12(di + 3.1);
		float dot_k = (1.0 - smoothstep(dr - fwidth(dc.x), dr + fwidth(dc.x), length(dfp))) * step(hash12(di + 7.7), 0.25 + 0.6 * gr.r) * step(0.1, gr.r);
		dot_k *= 1.0 - smoothstep(0.5, 1.2, fwidth(dc.x));
		plain = mix(plain, vec3(0.3, 0.42, 0.34), dot_k * 0.75);
		// 5 · painted mist round the mountain feet
		float hb = texture(t_height_blur, height_uv(qx)).r;
		vec2 warp = vec2(fbm3(P * 0.0003), fbm3(P * 0.0003 + 5.2));
		float cf = 0.7 * fbm3(P * 0.0006 + warp * 2.0) + 0.45 * smoothstep(2.0, 70.0, hb);
		// 6 · the ranges: two flat tones, hatching in shade, an ink terminator
		float hs = hs_at(qx);
		float stp = cell * 2.2;
		float dx = hs_at(qx + vec2(stp, 0)) - hs_at(qx - vec2(stp, 0));
		float dz = hs_at(qx + vec2(0, stp)) - hs_at(qx - vec2(0, stp));
		vec3 N = normalize(vec3(-dx / (cell * 4.4), 1.0, -dz / (cell * 4.4)));
		vec3 Ld = normalize(vec3(-0.6, 0.5, -0.6));
		float tone = dot(N, Ld);
		float tw = max(1.5 * fwidth(tone), 0.03);
		float lit = smoothstep(0.5 - tw, 0.5 + tw, tone);
		float hk = clamp((hs - 120.0) / 320.0, 0.0, 1.0);
		vec3 rc = mix(vec3(0.46, 0.64, 0.52), vec3(0.26, 0.46, 0.56), hk);
		rc = mix(vec3(0.66, 0.58, 0.44), rc, smoothstep(3.0, 50.0, hs));
		rc = mix(rc, vec3(0.88, 0.92, 0.92), 0.5 * smoothstep(600.0, 850.0, hs));
		rc *= mix(vec3(0.74, 0.77, 0.82), vec3(1.12, 1.1, 1.02), lit);
		vec2 gdir = normalize(vec2(dx, dz) + vec2(1e-4));
		float s_along = dot(P, vec2(-gdir.y, gdir.x));
		float spacing = max(6.0 * fwidth(s_along), 2.0);
		float hatch = (1.0 - smoothstep(0.15, 0.35, abs(fract(s_along / spacing) - 0.5) * 2.0)) * (1.0 - lit) * smoothstep(10.0, 50.0, h);
		hatch *= step(0.45, vnoise(P * 0.01));
		rc = mix(rc, ink, hatch * 0.5);
		rc = mix(rc, ink, (1.0 - smoothstep(0.0, 2.2 * tw, abs(tone - 0.5))) * 0.6 * smoothstep(12.0, 60.0, h));
		float range_k = smoothstep(2.0, 8.0, h);
		vec3 land = mix(plain, rc, range_k);
		land = mix(land, ink, 0.55 * (1.0 - abs(2.0 * range_k - 1.0)) * step(0.05, range_k) * step(range_k, 0.95));
		float mist_k = smoothstep(0.56, 0.7, cf) * (1.0 - water);
		land = mix(land, vec3(0.93, 0.91, 0.84), 0.6 * mist_k);
		land = mix(land, vec3(0.58, 0.62, 0.64), 0.3 * (1.0 - smoothstep(0.0, 0.02, abs(cf - 0.57))) * (1.0 - water));
		// 7 · water over land, an ink shore line
		c = mix(land, wcol, water);
		float spx = max(fwidth(sd), 1e-3);
		c = mix(c, ink, 0.6 * (1.0 - smoothstep(0.0, 1.8, abs(sd) / spx)));
		// 8 · roads, villages, cities
		vec4 ov = texture(t_over, wuv);
		c = mix(c, ov.rgb, ov.a);
		c = mix(silk, c, ready_k);
	} else {
		c *= 0.97;
	}
	// 9 · silk weave, blotches, a warm wash at the frame's edge
	float fib = vnoise(P * vec2(0.36, 0.016)) * 0.5 + vnoise(P * vec2(0.016, 0.36)) * 0.5;
	c *= 0.97 + 0.05 * fib;
	c *= 1.0 - 0.05 * smoothstep(0.6, 0.8, fbm3(P * 0.00012 + 11.0));
	c = mix(c, c * vec3(1.0, 0.95, 0.86), 0.35 * (1.0 - smoothstep(0.0, 0.3, min(ed.x, ed.y))) * float(inside));
	// 10 · ink-seep reveal
	float sn = 0.75 * fbm3(P * 0.00018 + 2.3) + 0.25 * vnoise(P * 0.0016);
	float a = smoothstep(sn - 0.14, sn + 0.06, map_k * 1.3 - 0.15);
	if (a < 0.003) discard;
	ALBEDO = OUTPUT_IS_SRGB ? (c) : to_linear(c);
	ALPHA = a;
}
