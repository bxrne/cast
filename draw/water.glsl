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

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
	float along = uv.x;
	float across = uv.y;
	float depth = color.a;
	vec2 dir = vec2(along * 11.0 - time * speed, across * 2.4);
	float n1 = noise(dir);
	float n2 = noise(vec2(along * 3.2, across * 6.5) + 2.7);
	float n3 = noise(vec2(along * 7.0, across * 4.0) + 1.1);
	vec3 water = color.rgb * (0.94 + 0.06 * n1);
	vec3 bed = mix(bed_color, spot_color, smoothstep(0.35, 0.75, n2));
	float reveal = (1.0 - depth) * (0.20 + 0.80 * smoothstep(0.38, 0.82, n3));
	vec3 c = mix(water, bed, clamp(reveal, 0.0, 0.72));
	float spec = pow(clamp(n1, 0.0, 1.0), 28.0) * 0.05 * depth;
	c += spec * vec3(0.70, 0.82, 0.88);
	return vec4(c, 1.0);
}
