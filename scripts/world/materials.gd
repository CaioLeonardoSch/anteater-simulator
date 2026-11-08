extends RefCounted
## Materiais compartilhados do cenário (todos estilizados, com shaders próprios).

const SOFT_SURFACE := preload("res://shaders/soft_surface.gdshader")
const FOLIAGE := preload("res://shaders/foliage.gdshader")
const GRASS := preload("res://shaders/grass.gdshader")
const TERRAIN := preload("res://shaders/terrain.gdshader")
const ARENITO := preload("res://shaders/arenito.gdshader")
const CASCA := preload("res://shaders/casca.gdshader")
const FLOWER := preload("res://shaders/flower.gdshader")
const LEAF_TEX := preload("res://assets/textures/leaf_cluster.png")
const FLOWER_TEX := preload("res://assets/textures/flower_cluster.png")
const SHRUB_TEX := preload("res://assets/textures/shrub_cluster.png")
const SOLO_COR := preload("res://assets/textures/chao/cor.png")
const SOLO_RELEVO := preload("res://assets/textures/chao/relevo.png")
const SOLO_ASPEREZA := preload("res://assets/textures/chao/aspereza.png")
const TRILHA_COR := preload("res://assets/textures/trilha/cor.png")
const TRILHA_RELEVO := preload("res://assets/textures/trilha/relevo.png")
const TRILHA_ASPEREZA := preload("res://assets/textures/trilha/aspereza.png")
const ARENITO_COR := preload("res://assets/textures/arenito/cor.png")
const ARENITO_RELEVO := preload("res://assets/textures/arenito/relevo.png")
const BARRO_COR := preload("res://assets/textures/barro/cor.png")
const BARRO_RELEVO := preload("res://assets/textures/barro/relevo.png")
const CASCA_COR := preload("res://assets/textures/casca/cor.png")
const CASCA_RELEVO := preload("res://assets/textures/casca/relevo.png")
const FORMIGUEIRO := preload("res://shaders/formigueiro.gdshader")
const TERRA_COR := preload("res://assets/textures/terra/cor.png")
const TERRA_RELEVO := preload("res://assets/textures/terra/relevo.png")
const CAVA_COR := preload("res://assets/textures/cava/cor.png")
const CAVA_RELEVO := preload("res://assets/textures/cava/relevo.png")
const AGUA := preload("res://shaders/agua.gdshader")

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
var arenito: ShaderMaterial
var nest_soil: ShaderMaterial
var nest_cap: ShaderMaterial
var nest_fungus: ShaderMaterial
var water: ShaderMaterial


func _init() -> void:
	noise_tex = _make_noise(512, 0.012, 3, 11)
	cloud_noise = _make_noise(512, 0.006, 5, 23)

	terrain = _shader(TERRAIN)
	terrain.set_shader_parameter("noise_tex", noise_tex)
	terrain.set_shader_parameter("solo_cor", SOLO_COR)
	terrain.set_shader_parameter("solo_relevo", SOLO_RELEVO)
	terrain.set_shader_parameter("solo_aspereza", SOLO_ASPEREZA)
	terrain.set_shader_parameter("trilha_cor", TRILHA_COR)
	terrain.set_shader_parameter("trilha_relevo", TRILHA_RELEVO)
	terrain.set_shader_parameter("trilha_aspereza", TRILHA_ASPEREZA)

	grass = _shader(GRASS)
	grass.set_shader_parameter("noise_tex", noise_tex)

	flower = _shader(FLOWER)

	# Casca das árvores e galhos: cortiça grossa e rachada feita no Blender, presa
	# a cada galho.
	bark = _shader(CASCA)
	bark.set_shader_parameter("noise_tex", noise_tex)
	bark.set_shader_parameter("casca_cor", CASCA_COR)
	bark.set_shader_parameter("casca_relevo", CASCA_RELEVO)
	bark.set_shader_parameter("color_a", Color(0.30, 0.25, 0.21))
	bark.set_shader_parameter("color_b", Color(0.42, 0.36, 0.30))
	bark.set_shader_parameter("around_repeats", 2.0)
	bark.set_shader_parameter("length_tile", 0.8)
	bark.set_shader_parameter("detail_amount", 0.8)
	bark.set_shader_parameter("relief_strength", 1.4)

	# Troncos caídos: a mesma cortiça, mais escura e gasta, com falhas mostrando a
	# madeira cinza, musgo só embaixo e as pontas quebradas com anéis.
	log_bark = _shader(CASCA)
	log_bark.set_shader_parameter("noise_tex", noise_tex)
	log_bark.set_shader_parameter("casca_cor", CASCA_COR)
	log_bark.set_shader_parameter("casca_relevo", CASCA_RELEVO)
	log_bark.set_shader_parameter("color_a", Color(0.29, 0.24, 0.20))
	log_bark.set_shader_parameter("color_b", Color(0.40, 0.34, 0.28))
	log_bark.set_shader_parameter("bare_color", Color(0.58, 0.52, 0.43))
	log_bark.set_shader_parameter("around_repeats", 3.0)
	log_bark.set_shader_parameter("length_tile", 0.8)
	log_bark.set_shader_parameter("uv_per_meter", 0.5)
	log_bark.set_shader_parameter("detail_amount", 0.85)
	log_bark.set_shader_parameter("relief_strength", 1.4)
	log_bark.set_shader_parameter("bare_amount", 1.0)
	log_bark.set_shader_parameter("moss_amount", 0.9)
	log_bark.set_shader_parameter("moss_color", Color(0.25, 0.30, 0.14))
	log_bark.set_shader_parameter("wood_light", Color(0.60, 0.50, 0.38))
	log_bark.set_shader_parameter("wood_dark", Color(0.40, 0.31, 0.23))

	leaves_core = _foliage(Color(0.13, 0.24, 0.09), Color(0.36, 0.52, 0.17), Color(0.78, 0.74, 0.32), false)
	leaves_cards = _foliage(Color(0.13, 0.24, 0.09), Color(0.40, 0.56, 0.18), Color(0.86, 0.78, 0.34), true)
	# Árvores: folhas ovais de couro, com tons variados e poucas secas.
	leaves_cards.set_shader_parameter("tone_amount", 1.0)
	leaves_cards.set_shader_parameter("dry_amount", 1.0)
	leaves_cards.set_shader_parameter("dry_color", Color(0.52, 0.42, 0.24))
	# Arbustos: verde mais acinzentado e seco, folhas finas e mais folhas secas.
	shrub_core = _foliage(Color(0.20, 0.25, 0.14), Color(0.40, 0.48, 0.27), Color(0.64, 0.62, 0.38), false)
	shrub_cards = _foliage(Color(0.19, 0.25, 0.13), Color(0.47, 0.55, 0.31), Color(0.74, 0.70, 0.42), true, SHRUB_TEX)
	shrub_cards.set_shader_parameter("tone_amount", 1.0)
	shrub_cards.set_shader_parameter("dry_amount", 1.0)
	shrub_cards.set_shader_parameter("dry_color", Color(0.58, 0.45, 0.28))
	ipe_core = _foliage(Color(0.62, 0.36, 0.06), Color(0.95, 0.72, 0.12), Color(1.0, 0.90, 0.40), false, FLOWER_TEX)
	ipe_cards = _foliage(Color(0.70, 0.42, 0.06), Color(1.0, 0.78, 0.16), Color(1.0, 0.93, 0.48), true, FLOWER_TEX)
	ipe_roxo_core = _foliage(Color(0.40, 0.16, 0.32), Color(0.80, 0.42, 0.66), Color(0.98, 0.72, 0.86), false, FLOWER_TEX)
	ipe_roxo_cards = _foliage(Color(0.45, 0.18, 0.36), Color(0.88, 0.48, 0.72), Color(1.0, 0.78, 0.90), true, FLOWER_TEX)
	ipe_ground = ipe_cards.duplicate()
	ipe_ground.set_shader_parameter("sway", 0.0)

	# Cupinzeiros: estampa de barro seco feita no Blender (granulado, caneluras
	# verticais da chuva, rachaduras finas e furinhos), no mesmo shader dos
	# paredões, que deixa os sulcos sempre em pé.
	clay = _shader(ARENITO)
	clay.set_shader_parameter("noise_tex", noise_tex)
	clay.set_shader_parameter("rocha_cor", BARRO_COR)
	clay.set_shader_parameter("rocha_relevo", BARRO_RELEVO)
	clay.set_shader_parameter("topo_cor", BARRO_COR)
	clay.set_shader_parameter("topo_relevo", BARRO_RELEVO)
	clay.set_shader_parameter("rocha_media", Color(0.675, 0.495, 0.359))
	clay.set_shader_parameter("topo_media", Color(0.675, 0.495, 0.359))
	clay.set_shader_parameter("color_a", Color(0.50, 0.36, 0.27))
	clay.set_shader_parameter("color_b", Color(0.62, 0.49, 0.39))
	clay.set_shader_parameter("accent_color", Color(0.58, 0.45, 0.35))
	clay.set_shader_parameter("noise_scale", 1.6)
	clay.set_shader_parameter("detail_scale", 7.0)
	clay.set_shader_parameter("tint_variation", 0.3)
	clay.set_shader_parameter("relief_strength", 1.5)
	clay.set_shader_parameter("tile_size", 1.0)
	clay.set_shader_parameter("top_tile_size", 1.0)
	clay.set_shader_parameter("top_detail", 0.8)
	clay.set_shader_parameter("strata_warp", 0.0)
	clay.set_shader_parameter("streak_amount", 0.0)
	clay.set_shader_parameter("relief_fade", Vector2(25.0, 60.0))
	clay.set_shader_parameter("roughness_value", 0.95)
	clay.set_shader_parameter("specular_value", 0.15)
	clay.set_shader_parameter("rim_amount", 0.1)

	# Pedras soltas: a mesma rocha dos paredões (estampa de arenito, camadas mais
	# finas), um pouco mais apagada, com manchinhas de líquen por cima.
	rock = _shader(ARENITO)
	rock.set_shader_parameter("noise_tex", noise_tex)
	rock.set_shader_parameter("rocha_cor", ARENITO_COR)
	rock.set_shader_parameter("rocha_relevo", ARENITO_RELEVO)
	rock.set_shader_parameter("topo_cor", ARENITO_COR)
	rock.set_shader_parameter("topo_relevo", ARENITO_RELEVO)
	rock.set_shader_parameter("topo_media", Color(0.796, 0.610, 0.468))
	rock.set_shader_parameter("color_a", Color(0.47, 0.34, 0.25))
	rock.set_shader_parameter("color_b", Color(0.66, 0.51, 0.39))
	rock.set_shader_parameter("accent_color", Color(0.58, 0.44, 0.33))
	rock.set_shader_parameter("noise_scale", 1.2)
	rock.set_shader_parameter("detail_scale", 6.0)
	rock.set_shader_parameter("tile_size", 2.0)
	rock.set_shader_parameter("top_tile_size", 3.0)
	rock.set_shader_parameter("top_detail", 0.7)
	rock.set_shader_parameter("lichen_color", Color(0.64, 0.64, 0.46))
	rock.set_shader_parameter("streak_amount", 0.0)
	rock.set_shader_parameter("lichen_amount", 0.6)
	rock.set_shader_parameter("roughness_value", 0.85)
	rock.set_shader_parameter("specular_value", 0.3)
	rock.set_shader_parameter("rim_amount", 0.12)

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

	# Paredões: estampa de arenito feita no Blender (camadas, fendas, blocos), com
	# as faixas pintadas por vértice por cima e o verde só no topo. O `cliff` de
	# cima fica para o chão da mata, até ele ganhar o material dele.
	arenito = _shader(ARENITO)
	arenito.set_shader_parameter("noise_tex", noise_tex)
	arenito.set_shader_parameter("rocha_cor", ARENITO_COR)
	arenito.set_shader_parameter("rocha_relevo", ARENITO_RELEVO)
	arenito.set_shader_parameter("topo_cor", SOLO_COR)
	arenito.set_shader_parameter("topo_relevo", SOLO_RELEVO)

	# Formigueiros: grãozinhos de terra fofa feitos no Blender; nos buracos
	# (olheiros, câmaras abertas, buraco da rainha) a terra recém-cavada.
	nest_soil = _shader(FORMIGUEIRO)
	nest_soil.set_shader_parameter("noise_tex", noise_tex)
	nest_soil.set_shader_parameter("terra_cor", TERRA_COR)
	nest_soil.set_shader_parameter("terra_relevo", TERRA_RELEVO)
	nest_soil.set_shader_parameter("cava_cor", CAVA_COR)
	nest_soil.set_shader_parameter("cava_relevo", CAVA_RELEVO)
	nest_soil.set_shader_parameter("color_a", Color(0.48, 0.30, 0.20))
	nest_soil.set_shader_parameter("color_b", Color(0.62, 0.42, 0.30))
	# Terra fofa e mais clara que tampa as câmaras (dá para ver de longe).
	nest_cap = nest_soil.duplicate()
	nest_cap.set_shader_parameter("color_a", Color(0.70, 0.52, 0.38))
	nest_cap.set_shader_parameter("color_b", Color(0.86, 0.70, 0.52))
	nest_cap.set_shader_parameter("dug_amount", 0.0)
	# Jardim de fungo das saúvas nas câmaras abertas: esponja clara.
	nest_fungus = nest_soil.duplicate()
	nest_fungus.set_shader_parameter("fungus_mode", true)
	# Água das lagoas: ondinhas de um ruído em forma de relevo (sem emenda).
	var ripple := _make_noise(256, 0.035, 3, 23)
	ripple.as_normal_map = true
	ripple.bump_strength = 3.0
	water = _shader(AGUA)
	water.set_shader_parameter("ripple_tex", ripple)


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
