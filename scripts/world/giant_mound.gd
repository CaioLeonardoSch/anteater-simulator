extends Node3D
## O cupinzeiro gigante (área 4): visto lá longe desde a clareira, por cima dos
## penhascos. É o lugar aonde o tamanduá quer chegar. Por enquanto é só cenário.

const MeshBuilder := preload("res://scripts/procedural/mesh_builder.gd")
const LANDMARK_SHADER := preload("res://shaders/landmark.gdshader")

## Direção (radianos, ~165°) e distância do centro da clareira.
const ANGLE := 2.88
const DISTANCE := 215.0
const HEIGHT := 75.0


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
	var mat := ShaderMaterial.new()
	mat.shader = LANDMARK_SHADER
	mat.set_shader_parameter("noise_tex", mats.noise_tex)
	mat.set_shader_parameter("haze_color", haze_color)
	mat.set_shader_parameter("haze", 0.45)
	var mi := MeshInstance3D.new()
	mi.name = "CupinzeiroGigante"
	mi.mesh = b.commit(null, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	position = Vector3(cos(ANGLE) * DISTANCE, -3.0, sin(ANGLE) * DISTANCE)
