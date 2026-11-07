extends RefCounted
## Fábrica de elementos do cerrado feitos por código: árvores retorcidas, ipês,
## cupinzeiros, pedras, arbustos, troncos caídos, capim e flores.
## Tudo com formas suaves e arredondadas (estilo animação, nada de low poly).

const MeshBuilder := preload("res://scripts/procedural/mesh_builder.gd")

static var noise: FastNoiseLite = _make_noise()


static func _make_noise() -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = 4242
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.06
	n.fractal_octaves = 3
	return n


static func _rand_unit(rng: RandomNumberGenerator) -> Vector3:
	var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
	while v.length_squared() > 1.0 or v.length_squared() < 0.01:
		v = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
	return v.normalized()


static func _perp(v: Vector3) -> Vector3:
	var p := v.cross(Vector3.UP)
	if p.length_squared() < 0.0001:
		p = v.cross(Vector3.RIGHT)
	return p.normalized()


## Pinta COLOR.r (sombreamento) e COLOR.a (balanço) pelas normais.
static func _shade_by_normal(b: MeshBuilder, from: int, lo: float, hi: float, sway: float) -> void:
	for i in range(from, b.verts.size()):
		var n := b.normals[i]
		var s := lerpf(lo, hi, clampf(n.y * 0.5 + 0.5, 0.0, 1.0))
		b.colors[i] = Color(s, 0.0, 0.0, sway)


static func _add_canopy(core: MeshBuilder, cards: MeshBuilder, rng: RandomNumberGenerator,
		center: Vector3, radius: Vector3, card_count: int, card_size: float, subdiv: int = 2,
		solid: bool = true) -> void:
	# As árvores não têm miolo sólido: de longe ele aparecia como um bloco
	# escuro preso no galho (parecia um ninho). A copa delas é só de folhas.
	if solid:
		var start := core.verts.size()
		core.add_blob(center, radius * 0.7, noise, 0.32, subdiv, 1.4)
		_shade_by_normal(core, start, 0.05, 0.75, 0.35)
	for _i in card_count:
		var d := _rand_unit(rng)
		d.y = absf(d.y) * 0.9 + 0.1 if rng.randf() < 0.75 else d.y
		d = d.normalized()
		var base := center + d * radius * rng.randf_range(0.62, 0.95)
		var up_axis := (d + _rand_unit(rng) * 0.9).normalized()
		var side := up_axis.cross(_rand_unit(rng)).normalized()
		var s := card_size * rng.randf_range(0.75, 1.25)
		var tip := base + up_axis * s
		var shade := clampf(0.5 + 0.5 * (d.y * 0.5 + 0.5) + rng.randf_range(-0.08, 0.08), 0.0, 1.0)
		cards.color = Color(shade, 0.0, 0.0, 1.0)
		var a := cards.add_vertex(base - side * s * 0.5, d, Vector2(0, 1))
		var b := cards.add_vertex(base + side * s * 0.5, d, Vector2(1, 1))
		var c := cards.add_vertex(tip + side * s * 0.5, d, Vector2(1, 0))
		var e := cards.add_vertex(tip - side * s * 0.5, d, Vector2(0, 0))
		cards.add_quad(a, b, c, e)


static func _grow(bark: MeshBuilder, core: MeshBuilder, cards: MeshBuilder, rng: RandomNumberGenerator,
		pos: Vector3, dir: Vector3, length: float, radius: float, depth: int, p: Dictionary) -> void:
	var max_depth: int = p.get("depth", 2)
	var steps := 6 if depth == 0 else 5
	var pts := PackedVector3Array([pos])
	var radii := PackedFloat32Array([radius * (1.45 if depth == 0 else 1.0)])
	var cur := pos
	var d := dir
	var twist: float = p.get("twist", 0.45)
	for i in steps:
		d = (d + _rand_unit(rng) * twist + Vector3.UP * float(p.get("up_pull", 0.08))).normalized()
		cur += d * length / steps
		pts.append(cur)
		radii.append(lerpf(radius, radius * 0.62, float(i + 1) / steps))
	var sides := 12 if depth == 0 else (9 if depth == 1 else 7)
	bark.add_tube(pts, radii, sides, false, depth == max_depth, 0.6)
	var leafless: bool = p.get("leafless", false)
	if depth >= max_depth:
		var csize: float = p.get("canopy", 1.2) * rng.randf_range(0.8, 1.2)
		var ccenter := cur + d * csize * 0.35 + Vector3.UP * csize * 0.2
		_add_canopy(core, cards, rng, ccenter, Vector3(csize, csize * float(p.get("canopy_flat", 0.72)), csize),
			int(p.get("cards", 55)), float(p.get("card_size", 0.75)), int(p.get("subdiv", 2)), false)
		if leafless and rng.randf() < 0.5:
			# Galhos finos extras aparecendo entre as flores.
			pass
		return
	var children := rng.randi_range(2, 3) if depth > 0 else rng.randi_range(2, 4)
	for c in children:
		var az := TAU * (float(c) / children) + rng.randf_range(-0.5, 0.5)
		var out := Vector3(cos(az), 0.0, sin(az))
		var spread: float = p.get("spread", 0.75)
		var cdir := (d * (1.0 - spread * 0.6) + out * spread + Vector3.UP * 0.25).normalized()
		var at := pts[pts.size() - 1 - (rng.randi_range(0, 1) if depth == 0 else 0)]
		_grow(bark, core, cards, rng, at, cdir, length * rng.randf_range(0.55, 0.75),
			radius * rng.randf_range(0.55, 0.68), depth + 1, p)


## Árvore do cerrado (tronco retorcido e copa em tufos) ou ipê florido,
## já com colisão no tronco. `origin` + `ground_fn` acomodam as flores caídas no chão.
static func build_tree(rng: RandomNumberGenerator, mats, kind: String = "cerrado",
		detail: float = 1.0, origin: Vector3 = Vector3.ZERO, ground_fn: Callable = Callable()) -> Node3D:
	var p := {}
	var height := rng.randf_range(4.0, 6.5)
	var radius := rng.randf_range(0.16, 0.26)
	match kind:
		"ipe", "ipe_roxo":
			height = rng.randf_range(6.5, 8.5)
			radius = rng.randf_range(0.22, 0.3)
			p = {"canopy": 1.25, "canopy_flat": 0.85, "cards": int(150 * detail), "card_size": 0.85,
				"twist": 0.3, "spread": 0.6, "depth": 2, "up_pull": 0.14, "leafless": true}
		"background":
			p = {"canopy": 1.6, "canopy_flat": 0.7, "cards": int(40 * detail), "card_size": 1.3,
				"twist": 0.4, "spread": 0.8, "depth": 1, "subdiv": 1}
		_:
			p = {"canopy": 1.25, "canopy_flat": 0.68, "cards": int(130 * detail), "card_size": 0.95,
				"twist": 0.5, "spread": 0.85, "depth": 2}
	var bark := MeshBuilder.new()
	var core := MeshBuilder.new()
	var cards := MeshBuilder.new()
	var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
	var dir := (Vector3.UP + lean * rng.randf_range(0.12, 0.4)).normalized()
	_grow(bark, core, cards, rng, Vector3(0, -0.15, 0), dir, height * 0.42, radius, 0, p)
	var core_mat = mats.leaves_core
	var cards_mat = mats.leaves_cards
	if kind == "ipe":
		core_mat = mats.ipe_core
		cards_mat = mats.ipe_cards
	elif kind == "ipe_roxo":
		core_mat = mats.ipe_roxo_core
		cards_mat = mats.ipe_roxo_cards
	var mesh := bark.commit(null, mats.bark)
	if not core.verts.is_empty():
		core.commit(mesh, core_mat)
	cards.commit(mesh, cards_mat)
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	root.add_child(mi)
	if kind == "ipe" or kind == "ipe_roxo":
		root.add_child(_fallen_flowers(rng, kind == "ipe", mats, origin, ground_fn))
	if kind != "background":
		_add_cylinder_collider(root, radius * 1.3, 3.0)
	return root


static func _fallen_flowers(rng: RandomNumberGenerator, yellow: bool, mats, origin: Vector3,
		ground_fn: Callable) -> MeshInstance3D:
	var b := MeshBuilder.new()
	for _i in 160:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 3.8
		var p := Vector3(cos(a) * r, 0.03, sin(a) * r)
		if ground_fn.is_valid():
			p.y = float(ground_fn.call(origin.x + p.x, origin.z + p.z)) - origin.y + 0.03
		var s := rng.randf_range(0.18, 0.32)
		var rot := rng.randf() * TAU
		var x := Vector3(cos(rot), 0, sin(rot)) * s
		var z := Vector3(-sin(rot), 0, cos(rot)) * s
		b.color = Color(rng.randf_range(0.55, 0.9), 0, 0, 0)
		var i0 := b.add_vertex(p - x - z, Vector3.UP, Vector2(0, 0))
		var i1 := b.add_vertex(p + x - z, Vector3.UP, Vector2(1, 0))
		var i2 := b.add_vertex(p + x + z, Vector3.UP, Vector2(1, 1))
		var i3 := b.add_vertex(p - x + z, Vector3.UP, Vector2(0, 1))
		b.add_quad(i0, i3, i2, i1)
	var mat: Material = mats.ipe_ground
	if not yellow:
		mat = mats.ipe_roxo_cards.duplicate()
		mat.set_shader_parameter("sway", 0.0)
	var mi := MeshInstance3D.new()
	mi.name = "FallenFlowers"
	mi.mesh = b.commit(null, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _add_cylinder_collider(root: Node3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position.y = height * 0.5
	body.add_child(col)
	root.add_child(body)


## Cupinzeiro: torre de barro com camadas arredondadas.
static func build_termite_mound(rng: RandomNumberGenerator, mats) -> Node3D:
	var b := MeshBuilder.new()
	var height := rng.randf_range(0.9, 2.4)
	var radius := rng.randf_range(0.55, 0.95) * (0.7 + height * 0.18)
	var axis := Vector3(rng.randf_range(-0.12, 0.12), 1.0, rng.randf_range(-0.12, 0.12)).normalized()
	var layers := 4 + int(height)
	for i in layers:
		var t := float(i) / (layers - 1)
		var r := lerpf(radius, radius * 0.32, pow(t, 0.8))
		var c := axis * height * lerpf(0.12, 0.88, t)
		c += Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))
		b.color = Color.WHITE.darkened(rng.randf_range(0.0, 0.12))
		b.add_blob(c, Vector3(r, height / layers * 1.4, r * rng.randf_range(0.85, 1.1)), noise, 0.28, 3, 1.8)
	# Pequenas torres laterais.
	for _k in rng.randi_range(0, 2):
		var ang := rng.randf() * TAU
		var off := Vector3(cos(ang), 0, sin(ang)) * radius * 0.7
		var h2 := height * rng.randf_range(0.35, 0.6)
		b.add_blob(off + Vector3.UP * h2 * 0.45, Vector3(radius * 0.38, h2 * 0.55, radius * 0.38), noise, 0.3, 2, 2.0)
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(null, mats.clay)
	root.add_child(mi)
	_add_cylinder_collider(root, radius * 0.9, height)
	root.set_meta("radius", radius)
	return root


static func build_rock(rng: RandomNumberGenerator, mats, size: float) -> Node3D:
	var b := MeshBuilder.new()
	var basis := Basis(Vector3.UP, rng.randf() * TAU)
	b.add_blob(Vector3(0, size * 0.25, 0), Vector3(size, size * rng.randf_range(0.5, 0.8), size * rng.randf_range(0.7, 1.0)),
		noise, 0.42, 3, 0.9 + rng.randf(), basis, -size * 0.1)
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(null, mats.rock)
	root.add_child(mi)
	_add_cylinder_collider(root, size * 0.85, size)
	return root


## Arbusto folhoso (também serve de fonte de folhas para as saúvas).
static func build_shrub(rng: RandomNumberGenerator, mats, size: float, collider: bool = true) -> Node3D:
	var core := MeshBuilder.new()
	var cards := MeshBuilder.new()
	var stems := MeshBuilder.new()
	var clumps := rng.randi_range(3, 5)
	for i in clumps:
		var a := TAU * i / clumps + rng.randf_range(-0.4, 0.4)
		var r := size * rng.randf_range(0.2, 0.55)
		var c := Vector3(cos(a) * r, size * rng.randf_range(0.45, 0.8), sin(a) * r)
		_add_canopy(core, cards, rng, c, Vector3.ONE * size * rng.randf_range(0.42, 0.6), int(55 * size + 20), 0.45 * size + 0.18, 2)
		stems.add_tube(PackedVector3Array([Vector3.ZERO, c * 0.5, c]), PackedFloat32Array([0.04, 0.03, 0.02]), 6, false, true)
	var mesh := stems.commit(null, mats.bark)
	core.commit(mesh, mats.shrub_core)
	cards.commit(mesh, mats.shrub_cards)
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	root.add_child(mi)
	if collider:
		_add_cylinder_collider(root, size * 0.55, size)
	return root


static func build_log(rng: RandomNumberGenerator, mats) -> Node3D:
	var b := MeshBuilder.new()
	var length := rng.randf_range(2.5, 4.5)
	var radius := rng.randf_range(0.16, 0.26)
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 7:
		var t := float(i) / 6.0
		pts.append(Vector3(lerpf(-length * 0.5, length * 0.5, t), radius * 0.85 + sin(t * PI) * 0.05, sin(t * 3.0) * 0.18))
		radii.append(radius * (1.0 - t * 0.25))
	b.add_tube(pts, radii, 12, true, true, 0.5)
	# Galho quebrado.
	b.add_tube(PackedVector3Array([pts[3], pts[3] + Vector3(0.2, 0.45, 0.3), pts[3] + Vector3(0.3, 0.8, 0.5)]),
		PackedFloat32Array([radius * 0.45, radius * 0.3, radius * 0.18]), 8, false, true)
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(null, mats.log_bark)
	root.add_child(mi)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = length
	col.shape = shape
	col.rotation_degrees = Vector3(0, 0, 90)
	col.position.y = radius
	body.add_child(col)
	root.add_child(body)
	root.set_meta("radius", length * 0.5)
	return root


## Tufo de capim: várias folhas curvas e afinando, com COLOR.r = altura.
## `lite`: versão para longe, com as mesmas folhas em 2 gomos em vez de 4 (3
## triângulos por folha em vez de 7). Com o mesmo estado do sorteio, sai a
## mesma touceira.
static func build_grass_clump(rng: RandomNumberGenerator, blades: int, seed_heads: bool, lite: bool = false) -> ArrayMesh:
	var b := MeshBuilder.new()
	for i in blades:
		var start := b.verts.size()
		var ang := TAU * i / blades + rng.randf_range(-0.5, 0.5)
		var out := Vector3(cos(ang), 0, sin(ang))
		var h := rng.randf_range(0.55, 1.0)
		var lean := rng.randf_range(0.2, 0.6)
		var base := out * rng.randf_range(0.0, 0.2) + Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
		# Folha levemente torcida para não ficar plana demais.
		var side := Vector3(-out.z, 0, out.x).rotated(Vector3.UP, rng.randf_range(-0.6, 0.6))
		var pts := PackedVector3Array()
		var widths := PackedFloat32Array()
		var hs := PackedFloat32Array()
		var w0 := rng.randf_range(0.05, 0.075)
		var segs := 2 if lite else 4
		for k in segs + 1:
			var t := float(k) / segs
			pts.append(base + Vector3.UP * h * t + out * h * lean * t * t)
			widths.append(w0 * pow(1.0 - t, 0.6) * (1.15 if lite else 1.0) if k < segs else 0.0)
			hs.append(t * h)
		b.add_ribbon(pts, widths, side, out, hs)
		var rnd := rng.randf()
		for v in range(start, b.verts.size()):
			b.colors[v] = Color(b.uvs[v].y, rnd, 0, 1)
	if seed_heads:
		for i in rng.randi_range(2, 3):
			var start := b.verts.size()
			var ang := rng.randf() * TAU
			var out := Vector3(cos(ang), 0, sin(ang))
			var side := Vector3(-out.z, 0, out.x)
			var h := rng.randf_range(1.25, 1.6)
			var pts := PackedVector3Array()
			var widths := PackedFloat32Array()
			var hs := PackedFloat32Array()
			var ts: Array = [0.0, 0.62, 0.81, 1.0] if lite else [0.0, 1 / 6.0, 2 / 6.0, 3 / 6.0, 4 / 6.0, 5 / 6.0, 1.0]
			for k in ts.size():
				var t: float = ts[k]
				pts.append(Vector3.UP * h * t + out * 0.25 * t * t)
				var w := 0.012
				if t > 0.62:
					w = 0.05 * sin((t - 0.62) / 0.38 * PI) + 0.004
				widths.append(w if k < ts.size() - 1 else 0.0)
				hs.append(t * h)
			b.add_ribbon(pts, widths, side, out, hs)
			for v in range(start, b.verts.size()):
				b.colors[v] = Color(clampf(b.uvs[v].y, 0.0, 1.3), 0.95, 0, 1)
	return b.commit()


## Florzinha: caule + cabeça com cinco pétalas. COLOR.g = 1 nas pétalas.
static func build_flower_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.color = Color(0, 0, 0, 1)
	var stem := PackedVector3Array([Vector3.ZERO, Vector3(0.01, 0.12, 0), Vector3(0.0, 0.24, 0.01)])
	b.add_ribbon(stem, PackedFloat32Array([0.012, 0.01, 0.008]), Vector3.RIGHT, Vector3.BACK, PackedFloat32Array([0.0, 0.5, 1.0]))
	for v in b.verts.size():
		b.colors[v] = Color(b.uvs[v].y, 0, 0, 1)
	var center := Vector3(0.0, 0.245, 0.01)
	b.color = Color(1.0, 1.0, 0, 1)
	var c := b.add_vertex(center + Vector3.UP * 0.008, Vector3.UP, Vector2(0.5, 0.5))
	var ring := []
	for k in 10:
		var a := TAU * k / 10.0
		var r := 0.05 if k % 2 == 0 else 0.022
		ring.append(b.add_vertex(center + Vector3(cos(a) * r, 0.006 if k % 2 == 0 else 0.0, sin(a) * r), Vector3.UP, Vector2(0.5, 0.5)))
	for k in 10:
		b.add_tri(c, ring[(k + 1) % 10], ring[k])
	return b.commit()
