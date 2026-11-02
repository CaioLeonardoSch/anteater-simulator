extends Control
## Árvore de habilidades: 3 ramos (Língua, Garras, Corpo) com 4 níveis cada.
## A cada 100 formigas comidas você ganha 1 ponto (9 pontos na fase, para 12
## habilidades: escolha bem!). Cada ramo é aprendido em ordem.

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

var _points_label: Label
var _nodes: Dictionary = {}
var _connectors: Dictionary = {}
var _first_focus: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.03, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)
	var title := UiTheme.label("Árvore de Habilidades", 42, UiTheme.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	_points_label = UiTheme.label("", 22, UiTheme.CREAM)
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_points_label)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(cols)
	for b in GameState.BRANCHES.size():
		var branch: Dictionary = GameState.BRANCHES[b]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.alignment = BoxContainer.ALIGNMENT_BEGIN
		cols.add_child(col)
		var head := UiTheme.label(branch.name, 30, branch.color, true)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(head)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		col.add_child(spacer)
		var tier := 0
		for u in GameState.UPGRADES:
			if u.branch != b:
				continue
			if tier > 0:
				var link := ColorRect.new()
				link.custom_minimum_size = Vector2(6, 22)
				link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				col.add_child(link)
				_connectors[u.id] = link
			var node := _make_node(u, branch.color)
			col.add_child(node)
			_nodes[u.id] = node
			if _first_focus == null:
				_first_focus = node
			tier += 1
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 20)
	root.add_child(footer)
	var info := UiTheme.label("A cada 100 formigas: +1 ponto.  9 pontos, 12 habilidades: escolha seu estilo!", 18, UiTheme.SAND)
	footer.add_child(info)
	var back := UiTheme.button("Voltar ao jogo  [TAB]", 280)
	back.pressed.connect(func(): closed.emit())
	footer.add_child(back)
	GameState.upgrade_purchased.connect(func(_id): refresh())
	GameState.skill_point_gained.connect(func(_n): refresh())
	refresh()


func _make_node(u: Dictionary, color: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(330, 112)
	b.focus_mode = Control.FOCUS_ALL
	b.text = ""
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 10
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var tier_lbl := UiTheme.label(["I", "II", "III", "IV"][u.tier], 18, color, true)
	tier_lbl.custom_minimum_size = Vector2(34, 0)
	tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tier_lbl)
	var name_lbl := UiTheme.label(u.name, 24, UiTheme.CREAM, true)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_lbl)
	var state_lbl := UiTheme.label("", 16, UiTheme.SAND)
	state_lbl.name = "State"
	state_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(state_lbl)
	var desc := UiTheme.label(u.desc, 16, Color(0.95, 0.88, 0.78))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(290, 0)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(desc)
	b.set_meta("id", u.id)
	b.set_meta("color", color)
	b.set_meta("state_label", state_lbl)
	b.pressed.connect(_on_node_pressed.bind(u.id))
	return b


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


func refresh() -> void:
	var pts := GameState.points_available()
	if pts == 1:
		_points_label.text = "Você tem 1 ponto para gastar"
	elif pts > 1:
		_points_label.text = "Você tem %d pontos para gastar" % pts
	else:
		var to_next := GameState.ANTS_PER_POINT - GameState.ants_eaten % GameState.ANTS_PER_POINT
		_points_label.text = "Sem pontos agora. Faltam %d formigas para o próximo." % to_next
	for id in _nodes:
		var node: Button = _nodes[id]
		var color: Color = node.get_meta("color")
		var state := GameState.upgrade_state(id)
		var state_lbl: Label = node.get_meta("state_label")
		var bg := UiTheme._box(Color(0.2, 0.12, 0.1, 0.92), Color(0.5, 0.4, 0.33, 0.6), 2, 18)
		match state:
			2:
				bg = UiTheme._box(Color(color.r * 0.45, color.g * 0.32, color.b * 0.25, 0.95), UiTheme.GOLD, 3, 18)
				state_lbl.text = "Aprendida"
				state_lbl.add_theme_color_override("font_color", UiTheme.GOLD)
				node.modulate = Color.WHITE
			1:
				var can := pts > 0
				bg = UiTheme._box(Color(0.3, 0.17, 0.12, 0.95), color if can else Color(0.6, 0.5, 0.4), 3 if can else 2, 18)
				state_lbl.text = "Clique!" if can else "Disponível"
				state_lbl.add_theme_color_override("font_color", color if can else UiTheme.SAND)
				node.modulate = Color.WHITE
			_:
				state_lbl.text = "Bloqueada"
				state_lbl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
				node.modulate = Color(1, 1, 1, 0.55)
		for k in ["normal", "hover", "pressed", "focus"]:
			var box := bg.duplicate() as StyleBoxFlat
			if k == "hover" and state == 1:
				box.bg_color = box.bg_color.lightened(0.12)
			if k == "focus":
				box.draw_center = false
				box.border_color = Color(1, 0.95, 0.7)
			node.add_theme_stylebox_override(k, box)
		if _connectors.has(id):
			var link: ColorRect = _connectors[id]
			link.color = UiTheme.GOLD if state == 2 else (color if state == 1 else Color(0.4, 0.33, 0.28))


func open() -> void:
	refresh()
	visible = true
	if _first_focus:
		_first_focus.grab_focus.call_deferred()
