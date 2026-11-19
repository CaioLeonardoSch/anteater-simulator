extends Control
## Aba Coleção (no Tab, depois do mapa e das habilidades): um card para cada
## formiga colecionável da área (scripts/collectibles.gd). Antes de achar, o
## card mostra só a silhueta dela; achada, a foto (ant_photo.gd: tirada uma vez,
## num estúdio só dela) e o nome. A coleção vale para todos os jogos salvos.

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Collectibles := preload("res://scripts/collectibles.gd")
const AntPhoto := preload("res://scripts/ui/ant_photo.gd")

const AREA := 1
const COLUMNS := 3
const GAP := 24.0
## Espaço da barra das abas (em cima) e do botão de voltar (embaixo).
const TOP := 112.0
const BOTTOM := 116.0

var _header: Label
var _cards: Array[Card] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_header = UiTheme.caps_label("", 15, UiTheme.GOLD)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_header.offset_left = -300
	_header.offset_right = 300
	_header.offset_top = 84
	_header.offset_bottom = 106
	add_child(_header)
	for c in Collectibles.of_area(AREA):
		var studio := AntPhoto.make(String(c.id))
		add_child(studio)
		var card := Card.new()
		card.id = String(c.id)
		card.title = String(c.name)
		card.photo = studio.get_texture()
		add_child(card)
		_cards.append(card)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -86
	footer.offset_bottom = -26
	add_child(footer)
	var back := UiTheme.button("Voltar ao jogo  [%s]" % Settings.key_label("skill_tree").to_upper(), 300)
	back.pressed.connect(func(): closed.emit())
	footer.add_child(back)
	GameState.collectible_found.connect(func(_id): refresh())
	resized.connect(_layout)
	_layout()
	refresh()


func open() -> void:
	refresh()
	visible = true


func refresh() -> void:
	var found := 0
	for card in _cards:
		card.found = GameState.has_collectible(card.id)
		if card.found:
			found += 1
		card.queue_redraw()
	_header.text = "Área %d · %d de %d" % [AREA, found, _cards.size()]


## Cards em 3 colunas, do tamanho que couber entre as abas e o botão.
func _layout() -> void:
	var rows := ceili(float(_cards.size()) / COLUMNS)
	var h := clampf((size.y - TOP - BOTTOM - GAP * (rows - 1)) / rows, 170.0, 330.0)
	var w := h * 0.84
	var total := Vector2(COLUMNS * w + (COLUMNS - 1) * GAP, rows * h + (rows - 1) * GAP)
	var origin := Vector2((size.x - total.x) * 0.5, TOP + maxf((size.y - TOP - BOTTOM - total.y) * 0.5, 0.0))
	for k in _cards.size():
		var card := _cards[k]
		card.position = origin + Vector2((k % COLUMNS) * (w + GAP), (k / COLUMNS) * (h + GAP))
		card.size = Vector2(w, h)
	queue_redraw()


## Fundo como o da árvore: escuro nas bordas, com um brilho quente no meio.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.024, 0.024))
	var c := size * 0.5
	for k in 8:
		var t := float(k) / 7.0
		var r := Vector2(1.5, 1.0) * lerpf(620.0, 110.0, t)
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, Color(0.55, 0.3, 0.16, 0.022 + t * 0.012))


## Um card: a foto da formiga (ou a silhueta dela, antes de achar), o nome
## embaixo e a moldura dourada dos painéis do jogo.
class Card extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	var id := ""
	var title := ""
	var photo: Texture2D
	var found := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var gold := UT.GOLD
		draw_rect(r, Color(0.07, 0.048, 0.04, 0.96))
		# Luz de palco atrás da formiga.
		var pad := 12.0
		var side := size.x - pad * 2.0
		var photo_rect := Rect2(Vector2(pad, pad), Vector2(side, side))
		var c := photo_rect.get_center()
		for k in 7:
			var t := float(k) / 6.0
			draw_circle(c, lerpf(side * 0.5, side * 0.12, t), Color(0.78, 0.52, 0.3, (0.05 if found else 0.018)))
		if photo != null:
			if found:
				draw_texture_rect(photo, photo_rect, false)
			else:
				# Só a silhueta: a mesma foto, toda escura.
				draw_texture_rect(photo, photo_rect, false, Color(0.0, 0.0, 0.0, 0.85))
		draw_rect(r.grow(-0.75), Color(gold, 0.85 if found else 0.35), false, 1.5)
		draw_rect(r.grow(-4.5), Color(gold, 0.25 if found else 0.1), false, 1.0)
		if found:
			var font: Font = UT.display_font()
			var fs := 19
			while fs > 13 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 24.0:
				fs -= 1
			var y := photo_rect.end.y + (size.y - photo_rect.end.y) * 0.5 + fs * 0.35
			draw_string(font, Vector2(12.0, y), title, HORIZONTAL_ALIGNMENT_CENTER, size.x - 24.0, fs, UT.PALE)
