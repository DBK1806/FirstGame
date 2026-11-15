shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform float brightness = 1.0;
uniform float gamma = 1.0;

void fragment() {
	vec3 scene = texture(scene_color, SCREEN_UV).rgb;
	COLOR = vec4(brightness * pow(max(scene, vec3(0.0)), vec3(1.0 / gamma)), 1.0);
}
