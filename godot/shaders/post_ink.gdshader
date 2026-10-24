// Ink edges from depth (demo 09 · INK_EDGE L13025–13047): ~2 px lines drawn only on the near side of a depth step,
// not on the horizon. A full-screen quad in the transparent pass that outputs only ink (ALPHA = edge), drawn before
// the clouds (render_priority −100) so, like the demo's veil, no outlines show through cloud.
shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, skip_vertex_transform;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float strength = 0.7;      // look.edgeInk
uniform vec3 ink = vec3(0.24, 0.27, 0.31);
uniform float cam_far = 100000.0;  // not on the horizon
global uniform float map_k;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float lin(vec2 uv, mat4 ip) {
	float d = texture(depth_tex, uv).r;
	vec4 v = ip * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	if (map_k > 0.99 || strength < 0.01) discard;
	vec2 o = 1.7 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float z = lin(uv, INV_PROJECTION_MATRIX);
	float zl = lin(uv - vec2(o.x, 0), INV_PROJECTION_MATRIX), zr = lin(uv + vec2(o.x, 0), INV_PROJECTION_MATRIX);
	float zd = lin(uv - vec2(0, o.y), INV_PROJECTION_MATRIX), zu = lin(uv + vec2(0, o.y), INV_PROJECTION_MATRIX);
	float far_z = max(max(zl, zr), max(zd, zu));
	float lap = (zl + zr + zd + zu - 4.0 * z) / z;
	float edge = smoothstep(0.012, 0.05, lap) * smoothstep(0.008, 0.03, (far_z - z) / z);
	edge *= 1.0 - smoothstep(cam_far * 0.55, cam_far * 0.9, z);
	ALBEDO = OUTPUT_IS_SRGB ? ink : pow(ink, vec3(2.2));
	ALPHA = clamp(edge * strength * (1.0 - map_k), 0.0, 1.0);
}
