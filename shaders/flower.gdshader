shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley;
// Florzinhas do campo (MultiMesh). COLOR.r = altura (0 base .. 1 topo),
// COLOR.g = 1 nas pétalas, COLOR.b = 1 no miolo, COLOR.a = 0..1 da base à
// ponta da pétala; a cor de cada flor vem da instância.

global uniform vec3 player_pos;
global uniform vec2 wind_dir;
global uniform float wind_strength;

uniform vec3 stem_color : source_color = vec3(0.35, 0.45, 0.16);
// Miolo amarelo (flores claras, roxas, rosas) e marrom (flores amarelas e laranja).
uniform vec3 center_yellow : source_color = vec3(0.98, 0.76, 0.16);
uniform vec3 center_brown : source_color = vec3(0.50, 0.27, 0.08);
uniform float fade_start = 26.0;
uniform float fade_end = 38.0;

varying float vh;
varying float vpetal;
varying float vcenter;
varying float vpos;
varying float vrand;
varying vec3 vinst;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = COLOR.r;
	vh = h;
	vpetal = COLOR.g;
	vcenter = COLOR.b;
	vpos = COLOR.a;
	vinst = INSTANCE_CUSTOM.rgb;
	vrand = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float sway = sin(TIME * 2.1 + origin.x * 0.7 + origin.z * 0.5) * 0.06 * wind_strength * h;
	vec3 offset = vec3(wind_dir.x, 0.0, wind_dir.y) * sway;
	vec2 d = VERTEX.xz - player_pos.xz;
	float pd = length(d);
	float push = (1.0 - smoothstep(0.3, 1.1, pd)) * h;
	offset.xz += (d / max(pd, 0.001)) * push * 0.3;
	offset.y -= push * 0.15;
	float fade = 1.0 - smoothstep(fade_start, fade_end, distance(origin, INV_VIEW_MATRIX[3].xyz));
	VERTEX = origin + (VERTEX - origin) * fade + offset * fade;
}

void fragment() {
	// Com MSAA a beirada das pétalas finas é pintada num ponto fora delas e os
	// valores passam do ponto (pontinhos claros piscando): trava na faixa certa.
	float fh = clamp(vh, 0.0, 1.0);
	float fp = clamp(vpetal, 0.0, 1.0);
	float fc = clamp(vcenter, 0.0, 1.0);
	float fpo = clamp(vpos, 0.0, 1.0);
	float fr = clamp(vrand, 0.0, 1.0);
	// Caule mais escuro embaixo.
	vec3 stem = stem_color * (0.65 + 0.5 * fh);
	// Pétala: mais funda perto do miolo, clara e viva na ponta.
	vec3 tone = vinst * (0.9 + fr * 0.2);
	vec3 petal = mix(tone * vec3(0.68, 0.62, 0.62), min(tone * 1.1 + 0.03, vec3(1.0)), smoothstep(0.05, 0.85, fpo));
	float yellow = smoothstep(0.3, 0.6, (vinst.r + vinst.g) * 0.5 - vinst.b);
	vec3 center = mix(center_yellow, center_brown, yellow);
	vec3 col = mix(stem, petal, fp);
	col = mix(col, center, fc);
	ALBEDO = col;
	ROUGHNESS = 0.7;
	BACKLIGHT = col * mix(0.35, 0.65, fp);
	EMISSION = petal * fp * 0.04;
}
