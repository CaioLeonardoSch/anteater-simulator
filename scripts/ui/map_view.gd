extends Control
## Aba do mapa (TAB): o mapa inteiro do jogo. A área 1 (a clareira) é uma foto
## vista de cima, colorida onde você já andou e em sépia escura onde ainda não;
## as áreas 2, 3 e 4 ficam pretas, com cadeado. A roda do mouse aproxima (até a
## clareira encher a tela) e afasta (até caber o mapa inteiro); arrastando, o
## mapa anda. Passando o mouse num formigueiro, a área dele fica mais clara.
## A saída da clareira aponta para cima e para a direita (WorldMap).

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Exploration := preload("res://scripts/world/exploration.gd")
const WorldMap := preload("res://scripts/world/world_map.gd")
const Glyphs := preload("res://scripts/ui/glyphs.gd")

## Resolução da foto de cima.
const SHOT_SIZE := 1024
## Largura da legenda (à direita) e espaço livre em volta do mapa.
const LEGEND_W := 176.0
const MARGIN := 34.0
const TOP := 92.0
const BOTTOM := 64.0
## Até onde os formigueiros dividem a clareira (o resto são os paredões).
const TERRITORY_RADIUS := 63.0

const MAP_SHADER := """
shader_type canvas_item;
uniform sampler2D shot : filter_linear_mipmap;
uniform sampler2D fog : filter_linear;
uniform vec2 port_size = vec2(1000.0, 700.0);
uniform vec2 focus = vec2(0.0);
uniform float zoom = 4.0;
uniform float rot = 0.0;
uniform float world_size = 150.0;
uniform float area_radius = 74.0;
uniform float territory_radius = 63.0;
uniform vec2 nests[16];
uniform int nest_count = 0;
uniform int hover = -1;
void fragment() {
	vec2 m = focus + (UV * port_size - port_size * 0.5) / zoom;
	float c = cos(rot);
	float s = sin(rot);
	vec2 w = vec2(c * m.x + s * m.y, -s * m.x + c * m.y);
	float r = length(w);
	vec2 suv = w / world_size + 0.5;
	vec3 col = texture(shot, suv).rgb;
	float seen = smoothstep(0.2, 0.7, texture(fog, suv).r);
	float l = dot(col, vec3(0.3, 0.55, 0.15));
	vec3 sepia = vec3(0.62, 0.47, 0.32) * (0.1 + l * 0.52);
	col = mix(sepia, col, seen);
	// Formigueiro com o mouse em cima: a parte da clareira mais perto dele que
	// de qualquer outro fica mais clara.
	if (hover >= 0 && r < territory_radius) {
		int best = -1;
		float bd = 1e9;
		for (int i = 0; i < nest_count; i++) {
			float d = distance(w, nests[i]);
			if (d < bd) {
				bd = d;
				best = i;
			}
		}
		if (best == hover) {
			float fade = 1.0 - smoothstep(territory_radius - 4.0, territory_radius, r);
			col = mix(col, vec3(1.0, 0.97, 0.9), 0.26 * fade);
		}
	}
	col *= mix(1.0, 0.75, smoothstep(area_radius * 0.86, area_radius, r));
	float aa = 1.5 / zoom;
	COLOR = vec4(col, 1.0 - smoothstep(area_radius - aa, area_radius, r));
}
"""

var player
var world
var colony
var exploration
## Retângulo do mapa na tela.
var port := Rect2()
## Pixels por metro e o ponto do mapa (WorldMap) que fica no meio do retângulo.
var zoom := 4.0
var focus := Vector2.ZERO
var time := 0.0
## Formigueiro com o mouse em cima (-1 = nenhum).
var hover_nest := -1
## Números da legenda (atualizados ao abrir).
var nests_text := ""
var chambers_text := ""
var insects_text := ""
var _port: Port
var _map_rect: ColorRect
var _mat: ShaderMaterial
var _overlay: MapOverlay
var _shot_started := false
var _zoom_ready := false
var _dragging := false
var _right_from := Vector2(-999, -999)
var _joy_y := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_port = Port.new()
	_port.view = self
	_port.clip_contents = true
	_port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_port)
	_map_rect = ColorRect.new()
	_map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = MAP_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("world_size", Exploration.WORLD_SIZE)
	_mat.set_shader_parameter("area_radius", WorldMap.AREA1_RADIUS)
	_mat.set_shader_parameter("territory_radius", TERRITORY_RADIUS)
	_mat.set_shader_parameter("rot", WorldMap.ROTATION)
	var dark := Image.create(4, 4, false, Image.FORMAT_RGB8)
	dark.fill(Color(0.1, 0.075, 0.055))
	_mat.set_shader_parameter("shot", ImageTexture.create_from_image(dark))
	_map_rect.material = _mat
	_port.add_child(_map_rect)
	_overlay = MapOverlay.new()
	_overlay.view = self
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_port.add_child(_overlay)
	resized.connect(_layout)
	_layout()


func setup(p, w, c, e) -> void:
	player = p
	world = w
	colony = c
	exploration = e
	var pts := PackedVector2Array()
	for n in world.nests:
		pts.append(n.center2)
	_mat.set_shader_parameter("nests", pts)
	_mat.set_shader_parameter("nest_count", pts.size())


func _layout() -> void:
	var w := maxf(size.x - 2.0 * (LEGEND_W + MARGIN * 1.5), 320.0)
	var h := maxf(size.y - TOP - BOTTOM, 240.0)
	port = Rect2(Vector2((size.x - w) * 0.5, TOP), Vector2(w, h))
	_port.position = port.position
	_port.size = port.size
	_map_rect.size = port.size
	_overlay.size = port.size
	if not _zoom_ready and port.size.y > 0.0:
		_zoom_ready = true
		zoom = zoom_max()
		focus = Vector2.ZERO
	_set_view(zoom, focus)
	queue_redraw()


## Mais perto: a clareira enche a altura do mapa.
func zoom_max() -> float:
	return port.size.y * 0.49 / WorldMap.AREA1_RADIUS


## Mais longe: o mapa inteiro cabe.
func zoom_min() -> float:
	var b := WorldMap.bounds()
	return minf(minf(port.size.x / b.size.x, port.size.y / b.size.y) * 0.96, zoom_max())


## 0 = mapa inteiro, 1 = só a clareira.
func zoom_amount() -> float:
	var a := zoom_min()
	var b := zoom_max()
	return 1.0 if b - a < 0.0001 else clampf((zoom - a) / (b - a), 0.0, 1.0)


func _set_view(z: float, f: Vector2) -> void:
	zoom = clampf(z, zoom_min(), zoom_max())
	# O meio do retângulo não sai de cima do mapa (no mais longe, o mapa
	# inteiro fica no meio).
	var b := WorldMap.bounds()
	var t := zoom_amount()
	f = f.clamp(b.position, b.end)
	focus = b.get_center().lerp(f, clampf(t * 4.0, 0.0, 1.0))
	_mat.set_shader_parameter("port_size", port.size)
	_mat.set_shader_parameter("focus", focus)
	_mat.set_shader_parameter("zoom", zoom)
	_port.queue_redraw()
	_overlay.queue_redraw()


## Aproxima (factor > 1) ou afasta, mantendo parado o ponto embaixo de `at`
## (coordenadas do retângulo do mapa).
func zoom_at(factor: float, at: Vector2) -> void:
	var under := focus + (at - port.size * 0.5) / zoom
	var z := clampf(zoom * factor, zoom_min(), zoom_max())
	_set_view(z, under - (at - port.size * 0.5) / z)


## Ponto do mundo (plano xz) no retângulo do mapa.
func world_px(p2: Vector2) -> Vector2:
	return map_px(WorldMap.to_map(p2))


## Ponto do espaço do mapa (WorldMap) no retângulo do mapa.
func map_px(m: Vector2) -> Vector2:
	return port.size * 0.5 + (m - focus) * zoom


func _process(delta: float) -> void:
	if not visible:
		return
	time += delta
	_gamepad(delta)
	_overlay.queue_redraw()


## No controle: o analógico esquerdo move o mapa e o direito (para cima e para
## baixo) aproxima e afasta.
func _gamepad(delta: float) -> void:
	var pan := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if pan.length() > 0.2:
		_set_view(zoom, focus + pan * delta * 420.0 / zoom)
	var y_now := Input.is_joy_button_pressed(0, JOY_BUTTON_Y)
	if y_now and not _joy_y:
		toggle_marker(port.size * 0.5)
	_joy_y = y_now
	var z := -Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(z) > 0.25:
		zoom_at(pow(2.2, z * delta), port.size * 0.5)
		_update_hover(port.size * 0.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var local: Vector2 = event.position - port.position
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(1.18, local)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(1.0 / 1.18, local)
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _back_rect().has_point(event.position):
				accept_event()
				closed.emit()
				return
			_dragging = event.pressed and port.has_point(event.position)
			# Clique com o botão direito (sem arrastar): põe ou tira o marcador.
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_right_from = event.position
				elif _right_from.distance_to(event.position) < 6.0 and port.has_point(event.position):
					toggle_marker(event.position - port.position)
			accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			_set_view(zoom, focus - event.relative / zoom)
		_update_hover(event.position - port.position)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
		zoom_at(1.25, port.size * 0.5)
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
		zoom_at(0.8, port.size * 0.5)
		get_viewport().set_input_as_handled()


## Ponto do retângulo do mapa no mundo (plano xz).
func px_world(local: Vector2) -> Vector2:
	return WorldMap.to_world(focus + (local - port.size * 0.5) / zoom)


## Põe o marcador onde clicou; clicar perto dele tira o marcador.
func toggle_marker(local: Vector2) -> void:
	var m: Vector2 = GameState.marker
	if m != Vector2.INF and world_px(m).distance_to(local) < 14.0:
		GameState.marker = Vector2.INF
		Sfx.play("ui_click", -8.0, 0.8)
	else:
		GameState.marker = px_world(local)
		Sfx.play("ui_click", -6.0, 1.2)
	_overlay.queue_redraw()


func _update_hover(local: Vector2) -> void:
	if DevTools.args.has("maphover"):
		return
	var best := -1
	if world != null and Rect2(Vector2.ZERO, port.size).has_point(local):
		var reach := 8.0 + 8.0 * icon_scale()
		var bd := reach * reach
		for k in world.nests.size():
			var d := world_px(world.nests[k].center2).distance_squared_to(local)
			if d < bd:
				bd = d
				best = k
	if best != hover_nest:
		hover_nest = best
		_mat.set_shader_parameter("hover", best)
		if best >= 0:
			Sfx.play("ui_hover", -16.0, 1.0, 0.05)
		_overlay.queue_redraw()


## Tamanho dos ícones: menores com o mapa afastado.
func icon_scale() -> float:
	return lerpf(0.45, 1.0, zoom_amount())


## Abre a aba: atualiza a névoa e os números.
func open() -> void:
	visible = true
	take_shot()
	if exploration:
		_mat.set_shader_parameter("fog", exploration.texture())
	var done := 0
	var total := 0
	for n in world.nests:
		total += n.chambers.size()
		done += n.clean_chambers()
	chambers_text = "%d/%d" % [done, total]
	nests_text = "%d/%d" % [colony.nests_cleaned(), world.nests.size()]
	insects_text = MapOverlay._thousands(colony.remaining())
	hover_nest = -1
	_mat.set_shader_parameter("hover", -1)
	_dragging = false
	# Teste (capturas): zoom (0 = mapa inteiro, 1 = clareira) e um formigueiro em destaque.
	if DevTools.args.has("mapzoom"):
		_set_view(lerpf(zoom_min(), zoom_max(), float(DevTools.args.mapzoom)), focus)
	if DevTools.args.has("maphover"):
		hover_nest = int(DevTools.args.maphover)
		_mat.set_shader_parameter("hover", hover_nest)
	queue_redraw()
	_overlay.queue_redraw()


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


func _back_rect() -> Rect2:
	return Rect2(Vector2(port.end.x - 112.0, port.end.y + 18.0), Vector2(112, 30))


## Fundo, moldura do mapa, a legenda (à direita) e as teclas embaixo.
func _draw() -> void:
	var gold := UiTheme.GOLD
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.043, 0.031, 0.027))
	var frame := port.grow(6.0)
	draw_rect(port.grow(18.0), Color(gold, 0.03))
	draw_rect(frame, Color(0.05, 0.035, 0.028, 0.95), false, 7.0)
	draw_rect(port.grow(1.5), gold, false, 2.0)
	draw_rect(port.grow(9.5), Color(gold, 0.35), false, 1.0)
	_legend(Vector2(port.end.x + MARGIN, port.position.y + 4.0))
	# Teclas: zoom e mover, à esquerda; voltar, à direita.
	var y := port.end.y + 18.0
	var x := _key(Vector2(port.position.x, y), "Roda", "zoom")
	x = _key(Vector2(x + 18.0, y), "Arrastar", "mover")
	_key(Vector2(x + 18.0, y), "Botão direito", "marcar")
	_key(_back_rect().position, "Tab", "Voltar")


## Uma tecla (chip dourado) e o que ela faz. Retorna onde o texto termina.
func _key(at: Vector2, key: String, what: String) -> float:
	var gold := UiTheme.GOLD
	var kf: Font = UiTheme.display_bold_font()
	var kw := kf.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0
	var kr := Rect2(at + Vector2(0, 4), Vector2(kw, 22))
	draw_rect(kr, Color(0.04, 0.028, 0.024, 0.85))
	draw_rect(kr.grow(-0.5), Color(gold, 0.85), false, 1.0)
	draw_string(kf, kr.position + Vector2(8.0, 16.0), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)
	var f: Font = UiTheme.semi_font()
	draw_string(f, Vector2(kr.end.x + 8.0, kr.position.y + 16.5), what, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UiTheme.SAND)
	return kr.end.x + 8.0 + f.get_string_size(what, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x


## Legenda: o que é cada ícone, com uma palavra só (e os números, quando há).
func _legend(at: Vector2) -> void:
	var gold := UiTheme.GOLD
	var rows := [
		["mound", gold, "Formigueiros", nests_text],
		["diamond", UiTheme.PALE, "Câmaras", chambers_text],
		["cave", UiTheme.SAND, "Caverna", ""],
		["player", UiTheme.PALE, "Jogador", ""],
		["lock", UiTheme.SAND, "Fechada", ""],
		["ant", UiTheme.SAND, "Insetos", insects_text],
		["pin", UiTheme.PALE, "Marcador", ""],
	]
	var row_h := 34.0
	var rect := Rect2(at, Vector2(LEGEND_W, 18.0 + rows.size() * row_h))
	draw_rect(rect, Color(0.055, 0.04, 0.032, 0.93))
	draw_rect(rect.grow(-0.5), Color(gold, 0.7), false, 1.0)
	var f: Font = UiTheme.semi_font()
	var nf: Font = UiTheme.display_font()
	for i in rows.size():
		var row: Array = rows[i]
		var cy := rect.position.y + 9.0 + row_h * (i + 0.5)
		var ic := Vector2(rect.position.x + 22.0, cy)
		if row[0] == "player":
			MapOverlay.player_arrow(self, ic, -PI * 0.5, 0.75)
		elif row[0] == "diamond":
			MapOverlay.diamond(self, ic, 5.0, row[1])
		else:
			Glyphs.paint(self, row[0], ic, 8.0, row[1])
		draw_string(f, Vector2(rect.position.x + 40.0, cy + 6.0), row[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiTheme.SAND)
		if row[3] != "":
			var tw := nf.get_string_size(row[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(nf, Vector2(rect.end.x - 12.0 - tw, cy + 6.0), row[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiTheme.PALE)


## O retângulo do mapa: fundo e as áreas fechadas (pretas, com o paredão em
## volta e um cadeado). A foto da clareira e os ícones vão por cima.
class Port extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	const WM := preload("res://scripts/world/world_map.gd")
	const GL := preload("res://scripts/ui/glyphs.gd")
	## Largura do paredão em volta das áreas (m).
	const BAND := 10.0
	const ROCK := Color(0.42, 0.29, 0.2)
	const FILL := Color(0.018, 0.013, 0.011)
	var view

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.022, 0.019))
		# Uma trama leve no fundo (fora das áreas é o planalto, sem caminho).
		var z: float = view.zoom
		var step := 40.0 * z
		while step < 26.0:
			step *= 2.0
		var o: Vector2 = view.map_px(Vector2.ZERO)
		var x0 := fposmod(o.x, step)
		var y0 := fposmod(o.y, step)
		var x := x0
		while x < size.x:
			var y := y0
			while y < size.y:
				draw_circle(Vector2(x, y), 1.0, Color(1.0, 0.85, 0.65, 0.06))
				y += step
			x += step
		# Paredões (por baixo), depois o chão preto das áreas por cima: onde as
		# áreas se juntam, o paredão some.
		_blob(Vector2.ZERO, WM.AREA1_RADIUS + BAND, ROCK, 0)
		for a in WM.AREAS:
			if a.id != 4:
				_blob(a.center, a.radius + BAND, ROCK, a.id)
		for p in WM.PASSES:
			_capsule(p[0], p[1], p[2] + BAND, ROCK)
		for a in WM.AREAS:
			if a.id != 4:
				_blob(a.center, a.radius, FILL, a.id)
		for p in WM.PASSES:
			_capsule(p[0], p[1], p[2], FILL)
		# Área 4: o cupinzeiro gigante, dentro da área 3.
		var a4: Dictionary = WM.AREAS[2]
		_blob(a4.center, a4.radius, Color(0.045, 0.03, 0.024), 4)
		_blob_line(a4.center, a4.radius, Color(ROCK, 0.9), 4)
		# Cadeados e os números das áreas.
		var s: float = view.icon_scale()
		var df: Font = UT.display_font()
		for a in WM.AREAS:
			var p: Vector2 = view.map_px(a.label)
			if not Rect2(Vector2.ZERO, size).grow(30).has_point(p):
				continue
			var r := 20.0 * s + 4.0
			draw_circle(p, r, Color(0.07, 0.05, 0.04))
			draw_arc(p, r, 0, TAU, 32, Color(UT.GOLD, 0.6), 1.5, true)
			GL.paint(self, "lock", p, r * 0.55, UT.SAND)
			var num := str(a.id)
			var fs := int(14.0 + 6.0 * s)
			var tw := df.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(df, p + Vector2(-tw * 0.5, r + fs + 2.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UT.SAND, 0.8))

	## Círculo um pouco torto (como desenhado à mão), no espaço do mapa.
	func _blob_points(c: Vector2, r: float, seed: int) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var n := 72
		for i in n:
			var a := TAU * i / n
			var k := 1.0 + 0.03 * sin(a * 3.0 + seed * 1.7) + 0.02 * sin(a * 7.0 + seed * 2.9)
			pts.append(view.map_px(c + Vector2(cos(a), sin(a)) * r * k))
		return pts

	func _blob(c: Vector2, r: float, col: Color, seed: int) -> void:
		draw_colored_polygon(_blob_points(c, r, seed), col)

	func _blob_line(c: Vector2, r: float, col: Color, seed: int) -> void:
		var pts := _blob_points(c, r, seed)
		pts.append(pts[0])
		draw_polyline(pts, col, 2.0, true)

	## Passagem: um retângulo de pontas redondas entre dois pontos do mapa.
	func _capsule(a: Vector2, b: Vector2, half: float, col: Color) -> void:
		var pa: Vector2 = view.map_px(a)
		var pb: Vector2 = view.map_px(b)
		var w: float = half * view.zoom
		var d := (pb - pa).normalized().orthogonal() * w
		draw_colored_polygon(PackedVector2Array([pa + d, pb + d, pb - d, pa - d]), col)
		draw_circle(pa, w, col)
		draw_circle(pb, w, col)


## Tudo o que vai por cima da foto: a borda da clareira, a caverna, os
## formigueiros, as câmaras do campo já vistas e você.
class MapOverlay extends Control:
	const UT := preload("res://scripts/ui/ui_theme.gd")
	const GL := preload("res://scripts/ui/glyphs.gd")
	const WM := preload("res://scripts/world/world_map.gd")
	const DARK := Color(0.05, 0.035, 0.028, 0.82)
	var view

	static func diamond(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), col)

	static func diamond_outline(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
		ci.draw_polyline(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0),
			p + Vector2(0, -r)]), col, 1.3, true)

	## A setinha do jogador, apontando para `ang` (radianos, na tela).
	static func player_arrow(ci: CanvasItem, p: Vector2, ang: float, s: float) -> void:
		var arrow := PackedVector2Array()
		for q in [Vector2(12, 0), Vector2(-8, -8), Vector2(-3, 0), Vector2(-8, 8)]:
			arrow.append(p + (q as Vector2).rotated(ang) * s)
		ci.draw_colored_polygon(arrow, UT.PALE)
		arrow.append(arrow[0])
		ci.draw_polyline(arrow, Color(0.04, 0.028, 0.022), 1.5, true)

	func _seen(p2: Vector2) -> bool:
		return view.exploration == null or view.exploration.explored_at(p2) > 0.4

	func _draw() -> void:
		if view == null or view.world == null:
			return
		var world = view.world
		var s: float = view.icon_scale()
		var gold := UT.GOLD
		# Borda dourada da clareira.
		var c0: Vector2 = view.map_px(Vector2.ZERO)
		var ar: float = WM.AREA1_RADIUS * view.zoom
		draw_arc(c0, ar + 1.0, 0, TAU, 128, Color(gold, 0.55), 1.5, true)
		# Caverna (onde você começou).
		var cave: Vector2 = view.world_px(world.cliffs.cave_mouth() * 0.98)
		var cr := 12.0 * s
		draw_circle(cave, cr, DARK)
		draw_arc(cave, cr, 0, TAU, 32, UT.SAND, 1.5, true)
		GL.paint(self, "cave", cave + Vector2(0, -1), cr * 0.62, UT.SAND)
		# Formigueiros (com o mapa bem afastado, só a foto).
		if s > 0.55:
			for k in world.nests.size():
				_nest(world.nests[k], k == view.hover_nest, s)
		# Câmaras do campo que você já viu (ou farejou).
		if s > 0.6:
			for n in world.nests:
				for ch in n.chambers:
					if not ch.satellite or not _seen(ch.pos2):
						continue
					var p: Vector2 = view.world_px(ch.pos2)
					if not ch.opened:
						draw_circle(p, 7.0 * s, Color(UT.PALE, 0.22))
						diamond(self, p, 5.0 * s, UT.PALE)
					elif ch.residents > 0:
						diamond(self, p, 5.0 * s, gold)
					else:
						diamond_outline(self, p, 4.5 * s, UT.LEAF)
		# Marcador que você pôs.
		if GameState.marker != Vector2.INF:
			var mp: Vector2 = view.world_px(GameState.marker)
			var bob := sin(view.time * 3.0) * 2.0
			draw_circle(mp, 4.0, Color(0, 0, 0, 0.35))
			GL.paint(self, "pin", mp + Vector2(0, -13.0 + bob), 15.0, UT.PALE)
		# Você: a setinha e o que você está vendo.
		var pl = view.player
		if pl:
			var pp: Vector2 = view.world_px(Vector2(pl.global_position.x, pl.global_position.z))
			var fwd := WM.to_map(Vector2(-sin(pl.yaw), -cos(pl.yaw)))
			var cone := PackedVector2Array([pp])
			for i in 9:
				cone.append(pp + fwd.rotated(lerpf(-0.55, 0.55, i / 8.0)) * 46.0 * s)
			draw_colored_polygon(cone, Color(UT.PALE, 0.2))
			var pulse := fmod(view.time * 0.8, 1.0)
			draw_arc(pp, (9.0 + pulse * 14.0) * s, 0, TAU, 32, Color(UT.PALE, 0.5 * (1.0 - pulse)), 1.5, true)
			player_arrow(self, pp, fwd.angle(), maxf(s, 0.7))

	## Formigueiro: limpo (verde, com flores), começado (dourado, com as câmaras
	## embaixo) ou ainda não visitado (tracejado).
	func _nest(n, hot: bool, s: float) -> void:
		var p: Vector2 = view.world_px(n.center2)
		var r := (14.0 if n.big else 12.5) * s
		var gold := UT.GOLD
		if hot:
			draw_circle(p, r + 7.0, Color(1.0, 0.97, 0.9, 0.18))
			draw_arc(p, r + 4.0, 0, TAU, 40, Color(1.0, 0.97, 0.9, 0.9), 2.0, true)
		if n.cleaned:
			draw_circle(p, r, DARK)
			draw_arc(p, r, 0, TAU, 32, UT.LEAF, 2.0, true)
			GL.paint(self, "bloom", p + Vector2(0, -1), r * 0.62, UT.LEAF)
		elif _seen(n.center2) or hot:
			draw_circle(p, r, DARK)
			draw_arc(p, r, 0, TAU, 32, gold, 2.0, true)
			GL.paint(self, "mound", p + Vector2(0, -1), r * 0.6, gold)
		else:
			for k in 12:
				var a := TAU * k / 12.0
				draw_arc(p, r, a, a + TAU / 24.0, 4, Color(gold, 0.55), 1.5, true)
			GL.paint(self, "mound", p + Vector2(0, -1), r * 0.55, Color(gold, 0.4))
		if n.cleaned or s < 0.6 or not (_seen(n.center2) or hot):
			return
		# Câmaras desse formigueiro (as do monte e as do campo em volta).
		var total: int = n.chambers.size()
		var done: int = n.clean_chambers()
		var y := p.y + r + 8.0
		if total <= 9:
			var w := total * 8.0 + 4.0
			draw_rect(Rect2(Vector2(p.x - w * 0.5, y - 5.5), Vector2(w, 11.0)), Color(0.04, 0.028, 0.022, 0.75))
			var x := p.x - w * 0.5 + 6.0
			for i in total:
				if i < done:
					diamond(self, Vector2(x, y), 3.3, UT.LEAF)
				else:
					diamond_outline(self, Vector2(x, y), 3.0, gold)
				x += 8.0
		else:
			var f: Font = UT.display_bold_font()
			var txt := "%d/%d" % [done, total]
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var w := tw + 24.0
			draw_rect(Rect2(Vector2(p.x - w * 0.5, y - 7.5), Vector2(w, 15.0)), Color(0.04, 0.028, 0.022, 0.8))
			diamond_outline(self, Vector2(p.x - w * 0.5 + 9.0, y), 3.0, gold)
			draw_string(f, Vector2(p.x - w * 0.5 + 17.0, y + 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UT.PALE)
		# Quantos insetos ainda faltam neste formigueiro (trilha, passeio, câmaras e rainha).
		var nf: Font = UT.display_bold_font()
		var cnt := _thousands(n.remaining())
		var cw := nf.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 22.0
		var cy := y + 14.0
		draw_rect(Rect2(Vector2(p.x - cw * 0.5, cy - 7.5), Vector2(cw, 15.0)), Color(0.04, 0.028, 0.022, 0.8))
		GL.paint(self, "ant", Vector2(p.x - cw * 0.5 + 9.0, cy), 5.5, UT.SAND)
		draw_string(nf, Vector2(p.x - cw * 0.5 + 17.0, cy + 5.0), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UT.PALE)

	## 12345 -> "12 345"
	static func _thousands(v: int) -> String:
		var t := str(v)
		var out := ""
		while t.length() > 3:
			out = " " + t.substr(t.length() - 3) + out
			t = t.substr(0, t.length() - 3)
		return t + out
