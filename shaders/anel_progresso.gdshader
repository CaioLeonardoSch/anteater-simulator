shader_type spatial;
// Anel pequeno virado para a câmera: a borda vai enchendo (progress 0..1),
// a partir do topo, no sentido do relógio. Usado nos cogumelos que crescem.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

instance uniform float progress = 0.0;
uniform vec4 fill_color : source_color = vec4(1.0, 0.82, 0.42, 1.0);
uniform vec4 track_color : source_color = vec4(0.12, 0.08, 0.05, 0.55);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float aa = fwidth(r) * 1.2;
	float ring = smoothstep(0.62 - aa, 0.62 + aa, r) * (1.0 - smoothstep(0.92 - aa, 0.92 + aa, r));
	float t = atan(p.x, -p.y) / 6.2831853 + 0.5;
	t = fract(t + 0.5);
	vec4 c = t < progress ? fill_color : track_color;
	ALBEDO = c.rgb;
	ALPHA = c.a * ring;
}
