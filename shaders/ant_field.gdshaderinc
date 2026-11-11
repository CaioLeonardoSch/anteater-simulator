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
// Pedras e troncos (sobem) e arbustos (contornam): ant_ground.gd.
// RG desvio, B altura acima do chão, A escondida embaixo das folhas.
uniform sampler2D props_tex : filter_linear, repeat_disable;
uniform float props_size = 64.0;
// Troncos das árvores (a formiga sobe): em volta de cada um, RG = do ponto até
// o pé do tronco, B = qual tronco, A = 1. trunk_data: 7 pontos do tronco
// (xyz, raio) e um texel com (até onde sobe, raio do pé, alcance, começo da subida).
uniform sampler2D trunk_tex : filter_linear, repeat_disable;
uniform sampler2D trunk_data : filter_nearest, repeat_disable;
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

vec4 field_props(vec2 p) {
	vec2 uv = p / props_size + 0.5;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return vec4(0.0);
	}
	return texture(props_tex, uv);
}

float field_surface(vec2 p) {
	return field_ground(p) + field_props(p).b;
}

// Perto de um tronco: 1 = a formiga fica em `p` (chegando ou subindo), com
// `side` = para fora do tronco e `lift` = quanto já subiu (m); 2 = escondida
// (atravessando o meio, lá em cima); 0 = longe de troncos.
int field_climb(vec2 raw, out vec3 p, out vec3 side, out float lift) {
	p = vec3(0.0);
	side = vec3(0.0, 1.0, 0.0);
	lift = 0.0;
	vec2 uv = raw / props_size + 0.5;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return 0;
	}
	vec4 tk = texture(trunk_tex, uv);
	if (tk.a < 0.999) {
		return 0;
	}
	int ti = int(tk.b + 0.5);
	vec4 meta = texelFetch(trunk_data, ivec2(7, ti), 0);
	float r = meta.g;
	vec2 off = -tk.rg;
	float d = length(off);
	float outer = r + meta.b;
	float inner = r + meta.a;
	if (d >= outer) {
		return 0;
	}
	if (d < 0.05) {
		return 2;
	}
	vec2 n = off / d;
	vec2 c = raw + tk.rg;
	if (d >= inner) {
		vec2 q = c + n * (r + (d - inner) / (outer - inner) * (outer - r));
		p = vec3(q.x, field_ground(q) + field_props(q).b, q.y);
		return 1;
	}
	float f = (1.0 - (d / inner) * (d / inner)) * meta.r;
	int k = min(int(f), 5);
	float u = f - float(k);
	vec4 a = mix(texelFetch(trunk_data, ivec2(k, ti), 0), texelFetch(trunk_data, ivec2(k + 1, ti), 0), u);
	vec2 q = a.xz + n * a.w;
	float g = field_ground(q);
	p = vec3(q.x, max(a.y, g), q.y);
	lift = p.y - g;
	side = vec3(n.x, 0.0, n.y);
	return 1;
}

// Câmara do passeio (na cor extra da instância, igual para o grupo todo):
// x raio, y altura do morrinho da tampa (> 0) ou da terra tirada em volta da
// câmara aberta (< 0), z raio do buraco do meio, w altura da beirada dele (em
// raios do buraco). Tudo 0 = nada (trilhas). A formiga sobe na tampa e, no
// buraco, afunda até sumir (ant_field.gd faz a mesma conta).
const float HOLE_SINK = 0.2;
const float HOLE_SPREAD = 3.2;

float field_home(vec4 ic, vec2 off) {
	float d = length(off);
	float t = d / ic.x;
	float h = 0.0;
	if (ic.y > 0.0) {
		h = ic.y * pow(max(1.0 - t * t, 0.0), 1.4);
	} else if (ic.y < 0.0) {
		h = -ic.y * exp(-pow((t - 1.07) / 0.15, 2.0));
	}
	if (ic.z > 0.0) {
		float q = d / ic.z;
		h += ic.z * ic.w * exp(-(q - 1.5) * (q - 1.5)) * (1.0 - smoothstep(HOLE_SPREAD * 0.71, HOLE_SPREAD, q));
		h -= HOLE_SINK * (1.0 - smoothstep(0.0, 1.3, q));
	}
	return h;
}

vec3 field_trail_point(int row, int i) {
	return texelFetch(trail_tex, ivec2(i, row), 0).xyz;
}

// Põe a formiga no mundo. `halo` > 0 engorda a formiga (o brilho do faro).
// Retorna o destaque do faro (0..1).
float field_ant(mat4 m, mat4 view, vec4 c0, vec4 c1, vec4 ic, inout vec3 vtx, inout vec3 nrm, float halo) {
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
		vec2 raw = vec2(f0, f1) + d * rho;
		float dth = f11 + 0.22 * 12.566 * cos(w);
		vec2 dp = d * reach * 3.14159265 * cos(3.14159265 * u) + vec2(-d.y, d.x) * rho * dth;
		vec2 fw = normalize(dp + vec2(1e-5, 0.0));
		vec3 cp;
		vec3 cside;
		float clift;
		int cl = field_climb(raw, cp, cside, clift);
		vec2 fw0 = fw;
		// Contorna arbustos (e some embaixo das folhas, no miolo).
		vec4 pr = field_props(raw);
		vec2 p2 = raw + pr.rg;
		vec2 q = raw + fw * 0.05;
		q += field_props(q).rg;
		if (distance(q, p2) > 1e-4) {
			fw = normalize(q - p2);
		}
		// Sobe nas pedras e troncos.
		float e = 0.15;
		float hx = field_surface(p2 + vec2(e, 0.0)) - field_surface(p2 - vec2(e, 0.0));
		float hz = field_surface(p2 + vec2(0.0, e)) - field_surface(p2 - vec2(0.0, e));
		vec2 grad = vec2(hx, hz) / (2.0 * e);
		pos = vec3(p2.x, field_surface(p2), p2.y);
		// Sobe na tampa da câmara e afunda no buraco do meio.
		vec2 hoff = p2 - vec2(f0, f1);
		if (ic.x > 0.0 && dot(hoff, hoff) < ic.x * ic.x * 2.6) {
			float eh = 0.02;
			pos.y += field_home(ic, hoff);
			vec2 hg = vec2(field_home(ic, hoff + vec2(eh, 0.0)) - field_home(ic, hoff - vec2(eh, 0.0)),
				field_home(ic, hoff + vec2(0.0, eh)) - field_home(ic, hoff - vec2(0.0, eh))) / (2.0 * eh);
			float hl = length(hg);
			grad += hl > 2.5 ? hg * (2.5 / hl) : hg;
		}
		up = normalize(vec3(-grad.x, 1.0, -grad.y));
		fwd = vec3(fw.x, 0.0, fw.y);
		carry = u > 0.5 ? leaf : 0.0;
		// Some no buraco: com buraco de verdade, só depois de afundar nele.
		float hide_r = ic.z > 0.0 ? 0.02 : 0.15;
		hidden = rho < hide_r || pr.a > 0.5;
		if (cl > 0) {
			// Sobe no tronco: de pé no chão até chegar, depois de lado no tronco.
			hidden = rho < hide_r || cl == 2;
			vec3 cp2;
			vec3 cs2;
			float cl2;
			int nx = field_climb(raw + fw0 * 0.05, cp2, cs2, cl2);
			vec3 mv = cp2 - cp;
			if (nx == 1 && dot(mv, mv) > 1e-8) {
				fwd = normalize(mv);
			}
			up = normalize(mix(up, cside, smoothstep(0.0, 0.12, clift)));
			pos = cp;
		}
		gait = t * 0.55 / (size * 0.32) + seed;
	}
	vec3 Fr = fwd - up * dot(fwd, up);
	if (dot(Fr, Fr) < 1e-6) {
		Fr = cross(up, vec3(0.0, 0.0, 1.0));
	}
	vec3 F = normalize(Fr);
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
