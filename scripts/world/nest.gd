extends Node3D
## Formigueiro de saúvas: um monte de terra fofa com olheiros (por onde as
## formigas das trilhas entram e saem) e câmaras fechadas, onde moram as
## outras. Cavar abre uma câmara. Nos formigueiros grandes, a rainha mora bem
## no fundo: cavar o topo do monte (Escavação Real) desmancha o monte inteiro e
## fica um buraco com a rainha e a corte dela lá embaixo. Cada buraco pede um
## nível de Cavar (pequeno, câmara grande, o monte da rainha). Quando tudo é
## comido, o monte floresce.
## O tamanduá pode subir no monte (o chão acompanha a forma dele).
## Se existir assets/models/formigueiro.glb, ele substitui o monte feito por código.

const MeshBuilder := preload("res://scripts/procedural/mesh_builder.gd")
const ModelLibrary := preload("res://scripts/model_library.gd")
const Props := preload("res://scripts/world/props.gd")

const QUEEN_VALUE := 200
## Tamanho dos buracos (o nível de Cavar que cada um pede).
const SMALL := 1
const LARGE := 2
const ROYAL := 3
## Cor da tampa de cada tamanho: as mais fundas são mais escuras, entre a
## terra fofa das pequenas e a cor do monte.
const CAP_TINT := [Color.WHITE, Color.WHITE, Color(0.84, 0.75, 0.69), Color(0.76, 0.65, 0.58)]
## Buraco do monte desmanchado: raio da borda (parte do raio do monte), altura
## da borda (parte da altura do monte) e o fundo (m; um pouco acima do chão,
## para o chão do campo não cobrir o fundo escuro).
const CRATER_RIM := 0.8
const CRATER_RIM_HEIGHT := 0.36
const CRATER_FLOOR := 0.03


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


func setup(i: int, nest_name: String, pos2: Vector2, r: float, h: float, is_big: bool) -> void:
	index = i
	display_name = nest_name
	center2 = pos2
	radius = r
	height = h
	big = is_big
	hole_distance = radius * 0.7
	_noise.seed = 100 + i
	_noise.frequency = 0.9


## Altura do monte acima do terreno (as formigas sobem por ele).
func dome_height(x: float, z: float) -> float:
	var dx := x - center2.x
	var dz := z - center2.y
	var d2 := dx * dx + dz * dz
	var r2 := radius * radius
	if d2 >= r2:
		return 0.0
	if dug_out:
		# Borda irregular, como terra revirada.
		return crater_height(sqrt(d2 / r2)) * (1.0 + _noise.get_noise_2d(dx * 1.4, dz * 1.4) * 0.5)
	return height * pow(1.0 - d2 / r2, 1.3)


## Buraco do monte desmanchado: fundo raso no meio e uma borda de terra em
## volta. `d` = distância do centro / raio do monte.
func crater_height(d: float) -> float:
	var rim := height * CRATER_RIM_HEIGHT
	if d < CRATER_RIM:
		return lerpf(CRATER_FLOOR, rim, smoothstep(0.4, CRATER_RIM, d))
	return rim * (1.0 - smoothstep(CRATER_RIM, 1.0, d))


func hole_position(trail_dir: Vector2) -> Vector2:
	return center2 + trail_dir * hole_distance


## Escolhe onde ficam as câmaras, longe dos olheiros das trilhas.
## Grandes: a rainha no topo do monte + 4 câmaras grandes. Pequenos: 3.
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
	var count := 4 if big else 3
	var dist := radius * (0.56 if big else 0.43)
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
		c.size_class = LARGE if big else SMALL
		c.radius = rng.randf_range(0.52, 0.6) if big else rng.randf_range(0.48, 0.56)
		c.local = Vector2(cos(a), sin(a)) * dist
		chambers.append(c)
	for c in chambers:
		c.pos2 = center2 + c.local


func build(rng: RandomNumberGenerator, mats) -> void:
	_mats = mats
	var model := ModelLibrary.instantiate("formigueiro", Vector3(radius * 2.1, 0.0, radius * 2.1))
	if model:
		used_ai_model = true
		_mound = model
	else:
		_mound = _build_procedural(rng, mats)
	add_child(_mound)
	for c in chambers:
		# O buraco da rainha só é montado quando o monte é desmanchado.
		c.pit = Node3D.new() if c.royal else _build_pit(c, mats)
		c.pit.visible = false
		add_child(c.pit)
		c.cap = _build_cap(c, rng, mats)
		add_child(c.cap)
	_collision = _build_collision()
	add_child(_collision)


## Chão do monte: uma malha que segue a forma do domo, para dar para subir nele.
func _build_collision() -> StaticBody3D:
	var rings := 12
	var segs := 32
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
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = 46
	p.lifetime = 1.1
	p.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = r * 0.6
	pm.direction = Vector3.UP
	pm.spread = 55.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	p.process_material = pm
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.06
	mesh.radial_segments = 8
	mesh.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.33, 0.2)
	m.roughness = 1.0
	mesh.material = m
	p.draw_pass_1 = mesh
	get_parent().add_child(p)
	p.global_position = at + Vector3(0, 0.1, 0)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


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

func _build_pit(c: Chamber, mats) -> MeshInstance3D:
	var b := MeshBuilder.new()
	var rings := 7
	var segs := 28
	var r_out := c.radius * 1.12
	b.color = Color(0.1, 0.06, 0.04)
	b.add_vertex(Vector3(c.local.x, _surf(c.local) + 0.014, c.local.y), Vector3.UP)
	for i in range(1, rings + 1):
		var t := float(i) / rings
		for j in segs:
			var a := TAU * j / segs
			var lp := c.local + Vector2(cos(a), sin(a)) * r_out * t
			var dark := 1.0 - smoothstep(0.62, 0.98, t)
			b.color = Color(0.85, 0.72, 0.62).lerp(Color(0.1, 0.06, 0.04), dark)
			var rim := exp(-pow((t - 0.86) / 0.1, 2.0)) * 0.05
			b.add_vertex(Vector3(lp.x, _surf(lp) + 0.014 + rim, lp.y), Vector3.UP)
	for j in segs:
		b.add_tri(0, 1 + (j + 1) % segs, 1 + j)
	for i in range(1, rings):
		var r0 := 1 + (i - 1) * segs
		var r1 := 1 + i * segs
		for j in segs:
			var j1 := (j + 1) % segs
			b.add_quad(r0 + j, r0 + j1, r1 + j1, r1 + j)
	b.recompute_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Pit"
	mi.mesh = b.commit(null, mats.nest_soil)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _build_cap(c: Chamber, rng: RandomNumberGenerator, mats) -> Node3D:
	# Tampa de terra fofa que acompanha a inclinação do monte (nada flutuando).
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
	var bump := 0.22 if not c.royal else 0.3
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


## O buraco que fica quando o monte é desmanchado: escuro no fundo, com a
## terra revirada em volta.
func _build_crater() -> MeshInstance3D:
	var b := MeshBuilder.new()
	var rings := 20
	var segs := 56
	var outer := radius * 1.02
	b.color = Color(0.07, 0.045, 0.03)
	b.add_vertex(Vector3(0, _surf(Vector2.ZERO) + 0.01, 0), Vector3.UP)
	for i in range(1, rings + 1):
		var t := float(i) / rings
		for j in segs:
			var a := TAU * j / segs
			var lp := Vector2(cos(a), sin(a)) * outer * t
			var d := lp.length() / radius
			var n := _noise.get_noise_2d(lp.x * 2.5, lp.y * 2.5)
			# Fundo quase preto, parede escura e a borda com a terra do monte.
			var deep := 1.0 - smoothstep(0.55, CRATER_RIM + 0.12, d + n * 0.06)
			b.color = Color(0.9, 0.78, 0.68).lerp(Color(0.07, 0.045, 0.03), deep)
			b.add_vertex(Vector3(lp.x, _surf(lp) + 0.01 + n * 0.03 * (1.0 - deep), lp.y), Vector3.UP)
	for j in segs:
		b.add_tri(0, 1 + (j + 1) % segs, 1 + j)
	for i in range(1, rings):
		var r0 := 1 + (i - 1) * segs
		var r1 := 1 + i * segs
		for j in segs:
			var j1 := (j + 1) % segs
			b.add_quad(r0 + j, r0 + j1, r1 + j1, r1 + j)
	b.recompute_normals()
	var mi := MeshInstance3D.new()
	mi.name = "BuracoDaRainha"
	mi.mesh = b.commit(null, _mats.nest_soil)
	return mi


func _build_procedural(rng: RandomNumberGenerator, mats) -> MeshInstance3D:
	var b := MeshBuilder.new()
	var holes: Array[Vector2] = []
	for d in trail_dirs:
		holes.append(d * hole_distance)
	var rings := 26
	var segs := 64
	var outer := radius * 1.12
	# Monte em grade radial.
	b.add_vertex(Vector3(0, _surface_h(Vector2.ZERO, holes), 0), Vector3.UP, Vector2(0.5, 0.5))
	b.colors[0] = _hole_color(Vector2.ZERO, holes)
	for i in range(1, rings + 1):
		var t := float(i) / rings
		var r := outer * pow(t, 0.85)
		for j in segs:
			var a := TAU * j / segs
			var p2 := Vector2(cos(a), sin(a)) * r
			var y := _surface_h(p2, holes)
			b.color = _hole_color(p2, holes)
			b.add_vertex(Vector3(p2.x, y, p2.y), Vector3.UP, Vector2(t, float(j) / segs))
	for j in segs:
		b.add_tri(0, 1 + (j + 1) % segs, 1 + j)
	for i in range(1, rings):
		var r0 := 1 + (i - 1) * segs
		var r1 := 1 + i * segs
		for j in segs:
			var j1 := (j + 1) % segs
			b.add_quad(r0 + j, r0 + j1, r1 + j1, r1 + j)
	b.recompute_normals()
	var mi := MeshInstance3D.new()
	mi.name = "MonteProcedural"
	mi.mesh = MeshBuilder.with_lods(b.commit(null, mats.nest_soil))
	# Torrões e folhinhas numa malha à parte: sem sombra (são de 2 a 5 cm) e
	# somem de longe (a 35 m um torrão tem menos de 2 pixels).
	b = MeshBuilder.new()
	# Torrões de terra escavada (fora das câmaras e dos olheiros).
	var crumb_noise := FastNoiseLite.new()
	crumb_noise.frequency = 2.0
	for _k in int(90 + radius * 30.0):
		var a := rng.randf() * TAU
		var r := radius * sqrt(rng.randf()) * 1.05
		var p2 := Vector2(cos(a), sin(a)) * r
		if _near_hole(p2, holes, 0.16) or _in_chamber(p2, 0.1):
			continue
		var s := rng.randf_range(0.02, 0.05)
		var y := _surface_h(p2, holes)
		b.color = Color(0.8, 0.75, 0.72).lerp(Color(1.2, 1.12, 1.05), rng.randf())
		b.add_blob(Vector3(p2.x, y + s * 0.3, p2.y), Vector3(s, s * 0.75, s), crumb_noise, 0.25, 1, 1.0)
	# Pedacinhos de folha cortada perto dos olheiros.
	for h in holes:
		for _k in 4:
			var p2 := h + Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35))
			var y := _surface_h(p2, holes) + 0.012
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


func _surface_h(p2: Vector2, holes: Array[Vector2]) -> float:
	var r2 := p2.length_squared() / (radius * radius)
	var y := 0.0
	if r2 < 1.0:
		y = height * pow(1.0 - r2, 1.3)
	else:
		y = -0.06 * smoothstep(1.0, 1.25, sqrt(r2))
	y += _noise.get_noise_2d(p2.x * 3.0, p2.y * 3.0) * 0.045 * (1.0 - clampf(r2, 0.0, 1.0) * 0.5)
	for h in holes:
		var d := p2.distance_to(h)
		# Borda elevada (cratera) e buraco no meio.
		y += 0.07 * exp(-pow((d - 0.13) / 0.06, 2.0))
		y -= 0.16 * exp(-pow(d / 0.075, 2.0))
	return y


func _hole_color(p2: Vector2, holes: Array[Vector2]) -> Color:
	var dark := 0.0
	for h in holes:
		dark = maxf(dark, 1.0 - smoothstep(0.04, 0.12, p2.distance_to(h)))
	return Color.WHITE.lerp(Color(0.12, 0.07, 0.05), dark)


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
