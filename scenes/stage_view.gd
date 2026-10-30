class_name StageView
extends Control
## Draws what stands on the stage in chunky 8-bit pixels: the mic stand in
## the spotlight and a row of audience silhouettes that bounce when they laugh
## and slump when cold. Everything snaps to a PIXEL grid (matches stage.gdshader).

const PIXEL := 6.0
const SILHOUETTE := Color(0.05, 0.03, 0.08)
const METAL := Color(0.16, 0.15, 0.2)

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


func _snap(v: float) -> float:
	return floorf(v / PIXEL) * PIXEL


## A filled rectangle snapped to the pixel grid.
func _block(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(_snap(x), _snap(y), maxf(PIXEL, _snap(w)), maxf(PIXEL, _snap(h))), color)


## A blocky circle, one pixel row at a time.
func _disc(center: Vector2, r: float, color: Color) -> void:
	var rows := ceili(r / PIXEL)
	for row in range(-rows, rows):
		var y := (row + 0.5) * PIXEL
		var half := sqrt(maxf(r * r - y * y, 0.0))
		half = roundf(half / PIXEL) * PIXEL
		if half > 0.0:
			draw_rect(Rect2(_snap(center.x) - half, _snap(center.y) + row * PIXEL, half * 2.0, PIXEL), color)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var light := Color(0.45, 0.6, 1.0) if heat < 0.4 else Color(1.0, 0.85, 0.45)

	# Mic stand in the spotlight.
	var cx := _snap(w * 0.5)
	var base_y := _snap(h * floor_y + h * 0.03)
	var top_y := _snap(h * 0.50)
	_block(cx - PIXEL * 5, base_y, PIXEL * 11, PIXEL, METAL)
	_block(cx - PIXEL * 3, base_y - PIXEL, PIXEL * 7, PIXEL, METAL)
	_block(cx, top_y, PIXEL, base_y - top_y, METAL)
	_block(cx + PIXEL, top_y, PIXEL, base_y - top_y, METAL.lerp(light, 0.3))
	_block(cx + PIXEL, top_y - PIXEL, PIXEL * 2, PIXEL, METAL)
	_block(cx + PIXEL * 2, top_y - PIXEL * 2, PIXEL, PIXEL, METAL)
	# Mic head: grille with a lit corner.
	var mic := Vector2(cx + PIXEL * 1, top_y - PIXEL * 6)
	_block(mic.x, mic.y, PIXEL * 4, PIXEL * 4, METAL.lightened(0.15))
	_block(mic.x + PIXEL, mic.y - PIXEL, PIXEL * 2, PIXEL, METAL.lightened(0.15))
	_block(mic.x + PIXEL, mic.y + PIXEL * 4, PIXEL * 2, PIXEL, METAL)
	_block(mic.x + PIXEL, mic.y, PIXEL, PIXEL, Color(light, 0.8))

	# Audience: heads and shoulders along the bottom edge.
	var r := clampf(w / (crowd_size * 2.6), 18.0, 34.0)
	var slump := (0.5 - minf(heat, 0.5)) * r * 0.9
	var rim := Color(light, 0.35 + 0.45 * heat)
	for i in crowd_size:
		var x := (i + 0.5) / crowd_size * w + (r * 0.4 if i % 2 else -r * 0.4)
		var bounce := _snap(absf(sin(_time * _rates[i] + _phases[i])) * _excite * r * 0.7)
		var head := Vector2(x, h - r * 1.25 + slump - bounce)
		_disc(head + Vector2(0, -PIXEL), r, rim)
		_disc(head, r, SILHOUETTE)
		_disc(Vector2(x, h + r * 0.55 - bounce * 0.4), r * 1.7, SILHOUETTE)
		if is_boss and i == crowd_size / 2:
			# The Critic: top hat with a lit band.
			var brim := head + Vector2(0, -r * 0.8)
			_block(brim.x - r * 1.1, brim.y - PIXEL, r * 2.2, PIXEL * 2, SILHOUETTE)
			_block(brim.x - r * 0.7, brim.y - r * 1.4, r * 1.4, r * 1.4, SILHOUETTE)
			_block(brim.x - r * 0.7, brim.y - PIXEL * 2, r * 1.4, PIXEL, rim)
