extends Node3D
## Enxame de formigas. Há dois tipos:
## - As de campo (AntField, filho deste nó): milhares, nas trilhas e passeando
##   em volta das câmaras; a placa de vídeo calcula onde cada uma está.
## - As simuladas aqui, uma a uma, em arrays + MultiMesh: as moradoras das
##   câmaras abertas, as rainhas, as tanajuras e as de campo que precisam de
##   atenção agora (fugindo do tamanduá, tontas, grudadas na língua ou na mira
##   da Língua Certeira). Quando a de campo se acalma, ela volta para o
##   caminho dela e para de ser simulada aqui.
## Modos: seguindo a trilha (tanajuras), fugindo, voltando, tonta, grudada na
## língua, morando numa câmara aberta e "na mira" (segue o caminho de campo).

const AntMeshBuilder := preload("res://scripts/ants/ant_mesh_builder.gd")
const AntField := preload("res://scripts/ants/ant_field.gd")
const SCENT_SHADER := preload("res://shaders/ant_scent.gdshader")

const CAPACITY := 4096
## Distâncias em que as formigas trocam de malha: detalhada até a 1ª, depois
## simples, bem simples e mínima (até DRAW_DIST). Operárias até a 2ª fazem sombra.
const LOD_DISTS := [2.5, 6.0, 13.0]
const DRAW_DIST := 80.0
## Camadas de desenho (uma MultiMesh cada).
const LAYER_QUEEN := 4
const LAYER_TANAJURA := 5
## Tanajuras longe (malha simples, sem sombra).
const LAYER_TANAJURA_FAR := 6
const LAYER_NAMES := ["Workers0", "Workers1", "Workers2", "Workers3", "Queens", "Tanajuras", "TanajurasFar"]
## Camadas que fazem sombra. A sombra é desenhada por uma cópia da camada com a
## malha "bem simples" (LOD 2): na sombra, que é pequena e borrada, ninguém vê
## a diferença, e a sombra é desenhada até 4 vezes por quadro (uma por faixa).
## Operárias: as de perto fazem sombra com a malha bem simples, e as da 2ª
## camada com a mínima (de 2,5 a 6 m a sombra é um risquinho).
const SHADOW_LAYERS := [0, 1, LAYER_QUEEN, LAYER_TANAJURA]
## Até onde a tanajura usa a malha detalhada (e faz sombra).
const TANAJURA_NEAR := 9.5
## Formigas a menos disto acompanham a inclinação do chão.
const TILT_DIST := 30.0
## Moradoras de câmaras longe do tamanduá: simuladas 1 vez a cada 4 passos
## e não desenhadas muito longe (estão dentro do buraco, nem dá para ver).
const CHAMBER_SIM_LOD_DIST := 20.0
const CHAMBER_DRAW_DIST := 48.0
const STRIDE := 20
## De quantos em quantos passos as formigas de campo conferem se o tamanduá
## está perto.
const FLEE_CHECK_EVERY := 3
## Tonta que acorda a menos disso do tamanduá sai fugindo (m).
const WAKE_FLEE_DIST := 9.0
## Câmara aberta: depois de fugir, as moradoras passeiam até esta distância
## dela (m), por cima do monte também.
const WANDER_RADIUS := 5.0
## Quanto tempo a formiga "na mira" fica com o enxame antes de voltar ao campo.
const GHOST_TIME := 1.2

## ENTER: moradora entrando num buraco (afunda e some). EMERGE: saindo de um.
enum Mode { TRAIL, FLEE, RETURN, STUNNED, STUCK, CHAMBER, GHOST, ENTER, EMERGE }
const WORKER := 0
const QUEEN := 1
const TANAJURA := 2
const SIZE := [0.15, 0.44, 0.22]
const SPEED := [0.7, 0.0, 0.95]
const PANIC_SPEED := [1.8, 0.0, 2.2]
## Quando uma formiga é comida: chance de cada vizinha sair correndo e a
## velocidade dessa corrida (fração da fuga normal).
const SCARE_CHANCE := 0.2
const SCARE_SPEED := 0.6
const CHAMBER_SPEED := 0.32
const QUEEN_SPEED := 0.05
## Buracos das câmaras: quanto a formiga afunda até sumir (m), quanto tempo
## leva para sair (s), quanto ela inclina (rad) e a chance, por segundo, de uma
## moradora perto da câmara aberta (ou espiando fora da fechada) voltar para dentro.
const HOLE_SINK := 0.2
const EMERGE_TIME := 1.1
const DIVE_PITCH := 0.9
const ENTER_CHANCE := 0.04
const PEEK_ENTER_CHANCE := 0.12
## Só volta para dentro quem está a menos disto (m) da câmara aberta.
const ENTER_NEAR := 2.5

var world
var colony
var field: AntField
var trails: Array = []
var obstacles: Array[Vector3] = []

var alive := PackedByteArray()
var kind := PackedByteArray()
var mode := PackedByteArray()
## Folha na boca (bit 1) e chapéu de Natal (bit 2).
var carry := PackedByteArray()
var trail_id := PackedInt32Array()
## Moradora de uma câmara: ninho * 16 + câmara; -1 = não é moradora.
var home := PackedInt32Array()
## De onde veio uma formiga de campo (grupo e índice no AntField); -1 = nasceu aqui.
var origin_chunk := PackedInt32Array()
var origin_idx := PackedInt32Array()
var s := PackedFloat32Array()
var dir := PackedFloat32Array()
var lateral := PackedFloat32Array()
var speed := PackedFloat32Array()
var yaw := PackedFloat32Array()
var gait := PackedFloat32Array()
var timer := PackedFloat32Array()
var highlight := PackedFloat32Array()
## A formiga que a língua vai buscar (Língua Certeira): ganha um contorno verde.
var aim_target := -1
## Até onde se ouve o bater de asas da tanajura (m).
const BUZZ_DIST := 16.0
## De quanto em quanto tempo (s, sorteado entre os dois) ela bate as asas.
const BUZZ_EVERY := Vector2(2.5, 5.0)
var _buzz: AudioStreamPlayer3D
var _buzz_wait := 0.0
var rnd := PackedFloat32Array()
var seed_of := PackedFloat32Array()
## Escala extra (formigas encolhem na boca do tamanduá).
var shrink := PackedFloat32Array()
var pos := PackedVector3Array()
var vel := PackedVector2Array()
## Centro da câmara (x, raio, z) para as moradoras; a casa (x, 0, z) das que
## passeiam em volta de uma câmara do campo.
var anchor := PackedVector3Array()
## Entrando ou saindo: a boca do buraco (x, y, z, raio) e a inclinação do corpo
## (rad, > 0 = cabeça para cima).
var hole_at := PackedVector4Array()
var pitch := PackedFloat32Array()
var _free := PackedInt32Array()
var alive_count := 0
## Uma depois da última vaga ocupada: as voltas pelo enxame param aqui (as
## vagas são dadas a partir da 0, então quase sempre isto é bem menor que CAPACITY).
var _top := 0

## Posição do tamanduá e raio de fuga, atualizados pelo jogador.
var threat_pos := Vector3(9999, 0, 9999)
var flee_radius := 2.0
## Chance de cada inseto fugir quando você chega perto (GameState.flee_chance).
## Cada um tem um número fixo: foge se ele for menor que a chance, então os
## que ficam andando continuam calmos e, ao correr, mais deles fogem.
var flee_chance := 0.35
## Para onde as formigas tontas são puxadas (Terremoto).
var pull_target := Vector3.INF

var _mm: Array[MultiMesh] = []
var _mmi: Array[MultiMeshInstance3D] = []
var _buf: Array[PackedFloat32Array] = []
var _counts := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
## Cópias das camadas que fazem sombra (só sombra, malha simples).
var _shadow_mm: Array[MultiMesh] = []
var _shadow_of: Array[int] = []

var _scent_mat: ShaderMaterial
var _time := 0.0
var cam_pos := Vector3.ZERO:
	set(v):
		cam_pos = v
		if field:
			field.cam = v
var _found: Array[Vector4] = []


## Chão das formigas: o terreno e, por cima, as pedras e troncos caídos.
func _surface(x: float, z: float) -> float:
	var y: float = world.ground_height(x, z)
	if field != null and field.ground != null:
		y += field.ground.extra_height(Vector2(x, z))
	return y


## Câmara da formiga (ninho * 16 + câmara): a das moradoras ou a das que
## passeiam em volta de uma câmara do campo. -1 = nenhuma.
func _chamber_of(i: int) -> int:
	if home[i] >= 0:
		return home[i]
	if origin_chunk[i] >= 0:
		var ch = field.chunks[origin_chunk[i]]
		if ch.kind == AntField.ROAM:
			return ch.index
	return -1


## Chão da formiga i: o de todas e, em cima da tampa fechada da câmara dela,
## a tampa (ela sobe no morrinho).
func _home_surface(i: int, x: float, z: float) -> float:
	var y := _surface(x, z)
	var code := _chamber_of(i)
	if code >= 0:
		y += world.nests[code / 16].cap_lift(code % 16, Vector2(x, z))
	return y


func setup(w, col) -> void:
	world = w
	colony = col
	trails = w.trails.trails
	obstacles = w.vegetation.blockers.duplicate()
	for t in w.vegetation.trees:
		obstacles.append(Vector3(t.position.x, t.position.z, w.vegetation.TRUNK))
	for arr in [alive, kind, mode, carry]:
		arr.resize(CAPACITY)
		arr.fill(0)
	for arr in [s, dir, lateral, speed, yaw, gait, timer, highlight, rnd, seed_of, shrink, pitch]:
		arr.resize(CAPACITY)
		arr.fill(0.0)
	trail_id.resize(CAPACITY)
	home.resize(CAPACITY)
	home.fill(-1)
	origin_chunk.resize(CAPACITY)
	origin_chunk.fill(-1)
	origin_idx.resize(CAPACITY)
	pos.resize(CAPACITY)
	vel.resize(CAPACITY)
	anchor.resize(CAPACITY)
	hole_at.resize(CAPACITY)
	_free.resize(CAPACITY)
	for i in CAPACITY:
		_free[i] = CAPACITY - 1 - i
	for t in trails:
		t.bake_heights(w)
	field = AntField.new()
	field.name = "Field"
	add_child(field)
	_scent_mat = ShaderMaterial.new()
	_scent_mat.shader = SCENT_SHADER
	# 0..3 operárias (de perto para longe), 4 rainha, 5 tanajura perto, 6 tanajura longe
	var meshes: Array[Mesh] = []
	for lod in 4:
		meshes.append(AntMeshBuilder.build("worker", lod))
	meshes.append(AntMeshBuilder.build("queen", 0))
	meshes.append(AntMeshBuilder.build("tanajura", 0))
	meshes.append(AntMeshBuilder.build("tanajura", 2))
	var shadow_mesh := {0: meshes[2], 1: meshes[3], LAYER_QUEEN: AntMeshBuilder.build("queen", 2), LAYER_TANAJURA: meshes[6]}
	var caps := [1200, 2000, CAPACITY, CAPACITY, 16, 60, 60]
	for k in caps.size():
		var mmi := _new_layer(LAYER_NAMES[k], meshes[k], caps[k], GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		_mm.append(mmi.multimesh)
		_mmi.append(mmi)
		var buf := PackedFloat32Array()
		buf.resize(caps[k] * STRIDE)
		_buf.append(buf)
	for k in SHADOW_LAYERS:
		var smmi := _new_layer(LAYER_NAMES[k] + "Shadow", shadow_mesh[k], caps[k],
			GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
		_shadow_mm.append(smmi.multimesh)
		_shadow_of.append(k)


func _new_layer(layer_name: String, mesh: Mesh, cap: int, shadow: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-90, -20, -90), Vector3(180, 60, 180))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = layer_name
	mmi.multimesh = mm
	mmi.cast_shadow = shadow
	add_child(mmi)
	return mmi


func _take_slot() -> int:
	if _free.is_empty():
		return -1
	var i := _free[_free.size() - 1]
	_free.resize(_free.size() - 1)
	alive[i] = 1
	_top = maxi(_top, i + 1)
	alive_count += 1
	rnd[i] = randf()
	seed_of[i] = float(randi() % 1024)
	gait[i] = randf() * TAU
	timer[i] = 0.0
	highlight[i] = 0.0
	shrink[i] = 1.0
	pitch[i] = 0.0
	carry[i] = 2 if randf() < AntField.hat_chance() else 0
	vel[i] = Vector2.ZERO
	home[i] = -1
	origin_chunk[i] = -1
	trail_id[i] = -1
	return i


## Formiga de trilha simulada aqui (as tanajuras).
func spawn(ant_kind: int, trail_index: int, at_s: float, direction: float, lat: float = 0.0, carrying: bool = false) -> int:
	var i := _take_slot()
	if i < 0:
		return -1
	kind[i] = ant_kind
	mode[i] = Mode.TRAIL
	if carrying:
		carry[i] |= 1
	trail_id[i] = trail_index
	s[i] = at_s
	dir[i] = direction
	lateral[i] = lat
	speed[i] = SPEED[ant_kind] * randf_range(0.85, 1.15)
	var t = trails[trail_index]
	var p2: Vector2 = t.point_at(at_s) + t.side_at(at_s) * lat
	pos[i] = Vector3(p2.x, _surface(p2.x, p2.y), p2.y)
	return i


## Moradora de uma câmara aberta (ou a rainha, que anda devagar no fundo).
## `from_tunnel` = acabou de sair do túnel, no meio da câmara. Num buraco comprido,
## `axis` e `half_len` dão a direção e o meio comprimento dela. Com `hole`
## (x, y, z, raio da boca), ela sobe de dentro dele.
func spawn_resident(ant_kind: int, home_code: int, center: Vector2, radius: float, from_tunnel: bool = false,
		axis: float = 0.0, half_len: float = 0.0, hole: Vector4 = Vector4.ZERO) -> int:
	var i := _take_slot()
	if i < 0:
		return -1
	kind[i] = ant_kind
	mode[i] = Mode.CHAMBER
	home[i] = home_code
	anchor[i] = Vector3(center.x, radius, center.y)
	# Moradoras não usam a trilha: dir e lateral guardam a forma do buraco.
	dir[i] = axis
	lateral[i] = half_len
	trail_id[i] = 0
	speed[i] = (QUEEN_SPEED if ant_kind == QUEEN else CHAMBER_SPEED) * randf_range(0.7, 1.3)
	var p2 := center
	var a := randf() * TAU
	if ant_kind != QUEEN:
		var spread := 0.22 if from_tunnel else 0.9
		p2 += Vector2(cos(a), sin(a)) * radius * sqrt(randf()) * spread
		if half_len > 0.0:
			p2 += Vector2(cos(axis), sin(axis)) * half_len * randf_range(-1.0, 1.0) * (0.35 if from_tunnel else 0.9)
	vel[i] = Vector2(cos(a + (0.3 if from_tunnel else 1.7)), sin(a + (0.3 if from_tunnel else 1.7))) * speed[i]
	pos[i] = Vector3(p2.x, _surface(p2.x, p2.y), p2.y)
	yaw[i] = randf() * TAU
	if hole.w > 0.0 and ant_kind != QUEEN:
		# Sobe de dentro do buraco, com a cabeça para cima.
		var out := Vector2.RIGHT.rotated(a)
		mode[i] = Mode.EMERGE
		hole_at[i] = hole
		timer[i] = 0.0
		vel[i] = out * speed[i]
		pos[i] = Vector3(hole.x, hole.y - HOLE_SINK, hole.z)
		yaw[i] = atan2(-out.x, -out.y)
		pitch[i] = DIVE_PITCH
	return i


## Quantas formigas simuladas aqui moram na câmara `code`.
func count_home(code: int) -> int:
	var n := 0
	for i in _top:
		if alive[i] == 1 and home[i] == code:
			n += 1
	return n


## Entrando ou saindo de um buraco: volta a andar no chão, no lugar onde está.
func _leave_hole(i: int) -> void:
	if mode[i] == Mode.ENTER or mode[i] == Mode.EMERGE:
		mode[i] = Mode.CHAMBER
	pitch[i] = 0.0
	pos[i].y = _home_surface(i, pos[i].x, pos[i].z)


## Sai de dentro do buraco: um pouco para fora da boca, subindo.
func _update_emerge(i: int, delta: float) -> void:
	var h := hole_at[i]
	timer[i] += delta / EMERGE_TIME
	var k := minf(timer[i], 1.0)
	var out := vel[i].normalized() if vel[i].length_squared() > 0.000001 else Vector2.RIGHT
	var p2 := Vector2(h.x, h.z) + out * h.w * 1.7 * k
	var e := smoothstep(0.0, 1.0, k)
	pos[i] = Vector3(p2.x, lerpf(h.y - HOLE_SINK, _home_surface(i, p2.x, p2.y), e), p2.y)
	pitch[i] = DIVE_PITCH * (1.0 - e)
	yaw[i] = atan2(-out.x, -out.y)
	gait[i] += speed[i] * 1.5 * delta / (SIZE[kind[i]] * 0.32)
	if timer[i] >= 1.0:
		mode[i] = Mode.CHAMBER
		pitch[i] = 0.0
		vel[i] = out * speed[i]


## Vai até a boca do buraco e afunda nele, de cabeça para baixo, até sumir.
func _update_enter(i: int, delta: float) -> void:
	var h := hole_at[i]
	var p2 := Vector2(pos[i].x, pos[i].z)
	var to := Vector2(h.x, h.z) - p2
	var d := to.length()
	var sp := maxf(speed[i] * 1.4, 0.3)
	if d > 0.0001:
		var step := minf(sp * delta, d)
		p2 += to / d * step
		d -= step
		yaw[i] = lerp_angle(yaw[i], atan2(-to.x, -to.y), minf(delta * 10.0, 1.0))
	var near := h.w * 1.5
	var sink := 1.0 - d / near if d < near else 0.0
	# timer > 0: já está afundando (não foge mais).
	timer[i] = sink
	var y := _home_surface(i, p2.x, p2.y)
	pos[i] = Vector3(p2.x, lerpf(y, h.y - HOLE_SINK, sink), p2.y)
	pitch[i] = -DIVE_PITCH * sink
	gait[i] += sp * delta / (SIZE[kind[i]] * 0.32)
	if d <= 0.015:
		_went_in(i)


## Sumiu no buraco: a de campo volta para o passeio dela (dentro da câmara) e
## a moradora volta a contar como escondida.
func _went_in(i: int) -> void:
	if origin_chunk[i] >= 0:
		_back_to_field(i, true)
		return
	if colony != null:
		colony.resident_went_in(i)
	despawn(i)


## Moradora (fora da câmara) volta para dentro pelo buraco mais perto. Retorna
## se achou um buraco.
func _try_enter(i: int) -> bool:
	var code := _chamber_of(i)
	if code < 0:
		return false
	var holes: Array[Vector4] = world.nests[code / 16].chamber_holes(code % 16)
	if holes.is_empty():
		return false
	var p := pos[i]
	var best := holes[0]
	for h in holes:
		if Vector2(h.x - p.x, h.z - p.z).length_squared() < Vector2(best.x - p.x, best.z - p.z).length_squared():
			best = h
	mode[i] = Mode.ENTER
	hole_at[i] = best
	timer[i] = 0.0
	return true


## As moradoras de uma câmara passam a morar em outra (o monte desmanchado:
## todas caem no buraco da rainha). Retorna quantas mudaram.
func rehome(from_code: int, to_code: int, center: Vector2, radius: float) -> int:
	var n := 0
	for i in _top:
		if alive[i] == 0 or home[i] != from_code:
			continue
		home[i] = to_code
		if mode[i] == Mode.ENTER or mode[i] == Mode.EMERGE:
			_leave_hole(i)
		anchor[i] = Vector3(center.x, radius, center.y)
		dir[i] = 0.0
		lateral[i] = 0.0
		n += 1
	return n


func despawn(i: int) -> void:
	if alive[i] == 0:
		return
	alive[i] = 0
	alive_count -= 1
	home[i] = -1
	origin_chunk[i] = -1
	_free.append(i)
	while _top > 0 and alive[_top - 1] == 0:
		_top -= 1


func clear_all() -> void:
	for i in _top:
		if alive[i] == 1:
			# As de campo voltam para o campo.
			if origin_chunk[i] >= 0 and mode[i] != Mode.STUCK:
				field.unhide(origin_chunk[i], origin_idx[i])
			despawn(i)


# ------------------------------------------------------------------ Campo

## Assume a formiga `fi` do grupo `ci` do campo: ela some de lá e passa a ser
## simulada aqui, no modo `m`. Retorna o índice aqui (ou -1).
func take_from_field(ci: int, fi: int, m: int) -> int:
	var ch = field.chunks[ci]
	var st: Vector4 = field.ant_state(ch, fi)
	if st.w == INF:
		return -1
	var i := _take_slot()
	if i < 0:
		return -1
	field.hide_ant(ci, fi)
	kind[i] = WORKER
	mode[i] = m
	origin_chunk[i] = ci
	origin_idx[i] = fi
	var flags := int(field.flags_of(ci, fi))
	carry[i] = (flags & 2) | ((flags & 1) if field.returning(ci, fi) else 0)
	var size: float = field.size_of(ci, fi)
	rnd[i] = clampf((size / SIZE[WORKER] - 0.92) / 0.16, 0.0, 1.0)
	seed_of[i] = field.seed_of(ci, fi)
	speed[i] = field.speed_of(ci, fi)
	pos[i] = Vector3(st.x, st.y, st.z)
	yaw[i] = st.w
	if ch.kind == AntField.TRAIL:
		trail_id[i] = ch.index
		var sd: Vector2 = field.trail_s(ci, fi)
		s[i] = sd.x
		dir[i] = sd.y
		lateral[i] = 0.0
	else:
		anchor[i] = Vector3(ch.home.x, 0.0, ch.home.y)
	if m == Mode.GHOST:
		timer[i] = GHOST_TIME
	return i


## A formiga de campo i, já calma, volta para o campo (e sai daqui).
func _back_to_field(i: int, rejoin: bool) -> void:
	var ci := origin_chunk[i]
	var fi := origin_idx[i]
	if rejoin:
		if field.chunks[ci].kind == AntField.TRAIL:
			field.rejoin_trail(ci, fi, s[i], dir[i])
		else:
			field.rejoin_home(ci, fi)
	else:
		field.unhide(ci, fi)
	despawn(i)


func _is_field_trail(i: int) -> bool:
	return origin_chunk[i] >= 0 and field.chunks[origin_chunk[i]].kind == AntField.TRAIL


# ------------------------------------------------------------------ Passo

func _physics_process(delta: float) -> void:
	if world == null:
		return
	_time += delta
	var tp2 := Vector2(threat_pos.x, threat_pos.z)
	var flee_r2 := flee_radius * flee_radius
	var lod_r2 := CHAMBER_SIM_LOD_DIST * CHAMBER_SIM_LOD_DIST
	var frame := Engine.get_physics_frames()
	var lod_tick := frame % 4
	# As de campo perto do tamanduá saem correndo.
	if frame % FLEE_CHECK_EVERY == 0:
		_found.clear()
		field.gather(threat_pos, flee_radius, _found)
		for f in _found:
			if _calm(int(f.x) * 100003 + int(f.y)):
				continue
			var i := take_from_field(int(f.x), int(f.y), Mode.FLEE)
			if i >= 0:
				_start_flee(i, tp2)
	for i in _top:
		if alive[i] == 0:
			continue
		var m := mode[i]
		if highlight[i] > 0.0:
			highlight[i] = maxf(highlight[i] - delta, 0.0)
		# Indo para o buraco ainda foge; já afundando, não.
		if m == Mode.TRAIL or m == Mode.RETURN or m == Mode.CHAMBER or m == Mode.GHOST \
				or (m == Mode.ENTER and timer[i] <= 0.0):
			var d2 := Vector2(pos[i].x, pos[i].z).distance_squared_to(tp2)
			if d2 < flee_r2 and kind[i] != QUEEN and not _calm(i):
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
			Mode.GHOST:
				_update_ghost(i, delta)
			Mode.ENTER:
				_update_enter(i, delta)
			Mode.EMERGE:
				_update_emerge(i, delta)
			_:
				pass


## Este inseto fica calmo com você perto? (Veja flee_chance.)
func _calm(id: int) -> bool:
	var n := (id ^ 61) ^ (id >> 16)
	n = (n * 9) & 0xFFFFFFFF
	n ^= n >> 4
	n = (n * 0x27d4eb2d) & 0xFFFFFFFF
	n ^= n >> 15
	return float(n & 0xFFFF) / 65536.0 >= flee_chance


## Uma formiga foi pega: algumas das outras num raio em volta (SCARE_CHANCE)
## saem correndo, mais devagar que na fuga normal. As tontas continuam tontas.
func scare(at: Vector3, radius: float) -> void:
	var from := Vector2(at.x, at.z)
	var r2 := radius * radius
	var found: Array[Vector4] = []
	field.gather(at, radius, found)
	for f in found:
		if randf() >= SCARE_CHANCE:
			continue
		var j := take_from_field(int(f.x), int(f.y), Mode.FLEE)
		if j >= 0:
			_start_flee(j, from, SCARE_SPEED)
	for i in _top:
		if alive[i] == 0 or kind[i] == QUEEN:
			continue
		var m := mode[i]
		if m != Mode.TRAIL and m != Mode.RETURN and m != Mode.CHAMBER and m != Mode.GHOST:
			continue
		if Vector2(pos[i].x, pos[i].z).distance_squared_to(from) < r2 and randf() < SCARE_CHANCE:
			_start_flee(i, from, SCARE_SPEED)


func _start_flee(i: int, from: Vector2, speed_mult: float = 1.0) -> void:
	var p2 := Vector2(pos[i].x, pos[i].z)
	var away := (p2 - from)
	if away.length_squared() < 0.0001:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	away = away.normalized().rotated(randf_range(-0.7, 0.7))
	mode[i] = Mode.FLEE
	pitch[i] = 0.0
	vel[i] = away * PANIC_SPEED[kind[i]] * speed_mult * randf_range(0.85, 1.15)
	# Moradoras correm mais longe antes de pensar em voltar para a câmara.
	timer[i] = randf_range(2.4, 3.8) if home[i] >= 0 else randf_range(1.2, 2.2)


## Tanajuras: andam pela trilha e nunca entram no formigueiro.
func _update_trail(i: int, delta: float) -> void:
	var t = trails[trail_id[i]]
	var sp := speed[i]
	var ns := s[i] + sp * dir[i] * delta
	if dir[i] > 0.0 and ns >= t.length:
		ns = t.length
		dir[i] = -1.0
	elif dir[i] < 0.0 and ns <= 0.6:
		ns = 0.6
		dir[i] = 1.0
	s[i] = ns
	var lat := lateral[i] + sin(_time * 1.3 + rnd[i] * 40.0) * 0.03
	var p2: Vector2 = t.point_at(ns) + t.side_at(ns) * lat
	var fwd: Vector2 = t.dir_at(ns) * dir[i]
	var y: float = _surface(p2.x, p2.y)
	if kind[i] == TANAJURA:
		y += 0.35 + sin(_time * 2.2 + rnd[i] * 9.0) * 0.12
	pos[i] = Vector3(p2.x, y, p2.y)
	yaw[i] = lerp_angle(yaw[i], atan2(-fwd.x, -fwd.y), minf(delta * 10.0, 1.0))
	gait[i] += sp * delta / (SIZE[kind[i]] * 0.32)


func _update_free(i: int, delta: float) -> void:
	var v := vel[i]
	v = v.rotated(randf_range(-2.0, 2.0) * delta)
	var p2 := Vector2(pos[i].x, pos[i].z) + v * delta
	# Contorna arbustos, árvores, cupinzeiros e lagoas (pedras e troncos ela sobe).
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
	var y: float = _home_surface(i, p2.x, p2.y)
	if kind[i] == TANAJURA:
		y += 0.45 + sin(_time * 3.0 + rnd[i] * 9.0) * 0.15
	pos[i] = Vector3(p2.x, y, p2.y)
	if v.length_squared() > 0.0001:
		yaw[i] = lerp_angle(yaw[i], atan2(-v.x, -v.y), minf(delta * 12.0, 1.0))
	gait[i] += v.length() * delta / (SIZE[kind[i]] * 0.32)
	timer[i] -= delta
	if timer[i] <= 0.0:
		_start_return(i)


func _start_return(i: int) -> void:
	mode[i] = Mode.RETURN
	if home[i] < 0 and trail_id[i] >= 0:
		var t = trails[trail_id[i]]
		s[i] = t.closest_s(Vector2(pos[i].x, pos[i].z), s[i], 30.0)


func _update_return(i: int, delta: float) -> void:
	if home[i] >= 0:
		_update_homing(i, delta)
		return
	var p2 := Vector2(pos[i].x, pos[i].z)
	var target: Vector2
	var on_trail := trail_id[i] >= 0
	if on_trail:
		var t = trails[trail_id[i]]
		target = t.point_at(s[i]) + t.side_at(s[i]) * lateral[i]
	else:
		target = Vector2(anchor[i].x, anchor[i].z)
	var to := target - p2
	var dist := to.length()
	var sp := maxf(speed[i] * 1.8, 0.6)
	var step := sp * delta
	# Das que passeiam: chegando na câmara, entra pelo buraco dela.
	if not on_trail and origin_chunk[i] >= 0 and dist < 0.5 and _try_enter(i):
		return
	if dist <= step + 0.04:
		if origin_chunk[i] >= 0:
			_back_to_field(i, true)
		else:
			mode[i] = Mode.TRAIL
		return
	var v := to / dist * sp
	p2 += v * delta
	var y: float = _home_surface(i, p2.x, p2.y)
	if kind[i] == TANAJURA:
		y += 0.4
	pos[i] = Vector3(p2.x, y, p2.y)
	yaw[i] = lerp_angle(yaw[i], atan2(-v.x, -v.y), minf(delta * 10.0, 1.0))
	gait[i] += v.length() * delta / (SIZE[kind[i]] * 0.32)
	if on_trail:
		# Vai avançando o ponto-alvo para não voltar para trás.
		var t = trails[trail_id[i]]
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
	pos[i] = Vector3(p2.x, _home_surface(i, p2.x, p2.y), p2.y)
	yaw[i] = lerp_angle(yaw[i], atan2(-v.x, -v.y), minf(delta * 10.0, 1.0))
	gait[i] += sp * delta / (SIZE[kind[i]] * 0.32)


## Na mira da Língua Certeira: continua no caminho de campo dela.
func _update_ghost(i: int, delta: float) -> void:
	var ci := origin_chunk[i]
	var st: Vector4 = field.ant_state(field.chunks[ci], origin_idx[i], true)
	timer[i] -= delta
	if st.w == INF or timer[i] <= 0.0:
		_back_to_field(i, false)
		return
	pos[i] = Vector3(st.x, st.y, st.z)
	yaw[i] = st.w
	gait[i] += speed[i] * delta / (SIZE[WORKER] * 0.32)


## Moradoras andam em círculos dentro da câmara e se afastam do focinho. A
## rainha anda bem devagar.
func _update_chamber(i: int, delta: float, threat: Vector2) -> void:
	var a := anchor[i]
	var center := Vector2(a.x, a.z)
	var radius := a.y
	var queen := kind[i] == QUEEN
	var p2 := Vector2(pos[i].x, pos[i].z)
	var v := vel[i].rotated(randf_range(-2.5, 2.5) * delta * (0.4 if queen else 1.0))
	# O bolo de formigas fica dentro da câmara.
	var limit := maxf(radius * (0.45 if queen else 0.9) - SIZE[kind[i]] * 0.5, radius * 0.25)
	var away := p2 - threat
	var dthreat := away.length()
	if not queen and dthreat < 1.6 and dthreat > 0.001:
		v = v.lerp(away / dthreat * speed[i] * 2.2, minf(delta * 3.0, 1.0))
	else:
		v = v.normalized() * speed[i] if v.length_squared() > 0.000001 else Vector2.RIGHT.rotated(randf() * TAU) * speed[i]
	p2 += v * delta
	# Num buraco comprido, o "centro" é o ponto do eixo dele mais perto da formiga.
	var half := lateral[i]
	if half < 0.0:
		# Passeando em volta de uma câmara aberta: contorna arbustos e lagoas.
		p2 = _push_out(p2)
	elif half > 0.0:
		var ax := Vector2(cos(dir[i]), sin(dir[i]))
		center += ax * clampf((p2 - center).dot(ax), -half, half)
	var off := p2 - center
	if off.length() > limit:
		var n := off.normalized()
		p2 = center + n * limit
		v = v.bounce(n) * 0.8
	vel[i] = v
	pos[i] = Vector3(p2.x, _home_surface(i, p2.x, p2.y), p2.y)
	if v.length_squared() > 0.000001:
		yaw[i] = lerp_angle(yaw[i], atan2(-v.x, -v.y), minf(delta * (2.0 if queen else 8.0), 1.0))
	gait[i] += v.length() * delta / (SIZE[kind[i]] * 0.32)
	# De vez em quando volta para dentro por um buraco da câmara (e outra sai).
	var roll := randf()
	if not queen and half <= 0.0 and roll < delta * PEEK_ENTER_CHANCE and roll < delta * _enter_chance(i, p2):
		_try_enter(i)


## Chance por segundo da moradora i (em p2) voltar para dentro: as que espiam
## fora de uma câmara fechada voltam logo; as da câmara aberta, só perto dela.
func _enter_chance(i: int, p2: Vector2) -> float:
	var code := home[i]
	var c = world.nests[code / 16].chambers[code % 16]
	if not c.opened:
		return PEEK_ENTER_CHANCE
	if p2.distance_squared_to(c.pos2) > ENTER_NEAR * ENTER_NEAR:
		return 0.0
	return ENTER_CHANCE


func _update_stunned(i: int, delta: float) -> void:
	timer[i] -= delta
	if pull_target != Vector3.INF and kind[i] != QUEEN:
		var p := pos[i]
		var to := pull_target - p
		to.y = 0.0
		var d := to.length()
		if d > 0.35:
			var p2 := Vector2(p.x, p.z) + Vector2(to.x, to.z) / d * minf(2.6 * delta, d)
			pos[i] = Vector3(p2.x, _home_surface(i, p2.x, p2.y), p2.y)
	if timer[i] <= 0.0:
		# Acordou perto do tamanduá: continua fugindo de medo.
		var tp2 := Vector2(threat_pos.x, threat_pos.z)
		if kind[i] != QUEEN and Vector2(pos[i].x, pos[i].z).distance_to(tp2) < WAKE_FLEE_DIST:
			_start_flee(i, tp2)
			return
		if home[i] >= 0:
			# Longe da câmara (puxada pelo Terremoto ou tonta no meio da fuga): volta andando.
			var off := Vector2(pos[i].x - anchor[i].x, pos[i].z - anchor[i].z)
			if off.length() > anchor[i].y * 0.92:
				mode[i] = Mode.RETURN
			else:
				mode[i] = Mode.CHAMBER
				vel[i] = -off.normalized() * speed[i]
		else:
			_start_return(i)


## Câmara aberta (menos o buraco da rainha): as moradoras não voltam para
## dentro; passam a passear em volta dela, até WANDER_RADIUS.
## `instant` = já põe cada uma num ponto da volta (ao carregar um jogo salvo).
func disperse_home(home_code: int, center: Vector2, instant: bool = false) -> void:
	for i in _top:
		if alive[i] == 0 or home[i] != home_code or kind[i] == QUEEN:
			continue
		# Entrando ou saindo pela tampa, que sumiu: fica onde está.
		if mode[i] == Mode.ENTER or mode[i] == Mode.EMERGE:
			_leave_hole(i)
		disperse(i, center, instant)


## `radius` = até onde ela passeia (m).
func disperse(i: int, center: Vector2, instant: bool = false, radius: float = WANDER_RADIUS) -> void:
	# Em _update_chamber, o limite é 90% do raio guardado.
	anchor[i] = Vector3(center.x, radius / 0.9, center.y)
	dir[i] = 0.0
	lateral[i] = -1.0
	if instant:
		var spot := center + Vector2.RIGHT.rotated(randf() * TAU) * radius * sqrt(randf())
		pos[i] = Vector3(spot.x, _surface(spot.x, spot.y), spot.y)
		mode[i] = Mode.CHAMBER


## Empurra o ponto para fora de arbustos, árvores, cupinzeiros e lagoas.
func _push_out(p2: Vector2) -> Vector2:
	for o in obstacles:
		var off := p2 - Vector2(o.x, o.y)
		var rr := o.z + 0.1
		var dd := off.length_squared()
		if dd < rr * rr and dd > 0.000001:
			p2 = Vector2(o.x, o.y) + off / sqrt(dd) * rr
	return p2


## Câmara recém-aberta: as moradoras saem correndo para longe do tamanduá.
func scatter_home(home_code: int) -> void:
	var tp2 := Vector2(threat_pos.x, threat_pos.z)
	for i in _top:
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
		var d := (out.normalized() + away.normalized() * 0.8).normalized().rotated(randf_range(-0.6, 0.6))
		mode[i] = Mode.FLEE
		vel[i] = d * PANIC_SPEED[kind[i]] * randf_range(0.8, 1.2)
		timer[i] = randf_range(2.2, 4.0)


## Deixa tontas as moradoras de uma câmara (Garras Fortes, ao abrir).
func stun_home(home_code: int, duration: float) -> int:
	var n := 0
	for i in _top:
		if alive[i] == 0 or home[i] != home_code or kind[i] == QUEEN or mode[i] == Mode.STUCK:
			continue
		_leave_hole(i)
		mode[i] = Mode.STUNNED
		timer[i] = duration * randf_range(0.9, 1.15)
		n += 1
	return n


## Deixa tontas (de barriga para cima) as formigas num raio.
func stun_radius(center: Vector3, radius: float, duration: float) -> int:
	var n := 0
	var r2 := radius * radius
	_found.clear()
	field.gather(center, radius, _found)
	for f in _found:
		take_from_field(int(f.x), int(f.y), Mode.STUNNED)
	for i in _top:
		if alive[i] == 0 or mode[i] == Mode.STUCK or kind[i] == QUEEN:
			continue
		var dx := pos[i].x - center.x
		var dz := pos[i].z - center.z
		if dx * dx + dz * dz <= r2:
			mode[i] = Mode.STUNNED
			timer[i] = duration * randf_range(0.9, 1.15)
			pitch[i] = 0.0
			pos[i].y = _home_surface(i, pos[i].x, pos[i].z)
			n += 1
	return n


func _reach2(i: int, p: Vector3) -> float:
	return (pos[i] + Vector3(0, SIZE[kind[i]] * 0.25, 0)).distance_squared_to(p)


func _queen_blocked(i: int) -> bool:
	return kind[i] == QUEEN and colony != null and colony.is_queen_protected(home[i])


## Lambida: gruda até `capacity` formigas no raio, as mais perto da ponta
## primeiro. Retorna as grudadas e se bateu numa rainha protegida.
func lick(tip: Vector3, radius: float, capacity: int) -> Dictionary:
	var protected_queen := false
	var r2 := radius * radius
	# Vector3(distância², índice, 0 = daqui / 1 = do campo, grupo do campo)
	var near: Array[Vector4] = []
	for i in _top:
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
		near.append(Vector4(d2, i, 0, 0))
	_found.clear()
	field.gather(tip, radius + 0.3, _found)
	for f in _found:
		var st: Vector4 = field.ant_state(field.chunks[int(f.x)], int(f.y))
		var d2 := Vector3(st.x, st.y + SIZE[WORKER] * 0.25, st.z).distance_squared_to(tip)
		if d2 <= r2:
			near.append(Vector4(d2, f.y, 1, f.x))
	near.sort()
	var captured := PackedInt32Array()
	for k in mini(capacity, near.size()):
		var e := near[k]
		var i := int(e.y)
		if e.z > 0.5:
			i = take_from_field(int(e.w), int(e.y), Mode.STUCK)
			if i < 0:
				continue
		mode[i] = Mode.STUCK
		captured.append(i)
	return {"captured": captured, "queen_protected": protected_queen}


## Tanajura voando que a língua cruza indo reta de `from` até `to` (a mais perto
## de `from`), ou -1. Sem isso, a língua passava por baixo dela e ia até o chão.
func tanajura_on_path(from: Vector3, to: Vector3, radius: float) -> int:
	var seg := to - from
	var len2 := seg.length_squared()
	if len2 < 0.0001:
		return -1
	var r2 := radius * radius
	var best := -1
	var best_t := INF
	for i in _top:
		if alive[i] == 0 or kind[i] != TANAJURA or mode[i] == Mode.STUCK or mode[i] == Mode.STUNNED:
			continue
		var c := pos[i] + Vector3(0, SIZE[TANAJURA] * 0.25, 0)
		var t := clampf((c - from).dot(seg) / len2, 0.0, 1.0)
		if t < best_t and (from + seg * t).distance_squared_to(c) <= r2:
			best_t = t
			best = i
	return best


## Onde a língua deve tocar este inseto (o meio do corpo).
func body_point(i: int) -> Vector3:
	return pos[i] + Vector3(0, SIZE[kind[i]] * 0.25, 0)


## Há alguma formiga (que dá para pegar) a menos de `radius` deste ponto?
func any_near(point: Vector3, radius: float) -> bool:
	var r2 := radius * radius
	for i in _top:
		if alive[i] == 0 or mode[i] == Mode.STUCK or _queen_blocked(i):
			continue
		if _reach2(i, point) <= r2:
			return true
	return field.any_near(point, radius)


## Formiga mais próxima da mira (Língua Certeira), ou -1. Se for uma de
## campo, o enxame passa a acompanhá-la (para a língua saber onde ela está).
func best_target(origin: Vector3, aim_dir: Vector3, max_dist: float, max_angle_cos: float) -> int:
	var best := -1
	var best_score := -INF
	for i in _top:
		if alive[i] == 0 or mode[i] == Mode.STUCK or _queen_blocked(i):
			continue
		var score := _aim_score(pos[i] - origin, aim_dir, max_dist, max_angle_cos)
		if score > best_score:
			best_score = score
			best = i
	_found.clear()
	field.gather(origin, max_dist, _found)
	var best_field := Vector2(-1, -1)
	for f in _found:
		var st: Vector4 = field.ant_state(field.chunks[int(f.x)], int(f.y))
		var score := _aim_score(Vector3(st.x, st.y, st.z) - origin, aim_dir, max_dist, max_angle_cos)
		if score > best_score:
			best_score = score
			best_field = Vector2(f.x, f.y)
	if best_field.x >= 0.0:
		var i := take_from_field(int(best_field.x), int(best_field.y), Mode.GHOST)
		if i >= 0:
			return i
	keep_target(best)
	return best


func _aim_score(to: Vector3, aim_dir: Vector3, max_dist: float, max_angle_cos: float) -> float:
	var d := to.length()
	if d > max_dist or d < 0.05:
		return -INF
	var c := to.dot(aim_dir) / d
	if c < max_angle_cos:
		return -INF
	return c * 4.0 - d * 0.08


## A formiga na mira continua sendo acompanhada (a língua está indo atrás dela).
func keep_target(i: int) -> void:
	if i >= 0 and alive[i] == 1 and mode[i] == Mode.GHOST:
		timer[i] = GHOST_TIME


## Formigueiro de uma formiga simulada aqui (-1 = nenhum).
func nest_of(i: int) -> int:
	if home[i] >= 0:
		return home[i] / 16
	if origin_chunk[i] >= 0:
		return field.chunk_nest(origin_chunk[i])
	if trail_id[i] >= 0:
		return int(trails[trail_id[i]].nest)
	return -1


## O faro de família: as formigas do formigueiro `nest_i` (ou só as moradoras
## da câmara `code`, se >= 0) a até `radius` m (< 0 = em qualquer lugar)
## brilham por `duration` s. Devolve quantas, a mais perto e alguns pontos
## (para a bússola e o brilho sem foco).
func sniff_family(center: Vector3, radius: float, nest_i: int, code: int, duration: float) -> Dictionary:
	var c2 := Vector2(center.x, center.z)
	var r2 := radius * radius
	var points := PackedVector3Array()
	var count := 0
	var nearest := INF
	# code < -1: nenhuma câmara para farejar.
	if nest_i < 0 or code < -1:
		return {"count": 0, "nearest": -1.0, "points": points}
	for i in _top:
		if alive[i] == 0 or mode[i] == Mode.STUCK:
			continue
		if code >= 0:
			if home[i] != code:
				continue
		elif nest_of(i) != nest_i:
			continue
		var d2 := Vector2(pos[i].x, pos[i].z).distance_squared_to(c2)
		if radius >= 0.0 and d2 > r2:
			continue
		count += 1
		nearest = minf(nearest, sqrt(d2))
		highlight[i] = duration
		if points.size() < 400:
			points.append(pos[i])
	if code < 0:
		for ci in field.chunks.size():
			var ch = field.chunks[ci]
			if ch.alive <= 0 or field.chunk_nest(ci) != nest_i:
				continue
			var far: bool = radius >= 0.0 and Vector2(ch.center.x, ch.center.z).distance_to(c2) - ch.radius > radius
			if far:
				continue
			var k := 0
			for fi in ch.count:
				if not field.is_alive(ci, fi):
					continue
				k += 1
				if radius >= 0.0 or k % 3 == 0:
					var p2: Vector2 = field.ant_xz(ch, fi)
					if p2 == Vector2.INF:
						continue
					var d2 := p2.distance_squared_to(c2)
					if radius >= 0.0 and d2 > r2:
						continue
					nearest = minf(nearest, sqrt(d2))
					if points.size() < 400 and k % 3 == 0:
						var st: Vector4 = field.ant_state(ch, fi)
						if st.w != INF:
							points.append(Vector3(st.x, st.y, st.z))
				count += 1
				field.highlight(ci, fi, duration)
	return {"count": count, "nearest": nearest if nearest < INF else -1.0, "points": points}


func set_scent_overlay(enabled: bool) -> void:
	for mmi in _mmi:
		mmi.material_overlay = _scent_mat if enabled else null
	field.set_scent_overlay(enabled)


## Cor do faro (configurável). A rainha continua com o brilho dourado dela.
func set_sniff_color(c: Color) -> void:
	if _scent_mat:
		_scent_mat.set_shader_parameter("tint", c)
	for k in [0, 1, 2, 3, LAYER_TANAJURA, LAYER_TANAJURA_FAR]:
		if k < _mmi.size():
			_mmi[k].set_instance_shader_parameter("glow_color", c)
	field.set_sniff_color(c)


## Centro aproximado do maior grupo de formigas (para a bússola do faro).
func densest_point(around: Vector3, max_dist: float) -> Vector3:
	var cell := 6.0
	var counts := {}
	var best_key := Vector2i.ZERO
	var best_n := 0
	var md2 := max_dist * max_dist
	for i in _top:
		if alive[i] == 0 or pos[i].distance_squared_to(around) > md2:
			continue
		var key := Vector2i(floori(pos[i].x / cell), floori(pos[i].z / cell))
		var n: int = counts.get(key, 0) + 1
		counts[key] = n
		if n > best_n:
			best_n = n
			best_key = key
	# Grupos de campo: contam no centro deles.
	for ch in field.chunks:
		if ch.alive <= 0 or ch.center.distance_squared_to(around) > md2:
			continue
		var key := Vector2i(floori(ch.center.x / cell), floori(ch.center.z / cell))
		var n: int = counts.get(key, 0) + ch.alive
		counts[key] = n
		if n > best_n:
			best_n = n
			best_key = key
	if best_n == 0:
		return Vector3.INF
	return Vector3((best_key.x + 0.5) * cell, 0.0, (best_key.y + 0.5) * cell)


## Chão inclinado embaixo da formiga: o "para cima" segue a normal do chão.
## Com `i`, conta também a tampa fechada da câmara da formiga.
func _ground_basis(p: Vector3, a: float, i: int = -1) -> Basis:
	var e := 0.25
	var hx: float = (_surface(p.x + e, p.z) - _surface(p.x - e, p.z)) / (2.0 * e)
	var hz: float = (_surface(p.x, p.z + e) - _surface(p.x, p.z - e)) / (2.0 * e)
	var code := _chamber_of(i) if i >= 0 else -1
	if code >= 0:
		var n = world.nests[code / 16]
		var ci := code % 16
		var c2 := Vector2(p.x, p.z)
		var ec := 0.04
		hx += (n.cap_lift(ci, c2 + Vector2(ec, 0.0)) - n.cap_lift(ci, c2 - Vector2(ec, 0.0))) / (2.0 * ec)
		hz += (n.cap_lift(ci, c2 + Vector2(0.0, ec)) - n.cap_lift(ci, c2 - Vector2(0.0, ec))) / (2.0 * ec)
	var up := Vector3(-hx, 1.0, -hz).normalized()
	var fwd := Vector3(-sin(a), 0.0, -cos(a))
	fwd = (fwd - up * fwd.dot(up)).normalized()
	return Basis(fwd.cross(up), up, -fwd)


## Bater de asas da tanajura mais perto (até BUZZ_DIST metros), de vez em
## quando (não um zumbido contínuo), para avisar que ela está passando.
func _update_buzz(at: Vector3, delta: float) -> void:
	_buzz_wait -= delta
	if at == Vector3.INF or _buzz_wait > 0.0:
		return
	_buzz_wait = randf_range(BUZZ_EVERY.x, BUZZ_EVERY.y)
	if Sfx._quitting:
		return
	if _buzz == null:
		_buzz = AudioStreamPlayer3D.new()
		_buzz.stream = load("res://assets/audio/flutter.wav")
		_buzz.bus = "SFX"
		_buzz.volume_db = -12.0
		_buzz.unit_size = 3.0
		_buzz.max_distance = BUZZ_DIST
		_buzz.add_to_group("game_sound")
		add_child(_buzz)
	_buzz.global_position = at
	_buzz.pitch_scale = randf_range(0.9, 1.1)
	_buzz.play()


func _process(delta: float) -> void:
	if _mm.is_empty():
		return
	_counts.fill(0)
	var cam := cam_pos
	var lod0 := float(LOD_DISTS[0]) * LOD_DISTS[0]
	var lod1 := float(LOD_DISTS[1]) * LOD_DISTS[1]
	var lod2 := float(LOD_DISTS[2]) * LOD_DISTS[2]
	var far2 := DRAW_DIST * DRAW_DIST
	var tan_near2 := TANAJURA_NEAR * TANAJURA_NEAR
	var tilt2 := TILT_DIST * TILT_DIST
	var chamber_far2 := CHAMBER_DRAW_DIST * CHAMBER_DRAW_DIST
	var buzz_d2 := BUZZ_DIST * BUZZ_DIST
	var buzz_at := Vector3.INF
	for i in _top:
		if alive[i] == 0:
			continue
		var p := pos[i]
		var d2 := p.distance_squared_to(cam)
		if kind[i] == TANAJURA and d2 < buzz_d2:
			buzz_d2 = d2
			buzz_at = p
		if d2 > far2 or (d2 > chamber_far2 and mode[i] == Mode.CHAMBER):
			continue
		var k := kind[i]
		var layer := 0
		if k == QUEEN:
			layer = LAYER_QUEEN
		elif k == TANAJURA:
			layer = LAYER_TANAJURA if d2 < tan_near2 else LAYER_TANAJURA_FAR
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
		if k == WORKER and d2 < tilt2 and m != Mode.STUCK:
			basis = _ground_basis(p, yaw[i], i)
		if m == Mode.ENTER or m == Mode.EMERGE:
			# Mergulhando no buraco (cabeça para baixo) ou saindo dele (para cima).
			basis = basis * Basis(Vector3.RIGHT, pitch[i])
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
		buf[o + 15] = 0.5 if i == aim_target else 1.0
		buf[o + 16] = gait[i]
		buf[o + 17] = hl
		buf[o + 18] = state + 4.0 * seed_of[i]
		buf[o + 19] = float(carry[i])
	_update_buzz(buzz_at, delta)
	for layer in _mm.size():
		_mm[layer].buffer = _buf[layer]
		_mm[layer].visible_instance_count = _counts[layer]
	for j in _shadow_mm.size():
		var layer := _shadow_of[j]
		_shadow_mm[j].buffer = _buf[layer]
		_shadow_mm[j].visible_instance_count = _counts[layer]
