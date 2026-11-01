extends Control
## Look Busy's alt-tab screen: a fake 90s spreadsheet that covers whatever
## game you're sitting at (scenes/office/look_busy.gd swaps it onto the
## screen). Fake work is its own tiny game: tap the yellow cells to "type"
## numbers into them; fill every yellow cell and the report totals up and a
## new batch appears. While the boss watches, working here cools suspicion.
## Every control is a Button (88 px or taller), so touch, mouse and the pad
## cursor all work. It lays itself out for tall (720x1280) or wide (1280x720)
## screens.

signal filled

const FONT := preload("res://fonts/press_start_2p.ttf")
const NAVY := Color(0.06, 0.14, 0.6)
const GREY := Color(0.76, 0.76, 0.74)
const INK := Color(0.08, 0.08, 0.1)
const ROW_H := 92.0
const TARGETS := 4
const FILES := ["Q3_TPS_REPORT.XLS", "BUDGET_FINAL_v7.XLS", "SYNERGY_MATRIX.XLS", "HEADCOUNT.XLS", "KPI_KPI_KPI.XLS"]

var title_text := "Q3_TPS_REPORT.XLS"
var _grid: GridContainer
var _cells: Array[Button] = []
var _todo: Array[int] = []
var _status: Label
var _formula: Label
var _bar_title: Label
var _done_today := 0
var _reports := 0
var _built_for := Vector2.ZERO
var _click: AudioStreamPlayer
var _ding: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_click = AudioStreamPlayer.new()
	_click.stream = preload("res://audio/click.wav")
	add_child(_click)
	_ding = AudioStreamPlayer.new()
	_ding.stream = preload("res://audio/ding.wav")
	_ding.volume_db = -6.0
	add_child(_ding)
	add_child(preload("res://scenes/pad_cursor.gd").new())
	resized.connect(_build)
	_build()


## A new file each time you alt-tab in.
func open(cells_today: int) -> void:
	_done_today = cells_today
	title_text = FILES[_rng.randi_range(0, FILES.size() - 1)]
	if _bar_title:
		_bar_title.text = title_text + " - SPREADSHEET 95"
	_build(true)


func _build(force := false) -> void:
	var s := get_viewport_rect().size
	if s.x <= 0 or (not force and s == _built_for):
		return
	_built_for = s
	for c in get_children():
		if c is Control:
			c.queue_free()
	_cells.clear()
	var wide := s.x > s.y
	var back := ColorRect.new()
	back.color = Color(0.0, 0.5, 0.5)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	# Title bar and menus (left clear: the office's STAND UP button sits there).
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(NAVY, NAVY, 0))
	bar.custom_minimum_size = Vector2(0, 56)
	col.add_child(bar)
	_bar_title = _text(title_text + " - SPREADSHEET 95", 16 if wide else 13, Color.WHITE)
	_bar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bar_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_bar_title)
	var menu := PanelContainer.new()
	menu.add_theme_stylebox_override("panel", _box(GREY, GREY, 0))
	col.add_child(menu)
	var menu_l := _text("FILE  EDIT  VIEW  INSERT  FORMAT  DATA", 13, INK)
	menu_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu.add_child(menu_l)
	var fx := PanelContainer.new()
	fx.add_theme_stylebox_override("panel", _box(Color.WHITE, Color(0.5, 0.5, 0.5), 2))
	col.add_child(fx)
	_formula = _text("", 14, INK)
	fx.add_child(_formula)
	# The sheet.
	var cols := 7 if wide else 5
	var bottom := 64.0
	var top := 56.0 + 40.0 + 44.0 + 8.0
	var rows := maxi(3, int((s.y - top - bottom - 40.0) / ROW_H))
	_grid = GridContainer.new()
	_grid.columns = cols + 1
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_grid)
	var cell_w := (s.x - 60.0 - 2.0 * cols) / cols
	_grid.add_child(_head("", 58))
	for c in cols:
		_grid.add_child(_head(String.chr(65 + c), cell_w))
	for r in rows:
		_grid.add_child(_head(str(r + 1), 58, ROW_H))
		for c in cols:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(cell_w, ROW_H)
			b.add_theme_font_override("font", FONT)
			b.add_theme_font_size_override("font_size", 18)
			for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(state, INK)
			b.text = _number() if _rng.randf() < 0.55 else ""
			var i := _cells.size()
			b.pressed.connect(_tap.bind(i))
			_grid.add_child(b)
			_cells.append(b)
	_status = _text("", 13, INK)
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", _box(GREY, GREY, 0))
	foot.custom_minimum_size = Vector2(0, 48)
	foot.add_child(_status)
	col.add_child(foot)
	_new_batch()


func _new_batch() -> void:
	_todo.clear()
	var free: Array = range(_cells.size())
	for k in TARGETS:
		if free.is_empty():
			break
		var i: int = free.pop_at(_rng.randi_range(0, free.size() - 1))
		_todo.append(i)
		_cells[i].text = "?"
	for i in _cells.size():
		_style(i)
	_update_status()


func _tap(i: int) -> void:
	if not _todo.has(i):
		return
	_todo.erase(i)
	_cells[i].text = _number()
	_style(i)
	_done_today += 1
	_click.pitch_scale = _rng.randf_range(0.9, 1.2)
	_click.play()
	filled.emit()
	if _todo.is_empty():
		_reports += 1
		_ding.play()
		_formula.text = " =SUM(TOTAL)  REPORT %d DONE. NICE WORK." % _reports
		_new_batch()
		_formula.text = " =SUM(TOTAL)  REPORT %d DONE. NICE WORK." % _reports
		return
	_update_status()


func _update_status() -> void:
	if _status:
		_status.text = " FILL THE YELLOW CELLS.  CELLS TODAY: %d" % _done_today
	if _formula and not _formula.text.contains("DONE"):
		_formula.text = " =SUM(B2:B%d)*SYNERGY" % (2 + _cells.size() / 5)


func _style(i: int) -> void:
	var b := _cells[i]
	var todo := _todo.has(i)
	var fill := Color(1.0, 0.92, 0.3) if todo else Color.WHITE
	var n := _box(fill, Color(0.6, 0.6, 0.6), 1)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", _box(fill.darkened(0.05), NAVY, 2))
	b.add_theme_stylebox_override("pressed", _box(fill.darkened(0.15), NAVY, 2))
	b.add_theme_stylebox_override("focus", n)


func _number() -> String:
	return str(_rng.randi_range(10, 9999))


func _head(t: String, w: float, h := 40.0) -> Label:
	var l := _text(t, 13, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(w, h)
	l.add_theme_stylebox_override("normal", _box(GREY, Color(0.55, 0.55, 0.55), 1))
	return l


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	return l


func _box(fill: Color, rim: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = rim
	s.set_border_width_all(width)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
