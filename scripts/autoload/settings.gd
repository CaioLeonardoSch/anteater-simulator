extends Node
## Configurações do jogador (tela, gráficos, controles e áudio) e mapa de controles.
## Salva em user://settings.cfg. F11 ou Alt+Enter alterna a tela cheia.

signal changed

const SAVE_PATH := "user://settings.cfg"

const QUALITY_NAMES := ["Baixa", "Média", "Alta", "Ultra", "Personalizada"]
const CUSTOM := 4
const WINDOW_MODE_NAMES := ["Janela", "Tela cheia", "Tela cheia exclusiva"]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1080), Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160)]
const FPS_LIMITS := [0, 30, 60, 120, 144, 165, 240]
const RENDER_SCALES := [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]
const SHADOW_NAMES := ["Baixa", "Média", "Alta", "Ultra"]
const GRASS_NAMES := ["Pouco", "Médio", "Muito", "Máximo"]
const AA_NAMES := ["Desligado", "FXAA", "MSAA 2x", "MSAA 4x", "TAA"]

## Cada preset de qualidade escolhe todos os itens de "Gráficos".
const PRESETS := [
	{"shadow_quality": 0, "grass_quality": 0, "ssao": false, "ssil": false, "volumetric_fog": false,
		"glow": true, "antialiasing": 1, "render_scale": 0.8},
	{"shadow_quality": 1, "grass_quality": 1, "ssao": true, "ssil": false, "volumetric_fog": false,
		"glow": true, "antialiasing": 2, "render_scale": 1.0},
	{"shadow_quality": 2, "grass_quality": 2, "ssao": true, "ssil": false, "volumetric_fog": false,
		"glow": true, "antialiasing": 2, "render_scale": 1.0},
	{"shadow_quality": 3, "grass_quality": 3, "ssao": true, "ssil": true, "volumetric_fog": true,
		"glow": true, "antialiasing": 3, "render_scale": 1.0},
]
const GRAPHICS_KEYS := ["shadow_quality", "grass_quality", "ssao", "ssil", "volumetric_fog", "glow",
	"antialiasing", "render_scale"]

# Tela
## 0 = janela, 1 = tela cheia, 2 = tela cheia exclusiva
var window_mode: int = 1
## Tamanho da janela (modo janela).
var window_size := Vector2i(1600, 900)
## Resolução em que o 3D é desenhado em tela cheia (0 x 0 = a da própria tela).
var fullscreen_resolution := Vector2i.ZERO
## A resolução do modo atual: tamanho da janela ou resolução da tela cheia.
var resolution: Vector2i:
	get:
		if window_mode == 0:
			return window_size
		return fullscreen_resolution if fullscreen_resolution != Vector2i.ZERO else screen_size()
	set(value):
		if window_mode == 0:
			window_size = value
		else:
			fullscreen_resolution = Vector2i.ZERO if value == screen_size() else value
var vsync: bool = true
## 0 = sem limite
var max_fps: int = 0
## Escala da resolução 3D (a interface continua nítida).
var render_scale: float = 1.0

# Gráficos (0 = Baixa, 1 = Média, 2 = Alta, 3 = Ultra, 4 = Personalizada)
var graphics_quality: int = 2
var shadow_quality: int = 2
var grass_quality: int = 2
var ssao: bool = true
var ssil: bool = false
var volumetric_fog: bool = false
var glow: bool = true
## 0 desligado, 1 FXAA, 2 MSAA 2x, 3 MSAA 4x, 4 TAA
var antialiasing: int = 2

# Jogo e áudio
var mouse_sensitivity: float = 0.22
var invert_y: bool = false
var fov: float = 78.0
## Balanço da câmera ao andar e correr (0 = parada, 1 = normal).
var camera_bob: float = 1.0
var master_volume: float = 0.85
var music_volume: float = 0.55


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_map()
	load_settings()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures") or arg == "--windowed":
			# Capturas de tela de teste: sempre numa janela de 1600x900.
			window_mode = 0
			window_size = Vector2i(1600, 900)
	apply_window()
	apply_audio()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.keycode
		if k == KEY_F11 or (k == KEY_ENTER and event.alt_pressed):
			set_value("window_mode", 0 if window_mode != 0 else 1)
			get_viewport().set_input_as_handled()


func _setup_input_map() -> void:
	_bind_keys("move_forward", [KEY_W, KEY_UP])
	_bind_keys("move_back", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("run", [KEY_SHIFT])
	_bind_keys("sniff", [KEY_Q])
	_bind_keys("dig", [KEY_E])
	_bind_keys("tremor", [KEY_SPACE])
	_bind_keys("skill_tree", [KEY_TAB, KEY_T])
	_bind_keys("pause", [KEY_ESCAPE, KEY_P])
	_bind_mouse("lick", MOUSE_BUTTON_LEFT)
	_bind_mouse("sniff", MOUSE_BUTTON_RIGHT)
	# Controle (gamepad)
	_bind_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_bind_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_bind_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_bind_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_bind_axis("lick", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_bind_axis("sniff", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_bind_joy("run", JOY_BUTTON_LEFT_STICK)
	_bind_joy("dig", JOY_BUTTON_X)
	_bind_joy("tremor", JOY_BUTTON_A)
	_bind_joy("skill_tree", JOY_BUTTON_BACK)
	_bind_joy("pause", JOY_BUTTON_START)
	for a in ["look_left", "look_right", "look_up", "look_down"]:
		_ensure_action(a)
	_add_event("look_left", _axis_event(JOY_AXIS_RIGHT_X, -1.0))
	_add_event("look_right", _axis_event(JOY_AXIS_RIGHT_X, 1.0))
	_add_event("look_up", _axis_event(JOY_AXIS_RIGHT_Y, -1.0))
	_add_event("look_down", _axis_event(JOY_AXIS_RIGHT_Y, 1.0))


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _add_event(action: String, ev: InputEvent) -> void:
	_ensure_action(action)
	InputMap.action_add_event(action, ev)


func _bind_keys(action: String, keys: Array) -> void:
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		_add_event(action, ev)


func _bind_mouse(action: String, button: MouseButton) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	_add_event(action, ev)


func _bind_joy(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	_add_event(action, ev)


func _axis_event(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev


func _bind_axis(action: String, axis: JoyAxis, value: float) -> void:
	_add_event(action, _axis_event(axis, value))


# ------------------------------------------------------------------ Salvar

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_pick_default_quality()
		return
	graphics_quality = clampi(int(cfg.get_value("video", "quality", graphics_quality)), 0, CUSTOM)
	if graphics_quality < CUSTOM:
		_apply_preset_values(graphics_quality)
	for key in GRAPHICS_KEYS:
		set(key, cfg.get_value("graphics", key, get(key)))
	shadow_quality = clampi(shadow_quality, 0, 3)
	grass_quality = clampi(grass_quality, 0, 3)
	antialiasing = clampi(antialiasing, 0, AA_NAMES.size() - 1)
	render_scale = clampf(render_scale, 0.5, 1.0)
	# Versões antigas só tinham "tela cheia: sim/não".
	var old_fullscreen = cfg.get_value("video", "fullscreen", null)
	if old_fullscreen != null:
		window_mode = 1 if bool(old_fullscreen) else 0
	window_mode = clampi(int(cfg.get_value("video", "window_mode", window_mode)), 0, 2)
	window_size = cfg.get_value("video", "window_size", window_size)
	fullscreen_resolution = cfg.get_value("video", "fullscreen_resolution", fullscreen_resolution)
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	max_fps = int(cfg.get_value("video", "max_fps", max_fps))
	fov = float(cfg.get_value("video", "fov", fov))
	camera_bob = clampf(float(cfg.get_value("video", "camera_bob", camera_bob)), 0.0, 1.0)
	mouse_sensitivity = float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	invert_y = bool(cfg.get_value("input", "invert_y", invert_y))
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))


## Primeira vez: escolhe a qualidade pelo tipo de placa de vídeo e a resolução pela tela.
func _pick_default_quality() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
			graphics_quality = 2
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
			graphics_quality = 1
		RenderingDevice.DEVICE_TYPE_CPU, RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
			graphics_quality = 0
		_:
			graphics_quality = 1
	_apply_preset_values(graphics_quality)
	# Janela de 1600x900 (ou menor, se a tela for pequena); tela cheia na resolução da tela.
	var usable := DisplayServer.screen_get_usable_rect().size
	if usable.x < 1600 or usable.y < 900:
		window_size = Vector2i(int(usable.x * 0.9), int(usable.y * 0.9))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", graphics_quality)
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "window_size", window_size)
	cfg.set_value("video", "fullscreen_resolution", fullscreen_resolution)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "max_fps", max_fps)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "camera_bob", camera_bob)
	for key in GRAPHICS_KEYS:
		cfg.set_value("graphics", key, get(key))
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.save(SAVE_PATH)


## Muda uma configuração, salva e aplica. Mexer num item de "Gráficos" deixa
## a qualidade como "Personalizada"; escolher um preset muda todos os itens.
func set_value(key: String, value) -> void:
	if key == "graphics_quality":
		graphics_quality = int(value)
		if graphics_quality < CUSTOM:
			_apply_preset_values(graphics_quality)
	else:
		set(key, value)
		if key in GRAPHICS_KEYS:
			graphics_quality = _matching_preset()
	save_settings()
	apply_window()
	apply_audio()
	changed.emit()


func _apply_preset_values(q: int) -> void:
	var preset: Dictionary = PRESETS[clampi(q, 0, PRESETS.size() - 1)]
	for key in preset:
		set(key, preset[key])


## O preset que bate com os itens atuais (ou Personalizada).
func _matching_preset() -> int:
	for q in PRESETS.size():
		var same := true
		for key in PRESETS[q]:
			if get(key) != PRESETS[q][key]:
				same = false
				break
		if same:
			return q
	return CUSTOM


# ------------------------------------------------------------------ Aplicar

func screen_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i(1600, 900)
	return DisplayServer.screen_get_size()


## Resoluções que cabem na tela (e a da própria tela).
func available_resolutions() -> Array[Vector2i]:
	var screen := screen_size()
	var out: Array[Vector2i] = []
	for r in RESOLUTIONS:
		if r.x <= screen.x and r.y <= screen.y:
			out.append(r)
	if not out.has(screen):
		out.append(screen)
	for extra in [window_size, fullscreen_resolution]:
		if extra != Vector2i.ZERO and not out.has(extra):
			out.append(extra)
	out.sort_custom(func(a: Vector2i, b: Vector2i): return a.x * a.y < b.x * b.y)
	return out


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var modes := [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	var want: int = modes[clampi(window_mode, 0, 2)]
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	if window_mode == 0:
		_apply_window_size.call_deferred()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps


func _apply_window_size() -> void:
	if window_mode != 0:
		return
	var usable := DisplayServer.screen_get_usable_rect()
	var size := Vector2i(mini(window_size.x, usable.size.x), mini(window_size.y, usable.size.y))
	if DisplayServer.window_get_size() != size:
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


## Escala do 3D: a escolhida e, em tela cheia, a resolução escolhida para a tela cheia.
func effective_3d_scale() -> float:
	var s := render_scale
	if window_mode != 0 and fullscreen_resolution != Vector2i.ZERO:
		var screen := screen_size()
		if screen.y > 0:
			s *= minf(1.0, float(fullscreen_resolution.y) / float(screen.y))
	return clampf(s, 0.25, 1.0)


func apply_audio() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume, 0.0001)))
	var music := AudioServer.get_bus_index("Music")
	if music >= 0:
		AudioServer.set_bus_volume_db(music, linear_to_db(maxf(music_volume, 0.0001)))


## Densidade e alcance do capim.
func grass_density() -> float:
	return [0.35, 0.6, 1.0, 1.4][grass_quality]


func grass_view_distance() -> float:
	return [28.0, 38.0, 50.0, 64.0][grass_quality]
