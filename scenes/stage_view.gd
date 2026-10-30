class_name StageView
extends Control
## Draws what stands on the stage: the mic stand in the spotlight and a row
## of audience silhouettes that bounce when they laugh and slump when cold.

const SILHOUETTE := Color(0.035, 0.025, 0.05)

## Where the floor starts, as a fraction of height (matches stage.gdshader).
var floor_y := 0.80
var crowd_size := 9
var is_boss := false
## 0 = cold crowd, 0.5 = normal, 1 = hot.
var heat := 0.5:
	set(value):
		heat = value
		queue_redraw()

var _excite := 0.0
var _time := 0.0
var _phases: Array[float] = []
var _rates: Array[float] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_crowd(crowd_size, false)


func set_crowd(count: int, boss: bool) -> void:
	crowd_size = count
	is_boss = boss
	_phases.clear()
	_rates.clear()
	for i in count:
		_phases.append(randf() * TAU)
		_rates.append(randf_range(9.0, 14.0))
	queue_redraw()


## Make the crowd laugh: 0.3 = chuckle, 1 = roaring.
func react(strength: float) -> void:
	_excite = maxf(_excite, clampf(strength, 0.0, 1.2))


func _process(delta: float) -> void:
	if _excite > 0.001:
		_time += delta
		_excite *= exp(-delta * 1.4)
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var light := Color(0.55, 0.68, 1.0).lerp(Color(1.0, 0.82, 0.52), clampf(heat * 1.6 - 0.3, 0.0, 1.0))

	# Mic stand in the spotlight.
	var cx := w * 0.5
	var base_y := h * floor_y + h * 0.03
	var top_y := h * 0.50
	draw_set_transform(Vector2(cx, base_y), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, w * 0.045, Color(0.08, 0.08, 0.09))
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(cx, base_y), Vector2(cx, top_y), Color(0.12, 0.12, 0.14), 6.0)
	draw_line(Vector2(cx + 2, base_y), Vector2(cx + 2, top_y), light * Color(1, 1, 1, 0.35), 2.0)
	var mic := Vector2(cx + 10, top_y - 16)
	draw_line(Vector2(cx, top_y), mic, Color(0.12, 0.12, 0.14), 6.0)
	draw_circle(mic, 13.0, Color(0.18, 0.18, 0.2))
	draw_circle(mic + Vector2(-3, -4), 6.0, light * Color(1, 1, 1, 0.45))

	# Audience: heads and shoulders along the bottom edge.
	var r := clampf(w / (crowd_size * 2.6), 16.0, 34.0)
	var slump := (0.5 - minf(heat, 0.5)) * r * 0.9
	var rim := light * Color(1, 1, 1, 0.25 + 0.35 * heat)
	for i in crowd_size:
		var x := (i + 0.5) / crowd_size * w + (r * 0.4 if i % 2 else -r * 0.4)
		var bounce := absf(sin(_time * _rates[i] + _phases[i])) * _excite * r * 0.7
		var head := Vector2(x, h - r * 1.25 + slump - bounce)
		draw_circle(head + Vector2(0, -2), r + 2.0, rim)
		draw_circle(head, r, SILHOUETTE)
		draw_circle(Vector2(x, h + r * 0.55 - bounce * 0.4), r * 1.7, SILHOUETTE)
		if is_boss and i == crowd_size / 2:
			# The Critic: top hat.
			var brim := head + Vector2(0, -r * 0.8)
			draw_rect(Rect2(brim + Vector2(-r * 1.1, -4), Vector2(r * 2.2, 7)), SILHOUETTE)
			draw_rect(Rect2(brim + Vector2(-r * 0.7, -r * 1.3), Vector2(r * 1.4, r * 1.3)), SILHOUETTE)
			draw_rect(Rect2(brim + Vector2(-r * 0.7, -r * 1.3), Vector2(r * 1.4, r * 1.3)), rim, false, 2.0)
