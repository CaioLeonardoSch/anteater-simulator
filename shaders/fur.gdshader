shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Pelagem por "cascas" (shells): a malha é repetida em camadas e cada fio
// nasce de um ponto do ruído celular. UV2.x = camada (0 pele .. 1 ponta do pelo).

uniform float fur_length = 0.012;
uniform float density = 38.0;
uniform float thickness : hint_range(0.0, 1.0) = 0.65;
uniform float droop = 0.25;
uniform vec3 root_color : source_color = vec3(0.16, 0.13, 0.11);
uniform vec3 tip_tint : source_color = vec3(1.15, 1.1, 1.05);
uniform sampler2D strand_tex : filter_linear_mipmap, repeat_enable;
uniform float sheen = 0.35;

varying float shell;

void vertex() {
	shell = UV2.x;
	VERTEX += NORMAL * fur_length * shell;
	VERTEX.y -= droop * fur_length * shell * shell;
}

void fragment() {
	float n = texture(strand_tex, UV * density).r;
	float strand = 1.0 - n;
	if (shell > 0.01 && strand < shell * thickness + (1.0 - thickness) * shell * shell) {
		discard;
	}
	vec3 base = COLOR.rgb;
	vec3 col = mix(root_color * base * 2.2, base * tip_tint, smoothstep(0.0, 1.0, shell));
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
	RIM = sheen;
	RIM_TINT = 0.7;
	AO = mix(0.5, 1.0, shell);
	AO_LIGHT_AFFECT = 0.5;
}
