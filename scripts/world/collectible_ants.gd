extends Node3D
## As formigas colecionáveis no mapa (scripts/collectibles.gd): fantasiadas,
## sempre no mesmo lugar, paradas ou andando no lugar, e sem fugir (não são de
## nenhum formigueiro: a língua não pega e elas não contam nos insetos).
## Chegando perto (FIND_DIST) e olhando para uma (FIND_ANGLE), sem nada no
## meio, ela entra na coleção. A Formiga Noel é procurada entre as formigas de
## verdade que estão perto: as que saíram de chapéu de Natal.

const Collectibles := preload("res://scripts/collectibles.gd")
const AntMeshBuilder := preload("res://scripts/ants/ant_mesh_builder.gd")

## Um terço maiores que as operárias (AntField.WORKER_SIZE, 0,15 m): pequenas
## e escondidas, mas com a fantasia dando para ver de perto.
const SIZE := 0.2
## Até onde dá para achar uma (m, da câmera) e quanto fora do meio da tela.
const FIND_DIST := 3.5
const FIND_ANGLE := 30.0
const CHECK_EVERY := 0.2
## Andando: velocidade (m/s), raio da roda e quanto tempo para no fim do
## vai e volta (s).
const WALK_SPEED := 0.12
const CIRCLE_R := 0.32
const PATROL_PAUSE := 1.2

var world
var player
var swarm
var _ants: Array = []
var _check := 0.0
var _time := 0.0
var _near: Array[Vector4] = []


func setup(w, p, sw) -> void:
	world = w
	player = p
	swarm = sw
	var k := 0
	for d in Collectibles.LIST:
		if d.has("spot"):
			_ants.append(_make(d, k))
			k += 1


func _make(d: Dictionary, k: int) -> Dictionary:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = AntMeshBuilder.build("worker", 0, String(d.id))
	mm.instance_count = 1
	mm.set_instance_color(0, Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Colecionavel_" + String(d.id)
	mmi.multimesh = mm
	add_child(mmi)
	var spot: Vector2 = d.spot
	var face := deg_to_rad(float(d.face)) if d.has("face") else atan2(spot.x, spot.y)
	return {"def": d, "mm": mm, "pos": spot, "yaw": face, "face": face, "gait": 0.0,
		"seed": 300.0 + k * 17.0, "t": k * 1.7, "dir": 1.0, "wait": 0.0}


func _process(delta: float) -> void:
	_time += delta
	for a in _ants:
		_move(a, delta)
		var p: Vector2 = a.pos
		var hop := absf(sin(a.t * 6.0)) * 0.012 if a.def.move == "dance" else 0.0
		var origin := Vector3(p.x, world.ground_height(p.x, p.y) + hop, p.y)
		var mm: MultiMesh = a.mm
		mm.set_instance_transform(0, Transform3D(Basis(Vector3.UP, a.yaw).scaled(Vector3.ONE * SIZE), origin))
		# Passo, sem destaque do faro, andando (estado 0) e com a fantasia ligada.
		mm.set_instance_custom_data(0, Color(a.gait, 0.0, 4.0 * float(a.seed), 2.0))


## O jeito de cada uma ficar no lugar.
func _move(a: Dictionary, delta: float) -> void:
	a.t += delta
	var step: float = delta / (SIZE * 0.32)
	match String(a.def.move):
		"look":
			# Parada, virando devagar para um lado e para o outro.
			var yaw: float = a.face + sin(a.t * 0.5) * 0.8
			a.gait += absf(angle_difference(a.yaw, yaw)) * 6.0
			a.yaw = yaw
		"circle":
			var ang: float = a.t * WALK_SPEED / CIRCLE_R
			var spot: Vector2 = a.def.spot
			a.pos = spot + Vector2(cos(ang), sin(ang)) * CIRCLE_R
			a.yaw = atan2(sin(ang), -cos(ang))
			a.gait += WALK_SPEED * step
		"patrol":
			var from: Vector2 = a.def.spot
			var to: Vector2 = a.def.to
			if a.wait > 0.0:
				a.wait -= delta
				# Vira para o outro lado enquanto espera.
				var back: Vector2 = (to - from) * float(a.dir)
				var want := atan2(-back.x, -back.y)
				var turn := clampf(angle_difference(a.yaw, want), -3.0 * delta, 3.0 * delta)
				a.yaw += turn
				a.gait += absf(turn) * 6.0
				return
			var goal: Vector2 = to if a.dir > 0.0 else from
			var pos: Vector2 = a.pos
			var dist := pos.distance_to(goal)
			var mv := minf(WALK_SPEED * delta, dist)
			var dir := (goal - pos).normalized() if dist > 0.0001 else Vector2.ZERO
			a.pos = pos + dir * mv
			if dir != Vector2.ZERO:
				a.yaw = atan2(-dir.x, -dir.y)
			a.gait += mv / (SIZE * 0.32)
			if dist <= mv + 0.001:
				a.dir = -a.dir
				a.wait = PATROL_PAUSE
		"dance":
			# Samba no lugar: gira, sapateia e dá uns pulinhos.
			a.yaw = a.face + a.t * 2.2
			a.gait += delta * 9.0
		_:
			a.yaw = a.face


func _physics_process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or not GameState.playing or player == null or player.camera == null:
		return
	_check = CHECK_EVERY
	for a in _ants:
		if GameState.has_collectible(a.def.id):
			continue
		var p: Vector2 = a.pos
		if _seen(Vector3(p.x, world.ground_height(p.x, p.y) + 0.08, p.y)):
			GameState.collect(a.def.id)
	if not GameState.has_collectible("noel") and _noel_seen():
		GameState.collect("noel")


## Uma formiga de chapéu de Natal (das de verdade) está perto e à vista?
func _noel_seen() -> bool:
	var cam: Vector3 = player.camera.global_position
	var field = swarm.field
	_near.clear()
	field.gather(cam, FIND_DIST, _near)
	for f in _near:
		if field.flags_of(int(f.x), int(f.y)) >= 1.5:
			var st: Vector4 = field.ant_state(field.chunks[int(f.x)], int(f.y))
			if st.w != INF and _seen(Vector3(st.x, st.y + 0.08, st.z)):
				return true
	var r2 := FIND_DIST * FIND_DIST
	for i in swarm.CAPACITY:
		if swarm.alive[i] == 0 or (swarm.carry[i] & 2) == 0:
			continue
		var pos: Vector3 = swarm.pos[i]
		if pos.distance_squared_to(cam) <= r2 and _seen(pos + Vector3(0, 0.08, 0)):
			return true
	return false


## O ponto está perto da câmera, perto do meio da tela e sem nada no caminho
## (pedra, árvore, paredão)?
func _seen(target: Vector3) -> bool:
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var to := target - from
	var dist := to.length()
	if dist > FIND_DIST:
		return false
	if dist < 0.05:
		return true
	if (-cam.global_transform.basis.z).angle_to(to) > deg_to_rad(FIND_ANGLE):
		return false
	var q := PhysicsRayQueryParameters3D.create(from, target)
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit.position as Vector3).distance_to(target) < 0.3
