extends Node
## Estado da partida: formigas comidas, pontos, habilidades compradas,
## atributos do tamanduá, recorde e o jogo salvo.
##
## Economia: as formigas andam em grupos de 10, e cada grupo comido (10
## formigas) vale 1 ponto; a rainha vale 20 pontos (200 formigas). Cada
## habilidade tem o seu preço. `ants_eaten` conta pontos: na tela, as
## formigas são `ants(ants_eaten)`. Os pontos gastos podem ser devolvidos de graça
## ("Redistribuir pontos").

signal ants_eaten_changed(total: int, delta: int)
## Uma habilidade que ainda não dava para comprar agora cabe nos pontos.
signal upgrade_affordable(id: String)
signal upgrade_purchased(id: String)
signal skills_reset
signal level_completed(time_sec: float)
signal frenzy_changed(active: bool)
signal run_reset

## Pontos da colônia do Cerrado: 3200 grupos de 10 (32 000 formigas; cada
## rainha conta como 20 pontos).
const GOAL := 3200
## Formigas em cada ponto (um grupo de formigas).
const ANTS_PER_POINT := 10
## Quanto dura o Frenesi (depois de comer uma tanajura), em segundos.
const FRENZY_TIME := 6.0
const RECORD_PATH := "user://save.cfg"
const GAME_SAVE_PATH := "user://jogo_salvo.json"
## Versão do jogo salvo: saves de versões com outro mapa não são carregados.
const SAVE_VERSION := 3

## As 5 habilidades. "lines" = nomes das duas linhas (quando o ramo se divide).
## "region" = só pode ser comprada ao chegar nessa região.
const BRANCHES := [
	{"id": "lingua", "name": "Língua", "color": Color(0.96, 0.45, 0.55), "lines": ["Bocado", "Destreza", "Mira"]},
	{"id": "garras", "name": "Garras", "color": Color(0.95, 0.70, 0.30), "lines": ["Força", "Rapidez", "Fundura"]},
	{"id": "patas", "name": "Patas", "color": Color(0.45, 0.75, 0.55), "lines": ["Velocidade", "Agilidade"]},
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
		"desc": "Cada lambida pega até 50 formigas perto da ponta da língua."},
	{"id": "lingua_bocado_2", "branch": 0, "col": 0, "row": 2, "cost": 75, "requires": ["lingua_bocado_1"],
		"name": "Lambida Larga",
		"desc": "Até 150 formigas por lambida, e a ponta gruda num raio um pouco maior."},
	{"id": "lingua_bocado_3", "branch": 0, "col": 0, "row": 3, "cost": 115, "requires": ["lingua_bocado_2"],
		"name": "Lambida Gulosa",
		"desc": "Até 250 formigas por lambida."},
	{"id": "lingua_bocado_4", "branch": 0, "col": 0, "row": 4, "cost": 170, "requires": ["lingua_bocado_3"],
		"name": "Lambida Voraz",
		"desc": "Até 400 formigas por lambida."},
	{"id": "lingua_comprida", "branch": 0, "col": 1, "row": 1, "cost": 70, "requires": ["lingua_segurar"],
		"name": "Língua Comprida",
		"desc": "Alcance da língua +50%."},
	{"id": "lingua_saliva", "branch": 0, "col": 1, "row": 2, "cost": 100, "requires": ["lingua_comprida"],
		"name": "Saliva Grudenta",
		"desc": "A ponta da língua gruda num raio 70% maior."},
	{"id": "lingua_turbo", "branch": 0, "col": 1, "row": 3, "cost": 150, "requires": ["lingua_saliva"],
		"name": "Língua Turbo",
		"desc": "A língua lambe 2x mais rápido."},
	{"id": "lingua_certeira", "branch": 0, "col": 2, "row": 1, "cost": 30, "requires": ["lingua_segurar"],
		"name": "Língua Certeira",
		"desc": "A língua vai sozinha atrás da formiga mais perto da mira."},
	{"id": "lingua_mira", "branch": 0, "col": 2, "row": 2, "cost": 60, "requires": ["lingua_certeira"],
		"name": "Mira Ampla",
		"desc": "A área da mira em que a língua procura formigas fica 25% maior."},
	# Garras: Cavar abre as linhas de Força, de Rapidez (o descanso entre usos)
	# e de Fundura (buracos maiores: câmaras grandes e a vala da rainha).
	{"id": "garras_cavar", "branch": 1, "col": -1, "row": 0, "cost": 35, "requires": [],
		"name": "Cavar",
		"desc": "Segure [E] perto de uma câmara pequena fechada para abri-la. Depois, as garras descansam 25 s."},
	{"id": "garras_fundo", "branch": 1, "col": 2, "row": 1, "cost": 60, "requires": ["garras_cavar"],
		"name": "Cavar Fundo",
		"desc": "Abre também as câmaras grandes, as dos formigueiros grandes."},
	{"id": "garras_real", "branch": 1, "col": 2, "row": 2, "cost": 120, "requires": ["garras_fundo"],
		"name": "Escavação Real",
		"desc": "Cava a vala da rainha, no pé dos formigueiros grandes: ela e a corte dela estão lá dentro."},
	{"id": "garras_fortes", "branch": 1, "col": 0, "row": 1, "cost": 70, "requires": ["garras_cavar"],
		"name": "Garras Fortes",
		"desc": "Abrir uma câmara deixa as moradoras tontas por 2,5 s: elas não fogem logo."},
	{"id": "garras_tremor", "branch": 1, "col": 0, "row": 2, "cost": 110, "requires": ["garras_fortes"],
		"name": "Tremor",
		"desc": "[Espaço] Pule e caia com força: as formigas num raio de 6 m ficam tontas por 3 s. Recarrega em 21 s."},
	{"id": "garras_terremoto", "branch": 1, "col": 0, "row": 3, "cost": 170, "requires": ["garras_tremor"],
		"name": "Terremoto",
		"desc": "Pulo mais alto e tremor quase 2x maior; as formigas tontas são puxadas para a sua boca."},
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
	{"id": "patas_corrida", "branch": 2, "col": -1, "row": 0, "cost": 30, "requires": [],
		"name": "Corrida",
		"desc": "Corra com [Shift]: +25% de velocidade. Correndo não dá para lamber, e as formigas fogem mais cedo."},
	{"id": "patas_ligeiras", "branch": 2, "col": 0, "row": 1, "cost": 80, "requires": ["patas_corrida"],
		"name": "Patas Ligeiras",
		"desc": "Corre mais 25%."},
	{"id": "patas_galope", "branch": 2, "col": 0, "row": 2, "cost": 130, "requires": ["patas_ligeiras"],
		"name": "Galope Silencioso",
		"desc": "Correndo, você não assusta mais as formigas."},
	{"id": "patas_lamber", "branch": 2, "col": 1, "row": 1, "cost": 60, "requires": ["patas_corrida"],
		"name": "Lamber Correndo",
		"desc": "Dá para lamber enquanto corre."},
	# Faro: Farejar abre as linhas de Alcance (distância e quantidade) e de Precisão.
	{"id": "faro_farejar", "branch": 3, "col": -1, "row": 0, "cost": 20, "requires": [],
		"name": "Farejar",
		"desc": "[Q] Fareje: descubra quantas formigas há a até 10 m (até 100 delas) e a que distância está a mais perto. Recarrega em 10 s."},
	{"id": "faro_atento", "branch": 3, "col": 0, "row": 1, "cost": 40, "requires": ["faro_farejar"],
		"name": "Faro Atento",
		"desc": "Fareja até 16 m e até 250 formigas. Recarrega em 9 s."},
	{"id": "faro_apurado", "branch": 3, "col": 0, "row": 2, "cost": 70, "requires": ["faro_atento"],
		"name": "Faro Apurado",
		"desc": "Fareja até 24 m e até 500 formigas, e o cheiro dura mais. Recarrega em 8 s."},
	{"id": "faro_agucado", "branch": 3, "col": 0, "row": 3, "cost": 110, "requires": ["faro_apurado"],
		"name": "Faro Aguçado",
		"desc": "Fareja até 34 m e até 1000 formigas; a bússola mostra quanto falta em cada formigueiro. Recarrega em 7 s."},
	{"id": "faro_lendario", "branch": 3, "col": 0, "row": 4, "cost": 160, "requires": ["faro_agucado"],
		"name": "Faro Lendário",
		"desc": "Fareja até 50 m e até 2000 formigas, e marca as rainhas na bússola. Recarrega em 6 s."},
	{"id": "faro_preciso", "branch": 3, "col": 1, "row": 1, "cost": 45, "requires": ["faro_farejar"],
		"name": "Faro Preciso",
		"desc": "Uma nuvem de cheiro, meio borrada, mostra onde estão as formigas farejadas."},
	{"id": "faro_nitido", "branch": 3, "col": 1, "row": 2, "cost": 85, "requires": ["faro_preciso"],
		"name": "Faro Nítido",
		"desc": "As formigas farejadas brilham nítidas, mesmo atrás do capim."},
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
var queens_eaten: int = 0
## Habilidades que já cabiam nos pontos (para avisar só das novas).
var _affordable: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_load_record()


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
	_affordable.clear()
	run_reset.emit()
	ants_eaten_changed.emit(0, 0)


func _process(delta: float) -> void:
	if not playing or completed:
		return
	elapsed += delta
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
	if frenzy_time > 0.0:
		frenzy_time -= delta
		if frenzy_time <= 0.0:
			frenzy_time = 0.0
			frenzy_changed.emit(false)


## Soma formigas comidas. `count` já vem com o valor da rainha (20) incluído.
func add_eaten(count: int, tanajuras: int = 0, queens: int = 0) -> void:
	if count <= 0 or completed:
		return
	count = mini(count, GOAL - ants_eaten)
	ants_eaten += count
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
		if (best_time <= 0.0 or elapsed < best_time) and not DevTools.autoplay:
			best_time = elapsed
			_save_record()
		level_completed.emit(elapsed)


## Formigas que cabem em `points` pontos (para mostrar na tela).
func ants(points: int) -> int:
	return points * ANTS_PER_POINT


## Pontos para gastar: 1 por grupo de 10 formigas comido, menos o que já foi gasto.
func points_available() -> int:
	return ants_eaten - points_spent


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


## Quantos grupos de formigas (de 10) uma lambida pega de uma vez.
func lick_capacity() -> int:
	return [1, 5, 15, 25, 40][bocado_level()]


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


func lick_rate() -> float:
	var r := 3.2
	if has("lingua_turbo"):
		r *= 2.0
	if frenzy_active():
		r *= 1.8
	return r


func can_dig() -> bool:
	return has("garras_cavar")


## Até que tamanho de buraco as garras abrem: 0 nenhum, 1 câmaras pequenas,
## 2 também as grandes (Cavar Fundo), 3 também a vala da rainha (Escavação Real).
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


func can_run() -> bool:
	return has("patas_corrida")


func walk_speed() -> float:
	return 3.3


## Correr: +25% com Corrida e mais 25% com Patas Ligeiras.
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


## Quantos grupos de formigas o faro consegue sentir de uma vez (os mais perto).
func sniff_max_ants() -> int:
	return [10, 25, 50, 100, 200][faro_level()]


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


# ---------------------------------------------------------------- Recorde e jogo salvo

func _load_record() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RECORD_PATH) == OK:
		# O recorde é por versão do mapa: tempos de 1000 formigas não contam.
		best_time = float(cfg.get_value("records", "best_time_%d" % GOAL, 0.0))


func _save_record() -> void:
	var cfg := ConfigFile.new()
	cfg.load(RECORD_PATH)
	cfg.set_value("records", "best_time_%d" % GOAL, best_time)
	cfg.save(RECORD_PATH)


func to_save() -> Dictionary:
	return {
		"ants_eaten": ants_eaten, "points_spent": points_spent,
		"purchased": purchased.keys(), "elapsed": elapsed, "best_combo": best_combo,
		"tanajuras_eaten": tanajuras_eaten, "queens_eaten": queens_eaten,
		"regions_reached": regions_reached, "completed": completed,
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
	combo = 0
	frenzy_time = 0.0
	_check_affordable(false)
	ants_eaten_changed.emit(ants_eaten, 0)


## Só conta como jogo salvo se for da versão atual do mapa.
func has_saved_game() -> bool:
	return not read_saved_game().is_empty()


func write_saved_game(data: Dictionary) -> void:
	if DevTools.autoplay and not DevTools.args.has("allow-save"):
		return
	var f := FileAccess.open(GAME_SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func read_saved_game() -> Dictionary:
	if not FileAccess.file_exists(GAME_SAVE_PATH):
		return {}
	var txt := FileAccess.get_file_as_string(GAME_SAVE_PATH)
	var parsed = JSON.parse_string(txt)
	if not parsed is Dictionary or int(parsed.get("version", 0)) != SAVE_VERSION:
		return {}
	return parsed


func delete_saved_game() -> void:
	if FileAccess.file_exists(GAME_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GAME_SAVE_PATH))


static func format_time(t: float) -> String:
	var total := int(t)
	return "%d:%02d" % [total / 60, total % 60]
