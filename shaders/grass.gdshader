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
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float fade_start = 34.0;
uniform float fade_end = 48.0;
uniform float sway_amount = 0.13;

varying float vh;
varying float vrand;
varying vec3 vworld;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vh = COLOR.r;
	vrand = COLOR.g;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;

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

	float fade = 1.0 - smoothstep(fade_start, fade_end, distance(origin, cam));
	VERTEX = origin + (VERTEX - origin) * fade + offset * fade;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.45));
	vworld = VERTEX;
}

void fragment() {
	vec3 col = mix(base_color, mid_color, smoothstep(0.0, 0.5, vh));
	col = mix(col, tip_color, smoothstep(0.45, 1.0, vh));
	float patch = texture(noise_tex, vworld.xz * 0.018 + 0.5).r;
	col = mix(col, green_color * (0.6 + vh * 0.6), smoothstep(0.62, 0.8, patch) * 0.55);
	col *= 0.82 + vrand * 0.32;
	ALBEDO = col;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	vec3 up_v = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, up_v, 0.35));
	BACKLIGHT = col * 0.75 * (0.3 + vh);
	AO = mix(0.35, 1.0, smoothstep(0.0, 0.6, vh));
	AO_LIGHT_AFFECT = 0.6;
}
