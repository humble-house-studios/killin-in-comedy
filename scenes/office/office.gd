extends Node
## The meta office: walk up to a desk in a PS1-style office and play real
## games on the computers, first person.
## - The 3D world renders at a third of the screen size (chunky PS1 pixels),
##   lit like a sunny morning: cream walls, daylight through the blinds.
## - Each computer is a chunky beige 90s CRT (4:3); the game runs in a window
##   on its desktop (teal wallpaper, title bar, taskbar). Each game runs in
##   its own viewport; a second full-res pass draws only the game screens, so
##   they stay readable up close.
##   - Main desk: this game (res://scenes/main.tscn) in a SubViewport.
##   - Side desk: Phone Pong (res://games/pong, pulled in by tools/fetch_games.sh):
##     its window is tall when the phone is upright and goes wide when it is
##     sideways (so Pong's paddle sits under the right thumb).
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
## - Dale: the coworker under the window. Tap him (or TALK) and the camera
##   glides to his desk for a chat: subtitles, three replies to pick, and the
##   phone's own voice reading his lines. His story (engine/dale_story.gd,
##   data/dale_lines.gd) unlocks chapter by chapter as you play the games;
##   he's your guide from desk to desk, and a to-do (top left) says what's next.
## - The ladder (scenes/office/ladder.gd): once Dale's story is done, the door
##   behind you opens onto the rooms of the ladder: the arcade (coworkers to
##   talk to, machines to win tickets), the trading floor, the boardroom, the
##   corner office and the stage. Same walking, sitting and talking.
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
## Dale's chair, under the window on the left wall; he faces into the room.
const DALE_SPOT := Vector3(-3.05, 0.0, -0.6)
## Talking to Dale: how close you can click him (mouse), the camera's fov, and
## how fast his words type out (characters per second).
const DALE_REACH := 3.4
const TALK_FOV := 46.0
const TALK_CPS := 38.0
## Main monitor: screen size in metres (16:9, matches the game viewport).
const SCREEN_W := 0.66
const SCREEN_H := 0.37125
const SCREEN_POS := Vector3(0.0, 1.17, -2.38)
const GAME_SIZE := Vector2i(1280, 720)
## Pong monitor: a tall screen on the side desk by the left wall.
const PONG_SCENE := "res://games/pong/main.tscn"
const PONG_SIZE := Vector2i(720, 1280)
## Tall games run in a 90s desktop window on a 4:3 CRT: the game's own
## screen (9:16), and the CRT glass around it.
const PONG_SCREEN := Vector2(0.225, 0.4)
const CRT_GLASS := Vector2(0.68, 0.51)
## Sideways phone: Pong's window goes wide and fills more of the glass.
const PONG_SCREEN_WIDE := Vector2(0.6, 0.3375)
## Main desk CRT glass, around the 16:9 comedy screen.
const MAIN_GLASS := Vector2(0.72, 0.54)
## Side desks: CRT glass centre height, and how far forward of the desk's middle.
const SIDE_CY := 1.16
const SIDE_Z := 0.1
## Look B, slim CRT TVs: 4:3 glass sizes, and where each game's centre sits
## (lower, since a TV sits straight on the desk). Pong's wide window shrinks
## to fit the smaller glass.
const TV_GLASS := Vector2(0.56, 0.42)
const TV_MAIN_GLASS := Vector2(0.68, 0.51)
const TV_SIDE_CY := 1.08
const TV_MAIN_Y := 1.125
const PONG_SCREEN_WIDE_TV := Vector2(0.53, 0.298)
## Which look is on (0 = A beige CRT monitors, 1 = B CRT TVs), remembered here.
const LOOK_FILE := "user://office_look.cfg"
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
const CUBE_SCREEN := Vector2(0.225, 0.4)
const CUBE_DESK := Vector3(-1.6, 0.0, 3.62)
## Game audio is full volume within NEAR metres of its screen, silent past FAR.
const AUDIO_NEAR := 1.6
const AUDIO_FAR := 5.0
const PIXEL_SHRINK := 3
## Room sound: the air conditioner hums from a ceiling vent (a little louder
## under it, ducked while you sit and play), and your feet pad on the carpet.
const AC_VENT := Vector3(1.4, 2.6, 0.6)
const AC_DB := -17.0
const AC_SEATED_DUCK := -5.0
const STEP_DB := -10.0
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
## Seated: hold B this long to leave the desk (a tap of B still goes to the game).
const PAD_LEAVE_HOLD := 0.8
const PAD_CARD := [
	["L", "Walk  (click the stick to run)"],
	["R", "Look around"],
	["A", "Sit at a computer / talk to Dale"],
	["BACK", "Leave a desk  (or hold B)"],
]
const PadUI := preload("res://scenes/pad_cursor.gd")


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
## Pong's desktop window, tall and wide; one shows at a time (phone upright / sideways).
var _pong_frames: Array[Node3D] = []
## A/B looks: the nodes that belong to each look, and each screen's spot in
## each look ([screen, spot in A, spot in B]).
var _look_i := 0
var _looks: Array = [[], []]
var _screen_spots: Array = []
var _look_button: Button
var _side_a: Node3D
var _side_b: Node3D
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
## Seated with the pad: how long B has been held (-1 = not held), and how
## long the LEAVE chip still shows.
var _pad_leave := -1.0
var _pad_chip := 0.0
var _pad_card := 0.0
var _pad_carded := false

## Dale: his rig (feet on the floor, facing local +z), the parts that move,
## his story, and the talk box.
var _dale: Node3D
var _dale_body: Node3D
var _dale_head: Node3D
var _dale_mouth: Node3D
var _dale_eyes: Array[Node3D] = []
var _dale_alert: Label3D
var _dale_story: DaleStory
var _dale_time := 0.0
var _blink_in := 2.5
var _news_check := 0.0
## Milestones Dale asks for that the Loot link doesn't count (Pong boss, cube
## record, proof win), and the to-do label that shows his next goal.
var _goals := OfficeGoals.new()
## The rooms past the door, and who you're talking to ({} = Dale; else a
## person from _ladder.people(): {id, node, c, r, eye/look offsets}).
var _ladder: Node
var _speaker := {}
## Who the last _dale_hit() ray found.
var _hit_who := {}
var _todo: Label
var _talking := false
## The conversation in progress: {id, title, steps}, and where we are in it.
var _talk := {}
var _talk_i := 0
var _talk_stats := {}
## The step on screen ends the talk once read.
var _talk_last := false
var _talk_panel: PanelContainer
var _talk_name: Label
var _talk_text: Label
var _talk_buttons: VBoxContainer
var _voice := ""
## The reply a controller has highlighted.
var _talk_pick := 0
## Real voice chat with Dale (scenes/office/dale_voice.gd), once the story bit
## of a conversation is over: hold TALK, say anything.
var _voice_chat: Node
var _chatting := false
var _hold_button: Button
## Room sound (see AC_VENT): the AC loop, two footstep voices taking turns,
## and which step of the walk cycle last played.
var _ac: AudioStreamPlayer
var _feet: Array[AudioStreamPlayer] = []
var _step_sounds: Array[AudioStream] = []
var _step_i := 0
var _step_phase := 0
var _walking := false


func _ready() -> void:
	_touch = DisplayServer.is_touchscreen_available()
	get_tree().node_added.connect(_on_node_added)
	var cfg := ConfigFile.new()
	if cfg.load(LOOK_FILE) == OK:
		_look_i = clampi(int(cfg.get_value("office", "look", 0)), 0, 1)
	_build_game()
	_build_views()
	_ladder = preload("res://scenes/office/ladder.gd").new()
	add_child(_ladder)
	_ladder.setup(self)
	_build_room()
	_build_player()
	_build_room_sound()
	_build_hud()
	_build_talk_box()
	_dale_story = DaleStory.new()
	_pick_voice()
	_voice_chat = preload("res://scenes/office/dale_voice.gd").new()
	add_child(_voice_chat)
	_voice_chat.replied.connect(_on_dale_replied)
	_voice_chat.failed.connect(_on_dale_failed)
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
	# The world copy looks like a tube; the crisp up-close copy stays clean.
	lo.set_shader_parameter("crt", 1.0)
	pc.hi_mat.set_shader_parameter("crt", 0.0)
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
func _box(size: Vector3, pos: Vector3, mat: Material, solid := false, rot := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
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


func _cyl(radius: float, height: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, sides := 8, top := -1.0, parent: Node = null) -> MeshInstance3D:
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


func _label(text: String, pos: Vector3, size: int, color: Color, rot := Vector3.ZERO, width := 0.0, parent: Node = null) -> Label3D:
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


# ---------------------------------------------------------------- 90s CRTs

## A chunky beige 90s CRT, its 4:3 glass centred on pos and facing +z in
## parent space: bezel with a fat chin, dark rim, tapered tube with vents on
## top, a badge, a power LED and a swivel foot down to desk_y.
func _crt(parent: Node, pos: Vector3, glass: Vector2, shell: Material, badge: String, led: Color, desk_y := 0.76) -> void:
	var rim := _mat(Color(0.14, 0.13, 0.12))
	var vent := _mat(Color(0.45, 0.42, 0.36))
	var bw := glass.x + 0.13
	var bh := glass.y + 0.16
	var by := pos.y - 0.015
	_box(Vector3(bw, bh, 0.09), Vector3(pos.x, by, pos.z - 0.05), shell, false, Vector3.ZERO, parent)
	_box(Vector3(glass.x + 0.035, glass.y + 0.035, 0.004), Vector3(pos.x, pos.y, pos.z - 0.0045), rim, false, Vector3.ZERO, parent)
	_box(Vector3(bw * 0.86, bh * 0.84, 0.2), Vector3(pos.x, by + 0.005, pos.z - 0.19), shell, false, Vector3.ZERO, parent)
	_box(Vector3(bw * 0.58, bh * 0.58, 0.12), Vector3(pos.x, by + 0.01, pos.z - 0.34), shell, false, Vector3.ZERO, parent)
	var top := by + 0.005 + bh * 0.42
	for i in 5:
		_box(Vector3(bw * 0.5, 0.004, 0.012), Vector3(pos.x, top + 0.002, pos.z - 0.13 - i * 0.03), vent, false, Vector3.ZERO, parent)
	# Chin: badge on the left, two knobs and the power LED on the right.
	var chin := pos.y - glass.y * 0.5 - 0.048
	_label(badge, Vector3(pos.x - bw * 0.5 + 0.03 + badge.length() * 0.0075, chin, pos.z - 0.004), 7, Color(0.38, 0.35, 0.3), Vector3.ZERO, 0.0, parent)
	for k in 2:
		_box(Vector3(0.022, 0.022, 0.01), Vector3(pos.x + bw * 0.5 - 0.15 + k * 0.035, chin, pos.z - 0.004), vent, false, Vector3.ZERO, parent)
	_box(Vector3(0.026, 0.012, 0.01), Vector3(pos.x + bw * 0.5 - 0.05, chin, pos.z - 0.004), _mat(Color.BLACK, 0, Color.BLACK, 24.0, led), false, Vector3.ZERO, parent)
	# Swivel foot.
	var bottom := by - bh * 0.5
	if bottom - desk_y > 0.01:
		_box(Vector3(bw * 0.42, bottom - desk_y, 0.2), Vector3(pos.x, (bottom + desk_y) * 0.5, pos.z - 0.14), shell, false, Vector3.ZERO, parent)
	_box(Vector3(bw * 0.55, 0.02, 0.3), Vector3(pos.x, desk_y + 0.01, pos.z - 0.14), shell, false, Vector3.ZERO, parent)


## The 90s desktop lit up on a CRT's glass: wallpaper, a column of icons and
## a taskbar with a Start button and a clock. Sits just behind the game.
func _desktop(parent: Node, pos: Vector3, glass: Vector2, wallpaper: Color) -> void:
	var glow := func(c: Color) -> ShaderMaterial: return _mat(Color.BLACK, 0, Color.BLACK, 24.0, c)
	_box(Vector3(glass.x, glass.y, 0.002), Vector3(pos.x, pos.y, pos.z - 0.0025), glow.call(wallpaper), false, Vector3.ZERO, parent)
	var icon_cols := [Color(0.98, 0.9, 0.4), Color(0.92, 0.92, 0.92), Color(0.55, 0.8, 1.0)]
	for i in 3:
		_box(Vector3(0.03, 0.03, 0.002), Vector3(pos.x - glass.x * 0.5 + 0.03, pos.y + glass.y * 0.5 - 0.035 - i * 0.055, pos.z - 0.0015), glow.call(icon_cols[i]), false, Vector3.ZERO, parent)
	var bar_h := 0.03
	var bar_y := pos.y - glass.y * 0.5 + bar_h * 0.5
	_box(Vector3(glass.x, bar_h, 0.002), Vector3(pos.x, bar_y, pos.z - 0.0015), glow.call(Color(0.74, 0.74, 0.72)), false, Vector3.ZERO, parent)
	_box(Vector3(0.07, bar_h - 0.008, 0.002), Vector3(pos.x - glass.x * 0.5 + 0.042, bar_y, pos.z - 0.001), glow.call(Color(0.84, 0.84, 0.82)), false, Vector3.ZERO, parent)
	_label("Start", Vector3(pos.x - glass.x * 0.5 + 0.042, bar_y, pos.z - 0.0005), 6, Color(0.1, 0.1, 0.1), Vector3.ZERO, 0.0, parent)
	_box(Vector3(0.07, bar_h - 0.008, 0.002), Vector3(pos.x + glass.x * 0.5 - 0.042, bar_y, pos.z - 0.001), glow.call(Color(0.66, 0.66, 0.64)), false, Vector3.ZERO, parent)
	_label("9:41", Vector3(pos.x + glass.x * 0.5 - 0.042, bar_y, pos.z - 0.0005), 6, Color(0.1, 0.1, 0.1), Vector3.ZERO, 0.0, parent)


## A grey 90s window frame and blue title bar around a game screen of `game`
## size centred on pos. Returned so it can swap (Pong's tall/wide windows).
func _window_frame(parent: Node, pos: Vector3, game: Vector2, title: String) -> Node3D:
	var w := Node3D.new()
	w.position = pos
	parent.add_child(w)
	var glow := func(c: Color) -> ShaderMaterial: return _mat(Color.BLACK, 0, Color.BLACK, 24.0, c)
	var title_h := 0.03
	_box(Vector3(game.x + 0.016, game.y + 0.016 + title_h, 0.002), Vector3(0, title_h * 0.5, -0.001), glow.call(Color(0.76, 0.76, 0.74)), false, Vector3.ZERO, w)
	var ty := game.y * 0.5 + title_h * 0.5 + 0.003
	_box(Vector3(game.x + 0.008, title_h - 0.004, 0.002), Vector3(0, ty, -0.0005), glow.call(Color(0.06, 0.14, 0.6)), false, Vector3.ZERO, w)
	_label(title, Vector3(-game.x * 0.5 + 0.012 + title.length() * 0.0055, ty, 0.0), 6, Color(1, 1, 1), Vector3.ZERO, 0.0, w)
	_box(Vector3(0.018, 0.016, 0.002), Vector3(game.x * 0.5 - 0.012, ty, 0.0), glow.call(Color(0.76, 0.76, 0.74)), false, Vector3.ZERO, w)
	return w


## A beige tower PC on the floor, front facing +z: floppy slot, CD tray, LED.
func _tower(parent: Node, pos: Vector3, shell: Material) -> void:
	var dark := _mat(Color(0.2, 0.19, 0.17))
	_box(Vector3(0.2, 0.44, 0.44), pos + Vector3(0, 0.22, 0), shell, false, Vector3.ZERO, parent)
	_box(Vector3(0.15, 0.03, 0.005), pos + Vector3(0, 0.37, 0.221), dark, false, Vector3.ZERO, parent)
	_box(Vector3(0.12, 0.008, 0.005), pos + Vector3(0, 0.31, 0.221), dark, false, Vector3.ZERO, parent)
	_box(Vector3(0.02, 0.01, 0.005), pos + Vector3(0.05, 0.25, 0.221), _mat(Color.BLACK, 0, Color.BLACK, 24.0, Color(0.3, 1.0, 0.4)), false, Vector3.ZERO, parent)
	for i in 4:
		_box(Vector3(0.12, 0.004, 0.005), pos + Vector3(0, 0.06 + i * 0.02, 0.221), dark, false, Vector3.ZERO, parent)


## Shared shell colours: classic beige, and a slightly greyer putty.
func _beige() -> ShaderMaterial:
	return _mat(Color(0.86, 0.82, 0.7), 6, Color.BLACK, 40.0)


func _putty() -> ShaderMaterial:
	return _mat(Color(0.8, 0.8, 0.76), 6, Color.BLACK, 40.0)


func _build_room() -> void:
	# Room: x -3.5..3.5, z -3..4, 2.6 tall. You start by the door at +z.
	# Sunny and friendly: cream walls, soft sage carpet, warm wood trim.
	var wall := _mat(Color(0.88, 0.82, 0.68), 6, Color.BLACK, 20.0)
	var carpet := _mat(Color(0.5, 0.6, 0.56), 1, Color(0.43, 0.52, 0.49), 28.0)
	var ceiling := _mat(Color(0.93, 0.92, 0.87), 2, Color(0.64, 0.62, 0.58), 30.0)
	var trim := _mat(Color(0.58, 0.4, 0.25))
	_box(Vector3(7.4, 0.1, 7.4), Vector3(0, -0.05, 0.5), carpet, true)
	_box(Vector3(7.4, 0.1, 7.4), Vector3(0, 2.65, 0.5), ceiling, true)
	_box(Vector3(7.4, 2.6, 0.1), Vector3(0, 1.3, -3.05), wall, true)
	# South wall, with a gap for the door to the ladder (ladder.gd hangs the door).
	_box(Vector3(5.0, 2.6, 0.1), Vector3(-1.2, 1.3, 4.05), wall, true)
	_box(Vector3(1.4, 2.6, 0.1), Vector3(3.0, 1.3, 4.05), wall, true)
	_box(Vector3(1.0, 0.5, 0.1), Vector3(1.8, 2.35, 4.05), wall, true)
	_box(Vector3(0.1, 2.6, 7.2), Vector3(-3.55, 1.3, 0.5), wall, true)
	_box(Vector3(0.1, 2.6, 7.2), Vector3(3.55, 1.3, 0.5), wall, true)
	for b in [[Vector3(7.0, 0.1, 0.02), Vector3(0, 0.05, -2.99)], [Vector3(7.0, 0.1, 0.02), Vector3(0, 0.05, 3.99)],
			[Vector3(0.02, 0.1, 7.0), Vector3(-3.49, 0.05, 0.5)], [Vector3(0.02, 0.1, 7.0), Vector3(3.49, 0.05, 0.5)]]:
		_box(b[0], b[1], trim)

	# Ceiling panels, warm white.
	var panel := _mat(Color(0.2, 0.2, 0.2), 0, Color.BLACK, 24.0, Color(1.0, 0.98, 0.88))
	_box(Vector3(0.6, 0.03, 1.2), Vector3(0, 2.59, -1.6), panel)
	_box(Vector3(0.6, 0.03, 1.2), Vector3(0, 2.59, 2.2), panel)

	# Window on the left wall: bright sky through half-open blinds, and the
	# patch of sunshine it throws across the carpet.
	_box(Vector3(0.04, 1.1, 1.8), Vector3(-3.49, 1.5, -0.5), _mat(Color(0.5, 0.48, 0.42), 4, Color(0.1, 0.1, 0.1), 24.0, Color(0.72, 0.86, 1.0)))
	_box(Vector3(0.08, 1.2, 0.06), Vector3(-3.47, 1.5, 0.43), trim)
	_box(Vector3(0.08, 1.2, 0.06), Vector3(-3.47, 1.5, -1.43), trim)
	_box(Vector3(0.12, 0.05, 1.9), Vector3(-3.45, 0.93, -0.5), trim)
	_box(Vector3(1.6, 0.004, 1.7), Vector3(-2.55, 0.003, -0.45), _mat(Color(0.58, 0.66, 0.56), 1, Color(0.5, 0.58, 0.5), 28.0, Color(0.16, 0.12, 0.05)), false, Vector3(0, 0.12, 0))

	_build_desk()
	_build_pong_desk()
	_build_proof_desk()
	_build_loot_cabinet()
	_build_cube_desk()
	_build_props()
	_build_vent()
	_build_dale()
	_ladder.build()
	_set_look(_look_i, false)


## A group of nodes that only shows in one look (0 = A, 1 = B).
func _style(parent: Node, look: int) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	_looks[look].append(n)
	return n


## Switch looks: show that look's shells, move each game screen to its spot.
func _set_look(i: int, save := true) -> void:
	_look_i = i
	for k in 2:
		for n in _looks[k]:
			n.visible = k == i
	for spot in _screen_spots:
		spot[0].position = spot[1 + i]
	if _pong_pc:
		var wide := _pong_view.size.x > _pong_view.size.y
		_pong_pc.size = _pong_wide_size() if wide else PONG_SCREEN
		_pong_pc.quad.size = _pong_pc.size
	if _look_button:
		_look_button.text = "LOOK A" if i == 0 else "LOOK B"
	if save:
		var cfg := ConfigFile.new()
		cfg.set_value("office", "look", i)
		cfg.save(LOOK_FILE)
		_toast.text = "LOOK A: BEIGE CRT MONITORS" if i == 0 else "LOOK B: CRT TVS"
		_toast_time = 2.0


func _pong_wide_size() -> Vector2:
	return PONG_SCREEN_WIDE if _look_i == 0 else PONG_SCREEN_WIDE_TV


## Look B: a compact 90s CRT TV, its 4:3 glass centred on pos facing +z: thin
## bezel, speaker grille, knobs and LED under the glass, a rounded-off back,
## little feet and rabbit ears. The game shows straight on the glass.
func _tv(parent: Node, pos: Vector3, glass: Vector2, shell: Material) -> void:
	var black := _mat(Color.BLACK, 0, Color.BLACK, 24.0, Color(0.02, 0.025, 0.03))
	var rim := _mat(Color(0.08, 0.08, 0.09))
	var grille := _mat(Color(0.12, 0.12, 0.13))
	var bw := glass.x + 0.07
	var bh := glass.y + 0.13
	var by := pos.y - 0.03
	_box(Vector3(bw, bh, 0.06), Vector3(pos.x, by, pos.z - 0.035), shell, false, Vector3.ZERO, parent)
	_box(Vector3(glass.x + 0.02, glass.y + 0.02, 0.004), Vector3(pos.x, pos.y, pos.z - 0.0045), rim, false, Vector3.ZERO, parent)
	_box(Vector3(glass.x, glass.y, 0.002), Vector3(pos.x, pos.y, pos.z - 0.0025), black, false, Vector3.ZERO, parent)
	_box(Vector3(bw * 0.92, bh * 0.88, 0.14), Vector3(pos.x, by, pos.z - 0.13), shell, false, Vector3.ZERO, parent)
	_box(Vector3(bw * 0.6, bh * 0.56, 0.1), Vector3(pos.x, by + 0.01, pos.z - 0.24), shell, false, Vector3.ZERO, parent)
	var low := pos.y - glass.y * 0.5 - 0.05
	for i in 4:
		_box(Vector3(bw * 0.4, 0.006, 0.004), Vector3(pos.x - bw * 0.22, low + 0.024 - i * 0.016, pos.z - 0.004), grille, false, Vector3.ZERO, parent)
	for k in 2:
		_cyl(0.016, 0.014, Vector3(pos.x + bw * 0.5 - 0.13 + k * 0.045, low, pos.z - 0.002), grille, Vector3(PI / 2, 0, 0), 8, -1.0, parent)
	_box(Vector3(0.016, 0.01, 0.006), Vector3(pos.x + bw * 0.5 - 0.035, low, pos.z - 0.004), _mat(Color.BLACK, 0, Color.BLACK, 24.0, Color(1.0, 0.3, 0.2)), false, Vector3.ZERO, parent)
	for side in [-1, 1]:
		_box(Vector3(0.06, 0.015, 0.12), Vector3(pos.x + side * bw * 0.35, by - bh * 0.5 - 0.0075, pos.z - 0.12), rim, false, Vector3.ZERO, parent)
	var top := by + bh * 0.44
	_box(Vector3(0.08, 0.025, 0.06), Vector3(pos.x, top + 0.012, pos.z - 0.14), rim, false, Vector3.ZERO, parent)
	var chrome := _mat(Color(0.78, 0.78, 0.8))
	for side in [-1, 1]:
		_cyl(0.004, 0.32, Vector3(pos.x + side * 0.07, top + 0.15, pos.z - 0.14), chrome, Vector3(0, 0, -side * 0.45), 4, -1.0, parent)


## TV shells: charcoal, silver and off-white plastic.
func _charcoal() -> ShaderMaterial:
	return _mat(Color(0.26, 0.26, 0.28), 6, Color.BLACK, 40.0)


func _build_desk() -> void:
	var wood := _mat(Color(0.7, 0.52, 0.34), 3, Color(0.62, 0.45, 0.28), 60.0)
	var metal := _mat(Color(0.55, 0.56, 0.56))
	var beige := _beige()
	var dark := _mat(Color(0.2, 0.2, 0.2))
	# Desk: top surface at 0.76, against the back wall.
	_box(Vector3(1.8, 0.05, 0.8), Vector3(0, 0.735, -2.55), wood, true)
	_box(Vector3(0.05, 0.71, 0.75), Vector3(-0.86, 0.355, -2.55), metal, true)
	_box(Vector3(0.05, 0.71, 0.75), Vector3(0.86, 0.355, -2.55), metal, true)
	_box(Vector3(1.7, 0.4, 0.03), Vector3(0, 0.5, -2.9), metal)
	_box(Vector3(0.45, 0.6, 0.7), Vector3(0.6, 0.41, -2.55), metal, true)
	for y in [0.55, 0.3]:
		_box(Vector3(0.3, 0.02, 0.02), Vector3(0.6, y, -2.19), dark)
	_tower(_world_vp, Vector3(-0.55, 0, -2.6), beige)

	# Look A: a big beige 90s CRT, the game in a window on its desktop.
	var a := _style(_world_vp, 0)
	_crt(a, SCREEN_POS, MAIN_GLASS, beige, "SONIX 17", Color(0.2, 1.0, 0.3))
	_desktop(a, SCREEN_POS, MAIN_GLASS, Color(0.0, 0.5, 0.5))
	_window_frame(a, SCREEN_POS, Vector2(SCREEN_W, SCREEN_H), "KILLIN.EXE")
	_main_notes(a, SCREEN_POS, MAIN_GLASS.x * 0.5 + 0.03)
	# Look B: a charcoal CRT TV, the game straight on the glass.
	var b := _style(_world_vp, 1)
	var tv_pos := Vector3(SCREEN_POS.x, TV_MAIN_Y, SCREEN_POS.z)
	_tv(b, tv_pos, TV_MAIN_GLASS, _charcoal())
	_main_notes(b, tv_pos, TV_MAIN_GLASS.x * 0.5 + 0.015)

	var screen := Node3D.new()
	screen.position = SCREEN_POS
	_world_vp.add_child(screen)
	_screen_spots.append([screen, SCREEN_POS, tv_pos])
	_add_computer(screen, Vector2(SCREEN_W, SCREEN_H), _game_vp, GAME_SIZE)

	# Keyboard, mouse, mug.
	_box(Vector3(0.46, 0.03, 0.16), Vector3(-0.05, 0.775, -2.2), _mat(Color(0.88, 0.85, 0.74), 7, Color(0.5, 0.48, 0.42)), false, Vector3(0.08, 0, 0))
	_box(Vector3(0.06, 0.025, 0.1), Vector3(0.32, 0.772, -2.2), beige)
	var mug := _mat(Color(0.95, 0.45, 0.35))
	_cyl(0.045, 0.1, Vector3(-0.62, 0.81, -2.35), mug)
	_cyl(0.038, 0.005, Vector3(-0.62, 0.861, -2.35), _mat(Color(0.35, 0.2, 0.1)))
	# Paper stack.
	_box(Vector3(0.22, 0.04, 0.3), Vector3(0.7, 0.78, -2.5), _mat(Color(0.96, 0.96, 0.92)), false, Vector3(0, 0.2, 0))


## The two sticky notes on the main screen's bezel, nx out from its centre.
func _main_notes(parent: Node3D, pos: Vector3, nx: float) -> void:
	var note := _mat(Color(0.98, 0.9, 0.4))
	_box(Vector3(0.08, 0.08, 0.004), Vector3(-nx, pos.y + 0.22, pos.z), note, false, Vector3(0, 0, 0.12), parent)
	_box(Vector3(0.08, 0.08, 0.004), Vector3(nx, pos.y - 0.18, pos.z), _mat(Color(0.98, 0.6, 0.75)), false, Vector3(0, 0, -0.1), parent)
	_label("TIGHT\nFIVE!", Vector3(-nx, pos.y + 0.22, pos.z + 0.004), 10, Color(0.15, 0.1, 0.1), Vector3(0, 0, 0.12), 0.0, parent)
	_label("LAND\nAT THE\nPEAK", Vector3(nx, pos.y - 0.18, pos.z + 0.004), 7, Color(0.15, 0.1, 0.1), Vector3(0, 0, -0.1), 0.0, parent)


## Desk where a tall game runs on a 4:3 screen: in look A a beige CRT with
## the game in a desktop window (group _side_a), in look B a CRT TV
## (group _side_b). Returns the screen node (centre of the game), facing +z.
func _side_desk(rig: Node3D, wood: Material, shell: Material, badge: String, led: Color, wallpaper: Color, tv_shell: Material) -> Node3D:
	var metal := _mat(Color(0.55, 0.56, 0.56))
	_box(Vector3(1.2, 0.05, 0.7), Vector3(0, 0.735, 0), wood, true, Vector3.ZERO, rig)
	_box(Vector3(0.05, 0.71, 0.65), Vector3(-0.56, 0.355, 0), metal, true, Vector3.ZERO, rig)
	_box(Vector3(0.05, 0.71, 0.65), Vector3(0.56, 0.355, 0), metal, true, Vector3.ZERO, rig)
	var pos := Vector3(0, SIDE_CY, SIDE_Z)
	var tv_pos := Vector3(0, TV_SIDE_CY, SIDE_Z)
	_side_a = _style(rig, 0)
	_crt(_side_a, pos, CRT_GLASS, shell, badge, led)
	_desktop(_side_a, pos, CRT_GLASS, wallpaper)
	_side_b = _style(rig, 1)
	_tv(_side_b, tv_pos, TV_GLASS, tv_shell)
	_tower(rig, Vector3(-0.32, 0, -0.05), shell)
	# Keyboard and mouse.
	_box(Vector3(0.4, 0.03, 0.14), Vector3(-0.02, 0.775, 0.24), _mat(Color(0.88, 0.85, 0.74), 7, Color(0.5, 0.48, 0.42)), false, Vector3(0.08, 0, 0), rig)
	_box(Vector3(0.06, 0.025, 0.1), Vector3(0.28, 0.772, 0.24), shell, false, Vector3.ZERO, rig)
	var screen := Node3D.new()
	screen.position = pos
	rig.add_child(screen)
	_screen_spots.append([screen, pos, tv_pos])
	return screen


## Side desk by the left wall, facing into the room: Pong on a putty CRT.
func _build_pong_desk() -> void:
	var rig := Node3D.new()
	rig.position = PONG_DESK
	rig.rotation.y = PI / 2
	_world_vp.add_child(rig)
	var wood := _mat(Color(0.74, 0.62, 0.46), 3, Color(0.66, 0.55, 0.4), 60.0)
	var screen := _side_desk(rig, wood, _putty(), "PONG-O-TRON", Color(1.0, 0.4, 0.75), Color(0.42, 0.36, 0.72), _mat(Color(0.62, 0.62, 0.65), 6, Color.BLACK, 40.0))
	var a := _side_a
	for spot in [[a, CRT_GLASS.x * 0.5 + 0.02, SIDE_CY + 0.2], [_side_b, TV_GLASS.x * 0.5 + 0.01, TV_SIDE_CY + 0.16]]:
		_box(Vector3(0.08, 0.08, 0.004), Vector3(spot[1], spot[2], SIDE_Z), _mat(Color(0.6, 0.95, 0.65)), false, Vector3(0, 0, -0.15), spot[0])
		_label("BEAT\nMY\nBEST", Vector3(spot[1], spot[2], SIDE_Z + 0.004), 8, Color(0.1, 0.15, 0.1), Vector3(0, 0, -0.15), 0.0, spot[0])
	_cyl(0.05, 0.12, Vector3(0.45, 0.82, 0.12), _mat(Color(0.98, 0.85, 0.3)), Vector3.ZERO, 8, -1.0, rig)
	if _pong_view:
		_pong_frames = [_window_frame(a, screen.position, PONG_SCREEN, "PONG.EXE"),
				_window_frame(a, screen.position, PONG_SCREEN_WIDE, "PONG.EXE")]
		_pong_frames[1].visible = false
		_pong_pc = _add_computer(screen, PONG_SCREEN, _pong_view, PONG_SIZE, true, _pong_screen)
	else:
		# Run tools/fetch_games.sh to put Pong on this screen.
		_label("NO SIGNAL", Vector3(0, 0, 0.002), 12, Color(0.9, 0.9, 1.0), Vector3.ZERO, 0.0, screen)


## Desk by the right wall, facing into the room: Proof Hand on a beige CRT,
## under a chalkboard of half-finished maths.
func _build_proof_desk() -> void:
	var rig := Node3D.new()
	rig.position = PROOF_DESK
	rig.rotation.y = -PI / 2
	_world_vp.add_child(rig)
	var wood := _mat(Color(0.7, 0.52, 0.34), 3, Color(0.62, 0.45, 0.28), 60.0)
	var screen := _side_desk(rig, wood, _beige(), "THE PROVER", Color(0.3, 1.0, 0.4), Color(0.12, 0.5, 0.32), _charcoal())
	var a := _side_a
	# Coffee and a stack of scratch paper.
	_cyl(0.045, 0.1, Vector3(0.46, 0.81, 0.12), _mat(Color(0.96, 0.96, 0.94)), Vector3.ZERO, 8, -1.0, rig)
	_box(Vector3(0.22, 0.05, 0.3), Vector3(-0.44, 0.785, 0.12), _mat(Color(0.96, 0.96, 0.9)), false, Vector3(0, -0.25, 0), rig)
	# Chalkboard on the wall behind.
	var board_z := -0.33
	_box(Vector3(1.7, 0.95, 0.04), Vector3(0, 1.98, board_z), _mat(Color(0.16, 0.3, 0.24), 6, Color.BLACK, 30.0), false, Vector3.ZERO, rig)
	_box(Vector3(1.78, 0.05, 0.07), Vector3(0, 1.48, board_z + 0.02), wood, false, Vector3.ZERO, rig)
	var chalk := Color(0.92, 0.94, 0.88)
	_label("a^2 + b^2 = c^2", Vector3(-0.42, 2.28, board_z + 0.025), 14, chalk, Vector3(0, 0, 0.04), 0.0, rig)
	_label("1 + 1 = 2 ?", Vector3(0.45, 2.15, board_z + 0.025), 16, chalk, Vector3(0, 0, -0.05), 0.0, rig)
	_label("f(x) -> INF", Vector3(-0.35, 1.93, board_z + 0.025), 14, chalk, Vector3(0, 0, -0.03), 0.0, rig)
	_label("PROOF LEFT AS\nAN EXERCISE", Vector3(0.4, 1.75, board_z + 0.025), 11, Color(1.0, 0.8, 0.75), Vector3(0, 0, 0.03), 0.0, rig)
	_label("QED", Vector3(-0.55, 1.65, board_z + 0.025), 18, Color(1.0, 0.9, 0.5), Vector3(0, 0, 0.08), 0.0, rig)
	if _proof_view:
		_window_frame(a, screen.position, PONG_SCREEN, "PROOF.EXE")
		# Taps go in Proof Hand's own canvas units (its 1080×1920 base), not
		# the window's pixels.
		_add_computer(screen, PONG_SCREEN, _proof_view, PROOF_BASE, false, _proof_view.get_parent())
	else:
		# Run tools/fetch_games.sh --autoloads to put Proof Hand on this screen.
		_label("NO SIGNAL", Vector3(0, 0, 0.002), 12, Color(0.85, 1.0, 0.85), Vector3.ZERO, 0.0, screen)


## Desk by the door: Cube Desk on a putty CRT, a Rubik's cube beside the
## keyboard and the world record on the wall.
func _build_cube_desk() -> void:
	var rig := Node3D.new()
	rig.position = CUBE_DESK
	rig.rotation.y = PI
	_world_vp.add_child(rig)
	var wood := _mat(Color(0.62, 0.7, 0.78), 6, Color.BLACK, 40.0)
	var screen := _side_desk(rig, wood, _putty(), "CUBETRON", Color(0.4, 0.7, 1.0), Color(0.3, 0.5, 0.82), _mat(Color(0.84, 0.82, 0.76), 6, Color.BLACK, 40.0))
	var a := _side_a
	# A real cube on the desk: black body, six coloured faces.
	var cube := Node3D.new()
	cube.position = Vector3(0.42, 0.81, 0.16)
	cube.rotation.y = 0.5
	rig.add_child(cube)
	_box(Vector3(0.07, 0.07, 0.07), Vector3.ZERO, _mat(Color(0.08, 0.08, 0.09)), false, Vector3.ZERO, cube)
	for f in [[Vector3(0, 0.036, 0), Vector3(0.06, 0.002, 0.06), Color(0.98, 0.98, 0.98)],
			[Vector3(0, 0, 0.036), Vector3(0.06, 0.06, 0.002), Color(0.0, 0.7, 0.35)],
			[Vector3(0.036, 0, 0), Vector3(0.002, 0.06, 0.06), Color(0.92, 0.2, 0.26)],
			[Vector3(-0.036, 0, 0), Vector3(0.002, 0.06, 0.06), Color(1.0, 0.55, 0.12)],
			[Vector3(0, 0, -0.036), Vector3(0.06, 0.06, 0.002), Color(0.16, 0.45, 0.9)]]:
		_box(f[1], f[0], _mat(f[2]), false, Vector3.ZERO, cube)
	# The record, on a poster above the desk.
	_box(Vector3(0.6, 0.42, 0.01), Vector3(0, 1.95, -0.33), _mat(Color(0.14, 0.2, 0.36)), false, Vector3.ZERO, rig)
	_label("WORLD RECORD", Vector3(0, 2.08, -0.32), 10, Color(0.35, 0.95, 0.8), Vector3.ZERO, 0.0, rig)
	_label("2.51", Vector3(0, 1.95, -0.32), 34, Color(1.0, 0.85, 0.3), Vector3.ZERO, 0.0, rig)
	_label("CAN YOU GO SUB-60?", Vector3(0, 1.82, -0.32), 7, Color(0.85, 0.9, 1.0), Vector3.ZERO, 0.0, rig)
	if _cube_vp:
		_window_frame(a, screen.position, CUBE_SCREEN, "CUBE.EXE")
		_add_computer(screen, CUBE_SCREEN, _cube_vp, CUBE_SIZE)
	else:
		_label("NO SIGNAL", Vector3(0, 0, 0.002), 12, Color(0.9, 0.95, 1.0), Vector3.ZERO, 0.0, screen)


## The Loot Machine: a grubby red slot cabinet against the right wall, its
## upright screen running the game, a lever on the side.
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


## The AC vent in the ceiling: a grey frame with dark slats, where the hum comes from.
func _build_vent() -> void:
	var grey := _mat(Color(0.8, 0.8, 0.77))
	var slot := _mat(Color(0.22, 0.22, 0.23))
	_box(Vector3(0.62, 0.03, 0.62), Vector3(AC_VENT.x, 2.585, AC_VENT.z), grey)
	for i in 5:
		_box(Vector3(0.5, 0.012, 0.05), Vector3(AC_VENT.x, 2.568, AC_VENT.z - 0.2 + i * 0.1), slot)


## AC room tone and footstep players (sounds made by tools/make_audio.py).
## They play on Master, outside every game's bus, so no desk fades them.
func _build_room_sound() -> void:
	var hum := load("res://audio/office_ac.ogg") as AudioStreamOggVorbis
	hum.loop = true
	_ac = AudioStreamPlayer.new()
	_ac.stream = hum
	_ac.volume_db = AC_DB
	add_child(_ac)
	for k in 4:
		_step_sounds.append(load("res://audio/step_%d.wav" % (k + 1)))
	for k in 2:
		var feet := AudioStreamPlayer.new()
		feet.volume_db = STEP_DB
		add_child(feet)
		_feet.append(feet)
	# Browsers hold sound until the first tap or key; elsewhere start now.
	if not OS.has_feature("web"):
		_ac.play()


func _start_room_sound() -> void:
	if _ac and not _ac.playing:
		_ac.play()


## Louder under the vent, quieter across the room, ducked while seated.
func _tick_room_sound(delta: float) -> void:
	var dist := _camera.global_position.distance_to(AC_VENT)
	var want := AC_DB + lerpf(3.0, -3.0, clampf((dist - 1.0) / 4.5, 0.0, 1.0))
	if _seat or _talking:
		want += AC_SEATED_DUCK
	_ac.volume_db = move_toward(_ac.volume_db, want, delta * 12.0)


## A footstep each time the head bob dips (so steps match the camera), harder
## when running, plus a soft last step when you stop.
func _tick_steps(flat: float) -> void:
	var moving := flat > 0.4 and _player.is_on_floor()
	var phase := int(floor((_bob - PI * 0.75) / PI))
	if moving and phase != _step_phase:
		var run := clampf((flat - SPEED) / (RUN_SPEED - SPEED), 0.0, 1.0)
		_play_step(lerpf(-2.0, 2.5, run) + lerpf(-4.0, 0.0, minf(1.0, flat / SPEED)))
	elif _walking and not moving:
		_play_step(-6.0)
	_step_phase = phase
	_walking = moving


func _play_step(db: float) -> void:
	var feet := _feet[_step_i % _feet.size()]
	var pick := randi() % _step_sounds.size()
	if _step_sounds[pick] == feet.stream:
		pick = (pick + 1) % _step_sounds.size()
	feet.stream = _step_sounds[pick]
	feet.volume_db = STEP_DB + db
	feet.pitch_scale = randf_range(0.9, 1.1)
	feet.play()
	_step_i += 1


func _build_props() -> void:
	var metal := _mat(Color(0.62, 0.64, 0.62))
	var dark := _mat(Color(0.1, 0.1, 0.11))
	# Office chair, pushed aside so you can walk up.
	var chair := Node3D.new()
	chair.position = Vector3(1.25, 0, -1.7)
	chair.rotation.y = -0.7
	_world_vp.add_child(chair)
	var fabric := _mat(Color(0.3, 0.45, 0.66), 1, Color(0.25, 0.38, 0.58), 50.0)
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
	var leaf := _mat(Color(0.32, 0.64, 0.32), 6, Color.BLACK, 30.0)
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


## Dale's corner under the window: a cluttered desk facing into the room, and
## Dale himself behind it, built from chunky PS1 boxes like everything else.
func _build_dale() -> void:
	_dale = Node3D.new()
	_dale.position = DALE_SPOT
	_dale.rotation.y = PI / 2
	_world_vp.add_child(_dale)
	var r := _dale
	var wood := _mat(Color(0.7, 0.52, 0.34), 3, Color(0.62, 0.45, 0.28), 60.0)
	var metal := _mat(Color(0.55, 0.56, 0.56))
	var dark := _mat(Color(0.1, 0.1, 0.11))
	var skin := _mat(Color(0.93, 0.72, 0.58))
	var shirt := _mat(Color(0.86, 0.84, 0.66), 6, Color.BLACK, 40.0)
	var hair := _mat(Color(0.36, 0.24, 0.15))
	var tie := _mat(Color(0.62, 0.12, 0.42), 4, Color(0.5, 0.08, 0.34), 40.0)
	var pants := _mat(Color(0.22, 0.24, 0.3))

	# Chair behind him.
	var fabric := _mat(Color(0.6, 0.36, 0.28), 1, Color(0.52, 0.3, 0.24), 50.0)
	_box(Vector3(0.56, 0.08, 0.5), Vector3(0, 0.46, 0), fabric, false, Vector3.ZERO, r)
	_box(Vector3(0.54, 0.62, 0.08), Vector3(0, 0.86, -0.3), fabric, false, Vector3(0.12, 0, 0), r)
	_cyl(0.03, 0.4, Vector3(0, 0.22, 0), dark, Vector3.ZERO, 6, -1.0, r)

	# Desk in front of him (top at 0.76), with a modesty panel facing the room.
	var dz := 0.62
	_box(Vector3(1.3, 0.05, 0.62), Vector3(0, 0.735, dz), wood, true, Vector3.ZERO, r)
	_box(Vector3(1.26, 0.6, 0.03), Vector3(0, 0.42, dz + 0.29), wood, true, Vector3.ZERO, r)
	_box(Vector3(0.05, 0.71, 0.58), Vector3(-0.62, 0.355, dz), metal, true, Vector3.ZERO, r)
	_box(Vector3(0.38, 0.6, 0.5), Vector3(0.42, 0.41, dz), metal, true, Vector3.ZERO, r)
	for y in [0.58, 0.36]:
		_box(Vector3(0.12, 0.02, 0.01), Vector3(0.42, y, dz - 0.25), dark, false, Vector3.ZERO, r)
	# Nameplate, facing you.
	_box(Vector3(0.34, 0.07, 0.03), Vector3(0.0, 0.795, dz + 0.24), _mat(Color(0.75, 0.6, 0.28)), false, Vector3(-0.3, 0, 0), r)
	_label("DALE P.\nACCTS RECEIVABLE", Vector3(0.0, 0.797, dz + 0.258), 7, Color(0.15, 0.1, 0.05), Vector3(-0.3, 0, 0), 0.0, r)
	# His old monitor, turned away to the side so you can see him.
	var beige := _beige()
	_box(Vector3(0.36, 0.3, 0.3), Vector3(-0.5, 0.95, dz - 0.12), beige, false, Vector3(0, -0.9, 0), r)
	_box(Vector3(0.2, 0.03, 0.18), Vector3(-0.5, 0.78, dz - 0.12), beige, false, Vector3(0, -0.9, 0), r)
	# A purple sticky note on its side. Hmm.
	_box(Vector3(0.07, 0.07, 0.004), Vector3(-0.38, 1.0, dz + 0.04), _mat(Color(0.72, 0.5, 0.95)), false, Vector3(0, -0.9, 0.1), r)
	# Mug, invoices, a purple pen.
	_cyl(0.045, 0.1, Vector3(0.42, 0.81, dz + 0.08), _mat(Color(0.95, 0.95, 0.92)), Vector3.ZERO, 8, -1.0, r)
	_label("#1\nDAD", Vector3(0.42, 0.815, dz + 0.127), 5, Color(0.2, 0.3, 0.7), Vector3.ZERO, 0.0, r)
	_box(Vector3(0.24, 0.05, 0.3), Vector3(0.18, 0.785, dz - 0.02), _mat(Color(0.92, 0.92, 0.86)), false, Vector3(0, 0.15, 0), r)
	_box(Vector3(0.012, 0.012, 0.14), Vector3(0.05, 0.768, dz + 0.12), _mat(Color(0.55, 0.25, 0.85)), false, Vector3(0, 0.7, 0), r)

	# Dale. The body breathes; the head turns to look at you.
	_dale_body = Node3D.new()
	_dale_body.position = Vector3(0, 0.5, 0)
	r.add_child(_dale_body)
	var b := _dale_body
	# Legs, mostly hidden by the desk.
	_box(Vector3(0.44, 0.16, 0.42), Vector3(0, 0.06, 0.16), pants, false, Vector3.ZERO, b)
	# Belly and chest: a big round shirt.
	_ball(0.31, Vector3(0, 0.3, 0.05), shirt, b, Vector3(1.05, 1.0, 0.95))
	_ball(0.26, Vector3(0, 0.52, -0.02), shirt, b, Vector3(1.15, 0.8, 0.9))
	# Tie, riding the curve of the belly.
	_box(Vector3(0.07, 0.04, 0.03), Vector3(0, 0.66, 0.17), tie, false, Vector3.ZERO, b)
	_box(Vector3(0.06, 0.24, 0.02), Vector3(0, 0.52, 0.24), tie, false, Vector3(0.25, 0, 0), b)
	_box(Vector3(0.06, 0.12, 0.02), Vector3(0, 0.34, 0.33), tie, false, Vector3(-0.15, 0, 0), b)
	# Shoulders, sleeves and arms resting on the desk.
	for side in [-1, 1]:
		_ball(0.1, Vector3(side * 0.3, 0.6, -0.02), shirt, b)
		_box(Vector3(0.12, 0.26, 0.12), Vector3(side * 0.34, 0.46, 0.04), shirt, false, Vector3(0.5, 0, side * 0.12), b)
		_box(Vector3(0.1, 0.1, 0.3), Vector3(side * 0.3, 0.3, 0.26), skin, false, Vector3(0.0, -side * 0.25, 0), b)
		_box(Vector3(0.1, 0.06, 0.1), Vector3(side * 0.22, 0.29, 0.42), skin, false, Vector3.ZERO, b)
	# Neck and double chin.
	_box(Vector3(0.2, 0.08, 0.18), Vector3(0, 0.7, 0.0), skin, false, Vector3.ZERO, b)
	_dale_head = Node3D.new()
	_dale_head.position = Vector3(0, 0.74, 0.0)
	b.add_child(_dale_head)
	var h := _dale_head
	_box(Vector3(0.27, 0.27, 0.25), Vector3(0, 0.15, 0.02), skin, false, Vector3.ZERO, h)
	_box(Vector3(0.23, 0.06, 0.06), Vector3(0, 0.02, 0.12), skin, false, Vector3.ZERO, h)
	# Bald on top, a horseshoe of brown hair around the sides and back.
	_box(Vector3(0.29, 0.1, 0.12), Vector3(0, 0.2, -0.07), hair, false, Vector3.ZERO, h)
	for side in [-1, 1]:
		_box(Vector3(0.03, 0.1, 0.16), Vector3(side * 0.14, 0.19, 0.0), hair, false, Vector3.ZERO, h)
		# Ears.
		_box(Vector3(0.03, 0.06, 0.04), Vector3(side * 0.145, 0.14, 0.03), skin, false, Vector3.ZERO, h)
	# Glasses: two dark frames and a bridge, eyes behind.
	var frame := _mat(Color(0.08, 0.08, 0.1))
	var glass := _mat(Color(0.75, 0.85, 0.9), 0, Color.BLACK, 24.0, Color(0.12, 0.15, 0.18))
	for side in [-1, 1]:
		_box(Vector3(0.09, 0.065, 0.01), Vector3(side * 0.06, 0.17, 0.146), frame, false, Vector3.ZERO, h)
		_box(Vector3(0.07, 0.045, 0.01), Vector3(side * 0.06, 0.17, 0.149), glass, false, Vector3.ZERO, h)
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.06, 0.17, 0.155)
		h.add_child(eye)
		_box(Vector3(0.022, 0.026, 0.006), Vector3.ZERO, dark, false, Vector3.ZERO, eye)
		_dale_eyes.append(eye)
		# Eyebrows.
		_box(Vector3(0.07, 0.014, 0.01), Vector3(side * 0.06, 0.218, 0.15), hair, false, Vector3(0, 0, side * -0.12), h)
	_box(Vector3(0.03, 0.012, 0.01), Vector3(0, 0.175, 0.15), frame, false, Vector3.ZERO, h)
	# Nose, moustache, mouth (it opens while he talks).
	_box(Vector3(0.045, 0.05, 0.04), Vector3(0, 0.12, 0.155), _mat(Color(0.9, 0.6, 0.5)), false, Vector3.ZERO, h)
	_box(Vector3(0.12, 0.025, 0.02), Vector3(0, 0.085, 0.148), hair, false, Vector3.ZERO, h)
	_dale_mouth = Node3D.new()
	_dale_mouth.position = Vector3(0, 0.058, 0.146)
	h.add_child(_dale_mouth)
	_box(Vector3(0.07, 0.03, 0.01), Vector3.ZERO, _mat(Color(0.35, 0.1, 0.1)), false, Vector3.ZERO, _dale_mouth)
	_dale_mouth.scale.y = 0.25

	# A floating "!" when he has something new to tell you.
	_dale_alert = _label("!", Vector3(0, 1.72, 0), 48, Color(1.0, 0.85, 0.3), Vector3.ZERO, 0.0, r)
	_dale_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_dale_alert.visible = false


## A low-poly sphere (faceted, like the rest of the room).
func _ball(radius: float, pos: Vector3, mat: Material, parent: Node3D, squash := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = LAYER_WORLD
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- Dale talk

## The talk box: Dale's name and story file, his line typing out, and the
## replies (or NEXT) underneath.
func _build_talk_box() -> void:
	var font := preload("res://fonts/press_start_2p.ttf")
	_talk_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.1, 0.92)
	style.border_color = Color(0.72, 0.5, 0.95)
	style.set_border_width_all(4)
	style.set_content_margin_all(22)
	_talk_panel.add_theme_stylebox_override("panel", style)
	_talk_panel.visible = false
	_hud.add_child(_talk_panel)
	_talk_panel.gui_input.connect(_on_talk_box_input)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_talk_panel.add_child(col)
	_talk_name = Label.new()
	_talk_name.add_theme_font_override("font", font)
	_talk_name.add_theme_font_size_override("font_size", 16)
	_talk_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	col.add_child(_talk_name)
	_talk_text = Label.new()
	_talk_text.add_theme_font_override("font", font)
	_talk_text.add_theme_font_size_override("font_size", 21)
	_talk_text.add_theme_constant_override("line_spacing", 10)
	_talk_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talk_text.custom_minimum_size.y = 120
	_talk_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	col.add_child(_talk_text)
	_talk_buttons = VBoxContainer.new()
	_talk_buttons.add_theme_constant_override("separation", 10)
	col.add_child(_talk_buttons)
	_place_talk_box()


func _place_talk_box() -> void:
	if _talk_panel == null:
		return
	var w := _hud.size.x
	var side := maxf(20.0, (w - 980.0) * 0.5)
	_talk_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_talk_panel.offset_left = side + _inset.x
	_talk_panel.offset_right = -side - _inset.z
	_talk_panel.offset_bottom = -24 - _inset.w
	_talk_panel.offset_top = -24 - _inset.w
	_talk_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _talk_button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", preload("res://fonts/press_start_2p.ttf"))
	b.add_theme_font_size_override("font_size", 19)
	b.custom_minimum_size = Vector2(0, 88)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.11, 0.22)
	normal.border_color = Color(1, 1, 1, 0.7)
	normal.set_border_width_all(3)
	normal.set_content_margin_all(16)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	var down := normal.duplicate()
	down.bg_color = Color(0.4, 0.26, 0.55)
	b.add_theme_stylebox_override("pressed", down)
	b.pressed.connect(action)
	_talk_buttons.add_child(b)


## Walk up to Dale's desk (or a coworker) and start the next conversation
## (or leave). who: a person from _ladder.people(), or {} for Dale.
func _set_talk(on: bool, who := {}) -> void:
	if on == _talking:
		return
	if on:
		_speaker = who
	if on and _seat:
		_seat.release()
		_seat = null
	_talking = on
	_glide_from = _camera.global_transform
	_glide_from_fov = _camera.fov
	_glide_time = 0.5 + 0.12 * _glide_from.origin.distance_to(_talk_node().global_position) if on else 0.5
	_glide = 0.0
	_touches.clear()
	_stick = Vector2.ZERO
	_moved = true
	if _press_pc:
		_press_pc.release()
		_press_pc = null
	_talk_panel.visible = on
	_place_stand_button()
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var node := _talk_node()
		var fwd := node.global_transform.basis.z
		fwd = Vector3(fwd.x, 0, fwd.z).normalized()
		_player.velocity = Vector3.ZERO
		_player.global_position = Vector3(node.global_position.x, 0.0, node.global_position.z) + fwd * 1.5
		_yaw = atan2(fwd.x, fwd.z)
		_pitch = -0.15
		if _speaker.is_empty():
			_dale_alert.visible = false
			_talk_stats = DaleStory.read_stats()
			_talk = _dale_story.next_talk(_talk_stats)
		else:
			_talk = _ladder.talk(_speaker.id)
		_talk_i = 0
		_show_step()
	else:
		_hush()
		_voice_chat.cancel()
		_chatting = false
		if not _speaker.is_empty():
			_ladder.end_talk(_speaker.id, _talk_i >= _talk.steps.size() - 1)
		_speaker = {}


## Who you're talking to: Dale, or a coworker (or the memo) up the ladder.
func _talk_node() -> Node3D:
	return _dale if _speaker.is_empty() else _speaker.node


## Where the camera sits while you chat: across his desk, Dale in the top part
## of the screen so the talk box doesn't cover his face.
func _talk_view() -> Transform3D:
	var landscape := _world_vp.size.x > _world_vp.size.y
	var xf := _talk_node().global_transform
	var eye := xf * (Vector3(0, 1.3, 1.55) if landscape else Vector3(0, 1.28, 1.9))
	var look := xf * (Vector3(0, 1.02, 0) if landscape else Vector3(0, 0.78, 0))
	if not _speaker.is_empty():
		eye = xf * (_speaker.eye_l if landscape else _speaker.eye_p)
		look = xf * (_speaker.look_l if landscape else _speaker.look_p)
	return Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)


func _show_step() -> void:
	for c in _talk_buttons.get_children():
		c.queue_free()
	var steps: Array = _talk.steps
	var title: String = _talk.title
	_talk_name.text = "DALE" + ("  -  %s: %s" % [_dale_story.file_label(), title] if title != "" else "")
	if not _speaker.is_empty():
		_talk_name.text = title
	if _talk_i >= steps.size():
		_end_talk()
		return
	var step: Dictionary = steps[_talk_i]
	_talk_last = _talk_i == steps.size() - 1
	if step.has("choices"):
		# Only the replies, so the box stays short and his face stays in view.
		_talk_text.text = "..."
		_talk_text.visible = false
		_talk_text.visible_characters = -1
		for c in step.choices:
			var tag: String = c.get("tag", "")
			_talk_button(("%s: %s" % [tag, c.text]) if tag != "" else c.text, _choose.bind(c))
		_talk_pick = 0
		_show_pick()
		return
	_say(step.get("dale", step.get("line", "")))
	_end_buttons()


func _choose(choice: Dictionary) -> void:
	for c in _talk_buttons.get_children():
		c.queue_free()
	var reply: String
	if _speaker.is_empty():
		_dale_story.add_trust(int(choice.get("trust", 0)))
		reply = choice.reply
	else:
		# A coworker answers, then any payout lines (a bonus, a secret, a perk)
		# follow as their own lines.
		var lines: Array = _ladder.choose(_speaker.id, choice)
		reply = lines[0] if not lines.is_empty() else ""
		var steps: Array = _talk.steps
		for i in range(lines.size() - 1, 0, -1):
			steps.insert(_talk_i + 1, {"line": lines[i]})
	_talk_last = _talk_i == _talk.steps.size() - 1
	_say(reply)
	_end_buttons()


## NEXT, or at the end of the story bit: HOLD TO TALK (when Dale's voice
## server is set up) and SEE YA.
func _end_buttons() -> void:
	if not _talk_last:
		_talk_button("NEXT >>", _advance)
		return
	# The story bit is done; remember it now, so chatting on doesn't lose it.
	if not _speaker.is_empty():
		_talk_button("SEE YA", _advance)
		_talk_pick = 0
		_show_pick()
		return
	_dale_story.finish(_talk.id, _talk_stats)
	if _voice_chat.available():
		_add_hold_button()
	_talk_button("SEE YA", _advance)
	_talk_pick = 0
	_show_pick()


## HOLD TO TALK, with the key or button to hold on a computer or controller.
func _hold_label() -> String:
	if _pad:
		return "HOLD TO TALK (A / Y)"
	if not _touch:
		return "HOLD TO TALK (SPACE)"
	return "HOLD TO TALK"


func _add_hold_button() -> void:
	_talk_button(_hold_label(), func(): pass)
	_hold_button = _talk_buttons.get_child(_talk_buttons.get_child_count() - 1)
	_hold_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_hold_button.button_down.connect(_hold_talk)
	_voice_chat.warm_up()
	_hold_button.button_up.connect(_release_talk)


func _hold_talk() -> void:
	if _voice_chat.busy or _voice_chat.listening():
		return
	_hush()
	if _voice_chat.start_listening():
		_chatting = true
		_talk_name.text = "DALE  -  LISTENING..."
		_hold_button.text = "LISTENING... (LET GO TO SEND)"


func _release_talk() -> void:
	if not _voice_chat.listening():
		return
	_voice_chat.stop_listening(_dale_story.persona(_talk_stats))
	if _voice_chat.busy:
		_talk_name.text = "DALE  -  THINKING..."
		_hold_button.text = "..."
		_hold_button.disabled = true


func _on_dale_replied(heard: String, reply: String) -> void:
	if not _talking:
		return
	_talk_name.text = "YOU: " + heard.to_upper().left(60)
	_say(reply, not _voice_chat.speaking())
	_reset_hold_button()


func _on_dale_failed(message: String) -> void:
	if not _talking:
		return
	# The mic readout (how long you held, how much sound arrived) helps tell a
	# blocked mic from a quiet one.
	_talk_name.text = "DALE" + ("   [%s]" % _voice_chat.mic_report if _voice_chat.mic_report != "" else "")
	_voice_chat.mic_report = ""
	_say(message, false)
	_voice_chat.play_line(message)
	_reset_hold_button()


func _reset_hold_button() -> void:
	if is_instance_valid(_hold_button):
		_hold_button.disabled = false
		_hold_button.text = _hold_label()


## NEXT: finish typing the line first, then move on.
func _advance() -> void:
	if _waiting_for_choice():
		return
	if _talk_text.visible_characters >= 0 and _talk_text.visible_characters < _talk_text.text.length():
		_talk_text.visible_characters = -1
		return
	_talk_i += 1
	if _talk_i >= _talk.steps.size():
		_end_talk()
	else:
		_show_step()


## Is Dale waiting for you to pick a reply?
func _waiting_for_choice() -> bool:
	return _talking and _talk_i < _talk.steps.size() and _talk.steps[_talk_i].has("choices") \
			and _talk_text.text == "..."


func _on_talk_box_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
	# Tapping the line itself works like NEXT (not while a reply is wanted,
	# and never on the last line: that would walk away before HOLD TO TALK).
	if pressed and not _chatting:
		if _talk_last and _talk_text.visible_characters < 0:
			return
		_advance()


func _end_talk() -> void:
	if _speaker.is_empty():
		_dale_story.finish(_talk.id, _talk_stats)
		_dale_alert.visible = false
	_voice_chat.cancel()
	_chatting = false
	_set_talk(false)


func _say(line: String, speak := true) -> void:
	_talk_text.visible = true
	_talk_text.text = line
	_talk_text.visible_characters = 0
	if speak and _voice_chat.play_line(line):
		return
	if speak and _voice != "":
		# A slower, lower voice for Dale. The phone's own speech voice, so it
		# works offline on every platform (web uses the browser's).
		DisplayServer.tts_speak(line, _voice, 80, 0.8, 0.95, 0, true)


func _hush() -> void:
	if _voice_chat:
		_voice_chat.stop_speaking()
	if _voice != "":
		DisplayServer.tts_stop()


func _pick_voice() -> void:
	if not ProjectSettings.get_setting("audio/general/text_to_speech", false) or DisplayServer.get_name() == "headless":
		return
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if not voices.is_empty():
		_voice = voices[0]


## Dale's idle life: breathing, blinking, looking at you, a mouth that moves
## while his line types out, and a "!" when there's a new chapter.
func _tick_dale(delta: float) -> void:
	_dale_time += delta
	_dale_body.scale = Vector3(1.0 + sin(_dale_time * 1.7) * 0.012, 1.0 + sin(_dale_time * 1.7) * 0.018, 1.0)
	var to_you := _dale.to_local(_camera.global_position)
	var yaw := clampf(atan2(to_you.x, to_you.z), -0.7, 0.7)
	_dale_head.rotation.y = lerp_angle(_dale_head.rotation.y, yaw, minf(1.0, delta * 4.0))
	_dale_head.rotation.x = lerpf(_dale_head.rotation.x, clampf(-atan2(to_you.y - 1.3, Vector2(to_you.x, to_you.z).length()) * 0.5, -0.3, 0.3), minf(1.0, delta * 4.0))
	_blink_in -= delta
	var shut := _blink_in < 0.0
	if _blink_in < -0.12:
		_blink_in = randf_range(2.0, 5.0)
	for eye in _dale_eyes:
		eye.scale.y = 0.15 if shut else 1.0
	var typing := false
	if _talking and _talk_text.visible_characters >= 0:
		var n := _talk_text.text.length()
		var shown := mini(n, _talk_text.visible_characters + maxi(1, int(TALK_CPS * delta + randf())))
		_talk_text.visible_characters = -1 if shown >= n else shown
		typing = shown < n
	var talking: bool = _speaker.is_empty() and (typing or _voice_chat.speaking() or (_voice != "" and _talking and DisplayServer.tts_is_speaking()))
	var open := 0.6 + 0.6 * absf(sin(_dale_time * 13.0)) if talking else 0.25
	_dale_mouth.scale.y = lerpf(_dale_mouth.scale.y, open, minf(1.0, delta * 20.0))
	# Every couple of seconds, see whether the games unlocked a new chapter.
	_news_check -= delta
	if _news_check <= 0.0 and not _talking:
		_news_check = 2.0
		var stats := DaleStory.read_stats()
		_dale_alert.visible = _dale_story.has_news(stats)
		if _todo:
			var goal := _dale_story.objective(stats)
			if _dale_story.next_chapter().is_empty():
				goal = _ladder.objective()
			_todo.text = "TO-DO: " + goal if goal != "" else ""
	if _dale_alert.visible:
		_dale_alert.position.y = 1.72 + sin(_dale_time * 3.0) * 0.04


## Everyone you can talk to: Dale ({} as the speaker) and, up the ladder,
## whoever is around (coworkers, the memo, Dale at the stage).
## Only people in the room you're standing in count (never through a wall).
func _talkers() -> Array:
	var out: Array = []
	if _ladder == null or _ladder.room() == "office":
		out.append({"id": "", "node": _dale, "c": Vector3(0, 1.05, 0.1), "r": 0.45})
	if _ladder:
		out.append_array(_ladder.people())
	return out


## Ray from a HUD point to whoever you can talk to: the distance to the
## nearest one it hits (remembered in _hit_who), or -1 if it misses.
func _dale_hit(point: Vector2) -> float:
	if _dale == null or _hud.size.x <= 0:
		return -1.0
	var px := point / _hud.size * Vector2(_world_vp.size)
	var o := _camera.project_ray_origin(px)
	var d := _camera.project_ray_normal(px)
	var best := -1.0
	for who in _talkers():
		var c: Vector3 = who.node.global_transform * who.c
		var t := (c - o).dot(d)
		if t < 0.0 or (o + d * t).distance_to(c) > who.r:
			continue
		if best >= 0.0 and t >= best:
			continue
		if _occluded(o, c, 0.6):
			continue
		best = t
		_hit_who = {} if who.id == "" else who
	return best


## The nearest person to talk to: {who, dist}.
func _nearest_talker() -> Dictionary:
	var me := _player.global_position
	var best := {}
	var bd := INF
	for who in _talkers():
		var dist := me.distance_to(who.node.global_position)
		if dist < bd:
			bd = dist
			best = {} if who.id == "" else who
	return {"who": best, "dist": bd}


func _dale_nearer_than_computers() -> bool:
	var me := _player.global_position
	var to_dale: float = _nearest_talker().dist
	if to_dale == INF:
		return false
	for pc in _computers:
		if pc.screen.is_visible_in_tree() and me.distance_to(pc.screen.global_position) < to_dale:
			return false
	return true


## Is there a wall (or anything solid) between a and b? `slack` metres short
## of b are ignored, so the thing you're aiming at doesn't block itself.
func _occluded(a: Vector3, b: Vector3, slack := 0.05) -> bool:
	var space := _world_vp.find_world_3d().direct_space_state
	var dir := b - a
	var len := dir.length()
	if len <= slack:
		return false
	var q := PhysicsRayQueryParameters3D.create(a, a + dir / len * (len - slack))
	q.exclude = [_player.get_rid()]
	return not space.intersect_ray(q).is_empty()


func _place_stand_button() -> void:
	var landscape := _hud.size.x > _hud.size.y
	_stand_button.text = "BYE" if _talking else "STAND UP"
	# STAND UP: top-left upright; bottom-left sideways, clear of Pong's music
	# button and the comedy game's cards. Talking, it stays clear of the talk box.
	_stand_corner = Control.PRESET_BOTTOM_LEFT if landscape and not _talking else Control.PRESET_TOP_LEFT
	_place_button(_stand_button, _stand_corner)


func _stand_up() -> void:
	if _talking:
		_set_talk(false)
	else:
		_set_seat(null)


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
	# Dale's next goal, top left while walking.
	_todo = Label.new()
	_todo.add_theme_font_override("font", font)
	_todo.add_theme_font_size_override("font_size", 14)
	_todo.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_todo.add_theme_color_override("font_outline_color", Color.BLACK)
	_todo.add_theme_constant_override("outline_size", 6)
	_todo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_todo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_todo.offset_left = 24
	_todo.offset_top = 24
	_todo.offset_right = 24 + 260
	_todo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_todo)
	_sit_button = _hud_button("SIT DOWN", Control.PRESET_BOTTOM_RIGHT)
	_sit_button.pressed.connect(_sit_nearest)
	_stand_button = _hud_button("STAND UP", Control.PRESET_TOP_LEFT)
	_stand_button.pressed.connect(_stand_up)
	# A/B test the screens: beige CRT monitors (A) or CRT TVs (B). L on keys.
	_look_button = _hud_button("LOOK A" if _look_i == 0 else "LOOK B", Control.PRESET_TOP_RIGHT)
	_look_button.custom_minimum_size = Vector2(200, 88)
	_place_button(_look_button, Control.PRESET_TOP_RIGHT)
	_look_button.pressed.connect(func(): _set_look(1 - _look_i))
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


func _dale_aimed() -> bool:
	var t := _dale_hit(_aim_point())
	return t >= 0.0 and t < DALE_REACH and not _talking and _seat == null


func _hud_button_at(point: Vector2) -> bool:
	for b in [_sit_button, _stand_button, _look_button]:
		if b.visible and b.get_global_rect().has_point(point):
			return true
	return false


func _sit_nearest() -> void:
	if _dale_nearer_than_computers():
		_set_talk(true, _nearest_talker().who)
		return
	var best: Computer
	for pc in _computers:
		if not pc.screen.is_visible_in_tree():
			continue
		if best == null or _player.global_position.distance_to(pc.screen.global_position) \
				< _player.global_position.distance_to(best.screen.global_position):
			best = pc
	_set_seat(best)


## Sit at a computer (the camera glides to frame its screen), or stand (null).
func _set_seat(pc: Computer) -> void:
	if pc == _seat:
		return
	if pc and _talking:
		_talking = false
		_talk_panel.visible = false
		_hush()
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
	_inset = SafeArea.get_insets(get_viewport().get_visible_rect().size)
	_apply_insets(true)


## Keeps the HUD clear of the notch, status bar and home bar.
func _apply_insets(force := false) -> void:
	var inset := SafeArea.get_insets(get_viewport().get_visible_rect().size)
	if inset == _inset and not force:
		return
	_inset = inset
	_place_button(_sit_button, Control.PRESET_BOTTOM_RIGHT)
	_place_button(_look_button, Control.PRESET_TOP_RIGHT)
	_place_stand_button()
	_place_talk_box()
	_hint.offset_top = -270 - _inset.w
	_hint.offset_bottom = -150 - _inset.w
	_hint.offset_left = 30 + _inset.x
	_hint.offset_right = -30 - _inset.z
	_title.offset_top = 90 + _inset.y
	# Sideways the toast fits between the corner buttons; upright it drops
	# below them and runs the full width, so longer news still reads.
	var wide := _hud.size.x > _hud.size.y
	_toast.offset_top = (24 if wide else 140) + _inset.y
	_toast.offset_left = 300 if wide else 30 + _inset.x
	_toast.offset_right = -300 if wide else -30 - _inset.z
	_todo.offset_top = 24 + _inset.y
	_todo.offset_left = 24 + _inset.x
	_todo.offset_right = 24 + _inset.x + 260


## Swap Pong's window (on its CRT) between tall and wide to match the phone.
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
	_pong_pc.size = _pong_wide_size() if wide else PONG_SCREEN
	_pong_pc.quad.size = _pong_pc.size
	# The CRT stays put; its desktop window goes tall or wide.
	_pong_frames[0].visible = not wide
	_pong_frames[1].visible = wide
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
	move = Vector2.ZERO if _seat or _talking else move.limit_length(1.0)
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
	_tick_steps(flat)


func _process(delta: float) -> void:
	_pad_chip = maxf(0.0, _pad_chip - delta)
	_pad_card = maxf(0.0, _pad_card - delta)
	if _pad_leave >= 0.0:
		if _seat == null:
			_pad_leave = -1.0
		else:
			_pad_leave += delta
			if _pad_leave >= PAD_LEAVE_HOLD:
				_pad_leave = -1.0
				_set_seat(null)
	if _seat == null and _pad_look.length() > PAD_DEAD:
		_look(_pad_look * PAD_LOOK * delta)
	_player.rotation.y = _yaw
	_head.rotation.x = _pitch
	# Lean in a bit while looking at the monitor up close.
	var aim = _aim_at(_aim_point())
	var close: bool = aim != null and aim.dist < REACH and _seat == null and not _talking
	_zoom = move_toward(_zoom, 1.0 if close else 0.0, delta * 2.5)
	var walk_fov := lerpf(70.0, 52.0, _zoom * _zoom * (3.0 - 2.0 * _zoom))
	# Glide between the walking view and the seated view.
	_glide = minf(1.0, _glide + delta / _glide_time)
	var target := _seat.seat_transform(_camera, Vector2(_world_vp.size), SEAT_FOV, SEAT_FILL) if _seat else _head.global_transform
	var target_fov := SEAT_FOV if _seat else walk_fov
	if _talking:
		target = _talk_view()
		target_fov = TALK_FOV
	if _glide < 1.0:
		var e := _glide * _glide * (3.0 - 2.0 * _glide)
		_camera.global_transform = _glide_from.interpolate_with(target, e)
		_camera.fov = lerpf(_glide_from_fov, target_fov, e)
	else:
		_camera.global_transform = target
		_camera.fov = target_fov
	_screen_camera.global_transform = _camera.global_transform
	_screen_camera.fov = _camera.fov
	# Several screens can share a bus (the ladder's machines): the nearest wins.
	var bus_vol := {}
	for pc in _computers:
		var dist := _camera.global_position.distance_to(pc.screen.global_position)
		pc.hi_mat.set_shader_parameter("fade", clampf((4.0 - dist) / 1.5, 0.0, 1.0))
		var vol := clampf((AUDIO_FAR - dist) / (AUDIO_FAR - AUDIO_NEAR), 0.0, 1.0)
		if not pc.screen.is_visible_in_tree():
			vol = 0.0
		bus_vol[pc.bus] = maxf(bus_vol.get(pc.bus, 0.0), vol)
	for bus in bus_vol:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(bus_vol[bus], 0.0001)))

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
	_tick_dale(delta)
	_ladder.tick(delta)
	_tick_room_sound(delta)
	_sit_button.visible = _touch and not _pad and _seat == null and not _talking
	_sit_button.text = "TALK" if _dale_nearer_than_computers() else "SIT DOWN"
	_stand_button.visible = not _pad and ((_touch and _seat != null) or _talking)
	_look_button.visible = not _pad and _seat == null and not _talking
	_todo.visible = _seat == null and not _talking
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
	_tick_goals()
	var news: Array = _link.pop_news()
	if not news.is_empty():
		_toast.text = "\n".join(news)
		_toast_time = 3.5


## Count the milestones Dale's story needs into the shared stats.
func _tick_goals() -> void:
	var relics = _link.get("relics")
	if relics == null:
		return
	if _pong_view and _pong_view.get_child_count() > 0:
		var pong := _pong_view.get_child(0)
		if "stage" in pong and "cheated" in pong:
			var n := _goals.pong(int(pong.get("stage")), bool(pong.get("cheated")))
			if n > 0:
				relics.bump("pong_bosses", n)
	if _cube_vp and _cube_vp.get_child_count() > 0:
		var cube := _cube_vp.get_child(0)
		if "solves" in cube and "last_level" in cube:
			if _goals.cube(int(cube.get("solves")), int(cube.get("last_level"))) > 0:
				relics.bump("cube_records")
	if _proof_view and _proof_view.get_child_count() > 0:
		var proof := _proof_view.get_child(0)
		if "_blind" in proof:
			var blind = proof.get("_blind")
			if blind is Object and blind.has_method("is_won"):
				if _goals.proof(blind, blind.is_won()) > 0:
					relics.bump("proof_wins")


func _update_hint(aim, close: bool) -> void:
	var text := ""
	if _talking:
		text = ""
	elif _pad:
		if _seat:
			text = ""
		elif close or _dale_aimed():
			text = ""
		elif not _moved and _pad_card <= 0.0:
			text = "WALK UP TO A COMPUTER"
	elif _touch:
		if not _moved:
			text = "TAP A COMPUTER\nTO SIT DOWN"
		elif _dale_alert.visible and _player.global_position.z < 4.0:
			text = "DALE WANTS A WORD"
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		text = "CLICK TO LOOK AROUND\nWASD WALK - MOUSE LOOK - ESC LETS GO"
	elif close:
		text = ""
	elif _dale_aimed():
		text = "CLICK TO TALK"
	elif aim != null:
		text = "GET CLOSER"
	elif not _moved:
		text = "WALK UP TO A COMPUTER"
	if not _talking and _seat == null and _ladder and _ladder.hint() != "":
		text = _ladder.hint()
	_hint.text = text


func _draw_hud() -> void:
	var size := _hud.size
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (_pad and _seat == null):
		var c := size * 0.5
		var aim = _aim_at(_aim_point())
		if (aim != null and aim.dist < REACH) or _dale_aimed():
			_hud.draw_arc(c, 9, 0, TAU, 16, Color(1, 1, 1, 0.9), 3)
		else:
			_hud.draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1, 0.85))
	if _pad:
		_draw_pad_hud(size)
	if _touches.values().has("move"):
		_hud.draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.35), 4)
		_hud.draw_circle(_stick_origin + _stick * STICK_RADIUS, 34, Color(1, 1, 1, 0.35))
	elif _touch and not _pad and _seat == null and not _talking:
		# Ghost stick so you can see where the walk thumb goes.
		var rest := _stick_rest()
		_hud.draw_arc(rest, STICK_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.18), 4)
		_hud.draw_circle(rest, 34, Color(1, 1, 1, 0.18))


## Controller prompts: the controls card, an [A] SIT DOWN / TALK prompt
## under the crosshair, and while seated the LEAVE chip (with a ring that
## fills while B is held).
func _draw_pad_hud(size: Vector2) -> void:
	var k := minf(size.x, size.y) / 720.0
	var font := ThemeDB.fallback_font
	var fs := int(22 * k)
	if _pad_card > 0.0 and _seat == null and not _talking:
		PadUI.draw_card(_hud, size, PAD_CARD, k, clampf(_pad_card, 0.0, 1.0), _inset.y)
	if _seat == null and not _talking:
		var aim = _aim_at(_aim_point())
		var what := ""
		if aim != null and aim.dist < PAD_SIT_RANGE:
			what = "SIT DOWN"
		elif _dale_aimed():
			what = "TALK"
		if what != "":
			var at := size * 0.5 + Vector2(-font.get_string_size(what, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, 70 * k)
			PadUI.draw_badge(_hud, at, "A", 17 * k)
			_hud.draw_string_outline(font, at + Vector2(28 * k, fs * 0.4), what, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(8 * k), Color.BLACK)
			_hud.draw_string(font, at + Vector2(28 * k, fs * 0.4), what, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if _seat == null:
		return
	var holding := _pad_leave >= 0.0
	var alpha := 1.0 if holding else clampf(_pad_chip, 0.0, 1.0)
	if alpha <= 0.0:
		return
	# [BACK] or hold [B]  LEAVE
	var x := _inset.x + 24 * k
	var y := _inset.y + 34 * k
	var box := Rect2(Vector2(x - 10 * k, y - 26 * k), Vector2(390 * k, 52 * k))
	_hud.draw_rect(box, Color(0.05, 0.04, 0.08, 0.8 * alpha))
	x += PadUI.draw_badge(_hud, Vector2(x + 34 * k, y), "BACK", 16 * k, alpha) * 0.5 + 44 * k
	var small := int(17 * k)
	_hud.draw_string(font, Vector2(x, y + small * 0.4), "or hold", HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(1, 1, 1, 0.8 * alpha))
	x += font.get_string_size("or hold", HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 28 * k
	var b_at := Vector2(x, y)
	PadUI.draw_badge(_hud, b_at, "B", 16 * k, alpha)
	if holding:
		var t := clampf(_pad_leave / PAD_LEAVE_HOLD, 0.0, 1.0)
		_hud.draw_arc(b_at, 22 * k, -PI / 2, -PI / 2 + TAU * t, 24, Color(1, 0.86, 0.25), 5 * k)
	_hud.draw_string(font, Vector2(x + 30 * k, y + fs * 0.4), "LEAVE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	_start_room_sound()
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_pad_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L \
			and _seat == null and not _talking:
		_set_look(1 - _look_i)
		return
	if event is InputEventKey and _talking and event.physical_keycode == KEY_SPACE and not event.echo \
			and is_instance_valid(_hold_button):
		# Keyboard: hold Space to talk to Dale.
		if event.pressed:
			_hold_talk()
		else:
			_release_talk()
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
		if _talking:
			_set_talk(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _mouse_button(event: InputEventMouseButton) -> void:
	if _talking:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		var aim = _aim_at(_aim_point())
		if _dale_aimed() and (aim == null or _dale_hit(_aim_point()) < aim.dist):
			_set_talk(true, _hit_who)
		elif aim != null and aim.dist < REACH:
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
	if not _pad_carded:
		_pad_carded = true
		_pad_card = 7.0
		_title.modulate.a = 0.0  # make room for the controls card
	if _talking:
		_pad_talk(event)
		return
	if event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_BACK, JOY_BUTTON_GUIDE]:
		if event.pressed and _seat:
			_set_seat(null)
		return
	if _seat:
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B:
			_pad_leave = 0.0 if event.pressed else -1.0
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
	if _dale_aimed():
		_set_talk(true, _hit_who)
		return
	var near := _nearest_talker()
	if _dale_nearer_than_computers() and near.dist < PAD_SIT_RANGE:
		_set_talk(true, near.who)
		return
	var aim = _aim_at(_aim_point())
	var pc: Computer = aim.pc if aim != null and aim.dist < PAD_SIT_RANGE else null
	if pc == null:
		for c in _computers:
			var d := _player.global_position.distance_to(c.screen.global_position)
			if c.screen.is_visible_in_tree() and d < PAD_SIT_RANGE and (pc == null or d < _player.global_position.distance_to(pc.screen.global_position)):
				pc = c
	if pc == null:
		_toast.text = "WALK UP TO A COMPUTER"
		_toast_time = 2.0
		return
	_set_seat(pc)
	_pad_chip = 6.0


## Chatting with a controller: up/down picks a reply, A says it (or NEXT),
## B or Back says bye.
func _pad_talk(event: InputEvent) -> void:
	var on_hold := is_instance_valid(_hold_button) and _talk_buttons.get_children().find(_hold_button) == _talk_pick
	if event is InputEventJoypadButton and is_instance_valid(_hold_button) \
			and (event.button_index == JOY_BUTTON_Y or (event.button_index == JOY_BUTTON_A and on_hold and _talk_last)):
		if event.pressed:
			_hold_talk()
		else:
			_release_talk()
		return
	if not (event is InputEventJoypadButton and event.pressed):
		return
	var buttons := _talk_buttons.get_children().filter(func(b): return not b.is_queued_for_deletion())
	match event.button_index:
		JOY_BUTTON_B, JOY_BUTTON_BACK:
			_set_talk(false)
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN:
			if buttons.size() > 1:
				_talk_pick = wrapi(_talk_pick + (1 if event.button_index == JOY_BUTTON_DPAD_DOWN else -1), 0, buttons.size())
				_show_pick()
		JOY_BUTTON_A:
			if _glide < 1.0:
				return
			if (_waiting_for_choice() or _talk_last) and _talk_pick < buttons.size():
				buttons[_talk_pick].pressed.emit()
			else:
				_advance()


## Light up the reply the controller is on.
func _show_pick() -> void:
	var i := 0
	for b in _talk_buttons.get_children():
		if b.is_queued_for_deletion():
			continue
		b.modulate = Color(1.0, 0.85, 0.3) if _pad and i == _talk_pick else Color.WHITE
		i += 1


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
	# Chatting with Dale: the talk box and BYE take the taps.
	if _talking:
		return
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
			elif _dale_hit(event.position) >= 0.0 and _glide >= 1.0 \
					and (aim == null or _dale_hit(event.position) < aim.dist):
				_set_talk(true, _hit_who)
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
		if not pc.screen.is_visible_in_tree():
			continue
		if best == null or t < best.dist:
			# Not through walls: screens in the other rooms stay out of reach.
			if _ladder and (pc.screen.global_position.z > 4.0 or _player.global_position.z > 4.0) \
					and _occluded(origin, origin + dir * t):
				continue
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
