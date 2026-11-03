extends StyleBox
## Moldura do estilo Constelação (o mesmo da árvore de habilidades): fundo quase
## preto com um leve degradê, borda dourada fina e uma segunda linha dourada por
## dentro. Opcional: brilho em volta (botão com o mouse em cima) e losangos nos
## cantos (painéis dos menus).

var bg_top := Color(0.063, 0.043, 0.035, 0.9)
var bg_bottom := Color(0.031, 0.024, 0.02, 0.9)
var border := Color(0.91, 0.706, 0.31, 0.8)
var inner := Color(0.91, 0.706, 0.31, 0.25)
## Distância da linha de dentro até a borda.
var inset := 4.0
## Brilho dourado em volta (0 = nenhum).
var glow := 0.0
## Losangos nos quatro cantos.
var corners := false


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	var rs := RenderingServer
	if glow > 0.0:
		for k in 4:
			rs.canvas_item_add_rect(to_canvas_item, rect.grow(1.5 + k * 2.5), Color(border, glow * 0.07))
	if bg_top.a > 0.0 or bg_bottom.a > 0.0:
		var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)])
		rs.canvas_item_add_polygon(to_canvas_item, pts, PackedColorArray([bg_top, bg_top, bg_bottom, bg_bottom]))
	if border.a > 0.0:
		_outline(to_canvas_item, rect.grow(-0.5), border)
	if inner.a > 0.0 and rect.size.x > inset * 3.0 and rect.size.y > inset * 3.0:
		_outline(to_canvas_item, rect.grow(-inset - 0.5), inner)
	if corners:
		for p in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var d := PackedVector2Array([p + Vector2(0, -4.5), p + Vector2(4.5, 0), p + Vector2(0, 4.5), p + Vector2(-4.5, 0)])
			rs.canvas_item_add_polygon(to_canvas_item, d, PackedColorArray([border, border, border, border]))


func _outline(ci: RID, r: Rect2, col: Color) -> void:
	var p := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	RenderingServer.canvas_item_add_polyline(ci, p, PackedColorArray([col, col, col, col, col]), 1.0)
