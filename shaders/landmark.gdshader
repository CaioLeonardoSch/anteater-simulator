shader_type spatial;
render_mode diffuse_burley, specular_disabled, fog_disabled;
// Marco distante (o cupinzeiro gigante): a névoa normal o apagaria a 200 m,
// então ele usa uma névoa própria, que deixa a silhueta legível e com cara de longe.

uniform vec3 color_a : source_color = vec3(0.56, 0.29, 0.17);
uniform vec3 color_b : source_color = vec3(0.76, 0.46, 0.29);
uniform vec3 haze_color : source_color = vec3(0.92, 0.74, 0.62);
uniform float haze : hint_range(0.0, 1.0) = 0.38;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(noise_tex, wpos.xz * 0.012 + vec2(0.0, wpos.y * 0.01)).r;
	float streak = texture(noise_tex, vec2((wpos.x + wpos.z) * 0.03, wpos.y * 0.004)).r;
	vec3 base = mix(color_a, color_b, smoothstep(0.3, 0.7, n)) * COLOR.rgb;
	base *= mix(0.78, 1.08, smoothstep(0.35, 0.65, streak));
	ALBEDO = base * (1.0 - haze);
	EMISSION = haze_color * haze * 0.85;
	ROUGHNESS = 1.0;
}
