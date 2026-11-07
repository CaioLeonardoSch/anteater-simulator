extends CharacterBody3D
## O tamanduá-bandeira em primeira pessoa: anda, corre, fareja, lambe formigas
## com a língua comprida, cava formigueiros e bate no chão (com os upgrades).

signal ate(count: int, tanajuras: int, queens: int)
## Farejou: quantas formigas sentiu, se havia mais, a distância da mais perto
## (-1 = nenhuma) e quantas câmaras fechadas achou (Faro de Câmara).
signal sniffed(count: int, capped: bool, nearest: float, chambers: int)
signal dug(nest, chamber_index: int, released: int)
signal tremor_used(count: int)
signal queen_blocked
## Tentou lamber correndo sem ter aprendido Lamber Correndo.
signal lick_blocked_running
## Quebrou o tronco que fecha a passagem para a área 2 (fim da demo).
signal exit_broken

const SnoutBuilder := preload("res://scripts/player/snout_builder.gd")
const ModelLibrary := preload("res://scripts/model_library.gd")
const TONGUE_SHADER := preload("res://shaders/tongue.gdshader")

## O focinho é desenhado em escala reduzida bem perto da câmera: na tela fica
## idêntico, mas não atravessa o chão quando você olha para baixo.
const VIEW_SCALE := 0.25
## Altura dos olhos: alto o bastante para ver por cima do capim baixo.
const EYE_HEIGHT := 0.72
const GRAVITY := 20.0

enum Tongue { IDLE, OUT, BACK }

var world
var swarm
var colony
var controls_enabled := false
var bot := false

var head: Node3D
var camera: Camera3D
var viewmodel: Node3D
var snout_mi: MeshInstance3D
var arm_pivots: Array[Node3D] = []
var tongue_mi: MeshInstance3D
var tongue_mat: ShaderMaterial

var yaw := 0.0
var pitch := -0.12
var _sway := Vector2.ZERO

var t_state := Tongue.IDLE
var t_time := 0.0
var t_dur_out := 0.1
var t_dur_back := 0.14
var t_target := Vector3.ZERO
## Mira: a formiga que a língua vai buscar (Língua Certeira, ou -1) e se a
## lambida pega alguma formiga daqui.
var aim_ant := -1
var aim_hits := false
var t_tip := Vector3.ZERO
## Tanajura que a língua está indo buscar (a ponta acompanha ela), ou -1.
var t_follow := -1
var _path_tanajura := -1
var t_stuck := PackedInt32Array()
var _stuck_offsets: Array[Vector3] = []
var lick_cooldown := 0.0
## Clique guardado por um instante (sem a Lambida Contínua, cada clique é uma lambida).
var _lick_click := 0.0
var _blocked_note := 0.0

var sniff_cd := 0.0
var sniff_left := 0.0
var sniff_target := Vector3.INF
## Câmaras fechadas achadas pelo último faro (Faro de Câmara).
var sniff_chambers: Array[Vector3] = []
var tremor_cd := 0.0
## Descanso das garras depois de abrir uma câmara.
var dig_cd := 0.0
## Perto do tronco da saída (com a clareira limpa) e quanto dele já foi quebrado.
var near_exit := false
var exit_progress := 0.0
var _jump_request := false
var _stomp_pending := false
var _air_time := 0.0
var pull_time := 0.0
var dig_progress := 0.0
var _run_latch := false
var _dig_latch := false
var near_nest = null
## Câmara fechada ao alcance das garras (formigueiro + índice).
var dig_nest = null
var dig_chamber := -1
const DIG_REACH := 1.4
var arm_anim := 0.0
var _dig_swipe := 0.0
var _dig_sound := 0.0
var _tremor_anim := 0.0
var shake := 0.0
var _bob := 0.0
var _run_blend := 0.0
var _last_step_sign := 1.0
var running := false
## Estamina (ver GameState.stamina_*). -1 = começa cheia.
var stamina := -1.0
## Zerou a estamina: só volta a correr quando ela encher um pouco.
var exhausted := false
var _stamina_rest := 0.0

# Bot (teste automático)
var _bot_target := -1
## Alvo do bot entre as formigas do campo (trilhas e passeios): grupo e índice.
var _bot_field := Vector2i(-1, -1)
## Tempo desde a última formiga comida: se passar muito, o bot muda de alvo.
var _bot_hungry := 0.0
## Alvos que o bot desistiu de pegar (índice -> quando tentar de novo).
var _bot_skip := {}
## Quantos insetos estão no raio do Tremor (contado junto com a escolha do alvo).
var _bot_crowd := 0
var _bot_eaten := 0
var _bot_think := 0.0
var _bot_lick := false
var _bot_run := false
var _bot_input := Vector2.ZERO
var _bot_sniff := 0.0
var _bot_dig := false
var _bot_check := 1.2
var _bot_last_pos := Vector2.ZERO
var _bot_side := 1.0
var _bot_side_t := 0.0


func _ready() -> void:
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(55.0)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.0
	col.shape = cap
	col.position.y = 0.5
	add_child(col)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_HEIGHT
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = Settings.fov
	camera.near = 0.02
	camera.far = 1500.0
	head.add_child(camera)
	viewmodel = Node3D.new()
	viewmodel.name = "Viewmodel"
	viewmodel.scale = Vector3.ONE * VIEW_SCALE
	camera.add_child(viewmodel)
	var ai_snout := _ai_snout()
	if ai_snout:
		viewmodel.add_child(ai_snout)
	else:
		snout_mi = MeshInstance3D.new()
		snout_mi.name = "Snout"
		snout_mi.mesh = SnoutBuilder.build_snout()
		snout_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		viewmodel.add_child(snout_mi)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.2, -0.62, 0.05)
		viewmodel.add_child(pivot)
		var arm := MeshInstance3D.new()
		arm.mesh = SnoutBuilder.build_arm(side)
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(arm)
		pivot.visible = false
		arm_pivots.append(pivot)
	tongue_mat = ShaderMaterial.new()
	tongue_mat.shader = TONGUE_SHADER
	tongue_mi = MeshInstance3D.new()
	tongue_mi.name = "Tongue"
	tongue_mi.mesh = SnoutBuilder.build_tongue_mesh()
	tongue_mi.material_override = tongue_mat
	tongue_mi.top_level = true
	tongue_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tongue_mi.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 100, 400))
	tongue_mi.visible = false
	add_child(tongue_mi)
	Settings.changed.connect(func(): camera.fov = Settings.fov)


## Focinho gerado por IA (assets/models/tamandua_focinho.glb), se existir:
## o modelo deve apontar para -Z, com a boca na ponta da frente.
func _ai_snout() -> Node3D:
	var node := ModelLibrary.instantiate("tamandua_focinho", Vector3(0, 0, 0.62))
	if node == null:
		return null
	var box := ModelLibrary.compute_aabb(node)
	node.position += Vector3(0, SnoutBuilder.MOUTH.y - box.get_center().y, SnoutBuilder.MOUTH.z - box.position.z)
	_no_shadows(node)
	return node


func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadows(c)


func setup(w, sw, col_) -> void:
	world = w
	swarm = sw
	colony = col_


## Põe o tamanduá em pé nesse ponto (em cima do monte, se houver um ali).
func place_at(pos2: Vector2, yaw_value: float) -> void:
	global_position = Vector3(pos2.x, world.ground_height(pos2.x, pos2.y) + 0.05, pos2.y)
	yaw = yaw_value
	pitch = -0.12
	velocity = Vector3.ZERO
	rotation.y = yaw
	head.rotation.x = pitch


## O clique de lamber é lido antes da interface, para nenhum elemento da tela engolir o clique.
func _input(event: InputEvent) -> void:
	if controls_enabled and event.is_action_pressed("lick"):
		_lick_click = 0.3


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := Settings.mouse_sensitivity * 0.01
		var rel: Vector2 = event.relative
		yaw -= rel.x * sens
		pitch -= rel.y * sens * (-1.0 if Settings.invert_y else 1.0)
		pitch = clampf(pitch, deg_to_rad(-75.0), deg_to_rad(40.0))
		_sway += rel * 0.00035


# ------------------------------------------------------------- Movimento

func _physics_process(delta: float) -> void:
	if world == null:
		return
	var input := Vector2.ZERO
	var want_run := false
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		want_run = _run_held(input) and GameState.can_run()
		_update_dig_latch()
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		var gs := Settings.gamepad_sensitivity
		yaw -= look.x * delta * 2.6 * gs
		var inv := -1.0 if Settings.invert_y else 1.0
		pitch = clampf(pitch - look.y * delta * 2.0 * gs * inv, deg_to_rad(-75.0), deg_to_rad(40.0))
	elif bot:
		_bot_update(delta)
		input = _bot_input
		want_run = _bot_run and GameState.can_run()
	if exhausted or stamina == 0.0:
		want_run = false
	var digging := _is_digging() or _breaking_exit()
	var target_speed := GameState.run_speed() if want_run else GameState.walk_speed()
	if digging:
		target_speed = 0.0
	var wish := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var accel := 16.0 if wish.length() > 0.05 else 20.0
	hv = hv.move_toward(wish * target_speed, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = -0.5
		if _jump_request:
			# Pulo do Tremor: a pancada vem quando ele cai de volta no chão.
			velocity.y = GameState.tremor_jump_speed()
	else:
		velocity.y -= GRAVITY * delta
	_jump_request = false
	move_and_slide()
	if is_on_floor():
		if _stomp_pending and _air_time > 0.12:
			_stomp()
		_air_time = 0.0
	else:
		_air_time += delta
		if _stomp_pending and _air_time > 3.0:
			_stomp()
	# Os penhascos são o limite (dá para entrar na caverna e ir até o tronco).
	var flat := Vector2(global_position.x, global_position.z)
	var limit: float = world.walk_limit(flat)
	if flat.length() > limit:
		flat = flat.normalized() * limit
		global_position.x = flat.x
		global_position.z = flat.y
	var floor_y: float = world.ground_height(global_position.x, global_position.z)
	if global_position.y < floor_y - 0.6:
		global_position.y = floor_y + 0.2
		velocity.y = 0.0
	rotation.y = yaw
	head.rotation.x = pitch
	var spd := hv.length()
	running = want_run and spd > GameState.walk_speed() * 1.1
	_update_stamina(delta)
	if controls_enabled:
		var rv := get_real_velocity()
		GameState.count("distance", Vector2(rv.x, rv.z).length() * delta)
		if running:
			GameState.count("run_time", delta)
	swarm.threat_pos = global_position
	# Os insetos fogem a 1 m de você parado, a 2,5 m andando e mais longe
	# correndo (a língua alcança 3 m ou mais com Comprimento).
	var pace := spd / maxf(GameState.walk_speed(), 0.1)
	swarm.flee_radius = (1.0 + clampf(pace, 0.0, 1.0) * 1.5 + clampf(pace - 1.0, 0.0, 1.0) * 0.9) \
		* GameState.flee_multiplier(running)
	_update_aim()
	_update_tongue(delta)
	_update_abilities(delta)


func _process(delta: float) -> void:
	if world == null:
		return
	var spd := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and spd > 0.2:
		_bob += delta * (4.0 + spd * 1.6)
	# Balanço da cabeça: leve ao andar, um galope perceptível ao correr.
	_run_blend = move_toward(_run_blend, 1.0 if running else 0.0, delta * 3.0)
	var bob_k: float = Settings.camera_bob
	var amp := clampf(spd / 6.0, 0.0, 1.2) * 0.02 * (0.4 + 0.6 * bob_k)
	var gallop := _run_blend * bob_k
	amp += 0.035 * gallop
	head.position = Vector3(sin(_bob * 0.5) * amp * 0.7, EYE_HEIGHT + absf(sin(_bob)) * amp, 0.0)
	camera.rotation.z = sin(_bob * 0.5) * (amp * 0.25 + 0.014 * gallop)
	camera.rotation.x = (absf(cos(_bob)) - 0.5) * 0.022 * gallop
	var s := signf(sin(_bob))
	if s != _last_step_sign and spd > 0.4:
		Sfx.play("step", -14.0 + minf(spd, 6.0), 1.0, 0.15, 4)
	_last_step_sign = s
	if shake > 0.0:
		shake = maxf(shake - delta * 1.4, 0.0)
		camera.h_offset = randf_range(-1, 1) * shake * 0.03
		camera.v_offset = randf_range(-1, 1) * shake * 0.03
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	var fov_target := Settings.fov + (7.0 if running else 0.0)
	camera.fov = lerpf(camera.fov, fov_target, minf(delta * 6.0, 1.0))
	# Balanço do focinho.
	_sway = _sway.lerp(Vector2.ZERO, minf(delta * 8.0, 1.0))
	var lick_kick := 0.0
	if t_state == Tongue.OUT:
		lick_kick = 0.012
	viewmodel.position = Vector3(-_sway.x * 0.02 + sin(_bob * 0.5) * amp * 0.08,
		_sway.y * 0.02 - absf(sin(_bob)) * amp * 0.06, -lick_kick)
	viewmodel.rotation = Vector3(_sway.y * 0.25, -_sway.x * 0.25, 0.0)
	_update_arms(delta)
	_update_tongue_visual()
	world.follow_camera(camera.global_position)
	swarm.cam_pos = camera.global_position
	RenderingServer.global_shader_parameter_set("player_pos", global_position)


## Correr: segurando a tecla ou, com "Correr: Apertar" nas configurações,
## apertando uma vez (desliga ao apertar de novo ou ao parar de andar).
## Correndo gasta; sem correr, recupera depois de STAMINA_DELAY segundos.
func _update_stamina(delta: float) -> void:
	var top := GameState.stamina_max()
	if stamina < 0.0:
		stamina = top
	if running:
		stamina = maxf(stamina - GameState.stamina_drain() * delta, 0.0)
		_stamina_rest = 0.0
		if stamina <= 0.0:
			exhausted = true
	else:
		_stamina_rest += delta
		if _stamina_rest >= GameState.STAMINA_DELAY:
			stamina = minf(stamina + GameState.stamina_regen() * delta, top)
	stamina = minf(stamina, top)
	if exhausted and stamina >= top * GameState.STAMINA_RESUME:
		exhausted = false


func _run_held(input: Vector2) -> bool:
	if not Settings.run_toggle:
		_run_latch = false
		return Input.is_action_pressed("run")
	if Input.is_action_just_pressed("run"):
		_run_latch = not _run_latch
	if input.length() < 0.1:
		_run_latch = false
	return _run_latch


## Cavar com "Cavar: Apertar": um toque começa e as garras seguem até abrir
## (ou até você se afastar, ou apertar de novo).
func _update_dig_latch() -> void:
	if not Settings.dig_toggle:
		_dig_latch = false
		return
	if Input.is_action_just_pressed("dig"):
		_dig_latch = not _dig_latch
	if dig_nest == null and not near_exit:
		_dig_latch = false


func _dig_held() -> bool:
	return _dig_latch if Settings.dig_toggle else Input.is_action_pressed("dig")


## Quebrando o tronco da saída com as garras (só com a clareira 100% limpa).
func _breaking_exit() -> bool:
	if not near_exit or not GameState.can_dig():
		return false
	if controls_enabled:
		return _dig_held()
	return false


func _is_digging() -> bool:
	if dig_nest == null or dig_chamber < 0 or not GameState.can_dig() or dig_cd > 0.0:
		return false
	# Buraco grande demais para o nível de Cavar que você tem.
	if GameState.dig_level() < dig_nest.chambers[dig_chamber].size_class:
		return false
	if controls_enabled:
		return _dig_held()
	return bot and _bot_dig


# ------------------------------------------------------------- Língua

func mouth_real() -> Vector3:
	return camera.global_transform * SnoutBuilder.MOUTH


func mouth_view() -> Vector3:
	return viewmodel.global_transform * SnoutBuilder.MOUTH


func _wants_lick() -> bool:
	if controls_enabled:
		if GameState.lick_hold() and Input.is_action_pressed("lick"):
			return true
		return _lick_click > 0.0
	return bot and _bot_lick


## Correndo, só dá para lamber com Lamber Correndo.
func _lick_blocked() -> bool:
	return running and not GameState.can_lick_running()


func _update_tongue(delta: float) -> void:
	lick_cooldown -= delta
	_lick_click = maxf(_lick_click - delta, 0.0)
	_blocked_note = maxf(_blocked_note - delta, 0.0)
	if t_state == Tongue.IDLE and lick_cooldown <= 0.0 and _wants_lick() and not _is_digging():
		if _lick_blocked():
			_lick_click = 0.0
			if _blocked_note <= 0.0:
				_blocked_note = 6.0
				lick_blocked_running.emit()
		else:
			_lick_click = 0.0
			_start_flick()
	match t_state:
		Tongue.OUT:
			t_time += delta
			# A tanajura foge rápido: a ponta vai atrás dela até alcançar.
			if t_follow >= 0 and swarm.alive[t_follow] == 1 and swarm.mode[t_follow] != swarm.Mode.STUCK:
				t_target = swarm.body_point(t_follow)
			var k := clampf(t_time / t_dur_out, 0.0, 1.0)
			t_tip = mouth_view().lerp(t_target, 1.0 - pow(1.0 - k, 3.0))
			if k >= 1.0:
				_capture()
				t_state = Tongue.BACK
				t_time = 0.0
		Tongue.BACK:
			t_time += delta
			var k := clampf(t_time / t_dur_back, 0.0, 1.0)
			t_tip = t_target.lerp(mouth_view(), k * k)
			_carry_stuck()
			if k >= 1.0:
				_swallow()
				t_state = Tongue.IDLE


func _start_flick() -> void:
	var period := 1.0 / GameState.lick_rate()
	lick_cooldown = period
	t_dur_out = period * 0.36
	t_dur_back = period * 0.5
	var target := _straight_target()
	t_follow = _path_tanajura
	# Língua Certeira: a ponta vai atrás da formiga mais perto da mira.
	var ant := _tracked_ant()
	if ant >= 0:
		target = swarm.pos[ant] + Vector3(0, 0.02, 0)
		t_follow = ant if swarm.kind[ant] == swarm.TANAJURA else -1
	t_target = target
	t_state = Tongue.OUT
	t_time = 0.0
	GameState.count("licks")
	Sfx.play("tongue", -7.0, 1.0, 0.12)


## Onde a língua chega indo reta: no chão (ou no monte) para onde você mira,
## no máximo até o alcance dela; ou numa tanajura voando no caminho.
func _straight_target() -> Vector3:
	var cam_t := camera.global_transform
	var origin := cam_t.origin
	var fwd := -cam_t.basis.z
	var mouth := mouth_real()
	var reach := GameState.tongue_range()
	var q := PhysicsRayQueryParameters3D.create(origin, origin + fwd * (reach + 1.0))
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var target := origin + fwd * (reach + 0.5)
	if not hit.is_empty():
		target = hit.position
	var off := target - mouth
	if off.length() > reach:
		target = mouth + off.normalized() * reach
	# Tanajura voando no caminho: a língua para nela (e não no chão atrás).
	_path_tanajura = swarm.tanajura_on_path(origin, target, GameState.capture_radius())
	if _path_tanajura >= 0:
		target = swarm.body_point(_path_tanajura)
	return target


## Com Língua Certeira, a formiga que a língua vai buscar (ou -1).
func _tracked_ant() -> int:
	if not GameState.tongue_tracking():
		return -1
	var cam_t := camera.global_transform
	var reach := GameState.tongue_range()
	var best: int = swarm.best_target(cam_t.origin, -cam_t.basis.z, reach + 0.7, cos(deg_to_rad(GameState.aim_cone_deg())))
	if best >= 0 and swarm.pos[best].distance_to(mouth_real()) > reach + 0.2:
		return -1
	return best


## Para a mira da tela: a formiga que a língua vai buscar e se a lambida pega alguma.
func _update_aim() -> void:
	aim_ant = _tracked_ant()
	swarm.aim_target = aim_ant
	if aim_ant >= 0:
		aim_hits = true
	else:
		aim_hits = swarm.any_near(_straight_target(), GameState.capture_radius())


func _capture() -> void:
	var res: Dictionary = swarm.lick(t_target, GameState.capture_radius(), GameState.lick_capacity())
	t_stuck = res.captured
	_stuck_offsets.clear()
	for i in t_stuck.size():
		_stuck_offsets.append(Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)) * 0.04)
	if res.queen_protected and t_stuck.is_empty():
		queen_blocked.emit()
		Sfx.play("deny", -8.0)
	if t_stuck.size() > 0:
		GameState.count("licks_hit")
		Sfx.play("slurp", -4.0, 1.0, 0.1)


func _carry_stuck() -> void:
	var cam := camera.global_position
	var shrink := clampf(t_tip.distance_to(cam) / 0.9, 0.12, 1.0)
	for k in t_stuck.size():
		var i := t_stuck[k]
		swarm.pos[i] = t_tip + _stuck_offsets[k] * shrink - Vector3(0, 0.02, 0) * shrink
		swarm.shrink[i] = shrink


func _swallow() -> void:
	var n := t_stuck.size()
	if n == 0:
		return
	var taj := 0
	var queens := 0
	var value := 0
	for i in t_stuck:
		if swarm.kind[i] == swarm.TANAJURA:
			taj += 1
		elif swarm.kind[i] == swarm.QUEEN:
			queens += 1
		value += colony.ant_eaten(i)
		swarm.despawn(i)
	t_stuck = PackedInt32Array()
	GameState.add_eaten(value, taj, queens)
	ate.emit(value, taj, queens)
	Sfx.play("munch", -3.0 + minf(n, 8) * 0.5, 1.0, 0.1, 3)
	if taj > 0:
		Sfx.play("frenzy", -2.0)
	if queens > 0:
		Sfx.play("queen", 0.0)


func _update_tongue_visual() -> void:
	if t_state == Tongue.IDLE:
		tongue_mi.visible = false
		return
	tongue_mi.visible = true
	tongue_mi.global_transform = Transform3D.IDENTITY
	var p0 := mouth_view()
	var p3 := t_tip
	var length := p0.distance_to(p3)
	var sdir := (camera.global_transform.basis * SnoutBuilder.SNOUT_DIR).normalized()
	var p1 := p0 + sdir * length * 0.3
	var p2 := p3.lerp(p0, 0.3) + Vector3(0, 0.05 * length, 0)
	tongue_mat.set_shader_parameter("p0", p0)
	tongue_mat.set_shader_parameter("p1", p1)
	tongue_mat.set_shader_parameter("p2", p2)
	tongue_mat.set_shader_parameter("p3", p3)
	tongue_mat.set_shader_parameter("r0", 0.0032)
	tongue_mat.set_shader_parameter("r1", 0.0095)
	tongue_mat.set_shader_parameter("wobble", 1.0 if t_state == Tongue.BACK else 0.3)


# ------------------------------------------------------------- Habilidades

func _update_abilities(delta: float) -> void:
	sniff_cd = maxf(sniff_cd - delta, 0.0)
	tremor_cd = maxf(tremor_cd - delta, 0.0)
	dig_cd = maxf(dig_cd - delta, 0.0)
	if sniff_left > 0.0:
		sniff_left -= delta
		world.scent_marks.set_fade(clampf(sniff_left / 0.8, 0.0, 1.0))
		if sniff_left <= 0.0:
			swarm.set_scent_overlay(false)
			sniff_target = Vector3.INF
			sniff_chambers.clear()
			world.scent_marks.set_fade(0.0)
	RenderingServer.global_shader_parameter_set("sniff_amount", clampf(sniff_left / 0.8, 0.0, 1.0))
	var want_sniff := controls_enabled and Input.is_action_just_pressed("sniff")
	if bot:
		_bot_sniff -= delta
		if _bot_sniff <= 0.0:
			_bot_sniff = 14.0
			want_sniff = true
	if want_sniff and sniff_cd <= 0.0 and GameState.can_sniff():
		do_sniff()
	# Formigueiro mais perto (para as dicas) e câmara fechada ao alcance das
	# garras (no monte ou no meio do campo).
	near_nest = null
	var p2 := Vector2(global_position.x, global_position.z)
	for n in world.nests:
		if p2.distance_to(n.center2) < n.radius + 2.0:
			near_nest = n
			break
	var prev_nest = dig_nest
	var prev_chamber := dig_chamber
	dig_nest = null
	dig_chamber = -1
	var best_reach := DIG_REACH
	for n in world.nests:
		var ci: int = n.closed_chamber_near(p2, best_reach)
		if ci >= 0:
			dig_nest = n
			dig_chamber = ci
			best_reach = n.chambers[ci].edge_distance(p2)
	if prev_nest != null and (prev_nest != dig_nest or prev_chamber != dig_chamber):
		prev_nest.reset_dig(prev_chamber)
		dig_progress = 0.0
	if _is_digging():
		dig_progress += delta / GameState.dig_time()
		_dig_swipe += delta * 11.0
		_dig_sound -= delta
		if _dig_sound <= 0.0:
			_dig_sound = 0.18
			Sfx.play("dig", -6.0, 1.0, 0.2)
		dig_nest.set_dig_progress(dig_chamber, dig_progress)
		if dig_progress >= 1.0:
			dig_progress = 0.0
			var opened_nest = dig_nest
			var opened_chamber := dig_chamber
			var released: int = colony.open_chamber(opened_nest, opened_chamber, false, GameState.dig_stun_time())
			dig_cd = GameState.dig_cooldown()
			_dig_latch = false
			shake = 0.5
			Sfx.play("burst", -2.0)
			dug.emit(opened_nest, opened_chamber, released)
	elif dig_progress > 0.0:
		dig_progress = maxf(dig_progress - delta * 2.0, 0.0)
		if dig_nest != null:
			dig_nest.set_dig_progress(dig_chamber, dig_progress)
			if dig_progress <= 0.0:
				dig_nest.reset_dig(dig_chamber)
	# Tronco da saída: com a clareira limpa, segurar E perto dele quebra o tronco.
	near_exit = world.exit_breakable and not world.exit_open and world.near_exit(p2, 2.4)
	if _breaking_exit():
		exit_progress += delta / 1.6
		_dig_swipe += delta * 11.0
		_dig_sound -= delta
		if _dig_sound <= 0.0:
			_dig_sound = 0.16
			Sfx.play("dig", -5.0, 0.8, 0.2)
		if exit_progress >= 1.0:
			exit_progress = 0.0
			world.break_exit()
			shake = 0.9
			Sfx.play("crack", 0.0)
			exit_broken.emit()
	else:
		exit_progress = maxf(exit_progress - delta * 2.0, 0.0)
	var want_tremor := controls_enabled and Input.is_action_just_pressed("tremor")
	if bot and GameState.can_tremor() and tremor_cd <= 0.0:
		# Tremor quando vale a pena: um bolo de insetos em volta, ou o alvo
		# fugindo perto.
		var fleeing: bool = _bot_target >= 0 and swarm.alive[_bot_target] == 1 \
			and swarm.mode[_bot_target] == swarm.Mode.FLEE \
			and swarm.pos[_bot_target].distance_to(global_position) < GameState.tremor_radius() * 0.7
		want_tremor = _bot_crowd >= BOT_TREMOR_CROWD or fleeing
		if want_tremor:
			_bot_crowd = 0
	if want_tremor and GameState.can_tremor() and tremor_cd <= 0.0 and is_on_floor():
		do_tremor()
	if pull_time > 0.0:
		pull_time -= delta
		swarm.pull_target = mouth_real() + Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.6)
	else:
		swarm.pull_target = Vector3.INF
	_tremor_anim = maxf(_tremor_anim - delta * 2.5, 0.0)


func do_sniff() -> void:
	sniff_cd = GameState.sniff_cooldown()
	sniff_left = GameState.sniff_duration()
	var precision := GameState.sniff_precision()
	var res: Dictionary = swarm.sniff(global_position, GameState.sniff_radius(), GameState.sniff_max_ants(),
		sniff_left, precision >= 2)
	# Faro Nítido: as formigas farejadas brilham através do capim.
	swarm.set_scent_overlay(precision >= 2)
	sniff_target = Vector3.INF
	var points: PackedVector3Array = res.points
	if not points.is_empty():
		# A bússola aponta o maior grupo desde o Farejar. Faro Preciso: nuvens
		# borradas onde elas estão (com o Faro Nítido, as próprias formigas
		# brilham no lugar da nuvem).
		if precision == 1:
			world.scent_marks.show_clouds(points)
		var groups: Array = world.scent_marks.clusters(points)
		sniff_target = groups[0].center
	sniff_chambers.clear()
	if GameState.sniff_chambers():
		# Faro de Câmara: colunas de cheiro nas câmaras fechadas por perto.
		var reach := maxf(GameState.sniff_radius() * 1.5, 20.0)
		var here := Vector2(global_position.x, global_position.z)
		for n in world.nests:
			for c in n.chambers:
				if not c.opened and here.distance_to(c.pos2) <= reach:
					sniff_chambers.append(n.chamber_world_pos(c))
		world.scent_marks.show_pillars(sniff_chambers)
	GameState.count("sniffs")
	Sfx.play("sniff", -3.0)
	sniffed.emit(res.count, res.capped, res.nearest, sniff_chambers.size())


## Tremor: um pulo; a pancada (formigas tontas) vem quando ele cai no chão.
func do_tremor() -> void:
	tremor_cd = GameState.tremor_cooldown()
	_jump_request = true
	_stomp_pending = true
	GameState.count("tremors")
	Sfx.play("step", -4.0, 0.7)


func _stomp() -> void:
	_stomp_pending = false
	var n: int = swarm.stun_radius(global_position, GameState.tremor_radius(), 3.0)
	if GameState.tremor_pulls():
		pull_time = 2.4
	shake = 1.0
	_tremor_anim = 1.0
	Sfx.play("tremor", 0.0)
	_dust_ring(GameState.tremor_radius())
	tremor_used.emit(n)


## Poeira que sobe em volta quando ele cai com força.
func _dust_ring(radius: float) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = 64
	p.lifetime = 1.0
	p.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.6
	pm.emission_ring_inner_radius = 0.3
	pm.emission_ring_height = 0.05
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.8
	pm.radial_velocity_min = radius * 0.45
	pm.radial_velocity_max = radius * 0.7
	pm.damping_min = 2.0
	pm.damping_max = 3.0
	pm.gravity = Vector3(0, -2.5, 0)
	pm.scale_min = 0.8
	pm.scale_max = 1.8
	var fade := Gradient.new()
	fade.set_color(0, Color(0.72, 0.5, 0.34, 0.8))
	fade.set_color(1, Color(0.72, 0.5, 0.34, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 8
	mesh.rings = 4
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	mesh.material = m
	p.draw_pass_1 = mesh
	world.add_child(p)
	p.global_position = global_position + Vector3(0, 0.05, 0)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _update_arms(delta: float) -> void:
	var working := _is_digging() or _breaking_exit()
	var target := 1.0 if (working or _tremor_anim > 0.0) else 0.0
	arm_anim = move_toward(arm_anim, target, delta * 6.0)
	for k in arm_pivots.size():
		var pivot := arm_pivots[k]
		pivot.visible = arm_anim > 0.01
		var side := -1.0 if k == 0 else 1.0
		var swipe := sin(_dig_swipe + k * PI) * 0.35 if working else -_tremor_anim * 0.5
		pivot.rotation = Vector3(lerpf(-1.4, 0.15, arm_anim) + swipe * arm_anim, side * 0.15, side * 0.1)


# ------------------------------------------------------------- Bot de teste

## O bot usa o Tremor quando tem pelo menos isso de insetos no raio dele.
const BOT_TREMOR_CROWD := 12


func _bot_update(delta: float) -> void:
	_bot_think -= delta
	if GameState.ants_eaten != _bot_eaten:
		_bot_eaten = GameState.ants_eaten
		_bot_hungry = 0.0
	else:
		_bot_hungry += delta
	var field = swarm.field
	var field_pos := Vector3.INF
	if _bot_field.x >= 0:
		var st: Vector4 = field.ant_state(field.chunks[_bot_field.x], _bot_field.y)
		if st.w != INF:
			field_pos = Vector3(st.x, st.y, st.z)
	var lost: bool = _bot_target >= 0 and (swarm.alive[_bot_target] == 0 or swarm.mode[_bot_target] == swarm.Mode.STUCK)
	if _bot_hungry > 20.0:
		# Muito tempo sem comer: larga o alvo e dá uns passos para o lado.
		print("[bot] sem comer: pos=%s alvo=%d (tipo %d, modo %d) campo=%s alvo_pos=%s" % [global_position.snapped(Vector3.ONE * 0.1),
			_bot_target, swarm.kind[_bot_target] if _bot_target >= 0 else -1, swarm.mode[_bot_target] if _bot_target >= 0 else -1,
			_bot_field, (swarm.pos[_bot_target] if _bot_target >= 0 else field_pos).snapped(Vector3.ONE * 0.1)])
		if _bot_target >= 0:
			_bot_skip[_bot_target] = GameState.elapsed + 60.0
		elif _bot_field.x >= 0:
			_bot_skip[Vector2i(_bot_field)] = GameState.elapsed + 60.0
		_bot_hungry = 0.0
		lost = true
		_bot_side = -1.0 if randf() < 0.5 else 1.0
		_bot_side_t = 2.5
	# Alvo do campo sumiu (entrou no buraco): escolhe outro logo, mas sem
	# refazer a busca toda a cada quadro.
	var gone: bool = _bot_target < 0 and field_pos == Vector3.INF and _bot_think < 0.45
	if _bot_think <= 0.0 or lost or gone:
		_bot_think = 0.6
		_bot_pick_target(field)
		field_pos = Vector3.INF
		if _bot_field.x >= 0:
			var st: Vector4 = field.ant_state(field.chunks[_bot_field.x], _bot_field.y)
			field_pos = Vector3(st.x, st.y, st.z)
	_bot_lick = false
	_bot_input = Vector2.ZERO
	_bot_run = false
	if _bot_side_t > 0.0 and _bot_hungry < 3.0:
		# Acabou de desistir de um alvo: anda um pouco de lado antes de seguir.
		_bot_side_t -= delta
		_bot_input = Vector2(_bot_side, -0.3).normalized()
		return
	_bot_dig = dig_nest != null and GameState.can_dig() and dig_cd <= 0.0
	if _bot_dig:
		return
	var goal := Vector3.INF
	var to_chamber := false
	if _bot_target >= 0:
		goal = swarm.pos[_bot_target]
	elif field_pos != Vector3.INF:
		goal = field_pos + Vector3(0, 0.04, 0)
	if GameState.can_dig() and dig_cd <= 0.0:
		var ch := _bot_nearest_closed_chamber()
		if ch != Vector3.INF and (goal == Vector3.INF or ch.distance_to(global_position) + 10.0 < goal.distance_to(global_position)):
			goal = ch
			to_chamber = true
	if goal == Vector3.INF:
		return
	# Anda até o alvo (dá para subir nos montes) e mira na formiga.
	var move_goal := goal
	var cam_pos := camera.global_position
	var to_goal := goal - cam_pos
	var dist := Vector2(to_goal.x, to_goal.z).length()
	var reach := GameState.tongue_range()
	# Errando de longe faz tempo: chega bem perto antes de lamber de novo.
	var near := 0.9 if _bot_hungry > 6.0 else reach * 0.75
	var moving := to_chamber or dist > near
	var aim := move_goal if moving else goal
	var to := aim - cam_pos
	var flat_d := maxf(Vector2(to.x, to.z).length(), 0.01)
	var want_yaw := atan2(-to.x, -to.z)
	yaw = lerp_angle(yaw, want_yaw, minf(delta * 6.0, 1.0))
	var want_pitch := atan2(to.y, flat_d) if not moving else -0.15
	pitch = lerpf(pitch, clampf(want_pitch, deg_to_rad(-70.0), deg_to_rad(30.0)), minf(delta * 6.0, 1.0))
	if moving:
		if Vector2(move_goal.x - global_position.x, move_goal.z - global_position.z).length() > 0.25:
			_bot_input = Vector2(0, -1)
			# Correr assusta os insetos (menos com Corrida nível 3): sem ela,
			# só corre para longe; com ela, corre até perto do alvo.
			_bot_run = dist > (3.0 if GameState.has("patas_corrida_3") else 9.0)
			_bot_unstuck(delta)
		# Já ao alcance da língua: lambe andando (ou correndo, com Lamber Correndo).
		if not to_chamber and dist <= reach and (not _bot_run or GameState.can_lick_running()):
			_bot_lick = absf(angle_difference(yaw, want_yaw)) < 0.25
	else:
		_bot_lick = absf(angle_difference(yaw, want_yaw)) < 0.25


## Escolhe a formiga mais perto: entre as soltas (fugindo, das câmaras,
## rainhas, tanajuras) e as do campo (trilhas e passeios).
func _bot_pick_target(field) -> void:
	_bot_target = -1
	_bot_field = Vector2i(-1, -1)
	if GameState.can_tremor() and tremor_cd <= 0.0:
		var found: Array[Vector4] = []
		field.gather(global_position, GameState.tremor_radius() * 0.8, found)
		_bot_crowd = found.size()
	for k in _bot_skip.keys():
		if GameState.elapsed >= _bot_skip[k]:
			_bot_skip.erase(k)
	var best := INF
	var reach2 := GameState.tongue_range() * GameState.tongue_range()
	for i in swarm.CAPACITY:
		if swarm.alive[i] == 0 or swarm.mode[i] == swarm.Mode.STUCK or swarm._queen_blocked(i) or _bot_skip.has(i):
			continue
		var d: float = swarm.pos[i].distance_squared_to(global_position)
		# Tanajura voando foge mais rápido que o tamanduá andando: só vale
		# mirar nela quando ela passa perto.
		if swarm.kind[i] == swarm.TANAJURA and d > reach2:
			continue
		if d < best:
			best = d
			_bot_target = i
	# Campo: primeiro o grupo mais perto (pela trilha ou pela câmara do passeio),
	# depois a formiga mais perto dentro dele.
	var me := Vector2(global_position.x, global_position.z)
	var best_ci := -1
	var best_cd := INF
	for ci in field.chunks.size():
		var ch = field.chunks[ci]
		if ch.alive <= 0:
			continue
		var cd := INF
		if ch.kind == field.TRAIL:
			for p in ch.trail.points:
				cd = minf(cd, p.distance_squared_to(me))
		else:
			cd = ch.home.distance_squared_to(me)
		if cd < best_cd:
			best_cd = cd
			best_ci = ci
	if best_ci < 0 or best_cd > best:
		return
	var ch = field.chunks[best_ci]
	var fbest := INF
	for i in ch.count:
		var p: Vector2 = field.ant_xz(ch, i)
		if p == Vector2.INF or _bot_skip.has(Vector2i(best_ci, i)):
			continue
		var d := p.distance_squared_to(me)
		if d < fbest:
			fbest = d
			_bot_field = Vector2i(best_ci, i)
	if _bot_field.x >= 0 and fbest < best:
		_bot_target = -1
	else:
		_bot_field = Vector2i(-1, -1)


## Se ficar preso numa árvore ou pedra, dá um passo de lado por um tempo.
func _bot_unstuck(delta: float) -> void:
	_bot_check -= delta
	if _bot_side_t > 0.0:
		_bot_side_t -= delta
		_bot_input = Vector2(_bot_side, -0.6).normalized()
		return
	if _bot_check <= 0.0:
		_bot_check = 1.2
		var moved := Vector2(global_position.x, global_position.z).distance_to(_bot_last_pos)
		_bot_last_pos = Vector2(global_position.x, global_position.z)
		if moved < 0.5:
			_bot_side = -1.0 if randf() < 0.5 else 1.0
			_bot_side_t = 1.4


func _bot_nearest_closed_chamber() -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for n in world.nests:
		for c in n.chambers:
			if c.opened or GameState.dig_level() < c.size_class:
				continue
			var p: Vector3 = n.chamber_world_pos(c)
			var d := p.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = p
	return best
