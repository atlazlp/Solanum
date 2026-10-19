shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled, depth_draw_opaque;

/// Terrain_SUN_Supernova: HDR white × blue→white 1D ramp. Soft fresnel so the
/// face is blown-out white/cyan and only the limb reads a bit of ramp color —
/// no swirling albedo map (that read as a giant PNG with red tendrils).
uniform sampler2D color_ramp : source_color, hint_default_white;
uniform float emission_energy : hint_range(1.0, 80.0) = 28.0;
uniform float fresnel_power : hint_range(0.5, 6.0) = 2.8;
uniform vec3 core_tint : source_color = vec3(1.25, 1.35, 1.55);
uniform vec3 rim_tint : source_color = vec3(0.35, 0.75, 1.55);
uniform float wave_strength : hint_range(0.0, 0.25) = 0.1;

varying vec3 v_world_normal;
varying vec3 v_world_pos;
varying vec3 v_dir;

float shell_wave(vec3 dir) {
	float t = TIME;
	float w = sin(dir.y * 5.2 + t * 1.7);
	w += sin(dir.x * 7.6 - t * 1.2 + dir.z * 2.1) * 0.7;
	w += sin(dir.z * 6.1 + dir.y * 3.3 + t * 0.95) * 0.45;
	w += sin(dot(dir, vec3(1.1, -0.7, 1.4)) * 11.0 - t * 2.3) * 0.28;
	return w / 2.4;
}

void vertex() {
	vec3 dir = normalize(VERTEX);
	v_dir = dir;
	VERTEX += dir * shell_wave(dir) * wave_strength;
	v_world_normal = MODEL_NORMAL_MATRIX * NORMAL;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(v_world_normal);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world_pos);
	float ndv = clamp(abs(dot(n, view_dir)), 0.0, 1.0);
	float crawl = sin(v_dir.x * 16.0 + TIME * 2.2) * sin(v_dir.z * 13.0 - TIME * 1.6);
	float rim = pow(1.0 - ndv, fresnel_power);
	rim = clamp(rim + crawl * 0.18, 0.0, 1.0);

	// Ramp is 1×N (Effects_SUN_Supernova_d): blue at bottom → white at top.
	float ramp_v = mix(0.92, 0.12, rim);
	vec3 ramp = texture(color_ramp, vec2(0.5, ramp_v)).rgb;
	vec3 tint = mix(core_tint, rim_tint, rim);
	vec3 col = ramp * tint;

	// Mild facing variation so it isn't a flat billboard, still no UV swirl.
	float facing = mix(1.15, 0.75, rim);
	ALBEDO = col * facing;
	EMISSION = col * emission_energy * facing;
}
