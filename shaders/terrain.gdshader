shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Chão do cerrado: terra vermelha nas trilhas e formigueiros, solo de capim no resto.
// Cada um tem uma estampa feita no Blender (cor + altura no alfa, relevo e
// aspereza) que se repete a cada `tile_size` metros. As cores abaixo continuam
// dando o tom geral; a estampa só traz o detalhe (torrões, pedrinhas, folhas,
// palhas, rachaduras).

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 map_size = vec2(160.0, 160.0);
uniform vec3 soil_color : source_color = vec3(0.76, 0.58, 0.42);
uniform vec3 soil_dark : source_color = vec3(0.64, 0.46, 0.33);
uniform vec3 soil_light : source_color = vec3(0.88, 0.74, 0.58);
uniform vec3 ground_a : source_color = vec3(0.45, 0.40, 0.18);
uniform vec3 ground_b : source_color = vec3(0.33, 0.33, 0.15);
uniform vec3 ground_dry : source_color = vec3(0.58, 0.50, 0.28);

uniform sampler2D solo_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D solo_relevo : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D solo_aspereza : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D trilha_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trilha_relevo : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D trilha_aspereza : hint_default_white, filter_linear_mipmap, repeat_enable;
// Tamanho de uma estampa no mundo, em metros.
uniform float tile_size = 2.0;
// Segunda leitura da mesma estampa, maior e girada, para esconder a repetição.
uniform float tile_size_2 = 2.3;
uniform float tile_angle_2 = 0.9;
// Quanto da estampa aparece na cor (0 = só a mancha lisa antiga).
// Cor média de cada estampa (o detalhe é a estampa dividida por ela).
uniform vec3 solo_media : source_color = vec3(0.382, 0.316, 0.183);
uniform vec3 trilha_media : source_color = vec3(0.672, 0.411, 0.262);
uniform float detail_amount : hint_range(0.0, 1.5) = 0.9;
uniform float relief_strength : hint_range(0.0, 3.0) = 1.0;
// Distância (m) em que o relevo some, para não piscar de longe.
uniform vec2 relief_fade = vec2(18.0, 55.0);
// Lama molhada na beira das lagoas (canal alfa da máscara).
uniform vec3 mud_tint : source_color = vec3(0.52, 0.40, 0.30);
uniform float mud_rough : hint_range(0.0, 1.0) = 0.55;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

struct Layer {
	vec3 col;     // detalhe de cor (1 = média da estampa)
	float h;      // altura 0..1
	vec2 slope;   // inclinação do relevo, no plano XZ do mundo
	float rough;
};

// Lê uma estampa nas duas posições (uv1 e uv2), só onde cada uma aparece, e o
// relevo só de perto. Usa textureGrad porque as leituras ficam dentro de `if`.
Layer read_layer(sampler2D cor, sampler2D rel, sampler2D asp, vec3 avg,
		vec2 uv1, vec2 uv2, vec4 g1, vec4 g2, mat2 rot2, float d, bool near) {
	bool use1 = d < 1.1;
	bool use2 = d > -1.1;
	vec4 c1 = vec4(0.0);
	vec4 c2 = vec4(0.0);
	if (use1) c1 = textureGrad(cor, uv1, g1.xy, g1.zw);
	if (use2) c2 = textureGrad(cor, uv2, g2.xy, g2.zw);
	// Troca de uma leitura para a outra numa faixa estreita, pela altura (fica
	// por cima o que é mais alto), para não aparecer uma imagem fantasma.
	float k = use1 && use2 ? smoothstep(0.35, 0.65, d + (c2.a - c1.a) * 0.9 + 0.5) : (use2 ? 1.0 : 0.0);
	Layer l;
	l.col = mix(c1.rgb, c2.rgb, k) / avg;
	l.h = mix(c1.a, c2.a, k);
	l.slope = vec2(0.0);
	l.rough = 0.92;
	if (near) {
		vec2 s1 = vec2(0.0), s2 = vec2(0.0);
		float r1 = 0.92, r2 = 0.92;
		if (k < 0.999) {
			vec2 n1 = textureGrad(rel, uv1, g1.xy, g1.zw).rg * 2.0 - 1.0;
			// Na imagem, o verde aponta para cima, que no chão é -Z.
			s1 = vec2(n1.x, -n1.y);
			r1 = textureGrad(asp, uv1, g1.xy, g1.zw).r;
		}
		if (k > 0.001) {
			vec2 n2 = textureGrad(rel, uv2, g2.xy, g2.zw).rg * 2.0 - 1.0;
			s2 = vec2(n2.x, -n2.y) * rot2;
			r2 = textureGrad(asp, uv2, g2.xy, g2.zw).r;
		}
		l.slope = mix(s1, s2, k);
		l.rough = mix(r1, r2, k);
	}
	return l;
}

void fragment() {
	vec2 muv = wpos.xz / map_size + 0.5;
	vec4 m = texture(mask_tex, muv);
	float n_big = texture(noise_tex, wpos.xz * 0.013).r;
	float n_mid = texture(noise_tex, wpos.xz * 0.07 + 0.31).r;
	float n_fine = texture(noise_tex, wpos.xz * 0.55 + 0.73).r;
	float n_swap = texture(noise_tex, wpos.xz * 0.045 + 0.5).r;

	vec3 ground = mix(ground_b, ground_a, smoothstep(0.3, 0.7, n_big));
	ground = mix(ground, ground_dry, smoothstep(0.55, 0.85, n_mid) * 0.6);
	ground *= 0.92 + n_fine * 0.16;

	vec3 soil = mix(soil_dark, soil_color, smoothstep(0.25, 0.75, n_mid));
	soil = mix(soil, soil_light, smoothstep(0.6, 0.95, n_fine) * 0.3);

	float bare = max(m.r, m.g);
	float edge = (n_fine - 0.5) * 0.35 + (n_mid - 0.5) * 0.2;
	float soil_amount = smoothstep(0.18, 0.55, bare + edge);
	// Manchas de terra exposta espalhadas pelo campo.
	soil_amount = max(soil_amount, smoothstep(0.86, 0.95, n_big * 0.6 + n_mid * 0.6) * 0.7);

	// As duas leituras da estampa: a normal e uma um pouco maior, girada, que
	// entra em manchas.
	float ca = cos(tile_angle_2), sa = sin(tile_angle_2);
	mat2 rot2 = mat2(vec2(ca, sa), vec2(-sa, ca));
	vec2 uv1 = wpos.xz / tile_size;
	vec2 uv2 = (rot2 * wpos.xz) / tile_size_2 + vec2(0.37, 0.71);
	vec4 g1 = vec4(dFdx(uv1), dFdy(uv1));
	vec4 g2 = vec4(dFdx(uv2), dFdy(uv2));
	float d = (n_swap - 0.5) * 10.0;

	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(relief_fade.x, relief_fade.y, dist);
	bool near = fade > 0.0;

	Layer g;
	g.col = vec3(1.0); g.h = 0.0; g.slope = vec2(0.0); g.rough = 0.92;
	Layer t = g;
	if (soil_amount < 0.999) {
		g = read_layer(solo_cor, solo_relevo, solo_aspereza, solo_media, uv1, uv2, g1, g2, rot2, d, near);
	}
	if (soil_amount > 0.001) {
		t = read_layer(trilha_cor, trilha_relevo, trilha_aspereza, trilha_media, uv1, uv2, g1, g2, rot2, d, near);
	}


	// Mistura pela altura: na beira da trilha, as pedrinhas e palhas do campo
	// ficam por cima da terra, e a terra aparece primeiro nas partes baixas.
	float hb = soil_amount * 2.0 - 1.0 + (t.h - g.h) * 0.9;
	float w = smoothstep(-0.12, 0.12, hb);
	w = mix(w, soil_amount, step(0.999, soil_amount) + step(soil_amount, 0.001));

	vec3 col_g = ground * mix(vec3(1.0), g.col, detail_amount);
	vec3 col_t = soil * mix(vec3(1.0), t.col, detail_amount);
	vec3 col = mix(col_g, col_t, w);
	// Trilha um pouco mais escura no centro (pisoteada).
	col *= 1.0 - m.r * 0.12 * smoothstep(0.6, 1.0, m.r);
	// Beira das lagoas: lama escura, lisa e brilhante, com poças onde é mais baixo.
	float wet = smoothstep(0.2, 0.75, m.a + (n_mid - 0.5) * 0.35 + (n_fine - 0.5) * 0.15);
	float puddle = wet * smoothstep(0.55, 0.8, n_fine + (0.5 - t.h) * 0.6);
	col = mix(col, col * mud_tint, wet);
	ALBEDO = col;

	vec2 slope = mix(g.slope, t.slope, w) * relief_strength * fade * (1.0 - wet * 0.65);
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	nw = normalize(vec3(nw.x + slope.x, nw.y, nw.z + slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	ROUGHNESS = mix(mix(0.92, mix(g.rough, t.rough, w), fade), mix(mud_rough, 0.2, puddle), wet);
	SPECULAR = 0.25;
}
