// The blurred heights (the demo's tLand.g, buildLandTextures L5397–5399): an 11 × 11 box over max(0, h) on the 40-丈
// grid, the sects' patch heights and the 天柱山 pillar included (L5393–5396). Drawn once into an HDR SubViewport the size
// of the grid (one pixel per grid point) and read back into t_height_blur.
shader_type canvas_item;

uniform sampler2D heights : filter_nearest, repeat_disable;
uniform vec2 grid0;                // world x, z of grid point (0, 0)
uniform float cell = 40.0;
global uniform vec4 pillar;        // 天柱山: x, z, h, r (r = 0: none)

// pillarH (L5395): the pillar's column, (h + 120) inside 0.8 r, gone by 1.2 r
float pillar_h(vec2 xz, float v) {
	float d = length(xz - pillar.xy);
	return d < pillar.w * 1.2 ? max(v, (pillar.z + 120.0) * (1.0 - smoothstep(pillar.w * 0.8, pillar.w * 1.2, d))) : v;
}

void fragment() {
	ivec2 n = textureSize(heights, 0);
	ivec2 c = ivec2(UV * vec2(n));
	bool near_pillar = pillar.w > 0.0 && length(grid0 + vec2(c) * cell - pillar.xy) < pillar.w * 1.2 + 8.0 * cell;
	float acc = 0.0;
	for (int j = -5; j <= 5; j++) {
		for (int i = -5; i <= 5; i++) {
			ivec2 q = clamp(c + ivec2(i, j), ivec2(0), n - 1);
			float v = max(texelFetch(heights, q, 0).r, 0.0);
			if (near_pillar) v = pillar_h(grid0 + vec2(q) * cell, v);
			acc += v;
		}
	}
	COLOR = vec4(acc / 121.0, 0.0, 0.0, 1.0);
}
