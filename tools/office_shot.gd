extends SceneTree
## Renders the 3D office from a few spots and saves PNGs to $OUT (needs a display):
##   OUT=/some/dir LAYOUT=landscape xvfb-run -a -s "-screen 0 1280x720x24" \
##     godot --rendering-driver opengl3 --resolution 1280x720 -s res://tools/office_shot.gd

func _init() -> void:
	var office = load("res://scenes/office/office.tscn").instantiate()
	root.add_child(office)
	for i in 5: await process_frame
	var spots := [[Vector3(0.3, 0, 3.2), 0.0, -0.08], [Vector3(0.0, 0, -1.55), 0.0, -0.35], [Vector3(-1.5, 0, 1.5), -2.3, -0.1]]
	for n in spots.size():
		office._player.position = spots[n][0]
		office._yaw = spots[n][1]
		office._pitch = spots[n][2]
		for i in 90: await process_frame
		if n == 1:
			# Click "start" on the monitor via the same path a player uses.
			office.call("_send_button", Vector2(0.5, 0.81), true)
			await process_frame
			office.call("_send_button", Vector2(0.5, 0.81), false)
			for i in 240: await process_frame
		root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/office_%s_%d.png" % [OS.get_environment("LAYOUT"), n])
	quit()
