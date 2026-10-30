// The comedy club stage: brick wall, red curtains with a scalloped valance,
// wooden floor and a spotlight. Written for the Compatibility renderer.
shader_type canvas_item;

uniform vec2 rect_size = vec2(680.0, 600.0);
// 0 = cold crowd (dim, blue light), 0.5 = normal, 1 = hot (bright, warm).
uniform float heat : hint_range(0.0, 1.0) = 0.5;
uniform float corner_radius = 18.0;
uniform float floor_y = 0.80;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 bricks(vec2 px) {
	vec2 b = px / vec2(54.0, 24.0);
	float row = floor(b.y);
	b.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(b);
	vec2 f = fract(b);
	float inside = step(0.08, f.y) * step(0.04, f.x);
	vec3 brick = vec3(0.40, 0.15, 0.11) * (0.7 + 0.4 * hash(cell));
	return mix(vec3(0.08, 0.06, 0.07), brick, inside);
}

void fragment() {
	vec2 uv = UV;
	vec2 px = UV * rect_size;
	vec3 col = bricks(px);

	if (uv.y > floor_y) {
		float depth = (uv.y - floor_y) / (1.0 - floor_y);
		float plank = floor(px.x / 70.0);
		col = vec3(0.36, 0.21, 0.11) * (0.8 + 0.25 * hash(vec2(plank, 7.0)));
		col *= step(0.04, fract(px.x / 70.0)) * (0.55 + 0.6 * depth);
		col += vec3(0.25, 0.18, 0.1) * smoothstep(0.02, 0.0, abs(uv.y - floor_y - 0.005));
	}

	// Spotlight: a cone from above onto a pool around the mic.
	vec3 cold_light = vec3(0.55, 0.68, 1.0);
	vec3 warm_light = vec3(1.0, 0.82, 0.52);
	vec3 light = mix(cold_light, warm_light, smoothstep(0.2, 0.6, heat));
	float strength = mix(0.45, 1.25, heat);
	float h = clamp(uv.y / floor_y, 0.0, 1.0);
	float spread = mix(0.07, 0.25, h);
	float cone = smoothstep(spread, spread * 0.55, abs(uv.x - 0.5)) * (0.35 + 0.65 * h);
	cone *= step(uv.y, floor_y + 0.02);
	vec2 d = (px - vec2(0.5, floor_y) * rect_size) / vec2(rect_size.x * 0.27, rect_size.x * 0.075);
	float pool = smoothstep(1.0, 0.2, length(d));
	float lit = clamp(cone * 0.55 + pool, 0.0, 1.0) * strength;
	col = col * (0.32 + 0.9 * lit) + light * (cone * 0.10 + pool * 0.18) * strength;

	// Curtains, tied back so they widen toward the floor.
	float edge = min(uv.x, 1.0 - uv.x);
	float width = 0.07 + 0.08 * smoothstep(0.15, 1.0, uv.y);
	if (edge < width) {
		float fold = 0.45 + 0.55 * pow(abs(sin(px.x * 0.22 + uv.y * 1.5)), 0.6);
		col = vec3(0.55, 0.04, 0.09) * fold * (0.55 + 0.45 * edge / width);
		col += vec3(0.25, 0.02, 0.04) * smoothstep(width - 0.01, width, edge);
	}
	// Valance across the top with a gold trim.
	float scallop = 0.075 + 0.022 * abs(sin(uv.x * 3.14159 * 6.0));
	if (uv.y < scallop) {
		float fold = 0.55 + 0.45 * abs(sin(px.x * 0.12));
		col = vec3(0.50, 0.03, 0.08) * fold;
	}
	col = mix(col, vec3(0.85, 0.65, 0.25), smoothstep(0.006, 0.0, abs(uv.y - scallop)) * 0.9);

	col *= 1.0 - 0.45 * pow(length(uv - vec2(0.5, 0.55)), 2.0);

	vec2 q = abs(px - rect_size * 0.5) - (rect_size * 0.5 - corner_radius);
	float dist = length(max(q, 0.0)) - corner_radius;
	COLOR = vec4(col, clamp(0.5 - dist, 0.0, 1.0));
}
