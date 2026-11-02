extends Node
## Configurações do jogador (sensibilidade, gráficos, áudio) e mapa de controles.
## Salva em user://settings.cfg.

signal changed

const SAVE_PATH := "user://settings.cfg"

## 0 = Baixa, 1 = Média, 2 = Alta, 3 = Ultra
var graphics_quality: int = 2
var mouse_sensitivity: float = 0.22
var invert_y: bool = false
var fov: float = 78.0
var master_volume: float = 0.85
var music_volume: float = 0.55
var fullscreen: bool = false

const QUALITY_NAMES := ["Baixa", "Média", "Alta", "Ultra"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_map()
	load_settings()
	apply_window()
	apply_audio()


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


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_pick_default_quality()
		return
	graphics_quality = int(cfg.get_value("video", "quality", graphics_quality))
	fov = float(cfg.get_value("video", "fov", fov))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	mouse_sensitivity = float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	invert_y = bool(cfg.get_value("input", "invert_y", invert_y))
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	graphics_quality = clampi(graphics_quality, 0, 3)


## Primeira vez: escolhe a qualidade pelo tipo de placa de vídeo.
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


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", graphics_quality)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.save(SAVE_PATH)


func set_value(key: String, value) -> void:
	set(key, value)
	save_settings()
	apply_window()
	apply_audio()
	changed.emit()


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func apply_audio() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume, 0.0001)))
	var music := AudioServer.get_bus_index("Music")
	if music >= 0:
		AudioServer.set_bus_volume_db(music, linear_to_db(maxf(music_volume, 0.0001)))


## Densidade de grama/flores de acordo com a qualidade gráfica.
func grass_density() -> float:
	return [0.35, 0.6, 1.0, 1.4][graphics_quality]


func grass_view_distance() -> float:
	return [28.0, 38.0, 50.0, 64.0][graphics_quality]
