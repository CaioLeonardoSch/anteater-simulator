extends Node3D
## Campo de capim e flores: instâncias em blocos (MultiMesh).
## Duas camadas: capim denso perto do jogador (some suavemente a ~25 m) e
## capim espaçado até o horizonte. Assim o campo é cheio sem pesar na placa de vídeo.

const Props := preload("res://scripts/world/props.gd")

const CHUNK := 16.0
const EXTENT := 78.0


func build(terrain, mats, rng: RandomNumberGenerator, density_mult: float, view_dist: float) -> void:
	var variants: Array[ArrayMesh] = [
		Props.build_grass_clump(rng, 12, false),
		Props.build_grass_clump(rng, 15, false),
		Props.build_grass_clump(rng, 10, true),
	]
	var flower_mesh := Props.build_flower_mesh()
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
	var layers := [
		{"density": 1.1, "mat": far_mat, "range": view_dist, "scale": 1.12},
		{"density": 3.0 * density_mult, "mat": near_mat, "range": near_dist, "scale": 1.0},
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
					if not lists[v].is_empty():
						_add_multimesh(variants[v], lists[v], layer.mat, float(layer.range))
			var flowers: Array = []
			var colors: Array = []
			for _k in flowers_per_chunk:
				var x := x0 + rng.randf() * CHUNK
				var z := z0 + rng.randf() * CHUNK
				if Vector2(x, z).length() > EXTENT - 4.0:
					continue
				if terrain.mask_value(x, z, 0) > 0.15 or terrain.mask_value(x, z, 1) > 0.2 or terrain.mask_value(x, z, 2) > 0.3:
					continue
				var s := rng.randf_range(0.9, 1.6)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
				flowers.append(Transform3D(basis, Vector3(x, terrain.get_height(x, z) - 0.01, z)))
				colors.append(flower_colors[rng.randi() % flower_colors.size()])
			if not flowers.is_empty():
				_add_multimesh(flower_mesh, flowers, flower_mat, near_dist * 1.2, colors)


func _add_multimesh(mesh: Mesh, xforms: Array, mat: Material, view_dist: float, custom: Array = []) -> void:
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
	mmi.visibility_range_end = view_dist + CHUNK * 0.75
	add_child(mmi)
