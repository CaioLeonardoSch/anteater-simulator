extends Node
## A colônia da fase: exatamente 1000 formigas. Elas saem dos formigueiros em
## fluxo contínuo pelas trilhas e em ondas cada vez maiores. Quem volta para o
## formigueiro sai de novo depois; só as que você come somem de vez.

signal wave_announced(wave: int, nest_name: String, count: int, nest_index: int)
signal final_wave(remaining: int)

const TOTAL := 1000

var swarm
var world
var in_nest := TOTAL
var max_alive := 300
var wave_number := 0
var wave_timer := 22.0
var final_released := false
var active := false

var _trail_timers := PackedFloat32Array()
var _wave := {}


func setup(w, sw) -> void:
	world = w
	swarm = sw
	swarm.ant_entered_nest.connect(_on_ant_entered_nest)
	_trail_timers.resize(world.trails.trails.size())
	for i in _trail_timers.size():
		_trail_timers[i] = randf_range(0.0, 1.5)


## Espalha formigas pelas trilhas para o mundo já começar vivo.
func populate(count: int) -> void:
	var trails: Array = world.trails.trails
	for _k in count:
		if in_nest <= 0:
			return
		var ti := randi() % trails.size()
		var t = trails[ti]
		var going := randf() < 0.5
		var i: int = swarm.spawn(_roll_kind(0.08, 0.01), ti, randf() * t.length, 1.0 if going else -1.0,
			randf_range(-0.22, 0.22), not going)
		if i >= 0:
			in_nest -= 1


func remaining() -> int:
	return in_nest + swarm.alive_count


func _roll_kind(soldier_chance: float, tanajura_chance: float) -> int:
	var r := randf()
	if r < tanajura_chance:
		return swarm.TANAJURA
	if r < tanajura_chance + soldier_chance:
		return swarm.SOLDIER
	return swarm.WORKER


func _on_ant_entered_nest(_nest_index: int) -> void:
	in_nest += 1


func _process(delta: float) -> void:
	if not active:
		return
	var trails: Array = world.trails.trails
	# Fluxo contínuo nas trilhas.
	for ti in _trail_timers.size():
		_trail_timers[ti] -= delta
		if _trail_timers[ti] > 0.0:
			continue
		_trail_timers[ti] = randf_range(0.9, 1.9)
		if in_nest <= 0 or swarm.alive_count >= max_alive:
			continue
		if swarm.spawn(_roll_kind(0.08, 0.008), ti, 0.0, 1.0, randf_range(-0.2, 0.2)) >= 0:
			in_nest -= 1
	# Ondas.
	if not _wave.is_empty():
		_wave.timer -= delta
		while _wave.timer <= 0.0 and _wave.left > 0 and in_nest > 0:
			_wave.timer += _wave.interval
			var ti: int = _wave.trails[randi() % _wave.trails.size()]
			var k := _roll_kind(0.12, 0.0)
			if _wave.tanajuras > 0 and randf() < 0.08:
				k = swarm.TANAJURA
				_wave.tanajuras -= 1
			if swarm.spawn(k, ti, 0.0, 1.0, randf_range(-0.38, 0.38)) >= 0:
				in_nest -= 1
				_wave.left -= 1
			else:
				break
		if _wave.left <= 0 or in_nest <= 0:
			_wave = {}
	wave_timer -= delta
	if wave_timer <= 0.0 and _wave.is_empty() and in_nest > 0:
		_start_wave()
	# Reta final: libera todo mundo e ninguém mais volta para casa.
	if not final_released and remaining() <= 90:
		final_released = true
		swarm.stay_outside = true
		var left := in_nest
		_start_wave(left)
		final_wave.emit(remaining())


func _start_wave(forced_count: int = -1) -> void:
	wave_number += 1
	wave_timer = randf_range(34.0, 44.0)
	var nest = world.nests[randi() % world.nests.size()]
	var count := mini(in_nest, 26 + wave_number * 13) if forced_count < 0 else forced_count
	count = mini(count, in_nest)
	if count <= 0:
		return
	_wave = {
		"left": count,
		"interval": clampf(5.0 / count, 0.03, 0.12),
		"timer": 2.5,
		"trails": nest.trail_ids.duplicate(),
		"tanajuras": 1 + wave_number / 3,
	}
	wave_announced.emit(wave_number, nest.display_name, count, nest.index)


## Escavação: solta várias formigas de uma vez de um formigueiro.
func burst(nest, count: int) -> int:
	var released := 0
	for _k in count:
		if in_nest <= 0:
			break
		var ti: int = nest.trail_ids[randi() % nest.trail_ids.size()]
		if swarm.spawn_burst(_roll_kind(0.1, 0.02), nest, ti) >= 0:
			in_nest -= 1
			released += 1
	return released
