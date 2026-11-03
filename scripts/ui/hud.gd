extends Control
## HUD da partida, no estilo Constelação: medalhão com as formigas comidas,
## painel de pontos e formigueiros, bússola numa faixa com moldura dourada (só o
## formigueiro para onde você olha mostra nome e distância), relógio e ondas,
## mira, habilidades em círculos (como na árvore) e avisos.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Glyphs := preload("res://scripts/ui/glyphs.gd")

var player
var swarm
var colony
var world

var _medallion: Medallion
var _points_value: Label
var _next_bar: GoldBar
var _next_label: Label
var _nests_value: Label
var _saved_label: Label
var _queen_note_next := 0.0
var _help_next := 0.0
var _points_badge: PanelContainer
var _points_label: Label
var _timer_label: Label
var _wave_label: Label
## Aviso de onda no painel da direita (em vez de no meio da tela).
var _wave_note := ""
var _wave_note_time := 0.0
## 0 = estado da onda (caixa alta), 1 = aviso de onda (texto normal).
var _wave_mode := -1
var _compass: Compass
var _crosshair: Crosshair
var _notes: VBoxContainer
var _big_box: VBoxContainer
var _big_note: Label
var _big_sub: Label
var _big_time := 0.0
var _hint: Label
var _controls_hint: Label
var _controls_time := 14.0
var _abilities: Array = []
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _popups: Control
var _shown_count := 0.0

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform float amount = 0.0;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.0, 0.75));
	float v = smoothstep(0.32, 0.75, d);
	float pulse = 0.85 + 0.15 * sin(TIME * 6.0);
	COLOR = vec4(tint.rgb, v * amount * pulse);
}
"""


func setup(p, sw, col, w) -> void:
	player = p
	swarm = sw
	colony = col
	world = w
	_compass.player = p
	_compass.world = w
	_crosshair.player = p
	_crosshair.swarm = sw
	player.ate.connect(_on_ate)
	player.dug.connect(_on_dug)
	player.tremor_used.connect(func(n): note("Tremor! %d formigas ficaram tontas" % n, UiTheme.SAND))
	player.sniffed.connect(_on_sniffed)
	player.queen_blocked.connect(_on_queen_blocked)
	player.lick_blocked_running.connect(_on_lick_blocked_running)
	colony.wave_announced.connect(_on_wave)
	colony.final_wave.connect(func(_n): big_note("Reta final das trilhas", "As últimas forrageiras saíram de casa. O resto está nas câmaras!"))
	colony.chamber_cleaned.connect(_on_chamber_cleaned)
	colony.nest_cleaned.connect(_on_nest_cleaned)
	colony.queen_eaten.connect(func(_nest): big_note("Rainha!", "Ela valeu 20 formigas", 4.0))
	GameState.ants_eaten_changed.connect(_on_eaten_changed)
	GameState.upgrade_affordable.connect(_on_affordable)
	GameState.skills_reset.connect(_refresh_points)
	GameState.frenzy_changed.connect(func(on): if on: big_note("Frenesi!", "Você comeu uma tanajura: língua turbinada por 6 s"))
	GameState.upgrade_purchased.connect(func(_id): _refresh_points())
	_on_eaten_changed(GameState.ants_eaten, 0)
	_refresh_points()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = sh
	_vignette.material = _vignette_mat
	add_child(_vignette)
	_build_counter()
	_build_top_right()
	_compass = Compass.new()
	add_child(_compass)
	_place(_compass, Control.PRESET_CENTER_TOP, Vector2(-350, 10), Vector2(700, 104))
	_crosshair = Crosshair.new()
	add_child(_crosshair)
	_place(_crosshair, Control.PRESET_CENTER, Vector2(-40, -40), Vector2(80, 80))
	_notes = VBoxContainer.new()
	_notes.alignment = BoxContainer.ALIGNMENT_BEGIN
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notes)
	_place(_notes, Control.PRESET_CENTER_TOP, Vector2(-450, 126), Vector2(900, 140))
	_build_big_note()
	_hint = UiTheme.label("", 22, UiTheme.CREAM)
	_hint.add_theme_font_override("font", UiTheme.semi_font())
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_soft_shadow(_hint)
	add_child(_hint)
	_place(_hint, Control.PRESET_CENTER, Vector2(-500, 72), Vector2(1000, 40))
	_build_abilities()
	_controls_hint = UiTheme.label(
		"WASD andar  ·  Mouse olhar  ·  Clique: lamber  ·  Q ou botão direito: farejar  ·  TAB: habilidades",
		19, UiTheme.CREAM)
	_controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_soft_shadow(_controls_hint)
	add_child(_controls_hint)
	_place(_controls_hint, Control.PRESET_CENTER_BOTTOM, Vector2(-640, -182), Vector2(1280, 56))
	_popups = Control.new()
	_popups.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popups)


## Texto sobre o cenário: sem contorno, com uma sombra escura macia por trás.
func _soft_shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0.02, 0.012, 0.01, 0.85))
	l.add_theme_constant_override("shadow_outline_size", 5)
	l.add_theme_constant_override("shadow_offset_y", 1)


## Posiciona um controle por âncora + deslocamento (independe do tamanho da tela).
func _place(c: Control, preset: int, offset: Vector2, box_size: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + box_size.x
	c.offset_bottom = offset.y + box_size.y


## Medalhão com as formigas comidas, painel de pontos e o aviso de [TAB].
func _build_counter() -> void:
	_medallion = Medallion.new()
	_medallion.position = Vector2(24, 18)
	_medallion.size = Vector2(116, 116)
	_medallion.sub = "de %d" % GameState.GOAL
	add_child(_medallion)
	var col := VBoxContainer.new()
	col.position = Vector2(152, 24)
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_frame())
	panel.custom_minimum_size = Vector2(262, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	var pts_label := UiTheme.caps_label("Pontos", 12)
	pts_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pts_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pts_label)
	_points_value = UiTheme.display_label("0", 23, UiTheme.GOLD)
	row.add_child(_points_value)
	_next_bar = GoldBar.new()
	_next_bar.custom_minimum_size = Vector2(0, 12)
	v.add_child(_next_bar)
	_next_label = UiTheme.label("", 16, UiTheme.SAND)
	v.add_child(_next_label)
	var line := ColorRect.new()
	line.color = Color(UiTheme.GOLD, 0.22)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	var row2 := HBoxContainer.new()
	v.add_child(row2)
	var nests_label := UiTheme.caps_label("Formigueiros limpos", 11)
	nests_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nests_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row2.add_child(nests_label)
	_nests_value = UiTheme.display_label("0/12", 19, UiTheme.LEAF)
	row2.add_child(_nests_value)
	# Aviso de habilidade para aprender.
	_points_badge = PanelContainer.new()
	var badge := UiTheme.frame(Color(0.05, 0.035, 0.028, 0.92), Color(0.03, 0.022, 0.018, 0.92), UiTheme.GOLD,
		Color(0, 0, 0, 0), 12, 5)
	badge.glow = 0.7
	_points_badge.add_theme_stylebox_override("panel", badge)
	_points_badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(_points_badge)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 9)
	_points_badge.add_child(h)
	var dia := Diamond.new()
	dia.custom_minimum_size = Vector2(10, 10)
	dia.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dia)
	_points_label = UiTheme.caps_label("", 13, UiTheme.PALE)
	_points_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_points_label)
	h.add_child(_key_chip("Tab"))


## Tecla num quadradinho com borda dourada (TAB, E...).
func _key_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.02, 0.018, 0.9)
	box.border_color = Color(UiTheme.GOLD, 0.75)
	box.set_border_width_all(1)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 0
	box.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", box)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UiTheme.display_label(text, 14, UiTheme.GOLD)
	l.add_theme_font_override("font", UiTheme.display_bold_font())
	chip.add_child(l)
	return chip


func _build_top_right() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_frame(16, 9))
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	_place(panel, Control.PRESET_TOP_RIGHT, Vector2(-238, 24), Vector2(214, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	panel.add_child(v)
	_timer_label = UiTheme.display_label("0:00", 30, UiTheme.PALE)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_timer_label)
	_wave_label = UiTheme.caps_label("", 12)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wave_label.custom_minimum_size = Vector2(180, 0)
	v.add_child(_wave_label)


## Aviso grande no meio da tela: título em Alegreya SC entre dois enfeites dourados.
func _build_big_note() -> void:
	_big_box = VBoxContainer.new()
	_big_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_big_box.add_theme_constant_override("separation", 2)
	_big_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_big_box)
	_place(_big_box, Control.PRESET_CENTER, Vector2(-700, -178), Vector2(1400, 130))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_box.add_child(row)
	var left := Flourish.new()
	left.custom_minimum_size = Vector2(150, 20)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)
	_big_note = UiTheme.display_label("", 58, UiTheme.PALE)
	_big_note.add_theme_constant_override("outline_size", 8)
	_big_note.add_theme_color_override("font_outline_color", Color(0.06, 0.035, 0.02, 0.92))
	_big_note.add_theme_color_override("font_shadow_color", Color(UiTheme.GOLD, 0.45))
	_big_note.add_theme_constant_override("shadow_outline_size", 18)
	_big_note.add_theme_constant_override("shadow_offset_y", 0)
	row.add_child(_big_note)
	var right := Flourish.new()
	right.mirror = true
	right.custom_minimum_size = Vector2(150, 20)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	_big_sub = UiTheme.label("", 25, UiTheme.CREAM)
	_big_sub.add_theme_font_override("font", UiTheme.semi_font())
	_big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_soft_shadow(_big_sub)
	_big_box.add_child(_big_sub)
	_big_box.modulate.a = 0.0


func _build_abilities() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_place(row, Control.PRESET_CENTER_BOTTOM, Vector2(-280, -128), Vector2(560, 112))
	var b: Array = GameState.BRANCHES
	var defs := [
		{"key": "Clique", "name": "Lamber", "kind": "lick", "glyph": "tongue", "tint": b[0].color, "primary": true},
		{"key": "Q", "name": "Farejar", "kind": "sniff", "glyph": "nose", "tint": b[3].color, "primary": false},
		{"key": "E", "name": "Cavar", "kind": "dig", "glyph": "claws", "tint": b[1].color, "primary": false},
		{"key": "Espaço", "name": "Tremor", "kind": "tremor", "glyph": "burst", "tint": b[1].color, "primary": false},
	]
	for d in defs:
		var a := AbilityIcon.new()
		a.kind = d.kind
		a.key_text = d.key
		a.name_text = d.name
		a.glyph = d.glyph
		a.tint = d.tint
		a.primary = d.primary
		a.custom_minimum_size = Vector2(104, 112)
		row.add_child(a)
		_abilities.append(a)


func _process(delta: float) -> void:
	if player == null:
		return
	_shown_count = move_toward(_shown_count, GameState.ants_eaten, maxf(delta * 60.0, absf(GameState.ants_eaten - _shown_count) * delta * 8.0))
	var shown := str(int(round(_shown_count)))
	if _medallion.value != shown:
		_medallion.value = shown
		_medallion.queue_redraw()
	_timer_label.text = GameState.format_time(GameState.elapsed)
	var wave_active: bool = colony._wave.size() > 0
	_nests_value.text = "%d/%d" % [colony.nests_cleaned(), world.nests.size()]
	_wave_note_time = maxf(_wave_note_time - delta, 0.0)
	if _wave_note_time > 0.0:
		# Aviso de onda: texto normal, dourado (é mais longo).
		_set_wave_mode(1)
		_wave_label.text = _wave_note
	else:
		_set_wave_mode(0)
		var text := ""
		if colony.final_released:
			if colony.outside_total() == 0:
				text = "FALTAM %d NAS CÂMARAS" % colony.remaining()
			else:
				text = "RETA FINAL: %d RESTANTES" % colony.remaining()
		elif wave_active:
			text = "ONDA %d CHEGANDO!" % colony.wave_number
		else:
			text = "PRÓXIMA ONDA EM %d s" % int(ceil(colony.wave_timer))
		_wave_label.text = text
		_wave_label.add_theme_color_override("font_color", UiTheme.PALE if wave_active else UiTheme.MUTED)
	# Habilidades.
	for a in _abilities:
		match a.kind:
			"lick":
				a.locked = false
				a.cooldown = 0.0
			"sniff":
				a.locked = not GameState.can_sniff()
				a.seconds = player.sniff_cd
				a.cooldown = player.sniff_cd / GameState.sniff_cooldown() if player.sniff_cd > 0.0 else 0.0
			"dig":
				a.locked = not GameState.can_dig()
				a.seconds = player.dig_cd
				a.cooldown = player.dig_cd / GameState.dig_cooldown() if player.dig_cd > 0.0 else 0.0
				a.progress = player.dig_progress
			"tremor":
				a.locked = not GameState.can_tremor()
				a.seconds = player.tremor_cd
				a.cooldown = player.tremor_cd / GameState.tremor_cooldown() if player.tremor_cd > 0.0 else 0.0
		a.queue_redraw()
	# Dica de contexto.
	_hint.text = _context_hint()
	_maybe_help()
	if _controls_time > 0.0:
		_controls_time -= delta
		_controls_hint.modulate.a = clampf(_controls_time / 2.0, 0.0, 1.0)
	if _big_time > 0.0:
		_big_time -= delta
		_big_box.modulate.a = clampf(_big_time / 0.6, 0.0, 1.0)
	var vig := 0.0
	if GameState.frenzy_active():
		vig = 0.55
		_vignette_mat.set_shader_parameter("tint", Color(1.0, 0.45, 0.2))
	elif player.sniff_left > 0.0:
		vig = clampf(player.sniff_left, 0.0, 1.0) * 0.35
		_vignette_mat.set_shader_parameter("tint", Settings.sniff_color())
	_vignette_mat.set_shader_parameter("amount", vig)
	_compass.queue_redraw()
	_crosshair.queue_redraw()


func _set_wave_mode(mode: int) -> void:
	if mode == _wave_mode:
		return
	_wave_mode = mode
	if mode == 1:
		_wave_label.add_theme_font_override("font", UiTheme.semi_font())
		_wave_label.add_theme_font_size_override("font_size", 15)
		_wave_label.add_theme_color_override("font_color", UiTheme.GOLD)
	else:
		_wave_label.add_theme_font_override("font", UiTheme.caps_font())
		_wave_label.add_theme_font_size_override("font_size", 12)


func _on_eaten_changed(_total: int, _delta: int) -> void:
	_refresh_points()


## Pontos para gastar, barra até a próxima habilidade e o aviso de [TAB].
func _refresh_points() -> void:
	var pts := GameState.points_available()
	var goal := GameState.next_goal()
	_points_value.text = str(pts)
	if goal.is_empty():
		_next_bar.value = 1.0 if GameState.affordable_count() > 0 or pts > 0 else 0.0
		if GameState.affordable_count() > 0:
			_next_label.text = "Gaste os pontos na árvore [TAB]"
		else:
			_next_label.text = "Tudo aprendido por aqui"
	else:
		_next_bar.value = clampf(float(pts) / float(goal.cost), 0.0, 1.0)
		_next_label.text = "Próxima: %s · %d" % [goal.name, goal.cost]
	_next_bar.queue_redraw()
	var n := GameState.affordable_count()
	_points_badge.visible = n > 0
	if n == 1:
		for u in GameState.UPGRADES:
			if GameState.can_buy(u.id):
				_points_label.text = ("Dá para aprender: %s" % u.name).to_upper()
				break
	else:
		_points_label.text = ("%d habilidades para aprender" % n).to_upper()


func _on_affordable(id: String) -> void:
	_refresh_points()
	var u := GameState.get_upgrade(id)
	Sfx.play("point", -2.0)
	note("Já dá para aprender %s (%d pontos)  [TAB]" % [u.name, u.cost], UiTheme.GOLD, 3.5)


func _on_lick_blocked_running() -> void:
	note("Correndo não dá para lamber: solte o Shift (ou aprenda Lamber Correndo)", UiTheme.SAND, 3.0)


func _context_hint() -> String:
	if player.dig_nest != null:
		if not GameState.can_dig():
			return "Câmara fechada: aprenda Cavar (Garras) na árvore [TAB]"
		if player.dig_cd > 0.0:
			return "As garras estão descansando: %d s" % int(ceil(player.dig_cd))
		var c = player.dig_nest.chambers[player.dig_chamber]
		if c.royal:
			return "Segure E para abrir a câmara da rainha"
		return "Segure E para abrir esta câmara do campo" if c.satellite else "Segure E para abrir a câmara"
	# Câmara aberta por perto (no monte ou no campo).
	var p2 := Vector2(player.global_position.x, player.global_position.z)
	# Tronco caído na saída para a área 2.
	if not world.exit_open and world.near_exit(p2, 4.5):
		if not world.exit_breakable:
			return "Um tronco caído fecha a passagem. Limpe a clareira primeiro (faltam %d formigas)" % colony.remaining()
		if not GameState.can_dig():
			return "Aprenda Cavar (Garras) na árvore [TAB] para quebrar o tronco"
		return "Segure E para quebrar o tronco com as garras"
	for n in world.nests:
		var ci: int = n.open_chamber_near(p2, 3.0)
		if ci < 0:
			continue
		var c = n.chambers[ci]
		if c.royal and n.queen_alive and c.residents > 0:
			return "Rainha protegida: faltam %d formigas nesta câmara" % c.residents
		if c.royal and n.queen_alive:
			return "A rainha está sozinha: lamba!"
		return "Câmara aberta: %d formigas" % c.residents
	var nest = player.near_nest
	if nest == null:
		return ""
	if nest.cleaned:
		return "%s limpo!" % nest.display_name
	if nest.closed_chambers() > 0:
		var field: int = nest.closed_chambers() - _closed_on_mound(nest)
		if field > 0 and _closed_on_mound(nest) == 0:
			return "%s: faltam %d câmaras no campo (fareje!)" % [nest.display_name, field]
		return "%s: %d câmaras fechadas" % [nest.display_name, nest.closed_chambers()]
	return nest.display_name


func _closed_on_mound(nest) -> int:
	var n := 0
	for c in nest.chambers:
		if not c.opened and not c.satellite:
			n += 1
	return n


## Ajuda quando só restam formigas dentro das câmaras.
func _maybe_help() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _help_next or colony.outside_total() > 0 or colony.pools_total() > 0:
		return
	if colony.closed_chambers_total() == 0:
		return
	_help_next = now + 45.0
	if GameState.can_dig():
		note("As formigas que faltam estão dentro dos formigueiros: cave as câmaras fechadas", UiTheme.SAND, 4.5)
	elif GameState.can_buy("garras_cavar"):
		note("Aprenda Cavar (Garras) na árvore [TAB] para abrir as câmaras", UiTheme.SAND, 4.5)
	else:
		note("Para abrir as câmaras, redistribua seus pontos na árvore [TAB] e aprenda Cavar", UiTheme.SAND, 5.0)


func _on_dug(nest, ci: int, released: int) -> void:
	var c = nest.chambers[ci]
	if c.royal and nest.queen_alive:
		note("Câmara da rainha aberta: coma as %d formigas em volta dela!" % released, UiTheme.GOLD, 3.5)
	else:
		note("Câmara aberta: %d formigas lá dentro!" % released, UiTheme.GOLD)


func _on_chamber_cleaned(nest, _ci: int) -> void:
	Sfx.play("chamber", -3.0)
	note("Câmara limpa! (%d de %d no %s)" % [nest.clean_chambers(), nest.chambers.size(), nest.display_name], UiTheme.LEAF, 3.0)


func _on_nest_cleaned(nest) -> void:
	Sfx.play("nest_clean", -1.0)
	big_note("Formigueiro limpo!", "%s · %d de %d" % [nest.display_name, colony.nests_cleaned(), world.nests.size()], 4.0)


func _on_queen_blocked() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _queen_note_next:
		return
	_queen_note_next = now + 6.0
	note("A rainha está protegida: coma primeiro as formigas da câmara", UiTheme.TERRACOTTA, 2.6)


func _on_ate(count: int, _taj: int, _queens: int) -> void:
	var l := UiTheme.display_label("+%d" % count, 30 + mini(count, 10) * 2, UiTheme.GOLD)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.035, 0.02, 0.9))
	var vs := get_viewport_rect().size
	l.position = vs * 0.5 + Vector2(randf_range(20, 60), randf_range(-60, -20))
	_popups.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 70, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)
	if GameState.combo >= 10 and GameState.combo % 10 < count:
		note("Combo x%d!" % GameState.combo, UiTheme.PINK, 1.6)


func _on_sniffed(n: int, capped: bool, nearest: float, chambers: int) -> void:
	var radius := int(GameState.sniff_radius())
	if n == 0:
		note("Nenhuma formiga a até %d m... siga as trilhas de terra" % radius, UiTheme.SAND)
	else:
		var how_many := ("%d+" % n) if capped else str(n)
		note("Faro: %s formigas a até %d m · a mais perto a uns %d m" % [how_many, radius, int(round(nearest))], UiTheme.SAND, 2.5)
	if GameState.sniff_chambers():
		if chambers > 0:
			note("Faro: %d %s por perto" % [chambers, "câmara fechada" if chambers == 1 else "câmaras fechadas"], Settings.sniff_color().lightened(0.3), 2.5)
		else:
			note("Nenhuma câmara fechada por perto", UiTheme.SAND, 2.0)
	var now := Time.get_ticks_msec() / 1000.0
	_compass.sniff_target = player.sniff_target
	_compass.sniff_until = now + GameState.sniff_duration() + 3.0
	_compass.chamber_marks = player.sniff_chambers.duplicate()
	_compass.nests_until = now + 12.0 if GameState.sniff_nest_counts() else 0.0
	_compass.queens_until = now + 12.0 if GameState.sniff_queens() else 0.0


## Onda: aviso discreto no painel da direita (a bússola marca o formigueiro).
func _on_wave(wave: int, nest_name: String, count: int, nest_index: int) -> void:
	_wave_note = "Onda %d: %d formigas saindo do %s" % [wave, count, nest_name]
	_wave_note_time = 7.0
	Sfx.play("wave", -6.0)
	_compass.wave_nest = world.nests[nest_index]
	_compass.wave_until = Time.get_ticks_msec() / 1000.0 + 25.0


## Aviso discreto de "Jogo salvo" no canto da tela.
func show_saved() -> void:
	if _saved_label == null:
		_saved_label = UiTheme.caps_label("Jogo salvo", 12, UiTheme.SAND)
		_saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(_saved_label)
		_place(_saved_label, Control.PRESET_BOTTOM_RIGHT, Vector2(-220, -40), Vector2(200, 24))
	_saved_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_saved_label, "modulate:a", 0.0, 0.8)


## Aviso no alto da tela, entre dois losangos.
func note(text: String, color: Color = UiTheme.CREAM, duration: float = 3.2) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in 3:
		if k == 1:
			var l := UiTheme.label(text, 23, color)
			l.add_theme_font_override("font", UiTheme.semi_font())
			_soft_shadow(l)
			row.add_child(l)
		else:
			var d := Diamond.new()
			d.color = Color(UiTheme.GOLD, 0.9)
			d.custom_minimum_size = Vector2(8, 8)
			d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(d)
	_notes.add_child(row)
	while _notes.get_child_count() > 4:
		var old := _notes.get_child(0)
		_notes.remove_child(old)
		old.queue_free()
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(row, "modulate:a", 0.0, 0.6)
	tw.tween_callback(row.queue_free)


func big_note(title: String, sub: String = "", duration: float = 3.5) -> void:
	_big_note.text = title
	_big_sub.text = sub
	_big_time = duration
	_big_box.modulate.a = 1.0
	_big_box.pivot_offset = _big_box.size * 0.5
	_big_box.scale = Vector2(1.15, 1.15)
	var tw := create_tween()
	tw.tween_property(_big_box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ Widgets

## Losango dourado.
class Diamond extends Control:
	var color := Color("e8b44f")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), color)


## Enfeite dos avisos grandes: um traço que some na ponta e um losango.
class Flourish extends Control:
	var mirror := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var gold := Color("e8b44f")
		var y := size.y * 0.5
		var near := size.x - 8.0 if not mirror else 8.0
		var far := 0.0 if not mirror else size.x
		draw_polyline_colors(PackedVector2Array([Vector2(far, y), Vector2(near - (9.0 if not mirror else -9.0), y)]),
			PackedColorArray([Color(gold, 0.0), gold]), 1.5, true)
		var c := Vector2(near, y)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)]), gold)


## Medalhão com as formigas comidas (como o centro da árvore de habilidades).
class Medallion extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	var value := "0"
	var sub := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := 49.0
		var gold := UT.GOLD
		draw_circle(c, r + 13.0, Color(gold, 0.05))
		draw_circle(c, r + 9.0, Color(gold, 0.08))
		draw_circle(c, r + 6.5, Color(0.05, 0.035, 0.028, 0.88))
		draw_arc(c, r + 6.5, 0, TAU, 72, Color(gold, 0.45), 1.0, true)
		for k in 6:
			var t := float(k) / 5.0
			draw_circle(c, r * (1.0 - t * 0.7), Color("0d0907").lerp(Color("21150f"), t))
		draw_arc(c, r, 0, TAU, 72, gold, 3.0, true)
		var f: Font = UT.display_font()
		var fs := 34 if value.length() <= 3 else 29
		var w := f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w * 0.5, 7), value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UT.PALE)
		var cf: Font = UT.caps_font()
		var s := sub.to_upper()
		var w2 := cf.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(cf, c + Vector2(-w2 * 0.5, 27), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UT.MUTED)


## Barra fina dourada com um losango na ponta.
class GoldBar extends Control:
	var value := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var gold := Color("e8b44f")
		var y := size.y * 0.5
		draw_rect(Rect2(0, y - 2.0, size.x, 4.0), Color(gold, 0.18))
		var w := size.x * clampf(value, 0.0, 1.0)
		if w > 1.0:
			draw_polygon(PackedVector2Array([Vector2(0, y - 2.0), Vector2(w, y - 2.0), Vector2(w, y + 2.0), Vector2(0, y + 2.0)]),
				PackedColorArray([Color("8a6a2c"), gold, gold, Color("8a6a2c")]))
		var p := Vector2(clampf(w, 4.0, size.x - 4.0), y)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4.5), p + Vector2(4.5, 0), p + Vector2(0, 4.5), p + Vector2(-4.5, 0)]),
			Color("f6e3b4"))


## Bússola: faixa com moldura dourada, risquinhos a cada 15° (os de 45° maiores),
## direções e um medalhão no meio com o rumo. Os formigueiros são montinhos em
## cima da faixa; só o que está à sua frente mostra nome e distância embaixo.
class Compass extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	var player
	var world
	var wave_nest = null
	var wave_until := 0.0
	var sniff_target := Vector3.INF
	var sniff_until := 0.0
	var nests_until := 0.0
	var queens_until := 0.0
	## Câmaras fechadas achadas pelo Faro de Câmara.
	var chamber_marks: Array[Vector3] = []
	## Metade do que a faixa mostra (80°, em radianos).
	const SPAN := 1.3963
	const BAND_W := 640.0
	const BAND_H := 40.0
	const BAND_TOP := 32.0
	const DIRS := [
		{"t": "N", "a": 0.0, "big": true}, {"t": "NO", "a": PI * 0.25, "big": false},
		{"t": "O", "a": PI * 0.5, "big": true}, {"t": "SO", "a": PI * 0.75, "big": false},
		{"t": "S", "a": PI, "big": true}, {"t": "SE", "a": -PI * 0.75, "big": false},
		{"t": "L", "a": -PI * 0.5, "big": true}, {"t": "NE", "a": -PI * 0.25, "big": false},
	]
	const HEADINGS := ["N", "NO", "O", "SO", "S", "SE", "L", "NE"]

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _band() -> Rect2:
		return Rect2(Vector2((size.x - BAND_W) * 0.5, BAND_TOP), Vector2(BAND_W, BAND_H))

	func _x_for(dir_yaw: float) -> float:
		var b := _band()
		var rel := angle_difference(player.yaw, dir_yaw)
		return b.get_center().x - rel / SPAN * (b.size.x * 0.5 - 22.0)

	func _yaw_to(p: Vector3) -> float:
		var d: Vector3 = p - player.global_position
		return atan2(-d.x, -d.z)

	func _inside(x: float) -> bool:
		var b := _band()
		return x >= b.position.x + 10.0 and x <= b.end.x - 10.0

	## Some aos poucos perto das pontas da faixa.
	func _fade(x: float) -> float:
		var b := _band()
		var t := absf(x - b.get_center().x) / (b.size.x * 0.5 - 10.0)
		return 1.0 - smoothstep(0.78, 1.0, t)

	func _diamond(p: Vector2, r: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), col)

	func _text_centered(font: Font, x: float, baseline: float, text: String, fsize: int, col: Color) -> void:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		draw_string(font, Vector2(x - w * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)

	## Montinho de formigueiro (com o olheiro escuro).
	func _mound(base: Vector2, col: Color, big: bool) -> void:
		var w := 24.0 if big else 19.0
		var h := 15.0 if big else 12.0
		var pts := PackedVector2Array()
		for i in 13:
			var t := PI * float(i) / 12.0
			pts.append(base + Vector2(-cos(t) * w * 0.5, -sin(t) * h))
		draw_colored_polygon(pts, col)
		draw_circle(base + Vector2(0, -h * 0.42), 1.8 if not big else 2.2, Color(0.04, 0.025, 0.02))

	func _crown(p: Vector2, col: Color) -> void:
		var s := 1.3
		draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 3) * s, p + Vector2(-5, -2) * s, p + Vector2(-2.5, 0.5) * s,
			p + Vector2(0, -3) * s, p + Vector2(2.5, 0.5) * s, p + Vector2(5, -2) * s, p + Vector2(5, 3) * s]), col)

	## Plaquinha escura com borda dourada (nome e distância).
	func _plate(top_center: Vector2, text: String, col: Color) -> void:
		var f: Font = UT.bold_font()
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var r := Rect2(Vector2(top_center.x - w * 0.5 - 10.0, top_center.y), Vector2(w + 20.0, 22.0))
		r.position.x = clampf(r.position.x, 0.0, size.x - r.size.x)
		draw_rect(r, Color(0.04, 0.028, 0.024, 0.92))
		draw_rect(r.grow(-0.5), Color(UT.GOLD, 0.75), false, 1.0)
		draw_string(f, Vector2(r.position.x + 10.0, r.end.y - 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)

	func _draw() -> void:
		if player == null:
			return
		var b := _band()
		var gold := UT.GOLD
		var cx := b.get_center().x
		var now := Time.get_ticks_msec() / 1000.0
		# Faixa com moldura dupla e losangos nas pontas.
		draw_polygon(PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]),
			PackedColorArray([Color(0.063, 0.043, 0.035, 0.9), Color(0.063, 0.043, 0.035, 0.9),
				Color(0.031, 0.024, 0.02, 0.9), Color(0.031, 0.024, 0.02, 0.9)]))
		draw_rect(b.grow(-0.5), Color(gold, 0.85), false, 1.0)
		draw_rect(b.grow(-4.5), Color(gold, 0.25), false, 1.0)
		for side in [-1.0, 1.0]:
			var tip := Vector2(cx + side * (b.size.x * 0.5 + 17.0), b.get_center().y)
			_diamond(tip, 4.5, gold)
			draw_line(tip - Vector2(side * 5.0, 0), Vector2(cx + side * (b.size.x * 0.5 + 1.0), tip.y), gold, 1.0)
		# Risquinhos a cada 15° (os de 45°, maiores).
		for k in 24:
			var x := _x_for(k * TAU / 24.0)
			if not _inside(x):
				continue
			var major := k % 3 == 0
			var h := 9.0 if major else 5.0
			draw_line(Vector2(x, b.end.y - 3.0), Vector2(x, b.end.y - 3.0 - h), Color(gold, _fade(x) * (1.0 if major else 0.6)),
				2.0 if major else 1.0)
		# Direções.
		for d in DIRS:
			var x := _x_for(d.a)
			if not _inside(x) or absf(x - cx) < 30.0:
				continue
			if d.big:
				_text_centered(UT.display_font(), x, b.position.y + 25.0, d.t, 20, Color(UT.CREAM, _fade(x)))
			else:
				_text_centered(UT.caps_font(), x, b.position.y + 22.0, d.t, 12, Color(UT.MUTED, _fade(x)))
		# Formigueiros em cima da faixa; o que está à frente ganha destaque.
		var faced = null
		var faced_dx := 24.0
		for n in world.nests:
			if n.cleaned:
				continue
			var dx := absf(_x_for(_yaw_to(n.global_position)) - cx)
			if dx < faced_dx:
				faced_dx = dx
				faced = n
		for n in world.nests:
			var x := _x_for(_yaw_to(n.global_position))
			if not _inside(x):
				continue
			var is_wave: bool = wave_nest == n and now < wave_until
			var col := Color(gold, 0.8 * _fade(x))
			if n.cleaned:
				col = Color(UT.LEAF, 0.65 * _fade(x))
			if is_wave:
				col = Color(1.0, 0.5, 0.32).lerp(UT.PALE, 0.5 + 0.5 * sin(now * 8.0))
			var base := Vector2(x, b.position.y - 2.0)
			if n == faced:
				draw_circle(base + Vector2(0, -7), 15.0, Color(UT.PALE, 0.16))
				col = UT.PALE
			_mound(base, col, n == faced)
			var tag_y := b.position.y - 20.0
			if n.cleaned:
				draw_polyline(PackedVector2Array([base + Vector2(-5, -18), base + Vector2(-1, -14), base + Vector2(6, -22)]),
					Color(UT.LEAF, _fade(x)), 2.0, true)
				tag_y -= 10.0
			if now < queens_until and n.queen_alive:
				_crown(Vector2(x, tag_y), gold)
				tag_y -= 12.0
			if is_wave:
				_text_centered(UT.caps_font(), x, tag_y, "ONDA", 11, Color(1.0, 0.6, 0.42))
			elif now < nests_until and not n.cleaned:
				_text_centered(UT.display_bold_font(), x, tag_y, str(n.remaining()), 14, UT.PALE)
		if faced != null:
			var dist: float = faced.global_position.distance_to(player.global_position)
			var txt := "%s · %d m" % [faced.display_name, int(dist)]
			if now < nests_until:
				txt += " · faltam %d" % faced.remaining()
			_plate(Vector2(_x_for(_yaw_to(faced.global_position)), b.end.y + 6.0), txt, UT.PALE)
		# Saída para a área 2 (quando a clareira fica limpa).
		if world.exit_breakable and not world.exit_open:
			var ep: Vector2 = world.cliffs.exit_center(1.6)
			var ex := clampf(_x_for(_yaw_to(Vector3(ep.x, 0.0, ep.y))), b.position.x + 14.0, b.end.x - 14.0)
			var pulse := 0.65 + 0.35 * sin(now * 5.0)
			draw_circle(Vector2(ex, b.position.y - 8.0), 13.0, Color(UT.PALE, 0.18 * pulse))
			_diamond(Vector2(ex, b.position.y - 8.0), 7.0, Color(UT.PALE, pulse))
			var dist := Vector2(player.global_position.x, player.global_position.z).distance_to(ep)
			_text_centered(UT.caps_font(), ex, b.position.y - 22.0, "SAÍDA · %d M" % int(dist), 12, Color(UT.PALE, pulse))
		# Faro: câmaras e o rumo das formigas, dentro da faixa.
		var scent: Color = Settings.sniff_color()
		if now < sniff_until:
			for cpos in chamber_marks:
				var x := _x_for(_yaw_to(cpos))
				if _inside(x):
					_diamond(Vector2(x, b.get_center().y), 5.5, scent)
		if sniff_target != Vector3.INF and now < sniff_until:
			var x := clampf(_x_for(_yaw_to(sniff_target)), b.position.x + 14.0, b.end.x - 14.0)
			draw_circle(Vector2(x, b.get_center().y), 8.0, Color(scent, 0.9))
			draw_circle(Vector2(x, b.get_center().y), 3.5, Color(0.1, 0.04, 0.04))
		# Medalhão do meio com o rumo, e a setinha para a faixa.
		var mc := Vector2(cx, b.position.y)
		draw_circle(mc, 28.0, Color(0.05, 0.035, 0.028, 0.92))
		draw_arc(mc, 28.0, 0, TAU, 48, Color(gold, 0.45), 1.0, true)
		draw_circle(mc, 23.5, Color("0d0907"))
		draw_circle(mc, 15.0, Color("1d130e"))
		draw_arc(mc, 23.5, 0, TAU, 48, gold, 2.0, true)
		var idx := posmod(int(round(player.yaw / (PI * 0.25))), 8)
		var hname: String = HEADINGS[idx]
		_text_centered(UT.display_font(), cx, mc.y + 7.0, hname, 20 if hname.length() == 1 else 16, UT.PALE)
		draw_colored_polygon(PackedVector2Array([mc + Vector2(-6, 29), mc + Vector2(6, 29), mc + Vector2(0, 36)]), gold)


## Mira: anel fino com quatro risquinhos; verde quando a lambida vai pegar formiga.
class Crosshair extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	var player
	var swarm

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if player == null or player.camera == null:
			return
		var c := size * 0.5
		var cam: Camera3D = player.camera
		# Verde: a lambida vai pegar formiga (com Língua Certeira, a língua vai
		# atrás dela; sem, só se ela estiver perto de onde a língua chega reta).
		var locked: bool = player.aim_hits
		var col := UT.AIM if locked else Color(UT.CREAM, 0.88)
		var r := 15.0 if locked else 12.0
		if locked:
			draw_arc(c, r, 0, TAU, 40, Color(col, 0.22), 7.0, true)
		draw_arc(c, r, 0, TAU, 40, Color(0, 0, 0, 0.35), 3.5, true)
		draw_arc(c, r, 0, TAU, 40, col, 1.6, true)
		for k in 4:
			var d := Vector2.RIGHT.rotated(k * PI * 0.5)
			draw_line(c + d * (r + 3.0), c + d * (r + 8.0), col, 2.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2.5), c + Vector2(2.5, 0), c + Vector2(0, 2.5), c + Vector2(-2.5, 0)]), col)
		# Língua Certeira: um anel pequeno na formiga que a língua vai buscar.
		var ant: int = player.aim_ant
		if ant >= 0 and ant < swarm.pos.size():
			var p: Vector3 = swarm.pos[ant]
			if not cam.is_position_behind(p):
				var sp: Vector2 = get_global_transform_with_canvas().affine_inverse() * cam.unproject_position(p)
				if sp.distance_to(c) > r + 4.0:
					draw_arc(sp, 6.0, 0, TAU, 20, Color(UT.AIM, 0.9), 2.0, true)
		var work := maxf(player.dig_progress, player.exit_progress)
		if work > 0.0:
			draw_arc(c, 27.0, -PI * 0.5, -PI * 0.5 + TAU * work, 48, UT.GOLD, 4.0, true)


## Habilidade no HUD: um círculo como os da árvore, com a tecla embaixo.
class AbilityIcon extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	const Glyphs := preload("res://scripts/ui/glyphs.gd")
	var kind := "lick"
	var key_text := ""
	var name_text := ""
	var glyph := "tongue"
	var tint := Color.WHITE
	var primary := false
	var locked := false
	## Quanto falta da recarga (0..1) e em segundos.
	var cooldown := 0.0
	var seconds := 0.0
	var progress := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 38.0)
		var r := 31.0
		var gold := UT.GOLD
		var waiting := cooldown > 0.0 and not locked
		if primary:
			draw_circle(c, r + 12.0, Color(gold, 0.06))
			draw_circle(c, r + 8.5, Color(gold, 0.09))
		draw_circle(c, r + 5.5, Color(0.045, 0.03, 0.026, 0.88))
		var outer := Color(gold, 0.55) if primary else Color(UT.BRONZE, 0.45)
		if locked:
			outer = Color(0.24, 0.19, 0.16, 0.6)
		draw_arc(c, r + 5.5, 0, TAU, 56, outer, 1.0, true)
		var disc := tint.darkened(0.8) if not locked else Color(0.055, 0.04, 0.035)
		for k in 5:
			var t := float(k) / 4.0
			draw_circle(c, r * (1.0 - t * 0.55), Color("0b0807").lerp(disc, t))
		var ring := gold if primary else UT.BRONZE
		if locked:
			ring = Color(0.26, 0.21, 0.17)
		draw_arc(c, r, 0, TAU, 56, ring, 2.5 if primary else 2.0, true)
		if locked:
			_padlock(c)
		else:
			var gcol := tint.lightened(0.45)
			if waiting:
				gcol.a = 0.3
			Glyphs.paint(self, glyph, c, r * 0.56, gcol)
		if waiting:
			draw_arc(c, r + 5.5, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - cooldown), 56, gold, 3.0, true)
			var f: Font = UT.display_font()
			var txt := str(int(ceil(seconds)))
			var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(f, c + Vector2(-w * 0.5, 8.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UT.PALE)
		if progress > 0.0:
			draw_arc(c, r - 5.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, UT.PALE, 3.0, true)
		# Tecla na base do círculo.
		var cf: Font = UT.caps_font()
		var key := key_text.to_upper()
		var kw := cf.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14.0
		var kr := Rect2(Vector2(c.x - kw * 0.5, c.y + r - 7.0), Vector2(kw, 17.0))
		draw_rect(kr, Color("0b0807"))
		var kcol := gold if primary else UT.BRONZE
		if locked:
			kcol = Color(0.3, 0.25, 0.2)
		draw_rect(kr.grow(-0.5), kcol, false, 1.0)
		var ktext := gold if primary else UT.SAND
		if locked:
			ktext = Color(0.5, 0.45, 0.4)
		draw_string(cf, Vector2(kr.position.x + 7.0, kr.end.y - 4.0), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ktext)
		# Nome embaixo.
		var nf: Font = UT.bold_font()
		var nw := nf.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var npos := Vector2(c.x - nw * 0.5, c.y + r + 30.0)
		draw_string(nf, npos + Vector2(0, 2), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.6))
		draw_string(nf, npos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UT.CREAM if not locked else Color(0.55, 0.5, 0.44))

	func _padlock(c: Vector2) -> void:
		var metal := Color(0.55, 0.49, 0.42)
		var p := c + Vector2(0, 3)
		draw_arc(p + Vector2(0, -6), 6.5, PI, TAU, 14, metal, 3.0, true)
		draw_line(p + Vector2(-6.5, -6), p + Vector2(-6.5, -2), metal, 3.0, true)
		draw_line(p + Vector2(6.5, -6), p + Vector2(6.5, -2), metal, 3.0, true)
		draw_rect(Rect2(p + Vector2(-10, -2), Vector2(20, 15)), metal)
		draw_circle(p + Vector2(0, 4), 2.5, Color(0.08, 0.05, 0.04))
