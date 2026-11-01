extends SceneTree
## Renders the ladder (the rooms past the office door) and saves PNGs to $OUT
## (needs a display). It starts a fresh save with Dale's story finished and
## the doors open, so every room can be visited:
##   OUT=/some/dir LAYOUT=portrait xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 --resolution 720x1280 -s res://tools/ladder_shot.gd
## Shots: arcade from the door, the claw and Gloria, playing the claw,
## the coin pusher, the ragdoll mid-fling, talking to Gloria (line, replies,
## answer), the prize counter, the trading floor and its terminal, the
## boardroom and the pitch, the corner office and the memo, the stage and the
## set list, the archive. It wipes user://dale.cfg, ladder.cfg, coworkers.cfg.

var office
var n := 0


func _init() -> void:
	for f in ["user://dale.cfg", "user://ladder.cfg", "user://coworkers.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var d := DaleStory.new()
	for ch in DaleLines.CHAPTERS:
		d.finish(ch.id, {})
	var l := LadderState.new()
	l.collect_paycheck({"pong_bosses": 2, "comedy_sets": 3})
	l.win_tickets(260)
	for m in ["market", "pitch", "memo"]:
		l.mark(m)
	l.items.append("door_key")
	l.items.append("archive_key")
	l.items.append("gloria_eye")
	l.save()
	for i in 3: await process_frame
	office = load("res://scenes/office/office.tscn").instantiate()
	root.add_child(office)
	for i in 5: await process_frame
	office._touch = true
	await _frames(60)
	# Through the office door into the arcade.
	await _stand(Vector3(1.8, 0, 3.2), 0.0, PI, -0.05)
	await _stand(Vector3(0.6, 0, 4.6), PI + 0.15, 0, -0.08)
	_shot("arcade")
	await _stand(Vector3(-0.8, 0, 5.4), PI / 2 + 0.25, 0, -0.1)
	_shot("claw_gloria")
	var claw = office._ladder._machines.claw
	office._set_seat(claw.pc)
	await _frames(80)
	claw.node._nudge(-80)
	claw.node._on_drop()
	await _frames(70)
	_shot("claw_play")
	office._set_seat(office._ladder._machines.pusher.pc)
	await _frames(60)
	for i in 4:
		office._ladder._machines.pusher.node._on_drop()
		await _frames(20)
	_shot("pusher")
	office._set_seat(office._ladder._machines.ragdoll.pc)
	await _frames(80)
	office._ladder._machines.ragdoll.node._on_fling()
	await _frames(45)
	_shot("ragdoll")
	office._set_seat(null)
	await _frames(30)
	# Talk to Gloria.
	await _stand(Vector3(-1.0, 0, 6.2), PI / 2 + 0.6, 0, -0.1)
	var gloria = null
	for who in office._ladder.people():
		if who.id == "gloria":
			gloria = who
	office._set_talk(true, gloria)
	await _frames(90)
	_shot("talk_line")
	office._advance()
	office._advance()
	await _frames(40)
	office._talk_text.visible_characters = -1
	office._advance()
	await _frames(30)
	_shot("talk_replies")
	for b in office._talk_buttons.get_children():
		if b.text.begins_with("ASK"):
			b.pressed.emit()
	await _frames(60)
	office._talk_text.visible_characters = -1
	await _frames(10)
	_shot("talk_answer")
	office._set_talk(false)
	await _frames(30)
	office._set_seat(office._ladder._machines.counter.pc)
	await _frames(90)
	_shot("counter")
	office._set_seat(null)
	await _frames(20)
	# The trading floor.
	await _stand(Vector3(0.3, 0, 12.8), PI, 0, -0.05)
	_shot("trading")
	var trade = office._ladder._machines.trading
	office._set_seat(trade.pc)
	await _frames(60)
	trade.node._open()
	await _frames(240)
	trade.node._buy(-1)
	await _frames(30)
	_shot("trading_play")
	office._set_seat(null)
	await _frames(20)
	await _stand(Vector3(1.6, 0, 20.9), PI + 0.35, 0, -0.05)
	_shot("boardroom")
	var pitch = office._ladder._machines.pitch
	office._set_seat(pitch.pc)
	await _frames(60)
	pitch.node._begin()
	await _frames(40)
	_shot("pitch")
	office._set_seat(null)
	await _frames(20)
	await _stand(Vector3(1.2, 0, 27.0), PI + 0.3, 0, -0.1)
	_shot("corner")
	var memo = null
	for who in office._ladder.people():
		if who.id == "memo":
			memo = who
	office._set_talk(true, memo)
	await _frames(90)
	office._talk_text.visible_characters = -1
	_shot("memo")
	office._set_talk(false)
	await _frames(30)
	await _stand(Vector3(2.2, 0, 33.0), PI - 0.3, 0, -0.05)
	_shot("stage")
	var stage = office._ladder._machines.stage
	office._set_seat(stage.pc)
	await _frames(60)
	stage.node._begin()
	await _frames(40)
	_shot("set_list")
	office._set_seat(null)
	await _frames(20)
	await _stand(Vector3(-3.9, 0, 7.4), PI / 2, 0, -0.05)
	_shot("archive")
	quit()


func _stand(at: Vector3, yaw: float, _unused: float, pitch: float) -> void:
	office._player.position = at
	office._player.velocity = Vector3.ZERO
	office._yaw = yaw
	office._pitch = pitch
	await _frames(45)


func _frames(k: int) -> void:
	for i in k: await process_frame


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var out := OS.get_environment("OUT")
	if out == "":
		out = "/tmp"
	var layout := OS.get_environment("LAYOUT")
	img.save_png("%s/%02d_%s_%s.png" % [out, n, name, layout if layout != "" else "shot"])
	n += 1
