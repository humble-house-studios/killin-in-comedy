extends SceneTree
## Screenshots of Look Busy (docs/look-busy.md) in the office, saved as PNGs
## to $OUT (needs a display):
##   OUT=/some/dir LAYOUT=portrait xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 --resolution 720x1280 -s res://tools/busy_shot.gd
## Shots: morning = the morning card, boss = the boss walking the floor with
## the clock HUD, seated = sitting at your desk with the boss behind you (the
## reflection), sheet = alt-tabbed to the spreadsheet, caught = the warning,
## kit_desk / kit / trailer = the DEV KIT desk, seated at it, its trailer.
## Wipes user://look_busy.cfg.

var office
var busy


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://look_busy.cfg"))
	Engine.max_fps = 60
	for i in 3: await process_frame
	office = load("res://scenes/office/office.tscn").instantiate()
	root.add_child(office)
	busy = office._busy
	busy.set_enabled(true)
	office._touch = true
	await _frames(30)
	_shot("morning")
	_press()
	await _frames(10)
	office._player.global_position = Vector3(-1.0, 0, -1.6)
	office._yaw = PI * 0.82
	office._pitch = -0.05
	busy.dev_boss_now()
	await _frames(200)
	_shot("boss")
	office._set_seat(office._computers[0])
	busy.wd.suspicion = 0.0
	await _frames(200)
	_shot("seated")
	busy.alt_tab()
	await _frames(40)
	_shot("sheet")
	busy.alt_tab()
	busy.wd.suspicion = 99.0
	await _frames(60)
	_shot("caught")
	_press()
	office._set_seat(null)
	busy._end_visit()
	busy.wd.suspicion = 0.0
	busy.dev_all_pieces()
	busy.gm.build = {"genre": "COMEDY", "mechanic": "SLOT REELS", "art": "CASINO NEON", "sound": "DING DING", "character": "KEV"}
	office._player.global_position = Vector3(1.0, 0, 2.6)
	office._yaw = -PI / 2
	office._pitch = -0.12
	await _frames(60)
	_shot("kit_desk")
	office._set_seat(busy._kit_pc)
	await _frames(90)
	_shot("kit")
	busy._kit.play_trailer()
	await _frames(40)
	_shot("trailer")
	quit()


func _press() -> void:
	for b in busy.notice._buttons.get_children():
		if b is Button and not b.is_queued_for_deletion():
			b.pressed.emit()
			return


func _frames(n: int) -> void:
	for i in n: await process_frame


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/busy_%s_%s.png" % [OS.get_environment("LAYOUT"), name])
