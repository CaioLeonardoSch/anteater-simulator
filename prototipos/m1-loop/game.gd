extends Node2D

# =============================================================
#  TAMANDUÁ — protótipo do loop principal
#  Objetivo deste protótipo: responder UMA pergunta —
#  "comer inseto é gostoso o bastante pra sustentar 3-5 horas?"
#  Tudo aqui é arte de programador de propósito.
# =============================================================

# ---------- Layout (resolução de projeto 1152x648) ----------
const SNOUT := Vector2(576.0, 616.0)

# ---------- Progressão por marcos (total comido, sem economia) ----------
const M_LAMBIDA := 50      # Língua 2: lambida + alcance
const M_GARRAS := 150      # quebra o bloqueio no caminho da câmara do topo
const M_LINGUA3 := 185     # Língua 3: alcance total + velocidade
# Faro, na escada do documento:
#   I   - avisa que sobrou algo perto (raio curto, SEM direção)
#   II  - aponta a área (a câmara) dentro do ninho
#   III - marca o inseto exato, e funciona à distância
const M_FARO1 := 25
const M_FARO2 := 100
const M_FARO3 := 175

const REACH := [250.0, 520.0, 640.0]
const EAT_INTERVAL := [0.38, 0.13, 0.065]

const FARO_COOLDOWN := 4.0
const FARO_DURATION := 3.5

# ---------- Paleta ----------
const C_BG := Color(0.09, 0.07, 0.06)
const C_MOUND := Color(0.28, 0.20, 0.14)
const C_MOUND_EDGE := Color(0.20, 0.14, 0.10)
const C_CHAMBER := Color(0.14, 0.11, 0.09)
const C_CHAMBER_DONE := Color(0.11, 0.15, 0.11)
const C_TUNNEL := Color(0.16, 0.12, 0.10)
const C_BUG := Color(0.86, 0.78, 0.55)
const C_BUG_DARK := Color(0.62, 0.52, 0.32)
const C_QUEEN := Color(0.95, 0.72, 0.80)
const C_TONGUE := Color(0.90, 0.42, 0.48)
const C_FUR := Color(0.30, 0.28, 0.30)
const C_FUR_LIGHT := Color(0.72, 0.70, 0.68)
const C_TEXT := Color(0.92, 0.89, 0.84)
const C_DIM := Color(0.55, 0.50, 0.45)
const C_GOLD := Color(1.0, 0.82, 0.35)


class Bug:
	var pos: Vector2
	var vel: Vector2
	var home: int          # índice da câmara
	var phase: float
	var alive: bool = true
	var lit: float = 0.0   # destaque do faro


class Chamber:
	var c: Vector2
	var r: float
	var total: int = 0
	var left: int = 0
	var locked: bool = false
	var has_queen: bool = false
	var flash: float = 0.0
	var glow: float = 0.0


# ---------- Estado ----------
var chambers: Array = []
var bugs: Array = []
var particles: Array = []

var queen_pos: Vector2
var queen_alive: bool = true
var queen_eaten_at: float = -1.0

var total_bugs: int = 0
var eaten: int = 0

var tongue_out: bool = false
var tongue_tip: Vector2 = SNOUT
var tongue_ctrl: Vector2 = SNOUT
var tongue_target: Vector2 = SNOUT
var eat_timer: float = 0.0
var dab_lock: bool = false      # no nível 1 a língua come 1 e recolhe
var dab_time: float = 0.0       # janela em que a bicada continua valendo depois do clique

var combo: int = 0
var combo_timer: float = 0.0

var faro_timer: float = 0.0     # cooldown restante
var faro_active: float = 0.0    # duração restante
var faro_pulse: float = 0.0

var shake: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var finished: bool = false
var finish_time: float = 0.0
var taps: int = 0
var lick_seconds: float = 0.0
var banner: String = ""
var banner_t: float = 0.0

var garras_open_anim: float = 0.0
var last_unlocked_lambida: bool = false

# ---------- Áudio ----------
var players: Array = []
var next_player: int = 0
var snd_chomp: AudioStreamWAV
var snd_clear: AudioStreamWAV
var snd_crack: AudioStreamWAV
var snd_queen: AudioStreamWAV
var snd_unlock: AudioStreamWAV

var font: Font


func _ready() -> void:
	randomize()
	font = ThemeDB.fallback_font
	_build_audio()
	_build_nest()
	set_process(true)


# =============================================================
#  Construção do ninho
# =============================================================
func _build_nest() -> void:
	chambers.clear()
	bugs.clear()
	particles.clear()

	# A câmara 5 é a mais cheia do ninho em número E em densidade:
	# 68 insetos num raio de 58 contra 55 num raio de 95 na base.
	# É o "ponto mais cheio" onde o documento põe a rainha.
	var defs := [
		{"c": Vector2(576, 470), "r": 95.0, "n": 55, "lock": false, "queen": false},
		{"c": Vector2(400, 320), "r": 78.0, "n": 38, "lock": false, "queen": false},
		{"c": Vector2(752, 320), "r": 78.0, "n": 38, "lock": false, "queen": false},
		{"c": Vector2(480, 190), "r": 66.0, "n": 30, "lock": false, "queen": false},
		{"c": Vector2(672, 190), "r": 66.0, "n": 30, "lock": false, "queen": false},
		{"c": Vector2(576, 70), "r": 58.0, "n": 68, "lock": true, "queen": true},
	]

	for i in defs.size():
		var d: Dictionary = defs[i]
		var ch := Chamber.new()
		ch.c = d["c"]
		ch.r = d["r"]
		ch.total = d["n"]
		ch.left = d["n"]
		ch.locked = d["lock"]
		ch.has_queen = d["queen"]
		chambers.append(ch)

		for j in int(d["n"]):
			var b := Bug.new()
			var a := randf() * TAU
			var rr: float = sqrt(randf()) * (ch.r - 10.0)
			b.pos = ch.c + Vector2(cos(a), sin(a)) * rr
			b.vel = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 16.0
			b.home = i
			b.phase = randf() * TAU
			bugs.append(b)

	queen_pos = chambers[5].c
	queen_alive = true
	total_bugs = bugs.size() + 1

	eaten = 0
	elapsed = 0.0
	finished = false
	taps = 0
	lick_seconds = 0.0
	combo = 0
	combo_timer = 0.0
	faro_timer = 0.0
	faro_active = 0.0
	tongue_out = false
	tongue_tip = SNOUT
	tongue_ctrl = SNOUT
	queen_eaten_at = -1.0
	garras_open_anim = 0.0
	last_unlocked_lambida = false
	banner = "Toque e segure pra usar a língua"
	banner_t = 3.5


# =============================================================
#  Progressão
# =============================================================
func tongue_level() -> int:
	if eaten >= M_LINGUA3:
		return 2
	if eaten >= M_LAMBIDA:
		return 1
	return 0

func lick_unlocked() -> bool:
	return eaten >= M_LAMBIDA

func faro_level() -> int:
	if eaten >= M_FARO3:
		return 3
	if eaten >= M_FARO2:
		return 2
	if eaten >= M_FARO1:
		return 1
	return 0

func reach() -> float:
	return float(REACH[tongue_level()])


# =============================================================
#  Entrada
# =============================================================
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_build_nest()
			return
		if event.keycode == KEY_F:
			_try_faro()
			return

	var pressed := false
	var released := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed

	if pressed:
		var mp := get_global_mouse_position()
		if _faro_button_rect().has_point(mp):
			_try_faro()
			return
		if finished:
			if elapsed - finish_time > 1.2:
				_build_nest()
			return
		tongue_out = true
		taps += 1
		dab_lock = false
		eat_timer = 0.0
		if not lick_unlocked():
			dab_time = 0.34
	elif released:
		tongue_out = false
		dab_lock = false


func _faro_button_rect() -> Rect2:
	return Rect2(28, 556, 176, 60)


func _try_faro() -> void:
	if faro_level() == 0 or faro_timer > 0.0:
		return
	faro_timer = FARO_COOLDOWN
	faro_active = FARO_DURATION
	faro_pulse = 1.0
	_play(snd_unlock, 1.35, 0.35)
	var lvl := faro_level()
	# Nível I não marca nada: só responde "tem algo perto?" enquanto dura.
	if lvl >= 2:
		for ch in chambers:
			if ch.left > 0 and not ch.locked:
				ch.glow = 1.0
	if lvl >= 3:
		for b in bugs:
			if b.alive:
				b.lit = 1.0


# =============================================================
#  Loop
# =============================================================
func _process(delta: float) -> void:
	if not finished:
		elapsed += delta

	var mp := get_global_mouse_position()

	# --- língua ---
	dab_time = max(0.0, dab_time - delta)
	var active := (tongue_out or dab_time > 0.0) and not finished

	if active:
		tongue_target = mp
		var d := tongue_target - SNOUT
		var max_r := reach()
		if d.length() > max_r:
			tongue_target = SNOUT + d.normalized() * max_r
		if lick_unlocked() and tongue_out:
			lick_seconds += delta
	else:
		tongue_target = SNOUT

	# chicote: a ponta persegue o alvo, o controle atrasa mais
	var speed := 26.0 if active else 13.0
	tongue_tip = tongue_tip.lerp(tongue_target, clamp(speed * delta, 0.0, 1.0))
	tongue_ctrl = tongue_ctrl.lerp(tongue_tip.lerp(SNOUT, 0.5), clamp(8.0 * delta, 0.0, 1.0))

	# --- comer ---
	eat_timer -= delta
	var can_eat := active
	if can_eat and not lick_unlocked() and dab_lock:
		can_eat = false
	if can_eat and eat_timer <= 0.0:
		if _eat_near(tongue_tip):
			eat_timer = float(EAT_INTERVAL[tongue_level()])
			if not lick_unlocked():
				dab_lock = true

	# --- insetos ---
	var tip_active := active
	for b in bugs:
		if not b.alive:
			continue
		var ch: Chamber = chambers[b.home]
		b.phase += delta * randf_range(3.0, 5.0)
		b.vel += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 60.0 * delta
		if tip_active:
			var away := b.pos - tongue_tip
			var dl := away.length()
			if dl < 46.0 and dl > 0.1:
				b.vel += away / dl * (46.0 - dl) * 9.0 * delta
		b.vel = b.vel.limit_length(58.0 if tip_active else 32.0)
		b.pos += b.vel * delta
		var off := b.pos - ch.c
		if off.length() > ch.r - 7.0:
			b.pos = ch.c + off.normalized() * (ch.r - 7.0)
			b.vel = b.vel.bounce(off.normalized()) * 0.6
		b.lit = max(0.0, b.lit - delta / FARO_DURATION)

	# --- combo ---
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo = 0

	# --- faro ---
	faro_timer = max(0.0, faro_timer - delta)
	faro_active = max(0.0, faro_active - delta)
	faro_pulse = max(0.0, faro_pulse - delta * 0.8)

	# --- garras / trava da rainha ---
	if chambers[5].locked and eaten >= M_GARRAS:
		chambers[5].locked = false
		garras_open_anim = 1.0
		shake = 7.0
		_play(snd_crack, 1.0, 0.9)
		_banner("GARRAS — a câmara da rainha abriu")
	garras_open_anim = max(0.0, garras_open_anim - delta * 0.8)

	if not last_unlocked_lambida and lick_unlocked():
		last_unlocked_lambida = true
		_banner("LAMBIDA — segure e arraste pra comer em sequência")
		_play(snd_unlock, 1.0, 0.6)

	# --- câmaras ---
	for ch in chambers:
		ch.flash = max(0.0, ch.flash - delta * 1.6)
		ch.glow = max(0.0, ch.glow - delta / FARO_DURATION)

	# --- partículas ---
	var keep: Array = []
	for p in particles:
		p["life"] -= delta
		if p["life"] > 0.0:
			p["pos"] += p["vel"] * delta
			p["vel"] *= 0.90
			keep.append(p)
	particles = keep

	shake = max(0.0, shake - delta * 26.0)
	shake_offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))

	banner_t = max(0.0, banner_t - delta)

	if not finished and eaten >= total_bugs and not queen_alive:
		finished = true
		finish_time = elapsed
		_banner("NINHO LIMPO")

	queue_redraw()


func _eat_near(tip: Vector2) -> bool:
	# rainha primeiro, se estiver liberada
	var qch: Chamber = chambers[5]
	if queen_alive and not qch.locked and qch.left <= 0:
		if tip.distance_to(queen_pos) < 30.0:
			queen_alive = false
			eaten += 1
			queen_eaten_at = elapsed
			shake = 12.0
			_burst(queen_pos, 34, C_QUEEN, 260.0)
			_play(snd_queen, 1.0, 1.0)
			_banner("RAINHA   x18")
			return true

	var best := -1
	var best_d := 26.0
	for i in bugs.size():
		var b: Bug = bugs[i]
		if not b.alive:
			continue
		var ch: Chamber = chambers[b.home]
		if ch.locked:
			continue
		var d := tip.distance_to(b.pos)
		if d < best_d:
			best_d = d
			best = i

	if best < 0:
		return false

	var bug: Bug = bugs[best]
	bug.alive = false
	eaten += 1
	var ch2: Chamber = chambers[bug.home]
	ch2.left -= 1

	combo += 1
	combo_timer = 0.75
	var semis: int = combo % 14
	_play(snd_chomp, pow(1.05946, float(semis)), 0.5)
	_burst(bug.pos, 5, C_BUG, 90.0)

	if ch2.left == 0:
		ch2.flash = 1.0
		if not ch2.has_queen:
			_play(snd_clear, 1.0, 0.7)
			_banner("Câmara limpa")
		else:
			_play(snd_clear, 0.8, 0.8)
			_banner("A rainha está exposta")
	return true


func _burst(p: Vector2, n: int, col: Color, spd: float) -> void:
	for i in n:
		var a := randf() * TAU
		particles.append({
			"pos": p,
			"vel": Vector2(cos(a), sin(a)) * randf_range(spd * 0.3, spd),
			"life": randf_range(0.18, 0.45),
			"col": col,
		})


func _banner(t: String) -> void:
	banner = t
	banner_t = 2.6


# =============================================================
#  Áudio procedural (sem arquivos externos)
# =============================================================
func _build_audio() -> void:
	snd_chomp = _tone(300.0, 0.10, 34.0, 0.45)
	snd_clear = _tone(660.0, 0.35, 7.0, 0.05)
	snd_crack = _tone(120.0, 0.45, 9.0, 0.85)
	snd_queen = _tone(520.0, 0.90, 3.0, 0.02)
	snd_unlock = _tone(880.0, 0.22, 12.0, 0.03)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func _tone(freq: float, dur: float, decay: float, noise: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env: float = exp(-decay * t)
		var s: float = sin(TAU * freq * t)
		s += 0.35 * sin(TAU * freq * 2.0 * t)
		s = s / 1.35
		if noise > 0.0:
			s = lerp(s, randf_range(-1.0, 1.0), noise * env)
		var v := int(clamp(s * env, -1.0, 1.0) * 30000.0)
		data.encode_s16(i * 2, v)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.stereo = false
	st.data = data
	return st


func _play(stream: AudioStreamWAV, pitch: float, vol: float) -> void:
	if stream == null or players.is_empty():
		return
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = stream
	p.pitch_scale = clamp(pitch, 0.2, 3.0)
	p.volume_db = linear_to_db(clamp(vol, 0.001, 1.0))
	p.play()


# =============================================================
#  Desenho
# =============================================================
func _draw() -> void:
	draw_set_transform(shake_offset, 0.0, Vector2.ONE)
	_draw_mound()
	_draw_tunnels()

	for i in chambers.size():
		_draw_chamber(chambers[i])

	# rainha (embaixo dos insetos, coberta por eles)
	var qch: Chamber = chambers[5]
	if queen_alive and not qch.locked:
		var pulse: float = 1.0 + 0.06 * sin(elapsed * 4.0)
		var ready: bool = qch.left <= 0
		var qc: Color = C_QUEEN if ready else C_QUEEN.darkened(0.35)
		draw_circle(queen_pos, 19.0 * pulse, qc)
		draw_circle(queen_pos + Vector2(0, -14), 9.0, qc.lightened(0.15))
		if ready:
			draw_arc(queen_pos, 30.0 + 4.0 * sin(elapsed * 5.0), 0, TAU, 40, C_GOLD, 2.0, true)

	for b in bugs:
		if b.alive and not chambers[b.home].locked:
			_draw_bug(b)

	if garras_open_anim > 0.0:
		draw_arc(chambers[5].c, (1.0 - garras_open_anim) * 200.0, 0, TAU, 48,
			Color(1, 0.85, 0.5, garras_open_anim * 0.8), 4.0, true)

	for p in particles:
		var a: float = clamp(p["life"] * 3.0, 0.0, 1.0)
		var col: Color = p["col"]
		draw_circle(p["pos"], 2.4 * a + 0.6, Color(col.r, col.g, col.b, a))

	_draw_anteater()
	_draw_tongue()
	_draw_faro_overlay()
	_draw_hud()


func _draw_mound() -> void:
	var pts := PackedVector2Array([
		Vector2(576, 8), Vector2(636, 60), Vector2(690, 150), Vector2(714, 220),
		Vector2(800, 260), Vector2(858, 340), Vector2(872, 440), Vector2(902, 560),
		Vector2(880, 600), Vector2(272, 600), Vector2(250, 560), Vector2(280, 440),
		Vector2(294, 340), Vector2(352, 260), Vector2(438, 220), Vector2(462, 150),
		Vector2(516, 60),
	])
	draw_colored_polygon(pts, C_MOUND)
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, C_MOUND_EDGE, 3.0, true)


func _draw_tunnels() -> void:
	var links := [[0, 1], [0, 2], [1, 3], [2, 4], [3, 5], [4, 5]]
	for l in links:
		var a: Chamber = chambers[l[0]]
		var b: Chamber = chambers[l[1]]
		if b.locked or a.locked:
			continue
		draw_line(a.c, b.c, C_TUNNEL, 22.0, true)
	# entrada, do focinho até a câmara base
	draw_line(SNOUT, chambers[0].c, C_TUNNEL, 26.0, true)

	# tampão de terra: só some com as Garras
	if chambers[5].locked:
		for pair in [[3, 5], [4, 5]]:
			var a2: Chamber = chambers[pair[0]]
			var mid: Vector2 = a2.c.lerp(chambers[5].c, 0.45)
			draw_circle(mid, 20.0, C_MOUND_EDGE)
			draw_arc(mid, 20.0, 0, TAU, 24, Color(0.5, 0.36, 0.24), 2.0, true)


func _draw_chamber(ch: Chamber) -> void:
	if ch.locked:
		return
	var base: Color = C_CHAMBER_DONE if ch.left == 0 else C_CHAMBER
	draw_circle(ch.c, ch.r, base)
	if ch.glow > 0.0 and ch.left > 0:
		var g: float = ch.glow * (0.5 + 0.5 * sin(elapsed * 9.0))
		draw_arc(ch.c, ch.r - 2.0, 0, TAU, 48, Color(0.4, 0.9, 1.0, g * 0.9), 3.0, true)
	if ch.flash > 0.0:
		draw_arc(ch.c, ch.r * (1.0 + (1.0 - ch.flash) * 0.35), 0, TAU, 48,
			Color(0.6, 1.0, 0.6, ch.flash), 3.0, true)
	draw_arc(ch.c, ch.r, 0, TAU, 48, Color(0.36, 0.26, 0.18, 0.85), 2.0, true)


func _draw_bug(b: Bug) -> void:
	var w: float = sin(b.phase) * 1.2
	var p: Vector2 = b.pos + Vector2(w, 0)
	draw_circle(p, 4.2, C_BUG)
	draw_circle(p + b.vel.normalized() * 3.0, 2.4, C_BUG_DARK)
	if b.lit > 0.0 and faro_level() >= 3:
		draw_arc(p, 9.0 + 3.0 * sin(elapsed * 10.0), 0, TAU, 16,
			Color(0.4, 0.95, 1.0, b.lit), 1.6, true)


func _draw_anteater() -> void:
	var body := Vector2(576, 660)
	draw_circle(body, 76.0, C_FUR)
	draw_circle(body + Vector2(-84, -6), 34.0, C_FUR)      # cauda
	draw_circle(body + Vector2(84, -6), 34.0, C_FUR)
	# focinho
	var snout_poly := PackedVector2Array([
		SNOUT + Vector2(-9, 0), SNOUT + Vector2(9, 0),
		body + Vector2(34, -20), body + Vector2(-34, -20),
	])
	draw_colored_polygon(snout_poly, C_FUR.lightened(0.08))
	draw_circle(SNOUT, 9.0, C_FUR.darkened(0.25))
	# faixa clara
	draw_line(body + Vector2(-60, 6), body + Vector2(28, -34), C_FUR_LIGHT, 7.0, true)
	# raio de alcance
	draw_arc(SNOUT, reach(), PI * 1.02, TAU * 0.99, 64, Color(0.9, 0.5, 0.5, 0.13), 2.0, true)


func _draw_tongue() -> void:
	if tongue_tip.distance_to(SNOUT) < 4.0:
		return
	var pts := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var t := float(i) / float(steps)
		var a: Vector2 = SNOUT.lerp(tongue_ctrl, t)
		var b: Vector2 = tongue_ctrl.lerp(tongue_tip, t)
		pts.append(a.lerp(b, t))
	draw_polyline(pts, C_TONGUE.darkened(0.25), 9.0, true)
	draw_polyline(pts, C_TONGUE, 5.0, true)
	draw_circle(tongue_tip, 7.0, C_TONGUE.lightened(0.15))
	if tongue_out and lick_unlocked():
		draw_arc(tongue_tip, 20.0, 0, TAU, 20, Color(1, 0.6, 0.6, 0.35), 1.5, true)


func _draw_faro_overlay() -> void:
	if faro_pulse > 0.0:
		var r: float = (1.0 - faro_pulse) * 900.0
		draw_arc(SNOUT, r, PI, TAU, 64, Color(0.4, 0.95, 1.0, faro_pulse * 0.5), 3.0, true)

	# Faro I: raio curto, sem direção. Só diz que sobrou algo por perto.
	if faro_active > 0.0 and faro_level() == 1:
		var mp := get_global_mouse_position()
		var near := _any_remaining_within(mp, 165.0)
		var col: Color = Color(0.40, 0.95, 1.0, 0.80) if near else Color(0.55, 0.52, 0.50, 0.40)
		draw_arc(mp, 38.0 + 6.0 * sin(elapsed * 7.0), 0, TAU, 32, col, 3.0, true)
		var msg: String = "algo por perto" if near else "nada por perto"
		draw_string(font, mp + Vector2(48, -4), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)


func _any_remaining_within(p: Vector2, r: float) -> bool:
	var r2 := r * r
	for b in bugs:
		if b.alive and not chambers[b.home].locked:
			if p.distance_squared_to(b.pos) < r2:
				return true
	if queen_alive and not chambers[5].locked and chambers[5].left <= 0:
		if p.distance_squared_to(queen_pos) < r2:
			return true
	return false


func _draw_hud() -> void:
	var remaining: int = max(0, total_bugs - eaten)
	draw_string(font, Vector2(28, 44), "Comidos  %d / %d" % [eaten, total_bugs],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, C_TEXT)
	draw_string(font, Vector2(28, 72), "Tempo  %s" % _fmt(elapsed),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, C_DIM)
	draw_string(font, Vector2(28, 96), "Restam  %d" % remaining,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, C_DIM)

	# barra de progresso
	var w := 260.0
	draw_rect(Rect2(28, 110, w, 8), Color(1, 1, 1, 0.10))
	draw_rect(Rect2(28, 110, w * float(eaten) / float(max(1, total_bugs)), 8), C_GOLD)

	# marcos
	var y := 150.0
	_milestone("Lambida", M_LAMBIDA, y)
	_milestone("Garras", M_GARRAS, y + 24)
	_milestone("Lingua III", M_LINGUA3, y + 48)
	_milestone("Faro I  (tem algo perto)", M_FARO1, y + 72)
	_milestone("Faro II  (qual camara)", M_FARO2, y + 96)
	_milestone("Faro III  (inseto exato)", M_FARO3, y + 120)

	# combo
	if combo > 2:
		draw_string(font, Vector2(940, 60), "x%d" % combo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 34, C_GOLD)

	# botão faro
	var r := _faro_button_rect()
	var enabled := faro_level() > 0 and faro_timer <= 0.0
	var bg := Color(0.16, 0.34, 0.40) if enabled else Color(0.16, 0.16, 0.18)
	draw_rect(r, bg)
	draw_rect(r, Color(1, 1, 1, 0.18), false, 2.0)
	var label := "FARO  [F]" if faro_level() > 0 else "FARO bloqueado"
	draw_string(font, r.position + Vector2(16, 26), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, C_TEXT if enabled else C_DIM)
	if faro_timer > 0.0:
		draw_string(font, r.position + Vector2(16, 48), "%.1fs" % faro_timer,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_DIM)
	elif faro_level() > 0:
		draw_string(font, r.position + Vector2(16, 48), "nivel %d" % faro_level(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_DIM)

	# dica de gesto
	var hint := "Segure e arraste = LAMBIDA" if lick_unlocked() else "Clique = bicada (1 inseto por vez)"
	draw_string(font, Vector2(28, 636), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_DIM)
	draw_string(font, Vector2(1000, 636), "[R] reiniciar", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_DIM)

	# banner
	if banner_t > 0.0 and not finished:
		var a: float = clamp(banner_t, 0.0, 1.0)
		draw_string(font, Vector2(0, 300), banner, HORIZONTAL_ALIGNMENT_CENTER, 1152, 40,
			Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, a))

	if finished:
		draw_rect(Rect2(0, 0, 1152, 648), Color(0, 0, 0, 0.62))
		draw_string(font, Vector2(0, 230), "NINHO LIMPO", HORIZONTAL_ALIGNMENT_CENTER, 1152, 56, C_GOLD)
		draw_string(font, Vector2(0, 300), "Tempo total: %s" % _fmt(elapsed),
			HORIZONTAL_ALIGNMENT_CENTER, 1152, 28, C_TEXT)
		draw_string(font, Vector2(0, 340), "Insetos: %d   Cliques: %d   Segundos lambendo: %.0f"
			% [total_bugs, taps, lick_seconds], HORIZONTAL_ALIGNMENT_CENTER, 1152, 22, C_DIM)
		var per_min: float = float(total_bugs) / max(0.01, elapsed / 60.0)
		draw_string(font, Vector2(0, 378), "Ritmo: %.0f insetos/min" % per_min,
			HORIZONTAL_ALIGNMENT_CENTER, 1152, 22, C_DIM)
		draw_string(font, Vector2(0, 440),
			"Alvo do design: 3 a 6 min por ninho. Este ninho tem %d insetos." % total_bugs,
			HORIZONTAL_ALIGNMENT_CENTER, 1152, 20, C_DIM)
		draw_string(font, Vector2(0, 500), "Clique ou [R] pra jogar de novo",
			HORIZONTAL_ALIGNMENT_CENTER, 1152, 20, C_TEXT)


func _milestone(label: String, at: int, y: float) -> void:
	var got: bool = eaten >= at
	var col: Color = C_GOLD if got else Color(0.45, 0.42, 0.40)
	var mark: String = "*" if got else "-"
	draw_string(font, Vector2(28, y), "%s %s" % [mark, label],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)
	if not got:
		draw_string(font, Vector2(232, y), "%d" % at,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.40, 0.37, 0.35))


func _fmt(s: float) -> String:
	var m := int(s) / 60
	var sec := int(s) % 60
	return "%d:%02d" % [m, sec]
