extends Node3D
## Distribui árvores, ipês, cupinzeiros, pedras, arbustos e troncos pelo mapa,
## longe das trilhas e dos formigueiros.

const Props := preload("res://scripts/world/props.gd")
const ModelLibrary := preload("res://scripts/model_library.gd")

## Obstáculos circulares: Vector3(x, z, raio).
var obstacles: Array[Vector3] = []
var landmarks: Array[Dictionary] = []


func build(world, rng: RandomNumberGenerator) -> void:
	var mats = world.mats
	var terrain = world.terrain
	var ground := Callable(terrain, "get_height")
	# Ipês: marcos visuais do mapa.
	for kind in ["ipe", "ipe", "ipe_roxo", "ipe"]:
		var pos := _find_spot(world, rng, 10.0, 48.0, 5.0, 14.0, 2.6)
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
	# Árvores retorcidas do cerrado.
	for _i in 16:
		var pos := _find_spot(world, rng, 6.0, 57.0, 3.8, 8.0, 2.0)
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
	for _i in 9:
		var pos := _find_spot(world, rng, 5.0, 58.0, 2.5, 4.0, 1.2)
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
	# Pedras.
	for _i in 22:
		var size := rng.randf_range(0.35, 1.5)
		var pos := _find_spot(world, rng, 4.0, 60.0, 2.0 + size, 2.5, size)
		if pos == Vector2.INF:
			continue
		var geo := _sub_rng(rng)
		var rock := _ai("pedra", Vector3(size * 2.0, 0, size * 2.0), size * 0.85, size)
		if rock == null:
			rock = Props.build_rock(geo, mats, size)
		_put(rock, Vector3(pos.x, _min_height(terrain, pos, size) - size * 0.12, pos.y), rng)
		obstacles.append(Vector3(pos.x, pos.y, size * 0.9))
	# Arbustos decorativos.
	for _i in 18:
		var size := rng.randf_range(0.6, 1.2)
		var pos := _find_spot(world, rng, 4.0, 60.0, 2.2, 3.0, size * 0.6)
		if pos == Vector2.INF:
			continue
		var geo := _sub_rng(rng)
		var shrub := _ai("arbusto", Vector3(0, size * 1.3, 0), size * 0.55, size)
		if shrub == null:
			shrub = Props.build_shrub(geo, mats, size)
		_put(shrub, Vector3(pos.x, terrain.get_height(pos.x, pos.y) - 0.04, pos.y), rng)
		obstacles.append(Vector3(pos.x, pos.y, size * 0.55))
	# Troncos caídos.
	for _i in 4:
		var pos := _find_spot(world, rng, 8.0, 55.0, 3.5, 4.0, 2.0)
		if pos == Vector2.INF:
			continue
		var geo := _sub_rng(rng)
		var log_node := _ai("tronco_caido", Vector3(3.6, 0, 0), 0.0, 0.0)
		if log_node == null:
			log_node = Props.build_log(geo, mats)
		_put(log_node, Vector3(pos.x, terrain.get_height(pos.x, pos.y) - 0.05, pos.y), rng)
		obstacles.append(Vector3(pos.x, pos.y, 1.2))
	# Anel de árvores ao fundo (horizonte).
	for i in 52:
		var a := TAU * i / 52.0 + rng.randf_range(-0.05, 0.05)
		var r := rng.randf_range(66.0, 84.0)
		var pos := Vector2(cos(a), sin(a)) * r
		var origin := Vector3(pos.x, terrain.get_height(pos.x, pos.y) - 0.1, pos.y)
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
	for o in obstacles:
		terrain.mask_paint(o.x, o.y, o.z + 0.25, 2, 1.0)


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
		if pos.distance_to(n.center2) < n.radius + 3.0 + radius:
			return false
	for f in world.food_sources:
		if pos.distance_to(f) < 3.0 + radius:
			return false
	for q in world.satellite_spots:
		if pos.distance_to(q) < 2.5 + radius:
			return false
	if pos.distance_to(world.player_start) < 5.0:
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
