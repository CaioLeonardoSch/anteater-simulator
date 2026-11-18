extends RefCounted
## Foto de uma formiga colecionável para a aba Coleção: a formiga fantasiada,
## mais detalhada que no mapa, num estúdio só dela (um SubViewport com mundo
## próprio, luz de fim de tarde e fundo transparente), tirada uma vez só.
## Sem a formiga achada, o card mostra a mesma foto toda escura (a silhueta).

const AntMeshBuilder := preload("res://scripts/ants/ant_mesh_builder.gd")

const SIZE := Vector2i(360, 360)
## Para onde a câmera olha (o meio da formiga com a fantasia) e de onde: de
## frente e de lado, um pouco de cima.
const TARGET := Vector3(0.0, 0.3, -0.16)
const VIEW_DIR := Vector3(-0.62, 0.42, -0.92)
const DISTANCE := 2.45
const FOV := 30.0


## O estúdio da `costume` (veja scripts/collectibles.gd). Ponha na árvore: a
## foto sai no quadro seguinte, em `get_texture()`.
static func make(costume: String, size: Vector2i = SIZE) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = "Foto_" + costume
	vp.size = size
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.55, 0.47)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)
	# Luz principal quente (o sol de fim de tarde), uma de preenchimento fria e
	# uma de contorno por trás.
	vp.add_child(_light(Color(1.0, 0.86, 0.68), 1.7, -40.0, -30.0, true))
	vp.add_child(_light(Color(0.6, 0.7, 0.95), 0.45, -15.0, 140.0, false))
	vp.add_child(_light(Color(1.0, 0.78, 0.55), 1.0, -18.0, 200.0, false))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = AntMeshBuilder.build("worker", -1, costume)
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	mm.set_instance_color(0, Color.WHITE)
	# Passo parado no meio (pernas abertas), semente fixa e a fantasia ligada.
	mm.set_instance_custom_data(0, Color(1.3, 0.0, 4.0 * 37.0, 2.0))
	var ant := MultiMeshInstance3D.new()
	ant.multimesh = mm
	vp.add_child(ant)
	var cam := Camera3D.new()
	cam.fov = FOV
	cam.transform = Transform3D(Basis.IDENTITY, TARGET + VIEW_DIR.normalized() * DISTANCE).looking_at(TARGET, Vector3.UP)
	cam.current = true
	vp.add_child(cam)
	return vp


static func _light(color: Color, energy: float, pitch_deg: float, yaw_deg: float, shadows: bool) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.rotation = Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0)
	l.shadow_enabled = shadows
	return l
