shader_type spatial;
render_mode cull_disabled;

uniform vec4 shallow : source_color = vec4(0.35, 0.61, 0.58, 1.0);
uniform vec4 glint : source_color = vec4(0.73, 0.87, 0.79, 1.0);
varying float fall_depth;

float flow_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec4 seeds = dot(cell, vec2(127.1, 311.7)) + vec4(0.0, 127.1, 311.7, 438.8);
	vec4 values = fract(sin(seeds) * 43758.5453);
	return mix(mix(values.x, values.y, f.x), mix(values.z, values.w, f.x), f.y);
}

void vertex() {
	fall_depth = max(-VERTEX.y, 0.0);
	VERTEX.x += smoothstep(0.0, 0.6, fall_depth) * 0.018 * sin(UV.y * 18.0 - TIME * 9.0);
}

void fragment() {
	float along = UV.y - TIME * 0.72;
	float lanes = UV.x * 3.0 + 0.14 * sin(along * 3.1);
	float streak = smoothstep(0.85, 0.98, cos(lanes * 6.283));
	float pulse = smoothstep(0.35, 0.86, sin(along * 5.0 + floor(lanes + 0.5) * 2.2));
	float lip = smoothstep(9.95, 10.48, UV.y);
	ALBEDO = mix(shallow.rgb, glint.rgb, streak * pulse * (0.43 + 0.35 * lip) + 0.15 * lip);
	float downstream = UV.y * 2.6 - TIME * 3.7;
	float warp = flow_noise(vec2(UV.x * 3.0, downstream * 0.65));
	float ribbons = flow_noise(vec2(UV.x * 13.0 + warp * 2.3, downstream));
	float foam = smoothstep(0.49, 0.79, ribbons) * smoothstep(0.0, 0.3, fall_depth);
	ALBEDO = mix(ALBEDO, glint.rgb, foam * 0.62);
	if (fall_depth > 0.70 + 0.43*ribbons + 0.04*warp) {
		discard;
	}
	ROUGHNESS = 0.68;
}
