extends Control
## Objetivos guiados (tutorial): um objetivo de cada vez num cartão no canto
## esquerdo, com o progresso, e um losango que mostra onde fazer. O losango é da
## tela, não do mapa: quando um objetivo com lugar começa, ele sai do cartão,
## voa numa leve curva até o alvo e fica pulsando em cima dele, com a
## distância; depois de um tempo some. A tecla do objetivo (F) faz ele voar de
## novo. O alvo também aparece na bússola. O que o jogador já fez antes de
## chegar a vez é pulado na hora. Embaixo, a linha da próxima novidade mostra
## quanto falta para o próximo marco de quantidade ("Tremor nível 1 · faltam
## 380 insetos") e, quando ele chega, o que abriu. Ver
## docs/pesquisa-habilidades.md, seções 12 e 14.

signal step_done(id: String)

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Glyphs := preload("res://scripts/ui/glyphs.gd")
const NestScript := preload("res://scripts/world/nest.gd")

## A sequência da área 1. "end" = acabou (o cartão some).
const STEPS := ["move", "lick", "eat50", "learn", "dig", "nest", "nests4", "rest", "queen", "exit", "end"]
## Insetos do objetivo "Coma 50 insetos" (pagam a Lambida Rápida).
const EAT_GOAL := 50
## Ninhos do objetivo "Limpe 4 ninhos".
const NESTS_GOAL := 4
## Quanto tempo a linha da próxima novidade mostra o que abriu (s).
const NOVELTY_HOLD := 4.0
## Duração do voo do losango (s), quanto tempo ele fica no alvo e o fade.
const FLIGHT_TIME := 1.25
const MARKER_TIME := 9.0
const FADE_TIME := 1.5
## Altura do losango acima do alvo (m).
const LIFT := 1.6
## Quanto o cartão espera mostrando o ✓ antes do próximo objetivo (s).
const DONE_HOLD := 1.4
const GOLD := Color("e8b44f")
const PALE := Color("f6e3b4")

var player
var world
var colony
## A bússola do HUD (mostra o alvo do objetivo).
var compass
## O cartão (o HUD o põe embaixo do painel de pontos).
var card: PanelContainer

var _title: Label
var _text: Label
var _count: Label
var _extra: Label
var _bar: Bar
## Linha da próxima novidade: texto e barra (do marco anterior até o próximo).
var _novelty: VBoxContainer
var _novelty_text: Label
var _novelty_bar: Bar
## Marco que a linha está mostrando como aberto, e por quanto tempo ainda.
var _reveal_index := 0
var _reveal_time := 0.0
var _icon: Gem
var _key: PanelContainer
var _key_label: Label
var _step := ""
var _target := Vector3.INF
## Formigueiro do objetivo "Limpe um formigueiro" e quantos ele tinha.
var _nest
var _nest_start := 1
## Voo: tempo desde que começou (<0 = sem voo) e o rastro na tela.
var _flight := -1.0
var _trail: Array[Vector2] = []
var _from := Vector2.ZERO
var _bend := 1.0
## Quanto tempo o losango ainda fica no alvo.
var _shown := 0.0
var _done_time := 0.0
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_card()


func setup(p, w, col, comp) -> void:
	player = p
	world = w
	colony = col
	compass = comp
	GameState.run_reset.connect(_restart)
	GameState.marco_reached.connect(_on_marco)
	Settings.changed.connect(_refresh_text)
	_restart()


## Jogo novo ou jogo salvo aberto: volta para o objetivo guardado e pula o que
## já está feito.
func _restart() -> void:
	_step = ""
	_done_time = 0.0
	_reveal_time = 0.0
	_flight = -1.0
	_shown = 0.0
	call_deferred("_resume")


func _resume() -> void:
	var i := clampi(GameState.objective, 0, STEPS.size() - 1)
	while i < STEPS.size() - 1 and _is_done(STEPS[i]):
		i += 1
	GameState.objective = i
	_enter(STEPS[i])


# ------------------------------------------------------------------ Cartão

func _build_card() -> void:
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_frame(14, 10))
	card.size_flags_horizontal = Control.SIZE_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	_icon = Gem.new()
	_icon.custom_minimum_size = Vector2(14, 14)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_icon)
	_title = UiTheme.caps_label("Objetivo", 12)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_title)
	_key = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.02, 0.018, 0.9)
	box.border_color = Color(GOLD, 0.6)
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	_key.add_theme_stylebox_override("panel", box)
	_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_key)
	_key_label = UiTheme.caps_label("F", 11, GOLD)
	_key.add_child(_key_label)
	_text = UiTheme.label("", 17, UiTheme.CREAM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(258, 0)
	v.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	v.add_child(row)
	_bar = Bar.new()
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bar)
	_count = UiTheme.display_label("", 15, UiTheme.SAND)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_count)
	_extra = UiTheme.label("", 14, UiTheme.MUTED)
	_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_extra.custom_minimum_size = Vector2(258, 0)
	v.add_child(_extra)
	_novelty = VBoxContainer.new()
	_novelty.add_theme_constant_override("separation", 5)
	_novelty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_novelty.visible = false
	v.add_child(_novelty)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.22)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_novelty.add_child(rule)
	_novelty_text = UiTheme.label("", 14, UiTheme.SAND)
	_novelty_text.add_theme_color_override("font_color", UiTheme.SAND)
	_novelty_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_novelty_text.custom_minimum_size = Vector2(258, 0)
	_novelty.add_child(_novelty_text)
	_novelty_bar = Bar.new()
	_novelty_bar.color = UiTheme.SAND
	_novelty_bar.custom_minimum_size = Vector2(0, 6)
	_novelty.add_child(_novelty_bar)


## Começa um objetivo: texto, alvo e o voo do losango (se tiver lugar).
func _enter(id: String) -> void:
	_step = id
	_done_time = 0.0
	_icon.done = false
	# Sem isso o ✓ do objetivo anterior fica no losango do novo.
	_icon.queue_redraw()
	_text.add_theme_color_override("font_color", UiTheme.CREAM)
	card.visible = id != "end"
	_pick_target()
	_refresh_text()
	if _target != Vector3.INF:
		relight()
	else:
		_flight = -1.0
		_shown = 0.0
	card.modulate.a = 0.0
	create_tween().tween_property(card, "modulate:a", 1.0, 0.35)


func _refresh_text() -> void:
	if _step == "" or _step == "end":
		return
	if _done_time <= 0.0:
		_text.text = _describe(_step)
	_key_label.text = Settings.key_label("objective")
	_key.visible = _target != Vector3.INF and _markers_on()
	var p := _progress(_step)
	_bar.get_parent().visible = p.y > 0
	if p.y > 0:
		_bar.value = clampf(float(p.x) / float(p.y), 0.0, 1.0)
		_count.text = "%s / %s" % [_n(mini(p.x, p.y)), _n(p.y)]
	var extra := ""
	_extra.text = extra
	_extra.visible = extra != ""


static func _n(v: int) -> String:
	var s := str(v)
	if v >= 1000:
		s = "%d %03d" % [v / 1000, v % 1000]
	return s


func _describe(id: String) -> String:
	var tree := Settings.key_label("open_skills")
	match id:
		"move":
			return "Ande com %s" % Settings.move_keys_label()
		"lick":
			return "Use a língua para comer um inseto (%s)" % Settings.key_label("lick")
		"eat50":
			return "Coma %d insetos" % EAT_GOAL
		"learn":
			return "Abra a árvore (%s) e aprenda a Lambida Rápida" % tree
		"dig":
			if GameState.can_dig():
				return "Abra uma câmara (%s)" % Settings.key_label("dig")
			return "Aprenda Cavar na árvore (%s) e abra uma câmara" % tree
		"nest":
			return "Limpe um ninho"
		"nests4":
			return "Limpe %d ninhos" % NESTS_GOAL
		"rest":
			return "Coma todos os insetos"
		"queen":
			return "Desmanche o ninho da rainha"
		"exit":
			return "Quebre o tronco da saída (%s)" % Settings.key_label("dig")
	return ""


## Progresso (feito, total); total 0 = sem barra.
func _progress(id: String) -> Vector2i:
	match id:
		"eat50":
			return Vector2i(GameState.ants_eaten, EAT_GOAL)
		"nest":
			if _nest != null:
				return Vector2i(_nest_start - _nest.remaining(), _nest_start)
		"nests4":
			if colony != null:
				return Vector2i(colony.nests_cleaned(), NESTS_GOAL)
		"rest":
			if colony != null:
				var goal: int = GameState.GOAL - colony.queen_pit_start()
				return Vector2i(goal - colony.rest_left(), goal)
	return Vector2i.ZERO


func _is_done(id: String) -> bool:
	match id:
		"move":
			# O bot de teste não usa o teclado: para ele, andar já conta.
			return Settings.hint_learned("move") or (DevTools.autoplay and GameState.elapsed > 2.0)
		"lick":
			return GameState.ants_eaten >= 1
		"eat50":
			return GameState.ants_eaten >= EAT_GOAL
		"learn":
			return GameState.has("lingua_segurar")
		"dig":
			return GameState.stat("chambers_opened") >= 1.0
		"nest":
			return GameState.marcos.has(GameState.MARCO_NINHO)
		"nests4":
			return colony != null and colony.nests_cleaned() >= NESTS_GOAL
		"rest":
			return GameState.marcos.has(GameState.MARCO_RAINHA)
		"queen":
			if world == null:
				return false
			# Fica até comer tudo: as moradoras do buraco da rainha também contam.
			return GameState.completed
		"exit":
			return world != null and world.exit_open
	return false


# ------------------------------------------------------------------ Alvo

## Onde fica o objetivo agora (INF = sem lugar).
func _pick_target() -> void:
	_target = Vector3.INF
	_nest = null
	if world == null or player == null:
		return
	var here := Vector2(player.global_position.x, player.global_position.z)
	match _step:
		"lick":
			var best := Vector2.INF
			for t in world.trails.trails:
				for k in range(0, t.points.size(), 3):
					var q: Vector2 = t.points[k]
					if q.distance_squared_to(here) < best.distance_squared_to(here):
						best = q
			if best != Vector2.INF:
				_target = _ground(best)
		"dig":
			var best_d := INF
			for n in world.nests:
				for c in n.chambers:
					if c.opened or c.size_class > 1:
						continue
					var d: float = here.distance_to(c.pos2)
					if d < best_d:
						best_d = d
						_target = n.chamber_world_pos(c)
		"nest", "nests4", "rest":
			var best_score := INF
			for n in world.nests:
				var left := _nest_left(n)
				if left <= 0 or not _nest_open(n):
					continue
				var score: float = left + here.distance_to(n.center2) * 20.0
				if score < best_score:
					best_score = score
					_nest = n
			if _nest != null:
				# O total é o do começo do jogo (não o que sobrou ao abrir um
				# jogo salvo), para a barra mostrar o que já foi comido.
				_nest_start = maxi(maxi(_nest.start_total, _nest.remaining()), 1)
				_target = _ground(_nest.center2) + Vector3(0, _nest.height, 0)
		"queen":
			for n in world.nests:
				if n.big:
					_target = _ground(n.center2) + Vector3(0, n.height, 0)
		"exit":
			if world.exit_log != null:
				_target = world.exit_log.global_position + Vector3(0, 0.6, 0)


## Quanto falta comer no ninho para o objetivo da vez. No "Coma todos os
## insetos", o buraco da rainha não conta (ele só abre no fim).
func _nest_left(n) -> int:
	if n.cleaned:
		return 0
	var left: int = n.remaining()
	if _step == "rest" and n.big:
		var royal = n.royal_chamber()
		if royal != null:
			left -= royal.residents
		if n.queen_alive:
			left -= NestScript.QUEEN_VALUE
	return left


## O losango só aponta ninhos que as garras de agora já limpam: no primeiro,
## só os pequenos (bastam as garras do começo); depois, os médios também,
## quando Cavar fundo nível 1 chega; o da rainha, só no fim.
func _nest_open(n) -> bool:
	match _step:
		"nest":
			return not n.big and not n.medium
		"nests4":
			return not n.big and (not n.medium or GameState.dig_level() >= 2)
	return true


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, world.ground_height(p.x, p.y), p.y)


## O ninho do objetivo agora (-1 = nenhum). O bot de teste vai atrás dos
## insetos dele com --bot-objetivos.
func target_nest() -> int:
	if _step == "queen" and world != null:
		for n in world.nests:
			if n.big:
				return n.index
	return _nest.index if _nest != null and _step != "end" else -1


## O losango voa de novo do cartão até o alvo.
func relight() -> void:
	if _target == Vector3.INF or not _markers_on():
		return
	_from = Vector2.INF
	_flight = 0.0
	_trail.clear()
	_bend = -1.0 if randf() < 0.5 else 1.0
	_shown = MARKER_TIME


func _markers_on() -> bool:
	return Settings.hints_level < 2


## Centro do losango do cartão, na tela.
func _card_point() -> Vector2:
	var r := _icon.get_global_rect()
	return r.get_center() - get_global_rect().position


# ------------------------------------------------------------------ Quadro

func _process(delta: float) -> void:
	_time += delta
	if player == null or _step == "":
		return
	if Input.is_action_just_pressed("objective") and player.controls_enabled and not get_tree().paused:
		relight()
	if _step != "end":
		if _done_time > 0.0:
			_done_time -= delta
			if _done_time <= 0.0:
				_next()
		elif _is_done(_step):
			_complete()
		else:
			# O alvo sumiu (câmara aberta por outro caminho, ninho limpo...).
			if _step == "dig" and _target != Vector3.INF and fmod(_time, 1.0) < delta:
				var old := _target
				_pick_target()
				if _target != old and _target != Vector3.INF:
					relight()
			elif _nest != null and fmod(_time, 1.0) < delta and _nest_left(_nest) <= 0:
				_pick_target()
				if _target != Vector3.INF:
					relight()
			_refresh_text()
	_refresh_novelty(delta)
	if _flight >= 0.0:
		_flight += delta
		if _flight >= FLIGHT_TIME:
			_flight = -1.0
	elif _shown > 0.0:
		_shown -= delta
	if compass:
		compass.objective = _target if _markers_on() and _step != "end" else Vector3.INF
	queue_redraw()


# ------------------------------------------------------------------ Próxima novidade

## A linha da próxima novidade aparece depois de aprender a primeira
## habilidade (quando o jogador já conhece a árvore).
func _novelty_on() -> bool:
	return _step != "end" and STEPS.find(_step) > STEPS.find("learn")


## Chegou um marco de quantidade: a linha mostra o que abriu por um tempo
## (menos quando a habilidade veio de presente: o aviso grande já diz).
func _on_marco(index: int) -> void:
	var m := GameState.get_marco(index)
	if not m.has("insects") or not _novelty_on() or GameState.last_gifts.has(String(m.skill)):
		return
	_reveal_index = index
	_reveal_time = NOVELTY_HOLD
	if GameState.last_gifts.is_empty():
		# Os marcos com presente já tocam o som do aviso grande.
		Sfx.play("point", -6.0, 1.5)


## "Tremor nível 1 · faltam 380 insetos" (o nome da árvore e o "Faltam N
## insetos" dela), com a barra do marco anterior até esse; quando ele chega,
## "Tremor nível 1 · desbloqueada" por um tempo (como o "Aprendida" da árvore).
func _refresh_novelty(delta: float) -> void:
	_reveal_time = maxf(_reveal_time - delta, 0.0)
	if not _novelty_on():
		_novelty.visible = false
		return
	if _reveal_time > 0.0:
		var shown := GameState.get_marco(_reveal_index)
		_novelty_text.text = "%s · desbloqueada" % GameState.get_upgrade(String(shown.skill)).name
		_novelty_color(UiTheme.LEAF)
		_novelty_bar.value = 1.0
		_novelty.visible = true
		return
	var m := GameState.next_insect_marco()
	_novelty.visible = not m.is_empty()
	if m.is_empty():
		return
	var at := int(m.insects)
	var from := GameState.prev_insect_marco(m.index)
	_novelty_text.text = "%s · faltam %s insetos" % [GameState.get_upgrade(String(m.skill)).name,
		_n(maxi(at - GameState.ants_eaten, 0))]
	_novelty_color(UiTheme.SAND)
	_novelty_bar.value = clampf(float(GameState.ants_eaten - from) / float(maxi(at - from, 1)), 0.0, 1.0)


## Cor do texto e da barra da próxima novidade (só muda quando precisa).
func _novelty_color(c: Color) -> void:
	if _novelty_bar.color == c:
		return
	_novelty_bar.color = c
	_novelty_text.add_theme_color_override("font_color", c)


func _complete() -> void:
	_done_time = DONE_HOLD
	_icon.done = true
	_icon.queue_redraw()
	_text.text = _describe(_step)
	_text.add_theme_color_override("font_color", UiTheme.LEAF)
	_refresh_text()
	Sfx.play("point", -6.0, 1.25)
	_shown = minf(_shown, 0.4)
	step_done.emit(_step)


func _next() -> void:
	var i := STEPS.find(_step) + 1
	while i < STEPS.size() - 1 and _is_done(STEPS[i]):
		step_done.emit(STEPS[i])
		i += 1
	i = mini(i, STEPS.size() - 1)
	GameState.objective = i
	_enter(STEPS[i])


func _draw() -> void:
	if _target == Vector3.INF or player == null or not _markers_on() or _step == "end":
		return
	var cam: Camera3D = player.camera
	if cam == null:
		return
	var aim := _screen_point(cam, _target + Vector3(0, LIFT, 0))
	if _flight >= 0.0:
		if _from == Vector2.INF:
			_from = _card_point()
		var t := clampf(_flight / FLIGHT_TIME, 0.0, 1.0)
		var e := t * t * (3.0 - 2.0 * t)
		var mid := (_from + aim) * 0.5
		var span := aim - _from
		var side := Vector2(-span.y, span.x).normalized() * span.length() * 0.22 * _bend
		var p := _from.lerp(mid + side, e).lerp((mid + side).lerp(aim, e), e)
		_trail.append(p)
		if _trail.size() > 18:
			_trail.pop_front()
		for k in range(1, _trail.size()):
			var f := float(k) / _trail.size()
			draw_line(_trail[k - 1], _trail[k], Color(GOLD, 0.55 * f), 1.0 + 4.0 * f, true)
		for k in _trail.size():
			var f := float(k + 1) / _trail.size()
			_diamond(_trail[k], 3.0 + 6.0 * f, Color(PALE, 0.3 * f))
		var r := lerpf(9.0, 14.0, e)
		draw_circle(p, r * 2.4, Color(GOLD, 0.2))
		_diamond(p, r, PALE)
		_diamond(p, r * 0.45, GOLD)
		return
	if _shown <= 0.0:
		return
	var a := clampf(_shown / FADE_TIME, 0.0, 1.0)
	var pulse := 0.75 + 0.25 * sin(_time * 4.5)
	draw_circle(aim, 26.0, Color(GOLD, 0.14 * a * pulse))
	_diamond(aim, 14.0 + pulse * 2.0, Color(PALE, a))
	_diamond(aim, 6.0, Color(GOLD, a))
	var dist: float = player.global_position.distance_to(_target)
	var txt := "%d m" % int(round(dist))
	var font: Font = UiTheme.display_bold_font()
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var tp := aim + Vector2(-w * 0.5, 40.0)
	draw_string(font, tp + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.7 * a))
	draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(PALE, a))


## Ponto do alvo na tela; atrás da câmera ou fora dela, vai para a borda (pelo
## lado mais curto).
func _screen_point(cam: Camera3D, pos: Vector3) -> Vector2:
	var vp := size
	var margin := 48.0
	var center := vp * 0.5
	if not cam.is_position_behind(pos):
		var s := cam.unproject_position(pos)
		if Rect2(Vector2.ONE * margin, vp - Vector2.ONE * margin * 2.0).has_point(s):
			return s
	# Direção do alvo em relação à câmera, no plano da tela.
	var local := cam.global_transform.affine_inverse() * pos
	var dir := Vector2(local.x, -local.y)
	if local.z > 0.0 and absf(dir.x) < 0.01:
		dir.x = 1.0
	if dir.length() < 0.001:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	var half := center - Vector2.ONE * margin
	var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	return center + dir * k


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0),
		c + Vector2(0, r), c + Vector2(-r * 0.8, 0)]), col)


## Losango do cartão (vira um ✓ verde quando o objetivo se cumpre).
class Gem extends Control:
	var done := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		if done:
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.8, 0), c + Vector2(-r * 0.2, r * 0.6),
				c + Vector2(r * 0.9, -r * 0.7)]), Color("b9d99a"), 2.5, true)
			return
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0),
			c + Vector2(0, r), c + Vector2(-r * 0.8, 0)]), Color("f6e3b4"))


## Barrinha do progresso (dourada; a da próxima novidade é areia).
class Bar extends Control:
	var value := 0.0:
		set(v):
			if v != value:
				value = v
				queue_redraw()
	var color := Color("e8b44f"):
		set(c):
			if c != color:
				color = c
				queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		var h := minf(size.y, 4.0)
		draw_rect(Rect2(0, y - h * 0.5, size.x, h), Color(color, 0.18))
		var w := size.x * clampf(value, 0.0, 1.0)
		if w > 1.0:
			draw_rect(Rect2(0, y - h * 0.5, w, h), color)
