extends Node3D
## Enxame de formigas: simulação leve em arrays + desenho com MultiMesh.
## Cada operária da simulação é um grupo de SQUAD formigas (vale 1 ponto): o
## shader desenha as 10, em fila na trilha, num bando solto quando fogem e num
## bolo apertado na câmara e na língua. Rainhas e tanajuras andam sozinhas.
## Modos: seguindo a trilha, fugindo, voltando (para a trilha ou para a câmara),
## tonta, grudada na língua e morando numa câmara aberta de um formigueiro.
## As moradoras de uma câmara recém-aberta saem correndo, e todas fogem quando
## o tamanduá chega perto; depois voltam para casa.

signal ant_entered_nest(nest_index: int)

const AntMeshBuilder := preload("res://scripts/ants/ant_mesh_builder.gd")
const SCENT_SHADER := preload("res://shaders/ant_scent.gdshader")

const CAPACITY := 1600
## Distâncias em que os grupos trocam de malha: detalhada (com sombra) até a
## 1ª, depois simples, bem simples e mínima (até DRAW_DIST).
const LOD_DISTS := [6.0, 13.0, 28.0]
const DRAW_DIST := 75.0
## Camadas de desenho (uma MultiMesh cada).
const LAYER_QUEEN := 4
const LAYER_TANAJURA := 5
## Grupos a menos disto acompanham a inclinação do chão.
const TILT_DIST := 30.0
## Formigas em cada grupo de operárias.
const SQUAD := 10
## Formações dos grupos (o shader mistura as vizinhas na troca).
const FORM_LINE := 1.0
const FORM_LOOSE := 2.0
const FORM_TIGHT := 3.0
## Meia fila e raio do bando e do bolo, em unidades da formiga.
const LINE_HALF := 4.6
const LOOSE_RADIUS := 2.9
const TIGHT_RADIUS := 1.6
## Moradoras de câmaras longe do tamanduá: simuladas 1 vez a cada 4 passos
## e não desenhadas muito longe (estão dentro do buraco, nem dá para ver).
const CHAMBER_SIM_LOD_DIST := 20.0
const CHAMBER_DRAW_DIST := 48.0
const STRIDE := 20

enum Mode { TRAIL, FLEE, RETURN, STUNNED, STUCK, CHAMBER }
const WORKER := 0
const QUEEN := 1
const TANAJURA := 2
const SIZE := [0.15, 0.44, 0.22]
const SPEED := [0.7, 0.0, 0.95]
const PANIC_SPEED := [1.8, 0.0, 2.2]
const CHAMBER_SPEED := 0.32

var world
var colony
var trails: Array = []
var obstacles: Array[Vector3] = []

var alive := PackedByteArray()
var kind := PackedByteArray()
var mode := PackedByteArray()
var carry := PackedByteArray()
var trail_id := PackedInt32Array()
## -1 = formiga de trilha; senão ninho * 16 + câmara (moradora de uma câmara).
var home := PackedInt32Array()
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
## Formação do grupo agora (vai mudando aos poucos até a da situação).
var form := PackedFloat32Array()
var pos := PackedVector3Array()
var vel := PackedVector2Array()
## Centro da câmara (x, raio, z) para as moradoras.
var anchor := PackedVector3Array()
var _free := PackedInt32Array()
var alive_count := 0
## Quando true, as formigas de trilha não entram mais nos formigueiros (reta final).
var stay_outside := false

## Posição do tamanduá e raio de fuga, atualizados pelo jogador.
var threat_pos := Vector3(9999, 0, 9999)
var flee_radius := 2.0
## Para onde as formigas tontas são puxadas (Terremoto).
var pull_target := Vector3.INF

var _mm: Array[MultiMesh] = []
var _mmi: Array[MultiMeshInstance3D] = []
var _buf: Array[PackedFloat32Array] = []
var _counts := PackedInt32Array([0, 0, 0, 0, 0, 0])
var _scent_mat: ShaderMaterial
var _time := 0.0
var cam_pos := Vector3.ZERO


func setup(w, col) -> void:
	world = w
	colony = col
	trails = w.trails.trails
	obstacles = w.vegetation.obstacles
	for arr in [alive, kind, mode, carry]:
		arr.resize(CAPACITY)
		arr.fill(0)
	for arr in [s, dir, lateral, speed, yaw, gait, timer, highlight, rnd, shrink, form]:
		arr.resize(CAPACITY)
		arr.fill(0.0)
	trail_id.resize(CAPACITY)
	home.resize(CAPACITY)
	home.fill(-1)
	pos.resize(CAPACITY)
	vel.resize(CAPACITY)
	anchor.resize(CAPACITY)
	_free.resize(CAPACITY)
	for i in CAPACITY:
		_free[i] = CAPACITY - 1 - i
	for t in trails:
		t.bake_heights(w)
	_scent_mat = ShaderMaterial.new()
	_scent_mat.shader = SCENT_SHADER
	# 0..3 grupos de operárias (de perto para longe), 4 rainha, 5 tanajura
	var meshes: Array[Mesh] = []
	for lod in 4:
		meshes.append(AntMeshBuilder.squad(AntMeshBuilder.build("worker", lod), SQUAD))
	meshes.append(AntMeshBuilder.build("queen", 0))
	meshes.append(AntMeshBuilder.build("tanajura", 0))
	var caps := [400, 800, CAPACITY, CAPACITY, 8, 60]
	for k in 6:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = meshes[k]
		mm.instance_count = caps[k]
		mm.visible_instance_count = 0
		mm.custom_aabb = AABB(Vector3(-90, -20, -90), Vector3(180, 60, 180))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = ["Workers0", "Workers1", "Workers2", "Workers3", "Queens", "Tanajuras"][k]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if k in [0, LAYER_QUEEN, LAYER_TANAJURA] \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		var buf := PackedFloat32Array()
		buf.resize(caps[k] * STRIDE)
		_mm.append(mm)
		_mmi.append(mmi)
		_buf.append(buf)


func _take_slot() -> int:
	if _free.is_empty():
		return -1
	var i := _free[_free.size() - 1]
	_free.resize(_free.size() - 1)
	alive[i] = 1
	alive_count += 1
	rnd[i] = randf()
	gait[i] = randf() * TAU
	timer[i] = 0.0
	highlight[i] = 0.0
	shrink[i] = 1.0
	form[i] = FORM_LINE
	carry[i] = 0
	vel[i] = Vector2.ZERO
	home[i] = -1
	return i


## Formiga de trilha (sai do formigueiro e vai até um arbusto).
func spawn(ant_kind: int, trail_index: int, at_s: float, direction: float, lat: float = 0.0, carrying: bool = false) -> int:
	var i := _take_slot()
	if i < 0:
		return -1
	kind[i] = ant_kind
	mode[i] = Mode.TRAIL
	carry[i] = 1 if carrying else 0
	trail_id[i] = trail_index
	s[i] = at_s
	dir[i] = direction
	lateral[i] = lat
	speed[i] = SPEED[ant_kind] * randf_range(0.85, 1.15)
	var t = trails[trail_index]
	var p2: Vector2 = t.point_at(at_s) + t.side_at(at_s) * lat
	pos[i] = Vector3(p2.x, world.ground_height(p2.x, p2.y), p2.y)
	return i


## Moradora de uma câmara aberta (ou a rainha, parada no centro).
## `from_tunnel` = acabou de sair do túnel, no meio da câmara. Numa vala,
## `axis` e `half_len` dão a direção e o meio comprimento dela.
func spawn_resident(ant_kind: int, home_code: int, center: Vector2, radius: float, from_tunnel: bool = false,
		axis: float = 0.0, half_len: float = 0.0) -> int:
	var i := _take_slot()
	if i < 0:
		return -1
	kind[i] = ant_kind
	mode[i] = Mode.CHAMBER
	home[i] = home_code
	anchor[i] = Vector3(center.x, radius, center.y)
	# Moradoras já saem do túnel em bolo (as das trilhas andam em fila).
	form[i] = FORM_TIGHT
	# Moradoras não usam a trilha: dir e lateral guardam a forma da vala.
	dir[i] = axis
	lateral[i] = half_len
	trail_id[i] = 0
	speed[i] = CHAMBER_SPEED * randf_range(0.7, 1.3)
	var p2 := center
	if ant_kind != QUEEN:
		var a := randf() * TAU
		var spread := 0.22 if from_tunnel else 0.9
		p2 += Vector2(cos(a), sin(a)) * radius * sqrt(randf()) * spread
		if half_len > 0.0:
			p2 += Vector2(cos(axis), sin(axis)) * half_len * randf_range(-1.0, 1.0) * (0.35 if from_tunnel else 0.9)
		vel[i] = Vector2(cos(a + (0.3 if from_tunnel else 1.7)), sin(a + (0.3 if from_tunnel else 1.7))) * speed[i]
	pos[i] = Vector3(p2.x, world.ground_height(p2.x, p2.y), p2.y)
	yaw[i] = randf() * TAU
	return i


func despawn(i: int) -> void:
	if alive[i] == 0:
		return
	alive[i] = 0
	alive_count -= 1
	home[i] = -1
	_free.append(i)


func clear_all() -> void:
	for i in CAPACITY:
		if alive[i] == 1:
			despawn(i)
	stay_outside = false


func _physics_process(delta: float) -> void:
	if world == null:
		return
	_time += delta
	var tp2 := Vector2(threat_pos.x, threat_pos.z)
	var flee_r2 := flee_radius * flee_radius
	var lod_r2 := CHAMBER_SIM_LOD_DIST * CHAMBER_SIM_LOD_DIST
	var lod_tick := Engine.get_physics_frames() % 4
	for i in CAPACITY:
		if alive[i] == 0:
			continue
		var m := mode[i]
		if highlight[i] > 0.0:
			highlight[i] = maxf(highlight[i] - delta, 0.0)
		if m == Mode.TRAIL or m == Mode.RETURN or m == Mode.CHAMBER:
			var d2 := Vector2(pos[i].x, pos[i].z).distance_squared_to(tp2)
			if d2 < flee_r2 and kind[i] != QUEEN:
				_start_flee(i, tp2)
				m = Mode.FLEE
			elif m == Mode.CHAMBER:
				if d2 > lod_r2:
					if (i & 3) == lod_tick:
						_update_chamber(i, delta * 4.0, tp2)
				else:
					_update_chamber(i, delta, tp2)
				continue
		match m:
			Mode.TRAIL:
				_update_trail(i, delta)
			Mode.FLEE:
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
	# Moradoras correm mais longe antes de pensar em voltar para a câmara.
	timer[i] = randf_range(2.4, 3.8) if home[i] >= 0 else randf_range(1.6, 2.8)


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
	gait[i] += sp * delta / (SIZE[kind[i]] * 0.32)


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
	var limit: float = world.walk_limit(p2) - 0.3
	if p2.length() > limit:
		p2 = p2.normalized() * limit
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
		if home[i] < 0:
			var t = trails[trail_id[i]]
			s[i] = t.closest_s(p2, s[i], 30.0)


func _update_return(i: int, delta: float) -> void:
	if home[i] >= 0:
		_update_homing(i, delta)
		return
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


## Moradora voltando para a sua câmara depois de fugir.
func _update_homing(i: int, delta: float) -> void:
	var a := anchor[i]
	var center := Vector2(a.x, a.z)
	var p2 := Vector2(pos[i].x, pos[i].z)
	var to := center - p2
	var dist := to.length()
	if dist < a.y * 0.6:
		mode[i] = Mode.CHAMBER
		vel[i] = (to / dist if dist > 0.001 else Vector2.RIGHT) * speed[i]
		return
	var sp := maxf(speed[i] * 2.4, 0.75)
	var v := to / dist * sp
	p2 += v * delta
	pos[i] = Vector3(p2.x, world.ground_height(p2.x, p2.y), p2.y)
	yaw[i] = lerp_angle(yaw[i], atan2(-v.x, -v.y), minf(delta * 10.0, 1.0))
	gait[i] += sp * delta / (SIZE[kind[i]] * 0.32)


## Moradoras andam em círculos dentro da câmara e se afastam do focinho.
func _update_chamber(i: int, delta: float, threat: Vector2) -> void:
	if kind[i] == QUEEN:
		return
	var a := anchor[i]
	var center := Vector2(a.x, a.z)
	var radius := a.y
	var p2 := Vector2(pos[i].x, pos[i].z)
	var v := vel[i].rotated(randf_range(-2.5, 2.5) * delta)
	# O bolo de formigas fica dentro da câmara.
	var limit := maxf(radius * 0.92 - SIZE[WORKER] * TIGHT_RADIUS * 0.8, radius * 0.4)
	var away := p2 - threat
	var dthreat := away.length()
	if dthreat < 1.6 and dthreat > 0.001:
		v = v.lerp(away / dthreat * speed[i] * 2.2, minf(delta * 3.0, 1.0))
	else:
		v = v.normalized() * speed[i] if v.length_squared() > 0.000001 else Vector2.RIGHT.rotated(randf() * TAU) * speed[i]
	p2 += v * delta
	# Na vala, o "centro" é o ponto do eixo dela mais perto da formiga.
	var half := lateral[i]
	if half > 0.0:
		var ax := Vector2(cos(dir[i]), sin(dir[i]))
		center += ax * clampf((p2 - center).dot(ax), -half, half)
	var off := p2 - center
	if off.length() > limit:
		var n := off.normalized()
		p2 = center + n * limit
		v = v.bounce(n) * 0.8
	vel[i] = v
	pos[i] = Vector3(p2.x, world.ground_height(p2.x, p2.y), p2.y)
	if v.length_squared() > 0.0001:
		yaw[i] = lerp_angle(yaw[i], atan2(-v.x, -v.y), minf(delta * 8.0, 1.0))
	gait[i] += v.length() * delta / (SIZE[kind[i]] * 0.32)


func _update_stunned(i: int, delta: float) -> void:
	timer[i] -= delta
	if pull_target != Vector3.INF and kind[i] != QUEEN:
		var p := pos[i]
		var to := pull_target - p
		to.y = 0.0
		var d := to.length()
		if d > 0.35:
			var p2 := Vector2(p.x, p.z) + Vector2(to.x, to.z) / d * minf(2.6 * delta, d)
			pos[i] = Vector3(p2.x, world.ground_height(p2.x, p2.y), p2.y)
	if timer[i] <= 0.0:
		if home[i] >= 0:
			# Longe da câmara (puxada pelo Terremoto ou tonta no meio da fuga): volta andando.
			var off := Vector2(pos[i].x - anchor[i].x, pos[i].z - anchor[i].z)
			if off.length() > anchor[i].y * 0.92:
				mode[i] = Mode.RETURN
			else:
				mode[i] = Mode.CHAMBER
				vel[i] = -off.normalized() * speed[i]
		else:
			mode[i] = Mode.RETURN
			var t = trails[trail_id[i]]
			s[i] = t.closest_s(Vector2(pos[i].x, pos[i].z), s[i], 30.0)


## Câmara recém-aberta: as moradoras saem correndo para longe do tamanduá.
func scatter_home(home_code: int) -> void:
	var tp2 := Vector2(threat_pos.x, threat_pos.z)
	for i in CAPACITY:
		if alive[i] == 0 or home[i] != home_code or kind[i] == QUEEN or mode[i] != Mode.CHAMBER:
			continue
		var a := anchor[i]
		var p2 := Vector2(pos[i].x, pos[i].z)
		var out := p2 - Vector2(a.x, a.z)
		if out.length_squared() < 0.0001:
			out = Vector2.RIGHT.rotated(randf() * TAU)
		var away := p2 - tp2
		if away.length_squared() < 0.0001:
			away = out
		var dir := (out.normalized() + away.normalized() * 0.8).normalized().rotated(randf_range(-0.6, 0.6))
		mode[i] = Mode.FLEE
		vel[i] = dir * PANIC_SPEED[kind[i]] * randf_range(0.8, 1.2)
		timer[i] = randf_range(2.2, 4.0)


## Deixa tontas as moradoras de uma câmara (Garras Fortes, ao abrir).
func stun_home(home_code: int, duration: float) -> int:
	var n := 0
	for i in CAPACITY:
		if alive[i] == 0 or home[i] != home_code or kind[i] == QUEEN or mode[i] == Mode.STUCK:
			continue
		mode[i] = Mode.STUNNED
		timer[i] = duration * randf_range(0.9, 1.15)
		n += 1
	return n


## Deixa tontas (de barriga para cima) as formigas num raio.
func stun_radius(center: Vector3, radius: float, duration: float) -> int:
	var n := 0
	var r2 := radius * radius
	for i in CAPACITY:
		if alive[i] == 0 or mode[i] == Mode.STUCK or kind[i] == QUEEN:
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


## Distância (ao quadrado) de p até a formiga i. Para um grupo, até a fila ou
## o bando dele (a língua pega o grupo inteiro se encostar em qualquer parte).
func _reach2(i: int, p: Vector3) -> float:
	var c := pos[i] + Vector3(0, SIZE[kind[i]] * 0.25, 0)
	if kind[i] != WORKER:
		return c.distance_squared_to(p)
	var unit: float = SIZE[WORKER]
	var f := form[i]
	if f < 1.5:
		var fwd := Vector3(-sin(yaw[i]), 0.0, -cos(yaw[i]))
		var half := LINE_HALF * unit
		var t := clampf((p - c).dot(fwd), -half, half)
		return (c + fwd * t).distance_squared_to(p)
	var r := (LOOSE_RADIUS if f < 2.5 else TIGHT_RADIUS) * unit
	var d := maxf(c.distance_to(p) - r, 0.0)
	return d * d


func _queen_blocked(i: int) -> bool:
	return kind[i] == QUEEN and colony != null and colony.is_queen_protected(home[i])


## Lambida: gruda até `capacity` formigas no raio, as mais perto da ponta
## primeiro. Retorna as grudadas e se bateu numa rainha protegida.
func lick(tip: Vector3, radius: float, capacity: int) -> Dictionary:
	var protected_queen := false
	var r2 := radius * radius
	var near: Array[Vector2] = []
	for i in CAPACITY:
		if alive[i] == 0 or mode[i] == Mode.STUCK:
			continue
		var k := kind[i]
		var reach2 := r2 if k != QUEEN else (radius + 0.25) * (radius + 0.25)
		var d2 := _reach2(i, tip)
		if d2 > reach2:
			continue
		if _queen_blocked(i):
			protected_queen = true
			continue
		near.append(Vector2(d2, i))
	near.sort()
	var captured := PackedInt32Array()
	for k in mini(capacity, near.size()):
		var i := int(near[k].y)
		mode[i] = Mode.STUCK
		captured.append(i)
	return {"captured": captured, "queen_protected": protected_queen}


## Há alguma formiga (que dá para pegar) a menos de `radius` deste ponto?
func any_near(point: Vector3, radius: float) -> bool:
	var r2 := radius * radius
	for i in CAPACITY:
		if alive[i] == 0 or mode[i] == Mode.STUCK or _queen_blocked(i):
			continue
		if _reach2(i, point) <= r2:
			return true
	return false


## Formiga mais próxima da mira (Língua Certeira), ou -1.
func best_target(origin: Vector3, aim_dir: Vector3, max_dist: float, max_angle_cos: float) -> int:
	var best := -1
	var best_score := -INF
	for i in CAPACITY:
		if alive[i] == 0 or mode[i] == Mode.STUCK or _queen_blocked(i):
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


## Faro: sente as `max_ants` formigas mais perto num raio. Com `sharp`
## (Faro Nítido), elas brilham por `duration` segundos. Retorna quantas sentiu,
## se havia mais, a distância da mais perto e onde elas estão.
func sniff(center: Vector3, radius: float, max_ants: int, duration: float, sharp: bool) -> Dictionary:
	var r2 := radius * radius
	var near: Array[Vector2] = []
	for i in CAPACITY:
		if alive[i] == 0 or mode[i] == Mode.STUCK:
			continue
		var dx := pos[i].x - center.x
		var dz := pos[i].z - center.z
		var d2 := dx * dx + dz * dz
		if d2 <= r2:
			near.append(Vector2(d2, i))
	near.sort()
	var n := mini(max_ants, near.size())
	var points := PackedVector3Array()
	for k in n:
		var i := int(near[k].y)
		points.append(pos[i])
		if sharp:
			highlight[i] = duration
	return {"count": n, "capped": near.size() > max_ants,
		"nearest": sqrt(near[0].x) if n > 0 else -1.0, "points": points}


func set_scent_overlay(enabled: bool) -> void:
	for mmi in _mmi:
		mmi.material_overlay = _scent_mat if enabled else null


## Cor do faro (configurável). A rainha continua com o brilho dourado dela.
func set_sniff_color(c: Color) -> void:
	if _scent_mat:
		_scent_mat.set_shader_parameter("tint", c)
	for k in [0, 1, 2, 3, LAYER_TANAJURA]:
		if k < _mmi.size():
			_mmi[k].set_instance_shader_parameter("glow_color", c)


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


## Quantas formigas de trilha estão vivas (fora dos formigueiros).
func trail_count() -> int:
	var n := 0
	for i in CAPACITY:
		if alive[i] == 1 and home[i] < 0:
			n += 1
	return n


## Chão inclinado embaixo do grupo: o "para cima" segue a normal do chão.
func _ground_basis(p: Vector3, a: float) -> Basis:
	var e := 0.25
	var hx: float = world.ground_height(p.x + e, p.z) - world.ground_height(p.x - e, p.z)
	var hz: float = world.ground_height(p.x, p.z + e) - world.ground_height(p.x, p.z - e)
	var up := Vector3(-hx, 2.0 * e, -hz).normalized()
	var fwd := Vector3(-sin(a), 0.0, -cos(a))
	fwd = (fwd - up * fwd.dot(up)).normalized()
	return Basis(fwd.cross(up), up, -fwd)


func _process(delta: float) -> void:
	if _mm.is_empty():
		return
	_counts.fill(0)
	var cam := cam_pos
	var lod0 := float(LOD_DISTS[0]) * LOD_DISTS[0]
	var lod1 := float(LOD_DISTS[1]) * LOD_DISTS[1]
	var lod2 := float(LOD_DISTS[2]) * LOD_DISTS[2]
	var far2 := DRAW_DIST * DRAW_DIST
	var tilt2 := TILT_DIST * TILT_DIST
	var chamber_far2 := CHAMBER_DRAW_DIST * CHAMBER_DRAW_DIST
	var form_step := delta * 2.5
	for i in CAPACITY:
		if alive[i] == 0:
			continue
		var p := pos[i]
		var d2 := p.distance_squared_to(cam)
		if d2 > far2 or (d2 > chamber_far2 and mode[i] == Mode.CHAMBER):
			continue
		var k := kind[i]
		var layer := 0
		if k == QUEEN:
			layer = LAYER_QUEEN
		elif k == TANAJURA:
			layer = LAYER_TANAJURA
		elif d2 >= lod2:
			layer = 3
		elif d2 >= lod1:
			layer = 2
		elif d2 >= lod0:
			layer = 1
		var slot := _counts[layer]
		if slot * STRIDE >= _buf[layer].size():
			continue
		_counts[layer] = slot + 1
		var size: float = SIZE[k] * (0.92 + rnd[i] * 0.16) * shrink[i]
		var basis := Basis(Vector3.UP, yaw[i])
		var state := 0.0
		var origin := p
		var m := mode[i]
		var formation := 0.0
		var clip := 999.0
		if k == WORKER:
			# Fila na trilha, bolo na câmara e na língua, bando solto no resto.
			var want := FORM_LOOSE
			if m == Mode.TRAIL:
				want = FORM_LINE
			elif m == Mode.CHAMBER or m == Mode.STUCK:
				want = FORM_TIGHT
			# Na língua o bolo se fecha depressa.
			form[i] = move_toward(form[i], want, form_step * (3.5 if m == Mode.STUCK else 1.0))
			formation = form[i]
			if d2 < tilt2:
				if m == Mode.TRAIL:
					var t = trails[trail_id[i]]
					basis = basis * Basis(Vector3.RIGHT, atan(t.slope_at(s[i]) * dir[i]))
				elif m != Mode.STUCK:
					basis = _ground_basis(p, yaw[i])
			# Na boca do formigueiro, as do grupo que já entraram (ou ainda não
			# saíram) ficam escondidas.
			if m == Mode.TRAIL and s[i] < 1.2:
				var units := s[i] / size
				clip = units if dir[i] < 0.0 else -units
		if k == QUEEN:
			size *= 1.0 + sin(_time * 2.0 + rnd[i] * 6.0) * 0.03
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
		if k == QUEEN:
			hl = maxf(hl, 0.45 + sin(_time * 3.0) * 0.15)
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
		buf[o + 15] = clip
		buf[o + 16] = gait[i]
		buf[o + 17] = hl
		buf[o + 18] = state + 4.0 * float(int(rnd[i] * 1023.0))
		buf[o + 19] = float(carry[i]) + 2.0 * round(formation * 64.0)
	for layer in _mm.size():
		_mm[layer].buffer = _buf[layer]
		_mm[layer].visible_instance_count = _counts[layer]
