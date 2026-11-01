extends Control
## Look Busy's pop-up window (a 90s dialog like the pause menu): the morning
## card, getting caught (warning, write-up, fired), clocking out, and later
## ship day. It pauses the office while it's up and runs PROCESS_MODE_ALWAYS.
## Buttons are 88 px tall so touch, mouse and the pad cursor all work.

const FONT := preload("res://fonts/press_start_2p.ttf")
const GREY := Color(0.76, 0.76, 0.74)
const NAVY := Color(0.06, 0.14, 0.6)
const INK := Color(0.08, 0.08, 0.1)

var office: Node
var _window: PanelContainer
var _margin: MarginContainer
var _title: Label
var _head: Label
var _body: Label
var _buttons: VBoxContainer
var _cursor: Node
var _was_paused := false
var _bar: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.65)
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
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", _box(NAVY, NAVY, 0))
	col.add_child(_bar)
	_title = _text("", 18, Color.WHITE)
	_bar.add_child(_title)
	var body := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 18)
	col.add_child(body)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	body.add_child(stack)
	_head = _text("", 30, INK)
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_head)
	_body = _text("", 15, INK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_constant_override("line_spacing", 8)
	stack.add_child(_body)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	stack.add_child(_buttons)
	get_viewport().size_changed.connect(_layout)


## title: the window's title bar. head: the big line. buttons: [[text,
## Callable], ...]; any button closes the window first, then runs its action.
## accent: the head's colour.
func show_notice(title: String, head: String, body: String, buttons: Array, accent := INK) -> void:
	_title.text = title
	_head.text = head
	_head.visible = head != ""
	_head.add_theme_color_override("font_color", accent)
	_body.text = body
	_body.visible = body != ""
	for c in _buttons.get_children():
		c.queue_free()
	var first: Button
	for spec in buttons:
		var b := _button(spec[0], spec[1])
		_buttons.add_child(b)
		if first == null:
			first = b
	if not visible:
		_was_paused = get_tree().paused
	visible = true
	get_tree().paused = true
	if office:
		office.release_for_overlay()
	_layout()
	if _cursor == null:
		_cursor = preload("res://scenes/pad_cursor.gd").new()
		add_child(_cursor)
	if first:
		_cursor.focus.call_deferred(first)
		_cursor.active = office != null and office._pad


func close() -> void:
	visible = false
	get_tree().paused = _was_paused
	if _cursor:
		_cursor.queue_free()
		_cursor = null


func _layout() -> void:
	var view := get_viewport_rect().size
	var inset: Vector4 = office._inset if office else Vector4.ZERO
	_margin.add_theme_constant_override("margin_left", int(16 + inset.x))
	_margin.add_theme_constant_override("margin_top", int(16 + inset.y))
	_margin.add_theme_constant_override("margin_right", int(16 + inset.z))
	_margin.add_theme_constant_override("margin_bottom", int(16 + inset.w))
	var w := minf(view.x - 32.0 - inset.x - inset.z, 760.0)
	_body.custom_minimum_size.x = w - 40.0
	_head.custom_minimum_size.x = w - 40.0
	# Sideways the body text gets smaller so it fits the short screen.
	_body.add_theme_font_size_override("font_size", 13 if view.y < 800 else 15)
	_head.add_theme_font_size_override("font_size", 24 if view.y < 800 else 30)
	_window.reset_size()


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 88)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 18)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, INK)
	b.add_theme_stylebox_override("normal", _box(Color(0.84, 0.84, 0.82), Color(0.98, 0.98, 0.96), 4, Color(0.3, 0.3, 0.3)))
	b.add_theme_stylebox_override("hover", _box(Color(0.9, 0.9, 0.88), Color(0.98, 0.98, 0.96), 4, Color(0.3, 0.3, 0.3)))
	b.add_theme_stylebox_override("pressed", _box(Color(0.66, 0.66, 0.64), Color(0.3, 0.3, 0.3), 4))
	b.pressed.connect(func():
		close()
		action.call())
	return b


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


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
		s.shadow_offset = Vector2(4, 4)
		s.shadow_size = 1
	return s
