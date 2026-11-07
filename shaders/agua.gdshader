shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;
// Água das lagoas. Escura e funda no meio, transparente na beira (mostra o
// fundo), com ondinhas andando com o vento e brilhos do sol. Reflete o céu (o
// próprio céu do jogo) e, perto do horizonte, o paredão de arenito em volta da
// clareira (de mentira: um anel na distância e na altura do paredão).

global uniform vec2 wind_dir;
global uniform float wind_strength;

uniform sampler2D ripple_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

uniform vec3 deep_color : source_color = vec3(0.03, 0.09, 0.1);
uniform vec3 shallow_color : source_color = vec3(0.24, 0.22, 0.13);
uniform vec3 cliff_color : source_color = vec3(0.52, 0.28, 0.18);
// Anel do paredão (metros, a partir do centro do mapa). A altura é menor que a
// de verdade: assim a parte de perto da lagoa mostra o céu e lê como água.
uniform float cliff_radius = 66.0;
uniform float cliff_height = 3.5;
// Céu refletido (vem de world.gd, com o dia).
uniform vec3 sky_low : source_color = vec3(0.66, 0.62, 0.74);
uniform vec3 sky_high : source_color = vec3(0.26, 0.36, 0.62);
uniform float sky_energy = 0.8;

// Tamanho das ondinhas (m) e força delas.
uniform float ripple_size_a = 4.5;
uniform float ripple_size_b = 1.6;
uniform float ripple_strength : hint_range(0.0, 1.5) = 0.2;
uniform float ripple_speed = 0.22;
// Profundidade (m) em que a água já esconde o fundo.
uniform float clear_depth = 0.45;
// Largura (m de água) da beira que some aos poucos.
uniform float edge_soft = 0.05;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Ondinhas: duas leituras andando em direções diferentes, mais fortes com vento.
	vec2 w = length(wind_dir) > 0.01 ? normalize(wind_dir) : vec2(0.8, 0.6);
	float spd = ripple_speed * (0.6 + wind_strength);
	vec2 ua = (wpos.xz + w * TIME * spd) / ripple_size_a;
	vec2 ub = (wpos.xz - vec2(-w.y, w.x) * TIME * spd * 0.6) / ripple_size_b + 0.37;
	vec2 na = texture(ripple_tex, ua).rg * 2.0 - 1.0;
	vec2 nb = texture(ripple_tex, ub).rg * 2.0 - 1.0;
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(25.0, 70.0, dist) * 0.7;
	vec2 slope = (na + nb * 0.3) * ripple_strength * fade;
	vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	float fres = 0.03 + 0.97 * pow(1.0 - ndv, 5.0);

	// Quanta água há entre a superfície e o fundo (na vertical).
	float zs = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zs, 1.0);
	vp.xyz /= vp.w;
	float thick = max(length(vp.xyz) - length(VERTEX), 0.0);
	float depth = thick * max(v.y, 0.05);
	// A cor e a transparência dependem do caminho da luz dentro da água (de lado,
	// ele é longo mesmo no raso); a beira some pela profundidade na vertical.
	float deep = smoothstep(0.0, clear_depth, thick);
	vec3 col = mix(shallow_color, deep_color, deep);

	// Reflexo do paredão: onde o raio refletido bate no anel antes de passar
	// por cima dele.
	// (com as ondinhas mais fracas, para o reflexo tremer sem virar chuvisco)
	vec3 r = reflect(-v, normalize(vec3(-slope.x * 0.4, 1.0, -slope.y * 0.4)));
	float rh = max(length(r.xz), 1e-4);
	vec2 d = r.xz / rh;
	float b = dot(wpos.xz, d);
	float c = dot(wpos.xz, wpos.xz) - cliff_radius * cliff_radius;
	float t = -b + sqrt(max(b * b - c, 0.0));
	float top = cliff_height / max(t, 1.0);
	float rel = r.y / rh;
	float hit = 1.0 - smoothstep(top * 0.8, top * 1.05, rel);
	float band = 0.85 + 0.15 * sin(rel / top * 22.0 + 1.3);
	// Copas das árvores em cima do paredão: uma faixa escura no alto.
	band *= 1.0 - 0.45 * smoothstep(0.82, 0.95, rel / top);
	vec3 refl = cliff_color * band * mix(0.75, 1.0, smoothstep(0.0, top, rel));
	float k = clamp(fres * 2.5, 0.0, 0.55) * hit;
	// Céu: as cores do céu do jogo (o mundo atualiza junto com o dia), puxadas
	// para o azul do alto, só onde o reflexo passa por cima do paredão.
	float up = smoothstep(top, top + 0.8, rel);
	vec3 skyc = mix(sky_low, sky_high, 0.55 + 0.45 * up);
	float ks = clamp(0.12 + fres * 1.5, 0.0, 0.85) * (1.0 - hit);
	ALBEDO = mix(col, refl, k) * (1.0 - ks);
	EMISSION = skyc * ks * sky_energy;

	// Brilho do sol nas ondinhas.
	ROUGHNESS = 0.1;
	METALLIC = 0.0;
	SPECULAR = 0.15;

	float edge = smoothstep(0.0, edge_soft, depth);
	ALPHA = clamp(mix(0.25, 0.94, deep) + fres * 0.6, 0.0, 1.0) * edge;
}
