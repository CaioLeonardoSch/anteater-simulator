extends Control
## HUD da partida: contador de formigas, pontos e a próxima habilidade,
## bússola com formigueiros e ondas, mira, habilidades e avisos.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

var player
var swarm
var colony
var world

var _count_label: Label
var _goal_label: Label
var _next_bar: ProgressBar
var _next_label: Label
var _nests_label: Label
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
var _compass: Compass
var _crosshair: Crosshair
var _notes: VBoxContainer
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
	colony.final_wave.connect(func(_n): big_note("RETA FINAL DAS TRILHAS", "As últimas forrageiras saíram de casa. O resto está nas câmaras!"))
	colony.chamber_cleaned.connect(_on_chamber_cleaned)
	colony.nest_cleaned.connect(_on_nest_cleaned)
	colony.queen_eaten.connect(func(_nest): big_note("RAINHA!", "Ela valeu 20 formigas", 4.0))
	GameState.ants_eaten_changed.connect(_on_eaten_changed)
	GameState.upgrade_affordable.connect(_on_affordable)
	GameState.skills_reset.connect(_refresh_points)
	GameState.frenzy_changed.connect(func(on): if on: big_note("FRENESI!", "Você comeu uma tanajura: língua turbinada por 6 s"))
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
	_place(_compass, Control.PRESET_CENTER_TOP, Vector2(-330, 14), Vector2(660, 54))
	_crosshair = Crosshair.new()
	add_child(_crosshair)
	_place(_crosshair, Control.PRESET_CENTER, Vector2(-40, -40), Vector2(80, 80))
	_notes = VBoxContainer.new()
	_notes.alignment = BoxContainer.ALIGNMENT_BEGIN
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notes)
	_place(_notes, Control.PRESET_CENTER_TOP, Vector2(-450, 150), Vector2(900, 200))
	_big_note = UiTheme.label("", 64, UiTheme.GOLD, true)
	_big_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_note.add_theme_constant_override("outline_size", 10)
	_big_note.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.05, 0.9))
	add_child(_big_note)
	_place(_big_note, Control.PRESET_CENTER, Vector2(-600, -240), Vector2(1200, 80))
	_big_sub = UiTheme.label("", 26, UiTheme.CREAM)
	_big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_sub.add_theme_constant_override("outline_size", 6)
	_big_sub.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.05, 0.9))
	add_child(_big_sub)
	_place(_big_sub, Control.PRESET_CENTER, Vector2(-600, -158), Vector2(1200, 40))
	_hint = UiTheme.label("", 24, UiTheme.CREAM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03, 0.9))
	add_child(_hint)
	_place(_hint, Control.PRESET_CENTER, Vector2(-500, 70), Vector2(1000, 40))
	_build_abilities()
	_controls_hint = UiTheme.label(
		"WASD andar  ·  Mouse olhar  ·  Clique: lamber  ·  Q ou botão direito: farejar  ·  TAB: habilidades",
		19, UiTheme.CREAM)
	_controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls_hint.add_theme_constant_override("outline_size", 6)
	_controls_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03, 0.85))
	add_child(_controls_hint)
	_place(_controls_hint, Control.PRESET_CENTER_BOTTOM, Vector2(-640, -170), Vector2(1280, 56))
	_popups = Control.new()
	_popups.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popups)


## Posiciona um controle por âncora + deslocamento (independe do tamanho da tela).
func _place(c: Control, preset: int, offset: Vector2, box_size: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + box_size.x
	c.offset_bottom = offset.y + box_size.y


func _build_counter() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 20)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var icon := AntIcon.new()
	icon.custom_minimum_size = Vector2(46, 46)
	h.add_child(icon)
	_count_label = UiTheme.label("0", 46, UiTheme.CREAM, true)
	h.add_child(_count_label)
	_goal_label = UiTheme.label("/ %d" % GameState.GOAL, 26, UiTheme.SAND)
	_goal_label.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(_goal_label)
	_next_bar = ProgressBar.new()
	_next_bar.custom_minimum_size = Vector2(270, 14)
	_next_bar.show_percentage = false
	_next_bar.max_value = 100
	v.add_child(_next_bar)
	_next_label = UiTheme.label("", 17, UiTheme.SAND)
	v.add_child(_next_label)
	_nests_label = UiTheme.label("", 17, UiTheme.LEAF)
	v.add_child(_nests_label)
	_points_badge = PanelContainer.new()
	var badge_box := UiTheme._box(Color(0.75, 0.32, 0.2, 0.95), UiTheme.GOLD, 2, 14)
	badge_box.content_margin_top = 4
	badge_box.content_margin_bottom = 4
	_points_badge.add_theme_stylebox_override("panel", badge_box)
	_points_label = UiTheme.label("", 19, Color.WHITE, true)
	_points_badge.add_child(_points_label)
	v.add_child(_points_badge)


func _build_top_right() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(186, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	_place(panel, Control.PRESET_TOP_RIGHT, Vector2(-250, 20), Vector2(226, 0))
	var v := VBoxContainer.new()
	panel.add_child(v)
	_timer_label = UiTheme.label("0:00", 30, UiTheme.CREAM, true)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_timer_label)
	_wave_label = UiTheme.label("Calmaria", 18, UiTheme.SAND)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wave_label.custom_minimum_size = Vector2(190, 0)
	v.add_child(_wave_label)


func _build_abilities() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_place(row, Control.PRESET_CENTER_BOTTOM, Vector2(-260, -106), Vector2(520, 92))
	var defs := [
		{"key": "Clique", "name": "Lamber", "kind": "lick"},
		{"key": "Q", "name": "Farejar", "kind": "sniff"},
		{"key": "E", "name": "Cavar", "kind": "dig"},
		{"key": "Espaço", "name": "Tremor", "kind": "tremor"},
	]
	for d in defs:
		var a := AbilityIcon.new()
		a.kind = d.kind
		a.key_text = d.key
		a.name_text = d.name
		a.custom_minimum_size = Vector2(96, 90)
		row.add_child(a)
		_abilities.append(a)


func _process(delta: float) -> void:
	if player == null:
		return
	_shown_count = move_toward(_shown_count, GameState.ants_eaten, maxf(delta * 60.0, absf(GameState.ants_eaten - _shown_count) * delta * 8.0))
	_count_label.text = str(int(round(_shown_count)))
	_timer_label.text = GameState.format_time(GameState.elapsed)
	var wave_active: bool = colony._wave.size() > 0
	_nests_label.text = "Formigueiros limpos: %d/%d" % [colony.nests_cleaned(), world.nests.size()]
	_wave_note_time = maxf(_wave_note_time - delta, 0.0)
	_wave_label.add_theme_color_override("font_color", UiTheme.GOLD if _wave_note_time > 0.0 else UiTheme.SAND)
	if _wave_note_time > 0.0:
		_wave_label.text = _wave_note
	elif colony.final_released:
		if colony.outside_total() == 0:
			_wave_label.text = "Faltam %d nas câmaras" % colony.remaining()
		else:
			_wave_label.text = "Reta final: %d restantes" % colony.remaining()
	elif wave_active:
		_wave_label.text = "Onda %d chegando!" % colony.wave_number
	else:
		_wave_label.text = "Próxima onda em %ds" % int(ceil(colony.wave_timer))
	# Habilidades.
	for a in _abilities:
		match a.kind:
			"lick":
				a.locked = false
				a.cooldown = 0.0
			"sniff":
				a.locked = not GameState.can_sniff()
				a.cooldown = player.sniff_cd / GameState.sniff_cooldown() if player.sniff_cd > 0.0 else 0.0
			"dig":
				a.locked = not GameState.can_dig()
				a.cooldown = player.dig_cd / GameState.dig_cooldown() if player.dig_cd > 0.0 else 0.0
				a.progress = player.dig_progress
			"tremor":
				a.locked = not GameState.can_tremor()
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
		var a := clampf(_big_time / 0.6, 0.0, 1.0)
		_big_note.modulate.a = a
		_big_sub.modulate.a = a
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


func _on_eaten_changed(_total: int, _delta: int) -> void:
	_refresh_points()


## Pontos para gastar, barra até a próxima habilidade e o aviso de [TAB].
func _refresh_points() -> void:
	var pts := GameState.points_available()
	var goal := GameState.next_goal()
	if goal.is_empty():
		_next_bar.value = 100.0 if GameState.affordable_count() > 0 or pts > 0 else 0.0
		_next_label.text = "Pontos: %d" % pts
	else:
		_next_bar.value = clampf(float(pts) / float(goal.cost) * 100.0, 0.0, 100.0)
		_next_label.text = "Pontos: %d  ·  %s: %d" % [pts, goal.name, goal.cost]
	var n := GameState.affordable_count()
	_points_badge.visible = n > 0
	if n == 1:
		for u in GameState.UPGRADES:
			if GameState.can_buy(u.id):
				_points_label.text = "Dá para aprender: %s  [TAB]" % u.name
				break
	else:
		_points_label.text = "%d habilidades para aprender  [TAB]" % n


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
	big_note("FORMIGUEIRO LIMPO!", "%s · %d de %d" % [nest.display_name, colony.nests_cleaned(), world.nests.size()], 4.0)


func _on_queen_blocked() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _queen_note_next:
		return
	_queen_note_next = now + 6.0
	note("A rainha está protegida: coma primeiro as formigas da câmara", UiTheme.TERRACOTTA, 2.6)


func _on_ate(count: int, _taj: int, _queens: int) -> void:
	var l := UiTheme.label("+%d" % count, 30 + mini(count, 10) * 2, UiTheme.GOLD, true)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.3, 0.12, 0.05, 0.9))
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
		_saved_label = UiTheme.label("Jogo salvo", 16, UiTheme.SAND)
		_saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(_saved_label)
		_place(_saved_label, Control.PRESET_BOTTOM_RIGHT, Vector2(-220, -40), Vector2(200, 24))
	_saved_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_saved_label, "modulate:a", 0.0, 0.8)


func note(text: String, color: Color = UiTheme.CREAM, duration: float = 3.2) -> void:
	var l := UiTheme.label(text, 24, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03, 0.9))
	_notes.add_child(l)
	while _notes.get_child_count() > 4:
		_notes.get_child(0).queue_free()
		_notes.remove_child(_notes.get_child(0))
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func big_note(title: String, sub: String = "", duration: float = 3.5) -> void:
	_big_note.text = title
	_big_sub.text = sub
	_big_time = duration
	_big_note.modulate.a = 1.0
	_big_sub.modulate.a = 1.0
	_big_note.pivot_offset = _big_note.size * 0.5
	_big_note.scale = Vector2(1.25, 1.25)
	var tw := create_tween()
	tw.tween_property(_big_note, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ Widgets

class AntIcon extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var col := Color(0.35, 0.13, 0.07)
		var leg := Color(0.3, 0.12, 0.06)
		for k in 3:
			var y := c.y - 6 + k * 6
			draw_line(Vector2(c.x - 4, y), Vector2(c.x - 16, y - 6 + k * 6), leg, 2.5, true)
			draw_line(Vector2(c.x + 4, y), Vector2(c.x + 16, y - 6 + k * 6), leg, 2.5, true)
		draw_circle(c + Vector2(0, -12), 7.0, col)
		draw_circle(c + Vector2(0, -1), 5.0, col)
		draw_circle(c + Vector2(0, 11), 9.0, col)
		draw_line(c + Vector2(-3, -17), c + Vector2(-10, -24), leg, 2.0, true)
		draw_line(c + Vector2(3, -17), c + Vector2(10, -24), leg, 2.0, true)
		draw_circle(c + Vector2(-3, -14), 1.6, Color(1, 1, 1, 0.8))


class Compass extends Control:
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
	const SPAN := PI * 0.6

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _x_for(dir_yaw: float) -> float:
		var rel := angle_difference(player.yaw, dir_yaw)
		return size.x * 0.5 - rel / SPAN * size.x * 0.5

	func _yaw_to(p: Vector3) -> float:
		var d: Vector3 = p - player.global_position
		return atan2(-d.x, -d.z)

	func _draw() -> void:
		if player == null:
			return
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.12, 0.07, 0.06, 0.55)
		bg.set_corner_radius_all(14)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		var font := ThemeDB.fallback_font
		var f: Font = get_theme_default_font()
		if f:
			font = f
		var dirs := {"N": 0.0, "O": PI * 0.5, "S": PI, "L": -PI * 0.5}
		for k in 24:
			var a := k * TAU / 24.0
			var x := _x_for(a)
			if x < 8 or x > size.x - 8:
				continue
			draw_line(Vector2(x, size.y - 10), Vector2(x, size.y - (16 if k % 6 == 0 else 6)), Color(1, 0.9, 0.75, 0.5), 2)
		for dname in dirs:
			var x := _x_for(dirs[dname])
			if x < 10 or x > size.x - 10:
				continue
			draw_string(font, Vector2(x - 8, 30), dname, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.95, 0.85))
		var now := Time.get_ticks_msec() / 1000.0
		for n in world.nests:
			var p: Vector3 = n.global_position
			var x := _x_for(_yaw_to(p))
			if x < 10 or x > size.x - 10:
				continue
			var is_wave: bool = wave_nest == n and now < wave_until
			var col := Color(0.95, 0.55, 0.35) if not is_wave else Color(1, 0.3, 0.2, 0.6 + 0.4 * sin(now * 8.0))
			if n.cleaned:
				col = Color(0.55, 0.85, 0.45)
			var base := Vector2(x, size.y - 22)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-9, 6), base + Vector2(0, -6), base + Vector2(9, 6)]), col)
			if n.cleaned:
				draw_polyline(PackedVector2Array([base + Vector2(-5, -12), base + Vector2(-1, -8), base + Vector2(6, -16)]), Color(0.7, 1, 0.6), 2.5, true)
			var dist := p.distance_to(player.global_position)
			var show_count: bool = now < nests_until and not n.cleaned
			if absf(x - size.x * 0.5) < 60 or is_wave or show_count:
				var txt := "%dm" % int(dist)
				if is_wave:
					txt = "ONDA %dm" % int(dist)
				elif show_count:
					txt = "%d · %dm" % [n.remaining(), int(dist)]
				draw_string(font, base + Vector2(-26, 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
			if now < queens_until and n.queen_alive:
				var q := Vector2(x, 10)
				draw_colored_polygon(PackedVector2Array([q + Vector2(-8, 6), q + Vector2(-8, -3), q + Vector2(-4, 2), q + Vector2(0, -6),
					q + Vector2(4, 2), q + Vector2(8, -3), q + Vector2(8, 6)]), Color(1.0, 0.82, 0.25))
		var scent: Color = Settings.sniff_color()
		if now < sniff_until:
			for cpos in chamber_marks:
				var cx := _x_for(_yaw_to(cpos))
				if cx < 10 or cx > size.x - 10:
					continue
				var q := Vector2(cx, size.y * 0.5 - 6)
				draw_colored_polygon(PackedVector2Array([q + Vector2(0, -7), q + Vector2(6, 0), q + Vector2(0, 7), q + Vector2(-6, 0)]), scent)
		if sniff_target != Vector3.INF and now < sniff_until:
			var x := _x_for(_yaw_to(sniff_target))
			x = clampf(x, 14, size.x - 14)
			draw_circle(Vector2(x, size.y * 0.5 - 4), 9.0, Color(scent, 0.9))
			draw_circle(Vector2(x, size.y * 0.5 - 4), 4.0, Color(0.15, 0.05, 0.05))
		draw_line(Vector2(size.x * 0.5, 2), Vector2(size.x * 0.5, 12), Color(1, 1, 1, 0.9), 3)


class Crosshair extends Control:
	var player
	var swarm

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if player == null or player.camera == null:
			return
		var c := size * 0.5
		var cam: Camera3D = player.camera
		var fwd := -cam.global_transform.basis.z
		var reach := GameState.tongue_range()
		var target: int = swarm.best_target(cam.global_position, fwd, reach + 0.7, cos(deg_to_rad(10.0)))
		var locked := target >= 0
		var col := Color(0.6, 1.0, 0.5, 0.95) if locked else Color(1, 0.96, 0.88, 0.85)
		var r := 13.0 if locked else 10.0
		draw_arc(c, r, 0, TAU, 32, col, 2.5, true)
		draw_circle(c, 2.5, col)
		if player.dig_progress > 0.0:
			draw_arc(c, 24, -PI * 0.5, -PI * 0.5 + TAU * player.dig_progress, 48, Color(1, 0.75, 0.3), 5, true)


class AbilityIcon extends Control:
	var kind := "lick"
	var key_text := ""
	var name_text := ""
	var locked := false
	var cooldown := 0.0
	var progress := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var box := Rect2(Vector2(14, 0), Vector2(68, 64))
		var bg := StyleBoxFlat.new()
		bg.set_corner_radius_all(16)
		bg.bg_color = Color(0.15, 0.09, 0.07, 0.8) if not locked else Color(0.1, 0.08, 0.08, 0.55)
		bg.border_color = Color(1, 0.75, 0.4, 0.8) if not locked else Color(0.5, 0.45, 0.4, 0.4)
		bg.set_border_width_all(2)
		draw_style_box(bg, box)
		var c := box.get_center()
		var ink := Color(1, 0.92, 0.8) if not locked else Color(0.55, 0.5, 0.45)
		match kind:
			"lick":
				var pts := PackedVector2Array()
				for k in 12:
					var t := k / 11.0
					pts.append(c + Vector2(-18 + t * 34, 10 - t * 20 + sin(t * 6.0) * 5))
				draw_polyline(pts, Color(1, 0.55, 0.62) if not locked else ink, 6, true)
			"sniff":
				draw_circle(c + Vector2(-6, 6), 7, ink)
				draw_circle(c + Vector2(6, 6), 7, ink)
				draw_circle(c + Vector2(-6, 6), 3, Color(0.15, 0.08, 0.06))
				draw_circle(c + Vector2(6, 6), 3, Color(0.15, 0.08, 0.06))
				for k in 3:
					draw_arc(c + Vector2(0, 2), 14 + k * 6, -PI * 0.8, -PI * 0.2, 12, Color(ink, 0.7 - k * 0.2), 2, true)
			"dig":
				for k in 3:
					var x := -12 + k * 12
					draw_line(c + Vector2(x, -16), c + Vector2(x - 6, 14), ink, 5, true)
			"tremor":
				var pts := PackedVector2Array()
				for k in 9:
					pts.append(c + Vector2(-20 + k * 5, (8 if k % 2 == 0 else -8)))
				draw_polyline(pts, ink, 4, true)
		if cooldown > 0.0:
			draw_rect(Rect2(box.position + Vector2(0, box.size.y * (1.0 - cooldown)), Vector2(box.size.x, box.size.y * cooldown)), Color(0, 0, 0, 0.55))
		if progress > 0.0:
			draw_rect(Rect2(box.position + Vector2(4, box.size.y - 8), Vector2((box.size.x - 8) * progress, 5)), Color(1, 0.75, 0.3))
		if locked:
			draw_rect(Rect2(c + Vector2(-8, 0), Vector2(16, 13)), Color(0.7, 0.62, 0.55))
			draw_arc(c + Vector2(0, 0), 6, PI, TAU, 12, Color(0.7, 0.62, 0.55), 3, true)
		if font:
			draw_string(font, Vector2(0, 84), name_text if not locked else "Bloqueado", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, ink)
			var kw := maxf(42.0, font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0)
			var kb := Rect2(Vector2(box.end.x + 12 - kw, box.position.y - 8), Vector2(kw, 22))
			var kbg := StyleBoxFlat.new()
			kbg.bg_color = Color(0.85, 0.42, 0.28) if not locked else Color(0.35, 0.3, 0.28)
			kbg.set_corner_radius_all(8)
			draw_style_box(kbg, kb)
			draw_string(font, kb.position + Vector2(0, 16), key_text, HORIZONTAL_ALIGNMENT_CENTER, kb.size.x, 13, Color.WHITE)
