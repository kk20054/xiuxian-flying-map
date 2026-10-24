// The sun bake (demo SUN_BAKE_FS L5478–5500), drawn once into a SubViewport over the height grid:
// R = ground cast shadow (march toward the sun over the heightfield), G = the same at the cloud sea's height (peak shadows
// on the sea), B = sky openness (how far the ground round about rises above this point → valleys darker).
shader_type canvas_item;

uniform sampler2D heights : filter_linear, repeat_disable;
uniform vec4 rect;                 // the height texture's rect: x0, z0, width, depth
uniform vec3 sun = vec3(0.413, 0.643, 0.493);
uniform float cloud_y = 175.0;
uniform vec4 sites[6];             // x, z, R, the sect's cloud-sea top above cloud_y
uniform float relief = 1.0;
global uniform vec4 pillar;        // 天柱山 (x, z, h, r): in the demo's tLand (L5395), so it casts its long shadow

float H(vec2 xz) {
	float v = max(texture(heights, (xz - rect.xy) / rect.zw).r, 0.0);
	float d = length(xz - pillar.xy);
	if (d < pillar.w * 1.2) v = max(v, (pillar.z + 120.0) * (1.0 - smoothstep(pillar.w * 0.8, pillar.w * 1.2, d)));
	return v * relief;
}

void fragment() {
	vec2 xz = rect.xy + UV * rect.zw;
	float h0 = H(xz), cy = cloud_y;
	for (int i = 0; i < 6; i++) cy = max(cy, cloud_y + sites[i].w * (1.0 - smoothstep(sites[i].z * 0.7, sites[i].z * 1.08, length(xz - sites[i].xy))));
	vec2 d = normalize(sun.xz);
	float tan_e = sun.y / max(length(sun.xz), 1e-3);
	float s0 = 1.0, s1 = 1.0, t = 20.0, st = 20.0;
	for (int i = 0; i < 120; i++) {
		float hp = H(xz + d * t), pen = t * 0.03 + 5.0;
		s0 = min(s0, clamp((h0 + 4.0 + t * tan_e - hp) / pen + 0.5, 0.0, 1.0));
		s1 = min(s1, clamp((max(h0, cy) + t * tan_e - hp) / pen + 0.5, 0.0, 1.0));
		t += st; st *= 1.028;
		if (min(h0 + 4.0, cy) + t * tan_e > 1800.0) break;
	}
	float occ = 0.0;
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398 + 0.3;
		vec2 dd = vec2(cos(a), sin(a));
		for (int r = 1; r <= 3; r++) { float rr = float(r) * 140.0; occ += clamp((H(xz + dd * rr) - h0) / rr, 0.0, 1.2); }
	}
	COLOR = vec4(s0, s1, clamp(1.0 - occ / 24.0, 0.0, 1.0), 1.0);
}
