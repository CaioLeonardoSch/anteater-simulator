shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_back;
// Faro do tamanduá: formigas farejadas brilham através do capim.

#include "res://shaders/ant_anim.gdshaderinc"

global uniform float sniff_amount;
uniform vec3 tint : source_color = vec3(1.0, 0.16, 0.12);

varying float v_highlight;

void vertex() {
	ant_animate(VERTEX, NORMAL, CUSTOM0, CUSTOM1, INSTANCE_CUSTOM, float(INSTANCE_ID), TIME);
	// Halo maior que a formiga, pulsando, para ser visto de longe.
	VERTEX += NORMAL * (0.07 + 0.03 * sin(TIME * 6.0 + float(INSTANCE_ID)));
	VERTEX = (VERTEX - vec3(0.0, 0.2, 0.0)) * 1.35 + vec3(0.0, 0.2, 0.0);
	v_highlight = INSTANCE_CUSTOM.y;
}

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	float a = v_highlight * sniff_amount;
	ALBEDO = tint * (0.4 + fres * 0.9) * a;
	ALPHA = a;
}
