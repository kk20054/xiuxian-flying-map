// The 遁光's glow quads (demo 08, L12731–12735): camera-facing, a gaussian falloff cut to a disc. Normal blending, not
// additive (additive light vanishes on pale paper), drawn over everything like the demo (depthTest off).
shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

uniform vec3 col = vec3(0.247, 0.851, 0.69);
uniform float fall = 3.2;
uniform float alpha = 0.5;
uniform float size = 90.0;

void vertex() {
	// billboard: keep the centre, spread the corners in view space
	vec4 c = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	c.xy += VERTEX.xy * size;
	POSITION = PROJECTION_MATRIX * c;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	float a = exp(-r2 * fall) * (1.0 - smoothstep(0.8, 1.0, sqrt(r2)));
	ALBEDO = OUTPUT_IS_SRGB ? col : pow(col, vec3(2.2));
	ALPHA = a * alpha;
}
