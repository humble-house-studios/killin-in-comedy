// Old-TV filter laid over the whole game: scanlines, a little colour fringe,
// a soft vignette, and screen shake on big laughs. Draws on top of everything
// but ignores taps. Written for the Compatibility renderer.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 rect_size = vec2(720.0, 1280.0);
// Screen shake, in viewport units.
uniform vec2 shake = vec2(0.0);

void fragment() {
	vec2 uv = SCREEN_UV + shake / rect_size;
	vec2 fringe = vec2(1.5 / rect_size.x, 0.0);
	vec3 col;
	col.r = texture(screen_tex, uv + fringe).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - fringe).b;
	// Scanlines every 4 viewport units, so they look the same on any screen.
	float y = UV.y * rect_size.y;
	col *= 0.86 + 0.14 * step(1.5, mod(y, 4.0));
	vec2 v = UV - 0.5;
	col *= 1.0 - 0.9 * dot(v, v) * dot(v, v) * 4.0;
	col *= 1.0 + 0.015 * sin(TIME * 60.0);
	COLOR = vec4(col, 1.0);
}
