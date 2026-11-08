extends RefCounted
## O chão das formigas que passeiam: por onde elas sobem e o que contornam.
## - Pedras e troncos caídos: as formigas sobem e andam por cima (a altura de
##   cima de cada um vai no canal B, acima do chão).
## - Arbustos, árvores e cupinzeiros: as formigas dão a volta. O caminho que
##   passaria por dentro é empurrado para um anel em volta (o desvio vai nos
##   canais R e G); bem no meio (canal A), a formiga some embaixo das folhas.
## Uma textura cobre a clareira; a placa de vídeo (ant_field.gdshaderinc) e
## o jogo (sample) leem a mesma coisa.

## Lado do quadrado coberto (m, centrado na origem) e texels por lado.
const SIZE := 64.0
const RES := 512
const CELL := SIZE / RES
## Folga em volta do que as formigas contornam (m).
const AROUND := 0.6
## Até este raio as formigas contornam; maior que isso (lagoas) nem chegam perto.
const MAX_BLOCK := 2.5

var texture: ImageTexture
## RGBA de cada texel, em sequência (para o jogo ler sem a placa de vídeo).
var _data := PackedFloat32Array()
## Só a altura (canal B), para a conta rápida de extra_height.
var _h := PackedFloat32Array()


func build(world) -> void:
	_data.resize(RES * RES * 4)
	_data.fill(0.0)
	var top := PackedFloat32Array()
	top.resize(RES * RES)
	top.fill(-INF)
	var veg = world.vegetation
	for rock in veg.rocks:
		_raster_mesh(rock, top)
	for log_node in veg.logs:
		if log_node.has_meta("tube_pts"):
			_raster_tube(log_node, top)
		else:
			_raster_mesh(log_node, top)
	for k in RES * RES:
		if top[k] == -INF:
			continue
		var p := _texel_pos(k % RES, k / RES)
		_data[k * 4 + 2] = maxf(top[k] - world.ground_height(p.x, p.y), 0.0)
	_h.resize(RES * RES)
	for k in RES * RES:
		_h[k] = _data[k * 4 + 2]
	for b in veg.blockers:
		if b.z <= MAX_BLOCK:
			_add_block(Vector2(b.x, b.y), b.z)
	var img := Image.create(RES, RES, false, Image.FORMAT_RGBAH)
	for y in RES:
		for x in RES:
			var k := (y * RES + x) * 4
			img.set_pixel(x, y, Color(_data[k], _data[k + 1], _data[k + 2], _data[k + 3]))
	texture = ImageTexture.create_from_image(img)


## (desvio x, desvio z, altura acima do chão, escondida 0..1) num ponto do chão.
func sample(p: Vector2) -> Vector4:
	var fx := (p.x + SIZE * 0.5) / CELL - 0.5
	var fz := (p.y + SIZE * 0.5) / CELL - 0.5
	if fx < 0.0 or fz < 0.0 or fx >= RES - 1 or fz >= RES - 1:
		return Vector4.ZERO
	var x := int(fx)
	var z := int(fz)
	var tx := fx - x
	var tz := fz - z
	var a := _at(x, z)
	var b := _at(x + 1, z)
	var c := _at(x, z + 1)
	var d := _at(x + 1, z + 1)
	return a.lerp(b, tx).lerp(c.lerp(d, tx), tz)


## Onde a formiga fica de verdade (com o desvio) e se está escondida embaixo
## das folhas (Vector2.INF).
func warp(p: Vector2) -> Vector2:
	var s := sample(p)
	if s.w > 0.5:
		return Vector2.INF
	return p + Vector2(s.x, s.y)


## Altura de cima das pedras e troncos acima do chão.
func extra_height(p: Vector2) -> float:
	var fx := (p.x + SIZE * 0.5) / CELL - 0.5
	var fz := (p.y + SIZE * 0.5) / CELL - 0.5
	if fx < 0.0 or fz < 0.0 or fx >= RES - 1 or fz >= RES - 1:
		return 0.0
	var x := int(fx)
	var z := int(fz)
	var k := z * RES + x
	var a := _h[k]
	var b := _h[k + 1]
	var c := _h[k + RES]
	var d := _h[k + RES + 1]
	if a == 0.0 and b == 0.0 and c == 0.0 and d == 0.0:
		return 0.0
	var tx := fx - x
	var tz := fz - z
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func _at(x: int, z: int) -> Vector4:
	var k := (z * RES + x) * 4
	return Vector4(_data[k], _data[k + 1], _data[k + 2], _data[k + 3])


func _texel_pos(x: int, z: int) -> Vector2:
	return Vector2((x + 0.5) * CELL - SIZE * 0.5, (z + 0.5) * CELL - SIZE * 0.5)


func _texel_range(lo: float, hi: float) -> Vector2i:
	return Vector2i(clampi(int(floor((lo + SIZE * 0.5) / CELL - 0.5)), 0, RES - 1),
		clampi(int(ceil((hi + SIZE * 0.5) / CELL - 0.5)), 0, RES - 1))


static func _world_xf(node: Node3D) -> Transform3D:
	if node.is_inside_tree():
		return node.global_transform
	var xf := node.transform
	var p := node.get_parent()
	while p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## A face de cima da malha: para cada texel, a maior altura dos triângulos.
func _raster_mesh(node: Node3D, top: PackedFloat32Array) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		var xf := _world_xf(mi)
		var f := mesh.get_faces()
		for t in range(0, f.size(), 3):
			var a: Vector3 = xf * f[t]
			var b: Vector3 = xf * f[t + 1]
			var c: Vector3 = xf * f[t + 2]
			var rx := _texel_range(minf(a.x, minf(b.x, c.x)), maxf(a.x, maxf(b.x, c.x)))
			var rz := _texel_range(minf(a.z, minf(b.z, c.z)), maxf(a.z, maxf(b.z, c.z)))
			var den := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
			if absf(den) < 1e-9:
				continue
			for z in range(rz.x, rz.y + 1):
				for x in range(rx.x, rx.y + 1):
					var p := _texel_pos(x, z)
					var w1 := ((b.z - c.z) * (p.x - c.x) + (c.x - b.x) * (p.y - c.z)) / den
					var w2 := ((c.z - a.z) * (p.x - c.x) + (a.x - c.x) * (p.y - c.z)) / den
					var w3 := 1.0 - w1 - w2
					if w1 < -0.001 or w2 < -0.001 or w3 < -0.001:
						continue
					var y := a.y * w1 + b.y * w2 + c.y * w3
					var k := z * RES + x
					if y > top[k]:
						top[k] = y


## Tronco caído: um tubo (pontos e raios guardados pelo Props.build_log). Fica
## de fora o galho quebrado, que aponta para cima.
func _raster_tube(node: Node3D, top: PackedFloat32Array) -> void:
	var xf := _world_xf(node)
	var pts: PackedVector3Array = node.get_meta("tube_pts")
	var radii: PackedFloat32Array = node.get_meta("tube_radii")
	var w := PackedVector3Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var rmax := 0.0
	for p in pts:
		var q: Vector3 = xf * p
		w.append(q)
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.z))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.z))
	for r in radii:
		rmax = maxf(rmax, r)
	var rx := _texel_range(lo.x - rmax, hi.x + rmax)
	var rz := _texel_range(lo.y - rmax, hi.y + rmax)
	for z in range(rz.x, rz.y + 1):
		for x in range(rx.x, rx.y + 1):
			var p := _texel_pos(x, z)
			for s in w.size() - 1:
				var a := Vector2(w[s].x, w[s].z)
				var b := Vector2(w[s + 1].x, w[s + 1].z)
				var ab := b - a
				var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
				var d := p.distance_to(a + ab * t)
				var r := lerpf(radii[s], radii[s + 1], t)
				if d >= r:
					continue
				var y := lerpf(w[s].y, w[s + 1].y, t) + sqrt(r * r - d * d)
				var k := z * RES + x
				if y > top[k]:
					top[k] = y


## Contorno: o disco de raio r + AROUND vira o anel de r até r + AROUND (quem
## ia passar por dentro passa rente, por fora). No miolo, a formiga some.
func _add_block(c: Vector2, r: float) -> void:
	var outer := r + AROUND
	var rx := _texel_range(c.x - outer, c.x + outer)
	var rz := _texel_range(c.y - outer, c.y + outer)
	for z in range(rz.x, rz.y + 1):
		for x in range(rx.x, rx.y + 1):
			var k := (z * RES + x) * 4
			var p := _texel_pos(x, z) + Vector2(_data[k], _data[k + 1])
			var off := p - c
			var d := off.length()
			if d >= outer:
				continue
			var n := off / d if d > 0.0001 else Vector2.RIGHT
			var moved := c + n * (r + AROUND * d / outer)
			_data[k] += moved.x - p.x
			_data[k + 1] += moved.y - p.y
			if d < outer * 0.3:
				_data[k + 3] = 1.0
