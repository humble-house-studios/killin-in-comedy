extends "res://scenes/ladder/machine.gd"
## The prize counter: spend tickets on the DOOR KEY (opens the trading floor)
## and on gifts your coworkers want. The petty-cash jar refills you when
## you're out of tokens, so you can never get stuck. Below, YOUR STUFF lists
## what you own, the perks coworkers gave you and the secrets they told you.

var _list: VBoxContainer
var _stuff: Label


func _ready() -> void:
	super._ready()
	frame("PRIZE COUNTER", Color(0.1, 0.06, 0.02), Color(1.0, 0.8, 0.3))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 160)
	scroll.size = Vector2(W - 48, H - 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)
	refresh()


func set_active(on: bool) -> void:
	super.set_active(on)
	if on:
		refresh()


func refresh() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	refresh_top()
	var given: Array = hub.crew.gifted if hub else []
	for p in LadderState.PRIZES:
		var owned: bool = hub != null and hub.state.has(p.id)
		var gone: bool = p.has("for") and given.has(p["for"])
		var text := "%s - %d\n%s" % [p.name, p.cost, p.note]
		if owned:
			text = "%s - OWNED\n%s" % [p.name, "Give it to %s" % Coworkers.person(p["for"]).name if p.has("for") else p.note]
		elif gone:
			text = "%s - GIVEN\n%s has it now" % [p.name, Coworkers.person(p["for"]).name]
		var b := button(text, 22, Color(0.35, 0.22, 0.05) if p.id == "door_key" else Color(0.2, 0.14, 0.08))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 130)
		b.disabled = owned or gone or hub == null or not hub.state.can_buy(p.id, given)
		b.pressed.connect(_buy.bind(p.id))
		if p.id == "door_key":
			b.set_meta("pad_default", true)
		_list.add_child(b)
	var petty := button("PETTY CASH JAR\n+%d tokens when you're out" % LadderState.PETTY_CASH, 22, Color(0.1, 0.25, 0.12))
	petty.alignment = HORIZONTAL_ALIGNMENT_LEFT
	petty.custom_minimum_size = Vector2(0, 130)
	petty.disabled = hub == null or hub.state.tokens > 0
	petty.pressed.connect(_petty)
	_list.add_child(petty)
	_stuff = label(_stuff_text(), 20, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	_stuff.custom_minimum_size = Vector2(W - 60, 0)
	_list.add_child(_stuff)


func _stuff_text() -> String:
	if hub == null:
		return ""
	var lines: Array[String] = ["YOUR STUFF"]
	var perks := {"gloria_eye": "GLORIA'S EYE", "insider_tip": "INSIDER TIP", "hr_badge": "HR BADGE", "style": "STYLE x2",
		"theo_vote": "THEO'S VOTE", "archive_key": "ARCHIVE KEY"}
	var have: Array[String] = []
	for k in perks:
		if hub.state.has(k):
			have.append(perks[k])
	lines.append("PERKS: " + (", ".join(have) if not have.is_empty() else "none yet. Talk to people."))
	lines.append("MACHINES BEATEN: %d/3" % hub.state.beaten.size())
	var secrets: Array[String] = hub.crew.secret_texts()
	lines.append("\nSECRETS %d/%d" % [secrets.size(), LadderState.SECRETS_TOTAL])
	for s in secrets:
		lines.append("- " + s)
	return "\n".join(lines)


func _buy(id: String) -> void:
	if hub and hub.buy(id):
		sfx("fanfare" if id == "door_key" else "chime")
		banner("DOOR KEY!\nTHE DOOR IS OPEN" if id == "door_key" else LadderState.prize(id).name + "!", 2.4)
	refresh()


func _petty() -> void:
	if hub and hub.state.petty_cash() > 0:
		sfx("coin")
		banner("+%d TOKENS" % LadderState.PETTY_CASH, 1.4)
	refresh()
