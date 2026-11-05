extends Control
## Menus da demo: tela inicial, pausa, configurações, "como jogar" e tela final.
## Um único nó com várias telas; o Main troca entre elas.

signal play_pressed
signal continue_pressed
## Escolheu um dos jogos salvos (vazio = jogo novo nele).
signal slot_chosen(slot: int)
signal resume_pressed
signal restart_pressed
signal main_menu_pressed
signal skill_tree_pressed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const StatsPanel := preload("res://scripts/ui/stats_panel.gd")

var _screens: Dictionary = {}
var _current := ""
var _back_to := "title"
## Estatísticas (tela aberta pela pausa) e na tela do fim.
var _pause_stats: StatsPanel
var _end_stats: StatsPanel
var _end_time: Label
var _end_title: Label
var _end_sub: Label
var _restart_button: Button
var _settings_controls: Dictionary = {}
var _settings_pages: Array[Control] = []
var _settings_tab_buttons: Array[Button] = []
var _settings_note: Label
## Botões das teclas (ação -> botão) e a ação esperando uma tecla nova.
var _key_buttons: Dictionary = {}
var _rebinding := ""
## Jogo salvo (vazio) onde vai começar o jogo novo e a tela de onde veio.
var _new_slot := 1
var _mode_back := "title"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screens.title = _build_title()
	_screens.pause = _build_pause()
	_screens.stats = _build_stats()
	_screens.settings = _build_settings()
	_screens.howto = _build_howto()
	_screens.slots = _build_slots()
	_screens.mode = _build_mode()
	_screens.end = _build_end()
	_screens.loading = _build_loading()
	for k in _screens:
		add_child(_screens[k])
		_screens[k].visible = false


func show_screen(screen_name: String) -> void:
	for k in _screens:
		_screens[k].visible = (k == screen_name)
	_current = screen_name
	visible = screen_name != ""
	if screen_name == "stats":
		_pause_stats.refresh()
	if screen_name != "":
		var first := _find_first_button(_screens[screen_name])
		if first:
			first.grab_focus.call_deferred()


## O mundo e as formigas, para as contas das estatísticas.
func setup_stats(world, colony) -> void:
	_pause_stats.setup(world, colony)
	_end_stats.setup(world, colony)


func current() -> String:
	return _current


func _find_first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and (c as Button).visible:
			return c
		var r := _find_first_button(c)
		if r:
			return r
	return null


func _screen(dim: float = 0.0) -> Control:
	var s := Control.new()
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if dim > 0.0:
		var bg := ColorRect.new()
		bg.color = Color(0.03, 0.02, 0.018, dim)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		s.add_child(bg)
	return s


func _centered_column(parent: Control, panel: bool = true) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	if panel:
		var p := PanelContainer.new()
		center.add_child(p)
		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 26)
		p.add_child(margin)
		margin.add_child(v)
	else:
		center.add_child(v)
	return v


# ------------------------------------------------------------------ Telas

func _build_loading() -> Control:
	var s := _screen(1.0)
	var v := _centered_column(s, false)
	var t := UiTheme.display_label("Preparando o cerrado...", 36, UiTheme.PALE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return s


func _build_title() -> Control:
	var s := _screen(0.0)
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.02, 0.018, 0.0))
	g.set_color(1, Color(0.03, 0.02, 0.018, 0.82))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.2)
	gt.fill_to = Vector2(0.0, 1.0)
	grad.texture = gt
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	s.add_child(grad)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	v.offset_left = 90
	v.offset_right = 760
	v.offset_top = 0
	v.offset_bottom = 0
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	s.add_child(v)
	var title := UiTheme.display_label("Anteater\nSimulator", 100, UiTheme.PALE)
	title.add_theme_constant_override("line_spacing", -26)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0.06, 0.035, 0.02, 0.95))
	title.add_theme_color_override("font_shadow_color", Color(UiTheme.GOLD, 0.4))
	title.add_theme_constant_override("shadow_outline_size", 22)
	title.add_theme_constant_override("shadow_offset_y", 0)
	v.add_child(title)
	var divider := Divider.new()
	divider.custom_minimum_size = Vector2(520, 18)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(divider)
	var sub := UiTheme.caps_label("Demo · Fase 1: Cerrado ao Entardecer", 18, UiTheme.GOLD)
	sub.add_theme_constant_override("outline_size", 4)
	sub.add_theme_color_override("font_outline_color", Color(0.04, 0.025, 0.02, 0.9))
	v.add_child(sub)
	var tag := UiTheme.label("Você é um tamanduá-bandeira faminto. A clareira tem %s insetos.\nCada 10 insetos comidos valem 1 ponto para aprender habilidades." % StatsPanel._n(GameState.GOAL), 22, UiTheme.CREAM)
	tag.add_theme_font_override("font", UiTheme.semi_font())
	tag.add_theme_constant_override("outline_size", 4)
	tag.add_theme_color_override("font_outline_color", Color(0.04, 0.025, 0.02, 0.85))
	v.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	v.add_child(gap)
	var cont := UiTheme.button("Continuar")
	cont.name = "Continue"
	cont.pressed.connect(func():
		GameState.slot = GameState.latest_slot()
		continue_pressed.emit())
	v.add_child(cont)
	var play := UiTheme.button("Jogar")
	play.name = "Play"
	play.pressed.connect(func():
		if GameState.any_saved_game():
			_goto("slots", "title")
		else:
			_choose_mode(1, "title"))
	v.add_child(play)
	var how := UiTheme.button("Como jogar")
	how.pressed.connect(_goto.bind("howto", "title"))
	v.add_child(how)
	var settings := UiTheme.button("Configurações")
	settings.pressed.connect(_goto.bind("settings", "title"))
	v.add_child(settings)
	var quit := UiTheme.button("Sair")
	quit.pressed.connect(func(): Sfx.quit_game())
	v.add_child(quit)
	for b in [cont, play, how, settings, quit]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var record := UiTheme.label("", 20, UiTheme.SAND)
	record.name = "Record"
	v.add_child(record)
	s.visibility_changed.connect(_update_record.bind(record))
	s.visibility_changed.connect(_update_title_buttons.bind(cont, play))
	return s


## Com jogo salvo: "Continuar" (o mais recente) aparece e "Jogar" vira
## "Jogos salvos", que abre a escolha entre os 3.
func _update_title_buttons(cont: Button, play: Button) -> void:
	var saved := GameState.any_saved_game()
	cont.visible = saved
	play.text = "Jogos salvos" if saved else "Jogar"


func _update_record(record: Label) -> void:
	var parts: Array[String] = []
	if GameState.best_time > 0.0:
		parts.append("Seu recorde: %s" % GameState.format_time(GameState.best_time))
	if GameState.best_time_clock > 0.0:
		parts.append("Contra o relógio: %s" % GameState.format_clock(GameState.best_time_clock))
	record.text = "   ·   ".join(parts)


## Recomeçar apaga o jogo salvo: pede um segundo clique para confirmar.
func _confirm_restart(b: Button) -> void:
	if b.get_meta("armed", false):
		b.set_meta("armed", false)
		restart_pressed.emit()
		return
	b.set_meta("armed", true)
	b.text = "Apaga o progresso! Clique de novo"
	get_tree().create_timer(3.0, true).timeout.connect(_disarm_restart.bind(b))


func _disarm_restart(b: Button) -> void:
	if is_instance_valid(b):
		b.set_meta("armed", false)
		b.text = "Recomeçar do zero"


# ------------------------------------------------------------------ Jogos salvos

## Os 3 jogos salvos: cada um mostra quanto já foi comido e o tempo de jogo;
## um vazio começa um jogo novo. Apagar pede um segundo clique.
func _build_slots() -> Control:
	var s := _screen(0.6)
	var v := _centered_column(s)
	var t := UiTheme.display_label("Jogos salvos", 46, UiTheme.PALE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var rows: Array = []
	for slot in range(1, GameState.SLOTS + 1):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		v.add_child(h)
		var b := UiTheme.button("", 560)
		b.custom_minimum_size = Vector2(560, 74)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			if GameState.has_saved_game(slot):
				slot_chosen.emit(slot)
			else:
				_choose_mode(slot, "slots"))
		h.add_child(b)
		var del := UiTheme.button("Apagar", 170)
		del.custom_minimum_size = Vector2(170, 74)
		del.pressed.connect(_confirm_delete.bind(del, slot))
		h.add_child(del)
		rows.append([b, del, slot])
	var back := UiTheme.button("Voltar", 260)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): show_screen(_back_to))
	v.add_child(back)
	s.visibility_changed.connect(_update_slots.bind(rows))
	return s


# ------------------------------------------------------------------ Modo do jogo novo

## Jogo novo: normal (no seu ritmo) ou contra o relógio (speedrun).
func _build_mode() -> Control:
	var s := _screen(0.6)
	var v := _centered_column(s)
	var t := UiTheme.display_label("Jogo novo", 46, UiTheme.PALE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_mode_option(v, "Normal", "No seu ritmo, sem cronômetro na tela.", GameState.MODE_NORMAL)
	var clock_desc := _mode_option(v, "Contra o relógio", "", GameState.MODE_CLOCK)
	var note := UiTheme.label("O relógio só corre com o jogo rodando: pausa, mapa e habilidades param o tempo.", 17, UiTheme.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	var back := UiTheme.button("Voltar", 260)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): show_screen(_mode_back))
	v.add_child(back)
	s.visibility_changed.connect(func():
		var best := GameState.best_time_clock
		clock_desc.text = "Cronômetro na tela e tempos parciais a cada 25% dos insetos." + (
			"\nSeu recorde: " + GameState.format_clock(best) if best > 0.0 else ""))
	return s


## Um modo: o botão e, embaixo, o que ele muda. Retorna o texto de baixo.
func _mode_option(v: VBoxContainer, title: String, desc: String, which: String) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	v.add_child(box)
	var b := UiTheme.button(title, 460)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_start_new.bind(which))
	box.add_child(b)
	var l := UiTheme.label(desc, 19, UiTheme.SAND)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	return l


func _choose_mode(slot: int, back: String) -> void:
	_new_slot = slot
	_mode_back = back
	show_screen("mode")


func _start_new(which: String) -> void:
	GameState.next_mode = which
	slot_chosen.emit(_new_slot)


func _update_slots(rows: Array) -> void:
	for r in rows:
		var b: Button = r[0]
		var del: Button = r[1]
		var slot: int = r[2]
		var info := GameState.slot_summary(slot)
		del.set_meta("armed", false)
		del.text = "Apagar"
		del.visible = not info.is_empty()
		if info.is_empty():
			b.text = "  Jogo %d  ·  vazio: começar um jogo novo" % slot
		else:
			var when := Time.get_datetime_dict_from_unix_time(int(info.saved_at) + _utc_offset())
			var clock: bool = info.mode == GameState.MODE_CLOCK
			b.text = "  Jogo %d  ·  %d de %d insetos  ·  %s\n  %sSalvo em %02d/%02d às %02d:%02d" % [
				slot, info.eaten, GameState.GOAL,
				GameState.format_clock(info.elapsed) if clock else GameState.format_time(info.elapsed),
				"Contra o relógio  ·  " if clock else "", when.day, when.month, when.hour, when.minute]


static func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func _confirm_delete(b: Button, slot: int) -> void:
	if b.get_meta("armed", false):
		GameState.delete_saved_game(slot)
		_update_slots_now()
		return
	b.set_meta("armed", true)
	b.text = "Certeza?"
	get_tree().create_timer(3.0, true).timeout.connect(func():
		if is_instance_valid(b) and b.get_meta("armed", false):
			b.set_meta("armed", false)
			b.text = "Apagar")


func _update_slots_now() -> void:
	var s: Control = _screens.slots
	s.visible = false
	s.visible = true


func _goto(screen_name: String, back: String) -> void:
	_back_to = back
	show_screen(screen_name)


func _build_pause() -> Control:
	var s := _screen(0.55)
	var v := _centered_column(s)
	var t := UiTheme.display_label("Pausa", 52, UiTheme.PALE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var buttons := [
		["Continuar", func(): resume_pressed.emit()],
		["Árvore de habilidades", func(): skill_tree_pressed.emit()],
		["Estatísticas", _goto.bind("stats", "pause")],
		["Como jogar", _goto.bind("howto", "pause")],
		["Configurações", _goto.bind("settings", "pause")],
		["Recomeçar do zero", _confirm_restart],
		["Salvar e voltar ao menu", func(): main_menu_pressed.emit()],
	]
	for item in buttons:
		var b := UiTheme.button(item[0], 380)
		if item[0] == "Recomeçar do zero":
			_restart_button = b
			b.pressed.connect(item[1].bind(b))
		else:
			b.pressed.connect(item[1])
		v.add_child(b)
	return s


## Estatísticas (pela pausa): os quadros e um botão para voltar.
func _build_stats() -> Control:
	var s := _screen(0.7)
	var v := _centered_column(s)
	var t := UiTheme.display_label("Estatísticas", 46, UiTheme.PALE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_pause_stats = StatsPanel.new()
	_pause_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_pause_stats)
	var back := UiTheme.button("Voltar", 260)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): show_screen(_back_to))
	v.add_child(back)
	return s


func _build_howto() -> Control:
	var s := _screen(0.7)
	var v := _centered_column(s)
	var t := UiTheme.display_label("Como jogar", 46, UiTheme.PALE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.custom_minimum_size = Vector2(760, 0)
	text.add_theme_font_size_override("normal_font_size", 20)
	text.add_theme_font_override("bold_font", UiTheme.bold_font())
	text.add_theme_font_size_override("bold_font_size", 20)
	text.add_theme_color_override("default_color", UiTheme.CREAM)
	text.text = """[b]Objetivo:[/b] a colônia do cerrado tem [b]%s insetos[/b]. Coma todos e deixe os [b]18 formigueiros[/b] limpos.
Algumas formigas andam pelas [b]trilhas de terra[/b]; as outras moram nas [b]câmaras[/b] dos formigueiros.

[b]WASD[/b] andar · [b]Mouse[/b] olhar · [b]Shift[/b] correr (gasta a estamina)
[b]Clique esquerdo[/b] lamber: cada clique é uma lambida (com a [b]Lambida Contínua[/b], é só segurar)
[b]Q[/b] ou [b]clique direito[/b] farejar (com Farejar) · [b]E (segurado)[/b] abrir uma câmara (com Cavar) · [b]Espaço[/b] pulo do Tremor (com Tremor nível 1)
[b]TAB[/b] árvore de habilidades · [b]ESC[/b] pausa (o jogo salva sozinho) · [b]F11[/b] tela cheia

[b]Dicas[/b]
· [b]Cada 10 insetos comidos valem 1 ponto[/b], e cada habilidade tem seu preço. Dá para [b]redistribuir os pontos[/b] na árvore quando quiser.
· Habilidades com [b]cadeado[/b] e um número ("8 mil") abrem quando você tiver comido essa quantidade de insetos: 1 mil, 3 mil, 8 mil, 13 mil e 21 mil.
· A língua vai [b]reta[/b] até onde você mira (a mira fica verde quando vai pegar formiga); com [b]Mira[/b] (na Língua), ela vai sozinha atrás da mais perto.
· Suba nos formigueiros: lá de cima dá para ver dentro das câmaras abertas.
· Os montinhos de terra clara são [b]câmaras fechadas[/b]: cave para comer quem mora lá (elas saem correndo!). Algumas ficam [b]no meio do campo[/b]. Buracos maiores pedem mais [b]Cavar[/b]: as câmaras grandes pedem [b]Fundura nível 1[/b], e a [b]rainha[/b] (vale 200 formigas) mora no fundo dos formigueiros grandes: só [b]Fundura nível 2[/b] desmancha o monte inteiro.
· [b]Tanajuras[/b] (voando, douradas) ativam o [b]Frenesi[/b]: língua turbinada por 6 s.
· Correr gasta a [b]estamina[/b] (a barra verde no canto de baixo, à esquerda). Ela volta quando você para de correr; se zerar, espere a barra encher um pouco.
· Correr assusta as formigas, e sem [b]Corrida nível 2[/b] não dá para lamber enquanto corre.
· Com a clareira limpa, quebre o [b]tronco caído[/b] na saída (segure E) para abrir o caminho até o cupinzeiro gigante.
· Não dá para perder: aproveite o fim de tarde e tente bater seu recorde de tempo.""" % StatsPanel._n(GameState.GOAL)
	v.add_child(text)
	var back := UiTheme.button("Voltar", 260)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): show_screen(_back_to))
	v.add_child(back)
	return s


func _build_settings() -> Control:
	var s := _screen(0.65)
	var v := _centered_column(s)
	var t := UiTheme.display_label("Configurações", 46, UiTheme.PALE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	v.add_child(tabs)
	var stack := MarginContainer.new()
	stack.custom_minimum_size = Vector2(800, 446)
	v.add_child(stack)
	var tab_names := ["Tela", "Gráficos", "Jogo", "Controles", "Áudio"]
	for i in tab_names.size():
		var b := UiTheme.button(tab_names[i], 150)
		b.toggle_mode = true
		b.pressed.connect(_show_settings_tab.bind(i))
		tabs.add_child(b)
		_settings_tab_buttons.append(b)
	# Tela
	var g := _settings_page(stack)
	_add_option(g, "window_mode", "Modo de tela", Settings.WINDOW_MODE_NAMES)
	var res_names := []
	var res_values := []
	for r in Settings.available_resolutions():
		res_names.append("%d × %d" % [r.x, r.y])
		res_values.append(r)
	_add_option(g, "resolution", "Resolução", res_names, res_values)
	var scale_names := []
	for k in Settings.RENDER_SCALES:
		scale_names.append("%d%%" % int(round(k * 100.0)))
	_add_option(g, "render_scale", "Resolução do 3D", scale_names, Settings.RENDER_SCALES)
	_add_check(g, "vsync", "Sincronia vertical (VSync)")
	var fps_names := []
	for f in Settings.FPS_LIMITS:
		fps_names.append("Sem limite" if f == 0 else str(f))
	_add_option(g, "max_fps", "Limite de FPS", fps_names, Settings.FPS_LIMITS)
	# Gráficos
	g = _settings_page(stack)
	_add_option(g, "graphics_quality", "Qualidade", Settings.QUALITY_NAMES)
	_add_option(g, "shadow_quality", "Sombras", Settings.SHADOW_NAMES)
	_add_option(g, "grass_quality", "Capim", Settings.GRASS_NAMES)
	_add_option(g, "antialiasing", "Suavização (anti-aliasing)", Settings.AA_NAMES)
	_add_check(g, "ssao", "Sombra de contato (SSAO)")
	_add_check(g, "ssil", "Luz rebatida (SSIL)")
	_add_check(g, "volumetric_fog", "Neblina volumétrica")
	_add_check(g, "glow", "Brilho do sol (bloom)")
	# Jogo
	g = _settings_page(stack)
	_add_slider(g, "mouse_sensitivity", "Sensibilidade do mouse", 0.05, 0.6)
	_add_slider(g, "gamepad_sensitivity", "Sensibilidade do controle", 0.3, 2.5)
	_add_check(g, "invert_y", "Inverter eixo Y")
	_add_slider(g, "fov", "Campo de visão", 60.0, 100.0)
	_add_slider(g, "camera_bob", "Balanço da câmera", 0.0, 1.0)
	_add_option(g, "sniff_color_index", "Cor do faro", Settings.SNIFF_COLOR_NAMES)
	_add_option(g, "hints_level", "Dicas", Settings.HINTS_NAMES)
	_add_check(g, "show_hud", "Mostrar a interface (HUD)")
	# Controles
	_build_controls_page(stack)
	# Áudio
	g = _settings_page(stack)
	_add_slider(g, "master_volume", "Volume geral", 0.0, 1.0)
	_add_slider(g, "music_volume", "Música", 0.0, 1.0)
	_add_slider(g, "sfx_volume", "Efeitos", 0.0, 1.0)
	_add_slider(g, "ambience_volume", "Ambiente (vento, bichos)", 0.0, 1.0)
	_settings_note = UiTheme.label("", 16, UiTheme.SAND)
	_settings_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_settings_note)
	var back := UiTheme.button("Voltar", 260)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): show_screen(_back_to))
	v.add_child(back)
	Settings.changed.connect(_sync_settings)
	Settings.changed.connect(_sync_keys)
	s.visibility_changed.connect(_sync_settings)
	_show_settings_tab(0)
	return s


## Abre as configurações numa aba (usado também pelos testes: --start=settings --tab=N).
func open_settings(tab: int = 0) -> void:
	_goto("settings", "title")
	_show_settings_tab(clampi(tab, 0, _settings_pages.size() - 1))


## Aba Controles: segurar ou apertar (Correr e Cavar) e as teclas de cada ação.
func _build_controls_page(stack: Control) -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	stack.add_child(page)
	_settings_pages.append(page)
	var top := GridContainer.new()
	top.columns = 2
	top.add_theme_constant_override("h_separation", 26)
	top.add_theme_constant_override("v_separation", 8)
	page.add_child(top)
	_add_option(top, "run_toggle", "Correr", ["Segurar a tecla", "Apertar para ligar e desligar"], [false, true])
	_add_option(top, "dig_toggle", "Cavar", ["Segurar a tecla", "Apertar uma vez"], [false, true])
	var keys := GridContainer.new()
	keys.columns = 4
	keys.add_theme_constant_override("h_separation", 18)
	keys.add_theme_constant_override("v_separation", 6)
	page.add_child(keys)
	for pair in Settings.REBINDABLE:
		var l := UiTheme.label(pair[1], 18)
		l.add_theme_font_override("font", UiTheme.semi_font())
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.custom_minimum_size.x = 220
		keys.add_child(l)
		var b := UiTheme.button("", 150)
		b.custom_minimum_size = Vector2(150, 40)
		b.pressed.connect(_start_rebind.bind(pair[0]))
		keys.add_child(b)
		_key_buttons[pair[0]] = b
	var reset := UiTheme.button("Restaurar as teclas", 300)
	reset.custom_minimum_size.y = 44
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(func():
		_rebinding = ""
		Settings.reset_bindings())
	page.add_child(reset)
	_sync_keys()


func _sync_keys() -> void:
	for action in _key_buttons:
		var b: Button = _key_buttons[action]
		b.text = "Aperte uma tecla..." if action == _rebinding else Settings.key_label(action)


func _start_rebind(action: String) -> void:
	_rebinding = action
	_sync_keys()


## Esperando uma tecla nova: a próxima tecla ou botão do mouse vira a tecla da ação.
func _input(event: InputEvent) -> void:
	if _rebinding == "" or not visible:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
				MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT])
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	var action := _rebinding
	_rebinding = ""
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_sync_keys()
		return
	Settings.rebind(action, event)
	_sync_keys()

func _settings_page(stack: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 10)
	stack.add_child(grid)
	_settings_pages.append(grid)
	return grid


func _show_settings_tab(i: int) -> void:
	for k in _settings_pages.size():
		_settings_pages[k].visible = k == i
		_settings_tab_buttons[k].set_pressed_no_signal(k == i)
	_settings_note.text = [
		"F11 ou Alt+Enter liga e desliga a tela cheia. Em tela cheia, a resolução muda só o 3D (a interface fica nítida).",
		"Escolher uma qualidade ajusta todos os itens; mexer num item deixa a qualidade \"Personalizada\".",
		"Dicas \"Poucas\": só o que dá para fazer perto de você. \"Todas\": também ensina os controles, cada um até você usar.",
		"Clique numa tecla e aperte a nova (Esc cancela). No controle, os botões ficam como estão.",
		"",
	][i]


func _setting_label(grid: GridContainer, text: String) -> void:
	var l := UiTheme.label(text, 21)
	l.add_theme_font_override("font", UiTheme.semi_font())
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(l)


func _add_option(grid: GridContainer, key: String, text: String, names: Array, values: Array = []) -> void:
	_setting_label(grid, text)
	var ob := OptionButton.new()
	for i in names.size():
		ob.add_item(String(names[i]), i)
	ob.custom_minimum_size = Vector2(330, 44)
	ob.set_meta("values", values)
	ob.item_selected.connect(_on_option.bind(key, ob))
	grid.add_child(ob)
	_settings_controls[key] = ob


func _on_option(i: int, key: String, ob: OptionButton) -> void:
	var values: Array = ob.get_meta("values")
	Settings.set_value(key, values[i] if not values.is_empty() else i)


func _add_check(grid: GridContainer, key: String, text: String) -> void:
	_setting_label(grid, text)
	var cb := CheckBox.new()
	cb.toggled.connect(func(on): Settings.set_value(key, on))
	grid.add_child(cb)
	_settings_controls[key] = cb


func _add_slider(grid: GridContainer, key: String, text: String, lo: float, hi: float) -> void:
	_setting_label(grid, text)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = (hi - lo) / 100.0
	sl.custom_minimum_size = Vector2(330, 32)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.value_changed.connect(func(x): Settings.set_value(key, x))
	grid.add_child(sl)
	_settings_controls[key] = sl


## Mostra nos controles o que está valendo agora (ex.: depois de trocar o preset).
func _sync_settings() -> void:
	for key in _settings_controls:
		var c: Control = _settings_controls[key]
		var value = Settings.get(key)
		if c is OptionButton:
			var ob := c as OptionButton
			var values: Array = ob.get_meta("values")
			var idx := -1
			if values.is_empty():
				idx = int(value)
			else:
				var best := INF
				for i in values.size():
					var d := 0.0
					if value is Vector2i:
						d = 0.0 if values[i] == value else 1.0
					else:
						d = absf(float(values[i]) - float(value))
					if d < best:
						best = d
						idx = i
			if idx >= 0 and idx < ob.item_count and ob.selected != idx:
				ob.select(idx)
		elif c is CheckBox:
			(c as CheckBox).set_pressed_no_signal(bool(value))
		elif c is HSlider:
			(c as HSlider).set_value_no_signal(float(value))


func _build_end() -> Control:
	var s := _screen(0.45)
	var v := _centered_column(s)
	_end_title = UiTheme.display_label("Fim da demo!", 60, UiTheme.PALE)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_title)
	_end_sub = UiTheme.label("Você comeu os %s insetos da clareira e abriu o caminho\naté o cupinzeiro gigante." % StatsPanel._n(GameState.GOAL), 24, UiTheme.CREAM)
	_end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_sub)
	_end_time = UiTheme.label("", 24, UiTheme.SAND)
	_end_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_time)
	_end_stats = StatsPanel.new()
	_end_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_end_stats)
	var thanks := UiTheme.label("Obrigado por jogar a demo!", 20, UiTheme.CREAM)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(thanks)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 18)
	v.add_child(h)
	var again := UiTheme.button("Jogar de novo", 280)
	again.pressed.connect(func(): restart_pressed.emit())
	h.add_child(again)
	var menu := UiTheme.button("Menu principal", 280)
	menu.pressed.connect(func(): main_menu_pressed.emit())
	h.add_child(menu)
	return s


func _record_text(new_record: bool) -> String:
	if new_record:
		return "  (novo recorde!)"
	var best := GameState.mode_best_time()
	if best > 0.0:
		return "  (recorde: %s)" % _fmt(best)
	return ""


## No modo contra o relógio os tempos aparecem com décimos.
func _fmt(t: float) -> String:
	return GameState.format_clock(t) if GameState.mode == GameState.MODE_CLOCK else GameState.format_time(t)


func show_end(time_sec: float, new_record: bool) -> void:
	_end_time.text = "%sTempo: %s%s" % [
		"Contra o relógio  ·  " if GameState.mode == GameState.MODE_CLOCK else "",
		_fmt(time_sec), _record_text(new_record)]
	_end_stats.refresh()
	show_screen("end")


## Enfeite embaixo do nome do jogo: um traço dourado que some nas pontas e um losango.
class Divider extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var gold := Color("e8b44f")
		var y := size.y * 0.5
		var mid := 150.0
		draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(mid - 10.0, y)]),
			PackedColorArray([Color(gold, 0.15), gold]), 1.5, true)
		draw_polyline_colors(PackedVector2Array([Vector2(mid + 10.0, y), Vector2(size.x, y)]),
			PackedColorArray([gold, Color(gold, 0.0)]), 1.5, true)
		var c := Vector2(mid, y)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), gold)
		draw_circle(c + Vector2(-16, 0), 2.0, gold)
		draw_circle(c + Vector2(16, 0), 2.0, gold)
