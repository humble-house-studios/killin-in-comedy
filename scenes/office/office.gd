extends Node
## The meta office: walk up to a desk in a PS1-style office and play real
## games on the computers, first person.
## - The 3D world renders at a third of the screen size (chunky PS1 pixels).
## - Each computer runs a game in its own viewport; a second full-res pass
##   draws only the screens, so they stay readable up close.
##   - Main desk: this game (res://scenes/main.tscn) in a SubViewport.
##   - Side desk: Phone Pong (res://games/pong, pulled in by tools/fetch_games.sh)
##     on a pivot monitor: tall when the phone is upright, sideways when it is
##     (so Pong's paddle sits under the right thumb).
##   - Right-wall desk: Proof Hand (res://games/proof), same embedding; it also
##     needs its Game/Save autoloads, added by tools/fetch_games.sh --autoloads.
##     in an embedded Window (inside a hidden holder viewport), so its own
##     window-size logic still works.
##   - Corner: the Loot Machine (res://games/loot, humble-house-studios/Loot-Machine),
##     a slot-machine cabinet whose relics power up every game in the room.
##     OfficeLink (from that repo) applies the relics to Pong and this game
##     at the start of each run/set, and pays Comp Tokens into the machine
##     when you clear Pong stages and comedy sets.
## - Clicks/taps are ray-cast onto a screen and pushed into that game at that spot.
## - Each game has its own audio bus that fades with distance to its screen.
## Mouse: click to look around, WASD walk, click the monitor to play, Esc lets go.
## Touch: tap the computer (or SIT DOWN) and the camera glides to the desk and
## frames the screen; then every tap goes into the game. STAND UP to walk again
## (left thumb walks, right thumb looks).
## Controller: left stick walks (click it or hold LB to run), right stick
## looks, A sits at the computer you're facing. Seated, the pad goes into
## that game (each game has its own controls); Back / Select stands up.
## Keys go to the seated or hovered game too (Pong's arrow keys).

const EYE := 1.5
const SPEED := 2.4
const RUN_SPEED := 3.8
const LOOK_SENS := 0.0025
const TOUCH_LOOK_SENS := 0.006
## How far away you can still click a monitor (metres).
const REACH := 2.6
## Main monitor: screen size in metres (16:9, matches the game viewport).
const SCREEN_W := 0.66
const SCREEN_H := 0.37125
const SCREEN_POS := Vector3(0.0, 1.17, -2.38)
const GAME_SIZE := Vector2i(1280, 720)
## Pong monitor: a tall screen on the side desk by the left wall.
const PONG_SCENE := "res://games/pong/main.tscn"
const PONG_SIZE := Vector2i(720, 1280)
const PONG_SCREEN := Vector2(0.36, 0.64)
## Sideways phone = sideways Pong monitor (it pivots), so Pong plays its own
## landscape mode: paddle on the right, under your right thumb.
const PONG_SIZE_WIDE := Vector2i(1280, 720)
const PONG_DESK := Vector3(-3.05, 0.0, 2.0)
## Proof Hand: a tall terminal on a desk by the right wall, under a chalkboard.
const PROOF_SCENE := "res://games/proof/scenes/main.tscn"
const PROOF_SIZE := Vector2i(720, 1280)
const PROOF_BASE := Vector2i(1080, 1920)
const PROOF_DESK := Vector3(3.05, 0.0, -0.9)
## Loot Machine cabinet on the right wall, between the chalkboard and the water cooler: an upright screen.
const LOOT_SCENE := "res://games/loot/scenes/main.tscn"
const LOOT_LINK := "res://games/loot/ecosystem/office_link.gd"
const LOOT_SIZE := Vector2i(720, 1280)
const LOOT_SCREEN := Vector2(0.34, 0.6044)
const LOOT_SPOT := Vector3(3.12, 0.0, 0.45)
## Cube Desk (humble-house-studios/rubix): a desk by the door with an upright
## monitor, a Rubik's cube beside the keyboard.
const CUBE_SCENE := "res://games/cube/scenes/main.tscn"
const CUBE_SIZE := Vector2i(720, 1280)
const CUBE_SCREEN := Vector2(0.36, 0.64)
const CUBE_DESK := Vector3(-1.6, 0.0, 3.62)
## Game audio is full volume within NEAR metres of its screen, silent past FAR.
const AUDIO_NEAR := 1.6
const AUDIO_FAR := 5.0
const PIXEL_SHRINK := 3
const LAYER_WORLD := 1
const LAYER_SCREEN := 2
const STICK_RADIUS := 90.0
const SafeArea := preload("res://scenes/safe_area.gd")
## Seated view: fov, and how much of the view the screen fills.
const SEAT_FOV := 50.0
const SEAT_FILL := 0.94
## How far in front of a screen you stand when you get up from its desk.
const STAND_BACK := 0.8
## Controller: look speed (radians per second at full tilt), stick deadzone,
## and how far away A still sits you down at the nearest computer.
const PAD_LOOK := 2.4
const PAD_DEAD := 0.18
const PAD_SIT_RANGE := 3.0


## One playable computer: a game running in its own viewport, shown on a screen.
class Computer:
	## Centre of the screen; the screen faces local +z.
	var screen: Node3D
	## Screen size in metres.
	var size: Vector2
	var view: Viewport
	var pixels: Vector2
	var hi_mat: ShaderMaterial
	var quad: QuadMesh
	var bus := 0
	## The game reads screen touches (Pong) instead of mouse buttons (Controls).
	var touch_events := false
	## Where the pointer sits on the game (game pixels), or null.
	var pointer = null
	var held := false

	func last_uv() -> Vector2:
		return pointer / pixels if pointer != null else Vector2(-1, -1)

	func send_motion(uv: Vector2) -> void:
		var pos := uv * pixels
		if pointer != null and pos.is_equal_approx(pointer):
			return
		var rel: Vector2 = pos - (pointer if pointer != null else pos)
		pointer = pos
		var ev := InputEventMouseMotion.new()
		ev.position = pos
		ev.global_position = pos
		ev.relative = rel
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
		view.push_input(ev, true)
		if touch_events and held:
			var drag := InputEventScreenDrag.new()
			drag.position = pos
			drag.relative = rel
			view.push_input(drag, true)

	func send_button(uv: Vector2, pressed: bool) -> void:
		send_motion(uv)
		held = pressed
		var pos := uv * pixels
		if touch_events:
			var touch := InputEventScreenTouch.new()
			touch.position = pos
			touch.pressed = pressed
			view.push_input(touch, true)
			return
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		view.push_input(ev, true)

	func release() -> void:
		if held:
			send_button(last_uv(), false)

	## Camera transform that frames the whole screen, centred.
	func seat_transform(camera: Camera3D, view_size: Vector2, fov: float, fill: float) -> Transform3D:
		var aspect := view_size.x / maxf(view_size.y, 1.0)
		var half := tan(deg_to_rad(fov) * 0.5)
		var tan_w := half if camera.keep_aspect == Camera3D.KEEP_WIDTH else half * aspect
		var tan_h := half if camera.keep_aspect == Camera3D.KEEP_HEIGHT else half / aspect
		var d := maxf(size.x * 0.5 / fill / tan_w, size.y * 0.5 / fill / tan_h)
		var xf := screen.global_transform
		return Transform3D(xf.basis.orthonormalized(), xf.origin + xf.basis.z.normalized() * d)

var _ps1 := preload("res://scenes/office/ps1.gdshader")
var _monitor_shader := preload("res://scenes/office/monitor.gdshader")

var _world_box: SubViewportContainer
var _world_vp: SubViewport
var _screen_vp: SubViewport
var _game_vp: SubViewport
var _pong_view: Window
## What Pong's screen shows (the holder its window is embedded in).
var _pong_screen: SubViewport
var _pong_pc: Computer
var _proof_view: Window
## The Pong monitor's case, which turns 90° when the phone goes sideways.
var _pong_pivot: Node3D
var _computers: Array[Computer] = []
## Game viewport -> audio bus index, so each game's sounds can fade by distance.
var _view_bus := {}
var _player: CharacterBody3D
var _head: Node3D
var _camera: Camera3D
var _screen_camera: Camera3D
var _clock_hands: Array[Node3D] = []
var _hud: Control
var _hint: Label
var _title: Label
## Loot Machine game viewport, and the relic link (null if it isn't fetched).
var _loot_vp: SubViewport
var _cube_vp: SubViewport
var _link: RefCounted
var _toast: Label
var _toast_time := 0.0

var _yaw := 0.0
var _pitch := -0.08
var _bob := 0.0
var _zoom := 0.0
var _touch := false
## Touch index -> "move" / "look" / "screen".
var _touches := {}
## The computer a held click/tap is pressing on.
var _press_pc: Computer
## The computer the crosshair last hovered.
var _hover_pc: Computer
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
## Notch / status bar / home bar clearance: left, top, right, bottom (viewport units).
var _inset := Vector4.ZERO
var _stand_corner := Control.PRESET_TOP_LEFT
var _stick := Vector2.ZERO
var _moved := false
## The computer you're sitting at, or null while walking.
var _seat: Computer
## Camera glide between walking and seated views.
var _glide := 1.0
var _glide_time := 0.6
var _glide_from := Transform3D()
var _glide_from_fov := 70.0
var _sit_button: Button
var _stand_button: Button
## A controller is being used (hints and crosshair follow it).
var _pad := false
var _pad_move := Vector2.ZERO
var _pad_look := Vector2.ZERO
var _pad_run := false
var _pad_told := false


func _ready() -> void:
	_touch = DisplayServer.is_touchscreen_available()
	get_tree().node_added.connect(_on_node_added)
	_build_game()
	_build_views()
	_build_room()
	_build_player()
	_build_hud()
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	# The phone reports its safe area a moment after it turns; re-check twice a second.
	if OS.has_feature("web"):
		var poll := Timer.new()
		poll.wait_time = 0.5
		poll.autostart = true
		poll.timeout.connect(_apply_insets)
		add_child(poll)


# ---------------------------------------------------------------- setup

func _build_game() -> void:
	_game_vp = SubViewport.new()
	_game_vp.size = GAME_SIZE
	_game_vp.disable_3d = true
	_game_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_game_vp)
	_view_bus[_game_vp] = _make_bus("Comedy")
	_game_vp.add_child(preload("res://scenes/main.tscn").instantiate())
	if ResourceLoader.exists(LOOT_SCENE):
		_loot_vp = SubViewport.new()
		_loot_vp.size = LOOT_SIZE
		_loot_vp.disable_3d = true
		_loot_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_loot_vp)
		_view_bus[_loot_vp] = _make_bus("Loot")
		_loot_vp.add_child(load(LOOT_SCENE).instantiate())
		_link = load(LOOT_LINK).new()
	if ResourceLoader.exists(CUBE_SCENE):
		# 3D stays on: the cube renders in its own little world inside.
		_cube_vp = SubViewport.new()
		_cube_vp.size = CUBE_SIZE
		_cube_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_cube_vp)
		_view_bus[_cube_vp] = _make_bus("Cube")
		_cube_vp.add_child(load(CUBE_SCENE).instantiate())
	if ResourceLoader.exists(PONG_SCENE):
		_pong_view = _embed(PONG_SCENE, PONG_SIZE, PONG_SIZE, "Pong")
		_pong_screen = _pong_view.get_parent()
	# Proof Hand needs its autoloads (Game, Save), which the office build adds
	# (tools/fetch_games.sh --autoloads).
	if ResourceLoader.exists(PROOF_SCENE) and has_node("/root/Game"):
		_proof_view = _embed(PROOF_SCENE, PROOF_SIZE, PROOF_BASE, "Proof")


## Runs a game that sizes itself from get_window() in a window of its own,
## embedded in a holder viewport that's never drawn (only its texture is
## shown), so the window can't pop up over the office. Returns the window;
## its parent is the holder.
func _embed(scene: String, px: Vector2i, base: Vector2i, bus_name: String) -> Window:
	var holder := SubViewport.new()
	holder.size = px
	holder.disable_3d = true
	holder.gui_embed_subwindows = true
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(holder)
	var w := Window.new()
	w.size = px
	w.borderless = true
	w.unfocusable = true
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	w.content_scale_size = base
	holder.add_child(w)
	_view_bus[w] = _make_bus(bus_name)
	w.add_child(load(scene).instantiate())
	return w


## Each game's bus. They're declared in default_bus_layout.tres because the
## web build (sample playback) only knows buses that exist at startup: a bus
## added at runtime plays nothing in Safari. Adding is the fallback.
func _make_bus(bus_name: String) -> int:
	var existing := AudioServer.get_bus_index(bus_name)
	if existing >= 0:
		return existing
	var i := AudioServer.bus_count
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")
	return i


## Route each game's sound players to that game's bus.
func _on_node_added(node: Node) -> void:
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D):
		return
	for view in _view_bus:
		if view.is_ancestor_of(node):
			node.bus = AudioServer.get_bus_name(_view_bus[view])
			# The web build's default "sample" playback hands sounds to the
			# browser and drops them for games embedded here; Godot's own
			# mixer (stream playback) plays them through the per-game buses.
			node.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
			return


## A screen showing a game's viewport, plus its crisp copy for the screen pass.
## view gets the input, in `pixels` units (the game's canvas size); shown
## (default: view) is what the screen displays.
func _add_computer(screen: Node3D, size: Vector2, view: Viewport, pixels: Vector2i, touch_events := false, shown: Viewport = null) -> Computer:
	var pc := Computer.new()
	pc.screen = screen
	pc.size = size
	pc.view = view
	pc.pixels = Vector2(pixels)
	pc.touch_events = touch_events
	pc.bus = _view_bus[view]
	var quad := QuadMesh.new()
	quad.size = size
	pc.quad = quad
	var lo := ShaderMaterial.new()
	lo.shader = _monitor_shader
	var texture := (shown if shown else view).get_texture()
	lo.set_shader_parameter("game", texture)
	var lo_mi := MeshInstance3D.new()
	lo_mi.mesh = quad
	lo_mi.material_override = lo
	lo_mi.layers = LAYER_WORLD
	screen.add_child(lo_mi)
	pc.hi_mat = lo.duplicate()
	pc.hi_mat.set_shader_parameter("game", texture)
	var hi_mi := MeshInstance3D.new()
	hi_mi.mesh = quad
	hi_mi.material_override = pc.hi_mat
	hi_mi.layers = LAYER_SCREEN
	hi_mi.position.z = 0.001
	screen.add_child(hi_mi)
	_computers.append(pc)
	return pc


func _build_views() -> void:
	_world_box = SubViewportContainer.new()
	_world_box.stretch = true
	_world_box.stretch_shrink = PIXEL_SHRINK
	_world_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_world_box)
	_world_vp = SubViewport.new()
	_world_vp.gui_disable_input = true
	_world_vp.audio_listener_enable_3d = true
	_world_box.add_child(_world_vp)

	var screen_box := SubViewportContainer.new()
	screen_box.stretch = true
	screen_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen_box)
	_screen_vp = SubViewport.new()
	_screen_vp.transparent_bg = true
	_screen_vp.gui_disable_input = true
	screen_box.add_child(_screen_vp)
	_screen_camera = Camera3D.new()
	_screen_camera.cull_mask = LAYER_SCREEN
	_screen_vp.add_child(_screen_camera)


func _mat(albedo: Color, pattern := 0, albedo2 := Color.BLACK, texel := 24.0, emission := Color.BLACK) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _ps1
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("albedo2", albedo2)
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("texel", texel)
	m.set_shader_parameter("emission", emission)
	return m


## A box mesh at pos (its centre), optionally solid to walk into.
func _box(size: Vector3, pos: Vector3, mat: Material, solid := false, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	# Subdivide big faces so the per-vertex light has something to work with.
	mesh.subdivide_width = clampi(int(size.x / 0.3), 0, 24)
	mesh.subdivide_height = clampi(int(size.y / 0.3), 0, 24)
	mesh.subdivide_depth = clampi(int(size.z / 0.3), 0, 24)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = LAYER_WORLD
	mi.position = pos
	mi.rotation = rot
	(parent if parent else _world_vp).add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		mi.add_child(body)
	return mi


func _cyl(radius: float, height: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, sides := 8, top := -1.0, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = LAYER_WORLD
	mi.position = pos
	mi.rotation = rot
	(parent if parent else _world_vp).add_child(mi)
	return mi


func _label(text: String, pos: Vector3, size: int, color: Color, rot := Vector3.ZERO, width := 0.0, parent: Node3D = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = preload("res://fonts/press_start_2p.ttf")
	l.font_size = size
	l.pixel_size = 0.002
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.position = pos
	l.rotation = rot
	l.layers = LAYER_WORLD
	if width > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.width = width
	(parent if parent else _world_vp).add_child(l)
	return l


func _build_room() -> void:
	# Room: x -3.5..3.5, z -3..4, 2.6 tall. You start by the door at +z.
	var wall := _mat(Color(0.62, 0.6, 0.5), 6, Color.BLACK, 20.0)
	var carpet := _mat(Color(0.25, 0.3, 0.36), 1, Color(0.2, 0.22, 0.3), 28.0)
	var ceiling := _mat(Color(0.78, 0.77, 0.72), 2, Color(0.45, 0.44, 0.42), 30.0)
	var trim := _mat(Color(0.22, 0.2, 0.18))
	_box(Vector3(7.4, 0.1, 7.4), Vector3(0, -0.05, 0.5), carpet, true)
	_box(Vector3(7.4, 0.1, 7.4), Vector3(0, 2.65, 0.5), ceiling, true)
	_box(Vector3(7.4, 2.6, 0.1), Vector3(0, 1.3, -3.05), wall, true)
	_box(Vector3(7.4, 2.6, 0.1), Vector3(0, 1.3, 4.05), wall, true)
	_box(Vector3(0.1, 2.6, 7.2), Vector3(-3.55, 1.3, 0.5), wall, true)
	_box(Vector3(0.1, 2.6, 7.2), Vector3(3.55, 1.3, 0.5), wall, true)
	for b in [[Vector3(7.0, 0.1, 0.02), Vector3(0, 0.05, -2.99)], [Vector3(7.0, 0.1, 0.02), Vector3(0, 0.05, 3.99)],
			[Vector3(0.02, 0.1, 7.0), Vector3(-3.49, 0.05, 0.5)], [Vector3(0.02, 0.1, 7.0), Vector3(3.49, 0.05, 0.5)]]:
		_box(b[0], b[1], trim)

	# Fluorescent panels.
	var panel := _mat(Color(0.2, 0.2, 0.2), 0, Color.BLACK, 24.0, Color(0.95, 0.97, 0.9))
	_box(Vector3(0.6, 0.03, 1.2), Vector3(0, 2.59, -1.6), panel)
	_box(Vector3(0.6, 0.03, 1.2), Vector3(0, 2.59, 2.2), panel)

	# Window with blinds on the left wall.
	_box(Vector3(0.04, 1.1, 1.8), Vector3(-3.49, 1.5, -0.5), _mat(Color(0.1, 0.1, 0.1), 4, Color(0.05, 0.05, 0.06), 24.0, Color(0.55, 0.65, 0.8)))
	_box(Vector3(0.08, 1.2, 0.06), Vector3(-3.47, 1.5, 0.43), trim)
	_box(Vector3(0.08, 1.2, 0.06), Vector3(-3.47, 1.5, -1.43), trim)
	_box(Vector3(0.12, 0.05, 1.9), Vector3(-3.45, 0.93, -0.5), trim)

	# Door behind you.
	_box(Vector3(0.95, 2.1, 0.05), Vector3(1.8, 1.05, 3.98), _mat(Color(0.42, 0.28, 0.17), 3, Color(0.34, 0.22, 0.13), 40.0))
	_box(Vector3(0.1, 0.04, 0.06), Vector3(1.45, 1.0, 3.93), _mat(Color(0.7, 0.65, 0.4)))

	_build_desk()
	_build_pong_desk()
	_build_proof_desk()
	_build_loot_cabinet()
	_build_cube_desk()
	_build_props()


func _build_desk() -> void:
	var wood := _mat(Color(0.5, 0.36, 0.22), 3, Color(0.42, 0.29, 0.17), 60.0)
	var metal := _mat(Color(0.3, 0.31, 0.33))
	var beige := _mat(Color(0.78, 0.74, 0.62), 6, Color.BLACK, 40.0)
	var dark := _mat(Color(0.12, 0.12, 0.13))
	# Desk: top surface at 0.76, against the back wall.
	_box(Vector3(1.8, 0.05, 0.8), Vector3(0, 0.735, -2.55), wood, true)
	_box(Vector3(0.05, 0.71, 0.75), Vector3(-0.86, 0.355, -2.55), metal, true)
	_box(Vector3(0.05, 0.71, 0.75), Vector3(0.86, 0.355, -2.55), metal, true)
	_box(Vector3(1.7, 0.4, 0.03), Vector3(0, 0.5, -2.9), metal)
	_box(Vector3(0.45, 0.6, 0.7), Vector3(0.6, 0.41, -2.55), metal, true)
	for y in [0.55, 0.3]:
		_box(Vector3(0.3, 0.02, 0.02), Vector3(0.6, y, -2.19), dark)

	# The monitor: a chunky beige box, screen facing you.
	_box(Vector3(0.3, 0.02, 0.24), Vector3(0, 0.77, -2.6), beige)
	_box(Vector3(0.08, 0.14, 0.08), Vector3(0, 0.84, -2.6), beige)
	_box(Vector3(0.8, 0.52, 0.08), Vector3(0, SCREEN_POS.y, SCREEN_POS.z - 0.045), beige, true)
	_box(Vector3(0.62, 0.42, 0.34), Vector3(0, SCREEN_POS.y, SCREEN_POS.z - 0.25), beige)
	_box(Vector3(0.7, 0.4, 0.01), Vector3(0, SCREEN_POS.y, SCREEN_POS.z - 0.003), dark)
	_box(Vector3(0.03, 0.015, 0.01), Vector3(0.33, SCREEN_POS.y - 0.235, SCREEN_POS.z - 0.003), _mat(Color.BLACK, 0, Color.BLACK, 24.0, Color(0.2, 1.0, 0.3)))
	# Sticky notes on the bezel.
	var note := _mat(Color(0.95, 0.88, 0.35))
	_box(Vector3(0.08, 0.08, 0.004), Vector3(-0.42, SCREEN_POS.y + 0.22, SCREEN_POS.z), note, false, Vector3(0, 0, 0.12))
	_box(Vector3(0.08, 0.08, 0.004), Vector3(0.43, SCREEN_POS.y - 0.17, SCREEN_POS.z), _mat(Color(0.95, 0.5, 0.7)), false, Vector3(0, 0, -0.1))
	_label("TIGHT\nFIVE!", Vector3(-0.42, SCREEN_POS.y + 0.22, SCREEN_POS.z + 0.004), 10, Color(0.15, 0.1, 0.1), Vector3(0, 0, 0.12))
	_label("LAND\nAT THE\nPEAK", Vector3(0.43, SCREEN_POS.y - 0.17, SCREEN_POS.z + 0.004), 7, Color(0.15, 0.1, 0.1), Vector3(0, 0, -0.1))

	var screen := Node3D.new()
	screen.position = SCREEN_POS
	_world_vp.add_child(screen)
	_add_computer(screen, Vector2(SCREEN_W, SCREEN_H), _game_vp, GAME_SIZE)

	# Keyboard, mouse, mug.
	_box(Vector3(0.46, 0.03, 0.16), Vector3(-0.05, 0.775, -2.3), _mat(Color(0.8, 0.77, 0.66), 7, Color(0.45, 0.43, 0.38)), false, Vector3(0.08, 0, 0))
	_box(Vector3(0.06, 0.025, 0.1), Vector3(0.32, 0.772, -2.3), beige)
	var mug := _mat(Color(0.75, 0.18, 0.2))
	_cyl(0.045, 0.1, Vector3(-0.6, 0.81, -2.4), mug)
	_cyl(0.038, 0.005, Vector3(-0.6, 0.861, -2.4), _mat(Color(0.2, 0.1, 0.05)))
	# Paper stack.
	_box(Vector3(0.22, 0.04, 0.3), Vector3(0.68, 0.78, -2.6), _mat(Color(0.92, 0.92, 0.88)), false, Vector3(0, 0.2, 0))


## Side desk by the left wall, facing into the room: a tall monitor running Pong.
func _build_pong_desk() -> void:
	var rig := Node3D.new()
	rig.position = PONG_DESK
	rig.rotation.y = PI / 2
	_world_vp.add_child(rig)
	var wood := _mat(Color(0.36, 0.38, 0.4), 6, Color.BLACK, 40.0)
	var metal := _mat(Color(0.25, 0.26, 0.28))
	var shell := _mat(Color(0.2, 0.2, 0.24), 6, Color.BLACK, 40.0)
	var dark := _mat(Color(0.05, 0.05, 0.06))
	_box(Vector3(1.2, 0.05, 0.7), Vector3(0, 0.735, 0), wood, true, Vector3.ZERO, rig)
	_box(Vector3(0.05, 0.71, 0.65), Vector3(-0.56, 0.355, 0), metal, true, Vector3.ZERO, rig)
	_box(Vector3(0.05, 0.71, 0.65), Vector3(0.56, 0.355, 0), metal, true, Vector3.ZERO, rig)
	var h := PONG_SCREEN.y
	var cy := 0.84 + h * 0.5 + 0.06
	_box(Vector3(0.26, 0.02, 0.22), Vector3(0, 0.77, -0.08), shell, false, Vector3.ZERO, rig)
	_box(Vector3(0.07, 0.08, 0.07), Vector3(0, 0.81, -0.08), shell, false, Vector3.ZERO, rig)
	# Pivot arm behind the monitor, so it can turn sideways.
	_box(Vector3(0.06, cy - 0.77, 0.05), Vector3(0, (0.77 + cy) * 0.5, -0.38), shell, false, Vector3.ZERO, rig)
	_pong_pivot = Node3D.new()
	_pong_pivot.position = Vector3(0, cy, 0)
	rig.add_child(_pong_pivot)
	var pv := _pong_pivot
	_box(Vector3(PONG_SCREEN.x + 0.1, h + 0.12, 0.08), Vector3(0, 0, -0.045), shell, true, Vector3.ZERO, pv)
	_box(Vector3(PONG_SCREEN.x - 0.04, h - 0.08, 0.26), Vector3(0, 0, -0.22), shell, false, Vector3.ZERO, pv)
	_box(Vector3(PONG_SCREEN.x + 0.04, h + 0.04, 0.01), Vector3(0, 0, -0.003), dark, false, Vector3.ZERO, pv)
	_box(Vector3(0.025, 0.012, 0.01), Vector3(0.15, -h * 0.5 - 0.035, -0.003), _mat(Color.BLACK, 0, Color.BLACK, 24.0, Color(1.0, 0.3, 0.7)), false, Vector3.ZERO, pv)
	_label("PONG-O-TRON", Vector3(-0.06, -h * 0.5 - 0.033, 0.002), 8, Color(0.75, 0.75, 0.8), Vector3.ZERO, 0.0, pv)
	_box(Vector3(0.08, 0.08, 0.004), Vector3(0.26, 0.2, 0.0), _mat(Color(0.5, 0.9, 0.6)), false, Vector3(0, 0, -0.15), pv)
	_label("BEAT\nMY\nBEST", Vector3(0.26, 0.2, 0.004), 8, Color(0.1, 0.15, 0.1), Vector3(0, 0, -0.15), 0.0, pv)
	_box(Vector3(0.36, 0.03, 0.13), Vector3(0, 0.775, 0.2), _mat(Color(0.3, 0.3, 0.34), 7, Color(0.15, 0.15, 0.17)), false, Vector3(0.08, 0, 0), rig)
	_cyl(0.05, 0.12, Vector3(-0.42, 0.82, 0.05), _mat(Color(0.95, 0.85, 0.3)), Vector3.ZERO, 8, -1.0, rig)

	var screen := Node3D.new()
	screen.position = Vector3(0, cy, 0)
	rig.add_child(screen)
	if _pong_view:
		_pong_pc = _add_computer(screen, PONG_SCREEN, _pong_view, PONG_SIZE, true, _pong_screen)
	else:
		# Run tools/fetch_games.sh to put Pong on this screen.
		_label("NO SIGNAL", Vector3(0, 0, 0.002), 12, Color(0.4, 0.5, 0.6), Vector3.ZERO, 0.0, screen)


## Desk by the right wall, facing into the room: a green-screen terminal
## running Proof Hand, under a chalkboard of half-finished maths.
func _build_proof_desk() -> void:
	var rig := Node3D.new()
	rig.position = PROOF_DESK
	rig.rotation.y = -PI / 2
	_world_vp.add_child(rig)
	var wood := _mat(Color(0.45, 0.33, 0.22), 3, Color(0.38, 0.27, 0.17), 60.0)
	var metal := _mat(Color(0.25, 0.26, 0.28))
	var shell := _mat(Color(0.7, 0.68, 0.58), 6, Color.BLACK, 40.0)
	var dark := _mat(Color(0.03, 0.06, 0.04))
	_box(Vector3(1.2, 0.05, 0.7), Vector3(0, 0.735, 0), wood, true, Vector3.ZERO, rig)
	_box(Vector3(0.05, 0.71, 0.65), Vector3(-0.56, 0.355, 0), metal, true, Vector3.ZERO, rig)
	_box(Vector3(0.05, 0.71, 0.65), Vector3(0.56, 0.355, 0), metal, true, Vector3.ZERO, rig)
	var h := PONG_SCREEN.y
	var cy := 0.84 + h * 0.5 + 0.06
	_box(Vector3(0.3, 0.06, 0.26), Vector3(0, 0.79, -0.08), shell, false, Vector3.ZERO, rig)
	_box(Vector3(PONG_SCREEN.x + 0.12, h + 0.14, 0.08), Vector3(0, cy, -0.045), shell, true, Vector3.ZERO, rig)
	_box(Vector3(PONG_SCREEN.x - 0.02, h - 0.04, 0.3), Vector3(0, cy, -0.24), shell, false, Vector3.ZERO, rig)
	_box(Vector3(PONG_SCREEN.x + 0.04, h + 0.04, 0.01), Vector3(0, cy, -0.003), dark, false, Vector3.ZERO, rig)
	_box(Vector3(0.025, 0.012, 0.01), Vector3(0.16, cy - h * 0.5 - 0.04, -0.003), _mat(Color.BLACK, 0, Color.BLACK, 24.0, Color(0.3, 1.0, 0.4)), false, Vector3.ZERO, rig)
	_label("THE PROVER", Vector3(-0.05, cy - h * 0.5 - 0.038, 0.002), 8, Color(0.2, 0.25, 0.2), Vector3.ZERO, 0.0, rig)
	_box(Vector3(0.4, 0.03, 0.14), Vector3(0, 0.775, 0.2), _mat(Color(0.72, 0.7, 0.6), 7, Color(0.4, 0.4, 0.35)), false, Vector3(0.08, 0, 0), rig)
	# Coffee and a stack of scratch paper.
	_cyl(0.045, 0.1, Vector3(0.45, 0.81, 0.1), _mat(Color(0.9, 0.9, 0.88)), Vector3.ZERO, 8, -1.0, rig)
	_box(Vector3(0.22, 0.05, 0.3), Vector3(-0.42, 0.785, 0.05), _mat(Color(0.92, 0.92, 0.86)), false, Vector3(0, -0.25, 0), rig)
	# Chalkboard on the wall behind.
	var board_z := -0.33
	_box(Vector3(1.7, 0.95, 0.04), Vector3(0, 1.95, board_z), _mat(Color(0.12, 0.2, 0.16), 6, Color.BLACK, 30.0), false, Vector3.ZERO, rig)
	_box(Vector3(1.78, 0.05, 0.07), Vector3(0, 1.45, board_z + 0.02), wood, false, Vector3.ZERO, rig)
	var chalk := Color(0.88, 0.9, 0.85)
	_label("a^2 + b^2 = c^2", Vector3(-0.42, 2.25, board_z + 0.025), 14, chalk, Vector3(0, 0, 0.04), 0.0, rig)
	_label("1 + 1 = 2 ?", Vector3(0.45, 2.12, board_z + 0.025), 16, chalk, Vector3(0, 0, -0.05), 0.0, rig)
	_label("f(x) -> INF", Vector3(-0.35, 1.9, board_z + 0.025), 14, chalk, Vector3(0, 0, -0.03), 0.0, rig)
	_label("PROOF LEFT AS\nAN EXERCISE", Vector3(0.4, 1.72, board_z + 0.025), 11, Color(0.95, 0.75, 0.7), Vector3(0, 0, 0.03), 0.0, rig)
	_label("QED", Vector3(-0.55, 1.62, board_z + 0.025), 18, Color(0.95, 0.88, 0.5), Vector3(0, 0, 0.08), 0.0, rig)

	var screen := Node3D.new()
	screen.position = Vector3(0, cy, 0)
	rig.add_child(screen)
	if _proof_view:
		# Taps go in Proof Hand's own canvas units (its 1080×1920 base), not
		# the window's pixels.
		_add_computer(screen, PONG_SCREEN, _proof_view, PROOF_BASE, false, _proof_view.get_parent())
	else:
		# Run tools/fetch_games.sh --autoloads to put Proof Hand on this screen.
		_label("NO SIGNAL", Vector3(0, 0, 0.002), 12, Color(0.3, 0.6, 0.35), Vector3.ZERO, 0.0, screen)


## The Loot Machine: a grubby red slot cabinet against the right wall, its
## upright screen running the game, a lever on the side.
func _build_cube_desk() -> void:
	var rig := Node3D.new()
	rig.position = CUBE_DESK
	rig.rotation.y = PI
	_world_vp.add_child(rig)
	var wood := _mat(Color(0.3, 0.32, 0.42), 6, Color.BLACK, 40.0)
	var metal := _mat(Color(0.25, 0.26, 0.28))
	var shell := _mat(Color(0.12, 0.13, 0.18), 6, Color.BLACK, 40.0)
	var dark := _mat(Color(0.03, 0.04, 0.08))
	_box(Vector3(1.2, 0.05, 0.7), Vector3(0, 0.735, 0), wood, true, Vector3.ZERO, rig)
	_box(Vector3(0.05, 0.71, 0.65), Vector3(-0.56, 0.355, 0), metal, true, Vector3.ZERO, rig)
	_box(Vector3(0.05, 0.71, 0.65), Vector3(0.56, 0.355, 0), metal, true, Vector3.ZERO, rig)
	var h := CUBE_SCREEN.y
	var cy := 0.84 + h * 0.5 + 0.06
	_box(Vector3(0.24, 0.02, 0.2), Vector3(0, 0.77, -0.1), shell, false, Vector3.ZERO, rig)
	_box(Vector3(0.06, 0.1, 0.06), Vector3(0, 0.82, -0.1), shell, false, Vector3.ZERO, rig)
	_box(Vector3(CUBE_SCREEN.x + 0.08, h + 0.1, 0.06), Vector3(0, cy, -0.04), shell, true, Vector3.ZERO, rig)
	_box(Vector3(CUBE_SCREEN.x + 0.03, h + 0.03, 0.01), Vector3(0, cy, -0.006), dark, false, Vector3.ZERO, rig)
	_label("CUBETRON", Vector3(0, cy - h * 0.5 - 0.03, 0.0), 8, Color(0.6, 0.65, 0.8), Vector3.ZERO, 0.0, rig)
	_box(Vector3(0.36, 0.03, 0.13), Vector3(0, 0.775, 0.2), _mat(Color(0.2, 0.2, 0.25), 7, Color(0.1, 0.1, 0.12)), false, Vector3(0.08, 0, 0), rig)
	# A real cube on the desk: black body, six coloured faces.
	var cube := Node3D.new()
	cube.position = Vector3(0.38, 0.81, 0.12)
	cube.rotation.y = 0.5
	rig.add_child(cube)
	_box(Vector3(0.07, 0.07, 0.07), Vector3.ZERO, _mat(Color(0.05, 0.05, 0.06)), false, Vector3.ZERO, cube)
	for f in [[Vector3(0, 0.036, 0), Vector3(0.06, 0.002, 0.06), Color(0.95, 0.95, 0.95)],
			[Vector3(0, 0, 0.036), Vector3(0.06, 0.06, 0.002), Color(0.0, 0.65, 0.3)],
			[Vector3(0.036, 0, 0), Vector3(0.002, 0.06, 0.06), Color(0.88, 0.16, 0.24)],
			[Vector3(-0.036, 0, 0), Vector3(0.002, 0.06, 0.06), Color(1.0, 0.48, 0.1)],
			[Vector3(0, 0, -0.036), Vector3(0.06, 0.06, 0.002), Color(0.14, 0.4, 0.85)]]:
		_box(f[1], f[0], _mat(f[2]), false, Vector3.ZERO, cube)
	# The record, on a poster above the desk.
	_box(Vector3(0.6, 0.42, 0.01), Vector3(0, 1.95, -0.33), _mat(Color(0.09, 0.13, 0.24)), false, Vector3.ZERO, rig)
	_label("WORLD RECORD", Vector3(0, 2.08, -0.32), 10, Color(0.24, 0.9, 0.76), Vector3.ZERO, 0.0, rig)
	_label("2.51", Vector3(0, 1.95, -0.32), 34, Color(1.0, 0.82, 0.25), Vector3.ZERO, 0.0, rig)
	_label("CAN YOU GO SUB-60?", Vector3(0, 1.82, -0.32), 7, Color(0.8, 0.85, 1.0), Vector3.ZERO, 0.0, rig)

	var screen := Node3D.new()
	screen.position = Vector3(0, cy, 0)
	rig.add_child(screen)
	if _cube_vp:
		_add_computer(screen, CUBE_SCREEN, _cube_vp, CUBE_SIZE)
	else:
		_label("NO SIGNAL", Vector3(0, 0, 0.002), 12, Color(0.4, 0.5, 0.7), Vector3.ZERO, 0.0, screen)


func _build_loot_cabinet() -> void:
	var rig := Node3D.new()
	rig.position = LOOT_SPOT
	rig.rotation.y = -PI / 2
	_world_vp.add_child(rig)
	var red := _mat(Color(0.45, 0.1, 0.09), 6, Color.BLACK, 30.0)
	var dark_red := _mat(Color(0.22, 0.05, 0.05))
	var brass := _mat(Color(0.75, 0.6, 0.28))
	var dark := _mat(Color(0.05, 0.04, 0.04))
	var h := LOOT_SCREEN.y
	var cy := 1.24
	# Body, plinth and a sloped top.
	_box(Vector3(0.62, 1.78, 0.56), Vector3(0, 0.89, -0.12), red, true, Vector3.ZERO, rig)
	_box(Vector3(0.66, 0.12, 0.6), Vector3(0, 0.06, -0.12), dark_red, false, Vector3.ZERO, rig)
	# Screen bezel: brass frame, black glass.
	_box(Vector3(LOOT_SCREEN.x + 0.08, h + 0.08, 0.02), Vector3(0, cy, 0.16), brass, false, Vector3.ZERO, rig)
	_box(Vector3(LOOT_SCREEN.x + 0.04, h + 0.04, 0.02), Vector3(0, cy, 0.165), dark, false, Vector3.ZERO, rig)
	# Coin tray and slot under the screen.
	_box(Vector3(0.5, 0.06, 0.18), Vector3(0, 0.82, 0.22), dark_red, false, Vector3.ZERO, rig)
	_box(Vector3(0.44, 0.03, 0.14), Vector3(0, 0.85, 0.23), dark, false, Vector3.ZERO, rig)
	_box(Vector3(0.1, 0.03, 0.01), Vector3(0.18, 0.66, 0.165), brass, false, Vector3.ZERO, rig)
	_label("INSERT\nCOIN", Vector3(-0.12, 0.66, 0.17), 7, Color(1.0, 0.8, 0.3), Vector3.ZERO, 0.0, rig)
	# Marquee: a glowing sign on top.
	_box(Vector3(0.66, 0.24, 0.42), Vector3(0, 1.9, -0.06), _mat(Color(0.2, 0.04, 0.04), 0, Color.BLACK, 24.0, Color(0.5, 0.12, 0.05)), false, Vector3.ZERO, rig)
	_label("LOOT\nMACHINE", Vector3(0, 1.9, 0.152), 14, Color(1.0, 0.82, 0.25), Vector3.ZERO, 0.0, rig)
	for i in 6:
		var bulb := _mat(Color.BLACK, 0, Color.BLACK, 24.0, Color(1.0, 0.85, 0.4))
		_box(Vector3(0.025, 0.025, 0.01), Vector3(-0.28 + i * 0.112, 2.0, 0.152), bulb, false, Vector3.ZERO, rig)
		_box(Vector3(0.025, 0.025, 0.01), Vector3(-0.28 + i * 0.112, 1.8, 0.152), bulb, false, Vector3.ZERO, rig)
	# Lever on the right side (your right as you face the machine).
	_box(Vector3(0.06, 0.16, 0.1), Vector3(0.34, 1.05, 0.0), brass, false, Vector3.ZERO, rig)
	_cyl(0.012, 0.42, Vector3(0.38, 1.25, 0.0), _mat(Color(0.8, 0.8, 0.8)), Vector3.ZERO, 6, -1.0, rig)
	_cyl(0.04, 0.07, Vector3(0.38, 1.48, 0.0), _mat(Color(0.85, 0.1, 0.1), 0, Color.BLACK, 24.0, Color(0.3, 0.0, 0.0)), Vector3.ZERO, 8, -1.0, rig)
	# A sticky note, because it's still an office.
	_box(Vector3(0.08, 0.08, 0.004), Vector3(-0.25, cy + h * 0.5 + 0.02, 0.172), _mat(Color(0.95, 0.88, 0.35)), false, Vector3(0, 0, 0.15), rig)
	_label("RELICS\nFOR\nALL", Vector3(-0.25, cy + h * 0.5 + 0.02, 0.176), 7, Color(0.15, 0.1, 0.1), Vector3(0, 0, 0.15), 0.0, rig)

	var screen := Node3D.new()
	screen.position = Vector3(0, cy, 0.18)
	rig.add_child(screen)
	if _loot_vp:
		_add_computer(screen, LOOT_SCREEN, _loot_vp, LOOT_SIZE)
	else:
		# Run tools/fetch_games.sh to put the Loot Machine on this screen.
		_label("OUT OF\nORDER", Vector3(0, 0, 0.002), 12, Color(1.0, 0.4, 0.3), Vector3.ZERO, 0.0, screen)


func _build_props() -> void:
	var metal := _mat(Color(0.42, 0.44, 0.42))
	var dark := _mat(Color(0.1, 0.1, 0.11))
	# Office chair, pushed aside so you can walk up.
	var chair := Node3D.new()
	chair.position = Vector3(1.25, 0, -1.7)
	chair.rotation.y = -0.7
	_world_vp.add_child(chair)
	var fabric := _mat(Color(0.18, 0.22, 0.36), 1, Color(0.14, 0.17, 0.3), 50.0)
	_box(Vector3(0.48, 0.08, 0.46), Vector3(0, 0.48, 0), fabric, true, Vector3.ZERO, chair)
	_box(Vector3(0.46, 0.5, 0.07), Vector3(0, 0.82, 0.22), fabric, false, Vector3(-0.1, 0, 0), chair)
	_cyl(0.03, 0.4, Vector3(0, 0.25, 0), dark, Vector3.ZERO, 6, -1.0, chair)
	for i in 5:
		var a := TAU * i / 5.0
		_box(Vector3(0.04, 0.03, 0.3), Vector3(sin(a) * 0.14, 0.05, cos(a) * 0.14), dark, false, Vector3(0, a, 0), chair)

	# Filing cabinet.
	_box(Vector3(0.5, 1.3, 0.6), Vector3(-3.15, 0.65, -2.6), metal, true)
	for y in [0.3, 0.62, 0.94]:
		_box(Vector3(0.44, 0.015, 0.01), Vector3(-3.15, y + 0.12, -2.29), dark)
		_box(Vector3(0.12, 0.03, 0.02), Vector3(-3.15, y, -2.29), dark)

	# Plant in the corner.
	_cyl(0.18, 0.36, Vector3(3.1, 0.18, -2.6), _mat(Color(0.55, 0.3, 0.2)), Vector3.ZERO, 7, 0.22)
	var leaf := _mat(Color(0.2, 0.45, 0.2), 6, Color.BLACK, 30.0)
	for i in 7:
		var a := TAU * i / 7.0
		_box(Vector3(0.1, 0.55, 0.03), Vector3(3.1 + sin(a) * 0.1, 0.62, -2.6 + cos(a) * 0.1), leaf, false, Vector3(cos(a) * 0.45, a, -sin(a) * 0.45))

	# Water cooler.
	_box(Vector3(0.36, 1.0, 0.36), Vector3(3.25, 0.5, 1.2), _mat(Color(0.85, 0.85, 0.82)), true)
	_cyl(0.15, 0.4, Vector3(3.25, 1.2, 1.2), _mat(Color(0.3, 0.55, 0.85), 0, Color.BLACK, 24.0, Color(0.05, 0.1, 0.2)))
	_box(Vector3(0.04, 0.04, 0.04), Vector3(3.05, 0.8, 1.2), _mat(Color(0.2, 0.3, 0.8)))

	# Trash can.
	_cyl(0.15, 0.34, Vector3(-1.05, 0.17, -2.55), _mat(Color(0.3, 0.32, 0.3)), Vector3.ZERO, 8, 0.17)

	# Poster above the desk: the game's own flyer.
	_box(Vector3(0.7, 0.9, 0.01), Vector3(-1.5, 1.6, -2.99), _mat(Color(0.08, 0.05, 0.1)))
	_label("KILLIN'\nIN", Vector3(-1.5, 1.88, -2.98), 22, Color(1.0, 0.35, 0.7))
	_label("COMEDY", Vector3(-1.5, 1.68, -2.98), 22, Color(0.35, 0.85, 1.0))
	_label("OPEN MIC\nTONITE\n8PM", Vector3(-1.5, 1.38, -2.98), 12, Color(1.0, 0.85, 0.3))
	# Motivational poster.
	_box(Vector3(0.6, 0.45, 0.01), Vector3(1.6, 1.65, -2.99), _mat(Color(0.05, 0.05, 0.05)))
	_box(Vector3(0.5, 0.28, 0.005), Vector3(1.6, 1.7, -2.985), _mat(Color(0.35, 0.5, 0.7), 4, Color(0.3, 0.42, 0.62)))
	_label("PERSEVERANCE", Vector3(1.6, 1.5, -2.98), 9, Color(0.9, 0.9, 0.85))

	# Wall clock on the right wall, showing the real time.
	var clock := Node3D.new()
	clock.position = Vector3(3.48, 2.0, 2.3)
	clock.rotation.y = -PI / 2
	_world_vp.add_child(clock)
	_cyl(0.18, 0.04, Vector3.ZERO, _mat(Color(0.92, 0.92, 0.88)), Vector3(PI / 2, 0, 0), 10, -1.0, clock)
	for spec in [[0.09, 0.016], [0.14, 0.01]]:
		var pivot := Node3D.new()
		pivot.position.z = 0.025
		clock.add_child(pivot)
		_box(Vector3(spec[1], spec[0], 0.005), Vector3(0, spec[0] * 0.45, 0), dark, false, Vector3.ZERO, pivot)
		_clock_hands.append(pivot)

	# Sign on the door side.
	_label("BREAK ROOM ->", Vector3(0.4, 1.9, 3.99), 30, Color(0.9, 0.9, 0.8), Vector3(0, PI, 0))


func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.position = Vector3(0.3, 0.0, 3.2)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	_player.add_child(shape)
	_world_vp.add_child(_player)
	_head = Node3D.new()
	_head.position.y = EYE
	_player.add_child(_head)
	_camera = Camera3D.new()
	_camera.cull_mask = LAYER_WORLD
	_camera.near = 0.05
	_camera.far = 30.0
	_head.add_child(_camera)
	_camera.current = true
	_screen_camera.near = _camera.near
	_screen_camera.far = _camera.far
	_screen_camera.current = true


func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	add_child(_hud)
	var font := preload("res://fonts/press_start_2p.ttf")
	_hint = Label.new()
	_hint.add_theme_font_override("font", font)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -270
	_hint.offset_bottom = -150
	_hint.offset_left = 30
	_hint.offset_right = -30
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hint)
	_title = Label.new()
	_title.add_theme_font_override("font", font)
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 90
	_title.offset_left = 30
	_title.offset_right = -30
	_title.text = "MONDAY, 9:02 AM\nYOU SHOULD BE WORKING."
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_title)
	# Relic and token news from the Loot Machine link.
	_toast = Label.new()
	_toast.add_theme_font_override("font", font)
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 24
	_toast.offset_left = 300
	_toast.offset_right = -300
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_hud.add_child(_toast)
	_sit_button = _hud_button("SIT DOWN", Control.PRESET_BOTTOM_RIGHT)
	_sit_button.pressed.connect(_sit_nearest)
	_stand_button = _hud_button("STAND UP", Control.PRESET_TOP_LEFT)
	_stand_button.pressed.connect(_set_seat.bind(null))
	var t := create_tween()
	t.tween_interval(3.5)
	t.tween_property(_title, "modulate:a", 0.0, 1.5)


func _hud_button(text: String, corner: Control.LayoutPreset) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", preload("res://fonts/press_start_2p.ttf"))
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(260, 96)
	b.visible = false
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.06, 0.1, 0.8)
	normal.border_color = Color(1, 1, 1, 0.8)
	normal.set_border_width_all(4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	var down := normal.duplicate()
	down.bg_color = Color(0.3, 0.25, 0.35, 0.9)
	b.add_theme_stylebox_override("pressed", down)
	_hud.add_child(b)
	_place_button(b, corner)
	return b


func _place_button(b: Button, corner: Control.LayoutPreset) -> void:
	b.set_anchors_and_offsets_preset(corner, Control.PRESET_MODE_MINSIZE, 24)
	var dx := _inset.x if b.anchor_left < 0.5 else -_inset.z
	var dy := _inset.y if b.anchor_top < 0.5 else -_inset.w
	b.offset_left += dx
	b.offset_right += dx
	b.offset_top += dy
	b.offset_bottom += dy
	# Grow inward from the corner it's pinned to.
	b.grow_horizontal = Control.GROW_DIRECTION_BEGIN if b.anchor_left > 0.5 else Control.GROW_DIRECTION_END
	b.grow_vertical = Control.GROW_DIRECTION_BEGIN if b.anchor_top > 0.5 else Control.GROW_DIRECTION_END


func _hud_button_at(point: Vector2) -> bool:
	for b in [_sit_button, _stand_button]:
		if b.visible and b.get_global_rect().has_point(point):
			return true
	return false


func _sit_nearest() -> void:
	var best: Computer
	for pc in _computers:
		if best == null or _player.global_position.distance_to(pc.screen.global_position) \
				< _player.global_position.distance_to(best.screen.global_position):
			best = pc
	_set_seat(best)


## Sit at a computer (the camera glides to frame its screen), or stand (null).
func _set_seat(pc: Computer) -> void:
	if pc == _seat:
		return
	var old := _seat
	_seat = pc
	_glide_from = _camera.global_transform
	_glide_from_fov = _camera.fov
	_glide_time = 0.5 + 0.12 * _glide_from.origin.distance_to(pc.screen.global_position) if pc else 0.5
	_glide = 0.0
	_touches.clear()
	_stick = Vector2.ZERO
	_pad_move = Vector2.ZERO
	_pad_look = Vector2.ZERO
	_pad_run = false
	_moved = true
	if _press_pc:
		_press_pc.release()
		_press_pc = null
	if pc:
		# Leave the body at the desk so standing up puts you right there.
		var xf := pc.screen.global_transform
		var fwd := xf.basis.z.normalized()
		_player.velocity = Vector3.ZERO
		_player.global_position = Vector3(xf.origin.x, 0.0, xf.origin.z) + Vector3(fwd.x, 0, fwd.z).normalized() * STAND_BACK
		_yaw = atan2(fwd.x, fwd.z)
		_pitch = -0.3
	elif old:
		old.release()
	if old:
		_let_go_keys(old)


func _on_resized() -> void:
	var s := get_window().size
	var landscape := s.x > s.y
	var base := Vector2i(1280, 720) if landscape else Vector2i(720, 1280)
	if get_window().content_scale_size != base:
		get_window().content_scale_size = base
	# Phones held upright keep a wide view instead of a narrow slit.
	for cam in [_camera, _screen_camera]:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT if landscape else Camera3D.KEEP_WIDTH
	_turn_pong(landscape)
	# STAND UP: top-left upright; bottom-left sideways, clear of Pong's music
	# button and the comedy game's cards.
	_stand_corner = Control.PRESET_BOTTOM_LEFT if landscape else Control.PRESET_TOP_LEFT
	_inset = SafeArea.get_insets(get_viewport().get_visible_rect().size)
	_apply_insets(true)


## Keeps the HUD clear of the notch, status bar and home bar.
func _apply_insets(force := false) -> void:
	var inset := SafeArea.get_insets(get_viewport().get_visible_rect().size)
	if inset == _inset and not force:
		return
	_inset = inset
	_place_button(_sit_button, Control.PRESET_BOTTOM_RIGHT)
	_place_button(_stand_button, _stand_corner)
	_hint.offset_top = -270 - _inset.w
	_hint.offset_bottom = -150 - _inset.w
	_hint.offset_left = 30 + _inset.x
	_hint.offset_right = -30 - _inset.z
	_title.offset_top = 90 + _inset.y
	_toast.offset_top = 24 + _inset.y


## Turn the Pong monitor (and Pong's window) to match the phone.
func _turn_pong(wide: bool) -> void:
	if _pong_pc == null:
		return
	var px := PONG_SIZE_WIDE if wide else PONG_SIZE
	if _pong_view.size == px:
		return
	_pong_pc.release()
	_pong_pc.pointer = null
	_pong_screen.size = px
	_pong_view.size = px
	_pong_view.content_scale_size = px
	_pong_pc.pixels = Vector2(px)
	_pong_pc.size = Vector2(PONG_SCREEN.y, PONG_SCREEN.x) if wide else PONG_SCREEN
	_pong_pc.quad.size = _pong_pc.size
	_pong_pivot.rotation.z = PI / 2 if wide else 0.0
	# Pong re-lays itself out when the main window resizes, which may run
	# before its own window has changed; nudge it once more.
	var pong := _pong_view.get_child(0)
	if pong.has_method("_update_layout"):
		pong.call_deferred("_update_layout")


# ---------------------------------------------------------------- frame

func _physics_process(delta: float) -> void:
	var move := _stick
	# WASD only: the arrow keys belong to Pong's paddle.
	if Input.is_physical_key_pressed(KEY_W):
		move.y += 1
	if Input.is_physical_key_pressed(KEY_S):
		move.y -= 1
	if Input.is_physical_key_pressed(KEY_A):
		move.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		move.x += 1
	if _pad_move.length() > PAD_DEAD:
		move += _pad_move
	move = Vector2.ZERO if _seat else move.limit_length(1.0)
	if move.length() > 0.1:
		_moved = true
	var speed := RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) or _pad_run else SPEED
	if _link:
		speed *= _link.walk_speed()
	var want := Basis(Vector3.UP, _yaw) * Vector3(move.x, 0, -move.y) * speed
	var v := _player.velocity
	v.x = lerpf(v.x, want.x, minf(1.0, delta * 12.0))
	v.z = lerpf(v.z, want.z, minf(1.0, delta * 12.0))
	v.y = 0.0 if _player.is_on_floor() else v.y - 9.8 * delta
	_player.velocity = v
	_player.move_and_slide()
	var flat := Vector2(v.x, v.z).length()
	_bob += delta * flat * 3.2
	_head.position.y = EYE + sin(_bob * 2.0) * 0.022 * minf(1.0, flat)
	_head.position.x = cos(_bob) * 0.012 * minf(1.0, flat)


func _process(delta: float) -> void:
	if _seat == null and _pad_look.length() > PAD_DEAD:
		_look(_pad_look * PAD_LOOK * delta)
	_player.rotation.y = _yaw
	_head.rotation.x = _pitch
	# Lean in a bit while looking at the monitor up close.
	var aim = _aim_at(_aim_point())
	var close: bool = aim != null and aim.dist < REACH and _seat == null
	_zoom = move_toward(_zoom, 1.0 if close else 0.0, delta * 2.5)
	var walk_fov := lerpf(70.0, 52.0, _zoom * _zoom * (3.0 - 2.0 * _zoom))
	# Glide between the walking view and the seated view.
	_glide = minf(1.0, _glide + delta / _glide_time)
	var target := _seat.seat_transform(_camera, Vector2(_world_vp.size), SEAT_FOV, SEAT_FILL) if _seat else _head.global_transform
	var target_fov := SEAT_FOV if _seat else walk_fov
	if _glide < 1.0:
		var e := _glide * _glide * (3.0 - 2.0 * _glide)
		_camera.global_transform = _glide_from.interpolate_with(target, e)
		_camera.fov = lerpf(_glide_from_fov, target_fov, e)
	else:
		_camera.global_transform = target
		_camera.fov = target_fov
	_screen_camera.global_transform = _camera.global_transform
	_screen_camera.fov = _camera.fov
	for pc in _computers:
		var dist := _camera.global_position.distance_to(pc.screen.global_position)
		pc.hi_mat.set_shader_parameter("fade", clampf((4.0 - dist) / 1.5, 0.0, 1.0))
		var vol := clampf((AUDIO_FAR - dist) / (AUDIO_FAR - AUDIO_NEAR), 0.0, 1.0)
		AudioServer.set_bus_volume_db(pc.bus, linear_to_db(maxf(vol, 0.0001)))

	# Hover the game under the crosshair (mouse) so buttons light up.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _press_pc == null:
		var pc: Computer = aim.pc if close else null
		if _hover_pc and _hover_pc != pc:
			_hover_pc.send_motion(Vector2(-1, -1))
			_let_go_keys(_hover_pc)
		_hover_pc = pc
		if pc:
			pc.send_motion(aim.uv)

	var time := Time.get_time_dict_from_system()
	if _clock_hands.size() == 2:
		_clock_hands[0].rotation.z = -TAU * (fmod(time.hour, 12) + time.minute / 60.0) / 12.0
		_clock_hands[1].rotation.z = -TAU * time.minute / 60.0

	_tick_link(delta)
	_sit_button.visible = _touch and _seat == null and not _computers.is_empty()
	_stand_button.visible = _touch and _seat != null
	_update_hint(aim, close)
	_hud.queue_redraw()


## Let the Loot Machine's relics reach the other games, and show what happened.
func _tick_link(delta: float) -> void:
	_toast_time = maxf(0.0, _toast_time - delta)
	_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
	if _link == null:
		return
	_link.tick("comedy", _game_vp.get_child(0))
	if _pong_view and _pong_view.get_child_count() > 0:
		_link.tick("pong", _pong_view.get_child(0))
	if _cube_vp and _cube_vp.get_child_count() > 0:
		_link.tick("cube", _cube_vp.get_child(0))
	var news: Array = _link.pop_news()
	if not news.is_empty():
		_toast.text = "\n".join(news)
		_toast_time = 3.5


func _update_hint(aim, close: bool) -> void:
	var text := ""
	if _pad:
		if _seat:
			text = ""
		elif close:
			text = "A: SIT DOWN"
		elif not _moved:
			text = "LEFT STICK WALK - RIGHT STICK LOOK\nA: SIT AT A COMPUTER"
	elif _touch:
		if not _moved:
			text = "TAP A COMPUTER\nTO SIT DOWN"
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		text = "CLICK TO LOOK AROUND\nWASD WALK - MOUSE LOOK - ESC LETS GO"
	elif close:
		text = ""
	elif aim != null:
		text = "GET CLOSER"
	elif not _moved:
		text = "WALK UP TO A COMPUTER"
	_hint.text = text


func _draw_hud() -> void:
	var size := _hud.size
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (_pad and _seat == null):
		var c := size * 0.5
		var aim = _aim_at(_aim_point())
		if aim != null and aim.dist < REACH:
			_hud.draw_arc(c, 9, 0, TAU, 16, Color(1, 1, 1, 0.9), 3)
		else:
			_hud.draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1, 0.85))
	if _touches.values().has("move"):
		_hud.draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.35), 4)
		_hud.draw_circle(_stick_origin + _stick * STICK_RADIUS, 34, Color(1, 1, 1, 0.35))
	elif _touch and _seat == null:
		# Ghost stick so you can see where the walk thumb goes.
		var rest := _stick_rest()
		_hud.draw_arc(rest, STICK_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.18), 4)
		_hud.draw_circle(rest, 34, Color(1, 1, 1, 0.18))


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_pad_input(event)
		return
	if event is InputEventKey and event.physical_keycode != KEY_ESCAPE:
		# Keys belong to the game you sit at or point at (Pong's arrows).
		var pc := _seat if _seat else _hover_pc
		if pc:
			pc.view.push_input(event)
	# Touch and mouse each emulate the other; only handle the real one.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_touch = true
		_pad = false
		_touch_input(event)
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton:
		_pad = false
		_mouse_button(event)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * LOOK_SENS)
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _mouse_button(event: InputEventMouseButton) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		var aim = _aim_at(_aim_point())
		if aim != null and aim.dist < REACH:
			_press_pc = aim.pc
			_press_pc.send_button(aim.uv, true)
	elif _press_pc:
		_release_press(_aim_point())


## Controller. Walking: sticks move and look, A sits down. Seated: everything
## goes to that game, except Back / Select, which stands you up.
func _pad_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and absf(event.axis_value) < PAD_DEAD and not _pad:
		return  # stick drift doesn't count as picking up the pad
	_pad = true
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK:
		if event.pressed and _seat:
			_set_seat(null)
		return
	if _seat:
		_seat.view.push_input(event)
		return
	if event is InputEventJoypadMotion:
		match event.axis:
			JOY_AXIS_LEFT_X:
				_pad_move.x = event.axis_value
			JOY_AXIS_LEFT_Y:
				_pad_move.y = -event.axis_value
			JOY_AXIS_RIGHT_X:
				_pad_look.x = event.axis_value
			JOY_AXIS_RIGHT_Y:
				_pad_look.y = event.axis_value
		return
	match event.button_index:
		JOY_BUTTON_LEFT_STICK, JOY_BUTTON_LEFT_SHOULDER:
			_pad_run = event.pressed
		JOY_BUTTON_A:
			if event.pressed and _glide >= 1.0:
				_pad_sit()


## A while walking: sit at the computer you're facing, or the nearest one
## close by.
func _pad_sit() -> void:
	var aim = _aim_at(_aim_point())
	var pc: Computer = aim.pc if aim != null and aim.dist < PAD_SIT_RANGE else null
	if pc == null:
		for c in _computers:
			var d := _player.global_position.distance_to(c.screen.global_position)
			if d < PAD_SIT_RANGE and (pc == null or d < _player.global_position.distance_to(pc.screen.global_position)):
				pc = c
	if pc == null:
		_toast.text = "WALK UP TO A COMPUTER"
		_toast_time = 2.0
		return
	_set_seat(pc)
	if not _pad_told:
		_pad_told = true
		_toast.text = "PLAYING WITH THE CONTROLLER\nBACK / SELECT: STAND UP"
		_toast_time = 3.5


## Let go of every stick, D-pad and arrow key in a game, so nothing stays
## held after you leave it.
func _let_go_keys(pc: Computer) -> void:
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		var m := InputEventJoypadMotion.new()
		m.axis = axis
		m.axis_value = 0.0
		pc.view.push_input(m)
	for b in [JOY_BUTTON_A, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = false
		pc.view.push_input(e)
	for k in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		var key := InputEventKey.new()
		key.keycode = k
		key.physical_keycode = k
		key.pressed = false
		pc.view.push_input(key)


func _stick_rest() -> Vector2:
	return Vector2(STICK_RADIUS + 50 + _inset.x, _hud.size.y - STICK_RADIUS - 60 - _inset.w)


func _touch_input(event: InputEvent) -> void:
	var i: int = event.index
	if event is InputEventScreenTouch:
		if event.pressed:
			if _hud_button_at(event.position):
				return
			var aim = _aim_at(event.position)
			if _seat:
				# Seated: every tap goes to the game; nothing else moves.
				var uv = _seat_uv(event.position, aim)
				if uv != null and _press_pc == null:
					_touches[i] = "screen"
					_press_pc = _seat
					_seat.send_button(uv, true)
			elif aim != null and _glide >= 1.0:
				# Tap a computer from anywhere to sit down at it.
				_set_seat(aim.pc)
			elif event.position.x < _hud.size.x * 0.45 and not _touches.values().has("move"):
				_touches[i] = "move"
				_stick_origin = event.position
				_stick = Vector2.ZERO
			else:
				_touches[i] = "look"
		else:
			var kind = _touches.get(i)
			_touches.erase(i)
			if kind == "screen" and _press_pc:
				_release_press(event.position)
			elif kind == "move":
				_stick = Vector2.ZERO
		return
	match _touches.get(i):
		"screen":
			var uv = _seat_uv(event.position, _aim_at(event.position))
			if uv != null and _press_pc:
				_press_pc.send_motion(uv)
		"move":
			var d: Vector2 = (event.position - _stick_origin) / STICK_RADIUS
			_stick = Vector2(d.x, -d.y).limit_length(1.0)
		"look":
			_look(event.relative * TOUCH_LOOK_SENS)


func _look(delta: Vector2) -> void:
	_yaw -= delta.x
	_pitch = clampf(_pitch - delta.y, -1.4, 1.4)


## Where the player is pointing, in HUD coordinates.
func _aim_point() -> Vector2:
	return _hud.size * 0.5


## Ray from a HUD point onto the nearest screen it hits. Returns
## {uv, dist, pc} or null.
func _aim_at(point: Vector2):
	if _hud == null or _hud.size.x <= 0:
		return null
	var px := point / _hud.size * Vector2(_world_vp.size)
	var origin := _camera.project_ray_origin(px)
	var dir := _camera.project_ray_normal(px)
	var best = null
	for pc in _computers:
		var inv := pc.screen.global_transform.affine_inverse()
		var lo := inv * origin
		var ld := inv.basis * dir
		if ld.z >= -0.0001 or lo.z <= 0:
			continue
		var t := -lo.z / ld.z
		var hit := lo + ld * t
		var uv := Vector2(hit.x / pc.size.x + 0.5, 0.5 - hit.y / pc.size.y)
		if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1:
			continue
		if best == null or t < best.dist:
			best = {"uv": uv, "dist": t, "pc": pc}
	return best


## Let go of whatever's being pressed, at this HUD point if it's still on that screen.
func _release_press(point: Vector2) -> void:
	var aim = _aim_at(point)
	var uv = _seat_uv(point, aim) if _seat == _press_pc else null
	if uv == null:
		uv = aim.uv if aim != null and aim.pc == _press_pc else _press_pc.last_uv()
	_press_pc.send_button(uv, false)
	_press_pc = null


## Where a touch lands on the seated computer's game, or null. Pong takes
## touches anywhere (clamped to its screen) so a thumb can rest at the phone's
## edge; the comedy game only takes touches on its screen.
func _seat_uv(point: Vector2, aim):
	if _seat == null:
		return null
	if not _seat.touch_events:
		return aim.uv if aim != null and aim.pc == _seat else null
	var px := point / _hud.size * Vector2(_world_vp.size)
	var origin := _camera.project_ray_origin(px)
	var dir := _camera.project_ray_normal(px)
	var inv := _seat.screen.global_transform.affine_inverse()
	var lo := inv * origin
	var ld := inv.basis * dir
	if ld.z >= -0.0001 or lo.z <= 0:
		return null
	var hit := lo + ld * (-lo.z / ld.z)
	return Vector2(clampf(hit.x / _seat.size.x + 0.5, 0.0, 1.0), clampf(0.5 - hit.y / _seat.size.y, 0.0, 1.0))
