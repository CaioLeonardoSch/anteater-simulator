extends RefCounted
## Ícones das habilidades, desenhados com formas simples (usados na árvore de
## habilidades e nos botões de habilidade do HUD).

static func paint(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	match kind:
		"tongue":
			var pts := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				pts.append(c + Vector2(lerpf(-0.78, 0.5, t), 0.32 - t * 0.55 + sin(t * PI * 1.7) * 0.28) * s)
			ci.draw_polyline(pts, col, s * 0.24, true)
			ci.draw_circle(pts[pts.size() - 1], s * 0.17, col)
		"ant":
			var w := maxf(s * 0.11, 1.5)
			var thorax := c + Vector2(-0.05, 0.02) * s
			for k in 3:
				var x := (k - 1) * 0.3
				ci.draw_polyline(PackedVector2Array([thorax, thorax + Vector2(x * 0.6, -0.3) * s,
					thorax + Vector2(x * 1.2, -0.62) * s]), col, w, true)
				ci.draw_polyline(PackedVector2Array([thorax, thorax + Vector2(x * 0.6, 0.3) * s,
					thorax + Vector2(x * 1.2, 0.62) * s]), col, w, true)
			var head := c + Vector2(-0.52, 0.0) * s
			ci.draw_line(head, head + Vector2(-0.32, -0.42) * s, col, w, true)
			ci.draw_line(head, head + Vector2(-0.42, -0.2) * s, col, w, true)
			ci.draw_circle(head, s * 0.2, col)
			ci.draw_circle(thorax, s * 0.17, col)
			ci.draw_circle(c + Vector2(0.45, 0.0) * s, s * 0.32, col)
		"bolt":
			var poly := PackedVector2Array()
			for p in [Vector2(0.18, -0.9), Vector2(-0.5, 0.12), Vector2(-0.04, 0.12), Vector2(-0.2, 0.9),
					Vector2(0.5, -0.16), Vector2(0.05, -0.16)]:
				poly.append(c + p * s)
			ci.draw_colored_polygon(poly, col)
		"cross":
			ci.draw_arc(c, s * 0.58, 0, TAU, 32, col, s * 0.13, true)
			for k in 4:
				var d := Vector2.RIGHT.rotated(TAU * k / 4.0)
				ci.draw_line(c + d * s * 0.3, c + d * s * 0.92, col, s * 0.13, true)
			ci.draw_circle(c, s * 0.1, col)
		"claws":
			for k in 3:
				var off := (k - 1) * 0.42
				var pts := PackedVector2Array()
				for i in 7:
					var t := i / 6.0
					pts.append(c + Vector2(off + lerpf(-0.3, 0.3, t) + sin(t * PI) * 0.12, lerpf(-0.75, 0.75, t)) * s)
				ci.draw_polyline(pts, col, s * 0.15, true)
		"burst":
			var poly := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0 - PI * 0.5
				var r := 0.9 if i % 2 == 0 else 0.38
				poly.append(c + Vector2(cos(a), sin(a)) * r * s)
			ci.draw_colored_polygon(poly, col)
		"clock":
			ci.draw_arc(c, s * 0.72, 0, TAU, 32, col, s * 0.14, true)
			ci.draw_line(c, c + Vector2(0, -0.48) * s, col, s * 0.13, true)
			ci.draw_line(c, c + Vector2(0.36, 0.12) * s, col, s * 0.13, true)
		"paw":
			var pad := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				pad.append(c + Vector2(cos(a) * 0.46, 0.3 + sin(a) * 0.36) * s)
			ci.draw_colored_polygon(pad, col)
			for p in [Vector2(-0.62, -0.18), Vector2(-0.24, -0.55), Vector2(0.24, -0.55), Vector2(0.62, -0.18)]:
				ci.draw_circle(c + p * s, s * 0.18, col)
		"chevrons":
			for x0 in [-0.62, -0.02]:
				ci.draw_polyline(PackedVector2Array([c + Vector2(x0, -0.55) * s, c + Vector2(x0 + 0.5, 0) * s,
					c + Vector2(x0, 0.55) * s]), col, s * 0.17, true)
		"nose":
			var o := c + Vector2(-0.5, 0) * s
			ci.draw_circle(o, s * 0.2, col)
			for k in 3:
				ci.draw_arc(o, s * (0.48 + k * 0.32), -0.75, 0.75, 12, Color(col, 1.0 - k * 0.22), s * 0.12, true)
		"rings":
			ci.draw_arc(c, s * 0.78, 0, TAU, 32, col, s * 0.11, true)
			ci.draw_arc(c, s * 0.46, 0, TAU, 32, col, s * 0.11, true)
			ci.draw_circle(c, s * 0.15, col)
		"eye":
			var top := PackedVector2Array()
			var bottom := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				var x := lerpf(-0.88, 0.88, t)
				top.append(c + Vector2(x, -sin(t * PI) * 0.5) * s)
				bottom.append(c + Vector2(x, sin(t * PI) * 0.5) * s)
			ci.draw_polyline(top, col, s * 0.12, true)
			ci.draw_polyline(bottom, col, s * 0.12, true)
			ci.draw_circle(c, s * 0.25, col)
		"peak":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.85, 0.6) * s, c + Vector2(-0.1, -0.7) * s,
				c + Vector2(0.25, -0.1) * s, c + Vector2(0.45, -0.35) * s, c + Vector2(0.9, 0.6) * s]), col)
