// The 遁光's tapered trail (demo 08, L12743–12749): a ribbon of 96 sections; UV.x = along (0 head → 1 tail),
// UV.y = side (−1 … 1). Bright core near the head, flowing noise, fading toward the tail.
shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

uniform vec3 core = vec3(0.91, 1.0, 0.965);
uniform vec3 glow = vec3(0.247, 0.851, 0.69);
uniform float alpha = 1.0;

float h12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1, 0)), u.x), mix(h12(i + vec2(0, 1)), h12(i + vec2(1, 1)), u.x), u.y); }

void fragment() {
	float t = UV.x, side = UV.y;
	float s = 1.0 - min(abs(side), 1.0);
	float fade = pow(1.0 - t, 1.7);
	float flow = 0.75 + 0.25 * vn(vec2(t * 22.0 - TIME * 7.0, side * 1.5));
	float inner = pow(s, 7.0) * (1.0 - smoothstep(0.0, 0.5, t));
	vec3 c = mix(mix(core, glow, smoothstep(0.0, 0.3, t)), core, inner);
	ALBEDO = OUTPUT_IS_SRGB ? c : pow(c, vec3(2.2));
	ALPHA = clamp(pow(s, 1.4) * flow * 0.55 + inner * 0.6, 0.0, 1.0) * fade * alpha;
}
