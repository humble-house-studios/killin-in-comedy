extends SceneTree
## Checks the office jazz crossfade, headless (PASS/FAIL):
##   godot --headless -s res://tools/music_check.gd
## Title tune on the title screen, the loop after clocking in, the loop fading
## out when a desk game's music starts up close, and back in when you walk away.

var office: Node
var fails := 0


func _initialize() -> void:
	office = load("res://scenes/office/office.tscn").instantiate()
	root.add_child(office)
	_run.call_deferred()


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < end:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _db(p: AudioStreamPlayer) -> float:
	return p.volume_db if p.playing else -80.0


func _run() -> void:
	await _wait(0.5)
	var m: Node = office._hub_music
	m.start()
	var title: Node = office._busy.title_screen
	if not title.visible and office._busy.enabled:
		title.open()
	await _wait(2.0)
	if office._busy.enabled:
		_check(_db(m._title) > -20.0 and _db(m._loop) < -60.0, "title tune on the title screen (%.1f / %.1f dB)" % [_db(m._title), _db(m._loop)])
		title._clock_in()
	await _wait(2.0)
	_check(_db(m._loop) > -20.0, "office loop after clocking in (%.1f dB)" % _db(m._loop))
	_check(not m._title.playing, "title tune stopped")

	# Stand at the comedy desk with its music playing.
	var pc = null
	for c in office._computers:
		if c.bus == AudioServer.get_bus_index("Comedy"):
			pc = c
	var twin := AudioServer.get_bus_index("Comedy Music")
	var players: Array = office._game_music.get(twin, [])
	_check(pc != null and not players.is_empty(), "comedy music found (%d player)" % players.size())
	if pc == null or players.is_empty():
		_finish()
		return
	var spot: Vector3 = pc.screen.global_position
	office._player.global_position = Vector3(spot.x, office._player.global_position.y, spot.z) + pc.screen.global_transform.basis.z * 1.2
	await _wait(1.0)
	_check(_db(m._loop) > -20.0, "jazz still on near a game that isn't playing music (%.1f dB)" % _db(m._loop))
	players[0].play()
	await _wait(0.4)
	var mid := _db(m._loop)
	await _wait(2.5)
	_check(m.game_mix > 0.9, "game music faded in (mix %.2f)" % m.game_mix)
	_check(_db(m._loop) < -40.0 and mid > _db(m._loop), "jazz faded out under it (%.1f then %.1f dB)" % [mid, _db(m._loop)])
	# Walk away with the game's music still going.
	office._player.global_position = spot + pc.screen.global_transform.basis.z * 12.0
	office._player.global_position.y = 0.0
	await _wait(2.5)
	_check(m.game_mix < 0.05, "game music faded with distance (mix %.2f)" % m.game_mix)
	_check(_db(m._loop) > -20.0, "jazz back when you walk away (%.1f dB)" % _db(m._loop))
	_finish()


func _finish() -> void:
	print("music_check: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails else 0)
