extends RefCounted
## Conquistas preparadas para o jogo completo. Na demo elas não aparecem para o
## jogador (VISIBLE = false): ficam só contadas em user://save.cfg, prontas para
## ligar na Steam (cada "id" vira o nome da conquista lá) ou num menu próprio.
## Os testes mostram a lista na tela de estatísticas com --conquistas.
##
## Cada conquista olha um número (`stat`) e destrava quando ele chega na meta
## (`goal`). Os números vêm de GameState.achievement_facts().

## Mostrar as conquistas para o jogador (desligado na demo).
const VISIBLE := false

const LIST := [
	{"id": "primeira_mordida", "name": "Primeira mordida", "desc": "Coma o primeiro inseto.",
		"stat": "eaten", "goal": 1},
	{"id": "mil_insetos", "name": "Petisco", "desc": "Coma 1 000 insetos.",
		"stat": "eaten", "goal": 1000},
	{"id": "dez_mil_insetos", "name": "Banquete", "desc": "Coma 10 000 insetos.",
		"stat": "eaten", "goal": 10000},
	{"id": "clareira_limpa", "name": "Clareira limpa", "desc": "Coma todos os insetos do cerrado.",
		"stat": "eaten", "goal": 32000},
	{"id": "cem_mil_total", "name": "Apetite sem fim", "desc": "Coma 100 000 insetos somando todos os jogos.",
		"stat": "eaten_total", "goal": 100000},
	{"id": "primeiro_formigueiro", "name": "Despejo", "desc": "Limpe um formigueiro inteiro.",
		"stat": "nests_cleaned", "goal": 1},
	{"id": "metade_formigueiros", "name": "Meio caminho", "desc": "Limpe 9 formigueiros.",
		"stat": "nests_cleaned", "goal": 9},
	{"id": "escavador", "name": "Escavador", "desc": "Abra 50 câmaras.",
		"stat": "chambers_opened", "goal": 50},
	{"id": "primeira_rainha", "name": "Fim do reinado", "desc": "Coma uma rainha.",
		"stat": "queens", "goal": 1},
	{"id": "todas_rainhas", "name": "Sem coroa", "desc": "Coma as 7 rainhas.",
		"stat": "queens", "goal": 7},
	{"id": "primeira_tanajura", "name": "Iguaria do cerrado", "desc": "Coma uma tanajura.",
		"stat": "tanajuras", "goal": 1},
	{"id": "revoada", "name": "Revoada", "desc": "Coma 25 tanajuras num jogo.",
		"stat": "tanajuras", "goal": 25},
	{"id": "combo_50", "name": "Língua afiada", "desc": "Faça um combo de 50 insetos.",
		"stat": "best_combo", "goal": 50},
	{"id": "combo_200", "name": "Aspirador", "desc": "Faça um combo de 200 insetos.",
		"stat": "best_combo", "goal": 200},
	{"id": "primeira_habilidade", "name": "Aprendiz", "desc": "Aprenda uma habilidade.",
		"stat": "skills", "goal": 1},
	{"id": "todas_habilidades", "name": "Mestre do cerrado", "desc": "Aprenda todas as habilidades da área 1.",
		"stat": "skills_all", "goal": 1},
	{"id": "farejador", "name": "Nariz no chão", "desc": "Use o Faro 50 vezes num jogo.",
		"stat": "sniffs", "goal": 50},
	{"id": "andarilho", "name": "Andarilho", "desc": "Ande 5 km num jogo.",
		"stat": "distance", "goal": 5000},
	{"id": "caminho_aberto", "name": "Caminho aberto", "desc": "Quebre o tronco da saída.",
		"stat": "exit_broken", "goal": 1},
	{"id": "contra_o_relogio", "name": "Contra o relógio", "desc": "Limpe a clareira no modo contra o relógio.",
		"stat": "clock_done", "goal": 1},
	# Meta provisória: acertar depois de medir o tempo de bons jogadores.
	{"id": "relampago", "name": "Relâmpago", "desc": "Limpe a clareira em menos de 45 minutos no modo contra o relógio.",
		"stat": "clock_fast", "goal": 1},
]

## Tempo do "Relâmpago", em segundos.
const FAST_TIME := 45.0 * 60.0


static func get_def(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}


## As que chegaram na meta e ainda não estavam em `unlocked`.
static func newly_unlocked(facts: Dictionary, unlocked: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for a in LIST:
		if unlocked.has(a.id):
			continue
		if float(facts.get(a.stat, 0)) >= float(a.goal):
			out.append(a.id)
	return out
