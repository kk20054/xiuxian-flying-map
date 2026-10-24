// Shared pieces of every world shader — a port of the demo's GLSL_NOISE (L491–499), GLSL_LIGHT (L4277–4307),
// hazeMix (L4321–4335) and the intro reveal (L4255–4276). All colour maths happens on display-space (sRGB) values,
// exactly as the demo does (its ShaderMaterials write gl_FragColor raw); `to_linear()` at the very end hands Godot a
// linear value so its output transform gives the same display colour back (keep the Environment's tonemap on Linear).

global uniform float map_k;          // 0 sandbox … 1 舆图: flattens the world (y *= 1 − map_k) and fades the 3D away
global uniform float ink_reveal;     // intro: ink lines spread (uInk)
global uniform float wash_reveal;    // intro: colour washes in (uWash)
global uniform float cloud_in;       // intro: clouds and post fade in (uCloudIn)
global uniform vec3 sun_dir;         // toward the sun (azimuth 140° clockwise from north, elevation 40°)
global uniform vec4 toon;            // flat tones: shadow, half, sun multipliers, cast-shadow strength
global uniform vec3 shade_tint;      // cool shadows
global uniform vec3 lit_tint;        // warm light
global uniform vec3 ink_col;
global uniform vec3 haze_col;
global uniform vec3 haze_warm;
global uniform float haze_k;
global uniform float valley_k;
global uniform float alt_k;          // smoothstep(zoom.mid, zoom.high, altitude)
global uniform float cine_k;
global uniform float relief;
global uniform vec4 world_rect;      // x0, z0, width, depth (丈)
global uniform vec4 height_rect;     // the height texture's own rect (texel centres on grid points)
global uniform vec4 light_pos;       // the 遁光: xyz, w = shown
global uniform vec3 glow_col;
global uniform sampler2D t_height : filter_linear, repeat_disable;       // R = height (丈), half float
global uniform sampler2D t_height_blur : filter_linear, repeat_disable;  // R = height blurred over ~200 丈
global uniform sampler2D t_water : filter_linear, repeat_disable;        // R shore distance (128 = shore, 2 丈/step), GB flow, A sea
global uniform sampler2D t_mcolor : filter_linear, repeat_disable;       // the mountains' 青绿 ramp (rgb), a = mountain tile
global uniform sampler2D t_ground : filter_linear, repeat_disable;       // R woods, G fields, B bare ground, A lie of the fields
global uniform sampler2D t_sun : filter_linear, repeat_disable;          // R ground shadow, G cloud-sea shadow, B sky openness

float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec2 hash22(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973)); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.xx + p3.yz) * p3.zy); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}
float fbm3(vec2 p) { float s = 0.5 * vnoise(p); p = p * 2.03 + 17.1; s += 0.25 * vnoise(p); p = p * 2.01 + 5.3; s += 0.125 * vnoise(p); return s / 0.875; }

vec2 world_uv(vec2 xz) { return (xz - world_rect.xy) / world_rect.zw; }
vec2 height_uv(vec2 xz) { return (xz - height_rect.xy) / height_rect.zw; }
float height_at(vec2 xz) { return max(texture(t_height, height_uv(xz)).r, 0.0); }
float height_lod(vec2 xz) { return max(textureLod(t_height, height_uv(xz), 0.0).r, 0.0); }
vec3 sun_at(vec2 xz) { return texture(t_sun, height_uv(xz)).rgb; }
// shore distance in 丈 (+ in water) and the sea factor, from the demo's packed water texture
vec2 water_at(vec2 xz) { vec4 w = texture(t_water, world_uv(xz)); return vec2((w.r * 255.0 - 128.0) * 2.0, w.a); }

// three flat tones from a facet normal: 0 shadow, 0.5 half-lit, 1 sun
float tones(vec3 N) { float nl = dot(N, sun_dir); return mix(0.0, mix(0.5, 1.0, smoothstep(0.5, 0.56, nl)), smoothstep(0.1, 0.16, nl)); }
// the same on a smooth surface, edges washed soft (没骨 rather than 界画)
float soft_tones(float nl) { return mix(0.0, mix(0.5, 1.0, smoothstep(0.4, 0.66, nl)), smoothstep(0.0, 0.26, nl)); }
float cast_light(float s) { return mix(1.0, smoothstep(0.36, 0.64, s), toon.w); }
vec3 tone_col(vec3 base, float t) {
	vec3 sh = base * toon.x * shade_tint, mid = base * toon.y, lit = base * toon.z * lit_tint;
	return t < 0.5 ? mix(sh, mid, t * 2.0) : mix(mid, lit, t * 2.0 - 1.0);
}
vec3 ao_mul(vec3 c, float sky) { return c * mix(1.0, mix(0.84, 1.0, sky), 0.5); }

// 披麻/斧劈 dry strokes along the fall line (cun, L4528)
float cun(vec3 wp, vec3 N) {
	vec2 dh = N.xz; float sl = length(dh); if (sl < 0.12) return 0.0;
	dh /= sl; vec2 tg = vec2(-dh.y, dh.x);
	vec2 p = vec2(dot(wp.xz, tg) * 0.085, (wp.y + dot(wp.xz, dh) * 0.35) * 0.015);
	float n = vnoise(p) * 0.62 + vnoise(p * vec2(2.6, 1.9) + 5.3) * 0.38;
	return smoothstep(0.56, 0.84, n) * smoothstep(0.12, 0.45, sl) * (1.0 - smoothstep(0.3, 0.8, fwidth(p.x)));
}

// distance haze scaled by the camera's height, plus a milky valley fog that thickens as you climb (hazeMix L4321)
vec3 haze_mix(vec3 c, vec3 wp, vec3 cam) {
	float d = length(wp - cam);
	float k = smoothstep(cam.y * 1.2, cam.y * 3.4, d) * haze_k * 0.62 * (1.0 + 0.8 * alt_k);
	float low = exp(-max(wp.y, 0.0) / (240.0 + 160.0 * alt_k));
	float v = valley_k * low * smoothstep(cam.y * 0.4, cam.y * 2.4, d) * (0.3 + 0.7 * alt_k);
	k = 1.0 - (1.0 - k) * (1.0 - v * 0.6);
	return mix(c, mix(haze_col, haze_warm, cine_k), clamp(k, 0.0, 1.0));
}

// the 遁光's jade glow and its ink shadow on the ground under it (lightOnGround L4337)
vec3 light_on_ground(vec3 c, vec3 wp) {
	if (light_pos.w < 0.01) return c;
	float hgt = max(1.0, light_pos.y - wp.y);
	float sy = max(sun_dir.y, 0.3);
	vec2 sp = light_pos.xz - sun_dir.xz / sy * hgt * 0.45;
	float rs = (26.0 + 0.08 * hgt) * 1.4;
	float sh = exp(-pow(length(wp.xz - sp) / rs, 2.0)) * 0.32 * 0.55 * (1.0 - 0.5 * smoothstep(200.0, 1400.0, hgt));
	float rg = 60.0 + 0.22 * hgt;
	float gl = exp(-pow(length(wp.xz - (light_pos.xz + vec2(0.0, 0.1 * hgt))) / rg, 2.0)) * 0.07 * light_pos.w;
	return mix(c, ink_col, sh) + glow_col * gl;
}

// intro 先勾后染: ink first on paper, then the colour washes in from the middle outwards (simplified introMix L4255)
const vec3 PAPER = vec3(0.925, 0.905, 0.85);
vec3 intro_mix(vec3 c, float line, float tone, vec3 wp, vec2 focus, float scale) {
	if (wash_reveal >= 0.999) return c;
	float r = length(wp.xz - focus) / scale + (fbm3(wp.xz * 0.00035) - 0.5) * 0.35;
	float inkR = smoothstep(r - 0.05, r + 0.02, ink_reveal * 1.25);
	float toneR = smoothstep(r - 0.05, r + 0.02, ink_reveal * 1.25 - 0.18);
	vec3 sketch = mix(PAPER, ink_col, max(line * inkR, tone * toneR));
	float prog = wash_reveal * 1.35 - r * 0.6;
	float wet = exp(-pow((prog - 0.0) / 0.035, 2.0));
	float w = smoothstep(-0.02, 0.06, prog);
	return mix(sketch, c, w) * (1.0 - wet * 0.12);
}

// Forward+/Mobile convert linear → sRGB at the output, the Compatibility renderer does not (OUTPUT_IS_SRGB): every
// shader ends with  ALBEDO = OUTPUT_IS_SRGB ? col : to_linear(col);  so both renderers show the demo's colours.
vec3 to_linear(vec3 c) { c = max(c, vec3(0.0)); return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
