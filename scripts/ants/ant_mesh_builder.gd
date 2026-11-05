extends RefCounted
## Gera as malhas das formigas (saúvas): operária com folha, rainha de abdômen
## enorme e tanajura alada. Cada vértice carrega dados de animação (CUSTOM0/CUSTOM1) que o
## shader usa para mexer pernas, antenas, mandíbulas e asas.
## Unidade: a formiga tem ~1 de comprimento, olha para -Z e pisa em y = 0.
## As operárias andam em grupos de 10: `squad()` junta 10 cópias numa malha só
## (CUSTOM1.w = qual delas) e o shader espalha cada uma no seu lugar.
## LOD: 0 = detalhada (perto), 1 = simples, 2 = bem simples, 3 = mínima (longe).

const MeshBuilder := preload("res://scripts/procedural/mesh_builder.gd")
const ModelLibrary := preload("res://scripts/model_library.gd")
const ANT_SHADER := preload("res://shaders/ant.gdshader")
const WING_SHADER := preload("res://shaders/ant_wing.gdshader")

enum Part { BODY, LEG, ANTENNA, LEAF, WING, MANDIBLE, HAT }

const KIND_MODEL := {"worker": "formiga_operaria", "queen": "formiga_rainha", "tanajura": "formiga_tanajura"}

static var body_material: ShaderMaterial
static var wing_material: ShaderMaterial


static func materials() -> void:
	if body_material == null:
		body_material = ShaderMaterial.new()
		body_material.shader = ANT_SHADER
		wing_material = ShaderMaterial.new()
		wing_material.shader = WING_SHADER


static func _tag(b: MeshBuilder, part: int, pivot: Vector3 = Vector3.ZERO, phase: float = 0.0, side: float = 0.0) -> void:
	b.c0 = Color(pivot.x, pivot.y, pivot.z, float(part))
	b.c1 = Color(1.0, phase, side, 0.0)


## Retorna a malha da formiga. Se houver um modelo de IA (assets/models), usa-o.
static func build(kind: String, lod: int = 0) -> ArrayMesh:
	materials()
	var ai := _from_model(kind)
	if ai:
		return ai
	var b := MeshBuilder.new()
	b.use_custom0 = true
	b.use_custom1 = true
	var tiny := lod >= 2
	var rings: int = [12, 6, 4][clampi(lod, 0, 2)]
	var segs: int = [18, 8, 6][clampi(lod, 0, 2)]
	var leg_sides: int = [6, 4, 3][clampi(lod, 0, 2)]
	var head_s := 1.0
	var gaster_s := 1.0
	var mand_s := 1.0
	var c_head := Color(0.42, 0.15, 0.07)
	var c_meso := Color(0.37, 0.13, 0.06)
	var c_gaster := Color(0.27, 0.09, 0.05)
	var c_leg := Color(0.32, 0.12, 0.06)
	match kind:
		"queen":
			# Rainha: abdômen enorme e listrado, cabeça grande, sem asas.
			head_s = 1.12
			gaster_s = 2.35
			mand_s = 1.2
			c_head = Color(0.36, 0.13, 0.06)
			c_meso = Color(0.40, 0.15, 0.07)
			c_gaster = Color(0.52, 0.22, 0.08)
			c_leg = Color(0.30, 0.11, 0.05)
		"tanajura":
			head_s = 0.92
			gaster_s = 1.75
			c_head = Color(0.45, 0.22, 0.09)
			c_meso = Color(0.50, 0.26, 0.10)
			c_gaster = Color(0.66, 0.34, 0.11)
			c_leg = Color(0.40, 0.2, 0.08)
	if lod >= 4:
		return _build_nano(b, kind, c_head, c_meso, c_gaster, c_leg, gaster_s, head_s)
	if lod >= 3:
		return _build_micro(b, kind, c_head, c_meso, c_gaster, c_leg, gaster_s, head_s)
	# --- Corpo
	_tag(b, Part.BODY)
	b.color = c_gaster
	var gz := 0.30 + (gaster_s - 1.0) * 0.16
	b.add_ellipsoid(Vector3(0, 0.21 + (gaster_s - 1.0) * 0.05, gz), Vector3(0.15, 0.13, 0.2) * gaster_s, rings, segs, Basis(Vector3.RIGHT, -0.25))
	if (kind == "tanajura" or kind == "queen") and not tiny:
		# Listras douradas no abdômen da tanajura e da rainha.
		b.color = Color(0.88, 0.62, 0.22)
		for k in 3:
			var zz := gz - 0.12 + k * 0.12
			b.add_ellipsoid(Vector3(0, 0.215 + (gaster_s - 1.0) * 0.05, zz), Vector3(0.152, 0.132, 0.025) * gaster_s, 6, segs, Basis(Vector3.RIGHT, -0.25))
	b.color = c_meso
	if not tiny:
		b.add_ellipsoid(Vector3(0, 0.19, 0.11), Vector3(0.045, 0.045, 0.045), 6, segs / 2)
		b.add_ellipsoid(Vector3(0, 0.2, 0.05), Vector3(0.05, 0.055, 0.05), 6, segs / 2)
	b.add_ellipsoid(Vector3(0, 0.2, -0.07), Vector3(0.075, 0.075, 0.135), rings, segs, Basis(Vector3.RIGHT, 0.18))
	# Espinhos do tórax (marca das saúvas).
	if lod == 0:
		for sx in [-1.0, 1.0]:
			b.add_tube(PackedVector3Array([Vector3(sx * 0.035, 0.25, -0.12), Vector3(sx * 0.06, 0.32, -0.13)]),
				PackedFloat32Array([0.016, 0.004]), 5, false, true)
	# Cabeça em forma de coração.
	b.color = c_head
	if tiny:
		b.add_ellipsoid(Vector3(0, 0.235, -0.29 - (head_s - 1.0) * 0.06), Vector3(0.15, 0.1, 0.12) * head_s, rings, segs)
	else:
		for sx in [-1.0, 1.0]:
			b.add_ellipsoid(Vector3(sx * 0.055 * head_s, 0.245, -0.255 - (head_s - 1.0) * 0.05), Vector3(0.105, 0.1, 0.115) * head_s, rings, segs)
		b.add_ellipsoid(Vector3(0, 0.22, -0.32 - (head_s - 1.0) * 0.08), Vector3(0.115, 0.085, 0.095) * head_s, rings, segs)
		# Olhos brilhantes.
		b.color = Color(0.05, 0.03, 0.02)
		for sx in [-1.0, 1.0]:
			b.add_ellipsoid(Vector3(sx * 0.115 * head_s, 0.255, -0.335 - (head_s - 1.0) * 0.08), Vector3(0.03, 0.032, 0.03) * clampf(head_s, 1.0, 1.2), 6, 10)
	var head_front := -0.4 - (head_s - 1.0) * 0.14
	# --- Mandíbulas
	b.color = Color(0.32, 0.12, 0.05)
	for sx in ([] if tiny else [-1.0, 1.0]):
		var piv := Vector3(sx * 0.045, 0.19, head_front)
		_tag(b, Part.MANDIBLE, piv, 0.0, sx)
		var pts := PackedVector3Array([piv, piv + Vector3(sx * 0.012, -0.008, -0.06) * mand_s, piv + Vector3(-sx * 0.025, -0.015, -0.11) * mand_s])
		b.add_tube(pts, PackedFloat32Array([0.022, 0.016, 0.006]) , leg_sides, false, true)
	# --- Antenas
	b.color = c_leg
	for sx in [-1.0, 1.0]:
		var piv := Vector3(sx * 0.05 * head_s, 0.27, head_front + 0.03)
		_tag(b, Part.ANTENNA, piv, 0.0, sx)
		var elbow := piv + Vector3(sx * 0.11, 0.13, -0.02)
		var tip := elbow + Vector3(sx * 0.07, -0.03, -0.24)
		if tiny:
			b.add_tube(PackedVector3Array([piv, elbow, tip]), PackedFloat32Array([0.014, 0.012, 0.014]), leg_sides, false, true)
		else:
			var pts := PackedVector3Array([piv, piv.lerp(elbow, 0.5), elbow, elbow.lerp(tip, 0.5), tip])
			b.add_tube(pts, PackedFloat32Array([0.012, 0.011, 0.01, 0.01, 0.016]), leg_sides, false, true)
	# --- Pernas (tripé: L1, R2, L3 numa fase; R1, L2, R3 na outra)
	b.color = c_leg
	var hip_z := [-0.12, -0.05, 0.02]
	var knee_d := [Vector3(0.2, 0.13, -0.1), Vector3(0.22, 0.13, 0.0), Vector3(0.2, 0.13, 0.1)]
	var foot_d := [Vector3(0.36, -0.2, -0.27), Vector3(0.42, -0.2, 0.03), Vector3(0.38, -0.2, 0.32)]
	for leg in 3:
		for sx in [-1.0, 1.0]:
			var hip := Vector3(sx * 0.06, 0.17, hip_z[leg])
			var phase := 0.0
			if (leg == 1) == (sx < 0.0):
				phase = PI
			_tag(b, Part.LEG, hip, phase, sx)
			var kd: Vector3 = knee_d[leg]
			var fd: Vector3 = foot_d[leg]
			var knee := hip + Vector3(sx * kd.x, kd.y, kd.z)
			var foot := hip + Vector3(sx * fd.x, fd.y + 0.03, fd.z)
			foot.y = 0.012
			var tarsus := foot + Vector3(sx * 0.05, -0.005, fd.z * 0.15)
			if tiny:
				b.add_tube(PackedVector3Array([hip, knee, foot]), PackedFloat32Array([0.026, 0.02, 0.014]), leg_sides, false, true)
			else:
				var pts := PackedVector3Array([hip, hip.lerp(knee, 0.5), knee, knee.lerp(foot, 0.5), foot, tarsus])
				b.add_tube(pts, PackedFloat32Array([0.024, 0.022, 0.019, 0.015, 0.012, 0.008]), leg_sides, false, true)
	# --- Folha carregada (operária)
	if kind == "worker":
		_tag(b, Part.LEAF, Vector3(0, 0.17, head_front - 0.09))
		b.color = Color(0.36, 0.72, 0.18)
		_add_leaf(b, Vector3(0, 0.17, head_front - 0.09), 6 if tiny else 14)
		_add_hat(b, tiny)
	var mesh := b.commit(null, body_material)
	# --- Asas (superfície translúcida separada)
	if kind == "tanajura":
		var w := MeshBuilder.new()
		w.use_custom0 = true
		w.use_custom1 = true
		w.color = Color.WHITE
		for sx in [-1.0, 1.0]:
			for pair in 2:
				var piv := Vector3(sx * 0.04, 0.27, -0.09 + pair * 0.06)
				_tag(w, Part.WING, piv, 0.0, sx)
				var length := 0.95 if pair == 0 else 0.7
				var width := 0.2 if pair == 0 else 0.15
				_add_wing(w, piv, sx, length, width)
		w.commit(mesh, wing_material)
	return mesh


## Formiga mínima, para longe (poucos pixels): três gomos, um traço de perna de
## cada lado e a folha.
static func _build_micro(b: MeshBuilder, kind: String, c_head: Color, c_meso: Color, c_gaster: Color, c_leg: Color,
		gaster_s: float, head_s: float) -> ArrayMesh:
	_tag(b, Part.BODY)
	b.color = c_gaster
	b.add_ellipsoid(Vector3(0, 0.21, 0.3 + (gaster_s - 1.0) * 0.16), Vector3(0.15, 0.13, 0.2) * gaster_s, 3, 5)
	b.color = c_meso
	b.add_ellipsoid(Vector3(0, 0.2, -0.07), Vector3(0.08, 0.08, 0.14), 3, 5)
	b.color = c_head
	b.add_ellipsoid(Vector3(0, 0.235, -0.29), Vector3(0.15, 0.1, 0.12) * head_s, 3, 5)
	b.color = c_leg
	for sx in [-1.0, 1.0]:
		var hip := Vector3(sx * 0.06, 0.17, -0.05)
		_tag(b, Part.LEG, hip, PI if sx > 0.0 else 0.0, sx)
		b.add_tube(PackedVector3Array([hip, hip + Vector3(sx * 0.4, -0.16, 0.02)]), PackedFloat32Array([0.05, 0.03]), 3, false, true)
	if kind == "worker":
		var grip := Vector3(0, 0.17, -0.49)
		_tag(b, Part.LEAF, grip)
		b.color = Color(0.36, 0.72, 0.18)
		_add_leaf(b, grip, 5)
	return b.commit(null, body_material)


## Bem longe (a formiga tem 2 ou 3 pixels): só o corpo em 3 gomos, um par de
## pernas e a folha (o ponto verde que mostra a fila de longe).
static func _build_nano(b: MeshBuilder, kind: String, c_head: Color, c_meso: Color, c_gaster: Color, c_leg: Color,
		gaster_s: float, head_s: float) -> ArrayMesh:
	_tag(b, Part.BODY)
	b.color = c_gaster
	b.add_ellipsoid(Vector3(0, 0.21, 0.3 + (gaster_s - 1.0) * 0.16), Vector3(0.15, 0.13, 0.2) * gaster_s, 2, 4)
	b.color = c_meso
	b.add_ellipsoid(Vector3(0, 0.2, -0.07), Vector3(0.08, 0.08, 0.14), 2, 4)
	b.color = c_head
	b.add_ellipsoid(Vector3(0, 0.235, -0.29), Vector3(0.15, 0.1, 0.12) * head_s, 2, 4)
	b.color = c_leg
	# Pernas paradas (de longe não dá para ver o passo).
	var hip := Vector3(-0.06, 0.17, -0.05)
	b.add_tube(PackedVector3Array([hip + Vector3(-0.34, -0.16, 0.02), hip, hip + Vector3(0.46, -0.16, 0.02)]),
		PackedFloat32Array([0.03, 0.05, 0.03]), 3, false, true)
	if kind == "worker":
		var grip := Vector3(0, 0.17, -0.49)
		_tag(b, Part.LEAF, grip)
		b.color = Color(0.36, 0.72, 0.18)
		_add_leaf(b, grip, 4)
	return b.commit(null, body_material)


## Chapéu de Natal (só aparece numa formiga sorteada a cada 16 000; o shader
## esconde nas outras): cone vermelho caído para trás, aba e pompom brancos.
static func _add_hat(b: MeshBuilder, tiny: bool) -> void:
	var base := Vector3(0, 0.33, -0.27)
	_tag(b, Part.HAT, base)
	var sides := 5 if tiny else 10
	b.color = Color(0.86, 0.08, 0.06)
	var pts := PackedVector3Array([base, base + Vector3(0, 0.08, 0.02), base + Vector3(0, 0.15, 0.07), base + Vector3(0, 0.18, 0.15)])
	b.add_tube(pts, PackedFloat32Array([0.085, 0.062, 0.035, 0.012]), sides, false, true)
	b.color = Color(0.96, 0.95, 0.92)
	b.add_ellipsoid(base + Vector3(0, 0.005, 0), Vector3(0.1, 0.026, 0.1), 4 if tiny else 6, sides)
	b.add_ellipsoid(pts[3] + Vector3(0, -0.005, 0.01), Vector3.ONE * 0.03, 3 if tiny else 5, sides)


static func _add_leaf(b: MeshBuilder, grip: Vector3, count: int = 14) -> void:
	# Pedaço de folha meio redondo, em pé, preso na mandíbula (face dupla no shader).
	var center := grip + Vector3(0, 0.26, 0.16)
	var n := Vector3.RIGHT
	var c := b.add_vertex(center, n, Vector2(0.5, 0.5))
	var g := b.add_vertex(grip, n, Vector2(0.5, 1.0))
	var idx: Array[int] = []
	for k in count:
		var a := PI * 0.05 + PI * 1.9 * k / (count - 1)
		var r := 0.27 * (0.85 + 0.15 * sin(a * 3.0))
		var p := center + Vector3(0.012 * sin(a * 2.0), -cos(a) * r, sin(a) * r * 0.9)
		idx.append(b.add_vertex(p, n, Vector2(0.5 + (p.z - center.z) * 1.5, 0.5 - (p.y - center.y) * 1.5)))
	for k in count - 1:
		b.add_tri(c, idx[k + 1], idx[k])
	b.add_tri(g, c, idx[0])
	b.add_tri(g, idx[count - 1], c)


static func _add_wing(w: MeshBuilder, piv: Vector3, sx: float, length: float, width: float) -> void:
	var dir := Vector3(sx * 0.32, 0.04, 1.0).normalized()
	var side := Vector3(sx, 0, -0.3 * sx).normalized()
	var count := 10
	var c := w.add_vertex(piv, Vector3.UP, Vector2(0, 0.5))
	var idx: Array[int] = []
	for k in count + 1:
		var t := float(k) / count
		var a := t * PI
		var along := (1.0 - cos(a)) * 0.5 * length
		var across := sin(a) * width * (1.0 - t * 0.25)
		idx.append(w.add_vertex(piv + dir * along + side * across, Vector3.UP, Vector2(t, 1.0)))
	for k in count:
		w.add_tri(c, idx[k + 1], idx[k])


## Junta `count` cópias da malha numa só (um grupo de formigas): CUSTOM1.w de
## cada vértice diz qual formiga do grupo ele é, e o shader põe cada uma no seu
## lugar, com tamanho, rumo e passo próprios.
static func squad(src: ArrayMesh, count: int) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var arrays := src.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n := verts.size()
		var res := []
		res.resize(Mesh.ARRAY_MAX)
		for a in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2,
				Mesh.ARRAY_CUSTOM0]:
			var data = arrays[a]
			if data == null:
				continue
			var rep = data.duplicate()
			for k in count - 1:
				rep.append_array(data)
			res[a] = rep
		var c1: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
		var c1r := PackedFloat32Array()
		c1r.resize(c1.size() * count)
		for k in count:
			var o := k * c1.size()
			for i in n:
				c1r[o + i * 4] = c1[i * 4]
				c1r[o + i * 4 + 1] = c1[i * 4 + 1]
				c1r[o + i * 4 + 2] = c1[i * 4 + 2]
				c1r[o + i * 4 + 3] = float(k)
		res[Mesh.ARRAY_CUSTOM1] = c1r
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var idr := PackedInt32Array()
		idr.resize(idx.size() * count)
		for k in count:
			var o := k * idx.size()
			for i in idx.size():
				idr[o + i] = idx[i] + k * n
		res[Mesh.ARRAY_INDEX] = idr
		var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
			| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(si))
	return out


# --------------------------------------------------------- Modelos de IA

## Converte um modelo .glb de formiga para o formato animável (classificando
## automaticamente pernas e antenas pela posição dos vértices).
static func _from_model(kind: String) -> ArrayMesh:
	var model_name: String = KIND_MODEL.get(kind, "")
	if model_name.is_empty() or not ModelLibrary.has_model(model_name):
		return null
	var info := ModelLibrary.load_mesh(model_name, 1.0)
	if info.is_empty():
		return null
	var src: Mesh = info.mesh
	var xf: Transform3D = info.transform
	var out := ArrayMesh.new()
	var albedo: Texture2D = null
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var count := verts.size()
		var c0 := PackedFloat32Array()
		var c1 := PackedFloat32Array()
		c0.resize(count * 4)
		c1.resize(count * 4)
		var src_mat := src.surface_get_material(s)
		var tint := Color.WHITE
		if src_mat is BaseMaterial3D:
			tint = (src_mat as BaseMaterial3D).albedo_color
		var colors := PackedColorArray()
		var src_colors = arrays[Mesh.ARRAY_COLOR]
		if src_colors is PackedColorArray and (src_colors as PackedColorArray).size() == count:
			colors = src_colors
			for i in count:
				colors[i] = colors[i] * tint
		else:
			colors.resize(count)
			colors.fill(tint)
		for i in count:
			var v := xf * verts[i]
			verts[i] = v
			if norms.size() == count:
				norms[i] = (xf.basis * norms[i]).normalized()
			var part := Part.BODY
			var pivot := Vector3.ZERO
			var side := signf(v.x) if absf(v.x) > 0.001 else 1.0
			var phase := 0.0
			if absf(v.x) > 0.1 and v.y < 0.3 and v.z > -0.45:
				part = Part.LEG
				var band := 0 if v.z < -0.09 else (1 if v.z < 0.0 else 2)
				pivot = Vector3(side * 0.06, 0.17, [-0.12, -0.05, 0.02][band])
				if (band == 1) == (side < 0.0):
					phase = PI
			elif v.z < -0.42 and v.y > 0.24 and absf(v.x) > 0.03:
				part = Part.ANTENNA
				pivot = Vector3(side * 0.05, 0.27, -0.37)
			c0[i * 4] = pivot.x
			c0[i * 4 + 1] = pivot.y
			c0[i * 4 + 2] = pivot.z
			c0[i * 4 + 3] = float(part)
			c1[i * 4] = 1.0
			c1[i * 4 + 1] = phase
			c1[i * 4 + 2] = side
		arrays[Mesh.ARRAY_VERTEX] = verts
		if norms.size() == count:
			arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TANGENT] = null
		arrays[Mesh.ARRAY_CUSTOM0] = c0
		arrays[Mesh.ARRAY_CUSTOM1] = c1
		var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
			| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		if src_mat is BaseMaterial3D and (src_mat as BaseMaterial3D).albedo_texture:
			albedo = (src_mat as BaseMaterial3D).albedo_texture
		var m := body_material.duplicate() as ShaderMaterial
		if albedo:
			m.set_shader_parameter("albedo_tex", albedo)
			m.set_shader_parameter("use_albedo_tex", 1.0)
		out.surface_set_material(out.get_surface_count() - 1, m)
	return out
