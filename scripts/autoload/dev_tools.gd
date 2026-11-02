extends Node
## Ferramentas de desenvolvimento, ativadas só por argumentos de linha de comando
## (depois de "--"). Exemplos:
##   godot --path . -- --start=play --captures=3:shot.png --quit
##   godot --path . -- --start=play --autoplay --timescale=3 --stats
## Opções:
##   --start=play|tree|complete   pula o menu
##   --captures=SEG:arquivo.png,... salva capturas de tela nesses instantes
##   --quit                       fecha depois da última captura
##   --quit-after=SEG             fecha depois de SEG segundos
##   --autoplay                   um "bot" controla o tamanduá (teste de fumaça)
##   --give=N                     começa com N formigas comidas
##   --buy=id1,id2                compra upgrades no início
##   --timescale=K                acelera o tempo do jogo
##   --pose=x,z,yaw,pitch         posiciona o jogador
##   --stats                      imprime FPS e estatísticas de render a cada segundo

var args: Dictionary = {}
var start_mode: String = ""
var autoplay := false
var give := 0
var buy: PackedStringArray = []
var pose: PackedFloat32Array = []
var _captures: Array = []
var _quit_when_done := false
var _quit_after := -1.0
var _stats := false
var _time := 0.0
var _stat_timer := 0.0
var _frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--"):
			s = s.substr(2)
		var eq := s.find("=")
		if eq >= 0:
			args[s.substr(0, eq)] = s.substr(eq + 1)
		else:
			args[s] = "1"
	if args.is_empty():
		set_process(false)
		return
	start_mode = String(args.get("start", ""))
	autoplay = args.has("autoplay")
	give = int(args.get("give", "0"))
	if args.has("buy"):
		buy = String(args.buy).split(",", false)
	if args.has("pose"):
		for p in String(args.pose).split(","):
			pose.append(float(p))
	if args.has("timescale"):
		Engine.time_scale = float(args.timescale)
	if args.has("captures"):
		for item in String(args.captures).split(","):
			var parts := item.split(":")
			if parts.size() == 2:
				_captures.append([float(parts[0]), parts[1]])
	_quit_when_done = args.has("quit")
	_quit_after = float(args.get("quit-after", "-1"))
	_stats = args.has("stats")
	print("[DevTools] args: ", args)


func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.0001)
	_time += real_dt
	_frames += 1
	if _stats:
		_stat_timer += real_dt
		if _stat_timer >= 1.0:
			var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			print("[stats] t=%.1f fps=%d frames=%d prims=%d draws=%d eaten=%d" % [
				_time, Engine.get_frames_per_second(), _frames, prims, draws, GameState.ants_eaten])
			_stat_timer = 0.0
	while not _captures.is_empty() and _time >= float(_captures[0][0]):
		var c: Array = _captures.pop_front()
		_capture(String(c[1]))
		if _captures.is_empty() and _quit_when_done:
			Sfx.quit_game()
	if _quit_after > 0.0 and _time >= _quit_after:
		Sfx.quit_game()


func _capture(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_warning("[DevTools] sem imagem para capturar")
		return
	var err := img.save_jpg(path, 0.9) if path.ends_with(".jpg") else img.save_png(path)
	print("[DevTools] captura salva: ", path, " (", err, ") ", img.get_size())
