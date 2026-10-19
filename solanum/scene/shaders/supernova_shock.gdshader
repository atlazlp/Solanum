shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, specular_disabled;

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(0.85, 0.95, 1.55, 0.55);
uniform vec3 emission_color : source_color = vec3(0.45, 0.85, 1.8);
uniform float emission_energy = 16.0;
uniform float wave_strength : hint_range(0.0, 0.25) = 0.12;

float shell_wave(vec3 dir) {
	float t = TIME;
	float w = sin(dir.y * 4.6 + t * 2.1);
	w += sin(dir.x * 6.8 - t * 1.45 + dir.z * 1.8) * 0.65;
	w += sin(dir.z * 8.4 + dir.x * 2.6 + t * 1.05) * 0.4;
	w += sin(dot(dir, vec3(0.9, 1.3, -1.1)) * 12.0 + t * 2.6) * 0.3;
	return w / 2.3;
}

void vertex() {
	vec3 dir = normalize(VERTEX);
	VERTEX += dir * shell_wave(dir) * wave_strength;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = tex.rgb * albedo_color.rgb;
	ALPHA = tex.a * albedo_color.a;
	EMISSION = tex.rgb * emission_color * emission_energy;
}
