extends Control
## Aba do mapa (TAB): a clareira vista de cima, colorida onde você já andou e
## em sépia escura onde ainda não. Mostra os formigueiros (limpos, começados ou
## ainda não visitados), as câmaras do campo que você já viu, a caverna, o
## tronco da saída, para onde fica o cupinzeiro gigante e você.

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Exploration := preload("res://scripts/world/exploration.gd")

## Raio (m) mostrado no círculo, a partir do centro da clareira.
const VIEW_RADIUS := 74.0
## Resolução da foto de cima.
const SHOT_SIZE := 1024

const MAP_SHADER := """
shader_type canvas_item;
uniform sampler2D shot : filter_linear_mipmap;
uniform sampler2D fog : filter_linear;
uniform float view = 0.9867;
void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d) * 2.0;
	vec2 suv = 0.5 + d * view;
	vec3 c = texture(shot, suv).rgb;
	float seen = smoothstep(0.2, 0.7, texture(fog, suv).r);
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	vec3 sepia = vec3(0.62, 0.47, 0.32) * (0.1 + l * 0.52);
	vec3 col = mix(sepia, c, seen);
	col *= mix(1.0, 0.72, smoothstep(0.82, 1.0, r));
	COLOR = vec4(col, 1.0 - smoothstep(0.994, 1.0, r));
}
"""

var player
var world
var colony
var exploration
## Centro e raio do círculo do mapa na tela.
var center := Vector2.ZERO
var radius := 360.0
var time := 0.0
## Números do painel (atualizados ao abrir).
var nests_text := ""
var chambers_text := ""
var explored_text := ""
var _map_rect: ColorRect
var _mat: ShaderMaterial
var _overlay: MapOverlay
var _shot_started := false
var _stars: Array[Vector4] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 90:
		_stars.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.5), rng.randf_range(0.1, 0.45)))
	_map_rect = ColorRect.new()
	_map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = MAP_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("view", VIEW_RADIUS / (Exploration.WORLD_SIZE * 0.5))
	var dark := Image.create(4, 4, false, Image.FORMAT_RGB8)
	dark.fill(Color(0.1, 0.075, 0.055))
	_mat.set_shader_parameter("shot", ImageTexture.create_from_image(dark))
	_map_rect.material = _mat
	add_child(_map_rect)
	_overlay = MapOverlay.new()
	_overlay.view = self
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	resized.connect(_layout)
	_layout()


func setup(p, w, c, e) -> void:
	player = p
	world = w
	colony = c
	exploration = e


func _layout() -> void:
	var d := clampf(minf(size.y - 180.0, size.x * 0.48), 300.0, 760.0)
	radius = d * 0.5
	center = Vector2(size.x * 0.5 - 100.0, size.y * 0.5 + 22.0)
	_map_rect.position = center - Vector2(radius, radius)
	_map_rect.size = Vector2(d, d)
	queue_redraw()
	_overlay.queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	time += delta
	_overlay.queue_redraw()


## Abre a aba: atualiza a névoa e os números.
func open() -> void:
	visible = true
	take_shot()
	if exploration:
		_mat.set_shader_parameter("fog", exploration.texture())
		explored_text = "%d%%" % int(round(exploration.fraction() * 100.0))
	var done := 0
	var total := 0
	for n in world.nests:
		total += n.chambers.size()
		done += n.clean_chambers()
	chambers_text = "%d/%d" % [done, total]
	nests_text = "%d/%d" % [colony.nests_cleaned(), world.nests.size()]
	_overlay.queue_redraw()


## Ponto do mundo (plano xz) no círculo da tela: norte em cima, leste à direita.
func to_map(p2: Vector2) -> Vector2:
	return center + p2 / VIEW_RADIUS * radius


## Foto da clareira vista de cima, tirada uma vez só depois de o mundo ficar
## pronto: câmera ortográfica, sem neblina.
func take_shot() -> void:
	if _shot_started or world == null or DisplayServer.get_name() == "headless":
		return
	_shot_started = true
	var vp := SubViewport.new()
	vp.size = Vector2i(SHOT_SIZE, SHOT_SIZE)
	vp.world_3d = get_tree().root.find_world_3d()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	get_tree().root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = Exploration.WORLD_SIZE
	cam.near = 1.0
	cam.far = 600.0
	var env: Environment = world.env.duplicate()
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	cam.environment = env
	vp.add_child(cam)
	cam.position = Vector3(0, 250, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		_shot_started = false
		return
	img.generate_mipmaps()
	_mat.set_shader_parameter("shot", ImageTexture.create_from_image(img))


## Fundo escuro com um brilho quente atrás do mapa e algumas estrelas.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.043, 0.031, 0.027))
	for k in 9:
		var t := float(k) / 8.0
		var r := lerpf(radius * 2.3, radius * 0.6, t)
		draw_circle(center, r, Color(0.55, 0.32, 0.17, 0.02 + t * 0.01))
	for s in _stars:
		draw_circle(Vector2(s.x * size.x, s.y * size.y), s.z, Color(1.0, 0.9, 0.75, s.w))


## Tudo o que vai por cima da foto: moldura, pontos cardeais, ícones, você e
## o painel com os números.
class MapOverlay extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	const Glyphs := preload("res://scripts/ui/glyphs.gd")
	const GiantMound := preload("res://scripts/world/giant_mound.gd")
	const DARK := Color(0.05, 0.035, 0.028, 0.82)
	var view

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _back_rect().has_point(event.position):
				accept_event()
				view.closed.emit()

	func _back_rect() -> Rect2:
		return Rect2(size - Vector2(168, 62), Vector2(132, 30))

	func _diamond(p: Vector2, r: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), col)

	func _diamond_outline(p: Vector2, r: float, col: Color) -> void:
		draw_polyline(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0),
			p + Vector2(0, -r)]), col, 1.3, true)

	func _text(f: Font, pos: Vector2, text: String, fs: int, col: Color, centered: bool = false) -> void:
		var x := pos.x
		if centered:
			x -= f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5
		draw_string(f, Vector2(x, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _seen(p2: Vector2) -> bool:
		return view.exploration == null or view.exploration.explored_at(p2) > 0.4

	func _draw() -> void:
		if view == null or view.world == null:
			return
		var c: Vector2 = view.center
		var r: float = view.radius
		var gold := UT.GOLD
		# Moldura: brilho, faixa escura e o anel dourado.
		draw_arc(c, r + 22.0, 0, TAU, 96, Color(gold, 0.05), 24.0, true)
		draw_arc(c, r + 4.5, 0, TAU, 128, Color(0.05, 0.035, 0.028, 0.92), 7.0, true)
		draw_arc(c, r + 8.5, 0, TAU, 128, Color(gold, 0.45), 1.0, true)
		draw_arc(c, r, 0, TAU, 128, gold, 3.0, true)
		# Pontos cardeais.
		var df: Font = UT.display_font()
		_text(df, c + Vector2(0, -r - 18.0), "N", 22, UT.PALE, true)
		_text(df, c + Vector2(0, r + 38.0), "S", 20, UT.SAND, true)
		_text(df, c + Vector2(-r - 30.0, 7.0), "O", 20, UT.SAND, true)
		_text(df, c + Vector2(r + 30.0, 7.0), "L", 20, UT.SAND, true)
		var world = view.world
		# Caverna (onde você começou) e o tronco na saída para a área 2.
		var cave: Vector2 = view.to_map(world.cliffs.cave_mouth() * 0.98)
		draw_circle(cave, 12.0, DARK)
		draw_arc(cave, 12.0, 0, TAU, 32, UT.SAND, 1.5, true)
		Glyphs.paint(self, "cave", cave + Vector2(0, -1), 7.5, UT.SAND)
		var ex: Vector2 = view.to_map(world.cliffs.exit_center(0.0) * 0.98)
		var er := Rect2(ex - Vector2(15, 12), Vector2(30, 24))
		draw_rect(er, Color(0.05, 0.035, 0.028, 0.86))
		draw_rect(er.grow(-0.75), UT.LEAF if world.exit_open else UT.TERRACOTTA, false, 1.5)
		Glyphs.paint(self, "log", ex, 9.0, Color("a8704a"))
		# Formigueiros.
		for n in world.nests:
			_nest(n)
		# Câmaras do campo que você já viu (ou farejou).
		for n in world.nests:
			for ch in n.chambers:
				if not ch.satellite or not _seen(ch.pos2):
					continue
				var p: Vector2 = view.to_map(ch.pos2)
				if not ch.opened:
					draw_circle(p, 7.0, Color(UT.PALE, 0.22))
					_diamond(p, 5.0, UT.PALE)
				elif ch.residents > 0:
					_diamond(p, 5.0, gold)
				else:
					_diamond_outline(p, 4.5, UT.LEAF)
		# Para onde fica o cupinzeiro gigante (além da saída).
		var gd := Vector2(cos(GiantMound.ANGLE), sin(GiantMound.ANGLE))
		var a0 := c + gd * (r + 16.0)
		var a1 := c + gd * (r + 40.0)
		draw_line(a0, a1, gold, 2.5, true)
		draw_line(a1, a1 - gd.rotated(0.55) * 9.0, gold, 2.5, true)
		draw_line(a1, a1 - gd.rotated(-0.55) * 9.0, gold, 2.5, true)
		Glyphs.paint(self, "peak", c + gd * (r + 66.0), 15.0, Color(gold, 0.85))
		# Você: a setinha e o que você está vendo.
		var pl = view.player
		if pl:
			var pp: Vector2 = view.to_map(Vector2(pl.global_position.x, pl.global_position.z))
			var fwd := Vector2(-sin(pl.yaw), -cos(pl.yaw))
			var cone := PackedVector2Array([pp])
			for i in 9:
				cone.append(pp + fwd.rotated(lerpf(-0.55, 0.55, i / 8.0)) * 46.0)
			draw_colored_polygon(cone, Color(UT.PALE, 0.2))
			var pulse := fmod(view.time * 0.8, 1.0)
			draw_arc(pp, 9.0 + pulse * 14.0, 0, TAU, 32, Color(UT.PALE, 0.5 * (1.0 - pulse)), 1.5, true)
			var ang := fwd.angle()
			var arrow := PackedVector2Array()
			for q in [Vector2(12, 0), Vector2(-8, -8), Vector2(-3, 0), Vector2(-8, 8)]:
				arrow.append(pp + (q as Vector2).rotated(ang))
			draw_colored_polygon(arrow, UT.PALE)
			arrow.append(arrow[0])
			draw_polyline(arrow, Color(0.04, 0.028, 0.022), 1.5, true)
		_panel()
		# Voltar.
		var br := _back_rect()
		var kf: Font = UT.display_bold_font()
		var kr := Rect2(br.position + Vector2(0, 4), Vector2(42, 22))
		draw_rect(kr, Color(0.04, 0.028, 0.024, 0.85))
		draw_rect(kr.grow(-0.5), Color(gold, 0.85), false, 1.0)
		_text(kf, kr.position + Vector2(kr.size.x * 0.5, 16.0), "Tab", 14, gold, true)
		_text(UT.semi_font(), Vector2(kr.end.x + 9.0, kr.position.y + 16.5), "Voltar", 17, UT.SAND)

	## Formigueiro: limpo (verde, com flores), começado (dourado, com as câmaras
	## embaixo) ou ainda não visitado (tracejado).
	func _nest(n) -> void:
		var p: Vector2 = view.to_map(n.center2)
		var r := 14.0 if n.big else 12.5
		var gold := UT.GOLD
		if n.cleaned:
			draw_circle(p, r, DARK)
			draw_arc(p, r, 0, TAU, 32, UT.LEAF, 2.0, true)
			Glyphs.paint(self, "bloom", p + Vector2(0, -1), r * 0.62, UT.LEAF)
		elif _seen(n.center2):
			draw_circle(p, r, DARK)
			draw_arc(p, r, 0, TAU, 32, gold, 2.0, true)
			Glyphs.paint(self, "mound", p + Vector2(0, -1), r * 0.6, gold)
			var total: int = n.chambers.size()
			var done: int = n.clean_chambers()
			var w := total * 8.0 + 4.0
			var y := p.y + r + 8.0
			draw_rect(Rect2(Vector2(p.x - w * 0.5, y - 5.5), Vector2(w, 11.0)), Color(0.04, 0.028, 0.022, 0.75))
			var x := p.x - w * 0.5 + 6.0
			for i in total:
				if i < done:
					_diamond(Vector2(x, y), 3.3, UT.LEAF)
				else:
					_diamond_outline(Vector2(x, y), 3.0, gold)
				x += 8.0
		else:
			for k in 12:
				var a := TAU * k / 12.0
				draw_arc(p, r, a, a + TAU / 24.0, 4, Color(gold, 0.55), 1.5, true)
			Glyphs.paint(self, "mound", p + Vector2(0, -1), r * 0.55, Color(gold, 0.4))

	## Painel com formigueiros limpos, câmaras limpas e quanto você já explorou.
	func _panel() -> void:
		var c: Vector2 = view.center
		var w := 300.0
		var h := 212.0
		var x := minf(c.x + view.radius + 90.0, size.x - w - 24.0)
		var rect := Rect2(Vector2(x, c.y - h * 0.5 - 30.0), Vector2(w, h))
		var gold := UT.GOLD
		draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]), PackedColorArray([Color(0.063, 0.043, 0.035, 0.93),
			Color(0.063, 0.043, 0.035, 0.93), Color(0.031, 0.024, 0.02, 0.93), Color(0.031, 0.024, 0.02, 0.93)]))
		draw_rect(rect.grow(-0.5), Color(gold, 0.8), false, 1.0)
		draw_rect(rect.grow(-4.5), Color(gold, 0.25), false, 1.0)
		var rows := [
			["bloom", Color("8fb86a"), view.nests_text, UT.LEAF],
			["mound", gold, view.chambers_text, UT.PALE],
			["eye", UT.SAND, view.explored_text, UT.SAND],
		]
		var f: Font = UT.display_font()
		for i in rows.size():
			var row: Array = rows[i]
			var cy := rect.position.y + 46.0 + i * 60.0
			Glyphs.paint(self, row[0], Vector2(rect.position.x + 44.0, cy), 15.0, row[1])
			draw_string(f, Vector2(rect.position.x + 78.0, cy + 11.0), row[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, row[3])
