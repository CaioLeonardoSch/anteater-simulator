// Animação das formigas, compartilhada pelos shaders de corpo, asas e faro.
// CUSTOM0 = (pivô xyz, parte)  parte: 0 corpo, 1 perna, 2 antena, 3 folha, 4 asa, 5 mandíbula
// CUSTOM1 = (peso, fase do passo, lado -1/+1, qual formiga do grupo 0..9)
// INSTANCE_CUSTOM = (fase da caminhada, destaque do faro,
//                    estado + 4 * semente, carregando + 2 * formação * 64)
//   estado: 0 andando, 1 tonta (de barriga para cima), 2 voando
//   semente: 0..1023, fixa para cada grupo (para cada formiga ter o seu jeito)
//   formação: 0 sozinha (rainha, tanajura), 1 fila de duas pistas (trilha),
//             2 bando solto (fugindo), 3 bolo apertado (câmara, língua);
//             valores no meio misturam as duas formações vizinhas.
// clip (alfa da cor da instância): esconde as formigas do grupo que passaram
//   deste ponto, em unidades da formiga ao longo da frente (> 0: à frente,
//   < 0: atrás). Usado na boca do formigueiro, onde o grupo entra e sai.

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

// Onde fica a formiga k do grupo (x = lado, y = para a frente) e quanto ela
// vira, em cada formação.
vec3 ant_slot(float formation, float k, float seed, float time) {
	float h1 = ant_hash(seed * 1.37 + k * 7.91);
	float h2 = ant_hash(seed * 4.11 + k * 3.53 + 0.5);
	float h3 = ant_hash(seed * 2.71 + k * 5.17 + 0.25);
	if (formation < 1.5) {
		// Fila de duas pistas, cada formiga balançando um pouco.
		float lane = mod(k, 2.0) * 2.0 - 1.0;
		vec2 off = vec2(lane * 0.62 + (h2 - 0.5) * 0.5, (k - 4.5) * 0.92 + (h3 - 0.5) * 0.5);
		off.x += sin(time * 1.7 + h1 * 30.0) * 0.16;
		off.y += sin(time * 2.3 + h2 * 30.0) * 0.1;
		return vec3(off, (h1 - 0.5) * 0.35 + cos(time * 1.7 + h1 * 30.0) * 0.12);
	}
	float spread = formation < 2.5 ? 1.0 : 0.55;
	float r = sqrt(k + 0.5) * 0.9 * spread;
	float a = k * 2.39996 + seed;
	vec2 off = vec2(cos(a), sin(a)) * r + vec2(h2 - 0.5, h3 - 0.5) * 0.4 * spread;
	return vec3(off, (h1 - 0.5) * 1.6);
}

void ant_animate(inout vec3 v, inout vec3 n, vec4 c0, vec4 c1, vec4 inst, float clip, float time) {
	float state = mod(inst.z, 4.0);
	float seed = floor(inst.z / 4.0 + 0.01);
	float carry = mod(inst.w, 2.0);
	float formation = floor(inst.w / 2.0 + 0.01) / 64.0;
	float k = c1.w;
	float id = seed * 7.31 + k * 3.17;
	float stunned = step(0.5, state) * (1.0 - step(1.5, state));
	float flying = step(1.5, state);
	float gait = mix(inst.x + k * 2.13, time * 26.0 + id * 1.7, stunned);
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
		float has_leaf = step(0.5, carry) * step(0.4, ant_hash(seed * 0.71 + k * 1.93));
		mat3 r = ant_rot_z(sin(gait * 0.5) * 0.07);
		v = pivot + r * (v - pivot) * has_leaf;
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
	}
	if (part != 1) {
		v.y += sin(gait * 2.0) * body_bob * (1.0 - stunned);
	}
	// Grupo: cada formiga no seu lugar, com tamanho, rumo e balanço próprios.
	if (formation > 0.5) {
		vec3 slot;
		if (formation <= 2.0) {
			slot = mix(ant_slot(1.0, k, seed, time), ant_slot(2.0, k, seed, time), clamp(formation - 1.0, 0.0, 1.0));
		} else {
			slot = mix(ant_slot(2.0, k, seed, time), ant_slot(3.0, k, seed, time), clamp(formation - 2.0, 0.0, 1.0));
		}
		float size = 0.86 + ant_hash(seed * 3.3 + k * 1.1) * 0.28;
		float hide = clip >= 0.0 ? step(clip, slot.y) : step(slot.y, clip);
		mat3 r = ant_rot_y(slot.z);
		v = (r * (v * size) + vec3(slot.x, 0.0, -slot.y)) * (1.0 - hide);
		n = r * n;
	}
}
