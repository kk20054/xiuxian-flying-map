// The sects' 13.3-丈 detail patches (World.t_patch_h, one layer per patch; texel (i, j) = patch vertex (i, j)). Their GLB
// ground meshes exist only where a patch cell has relief (meshGrid L4900: a cell is built when any corner has H > 0).
uniform sampler2DArray t_patch_h : filter_linear, repeat_disable;
uniform vec4 patches[6];              // the patch rects (x0, z0, x1, z1)
uniform int patch_count = 0;
uniform float patch_cell = 13.333333;

// the patch containing xz (inset by `inset` 丈), or −1
int patch_at(vec2 xz, float inset) {
	for (int i = 0; i < patch_count; i++) {
		vec4 p = patches[i];
		if (xz.x > p.x + inset && xz.x < p.z - inset && xz.y > p.y + inset && xz.y < p.w - inset) return i;
	}
	return -1;
}

// patch i's fine height at xz (bilinear between its vertices; ≤ 0 on the plain round its hills)
float patch_h(vec2 xz, int i) {
	vec2 f = (xz - patches[i].xy) / patch_cell + 0.5;
	return textureLod(t_patch_h, vec3(f / vec2(textureSize(t_patch_h, 0).xy), float(i)), 0.0).r;
}
