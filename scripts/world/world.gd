extends Node3D
## Monta a fase "Cerrado ao Entardecer" (a clareira, área 1): céu, sol, terreno,
## penhascos com a caverna e a saída, trilhas, formigueiros, vegetação, lagoas,
## o tronco caído, o cupinzeiro gigante ao longe, capim e partículas. A luz é a
## de um fim de tarde fixo (o sol não se põe).

const Materials := preload("res://scripts/world/materials.gd")
const Terrain := preload("res://scripts/world/terrain.gd")
const TrailNetwork := preload("res://scripts/world/trail_network.gd")
const Vegetation := preload("res://scripts/world/vegetation.gd")
const Grass := preload("res://scripts/world/grass.gd")
const Nest := preload("res://scripts/world/nest.gd")
const Props := preload("res://scripts/world/props.gd")
const ScentMarks := preload("res://scripts/world/scent_marks.gd")
const Cliffs := preload("res://scripts/world/cliffs.gd")
const GiantMound := preload("res://scripts/world/giant_mound.gd")
const WorldMap := preload("res://scripts/world/world_map.gd")
const MeshBuilder := preload("res://scripts/procedural/mesh_builder.gd")
const ModelLibrary := preload("res://scripts/model_library.gd")
const SKY_SHADER := preload("res://shaders/sky_dusk.gdshader")

const SEED := 20261102

var mats: Materials
var terrain: Terrain
var trails: TrailNetwork
var nests: Array = []
var food_sources: Array[Vector2] = []
var vegetation: Vegetation
var grass: Grass
var player_start := Vector2(2.0, 6.0)
## Câmaras no meio do campo (posição), para a vegetação não cobrir.
var satellite_spots: Array[Vector2] = []
## Nuvens e colunas de cheiro do faro.
var scent_marks: ScentMarks
## Penhascos em volta da clareira (limite do mapa), com a caverna e a passagem.
var cliffs: Cliffs
var giant_mound: GiantMound
## Lagoas (só enfeite): Vector3(x, z, raio).
var ponds: Array[Vector3] = []
## Os lobos de cada lagoa (uma lista de Vector3 por lagoa).
var pond_shapes: Array = []
## Trilha de terra (sem capim) da caverna até o formigueiro mais perto.
var cave_path := PackedVector2Array()
## Tronco caído que fecha a passagem para a área 2.
var exit_log: Node3D
## A clareira está 100% limpa: o tronco já pode ser quebrado.
var exit_breakable := false
## O tronco foi quebrado (a passagem está aberta).
var exit_open := false
var _exit_halves: Array[Node3D] = []
var _exit_body: StaticBody3D
var player_start_yaw := 0.0
var start_trail_index := 0

var env: Environment
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var dust: GPUParticles3D
var fireflies: GPUParticles3D

var day_progress := 0.0
var _day_target := 0.0
var _rng := RandomNumberGenerator.new()
var _nest_grid := PackedInt32Array()
var _nest_grid_n := 0
var _grass_quality_built := -1
var _shadow_atlas := 0

## 8 formigueiros numa clareira de ~50 m: 5 pequenos ("small", câmaras que
## Cavar já abre) perto da caverna (o começo), 2 médios ("medium", câmaras
## grandes, que pedem Fundura 1) e o grande ("big", com a rainha, que pede
## Fundura 2) do lado da saída para a área 2.
const NEST_LAYOUT := [
	{"name": "Formigueiro Leste", "pos": Vector2(14, 3), "kind": "small"},
	{"name": "Formigueiro Nordeste", "pos": Vector2(9, -11), "kind": "small"},
	{"name": "Formigueiro Sudeste", "pos": Vector2(6, 14), "kind": "small"},
	{"name": "Formigueiro Norte", "pos": Vector2(-3, -18), "kind": "small"},
	{"name": "Formigueiro do Centro", "pos": Vector2(2, 1), "kind": "small"},
	{"name": "Formigueiro Noroeste", "pos": Vector2(-9, -8), "kind": "medium"},
	{"name": "Formigueiro Sul", "pos": Vector2(-6, 17), "kind": "medium"},
	{"name": "Formigueiro da Rainha", "pos": Vector2(-15, 2), "kind": "big"},
]
## Arbustos onde as saúvas cortam folhas.
const FOOD_LAYOUT := [
	Vector2(10, -3), Vector2(-1, 9), Vector2(-15, -5), Vector2(2, -12), Vector2(-10, 10)]
## Trilhas: [formigueiro, arbusto].
const LINKS := [[0, 0], [1, 0], [1, 3], [2, 1], [3, 3], [4, 0], [4, 1],
	[5, 2], [5, 3], [6, 1], [6, 4], [7, 2], [7, 4]]
## Grade que diz qual formigueiro (se algum) cobre cada pedaço do mapa.
const NEST_GRID_CELL := 2.0
## Câmaras sozinhas no meio do campo, longe das trilhas (as formigas saem
## delas para passear).
const SATELLITE_COUNT := 12
const SATELLITES_PER_NEST := 2
const SATELLITE_SPACING := 6.0
## Trilha de referência para espalhar as câmaras do campo (formigueiro Leste ->
## arbusto 0).
const START_LINK := [0, 0]


func build() -> void:
	_rng.seed = SEED
	mats = Materials.new()
	_build_environment()
	# Formigueiros (tamanho de cada um) e o chão plano em volta deles.
	var spots: Array[Vector3] = []
	for i in NEST_LAYOUT.size():
		var nest: Nest = Nest.new()
		nest.name = "Nest%d" % i
		var kind: String = NEST_LAYOUT[i].kind
		var r: float = {"small": _rng.randf_range(2.4, 2.75), "medium": _rng.randf_range(2.9, 3.15), "big": _rng.randf_range(3.3, 3.6)}[kind]
		var h: float = {"small": _rng.randf_range(0.76, 0.88), "medium": _rng.randf_range(0.88, 0.98), "big": _rng.randf_range(1.0, 1.12)}[kind]
		nest.setup(i, NEST_LAYOUT[i].name, NEST_LAYOUT[i].pos, r, h, kind == "big", kind == "medium")
		nests.append(nest)
		spots.append(Vector3(nest.center2.x, nest.center2.y, r * 2.0 + 0.4))
	_build_nest_grid()
	for f in FOOD_LAYOUT:
		food_sources.append(f)
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.setup(SEED, spots)
	# Penhascos em volta: primeiro o formato (aplaina o chão da caverna e da
	# passagem); a malha vem depois, com o terreno pronto.
	cliffs = Cliffs.new()
	cliffs.name = "Penhascos"
	add_child(cliffs)
	cliffs.plan(terrain)
	# Trilhas.
	trails = TrailNetwork.new(SEED)
	for link in LINKS:
		var nest: Nest = nests[link[0]]
		var food: Vector2 = food_sources[link[1]]
		var dir := (food - nest.center2).normalized()
		nest.trail_dirs.append(dir)
		var start := nest.hole_position(dir)
		var end := food - dir * 0.9
		var t = trails.add_trail(start, end, link[0], link[1], _rng)
		nest.trail_ids.append(trails.trails.size() - 1)
		for k in range(0, t.points.size(), 2):
			var p: Vector2 = t.points[k]
			terrain.mask_paint(p.x, p.y, 0.62, 0, 1.0)
			terrain.mask_paint(p.x, p.y, 1.25, 0, 0.35)
	# Ponto ao lado da trilha de onde o jogo começava: ainda serve de referência
	# para espalhar as câmaras do campo sempre nos mesmos lugares (assim os jogos
	# salvos continuam valendo).
	for k in LINKS.size():
		if LINKS[k] == START_LINK:
			start_trail_index = k
	var start_trail = trails.trails[start_trail_index]
	var s0: float = start_trail.length * 0.5
	var trail_start: Vector2 = start_trail.point_at(s0) + start_trail.side_at(s0) * 1.4
	player_start = trail_start
	for nest in nests:
		terrain.mask_paint(nest.center2.x, nest.center2.y, nest.radius + 1.0, 1, 1.0)
	for f in food_sources:
		terrain.mask_paint(f.x, f.y, 1.6, 1, 0.8)
	# Nós dos formigueiros (com as câmaras longe dos olheiros das trilhas).
	# As câmaras são planejadas antes de montar qualquer monte, para o mapa não
	# mudar quando o visual dos montes muda.
	for nest in nests:
		nest.plan_chambers(_rng)
	_plan_satellites()
	_plan_ponds()
	_plan_cave_path()
	terrain.build(mats.terrain)
	cliffs.build(mats)
	# O tamanduá acorda no fundo da caverna, olhando para o cupinzeiro gigante.
	player_start = cliffs.cave_spot()
	var look := WorldMap.mound_world()
	var to := look - player_start
	player_start_yaw = atan2(-to.x, -to.y)
	for nest in nests:
		nest.position = Vector3(nest.center2.x, terrain.get_height(nest.center2.x, nest.center2.y), nest.center2.y)
		nest.ground = ground_height
		add_child(nest)
		nest.build(_rng, mats)
	# Arbustos onde as saúvas cortam folhas.
	for f in food_sources:
		var size := _rng.randf_range(1.0, 1.25)
		var shrub: Node3D = vegetation_ai("arbusto", Vector3(0, size * 1.3, 0))
		if shrub == null:
			shrub = Props.build_shrub(_rng, mats, size)
		shrub.position = Vector3(f.x, terrain.get_height(f.x, f.y) - 0.05, f.y)
		shrub.rotation.y = _rng.randf() * TAU
		add_child(shrub)
	vegetation = Vegetation.new()
	vegetation.name = "Vegetation"
	add_child(vegetation)
	vegetation.build(self, _rng)
	for f in food_sources:
		vegetation.obstacles.append(Vector3(f.x, f.y, 0.7))
	for w in ponds:
		vegetation.obstacles.append(w)
	_build_pond_water()
	_build_exit_log()
	giant_mound = GiantMound.new()
	add_child(giant_mound)
	giant_mound.build(mats, Color(0.92, 0.74, 0.6))
	mats.terrain.set_shader_parameter("mask_tex", terrain.finalize_mask())
	grass = Grass.new()
	grass.name = "Grass"
	add_child(grass)
	grass.build(terrain, mats, _rng, Settings.grass_density(), Settings.grass_view_distance())
	_grass_quality_built = Settings.grass_quality
	_build_particles()
	scent_marks = ScentMarks.new()
	scent_marks.name = "ScentMarks"
	add_child(scent_marks)
	scent_marks.setup(self)
	set_day_progress(0.0, true)
	apply_graphics()


## Até onde dá para andar nessa direção (penhascos, caverna e o tronco da saída).
func walk_limit(p2: Vector2) -> float:
	return cliffs.walk_limit(p2, exit_open)


## Trilha de terra, sem capim, da caverna até o formigueiro mais perto: mostra
## ao jogador por onde começar. Tem um sorteio próprio (o resto do mapa não muda).
func _plan_cave_path() -> void:
	var mouth := cliffs.cave_mouth()
	var target: Nest = null
	var best := INF
	for n in nests:
		var d: float = mouth.distance_to(n.center2) - n.radius
		if d < best:
			best = d
			target = n
	if target == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 47
	var start := cliffs.cave_spot()
	var inward := -mouth.normalized()
	var out := mouth + inward * 3.0
	var end: Vector2 = target.center2 + (out - target.center2).normalized() * (target.radius + 1.0)
	var side := (end - out).orthogonal().normalized()
	for attempt in 12:
		var bend := rng.randf_range(-3.5, 3.5) * (1.0 - attempt / 12.0)
		var ctrl := PackedVector2Array([start - inward * 2.0, start, mouth, out,
			(out + end) * 0.5 + side * bend, end, end + (end - target.center2).normalized() * -2.0])
		var pts := PackedVector2Array()
		for i in range(1, ctrl.size() - 2):
			var steps := maxi(2, int(ctrl[i].distance_to(ctrl[i + 1]) / 0.5))
			for k in steps:
				pts.append(_catmull(ctrl[i - 1], ctrl[i], ctrl[i + 1], ctrl[i + 2], float(k) / steps))
		pts.append(end)
		if _path_clear(pts, target):
			cave_path = pts
			break
	for q in cave_path:
		terrain.mask_paint(q.x, q.y, 0.72, 0, 1.0)
		terrain.mask_paint(q.x, q.y, 1.4, 0, 0.35)


func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)


## A trilha não passa por cima de outro formigueiro, de arbusto, câmara ou lagoa.
func _path_clear(pts: PackedVector2Array, target: Nest) -> bool:
	for q in pts:
		for n in nests:
			if n != target and q.distance_to(n.center2) < n.radius + 1.5:
				return false
		for f in food_sources:
			if q.distance_to(f) < 2.0:
				return false
		for c in satellite_spots:
			if q.distance_to(c) < 2.0:
				return false
		for w in ponds:
			if q.distance_to(Vector2(w.x, w.y)) < w.z + 1.0:
				return false
	return true


## Algum ponto da trilha da caverna está a menos de `dist` daqui?
func near_cave_path(p: Vector2, dist: float) -> bool:
	for q in cave_path:
		if p.distance_squared_to(q) < dist * dist:
			return true
	return false


## Lagoa de enfeite (uma só, na clareira pequena), de forma natural: um punhado
## de círculos que se sobrepõem (lobos), longe das trilhas, dos formigueiros,
## das câmaras, da caverna e da passagem.
## `ponds` guarda cada lobo (x, z, raio): quem desvia da água trata cada lobo
## como um círculo. `pond_shapes` guarda os lobos de cada lagoa.
func _plan_ponds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 31
	# Tamanho de cada lagoa (m, de uma ponta à outra, mais ou menos).
	for size in [8.0]:
		var placed := false
		var r: float = size * 0.5
		for attempt in 600:
			if attempt > 0 and attempt % 150 == 0:
				r *= 0.85
			var a := rng.randf() * TAU
			var c := Vector2(cos(a), sin(a)) * rng.randf_range(4.0, 22.0)
			var lobes: Array[Vector3] = [Vector3(c.x, c.y, r * rng.randf_range(0.55, 0.68))]
			var n := rng.randi_range(2, 4)
			var dir0 := rng.randf() * TAU
			for k in n:
				var ang := dir0 + TAU * k / n + rng.randf_range(-0.6, 0.6)
				var off: float = r * rng.randf_range(0.3, 0.58)
				lobes.append(Vector3(c.x + cos(ang) * off, c.y + sin(ang) * off, r * rng.randf_range(0.3, 0.5)))
			if not _pond_fits(lobes):
				continue
			_dig_pond(lobes)
			placed = true
			break
		if not placed:
			push_warning("Lagoa de %.0f m não coube no mapa." % size)


func _pond_fits(lobes: Array[Vector3]) -> bool:
	for l in lobes:
		var p := Vector2(l.x, l.y)
		var lr := l.z
		if trails.distance_to_trails(p) < lr + 1.8:
			return false
		if p.distance_to(cliffs.cave_mouth()) < lr + 8.0 or p.distance_to(cliffs.exit_center(0.0)) < lr + 8.0:
			return false
		if p.length() > walk_limit(p) - lr - 2.0:
			return false
		for nest in nests:
			if p.distance_to(nest.center2) < nest.radius + lr + 2.5:
				return false
		for f in food_sources:
			if p.distance_to(f) < lr + 2.5:
				return false
		for q in satellite_spots:
			if p.distance_to(q) < lr + 2.5:
				return false
		for w in ponds:
			if p.distance_to(Vector2(w.x, w.y)) < lr + w.z + 9.0:
				return false
	return true


## Cava a bacia da lagoa: cada lobo afunda o chão, todos na mesma altura de
## beira, e tira o capim de dentro.
func _dig_pond(lobes: Array[Vector3]) -> void:
	var level := INF
	for l in lobes:
		level = minf(level, terrain.natural_height(l.x, l.y))
	for l in lobes:
		terrain.add_flat_zone(l.x, l.y, l.z * 1.8, level)
	for l in lobes:
		terrain.add_dip(l.x, l.y, l.z, clampf(0.35 + l.z * 0.13, 0.5, 0.95))
		terrain.mask_paint(l.x, l.y, l.z + 0.5, 1, 1.0)
		# Lama molhada na beira (canal 3 da máscara, só para a cor do chão).
		terrain.mask_paint(l.x, l.y, l.z + 1.1, 3, 1.0)
		ponds.append(l)
	pond_shapes.append(lobes)


func _build_pond_water() -> void:
	var mat: ShaderMaterial = mats.water
	# O reflexo do paredão usa a distância média dele.
	var r := 0.0
	for i in 16:
		r += cliffs.radius_at(TAU * i / 16.0)
	mat.set_shader_parameter("cliff_radius", r / 16.0)
	for lobes in pond_shapes:
		_build_one_pond(lobes, mat)


## A água de uma lagoa: o contorno é a união dos lobos (alisada), mais clara e
## transparente na beira (raso) e escura no meio (fundo).
func _build_one_pond(lobes: Array, mat: Material) -> void:
	var c := Vector2(lobes[0].x, lobes[0].y)
	var segs := 72
	var radial := PackedFloat32Array()
	radial.resize(segs)
	for j in segs:
		var d := Vector2.RIGHT.rotated(TAU * j / segs)
		var best := 0.0
		for l in lobes:
			var o: Vector2 = Vector2(l.x, l.y) - c
			var t := o.dot(d)
			var perp2 := o.length_squared() - t * t
			var disc: float = l.z * l.z - perp2
			if disc >= 0.0:
				best = maxf(best, t + sqrt(disc))
		radial[j] = best
	# Alisa as quinas onde dois lobos se encontram.
	for _pass in 3:
		var sm := radial.duplicate()
		for j in segs:
			sm[j] = (radial[(j + segs - 1) % segs] + radial[j] * 2.0 + radial[(j + 1) % segs]) * 0.25
		radial = sm
	# Nível da água um pouco abaixo da beira mais baixa (a água nunca sobe no capim).
	var level := INF
	for j in segs:
		var q := c + Vector2.RIGHT.rotated(TAU * j / segs) * radial[j] * 0.93
		level = minf(level, terrain.get_height(q.x, q.y))
	level -= 0.06
	var deep := Color(0.035, 0.12, 0.13, 0.95)
	var mid := Color(0.07, 0.19, 0.18, 0.88)
	var shore := Color(0.22, 0.26, 0.17, 0.45)
	var b := MeshBuilder.new()
	b.color = deep
	b.add_vertex(Vector3.ZERO, Vector3.UP)
	for ring in [[0.55, mid], [1.0, shore]]:
		b.color = ring[1]
		for j in segs:
			var d := Vector2.RIGHT.rotated(TAU * j / segs) * radial[j] * float(ring[0])
			b.add_vertex(Vector3(d.x, 0.0, d.y), Vector3.UP)
	for j in segs:
		var j2 := (j + 1) % segs
		b.add_tri(0, 1 + j2, 1 + j)
		b.add_quad(1 + j, 1 + j2, 1 + segs + j2, 1 + segs + j)
	var mi := MeshInstance3D.new()
	mi.name = "Lagoa"
	mi.mesh = b.commit(null, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(c.x, level, c.y)
	add_child(mi)


## Tronco caído atravessado na passagem para a área 2 (em duas metades, que se
## abrem quando as garras quebram o tronco).
func _build_exit_log() -> void:
	var e := Vector2(cos(Cliffs.EXIT_ANGLE), sin(Cliffs.EXIT_ANGLE))
	var lateral := Vector2(-e.y, e.x)
	var c := cliffs.exit_center(1.6)
	var length := cliffs.exit_width() + 2.6
	var radius := 0.62
	exit_log = Node3D.new()
	exit_log.name = "TroncoCaido"
	exit_log.position = Vector3(c.x, terrain.get_height(c.x, c.y), c.y)
	exit_log.rotation.y = atan2(-lateral.y, lateral.x)
	add_child(exit_log)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * length * 0.5, 0.0, 0.0)
		exit_log.add_child(pivot)
		var b := MeshBuilder.new()
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for i in 6:
			var t := float(i) / 5.0
			pts.append(Vector3(-side * t * (length * 0.5 - 0.06), radius * 0.85 + sin(t * PI) * 0.06, sin(t * 2.6 + side) * 0.12))
			radii.append(radius * lerpf(1.0, 0.86, t) * (1.0 if side < 0.0 else 0.94))
		# Pontas com a madeira à mostra (sorteio próprio, para não mexer no resto).
		var lr := RandomNumberGenerator.new()
		lr.seed = 7 + int(side)
		b.use_uv2 = true
		var tube := b.vertex_count()
		b.add_tube(pts, radii, 14, false, false, 0.5)
		Props.add_log_end(b, lr, tube, 14, pts[0], (pts[0] - pts[1]).normalized(), radii[0], true)
		Props.add_log_end(b, lr, tube + 5 * 15, 14, pts[5], (pts[5] - pts[4]).normalized(), radii[5], false)
		# Toco de galho quebrado.
		var stub := pts[2] + Vector3(0, radius * 0.6, 0)
		var spts := PackedVector3Array([stub, stub + Vector3(0.1, 0.55, 0.25), stub + Vector3(0.2, 0.95, 0.35)])
		var branch := b.vertex_count()
		b.add_tube(spts, PackedFloat32Array([radius * 0.32, radius * 0.22, radius * 0.12]), 8, false, false, 0.5)
		Props.add_log_end(b, lr, branch + 2 * 9, 8, spts[2], (spts[2] - spts[1]).normalized(), radius * 0.12, false)
		var mi := MeshInstance3D.new()
		mi.mesh = b.commit(null, mats.log_bark)
		pivot.add_child(mi)
		_exit_halves.append(pivot)
	_exit_body = StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = length
	col.shape = shape
	col.rotation_degrees = Vector3(0, 0, 90)
	col.position.y = radius
	_exit_body.add_child(col)
	exit_log.add_child(_exit_body)


## Distância (no chão) até o tronco da saída é menor que `reach`?
func near_exit(p2: Vector2, reach: float) -> bool:
	if exit_log == null:
		return false
	var e := Vector2(cos(Cliffs.EXIT_ANGLE), sin(Cliffs.EXIT_ANGLE))
	var lateral := Vector2(-e.y, e.x)
	var c := cliffs.exit_center(1.6)
	var half := (cliffs.exit_width() + 2.6) * 0.5
	var along := clampf((p2 - c).dot(lateral), -half, half)
	return p2.distance_to(c + lateral * along) < reach


## As garras quebram o tronco: as duas metades se abrem e a passagem fica livre.
func break_exit() -> void:
	if exit_open:
		return
	exit_open = true
	if _exit_body:
		_exit_body.queue_free()
		_exit_body = null
	for k in _exit_halves.size():
		var pivot := _exit_halves[k]
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(pivot, "rotation:y", 1.25 if k == 0 else -1.25, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pivot, "rotation:x", 0.18 if k == 0 else -0.18, 0.9)
	_splinters(exit_log.global_position + Vector3(0, 0.6, 0))


func _splinters(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = 60
	p.lifetime = 1.3
	p.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6
	pm.direction = Vector3.UP
	pm.spread = 75.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	p.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.03, 0.18)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.38, 0.24)
	m.roughness = 1.0
	mesh.material = m
	p.draw_pass_1 = mesh
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)


## Espalha câmaras pelo campo, longe das trilhas, dos montes e dos arbustos.
## Cada uma pertence ao formigueiro mais perto (no máximo SATELLITES_PER_NEST).
## Espalha as câmaras do campo por igual: para cada uma sorteia vários
## lugares possíveis e fica com o mais longe das câmaras e montes que já
## existem (assim nenhum pedaço do mapa fica vazio nem amontoado).
func _plan_satellites() -> void:
	var per_nest := {}
	var tries := 0
	while satellite_spots.size() < SATELLITE_COUNT and tries < 400:
		tries += 1
		var best := Vector2.INF
		var best_owner: Nest = null
		var best_d := -INF
		for _cand in 40:
			var a := _rng.randf() * TAU
			var r := sqrt(_rng.randf_range(5.0 * 5.0, 22.0 * 22.0))
			var p := Vector2(cos(a), sin(a)) * r
			if p.length() > walk_limit(p) - 3.0:
				continue
			if trails.distance_to_trails(p) < 2.6 or p.distance_to(player_start) < 4.0:
				# (player_start aqui ainda é o ponto antigo, ao lado da trilha)
				continue
			var d := INF
			for n in nests:
				d = minf(d, p.distance_to(n.center2) - n.radius - 3.2)
			for f in food_sources:
				d = minf(d, p.distance_to(f) - 3.0)
			if d < 0.0:
				continue
			for q in satellite_spots:
				d = minf(d, p.distance_to(q) - SATELLITE_SPACING)
			if d < 0.0:
				continue
			var owner := nearest_nest(p)
			if int(per_nest.get(owner.index, 0)) >= SATELLITES_PER_NEST:
				continue
			if d > best_d:
				best_d = d
				best = p
				best_owner = owner
		if best_owner == null:
			continue
		var owner := best_owner
		var p := best
		per_nest[owner.index] = int(per_nest.get(owner.index, 0)) + 1
		var c := Nest.Chamber.new()
		c.satellite = true
		c.radius = _rng.randf_range(0.46, 0.54)
		c.pos2 = p
		c.local = p - owner.center2
		owner.chambers.append(c)
		satellite_spots.append(p)
		terrain.mask_paint(p.x, p.y, 1.3, 1, 1.0)


func vegetation_ai(model_name: String, target: Vector3) -> Node3D:
	return ModelLibrary.instantiate(model_name, target)


## Altura do chão (terreno + monte do formigueiro, se houver um ali).
## O tamanduá anda por cima dos montes, e as formigas também.
func ground_height(x: float, z: float) -> float:
	var h := terrain.get_height(x, z)
	var ix := int(floor(x / NEST_GRID_CELL)) + _nest_grid_n / 2
	var iz := int(floor(z / NEST_GRID_CELL)) + _nest_grid_n / 2
	if ix >= 0 and iz >= 0 and ix < _nest_grid_n and iz < _nest_grid_n:
		var k := _nest_grid[iz * _nest_grid_n + ix]
		if k >= 0:
			h += nests[k].dome_height(x, z)
	return h


## Marca, numa grade de 2 m, as células cobertas por cada monte (eles não se
## encostam, então cada célula tem no máximo um formigueiro).
func _build_nest_grid() -> void:
	_nest_grid_n = int(Terrain.SIZE / NEST_GRID_CELL)
	_nest_grid.resize(_nest_grid_n * _nest_grid_n)
	_nest_grid.fill(-1)
	var half := _nest_grid_n / 2
	for k in nests.size():
		var n: Nest = nests[k]
		var r := n.radius + 0.1
		var x0 := int(floor((n.center2.x - r) / NEST_GRID_CELL)) + half
		var x1 := int(floor((n.center2.x + r) / NEST_GRID_CELL)) + half
		var z0 := int(floor((n.center2.y - r) / NEST_GRID_CELL)) + half
		var z1 := int(floor((n.center2.y + r) / NEST_GRID_CELL)) + half
		for iz in range(maxi(z0, 0), mini(z1, _nest_grid_n - 1) + 1):
			for ix in range(maxi(x0, 0), mini(x1, _nest_grid_n - 1) + 1):
				_nest_grid[iz * _nest_grid_n + ix] = k


func nearest_nest(p: Vector2) -> Nest:
	var best: Nest = null
	var bd := INF
	for n in nests:
		var d := p.distance_squared_to(n.center2)
		if d < bd:
			bd = d
			best = n
	return best


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("cloud_noise", mats.cloud_noise)
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.05
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	# Contra o sol: pouco "bloom" (ele lavava a imagem de branco) e só o que é
	# bem claro brilha.
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.92, 0.72, 0.58)
	env.fog_light_energy = 1.0
	# A névoa do lado do sol fica mais quente, sem virar uma parede branca
	# (perspectiva aérea: o longe fica colorido, não esbranquiçado).
	env.fog_sun_scatter = 0.14
	env.fog_density = 0.0065
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.15
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.4
	env.ssao_power = 1.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.95, 0.8, 0.65)
	env.volumetric_fog_anisotropy = 0.35
	env.volumetric_fog_length = 48.0
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.6
	sun.shadow_blur = 1.2
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.4
	add_child(sun)


func _build_particles() -> void:
	# Poeira/pólen dourado flutuando contra a luz.
	dust = GPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 260
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.local_coords = false
	dust.visibility_aabb = AABB(Vector3(-20, -4, -20), Vector3(40, 10, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 2.5, 16)
	pm.gravity = Vector3(0, 0.02, 0)
	pm.direction = Vector3(0.6, 0.3, 0.4)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	dust.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.03)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(1.0, 0.85, 0.55, 0.6)
	qm.albedo_texture = _soft_dot()
	qm.disable_receive_shadows = true
	quad.material = qm
	dust.draw_pass_1 = quad
	add_child(dust)
	# Vaga-lumes (aparecem quando o sol baixa).
	fireflies = GPUParticles3D.new()
	fireflies.name = "Fireflies"
	fireflies.amount = 90
	fireflies.lifetime = 6.0
	fireflies.preprocess = 6.0
	fireflies.local_coords = false
	fireflies.emitting = false
	fireflies.visibility_aabb = AABB(Vector3(-25, -3, -25), Vector3(50, 8, 50))
	var fm := ParticleProcessMaterial.new()
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fm.emission_box_extents = Vector3(22, 1.2, 22)
	fm.gravity = Vector3.ZERO
	fm.spread = 180.0
	fm.initial_velocity_min = 0.1
	fm.initial_velocity_max = 0.35
	fm.turbulence_enabled = true
	fm.turbulence_noise_strength = 1.2
	fm.turbulence_noise_scale = 2.0
	var blink := Gradient.new()
	blink.set_color(0, Color(1, 1, 1, 0))
	blink.set_color(1, Color(1, 1, 1, 0))
	for k in 5:
		var t := 0.1 + k * 0.2
		blink.add_point(t, Color(1, 1, 1, 1))
		blink.add_point(t + 0.08, Color(1, 1, 1, 0.1))
	var blink_tex := GradientTexture1D.new()
	blink_tex.gradient = blink
	fm.color_ramp = blink_tex
	fireflies.process_material = fm
	var fq := QuadMesh.new()
	fq.size = Vector2(0.09, 0.09)
	var fqm := qm.duplicate()
	fqm.albedo_color = Color(0.85, 1.0, 0.35, 1.0)
	fqm.emission_enabled = true
	fqm.emission = Color(0.8, 1.0, 0.3)
	fqm.emission_energy_multiplier = 4.0
	fq.material = fqm
	fireflies.draw_pass_1 = fq
	add_child(fireflies)


func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	return t


## Move partículas para perto da câmera.
func follow_camera(cam_pos: Vector3) -> void:
	if dust:
		dust.global_position = cam_pos
	if fireflies:
		fireflies.global_position = Vector3(cam_pos.x, ground_height(cam_pos.x, cam_pos.z) + 0.9, cam_pos.z)


## 0 = início da fase (sol mais alto), 1 = fim (sol quase se pondo).
func set_day_progress(p: float, instant: bool = false) -> void:
	_day_target = clampf(p, 0.0, 1.0)
	if instant:
		day_progress = _day_target
		_apply_day()


func _process(delta: float) -> void:
	if absf(day_progress - _day_target) > 0.0005:
		day_progress = move_toward(day_progress, _day_target, delta * 0.02)
		_apply_day()


func _apply_day() -> void:
	var p := day_progress
	var elev := deg_to_rad(lerpf(17.0, 4.5, p))
	var azim := deg_to_rad(lerpf(-62.0, -72.0, p))
	var s := Vector3(sin(azim) * cos(elev), sin(elev), -cos(azim) * cos(elev))
	sun.basis = Basis.looking_at(-s, Vector3.UP)
	sun.light_color = Color(1.0, 0.78, 0.56).lerp(Color(1.0, 0.56, 0.36), p)
	sun.light_energy = lerpf(1.85, 1.25, p)
	env.ambient_light_energy = lerpf(1.05, 0.85, p)
	sky_mat.set_shader_parameter("horizon_color", Color(1.0, 0.70, 0.45).lerp(Color(1.0, 0.52, 0.42), p))
	var mid := Color(0.66, 0.62, 0.74).lerp(Color(0.62, 0.45, 0.66), p)
	var zenith := Color(0.26, 0.36, 0.62).lerp(Color(0.18, 0.20, 0.45), p)
	sky_mat.set_shader_parameter("mid_color", mid)
	sky_mat.set_shader_parameter("zenith_color", zenith)
	# A água das lagoas reflete o mesmo céu.
	mats.water.set_shader_parameter("sky_low", mid)
	mats.water.set_shader_parameter("sky_high", zenith)
	sky_mat.set_shader_parameter("sun_glow_color", Color(1.0, 0.6, 0.3).lerp(Color(1.0, 0.42, 0.25), p))
	env.fog_light_color = Color(0.86, 0.66, 0.52).lerp(Color(0.8, 0.5, 0.48), p)
	if giant_mound:
		giant_mound.set_atmosphere(sky_mat, env, s, sun)
	if fireflies:
		fireflies.emitting = p > 0.55


## Aplica as opções de "Gráficos" e "Tela" (Settings).
func apply_graphics() -> void:
	var sq: int = Settings.shadow_quality
	env.ssao_enabled = Settings.ssao
	env.ssil_enabled = Settings.ssil
	env.volumetric_fog_enabled = Settings.volumetric_fog
	if giant_mound:
		giant_mound.set_volumetric(Settings.volumetric_fog)
	env.glow_enabled = Settings.glow
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if sq == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = [35.0, 55.0, 70.0, 90.0][sq]
	var atlas: int = [2048, 4096, 4096, 8192][sq]
	if atlas != _shadow_atlas:
		_shadow_atlas = atlas
		RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	var vp := get_viewport()
	if vp:
		var aa: int = Settings.antialiasing
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X,
			Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X][aa]
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else \
			(Viewport.SCREEN_SPACE_AA_SMAA if aa >= 5 else Viewport.SCREEN_SPACE_AA_DISABLED)
		vp.use_taa = aa == 4
		var scale := Settings.effective_3d_scale()
		vp.scaling_3d_scale = scale
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	if dust:
		dust.amount = [80, 160, 260, 360][Settings.grass_quality]
	if grass and Settings.grass_quality != _grass_quality_built:
		rebuild_grass()


## Refaz o capim com a densidade nova (sem precisar recomeçar a fase).
func rebuild_grass() -> void:
	remove_child(grass)
	grass.queue_free()
	grass = Grass.new()
	grass.name = "Grass"
	add_child(grass)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 7
	grass.build(terrain, mats, rng, Settings.grass_density(), Settings.grass_view_distance())
	_grass_quality_built = Settings.grass_quality
