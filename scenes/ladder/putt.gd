extends "res://scenes/ladder/machine.gd"
## The corner office's desk toy, now a 3D mini-golf course
## (scenes/ladder/view3d.gd) built on the executive desk in golden-hour light:
## three holes (THE MUG, THE BOOK RAMP, THE IN-TRAY). Turn with the arrows
## (hold to swing round), time the power, PUTT. Real ball physics: rails
## bounce, the ramp slows you, roll off the edge and it's a stroke penalty.
## Pure fun, no tokens: you made it this far. Counts strokes against par and
## remembers your best round.

const VIEW_AT := Vector2(0, 200)
const VIEW := Vector2(720, 840)
const BALL_R := 0.07
const CUP_R := 0.13
const HOLE_GAP := 9.0
const TURN := 1.6
const HOLES := [
	{"name": "THE MUG", "par": 2, "tee": Vector3(0, 0, 2.0), "cup": Vector3(0, 0, -2.0)},
	{"name": "THE BOOK RAMP", "par": 3, "tee": Vector3(0, 0, 2.0), "cup": Vector3(0, 0.15, -1.8)},
	{"name": "THE IN-TRAY", "par": 3, "tee": Vector3(0, 0, 2.0), "cup": Vector3(-2.0, 0, -1.3)},
]

var _view
var _ball: RigidBody3D
var _hole := 0
var _angle := 0.0
var _turn := 0.0
var _t := 0.0
var _strokes := 0
var _round := 0
var _best := 0
var _rolling := false
var _rest_t := 0.0
var _last_rest := Vector3.ZERO
var _sunk := false
var _dots: Array[MeshInstance3D] = []
var _flags: Array[Node3D] = []
var _info: Label
var _bar: ColorRect
var _bar_fill: ColorRect
var _putt: Button
var _felt: ShaderMaterial
var _rail: ShaderMaterial


func _ready() -> void:
	super._ready()
	frame("CORNER LINKS", Color(0.1, 0.05, 0.03), Color(1.0, 0.75, 0.4))
	_top.text = "THE BOSS'S DESK"
	_view = preload("res://scenes/ladder/view3d.gd").new()
	add_child(_view)
	_view.setup(VIEW_AT, VIEW, 3, {
		"sky": Color(0.95, 0.55, 0.32), "ambient": Color(0.32, 0.27, 0.38),
		"sun_dir": Vector3(-0.8, 0.5, -0.35), "sun_col": Color(1.0, 0.72, 0.42),
		"fog_col": Color(0.95, 0.55, 0.32), "fog_near": 5.0, "fog_far": 16.0,
		"grain": 0.04, "vignette": 0.45, "scan": 0.04, "tint": Color(1.0, 0.6, 0.2, 0.04),
	})
	_view.add_post(self)
	_view.cam.fov = 55.0
	_felt = _view.mat(Color(0.2, 0.55, 0.22), {"pattern": 2, "col2": Color(0.24, 0.62, 0.26), "texel": 3.0})
	_rail = _view.mat(Color(0.45, 0.2, 0.1), {"shine": 0.8})
	_build_desk()
	for i in HOLES.size():
		_build_hole(i)
	_ball = RigidBody3D.new()
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = BALL_R
	shape.shape = s
	_ball.add_child(shape)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.4
	pm.friction = 0.6
	_ball.physics_material_override = pm
	_ball.mass = 0.05
	_ball.linear_damp = 0.4
	_ball.angular_damp = 1.5
	_ball.continuous_cd = true
	_ball.can_sleep = false
	_view.ball(BALL_R, Vector3.ZERO, _view.mat(Color(0.97, 0.97, 0.95), {"shine": 1.2}), _ball, 8)
	_view.root.add_child(_ball)
	var dot: ShaderMaterial = _view.glow(Color(1.0, 0.95, 0.75))
	for i in 8:
		_dots.append(_view.ball(0.025, Vector3.ZERO, dot, null, 4))
	_info = label("", 22, Color(1.0, 0.92, 0.55))
	_info.position = Vector2(0, 150)
	_info.size = Vector2(W, 40)
	add_child(_info)
	_bar = ColorRect.new()
	_bar.color = Color(0.15, 0.08, 0.04)
	_bar.position = Vector2(60, 1048)
	_bar.size = Vector2(W - 120, 20)
	add_child(_bar)
	_bar_fill = ColorRect.new()
	_bar_fill.size = Vector2(0, 20)
	_bar.add_child(_bar_fill)
	var row := HBoxContainer.new()
	row.position = Vector2(30, 1086)
	row.size = Vector2(W - 60, 150)
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	var left := button("<", 48, Color(0.3, 0.15, 0.08), Color(1.0, 0.85, 0.6))
	_putt = button("PUTT", 40, Color(0.15, 0.4, 0.12), Color(1.0, 0.85, 0.6))
	var right := button(">", 48, Color(0.3, 0.15, 0.08), Color(1.0, 0.85, 0.6))
	for b in [left, _putt, right]:
		b.custom_minimum_size = Vector2(0, 140)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_putt.size_flags_stretch_ratio = 1.6
	left.button_down.connect(func(): _turn = 1.0)
	right.button_down.connect(func(): _turn = -1.0)
	left.button_up.connect(func(): _turn = 0.0)
	right.button_up.connect(func(): _turn = 0.0)
	left.pressed.connect(func(): _angle += 0.05)
	right.pressed.connect(func(): _angle -= 0.05)
	_putt.pressed.connect(_on_putt)
	_putt.set_meta("pad_default", true)
	_start_hole(0)


func refresh_top() -> void:
	pass


# ---------------------------------------------------------------- building

func _origin(i: int) -> Vector3:
	return Vector3(i * HOLE_GAP, 0, 0)


func _build_desk() -> void:
	var v = _view
	var wood: ShaderMaterial = v.mat(Color(0.36, 0.17, 0.08), {"pattern": 2, "col2": Color(0.3, 0.13, 0.06), "texel": 2.5, "shine": 0.5})
	var span := HOLE_GAP * (HOLES.size() - 1)
	v.box(Vector3(span + 12.0, 0.4, 10.0), Vector3(span * 0.5, -0.45, 0), wood)
	# Desk things the size of buildings: a mug, a pencil, the nameplate,
	# a stack of reports.
	var white: ShaderMaterial = v.mat(Color(0.95, 0.93, 0.88), {"shine": 0.8})
	v.cyl(0.6, 0.55, 1.4, Vector3(1.9, 0.45, -1.2), white)
	v.text("#1\nBOSS", Vector3(1.9, 0.55, -0.59), 40, Color(0.2, 0.1, 0.05), null, Vector3.ZERO, 0.007)
	v.cyl(0.08, 0.08, 4.0, Vector3(5.0, -0.17, 2.0), v.mat(Color(1.0, 0.75, 0.15)), null, Vector3(PI / 2, 0.6, 0), 6)
	var plate: MeshInstance3D = v.box(Vector3(2.2, 0.4, 0.2), Vector3(HOLE_GAP + 2.0, -0.05, 2.6), v.mat(Color(0.75, 0.6, 0.25), {"shine": 1.8}), null, Vector3(-0.3, -0.3, 0))
	v.text("THE BOSS", Vector3(0, 0, 0.105), 40, Color(0.2, 0.12, 0.04), plate, Vector3.ZERO, 0.008)
	for k in 4:
		v.box(Vector3(1.4, 0.12, 1.0), Vector3(HOLE_GAP * 2 + 1.6, -0.19 + k * 0.13, 1.4), v.mat(Color(0.9, 0.88, 0.8) if k % 2 == 0 else Color(0.7, 0.8, 0.95)), null, Vector3(0, k * 0.12, 0))


func _floor(o: Vector3, dims: Vector3, at: Vector3, rot := Vector3.ZERO) -> void:
	_view.solid(dims, o + at, _felt, null, rot, 0.1, 0.9)


## A rail from a to b (x/z on the hole), axis-aligned.
func _wall(o: Vector3, a: Vector2, b: Vector2, h := 0.16, base := 0.0) -> void:
	var mid := (a + b) * 0.5
	var dims := Vector3(maxf(absf(b.x - a.x), 0.1), h, maxf(absf(b.y - a.y), 0.1))
	_view.solid(dims, o + Vector3(mid.x, base + h * 0.5 - 0.02, mid.y), _rail, null, Vector3.ZERO, 0.7, 0.3)


func _build_hole(i: int) -> void:
	var o := _origin(i)
	var v = _view
	match i:
		0:
			_floor(o, Vector3(1.6, 0.1, 5.2), Vector3(0, -0.05, 0))
			_wall(o, Vector2(-0.85, -2.65), Vector2(-0.85, 2.65))
			_wall(o, Vector2(0.85, -2.65), Vector2(0.85, 2.65))
			_wall(o, Vector2(-0.85, -2.65), Vector2(0.85, -2.65))
			_wall(o, Vector2(-0.85, 2.65), Vector2(0.85, 2.65))
			# The desk lamp's heavy base, right in the way.
			var lamp := StaticBody3D.new()
			lamp.position = o + Vector3(0.15, 0, -0.1)
			var shape := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = 0.3
			cy.height = 0.3
			shape.shape = cy
			shape.position.y = 0.15
			lamp.add_child(shape)
			var pm := PhysicsMaterial.new()
			pm.bounce = 0.6
			lamp.physics_material_override = pm
			var brass: ShaderMaterial = v.mat(Color(0.8, 0.6, 0.25), {"shine": 1.8})
			v.cyl(0.26, 0.3, 0.3, Vector3(0, 0.15, 0), brass, lamp, Vector3.ZERO, 12)
			v.cyl(0.03, 0.03, 1.4, Vector3(0, 0.95, 0), brass, lamp, Vector3.ZERO, 6)
			v.cyl(0.12, 0.3, 0.3, Vector3(0, 1.65, 0), v.mat(Color(0.1, 0.35, 0.15), {"shine": 1.0}), lamp)
			v.root.add_child(lamp)
		1:
			# Lower green, a ramp, then the cup up on a fat book.
			_floor(o, Vector3(1.6, 0.1, 2.0), Vector3(0, -0.05, 1.6))
			_floor(o, Vector3(1.6, 0.1, 0.92), Vector3(0, 0.025, 0.15), Vector3(atan2(0.15, 0.9), 0, 0))
			v.solid(Vector3(1.6, 0.25, 2.3), o + Vector3(0, 0.025, -1.45), v.mat(Color(0.55, 0.12, 0.1), {"pattern": 2, "col2": Color(0.9, 0.85, 0.7), "texel": 9.0}))
			_floor(o, Vector3(1.6, 0.04, 2.3), Vector3(0, 0.132, -1.45))
			v.text("Q3 REPORT", Vector3(0, 0.02, -0.29), 30, Color(1.0, 0.85, 0.4), null, Vector3.ZERO, 0.006).position += o
			_wall(o, Vector2(-0.85, -2.65), Vector2(-0.85, 2.65), 0.45)
			_wall(o, Vector2(0.85, -2.65), Vector2(0.85, 2.65), 0.45)
			_wall(o, Vector2(-0.85, -2.65), Vector2(0.85, -2.65), 0.45)
			_wall(o, Vector2(-0.85, 2.65), Vector2(0.85, 2.65), 0.2)
		2:
			# An L: up the right side, then left along the top past a stapler.
			_floor(o, Vector3(1.6, 0.1, 3.1), Vector3(0, -0.05, 1.05))
			_floor(o, Vector3(3.4, 0.1, 1.6), Vector3(-0.9, -0.05, -1.3))
			_wall(o, Vector2(0.85, -2.15), Vector2(0.85, 2.65))
			_wall(o, Vector2(-0.85, -0.45), Vector2(-0.85, 2.65))
			_wall(o, Vector2(-0.85, 2.65), Vector2(0.85, 2.65))
			_wall(o, Vector2(-2.65, -2.15), Vector2(0.85, -2.15))
			_wall(o, Vector2(-2.65, -0.45), Vector2(-0.85, -0.45))
			_wall(o, Vector2(-2.65, -2.15), Vector2(-2.65, -0.45))
			var stapler: StaticBody3D = v.solid(Vector3(0.6, 0.2, 0.18), o + Vector3(-1.1, 0.1, -1.55), v.mat(Color(0.75, 0.1, 0.1), {"shine": 1.2}), null, Vector3(0, 0.5, 0), 0.9)
			v.box(Vector3(0.62, 0.05, 0.2), Vector3(0, 0.12, 0), v.mat(Color(0.7, 0.7, 0.75), {"shine": 1.5}), stapler)
	# The cup and its flag.
	var hole: Dictionary = HOLES[i]
	var cup: Vector3 = o + hole.cup
	v.cyl(CUP_R + 0.03, CUP_R + 0.03, 0.004, cup + Vector3(0, 0.002, 0), v.mat(Color(0.95, 0.95, 0.9)), null, Vector3.ZERO, 14)
	v.cyl(CUP_R, CUP_R, 0.006, cup + Vector3(0, 0.004, 0), v.mat(Color(0.03, 0.02, 0.02)), null, Vector3.ZERO, 14)
	var flag := Node3D.new()
	flag.position = cup
	v.root.add_child(flag)
	v.cyl(0.012, 0.012, 1.0, Vector3(0, 0.5, 0), v.mat(Color(0.9, 0.9, 0.85), {"shine": 1.0}), flag, Vector3.ZERO, 4)
	v.box(Vector3(0.02, 0.22, 0.34), Vector3(0, 0.88, 0.17), v.mat(Color(0.9, 0.12, 0.1), {"glow": Color(0.3, 0.02, 0.0)}), flag)
	_flags.append(flag)
	v.text("%d" % (i + 1), Vector3(0.012, 0.88, 0.17), 40, Color(1, 1, 1), flag, Vector3(0, PI / 2, 0), 0.005)
	# Tee marker.
	v.cyl(0.1, 0.1, 0.006, o + hole.tee + Vector3(0, 0.003, 0), v.glow(Color(1.0, 0.85, 0.3) * 0.6), null, Vector3.ZERO, 8)


# ---------------------------------------------------------------- playing

func _start_hole(i: int) -> void:
	_hole = i
	if i == 0:
		_round = 0
	_strokes = 0
	_sunk = false
	_angle = 0.0
	var hole: Dictionary = HOLES[i]
	_place_ball(_origin(i) + hole.tee + Vector3(0, BALL_R + 0.02, 0))
	_last_rest = _ball.position
	_update()


func _place_ball(at: Vector3) -> void:
	_ball.freeze = false
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	var t := Transform3D(Basis(), at)
	_ball.global_transform = t
	PhysicsServer3D.body_set_state(_ball.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	_rolling = false


func _power() -> float:
	return 0.5 - 0.5 * cos(_t * 3.0)


func _dir() -> Vector3:
	return Vector3(-sin(_angle), 0, -cos(_angle))


func _on_putt() -> void:
	if _rolling:
		return
	if _sunk:
		_start_hole(0 if _hole == HOLES.size() - 1 else _hole + 1)
		return
	_ball.linear_velocity = _dir() * (0.5 + 5.0 * _power())
	_strokes += 1
	_round += 1
	_rolling = true
	_rest_t = 0.0
	sfx("click")
	_update()


func _process(delta: float) -> void:
	super._process(delta)
	var cam: Camera3D = _view.cam
	var at := _ball.position
	if not _rolling and not _sunk:
		_t += delta
		_angle += _turn * TURN * delta
		var p := _power()
		_bar_fill.size.x = _bar.size.x * p
		_bar_fill.color = Color(1.0, 0.85 - 0.5 * p, 0.25)
		for i in _dots.size():
			_dots[i].visible = true
			_dots[i].position = at + _dir() * (0.15 + i * (0.08 + 0.22 * p)) + Vector3(0, -BALL_R + 0.03, 0)
	else:
		for d in _dots:
			d.visible = false
	if _rolling:
		_check_ball(delta)
	# Behind the ball, looking down the aim.
	var want := at - _dir() * 1.7 + Vector3(0, 1.0, 0)
	cam.position = cam.position.lerp(want, minf(1.0, delta * (2.5 if _rolling else 6.0)))
	cam.look_at(at + _dir() * 1.0 + Vector3(0, -0.1, 0))
	for f in _flags:
		f.rotation.y = sin(_t * 0.8 + f.position.x) * 0.15


func _check_ball(delta: float) -> void:
	var hole: Dictionary = HOLES[_hole]
	var cup: Vector3 = _origin(_hole) + hole.cup
	var p := _ball.position
	var speed := _ball.linear_velocity.length()
	var flat := Vector2(p.x - cup.x, p.z - cup.z).length()
	if flat < CUP_R and absf(p.y - BALL_R - cup.y) < 0.08 and speed < 3.0:
		_sink(cup)
		return
	if p.y < -1.0:
		_strokes += 1
		_round += 1
		_place_ball(_last_rest)
		banner("OFF THE DESK!\n+1 STROKE", 1.6, Color(1.0, 0.6, 0.4))
		sfx("groan", -6.0)
		_update()
		return
	_rest_t = _rest_t + delta if speed < 0.08 else 0.0
	if _rest_t > 0.35:
		_ball.linear_velocity = Vector3.ZERO
		_ball.angular_velocity = Vector3.ZERO
		_rolling = false
		_last_rest = p
		# Aim at the cup again, roughly: you still have to line it up.
		_update()


func _sink(cup: Vector3) -> void:
	_rolling = false
	_sunk = true
	_ball.freeze = true
	var t := create_tween()
	t.tween_property(_ball, "position", cup + Vector3(0, BALL_R * 0.3, 0), 0.12)
	t.tween_property(_ball, "position", cup + Vector3(0, -0.2, 0), 0.2)
	var par: int = HOLES[_hole].par
	var call := "HOLE IN ONE!" if _strokes == 1 else ("BIRDIE!" if _strokes == par - 1 else ("PAR" if _strokes == par else "IN!  %d STROKES" % _strokes))
	sfx("jackpot" if _strokes == 1 else "ding")
	if _hole == HOLES.size() - 1:
		var total_par := 0
		for h in HOLES:
			total_par += h.par
		if _best == 0 or _round < _best:
			_best = _round
		banner("%s\nROUND: %d (PAR %d)" % [call, _round, total_par], 3.0)
	else:
		banner(call, 2.0)
	_update()


func _update() -> void:
	var hole: Dictionary = HOLES[_hole]
	_info.text = "HOLE %d: %s  PAR %d\nSTROKES %d   ROUND %d   BEST %s" % [_hole + 1, hole.name, hole.par, _strokes, _round, str(_best) if _best > 0 else "-"]
	if _sunk:
		_putt.text = "AGAIN" if _hole == HOLES.size() - 1 else "NEXT HOLE"
	else:
		_putt.text = "PUTT"
