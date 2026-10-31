extends SceneTree
## Renders the 3D office and saves PNGs to $OUT (needs a display):
##   OUT=/some/dir LAYOUT=landscape xvfb-run -a -s "-screen 0 1280x720x24" \
##     godot --rendering-driver opengl3 --resolution 1280x720 -s res://tools/office_shot.gd
## Shots: 0 = by the door, 1 = after tapping the main monitor (seated) and
## tapping "Start your set", 2 = standing, facing the Pong desk, 3 = seated at
## Pong after tapping PLAY, 4 = after a right-edge thumb drag,
## 5 = facing the Proof Hand desk, 6 = seated there after tapping two cards. Run tools/fetch_games.sh --autoloads first so
## the other games are there (then `git checkout project.godot`).

var office


func _init() -> void:
	# Let autoloads (Proof Hand's Game/Save) finish _ready first, as in a real launch.
	for i in 3: await process_frame
	office = load("res://scenes/office/office.tscn").instantiate()
	root.add_child(office)
	for i in 5: await process_frame
	office._touch = true
	await _frames(90)
	_shot(0)
	# Tap the far-away monitor: should glide over and sit down.
	var main_pc = office._computers[0]
	_tap(_screen_point(main_pc, Vector2(0.5, 0.5)))
	await _frames(120)
	# Tap "Start your set" on the game, through the same touch path.
	_tap(_screen_point(main_pc, Vector2(0.5, 0.81)))
	await _frames(240)
	_shot(1)
	office._set_seat(null)
	await _frames(60)
	office._player.position = Vector3(0.5, 0, 2.0)
	office._yaw = PI / 2
	office._pitch = -0.15
	await _frames(60)
	_shot(2)
	if office._computers.size() > 1:
		var pong = office._computers[1]
		_tap(_screen_point(pong, Vector2(0.5, 0.5)))
		await _frames(120)
		# Tap PLAY on Pong's title screen.
		_tap(_screen_point(pong, Vector2(0.5, 0.58)))
		await _frames(150)
		_shot(3)
		# Right thumb at the very edge of the phone, sliding down: the paddle
		# should follow even though the thumb is off the monitor.
		var x: float = office._hud.size.x - 20
		var h: float = office._hud.size.y
		_touch(Vector2(x, h * 0.2), true)
		for k in 20:
			_drag(Vector2(x, h * (0.2 + k * 0.03)))
			await _frames(2)
		await _frames(10)
		_shot(4)
		_touch(Vector2(x, h * 0.8), false)
	if office._computers.size() > 2:
		office._set_seat(null)
		await _frames(40)
		office._player.position = Vector3(1.4, 0, -0.9)
		office._yaw = -PI / 2
		office._pitch = -0.1
		await _frames(60)
		_shot(5)
		var proof = office._computers[2]
		_tap(_screen_point(proof, Vector2(0.5, 0.5)))
		await _frames(120)
		_tap(_screen_point(proof, Vector2(0.14, 0.64)))
		await _frames(10)
		_tap(_screen_point(proof, Vector2(0.38, 0.64)))
		await _frames(30)
		_shot(6)
	quit()


func _frames(n: int) -> void:
	for i in n: await process_frame


## Where a point on the game screen (uv) appears on the HUD.
func _screen_point(pc, uv: Vector2) -> Vector2:
	var local := Vector3((uv.x - 0.5) * pc.size.x, (0.5 - uv.y) * pc.size.y, 0)
	var px: Vector2 = office._camera.unproject_position(pc.screen.global_transform * local)
	return px / Vector2(office._world_vp.size) * office._hud.size


func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.position = pos
		ev.pressed = pressed
		office._touch_input(ev)


func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 1
	ev.position = pos
	ev.pressed = pressed
	office._touch_input(ev)


func _drag(pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 1
	ev.position = pos
	office._touch_input(ev)


func _shot(n: int) -> void:
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/office_%s_%d.png" % [OS.get_environment("LAYOUT"), n])
