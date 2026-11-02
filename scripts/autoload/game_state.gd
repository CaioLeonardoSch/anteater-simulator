extends Node
## Estado da partida: formigas comidas, pontos de habilidade, habilidades
## compradas, atributos do tamanduá, recorde e o jogo salvo.

signal ants_eaten_changed(total: int, delta: int)
signal skill_point_gained(available: int)
signal upgrade_purchased(id: String)
signal skills_reset
signal level_completed(time_sec: float)
signal frenzy_changed(active: bool)
signal run_reset

const GOAL := 1000
const ANTS_PER_POINT := 100
const RECORD_PATH := "user://save.cfg"
const GAME_SAVE_PATH := "user://jogo_salvo.json"

## As 5 habilidades. "region" = só pode ser comprada ao chegar nessa região.
const BRANCHES := [
	{"id": "lingua", "name": "Língua", "color": Color(0.96, 0.45, 0.55)},
	{"id": "garras", "name": "Garras", "color": Color(0.95, 0.70, 0.30)},
	{"id": "patas", "name": "Patas", "color": Color(0.45, 0.75, 0.55)},
	{"id": "faro", "name": "Faro", "color": Color(0.55, 0.70, 0.98)},
	{"id": "escalada", "name": "Escalada + Cauda", "color": Color(0.80, 0.62, 0.42), "region": "Floresta"},
]

## Cada habilidade tem níveis, comprados em ordem com pontos.
const UPGRADES := [
	{"id": "lingua_1", "branch": 0, "tier": 0, "name": "Lambida",
		"desc": "A língua gruda todas as formigas perto da ponta, não só uma."},
	{"id": "lingua_2", "branch": 0, "tier": 1, "name": "Língua Comprida",
		"desc": "Alcance da língua +50%."},
	{"id": "lingua_3", "branch": 0, "tier": 2, "name": "Saliva Grudenta",
		"desc": "Raio de captura +70%: uma lambida pega o grupo inteiro."},
	{"id": "lingua_4", "branch": 0, "tier": 3, "name": "Língua Turbo",
		"desc": "A língua lambe 2x mais rápido."},
	{"id": "garras_1", "branch": 1, "tier": 0, "name": "Cavar",
		"desc": "Segure [E] perto de uma câmara fechada para abri-la e comer quem mora lá dentro."},
	{"id": "garras_2", "branch": 1, "tier": 1, "name": "Garras Fortes",
		"desc": "Cava 3x mais rápido."},
	{"id": "garras_3", "branch": 1, "tier": 2, "name": "Tremor",
		"desc": "[Espaço] Bata no chão: as formigas num raio de 6 m ficam tontas por 3 s."},
	{"id": "garras_4", "branch": 1, "tier": 3, "name": "Terremoto",
		"desc": "Tremor quase 2x maior, e as formigas tontas são puxadas para a sua boca."},
	{"id": "patas_1", "branch": 2, "tier": 0, "name": "Corrida",
		"desc": "Libera correr com [Shift]. Correndo, as formigas fogem mais cedo."},
	{"id": "patas_2", "branch": 2, "tier": 1, "name": "Patas Ligeiras",
		"desc": "Anda e corre 30% mais rápido."},
	{"id": "patas_3", "branch": 2, "tier": 2, "name": "Galope Silencioso",
		"desc": "Corre 60% mais rápido e sem assustar as formigas."},
	{"id": "faro_1", "branch": 3, "tier": 0, "name": "Faro Apurado",
		"desc": "[Q] Farejar alcança 30 m e a bússola aponta o maior grupo de formigas."},
	{"id": "faro_2", "branch": 3, "tier": 1, "name": "Faro de Ninho",
		"desc": "Farejar mostra na bússola os formigueiros que ainda têm formigas, e quantas."},
	{"id": "faro_3", "branch": 3, "tier": 2, "name": "Faro Lendário",
		"desc": "Farejar alcança o mapa todo, marca as rainhas e recarrega 2x mais rápido."},
	{"id": "escalada_1", "branch": 4, "tier": 0, "name": "Escalada",
		"desc": "Sobe em árvores e cupinzeiros para alcançar ninhos no alto."},
	{"id": "escalada_2", "branch": 4, "tier": 1, "name": "Cauda Preênsil",
		"desc": "Pendura-se pela cauda para alcançar ninhos embaixo de galhos e do outro lado de vãos."},
]

## Regiões que o jogador já alcançou (o Cerrado é o começo).
var regions_reached: Array[String] = ["Cerrado"]

var ants_eaten: int = 0
var points_earned: int = 0
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_load_record()


func reset_run() -> void:
	ants_eaten = 0
	points_earned = 0
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
	var before := ants_eaten
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
	var new_points := mini(ants_eaten / ANTS_PER_POINT, (GOAL / ANTS_PER_POINT) - 1)
	var old_points := mini(before / ANTS_PER_POINT, (GOAL / ANTS_PER_POINT) - 1)
	if new_points > old_points:
		points_earned += new_points - old_points
		skill_point_gained.emit(points_available())
	if ants_eaten >= GOAL:
		completed = true
		if (best_time <= 0.0 or elapsed < best_time) and not DevTools.autoplay:
			best_time = elapsed
			_save_record()
		level_completed.emit(elapsed)


func points_available() -> int:
	return points_earned - points_spent


func has(id: String) -> bool:
	return purchased.get(id, false)


func get_upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}


## Região necessária para comprar (vazio = disponível em qualquer lugar).
func region_required(id: String) -> String:
	var u := get_upgrade(id)
	if u.is_empty():
		return ""
	var region: String = BRANCHES[u.branch].get("region", "")
	if region.is_empty() or regions_reached.has(region):
		return ""
	return region


## 0 = bloqueado, 1 = disponível (pode comprar), 2 = comprado, 3 = região ainda não alcançada
func upgrade_state(id: String) -> int:
	if has(id):
		return 2
	var u := get_upgrade(id)
	if u.is_empty():
		return 0
	if not region_required(id).is_empty():
		return 3
	if u.tier > 0:
		var prev := "%s_%d" % [BRANCHES[u.branch].id, u.tier]
		if not has(prev):
			return 0
	return 1


func can_buy(id: String) -> bool:
	return upgrade_state(id) == 1 and points_available() > 0


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	purchased[id] = true
	points_spent += 1
	upgrade_purchased.emit(id)
	return true


## Devolve todos os pontos para distribuir de novo (de graça).
func respec() -> void:
	purchased.clear()
	points_spent = 0
	skills_reset.emit()


func frenzy_active() -> bool:
	return frenzy_time > 0.0


# ---------------------------------------------------------------- Atributos

## Sem a Lambida, cada lambida pega só uma formiga (bicada).
func lick_grabs_all() -> bool:
	return has("lingua_1")


func tongue_range() -> float:
	var r := 3.0
	if has("lingua_2"):
		r *= 1.5
	if frenzy_active():
		r *= 1.25
	return r


func capture_radius() -> float:
	return 0.34 * (1.7 if has("lingua_3") else 1.0)


func lick_rate() -> float:
	var r := 3.2
	if has("lingua_4"):
		r *= 2.0
	if frenzy_active():
		r *= 1.8
	return r


func can_dig() -> bool:
	return has("garras_1")


func dig_time() -> float:
	return 0.4 if has("garras_2") else 1.2


func can_tremor() -> bool:
	return has("garras_3")


func tremor_radius() -> float:
	return 11.0 if has("garras_4") else 6.0


func tremor_pulls() -> bool:
	return has("garras_4")


func can_run() -> bool:
	return has("patas_1")


func walk_speed() -> float:
	return 3.3 * (1.3 if has("patas_2") else 1.0)


func run_speed() -> float:
	var s := 6.2 * (1.3 if has("patas_2") else 1.0)
	if has("patas_3"):
		s *= 1.6
	return s


func flee_multiplier(running: bool) -> float:
	return 1.8 if running and not has("patas_3") else 1.0


## 0 = faro básico, 1..3 = níveis comprados.
func faro_level() -> int:
	if has("faro_3"):
		return 3
	if has("faro_2"):
		return 2
	if has("faro_1"):
		return 1
	return 0


func sniff_radius() -> float:
	return [14.0, 30.0, 45.0, 400.0][faro_level()]


func sniff_duration() -> float:
	return 6.0 if faro_level() == 3 else 4.0


func sniff_cooldown() -> float:
	return 4.0 if faro_level() == 3 else 8.0


# ---------------------------------------------------------------- Recorde e jogo salvo

func _load_record() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RECORD_PATH) == OK:
		best_time = float(cfg.get_value("records", "best_time", 0.0))


func _save_record() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_time", best_time)
	cfg.save(RECORD_PATH)


func to_save() -> Dictionary:
	return {
		"ants_eaten": ants_eaten, "points_earned": points_earned, "points_spent": points_spent,
		"purchased": purchased.keys(), "elapsed": elapsed, "best_combo": best_combo,
		"tanajuras_eaten": tanajuras_eaten, "queens_eaten": queens_eaten,
		"regions_reached": regions_reached,
	}


func from_save(d: Dictionary) -> void:
	ants_eaten = int(d.get("ants_eaten", 0))
	points_earned = int(d.get("points_earned", 0))
	points_spent = int(d.get("points_spent", 0))
	purchased.clear()
	for id in d.get("purchased", []):
		purchased[String(id)] = true
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
	ants_eaten_changed.emit(ants_eaten, 0)


func has_saved_game() -> bool:
	return FileAccess.file_exists(GAME_SAVE_PATH)


func write_saved_game(data: Dictionary) -> void:
	if DevTools.autoplay and not DevTools.args.has("allow-save"):
		return
	var f := FileAccess.open(GAME_SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func read_saved_game() -> Dictionary:
	if not has_saved_game():
		return {}
	var txt := FileAccess.get_file_as_string(GAME_SAVE_PATH)
	var parsed = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func delete_saved_game() -> void:
	if has_saved_game():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GAME_SAVE_PATH))


static func format_time(t: float) -> String:
	var total := int(t)
	return "%d:%02d" % [total / 60, total % 60]
