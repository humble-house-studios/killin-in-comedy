extends SceneTree
## The office's pause menu: renders it (main page, controls card, the New
## Game question) and checks that NEW GAME starts over at Dale's first
## chapter with the goal marker on him, keeping the settings. Saves PNGs to
## $OUT and prints PASS / FAIL lines (needs a display):
##   OUT=/some/dir LAYOUT=portrait xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 --resolution 720x1280 -s res://tools/menu_shot.gd
## It starts from a save with Dale's story done and wipes every progress save
## (user://dale.cfg, ladder.cfg, coworkers.cfg, office_relics.cfg, ...).

var office
var fails := 0


func _init() -> void:
	var d := DaleStory.new()
	for ch in DaleLines.CHAPTERS:
		d.finish(ch.id, {})
	var l := LadderState.new()
	l.collect_paycheck({})
	l.save()
	Sound.write_settings("office", {"music": 0.5})
	for i in 3: await process_frame
	office = load("res://scenes/office/office.tscn").instantiate()
	root.add_child(office)
	# Look Busy off: no morning card or boss in the way of the script.
	office._busy.set_enabled(false)
	for i in 5: await process_frame
	office._touch = true
	await _frames(40)
	check(office._goal_hop != "dale", "progress save: marker isn't on Dale (%s)" % office._goal_hop)
	office._open_menu(false)
	await _frames(5)
	check(paused, "the world pauses under the menu")
	check(not office._marker.visible, "marker hides while paused")
	_shot("menu")
	var music: Label = office._menu._labels.music
	check(music.text.contains("50%"), "music volume read from settings.cfg (%s)" % music.text.replace("\n", " "))
	_press("+", 0)
	check(absf(float(Sound.read_setting("office", "music", 0)) - 0.6) < 0.01, "MUSIC + saves 60%")
	var bus := AudioServer.get_bus_index("Music")
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(bus)) - 0.6) < 0.01, "and applies it live")
	_press("CONTROLS")
	await _frames(5)
	_shot("controls")
	_press("BACK")
	_press("NEW GAME")
	await _frames(5)
	_shot("confirm")
	_press("NO")
	check(office._menu._page == "main", "NO goes back")
	_press("NEW GAME")
	_press("YES, WIPE")
	await _frames(30)
	var fresh = null
	for n in root.get_children():
		if n != office and n.has_method("new_game"):
			fresh = n
	check(fresh != null, "the office reloaded")
	if fresh:
		office = fresh
		await _frames(30)
		check(not paused, "not paused after New Game")
		check(office._dale_story.next_chapter().get("id", "") == "pong", "Dale's story is back at chapter 1")
		check(office._goal_hop == "dale", "marker on Dale (%s)" % office._goal_hop)
		check(not office._ladder.state.paid, "ladder progress gone")
		check(FileAccess.file_exists("user://settings.cfg") and absf(float(Sound.read_setting("office", "music", 0)) - 0.6) < 0.01, "settings kept")
		_shot("new_game")
	print("\n%s: %d failure(s)" % ["ALL GOOD" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)


func _press(text: String, nth := -1) -> void:
	var found: Array = []
	_find(office._menu, text, found)
	if found.is_empty():
		check(false, "button %s" % text)
		return
	var b: Button = found[nth if nth >= 0 else 0]
	if not b.is_visible_in_tree():
		check(false, "button %s is showing" % text)
		return
	b.pressed.emit()


func _find(n: Node, text: String, out: Array) -> void:
	if n is Button and n.text == text and n.is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_find(c, text, out)


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n: await process_frame


func _shot(name: String) -> void:
	var dir := OS.get_environment("OUT")
	if dir != "":
		root.get_texture().get_image().save_png(dir + "/menu_%s_%s.png" % [OS.get_environment("LAYOUT"), name])
