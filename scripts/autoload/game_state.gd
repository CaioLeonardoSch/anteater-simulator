extends Node
## Estado da partida: formigas comidas, pontos, habilidades compradas,
## atributos do tamanduá, recorde e o jogo salvo.
##
## Economia: cada formiga comida conta 1 e cada 10 formigas valem 1 ponto; a
## rainha vale 200 formigas (20 pontos). Cada habilidade tem o seu preço. Os
## pontos gastos podem ser devolvidos de graça ("Redistribuir pontos").

signal ants_eaten_changed(total: int, delta: int)
## Uma habilidade que ainda não dava para comprar agora cabe nos pontos.
signal upgrade_affordable(id: String)
signal upgrade_purchased(id: String)
## Chegou num marco da área (1, 2 ou 3): mais habilidades abrem na árvore.
signal marco_reached(index: int)
signal skills_reset
signal level_completed(time_sec: float)
signal frenzy_changed(active: bool)
signal run_reset
## Modo contra o relógio: chegou numa parcial (25%, 50%...). `diff` = diferença
## para a mesma parcial do recorde (INF se ainda não houver recorde).
signal split_reached(index: int, time_sec: float, diff: float)
## Conquista destravada (na demo só fica registrada; veja achievements.gd).
signal achievement_unlocked(id: String)

const Achievements := preload("res://scripts/achievements.gd")

## Formigas da colônia do Cerrado (cada rainha conta como 200).
const GOAL := 10000
## Formigas comidas para ganhar 1 ponto.
const ANTS_PER_POINT := 10
## Quanto dura o Frenesi (depois de comer uma tanajura), em segundos.
const FRENZY_TIME := 6.0
const RECORD_PATH := "user://save.cfg"
## Versões antigas tinham um jogo salvo só: ele vira o jogo 1.
const OLD_SAVE_PATH := "user://jogo_salvo.json"
## Quantos jogos salvos dá para ter.
const SLOTS := 3
## Versão do jogo salvo: saves de versões com outro mapa não são carregados.
## Versão 8: a área 1 ficou menor (8 formigueiros), então os saves antigos não abrem.
const SAVE_VERSION := 8
const SAVE_VERSIONS_OK := [8]
## Modos de jogo. Contra o relógio é o speedrun: cronômetro na tela, tempos
## parciais e um recorde só dele. O tempo só corre com o jogo rodando (pausa,
## mapa e habilidades param o relógio), então dá para comparar jogos.
const MODE_NORMAL := "normal"
const MODE_CLOCK := "relogio"
## Parciais do modo contra o relógio (parte dos insetos comidos).
const SPLITS := [0.25, 0.5, 0.75, 1.0]

## Os 5 ramos. "lines" = nomes das linhas (quando o ramo se divide).
## "region" = só pode ser comprada ao chegar nessa região.
const BRANCHES := [
	{"id": "lingua", "name": "Língua", "color": Color(0.96, 0.45, 0.55), "lines": ["Bocado", "Destreza", "Comprimento", "Mira"]},
	{"id": "garras", "name": "Garras", "color": Color(0.95, 0.70, 0.30), "lines": ["Força", "Tremor", "Rapidez", "Fundura"]},
	{"id": "patas", "name": "Patas", "color": Color(0.45, 0.75, 0.55), "lines": ["Corrida", "Respiro", "Passada", "Fôlego"]},
	{"id": "faro", "name": "Faro", "color": Color(0.55, 0.70, 0.98), "lines": ["Alcance", "Precisão"]},
	{"id": "escalada", "name": "Escalada + Cauda", "color": Color(0.80, 0.62, 0.42), "lines": [], "region": "Área 2"},
]

## Marcos da área 1 (no lugar das travas por insetos). Cada habilidade diz
## quando abre ("unlock"): sem a chave, desde o começo; 1, 2 ou 3, no marco;
## AREA2, só na área 2 (não abre na demo). Ver docs/pesquisa-habilidades.md,
## seções 11 e 12.
##   1: limpar o primeiro formigueiro.
##   2: comer metade dos insetos da área.
##   3: comer 80% dos insetos da área (o Farejar vem de presente).
const MARCOS := [
	{"index": 1, "title": "Formigueiro limpo", "short": "Formigueiro"},
	{"index": 2, "title": "Metade da clareira", "short": "Metade", "share": 0.5},
	{"index": 3, "title": "O faro despertou", "short": "80%", "share": 0.8},
]
const AREA2 := 9
## Habilidades que um marco dá de presente (não gastam pontos e ficam ao
## redistribuir).
const MARCO_GIFTS := {3: ["faro_farejar"]}

## Cada habilidade (nó): ramo, posição na árvore (col -1 = topo do ramo,
## centralizado; 0..3 = linhas da esquerda para a direita), o preço de cada
## clique ("costs": 1 a 3 cliques; cada clique é uma melhora pequena), quando
## abre ("unlock", veja MARCOS) e o que precisa estar completo antes. O nó
## seguinte da linha só abre com o anterior completo.
const UPGRADES := [
	# Língua: Lambida Contínua abre as linhas de Bocado (quantos por lambida),
	# Destreza (lambidas por segundo), Comprimento (alcance) e Mira (a língua ir
	# atrás do inseto).
	{"id": "lingua_segurar", "branch": 0, "col": -1, "row": 0, "costs": [15], "requires": [],
		"name": "Lambida Contínua",
		"desc": "Segure o botão para lamber sem parar."},
	{"id": "lingua_bocado_1", "branch": 0, "col": 0, "row": 1, "costs": [8, 12, 16], "requires": ["lingua_segurar"],
		"name": "Bocado nível 1",
		"desc": "Cada lambida pega mais insetos perto da ponta da língua: 2, depois 3, depois 5."},
	{"id": "lingua_bocado_2", "branch": 0, "col": 0, "row": 2, "costs": [30, 40, 50], "unlock": 1, "requires": ["lingua_bocado_1"],
		"name": "Bocado nível 2",
		"desc": "8, 11 e 15 insetos por lambida, e a ponta gruda num raio um pouco maior."},
	{"id": "lingua_bocado_3", "branch": 0, "col": 0, "row": 3, "costs": [70, 90], "unlock": AREA2, "requires": ["lingua_bocado_2"],
		"name": "Bocado nível 3",
		"desc": "20 e 25 insetos por lambida."},
	{"id": "lingua_bocado_4", "branch": 0, "col": 0, "row": 4, "costs": [160, 200], "unlock": AREA2, "requires": ["lingua_bocado_3"],
		"name": "Bocado nível 4",
		"desc": "32 e 40 insetos por lambida."},
	{"id": "lingua_destreza_1", "branch": 0, "col": 1, "row": 1, "costs": [10, 14, 18], "requires": ["lingua_segurar"],
		"name": "Destreza nível 1",
		"desc": "A língua lambe um pouco mais rápido a cada clique."},
	{"id": "lingua_destreza_2", "branch": 0, "col": 1, "row": 2, "costs": [50, 60, 70], "unlock": 2, "requires": ["lingua_destreza_1"],
		"name": "Destreza nível 2",
		"desc": "A língua lambe ainda mais rápido."},
	{"id": "lingua_destreza_3", "branch": 0, "col": 1, "row": 3, "costs": [260], "unlock": AREA2, "requires": ["lingua_destreza_2"],
		"name": "Destreza nível 3",
		"desc": "A língua lambe muito mais rápido."},
	{"id": "lingua_comprimento_1", "branch": 0, "col": 2, "row": 1, "costs": [16, 20, 24], "requires": ["lingua_segurar"],
		"name": "Comprimento nível 1",
		"desc": "A língua alcança mais longe: 3,3, depois 3,6, depois 3,9 m."},
	{"id": "lingua_comprimento_2", "branch": 0, "col": 2, "row": 2, "costs": [60, 80], "unlock": AREA2, "requires": ["lingua_comprimento_1"],
		"name": "Comprimento nível 2",
		"desc": "A língua alcança 4,2 e depois 4,5 m."},
	{"id": "lingua_mira_1", "branch": 0, "col": 3, "row": 1, "costs": [12], "requires": ["lingua_segurar"],
		"name": "Mira nível 1",
		"desc": "A língua vai sozinha atrás do inseto mais perto da mira, e a área da mira fica maior."},
	{"id": "lingua_mira_2", "branch": 0, "col": 3, "row": 2, "costs": [25, 30, 35], "unlock": 1, "requires": ["lingua_mira_1"],
		"name": "Mira nível 2",
		"desc": "A área da mira em que a língua procura insetos fica maior a cada clique."},
	{"id": "lingua_mira_3", "branch": 0, "col": 3, "row": 3, "costs": [110], "unlock": AREA2, "requires": ["lingua_mira_2"],
		"name": "Mira nível 3",
		"desc": "A ponta da língua gruda num raio 70% maior."},
	# Garras: Cavar abre as linhas de Força (moradoras tontas), de Rapidez (o
	# descanso entre usos) e de Fundura (buracos maiores: câmaras grandes e o
	# monte da rainha). A linha do Tremor sai de Força nível 1.
	{"id": "garras_cavar", "branch": 1, "col": -1, "row": 0, "costs": [25], "requires": [],
		"name": "Cavar",
		"desc": "Segure [E] perto de uma câmara pequena fechada para abri-la. Depois, as garras descansam 25 s."},
	{"id": "garras_forca_1", "branch": 1, "col": 0, "row": 1, "costs": [25, 35], "requires": ["garras_cavar"],
		"name": "Força nível 1",
		"desc": "Abrir uma câmara deixa as moradoras tontas: elas não fogem logo."},
	{"id": "garras_forca_2", "branch": 1, "col": 0, "row": 2, "costs": [40, 50], "unlock": 2, "requires": ["garras_forca_1"],
		"name": "Força nível 2",
		"desc": "As moradoras ficam tontas por mais tempo."},
	{"id": "garras_tremor_1", "branch": 1, "col": 1, "row": 2, "costs": [90], "unlock": 2, "requires": ["garras_forca_1"],
		"name": "Tremor nível 1",
		"desc": "[Espaço] Tremor: pule e caia com força. Os insetos num raio de 6 m ficam tontos por 3 s. Recarrega em 21 s."},
	{"id": "garras_tremor_2", "branch": 1, "col": 1, "row": 3, "costs": [45, 55, 65], "unlock": AREA2, "requires": ["garras_tremor_1"],
		"name": "Tremor nível 2",
		"desc": "O Tremor recarrega mais rápido: 18, 15 e 12 s."},
	{"id": "garras_tremor_3", "branch": 1, "col": 1, "row": 4, "costs": [300], "unlock": AREA2, "requires": ["garras_tremor_2"],
		"name": "Tremor nível 3",
		"desc": "Vira Terremoto: pulo mais alto, tremor quase 2x maior, os insetos tontos são puxados para a sua boca, e recarrega em só 7 s."},
	{"id": "garras_rapidez_1", "branch": 1, "col": 2, "row": 1, "costs": [12, 16, 20], "requires": ["garras_cavar"],
		"name": "Rapidez nível 1",
		"desc": "As garras descansam menos depois de cavar."},
	{"id": "garras_rapidez_2", "branch": 1, "col": 2, "row": 2, "costs": [40, 50, 60], "unlock": AREA2, "requires": ["garras_rapidez_1"],
		"name": "Rapidez nível 2",
		"desc": "Descanso ainda menor; no último clique, a câmara abre na metade do tempo."},
	{"id": "garras_fundura_1", "branch": 1, "col": 3, "row": 1, "costs": [60], "requires": ["garras_cavar"],
		"name": "Fundura nível 1",
		"desc": "Abre também as câmaras grandes, as dos formigueiros grandes."},
	{"id": "garras_fundura_2", "branch": 1, "col": 3, "row": 2, "costs": [120], "unlock": 2, "requires": ["garras_fundura_1"],
		"name": "Fundura nível 2",
		"desc": "Desmancha um formigueiro grande inteiro: no fundo do buraco estão a rainha e a corte dela."},
	# Patas: correr existe desde o começo, gastando estamina. Fôlego abre as
	# linhas de Corrida (velocidade e o que dá para fazer correndo), Respiro
	# (recuperar mais rápido), Passada (gastar menos correndo) e Fôlego
	# (estamina máxima).
	{"id": "patas_folego", "branch": 2, "col": -1, "row": 0, "costs": [10], "requires": [],
		"name": "Fôlego",
		"desc": "Estamina máxima de 50 para 75."},
	{"id": "patas_folego_1", "branch": 2, "col": 3, "row": 1, "costs": [12, 16, 20], "requires": ["patas_folego"],
		"name": "Fôlego nível 1",
		"desc": "Estamina máxima de 100, depois 125, depois 150."},
	{"id": "patas_folego_2", "branch": 2, "col": 3, "row": 2, "costs": [50, 60], "unlock": AREA2, "requires": ["patas_folego_1"],
		"name": "Fôlego nível 2",
		"desc": "Estamina máxima de 175 e depois 200."},
	{"id": "patas_passada_1", "branch": 2, "col": 2, "row": 1, "costs": [8, 12, 16], "requires": ["patas_folego"],
		"name": "Passada nível 1",
		"desc": "Correndo, gasta menos estamina."},
	{"id": "patas_passada_2", "branch": 2, "col": 2, "row": 2, "costs": [40, 50], "unlock": 1, "requires": ["patas_passada_1"],
		"name": "Passada nível 2",
		"desc": "Correndo, gasta ainda menos estamina: metade do começo."},
	{"id": "patas_respiro_1", "branch": 2, "col": 1, "row": 1, "costs": [8, 12], "requires": ["patas_folego"],
		"name": "Respiro nível 1",
		"desc": "A estamina volta mais rápido."},
	{"id": "patas_respiro_2", "branch": 2, "col": 1, "row": 2, "costs": [30, 40], "unlock": 1, "requires": ["patas_respiro_1"],
		"name": "Respiro nível 2",
		"desc": "A estamina volta ainda mais rápido: mais que o dobro do começo."},
	{"id": "patas_corrida_1", "branch": 2, "col": 0, "row": 1, "costs": [25, 35], "requires": ["patas_folego"],
		"name": "Corrida nível 1",
		"desc": "Corre mais rápido a cada clique."},
	{"id": "patas_corrida_2", "branch": 2, "col": 0, "row": 2, "costs": [90], "unlock": AREA2, "requires": ["patas_corrida_1"],
		"name": "Corrida nível 2",
		"desc": "Dá para lamber enquanto corre."},
	{"id": "patas_corrida_3", "branch": 2, "col": 0, "row": 3, "costs": [250], "unlock": AREA2, "requires": ["patas_corrida_2"],
		"name": "Corrida nível 3",
		"desc": "Correndo, você não assusta mais os insetos."},
	# Faro: Farejar abre as linhas de Alcance (distância e quantidade) e de Precisão.
	{"id": "faro_farejar", "branch": 3, "col": -1, "row": 0, "costs": [25], "unlock": 3, "requires": [],
		"name": "Farejar",
		"desc": "[Q] Fareje: descubra quantos insetos há a até 10 m (até 100 deles), a que distância está o mais perto, e a bússola aponta o maior grupo. Recarrega em 10 s."},
	{"id": "faro_alcance_1", "branch": 3, "col": 0, "row": 1, "costs": [15, 20, 25], "unlock": 3, "requires": ["faro_farejar"],
		"name": "Alcance nível 1",
		"desc": "Fareja mais longe e mais insetos, e recarrega mais rápido."},
	{"id": "faro_alcance_2", "branch": 3, "col": 0, "row": 2, "costs": [55, 70], "unlock": AREA2, "requires": ["faro_alcance_1"],
		"name": "Alcance nível 2",
		"desc": "Fareja ainda mais longe; no último clique, a bússola mostra quanto falta em cada formigueiro."},
	{"id": "faro_alcance_3", "branch": 3, "col": 0, "row": 3, "costs": [220], "unlock": AREA2, "requires": ["faro_alcance_2"],
		"name": "Alcance nível 3",
		"desc": "Fareja até 50 m e até 2000 insetos, e marca as rainhas na bússola."},
	{"id": "faro_precisao_1", "branch": 3, "col": 1, "row": 1, "costs": [45], "unlock": AREA2, "requires": ["faro_farejar"],
		"name": "Precisão nível 1",
		"desc": "Uma nuvem de cheiro, meio borrada, mostra onde estão os insetos farejados."},
	{"id": "faro_precisao_2", "branch": 3, "col": 1, "row": 2, "costs": [75], "unlock": AREA2, "requires": ["faro_precisao_1"],
		"name": "Precisão nível 2",
		"desc": "Os insetos farejados brilham nítidos, mesmo atrás do capim."},
	{"id": "faro_precisao_3", "branch": 3, "col": 1, "row": 3, "costs": [200], "unlock": AREA2, "requires": ["faro_precisao_2"],
		"name": "Precisão nível 3",
		"desc": "Farejar também mostra as câmaras fechadas por perto (até no meio do campo), com uma coluna de cheiro."},
	# Escalada + Cauda (ainda não feita: aparece com cadeado)
	{"id": "escalada_1", "branch": 4, "col": 0, "row": 0, "costs": [300], "requires": [],
		"name": "Escalada",
		"desc": "Sobe em árvores e cupinzeiros para alcançar ninhos no alto."},
	{"id": "escalada_2", "branch": 4, "col": 0, "row": 1, "costs": [400], "requires": ["escalada_1"],
		"name": "Cauda Preênsil",
		"desc": "Pendura-se pela cauda para alcançar ninhos embaixo de galhos e do outro lado de vãos."},
]

## Regiões que o jogador já alcançou (o Cerrado é o começo).
var regions_reached: Array[String] = ["Cerrado"]

var ants_eaten: int = 0
var points_spent: int = 0
## Habilidades compradas: id -> quantos cliques (1 até max_rank).
var purchased: Dictionary = {}
## Marcos já alcançados neste jogo (1, 2, 3) e as habilidades ganhas de
## presente neles.
var marcos: Array[int] = []
## Objetivo guiado atual (índice em objectives.gd, STEPS).
var objective := 0
var gifted: Array[String] = []
## O jogo salvo aberto era de antes dos nós com cliques: os pontos voltaram
## (o HUD avisa uma vez e desliga).
var skills_refunded := false
var elapsed: float = 0.0
var playing: bool = false
var completed: bool = false
var combo: int = 0
var best_combo: int = 0
var combo_timer: float = 0.0
var frenzy_time: float = 0.0
var best_time: float = 0.0
var tanajuras_eaten: int = 0
## O jogo salvo em uso (1 a SLOTS).
var slot: int = 1
## Marcador que o jogador pôs no mapa (mundo, plano xz); INF = nenhum.
var marker := Vector2.INF
var queens_eaten: int = 0
## Modo deste jogo e o do próximo jogo novo (escolhido ao começar).
var mode := MODE_NORMAL
var next_mode := MODE_NORMAL
## Tempos parciais deste jogo e os do recorde contra o relógio.
var splits: Array = []
var best_splits: Array = []
var best_time_clock: float = 0.0
## Números deste jogo para a tela de estatísticas (distância, lambidas...).
var stats: Dictionary = {}
## Número aleatório desta partida (vai junto com as estatísticas da versão de teste).
var run_id: String = ""
## Somas de todos os jogos e conquistas destravadas (ficam em save.cfg).
var lifetime: Dictionary = {}
var achievements: Dictionary = {}
var _facts_dirty := false
var _facts_timer := 0.0
## Habilidades que já cabiam nos pontos (para avisar só das novas).
var _affordable: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_load_record()
	_migrate_old_save()


func reset_run() -> void:
	ants_eaten = 0
	points_spent = 0
	purchased.clear()
	marcos.clear()
	gifted.clear()
	objective = 0
	elapsed = 0.0
	completed = false
	combo = 0
	best_combo = 0
	combo_timer = 0.0
	frenzy_time = 0.0
	tanajuras_eaten = 0
	queens_eaten = 0
	marker = Vector2.INF
	splits.clear()
	stats.clear()
	run_id = "%06x" % (randi() & 0xFFFFFF)
	_affordable.clear()
	run_reset.emit()
	ants_eaten_changed.emit(0, 0)


func _process(delta: float) -> void:
	if not playing or completed:
		return
	elapsed += delta
	lifetime["playtime"] = float(lifetime.get("playtime", 0.0)) + delta
	_facts_timer -= delta
	if _facts_dirty and _facts_timer <= 0.0:
		_facts_dirty = false
		_facts_timer = 0.5
		_check_achievements()
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
	if frenzy_time > 0.0:
		frenzy_time -= delta
		if frenzy_time <= 0.0:
			frenzy_time = 0.0
			frenzy_changed.emit(false)


## Soma formigas comidas. `count` já vem com o valor da rainha (200) incluído.
func add_eaten(count: int, tanajuras: int = 0, queens: int = 0) -> void:
	if count <= 0 or completed:
		return
	count = mini(count, GOAL - ants_eaten)
	var before := ants_eaten
	ants_eaten += count
	lifetime["eaten"] = int(lifetime.get("eaten", 0)) + count
	_check_splits(before)
	for m in MARCOS:
		if m.has("share") and ants_eaten >= marco_insects(m.index):
			reach_marco(m.index)
	_facts_dirty = true
	combo += count
	combo_timer = 2.5
	best_combo = maxi(best_combo, combo)
	queens_eaten += queens
	if tanajuras > 0:
		tanajuras_eaten += tanajuras
		var was_active := frenzy_time > 0.0
		frenzy_time = FRENZY_TIME
		if not was_active:
			frenzy_changed.emit(true)
	ants_eaten_changed.emit(ants_eaten, count)
	_check_affordable(true)
	if ants_eaten >= GOAL:
		completed = true
		lifetime["cleared"] = int(lifetime.get("cleared", 0)) + 1
		if not DevTools.autoplay:
			if mode == MODE_CLOCK:
				if best_time_clock <= 0.0 or elapsed < best_time_clock:
					best_time_clock = elapsed
					best_splits = splits.duplicate()
			elif best_time <= 0.0 or elapsed < best_time:
				best_time = elapsed
		_check_achievements()
		_save_record()
		level_completed.emit(elapsed)


## O recorde do modo deste jogo.
func mode_best_time() -> float:
	return best_time_clock if mode == MODE_CLOCK else best_time


## Marca as parciais que esse tanto de insetos passou.
func _check_splits(before: int) -> void:
	for i in SPLITS.size():
		var at := int(round(GOAL * SPLITS[i]))
		if before < at and ants_eaten >= at and splits.size() == i:
			splits.append(elapsed)
			var diff := INF
			if i < best_splits.size():
				diff = elapsed - float(best_splits[i])
			split_reached.emit(i, elapsed, diff)


## Soma um número do jogo (lambidas, distância, câmaras abertas...).
func count(id: String, amount: float = 1.0) -> void:
	if not playing:
		return
	stats[id] = float(stats.get(id, 0.0)) + amount
	_facts_dirty = true
	if completed and id != "distance" and id != "run_time":
		# Com a clareira limpa o relógio parou: confere na hora.
		_check_achievements()


func stat(id: String) -> float:
	return float(stats.get(id, 0.0))


## Os números que as conquistas olham (achievements.gd).
func achievement_facts() -> Dictionary:
	var all_skills := true
	for u in UPGRADES:
		if region_required(u.id).is_empty() and not complete(u.id):
			all_skills = false
	return {
		"eaten": ants_eaten, "eaten_total": int(lifetime.get("eaten", 0)),
		"nests_cleaned": stat("nests_cleaned"), "chambers_opened": stat("chambers_opened"),
		"queens": queens_eaten, "tanajuras": tanajuras_eaten, "best_combo": best_combo,
		"skills": purchased.size(), "skills_all": 1 if all_skills else 0,
		"sniffs": stat("sniffs"), "distance": stat("distance"), "exit_broken": stat("exit_broken"),
		"clock_done": 1 if completed and mode == MODE_CLOCK else 0,
		"clock_fast": 1 if completed and mode == MODE_CLOCK and elapsed < Achievements.FAST_TIME else 0,
	}


func _check_achievements() -> void:
	if DevTools.autoplay:
		return
	var new := Achievements.newly_unlocked(achievement_facts(), achievements)
	if new.is_empty():
		return
	for id in new:
		achievements[id] = Time.get_unix_time_from_system()
		print("[conquista] %s" % Achievements.get_def(id).name)
		achievement_unlocked.emit(id)
	_save_record()


## Pontos para gastar: 1 a cada 10 formigas comidas, menos o que já foi gasto.
func points_available() -> int:
	return ants_eaten / ANTS_PER_POINT - points_spent


## Quantas formigas ainda faltam comer para ter `points` pontos para gastar.
func ants_needed(points: int) -> int:
	var missing := points - points_available()
	if missing <= 0:
		return 0
	return (ants_eaten / ANTS_PER_POINT + missing) * ANTS_PER_POINT - ants_eaten


## Tem pelo menos um clique nesta habilidade.
func has(id: String) -> bool:
	return rank(id) > 0


## Quantos cliques já foram comprados nesta habilidade.
func rank(id: String) -> int:
	return int(purchased.get(id, 0))


## Quantos cliques a habilidade tem (1 a 3).
func max_rank(id: String) -> int:
	return (get_upgrade(id).get("costs", []) as Array).size()


## Todos os cliques comprados.
func complete(id: String) -> bool:
	var m := max_rank(id)
	return m > 0 and rank(id) >= m


## Soma dos cliques comprados em várias habilidades (uma linha da árvore).
func clicks(ids: Array) -> int:
	var n := 0
	for id in ids:
		n += rank(String(id))
	return n


## Cliques comprados na árvore toda.
func clicks_total() -> int:
	var n := 0
	for id in purchased:
		n += int(purchased[id])
	return n


func get_upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}


## Preço do próximo clique (o do último, se a habilidade estiver completa).
func cost_of(id: String) -> int:
	var costs: Array = get_upgrade(id).get("costs", [])
	if costs.is_empty():
		return 0
	return int(costs[mini(rank(id), costs.size() - 1)])


## Preço de todos os cliques da habilidade.
func total_cost(id: String) -> int:
	var t := 0
	for c in get_upgrade(id).get("costs", []):
		t += int(c)
	return t


## Pontos gastos nos cliques comprados (cada clique tem o seu preço).
func _spent_on(ranks: Dictionary) -> int:
	var t := 0
	for id in ranks:
		if gifted.has(String(id)):
			continue
		var costs: Array = get_upgrade(String(id)).get("costs", [])
		for k in mini(int(ranks[id]), costs.size()):
			t += int(costs[k])
	return t


## Quantos insetos comidos o marco 2 ou 3 pede (0 para o marco 1).
func marco_insects(index: int) -> int:
	for m in MARCOS:
		if m.index == index and m.has("share"):
			return int(round(GOAL * float(m.share)))
	return 0


func get_marco(index: int) -> Dictionary:
	for m in MARCOS:
		if m.index == index:
			return m
	return {}


## Chegou no marco: guarda, dá os presentes e avisa (uma vez só).
func reach_marco(index: int) -> void:
	if marcos.has(index) or get_marco(index).is_empty():
		return
	marcos.append(index)
	for id in MARCO_GIFTS.get(index, []):
		if not gifted.has(id):
			gifted.append(id)
		purchased[id] = max_rank(id)
	_check_affordable(false)
	marco_reached.emit(index)
	for id in MARCO_GIFTS.get(index, []):
		upgrade_purchased.emit(id)


## Habilidades que o marco `index` abre na árvore.
func marco_unlocks(index: int) -> Array[String]:
	var ids: Array[String] = []
	for u in UPGRADES:
		if unlock_of(u.id) == index:
			ids.append(u.id)
	return ids


## Quando a habilidade abre: 0 = desde o começo, 1..3 = marco, AREA2.
func unlock_of(id: String) -> int:
	return int(get_upgrade(id).get("unlock", 0))


## Ganha de presente num marco (não custa pontos).
func is_gift(id: String) -> bool:
	for k in MARCO_GIFTS:
		if (MARCO_GIFTS[k] as Array).has(id):
			return true
	return false


## Região necessária para comprar (vazio = disponível em qualquer lugar).
func region_required(id: String) -> String:
	var u := get_upgrade(id)
	if u.is_empty():
		return ""
	if int(u.get("unlock", 0)) == AREA2 and not regions_reached.has("Área 2"):
		return "Área 2"
	var region: String = BRANCHES[u.branch].get("region", "")
	if region.is_empty() or regions_reached.has(region):
		return ""
	return region


## Habilidades que faltam aprender antes desta.
func missing_requirements(id: String) -> Array[String]:
	var missing: Array[String] = []
	for r in get_upgrade(id).get("requires", []):
		if not complete(String(r)):
			missing.append(String(r))
	return missing


## 0 = falta completar outra antes, 1 = disponível (dá para dar mais um clique),
## 2 = completa, 3 = de outra área (Área 2), 4 = espera um marco desta área
func upgrade_state(id: String) -> int:
	if complete(id):
		return 2
	var u := get_upgrade(id)
	if u.is_empty():
		return 0
	if not region_required(id).is_empty():
		return 3
	var m := unlock_of(id)
	if m > 0 and not marcos.has(m):
		return 4
	if not missing_requirements(id).is_empty():
		return 0
	return 1


func can_buy(id: String) -> bool:
	return upgrade_state(id) == 1 and points_available() >= cost_of(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	points_spent += cost_of(id)
	purchased[id] = rank(id) + 1
	_check_affordable(false)
	upgrade_purchased.emit(id)
	return true


## Testes (--buy): aprende sem gastar pontos (todos os cliques, ou `ranks`).
func grant(id: String, ranks: int = 0) -> void:
	if get_upgrade(id).is_empty() or complete(id):
		return
	purchased[id] = clampi(ranks, 1, max_rank(id)) if ranks > 0 else max_rank(id)
	_check_affordable(false)
	upgrade_purchased.emit(id)


## Devolve todos os pontos para distribuir de novo (de graça).
func respec() -> void:
	purchased.clear()
	for id in gifted:
		purchased[id] = max_rank(id)
	points_spent = 0
	_check_affordable(false)
	skills_reset.emit()


## Quantas habilidades dá para comprar agora.
func affordable_count() -> int:
	var n := 0
	for u in UPGRADES:
		if can_buy(u.id):
			n += 1
	return n


## A habilidade disponível mais barata que ainda não cabe nos pontos (ou {}).
func next_goal() -> Dictionary:
	var best := {}
	for u in UPGRADES:
		if upgrade_state(u.id) != 1 or can_buy(u.id):
			continue
		if best.is_empty() or cost_of(u.id) < cost_of(best.id):
			best = u
	return best


## Avisa (sinal) quando uma habilidade nova passa a caber nos pontos.
func _check_affordable(notify: bool) -> void:
	var now := {}
	for u in UPGRADES:
		if can_buy(u.id):
			now[u.id] = true
			if notify and not _affordable.has(u.id):
				upgrade_affordable.emit(u.id)
	_affordable = now


func frenzy_active() -> bool:
	return frenzy_time > 0.0


# ---------------------------------------------------------------- Atributos

## Sem a Lambida Contínua, cada clique é uma lambida.
func lick_hold() -> bool:
	return has("lingua_segurar")


const BOCADO := ["lingua_bocado_1", "lingua_bocado_2", "lingua_bocado_3", "lingua_bocado_4"]
const DESTREZA := ["lingua_destreza_1", "lingua_destreza_2", "lingua_destreza_3"]
const COMPRIMENTO := ["lingua_comprimento_1", "lingua_comprimento_2"]
## Os cliques que abrem a área da mira (Mira 3 aumenta a ponta, não a área).
const MIRA_AREA := ["lingua_mira_1", "lingua_mira_2"]
const RAPIDEZ := ["garras_rapidez_1", "garras_rapidez_2"]
const FORCA := ["garras_forca_1", "garras_forca_2"]
const FOLEGO := ["patas_folego", "patas_folego_1", "patas_folego_2"]
const RESPIRO := ["patas_respiro_1", "patas_respiro_2"]
const PASSADA := ["patas_passada_1", "patas_passada_2"]
const ALCANCE := ["faro_alcance_1", "faro_alcance_2", "faro_alcance_3"]


## Valor da lista para a quantidade de cliques comprados numa linha.
func _by_clicks(values: Array, ids: Array) -> Variant:
	return values[mini(clicks(ids), values.size() - 1)]


## Quantos insetos uma lambida pega de uma vez (um valor por clique de Bocado).
func lick_capacity() -> int:
	return _by_clicks([1, 2, 3, 5, 8, 11, 15, 20, 25, 32, 40], BOCADO)


## Alcance da língua (linha de Comprimento).
func tongue_range() -> float:
	var r: float = _by_clicks([3.0, 3.3, 3.6, 3.9, 4.2, 4.5], COMPRIMENTO)
	if frenzy_active():
		r *= 1.25
	return r


## Mira nível 1: a língua vai atrás do inseto mais perto da mira.
func tongue_tracking() -> bool:
	return has("lingua_mira_1")


## Abertura (graus, do centro até a borda) da área da mira em que a língua
## procura insetos.
func aim_cone_deg() -> float:
	return _by_clicks([10.0, 15.0, 18.0, 21.0, 25.0], MIRA_AREA)


## Raio em que a ponta da língua gruda: cresce com os nós de Bocado completos
## e 70% com Mira nível 3.
func capture_radius() -> float:
	var full := 0
	for id in BOCADO:
		if complete(id):
			full += 1
	var r: float = 0.34 * [1.0, 1.0, 1.15, 1.3, 1.45][full]
	if has("lingua_mira_3"):
		r *= 1.7
	return r


## Lambidas por segundo: começa devagar e acelera com a linha de Destreza.
func lick_rate() -> float:
	var r: float = _by_clicks([1.4, 1.6, 1.8, 2.0, 2.4, 2.8, 3.2, 4.4], DESTREZA)
	if frenzy_active():
		r *= 1.8
	return r


func can_dig() -> bool:
	return has("garras_cavar")


## Até que tamanho de buraco as garras abrem: 0 nenhum, 1 câmaras pequenas,
## 2 também as grandes (Fundura 1), 3 também o monte da rainha (Fundura 2).
func dig_level() -> int:
	if not has("garras_cavar"):
		return 0
	if has("garras_fundura_2"):
		return 3
	return 2 if has("garras_fundura_1") else 1


## A habilidade que abre buracos deste tamanho (1, 2 ou 3).
func dig_skill_for(size_class: int) -> String:
	return ["garras_cavar", "garras_cavar", "garras_fundura_1", "garras_fundura_2"][clampi(size_class, 0, 3)]


## Quanto tempo segurando [E] para abrir uma câmara (o último clique de
## Rapidez corta pela metade).
func dig_time() -> float:
	return 0.6 if complete("garras_rapidez_2") else 1.2


## Descanso das garras depois de abrir uma câmara.
func dig_cooldown() -> float:
	return _by_clicks([25.0, 20.0, 16.0, 12.0, 9.0, 7.0, 5.0], RAPIDEZ)


## Quanto tempo as moradoras ficam tontas quando a câmara é aberta (0 = nada).
func dig_stun_time() -> float:
	return _by_clicks([0.0, 1.5, 2.5, 3.2, 4.0], FORCA)


func can_tremor() -> bool:
	return has("garras_tremor_1")


func tremor_radius() -> float:
	return 11.0 if has("garras_tremor_3") else 6.0


func tremor_pulls() -> bool:
	return has("garras_tremor_3")


func tremor_cooldown() -> float:
	if has("garras_tremor_3"):
		return 7.0
	return [21.0, 18.0, 15.0, 12.0][rank("garras_tremor_2")]


## Força do pulo do Tremor (o Terremoto pula mais alto).
func tremor_jump_speed() -> float:
	return 7.4 if has("garras_tremor_3") else 6.0


## Correr existe desde o começo; o limite é a estamina.
func can_run() -> bool:
	return true


## Estamina: correr gasta, e ela só volta sem correr (STAMINA_DELAY segundos
## depois de parar). Gastar e recuperar são por segundo.
const STAMINA_DELAY := 1.0
## Zerou: só volta a correr quando a estamina encher esta fração.
const STAMINA_RESUME := 0.15


## 50, e +25 a cada clique de Fôlego (até 200).
func stamina_max() -> float:
	return 50.0 + 25.0 * clicks(FOLEGO)


## Gasto correndo: 10 por segundo, -1 a cada clique de Passada.
func stamina_drain() -> float:
	return 10.0 - clicks(PASSADA)


## Recuperação: 3 por segundo, +1 a cada clique de Respiro.
func stamina_regen() -> float:
	return 3.0 + clicks(RESPIRO)


## Andar: 2,8 m/s (era 3,3; ficou 15% mais lento a pedido dos testes).
func walk_speed() -> float:
	return 2.8


## Correr: +25% sobre andar desde o começo; cada clique de Corrida nível 1
## deixa 10% mais rápido.
func run_speed() -> float:
	return walk_speed() * [1.25, 1.375, 1.5][rank("patas_corrida_1")]


func can_lick_running() -> bool:
	return has("patas_corrida_2")


## Quanto mais longe os insetos fogem quando você corre (Corrida 3 tira isso).
func flee_multiplier(running: bool) -> float:
	return 1.5 if running and not has("patas_corrida_3") else 1.0


func can_sniff() -> bool:
	return has("faro_farejar")


func sniff_radius() -> float:
	return _by_clicks([10.0, 13.0, 16.0, 20.0, 26.0, 34.0, 50.0], ALCANCE)


## Quantos insetos o faro consegue sentir de uma vez (os mais perto).
func sniff_max_ants() -> int:
	return _by_clicks([100, 160, 250, 400, 600, 1000, 2000], ALCANCE)


func sniff_duration() -> float:
	return _by_clicks([4.0, 4.2, 4.5, 5.0, 5.5, 6.0, 7.0], ALCANCE)


func sniff_cooldown() -> float:
	return _by_clicks([10.0, 9.5, 9.0, 8.5, 8.0, 7.0, 6.0], ALCANCE)


## 0 = só conta, 1 = nuvem borrada onde estão, 2 = insetos nítidos.
func sniff_precision() -> int:
	if has("faro_precisao_2"):
		return 2
	if has("faro_precisao_1"):
		return 1
	return 0


func sniff_chambers() -> bool:
	return has("faro_precisao_3")


func sniff_nest_counts() -> bool:
	return complete("faro_alcance_2")


func sniff_queens() -> bool:
	return has("faro_alcance_3")


## O que o próximo clique de uma habilidade muda em números:
## [{"label", "before", "after"}], para a árvore mostrar "10 → 13". Com a
## habilidade completa, mostra o que ela toda deu. "—" quando a habilidade é
## que libera o gesto.
func stat_changes(id: String) -> Array:
	var m := max_rank(id)
	if m == 0:
		return []
	var r := rank(id)
	return stat_changes_between(id, 0 if r >= m else r, mini(r + 1, m) if r < m else m)


## O que muda de `from` cliques para `to` cliques nesta habilidade.
func stat_changes_between(id: String, from: int, to: int) -> Array:
	# Conta como se as habilidades anteriores da linha já estivessem completas.
	var saved := purchased.duplicate()
	var fz := frenzy_time
	frenzy_time = 0.0
	var todo: Array = (get_upgrade(id).get("requires", []) as Array).duplicate()
	while not todo.is_empty():
		var req: String = todo.pop_back()
		if not complete(req):
			purchased[req] = max_rank(req)
			todo.append_array(get_upgrade(req).get("requires", []))
	if from <= 0:
		purchased.erase(id)
	else:
		purchased[id] = from
	var before := _stat_snapshot()
	purchased[id] = to
	var after := _stat_snapshot()
	purchased = saved
	frenzy_time = fz
	var out := []
	for k in after.size():
		if before[k][1] != after[k][1]:
			out.append({"label": after[k][0], "before": before[k][1] if before[k][1] != "" else "—",
				"after": after[k][1] if after[k][1] != "" else "—"})
	return out


func _stat_snapshot() -> Array:
	var run := can_run()
	var snf := can_sniff()
	var dig := can_dig()
	var trem := can_tremor()
	return [
		["Insetos por lambida", str(lick_capacity())],
		["Lambidas por segundo", _num(lick_rate(), 2)],
		["Alcance da língua", _num(tongue_range(), 1) + " m"],
		["Raio da ponta", _num(capture_radius() * 100.0, 0) + " cm"],
		["Área da mira", _num(aim_cone_deg(), 1) + "°"],
		["Velocidade máxima", _num(run_speed() if run else walk_speed(), 1) + " m/s"],
		["Estamina máxima", _num(stamina_max(), 0)],
		["Gasto correndo", _num(stamina_drain(), 1) + " por segundo"],
		["Recuperação", _num(stamina_regen(), 1) + " por segundo"],
		["Tempo para cavar", _num(dig_time(), 1) + " s" if dig else ""],
		["Descanso das garras", _num(dig_cooldown(), 0) + " s" if dig else ""],
		["Moradoras tontas", _num(dig_stun_time(), 1) + " s" if dig and dig_stun_time() > 0.0 else ""],
		["Raio do Tremor", _num(tremor_radius(), 0) + " m" if trem else ""],
		["Recarga do Tremor", _num(tremor_cooldown(), 0) + " s" if trem else ""],
		["Alcance do faro", _num(sniff_radius(), 0) + " m" if snf else ""],
		["Insetos farejados", str(sniff_max_ants()) if snf else ""],
		["Cheiro dura", _num(sniff_duration(), 1) + " s" if snf else ""],
		["Recarga do faro", _num(sniff_cooldown(), 0) + " s" if snf else ""],
	]


## Número com vírgula e sem zeros sobrando ("1,75", "3", "4,1").
static func _num(v: float, decimals: int) -> String:
	var t := String.num(v, decimals)
	if t.contains("."):
		t = t.rstrip("0").rstrip(".")
	return t.replace(".", ",")


# ---------------------------------------------------------------- Recorde e jogo salvo

func _load_record() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RECORD_PATH) == OK:
		# O recorde é por versão do mapa: tempos de 1000 formigas não contam.
		best_time = float(cfg.get_value("records", "best_time_%d" % GOAL, 0.0))
		best_time_clock = float(cfg.get_value("records", "best_clock_%d" % GOAL, 0.0))
		best_splits = cfg.get_value("records", "best_splits_%d" % GOAL, [])
		lifetime = cfg.get_value("lifetime", "totals", {})
		achievements = cfg.get_value("achievements", "unlocked", {})


func _save_record() -> void:
	var cfg := ConfigFile.new()
	cfg.load(RECORD_PATH)
	cfg.set_value("records", "best_time_%d" % GOAL, best_time)
	cfg.set_value("records", "best_clock_%d" % GOAL, best_time_clock)
	cfg.set_value("records", "best_splits_%d" % GOAL, best_splits)
	cfg.set_value("lifetime", "totals", lifetime)
	cfg.set_value("achievements", "unlocked", achievements)
	cfg.save(RECORD_PATH)


func to_save() -> Dictionary:
	return {
		"ants_eaten": ants_eaten, "points_spent": points_spent,
		"purchased": purchased.duplicate(), "elapsed": elapsed, "best_combo": best_combo,
		"tanajuras_eaten": tanajuras_eaten, "queens_eaten": queens_eaten,
		"regions_reached": regions_reached, "completed": completed,
		"marcos": marcos.duplicate(), "gifted": gifted.duplicate(), "objective": objective,
		"marker": [marker.x, marker.y] if marker != Vector2.INF else [],
		"mode": mode, "splits": splits.duplicate(), "stats": stats.duplicate(), "run_id": run_id,
	}


func from_save(d: Dictionary) -> void:
	ants_eaten = int(d.get("ants_eaten", 0))
	purchased.clear()
	points_spent = 0
	skills_refunded = false
	marcos.clear()
	for m in d.get("marcos", []):
		marcos.append(int(m))
	gifted.clear()
	for g in d.get("gifted", []):
		gifted.append(String(g))
	objective = int(d.get("objective", 0))
	var saved = d.get("purchased", {})
	if saved is Dictionary:
		for id in saved:
			var key := String(id)
			if not get_upgrade(key).is_empty():
				purchased[key] = clampi(int(saved[id]), 0, max_rank(key))
				if purchased[key] == 0:
					purchased.erase(key)
		points_spent = _spent_on(purchased)
	elif not (saved as Array).is_empty():
		# Jogo salvo de antes dos nós com cliques: as habilidades eram outras.
		skills_refunded = true
	# Preços mudaram desde que o jogo foi salvo e não cabem mais: devolve os pontos.
	if points_spent > ants_eaten / ANTS_PER_POINT:
		purchased.clear()
		points_spent = 0
		skills_refunded = true
	elapsed = float(d.get("elapsed", 0.0))
	best_combo = int(d.get("best_combo", 0))
	tanajuras_eaten = int(d.get("tanajuras_eaten", 0))
	queens_eaten = int(d.get("queens_eaten", 0))
	regions_reached.clear()
	for r in d.get("regions_reached", ["Cerrado"]):
		regions_reached.append(String(r))
	completed = bool(d.get("completed", false)) and ants_eaten >= GOAL
	var m: Array = d.get("marker", [])
	marker = Vector2(float(m[0]), float(m[1])) if m.size() == 2 else Vector2.INF
	mode = MODE_CLOCK if String(d.get("mode", MODE_NORMAL)) == MODE_CLOCK else MODE_NORMAL
	splits = Array(d.get("splits", []))
	stats = Dictionary(d.get("stats", {}))
	run_id = String(d.get("run_id", run_id))
	combo = 0
	frenzy_time = 0.0
	_check_affordable(false)
	ants_eaten_changed.emit(ants_eaten, 0)


func save_path(s: int = -1) -> String:
	return "user://jogo_salvo_%d.json" % (slot if s < 0 else s)


func _migrate_old_save() -> void:
	if FileAccess.file_exists(OLD_SAVE_PATH) and not FileAccess.file_exists(save_path(1)):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(OLD_SAVE_PATH),
			ProjectSettings.globalize_path(save_path(1)))


## Só conta como jogo salvo se for da versão atual do mapa.
func has_saved_game(s: int = -1) -> bool:
	return not read_saved_game(s).is_empty()


func any_saved_game() -> bool:
	return latest_slot() > 0


## O jogo salvo mais recente (0 se não houver nenhum).
func latest_slot() -> int:
	var best := 0
	var best_at := -1.0
	for s in range(1, SLOTS + 1):
		var d := read_saved_game(s)
		if not d.is_empty() and float(d.get("saved_at", 0.0)) > best_at:
			best_at = float(d.get("saved_at", 0.0))
			best = s
	return best


## Resumo de um jogo salvo para a tela de escolha ({} se estiver vazio).
func slot_summary(s: int) -> Dictionary:
	var d := read_saved_game(s)
	if d.is_empty():
		return {}
	var st: Dictionary = d.get("state", {})
	return {"eaten": int(st.get("ants_eaten", 0)), "elapsed": float(st.get("elapsed", 0.0)),
		"saved_at": float(d.get("saved_at", 0.0)), "completed": bool(st.get("completed", false)),
		"mode": String(st.get("mode", MODE_NORMAL))}


func write_saved_game(data: Dictionary) -> void:
	if DevTools.autoplay and not DevTools.args.has("allow-save"):
		return
	data["saved_at"] = Time.get_unix_time_from_system()
	_save_record()
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func read_saved_game(s: int = -1) -> Dictionary:
	var path := save_path(s)
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if not parsed is Dictionary or not SAVE_VERSIONS_OK.has(int(parsed.get("version", 0))):
		return {}
	return parsed


func delete_saved_game(s: int = -1) -> void:
	var path := save_path(s)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func format_time(t: float) -> String:
	var total := int(t)
	if total >= 3600:
		return "%d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]
	return "%d:%02d" % [total / 60, total % 60]


## Cronômetro com décimos (modo contra o relógio): 12:34.5
static func format_clock(t: float) -> String:
	var tenths := int(floor(t * 10.0))
	var total := tenths / 10
	var head := "%d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60] if total >= 3600 \
		else "%d:%02d" % [total / 60, total % 60]
	return "%s.%d" % [head, tenths % 10]


## Diferença para o recorde: −0:05.2 (mais rápido) ou +0:12.0.
static func format_diff(d: float) -> String:
	var sign := "−" if d < 0.0 else "+"
	return sign + format_clock(absf(d))
