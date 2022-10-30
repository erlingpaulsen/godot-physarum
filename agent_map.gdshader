shader_type canvas_item;

uniform float max_value = 30.0;

void fragment() {
	float v = texture(TEXTURE, UV).r / max_value;
	COLOR = vec4(vec3(pow(v, 0.4)), 1.0);
}
