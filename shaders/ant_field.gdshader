shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, skip_vertex_transform;
// Corpo das formigas de campo (trilhas e passeios): a placa de vídeo calcula
// onde cada uma está (ant_field.gdshaderinc). O visual é o de ant.gdshader.

#include "res://shaders/ant_field.gdshaderinc"

uniform float roughness_body : hint_range(0.0, 1.0) = 0.3;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.55;
instance uniform vec3 glow_color : source_color = vec3(1.0, 0.75, 0.3);

varying float v_part;
varying float v_highlight;

void vertex() {
	v_highlight = field_ant(MODEL_MATRIX, VIEW_MATRIX, CUSTOM0, CUSTOM1, VERTEX, NORMAL, 0.0);
	v_part = CUSTOM0.w;
}

void fragment() {
	vec3 base = COLOR.rgb;
	bool leaf = abs(v_part - 3.0) < 0.5;
	ALBEDO = base;
	ROUGHNESS = leaf ? 0.65 : roughness_body;
	SPECULAR = leaf ? 0.25 : 0.65;
	RIM = leaf ? 0.1 : rim_amount;
	RIM_TINT = 0.35;
	BACKLIGHT = leaf ? base * 0.6 : vec3(0.0);
	EMISSION = glow_color * v_highlight * 0.5;
}
