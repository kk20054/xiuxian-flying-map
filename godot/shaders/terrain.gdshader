// The ground: mountains and plains in one pass (the demo splits them into TERRAIN_VS/FS L4678–4791 and PLAINS_VS/FS
// L5155–5270). A flat grid chunk is displaced from the height texture; colour = the demo's own mountain ramp (t_mcolor,
// read back from its terrain tiles) over a painted plain; light = three flat tones blended toward the smooth normal,
// cast shadow + valley AO from the sun bake; ink on crests (height Laplacian) and at the foot of the slopes.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_opaque;

#include "res://shaders/land_common.gdshaderinc"
#include "res://shaders/patch_common.gdshaderinc"
#include "res://shaders/ground_common.gdshaderinc"

uniform float soft_k = 0.85;          // terrain.soft
uniform float foot_ink = 0.8;         // terrain.footInk
uniform float ridge_light = 1.0;      // terrain.ridgeLight
uniform float cun_k = 1.0;            // terrain.cun
uniform vec2 intro_focus = vec2(11027.0, 792.0);
uniform float intro_scale = 22236.0;
// the plain's painted colours (PLAINS_FS uniforms, L5281)
uniform vec3 c_plains = vec3(0.714, 0.741, 0.6);        // #b6bd99
uniform vec3 c_plains_green = vec3(0.616, 0.69, 0.541); // #9db08a
uniform vec3 c_field = vec3(0.725, 0.706, 0.561);       // #b9b48f
uniform vec3 c_yard = vec3(0.827, 0.78, 0.659);         // #d3c7a8
uniform vec3 c_rice = vec3(0.51, 0.682, 0.345);         // #82ae58
uniform vec3 c_wheat = vec3(0.784, 0.71, 0.369);        // #c8b55e

varying vec3 v_wp;
varying float v_skirt;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// the plain stays at y = 0 (PLAINS_VS): the water is cut out of it per pixel below; UV2.x = 1 on the skirt, which hangs
	// 70 丈 so a coarser neighbour never opens a crack
	wp.y = height_lod(wp.xz) * relief - UV2.x * 70.0;
	v_skirt = UV2.x;
	wp.y *= 1.0 - map_k;
	v_wp = wp;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}

// a re-sculpted terrain's rock map (tools/terrain: World --terrain=…): 8-bit rock id per height sample
global uniform sampler2D t_litho : filter_nearest, repeat_disable;
global uniform bool litho_on;

// bare-rock colour per id (alluvium, loess, metamorphic, granite, quartz sandstone, red beds, limestone, volcanic,
// lacustrine) and how strongly it shows where the rock is bare; display-space, muted for the 青绿 palette
vec4 rock_col(int id) {
	if (id == 1) return vec4(0.78, 0.68, 0.5, 0.75);
	if (id == 3) return vec4(0.76, 0.76, 0.74, 0.8);
	if (id == 4) return vec4(0.7, 0.65, 0.55, 0.75);
	if (id == 5) return vec4(0.71, 0.4, 0.3, 0.85);
	if (id == 6) return vec4(0.62, 0.67, 0.66, 0.65);
	if (id == 7) return vec4(0.43, 0.41, 0.43, 0.7);
	return vec4(0.0);
}

void fragment() {
	vec3 wp = v_wp;
	// a sect's patch GLB draws its ground wherever the patch has relief; the plain round its hills is still ours, and
	// inside a patch only the plain (the demo skips the coarse cells there, buildMountains L5146)
	int ip = patch_at(wp.xz, 20.0);
	if (ip >= 0 && patch_h(wp.xz, ip) > 0.25) discard;
	vec2 xz = wp.xz;
	float h = ip >= 0 ? 0.0 : height_at(xz);
	// the plain is cut away wherever there is water, per pixel (PLAINS_FS L5172): the sunken water shows through
	vec2 wsd = water_at(xz);
	if (h <= 0.0 && wsd.x > 0.0) discard;
	float hb = texture(t_height_blur, height_uv(xz)).r;
	// smooth normal from the height texture (central differences over one 40-丈 cell)
	float e = 40.0;
	float hx = height_at(xz + vec2(e, 0)) - height_at(xz - vec2(e, 0));
	float hz = height_at(xz + vec2(0, e)) - height_at(xz - vec2(0, e));
	vec3 Ns = normalize(vec3(-hx * relief, 2.0 * e, -hz * relief));
	vec3 Nf = normalize(cross(dFdx(wp), dFdy(wp)));
	if (dot(Nf, Ns) < 0.0) Nf = -Nf;
	float px = length(fwidth(wp.xz));
	float small = smoothstep(16.0, 40.0, px);
	float soft = max(soft_k, small);
	vec3 N = normalize(mix(Nf, Ns, soft));
	vec3 s = sun_at(xz);
	float t = min(mix(tones(Nf), soft_tones(dot(N, sun_dir)), soft), cast_light(s.r));

	// colour: the painted plain, then the mountains' 青绿 ramp where they rise
	vec4 gr = texture(t_ground, world_uv(xz));
	float mott = fbm3(xz * 0.00048);
	vec3 plain = mix(c_plains, c_plains_green, 0.7 * mott);
	plain = mix(plain, mix(c_rice, c_wheat, step(0.5, fract(gr.a * 3.7))), gr.g * 0.45);
	plain = mix(plain, c_field, gr.g * 0.25);
	plain = mix(plain, c_yard, gr.b * 0.6);
	vec4 mc = texture(t_mcolor, height_uv(xz));
	// a sculpted plain has relief (fans, terraces, low mesas to ~30 丈): it keeps its fields and woods, the ramp starts above
	float mk = (litho_on ? smoothstep(24.0, 48.0, h) : smoothstep(1.0, 14.0, h)) * step(0.5, mc.a);
	// a wood on a gentle slope: the canopy's green under the trees (TERRAIN_FS L4717)
	float wn = vnoise(xz / 36.0) - 0.5;
	float wood_m = smoothstep(0.06, 0.5, gr.r + wn * 0.24) * smoothstep(0.55, 0.8, Ns.y) * (1.0 - smoothstep(380.0, 470.0, wp.y));
	vec3 base = mix(plain, mix(mc.rgb, wood_col(xz), wood_m * 0.8), mk);
	base = biome_ground(base, wp, Ns, wood_m * mk);
	// the plain: the biome's grass first, then the woods laid over it (PLAINS_FS L5194, L5230)
	float wood_p = smoothstep(0.04, 0.42, gr.r + wn * 0.26);
	base = mix(base, wood_col(xz), wood_p * 0.92 * (1.0 - mk));
	base = season_ground(base, wp, Ns);
	if (litho_on) {
		// where the slope is too steep for soil the rock shows its own colour (Ns is smoothed over 80 丈, so a one-cell
		// cliff reads ~40°); red beds and loess colour their own soil, so they show through on gentle ground too — in the
		// fields, not under the woods (a red-bed basin is green farmland and forest between red cliffs, not a desert)
		int id = int(texture(t_litho, height_uv(xz)).r * 255.0 + 0.5);
		vec4 rc = rock_col(id);
		// red beds in patches (ploughed fields of 紫色土 among green ones: an even wash would read khaki), loess all over
		float red_soil = 0.55 * smoothstep(0.45, 0.8, vnoise(xz / 260.0 + vec2(3.1, 7.7)));
		float floor_k = (id == 5 ? red_soil : (id == 1 ? 0.45 : 0.0)) * (1.0 - 0.85 * max(wood_p * (1.0 - mk), wood_m * mk));
		float bare = max(smoothstep(0.93, 0.7, Ns.y), floor_k) * smoothstep(2.0, 20.0, h);
		base = mix(base, rc.rgb * (0.92 + 0.16 * mott), rc.a * bare);
	}

	vec3 col;
	// a sculpted plain has relief (fans, terraces, low mesas to ~30 丈): lit as the plain where level, shaded on its slopes
	float plain_k = 1.0 - (litho_on ? smoothstep(24.0, 48.0, h) : smoothstep(4.0, 30.0, h));
	if (litho_on) plain_k *= smoothstep(0.86, 0.97, Ns.y);
	vec3 lit = ao_mul(tone_col(base, t), s.b) + vec3(0.016, 0.02, 0.018) * N.y;
	lit /= mix(1.0, max(toon.z * 0.96, 0.5), 1.0 - smoothstep(40.0, 420.0, wp.y));   // the low foot lit as the plain (L4760–4763)
	// flat ground takes the lit tone it faces up into, the ranges' shadows fall across it (PLAINS_FS L5257–5258)
	float tp = tones(vec3(0.0, 1.0, 0.0)) * mix(0.25, 1.0, cast_light(s.r));
	vec3 flat_c = tone_col(base, tp) * mix(1.0, mix(0.9, 1.0, s.b), 0.5) / max(toon.z * 0.96, 0.5);
	col = mix(lit, flat_c, plain_k);
	col *= 1.0 - cun(wp, Ns) * (0.17 - 0.11 * t) * cun_k * (1.0 - plain_k);
	col *= mix(vec3(1.0), vec3(0.88, 0.96, 0.86), alt_k * 0.55);   // the land cools and deepens as you climb

	// ridges: lit crests brighten, shaded crests take ink (Laplacian of the height, 64-丈 stencil — L4766)
	float st = 64.0;
	float lap = height_at(xz + vec2(st, 0)) + height_at(xz - vec2(st, 0)) + height_at(xz + vec2(0, st)) + height_at(xz - vec2(0, st)) - 4.0 * h;
	float crest = smoothstep(12.0, 38.0, -lap) * smoothstep(40.0, 150.0, h) * (1.0 - smoothstep(60.0, 140.0, px));
	col = mix(col, col * 1.1 + vec3(0.035, 0.03, 0.02), crest * smoothstep(0.45, 0.8, t) * 0.55 * ridge_light);
	col = mix(col, mix(col, ink_col, 0.35), crest * (1.0 - smoothstep(0.2, 0.55, t)) * 0.5 * ridge_light);
	// foot ink where the slope meets the plain (L4774)
	float fy = max(fwidth(wp.y), 1e-3);
	float foot = (1.0 - smoothstep(fy * 0.9, fy * 2.4, wp.y)) * foot_ink * step(-0.2, wp.y) * smoothstep(40.0, 110.0, hb);
	col = mix(col, ink_col, foot * 0.82);
	// the ink line of the plain's cut edge (PLAINS_FS L5250, L5263)
	float spx = max(fwidth(wsd.x), 0.05);
	col = mix(col, ink_col, (1.0 - smoothstep(spx * 0.8, spx * 2.2, -wsd.x)) * 0.75 * plain_k * step(wsd.x, 0.0));
	col *= 1.0 - v_skirt * 0.2;

	col = light_on_ground(col, wp);
	col = intro_mix(col, max(crest, foot), (1.0 - t) * 0.32 + 0.06, wp, intro_focus, intro_scale);
	col = haze_mix(col, wp, CAMERA_POSITION_WORLD);
	ALBEDO = OUTPUT_IS_SRGB ? (col) : to_linear(col);
}
