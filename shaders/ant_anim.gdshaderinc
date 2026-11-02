// Animação das formigas, compartilhada pelos shaders de corpo, asas e faro.
// CUSTOM0 = (pivô xyz, parte)  parte: 0 corpo, 1 perna, 2 antena, 3 folha, 4 asa, 5 mandíbula
// CUSTOM1 = (peso, fase do passo, lado -1/+1, livre)
// INSTANCE_CUSTOM = (fase da caminhada, destaque do faro, estado, carregando folha)
//   estado: 0 andando, 1 tonta (de barriga para cima), 2 voando

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

void ant_animate(inout vec3 v, inout vec3 n, vec4 c0, vec4 c1, vec4 inst, float id, float time) {
	float state = inst.z;
	float stunned = step(0.5, state) * (1.0 - step(1.5, state));
	float flying = step(1.5, state);
	float gait = mix(inst.x, time * 26.0 + id * 1.7, stunned);
	int part = int(c0.w + 0.5);
	vec3 pivot = c0.xyz;
	float side = c1.z;
	if (part == 1) {
		float ph = gait + c1.y;
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
		float carry = step(0.5, inst.w);
		mat3 r = ant_rot_z(sin(gait * 0.5) * 0.07);
		v = pivot + r * (v - pivot) * carry;
		n = r * n;
	} else if (part == 4) {
		float flap = flying * sin(time * 48.0 + id) * 0.85;
		float fold = (1.0 - flying) * -0.08;
		mat3 r = ant_rot_z((flap + fold) * side);
		v = pivot + r * (v - pivot);
		n = r * n;
	} else if (part == 5) {
		float open = (sin(time * 5.0 + id) * 0.5 + 0.5) * 0.25 * (1.0 - step(0.5, inst.w)) + stunned * 0.3;
		mat3 r = ant_rot_y(open * side);
		v = pivot + r * (v - pivot);
		n = r * n;
	}
	if (part != 1) {
		v.y += sin(gait * 2.0) * body_bob * (1.0 - stunned);
	}
}
