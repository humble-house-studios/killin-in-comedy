extends "res://scenes/ladder/machine.gd"
## The boardroom projector: pitch your dream project. Each board member raises
## an objection; answer with the card that matches it (or a YES, AND wild
## card). Three yeses of five greenlight it and open the corner office.
## Theo's vote starts you on one yes; Bernie's HR badge buys one redraw.

var pitch: Pitch
var _who: Label
var _line: Label
var _votes: Control
var _hand: VBoxContainer
var _redraw: Button
var _start: Button
var _helpers: Label


func _ready() -> void:
	super._ready()
	frame("THE PITCH", Color(0.05, 0.06, 0.12), Color(0.55, 0.75, 1.0))
	_top.text = "THREE YESES OF FIVE"
	_helpers = label("", 20, Color(1, 1, 1, 0.6))
	_helpers.position = Vector2(0, 150)
	_helpers.size = Vector2(W, 60)
	add_child(_helpers)
	_votes = Control.new()
	_votes.position = Vector2(60, 220)
	_votes.size = Vector2(W - 120, 70)
	_votes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_votes.draw.connect(_draw_votes)
	add_child(_votes)
	_who = label("", 30, Color(0.55, 0.75, 1.0))
	_who.position = Vector2(20, 320)
	_who.size = Vector2(W - 40, 50)
	add_child(_who)
	_line = label("", 32, Color.WHITE)
	_line.position = Vector2(30, 390)
	_line.size = Vector2(W - 60, 200)
	add_child(_line)
	_hand = VBoxContainer.new()
	_hand.position = Vector2(30, 640)
	_hand.size = Vector2(W - 60, 450)
	_hand.add_theme_constant_override("separation", 14)
	add_child(_hand)
	_redraw = button("HR BADGE: REDRAW", 24, Color(0.25, 0.15, 0.3))
	_redraw.position = Vector2(140, 1130)
	_redraw.size = Vector2(W - 280, 110)
	_redraw.pressed.connect(func():
		if pitch and pitch.redraw():
			sfx("card")
			_refresh())
	add_child(_redraw)
	_start = button("START THE PITCH", 34, Color(0.12, 0.25, 0.5))
	_start.position = Vector2(60, 700)
	_start.size = Vector2(W - 120, 160)
	_start.z_index = 10
	_start.pressed.connect(_begin)
	_start.set_meta("pad_default", true)
	add_child(_start)
	_refresh()


func refresh_top() -> void:
	pass


func _begin() -> void:
	var theo: bool = hub != null and hub.state.has("theo_vote")
	var hr: bool = hub != null and hub.state.has("hr_badge")
	pitch = Pitch.new(-1, theo, hr)
	_start.visible = false
	sfx("ding")
	if theo:
		banner("THEO VOTES YES!", 1.6, Color(0.5, 1.0, 0.6))
	_refresh()


func _answer(i: int) -> void:
	if pitch == null or pitch.done():
		return
	var name: String = pitch.member().name
	var ok := pitch.answer(i)
	sfx("cheer" if ok else "groan", -4.0)
	banner("%s:\n%s" % [name, "YES." if ok else "NO."], 1.2, Color(0.5, 1.0, 0.6) if ok else Color(1.0, 0.5, 0.4))
	if pitch.done():
		if pitch.won():
			if hub and not hub.state.is_done("pitch"):
				hub.pitch_won()
			sfx("fanfare")
			banner("GREENLIT!\nTHE CORNER OFFICE\nIS OPEN", 3.5, Color(0.5, 1.0, 0.6))
			_start.text = "PITCH AGAIN"
		else:
			sfx("sad_trombone", -4.0)
			banner("PASS.\nTRY AGAIN.", 2.5, Color(1.0, 0.5, 0.4))
			_start.text = "PITCH AGAIN"
		_start.visible = true
	_refresh()


func _refresh() -> void:
	for c in _hand.get_children():
		c.queue_free()
	var helpers: Array[String] = []
	if hub and hub.state.has("theo_vote"):
		helpers.append("THEO'S VOTE")
	if hub and hub.state.has("hr_badge"):
		helpers.append("HR BADGE")
	_helpers.text = "ON YOUR SIDE: " + ", ".join(helpers) if not helpers.is_empty() else "MATCH EACH OBJECTION. YES, AND MATCHES ANYTHING."
	_redraw.visible = pitch != null and pitch.redraws > 0 and not pitch.done()
	if pitch == null or pitch.done():
		_who.text = "THE BOARD IS WAITING" if pitch == null else ("GREENLIT" if pitch.won() else "THE BOARD PASSED")
		_line.text = "Five board members. Each one has a worry. Answer it." if pitch == null else ""
		_votes.queue_redraw()
		return
	var m := pitch.member()
	_who.text = "%s  [%s]" % [m.name, m.kind]
	_line.text = "\"%s\"" % m.line
	for i in pitch.hand.size():
		var c: Dictionary = pitch.hand[i]
		var wild: bool = c.kind == Pitch.WILD
		var b := button("%s\n%s" % ["WILD" if wild else c.kind, c.text], 24, Color(0.35, 0.2, 0.05) if wild else Color(0.1, 0.16, 0.32))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 130)
		b.pressed.connect(_answer.bind(i))
		_hand.add_child(b)
	_votes.queue_redraw()


func _draw_votes() -> void:
	var n := Pitch.BOARD.size()
	var gap := _votes.size.x / n
	var votes: Array = pitch.votes if pitch else []
	for i in n:
		var c := Vector2(gap * (i + 0.5), 35)
		var col := Color(0.3, 0.3, 0.4)
		if i < votes.size():
			col = Color(0.4, 1.0, 0.5) if votes[i] else Color(1.0, 0.4, 0.35)
		_votes.draw_circle(c, 28, col)
		_votes.draw_arc(c, 28, 0, TAU, 20, Color.WHITE, 3)
	if pitch and pitch.ally:
		_votes.draw_string(FONT, Vector2(0, 90), "+1 YES FROM THEO", HORIZONTAL_ALIGNMENT_CENTER, _votes.size.x, 18, Color(0.5, 1.0, 0.6))
