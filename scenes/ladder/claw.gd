extends "res://scenes/ladder/machine.gd"
## CLAW KING: a real 3D claw machine (scenes/ladder/view3d.gd) under pink and
## cyan neon. Steer the claw left/right and back/front with the arrows (a red
## laser and a shadow show where it'll land), DROP (1 token), and it grabs
## whatever is under it. Every fourth grab is full strength
## (ArcadeRules.CLAW_STRONG_EVERY); weaker grabs slip partway up. Prizes
## carried to the chute (front left) pay tickets. The TOP-SHELF STAR beats the
## machine. Gloria's Eye (her perk) lights the claw green at full strength.
## On a controller the claw drives straight from the stick or D-pad (the pad
## cursor stands aside, `hold`) and A drops; arrow keys + Enter/Space too.

const VIEW_AT := Vector2(0, 150)
const VIEW := Vector2(720, 850)
## The glass box, metres: x left/right, z back/front, floor at y 0.
const HALF := Vector2(0.8, 0.6)
const CHUTE := Rect2(-0.8, 0.18, 0.42, 0.42)
const RAIL_Y := 1.25
const SPEED := 0.55
const DROP_SPEED := 0.75
const REACH := 0.17
const KEEP := 13
const STAR_KEEP := 2
const OPEN := 0.75
const SHUT := 0.12

enum S { IDLE, DROP, CLOSE, RISE, CARRY, OPEN_UP }

var _state := S.IDLE
var _claw := Vector3(0.25, RAIL_Y, -0.1)
var _dir := Vector2.ZERO
var _stick := Vector2.ZERO
var _dpad := {}
var _keys := {}
var _pad_told := false
var _held: RigidBody3D
var _strong := false
var _grabs := 0
var _close_t := 0.0
var _rise_from := 0.0
var _open := OPEN
var _prizes: Array[RigidBody3D] = []
var _view
var _bridge: Node3D
var _carriage: Node3D
var _cable: MeshInstance3D
var _head: Node3D
var _prongs: Array[Node3D] = []
var _laser: MeshInstance3D
var _shadow: MeshInstance3D
var _head_mat: ShaderMaterial
var _bulbs: Array[ShaderMaterial] = []
var _grip: Label
var _drop: Button
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func _ready() -> void:
	super._ready()
	_rng.randomize()
	frame("CLAW KING", Color(0.05, 0.02, 0.09), Color(1.0, 0.4, 0.75))
	_view = preload("res://scenes/ladder/view3d.gd").new()
	add_child(_view)
	_view.setup(VIEW_AT, VIEW, 3, {
		"sky": Color(0.05, 0.02, 0.09), "ambient": Color(0.28, 0.2, 0.36),
		"fog_col": Color(0.08, 0.03, 0.12), "fog_near": 3.0, "fog_far": 6.5,
		"grain": 0.05, "vignette": 0.55, "scan": 0.07, "tint": Color(1.0, 0.3, 0.7, 0.04),
	})
	_view.add_post(self)
	_view.set_light(0, Vector3(-0.6, 1.5, 0.1), Color(1.0, 0.35, 0.75), 2.4, 1.1)
	_view.set_light(1, Vector3(0.7, 1.5, -0.2), Color(0.3, 0.9, 1.0), 2.4, 1.0)
	_view.set_light(2, Vector3(0.0, 1.6, 1.4), Color(1.0, 0.95, 0.85), 3.2, 0.7)
	_view.set_light(3, Vector3(-0.6, 0.2, 0.4), Color(1.0, 0.8, 0.2), 0.9, 0.8)
	_view.cam.position = Vector3(0.15, 1.75, 2.45)
	_view.cam.look_at(Vector3(0.0, 0.62, 0.0))
	_view.cam.fov = 44.0
	_build_box()
	_build_claw()
	for i in KEEP:
		_spawn(_kind_for(i), _random_spot(0.2 + i * 0.09))
	_grip = label("", 22, Color(0.6, 1.0, 0.7))
	_grip.position = Vector2(0, 156)
	_grip.size = Vector2(W, 34)
	add_child(_grip)
	_controls()
	_update_grip()
	pad.hold = true
	pad.guide = [["L", "Move the claw"], ["DPAD", "Move the claw"], ["A", "Drop"]]


func _kind_for(i: int) -> String:
	if i < STAR_KEEP:
		return "star"
	return "bear" if i % 3 == 0 else "duck"


func _random_spot(y: float) -> Vector3:
	return Vector3(_rng.randf_range(CHUTE.end.x + 0.15, HALF.x - 0.15), y, _rng.randf_range(-HALF.y + 0.15, HALF.y - 0.15))


# ---------------------------------------------------------------- building

func _build_box() -> void:
	var v = _view
	var plush: ShaderMaterial = v.mat(Color(0.55, 0.15, 0.45), {"pattern": 3, "col2": Color(0.8, 0.3, 0.65), "texel": 30.0})
	var wall: ShaderMaterial = v.mat(Color(0.12, 0.05, 0.2), {"pattern": 4, "col2": Color(0.9, 0.3, 0.8), "texel": 5.0})
	var side: ShaderMaterial = v.mat(Color(0.1, 0.04, 0.16))
	var chrome: ShaderMaterial = v.mat(Color(0.7, 0.7, 0.78), {"shine": 1.4})
	var hazard: ShaderMaterial = v.mat(Color(1.0, 0.8, 0.1), {"pattern": 1, "col2": Color(0.08, 0.06, 0.04), "texel": 14.0})
	# Floor with the chute cut out of its front-left corner.
	var right_w := HALF.x - CHUTE.end.x
	v.solid(Vector3(right_w, 0.1, HALF.y * 2), Vector3(CHUTE.end.x + right_w * 0.5, -0.05, 0), plush, null, Vector3.ZERO, 0.05, 0.9)
	var back_d := CHUTE.position.y + HALF.y
	v.solid(Vector3(CHUTE.size.x, 0.1, back_d), Vector3(CHUTE.get_center().x, -0.05, -HALF.y + back_d * 0.5), plush, null, Vector3.ZERO, 0.05, 0.9)
	# Walls: back, sides; the front is glass (invisible, still solid).
	v.solid(Vector3(HALF.x * 2 + 0.2, 1.6, 0.1), Vector3(0, 0.75, -HALF.y - 0.05), wall)
	v.solid(Vector3(0.1, 1.6, HALF.y * 2), Vector3(-HALF.x - 0.05, 0.75, 0), side)
	v.solid(Vector3(0.1, 1.6, HALF.y * 2), Vector3(HALF.x + 0.05, 0.75, 0), side)
	v.solid(Vector3(HALF.x * 2, 1.6, 0.04), Vector3(0, 0.75, HALF.y + 0.02), null)
	# The chute: a low hazard-striped lip so prizes don't wander in, and a
	# glowing pit below.
	v.solid(Vector3(0.03, 0.14, CHUTE.size.y), Vector3(CHUTE.end.x + 0.015, 0.07, CHUTE.get_center().y), hazard)
	v.solid(Vector3(CHUTE.size.x, 0.14, 0.03), Vector3(CHUTE.get_center().x, 0.07, CHUTE.position.y - 0.015), hazard)
	v.box(Vector3(CHUTE.size.x, 0.02, CHUTE.size.y), Vector3(CHUTE.get_center().x, -0.6, CHUTE.get_center().y), v.glow(Color(0.9, 0.6, 0.1)))
	v.text("PRIZE", Vector3(CHUTE.get_center().x, 0.17, CHUTE.end.y - 0.01), 16, Color(1.0, 0.85, 0.3), null, Vector3(-0.5, 0, 0))
	# Neon on the glass edges, and a marquee on the back wall.
	var pink: ShaderMaterial = v.glow(Color(1.0, 0.35, 0.75))
	var cyan: ShaderMaterial = v.glow(Color(0.3, 0.95, 1.0))
	for x in [-HALF.x, HALF.x]:
		v.box(Vector3(0.025, 1.5, 0.025), Vector3(x, 0.75, HALF.y), pink)
	v.box(Vector3(HALF.x * 2, 0.025, 0.025), Vector3(0, 1.5, HALF.y), cyan)
	v.box(Vector3(HALF.x * 2, 0.025, 0.025), Vector3(0, 0.0, HALF.y + 0.01), cyan)
	v.text("CLAW KING", Vector3(0.1, 1.05, -HALF.y + 0.005), 48, Color(1.0, 0.45, 0.85))
	v.text("EVERY GRAB IS A GAMBLE", Vector3(0.1, 0.9, -HALF.y + 0.005), 14, Color(0.4, 1.0, 0.95))
	for i in 10:
		var b: ShaderMaterial = v.glow(Color(1.0, 0.9, 0.4))
		_bulbs.append(b)
		v.ball(0.025, Vector3(-HALF.x + 0.08 + i * 0.16, 1.55, HALF.y + 0.02), b, null, 6)
	# Gantry rails along the top.
	for z in [-HALF.y + 0.04, HALF.y - 0.04]:
		v.box(Vector3(HALF.x * 2, 0.04, 0.04), Vector3(0, RAIL_Y + 0.12, z), chrome)


func _build_claw() -> void:
	var v = _view
	var chrome: ShaderMaterial = v.mat(Color(0.75, 0.75, 0.82), {"shine": 1.6})
	var dark: ShaderMaterial = v.mat(Color(0.2, 0.2, 0.25), {"shine": 0.6})
	_head_mat = v.mat(Color(0.8, 0.8, 0.86), {"shine": 1.6})
	_bridge = Node3D.new()
	v.root.add_child(_bridge)
	v.box(Vector3(0.05, 0.05, HALF.y * 2), Vector3(0, RAIL_Y + 0.12, 0), chrome, _bridge)
	_carriage = Node3D.new()
	_bridge.add_child(_carriage)
	v.box(Vector3(0.13, 0.08, 0.13), Vector3(0, RAIL_Y + 0.07, 0), dark, _carriage)
	_cable = v.box(Vector3(0.012, 1.0, 0.012), Vector3.ZERO, chrome)
	_head = Node3D.new()
	v.root.add_child(_head)
	v.cyl(0.055, 0.07, 0.08, Vector3(0, 0.0, 0), _head_mat, _head)
	for i in 3:
		var pivot := Node3D.new()
		pivot.rotation.y = i * TAU / 3.0
		_head.add_child(pivot)
		var hinge := Node3D.new()
		hinge.position = Vector3(0, -0.03, 0.05)
		pivot.add_child(hinge)
		v.box(Vector3(0.022, 0.12, 0.022), Vector3(0, -0.06, 0), chrome, hinge)
		v.box(Vector3(0.022, 0.08, 0.022), Vector3(0, -0.14, -0.025), chrome, hinge, Vector3(0.6, 0, 0))
		_prongs.append(hinge)
	_laser = v.box(Vector3(0.006, 1.0, 0.006), Vector3.ZERO, v.glow(Color(1.0, 0.1, 0.15)))
	_shadow = v.cyl(0.08, 0.08, 0.004, Vector3.ZERO, v.mat(Color(0.03, 0.0, 0.05)), null, Vector3.ZERO, 12)


func _spawn(kind: String, at: Vector3) -> void:
	var v = _view
	var b := RigidBody3D.new()
	b.position = at
	b.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0) * 0.3
	b.set_meta("kind", kind)
	var r := 0.11 if kind == "duck" else (0.14 if kind == "bear" else 0.12)
	b.set_meta("r", r)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = r
	shape.shape = sphere
	b.add_child(shape)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.05
	pm.rough = true
	b.physics_material_override = pm
	b.mass = 0.4
	b.angular_damp = 3.0
	b.linear_damp = 0.4
	match kind:
		"duck":
			var yellow: ShaderMaterial = v.mat(Color(1.0, 0.85, 0.15), {"shine": 0.5})
			v.ball(r, Vector3.ZERO, yellow, b)
			v.ball(r * 0.6, Vector3(0, r * 0.75, r * 0.35), yellow, b)
			v.box(Vector3(r * 0.5, r * 0.18, r * 0.45), Vector3(0, r * 0.7, r * 0.95), v.mat(Color(1.0, 0.45, 0.05)), b)
			for s in [-1.0, 1.0]:
				v.ball(r * 0.1, Vector3(s * r * 0.28, r * 0.95, r * 0.72), v.mat(Color(0.02, 0.02, 0.02)), b, 4)
		"bear":
			var fur: ShaderMaterial = v.mat(Color(0.6, 0.38, 0.2), {"pattern": 3, "col2": Color(0.5, 0.3, 0.15), "texel": 60.0})
			v.ball(r, Vector3.ZERO, fur, b)
			for s in [-1.0, 1.0]:
				v.ball(r * 0.32, Vector3(s * r * 0.62, r * 0.78, 0), fur, b, 6)
				v.ball(r * 0.1, Vector3(s * r * 0.3, r * 0.25, r * 0.9), v.mat(Color(0.02, 0.02, 0.02)), b, 4)
			v.ball(r * 0.35, Vector3(0, -r * 0.05, r * 0.82), v.mat(Color(0.9, 0.75, 0.55)), b, 6)
		_:
			var gold: ShaderMaterial = v.mat(Color(1.0, 0.8, 0.1), {"shine": 2.0, "glow": Color(0.35, 0.25, 0.0)})
			v.ball(r, Vector3.ZERO, gold, b, 5)
			v.cyl(0.0, r * 0.55, r * 0.9, Vector3(0, r * 1.1, 0), gold, b, Vector3.ZERO, 5)
			v.text("*", Vector3(0, 0, r + 0.005), 40, Color(1, 1, 0.8), b)
	v.root.add_child(b)
	_prizes.append(b)


func _controls() -> void:
	# Arrow keys on the left (back on top, then left / front / right),
	# DROP on the right.
	var pad := GridContainer.new()
	pad.columns = 3
	pad.position = Vector2(26, 1012)
	pad.size = Vector2(390, 250)
	pad.add_theme_constant_override("h_separation", 10)
	pad.add_theme_constant_override("v_separation", 10)
	add_child(pad)
	var dirs := [null, ["^", Vector2(0, -1)], null, ["<", Vector2(-1, 0)], ["v", Vector2(0, 1)], [">", Vector2(1, 0)]]
	for d in dirs:
		if d == null:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(120, 116)
			pad.add_child(gap)
			continue
		var b := button(d[0], 44)
		b.custom_minimum_size = Vector2(120, 116)
		pad.add_child(b)
		var dir: Vector2 = d[1]
		b.button_down.connect(func(): _dir = dir)
		b.button_up.connect(func(): _dir = Vector2.ZERO)
		b.pressed.connect(func(): _nudge(dir.x * 0.08, dir.y * 0.08))
	_drop = button("DROP", 44, Color(0.55, 0.1, 0.3))
	_drop.position = Vector2(436, 1012)
	_drop.size = Vector2(258, 242)
	_drop.custom_minimum_size = Vector2(258, 242)
	_drop.pressed.connect(_on_drop)
	_drop.set_meta("pad_default", true)
	_drop.set_meta("pad_button", JOY_BUTTON_A)
	add_child(_drop)


# ---------------------------------------------------------------- playing

const PAD_DEAD := 0.25
const DPAD := {
	JOY_BUTTON_DPAD_LEFT: Vector2(-1, 0), JOY_BUTTON_DPAD_RIGHT: Vector2(1, 0),
	JOY_BUTTON_DPAD_UP: Vector2(0, -1), JOY_BUTTON_DPAD_DOWN: Vector2(0, 1),
}
const KEYS := {
	KEY_LEFT: Vector2(-1, 0), KEY_RIGHT: Vector2(1, 0), KEY_UP: Vector2(0, -1), KEY_DOWN: Vector2(0, 1),
	KEY_A: Vector2(-1, 0), KEY_D: Vector2(1, 0), KEY_W: Vector2(0, -1), KEY_S: Vector2(0, 1),
}


## The controller (pushed in by the office while you sit here) and the
## keyboard steer the claw directly. Events only, never Input polling.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y:
			var v: float = event.axis_value if absf(event.axis_value) > PAD_DEAD else 0.0
			if event.axis == JOY_AXIS_LEFT_X:
				_stick.x = v
			else:
				_stick.y = v
			_tell_pad()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and DPAD.has(event.button_index):
		_dpad[event.button_index] = event.pressed
		_tell_pad()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and not event.echo:
		if KEYS.has(event.keycode):
			_keys[event.keycode] = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			_on_drop()
			get_viewport().set_input_as_handled()


func _tell_pad() -> void:
	if pad:
		pad.active = true
	if not _pad_told and pad:
		_pad_told = true
		pad.show_guide()


## Standing up: let go of everything (the release won't reach us any more).
func set_active(on: bool) -> void:
	super.set_active(on)
	if not on:
		_dir = Vector2.ZERO
		_stick = Vector2.ZERO
		_dpad.clear()
		_keys.clear()


## Where the controls are pushing: on-screen arrows, stick, D-pad, keys.
func _steer() -> Vector2:
	var v := _dir + _stick
	for b in _dpad:
		if _dpad[b]:
			v += DPAD[b]
	for k in _keys:
		if _keys[k]:
			v += KEYS[k]
	return v.limit_length(1.0)


func _clamp_claw() -> void:
	_claw.x = clampf(_claw.x, -HALF.x + 0.1, HALF.x - 0.1)
	_claw.z = clampf(_claw.z, -HALF.y + 0.1, HALF.y - 0.1)


func _nudge(dx: float, dz := 0.0) -> void:
	if _state == S.IDLE:
		_claw.x += dx
		_claw.z += dz
		_clamp_claw()


func _on_drop() -> void:
	if _state != S.IDLE:
		return
	if not pay_token():
		return
	_strong = ArcadeRules.claw_strong(_grabs)
	_grabs += 1
	_state = S.DROP
	_dir = Vector2.ZERO
	sfx("click")


## Where the claw tips are (just under the head).
func _tip() -> Vector3:
	return _claw + Vector3(0, -0.17, 0)


## What's under the claw: the top of the prize pile, or the floor.
func _ground_y() -> float:
	var hit: Dictionary = _view.ray(Vector3(_claw.x, RAIL_Y - 0.05, _claw.z), Vector3(_claw.x, -0.5, _claw.z), _held_rid())
	return hit.position.y if hit else -0.5


func _held_rid() -> Array[RID]:
	var out: Array[RID] = []
	if _held:
		out.append(_held.get_rid())
	return out


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	var target_open := OPEN
	match _state:
		S.IDLE:
			var steer := _steer()
			_claw.x += steer.x * SPEED * delta
			_claw.z += steer.y * SPEED * delta
			_clamp_claw()
		S.DROP:
			_claw.y -= DROP_SPEED * delta
			if _tip().y <= maxf(_ground_y(), 0.0) + 0.04:
				_state = S.CLOSE
				_close_t = 0.0
		S.CLOSE:
			_close_t += delta
			target_open = SHUT
			if _close_t > 0.45:
				_held = _nearest()
				if _held:
					_held.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
					_held.freeze = true
					sfx("thump", -4.0)
				_rise_from = _claw.y
				_state = S.RISE
		S.RISE:
			target_open = 0.32 if _held else SHUT
			_claw.y += DROP_SPEED * 0.6 * delta
			if _held and not _strong and _claw.y > lerpf(_rise_from, RAIL_Y, ArcadeRules.CLAW_WEAK_HOLD):
				_let_go()
				banner("IT SLIPPED!", 1.2, Color(1.0, 0.6, 0.5))
			if _claw.y >= RAIL_Y:
				_claw.y = RAIL_Y
				_state = S.CARRY if _held else S.IDLE
				if not _held:
					_update_grip()
		S.CARRY:
			target_open = 0.32
			var to := Vector2(CHUTE.get_center().x, CHUTE.get_center().y)
			var at := Vector2(_claw.x, _claw.z).move_toward(to, SPEED * 1.2 * delta)
			_claw.x = at.x
			_claw.z = at.y
			if at.distance_to(to) < 0.005:
				_let_go()
				_state = S.OPEN_UP
				_close_t = 0.0
		S.OPEN_UP:
			_close_t += delta
			if _close_t > 0.5:
				_state = S.IDLE
				_update_grip()
	_open = move_toward(_open, target_open, delta * 3.0)
	if _held:
		_hold(_held)
	_collect()
	_draw_rig()


func _nearest() -> RigidBody3D:
	var best: RigidBody3D
	var bd := REACH
	var tip := _tip()
	for p in _prizes:
		var r: float = p.get_meta("r")
		var flat := Vector2(p.position.x - tip.x, p.position.z - tip.z).length()
		var dy := absf(p.position.y + r * 0.5 - tip.y)
		if flat < bd and dy < r + 0.12:
			bd = flat
			best = p
	return best


func _hold(b: RigidBody3D) -> void:
	var r: float = b.get_meta("r")
	var t := b.global_transform
	t.origin = _tip() + Vector3(0, -r * 0.55, 0)
	b.global_transform = t
	PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)


func _let_go() -> void:
	if _held == null:
		return
	_hold(_held)
	_held.freeze = false
	_held.sleeping = false
	_held.linear_velocity = Vector3(0, -0.4, 0)
	_held = null


## Prizes that fell down the chute pay out; the box refills from the top.
func _collect() -> void:
	for p in _prizes.duplicate():
		if p == _held:
			continue
		if p.position.y < -0.35:
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
			_spawn(kind_new, _random_spot(1.0))


func _draw_rig() -> void:
	_bridge.position.x = _claw.x
	_carriage.position.z = _claw.z
	var top := RAIL_Y + 0.05
	var len := maxf(0.01, top - (_claw.y + 0.03))
	_cable.position = Vector3(_claw.x, top - len * 0.5, _claw.z)
	_cable.scale = Vector3(1, len, 1)
	_head.position = _claw
	_head.rotation.y = sin(_t * 0.7) * 0.15
	for h in _prongs:
		h.rotation.x = 0.3 - _open
	var ground := maxf(_ground_y(), -0.05)
	var show := _state == S.IDLE
	_laser.visible = show
	_shadow.visible = ground > -0.1
	var drop := maxf(0.01, _claw.y - 0.05 - ground)
	_laser.position = Vector3(_claw.x, ground + drop * 0.5, _claw.z)
	_laser.scale = Vector3(1, drop, 1)
	_shadow.position = Vector3(_claw.x, ground + 0.003, _claw.z)
	var s := clampf(1.3 - (_claw.y - ground) * 0.4, 0.5, 1.3)
	_shadow.scale = Vector3(s, 1, s)
	var lit: bool = hub != null and hub.state.has("gloria_eye") and ArcadeRules.claw_strong(_grabs) and _state == S.IDLE
	_head_mat.set_shader_parameter("emission", Color(0.1, 0.8, 0.3) if lit else Color.BLACK)
	var step := int(_t * 6.0)
	for i in _bulbs.size():
		_bulbs[i].set_shader_parameter("emission", Color(1.0, 0.85, 0.35) if (step + i) % 3 == 0 else Color(0.3, 0.12, 0.08))


func _update_grip() -> void:
	if hub == null or not hub.state.has("gloria_eye"):
		_grip.text = "STEER  ^ v < >  THEN DROP"
		_grip.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		return
	var strong := ArcadeRules.claw_strong(_grabs)
	var left := (ArcadeRules.CLAW_STRONG_EVERY - 1 - _grabs % ArcadeRules.CLAW_STRONG_EVERY)
	_grip.text = "GLORIA'S EYE: FULL STRENGTH!" if strong else "GLORIA'S EYE: WEAK (%d TO GO)" % left
	_grip.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if strong else Color(1.0, 0.7, 0.5))
