extends Control
## The playable game: a run of sets, played by tapping cards.
## Upright screen = phone layout (stage above hand).
## Sideways screen = Steam layout (stage beside hand).
## All rules live in res://engine/; this script only draws state and forwards taps.
## The set is live: _process() ticks the battle every frame (unless paused).
## Look: 8-bit arcade. Pixel fonts, square panels with thick outlines and hard
## shadows, a pixel-art stage, and an old-TV filter (crt.gdshader) on top.

const MIN_TOUCH_HEIGHT := 88.0
const CARD_HEIGHT := 214.0
const HAND_COLUMNS := 3

const COLOR_PUNCHLINE := Color(0.80, 0.42, 0.12)
const COLOR_SETUP := Color(0.48, 0.28, 0.66)
const COLOR_ENERGY := Color(0.20, 0.55, 0.32)
const COLOR_UTILITY := Color(0.17, 0.45, 0.55)
const COLOR_LAUGHS := Color(0.22, 0.36, 0.68)
const COLOR_HOT := Color(1.0, 0.45, 0.2)
const COLOR_COLD := Color(0.45, 0.65, 1.0)
const COLOR_GOLD := Color(1.0, 0.85, 0.3)
const COLOR_NEON := Color(1.0, 0.35, 0.7)
const COLOR_NEON_BLUE := Color(0.35, 0.85, 1.0)
const COLOR_PAPER := Color(0.97, 0.94, 0.85)
const COLOR_INK := Color(0.16, 0.12, 0.10)
## Outline colour for every panel, card and button.
const COLOR_OUTLINE := Color(0.04, 0.02, 0.07)
const OUTLINE := 4
const CROWD_SIZES := {"open_mic": 6, "the_critic": 7}

var _run: Run
var _patter: Patter
var _battle: Battle
var _sound: Sound
## Bold Pixelify Sans: card titles and short labels.
var _heading_font: FontVariation
## Press Start 2P: signs, big numbers and buttons. Wide, so short text only.
var _pixel_font: FontFile
var _crt_mat: ShaderMaterial
var _stage_view: StageView
## Top layer of the stage for floating numbers.
var _fx_layer: Control
var _stage_mat: ShaderMaterial
var _mute_button: Button

const SafeArea := preload("res://scenes/safe_area.gd")
var _safe_margin: MarginContainer
var _last_inset := Vector4.ZERO
var _safe_applied := false
var _body: BoxContainer
var _set_label: Label
var _deck_label: Label
var _audience_label: Label
var _intent_label: Label
var _peek_label: Label
var _taste_label: Label
var _bit_label: Label
var _clock_label: Label
var _bubble_area: Control
var _bubble: PanelContainer
var _bubble_label: Label
var _laugh_label: Label
var _laugh_bar: ProgressBar
var _energy_label: Label
var _hand_grid: GridContainer
var _mic_label: Label
var _end_turn_button: Button
var _overlay: Control
var _overlay_box: VBoxContainer
var _room_chart: RoomChart
var _mic_bar: ProgressBar
var _pause_button: Button
var _paused := false
## Whole mic points last drawn, so the hand only redraws when playability changes.
var _mic_whole := -1
## The laugh counter on screen, rolling up toward the real total.
var _shown_laughs := 0.0
## What was said for each card in the bit being built: {card, line}.
var _bit_lines: Array = []
## Card objects in hand last drawn, to pop in only the new ones.
var _hand_shown: Array = []
## Full-screen layer for coins and numbers that fly between parts of the screen.
var _top_fx: Control
## Laughs still flying toward the meter as coins; the counter waits for them.
var _in_flight := 0
## The big centre text of a landing payout (one slot, so it never piles up).
var _slam: Label
## The clock waits for the first joke of each set.
var _started := false
## The coach: one line of help above the hand.
var _coach: PanelContainer
var _coach_label: Label
var _tips_seen := {}
var _tip_queue: Array = []
var _tip_text := ""
var _tip_left := 0.0
var _coach_time := 0.0
var _ha_clock := 0.0
## Laugh-meter milestones already celebrated this set (25, 50, 75).
var _milestones := {}
const TIPS_PATH := "user://tips.cfg"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sound = Sound.new()
	add_child(_sound)
	_pixel_font = _crisp_font("res://fonts/press_start_2p.ttf")
	var body := FontVariation.new()
	body.base_font = _crisp_font("res://fonts/pixelify_sans.ttf")
	body.variation_opentype = {"wght": 500}
	# Pixelify's "fi" ligature draws as a lone "A", so ligatures are off.
	body.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("liga"): 0}
	_heading_font = FontVariation.new()
	_heading_font.base_font = body.base_font
	_heading_font.variation_opentype = {"wght": 700}
	_heading_font.opentype_features = body.opentype_features
	theme = Theme.new()
	theme.default_font = body
	_build_ui()
	# Controller / arrow keys: a frame that moves between buttons, A presses.
	var pad := preload("res://scenes/pad_cursor.gd").new()
	pad.guide = [["DPAD", "Pick a card"], ["A", "Tell the joke"], ["X", "LAND IT: cash in the bit"], ["START", "Pause"]]
	add_child(pad)
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	# The phone reports its safe area a moment after it turns; re-check twice a second.
	if OS.has_feature("web") and _owns_window():
		var poll := Timer.new()
		poll.wait_time = 0.5
		poll.autostart = true
		poll.timeout.connect(_apply_safe_area)
		add_child(poll)
	_show_title()


# ---------------------------------------------------------------- layout

func _build_ui() -> void:
	add_child(_shader_rect(preload("res://scenes/club.gdshader")))

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
	_mute_button = _button("", Color(0.2, 0.15, 0.25))
	_mute_button.custom_minimum_size = Vector2(150, MIN_TOUCH_HEIGHT * 0.75)
	_mute_button.add_theme_font_size_override("font_size", 22)
	_mute_button.add_theme_font_override("font", _heading_font)
	_mute_button.pressed.connect(_on_mute)
	top.add_child(_mute_button)
	_update_mute_label()
	_pause_button = _button("II", Color(0.2, 0.15, 0.25))
	_pause_button.custom_minimum_size = Vector2(96, MIN_TOUCH_HEIGHT * 0.75)
	_pause_button.pressed.connect(_on_pause)
	_pause_button.set_meta("pad_button", JOY_BUTTON_START)
	top.add_child(_pause_button)

	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	root.add_child(_body)

	_body.add_child(_build_stage())
	_body.add_child(_build_hand_area())

	_top_fx = Control.new()
	_top_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_fx)
	_load_tips()

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.04, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	_overlay_box = VBoxContainer.new()
	_overlay_box.add_theme_constant_override("separation", 20)
	_overlay_box.custom_minimum_size = Vector2(640, 0)
	center.add_child(_overlay_box)

	var crt := _shader_rect(preload("res://scenes/crt.gdshader"))
	_crt_mat = crt.material
	# A shader setting must exist before it can be tweened (for screen shake).
	_crt_mat.set_shader_parameter("shake", Vector2.ZERO)
	add_child(crt)


func _build_stage() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.2
	column.add_theme_constant_override("separation", 10)

	# The club stage: shader backdrop, mic + crowd drawing, then text on top.
	var stage := PanelContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	column.add_child(stage)
	var backdrop := _shader_rect(preload("res://scenes/stage.gdshader"))
	_stage_mat = backdrop.material
	stage.add_child(backdrop)
	_stage_view = StageView.new()
	stage.add_child(_stage_view)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	margin.add_theme_constant_override("margin_top", 26)
	stage.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	_audience_label = _neon("", 32, COLOR_NEON)
	box.add_child(_audience_label)
	_taste_label = _label("", 20, Color(0.85, 1, 0.85))
	_taste_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_taste_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shadow(_taste_label)
	box.add_child(_taste_label)
	_intent_label = _label("", 21, Color(1, 0.75, 0.75))
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shadow(_intent_label)
	_peek_label = _label("", 18, Color(1, 0.85, 0.85, 0.8))
	_peek_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_peek_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shadow(_peek_label)

	# Speech bubble and floating numbers, above the mic.
	_bubble_area = Control.new()
	_bubble_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bubble_area.size_flags_stretch_ratio = 1.0
	_bubble_area.custom_minimum_size = Vector2(0, 110)
	box.add_child(_bubble_area)
	var bubble_center := CenterContainer.new()
	bubble_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bubble_area.add_child(bubble_center)
	_bubble = PanelContainer.new()
	var bubble_style := _box_style(COLOR_PAPER, 16, OUTLINE)
	_hard_shadow(bubble_style, 6)
	_bubble.add_theme_stylebox_override("panel", bubble_style)
	bubble_center.add_child(_bubble)
	_bubble_label = _label("", 25, COLOR_INK)
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(400, 0)
	_bubble.add_child(_bubble_label)
	_bubble.modulate.a = 0.0
	# Room for the mic and the crowd below the bubble.
	var floor_space := Control.new()
	floor_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	floor_space.size_flags_stretch_ratio = 0.9
	box.add_child(floor_space)

	_fx_layer = Control.new()
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_fx_layer)
	var slam_center := CenterContainer.new()
	slam_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	slam_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(slam_center)
	_slam = _label("", 40, COLOR_GOLD)
	_slam.add_theme_font_override("font", _pixel_font)
	_slam.add_theme_constant_override("outline_size", 14)
	_slam.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	_slam.add_theme_color_override("font_shadow_color", COLOR_OUTLINE)
	_slam.add_theme_constant_override("shadow_offset_x", 5)
	_slam.add_theme_constant_override("shadow_offset_y", 5)
	_slam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slam.modulate.a = 0.0
	slam_center.add_child(_slam)

	# Meters under the stage.
	var meters := PanelContainer.new()
	meters.add_theme_stylebox_override("panel", _box_style(Color(0.08, 0.05, 0.12), 12, OUTLINE))
	column.add_child(meters)
	var mbox := VBoxContainer.new()
	mbox.add_theme_constant_override("separation", 4)
	meters.add_child(mbox)
	var laugh_row := HBoxContainer.new()
	mbox.add_child(laugh_row)
	_laugh_label = _label("", 22, COLOR_GOLD)
	_laugh_label.add_theme_font_override("font", _heading_font)
	_laugh_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	laugh_row.add_child(_laugh_label)
	_clock_label = _label("", 26, Color.WHITE)
	_clock_label.add_theme_font_override("font", _pixel_font)
	laugh_row.add_child(_clock_label)
	_laugh_bar = _bar(COLOR_GOLD)
	mbox.add_child(_laugh_bar)
	_energy_label = _label("", 22)
	_energy_label.add_theme_font_override("font", _heading_font)
	mbox.add_child(_energy_label)
	_room_chart = RoomChart.new()
	_room_chart.font = _pixel_font
	_room_chart.max_value = Balance.MAX_CROWD_ENERGY
	mbox.add_child(_room_chart)
	# Ticker under the chart: the crowd's next move, with a countdown.
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_peek_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mbox.add_child(_intent_label)
	mbox.add_child(_peek_label)
	# The bit being built this minute, Balatro-style: laughs × multiplier.
	_bit_label = _label("", 20, COLOR_NEON_BLUE)
	_bit_label.add_theme_font_override("font", _pixel_font)
	_bit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bit_label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	_bit_label.add_theme_constant_override("outline_size", 6)
	mbox.add_child(_bit_label)
	return column


func _build_hand_area() -> Control:
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 1.0
	side.add_theme_constant_override("separation", 12)

	_coach = PanelContainer.new()
	var coach_style := _box_style(Color(0.05, 0.1, 0.18), 10, OUTLINE)
	coach_style.border_color = COLOR_NEON_BLUE
	_coach.add_theme_stylebox_override("panel", coach_style)
	_coach.visible = false
	side.add_child(_coach)
	_coach_label = _label("", 22, Color.WHITE)
	_coach_label.add_theme_font_override("font", _heading_font)
	_coach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach.add_child(_coach_label)

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
	var mic_box := VBoxContainer.new()
	mic_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mic_box.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_child(mic_box)
	_mic_label = _label("", 18)
	_mic_label.add_theme_font_override("font", _pixel_font)
	mic_box.add_child(_mic_label)
	_mic_bar = _bar(COLOR_NEON_BLUE)
	_mic_bar.max_value = Balance.MIC_MAX
	mic_box.add_child(_mic_bar)
	_end_turn_button = _button("Land It", Color(0.62, 0.08, 0.18))
	_end_turn_button.custom_minimum_size = Vector2(330, MIN_TOUCH_HEIGHT)
	_end_turn_button.pressed.connect(_on_end_turn)
	_end_turn_button.set_meta("pad_button", JOY_BUTTON_X)
	controls.add_child(_end_turn_button)
	return side


func is_landscape() -> bool:
	var s := get_viewport_rect().size
	return s.x > s.y


## False when the game runs inside another scene (the office monitor's SubViewport).
func _owns_window() -> bool:
	return get_viewport() == get_window()


func _on_resized() -> void:
	var landscape := is_landscape()
	# Same pixel budget both ways round, so text stays readable sideways too.
	var base := Vector2i(1280, 720) if landscape else Vector2i(720, 1280)
	if _owns_window() and get_window().content_scale_size != base:
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
	if _owns_window():
		var inset := SafeArea.get_insets(get_viewport_rect().size)
		if inset == _last_inset and _safe_applied:
			return
		_last_inset = inset
		left += inset.x
		top += inset.y
		right += inset.z
		bottom += inset.w
	_safe_applied = true
	_safe_margin.add_theme_constant_override("margin_left", int(left))
	_safe_margin.add_theme_constant_override("margin_top", int(top))
	_safe_margin.add_theme_constant_override("margin_right", int(right))
	_safe_margin.add_theme_constant_override("margin_bottom", int(bottom))


# ---------------------------------------------------------------- flow

func _show_title() -> void:
	_open_overlay()
	var sign := _neon("KILLIN' IN", 56, COLOR_NEON)
	_overlay_box.add_child(sign)
	_flicker(sign)
	_overlay_box.add_child(_neon("COMEDY", 64, COLOR_NEON_BLUE))
	var how := _label("It's live! Mic time refills every second, so keep firing jokes.\n" +
		"Cards build a bit. LAND IT to cash in: laughs × the Room × chains.\n" +
		"Setup > Punchline > Tag chains multiply. Tags re-fire the punchline.\n" +
		"Watch the Room line: land at a peak, before a heckle cuts your bit.\n" +
		"Hit the target before the light!", 23)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_box.add_child(how)
	var start := _button("Start your set", COLOR_PUNCHLINE)
	start.pressed.connect(_new_run)
	start.pressed.connect(_sound.start_music)
	start.set_meta("pad_button", JOY_BUTTON_START)
	_overlay_box.add_child(start)


func _new_run() -> void:
	_run = Run.new(randi())
	_patter = Patter.new(randi())
	_show_next_up()


func _start_set() -> void:
	_close_overlay()
	_paused = false
	_battle = _run.start_set()
	_hand_shown = []
	_bit_lines = []
	_mic_whole = -1
	_shown_laughs = 0.0
	_in_flight = 0
	_started = false
	_milestones = {}
	_patter.start_set()
	var crowd: int = CROWD_SIZES.get(_battle.audience.id, 9)
	_stage_view.set_crowd(crowd, _battle.audience.is_boss)
	_sound.play("thump")
	_say(_patter.opener(), COLOR_PAPER)
	_laugh_bar.value = 0
	_refresh()


func _process(delta: float) -> void:
	if _battle == null:
		return
	# Roll the laugh counter toward the real total, like a slot machine. Laughs
	# still flying in as coins aren't counted until they land.
	var target := float(_battle.laughs - _in_flight)
	if _shown_laughs < target:
		_shown_laughs = minf(target, _shown_laughs + maxf(40.0, (target - _shown_laughs) * 6.0) * delta)
	_update_coach(delta)
	_ambient(delta)
	if _battle.result == Battle.Result.ONGOING and not _paused and not _overlay.visible and _started:
		_battle.tick(delta)
		for ev in _battle.pop_events():
			_on_battle_event(ev)
		var whole := int(_battle.mic)
		if whole != _mic_whole:
			_mic_whole = whole
			_refresh()
	_update_live()


func _notification(what: int) -> void:
	# Phone locked or app switched: pause so the light doesn't run out unseen.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _battle and _battle.result == Battle.Result.ONGOING \
			and not _overlay.visible:
		_set_paused(true)


func _on_battle_event(ev: String) -> void:
	match ev:
		"event":
			var line: String = _battle.history.back()
			_say(line.trim_prefix(_battle.audience.title + ": "), Color(1, 0.82, 0.82))
			var intent := _battle.audience.intents[(_battle._intent_index - 1) % _battle.audience.intents.size()]
			match intent.kind:
				IntentData.Kind.SPIKE:
					_sound.play("cheer", -4.0)
					_float_text("+%d HEAT" % intent.amount, COLOR_ENERGY.lightened(0.4), false, true)
					_stage_view.react(0.5)
				IntentData.Kind.CALM:
					pass
				_:
					_sound.play("groan", -4.0)
					_flash(_room_chart)
		"interrupt":
			_float_text("INTERRUPTED! BIT CUT", COLOR_HOT, false, false, 0.25)
			_sound.play("crickets", -2.0)
			_shake(6.0)
			_refresh()
		"landed":
			# The light auto-landed the last bit.
			_cascade()
		"won", "lost":
			_refresh()
			_check_result()


func _on_card_pressed(index: int) -> void:
	if _battle == null or not _battle.can_play(index) or _paused:
		return
	var card := _battle.hand[index]
	var from := _card_center(index)
	if not _started:
		_started = true
		_sound.start_music()
	var linked := _battle.is_linked(card)
	var chained := _battle.chains(card)
	var taste := _battle.taste(card)
	var before_laughs := _battle.bit_laughs
	var before_energy := _battle.crowd_energy
	_battle.play_card(index)
	var gained := _battle.bit_laughs - before_laughs
	var energy := int(round(_battle.crowd_energy - before_energy))
	var line := _patter.line_for(card, _battle.audience.id)
	# Stage directions (*sips water*) aren't speech, so no quote marks.
	line = line if line.begins_with("*") else "\"%s\"" % line
	_bit_lines.append({"card": card, "line": line, "laughs": gained})
	_say(line, COLOR_PAPER)
	_play_reaction(card, gained, energy)
	if gained > 0:
		_fling_to_pot(gained, from)
	if chained:
		_float_text("CHAIN! ×%.1f" % _battle.chain_multiplier(), COLOR_NEON, false, false, 0.22)
		_sound.play("chime", 0.0, 1.0 + 0.12 * _battle.chain_links)
		_ding_run(2 + _battle.chain_links, 1.1)
		_stage_view.react(0.6)
		_tip("chain", "CHAIN! Setup → Punchline → Tag each multiply the whole bit ×1.5. Keep it going!")
	elif linked:
		_float_text("LINK!", COLOR_NEON_BLUE, false, false, 0.30)
		_sound.play("chime")
	if card.is_joke() and _battle.cards_played_this_bit == 1:
		_tip("land", "Nice! Jokes stack up into a BIT. Add more, then tap LAND IT to cash in.", 99.0)
	if taste > 0:
		_float_text("THEY LOVE %s!" % CardData.TOPIC_NAMES[card.topic].to_upper(), Color(0.6, 1, 0.6), false, false, 0.38)
	elif taste < 0:
		_float_text("GROAN...", COLOR_COLD, false, false, 0.38)
		_sound.play_later("groan", 0.2, -4.0)
	if energy != 0:
		_float_text("%+d Heat" % energy, COLOR_ENERGY.lightened(0.4) if energy > 0 else COLOR_HOT, false, true)
	_refresh()
	for ev in _battle.pop_events():
		_on_battle_event(ev)


func _on_end_turn() -> void:
	if _battle == null or _battle.result != Battle.Result.ONGOING or _paused or not _battle.bit_open():
		return
	_battle.land_bit()
	for ev in _battle.pop_events():
		_on_battle_event(ev)


## The landing, casino-style. Ding ding ding: every joke in the bit pops up
## in a row with a rising pitch, each multiplier slams in by name (so you see
## WHY it got big), the total spins up, a NICE / BIG LAUGH / HUGE / JACKPOT
## banner hits, and the payout showers into the laugh meter as coins.
func _cascade() -> void:
	var b := _battle
	var jokes := b.landed_jokes.duplicate()
	var score := b.last_landed
	var lines := _bit_lines.duplicate()
	_bit_lines = []
	# Hold the counter back until the coins arrive.
	_in_flight += score
	_refresh()
	_bubble.modulate.a = 0.0
	_sound.play("thump", -4.0)
	var area := _fx_layer.get_global_rect()

	# 1. The jokes, left to right, ding ding ding.
	var shown := jokes.filter(func(j): return j.laughs > 0)
	var gap := clampf(0.8 / maxf(1.0, shown.size()), 0.05, 0.11)
	for k in shown.size():
		var joke: Dictionary = shown[k]
		# Two staggered rows across the stage, so a long bit never piles up.
		var per_row := ceili(shown.size() / 2.0) if shown.size() > 4 else shown.size()
		var col := k % per_row
		var row := k / per_row
		var x := area.position.x + area.size.x * (0.14 + 0.72 * (col + 0.5 + 0.5 * row) / (per_row + 0.5 * row))
		var y := area.position.y + area.size.y * (0.42 + 0.24 * row)
		var text := "+%s" % _num(joke.laughs)
		var why: Array = joke.get("why", [])
		if joke.retrigger and why.is_empty():
			why = ["AGAIN"]
		_pop_number(text, Vector2(x, y), COLOR_NEON if joke.retrigger else COLOR_GOLD, 26, _short_reasons(why))
		_sound.play("ding", -6.0, 1.0 + 0.07 * k)
		_stage_view.react(0.3 + 0.05 * k)
		await get_tree().create_timer(gap).timeout

	# 2. The multipliers, one slam each.
	var mults: Array = [["×%.1f  THE ROOM" % b.landed_room, COLOR_HOT]]
	if b.landed_links > 0:
		mults.append(["×%s  CHAIN" % _mult_text(b.landed_chain), COLOR_NEON])
	if b.landed_keep < 0.999:
		mults.append(["×%s  CREW CUT" % _mult_text(b.landed_keep), Color(0.8, 0.75, 1)])
	for m in mults.size():
		_slam_show(mults[m][0], mults[m][1], 30)
		_sound.play("ding", -2.0, 0.8 + 0.15 * m)
		_shake(3.0 + m)
		await get_tree().create_timer(0.28).timeout

	# 3. The total spins up like a slot reel.
	var frac := float(score) / maxf(1.0, b.laughs_needed)
	_sound.play("rimshot", -2.0)
	var spin := create_tween()
	spin.tween_method(func(v: float):
		_slam.text = "+%s" % _num(int(v)), 0.0, float(score), 0.45).set_ease(Tween.EASE_OUT)
	_slam_show("+0", COLOR_GOLD, 44, false)
	for t in 8:
		_sound.play("coin", -8.0, 1.0 + 0.1 * t)
		await get_tree().create_timer(0.055).timeout
	_slam.text = "+%s" % _num(score)

	# 4. The banner, sized to how much of the night's target this bit was.
	var tier := "NICE!"
	var coins := 6
	if frac >= 0.5:
		tier = "JACKPOT!!!"
		coins = 48
	elif frac >= 0.25:
		tier = "HUGE!"
		coins = 32
	elif frac >= 0.1:
		tier = "BIG LAUGH!"
		coins = 18
	else:
		coins = 6 + int(frac * 120)
	_slam_show("+%s\n%s" % [_num(score), tier], COLOR_GOLD, 44)
	if frac >= 0.25:
		_sound.play("jackpot", -2.0)
		_sound.play_later("applause", 0.3, -4.0)
	else:
		_ding_run(3, 1.2)
	_sound.play("laugh_huge" if frac >= 0.25 else ("laugh_big" if frac >= 0.1 else "laugh_small"))
	_stage_view.react(minf(0.5 + frac * 2.0, 1.6))
	_shake(minf(4.0 + frac * 30.0, 18.0))
	_coin_shower(score, coins, area.get_center())
	if b.result == Battle.Result.ONGOING and b.cards_played_this_set <= 6:
		_tip("room", "The ROOM line multiplies every bit. Land when it's HIGH, before a heckle drops it.", 7.0)

	# 5. The hero joke: the biggest line of the bit, shown at the end.
	await get_tree().create_timer(1.1).timeout
	create_tween().tween_property(_slam, "modulate:a", 0.0, 0.25)
	var hero: Dictionary = {}
	for l in lines:
		if hero.is_empty() or l.laughs > hero.laughs:
			hero = l
	if not hero.is_empty() and _battle.result == Battle.Result.ONGOING:
		_say(hero.line, COLOR_GOLD.lightened(0.5))


## One-word tags for a joke's reasons, small enough to sit under its number.
func _short_reasons(why: Array) -> Array:
	var out := []
	for w in why:
		var word: String = str(w).split(" ")[0]
		if word == "PUNCHLINE":
			word = "AGAIN"
		if word != "COMBO" and not out.has(word):
			out.append(word)
	return out.slice(0, 1)


func _mult_text(m: float) -> String:
	var t := "%.2f" % m
	return t.trim_suffix("0").trim_suffix(".0") if t.ends_with("0") else t


func _check_result() -> void:
	match _battle.result:
		Battle.Result.WON:
			_end_turn_button.disabled = true
			_stage_view.react(1.2)
			_sound.play_later("applause", 0.5)
			await get_tree().create_timer(2.0).timeout
			if _run.is_final_set():
				_sound.play("fanfare")
				_show_run_won()
			else:
				_show_reward()
		Battle.Result.LOST:
			_end_turn_button.disabled = true
			_sound.play_later("sad_trombone", 0.4)
			await get_tree().create_timer(1.6).timeout
			_show_lost()


func _on_pause() -> void:
	_sound.play("click")
	_set_paused(not _paused)


func _set_paused(on: bool) -> void:
	if _battle == null or _battle.result != Battle.Result.ONGOING:
		return
	_paused = on
	if on:
		_open_overlay()
		_overlay_box.add_child(_neon("PAUSED", 48, COLOR_NEON_BLUE))
		_overlay_box.add_child(_centered(_label("The crowd waits. Barely.", 24)))
		var resume := _button("Back to the mic", COLOR_PUNCHLINE)
		resume.pressed.connect(_set_paused.bind(false))
		resume.set_meta("pad_button", JOY_BUTTON_START)
		_overlay_box.add_child(resume)
		if Dev.ON:
			_overlay_box.add_child(_dev_tools())
	else:
		_close_overlay()


func _show_reward() -> void:
	_open_overlay()
	_overlay_box.add_child(_neon("YOU KILLED!", 48, COLOR_GOLD))
	_overlay_box.add_child(_centered(_label("%s laughs. Add a new bit to your act:" % _num(_battle.laughs), 26)))
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
	skip.set_meta("pad_button", JOY_BUTTON_B)
	_overlay_box.add_child(skip)


func _take_reward(card: CardData) -> void:
	_sound.play("chime" if card else "click")
	_run.finish_set(card)
	if _run.crew_choices().is_empty():
		_show_next_up()
	else:
		_show_crew()


## Hire crew between sets: each helps every set but takes a cut of every bit.
func _show_crew() -> void:
	_open_overlay()
	_overlay_box.add_child(_neon("HIRE YOUR CREW", 40, COLOR_NEON_BLUE))
	_overlay_box.add_child(_centered(_label("They help every set, for a cut of every bit.", 24)))
	for id in _run.crew_choices():
		var info := Crew.info(id)
		var b := _button("%s\n%s  (takes %d%%)" % [info.title, info.perk, roundi(info.cut * 100)], COLOR_SETUP)
		b.custom_minimum_size.y = MIN_TOUCH_HEIGHT * 1.4
		b.add_theme_font_override("font", _heading_font)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_hire.bind(id))
		_overlay_box.add_child(b)
	var skip := _button("Work alone", Color(0.3, 0.3, 0.35))
	skip.pressed.connect(_hire.bind(""))
	skip.set_meta("pad_button", JOY_BUTTON_B)
	_overlay_box.add_child(skip)


func _hire(id: String) -> void:
	_sound.play("chime" if id != "" else "click")
	_run.hire(id)
	_show_next_up()


func _show_next_up() -> void:
	_open_overlay()
	var next := _run.current_audience()
	var heading := "HEADLINE SHOW" if next.is_boss else "NEXT SET"
	if _run.set_index == 0:
		heading = "FIRST SET"
	_overlay_box.add_child(_neon(heading, 40, COLOR_NEON_BLUE))
	_overlay_box.add_child(_centered(_label(next.title, 36)))
	_overlay_box.add_child(_neon("GOAL: %s LAUGHS" % _num(next.laughs_needed), 28, COLOR_GOLD))
	_overlay_box.add_child(_centered(_label("before the light goes on (%d seconds).  Deck: %d cards" % [int(next.seconds), _run.deck.size()], 24)))
	for t in next.loves:
		_overlay_box.add_child(_centered(_label("LOVES %s:  ×%s laughs, +Heat" % [CardData.TOPIC_NAMES[t], str(Balance.LOVED_MULT)], 26, Color(0.6, 1, 0.6))))
	for t in next.hates:
		_overlay_box.add_child(_centered(_label("HATES %s:  ×%s laughs, -Heat" % [CardData.TOPIC_NAMES[t], str(Balance.HATED_MULT)], 26, Color(1, 0.6, 0.6))))
	if not _run.crew.is_empty():
		var names := _run.crew.map(func(id): return Crew.info(id).title)
		_overlay_box.add_child(_centered(_label("Crew: " + ", ".join(names), 22, Color(0.8, 0.75, 1))))
	var go := _button("Take the stage", COLOR_PUNCHLINE)
	go.pressed.connect(_start_set)
	go.pressed.connect(_sound.play.bind("click"))
	go.set_meta("pad_button", JOY_BUTTON_START)
	if Dev.ON and not next.is_boss:
		# Side by side, so the screen doesn't grow taller in landscape.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(go)
		row.add_child(_dev_button("DEV:\nSKIP TO BOSS", dev_skip_to_headline))
		_overlay_box.add_child(row)
	else:
		_overlay_box.add_child(go)


func _show_lost() -> void:
	_open_overlay()
	var why := "YOU GOT THE LIGHT" if _battle.loss == Battle.Loss.LIGHT else "YOU LOST THE ROOM"
	_overlay_box.add_child(_neon(why, 40, COLOR_HOT))
	_overlay_box.add_child(_centered(_label("%s.  Set %d of %d.  Laughs %s / %s" % [
		_battle.audience.title, _run.set_index + 1, _run.lineup.size(), _num(_battle.laughs), _num(_battle.laughs_needed)], 24)))
	var again := _button("Try again", COLOR_PUNCHLINE)
	again.pressed.connect(_new_run)
	_overlay_box.add_child(again)


func _show_run_won() -> void:
	_open_overlay()
	_overlay_box.add_child(_neon("STANDING OVATION!", 40, COLOR_GOLD))
	_overlay_box.add_child(_centered(_label("Even The Critic laughed. You're a headliner.", 26)))
	var again := _button("Play again", COLOR_PUNCHLINE)
	again.pressed.connect(_new_run)
	_overlay_box.add_child(again)


# ---------------------------------------------------------------- dev tools

## DEV TOOLS (Dev.ON) under the pause menu: shortcuts for testing later sets.
## The office's DEV panel calls dev_win_set() and dev_skip_to_headline() too.
func _dev_tools() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var head := _centered(_label("DEV TOOLS", 20, Color(1.0, 0.65, 0.3)))
	head.add_theme_font_override("font", _pixel_font)
	head.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	head.add_theme_constant_override("outline_size", 8)
	box.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var buttons := [_dev_button("WIN\nTHIS SET", dev_win_set), _dev_button("MAX MIC\n+HEAT +30S", dev_boost)]
	if not _run.is_final_set():
		buttons.append(_dev_button("SKIP TO\nHEADLINE", dev_skip_to_headline))
	for b in buttons:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return box


func _dev_button(text: String, action: Callable) -> Button:
	var b := _button(text, Color(0.28, 0.3, 0.36))
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_constant_override("outline_size", 6)
	b.pressed.connect(func():
		_sound.play("click")
		action.call())
	return b


## Win the set being played right now. False if no set is live.
func dev_win_set() -> bool:
	if _battle == null or _battle.result != Battle.Result.ONGOING:
		return false
	_paused = false
	_close_overlay()
	_battle.dev_win()
	_battle.pop_events()
	_refresh()
	_check_result()
	return true


## Full mic, the hottest room and 30 more seconds, then back to the set.
func dev_boost() -> bool:
	if _battle == null or _battle.result != Battle.Result.ONGOING:
		return false
	_battle.dev_boost(30.0)
	_set_paused(false)
	_refresh()
	return true


## Jump to the headline show, picking up one new card per set skipped (as
## if you'd played them). False before a run starts or at the boss already.
func dev_skip_to_headline() -> bool:
	if _run == null or _run.is_final_set():
		return false
	while not _run.is_final_set():
		var picks := _run.reward_choices()
		_run.finish_set(picks[0] if not picks.is_empty() else null)
	_paused = false
	_show_next_up()
	return true


# ---------------------------------------------------------------- drawing

## Things that change every frame: the clock, the Room line, mic, the pot.
func _update_live() -> void:
	var b := _battle
	var t := ceili(b.time_left)
	_clock_label.text = "%d:%02d" % [t / 60, t % 60]
	var urgent := b.time_left <= 10.0 and b.result == Battle.Result.ONGOING
	_clock_label.add_theme_color_override("font_color",
		COLOR_HOT if urgent and fmod(b.time_left, 1.0) > 0.5 else (COLOR_HOT.lightened(0.3) if urgent else Color.WHITE))
	_laugh_label.text = "LAUGHS  %s / %s" % [_num(int(_shown_laughs)), _num(b.laughs_needed)]
	_laugh_bar.max_value = b.laughs_needed
	_laugh_bar.value = minf(_shown_laughs, b.laughs_needed)

	var heat := clampf(b.crowd_energy / Balance.HOT_ENERGY, 0.0, 1.0)
	_stage_view.heat = heat
	_stage_mat.set_shader_parameter("heat", heat)
	var line: Array[float] = b.heat_history.duplicate()
	line.append(b.crowd_energy)
	_room_chart.set_data(line, b.heat_multiplier())
	var hot := b.crowd_energy >= Balance.HOT_ENERGY
	var cold := b.crowd_energy <= Balance.COLD_ENERGY
	var mood := "  ON FIRE!" if hot else ("  DYING..." if cold else "")
	_energy_label.text = "THE ROOM  ×%.1f%s" % [b.heat_multiplier(), mood]
	_energy_label.add_theme_color_override("font_color",
		COLOR_HOT if hot else (COLOR_COLD if cold else Color.WHITE))

	var intent := b.current_intent()
	if intent:
		_intent_label.text = "NEXT IN %ds: %s" % [ceili(b.event_in()), intent.text]
		var bad := intent.kind == IntentData.Kind.DRAIN
		_intent_label.add_theme_color_override("font_color",
			COLOR_HOT if bad and b.event_in() < 2.0 and b.bit_open() else Color(1, 0.75, 0.75))
	var peek := b.next_intent()
	_peek_label.text = "Then: %s" % peek.text if b.sees_two_moves() and peek else ""
	_peek_label.visible = _peek_label.text != ""

	_mic_label.text = "MIC %.1f" % b.mic
	_mic_bar.value = b.mic
	if b.bit_open():
		_bit_label.text = "BIT  %s × %.1f = %s" % [_num(b.bit_laughs), b.bit_multiplier(), _num(b.bit_score())]
		_end_turn_button.text = "LAND IT  %s" % _num(b.bit_score())
	else:
		_bit_label.text = "play cards to build a bit"
		_end_turn_button.text = "LAND IT"
	_end_turn_button.disabled = b.result != Battle.Result.ONGOING or not b.bit_open()


## Redraws the hand and the labels that only change on a tap or a crowd move.
func _refresh() -> void:
	var b := _battle
	_set_label.text = "Set %d of %d" % [_run.set_index + 1, _run.lineup.size()]
	_deck_label.text = "Deck %d" % (b.draw_pile.size() + b.discard_pile.size() + b.hand.size())
	_audience_label.text = b.audience.title
	_taste_label.text = _taste_text(b.audience)
	_update_live()

	for child in _hand_grid.get_children():
		child.queue_free()
	for i in b.hand.size():
		var card := b.hand[i]
		var widget := _card_widget(card, b.laughs_for(card), b.can_play(i))
		widget.pressed.connect(_on_card_pressed.bind(i))
		_hand_grid.add_child(widget)
		if i >= _hand_shown.size() or _hand_shown[i] != card:
			_pop_in(widget, 0.0)
	_hand_shown = b.hand.duplicate()
	_mic_whole = int(b.mic)
	if _started and b.result == Battle.Result.ONGOING:
		if b.hand.any(func(c): return c.setups > 0) and b.hand.any(func(c): return c.is_punchline):
			_tip("setup", "Purple SETUP, then orange PUNCHLINE = DOUBLE laughs!")
		if b.hand.any(func(c): return b.taste(c) > 0):
			_tip("loved", "Cards marked LOVED are this crowd's favourite topic: ×1.5 laughs and +Heat!")


## 12,345 / 1.2M style numbers.
func _num(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## A number popping up somewhere over the crowd, for the landing cascade.
func _float_burst(text: String, color: Color, font_size: int) -> void:
	var label := _label(text, font_size, color)
	label.add_theme_font_override("font", _pixel_font)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(label)
	var area := _fx_layer.size
	label.position = Vector2(randf_range(0.1, 0.75) * area.x, randf_range(0.35, 0.75) * area.y)
	label.pivot_offset = label.size / 2
	label.scale = Vector2(0.4, 0.4)
	var t := create_tween().set_parallel()
	t.tween_property(label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "position:y", label.position.y - 90, 0.8)
	t.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.45)
	t.chain().tween_callback(label.queue_free)


## "Loves: Dating   Hates: Work" for an audience, or "".
func _taste_text(a: AudienceData) -> String:
	var parts: Array[String] = []
	if not a.loves.is_empty():
		parts.append("Loves: " + ", ".join(a.loves.map(func(t): return CardData.TOPIC_NAMES[t])))
	if not a.hates.is_empty():
		parts.append("Hates: " + ", ".join(a.hates.map(func(t): return CardData.TOPIC_NAMES[t])))
	return "   ".join(parts)


func _card_widget(card: CardData, preview: int, playable: bool) -> Button:
	# An 8-bit trading card: paper face, thick outline, hard shadow and a
	# coloured title band by card type.
	var color := _card_color(card)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not playable
	for state in ["normal", "hover", "pressed", "disabled"]:
		var paper := COLOR_PAPER.darkened(0.12 if state == "pressed" else 0.0)
		var style := _box_style(paper.lightened(0.04) if state == "hover" else paper, 0, OUTLINE)
		style.border_color = color.darkened(0.35)
		_hard_shadow(style, 2 if state == "pressed" else 6)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(_sound.play.bind("card"))
	button.resized.connect(func(): button.pivot_offset = button.size / 2)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = OUTLINE
	box.offset_top = OUTLINE
	box.offset_right = -OUTLINE
	box.offset_bottom = -OUTLINE - 4
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	button.add_child(box)

	var band := PanelContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band_style := _box_style(color, 4)
	band_style.border_width_bottom = OUTLINE
	band_style.border_color = COLOR_OUTLINE
	band.add_theme_stylebox_override("panel", band_style)
	box.add_child(band)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 6)
	band.add_child(head)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _box_style(COLOR_OUTLINE, 0))
	badge.custom_minimum_size = Vector2(34, 34)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(badge)
	var cost := _label(str(card.cost), 16, COLOR_GOLD)
	cost.add_theme_font_override("font", _pixel_font)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(cost)
	var title := _label(card.title, 23, Color.WHITE)
	title.add_theme_font_override("font", _heading_font)
	title.add_theme_color_override("font_outline_color", color.darkened(0.6))
	title.add_theme_constant_override("outline_size", 6)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 40
	head.add_child(title)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	box.add_child(margin)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(body)
	if card.is_joke():
		var tag_text := CardData.beat_name(card.beat)
		var tag_color := Color(0.35, 0.3, 0.3)
		if card.topic != "":
			tag_text += " · " + CardData.TOPIC_NAMES[card.topic]
			var taste := _battle.taste(card) if _battle != null and preview >= 0 else 0
			if taste > 0:
				tag_text += "  LOVED"
				tag_color = Color(0.1, 0.5, 0.15)
			elif taste < 0:
				tag_text += "  HATED"
				tag_color = Color(0.7, 0.1, 0.1)
		var beat_label := _label(tag_text, 15, tag_color)
		beat_label.add_theme_font_override("font", _heading_font)
		beat_label.clip_text = true
		beat_label.custom_minimum_size.x = 40
		body.add_child(beat_label)
	var rules := _label(card.rules, 19, COLOR_INK)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules.custom_minimum_size.x = 40
	body.add_child(rules)

	var linked := _battle != null and preview >= 0 and playable and _battle.is_linked(card)
	var chain := _battle != null and preview >= 0 and playable and _battle.chains(card)
	if chain:
		for state in ["normal", "hover", "pressed"]:
			var frame: StyleBoxFlat = button.get_theme_stylebox(state)
			frame.border_color = COLOR_NEON
		var badge_chain := _label("CHAIN ×%.1f" % Balance.CHAIN_X, 14, COLOR_NEON)
		badge_chain.add_theme_font_override("font", _pixel_font)
		badge_chain.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
		badge_chain.add_theme_constant_override("outline_size", 6)
		body.add_child(badge_chain)
	elif linked:
		# Lit gold frame and a badge: playing this now earns its link bonus.
		for state in ["normal", "hover", "pressed"]:
			var frame: StyleBoxFlat = button.get_theme_stylebox(state)
			frame.border_color = COLOR_GOLD
		var badge_link := _label("LINK!", 16, COLOR_NEON_BLUE)
		badge_link.add_theme_font_override("font", _pixel_font)
		badge_link.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
		badge_link.add_theme_constant_override("outline_size", 6)
		body.add_child(badge_link)
	if preview > 0:
		var gain := _label("+%d" % preview, 16, Color(0.75, 0.4, 0.0))
		gain.add_theme_font_override("font", _pixel_font)
		body.add_child(gain)
	if not playable:
		button.modulate = Color(0.75, 0.72, 0.75, 0.5)
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


func _play_reaction(card: CardData, gained: int, energy: int) -> void:
	if gained >= 150:
		_sound.play_later("laugh_huge", 0.25 if card.is_punchline else 0.0)
	elif gained >= 80:
		_sound.play_later("laugh_big", 0.25 if card.is_punchline else 0.0)
	elif gained > 0:
		_sound.play("laugh_small")
	elif energy > 0:
		_sound.play("cheer")
	if card.is_punchline and gained > 0:
		_sound.play("rimshot", -3.0)
	if gained > 0:
		_stage_view.react(gained / 140.0)


func _on_mute() -> void:
	_sound.toggle_mute()
	_update_mute_label()
	_sound.play("click")


func _update_mute_label() -> void:
	_mute_button.text = "Sound: Off" if _sound.muted else "Sound: On"


## Floats a number up over the stage: laughs near the top right, energy
## (low = true) just above the crowd so it never covers the speech bubble.
# ---------------------------------------------------------------- casino fx

## Centre of the card in hand slot `index`, on screen.
func _card_center(index: int) -> Vector2:
	var live := _hand_grid.get_children().filter(func(c): return not c.is_queued_for_deletion())
	if index < live.size():
		return (live[index] as Control).get_global_rect().get_center()
	return _hand_grid.get_global_rect().get_center()


## A played card's laughs fly up into the bit (the pot): the number, plus a
## handful of coins clinking in one after another.
func _fling_to_pot(gained: int, from: Vector2) -> void:
	var to := _bit_label.get_global_rect().get_center()
	var label := _fx_label("+%s" % _num(gained), COLOR_GOLD, 28)
	_fly(label, from, to, 0.0, func():
		_sound.play("ding", -8.0, 1.3)
		_bump(_bit_label))
	var count := clampi(2 + gained / (5 * Balance.LAUGH_SCALE), 3, 10)
	for i in count:
		_fly(_coin(), from, to + Vector2(randf_range(-60, 60), 0), 0.04 * i, func():
			_sound.play("coin", -12.0, 1.0 + 0.06 * i))


## Laughs pour into the meter as coins; each one counts as it lands.
func _coin_shower(total: int, count: int, from: Vector2) -> void:
	var to_rect := _laugh_bar.get_global_rect()
	var each := total / maxi(1, count)
	for i in count:
		var value := each if i < count - 1 else total - each * (count - 1)
		var to := Vector2(randf_range(to_rect.position.x + 20, to_rect.end.x - 20), to_rect.get_center().y)
		var node: Control = _coin() if i % 3 != 0 else _fx_label("+%s" % _num(value), COLOR_GOLD, 18)
		_fly(node, from, to, 0.025 * i, func():
			_in_flight = maxi(0, _in_flight - value)
			if i % 2 == 0:
				_sound.play("coin", -10.0, 1.0 + 0.5 * float(i) / count)
			_bump(_laugh_bar))


## Bursts `node` out of `from`, then flies it into `to`; `arrive` runs on landing.
func _fly(node: Control, from: Vector2, to: Vector2, delay: float, arrive: Callable) -> void:
	_top_fx.add_child(node)
	node.position = from - node.size / 2
	node.pivot_offset = node.size / 2
	node.scale = Vector2(0.3, 0.3)
	node.modulate.a = 0.0
	var burst := from + Vector2(randf_range(-110, 110), randf_range(-120, -20))
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(node, "modulate:a", 1.0, 0.01)
	t.parallel().tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(node, "position", burst - node.size / 2, 0.18).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", to - node.size / 2, randf_range(0.28, 0.4)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(node, "scale", Vector2(0.6, 0.6), 0.3)
	t.tween_callback(arrive)
	t.tween_callback(node.queue_free)


## A number popping up in place during the payout, with its reasons under it.
func _pop_number(text: String, at: Vector2, color: Color, size: int, why: Array) -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	box.add_child(_fx_label(text, color, size))
	for w in why:
		box.add_child(_fx_label(w, COLOR_NEON_BLUE if not str(w).begins_with("HATED") else COLOR_COLD, 12))
	_top_fx.add_child(box)
	box.reset_size()
	box.position = at - box.size / 2
	box.pivot_offset = box.size / 2
	box.scale = Vector2(0.2, 0.2)
	var t := create_tween()
	t.tween_property(box, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.5)
	t.tween_property(box, "position:y", box.position.y - 30, 0.3)
	t.parallel().tween_property(box, "modulate:a", 0.0, 0.3)
	t.tween_callback(box.queue_free)


## Puts text in the big centre slot of the stage with a slam.
func _slam_show(text: String, color: Color, size: int, slam := true) -> void:
	_slam.text = text
	_slam.add_theme_color_override("font_color", color)
	# Shrink to fit the stage instead of wrapping mid-word (Press Start is 1em wide).
	var longest := 1
	for part in text.split("\n"):
		longest = maxi(longest, part.length())
	var fit := int(_fx_layer.size.x * 0.92 / longest)
	_slam.add_theme_font_size_override("font_size", clampi(fit, 16, size))
	_slam.modulate.a = 1.0
	await get_tree().process_frame
	_slam.pivot_offset = _slam.size / 2
	if slam:
		_slam.scale = Vector2(1.8, 1.8)
		create_tween().tween_property(_slam, "scale", Vector2.ONE, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Quick rising dings: ding ding ding.
func _ding_run(count: int, pitch: float) -> void:
	for i in count:
		_sound.play("ding", -6.0, pitch + 0.12 * i)
		await get_tree().create_timer(0.07).timeout


## A casino token: a gold square with a $ on it.
func _coin() -> Control:
	var coin := PanelContainer.new()
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _box_style(COLOR_GOLD, 0, 3)
	style.border_color = Color(0.55, 0.35, 0.0)
	coin.add_theme_stylebox_override("panel", style)
	coin.custom_minimum_size = Vector2(26, 26)
	var mark := _label("$", 14, Color(0.5, 0.3, 0.0))
	mark.add_theme_font_override("font", _pixel_font)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin.add_child(mark)
	coin.size = coin.custom_minimum_size
	return coin


func _fx_label(text: String, color: Color, size: int) -> Label:
	var label := _label(text, size, color)
	label.add_theme_font_override("font", _pixel_font)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.reset_size()
	return label


## Background fizz: the hotter the room, the more "HA!"s pop over the crowd;
## the meter dings as it passes each quarter of the target.
func _ambient(delta: float) -> void:
	var b := _battle
	if b.result != Battle.Result.ONGOING or not _started or _paused or _overlay.visible:
		return
	_ha_clock -= delta
	var heat := clampf(b.crowd_energy / Balance.MAX_CROWD_ENERGY, 0.0, 1.0)
	if _ha_clock <= 0.0 and heat > 0.35:
		_ha_clock = lerpf(0.9, 0.12, (heat - 0.35) / 0.65)
		var area := _fx_layer.get_global_rect()
		var at := Vector2(randf_range(area.position.x + 40, area.end.x - 40), area.end.y - randf_range(30, 90))
		var ha := _fx_label(["HA!", "HA", "HAHA", "LOL"][randi() % 4], COLOR_GOLD.lightened(randf() * 0.4), 14 + int(heat * 10))
		_top_fx.add_child(ha)
		ha.position = at - ha.size / 2
		var t := create_tween()
		t.tween_property(ha, "position:y", ha.position.y - 50, 0.7)
		t.parallel().tween_property(ha, "modulate:a", 0.0, 0.7).set_delay(0.25)
		t.tween_callback(ha.queue_free)
	var pct := int(100.0 * _shown_laughs / maxf(1.0, b.laughs_needed))
	for mark in [25, 50, 75]:
		if pct >= mark and not _milestones.has(mark):
			_milestones[mark] = true
			_float_text("%d%%!" % mark, COLOR_GOLD, false, false, 0.62)
			_ding_run(mark / 25 + 1, 1.0 + mark / 100.0)
			_bump(_laugh_bar)


## A quick squash on whatever just got paid.
func _bump(node: Control) -> void:
	node.pivot_offset = node.size / 2
	node.scale = Vector2(1.06, 1.25)
	create_tween().tween_property(node, "scale", Vector2.ONE, 0.12)


# ---------------------------------------------------------------- coach

func _load_tips() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(TIPS_PATH) == OK and cfg.has_section("seen"):
		for id in cfg.get_section_keys("seen"):
			_tips_seen[id] = true


## Queues a one-time tip (each is shown once ever, then remembered).
func _tip(id: String, text: String, seconds := 6.0) -> void:
	if _tips_seen.has(id):
		return
	_tips_seen[id] = true
	var cfg := ConfigFile.new()
	for seen in _tips_seen:
		cfg.set_value("seen", seen, true)
	cfg.save(TIPS_PATH)
	_tip_queue.append([id, text, seconds])


## Picks the coach's line: urgent warnings first, then how to start, then tips.
func _update_coach(delta: float) -> void:
	_coach_time += delta
	if _tip_left > 0.0:
		_tip_left -= delta
	if _tip_left <= 0.0 and not _tip_queue.is_empty():
		var next: Array = _tip_queue.pop_front()
		_tip_text = next[1]
		_tip_left = next[2]
	var b := _battle
	var text := ""
	var urgent := false
	if b.result == Battle.Result.ONGOING and not _overlay.visible:
		var intent := b.current_intent()
		if not _started:
			text = "TAP ANY CARD TO START!  The clock waits for your first joke."
		elif intent and intent.kind == IntentData.Kind.DRAIN and b.bit_open() and b.event_in() < 3.0:
			text = "HECKLE IN %d!  LAND IT NOW or lose half the bit!" % ceili(b.event_in())
			urgent = true
		elif _tip_left > 0.0:
			text = _tip_text
	_coach.visible = text != ""
	_coach_label.text = text
	var glow := 0.5 + 0.5 * sin(_coach_time * (10.0 if urgent else 4.0))
	_coach_label.add_theme_color_override("font_color",
		COLOR_HOT.lerp(Color.WHITE, glow * 0.4) if urgent else Color.WHITE.lerp(COLOR_GOLD, glow))
	(_coach.get_theme_stylebox("panel") as StyleBoxFlat).border_color = COLOR_HOT if urgent else COLOR_NEON_BLUE
	# LAND IT pulses while you're being told to press it.
	var pulse := (urgent or _tip_text.contains("LAND IT") and _tip_left > 0.0) and b.bit_open()
	_end_turn_button.modulate = Color(1.0 + 0.5 * glow, 1.0 + 0.3 * glow, 1.0) if pulse else Color.WHITE
	if _tip_text.contains("LAND IT") and b.landed_raw > 0:
		_tip_left = 0.0


func _float_text(text: String, color: Color, big: bool, low := false, y_frac := -1.0) -> void:
	var label := _label(text, 48 if big else (24 if low else 32), color)
	label.add_theme_font_override("font", _pixel_font)
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_color_override("font_shadow_color", COLOR_OUTLINE)
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	_fx_layer.add_child(label)
	if big:
		_shake(14.0)
	await get_tree().process_frame
	var y := _fx_layer.size.y * (y_frac if y_frac >= 0.0 else (0.66 if low else 0.12))
	label.position = Vector2(_fx_layer.size.x - label.size.x - 50, y)
	label.pivot_offset = label.size / 2
	label.scale = Vector2(1.6, 1.6)
	var t := create_tween().set_parallel()
	t.tween_property(label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "position:y", label.position.y - 60, 0.9).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	t.chain().tween_callback(label.queue_free)


func _flash(node: CanvasItem) -> void:
	node.modulate = Color(2, 0.6, 0.6)
	create_tween().tween_property(node, "modulate", Color.WHITE, 0.4)
	_shake(8.0)


## Shakes the picture (not the layout, so taps stay where they are).
func _shake(strength: float) -> void:
	var t := create_tween()
	for i in 6:
		var k := strength * (1.0 - i / 6.0)
		t.tween_property(_crt_mat, "shader_parameter/shake",
			Vector2(randf_range(-k, k), randf_range(-k, k)), 0.03)
	t.tween_property(_crt_mat, "shader_parameter/shake", Vector2.ZERO, 0.03)


## Cards bounce up into place when the hand is dealt.
func _pop_in(node: Control, delay: float) -> void:
	node.scale = Vector2(0.4, 0.4)
	node.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(node, "scale", Vector2.ONE, 0.25).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 1.0, 0.1).set_delay(delay)


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


## Neon-sign text: bold, colored glow around a pale core.
func _neon(text: String, size: int, color: Color) -> Label:
	var label := _label(text, size, color.lerp(Color.WHITE, 0.55))
	label.add_theme_font_override("font", _pixel_font)
	label.add_theme_color_override("font_outline_color", color)
	label.add_theme_constant_override("outline_size", maxi(4, size / 6))
	# A blocky drop shadow in the sign's colour, arcade-title style.
	var drop := maxi(4, size / 10)
	label.add_theme_color_override("font_shadow_color", color.darkened(0.6))
	label.add_theme_constant_override("shadow_outline_size", maxi(4, size / 6))
	label.add_theme_constant_override("shadow_offset_x", drop)
	label.add_theme_constant_override("shadow_offset_y", drop)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Every few seconds the sign buzzes off and on, like an old neon tube.
func _flicker(node: CanvasItem) -> void:
	var t := create_tween().set_loops()
	t.tween_interval(2.6)
	t.tween_property(node, "modulate:a", 0.35, 0.05)
	t.tween_property(node, "modulate:a", 1.0, 0.05)
	t.tween_property(node, "modulate:a", 0.5, 0.04)
	t.tween_property(node, "modulate:a", 1.0, 0.08)


func _shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


func _shader_rect(shader: Shader) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	rect.resized.connect(func(): mat.set_shader_parameter("rect_size", rect.size))
	return rect


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, MIN_TOUCH_HEIGHT)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_font_override("font", _pixel_font)
	button.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	button.add_theme_constant_override("outline_size", 8)
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled"]:
		var c := color
		match state:
			"hover": c = color.lightened(0.15)
			"pressed": c = color.darkened(0.2)
			"disabled": c = color.darkened(0.45)
		# Chunky arcade button: outline, a dark lip underneath that squashes
		# when pressed, and a hard shadow.
		var style := _box_style(c, 12, OUTLINE)
		style.border_color = c.darkened(0.55)
		style.border_width_bottom = OUTLINE + (2 if state == "pressed" else 10)
		if state == "pressed":
			style.expand_margin_top = -8
		_hard_shadow(style, 2 if state == "pressed" else 6)
		button.add_theme_stylebox_override(state, style)
	return button


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 30)
	var back := _box_style(Color(0.02, 0.01, 0.04), 0, OUTLINE)
	bar.add_theme_stylebox_override("background", back)
	var fill := _box_style(color, 0, OUTLINE)
	bar.add_theme_stylebox_override("fill", fill)
	# Segment lines so the bar reads as blocks.
	var ticks := Control.new()
	ticks.set_anchors_preset(Control.PRESET_FULL_RECT)
	ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticks.draw.connect(func():
		var step := 24.0
		var x := step
		while x < ticks.size.x - OUTLINE:
			ticks.draw_rect(Rect2(x, OUTLINE, 4, ticks.size.y - OUTLINE * 2), Color(COLOR_OUTLINE, 0.7))
			x += step)
	ticks.resized.connect(ticks.queue_redraw)
	bar.add_child(ticks)
	return bar


## Square pixel panel, optionally with a dark outline.
func _box_style(color: Color, padding := 0, outline := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.anti_aliasing = false
	style.set_border_width_all(outline)
	style.border_color = COLOR_OUTLINE
	style.set_content_margin_all(padding + outline)
	return style


## A solid, unblurred drop shadow down and to the right.
func _hard_shadow(style: StyleBoxFlat, offset: int) -> void:
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 1
	style.shadow_offset = Vector2(offset, offset)


## Pixel fonts drawn crisp: no smoothing, whole-pixel placement.
func _crisp_font(path: String) -> FontFile:
	var font: FontFile = load(path)
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return font
