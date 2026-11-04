extends Node
## A colônia do Cerrado: GameState.GOAL formigas ao todo (cada rainha conta
## como 20). Cada formigueiro guarda forrageiras, que saem pelas trilhas e
## voltam, e moradoras, que vivem nas câmaras e só aparecem quando você cava.
## Numa câmara aberta ficam até CHAMBER_VISIBLE à vista; as outras saem do
## túnel conforme você come. Só as formigas que você come somem de vez.

signal wave_announced(wave: int, nest_name: String, count: int, nest_index: int)
signal final_wave(remaining: int)
signal chamber_opened(nest, chamber_index: int)
signal chamber_cleaned(nest, chamber_index: int)
signal nest_cleaned(nest)
signal queen_eaten(nest)

const Nest := preload("res://scripts/world/nest.gd")
const QUEEN_VALUE := Nest.QUEEN_VALUE
const CHAMBER_VISIBLE := 12
## Parte de cada formigueiro que anda pelas trilhas (o resto mora nas câmaras).
const FORAGER_SHARE := 0.45
const ROYAL_WEIGHT := 1.7
## Câmaras no meio do campo são menores.
const SATELLITE_WEIGHT := 0.6

var swarm
var world
var max_alive := 300
var wave_number := 0
var wave_timer := 22.0
var final_released := false
var active := false

var _trail_timers := PackedFloat32Array()
var _wave := {}
var _clean_announced := {}
var _refill_timer := 0.0


func setup(w, sw) -> void:
	world = w
	swarm = sw
	swarm.ant_entered_nest.connect(_on_ant_entered_nest)
	_trail_timers.resize(world.trails.trails.size())
	for i in _trail_timers.size():
		_trail_timers[i] = randf_range(0.0, 1.5)
	_distribute()


## Reparte as formigas da colônia entre os formigueiros, as trilhas e as câmaras.
func _distribute() -> void:
	var nests: Array = world.nests
	var queens := 0
	var total_w := 0.0
	for n in nests:
		if n.big:
			queens += 1
		total_w += 1.75 if n.big else 1.0
	var workers: int = GameState.GOAL - queens * QUEEN_VALUE
	var assigned := 0
	for k in nests.size():
		var n = nests[k]
		var share := int(round(workers * (1.75 if n.big else 1.0) / total_w))
		if k == nests.size() - 1:
			share = workers - assigned
		assigned += share
		n.pool = int(round(share * FORAGER_SHARE))
		n.outside = 0
		n.queen_alive = n.big
		n.cleaned = false
		var residents: int = share - n.pool
		var weights := 0.0
		for c in n.chambers:
			weights += _chamber_weight(c)
		var given := 0
		for ci in n.chambers.size():
			var c = n.chambers[ci]
			var r := int(floor(residents * _chamber_weight(c) / weights))
			if ci == n.chambers.size() - 1:
				r = residents - given
			c.residents = r
			c.shown = 0
			c.opened = false
			given += r


## Peso de cada câmara na hora de repartir as moradoras.
func _chamber_weight(c) -> float:
	if c.royal:
		return ROYAL_WEIGHT
	if c.satellite:
		return SATELLITE_WEIGHT
	return 1.0


func total_remaining() -> int:
	var n := 0
	for nest in world.nests:
		n += nest.remaining()
	return n


func remaining() -> int:
	return total_remaining()


func pools_total() -> int:
	var n := 0
	for nest in world.nests:
		n += nest.pool
	return n


func outside_total() -> int:
	var n := 0
	for nest in world.nests:
		n += nest.outside
	return n


func nests_cleaned() -> int:
	var n := 0
	for nest in world.nests:
		if nest.cleaned:
			n += 1
	return n


func closed_chambers_total() -> int:
	var n := 0
	for nest in world.nests:
		n += nest.closed_chambers()
	return n


## Espalha forrageiras pelas trilhas para o mundo já começar vivo.
func populate(count: int) -> void:
	var trails: Array = world.trails.trails
	for _k in count:
		var ti := randi() % trails.size()
		var t = trails[ti]
		var nest = world.nests[t.nest]
		if nest.pool <= 0:
			continue
		var going := randf() < 0.5
		if swarm.spawn(_roll_kind(0.01), ti, randf() * t.length, 1.0 if going else -1.0,
				randf_range(-0.22, 0.22), not going) >= 0:
			nest.pool -= 1
			nest.outside += 1


func _roll_kind(tanajura_chance: float) -> int:
	return swarm.TANAJURA if randf() < tanajura_chance else swarm.WORKER


func _on_ant_entered_nest(nest_index: int) -> void:
	var nest = world.nests[nest_index]
	nest.outside -= 1
	nest.pool += 1


## Chamado logo antes de uma formiga ser engolida. Retorna quanto ela vale.
func ant_eaten(i: int) -> int:
	var code: int = swarm.home[i]
	if code < 0:
		var nest = world.nests[world.trails.trails[swarm.trail_id[i]].nest]
		nest.outside -= 1
		_check_cleaned(nest)
		return 1
	var nest = world.nests[code / 16]
	var ci := code % 16
	var value := 1
	if swarm.kind[i] == swarm.QUEEN:
		nest.queen_alive = false
		value = QUEEN_VALUE
		queen_eaten.emit(nest)
	else:
		var c = nest.chambers[ci]
		c.residents -= 1
		c.shown = maxi(c.shown - 1, 0)
		_refill(nest, ci, true)
	_check_chamber(nest, ci)
	_check_cleaned(nest)
	return value


func is_queen_protected(code: int) -> bool:
	if code < 0:
		return false
	var nest = world.nests[code / 16]
	return nest.chambers[code % 16].residents > 0


func _check_chamber(nest, ci: int) -> void:
	var key: int = nest.index * 16 + ci
	if _clean_announced.has(key):
		return
	var c = nest.chambers[ci]
	if c.opened and c.residents == 0 and not (c.royal and nest.queen_alive):
		_clean_announced[key] = true
		chamber_cleaned.emit(nest, ci)


func _check_cleaned(nest) -> void:
	if not nest.cleaned and nest.remaining() == 0:
		nest.set_cleaned()
		nest_cleaned.emit(nest)


## Abre uma câmara: as moradoras (e a rainha) aparecem dentro do buraco.
## `stun` > 0 deixa as moradoras tontas (Garras Fortes). Retorna quantas
## moram lá (à vista ou ainda no túnel).
func open_chamber(nest, ci: int, instant: bool = false, stun: float = 0.0) -> int:
	var c = nest.chambers[ci]
	if c.opened and not instant:
		return 0
	nest.open_chamber(ci, instant)
	var code: int = nest.index * 16 + ci
	c.shown = 0
	_refill(nest, ci, false)
	if c.royal and nest.queen_alive:
		swarm.spawn_resident(swarm.QUEEN, code, c.pos2, c.radius)
	if stun > 0.0:
		swarm.stun_home(code, stun)
	elif not instant:
		# Sem Garras Fortes, as moradoras saem correndo para longe.
		swarm.scatter_home(code)
	if not instant:
		chamber_opened.emit(nest, ci)
		_check_chamber(nest, ci)
		_check_cleaned(nest)
	return c.residents


## Põe moradoras à vista até CHAMBER_VISIBLE (as novas saem do túnel, no centro).
func _refill(nest, ci: int, from_tunnel: bool) -> void:
	var c = nest.chambers[ci]
	if not c.opened:
		return
	var want: int = mini(c.residents, CHAMBER_VISIBLE)
	var code: int = nest.index * 16 + ci
	while c.shown < want:
		if swarm.spawn_resident(swarm.WORKER, code, c.pos2, c.radius, from_tunnel) < 0:
			break
		c.shown += 1


func _process(delta: float) -> void:
	if not active:
		return
	# Câmaras abertas que ainda têm moradoras no túnel (ex.: o enxame estava cheio).
	_refill_timer -= delta
	if _refill_timer <= 0.0:
		_refill_timer = 1.0
		for nest in world.nests:
			for ci in nest.chambers.size():
				var c = nest.chambers[ci]
				if c.opened and c.shown < mini(c.residents, CHAMBER_VISIBLE):
					_refill(nest, ci, true)
	var trails: Array = world.trails.trails
	var outside := outside_total()
	# Fluxo contínuo nas trilhas.
	for ti in _trail_timers.size():
		_trail_timers[ti] -= delta
		if _trail_timers[ti] > 0.0:
			continue
		_trail_timers[ti] = randf_range(0.9, 1.9)
		var nest = world.nests[trails[ti].nest]
		if nest.pool <= 0 or outside >= max_alive:
			continue
		if swarm.spawn(_roll_kind(0.008), ti, 0.0, 1.0, randf_range(-0.2, 0.2)) >= 0:
			nest.pool -= 1
			nest.outside += 1
			outside += 1
	# Ondas.
	if not _wave.is_empty():
		var nest = world.nests[_wave.nest]
		_wave.timer -= delta
		while _wave.timer <= 0.0 and _wave.left > 0 and nest.pool > 0:
			_wave.timer += _wave.interval
			var ti: int = _wave.trails[randi() % _wave.trails.size()]
			var k: int = swarm.WORKER
			if _wave.tanajuras > 0 and randf() < 0.08:
				k = swarm.TANAJURA
				_wave.tanajuras -= 1
			if swarm.spawn(k, ti, 0.0, 1.0, randf_range(-0.38, 0.38)) >= 0:
				nest.pool -= 1
				nest.outside += 1
				_wave.left -= 1
			else:
				break
		if _wave.left <= 0 or nest.pool <= 0:
			_wave = {}
	wave_timer -= delta
	if wave_timer <= 0.0 and _wave.is_empty():
		_start_wave()
	# Reta final das trilhas: todas as forrageiras saem e ninguém volta para casa.
	if not final_released and pools_total() + outside <= 60 and pools_total() > 0:
		_release_all()
		final_wave.emit(pools_total() + outside_total())


func _release_all() -> void:
	final_released = true
	swarm.stay_outside = true
	var trails: Array = world.trails.trails
	for nest in world.nests:
		while nest.pool > 0:
			var ti: int = nest.trail_ids[randi() % nest.trail_ids.size()]
			var t = trails[ti]
			if swarm.spawn(_roll_kind(0.0), ti, randf() * t.length * 0.5, 1.0, randf_range(-0.3, 0.3)) < 0:
				break
			nest.pool -= 1
			nest.outside += 1


func _start_wave() -> void:
	wave_timer = randf_range(34.0, 44.0)
	var candidates: Array = []
	for n in world.nests:
		if n.pool >= 8:
			candidates.append(n)
	if candidates.is_empty():
		return
	wave_number += 1
	var nest = candidates[randi() % candidates.size()]
	var count := mini(nest.pool, 24 + wave_number * 10)
	_wave = {
		"nest": nest.index,
		"left": count,
		"interval": clampf(5.0 / count, 0.04, 0.14),
		"timer": 2.5,
		"trails": nest.trail_ids.duplicate(),
		"tanajuras": 1 + wave_number / 3,
	}
	wave_announced.emit(wave_number, nest.display_name, count, nest.index)


# ------------------------------------------------------------------ Salvar

func to_save() -> Dictionary:
	var nests := []
	for n in world.nests:
		var ch := []
		for c in n.chambers:
			ch.append({"residents": c.residents, "opened": c.opened})
		nests.append({"pool": n.pool + n.outside, "queen": n.queen_alive, "chambers": ch})
	return {"nests": nests, "wave_number": wave_number, "wave_timer": wave_timer,
		"final_released": final_released}


func from_save(d: Dictionary) -> void:
	swarm.clear_all()
	_wave = {}
	_clean_announced.clear()
	var saved: Array = d.get("nests", [])
	for k in mini(saved.size(), world.nests.size()):
		var n = world.nests[k]
		var sd: Dictionary = saved[k]
		n.pool = int(sd.get("pool", 0))
		n.outside = 0
		n.queen_alive = bool(sd.get("queen", false)) and n.big
		for c in n.chambers:
			c.shown = 0
			c.opened = false
		var ch: Array = sd.get("chambers", [])
		for ci in mini(ch.size(), n.chambers.size()):
			n.chambers[ci].residents = int(ch[ci].get("residents", 0))
			if bool(ch[ci].get("opened", false)):
				open_chamber(n, ci, true)
				var c = n.chambers[ci]
				if c.residents == 0 and not (c.royal and n.queen_alive):
					_clean_announced[k * 16 + ci] = true
		if n.remaining() == 0:
			n.set_cleaned(true)
	wave_number = int(d.get("wave_number", 0))
	wave_timer = float(d.get("wave_timer", 22.0))
	final_released = false
	if bool(d.get("final_released", false)):
		_release_all()
	else:
		populate(220)
