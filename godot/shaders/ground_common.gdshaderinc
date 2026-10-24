// The painted ground shared by the ranges (terrain.gdshader) and the sects' fine ground (facet.gdshader, `ground`):
// woodCol (L4309), seasonGround (L4381) and biomeGround (L4398) of the demo's GLSL_LIGHT. Include after land_common.
uniform sampler2D t_bweights : filter_linear, repeat_disable;   // R flowers, G sand, B marsh, A lushness (biome_weights.png)
uniform sampler2D t_season : filter_linear, repeat_disable;     // R winter, G autumn, B spirit land, A dry steppe (season.png)
uniform sampler2D t_drift : filter_linear, repeat_disable;      // rgb the dominant flower, a the drift (flower_drift.png)
uniform bool biome_on = false;
uniform vec4 regions[3];              // uReg: 古剑门, 落云宗, 百巧院 — x, z, r0, r1 (frosty, jade, red-and-gold woods)

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

// the woods seen from above: a dark green mottled like crowns, frosty round 古剑门 and in the winter country, red and gold
// round 百巧院 and in the autumn country, a breath of jade round 落云宗 (woodCol L4309)
vec3 wood_col(vec2 xz) {
	float cr = vnoise(xz / 11.0) * 0.6 + vnoise(xz / 4.7 + 3.3) * 0.4;
	vec3 c = mix(vec3(0.2, 0.34, 0.19), vec3(0.3, 0.45, 0.24), smoothstep(0.35, 0.75, cr));
	float kg = 1.0 - smoothstep(regions[0].z, regions[0].w, length(xz - regions[0].xy));
	float kl = 1.0 - smoothstep(regions[1].z, regions[1].w, length(xz - regions[1].xy));
	float kb = 1.0 - smoothstep(regions[2].z, regions[2].w, length(xz - regions[2].xy));
	if (biome_on) { vec4 se = texture(t_season, world_uv(xz)); kg = max(kg, se.r); kb = max(kb, se.g); }
	c = mix(c, mix(vec3(0.5, 0.58, 0.6), vec3(0.72, 0.78, 0.8), cr), kg * 0.65);
	c = mix(c, mix(vec3(0.56, 0.34, 0.24), vec3(0.74, 0.55, 0.3), cr), kb * 0.75);
	c = mix(c, mix(vec3(0.38, 0.55, 0.4), vec3(0.52, 0.68, 0.5), cr), kl * 0.5);
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
