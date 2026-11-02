extends Node3D
## Terreno procedural do cerrado: relevo suave, malha visual, colisão e
## uma "máscara" (textura) que marca trilhas, clareiras e obstáculos.

const SIZE := 160.0
const RES := 256
const COLLISION_RES := 160
const PLAY_RADIUS := 60.0
const MASK_RES := 512

var heights := PackedFloat32Array()
var cell := SIZE / RES
var noise_big := FastNoiseLite.new()
var noise_small := FastNoiseLite.new()
var noise_ring := FastNoiseLite.new()
## Áreas planas: Vector3(x, z, raio).
var flat_spots: Array[Vector3] = []
var _flat_targets: Array[float] = []

var mask_data := PackedByteArray()
var mask_texture: ImageTexture
var mesh_instance: MeshInstance3D


func setup(seed_value: int, spots: Array[Vector3]) -> void:
	noise_big.seed = seed_value
	noise_big.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_big.frequency = 0.012
	noise_big.fractal_octaves = 3
	noise_small.seed = seed_value + 17
	noise_small.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_small.frequency = 0.07
	noise_small.fractal_octaves = 2
	noise_ring.seed = seed_value + 99
	noise_ring.frequency = 0.02
	flat_spots = spots
	_flat_targets.clear()
	for s in flat_spots:
		_flat_targets.append(_base_height(s.x, s.y))
	mask_data.resize(MASK_RES * MASK_RES * 4)
	mask_data.fill(0)


func _base_height(x: float, z: float) -> float:
	var h := noise_big.get_noise_2d(x, z) * 2.4 + noise_small.get_noise_2d(x, z) * 0.3
	var r := sqrt(x * x + z * z)
	var rise := smoothstep(PLAY_RADIUS - 4.0, PLAY_RADIUS + 26.0, r)
	h += rise * (6.0 + 4.0 * noise_ring.get_noise_2d(x, z))
	return h


func height_fn(x: float, z: float) -> float:
	var h := _base_height(x, z)
	for i in flat_spots.size():
		var s := flat_spots[i]
		var d := Vector2(x - s.x, z - s.y).length()
		if d < s.z:
			var w := 1.0 - smoothstep(s.z * 0.55, s.z, d)
			h = lerpf(h, _flat_targets[i], w)
	return h


func build(material: Material) -> void:
	var n := RES + 1
	heights.resize(n * n)
	for j in n:
		var z := -SIZE * 0.5 + j * cell
		for i in n:
			heights[j * n + i] = height_fn(-SIZE * 0.5 + i * cell, z)
	_build_mesh(material)
	_build_collision()


## Altura interpolada (bilinear) em qualquer ponto do mapa.
func get_height(x: float, z: float) -> float:
	var n := RES + 1
	var fx := clampf((x + SIZE * 0.5) / cell, 0.0, RES - 0.001)
	var fz := clampf((z + SIZE * 0.5) / cell, 0.0, RES - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i0 := iz * n + ix
	var h00 := heights[i0]
	var h10 := heights[i0 + 1]
	var h01 := heights[i0 + n]
	var h11 := heights[i0 + n + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func get_normal(x: float, z: float) -> Vector3:
	var e := cell
	var hl := get_height(x - e, z)
	var hr := get_height(x + e, z)
	var hd := get_height(x, z - e)
	var hu := get_height(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()


func _build_mesh(material: Material) -> void:
	var n := RES + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(n * n)
	norms.resize(n * n)
	uvs.resize(n * n)
	for j in n:
		for i in n:
			var idx := j * n + i
			var x := -SIZE * 0.5 + i * cell
			var z := -SIZE * 0.5 + j * cell
			verts[idx] = Vector3(x, heights[idx], z)
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, RES)]
			var hd := heights[maxi(j - 1, 0) * n + i]
			var hu := heights[mini(j + 1, RES) * n + i]
			norms[idx] = Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
			uvs[idx] = Vector2(x, z) * 0.25
	var idxs := PackedInt32Array()
	idxs.resize(RES * RES * 6)
	var k := 0
	for j in RES:
		for i in RES:
			var a := j * n + i
			var b := a + 1
			var c := a + n + 1
			var d := a + n
			idxs[k] = a
			idxs[k + 1] = b
			idxs[k + 2] = c
			idxs[k + 3] = a
			idxs[k + 4] = c
			idxs[k + 5] = d
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idxs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = mesh
	add_child(mesh_instance)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var shape := HeightMapShape3D.new()
	var n := COLLISION_RES + 1
	shape.map_width = n
	shape.map_depth = n
	var data := PackedFloat32Array()
	data.resize(n * n)
	var step := SIZE / COLLISION_RES
	for j in n:
		for i in n:
			data[j * n + i] = get_height(-SIZE * 0.5 + i * step, -SIZE * 0.5 + j * step)
	shape.map_data = data
	var col := CollisionShape3D.new()
	col.shape = shape
	col.scale = Vector3(step, 1.0, step)
	body.add_child(col)
	add_child(body)


# ------------------------------------------------------------------ Máscara

func _mask_px(x: float, z: float) -> Vector2:
	return Vector2((x / SIZE + 0.5) * MASK_RES, (z / SIZE + 0.5) * MASK_RES)


## Pinta um círculo suave num canal da máscara (0 = trilha, 1 = clareira, 2 = obstáculo).
func mask_paint(x: float, z: float, radius: float, channel: int, strength: float = 1.0) -> void:
	var c := _mask_px(x, z)
	var rp := radius / SIZE * MASK_RES
	var x0 := maxi(int(c.x - rp - 1), 0)
	var x1 := mini(int(c.x + rp + 1), MASK_RES - 1)
	var y0 := maxi(int(c.y - rp - 1), 0)
	var y1 := mini(int(c.y + rp + 1), MASK_RES - 1)
	for py in range(y0, y1 + 1):
		for px in range(x0, x1 + 1):
			var d := Vector2(px + 0.5, py + 0.5).distance_to(c) / maxf(rp, 0.001)
			if d >= 1.0:
				continue
			var v := int(clampf((1.0 - d * d) * strength * 1.6, 0.0, 1.0) * 255.0)
			var idx := (py * MASK_RES + px) * 4 + channel
			if v > mask_data[idx]:
				mask_data[idx] = v


func mask_value(x: float, z: float, channel: int) -> float:
	var c := _mask_px(x, z)
	var px := clampi(int(c.x), 0, MASK_RES - 1)
	var py := clampi(int(c.y), 0, MASK_RES - 1)
	return mask_data[(py * MASK_RES + px) * 4 + channel] / 255.0


func finalize_mask() -> ImageTexture:
	var img := Image.create_from_data(MASK_RES, MASK_RES, false, Image.FORMAT_RGBA8, mask_data)
	mask_texture = ImageTexture.create_from_image(img)
	return mask_texture
