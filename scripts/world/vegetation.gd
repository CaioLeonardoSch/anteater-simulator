extends Node3D
## Distribui árvores, ipês, cupinzeiros, pedras, arbustos e troncos pela
## clareira, longe das trilhas e dos formigueiros: o centro fica aberto e as
## árvores ficam mais densas perto dos penhascos. No topo dos penhascos, mais árvores.

const Props := preload("res://scripts/world/props.gd")
const MeshBuilder := preload("res://scripts/procedural/mesh_builder.gd")
const ModelLibrary := preload("res://scripts/model_library.gd")

## Obstáculos circulares: Vector3(x, z, raio).
var obstacles: Array[Vector3] = []
var landmarks: Array[Dictionary] = []


func build(world, rng: RandomNumberGenerator) -> void:
	var mats = world.mats
	var terrain = world.terrain
	var ground := Callable(terrain, "get_height")
	# Ipês: marcos visuais do mapa.
	for kind in ["ipe", "ipe_roxo"]:
		var pos := _find_spot(world, rng, 6.0, 20.0, 4.0, 10.0, 2.6)
		if pos == Vector2.INF:
			continue
		var geo := _sub_rng(rng)
		var origin := Vector3(pos.x, terrain.get_height(pos.x, pos.y) - 0.05, pos.y)
		var model_name := "ipe_amarelo" if kind == "ipe" else "ipe_roxo"
		var tree := _ai(model_name, Vector3(0, geo.randf_range(6.5, 8.5), 0), 0.35, 3.0)
		if tree == null:
			tree = Props.build_tree(geo, mats, kind, 1.0, origin, ground)
		_put(tree, origin, rng)
		obstacles.append(Vector3(pos.x, pos.y, 0.6))
		landmarks.append({"name": "Ipê", "pos": pos})
	# Árvores retorcidas do cerrado: muitas perto dos penhascos, poucas no meio.
	for i in 12:
		var pos := _find_spot(world, rng, 16.0, 25.0, 3.0, 4.0, 2.0) if i < 10 else _find_spot(world, rng, 5.0, 14.0, 3.0, 6.0, 2.0)
		if pos == Vector2.INF:
			continue
		var geo := _sub_rng(rng)
		var origin := Vector3(pos.x, terrain.get_height(pos.x, pos.y) - 0.05, pos.y)
		var tree := _ai("arvore_cerrado", Vector3(0, geo.randf_range(4.5, 6.5), 0), 0.3, 3.0)
		if tree == null:
			tree = Props.build_tree(geo, mats, "cerrado", 1.0, origin, ground)
		_put(tree, origin, rng)
		obstacles.append(Vector3(pos.x, pos.y, 0.5))
	# Cupinzeiros, alguns em grupos.
	for _i in 4:
		var pos := _find_spot(world, rng, 4.0, 23.0, 2.2, 3.0, 1.2)
		if pos == Vector2.INF:
			continue
		var group := rng.randi_range(1, 3)
		for g in group:
			var p := pos + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5)) * float(g > 0)
			if g > 0 and not _spot_ok(world, p, 2.0, 1.6, 1.0):
				continue
			var geo := _sub_rng(rng)
			var h := geo.randf_range(0.9, 2.4)
			var mound := _ai("cupinzeiro", Vector3(0, h, 0), h * 0.32, h)
			var r := h * 0.4
			if mound == null:
				mound = Props.build_termite_mound(geo, mats)
				r = mound.get_meta("radius", 0.8)
			_put(mound, Vector3(p.x, _min_height(terrain, p, r) - 0.08, p.y), rng)
			obstacles.append(Vector3(p.x, p.y, r))
	# Pedras (as últimas caíram dos penhascos e ficam no pé deles).
	for i in 16:
		var size := rng.randf_range(0.35, 1.3) if i < 8 else rng.randf_range(0.8, 2.0)
		var pos := _find_spot(world, rng, 4.0, 23.0, 1.6 + size, 2.0, size) if i < 8 else _find_spot(world, rng, 21.0, 27.0, 1.6, 1.2, size)
		if pos == Vector2.INF:
			continue
		var geo := _sub_rng(rng)
		var rock := _ai("pedra", Vector3(size * 2.0, 0, size * 2.0), size * 0.85, size)
		if rock == null:
			rock = Props.build_rock(geo, mats, size)
		_put(rock, Vector3(pos.x, _min_height(terrain, pos, size) - size * 0.12, pos.y), rng)
		obstacles.append(Vector3(pos.x, pos.y, size * 0.9))
	# Arbustos decorativos (mais perto das bordas).
	for i in 12:
		var size := rng.randf_range(0.6, 1.2)
		var pos := _find_spot(world, rng, 15.0 if i < 8 else 4.0, 25.0, 1.8, 2.2, size * 0.6)
		if pos == Vector2.INF:
			continue
		var geo := _sub_rng(rng)
		var shrub := _ai("arbusto", Vector3(0, size * 1.3, 0), size * 0.55, size)
		if shrub == null:
			shrub = Props.build_shrub(geo, mats, size)
		_put(shrub, Vector3(pos.x, terrain.get_height(pos.x, pos.y) - 0.04, pos.y), rng)
		obstacles.append(Vector3(pos.x, pos.y, size * 0.55))
	# Troncos caídos.
	for _i in 2:
		var pos := _find_spot(world, rng, 6.0, 22.0, 2.8, 3.0, 2.0)
		if pos == Vector2.INF:
			continue
		var geo := _sub_rng(rng)
		var log_node := _ai("tronco_caido", Vector3(3.6, 0, 0), 0.0, 0.0)
		if log_node == null:
			log_node = Props.build_log(geo, mats)
		_put(log_node, Vector3(pos.x, terrain.get_height(pos.x, pos.y) - 0.05, pos.y), rng)
		obstacles.append(Vector3(pos.x, pos.y, 1.2))
	# Árvores no topo dos penhascos (aparecem por cima da beirada).
	var cliffs = world.cliffs
	for i in 64:
		var a := TAU * i / 64.0 + rng.randf_range(-0.04, 0.04)
		var r: float = cliffs.radius_at(a) + rng.randf_range(2.5, 17.0)
		var pos := Vector2(cos(a), sin(a)) * r
		if cliffs.in_exit(a):
			# Na direção da passagem não há platô: as árvores ficam lá no fim dela
			# (o começo da área 2).
			pos = Vector2(cos(a), sin(a)) * (cliffs.radius_at(a) + rng.randf_range(15.0, 19.0))
		var ground_y: float = terrain.get_height(pos.x, pos.y) if cliffs.in_exit(a) else cliffs.top_y(a)
		var origin := Vector3(pos.x, ground_y - 0.1, pos.y)
		var kind := "background"
		if rng.randf() < 0.12:
			kind = "ipe"
		var geo := _sub_rng(rng)
		var tree := _ai("ipe_amarelo" if kind == "ipe" else "arvore_cerrado", Vector3(0, geo.randf_range(5.0, 8.0), 0), 0.0, 0.0)
		if tree == null:
			tree = Props.build_tree(geo, mats, kind, 0.6, origin, ground)
			tree.scale = Vector3.ONE * geo.randf_range(1.0, 1.5)
		_no_shadows(tree)
		_put(tree, origin, rng)
	_build_edges(world)
	_add_lods(self, {})
	for o in obstacles:
		terrain.mask_paint(o.x, o.y, o.z + 0.25, 2, 1.0)


## Mais árvores em volta dos penhascos (no pé e no alto deles) e uma mata
## fechada depois da passagem para a área 2. Usa um gerador só seu: assim o
## resto do mapa não muda de lugar.
func _build_edges(world) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var mats = world.mats
	var terrain = world.terrain
	var ground := Callable(terrain, "get_height")
	var cliffs = world.cliffs
	# Pé dos penhascos: árvores do cerrado.
	for _i in 10:
		var pos := _find_spot(world, rng, 21.0, 26.0, 2.5, 3.0, 1.6)
		if pos == Vector2.INF:
			continue
		var geo := _sub_rng(rng)
		var origin := Vector3(pos.x, terrain.get_height(pos.x, pos.y) - 0.05, pos.y)
		var tree := _ai("arvore_cerrado", Vector3(0, geo.randf_range(4.5, 6.5), 0), 0.3, 3.0)
		if tree == null:
			tree = Props.build_tree(geo, mats, "cerrado", 0.85, origin, ground)
		_put(tree, origin, rng)
		obstacles.append(Vector3(pos.x, pos.y, 0.5))
	# Alto dos penhascos: mais um anel de árvores, bem mais cheio.
	for _i in 56:
		var a := rng.randf() * TAU
		if absf(angle_difference(cliffs.EXIT_ANGLE, a)) < cliffs.EXIT_HALF * 2.4:
			continue
		var r: float = cliffs.radius_at(a) + rng.randf_range(3.0, 21.0)
		var pos := Vector2(cos(a), sin(a)) * r
		var origin := Vector3(pos.x, cliffs.top_y(a) + 0.2, pos.y)
		var kind := "ipe" if rng.randf() < 0.1 else "background"
		var geo := _sub_rng(rng)
		var tree := _ai("ipe_amarelo" if kind == "ipe" else "arvore_cerrado", Vector3(0, geo.randf_range(5.0, 8.0), 0), 0.0, 0.0)
		if tree == null:
			tree = Props.build_tree(geo, mats, kind, 0.6, origin, ground)
			tree.scale = Vector3.ONE * geo.randf_range(0.9, 1.5)
		_no_shadows(tree)
		_put(tree, origin, rng)
	_build_forest(world, rng)


## Depois da passagem: uma picada que entra numa mata cada vez mais fechada,
## com árvores cada vez maiores dos dois lados (o cupinzeiro gigante aparece
## lá no fundo, por cima da picada). O chão de mata continua o terreno além da
## borda do mapa.
func _build_forest(world, rng: RandomNumberGenerator) -> void:
	var mats = world.mats
	var terrain = world.terrain
	var cliffs = world.cliffs
	var e := Vector2(cos(cliffs.EXIT_ANGLE), sin(cliffs.EXIT_ANGLE))
	var side := Vector2(-e.y, e.x)
	var r0: float = cliffs.radius_at(cliffs.EXIT_ANGLE)
	var start: Vector2 = e * (r0 + cliffs.CANYON_LENGTH - 2.0)
	var half_map: float = terrain.SIZE * 0.5
	var floor_noise := FastNoiseLite.new()
	floor_noise.seed = 31337
	floor_noise.frequency = 0.05
	# Chão: igual ao terreno onde ele existe (um pouco abaixo, escondido) e,
	# depois da borda, continuando dela com uma subida leve e ondulada.
	var floor_y := func(p: Vector2) -> float:
		var out := maxf(absf(p.x), absf(p.y)) - half_map
		var h: float = terrain.get_height(p.x, p.y)
		if out < 0.0:
			return h - 0.3 * clampf(-out / 3.0, 0.0, 1.0)
		return h + out * 0.04 + floor_noise.get_noise_2d(p.x, p.y) * 1.2 * smoothstep(0.0, 10.0, out)
	var b := MeshBuilder.new()
	var rings := 54
	var fan := 48
	for ri in rings + 1:
		var along := lerpf(0.0, 75.0, float(ri) / rings)
		var width := 7.0 + along * 0.8
		for fi in fan + 1:
			var lat := lerpf(-width, width, float(fi) / fan)
			var p: Vector2 = start + e * along + side * lat
			b.color = Color(0.95, 0.95, 0.88)
			b.add_vertex(Vector3(p.x, floor_y.call(p), p.y), Vector3.UP)
	for ri in rings:
		for fi in fan:
			var i0 := ri * (fan + 1) + fi
			b.add_quad(i0, i0 + 1, i0 + fan + 2, i0 + fan + 1)
	b.recompute_normals()
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "ChaoDaMata"
	floor_mi.mesh = b.commit(null, mats.forest_floor)
	mats.forest_floor.set_shader_parameter("half_map", half_map)
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mi)
	# Árvores dos dois lados da picada: mais juntas e maiores lá na frente.
	var placed: Array[Vector2] = []
	for _attempt in 900:
		if placed.size() >= 120:
			break
		var along := pow(rng.randf(), 0.75) * 66.0 + 3.0
		var width := 5.0 + along * 0.75
		var gap := lerpf(3.2, 2.3, clampf(along / 60.0, 0.0, 1.0))
		var lat := rng.randf_range(gap, width) * (1.0 if rng.randf() < 0.5 else -1.0)
		var p: Vector2 = start + e * along + side * lat
		var spacing := lerpf(3.4, 2.0, clampf(along / 45.0, 0.0, 1.0))
		var ok := true
		for q in placed:
			if q.distance_to(p) < spacing:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var origin := Vector3(p.x, floor_y.call(p) - 0.1, p.y)
		var geo := _sub_rng(rng)
		var near := along < 16.0
		var kind := "cerrado" if near else ("ipe" if rng.randf() < 0.07 else "background")
		var tree := _ai("arvore_cerrado", Vector3(0, geo.randf_range(5.5, 9.0), 0), 0.0, 0.0)
		if tree == null:
			tree = Props.build_tree(geo, mats, kind, 0.75 if near else 0.55, origin, Callable())
			tree.scale = Vector3.ONE * lerpf(1.0, 1.6, clampf(along / 60.0, 0.0, 1.0)) * geo.randf_range(0.9, 1.15)
		if not near:
			_no_shadows(tree)
		_put(tree, origin, rng)
	# Arbustos entre as árvores e na beira da picada.
	for _i in 50:
		var along := rng.randf_range(2.0, 55.0)
		var lat := rng.randf_range(1.8, 5.0 + along * 0.7) * (1.0 if rng.randf() < 0.5 else -1.0)
		var p: Vector2 = start + e * along + side * lat
		var geo := _sub_rng(rng)
		var size := geo.randf_range(0.7, 1.4)
		var shrub := _ai("arbusto", Vector3(0, size * 1.3, 0), 0.0, 0.0)
		if shrub == null:
			shrub = Props.build_shrub(geo, mats, size)
		_no_shadows(shrub)
		_put(shrub, Vector3(p.x, floor_y.call(p) - 0.04, p.y), rng)


## Gerador separado para a forma de cada objeto: assim o mapa não muda de
## lugar quando um modelo de IA substitui a versão feita por código.
func _sub_rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = rng.randi()
	return g


## Modelo de IA (assets/models/<nome>.glb) com colisão cilíndrica, ou null.
func _ai(model_name: String, target: Vector3, col_radius: float, col_height: float) -> Node3D:
	var node := ModelLibrary.instantiate(model_name, target)
	if node == null:
		return null
	if col_radius > 0.0:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = col_radius
		shape.height = maxf(col_height, 0.5)
		col.shape = shape
		col.position.y = shape.height * 0.5
		body.add_child(col)
		node.add_child(body)
	return node


## Dá às malhas versões mais simples para longe (e para as sombras).
func _add_lods(node: Node, done: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is ArrayMesh:
		var mi := node as MeshInstance3D
		if not done.has(mi.mesh):
			done[mi.mesh] = MeshBuilder.with_lods(mi.mesh)
		mi.mesh = done[mi.mesh]
	for c in node.get_children():
		_add_lods(c, done)


func _no_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_no_shadows(c)


func _put(node: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	node.position = pos
	node.rotation.y = rng.randf() * TAU
	add_child(node)


func _min_height(terrain, p: Vector2, r: float) -> float:
	var h: float = terrain.get_height(p.x, p.y)
	for k in 6:
		var a := TAU * k / 6.0
		h = minf(h, terrain.get_height(p.x + cos(a) * r, p.y + sin(a) * r))
	return h


func _spot_ok(world, pos: Vector2, trail_gap: float, spacing: float, radius: float) -> bool:
	if world.trails.distance_to_trails(pos) < trail_gap + radius:
		return false
	for n in world.nests:
		if pos.distance_to(n.center2) < n.radius + 2.2 + radius:
			return false
	for f in world.food_sources:
		if pos.distance_to(f) < 2.2 + radius:
			return false
	for q in world.satellite_spots:
		if pos.distance_to(q) < 2.5 + radius:
			return false
	if pos.distance_to(world.player_start) < 3.0:
		return false
	# Nada dentro dos penhascos, na boca da caverna ou na entrada da passagem.
	var angle := atan2(pos.y, pos.x)
	if pos.length() > world.cliffs.radius_at(angle) - 1.2 - radius:
		return false
	if pos.distance_to(world.cliffs.cave_mouth()) < 6.0 or pos.distance_to(world.cliffs.exit_center(0.0)) < 6.0:
		return false
	for w in world.ponds:
		if pos.distance_to(Vector2(w.x, w.y)) < w.z + 1.5 + radius:
			return false
	if world.near_cave_path(pos, 1.6 + radius):
		return false
	for o in obstacles:
		if pos.distance_to(Vector2(o.x, o.y)) < o.z + radius + spacing:
			return false
	return true


func _find_spot(world, rng: RandomNumberGenerator, min_r: float, max_r: float, trail_gap: float,
		spacing: float, radius: float) -> Vector2:
	for _attempt in 160:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(min_r * min_r, max_r * max_r))
		var pos := Vector2(cos(a), sin(a)) * r
		if _spot_ok(world, pos, trail_gap, spacing, radius):
			return pos
	return Vector2.INF
