shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Casca das árvores e galhos. Usa a estampa de cortiça feita no Blender, presa
// ao galho (em volta e ao longo dele), então as rachaduras seguem cada galho,
// mesmo os tortos. As cores abaixo continuam dando o tom geral; a estampa só
// traz o detalhe. Os troncos caídos usam o mesmo shader com as partes de
// tronco morto ligadas: falhas na casca com a madeira cinza à mostra, musgo só
// na parte de baixo e as pontas quebradas com anéis (UV2.x = 1 nas pontas).

uniform vec3 color_a : source_color = vec3(0.30, 0.24, 0.20);
uniform vec3 color_b : source_color = vec3(0.55, 0.47, 0.39);
uniform float noise_scale = 2.0;
uniform float detail_scale = 9.0;
uniform float tint_variation : hint_range(0.0, 1.0) = 0.5;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.95;
uniform float specular_value : hint_range(0.0, 1.0) = 0.2;
uniform float vertex_color_mix : hint_range(0.0, 1.0) = 1.0;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.15;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

uniform sampler2D casca_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D casca_relevo : hint_normal, filter_linear_mipmap, repeat_enable;
// Cor média da estampa (o detalhe é a estampa dividida por ela).
uniform vec3 casca_media : source_color = vec3(0.409, 0.355, 0.302);
// Quantas vezes a estampa dá a volta no galho (número inteiro, para não ter emenda).
uniform float around_repeats = 3.0;
// Comprimento de uma estampa ao longo do galho, em metros.
uniform float length_tile = 0.5;
// Quanto o UV.y anda por metro de galho (o `v_scale` de `add_tube`).
uniform float uv_per_meter = 0.6;
uniform float detail_amount : hint_range(0.0, 1.5) = 1.0;
uniform float relief_strength : hint_range(0.0, 3.0) = 1.0;
// Distância (m) em que o relevo some, para não piscar de longe.
uniform vec2 relief_fade = vec2(20.0, 50.0);

// Tronco morto (as árvores deixam tudo em 0).
// Falhas na casca, com a madeira desbotada e riscada no comprido.
uniform float bare_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 bare_color : source_color = vec3(0.56, 0.52, 0.46);
// Musgo na parte de baixo (e um pouco subindo pelas rachaduras).
uniform float moss_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moss_color : source_color = vec3(0.27, 0.33, 0.14);
// Madeira das pontas quebradas.
uniform vec3 wood_light : source_color = vec3(0.66, 0.53, 0.38);
uniform vec3 wood_dark : source_color = vec3(0.44, 0.32, 0.22);
uniform float wood_rings = 9.0;

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

void fragment() {
	float n1 = tri_noise(wpos, wnorm, noise_scale * 0.1);
	float n2 = tri_noise(wpos + 13.7, wnorm, detail_scale * 0.1);
	vec3 tint = mix(color_a, color_b, 0.5 + (smoothstep(0.3, 0.7, n1 * 0.6 + n2 * 0.4) - 0.5) * tint_variation);

	vec2 uv = vec2(UV.x * around_repeats, UV.y / (uv_per_meter * length_tile));
	vec4 c = texture(casca_cor, uv);
	vec3 col = tint * mix(vec3(1.0), c.rgb / casca_media, detail_amount);
	float bump = 1.0;

	if (bare_amount > 0.0) {
		// Placas grandes onde a casca caiu; a madeira tem riscos no comprido.
		float bn = texture(noise_tex, vec2(UV.x * 0.9, UV.y * 0.35) + 0.37).r;
		float bare = smoothstep(0.62, 0.66, bn + (c.a - 0.5) * 0.15) * bare_amount;
		float grain = texture(noise_tex, vec2(UV.x * 6.0, UV.y * 0.08)).r;
		vec3 wood = bare_color * (0.82 + grain * 0.3);
		// Beirada escura onde a casca ainda está presa.
		float lip = smoothstep(0.56, 0.62, bn) * (1.0 - smoothstep(0.62, 0.66, bn)) * bare_amount;
		col = mix(col * (1.0 - lip * 0.35), wood, bare);
		bump = 1.0 - bare * 0.85;
	}
	if (moss_amount > 0.0) {
		float mn = tri_noise(wpos + 3.1, wnorm, 0.9);
		float mf = tri_noise(wpos + 7.7, wnorm, 6.0);
		// De baixo para cima, com a beira irregular; nas rachaduras sobe mais.
		float below = smoothstep(0.30, -0.25, wnorm.y + (mn - 0.5) * 0.9 - (1.0 - c.a) * 0.25);
		float moss = below * smoothstep(0.25, 0.45, mf) * moss_amount;
		col = mix(col, moss_color * (0.75 + mf * 0.5), moss);
		bump *= 1.0 - moss * 0.6;
	}
	if (UV2.x > 0.5) {
		// Ponta quebrada: anéis tortos, rachaduras saindo do miolo e a casca na beira.
		vec2 d = UV - 0.5;
		float r = length(d) * 2.0;
		float ang = atan(d.y, d.x);
		float wob = texture(noise_tex, vec2(ang * 0.16, r * 0.3) + 0.21).r;
		float ring = 0.5 + 0.5 * sin((r + wob * 0.12) * wood_rings * 6.2832);
		vec3 wood = mix(wood_dark, wood_light, smoothstep(0.2, 0.8, ring) * 0.6 + 0.3 - r * 0.15);
		float chk = texture(noise_tex, vec2(ang * 0.48, 0.1)).r;
		wood *= 1.0 - smoothstep(0.72, 0.76, chk) * smoothstep(0.15, 0.5, r) * 0.55;
		wood *= mix(0.7, 1.0, smoothstep(0.0, 0.18, r));
		col = mix(wood, color_a * 0.8, smoothstep(0.86, 0.92, r));
		bump = 0.0;
	}
	col = mix(col, col * COLOR.rgb, vertex_color_mix);
	ALBEDO = col;

	// Relevo: direções "em volta" e "ao longo" do galho tiradas da própria tela
	// (a malha não guarda essas direções).
	vec3 nm = texture(casca_relevo, uv).rgb * 2.0 - 1.0;
	vec3 dp1 = dFdx(VERTEX);
	vec3 dp2 = dFdy(VERTEX);
	vec2 duv1 = dFdx(uv);
	vec2 duv2 = dFdy(uv);
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float fade = (1.0 - smoothstep(relief_fade.x, relief_fade.y, dist)) * bump;
	if (fade > 0.0) {
		vec3 n = normalize(NORMAL);
		vec3 dp2perp = cross(dp2, n);
		vec3 dp1perp = cross(n, dp1);
		vec3 t = dp2perp * duv1.x + dp1perp * duv2.x;
		vec3 b = dp2perp * duv1.y + dp1perp * duv2.y;
		float inv = inversesqrt(max(max(dot(t, t), dot(b, b)), 1e-12));
		// Na imagem, o verde aponta para cima, que é o sentido de UV.y diminuindo.
		NORMAL = normalize(n + (t * nm.x - b * nm.y) * inv * relief_strength * fade);
	}
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	RIM = rim_amount;
	RIM_TINT = 0.6;
}
