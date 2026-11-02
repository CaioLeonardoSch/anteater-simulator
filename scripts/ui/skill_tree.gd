extends Control
## Árvore de habilidades: Língua, Garras, Patas, Faro e Escalada + Cauda.
## Cada formiga comida vale 1 ponto e cada habilidade tem o seu preço.
## Cada ramo começa com uma habilidade e se divide em duas linhas, que não se
## excluem. O que ainda não existe no jogo (Escalada + Cauda) aparece com cadeado.
## Dá para redistribuir os pontos de graça a qualquer momento.

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

const NODE_SIZE := Vector2(150, 74)
const COL_GAP := 10.0
const BRANCH_GAP := 22.0
const ROW_GAP := 20.0
## Espaço extra entre o topo do ramo e as duas linhas (para o nome das linhas).
const SPLIT_GAP := 24.0
const HEADER_H := 36.0
## Folga nas laterais (o nome do último ramo é mais largo que a coluna).
const MARGIN_X := 14.0

var _points_label: Label
var _points_hint: Label
var _nodes: Dictionary = {}
var _canvas: TreeCanvas
var _detail_title: Label
var _detail_where: Label
var _detail_desc: Label
var _detail_state: Label
var _first_focus: Control
var _respec: Button
var _shown_id := ""
var _focus_id := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.03, 0.03, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(top)
	var title := UiTheme.label("Árvore de Habilidades", 36, UiTheme.GOLD, true)
	top.add_child(title)
	_points_label = UiTheme.label("", 26, UiTheme.CREAM, true)
	_points_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_points_label)
	_points_hint = UiTheme.label("1 formiga comida = 1 ponto", 17, UiTheme.SAND)
	_points_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_points_hint)
	_canvas = TreeCanvas.new()
	_canvas.tree = self
	_canvas.node_size = NODE_SIZE
	_canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(_canvas)
	_build_nodes()
	root.add_child(_build_detail())
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 18)
	root.add_child(footer)
	_respec = UiTheme.button("Redistribuir pontos", 280)
	_respec.pressed.connect(_on_respec)
	footer.add_child(_respec)
	var back := UiTheme.button("Voltar ao jogo  [TAB]", 300)
	back.pressed.connect(func(): closed.emit())
	footer.add_child(back)
	GameState.upgrade_purchased.connect(func(_id): refresh())
	GameState.upgrade_affordable.connect(func(_id): refresh())
	GameState.ants_eaten_changed.connect(_on_eaten_changed)
	GameState.skills_reset.connect(refresh)
	refresh()


# ------------------------------------------------------------------ Montagem

## Largura de cada ramo (1 ou 2 colunas) e onde ele começa.
func _branch_layout() -> Array:
	var out := []
	var x := MARGIN_X
	for b in GameState.BRANCHES.size():
		var cols: int = 2 if GameState.BRANCHES[b].lines.size() == 2 else 1
		var w := cols * NODE_SIZE.x + (cols - 1) * COL_GAP
		out.append({"x": x, "w": w, "cols": cols})
		x += w + BRANCH_GAP
	return out


func row_y(row: int) -> float:
	return HEADER_H + row * (NODE_SIZE.y + ROW_GAP) + (SPLIT_GAP if row >= 1 else 0.0)


func column_x(branch: int, col: int) -> float:
	var lay: Dictionary = _branch_layout()[branch]
	if col < 0:
		return lay.x + (lay.w - NODE_SIZE.x) * 0.5
	return lay.x + col * (NODE_SIZE.x + COL_GAP)


func _build_nodes() -> void:
	var layout := _branch_layout()
	var last: Dictionary = layout[layout.size() - 1]
	var max_row := 0
	for u in GameState.UPGRADES:
		max_row = maxi(max_row, int(u.row))
	_canvas.custom_minimum_size = Vector2(last.x + last.w + MARGIN_X, row_y(max_row) + NODE_SIZE.y)
	for u in GameState.UPGRADES:
		var color: Color = GameState.BRANCHES[u.branch].color
		var node := _make_node(u, color)
		node.position = Vector2(column_x(u.branch, u.col), row_y(u.row))
		node.size = NODE_SIZE
		_canvas.add_child(node)
		_nodes[u.id] = node
		if _first_focus == null:
			_first_focus = node


func _make_node(u: Dictionary, color: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = NODE_SIZE
	b.focus_mode = Control.FOCUS_ALL
	b.text = ""
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -10
	v.offset_top = 6
	v.offset_bottom = -6
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	b.add_child(v)
	var name_lbl := UiTheme.label(u.name, 15, UiTheme.CREAM, true)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.max_lines_visible = 2
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_lbl)
	var state_lbl := UiTheme.label("", 15, UiTheme.SAND, true)
	state_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(state_lbl)
	b.set_meta("id", u.id)
	b.set_meta("color", color)
	b.set_meta("state_label", state_lbl)
	b.set_meta("name_label", name_lbl)
	var lock := Padlock.new()
	lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock.visible = false
	b.add_child(lock)
	b.set_meta("lock", lock)
	b.pressed.connect(_on_node_pressed.bind(u.id))
	b.focus_entered.connect(_on_node_focus.bind(u.id))
	b.mouse_entered.connect(_show_detail.bind(u.id))
	b.mouse_exited.connect(func(): _show_detail(_focus_id))
	return b


func _build_detail() -> Control:
	var box := PanelContainer.new()
	var style := UiTheme._box(Color(0.1, 0.06, 0.05, 0.75), Color(1, 0.85, 0.6, 0.3), 2, 16)
	box.add_theme_stylebox_override("panel", style)
	box.custom_minimum_size = Vector2(0, 118)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	_detail_title = UiTheme.label("", 24, UiTheme.GOLD, true)
	h.add_child(_detail_title)
	_detail_where = UiTheme.label("", 17, UiTheme.SAND)
	_detail_where.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(_detail_where)
	_detail_desc = UiTheme.label("", 19, UiTheme.CREAM)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_detail_desc)
	_detail_state = UiTheme.label("", 18, UiTheme.SAND, true)
	v.add_child(_detail_state)
	return box


# ------------------------------------------------------------------ Ações

func _on_node_focus(id: String) -> void:
	_focus_id = id
	_show_detail(id)


func _on_eaten_changed(_total: int, _delta: int) -> void:
	if visible:
		refresh()


func _on_node_pressed(id: String) -> void:
	if GameState.buy(id):
		Sfx.play("upgrade", -2.0)
		var node: Button = _nodes[id]
		node.pivot_offset = node.size * 0.5
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector2(1.08, 1.08), 0.1)
		tw.tween_property(node, "scale", Vector2.ONE, 0.18)
	else:
		Sfx.play("deny", -6.0)
	_show_detail(id)


func _on_respec() -> void:
	if GameState.points_spent == 0 and GameState.purchased.is_empty():
		Sfx.play("deny", -6.0)
		return
	GameState.respec()
	Sfx.play("ui_open", -4.0)


# ------------------------------------------------------------------ Estado

func refresh() -> void:
	var pts := GameState.points_available()
	_points_label.text = "%d %s" % [pts, "ponto" if pts == 1 else "pontos"]
	if _respec:
		_respec.disabled = GameState.purchased.is_empty()
	for id in _nodes:
		var node: Button = _nodes[id]
		var color: Color = node.get_meta("color")
		var state := GameState.upgrade_state(id)
		var cost := GameState.cost_of(id)
		var state_lbl: Label = node.get_meta("state_label")
		var bg := UiTheme._box(Color(0.2, 0.12, 0.1, 0.92), Color(0.5, 0.4, 0.33, 0.6), 2, 16)
		# O que ainda não existe no jogo aparece só com o cadeado.
		(node.get_meta("name_label") as Label).visible = state != 3
		match state:
			2:
				bg = UiTheme._box(Color(color.r * 0.45, color.g * 0.32, color.b * 0.25, 0.95), UiTheme.GOLD, 3, 16)
				state_lbl.text = "Aprendida"
				state_lbl.add_theme_color_override("font_color", UiTheme.GOLD)
				node.modulate = Color.WHITE
			1:
				var can := pts >= cost
				bg = UiTheme._box(Color(0.3, 0.17, 0.12, 0.95), color if can else Color(0.6, 0.5, 0.4), 3 if can else 2, 16)
				state_lbl.text = "%d pontos" % cost
				state_lbl.add_theme_color_override("font_color", color.lightened(0.25) if can else UiTheme.SAND)
				node.modulate = Color.WHITE
			3:
				state_lbl.text = ""
				node.modulate = Color(1, 1, 1, 0.5)
			_:
				state_lbl.text = "%d pontos" % cost
				state_lbl.add_theme_color_override("font_color", Color(0.7, 0.62, 0.55))
				node.modulate = Color(1, 1, 1, 0.55)
		(node.get_meta("lock") as Control).visible = state == 3
		for k in ["normal", "hover", "pressed", "focus"]:
			var box := bg.duplicate() as StyleBoxFlat
			box.content_margin_top = 4
			box.content_margin_bottom = 4
			box.shadow_size = 4
			if k == "hover" and state == 1:
				box.bg_color = box.bg_color.lightened(0.12)
			if k == "focus":
				box.draw_center = false
				box.border_color = Color(1, 0.95, 0.7)
			node.add_theme_stylebox_override(k, box)
	_canvas.queue_redraw()
	_show_detail(_shown_id)


func _show_detail(id: String) -> void:
	_shown_id = id
	var u := GameState.get_upgrade(id)
	if u.is_empty():
		_detail_title.text = "Escolha uma habilidade"
		_detail_where.text = ""
		_detail_desc.text = "Passe o mouse (ou o controle) numa habilidade para ver o que ela faz e quanto custa. Clique para aprender."
		_detail_state.text = _summary_text()
		_detail_state.add_theme_color_override("font_color", UiTheme.SAND)
		return
	var branch: Dictionary = GameState.BRANCHES[u.branch]
	_detail_title.text = u.name
	_detail_title.add_theme_color_override("font_color", branch.color.lightened(0.2))
	var where: String = branch.name
	if u.col >= 0 and branch.lines.size() == 2:
		where += " · linha de %s" % branch.lines[u.col]
	_detail_where.text = where
	_detail_desc.text = u.desc
	var pts := GameState.points_available()
	var cost: int = u.cost
	var col := UiTheme.SAND
	var text := ""
	match GameState.upgrade_state(id):
		2:
			text = "Você já aprendeu esta habilidade."
			col = UiTheme.GOLD
		3:
			text = "Ainda não disponível."
		0:
			var names := []
			for r in GameState.missing_requirements(id):
				names.append(GameState.get_upgrade(r).name)
			text = "Custa %d pontos. Aprenda antes: %s." % [cost, ", ".join(names)]
		_:
			if pts >= cost:
				text = "Clique para aprender por %d pontos." % cost
				col = branch.color.lightened(0.3)
			else:
				text = "Custa %d pontos: faltam %d formigas." % [cost, cost - pts]
	_detail_state.text = text
	_detail_state.add_theme_color_override("font_color", col)


func _summary_text() -> String:
	var n := GameState.affordable_count()
	if n == 1:
		return "Já dá para aprender 1 habilidade."
	if n > 1:
		return "Já dá para aprender %d habilidades." % n
	var goal := GameState.next_goal()
	if goal.is_empty():
		return ""
	return "Próxima: %s (%d pontos) · faltam %d formigas." % [goal.name, goal.cost, goal.cost - GameState.points_available()]


func open() -> void:
	_focus_id = ""
	refresh()
	visible = true
	if _first_focus:
		_first_focus.grab_focus.call_deferred()


# ------------------------------------------------------------------ Desenho

## Área da árvore: nomes dos ramos, das linhas e as ligações entre habilidades.
class TreeCanvas extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	var tree
	var node_size := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if tree == null:
			return
		var font: Font = UT.FONT_BOLD
		var layout: Array = tree._branch_layout()
		var ns := node_size
		# Ligações (pré-requisito -> habilidade).
		for u in GameState.UPGRADES:
			var to: Vector2 = Vector2(tree.column_x(u.branch, u.col) + ns.x * 0.5, tree.row_y(u.row))
			var state := GameState.upgrade_state(u.id)
			var branch_col: Color = GameState.BRANCHES[u.branch].color
			var col := Color(0.42, 0.34, 0.29)
			if state == 2:
				col = UT.GOLD
			elif state == 1:
				col = branch_col
			for r in u.requires:
				var p := GameState.get_upgrade(String(r))
				var from := Vector2(tree.column_x(p.branch, p.col) + ns.x * 0.5, tree.row_y(p.row) + ns.y)
				if is_equal_approx(from.x, to.x):
					draw_line(from, to, col, 5.0, true)
				else:
					var mid := from.y + (to.y - from.y) * 0.35
					draw_polyline(PackedVector2Array([from, Vector2(from.x, mid), Vector2(to.x, mid), to]), col, 5.0, true)
		# Nome dos ramos e das linhas.
		for b in GameState.BRANCHES.size():
			var branch: Dictionary = GameState.BRANCHES[b]
			var lay: Dictionary = layout[b]
			var name_size := font.get_string_size(branch.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 23)
			draw_string(font, Vector2(lay.x + (lay.w - name_size.x) * 0.5, 24), branch.name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 23, branch.color)
			if branch.lines.size() == 2:
				for c in 2:
					var text: String = branch.lines[c]
					var tsz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
					var cx: float = tree.column_x(b, c) + ns.x * 0.5
					var y: float = tree.row_y(1) - 15.0
					var pill := Rect2(Vector2(cx - tsz.x * 0.5 - 9, y - 11), Vector2(tsz.x + 18, 21))
					var sb := StyleBoxFlat.new()
					sb.bg_color = Color(0.16, 0.09, 0.07, 0.95)
					sb.border_color = Color(branch.color, 0.7)
					sb.set_border_width_all(1)
					sb.set_corner_radius_all(10)
					draw_style_box(sb, pill)
					draw_string(font, Vector2(cx - tsz.x * 0.5, y + 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
						branch.color.lightened(0.25))


## Cadeado por cima das habilidades que ainda não existem no jogo.
class Padlock extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, 4)
		var metal := Color(0.95, 0.85, 0.65)
		draw_arc(c + Vector2(0, -8), 9.0, PI, TAU, 16, metal, 4.0, true)
		draw_line(c + Vector2(-9, -8), c + Vector2(-9, -2), metal, 4.0, true)
		draw_line(c + Vector2(9, -8), c + Vector2(9, -2), metal, 4.0, true)
		var body := StyleBoxFlat.new()
		body.bg_color = metal
		body.set_corner_radius_all(4)
		draw_style_box(body, Rect2(c + Vector2(-14, -3), Vector2(28, 22)))
		draw_circle(c + Vector2(0, 6), 3.5, Color(0.3, 0.2, 0.15))
		draw_line(c + Vector2(0, 7), c + Vector2(0, 13), Color(0.3, 0.2, 0.15), 3.0)
