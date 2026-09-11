extern number time;
extern number speed;
extern vec3 bed_color;
extern vec3 spot_color;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

// Fractal noise: a few octaves give smooth, low-contrast detail.
float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.13 + 1.7) * 0.30 + noise(p * 4.37 + 4.1) * 0.15;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
	float along = uv.x;
	float across = uv.y;
	float depth = color.a; // 0 shallow (bed close) .. 1 deep
	vec2 dir = vec2(along * 11.0 - time * speed, across * 2.4);
	float ripple = noise(dir);
	float spec = pow(clamp(ripple, 0.0, 1.0), 26.0);

	// Surface tint stays calm and bluish over the vertex colour.
	vec3 water = mix(color.rgb, vec3(0.55, 0.72, 0.78), 0.30);

	// Bed detail: soft fbm grain tinted toward the spot colour. The
	// contrast stays low so patches read as gravel, not hard blobs.
	float grain = fbm(vec2(along * 6.0, across * 3.0));
	vec3 bed = mix(bed_color, spot_color, clamp(grain * 1.3 - 0.10, 0.0, 1.0) * 0.42);

	// Bed exposure: strongest at the shallowest water, fading quickly
	// with depth, with a gentle scrambled patch so edges never ring.
	float patch = 0.55 + 0.60 * fbm(vec2(along * 3.6, across * 2.1) + 2.3);
	float reveal = exp(-depth * 4.6) * patch;
	vec3 c = mix(water, bed, clamp(reveal, 0.0, 0.46));

	// Height sheen: a faint lightening band on the shallow shelves.
	float shelf = clamp((1.0 - depth) * 2.0, 0.0, 1.0) * (0.5 + 0.5 * fbm(vec2(along * 8.0, across * 4.0)));
	c += vec3(0.22, 0.28, 0.30) * shelf * 0.06;

	c += spec * 0.05 * depth * vec3(0.70, 0.82, 0.88);
	return vec4(c, 1.0);
}