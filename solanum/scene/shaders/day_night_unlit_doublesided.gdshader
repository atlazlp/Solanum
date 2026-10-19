shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, specular_disabled;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform bool use_albedo_texture = false;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_energy = 0.0;
uniform sampler2D emission_texture : source_color, hint_default_black;
uniform bool use_emission_texture = false;
uniform float night_level : hint_range(0.0, 1.0) = 0.14;
uniform float day_level : hint_range(0.0, 1.5) = 1.05;
uniform float terminator_soft : hint_range(0.01, 0.8) = 0.18;
uniform float eclipse : hint_range(0.0, 1.0) = 0.0;
uniform float eclipse_floor : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sun_position = vec3(0.0);
uniform float body_fade : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec4 alb = albedo_color;
	if (use_albedo_texture) {
		alb.rgb *= texture(albedo_texture, UV).rgb;
	}
	vec3 emis = emission_color.rgb * emission_energy;
	if (use_emission_texture) {
		emis *= texture(emission_texture, UV).rgb;
	}

	vec3 n = normalize(v_world_normal);
	// Backfaces keep the mesh normal; flip so lighting matches the visible side.
	if (!FRONT_FACING) {
		n = -n;
	}
	vec3 to_sun = sun_position - v_world_pos;
	float sun_dist = length(to_sun);
	to_sun = sun_dist > 0.001 ? to_sun / sun_dist : vec3(0.0, 1.0, 0.0);
	float ndl = dot(n, to_sun);
	float day = smoothstep(-terminator_soft, terminator_soft, ndl);
	float light = mix(night_level, day_level, day);
	float eclipse_light = night_level * 0.55;
	if (eclipse_floor > 0.001) {
		eclipse_light = max(eclipse_light, eclipse_floor);
	}
	light = mix(light, eclipse_light, eclipse);
	if (emission_energy > 12.0) {
		light = max(light, 1.0);
	}

	ALBEDO = alb.rgb * light;
	EMISSION = emis;
	if (body_fade < 0.999) {
		float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (dither > body_fade) {
			discard;
		}
	}
}
