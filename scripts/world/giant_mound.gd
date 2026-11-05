extends Node3D
## O cupinzeiro gigante (área 4): visto lá longe desde a clareira, por cima dos
## penhascos. É o lugar aonde o tamanduá quer chegar. Por enquanto é só cenário.

const MeshBuilder := preload("res://scripts/procedural/mesh_builder.gd")
const LANDMARK_SHADER := preload("res://shaders/landmark.gdshader")
const WorldMap := preload("res://scripts/world/world_map.gd")

## Altura do modelo (antes da escala) e a escala: ele fica no meio da área 4,
## lá longe (quase 900 m), e por isso é bem grande.
const HEIGHT := 75.0
const SCALE := 4.0

var _mat: ShaderMaterial


func build(mats, haze_color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261103
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.6
	var b := MeshBuilder.new()
	# Base larga, como uma saia de terra.
	b.color = Color(0.92, 0.9, 0.88)
	b.add_blob(Vector3(0, 5.0, 0), Vector3(44.0, 14.0, 40.0), noise, 0.22, 3, 1.2)
	# Torre principal: torrões empilhados, afinando e torcendo um pouco.
	var layers := 16
	for i in layers:
		var t := float(i) / (layers - 1)
		var r := lerpf(26.0, 6.5, pow(t, 1.1))
		var c := Vector3(sin(t * 2.4) * 3.0, lerpf(6.0, HEIGHT - 3.0, t), cos(t * 1.7) * 2.0)
		b.color = Color.WHITE.darkened(rng.randf_range(0.0, 0.14))
		b.add_blob(c, Vector3(r, HEIGHT / layers * 1.5, r * rng.randf_range(0.85, 1.1)), noise, 0.26, 3, 1.6)
	# Torres menores em volta (de longe parece um castelo de barro).
	for k in 7:
		var ang := TAU * k / 7.0 + rng.randf_range(-0.3, 0.3)
		var dist := rng.randf_range(16.0, 26.0)
		var h := rng.randf_range(26.0, 52.0)
		var base_r := rng.randf_range(7.0, 11.0)
		var off := Vector3(cos(ang), 0, sin(ang)) * dist
		var n_layers := 7
		for i in n_layers:
			var t := float(i) / (n_layers - 1)
			var r := lerpf(base_r, base_r * 0.3, t)
			b.color = Color.WHITE.darkened(rng.randf_range(0.04, 0.2))
			b.add_blob(off + Vector3(0, lerpf(3.0, h, t), 0), Vector3(r, h / n_layers * 1.6, r), noise, 0.3, 2, 2.0)
	_mat = ShaderMaterial.new()
	_mat.shader = LANDMARK_SHADER
	_mat.set_shader_parameter("noise_tex", mats.noise_tex)
	_mat.set_shader_parameter("fog_color", haze_color)
	_mat.set_shader_parameter("world_scale", SCALE)
	var mi := MeshInstance3D.new()
	mi.name = "CupinzeiroGigante"
	mi.mesh = b.commit(null, _mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var at := WorldMap.mound_world()
	position = Vector3(at.x, -3.0 * SCALE, at.y)
	scale = Vector3.ONE * SCALE


## Copia a luz do cenário (céu, névoa e sol) para o cupinzeiro ficar na mesma
## luz do resto. Chamado sempre que o céu é acertado.
func set_atmosphere(sky_mat: ShaderMaterial, env: Environment, toward_sun: Vector3, sun: DirectionalLight3D) -> void:
	if _mat == null:
		return
	for key in ["zenith_color", "mid_color", "horizon_color", "sun_glow_color"]:
		var v = sky_mat.get_shader_parameter(key)
		if v != null:
			_mat.set_shader_parameter(key, v)
	_mat.set_shader_parameter("fog_color", env.fog_light_color)
	_mat.set_shader_parameter("aerial", env.fog_aerial_perspective)
	_mat.set_shader_parameter("sun_scatter", env.fog_sun_scatter)
	_mat.set_shader_parameter("sun_dir", toward_sun.normalized())
	_mat.set_shader_parameter("sun_color", sun.light_color)
	_mat.set_shader_parameter("sun_energy", sun.light_energy)


## Com a neblina volumétrica ligada, todo o resto fica mais enevoado; o
## cupinzeiro acompanha.
func set_volumetric(on: bool) -> void:
	if _mat:
		_mat.set_shader_parameter("extra_haze", 0.2 if on else 0.0)
