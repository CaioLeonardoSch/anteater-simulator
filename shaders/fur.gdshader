shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Pelagem por "cascas" (shells): a malha é repetida em camadas e cada fio
// nasce de um ponto do ruído celular. UV2.x = camada (0 pele .. 1 ponta do pelo).
// COLOR.a < 0.5 = pele sem pelo (a ponta do focinho): úmida e lisa.

uniform float fur_length = 0.012;
uniform float density = 38.0;
uniform float thickness : hint_range(0.0, 1.0) = 0.65;
uniform float droop = 0.25;
// Fios compridos ao longo de UV.y (1 = fios redondos, sem direção).
uniform float stretch = 1.0;
// Para onde os fios deitam (no espaço do modelo), em comprimentos de pelo.
uniform vec3 comb = vec3(0.0);
// Fios mesclados: uns mais claros, outros mais escuros (0 = todos iguais).
uniform float grizzle : hint_range(0.0, 1.0) = 0.0;
uniform vec3 root_color : source_color = vec3(0.16, 0.13, 0.11);
uniform vec3 tip_tint : source_color = vec3(1.15, 1.1, 1.05);
uniform sampler2D strand_tex : filter_linear_mipmap, repeat_enable;
uniform float sheen = 0.35;

varying float shell;
varying float bare;

void vertex() {
	shell = UV2.x;
	bare = step(COLOR.a, 0.5);
	VERTEX += (NORMAL + comb * shell) * fur_length * shell;
	VERTEX.y -= droop * fur_length * shell * shell;
}

void fragment() {
	vec2 suv = vec2(UV.x * density, UV.y * density / stretch);
	float n = texture(strand_tex, suv).r;
	float strand = 1.0 - n;
	if (shell > 0.01 && (bare > 0.5 || strand < shell * thickness + (1.0 - thickness) * shell * shell)) {
		discard;
	}
	vec3 base = COLOR.rgb;
	// Cada fio pega um tom: o ruído numa escala que não bate com a dos fios.
	float tone = texture(strand_tex, suv * 0.37 + vec2(0.31, 0.77)).r;
	base *= mix(1.0, mix(0.55, 1.55, smoothstep(0.25, 0.75, tone)), grizzle * smoothstep(0.2, 0.7, shell));
	vec3 col = mix(root_color * base * 2.2, base * tip_tint, smoothstep(0.0, 1.0, shell));
	if (bare > 0.5) {
		// Pele da ponta do focinho: escura, lisa e um pouco molhada.
		ALBEDO = base;
		ROUGHNESS = 0.32;
		SPECULAR = 0.55;
		RIM = 0.1;
		RIM_TINT = 0.5;
	} else {
		ALBEDO = col;
		ROUGHNESS = 0.85;
		SPECULAR = 0.3;
		RIM = sheen;
		RIM_TINT = 0.7;
		AO = mix(0.5, 1.0, shell);
		AO_LIGHT_AFFECT = 0.5;
	}
}
