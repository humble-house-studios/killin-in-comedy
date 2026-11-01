extends "res://scenes/ladder/machine.gd"
## FALL GUY: Bernie's stress-relief cabinet. A Dale-shaped dummy (glasses,
## purple tie, legally not Dale) on a slingshot, with real 2D ragdoll physics.
## Set the angle, time the power meter, FLING (1 token). Points for distance,
## for every crash into the office furniture and for each full spin (double
## with Bernie's style perk). Tickets = points / 20; 900 beats the machine.

const VIEW := Vector2(720, 860)
const GROUND := 700.0
const COURSE := 4200.0
const START := Vector2(150, 500)
const POWER := 2300.0

var _vp: SubViewport
var _cam: Camera2D
var _world: Node2D
var _parts: Array[RigidBody2D] = []
var _torso: RigidBody2D
var _head: RigidBody2D
var _angle := 0.75
var _power_t := 0.0
var _flying := false
var _still := 0.0
var _fly_t := 0.0
var _impacts := 0.0
var _spin := 0.0
var _last_rot := 0.0
var _last_v := Vector2.ZERO
var _best_x := 0.0
var _score_lbl: Label
var _live: Label
var _fling: Button
var _lower: Button
var _raise: Button
var _aim: Node2D


func _ready() -> void:
	super._ready()
	frame("FALL GUY", Color(0.12, 0.06, 0.04), Color(1.0, 0.6, 0.25))
	var box := SubViewportContainer.new()
	box.stretch = true
	box.position = Vector2(0, 160)
	box.size = VIEW
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_vp = SubViewport.new()
	_vp.size = Vector2i(VIEW)
	_vp.disable_3d = true
	_vp.handle_input_locally = false
	box.add_child(_vp)
	_cam = Camera2D.new()
	_vp.add_child(_cam)
	_world = Node2D.new()
	_vp.add_child(_world)
	_build_course()
	_aim = Node2D.new()
	_aim.draw.connect(_draw_aim)
	_vp.add_child(_aim)
	_live = label("", 26, Color(1.0, 0.92, 0.55))
	_live.position = Vector2(0, 170)
	_live.size = Vector2(W, 40)
	add_child(_live)
	_score_lbl = label("", 24, Color(1, 1, 1, 0.7))
	_score_lbl.position = Vector2(0, 980)
	_score_lbl.size = Vector2(W, 60)
	add_child(_score_lbl)
	var row := HBoxContainer.new()
	row.position = Vector2(30, 1060)
	row.size = Vector2(W - 60, 150)
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	_lower = button("ANGLE\n-", 26)
	_fling = button("FLING!", 40, Color(0.6, 0.25, 0.05))
	_raise = button("ANGLE\n+", 26)
	for b in [_lower, _fling, _raise]:
		b.custom_minimum_size = Vector2(0, 140)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_fling.size_flags_stretch_ratio = 1.6
	_lower.pressed.connect(func(): _angle = clampf(_angle - 0.12, 0.15, 1.35))
	_raise.pressed.connect(func(): _angle = clampf(_angle + 0.12, 0.15, 1.35))
	_fling.pressed.connect(_on_fling)
	_fling.set_meta("pad_default", true)
	_reset_dummy()
	_score_lbl.text = "TIME THE POWER BAR. SPIN = POINTS."


func _static(points: PackedVector2Array, bounce := 0.1, color := Color(0.45, 0.4, 0.38)) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	body.add_child(shape)
	var mat := PhysicsMaterial.new()
	mat.bounce = bounce
	mat.friction = 0.7
	body.physics_material_override = mat
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	body.add_child(poly)
	_world.add_child(body)


func _build_course() -> void:
	var sky := Polygon2D.new()
	sky.polygon = PackedVector2Array([Vector2(-400, -1600), Vector2(COURSE + 600, -1600), Vector2(COURSE + 600, GROUND), Vector2(-400, GROUND)])
	sky.color = Color(0.2, 0.12, 0.08)
	_world.add_child(sky)
	# Floor (carpet), the launch desk, and a wall at the far end.
	_static(PackedVector2Array([Vector2(-400, GROUND), Vector2(COURSE + 600, GROUND), Vector2(COURSE + 600, GROUND + 400), Vector2(-400, GROUND + 400)]), 0.15, Color(0.35, 0.42, 0.38))
	_static(PackedVector2Array([Vector2(40, 610), Vector2(260, 610), Vector2(260, GROUND), Vector2(40, GROUND)]), 0.1, Color(0.6, 0.45, 0.3))
	_static(PackedVector2Array([Vector2(COURSE, -800), Vector2(COURSE + 80, -800), Vector2(COURSE + 80, GROUND), Vector2(COURSE, GROUND)]), 0.3, Color(0.85, 0.8, 0.65))
	# Furniture: filing cabinets, a ramp, the stairwell, bouncy office chairs.
	for x in [700.0, 1650.0, 2900.0]:
		_static(PackedVector2Array([Vector2(x, GROUND - 160), Vector2(x + 90, GROUND - 160), Vector2(x + 90, GROUND), Vector2(x, GROUND)]), 0.2, Color(0.55, 0.57, 0.58))
	_static(PackedVector2Array([Vector2(1100, GROUND), Vector2(1400, GROUND - 120), Vector2(1400, GROUND)]), 0.1, Color(0.6, 0.45, 0.3))
	for i in 5:
		var sx := 2100.0 + i * 70.0
		_static(PackedVector2Array([Vector2(sx, GROUND - 60 * (5 - i)), Vector2(sx + 70, GROUND - 60 * (5 - i)), Vector2(sx + 70, GROUND), Vector2(sx, GROUND)]), 0.1, Color(0.7, 0.66, 0.55))
	for x in [1000.0, 2600.0, 3500.0]:
		var pts := PackedVector2Array()
		for i in 12:
			var a := PI + i * PI / 11.0
			pts.append(Vector2(x, GROUND) + Vector2(cos(a), sin(a) * 0.6) * 70.0)
		_static(pts, 1.15, Color(0.3, 0.45, 0.66))
	# A water cooler and a few boxes to knock over.
	for spot in [[Vector2(1900, GROUND - 60), Vector2(50, 120)], [Vector2(3200, GROUND - 40), Vector2(80, 80)], [Vector2(3280, GROUND - 40), Vector2(80, 80)], [Vector2(3240, GROUND - 120), Vector2(80, 80)]]:
		var b := RigidBody2D.new()
		b.position = spot[0]
		var s := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = spot[1]
		s.shape = r
		b.add_child(s)
		var p := Polygon2D.new()
		var hs: Vector2 = spot[1] * 0.5
		p.polygon = PackedVector2Array([-hs, Vector2(hs.x, -hs.y), hs, Vector2(-hs.x, hs.y)])
		p.color = Color(0.75, 0.6, 0.4)
		b.add_child(p)
		b.mass = 0.6
		_world.add_child(b)
	for i in 8:
		var l := Label.new()
		l.text = "%dm" % ((i + 1) * 5)
		l.add_theme_font_override("font", FONT)
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		l.position = Vector2(START.x + (i + 1) * 500 - 30, GROUND + 20)
		_world.add_child(l)


func _part(at: Vector2, size: Vector2, color: Color, round_part := false) -> RigidBody2D:
	var b := RigidBody2D.new()
	b.position = at
	var shape := CollisionShape2D.new()
	if round_part:
		var c := CircleShape2D.new()
		c.radius = size.x
		shape.shape = c
	else:
		var r := RectangleShape2D.new()
		r.size = size
		shape.shape = r
	b.add_child(shape)
	var mat := PhysicsMaterial.new()
	mat.friction = 0.6
	mat.bounce = 0.25
	b.physics_material_override = mat
	b.mass = 1.0
	b.angular_damp = 0.4
	b.set_meta("size", size)
	b.set_meta("color", color)
	b.set_meta("round", round_part)
	b.draw.connect(_draw_part.bind(b))
	_world.add_child(b)
	_parts.append(b)
	return b


func _pin(a: RigidBody2D, b: RigidBody2D, at: Vector2) -> void:
	var j := PinJoint2D.new()
	j.position = at
	j.softness = 0.2
	_world.add_child(j)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)


func _reset_dummy() -> void:
	for p in _parts:
		p.queue_free()
	for c in _world.get_children():
		if c is PinJoint2D:
			c.queue_free()
	_parts.clear()
	var o := START
	var shirt := Color(0.86, 0.84, 0.66)
	var skin := Color(0.93, 0.72, 0.58)
	var pants := Color(0.22, 0.24, 0.3)
	_torso = _part(o, Vector2(46, 70), shirt)
	_torso.mass = 2.0
	_head = _part(o + Vector2(0, -58), Vector2(22, 22), skin, true)
	var arm_l := _part(o + Vector2(-34, -10), Vector2(16, 52), shirt)
	var arm_r := _part(o + Vector2(34, -10), Vector2(16, 52), shirt)
	var leg_l := _part(o + Vector2(-12, 62), Vector2(18, 58), pants)
	var leg_r := _part(o + Vector2(12, 62), Vector2(18, 58), pants)
	_pin(_torso, _head, o + Vector2(0, -38))
	_pin(_torso, arm_l, o + Vector2(-28, -30))
	_pin(_torso, arm_r, o + Vector2(28, -30))
	_pin(_torso, leg_l, o + Vector2(-12, 34))
	_pin(_torso, leg_r, o + Vector2(12, 34))
	for a in _parts:
		for b in _parts:
			if a != b:
				a.add_collision_exception_with(b)
		a.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		a.freeze = true
	_flying = false
	_cam.position = Vector2(VIEW.x * 0.5, GROUND - VIEW.y * 0.5 + 120)


func _draw_part(b: RigidBody2D) -> void:
	var s: Vector2 = b.get_meta("size")
	var c: Color = b.get_meta("color")
	if b.get_meta("round"):
		b.draw_circle(Vector2.ZERO, s.x, c)
		if b == _head:
			# Glasses, the moustache and a horseshoe of hair.
			b.draw_rect(Rect2(-14, -6, 11, 8), Color(0.08, 0.08, 0.1), false, 2.0)
			b.draw_rect(Rect2(3, -6, 11, 8), Color(0.08, 0.08, 0.1), false, 2.0)
			b.draw_rect(Rect2(-8, 6, 16, 3), Color(0.36, 0.24, 0.15))
			b.draw_arc(Vector2.ZERO, s.x, PI * 0.15, PI * 0.85, 8, Color(0.36, 0.24, 0.15), 4.0)
		return
	b.draw_rect(Rect2(-s * 0.5, s), c)
	if b == _torso:
		b.draw_rect(Rect2(-5, -s.y * 0.5 + 4, 10, s.y * 0.7), Color(0.62, 0.12, 0.42))


func _on_fling() -> void:
	if _flying:
		return
	if not pay_token():
		return
	var power := _power()
	var dir := Vector2(cos(_angle), -sin(_angle))
	for p in _parts:
		p.freeze = false
		p.linear_velocity = dir * POWER * (0.35 + 0.65 * power)
		p.angular_velocity = 0.0
	_torso.angular_velocity = -14.0 * power
	_flying = true
	_still = 0.0
	_fly_t = 0.0
	_impacts = 0.0
	_spin = 0.0
	_last_rot = _torso.rotation
	_last_v = _torso.linear_velocity
	_best_x = _torso.position.x
	_fling.disabled = true
	sfx("thump")


func _power() -> float:
	return 0.5 - 0.5 * cos(_power_t * 3.4)


func _physics_process(delta: float) -> void:
	if not _flying:
		return
	_fly_t += delta
	var v := _torso.linear_velocity
	var dv := (v - _last_v).length()
	if dv > 260.0:
		_impacts += (dv - 260.0) * 0.18
	_last_v = v
	var r := _torso.rotation
	_spin += wrapf(r - _last_rot, -PI, PI)
	_last_rot = r
	_best_x = maxf(_best_x, _torso.position.x)
	_still = _still + delta if v.length() < 25.0 else 0.0
	if _still > 1.0 or _fly_t > 9.0:
		_land()


func _distance() -> float:
	return maxf(0.0, (_best_x - START.x) / 100.0)


func _spins() -> int:
	return int(absf(_spin) / TAU)


func _land() -> void:
	_flying = false
	var style: bool = hub != null and hub.state.has("style")
	var score := ArcadeRules.ragdoll_score(_distance(), _impacts, _spins(), style)
	var tickets := ArcadeRules.ragdoll_tickets(score)
	var beats := score >= ArcadeRules.RAGDOLL_BEAT
	win(tickets, "ragdoll", beats)
	sfx("jackpot" if beats else ("ding" if tickets > 20 else "groan"))
	banner("%d POINTS\n+%d TICKETS%s" % [score, tickets, "\nMACHINE BEATEN!" if beats else ""], 3.0)
	_score_lbl.text = "%.1fm  CRASHES %d  SPINS %d%s" % [_distance(), int(_impacts), _spins(), " x2" if style else ""]
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_callback(func():
		_reset_dummy()
		_fling.disabled = false)


func _process(delta: float) -> void:
	super._process(delta)
	if not _flying:
		_power_t += delta
		_live.text = "POWER %d%%   ANGLE %d" % [roundi(_power() * 100), roundi(rad_to_deg(_angle))]
	else:
		var style: bool = hub != null and hub.state.has("style")
		_live.text = "%d POINTS" % ArcadeRules.ragdoll_score(_distance(), _impacts, _spins(), style)
		var target := Vector2(clampf(_torso.position.x + 120, VIEW.x * 0.5, COURSE + 80 - VIEW.x * 0.5), clampf(_torso.position.y, -600, GROUND - VIEW.y * 0.5 + 120))
		_cam.position = _cam.position.lerp(target, minf(1.0, delta * 6.0))
	_aim.queue_redraw()


func _draw_aim() -> void:
	if _flying or _torso == null:
		return
	var dir := Vector2(cos(_angle), -sin(_angle))
	var len := 60.0 + 140.0 * _power()
	for i in 8:
		var p := START + dir * (40.0 + i * len / 8.0)
		_aim.draw_circle(p, 6.0, Color(1.0, 0.85, 0.3, 0.9 - i * 0.08))
	_aim.draw_rect(Rect2(START.x - 70, START.y + 110, 140, 16), Color(0.2, 0.1, 0.05))
	_aim.draw_rect(Rect2(START.x - 70, START.y + 110, 140 * _power(), 16), Color(1.0, 0.5 + 0.5 * _power(), 0.2))
