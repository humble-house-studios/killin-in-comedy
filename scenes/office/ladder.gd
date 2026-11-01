extends Node
## The ladder: the rooms past the office door, built into the office's own 3D
## world so walking, sitting at screens, touch, mouse and the controller all
## work the same. Dale's last chapter opens the office door. Then:
##   ARCADE (z 4-12): claw machine, coin pusher, the FALL GUY ragdoll cabinet
##     and the prize counter; five coworkers on break to talk to (Gloria,
##     Kev, Bernie, Theo and, once two machines are beaten, Ray). Tokens in,
##     tickets out; the DOOR KEY opens the next door. Ray's key opens the
##     basement ARCHIVE off the west wall.
##   TRADING FLOOR (z 12-20): your tickets cash out as a portfolio; double it.
##   BOARDROOM (z 20-26): pitch the board, three yeses of five.
##   CORNER OFFICE (z 26-32): the founder's memo on the desk, a 3D mini-golf toy.
##   THE STAGE (z 32-40): an open mic. Land your set. With every secret and
##     the archive found, Dale is in the crowd for the true ending.
## Each screen is a machine scene (scenes/ladder/) in its own SubViewport,
## added with the office's _add_computer(). Rooms out of reach are hidden and
## their machines paused. Rules: engine/ladder_state.gd, engine/coworkers.gd.
## Design: docs/narrative.md (The Ladder).

const MACHINE_PX := Vector2i(720, 1280)
const CAB_SCREEN := Vector2(0.36, 0.64)
const DOOR_W := 1.0
const DOOR_H := 2.1
## z where each room starts (its front wall), in walking order.
const ROOM_Z := {"office": -3.0, "arcade": 4.1, "trading": 12.2, "boardroom": 20.3, "corner": 26.4, "stage": 32.5}
const ROOM_END := 40.5
const ORDER := ["office", "arcade", "trading", "boardroom", "corner", "stage"]
const ARCHIVE := Rect2(-8.6, 5.6, 5.0, 3.8)
## Where each coworker stands, and which way they face (toward the middle).
const NPC_SPOTS := {
	"gloria": [Vector3(-2.15, 0, 5.15), 0.65], "kev": [Vector3(2.15, 0, 5.9), -0.8],
	"bernie": [Vector3(-2.2, 0, 9.85), 2.27], "theo": [Vector3(2.0, 0, 11.0), -2.55],
	"ray": [Vector3(-2.75, 0, 11.35), 2.45],
}

var office: Node
var state: LadderState
var crew: Coworkers

var _rooms := {}
var _doors := {}
var _machines := {}
var _people := {}
var _room := "office"
var _visible_rooms := {}
var _check := 0.0
var _ticker: Label3D
var _ticker_x := 0.0
var _memo_node: Node3D
var _stage_dale: Node3D
var _crowd := {}
var _talk_id := ""
var _time := 0.0
var _locked_hint := ""
var _doors_ready := false
## Look Busy's boss is coming through the shut office door: show the arcade.
var _peek := false
## What the office's goal marker is over: its "!" (if any) hides.
var goal_id := ""


func setup(o: Node) -> void:
	office = o
	state = LadderState.new()
	crew = Coworkers.new()


# ---------------------------------------------------------------- materials

## The office's PS1 material, lit by this room's lights.
func _mat(room: String, albedo: Color, pattern := 0, albedo2 := Color.BLACK, texel := 24.0, emission := Color.BLACK) -> ShaderMaterial:
	var m: ShaderMaterial = office._mat(albedo, pattern, albedo2, texel, emission)
	var L: Dictionary = _light(room)
	m.set_shader_parameter("office_lights", 0.0 if room != "office" else 1.0)
	m.set_shader_parameter("room_pos", L.pos)
	m.set_shader_parameter("room_col", L.col)
	m.set_shader_parameter("room_range", L.range)
	m.set_shader_parameter("room_ambient", L.amb)
	m.set_shader_parameter("room_fog", L.fog)
	return m


func _glow(room: String, c: Color) -> ShaderMaterial:
	return _mat(room, Color.BLACK, 0, Color.BLACK, 24.0, c)


var _lights_cache := {}

func _light(room: String) -> Dictionary:
	if _lights_cache.has(room):
		return _lights_cache[room]
	var z: float = ROOM_Z.get(room, 0.0)
	var L := {}
	match room:
		"arcade":
			L = {"amb": Vector3(0.3, 0.24, 0.38), "fog": Vector3(0.12, 0.06, 0.18), "range": 4.5, "pos": [
				Vector3(-2.6, 2.2, 6.0), Vector3(2.6, 2.2, 7.0), Vector3(-2.6, 2.2, 8.8), Vector3(2.6, 2.2, 10.0), Vector3(0, 2.6, 8.0), Vector3(0, 2.0, 11.5)],
				"col": [Vector3(0.9, 0.3, 0.6), Vector3(0.25, 0.8, 0.75), Vector3(0.9, 0.5, 0.2), Vector3(0.9, 0.75, 0.3), Vector3(0.45, 0.4, 0.6), Vector3(0.4, 0.3, 0.7)]}
		"archive":
			L = {"amb": Vector3(0.2, 0.22, 0.28), "fog": Vector3(0.05, 0.05, 0.07), "range": 4.0, "pos": [
				Vector3(-6.2, 2.2, 7.4), Vector3(-4.2, 1.2, 7.4), Vector3(-8, 1, 6), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO],
				"col": [Vector3(0.9, 0.75, 0.45), Vector3(0.3, 0.3, 0.4), Vector3(0.2, 0.25, 0.35), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]}
		"trading":
			L = {"amb": Vector3(0.42, 0.48, 0.44), "fog": Vector3(0.25, 0.32, 0.27), "range": 5.0, "pos": [
				Vector3(-1.8, 2.7, z + 2.0), Vector3(1.8, 2.7, z + 2.0), Vector3(-1.8, 2.7, z + 6.0), Vector3(1.8, 2.7, z + 6.0), Vector3(0, 2.0, z + 7.8), Vector3(-1.5, 1.3, z + 3.6)],
				"col": [Vector3(0.6, 0.7, 0.62), Vector3(0.6, 0.7, 0.62), Vector3(0.6, 0.7, 0.62), Vector3(0.6, 0.7, 0.62), Vector3(0.2, 0.7, 0.3), Vector3(0.2, 0.6, 0.3)]}
		"boardroom":
			L = {"amb": Vector3(0.36, 0.3, 0.26), "fog": Vector3(0.3, 0.24, 0.2), "range": 4.5, "pos": [
				Vector3(-0.6, 2.6, z + 1.8), Vector3(-0.6, 2.6, z + 4.2), Vector3(-0.6, 1.6, z + 5.8), Vector3(2.5, 2.4, z + 3.0), Vector3.ZERO, Vector3.ZERO],
				"col": [Vector3(0.85, 0.7, 0.5), Vector3(0.85, 0.7, 0.5), Vector3(0.4, 0.5, 0.8), Vector3(0.5, 0.42, 0.3), Vector3.ZERO, Vector3.ZERO]}
		"corner":
			L = {"amb": Vector3(0.48, 0.38, 0.32), "fog": Vector3(0.62, 0.45, 0.35), "range": 5.5, "pos": [
				Vector3(3.2, 1.6, z + 2.0), Vector3(3.2, 1.6, z + 4.5), Vector3(0, 2.6, z + 3.0), Vector3(0.2, 1.2, z + 3.4), Vector3.ZERO, Vector3.ZERO],
				"col": [Vector3(1.0, 0.6, 0.3), Vector3(1.0, 0.55, 0.3), Vector3(0.6, 0.55, 0.45), Vector3(0.3, 0.3, 0.2), Vector3.ZERO, Vector3.ZERO]}
		"stage":
			L = {"amb": Vector3(0.24, 0.17, 0.22), "fog": Vector3(0.08, 0.04, 0.08), "range": 4.5, "pos": [
				Vector3(0, 2.7, z + 6.3), Vector3(-2.0, 1.4, z + 2.4), Vector3(2.0, 1.4, z + 2.4), Vector3(0, 1.6, z + 4.0), Vector3(-3.0, 2.4, z + 0.5), Vector3(0, 0.8, z + 6.8)],
				"col": [Vector3(1.0, 0.9, 0.7), Vector3(0.5, 0.25, 0.3), Vector3(0.5, 0.25, 0.3), Vector3(0.3, 0.2, 0.35), Vector3(0.6, 0.1, 0.1), Vector3(0.5, 0.45, 0.35)]}
		_:
			L = {"amb": Vector3(-1, -1, -1), "fog": Vector3(-1, -1, -1), "range": 0.0, "pos": [], "col": []}
	var pos := PackedVector3Array(L.pos)
	var col := PackedVector3Array(L.col)
	while pos.size() < 6:
		pos.append(Vector3.ZERO)
		col.append(Vector3.ZERO)
	L.pos = pos
	L.col = col
	_lights_cache[room] = L
	return L


func _box(size: Vector3, pos: Vector3, mat: Material, solid := false, rot := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	return office._box(size, pos, mat, solid, rot, parent)


func _cyl(radius: float, height: float, pos: Vector3, mat: Material, parent: Node, rot := Vector3.ZERO, sides := 8, top := -1.0) -> MeshInstance3D:
	return office._cyl(radius, height, pos, mat, rot, sides, top, parent)


func _label(text: String, pos: Vector3, size: int, color: Color, parent: Node, rot := Vector3.ZERO, width := 0.0) -> Label3D:
	return office._label(text, pos, size, color, rot, width, parent)


# ---------------------------------------------------------------- building

## Called by the office while it builds its room. The office's south wall has
## a gap where its door is; the door itself lives here.
func build() -> void:
	for room in ORDER:
		if room == "office":
			continue
		var n := Node3D.new()
		n.name = room
		office._world_vp.add_child(n)
		_rooms[room] = n
	var arch := Node3D.new()
	arch.name = "archive"
	office._world_vp.add_child(arch)
	_rooms["archive"] = arch
	_office_door()
	_build_arcade()
	_build_archive()
	_build_trading()
	_build_boardroom()
	_build_corner()
	_build_stage()
	_refresh_people()
	_update_rooms(true)


## Walls, floor and ceiling of one room spanning z0..z1 (x -3.5..3.5), with
## the door gap in its far wall at door_x (none for the last room).
func _shell(room: String, z0: float, z1: float, h: float, wall: Material, floor_mat: Material, ceil_mat: Material, door_x: float, front_door_x: float, west_door_z := -99.0) -> void:
	var p: Node3D = _rooms[room]
	var depth := z1 - z0
	var cz := (z0 + z1) * 0.5
	# This room's face of the wall you came through (the far side belongs to
	# the room before), with the same door gap.
	_wall_with_door(p, z0 + 0.05, h, front_door_x, wall)
	_box(Vector3(7.2, 0.1, depth + 0.1), Vector3(0, -0.05, cz), floor_mat, true, Vector3.ZERO, p)
	_box(Vector3(7.2, 0.1, depth + 0.1), Vector3(0, h + 0.05, cz), ceil_mat, true, Vector3.ZERO, p)
	# East wall, and the west wall (split around a side door if there is one).
	_box(Vector3(0.1, h, depth), Vector3(3.55, h * 0.5, cz), wall, true, Vector3.ZERO, p)
	if west_door_z > -90.0:
		var a := west_door_z - DOOR_W * 0.5
		var b := west_door_z + DOOR_W * 0.5
		_box(Vector3(0.1, h, a - z0), Vector3(-3.55, h * 0.5, (z0 + a) * 0.5), wall, true, Vector3.ZERO, p)
		_box(Vector3(0.1, h, z1 - b), Vector3(-3.55, h * 0.5, (b + z1) * 0.5), wall, true, Vector3.ZERO, p)
		_box(Vector3(0.1, h - DOOR_H, DOOR_W), Vector3(-3.55, DOOR_H + (h - DOOR_H) * 0.5, west_door_z), wall, true, Vector3.ZERO, p)
	else:
		_box(Vector3(0.1, h, depth), Vector3(-3.55, h * 0.5, cz), wall, true, Vector3.ZERO, p)
	if door_x > -90.0:
		_wall_with_door(p, z1 + 0.05, h, door_x, wall)
	else:
		_box(Vector3(7.2, h, 0.1), Vector3(0, h * 0.5, z1 + 0.05), wall, true, Vector3.ZERO, p)


func _wall_with_door(p: Node3D, z: float, h: float, door_x: float, wall: Material) -> void:
	var a := door_x - DOOR_W * 0.5
	var b := door_x + DOOR_W * 0.5
	_box(Vector3(a + 3.6, h, 0.1), Vector3((-3.6 + a) * 0.5, h * 0.5, z), wall, true, Vector3.ZERO, p)
	_box(Vector3(3.6 - b, h, 0.1), Vector3((b + 3.6) * 0.5, h * 0.5, z), wall, true, Vector3.ZERO, p)
	_box(Vector3(DOOR_W, h - DOOR_H, 0.1), Vector3(door_x, DOOR_H + (h - DOOR_H) * 0.5, z), wall, true, Vector3.ZERO, p)


## A door in a gap: a hinged panel that swings open once it's unlocked.
## along_x: the door sits in a wall that runs along x (faces z); else along z.
func _door(id: String, room: String, center: Vector3, along_x: bool, color: Color, sign_text := "") -> void:
	var p: Node = _rooms[room] if _rooms.has(room) else office._world_vp
	var hinge := Node3D.new()
	hinge.position = center + (Vector3(-DOOR_W * 0.5, 0, 0) if along_x else Vector3(0, 0, -DOOR_W * 0.5))
	p.add_child(hinge)
	var wood := _mat(room, color, 3, color.darkened(0.15), 40.0)
	var size := Vector3(DOOR_W - 0.04, DOOR_H - 0.02, 0.05) if along_x else Vector3(0.05, DOOR_H - 0.02, DOOR_W - 0.04)
	var off := Vector3(DOOR_W * 0.5, DOOR_H * 0.5, 0) if along_x else Vector3(0, DOOR_H * 0.5, DOOR_W * 0.5)
	var panel := _box(size, off, wood, true, Vector3.ZERO, hinge)
	var knob := _mat(room, Color(0.85, 0.75, 0.4))
	for side in [-1.0, 1.0]:
		var k := Vector3(DOOR_W * 0.82, 1.0, side * 0.05) if along_x else Vector3(side * 0.05, 1.0, DOOR_W * 0.82)
		_box(Vector3(0.06, 0.04, 0.05), k, knob, false, Vector3.ZERO, hinge)
	var lock := _label("LOCKED", off + (Vector3(0, 0.45, 0.03) if along_x else Vector3(0.03, 0.45, 0)), 14, Color(1.0, 0.4, 0.35), hinge, Vector3(0, 0 if along_x else PI / 2, 0))
	var lock_back := _label("LOCKED", off + (Vector3(0, 0.45, -0.03) if along_x else Vector3(-0.03, 0.45, 0)), 14, Color(1.0, 0.4, 0.35), hinge, Vector3(0, PI if along_x else -PI / 2, 0))
	if sign_text != "":
		var s := _label(sign_text, center + (Vector3(0, DOOR_H + 0.18, -0.07) if along_x else Vector3(0.07, DOOR_H + 0.18, 0)), 16, Color(1.0, 0.85, 0.4), p, Vector3(0, PI if along_x else PI / 2, 0))
		s.double_sided = true
	_doors[id] = {"hinge": hinge, "panel": panel, "open": false, "center": center, "locks": [lock, lock_back], "along_x": along_x}


func _office_door() -> void:
	_door("office", "office", Vector3(1.8, 0, 4.05), true, Color(0.6, 0.42, 0.26), "")


func _cabinet(room: String, at: Vector3, rot_y: float, body_col: Color, title: String, title_col: Color, machine: String, script: String) -> void:
	var p: Node3D = _rooms[room]
	var rig := Node3D.new()
	rig.position = at
	rig.rotation.y = rot_y
	p.add_child(rig)
	var cy := 1.28
	match machine:
		"claw":
			_crane_cabinet(room, rig, body_col, title, title_col, cy)
		"pusher":
			_pusher_cabinet(room, rig, body_col, title, title_col, cy)
		_:
			_upright_cabinet(room, rig, body_col, title, title_col, cy)
	var screen := Node3D.new()
	screen.position = Vector3(0, cy, 0.182)
	rig.add_child(screen)
	_machine(machine, script, room, screen, CAB_SCREEN)


## Bits every cabinet shares: the bezel round the screen, a coin door with
## lit slots, chaser bulbs along a line.
func _bezel(room: String, rig: Node3D, cy: float, col: Color) -> void:
	_box(Vector3(CAB_SCREEN.x + 0.1, CAB_SCREEN.y + 0.1, 0.03), Vector3(0, cy, 0.158), _mat(room, col.darkened(0.35), 6, col.darkened(0.6), 60.0), false, Vector3.ZERO, rig)
	_box(Vector3(CAB_SCREEN.x + 0.035, CAB_SCREEN.y + 0.035, 0.02), Vector3(0, cy, 0.168), _mat(room, Color(0.02, 0.02, 0.03)), false, Vector3.ZERO, rig)


func _coin_door(room: String, rig: Node3D, at: Vector3, slots := 2) -> void:
	var steel := _mat(room, Color(0.55, 0.55, 0.58), 6, Color(0.4, 0.4, 0.44), 80.0)
	_box(Vector3(0.3, 0.3, 0.02), at, steel, false, Vector3.ZERO, rig)
	for i in slots:
		var x := (i - (slots - 1) * 0.5) * 0.11
		_box(Vector3(0.07, 0.09, 0.012), at + Vector3(x, 0.05, 0.014), _glow(room, Color(0.9, 0.15, 0.1)), false, Vector3.ZERO, rig)
		_box(Vector3(0.008, 0.04, 0.01), at + Vector3(x, 0.05, 0.022), _mat(room, Color(0.05, 0.05, 0.05)), false, Vector3.ZERO, rig)
	_box(Vector3(0.22, 0.05, 0.012), at + Vector3(0, -0.08, 0.014), _mat(room, Color(0.2, 0.2, 0.22)), false, Vector3.ZERO, rig)


func _bulbs(room: String, rig: Node3D, from: Vector3, to: Vector3, n: int) -> void:
	for i in n:
		var t := float(i) / maxf(1.0, n - 1)
		var c := Color(1.0, 0.92, 0.55) if i % 2 == 0 else Color(1.0, 0.55, 0.3)
		office._ball(0.018, from.lerp(to, t), _glow(room, c), rig)


## CLAW KING: a crane cabinet. Base with a prize door and a control ledge
## (joystick, big DROP button), a glass case on chrome posts (the screen is
## its front window, plush stacked behind the side panes), a lit canopy.
func _crane_cabinet(room: String, rig: Node3D, body_col: Color, title: String, title_col: Color, cy: float) -> void:
	var body := _mat(room, body_col, 6, body_col.darkened(0.25), 30.0)
	var stripe := _mat(room, title_col.darkened(0.15), 6, title_col.darkened(0.4), 40.0)
	var chrome := _mat(room, Color(0.78, 0.78, 0.84), 6, Color(0.6, 0.6, 0.68), 90.0)
	var dark := _mat(room, Color(0.04, 0.03, 0.05))
	var glass := _mat(room, Color(0.12, 0.16, 0.22), 6, Color(0.2, 0.26, 0.34), 30.0, Color(0.03, 0.04, 0.06))
	# Base.
	_box(Vector3(0.82, 0.9, 0.7), Vector3(0, 0.45, -0.17), body, true, Vector3.ZERO, rig)
	_box(Vector3(0.84, 0.06, 0.72), Vector3(0, 0.03, -0.17), dark, false, Vector3.ZERO, rig)
	_box(Vector3(0.84, 0.07, 0.72), Vector3(0, 0.62, -0.17), stripe, false, Vector3.ZERO, rig)
	# Prize door, bottom left, and the coin door, bottom right.
	_box(Vector3(0.26, 0.26, 0.02), Vector3(-0.2, 0.3, 0.19), chrome, false, Vector3.ZERO, rig)
	_box(Vector3(0.2, 0.18, 0.02), Vector3(-0.2, 0.3, 0.2), dark, false, Vector3.ZERO, rig)
	_label("PRIZE", Vector3(-0.2, 0.47, 0.19), 12, Color(1.0, 0.85, 0.4), rig)
	_coin_door(room, rig, Vector3(0.2, 0.3, 0.19), 1)
	# Control ledge: joystick and the DROP button.
	_box(Vector3(0.84, 0.06, 0.3), Vector3(0, 0.86, 0.26), _mat(room, Color(0.08, 0.06, 0.1)), false, Vector3(0.12, 0, 0), rig)
	_box(Vector3(0.84, 0.16, 0.02), Vector3(0, 0.79, 0.41), stripe, false, Vector3.ZERO, rig)
	_cyl(0.012, 0.07, Vector3(-0.18, 0.92, 0.28), chrome, rig)
	office._ball(0.032, Vector3(-0.18, 0.96, 0.28), _mat(room, Color(0.9, 0.1, 0.15)), rig)
	_cyl(0.055, 0.03, Vector3(0.17, 0.9, 0.27), _glow(room, Color(1.0, 0.2, 0.55)), rig)
	_label("1 TOKEN", Vector3(0, 0.66, 0.19), 14, Color(1.0, 0.85, 0.4), rig)
	# The glass case: chrome posts, tinted side panes with plush behind them.
	for x in [-0.4, 0.4]:
		for z in [0.16, -0.5]:
			_box(Vector3(0.035, 0.86, 0.035), Vector3(x, 1.36, z), chrome, false, Vector3.ZERO, rig)
	_box(Vector3(0.8, 0.86, 0.02), Vector3(0, 1.36, -0.5), _mat(room, Color(0.2, 0.06, 0.22), 6, title_col.darkened(0.5), 12.0), false, Vector3.ZERO, rig)
	for x in [-0.4, 0.4]:
		_box(Vector3(0.015, 0.86, 0.64), Vector3(x, 1.36, -0.17), glass, false, Vector3.ZERO, rig)
	_box(Vector3(0.76, 0.02, 0.62), Vector3(0, 0.93, -0.17), _mat(room, Color(0.35, 0.1, 0.32), 6, title_col.darkened(0.3), 30.0), false, Vector3.ZERO, rig)
	for side in [-1.0, 1.0]:
		var plush := [Color(1.0, 0.85, 0.2), Color(0.62, 0.4, 0.22), Color(0.95, 0.45, 0.6), Color(0.45, 0.75, 1.0)]
		for k in 5:
			office._ball(0.06, Vector3(side * (0.24 + (k % 2) * 0.08), 0.99 + (k / 2) * 0.09, 0.05 - (k % 3) * 0.08), _mat(room, plush[(k + int(side)) % 4]), rig)
	_bezel(room, rig, cy, Color(0.75, 0.75, 0.8))
	_box(Vector3(0.84, 0.04, 0.72), Vector3(0, 1.8, -0.17), chrome, false, Vector3.ZERO, rig)
	# Canopy: a lit sign box with chaser bulbs round its face.
	_box(Vector3(0.84, 0.3, 0.5), Vector3(0, 1.97, -0.1), _glow(room, title_col * 0.12), false, Vector3.ZERO, rig)
	_label(title, Vector3(0, 1.97, 0.16), 44, title_col.lightened(0.35), rig)
	_bulbs(room, rig, Vector3(-0.38, 2.12, 0.16), Vector3(0.38, 2.12, 0.16), 9)
	_bulbs(room, rig, Vector3(-0.38, 1.82, 0.16), Vector3(0.38, 1.82, 0.16), 9)
	_box(Vector3(0.02, 0.86, 0.02), Vector3(-0.42, 1.36, 0.17), _glow(room, title_col), false, Vector3.ZERO, rig)
	_box(Vector3(0.02, 0.86, 0.02), Vector3(0.42, 1.36, 0.17), _glow(room, title_col), false, Vector3.ZERO, rig)


## PUSH YOUR LUCK: a coin-pusher tower. Wide base with a coin tray full of
## coins, a ledge with two coin slots, light columns either side of the
## window, an arched marquee with a big gold coin on top.
func _pusher_cabinet(room: String, rig: Node3D, body_col: Color, title: String, title_col: Color, cy: float) -> void:
	var body := _mat(room, body_col, 6, body_col.darkened(0.3), 30.0)
	var chrome := _mat(room, Color(0.78, 0.8, 0.84), 6, Color(0.6, 0.62, 0.68), 90.0)
	var dark := _mat(room, Color(0.03, 0.05, 0.06))
	var gold := _mat(room, Color(0.95, 0.75, 0.25), 6, Color(0.8, 0.6, 0.15), 60.0, Color(0.15, 0.1, 0.0))
	_box(Vector3(0.95, 0.85, 0.75), Vector3(0, 0.425, -0.2), body, true, Vector3.ZERO, rig)
	_box(Vector3(0.97, 0.06, 0.77), Vector3(0, 0.03, -0.2), dark, false, Vector3.ZERO, rig)
	# Coin tray: a dark recess heaped with coins.
	_box(Vector3(0.5, 0.12, 0.12), Vector3(0, 0.3, 0.2), chrome, false, Vector3.ZERO, rig)
	_box(Vector3(0.44, 0.08, 0.1), Vector3(0, 0.33, 0.21), dark, false, Vector3.ZERO, rig)
	for i in 9:
		_cyl(0.03, 0.008, Vector3(-0.17 + i * 0.043, 0.3 + (i % 3) * 0.008, 0.22 - (i % 2) * 0.03), gold, rig, Vector3(0.3, 0, 0.2 * (i % 3 - 1)), 8)
	_label("TICKETS OUT", Vector3(0, 0.42, 0.19), 12, title_col, rig)
	_coin_door(room, rig, Vector3(0.33, 0.6, 0.19), 1)
	_coin_door(room, rig, Vector3(-0.33, 0.6, 0.19), 1)
	# Ledge.
	_box(Vector3(0.97, 0.05, 0.26), Vector3(0, 0.86, 0.26), chrome, false, Vector3(0.1, 0, 0), rig)
	_cyl(0.05, 0.03, Vector3(0, 0.9, 0.28), _glow(room, Color(0.3, 1.0, 0.85)), rig)
	_label("1 TOKEN = 5 COINS", Vector3(0, 0.76, 0.19), 12, Color(1.0, 0.85, 0.4), rig)
	# The upper hood: window in the middle, light columns either side.
	_box(Vector3(0.95, 0.9, 0.5), Vector3(0, 1.35, -0.1), body, false, Vector3.ZERO, rig)
	_bezel(room, rig, cy, title_col)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.18, 0.86, 0.04), Vector3(side * 0.37, 1.35, 0.16), dark, false, Vector3.ZERO, rig)
		for k in 7:
			var c := Color(1.0, 0.85, 0.3) if k % 2 == 0 else title_col
			_box(Vector3(0.12, 0.07, 0.015), Vector3(side * 0.37, 1.0 + k * 0.115, 0.185), _glow(room, c * (0.9 if k % 2 == 0 else 0.7)), false, Vector3.ZERO, rig)
	# Arched marquee and a big coin on top.
	_box(Vector3(0.97, 0.26, 0.5), Vector3(0, 1.93, -0.1), _glow(room, title_col * 0.12), false, Vector3.ZERO, rig)
	_box(Vector3(0.7, 0.12, 0.46), Vector3(0, 2.11, -0.1), _glow(room, title_col * 0.25), false, Vector3.ZERO, rig)
	_label(title, Vector3(0, 1.93, 0.16), 36, title_col.lightened(0.3), rig)
	_bulbs(room, rig, Vector3(-0.45, 1.81, 0.16), Vector3(0.45, 1.81, 0.16), 11)
	_cyl(0.16, 0.04, Vector3(0, 2.36, -0.1), gold, rig, Vector3(PI / 2, 0, 0), 14)
	_label("$", Vector3(0, 2.36, -0.075), 64, Color(0.5, 0.3, 0.0), rig)


## FALL GUY: a classic upright video cabinet. Side panels in the familiar
## profile (kick plate, coin door, jutting control panel, recessed screen,
## overhanging marquee), coloured trim down the edges, a big FLING button.
func _upright_cabinet(room: String, rig: Node3D, body_col: Color, title: String, title_col: Color, cy: float) -> void:
	var body := _mat(room, body_col, 6, body_col.darkened(0.3), 30.0)
	var side_art := _mat(room, body_col.darkened(0.2), 6, title_col.darkened(0.35), 10.0)
	var dark := _mat(room, Color(0.04, 0.03, 0.03))
	var trim := _glow(room, title_col * 0.8)
	# Back and the two side panels, with their profile.
	_box(Vector3(0.66, 1.95, 0.5), Vector3(0, 0.975, -0.25), body, true, Vector3.ZERO, rig)
	for side in [-1.0, 1.0]:
		var x: float = side * 0.35
		_box(Vector3(0.04, 0.9, 0.7), Vector3(x, 0.45, -0.17), side_art, false, Vector3.ZERO, rig)
		_box(Vector3(0.04, 0.82, 0.55), Vector3(x, 1.31, -0.1), side_art, false, Vector3.ZERO, rig)
		_box(Vector3(0.04, 0.32, 0.7), Vector3(x, 1.9, -0.15), side_art, false, Vector3.ZERO, rig)
		# T-moulding down the front edges.
		_box(Vector3(0.045, 0.9, 0.02), Vector3(x, 0.45, 0.185), trim, false, Vector3.ZERO, rig)
		_box(Vector3(0.045, 0.82, 0.02), Vector3(x, 1.31, 0.175), trim, false, Vector3.ZERO, rig)
	# Kick plate and coin door.
	_box(Vector3(0.66, 0.12, 0.02), Vector3(0, 0.06, 0.18), dark, false, Vector3.ZERO, rig)
	_box(Vector3(0.66, 0.72, 0.02), Vector3(0, 0.48, 0.17), body, false, Vector3.ZERO, rig)
	_coin_door(room, rig, Vector3(0, 0.5, 0.185), 2)
	# Control panel: jutting out, tilted, a joystick, two small buttons and
	# the big FLING button.
	var panel := _mat(room, Color(0.12, 0.1, 0.09), 6, Color(0.2, 0.17, 0.14), 40.0)
	_box(Vector3(0.7, 0.07, 0.36), Vector3(0, 0.84, 0.27), panel, false, Vector3(0.2, 0, 0), rig)
	_box(Vector3(0.7, 0.14, 0.02), Vector3(0, 0.76, 0.45), trim, false, Vector3.ZERO, rig)
	_cyl(0.012, 0.07, Vector3(-0.2, 0.9, 0.3), _mat(room, Color(0.75, 0.75, 0.8)), rig)
	office._ball(0.03, Vector3(-0.2, 0.94, 0.3), _mat(room, Color(0.9, 0.15, 0.12)), rig)
	for i in 2:
		_cyl(0.025, 0.02, Vector3(-0.02 + i * 0.08, 0.885, 0.28), _mat(room, [Color(0.95, 0.85, 0.2), Color(0.3, 0.55, 0.95)][i]), rig)
	_cyl(0.055, 0.03, Vector3(0.2, 0.89, 0.28), _glow(room, Color(1.0, 0.35, 0.1)), rig)
	_label("FLING", Vector3(0.2, 0.78, 0.465), 10, Color(1.0, 0.85, 0.5), rig)
	_label("1 TOKEN", Vector3(0, 0.72, 0.19), 14, Color(1.0, 0.85, 0.4), rig)
	# Screen, recessed in its bezel, with a little line of art under it.
	_box(Vector3(0.66, 0.82, 0.02), Vector3(0, 1.31, 0.145), dark, false, Vector3.ZERO, rig)
	_bezel(room, rig, cy, title_col)
	# Overhanging marquee, angled down at you.
	_box(Vector3(0.7, 0.28, 0.08), Vector3(0, 1.88, 0.1), _glow(room, title_col * 0.15), false, Vector3(-0.15, 0, 0), rig)
	_label(title, Vector3(0, 1.9, 0.145), 40, title_col.lightened(0.3), rig, Vector3(-0.15, 0, 0))
	_label("BERNIE'S STRESS RELIEF", Vector3(0, 1.78, 0.16), 8, Color(1, 1, 1, 0.8), rig, Vector3(-0.15, 0, 0))
	_box(Vector3(0.7, 0.04, 0.6), Vector3(0, 2.05, -0.15), dark, false, Vector3.ZERO, rig)


func _machine(id: String, script: String, room: String, screen: Node3D, size: Vector2) -> void:
	var vp := SubViewport.new()
	vp.size = MACHINE_PX
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	office.add_child(vp)
	office._view_bus[vp] = office._make_bus("Ladder")
	var m: Control = load(script).new()
	m.hub = self
	vp.add_child(m)
	var pc = office._add_computer(screen, size, vp, MACHINE_PX)
	_machines[id] = {"vp": vp, "node": m, "pc": pc, "room": room, "active": false}


## A standing (or seated) coworker built from PS1 boxes. Returns their root.
func _person(room: String, id: String, at: Vector3, yaw: float, look: Dictionary, seated := false) -> Node3D:
	var p: Node = _rooms[room] if _rooms.has(room) else office._world_vp
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	p.add_child(root)
	var skin := _mat(room, look.get("skin", Color(0.9, 0.7, 0.55)))
	var shirt := _mat(room, look.get("shirt", Color(0.5, 0.5, 0.6)), 6, Color.BLACK, 40.0)
	var pants := _mat(room, look.get("pants", Color(0.2, 0.2, 0.25)))
	var hair := _mat(room, look.get("hair", Color(0.25, 0.18, 0.12)))
	var dark := _mat(room, Color(0.08, 0.08, 0.1))
	var wide: float = look.get("wide", 1.0)
	var body := Node3D.new()
	body.position.y = -0.42 if seated else 0.0
	root.add_child(body)
	if not seated:
		for side in [-1.0, 1.0]:
			_box(Vector3(0.14, 0.8, 0.16), Vector3(side * 0.1 * wide, 0.4, 0), pants, false, Vector3.ZERO, body)
			_box(Vector3(0.15, 0.06, 0.24), Vector3(side * 0.1 * wide, 0.03, 0.04), dark, false, Vector3.ZERO, body)
	_box(Vector3(0.42 * wide, 0.62, 0.26 * wide), Vector3(0, 1.11, 0), shirt, false, Vector3.ZERO, body)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.11, 0.58, 0.12), Vector3(side * (0.27 * wide), 1.1, 0.0), shirt, false, Vector3(0, 0, side * 0.08), body)
		_box(Vector3(0.09, 0.09, 0.1), Vector3(side * (0.29 * wide + 0.02), 0.78, 0.0), skin, false, Vector3.ZERO, body)
	if look.has("tie"):
		_box(Vector3(0.06, 0.32, 0.02), Vector3(0, 1.18, 0.135 * wide), _mat(room, look.tie), false, Vector3.ZERO, body)
	if look.has("strap"):
		for side in [-1.0, 1.0]:
			_box(Vector3(0.06, 0.62, 0.02), Vector3(side * 0.12, 1.11, 0.135 * wide), _mat(room, look.strap), false, Vector3.ZERO, body)
	if look.has("lanyard"):
		_box(Vector3(0.1, 0.13, 0.02), Vector3(0, 1.02, 0.14 * wide), _mat(room, Color(0.95, 0.95, 0.9)), false, Vector3.ZERO, body)
	_box(Vector3(0.12, 0.08, 0.12), Vector3(0, 1.45, 0), skin, false, Vector3.ZERO, body)
	var head := Node3D.new()
	head.position = Vector3(0, 1.48, 0)
	body.add_child(head)
	_box(Vector3(0.25, 0.27, 0.24), Vector3(0, 0.14, 0), skin, false, Vector3.ZERO, head)
	var eyes: Array = []
	for side in [-1.0, 1.0]:
		var e := Node3D.new()
		e.position = Vector3(side * 0.055, 0.17, 0.122)
		head.add_child(e)
		_box(Vector3(0.025, 0.03, 0.006), Vector3.ZERO, dark, false, Vector3.ZERO, e)
		eyes.append(e)
		if look.get("glasses", false):
			_box(Vector3(0.08, 0.06, 0.008), Vector3(side * 0.055, 0.17, 0.128), dark, false, Vector3.ZERO, head)
			_box(Vector3(0.06, 0.04, 0.008), Vector3(side * 0.055, 0.17, 0.131), _mat(room, Color(0.75, 0.85, 0.9), 0, Color.BLACK, 24.0, Color(0.1, 0.12, 0.15)), false, Vector3.ZERO, head)
	_box(Vector3(0.04, 0.05, 0.04), Vector3(0, 0.11, 0.13), skin, false, Vector3.ZERO, head)
	var mouth := Node3D.new()
	mouth.position = Vector3(0, 0.055, 0.122)
	head.add_child(mouth)
	_box(Vector3(0.07, 0.03, 0.01), Vector3.ZERO, _mat(room, Color(0.35, 0.1, 0.1)), false, Vector3.ZERO, mouth)
	mouth.scale.y = 0.25
	match look.get("hair_style", "short"):
		"short":
			_box(Vector3(0.27, 0.08, 0.26), Vector3(0, 0.3, -0.005), hair, false, Vector3.ZERO, head)
		"bob":
			_box(Vector3(0.29, 0.1, 0.27), Vector3(0, 0.3, -0.01), hair, false, Vector3.ZERO, head)
			for side in [-1.0, 1.0]:
				_box(Vector3(0.04, 0.22, 0.22), Vector3(side * 0.145, 0.16, -0.02), hair, false, Vector3.ZERO, head)
			_box(Vector3(0.28, 0.22, 0.05), Vector3(0, 0.16, -0.13), hair, false, Vector3.ZERO, head)
		"curls":
			for i in 7:
				var a := -PI * 0.1 + i * PI * 1.2 / 6.0
				office._ball(0.08, Vector3(cos(a) * 0.15, 0.24 + sin(a) * 0.08, -0.02 - absf(cos(a)) * 0.02), hair, head)
			office._ball(0.13, Vector3(0, 0.3, -0.06), hair, head, Vector3(1.4, 0.8, 1.2))
		"slick":
			_box(Vector3(0.27, 0.06, 0.28), Vector3(0, 0.31, -0.01), hair, false, Vector3(-0.15, 0, 0), head)
		"cap_back":
			_box(Vector3(0.28, 0.09, 0.27), Vector3(0, 0.31, 0), _mat(room, look.cap), false, Vector3.ZERO, head)
			_box(Vector3(0.2, 0.025, 0.12), Vector3(0, 0.28, -0.18), _mat(room, look.cap), false, Vector3.ZERO, head)
		"flat_cap":
			_box(Vector3(0.29, 0.07, 0.29), Vector3(0, 0.31, 0.01), _mat(room, look.cap), false, Vector3.ZERO, head)
			_box(Vector3(0.24, 0.025, 0.1), Vector3(0, 0.285, 0.16), _mat(room, look.cap), false, Vector3.ZERO, head)
		"horseshoe":
			_box(Vector3(0.27, 0.09, 0.1), Vector3(0, 0.19, -0.08), hair, false, Vector3.ZERO, head)
			for side in [-1.0, 1.0]:
				_box(Vector3(0.03, 0.09, 0.14), Vector3(side * 0.13, 0.19, 0.0), hair, false, Vector3.ZERO, head)
	if look.get("beard", false):
		_box(Vector3(0.24, 0.1, 0.04), Vector3(0, 0.04, 0.115), _mat(room, Color(0.7, 0.7, 0.68)), false, Vector3.ZERO, head)
	if look.get("moustache", false):
		_box(Vector3(0.12, 0.025, 0.02), Vector3(0, 0.08, 0.13), hair, false, Vector3.ZERO, head)
	var alert: Label3D = _label("!", Vector3(0, 2.05 - (0.42 if seated else 0.0), 0), 48, Color(1.0, 0.85, 0.3), root)
	alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alert.visible = false
	_people[id] = {"root": root, "body": body, "head": head, "mouth": mouth, "eyes": eyes, "alert": alert, "room": room,
		"seated": seated, "blink": randf_range(1.0, 4.0), "phase": randf() * TAU}
	return root


const LOOKS := {
	"gloria": {"skin": Color(0.88, 0.68, 0.55), "shirt": Color(0.2, 0.55, 0.55), "pants": Color(0.55, 0.5, 0.38), "hair": Color(0.72, 0.72, 0.74), "hair_style": "bob", "glasses": true, "lanyard": true},
	"kev": {"skin": Color(0.78, 0.58, 0.42), "shirt": Color(0.95, 0.5, 0.15), "pants": Color(0.25, 0.35, 0.6), "hair_style": "cap_back", "cap": Color(0.8, 0.15, 0.15)},
	"bernie": {"skin": Color(0.5, 0.34, 0.25), "shirt": Color(0.55, 0.3, 0.62), "pants": Color(0.2, 0.18, 0.26), "hair": Color(0.15, 0.1, 0.08), "hair_style": "curls", "lanyard": true},
	"theo": {"skin": Color(0.96, 0.8, 0.68), "shirt": Color(0.12, 0.15, 0.32), "pants": Color(0.35, 0.36, 0.4), "hair": Color(0.85, 0.72, 0.4), "hair_style": "slick", "tie": Color(0.75, 0.12, 0.12)},
	"ray": {"skin": Color(0.42, 0.28, 0.2), "shirt": Color(0.45, 0.32, 0.2), "pants": Color(0.3, 0.38, 0.46), "strap": Color(0.3, 0.38, 0.46), "hair_style": "flat_cap", "cap": Color(0.3, 0.3, 0.32), "beard": true},
	"dale": {"skin": Color(0.93, 0.72, 0.58), "shirt": Color(0.86, 0.84, 0.66), "pants": Color(0.22, 0.24, 0.3), "hair": Color(0.36, 0.24, 0.15), "hair_style": "horseshoe", "glasses": true, "moustache": true, "tie": Color(0.62, 0.12, 0.42), "wide": 1.3},
}


# ---------------------------------------------------------------- the rooms

func _build_arcade() -> void:
	var r := "arcade"
	var p: Node3D = _rooms[r]
	var z0: float = ROOM_Z.arcade
	var wall := _mat(r, Color(0.16, 0.1, 0.24), 6, Color.BLACK, 20.0)
	var carpet := _mat(r, Color(0.12, 0.08, 0.2), 1, Color(0.7, 0.2, 0.6), 18.0)
	var ceil := _mat(r, Color(0.08, 0.06, 0.12), 2, Color(0.2, 0.15, 0.3), 30.0)
	_shell(r, z0, ROOM_Z.trading - 0.1, 2.8, wall, carpet, ceil, 0.0, 1.8, 7.4)
	# Neon strips and signs.
	for spec in [[Vector3(-3.48, 2.5, 8.0), Color(1.0, 0.3, 0.7)], [Vector3(3.48, 2.5, 8.0), Color(0.3, 0.95, 0.9)]]:
		_box(Vector3(0.03, 0.05, 7.6), spec[0], _glow(r, spec[1]), false, Vector3.ZERO, p)
	_label("THE BREAK ROOM ARCADE", Vector3(0, 2.45, ROOM_Z.trading - 0.17), 26, Color(1.0, 0.45, 0.8), p, Vector3(0, PI, 0))
	_label("WIN TICKETS -> PRIZE COUNTER -> DOOR KEY", Vector3(0, 2.6, z0 + 0.12), 14, Color(0.4, 1.0, 0.9), p)
	_cabinet(r, Vector3(-2.95, 0, 6.0), PI / 2, Color(0.45, 0.1, 0.35), "CLAW\nKING", Color(1.0, 0.45, 0.8), "claw", "res://scenes/ladder/claw.gd")
	_cabinet(r, Vector3(-2.95, 0, 9.0), PI / 2, Color(0.5, 0.25, 0.08), "FALL\nGUY", Color(1.0, 0.65, 0.3), "ragdoll", "res://scenes/ladder/ragdoll.gd")
	_cabinet(r, Vector3(2.95, 0, 7.2), -PI / 2, Color(0.06, 0.35, 0.35), "PUSH YOUR\nLUCK", Color(0.4, 1.0, 0.9), "pusher", "res://scenes/ladder/pusher.gd")
	# Prize counter: a long glass counter along the east wall, shelves of
	# prizes behind it, a CRT on top that runs the shop.
	var counter := Node3D.new()
	counter.position = Vector3(2.95, 0, 10.0)
	counter.rotation.y = -PI / 2
	p.add_child(counter)
	var wood := _mat(r, Color(0.5, 0.32, 0.18), 3, Color(0.42, 0.26, 0.14), 50.0)
	_box(Vector3(1.6, 0.95, 0.5), Vector3(0, 0.475, -0.05), wood, true, Vector3.ZERO, counter)
	_box(Vector3(1.6, 0.04, 0.55), Vector3(0, 0.97, -0.05), _mat(r, Color(0.6, 0.8, 0.85), 0, Color.BLACK, 24.0, Color(0.1, 0.15, 0.2)), false, Vector3.ZERO, counter)
	var prize_cols := [Color(1.0, 0.85, 0.2), Color(0.62, 0.4, 0.22), Color(0.95, 0.4, 0.5), Color(0.4, 0.7, 1.0)]
	for row in 3:
		_box(Vector3(1.5, 0.03, 0.25), Vector3(0, 1.3 + row * 0.38, -0.42), wood, false, Vector3.ZERO, counter)
		for i in 6:
			office._ball(0.07, Vector3(-0.6 + i * 0.24, 1.38 + row * 0.38, -0.42), _mat(r, prize_cols[(i + row) % 4]), counter)
	_box(Vector3(0.1, 0.7, 0.04), Vector3(-0.45, 1.65, -0.39), _mat(r, Color(0.85, 0.75, 0.4), 0, Color.BLACK, 24.0, Color(0.4, 0.3, 0.1)), false, Vector3(0, 0, 0.3), counter)
	_label("DOOR\nKEY\n300", Vector3(-0.45, 2.15, -0.38), 9, Color(1.0, 0.9, 0.5), counter)
	_label("PRIZES", Vector3(0, 2.45, -0.4), 22, Color(1.0, 0.8, 0.3), counter)
	_monitor(r, counter, Vector3(0.45, 1.0, 0.05), Vector2(0.27, 0.48), "counter", "res://scenes/ladder/counter.gd", Color(0.3, 0.22, 0.12))
	# Out-of-order cabinets along the back wall, for atmosphere.
	for i in 3:
		var x := -2.7 + i * 0.9 if i < 2 else 2.4
		var rig := Node3D.new()
		rig.position = Vector3(x, 0, ROOM_Z.trading - 0.55)
		rig.rotation.y = PI
		p.add_child(rig)
		_box(Vector3(0.7, 1.8, 0.6), Vector3(0, 0.9, 0), _mat(r, [Color(0.2, 0.2, 0.5), Color(0.4, 0.1, 0.1), Color(0.1, 0.35, 0.15)][i], 6, Color.BLACK, 30.0), true, Vector3.ZERO, rig)
		_box(Vector3(0.4, 0.34, 0.02), Vector3(0, 1.3, 0.31), _glow(r, Color(0.08, 0.1, 0.2)), false, Vector3.ZERO, rig)
		_label("OUT OF\nORDER", Vector3(0, 1.3, 0.325), 9, Color(1.0, 0.4, 0.35), rig)
	# Ray's mop and bucket, by the back corner.
	_cyl(0.14, 0.26, Vector3(-3.15, 0.13, 11.7), _mat(r, Color(0.95, 0.8, 0.1)), p, Vector3.ZERO, 8, 0.16)
	_cyl(0.015, 1.3, Vector3(-3.05, 0.65, 11.55), _mat(r, Color(0.6, 0.45, 0.3)), p, Vector3(0.2, 0, 0.1))
	# Coworkers.
	for id in CoworkerLines.ORDER:
		var spot: Array = NPC_SPOTS[id]
		_person(r, id, spot[0], spot[1], LOOKS[id])
	# Doors: to the trading floor (centre of the back wall) and the archive.
	_door("trading", "arcade", Vector3(0, 0, ROOM_Z.trading - 0.05), true, Color(0.25, 0.25, 0.28), "TRADING FLOOR")
	_door("archive", "arcade", Vector3(-3.55, 0, 7.4), false, Color(0.3, 0.28, 0.25), "BASEMENT")


## A CRT-style monitor in a rig, screen facing local +z, running a machine.
func _monitor(room: String, parent: Node3D, at: Vector3, glass: Vector2, id: String, script: String, shell_col: Color) -> void:
	var shell := _mat(room, shell_col, 6, Color.BLACK, 40.0)
	var rim := _mat(room, Color(0.05, 0.05, 0.06))
	_box(Vector3(glass.x + 0.1, glass.y + 0.12, 0.08), at + Vector3(0, glass.y * 0.5 + 0.08, -0.05), shell, false, Vector3.ZERO, parent)
	_box(Vector3(glass.x + 0.03, glass.y + 0.03, 0.004), at + Vector3(0, glass.y * 0.5 + 0.08, -0.008), rim, false, Vector3.ZERO, parent)
	_box(Vector3(glass.x * 0.8, glass.y * 0.8, 0.22), at + Vector3(0, glass.y * 0.5 + 0.08, -0.2), shell, false, Vector3.ZERO, parent)
	_box(Vector3(glass.x * 0.6, 0.04, 0.24), at + Vector3(0, 0.02, -0.12), shell, false, Vector3.ZERO, parent)
	var screen := Node3D.new()
	screen.position = at + Vector3(0, glass.y * 0.5 + 0.08, 0.0)
	parent.add_child(screen)
	_machine(id, script, room, screen, glass)


func _build_archive() -> void:
	var r := "archive"
	var p: Node3D = _rooms[r]
	var a := ARCHIVE
	var wall := _mat(r, Color(0.28, 0.26, 0.24), 6, Color.BLACK, 20.0)
	var concrete := _mat(r, Color(0.3, 0.3, 0.32), 5, Color(0.26, 0.26, 0.28), 20.0)
	var h := 2.4
	var cx := a.position.x + a.size.x * 0.5
	var cz := a.position.y + a.size.y * 0.5
	_box(Vector3(a.size.x + 0.1, 0.1, a.size.y + 0.1), Vector3(cx, -0.05, cz), concrete, true, Vector3.ZERO, p)
	_box(Vector3(a.size.x + 0.1, 0.1, a.size.y + 0.1), Vector3(cx, h + 0.05, cz), concrete, true, Vector3.ZERO, p)
	_box(Vector3(a.size.x, h, 0.1), Vector3(cx, h * 0.5, a.position.y - 0.05), wall, true, Vector3.ZERO, p)
	_box(Vector3(a.size.x, h, 0.1), Vector3(cx, h * 0.5, a.end.y + 0.05), wall, true, Vector3.ZERO, p)
	_box(Vector3(0.1, h, a.size.y), Vector3(a.position.x - 0.05, h * 0.5, cz), wall, true, Vector3.ZERO, p)
	# A short passage from the arcade's side door.
	_box(Vector3(0.1, h, a.size.y), Vector3(a.end.x + 0.05, h * 0.5, cz), wall, false, Vector3.ZERO, p).visible = false
	var bulb := _glow(r, Color(1.0, 0.9, 0.6))
	_cyl(0.06, 0.12, Vector3(-6.2, 2.25, 7.4), bulb, p)
	# Shelves of shelved games.
	var shelf := _mat(r, Color(0.45, 0.4, 0.32))
	for i in 2:
		var sz := 5.9 + i * 2.9
		for row in 4:
			_box(Vector3(2.4, 0.04, 0.4), Vector3(-6.6, 0.35 + row * 0.45, sz), shelf, row == 0, Vector3.ZERO, p)
			for b in 7:
				var c := Color.from_hsv(fmod(b * 0.17 + row * 0.31 + i * 0.5, 1.0), 0.5, 0.6)
				_box(Vector3(0.05, 0.3, 0.26), Vector3(-7.6 + b * 0.32, 0.53 + row * 0.45, sz), _mat(r, c), false, Vector3(0, 0, 0.05 * (b % 3 - 1)), p)
	_box(Vector3(2.4, 1.8, 0.05), Vector3(-6.6, 0.9, 5.65), shelf, true, Vector3.ZERO, p)
	# The photo on the far wall, and the terminal on a desk.
	_box(Vector3(0.9, 0.62, 0.02), Vector3(-8.57, 1.5, 7.4), _mat(r, Color(0.2, 0.15, 0.1)), false, Vector3(0, PI / 2, 0), p)
	_box(Vector3(0.8, 0.5, 0.01), Vector3(-8.55, 1.52, 7.4), _mat(r, Color(0.55, 0.5, 0.42), 6, Color.BLACK, 30.0), false, Vector3(0, PI / 2, 0), p)
	_label("OPENING NIGHT 2011\nHUMBLE HOUSE GAMES\n'BIG DEAL' CUTS\nTHE RIBBON", Vector3(-8.54, 1.52, 7.4), 9, Color(0.2, 0.15, 0.1), p, Vector3(0, PI / 2, 0), 0.75)
	var desk := Node3D.new()
	desk.position = Vector3(-7.7, 0, 7.4)
	desk.rotation.y = PI / 2
	p.add_child(desk)
	var wood := _mat(r, Color(0.4, 0.3, 0.2), 3, Color(0.34, 0.25, 0.16), 50.0)
	_box(Vector3(1.0, 0.05, 0.55), Vector3(0, 0.73, -0.1), wood, true, Vector3.ZERO, desk)
	_box(Vector3(0.05, 0.71, 0.5), Vector3(-0.47, 0.355, -0.1), wood, true, Vector3.ZERO, desk)
	_box(Vector3(0.05, 0.71, 0.5), Vector3(0.47, 0.355, -0.1), wood, true, Vector3.ZERO, desk)
	_monitor(r, desk, Vector3(0, 0.76, -0.05), Vector2(0.27, 0.48), "archive", "res://scenes/ladder/archive.gd", Color(0.75, 0.72, 0.62))
	_label("NEVER SHIPPED", Vector3(-6.6, 2.15, 9.33), 20, Color(0.8, 0.8, 0.9), p, Vector3(0, PI, 0))


func _build_trading() -> void:
	var r := "trading"
	var p: Node3D = _rooms[r]
	var z0: float = ROOM_Z.trading
	var z1: float = ROOM_Z.boardroom - 0.1
	var wall := _mat(r, Color(0.72, 0.74, 0.7), 6, Color.BLACK, 20.0)
	var floor_mat := _mat(r, Color(0.35, 0.36, 0.38), 1, Color(0.3, 0.31, 0.33), 26.0)
	var ceil := _mat(r, Color(0.86, 0.87, 0.85), 2, Color(0.6, 0.6, 0.6), 30.0)
	_shell(r, z0, z1, 3.0, wall, floor_mat, ceil, 0.0, 0.0)
	var panel := _glow(r, Color(0.9, 0.95, 0.9))
	for x in [-1.8, 1.8]:
		for zz in [z0 + 2.0, z0 + 6.0]:
			_box(Vector3(0.5, 0.03, 1.4), Vector3(x, 2.98, zz), panel, false, Vector3.ZERO, p)
	# The big ticker board over the far door.
	_box(Vector3(6.2, 0.5, 0.06), Vector3(0, 2.6, z1 - 0.04), _mat(r, Color(0.02, 0.02, 0.02)), false, Vector3.ZERO, p)
	_ticker = _label("", Vector3(0, 2.6, z1 - 0.08), 26, Color(1.0, 0.7, 0.2), p, Vector3(0, PI, 0))
	_label("BUY LOW  SELL HIGH  DOUBLE IT", Vector3(0, 2.6, z0 + 0.08), 18, Color(0.4, 1.0, 0.5), p)
	# Rows of trader desks with glowing green CRTs.
	var desk := _mat(r, Color(0.3, 0.32, 0.36))
	var shell := _mat(r, Color(0.75, 0.74, 0.68), 6, Color.BLACK, 40.0)
	for x in [-2.6, 2.6]:
		for i in 3:
			var zz := z0 + 1.6 + i * 2.1
			_box(Vector3(1.3, 0.05, 0.7), Vector3(x, 0.74, zz), desk, true, Vector3.ZERO, p)
			_box(Vector3(1.26, 0.7, 0.04), Vector3(x, 0.37, zz - 0.32), desk, true, Vector3.ZERO, p)
			for k in [-0.3, 0.3]:
				_box(Vector3(0.4, 0.32, 0.32), Vector3(x + k, 0.95, zz + 0.1), shell, false, Vector3.ZERO, p)
				_box(Vector3(0.32, 0.24, 0.01), Vector3(x + k, 0.96, zz - 0.065), _glow(r, Color(0.1, 0.5, 0.2)), false, Vector3.ZERO, p)
	# The terminal you trade on: a tall double-height monitor on its own desk.
	var term := Node3D.new()
	term.position = Vector3(-1.2, 0, z0 + 3.4)
	term.rotation.y = PI
	p.add_child(term)
	_box(Vector3(1.1, 0.05, 0.6), Vector3(0, 0.74, 0.05), desk, true, Vector3.ZERO, term)
	_box(Vector3(1.06, 0.7, 0.04), Vector3(0, 0.37, 0.33), desk, true, Vector3.ZERO, term)
	_monitor(r, term, Vector3(0, 0.77, 0.12), Vector2(0.4, 0.71), "trading", "res://scenes/ladder/trading.gd", Color(0.2, 0.22, 0.24))
	_label("TERMINAL 1", Vector3(0, 1.75, 0.0), 12, Color(0.4, 1.0, 0.5), term)
	_door("boardroom", "trading", Vector3(0, 0, z1 + 0.05), true, Color(0.35, 0.25, 0.18), "BOARDROOM")


func _build_boardroom() -> void:
	var r := "boardroom"
	var p: Node3D = _rooms[r]
	var z0: float = ROOM_Z.boardroom
	var z1: float = ROOM_Z.corner - 0.1
	var wall := _mat(r, Color(0.42, 0.3, 0.22), 3, Color(0.36, 0.25, 0.18), 18.0)
	var carpet := _mat(r, Color(0.32, 0.12, 0.12), 1, Color(0.28, 0.1, 0.1), 26.0)
	var ceil := _mat(r, Color(0.7, 0.66, 0.6), 2, Color(0.5, 0.46, 0.4), 30.0)
	_shell(r, z0, z1, 3.0, wall, carpet, ceil, 2.5, 0.0)
	var wood := _mat(r, Color(0.35, 0.2, 0.12), 3, Color(0.3, 0.17, 0.1), 50.0)
	# The long table and the board around it.
	_box(Vector3(1.2, 0.07, 3.4), Vector3(-0.6, 0.76, z0 + 3.1), wood, true, Vector3.ZERO, p)
	_box(Vector3(0.5, 0.72, 2.6), Vector3(-0.6, 0.36, z0 + 3.1), wood, true, Vector3.ZERO, p)
	var suits := [Color(0.15, 0.15, 0.18), Color(0.3, 0.3, 0.33), Color(0.2, 0.15, 0.25), Color(0.12, 0.2, 0.2), Color(0.35, 0.28, 0.2)]
	var spots := [[Vector3(-1.45, 0, z0 + 2.2), PI / 2], [Vector3(-1.45, 0, z0 + 3.4), PI / 2], [Vector3(0.25, 0, z0 + 2.2), -PI / 2], [Vector3(0.25, 0, z0 + 3.4), -PI / 2], [Vector3(-0.6, 0, z0 + 5.05), PI]]
	var chair := _mat(r, Color(0.12, 0.1, 0.1))
	for i in 5:
		var look := {"shirt": suits[i], "skin": [Color(0.9, 0.72, 0.6), Color(0.55, 0.38, 0.28), Color(0.95, 0.8, 0.7), Color(0.7, 0.5, 0.38), Color(0.85, 0.65, 0.55)][i],
			"hair": [Color(0.8, 0.8, 0.8), Color(0.1, 0.08, 0.06), Color(0.6, 0.4, 0.2), Color(0.2, 0.15, 0.1), Color(0.9, 0.9, 0.9)][i],
			"hair_style": ["short", "short", "bob", "slick", "horseshoe"][i], "tie": Color(0.6, 0.1, 0.1) if i % 2 == 0 else Color(0.1, 0.2, 0.5), "glasses": i == 4}
		var spot: Array = spots[i]
		_person(r, "board_%d" % i, spot[0], spot[1], look, true)
		var back: Vector3 = spot[0] - Vector3(sin(spot[1]), 0, cos(spot[1])) * 0.28
		_box(Vector3(0.5, 0.9, 0.08), back + Vector3(0, 0.75, 0), chair, true, Vector3(0, spot[1], 0), p)
	# The projector screen on the far wall runs the pitch.
	var rig := Node3D.new()
	rig.position = Vector3(-0.6, 0, z1 - 0.06)
	rig.rotation.y = PI
	p.add_child(rig)
	var glass := Vector2(0.84, 1.49)
	_box(Vector3(glass.x + 0.14, glass.y + 0.14, 0.04), Vector3(0, 1.45, -0.03), _mat(r, Color(0.9, 0.9, 0.88)), false, Vector3.ZERO, rig)
	var screen := Node3D.new()
	screen.position = Vector3(0, 1.45, 0.0)
	rig.add_child(screen)
	_machine("pitch", "res://scenes/ladder/pitch_screen.gd", r, screen, glass)
	_label("Q3 PITCH MEETING", Vector3(-0.6, 2.4, z1 - 0.1), 16, Color(0.9, 0.85, 0.7), p, Vector3(0, PI, 0))
	# A water jug, the sad bagels and a framed motto.
	_cyl(0.07, 0.24, Vector3(-0.6, 0.92, z0 + 1.7), _mat(r, Color(0.6, 0.75, 0.9), 0, Color.BLACK, 24.0, Color(0.05, 0.08, 0.12)), p)
	_label("SYNERGY", Vector3(3.48, 1.7, z0 + 3.0), 18, Color(0.9, 0.85, 0.7), p, Vector3(0, -PI / 2, 0))
	_door("corner", "boardroom", Vector3(2.5, 0, z1 + 0.05), true, Color(0.5, 0.35, 0.2), "CORNER OFFICE")


func _build_corner() -> void:
	var r := "corner"
	var p: Node3D = _rooms[r]
	var z0: float = ROOM_Z.corner
	var z1: float = ROOM_Z.stage - 0.1
	var wall := _mat(r, Color(0.8, 0.74, 0.62), 6, Color.BLACK, 20.0)
	var carpet := _mat(r, Color(0.55, 0.45, 0.32), 1, Color(0.5, 0.4, 0.28), 26.0)
	var ceil := _mat(r, Color(0.9, 0.88, 0.82), 2, Color(0.6, 0.58, 0.52), 30.0)
	_shell(r, z0, z1, 3.0, wall, carpet, ceil, 2.5, 2.5)
	# A wall of window: the city at sunset.
	_box(Vector3(0.04, 2.0, 5.0), Vector3(3.48, 1.5, z0 + 3.0), _glow(r, Color(1.0, 0.6, 0.35)), false, Vector3.ZERO, p)
	for i in 6:
		var h := 0.4 + fmod(i * 0.37, 0.9)
		_box(Vector3(0.02, h, 0.5), Vector3(3.46, 0.5 + h * 0.5, z0 + 0.9 + i * 0.85), _glow(r, Color(0.25, 0.12, 0.2)), false, Vector3.ZERO, p)
	for zz in [z0 + 0.5, z0 + 3.0, z0 + 5.5]:
		_box(Vector3(0.08, 2.1, 0.08), Vector3(3.45, 1.5, zz), _mat(r, Color(0.3, 0.25, 0.2)), false, Vector3.ZERO, p)
	# The executive desk, facing the door, with the memo and the putting toy.
	var desk := Node3D.new()
	desk.position = Vector3(0, 0, z0 + 3.6)
	desk.rotation.y = PI
	p.add_child(desk)
	var wood := _mat(r, Color(0.3, 0.16, 0.08), 3, Color(0.25, 0.13, 0.06), 50.0)
	_box(Vector3(1.9, 0.07, 0.85), Vector3(0, 0.76, 0), wood, true, Vector3.ZERO, desk)
	_box(Vector3(1.86, 0.72, 0.05), Vector3(0, 0.36, -0.4), wood, true, Vector3.ZERO, desk)
	_box(Vector3(0.05, 0.72, 0.8), Vector3(-0.9, 0.36, 0), wood, true, Vector3.ZERO, desk)
	_box(Vector3(0.05, 0.72, 0.8), Vector3(0.9, 0.36, 0), wood, true, Vector3.ZERO, desk)
	_box(Vector3(0.36, 0.07, 0.03), Vector3(0.5, 0.83, 0.38), _mat(r, Color(0.75, 0.6, 0.28)), false, Vector3(-0.3, 0, 0), desk)
	_label("FOUNDER", Vector3(0.5, 0.832, 0.398), 8, Color(0.15, 0.1, 0.05), desk, Vector3(-0.3, 0, 0))
	# The big leather chair (it does not squeak) behind it.
	var leather := _mat(r, Color(0.15, 0.08, 0.06))
	_box(Vector3(0.65, 0.1, 0.6), Vector3(0, 0.5, -0.85), leather, true, Vector3.ZERO, desk)
	_box(Vector3(0.65, 0.9, 0.12), Vector3(0, 1.0, -1.12), leather, false, Vector3.ZERO, desk)
	_monitor(r, desk, Vector3(-0.55, 0.795, -0.05), Vector2(0.24, 0.43), "putt", "res://scenes/ladder/putt.gd", Color(0.2, 0.2, 0.22))
	# The memo: a folded sheet on the blotter, glowing a little so you notice it.
	_box(Vector3(0.7, 0.01, 0.45), Vector3(0.2, 0.8, 0.1), _mat(r, Color(0.2, 0.3, 0.22)), false, Vector3.ZERO, desk)
	_memo_node = Node3D.new()
	_memo_node.position = Vector3(0.2, 0.81, 0.12)
	desk.add_child(_memo_node)
	_box(Vector3(0.24, 0.006, 0.32), Vector3.ZERO, _mat(r, Color(0.95, 0.94, 0.88), 0, Color.BLACK, 24.0, Color(0.25, 0.22, 0.12)), false, Vector3(0, 0.2, 0), _memo_node)
	_label("MEMO", Vector3(0, 0.005, 0), 10, Color(0.6, 0.1, 0.1), _memo_node, Vector3(-PI / 2, 0.2, 0))
	var alert: Label3D = _label("!", Vector3(0, 0.45, 0), 48, Color(1.0, 0.85, 0.3), _memo_node)
	alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_people["memo"] = {"root": _memo_node, "alert": alert, "room": r, "object": true}
	# The fabled smoothie machine. Dale was right.
	_box(Vector3(0.5, 1.5, 0.45), Vector3(-3.15, 0.75, z0 + 1.2), _mat(r, Color(0.9, 0.5, 0.65), 6, Color.BLACK, 30.0), true, Vector3.ZERO, p)
	_box(Vector3(0.02, 0.4, 0.3), Vector3(-2.89, 1.15, z0 + 1.2), _glow(r, Color(1.0, 0.6, 0.75)), false, Vector3.ZERO, p)
	_label("SMOOTHIES", Vector3(-2.88, 1.62, z0 + 1.2), 12, Color(1.0, 0.95, 0.9), p, Vector3(0, PI / 2, 0))
	_label("YOU MADE IT.", Vector3(0, 2.5, z0 + 0.08), 22, Color(0.5, 0.3, 0.15), p)
	_door("stage", "corner", Vector3(2.5, 0, z1 + 0.05), true, Color(0.2, 0.2, 0.22), "EXIT -> STREET")


func _build_stage() -> void:
	var r := "stage"
	var p: Node3D = _rooms[r]
	var z0: float = ROOM_Z.stage
	var z1 := ROOM_END
	var brick := _mat(r, Color(0.45, 0.2, 0.15), 5, Color(0.38, 0.16, 0.12), 6.0)
	var floor_mat := _mat(r, Color(0.12, 0.1, 0.1), 5, Color(0.1, 0.08, 0.08), 12.0)
	var ceil := _mat(r, Color(0.05, 0.04, 0.05))
	_shell(r, z0, z1, 3.2, brick, floor_mat, ceil, -99.0, 2.5)
	_label("THE BRICK WALL", Vector3(0, 2.6, z1 - 0.08), 34, Color(1.0, 0.3, 0.55), p, Vector3(0, PI, 0))
	_label("COMEDY CLUB  EST. 1987", Vector3(0, 2.35, z1 - 0.08), 14, Color(1.0, 0.8, 0.4), p, Vector3(0, PI, 0))
	_label("OPEN MIC TONIGHT", Vector3(-3.48, 2.0, z0 + 2.0), 16, Color(0.4, 0.9, 1.0), p, Vector3(0, PI / 2, 0))
	# The stage: a low platform with a ramp up the middle, the mic and a stool.
	var stage_mat := _mat(r, Color(0.2, 0.12, 0.08), 3, Color(0.16, 0.1, 0.06), 30.0)
	var sz0 := z1 - 2.6
	_box(Vector3(7.0, 0.26, 2.6), Vector3(0, 0.13, sz0 + 1.3), stage_mat, true, Vector3.ZERO, p)
	var slope := atan2(0.26, 1.1)
	_box(Vector3(1.2, 0.08, 1.14), Vector3(0, 0.12, sz0 - 0.55), stage_mat, true, Vector3(-slope, 0, 0), p)
	_box(Vector3(2.4, 0.01, 2.2), Vector3(0, 0.265, sz0 + 1.4), _mat(r, Color(0.5, 0.45, 0.35), 0, Color.BLACK, 24.0, Color(0.35, 0.3, 0.2)), false, Vector3.ZERO, p)
	var metal := _mat(r, Color(0.3, 0.3, 0.32))
	_cyl(0.012, 1.4, Vector3(0, 0.96, sz0 + 1.7), metal, p)
	_cyl(0.12, 0.02, Vector3(0, 0.27, sz0 + 1.7), metal, p)
	office._ball(0.04, Vector3(0, 1.68, sz0 + 1.7), _mat(r, Color(0.1, 0.1, 0.1)), p)
	_cyl(0.18, 0.04, Vector3(1.0, 0.95, sz0 + 1.9), stage_mat, p)
	_cyl(0.02, 0.68, Vector3(1.0, 0.6, sz0 + 1.9), metal, p)
	# The set list on a monitor at the lip of the stage, facing the comic.
	var rig := Node3D.new()
	rig.position = Vector3(-1.0, 0.26, sz0 + 0.45)
	p.add_child(rig)
	_cyl(0.02, 0.6, Vector3(0, 0.3, -0.05), metal, rig)
	_monitor(r, rig, Vector3(0, 0.6, 0.0), Vector2(0.3, 0.53), "stage", "res://scenes/ladder/final_set.gd", Color(0.1, 0.1, 0.12))
	_label("YOUR SET", Vector3(0, 1.32, -0.06), 12, Color(1.0, 0.4, 0.7), rig)
	# Crowd tables with candles, and the regulars (coworkers you befriended
	# show up here).
	var table := _mat(r, Color(0.15, 0.1, 0.08))
	var candle := _glow(r, Color(1.0, 0.7, 0.3))
	var seats := [Vector3(-2.2, 0, z0 + 1.6), Vector3(0.0, 0, z0 + 1.2), Vector3(2.2, 0, z0 + 1.6), Vector3(-1.2, 0, z0 + 3.4), Vector3(1.2, 0, z0 + 3.4)]
	for t in seats:
		_cyl(0.35, 0.04, t + Vector3(0, 0.72, 0), table, p)
		_cyl(0.04, 0.7, t + Vector3(0, 0.35, 0), table, p)
		_cyl(0.03, 0.06, t + Vector3(0, 0.77, 0), candle, p)
	var ids := CoworkerLines.ORDER
	for i in ids.size():
		var t: Vector3 = seats[i]
		_crowd[ids[i]] = _person(r, "crowd_" + ids[i], t + Vector3(0.0, 0, -0.55), 0.0, LOOKS[ids[i]], true)
	_stage_dale = _person(r, "dale_stage", Vector3(-0.55, 0, z0 + 1.2), 0.25, LOOKS.dale, true)


# ---------------------------------------------------------------- talking

## Everyone you can talk to right now: {id, node, c (hit centre, local),
## r (hit radius), eye/look offsets for the talk camera}.
func people() -> Array:
	var out: Array = []
	for id in _people:
		var p: Dictionary = _people[id]
		if id.begins_with("board_") or id.begins_with("crowd_") or id.begins_with("boss_"):
			continue
		var node: Node3D = p.root
		if not node.is_visible_in_tree() or p.room != _room:
			continue
		if p.get("object", false):
			out.append({"id": id, "node": node, "c": Vector3.ZERO, "r": 0.3,
				"eye_p": Vector3(0, 0.75, 0.9), "look_p": Vector3(0, -0.05, 0), "eye_l": Vector3(0, 0.6, 0.8), "look_l": Vector3(0, 0.0, 0)})
			continue
		var seated: bool = p.seated
		var y := 1.0 if seated else 1.42
		out.append({"id": id, "node": node, "c": Vector3(0, y, 0), "r": 0.5,
			"eye_p": Vector3(0, y + 0.12, 1.9), "look_p": Vector3(0, y - 0.45, 0), "eye_l": Vector3(0, y + 0.12, 1.5), "look_l": Vector3(0, y - 0.08, 0)})
	return out


## The room you're standing in ("office", "arcade", "archive", "trading"...).
func room() -> String:
	return _room


func talk(id: String) -> Dictionary:
	_talk_id = id
	match id:
		"memo":
			return {"id": id, "title": "MEMO  -  FROM: B.D. (FOUNDER)", "steps": MEMO.duplicate(true)}
		"dale_stage":
			return {"id": id, "title": "DALE", "steps": DALE_STAGE.duplicate(true)}
	return crew.talk(id, _ctx())


## A reply was picked. Returns what's said back, line by line.
func choose(id: String, choice: Dictionary) -> Array:
	if id == "dale_stage" or not CoworkerLines.PEOPLE.has(id):
		return [choice.get("reply", "")]
	var out := crew.choose(id, choice, _ctx())
	for r in out.rewards:
		state.apply_reward(r)
	_refresh_machines()
	var news: Array[String] = []
	if out.secret != "":
		news.append("SECRET LEARNED (%d/%d)" % [crew.secrets.size(), LadderState.SECRETS_TOTAL])
	if out.perk != "":
		news.append(out.perk)
	if out.delta < 0:
		news.append("%s CLOSED OFF. PLAY A MACHINE, THEN TRY AGAIN." % Coworkers.person(id).name)
	if out.role != "":
		news.append(office._busy.role_news(id, out.role))
	if not news.is_empty():
		office._toast.text = "\n".join(news)
		office._toast_time = 4.0
	return out.lines


## A talk ended; finished = you read it to the end (not BYE halfway).
func end_talk(id: String, finished := true) -> void:
	_talk_id = ""
	match id:
		"memo":
			if finished and not state.is_done("memo"):
				state.mark("memo")
				_toast("THE STAGE DOOR IS OPEN")
		"dale_stage":
			if finished:
				state.mark("true_end")
	_update_doors(false)
	_refresh_people()


func _ctx() -> Dictionary:
	return {"plays": state.plays, "items": Array(state.items), "beaten": state.beaten.size(),
		"busy": office._busy != null and office._busy.enabled}


const MEMO := [
	{"line": "To whoever finally opens this office: hi. It's been empty since 2011. Sorry about the dust."},
	{"line": "I did stand-up for one week. Called myself Big Deal. Then I bought the club. The Brick Wall."},
	{"line": "I turned it into a game studio. Hired good people. Built a ladder with this office on top."},
	{"line": "Then the top got scary. So I took the desk by the window and called myself QA."},
	{"line": "Fifteen years. I never climbed it. You did, in about a week."},
	{"line": "This office was never the point. The stage is. Out the door, down the street. Go. - Dale"},
]

const DALE_STAGE := [
	{"line": "You read the memo. ...Yeah. It was me. Big Deal. Founder. Fifteen years in QA."},
	{"line": "Built a whole ladder and got scared of the top. You climbed it like it was nothing."},
	{"line": "Then you walked right past the corner office to get to this mic. Good. That's the job."},
	{"choices": [
		{"text": "I learned it from you.", "reply": "From me? I quit everything after a week. ...Except this place. Huh.", "kind": "line"},
		{"text": "Your turn, Big Deal.", "reply": "My turn? ...One minute. Hold my purple pen.", "kind": "line"},
		{"text": "Same sandwich daily?", "reply": "Turkey on rye. Fifteen years. I'm loyal. To a fault. To a sandwich.", "kind": "line"},
	]},
	{"line": "THE END. Thanks for playing. Come back to the office anytime. I'll be at the window."},
]


# ---------------------------------------------------------------- the hub (machines call these)

func spend_token() -> bool:
	var ok := state.spend_token()
	_refresh_machines()
	return ok


func win_tickets(n: int, machine: String, beats: bool) -> void:
	state.win_tickets(n)
	if beats and state.beat(machine):
		var names := {"claw": "CLAW KING", "pusher": "PUSH YOUR LUCK", "ragdoll": "FALL GUY"}
		var msg := "MACHINE BEATEN: %s (%d/3)" % [names.get(machine, machine), state.beaten.size()]
		if state.beaten.size() == Coworkers.RAY_AFTER:
			msg += "\nTHE LIGHTS DIM... SOMEONE'S MOPPING BY THE BACK WALL."
		_toast(msg)
		_refresh_people()
	_refresh_machines()


func buy(id: String) -> bool:
	var ok := state.buy(id, crew.gifted)
	if ok and id == LadderState.DOOR_KEY:
		_update_doors(false)
	_refresh_machines()
	return ok


func market_won() -> void:
	state.mark("market")
	_update_doors(false)
	_toast("YOU DOUBLED IT. THE BOARDROOM DOOR IS OPEN")


func pitch_won() -> void:
	state.mark("pitch")
	_update_doors(false)
	_toast("GREENLIT. THE CORNER OFFICE IS OPEN")


func stage_won() -> void:
	var first := not state.is_done("stage")
	state.mark("stage")
	if state.true_ending(crew.secrets.size()):
		_toast("SOMEONE IN THE CROWD IS WAVING AT YOU...")
	elif first:
		_toast("YOU KILLED. THE END... FOR NOW.\nFIND EVERY SECRET FOR THE TRUE ENDING.")
	_refresh_people()


func _toast(text: String) -> void:
	office._toast.text = text
	office._toast_time = 4.5


func _refresh_machines() -> void:
	for id in _machines:
		var m: Control = _machines[id].node
		m.refresh_top()
		if id == "counter" and _machines[id].active:
			m.refresh()


# ---------------------------------------------------------------- every frame

## Re-check who shows a "!" (the goal marker just moved).
func refresh_alerts() -> void:
	_refresh_people()


## Where the office's goal marker floats for key (engine/goal_target.gd), or
## null. Doors: in the doorway, on your side of it.
func goal_spot(key: String, me: Vector3):
	if key.begins_with("door_"):
		var d: Dictionary = _doors.get(key.substr(5), {})
		if d.is_empty():
			return null
		var c: Vector3 = d.center
		var side := Vector3(0, 0, signf(me.z - c.z)) if d.along_x else Vector3(signf(me.x - c.x), 0, 0)
		return c + Vector3(0, 1.65, 0) + side * 0.35
	if _machines.has(key):
		var pc = _machines[key].pc
		return office._above_screen(pc.screen, pc.size.y)
	if _people.has(key):
		var p: Dictionary = _people[key]
		var root: Node3D = p.root
		if p.get("object", false):
			return root.global_position + Vector3(0, 0.45, 0)
		return root.global_position + Vector3(0, 2.1 - (0.42 if p.seated else 0.0), 0)
	return null


func objective() -> String:
	return state.objective(crew.secrets.size())


## Shown instead of the office's hint when you're at a locked door.
func hint() -> String:
	return _locked_hint


func tick(delta: float) -> void:
	_time += delta
	var me: Vector3 = office._player.global_position
	var room := _room_at(me)
	if room != _room:
		_room = room
		_entered(room)
		_update_rooms(false)
	if not _doors_ready:
		_doors_ready = true
		_update_doors(true)
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_update_doors(false)
		_refresh_people()
	# Which screen you're sitting at runs; the rest of its room keeps going too.
	for id in _machines:
		var m: Dictionary = _machines[id]
		var on: bool = office._seat == m.pc
		if on != m.active:
			m.active = on
			m.node.set_active(on)
	_tick_people(delta, me)
	_tick_ticker(delta)
	# Standing at a locked door? Say what opens it.
	_locked_hint = ""
	for id in _doors:
		var d: Dictionary = _doors[id]
		if d.open:
			continue
		var c: Vector3 = d.center
		if Vector2(me.x - c.x, me.z - c.z).length() < 1.4:
			_locked_hint = _lock_text(id)


# ---------------------------------------------------------------- dev tools

## Where the DEV panel's teleports land: just inside each room's door, facing
## in (the same clear spots tools/ladder_walk.gd walks through).
const SPOTS := {
	"office": {"name": "OFFICE", "pos": Vector3(0.3, 0, 3.2), "yaw": 0.0},
	"arcade": {"name": "ARCADE", "pos": Vector3(1.8, 0, 5.0), "yaw": PI},
	"archive": {"name": "BASEMENT", "pos": Vector3(-5.0, 0, 7.4), "yaw": PI / 2},
	"trading": {"name": "TRADING FLOOR", "pos": Vector3(0, 0, 13.2), "yaw": PI},
	"boardroom": {"name": "BOARDROOM", "pos": Vector3(0, 0, 21.2), "yaw": PI},
	"corner": {"name": "CORNER OFFICE", "pos": Vector3(2.5, 0, 27.4), "yaw": PI},
	"stage": {"name": "THE STAGE", "pos": Vector3(2.5, 0, 33.4), "yaw": PI},
}


func dev_spots() -> Dictionary:
	return SPOTS


## After a dev shortcut changed the saves: doors, people and machine screens
## catch up right away.
func dev_refresh() -> void:
	_update_doors(false)
	_refresh_people()
	_refresh_machines()


func dev_teleport(room: String) -> void:
	var spot: Dictionary = SPOTS.get(room, {})
	if spot.is_empty():
		return
	if office._talking:
		office._set_talk(false)
	office._set_seat(null)
	office._player.global_position = spot.pos
	office._player.velocity = Vector3.ZERO
	office._yaw = spot.yaw
	office._pitch = -0.08
	office._glide = 1.0


func _lock_text(id: String) -> String:
	match id:
		"office":
			return "LOCKED. DALE HAS THE KEY.\n(FINISH HIS STORY)"
		"trading":
			return "LOCKED. BUY THE DOOR KEY\nAT THE PRIZE COUNTER (300 TICKETS)"
		"archive":
			return "BASEMENT. LOCKED.\nTHE JANITOR HAS A KEY."
		"boardroom":
			return "LOCKED. DOUBLE YOUR MONEY\nON THE TERMINAL FIRST."
		"corner":
			return "LOCKED. WIN THE PITCH FIRST."
		"stage":
			return "LOCKED. READ THE MEMO\nON THE DESK."
	return "LOCKED"


func _room_at(p: Vector3) -> String:
	if p.x < -3.6 and p.z > ARCHIVE.position.y - 0.5 and p.z < ARCHIVE.end.y + 0.5:
		return "archive"
	var room := "office"
	for r in ORDER:
		if p.z >= ROOM_Z[r] - 0.05:
			room = r
	return room


func _entered(room: String) -> void:
	match room:
		"arcade":
			if not state.paid:
				var pay := state.collect_paycheck(DaleStory.read_stats())
				_toast("PAYDAY! +%d TOKENS\nPLAY MACHINES, WIN TICKETS, TALK TO PEOPLE." % pay)
				_refresh_machines()
		"archive":
			if not state.is_done("archive"):
				state.mark("archive")
				_toast("YOU FOUND THE ARCHIVE.\nGAMES THAT NEVER SHIPPED...")
		"trading":
			if state.market_cash <= 0:
				var cash := state.market_start()
				_toast("YOUR TICKETS CASHED OUT: $%d\nDOUBLE IT AT TERMINAL 1." % cash)
				_refresh_machines()
		"corner":
			_toast("THE CORNER OFFICE.\nNOBODY'S BEEN HERE IN YEARS.")
		"stage":
			_toast("THE BRICK WALL. OPEN MIC.\nGET ON STAGE. YOUR SET'S ON THE MONITOR.")


## Show the room you're in and its neighbours (seen through open doors);
## pause the machines everywhere else.
func _update_rooms(force: bool) -> void:
	var i := ORDER.find(_room if _room != "archive" else "arcade")
	var show := {}
	for k in range(maxi(0, i - 1), mini(ORDER.size(), i + 2)):
		show[ORDER[k]] = true
	show["archive"] = _room in ["arcade", "archive"]
	# Nothing to see behind a shut office door (saves drawing the arcade).
	if _room == "office" and not _doors.get("office", {}).get("open", false) and not _peek:
		show["arcade"] = false
	for r in _rooms:
		var on: bool = show.get(r, false)
		if force or _visible_rooms.get(r, null) != on:
			_rooms[r].visible = on
			_visible_rooms[r] = on
	for id in _machines:
		var m: Dictionary = _machines[id]
		var here: bool = m.room == _room or (m.room == "archive" and _room == "arcade") or (m.room == "arcade" and _room == "archive")
		m.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if here else (SubViewport.UPDATE_ONCE if force else SubViewport.UPDATE_DISABLED)
		m.node.process_mode = Node.PROCESS_MODE_INHERIT if here else Node.PROCESS_MODE_DISABLED


## Look Busy: the boss walks in through the office door even while it's
## locked to you, so the arcade behind it shows for the moment it's open.
func peek_arcade(on: bool) -> void:
	if on != _peek:
		_peek = on
		_update_rooms(false)


func _update_doors(instant: bool) -> void:
	var office_done: bool = office._dale_story.next_chapter().is_empty()
	for id in _doors:
		var d: Dictionary = _doors[id]
		var want := state.door_open(id, office_done)
		if want and not d.open:
			d.open = true
			if id == "office":
				_update_rooms(true)
			for l in d.locks:
				l.visible = false
			var body := d.panel.get_child(0) as StaticBody3D
			if body:
				body.collision_layer = 0
				body.collision_mask = 0
			var angle := -PI * 0.55 if d.along_x else PI * 0.55
			if instant:
				d.hinge.rotation.y = angle
			else:
				var t := create_tween()
				t.tween_property(d.hinge, "rotation:y", angle, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				if id != "office":
					_toast_door(id)


func _toast_door(id: String) -> void:
	if id == "archive":
		_toast("THE BASEMENT DOOR IS UNLOCKED (BY THE CLAW)")


func _refresh_people() -> void:
	for id in CoworkerLines.ORDER:
		if _people.has(id):
			var p: Dictionary = _people[id]
			p.root.visible = Coworkers.present(id, state.beaten.size())
			p.alert.visible = p.root.visible and crew.has_news(id, _ctx()) and _talk_id != id and goal_id != id
	if _people.has("memo"):
		_people.memo.alert.visible = not state.is_done("memo") and _talk_id != "memo" and goal_id != "memo"
	for id in _crowd:
		_crowd[id].visible = crew.tier(id) >= 2
	if _stage_dale:
		_stage_dale.visible = state.is_done("stage") and state.true_ending(crew.secrets.size())
		_people.dale_stage.alert.visible = _stage_dale.visible and not state.is_done("true_end") and _talk_id != "dale_stage" and goal_id != "dale_stage"


func _tick_people(delta: float, me: Vector3) -> void:
	var cam: Vector3 = office._camera.global_position
	for id in _people:
		var p: Dictionary = _people[id]
		if p.get("object", false):
			if p.alert.visible:
				p.alert.position.y = 0.45 + sin(_time * 3.0) * 0.04
			continue
		var root: Node3D = p.root
		if not root.is_visible_in_tree():
			continue
		p.phase += delta
		p.body.scale = Vector3(1.0 + sin(p.phase * 1.6) * 0.01, 1.0 + sin(p.phase * 1.6) * 0.012, 1.0)
		var head: Node3D = p.head
		var to_you := root.to_local(cam)
		var yaw := clampf(atan2(to_you.x, to_you.z), -0.9, 0.9)
		if root.global_position.distance_to(me) > 6.0:
			yaw = 0.0
		head.rotation.y = lerp_angle(head.rotation.y, yaw, minf(1.0, delta * 4.0))
		p.blink -= delta
		var shut: bool = p.blink < 0.0
		if p.blink < -0.12:
			p.blink = randf_range(2.0, 5.0)
		for e in p.eyes:
			e.scale.y = 0.15 if shut else 1.0
		var talking: bool = office._talking and _talk_id == id and office._talk_text.visible_characters >= 0
		var open := 0.6 + 0.6 * absf(sin(_time * 13.0)) if talking else 0.25
		p.mouth.scale.y = lerpf(p.mouth.scale.y, open, minf(1.0, delta * 20.0))
		if p.alert.visible:
			p.alert.position.y = (2.05 - (0.42 if p.seated else 0.0)) + sin(_time * 3.0 + p.phase) * 0.04


func _tick_ticker(delta: float) -> void:
	if _ticker == null or not _ticker.is_visible_in_tree():
		return
	var m = _machines.get("trading", {}).get("node")
	var text := "HHG  PRZ  BRCK  LOOT  PRF  ...  BUY ON THE RUMOR, SELL ON THE NEWS  ...  "
	if m and m.market:
		var parts: Array[String] = []
		for s in Market.STOCKS:
			parts.append("%s %.2f" % [s.sym, m.market.prices[s.sym]])
		text = "  ".join(parts) + "   ***   " + m.market.headline + "   ***   "
	_ticker.text = text.left(54)
