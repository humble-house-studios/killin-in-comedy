extends SceneTree
## Debug walkthrough of the ladder, headless or under xvfb. Starts fresh
## saves with Dale's story done, then:
##  - walks (real physics) from the office through every door to the stage,
##    unlocking each door the way the game does;
##  - checks that every screen can be tapped from in front of it and that
##    every coworker can be tapped to talk;
##  - runs a talk to the end with each coworker, a gift and a callback;
##  - checks locked doors block you and the to-do follows along.
## Prints PASS / FAIL lines and a summary. Wipes user://dale.cfg,
## ladder.cfg and coworkers.cfg.
##   godot --headless -s res://tools/ladder_walk.gd

var office
var ladder
var fails := 0


func _init() -> void:
	for f in ["user://dale.cfg", "user://ladder.cfg", "user://coworkers.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var d := DaleStory.new()
	for ch in DaleLines.CHAPTERS:
		d.finish(ch.id, {})
	for i in 3: await process_frame
	office = load("res://scenes/office/office.tscn").instantiate()
	root.add_child(office)
	# Look Busy off: no morning card or boss in the way of the script.
	office._busy.set_enabled(false)
	for i in 10: await process_frame
	office._touch = true
	ladder = office._ladder
	check(ladder.objective().contains("DOOR"), "to-do points at the door first")

	# Office -> arcade, through the office door.
	await walk(Vector3(1.8, 0, 2.6), 4.9)
	check(ladder.room() == "arcade", "walked into the arcade")
	check(ladder.state.paid and ladder.state.tokens > 0, "payday on entering (%d tokens)" % ladder.state.tokens)
	check(ladder.objective().contains("TICKETS"), "to-do: win tickets")

	# Locked trading door blocks you.
	await walk(Vector3(0, 0, 10.6), 12.6, 2.0)
	check(ladder.room() == "arcade", "locked door to the trading floor blocks you")
	check(ladder.hint().contains("DOOR KEY"), "locked door says what opens it")

	# Every arcade screen is tappable from in front of it.
	for id in ["claw", "ragdoll", "pusher", "counter"]:
		await tap_screen(id)
	# Every coworker present can be tapped.
	for id in ["gloria", "kev", "bernie", "theo"]:
		await tap_person(id)
	check(not ladder.people().any(func(p): return p.id == "ray"), "Ray isn't out yet")

	# Talk to Gloria the right way three times (each play reopens nothing needed).
	for i in 3:
		await talk_through("gloria", "ask")
	check(ladder.crew.tier("gloria") == 3, "Gloria reached tier 3")
	check(ladder.state.has("gloria_eye"), "Gloria's Eye perk applied")
	# Hated stance closes Kev off; a machine play reopens him.
	await talk_through("kev", "push")
	check(ladder.crew.is_closed("kev", ladder.state.plays), "Kev closed off after a PUSH")
	ladder.spend_token()
	check(not ladder.crew.is_closed("kev", ladder.state.plays), "a machine play reopens Kev")
	# Callback: Gloria's secret, brought to Kev.
	await talk_through("kev", "callback")
	check(ladder.crew.used_callbacks.has("credits_ceo"), "callback used with Kev")
	# Gift: buy the stress ball and give it to Bernie.
	ladder.state.win_tickets(40)
	check(ladder.buy("stress_ball"), "bought the stress ball")
	await talk_through("bernie", "gift")
	check(not ladder.state.has("stress_ball") and ladder.crew.tier("bernie") >= 1, "gift given to Bernie")

	# Beat two machines: Ray comes out.
	ladder.win_tickets(0, "claw", true)
	ladder.win_tickets(0, "pusher", true)
	await frames(40)
	await tap_person("ray")
	for i in 3:
		await talk_through("ray", "yes_and")
	check(ladder.state.has("archive_key"), "Ray gave the archive key")
	await frames(40)
	await walk(Vector3(-2.6, 0, 7.4), -5.0, 3.0, Vector2(-1, 0))
	check(ladder.room() == "archive", "walked into the archive")
	check(ladder.state.is_done("archive"), "archive counted")
	await tap_screen("archive")

	# Buy the key, walk to the trading floor.
	ladder.state.win_tickets(400)
	check(ladder.buy("door_key"), "bought the door key")
	await frames(70)
	await walk(Vector3(0, 0, 10.6), 13.2)
	check(ladder.room() == "trading", "walked into the trading floor")
	check(ladder.state.market_cash > 0, "tickets cashed out ($%d)" % ladder.state.market_cash)
	await tap_screen("trading")
	# Win the market the honest way: open it and trade the rumors.
	var term = ladder._machines.trading.node
	office._set_seat(ladder._machines.trading.pc)
	await frames(30)
	term._open()
	term.market.cash = term.market.target  # skip the playing; the rules are tested elsewhere
	# Headless frames can be tiny; step the terminal by a full market tick.
	term._process(Market.TICK + 0.01)
	await frames(10)
	check(ladder.state.is_done("market"), "market win opens the boardroom")
	office._set_seat(null)
	await frames(80)
	await walk(Vector3(0, 0, 18.8), 21.2)
	check(ladder.room() == "boardroom", "walked into the boardroom")
	await tap_screen("pitch")
	ladder.pitch_won()
	await frames(80)
	await walk(Vector3(2.5, 0, 24.8), 27.4)
	check(ladder.room() == "corner", "walked into the corner office")
	await tap_screen("putt")
	await tap_person("memo")
	await talk_through("memo", "")
	check(ladder.state.is_done("memo"), "memo read opens the stage")
	await frames(80)
	await walk(Vector3(2.5, 0, 30.8), 33.4)
	check(ladder.room() == "stage", "walked onto the stage floor")
	# Up the ramp and onto the stage.
	await walk(Vector3(0, 0, 36.2), 39.0)
	check(office._player.global_position.y > 0.15, "climbed the ramp onto the stage (y %.2f)" % office._player.global_position.y)
	await tap_screen("stage")
	ladder.stage_won()
	check(ladder.objective().contains("SECRETS"), "after the set: find the rest (%s)" % ladder.objective())
	print("\n%s: %d failure(s)" % ["ALL GOOD" if fails == 0 else "PROBLEMS", fails])
	quit()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n: await process_frame


## Stand at `from` and walk along +z (or `dir`) until past `until` (z, or x
## when walking sideways) or out of time.
func walk(from: Vector3, until: float, seconds := 8.0, dir := Vector2(0, 1)) -> void:
	office._set_seat(null)
	if office._talking:
		office._set_talk(false)
	office._player.global_position = from
	office._player.velocity = Vector3.ZERO
	office._yaw = PI if dir.y > 0 else (PI / 2 if dir.x < 0 else -PI / 2)
	office._pitch = 0.0
	office._stick = Vector2(0, 1)
	var t := 0.0
	while t < seconds:
		await physics_frame
		t += 1.0 / 60.0
		var p: Vector3 = office._player.global_position
		var past: bool = (p.z >= until) if dir.y > 0 else ((p.x <= until) if dir.x < 0 else p.x >= until)
		if past:
			break
	office._stick = Vector2.ZERO
	await frames(5)


func tap_screen(id: String) -> void:
	var pc = ladder._machines[id].pc
	var xf: Transform3D = pc.screen.global_transform
	var fwd := Vector3(xf.basis.z.x, 0, xf.basis.z.z).normalized()
	office._set_seat(null)
	await frames(30)
	office._player.global_position = Vector3(xf.origin.x, 0, xf.origin.z) + fwd * 1.3
	office._yaw = atan2(fwd.x, fwd.z)
	office._pitch = -0.2
	await frames(20)
	var px: Vector2 = office._camera.unproject_position(xf.origin)
	var hud: Vector2 = px / Vector2(office._world_vp.size) * office._hud.size
	var aim = office._aim_at(hud)
	check(aim != null and aim.pc == pc, "can tap the %s screen" % id)
	var hit: float = office._dale_hit(hud)
	check(aim != null and (hit < 0.0 or hit > aim.dist), "a coworker doesn't catch the tap on the %s" % id)
	check(not office._dale_nearer_than_computers(), "the button says SIT DOWN (not TALK) at the %s" % id)
	office._set_seat(pc)
	await frames(50)
	check(office._seat == pc and ladder._machines[id].active, "%s runs while seated" % id)
	office._set_seat(null)
	await frames(30)


func _who(id: String):
	for p in ladder.people():
		if p.id == id:
			return p
	return null


func tap_person(id: String) -> void:
	await frames(5)
	var who = _who(id)
	if who == null:
		check(false, "%s is around to talk to" % id)
		return
	var node: Node3D = who.node
	var fwd := Vector3(node.global_transform.basis.z.x, 0, node.global_transform.basis.z.z).normalized()
	office._player.global_position = Vector3(node.global_position.x, 0, node.global_position.z) + fwd * 1.6
	office._yaw = atan2(fwd.x, fwd.z)
	office._pitch = -0.15
	await frames(20)
	var c: Vector3 = node.global_transform * who.c
	var hud: Vector2 = office._camera.unproject_position(c) / Vector2(office._world_vp.size) * office._hud.size
	var t: float = office._dale_hit(hud)
	check(t >= 0.0 and office._hit_who.get("id", "") == id, "can tap %s to talk" % id)


## Talk to someone and pick the reply of this kind (a stance, "gift",
## "callback"), reading every line to the end.
func talk_through(id: String, pick: String) -> void:
	var who = _who(id)
	if who == null:
		check(false, "%s is around to talk to" % id)
		return
	office._set_talk(true, who)
	await frames(40)
	var guard := 0
	while office._talking and guard < 40:
		guard += 1
		office._talk_text.visible_characters = -1
		if office._waiting_for_choice():
			var chosen := false
			for b in office._talk_buttons.get_children():
				if b.is_queued_for_deletion():
					continue
				var t: String = b.text
				var want: String = {"ask": "ASK:", "yes_and": "YES, AND:", "riff": "RIFF:", "push": "PUSH:", "gift": "GIFT:", "callback": "CALLBACK:"}.get(pick, "")
				if (want != "" and t.begins_with(want)) or (pick == "gift" and t.begins_with("BRAG:")):
					b.pressed.emit()
					chosen = true
					break
			if not chosen:
				var first = office._talk_buttons.get_child(0)
				check(pick == "", "%s offered a %s reply (had: %s)" % [id, pick, first.text])
				first.pressed.emit()
			await frames(3)
			continue
		if office._talk_last:
			for b in office._talk_buttons.get_children():
				if b.text == "SEE YA" and not b.is_queued_for_deletion():
					b.pressed.emit()
			await frames(3)
			if office._talking:
				office._advance()
		else:
			office._advance()
		await frames(3)
	check(not office._talking, "talk with %s ended cleanly" % id)
	await frames(20)
