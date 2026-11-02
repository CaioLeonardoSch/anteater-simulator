extends RefCounted
## Rede de trilhas de formigas: cada trilha liga um formigueiro a um arbusto
## (fonte de folhas). As formigas saem do formigueiro, cortam folhas e voltam.

const STEP := 0.25


class Trail extends RefCounted:
	var points := PackedVector2Array()
	var lateral := PackedVector2Array()
	var length := 0.0
	var nest := 0
	var food := 0

	func point_at(s: float) -> Vector2:
		var f := clampf(s / STEP, 0.0, points.size() - 1.001)
		var i := int(f)
		return points[i].lerp(points[i + 1], f - i)

	func side_at(s: float) -> Vector2:
		var i := clampi(int(s / STEP), 0, lateral.size() - 1)
		return lateral[i]

	func dir_at(s: float) -> Vector2:
		var i := clampi(int(s / STEP), 0, points.size() - 2)
		return (points[i + 1] - points[i]).normalized()

	## Ponto da trilha mais próximo de p, procurando perto de `hint_s`.
	func closest_s(p: Vector2, hint_s: float = -1.0, window: float = 12.0) -> float:
		var best := 0.0
		var best_d := INF
		var i0 := 0
		var i1 := points.size() - 1
		if hint_s >= 0.0:
			i0 = maxi(int((hint_s - window) / STEP), 0)
			i1 = mini(int((hint_s + window) / STEP), points.size() - 1)
		var stride := 2
		var i := i0
		while i <= i1:
			var d := points[i].distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = i * STEP
			i += stride
		return best


var trails: Array[Trail] = []
var _noise := FastNoiseLite.new()


func _init(seed_value: int = 1) -> void:
	_noise.seed = seed_value
	_noise.frequency = 0.08


func add_trail(a: Vector2, b: Vector2, nest_index: int, food_index: int, rng: RandomNumberGenerator) -> Trail:
	var dir := b - a
	var total := dir.length()
	var side := Vector2(-dir.y, dir.x).normalized()
	var ctrl: Array[Vector2] = []
	var count := maxi(3, int(total / 3.5))
	var amp := minf(4.5, total * 0.14)
	var phase := rng.randf() * 1000.0
	for i in count + 1:
		var t := float(i) / count
		var off := _noise.get_noise_1d(phase + t * total * 1.3) * amp * 1.8 * sin(PI * t)
		ctrl.append(a + dir * t + side * off)
	# Catmull-Rom denso.
	var dense := PackedVector2Array()
	for i in ctrl.size() - 1:
		var p0 := ctrl[maxi(i - 1, 0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(i + 2, ctrl.size() - 1)]
		for k in 10:
			var t := k / 10.0
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	dense.append(ctrl[ctrl.size() - 1])
	# Reamostragem em passos iguais.
	var trail := Trail.new()
	trail.nest = nest_index
	trail.food = food_index
	trail.points.append(dense[0])
	var carry := 0.0
	for i in dense.size() - 1:
		var p := dense[i]
		var q := dense[i + 1]
		var seg := p.distance_to(q)
		var pos := STEP - carry
		while pos <= seg:
			trail.points.append(p.lerp(q, pos / seg))
			pos += STEP
		carry = seg - (pos - STEP)
	trail.length = (trail.points.size() - 1) * STEP
	trail.lateral.resize(trail.points.size())
	for i in trail.points.size():
		var d := trail.points[mini(i + 1, trail.points.size() - 1)] - trail.points[maxi(i - 1, 0)]
		var dn := d.normalized()
		trail.lateral[i] = Vector2(-dn.y, dn.x)
	trails.append(trail)
	return trail


## Menor distância de p até qualquer trilha (para posicionar a vegetação).
func distance_to_trails(p: Vector2) -> float:
	var best := INF
	for t in trails:
		var i := 0
		while i < t.points.size():
			best = minf(best, t.points[i].distance_squared_to(p))
			i += 4
	return sqrt(best)
