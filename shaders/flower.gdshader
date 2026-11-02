shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley;
// Florzinhas do campo (MultiMesh). COLOR.r = altura (0 base .. 1 topo),
// COLOR.g = 1 nas pétalas; a cor de cada flor vem da instância.

global uniform vec3 player_pos;
global uniform vec2 wind_dir;
global uniform float wind_strength;

uniform vec3 stem_color : source_color = vec3(0.35, 0.45, 0.16);
uniform float fade_start = 26.0;
uniform float fade_end = 38.0;

varying float vpetal;
varying vec3 vinst;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = COLOR.r;
	vpetal = COLOR.g;
	vinst = INSTANCE_CUSTOM.rgb;
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
	vec3 col = mix(stem_color, vinst, vpetal);
	ALBEDO = col;
	ROUGHNESS = 0.7;
	BACKLIGHT = col * 0.5;
	EMISSION = vinst * vpetal * 0.04;
}
