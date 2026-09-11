extern number time;
extern vec3 bed_color;
extern vec3 spot_color;
extern vec3 water_color;
extern vec3 deep_color;
extern number bed_exposure;
extern number water_sheen;
extern Image flow_tex;

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

	// Live flow from the field canvas: heading and relative speed drive
	// the ripple, caustics, and the wake tint.
	vec4 flow = texture2D(flow_tex, uv);
	vec2 fdir = flow.xy * 2.0 - 1.0;
	float fspeed = clamp(flow.b, 0.0, 1.0);
	vec2 flowDir = length(fdir) > 0.01 ? normalize(fdir) : vec2(0.0, 1.0);
	float flong = dot(uv, flowDir);
	float fcross = dot(uv, vec2(-flowDir.y, flowDir.x));

	// Ripple advected downstream at the local current, strained across
	// the flow so streaks read as lanes around the wakes.
	vec2 dir = vec2(flong * 11.0 - time * (0.3 + 2.2 * fspeed), fcross * 2.2 + flong * 0.9);
	float ripple = noise(dir);
	float spec = pow(clamp(ripple, 0.0, 1.0), 26.0);

	// Body of water: palette-driven, deep water falling toward the deep
	// colour and slightly lighter on the shallow shelves. Never grey.
	float dcol = clamp(depth * 0.78, 0.0, 1.0);
	vec3 water = mix(water_color, deep_color, dcol);
	water = mix(water, color.rgb, 0.35);

	// Slow lanes behind rocks read slightly darker: a wake tint.
	float wake = clamp(1.0 - fspeed * 1.5, 0.0, 0.5);
	water *= 1.0 - 0.10 * wake;

	// Moving caustic light: bands of lighter water that ride downstream,
	// brightest over the shallows and tied to the current.
	float caustic = fbm(vec2(flong * 9.0 - time * (0.5 + 1.9 * fspeed), fcross * 5.0 + flong));
	water += vec3(0.62, 0.78, 0.86) * caustic * water_sheen * 0.10 * (0.35 + 0.65 * (1.0 - depth));

	// Bed detail: soft fbm grain tinted toward the spot colour. The
	// contrast stays low so patches read as gravel, not hard blobs.
	float grain = fbm(vec2(along * 6.0, across * 3.0));
	vec3 bed = mix(bed_color, spot_color, clamp(grain * 1.3 - 0.10, 0.0, 1.0) * 0.42);

	// Bed exposure: strongest at the shallowest water, fading quickly
	// with depth, scaled by the debug exposure knob.
	float patch = 0.55 + 0.60 * fbm(vec2(along * 3.6, across * 2.1) + 2.3);
	float reveal = exp(-depth * 4.6) * patch * bed_exposure;
	vec3 c = mix(water, bed, clamp(reveal, 0.0, 0.55));

	// Height sheen: a faint lightening band on the shallow shelves.
	float shelf = clamp((1.0 - depth) * 2.0, 0.0, 1.0) * (0.5 + 0.5 * fbm(vec2(along * 8.0, across * 4.0)));
	c += vec3(0.22, 0.28, 0.30) * shelf * 0.06;

	// Surface sparkle: few, bright, sitting on the fast shallow lanes.
	c += spec * (0.03 + 0.04 * fspeed) * depth * vec3(0.75, 0.85, 0.90);
	return vec4(c, 1.0);
}