extends Node
## Look Busy (docs/look-busy.md) in the office: the 9-to-5 clock, the boss on
## the floor, the suspicion meter, alt-tab, and getting caught. On when the
## pause menu's LOOK BUSY is on; off, the office plays exactly as before.
##   - The clock runs a workday in Workday.DAY_SECONDS real seconds (top
##     centre, with the suspicion meter and your strikes). The wall clock
##     shows it too.
##   - The boss comes by on a fixed schedule (data/busy_lines.gd): walking
##     bosses come in through the office door (it creaks), walk a route past
##     every desk and stop at yours; footsteps get louder, and seated you
##     can see their reflection in the screen. The WFH boss rings your screen
##     instead, then looks through it.
##   - Watched while you play a game, suspicion climbs; full = a strike:
##     warning, write-up, fired (the run starts over on floor 1). Not in the
##     office when the boss checks your desk = an empty-desk lump.
##   - ALT-TAB (Tab, Y on a pad, or the button while seated) covers the game
##     you're at with a fake spreadsheet (scenes/office/spreadsheet.gd); the
##     game keeps running behind it. Working while watched cools suspicion.
##   - Coworkers (engine/coworkers.gd role(), data/coworker_lines.gd BUSY):
##     lookouts cough before the boss comes and cover one empty desk a day;
##     snitches tip the boss off (an extra visit); collaborators bring their
##     side project to your game.
##   - Your own game (engine/game_maker.gd): beating desks (the shared stats,
##     arcade machines, every 20 spreadsheet cells) and collaborators hand you
##     pieces; the DEV KIT desk by the door (scenes/office/dev_kit.gd) combines
##     them into a scored game with a generated trailer.
##   - 5 PM: clock out. Friday 5 PM is ship day (engine/ship_day.gd): press
##     and coworker reviews, Theo ships his game, the reviews pay out (arcade
##     tokens and tickets), and a good week promotes you to the next floor and
##     its boss.
## Rules: engine/workday.gd. The pop-ups: scenes/office/busy_notice.gd.

const Notice := preload("res://scenes/office/busy_notice.gd")
const DOOR := Vector3(1.8, 0.0, 4.05)
const SPAWN := Vector3(0.3, 0.0, 3.2)
const EYE := 1.6
const STEP_EVERY := 0.52
const REFLECT_RANGE := 3.5
const HUD_W := 300.0
const HUD_H := 70.0
const CREAK := preload("res://audio/creak.wav")
const COUGH := preload("res://audio/cough.wav")
const BUSTED := preload("res://audio/busted.wav")
const RING := preload("res://audio/ring.wav")
const BELL := preload("res://audio/bell.wav")

var office: Node
var wd: Workday
var gm: GameMaker
var enabled := false
var notice: Control

var _sheet_vp: SubViewport
var _sheet: Control
var _covered = null
var _hud: Control
var _alt_button: Button
var _bosses := {}
var _boss_node: Node3D
var _visit_t := -1.0
var _call_t := -1.0
var _desk_checked := false
var _connected := false
var _seen := false
var _flash := 0.0
var _step_t := 0.0
var _door_open := false
var _save_t := 0.0
var _player: AudioStreamPlayer
var _feet: AudioStreamPlayer
var _ring: AudioStreamPlayer
var _ring_t := 0.0
var _reflect := 0.0
var _boss_pos := Vector2(99, 99)
var _boss_yaw := 0.0
var _morning_shown := false
var _kit_rig: Node3D
var _kit_vp: SubViewport
var _kit: Control
var _kit_pc
var _piece_t := 0.0
## Desk the DEV KIT sits on: right wall, by the door, facing into the room.
const KIT_DESK := Vector3(3.05, 0.0, 2.95)


func setup(o: Node) -> void:
	office = o
	wd = Workday.new()
	gm = GameMaker.new()
	_sheet_vp = SubViewport.new()
	_sheet_vp.size = Vector2i(720, 1280)
	_sheet_vp.disable_3d = true
	_sheet_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	office.add_child(_sheet_vp)
	_sheet = preload("res://scenes/office/spreadsheet.gd").new()
	_sheet_vp.add_child(_sheet)
	_sheet.filled.connect(_on_cell)
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = "Effects"
		add_child(p)
		if i == 0:
			_player = p
		elif i == 1:
			_feet = p
		else:
			_ring = p
	_ring.stream = RING


## After the office and the ladder are built: the bosses, the HUD, the pop-up.
func build() -> void:
	for b in BusyLines.BOSSES:
		if b.kind != "walk":
			continue
		var root: Node3D = office._ladder._person("office", "boss_" + b.id, Vector3(DOOR.x, 0, DOOR.z + 1.2), PI, b.look_body)
		root.visible = false
		_bosses[b.id] = root
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	office._hud.add_child(_hud)
	_alt_button = office._hud_button("ALT-TAB", Control.PRESET_TOP_RIGHT)
	_alt_button.custom_minimum_size = Vector2(230, 88)
	office._place_button(_alt_button, Control.PRESET_TOP_RIGHT)
	_alt_button.pressed.connect(alt_tab)
	notice = Notice.new()
	notice.office = office
	office.add_child(notice)
	_build_kit()


## The DEV KIT desk: GAMEMAKER 95 on a CRT by the door (scenes/office/dev_kit.gd).
func _build_kit() -> void:
	_kit_rig = Node3D.new()
	_kit_rig.position = KIT_DESK
	_kit_rig.rotation.y = -PI / 2
	office._world_vp.add_child(_kit_rig)
	var wood: Material = office._mat(Color(0.55, 0.42, 0.6), 3, Color(0.48, 0.36, 0.52), 60.0)
	var screen: Node3D = office._side_desk(_kit_rig, wood, office._beige(), "DEV KIT", Color(1.0, 0.4, 0.75), Color(0.35, 0.1, 0.4), office._charcoal())
	office._label("YOUR GAME", Vector3(0.15, 1.82, -0.32), 22, Color(1.0, 0.45, 0.8), Vector3.ZERO, 0.0, _kit_rig)
	_kit_vp = SubViewport.new()
	_kit_vp.size = Vector2i(720, 1280)
	_kit_vp.disable_3d = true
	_kit_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	office.add_child(_kit_vp)
	office._view_bus[_kit_vp] = office._make_bus("Ladder")
	_kit = preload("res://scenes/office/dev_kit.gd").new()
	_kit.busy = self
	_kit_vp.add_child(_kit)
	office._window_frame(office._side_a, screen.position, office.CUBE_SCREEN, "GAMEMAKER.EXE")
	_kit_pc = office._add_computer(screen, office.CUBE_SCREEN, _kit_vp, Vector2i(720, 1280))
	# Built after the room: put its shells in the current look.
	office._set_look(office._look_i, false)
	_show_kit(false)


## The desk only exists with Look Busy on (and doesn't block you without it).
func _show_kit(on: bool) -> void:
	if _kit_rig == null:
		return
	_kit_rig.visible = on
	_kit_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	var stack: Array = [_kit_rig]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is StaticBody3D:
			n.collision_layer = 1 if on else 0
		stack.append_array(n.get_children())


func set_enabled(on: bool) -> void:
	if on == enabled:
		return
	enabled = on
	if not on:
		if office and office._title:
			office._title.visible = true
		uncover()
		_end_visit()
		_call_t = -1.0
		_ring.stop()
	if _hud:
		_hud.visible = on
	_show_kit(on)
	if not on and office and office._seat == _kit_pc and _kit_pc != null:
		office._set_seat(null)


# ---------------------------------------------------------------- every frame

func tick(delta: float) -> void:
	if not enabled:
		_alt_button.visible = false
		return
	_place_hud()
	# The morning card replaces the office's own "MONDAY, 9:02 AM" title.
	office._title.visible = false
	if not _morning_shown and wd.minutes <= 0.0 and not notice.visible and not wd.fired:
		_morning()
		return
	if wd.fired and not notice.visible:
		_fired()
		return
	for ev in wd.tick(delta):
		match ev.type:
			"visit":
				_start_visit()
			"soon":
				_lookout_warns()
			"snitch":
				_snitch()
			"day_end":
				_day_end()
				return
	_tick_visit(delta)
	_tick_call(delta)
	var level := wd.watch(delta, _activity(), _seen, _visit_t >= 0.0 or _connected)
	if level != "":
		_caught(level)
	_flash = maxf(0.0, _flash - delta)
	_piece_t -= delta
	if _piece_t <= 0.0:
		_piece_t = 1.0
		_tick_pieces()
	_save_t -= delta
	if _save_t <= 0.0:
		_save_t = 5.0
		wd.save()
	# Seated: the boss's reflection in the glass when they're right behind you.
	var want := 0.0
	if office._seat and _boss_node and _boss_node.visible:
		var cam: Vector3 = office._camera.global_position
		var d := Vector2(cam.x, cam.z).distance_to(_boss_pos)
		if d < REFLECT_RANGE:
			want = 1.0 - d / REFLECT_RANGE
	_reflect = move_toward(_reflect, want, delta * 2.0)
	_alt_button.visible = office._seat != null and not office._pad
	_alt_button.text = "BACK TO\nTHE GAME" if is_covered() else "ALT-TAB"
	_alt_button.add_theme_font_size_override("font_size", 16 if is_covered() else 22)
	_place_hud()
	_hud.queue_redraw()
	_tick_wall_clock()


## Desk wins, fake work and collaborators turn into pieces for your game.
func _tick_pieces() -> void:
	var got: Array = []
	for src in gm.desk_wins(DaleStory.read_stats(), Array(office._ladder.state.beaten)):
		var p := gm.earn(src)
		if not p.is_empty():
			got.append(p)
	for i in gm.cell_wins(wd.cells_today):
		var p := gm.earn("spreadsheet")
		if not p.is_empty():
			got.append(p)
	got.append_array(gm.collaborate(crew().with_role("collaborator")))
	if got.is_empty():
		return
	var names: Array[String] = []
	for p in got:
		names.append("%s (%s)" % [p.name, GameMaker.KIND_NAMES[p.kind]])
	office._toast.text = "NEW PIECE%s: %s\nBUILD YOUR GAME AT THE DEV KIT" % ["S" if got.size() > 1 else "", ", ".join(names)]
	office._toast_time = 4.5
	_play(preload("res://audio/coin.wav"), -2.0)
	if _kit:
		_kit.refresh()


## What you're doing, as the boss would put it.
func _activity() -> String:
	if office._seat:
		# Building your game at the DEV KIT is also not your job.
		return "working" if is_covered() else "slacking"
	if office._talking:
		return "chatting"
	return "idle"


func _in_office() -> bool:
	return office._ladder.room() == "office"


# ---------------------------------------------------------------- the boss

func _start_visit() -> void:
	var b := wd.boss()
	if b.kind == "call":
		_call_t = 0.0
		_connected = false
		_desk_checked = false
		return
	_end_visit()
	_boss_node = _bosses.get(b.id)
	if _boss_node == null:
		return
	_visit_t = 0.0
	_desk_checked = false
	_boss_node.visible = true
	office._ladder.peek_arcade(true)


func _end_visit() -> void:
	_visit_t = -1.0
	_seen = false
	_boss_pos = Vector2(99, 99)
	for id in _bosses:
		_bosses[id].visible = false
	if _door_open:
		_swing_door(false)
	if office and office._ladder:
		office._ladder.peek_arcade(false)


func _tick_visit(delta: float) -> void:
	_seen = false
	if _visit_t < 0.0 or _boss_node == null:
		return
	var b := wd.boss()
	_visit_t += delta
	var pa := Workday.patrol_at(BusyLines.ROUTE, float(b.speed), _visit_t)
	if pa.done:
		_end_visit()
		return
	_boss_pos = pa.pos
	_boss_yaw = pa.yaw
	_boss_node.position = Vector3(pa.pos.x, 0.0, pa.pos.y)
	_boss_node.rotation.y = pa.yaw
	var walking: bool = pa.stop < 0
	var body: Node3D = _boss_node.get_child(0)
	body.position.y = absf(sin(_visit_t * 7.0)) * 0.03 if walking else 0.0
	body.rotation.z = sin(_visit_t * 7.0) * 0.03 if walking else 0.0
	# The door: opens as they reach it (creak), shuts behind them.
	var to_door := Vector2(pa.pos.x - DOOR.x, pa.pos.y - DOOR.z).length()
	if to_door < 1.3 and not _door_open:
		_swing_door(true)
	elif to_door > 1.8 and _door_open and pa.pos.y < DOOR.z:
		_swing_door(false)
	# Footsteps, louder as they get closer.
	if walking:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = STEP_EVERY / maxf(0.5, float(b.speed) / 1.1)
			_step(float(b.get("steps_db", -8.0)))
	# Your desk: are you anywhere in the office?
	if pa.desk and not _desk_checked:
		_desk_checked = true
		if not _in_office():
			_empty_desk()
	if not _in_office():
		return
	var me: Vector3 = office._player.global_position
	if Workday.sees(pa.pos, pa.yaw, Vector2(me.x, me.z), float(b.range), float(b.cone)):
		var eye := Vector3(pa.pos.x, EYE, pa.pos.y)
		_seen = not office._occluded(eye, me + Vector3(0, 1.2, 0), 0.3)


func _tick_call(delta: float) -> void:
	if _call_t < 0.0:
		_connected = false
		return
	var b := wd.boss()
	_call_t += delta
	var ring := float(b.get("ring", 4.0))
	if _call_t < ring:
		_ring_t -= delta
		if _ring_t <= 0.0:
			_ring_t = 1.2
			_ring.play()
		return
	if not _connected:
		_connected = true
		_ring.stop()
		# He sees whatever screen you're at. Not at one? Empty desk.
		if office._seat == null:
			_empty_desk()
	if _call_t >= ring + float(b.get("call", 5.0)):
		_call_t = -1.0
		_connected = false
		return
	_seen = office._seat != null


func _empty_desk() -> void:
	var b := wd.boss()
	# A lookout covers for you, once a day.
	var lookouts := crew().with_role("lookout")
	if not lookouts.is_empty() and wd.cover():
		var who: String = lookouts[wd.day % lookouts.size()]
		office._toast.text = "EMPTY DESK... COVERED.\n" + str(CoworkerLines.BUSY[who].cover).to_upper()
		office._toast_time = 4.5
		return
	var lines: Array = b.desk
	office._toast.text = "%s: \"%s\"\n+SUSPICION (EMPTY DESK)" % [b.name, lines[randi() % lines.size()]]
	office._toast_time = 4.0
	_flash = 1.0
	var level := wd.add(Workday.EMPTY_DESK)
	if level != "":
		_caught(level)


# ---------------------------------------------------------------- coworkers

func crew() -> Coworkers:
	return office._ladder.crew


## A lookout coughs a little before the boss comes by.
func _lookout_warns() -> void:
	var lookouts := crew().with_role("lookout")
	if lookouts.is_empty():
		return
	var who: String = lookouts[(wd.day + int(wd.minutes / 60.0)) % lookouts.size()]
	_play(COUGH, -1.0)
	var b := wd.boss()
	var what := "%s IS ON THE WAY" % b.name if b.kind == "walk" else "%s IS ABOUT TO CALL" % b.name
	office._toast.text = "%s: \"%s\"\n(%s)" % [Coworkers.person(who).name, CoworkerLines.BUSY[who].lookout, what]
	office._toast_time = 4.5


## A snitch tips the boss off: suspicion, and the boss comes to look.
func _snitch() -> void:
	var snitches := crew().with_role("snitch")
	if snitches.is_empty():
		return
	var who: String = snitches[wd.day % snitches.size()]
	office._toast.text = "SNITCH! " + str(CoworkerLines.BUSY[who].snitch).to_upper()
	office._toast_time = 4.5
	_flash = 1.0
	var level := wd.add(Workday.SNITCH)
	if level != "":
		_caught(level)
		return
	if _visit_t < 0.0 and _call_t < 0.0:
		_start_visit()


## The toast when a talk changes someone's role.
func role_news(id: String, r: String) -> String:
	var n: String = Coworkers.person(id).name
	match r:
		"lookout":
			return "%s IS YOUR LOOKOUT: A COUGH = THE BOSS IS COMING" % n
		"collaborator":
			return "%s WILL COLLABORATE: %s JOINS YOUR GAME" % [n, CoworkerLines.BUSY[id].side.name]
		"snitch":
			return "YOU BURNED %s. NOW THEY SNITCH. (A GIFT OR A CALLBACK MAKES UP)" % n
	return ""


## "Lookouts: KEV, GLORIA. Snitches: BERNIE." for the morning card.
func crew_text() -> String:
	var parts: Array[String] = []
	for r in ["lookout", "snitch"]:
		var names: Array[String] = []
		for id in crew().with_role(r):
			names.append(Coworkers.person(id).name)
		if not names.is_empty():
			parts.append("%s: %s." % ["Lookouts" if r == "lookout" else "Snitches", ", ".join(names)])
	return " ".join(parts) if not parts.is_empty() else "No lookouts yet. Make friends in the break room (past the door)."


func _swing_door(open: bool) -> void:
	_door_open = open
	var d: Dictionary = office._ladder._doors.get("office", {})
	if d.is_empty() or d.open:
		return
	var t := create_tween()
	t.tween_property(d.hinge, "rotation:y", -PI * 0.55 if open else 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	if open and bool(wd.boss().get("creak", true)):
		_play(CREAK, _distance_db(Vector2(DOOR.x, DOOR.z), -2.0))


func _step(db: float) -> void:
	var sounds: Array = office._step_sounds
	if sounds.is_empty():
		return
	_feet.stream = sounds[randi() % sounds.size()]
	_feet.pitch_scale = randf_range(0.8, 0.9)
	_feet.volume_db = _distance_db(_boss_pos, db)
	_feet.play()


## Quieter with distance from you (and from the office, past its door).
func _distance_db(at: Vector2, db: float) -> float:
	var cam: Vector3 = office._camera.global_position
	var d := Vector2(cam.x, cam.z).distance_to(at)
	return db - clampf(d - 1.0, 0.0, 12.0) * 1.6


func _play(stream: AudioStream, db := 0.0) -> void:
	_player.stream = stream
	_player.volume_db = db
	_player.play()


# ---------------------------------------------------------------- caught

func _caught(level: String) -> void:
	var b := wd.boss()
	_play(BUSTED, -2.0)
	_flash = 1.5
	var lines: Array = b[level]
	var quote := "%s: \"%s\"" % [b.name, lines[randi() % lines.size()]]
	if level == "fired":
		_fired(quote)
		return
	var head := "VERBAL WARNING" if level == "warning" else "WRITTEN UP"
	var next := "Next time it's a write-up." if level == "warning" else "One more and you're fired."
	notice.show_notice("HR.EXE", "%s (%d/3)" % [head, wd.strikes], "%s\n\n%s Alt-tab (Tab / Y / the ALT-TAB button) when the boss is near." % [quote, next],
			[["BACK TO WORK", func(): pass]], Color(0.75, 0.35, 0.0) if level == "warning" else Color(0.7, 0.1, 0.08))


func _fired(quote := "") -> void:
	uncover()
	_end_visit()
	_call_t = -1.0
	var body := "%s\n\nYou made it to %s on floor %d, week %d. Best floor: %d." % [
		quote if quote != "" else "Three strikes.", wd.clock_text(), wd.floor_i, wd.week, wd.best_floor]
	notice.show_notice("HR.EXE", "YOU'RE FIRED", body, [["START OVER\n(FLOOR 1, MONDAY)", _start_over]], Color(0.7, 0.1, 0.08))


func _start_over() -> void:
	wd.start_over()
	gm.reset()
	_go_home()


# ---------------------------------------------------------------- the day

func _day_end() -> void:
	uncover()
	_end_visit()
	_call_t = -1.0
	_play(BELL, -4.0)
	var friday := wd.is_friday()
	if friday:
		_ship_day()
		return
	var body := "Clocked out. Today: %d spreadsheet cells. Strikes: %d/3.\n\nYour game: %s (%d pieces). It ships Friday at 5." % [
		wd.cells_today, wd.strikes, gm.title() if not gm.build.is_empty() else "nothing yet", gm.pieces.size()]
	notice.show_notice("CLOCK.EXE", "5:00 PM", body, [["GO HOME", _next_day]], Color(0.06, 0.14, 0.6))


# ---------------------------------------------------------------- Friday

## Ship day: your game ships, the press and the crew review it, Theo ships
## his, the reviews pay out, and a good week promotes you.
func _ship_day() -> void:
	var met := {}
	for id in crew().met:
		met[id] = crew().role(id)
	var r := ShipDay.review(gm.build, met, wd.floor_i, wd.week)
	wd.record_ship(r)
	var lines: Array[String] = []
	for p in r.press:
		lines.append("%s  %s/10\n%s" % [p.who, ShipDay.fmt(p.score), p.quote])
	var head := "YOU SHIPPED\n%s" % r.title if r.shipped else "YOU SHIPPED NOTHING"
	var body := ("Score %d. Press average %s/10.\n\n" % [r.score, ShipDay.fmt(r.press_avg)]) + "\n\n".join(lines)
	notice.show_notice("SHIP.EXE", head, body, [["NEXT: THE OFFICE", _ship_crew.bind(r)]], Color(0.75, 0.2, 0.55))


func _ship_crew(r: Dictionary) -> void:
	if r.crew.is_empty():
		_ship_theo(r)
		return
	var lines: Array[String] = []
	for c in r.crew:
		lines.append("%s  %s/10\n\"%s\"" % [c.who, ShipDay.fmt(c.score), c.quote])
	notice.show_notice("SHIP.EXE", "THE OFFICE PLAYED IT", "\n\n".join(lines), [["NEXT: THEO", _ship_theo.bind(r)]], Color(0.75, 0.2, 0.55))


func _ship_theo(r: Dictionary) -> void:
	var body := "Theo shipped %s.\nPress average: %s/10.\n\nYours: %s/10.\n\n%s" % [
		r.theo.title, ShipDay.fmt(r.theo.score), ShipDay.fmt(r.press_avg),
		"You beat him. He's furious. He's making risotto about it." if r.beat_theo else "He beat you. He made sure everyone saw."]
	notice.show_notice("RIVAL.EXE", "THEO SHIPPED TOO", body, [["NEXT: PAYDAY", _ship_pay.bind(r)]], Color(0.12, 0.15, 0.4))


func _ship_pay(r: Dictionary) -> void:
	var state: LadderState = office._ladder.state
	state.apply_reward("tokens:%d" % r.tokens)
	state.apply_reward("tickets:%d" % r.tickets)
	office._ladder.dev_refresh()
	var body := "Reviews paid out: +%d tokens, +%d tickets (for the break room arcade).\n\n" % [r.tokens, r.tickets]
	var head := "NO PROMOTION"
	var button := "NEXT WEEK (FLOOR %d)" % wd.floor_i
	if r.promoted and wd.floor_i >= BusyLines.FLOORS:
		head = "TOP OF THE BUILDING"
		body += "A great week, and there's no floor left above this one. Just a door at the very top that nobody has a key to. Yet."
	elif r.promoted:
		var next := Workday.boss_for(wd.floor_i + 1)
		head = "PROMOTED!"
		body += "Floor %d. New desk, new boss: %s (%s)." % [wd.floor_i + 1, next.name, next.title]
		button = "MOVE UP TO FLOOR %d" % (wd.floor_i + 1)
	else:
		body += "You need a press average of %s and to beat Theo. Another week on floor %d." % [ShipDay.fmt(ShipDay.PROMOTE_AT), wd.floor_i]
	notice.show_notice("PAYROLL.EXE", head, body, [[button, _new_week.bind(r.promoted)]], Color(0.1, 0.5, 0.2) if r.promoted else Color(0.4, 0.3, 0.1))
	if r.promoted:
		_play(preload("res://audio/fanfare.wav"), -2.0)


func _new_week(promote: bool) -> void:
	wd.new_week(promote)
	gm.new_week()
	_go_home()


func _next_day() -> void:
	if wd.next_day():
		gm.new_day()
	else:
		wd.new_week(false)
		gm.new_week()
	_go_home()


## Morning: you're back at the door, standing, and the day's card shows.
func _go_home() -> void:
	uncover()
	_end_visit()
	_call_t = -1.0
	_ring.stop()
	if office._talking:
		office._set_talk(false)
	office._set_seat(null)
	office._player.global_position = SPAWN
	office._player.velocity = Vector3.ZERO
	office._yaw = 0.0
	office._pitch = -0.08
	office._glide = 1.0
	_morning_shown = false
	wd.save()


func _morning() -> void:
	_morning_shown = true
	var b := wd.boss()
	var day: String = BusyLines.DAYS[wd.day]
	var body := "Floor %d, week %d. %s\n\nBoss: %s\n%s\n\nPlay the desk games, but if the boss sees you playing, suspicion climbs. Full meter = a strike. Three strikes = fired. ALT-TAB (Tab / Y / the button) to a spreadsheet.\n\nCrew: %s" % [
		wd.floor_i, wd.week, BusyLines.MORNING[wd.day], b.hello, b.habit, crew_text()]
	notice.show_notice("MONDAY.EXE" if wd.day == 0 else day + ".EXE", "%s, 9:00 AM" % day, body, [["CLOCK IN", func(): pass]], Color(0.06, 0.14, 0.6))


# ---------------------------------------------------------------- alt-tab

func is_covered() -> bool:
	return _covered != null


## Swap the screen you're at between its game and the spreadsheet.
func alt_tab() -> void:
	if not enabled:
		return
	if is_covered():
		uncover()
		return
	var pc = office._seat
	if pc == null:
		return
	pc.release()
	_sheet_vp.size = Vector2i(pc.pixels)
	_sheet_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sheet.open(wd.cells_today)
	pc.set_cover(_sheet_vp)
	_covered = pc
	_play(preload("res://audio/click.wav"), -4.0)


func uncover() -> void:
	if _covered:
		_covered.release()
		_covered.set_cover(null)
		_covered = null
	if _sheet_vp:
		_sheet_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


## The office stood you up or moved you to another screen.
func on_seat_changed() -> void:
	if _covered and office._seat != _covered:
		uncover()
	if _kit:
		_kit.set_active(office._seat == _kit_pc and _kit_pc != null)


## SHIP IT on Friday: the week ends now.
func ship_now() -> void:
	if not wd.is_friday():
		return
	wd.minutes = Workday.DAY_MINUTES
	wd.save()
	_day_end()


func _on_cell() -> void:
	wd.fill_cell()


# ---------------------------------------------------------------- HUD

func _place_hud() -> void:
	var size: Vector2 = office._hud.size
	var inset: Vector4 = office._inset
	var wide := size.x > size.y
	_hud.position = Vector2((size.x - HUD_W) * 0.5, 14 + inset.y)
	_hud.size = Vector2(HUD_W, HUD_H)
	# Upright, the TO-DO steps down under the clock.
	office._todo.offset_top = 24 + inset.y + (0 if wide else 80)


func _draw_hud() -> void:
	var font: Font = preload("res://fonts/press_start_2p.ttf")
	var w := HUD_W
	var watched := _seen and _activity() != "working"
	var bg := Color(0.05, 0.04, 0.08, 0.72)
	if _flash > 0.0 and fmod(_flash, 0.3) < 0.15:
		bg = Color(0.6, 0.05, 0.05, 0.85)
	_hud.draw_rect(Rect2(Vector2.ZERO, Vector2(w, HUD_H)), bg)
	_hud.draw_rect(Rect2(Vector2.ZERO, Vector2(w, HUD_H)), Color(1, 1, 1, 0.5), false, 2.0)
	var b := wd.boss()
	_hud.draw_string(font, Vector2(10, 24), wd.clock_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.92, 0.55))
	_hud.draw_string(font, Vector2(10, 24), "FL%d" % wd.floor_i, HORIZONTAL_ALIGNMENT_RIGHT, w - 20, 12, Color(1, 1, 1, 0.6))
	# Suspicion bar.
	var bar := Rect2(10, 36, w - 100, 22)
	_hud.draw_rect(bar, Color(0.15, 0.15, 0.18))
	var k := wd.suspicion / Workday.MAX_SUSPICION
	var col := Color(0.3, 0.85, 0.35).lerp(Color(1.0, 0.85, 0.2), clampf(k * 2.0, 0.0, 1.0)).lerp(Color(1.0, 0.2, 0.15), clampf(k * 2.0 - 1.0, 0.0, 1.0))
	_hud.draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), col)
	_hud.draw_string(font, bar.position + Vector2(6, 16), "!! WATCHED !!" if watched else "SUSPICION", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(1, 1, 1, 1.0 if watched and fmod(Time.get_ticks_msec() / 250.0, 2.0) < 1.0 else 0.75))
	# Strikes.
	for i in 3:
		var r := Rect2(w - 82 + i * 24, 38, 18, 18)
		_hud.draw_rect(r, Color(0.85, 0.15, 0.1) if i < wd.strikes else Color(1, 1, 1, 0.15))
		_hud.draw_rect(r, Color(1, 1, 1, 0.6), false, 2.0)
	# An incoming video call (the WFH boss).
	if _call_t >= 0.0:
		var ringing := not _connected
		var text := ("INCOMING CALL: %s" % b.name) if ringing else ("ON CALL WITH %s" % b.name)
		var cr := Rect2(0, HUD_H + 6, w, 34)
		var on := not ringing or fmod(_call_t, 0.6) < 0.3
		_hud.draw_rect(cr, Color(0.1, 0.45, 0.2, 0.9) if on else Color(0.05, 0.2, 0.1, 0.9))
		_hud.draw_string(font, cr.position + Vector2(8, 22), text, HORIZONTAL_ALIGNMENT_LEFT, w - 16, 11, Color.WHITE)
	# The boss's reflection in the glass, seated with them right behind you.
	if _reflect > 0.01:
		_draw_reflection()


func _draw_reflection() -> void:
	var size: Vector2 = office._hud.size
	var a := 0.32 * _reflect
	var col := Color(0.02, 0.02, 0.04, a)
	var c := Vector2(size.x * 0.72, size.y * 0.42) - _hud.position
	var s := minf(size.x, size.y) / 720.0
	_hud.draw_circle(c, 70 * s, col)
	_hud.draw_rect(Rect2(c + Vector2(-26, 60) * s, Vector2(52, 40) * s), col)
	var pts := PackedVector2Array([c + Vector2(-170, 340) * s, c + Vector2(-120, 110) * s, c + Vector2(120, 110) * s, c + Vector2(170, 340) * s])
	_hud.draw_colored_polygon(pts, col)


func _tick_wall_clock() -> void:
	var hands: Array = office._clock_hands
	if hands.size() != 2:
		return
	var hm := wd.hour_minute()
	hands[0].rotation.z = -TAU * (fmod(hm.x, 12) + hm.y / 60.0) / 12.0
	hands[1].rotation.z = -TAU * hm.y / 60.0


# ---------------------------------------------------------------- dev

func dev_boss_now() -> void:
	_start_visit()


func dev_skip_to(minute: float) -> void:
	wd.minutes = clampf(minute, 0.0, Workday.DAY_MINUTES - 0.1)
	wd.save()


func dev_friday() -> void:
	wd.day = BusyLines.DAYS.size() - 1
	wd.minutes = Workday.DAY_MINUTES - 10.0
	wd.save()


func dev_strike() -> void:
	var level := wd.strike()
	_caught.call_deferred(level)


func dev_ship_now() -> void:
	wd.day = BusyLines.DAYS.size() - 1
	wd.minutes = Workday.DAY_MINUTES
	wd.save()
	uncover()
	_ship_day()


func dev_promote() -> void:
	wd.new_week(true)
	gm.new_week()
	_go_home()


func dev_all_pieces() -> void:
	for src in GameMaker.SOURCES:
		for p in GameMaker.SOURCES[src]:
			gm.add(p[0], p[1], src)
	gm.collaborate(CoworkerLines.ORDER)
	if _kit:
		_kit.refresh()


func dev_piece(src: String) -> void:
	var p := gm.earn(src)
	office._toast.text = "NEW PIECE: %s" % p.get("name", "(NONE LEFT)")
	office._toast_time = 3.0
	if _kit:
		_kit.refresh()


func dev_clear() -> void:
	wd.strikes = 0
	wd.suspicion = 0.0
	wd.fired = false
	wd.save()
