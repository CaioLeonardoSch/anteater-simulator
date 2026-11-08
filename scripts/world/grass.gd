extends Node3D
## Campo de capim e flores: instâncias em blocos (MultiMesh).
## Duas camadas: capim denso perto do jogador (some suavemente a ~25 m) e
## capim espaçado até o horizonte. Assim o campo é cheio sem pesar na placa de vídeo.

const Props := preload("res://scripts/world/props.gd")

const CHUNK := 16.0
## Até onde vai o capim: a clareira e a passagem para a área 2.
const EXTENT := 44.0
## Blocos com o centro além disto (m) usam a touceira leve. O capim de perto
## some aos ~26 m; o de longe vai até o fim da vista (64 m no Ultra).
const LITE_NEAR := 14.0
const LITE_FAR := 26.0
## Folga no fim da vista: o bloco fica até o capim da ponta dele sumir no fade.
const PAD := CHUNK * 0.75


func build(terrain, mats, rng: RandomNumberGenerator, density_mult: float, view_dist: float) -> void:
	# Cada touceira tem a versão cheia (perto) e a leve (longe), iguais no formato.
	var variants: Array[ArrayMesh] = []
	var lite: Array[ArrayMesh] = []
	for v in [[12, false], [15, false], [10, true]]:
		var state := rng.state
		variants.append(Props.build_grass_clump(rng, v[0], v[1]))
		rng.state = state
		lite.append(Props.build_grass_clump(rng, v[0], v[1], true))
	var flower_meshes: Array[ArrayMesh] = [Props.build_flower_mesh(0), Props.build_flower_mesh(1)]
	var patch := FastNoiseLite.new()
	patch.seed = rng.randi()
	patch.frequency = 0.045
	var flower_colors: Array[Color] = [
		Color(0.98, 0.78, 0.18), Color(0.98, 0.95, 0.88), Color(0.72, 0.52, 0.86),
		Color(0.97, 0.52, 0.22), Color(0.98, 0.70, 0.82)]
	var far_mat: ShaderMaterial = mats.grass
	far_mat.set_shader_parameter("fade_end", view_dist)
	far_mat.set_shader_parameter("fade_start", view_dist * 0.72)
	var near_dist := minf(26.0, view_dist * 0.6)
	var near_mat := far_mat.duplicate() as ShaderMaterial
	near_mat.set_shader_parameter("fade_end", near_dist)
	near_mat.set_shader_parameter("fade_start", near_dist * 0.7)
	var flower_mat: ShaderMaterial = mats.flower
	flower_mat.set_shader_parameter("fade_end", near_dist * 1.2)
	flower_mat.set_shader_parameter("fade_start", near_dist * 0.8)
	# "lite": a partir de que distância (do centro do bloco) usa a touceira leve.
	var layers := [
		{"density": 1.1, "mat": far_mat, "range": view_dist, "scale": 1.12, "lite": LITE_FAR},
		{"density": 3.0 * density_mult, "mat": near_mat, "range": near_dist, "scale": 1.0, "lite": LITE_NEAR},
	]
	var flowers_per_chunk := int(CHUNK * CHUNK * 0.16 * density_mult)
	var n := int(ceil(EXTENT * 2.0 / CHUNK))
	for cz in n:
		for cx in n:
			var x0 := -EXTENT + cx * CHUNK
			var z0 := -EXTENT + cz * CHUNK
			var center := Vector2(x0 + CHUNK * 0.5, z0 + CHUNK * 0.5)
			if center.length() > EXTENT + CHUNK * 0.5:
				continue
			for layer in layers:
				var lists: Array = [[], [], []]
				var count := int(CHUNK * CHUNK * float(layer.density))
				for _k in count:
					var x := x0 + rng.randf() * CHUNK
					var z := z0 + rng.randf() * CHUNK
					if Vector2(x, z).length() > EXTENT:
						continue
					var trail: float = terrain.mask_value(x, z, 0)
					var clear: float = terrain.mask_value(x, z, 1)
					var obstacle: float = terrain.mask_value(x, z, 2)
					if trail > 0.3 or clear > 0.25 or obstacle > 0.35:
						continue
					var pn := patch.get_noise_2d(x, z) * 0.5 + 0.5
					var h := lerpf(0.22, 0.6, pn) * rng.randf_range(0.8, 1.15) * float(layer.scale)
					if trail > 0.0:
						h *= lerpf(1.0, 0.45, trail / 0.3)
					var y: float = terrain.get_height(x, z) - 0.02
					var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(
						Vector3(h * rng.randf_range(0.85, 1.2), h, h * rng.randf_range(0.85, 1.2)))
					var v := 2 if rng.randf() < 0.14 else (rng.randi() % 2)
					lists[v].append(Transform3D(basis, Vector3(x, y, z)))
				for v in 3:
					if lists[v].is_empty():
						continue
					var split: float = layer.lite
					var end := float(layer.range) + PAD
					if split >= end:
						_add_multimesh(variants[v], lists[v], layer.mat, 0.0, end)
					else:
						_add_multimesh(variants[v], lists[v], layer.mat, 0.0, split)
						_add_multimesh(lite[v], lists[v], layer.mat, split, end)
			# [touceirinhas de cinco pétalas, margaridas]
			var flowers: Array = [[], []]
			var colors: Array = [[], []]
			for _k in flowers_per_chunk:
				var x := x0 + rng.randf() * CHUNK
				var z := z0 + rng.randf() * CHUNK
				if Vector2(x, z).length() > EXTENT - 4.0:
					continue
				if terrain.mask_value(x, z, 0) > 0.15 or terrain.mask_value(x, z, 1) > 0.2 or terrain.mask_value(x, z, 2) > 0.3:
					continue
				var s := rng.randf_range(0.9, 1.6)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
				# O tipo vem da posição (não gasta o sorteio do mapa): 3 em 10 são margaridas.
				var kind := 1 if fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0) < 0.3 else 0
				flowers[kind].append(Transform3D(basis, Vector3(x, terrain.get_height(x, z) - 0.01, z)))
				colors[kind].append(flower_colors[rng.randi() % flower_colors.size()])
			for kind in 2:
				if not flowers[kind].is_empty():
					_add_multimesh(flower_meshes[kind], flowers[kind], flower_mat, 0.0, near_dist * 1.2 + PAD, colors[kind])


## Mostra o bloco quando o centro dele está entre `from_dist` e `view_dist`.
func _add_multimesh(mesh: Mesh, xforms: Array, mat: Material, from_dist: float, view_dist: float,
		custom: Array = []) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = not custom.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_custom_data:
			mm.set_instance_custom_data(i, custom[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = view_dist
	mmi.visibility_range_begin = from_dist
	add_child(mmi)
