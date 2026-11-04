extends Node
## O que o tamanduá já explorou: uma imagem pequena da clareira vista de cima,
## pintada em volta dele conforme ele anda (e onde o faro achou câmaras). O mapa
## do TAB fica colorido onde ela está pintada. Vai junto no jogo salvo.

## Lado da imagem (pixels) e da área que ela cobre (metros), com o centro da
## clareira no meio.
const SIZE := 128
const WORLD_SIZE := 150.0
## Raio que fica conhecido em volta do tamanduá (m).
const RADIUS := 11.0
## Só a clareira (dentro dos paredões) conta para a porcentagem explorada.
const AREA_RADIUS := 62.0

var player
var image: Image
var _tex: ImageTexture
var _dirty := true
var _last := Vector2.INF
var _area_idx := PackedInt32Array()


func _ready() -> void:
	image = Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	for y in SIZE:
		for x in SIZE:
			if _world_of(Vector2(x + 0.5, y + 0.5)).length() < AREA_RADIUS:
				_area_idx.append(y * SIZE + x)
	GameState.run_reset.connect(reset)


func setup(p) -> void:
	player = p
	player.sniffed.connect(_on_sniffed)


func _process(_delta: float) -> void:
	if player == null or not GameState.playing:
		return
	var p := Vector2(player.global_position.x, player.global_position.z)
	if p.distance_to(_last) < 1.5:
		return
	_last = p
	reveal(p, RADIUS)


func _px_of(p: Vector2) -> Vector2:
	return (p / WORLD_SIZE + Vector2(0.5, 0.5)) * SIZE


func _world_of(px: Vector2) -> Vector2:
	return (px / SIZE - Vector2(0.5, 0.5)) * WORLD_SIZE


## Pinta um círculo de borda macia em volta de p (no plano xz).
func reveal(p: Vector2, radius: float) -> void:
	var c := _px_of(p)
	var r := radius / WORLD_SIZE * SIZE
	var x0 := maxi(int(c.x - r) - 1, 0)
	var x1 := mini(int(c.x + r) + 1, SIZE - 1)
	var y0 := maxi(int(c.y - r) - 1, 0)
	var y1 := mini(int(c.y + r) + 1, SIZE - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / r
			if d >= 1.0:
				continue
			var v := clampf((1.0 - d) * 2.5, 0.0, 1.0)
			if v > image.get_pixel(x, y).r:
				image.set_pixel(x, y, Color(v, v, v))
	_dirty = true


## O faro achou câmaras: o lugar delas também fica conhecido no mapa.
func _on_sniffed(_n: int, _capped: bool, _nearest: float, _chambers: int) -> void:
	for cp in player.sniff_chambers:
		reveal(Vector2(cp.x, cp.z), 3.5)


## Quanto já foi visto neste ponto (0 a 1).
func explored_at(p: Vector2) -> float:
	var c := _px_of(p)
	return image.get_pixel(clampi(int(c.x), 0, SIZE - 1), clampi(int(c.y), 0, SIZE - 1)).r


## Fração da clareira já explorada (0 a 1).
func fraction() -> float:
	var data := image.get_data()
	var n := 0
	for i in _area_idx:
		if data[i] > 127:
			n += 1
	return float(n) / float(maxi(_area_idx.size(), 1))


func texture() -> ImageTexture:
	if _tex == null:
		_tex = ImageTexture.create_from_image(image)
	elif _dirty:
		_tex.update(image)
	_dirty = false
	return _tex


func reset() -> void:
	image.fill(Color(0, 0, 0))
	_last = Vector2.INF
	_dirty = true


func to_save() -> String:
	return Marshalls.raw_to_base64(image.get_data().compress(FileAccess.COMPRESSION_DEFLATE))


func from_save(text: String) -> void:
	reset()
	if text.is_empty():
		return
	var raw := Marshalls.base64_to_raw(text).decompress(SIZE * SIZE, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() == SIZE * SIZE:
		image.set_data(SIZE, SIZE, false, Image.FORMAT_L8, raw)
	_dirty = true
