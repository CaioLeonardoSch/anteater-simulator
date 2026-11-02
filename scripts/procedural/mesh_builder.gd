extends RefCounted
## Construtor de malhas procedurais (formas suaves, nada de low poly).
## Acumula vértices em arrays compactos e gera um ArrayMesh com cores
## e canais CUSTOM0/CUSTOM1 opcionais (usados para animar formigas no shader).


var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var custom0 := PackedFloat32Array()
var custom1 := PackedFloat32Array()
var indices := PackedInt32Array()

var use_custom0 := false
var use_custom1 := false
var use_uv2 := false

var color := Color.WHITE
var c0 := Color(0, 0, 0, 0)
var c1 := Color(0, 0, 0, 0)
var uv2 := Vector2.ZERO
## Transformação aplicada a tudo o que for adicionado (posição e normal).
var xform := Transform3D.IDENTITY


func vertex_count() -> int:
	return verts.size()


func add_vertex(p: Vector3, n: Vector3, uv: Vector2 = Vector2.ZERO) -> int:
	verts.append(xform * p)
	normals.append((xform.basis * n).normalized())
	uvs.append(uv)
	colors.append(color)
	if use_uv2:
		uv2s.append(uv2)
	if use_custom0:
		custom0.append(c0.r)
		custom0.append(c0.g)
		custom0.append(c0.b)
		custom0.append(c0.a)
	if use_custom1:
		custom1.append(c1.r)
		custom1.append(c1.g)
		custom1.append(c1.b)
		custom1.append(c1.a)
	return verts.size() - 1


## Triângulo com vértices em sentido anti-horário vistos de fora.
## (O Godot usa sentido horário para a face da frente, então invertemos aqui.)
func add_tri(a: int, b: int, c: int) -> void:
	indices.append(a)
	indices.append(c)
	indices.append(b)


func add_quad(a: int, b: int, c: int, d: int) -> void:
	add_tri(a, b, c)
	add_tri(a, c, d)


## Recalcula normais pela média das faces (para malhas deformadas por ruído).
func recompute_normals(from_vertex: int = 0) -> void:
	var acc := PackedVector3Array()
	acc.resize(verts.size())
	for i in range(0, indices.size(), 3):
		var ia := indices[i]
		var ib := indices[i + 1]
		var ic := indices[i + 2]
		if ia < from_vertex:
			continue
		var n := (verts[ic] - verts[ia]).cross(verts[ib] - verts[ia])
		acc[ia] += n
		acc[ib] += n
		acc[ic] += n
	for i in range(from_vertex, verts.size()):
		if acc[i].length_squared() > 0.0:
			normals[i] = acc[i].normalized()


func commit(mesh: ArrayMesh = null, material: Material = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if use_uv2:
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	var flags := 0
	if use_custom0:
		arrays[Mesh.ARRAY_CUSTOM0] = custom0
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	if use_custom1:
		arrays[Mesh.ARRAY_CUSTOM1] = custom1
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	if material:
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


func clear() -> void:
	verts.clear()
	normals.clear()
	colors.clear()
	uvs.clear()
	uv2s.clear()
	custom0.clear()
	custom1.clear()
	indices.clear()


# ------------------------------------------------------------------ Formas

## Elipsoide suave. `basis` orienta os raios; `taper` afina um dos polos (-1..1).
func add_ellipsoid(center: Vector3, radii: Vector3, rings: int = 14, segments: int = 20,
		basis: Basis = Basis.IDENTITY, taper: float = 0.0) -> void:
	var start := verts.size()
	for i in rings + 1:
		var v := float(i) / rings
		var theta := v * PI
		var y := cos(theta)
		var r := sin(theta)
		var t := 1.0 + taper * y
		for j in segments + 1:
			var u := float(j) / segments
			var phi := u * TAU
			var local := Vector3(r * cos(phi) * t, y, r * sin(phi) * t)
			var p := local * radii
			var n := Vector3(local.x / radii.x, local.y / radii.y, local.z / radii.z)
			add_vertex(center + basis * p, (basis * n).normalized(), Vector2(u, v))
	var row := segments + 1
	for i in rings:
		for j in segments:
			var a := start + i * row + j
			var b := a + 1
			var c := a + row + 1
			var d := a + row
			# Anti-horário visto de fora.
			add_quad(a, b, c, d)


## Tubo suave ao longo de uma curva (troncos, pernas, antenas, cauda).
func add_tube(points: PackedVector3Array, radii: PackedFloat32Array, sides: int = 10,
		cap_start: bool = true, cap_end: bool = true, v_scale: float = 1.0) -> void:
	var count := points.size()
	if count < 2:
		return
	var tangents := PackedVector3Array()
	tangents.resize(count)
	for i in count:
		var t: Vector3
		if i == 0:
			t = points[1] - points[0]
		elif i == count - 1:
			t = points[i] - points[i - 1]
		else:
			t = points[i + 1] - points[i - 1]
		tangents[i] = t.normalized()
	# Transporte paralelo para evitar torções.
	var normal := tangents[0].cross(Vector3.UP)
	if normal.length_squared() < 0.0001:
		normal = tangents[0].cross(Vector3.RIGHT)
	normal = normal.normalized()
	var start := verts.size()
	var length_acc := 0.0
	for i in count:
		if i > 0:
			var axis := tangents[i - 1].cross(tangents[i])
			if axis.length_squared() > 0.000001:
				var ang := tangents[i - 1].angle_to(tangents[i])
				normal = normal.rotated(axis.normalized(), ang)
			length_acc += points[i].distance_to(points[i - 1])
		var binormal := tangents[i].cross(normal).normalized()
		var nrm := binormal.cross(tangents[i]).normalized()
		for s in sides + 1:
			var a := TAU * float(s) / sides
			var dir := nrm * cos(a) + binormal * sin(a)
			add_vertex(points[i] + dir * radii[i], dir, Vector2(float(s) / sides, length_acc * v_scale))
	var row := sides + 1
	for i in count - 1:
		for s in sides:
			var a := start + i * row + s
			var b := a + 1
			var c := a + row + 1
			var d := a + row
			add_quad(a, b, c, d)
	if cap_start:
		_add_cap(points[0], -tangents[0], start, sides, radii[0], true)
	if cap_end:
		_add_cap(points[count - 1], tangents[count - 1], start + (count - 1) * row, sides, radii[count - 1], false)


func _add_cap(center: Vector3, dir: Vector3, ring_start: int, sides: int, radius: float, flip: bool) -> void:
	# Tampa arredondada (meia esfera achatada) para pontas suaves.
	var tip := add_vertex(center + dir * radius * 0.6, dir, Vector2(0.5, 0.5))
	for s in sides:
		var a := ring_start + s
		var b := ring_start + s + 1
		if flip:
			add_tri(tip, b, a)
		else:
			add_tri(tip, a, b)


## Esfera geodésica (icosfera) deformada por ruído: rochas, copas, cupinzeiros.
func add_blob(center: Vector3, radii: Vector3, noise: FastNoiseLite, amount: float,
		subdiv: int = 3, noise_scale: float = 1.0, basis: Basis = Basis.IDENTITY,
		flatten_bottom: float = -10.0) -> void:
	var ico := _icosphere(subdiv)
	var pts: PackedVector3Array = ico[0]
	var tris: PackedInt32Array = ico[1]
	var start := verts.size()
	for p in pts:
		var d := 1.0
		if noise:
			var q := p * noise_scale + center * 0.37
			d += amount * noise.get_noise_3d(q.x * 10.0, q.y * 10.0, q.z * 10.0)
		var lp := p * d * radii
		if lp.y < flatten_bottom:
			lp.y = flatten_bottom + (lp.y - flatten_bottom) * 0.15
		var uv := Vector2(atan2(p.z, p.x) / TAU + 0.5, acos(clampf(p.y, -1.0, 1.0)) / PI)
		add_vertex(center + basis * lp, basis * p, uv)
	for i in range(0, tris.size(), 3):
		add_tri(start + tris[i], start + tris[i + 1], start + tris[i + 2])
	recompute_normals(start)


static var _ico_cache: Dictionary = {}

static func _icosphere(subdiv: int) -> Array:
	if _ico_cache.has(subdiv):
		return _ico_cache[subdiv]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var pts := PackedVector3Array([
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)])
	for i in pts.size():
		pts[i] = pts[i].normalized()
	var tris := PackedInt32Array([
		0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
		1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
		4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for _s in subdiv:
		var cache := {}
		var new_tris := PackedInt32Array()
		for i in range(0, tris.size(), 3):
			var a := tris[i]
			var b := tris[i + 1]
			var c := tris[i + 2]
			var ab := _midpoint(pts, cache, a, b)
			var bc := _midpoint(pts, cache, b, c)
			var ca := _midpoint(pts, cache, c, a)
			new_tris.append_array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca])
		tris = new_tris
	# A tabela clássica já está em sentido anti-horário visto de fora.
	var result := [pts, tris]
	_ico_cache[subdiv] = result
	return result


static func _midpoint(pts: PackedVector3Array, cache: Dictionary, a: int, b: int) -> int:
	var key := mini(a, b) * 100000 + maxi(a, b)
	if cache.has(key):
		return cache[key]
	pts.append(((pts[a] + pts[b]) * 0.5).normalized())
	var idx := pts.size() - 1
	cache[key] = idx
	return idx


## Fita curva (folhas de capim, pétalas, asas): lista de pontos centrais e larguras.
func add_ribbon(points: PackedVector3Array, widths: PackedFloat32Array, side: Vector3,
		normal: Vector3, heights: PackedFloat32Array = PackedFloat32Array()) -> void:
	var start := verts.size()
	var count := points.size()
	for i in count:
		var v := float(i) / maxf(count - 1, 1)
		if heights.size() == count:
			v = heights[i]
		var w := widths[i] * 0.5
		if w <= 0.00001:
			add_vertex(points[i], normal, Vector2(0.5, v))
		else:
			add_vertex(points[i] - side * w, normal, Vector2(0.0, v))
			add_vertex(points[i] + side * w, normal, Vector2(1.0, v))
	# Monta triângulos considerando pontas de largura zero.
	var idx := start
	for i in count - 1:
		var w0 := widths[i] > 0.00001
		var w1 := widths[i + 1] > 0.00001
		if w0 and w1:
			add_quad(idx, idx + 1, idx + 3, idx + 2)
			idx += 2
		elif w0 and not w1:
			add_tri(idx, idx + 1, idx + 2)
			idx += 2
		elif not w0 and w1:
			add_tri(idx, idx + 2, idx + 1)
			idx += 1
		else:
			idx += 1
