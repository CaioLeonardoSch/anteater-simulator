extends Node
## Fotos de perto de cada superfície do cenário, sempre do mesmo lugar, para
## comparar texturas antes e depois. Não faz parte do jogo (fica fora da versão
## para Windows).
##
## Uso (com tela; sem tela não há imagem):
##   godot --path . res://tools/fotos_texturas.tscn -- --start=play --fotos=C:/pasta/antes
##   godot --path . res://tools/fotos_texturas.tscn -- --start=play --fotos=C:/pasta/depois --so=chao,pedra
## Sem --fotos, salva em user://fotos (no Windows, %APPDATA%/Godot/app_userdata/Anteater Simulator/fotos).
## --so=nome1,nome2 tira só essas fotos. Nomes: arvore, copa, ipe, ipe_perto, ipe_roxo, arbusto,
## cupinzeiro, pedra, pedra_pequena, pedra_grande, tronco, tronco_ponta, formigueiro, formigueiro_grande, chao, capim, lagoa, lagoa_beira, penhasco, paredao,
## caverna, mata, mata_chao, trilha, camara, camara_funda, camara_campo, cratera, cavar, poeira, lascas,
## cogumelos, cogumelos_longe, cogumelo_comer, flores, flores_longe, focinho, focinho_sol, formigas, tanajura,
## cupinzeiro_gigante, tampa_campo, tampa_monte, tampa_funda, tampa_rainha.

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
		["ipe_perto", mats.ipe_cards, 4.0, 3.6],
		["ipe_roxo", mats.ipe_roxo_cards, 10.0, 3.0],
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
	# Pedras soltas: a menor e a maior (as grandes caíram dos penhascos).
	if _wanted("pedra_pequena") or _wanted("pedra_grande"):
		var rocks: Array = main.world.vegetation.rocks.duplicate()
		var size_of := func(r: Node3D) -> float:
			for c in r.get_children():
				if c is MeshInstance3D:
					var a: AABB = (c as MeshInstance3D).get_aabb()
					return maxf(a.size.x, a.size.z) * r.scale.x
			return 1.0
		rocks.sort_custom(func(a, b): return size_of.call(a) < size_of.call(b))
		for job in [["pedra_pequena", rocks.front()], ["pedra_grande", rocks.back()]]:
			if not _wanted(job[0]) or job[1] == null:
				continue
			var s: float = size_of.call(job[1])
			await _look(job[1].global_position, s * 1.3 + 0.8, s * 0.15)
			await _shot(job[0])
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
	if _wanted("formigueiro_grande"):
		for nest in main.world.nests:
			if nest.big:
				await _look(nest.global_position, nest.radius + 3.0, 0.3)
				await _shot("formigueiro_grande")
				break
	# Câmaras abertas de cada nível: rasa (formigueiro pequeno), funda
	# (formigueiro grande) e a do campo (longe dos montes).
	for job in [["camara", false], ["camara_funda", true]]:
		if not _wanted(job[0]):
			continue
		for nest in main.world.nests:
			if nest.big != job[1]:
				continue
			var ci := _first_mound_chamber(nest)
			if ci < 0:
				continue
			var c = nest.chambers[ci]
			main.colony.open_chamber(nest, ci, true)
			# Do lado de cima do monte, olhando para dentro dela.
			var cp: Vector3 = nest.chamber_world_pos(c)
			var out2: Vector2 = Vector2(cp.x, cp.z) - nest.center2
			out2 = out2.normalized() if out2.length() > 0.1 else Vector2(1, 0)
			await _look_from(Vector2(cp.x, cp.z) - out2 * 1.0, cp)
			await _shot(job[0])
			break
	if _wanted("camara_campo"):
		var done := false
		for nest in main.world.nests:
			for ci in nest.chambers.size():
				var c = nest.chambers[ci]
				if not c.satellite or not _clear(c.pos2):
					continue
				main.colony.open_chamber(nest, ci, true)
				var cp: Vector3 = nest.chamber_world_pos(c)
				var away: Vector2 = (-c.pos2).normalized()
				await _look_from(c.pos2 + away * 1.4, cp)
				await _shot("camara_campo")
				done = true
				break
			if done:
				break
	# Tampas fechadas de cada nível, com o buraco por onde as formigas entram
	# (de longe o bastante para elas não fugirem do tamanduá).
	if _wanted("tampa_campo"):
		var done := false
		for nest in main.world.nests:
			for ci in nest.chambers.size():
				var c = nest.chambers[ci]
				if not c.satellite or c.opened or not _clear(c.pos2):
					continue
				var cp: Vector3 = nest.chamber_world_pos(c)
				await _look_from(c.pos2 + (-c.pos2).normalized() * 3.0, cp)
				await _shot_after("tampa_campo", 3.0)
				done = true
				break
			if done:
				break
	for job in [["tampa_monte", false, false], ["tampa_funda", true, false], ["tampa_rainha", true, true]]:
		if not _wanted(job[0]):
			continue
		for nest in main.world.nests:
			if nest.big != job[1]:
				continue
			var ci := -1
			for k in nest.chambers.size():
				var c = nest.chambers[k]
				if not c.satellite and c.royal == job[2] and not c.opened:
					ci = k
					break
			if ci < 0:
				continue
			var c = nest.chambers[ci]
			var cp: Vector3 = nest.chamber_world_pos(c)
			var out2: Vector2 = Vector2(cp.x, cp.z) - nest.center2
			out2 = out2.normalized() if out2.length() > 0.1 else Vector2(1, 0)
			await _look_from(Vector2(cp.x, cp.z) + out2 * 3.0, cp)
			await _shot_after(job[0], 6.0)
			break
	if _wanted("cratera"):
		# O monte grande desmanchado (Escavação Real): o buraco da rainha.
		for nest in main.world.nests:
			if not nest.big:
				continue
			for ci in nest.chambers.size():
				if nest.chambers[ci].royal:
					main.colony.open_chamber(nest, ci, true)
					break
			# Da borda do buraco, olhando para o fundo.
			var gp: Vector3 = nest.global_position
			var d2 := (-Vector2(gp.x, gp.z)).normalized()
			await _look_from(Vector2(gp.x, gp.z) + d2 * nest.radius * 0.95, gp)
			await _shot("cratera")
			break
	if _wanted("chao"):
		p.place_at(Vector2(6, 6), 0.8)
		await get_tree().physics_frame
		p.pitch = -0.9
		await _shot("chao")
	if _wanted("formigas"):
		# Na beira da primeira trilha, olhando as operárias passarem.
		var tr = main.world.trails.trails[0]
		var s0: float = tr.length * 0.35
		var tp: Vector2 = tr.point_at(s0)
		var side: Vector2 = tr.side_at(s0)
		var ty: float = main.world.terrain.get_height(tp.x, tp.y)
		await _look_from(tp + side * 0.75, Vector3(tp.x, ty, tp.y))
		await _shot("formigas")
	if _wanted("tanajura"):
		# A primeira tanajura viva, de perto.
		var sw = main.swarm
		var best := -1
		for i in sw.alive.size():
			if sw.alive[i] == 1 and sw.kind[i] == sw.TANAJURA:
				best = i
				break
		if best >= 0:
			# Para a tanajura enquanto fotografa.
			var spd: float = sw.speed[best]
			sw.speed[best] = 0.0
			# Ela voa balançando: a câmera acompanha a cada quadro, de lado.
			for _f in 14:
				var tq: Vector3 = sw.pos[best]
				var fwd := Vector2(-sin(sw.yaw[best]), -cos(sw.yaw[best]))
				var side := Vector2(-fwd.y, fwd.x)
				# Um pouco à frente e de lado; mira abaixo dela para ficar acima do focinho.
				await _look_from(Vector2(tq.x, tq.z) + (side + fwd * 0.6).normalized() * 0.55, tq - Vector3(0, 0.12, 0))
			print("[fotos] tanajura em ", sw.pos[best])
			DevTools._capture("%s/%s.jpg" % [out_dir, "tanajura"])
			sw.speed[best] = spd
	if _wanted("focinho") or _wanted("focinho_sol"):
		# O focinho em primeira pessoa: de costas para o sol e contra o sol.
		for k in 2:
			var name: String = ["focinho", "focinho_sol"][k]
			if not _wanted(name):
				continue
			p.place_at(Vector2(6, 6), 0.8 + PI * (1 - k))
			await get_tree().physics_frame
			p.pitch = -0.45
			await _shot(name)
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
	if _wanted("lagoa_beira") and not main.world.pond_shapes.is_empty():
		# Na beira, olhando para a água rasa e a lama (de onde o tamanduá bebe).
		var l: Vector3 = main.world.pond_shapes[0][0]
		var c2 := Vector2(l.x, l.y)
		var dir := (-c2).normalized() if c2.length() > 1.0 else Vector2(1, 0)
		var edge := c2 + dir * l.z * 0.75
		var gy: float = main.world.terrain.get_height(edge.x, edge.y)
		await _look_from(c2 + dir * (l.z + 1.6), Vector3(edge.x, gy, edge.y))
		await _shot("lagoa_beira")
	if _wanted("penhasco"):
		var gp: Vector3 = main.world.giant_mound.global_position
		var dir := Vector2(gp.x, gp.z).normalized()
		p.place_at(dir * 40.0, atan2(-dir.x, -dir.y))
		await get_tree().physics_frame
		p.pitch = 0.05
		await _shot("penhasco")
	if _wanted("cupinzeiro_gigante"):
		# De binóculo: do mesmo lugar do penhasco, com a câmera fechada no
		# cupinzeiro lá longe (a lente volta ao normal depois).
		var gp: Vector3 = main.world.giant_mound.global_position
		var dir := Vector2(gp.x, gp.z).normalized()
		p.place_at(dir * 40.0, atan2(-dir.x, -dir.y))
		await get_tree().physics_frame
		var aim: Vector3 = gp + Vector3(0, 230, 0) - p.camera.global_position
		p.pitch = asin(aim.normalized().y)
		var fov0: float = Settings.fov
		Settings.fov = 22.0
		p.camera.fov = 22.0
		await _shot("cupinzeiro_gigante")
		Settings.fov = fov0
		p.camera.fov = fov0
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
	# Chão da mata, depois da passagem. O tamanduá não chega lá (a passagem
	# termina antes), então a foto desliga a física dele e o põe em cima do chão
	# da mata: na picada olhando para a frente, e olhando para o chão.
	var floor_mi := main.world.find_child("ChaoDaMata", true, false) as MeshInstance3D
	for job in [["mata", 4.0, 14.0], ["mata_chao", 8.0, 10.5]]:
		if not _wanted(job[0]) or floor_mi == null:
			continue
		var cl = main.world.cliffs
		var e := Vector2(cos(cl.EXIT_ANGLE), sin(cl.EXIT_ANGLE))
		var start: Vector2 = e * (cl.radius_at(cl.EXIT_ANGLE) + cl.CANYON_LENGTH - 2.0)
		var from2: Vector2 = start + e * float(job[1])
		var t2: Vector2 = start + e * float(job[2])
		p.set_physics_process(false)
		var d := Vector3(t2.x - from2.x, 0, t2.y - from2.y)
		p.place_at(from2, atan2(-d.x, -d.z))
		p.global_position.y = _floor_y(floor_mi, from2) + 0.25
		await get_tree().process_frame
		var aim: Vector3 = Vector3(t2.x, _floor_y(floor_mi, t2), t2.y) - p.camera.global_position
		p.pitch = clampf(asin(aim.normalized().y), -1.3, 1.3)
		await _shot(job[0])
		p.set_physics_process(true)
	# Terra ao cavar: a tampa de uma câmara sendo aberta (terra voando), a
	# poeira do tremor e as lascas do tronco da passagem. Fotos no meio do efeito.
	if _wanted("cavar"):
		var done := false
		for nest in main.world.nests:
			if nest.big:
				continue
			for ci in nest.chambers.size():
				var c = nest.chambers[ci]
				if c.royal or c.satellite or c.opened:
					continue
				var cp: Vector3 = nest.chamber_world_pos(c)
				var out2: Vector2 = Vector2(cp.x, cp.z) - nest.center2
				out2 = out2.normalized() if out2.length() > 0.1 else Vector2(1, 0)
				await _look_from(Vector2(cp.x, cp.z) + out2 * 2.6, cp + Vector3(0, 0.3, 0))
				for i in 6:
					await get_tree().process_frame
				main.colony.open_chamber(nest, ci, false)
				await _shot_after("cavar", 0.22)
				done = true
				break
			if done:
				break
	if _wanted("poeira"):
		p.place_at(Vector2(6, 6), 0.8)
		await get_tree().physics_frame
		p.pitch = -0.35
		for i in 6:
			await get_tree().process_frame
		p._dust_ring(GameState.tremor_radius())
		await _shot_after("poeira", 0.3)
	if _wanted("lascas") and main.world.exit_log:
		var lp: Vector3 = main.world.exit_log.global_position + Vector3(0, 0.6, 0)
		var l2 := Vector2(lp.x, lp.z)
		await _look_from(l2 - l2.normalized() * 3.5, lp)
		for i in 6:
			await get_tree().process_frame
		main.world._splinters(lp)
		await _shot_after("lascas", 0.25)
	# Cogumelos: de perto, no meio do campo e a língua pegando um grupinho.
	if _wanted("flores") or _wanted("flores_longe"):
		# Florzinha mais perto do ponto (6, 6), de perto e de um pouco mais longe.
		var best := Vector3.INF
		for mmi in main.world.grass.get_children():
			if not (mmi is MultiMeshInstance3D) or mmi.material_override != main.world.mats.flower:
				continue
			var mm: MultiMesh = mmi.multimesh
			for i in mm.instance_count:
				var o := mm.get_instance_transform(i).origin
				if Vector2(o.x - 6, o.z - 6).length() < Vector2(best.x - 6, best.z - 6).length():
					best = o
		if best != Vector3.INF:
			var f2 := Vector2(best.x, best.z)
			var away := (-f2).normalized()
			if _wanted("flores"):
				await _look_from(f2 + away * 0.9, best + Vector3(0, 0.2, 0))
				await _shot("flores")
			if _wanted("flores_longe"):
				await _look_from(f2 + away * 2.6, best + Vector3(0, 0.2, 0))
				await _shot("flores_longe")
	if (_wanted("cogumelos") or _wanted("cogumelos_longe") or _wanted("cogumelo_comer")) and main.world.mushrooms.spots.size() > 0:
		var ms = main.world.mushrooms
		print("[fotos] cogumelos no mapa: ", ms.spots.size())
		var m3: Vector3 = ms.center(0)
		var m2 := Vector2(m3.x, m3.z)
		var away := (-m2).normalized()
		if _wanted("cogumelos"):
			await _look_from(m2 + away * 1.1, m3)
			await _shot("cogumelos")
		if _wanted("cogumelos_longe"):
			await _look_from(m2 + away * 3.0, m3)
			await _shot("cogumelos_longe")
		if _wanted("cogumelo_comer"):
			await _look_from(m2 + away * 1.3, m3)
			for i in 6:
				await get_tree().process_frame
			p._start_flick()
			await _shot_after("cogumelo_comer", 0.12)
			await get_tree().create_timer(1.0).timeout
			print("[fotos] comeu cogumelo: ", GameState.stat("mushrooms"), " frenesi: ", GameState.frenzy_active(), " visível: ", ms.nodes[0].visible)
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


## Primeira câmara do monte que não é a da rainha (ou -1).
func _first_mound_chamber(nest) -> int:
	for ci in nest.chambers.size():
		var c = nest.chambers[ci]
		if not c.royal and not c.satellite:
			return ci
	return -1


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


## Põe o tamanduá no ponto `from2`, olhando para `target`.
func _look_from(from2: Vector2, target: Vector3) -> void:
	var p = main.player
	var d := Vector3(target.x - from2.x, 0, target.z - from2.y)
	p.place_at(from2, atan2(-d.x, -d.z))
	await get_tree().physics_frame
	var aim: Vector3 = target - p.camera.global_position
	p.pitch = clampf(asin(aim.normalized().y), -1.3, 1.3)


func _shot(name: String) -> void:
	for i in 12:
		await get_tree().process_frame
	DevTools._capture("%s/%s.jpg" % [out_dir, name])


## Altura do chão da mata em `p2` (o vértice mais perto da malha).
func _floor_y(mi: MeshInstance3D, p2: Vector2) -> float:
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var best := INF
	var y := 0.0
	for v in verts:
		var w: Vector3 = mi.global_transform * v
		var dd := Vector2(w.x, w.z).distance_squared_to(p2)
		if dd < best:
			best = dd
			y = w.y
	return y


## Foto `secs` segundos depois de agora (para pegar um efeito no meio).
func _shot_after(name: String, secs: float) -> void:
	await get_tree().create_timer(secs).timeout
	DevTools._capture("%s/%s.jpg" % [out_dir, name])
