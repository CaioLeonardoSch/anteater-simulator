extends RefCounted
## O chão das formigas que passeiam: por onde elas sobem e o que contornam.
## - Pedras e troncos caídos: as formigas sobem e andam por cima (a altura de
##   cima de cada um vai no canal B, acima do chão).
## - Arbustos, árvores e cupinzeiros: as formigas dão a volta. O caminho que
##   passaria por dentro é empurrado para um anel em volta (o desvio vai nos
##   canais R e G); bem no meio (canal A), a formiga some embaixo das folhas.
## - Árvores em pé: perto do tronco, a formiga encosta nele e sobe (quanto mais
##   o caminho dela entraria no tronco, mais alto ela vai), até antes da
##   primeira forquilha, longe das folhas. Outra textura (trunk_texture) diz,
##   em volta de cada tronco, onde fica o pé dele e qual é; trunk_data guarda
##   os pontos de cada tronco.
## Uma textura cobre a clareira; a placa de vídeo (ant_field.gdshaderinc) e
## o jogo (sample, climb) leem a mesma coisa.

## Lado do quadrado coberto (m, centrado na origem) e texels por lado.
const SIZE := 64.0
const RES := 512
const CELL := SIZE / RES
## Folga em volta do que as formigas contornam (m).
const AROUND := 0.6
## Até este raio as formigas contornam; maior que isso (lagoas) nem chegam perto.
const MAX_BLOCK := 2.5
## Troncos: até onde (m, além da casca) o caminho é puxado para o tronco, de
## onde a formiga começa a subir e até que altura (m acima do pé) ela sobe.
const CLIMB_OUT := 2.5
const CLIMB_IN := 1.0
const CLIMB_MAX := 1.4
## Pontos de cada tronco (o tubo do tronco tem 7) + 1 texel de números.
const TRUNK_PTS := 7

var texture: ImageTexture
## RGBA de cada texel, em sequência (para o jogo ler sem a placa de vídeo).
var _data := PackedFloat32Array()
## Só a altura (canal B), para a conta rápida de extra_height.
var _h := PackedFloat32Array()
var trunk_texture: ImageTexture
var trunk_data: ImageTexture
## Tronco de cada texel (-1 = nenhum) e os troncos: {c, r, pts, radii, fmax}.
var _trunk_idx := PackedInt32Array()
var _trunks: Array[Dictionary] = []
var _world


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
	_world = world
	_build_trunks(veg.trees)


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


func _build_trunks(trees: Array) -> void:
	_trunk_idx.resize(RES * RES)
	_trunk_idx.fill(-1)
	var zone := PackedFloat32Array()
	zone.resize(RES * RES * 4)
	zone.fill(0.0)
	for tree in trees:
		var local: PackedVector3Array = tree.get_meta("trunk_pts", PackedVector3Array())
		var radii: PackedFloat32Array = tree.get_meta("trunk_radii", PackedFloat32Array())
		if local.size() != TRUNK_PTS or radii.size() != TRUNK_PTS:
			continue
		var xf := _world_xf(tree)
		var pts := PackedVector3Array()
		for q in local:
			pts.append(xf * q)
		var scale: float = xf.basis.get_scale().x
		var rr := PackedFloat32Array()
		for r in radii:
			rr.append(r * scale)
		var c := Vector2(pts[0].x, pts[0].z)
		var base: float = _world.ground_height(c.x, c.y)
		# Até onde sobe: CLIMB_MAX acima do pé, no máximo 70% do tronco.
		var fmax := (TRUNK_PTS - 1) * 0.7
		for k in TRUNK_PTS - 1:
			if pts[k + 1].y - base >= CLIMB_MAX:
				fmax = minf(fmax, k + clampf((base + CLIMB_MAX - pts[k].y) / maxf(pts[k + 1].y - pts[k].y, 0.01), 0.0, 1.0))
				break
		var idx := _trunks.size()
		_trunks.append({"c": c, "r": rr[0], "pts": pts, "radii": rr, "fmax": fmax})
		var reach: float = rr[0] + CLIMB_OUT + 2.0 * CELL
		var rx := _texel_range(c.x - reach, c.x + reach)
		var rz := _texel_range(c.y - reach, c.y + reach)
		for z in range(rz.x, rz.y + 1):
			for x in range(rx.x, rx.y + 1):
				var p := _texel_pos(x, z)
				if p.distance_to(c) > reach:
					continue
				var k := z * RES + x
				_trunk_idx[k] = idx
				zone[k * 4] = c.x - p.x
				zone[k * 4 + 1] = c.y - p.y
				zone[k * 4 + 2] = float(idx)
				zone[k * 4 + 3] = 1.0
	var img := Image.create(RES, RES, false, Image.FORMAT_RGBAF)
	for y in RES:
		for x in RES:
			var k := (y * RES + x) * 4
			if zone[k + 3] > 0.0:
				img.set_pixel(x, y, Color(zone[k], zone[k + 1], zone[k + 2], zone[k + 3]))
	trunk_texture = ImageTexture.create_from_image(img)
	var data := Image.create(TRUNK_PTS + 1, maxi(_trunks.size(), 1), false, Image.FORMAT_RGBAF)
	for i in _trunks.size():
		var t: Dictionary = _trunks[i]
		for k in TRUNK_PTS:
			var q: Vector3 = t.pts[k]
			data.set_pixel(k, i, Color(q.x, q.y, q.z, t.radii[k]))
		data.set_pixel(TRUNK_PTS, i, Color(t.fmax, t.r, CLIMB_OUT, CLIMB_IN))
	trunk_data = ImageTexture.create_from_image(data)


## Perto de um tronco: Vector4(x, y, z, 1) onde a formiga fica (no chão,
## chegando, ou no tronco, subindo); Vector4(.., 2) escondida (atravessando o
## meio, lá em cima); Vector4(.., 0) longe de troncos.
func climb(raw: Vector2) -> Vector4:
	var x := int((raw.x + SIZE * 0.5) / CELL)
	var z := int((raw.y + SIZE * 0.5) / CELL)
	if x < 0 or z < 0 or x >= RES or z >= RES:
		return Vector4.ZERO
	var idx := _trunk_idx[z * RES + x]
	if idx < 0:
		return Vector4.ZERO
	var t: Dictionary = _trunks[idx]
	var c: Vector2 = t.c
	var r: float = t.r
	var off := raw - c
	var d := off.length()
	var outer := r + CLIMB_OUT
	var inner := r + CLIMB_IN
	if d >= outer:
		return Vector4.ZERO
	if d < 0.05:
		return Vector4(raw.x, 0.0, raw.y, 2.0)
	var n := off / d
	if d >= inner:
		# Chegando: o caminho encolhe até encostar no tronco.
		var q := c + n * (r + (d - inner) / (outer - inner) * (outer - r))
		return Vector4(q.x, _world.ground_height(q.x, q.y) + extra_height(q), q.y, 1.0)
	# Subindo: quanto mais para dentro, mais alto.
	var f: float = (1.0 - (d / inner) * (d / inner)) * float(t.fmax)
	var k := mini(int(f), TRUNK_PTS - 2)
	var u := f - k
	var a: Vector3 = t.pts[k].lerp(t.pts[k + 1], u)
	var ra: float = lerpf(t.radii[k], t.radii[k + 1], u)
	var p := Vector3(a.x + n.x * ra, a.y, a.z + n.y * ra)
	p.y = maxf(p.y, _world.ground_height(p.x, p.z))
	return Vector4(p.x, p.y, p.z, 1.0)
