shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float gap_angle = 0.0;
uniform float prograde_sign = 1.0;
uniform float trail_half = 0.1;
uniform float lead_half = 0.1;
uniform float half_width = 14.0;
uniform float fade = 1.0;

varying float v_ang;

void vertex() {
	v_ang = UV.x;
	vec3 tangent = vec3(UV2.x, 0.0, UV2.y);
	float tlen = length(tangent);
	if (tlen > 0.0001) {
		tangent /= tlen;
	} else {
		tangent = vec3(1.0, 0.0, 0.0);
	}
	vec3 cam_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 view = cam_local - VERTEX;
	vec3 side = cross(tangent, view);
	if (dot(side, side) < 0.0001) {
		side = cross(tangent, vec3(0.0, 1.0, 0.0));
	}
	VERTEX += normalize(side) * half_width * UV.y;
}

void fragment() {
	float diff = mod(v_ang - gap_angle + PI, TAU) - PI;
	float along = diff * prograde_sign;
	if (along > -trail_half && along < lead_half) {
		discard;
	}
	float from_trail = -trail_half - along;
	if (from_trail < 0.0) {
		from_trail += TAU;
	}
	float span = max(TAU - trail_half - lead_half, 0.001);
	float t = clamp(from_trail / span, 0.0, 1.0);
	float alpha = 1.0 - t;
	alpha = alpha * alpha * (3.0 - 2.0 * alpha);
	ALBEDO = albedo.rgb;
	ALPHA = alpha * albedo.a * fade;
}
