shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// Asas translúcidas e iridescentes da tanajura.

#include "res://shaders/ant_anim.gdshaderinc"

varying vec3 v_local;

void vertex() {
	ant_animate(VERTEX, NORMAL, CUSTOM0, CUSTOM1, INSTANCE_CUSTOM, COLOR.a, TIME);
	v_local = VERTEX;
}

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	vec3 irid = 0.5 + 0.5 * cos(6.2831 * (fres * 1.2 + vec3(0.0, 0.33, 0.67)));
	ALBEDO = mix(vec3(0.92, 0.95, 1.0), irid, 0.35);
	ALPHA = 0.28 + fres * 0.45;
	ROUGHNESS = 0.15;
	SPECULAR = 0.9;
}
