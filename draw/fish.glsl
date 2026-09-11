extern vec3 dorsal;
extern vec3 belly;
extern vec3 stripe;
extern vec3 deep;
extern number sink;
extern number flash;
extern vec2 center;
extern number angle;
extern number half_h;

// Countershaded flank. Spine shows the dorsal tone, edges fall
// to the pale belly, stripe marks the lateral line. Flash adds
// a silver wash tied to behaviour. Love color carries vis.
// Screen space equals world space here, so no vertex stage.
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
	vec2 d = screen - center;
	float c = cos(-angle);
	float s = sin(-angle);
	vec2 local = vec2(d.x * c - d.y * s, d.x * s + d.y * c);
	float v = clamp(abs(local.y) / max(half_h, 0.5), 0.0, 1.0);
	vec3 col = mix(dorsal, belly, smoothstep(0.05, 0.9, v));
	float lat = 1.0 - smoothstep(0.0, 0.22, abs(v - 0.45));
	col = mix(col, stripe, lat * 0.55);
	col = mix(col, deep, clamp(sink, 0.0, 1.0));
	col += vec3(0.85, 0.92, 0.95) * clamp(flash, 0.0, 1.0);
	return vec4(col, color.a);
}
