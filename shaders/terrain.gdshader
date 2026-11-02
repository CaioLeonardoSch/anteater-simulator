shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Chão do cerrado: terra vermelha nas trilhas e formigueiros, solo de capim no resto.

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 map_size = vec2(160.0, 160.0);
uniform vec3 soil_color : source_color = vec3(0.76, 0.58, 0.42);
uniform vec3 soil_dark : source_color = vec3(0.64, 0.46, 0.33);
uniform vec3 soil_light : source_color = vec3(0.88, 0.74, 0.58);
uniform vec3 ground_a : source_color = vec3(0.45, 0.40, 0.18);
uniform vec3 ground_b : source_color = vec3(0.33, 0.33, 0.15);
uniform vec3 ground_dry : source_color = vec3(0.58, 0.50, 0.28);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 muv = wpos.xz / map_size + 0.5;
	vec4 m = texture(mask_tex, muv);
	float n_big = texture(noise_tex, wpos.xz * 0.013).r;
	float n_mid = texture(noise_tex, wpos.xz * 0.07 + 0.31).r;
	float n_fine = texture(noise_tex, wpos.xz * 0.55 + 0.73).r;

	vec3 ground = mix(ground_b, ground_a, smoothstep(0.3, 0.7, n_big));
	ground = mix(ground, ground_dry, smoothstep(0.55, 0.85, n_mid) * 0.6);
	ground *= 0.85 + n_fine * 0.3;

	vec3 soil = mix(soil_dark, soil_color, smoothstep(0.25, 0.75, n_mid));
	soil = mix(soil, soil_light, smoothstep(0.6, 0.95, n_fine) * 0.45);

	float bare = max(m.r, m.g);
	float edge = (n_fine - 0.5) * 0.35 + (n_mid - 0.5) * 0.2;
	float soil_amount = smoothstep(0.18, 0.55, bare + edge);
	// Manchas de terra exposta espalhadas pelo campo.
	soil_amount = max(soil_amount, smoothstep(0.86, 0.95, n_big * 0.6 + n_mid * 0.6) * 0.7);

	vec3 col = mix(ground, soil, soil_amount);
	// Trilha um pouco mais escura no centro (pisoteada).
	col *= 1.0 - m.r * 0.12 * smoothstep(0.6, 1.0, m.r);
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
