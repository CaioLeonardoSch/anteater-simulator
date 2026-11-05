extends Node
## Ponto de entrada da demo. Monta o mundo, o enxame, o tamanduá e a interface,
## e controla os estados: menu inicial, jogando, pausa, árvore de habilidades e fim.

const World := preload("res://scripts/world/world.gd")
const Swarm := preload("res://scripts/ants/ant_swarm.gd")
const Colony := preload("res://scripts/ants/colony.gd")
const Player := preload("res://scripts/player/anteater.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const TabMenu := preload("res://scripts/ui/tab_menu.gd")
const Exploration := preload("res://scripts/world/exploration.gd")
const Menus := preload("res://scripts/ui/menus.gd")
const ModelLibrary := preload("res://scripts/model_library.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const SnoutBuilder := preload("res://scripts/player/snout_builder.gd")
const AntMeshBuilder := preload("res://scripts/ants/ant_mesh_builder.gd")
const Props := preload("res://scripts/world/props.gd")

enum State { LOADING, MENU, PLAYING, PAUSED, TREE, COMPLETE }

## Ao recomeçar, pula o menu e vai direto para um jogo novo.
static var skip_menu := false
const AUTOSAVE_EVERY := 30.0
## Ordem em que o bot de teste aprende as habilidades (junta pontos para a próxima).
const BOT_ORDER := ["lingua_segurar", "faro_farejar", "garras_cavar", "lingua_bocado_1", "garras_fundo", "patas_corrida",
	"garras_ageis", "faro_preciso", "lingua_bocado_2", "lingua_comprida", "garras_fortes", "faro_atento",
	"patas_lamber", "lingua_bocado_3", "lingua_saliva", "garras_incansaveis", "garras_tremor", "faro_nitido",
	"garras_real", "faro_apurado", "faro_camara", "lingua_turbo", "lingua_bocado_4", "patas_ligeiras", "garras_terremoto",
	"faro_agucado", "garras_recarga", "patas_galope", "faro_lendario", "garras_recarga_2"]

var state := State.LOADING
var world: World
var swarm: Swarm
var colony: Colony
var player: Player
var menu_cam: Camera3D
var ui: CanvasLayer
var hud: Hud
## Tela do TAB (mapa e árvore de habilidades).
var tab_ui: TabMenu
var exploration: Exploration
var menus: Menus
var fade: ColorRect

var _menu_t := 0.0
var _menu_center := Vector3.ZERO
var _complete_wait := -1.0
var _base_time_scale := 1.0
var _new_record := false
var _reloading := false
var _autosave := AUTOSAVE_EVERY


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_base_time_scale = Engine.time_scale
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	menus = Menus.new()
	ui.add_child(menus)
	menus.show_screen("loading")
	Settings.changed.connect(_apply_hud_visibility)
	fade = ColorRect.new()
	fade.color = Color(0.06, 0.03, 0.02, 1.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := CanvasLayer.new()
	top.layer = 20
	add_child(top)
	top.add_child(fade)
	fade.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	_build_game()
	if DevTools.start_mode == "continue":
		_continue_game()
	elif DevTools.start_mode == "settings":
		_enter_menu()
		menus.open_settings(int(DevTools.args.get("tab", "0")))
	elif DevTools.start_mode == "howto":
		_enter_menu()
		menus.show_screen("howto")
	elif skip_menu or DevTools.start_mode != "":
		skip_menu = false
		_start_play()
		if DevTools.start_mode == "tree":
			_open_tree(TabMenu.SKILLS)
		elif DevTools.start_mode == "map":
			_open_tree(TabMenu.MAP)
	else:
		_enter_menu()
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.8)


func _build_game() -> void:
	world = World.new()
	world.name = "World"
	# O Main roda sempre (menus), mas o mundo, as formigas e o tamanduá param na pausa.
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.build()
	swarm = Swarm.new()
	swarm.name = "Swarm"
	swarm.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(swarm)
	colony = Colony.new()
	colony.name = "Colony"
	colony.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(colony)
	swarm.setup(world, colony)
	colony.setup(world, swarm)
	colony.active = true
	player = Player.new()
	player.name = "Anteater"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.setup(world, swarm, colony)
	player.place_at(world.player_start, world.player_start_yaw)
	player.exit_broken.connect(_on_exit_broken)
	menu_cam = Camera3D.new()
	menu_cam.name = "MenuCamera"
	menu_cam.fov = 62.0
	menu_cam.near = 0.03
	add_child(menu_cam)
	var t = world.trails.trails[world.start_trail_index]
	var c2: Vector2 = t.point_at(t.length * 0.62)
	_menu_center = Vector3(c2.x, world.ground_height(c2.x, c2.y), c2.y)
	# Tamanduá de corpo inteiro (modelo de IA opcional) posando no menu.
	var showcase := ModelLibrary.instantiate("tamandua", Vector3(2.2, 0, 2.2))
	if showcase:
		var sp := _menu_center + Vector3(1.4, 0, 1.0)
		sp.y = world.ground_height(sp.x, sp.z)
		showcase.position = sp
		showcase.rotation.y = 0.8
		world.add_child(showcase)
	hud = Hud.new()
	ui.add_child(hud)
	hud.setup(player, swarm, colony, world)
	hud.visible = false
	exploration = Exploration.new()
	exploration.name = "Exploration"
	exploration.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(exploration)
	exploration.setup(player)
	tab_ui = TabMenu.new()
	ui.add_child(tab_ui)
	tab_ui.setup(player, world, colony, exploration)
	tab_ui.visible = false
	tab_ui.closed.connect(_close_tree)
	# Foto da clareira vista de cima para o mapa (enquanto a tela ainda está escura).
	tab_ui.map_view.take_shot()
	ui.move_child(menus, -1)
	menus.play_pressed.connect(_on_play_pressed)
	menus.continue_pressed.connect(_on_continue_pressed)
	menus.resume_pressed.connect(_resume)
	menus.restart_pressed.connect(_restart)
	menus.main_menu_pressed.connect(_to_main_menu)
	menus.skill_tree_pressed.connect(_open_tree.bind(TabMenu.SKILLS))
	GameState.level_completed.connect(_on_complete)
	GameState.ants_eaten_changed.connect(_on_eaten_changed)
	Settings.changed.connect(world.apply_graphics)
	Settings.changed.connect(_apply_sniff_color)
	_apply_sniff_color()
	Sfx.start_ambience()
	Sfx.start_music()


func _apply_sniff_color() -> void:
	swarm.set_sniff_color(Settings.sniff_color())
	world.scent_marks.set_color(Settings.sniff_color())


## A interface some com "Mostrar a interface" desligado (ou --nohud nos testes).
func _apply_hud_visibility() -> void:
	if state == State.PLAYING or state == State.TREE or state == State.PAUSED:
		hud.visible = Settings.show_hud and not DevTools.args.has("nohud")


func _enter_menu() -> void:
	state = State.MENU
	GameState.playing = false
	get_tree().paused = false
	menu_cam.current = true
	hud.visible = false
	player.controls_enabled = false
	menus.show_screen("title")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.set_music_duck(0.0)


func _on_play_pressed() -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.35)
	tw.tween_callback(_start_play)
	tw.tween_property(fade, "modulate:a", 0.0, 0.6)


func _on_continue_pressed() -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.35)
	tw.tween_callback(_continue_game)
	tw.tween_property(fade, "modulate:a", 0.0, 0.6)


## Jogo novo.
func _start_play() -> void:
	GameState.reset_run()
	player.place_at(world.player_start, world.player_start_yaw)
	_begin_playing()
	save_game()
	# Ele acorda na caverna com fome: a barriga ronca uma vez.
	if DevTools.start_mode == "" or DevTools.args.has("growl"):
		get_tree().create_timer(1.4).timeout.connect(_belly_growl)
	if DevTools.give > 0:
		GameState.add_eaten(DevTools.give * GameState.ANTS_PER_POINT)
		GameState.combo = 0
		GameState.best_combo = 0
	for id in DevTools.buy:
		GameState.grant(id)
	if DevTools.pose.size() >= 4:
		player.place_at(Vector2(DevTools.pose[0], DevTools.pose[1]), deg_to_rad(DevTools.pose[2]))
		player.pitch = deg_to_rad(DevTools.pose[3])
	if DevTools.args.has("sniff"):
		# Teste: fareja sozinho nesse instante (para capturas do faro).
		get_tree().create_timer(float(DevTools.args.sniff)).timeout.connect(player.do_sniff)
	if DevTools.args.has("open"):
		# Teste: abre todas as câmaras de um formigueiro (ou de todos, com --open=all).
		for nest in world.nests:
			if DevTools.args.open == "all" or nest.index == int(DevTools.args.open):
				for ci in nest.chambers.size():
					colony.open_chamber(nest, ci)


## Continua o jogo salvo (ou começa um novo, se não houver).
func _continue_game() -> void:
	var data := GameState.read_saved_game()
	if data.is_empty():
		_start_play()
		return
	GameState.reset_run()
	GameState.from_save(data.get("state", {}))
	colony.from_save(data.get("colony", {}))
	exploration.from_save(String(data.get("explored", "")))
	var p: Dictionary = data.get("player", {})
	player.place_at(Vector2(float(p.get("x", world.player_start.x)), float(p.get("z", world.player_start.y))),
		float(p.get("yaw", world.player_start_yaw)))
	player.pitch = float(p.get("pitch", -0.12))
	_begin_playing()
	if GameState.completed:
		# A clareira já estava limpa: o tronco da saída continua esperando as garras.
		world.exit_breakable = true


func _begin_playing() -> void:
	GameState.playing = true
	state = State.PLAYING
	_autosave = AUTOSAVE_EVERY
	player.camera.current = true
	player.bot = DevTools.autoplay
	player.controls_enabled = not DevTools.autoplay
	menus.show_screen("")
	# "Mostrar a interface" desligado (ou --nohud nos testes) esconde o HUD.
	_apply_hud_visibility()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.set_music_duck(0.35)


## Salva o progresso (formigas, câmaras, habilidades e onde o tamanduá está).
func save_game() -> void:
	if state == State.COMPLETE:
		return
	var gp := player.global_position
	GameState.write_saved_game({
		"version": GameState.SAVE_VERSION,
		"state": GameState.to_save(),
		"colony": colony.to_save(),
		"player": {"x": gp.x, "z": gp.z, "yaw": player.yaw, "pitch": player.pitch},
		"explored": exploration.to_save(),
	})
	if hud:
		hud.show_saved()


## Pausa e árvore são tratadas em _input (antes da interface): assim o TAB
## fecha a árvore em vez de só trocar o foco entre os botões.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		match state:
			State.PLAYING:
				_pause()
			State.PAUSED:
				if menus.current() == "pause":
					_resume()
				else:
					menus.show_screen("pause")
			State.TREE:
				_close_tree()
			State.MENU:
				if menus.current() != "title":
					menus.show_screen("title")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_tree") and state in [State.PLAYING, State.TREE]:
		if state == State.PLAYING:
			# Com a dica de cadeado na tela, abre direto naquela habilidade.
			var skill := hud.locked_skill()
			if skill.is_empty():
				_open_tree()
			else:
				_open_tree(TabMenu.SKILLS, skill)
		else:
			_close_tree()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.PLAYING and event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAYING and not DevTools.autoplay:
		_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and state in [State.PLAYING, State.PAUSED, State.TREE]:
		save_game()


func _pause() -> void:
	state = State.PAUSED
	save_game()
	get_tree().paused = true
	menus.show_screen("pause")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.set_music_duck(0.8)


func _resume() -> void:
	state = State.PLAYING
	get_tree().paused = false
	menus.show_screen("")
	tab_ui.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.set_music_duck(0.35)


## Abre a tela do TAB (o mapa primeiro; a árvore pelo menu de pausa).
func _open_tree(page: int = TabMenu.MAP, focus_skill: String = "") -> void:
	if state == State.COMPLETE:
		return
	state = State.TREE
	get_tree().paused = true
	menus.show_screen("")
	Settings.learn_hint("map")
	tab_ui.open(page, focus_skill)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("ui_open", -6.0)


func _close_tree() -> void:
	tab_ui.visible = false
	_resume()


func _restart() -> void:
	GameState.delete_saved_game()
	skip_menu = true
	_reload()


func _to_main_menu() -> void:
	if state in [State.PLAYING, State.PAUSED, State.TREE]:
		save_game()
	skip_menu = false
	_reload()


func _exit_tree() -> void:
	if _reloading:
		return
	# Saindo do jogo: solta os recursos guardados em variáveis estáticas.
	UiTheme._theme = null
	SnoutBuilder._strands = null
	AntMeshBuilder.body_material = null
	AntMeshBuilder.wing_material = null
	Props.noise = null


func _reload() -> void:
	_reloading = true
	get_tree().paused = false
	Engine.time_scale = _base_time_scale
	GameState.playing = false
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(fade, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): get_tree().reload_current_scene())


func _on_eaten_changed(_total: int, _delta: int) -> void:
	if DevTools.autoplay and state == State.PLAYING:
		_bot_buy()


## Bot de teste: aprende as habilidades na ordem de BOT_ORDER.
func _bot_buy() -> void:
	for id in BOT_ORDER:
		if GameState.has(id):
			continue
		if not GameState.can_buy(id):
			return
		GameState.buy(id)
		print("[bot] comprou %s com %d formigas comidas" % [id, GameState.ants_eaten])


## Clareira 100% limpa: o tronco da saída já pode ser quebrado com as garras.
func _on_complete(_time: float) -> void:
	_new_record = is_equal_approx(GameState.best_time, GameState.elapsed)
	world.exit_breakable = true
	hud.big_note("Clareira limpa!", "Quebre o tronco na saída", 5.0, "log")
	Sfx.play("complete", 0.0)
	save_game()


func _belly_growl() -> void:
	if state != State.PLAYING:
		return
	Sfx.play("growl", 0.0)
	player.shake = 0.35


## O tronco foi quebrado: a passagem para a área 2 está aberta (fim da demo).
func _on_exit_broken() -> void:
	state = State.COMPLETE
	GameState.delete_saved_game()
	player.controls_enabled = false
	player.bot = false
	Engine.time_scale = _base_time_scale * 0.35
	_complete_wait = 2.6
	hud.big_note("O caminho está aberto", "Lá longe, o cupinzeiro gigante espera...", 4.0)


func _process(delta: float) -> void:
	if state == State.PLAYING:
		_autosave -= delta / maxf(Engine.time_scale, 0.01)
		if _autosave <= 0.0:
			_autosave = AUTOSAVE_EVERY
			save_game()
	if state == State.MENU and menu_cam:
		_menu_t += delta
		var a := _menu_t * 0.06 + 2.2
		var pos := _menu_center + Vector3(cos(a) * 3.2, 0.0, sin(a) * 3.2)
		pos.y = world.ground_height(pos.x, pos.z) + 0.55 + sin(_menu_t * 0.3) * 0.08
		menu_cam.global_position = pos
		menu_cam.look_at(_menu_center + Vector3(0, 0.25, 0) + Vector3(cos(a + 1.9), 0, sin(a + 1.9)) * 2.0)
		RenderingServer.global_shader_parameter_set("player_pos", Vector3(9999, 0, 9999))
		world.follow_camera(pos)
		swarm.cam_pos = pos
	if state == State.COMPLETE and _complete_wait > 0.0:
		_complete_wait -= delta / maxf(Engine.time_scale, 0.01)
		if _complete_wait <= 0.0:
			Engine.time_scale = _base_time_scale
			GameState.playing = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			hud.visible = false
			menus.show_end(GameState.elapsed, _new_record)
