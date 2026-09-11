extern number time;
extern number speed;
extern vec3 foam;

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
	vec2 dir = vec2(along * 11.0 - time * speed, across * 2.4);
	float n1 = noise(dir);
	float n2 = noise(dir * vec2(1.8, 1.15) + vec2(2.1, 0.4));
	float n3 = noise(dir * vec2(0.45, 0.8) + vec2(time * 0.05, 3.0));
	vec3 c = color.rgb * (0.93 + 0.07 * n3);
	float spec = pow(clamp(n1 * 0.55 + n2 * 0.45, 0.0, 1.0), 22.0) * 0.07;
	c += spec * vec3(0.78, 0.84, 0.80);
	float rim = min(across, 1.0 - across);
	float foam_n = noise(vec2(along * 18.0 - time * speed * 0.4, across * 6.0));
	float edge = smoothstep(0.0, 0.07 + 0.06 * foam_n, rim);
	c = mix(mix(foam, c, 0.55 + 0.45 * foam_n), c, edge);
	return vec4(c, 1.0);
}
