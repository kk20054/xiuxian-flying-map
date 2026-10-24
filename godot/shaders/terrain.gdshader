// The ground: mountains and plains in one pass (the demo splits them into TERRAIN_VS/FS L4678–4791 and PLAINS_VS/FS
// L5155–5270). A flat grid chunk is displaced from the height texture; colour = the demo's own mountain ramp (t_mcolor,
// read back from its terrain tiles) over a painted plain; light = three flat tones blended toward the smooth normal,
// cast shadow + valley AO from the sun bake; ink on crests (height Laplacian) and at the foot of the slopes.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_opaque;

#include "res://shaders/land_common.gdshaderinc"

uniform float soft_k = 0.85;          // terrain.soft
uniform float foot_ink = 0.8;         // terrain.footInk
uniform float ridge_light = 1.0;      // terrain.ridgeLight
uniform float cun_k = 1.0;            // terrain.cun
uniform float sea_floor = 26.0;       // the ground dives this far under the water
uniform vec4 patches[6];              // the six sects' detail rects (x0, z0, x1, z1): their GLB ground meshes draw there
uniform int patch_count = 0;
uniform vec2 intro_focus = vec2(11027.0, 792.0);
uniform float intro_scale = 22236.0;
// the plain's painted colours (PLAINS_FS uniforms, L5281)
uniform vec3 c_plains = vec3(0.714, 0.741, 0.6);        // #b6bd99
uniform vec3 c_plains_green = vec3(0.616, 0.69, 0.541); // #9db08a
uniform vec3 c_field = vec3(0.725, 0.706, 0.561);       // #b9b48f
uniform vec3 c_wood = vec3(0.42, 0.55, 0.43);
uniform vec3 c_yard = vec3(0.827, 0.78, 0.659);         // #d3c7a8
uniform vec3 c_rice = vec3(0.51, 0.682, 0.345);         // #82ae58
uniform vec3 c_wheat = vec3(0.784, 0.71, 0.369);        // #c8b55e

uniform sampler2D t_bweights : filter_linear, repeat_disable;   // R flowers, G sand, B marsh, A lushness (biome_weights.png)
uniform sampler2D t_season : filter_linear, repeat_disable;     // R winter, G autumn, B spirit land, A dry steppe (season.png)
uniform sampler2D t_drift : filter_linear, repeat_disable;      // rgb the dominant flower, a the drift (flower_drift.png)
uniform bool biome_on = false;

varying vec3 v_wp;
varying float v_skirt;

// the ground's painted colour: meadow greens on the flats and low slopes, sunnier over flower fields, dry gold in the
// autumn country, faded under winter snow, straw in the steppe, sand by the water, dark mud in the marsh — large soft
// gradients, never noise (biomeGround L4398, "the way a Ghibli background or a Meadow scene paints its ground")
vec3 biome_ground(vec3 base, vec3 wp, vec3 Ns, float wood) {
	if (!biome_on) return base;
	vec2 uv = world_uv(wp.xz);
	vec4 b = texture(t_bweights, uv);
	vec4 se = texture(t_season, uv);
	float flat_k = smoothstep(0.6, 0.86, Ns.y), veg = flat_k * (1.0 - smoothstep(300.0, 470.0, wp.y));
	float n1 = fbm3(wp.xz * 0.00031 + 7.1), n2 = fbm3(wp.xz * 0.0013 - 2.3), n3 = vnoise(wp.xz * 0.011);
	vec3 g_light = vec3(0.5, 0.64, 0.25), g_mid = vec3(0.36, 0.55, 0.21), g_deep = vec3(0.25, 0.45, 0.22);
	float nm = fbm3(wp.xz * 0.0019 + 3.3);
	vec3 grass = mix(g_mid, g_light, smoothstep(0.3, 0.75, n1 * 0.6 + nm * 0.4));
	grass = mix(grass, g_deep, clamp(b.a * 0.75 + (0.5 - n2) * 0.3, 0.0, 0.85));
	grass *= 0.96 + 0.08 * n3;
	grass = mix(grass, grass * vec3(1.06, 1.05, 0.92) + vec3(0.035, 0.03, 0.0), b.r * 0.55);
	vec3 dry = mix(vec3(0.6, 0.56, 0.29), vec3(0.72, 0.62, 0.33), n1);
	grass = mix(grass, mix(dry, mix(dry, vec3(0.45, 0.5, 0.26), 0.5), b.a * 0.6), smoothstep(0.15, 0.8, se.g) * 0.58);
	vec4 fw = texture(t_drift, uv);
	grass = mix(grass, fw.rgb * 0.85, b.r * smoothstep(0.3, 0.7, fw.a) * 0.12);
	grass = mix(grass, vec3(0.55, 0.58, 0.52) * (0.95 + 0.1 * n1), smoothstep(0.2, 0.8, se.r) * 0.55);
	float ard = smoothstep(0.25, 0.75, se.a + (n2 - 0.5) * 0.25);
	vec3 steppe = mix(vec3(0.66, 0.6, 0.36), vec3(0.77, 0.7, 0.52), smoothstep(0.35, 0.7, n2 * 0.6 + n3 * 0.4));
	grass = mix(grass, mix(steppe, vec3(0.5, 0.52, 0.3), b.a * 0.5), ard * 0.9);
	vec3 c = mix(base, grass, veg * (1.0 - wood) * 0.88);
	c = mix(c, mix(vec3(0.84, 0.77, 0.6), vec3(0.74, 0.68, 0.56), n3), b.g * flat_k * 0.85);
	c = mix(c, mix(vec3(0.32, 0.31, 0.19), vec3(0.26, 0.36, 0.2), smoothstep(0.35, 0.65, n2)), b.b * 0.88);
	return c;
}

// the season on the ground (seasonGround L4381): snow lying on the flats of the winter country in drifts with bare
// patches, thinning on slopes, none on the steep; the bare ground between the drifts cold; tawny grass in the autumn
vec3 season_ground(vec3 base, vec3 wp, vec3 Ns) {
	if (!biome_on) return base;
	vec4 se = texture(t_season, world_uv(wp.xz));
	if (se.r + se.g < 0.004) return base;
	float flat_k = smoothstep(0.8, 0.97, Ns.y), br = vnoise(wp.xz / 60.0) * 0.55 + vnoise(wp.xz / 17.0 + 2.7) * 0.45;
	float snow = smoothstep(0.45, 0.85, se.r * 1.15 - 0.3 + (br - 0.5) * 0.95) * flat_k * smoothstep(-2.0, 16.0, wp.y);
	base = mix(base, vec3(0.88, 0.91, 0.93) * (0.95 + 0.07 * br), snow * 0.58);
	base = mix(base, base * vec3(0.9, 0.95, 1.02) + vec3(0.025, 0.03, 0.035), se.r * (1.0 - snow) * 0.18);
	float aut = se.g * smoothstep(0.45, 0.8, Ns.y) * (1.0 - snow) * 0.25;
	return mix(base, base * vec3(1.1, 0.98, 0.76) + vec3(0.03, 0.015, 0.0), aut * 0.42);
}

float ground_y(vec2 xz) {
	float h = height_lod(xz) * relief;
	if (h <= 0.0) {
		vec4 w = textureLod(t_water, world_uv(xz), 0.0);
		float sd = (w.r * 255.0 - 128.0) * 2.0;
		h = -sea_floor * smoothstep(-6.0, 14.0, sd);        // plain → under the water (the demo cuts holes and drops earth banks)
	}
	return h;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wp.y = ground_y(wp.xz) - UV2.x * 70.0;                 // UV2.x = 1 on the skirt: hangs 70 丈 so a coarser neighbour never opens a crack
	v_skirt = UV2.x;
	wp.y *= 1.0 - map_k;
	v_wp = wp;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}

void fragment() {
	vec3 wp = v_wp;
	for (int i = 0; i < patch_count; i++) {
		vec4 p = patches[i];
		if (wp.x > p.x + 20.0 && wp.x < p.z - 20.0 && wp.z > p.y + 20.0 && wp.z < p.w - 20.0) discard;
	}
	vec2 xz = wp.xz;
	float h = height_at(xz);
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
	plain = mix(plain, c_wood, gr.r * 0.55);
	plain = mix(plain, c_yard, gr.b * 0.6);
	vec4 mc = texture(t_mcolor, height_uv(xz));
	float mk = smoothstep(1.0, 14.0, h) * step(0.5, mc.a);
	vec3 base = mix(plain, mc.rgb, mk);
	base = biome_ground(base, wp, Ns, gr.r * 0.6);
	base = season_ground(base, wp, Ns);

	vec3 col;
	float plain_k = 1.0 - smoothstep(4.0, 30.0, h);
	vec3 lit = ao_mul(tone_col(base, t), s.b) + vec3(0.016, 0.02, 0.018) * N.y;
	// flat lit ground keeps its own colour (the demo divides by uToon.z·0.96 for the plain)
	vec3 flat_c = base * mix(0.25, 1.0, cast_light(s.r)) * mix(0.84, 1.0, s.b * 0.5 + 0.5);
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
	// shore ink on the plain's edge
	vec2 wsd = water_at(xz);
	float spx = max(fwidth(wsd.x), 1e-3);
	col = mix(col, ink_col, (1.0 - smoothstep(spx * 0.8, spx * 2.2, abs(wsd.x))) * 0.6 * plain_k);
	col *= 1.0 - v_skirt * 0.2;

	col = light_on_ground(col, wp);
	col = intro_mix(col, max(crest, foot), (1.0 - t) * 0.32 + 0.06, wp, intro_focus, intro_scale);
	col = haze_mix(col, wp, CAMERA_POSITION_WORLD);
	ALBEDO = OUTPUT_IS_SRGB ? (col) : to_linear(col);
}
