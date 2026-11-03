extends RefCounted
## Tema visual da interface, no estilo "Constelação" (o mesmo da árvore de
## habilidades): painéis quase pretos com moldura dourada dupla, texto marfim,
## números e títulos em Alegreya SC e textos em Alegreya Sans.

const FrameBox := preload("res://scripts/ui/frame_box.gd")

## Arquivos das fontes (use as funções text_font(), semi_font(), bold_font()...).
const _TEXT_FILE := preload("res://assets/fonts/AlegreyaSans-Medium.ttf")
const _SEMI_FILE := preload("res://assets/fonts/AlegreyaSans-Bold.ttf")
const _BOLD_FILE := preload("res://assets/fonts/AlegreyaSans-ExtraBold.ttf")
const _DISPLAY_FILE := preload("res://assets/fonts/AlegreyaSC-ExtraBold.ttf")
const _DISPLAY_BOLD_FILE := preload("res://assets/fonts/AlegreyaSC-Bold.ttf")

## Cores.
const CREAM := Color("efe6d2")
const PALE := Color("f6e3b4")
const SAND := Color("cfc3aa")
const MUTED := Color("a89c86")
const GOLD := Color("e8b44f")
const BRONZE := Color("9c7a47")
const TERRACOTTA := Color("e0906a")
const DARK := Color(0.04, 0.028, 0.024, 0.9)
const DARK_SOLID := Color("0b0807")
const LEAF := Color("b9d99a")
const PINK := Color("ffa6b5")
## Mira verde (a lambida vai pegar formiga).
const AIM := Color("b9e39a")

static var _theme: Theme
static var _text: FontVariation
static var _semi: FontVariation
static var _bold: FontVariation
static var _display: FontVariation
static var _display_bold: FontVariation
static var _caps: FontVariation


## Textos (Alegreya Sans): números alinhados e um pouco mais de espaço entre as
## palavras (o espaço original da fonte é estreito demais sobre o cenário).
static func text_font() -> Font:
	if _text == null:
		_text = _variation(_TEXT_FILE, 2, false)
	return _text


static func semi_font() -> Font:
	if _semi == null:
		_semi = _variation(_SEMI_FILE, 2, false)
	return _semi


static func bold_font() -> Font:
	if _bold == null:
		_bold = _variation(_BOLD_FILE, 2, false)
	return _bold


## Números e títulos: Alegreya SC, com algarismos alinhados e de largura igual
## (o contador e o relógio não tremem quando mudam).
static func display_font() -> Font:
	if _display == null:
		_display = _variation(_DISPLAY_FILE, 3, true)
	return _display


## Alegreya SC um pouco mais leve (botões e títulos menores).
static func display_bold_font() -> Font:
	if _display_bold == null:
		_display_bold = _variation(_DISPLAY_BOLD_FILE, 3, true)
	return _display_bold


## Rótulos pequenos em caixa alta (PONTOS, PRÓXIMA ONDA...): letras espaçadas.
static func caps_font() -> Font:
	if _caps == null:
		_caps = _variation(_BOLD_FILE, 3, false)
		_caps.spacing_glyph = 2
	return _caps


static func _variation(base: Font, space: int, tabular: bool) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_space = space
	var ts := TextServerManager.get_primary_interface()
	var features := {ts.name_to_tag("lnum"): 1}
	if tabular:
		features[ts.name_to_tag("tnum")] = 1
	fv.opentype_features = features
	return fv


## Moldura dourada dupla (painéis, botões, quadros).
static func frame(top: Color, bottom: Color, border: Color, inner: Color, margin_x: int = 18, margin_y: int = 10) -> FrameBox:
	var f := FrameBox.new()
	f.bg_top = top
	f.bg_bottom = bottom
	f.border = border
	f.inner = inner
	f.content_margin_left = margin_x
	f.content_margin_right = margin_x
	f.content_margin_top = margin_y
	f.content_margin_bottom = margin_y
	return f


## Painel padrão do HUD: quase preto, borda dourada e linha de dentro.
static func panel_frame(margin_x: int = 16, margin_y: int = 11) -> FrameBox:
	return frame(Color(0.063, 0.043, 0.035, 0.9), Color(0.031, 0.024, 0.02, 0.9), Color(GOLD, 0.8), Color(GOLD, 0.25),
		margin_x, margin_y)


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = text_font()
	t.default_font_size = 22
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_constant("shadow_outline_size", "Label", 4)
	# Botões: moldura dourada; com o mouse em cima, a borda acende e brilha.
	var normal := frame(Color(0.07, 0.048, 0.038, 0.92), Color(0.035, 0.026, 0.021, 0.92), Color(GOLD, 0.6), Color(GOLD, 0.18))
	var hover := frame(Color(0.15, 0.1, 0.065, 0.95), Color(0.08, 0.055, 0.038, 0.95), GOLD, Color(GOLD, 0.38))
	hover.glow = 1.0
	var pressed := frame(Color(0.27, 0.18, 0.09, 0.97), Color(0.16, 0.1, 0.055, 0.97), PALE, Color(PALE, 0.45))
	var disabled := frame(Color(0.05, 0.04, 0.035, 0.6), Color(0.03, 0.025, 0.02, 0.6), Color(0.45, 0.38, 0.3, 0.4), Color(0, 0, 0, 0))
	var focus := frame(Color(0, 0, 0, 0), Color(0, 0, 0, 0), PALE, Color(0, 0, 0, 0))
	focus.glow = 0.8
	var styles := {"normal": normal, "hover": hover, "pressed": pressed, "hover_pressed": pressed,
		"disabled": disabled, "focus": focus}
	for k in styles:
		t.set_stylebox(k, "Button", styles[k])
		t.set_stylebox(k, "OptionButton", styles[k])
	t.set_color("font_color", "Button", PALE)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.97, 0.88))
	t.set_color("font_pressed_color", "Button", Color(1.0, 0.95, 0.8))
	t.set_color("font_hover_pressed_color", "Button", Color(1.0, 0.95, 0.8))
	t.set_color("font_focus_color", "Button", PALE)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.55, 0.48, 0.6))
	t.set_font("font", "Button", display_bold_font())
	t.set_font_size("font_size", "Button", 25)
	t.set_color("font_color", "OptionButton", CREAM)
	t.set_color("font_hover_color", "OptionButton", Color(1.0, 0.97, 0.88))
	t.set_color("font_pressed_color", "OptionButton", PALE)
	t.set_color("font_focus_color", "OptionButton", CREAM)
	t.set_font("font", "OptionButton", semi_font())
	t.set_font_size("font_size", "OptionButton", 21)
	# Lista que abre nas opções.
	var popup := frame(Color(0.06, 0.042, 0.034, 0.98), Color(0.035, 0.026, 0.021, 0.98), Color(GOLD, 0.8), Color(GOLD, 0.2), 8, 8)
	t.set_stylebox("panel", "PopupMenu", popup)
	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color = Color(GOLD, 0.22)
	popup_hover.border_color = Color(GOLD, 0.6)
	popup_hover.set_border_width_all(1)
	t.set_stylebox("hover", "PopupMenu", popup_hover)
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", PALE)
	t.set_font("font", "PopupMenu", semi_font())
	t.set_font_size("font_size", "PopupMenu", 20)
	t.set_constant("v_separation", "PopupMenu", 8)
	# Painéis dos menus: moldura com losangos nos cantos.
	var panel := frame(Color(0.05, 0.035, 0.03, 0.95), Color(0.025, 0.018, 0.015, 0.95), Color(GOLD, 0.8), Color(GOLD, 0.25), 22, 16)
	panel.corners = true
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	# Barras de volume e sensibilidade: trilho escuro, parte cheia dourada, pino em losango.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.055, 0.045, 0.95)
	track.border_color = Color(GOLD, 0.45)
	track.set_border_width_all(1)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(GOLD, 0.85)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _diamond_icon(GOLD))
	t.set_icon("grabber_highlight", "HSlider", _diamond_icon(PALE))
	# Caixas de seleção.
	t.set_color("font_color", "CheckBox", CREAM)
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(k, "CheckBox", StyleBoxEmpty.new())
	var check_focus := StyleBoxFlat.new()
	check_focus.draw_center = false
	check_focus.border_color = PALE
	check_focus.set_border_width_all(1)
	t.set_stylebox("focus", "CheckBox", check_focus)
	t.set_icon("checked", "CheckBox", _check_icon(true))
	t.set_icon("unchecked", "CheckBox", _check_icon(false))
	# Barra de progresso.
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.06, 0.04, 0.035, 0.85)
	bar_bg.border_color = Color(GOLD, 0.4)
	bar_bg.set_border_width_all(1)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GOLD
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "ProgressBar", CREAM)
	# Textos longos (Como jogar).
	t.set_font("normal_font", "RichTextLabel", text_font())
	t.set_font("bold_font", "RichTextLabel", bold_font())
	t.set_color("default_color", "RichTextLabel", CREAM)
	_theme = t
	return t


## Caixa de seleção: quadrado escuro com borda dourada; marcada, um losango dourado.
static func _check_icon(on: bool) -> Texture2D:
	var size := 30
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var edge := mini(mini(x, y), mini(size - 1 - x, size - 1 - y))
			if edge < 2:
				img.set_pixel(x, y, Color(GOLD, 0.85))
			elif edge < 3:
				img.set_pixel(x, y, Color(0.03, 0.02, 0.018))
			else:
				img.set_pixel(x, y, Color(0.07, 0.048, 0.038))
			if on and absf(x - c) + absf(y - c) <= 8.0:
				img.set_pixel(x, y, GOLD if absf(x - c) + absf(y - c) <= 6.5 else Color(PALE, 0.9))
	return ImageTexture.create_from_image(img)


## Pino das barras: losango dourado com contorno escuro.
static func _diamond_icon(col: Color) -> Texture2D:
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := absf(x - c) + absf(y - c)
			if d <= 8.5:
				img.set_pixel(x, y, col)
			elif d <= 10.5:
				img.set_pixel(x, y, Color(0.03, 0.02, 0.018, 0.95))
	return ImageTexture.create_from_image(img)


## Caixa simples (cantos levemente arredondados), para detalhes que não pedem moldura dupla.
static func _box(bg: Color, border: Color, border_w: int = 1, radius: int = 3) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 14
	b.content_margin_right = 14
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	b.anti_aliasing = true
	return b


static func label(text: String, size: int = 22, color: Color = CREAM, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", bold_font())
	return l


## Título ou número em Alegreya SC.
static func display_label(text: String, size: int = 30, color: Color = PALE) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", display_font())
	return l


## Rótulo pequeno em caixa alta e espaçado.
static func caps_label(text: String, size: int = 12, color: Color = MUTED) -> Label:
	var l := label(text.to_upper(), size, color)
	l.add_theme_font_override("font", caps_font())
	return l


static func button(text: String, min_width: float = 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 56)
	b.mouse_entered.connect(func(): Sfx.play("ui_hover", -14.0, 1.0, 0.05))
	b.pressed.connect(func(): Sfx.play("ui_click", -8.0))
	return b
