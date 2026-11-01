// Drawn over an arcade machine's 3D view: film grain, scanlines, a vignette
// and a colour cast. Doesn't read the screen, so it's cheap on every renderer.
shader_type canvas_item;

uniform float grain = 0.06;
uniform float vignette = 0.5;
uniform float scan = 0.08;
uniform vec4 tint = vec4(0.0);
uniform vec2 px = vec2(240.0, 280.0);
uniform float flicker = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * px);
	float n = hash(cell + floor(TIME * 18.0) * vec2(13.1, 7.7));
	float v = smoothstep(0.3, 0.85, length(UV - 0.5) * 1.3) * vignette;
	float s = scan * step(0.5, fract(UV.y * px.y * 0.5));
	float f = flicker * step(0.93, hash(vec2(floor(TIME * 12.0), 3.0))) * 0.5;
	float dark = clamp(v + s + f, 0.0, 1.0);
	float a = clamp(dark + grain + tint.a, 0.001, 1.0);
	vec3 rgb = (vec3(n) * grain + tint.rgb * tint.a) / a;
	COLOR = vec4(rgb, a);
}
