extends Control
## Árvore de habilidades com cara de constelação (inspirada na árvore passiva de
## Path of Exile, só no visual): os 5 ramos (Língua, Garras, Patas, Faro e
## Escalada + Cauda) saem do centro, onde ficam os pontos. Cada habilidade é um
## círculo com ícone, e as ligações acendem em dourado conforme você aprende.
## Passe o mouse (ou o controle) numa habilidade para ver o que ela faz; clique
## para aprender. Cada 10 formigas comidas valem 1 ponto e cada habilidade tem o seu
## preço; as linhas de um ramo não se excluem. O que ainda não existe no jogo
## aparece com cadeado. Dá para redistribuir os pontos de graça.

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Glyphs := preload("res://scripts/ui/glyphs.gd")

## Direção de cada ramo, em graus (0 = direita, 90 = para baixo), na ordem de
## GameState.BRANCHES.
const BRANCH_ANGLE := [-150.0, -30.0, 150.0, 30.0, 90.0]
## Abertura entre as linhas de um ramo.
const LINE_SPREAD := 19.0
## Distância do centro até a 1ª habilidade do ramo, e de um nível para o outro.
const ROOT_DIST := 165.0
const ROW_STEP := 74.0
## A tela é larga: o desenho estica mais na horizontal.
const STRETCH := Vector2(1.42, 0.98)
const NODE_R := 22.0
const ROOT_R := 30.0
const CENTER_R := 64.0
const HEADER_H := 70.0
const FOOTER_H := 128.0

var _canvas: TreeCanvas
var _nodes: Dictionary = {}
var _offsets: Dictionary = {}
var _center := Vector2.ZERO
var _tip: PanelContainer
var _tip_title: Label
var _tip_where: Label
var _tip_desc: Label
var _tip_state: Label
var _tip_stats: GridContainer
var _respec: Button
var _first_node: Control
var _shown_id := ""
var _hover_id := ""
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = TreeCanvas.new()
	_canvas.tree = self
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_canvas)
	for u in GameState.UPGRADES:
		_offsets[u.id] = _offset_of(u)
		var node := SkillNode.new()
		node.id = u.id
		node.tree = self
		node.root = (u.requires as Array).is_empty()
		node.radius = ROOT_R if node.root else NODE_R
		node.color = GameState.BRANCHES[u.branch].color
		node.glyph = Glyphs.for_upgrade(u)
		node.pressed.connect(_on_node_pressed.bind(u.id))
		node.focus_entered.connect(_show_tip.bind(u.id))
		node.focus_exited.connect(_on_focus_lost)
		node.mouse_entered.connect(_on_hover.bind(u.id))
		node.mouse_exited.connect(_on_unhover.bind(u.id))
		_canvas.add_child(node)
		_nodes[u.id] = node
		if _first_node == null:
			_first_node = node
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 18)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -86
	footer.offset_bottom = -26
	add_child(footer)
	_respec = UiTheme.button("Redistribuir pontos", 280)
	_respec.pressed.connect(_on_respec)
	footer.add_child(_respec)
	var back := UiTheme.button("Voltar ao jogo  [%s]" % Settings.key_label("skill_tree").to_upper(), 300)
	back.pressed.connect(func(): closed.emit())
	footer.add_child(back)
	_build_tip()
	resized.connect(_layout)
	GameState.upgrade_purchased.connect(func(_id): refresh())
	GameState.upgrade_affordable.connect(func(_id): refresh())
	GameState.ants_eaten_changed.connect(_on_eaten_changed)
	GameState.skills_reset.connect(refresh)
	_layout()
	refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	# As habilidades que já dá para aprender pulsam.
	for id in _nodes:
		if GameState.upgrade_state(id) == 1:
			(_nodes[id] as Control).queue_redraw()


## Com o controle (ou as setas), a primeira direção apertada escolhe a 1ª habilidade.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or _first_node == null:
		return
	for a in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		if event.is_action_pressed(a) and get_viewport().gui_get_focus_owner() == null:
			_first_node.grab_focus()
			get_viewport().set_input_as_handled()
			return


# ------------------------------------------------------------------ Montagem

## Posição de uma habilidade em relação ao centro: cada ramo sai numa direção,
## e as linhas dele se abrem em leque, um nível mais longe a cada habilidade.
func _offset_of(u: Dictionary) -> Vector2:
	var b: int = u.branch
	var lines: int = GameState.BRANCHES[b].lines.size()
	var ang: float = BRANCH_ANGLE[b]
	if lines > 1 and int(u.col) >= 0:
		ang += (float(u.col) - (lines - 1) * 0.5) * LINE_SPREAD
	var d := ROOT_DIST + float(u.row) * ROW_STEP
	var r := deg_to_rad(ang)
	return Vector2(cos(r) * STRETCH.x, sin(r) * STRETCH.y) * d


func _layout() -> void:
	_center = Vector2(size.x * 0.5, (HEADER_H + size.y - FOOTER_H) * 0.5)
	for id in _nodes:
		var node: Control = _nodes[id]
		node.position = (_center + _offsets[id] - node.size * 0.5).round()
	_canvas.queue_redraw()
	if not _shown_id.is_empty():
		_show_tip(_shown_id)


func node_pos(id: String) -> Vector2:
	return _center + _offsets.get(id, Vector2.ZERO)


func center() -> Vector2:
	return _center


func _build_tip() -> void:
	_tip = PanelContainer.new()
	var style := UiTheme.frame(Color(0.065, 0.044, 0.036, 0.97), Color(0.035, 0.026, 0.021, 0.97), Color(UiTheme.GOLD, 0.8),
		Color(UiTheme.GOLD, 0.25), 18, 12)
	style.corners = true
	_tip.add_theme_stylebox_override("panel", style)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	add_child(_tip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(v)
	_tip_title = UiTheme.display_label("", 25, UiTheme.GOLD)
	v.add_child(_tip_title)
	_tip_where = UiTheme.label("", 15, UiTheme.SAND)
	v.add_child(_tip_where)
	var sep := ColorRect.new()
	sep.color = Color(UiTheme.GOLD, 0.3)
	sep.custom_minimum_size = Vector2(0, 1)
	v.add_child(sep)
	_tip_desc = UiTheme.label("", 18, UiTheme.CREAM)
	_tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_desc.custom_minimum_size = Vector2(340, 0)
	v.add_child(_tip_desc)
	# Antes → depois, em números.
	_tip_stats = GridContainer.new()
	_tip_stats.columns = 2
	_tip_stats.add_theme_constant_override("h_separation", 16)
	_tip_stats.add_theme_constant_override("v_separation", 1)
	_tip_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_tip_stats)
	_tip_state = UiTheme.label("", 17, UiTheme.SAND, true)
	_tip_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_state.custom_minimum_size = Vector2(340, 0)
	v.add_child(_tip_state)


# ------------------------------------------------------------------ Ações

func _on_hover(id: String) -> void:
	_hover_id = id
	_show_tip(id)
	Sfx.play("ui_hover", -16.0, 1.0, 0.05)


func _on_unhover(id: String) -> void:
	if _hover_id == id:
		_hover_id = ""
	var focused := get_viewport().gui_get_focus_owner()
	if focused is SkillNode:
		_show_tip((focused as SkillNode).id)
	else:
		_hide_tip()


func _on_focus_lost() -> void:
	if _hover_id.is_empty():
		_hide_tip()


func _on_eaten_changed(_total: int, _delta: int) -> void:
	if visible:
		refresh()


func _on_node_pressed(id: String) -> void:
	if GameState.buy(id):
		Sfx.play("upgrade", -2.0)
		var node: Control = _nodes[id]
		node.pivot_offset = node.size * 0.5
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector2(1.25, 1.25), 0.1)
		tw.tween_property(node, "scale", Vector2.ONE, 0.22)
	else:
		Sfx.play("deny", -6.0)
	# Clique do mouse: a habilidade não fica escolhida (senão o quadro não some
	# quando o mouse sai). Com o controle, ela continua escolhida.
	if _hover_id == id:
		var node: Control = _nodes[id]
		if node.has_focus():
			node.release_focus()
	_show_tip(id)


func _on_respec() -> void:
	if GameState.points_spent == 0 and GameState.purchased.is_empty():
		Sfx.play("deny", -6.0)
		return
	GameState.respec()
	Sfx.play("ui_open", -4.0)


# ------------------------------------------------------------------ Estado

func refresh() -> void:
	if _respec:
		_respec.disabled = GameState.purchased.is_empty()
	for id in _nodes:
		(_nodes[id] as Control).queue_redraw()
	_canvas.queue_redraw()
	if _tip.visible and not _shown_id.is_empty():
		_show_tip(_shown_id)


func _hide_tip() -> void:
	_tip.visible = false
	_shown_id = ""


## Quadro com o nome, o ramo, o que a habilidade faz e quanto custa, ao lado dela.
func _show_tip(id: String) -> void:
	var u := GameState.get_upgrade(id)
	if u.is_empty():
		_hide_tip()
		return
	_shown_id = id
	var branch: Dictionary = GameState.BRANCHES[u.branch]
	_tip_title.text = u.name
	_tip_title.add_theme_color_override("font_color", branch.color.lightened(0.25))
	var where: String = branch.name
	if int(u.col) >= 0 and branch.lines.size() > 1:
		where += " · linha de %s" % branch.lines[u.col]
	_tip_where.text = where
	_tip_desc.text = u.desc
	for c in _tip_stats.get_children():
		_tip_stats.remove_child(c)
		c.queue_free()
	var changes := GameState.stat_changes(id)
	_tip_stats.visible = not changes.is_empty()
	for ch in changes:
		var l := UiTheme.label(ch.label, 16, UiTheme.SAND)
		_tip_stats.add_child(l)
		var val := UiTheme.label("%s  →  %s" % [ch.before, ch.after], 16, branch.color.lightened(0.35))
		val.add_theme_font_override("font", UiTheme.display_bold_font())
		_tip_stats.add_child(val)
	var pts := GameState.points_available()
	var cost: int = u.cost
	var col := UiTheme.SAND
	var text := ""
	match GameState.upgrade_state(id):
		2:
			text = "Aprendida."
			col = UiTheme.GOLD
		3:
			text = "Custa %d pontos · ainda não disponível." % cost
		4:
			var gate := GameState.gate_of(id)
			text = "Abre com %s insetos comidos (faltam %s) · custa %d pontos." % [
				_thousands(gate), _thousands(gate - GameState.ants_eaten), cost]
		0:
			text = "Custa %d pontos." % cost
		_:
			if pts >= cost:
				text = "Custa %d pontos · clique para aprender." % cost
				col = branch.color.lightened(0.3)
			else:
				text = "Custa %d pontos · faltam %d insetos." % [cost, GameState.ants_needed(cost)]
	_tip_state.text = text
	_tip_state.add_theme_color_override("font_color", col)
	_tip.visible = true
	_tip.reset_size()
	var tsize := _tip.get_combined_minimum_size()
	_tip.size = tsize
	_tip.position = _tip_position(id, (u.requires as Array).is_empty(), tsize)


## "13 000" (espaço separando os milhares).
static func _thousands(v: int) -> String:
	var t := str(maxi(v, 0))
	var out := ""
	while t.length() > 3:
		out = " " + t.substr(t.length() - 3) + out
		t = t.substr(0, t.length() - 3)
	return t + out


## Onde fica o quadro: ao lado da habilidade (do lado de fora da árvore) quando
## cabe sem cobri-la; senão, acima ou abaixo dela.
func _tip_position(id: String, is_root: bool, tsize: Vector2) -> Vector2:
	var p := node_pos(id)
	var r := (ROOT_R if is_root else NODE_R) + 22.0
	var top := HEADER_H
	var bottom := size.y - FOOTER_H
	var keep := Rect2(p - Vector2.ONE * (r - 6.0), Vector2.ONE * (r - 6.0) * 2.0)
	var side := Vector2(p.x - r - tsize.x if p.x < _center.x - 10.0 else p.x + r, p.y - tsize.y * 0.5)
	side.x = clampf(side.x, 12.0, size.x - tsize.x - 12.0)
	side.y = clampf(side.y, top, bottom - tsize.y)
	if not Rect2(side, tsize).intersects(keep):
		return side
	var x := clampf(p.x - tsize.x * 0.5, 12.0, size.x - tsize.x - 12.0)
	var above := Vector2(x, p.y - r - tsize.y)
	var below := Vector2(x, p.y + r + 8.0)
	# Na metade de baixo da tela, prefere em cima; na de cima, embaixo.
	var order := [above, below] if p.y > _center.y else [below, above]
	for cand in order:
		if cand.y >= top - 50.0 and cand.y + tsize.y <= size.y - 12.0:
			return cand
	return order[0]


func open() -> void:
	_hover_id = ""
	_hide_tip()
	refresh()
	visible = true
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	# Teste (capturas): já abre com uma habilidade escolhida, como com o controle.
	if DevTools.args.has("focus"):
		show_skill(String(DevTools.args.focus))


## Mostra uma habilidade (com a explicação dela), como se o cursor estivesse nela.
func show_skill(id: String) -> void:
	if _nodes.has(id):
		(_nodes[id] as Control).grab_focus.call_deferred()


# ------------------------------------------------------------------ Desenho

## Fundo: céu escuro com estrelas, órbitas em volta do centro, as ligações
## entre as habilidades, o medalhão do centro com os pontos e os nomes.
class TreeCanvas extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	var tree
	var _stars: Array[Vector4] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 260:
			_stars.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.7), rng.randf_range(0.12, 0.6)))

	func _draw() -> void:
		if tree == null:
			return
		var c: Vector2 = tree.center()
		# Céu: escuro nas bordas, um brilho quente no meio.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.024, 0.024))
		for k in 8:
			var t := float(k) / 7.0
			_ellipse_fill(c, Vector2(1.5, 1.0) * lerpf(560.0, 90.0, t), Color(0.55, 0.3, 0.16, 0.022 + t * 0.012))
		for s in _stars:
			var p := Vector2(s.x * size.x, s.y * size.y)
			draw_circle(p, s.z, Color(1.0, 0.9, 0.75, s.w))
		# Órbitas (as distâncias de cada nível).
		var st: Vector2 = tree.STRETCH
		for k in 6:
			var d: float = tree.ROOT_DIST + k * tree.ROW_STEP
			_ellipse_line(c, st * d, Color(1.0, 0.8, 0.5, 0.05 if k > 0 else 0.08), 1.5)
		# Ligações: do centro até a 1ª habilidade de cada ramo, e de cada uma
		# para a seguinte.
		for u in GameState.UPGRADES:
			var to: Vector2 = tree.node_pos(u.id)
			var state := GameState.upgrade_state(u.id)
			var bcol: Color = GameState.BRANCHES[u.branch].color
			if (u.requires as Array).is_empty():
				var dir := (to - c).normalized()
				_link(c + dir * (tree.CENTER_R + 4.0), to, 2 if state == 2 else (1 if state == 1 else 0), bcol)
				continue
			for r in u.requires:
				var from: Vector2 = tree.node_pos(String(r))
				var lit := 0
				if state == 2:
					lit = 2
				elif state == 1:
					lit = 1
				_link(from, to, lit, bcol)
		# Medalhão do centro, com os pontos para gastar.
		draw_circle(c, tree.CENTER_R + 10.0, Color(1.0, 0.76, 0.3, 0.07))
		draw_circle(c, tree.CENTER_R + 3.0, Color(0.03, 0.02, 0.02))
		draw_circle(c, tree.CENTER_R, Color(0.16, 0.09, 0.06))
		draw_circle(c, tree.CENTER_R - 9.0, Color(0.1, 0.06, 0.045))
		draw_arc(c, tree.CENTER_R, 0, TAU, 64, UT.GOLD, 3.0, true)
		draw_arc(c, tree.CENTER_R - 9.0, 0, TAU, 64, Color(UT.GOLD, 0.55), 1.5, true)
		draw_arc(c, tree.CENTER_R + 8.0, 0, TAU, 64, Color(UT.GOLD, 0.35), 1.2, true)
		for k in 16:
			var a := TAU * k / 16.0
			var dir := Vector2(cos(a), sin(a))
			var long := k % 4 == 0
			draw_line(c + dir * (tree.CENTER_R + 3.0), c + dir * (tree.CENTER_R + (12.0 if long else 7.0)),
				Color(UT.GOLD, 0.8 if long else 0.45), 2.0 if long else 1.2, true)
		var pts := GameState.points_available()
		var font: Font = UT.display_font()
		var num := str(pts)
		var nsz := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 42)
		draw_string(font, c + Vector2(-nsz.x * 0.5, 9), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, UT.PALE)
		var word := "PONTO" if pts == 1 else "PONTOS"
		var cf: Font = UT.caps_font()
		var wsz := cf.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string(cf, c + Vector2(-wsz.x * 0.5, 30), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UT.MUTED)
		# Nome de cada ramo, no caminho entre o centro e a 1ª habilidade dele.
		for b in GameState.BRANCHES.size():
			var branch: Dictionary = GameState.BRANCHES[b]
			var root_id := ""
			for u in GameState.UPGRADES:
				if int(u.branch) == b and (u.requires as Array).is_empty():
					root_id = u.id
					break
			if root_id.is_empty():
				continue
			var rp: Vector2 = tree.node_pos(root_id)
			var dir := (rp - c).normalized()
			var gap_a: float = tree.CENTER_R + 8.0
			var gap_b: float = (rp - c).length() - tree.ROOT_R - 8.0
			_pill(c + dir * (gap_a + gap_b) * 0.5, branch.name, 18, branch.color, true)
		# Nome de cada linha, depois da última habilidade dela.
		for b in GameState.BRANCHES.size():
			var branch: Dictionary = GameState.BRANCHES[b]
			if branch.lines.size() < 2:
				continue
			for col in branch.lines.size():
				var last := {}
				for u in GameState.UPGRADES:
					if int(u.branch) == b and int(u.col) == col and (last.is_empty() or int(u.row) > int(last.row)):
						last = u
				if last.is_empty():
					continue
				var lp: Vector2 = tree.node_pos(last.id)
				# Na mesma direção da linha (da habilidade anterior até a última).
				var prev := c
				if not (last.requires as Array).is_empty():
					prev = tree.node_pos(String(last.requires[0]))
				var dir := (lp - prev).normalized()
				# Encostado na última habilidade, sem cobrir o círculo nem o preço.
				var half := _pill_size(branch.lines[col], 14, false) * 0.5
				var gap: float = tree.NODE_R + 12.0 + absf(dir.x) * half.x + absf(dir.y) * half.y
				if dir.y > 0.3:
					gap += 16.0
				_pill(lp + dir * gap, branch.lines[col], 14, branch.color, false)

	## Ligação: escura (0), clara (1, a próxima que dá para aprender) ou dourada (2, aprendida).
	func _link(a: Vector2, b: Vector2, lit: int, _bcol: Color) -> void:
		draw_line(a, b, Color(0.02, 0.012, 0.01, 0.9), 8.0, true)
		match lit:
			2:
				draw_line(a, b, Color(UT.GOLD, 0.28), 10.0, true)
				draw_line(a, b, UT.GOLD, 4.0, true)
				draw_line(a, b, Color(1.0, 0.95, 0.75), 1.5, true)
			1:
				draw_line(a, b, Color(1.0, 0.93, 0.8, 0.55), 2.5, true)
			_:
				draw_line(a, b, Color(0.36, 0.28, 0.22), 3.0, true)

	func _pill_size(text: String, fsize: int, big: bool) -> Vector2:
		var tsz := (UT.display_bold_font() if big else UT.bold_font()).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var pad := Vector2(12, 5) if big else Vector2(9, 3)
		return Vector2(tsz.x, fsize * 1.24) + pad * 2.0

	func _pill(p: Vector2, text: String, fsize: int, col: Color, big: bool) -> void:
		var font: Font = UT.display_bold_font() if big else UT.bold_font()
		var tsz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var pad := Vector2(12, 5) if big else Vector2(9, 3)
		var rect := Rect2(p - Vector2(tsz.x * 0.5, fsize * 0.62) - pad, Vector2(tsz.x, fsize * 1.24) + pad * 2.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.035, 0.03, 0.95)
		sb.border_color = Color(col, 0.75 if big else 0.5)
		sb.set_border_width_all(2 if big else 1)
		sb.set_corner_radius_all(int(rect.size.y * 0.5))
		sb.anti_aliasing = true
		draw_style_box(sb, rect)
		draw_string(font, Vector2(p.x - tsz.x * 0.5, p.y + fsize * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			fsize, col.lightened(0.3 if big else 0.2))

	func _ellipse_fill(c: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)

	func _ellipse_line(c: Vector2, r: Vector2, col: Color, w: float) -> void:
		var pts := PackedVector2Array()
		for i in 97:
			var a := TAU * i / 96.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_polyline(pts, col, w, true)


## Uma habilidade: círculo com moldura e ícone (o botão em si é invisível).
class SkillNode extends Button:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	var id := ""
	var radius := 22.0
	var glyph := "tongue"
	var color := Color.WHITE
	var root := false
	var tree

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		text = ""
		for k in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(k, StyleBoxEmpty.new())
		custom_minimum_size = Vector2.ONE * (radius * 2.0 + 16.0)
		size = custom_minimum_size
		pivot_offset = size * 0.5
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _has_point(p: Vector2) -> bool:
		return p.distance_to(size * 0.5) <= radius + 5.0

	func _draw() -> void:
		var c := size * 0.5
		var state := GameState.upgrade_state(id)
		var cost := GameState.cost_of(id)
		var can := state == 1 and GameState.points_available() >= cost
		var t: float = tree._time if tree else 0.0
		var hot := is_hovered() or has_focus()
		var bronze := Color(0.6, 0.46, 0.32)
		var disc := Color(0.1, 0.065, 0.05)
		var ring := bronze
		var ring_w := 2.5
		var glyph_col := Color(color, 0.6)
		var halo := 0.0
		var halo_col := color
		match state:
			2:
				disc = color.darkened(0.5)
				ring = UT.GOLD
				ring_w = 3.5
				glyph_col = Color(1.0, 0.97, 0.88)
				halo = 0.55
				halo_col = UT.GOLD
			1:
				if can:
					# Dá para aprender agora: anel claro pulsando (o dourado é só
					# para as aprendidas).
					var pulse := 0.5 + 0.5 * sin(t * 4.0)
					ring = Color(1.0, 0.95, 0.85)
					ring_w = 2.5 + pulse
					glyph_col = color.lightened(0.2)
					halo = 0.25 + 0.35 * pulse
					halo_col = Color(1.0, 0.92, 0.8)
				else:
					glyph_col = Color(color, 0.75)
			3, 4:
				ring = Color(0.32, 0.27, 0.23)
				glyph_col = Color(0.5, 0.45, 0.4, 0.35)
			_:
				disc = Color(0.07, 0.05, 0.045)
				ring = Color(0.34, 0.27, 0.22)
				glyph_col = Color(0.5, 0.44, 0.38, 0.75)
		if halo > 0.0:
			draw_circle(c, radius + 11.0, Color(halo_col, halo * 0.12))
			draw_circle(c, radius + 6.0, Color(halo_col, halo * 0.25))
		draw_circle(c, radius + 2.5, Color(0.02, 0.012, 0.01))
		draw_circle(c, radius, disc)
		Glyphs.paint(self, glyph, c, radius * 0.6, glyph_col)
		draw_arc(c, radius, 0, TAU, 48, ring, ring_w, true)
		if root:
			# Habilidade que abre o ramo: moldura dupla com pinos, como as grandes do PoE.
			draw_arc(c, radius + 5.5, 0, TAU, 56, Color(ring, 0.75), 1.5, true)
			for k in 4:
				var a := TAU * k / 4.0 + PI * 0.25
				draw_circle(c + Vector2(cos(a), sin(a)) * (radius + 5.5), 3.0, ring)
		if hot:
			draw_arc(c, radius + (10.0 if root else 6.5), 0, TAU, 56, Color(1.0, 0.96, 0.8, 0.95), 2.0, true)
		if state == 3:
			_padlock(c)
		elif state == 4:
			# Travada até comer mais insetos: cadeado e "8 mil" embaixo.
			_padlock(c)
			_label_below(c, "%d mil" % (GameState.gate_of(id) / 1000), Color(0.72, 0.64, 0.55, 0.85))
		elif state != 2:
			# Preço embaixo.
			var font: Font = UT.display_bold_font()
			var txt := str(cost)
			var tsz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
			var y := c.y + radius + (19.0 if root else 15.0)
			var rect := Rect2(Vector2(c.x - tsz.x * 0.5 - 6, y - 12), Vector2(tsz.x + 12, 17))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.05, 0.03, 0.025, 0.9)
			sb.set_corner_radius_all(8)
			draw_style_box(sb, rect)
			var tc := color.lightened(0.3) if can else Color(0.75, 0.66, 0.56, 0.9 if state == 1 else 0.6)
			draw_string(font, Vector2(c.x - tsz.x * 0.5, y + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tc)

	func _label_below(c: Vector2, txt: String, tc: Color) -> void:
		var font: Font = UT.display_bold_font()
		var tsz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var y := c.y + radius + (19.0 if root else 15.0)
		var rect := Rect2(Vector2(c.x - tsz.x * 0.5 - 6, y - 12), Vector2(tsz.x + 12, 17))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.03, 0.025, 0.9)
		sb.border_color = Color(0.45, 0.38, 0.3, 0.6)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		draw_style_box(sb, rect)
		draw_string(font, Vector2(c.x - tsz.x * 0.5, y + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tc)

	func _padlock(c: Vector2) -> void:
		var metal := Color(0.95, 0.85, 0.65)
		var p := c + Vector2(0, 3)
		draw_arc(p + Vector2(0, -6), 6.5, PI, TAU, 14, metal, 3.0, true)
		draw_line(p + Vector2(-6.5, -6), p + Vector2(-6.5, -2), metal, 3.0, true)
		draw_line(p + Vector2(6.5, -6), p + Vector2(6.5, -2), metal, 3.0, true)
		var body := StyleBoxFlat.new()
		body.bg_color = metal
		body.set_corner_radius_all(3)
		draw_style_box(body, Rect2(p + Vector2(-10, -2), Vector2(20, 15)))
		draw_circle(p + Vector2(0, 4), 2.5, Color(0.3, 0.2, 0.15))
