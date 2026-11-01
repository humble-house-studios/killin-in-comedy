extends "res://scenes/ladder/machine.gd"
## The corner office's desk toy: an executive putting green. Aim, time the
## power, PUTT into the coffee mug. Pure fun, no tokens: you made it this far.
## Counts your strokes and remembers your best.

const GREEN := Rect2(60, 200, 600, 820)
const CUP := Vector2(360, 330)
const CUP_R := 30.0
const BALL_R := 14.0
const TEE := Vector2(360, 900)
const FRICTION := 0.985

var _ball := TEE
var _vel := Vector2.ZERO
var _angle := -PI / 2
var _t := 0.0
var _strokes := 0
var _best := 0
var _sunk := false
var _info: Label
var _putt: Button


func _ready() -> void:
	super._ready()
	frame("CORNER PUTT", Color(0.08, 0.06, 0.04), Color(0.6, 0.95, 0.5))
	_top.text = "SINK IT IN THE MUG"
	_info = label("", 24, Color(1.0, 0.92, 0.55))
	_info.position = Vector2(0, 150)
	_info.size = Vector2(W, 40)
	add_child(_info)
	var row := HBoxContainer.new()
	row.position = Vector2(30, 1060)
	row.size = Vector2(W - 60, 150)
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	var left := button("<", 48)
	_putt = button("PUTT", 40, Color(0.15, 0.4, 0.12))
	var right := button(">", 48)
	for b in [left, _putt, right]:
		b.custom_minimum_size = Vector2(0, 140)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_putt.size_flags_stretch_ratio = 1.6
	left.pressed.connect(func(): _angle -= 0.1)
	right.pressed.connect(func(): _angle += 0.1)
	_putt.pressed.connect(_on_putt)
	_putt.set_meta("pad_default", true)
	_update()


func refresh_top() -> void:
	pass


func _power() -> float:
	return 0.5 - 0.5 * cos(_t * 3.0)


func _on_putt() -> void:
	if _vel.length() > 1.0:
		return
	if _sunk:
		_sunk = false
		_ball = TEE
		_strokes = 0
		_update()
		return
	_vel = Vector2(cos(_angle), sin(_angle)) * (250.0 + 1150.0 * _power())
	_strokes += 1
	sfx("click")
	_update()


func _process(delta: float) -> void:
	super._process(delta)
	if _vel.length() > 1.0:
		_ball += _vel * delta
		_vel *= pow(FRICTION, delta * 60.0)
		if _ball.x < GREEN.position.x + BALL_R or _ball.x > GREEN.end.x - BALL_R:
			_vel.x = -_vel.x * 0.8
			_ball.x = clampf(_ball.x, GREEN.position.x + BALL_R, GREEN.end.x - BALL_R)
			sfx("thump", -10.0)
		if _ball.y < GREEN.position.y + BALL_R or _ball.y > GREEN.end.y - BALL_R:
			_vel.y = -_vel.y * 0.8
			_ball.y = clampf(_ball.y, GREEN.position.y + BALL_R, GREEN.end.y - BALL_R)
			sfx("thump", -10.0)
		# The desk lamp's base sits in the way.
		var lamp := Vector2(360, 600)
		if _ball.distance_to(lamp) < 50.0 + BALL_R:
			var n := (_ball - lamp).normalized()
			_ball = lamp + n * (50.0 + BALL_R)
			_vel = _vel.bounce(n) * 0.8
			sfx("thump", -8.0)
		if _ball.distance_to(CUP) < CUP_R and _vel.length() < 700.0:
			_vel = Vector2.ZERO
			_ball = CUP
			_sunk = true
			if _best == 0 or _strokes < _best:
				_best = _strokes
			sfx("jackpot" if _strokes == 1 else "ding")
			banner("HOLE IN ONE!" if _strokes == 1 else "IN THE MUG!\n%d STROKES" % _strokes, 2.5)
		if _vel.length() <= 1.0:
			_vel = Vector2.ZERO
			_update()
	else:
		_t += delta
	queue_redraw()


func _update() -> void:
	_info.text = "STROKES %d   BEST %s" % [_strokes, str(_best) if _best > 0 else "-"]
	_putt.text = "AGAIN" if _sunk else "PUTT"


func _draw() -> void:
	draw_rect(GREEN, Color(0.2, 0.5, 0.22))
	for i in 12:
		draw_rect(Rect2(GREEN.position.x, GREEN.position.y + i * 70, GREEN.size.x, 35), Color(0.24, 0.55, 0.26))
	draw_rect(GREEN, Color(0.6, 0.45, 0.25), false, 10.0)
	draw_circle(Vector2(360, 600), 50, Color(0.25, 0.25, 0.28))
	draw_circle(Vector2(360, 600), 30, Color(0.9, 0.85, 0.5))
	draw_circle(CUP, CUP_R + 8, Color(0.95, 0.95, 0.92))
	draw_circle(CUP, CUP_R, Color(0.25, 0.15, 0.1))
	draw_string(FONT, CUP + Vector2(-60, -48), "#1 BOSS", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(1, 1, 1, 0.7))
	if not _sunk and _vel.length() <= 1.0:
		var dir := Vector2(cos(_angle), sin(_angle))
		for i in 7:
			draw_circle(_ball + dir * (30.0 + i * (20.0 + 40.0 * _power())), 5.0, Color(1, 1, 1, 0.85 - i * 0.1))
		draw_rect(Rect2(GREEN.position.x, GREEN.end.y + 12, GREEN.size.x, 18), Color(0.15, 0.1, 0.05))
		draw_rect(Rect2(GREEN.position.x, GREEN.end.y + 12, GREEN.size.x * _power(), 18), Color(1.0, 0.5 + 0.5 * _power(), 0.2))
	draw_circle(_ball, BALL_R, Color.WHITE)
