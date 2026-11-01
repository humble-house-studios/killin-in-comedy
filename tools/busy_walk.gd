extends SceneTree
## Debug walkthrough of Look Busy (docs/look-busy.md), headless or under xvfb.
## Fresh saves, Look Busy on, then:
##  - the morning card, the clock running, the boss coming in through the
##    door, walking the route and leaving;
##  - sitting at your desk while the boss watches: suspicion climbs to a
##    warning; alt-tab covers the screen with the spreadsheet and cools it;
##  - an empty desk while you're out; strikes up to fired and starting over;
##  - 5 PM and the end of the week.
## Prints PASS / FAIL lines and a summary. Wipes the office saves.
##   godot --headless -s res://tools/busy_walk.gd

var office
var busy
var fails := 0


func _init() -> void:
	for f in ["user://dale.cfg", "user://ladder.cfg", "user://coworkers.cfg", "user://look_busy.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	# Real-time pace, so the clock and the boss move like they do in the game.
	Engine.max_fps = 60
	for i in 3: await process_frame
	office = load("res://scenes/office/office.tscn").instantiate()
	root.add_child(office)
	busy = office._busy
	busy.set_enabled(true)
	office._touch = true
	await frames(10)
	check(busy.notice.visible and paused, "morning card shows and pauses")
	press_first()
	await frames(5)
	check(not paused, "CLOCK IN resumes")
	var m0: float = busy.wd.minutes
	await frames(60)
	check(busy.wd.minutes > m0, "the clock runs (%s)" % busy.wd.clock_text())

	# The boss comes by: through the door, along the route.
	busy.dev_boss_now()
	await frames(5)
	check(busy._boss_node != null and busy._boss_node.visible, "the boss walks in")
	await frames(240)
	var bz: float = busy._boss_node.position.z
	check(bz < 3.5, "the boss is inside the office (z %.1f)" % bz)
	# Sit at your desk, facing the screen, with the boss behind: suspicion climbs.
	var main_pc = office._computers[0]
	office._set_seat(main_pc)
	busy.wd.suspicion = 0.0
	var watched := false
	for i in 400:
		await process_frame
		if busy._seen:
			watched = true
		if busy.notice.visible:
			break
	check(watched, "the boss sees you playing at your desk")
	check(busy.notice.visible and busy.wd.strikes == 1, "caught: a verbal warning (strikes %d)" % busy.wd.strikes)
	press_first()
	await frames(5)
	# Alt-tab: the spreadsheet covers the game and takes the taps.
	busy.alt_tab()
	await frames(5)
	check(busy.is_covered() and main_pc.cover != null, "alt-tab covers the screen")
	var cells_before: int = busy.wd.cells
	var sheet = busy._sheet
	var todo: int = sheet._todo[0]
	sheet._cells[todo].pressed.emit()
	check(busy.wd.cells == cells_before + 1, "a spreadsheet cell counts")
	busy.wd.suspicion = 50.0
	await frames(60)
	check(busy.wd.suspicion < 50.0, "working cools suspicion (%.0f)" % busy.wd.suspicion)
	office._set_seat(null)
	await frames(5)
	check(not busy.is_covered() and main_pc.cover == null, "standing up uncovers the screen")
	# Let the visit finish.
	for i in 3000:
		await process_frame
		if busy._visit_t < 0.0:
			break
		if busy.notice.visible:
			press_first()
	check(busy._visit_t < 0.0 and not busy._boss_node.visible, "the boss leaves")

	# Empty desk: out of the office when the boss checks.
	busy.wd.suspicion = 0.0
	busy.wd.strikes = 1
	busy._empty_desk()
	check(busy.wd.suspicion >= Workday.EMPTY_DESK - 0.1, "empty desk adds suspicion")

	# Fired: strikes run out, the run starts over.
	busy.wd.tick(Workday.GRACE + 1.0)
	busy.wd.add(200.0)
	busy.wd.tick(Workday.GRACE + 1.0)
	var level: String = busy.wd.add(200.0)
	check(level == "fired" and busy.wd.fired, "third strike fires you")
	busy._caught(level)
	await frames(2)
	check(busy.notice.visible, "fired notice shows")
	press_first()
	await frames(5)
	check(not busy.wd.fired and busy.wd.floor_i == 1 and busy.wd.day == 0, "start over: floor 1, Monday")
	await frames(5)
	check(busy.notice.visible, "a new morning card")
	press_first()
	await frames(5)

	# 5 PM, then the next day; Friday ends the week.
	busy.dev_skip_to(Workday.DAY_MINUTES - 1.0)
	await frames(90)
	check(busy.notice.visible and busy.notice._head.text.begins_with("5:00"), "5 PM: clock out")
	press_first()
	await frames(5)
	check(busy.wd.day == 1 and busy.wd.minutes <= 1.0, "the next morning (%s)" % busy.wd.clock_text())
	press_first()
	await frames(5)
	busy.dev_friday()
	busy.wd.minutes = Workday.DAY_MINUTES - 1.0
	await frames(90)
	check(busy.notice.visible and busy.notice._head.text.begins_with("FRIDAY"), "Friday 5 PM ends the week")
	press_first()
	await frames(5)
	check(busy.wd.week == 2 and busy.wd.day == 0, "week 2, Monday")
	press_first()
	await frames(5)

	# Off: no clock, no boss, the office as before.
	busy.set_enabled(false)
	var m1: float = busy.wd.minutes
	await frames(60)
	check(busy.wd.minutes == m1 and not busy._hud.visible, "off: the clock stops and the HUD hides")

	print("\n%s: %d failed" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit(1 if fails else 0)


func press_first() -> void:
	for b in busy.notice._buttons.get_children():
		if b is Button and not b.is_queued_for_deletion():
			b.pressed.emit()
			return


func frames(n: int) -> void:
	for i in n:
		await process_frame


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("PASS  " if ok else "FAIL  ") + what)
