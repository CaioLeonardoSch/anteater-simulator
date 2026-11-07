extends Node
## Fotos de perto de cada superfície do cenário, sempre do mesmo lugar, para
## comparar texturas antes e depois. Não faz parte do jogo (fica fora da versão
## para Windows).
##
## Uso (com tela; sem tela não há imagem):
##   godot --path . res://tools/fotos_texturas.tscn -- --start=play --fotos=C:/pasta/antes
##   godot --path . res://tools/fotos_texturas.tscn -- --start=play --fotos=C:/pasta/depois --so=chao,pedra
## Sem --fotos, salva em user://fotos (no Windows, %APPDATA%/Godot/app_userdata/Anteater Simulator/fotos).
## --so=nome1,nome2 tira só essas fotos. Nomes: arvore, copa, ipe, arbusto,
## cupinzeiro, pedra, tronco, tronco_ponta, formigueiro, chao, capim, lagoa, penhasco, paredao,
## caverna, trilha.

var main
var out_dir := "user://fotos"
var only: PackedStringArray = []


func _ready() -> void:
	out_dir = String(DevTools.args.get("fotos", out_dir))
	if DevTools.args.has("so"):
		only = String(DevTools.args.so).split(",", false)
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(4.0).timeout
	for c in main.get_children():
		if c is CanvasLayer:
			c.visible = false
	var mats = main.world.mats
	var p = main.player
	p.controls_enabled = false
	# [nome, material que identifica o objeto, distância, mirar quantos metros acima do pé]
	var jobs := [
		["arvore", mats.bark, 3.2, 1.6],
		["copa", mats.leaves_cards, 4.5, 3.2],
		["ipe", mats.ipe_cards, 10.0, 3.0],
		["arbusto", mats.shrub_cards, 2.2, 0.5],
		["cupinzeiro", mats.clay, 2.4, 0.7],
		["pedra", mats.rock, 2.0, 0.3],
		["tronco", mats.log_bark, 2.4, 0.2],
	]
	for j in jobs:
		if not _wanted(j[0]):
			continue
		var n := _find(j[1])
		if n == null:
			print("[fotos] não achei: ", j[0])
			continue
		await _look(n.global_position, j[2], j[3])
		await _shot(j[0])
	if _wanted("tronco_ponta"):
		# De frente para uma ponta quebrada do tronco caído (a madeira à mostra).
		var n := _find(mats.log_bark)
		if n:
			var half: float = n.get_meta("radius", 2.0)
			var axis := n.global_transform.basis.x.normalized()
			var tip := n.global_transform * Vector3(-half, 0.2, 0.0)
			var from := tip - axis * 1.5 + n.global_transform.basis.z.normalized() * 0.5
			var d := tip - from
			p.place_at(Vector2(from.x, from.z), atan2(-d.x, -d.z))
			await get_tree().physics_frame
			var aim: Vector3 = tip - p.camera.global_position
			p.pitch = clampf(asin(aim.normalized().y), -1.3, 1.3)
			await _shot("tronco_ponta")
	if _wanted("formigueiro"):
		await _look(main.world.nests[0].global_position, 4.0, 0.2)
		await _shot("formigueiro")
	if _wanted("chao"):
		p.place_at(Vector2(6, 6), 0.8)
		await get_tree().physics_frame
		p.pitch = -0.9
		await _shot("chao")
	if _wanted("capim"):
		p.place_at(Vector2(6, 6), 0.8)
		await get_tree().physics_frame
		p.pitch = -0.25
		await _shot("capim")
	var lagoa := main.world.find_child("Lagoa", true, false) as MeshInstance3D
	if lagoa and _wanted("lagoa"):
		var aabb := lagoa.get_aabb()
		await _look(lagoa.global_transform * aabb.get_center(), aabb.size.x * 0.5 + 3.0, 0.0)
		p.pitch = -0.35
		await _shot("lagoa")
	if _wanted("penhasco"):
		var gp: Vector3 = main.world.giant_mound.global_position
		var dir := Vector2(gp.x, gp.z).normalized()
		p.place_at(dir * 40.0, atan2(-dir.x, -dir.y))
		await get_tree().physics_frame
		p.pitch = 0.05
		await _shot("penhasco")
	if _wanted("paredao"):
		# De perto, a 5 m do pé do paredão, longe da caverna e da passagem.
		var a := 0.6
		while a < 2.4 and not _clear(Vector2(cos(a), sin(a)) * (main.world.cliffs.radius_at(a) - 5.0)):
			a += 0.05
		var dir := Vector2(cos(a), sin(a))
		p.place_at(dir * (main.world.cliffs.radius_at(a) - 5.0), atan2(-dir.x, -dir.y))
		await get_tree().physics_frame
		p.pitch = 0.3
		await _shot("paredao")
	if _wanted("caverna"):
		# Do fundo da caverna, olhando para a boca (o que se vê ao acordar).
		var dir: Vector2 = -main.world.cliffs.cave_spot().normalized()
		p.place_at(main.world.cliffs.cave_spot(), atan2(-dir.x, -dir.y))
		await get_tree().physics_frame
		p.pitch = 0.05
		await _shot("caverna")
	if _wanted("trilha"):
		var sw = main.swarm
		var best := -1
		for i in sw.CAPACITY:
			if sw.alive[i] == 1 and sw.kind[i] == sw.TANAJURA and _clear(Vector2(sw.pos[i].x, sw.pos[i].z)):
				best = i
				break
		if best >= 0:
			await _look(sw.pos[best], 1.3, 0.0)
			await _shot("trilha")
	print("[fotos] prontas em ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _wanted(name: String) -> bool:
	return only.is_empty() or only.has(name)


## Longe de árvores, pedras e arbustos (para nenhuma folha tapar a foto).
func _clear(p2: Vector2) -> bool:
	for o in main.world.vegetation.obstacles:
		if Vector2(o.x, o.y).distance_to(p2) < o.z + 3.0:
			return false
	return true


func _mats_of(n: Node, acc: Array) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.material_override:
			acc.append(mi.material_override)
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var m = mi.get_surface_override_material(s)
				if m == null:
					m = mi.mesh.surface_get_material(s)
				if m:
					acc.append(m)
	for c in n.get_children():
		_mats_of(c, acc)


## O objeto com esse material mais perto do centro da clareira.
func _find(mat) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for c in main.world.vegetation.get_children():
		if not (c is Node3D):
			continue
		var acc := []
		_mats_of(c, acc)
		if acc.has(mat):
			var d: float = Vector2(c.global_position.x, c.global_position.z).length()
			if d < bd and d < 60.0:
				bd = d
				best = c
	return best


## Põe o tamanduá a `dist` metros do alvo (do lado do centro da clareira),
## olhando para ele.
func _look(target: Vector3, dist: float, aim_y: float) -> void:
	var p = main.player
	var t2 := Vector2(target.x, target.z)
	var away := (-t2).normalized() if t2.length() > 1.0 else Vector2(1, 0)
	var s2 := t2 + away * dist
	var d := Vector3(t2.x - s2.x, 0, t2.y - s2.y)
	p.place_at(s2, atan2(-d.x, -d.z))
	await get_tree().physics_frame
	var cam: Vector3 = p.camera.global_position
	var aim := Vector3(target.x, target.y + aim_y, target.z) - cam
	p.pitch = clampf(asin(aim.normalized().y), -1.3, 1.3)


func _shot(name: String) -> void:
	for i in 12:
		await get_tree().process_frame
	DevTools._capture("%s/%s.jpg" % [out_dir, name])
