extends Node3D
## Monta a fase "Cerrado ao Entardecer": céu, sol, terreno, trilhas, formigueiros,
## vegetação, capim e partículas. Também controla o pôr do sol ao longo da fase.

const Materials := preload("res://scripts/world/materials.gd")
const Terrain := preload("res://scripts/world/terrain.gd")
const TrailNetwork := preload("res://scripts/world/trail_network.gd")
const Vegetation := preload("res://scripts/world/vegetation.gd")
const Grass := preload("res://scripts/world/grass.gd")
const Nest := preload("res://scripts/world/nest.gd")
const Props := preload("res://scripts/world/props.gd")
const ModelLibrary := preload("res://scripts/model_library.gd")
const SKY_SHADER := preload("res://shaders/sky_dusk.gdshader")

const SEED := 20261102
const PLAY_RADIUS := 60.0

var mats: Materials
var terrain: Terrain
var trails: TrailNetwork
var nests: Array = []
var food_sources: Array[Vector2] = []
var vegetation: Vegetation
var grass: Grass
var player_start := Vector2(2.0, 6.0)
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

## 8 formigueiros; os grandes ("big") têm a câmara da rainha.
const NEST_LAYOUT := [
	{"name": "Formigueiro Norte", "pos": Vector2(4, -42), "big": true},
	{"name": "Formigueiro Nordeste", "pos": Vector2(32, -30), "big": false},
	{"name": "Formigueiro Leste", "pos": Vector2(44, 2), "big": true},
	{"name": "Formigueiro Sudeste", "pos": Vector2(28, 36), "big": false},
	{"name": "Formigueiro Sul", "pos": Vector2(-2, 46), "big": true},
	{"name": "Formigueiro Sudoeste", "pos": Vector2(-32, 30), "big": false},
	{"name": "Formigueiro Oeste", "pos": Vector2(-45, -6), "big": false},
	{"name": "Formigueiro Noroeste", "pos": Vector2(-26, -36), "big": false},
]
## Arbustos onde as saúvas cortam folhas.
const FOOD_LAYOUT := [
	Vector2(-9, -24), Vector2(18, -20), Vector2(26, 4), Vector2(12, 24),
	Vector2(-14, 22), Vector2(-26, -2)]
## Trilhas: [formigueiro, arbusto].
const LINKS := [[0, 0], [0, 1], [1, 1], [2, 2], [2, 1], [3, 3], [3, 2], [4, 3], [4, 4],
	[5, 4], [5, 5], [6, 5], [7, 0], [7, 5]]
## Trilha onde o jogador começa (formigueiro Leste -> arbusto 2), olhando para o sol.
const START_LINK := [2, 2]


func build() -> void:
	_rng.seed = SEED
	mats = Materials.new()
	_build_environment()
	# Formigueiros e fontes de folhas.
	var spots: Array[Vector3] = []
	for i in NEST_LAYOUT.size():
		var p: Vector2 = NEST_LAYOUT[i].pos
		spots.append(Vector3(p.x, p.y, 5.2 if NEST_LAYOUT[i].big else 4.5))
	for f in FOOD_LAYOUT:
		food_sources.append(f)
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.setup(SEED, spots)
	terrain.build(mats.terrain)
	for i in NEST_LAYOUT.size():
		var nest: Nest = Nest.new()
		nest.name = "Nest%d" % i
		var big: bool = NEST_LAYOUT[i].big
		var r := _rng.randf_range(2.25, 2.45) if big else _rng.randf_range(1.6, 1.9)
		var h := _rng.randf_range(0.72, 0.8) if big else _rng.randf_range(0.55, 0.65)
		nest.setup(i, NEST_LAYOUT[i].name, NEST_LAYOUT[i].pos, r, h, big)
		nests.append(nest)
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
	# Início: ao lado de uma trilha movimentada, olhando ao longo dela, contra o sol.
	for k in LINKS.size():
		if LINKS[k] == START_LINK:
			start_trail_index = k
	var start_trail = trails.trails[start_trail_index]
	var s0: float = start_trail.length * 0.5
	player_start = start_trail.point_at(s0) + start_trail.side_at(s0) * 1.4
	var target: Vector2 = start_trail.point_at(start_trail.length * 0.72)
	var to := target - player_start
	player_start_yaw = atan2(-to.x, -to.y)
	for nest in nests:
		terrain.mask_paint(nest.center2.x, nest.center2.y, nest.radius + 1.0, 1, 1.0)
	for f in food_sources:
		terrain.mask_paint(f.x, f.y, 1.6, 1, 0.8)
	# Nós dos formigueiros (com as câmaras longe dos olheiros das trilhas).
	# As câmaras são planejadas antes de montar qualquer monte, para o mapa não
	# mudar quando o visual dos montes muda.
	for nest in nests:
		nest.plan_chambers(_rng)
	for nest in nests:
		nest.position = Vector3(nest.center2.x, terrain.get_height(nest.center2.x, nest.center2.y), nest.center2.y)
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
	mats.terrain.set_shader_parameter("mask_tex", terrain.finalize_mask())
	grass = Grass.new()
	grass.name = "Grass"
	add_child(grass)
	grass.build(terrain, mats, _rng, Settings.grass_density(), Settings.grass_view_distance())
	_build_particles()
	set_day_progress(0.0, true)
	apply_quality(Settings.graphics_quality)


func vegetation_ai(model_name: String, target: Vector3) -> Node3D:
	return ModelLibrary.instantiate(model_name, target)


## Altura do chão para as formigas (terreno + montes dos formigueiros).
func ground_height(x: float, z: float) -> float:
	var h := terrain.get_height(x, z)
	for n in nests:
		h += n.dome_height(x, z)
	return h


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
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.92, 0.72, 0.58)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.45
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
	env.volumetric_fog_anisotropy = 0.6
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
	sky_mat.set_shader_parameter("mid_color", Color(0.66, 0.62, 0.74).lerp(Color(0.62, 0.45, 0.66), p))
	sky_mat.set_shader_parameter("zenith_color", Color(0.26, 0.36, 0.62).lerp(Color(0.18, 0.20, 0.45), p))
	sky_mat.set_shader_parameter("sun_glow_color", Color(1.0, 0.6, 0.3).lerp(Color(1.0, 0.42, 0.25), p))
	env.fog_light_color = Color(0.92, 0.74, 0.6).lerp(Color(0.85, 0.55, 0.52), p)
	if fireflies:
		fireflies.emitting = p > 0.55


func apply_quality(q: int) -> void:
	env.ssao_enabled = q >= 1
	env.ssil_enabled = q >= 3
	env.volumetric_fog_enabled = q >= 3
	env.glow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = [35.0, 55.0, 70.0, 90.0][q]
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
		vp.scaling_3d_scale = 0.8 if q == 0 else 1.0
	if dust:
		dust.amount = [80, 160, 260, 360][q]
