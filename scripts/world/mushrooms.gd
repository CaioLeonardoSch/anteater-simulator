extends Node3D
## Cogumelos: grupinhos laranja-dourados ao pé de árvores, troncos, arbustos e
## cupinzeiros. A língua pega um grupinho inteiro e ele dá o Frenesi, como a
## tanajura. Comido, nasce de novo no mesmo lugar, pequenino, e vai crescendo
## devagar (GROW_TIME); só dá para comer quando está inteiro.
## Usa um gerador só seu: o resto do mapa não muda de lugar.

const MeshBuilder := preload("res://scripts/procedural/mesh_builder.gd")

const SEED := 4417
## Quantos grupinhos no mapa.
const COUNT := 14
## Distância mínima entre dois grupinhos (m).
const SPACING := 7.0
## Quanto tempo leva crescendo de novo, de pequenino a inteiro (s).
const GROW_TIME := 90.0
## Tamanho do grupinho logo depois de comido (fração do inteiro).
const SPROUT := 0.15
const RING_SHADER := preload("res://shaders/anel_progresso.gdshader")
## Altura e tamanho do anel que mostra quanto falta para crescer (m).
const RING_Y := 0.5
const RING_SIZE := 0.16
## Raio do grupinho para a língua pegar (somado ao raio da lambida).
const REACH := 0.24
## Altura do meio do grupinho (onde a língua encosta).
const CENTER_Y := 0.13

## Posição de cada grupinho no chão.
var spots: Array[Vector3] = []
var nodes: Array[MeshInstance3D] = []
## Anel em cima de cada grupinho que ainda está crescendo (a borda vai enchendo).
var rings: Array[MeshInstance3D] = []
## Crescendo de novo: 0..1 (1 = inteiro).
var grow := PackedFloat32Array()
## Grupinho preso na língua (ou -1).
var carried := -1


func build(world) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.6
	mat.rim_enabled = true
	mat.rim = 0.35
	mat.rim_tint = 0.6
	var variants: Array[ArrayMesh] = []
	for n in [3, 4, 5, 2]:
		variants.append(_cluster_mesh(rng, n, mat))
	# Pé de árvores, troncos, arbustos e cupinzeiros (os obstáculos médios).
	var bases: Array[Vector3] = []
	for o in world.vegetation.obstacles:
		if o.z >= 0.3 and o.z <= 1.3:
			bases.append(o)
	for _attempt in 800:
		if spots.size() >= COUNT or bases.is_empty():
			break
		var o: Vector3 = bases[rng.randi() % bases.size()]
		var a := rng.randf() * TAU
		var p := Vector2(o.x, o.y) + Vector2(cos(a), sin(a)) * (o.z + rng.randf_range(0.3, 0.6))
		if not _spot_ok(world, p):
			continue
		var y: float = world.terrain.get_height(p.x, p.y)
		spots.append(Vector3(p.x, y, p.y))
		# Clareirinha sem capim em volta (o capim alto esconderia o grupinho).
		world.terrain.mask_paint(p.x, p.y, 0.75, 2, 1.0)
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = RING_SHADER
	var ring_mesh := QuadMesh.new()
	ring_mesh.size = Vector2.ONE * RING_SIZE
	ring_mesh.material = ring_mat
	for i in spots.size():
		var mi := MeshInstance3D.new()
		mi.name = "Cogumelos%d" % i
		mi.mesh = variants[i % variants.size()]
		mi.position = spots[i] - Vector3(0, 0.01, 0)
		mi.rotation.y = rng.randf() * TAU
		mi.visibility_range_end = 45.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		nodes.append(mi)
		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.position = spots[i] + Vector3(0, RING_Y, 0)
		ring.visibility_range_end = 18.0
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		rings.append(ring)
	grow.resize(spots.size())
	grow.fill(1.0)


func _spot_ok(world, p: Vector2) -> bool:
	if world.trails.distance_to_trails(p) < 1.3:
		return false
	for n in world.nests:
		if p.distance_to(n.center2) < n.radius + 1.5:
			return false
	for f in world.food_sources:
		if p.distance_to(f) < 2.0:
			return false
	for q in world.satellite_spots:
		if p.distance_to(q) < 1.5:
			return false
	for w in world.ponds:
		if p.distance_to(Vector2(w.x, w.y)) < w.z + 1.0:
			return false
	var angle := atan2(p.y, p.x)
	if p.length() > world.cliffs.radius_at(angle) - 2.0:
		return false
	if p.distance_to(world.cliffs.cave_mouth()) < 6.0 or world.near_cave_path(p, 1.0):
		return false
	# Fora de qualquer tronco ou pedra (o grupinho fica no chão, ao lado).
	for o in world.vegetation.obstacles:
		if p.distance_to(Vector2(o.x, o.y)) < o.z + 0.15:
			return false
	for s in spots:
		if p.distance_to(Vector2(s.x, s.z)) < SPACING:
			return false
	return true


## Grupinho de `n` cogumelos: pé claro, chapéu laranja-dourado com pintinhas
## creme e a parte de baixo (lamelas) mais clara.
func _cluster_mesh(rng: RandomNumberGenerator, n: int, mat: Material) -> ArrayMesh:
	var mb := MeshBuilder.new()
	for k in n:
		var big := k == 0
		var off := Vector3.ZERO if big else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.09, 0.19)
		var cap_r := rng.randf_range(0.095, 0.115) if big else rng.randf_range(0.05, 0.08)
		var h := cap_r * rng.randf_range(1.6, 2.2)
		var lean := Vector3(off.x, 0, off.z).normalized() * rng.randf_range(0.1, 0.3) if not big else Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
		var up := (Vector3.UP + lean).normalized()
		var top := off + up * h
		var stem_r := cap_r * 0.24
		# Pé: um pouco mais grosso embaixo, curvinho.
		mb.color = Color(0.90, 0.84, 0.70)
		var mid := off + up * h * 0.5 + Vector3(lean.z, 0, -lean.x) * 0.02
		mb.add_tube(PackedVector3Array([off - Vector3(0, 0.01, 0), mid, top]),
			PackedFloat32Array([stem_r * 1.3, stem_r, stem_r * 0.9]), 7, false, false)
		var basis := Basis(Quaternion(Vector3.UP, up))
		# Lamelas: disco claro embaixo do chapéu.
		mb.color = Color(0.93, 0.85, 0.66)
		mb.add_ellipsoid(top - up * cap_r * 0.05, Vector3(cap_r * 0.93, cap_r * 0.12, cap_r * 0.93), 4, 12, basis)
		# Chapéu: meia cúpula achatada, laranja a dourado.
		var t := rng.randf()
		mb.color = Color(0.86, 0.42, 0.10).lerp(Color(0.95, 0.66, 0.18), t)
		mb.add_ellipsoid(top + up * cap_r * 0.02, Vector3(cap_r, cap_r * 0.55, cap_r), 7, 14, basis, -0.15)
		# Pintinhas creme no chapéu.
		mb.color = Color(0.98, 0.92, 0.78)
		for _s in rng.randi_range(3, 6):
			var sa := rng.randf() * TAU
			var sr := rng.randf_range(0.2, 0.75)
			var local := Vector3(cos(sa) * sr, sqrt(maxf(1.0 - sr * sr, 0.0)), sin(sa) * sr)
			var sp := top + up * cap_r * 0.02 + basis * (local * Vector3(cap_r, cap_r * 0.55, cap_r))
			var spot_r := cap_r * rng.randf_range(0.1, 0.17)
			mb.add_ellipsoid(sp, Vector3(spot_r, spot_r * 0.35, spot_r), 3, 6, Basis(Quaternion(Vector3.UP, (basis * local).normalized())))
	return mb.commit(null, mat)


func _process(delta: float) -> void:
	for i in spots.size():
		if grow[i] < 1.0 and i != carried:
			grow[i] = minf(grow[i] + delta / GROW_TIME, 1.0)
			_show_size(i)


func _show_size(i: int) -> void:
	nodes[i].scale = Vector3.ONE * lerpf(SPROUT, 1.0, grow[i])
	rings[i].visible = grow[i] < 1.0
	rings[i].set_instance_shader_parameter("progress", grow[i])


func is_ready(i: int) -> bool:
	return grow[i] >= 1.0 and i != carried


func center(i: int) -> Vector3:
	return spots[i] + Vector3(0, CENTER_Y, 0)


## Grupinho mais perto de `p` que a lambida (raio `radius`) alcança, ou -1.
func near(p: Vector3, radius: float) -> int:
	var best := -1
	var best_d := radius + REACH
	for i in spots.size():
		if not is_ready(i):
			continue
		var d := center(i).distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


## Grupinho que a língua cruza indo reta de `from` até `to` (o mais perto de
## `from`), ou -1.
func on_path(from: Vector3, to: Vector3, radius: float) -> int:
	var best := -1
	var best_t := INF
	var seg := to - from
	var len2 := seg.length_squared()
	if len2 < 0.0001:
		return -1
	for i in spots.size():
		if not is_ready(i):
			continue
		var c := center(i)
		var t := clampf((c - from).dot(seg) / len2, 0.0, 1.0)
		if c.distance_to(from + seg * t) < radius + REACH and t < best_t:
			best_t = t
			best = i
	return best


## A língua pegou o grupinho: ele sai do chão e acompanha a ponta.
func grab(i: int) -> void:
	carried = i


func carry(i: int, at: Vector3, shrink: float) -> void:
	nodes[i].position = at - Vector3(0, CENTER_Y, 0) * shrink
	nodes[i].scale = Vector3.ONE * shrink


## Engolido: nasce de novo no mesmo lugar, pequenino.
func eat(i: int) -> void:
	if carried == i:
		carried = -1
	nodes[i].position = spots[i] - Vector3(0, 0.01, 0)
	grow[i] = 0.0
	_show_size(i)


## Para o jogo salvo: quanto cada grupinho já cresceu.
func to_save() -> Array:
	return Array(grow)


func from_save(data: Array) -> void:
	for i in mini(data.size(), spots.size()):
		grow[i] = clampf(float(data[i]), 0.0, 1.0)
		_show_size(i)
