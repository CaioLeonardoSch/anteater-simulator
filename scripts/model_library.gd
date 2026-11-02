extends RefCounted
## Biblioteca de modelos 3D gerados por IA.
##
## Se existir um arquivo res://assets/models/<nome>.glb, o jogo usa esse modelo
## no lugar da versão feita por código. O modelo é centralizado, apoiado no chão
## e escalado para o tamanho certo automaticamente. Ajustes finos (rotação,
## escala extra, deslocamento) podem ser feitos em res://assets/models/ajustes.cfg:
##
##   [formigueiro]
##   rotacao_y=90.0
##   escala=1.1
##   deslocamento=Vector3(0, -0.05, 0)

const MODELS_DIR := "res://assets/models/"
const ADJUST_FILE := "res://assets/models/ajustes.cfg"

static var _cfg: ConfigFile = null


static func path_for(model_name: String) -> String:
	return MODELS_DIR + model_name + ".glb"


static func has_model(model_name: String) -> bool:
	return ResourceLoader.exists(path_for(model_name))


static func _adjustments() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		if FileAccess.file_exists(ADJUST_FILE):
			_cfg.load(ADJUST_FILE)
	return _cfg


## Instancia o modelo (ou null se não existir), cabendo em `target_size`
## (x/z = pegada no chão, y = altura; use 0 para ignorar um eixo).
static func instantiate(model_name: String, target_size: Vector3) -> Node3D:
	var path := path_for(model_name)
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if not (res is PackedScene):
		push_warning("Modelo inválido: " + path)
		return null
	var inst: Node3D = (res as PackedScene).instantiate()
	var aabb := compute_aabb(inst)
	if aabb.size.length() < 0.0001:
		return null
	var cfg := _adjustments()
	var ratios: Array[float] = []
	if target_size.x > 0.0:
		ratios.append(target_size.x / maxf(aabb.size.x, 0.0001))
	if target_size.z > 0.0:
		ratios.append(target_size.z / maxf(aabb.size.z, 0.0001))
	if target_size.y > 0.0:
		ratios.append(target_size.y / maxf(aabb.size.y, 0.0001))
	var s: float = ratios.min() if not ratios.is_empty() else 1.0
	s *= float(cfg.get_value(model_name, "escala", 1.0))
	var wrapper := Node3D.new()
	wrapper.name = "Modelo_" + model_name
	var pivot := Node3D.new()
	pivot.rotation_degrees.y = float(cfg.get_value(model_name, "rotacao_y", 0.0))
	wrapper.add_child(pivot)
	pivot.add_child(inst)
	inst.scale = inst.scale * s
	var center := aabb.get_center()
	inst.position = -Vector3(center.x, aabb.position.y, center.z) * s + inst.position * s
	wrapper.position = cfg.get_value(model_name, "deslocamento", Vector3.ZERO)
	return wrapper


## Caixa envolvente de todas as malhas de uma árvore de nós (no espaço da raiz).
static func compute_aabb(root: Node) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		if node is Node3D and node != root:
			xf = xf * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var box: AABB = xf * (node as MeshInstance3D).mesh.get_aabb()
			if first:
				result = box
				first = false
			else:
				result = result.merge(box)
		for child in node.get_children():
			stack.append([child, xf])
	return result


## Primeira malha encontrada no modelo, já com a transformação que a deixa
## centralizada, apoiada no chão e com o comprimento pedido (para MultiMesh).
static func load_mesh(model_name: String, target_length: float) -> Dictionary:
	var path := path_for(model_name)
	if not ResourceLoader.exists(path):
		return {}
	var res = load(path)
	if not (res is PackedScene):
		return {}
	var inst: Node = (res as PackedScene).instantiate()
	var stack: Array = [[inst, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		if node is Node3D and node != inst:
			xf = xf * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh: Mesh = (node as MeshInstance3D).mesh
			var box: AABB = xf * mesh.get_aabb()
			var longest := maxf(box.size.x, box.size.z)
			var s := target_length / maxf(longest, 0.0001)
			s *= float(_adjustments().get_value(model_name, "escala", 1.0))
			var rot := Basis(Vector3.UP, deg_to_rad(float(_adjustments().get_value(model_name, "rotacao_y", 0.0))))
			var c := box.get_center()
			var fix := Transform3D(rot.scaled(Vector3.ONE * s), Vector3.ZERO) \
				* Transform3D(Basis.IDENTITY, -Vector3(c.x, box.position.y, c.z)) * xf
			inst.free()
			return {"mesh": mesh, "transform": fix}
		for child in node.get_children():
			stack.append([child, xf])
	inst.free()
	return {}
