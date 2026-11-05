extends RefCounted
## O mapa do jogo completo (esboço de 02/11/2026): a área 1 (a demo, a
## clareira) embaixo à esquerda, a passagem para a área 2, a área 3 grande e
## o cupinzeiro gigante (área 4) dentro dela.
##
## "Espaço do mapa": metros, com o centro da clareira na origem, x para a
## direita e y para baixo (como na tela). O mundo 3D é girado em relação a
## ele: a saída da clareira aponta para cima e para a direita no mapa.

const Cliffs := preload("res://scripts/world/cliffs.gd")

## Giro do mundo (plano xz) para o mapa: a saída fica a 45° (direita e cima).
const ROTATION := -PI * 0.25 - Cliffs.EXIT_ANGLE
## Raio da clareira (área 1) que a foto do mapa mostra.
const AREA1_RADIUS := 74.0

## Áreas ainda fechadas: círculos (centro, raio) no espaço do mapa.
const AREAS := [
	{"id": 2, "center": Vector2(170, -222), "radius": 125.0, "label": Vector2(170, -222)},
	{"id": 3, "center": Vector2(525, -547), "radius": 290.0, "label": Vector2(372, -440)},
	{"id": 4, "center": Vector2(640, -606), "radius": 140.0, "label": Vector2(640, -606)},
]
## Passagens estreitas entre as áreas: (de, até, meia largura).
const PASSES := [
	[Vector2(48, -48), Vector2(128, -146), 15.0],
	[Vector2(250, -300), Vector2(335, -372), 24.0],
]
## Cupinzeiro gigante: no meio da área 4.
const MOUND_AREA := 2


## Ponto do mundo (plano xz) no espaço do mapa.
static func to_map(w: Vector2) -> Vector2:
	return w.rotated(ROTATION)


## Ponto do espaço do mapa no mundo (plano xz).
static func to_world(m: Vector2) -> Vector2:
	return m.rotated(-ROTATION)


## Onde fica o cupinzeiro gigante no mundo (plano xz).
static func mound_world() -> Vector2:
	return to_world(AREAS[MOUND_AREA].center)


## Retângulo (espaço do mapa) que cobre o mapa inteiro.
static func bounds() -> Rect2:
	var r := Rect2(Vector2(-AREA1_RADIUS, -AREA1_RADIUS), Vector2.ONE * AREA1_RADIUS * 2.0)
	for a in AREAS:
		var rad: float = a.radius * 1.06 + 10.0
		r = r.merge(Rect2(a.center - Vector2.ONE * rad, Vector2.ONE * rad * 2.0))
	return r
