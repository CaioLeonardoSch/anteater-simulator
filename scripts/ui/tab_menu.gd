extends Control
## Tela do TAB: duas abas, o mapa (abre primeiro) e a árvore de habilidades.
## Q e E (ou os botões de ombro do controle) trocam de aba.

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const MapView := preload("res://scripts/ui/map_view.gd")
const SkillTree := preload("res://scripts/ui/skill_tree.gd")

const MAP := 0
const SKILLS := 1

var map_view: MapView
var tree: SkillTree
var page := MAP
var _tabs: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	map_view = MapView.new()
	add_child(map_view)
	map_view.closed.connect(func(): closed.emit())
	tree = SkillTree.new()
	add_child(tree)
	tree.closed.connect(func(): closed.emit())
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 14)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.offset_left = -330
	bar.offset_right = 330
	bar.offset_top = 18
	bar.offset_bottom = 70
	add_child(bar)
	bar.add_child(_key_chip("Q"))
	for i in 2:
		var b := Button.new()
		b.text = ["Mapa", "Habilidades"][i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(196, 48)
		b.pressed.connect(show_page.bind(i))
		bar.add_child(b)
		_tabs.append(b)
	bar.add_child(_key_chip("E"))


func setup(player, world, colony, exploration) -> void:
	map_view.setup(player, world, colony, exploration)


func _key_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.02, 0.018, 0.9)
	box.border_color = Color(UiTheme.GOLD, 0.6)
	box.set_border_width_all(1)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", box)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UiTheme.display_label(text, 15, Color(UiTheme.GOLD, 0.85))
	l.add_theme_font_override("font", UiTheme.display_bold_font())
	chip.add_child(l)
	return chip


func open(which: int = MAP) -> void:
	visible = true
	show_page(which)


func show_page(which: int) -> void:
	if visible and which != page:
		Sfx.play("ui_hover", -10.0)
	page = which
	tree.visible = false
	map_view.visible = false
	if which == MAP:
		map_view.open()
	else:
		tree.open()
	for k in _tabs.size():
		_tabs[k].set_pressed_no_signal(k == which)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var to := -1
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			to = MAP
		elif event.keycode == KEY_E:
			to = SKILLS
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			to = MAP
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			to = SKILLS
	if to >= 0:
		show_page(to)
		get_viewport().set_input_as_handled()
