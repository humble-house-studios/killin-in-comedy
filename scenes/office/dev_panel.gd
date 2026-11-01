extends Control
## The office DEV panel (only when Dev.ON): skip ahead to test the later
## parts of the office and the ladder without playing through them. Opened by
## the DEV button (top right, under LOOK) or the ` / F1 key; Esc closes.
## Every shortcut writes the same saves playing would (Dale, the ladder, the
## coworkers, the Loot Machine's shared stats), so what it unlocks stays
## unlocked. WIPE puts everything back to a fresh start.

const FONT := preload("res://fonts/press_start_2p.ttf")
const GOLD := Color(1.0, 0.85, 0.3)
const DEV_ORANGE := Color(1.0, 0.55, 0.2)

var office: Node
var _info: Label
var _status: Label
var _panel: PanelContainer
var _scroll: ScrollContainer
var _grids: Array[GridContainer] = []
var _wipe: Button
var _wipe_armed := false


func setup(o: Node) -> void:
	office = o
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.95)
	style.border_color = DEV_ORANGE
	style.set_border_width_all(4)
	style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var title := _text("DEV TOOLS", 22, DEV_ORANGE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	var close_b := _button("CLOSE", close)
	close_b.custom_minimum_size.x = 180
	head.add_child(close_b)
	_info = _text("", 12, Color(0.85, 0.85, 0.9))
	col.add_child(_info)
	_status = _text("Shortcuts to test later parts. They save like the real thing.", 12, GOLD)
	col.add_child(_status)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	_scroll.add_child(list)

	_section(list, "DALE'S STORY", [
		["MEET NEXT GOAL", _meet_goal],
		["SKIP CHAPTER", _skip_chapter],
		["FINISH STORY\n(OPENS THE DOOR)", _finish_story],
	])
	_section(list, "LOOK BUSY (WORKDAY)", [
		["BOSS COMES\nBY NOW", _boss_now],
		["SKIP TO\n4:55 PM", _skip_day],
		["SKIP TO\nFRIDAY 4:50", _skip_week],
		["+1 STRIKE", _strike],
		["CLEAR STRIKES\n+ SUSPICION", _clear_strikes],
		["KEV IS A\nLOOKOUT", _role.bind("kev", "lookout")],
		["GLORIA\nCOLLABORATES", _role.bind("gloria", "collaborator")],
		["BURN BERNIE\n(SNITCH)", _role.bind("bernie", "snitch")],
		["LOOKOUT\nCOUGHS NOW", _cough],
		["SNITCH\nTELLS NOW", _snitch],
		["+1 COMEDY\nPIECE", _piece.bind("comedy")],
		["+1 LOOT\nPIECE", _piece.bind("loot")],
		["ALL PIECES", _all_pieces],
		["SHIP NOW\n(FRIDAY 5 PM)", _ship_now],
		["PROMOTE\n(NEXT FLOOR)", _promote],
	])
	_section(list, "COMEDY (YOUR DESK)", [
		["WIN THIS SET", _win_set],
		["SKIP TO THE\nHEADLINE SHOW", _skip_to_boss],
	])
	_section(list, "THE LADDER", [
		["+100 TOKENS", _tokens],
		["+300 TICKETS", _tickets],
		["BEAT ALL\nMACHINES", _machines],
		["MAX ALL\nCOWORKERS", _coworkers],
		["OPEN ALL DOORS", _doors],
	])
	_section(list, "LOOT MACHINE", [
		["+10 COMP TOKENS", _loot_tokens],
		["+500 SHARDS", _loot_shards],
		["ALL RELICS", _loot_relics],
	])
	var spots: Array = []
	var where: Dictionary = office._ladder.dev_spots()
	for room in where:
		spots.append([str(where[room].name), _teleport.bind(room)])
	_section(list, "TELEPORT", spots)
	_section(list, "SAVES", [["WIPE ALL SAVES", _wipe_saves]])
	_wipe = _grids.back().get_child(0)
	# The phone turned while it's open.
	resized.connect(func():
		if visible:
			layout())


func open() -> void:
	_wipe_armed = false
	_wipe.text = "WIPE ALL SAVES"
	_status.text = "Shortcuts to test later parts. They save like the real thing."
	layout()
	_refresh()
	_scroll.scroll_vertical = 0
	visible = true


func close() -> void:
	visible = false


## Fit inside the safe area; three columns sideways, two upright.
func layout() -> void:
	var inset: Vector4 = office._inset
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var side := maxf(16.0, (size.x - 1100.0) * 0.5)
	_panel.offset_left = side + inset.x
	_panel.offset_right = -side - inset.z
	_panel.offset_top = 16 + inset.y
	_panel.offset_bottom = -16 - inset.w
	var cols := 3 if size.x > size.y else 2
	for g in _grids:
		g.columns = cols


# ---------------------------------------------------------------- building

func _section(list: VBoxContainer, heading: String, buttons: Array) -> void:
	var h := _text(heading, 14, Color(1, 1, 1, 0.6))
	list.add_child(h)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	list.add_child(grid)
	_grids.append(grid)
	for b in buttons:
		var button := _button(b[0], b[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)


func _text(t: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 6)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(t: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 88)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_constant_override("line_spacing", 6)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.12, 0.18)
	normal.border_color = Color(1, 1, 1, 0.7)
	normal.set_border_width_all(3)
	normal.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	var down := normal.duplicate()
	down.bg_color = Color(0.35, 0.22, 0.12)
	down.border_color = DEV_ORANGE
	b.add_theme_stylebox_override("pressed", down)
	b.pressed.connect(func():
		action.call()
		_refresh())
	return b


func _say(t: String) -> void:
	_status.text = t


func _refresh() -> void:
	var story: DaleStory = office._dale_story
	var stats := DaleStory.read_stats()
	var ladder = office._ladder
	var dale := story.file_label()
	if story.next_chapter().is_empty():
		dale = "DONE, DOOR OPEN"
	var goal: String = story.objective(stats) if not story.next_chapter().is_empty() else ladder.objective()
	_info.text = "DALE: %s   ROOM: %s\nTOKENS %d  TICKETS %d  SECRETS %d/%d\nTO-DO: %s" % [
		dale, ladder.room().to_upper(), ladder.state.tokens, ladder.state.tickets,
		ladder.crew.secrets.size(), LadderState.SECRETS_TOTAL, goal]


# ---------------------------------------------------------------- Dale

## Add whatever the shared office stats are short of (the same counters the
## games bump), through the Loot Machine's save when it's in the build.
func _bump(stat: String, n: int) -> void:
	var relics = _relics()
	if relics:
		relics.bump(stat, n)
		return
	var cfg := ConfigFile.new()
	cfg.load(DaleStory.RELICS_PATH)
	var s = cfg.get_value("stats", "all", {})
	if not s is Dictionary:
		s = {}
	s[stat] = int(s.get(stat, 0)) + n
	cfg.set_value("stats", "all", s)
	cfg.save(DaleStory.RELICS_PATH)


## Meet the next chapter's goal. Returns the chapter, or {} if the story's done.
func _meet() -> Dictionary:
	var ch: Dictionary = office._dale_story.next_chapter()
	if ch.is_empty():
		return {}
	var add := Dev.missing(ch, DaleStory.read_stats())
	for stat in add:
		_bump(stat, add[stat])
	office._news_check = 0.0
	return ch


func _meet_goal() -> void:
	var ch := _meet()
	_say("DALE'S STORY IS ALREADY DONE." if ch.is_empty() else "GOAL MET. TALK TO DALE FOR \"%s\"." % ch.title)


func _skip_chapter() -> void:
	var ch := _meet()
	if ch.is_empty():
		_say("DALE'S STORY IS ALREADY DONE.")
		return
	office._dale_story.finish(ch.id, DaleStory.read_stats())
	office._ladder.dev_refresh()
	var next: Dictionary = office._dale_story.next_chapter()
	_say("SKIPPED \"%s\". %s" % [ch.title, "THE DOOR'S OPEN." if next.is_empty() else "NEXT: " + str(next.get("goal", ""))])


func _finish_story() -> void:
	var n := 0
	while not office._dale_story.next_chapter().is_empty():
		var ch := _meet()
		office._dale_story.finish(ch.id, DaleStory.read_stats())
		n += 1
	office._ladder.dev_refresh()
	_say("DALE'S STORY DONE (%d SKIPPED). THE DOOR BEHIND YOU IS OPEN." % n)


# ---------------------------------------------------------------- Look Busy

func _busy_on() -> bool:
	if office._busy and office._busy.enabled:
		return true
	_say("TURN LOOK BUSY ON IN THE PAUSE MENU FIRST.")
	return false


func _boss_now() -> void:
	if _busy_on():
		close()
		office._busy.dev_boss_now()


func _skip_day() -> void:
	if _busy_on():
		office._busy.dev_skip_to(Workday.DAY_MINUTES - 5.0)
		_say("4:55 PM. THE BELL RINGS IN A FEW SECONDS.")


func _skip_week() -> void:
	if _busy_on():
		office._busy.dev_friday()
		_say("FRIDAY, ALMOST 5. THE WEEK ENDS IN A FEW SECONDS.")


func _strike() -> void:
	if _busy_on():
		close()
		office._busy.dev_strike()


func _role(id: String, role: String) -> void:
	Dev.set_role(office._ladder.crew, id, role)
	office._ladder.dev_refresh()
	_say("%s IS NOW A %s." % [Coworkers.person(id).name, role.to_upper()])


func _cough() -> void:
	if _busy_on():
		if office._ladder.crew.with_role("lookout").is_empty():
			_say("NO LOOKOUTS YET. MAKE KEV ONE FIRST.")
			return
		close()
		office._busy._lookout_warns()


func _snitch() -> void:
	if _busy_on():
		if office._ladder.crew.with_role("snitch").is_empty():
			_say("NO SNITCHES. BURN BERNIE FIRST.")
			return
		close()
		office._busy._snitch()


func _piece(src: String) -> void:
	if _busy_on():
		office._busy.dev_piece(src)
		_say("A %s PIECE. BUILD AT THE DEV KIT (RIGHT WALL, BY THE DOOR)." % src.to_upper())


func _all_pieces() -> void:
	if _busy_on():
		office._busy.dev_all_pieces()
		_say("EVERY PIECE THIS WEEK. TRY COMEDY + SLOT REELS.")


func _ship_now() -> void:
	if _busy_on():
		close()
		office._busy.dev_ship_now()


func _promote() -> void:
	if _busy_on():
		close()
		office._busy.dev_promote()


func _clear_strikes() -> void:
	if _busy_on():
		office._busy.dev_clear()
		_say("STRIKES 0/3, SUSPICION 0.")


# ---------------------------------------------------------------- comedy

func _comedy() -> Node:
	var vp: Viewport = office._game_vp
	return vp.get_child(0) if vp and vp.get_child_count() > 0 else null


func _win_set() -> void:
	var g := _comedy()
	if g and g.has_method("dev_win_set") and g.dev_win_set():
		_say("SET WON. IT COUNTS FOR DALE'S GOAL.")
	else:
		_say("NO SET RUNNING. SIT AT YOUR DESK AND START ONE.")


func _skip_to_boss() -> void:
	var g := _comedy()
	if g and g.has_method("dev_skip_to_headline") and g.dev_skip_to_headline():
		_say("NEXT UP AT YOUR DESK: THE HEADLINE SHOW.")
	else:
		_say("START A RUN AT YOUR DESK FIRST (OR YOU'RE ALREADY AT THE BOSS).")


# ---------------------------------------------------------------- ladder

func _tokens() -> void:
	office._ladder.state.apply_reward("tokens:100")
	office._ladder.dev_refresh()
	_say("+100 TOKENS.")


func _tickets() -> void:
	office._ladder.state.win_tickets(300)
	office._ladder.dev_refresh()
	_say("+300 TICKETS. THE DOOR KEY IS 300 AT THE PRIZE COUNTER.")


func _machines() -> void:
	Dev.beat_machines(office._ladder.state)
	office._ladder.dev_refresh()
	_say("CLAW, PUSHER AND FALL GUY BEATEN. RAY IS OUT.")


func _coworkers() -> void:
	Dev.max_coworkers(office._ladder.crew, office._ladder.state)
	office._ladder.dev_refresh()
	_say("EVERY COWORKER AT FULL TRUST: ALL 5 SECRETS AND PERKS.")


func _doors() -> void:
	_finish_story()
	Dev.open_ladder(office._ladder.state)
	office._ladder.dev_refresh()
	_say("EVERY DOOR IS OPEN. TELEPORT OR WALK ON THROUGH.")


# ---------------------------------------------------------------- Loot Machine

func _relics():
	return office._link.get("relics") if office._link else null


func _loot_tokens() -> void:
	var r = _relics()
	if r == null:
		_say("THE LOOT MACHINE ISN'T IN THIS BUILD.")
		return
	r.add_tokens(10)
	_say("COMP TOKENS: %d (THE MACHINE CAPS THEM)." % r.tokens)


func _loot_shards() -> void:
	var r = _relics()
	if r == null:
		_say("THE LOOT MACHINE ISN'T IN THIS BUILD.")
		return
	r.add_shards(500)
	_say("SHARDS: %d. SPEND THEM AT THE MACHINE'S PRIZE COUNTER." % r.shards)


func _loot_relics() -> void:
	var r = _relics()
	if r == null:
		_say("THE LOOT MACHINE ISN'T IN THIS BUILD.")
		return
	for id in r.unowned():
		r.grant(id)
	_say("EVERY RELIC OWNED. THEY KICK IN ON THE NEXT RUN OR SET.")


# ---------------------------------------------------------------- teleport and saves

func _teleport(room: String) -> void:
	office._ladder.dev_teleport(room)
	close()


func _wipe_saves() -> void:
	if not _wipe_armed:
		_wipe_armed = true
		_wipe.text = "TAP AGAIN\nTO WIPE"
		_say("THIS RESETS DALE, THE LADDER, COWORKERS, RELICS AND TIPS.")
		return
	Dev.wipe()
	get_tree().reload_current_scene()
