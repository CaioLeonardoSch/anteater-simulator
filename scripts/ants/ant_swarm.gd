extends Node3D
## Enxame de formigas: simulação leve em arrays + desenho com MultiMesh.
## Modos: seguindo a trilha, fugindo, voltando para a trilha, tonta,
## grudada na língua, saindo em disparada de um formigueiro escavado.

signal ant_entered_nest(nest_index: int)

const AntMeshBuilder := preload("res://scripts/ants/ant_mesh_builder.gd")
const SCENT_SHADER := preload("res://shaders/ant_scent.gdshader")

const CAPACITY := 720
const NEAR_LOD_DIST := 15.0
const DRAW_DIST := 75.0
const STRIDE := 20

enum Mode { TRAIL, FLEE, RETURN, STUNNED, STUCK, BURST }
const WORKER := 0
const SOLDIER := 1
const TANAJURA := 2
const SIZE := [0.15, 0.2, 0.22]
const SPEED := [0.7, 0.55, 0.95]
const PANIC_SPEED := [1.8, 1.35, 2.2]

var world
var trails: Array = []
var obstacles: Array[Vector3] = []

var alive := PackedByteArray()
var kind := PackedByteArray()
var mode := PackedByteArray()
var carry := PackedByteArray()
var hp := PackedByteArray()
var trail_id := PackedInt32Array()
var s := PackedFloat32Array()
var dir := PackedFloat32Array()
var lateral := PackedFloat32Array()
var speed := PackedFloat32Array()
var yaw := PackedFloat32Array()
var gait := PackedFloat32Array()
var timer := PackedFloat32Array()
var highlight := PackedFloat32Array()
var rnd := PackedFloat32Array()
## Escala extra (formigas encolhem ao entrar na boca).
var shrink := PackedFloat32Array()
var pos := PackedVector3Array()
var vel := PackedVector2Array()
var _free := PackedInt32Array()
var alive_count := 0
## Quando true, as formigas não entram mais nos formigueiros (reta final).
var stay_outside := false

## Posição do tamanduá (focinho) e raio de fuga, atualizados pelo jogador.
var threat_pos := Vector3(9999, 0, 9999)
var flee_radius := 2.0
## Para onde as formigas tontas são puxadas (Terremoto).
var pull_target := Vector3.INF

var _mm: Array[MultiMesh] = []
var _mmi: Array[MultiMeshInstance3D] = []
var _buf: Array[PackedFloat32Array] = []
var _counts := PackedInt32Array([0, 0, 0, 0])
var _scent_mat: ShaderMaterial
var _time := 0.0
var cam_pos := Vector3.ZERO


func setup(w) -> void:
	world = w
	trails = w.trails.trails
	obstacles = w.vegetation.obstacles
	for arr in [alive, kind, mode, carry, hp]:
		arr.resize(CAPACITY)
		arr.fill(0)
	for arr in [s, dir, lateral, speed, yaw, gait, timer, highlight, rnd, shrink]:
		arr.resize(CAPACITY)
		arr.fill(0.0)
	trail_id.resize(CAPACITY)
	pos.resize(CAPACITY)
	vel.resize(CAPACITY)
	_free.resize(CAPACITY)
	for i in CAPACITY:
		_free[i] = CAPACITY - 1 - i
	_scent_mat = ShaderMaterial.new()
	_scent_mat.shader = SCENT_SHADER
	# 0 operária perto, 1 operária longe, 2 soldado, 3 tanajura
	var meshes: Array[Mesh] = [
		AntMeshBuilder.build("worker", 0), AntMeshBuilder.build("worker", 1),
		AntMeshBuilder.build("soldier", 0), AntMeshBuilder.build("tanajura", 0)]
	var caps := [CAPACITY, CAPACITY, 220, 60]
	for k in 4:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = meshes[k]
		mm.instance_count = caps[k]
		mm.visible_instance_count = 0
		mm.custom_aabb = AABB(Vector3(-90, -20, -90), Vector3(180, 60, 180))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = ["WorkersNear", "WorkersFar", "Soldiers", "Tanajuras"][k]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if k != 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		var buf := PackedFloat32Array()
		buf.resize(caps[k] * STRIDE)
		_mm.append(mm)
		_mmi.append(mmi)
		_buf.append(buf)


func spawn(ant_kind: int, trail_index: int, at_s: float, direction: float, lat: float = 0.0, carrying: bool = false) -> int:
	if _free.is_empty():
		return -1
	var i := _free[_free.size() - 1]
	_free.resize(_free.size() - 1)
	alive[i] = 1
	alive_count += 1
	kind[i] = ant_kind
	mode[i] = Mode.TRAIL
	carry[i] = 1 if carrying else 0
	hp[i] = 2 if ant_kind == SOLDIER else 1
	trail_id[i] = trail_index
	s[i] = at_s
	dir[i] = direction
	lateral[i] = lat
	rnd[i] = randf()
	speed[i] = SPEED[ant_kind] * randf_range(0.85, 1.15)
	gait[i] = randf() * TAU
	timer[i] = 0.0
	highlight[i] = 0.0
	shrink[i] = 1.0
	var t = trails[trail_index]
	var p2: Vector2 = t.point_at(at_s) + t.side_at(at_s) * lat
	pos[i] = Vector3(p2.x, world.ground_height(p2.x, p2.y), p2.y)
	vel[i] = Vector2.ZERO
	return i


## Formigas saindo em disparada de um formigueiro escavado.
func spawn_burst(ant_kind: int, nest, trail_index: int) -> int:
	var i := spawn(ant_kind, trail_index, 0.0, 1.0, randf_range(-0.2, 0.2))
	if i < 0:
		return -1
	var a := randf() * TAU
	var p2: Vector2 = nest.center2 + Vector2(cos(a), sin(a)) * randf_range(0.0, 0.4)
	pos[i] = Vector3(p2.x, world.ground_height(p2.x, p2.y), p2.y)
	vel[i] = Vector2(cos(a), sin(a)) * randf_range(1.0, 2.2)
	mode[i] = Mode.BURST
	timer[i] = randf_range(1.2, 2.6)
	return i


func despawn(i: int) -> void:
	if alive[i] == 0:
		return
	alive[i] = 0
	alive_count -= 1
	_free.append(i)


func _physics_process(delta: float) -> void:
	if world == null:
		return
	_time += delta
	var tp2 := Vector2(threat_pos.x, threat_pos.z)
	var flee_r2 := flee_radius * flee_radius
	for i in CAPACITY:
		if alive[i] == 0:
			continue
		var m := mode[i]
		var k := kind[i]
		if highlight[i] > 0.0:
			highlight[i] = maxf(highlight[i] - delta, 0.0)
		if m == Mode.TRAIL or m == Mode.RETURN:
			var d2 := Vector2(pos[i].x, pos[i].z).distance_squared_to(tp2)
			if d2 < flee_r2 * (1.25 if k == SOLDIER else 1.0):
				_start_flee(i, tp2)
				m = Mode.FLEE
		match m:
			Mode.TRAIL:
				_update_trail(i, delta)
			Mode.FLEE, Mode.BURST:
				_update_free(i, delta)
			Mode.RETURN:
				_update_return(i, delta)
			Mode.STUNNED:
				_update_stunned(i, delta)
			_:
				pass


func _start_flee(i: int, from: Vector2) -> void:
	var p2 := Vector2(pos[i].x, pos[i].z)
	var away := (p2 - from)
	if away.length_squared() < 0.0001:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	away = away.normalized().rotated(randf_range(-0.7, 0.7))
	mode[i] = Mode.FLEE
	vel[i] = away * PANIC_SPEED[kind[i]] * randf_range(0.85, 1.15)
	timer[i] = randf_range(1.6, 2.8)


func _update_trail(i: int, delta: float) -> void:
	var t = trails[trail_id[i]]
	var sp := speed[i]
	var ns := s[i] + sp * dir[i] * delta
	if dir[i] > 0.0 and ns >= t.length:
		ns = t.length
		dir[i] = -1.0
		carry[i] = 1 if kind[i] == WORKER else 0
	elif dir[i] < 0.0 and ns <= 0.0:
		if stay_outside:
			ns = 0.0
			dir[i] = 1.0
		else:
			var nest_index: int = t.nest
			despawn(i)
			ant_entered_nest.emit(nest_index)
			return
	s[i] = ns
	var lat := lateral[i] + sin(_time * 1.3 + rnd[i] * 40.0) * 0.03
	var p2: Vector2 = t.point_at(ns) + t.side_at(ns) * lat
	var fwd: Vector2 = t.dir_at(ns) * dir[i]
	var y: float = world.ground_height(p2.x, p2.y)
	if kind[i] == TANAJURA:
		y += 0.35 + sin(_time * 2.2 + rnd[i] * 9.0) * 0.12
	pos[i] = Vector3(p2.x, y, p2.y)
	yaw[i] = lerp_angle(yaw[i], atan2(-fwd.x, -fwd.y), minf(delta * 10.0, 1.0))
	gait[i] += sp * delta / (SIZE[kind[i]] * 0.32) * 1.0


func _update_free(i: int, delta: float) -> void:
	var v := vel[i]
	v = v.rotated(randf_range(-2.0, 2.0) * delta)
	var p2 := Vector2(pos[i].x, pos[i].z) + v * delta
	# Desvia de pedras, troncos e cupinzeiros.
	for o in obstacles:
		var dx := p2.x - o.x
		var dz := p2.y - o.y
		var rr := o.z + 0.1
		var dd := dx * dx + dz * dz
		if dd < rr * rr and dd > 0.000001:
			var d := sqrt(dd)
			p2 = Vector2(o.x, o.y) + Vector2(dx, dz) / d * rr
			v = v.slide(Vector2(dx, dz) / d)
	if p2.length() > 62.0:
		p2 = p2.normalized() * 62.0
		v = -v
	vel[i] = v
	var y: float = world.ground_height(p2.x, p2.y)
	if kind[i] == TANAJURA:
		y += 0.45 + sin(_time * 3.0 + rnd[i] * 9.0) * 0.15
	pos[i] = Vector3(p2.x, y, p2.y)
	if v.length_squared() > 0.0001:
		yaw[i] = lerp_angle(yaw[i], atan2(-v.x, -v.y), minf(delta * 12.0, 1.0))
	gait[i] += v.length() * delta / (SIZE[kind[i]] * 0.32)
	timer[i] -= delta
	if timer[i] <= 0.0:
		mode[i] = Mode.RETURN
		var t = trails[trail_id[i]]
		s[i] = t.closest_s(p2, s[i], 30.0)


func _update_return(i: int, delta: float) -> void:
	var t = trails[trail_id[i]]
	var target: Vector2 = t.point_at(s[i]) + t.side_at(s[i]) * lateral[i]
	var p2 := Vector2(pos[i].x, pos[i].z)
	var to := target - p2
	var dist := to.length()
	var step := speed[i] * 1.8 * delta
	if dist <= step + 0.02:
		mode[i] = Mode.TRAIL
		return
	var v := to / dist * speed[i] * 1.8
	p2 += v * delta
	var y: float = world.ground_height(p2.x, p2.y)
	if kind[i] == TANAJURA:
		y += 0.4
	pos[i] = Vector3(p2.x, y, p2.y)
	yaw[i] = lerp_angle(yaw[i], atan2(-v.x, -v.y), minf(delta * 10.0, 1.0))
	gait[i] += v.length() * delta / (SIZE[kind[i]] * 0.32)
	# Vai avançando o ponto-alvo para não voltar para trás.
	s[i] = clampf(s[i] + speed[i] * dir[i] * delta * 0.5, 0.0, t.length)


func _update_stunned(i: int, delta: float) -> void:
	timer[i] -= delta
	if pull_target != Vector3.INF:
		var p := pos[i]
		var to := pull_target - p
		to.y = 0.0
		var d := to.length()
		if d > 0.35:
			var p2 := Vector2(p.x, p.z) + Vector2(to.x, to.z) / d * minf(2.6 * delta, d)
			pos[i] = Vector3(p2.x, world.ground_height(p2.x, p2.y), p2.y)
	if timer[i] <= 0.0:
		mode[i] = Mode.RETURN
		var t = trails[trail_id[i]]
		s[i] = t.closest_s(Vector2(pos[i].x, pos[i].z), s[i], 30.0)


## Deixa tontas (de barriga para cima) as formigas num raio.
func stun_radius(center: Vector3, radius: float, duration: float) -> int:
	var n := 0
	var r2 := radius * radius
	for i in CAPACITY:
		if alive[i] == 0 or mode[i] == Mode.STUCK:
			continue
		var dx := pos[i].x - center.x
		var dz := pos[i].z - center.z
		if dx * dx + dz * dz <= r2:
			mode[i] = Mode.STUNNED
			timer[i] = duration * randf_range(0.9, 1.15)
			if kind[i] == TANAJURA:
				pos[i].y = world.ground_height(pos[i].x, pos[i].z)
			n += 1
	return n


## Lambida: retorna as formigas grudadas na língua (índices) e quantas
## ficaram só tontas (soldados resistem à primeira lambida).
func lick(tip: Vector3, radius: float, mouth: Vector3, sweep: bool) -> Dictionary:
	var captured := PackedInt32Array()
	var knocked := 0
	var r2 := radius * radius
	var seg := tip - mouth
	var seg_len2 := maxf(seg.length_squared(), 0.0001)
	for i in CAPACITY:
		if alive[i] == 0 or mode[i] == Mode.STUCK:
			continue
		var p := pos[i] + Vector3(0, SIZE[kind[i]] * 0.25, 0)
		var d2 := p.distance_squared_to(tip)
		if sweep and d2 > r2:
			var t := clampf((p - mouth).dot(seg) / seg_len2, 0.0, 1.0)
			d2 = p.distance_squared_to(mouth + seg * t) * 1.6
		if d2 > r2:
			continue
		if kind[i] == SOLDIER and hp[i] > 1 and mode[i] != Mode.STUNNED:
			hp[i] -= 1
			mode[i] = Mode.STUNNED
			timer[i] = 2.0
			knocked += 1
			continue
		mode[i] = Mode.STUCK
		captured.append(i)
	return {"captured": captured, "knocked": knocked}


## Formiga mais próxima da mira (ajuda de mira), ou -1.
func best_target(origin: Vector3, aim_dir: Vector3, max_dist: float, max_angle_cos: float) -> int:
	var best := -1
	var best_score := -INF
	for i in CAPACITY:
		if alive[i] == 0 or mode[i] == Mode.STUCK:
			continue
		var to := pos[i] - origin
		var d := to.length()
		if d > max_dist or d < 0.05:
			continue
		var c := to.dot(aim_dir) / d
		if c < max_angle_cos:
			continue
		var score := c * 4.0 - d * 0.08
		if score > best_score:
			best_score = score
			best = i
	return best


## Destaca (faro) as formigas num raio por alguns segundos.
func sniff(center: Vector3, radius: float, duration: float) -> int:
	var n := 0
	var r2 := radius * radius
	for i in CAPACITY:
		if alive[i] == 0:
			continue
		var dx := pos[i].x - center.x
		var dz := pos[i].z - center.z
		if dx * dx + dz * dz <= r2:
			highlight[i] = duration
			n += 1
	return n


func set_scent_overlay(enabled: bool) -> void:
	for mmi in _mmi:
		mmi.material_overlay = _scent_mat if enabled else null


## Centro aproximado do maior grupo de formigas (para a bússola do faro).
func densest_point(around: Vector3, max_dist: float) -> Vector3:
	var cell := 6.0
	var counts := {}
	var best_key := Vector2i.ZERO
	var best_n := 0
	for i in CAPACITY:
		if alive[i] == 0:
			continue
		if pos[i].distance_squared_to(around) > max_dist * max_dist:
			continue
		var key := Vector2i(floori(pos[i].x / cell), floori(pos[i].z / cell))
		var n: int = counts.get(key, 0) + 1
		counts[key] = n
		if n > best_n:
			best_n = n
			best_key = key
	if best_n == 0:
		return Vector3.INF
	return Vector3((best_key.x + 0.5) * cell, 0.0, (best_key.y + 0.5) * cell)


func _process(_delta: float) -> void:
	if _mm.is_empty():
		return
	_counts.fill(0)
	var cam := cam_pos
	var near2 := NEAR_LOD_DIST * NEAR_LOD_DIST
	var far2 := DRAW_DIST * DRAW_DIST
	for i in CAPACITY:
		if alive[i] == 0:
			continue
		var p := pos[i]
		var d2 := p.distance_squared_to(cam)
		if d2 > far2:
			continue
		var k := kind[i]
		var layer := 2 if k == SOLDIER else (3 if k == TANAJURA else (0 if d2 < near2 else 1))
		var slot := _counts[layer]
		if slot * STRIDE >= _buf[layer].size():
			continue
		_counts[layer] = slot + 1
		var size: float = SIZE[k] * (0.92 + rnd[i] * 0.16) * shrink[i]
		var basis := Basis(Vector3.UP, yaw[i])
		var state := 0.0
		var origin := p
		var m := mode[i]
		if m == Mode.STUNNED:
			state = 1.0
			basis = basis * Basis(Vector3.FORWARD, PI)
			origin.y += size * 0.42
		elif k == TANAJURA:
			state = 2.0
		elif m == Mode.STUCK:
			basis = basis * Basis(Vector3.RIGHT, -1.2)
		basis = basis.scaled(Vector3.ONE * size)
		var tint := 0.88 + rnd[i] * 0.24
		var hl := clampf(highlight[i], 0.0, 1.0)
		var buf := _buf[layer]
		var o := slot * STRIDE
		buf[o] = basis.x.x
		buf[o + 1] = basis.y.x
		buf[o + 2] = basis.z.x
		buf[o + 3] = origin.x
		buf[o + 4] = basis.x.y
		buf[o + 5] = basis.y.y
		buf[o + 6] = basis.z.y
		buf[o + 7] = origin.y
		buf[o + 8] = basis.x.z
		buf[o + 9] = basis.y.z
		buf[o + 10] = basis.z.z
		buf[o + 11] = origin.z
		buf[o + 12] = tint
		buf[o + 13] = tint
		buf[o + 14] = tint
		buf[o + 15] = 1.0
		buf[o + 16] = gait[i]
		buf[o + 17] = hl
		buf[o + 18] = state
		buf[o + 19] = float(carry[i])
	for layer in 4:
		_mm[layer].buffer = _buf[layer]
		_mm[layer].visible_instance_count = _counts[layer]
