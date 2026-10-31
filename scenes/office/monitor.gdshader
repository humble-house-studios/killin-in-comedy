// The game, shown on the office monitor. The crisp copy (screen pass) fades in
// as you walk up so the cards stay readable; the chunky copy sits in the world.
shader_type spatial;
render_mode unshaded, cull_back, blend_mix;

uniform sampler2D game : source_color, filter_linear;
uniform float fade = 1.0;
uniform float glass = 0.06;

void fragment() {
	vec3 col = texture(game, UV).rgb;
	vec2 v = UV - 0.5;
	// A little glass sheen in the top corner.
	col += glass * smoothstep(0.35, 0.0, length(v - vec2(-0.3, -0.35)));
	ALBEDO = col;
	ALPHA = fade;
}
