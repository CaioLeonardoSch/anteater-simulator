extends Control
## Menus da demo: tela inicial, pausa, configurações, "como jogar" e tela final.
## Um único nó com várias telas; o Main troca entre elas.

signal play_pressed
signal continue_pressed
signal resume_pressed
signal restart_pressed
signal main_menu_pressed
signal skill_tree_pressed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

var _screens: Dictionary = {}
var _current := ""
var _back_to := "title"
var _end_stats: Label
var _end_title: Label
var _restart_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screens.title = _build_title()
	_screens.pause = _build_pause()
	_screens.settings = _build_settings()
	_screens.howto = _build_howto()
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
	if screen_name != "":
		var first := _find_first_button(_screens[screen_name])
		if first:
			first.grab_focus.call_deferred()


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
		bg.color = Color(0.05, 0.02, 0.02, dim)
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
	var t := UiTheme.label("Preparando o cerrado...", 34, UiTheme.SAND, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return s


func _build_title() -> Control:
	var s := _screen(0.0)
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.08, 0.03, 0.02, 0.0))
	g.set_color(1, Color(0.08, 0.03, 0.02, 0.75))
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
	var title := UiTheme.label("Anteater\nSimulator", 96, UiTheme.CREAM, true)
	title.add_theme_constant_override("line_spacing", -22)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Color(0.45, 0.16, 0.08))
	v.add_child(title)
	var sub := UiTheme.label("Demo · Fase 1: Cerrado ao Entardecer", 28, UiTheme.GOLD, true)
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.05))
	v.add_child(sub)
	var tag := UiTheme.label("Você é um tamanduá-bandeira faminto. A colônia tem 1000 formigas.\nComa todas e evolua a cada 100.", 21, UiTheme.CREAM)
	tag.add_theme_constant_override("outline_size", 5)
	tag.add_theme_color_override("font_outline_color", Color(0.15, 0.06, 0.03, 0.9))
	v.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	v.add_child(gap)
	var cont := UiTheme.button("Continuar")
	cont.name = "Continue"
	cont.pressed.connect(func(): continue_pressed.emit())
	v.add_child(cont)
	var play := UiTheme.button("Jogar")
	play.name = "Play"
	play.pressed.connect(func(): play_pressed.emit())
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


## Com jogo salvo: "Continuar" aparece e "Jogar" vira "Novo jogo".
func _update_title_buttons(cont: Button, play: Button) -> void:
	var saved := GameState.has_saved_game()
	cont.visible = saved
	play.text = "Novo jogo" if saved else "Jogar"


func _update_record(record: Label) -> void:
	if GameState.best_time > 0.0:
		record.text = "Seu recorde: 1000 formigas em %s" % GameState.format_time(GameState.best_time)
	else:
		record.text = ""


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


func _goto(screen_name: String, back: String) -> void:
	_back_to = back
	show_screen(screen_name)


func _build_pause() -> Control:
	var s := _screen(0.55)
	var v := _centered_column(s)
	var t := UiTheme.label("Pausa", 48, UiTheme.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var buttons := [
		["Continuar", func(): resume_pressed.emit()],
		["Árvore de habilidades", func(): skill_tree_pressed.emit()],
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


func _build_howto() -> Control:
	var s := _screen(0.7)
	var v := _centered_column(s)
	var t := UiTheme.label("Como jogar", 44, UiTheme.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.custom_minimum_size = Vector2(760, 0)
	text.add_theme_font_size_override("normal_font_size", 20)
	text.add_theme_font_override("bold_font", UiTheme.FONT_BOLD)
	text.add_theme_font_size_override("bold_font_size", 20)
	text.add_theme_color_override("default_color", UiTheme.CREAM)
	text.text = """[b]Objetivo:[/b] a colônia do cerrado tem [b]1000 formigas[/b]. Coma todas e deixe os [b]8 formigueiros[/b] limpos.
Algumas formigas andam pelas [b]trilhas de terra[/b] e chegam em [b]ondas[/b]; as outras moram nas [b]câmaras[/b] dos formigueiros.

[b]WASD[/b] andar · [b]Mouse[/b] olhar · [b]Shift[/b] correr (depois de aprender Corrida)
[b]Clique esquerdo (segurado)[/b] lamber: a língua vai até a mira e gruda uma formiga (com a Lambida, gruda várias)
[b]Q[/b] ou [b]clique direito[/b] farejar · [b]E (segurado)[/b] abrir uma câmara (com Cavar)
[b]TAB[/b] árvore de habilidades · [b]ESC[/b] pausa (o jogo salva sozinho)

[b]Dicas[/b]
· Os montinhos de terra clara nos formigueiros são [b]câmaras fechadas[/b]: cave para comer quem mora lá.
· Os formigueiros grandes guardam uma [b]rainha[/b]: coma as formigas em volta dela e ela vale 20.
· [b]Tanajuras[/b] (voando, douradas) ativam o [b]Frenesi[/b]: língua turbinada por 6 s.
· Correr assusta as formigas: chegue andando e lamba de longe.
· A cada [b]100 formigas[/b], 1 ponto de habilidade. Dá para [b]redistribuir os pontos[/b] na árvore quando quiser.
· Não dá para perder: aproveite o pôr do sol e tente bater seu recorde de tempo."""
	v.add_child(text)
	var back := UiTheme.button("Voltar", 260)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): show_screen(_back_to))
	v.add_child(back)
	return s


func _build_settings() -> Control:
	var s := _screen(0.65)
	var v := _centered_column(s)
	var t := UiTheme.label("Configurações", 44, UiTheme.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 14)
	v.add_child(grid)
	# Qualidade.
	grid.add_child(UiTheme.label("Qualidade gráfica", 22))
	var q := OptionButton.new()
	for i in Settings.QUALITY_NAMES.size():
		q.add_item(Settings.QUALITY_NAMES[i], i)
	q.selected = Settings.graphics_quality
	q.custom_minimum_size = Vector2(300, 48)
	q.item_selected.connect(func(i): Settings.set_value("graphics_quality", i))
	grid.add_child(q)
	_add_slider(grid, "Sensibilidade do mouse", 0.05, 0.6, Settings.mouse_sensitivity, func(x): Settings.set_value("mouse_sensitivity", x))
	_add_slider(grid, "Campo de visão", 60.0, 100.0, Settings.fov, func(x): Settings.set_value("fov", x))
	_add_slider(grid, "Volume geral", 0.0, 1.0, Settings.master_volume, func(x): Settings.set_value("master_volume", x))
	_add_slider(grid, "Volume da música", 0.0, 1.0, Settings.music_volume, func(x): Settings.set_value("music_volume", x))
	grid.add_child(UiTheme.label("Inverter eixo Y", 22))
	var inv := CheckBox.new()
	inv.button_pressed = Settings.invert_y
	inv.toggled.connect(func(on): Settings.set_value("invert_y", on))
	grid.add_child(inv)
	grid.add_child(UiTheme.label("Tela cheia", 22))
	var fs := CheckBox.new()
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on): Settings.set_value("fullscreen", on))
	grid.add_child(fs)
	var note := UiTheme.label("A densidade do capim muda ao recomeçar a fase.", 16, UiTheme.SAND)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	var back := UiTheme.button("Voltar", 260)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): show_screen(_back_to))
	v.add_child(back)
	return s


func _add_slider(grid: GridContainer, text: String, lo: float, hi: float, value: float, cb: Callable) -> void:
	grid.add_child(UiTheme.label(text, 22))
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = (hi - lo) / 100.0
	sl.value = value
	sl.custom_minimum_size = Vector2(300, 32)
	sl.value_changed.connect(cb)
	grid.add_child(sl)


func _build_end() -> Control:
	var s := _screen(0.45)
	var v := _centered_column(s)
	_end_title = UiTheme.label("Fase concluída!", 56, UiTheme.GOLD, true)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_title)
	var sub := UiTheme.label("Você comeu as 1000 formigas da colônia do cerrado.", 24, UiTheme.CREAM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_end_stats = UiTheme.label("", 22, UiTheme.SAND)
	_end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	if GameState.best_time > 0.0:
		return "  (recorde: %s)" % GameState.format_time(GameState.best_time)
	return ""


func show_end(time_sec: float, new_record: bool) -> void:
	var learned := []
	for u in GameState.UPGRADES:
		if GameState.has(u.id):
			learned.append(u.name)
	var lines := "Tempo: %s%s\nMaior combo: %d formigas\nTanajuras comidas: %d\nHabilidades: %s" % [
		GameState.format_time(time_sec), _record_text(new_record),
		GameState.best_combo, GameState.tanajuras_eaten, ", ".join(learned) if not learned.is_empty() else "nenhuma"]
	_end_stats.text = lines
	_end_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_stats.custom_minimum_size = Vector2(760, 0)
	show_screen("end")
