// The arcade machines' little 3D worlds (scenes/ladder/view3d.gd): PS1-ish
// snapped vertices, light worked out per vertex from a few point lights and a
// sun, cheap shine, chunky procedural patterns, fog and an ordered-dither
// palette. Unshaded, so it looks the same on every renderer.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 albedo : source_color = vec3(0.7);
uniform vec3 albedo2 : source_color = vec3(0.5);
// 0 flat, 1 checker, 2 stripes, 3 speckle, 4 tile grid
uniform int pattern = 0;
uniform float texel = 8.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform float shine = 0.0;
uniform vec3 ambient = vec3(0.3);
uniform vec3 sun_dir = vec3(0.3, 1.0, 0.4);
uniform vec3 sun_col = vec3(0.0);
uniform vec3 l_pos[6];
uniform vec3 l_col[6];
uniform float l_range[6];
uniform vec3 fog_col = vec3(0.0);
uniform float fog_near = 4.0;
uniform float fog_far = 20.0;
uniform vec2 snap = vec2(120.0, 140.0);
uniform float levels = 24.0;

varying vec3 light;
varying vec3 glint;
varying float fogv;
varying vec3 lpos;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 eye = normalize(INV_VIEW_MATRIX[3].xyz - wp);
	vec3 sd = normalize(sun_dir);
	vec3 lit = ambient * (0.8 + 0.2 * n.y) + sun_col * max(dot(n, sd), 0.0);
	vec3 g = sun_col * pow(max(dot(n, normalize(sd + eye)), 0.0), 24.0);
	for (int i = 0; i < 6; i++) {
		vec3 d = l_pos[i] - wp;
		float dist = max(length(d), 0.001);
		float att = clamp(1.0 - dist / max(l_range[i], 0.001), 0.0, 1.0);
		att *= att;
		vec3 ld = d / dist;
		lit += l_col[i] * att * (0.25 + 0.75 * max(dot(n, ld), 0.0));
		g += l_col[i] * att * pow(max(dot(n, normalize(ld + eye)), 0.0), 24.0);
	}
	light = lit;
	glint = g * shine;
	lpos = VERTEX;
	vec4 vp = VIEW_MATRIX * vec4(wp, 1.0);
	fogv = clamp((-vp.z - fog_near) / max(fog_far - fog_near, 0.001), 0.0, 1.0);
	POSITION = PROJECTION_MATRIX * vp;
	if (snap.x > 0.0) {
		POSITION.xy = floor(POSITION.xy / POSITION.w * snap + 0.5) / snap * POSITION.w;
	}
}

void fragment() {
	vec3 base = albedo;
	vec3 p = floor(lpos * texel);
	if (pattern == 1) {
		base = mod(p.x + p.z + p.y, 2.0) < 1.0 ? albedo : albedo2;
	} else if (pattern == 2) {
		base = mod(p.y, 2.0) < 1.0 ? albedo : albedo2;
	} else if (pattern == 3) {
		base = mix(albedo, albedo2, step(0.7, hash(p)));
	} else if (pattern == 4) {
		vec3 f = fract(lpos * texel);
		float edge = step(f.x, 0.07) + step(f.z, 0.07) + step(f.y, 0.07);
		base = edge > 0.0 ? albedo2 : albedo;
	}
	vec3 col = base * light + glint + emission;
	col = mix(col, fog_col, fogv);
	ivec2 fc = ivec2(FRAGCOORD.xy) % 4;
	float b = BAYER[fc.x + fc.y * 4] / 16.0 - 0.5;
	col = floor(clamp(col, 0.0, 1.0) * levels + b + 0.5) / levels;
	ALBEDO = col;
}
