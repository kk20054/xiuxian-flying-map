// The screen pass (demo 09 tilt-shift L13017–13024 + GRADE L13066–13091, and the page's CSS overlays: the silk paper
// multiply and the vignette, L21–22 / L14960): one ColorRect over the 3D view, under the UI.
//   tilt-shift: rows within `band` of the focus row stay sharp, blur ramps in beyond (here from the screen texture's mips)
//   grade: S-curve, cool shadows, warm highlights, saturation, vignette — strength rises with altitude
//   silk: faint warp/weft threads, fibres and stains, multiplied in (look.paper)
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float tilt = 0.32;          // k (updatePost): 0.82 low … 0.32 cruise … 0.06 high
uniform float focus = 0.5;          // focus row (0 top … 1 bottom), pulled toward the light
uniform float band = 0.225;
uniform float grade = 0.12;
uniform float contrast = 0.5;
uniform vec3 shadow_tint = vec3(0.9, 0.95, 1.04);
uniform vec3 high_tint = vec3(1.05, 1.0, 0.93);
uniform float sat = 1.12;
uniform float vig = 0.35;           // cinema.vignette
uniform float paper = 0.24;         // look.paper (× (1 − 0.4·map_k))
uniform float css_vignette = 0.38;  // look.vignette (× (1 − map_k))

float h12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1, 0)), u.x), mix(h12(i + vec2(0, 1)), h12(i + vec2(1, 1)), u.x), u.y); }
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float dy = max(abs(focus - uv.y) - band, 0.0);
	float blur = tilt * smoothstep(0.0, 0.5, dy) * 0.5;
	float lod = clamp(blur * 9.0, 0.0, 4.5);
	vec3 c = textureLod(screen, uv, lod).rgb;
	// grade
	float l = luma(c);
	vec3 s = c * c * (3.0 - 2.0 * c);
	vec3 g = mix(c, s, contrast * grade);
	g = mix(g, g * shadow_tint, (1.0 - smoothstep(0.05, 0.6, l)) * 0.6 * grade);
	g = mix(g, g * high_tint, smoothstep(0.4, 0.95, l) * 0.7 * grade);
	g = mix(vec3(luma(g)), g, 1.0 + (sat - 1.0) * grade);
	vec2 sz = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = sz.x / sz.y;
	vec2 q = (uv - 0.5) * vec2(aspect, 1.0) / vec2(max(aspect, 1.0));
	g *= 1.0 - vig * grade * smoothstep(0.3, 0.9, length(q) * 1.6);
	// CSS vignette: radial-gradient(125% 100% at 50% 46%, transparent 56%, rgba(70,62,44,.42) 100%)
	vec2 p = (uv - vec2(0.5, 0.46)) / vec2(1.25, 1.0) * 2.0;
	float r = length(p) / length(vec2(0.5 / 1.25, 0.54) * 2.0);
	g = mix(g, vec3(70.0, 62.0, 44.0) / 255.0, smoothstep(0.56, 1.0, r) * 0.42 * css_vignette);
	// silk: threads every other pixel row/column, fibres, stains — multiplied
	vec2 px = FRAGCOORD.xy;
	float weft = mod(floor(px.y), 2.0) * mix(0.03, 0.08, h12(vec2(floor(px.y), 3.0)));
	float warp = mod(floor(px.x), 2.0) * mix(0.02, 0.06, h12(vec2(floor(px.x), 7.0)));
	float fib = smoothstep(0.82, 0.9, vn(px * vec2(0.02, 0.35))) * 0.1;
	float stain = smoothstep(0.55, 0.85, vn(px / 180.0 + 4.0)) * 0.07;
	vec3 silk = vec3(1.0) - (vec3(1.0) - vec3(120.0, 96.0, 60.0) / 255.0) * (weft + warp + fib + stain);   // rgba(120,96,60,a) over white
	g *= mix(vec3(1.0), silk, paper / 0.26);
	COLOR = vec4(g, 1.0);
}
