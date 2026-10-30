// The comedy club stage in 8-bit pixels: brick wall, red curtains with a
// scalloped valance, wooden floor and a dithered spotlight.
// Written for the Compatibility renderer.
shader_type canvas_item;

uniform vec2 rect_size = vec2(680.0, 600.0);
// 0 = cold crowd (dim, blue light), 0.5 = normal, 1 = hot (bright, warm).
uniform float heat : hint_range(0.0, 1.0) = 0.5;
uniform float floor_y = 0.80;
// Size of one "pixel", in viewport units. Matches StageView.PIXEL.
uniform float pixel = 6.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }

vec3 bricks(vec2 px) {
	vec2 b = px / vec2(48.0, 24.0);
	b.x += mod(floor(b.y), 2.0) * 0.5;
	vec2 f = fract(b);
	float inside = step(0.25, f.y) * step(0.125, f.x);
	vec3 brick = vec3(0.45, 0.16, 0.14) * (0.8 + 0.25 * step(0.5, hash(floor(b))));
	// Light top edge on each brick, like hand-placed pixels.
	brick += vec3(0.08, 0.04, 0.03) * step(f.y, 0.5) * inside;
	return mix(vec3(0.09, 0.05, 0.09), brick, inside);
}

void fragment() {
	vec2 cell = floor(UV * rect_size / pixel);
	vec2 px = (cell + 0.5) * pixel;
	vec2 uv = px / rect_size;
	float dither = bayer4(cell);
	vec3 col = bricks(px);

	if (uv.y > floor_y) {
		float depth = (uv.y - floor_y) / (1.0 - floor_y);
		float plank = floor(px.x / 72.0);
		col = vec3(0.42, 0.24, 0.12) * (0.85 + 0.2 * step(0.5, hash(vec2(plank, 7.0))));
		col *= step(0.09, fract(px.x / 72.0));
		col *= floor((0.55 + 0.6 * depth) * 3.0 + dither) / 3.0;
		col = mix(col, vec3(0.75, 0.5, 0.25), step(abs(uv.y - floor_y), pixel / rect_size.y));
	}

	// Spotlight: a cone from above onto a pool around the mic, in dithered steps.
	vec3 cold_light = vec3(0.45, 0.6, 1.0);
	vec3 warm_light = vec3(1.0, 0.85, 0.45);
	vec3 light = mix(cold_light, warm_light, step(0.4, heat));
	float strength = mix(0.45, 1.25, heat);
	float h = clamp(uv.y / floor_y, 0.0, 1.0);
	float spread = mix(0.07, 0.25, h);
	float cone = smoothstep(spread, spread * 0.55, abs(uv.x - 0.5)) * (0.35 + 0.65 * h);
	cone *= step(uv.y, floor_y + 0.02);
	vec2 d = (px - vec2(0.5, floor_y) * rect_size) / vec2(rect_size.x * 0.27, rect_size.x * 0.075);
	float pool = smoothstep(1.0, 0.2, length(d));
	float lit = clamp(cone * 0.55 + pool, 0.0, 1.0) * strength;
	lit = floor(lit * 4.0 + dither) / 4.0;
	col = col * (0.3 + 0.9 * lit) + light * lit * 0.16;

	// Curtains, tied back so they widen toward the floor.
	float edge = min(uv.x, 1.0 - uv.x);
	float width = 0.07 + 0.08 * smoothstep(0.15, 1.0, uv.y);
	if (edge < width) {
		float fold = floor((0.5 + 0.5 * sin(px.x * 0.22 + uv.y * 1.5)) * 3.0 + dither) / 3.0;
		col = vec3(0.62, 0.06, 0.16) * (0.45 + 0.55 * fold);
		col = mix(col, vec3(0.95, 0.3, 0.35), step(width - pixel / rect_size.x, edge) * 0.6);
	}
	// Valance across the top with a gold trim.
	float scallop = 0.075 + 0.022 * abs(sin(uv.x * 3.14159 * 6.0));
	if (uv.y < scallop) {
		float fold = step(0.5, fract(px.x / 36.0));
		col = vec3(0.55, 0.05, 0.14) * (0.75 + 0.25 * fold);
	}
	col = mix(col, vec3(1.0, 0.78, 0.25), step(abs(uv.y - scallop), pixel / rect_size.y));

	// Chunky frame: dark outline with a gold inner line.
	vec2 cells = floor(rect_size / pixel);
	float ring = min(min(cell.x, cells.x - 1.0 - cell.x), min(cell.y, cells.y - 1.0 - cell.y));
	if (ring < 1.0) {
		col = vec3(0.04, 0.02, 0.06);
	} else if (ring < 2.0) {
		col = vec3(0.85, 0.6, 0.2);
	}
	COLOR = vec4(col, 1.0);
}
