extends RefCounted
## Constrói o que o tamanduá vê de si mesmo em primeira pessoa: o focinho
## comprido e peludo (no centro, embaixo) e as patas dianteiras com garras
## enormes (aparecem ao cavar). Medidas reais, no espaço da câmera (olhando -Z).

const MeshBuilder := preload("res://scripts/procedural/mesh_builder.gd")
const FUR_SHADER := preload("res://shaders/fur.gdshader")

## Ponta do focinho (boca), no espaço da câmera.
const MOUTH := Vector3(0.0, -0.158, -0.578)
const SNOUT_DIR := Vector3(0.0, 0.02, -1.0)

static var _strands: NoiseTexture2D


static func strand_texture() -> NoiseTexture2D:
	if _strands == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
		n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
		n.frequency = 0.06
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
		_strands = NoiseTexture2D.new()
		_strands.width = 256
		_strands.height = 256
		_strands.seamless = true
		_strands.normalize = true
		_strands.noise = n
	return _strands


static func fur_material(length: float, density: float, thickness: float = 0.65) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FUR_SHADER
	m.set_shader_parameter("fur_length", length)
	m.set_shader_parameter("density", density)
	m.set_shader_parameter("thickness", thickness)
	m.set_shader_parameter("strand_tex", strand_texture())
	return m


## Copia a geometria da camada base em várias cascas para o shader de pelo.
static func _shells(base: MeshBuilder, shells: int) -> MeshBuilder:
	var out := MeshBuilder.new()
	out.use_uv2 = true
	var n := base.verts.size()
	for k in shells + 1:
		var h := float(k) / shells
		var off := out.verts.size()
		for i in n:
			out.verts.append(base.verts[i])
			out.normals.append(base.normals[i])
			out.colors.append(base.colors[i])
			out.uvs.append(base.uvs[i])
			out.uv2s.append(Vector2(h, 0.0))
		for idx in base.indices:
			out.indices.append(idx + off)
	return out


static func _catmull(pts: Array[Vector3], per_seg: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for k in per_seg:
			var t := float(k) / per_seg
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


static func build_snout(shells: int = 14) -> ArrayMesh:
	var ctrl: Array[Vector3] = [
		Vector3(0, -0.24, 0.0), Vector3(0, -0.222, -0.17), Vector3(0, -0.2, -0.33),
		Vector3(0, -0.181, -0.45), Vector3(0, -0.167, -0.53), MOUTH + Vector3(0, 0.0, 0.014)]
	var path := _catmull(ctrl, 6)
	var radii := PackedFloat32Array()
	for i in path.size():
		var t := float(i) / (path.size() - 1)
		radii.append(lerpf(0.062, 0.024, pow(t, 0.9)))
	var b := MeshBuilder.new()
	var sides := 28
	var start := b.verts.size()
	b.add_tube(path, radii, sides, true, false, 2.0)
	# Cor: cinza-amarronzado, mais escuro na ponta e embaixo.
	for i in range(start, b.verts.size()):
		var v := b.verts[i]
		var t := clampf((-v.z + 0.04) / 0.6, 0.0, 1.0)
		var top := clampf(b.normals[i].y * 0.5 + 0.5, 0.0, 1.0)
		var c := Color(0.36, 0.31, 0.27).lerp(Color(0.13, 0.11, 0.10), smoothstep(0.4, 1.0, t))
		c = c.lerp(c.darkened(0.3), 1.0 - top)
		b.colors[i] = c
	# Ponta arredondada com a boca (pele escura e lisa).
	var tip_ring := b.verts.size() - (sides + 1)
	var tip_center := path[path.size() - 1]
	var fwd := (path[path.size() - 1] - path[path.size() - 2]).normalized()
	b.color = Color(0.13, 0.10, 0.10)
	var rings := 4
	var last_ring := []
	for s in sides + 1:
		last_ring.append(tip_ring + s)
	for r in range(1, rings + 1):
		var f := float(r) / rings
		var ring_idx := []
		for s in sides + 1:
			var base_v := b.verts[tip_ring + s]
			var radial := base_v - tip_center
			var p := tip_center + radial * cos(f * PI * 0.5) + fwd * radii[radii.size() - 1] * sin(f * PI * 0.5) * 0.7
			var n := (radial.normalized() * cos(f * PI * 0.5) + fwd * sin(f * PI * 0.5)).normalized()
			var dark := smoothstep(0.4, 1.0, f)
			b.color = Color(0.30, 0.26, 0.24).lerp(Color(0.05, 0.03, 0.03), dark)
			ring_idx.append(b.add_vertex(p, n, Vector2(float(s) / sides, 1.0 + f * 0.1)))
		for s in sides:
			b.add_quad(last_ring[s], last_ring[s + 1], ring_idx[s + 1], ring_idx[s])
		last_ring = ring_idx
	var fur := _shells(b, shells)
	return fur.commit(null, fur_material(0.009, 40.0, 0.62))


## Pata dianteira com as garras (lado -1 esquerda, +1 direita), no espaço do ombro.
static func build_arm(side: float, shells: int = 10) -> ArrayMesh:
	var ctrl: Array[Vector3] = [
		Vector3(0, 0, 0), Vector3(side * -0.02, 0.06, -0.16), Vector3(side * -0.04, 0.1, -0.32),
		Vector3(side * -0.05, 0.11, -0.42)]
	var path := _catmull(ctrl, 5)
	var radii := PackedFloat32Array()
	for i in path.size():
		var t := float(i) / (path.size() - 1)
		radii.append(lerpf(0.075, 0.05, t))
	var b := MeshBuilder.new()
	b.add_tube(path, radii, 18, true, true, 2.0)
	for i in b.verts.size():
		var v := b.verts[i]
		var t := clampf(-v.z / 0.42, 0.0, 1.0)
		var band := smoothstep(0.55, 0.62, t) * (1.0 - smoothstep(0.78, 0.85, t))
		var c := Color(0.86, 0.82, 0.74).lerp(Color(0.08, 0.07, 0.07), band)
		b.colors[i] = c
	var mesh := _shells(b, shells).commit(null, fur_material(0.014, 30.0, 0.7))
	# Garras: três curvas grandes, a do meio enorme.
	var claws := MeshBuilder.new()
	claws.color = Color(0.12, 0.1, 0.09)
	var paw := path[path.size() - 1]
	for k in 3:
		var off := Vector3((k - 1) * 0.03 * side, -0.01, 0.0)
		var big := 1.6 if k == 1 else 1.0
		var pts := PackedVector3Array()
		var rr := PackedFloat32Array()
		for j in 6:
			var t := j / 5.0
			pts.append(paw + off + Vector3(0, -0.03 - t * t * 0.07 * big, -0.02 - t * 0.09 * big))
			rr.append(lerpf(0.016 * big, 0.002, t))
		claws.add_tube(pts, rr, 8, true, true)
	var claw_mat := StandardMaterial3D.new()
	claw_mat.vertex_color_use_as_albedo = true
	claw_mat.roughness = 0.25
	claw_mat.metallic_specular = 0.7
	claws.commit(mesh, claw_mat)
	return mesh


## Cilindro unitário para a língua (anel em xy, comprimento em z de 0 a 1).
static func build_tongue_mesh(segments: int = 40, sides: int = 10) -> ArrayMesh:
	var b := MeshBuilder.new()
	for i in segments + 1:
		var t := float(i) / segments
		for s in sides + 1:
			var a := TAU * s / sides
			b.add_vertex(Vector3(cos(a), sin(a), t), Vector3(cos(a), sin(a), 0), Vector2(float(s) / sides, t))
	var row := sides + 1
	for i in segments:
		for s in sides:
			var a := i * row + s
			b.add_quad(a, a + 1, a + row + 1, a + row)
	# Ponta fechada.
	var tip := b.add_vertex(Vector3(0, 0, 1.0), Vector3(0, 0, 1), Vector2(0.5, 1.0))
	for s in sides:
		b.add_tri(segments * row + s, segments * row + s + 1, tip)
	var mesh := b.commit()
	return mesh
