extends Node
## Estado da partida: formigas comidas, pontos de habilidade, upgrades e atributos.

signal ants_eaten_changed(total: int, delta: int)
signal skill_point_gained(available: int)
signal upgrade_purchased(id: String)
signal level_completed(time_sec: float)
signal frenzy_changed(active: bool)
signal run_reset

const GOAL := 1000
const ANTS_PER_POINT := 100
const SAVE_PATH := "user://save.cfg"

const BRANCHES := [
	{"id": "lingua", "name": "Língua", "color": Color(0.96, 0.45, 0.55)},
	{"id": "garras", "name": "Garras", "color": Color(0.95, 0.70, 0.30)},
	{"id": "corpo", "name": "Corpo", "color": Color(0.45, 0.75, 0.55)},
]

## Árvore: 3 ramos x 4 níveis. Cada ramo é comprado em ordem.
const UPGRADES := [
	{"id": "lingua_1", "branch": 0, "tier": 0, "name": "Língua Comprida",
		"desc": "Alcance da língua +50%."},
	{"id": "lingua_2", "branch": 0, "tier": 1, "name": "Saliva Grudenta",
		"desc": "Raio de captura +70%. Uma lambida pega o grupo inteiro."},
	{"id": "lingua_3", "branch": 0, "tier": 2, "name": "Lambida Dupla",
		"desc": "A língua dá duas lambidas no tempo de uma."},
	{"id": "lingua_4", "branch": 0, "tier": 3, "name": "Língua Chicote",
		"desc": "A língua varre o caminho todo e gruda tudo o que tocar."},
	{"id": "garras_1", "branch": 1, "tier": 0, "name": "Garras Afiadas",
		"desc": "Segure [E] perto de um formigueiro para cavar e soltar 25 formigas de uma vez."},
	{"id": "garras_2", "branch": 1, "tier": 1, "name": "Escavação Profunda",
		"desc": "Cava 2x mais rápido e solta o dobro de formigas."},
	{"id": "garras_3", "branch": 1, "tier": 2, "name": "Tremor",
		"desc": "[Espaço] Bata no chão: as formigas num raio de 6 m ficam tontas por 3 s."},
	{"id": "garras_4", "branch": 1, "tier": 3, "name": "Terremoto",
		"desc": "Tremor quase 2x maior, e as formigas tontas são puxadas para perto da sua boca."},
	{"id": "corpo_1", "branch": 2, "tier": 0, "name": "Patas Ligeiras",
		"desc": "Velocidade de movimento +30%."},
	{"id": "corpo_2", "branch": 2, "tier": 1, "name": "Pelagem Silenciosa",
		"desc": "O pelo abafa seus passos: as formigas só fogem quando você está bem perto."},
	{"id": "corpo_3", "branch": 2, "tier": 2, "name": "Disparada",
		"desc": "Correr vira galope: 60% mais rápido, e as trilhas nem percebem você chegando."},
	{"id": "corpo_4", "branch": 2, "tier": 3, "name": "Faro Lendário",
		"desc": "[Q] Farejar revela todas as formigas do mapa e recarrega 2x mais rápido."},
]

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_load_save()


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


func add_eaten(count: int, tanajuras: int = 0) -> void:
	if count <= 0 or completed:
		return
	count = mini(count, GOAL - ants_eaten)
	var before := ants_eaten
	ants_eaten += count
	combo += count
	combo_timer = 2.5
	best_combo = maxi(best_combo, combo)
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
			_save()
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


## 0 = bloqueado, 1 = disponível (pode comprar), 2 = comprado
func upgrade_state(id: String) -> int:
	if has(id):
		return 2
	var u := get_upgrade(id)
	if u.is_empty():
		return 0
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


func frenzy_active() -> bool:
	return frenzy_time > 0.0


# ---------------------------------------------------------------- Atributos

func tongue_range() -> float:
	var r := 3.0
	if has("lingua_1"):
		r *= 1.5
	if frenzy_active():
		r *= 1.25
	return r


func capture_radius() -> float:
	return 0.34 * (1.7 if has("lingua_2") else 1.0)


func lick_rate() -> float:
	var r := 3.2
	if has("lingua_3"):
		r *= 2.0
	if frenzy_active():
		r *= 1.8
	return r


func tongue_sweeps() -> bool:
	return has("lingua_4")


func can_dig() -> bool:
	return has("garras_1")


func dig_time() -> float:
	return 0.55 if has("garras_2") else 1.1


func dig_burst() -> int:
	return 50 if has("garras_2") else 25


func can_tremor() -> bool:
	return has("garras_3")


func tremor_radius() -> float:
	return 11.0 if has("garras_4") else 6.0


func tremor_pulls() -> bool:
	return has("garras_4")


func walk_speed() -> float:
	return 3.3 * (1.3 if has("corpo_1") else 1.0)


func run_speed() -> float:
	var s := 6.2 * (1.3 if has("corpo_1") else 1.0)
	if has("corpo_3"):
		s *= 1.6
	return s


func flee_multiplier(running: bool) -> float:
	var m := 1.0
	if has("corpo_2"):
		m *= 0.45
	if running and not has("corpo_3"):
		m *= 1.8
	return m


func sniff_radius() -> float:
	return 400.0 if has("corpo_4") else 24.0


func sniff_duration() -> float:
	return 6.0 if has("corpo_4") else 4.0


func sniff_cooldown() -> float:
	return 4.5 if has("corpo_4") else 9.0


# ---------------------------------------------------------------- Save

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_time = float(cfg.get_value("records", "best_time", 0.0))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_time", best_time)
	cfg.save(SAVE_PATH)


static func format_time(t: float) -> String:
	var total := int(t)
	return "%d:%02d" % [total / 60, total % 60]
