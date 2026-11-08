shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// Asas da tanajura: película fina, quase transparente e iridescente, com
// nervuras escuras e a mancha (estigma) na beira da frente.
// UV = (ao longo da asa 0..1, para o lado 0..1); UV.y = 0 é a beira da frente.

#include "res://shaders/ant_anim.gdshaderinc"

uniform vec3 vein_color : source_color = vec3(0.32, 0.2, 0.1);

void vertex() {
	ant_animate(VERTEX, NORMAL, CUSTOM0, CUSTOM1, INSTANCE_CUSTOM, TIME);
}

float vline(float d, float w) {
	return 1.0 - smoothstep(w * 0.5, w, abs(d));
}

void fragment() {
	vec2 w = UV;
	float inner = 1.0 - smoothstep(0.7, 0.9, w.x);
	float costa = vline(w.y, 0.08);
	float v1 = vline(w.y - (0.12 + 0.3 * w.x), 0.035) * inner;
	float v2 = vline(w.y - (0.08 + 0.62 * w.x), 0.03) * inner;
	float cross = vline(w.x - 0.52, 0.03) * step(w.y, 0.45);
	float stigma = smoothstep(0.03, 0.0, abs(w.x - 0.6) - 0.06) * (1.0 - smoothstep(0.08, 0.14, w.y));
	float vein = max(max(costa, stigma), max(max(v1, v2), cross) * 0.85);
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	vec3 irid = 0.5 + 0.5 * cos(6.2831 * (fres * 1.2 + w.x * 0.6 + vec3(0.0, 0.33, 0.67)));
	vec3 film = mix(vec3(0.78, 0.72, 0.62), irid, 0.45);
	ALBEDO = mix(film, vein_color, vein);
	ALPHA = mix(0.2 + fres * 0.4, 0.92, vein);
	ROUGHNESS = mix(0.12, 0.5, vein);
	SPECULAR = 0.9;
}
