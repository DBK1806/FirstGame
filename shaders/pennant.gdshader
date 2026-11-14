shader_type spatial;
render_mode cull_disabled;
instance uniform float phase = 0.0;

void vertex() {
	float along = clamp(VERTEX.x / 0.36 + 0.5, 0.0, 1.0);
	float wind = phase + MODEL_MATRIX[3].x * 0.48 + MODEL_MATRIX[3].z * 0.31;
	VERTEX.y *= 1.0 - 0.78 * along;
	VERTEX.y += along * (0.025 * sin(wind - along * 4.0) - 0.025);
	VERTEX.z += along * (0.075 * sin(wind - along * 5.0) + 0.023 * sin(2.0 * wind - along * 8.0));
}

void fragment() {
	ALBEDO = vec3(0.52, 0.105, 0.046);
	ROUGHNESS = 1.0;
}
