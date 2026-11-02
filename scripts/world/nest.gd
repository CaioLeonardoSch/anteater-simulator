extends Node3D
## Formigueiro de saúvas: monte de terra fofa com olheiros (buracos).
## As formigas saem pelos olheiros, descem o monte e seguem pelas trilhas.
## Se existir assets/models/formigueiro.glb, ele substitui o monte feito por código.

const MeshBuilder := preload("res://scripts/procedural/mesh_builder.gd")
const ModelLibrary := preload("res://scripts/model_library.gd")

var index := 0
var display_name := "Formigueiro"
var radius := 1.8
var height := 0.62
var center2 := Vector2.ZERO
## Direções (no plano xz) das trilhas que saem daqui.
var trail_dirs: Array[Vector2] = []
var trail_ids: Array[int] = []
var hole_distance := 0.0

var dig_cooldown := 0.0
var used_ai_model := false

var _noise := FastNoiseLite.new()


func setup(i: int, nest_name: String, pos2: Vector2, r: float, h: float) -> void:
	index = i
	display_name = nest_name
	center2 = pos2
	radius = r
	height = h
	hole_distance = radius * 0.5
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
	return height * pow(1.0 - d2 / r2, 1.3)


func hole_position(trail_dir: Vector2) -> Vector2:
	return center2 + trail_dir * hole_distance


func build(rng: RandomNumberGenerator, mats) -> void:
	var model := ModelLibrary.instantiate("formigueiro", Vector3(radius * 2.1, 0.0, radius * 2.1))
	if model:
		used_ai_model = true
		add_child(model)
	else:
		add_child(_build_procedural(rng, mats))
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius * 0.72
	shape.height = height * 2.0
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _build_procedural(rng: RandomNumberGenerator, mats) -> MeshInstance3D:
	var b := MeshBuilder.new()
	var holes: Array[Vector2] = [Vector2.ZERO]
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
	# Torrões de terra escavada.
	var crumb_noise := FastNoiseLite.new()
	crumb_noise.frequency = 2.0
	for _k in 110:
		var a := rng.randf() * TAU
		var r := radius * sqrt(rng.randf()) * 1.05
		var p2 := Vector2(cos(a), sin(a)) * r
		if _near_hole(p2, holes, 0.16):
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
	var mat: ShaderMaterial = mats.nest_soil
	var mi := MeshInstance3D.new()
	mi.name = "MonteProcedural"
	mi.mesh = b.commit(null, mat)
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
