// Formigas "de campo": as das trilhas e as que passeiam em volta das câmaras.
// A placa de vídeo calcula onde cada uma está a cada quadro, a partir de uns
// poucos números por formiga (o jogo faz a mesma conta quando precisa: em
// ant_field.gd). Os números vão na transformação da instância da MultiMesh
// (12 números, f0..f11) e a cor na cor da instância.
//
// Trilha (field_kind 0): f0 linha da trilha na textura, f1 comprimento,
//   f2 fase, f3 voltas por segundo, f4 desvio para o lado, f5 tamanho,
//   f6 semente, f7 folha + 2 * chapéu, f8 viva, f9 fim do brilho do faro,
//   f10 velocidade (m/s).
// Passeio (field_kind 1): f0, f1 a câmara (x, z), f2 alcance, f3 passeios por
//   segundo, f4 fase, f5 tamanho, f6 semente, f7 folha + 2 * chapéu, f8 viva,
//   f9 fim do brilho do faro, f10 rumo, f11 quanto o passeio faz a curva.

#include "res://shaders/ant_anim.gdshaderinc"

uniform sampler2D trail_tex : filter_nearest, repeat_disable;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform float height_size = 160.0;
uniform float trail_step = 0.25;
uniform int field_kind = 0;
// Relógio das formigas e a câmera do jogador (para o nível de detalhe).
uniform float ant_time = 0.0;
uniform vec3 ant_cam = vec3(0.0);
// Faixa de distância (m) que esta camada desenha.
instance uniform vec2 lod_band = vec2(0.0, 100000.0);

float field_ground(vec2 p) {
	return texture(height_tex, p / height_size + 0.5).r;
}

vec3 field_trail_point(int row, int i) {
	return texelFetch(trail_tex, ivec2(i, row), 0).xyz;
}

// Põe a formiga no mundo. `halo` > 0 engorda a formiga (o brilho do faro).
// Retorna o destaque do faro (0..1).
float field_ant(mat4 m, mat4 view, vec4 c0, vec4 c1, inout vec3 vtx, inout vec3 nrm, float halo) {
	float f0 = m[0].x;
	float f1 = m[1].x;
	float f2 = m[2].x;
	float f3 = m[3].x;
	float f4 = m[0].y;
	float f5 = m[1].y;
	float f6 = m[2].y;
	float f7 = m[3].y;
	float f8 = m[0].z;
	float f9 = m[1].z;
	float f10 = m[2].z;
	float f11 = m[3].z;
	float t = ant_time;
	float seed = f6;
	float size = f5;
	float leaf = mod(f7, 2.0);
	float hat = step(1.5, f7);
	vec3 pos;
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 fwd;
	float carry = 0.0;
	bool hidden = false;
	float gait;
	if (field_kind == 0) {
		float len = f1;
		float q = fract(f2 + t * f3);
		float dir = q < 0.5 ? 1.0 : -1.0;
		float s = (q < 0.5 ? 2.0 * q : 2.0 - 2.0 * q) * len;
		int row = int(f0 + 0.5);
		int last = int(len / trail_step + 0.5);
		float fi = clamp(s / trail_step, 0.0, float(last) - 0.001);
		int i = int(fi);
		float k = fi - float(i);
		vec3 a = field_trail_point(row, i);
		vec3 b = field_trail_point(row, i + 1);
		vec3 a2 = field_trail_point(row, max(i - 1, 0));
		vec3 b2 = field_trail_point(row, min(i + 2, last));
		vec2 tan = normalize(b.xy - a.xy + vec2(1e-5, 0.0));
		vec2 side = vec2(-tan.y, tan.x);
		float lat = f4 + 0.03 * sin(t * 1.3 + seed * 0.039);
		vec2 p2 = mix(a.xy, b.xy, k) + side * lat;
		float slope = (b2.z - a2.z) / max(distance(b2.xy, a2.xy), 0.01);
		pos = vec3(p2.x, mix(a.z, b.z, k), p2.y);
		vec3 along = normalize(vec3(tan.x, slope, tan.y));
		up = normalize(cross(vec3(side.x, 0.0, side.y), along));
		fwd = along * dir;
		carry = dir < 0.0 ? leaf : 0.0;
		hidden = s < 0.2;
		gait = t * f10 / (size * 0.32) + seed;
	} else {
		float c = f4 + t * f3;
		float cyc = floor(c);
		float u = c - cyc;
		float reach = f2 * (0.75 + 0.25 * sin(cyc * 2.1 + seed * 0.013));
		float w = u * 12.566 + seed * 0.05;
		float th = f10 + cyc * 2.39996 + (u - 0.5) * f11 + 0.22 * sin(w);
		float rho = reach * sin(3.14159265 * u);
		vec2 d = vec2(cos(th), sin(th));
		vec2 p2 = vec2(f0, f1) + d * rho;
		float dth = f11 + 0.22 * 12.566 * cos(w);
		vec2 dp = d * reach * 3.14159265 * cos(3.14159265 * u) + vec2(-d.y, d.x) * rho * dth;
		vec2 fw = normalize(dp + vec2(1e-5, 0.0));
		float e = 0.3;
		float hx = field_ground(p2 + vec2(e, 0.0)) - field_ground(p2 - vec2(e, 0.0));
		float hz = field_ground(p2 + vec2(0.0, e)) - field_ground(p2 - vec2(0.0, e));
		up = normalize(vec3(-hx, 2.0 * e, -hz));
		pos = vec3(p2.x, field_ground(p2), p2.y);
		fwd = vec3(fw.x, 0.0, fw.y);
		carry = u > 0.5 ? leaf : 0.0;
		hidden = rho < 0.15;
		gait = t * 0.55 / (size * 0.32) + seed;
	}
	vec3 F = normalize(fwd - up * dot(fwd, up));
	vec3 X = cross(F, up);
	vec3 Z = -F;
	vec3 v = vtx;
	vec3 n = nrm;
	ant_parts(v, n, c0, c1, gait, 0.0, seed, carry, hat, t);
	if (halo > 0.0) {
		v += n * (0.07 + 0.03 * sin(t * 6.0 + seed));
		v = (v - vec3(0.0, 0.2, 0.0)) * 1.35 + vec3(0.0, 0.2, 0.0);
	}
	float dist = distance(pos, ant_cam);
	bool drop = f8 < 0.5 || hidden || dist < lod_band.x || dist >= lod_band.y;
	vec3 world = pos + (X * v.x + up * v.y + Z * v.z) * size;
	if (drop) {
		world = vec3(0.0, -500.0, 0.0);
	}
	vtx = (view * vec4(world, 1.0)).xyz;
	nrm = normalize((view * vec4(X * n.x + up * n.y + Z * n.z, 0.0)).xyz);
	return clamp(f9 - t, 0.0, 1.0);
}
