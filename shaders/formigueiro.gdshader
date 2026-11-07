shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Terra dos formigueiros de saúva. O monte e as tampas das câmaras usam a
// estampa de terra fofa feita no Blender (grãozinhos de terra), vista de cima.
// Onde a cor de vértice é escura (os olheiros, as câmaras abertas e o buraco da
// rainha) entra a estampa de terra recém-cavada: úmida, com riscos de garra,
// torrões, bocas de galeria e pedaços do jardim de fungo, mais escura quanto
// mais fundo.

uniform vec3 color_a : source_color = vec3(0.48, 0.30, 0.20);
uniform vec3 color_b : source_color = vec3(0.62, 0.42, 0.30);
uniform float noise_scale = 3.0;
uniform float detail_scale = 14.0;
// Quanto as manchas grandes de duas cores aparecem (a estampa já traz o detalhe).
uniform float tint_variation : hint_range(0.0, 1.0) = 0.5;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.97;
uniform float specular_value : hint_range(0.0, 1.0) = 0.15;
uniform float vertex_color_mix : hint_range(0.0, 1.0) = 1.0;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

uniform sampler2D terra_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terra_relevo : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D cava_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cava_relevo : hint_normal, filter_linear_mipmap, repeat_enable;
// Cor média de cada estampa (o detalhe é a estampa dividida por ela).
uniform vec3 terra_media : source_color = vec3(0.632, 0.428, 0.289);
uniform vec3 cava_media : source_color = vec3(0.376, 0.215, 0.134);
// Tamanho de uma estampa no mundo, em metros.
uniform float terra_tile = 0.5;
uniform float cava_tile = 0.9;
uniform float detail_amount : hint_range(0.0, 1.5) = 1.0;

// Terra cavada (as tampas deixam em 0: a beira escura delas é só sombra).
uniform float dug_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec3 dug_color : source_color = vec3(0.40, 0.25, 0.17);
// Quanto escurece no fundo (onde a cor de vértice é quase preta).
uniform float deep_dark : hint_range(0.0, 1.0) = 0.3;

// Na terra cavada, a cor de vértice também diz a cor da camada de terra
// (vermelha, amarelada...): 0 = ignora, 1 = usa toda.
uniform float strata_mix : hint_range(0.0, 1.0) = 1.0;
// Jardim de fungo e raízes: só a cor de vértice com poros de esponja.
uniform bool fungus_mode = false;

uniform float relief_strength : hint_range(0.0, 3.0) = 1.0;
// Distância (m) em que o relevo some, para não piscar de longe.
uniform vec2 relief_fade = vec2(15.0, 40.0);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tri_noise(vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float x = texture(noise_tex, p.zy * scale).r;
	float y = texture(noise_tex, p.xz * scale).r;
	float z = texture(noise_tex, p.xy * scale).r;
	return x * w.x + y * w.y + z * w.z;
}

// Estampa de terra fofa vista de cima; nos lados dos torrões (que ficam em
// pé) ela vem de lado também, para os grãos não esticarem.
vec3 terra_tri(vec2 uvt) {
	vec3 top = texture(terra_cor, uvt).rgb;
	if (abs(wnorm.y) > 0.8) {
		return top;
	}
	vec3 w = pow(abs(wnorm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 sx = texture(terra_cor, wpos.zy / terra_tile).rgb;
	vec3 sz = texture(terra_cor, wpos.xy / terra_tile).rgb;
	return sx * w.x + top * w.y + sz * w.z;
}

void fragment() {
	float n1 = tri_noise(wpos, wnorm, noise_scale * 0.1);
	float n2 = tri_noise(wpos + 13.7, wnorm, detail_scale * 0.1);
	vec3 tint = mix(color_a, color_b, 0.5 + (smoothstep(0.3, 0.7, n1 * 0.6 + n2 * 0.4) - 0.5) * tint_variation);

	// Quanto este ponto é buraco (pela cor de vértice) e quanto é fundo.
	float lum = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
	float dug = smoothstep(0.62, 0.32, lum) * dug_amount;
	float deep = smoothstep(0.32, 0.06, lum) * dug_amount;

	vec2 uvt = wpos.xz / terra_tile;
	vec2 uvc = wpos.xz / cava_tile + 0.37;
	vec3 col = tint * mix(vec3(1.0), terra_tri(uvt) / terra_media, detail_amount);
	col = mix(col, col * COLOR.rgb, vertex_color_mix);
	if (dug > 0.0) {
		vec3 dc = dug_color * mix(vec3(1.0), texture(cava_cor, uvc).rgb / cava_media, detail_amount);
		dc *= mix(1.0, deep_dark, deep);
		// Camada de terra: a cor de vértice dividida pelo próprio brilho.
		dc *= mix(vec3(1.0), COLOR.rgb / max(lum, 0.02), strata_mix);
		col = mix(col, dc, dug);
	}
	ALBEDO = col;

	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(relief_fade.x, relief_fade.y, dist);
	vec2 tt = texture(terra_relevo, uvt).rg * 2.0 - 1.0;
	vec2 tc = texture(cava_relevo, uvc).rg * 2.0 - 1.0;
	if (fade > 0.0 && !fungus_mode) {
		// Vista de cima: o vermelho anda com x e o verde aponta para -z.
		vec2 t = mix(tt, tc, dug) * smoothstep(0.4, 0.85, abs(wnorm.y));
		vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 n2w = normalize(nw + vec3(t.x, 0.0, -t.y) * relief_strength * fade);
		NORMAL = normalize((VIEW_MATRIX * vec4(n2w, 0.0)).xyz);
	}
	ROUGHNESS = mix(roughness_value, 0.85, dug);
	SPECULAR = specular_value;
	RIM = rim_amount;
	RIM_TINT = 0.6;
	if (fungus_mode) {
		// Esponja cinza-clara: poros miúdos e escuros.
		float p1 = tri_noise(wpos, wnorm, 12.0);
		float p2 = tri_noise(wpos + 5.3, wnorm, 30.0);
		float pores = smoothstep(0.42, 0.62, p1 * 0.5 + p2 * 0.5);
		ALBEDO = COLOR.rgb * mix(0.6, 1.05, pores);
		ROUGHNESS = 0.9;
		SPECULAR = 0.2;
		RIM = 0.05;
		RIM_TINT = 0.5;
	}
}
