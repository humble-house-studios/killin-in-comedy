extends SceneTree
## Plays ~14s of a set with real rendering and saves screenshots to $OUT
## (needs a display):
##   OUT=/some/dir LAYOUT=portrait xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 --resolution 720x1280 -s res://tools/screenshot.gd

func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5: await process_frame
	main._new_run()
	main._start_set()  # past the goal screen
	var t := 0.0
	var wait := 0.0
	var shot := 0
	while t < 14.0:
		await process_frame
		t += 1.0 / 60.0
		wait -= 1.0 / 60.0
		if wait <= 0:
			var b: Battle = main._battle
			if Autopilot._should_land(b) and t > 9.0:
				main._on_end_turn()
				wait = 0.7
			else:
				var i := Autopilot._best_card(b)
				if i >= 0:
					main._on_card_pressed(i)
					wait = 0.7
		if (shot == 0 and t > 8.5) or (shot == 1 and main._battle.last_landed > 0 and t > 9.5):
			root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/shot_%s_%d.png" % [OS.get_environment("LAYOUT"), shot])
			shot += 1
	quit()
