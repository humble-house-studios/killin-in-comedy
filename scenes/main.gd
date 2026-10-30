extends Control
## Step 2 placeholder: proves the scaling rule and shows the engine working.
## Upright screen = phone layout (stage above hand).
## Sideways screen = Steam layout (stage beside hand).
## "Simulate a set" lets the autopilot play the starter deck against a random
## audience; the real card UI replaces this in step 3.

const MIN_TOUCH_HEIGHT := 88.0
const LOG_LINES := 14

var _safe_margin: MarginContainer
var _body: BoxContainer
var _layout_label: Label
var _sim_button: Button
var _stage_label: Label
var _log_label: Label
var _rng := RandomNumberGenerator.new()
var _sets := 0
var _wins := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()


func _build_ui() -> void:
	_safe_margin = MarginContainer.new()
	_safe_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_safe_margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	_safe_margin.add_child(root)

	var title := Label.new()
	title.text = "YES AND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	root.add_child(title)

	_layout_label = Label.new()
	_layout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layout_label.add_theme_font_size_override("font_size", 22)
	root.add_child(_layout_label)

	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 16)
	root.add_child(_body)

	var stage := _make_panel("STAGE\n(audience + Laugh meter)", Color(0.35, 0.18, 0.45), 1.0)
	_stage_label = stage.get_child(0)
	_body.add_child(stage)
	var log_panel := _make_panel("Tap below to watch the engine\nplay a whole set.", Color(0.15, 0.32, 0.42), 2.0)
	_log_label = log_panel.get_child(0)
	_log_label.add_theme_font_size_override("font_size", 20)
	_body.add_child(log_panel)

	_sim_button = Button.new()
	_sim_button.text = "Simulate a set"
	_sim_button.custom_minimum_size = Vector2(0, MIN_TOUCH_HEIGHT)
	_sim_button.add_theme_font_size_override("font_size", 28)
	_sim_button.pressed.connect(_on_simulate)
	root.add_child(_sim_button)


func _make_panel(text: String, color: Color, stretch: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.custom_minimum_size = Vector2(1, 1)
	panel.add_child(label)
	return panel


func is_landscape() -> bool:
	var s := get_viewport_rect().size
	return s.x > s.y


func _on_resized() -> void:
	var landscape := is_landscape()
	_body.vertical = not landscape
	_layout_label.text = "Steam layout (sideways)" if landscape else "Phone layout (upright)"
	_apply_safe_area()


func _apply_safe_area() -> void:
	# Convert the device's safe area (screen pixels) into viewport units so the
	# UI stays clear of notches and home bars. Desktop/web just get a base margin.
	var base := 24.0
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


func _on_simulate() -> void:
	var audiences := CardLibrary.audiences().values()
	var audience: AudienceData = audiences[_rng.randi_range(0, audiences.size() - 1)]
	var battle := Battle.new(audience, CardLibrary.starter_deck(), _rng.randi())
	var result := Autopilot.play_set(battle)
	_sets += 1
	var won := result == Battle.Result.WON
	if won:
		_wins += 1
	_stage_label.text = "%s\n%s after %d turns\nLaughs %d / %d   Crowd Energy %d\nSets won: %d of %d" % [
		audience.title, "KILLED" if won else "BOMBED", battle.turn,
		battle.laughs, battle.laughs_needed, battle.crowd_energy, _wins, _sets]
	_log_label.text = "\n".join(battle.history.slice(-LOG_LINES))
