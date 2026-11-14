shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Corpo das formigas (MultiMesh): quitina brilhante, estilo animação.

#include "res://shaders/ant_anim.gdshaderinc"

#include "res://shaders/ant_look.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float use_albedo_tex : hint_range(0.0, 1.0) = 0.0;
// Brilho do faro (cor configurável); a rainha usa o dourado padrão.
instance uniform vec3 glow_color : source_color = vec3(1.0, 0.75, 0.3);
// Contorno da formiga que a língua vai buscar (cor da mira). COLOR.a < 0.75 marca ela.
uniform vec3 aim_color : source_color = vec3(0.725, 0.89, 0.604);

varying float v_part;
varying float v_highlight;
varying float v_aim;
varying float v_seed;

void vertex() {
	ant_animate(VERTEX, NORMAL, CUSTOM0, CUSTOM1, INSTANCE_CUSTOM, TIME);
	v_part = CUSTOM0.w;
	v_highlight = INSTANCE_CUSTOM.y;
	v_aim = step(COLOR.a, 0.75);
	v_seed = ant_hash(floor(INSTANCE_CUSTOM.z / 4.0 + 0.01) * 0.731);
}

void fragment() {
	vec3 base = COLOR.rgb;
	if (use_albedo_tex > 0.5) {
		base *= texture(albedo_tex, UV).rgb;
	}
	ant_look(base, v_part, UV, v_seed, ALBEDO, ROUGHNESS, SPECULAR, RIM, BACKLIGHT, CLEARCOAT);
	ant_spec_aa(NORMAL, ROUGHNESS, CLEARCOAT);
	CLEARCOAT_ROUGHNESS = 0.2;
	RIM_TINT = 0.35;
	EMISSION = glow_color * v_highlight * 0.5;
	if (v_aim > 0.5) {
		// Brilho nas bordas (vira um contorno suave) que pulsa de leve.
		float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
		EMISSION += aim_color * (edge * 0.9 + 0.04) * (0.8 + 0.2 * sin(TIME * 8.0));
	}
}
