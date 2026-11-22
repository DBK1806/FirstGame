shader_type spatial;
render_mode cull_back, depth_prepass_alpha;

uniform float visibility : hint_range(0.0, 1.0) = 1.0;
uniform float phase = 0.0;
uniform float animation_time = 0.0;
varying vec3 cloth_position;

void vertex() {
	cloth_position = VERTEX;
	float hem = pow(1.0 - clamp(VERTEX.y / 1.15, 0.0, 1.0), 2.0);
	VERTEX.x += sin(animation_time * 1.5 + phase + VERTEX.z * 7.0) * 0.045 * hem;
	VERTEX.z += cos(animation_time * 1.2 + phase + VERTEX.x * 8.0) * 0.035 * hem;
	VERTEX.y += sin(animation_time * 1.8 + phase + VERTEX.x * 9.0) * 0.025 * hem;
}

void fragment() {
	vec2 p = cloth_position.xy;
	float left_eye = length((p - vec2(-0.085, 0.925)) / vec2(0.043, 0.063));
	float right_eye = length((p - vec2(0.085, 0.925)) / vec2(0.043, 0.063));
	float mouth = length((p - vec2(0.0, 0.785)) / vec2(0.035, 0.055));
	float face = (1.0 - smoothstep(0.85, 1.05, min(min(left_eye, right_eye), mouth))) * step(0.10, cloth_position.z);
	vec3 cloth = mix(vec3(0.58, 0.76, 0.8), vec3(0.89, 0.96, 0.94), smoothstep(0.0, 1.1, cloth_position.y));
	ALBEDO = mix(cloth, vec3(0.035, 0.07, 0.09), face);
	EMISSION = cloth * 0.24 * (1.0 - face);
	ROUGHNESS = 1.0;
	ALPHA = visibility * mix(0.385, 0.525, smoothstep(0.0, 0.8, cloth_position.y));
}
