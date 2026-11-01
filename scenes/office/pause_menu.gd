extends Control
## The office's pause menu: a 90s window (grey frame, blue title bar) over a
## dimmed, paused world. Opens with Esc, Start on a pad while walking, or the
## pause button top right. Everything is a Button (88 px tall or more) so
## touch, mouse and the pad cursor all work.
##   RESUME, MUSIC -/+, EFFECTS -/+, LOOK SPEED -/+, INVERT Y, SCREENS (look
##   A/B), LOOK BUSY (the workday, the boss and alt-tab: docs/look-busy.md),
##   CONTROLS (the controls card), NEW GAME (asks first).
## Settings live in user://settings.cfg (scenes/sound.gd), section "office".
## The office (office.gd) owns pausing, applying settings and the restart;
## this only builds the window and calls back.

const PadUI := preload("res://scenes/pad_cursor.gd")
const FONT := preload("res://fonts/press_start_2p.ttf")
const ROW_H := 88
const GREY := Color(0.76, 0.76, 0.74)
const NAVY := Color(0.06, 0.14, 0.6)
const INK := Color(0.08, 0.08, 0.1)

var office: Node

var _window: PanelContainer
var _margin: MarginContainer
var _title: Label
var _pages := {}
var _grid: GridContainer
var _labels := {}
var _first := {}
var _cursor: Node
var _card: Control
var _page := "main"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(center)
	_window = PanelContainer.new()
	_window.add_theme_stylebox_override("panel", _box(GREY, Color(0.98, 0.98, 0.96), 4, Color(0, 0, 0, 0.5)))
	center.add_child(_window)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_window.add_child(col)
	# Title bar, like the windows on the office CRTs.
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(NAVY, NAVY, 0))
	col.add_child(bar)
	var bar_row := HBoxContainer.new()
	bar.add_child(bar_row)
	_title = _text("OPTIONS.EXE", 18, Color.WHITE)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(_title)
	var x := _text("x", 16, INK)
	x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	x.custom_minimum_size = Vector2(30, 26)
	x.add_theme_stylebox_override("normal", _box(GREY, Color(0.98, 0.98, 0.96), 2))
	bar_row.add_child(x)
	var body := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 16)
	col.add_child(body)
	var stack := VBoxContainer.new()
	body.add_child(stack)
	_build_main(stack)
	_build_controls(stack)
	_build_confirm(stack)
	get_viewport().size_changed.connect(_layout)
	_layout()


# ---------------------------------------------------------------- pages

func _build_main(parent: Node) -> void:
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 12)
	parent.add_child(_grid)
	_pages["main"] = _grid
	_first["main"] = _button(_grid, "RESUME", func(): office.close_menu(true))
	_stepper(_grid, "music", "MUSIC")
	_stepper(_grid, "effects", "EFFECTS")
	_stepper(_grid, "look_speed", "LOOK SPEED")
	_labels["invert_y"] = _button(_grid, "", func(): office.set_setting("invert_y", not office.setting("invert_y")))
	_labels["screens"] = _button(_grid, "", func(): office.toggle_look())
	_labels["look_busy"] = _button(_grid, "", func(): office.set_setting("look_busy", not office.setting("look_busy")))
	_button(_grid, "CONTROLS", func(): _show("controls"))
	var wipe := _button(_grid, "NEW GAME", func(): _show("confirm"))
	wipe.add_theme_color_override("font_color", Color(0.6, 0.08, 0.06))


## A row: [-] NAME VALUE [+], all buttons but the label.
func _stepper(parent: Node, key: String, title: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var minus := _button(row, "-", func(): office.step_setting(key, -1))
	minus.custom_minimum_size = Vector2(ROW_H, ROW_H)
	minus.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := _text(title, 16, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_FILL
	l.add_theme_stylebox_override("normal", _box(Color(0.86, 0.86, 0.84), Color(0.5, 0.5, 0.5), 2))
	row.add_child(l)
	_labels[key] = l
	l.set_meta("title", title)
	var plus := _button(row, "+", func(): office.step_setting(key, 1))
	plus.custom_minimum_size = Vector2(ROW_H, ROW_H)
	plus.size_flags_horizontal = Control.SIZE_SHRINK_END


func _build_controls(parent: Node) -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.visible = false
	parent.add_child(page)
	_pages["controls"] = page
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.draw.connect(_draw_card)
	page.add_child(_card)
	_first["controls"] = _button(page, "BACK", func(): _show("main"))


func _build_confirm(parent: Node) -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.visible = false
	parent.add_child(page)
	_pages["confirm"] = page
	var ask := _text("WIPE ALL PROGRESS?\n\nDale, the ladder, the coworkers, relics, tips and the desk games' saves. Settings stay.", 16, INK)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask.custom_minimum_size = Vector2(0, 150)
	page.add_child(ask)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	page.add_child(row)
	_first["confirm"] = _button(row, "NO", func(): _show("main"))
	var yes := _button(row, "YES, WIPE", func(): office.new_game())
	yes.add_theme_color_override("font_color", Color(0.6, 0.08, 0.06))
	for b in row.get_children():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _show(page: String) -> void:
	_page = page
	for k in _pages:
		_pages[k].visible = k == page
	_title.text = {"main": "OPTIONS.EXE", "controls": "CONTROLS.TXT", "confirm": "NEW GAME"}[page]
	_layout()
	if _cursor:
		_cursor.focus(_first[page])
	_card.queue_redraw()


# ---------------------------------------------------------------- open / close

func open(by_pad: bool) -> void:
	visible = true
	refresh()
	_show("main")
	_cursor = PadUI.new()
	add_child(_cursor)
	_cursor.focus(_first.main)
	if by_pad:
		_cursor.active = true


func close() -> void:
	visible = false
	if _cursor:
		_cursor.queue_free()
		_cursor = null


## Labels from the office's current settings.
func refresh() -> void:
	for key in ["music", "effects"]:
		_labels[key].text = "%s\n%d%%" % [_labels[key].get_meta("title"), roundi(float(office.setting(key)) * 100.0)]
	_labels.look_speed.text = "LOOK SPEED\nx%.2f" % float(office.setting("look_speed"))
	_labels.invert_y.text = "INVERT Y: " + ("ON" if office.setting("invert_y") else "OFF")
	_labels.screens.text = "SCREENS: LOOK " + ("A" if office.look_index() == 0 else "B")
	_labels.look_busy.text = "LOOK BUSY: " + ("ON" if office.setting("look_busy") else "OFF")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var back := false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		back = true
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_START]:
		back = true
	if not back:
		return
	get_viewport().set_input_as_handled()
	if _page != "main":
		_show("main")
	else:
		office.close_menu(event is InputEventKey)


# ---------------------------------------------------------------- layout

## Upright: one column. Sideways: two, so it fits the short screen.
func _layout() -> void:
	var view := get_viewport_rect().size
	var wide := view.x > view.y
	position = Vector2.ZERO
	size = view
	var inset: Vector4 = office._inset if office else Vector4.ZERO
	_margin.add_theme_constant_override("margin_left", int(16 + inset.x))
	_margin.add_theme_constant_override("margin_top", int(16 + inset.y))
	_margin.add_theme_constant_override("margin_right", int(16 + inset.z))
	_margin.add_theme_constant_override("margin_bottom", int(16 + inset.w))
	_grid.columns = 2 if wide else 1
	var w := minf(view.x - 32.0 - inset.x - inset.z, 1100.0 if wide else 620.0)
	var cell := (w - 32.0 - (16.0 if wide else 0.0)) / (2.0 if wide else 1.0)
	for c in _grid.get_children():
		c.custom_minimum_size.x = cell
	for k in ["controls", "confirm"]:
		_pages[k].custom_minimum_size.x = minf(w - 32.0, 620.0)
	_card.custom_minimum_size = Vector2(minf(w - 32.0, 620.0), 46.0 * office.PAD_CARD.size() + 60.0) if office else Vector2.ZERO
	_window.reset_size()


func _draw_card() -> void:
	PadUI.draw_card(_card, _card.size, office.PAD_CARD, _card.size.x / 620.0 * 1.0, 1.0, -20.0)


# ---------------------------------------------------------------- widgets

func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 20)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, INK)
	b.add_theme_stylebox_override("normal", _box(Color(0.84, 0.84, 0.82), Color(0.98, 0.98, 0.96), 4, Color(0.3, 0.3, 0.3)))
	b.add_theme_stylebox_override("hover", _box(Color(0.9, 0.9, 0.88), Color(0.98, 0.98, 0.96), 4, Color(0.3, 0.3, 0.3)))
	b.add_theme_stylebox_override("pressed", _box(Color(0.66, 0.66, 0.64), Color(0.3, 0.3, 0.3), 4))
	b.pressed.connect(func():
		action.call()
		if visible:
			refresh())
	parent.add_child(b)
	return b


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A flat 90s bevel: fill, a light rim, and a dark drop on the bottom/right.
func _box(fill: Color, rim: Color, width: int, drop := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = rim
	s.set_border_width_all(width)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	if drop.a > 0.0:
		s.shadow_color = drop
		s.shadow_size = 0
		s.shadow_offset = Vector2(4, 4)
		s.shadow_size = 1
	return s
