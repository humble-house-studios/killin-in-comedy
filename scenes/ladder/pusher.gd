extends "res://scenes/ladder/machine.gd"
## PUSH YOUR LUCK: a coin pusher, seen from above, with real 2D physics. The
## shelf at the back slides in and out; drop coins in front of it (the drop
## chute swings left and right; DROP releases at that spot) and it shoves the
## pile toward the edge. Whatever falls off the front pays tickets: coins,
## green bundles and the gold JACKPOT chip, which beats the machine.
## One token = 5 coins.

const TABLE := Rect2(70, 250, 580, 760)
const EDGE_Y := 1010.0
const SHELF_BACK := 380.0
const SHELF_REACH := 120.0
const SHELF_PERIOD := 2.6
const COIN_R := 28.0
## Rows of coins on the table at the start (it's kept about this full).
const START_ROWS := 10
const KEEP := 80

var _world: Node2D
var _shelf: AnimatableBody2D
var _t := 0.0
var _hand := 0
var _chute_x := 360.0
var _bodies: Array[RigidBody2D] = []
var _info: Label
var _drop: Button
var _rng := RandomNumberGenerator.new()
var _streak := 0
var _streak_time := 0.0


func _ready() -> void:
	super._ready()
	_rng.randomize()
	frame("PUSH YOUR LUCK", Color(0.03, 0.08, 0.1), Color(0.35, 0.95, 0.85))
	_world = Node2D.new()
	add_child(_world)
	var walls := StaticBody2D.new()
	_world.add_child(walls)
	# Side walls, and a back wall behind the shelf so nothing squirts out the top.
	for s in [[Vector2(TABLE.position.x, 150), Vector2(TABLE.position.x, EDGE_Y)], [Vector2(TABLE.end.x, 150), Vector2(TABLE.end.x, EDGE_Y)], [Vector2(TABLE.position.x, 150), Vector2(TABLE.end.x, 150)]]:
		var shape := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = s[0]
		seg.b = s[1]
		shape.shape = seg
		walls.add_child(shape)
	_shelf = AnimatableBody2D.new()
	_shelf.sync_to_physics = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TABLE.size.x - 6, 180)
	shape.shape = rect
	_shelf.add_child(shape)
	_shelf.position = Vector2(TABLE.get_center().x, SHELF_BACK - 90)
	_world.add_child(_shelf)
	# A packed table from the shelf to the edge, so every push carries through
	# the pile, with two bundles and the jackpot buried in it.
	# Packed tight (hex rows), so a push goes all the way through.
	var specials := {Vector2i(2, 4): "bundle", Vector2i(6, 7): "bundle", Vector2i(4, 2): "jackpot"}
	for row in START_ROWS:
		for col in 9:
			var at := Vector2(TABLE.position.x + 32 + col * 57 + (row % 2) * 28, 520 + row * 50)
			_spawn(specials.get(Vector2i(col, row), "coin"), at)
	_info = label("", 26, Color(1.0, 0.92, 0.55))
	_info.position = Vector2(0, 156)
	_info.size = Vector2(W, 40)
	add_child(_info)
	_drop = button("DROP COIN", 40, Color(0.05, 0.4, 0.38))
	_drop.position = Vector2(60, 1070)
	_drop.size = Vector2(W - 120, 150)
	_drop.custom_minimum_size = Vector2(0, 150)
	_drop.pressed.connect(_on_drop)
	_drop.set_meta("pad_default", true)
	add_child(_drop)
	_update_info()


func _spawn(kind: String, at: Vector2) -> void:
	var b := RigidBody2D.new()
	b.position = at
	b.gravity_scale = 0.0
	b.linear_damp = 3.5
	b.angular_damp = 6.0
	b.can_sleep = true
	b.set_meta("kind", kind)
	var shape := CollisionShape2D.new()
	if kind == "coin":
		var c := CircleShape2D.new()
		c.radius = COIN_R
		shape.shape = c
	else:
		var r := RectangleShape2D.new()
		r.size = Vector2(70, 46) if kind == "bundle" else Vector2(84, 56)
		shape.shape = r
	b.add_child(shape)
	var mat := PhysicsMaterial.new()
	mat.friction = 0.4
	mat.bounce = 0.0
	b.physics_material_override = mat
	b.mass = 1.0 if kind == "coin" else 1.6
	b.draw.connect(_draw_piece.bind(b))
	_world.add_child(b)
	_bodies.append(b)


func _draw_piece(b: RigidBody2D) -> void:
	match b.get_meta("kind"):
		"coin":
			b.draw_circle(Vector2.ZERO, COIN_R, Color(0.85, 0.7, 0.3))
			b.draw_circle(Vector2.ZERO, COIN_R - 6, Color(0.95, 0.82, 0.4))
			b.draw_arc(Vector2.ZERO, COIN_R - 6, 0, TAU, 16, Color(0.7, 0.55, 0.2), 2)
		"bundle":
			b.draw_rect(Rect2(-35, -23, 70, 46), Color(0.3, 0.8, 0.4))
			b.draw_string(FONT, Vector2(-26, 9), "25", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.05, 0.25, 0.1))
		"jackpot":
			b.draw_rect(Rect2(-42, -28, 84, 56), Color(1.0, 0.8, 0.1))
			b.draw_rect(Rect2(-42, -28, 84, 56), Color(1.0, 0.4, 0.1), false, 4)
			b.draw_string(FONT, Vector2(-30, 10), "JP!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.5, 0.15, 0.0))


func _on_drop() -> void:
	if _hand <= 0:
		if not pay_token():
			return
		_hand += ArcadeRules.PUSHER_COINS_PER_TOKEN
	_hand -= 1
	# Lands in the strip the shelf sweeps, so its next stroke shoves it in.
	_spawn("coin", Vector2(_chute_x, _drop_y()))
	sfx("click", -4.0, _rng.randf_range(0.9, 1.1))
	_update_info()


## Just in front of the shelf wherever it is now, so a new coin never
## spawns inside it (the next stroke shoves it into the pile).
func _drop_y() -> float:
	return _shelf.position.y + 90.0 + COIN_R + 4.0


func _physics_process(delta: float) -> void:
	_t += delta
	var reach := (0.5 - 0.5 * cos(_t * TAU / SHELF_PERIOD)) * SHELF_REACH
	_shelf.position.y = SHELF_BACK - 90 + reach


func _process(delta: float) -> void:
	super._process(delta)
	_chute_x = TABLE.get_center().x + sin(_t * 1.3) * (TABLE.size.x * 0.5 - 50)
	_streak_time = maxf(0.0, _streak_time - delta)
	if _streak_time <= 0.0:
		_streak = 0
	for b in _bodies.duplicate():
		if b.position.y > EDGE_Y + 10:
			_bodies.erase(b)
			var kind: String = b.get_meta("kind")
			b.queue_free()
			var t := ArcadeRules.pusher_tickets(kind)
			win(t, "pusher", kind == "jackpot")
			if kind == "coin":
				_streak += 1
				_streak_time = 1.2
				sfx("coin", -6.0, 1.0 + minf(_streak, 12) * 0.05)
				if _streak >= 5:
					banner("x%d COINS!\n+%d" % [_streak, _streak * t], 1.0)
			else:
				sfx("jackpot" if kind == "jackpot" else "ding")
				banner("JACKPOT!\n+%d TICKETS" % t if kind == "jackpot" else "BUNDLE!\n+%d TICKETS" % t, 2.4)
				# Bury a fresh one at the back so there's always something to chase.
				_spawn(kind, Vector2(_rng.randf_range(200, 520), _drop_y() + 20))
		elif b.position.x < TABLE.position.x - 10 or b.position.x > TABLE.end.x + 10 or b.position.y < 140:
			_bodies.erase(b)
			b.queue_free()
	# Keep the table stocked: a few coins rain in at the back if it runs thin.
	if _bodies.size() < KEEP:
		_spawn("coin", Vector2(_rng.randf_range(120, 600), _drop_y()))
	queue_redraw()


func _update_info() -> void:
	_info.text = "COINS IN HAND: %d" % _hand if _hand > 0 else "1 TOKEN = %d COINS" % ArcadeRules.PUSHER_COINS_PER_TOKEN
	refresh_top()


func _draw() -> void:
	draw_rect(TABLE, Color(0.08, 0.25, 0.3))
	draw_rect(Rect2(TABLE.position.x, EDGE_Y - 8, TABLE.size.x, 8), Color(1.0, 0.8, 0.3))
	draw_rect(Rect2(TABLE.position.x, EDGE_Y, TABLE.size.x, 40), Color(0.02, 0.05, 0.06))
	draw_rect(TABLE, Color(0.35, 0.95, 0.85), false, 5.0)
	# The shelf.
	var sy := _shelf.position.y + 90
	draw_rect(Rect2(TABLE.position.x + 3, 200, TABLE.size.x - 6, sy - 200), Color(0.6, 0.65, 0.7))
	draw_rect(Rect2(TABLE.position.x + 3, sy - 10, TABLE.size.x - 6, 10), Color(0.85, 0.9, 0.95))
	# Where the next coin drops.
	draw_circle(Vector2(_chute_x, 214), 20, Color(1.0, 0.85, 0.3, 0.9))
	draw_line(Vector2(_chute_x, 234), Vector2(_chute_x, sy + 40), Color(1.0, 0.85, 0.3, 0.35), 3)
	draw_string(FONT, Vector2(TABLE.position.x, EDGE_Y + 30), "EVERYTHING OFF THE EDGE PAYS", HORIZONTAL_ALIGNMENT_CENTER, TABLE.size.x, 16, Color(1, 1, 1, 0.6))
