extends RefCounted
## Materiais compartilhados do cenário (todos estilizados, com shaders próprios).

const SOFT_SURFACE := preload("res://shaders/soft_surface.gdshader")
const FOLIAGE := preload("res://shaders/foliage.gdshader")
const GRASS := preload("res://shaders/grass.gdshader")
const TERRAIN := preload("res://shaders/terrain.gdshader")
const FLOWER := preload("res://shaders/flower.gdshader")
const LEAF_TEX := preload("res://assets/textures/leaf_cluster.png")
const FLOWER_TEX := preload("res://assets/textures/flower_cluster.png")

var noise_tex: NoiseTexture2D
var cloud_noise: NoiseTexture2D

var terrain: ShaderMaterial
var grass: ShaderMaterial
var flower: ShaderMaterial
var bark: ShaderMaterial
var log_bark: ShaderMaterial
var leaves_core: ShaderMaterial
var leaves_cards: ShaderMaterial
var shrub_core: ShaderMaterial
var shrub_cards: ShaderMaterial
var ipe_core: ShaderMaterial
var ipe_cards: ShaderMaterial
var ipe_roxo_core: ShaderMaterial
var ipe_roxo_cards: ShaderMaterial
var ipe_ground: ShaderMaterial
var clay: ShaderMaterial
var rock: ShaderMaterial
var cliff: ShaderMaterial
var nest_soil: ShaderMaterial
var nest_cap: ShaderMaterial


func _init() -> void:
	noise_tex = _make_noise(512, 0.012, 3, 11)
	cloud_noise = _make_noise(512, 0.006, 5, 23)

	terrain = _shader(TERRAIN)
	terrain.set_shader_parameter("noise_tex", noise_tex)

	grass = _shader(GRASS)
	grass.set_shader_parameter("noise_tex", noise_tex)

	flower = _shader(FLOWER)

	bark = _surface(Color(0.30, 0.24, 0.20), Color(0.55, 0.47, 0.39), Color(0.62, 0.62, 0.42))
	bark.set_shader_parameter("noise_scale", 2.0)
	bark.set_shader_parameter("detail_scale", 9.0)
	bark.set_shader_parameter("streak_amount", 0.45)
	bark.set_shader_parameter("streak_scale", 14.0)
	bark.set_shader_parameter("accent_amount", 0.35)
	bark.set_shader_parameter("accent_threshold", 0.72)
	bark.set_shader_parameter("roughness_value", 0.95)

	log_bark = bark.duplicate()
	log_bark.set_shader_parameter("accent_color", Color(0.42, 0.52, 0.22))
	log_bark.set_shader_parameter("accent_amount", 0.6)
	log_bark.set_shader_parameter("accent_up_bias", 0.4)

	leaves_core = _foliage(Color(0.13, 0.24, 0.09), Color(0.36, 0.52, 0.17), Color(0.78, 0.74, 0.32), false)
	leaves_cards = _foliage(Color(0.13, 0.24, 0.09), Color(0.40, 0.56, 0.18), Color(0.86, 0.78, 0.34), true)
	shrub_core = _foliage(Color(0.12, 0.25, 0.10), Color(0.32, 0.55, 0.20), Color(0.65, 0.74, 0.30), false)
	shrub_cards = _foliage(Color(0.12, 0.25, 0.10), Color(0.36, 0.60, 0.22), Color(0.70, 0.78, 0.32), true)
	ipe_core = _foliage(Color(0.62, 0.36, 0.06), Color(0.95, 0.72, 0.12), Color(1.0, 0.90, 0.40), false, FLOWER_TEX)
	ipe_cards = _foliage(Color(0.70, 0.42, 0.06), Color(1.0, 0.78, 0.16), Color(1.0, 0.93, 0.48), true, FLOWER_TEX)
	ipe_roxo_core = _foliage(Color(0.40, 0.16, 0.32), Color(0.80, 0.42, 0.66), Color(0.98, 0.72, 0.86), false, FLOWER_TEX)
	ipe_roxo_cards = _foliage(Color(0.45, 0.18, 0.36), Color(0.88, 0.48, 0.72), Color(1.0, 0.78, 0.90), true, FLOWER_TEX)
	ipe_ground = ipe_cards.duplicate()
	ipe_ground.set_shader_parameter("sway", 0.0)

	clay = _surface(Color(0.50, 0.27, 0.15), Color(0.72, 0.45, 0.28), Color(0.82, 0.62, 0.44))
	clay.set_shader_parameter("noise_scale", 1.6)
	clay.set_shader_parameter("detail_scale", 7.0)
	clay.set_shader_parameter("streak_amount", 0.25)
	clay.set_shader_parameter("streak_scale", 8.0)
	clay.set_shader_parameter("accent_amount", 0.3)
	clay.set_shader_parameter("accent_threshold", 0.68)
	clay.set_shader_parameter("accent_up_bias", 0.25)

	rock = _surface(Color(0.42, 0.39, 0.35), Color(0.66, 0.61, 0.53), Color(0.72, 0.70, 0.30))
	rock.set_shader_parameter("noise_scale", 1.2)
	rock.set_shader_parameter("detail_scale", 6.0)
	rock.set_shader_parameter("accent_amount", 0.55)
	rock.set_shader_parameter("accent_threshold", 0.66)
	rock.set_shader_parameter("accent_up_bias", 0.35)
	rock.set_shader_parameter("roughness_value", 0.8)
	rock.set_shader_parameter("specular_value", 0.4)

	# Paredões de arenito da chapada: faixas pintadas por vértice, escorridos
	# verticais e um verde ralo só no topo plano.
	cliff = _surface(Color(0.50, 0.31, 0.21), Color(0.70, 0.51, 0.37), Color(0.46, 0.52, 0.26))
	cliff.set_shader_parameter("noise_scale", 0.35)
	cliff.set_shader_parameter("detail_scale", 2.6)
	cliff.set_shader_parameter("streak_amount", 0.3)
	cliff.set_shader_parameter("streak_scale", 3.0)
	cliff.set_shader_parameter("accent_amount", 0.7)
	cliff.set_shader_parameter("accent_threshold", 0.75)
	cliff.set_shader_parameter("accent_up_bias", 0.7)
	cliff.set_shader_parameter("roughness_value", 0.93)
	cliff.set_shader_parameter("specular_value", 0.2)
	cliff.set_shader_parameter("rim_amount", 0.05)

	nest_soil = _surface(Color(0.46, 0.26, 0.16), Color(0.64, 0.42, 0.28), Color(0.80, 0.62, 0.46))
	nest_soil.set_shader_parameter("noise_scale", 3.0)
	nest_soil.set_shader_parameter("detail_scale", 14.0)
	nest_soil.set_shader_parameter("accent_amount", 0.2)
	nest_soil.set_shader_parameter("roughness_value", 0.97)
	nest_soil.set_shader_parameter("specular_value", 0.15)
	nest_soil.set_shader_parameter("rim_amount", 0.0)
	# Terra fofa e mais clara que tampa as câmaras (dá para ver de longe).
	nest_cap = nest_soil.duplicate()
	nest_cap.set_shader_parameter("color_a", Color(0.70, 0.50, 0.34))
	nest_cap.set_shader_parameter("color_b", Color(0.90, 0.72, 0.52))
	nest_cap.set_shader_parameter("accent_color", Color(0.96, 0.84, 0.64))
	nest_soil.set_shader_parameter("accent_threshold", 0.7)


func _make_noise(size: int, freq: float, octaves: int, seed_value: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.normalize = true
	t.generate_mipmaps = true
	t.noise = n
	return t


func _shader(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


func _surface(a: Color, b: Color, accent: Color) -> ShaderMaterial:
	var m := _shader(SOFT_SURFACE)
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("accent_color", accent)
	m.set_shader_parameter("noise_tex", noise_tex)
	return m


func _foliage(dark: Color, light: Color, tip: Color, cards: bool, tex: Texture2D = LEAF_TEX) -> ShaderMaterial:
	var m := _shader(FOLIAGE)
	m.set_shader_parameter("color_dark", dark)
	m.set_shader_parameter("color_light", light)
	m.set_shader_parameter("color_tip", tip)
	m.set_shader_parameter("leaf_tex", tex)
	m.set_shader_parameter("noise_tex", noise_tex)
	m.set_shader_parameter("use_texture", 1.0 if cards else 0.0)
	return m
