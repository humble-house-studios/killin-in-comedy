extends "res://scenes/ladder/machine.gd"
## PUSH YOUR LUCK: a real 3D coin pusher (scenes/ladder/view3d.gd) in teal
## neon. The shelf at the back slides in and out; the drop chute swings left
## and right, DROP lets a coin fall in front of the shelf, and its next stroke
## shoves it into the pile. Whatever falls off the front edge pays tickets:
## coins, green bundles and the gold JACKPOT chip, which beats the machine.
## One token = 5 coins.

const VIEW_AT := Vector2(0, 200)
const VIEW := Vector2(720, 840)
const HALF_X := 0.7
const FRONT := 0.55
const BACK := -1.0
const SHELF_D := 0.7
## The shelf's front face moves between these (z, metres).
const SHELF_IN := -0.3
const SHELF_REACH := 0.24
const SHELF_PERIOD := 2.6
const COIN_R := 0.065
const COIN_H := 0.024
const KEEP := 58

var _view
var _shelf: AnimatableBody3D
var _t := 0.0
var _hand := 0
var _chute_x := 0.0
var _chute: Node3D
var _guide: MeshInstance3D
var _bodies: Array[RigidBody3D] = []
var _coin_mat: ShaderMaterial
var _edge_mat: ShaderMaterial
var _bulbs: Array[ShaderMaterial] = []
var _info: Label
var _drop: Button
var _rng := RandomNumberGenerator.new()
var _streak := 0
var _streak_time := 0.0
var _flash := 0.0


func _ready() -> void:
	super._ready()
	_rng.randomize()
	frame("PUSH YOUR LUCK", Color(0.01, 0.05, 0.06), Color(0.35, 0.95, 0.85))
	_view = preload("res://scenes/ladder/view3d.gd").new()
	add_child(_view)
	_view.setup(VIEW_AT, VIEW, 3, {
		"sky": Color(0.01, 0.05, 0.06), "ambient": Color(0.18, 0.26, 0.28),
		"fog_col": Color(0.01, 0.06, 0.07), "fog_near": 2.0, "fog_far": 4.6,
		"grain": 0.05, "vignette": 0.6, "scan": 0.07, "tint": Color(0.2, 1.0, 0.85, 0.03),
	})
	_view.add_post(self)
	_view.set_light(0, Vector3(0, 1.0, -0.3), Color(0.4, 1.0, 0.9), 2.2, 0.9)
	_view.set_light(1, Vector3(0, 0.6, 1.0), Color(1.0, 0.85, 0.5), 2.0, 0.9)
	_view.set_light(2, Vector3(-0.9, 0.4, 0.2), Color(1.0, 0.3, 0.8), 1.4, 0.8)
	_view.set_light(3, Vector3(0.9, 0.4, 0.2), Color(0.3, 0.6, 1.0), 1.4, 0.8)
	_view.set_light(4, Vector3(0, -0.1, FRONT + 0.1), Color(1.0, 0.75, 0.2), 0.6, 0.8)
	_view.cam.position = Vector3(0, 1.08, 1.5)
	_view.cam.look_at(Vector3(0, 0.0, -0.05))
	_view.cam.fov = 48.0
	_coin_mat = _view.mat(Color(0.95, 0.75, 0.25), {"shine": 1.8})
	_edge_mat = _view.glow(Color(1.0, 0.75, 0.2))
	_build()
	# A packed table from the shelf to the edge, so every push carries through
	# the pile, with two bundles and the jackpot buried in it.
	var specials := {Vector2i(2, 4): "bundle", Vector2i(7, 2): "bundle", Vector2i(4, 3): "jackpot"}
	for row in 7:
		for col in 10:
			var x := -HALF_X + 0.075 + col * 0.137 + (row % 2) * 0.0685
			if x > HALF_X - 0.06:
				continue
			_spawn(specials.get(Vector2i(col, row), "coin"), Vector3(x, 0.02, -0.2 + row * 0.112))
	for i in 10:
		_spawn("coin", Vector3(_rng.randf_range(-0.6, 0.6), 0.08 + i * 0.03, _rng.randf_range(0.0, 0.4)))
	_info = label("", 26, Color(1.0, 0.92, 0.55))
	_info.position = Vector2(0, 150)
	_info.size = Vector2(W, 40)
	add_child(_info)
	_drop = button("DROP COIN", 40, Color(0.05, 0.4, 0.38))
	_drop.position = Vector2(60, 1080)
	_drop.size = Vector2(W - 120, 150)
	_drop.custom_minimum_size = Vector2(0, 150)
	_drop.pressed.connect(_on_drop)
	_drop.set_meta("pad_default", true)
	add_child(_drop)
	_update_info()


func _build() -> void:
	var v = _view
	var felt: ShaderMaterial = v.mat(Color(0.05, 0.3, 0.32), {"pattern": 4, "col2": Color(0.1, 0.5, 0.5), "texel": 6.0})
	var side: ShaderMaterial = v.mat(Color(0.04, 0.12, 0.14), {"shine": 0.5})
	var chrome: ShaderMaterial = v.mat(Color(0.7, 0.75, 0.8), {"pattern": 2, "col2": Color(0.5, 0.55, 0.6), "texel": 40.0, "shine": 1.5})
	var mirror: ShaderMaterial = v.mat(Color(0.05, 0.08, 0.12), {"pattern": 1, "col2": Color(0.08, 0.14, 0.2), "texel": 4.0, "shine": 0.8})
	# Playfield, side walls, back wall.
	v.solid(Vector3(HALF_X * 2, 0.1, FRONT - BACK), Vector3(0, -0.05, (FRONT + BACK) * 0.5), felt, null, Vector3.ZERO, 0.0, 0.35)
	for s in [-1.0, 1.0]:
		v.solid(Vector3(0.06, 0.5, FRONT - BACK), Vector3(s * (HALF_X + 0.03), 0.25, (FRONT + BACK) * 0.5), side)
		v.box(Vector3(0.015, 0.015, FRONT - BACK), Vector3(s * (HALF_X + 0.01), 0.5, (FRONT + BACK) * 0.5), v.glow(Color(1.0, 0.3, 0.8) if s < 0 else Color(0.3, 0.6, 1.0)))
		for i in 7:
			var b: ShaderMaterial = v.glow(Color(1.0, 0.9, 0.4))
			_bulbs.append(b)
			v.ball(0.018, Vector3(s * (HALF_X + 0.065), 0.42, FRONT - 0.05 - i * 0.18), b, null, 6)
	v.solid(Vector3(HALF_X * 2 + 0.1, 0.9, 0.06), Vector3(0, 0.45, BACK - 0.03), mirror)
	v.text("PUSH YOUR LUCK", Vector3(0, 0.62, BACK + 0.01), 40, Color(0.4, 1.0, 0.9))
	v.text("JACKPOT  150", Vector3(0, 0.5, BACK + 0.01), 22, Color(1.0, 0.8, 0.2))
	# The gold lip at the front edge and the dark drop beyond it.
	v.box(Vector3(HALF_X * 2, 0.012, 0.03), Vector3(0, 0.0, FRONT - 0.012), _edge_mat)
	v.box(Vector3(HALF_X * 2 + 0.4, 0.02, 0.6), Vector3(0, -0.45, FRONT + 0.3), v.mat(Color(0.02, 0.04, 0.05)))
	# The shelf: moves in and out on its own clock (_physics_process).
	_shelf = AnimatableBody3D.new()
	_shelf.sync_to_physics = true
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(HALF_X * 2 - 0.01, 0.14, SHELF_D)
	shape.shape = b
	_shelf.add_child(shape)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	_shelf.physics_material_override = pm
	v.box(b.size, Vector3.ZERO, chrome, _shelf)
	v.box(Vector3(HALF_X * 2 - 0.01, 0.015, 0.02), Vector3(0, 0.07, SHELF_D * 0.5), v.glow(Color(0.4, 1.0, 0.9)), _shelf)
	_shelf.position = Vector3(0, 0.07, SHELF_IN - SHELF_D * 0.5)
	v.root.add_child(_shelf)
	# Coins on the shelf can't ride back past this.
	v.solid(Vector3(HALF_X * 2, 0.6, 0.04), Vector3(0, 0.45, SHELF_IN - SHELF_D + 0.02), mirror)
	# The drop chute and a guide line to where the coin lands.
	_chute = Node3D.new()
	v.root.add_child(_chute)
	v.cyl(0.085, 0.085, 0.18, Vector3(0, 0.62, 0), v.mat(Color(0.2, 0.25, 0.3), {"shine": 1.2}), _chute)
	v.cyl(0.07, 0.07, 0.01, Vector3(0, 0.525, 0), v.glow(Color(1.0, 0.85, 0.3)), _chute)
	_guide = v.box(Vector3(0.006, 0.5, 0.006), Vector3(0, 0.27, 0), v.glow(Color(1.0, 0.85, 0.3) * 0.6), _chute)


func _spawn(kind: String, at: Vector3) -> void:
	var v = _view
	var b := RigidBody3D.new()
	b.position = at
	b.rotation.y = _rng.randf() * TAU
	b.set_meta("kind", kind)
	var shape := CollisionShape3D.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 0.45
	pm.bounce = 0.05
	b.physics_material_override = pm
	b.linear_damp = 0.8
	b.angular_damp = 2.5
	b.can_sleep = true
	if kind == "coin":
		var c := CylinderShape3D.new()
		c.radius = COIN_R
		c.height = COIN_H
		shape.shape = c
		b.mass = 0.1
		v.cyl(COIN_R, COIN_R, COIN_H, Vector3.ZERO, _coin_mat, b, Vector3.ZERO, 10)
	else:
		var dims := Vector3(0.2, 0.05, 0.13) if kind == "bundle" else Vector3(0.22, 0.07, 0.15)
		var r := BoxShape3D.new()
		r.size = dims
		shape.shape = r
		b.mass = 0.2
		if kind == "bundle":
			v.box(dims, Vector3.ZERO, v.mat(Color(0.3, 0.8, 0.4), {"pattern": 2, "col2": Color(0.2, 0.6, 0.3), "texel": 80.0}), b)
			v.text("25", Vector3(0, dims.y * 0.5 + 0.002, 0), 30, Color(0.05, 0.25, 0.1), b, Vector3(-PI / 2, 0, 0))
		else:
			v.box(dims, Vector3.ZERO, v.mat(Color(1.0, 0.75, 0.1), {"shine": 2.0, "glow": Color(0.4, 0.25, 0.0)}), b)
			v.text("JP!", Vector3(0, dims.y * 0.5 + 0.002, 0), 34, Color(0.5, 0.1, 0.0), b, Vector3(-PI / 2, 0, 0))
	b.add_child(shape)
	v.root.add_child(b)
	_bodies.append(b)


func _on_drop() -> void:
	if _hand <= 0:
		if not pay_token():
			return
		_hand += ArcadeRules.PUSHER_COINS_PER_TOKEN
	_hand -= 1
	# Lands in the strip the shelf sweeps, so its next stroke shoves it in.
	_spawn("coin", Vector3(_chute_x, 0.45, _shelf_front() + COIN_R + 0.02))
	_bodies[-1].rotation = Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
	sfx("click", -4.0, _rng.randf_range(0.9, 1.1))
	_update_info()


func _shelf_front() -> float:
	return _shelf.position.z + SHELF_D * 0.5


func _physics_process(delta: float) -> void:
	_t += delta
	var reach := (0.5 - 0.5 * cos(_t * TAU / SHELF_PERIOD)) * SHELF_REACH
	_shelf.position.z = SHELF_IN - SHELF_D * 0.5 + reach


func _process(delta: float) -> void:
	super._process(delta)
	_chute_x = sin(_t * 1.3) * (HALF_X - 0.1)
	_chute.position = Vector3(_chute_x, 0, _shelf_front() + COIN_R + 0.02)
	_guide.scale.y = 1.0
	_streak_time = maxf(0.0, _streak_time - delta)
	if _streak_time <= 0.0:
		_streak = 0
	for b in _bodies.duplicate():
		if b.position.y < -0.12 and b.position.z > FRONT - 0.05:
			_bodies.erase(b)
			var kind: String = b.get_meta("kind")
			b.queue_free()
			var t := ArcadeRules.pusher_tickets(kind)
			win(t, "pusher", kind == "jackpot")
			_flash = 0.35
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
				_spawn(kind, Vector3(_rng.randf_range(-0.4, 0.4), 0.3, _shelf_front() + 0.12))
		elif b.position.y < -0.3 or absf(b.position.x) > HALF_X + 0.2 or b.position.y > 2.0:
			_bodies.erase(b)
			b.queue_free()
	# Keep the table stocked: a coin rains in at the back if it runs thin.
	if _bodies.size() < KEEP and Engine.get_process_frames() % 10 == 0:
		_spawn("coin", Vector3(_rng.randf_range(-0.6, 0.6), 0.4, _shelf_front() + COIN_R + 0.02))
	_flash = maxf(0.0, _flash - delta)
	_edge_mat.set_shader_parameter("emission", Color(1.0, 0.75, 0.2).lerp(Color(1, 1, 0.9), _flash * 2.5))
	var step := int(_t * 5.0)
	for i in _bulbs.size():
		_bulbs[i].set_shader_parameter("emission", Color(1.0, 0.85, 0.35) if (step + i) % 4 == 0 else Color(0.25, 0.12, 0.05))


func _update_info() -> void:
	_info.text = "COINS IN HAND: %d" % _hand if _hand > 0 else "1 TOKEN = %d COINS" % ArcadeRules.PUSHER_COINS_PER_TOKEN
	refresh_top()
