extends Control
## HUD da partida, no estilo Constelação: medalhão com as formigas comidas,
## painel de pontos (próxima habilidade e formigueiros limpos), bússola numa
## faixa dourada, mira, habilidades em círculos (como na árvore), cartões de
## conquista no canto direito e dicas curtas embaixo da mira. Pouco texto: o
## que dá para mostrar com ícone e número vira ícone e número.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Glyphs := preload("res://scripts/ui/glyphs.gd")
const NestScript := preload("res://scripts/world/nest.gd")

## Cor do Frenesi (asas de tanajura).
const FRENZY := Color("f0a65a")
## Fundo dos ícones dos cartões.
const BG_GREEN := Color("24301a")
const BG_GOLD := Color("3a2a10")
const BG_FRENZY := Color("3a2410")
## Cor do tronco nos avisos.
const LOG_COLOR := Color("a8703f")

var player
var swarm
var colony
var world

var _medallion: Medallion
var _points_value: Label
var _next_row: HBoxContainer
var _next_bar: GoldBar
var _next_icon: GlyphIcon
var _next_cost: Label
var _nest_pips: Pips
var _badge: PanelContainer
var _badge_count: Label
var _compass: Compass
var _crosshair: Crosshair
var _cards: CardStack
var _hint: HintRow
var _tutorial: HintRow
var _sniff: SniffChip
var _save: SaveIcon
var _big_box: VBoxContainer
var _big_note: Label
var _big_icon: GlyphIcon
var _big_sub: Label
var _big_time := 0.0
var _abilities: Array = []
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _popups: Control
var _shown_count := 0.0
## Dica passageira: tem prioridade sobre a dica do lugar.
var _flash: Array = []
var _flash_time := 0.0
var _queen_bump_next := 0.0
var _help_next := 0.0
## Tempo andando e correndo (a dica de um controle some depois que você usa).
var _moved := 0.0
var _ran := 0.0
var _play_time := 0.0

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
	player.sniffed.connect(_on_sniffed)
	player.queen_blocked.connect(_on_queen_blocked)
	player.lick_blocked_running.connect(_on_lick_blocked_running)
	colony.chamber_cleaned.connect(_on_chamber_cleaned)
	colony.nest_cleaned.connect(_on_nest_cleaned)
	colony.queen_eaten.connect(_on_queen_eaten)
	GameState.ants_eaten_changed.connect(_on_eaten_changed)
	GameState.upgrade_affordable.connect(_on_affordable)
	GameState.skills_reset.connect(_refresh_points)
	GameState.frenzy_changed.connect(_on_frenzy)
	GameState.upgrade_purchased.connect(_on_purchased)
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
	_compass = Compass.new()
	add_child(_compass)
	_place(_compass, Control.PRESET_CENTER_TOP, Vector2(-350, 10), Vector2(700, 104))
	_crosshair = Crosshair.new()
	add_child(_crosshair)
	_place(_crosshair, Control.PRESET_CENTER, Vector2(-40, -40), Vector2(80, 80))
	_cards = CardStack.new()
	add_child(_cards)
	_place(_cards, Control.PRESET_TOP_RIGHT, Vector2(-310, 24), Vector2(286, 230))
	_build_big_note()
	_hint = HintRow.new()
	add_child(_hint)
	_place(_hint, Control.PRESET_CENTER, Vector2(-450, 34), Vector2(900, 28))
	_build_abilities()
	_tutorial = HintRow.new()
	add_child(_tutorial)
	_place(_tutorial, Control.PRESET_CENTER_BOTTOM, Vector2(-450, -212), Vector2(900, 28))
	_save = SaveIcon.new()
	add_child(_save)
	_place(_save, Control.PRESET_BOTTOM_RIGHT, Vector2(-50, -48), Vector2(28, 28))
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


## Medalhão com as formigas comidas, painel (pontos, próxima habilidade e
## formigueiros limpos) e o selo de habilidades para aprender.
func _build_counter() -> void:
	_medallion = Medallion.new()
	_medallion.position = Vector2(24, 18)
	_medallion.size = Vector2(116, 116)
	_medallion.sub = "de %d" % GameState.ants(GameState.GOAL)
	add_child(_medallion)
	var col := VBoxContainer.new()
	col.position = Vector2(152, 24)
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_frame(15, 11))
	panel.custom_minimum_size = Vector2(232, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	panel.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	var pts_label := UiTheme.caps_label("Pontos", 12)
	pts_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pts_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pts_label)
	_points_value = UiTheme.display_label("0", 23, UiTheme.GOLD)
	row.add_child(_points_value)
	# Barra até a próxima habilidade, com o ícone e o custo dela.
	_next_row = HBoxContainer.new()
	_next_row.add_theme_constant_override("separation", 9)
	v.add_child(_next_row)
	_next_bar = GoldBar.new()
	_next_bar.custom_minimum_size = Vector2(0, 12)
	_next_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next_row.add_child(_next_bar)
	_next_icon = GlyphIcon.new()
	_next_icon.custom_minimum_size = Vector2(20, 20)
	_next_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next_row.add_child(_next_icon)
	_next_cost = UiTheme.display_label("", 17, UiTheme.SAND)
	_next_cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next_row.add_child(_next_cost)
	# Formigueiros limpos: um losango por formigueiro.
	_nest_pips = Pips.new()
	_nest_pips.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(_nest_pips)
	# Habilidades para aprender: ◆ 2 [Tab]
	_badge = PanelContainer.new()
	var badge := UiTheme.frame(Color(0.04, 0.028, 0.024, 0.92), Color(0.03, 0.022, 0.018, 0.92), UiTheme.GOLD,
		Color(0, 0, 0, 0), 11, 5)
	badge.glow = 0.7
	_badge.add_theme_stylebox_override("panel", badge)
	_badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(_badge)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 9)
	_badge.add_child(h)
	var dia := Diamond.new()
	dia.custom_minimum_size = Vector2(10, 10)
	dia.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dia)
	_badge_count = UiTheme.display_label("", 18, UiTheme.PALE)
	_badge_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_badge_count)
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


## Aviso grande no meio da tela (só no fim da clareira): título em Alegreya SC
## entre dois enfeites dourados e uma linha curta embaixo.
func _build_big_note() -> void:
	_big_box = VBoxContainer.new()
	_big_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_big_box.add_theme_constant_override("separation", 4)
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
	var sub_row := HBoxContainer.new()
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_row.add_theme_constant_override("separation", 10)
	sub_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_box.add_child(sub_row)
	_big_icon = GlyphIcon.new()
	_big_icon.custom_minimum_size = Vector2(34, 22)
	_big_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_big_icon.color = LOG_COLOR
	sub_row.add_child(_big_icon)
	_big_sub = UiTheme.label("", 22, UiTheme.CREAM)
	_big_sub.add_theme_font_override("font", UiTheme.semi_font())
	_soft_shadow(_big_sub)
	sub_row.add_child(_big_sub)
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
		if d.kind == "sniff":
			# O resultado do faro aparece em cima do botão de Farejar.
			_sniff = SniffChip.new()
			a.add_child(_sniff)
			_sniff.position = Vector2(52.0 - 130.0, -40.0)
			_sniff.size = Vector2(260, 26)


func _process(delta: float) -> void:
	if player == null:
		return
	_play_time += delta
	var eaten := GameState.ants(GameState.ants_eaten)
	_shown_count = move_toward(_shown_count, eaten, maxf(delta * 300.0, absf(eaten - _shown_count) * delta * 8.0))
	var shown := str(int(round(_shown_count)))
	if _medallion.value != shown:
		_medallion.value = shown
		_medallion.queue_redraw()
	_nest_pips.set_counts(colony.nests_cleaned(), world.nests.size())
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
	_update_hints(delta)
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


func _on_eaten_changed(_total: int, _delta: int) -> void:
	_refresh_points()


## Pontos para gastar, barra até a próxima habilidade (ícone e custo dela) e o
## selo de habilidades para aprender.
func _refresh_points() -> void:
	var pts := GameState.points_available()
	var goal := GameState.next_goal()
	var n := GameState.affordable_count()
	_points_value.text = str(pts)
	if goal.is_empty():
		# Nada mais longe para juntar: ou dá para aprender agora (selo), ou acabou.
		_next_row.visible = n > 0
		_next_bar.value = 1.0
		_next_icon.visible = false
		_next_cost.visible = false
	else:
		_next_row.visible = true
		_next_bar.value = clampf(float(pts) / float(goal.cost), 0.0, 1.0)
		_next_icon.kind = Glyphs.for_upgrade(goal)
		_next_icon.color = GameState.BRANCHES[goal.branch].color
		_next_icon.visible = true
		_next_icon.queue_redraw()
		_next_cost.text = str(goal.cost)
		_next_cost.visible = true
	_next_bar.queue_redraw()
	_badge.visible = n > 0
	_badge_count.text = str(n)


func _on_affordable(_id: String) -> void:
	_refresh_points()
	Sfx.play("point", -2.0)
	_badge.modulate = Color(1.8, 1.5, 1.0)
	var tw := create_tween()
	tw.tween_property(_badge, "modulate", Color.WHITE, 0.7)


func _on_purchased(id: String) -> void:
	_refresh_points()
	if not GameState.playing:
		return
	var u := GameState.get_upgrade(id)
	if u.is_empty():
		return
	var bc: Color = GameState.BRANCHES[u.branch].color
	_cards.push("learned:" + id, {"title": u.name, "sub": "Aprendida", "icon": Glyphs.for_upgrade(u),
		"icon_col": bc.lightened(0.35), "icon_bg": bc.darkened(0.72), "ring": UiTheme.GOLD,
		"value_col": UiTheme.GOLD})


func _on_chamber_cleaned(nest, _ci: int) -> void:
	Sfx.play("chamber", -3.0)
	_cards.push("chamber", {"title": "Câmara limpa", "icon": "mound", "icon_col": UiTheme.LEAF,
		"icon_bg": BG_GREEN, "ring": UiTheme.LEAF, "value_col": UiTheme.LEAF, "pip": 7.0,
		"pips_on": nest.clean_chambers(), "pips_total": nest.chambers.size()}, true)


func _on_nest_cleaned(_nest) -> void:
	Sfx.play("nest_clean", -1.0)
	_cards.push("nest", {"title": "Formigueiro limpo", "icon": "bloom", "icon_col": Color("8fb86a"),
		"icon_bg": BG_GREEN, "ring": UiTheme.LEAF, "value_col": UiTheme.LEAF, "pip": 6.0,
		"pips_on": colony.nests_cleaned(), "pips_total": world.nests.size()})


func _on_queen_eaten(_nest) -> void:
	_cards.push("queen", {"title": "Rainha", "icon": "crown", "icon_col": UiTheme.GOLD, "icon_bg": BG_GOLD,
		"ring": UiTheme.GOLD, "value": "+%d" % GameState.ants(NestScript.QUEEN_VALUE), "value_col": UiTheme.GOLD})


func _on_frenzy(on: bool) -> void:
	if on:
		_cards.push("frenzy", {"title": "Frenesi", "icon": "wings", "icon_col": FRENZY, "icon_bg": BG_FRENZY,
			"ring": FRENZY, "value_col": FRENZY, "bar": 1.0, "frenzy": true})


# ------------------------------------------------------------------ Dicas

## Dica do lugar embaixo da mira (Dicas: Todas ou Poucas), a dica passageira
## e as dicas de controle (só Todas) em cima das habilidades.
func _update_hints(delta: float) -> void:
	var level: int = Settings.hints_level
	_flash_time = maxf(_flash_time - delta, 0.0)
	var parts: Array = []
	if level < 2:
		parts = _flash if _flash_time > 0.0 else _context_hint()
	_hint.set_parts(parts)
	_learn_controls(delta)
	if level == 0:
		_maybe_help()
	_tutorial.set_parts(_tutorial_hint() if level == 0 and _play_time > 1.5 else [])


func _flash_hint(parts: Array, duration: float) -> void:
	_flash = parts
	_flash_time = duration


func _locked(what: String) -> Array:
	return [{"icon": "lock", "col": UiTheme.MUTED}, {"text": what}, {"key": "Tab"}]


## O que dá para fazer aqui: tecla e poucas palavras, ou só ícone e número.
func _context_hint() -> Array:
	if player.dig_nest != null:
		var dc = player.dig_nest.chambers[player.dig_chamber]
		if GameState.dig_level() < dc.size_class:
			return _locked(GameState.get_upgrade(GameState.dig_skill_for(dc.size_class)).name)
		if player.dig_cd > 0.0:
			return [{"icon": "clock", "col": UiTheme.GOLD}, {"num": "%d s" % int(ceil(player.dig_cd))}]
		return [{"key": "E"}, {"text": "Abrir a vala" if dc.half_len > 0.0 else "Abrir câmara"}]
	var p2 := Vector2(player.global_position.x, player.global_position.z)
	# Tronco caído na saída para a área 2.
	if not world.exit_open and world.near_exit(p2, 4.5):
		if not world.exit_breakable:
			return [{"icon": "lock", "col": UiTheme.MUTED}, {"num": str(GameState.ants(colony.remaining()))},
				{"icon": "ant", "col": UiTheme.SAND}]
		if not GameState.can_dig():
			return _locked("Cavar")
		return [{"key": "E"}, {"text": "Quebrar o tronco"}]
	# Câmara aberta por perto: quantas formigas faltam (e a rainha protegida).
	for n in world.nests:
		var ci: int = n.open_chamber_near(p2, 3.0)
		if ci < 0:
			continue
		var c = n.chambers[ci]
		if c.royal and n.queen_alive:
			if c.residents > 0:
				return [{"icon": "crown", "col": UiTheme.GOLD}, {"num": str(GameState.ants(c.residents))},
					{"icon": "ant", "col": UiTheme.SAND}]
			return []
		return [{"num": str(GameState.ants(c.residents))}, {"icon": "ant", "col": UiTheme.SAND}]
	# No monte, só faltam as câmaras do campo.
	var nest = player.near_nest
	if nest != null and not nest.cleaned and _closed_on_mound(nest) == 0 and nest.closed_chambers() > 0:
		var parts: Array = [{"icon": "diamond", "col": Settings.sniff_color()}, {"num": str(nest.closed_chambers())},
			{"text": "no campo"}]
		if GameState.can_sniff():
			parts.append({"key": "Q"})
		return parts
	return []


func _closed_on_mound(nest) -> int:
	var n := 0
	for c in nest.chambers:
		if not c.opened and not c.satellite:
			n += 1
	return n


## Dicas de controle (só com Dicas: Todas), cada uma até você usar.
func _tutorial_hint() -> Array:
	var parts: Array = []
	if not Settings.hint_learned("move"):
		parts += [{"key": "WASD"}, {"text": "Andar"}, {"gap": 16.0}]
	if GameState.can_run() and not Settings.hint_learned("run"):
		parts += [{"key": "Shift"}, {"text": "Correr"}, {"gap": 16.0}]
	if not Settings.hint_learned("map"):
		parts += [{"key": "Tab"}, {"text": "Mapa e habilidades"}, {"gap": 16.0}]
	if not parts.is_empty():
		parts.pop_back()
	return parts


func _learn_controls(delta: float) -> void:
	if not player.controls_enabled:
		return
	var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if mv.length() < 0.2:
		return
	_moved += delta
	if _moved > 0.6:
		Settings.learn_hint("move")
	if GameState.can_run() and Input.is_action_pressed("run"):
		_ran += delta
		if _ran > 0.6:
			Settings.learn_hint("run")


## Só restam formigas dentro de buracos que as suas garras ainda não abrem:
## lembra o que aprender (Dicas: Todas).
func _maybe_help() -> void:
	if _play_time < _help_next or colony.outside_total() > 0 or colony.pools_total() > 0:
		return
	var smallest := 99
	for n in world.nests:
		for c in n.chambers:
			if not c.opened:
				smallest = mini(smallest, c.size_class)
	if smallest == 99 or GameState.dig_level() >= smallest:
		return
	_help_next = _play_time + 45.0
	_flash_hint(_locked(GameState.get_upgrade(GameState.dig_skill_for(smallest)).name), 4.0)


func _on_lick_blocked_running() -> void:
	if Settings.hints_level < 2:
		_flash_hint([{"key": "Shift", "col": UiTheme.TERRACOTTA}, {"text": "Solte para lamber"}], 2.5)


## A rainha ainda está protegida: a dica com a coroa pisca.
func _on_queen_blocked() -> void:
	if _play_time < _queen_bump_next:
		return
	_queen_bump_next = _play_time + 1.5
	_hint.bump(UiTheme.TERRACOTTA)


func _on_ate(count: int, _taj: int, _queens: int) -> void:
	var l := UiTheme.display_label("+%d" % GameState.ants(count), 24 + mini(count, 10), UiTheme.GOLD)
	_soft_shadow(l)
	l.position = size * 0.5 + Vector2(randf_range(24, 44), randf_range(-64, -46))
	_popups.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 54, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


func _on_sniffed(n: int, capped: bool, nearest: float, chambers: int) -> void:
	_sniff.show_result(n, capped, nearest, chambers if GameState.sniff_chambers() else -1,
		GameState.sniff_duration() + 3.0)
	var now := Time.get_ticks_msec() / 1000.0
	_compass.sniff_target = player.sniff_target
	_compass.sniff_until = now + GameState.sniff_duration() + 3.0
	_compass.chamber_marks = player.sniff_chambers.duplicate()
	_compass.nests_until = now + 12.0 if GameState.sniff_nest_counts() else 0.0
	_compass.queens_until = now + 12.0 if GameState.sniff_queens() else 0.0


## Jogo salvo: só um ícone girando no canto.
func show_saved() -> void:
	_save.show_saved()


## Aviso grande (só no fim da clareira). `icon` é um ícone de Glyphs antes do
## texto de baixo (por exemplo, "log").
func big_note(title: String, sub: String = "", duration: float = 3.5, icon: String = "") -> void:
	_big_note.text = title
	_big_sub.text = sub
	_big_icon.kind = icon
	_big_icon.visible = icon != ""
	_big_icon.queue_redraw()
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


## Um ícone de Glyphs num controle.
class GlyphIcon extends Control:
	const Glyphs := preload("res://scripts/ui/glyphs.gd")
	var kind := ""
	var color := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if kind != "":
			Glyphs.paint(self, kind, size * 0.5, minf(size.x, size.y) * 0.45, color)


## Losangos em fila: cheios = feitos, só contorno = falta.
class Pips extends Control:
	var on := 0
	var total := 0
	var pip := 8.0
	var gap := 6.0
	var color := Color("b9d99a")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_counts(done: int, all: int) -> void:
		if done == on and all == total:
			return
		on = done
		total = all
		custom_minimum_size = Vector2(maxf(total * (pip + gap) - gap + 4.0, 0.0), pip * 1.6)
		queue_redraw()

	func _draw() -> void:
		var r := pip * 0.72
		var cy := size.y * 0.5
		for i in total:
			var p := Vector2(2.0 + pip * 0.5 + i * (pip + gap), cy)
			var poly := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
			if i < on:
				draw_colored_polygon(poly, color)
			else:
				poly.append(poly[0])
				draw_polyline(poly, Color(color, 0.5), 1.5, true)


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
		var fs := 34 if value.length() <= 3 else (29 if value.length() == 4 else 25)
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


## Cartão de conquista (canto direito): ícone num círculo, título e um detalhe
## (losangos, barra, número ou uma palavra).
class Card extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	const Glyphs := preload("res://scripts/ui/glyphs.gd")
	const W := 286.0
	const H := 62.0
	var key := ""
	var title := ""
	## Linha pequena em caixa alta embaixo do título.
	var sub := ""
	var icon := ""
	var icon_col := Color.WHITE
	var icon_bg := Color("3a2a10")
	var ring := Color("e8b44f")
	## Texto à direita (+20, ×3, 4 s).
	var value := ""
	var value_col := Color("e8b44f")
	var pips_on := 0
	var pips_total := 0
	var pip := 7.0
	## Barra (0..1) embaixo do título; < 0 = sem barra.
	var bar := -1.0
	## O cartão do Frenesi acompanha o tempo que falta.
	var frenzy := false
	var count := 1
	var life := 4.5
	var glow := 0.0
	var appear := 0.0
	var rank_alpha := 1.0
	var leaving := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(W, H)

	func apply(d: Dictionary) -> void:
		for k in d:
			set(k, d[k])
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, Vector2(W, H))
		var gold := UT.GOLD
		if glow > 0.01:
			for k in 4:
				draw_rect(r.grow(2.0 + k * 3.0), Color(gold, 0.06 * glow * float(4 - k) / 4.0))
		draw_polygon(PackedVector2Array([r.position, Vector2(W, 0), Vector2(W, H), Vector2(0, H)]),
			PackedColorArray([Color(0.063, 0.043, 0.035, 0.93), Color(0.063, 0.043, 0.035, 0.93),
				Color(0.031, 0.024, 0.02, 0.93), Color(0.031, 0.024, 0.02, 0.93)]))
		draw_rect(r.grow(-0.5), Color(gold, 0.85), false, 1.0)
		draw_rect(r.grow(-4.5), Color(gold, 0.25), false, 1.0)
		# Ícone num círculo.
		var ic := Vector2(31.0, H * 0.5)
		for k in 6:
			var t := float(k) / 5.0
			draw_circle(ic, 21.0 * (1.0 - t * 0.75), Color("0d0907").lerp(icon_bg, t))
		draw_arc(ic, 20.0, 0, TAU, 40, ring, 2.0, true)
		Glyphs.paint(self, icon, ic, 12.5, icon_col)
		# Título e detalhe.
		var x0 := 64.0
		var right := W - 14.0
		var vf: Font = UT.display_font()
		var vw := 0.0
		if value != "":
			vw = vf.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
			draw_string(vf, Vector2(right - vw, H * 0.5 + 7.5), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, value_col)
		var avail := right - x0 - (vw + 10.0 if vw > 0.0 else 0.0)
		var ts := 19
		while ts > 14 and vf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x > avail:
			ts -= 1
		var second := pips_total > 0 or bar >= 0.0 or sub != ""
		var ty := 28.0 if second else H * 0.5 + 6.5
		draw_string(vf, Vector2(x0, ty), title, HORIZONTAL_ALIGNMENT_LEFT, avail, ts, UT.PALE)
		if pips_total > 0:
			var step := pip + (5.0 if pip >= 7.0 else 4.0)
			var pr := pip * 0.72
			for i in pips_total:
				var p := Vector2(x0 + pr + i * step, 42.5)
				var poly := PackedVector2Array([p + Vector2(0, -pr), p + Vector2(pr, 0), p + Vector2(0, pr), p + Vector2(-pr, 0)])
				if i < pips_on:
					draw_colored_polygon(poly, UT.LEAF)
				else:
					poly.append(poly[0])
					draw_polyline(poly, Color(UT.LEAF, 0.55), 1.5, true)
		elif bar >= 0.0:
			var br := Rect2(Vector2(x0, 40.0), Vector2(150.0, 4.0))
			draw_rect(br, Color(value_col, 0.2))
			draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(bar, 0.0, 1.0), br.size.y)), value_col)
		elif sub != "":
			draw_string(UT.caps_font(), Vector2(x0, 46.0), sub.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, value_col)


## Pilha de cartões no canto direito: o mais novo em cima; os mais antigos
## descem e vão ficando transparentes. Cartões iguais se juntam (×2, ×3).
class CardStack extends Control:
	const MAX := 3
	const GAP := 10.0
	const RANK_ALPHA := [1.0, 0.88, 0.6]
	var cards: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func push(key: String, d: Dictionary, group: bool = false) -> void:
		var card: Card = null
		for c in cards:
			if c.key == key and not c.leaving and c.life > 0.5:
				card = c
				break
		if card == null:
			card = Card.new()
			card.key = key
			add_child(card)
		else:
			cards.erase(card)
			if group:
				card.count += 1
				d["value"] = "×%d" % card.count
		card.apply(d)
		card.life = 4.5
		card.glow = 1.0
		cards.push_front(card)
		var shown := 0
		for c in cards:
			if c.leaving:
				continue
			shown += 1
			if shown > MAX:
				c.leaving = true
				c.life = minf(c.life, 0.35)

	func _process(delta: float) -> void:
		for i in range(cards.size() - 1, -1, -1):
			var c: Card = cards[i]
			if c.frenzy and not c.leaving and GameState.frenzy_time > 0.0:
				c.life = GameState.frenzy_time + 0.6
				c.bar = GameState.frenzy_time / GameState.FRENZY_TIME
				c.value = "%d s" % int(ceil(GameState.frenzy_time))
			c.life -= delta
			if c.life <= 0.0:
				cards.remove_at(i)
				c.queue_free()
		var rank := 0
		for c in cards:
			c.appear = minf(c.appear + delta * 4.0, 1.0)
			c.glow = maxf(c.glow - delta * 0.9, 0.0)
			var e := 1.0 - pow(1.0 - c.appear, 3.0)
			if not c.leaving:
				var ty := rank * (Card.H + GAP)
				c.position.y = ty if c.appear < 0.05 else lerpf(c.position.y, ty, minf(delta * 12.0, 1.0))
				c.position.x = (1.0 - e) * 60.0
				c.rank_alpha = RANK_ALPHA[mini(rank, RANK_ALPHA.size() - 1)]
				rank += 1
			c.modulate.a = e * c.rank_alpha * clampf(c.life / 0.5, 0.0, 1.0)
			c.queue_redraw()


## Dica curta: teclas em quadradinhos, poucas palavras, ícones e números, numa
## linha centralizada. Partes: {"key"}, {"text"}, {"num"}, {"icon", "col"}, {"gap"}.
class HintRow extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	const Glyphs := preload("res://scripts/ui/glyphs.gd")
	const SPACE := 8.0
	var _parts: Array = []
	var _alpha := 0.0
	var _want := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.0

	func set_parts(parts: Array) -> void:
		_want = not parts.is_empty()
		if _want and parts != _parts:
			_parts = parts.duplicate(true)
			queue_redraw()

	## Pisca numa cor (quando você tenta algo que ainda não dá).
	func bump(col: Color) -> void:
		self_modulate = col.lightened(0.3)
		var tw := create_tween()
		tw.tween_property(self, "self_modulate", Color.WHITE, 0.6)

	func _process(delta: float) -> void:
		_alpha = move_toward(_alpha, 1.0 if _want else 0.0, delta * (6.0 if _want else 4.0))
		modulate.a = _alpha
		if _alpha <= 0.0 and not _want and not _parts.is_empty():
			_parts = []
			queue_redraw()

	func _measure(p: Dictionary) -> float:
		if p.has("key"):
			return UT.display_bold_font().get_string_size(p.key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 12.0
		if p.has("text"):
			return UT.semi_font().get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		if p.has("num"):
			return UT.display_font().get_string_size(p.num, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		if p.has("icon"):
			return 20.0
		return float(p.get("gap", 0.0))

	func _baseline(f: Font, fs: int, cy: float) -> float:
		return cy + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5

	func _shadowed(f: Font, pos: Vector2, text: String, fs: int, col: Color) -> void:
		draw_string_outline(f, pos + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.4))
		draw_string(f, pos + Vector2(0, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _draw() -> void:
		if _parts.is_empty():
			return
		var total := 0.0
		for p in _parts:
			total += _measure(p) + SPACE
		total -= SPACE
		var x := (size.x - total) * 0.5
		var cy := size.y * 0.5
		for p in _parts:
			var w := _measure(p)
			if p.has("key"):
				var col: Color = p.get("col", UT.GOLD)
				var f: Font = UT.display_bold_font()
				var r := Rect2(Vector2(x, cy - 10.5), Vector2(w, 21.0))
				draw_rect(r, Color(0.04, 0.028, 0.024, 0.82))
				draw_rect(r.grow(-0.5), Color(col, 0.85), false, 1.0)
				draw_string(f, Vector2(x + 6.0, _baseline(f, 14, cy)), p.key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
			elif p.has("text"):
				var f: Font = UT.semi_font()
				_shadowed(f, Vector2(x, _baseline(f, 17, cy)), p.text, 17, p.get("col", UT.CREAM))
			elif p.has("num"):
				var f: Font = UT.display_font()
				_shadowed(f, Vector2(x, _baseline(f, 17, cy)), p.num, 17, p.get("col", UT.PALE))
			elif p.has("icon"):
				var c := Vector2(x + 10.0, cy)
				Glyphs.paint(self, p.icon, c + Vector2(0, 1.5), 9.0, Color(0, 0, 0, 0.7))
				Glyphs.paint(self, p.icon, c, 9.0, p.get("col", UT.GOLD))
			x += w + SPACE


## Resultado do Faro, em cima do botão de Farejar: quantas formigas e a que
## distância está a mais perto (e as câmaras fechadas, com o Faro de Câmara).
class SniffChip extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	const Glyphs := preload("res://scripts/ui/glyphs.gd")
	var count := ""
	var dist := ""
	var chambers := -1
	var time := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_result(n: int, capped: bool, nearest: float, ch: int, duration: float) -> void:
		count = ("%d+" % GameState.ants(n)) if capped else str(GameState.ants(n))
		dist = ("· %d m" % int(round(nearest))) if n > 0 else ""
		chambers = ch
		time = duration
		modulate.a = 1.0
		queue_redraw()

	func _process(delta: float) -> void:
		if time <= 0.0:
			return
		time -= delta
		modulate.a = clampf(time / 0.6, 0.0, 1.0)
		if time <= 0.0:
			queue_redraw()

	func _draw() -> void:
		if time <= 0.0:
			return
		var scent: Color = Settings.sniff_color()
		var nf: Font = UT.display_font()
		var df: Font = UT.semi_font()
		var cw := nf.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var dw := df.get_string_size(dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x if dist != "" else 0.0
		var chs := str(chambers)
		var chw := nf.get_string_size(chs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var w := 10.0 + 18.0 + 7.0 + cw + (6.0 + dw if dist != "" else 0.0) + (14.0 + 12.0 + 6.0 + chw if chambers >= 0 else 0.0) + 10.0
		var r := Rect2(Vector2((size.x - w) * 0.5, 0.0), Vector2(w, size.y))
		draw_rect(r, Color(0.04, 0.028, 0.024, 0.86))
		draw_rect(r.grow(-0.5), Color(scent, 0.6), false, 1.0)
		var cy := size.y * 0.5
		var base := cy + (nf.get_ascent(16) - nf.get_descent(16)) * 0.5
		var x := r.position.x + 10.0
		Glyphs.paint(self, "nose", Vector2(x + 10.0, cy), 8.5, scent.lightened(0.3))
		x += 18.0 + 7.0
		draw_string(nf, Vector2(x, base), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UT.CREAM)
		x += cw
		if dist != "":
			x += 6.0
			draw_string(df, Vector2(x, base), dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UT.MUTED)
			x += dw
		if chambers >= 0:
			x += 14.0
			Glyphs.paint(self, "diamond", Vector2(x + 6.0, cy), 7.5, scent)
			x += 12.0 + 6.0
			draw_string(nf, Vector2(x, base), chs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UT.CREAM)


## Jogo salvo: um anel dourado girando no canto, sem texto.
class SaveIcon extends Control:
	const SHOW := 2.2
	var time := 0.0
	var _spin := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.0

	func show_saved() -> void:
		time = SHOW

	func _process(delta: float) -> void:
		if time <= 0.0:
			return
		time = maxf(time - delta, 0.0)
		_spin += delta * 5.0
		modulate.a = clampf(time / 0.6, 0.0, 1.0) * clampf((SHOW - time) / 0.25, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var gold := Color("e8b44f")
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_arc(c, r, 0, TAU, 40, Color(gold, 0.3), 2.0, true)
		draw_arc(c, r, _spin, _spin + PI * 0.75, 20, gold, 2.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)]), gold)


## Bússola: faixa com moldura dourada, risquinhos a cada 15° (os de 45° maiores),
## direções e um medalhão no meio com o rumo. Os formigueiros são montinhos em
## cima da faixa; o que está à sua frente mostra a distância e as câmaras dele
## (verdes = limpas) numa plaquinha embaixo.
class Compass extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	var player
	var world
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

	func _diamond_outline(p: Vector2, r: float, col: Color) -> void:
		draw_polyline(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0),
			p + Vector2(0, -r)]), col, 1.5, true)

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

	## Plaquinha embaixo da faixa: distância e as câmaras do formigueiro
	## (cheias = limpas, só contorno = ainda com formigas).
	func _plate(top_center: Vector2, nest) -> void:
		var f: Font = UT.display_font()
		var dist: float = nest.global_position.distance_to(player.global_position)
		var text := "%d m" % int(dist)
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var total: int = nest.chambers.size()
		var done: int = nest.clean_chambers()
		var pw := total * 10.0 - 4.0 if total > 0 else 0.0
		var w := 10.0 + tw + (9.0 + pw if total > 0 else 0.0) + 10.0
		var r := Rect2(Vector2(top_center.x - w * 0.5, top_center.y), Vector2(w, 22.0))
		r.position.x = clampf(r.position.x, 0.0, size.x - r.size.x)
		draw_rect(r, Color(0.04, 0.028, 0.024, 0.92))
		draw_rect(r.grow(-0.5), Color(UT.GOLD, 0.75), false, 1.0)
		draw_string(f, Vector2(r.position.x + 10.0, r.end.y - 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UT.PALE)
		var x := r.position.x + 10.0 + tw + 9.0 + 3.0
		var cy := r.get_center().y
		for i in total:
			if i < done:
				_diamond(Vector2(x, cy), 4.2, UT.LEAF)
			else:
				_diamond_outline(Vector2(x, cy), 3.8, UT.GOLD)
			x += 10.0

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
			var col := Color(gold, 0.8 * _fade(x))
			if n.cleaned:
				col = Color(UT.LEAF, 0.65 * _fade(x))
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
			if now < nests_until and not n.cleaned:
				_text_centered(UT.display_bold_font(), x, tag_y, str(GameState.ants(n.remaining())), 14, UT.PALE)
		if faced != null:
			_plate(Vector2(_x_for(_yaw_to(faced.global_position)), b.end.y + 6.0), faced)
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
