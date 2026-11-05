// Animação das formigas, compartilhada pelos shaders de corpo, asas e faro.
// CUSTOM0 = (pivô xyz, parte)  parte: 0 corpo, 1 perna, 2 antena, 3 folha, 4 asa,
//           5 mandíbula, 6 chapéu de Natal
// CUSTOM1 = (peso, fase do passo, lado -1/+1, 0)
// Formigas simuladas pelo jogo (ant.gdshader): INSTANCE_CUSTOM =
//   (fase da caminhada, destaque do faro, estado + 4 * semente, folha + 2 * chapéu)
//   estado: 0 andando, 1 tonta (de barriga para cima), 2 voando
//   semente: 0..1023, fixa para cada formiga (cada uma tem o seu jeito)

uniform float leg_swing = 0.42;
uniform float leg_lift = 0.32;
uniform float body_bob = 0.012;

mat3 ant_rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

mat3 ant_rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 ant_rot_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

float ant_hash(float x) {
	return fract(sin(x * 12.9898 + 4.1414) * 43758.5453);
}

// Mexe as partes da formiga (no espaço dela): pernas, antenas, folha, asas,
// mandíbulas e o chapéu.
void ant_parts(inout vec3 v, inout vec3 n, vec4 c0, vec4 c1, float gait, float state, float seed,
		float carry, float hat, float time) {
	float id = seed * 7.31;
	float stunned = step(0.5, state) * (1.0 - step(1.5, state));
	float flying = step(1.5, state);
	float g = mix(gait, time * 26.0 + id * 1.7, stunned);
	int part = int(c0.w + 0.5);
	vec3 pivot = c0.xyz;
	float side = c1.z;
	if (part == 1) {
		float ph = g + c1.y;
		float swing = sin(ph) * leg_swing * side * (1.0 - flying * 0.8);
		float lift = max(0.0, cos(ph)) * leg_lift * (1.0 - flying) - flying * 0.5;
		mat3 r = ant_rot_z(lift * side) * ant_rot_y(swing);
		v = pivot + r * (v - pivot);
		n = r * n;
	} else if (part == 2) {
		float a = sin(time * 3.1 + id * 0.77 + side) * 0.22 + stunned * sin(time * 17.0 + side) * 0.3;
		float b = sin(time * 2.3 + id * 1.3) * 0.16;
		mat3 r = ant_rot_y(a * side) * ant_rot_x(b);
		v = pivot + r * (v - pivot);
		n = r * n;
	} else if (part == 3) {
		mat3 r = ant_rot_z(sin(g * 0.5) * 0.07);
		v = pivot + r * (v - pivot) * step(0.5, carry);
		n = r * n;
	} else if (part == 4) {
		float flap = flying * sin(time * 48.0 + id) * 0.85;
		float fold = (1.0 - flying) * -0.08;
		mat3 r = ant_rot_z((flap + fold) * side);
		v = pivot + r * (v - pivot);
		n = r * n;
	} else if (part == 5) {
		float open = (sin(time * 5.0 + id) * 0.5 + 0.5) * 0.25 * (1.0 - step(0.5, carry)) + stunned * 0.3;
		mat3 r = ant_rot_y(open * side);
		v = pivot + r * (v - pivot);
		n = r * n;
	} else if (part == 6) {
		// Chapéu de Natal: só nas formigas sorteadas; balança com o passo.
		mat3 r = ant_rot_x(sin(g * 0.5) * 0.12) * ant_rot_z(sin(g * 0.5 + 1.3) * 0.08);
		v = pivot + r * (v - pivot) * step(0.5, hat);
		n = r * n;
	}
	if (part != 1) {
		v.y += sin(g * 2.0) * body_bob * (1.0 - stunned);
	}
}

// Formigas simuladas pelo jogo (MultiMesh com transformação normal).
void ant_animate(inout vec3 v, inout vec3 n, vec4 c0, vec4 c1, vec4 inst, float time) {
	float state = mod(inst.z, 4.0);
	float seed = floor(inst.z / 4.0 + 0.01);
	float carry = mod(inst.w, 2.0);
	float hat = step(1.5, inst.w);
	ant_parts(v, n, c0, c1, inst.x, state, seed, carry, hat, time);
}
