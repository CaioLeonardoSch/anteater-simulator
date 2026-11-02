extends Node3D
## Marcas do faro no mundo: nuvens de cheiro borradas onde estão as formigas
## farejadas (Faro Preciso) e colunas de cheiro nas câmaras fechadas (Faro de
## Câmara). Somem junto com o faro.

const MAX_CLOUDS := 48
const MAX_PILLARS := 40
## Tamanho da célula usada para juntar formigas próximas numa nuvem só.
const CLOUD_CELL := 3.5

var world
var _clouds: MultiMeshInstance3D
var _pillars: MultiMeshInstance3D
var _cloud_base := PackedFloat32Array()
var _pillar_count := 0
var _color := Color(1.0, 0.16, 0.12)
var _fade := 0.0


func setup(w) -> void:
	world = w
	var cloud_mesh := QuadMesh.new()
	cloud_mesh.size = Vector2(1.0, 1.0)
	_clouds = _make_layer(MAX_CLOUDS, cloud_mesh, _soft_dot(), BaseMaterial3D.BILLBOARD_ENABLED)
	var beam := QuadMesh.new()
	beam.size = Vector2(0.9, 7.0)
	beam.center_offset = Vector3(0.0, 3.5, 0.0)
	_pillars = _make_layer(MAX_PILLARS, beam, _beam_texture(), BaseMaterial3D.BILLBOARD_FIXED_Y)


func _make_layer(count: int, mesh: QuadMesh, tex: Texture2D, billboard: int) -> MultiMeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = billboard
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.disable_receive_shadows = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-90, -20, -90), Vector3(180, 60, 180))
	add_child(mmi)
	return mmi


func set_color(c: Color) -> void:
	_color = c
	set_fade(_fade)


## Junta as formigas farejadas em grupos (centro e quantidade), maiores primeiro.
func clusters(points: PackedVector3Array) -> Array:
	var cells := {}
	for p in points:
		var key := Vector2i(floori(p.x / CLOUD_CELL), floori(p.z / CLOUD_CELL))
		var acc: Array = cells.get(key, [Vector3.ZERO, 0])
		acc[0] += p
		acc[1] += 1
		cells[key] = acc
	var out := []
	for key in cells:
		var acc: Array = cells[key]
		out.append({"center": acc[0] / float(acc[1]), "count": acc[1]})
	out.sort_custom(func(a, b): return a.count > b.count)
	return out


## Nuvens borradas: mostram mais ou menos onde estão (nunca a posição exata).
func show_clouds(points: PackedVector3Array) -> void:
	var groups := clusters(points)
	var mm := _clouds.multimesh
	var n := mini(groups.size(), MAX_CLOUDS)
	_cloud_base.resize(n)
	for k in n:
		var g: Dictionary = groups[k]
		var c: Vector3 = g.center + Vector3(randf_range(-0.9, 0.9), 0.0, randf_range(-0.9, 0.9))
		c.y = world.ground_height(c.x, c.z) + 0.75
		var size := minf(1.7 + sqrt(float(g.count)) * 0.6, 4.2)
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3(size, size * 0.7, size)), c))
		_cloud_base[k] = clampf(0.3 + float(g.count) * 0.03, 0.3, 0.55)
	mm.visible_instance_count = n
	set_fade(1.0)


## Colunas de cheiro saindo das câmaras fechadas.
func show_pillars(spots: Array) -> void:
	var mm := _pillars.multimesh
	_pillar_count = mini(spots.size(), MAX_PILLARS)
	for k in _pillar_count:
		var p: Vector3 = spots[k]
		mm.set_instance_transform(k, Transform3D(Basis(), p))
	mm.visible_instance_count = _pillar_count
	set_fade(1.0)


## Some aos poucos com o faro (1 = forte, 0 = apagado).
func set_fade(a: float) -> void:
	_fade = a
	var cm := _clouds.multimesh
	for k in mini(_cloud_base.size(), cm.visible_instance_count):
		cm.set_instance_color(k, Color(_color, _cloud_base[k] * a))
	var pm := _pillars.multimesh
	for k in _pillar_count:
		pm.set_instance_color(k, Color(_color, 0.95 * a))
	if a <= 0.0:
		cm.visible_instance_count = 0
		pm.visible_instance_count = 0
		_pillar_count = 0
		_cloud_base.resize(0)


func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


## Faixa vertical: forte embaixo, sumindo para cima, com as bordas suaves.
func _beam_texture() -> Texture2D:
	var w := 16
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var up := pow(float(y) / (h - 1), 1.4)
		for x in w:
			var side := 1.0 - absf(float(x) / (w - 1) * 2.0 - 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(up * pow(side, 1.2), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
