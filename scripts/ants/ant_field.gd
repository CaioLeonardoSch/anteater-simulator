extends Node3D
## Formigas de campo: as que andam pelas trilhas (do formigueiro ao arbusto e
## de volta) e as que passeiam em volta das câmaras do campo (saem do buraco,
## dão uma volta e entram de novo). São milhares, então a placa de vídeo
## calcula onde cada uma está (shaders/ant_field.gdshaderinc); aqui ficam os
## números de cada uma e a mesma conta, para quando o jogo precisa saber
## (lamber, fugir, farejar, tremor).
##
## As formigas ficam em grupos ("chunks"): um por trilha e um por câmara do
## campo. Cada grupo tem 4 camadas de desenho (de perto a longe), e cada camada
## só desenha as formigas na sua faixa de distância.
## Quando uma formiga precisa de atenção (fugir, ficar tonta, ir para a língua),
## o enxame (ant_swarm.gd) a assume: aqui ela some até voltar para o lugar.

const AntMeshBuilder := preload("res://scripts/ants/ant_mesh_builder.gd")
const TrailNetwork := preload("res://scripts/world/trail_network.gd")
const FIELD_SHADER := preload("res://shaders/ant_field.gdshader")
const FIELD_SCENT_SHADER := preload("res://shaders/ant_field_scent.gdshader")

const TRAIL := 0
const ROAM := 1
## Faixas de distância de cada camada (malha detalhada perto, mínima longe).
const LOD_BANDS := [Vector2(0.0, 4.5), Vector2(4.5, 11.0), Vector2(11.0, 24.0), Vector2(24.0, 100000.0)]
const DRAW_DIST := 95.0
## Números por formiga no buffer da MultiMesh (12 da transformação, 4 da cor, 4 extras).
const STRIDE := 20
## Mapa de alturas do chão para as formigas que passeiam.
const HEIGHT_RES := 256
const HEIGHT_SIZE := 160.0
const WORKER_SIZE := 0.15
const TRAIL_SPEED := 0.7
const ROAM_SPEED := 0.5
## Chance de uma formiga aparecer de chapéu de Natal (0,00625%).
const HAT_CHANCE := 0.0000625
## Some no buraco (trilha: perto do olheiro; passeio: perto da câmara).
const TRAIL_HIDE_S := 0.2
const ROAM_HIDE_RHO := 0.15


class Chunk extends RefCounted:
	var kind := 0
	## Trilha: índice da trilha. Passeio: código da câmara (ninho * 16 + câmara).
	var index := 0
	var count := 0
	var alive := 0
	var buf := PackedFloat32Array()
	var mms: Array[MultiMesh] = []
	var mmis: Array[MultiMeshInstance3D] = []
	var center := Vector3.ZERO
	var radius := 1.0
	var dirty := false
	var trail
	var home := Vector2.ZERO
	var reach := 0.0
	## Para achar depressa as formigas da trilha perto de um ponto.
	var near := PackedByteArray()


var world
var chunks: Array[Chunk] = []
## Relógio das formigas (para quando o jogo pausa).
var time := 0.0
var cam := Vector3.ZERO
var trail_chunk := {}
var roam_chunk := {}
var _mats: Array[ShaderMaterial] = []
var _scent_mats: Array[ShaderMaterial] = []
var _meshes: Array[Mesh] = []
var _scent_on := false
var _glow := Color(1.0, 0.75, 0.3)


## Monta tudo. `trail_counts[k]` = formigas na trilha k; `roams` = lista de
## {code, home: Vector2, reach: float, count: int}.
func build(w, trail_counts: Array, roams: Array, rng: RandomNumberGenerator) -> void:
	world = w
	for lod in 4:
		_meshes.append(AntMeshBuilder.build("worker", lod))
	var trail_tex := _trail_texture()
	var height_tex := _height_texture()
	for kind in 2:
		var m := ShaderMaterial.new()
		m.shader = FIELD_SHADER
		var s := ShaderMaterial.new()
		s.shader = FIELD_SCENT_SHADER
		for mat in [m, s]:
			mat.set_shader_parameter("field_kind", kind)
			mat.set_shader_parameter("trail_tex", trail_tex)
			mat.set_shader_parameter("height_tex", height_tex)
			mat.set_shader_parameter("height_size", HEIGHT_SIZE)
			mat.set_shader_parameter("trail_step", TrailNetwork.STEP)
		_mats.append(m)
		_scent_mats.append(s)
	var trails: Array = world.trails.trails
	for ti in trails.size():
		var n: int = trail_counts[ti] if ti < trail_counts.size() else 0
		if n <= 0:
			continue
		trail_chunk[ti] = chunks.size()
		_add_trail_chunk(ti, trails[ti], n, rng)
	for r in roams:
		if int(r.count) <= 0:
			continue
		roam_chunk[int(r.code)] = chunks.size()
		_add_roam_chunk(int(r.code), r.home, float(r.reach), int(r.count), rng)


## O chão mudou (um monte virou buraco): refaz as alturas que a placa de
## vídeo usa (as trilhas já foram recalculadas).
func refresh_ground() -> void:
	var trail_tex := _trail_texture()
	var height_tex := _height_texture()
	for mat in _mats + _scent_mats:
		mat.set_shader_parameter("trail_tex", trail_tex)
		mat.set_shader_parameter("height_tex", height_tex)


func _trail_texture() -> ImageTexture:
	var trails: Array = world.trails.trails
	var width := 2
	for t in trails:
		width = maxi(width, t.points.size())
	var img := Image.create(width, maxi(trails.size(), 1), false, Image.FORMAT_RGBAF)
	for ti in trails.size():
		var t = trails[ti]
		for i in width:
			var k := mini(i, t.points.size() - 1)
			img.set_pixel(i, ti, Color(t.points[k].x, t.points[k].y, t.heights[k], 0.0))
	return ImageTexture.create_from_image(img)


func _height_texture() -> ImageTexture:
	var img := Image.create(HEIGHT_RES, HEIGHT_RES, false, Image.FORMAT_RH)
	for y in HEIGHT_RES:
		for x in HEIGHT_RES:
			var wx := ((x + 0.5) / HEIGHT_RES - 0.5) * HEIGHT_SIZE
			var wz := ((y + 0.5) / HEIGHT_RES - 0.5) * HEIGHT_SIZE
			img.set_pixel(x, y, Color(world.ground_height(wx, wz), 0.0, 0.0))
	return ImageTexture.create_from_image(img)


func _new_chunk(kind: int, index: int, n: int) -> Chunk:
	var ch := Chunk.new()
	ch.kind = kind
	ch.index = index
	ch.count = n
	ch.alive = n
	ch.buf.resize(n * STRIDE)
	return ch


## Chance do chapéu (teste: --hats põe chapéu em uma a cada 20).
static func hat_chance() -> float:
	return 0.05 if DevTools.args.has("hats") else HAT_CHANCE


static func _flags(rng: RandomNumberGenerator, leaf_chance: float) -> float:
	var leaf := 1.0 if rng.randf() < leaf_chance else 0.0
	var hat := 2.0 if rng.randf() < hat_chance() else 0.0
	return leaf + hat


func _add_trail_chunk(ti: int, t, n: int, rng: RandomNumberGenerator) -> void:
	var ch := _new_chunk(TRAIL, ti, n)
	ch.trail = t
	var length: float = t.length
	for i in n:
		var o := i * STRIDE
		var speed := TRAIL_SPEED * rng.randf_range(0.85, 1.15)
		var tint := rng.randf_range(0.88, 1.12)
		ch.buf[o] = ti
		ch.buf[o + 1] = length
		ch.buf[o + 2] = rng.randf()
		ch.buf[o + 3] = speed / (2.0 * length)
		ch.buf[o + 4] = rng.randf_range(-0.22, 0.22)
		ch.buf[o + 5] = WORKER_SIZE * rng.randf_range(0.92, 1.08)
		ch.buf[o + 6] = float(rng.randi() % 1024)
		ch.buf[o + 7] = _flags(rng, 0.6)
		ch.buf[o + 8] = 1.0
		ch.buf[o + 9] = 0.0
		ch.buf[o + 10] = speed
		ch.buf[o + 11] = 0.0
		ch.buf[o + 12] = tint
		ch.buf[o + 13] = tint
		ch.buf[o + 14] = tint
		ch.buf[o + 15] = 1.0
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in t.points.size():
		var p := Vector3(t.points[i].x, t.heights[i], t.points[i].y)
		lo = lo.min(p)
		hi = hi.max(p)
	ch.near.resize(t.points.size())
	_finish_chunk(ch, AABB(lo, hi - lo).grow(0.6))


func _add_roam_chunk(code: int, home: Vector2, reach: float, n: int, rng: RandomNumberGenerator) -> void:
	var ch := _new_chunk(ROAM, code, n)
	ch.home = home
	ch.reach = reach
	for i in n:
		var o := i * STRIDE
		var r := reach * rng.randf_range(0.5, 1.0)
		var sweep := rng.randf_range(0.9, 2.2) * (1.0 if rng.randf() < 0.5 else -1.0)
		var path := r * (2.0 + 0.64 * absf(sweep))
		var period := path / (ROAM_SPEED * rng.randf_range(0.8, 1.2))
		var tint := rng.randf_range(0.88, 1.12)
		ch.buf[o] = home.x
		ch.buf[o + 1] = home.y
		ch.buf[o + 2] = r
		ch.buf[o + 3] = 1.0 / period
		ch.buf[o + 4] = rng.randf()
		ch.buf[o + 5] = WORKER_SIZE * rng.randf_range(0.92, 1.08)
		ch.buf[o + 6] = float(rng.randi() % 1024)
		ch.buf[o + 7] = _flags(rng, 0.35)
		ch.buf[o + 8] = 1.0
		ch.buf[o + 9] = 0.0
		ch.buf[o + 10] = rng.randf() * TAU
		ch.buf[o + 11] = sweep
		ch.buf[o + 12] = tint
		ch.buf[o + 13] = tint
		ch.buf[o + 14] = tint
		ch.buf[o + 15] = 1.0
	var y: float = world.ground_height(home.x, home.y)
	var ext := Vector3(reach + 0.6, 3.0, reach + 0.6)
	_finish_chunk(ch, AABB(Vector3(home.x, y, home.y) - ext, ext * 2.0))


func _finish_chunk(ch: Chunk, box: AABB) -> void:
	ch.center = box.get_center()
	ch.radius = box.size.length() * 0.5
	for lod in 4:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = _meshes[lod]
		mm.instance_count = ch.count
		mm.custom_aabb = box
		mm.buffer = ch.buf
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mats[ch.kind]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 0 \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.set_instance_shader_parameter("lod_band", LOD_BANDS[lod])
		mmi.set_instance_shader_parameter("glow_color", _glow)
		mmi.visible = false
		add_child(mmi)
		ch.mms.append(mm)
		ch.mmis.append(mmi)
	chunks.append(ch)


func _process(delta: float) -> void:
	time += delta
	for m in _mats:
		m.set_shader_parameter("ant_time", time)
		m.set_shader_parameter("ant_cam", cam)
	if _scent_on:
		for m in _scent_mats:
			m.set_shader_parameter("ant_time", time)
			m.set_shader_parameter("ant_cam", cam)
	for ch in chunks:
		if ch.dirty:
			ch.dirty = false
			for mm in ch.mms:
				mm.buffer = ch.buf
		var d := ch.center.distance_to(cam)
		var dmin := maxf(d - ch.radius, 0.0)
		var dmax := d + ch.radius
		var show := ch.alive > 0 and dmin < DRAW_DIST
		for lod in 4:
			var band: Vector2 = LOD_BANDS[lod]
			ch.mmis[lod].visible = show and band.x < dmax and band.y > dmin


# ------------------------------------------------------------------ A conta

## Onde está a formiga i do grupo agora: Vector4(x, y, z, rumo) ou, se ela
## está dentro do buraco (ou já foi comida), Vector4 com w = INF.
func ant_state(ch: Chunk, i: int, even_hidden: bool = false) -> Vector4:
	var o := i * STRIDE
	var b := ch.buf
	if b[o + 8] < 0.5 and not even_hidden:
		return Vector4(0, 0, 0, INF)
	var t := time
	var seed := b[o + 6]
	if ch.kind == TRAIL:
		var length := b[o + 1]
		var q := fposmod(b[o + 2] + t * b[o + 3], 1.0)
		var going := q < 0.5
		var s := (2.0 * q if going else 2.0 - 2.0 * q) * length
		if s < TRAIL_HIDE_S:
			return Vector4(0, 0, 0, INF)
		var tr = ch.trail
		var lat := b[o + 4] + 0.03 * sin(t * 1.3 + seed * 0.039)
		var p2: Vector2 = tr.point_at(s) + tr.side_at(s) * lat
		var fwd: Vector2 = tr.dir_at(s) * (1.0 if going else -1.0)
		var f := clampf(s / TrailNetwork.STEP, 0.0, tr.heights.size() - 1.001)
		var k := int(f)
		var y := lerpf(tr.heights[k], tr.heights[k + 1], f - k)
		return Vector4(p2.x, y, p2.y, atan2(-fwd.x, -fwd.y))
	var c := b[o + 4] + t * b[o + 3]
	var cyc := floorf(c)
	var u := c - cyc
	var reach := b[o + 2] * (0.75 + 0.25 * sin(cyc * 2.1 + seed * 0.013))
	var w := u * 12.566 + seed * 0.05
	var th := b[o + 10] + cyc * 2.39996 + (u - 0.5) * b[o + 11] + 0.22 * sin(w)
	var rho := reach * sin(PI * u)
	if rho < ROAM_HIDE_RHO:
		return Vector4(0, 0, 0, INF)
	var d := Vector2(cos(th), sin(th))
	var p2 := Vector2(b[o], b[o + 1]) + d * rho
	var dth := b[o + 11] + 0.22 * 12.566 * cos(w)
	var dp := d * reach * PI * cos(PI * u) + Vector2(-d.y, d.x) * rho * dth
	return Vector4(p2.x, world.ground_height(p2.x, p2.y), p2.y, atan2(-dp.x, -dp.y))


## Só a posição no chão (x, z), sem a altura: mais rápido. Vector2.INF se a
## formiga está dentro do buraco ou já foi comida.
func ant_xz(ch: Chunk, i: int) -> Vector2:
	var o := i * STRIDE
	var b := ch.buf
	if b[o + 8] < 0.5:
		return Vector2.INF
	var t := time
	var seed := b[o + 6]
	if ch.kind == TRAIL:
		var q := fposmod(b[o + 2] + t * b[o + 3], 1.0)
		var s := (2.0 * q if q < 0.5 else 2.0 - 2.0 * q) * b[o + 1]
		if s < TRAIL_HIDE_S:
			return Vector2.INF
		var lat := b[o + 4] + 0.03 * sin(t * 1.3 + seed * 0.039)
		return ch.trail.point_at(s) + ch.trail.side_at(s) * lat
	var c := b[o + 4] + t * b[o + 3]
	var cyc := floorf(c)
	var u := c - cyc
	var rho := b[o + 2] * (0.75 + 0.25 * sin(cyc * 2.1 + seed * 0.013)) * sin(PI * u)
	if rho < ROAM_HIDE_RHO:
		return Vector2.INF
	var th := b[o + 10] + cyc * 2.39996 + (u - 0.5) * b[o + 11] + 0.22 * sin(u * 12.566 + seed * 0.05)
	return Vector2(b[o] + cos(th) * rho, b[o + 1] + sin(th) * rho)


## Formigas de campo (vivas e fora do buraco) a menos de `radius` (no chão)
## de `center`. Cada item: Vector4(grupo, índice, distância², 0).
func gather(center: Vector3, radius: float, out: Array[Vector4]) -> void:
	var c2 := Vector2(center.x, center.z)
	var r2 := radius * radius
	for ci in chunks.size():
		var ch := chunks[ci]
		if ch.alive <= 0:
			continue
		var cc := Vector2(ch.center.x, ch.center.z)
		if cc.distance_to(c2) > ch.radius + radius:
			continue
		if ch.kind == TRAIL:
			# Só as partes da trilha perto do ponto.
			var pts: PackedVector2Array = ch.trail.points
			var reach2 := (radius + 0.6) * (radius + 0.6)
			var any := false
			for k in pts.size():
				var hit := pts[k].distance_squared_to(c2) <= reach2
				ch.near[k] = 1 if hit else 0
				any = any or hit
			if not any:
				continue
			var b := ch.buf
			var t := time
			var last := pts.size() - 1
			for i in ch.count:
				var o := i * STRIDE
				if b[o + 8] < 0.5:
					continue
				var q := fposmod(b[o + 2] + t * b[o + 3], 1.0)
				var s := (2.0 * q if q < 0.5 else 2.0 - 2.0 * q) * b[o + 1]
				if ch.near[mini(int(s / TrailNetwork.STEP), last)] == 0:
					continue
				var d2 := ant_xz(ch, i).distance_squared_to(c2)
				if d2 <= r2:
					out.append(Vector4(ci, i, d2, 0.0))
		else:
			if ch.home.distance_to(c2) > ch.reach + radius:
				continue
			for i in ch.count:
				var d2 := ant_xz(ch, i).distance_squared_to(c2)
				if d2 <= r2:
					out.append(Vector4(ci, i, d2, 0.0))


## Há alguma formiga de campo a menos de `radius` (em 3D) deste ponto?
func any_near(point: Vector3, radius: float) -> bool:
	var found: Array[Vector4] = []
	gather(point, radius + 0.3, found)
	for f in found:
		var st := ant_state(chunks[int(f.x)], int(f.y))
		if Vector3(st.x, st.y + WORKER_SIZE * 0.25, st.z).distance_squared_to(point) <= radius * radius:
			return true
	return false


# ------------------------------------------------------------------ Mudanças

## Na trilha: Vector2(s, sentido) da formiga agora (sentido +1 = para o arbusto).
func trail_s(ci: int, i: int) -> Vector2:
	var b := chunks[ci].buf
	var o := i * STRIDE
	var q := fposmod(b[o + 2] + time * b[o + 3], 1.0)
	return Vector2((2.0 * q if q < 0.5 else 2.0 - 2.0 * q) * b[o + 1], 1.0 if q < 0.5 else -1.0)


## Está voltando para casa (trilha: para o formigueiro; passeio: segunda metade)?
func returning(ci: int, i: int) -> bool:
	var ch := chunks[ci]
	var b := ch.buf
	var o := i * STRIDE
	if ch.kind == TRAIL:
		return fposmod(b[o + 2] + time * b[o + 3], 1.0) >= 0.5
	return fposmod(b[o + 4] + time * b[o + 3], 1.0) > 0.5


## Volta a desenhar a formiga sem mexer no caminho dela (ela estava só sendo
## acompanhada pelo enxame).
func unhide(ci: int, i: int) -> void:
	_show(chunks[ci], i * STRIDE)


func speed_of(ci: int, i: int) -> float:
	var ch := chunks[ci]
	return ch.buf[i * STRIDE + 10] if ch.kind == TRAIL else ROAM_SPEED


func is_alive(ci: int, i: int) -> bool:
	return chunks[ci].buf[i * STRIDE + 8] > 0.5


## Tira a formiga do desenho (comida, ou o enxame cuida dela por enquanto).
func hide_ant(ci: int, i: int) -> void:
	var ch := chunks[ci]
	var o := i * STRIDE
	if ch.buf[o + 8] > 0.5:
		ch.buf[o + 8] = 0.0
		ch.alive -= 1
		ch.dirty = true


## A formiga volta para a trilha no ponto `s`, indo no sentido `dir` (+1 para
## o arbusto, -1 para o formigueiro).
func rejoin_trail(ci: int, i: int, s: float, dir: float) -> void:
	var ch := chunks[ci]
	var o := i * STRIDE
	var length := ch.buf[o + 1]
	var q := clampf(s, 0.0, length) / (2.0 * length)
	if dir < 0.0:
		q = 1.0 - q
	ch.buf[o + 2] = fposmod(q - time * ch.buf[o + 3], 1.0)
	_show(ch, o)


## A formiga entra na câmara dela e logo sai para um passeio novo.
func rejoin_home(ci: int, i: int) -> void:
	var ch := chunks[ci]
	var o := i * STRIDE
	ch.buf[o + 4] = fposmod(-time * ch.buf[o + 3], 1.0)
	_show(ch, o)


func _show(ch: Chunk, o: int) -> void:
	if ch.buf[o + 8] < 0.5:
		ch.buf[o + 8] = 1.0
		ch.alive += 1
	ch.dirty = true


## Brilho do faro (Faro Nítido) até `seconds` segundos a partir de agora.
func highlight(ci: int, i: int, seconds: float) -> void:
	var ch := chunks[ci]
	ch.buf[i * STRIDE + 9] = time + seconds
	ch.dirty = true


## Some com `n` formigas do grupo (jogo salvo: as que já foram comidas).
func remove_count(ci: int, n: int) -> void:
	var ch := chunks[ci]
	for i in ch.count:
		if n <= 0:
			break
		if ch.buf[i * STRIDE + 8] > 0.5:
			hide_ant(ci, i)
			n -= 1


## Uma formiga viva qualquer do grupo (ou -1).
func random_alive(ci: int) -> int:
	var ch := chunks[ci]
	if ch.alive <= 0:
		return -1
	for _k in 12:
		var i := randi() % ch.count
		if ch.buf[i * STRIDE + 8] > 0.5:
			return i
	for i in ch.count:
		if ch.buf[i * STRIDE + 8] > 0.5:
			return i
	return -1


func flags_of(ci: int, i: int) -> float:
	return chunks[ci].buf[i * STRIDE + 7]


func size_of(ci: int, i: int) -> float:
	return chunks[ci].buf[i * STRIDE + 5]


func seed_of(ci: int, i: int) -> float:
	return chunks[ci].buf[i * STRIDE + 6]


func alive_total() -> int:
	var n := 0
	for ch in chunks:
		n += ch.alive
	return n


func set_scent_overlay(enabled: bool) -> void:
	_scent_on = enabled
	for ch in chunks:
		for mmi in ch.mmis:
			mmi.material_overlay = _scent_mats[ch.kind] if enabled else null


func set_sniff_color(c: Color) -> void:
	_glow = c
	for m in _scent_mats:
		m.set_shader_parameter("tint", c)
	for ch in chunks:
		for mmi in ch.mmis:
			mmi.set_instance_shader_parameter("glow_color", c)
