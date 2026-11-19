extends RefCounted
## Gera as malhas das formigas (saúvas): operária com folha, rainha de abdômen
## enorme e tanajura alada. Cada vértice carrega dados de animação (CUSTOM0/CUSTOM1) que o
## shader usa para mexer pernas, antenas, mandíbulas e asas.
## Unidade: a formiga tem ~1 de comprimento, olha para -Z e pisa em y = 0.
## As operárias andam em grupos de 10: `squad()` junta 10 cópias numa malha só
## (CUSTOM1.w = qual delas) e o shader espalha cada uma no seu lugar.
## LOD: 0 = detalhada (perto), 1 = simples, 2 = bem simples, 3 = mínima, 4 = só um
## fuso e a folha (bem longe); -1 = ainda mais redonda (a foto da coleção).
## Fantasias das formigas colecionáveis (`costume`): operária sem folha, com a
## fantasia nas partes 7 (presa ao corpo) e 8 (solta, balança com o passo).

const MeshBuilder := preload("res://scripts/procedural/mesh_builder.gd")
const ModelLibrary := preload("res://scripts/model_library.gd")
const ANT_SHADER := preload("res://shaders/ant.gdshader")
const WING_SHADER := preload("res://shaders/ant_wing.gdshader")

enum Part { BODY, LEG, ANTENNA, LEAF, WING, MANDIBLE, HAT, COSTUME, COSTUME_SWAY }

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


## Retorna a malha da formiga. Se houver um modelo de IA (assets/models), usa-o
## (menos para as fantasias, que são feitas aqui).
static func build(kind: String, lod: int = 0, costume: String = "") -> ArrayMesh:
	materials()
	if costume.is_empty():
		var ai := _from_model(kind)
		if ai:
			return ai
	var b := MeshBuilder.new()
	b.use_custom0 = true
	b.use_custom1 = true
	var photo := lod < 0
	lod = maxi(lod, 0)
	var tiny := lod >= 2
	var rings: int = 16 if photo else [9, 5, 3][clampi(lod, 0, 2)]
	var segs: int = 24 if photo else [14, 7, 5][clampi(lod, 0, 2)]
	var leg_sides: int = 9 if photo else [6, 4, 3][clampi(lod, 0, 2)]
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
			c_gaster = Color(0.56, 0.27, 0.09)
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
		b.color = Color(0.82, 0.56, 0.2)
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
			b.add_ellipsoid(Vector3(sx * 0.115 * head_s, 0.255, -0.335 - (head_s - 1.0) * 0.08), Vector3(0.03, 0.032, 0.03) * clampf(head_s, 1.0, 1.2),
				6 if lod == 0 else 3, 10 if lod == 0 else 5)
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
			elif lod == 1:
				b.add_tube(PackedVector3Array([hip, knee, foot, tarsus]), PackedFloat32Array([0.024, 0.019, 0.012, 0.008]), leg_sides, false, true)
			else:
				var pts := PackedVector3Array([hip, hip.lerp(knee, 0.5), knee, knee.lerp(foot, 0.5), foot, tarsus])
				b.add_tube(pts, PackedFloat32Array([0.024, 0.022, 0.019, 0.015, 0.012, 0.008]), leg_sides, false, true)
	# --- Fantasia (colecionáveis): no lugar da folha.
	if not costume.is_empty():
		if costume == "noel":
			_add_hat(b, false)
		else:
			_add_costume(b, costume, rings, segs)
	# --- Folha carregada (operária)
	elif kind == "worker":
		_tag(b, Part.LEAF, Vector3(0, 0.17, head_front - 0.09))
		b.color = Color(0.36, 0.72, 0.18)
		_add_leaf(b, Vector3(0, 0.17, head_front - 0.09), 6 if tiny else 14)
		# O chapéu (uma formiga em 16 000) só nas malhas de perto: de longe nem se vê.
		if not tiny:
			_add_hat(b, lod > 0)
	_shade(b)
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


## Volume pintado na cor: casco mais claro em cima e escuro embaixo, e pernas e
## antenas escurecendo da junta até a ponta (a folha e o chapéu ficam como estão).
static func _shade(b: MeshBuilder) -> void:
	for i in b.verts.size():
		var part := int(b.custom0[i * 4 + 3] + 0.5)
		if part == Part.LEAF or part >= Part.HAT:
			continue
		var c := b.colors[i]
		var up := b.normals[i].y * 0.5 + 0.5
		var k := lerpf(0.45, 1.15, up * up)
		if part == Part.LEG or part == Part.ANTENNA:
			var piv := Vector3(b.custom0[i * 4], b.custom0[i * 4 + 1], b.custom0[i * 4 + 2])
			k *= lerpf(1.1, 0.4, clampf(b.verts[i].distance_to(piv) / 0.45, 0.0, 1.0))
		b.colors[i] = Color(c.r * k, c.g * k, c.b * k, c.a)


## Formiga mínima, para longe (4 a 6 pixels): dois fusos (abdômen e
## cabeça+tórax), uma plaquinha de perna de cada lado e a folha. ~30 triângulos.
static func _build_micro(b: MeshBuilder, kind: String, c_head: Color, c_meso: Color, c_gaster: Color, c_leg: Color,
		gaster_s: float, head_s: float) -> ArrayMesh:
	_tag(b, Part.BODY)
	var gz := 0.3 + (gaster_s - 1.0) * 0.16
	_spindle(b, Vector3(0, 0.2, gz + 0.2 * gaster_s), Vector3(0, 0.21, 0.08), Vector3(0, 0.21, gz),
		Vector2(0.15, 0.13) * gaster_s, 5, c_gaster, c_gaster, c_meso)
	_spindle(b, Vector3(0, 0.2, 0.06), Vector3(0, 0.23, -0.4 - (head_s - 1.0) * 0.14), Vector3(0, 0.22, -0.2),
		Vector2(0.13, 0.1) * head_s, 5, c_meso, c_meso, c_head)
	for sx in [-1.0, 1.0]:
		var hip := Vector3(sx * 0.06, 0.17, -0.05)
		_tag(b, Part.LEG, hip, PI if sx > 0.0 else 0.0, sx)
		b.color = c_leg
		_flat_quad(b, hip + Vector3(0, 0, -0.05), hip + Vector3(0, 0, 0.05),
			hip + Vector3(sx * 0.42, -0.16, 0.06), hip + Vector3(sx * 0.42, -0.16, -0.06))
	if kind == "worker":
		var grip := Vector3(0, 0.17, -0.49)
		_tag(b, Part.LEAF, grip)
		b.color = Color(0.36, 0.72, 0.18)
		_add_leaf(b, grip, 5)
	return b.commit(null, body_material)


## Bem longe (a formiga tem 1 a 3 pixels): um fuso de 4 lados para o corpo, uma
## plaquinha atravessada para as pernas e um losango para a folha (o ponto
## verde que mostra a fila de longe). 12 triângulos.
static func _build_nano(b: MeshBuilder, kind: String, c_head: Color, c_meso: Color, c_gaster: Color, c_leg: Color,
		gaster_s: float, head_s: float) -> ArrayMesh:
	_tag(b, Part.BODY)
	_spindle(b, Vector3(0, 0.2, 0.3 + (gaster_s - 1.0) * 0.16 + 0.2 * gaster_s), Vector3(0, 0.23, -0.4 - (head_s - 1.0) * 0.14),
		Vector3(0, 0.21, 0.08), Vector2(0.14 * gaster_s, 0.12 * gaster_s), 4, c_gaster, c_head, c_meso)
	# Pernas paradas (de longe não dá para ver o passo).
	b.color = c_leg
	_flat_quad(b, Vector3(-0.42, 0.03, -0.12), Vector3(-0.42, 0.03, 0.04),
		Vector3(0.42, 0.03, 0.04), Vector3(0.42, 0.03, -0.12))
	if kind == "worker":
		var grip := Vector3(0, 0.17, -0.49)
		_tag(b, Part.LEAF, grip)
		b.color = Color(0.36, 0.72, 0.18)
		var c := grip + Vector3(0, 0.26, 0.16)
		_flat_quad(b, grip, c + Vector3(0, 0, -0.25), c + Vector3(0, 0.26, 0), c + Vector3(0, 0, 0.25), Vector3.RIGHT)
	return b.commit(null, body_material)


## Fuso de `sides` lados entre duas pontas (`a` e `b`), mais largo em `mid`
## (raios x e y). Cores: ponta a, ponta b, meio.
static func _spindle(b: MeshBuilder, a: Vector3, z: Vector3, mid: Vector3, r: Vector2, sides: int,
		ca: Color, cz: Color, cm: Color) -> void:
	b.color = ca
	var ia := b.add_vertex(a, (a - mid).normalized())
	b.color = cz
	var iz := b.add_vertex(z, (z - mid).normalized())
	b.color = cm
	var ring: Array[int] = []
	for k in sides:
		var ang := TAU * k / sides + PI * 0.5
		var n := Vector3(cos(ang), sin(ang), 0.0)
		ring.append(b.add_vertex(mid + Vector3(n.x * r.x, n.y * r.y, 0.0), n))
	var front := 1.0 if z.z < a.z else -1.0
	for k in sides:
		var p := ring[k]
		var q := ring[(k + 1) % sides]
		if front > 0.0:
			b.add_tri(ia, p, q)
			b.add_tri(iz, q, p)
		else:
			b.add_tri(ia, q, p)
			b.add_tri(iz, p, q)


## Quadrado chato (o shader das formigas desenha os dois lados).
static func _flat_quad(b: MeshBuilder, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		n: Vector3 = Vector3.UP) -> void:
	var i0 := b.add_vertex(p0, n)
	var i1 := b.add_vertex(p1, n)
	var i2 := b.add_vertex(p2, n)
	var i3 := b.add_vertex(p3, n)
	b.add_quad(i0, i1, i2, i3)


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


# ------------------------------------------------------------------ Fantasias

## Fantasias das formigas colecionáveis (scripts/collectibles.gd). Cada peça
## leva a parte 7 (presa ao corpo) ou 8 (solta, balança com o passo) e o brilho
## no UV (ant_look.gdshaderinc). Na formiga: a cabeça fica perto de
## (0, 0.245, -0.27), o tórax em (0, 0.2, -0.07) e o abdômen em (0, 0.21, 0.3);
## ela olha para -Z.
static func _add_costume(b: MeshBuilder, costume: String, rings: int, segs: int) -> void:
	match costume:
		"abobora":
			_costume_pumpkin(b, rings, segs)
		"tamandua":
			_costume_anteater(b, rings, segs)
		"lincoln":
			_costume_lincoln(b, rings, segs)
		"banhista":
			_costume_swimmer(b, rings, segs)
		"folia":
			_costume_carnival(b, rings, segs)


## Máscara de abóbora de Halloween: gomos laranja em volta da cabeça, o cabinho
## e a cara recortada (olhos, nariz e boca acesos).
static func _costume_pumpkin(b: MeshBuilder, rings: int, segs: int) -> void:
	var c := Vector3(0, 0.245, -0.28)
	_tag(b, Part.COSTUME, c)
	var from := b.verts.size()
	var lobes := 8
	for k in lobes:
		var a := TAU * k / lobes
		var dir := Vector3(sin(a), 0.0, -cos(a))
		b.color = Color(0.95, 0.5, 0.09) if k % 2 == 0 else Color(0.88, 0.43, 0.07)
		b.add_ellipsoid(c + dir * 0.09, Vector3(0.085, 0.155, 0.1), rings, segs, Basis(Vector3.UP, -a))
	_gloss(b, from, 0.45)
	from = b.verts.size()
	b.color = Color(0.36, 0.44, 0.16)
	b.add_tube(PackedVector3Array([c + Vector3(0, 0.135, 0), c + Vector3(0.004, 0.18, -0.005), c + Vector3(0.022, 0.21, -0.02)]),
		PackedFloat32Array([0.026, 0.02, 0.013]), maxi(segs / 2, 6), false, true)
	_gloss(b, from, 0.1)
	# A cara recortada, colada na frente da abóbora.
	from = b.verts.size()
	b.color = Color(1.0, 0.8, 0.25)
	var env := Vector3(0.185, 0.15, 0.19)
	for sx in [-1.0, 1.0]:
		_front_tri(b, c, env, Vector2(sx * 0.105, 0.272), Vector2(sx * 0.035, 0.272), Vector2(sx * 0.07, 0.325))
	_front_tri(b, c, env, Vector2(-0.02, 0.232), Vector2(0.02, 0.232), Vector2(0.0, 0.258))
	var n := 9
	var top: Array[int] = []
	var bottom: Array[int] = []
	for i in n:
		var x := lerpf(-0.12, 0.12, float(i) / (n - 1))
		var q := x / 0.12
		var yt := 0.205 + 0.03 * q * q - (0.022 if i == 3 or i == 5 else 0.0)
		var yb := 0.165 + 0.07 * q * q
		top.append(b.add_vertex(_on_front(c, env, x, yt), Vector3.FORWARD))
		bottom.append(b.add_vertex(_on_front(c, env, x, yb), Vector3.FORWARD))
	for i in n - 1:
		b.add_quad(top[i], top[i + 1], bottom[i + 1], bottom[i])
	_gloss(b, from, 0.0)


## Máscara de tamanduá: a cabeça coberta de pelo, o focinho comprido, as
## orelhinhas e a faixa preta de bordas brancas do tamanduá-bandeira no tórax.
static func _costume_anteater(b: MeshBuilder, rings: int, segs: int) -> void:
	var head := Vector3(0, 0.25, -0.285)
	_tag(b, Part.COSTUME, head)
	var from := b.verts.size()
	# As cores do tamanduá do jogo: cabeça marrom-acinzentada, focinho escuro.
	var fur := Color(0.3, 0.26, 0.23)
	var dark := Color(0.16, 0.13, 0.11)
	b.color = fur
	b.add_ellipsoid(head, Vector3(0.17, 0.13, 0.155), rings, segs)
	b.color = dark
	b.add_tube(PackedVector3Array([Vector3(0, 0.235, -0.39), Vector3(0, 0.226, -0.5), Vector3(0, 0.208, -0.62),
		Vector3(0, 0.186, -0.73)]), PackedFloat32Array([0.078, 0.052, 0.034, 0.02]), maxi(segs / 2, 6), false, true)
	for sx in [-1.0, 1.0]:
		b.add_ellipsoid(Vector3(sx * 0.1, 0.365, -0.225), Vector3(0.034, 0.03, 0.016), 5, 8, Basis(Vector3.FORWARD, sx * 0.4))
	b.color = Color(0.06, 0.05, 0.04)
	b.add_ellipsoid(Vector3(0, 0.185, -0.738), Vector3(0.022, 0.019, 0.016), 5, 8)
	for sx in [-1.0, 1.0]:
		b.add_ellipsoid(Vector3(sx * 0.085, 0.3, -0.408), Vector3(0.017, 0.017, 0.012), 4, 6)
	_gloss(b, from, 0.0)
	from = b.verts.size()
	var th_c := Vector3(0, 0.2, -0.07)
	var th_r := Vector3(0.075, 0.075, 0.135)
	var th_b := Basis(Vector3.RIGHT, 0.18)
	b.color = Color(0.93, 0.91, 0.85)
	_band(b, th_c, th_r * 1.14, th_b, -0.46, -0.28, segs)
	b.color = Color(0.07, 0.06, 0.05)
	_band(b, th_c, th_r * 1.16, th_b, -0.28, 0.14, segs)
	b.color = Color(0.93, 0.91, 0.85)
	_band(b, th_c, th_r * 1.14, th_b, 0.14, 0.32, segs)
	_gloss(b, from, 0.0)


## Abraham Lincoln: cartola alta (um pouco para trás, balança com o passo) e a
## barba sem bigode, do queixo até as bochechas.
static func _costume_lincoln(b: MeshBuilder, rings: int, segs: int) -> void:
	var top := Vector3(0, 0.345, -0.27)
	_tag(b, Part.COSTUME_SWAY, top)
	var tilt := Basis(Vector3.RIGHT, -0.12)
	b.xform = Transform3D(tilt, top - tilt * top)
	var from := b.verts.size()
	b.color = Color(0.05, 0.045, 0.045)
	b.add_ellipsoid(top + Vector3(0, 0.006, 0), Vector3(0.138, 0.016, 0.132), maxi(rings / 2, 4), segs)
	b.add_tube(PackedVector3Array([top + Vector3(0, 0.01, 0), top + Vector3(0, 0.29, 0)]),
		PackedFloat32Array([0.074, 0.08]), segs, false, true)
	_gloss(b, from, 0.7)
	from = b.verts.size()
	b.color = Color(0.17, 0.16, 0.15)
	b.add_tube(PackedVector3Array([top + Vector3(0, 0.018, 0), top + Vector3(0, 0.065, 0)]),
		PackedFloat32Array([0.0795, 0.0805]), segs, false, false)
	_gloss(b, from, 0.25)
	b.xform = Transform3D.IDENTITY
	_tag(b, Part.COSTUME, Vector3(0, 0.2, -0.33))
	from = b.verts.size()
	b.color = Color(0.13, 0.09, 0.06)
	b.add_ellipsoid(Vector3(0, 0.18, -0.37), Vector3(0.142, 0.075, 0.09), rings, segs)
	b.add_ellipsoid(Vector3(0, 0.135, -0.425), Vector3(0.066, 0.058, 0.05), maxi(rings / 2, 4), segs, Basis.IDENTITY, -0.3)
	_gloss(b, from, 0.0)


## Roupa de banho: maiô listrado de vermelho e branco, touca amarela com
## florzinhas e óculos de natação.
static func _costume_swimmer(b: MeshBuilder, rings: int, segs: int) -> void:
	_tag(b, Part.COSTUME, Vector3(0, 0.2, 0.1))
	var from := b.verts.size()
	var red := Color(0.86, 0.15, 0.13)
	var white := Color(0.96, 0.94, 0.89)
	var g_c := Vector3(0, 0.21, 0.3)
	var g_r := Vector3(0.15, 0.13, 0.2) * 1.055
	var g_b := Basis(Vector3.RIGHT, -0.25)
	var stripes := 8
	for k in stripes:
		b.color = red if k % 2 == 0 else white
		_band(b, g_c, g_r, g_b, lerpf(-0.9, 0.78, float(k) / stripes), lerpf(-0.9, 0.78, float(k + 1) / stripes), segs)
	var th_c := Vector3(0, 0.2, -0.07)
	var th_r := Vector3(0.075, 0.075, 0.135) * 1.12
	var th_b := Basis(Vector3.RIGHT, 0.18)
	for k in 4:
		b.color = white if k % 2 == 0 else red
		_band(b, th_c, th_r, th_b, lerpf(-0.55, 0.75, float(k) / 4.0), lerpf(-0.55, 0.75, float(k + 1) / 4.0), segs)
	_gloss(b, from, 0.3)
	var cap := Vector3(0, 0.31, -0.255)
	var cap_r := Vector3(0.132, 0.07, 0.125)
	_tag(b, Part.COSTUME, cap)
	from = b.verts.size()
	b.color = Color(0.98, 0.84, 0.22)
	b.add_ellipsoid(cap, cap_r, rings, segs)
	b.color = Color(0.98, 0.45, 0.62)
	for u in [0.5, 2.6, 4.5]:
		var v := 0.62
		var p := cap + Vector3(sin(v) * cos(u) * cap_r.x, cos(v) * cap_r.y, sin(v) * sin(u) * cap_r.z)
		b.add_ellipsoid(p, Vector3.ONE * 0.022, 4, 6)
	_gloss(b, from, 0.55)
	from = b.verts.size()
	b.color = Color(0.45, 0.8, 0.96)
	for sx in [-1.0, 1.0]:
		b.add_ellipsoid(Vector3(sx * 0.058, 0.322, -0.378), Vector3(0.03, 0.024, 0.014), 5, 8)
	_gloss(b, from, 1.0)


## Roupa de carnaval: tiara dourada com uma pedra, um leque de penas coloridas
## (balança com o passo) e lantejoulas no abdômen.
static func _costume_carnival(b: MeshBuilder, rings: int, segs: int) -> void:
	var crown := Vector3(0, 0.3, -0.262)
	_tag(b, Part.COSTUME, crown)
	var from := b.verts.size()
	b.color = Color(0.97, 0.77, 0.22)
	var ring := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 17:
		var a := TAU * k / 16.0
		ring.append(crown + Vector3(sin(a) * 0.148, 0.0, -cos(a) * 0.108))
		radii.append(0.017)
	b.add_tube(ring, radii, 6, false, false)
	b.color = Color(0.2, 0.85, 0.95)
	b.add_ellipsoid(crown + Vector3(0, 0.012, -0.112), Vector3(0.026, 0.03, 0.014), 5, 8)
	_gloss(b, from, 1.0)
	var base := Vector3(0, 0.34, -0.21)
	_tag(b, Part.COSTUME_SWAY, base)
	from = b.verts.size()
	var colors := [Color(0.62, 0.2, 0.85), Color(0.2, 0.45, 0.95), Color(0.15, 0.78, 0.45), Color(1.0, 0.84, 0.15),
		Color(1.0, 0.5, 0.12), Color(0.95, 0.2, 0.55), Color(0.62, 0.2, 0.85)]
	for k in 7:
		var side := (float(k) - 3.0) / 3.0
		var dir := Vector3(side * 0.75, 1.0, 0.45).normalized()
		var x := (Vector3.RIGHT - dir * dir.dot(Vector3.RIGHT)).normalized()
		var feather := Basis(x, dir, x.cross(dir))
		b.color = colors[k]
		b.add_ellipsoid(base + dir * (0.2 - absf(side) * 0.03), Vector3(0.034, 0.2, 0.01), maxi(rings / 2, 5), maxi(segs / 2, 8), feather)
	_gloss(b, from, 0.2)
	var g_c := Vector3(0, 0.21, 0.3)
	var g_r := Vector3(0.15, 0.13, 0.2) * 1.05
	var g_b := Basis(Vector3.RIGHT, -0.25)
	_tag(b, Part.COSTUME, g_c)
	from = b.verts.size()
	var stripes := 6
	for k in stripes:
		b.color = Color(0.97, 0.77, 0.22) if k % 2 == 0 else Color(0.95, 0.22, 0.55)
		_band(b, g_c, g_r, g_b, lerpf(-0.85, 0.75, float(k) / stripes), lerpf(-0.85, 0.75, float(k + 1) / stripes), segs)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var beads := [Color(0.3, 0.9, 1.0), Color(1.0, 1.0, 0.95), Color(1.0, 0.85, 0.3)]
	for k in 14:
		var t := rng.randf_range(-0.7, 0.6)
		var a := rng.randf_range(0.15, PI - 0.15)
		var q := sqrt(1.0 - t * t)
		b.color = beads[k % beads.size()]
		b.add_ellipsoid(g_c + g_b * (Vector3(cos(a) * q, sin(a) * q, t) * g_r * 1.06), Vector3.ONE * 0.014, 3, 6)
	_gloss(b, from, 1.0)


## Faixa em volta de um elipsoide (o abdômen ou o tórax), de t0 a t1 ao longo
## do comprimento dele (-1 = frente, 1 = trás): as listras das fantasias.
static func _band(b: MeshBuilder, c: Vector3, r: Vector3, basis: Basis, t0: float, t1: float, segs: int) -> void:
	var steps := maxi(int(ceil((t1 - t0) / 0.12)), 1)
	var start := b.verts.size()
	for i in steps + 1:
		var t := lerpf(t0, t1, float(i) / steps)
		var q := sqrt(maxf(1.0 - t * t, 0.0))
		for j in segs + 1:
			var a := TAU * j / segs
			var local := Vector3(cos(a) * q, sin(a) * q, t)
			b.add_vertex(c + basis * (local * r), (basis * Vector3(local.x / r.x, local.y / r.y, local.z / r.z)).normalized())
	var row := segs + 1
	for i in steps:
		for j in segs:
			var a := start + i * row + j
			b.add_quad(a, a + 1, a + row + 1, a + row)


## Ponto (x, y) colado na frente de um elipsoide (centro c, raios r): a cara da
## abóbora acompanha a curva dela.
static func _on_front(c: Vector3, r: Vector3, x: float, y: float) -> Vector3:
	var k := 1.0 - pow(x / r.x, 2.0) - pow((y - c.y) / r.y, 2.0)
	return Vector3(x, y, c.z - r.z * sqrt(maxf(k, 0.0)) - 0.006)


static func _front_tri(b: MeshBuilder, c: Vector3, r: Vector3, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	var i0 := b.add_vertex(_on_front(c, r, p0.x, p0.y), Vector3.FORWARD)
	var i1 := b.add_vertex(_on_front(c, r, p1.x, p1.y), Vector3.FORWARD)
	var i2 := b.add_vertex(_on_front(c, r, p2.x, p2.y), Vector3.FORWARD)
	b.add_tri(i0, i1, i2)


## Brilho das peças da fantasia (0 = fosco, 1 = brilhante), guardado no UV.
static func _gloss(b: MeshBuilder, from: int, gloss: float) -> void:
	for i in range(from, b.uvs.size()):
		b.uvs[i] = Vector2(2.0 + gloss, 0.0)


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
	# UV = (ao longo da asa 0..1, para o lado 0..1): o shader desenha as nervuras.
	var c := w.add_vertex(piv, Vector3.UP, Vector2(0, 0))
	var idx: Array[int] = []
	for k in count + 1:
		var t := float(k) / count
		var a := t * PI
		var along := (1.0 - cos(a)) * 0.5 * length
		var across := sin(a) * width * (1.0 - t * 0.25)
		idx.append(w.add_vertex(piv + dir * along + side * across, Vector3.UP, Vector2(along / length, across / width)))
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
