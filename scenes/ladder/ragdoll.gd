extends "res://scenes/ladder/machine.gd"
## FALL GUY: Bernie's stress-relief cabinet, now a real 3D ragdoll
## (scenes/ladder/view3d.gd). A Dale-shaped dummy (glasses, purple tie,
## legally not Dale) is flung down a long, grimy service corridor under dying
## fluorescent tubes: crunchy low-res pixels, heavy grain, sickly light, a red
## EXIT at the far end. Set the angle, time the power meter, FLING (1 token).
## Points for distance, for every crash into the furniture (ceiling too) and
## for each full flip (double with Bernie's style perk). Tickets = points / 20;
## 900 beats the machine.

const VIEW_AT := Vector2(0, 150)
const VIEW := Vector2(720, 820)
const COURSE := 44.0
const HALF_Z := 2.0
const CEIL := 6.0
const START := Vector3(0, 1.8, 0)
const SPEED_MIN := 6.0
const SPEED_MAX := 23.0
const TUBES := 6
const TUBE_GAP := 8.0
const TUBE_Y := 3.3

var _view
var _parts: Array[RigidBody3D] = []
var _joints: Array[Joint3D] = []
var _torso: RigidBody3D
var _angle := 0.55
var _power_t := 0.0
var _flying := false
var _still := 0.0
var _fly_t := 0.0
var _impacts := 0.0
var _spin := 0.0
var _last_v := Vector3.ZERO
var _best_x := 0.0
var _last_score := 0
var _dots: Array[MeshInstance3D] = []
var _tube_mats: Array[ShaderMaterial] = []
var _tube_on: Array[bool] = []
var _flicker_t := 0.0
var _rng := RandomNumberGenerator.new()
var _score_lbl: Label
var _live: Label
var _bar: ColorRect
var _bar_fill: ColorRect
var _fling: Button
var _lower: Button
var _raise: Button


func _ready() -> void:
	super._ready()
	_rng.randomize()
	frame("FALL GUY", Color(0.04, 0.04, 0.03), Color(0.85, 0.8, 0.5))
	_view = preload("res://scenes/ladder/view3d.gd").new()
	add_child(_view)
	var murk := Color(0.1, 0.11, 0.07)
	_view.setup(VIEW_AT, VIEW, 3, {
		"sky": murk, "ambient": Color(0.3, 0.3, 0.22),
		"fog_col": murk, "fog_near": 5.0, "fog_far": 22.0, "levels": 12.0,
		"grain": 0.07, "vignette": 0.75, "scan": 0.05, "tint": Color(0.55, 0.6, 0.2, 0.04), "flicker": 1.0,
	})
	_view.add_post(self)
	# More solver passes in this little world: joints stay tighter on big hits.
	PhysicsServer3D.space_set_param(_view.vp.find_world_3d().space, PhysicsServer3D.SPACE_PARAM_SOLVER_ITERATIONS, 32)
	_view.cam.fov = 58.0
	_build_course()
	_build_aim()
	_live = label("", 24, Color(0.9, 0.85, 0.55))
	_live.position = Vector2(0, 160)
	_live.size = Vector2(W, 40)
	_live.z_index = 5
	add_child(_live)
	_bar = ColorRect.new()
	_bar.color = Color(0.1, 0.1, 0.07)
	_bar.position = Vector2(60, 985)
	_bar.size = Vector2(W - 120, 22)
	add_child(_bar)
	_bar_fill = ColorRect.new()
	_bar_fill.size = Vector2(0, 22)
	_bar.add_child(_bar_fill)
	_score_lbl = label("", 20, Color(0.85, 0.82, 0.6, 0.8))
	_score_lbl.position = Vector2(0, 1018)
	_score_lbl.size = Vector2(W, 40)
	add_child(_score_lbl)
	var row := HBoxContainer.new()
	row.position = Vector2(30, 1070)
	row.size = Vector2(W - 60, 150)
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	_lower = button("ANGLE\n-", 26, Color(0.16, 0.15, 0.1), Color(0.8, 0.75, 0.5))
	_fling = button("FLING!", 40, Color(0.45, 0.12, 0.08), Color(0.9, 0.8, 0.5))
	_raise = button("ANGLE\n+", 26, Color(0.16, 0.15, 0.1), Color(0.8, 0.75, 0.5))
	for b in [_lower, _fling, _raise]:
		b.custom_minimum_size = Vector2(0, 140)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_fling.size_flags_stretch_ratio = 1.6
	_lower.pressed.connect(func(): _angle = clampf(_angle - 0.1, 0.1, 1.25))
	_raise.pressed.connect(func(): _angle = clampf(_angle + 0.1, 0.1, 1.25))
	_fling.pressed.connect(_on_fling)
	_fling.set_meta("pad_default", true)
	_reset_dummy()
	_score_lbl.text = "TIME THE POWER BAR. FLIPS = POINTS."


# ---------------------------------------------------------------- the corridor

func _build_course() -> void:
	var v = _view
	var lino: ShaderMaterial = v.mat(Color(0.36, 0.34, 0.24), {"pattern": 1, "col2": Color(0.28, 0.27, 0.19), "texel": 1.6})
	var wall: ShaderMaterial = v.mat(Color(0.45, 0.44, 0.33), {"pattern": 2, "col2": Color(0.3, 0.32, 0.24), "texel": 2.2})
	var ceil: ShaderMaterial = v.mat(Color(0.25, 0.25, 0.2), {"pattern": 4, "col2": Color(0.14, 0.14, 0.11), "texel": 1.0})
	var metal: ShaderMaterial = v.mat(Color(0.4, 0.42, 0.4), {"shine": 0.7})
	var rust: ShaderMaterial = v.mat(Color(0.38, 0.27, 0.18), {"pattern": 3, "col2": Color(0.25, 0.16, 0.1), "texel": 14.0})
	var wood: ShaderMaterial = v.mat(Color(0.42, 0.3, 0.2))
	var length := COURSE + 6.0
	var mid := COURSE * 0.5
	# Floor, ceiling, walls, the far wall.
	v.solid(Vector3(length, 0.2, HALF_Z * 2), Vector3(mid, -0.1, 0), lino, null, Vector3.ZERO, 0.15, 0.8)
	v.solid(Vector3(length, 0.2, HALF_Z * 2), Vector3(mid, CEIL + 0.1, 0), ceil, null, Vector3.ZERO, 0.3, 0.5)
	for s in [-1.0, 1.0]:
		v.solid(Vector3(length, CEIL, 0.2), Vector3(mid, CEIL * 0.5, s * (HALF_Z + 0.1)), wall, null, Vector3.ZERO, 0.2, 0.6)
		# A pipe running along each wall, near the ceiling.
		v.cyl(0.07, 0.07, length, Vector3(mid, CEIL - 0.35, s * (HALF_Z - 0.12)), rust, null, Vector3(0, 0, PI / 2), 6)
	v.solid(Vector3(0.3, CEIL, HALF_Z * 2), Vector3(COURSE + 0.15, CEIL * 0.5, 0), v.mat(Color(0.3, 0.12, 0.1), {"pattern": 4, "col2": Color(0.18, 0.06, 0.05), "texel": 1.2}), null, Vector3.ZERO, 0.3)
	v.solid(Vector3(0.3, CEIL, HALF_Z * 2), Vector3(-3.0, CEIL * 0.5, 0), wall)
	v.box(Vector3(0.05, 0.3, 1.0), Vector3(COURSE - 0.03, 2.9, 0), v.glow(Color(0.9, 0.08, 0.05)))
	v.text("EXIT", Vector3(COURSE - 0.06, 2.9, 0), 40, Color(1.0, 0.85, 0.8), null, Vector3(0, -PI / 2, 0), 0.006)
	# Fluorescent tubes: six real lights down the corridor; some of them die.
	for i in TUBES:
		var x := 1.0 + i * TUBE_GAP
		var m: ShaderMaterial = v.glow(Color(0.95, 0.95, 0.7))
		_tube_mats.append(m)
		_tube_on.append(true)
		v.box(Vector3(1.4, 0.06, 0.18), Vector3(x, TUBE_Y - 0.04, 0), m)
		v.box(Vector3(1.5, 0.05, 0.3), Vector3(x, TUBE_Y, 0), metal)
		for c in [-0.6, 0.6]:
			v.box(Vector3(0.02, CEIL - TUBE_Y, 0.02), Vector3(x + c, (CEIL + TUBE_Y) * 0.5, 0), metal)
		v.set_light(i, Vector3(x, TUBE_Y - 0.3, 0), Color(1.0, 0.92, 0.62), 7.0, 1.4)
	# The last light is the emergency red over the exit.
	v.set_light(TUBES - 1, Vector3(COURSE - 0.6, 3.0, 0), Color(1.0, 0.2, 0.12), 7.0, 1.2)
	# Notices on the walls.
	var notes := [["KEEP\nSMILING", 5.0, -1.0], ["DAYS WITHOUT\nAN INCIDENT\n0", 13.0, 1.0], ["HUMBLE HOUSE\nCARES", 21.0, -1.0], ["DO NOT\nRUN", 30.0, 1.0], ["STAY\nCALM", 38.0, -1.0]]
	for n in notes:
		var s: float = n[2]
		var z := -s * (HALF_Z - 0.005)
		v.box(Vector3(0.9, 0.9, 0.02), Vector3(n[1], 1.7, z), v.mat(Color(0.75, 0.72, 0.55)), null, Vector3(0, 0, 0.03 * s))
		v.text(n[0], Vector3(n[1], 1.7, z + s * 0.015), 22, Color(0.25, 0.08, 0.05), null, Vector3(0, 0 if s < 0 else PI, 0), 0.005)
	for i in 8:
		v.text("%dm" % ((i + 1) * 5), Vector3(START.x + (i + 1) * 5.0, 0.01, 1.2), 26, Color(0.85, 0.8, 0.5, 0.6), null, Vector3(-PI / 2, 0, 0), 0.008)
	# The launch desk.
	v.solid(Vector3(1.2, 0.75, 0.8), Vector3(0, 0.375, 0), wood)
	# Furniture: filing cabinets, a ramp, a flight of steps, bouncy chairs.
	for spot in [[7.0, 0.3], [16.5, -0.6], [29.0, 0.4]]:
		var cab: StaticBody3D = v.solid(Vector3(0.6, 1.35, 0.7), Vector3(spot[0], 0.675, spot[1]), metal, null, Vector3.ZERO, 0.2)
		for d in 3:
			v.box(Vector3(0.02, 0.05, 0.25), Vector3(-0.31, 0.3 - d * 0.42, 0), v.mat(Color(0.2, 0.2, 0.18)), cab)
	v.solid(Vector3(3.4, 0.12, 2.4), Vector3(12.5, 0.45, 0), wood, null, Vector3(0, 0, 0.28))
	for i in 5:
		var h := 0.25 * (i + 1)
		v.solid(Vector3(0.7, h, 3.0), Vector3(21.0 + i * 0.7, h * 0.5, 0), v.mat(Color(0.5, 0.48, 0.38), {"pattern": 2, "col2": Color(0.62, 0.55, 0.15), "texel": 6.0}))
	var chair: ShaderMaterial = v.mat(Color(0.2, 0.28, 0.4), {"shine": 0.4})
	for spot in [[10.0, -0.5], [25.5, 0.6], [35.0, -0.3]]:
		var c := StaticBody3D.new()
		c.position = Vector3(spot[0], 0.0, spot[1])
		var shape := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.45
		cy.height = 0.55
		shape.shape = cy
		shape.position.y = 0.275
		c.add_child(shape)
		var pm := PhysicsMaterial.new()
		pm.bounce = 1.0
		c.physics_material_override = pm
		v.cyl(0.45, 0.4, 0.14, Vector3(0, 0.5, 0), chair, c)
		v.cyl(0.04, 0.04, 0.45, Vector3(0, 0.22, 0), metal, c)
		v.box(Vector3(0.5, 0.5, 0.08), Vector3(0, 0.85, -0.38), chair, c)
		v.root.add_child(c)
	# Things to knock over: a water cooler, a stack of boxes.
	_loose(Vector3(19.0, 0.6, 0.5), Vector3(0.4, 1.2, 0.4), v.mat(Color(0.6, 0.75, 0.8), {"shine": 1.0}))
	for p in [Vector3(32.0, 0.3, -0.2), Vector3(32.0, 0.3, 0.45), Vector3(32.0, 0.9, 0.1), Vector3(32.6, 0.3, 0.1)]:
		_loose(p, Vector3(0.6, 0.6, 0.6), v.mat(Color(0.55, 0.42, 0.28), {"pattern": 2, "col2": Color(0.45, 0.33, 0.2), "texel": 3.0}))


func _loose(at: Vector3, dims: Vector3, m: ShaderMaterial) -> void:
	var b := RigidBody3D.new()
	b.position = at
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = dims
	shape.shape = bs
	b.add_child(shape)
	b.mass = 0.6
	_view.box(dims, Vector3.ZERO, m, b)
	_view.root.add_child(b)


func _build_aim() -> void:
	var m: ShaderMaterial = _view.glow(Color(1.0, 0.85, 0.35))
	for i in 10:
		_dots.append(_view.ball(0.05, Vector3.ZERO, m, null, 4))


# ---------------------------------------------------------------- the dummy

## Dummy materials, made once (every throw rebuilds the body, not these).
var _dm := {}
## Joint anchors, parent before child: {a, b, la, lb} (local on each body).
var _links: Array[Dictionary] = []


func _dummy_mats() -> void:
	var v = _view
	_dm = {
		"shirt": v.mat(Color(0.82, 0.8, 0.62), {"shine": 0.2}),
		"skin": v.mat(Color(0.86, 0.66, 0.52), {"shine": 0.3}),
		"pants": v.mat(Color(0.22, 0.24, 0.3)),
		"shoe": v.mat(Color(0.12, 0.08, 0.06), {"shine": 0.6}),
		"dark": v.mat(Color(0.04, 0.04, 0.04)),
		"hair": v.mat(Color(0.32, 0.22, 0.13)),
		"tie": v.mat(Color(0.5, 0.1, 0.36), {"shine": 0.5}),
		"belt": v.mat(Color(0.15, 0.1, 0.07), {"shine": 0.8}),
		"buckle": v.glow(Color(0.6, 0.5, 0.2)),
		"lens": v.glow(Color(0.5, 0.55, 0.5)),
	}


func _body(at: Vector3, shape: Shape3D, mass: float) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.position = at
	var cs := CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.25
	b.physics_material_override = pm
	b.mass = mass
	b.angular_damp = 0.05
	b.continuous_cd = true
	_view.root.add_child(b)
	_parts.append(b)
	return b


## A limb segment: a capsule body, with a ball at its top joint to hide the seam.
func _limb(at: Vector3, r: float, h: float, m: ShaderMaterial, mass: float) -> RigidBody3D:
	var c := CapsuleShape3D.new()
	c.radius = r
	c.height = h
	var b := _body(at, c, mass)
	_view.capsule(r, h, Vector3.ZERO, m, b)
	_view.ball(r * 1.08, Vector3(0, h * 0.5 - r, 0), m, b, 8)
	return b


func _pin(a: RigidBody3D, b: RigidBody3D, at: Vector3, swing := 70.0, twist := 40.0) -> void:
	var j := ConeTwistJoint3D.new()
	# The cone's axis (joint x) points from the socket down the child part,
	# so a limb hanging at rest sits in the middle of its cone.
	var axis := (b.position - at).normalized()
	var side := Vector3(0, 0, 1)
	j.transform = Transform3D(Basis(axis, side.cross(axis).normalized(), side), at)
	j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(swing))
	j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(twist))
	_view.root.add_child(j)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)
	_joints.append(j)
	_links.append({"a": a, "b": b, "la": a.transform.affine_inverse() * at, "lb": b.transform.affine_inverse() * at})


## The Dale-shaped dummy: rounded torso, a head with glasses, moustache and
## a horseshoe of hair, arms and legs in two pieces each (elbows, knees),
## hands and shoes. Built standing on the desk, facing down the corridor (+x).
func _reset_dummy() -> void:
	for j in _joints:
		j.queue_free()
	for p in _parts:
		p.queue_free()
	_joints.clear()
	_parts.clear()
	_links.clear()
	if _dm.is_empty():
		_dummy_mats()
	var v = _view
	var o := START
	# Torso: a squashed capsule shirt, trousers and belt at the bottom.
	var tb := BoxShape3D.new()
	tb.size = Vector3(0.24, 0.56, 0.36)
	_torso = _body(o, tb, 2.5)
	v.capsule(0.18, 0.6, Vector3(0, 0.02, 0), _dm.shirt, _torso).scale = Vector3(0.7, 1, 1)
	v.cyl(0.175, 0.175, 0.2, Vector3(0, -0.2, 0), _dm.pants, _torso).scale = Vector3(0.72, 1, 1)
	v.cyl(0.18, 0.18, 0.045, Vector3(0, -0.1, 0), _dm.belt, _torso).scale = Vector3(0.74, 1, 1)
	v.box(Vector3(0.03, 0.05, 0.05), Vector3(0.13, -0.1, 0), _dm.buckle, _torso)
	v.box(Vector3(0.02, 0.26, 0.055), Vector3(0.128, 0.08, 0), _dm.tie, _torso)
	v.box(Vector3(0.03, 0.05, 0.08), Vector3(0.122, 0.22, 0), _dm.tie, _torso)
	v.box(Vector3(0.06, 0.04, 0.2), Vector3(0.08, 0.26, 0), _dm.shirt, _torso, Vector3(0, 0, -0.3))
	v.cyl(0.055, 0.055, 0.12, Vector3(0, 0.3, 0), _dm.skin, _torso)
	for s in [-1.0, 1.0]:
		v.ball(0.075, Vector3(0, 0.2, s * 0.19), _dm.shirt, _torso, 8)
		v.ball(0.08, Vector3(0, -0.25, s * 0.09), _dm.pants, _torso, 8)
	# Head.
	var hs := SphereShape3D.new()
	hs.radius = 0.12
	var head := _body(o + Vector3(0, 0.43, 0), hs, 0.8)
	v.ball(0.12, Vector3.ZERO, _dm.skin, head, 10)
	v.ball(0.122, Vector3(-0.025, 0.02, 0), _dm.hair, head, 10).scale = Vector3(0.9, 0.75, 1.02)
	v.ball(0.105, Vector3(0.012, 0.035, 0), _dm.skin, head, 10)
	for s in [-1.0, 1.0]:
		v.box(Vector3(0.012, 0.042, 0.055), Vector3(0.112, 0.015, s * 0.042), _dm.dark, head)
		v.box(Vector3(0.006, 0.03, 0.04), Vector3(0.118, 0.015, s * 0.042), _dm.lens, head)
		v.ball(0.03, Vector3(-0.005, 0.0, s * 0.12), _dm.skin, head, 6)
	v.box(Vector3(0.012, 0.01, 0.03), Vector3(0.118, 0.015, 0), _dm.dark, head)
	v.box(Vector3(0.05, 0.03, 0.03), Vector3(0.125, -0.025, 0), _dm.skin, head)
	v.box(Vector3(0.02, 0.022, 0.085), Vector3(0.118, -0.058, 0), _dm.hair, head)
	_pin(_torso, head, o + Vector3(0, 0.3, 0), 40.0, 40.0)
	# Arms: upper arm, then forearm with the hand.
	for s in [-1.0, 1.0]:
		var upper := _limb(o + Vector3(0, 0.08, s * 0.25), 0.052, 0.32, _dm.shirt, 0.6)
		_pin(_torso, upper, o + Vector3(0, 0.21, s * 0.24), 80.0, 50.0)
		var fore := _limb(o + Vector3(0, -0.2, s * 0.25), 0.046, 0.3, _dm.shirt, 0.5)
		v.ball(0.05, Vector3(0, -0.17, 0), _dm.skin, fore, 6)
		_pin(upper, fore, o + Vector3(0, -0.06, s * 0.25), 65.0, 20.0)
		var thigh := _limb(o + Vector3(0, -0.45, s * 0.09), 0.072, 0.4, _dm.pants, 0.8)
		_pin(_torso, thigh, o + Vector3(0, -0.27, s * 0.09), 60.0, 25.0)
		var shin := _limb(o + Vector3(0, -0.82, s * 0.09), 0.06, 0.38, _dm.pants, 0.6)
		v.box(Vector3(0.22, 0.07, 0.1), Vector3(0.05, -0.19, 0), _dm.shoe, shin)
		_pin(thigh, shin, o + Vector3(0, -0.64, s * 0.09), 60.0, 15.0)
	for a in _parts:
		for b in _parts:
			if a != b:
				a.add_collision_exception_with(b)
		a.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		a.freeze = true
	_flying = false


## Physics joints stretch when something hits hard enough; this keeps every
## joint shut so the dummy never comes apart: each child part is moved back
## onto its socket (parents first) and takes on some of the parent's speed.
func _hold_together() -> void:
	for l in _links:
		var a: RigidBody3D = l.a
		var b: RigidBody3D = l.b
		var wa: Vector3 = a.global_transform * l.la
		var wb: Vector3 = b.global_transform * l.lb
		var gap := wa - wb
		if gap.length() < 0.012:
			continue
		var t := b.global_transform
		t.origin += gap
		b.global_transform = t
		PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)
		var va := a.linear_velocity + a.angular_velocity.cross(wa - a.global_position)
		b.linear_velocity = b.linear_velocity.lerp(va, 0.5)


func _on_fling() -> void:
	if _flying:
		return
	if not pay_token():
		return
	var power := _power()
	var vel := _launch_dir() * lerpf(SPEED_MIN, SPEED_MAX, power)
	for p in _parts:
		p.freeze = false
		p.linear_velocity = vel
		p.angular_velocity = Vector3.ZERO
	_torso.angular_velocity = Vector3(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-1.0, 1.0), -15.0 * power)
	_flying = true
	_still = 0.0
	_fly_t = 0.0
	_impacts = 0.0
	_spin = 0.0
	_last_v = _torso.linear_velocity
	_best_x = _torso.position.x
	_fling.disabled = true
	for d in _dots:
		d.visible = false
	sfx("thump")


func _launch_dir() -> Vector3:
	return Vector3(cos(_angle), sin(_angle), 0)


func _power() -> float:
	return 0.5 - 0.5 * cos(_power_t * 3.4)


func _physics_process(delta: float) -> void:
	if not _flying:
		return
	_hold_together()
	_fly_t += delta
	var v := _torso.linear_velocity
	var dv := (v - _last_v).length()
	if dv > 3.5:
		_impacts += (dv - 3.5) * 9.0
		if dv > 5.0:
			sfx("thump", -10.0 + minf(dv, 12.0), _rng.randf_range(0.8, 1.1))
	_last_v = v
	_spin += _torso.angular_velocity.length() * delta
	_best_x = maxf(_best_x, _torso.position.x)
	_still = _still + delta if v.length() < 0.25 else 0.0
	if _still > 1.0 or _fly_t > 9.0 or _torso.position.y < -5.0:
		_land()


func _distance() -> float:
	return maxf(0.0, _best_x - START.x)


func _spins() -> int:
	return int(absf(_spin) / TAU)


func _land() -> void:
	_flying = false
	var style: bool = hub != null and hub.state.has("style")
	var score := ArcadeRules.ragdoll_score(_distance(), _impacts, _spins(), style)
	_last_score = score
	var tickets := ArcadeRules.ragdoll_tickets(score)
	var beats := score >= ArcadeRules.RAGDOLL_BEAT
	win(tickets, "ragdoll", beats)
	sfx("jackpot" if beats else ("ding" if tickets > 20 else "groan"))
	banner("%d POINTS\n+%d TICKETS%s" % [score, tickets, "\nMACHINE BEATEN!" if beats else ""], 3.0)
	_score_lbl.text = "%.1fm  CRASHES %d  FLIPS %d%s" % [_distance(), int(_impacts), _spins(), " x2" if style else ""]
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_callback(func():
		_reset_dummy()
		_fling.disabled = false)


func _process(delta: float) -> void:
	super._process(delta)
	var cam: Camera3D = _view.cam
	if not _flying:
		_power_t += delta
		var p := _power()
		_live.text = "POWER %d%%   ANGLE %d" % [roundi(p * 100), roundi(rad_to_deg(_angle))]
		_bar_fill.size.x = _bar.size.x * p
		_bar_fill.color = Color(0.9, 0.75 - 0.5 * p, 0.25)
		# The arc it'll fly, as dots.
		var vel := _launch_dir() * lerpf(SPEED_MIN, SPEED_MAX, p)
		for i in _dots.size():
			var t := 0.05 + i * 0.07
			_dots[i].visible = true
			_dots[i].position = START + vel * t + Vector3(0, -4.9 * t * t, 0)
		var want := Vector3(-2.0, 2.0, 1.5)
		cam.position = cam.position.lerp(want, minf(1.0, delta * 3.0))
		cam.look_at(Vector3(3.0, 1.2, 0))
	elif _torso:
		# Again just before drawing, so a hard hit never shows a gap.
		_hold_together()
		var style: bool = hub != null and hub.state.has("style")
		_live.text = "%d POINTS" % ArcadeRules.ragdoll_score(_distance(), _impacts, _spins(), style)
		var at := _torso.position
		var want := Vector3(at.x - 3.0, clampf(at.y + 1.0, 0.8, CEIL - 0.4), clampf(at.z + 1.6, -HALF_Z + 0.3, HALF_Z - 0.3))
		cam.position = cam.position.lerp(want, minf(1.0, delta * 4.0))
		cam.look_at(at + Vector3(1.2, -0.1, 0))
	# A slight dutch tilt, breathing.
	cam.rotate_object_local(Vector3.FORWARD, 0.05 + sin(Time.get_ticks_msec() * 0.0007) * 0.015)
	_flicker(delta)


## The tubes buzz: now and then one stutters off and back on.
func _flicker(delta: float) -> void:
	_flicker_t -= delta
	if _flicker_t > 0.0:
		return
	_flicker_t = _rng.randf_range(0.05, 0.4)
	for i in TUBES - 1:
		var on := _rng.randf() > (0.35 if i % 2 == 1 else 0.06)
		if on == _tube_on[i]:
			continue
		_tube_on[i] = on
		var x := 1.0 + i * TUBE_GAP
		_tube_mats[i].set_shader_parameter("emission", Color(0.95, 0.95, 0.7) if on else Color(0.12, 0.12, 0.1))
		_view.set_light(i, Vector3(x, TUBE_Y - 0.3, 0), Color(1.0, 0.92, 0.62), 7.0, 1.4 if on else 0.2)
