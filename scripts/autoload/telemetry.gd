extends Node
## Estatísticas da versão de teste: junta o que acontece em cada partida e manda
## para um Formulário do Google (as respostas caem numa planilha do Caio).
##
## O que vai: um número aleatório do jogador (e o apelido, se ele quiser), a
## versão do jogo, o tempo, os insetos, as compras, os marcos, os objetivos, os formigueiros
## limpos, os números das Estatísticas, a placa de vídeo e o FPS médio. Nada de
## nome, e-mail ou arquivos do computador.
##
## Quando vai: a cada 10 minutos de jogo, ao voltar para o menu ou fechar o jogo,
## e quando a clareira fica limpa. Cada envio leva o registro inteiro desta vez
## que o jogo foi aberto; na planilha, a linha mais nova de cada partida é a
## mais completa.
##
## Uma cópia de cada envio fica em user://registros/ (no Windows,
## %APPDATA%/Godot/app_userdata/Anteater Simulator/registros), mesmo sem internet.
##
## Desligado: sem formulário configurado (FORM_URL vazio), com "Enviar
## estatísticas" desligado nas Configurações e nos testes (argumentos depois de
## "--" ou sem tela), a não ser com --telemetria.

## Endereço "formResponse" do formulário (vazio = não manda nada).
const FORM_URL := "https://docs.google.com/forms/d/e/1FAIpQLSc-rjX-eJ-PsVels--fuEe_Hycl3pEiQhAy_vPL_yF8r7SxBw/formResponse"
## O número ("entry.123456") de cada pergunta do formulário. Sai do link
## pré-preenchido do formulário (ver docs/estatisticas-dos-testes.md).
const ENTRIES := {
	"jogador": "entry.510037951",
	"apelido": "entry.1486572967",
	"partida": "entry.380032149",
	"versao": "entry.440404601",
	"evento": "entry.574340865",
	"minutos": "entry.1322118713",
	"insetos": "entry.559935905",
	"computador": "entry.1407916040",
	"estatisticas": "entry.1136356305",
	"registro": "entry.2091696714",
}

## De quanto em quanto tempo de jogo manda um envio parcial.
const SEND_EVERY := 600.0
## De quanto em quanto tempo de jogo anota o progresso no registro.
const PROGRESS_EVERY := 120.0
## Quanto tempo espera o último envio ao fechar o jogo.
const QUIT_WAIT := 3.0
const LOG_DIR := "user://registros"

## Há uma partida sendo registrada.
var session_active := false
var _session_id := ""
var _rows: PackedStringArray = []
var _next_send := 0.0
var _next_progress := 0.0
var _pending := 0
# FPS: uma amostra por segundo de jogo (sem pausa).
var _fps_sum := 0.0
var _fps_n := 0
var _fps_low := 0
var _fps_worst := 9999.0
var _fps_tick := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Settings.player_id.is_empty():
		Settings.player_id = "%08x" % (randi() & 0x7FFFFFFF)
		if DisplayServer.get_name() != "headless":
			Settings.save_settings()
	GameState.upgrade_purchased.connect(func(id):
		var u := GameState.get_upgrade(id)
		var r := GameState.rank(id)
		var costs: Array = u.get("costs", [0])
		log_event("compra", "%s %d/%d (%d)" % [u.get("name", id), r, costs.size(),
			int(costs[clampi(r - 1, 0, costs.size() - 1)])]))
	GameState.marco_reached.connect(func(m): log_event("marco", str(m)))
	GameState.skills_reset.connect(func(): log_event("redistribuiu", ""))
	GameState.level_completed.connect(func(_t):
		if session_active:
			log_event("clareira limpa", GameState.format_time(GameState.elapsed))
			_send("clareira limpa"))


## Pode registrar e mandar? (os testes e o servidor sem tela não mandam)
func enabled() -> bool:
	if DevTools.args.has("telemetria"):
		return Settings.send_stats
	if DisplayServer.get_name() == "headless" or not DevTools.args.is_empty():
		return false
	return Settings.send_stats


## Para onde mandar: o formulário, ou (teste) o endereço dado em --telemetria=http://...
func _url() -> String:
	var test := String(DevTools.args.get("telemetria", ""))
	return test if test.begins_with("http") else FORM_URL


## O formulário já foi configurado (FORM_URL e as perguntas)?
func configured() -> bool:
	if _url() != FORM_URL:
		return true
	if FORM_URL.is_empty():
		return false
	for k in ENTRIES:
		if String(ENTRIES[k]).is_empty():
			return false
	return true


## Começou a jogar: "novo" (jogo novo) ou "continuou" (jogo salvo).
func start_session(kind: String) -> void:
	if session_active:
		end_session("trocou de jogo")
	if not enabled():
		return
	session_active = true
	_session_id = "%04x" % (randi() & 0xFFFF)
	_rows = PackedStringArray()
	_fps_sum = 0.0
	_fps_n = 0
	_fps_low = 0
	_fps_worst = 9999.0
	_fps_tick = Time.get_ticks_msec()
	_next_send = (floorf(GameState.elapsed / SEND_EVERY) + 1.0) * SEND_EVERY
	_next_progress = GameState.elapsed + PROGRESS_EVERY
	log_event(kind, "modo %s" % GameState.mode)


## Parou de jogar: manda o registro desta vez e encerra.
func end_session(reason: String) -> void:
	if not session_active:
		return
	log_event("fim da sessão", reason)
	_send(reason)
	session_active = false


## Fechando o jogo: encerra e espera o envio (até QUIT_WAIT segundos).
func before_quit() -> void:
	end_session("fechou o jogo")
	var start := Time.get_ticks_msec()
	while _pending > 0 and Time.get_ticks_msec() - start < QUIT_WAIT * 1000.0:
		await get_tree().process_frame


## Uma linha no registro: tempo de jogo, insetos comidos, o que aconteceu e detalhes.
func log_event(what: String, detail: String = "") -> void:
	if not session_active:
		return
	_rows.append("%s;%d;%s;%s" % [GameState.format_time(GameState.elapsed), GameState.ants_eaten,
		what, detail.replace(";", ",")])


func _process(_delta: float) -> void:
	if not session_active or not GameState.playing:
		return
	if not get_tree().paused:
		var now := Time.get_ticks_msec()
		if now - _fps_tick >= 1000:
			_fps_tick = now
			var fps := Engine.get_frames_per_second()
			_fps_sum += fps
			_fps_n += 1
			_fps_worst = minf(_fps_worst, fps)
			if fps < 30.0:
				_fps_low += 1
	else:
		_fps_tick = Time.get_ticks_msec()
	if GameState.elapsed >= _next_progress:
		_next_progress += PROGRESS_EVERY
		log_event("progresso", "%d pontos sobrando" % GameState.points_available())
	if GameState.elapsed >= _next_send:
		_next_send += SEND_EVERY
		_send("a cada 10 min")


# ------------------------------------------------------------------ Envio

func _fields(event: String) -> Dictionary:
	return {
		"jogador": Settings.player_id,
		"apelido": Settings.nickname.strip_edges(),
		"partida": "%s-%s" % [GameState.run_id, _session_id],
		"versao": version(),
		"evento": event,
		"minutos": GameState._num(GameState.elapsed / 60.0, 1),
		"insetos": str(GameState.ants_eaten),
		"computador": _computer(),
		"estatisticas": _stats(),
		"registro": "tempo;insetos;evento;detalhe\n" + "\n".join(_rows),
	}


func _send(event: String) -> void:
	# Desligou "Enviar estatísticas" no meio da partida: para na hora.
	if not Settings.send_stats:
		return
	var f := _fields(event)
	_write_local(f)
	if not configured():
		return
	var parts := PackedStringArray()
	for k in ENTRIES:
		var key := String(ENTRIES[k]) if not String(ENTRIES[k]).is_empty() else String(k)
		parts.append("%s=%s" % [key, String(f[k]).uri_encode()])
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	_pending += 1
	req.request_completed.connect(func(result, code, _h, _b):
		if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
			push_warning("[estatísticas] envio falhou (%d, %d)" % [result, code])
		elif DevTools.args.has("telemetria"):
			print("[estatísticas] enviado (%s): resposta %d" % [event, code])
		_pending -= 1
		req.queue_free())
	var err := req.request(_url(), ["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST, "&".join(parts))
	if err != OK:
		_pending -= 1
		req.queue_free()


## Cópia de cada envio no computador do jogador (o envio mais novo substitui o
## anterior da mesma sessão).
func _write_local(f: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var file := FileAccess.open("%s/partida_%s.txt" % [LOG_DIR, f.partida], FileAccess.WRITE)
	if file == null:
		return
	for k in ENTRIES:
		file.store_line("== %s ==" % k)
		file.store_line(String(f[k]))
	file.close()


static func version() -> String:
	var v := String(ProjectSettings.get_setting("application/config/version", "?"))
	return v + (" (editor)" if OS.has_feature("editor") else "")


func _computer() -> String:
	var fps := "—"
	if _fps_n > 0:
		fps = "%d (pior %d; abaixo de 30 em %d%% do tempo)" % [int(round(_fps_sum / _fps_n)), int(_fps_worst),
			int(round(100.0 * _fps_low / _fps_n))]
	var mem := int(OS.get_memory_info().get("physical", 0)) / (1024 * 1024 * 1024)
	var q := int(Settings.graphics_quality)
	var qname: String = Settings.QUALITY_NAMES[q] if q < Settings.QUALITY_NAMES.size() else "Personalizada"
	return "\n".join([
		"Placa de vídeo: %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()],
		"Processador: %s · %d GB de RAM" % [OS.get_processor_name(), mem],
		"Sistema: %s %s" % [OS.get_name(), OS.get_version()],
		"Tela: %d × %d · %s · qualidade %s · 3D em %d%%" % [DisplayServer.screen_get_size().x,
			DisplayServer.screen_get_size().y, Settings.WINDOW_MODE_NAMES[Settings.window_mode], qname,
			int(round(Settings.render_scale * 100.0))],
		"FPS médio: " + fps,
	])


func _stats() -> String:
	var skills := 0
	var total := 0
	for u in GameState.UPGRADES:
		if GameState.region_required(u.id).is_empty():
			total += GameState.max_rank(u.id)
			skills += GameState.rank(u.id)
	var licks := GameState.stat("licks")
	var aim := "—" if licks <= 0.0 else "%d%%" % int(round(GameState.stat("licks_hit") / licks * 100.0))
	return "\n".join([
		"Modo: %s" % ("contra o relógio" if GameState.mode == GameState.MODE_CLOCK else "normal"),
		"Clareira limpa: %s" % ("sim" if GameState.completed else "não"),
		"Habilidades: %d de %d cliques · pontos gastos %d · sobrando %d" % [skills, total, GameState.points_spent,
			GameState.points_available()],
		"Formigueiros limpos: %d · câmaras abertas: %d" % [int(GameState.stat("nests_cleaned")),
			int(GameState.stat("chambers_opened"))],
		"Rainhas: %d · tanajuras: %d · maior combo: %d" % [GameState.queens_eaten, GameState.tanajuras_eaten,
			GameState.best_combo],
		"Linguadas: %d · acerto: %s" % [int(licks), aim],
		"Faro: %d · tremores: %d" % [int(GameState.stat("sniffs")), int(GameState.stat("tremors"))],
		"Distância: %d m · correndo: %s" % [int(GameState.stat("distance")), GameState.format_time(GameState.stat("run_time"))],
		"Parciais: %s" % ", ".join(GameState.splits.map(func(t): return GameState.format_clock(float(t)))),
	])
