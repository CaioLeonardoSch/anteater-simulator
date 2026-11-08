shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, skip_vertex_transform;
// Corpo das formigas de campo (trilhas e passeios): a placa de vídeo calcula
// onde cada uma está (ant_field.gdshaderinc). O visual é o de ant.gdshader.

#include "res://shaders/ant_field.gdshaderinc"

#include "res://shaders/ant_look.gdshaderinc"

instance uniform vec3 glow_color : source_color = vec3(1.0, 0.75, 0.3);

varying float v_part;
varying float v_highlight;
varying float v_seed;

void vertex() {
	v_highlight = field_ant(MODEL_MATRIX, VIEW_MATRIX, CUSTOM0, CUSTOM1, VERTEX, NORMAL, 0.0);
	v_part = CUSTOM0.w;
	v_seed = ant_hash(MODEL_MATRIX[2].y * 0.731 + CUSTOM1.w * 13.7);
}

void fragment() {
	vec3 base = COLOR.rgb;
	ant_look(base, v_part, UV, v_seed, ALBEDO, ROUGHNESS, SPECULAR, RIM, BACKLIGHT, CLEARCOAT);
	CLEARCOAT_ROUGHNESS = 0.2;
	RIM_TINT = 0.35;
	EMISSION = glow_color * v_highlight * 0.5;
}
