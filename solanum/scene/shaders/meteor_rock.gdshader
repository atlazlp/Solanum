shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_opaque, specular_disabled;

uniform float fade : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_pos;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

void vertex() {
	v_pos = VERTEX;
}

void fragment() {
	// Soft blobs, not stripes. Most of the shard stays rock.
	float n = vnoise(v_pos * 0.22);
	float hot = step(0.5, n);
	float grit = fract(sin(dot(v_pos, vec3(19.1, 7.7, 3.3))) * 13013.0);
	vec3 rock = vec3(0.006, 0.0011, 0.0005) * mix(0.85, 1.15, grit);
	vec3 lava = vec3(1.0, 0.064, 0.001);
	ALBEDO = mix(rock, lava, hot) * fade;
	ALPHA = fade;
}
