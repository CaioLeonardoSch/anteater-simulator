shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Chão da mata depois da passagem: folhas secas caídas (folhiço), gravetos e
// terra escura nos vãos. A estampa (tools/gen_folhico.py) é lida de cima, em
// coordenadas do mundo (a malha não tem UV), em duas escalas trocando em
// manchas para esconder a repetição. Na beira do mapa, o folhiço vai rareando
// e o chão puxa para o tom do campo, para emendar com o terreno.

uniform sampler2D folhico_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D folhico_relevo : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
// Cor média da estampa (o detalhe é a estampa dividida por ela) e o tom final.
uniform vec3 folhico_media : source_color = vec3(0.26, 0.18, 0.10);
uniform vec3 tint : source_color = vec3(0.37, 0.29, 0.19);
uniform vec3 tint_dark : source_color = vec3(0.26, 0.19, 0.12);
// Tom do campo, para a emenda na beira do mapa.
uniform vec3 campo_color : source_color = vec3(0.40, 0.37, 0.17);
uniform float half_map = 80.0;
uniform float blend_width = 7.0;
uniform float tile_size = 1.8;
uniform float tile_size_2 = 2.3;
uniform float tile_angle_2 = 1.1;
uniform float relief_strength : hint_range(0.0, 3.0) = 1.2;
uniform vec2 relief_fade = vec2(15.0, 45.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n_big = texture(noise_tex, wpos.xz * 0.02).r;
	float n_mid = texture(noise_tex, wpos.xz * 0.09 + 0.4).r;
	float n_swap = texture(noise_tex, wpos.xz * 0.05 + 0.5).r;

	float ca = cos(tile_angle_2), sa = sin(tile_angle_2);
	mat2 rot2 = mat2(vec2(ca, sa), vec2(-sa, ca));
	vec2 uv1 = wpos.xz / tile_size;
	vec2 uv2 = (rot2 * wpos.xz) / tile_size_2 + vec2(0.31, 0.67);
	vec4 c1 = texture(folhico_cor, uv1);
	vec4 c2 = texture(folhico_cor, uv2);
	// Troca de uma leitura para a outra pela altura (a folha de cima fica por cima).
	float k = smoothstep(0.4, 0.6, (n_swap - 0.5) * 6.0 + (c2.a - c1.a) * 0.8 + 0.5);
	vec4 c = mix(c1, c2, k);

	// Tom: manchas mais escuras (úmidas, à sombra) e mais claras (folhas novas).
	vec3 base = mix(tint_dark, tint, smoothstep(0.25, 0.75, n_big));
	base *= 0.9 + n_mid * 0.2;
	vec3 col = base * (c.rgb / folhico_media);

	// Beira do mapa: o folhiço rareia e o chão puxa para o campo.
	float out_d = max(abs(wpos.x), abs(wpos.z)) - half_map;
	float litter = smoothstep(0.0, blend_width, out_d + (n_mid - 0.5) * 3.0);
	vec3 campo = campo_color * (0.85 + 0.3 * n_mid) * mix(vec3(1.0), c.rgb / folhico_media, 0.35);
	// Folhas soltas por cima do campo: só as partes mais altas da estampa.
	float loose = smoothstep(0.55, 0.7, c.a) * 0.6;
	col = mix(mix(campo, col, loose), col, litter);
	ALBEDO = col;

	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(relief_fade.x, relief_fade.y, dist);
	vec2 n1 = texture(folhico_relevo, uv1).rg * 2.0 - 1.0;
	vec2 n2 = texture(folhico_relevo, uv2).rg * 2.0 - 1.0;
	// Na imagem, o verde aponta para cima, que no chão é -Z.
	vec2 s1 = vec2(n1.x, -n1.y);
	vec2 s2 = vec2(n2.x, -n2.y) * rot2;
	vec2 slope = mix(s1, s2, k) * relief_strength * fade * mix(0.4, 1.0, litter);
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	nw = normalize(vec3(nw.x + slope.x, nw.y, nw.z + slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	// Folhas secas um pouco lisas (brilham de leve); a terra dos vãos, fosca.
	ROUGHNESS = mix(0.95, 0.78, smoothstep(0.3, 0.7, c.a));
	SPECULAR = 0.3;
	// Vãos fundos entre as folhas mais escuros também na luz do céu.
	AO = mix(0.6, 1.0, smoothstep(0.1, 0.6, c.a));
	AO_LIGHT_AFFECT = 0.3;
}
