extends HBoxContainer
## Estatísticas: os números deste jogo, as parciais do modo contra o relógio e
## os recordes de todos os jogos. Aparece na tela de estatísticas (pela pausa)
## e na tela do fim.
## As conquistas (preparadas, mas escondidas na demo) aparecem embaixo só com
## Achievements.VISIBLE ou --conquistas.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Achievements := preload("res://scripts/achievements.gd")

const GREEN := Color("9fdc7c")
const RED := Color("ef8a6a")
## Tamanho das letras das linhas.
const FONT := 17

## Largura de cada coluna de quadros (as duas iguais, para alinhar).
const COLUMN_WIDTH := 340.0

var world
var colony


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(w, c) -> void:
	world = w
	colony = c


## Refaz os quadros com os números de agora. Duas colunas da mesma largura:
## "Este jogo" e "Ações".
## O último quadro de cada coluna estica até embaixo, para as bordas baterem.
func refresh() -> void:
	for c in get_children():
		c.queue_free()
	if world == null:
		return
	var left := _column()
	left.add_child(_panel("Este jogo", _run_rows()))
	var right := _column()
	right.add_child(_panel("Ações", _action_rows()))
	for col in [left, right]:
		col.get_child(col.get_child_count() - 1).size_flags_vertical = Control.SIZE_EXPAND_FILL
	if Achievements.VISIBLE or DevTools.args.has("conquistas"):
		add_child(_achievements_panel())


func _column() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	add_child(v)
	return v


# ------------------------------------------------------------------ Números

func _run_rows() -> Array:
	var opened := 0
	var chambers := 0
	var queens := 0
	for n in world.nests:
		chambers += n.chambers.size()
		if n.big:
			queens += 1
		for c in n.chambers:
			if c.opened:
				opened += 1
	# Cliques comprados na árvore (cada habilidade tem de 1 a 3).
	var skills := 0
	var skills_total := 0
	for u in GameState.UPGRADES:
		if GameState.region_required(u.id).is_empty():
			skills_total += GameState.max_rank(u.id)
			skills += GameState.rank(u.id)
	return [
		["Tempo de jogo", GameState.format_time(GameState.elapsed)],
		["Insetos comidos", "%s de %s" % [_n(GameState.ants_eaten), _n(GameState.GOAL)]],
		["Ninhos limpos", "%d de %d" % [colony.nests_cleaned(), world.nests.size()]],
		["Câmaras abertas", "%d de %d" % [opened, chambers]],
		["Rainhas comidas", "%d de %d" % [GameState.queens_eaten, queens]],
		["Tanajuras comidas", _n(GameState.tanajuras_eaten)],
		["Cogumelos comidos", _n(int(GameState.stat("mushrooms")))],
		["Maior combo", "%s insetos" % _n(GameState.best_combo)],
		["Habilidades", "%d de %d cliques" % [skills, skills_total]],
		["Pontos gastos", _n(GameState.points_spent)],
	]


func _action_rows() -> Array:
	var licks := GameState.stat("licks")
	var hits := GameState.stat("licks_hit")
	var aim := "—" if licks <= 0.0 else "%d%%" % int(round(hits / licks * 100.0))
	return [
		["Linguadas", _n(int(licks))],
		["Acerto da língua", aim],
		["Faro", "%s vezes" % _n(int(GameState.stat("sniffs")))],
		["Tremores", "%s vezes" % _n(int(GameState.stat("tremors")))],
		["Distância", _distance(GameState.stat("distance"))],
		["Correndo", GameState.format_time(GameState.stat("run_time"))],
	]


# ------------------------------------------------------------------ Montagem

## Um quadro com título e linhas [rótulo, valor]. O valor pode ser um texto ou
## uma lista de textos/[texto, cor] lado a lado.
func _panel(title: String, rows: Array) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_frame(20, 14))
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UiTheme.display_label(title, 22, UiTheme.PALE))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 3)
	v.add_child(g)
	for r in rows:
		g.add_child(UiTheme.label(r[0], FONT, UiTheme.SAND))
		var cell := HBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_END
		cell.add_theme_constant_override("separation", 10)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(cell)
		var parts: Array = r[1] if r[1] is Array else [r[1]]
		for part in parts:
			var text: String = part[0] if part is Array else part
			var col: Color = part[1] if part is Array else UiTheme.CREAM
			var l := UiTheme.label(text, FONT, col, true)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cell.add_child(l)
	return p


func _achievements_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_frame(24, 18))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UiTheme.display_label("Conquistas  %d/%d" % [GameState.achievements.size(), Achievements.LIST.size()], 26, UiTheme.PALE))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 26)
	g.add_theme_constant_override("v_separation", 8)
	v.add_child(g)
	for a in Achievements.LIST:
		var got := GameState.achievements.has(a.id)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.custom_minimum_size = Vector2(300, 0)
		g.add_child(box)
		box.add_child(UiTheme.label(("◆  " if got else "◇  ") + a.name, 18, UiTheme.GOLD if got else UiTheme.SAND, true))
		var d := UiTheme.label("     " + a.desc, 15, UiTheme.CREAM if got else UiTheme.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(d)
	return p


static func _n(v: int) -> String:
	var t := str(absi(v))
	var out := ""
	while t.length() > 3:
		out = " " + t.substr(t.length() - 3) + out
		t = t.substr(0, t.length() - 3)
	return ("-" if v < 0 else "") + t + out


static func _distance(m: float) -> String:
	if m >= 1000.0:
		return "%s km" % GameState._num(m / 1000.0, 1)
	return "%d m" % int(m)
