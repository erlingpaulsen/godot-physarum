shader_type canvas_item;

uniform vec3 color_1 : source_color;
uniform vec3 color_2 : source_color;
uniform vec3 color_3 : source_color;
uniform vec3 color_4 : source_color;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 color_mix_1 = mix(color_1, color_2, smoothstep(0.0, 0.3, tex.r));
	vec3 color_mix_2 = mix(color_mix_1, color_3, smoothstep(0.1, 0.8, tex.r));
	vec3 color_mix_3 = mix(color_mix_2, color_4, smoothstep(0.6, 1.0, tex.r));
	COLOR.rgb = mix(color_mix_2, color_mix_3, tex.r);
}
