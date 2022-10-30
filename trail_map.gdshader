shader_type canvas_item;

uniform vec3 color_1 : source_color;
uniform vec3 color_2 : source_color;
uniform vec3 color_3 : source_color;
uniform vec3 color_4 : source_color;
uniform float max_value = 25.0;

void fragment() {
	float v = texture(TEXTURE, UV).r / max_value;
	vec3 color_mix_1 = mix(color_1, color_2, pow(smoothstep(0.0, 0.3, v), 0.5));
	vec3 color_mix_2 = mix(color_mix_1, color_3, smoothstep(0.1, 0.8, v));
	vec3 color_mix_3 = mix(color_mix_2, color_4, pow(smoothstep(0.6, 1.0, v), 1.5));
	COLOR.rgb = mix(color_mix_2, color_mix_3, v);
}
