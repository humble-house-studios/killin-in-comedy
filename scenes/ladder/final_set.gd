extends "res://scenes/ladder/machine.gd"
## The open mic at the end of the ladder. Five picks from your material, 100
## laughs to land the set (FinalSet). A Setup doubles the next Punchline; Tags
## right after a Punchline land at x1.5. Your coworkers' secrets are killer
## bits, and the founder's memo gives you BIG DEAL. Landing it finishes the
## ladder; a rough set can always go again.

var set_rules: FinalSet
var _meter: Control
var _last: Label
var _hand: GridContainer
var _start: Button


func _ready() -> void:
	super._ready()
	frame("OPEN MIC", Color(0.06, 0.02, 0.06), Color(1.0, 0.35, 0.7))
	_top.text = "FIVE BITS. 100 LAUGHS."
	_meter = Control.new()
	_meter.position = Vector2(40, 160)
	_meter.size = Vector2(W - 80, 90)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.draw.connect(_draw_meter)
	add_child(_meter)
	_last = label("", 24, Color(1, 1, 1, 0.9))
	_last.position = Vector2(30, 270)
	_last.size = Vector2(W - 60, 150)
	add_child(_last)
	_hand = GridContainer.new()
	_hand.columns = 2
	_hand.position = Vector2(24, 430)
	_hand.size = Vector2(W - 48, 820)
	_hand.add_theme_constant_override("h_separation", 12)
	_hand.add_theme_constant_override("v_separation", 12)
	add_child(_hand)
	_start = button("TAKE THE STAGE", 36, Color(0.5, 0.08, 0.3))
	_start.position = Vector2(60, 700)
	_start.size = Vector2(W - 120, 160)
	_start.z_index = 10
	_start.pressed.connect(_begin)
	_start.set_meta("pad_default", true)
	add_child(_start)
	_last.text = "Setup, then Punchline: x2.\nTags after a Punchline: x1.5.\nSecrets make the best bits."


func refresh_top() -> void:
	pass


func _begin() -> void:
	var secrets: Array = hub.crew.secrets if hub else []
	var memo: bool = hub != null and hub.state.is_done("memo")
	set_rules = FinalSet.new(secrets, memo)
	_start.visible = false
	_last.text = "The light's on you. Go."
	sfx("applause", -6.0)
	_refresh()


func _play(id: String) -> void:
	if set_rules == null or set_rules.done():
		return
	var card := {}
	for c in set_rules.hand:
		if c.id == id:
			card = c
	var score := set_rules.play(id)
	_last.text = "\"%s\"\n+%d LAUGHS%s" % [card.text, roundi(score), "  " + set_rules.last_reason if set_rules.last_reason != "" else ""]
	sfx("laugh_huge" if score >= 50 else ("laugh_big" if score >= 25 else "laugh_small"), -4.0)
	if set_rules.won():
		sfx("applause")
		banner("YOU KILLED!", 3.0)
		if hub:
			hub.stage_won()
		_start.text = "ENCORE"
		_start.visible = true
	elif set_rules.lost():
		sfx("sad_trombone", -4.0)
		banner("TOUGH ROOM.\nGO AGAIN.", 2.5, Color(1.0, 0.5, 0.4))
		_start.text = "GO AGAIN"
		_start.visible = true
	_refresh()


func _refresh() -> void:
	for c in _hand.get_children():
		c.queue_free()
	_meter.queue_redraw()
	if set_rules == null or set_rules.done():
		return
	for c in set_rules.hand:
		var special: bool = FinalSet.SECRET_BITS.has(c.id) or c.id == "memo"
		var beat: String = {"setup": "SETUP", "punch": "PUNCHLINE", "tag": "TAG"}.get(c.beat, "BIT")
		var b := button("%s\n%s %d" % [c.name, beat, c.laughs], 20, Color(0.45, 0.25, 0.05) if special else Color(0.2, 0.08, 0.2))
		b.custom_minimum_size = Vector2(0, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_play.bind(c.id))
		_hand.add_child(b)


func _draw_meter() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(_meter.size.x, 50))
	_meter.draw_rect(r, Color(0.15, 0.05, 0.15))
	var laughs := set_rules.laughs if set_rules else 0.0
	_meter.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(laughs / FinalSet.TARGET, 0.0, 1.0), r.size.y)), Color(1.0, 0.35, 0.7))
	_meter.draw_rect(r, Color.WHITE, false, 3.0)
	var picks := set_rules.picks_left() if set_rules else FinalSet.PICKS
	_meter.draw_string(FONT, Vector2(0, 82), "LAUGHS %d/%d    BITS LEFT %d" % [roundi(laughs), FinalSet.TARGET, picks], HORIZONTAL_ALIGNMENT_CENTER, _meter.size.x, 22, Color(1.0, 0.92, 0.55))
