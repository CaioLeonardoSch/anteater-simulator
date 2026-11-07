extends Node
## A colônia do Cerrado: GameState.GOAL formigas ao todo (cada rainha conta
## como QUEEN_VALUE). Cada formigueiro reparte as suas em três partes:
## - forrageiras, que vão e voltam pelas trilhas sem parar;
## - passeadoras, que saem das câmaras do campo, dão uma volta e entram de novo;
## - moradoras, que vivem nas câmaras e só aparecem quando você cava. Numa
##   câmara aberta ficam até CHAMBER_VISIBLE à vista; as outras saem do túnel
##   conforme você come.
## Cada formiga é uma só (sem grupos). Só as que você come somem de vez.

signal chamber_opened(nest, chamber_index: int)
signal chamber_cleaned(nest, chamber_index: int)
signal nest_cleaned(nest)
signal queen_eaten(nest)

const Nest := preload("res://scripts/world/nest.gd")
const AntField := preload("res://scripts/ants/ant_field.gd")
const QUEEN_VALUE := Nest.QUEEN_VALUE
const CHAMBER_VISIBLE := 40
## Parte das formigas de cada formigueiro nas trilhas e passeando pelo campo
## (o resto mora nas câmaras).
const TRAIL_SHARE := 0.2
const ROAM_SHARE := 0.35
## Tanajuras em cada trilha (contam como formigas da trilha).
const TANAJURAS_PER_TRAIL := 2
const ROYAL_WEIGHT := 1.7
## Câmaras no meio do campo guardam menos moradoras.
const SATELLITE_WEIGHT := 0.6
## Até onde as passeadoras vão (m), longe da câmara delas.
const ROAM_REACH := 12.0
const ROAM_REACH_MIN := 2.2

var swarm
var world
var active := false
## Formigas de cada trilha que ainda não foram comidas (as de campo) e as
## tanajuras de cada trilha.
var trail_left := PackedInt32Array()
var tanajuras_left := PackedInt32Array()
var _trail_total := PackedInt32Array()
var _clean_announced := {}
var _refill_timer := 0.0


func setup(w, sw) -> void:
	world = w
	swarm = sw
	_distribute()
	var trail_counts: Array = []
	for ti in trail_left.size():
		trail_counts.append(trail_left[ti])
	var roams: Array = []
	for nest in world.nests:
		for ci in nest.chambers.size():
			var c = nest.chambers[ci]
			if c.roamers > 0:
				roams.append({"code": nest.index * 16 + ci, "home": c.pos2, "reach": c.roam_reach, "count": c.roamers})
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	swarm.field.build(world, trail_counts, roams, rng)
	_spawn_tanajuras()


## Reparte as formigas da colônia entre os formigueiros, as trilhas, os
## passeios e as câmaras.
func _distribute() -> void:
	var nests: Array = world.nests
	var trails: Array = world.trails.trails
	trail_left.resize(trails.size())
	trail_left.fill(0)
	tanajuras_left.resize(trails.size())
	tanajuras_left.fill(0)
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
		n.queen_alive = n.big
		n.cleaned = false
		# Trilhas.
		var on_trails := int(round(share * TRAIL_SHARE)) if not n.trail_ids.is_empty() else 0
		var given := 0
		for j in n.trail_ids.size():
			var ti: int = n.trail_ids[j]
			var m: int = on_trails / n.trail_ids.size()
			if j == n.trail_ids.size() - 1:
				m = on_trails - given
			given += m
			tanajuras_left[ti] = mini(TANAJURAS_PER_TRAIL, m)
			trail_left[ti] = m - tanajuras_left[ti]
		n.pool = on_trails
		# Passeios em volta das câmaras do campo.
		var sats: Array = []
		for c in n.chambers:
			c.roamers = 0
			if c.satellite:
				sats.append(c)
		var roaming := int(round(share * ROAM_SHARE)) if not sats.is_empty() else 0
		given = 0
		for j in sats.size():
			var m: int = roaming / sats.size()
			if j == sats.size() - 1:
				m = roaming - given
			given += m
			sats[j].roamers = m
			sats[j].roam_reach = _roam_reach(sats[j].pos2)
		# Moradoras.
		var residents: int = share - on_trails - roaming
		var weights := 0.0
		for c in n.chambers:
			weights += _chamber_weight(c)
		given = 0
		for ci in n.chambers.size():
			var c = n.chambers[ci]
			var r := int(floor(residents * _chamber_weight(c) / weights))
			if ci == n.chambers.size() - 1:
				r = residents - given
			c.residents = r
			c.shown = 0
			c.opened = false
			given += r
	_trail_total = trail_left.duplicate()


## Até onde as passeadoras de uma câmara do campo andam: sem entrar nas
## lagoas nem passar dos penhascos.
func _roam_reach(p: Vector2) -> float:
	var reach := ROAM_REACH
	for w in world.ponds:
		reach = minf(reach, p.distance_to(Vector2(w.x, w.y)) - w.z - 0.4)
	for k in 16:
		var d := Vector2.RIGHT.rotated(TAU * k / 16.0)
		var q := p + d * reach
		var limit: float = world.walk_limit(q) - 0.6
		if q.length() > limit:
			reach = minf(reach, maxf(limit - p.length(), ROAM_REACH_MIN))
	return maxf(reach, ROAM_REACH_MIN)


## Peso de cada câmara na hora de repartir as moradoras.
func _chamber_weight(c) -> float:
	if c.royal:
		return ROYAL_WEIGHT
	if c.satellite:
		return SATELLITE_WEIGHT
	return 1.0


func _spawn_tanajuras() -> void:
	var trails: Array = world.trails.trails
	for ti in tanajuras_left.size():
		var t = trails[ti]
		for _k in tanajuras_left[ti]:
			swarm.spawn(swarm.TANAJURA, ti, randf_range(0.6, t.length), 1.0 if randf() < 0.5 else -1.0,
				randf_range(-0.2, 0.2))


func total_remaining() -> int:
	var n := 0
	for nest in world.nests:
		n += nest.remaining()
	return n


func remaining() -> int:
	return total_remaining()


## Formigas fora das câmaras fechadas (trilhas e passeios) que ainda não foram comidas.
func loose_total() -> int:
	var n := 0
	for nest in world.nests:
		n += nest.pool + nest.roamers_left()
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


## Chamado logo antes de uma formiga ser engolida. Retorna quanto ela vale.
func ant_eaten(i: int) -> int:
	var code: int = swarm.home[i]
	if code >= 0:
		return _resident_eaten(i, code)
	var ci: int = swarm.origin_chunk[i]
	var nest
	if ci >= 0:
		var ch = swarm.field.chunks[ci]
		if ch.kind == AntField.TRAIL:
			trail_left[ch.index] -= 1
			nest = world.nests[world.trails.trails[ch.index].nest]
			nest.pool -= 1
		else:
			nest = world.nests[ch.index / 16]
			nest.chambers[ch.index % 16].roamers -= 1
	else:
		# Tanajura.
		var ti: int = swarm.trail_id[i]
		tanajuras_left[ti] = maxi(tanajuras_left[ti] - 1, 0)
		nest = world.nests[world.trails.trails[ti].nest]
		nest.pool -= 1
	_check_cleaned(nest)
	return 1


func _resident_eaten(i: int, code: int) -> int:
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
	if c.royal:
		_merge_into_pit(nest, ci)
		if not instant:
			refresh_ground()
	c.shown = 0
	_refill(nest, ci, false)
	if c.royal and nest.queen_alive:
		swarm.spawn_resident(swarm.QUEEN, code, c.pos2, c.area_radius())
	if stun > 0.0:
		swarm.stun_home(code, stun)
	elif not instant:
		# Sem Garras Fortes, as moradoras saem correndo para longe.
		swarm.scatter_home(code)
	# Câmara aberta: as moradoras não voltam para ela, se espalham pela região
	# (no buraco da rainha, a corte fica com ela).
	if not c.royal:
		swarm.disperse_home(code, c.pos2, instant)
	if not instant:
		chamber_opened.emit(nest, ci)
		_check_chamber(nest, ci)
		_check_cleaned(nest)
	return c.residents


## O monte foi desmanchado: as moradoras das outras câmaras dele caem no
## buraco da rainha.
func _merge_into_pit(nest, royal_ci: int) -> void:
	var royal = nest.chambers[royal_ci]
	var code: int = nest.index * 16 + royal_ci
	for ci in nest.chambers.size():
		var c = nest.chambers[ci]
		if ci == royal_ci or c.satellite:
			continue
		royal.residents += c.residents
		royal.shown += swarm.rehome(nest.index * 16 + ci, code, royal.pos2, royal.area_radius())
		c.residents = 0
		c.shown = 0
		_clean_announced[nest.index * 16 + ci] = true


## O chão mudou (um monte virou buraco): as trilhas e as formigas de campo
## passam a seguir o chão novo.
func refresh_ground() -> void:
	for t in world.trails.trails:
		t.bake_heights(world)
	swarm.field.refresh_ground()


## Põe moradoras à vista até CHAMBER_VISIBLE (as novas saem do túnel, no centro).
func _refill(nest, ci: int, from_tunnel: bool) -> void:
	var c = nest.chambers[ci]
	if not c.opened:
		return
	var want: int = mini(c.residents, _visible_cap(c))
	var code: int = nest.index * 16 + ci
	while c.shown < want:
		var i: int = swarm.spawn_resident(swarm.WORKER, code, c.pos2, c.area_radius(), from_tunnel, c.axis, c.half_len)
		if i < 0:
			break
		# As que saem do túnel depois vão direto para um canto da região.
		if from_tunnel and not c.royal:
			swarm.disperse(i, c.pos2)
		c.shown += 1


## Quantas ficam à vista numa câmara (o buraco da rainha é bem maior).
func _visible_cap(c) -> int:
	return CHAMBER_VISIBLE * 3 if c.royal else CHAMBER_VISIBLE


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
				if c.opened and c.shown < mini(c.residents, _visible_cap(c)):
					_refill(nest, ci, true)


# ------------------------------------------------------------------ Salvar

func to_save() -> Dictionary:
	var nests := []
	for n in world.nests:
		var ch := []
		for c in n.chambers:
			ch.append({"residents": c.residents, "roamers": c.roamers, "opened": c.opened})
		nests.append({"queen": n.queen_alive, "chambers": ch})
	return {"nests": nests, "trails": Array(trail_left), "tanajuras": Array(tanajuras_left)}


func from_save(d: Dictionary) -> void:
	swarm.clear_all()
	_clean_announced.clear()
	var field = swarm.field
	# Trilhas: some com as formigas já comidas.
	var saved_trails: Array = d.get("trails", [])
	for ti in mini(saved_trails.size(), trail_left.size()):
		var left := clampi(int(saved_trails[ti]), 0, _trail_total[ti])
		var gone := trail_left[ti] - left
		if gone > 0 and field.trail_chunk.has(ti):
			field.remove_count(field.trail_chunk[ti], gone)
		trail_left[ti] = left
	var saved_taj: Array = d.get("tanajuras", [])
	for ti in mini(saved_taj.size(), tanajuras_left.size()):
		tanajuras_left[ti] = clampi(int(saved_taj[ti]), 0, tanajuras_left[ti])
	var saved: Array = d.get("nests", [])
	for k in mini(saved.size(), world.nests.size()):
		var n = world.nests[k]
		var sd: Dictionary = saved[k]
		n.queen_alive = bool(sd.get("queen", false)) and n.big
		n.pool = 0
		for ti in n.trail_ids:
			n.pool += trail_left[ti] + tanajuras_left[ti]
		for c in n.chambers:
			c.shown = 0
			c.opened = false
		var ch: Array = sd.get("chambers", [])
		# Primeiro as contas de todas as câmaras, depois abre as abertas (o
		# buraco da rainha junta as moradoras das outras câmaras do monte).
		for ci in mini(ch.size(), n.chambers.size()):
			n.chambers[ci].residents = int(ch[ci].get("residents", 0))
		for ci in mini(ch.size(), n.chambers.size()):
			var c = n.chambers[ci]
			var roam_left := clampi(int(ch[ci].get("roamers", c.roamers)), 0, c.roamers)
			var code: int = k * 16 + ci
			if roam_left < c.roamers and field.roam_chunk.has(code):
				field.remove_count(field.roam_chunk[code], c.roamers - roam_left)
			c.roamers = roam_left
			if bool(ch[ci].get("opened", false)):
				open_chamber(n, ci, true)
				if c.residents == 0 and not (c.royal and n.queen_alive):
					_clean_announced[code] = true
		if n.remaining() == 0:
			n.set_cleaned(true)
	refresh_ground()
	_spawn_tanajuras()
