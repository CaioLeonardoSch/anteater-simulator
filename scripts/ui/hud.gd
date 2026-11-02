extends Control
## HUD da partida: contador de formigas, progresso até o próximo ponto de
## habilidade, bússola com formigueiros e ondas, mira, habilidades e avisos.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

var player
var swarm
var colony
var world

var _count_label: Label
var _goal_label: Label
var _next_bar: ProgressBar
var _next_label: Label
var _points_badge: PanelContainer
var _points_label: Label
var _timer_label: Label
var _wave_label: Label
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
	player.dug.connect(func(nest_name, n): note("Você cavou o %s: %d formigas saíram!" % [nest_name, n], UiTheme.GOLD))
	player.tremor_used.connect(func(n): note("Tremor! %d formigas ficaram tontas" % n, UiTheme.SAND))
	player.sniffed.connect(_on_sniffed)
	player.soldier_knocked.connect(_on_soldier)
	colony.wave_announced.connect(_on_wave)
	colony.final_wave.connect(func(n): big_note("RETA FINAL", "As últimas %d formigas saíram de casa!" % n))
	GameState.ants_eaten_changed.connect(_on_eaten_changed)
	GameState.skill_point_gained.connect(_on_point)
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
		"WASD andar  ·  Shift correr  ·  Mouse olhar  ·  Clique segurado: lamber  ·  Q ou botão direito: farejar  ·  TAB: habilidades",
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
	_goal_label = UiTheme.label("/ 1000", 26, UiTheme.SAND)
	_goal_label.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(_goal_label)
	_next_bar = ProgressBar.new()
	_next_bar.custom_minimum_size = Vector2(270, 14)
	_next_bar.show_percentage = false
	_next_bar.max_value = 100
	v.add_child(_next_bar)
	_next_label = UiTheme.label("Próximo ponto de habilidade: 0/100", 17, UiTheme.SAND)
	v.add_child(_next_label)
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
	if colony.final_released:
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
				a.locked = false
				a.cooldown = player.sniff_cd / GameState.sniff_cooldown() if player.sniff_cd > 0.0 else 0.0
			"dig":
				a.locked = not GameState.can_dig()
				a.cooldown = 0.0
				if player.near_nest != null and player.near_nest.dig_cooldown > 0.0:
					a.cooldown = player.near_nest.dig_cooldown / 18.0
				a.progress = player.dig_progress
			"tremor":
				a.locked = not GameState.can_tremor()
				a.cooldown = player.tremor_cd / 7.0 if player.tremor_cd > 0.0 else 0.0
		a.queue_redraw()
	# Dica de contexto.
	var hint := ""
	if player.near_nest != null:
		if not GameState.can_dig():
			hint = "Formigueiro! Desbloqueie Garras Afiadas na árvore (TAB) para cavar"
		elif player.near_nest.dig_cooldown > 0.0:
			hint = "Formigueiro vazio por enquanto (%ds)" % int(ceil(player.near_nest.dig_cooldown))
		else:
			hint = "Segure E para cavar o formigueiro"
	_hint.text = hint
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
		_vignette_mat.set_shader_parameter("tint", Color(1.0, 0.8, 0.35))
	_vignette_mat.set_shader_parameter("amount", vig)
	_compass.queue_redraw()
	_crosshair.queue_redraw()


func _on_eaten_changed(total: int, _delta: int) -> void:
	var into := total % GameState.ANTS_PER_POINT
	if total >= GameState.GOAL:
		into = GameState.ANTS_PER_POINT
	_next_bar.value = into
	if total >= GameState.GOAL - GameState.ANTS_PER_POINT:
		_next_label.text = "Rumo às 1000: %d/100" % into
	else:
		_next_label.text = "Próximo ponto de habilidade: %d/100" % into


func _refresh_points() -> void:
	var n := GameState.points_available()
	_points_badge.visible = n > 0
	_points_label.text = ("1 ponto de habilidade  [TAB]" if n == 1 else "%d pontos de habilidade  [TAB]" % n)


func _on_point(_available: int) -> void:
	_refresh_points()
	Sfx.play("point", -2.0)
	big_note("%d FORMIGAS!" % (GameState.points_earned * GameState.ANTS_PER_POINT), "Novo ponto de habilidade: aperte TAB para evoluir")


func _on_ate(count: int, _taj: int) -> void:
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


var _soldier_notes := 0
var _soldier_next := 0.0


func _on_soldier() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _soldier_notes >= 3 or now < _soldier_next:
		return
	_soldier_notes += 1
	_soldier_next = now + 20.0
	note("Soldado! Ele aguenta uma lambida antes de grudar", UiTheme.TERRACOTTA, 2.4)


func _on_sniffed(n: int) -> void:
	if n == 0:
		note("Nenhuma formiga por perto... siga as trilhas de terra", UiTheme.SAND)
	else:
		note("Faro: %d formigas por perto" % n, UiTheme.SAND, 2.0)
	_compass.sniff_target = player.sniff_target
	_compass.sniff_until = Time.get_ticks_msec() / 1000.0 + GameState.sniff_duration() + 3.0


func _on_wave(wave: int, nest_name: String, count: int, nest_index: int) -> void:
	big_note("ONDA %d" % wave, "%d formigas saindo do %s" % [count, nest_name])
	Sfx.play("wave", -3.0)
	_compass.wave_nest = world.nests[nest_index]
	_compass.wave_until = Time.get_ticks_msec() / 1000.0 + 25.0


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
			var base := Vector2(x, size.y - 22)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-9, 6), base + Vector2(0, -6), base + Vector2(9, 6)]), col)
			var dist := p.distance_to(player.global_position)
			if absf(x - size.x * 0.5) < 60 or is_wave:
				var txt := "%dm" % int(dist)
				if is_wave:
					txt = "ONDA %dm" % int(dist)
				draw_string(font, base + Vector2(-22, 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
		if sniff_target != Vector3.INF and now < sniff_until:
			var x := _x_for(_yaw_to(sniff_target))
			x = clampf(x, 14, size.x - 14)
			draw_circle(Vector2(x, size.y * 0.5 - 4), 9.0, Color(1.0, 0.78, 0.3, 0.9))
			draw_circle(Vector2(x, size.y * 0.5 - 4), 4.0, Color(0.4, 0.2, 0.05))
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
