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
const GOAL := 44000
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
const SAVE_VERSION := 6
## Modos de jogo. Contra o relógio é o speedrun: cronômetro na tela, tempos
## parciais e um recorde só dele. O tempo só corre com o jogo rodando (pausa,
## mapa e habilidades param o relógio), então dá para comparar jogos.
const MODE_NORMAL := "normal"
const MODE_CLOCK := "relogio"
## Parciais do modo contra o relógio (parte dos insetos comidos).
const SPLITS := [0.25, 0.5, 0.75, 1.0]

## As 5 habilidades. "lines" = nomes das duas linhas (quando o ramo se divide).
## "region" = só pode ser comprada ao chegar nessa região.
const BRANCHES := [
	{"id": "lingua", "name": "Língua", "color": Color(0.96, 0.45, 0.55), "lines": ["Bocado", "Destreza", "Mira"]},
	{"id": "garras", "name": "Garras", "color": Color(0.95, 0.70, 0.30), "lines": ["Força", "Rapidez", "Fundura"]},
	{"id": "patas", "name": "Patas", "color": Color(0.45, 0.75, 0.55), "lines": ["Corrida", "Respiro", "Passada", "Fôlego"]},
	{"id": "faro", "name": "Faro", "color": Color(0.55, 0.70, 0.98), "lines": ["Alcance", "Precisão"]},
	{"id": "escalada", "name": "Escalada + Cauda", "color": Color(0.80, 0.62, 0.42), "lines": [], "region": "Floresta"},
]

## Cada habilidade: ramo, posição na árvore (col -1 = topo do ramo, centralizado;
## 0/1 = linha da esquerda/direita), preço em formigas e o que precisa antes.
const UPGRADES := [
	# Língua: Lambida Contínua abre as linhas de Bocado (quantas por lambida),
	# Destreza e Mira (a língua ir atrás da formiga).
	{"id": "lingua_segurar", "branch": 0, "col": -1, "row": 0, "cost": 25, "requires": [],
		"name": "Lambida Contínua",
		"desc": "Segure o botão para lamber sem parar."},
	{"id": "lingua_bocado_1", "branch": 0, "col": 0, "row": 1, "cost": 40, "requires": ["lingua_segurar"],
		"name": "Lambida",
		"desc": "Cada lambida pega até 50 insetos perto da ponta da língua."},
	{"id": "lingua_bocado_2", "branch": 0, "col": 0, "row": 2, "cost": 75, "requires": ["lingua_bocado_1"],
		"name": "Lambida Larga",
		"desc": "Até 150 insetos por lambida, e a ponta gruda num raio um pouco maior."},
	{"id": "lingua_bocado_3", "branch": 0, "col": 0, "row": 3, "cost": 115, "requires": ["lingua_bocado_2"],
		"name": "Lambida Gulosa",
		"desc": "Até 250 insetos por lambida."},
	{"id": "lingua_bocado_4", "branch": 0, "col": 0, "row": 4, "cost": 170, "requires": ["lingua_bocado_3"],
		"name": "Lambida Voraz",
		"desc": "Até 400 insetos por lambida."},
	{"id": "lingua_comprida", "branch": 0, "col": 1, "row": 1, "cost": 70, "requires": ["lingua_segurar"],
		"name": "Língua Comprida",
		"desc": "Alcance da língua +50%, e ela lambe 25% mais rápido."},
	{"id": "lingua_saliva", "branch": 0, "col": 1, "row": 2, "cost": 100, "requires": ["lingua_comprida"],
		"name": "Saliva Grudenta",
		"desc": "A ponta da língua gruda num raio 70% maior, e ela lambe 25% mais rápido."},
	{"id": "lingua_turbo", "branch": 0, "col": 1, "row": 3, "cost": 150, "requires": ["lingua_saliva"],
		"name": "Língua Turbo",
		"desc": "A língua lambe 2x mais rápido."},
	{"id": "lingua_certeira", "branch": 0, "col": 2, "row": 1, "cost": 30, "requires": ["lingua_segurar"],
		"name": "Língua Certeira",
		"desc": "A língua vai sozinha atrás do inseto mais perto da mira."},
	{"id": "lingua_mira", "branch": 0, "col": 2, "row": 2, "cost": 60, "requires": ["lingua_certeira"],
		"name": "Mira Ampla",
		"desc": "A área da mira em que a língua procura insetos fica 25% maior."},
	# Garras: Cavar abre as linhas de Força, de Rapidez (o descanso entre usos)
	# e de Fundura (buracos maiores: câmaras grandes e o monte da rainha).
	{"id": "garras_cavar", "branch": 1, "col": -1, "row": 0, "cost": 35, "requires": [],
		"name": "Cavar",
		"desc": "Segure [E] perto de uma câmara pequena fechada para abri-la. Depois, as garras descansam 25 s."},
	{"id": "garras_fundo", "branch": 1, "col": 2, "row": 1, "cost": 60, "requires": ["garras_cavar"],
		"name": "Cavar Fundo",
		"desc": "Abre também as câmaras grandes, as dos formigueiros grandes."},
	{"id": "garras_real", "branch": 1, "col": 2, "row": 2, "cost": 120, "requires": ["garras_fundo"],
		"name": "Escavação Real",
		"desc": "Desmancha um formigueiro grande inteiro: no fundo do buraco estão a rainha e a corte dela."},
	{"id": "garras_fortes", "branch": 1, "col": 0, "row": 1, "cost": 70, "requires": ["garras_cavar"],
		"name": "Garras Fortes",
		"desc": "Abrir uma câmara deixa as moradoras tontas por 2,5 s: elas não fogem logo."},
	{"id": "garras_tremor", "branch": 1, "col": 0, "row": 2, "cost": 110, "requires": ["garras_fortes"],
		"name": "Tremor",
		"desc": "[Espaço] Pule e caia com força: os insetos num raio de 6 m ficam tontos por 3 s. Recarrega em 21 s."},
	{"id": "garras_terremoto", "branch": 1, "col": 0, "row": 3, "cost": 170, "requires": ["garras_tremor"],
		"name": "Terremoto",
		"desc": "Pulo mais alto e tremor quase 2x maior; os insetos tontos são puxados para a sua boca."},
	{"id": "garras_ageis", "branch": 1, "col": 1, "row": 1, "cost": 50, "requires": ["garras_cavar"],
		"name": "Garras Ágeis",
		"desc": "As garras descansam só 15 s depois de cavar."},
	{"id": "garras_incansaveis", "branch": 1, "col": 1, "row": 2, "cost": 95, "requires": ["garras_ageis"],
		"name": "Garras Incansáveis",
		"desc": "Descanso de só 5 s, e a câmara abre na metade do tempo."},
	{"id": "garras_recarga", "branch": 1, "col": 1, "row": 3, "cost": 130, "requires": ["garras_incansaveis"],
		"name": "Recarga do Tremor",
		"desc": "O Tremor (e o Terremoto) recarrega em 14 s."},
	{"id": "garras_recarga_2", "branch": 1, "col": 1, "row": 4, "cost": 150, "requires": ["garras_recarga"],
		"name": "Recarga Relâmpago",
		"desc": "O Tremor (e o Terremoto) recarrega em só 7 s."},
	# Patas
	# Patas: correr existe desde o começo, gastando estamina. Fôlego abre as
	# linhas de Fôlego (estamina máxima), Passada (gastar menos correndo),
	# Respiro (recuperar mais rápido) e Corrida (velocidade e o que dá para
	# fazer correndo).
	{"id": "patas_folego", "branch": 2, "col": -1, "row": 0, "cost": 20, "requires": [],
		"name": "Fôlego",
		"desc": "Estamina máxima de 50 para 100."},
	{"id": "patas_folego_2", "branch": 2, "col": 3, "row": 1, "cost": 50, "requires": ["patas_folego"],
		"name": "Fôlego Longo",
		"desc": "Estamina máxima de 100 para 150."},
	{"id": "patas_folego_3", "branch": 2, "col": 3, "row": 2, "cost": 90, "requires": ["patas_folego_2"],
		"name": "Fôlego de Maratona",
		"desc": "Estamina máxima de 150 para 200."},
	{"id": "patas_passada_1", "branch": 2, "col": 2, "row": 1, "cost": 25, "requires": ["patas_folego"],
		"name": "Passada Leve",
		"desc": "Correndo, gasta menos estamina."},
	{"id": "patas_passada_2", "branch": 2, "col": 2, "row": 2, "cost": 50, "requires": ["patas_passada_1"],
		"name": "Passada Firme",
		"desc": "Correndo, gasta ainda menos estamina."},
	{"id": "patas_passada_3", "branch": 2, "col": 2, "row": 3, "cost": 90, "requires": ["patas_passada_2"],
		"name": "Passada Econômica",
		"desc": "Correndo, gasta metade da estamina do começo."},
	{"id": "patas_respiro_1", "branch": 2, "col": 1, "row": 1, "cost": 25, "requires": ["patas_folego"],
		"name": "Respiro",
		"desc": "A estamina volta mais rápido."},
	{"id": "patas_respiro_2", "branch": 2, "col": 1, "row": 2, "cost": 50, "requires": ["patas_respiro_1"],
		"name": "Respiro Fundo",
		"desc": "A estamina volta ainda mais rápido."},
	{"id": "patas_respiro_3", "branch": 2, "col": 1, "row": 3, "cost": 90, "requires": ["patas_respiro_2"],
		"name": "Segundo Fôlego",
		"desc": "A estamina volta mais que o dobro do começo."},
	{"id": "patas_ligeiras", "branch": 2, "col": 0, "row": 1, "cost": 70, "requires": ["patas_folego"],
		"name": "Patas Ligeiras",
		"desc": "Corre mais rápido: +50% sobre andar (eram +25%)."},
	{"id": "patas_lamber", "branch": 2, "col": 0, "row": 2, "cost": 80, "requires": ["patas_ligeiras"],
		"name": "Lamber Correndo",
		"desc": "Dá para lamber enquanto corre."},
	{"id": "patas_galope", "branch": 2, "col": 0, "row": 3, "cost": 120, "requires": ["patas_lamber"],
		"name": "Galope Silencioso",
		"desc": "Correndo, você não assusta mais os insetos."},
	# Faro: Farejar abre as linhas de Alcance (distância e quantidade) e de Precisão.
	{"id": "faro_farejar", "branch": 3, "col": -1, "row": 0, "cost": 20, "requires": [],
		"name": "Farejar",
		"desc": "[Q] Fareje: descubra quantos insetos há a até 10 m (até 100 deles) e a que distância está o mais perto. Recarrega em 10 s."},
	{"id": "faro_atento", "branch": 3, "col": 0, "row": 1, "cost": 40, "requires": ["faro_farejar"],
		"name": "Faro Atento",
		"desc": "Fareja até 16 m e até 250 insetos. Recarrega em 9 s."},
	{"id": "faro_apurado", "branch": 3, "col": 0, "row": 2, "cost": 70, "requires": ["faro_atento"],
		"name": "Faro Apurado",
		"desc": "Fareja até 24 m e até 500 insetos, e o cheiro dura mais. Recarrega em 8 s."},
	{"id": "faro_agucado", "branch": 3, "col": 0, "row": 3, "cost": 110, "requires": ["faro_apurado"],
		"name": "Faro Aguçado",
		"desc": "Fareja até 34 m e até 1000 insetos; a bússola mostra quanto falta em cada formigueiro. Recarrega em 7 s."},
	{"id": "faro_lendario", "branch": 3, "col": 0, "row": 4, "cost": 160, "requires": ["faro_agucado"],
		"name": "Faro Lendário",
		"desc": "Fareja até 50 m e até 2000 insetos, e marca as rainhas na bússola. Recarrega em 6 s."},
	{"id": "faro_preciso", "branch": 3, "col": 1, "row": 1, "cost": 45, "requires": ["faro_farejar"],
		"name": "Faro Preciso",
		"desc": "Uma nuvem de cheiro, meio borrada, mostra onde estão os insetos farejados."},
	{"id": "faro_nitido", "branch": 3, "col": 1, "row": 2, "cost": 85, "requires": ["faro_preciso"],
		"name": "Faro Nítido",
		"desc": "Os insetos farejados brilham nítidos, mesmo atrás do capim."},
	{"id": "faro_camara", "branch": 3, "col": 1, "row": 3, "cost": 100, "requires": ["faro_nitido"],
		"name": "Faro de Câmara",
		"desc": "Farejar também mostra as câmaras fechadas por perto (até no meio do campo), com uma coluna de cheiro."},
	# Escalada + Cauda (ainda não feita: aparece com cadeado)
	{"id": "escalada_1", "branch": 4, "col": 0, "row": 0, "cost": 300, "requires": [],
		"name": "Escalada",
		"desc": "Sobe em árvores e cupinzeiros para alcançar ninhos no alto."},
	{"id": "escalada_2", "branch": 4, "col": 0, "row": 1, "cost": 400, "requires": ["escalada_1"],
		"name": "Cauda Preênsil",
		"desc": "Pendura-se pela cauda para alcançar ninhos embaixo de galhos e do outro lado de vãos."},
]

## Regiões que o jogador já alcançou (o Cerrado é o começo).
var regions_reached: Array[String] = ["Cerrado"]

var ants_eaten: int = 0
var points_spent: int = 0
var purchased: Dictionary = {}
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
		if region_required(u.id).is_empty() and not has(u.id):
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


func has(id: String) -> bool:
	return purchased.get(id, false)


func get_upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}


func cost_of(id: String) -> int:
	return int(get_upgrade(id).get("cost", 0))


## Região necessária para comprar (vazio = disponível em qualquer lugar).
func region_required(id: String) -> String:
	var u := get_upgrade(id)
	if u.is_empty():
		return ""
	var region: String = BRANCHES[u.branch].get("region", "")
	if region.is_empty() or regions_reached.has(region):
		return ""
	return region


## Habilidades que faltam aprender antes desta.
func missing_requirements(id: String) -> Array[String]:
	var missing: Array[String] = []
	for r in get_upgrade(id).get("requires", []):
		if not has(String(r)):
			missing.append(String(r))
	return missing


## 0 = falta aprender outra antes, 1 = disponível, 2 = comprada, 3 = região ainda não alcançada
func upgrade_state(id: String) -> int:
	if has(id):
		return 2
	var u := get_upgrade(id)
	if u.is_empty():
		return 0
	if not region_required(id).is_empty():
		return 3
	if not missing_requirements(id).is_empty():
		return 0
	return 1


func can_buy(id: String) -> bool:
	return upgrade_state(id) == 1 and points_available() >= cost_of(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	purchased[id] = true
	points_spent += cost_of(id)
	_check_affordable(false)
	upgrade_purchased.emit(id)
	return true


## Testes (--buy): aprende sem gastar pontos.
func grant(id: String) -> void:
	if get_upgrade(id).is_empty() or has(id):
		return
	purchased[id] = true
	_check_affordable(false)
	upgrade_purchased.emit(id)


## Devolve todos os pontos para distribuir de novo (de graça).
func respec() -> void:
	purchased.clear()
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
		if best.is_empty() or u.cost < best.cost:
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


## Nível da linha de Bocado (0 = nenhum, 1..4).
func bocado_level() -> int:
	for k in [4, 3, 2, 1]:
		if has("lingua_bocado_%d" % k):
			return k
	return 0


## Quantas formigas uma lambida pega de uma vez.
func lick_capacity() -> int:
	return [10, 50, 150, 250, 400][bocado_level()]


func tongue_range() -> float:
	var r := 3.0
	if has("lingua_comprida"):
		r *= 1.5
	if frenzy_active():
		r *= 1.25
	return r


## Língua Certeira: a língua vai atrás da formiga mais perto da mira.
func tongue_tracking() -> bool:
	return has("lingua_certeira")


## Abertura (graus, do centro até a borda) da área da mira em que a língua
## procura formigas. Mira Ampla: 25% maior.
func aim_cone_deg() -> float:
	return 12.5 if has("lingua_mira") else 10.0


func capture_radius() -> float:
	var r: float = 0.34 * [1.0, 1.0, 1.15, 1.3, 1.45][bocado_level()]
	if has("lingua_saliva"):
		r *= 1.7
	return r


## Lambidas por segundo: começa devagar e acelera com a linha de Destreza.
func lick_rate() -> float:
	var r := 1.4
	if has("lingua_comprida"):
		r *= 1.25
	if has("lingua_saliva"):
		r *= 1.25
	if has("lingua_turbo"):
		r *= 2.0
	if frenzy_active():
		r *= 1.8
	return r


func can_dig() -> bool:
	return has("garras_cavar")


## Até que tamanho de buraco as garras abrem: 0 nenhum, 1 câmaras pequenas,
## 2 também as grandes (Cavar Fundo), 3 também o monte da rainha (Escavação Real).
func dig_level() -> int:
	if not has("garras_cavar"):
		return 0
	if has("garras_real"):
		return 3
	return 2 if has("garras_fundo") else 1


## A habilidade que abre buracos deste tamanho (1, 2 ou 3).
func dig_skill_for(size_class: int) -> String:
	return ["garras_cavar", "garras_cavar", "garras_fundo", "garras_real"][clampi(size_class, 0, 3)]


## Quanto tempo segurando [E] para abrir uma câmara.
func dig_time() -> float:
	return 0.6 if has("garras_incansaveis") else 1.2


## Descanso das garras depois de abrir uma câmara.
func dig_cooldown() -> float:
	if has("garras_incansaveis"):
		return 5.0
	if has("garras_ageis"):
		return 15.0
	return 25.0


## Quanto tempo as moradoras ficam tontas quando a câmara é aberta (0 = nada).
func dig_stun_time() -> float:
	return 2.5 if has("garras_fortes") else 0.0


func can_tremor() -> bool:
	return has("garras_tremor")


func tremor_radius() -> float:
	return 11.0 if has("garras_terremoto") else 6.0


func tremor_pulls() -> bool:
	return has("garras_terremoto")


func tremor_cooldown() -> float:
	if has("garras_recarga_2"):
		return 7.0
	if has("garras_recarga"):
		return 14.0
	return 21.0


## Força do pulo do Tremor (o Terremoto pula mais alto).
func tremor_jump_speed() -> float:
	return 7.4 if has("garras_terremoto") else 6.0


## Correr existe desde o começo; o limite é a estamina.
func can_run() -> bool:
	return true


## Estamina: correr gasta, e ela só volta sem correr (STAMINA_DELAY segundos
## depois de parar). Gastar e recuperar são por segundo.
const STAMINA_DELAY := 1.0
## Zerou: só volta a correr quando a estamina encher esta fração.
const STAMINA_RESUME := 0.25
const STAMINA_DRAIN := [10.0, 8.0, 6.5, 5.0]
const STAMINA_REGEN := [3.0, 4.5, 6.0, 7.0]


func stamina_max() -> float:
	var n := 0
	for id in ["patas_folego", "patas_folego_2", "patas_folego_3"]:
		if has(id):
			n += 1
	return 50.0 + 50.0 * n


func stamina_drain() -> float:
	return STAMINA_DRAIN[_level(["patas_passada_1", "patas_passada_2", "patas_passada_3"])]


func stamina_regen() -> float:
	return STAMINA_REGEN[_level(["patas_respiro_1", "patas_respiro_2", "patas_respiro_3"])]


func _level(ids: Array) -> int:
	var n := 0
	for id in ids:
		if has(id):
			n += 1
	return n


func walk_speed() -> float:
	return 3.3


## Correr: +25% sobre andar desde o começo, +50% com Patas Ligeiras.
func run_speed() -> float:
	return walk_speed() * (1.5 if has("patas_ligeiras") else 1.25)


func can_lick_running() -> bool:
	return has("patas_lamber")


func flee_multiplier(running: bool) -> float:
	return 1.8 if running and not has("patas_galope") else 1.0


func can_sniff() -> bool:
	return has("faro_farejar")


## Linha de Alcance do Faro: 0 = só Farejar, 1..4 = níveis comprados.
func faro_level() -> int:
	var lvl := 0
	for id in ["faro_atento", "faro_apurado", "faro_agucado", "faro_lendario"]:
		if has(id):
			lvl += 1
	return lvl


func sniff_radius() -> float:
	return [10.0, 16.0, 24.0, 34.0, 50.0][faro_level()]


## Quantas formigas o faro consegue sentir de uma vez (as mais perto).
func sniff_max_ants() -> int:
	return [100, 250, 500, 1000, 2000][faro_level()]


func sniff_duration() -> float:
	return [4.0, 4.5, 5.5, 6.0, 7.0][faro_level()]


func sniff_cooldown() -> float:
	return [10.0, 9.0, 8.0, 7.0, 6.0][faro_level()]


## 0 = só conta, 1 = nuvem borrada onde estão, 2 = formigas nítidas.
func sniff_precision() -> int:
	if has("faro_nitido"):
		return 2
	if has("faro_preciso"):
		return 1
	return 0


func sniff_chambers() -> bool:
	return has("faro_camara")


func sniff_nest_counts() -> bool:
	return has("faro_agucado")


func sniff_queens() -> bool:
	return has("faro_lendario")


## O que uma habilidade muda em números: [{"label", "before", "after"}], para a
## árvore mostrar "10 → 50". "—" quando a habilidade é que libera o gesto.
func stat_changes(id: String) -> Array:
	# Conta como se as habilidades anteriores da linha já estivessem aprendidas.
	var saved := purchased.duplicate()
	var fz := frenzy_time
	frenzy_time = 0.0
	var todo: Array = (get_upgrade(id).get("requires", []) as Array).duplicate()
	while not todo.is_empty():
		var r: String = todo.pop_back()
		if not purchased.get(r, false):
			purchased[r] = true
			todo.append_array(get_upgrade(r).get("requires", []))
	purchased.erase(id)
	var before := _stat_snapshot()
	purchased[id] = true
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
		["Raio do Tremor", _num(tremor_radius(), 0) + " m" if trem else ""],
		["Recarga do Tremor", _num(tremor_cooldown(), 0) + " s" if trem else ""],
		["Alcance do faro", _num(sniff_radius(), 0) + " m" if snf else ""],
		["Insetos farejados", str(sniff_max_ants()) if snf else ""],
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
		"purchased": purchased.keys(), "elapsed": elapsed, "best_combo": best_combo,
		"tanajuras_eaten": tanajuras_eaten, "queens_eaten": queens_eaten,
		"regions_reached": regions_reached, "completed": completed,
		"marker": [marker.x, marker.y] if marker != Vector2.INF else [],
		"mode": mode, "splits": splits.duplicate(), "stats": stats.duplicate(),
	}


func from_save(d: Dictionary) -> void:
	ants_eaten = int(d.get("ants_eaten", 0))
	purchased.clear()
	points_spent = 0
	for id in d.get("purchased", []):
		var key := String(id)
		if not get_upgrade(key).is_empty():
			purchased[key] = true
			points_spent += cost_of(key)
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
	if not parsed is Dictionary or int(parsed.get("version", 0)) != SAVE_VERSION:
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
