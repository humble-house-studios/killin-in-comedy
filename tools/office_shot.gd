extends SceneTree
## Renders the 3D office and saves PNGs to $OUT (needs a display):
##   OUT=/some/dir LAYOUT=landscape xvfb-run -a -s "-screen 0 1280x720x24" \
##     godot --rendering-driver opengl3 --resolution 1280x720 -s res://tools/office_shot.gd
## Shots: 0 = by the door, 1 = after tapping the monitor (seated) and tapping
## "Start your set", 2 = after STAND UP, looking around.

var office


func _init() -> void:
	office = load("res://scenes/office/office.tscn").instantiate()
	root.add_child(office)
	for i in 5: await process_frame
	office._touch = true
	await _frames(90)
	_shot(0)
	# Tap the far-away monitor: should glide over and sit down.
	_tap(_screen_point(Vector2(0.5, 0.5)))
	await _frames(120)
	# Tap "Start your set" on the game, through the same touch path.
	_tap(_screen_point(Vector2(0.5, 0.81)))
	await _frames(240)
	_shot(1)
	office._set_seated(false)
	await _frames(60)
	office._yaw = -2.3
	await _frames(30)
	_shot(2)
	quit()


func _frames(n: int) -> void:
	for i in n: await process_frame


## Where a point on the game screen (uv) appears on the HUD.
func _screen_point(uv: Vector2) -> Vector2:
	var local := Vector3((uv.x - 0.5) * office.SCREEN_W, (0.5 - uv.y) * office.SCREEN_H, 0)
	var px: Vector2 = office._camera.unproject_position(office._screen.global_transform * local)
	return px / Vector2(office._world_vp.size) * office._hud.size


func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.position = pos
		ev.pressed = pressed
		office._touch_input(ev)


func _shot(n: int) -> void:
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/office_%s_%d.png" % [OS.get_environment("LAYOUT"), n])
