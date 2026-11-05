shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_back, skip_vertex_transform;
// Faro do tamanduá nas formigas de campo: as farejadas brilham através do capim.

#include "res://shaders/ant_field.gdshaderinc"

global uniform float sniff_amount;
uniform vec3 tint : source_color = vec3(1.0, 0.16, 0.12);

varying float v_highlight;

void vertex() {
	v_highlight = field_ant(MODEL_MATRIX, VIEW_MATRIX, CUSTOM0, CUSTOM1, VERTEX, NORMAL, 1.0);
}

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	float a = v_highlight * sniff_amount;
	ALBEDO = tint * (0.4 + fres * 0.9) * a;
	ALPHA = a;
}
