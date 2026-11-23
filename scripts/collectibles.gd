extends RefCounted
## Formigas colecionáveis: cada uma com uma fantasia, escondida num lugar fixo
## do mapa (o mesmo em todo jogo), parada ou andando no lugar e sem fugir.
## Chegando perto e olhando para ela, ela entra na coleção deste jogo (aba
## Coleção, no Caderno), que vai no jogo salvo. A primeira vez que cada uma é
## achada, em qualquer jogo, conta para as conquistas (achievements.gd).
## A Formiga Noel é a do chapéu de Natal, que aparece de vez em quando no meio
## das outras (ant_field.gd, HAT_CHANCE): ela não tem lugar fixo. Com a semente
## fixa do campo, 2 das formigas do campo saem de chapéu em todo jogo (e às
## vezes uma das câmaras); comer uma também conta como achar (anteater.gd).
##
## Cada uma: "id" (também o nome da fantasia em ant_mesh_builder.gd), "name",
## "area", e as de lugar fixo têm "spot" (x, z do mapa) e "move": "still"
## (parada), "look" (parada, olhando em volta), "circle" (anda em roda),
## "patrol" (vai e volta até "to") ou "dance" (gira no lugar). "face" é para
## onde ela olha, em graus (0 = -z, o norte do mapa; 90 = -x); sem ele, olha
## para o meio da clareira.

const LIST := [
	{"id": "abobora", "name": "Formiga Abóbora", "area": 1,
		"spot": Vector2(-18.3, 16.2), "move": "circle"},
	{"id": "tamandua", "name": "Formiga Tamanduá", "area": 1,
		"spot": Vector2(14.0, -19.3), "move": "look"},
	{"id": "lincoln", "name": "Formiga Lincoln", "area": 1,
		"spot": Vector2(-24.4, -0.4), "move": "still"},
	{"id": "banhista", "name": "Formiga Banhista", "area": 1,
		"spot": Vector2(-19.4, -12.2), "to": Vector2(-19.5, -10.6), "move": "patrol"},
	{"id": "folia", "name": "Formiga Foliã", "area": 1,
		"spot": Vector2(23.6, -4.6), "move": "dance"},
	{"id": "noel", "name": "Formiga Noel", "area": 1},
]


static func get_def(id: String) -> Dictionary:
	for c in LIST:
		if c.id == id:
			return c
	return {}


## As colecionáveis de uma área, na ordem da lista.
static func of_area(area: int) -> Array:
	var out := []
	for c in LIST:
		if int(c.area) == area:
			out.append(c)
	return out
