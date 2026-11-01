extends "res://scenes/ladder/machine.gd"
## CLAW KING: a side-on claw machine with real 2D physics. Steer the claw
## with the arrows, DROP (1 token), and it grabs whatever is under it. Every
## fourth grab is full strength (ArcadeRules.CLAW_STRONG_EVERY); weaker grabs
## slip the prize partway up. Drop a prize down the chute (bottom left) for
## tickets. The TOP-SHELF STAR beats the machine. Gloria's Eye (her perk)
## shows when the claw is at full strength.

const BOX := Rect2(40, 200, 640, 800)
const CHUTE_W := 150.0
const RAIL_Y := 230.0
const FLOOR_Y := 960.0
const SPEED := 260.0
const DROP_SPEED := 420.0
const GRAB_REACH := 70.0
const KEEP := 13
const STAR_KEEP := 2

enum S { IDLE, DROP, CLOSE, RISE, CARRY, OPEN }

var _state := S.IDLE
var _claw := Vector2(400, RAIL_Y + 40)
var _dir := 0.0
var _held: RigidBody2D
var _strong := false
var _grabs := 0
var _close_t := 0.0
var _rise_from := 0.0
var _prizes: Array[RigidBody2D] = []
var _world: Node2D
var _fg: Node2D
var _grip: Label
var _left: Button
var _right: Button
var _drop: Button
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_rng.randomize()
	frame("CLAW KING", Color(0.08, 0.04, 0.14), Color(1.0, 0.4, 0.75))
	_world = Node2D.new()
	add_child(_world)
	_fg = Node2D.new()
	_fg.draw.connect(_draw_claw)
	add_child(_fg)
	_walls()
	for i in KEEP:
		_spawn(_kind_for(i), Vector2(_rng.randf_range(CHUTE_W + 120, BOX.end.x - 60), _rng.randf_range(600, 900)))
	_grip = label("", 22, Color(0.6, 1.0, 0.7))
	_grip.position = Vector2(0, 156)
	_grip.size = Vector2(W, 34)
	add_child(_grip)
	var hint := label("CHUTE", 18, Color(1, 1, 1, 0.6))
	hint.position = Vector2(BOX.position.x, FLOOR_Y + 10)
	hint.size = Vector2(CHUTE_W, 30)
	add_child(hint)
	var row := HBoxContainer.new()
	row.position = Vector2(30, 1060)
	row.size = Vector2(W - 60, 150)
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	_left = button("<", 48)
	_drop = button("DROP", 40, Color(0.55, 0.1, 0.3))
	_right = button(">", 48)
	for b in [_left, _drop, _right]:
		b.custom_minimum_size = Vector2(0, 140)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_drop.size_flags_stretch_ratio = 1.6
	_left.button_down.connect(func(): _dir = -1.0)
	_right.button_down.connect(func(): _dir = 1.0)
	_left.button_up.connect(func(): _dir = 0.0)
	_right.button_up.connect(func(): _dir = 0.0)
	_left.pressed.connect(func(): _nudge(-40.0))
	_right.pressed.connect(func(): _nudge(40.0))
	_drop.pressed.connect(_on_drop)
	_drop.set_meta("pad_default", true)
	_update_grip()


func _kind_for(i: int) -> String:
	if i < STAR_KEEP:
		return "star"
	return "bear" if i % 3 == 0 else "duck"


func _walls() -> void:
	var body := StaticBody2D.new()
	_world.add_child(body)
	var segs := [
		[Vector2(BOX.position.x + CHUTE_W, FLOOR_Y), Vector2(BOX.end.x, FLOOR_Y)],
		[Vector2(BOX.position.x, BOX.position.y), Vector2(BOX.position.x, BOX.end.y + 200)],
		[Vector2(BOX.end.x, BOX.position.y), Vector2(BOX.end.x, FLOOR_Y)],
		# The chute's wall: a low lip so prizes don't roll in by themselves.
		[Vector2(BOX.position.x + CHUTE_W, FLOOR_Y), Vector2(BOX.position.x + CHUTE_W, FLOOR_Y - 110)],
	]
	for s in segs:
		var shape := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = s[0]
		seg.b = s[1]
		shape.shape = seg
		body.add_child(shape)


func _spawn(kind: String, at: Vector2) -> void:
	var b := RigidBody2D.new()
	b.position = at
	b.set_meta("kind", kind)
	var r := 34.0 if kind == "duck" else (44.0 if kind == "bear" else 40.0)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = r
	shape.shape = circle
	b.add_child(shape)
	var mat := PhysicsMaterial.new()
	mat.friction = 0.9
	mat.bounce = 0.05
	b.physics_material_override = mat
	b.mass = 1.0
	b.angular_damp = 2.0
	b.set_meta("r", r)
	b.draw.connect(_draw_prize.bind(b))
	_world.add_child(b)
	_prizes.append(b)


func _draw_prize(b: RigidBody2D) -> void:
	var r: float = b.get_meta("r")
	match b.get_meta("kind"):
		"duck":
			b.draw_circle(Vector2.ZERO, r, Color(1.0, 0.85, 0.2))
			b.draw_circle(Vector2(r * 0.35, -r * 0.3), r * 0.14, Color.BLACK)
			b.draw_rect(Rect2(r * 0.6, -r * 0.1, r * 0.55, r * 0.3), Color(1.0, 0.5, 0.1))
		"bear":
			b.draw_circle(Vector2(-r * 0.6, -r * 0.75), r * 0.35, Color(0.55, 0.33, 0.18))
			b.draw_circle(Vector2(r * 0.6, -r * 0.75), r * 0.35, Color(0.55, 0.33, 0.18))
			b.draw_circle(Vector2.ZERO, r, Color(0.62, 0.4, 0.22))
			b.draw_circle(Vector2(0, r * 0.25), r * 0.38, Color(0.85, 0.7, 0.5))
			b.draw_circle(Vector2(-r * 0.3, -r * 0.15), r * 0.1, Color.BLACK)
			b.draw_circle(Vector2(r * 0.3, -r * 0.15), r * 0.1, Color.BLACK)
		_:
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + i * TAU / 10.0
				var rr := r * (1.0 if i % 2 == 0 else 0.45)
				pts.append(Vector2(cos(a), sin(a)) * rr)
			b.draw_colored_polygon(pts, Color(1.0, 0.82, 0.15))
			b.draw_circle(Vector2.ZERO, r * 0.2, Color(1.0, 1.0, 0.7))


func _nudge(dx: float) -> void:
	if _state == S.IDLE:
		_claw.x = clampf(_claw.x + dx, BOX.position.x + 50, BOX.end.x - 50)


func _on_drop() -> void:
	if _state != S.IDLE:
		return
	if not pay_token():
		return
	_strong = ArcadeRules.claw_strong(_grabs)
	_grabs += 1
	_state = S.DROP
	_dir = 0.0
	sfx("click")


func _process(delta: float) -> void:
	super._process(delta)
	match _state:
		S.IDLE:
			_claw.x = clampf(_claw.x + _dir * SPEED * delta, BOX.position.x + 50, BOX.end.x - 50)
		S.DROP:
			_claw.y += DROP_SPEED * delta
			if _claw.y >= FLOOR_Y - 40 or _touching():
				_state = S.CLOSE
				_close_t = 0.0
		S.CLOSE:
			_close_t += delta
			if _close_t > 0.35:
				_held = _nearest()
				if _held:
					_held.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
					_held.freeze = true
					sfx("thump", -4.0)
				_rise_from = _claw.y
				_state = S.RISE
		S.RISE:
			_claw.y -= DROP_SPEED * 0.6 * delta
			if _held and not _strong and _claw.y < lerpf(_rise_from, RAIL_Y + 40, ArcadeRules.CLAW_WEAK_HOLD):
				_let_go()
				banner("IT SLIPPED!", 1.2, Color(1.0, 0.6, 0.5))
			if _claw.y <= RAIL_Y + 40:
				_claw.y = RAIL_Y + 40
				_state = S.CARRY if _held else S.IDLE
				if not _held:
					_update_grip()
		S.CARRY:
			var target := BOX.position.x + CHUTE_W * 0.5
			_claw.x = move_toward(_claw.x, target, SPEED * 1.2 * delta)
			if absf(_claw.x - target) < 1.0:
				_let_go()
				_state = S.IDLE
				_update_grip()
	if _held:
		_place(_held, _claw + Vector2(0, 60))
	_collect()
	queue_redraw()
	_fg.queue_redraw()


func _touching() -> bool:
	for p in _prizes:
		if p.position.distance_to(_claw + Vector2(0, 60)) < float(p.get_meta("r")) + 14.0:
			return true
	return false


func _nearest() -> RigidBody2D:
	var best: RigidBody2D
	var bd := GRAB_REACH
	for p in _prizes:
		var d := p.position.distance_to(_claw + Vector2(0, 60))
		if d < bd + float(p.get_meta("r")) * 0.5:
			bd = d
			best = p
	return best


func _let_go() -> void:
	if _held == null:
		return
	_place(_held, _claw + Vector2(0, 60))
	_held.freeze = false
	_held.sleeping = false
	_held.linear_velocity = Vector2(0, 60)
	_held = null


## Move a carried prize: the node and the physics server both, or it snaps
## back to where it was picked up when it's let go.
func _place(b: RigidBody2D, at: Vector2) -> void:
	b.position = at
	PhysicsServer2D.body_set_state(b.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, b.global_transform)


## Prizes that fell down the chute pay out; the box refills from the top.
func _collect() -> void:
	for p in _prizes.duplicate():
		if p == _held:
			continue
		if p.position.y > FLOOR_Y + 60:
			var kind: String = p.get_meta("kind")
			_prizes.erase(p)
			p.queue_free()
			var t := ArcadeRules.claw_tickets(kind)
			var beats := ArcadeRules.claw_beats(kind)
			win(t, "claw", beats)
			sfx("jackpot" if beats else "ding")
			banner("%s!\n+%d TICKETS" % [ArcadeRules.CLAW_PRIZES[kind].name, t], 2.4)
			var stars := 0
			for q in _prizes:
				if q.get_meta("kind") == "star":
					stars += 1
			var kind_new := "star" if stars < STAR_KEEP else ("bear" if _rng.randf() < 0.35 else "duck")
			_spawn(kind_new, Vector2(_rng.randf_range(CHUTE_W + 140, BOX.end.x - 60), BOX.position.y + 140))
		elif p.position.y > FLOOR_Y + 600 or p.position.x < 0 or p.position.x > W:
			_prizes.erase(p)
			p.queue_free()


func _update_grip() -> void:
	if hub == null or not hub.state.has("gloria_eye"):
		_grip.text = "EVERY GRAB IS A GAMBLE"
		_grip.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		return
	var strong := ArcadeRules.claw_strong(_grabs)
	var left := (ArcadeRules.CLAW_STRONG_EVERY - 1 - _grabs % ArcadeRules.CLAW_STRONG_EVERY)
	_grip.text = "GLORIA'S EYE: FULL STRENGTH!" if strong else "GLORIA'S EYE: WEAK (%d TO GO)" % left
	_grip.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if strong else Color(1.0, 0.7, 0.5))


func _draw() -> void:
	# Glass box, back panel, floor and chute.
	draw_rect(BOX, Color(0.15, 0.08, 0.22))
	draw_rect(Rect2(BOX.position, Vector2(CHUTE_W, BOX.size.y)), Color(0.1, 0.05, 0.14))
	draw_rect(Rect2(BOX.position.x + CHUTE_W, FLOOR_Y, BOX.size.x - CHUTE_W, BOX.end.y - FLOOR_Y), Color(0.3, 0.12, 0.35))
	draw_rect(Rect2(BOX.position.x, FLOOR_Y - 110, CHUTE_W, 6), Color(1.0, 0.4, 0.75, 0.5))
	draw_rect(BOX, Color(1.0, 0.4, 0.75), false, 6.0)
	for i in 8:
		draw_circle(Vector2(BOX.position.x + 40 + i * 80, BOX.position.y - 2), 7, Color(1.0, 0.9, 0.4) if (Time.get_ticks_msec() / 300 + i) % 2 == 0 else Color(0.5, 0.3, 0.2))


## Rail, cable and claw, drawn over the prizes.
func _draw_claw() -> void:
	var c := _fg
	c.draw_line(Vector2(BOX.position.x, RAIL_Y), Vector2(BOX.end.x, RAIL_Y), Color(0.7, 0.7, 0.75), 8)
	c.draw_rect(Rect2(_claw.x - 30, RAIL_Y - 14, 60, 28), Color(0.75, 0.75, 0.8))
	c.draw_line(Vector2(_claw.x, RAIL_Y), _claw, Color(0.85, 0.85, 0.9), 4)
	var shut := _state in [S.CLOSE, S.RISE, S.CARRY] and (_held != null or _state == S.CLOSE)
	var spread := 18.0 if shut else 42.0
	var metal := Color(0.85, 0.85, 0.92)
	c.draw_rect(Rect2(_claw.x - 26, _claw.y - 10, 52, 22), metal)
	for side in [-1.0, 1.0]:
		var knee := _claw + Vector2(side * spread, 34)
		c.draw_line(_claw + Vector2(side * 16, 8), knee, metal, 8)
		c.draw_line(knee, knee + Vector2(-side * 16, 34), metal, 8)
	if hub and hub.state.has("gloria_eye") and ArcadeRules.claw_strong(_grabs) and _state == S.IDLE:
		c.draw_arc(_claw + Vector2(0, 30), 52, 0, TAU, 24, Color(0.4, 1.0, 0.5, 0.7), 5)
