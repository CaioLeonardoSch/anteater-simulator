extends RefCounted
## Efeitos de terra: torrões, grãos e poeira macia quando uma câmara é aberta
## (ou o monte desmancha), a poeira do tremor e as lascas do tronco da
## passagem. Só visual: não muda nada no jogo.
##
## Uso: const DirtFx := preload("res://scripts/world/dirt_fx.gd")
##      DirtFx.burst(pai, posição, raio)

# Tons da terra cavada (cada torrão e grão sorteia um).
const SOIL := [Color(0.34, 0.19, 0.11), Color(0.50, 0.29, 0.17), Color(0.63, 0.40, 0.25), Color(0.72, 0.53, 0.36)]
const DUST := Color(0.90, 0.78, 0.62)
# Madeira: miolo claro, lascas médias e pedaços de casca escura.
const WOOD := [Color(0.88, 0.74, 0.54), Color(0.78, 0.60, 0.40), Color(0.62, 0.45, 0.29), Color(0.44, 0.32, 0.21)]

static var _clod: ArrayMesh
static var _shard: ArrayMesh
static var _puff: QuadMesh
static var _solid_mat: StandardMaterial3D
static var _puff_mat: StandardMaterial3D


## Terra voando: torrões, grãos finos e uma nuvem de poeira que sobe devagar.
static func burst(parent: Node, at: Vector3, r: float) -> void:
	var holder := _holder(parent, at + Vector3(0, 0.08, 0), 2.6)
	var size := clampf(r, 0.3, 2.0)
	# Torrões: poucos, pesados, rolando.
	var clods := _particles(_clod_mesh(), int(18 + size * 10), 1.1)
	var pm := _process(SOIL, 1.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size * 0.5
	pm.spread = 50.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	clods.process_material = pm
	holder.add_child(clods)
	# Grãos: muitos, pequenos, mais espalhados.
	var grains := _particles(_clod_mesh(), int(50 + size * 40), 0.9)
	var pg := _process(SOIL, 0.85)
	pg.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pg.emission_sphere_radius = size * 0.55
	pg.spread = 70.0
	pg.initial_velocity_min = 1.2
	pg.initial_velocity_max = 3.6
	pg.gravity = Vector3(0, -9.0, 0)
	pg.scale_min = 0.3
	pg.scale_max = 0.6
	grains.process_material = pg
	holder.add_child(grains)
	_dust_cloud(holder, size, int(6 + size * 6), Vector3.ZERO)


## Poeira que corre pelo chão em volta (o tremor), com grãos pulando.
static func dust_ring(parent: Node, at: Vector3, radius: float) -> void:
	var holder := _holder(parent, at + Vector3(0, 0.2, 0), 2.4)
	var puffs := _particles(_puff_mesh(), 40, 1.5)
	var pm := _puff_process()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.7
	pm.emission_ring_inner_radius = 0.4
	pm.emission_ring_height = 0.05
	pm.spread = 80.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.radial_velocity_min = radius * 0.5
	pm.radial_velocity_max = radius * 0.8
	pm.damping_min = 3.0
	pm.damping_max = 4.5
	puffs.process_material = pm
	holder.add_child(puffs)
	var grains := _particles(_clod_mesh(), 40, 0.7)
	var pg := _process(SOIL, 0.8)
	pg.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pg.emission_ring_axis = Vector3.UP
	pg.emission_ring_radius = 0.9
	pg.emission_ring_inner_radius = 0.3
	pg.emission_ring_height = 0.05
	pg.spread = 30.0
	pg.initial_velocity_min = 1.0
	pg.initial_velocity_max = 2.0
	pg.radial_velocity_min = radius * 0.2
	pg.radial_velocity_max = radius * 0.4
	pg.gravity = Vector3(0, -9.0, 0)
	pg.scale_min = 0.3
	pg.scale_max = 0.55
	grains.process_material = pg
	holder.add_child(grains)


## Lascas de madeira (o tronco da passagem se partindo) e pó de madeira.
static func splinters(parent: Node, at: Vector3) -> void:
	var holder := _holder(parent, at, 2.8)
	var shards := _particles(_shard_mesh(), 60, 1.3)
	var pm := _process(WOOD, 1.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.spread = 75.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	shards.process_material = pm
	holder.add_child(shards)
	_dust_cloud(holder, 0.8, 8, Vector3(0, -0.2, 0), WOOD[0].lerp(DUST, 0.5))


# ------------------------------------------------------------------ Partes

static func _holder(parent: Node, at: Vector3, life: float) -> Node3D:
	var h := Node3D.new()
	h.name = "TerraVoando"
	parent.add_child(h)
	h.global_position = at
	parent.get_tree().create_timer(life).timeout.connect(h.queue_free)
	return h


static func _particles(mesh: Mesh, amount: int, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.92
	p.randomness = 0.4
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 8, 12))
	p.emitting = true
	return p


## Movimento comum dos pedaços sólidos: cor sorteada da lista, girando, e
## somem encolhendo no fim (em vez de atravessar o chão).
static func _process(colors: Array, shrink_at: float) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.color_initial_ramp = _ramp(colors)
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -360.0
	pm.angular_velocity_max = 360.0
	pm.particle_flag_rotate_y = true
	pm.scale_curve = _shrink_curve(minf(shrink_at, 0.95) * 0.75)
	return pm


static func _dust_cloud(holder: Node3D, size: float, amount: int, offset: Vector3, color: Color = DUST) -> void:
	var puffs := _particles(_puff_mesh(), amount, 1.8)
	puffs.position = offset
	var pm := _puff_process(color)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size * 0.45
	pm.spread = 45.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	puffs.process_material = pm
	holder.add_child(puffs)


## Nuvem macia: cresce, sobe um pouco e vai sumindo.
static func _puff_process(color: Color = DUST) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.gravity = Vector3(0, 0.35, 0)
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -30.0
	pm.angular_velocity_max = 30.0
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.4, 0.85))
	grow.add_point(Vector2(1.0, 1.0))
	var gt := CurveTexture.new()
	gt.curve = grow
	pm.scale_curve = gt
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	g.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.62), Color(color, 0.0)])
	var gtx := GradientTexture1D.new()
	gtx.gradient = g
	pm.color_ramp = gtx
	var tone := Gradient.new()
	tone.offsets = PackedFloat32Array([0.0, 1.0])
	tone.colors = PackedColorArray([Color(0.85, 0.85, 0.85), Color(1.08, 1.05, 1.0)])
	var ttx := GradientTexture1D.new()
	ttx.gradient = tone
	pm.color_initial_ramp = ttx
	return pm


static func _ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / float(colors.size() - 1))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _shrink_curve(start: float) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(start, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _solid_material() -> StandardMaterial3D:
	if _solid_mat == null:
		_solid_mat = StandardMaterial3D.new()
		_solid_mat.vertex_color_use_as_albedo = true
		_solid_mat.vertex_color_is_srgb = true
		_solid_mat.roughness = 1.0
	return _solid_mat


## Torrão: um bloquinho irregular de faces retas (some de longe, então
## poucos triângulos bastam): dois anéis tortos entre um topo e um fundo.
static func _clod_mesh() -> ArrayMesh:
	if _clod:
		return _clod
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var top := Vector3(rng.randf_range(-0.2, 0.2), 0.8, rng.randf_range(-0.2, 0.2))
	var bottom := Vector3(rng.randf_range(-0.2, 0.2), -0.75, rng.randf_range(-0.2, 0.2))
	var rings: Array = []
	for r in 2:
		var ring: Array[Vector3] = []
		var y := 0.35 if r == 0 else -0.3
		for i in 5:
			var a := TAU * (i + r * 0.5 + rng.randf_range(-0.15, 0.15)) / 5.0
			var rad := rng.randf_range(0.75, 1.15)
			ring.append(Vector3(cos(a) * rad, y + rng.randf_range(-0.15, 0.15), sin(a) * rad))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := 0.032
	for i in 5:
		var j := (i + 1) % 5
		var u0: Vector3 = rings[0][i]
		var u1: Vector3 = rings[0][j]
		var d0: Vector3 = rings[1][i]
		var d1: Vector3 = rings[1][j]
		_tri(st, top * s, u0 * s, u1 * s)
		_tri(st, bottom * s, d0 * s, d1 * s)
		_tri(st, u0 * s, d0 * s, u1 * s)
		_tri(st, u1 * s, d0 * s, d1 * s)
	st.generate_normals()
	_clod = st.commit()
	_clod.surface_set_material(0, _solid_material())
	return _clod


## Triângulo virado para fora (a peça é centrada na origem).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (b - a).cross(c - a).dot(a + b + c) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Lasca: fina, comprida e pontuda nas duas pontas.
static func _shard_mesh() -> ArrayMesh:
	if _shard:
		return _shard
	var hw := 0.045
	var hh := 0.02
	var hl := 0.14
	var tip_a := Vector3(0.004, 0, -hl)
	var tip_b := Vector3(-0.006, 0.002, hl)
	var mid := [Vector3(-hw, -hh, -0.02), Vector3(hw, -hh, 0.01), Vector3(hw * 0.7, hh, 0.02), Vector3(-hw * 0.8, hh, -0.01)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a: Vector3 = mid[i]
		var b: Vector3 = mid[(i + 1) % 4]
		_tri(st, tip_a, a, b)
		_tri(st, tip_b, b, a)
	st.generate_normals()
	_shard = st.commit()
	_shard.surface_set_material(0, _solid_material())
	return _shard


## Fumacinha: um quadrado virado para a câmera com uma mancha redonda e macia.
static func _puff_mesh() -> QuadMesh:
	if _puff:
		return _puff
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	tex.gradient = g
	_puff_mat = StandardMaterial3D.new()
	_puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_puff_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_puff_mat.billboard_keep_scale = true
	_puff_mat.vertex_color_use_as_albedo = true
	_puff_mat.vertex_color_is_srgb = true
	_puff_mat.albedo_texture = tex
	_puff_mat.roughness = 1.0
	_puff_mat.disable_receive_shadows = true
	_puff_mat.proximity_fade_enabled = true
	_puff_mat.proximity_fade_distance = 0.25
	_puff = QuadMesh.new()
	_puff.size = Vector2(1.2, 1.2)
	_puff.material = _puff_mat
	return _puff
