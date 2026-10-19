shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, ambient_light_disabled;

varying float v_bright;
varying float v_glint;
varying float v_warm;

void vertex() {
	// Quads are stored as a shared center plus a corner offset, then turned to face the camera
	// with a per-star roll so the glints don't all share one axis.
	vec2 corner = UV2;
	float roll = COLOR.r * 6.2831853;
	float s = sin(roll);
	float c = cos(roll);
	vec2 spun = vec2(c * corner.x - s * corner.y, s * corner.x + c * corner.y);
	// Uniform mesh scale keeps a world-space camera axis aligned after the model matrix.
	vec3 right_w = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up_w = normalize(INV_VIEW_MATRIX[1].xyz);
	VERTEX += right_w * spun.x + up_w * spun.y;
	v_bright = COLOR.g;
	v_glint = COLOR.b;
	v_warm = COLOR.a;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	// Soft disc that dies inside the quad, so the card edge and any orbit-line
	// cut through the margin stay invisible.
	float core = exp(-r * r * 10.5);
	float edge = 1.0 - smoothstep(0.34, 0.72, r);
	float a = core * edge * mix(0.82, 1.0, v_glint);
	vec3 cool = vec3(0.70, 0.84, 1.0);
	vec3 warm = vec3(1.0, 0.90, 0.70);
	ALBEDO = mix(cool, warm, v_warm) * v_bright * a;
	ALPHA = a;
}
