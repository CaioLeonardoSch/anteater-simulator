extends Node
## Estado da partida: formigas comidas, pontos, habilidades compradas,
## atributos do tamanduá, recorde e o jogo salvo.
##
## Economia: cada formiga comida vale 1 ponto (a rainha vale 20) e cada
## habilidade tem o seu preço. Os pontos gastos podem ser devolvidos de graça
## ("Redistribuir pontos").

signal ants_eaten_changed(total: int, delta: int)
## Uma habilidade que ainda não dava para comprar agora cabe nos pontos.
signal upgrade_affordable(id: String)
signal upgrade_purchased(id: String)
signal skills_reset
signal level_completed(time_sec: float)
signal frenzy_changed(active: bool)
signal run_reset

## Formigas da colônia do Cerrado (cada rainha conta como 20).
const GOAL := 3200
const RECORD_PATH := "user://save.cfg"
const GAME_SAVE_PATH := "user://jogo_salvo.json"
## Versão do jogo salvo: saves de versões com outro mapa não são carregados.
const SAVE_VERSION := 2

## As 5 habilidades. "lines" = nomes das duas linhas (quando o ramo se divide).
## "region" = só pode ser comprada ao chegar nessa região.
const BRANCHES := [
	{"id": "lingua", "name": "Língua", "color": Color(0.96, 0.45, 0.55), "lines": []},
	{"id": "garras", "name": "Garras", "color": Color(0.95, 0.70, 0.30), "lines": ["Força", "Rapidez"]},
	{"id": "patas", "name": "Patas", "color": Color(0.45, 0.75, 0.55), "lines": ["Velocidade", "Agilidade"]},
	{"id": "faro", "name": "Faro", "color": Color(0.55, 0.70, 0.98), "lines": ["Alcance", "Fôlego"]},
	{"id": "escalada", "name": "Escalada + Cauda", "color": Color(0.80, 0.62, 0.42), "lines": [], "region": "Floresta"},
]

## Cada habilidade: ramo, posição na árvore (col -1 = topo do ramo, centralizado;
## 0/1 = linha da esquerda/direita), preço em formigas e o que precisa antes.
const UPGRADES := [
	# Língua
	{"id": "lingua_segurar", "branch": 0, "col": 0, "row": 0, "cost": 25, "requires": [],
		"name": "Lambida Contínua",
		"desc": "Segure o botão para lamber sem parar. Sem ela, cada clique é uma lambida."},
	{"id": "lingua_lambida", "branch": 0, "col": 0, "row": 1, "cost": 50, "requires": ["lingua_segurar"],
		"name": "Lambida",
		"desc": "A língua gruda todas as formigas perto da ponta, não só uma."},
	{"id": "lingua_comprida", "branch": 0, "col": 0, "row": 2, "cost": 90, "requires": ["lingua_lambida"],
		"name": "Língua Comprida",
		"desc": "Alcance da língua +50%."},
	{"id": "lingua_saliva", "branch": 0, "col": 0, "row": 3, "cost": 140, "requires": ["lingua_comprida"],
		"name": "Saliva Grudenta",
		"desc": "Raio de captura +70%: uma lambida pega o grupo inteiro."},
	{"id": "lingua_turbo", "branch": 0, "col": 0, "row": 4, "cost": 200, "requires": ["lingua_saliva"],
		"name": "Língua Turbo",
		"desc": "A língua lambe 2x mais rápido."},
	# Garras: Cavar abre as duas linhas (Força e Rapidez), que não se excluem.
	{"id": "garras_cavar", "branch": 1, "col": -1, "row": 0, "cost": 35, "requires": [],
		"name": "Cavar",
		"desc": "Segure [E] perto de uma câmara fechada para abri-la e comer quem mora lá dentro."},
	{"id": "garras_fortes", "branch": 1, "col": 0, "row": 1, "cost": 80, "requires": ["garras_cavar"],
		"name": "Garras Fortes",
		"desc": "Abrir uma câmara deixa as moradoras tontas por 2,5 s: nenhuma foge da língua."},
	{"id": "garras_tremor", "branch": 1, "col": 0, "row": 2, "cost": 130, "requires": ["garras_fortes"],
		"name": "Tremor",
		"desc": "[Espaço] Bata no chão: as formigas num raio de 6 m ficam tontas por 3 s."},
	{"id": "garras_terremoto", "branch": 1, "col": 0, "row": 3, "cost": 200, "requires": ["garras_tremor"],
		"name": "Terremoto",
		"desc": "Tremor quase 2x maior, e as formigas tontas são puxadas para a sua boca."},
	{"id": "garras_rapidas", "branch": 1, "col": 1, "row": 1, "cost": 60, "requires": ["garras_cavar"],
		"name": "Cavada Rápida",
		"desc": "Menos espera para abrir uma câmara: 1,2 s vira 0,75 s."},
	{"id": "garras_relampago", "branch": 1, "col": 1, "row": 2, "cost": 110, "requires": ["garras_rapidas"],
		"name": "Cavada Relâmpago",
		"desc": "Abre uma câmara em 0,35 s."},
	{"id": "garras_recarga", "branch": 1, "col": 1, "row": 3, "cost": 160, "requires": ["garras_relampago"],
		"name": "Recarga Rápida",
		"desc": "O Tremor (e o Terremoto) recarrega 2x mais rápido: 8 s vira 4 s."},
	# Patas
	{"id": "patas_corrida", "branch": 2, "col": -1, "row": 0, "cost": 30, "requires": [],
		"name": "Corrida",
		"desc": "Corra com [Shift]: +25% de velocidade. Correndo não dá para lamber, e as formigas fogem mais cedo."},
	{"id": "patas_ligeiras", "branch": 2, "col": 0, "row": 1, "cost": 90, "requires": ["patas_corrida"],
		"name": "Patas Ligeiras",
		"desc": "Corre mais 25%: o dobro do bônus (+50%)."},
	{"id": "patas_galope", "branch": 2, "col": 0, "row": 2, "cost": 150, "requires": ["patas_ligeiras"],
		"name": "Galope Silencioso",
		"desc": "Correndo, você não assusta mais as formigas."},
	{"id": "patas_lamber", "branch": 2, "col": 1, "row": 1, "cost": 70, "requires": ["patas_corrida"],
		"name": "Lamber Correndo",
		"desc": "Dá para lamber enquanto corre."},
	# Faro: Faro Apurado abre as linhas de Alcance e de Fôlego.
	{"id": "faro_apurado", "branch": 3, "col": -1, "row": 0, "cost": 30, "requires": [],
		"name": "Faro Apurado",
		"desc": "[Q] Farejar alcança 30 m e a bússola aponta o maior grupo de formigas."},
	{"id": "faro_ninho", "branch": 3, "col": 0, "row": 1, "cost": 80, "requires": ["faro_apurado"],
		"name": "Faro de Ninho",
		"desc": "Farejar mostra na bússola os formigueiros que ainda têm formigas, e quantas."},
	{"id": "faro_lendario", "branch": 3, "col": 0, "row": 2, "cost": 170, "requires": ["faro_ninho"],
		"name": "Faro Lendário",
		"desc": "Farejar alcança o mapa todo e marca as rainhas na bússola."},
	{"id": "faro_folego", "branch": 3, "col": 1, "row": 1, "cost": 50, "requires": ["faro_apurado"],
		"name": "Fôlego",
		"desc": "Menos espera entre uma farejada e outra: 8 s vira 5 s."},
	{"id": "faro_duradouro", "branch": 3, "col": 1, "row": 2, "cost": 90, "requires": ["faro_folego"],
		"name": "Faro Duradouro",
		"desc": "O faro dura mais: 4 s vira 7 s."},
	{"id": "faro_incansavel", "branch": 3, "col": 1, "row": 3, "cost": 140, "requires": ["faro_duradouro"],
		"name": "Faro Incansável",
		"desc": "Quase sem espera: fareje de novo depois de 2 s."},
	# Escalada + Cauda (Floresta)
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
		frenzy_time = 6.0
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


## Pontos para gastar: 1 por formiga comida, menos o que já foi gasto.
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


## Sem a Lambida, cada lambida pega só uma formiga (bicada).
func lick_grabs_all() -> bool:
	return has("lingua_lambida")


func tongue_range() -> float:
	var r := 3.0
	if has("lingua_comprida"):
		r *= 1.5
	if frenzy_active():
		r *= 1.25
	return r


func capture_radius() -> float:
	return 0.34 * (1.7 if has("lingua_saliva") else 1.0)


func lick_rate() -> float:
	var r := 3.2
	if has("lingua_turbo"):
		r *= 2.0
	if frenzy_active():
		r *= 1.8
	return r


func can_dig() -> bool:
	return has("garras_cavar")


func dig_time() -> float:
	if has("garras_relampago"):
		return 0.35
	if has("garras_rapidas"):
		return 0.75
	return 1.2


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
	return 4.0 if has("garras_recarga") else 8.0


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


## Linha de Alcance do Faro: 0 = faro básico, 1..3 = níveis comprados.
func faro_level() -> int:
	if has("faro_lendario"):
		return 3
	if has("faro_ninho"):
		return 2
	if has("faro_apurado"):
		return 1
	return 0


func sniff_radius() -> float:
	return [14.0, 30.0, 45.0, 400.0][faro_level()]


func sniff_duration() -> float:
	return 7.0 if has("faro_duradouro") else 4.0


func sniff_cooldown() -> float:
	if has("faro_incansavel"):
		return 2.0
	if has("faro_folego"):
		return 5.0
	return 8.0


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
		"regions_reached": regions_reached,
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
	completed = false
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
