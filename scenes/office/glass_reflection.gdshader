// A CRT's glass reflecting the office (glass_reflection.gd films it with a
// camera mirrored behind the glass). Faint on bright pixels of the room,
// stronger at grazing angles (Fresnel), soft at the edges where a tube's glass
// curves away. The film is mirrored left/right, hence 1 - UV.x.
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never, shadows_disabled;

uniform sampler2D room : source_color, filter_linear;
uniform float strength = 0.0;

void fragment() {
	vec3 refl = texture(room, vec2(1.0 - UV.x, UV.y)).rgb;
	float lum = dot(refl, vec3(0.299, 0.587, 0.114));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float a = strength * (0.3 + 0.7 * smoothstep(0.05, 0.7, lum)) * (1.0 + 2.0 * fres);
	vec2 e = min(UV, 1.0 - UV);
	a *= smoothstep(0.0, 0.05, min(e.x, e.y));
	ALBEDO = refl;
	ALPHA = clamp(a, 0.0, 0.6);
}
