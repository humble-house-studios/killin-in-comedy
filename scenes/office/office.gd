extends Node
## The meta office: walk up to a desk in a PS1-style office and play the real
## game on the computer monitor, first person.
## - The 3D world renders at a third of the screen size (chunky PS1 pixels).
## - The monitor runs res://scenes/main.tscn in its own SubViewport; a second
##   full-res pass draws only the screen, so cards stay readable up close.
## - Clicks/taps are ray-cast onto the screen and pushed into the game as mouse
##   events at that spot.
## Mouse: click to look around, WASD walk, click the monitor to play, Esc lets go.
## Touch: left thumb walks, right thumb looks, tap the monitor to play.

const EYE := 1.5
const SPEED := 2.4
const RUN_SPEED := 3.8
const LOOK_SENS := 0.0025
const TOUCH_LOOK_SENS := 0.006
## How far away you can still click the monitor (metres).
const REACH := 2.6
## Screen size in metres (16:9, matches the game viewport).
const SCREEN_W := 0.66
const SCREEN_H := 0.37125
const SCREEN_POS := Vector3(0.0, 1.17, -2.38)
const GAME_SIZE := Vector2i(1280, 720)
const PIXEL_SHRINK := 3
const LAYER_WORLD := 1
const LAYER_SCREEN := 2
const STICK_RADIUS := 90.0

var _ps1 := preload("res://scenes/office/ps1.gdshader")
var _monitor_shader := preload("res://scenes/office/monitor.gdshader")

var _world_box: SubViewportContainer
var _world_vp: SubViewport
var _screen_vp: SubViewport
var _game_vp: SubViewport
var _player: CharacterBody3D
var _head: Node3D
var _camera: Camera3D
var _screen_camera: Camera3D
var _screen: Node3D
var _screen_hi_mat: ShaderMaterial
var _clock_hands: Array[Node3D] = []
var _hud: Control
var _hint: Label
var _title: Label

var _yaw := 0.0
var _pitch := -0.08
var _bob := 0.0
var _zoom := 0.0
var _touch := false
## Touch index -> "move" / "look" / "screen".
var _touches := {}
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _stick := Vector2.ZERO
## Where the pointer sits on the game screen (game pixels), or null.
var _game_pointer = null
var _game_held := false
var _moved := false


func _ready() -> void:
	_touch = DisplayServer.is_touchscreen_available()
	_build_game()
	_build_views()
	_build_room()
	_build_player()
	_build_hud()
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()


# ---------------------------------------------------------------- setup

func _build_game() -> void:
	_game_vp = SubViewport.new()
	_game_vp.size = GAME_SIZE
	_game_vp.disable_3d = true
	_game_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_game_vp)
	_game_vp.add_child(preload("res://scenes/main.tscn").instantiate())


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


func _label(text: String, pos: Vector3, size: int, color: Color, rot := Vector3.ZERO, width := 0.0) -> Label3D:
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
	_world_vp.add_child(l)
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

	_screen = Node3D.new()
	_screen.position = SCREEN_POS
	_world_vp.add_child(_screen)
	var quad := QuadMesh.new()
	quad.size = Vector2(SCREEN_W, SCREEN_H)
	var lo := ShaderMaterial.new()
	lo.shader = _monitor_shader
	lo.set_shader_parameter("game", _game_vp.get_texture())
	var lo_mi := MeshInstance3D.new()
	lo_mi.mesh = quad
	lo_mi.material_override = lo
	lo_mi.layers = LAYER_WORLD
	_screen.add_child(lo_mi)
	_screen_hi_mat = lo.duplicate()
	_screen_hi_mat.set_shader_parameter("game", _game_vp.get_texture())
	var hi_mi := MeshInstance3D.new()
	hi_mi.mesh = quad
	hi_mi.material_override = _screen_hi_mat
	hi_mi.layers = LAYER_SCREEN
	hi_mi.position.z = 0.001
	_screen.add_child(hi_mi)

	# Keyboard, mouse, mug.
	_box(Vector3(0.46, 0.03, 0.16), Vector3(-0.05, 0.775, -2.3), _mat(Color(0.8, 0.77, 0.66), 7, Color(0.45, 0.43, 0.38)), false, Vector3(0.08, 0, 0))
	_box(Vector3(0.06, 0.025, 0.1), Vector3(0.32, 0.772, -2.3), beige)
	var mug := _mat(Color(0.75, 0.18, 0.2))
	_cyl(0.045, 0.1, Vector3(-0.6, 0.81, -2.4), mug)
	_cyl(0.038, 0.005, Vector3(-0.6, 0.861, -2.4), _mat(Color(0.2, 0.1, 0.05)))
	# Paper stack.
	_box(Vector3(0.22, 0.04, 0.3), Vector3(0.68, 0.78, -2.6), _mat(Color(0.92, 0.92, 0.88)), false, Vector3(0, 0.2, 0))


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
	clock.position = Vector3(3.48, 2.0, -0.6)
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
	_hint.offset_top = -150
	_hint.offset_bottom = -40
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
	var t := create_tween()
	t.tween_interval(3.5)
	t.tween_property(_title, "modulate:a", 0.0, 1.5)


func _on_resized() -> void:
	var s := get_window().size
	var landscape := s.x > s.y
	var base := Vector2i(1280, 720) if landscape else Vector2i(720, 1280)
	if get_window().content_scale_size != base:
		get_window().content_scale_size = base
	# Phones held upright keep a wide view instead of a narrow slit.
	for cam in [_camera, _screen_camera]:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT if landscape else Camera3D.KEEP_WIDTH


# ---------------------------------------------------------------- frame

func _physics_process(delta: float) -> void:
	var move := _stick
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		move.y += 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		move.y -= 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		move.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		move.x += 1
	move = move.limit_length(1.0)
	if move.length() > 0.1:
		_moved = true
	var speed := RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else SPEED
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
	_player.rotation.y = _yaw
	_head.rotation.x = _pitch
	# Lean in a bit while looking at the monitor up close.
	var aim = _aim_at(_aim_point())
	var close: bool = aim != null and aim.dist < REACH
	_zoom = move_toward(_zoom, 1.0 if close else 0.0, delta * 2.5)
	_camera.fov = lerpf(70.0, 52.0, _zoom * _zoom * (3.0 - 2.0 * _zoom))
	_screen_camera.global_transform = _camera.global_transform
	_screen_camera.fov = _camera.fov
	var dist := _camera.global_position.distance_to(SCREEN_POS)
	_screen_hi_mat.set_shader_parameter("fade", clampf((4.0 - dist) / 1.5, 0.0, 1.0))

	# Hover the game under the crosshair (mouse) so buttons light up.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _touches.has("screen"):
		if close:
			_send_motion(aim.uv)
		elif _game_pointer != null and not _game_held:
			_send_motion(Vector2(-1, -1))
			_game_pointer = null

	var time := Time.get_time_dict_from_system()
	if _clock_hands.size() == 2:
		_clock_hands[0].rotation.z = -TAU * (fmod(time.hour, 12) + time.minute / 60.0) / 12.0
		_clock_hands[1].rotation.z = -TAU * time.minute / 60.0

	_update_hint(aim, close)
	_hud.queue_redraw()


func _update_hint(aim, close: bool) -> void:
	var text := ""
	if _touch:
		if not _moved:
			text = "LEFT THUMB: WALK\nRIGHT THUMB: LOOK\nTAP THE MONITOR TO PLAY"
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		text = "CLICK TO LOOK AROUND\nWASD WALK - MOUSE LOOK - ESC LETS GO"
	elif close:
		text = ""
	elif aim != null:
		text = "GET CLOSER"
	elif not _moved:
		text = "WALK UP TO THE COMPUTER"
	_hint.text = text


func _draw_hud() -> void:
	var size := _hud.size
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var c := size * 0.5
		var aim = _aim_at(_aim_point())
		if aim != null and aim.dist < REACH:
			_hud.draw_arc(c, 9, 0, TAU, 16, Color(1, 1, 1, 0.9), 3)
		else:
			_hud.draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1, 0.85))
	if _touches.values().has("move"):
		_hud.draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.35), 4)
		_hud.draw_circle(_stick_origin + _stick * STICK_RADIUS, 34, Color(1, 1, 1, 0.35))


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	# Touch and mouse each emulate the other; only handle the real one.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_touch = true
		_touch_input(event)
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton:
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
			_send_button(aim.uv, true)
	elif _game_held:
		var aim = _aim_at(_aim_point())
		_send_button(aim.uv if aim != null else _last_uv(), false)


func _touch_input(event: InputEvent) -> void:
	var i: int = event.index
	if event is InputEventScreenTouch:
		if event.pressed:
			var aim = _aim_at(event.position)
			if aim != null and aim.dist < REACH and not _touches.values().has("screen"):
				_touches[i] = "screen"
				_send_button(aim.uv, true)
			elif event.position.x < _hud.size.x * 0.45 and not _touches.values().has("move"):
				_touches[i] = "move"
				_stick_origin = event.position
				_stick = Vector2.ZERO
			else:
				_touches[i] = "look"
		else:
			var kind = _touches.get(i)
			_touches.erase(i)
			if kind == "screen":
				var aim = _aim_at(event.position)
				_send_button(aim.uv if aim != null else _last_uv(), false)
			elif kind == "move":
				_stick = Vector2.ZERO
		return
	match _touches.get(i):
		"screen":
			var aim = _aim_at(event.position)
			if aim != null:
				_send_motion(aim.uv)
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


## Ray from a HUD point onto the monitor. Returns {uv, dist} or null.
func _aim_at(point: Vector2):
	if _hud == null or _hud.size.x <= 0:
		return null
	var px := point / _hud.size * Vector2(_world_vp.size)
	var origin := _camera.project_ray_origin(px)
	var dir := _camera.project_ray_normal(px)
	var inv := _screen.global_transform.affine_inverse()
	var lo := inv * origin
	var ld := inv.basis * dir
	if ld.z >= -0.0001 or lo.z <= 0:
		return null
	var t := -lo.z / ld.z
	var hit := lo + ld * t
	var uv := Vector2(hit.x / SCREEN_W + 0.5, 0.5 - hit.y / SCREEN_H)
	if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1:
		return null
	return {"uv": uv, "dist": t}


func _last_uv() -> Vector2:
	return _game_pointer / Vector2(GAME_SIZE) if _game_pointer != null else Vector2(-1, -1)


func _send_motion(uv: Vector2) -> void:
	var pos := uv * Vector2(GAME_SIZE)
	if _game_pointer != null and pos.is_equal_approx(_game_pointer):
		return
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = pos - (_game_pointer if _game_pointer != null else pos)
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if _game_held else 0
	_game_pointer = pos
	_game_vp.push_input(ev, true)


func _send_button(uv: Vector2, pressed: bool) -> void:
	_send_motion(uv)
	var pos := uv * Vector2(GAME_SIZE)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_game_held = pressed
	_game_vp.push_input(ev, true)
