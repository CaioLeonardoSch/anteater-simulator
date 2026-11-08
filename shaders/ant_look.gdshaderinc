// Visual das formigas, igual nas de campo (ant_field.gdshader) e nas simuladas
// (ant.gdshader): casco de quitina brilhante e a folha carregada.
// A folha muda de tom de uma formiga para outra (`seed` 0..1) e tem nervuras;
// uma em cada doze leva uma pétala (rosa ou amarela) no lugar da folha.

uniform float roughness_body : hint_range(0.0, 1.0) = 0.3;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.55;

vec3 ant_leaf_color(vec3 base, vec2 uv, float seed) {
	vec3 green = mix(vec3(0.24, 0.55, 0.12), vec3(0.62, 0.78, 0.2), fract(seed * 3.7));
	green = mix(green, base, 0.25);
	float dx = abs(uv.x - 0.5);
	float midrib = 1.0 - smoothstep(0.018, 0.04, dx);
	float side = smoothstep(0.4, 0.5, abs(fract((uv.y + dx * 0.9) * 5.0) - 0.5)) * (1.0 - midrib);
	vec3 leaf = mix(green, green * 1.5 + vec3(0.08, 0.08, 0.02), max(midrib, side * 0.7));
	vec3 petal = mix(vec3(0.97, 0.56, 0.68), vec3(0.99, 0.82, 0.25), step(0.5, fract(seed * 17.0)));
	petal *= 0.8 + 0.25 * (1.0 - length(uv - vec2(0.5, 0.75)));
	return mix(leaf, petal, step(0.917, seed));
}

void ant_look(vec3 base, float part, vec2 uv, float seed, out vec3 albedo, out float rough,
		out float spec, out float rim, out vec3 back, out float coat) {
	bool leaf = abs(part - 3.0) < 0.5;
	if (leaf) {
		albedo = ant_leaf_color(base, uv, seed);
		rough = 0.65;
		spec = 0.25;
		rim = 0.1;
		back = albedo * 0.6;
		coat = 0.0;
	} else {
		albedo = base;
		rough = roughness_body;
		spec = 0.65;
		rim = rim_amount;
		back = vec3(0.0);
		// Verniz por cima do casco: um brilho fino e definido.
		coat = 0.6;
	}
}
