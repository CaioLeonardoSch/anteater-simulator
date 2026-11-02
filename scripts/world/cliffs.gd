extends Node3D
## Penhascos de arenito em volta da clareira: são o limite do mapa. Têm uma
## caverna na base (onde o tamanduá acorda) e uma passagem para a área 2, que
## um tronco caído fecha até a clareira ficar 100% limpa. O topo é um platô
## onde crescem árvores.

const MeshBuilder := preload("res://scripts/procedural/mesh_builder.gd")

const SEGMENTS := 432
const BASE_RADIUS := 64.0
## Pontos do perfil do paredão (de baixo para o platô).
const PROFILE := 12
## Caverna: ângulo no anel (radianos, ~12°, a leste), meia-largura, fundo e altura.
const CAVE_ANGLE := 0.2094
const CAVE_HALF := 0.08
const CAVE_DEPTH := 7.5
const CAVE_HEIGHT := 3.4
## Passagem para a área 2 (~162°, oeste-sudoeste), na direção do cupinzeiro gigante.
const EXIT_ANGLE := 2.8274
const EXIT_HALF := 0.056
const CANYON_LENGTH := 15.0
## Quanto o platô do topo avança para fora.
const PLATEAU := 24.0

var terrain
var _r := PackedFloat32Array()
var _h := PackedFloat32Array()
var _base := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _rock_noise := FastNoiseLite.new()


## Primeira etapa (antes de o terreno ser montado): forma do anel e chão plano
## dentro da caverna e na passagem.
func plan(t) -> void:
	terrain = t
	_noise.seed = 4242
	_noise.frequency = 1.0
	_rock_noise.seed = 99
	_rock_noise.frequency = 0.35
	_r.resize(SEGMENTS)
	_h.resize(SEGMENTS)
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var p := Vector2(cos(a), sin(a))
		var big := _noise.get_noise_2d(p.x * 2.2, p.y * 2.2)
		var fine := _noise.get_noise_2d(p.x * 9.0 + 50.0, p.y * 9.0)
		_r[i] = BASE_RADIUS + big * 2.2 + fine * 0.6
		# Mais baixos do lado da passagem, para o cupinzeiro gigante aparecer por cima.
		var toward_exit := smoothstep(0.2, 1.0, cos(a - EXIT_ANGLE))
		_h[i] = lerpf(15.5, 10.0, toward_exit) + _noise.get_noise_2d(p.x * 4.0 + 20.0, p.y * 4.0) * 2.0
	# Chão da caverna na altura da boca dela.
	var cave_dir := Vector2(cos(CAVE_ANGLE), sin(CAVE_ANGLE))
	var r_cave := radius_at(CAVE_ANGLE)
	var mouth := cave_dir * (r_cave - 2.0)
	var floor_y: float = terrain.natural_height(mouth.x, mouth.y)
	for k in 4:
		var c := cave_dir * (r_cave - 1.0 + k * 2.6)
		terrain.add_flat_zone(c.x, c.y, 6.5, floor_y)
	# Chão da passagem: plano no começo e subindo devagar depois.
	var exit_dir := Vector2(cos(EXIT_ANGLE), sin(EXIT_ANGLE))
	var r_exit := radius_at(EXIT_ANGLE)
	var inside := exit_dir * (r_exit - 4.0)
	var exit_y: float = terrain.natural_height(inside.x, inside.y)
	for k in 3:
		var c := exit_dir * (r_exit - 1.0 + k * 4.5)
		terrain.add_flat_zone(c.x, c.y, 6.0, exit_y + k * 0.35)


func _index(angle: float) -> float:
	return fposmod(angle, TAU) / TAU * SEGMENTS


## Raio da base do paredão nesse ângulo.
func radius_at(angle: float) -> float:
	var f := _index(angle)
	var i := int(f)
	return lerpf(_r[i % SEGMENTS], _r[(i + 1) % SEGMENTS], f - i)


func height_at(angle: float) -> float:
	var f := _index(angle)
	var i := int(f)
	return lerpf(_h[i % SEGMENTS], _h[(i + 1) % SEGMENTS], f - i)


## Altura do platô (topo do paredão) nesse ângulo. Só depois de build().
func top_y(angle: float) -> float:
	var f := _index(angle)
	var i := int(f)
	var b := lerpf(_base[i % SEGMENTS], _base[(i + 1) % SEGMENTS], f - i)
	return b + height_at(angle)


## Quanto a caverna entra no paredão nesse ângulo (0 fora dela).
func cave_depth(angle: float) -> float:
	var x := angle_difference(CAVE_ANGLE, angle) / CAVE_HALF
	if absf(x) >= 1.0:
		return 0.0
	return CAVE_DEPTH * pow(cos(x * PI * 0.5), 1.5)


func in_exit(angle: float) -> bool:
	return absf(angle_difference(EXIT_ANGLE, angle)) < EXIT_HALF


## Até onde dá para andar nessa direção (antes do paredão, da caverna ou do tronco).
func walk_limit(p2: Vector2, exit_open: bool) -> float:
	var a := atan2(p2.y, p2.x)
	if in_exit(a):
		return radius_at(EXIT_ANGLE) + (CANYON_LENGTH - 3.0 if exit_open else 0.6)
	return radius_at(a) + cave_depth(a) - 0.7


## Onde o tamanduá acorda: no fundo da caverna.
func cave_spot() -> Vector2:
	return Vector2(cos(CAVE_ANGLE), sin(CAVE_ANGLE)) * (radius_at(CAVE_ANGLE) + CAVE_DEPTH * 0.55)


func cave_mouth() -> Vector2:
	return Vector2(cos(CAVE_ANGLE), sin(CAVE_ANGLE)) * radius_at(CAVE_ANGLE)


## Centro da entrada da passagem para a área 2 e a direção dela.
func exit_center(offset: float = 1.6) -> Vector2:
	return Vector2(cos(EXIT_ANGLE), sin(EXIT_ANGLE)) * (radius_at(EXIT_ANGLE) + offset)


func exit_width() -> float:
	return 2.0 * radius_at(EXIT_ANGLE) * sin(EXIT_HALF)


# ------------------------------------------------------------------ Malha

## Segunda etapa (com o terreno pronto): monta o paredão, a passagem e a colisão.
func build(mats) -> void:
	_base.resize(SEGMENTS)
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var r := _r[i] + cave_depth(a)
		_base[i] = terrain.get_height(cos(a) * r, sin(a) * r)
	var b := MeshBuilder.new()
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var dir := Vector2(cos(a), sin(a))
		var prof := _profile(i, a)
		for k in PROFILE:
			var r: float = prof[k].x
			var y: float = prof[k].y
			if k >= 1 and k <= 9:
				r += _rock_noise.get_noise_3d(dir.x * r, y * 1.4, dir.y * r) * 0.55
			b.color = _strata_color(y - _base[i], k, a)
			b.add_vertex(Vector3(dir.x * r, y, dir.y * r), Vector3.UP)
	for i in SEGMENTS:
		var j := (i + 1) % SEGMENTS
		if in_exit(TAU * (i + 0.5) / SEGMENTS):
			continue
		for k in PROFILE - 1:
			b.add_quad(i * PROFILE + k, j * PROFILE + k, j * PROFILE + k + 1, i * PROFILE + k + 1)
	_canyon_wall(b, -1.0)
	_canyon_wall(b, 1.0)
	b.recompute_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Paredao"
	mi.mesh = b.commit(null, mats.cliff)
	add_child(mi)
	var faces := PackedVector3Array()
	for n in b.indices.size():
		faces.append(b.verts[b.indices[n]])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var col := CollisionShape3D.new()
	col.shape = shape
	var body := StaticBody3D.new()
	body.name = "ParedaoColisao"
	body.add_child(col)
	add_child(body)


## Perfil do paredão nesse ângulo, em (raio, altura): base, caverna, faixas de
## arenito, beirada e platô.
func _profile(i: int, a: float) -> Array[Vector2]:
	var r0 := _r[i]
	var d := cave_depth(a)
	var ck := d / CAVE_DEPTH
	var base := _base[i]
	var top := base + _h[i]
	var pts: Array[Vector2] = []
	pts.append(Vector2(r0 + d, base - 1.5))
	pts.append(Vector2(r0 + d, base + lerpf(1.0, CAVE_HEIGHT, ck)))
	var lip_y := base + lerpf(2.2, CAVE_HEIGHT + 0.45, ck)
	pts.append(Vector2(r0 + lerpf(0.25, 0.15, ck), lip_y))
	for k in 6:
		var t := float(k + 1) / 7.0
		var ledge := 0.32 if k % 2 == 0 else -0.18
		pts.append(Vector2(r0 + ledge, lerpf(lip_y, top, t)))
	pts.append(Vector2(r0 + 0.6, top + 0.25))
	pts.append(Vector2(r0 + 5.0, top + 0.7))
	pts.append(Vector2(r0 + PLATEAU, top + 0.3))
	return pts


## Faixas do arenito (creme e vermelho), mais escuro e úmido no pé do paredão.
func _strata_color(h: float, k: int, a: float) -> Color:
	if k >= 10:
		return Color(0.95, 0.95, 0.88)
	var band := smoothstep(-0.3, 0.3, sin(h * 0.85 + _noise.get_noise_2d(a * 30.0, h * 0.5) * 1.5))
	var c := Color(1.08, 1.02, 0.94).lerp(Color(0.76, 0.5, 0.4), band)
	var foot := lerpf(0.62, 1.0, smoothstep(0.0, 1.6, h))
	return Color(c.r * foot, c.g * foot, c.b * foot)


## Parede de um dos lados da passagem (side -1 = esquerda, 1 = direita, olhando
## de dentro da clareira), virada para dentro da passagem.
func _canyon_wall(b: MeshBuilder, side: float) -> void:
	var e := Vector2(cos(EXIT_ANGLE), sin(EXIT_ANGLE))
	var lateral := Vector2(-e.y, e.x)
	var r0 := radius_at(EXIT_ANGLE)
	var half := exit_width() * 0.5
	var top_level: float = terrain.get_height(e.x * (r0 - 3.0), e.y * (r0 - 3.0)) + height_at(EXIT_ANGLE)
	var steps_s := 10
	var steps_y := 8
	var start := b.vertex_count()
	for si in steps_s + 1:
		var s := lerpf(-1.5, CANYON_LENGTH, float(si) / steps_s)
		for yi in steps_y + 1:
			var t := float(yi) / steps_y
			var center := e * (r0 + s)
			var ground: float = terrain.get_height(center.x, center.y)
			var y := lerpf(ground - 1.5, top_level, t)
			var wobble := _rock_noise.get_noise_3d(center.x, y * 1.4, center.y) * 0.5
			var off := side * (half + wobble + 0.25 * sin(s * 0.7))
			var p := center + lateral * off
			b.color = _strata_color(y - ground, 3 + yi % 6, EXIT_ANGLE + s * 0.01)
			b.add_vertex(Vector3(p.x, y, p.y), Vector3.UP)
	for si in steps_s:
		for yi in steps_y:
			var a := start + si * (steps_y + 1) + yi
			var bb := start + (si + 1) * (steps_y + 1) + yi
			if side < 0.0:
				b.add_quad(a, bb, bb + 1, a + 1)
			else:
				b.add_quad(a, a + 1, bb + 1, bb)
