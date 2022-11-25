shader_type canvas_item;

global uniform float process_time;

uniform vec3 color_1 : source_color;
uniform vec3 color_2 : source_color;
uniform vec3 color_3 : source_color;
uniform vec3 color_4 : source_color;
uniform float max_value = 25.0;

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	float t = process_time / 10.0;

	vec3 color_1_hsv = rgb2hsv(color_1);
	float color_1_hue = mod(color_1_hsv.x + t, 1.0);
	vec3 c1 = hsv2rgb(vec3(color_1_hue, color_1_hsv.yz));

	vec3 color_2_hsv = rgb2hsv(color_2);
	float color_2_hue = mod(color_2_hsv.x + t, 1.0);
	vec3 c2 = hsv2rgb(vec3(color_2_hue, color_2_hsv.yz));

	vec3 color_3_hsv = rgb2hsv(color_3);
	float color_3_hue = mod(color_3_hsv.x + t, 1.0);
	vec3 c3 = hsv2rgb(vec3(color_3_hue, color_3_hsv.yz));

	vec3 color_4_hsv = rgb2hsv(color_4);
	float color_4_hue = mod(color_4_hsv.x + t, 1.0);
	vec3 c4 = hsv2rgb(vec3(color_4_hue, color_4_hsv.yz));

	float v = texture(TEXTURE, UV).r / max_value;

	vec3 color_mix_1 = mix(c1, c2, pow(smoothstep(0.0, 0.25, v), 0.5));
	vec3 color_mix_2 = mix(color_mix_1, c3, smoothstep(0.2, 0.6, v));
	vec3 color_mix_3 = mix(color_mix_2, c4, pow(smoothstep(0.55, 1.0, v), 1.5));
	COLOR.rgb = mix(color_mix_2, color_mix_3, v);
}
