shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, specular_disabled;

// Unity Terrain_BH_RockGeode blends the striped wall texture on steep faces
// and the cracked top texture on faces that point outward.
uniform sampler2D side_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 side_uv_scale = vec2(5.0, 5.0);
uniform vec2 top_uv_scale = vec2(6.0, 6.0);
uniform vec3 side_tint = vec3(0.52, 0.36, 0.60);
uniform vec3 top_tint = vec3(0.18, 0.11, 0.22);
uniform float angle_cutoff = 0.5;
uniform float angle_blend = 0.1;
uniform vec3 planet_center = vec3(0.0);
uniform float night_level : hint_range(0.0, 1.0) = 0.18;
uniform float day_level : hint_range(0.0, 1.5) = 0.92;
uniform float terminator_soft : hint_range(0.01, 0.8) = 0.18;
uniform float eclipse : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sun_position = vec3(0.0);
uniform float body_fade : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec3 n = normalize(v_world_normal);
	vec3 radial = v_world_pos - planet_center;
	float rlen = length(radial);
	radial = rlen > 0.001 ? radial / rlen : vec3(0.0, 1.0, 0.0);
	float outward = dot(n, radial);
	float top_w = smoothstep(angle_cutoff - angle_blend, angle_cutoff + angle_blend, abs(outward));
	vec3 side_texel = texture(side_tex, UV * side_uv_scale).rgb;
	vec3 top_texel = texture(top_tex, UV * top_uv_scale).rgb;
	// The top texture is pale pink. Recolor with its cracks, then mix grey with #29224d.
	float top_luma = dot(top_texel, vec3(0.299, 0.587, 0.114));
	top_luma = smoothstep(0.42, 0.96, top_luma);
	float side_l = dot(side_texel, vec3(0.299, 0.587, 0.114));
	side_l = smoothstep(0.04, 0.55, side_l);
	vec3 dye = vec3(0.0223, 0.0160, 0.0743);
	vec3 outside_top = mix(mix(vec3(0.032), vec3(0.062), top_luma), dye, 0.5);
	vec3 outside_side = mix(mix(vec3(0.028), vec3(0.054), side_l), dye, 0.5);
	vec3 outside = mix(outside_side, outside_top, top_w);
	vec3 inside_top = mix(mix(vec3(0.018), vec3(0.036), top_luma), dye, 0.5);
	vec3 inside_side = mix(mix(vec3(0.016), vec3(0.032), side_l), dye, 0.5);
	vec3 inside = mix(inside_side, inside_top, top_w);
	float inner = smoothstep(0.15, -0.22, outward);
	vec3 alb = mix(outside, inside, inner);

	vec3 to_sun = sun_position - v_world_pos;
	float sun_dist = length(to_sun);
	to_sun = sun_dist > 0.001 ? to_sun / sun_dist : vec3(0.0, 1.0, 0.0);
	float day = smoothstep(-terminator_soft, terminator_soft, dot(n, to_sun));
	float outside_light = mix(night_level, day_level, day);
	float inside_light = mix(0.04, 0.32, day);
	float light = mix(outside_light, inside_light, inner);
	light = mix(light, night_level * 0.45, eclipse);
	ALBEDO = alb * light;
	if (body_fade < 0.999) {
		float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (dither > body_fade) {
			discard;
		}
	}
}
