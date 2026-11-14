shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley, specular_schlick_ggx;
// Capim dourado do cerrado: balança com o vento, abre caminho para o tamanduá
// e brilha contra o sol baixo (translucidez).

global uniform vec3 player_pos;
global uniform vec2 wind_dir;
global uniform float wind_strength;

uniform vec3 base_color : source_color = vec3(0.30, 0.27, 0.10);
uniform vec3 mid_color : source_color = vec3(0.70, 0.56, 0.22);
uniform vec3 tip_color : source_color = vec3(0.96, 0.84, 0.52);
uniform vec3 green_color : source_color = vec3(0.46, 0.54, 0.20);
uniform vec3 copper_tint = vec3(1.08, 0.78, 0.58);
uniform vec3 straw_color : source_color = vec3(0.95, 0.88, 0.68);
uniform vec3 seed_color : source_color = vec3(0.80, 0.46, 0.32);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float fade_start = 34.0;
uniform float fade_end = 48.0;
uniform float sway_amount = 0.13;
// Perto da câmera os tufos somem (encolhem até o chão, cada um a uma distância
// um pouco diferente), para o capim não tapar as formigas nem a tela.
uniform float near_fade_start = 0.5;
uniform float near_fade_end = 1.9;

varying float vh;
varying float vrand;
varying vec3 vworld;
// 0..1 da base à ponta da folha; 1 nos pendões; sorteio de cada touceira.
varying float vt;
varying float vseed;
varying float vtuft;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vh = COLOR.r;
	vrand = COLOR.g;
	vt = COLOR.a;
	vseed = COLOR.b;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vtuft = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);

	float t = TIME;
	vec2 wuv = origin.xz * 0.03 + wind_dir * t * 0.05;
	float gust = textureLod(noise_tex, wuv, 0.0).r;
	float wave = sin(t * 1.9 + dot(origin.xz, vec2(0.45, 0.31)) + vrand * 6.28) * 0.3;
	float sway = (wave + (gust - 0.4) * 1.6) * wind_strength;
	float bend = vh * vh;
	vec3 offset = vec3(wind_dir.x, 0.0, wind_dir.y) * sway * sway_amount * bend;
	// Pequeno tremor lateral.
	offset.xz += vec2(-wind_dir.y, wind_dir.x) * sin(t * 3.7 + vrand * 20.0) * 0.012 * bend;

	// O capim se abre quando o tamanduá passa.
	vec2 d = VERTEX.xz - player_pos.xz;
	float pd = length(d);
	float push = (1.0 - smoothstep(0.3, 1.25, pd)) * vh;
	offset.xz += (d / max(pd, 0.001)) * push * 0.38;
	offset.y -= push * 0.22;
	offset.y -= length(offset.xz) * 0.35 * vh;

	float cam_d = distance(origin, cam);
	float fade = 1.0 - smoothstep(fade_start, fade_end, cam_d);
	float near = smoothstep(near_fade_start, near_fade_end, distance(origin.xz, cam.xz));
	fade *= clamp((near - vrand * 0.85) * 5.0, 0.0, 1.0);
	VERTEX = origin + (VERTEX - origin) * fade + offset * fade;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.45));
	vworld = VERTEX;
}

void fragment() {
	// Com MSAA a placa de vídeo pinta a beirada da folha fina num ponto que cai
	// fora dela, e esses valores "passam do ponto" (muito claros ou pretos,
	// piscando quando o capim balança). Trava tudo na faixa certa.
	float fh = clamp(vh, 0.0, 1.0);
	float ft = clamp(vt, 0.0, 1.0);
	float fr = clamp(vrand, 0.0, 1.0);
	float fs = clamp(vseed, 0.0, 1.0);
	float ftu = clamp(vtuft, 0.0, 1.0);
	vec3 col = mix(base_color, mid_color, smoothstep(0.0, 0.5, fh));
	col = mix(col, tip_color, smoothstep(0.45, 1.0, fh));
	float patch = texture(noise_tex, vworld.xz * 0.018 + 0.5).r;
	col = mix(col, green_color * (0.6 + fh * 0.6), smoothstep(0.62, 0.8, patch) * 0.55);
	// Cada touceira com seu tom: umas acobreadas, outras verde-oliva, outras
	// cor de palha clara; o resto fica no dourado do campo.
	float base_k = smoothstep(0.0, 0.5, fh);
	col = mix(col, col * copper_tint, (1.0 - smoothstep(0.12, 0.2, ftu)) * base_k);
	col = mix(col, mix(col, green_color * 1.1, 0.5), smoothstep(0.2, 0.25, ftu) * (1.0 - smoothstep(0.32, 0.37, ftu)));
	col = mix(col, straw_color, smoothstep(0.84, 0.9, ftu) * 0.45 * base_k);
	// Umas folhas mais secas e amarronzadas no meio das outras.
	col = mix(col, col * vec3(0.82, 0.66, 0.5), smoothstep(0.8, 0.9, fr) * (1.0 - fs));
	col *= 0.82 + fr * 0.32;
	// Ponta seca e desbotada.
	col = mix(col, straw_color, smoothstep(0.72, 1.0, ft) * 0.5 * (1.0 - fs));
	// Nervura clara no meio da folha e beiradas mais escuras (dá volume).
	float edge = min(abs(UV.x - 0.5) * 2.0, 1.0);
	col *= mix(1.0, mix(1.14, 0.8, edge * edge), 1.0 - fs);
	col = mix(col, col * 1.18 + vec3(0.03), (1.0 - smoothstep(0.0, 0.18, edge)) * 0.5 * (1.0 - fs) * base_k);
	// Pendões: haste cor de palha e espiga avermelhada, com a beira felpuda clara.
	float head = smoothstep(0.55, 0.68, ft);
	vec3 seed_col = mix(straw_color * 0.85, mix(seed_color, straw_color, edge * 0.7), head);
	col = mix(col, seed_col * (0.85 + ftu * 0.3), fs);
	ALBEDO = col;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	vec3 up_v = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, up_v, 0.35));
	BACKLIGHT = col * mix(0.75 * (0.3 + fh), 1.1, fs * head);
	AO = mix(0.35, 1.0, smoothstep(0.0, 0.6, fh));
	AO_LIGHT_AFFECT = 0.6;
}
