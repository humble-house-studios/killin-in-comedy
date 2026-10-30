// Whole-screen backdrop: a dim club wall with warm light near the top.
// Written for the Compatibility renderer.
shader_type canvas_item;

uniform vec2 rect_size = vec2(720.0, 1280.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 b = px / vec2(64.0, 28.0);
	b.x += mod(floor(b.y), 2.0) * 0.5;
	vec2 f = fract(b);
	float inside = step(0.08, f.y) * step(0.04, f.x);
	vec3 brick = vec3(0.16, 0.07, 0.07) * (0.7 + 0.4 * hash(floor(b)));
	vec3 col = mix(vec3(0.04, 0.03, 0.04), brick, inside);
	col += vec3(0.10, 0.05, 0.08) * (1.0 - UV.y);
	col *= 1.0 - 0.6 * pow(length(UV - vec2(0.5, 0.4)), 2.0);
	COLOR = vec4(col, 1.0);
}
