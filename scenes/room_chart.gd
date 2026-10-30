class_name RoomChart
extends Control
## The Room: a live stock-chart line of the crowd's Heat. Green when it's
## climbing, red when it's falling, with the current multiplier tagged on the
## end. Land your bit at a peak.

var values: Array[float] = []
var max_value := 20.0
var multiplier := 1.0
var font: Font


func _ready() -> void:
	custom_minimum_size = Vector2(0, 130)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(p_values: Array[float], p_multiplier: float) -> void:
	values = p_values
	multiplier = p_multiplier
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.03, 0.02, 0.06))
	# Grid: a line every 5 Heat (every ×0.5).
	for h in range(5, int(max_value), 5):
		var y := _y(h)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.08), 2)
	if values.size() < 2:
		return
	var label_w := 110.0
	var w := size.x - label_w
	var step := w / float(Balance.CHART_POINTS - 1)
	var start := Balance.CHART_POINTS - values.size()
	var pts := PackedVector2Array()
	for i in values.size():
		pts.append(Vector2((start + i) * step, _y(values[i])))
	# Filled area under the line, then the line, coloured by recent trend.
	var trend := values[-1] - values[maxi(0, values.size() - 6)]
	var col := Color(0.3, 1.0, 0.45) if trend >= 0 else Color(1.0, 0.3, 0.35)
	var fill := pts.duplicate()
	fill.append(Vector2(pts[-1].x, size.y))
	fill.append(Vector2(pts[0].x, size.y))
	draw_colored_polygon(fill, Color(col, 0.15))
	draw_polyline(pts, col, 4.0)
	var tip := pts[-1]
	draw_circle(tip, 8.0, col)
	draw_circle(tip, 4.0, Color.WHITE)
	if font:
		var text := "×%.1f" % multiplier
		var y := clampf(tip.y + 10, 24, size.y - 6)
		draw_string_outline(font, Vector2(tip.x + 14, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 8, Color(0, 0, 0))
		draw_string(font, Vector2(tip.x + 14, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
	draw_rect(r, Color(0.04, 0.02, 0.07), false, 4.0)


func _y(v: float) -> float:
	var pad := 8.0
	return pad + (1.0 - clampf(v / max_value, 0.0, 1.0)) * (size.y - pad * 2)
