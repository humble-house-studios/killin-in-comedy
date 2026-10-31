// The game, shown on an office CRT. The crisp copy (screen pass) fades in
// as you walk up so the cards stay readable; the chunky copy sits in the world
// and gets the CRT treatment (soft scanlines, darker corners, a glass sheen).
// UVs are never bent, so taps still land exactly where they look.
shader_type spatial;
render_mode unshaded, cull_back, blend_mix;

uniform sampler2D game : source_color, filter_linear;
uniform float fade = 1.0;
uniform float glass = 0.06;
// 0 = clean (crisp copy), 1 = full CRT look (world copy).
uniform float crt = 0.0;
uniform float lines = 240.0;

void fragment() {
	vec3 col = texture(game, UV).rgb;
	vec2 v = UV - 0.5;
	// A little glass sheen in the top corner.
	col += glass * smoothstep(0.35, 0.0, length(v - vec2(-0.3, -0.35)));
	// Scanlines and a soft tube vignette, only as strong as `crt`.
	float scan = 0.9 + 0.1 * sin(UV.y * lines * 6.2832);
	float vig = 1.0 - 0.35 * dot(v * 1.6, v * 1.6);
	col *= mix(1.0, scan * vig, crt);
	col = mix(col, col * 1.08 + vec3(0.02, 0.015, 0.0), crt);
	ALBEDO = col;
	ALPHA = fade;
}
