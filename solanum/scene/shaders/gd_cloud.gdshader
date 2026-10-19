shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, specular_disabled;

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec3 albedo_tint = vec3(0.07, 0.18, 0.045);
uniform vec2 uv_scale = vec2(1.0, 1.6);
uniform vec3 flash0 = vec3(0.0);
uniform vec3 flash1 = vec3(0.0);
uniform vec3 flash2 = vec3(0.0);
uniform vec3 flash3 = vec3(0.0);
uniform float amt0 = 0.0;
uniform float amt1 = 0.0;
uniform float amt2 = 0.0;
uniform float amt3 = 0.0;
uniform float flash_reach = 340.0;
uniform float eclipse : hint_range(0.0, 1.0) = 0.0;
uniform float body_fade : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

vec3 _storm(vec3 world_pos, vec3 center, float amt) {
	if (amt <= 0.001) {
		return vec3(0.0);
	}
	float d = length(world_pos - center);
	float k = amt * smoothstep(flash_reach, flash_reach * 0.15, d);
	k *= k;
	return vec3(0.48, 0.09, 0.13) * k;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec3 tex = texture(albedo_tex, UV * uv_scale).rgb;
	float luma = max(dot(tex, vec3(0.299, 0.587, 0.114)), 0.001);
	// Keep the cloud gradients. Pull the pale deck down so it cannot stay white.
	float shaped = pow(clamp(luma, 0.0, 1.0), 1.2);
	shaped *= mix(1.0, 0.42, smoothstep(0.35, 1.0, luma));
	vec3 alb = albedo_tint * shaped * (tex / luma);
	vec3 n = normalize(v_world_normal);
	vec3 to_sun = -v_world_pos;
	float sun_dist = length(to_sun);
	to_sun = sun_dist > 0.001 ? to_sun / sun_dist : vec3(0.0, 1.0, 0.0);
	float day = smoothstep(-0.18, 0.18, dot(n, to_sun));
	float light = mix(0.14, 0.36, day);
	light = mix(light, 0.08, eclipse);

	vec3 glow = vec3(0.0);
	glow += _storm(v_world_pos, flash0, amt0);
	glow += _storm(v_world_pos, flash1, amt1);
	glow += _storm(v_world_pos, flash2, amt2);
	glow += _storm(v_world_pos, flash3, amt3);

	ALBEDO = alb * light + glow;
	if (body_fade < 0.999) {
		float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (dither > body_fade) {
			discard;
		}
	}
}
