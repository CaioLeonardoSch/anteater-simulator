extends Node3D
## Formigueiro de saúvas: um monte de terra fofa com olheiros (por onde as
## formigas das trilhas entram e saem) e câmaras fechadas, onde moram as
## outras. Cavar abre uma câmara. Nos formigueiros grandes, a rainha mora bem
## no fundo: cavar o topo do monte (Escavação Real) desmancha o monte inteiro e
## fica um buraco com a rainha e a corte dela lá embaixo. Cada buraco pede um
## nível de Cavar (pequeno, câmara grande, o monte da rainha) e tem a cara do
## nível: panela rasa, panela funda com as camadas de terra, ou o buracão em
## degraus com câmaras cortadas na parede. Quando tudo é
## comido, o monte floresce.
## O tamanduá pode subir no monte (o chão acompanha a forma dele).
## Se existir assets/models/formigueiro.glb, ele substitui o monte feito por código.

const MeshBuilder := preload("res://scripts/procedural/mesh_builder.gd")
const ModelLibrary := preload("res://scripts/model_library.gd")
const Props := preload("res://scripts/world/props.gd")
const DirtFx := preload("res://scripts/world/dirt_fx.gd")

const QUEEN_VALUE := 200
## Tamanho dos buracos (o nível de Cavar que cada um pede).
const SMALL := 1
const LARGE := 2
const ROYAL := 3
## Cor da tampa de cada tamanho: as mais fundas são mais escuras, entre a
## terra fofa das pequenas e a cor do monte.
const CAP_TINT := [Color.WHITE, Color.WHITE, Color(0.84, 0.75, 0.69), Color(0.76, 0.65, 0.58)]
## Buraco do monte desmanchado: raio da crista da borda (parte do raio do
## monte), altura da borda (parte da altura do monte) e o fundo (m; um pouco
## acima do chão, para o chão do campo não cobrir o fundo escuro). A parede
## desce em dois degraus, com um patamar no meio.
const CRATER_RIM := 0.74
const CRATER_RIM_HEIGHT := 0.5
const CRATER_FLOOR := 0.03
## Cores das camadas de terra que aparecem na parede de um buraco, de cima
## para baixo (só o tom; o brilho vem à parte): a terra escura de cima, a
## vermelha e a amarelada lá do fundo.
const LAYER_TOP := Color(0.68, 0.9, 1.2)
const LAYER_RED := Color(1.15, 0.85, 0.8)
const LAYER_YELLOW := Color(0.88, 1.22, 0.55)


class Chamber extends RefCounted:
	var local := Vector2.ZERO
	var pos2 := Vector2.ZERO
	var radius := 0.4
	## Moradoras que ainda não foram comidas (dentro da câmara, aberta ou não).
	var residents := 0
	## Moradoras que estão à vista agora (o resto sai do túnel aos poucos).
	var shown := 0
	## Câmara do campo: formigas que saem dela, passeiam e voltam (as que
	## ainda não foram comidas) e até onde elas vão (m).
	var roamers := 0
	var roam_reach := 0.0
	var opened := false
	var royal := false
	## Câmara da rainha: até onde as formigas andam depois que o monte é
	## desmanchado (o buraco é bem maior que a tampa).
	var pit_radius := 0.0
	## Câmara no meio do campo, longe do monte (é deste formigueiro, mas fica sozinha).
	var satellite := false
	## Buraco comprido na direção `axis` (radianos, no plano xz), com meio
	## comprimento `half_len`; 0 = câmara redonda (todas, por enquanto).
	var axis := 0.0
	var half_len := 0.0
	## Nível de Cavar que o buraco pede (SMALL, LARGE ou ROYAL).
	var size_class := 1

	## Até onde as moradoras andam dentro do buraco aberto.
	func area_radius() -> float:
		return pit_radius if pit_radius > 0.0 else radius

	## Distância de p2 até a beirada do buraco (negativa dentro dele).
	func edge_distance(p2: Vector2) -> float:
		if half_len <= 0.0:
			return p2.distance_to(pos2) - radius
		var ax := Vector2(cos(axis), sin(axis))
		var t := clampf((p2 - pos2).dot(ax), -half_len, half_len)
		return p2.distance_to(pos2 + ax * t) - radius
	var cap: Node3D
	var pit: Node3D


var index := 0
var display_name := "Formigueiro"
var radius := 1.8
var height := 0.62
var center2 := Vector2.ZERO
var big := false
## Formigueiro médio: câmaras grandes (Fundura 1), sem rainha.
var medium := false
## Direções (no plano xz) das trilhas que saem daqui.
var trail_dirs: Array[Vector2] = []
var trail_ids: Array[int] = []
var hole_distance := 0.0

var chambers: Array[Chamber] = []
## Forrageiras das trilhas deste formigueiro que ainda não foram comidas.
var pool := 0
var queen_alive := false
var cleaned := false
## O monte foi desmanchado (sobrou o buraco da rainha).
var dug_out := false
var used_ai_model := false

## Altura do chão (terreno + montes), dada pelo mundo: as câmaras do campo
## ficam no chão de verdade, e não na altura do monte.
var ground: Callable
var _noise := FastNoiseLite.new()
var _mats
var _flowers: MultiMeshInstance3D
var _flower_bases: Array[Transform3D] = []
var _dig_shake := 0.0
var _mound: Node3D
var _collision: StaticBody3D
## Calombos do monte (x, z do centro, raio, altura em partes da altura).
var _lobes: Array[Vector4] = []
## Olheiros do monte (x, z, raio do buraco): os das trilhas e outros menores.
var _olheiros: Array[Vector3] = []


func setup(i: int, nest_name: String, pos2: Vector2, r: float, h: float, is_big: bool, is_medium: bool = false) -> void:
	index = i
	display_name = nest_name
	center2 = pos2
	radius = r
	height = h
	big = is_big
	medium = is_medium and not is_big
	hole_distance = radius * 0.7
	_noise.seed = 100 + i
	_noise.frequency = 0.9
	# Calombos: o monte de saúva é largo e baixo, feito de vários montinhos
	# de terra que se juntaram (gerador próprio: não mexe no resto do mapa).
	var lr := RandomNumberGenerator.new()
	lr.seed = 500 + i
	_lobes.clear()
	for _k in lr.randi_range(3, 4):
		var a := lr.randf() * TAU
		var d := lr.randf_range(0.25, 0.6) * radius
		_lobes.append(Vector4(cos(a) * d, sin(a) * d, lr.randf_range(0.3, 0.45) * radius, lr.randf_range(0.1, 0.2)))


## Altura do monte acima do terreno (as formigas sobem por ele).
func dome_height(x: float, z: float) -> float:
	var lp := Vector2(x - center2.x, z - center2.y)
	var d2 := lp.length_squared()
	var r2 := radius * radius
	if d2 >= r2:
		return 0.0
	if dug_out:
		# Borda irregular, como terra revirada.
		var d := sqrt(d2 / r2)
		return crater_height(d) * (1.0 + _noise.get_noise_2d(lp.x * 1.4, lp.y * 1.4) * 0.3 * smoothstep(0.3, 0.6, d))
	var h := _mound_shape(lp)
	if not used_ai_model:
		for c in chambers:
			if c.opened and not c.satellite and not c.royal:
				h += _pit_offset(c, lp)
	return h


## Buraco do monte desmanchado: fundo no meio, um degrau, um patamar, outro
## degrau e a borda de terra em volta. `d` = distância do centro / raio do monte.
func crater_height(d: float) -> float:
	var rim := height * CRATER_RIM_HEIGHT
	if d < CRATER_RIM:
		var y := CRATER_FLOOR
		y += rim * 0.42 * smoothstep(0.2, 0.36, d)
		y += rim * 0.06 * smoothstep(0.36, 0.48, d)
		y += rim * 0.52 * smoothstep(0.48, CRATER_RIM, d)
		return y
	return (rim + CRATER_FLOOR) * (1.0 - smoothstep(CRATER_RIM, 1.0, d))


## Até onde o monte vai nesta direção (a borda é irregular, nunca passa do raio).
func _edge_radius(lp: Vector2) -> float:
	var a := atan2(lp.y, lp.x)
	return radius * clampf(0.9 + 0.16 * _noise.get_noise_2d(cos(a) * 1.7 + 31.0, sin(a) * 1.7 - 17.0), 0.8, 0.98)


## Forma do monte sem as câmaras abertas: topo largo e achatado, lados que
## caem mais no fim, calombos e ondulações da terra fofa.
func _mound_shape(lp: Vector2) -> float:
	var t := lp.length() / _edge_radius(lp)
	if t >= 1.0:
		return 0.0
	var g := pow(1.0 - pow(t, 2.6), 1.4)
	var lobe := 0.0
	for l in _lobes:
		lobe += l.w * exp(-(lp - Vector2(l.x, l.y)).length_squared() / (l.z * l.z))
	var h := height * (0.88 + lobe) * g
	h += _noise.get_noise_2d(lp.x * 3.0, lp.y * 3.0) * 0.035 * minf(1.0, (1.0 - t) * 5.0)
	return maxf(h, 0.0)


## Medidas do buraco de cada câmara aberta, pelo nível de Cavar que ela pede:
## (fundura, altura da terra tirada em volta, onde começa a parede).
## Rasa (começo do jogo): uma panela pouco funda de parede suave. Funda
## (Fundura 1): parede quase em pé, com as camadas de terra à mostra. As do
## campo não afundam (o chão do campo cobriria o fundo): a terra tirada em
## volta é que faz a panela.
func _pit_dims(c: Chamber) -> Vector3:
	if c.satellite:
		return Vector3(0.0, 0.1, 0.45)
	if c.size_class >= LARGE:
		return Vector3(0.36, 0.12, 0.6)
	return Vector3(0.13, 0.07, 0.42)


## Distância do centro da câmara em partes do raio (a beirada é um pouco torta).
func _pit_t(c: Chamber, lp: Vector2) -> float:
	var v := lp - c.local
	var a := atan2(v.y, v.x)
	var wob := _noise.get_noise_2d(cos(a) * 2.0 + c.local.x * 3.0, sin(a) * 2.0 + c.local.y * 3.0)
	return v.length() / (c.radius * (1.0 + 0.08 * wob))


## Quanto o chão sobe (terra tirada, na beirada) ou desce (a panela) em `lp`.
func _pit_offset(c: Chamber, lp: Vector2) -> float:
	var t := _pit_t(c, lp)
	if t > 1.6:
		return 0.0
	var dims := _pit_dims(c)
	var y := dims.y * exp(-pow((t - 1.07) / 0.15, 2.0))
	if t < 1.0:
		y -= dims.x * (1.0 - smoothstep(dims.z, 1.0, t))
	return y


## Quanto dos insetos da colônia este formigueiro guarda (pequeno = 1).
func share_weight() -> float:
	return 1.75 if big else (1.4 if medium else 1.0)


func hole_position(trail_dir: Vector2) -> Vector2:
	return center2 + trail_dir * hole_distance


## Escolhe onde ficam as câmaras, longe dos olheiros das trilhas.
## Grandes: a rainha no topo do monte + 4 câmaras grandes. Médios: 4 câmaras
## grandes. Pequenos: 3 pequenas.
func plan_chambers(rng: RandomNumberGenerator) -> void:
	chambers.clear()
	if big:
		# A tampa da rainha fica no topo; aberta, o monte inteiro vira buraco.
		var royal := Chamber.new()
		royal.royal = true
		royal.size_class = ROYAL
		royal.radius = 0.85
		royal.pit_radius = radius * 0.62
		royal.local = Vector2.ZERO
		chambers.append(royal)
	var large := big or medium
	var count := 4 if large else 3
	var dist := radius * (0.56 if big else (0.5 if medium else 0.43))
	var best_angles: Array[float] = []
	var best_score := -INF
	for _attempt in 24:
		var start := rng.randf() * TAU
		var angles: Array[float] = []
		for k in count:
			angles.append(start + TAU * k / count)
		var score := INF
		for a in angles:
			var d := Vector2(cos(a), sin(a))
			for t in trail_dirs:
				score = minf(score, 1.0 - d.dot(t))
		if score > best_score:
			best_score = score
			best_angles = angles
	for a in best_angles:
		var c := Chamber.new()
		c.size_class = LARGE if large else SMALL
		c.radius = rng.randf_range(0.52, 0.6) if large else rng.randf_range(0.48, 0.56)
		c.local = Vector2(cos(a), sin(a)) * dist
		chambers.append(c)
	for c in chambers:
		c.pos2 = center2 + c.local


func build(rng: RandomNumberGenerator, mats) -> void:
	_mats = mats
	# O visual usa um gerador só dele; o do mapa gasta os mesmos números de
	# antes (no fim), para as plantas e o capim não mudarem de lugar.
	var vr := RandomNumberGenerator.new()
	vr.seed = 9100 + index * 7
	var model := ModelLibrary.instantiate("formigueiro", Vector3(radius * 2.1, 0.0, radius * 2.1))
	if model:
		used_ai_model = true
		_mound = model
	else:
		_mound = _build_procedural(vr, mats)
	add_child(_mound)
	for c in chambers:
		# O buraco da rainha só é montado quando o monte é desmanchado.
		c.pit = Node3D.new() if c.royal else _build_pit(c, vr, mats)
		c.pit.visible = false
		add_child(c.pit)
		c.cap = _build_cap(c, vr, mats)
		add_child(c.cap)
	_collision = _build_collision()
	add_child(_collision)
	_skip_old_draws(rng)


## Gasta do gerador do mapa os mesmos números que o visual antigo dos
## formigueiros gastava (torrões, folhinhas e tampas), para o resto do mapa
## sair igual.
func _skip_old_draws(rng: RandomNumberGenerator) -> void:
	if not used_ai_model:
		var holes: Array[Vector2] = []
		for d in trail_dirs:
			holes.append(d * hole_distance)
		for _k in int(90 + radius * 30.0):
			var a := rng.randf() * TAU
			var r := radius * sqrt(rng.randf()) * 1.05
			var p2 := Vector2(cos(a), sin(a)) * r
			if _near_hole(p2, holes, 0.16) or _in_chamber(p2, 0.1):
				continue
			rng.randf()
			rng.randf()
		for _h in holes:
			for _k in 4 * 4:
				rng.randf()
	for _c in chambers:
		rng.randi()
		for _k in 9 * 4:
			rng.randf()


## Chão do monte: uma malha que segue a forma do domo, para dar para subir nele.
func _build_collision() -> StaticBody3D:
	var rings := 20
	var segs := 48
	var outer := radius * 1.04
	var faces := PackedVector3Array()
	var top := Vector3(0, _surf(Vector2.ZERO), 0)
	var prev := PackedVector3Array()
	for i in range(1, rings + 1):
		var r := outer * float(i) / rings
		var ring := PackedVector3Array()
		for j in segs:
			var a := TAU * j / segs
			var lp := Vector2(cos(a), sin(a)) * r
			ring.append(Vector3(lp.x, _surf(lp), lp.y))
		for j in segs:
			var j1 := (j + 1) % segs
			if i == 1:
				faces.append(top)
				faces.append(ring[j1])
				faces.append(ring[j])
			else:
				faces.append(prev[j])
				faces.append(prev[j1])
				faces.append(ring[j1])
				faces.append(prev[j])
				faces.append(ring[j1])
				faces.append(ring[j])
		prev = ring
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var col := CollisionShape3D.new()
	col.shape = shape
	var body := StaticBody3D.new()
	body.name = "ChaoDoMonte"
	body.add_child(col)
	return body


# ------------------------------------------------------------------ Estado

func residents_left() -> int:
	var n := 0
	for c in chambers:
		n += c.residents
	return n


## Quanto ainda falta comer aqui (a rainha vale QUEEN_VALUE formigas).
func remaining() -> int:
	return pool + roamers_left() + residents_left() + (QUEEN_VALUE if queen_alive else 0)


## Formigas passeando em volta das câmaras do campo deste formigueiro.
func roamers_left() -> int:
	var n := 0
	for c in chambers:
		n += c.roamers
	return n


func closed_chambers() -> int:
	var n := 0
	for c in chambers:
		if not c.opened:
			n += 1
	return n


func clean_chambers() -> int:
	var n := 0
	for c in chambers:
		if c.opened and c.residents == 0 and not (c.royal and queen_alive):
			n += 1
	return n


func royal_chamber() -> Chamber:
	for c in chambers:
		if c.royal:
			return c
	return null


## Câmara fechada mais perto de p2, dentro do alcance (ou -1).
func closed_chamber_near(p2: Vector2, reach: float) -> int:
	var best := -1
	var best_d := reach
	for i in chambers.size():
		var c := chambers[i]
		if c.opened:
			continue
		var d := c.edge_distance(p2)
		if d < best_d:
			best_d = d
			best = i
	return best


## Câmara aberta com moradoras mais perto de p2 (ou -1).
func open_chamber_near(p2: Vector2, reach: float) -> int:
	var best := -1
	var best_d := reach
	for i in chambers.size():
		var c := chambers[i]
		if not c.opened or (c.residents == 0 and not (c.royal and queen_alive)):
			continue
		var d := c.edge_distance(p2)
		if d < best_d:
			best_d = d
			best = i
	return best


func chamber_world_pos(c: Chamber) -> Vector3:
	return global_position + Vector3(c.local.x, _surf(c.local), c.local.y)


## Câmaras que ficam no monte (sem as do campo).
func mound_chambers() -> int:
	var n := 0
	for c in chambers:
		if not c.satellite:
			n += 1
	return n


# ------------------------------------------------------------------ Efeitos

## Tremida da tampa enquanto o tamanduá cava (0..1).
func set_dig_progress(ci: int, progress: float) -> void:
	if ci < 0 or ci >= chambers.size():
		return
	var cap := chambers[ci].cap
	if cap == null:
		return
	_dig_shake += 0.7
	var k := 1.0 - progress * 0.35
	cap.scale = Vector3(k, k, k)
	cap.rotation = Vector3(sin(_dig_shake * 9.0) * 0.06 * progress, 0.0, cos(_dig_shake * 7.0) * 0.06 * progress)


func reset_dig(ci: int) -> void:
	if ci >= 0 and ci < chambers.size() and chambers[ci].cap:
		chambers[ci].cap.scale = Vector3.ONE
		chambers[ci].cap.rotation = Vector3.ZERO


## Abre a câmara: a tampa de terra some e o buraco aparece. A da rainha
## desmancha o monte inteiro.
func open_chamber(ci: int, instant: bool = false) -> void:
	var c := chambers[ci]
	c.opened = true
	if c.royal:
		_dig_out(c, instant)
		return
	c.pit.visible = true
	if not c.satellite and not used_ai_model:
		# O monte ganha o buraco (por baixo da panela) e o chão acompanha.
		(_mound as MeshInstance3D).mesh = MeshBuilder.with_lods(_mound_surface())
		_collision.queue_free()
		_collision = _build_collision()
		add_child(_collision)
	if instant:
		c.cap.visible = false
		return
	var tw := create_tween()
	tw.tween_property(c.cap, "scale", Vector3(1.25, 0.05, 1.25), 0.18).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): c.cap.visible = false)
	_dirt_burst(chamber_world_pos(c), c.radius)


## O monte some: as tampas e os buracos que estavam nele também, e fica o
## buraco grande com a rainha no fundo.
func _dig_out(royal: Chamber, instant: bool) -> void:
	dug_out = true
	for c in chambers:
		if c.satellite or c == royal:
			continue
		c.opened = true
		c.cap.visible = false
		c.pit.visible = false
	royal.cap.visible = false
	royal.pit.queue_free()
	royal.pit = _build_crater()
	add_child(royal.pit)
	_collision.queue_free()
	_collision = _build_collision()
	add_child(_collision)
	if instant:
		_mound.visible = false
		return
	# O monte afunda depressa, numa nuvem de terra.
	var tw := create_tween()
	tw.tween_property(_mound, "scale", Vector3(1.08, 0.02, 1.08), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _mound.visible = false)
	for k in 6:
		var a := TAU * k / 6.0
		var lp := Vector2(cos(a), sin(a)) * radius * 0.55
		_dirt_burst(global_position + Vector3(lp.x, _surf(lp), lp.y), radius * 0.4)
	_dirt_burst(chamber_world_pos(royal), radius * 0.5)


func _dirt_burst(at: Vector3, r: float) -> void:
	DirtFx.burst(get_parent(), at, r)


## Formigueiro limpo: florzinhas brotam no monte.
func set_cleaned(instant: bool = false) -> void:
	if cleaned:
		return
	cleaned = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + index
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = Props.build_flower_mesh()
	var n := int(46.0 * pow(radius / 1.9, 2.0))
	mm.instance_count = n
	var colors: Array[Color] = [Color(0.98, 0.78, 0.18), Color(0.98, 0.95, 0.88), Color(0.72, 0.52, 0.86), Color(0.98, 0.70, 0.82)]
	var bases: Array[Transform3D] = []
	for k in n:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius * 0.95
		var lp := Vector2(cos(a), sin(a)) * r
		var y := dome_height(center2.x + lp.x, center2.y + lp.y) - 0.01
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.1, 1.8)), Vector3(lp.x, y, lp.y))
		bases.append(xf)
		mm.set_instance_custom_data(k, colors[rng.randi() % colors.size()])
		mm.set_instance_transform(k, xf.scaled_local(Vector3.ONE * (1.0 if instant else 0.01)))
	_flowers = MultiMeshInstance3D.new()
	_flowers.multimesh = mm
	if _mats:
		_flowers.material_override = _mats.flower
	_flowers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flowers)
	if not instant:
		_flower_bases = bases
		create_tween().tween_method(_grow_flowers, 0.0, 1.0, 1.8)


func _grow_flowers(t: float) -> void:
	var mm := _flowers.multimesh
	var n := _flower_bases.size()
	for k in n:
		var grow := clampf(t * 1.6 - float(k) / n * 0.6, 0.01, 1.0)
		mm.set_instance_transform(k, _flower_bases[k].scaled_local(Vector3.ONE * grow))


# ------------------------------------------------------------------ Malhas

## Cor de vértice da terra cavada: o brilho `lum` (o shader troca a estampa
## por ele) com o tom `hue` da camada de terra.
static func _dug(lum: float, hue: Color) -> Color:
	var l := hue.r * 0.3 + hue.g * 0.59 + hue.b * 0.11
	return Color(hue.r / l * lum, hue.g / l * lum, hue.b / l * lum)


## Tom da camada de terra a `depth` metros abaixo da superfície.
func _layer_hue(depth: float, wobble: float) -> Color:
	var z := depth + wobble
	var h := LAYER_TOP.lerp(LAYER_RED, smoothstep(0.03, 0.08, z))
	return h.lerp(LAYER_YELLOW, smoothstep(0.17, 0.25, z))


## Câmara aberta. Rasa: panela pouco funda, um ou dois túneis no chão, um
## tufo de fungo e pouca terra em volta. Funda: parede quase em pé com as
## camadas de terra, túneis na parede, o jardim de fungo grande e torrões
## grandes em volta.
func _build_pit(c: Chamber, rng: RandomNumberGenerator, mats) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Pit"
	var dims := _pit_dims(c)
	var deep := dims.x > 0.2
	var rings := 22 if deep else 16
	var segs := 60 if deep else 44
	var t_out := 1.55
	var fn := FastNoiseLite.new()
	fn.seed = rng.randi()
	fn.frequency = 2.5
	# Bocas de túnel (x, z, raio): na parede das fundas, no chão das rasas.
	var tunnels: Array[Vector3] = []
	var nt := rng.randi_range(3, 5) if deep else rng.randi_range(1, 2)
	for _k in nt:
		var a := rng.randf() * TAU
		var tt := rng.randf_range(0.68, 0.84) if deep else rng.randf_range(0.1, 0.38)
		var p := c.local + Vector2(cos(a), sin(a)) * tt * c.radius
		tunnels.append(Vector3(p.x, p.y, rng.randf_range(0.05, 0.075) if deep else rng.randf_range(0.04, 0.055)))
	var b := MeshBuilder.new()
	for i in rings + 1:
		var t := t_out * pow(float(i) / rings, 0.9)
		for j in (1 if i == 0 else segs):
			var a := TAU * j / segs
			var lp := c.local + Vector2(cos(a), sin(a)) * t * c.radius
			var off := _pit_offset(c, lp)
			var tn := _pit_t(c, lp)
			var floor_k := 1.0 - smoothstep(dims.z, 1.0, tn)
			var y := _surf(lp) + off + fn.get_noise_2d(lp.x * 4.0, lp.y * 4.0) * 0.015 * floor_k
			var depth := maxf(-off, 0.0)
			var lum: float
			var hue: Color
			if deep:
				lum = lerpf(0.3, 0.12, clampf(depth / dims.x, 0.0, 1.0))
				hue = _layer_hue(depth, fn.get_noise_2d(lp.x * 6.0 + 11.0, lp.y * 6.0) * 0.03)
			else:
				lum = lerpf(0.32, 0.2, floor_k)
				hue = LAYER_TOP.lerp(LAYER_RED, floor_k * 0.6)
			var dark := 0.0
			for tu in tunnels:
				var dt := lp.distance_to(Vector2(tu.x, tu.y))
				dark = maxf(dark, 1.0 - smoothstep(tu.z * 0.55, tu.z * 1.05, dt))
				y -= 0.04 * (1.0 - smoothstep(0.0, tu.z, dt))
			lum = lerpf(lum, 0.03, dark)
			var col := _dug(lum, hue.lerp(Color.WHITE, dark))
			# A terra tirada em volta é terra fofa (a mesma do monte), mais clara.
			b.color = col.lerp(Color(0.97, 0.94, 0.88), smoothstep(0.96, 1.1, tn))
			y += 0.004 + 0.01 * (1.0 - smoothstep(1.3, t_out, t))
			b.add_vertex(Vector3(lp.x, y, lp.y), Vector3.UP)
	for j in segs:
		b.add_tri(0, 1 + (j + 1) % segs, 1 + j)
	for i in range(1, rings):
		var r0 := 1 + (i - 1) * segs
		var r1 := 1 + i * segs
		for j in segs:
			var j1 := (j + 1) % segs
			b.add_quad(r0 + j, r0 + j1, r1 + j1, r1 + j)
	b.recompute_normals()
	# Torrões da terra tirada, espalhados em volta.
	var nclods := 26 if deep else (22 if c.satellite else 14)
	for _k in nclods:
		var a := rng.randf() * TAU
		var lp := c.local + Vector2(cos(a), sin(a)) * rng.randf_range(1.0, 1.4) * c.radius
		var s := rng.randf_range(0.022, 0.05) if deep else rng.randf_range(0.012, 0.03)
		var y := _surf(lp) + _pit_offset(c, lp) + 0.012 + s * 0.2
		b.color = Color(0.86, 0.83, 0.78).lerp(Color(1.0, 0.97, 0.9), rng.randf())
		b.add_blob(Vector3(lp.x, y, lp.y), Vector3(s, s * 0.7, s), fn, 0.3, 1)
	var mi := MeshInstance3D.new()
	mi.name = "Panela"
	mi.mesh = b.commit(null, mats.nest_soil)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)

	# Jardim de fungo: esponja clara com pedacinhos de folha.
	var fb := MeshBuilder.new()
	var nf := rng.randi_range(2, 3) if deep else 1
	var a0 := rng.randf() * TAU
	for k in nf:
		var a := a0 + TAU * k / nf + rng.randf_range(-0.4, 0.4)
		var tt := rng.randf_range(0.5, 0.66) if deep else rng.randf_range(0.3, 0.5)
		var cp := c.local + Vector2(cos(a), sin(a)) * tt * c.radius
		var size := rng.randf_range(0.1, 0.14) if deep else rng.randf_range(0.06, 0.085)
		_add_fungus(fb, rng, fn, cp, size, func(p: Vector2) -> float: return _surf(p) + _pit_offset(c, p) + 0.01)
	var fungus := MeshInstance3D.new()
	fungus.name = "Fungo"
	fungus.mesh = fb.commit(null, mats.nest_fungus)
	fungus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(fungus)
	return pivot


## Um tufo do jardim de fungo das saúvas em `cp` (do tamanho `size`): bolotas
## de esponja grudadas, com pedacinhos de folha cortada por cima. `floor_at`
## dá a altura do chão em cada ponto.
func _add_fungus(fb: MeshBuilder, rng: RandomNumberGenerator, fn: FastNoiseLite, cp: Vector2,
		size: float, floor_at: Callable) -> void:
	for _k in rng.randi_range(3, 5):
		var p := cp + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * size * 0.55
		var r := size * rng.randf_range(0.45, 0.7)
		var y: float = floor_at.call(p)
		fb.color = Color(0.62, 0.59, 0.5).lerp(Color(0.52, 0.49, 0.4), rng.randf()) * rng.randf_range(0.92, 1.04)
		fb.add_blob(Vector3(p.x, y + r * 0.25, p.y), Vector3(r, r * 0.7, r), fn, 0.35, 2, 2.0, Basis.IDENTITY, -r * 0.2)
	var leaf_cols: Array[Color] = [Color(0.45, 0.55, 0.25), Color(0.7, 0.66, 0.32), Color(0.48, 0.36, 0.22)]
	for _k in rng.randi_range(4, 7):
		var p := cp + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * size * 0.5
		var y: float = floor_at.call(p) + size * rng.randf_range(0.55, 0.75)
		var s := rng.randf_range(0.012, 0.024)
		var rot := rng.randf() * TAU
		var dx := Vector3(cos(rot), 0, sin(rot)) * s
		var dz := Vector3(-sin(rot), 0.25, cos(rot)) * s * 0.6
		fb.color = leaf_cols[rng.randi() % leaf_cols.size()]
		var ctr := Vector3(p.x, y, p.y)
		var i0 := fb.add_vertex(ctr - dx - dz, Vector3.UP)
		var i1 := fb.add_vertex(ctr + dx - dz, Vector3.UP)
		var i2 := fb.add_vertex(ctr + dx + dz, Vector3.UP)
		var i3 := fb.add_vertex(ctr - dx + dz, Vector3.UP)
		fb.add_quad(i0, i3, i2, i1)


func _build_cap(c: Chamber, rng: RandomNumberGenerator, mats) -> Node3D:
	# Tampa de terra fofa que acompanha a inclinação do monte (nada flutuando).
	# Quanto mais funda a câmara, mais alto o morrinho de terra por cima.
	var pivot := Node3D.new()
	pivot.name = "Cap"
	var base_y := _surf(c.local)
	pivot.position = Vector3(c.local.x, base_y, c.local.y)
	var b := MeshBuilder.new()
	var n := FastNoiseLite.new()
	n.seed = rng.randi()
	n.frequency = 2.2
	var rings := 9
	var segs := 30
	var r_out := c.radius * 1.12
	var bump: float = [0.14, 0.14, 0.24, 0.26][c.size_class]
	var tint: Color = CAP_TINT[c.size_class]
	b.color = tint
	b.add_vertex(Vector3(0, bump + 0.01, 0), Vector3.UP)
	for i in range(1, rings + 1):
		var t := float(i) / rings
		for j in segs:
			var a := TAU * j / segs
			var off := Vector2(cos(a), sin(a)) * r_out * t
			var lp := c.local + off
			var h := bump * pow(1.0 - t * t, 1.4) + n.get_noise_2d(off.x * 9.0, off.y * 9.0) * 0.02 * (1.0 - t)
			var edge := smoothstep(0.72, 1.0, t)
			b.color = tint.lerp(Color(0.42, 0.32, 0.26), edge * 0.85)
			b.add_vertex(Vector3(off.x, _surf(lp) - base_y + h - 0.012 * edge, off.y), Vector3.UP)
	for j in segs:
		b.add_tri(0, 1 + (j + 1) % segs, 1 + j)
	for i in range(1, rings):
		var r0 := 1 + (i - 1) * segs
		var r1 := 1 + i * segs
		for j in segs:
			var j1 := (j + 1) % segs
			b.add_quad(r0 + j, r0 + j1, r1 + j1, r1 + j)
	b.recompute_normals()
	# Torrões soltos por cima.
	for _k in 9:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r_out * 0.75
		var off := Vector2(cos(a), sin(a)) * d
		var h := bump * pow(1.0 - pow(d / r_out, 2.0), 1.4)
		b.color = Color(0.8, 0.74, 0.68).lerp(Color.WHITE, rng.randf()) * tint
		var y := _surf(c.local + off) - base_y + h
		b.add_blob(Vector3(off.x, y + 0.015, off.y), Vector3.ONE * rng.randf_range(0.03, 0.055), n, 0.2, 1)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(null, mats.nest_cap)
	# A tampa fica rente ao monte: a sombra dela quase não aparece.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)
	return pivot


## Altura do chão neste ponto, medida a partir da base do formigueiro.
func _surf(local: Vector2) -> float:
	if ground.is_valid():
		return float(ground.call(center2.x + local.x, center2.y + local.y)) - position.y
	return dome_height(center2.x + local.x, center2.y + local.y)


## O buraco que fica quando o monte é desmanchado: a parede desce em dois
## degraus com as camadas de terra à mostra, câmaras cortadas ao meio na
## parede (com o fungo dentro), túneis, torrões e, no fundo, a câmara da
## rainha, escura.
func _build_crater() -> Node3D:
	var root := Node3D.new()
	root.name = "BuracoDaRainha"
	var rng := RandomNumberGenerator.new()
	rng.seed = 4400 + index
	var fn := FastNoiseLite.new()
	fn.seed = 4400 + index
	fn.frequency = 1.6
	var rim_y := CRATER_FLOOR + height * CRATER_RIM_HEIGHT
	# Câmaras cortadas na parede de cima (x, z, raio) e túneis (x, z, raio).
	var pockets: Array[Vector3] = []
	var np := 6
	var a0 := rng.randf() * TAU
	for k in np:
		var a := a0 + TAU * k / np + rng.randf_range(-0.3, 0.3)
		var d := rng.randf_range(0.55, 0.63) * radius
		pockets.append(Vector3(cos(a) * d, sin(a) * d, rng.randf_range(0.22, 0.3)))
	var tunnels: Array[Vector3] = []
	for _k in 10:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.24, 0.46) * radius
		tunnels.append(Vector3(cos(a) * d, sin(a) * d, rng.randf_range(0.06, 0.1)))
	var b := MeshBuilder.new()
	var rings := 32
	var segs := 84
	var outer := radius * 1.02
	for i in rings + 1:
		var t := float(i) / rings
		for j in (1 if i == 0 else segs):
			var a := TAU * j / segs
			var lp := Vector2(cos(a), sin(a)) * outer * t
			var d := lp.length() / radius
			var n := fn.get_noise_2d(lp.x * 2.5, lp.y * 2.5)
			var y := _surf(lp) + 0.01
			var lum: float
			var hue: Color
			if d < 0.2:
				# Fundo: a câmara da rainha, escura.
				lum = lerpf(0.05, 0.1, d / 0.2)
				hue = LAYER_TOP
			else:
				var dr := maxf(rim_y - y, 0.0)
				lum = lerpf(0.3, 0.12, clampf(dr / (rim_y - CRATER_FLOOR), 0.0, 1.0))
				hue = _layer_hue(dr * 0.7, n * 0.04)
				# No patamar caiu terra solta de cima: um pouco mais clara.
				lum += 0.04 * smoothstep(0.34, 0.4, d) * (1.0 - smoothstep(0.46, 0.5, d))
			var dark := 0.0
			for p in pockets:
				var dp := lp.distance_to(Vector2(p.x, p.y))
				var k := 1.0 - smoothstep(p.z * 0.6, p.z, dp)
				dark = maxf(dark, k * 0.85)
				y -= 0.12 * k
			for tu in tunnels:
				var dt := lp.distance_to(Vector2(tu.x, tu.y))
				dark = maxf(dark, 1.0 - smoothstep(tu.z * 0.55, tu.z * 1.05, dt))
				y -= 0.035 * (1.0 - smoothstep(0.0, tu.z, dt))
			lum = lerpf(lum, 0.03, dark)
			var col := _dug(lum, hue.lerp(Color.WHITE, dark))
			# A borda é a terra fofa do monte que sobrou.
			b.color = col.lerp(Color(0.95, 0.92, 0.86), smoothstep(0.68, 0.8, d + n * 0.05))
			b.add_vertex(Vector3(lp.x, y + n * 0.03 * smoothstep(0.7, 0.85, d), lp.y), Vector3.UP)
	for j in segs:
		b.add_tri(0, 1 + (j + 1) % segs, 1 + j)
	for i in range(1, rings):
		var r0 := 1 + (i - 1) * segs
		var r1 := 1 + i * segs
		for j in segs:
			var j1 := (j + 1) % segs
			b.add_quad(r0 + j, r0 + j1, r1 + j1, r1 + j)
	b.recompute_normals()
	# Torrões na borda e no patamar.
	for _k in 80:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.7, 0.98) if rng.randf() < 0.65 else rng.randf_range(0.37, 0.47)
		var lp := Vector2(cos(a), sin(a)) * d * radius
		var s := rng.randf_range(0.025, 0.07)
		b.color = Color(0.86, 0.83, 0.78).lerp(Color(1.0, 0.97, 0.9), rng.randf())
		b.add_blob(Vector3(lp.x, _surf(lp) + 0.01 + s * 0.2, lp.y), Vector3(s, s * 0.7, s), fn, 0.3, 1)
	var mi := MeshInstance3D.new()
	mi.name = "Terra"
	mi.mesh = b.commit(null, _mats.nest_soil)
	root.add_child(mi)
	# Fungo nas câmaras cortadas e pedaços dele caídos no patamar e no fundo.
	var fb := MeshBuilder.new()
	var floor_at := func(p: Vector2) -> float:
		var y := _surf(p) + 0.01
		for q in pockets:
			y -= 0.12 * (1.0 - smoothstep(q.z * 0.6, q.z, p.distance_to(Vector2(q.x, q.y))))
		return y
	for p in pockets:
		_add_fungus(fb, rng, fn, Vector2(p.x, p.y), p.z * 0.55, floor_at)
	for _k in 9:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.38, 0.46) if rng.randf() < 0.6 else rng.randf_range(0.12, 0.22)
		_add_fungus(fb, rng, fn, Vector2(cos(a), sin(a)) * d * radius, rng.randf_range(0.04, 0.07), floor_at)
	var fungus := MeshInstance3D.new()
	fungus.name = "Fungo"
	fungus.mesh = fb.commit(null, _mats.nest_fungus)
	fungus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fungus)
	return root


## Olheiros do monte: os das trilhas e outros menores espalhados (longe das
## câmaras), como nos montes de saúva de verdade.
func _plan_olheiros(rng: RandomNumberGenerator) -> void:
	_olheiros.clear()
	for d in trail_dirs:
		var h := d * hole_distance
		_olheiros.append(Vector3(h.x, h.y, 0.075))
	var want := int(radius * 4.0)
	var extra := 0
	for _try in 300:
		if extra >= want:
			break
		var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a)) * radius * 0.85 * sqrt(rng.randf())
		if _mound_shape(p) < height * 0.15:
			continue
		var ok := true
		for c in chambers:
			if not c.satellite and c.edge_distance(center2 + p) < 0.45:
				ok = false
		for o in _olheiros:
			if p.distance_to(Vector2(o.x, o.y)) < (0.55 if o.z > 0.07 else 0.4):
				ok = false
		if ok:
			_olheiros.append(Vector3(p.x, p.y, rng.randf_range(0.035, 0.06)))
			extra += 1


## Malha do chão do monte (com o buraco das câmaras abertas por baixo das panelas).
func _mound_surface() -> ArrayMesh:
	var b := MeshBuilder.new()
	var rings := 34
	var segs := 80
	var outer := radius * 1.05
	b.add_vertex(Vector3(0, _surface_h(Vector2.ZERO), 0), Vector3.UP, Vector2(0.5, 0.5))
	b.colors[0] = _mound_color(Vector2.ZERO)
	for i in range(1, rings + 1):
		var t := float(i) / rings
		var r := outer * pow(t, 0.85)
		for j in segs:
			var a := TAU * j / segs
			var p2 := Vector2(cos(a), sin(a)) * r
			b.color = _mound_color(p2)
			b.add_vertex(Vector3(p2.x, _surface_h(p2), p2.y), Vector3.UP, Vector2(t, float(j) / segs))
	for j in segs:
		b.add_tri(0, 1 + (j + 1) % segs, 1 + j)
	for i in range(1, rings):
		var r0 := 1 + (i - 1) * segs
		var r1 := 1 + i * segs
		for j in segs:
			var j1 := (j + 1) % segs
			b.add_quad(r0 + j, r0 + j1, r1 + j1, r1 + j)
	b.recompute_normals()
	return b.commit(null, _mats.nest_soil)


func _build_procedural(rng: RandomNumberGenerator, mats) -> MeshInstance3D:
	_plan_olheiros(rng)
	var mi := MeshInstance3D.new()
	mi.name = "MonteProcedural"
	mi.mesh = MeshBuilder.with_lods(_mound_surface())
	# Olheiros: vulcõezinhos de terra fofa com o buraco escuro no meio.
	var ob := MeshBuilder.new()
	var on := FastNoiseLite.new()
	on.seed = rng.randi()
	on.frequency = 2.0
	for o in _olheiros:
		_add_olheiro(ob, rng, on, o)
	var holes_mi := MeshInstance3D.new()
	holes_mi.name = "Olheiros"
	holes_mi.mesh = ob.commit(null, mats.nest_soil)
	holes_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holes_mi.visibility_range_end = 60.0
	mi.add_child(holes_mi)
	# Torrões e folhinhas numa malha à parte: sem sombra (são de 1 a 4 cm) e
	# somem de longe (a 35 m um torrão tem menos de 2 pixels).
	var b := MeshBuilder.new()
	var crumb_noise := FastNoiseLite.new()
	crumb_noise.frequency = 2.0
	for _k in int(30 + radius * 12.0):
		var a := rng.randf() * TAU
		var p2 := Vector2(cos(a), sin(a)) * radius * sqrt(rng.randf()) * 0.95
		if _in_chamber(p2, 0.1) or _near_olheiro(p2, 0.25) or _mound_shape(p2) < 0.04:
			continue
		var s := rng.randf_range(0.015, 0.04)
		b.color = Color(0.8, 0.76, 0.72).lerp(Color(1.0, 0.96, 0.9), rng.randf())
		b.add_blob(Vector3(p2.x, _surface_h(p2) + s * 0.3, p2.y), Vector3(s, s * 0.75, s), crumb_noise, 0.25, 1, 1.0)
	# Pedacinhos de folha cortada perto dos olheiros das trilhas.
	for d in trail_dirs:
		var h := d * hole_distance
		for _k in 4:
			var p2 := h + Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35))
			var y := _surface_h(p2) + 0.03
			var s := rng.randf_range(0.04, 0.07)
			var rot := rng.randf() * TAU
			var dx := Vector3(cos(rot), 0, sin(rot)) * s
			var dz := Vector3(-sin(rot), 0, cos(rot)) * s * 0.6
			b.color = Color(0.45, 1.0, 0.35)
			var c := Vector3(p2.x, y, p2.y)
			var i0 := b.add_vertex(c - dx - dz, Vector3.UP)
			var i1 := b.add_vertex(c + dx - dz, Vector3.UP)
			var i2 := b.add_vertex(c + dx + dz, Vector3.UP)
			var i3 := b.add_vertex(c - dx + dz, Vector3.UP)
			b.add_quad(i0, i3, i2, i1)
	var crumbs := MeshInstance3D.new()
	crumbs.name = "Torroes"
	crumbs.mesh = b.commit(null, mats.nest_soil)
	crumbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crumbs.visibility_range_end = 35.0
	mi.add_child(crumbs)
	return mi


## Um olheiro: um vulcãozinho de terra fofa (as bolinhas que as saúvas tiram
## lá de baixo) com o buraco escuro no meio, e bolinhas soltas em volta.
func _add_olheiro(b: MeshBuilder, rng: RandomNumberGenerator, n: FastNoiseLite, o: Vector3) -> void:
	var c2 := Vector2(o.x, o.y)
	var rh := o.z
	var rings := 8
	var segs := 18
	var r_out := rh * 4.5
	var rim_h := rh * 0.9
	var start := b.vertex_count()
	b.color = Color(0.03, 0.03, 0.03)
	b.add_vertex(Vector3(c2.x, _surface_h(c2) + 0.006, c2.y), Vector3.UP)
	for i in range(1, rings + 1):
		var t := float(i) / rings
		for j in segs:
			var a := TAU * j / segs
			var wob := 1.0 + 0.15 * n.get_noise_2d(cos(a) * 3.0 + o.x * 5.0, sin(a) * 3.0 + o.y * 5.0)
			var d := t * 4.5 * wob
			var lp := c2 + Vector2(cos(a), sin(a)) * r_out * t
			var cone := rim_h * exp(-pow((d - 1.5) / 1.0, 2.0)) * (1.0 - smoothstep(3.2, 4.5, t * 4.5))
			var y := _surface_h(lp) + 0.006 * (1.0 - smoothstep(0.8, 1.0, t)) + cone
			var dark := 1.0 - smoothstep(0.75, 1.2, d)
			b.color = Color(1.0, 0.95, 0.86).lerp(Color(0.03, 0.03, 0.03), dark)
			b.add_vertex(Vector3(lp.x, y, lp.y), Vector3.UP)
	for j in segs:
		b.add_tri(start, start + 1 + (j + 1) % segs, start + 1 + j)
	for i in range(1, rings):
		var r0 := start + 1 + (i - 1) * segs
		var r1 := start + 1 + i * segs
		for j in segs:
			var j1 := (j + 1) % segs
			b.add_quad(r0 + j, r0 + j1, r1 + j1, r1 + j)
	b.recompute_normals(start)
	for _k in rng.randi_range(8, 14):
		var a := rng.randf() * TAU
		var d := rng.randf_range(1.4, 3.4)
		var lp := c2 + Vector2(cos(a), sin(a)) * rh * d
		var s := rng.randf_range(0.008, 0.016)
		var cone := rim_h * exp(-pow((d - 1.5) / 1.0, 2.0))
		b.color = Color(0.9, 0.86, 0.8).lerp(Color(1.0, 0.97, 0.9), rng.randf())
		b.add_blob(Vector3(lp.x, _surface_h(lp) + cone + s * 0.4, lp.y), Vector3.ONE * s, n, 0.2, 1)


## Altura da malha do monte: a forma dele, a beirada um pouco enterrada (para
## não brigar com o chão do campo) e, nas câmaras abertas, um buraco bem
## fundo por baixo da panela.
func _surface_h(p2: Vector2) -> float:
	var y := _mound_shape(p2)
	var tq := p2.length() / _edge_radius(p2)
	y -= 0.05 * smoothstep(0.85, 1.05, tq)
	for c in chambers:
		if c.opened and not c.satellite and not c.royal:
			if _pit_t(c, p2) < 1.0:
				y = _mound_shape(p2) - _pit_dims(c).x - 0.08
			else:
				y += _pit_offset(c, p2)
	return y


## Cor de vértice do monte: manchas de terra mais velha e, em volta dos
## olheiros, a terra recém-tirada, mais clara.
func _mound_color(p2: Vector2) -> Color:
	var fresh := 0.0
	for o in _olheiros:
		fresh = maxf(fresh, 1.0 - smoothstep(o.z * 3.0, o.z * 9.0, p2.distance_to(Vector2(o.x, o.y))))
	var w := smoothstep(-0.2, 0.5, _noise.get_noise_2d(p2.x * 1.3 + 50.0, p2.y * 1.3))
	var base := Color(0.95, 0.95, 0.95).lerp(Color(0.84, 0.8, 0.78), w * 0.8)
	return base.lerp(Color(1.0, 0.94, 0.82), fresh * 0.8)


func _near_olheiro(p2: Vector2, dist: float) -> bool:
	for o in _olheiros:
		if p2.distance_to(Vector2(o.x, o.y)) < dist + o.z:
			return true
	return false


func _near_hole(p2: Vector2, holes: Array[Vector2], dist: float) -> bool:
	for h in holes:
		if p2.distance_to(h) < dist:
			return true
	return false


func _in_chamber(p2: Vector2, margin: float) -> bool:
	for c in chambers:
		if c.edge_distance(center2 + p2) < c.radius * 0.2 + margin:
			return true
	return false
