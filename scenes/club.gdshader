// Whole-screen backdrop: a dim club wall with warm light near the top,
// drawn in chunky 8-bit pixels with ordered dithering.
// Written for the Compatibility renderer.
shader_type canvas_item;

uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform float pixel = 8.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 4x4 Bayer matrix, 0..1.
float bayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }

void fragment() {
	vec2 cell = floor(UV * rect_size / pixel);
	vec2 px = cell * pixel;
	vec2 uv = px / rect_size;
	vec2 b = px / vec2(64.0, 32.0);
	b.x += mod(floor(b.y), 2.0) * 0.5;
	vec2 f = fract(b);
	float inside = step(0.2, f.y) * step(0.1, f.x);
	vec3 brick = vec3(0.20, 0.08, 0.14) * (0.8 + 0.3 * step(0.5, hash(floor(b))));
	vec3 col = mix(vec3(0.05, 0.03, 0.08), brick, inside);
	float glow = (1.0 - uv.y) * (1.0 - 0.8 * pow(length(uv - vec2(0.5, 0.4)), 2.0));
	// Dithered light bands instead of a smooth gradient.
	float band = floor(glow * 4.0 + bayer4(cell)) / 4.0;
	col += vec3(0.12, 0.04, 0.12) * band;
	col *= 0.55 + 0.45 * band;
	COLOR = vec4(col, 1.0);
}
