extends RefCounted
## Tema visual da interface: cantos arredondados, tons quentes de fim de tarde.

const FONT := preload("res://assets/fonts/Fredoka-Medium.ttf")
const FONT_BOLD := preload("res://assets/fonts/Fredoka-Bold.ttf")

const CREAM := Color(1.0, 0.95, 0.86)
const SAND := Color(0.98, 0.84, 0.6)
const GOLD := Color(1.0, 0.76, 0.3)
const TERRACOTTA := Color(0.86, 0.42, 0.28)
const DARK := Color(0.13, 0.08, 0.07, 0.88)
const DARK_SOLID := Color(0.16, 0.1, 0.08)
const LEAF := Color(0.55, 0.8, 0.4)
const PINK := Color(1.0, 0.55, 0.62)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 22
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_constant("shadow_outline_size", "Label", 4)
	# Botões.
	var normal := _box(Color(0.22, 0.13, 0.1, 0.92), Color(0.95, 0.68, 0.35, 0.7), 2)
	var hover := _box(Color(0.42, 0.22, 0.14, 0.96), GOLD, 3)
	var pressed := _box(Color(0.62, 0.3, 0.18, 1.0), GOLD, 3)
	var disabled := _box(Color(0.18, 0.13, 0.12, 0.6), Color(0.5, 0.42, 0.35, 0.5), 2)
	var focus := _box(Color(0, 0, 0, 0), Color(1.0, 0.9, 0.6), 3)
	focus.draw_center = false
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBox = {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled, "focus": focus}[k]
		t.set_stylebox(k, "Button", box)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.7, 0.62, 0.55, 0.6))
	t.set_font("font", "Button", FONT_BOLD)
	t.set_font_size("font_size", "Button", 24)
	# Painéis.
	t.set_stylebox("panel", "PanelContainer", _box(DARK, Color(0.95, 0.68, 0.35, 0.55), 2, 22))
	t.set_stylebox("panel", "Panel", _box(DARK, Color(0.95, 0.68, 0.35, 0.55), 2, 22))
	# Sliders / checkboxes.
	var track := _box(Color(0.3, 0.2, 0.16, 0.9), Color(0, 0, 0, 0), 0, 6)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var fill := _box(TERRACOTTA, Color(0, 0, 0, 0), 0, 6)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_color("font_color", "CheckBox", CREAM)
	t.set_color("font_color", "OptionButton", CREAM)
	t.set_stylebox("normal", "OptionButton", normal)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	t.set_stylebox("focus", "OptionButton", focus)
	var bar_bg := _box(Color(0.1, 0.06, 0.05, 0.75), Color(1, 0.85, 0.6, 0.35), 2, 10)
	var bar_fill := _box(GOLD, Color(0, 0, 0, 0), 0, 10)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "ProgressBar", CREAM)
	_theme = t
	return t


static func _box(bg: Color, border: Color, border_w: int = 2, radius: int = 16) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	b.shadow_color = Color(0, 0, 0, 0.3)
	b.shadow_size = 6
	b.shadow_offset = Vector2(0, 3)
	b.anti_aliasing = true
	return b


static func label(text: String, size: int = 22, color: Color = CREAM, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", FONT_BOLD)
	return l


static func button(text: String, min_width: float = 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 56)
	b.mouse_entered.connect(func(): Sfx.play("ui_hover", -14.0, 1.0, 0.05))
	b.pressed.connect(func(): Sfx.play("ui_click", -8.0))
	return b
