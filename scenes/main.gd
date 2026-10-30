extends Control
## The playable game: a run of sets, played by tapping cards.
## Upright screen = phone layout (stage above hand).
## Sideways screen = Steam layout (stage beside hand).
## All rules live in res://engine/; this script only draws state and forwards taps.

const MIN_TOUCH_HEIGHT := 88.0
const CARD_HEIGHT := 200.0
const HAND_COLUMNS := 3

const COLOR_PUNCHLINE := Color(0.80, 0.42, 0.12)
const COLOR_SETUP := Color(0.48, 0.28, 0.66)
const COLOR_ENERGY := Color(0.20, 0.55, 0.32)
const COLOR_UTILITY := Color(0.17, 0.45, 0.55)
const COLOR_LAUGHS := Color(0.22, 0.36, 0.68)
const COLOR_HOT := Color(1.0, 0.45, 0.2)
const COLOR_COLD := Color(0.45, 0.65, 1.0)
const COLOR_GOLD := Color(1.0, 0.85, 0.3)

var _run: Run
var _battle: Battle

var _safe_margin: MarginContainer
var _body: BoxContainer
var _set_label: Label
var _deck_label: Label
var _audience_label: Label
var _intent_label: Label
var _peek_label: Label
var _bubble_area: Control
var _bubble: PanelContainer
var _bubble_label: Label
var _laugh_label: Label
var _laugh_bar: ProgressBar
var _energy_label: Label
var _energy_bar: ProgressBar
var _hand_grid: GridContainer
var _mic_label: Label
var _end_turn_button: Button
var _overlay: Control
var _overlay_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	_show_title()


# ---------------------------------------------------------------- layout

func _build_ui() -> void:
	_safe_margin = MarginContainer.new()
	_safe_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_safe_margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	_safe_margin.add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	_set_label = _label("", 24)
	_set_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_set_label)
	_deck_label = _label("", 20, Color(1, 1, 1, 0.6))
	top.add_child(_deck_label)

	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	root.add_child(_body)

	_body.add_child(_build_stage())
	_body.add_child(_build_hand_area())

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	_overlay_box = VBoxContainer.new()
	_overlay_box.add_theme_constant_override("separation", 20)
	_overlay_box.custom_minimum_size = Vector2(640, 0)
	center.add_child(_overlay_box)


func _build_stage() -> Control:
	var stage := _panel(Color(0.20, 0.10, 0.26))
	stage.size_flags_stretch_ratio = 1.2
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	stage.add_child(box)

	_audience_label = _label("", 34)
	_audience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_audience_label)
	_intent_label = _label("", 22, Color(1, 0.6, 0.6))
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_intent_label)
	_peek_label = _label("", 18, Color(1, 0.8, 0.8, 0.7))
	_peek_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_peek_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_peek_label)

	# Speech bubble and floating numbers.
	_bubble_area = Control.new()
	_bubble_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bubble_area.custom_minimum_size = Vector2(0, 120)
	box.add_child(_bubble_area)
	var bubble_center := CenterContainer.new()
	bubble_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bubble_area.add_child(bubble_center)
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", _box_style(Color(0.96, 0.95, 0.9), 24, 16))
	bubble_center.add_child(_bubble)
	_bubble_label = _label("", 26, Color(0.1, 0.08, 0.12))
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(420, 0)
	_bubble.add_child(_bubble_label)
	_bubble.modulate.a = 0.0

	_laugh_label = _label("", 24, COLOR_GOLD)
	box.add_child(_laugh_label)
	_laugh_bar = _bar(COLOR_GOLD)
	box.add_child(_laugh_bar)
	_energy_label = _label("", 24)
	box.add_child(_energy_label)
	_energy_bar = _bar(COLOR_HOT)
	_energy_bar.max_value = Balance.MAX_CROWD_ENERGY
	box.add_child(_energy_bar)
	return stage


func _build_hand_area() -> Control:
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 1.0
	side.add_theme_constant_override("separation", 12)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	_hand_grid = GridContainer.new()
	_hand_grid.columns = HAND_COLUMNS
	_hand_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_grid.add_theme_constant_override("h_separation", 10)
	_hand_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_hand_grid)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	side.add_child(controls)
	_mic_label = _label("", 28)
	_mic_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(_mic_label)
	_end_turn_button = _button("End Turn", Color(0.55, 0.15, 0.2))
	_end_turn_button.custom_minimum_size = Vector2(260, MIN_TOUCH_HEIGHT)
	_end_turn_button.pressed.connect(_on_end_turn)
	controls.add_child(_end_turn_button)
	return side


func is_landscape() -> bool:
	var s := get_window().size
	return s.x > s.y


func _on_resized() -> void:
	var landscape := is_landscape()
	# Same pixel budget both ways round, so text stays readable sideways too.
	var base := Vector2i(1280, 720) if landscape else Vector2i(720, 1280)
	if get_window().content_scale_size != base:
		get_window().content_scale_size = base
	_body.vertical = not landscape
	_apply_safe_area()


func _apply_safe_area() -> void:
	# Convert the device's safe area (screen pixels) into viewport units so the
	# UI stays clear of notches and home bars. Desktop/web just get a base margin.
	var base := 20.0
	var left := base
	var top := base
	var right := base
	var bottom := base
	if OS.has_feature("mobile"):
		var window_size := Vector2(DisplayServer.window_get_size())
		var view_size := get_viewport_rect().size
		if window_size.x > 0 and window_size.y > 0:
			var to_view := view_size / window_size
			var safe := Rect2(DisplayServer.get_display_safe_area())
			left += safe.position.x * to_view.x
			top += safe.position.y * to_view.y
			right += (window_size.x - safe.end.x) * to_view.x
			bottom += (window_size.y - safe.end.y) * to_view.y
	_safe_margin.add_theme_constant_override("margin_left", int(left))
	_safe_margin.add_theme_constant_override("margin_top", int(top))
	_safe_margin.add_theme_constant_override("margin_right", int(right))
	_safe_margin.add_theme_constant_override("margin_bottom", int(bottom))


# ---------------------------------------------------------------- flow

func _show_title() -> void:
	_open_overlay()
	_overlay_box.add_child(_centered(_label("YES AND", 72, COLOR_GOLD)))
	var how := _label("Tap cards to tell jokes and fill the Laugh meter.\n" +
		"Keep the Crowd Energy up: if it hits zero, you lose the room.\n" +
		"Beat 3 crowds, then headline against The Critic.", 24)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_box.add_child(how)
	var start := _button("Start your set", COLOR_PUNCHLINE)
	start.pressed.connect(_new_run)
	_overlay_box.add_child(start)


func _new_run() -> void:
	_run = Run.new(randi())
	_start_set()


func _start_set() -> void:
	_close_overlay()
	_battle = _run.start_set()
	_say("Is this thing on?", Color(0.96, 0.95, 0.9))
	_laugh_bar.value = 0
	_refresh()


func _on_card_pressed(index: int) -> void:
	if not _battle.can_play(index):
		return
	var card := _battle.hand[index]
	var before_laughs := _battle.laughs
	var before_energy := _battle.crowd_energy
	_battle.play_card(index)
	var gained := _battle.laughs - before_laughs
	var energy := _battle.crowd_energy - before_energy
	_say("\"%s\"" % card.line, Color(0.96, 0.95, 0.9))
	if gained > 0:
		_float_text("+%d" % gained, COLOR_GOLD, gained >= 12)
	if energy != 0:
		_float_text("%+d energy" % energy, COLOR_ENERGY.lightened(0.4) if energy > 0 else COLOR_HOT, false, 50)
	_refresh()
	_check_result()


func _on_end_turn() -> void:
	if _battle == null or _battle.result != Battle.Result.ONGOING:
		return
	var seen := _battle.history.size()
	var before_energy := _battle.crowd_energy
	_battle.end_turn()
	var lines := _battle.history.slice(seen)
	var crowd_lines: Array[String] = []
	for line in lines:
		if not line.begins_with("The room") and not line.begins_with("You lost"):
			crowd_lines.append(line.trim_prefix(_battle.audience.title + ": "))
	_say("\n".join(crowd_lines), Color(1, 0.82, 0.82))
	var lost := _battle.crowd_energy - before_energy
	if lost < 0:
		_float_text("%d energy" % lost, COLOR_HOT, false, 50)
		_flash(_energy_bar)
	_refresh()
	_check_result()


func _check_result() -> void:
	match _battle.result:
		Battle.Result.WON:
			_end_turn_button.disabled = true
			await get_tree().create_timer(0.9).timeout
			if _run.is_final_set():
				_show_run_won()
			else:
				_show_reward()
		Battle.Result.LOST:
			_end_turn_button.disabled = true
			await get_tree().create_timer(0.9).timeout
			_show_lost()


func _show_reward() -> void:
	_open_overlay()
	_overlay_box.add_child(_centered(_label("YOU KILLED!", 60, COLOR_GOLD)))
	_overlay_box.add_child(_centered(_label("Add a new bit to your act:", 26)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_overlay_box.add_child(row)
	for card in _run.reward_choices():
		var widget := _card_widget(card, -1, true)
		widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		widget.custom_minimum_size.y = CARD_HEIGHT + 30
		widget.pressed.connect(_take_reward.bind(card))
		row.add_child(widget)
	var skip := _button("Skip", Color(0.3, 0.3, 0.35))
	skip.pressed.connect(_take_reward.bind(null))
	_overlay_box.add_child(skip)


func _take_reward(card: CardData) -> void:
	_run.finish_set(card)
	_show_next_up()


func _show_next_up() -> void:
	_open_overlay()
	var next := _run.current_audience()
	var heading := "HEADLINE SHOW" if next.is_boss else "NEXT SET"
	_overlay_box.add_child(_centered(_label(heading, 48, COLOR_GOLD)))
	_overlay_box.add_child(_centered(_label(next.title, 36)))
	_overlay_box.add_child(_centered(_label("Laughs needed: %d    Deck: %d cards" % [next.laughs_needed, _run.deck.size()], 24)))
	var go := _button("Take the stage", COLOR_PUNCHLINE)
	go.pressed.connect(_start_set)
	_overlay_box.add_child(go)


func _show_lost() -> void:
	_open_overlay()
	_overlay_box.add_child(_centered(_label("YOU LOST THE ROOM", 52, COLOR_HOT)))
	_overlay_box.add_child(_centered(_label("%s.  Set %d of %d.  Laughs %d / %d" % [
		_battle.audience.title, _run.set_index + 1, _run.lineup.size(), _battle.laughs, _battle.laughs_needed], 24)))
	var again := _button("Try again", COLOR_PUNCHLINE)
	again.pressed.connect(_new_run)
	_overlay_box.add_child(again)


func _show_run_won() -> void:
	_open_overlay()
	_overlay_box.add_child(_centered(_label("STANDING OVATION!", 56, COLOR_GOLD)))
	_overlay_box.add_child(_centered(_label("Even The Critic laughed. You're a headliner.", 26)))
	var again := _button("Play again", COLOR_PUNCHLINE)
	again.pressed.connect(_new_run)
	_overlay_box.add_child(again)


# ---------------------------------------------------------------- drawing

func _refresh() -> void:
	var b := _battle
	_set_label.text = "Set %d of %d" % [_run.set_index + 1, _run.lineup.size()]
	_deck_label.text = "Draw %d   Discard %d" % [b.draw_pile.size(), b.discard_pile.size()]
	_audience_label.text = b.audience.title
	var intent := b.current_intent()
	_intent_label.text = "Crowd's next move: %s" % (intent.text if intent else "nothing")
	var peek := b.next_intent()
	_peek_label.text = "After that: %s" % peek.text if b.next_intent_revealed and peek else ""

	_laugh_label.text = "LAUGHS  %d / %d" % [b.laughs, b.laughs_needed]
	_laugh_bar.max_value = b.laughs_needed
	create_tween().tween_property(_laugh_bar, "value", float(mini(b.laughs, b.laughs_needed)), 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var mult := b.laugh_multiplier()
	var mood := "  HOT! laughs x%.1f" % mult if mult > 1.0 else ("  COLD: laughs x%.2f" % mult if mult < 1.0 else "")
	_energy_label.text = "CROWD ENERGY  %d / %d%s" % [b.crowd_energy, Balance.MAX_CROWD_ENERGY, mood]
	_energy_label.add_theme_color_override("font_color",
		COLOR_HOT if mult > 1.0 else (COLOR_COLD if mult < 1.0 else Color.WHITE))
	_energy_bar.value = b.crowd_energy
	var fill := _energy_bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = COLOR_HOT if mult > 1.0 else (COLOR_COLD if mult < 1.0 else COLOR_ENERGY.lightened(0.2))

	_mic_label.text = "MIC TIME  %d / %d" % [b.mic, Balance.MIC_PER_TURN]
	_end_turn_button.disabled = b.result != Battle.Result.ONGOING

	for child in _hand_grid.get_children():
		child.queue_free()
	for i in b.hand.size():
		var card := b.hand[i]
		var widget := _card_widget(card, b.laughs_for(card), b.can_play(i))
		widget.pressed.connect(_on_card_pressed.bind(i))
		_hand_grid.add_child(widget)


func _card_widget(card: CardData, preview: int, playable: bool) -> Button:
	var color := _card_color(card)
	var button := _button("", color)
	button.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not playable

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	button.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var cost := _label(str(card.cost), 26, COLOR_GOLD)
	head.add_child(cost)
	var title := _label(card.title, 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 40
	head.add_child(title)

	var rules := _label(card.rules, 19, Color(1, 1, 1, 0.85))
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules.custom_minimum_size.x = 40
	box.add_child(rules)

	if preview > 0:
		box.add_child(_label("+%d laughs" % preview, 22, COLOR_GOLD))
	if not playable:
		button.modulate = Color(1, 1, 1, 0.45)
	return button


func _card_color(card: CardData) -> Color:
	if card.is_punchline:
		return COLOR_PUNCHLINE
	if card.setups > 0:
		return COLOR_SETUP
	if card.crowd_energy > 0 and card.laughs == 0:
		return COLOR_ENERGY
	if card.laughs == 0 and card.laughs_per_card_this_set == 0 and card.laughs_per_card_this_turn == 0:
		return COLOR_UTILITY
	return COLOR_LAUGHS


func _say(text: String, color: Color) -> void:
	_bubble.get_theme_stylebox("panel").bg_color = color
	_bubble_label.text = text
	_bubble.visible = text != ""
	_bubble.modulate.a = 0.0
	_bubble.scale = Vector2(0.85, 0.85)
	await get_tree().process_frame
	_bubble.pivot_offset = _bubble.size / 2
	var t := create_tween().set_parallel()
	t.tween_property(_bubble, "modulate:a", 1.0, 0.15)
	t.tween_property(_bubble, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _float_text(text: String, color: Color, big: bool, offset_y := 0.0) -> void:
	var label := _label(text, 64 if big else 44, color)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_bubble_area.add_child(label)
	await get_tree().process_frame
	label.position = Vector2(_bubble_area.size.x - label.size.x - 10, offset_y)
	var t := create_tween().set_parallel()
	t.tween_property(label, "position:y", label.position.y - 60, 0.9).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	t.chain().tween_callback(label.queue_free)


func _flash(node: CanvasItem) -> void:
	node.modulate = Color(2, 0.6, 0.6)
	create_tween().tween_property(node, "modulate", Color.WHITE, 0.4)


func _open_overlay() -> void:
	for child in _overlay_box.get_children():
		child.queue_free()
	_overlay.visible = true
	_overlay_box.custom_minimum_size.x = minf(640, get_viewport_rect().size.x - 60)


func _close_overlay() -> void:
	_overlay.visible = false


# ---------------------------------------------------------------- widgets

func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, MIN_TOUCH_HEIGHT)
	button.add_theme_font_size_override("font_size", 30)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _box_style(color, 14))
	button.add_theme_stylebox_override("hover", _box_style(color.lightened(0.15), 14))
	button.add_theme_stylebox_override("pressed", _box_style(color.darkened(0.2), 14))
	button.add_theme_stylebox_override("disabled", _box_style(color.darkened(0.3), 14))
	return button


func _panel(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box_style(color, 18, 18))
	return panel


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 30)
	bar.add_theme_stylebox_override("background", _box_style(Color(0, 0, 0, 0.4), 10))
	bar.add_theme_stylebox_override("fill", _box_style(color, 10))
	return bar


func _box_style(color: Color, radius: int, padding := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style
