extends Control
## Look Busy's title screen (docs/look-busy.md): shown once each time the
## office starts with Look Busy on, before you clock in. A looping cartoon
## (BusyDemo, below), filmed live in the real 3D office, plays the whole loop with no reading needed: you play a
## game at your desk, the boss walks in, you alt-tab to a spreadsheet and get
## away with it (or you don't, and get a strike), then your own game ships.
## Three rule lines say the same in words. Nothing past floor 1 is named, so
## the bosses upstairs, the ladder and Dale's secret stay to be found.
## It pauses the office while it's up and runs PROCESS_MODE_ALWAYS. Buttons
## are 88 px tall: touch, mouse and the pad cursor all work. Enter / Space /
## A clocks in.

signal clocked_in

const FONT := preload("res://fonts/press_start_2p.ttf")
const YELLOW := Color(1.0, 0.86, 0.25)
const INK := Color(0.08, 0.08, 0.1)
## The three rules, with the colour of the HUD bar each one maps to.
const RULES := [
	[Color(0.3, 0.85, 0.35), "PLAY GAMES AT WORK", "Every minute fills your SLACK meter. Hit the day's quota."],
	[Color(0.95, 0.25, 0.2), "DON'T GET CAUGHT", "Boss near? ALT-TAB to a spreadsheet. Seen playing = suspicion. 3 strikes = fired."],
	[Color(1.0, 0.45, 0.8), "SHIP YOUR GAME FRIDAY", "Beat desk games for pieces. Good reviews = promoted a floor."],
]

var office: Node
var busy: Node
var _box: BoxContainer
var _margin: MarginContainer
var _logo: Label
var _demo: Control
var _side: VBoxContainer
var _rule_texts: Array[Label] = []
var _records: Label
var _controls: Label
var _go: Button
var _options: Button
var _cursor: Node
var _t := 0.0
var _waiting_menu := false
## Web only: browsers hold sound until the first tap (office_music.gd).
var _sound_hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	_box = BoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 18)
	_margin.add_child(_box)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(head)
	_logo = _label("LOOK BUSY", 56, YELLOW, 14)
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_logo)
	var tag := _label("A GAME ABOUT PLAYING GAMES AT WORK", 14, Color(1, 1, 1, 0.85), 6)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(tag)
	_sound_hint = _label("TAP ANYWHERE FOR MUSIC", 12, YELLOW, 4)
	_sound_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sound_hint.visible = false
	head.add_child(_sound_hint)
	_demo = BusyDemo.new()
	_demo.office = office
	_demo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_demo)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 12)
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(_side)
	for i in RULES.size():
		_side.add_child(_rule(i))
	var tease := _label("Get promoted, go up a floor. Nobody has seen the top one.", 12, Color(1, 1, 1, 0.6), 4)
	tease.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tease.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_side.add_child(tease)
	_records = _label("", 12, YELLOW, 4)
	_records.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_records.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_side.add_child(_records)
	_go = _button("CLOCK IN", YELLOW, 26)
	_go.custom_minimum_size.y = 104
	_go.pressed.connect(_clock_in)
	_side.add_child(_go)
	_controls = _label("", 11, Color(1, 1, 1, 0.7), 4)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_side.add_child(_controls)
	_options = _button("OPTIONS", Color(0.8, 0.8, 0.78), 16)
	_options.pressed.connect(_open_options)
	_side.add_child(_options)
	get_viewport().size_changed.connect(_layout)


func open() -> void:
	_t = 0.0
	_demo.office = office
	_demo.reset()
	_demo.go_live(true)
	_refresh()
	visible = true
	get_tree().paused = true
	if office:
		office.release_for_overlay()
	_layout()
	if _cursor == null:
		_cursor = preload("res://scenes/pad_cursor.gd").new()
		add_child(_cursor)
	_cursor.focus.call_deferred(_go)
	_cursor.active = office != null and office._pad


func close() -> void:
	visible = false
	_demo.go_live(false)
	_waiting_menu = false
	if _cursor:
		_cursor.queue_free()
		_cursor = null
	get_tree().paused = false


func _clock_in() -> void:
	close()
	clocked_in.emit()


## OPTIONS: the office's pause menu; back here when it closes.
func _open_options() -> void:
	if office == null:
		return
	visible = false
	_demo.go_live(false)
	get_tree().paused = false
	_waiting_menu = true
	office._open_menu(office._pad)


func _process(delta: float) -> void:
	if _waiting_menu:
		if busy and not busy.enabled:
			_waiting_menu = false
		elif office and office._menu and not office._menu.visible:
			_waiting_menu = false
			open()
		return
	if not visible:
		return
	_t += delta
	var music: Node = office.get("_hub_music") if office else null
	_sound_hint.visible = OS.has_feature("web") and music != null and not music.started
	if _sound_hint.visible:
		_sound_hint.modulate.a = 0.55 + 0.45 * sin(_t * 4.0)
	# The logo breathes a little; the button pulses so the first tap is obvious.
	_logo.pivot_offset = _logo.size * 0.5
	_logo.rotation = sin(_t * 1.3) * 0.025
	_go.pivot_offset = _go.size * 0.5
	var s := 1.0 + 0.03 * maxf(0.0, sin(_t * 4.0))
	_go.scale = Vector2(s, s)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var go := false
	if event is InputEventKey and event.pressed and not event.echo:
		go = event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	if go:
		get_viewport().set_input_as_handled()
		_clock_in()


## Records, the button's words and the controls line for this run and device.
func _refresh() -> void:
	if busy == null:
		return
	var wd: Workday = busy.wd
	var fresh: bool = wd.runs <= 1 and wd.week <= 1 and wd.day == 0 and wd.minutes <= 0.0
	_go.text = "CLOCK IN" if fresh else "CLOCK BACK IN\n%s, FLOOR %d" % [BusyLines.DAYS[clampi(wd.day, 0, 4)], wd.floor_i]
	_go.add_theme_font_size_override("font_size", 26 if fresh else 18)
	var rec: Array[String] = []
	if wd.best_slack > Workday.MORNING_COFFEE:
		rec.append("BEST DAY: %s SLACKED" % Workday.hours_text(wd.best_slack))
	if wd.best_floor > 1:
		rec.append("BEST FLOOR: %d" % wd.best_floor)
	if office and office._ladder:
		var st: LadderState = office._ladder.state
		var tot := DeskGoals.total(DaleStory.read_stats(), st.best, Array(st.beaten))
		if tot.x > 0:
			rec.append("DESK STARS: %d/%d ★" % [tot.x, tot.y])
	if wd.runs > 1:
		rec.append("FIRED %d TIME%s" % [wd.runs - 1, "" if wd.runs == 2 else "S"])
	_records.text = "  ".join(rec)
	_records.visible = not rec.is_empty()
	var pad: bool = office != null and office._pad
	var touch: bool = office != null and (office._touch or DisplayServer.is_touchscreen_available()) and not pad
	if pad:
		_controls.text = "STICKS: WALK + LOOK.  A: SIT AT A SCREEN.  Y: ALT-TAB."
	elif touch:
		_controls.text = "STICK: WALK.  TAP A SCREEN TO SIT.  ALT-TAB: TOP RIGHT."
	else:
		_controls.text = "WASD + MOUSE: WALK.  CLICK A SCREEN TO SIT.  TAB: ALT-TAB."


func _layout() -> void:
	var view := get_viewport_rect().size
	var wide := view.x > view.y
	var inset: Vector4 = office._inset if office else Vector4.ZERO
	_margin.add_theme_constant_override("margin_left", int(24 + inset.x))
	_margin.add_theme_constant_override("margin_top", int(20 + inset.y))
	_margin.add_theme_constant_override("margin_right", int(24 + inset.z))
	_margin.add_theme_constant_override("margin_bottom", int(20 + inset.w))
	_box.vertical = not wide
	_logo.add_theme_font_size_override("font_size", 48 if wide else 56)
	_demo.custom_minimum_size = Vector2(0, 300 if wide else 380)
	_side.custom_minimum_size.x = 520 if wide else 0
	var body := 12 if wide else 13
	for l in _rule_texts:
		l.add_theme_font_size_override("font_size", body)


func _draw() -> void:
	# A dark office-blue backdrop with faint scanlines, over the dimmed world.
	var r := get_rect()
	draw_rect(Rect2(Vector2.ZERO, r.size), Color(0.03, 0.04, 0.12, 0.96))
	var y := 0.0
	while y < r.size.y:
		draw_rect(Rect2(0, y, r.size.x, 1), Color(1, 1, 1, 0.025))
		y += 4.0


func _rule(i: int) -> Control:
	var spec: Array = RULES[i]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var chip := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = spec[0]
	st.set_corner_radius_all(4)
	chip.add_theme_stylebox_override("panel", st)
	chip.custom_minimum_size = Vector2(48, 48)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n := _label(str(i + 1), 22, INK, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(n)
	row.add_child(chip)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := _label(spec[1], 16, spec[0], 6)
	col.add_child(h)
	var t := _label(spec[2], 13, Color(1, 1, 1, 0.9), 4)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_constant_override("line_spacing", 4)
	col.add_child(t)
	_rule_texts.append(t)
	row.add_child(col)
	return row


func _label(text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, fill: Color, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 88)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, INK)
	b.add_theme_stylebox_override("normal", _style(fill, Color(0.98, 0.98, 0.96)))
	b.add_theme_stylebox_override("hover", _style(fill.lightened(0.15), Color(0.98, 0.98, 0.96)))
	b.add_theme_stylebox_override("pressed", _style(fill.darkened(0.25), Color(0.3, 0.3, 0.3)))
	return b


func _style(fill: Color, rim: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = rim
	s.set_border_width_all(4)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_offset = Vector2(4, 4)
	s.shadow_size = 1
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## The cartoon, shot live in the real office: a camera up in the corner by
## the door films a stand-in you at your desk (Pong on the screen) while a
## stand-in Marge walks in behind you. The tree is paused while the title is
## up, so this class moves everything itself. The HUD bars, captions, the
## STRIKE stamp and the shipped game are drawn on top in a 600x360 design box,
## scaled to fit. Every other loop you're too slow and get a strike, so both
## outcomes are shown. Without an office (or before go_live) it falls back to
## the flat drawn side view.
class BusyDemo:
	extends Control

	const W := 600.0
	const H := 360.0
	const LOOP := 13.0
	const DOOR_X := 75.0
	const STOP_X := 262.0
	const FONT := preload("res://fonts/press_start_2p.ttf")
	const SKIN := Color(0.92, 0.74, 0.6)
	const BOSS_SHIRT := Color(0.62, 0.18, 0.24)
	const MY_SHIRT := Color(0.2, 0.42, 0.75)
	## The shot: up in the corner by the door, looking past you at the screen.
	const CAM_POS := Vector3(1.0, 1.8, 0.3)
	const CAM_AT := Vector3(-0.35, 1.0, -2.2)
	const SHRINK := 2
	## You, seated a little left of the screen so the camera sees past you.
	const YOU_AT := Vector3(-0.3, 0.0, -1.6)
	const YOU_LOOK := {"skin": Color(0.92, 0.74, 0.6), "shirt": Color(0.2, 0.42, 0.75),
		"pants": Color(0.2, 0.22, 0.3), "hair": Color(0.25, 0.18, 0.12)}
	## The boss's walk in: doorway, across the carpet, stop just behind you.
	const WALK := [Vector2(1.8, 4.4), Vector2(0.3, 1.2), Vector2(-0.85, -0.75)]

	var t := 0.0
	var office: Node
	var _live := false
	var _box3d: SubViewportContainer
	var _vp: SubViewport
	var _cam: Camera3D
	var _you: Node3D
	var _you_head: Node3D
	var _boss3d: Node3D
	var _pc
	var _old_cover: Viewport
	var _screen_vp: SubViewport
	var _art: ScreenArt
	var _world_mode := SubViewport.UPDATE_ALWAYS
	var _k := 1.0
	var _off := Vector2.ZERO

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func reset() -> void:
		t = 0.0

	## Start (or stop) filming the office. Safe to call without an office.
	func go_live(on: bool) -> void:
		if on == _live:
			return
		if on and not _build():
			return
		_live = on
		_box3d.visible = on
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		_screen_vp.render_target_update_mode = _vp.render_target_update_mode
		_you.visible = on
		_boss3d.visible = false
		# The office's own view is hidden under the title: stop drawing it.
		var wv: SubViewport = office._world_vp
		if on:
			_world_mode = wv.render_target_update_mode
			wv.render_target_update_mode = SubViewport.UPDATE_DISABLED
		else:
			wv.render_target_update_mode = _world_mode
		if _pc:
			if on:
				_old_cover = _pc.cover
				_pc.set_cover(_screen_vp)
			elif _pc.cover == _screen_vp:
				_pc.set_cover(_old_cover)
		queue_redraw()

	func _build() -> bool:
		if _vp:
			return true
		if office == null or office._ladder == null or office._world_vp == null:
			return false
		_box3d = SubViewportContainer.new()
		_box3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_box3d.stretch = true
		_box3d.stretch_shrink = SHRINK
		_box3d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_box3d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Under this control's own drawing, so the HUD sits on the picture.
		_box3d.show_behind_parent = true
		add_child(_box3d)
		_vp = SubViewport.new()
		_vp.world_3d = office._world_vp.world_3d
		_vp.gui_disable_input = true
		_vp.audio_listener_enable_3d = false
		_box3d.add_child(_vp)
		_cam = Camera3D.new()
		_cam.cull_mask = office.LAYER_WORLD
		_cam.fov = 52.0
		_cam.near = 0.05
		_cam.far = 30.0
		_vp.add_child(_cam)
		_cam.current = true
		_cam.position = CAM_POS
		_cam.look_at_from_position(CAM_POS, CAM_AT)
		# The main screen shows our Pong / spreadsheet instead of the paused game.
		_screen_vp = SubViewport.new()
		_screen_vp.size = Vector2i(640, 360)
		_screen_vp.disable_3d = true
		_screen_vp.gui_disable_input = true
		add_child(_screen_vp)
		_art = ScreenArt.new()
		_art.demo = self
		_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_screen_vp.add_child(_art)
		for pc in office._computers:
			if pc.view == office._game_vp:
				_pc = pc
		# Stand-ins ("boss_" ids keep them out of the talk list).
		var ladder: Node = office._ladder
		_you = ladder._person("office", "boss_title_you", YOU_AT, PI, YOU_LOOK, true)
		_you_head = ladder._people["boss_title_you"].head
		var fabric: Material = office._mat(Color(0.2, 0.22, 0.3))
		var dark: Material = office._mat(Color(0.1, 0.1, 0.12))
		office._box(Vector3(0.48, 0.08, 0.46), Vector3(0, 0.48, 0), fabric, false, Vector3.ZERO, _you)
		office._box(Vector3(0.4, 0.22, 0.06), Vector3(0, 0.66, -0.24), fabric, false, Vector3(0.1, 0, 0), _you)
		office._box(Vector3(0.06, 0.44, 0.06), Vector3(0, 0.22, 0), dark, false, Vector3.ZERO, _you)
		office._box(Vector3(0.5, 0.04, 0.06), Vector3(0, 0.03, 0), dark, false, Vector3.ZERO, _you)
		office._box(Vector3(0.06, 0.04, 0.5), Vector3(0, 0.03, 0), dark, false, Vector3.ZERO, _you)
		var b: Dictionary = BusyLines.BOSSES[0]
		_boss3d = ladder._person("office", "boss_title_boss", Vector3(WALK[0].x, 0, WALK[0].y), PI, b.look_body)
		_you.visible = false
		_boss3d.visible = false
		return true

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			t += delta
			if _live:
				_pose(fmod(t, LOOP), int(t / LOOP) % 2 == 1)
			queue_redraw()

	func _draw() -> void:
		_k = minf(size.x / W, size.y / H)
		_off = (size - Vector2(W, H) * _k) * 0.5
		draw_set_transform(_off, 0.0, Vector2(_k, _k))
		var lt := fmod(t, LOOP)
		var caught := int(t / LOOP) % 2 == 1
		_scene(lt, caught)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ------------------------------------------------------------ the 3D shot

	## Boss on the carpet at loop time lt: {pos (x, z), yaw, walking}, or {} when out.
	func _boss_at(lt: float) -> Dictionary:
		if lt < 3.6 or lt > 10.6:
			return {}
		var k := 0.0
		var walking := true
		if lt < 6.4:
			k = (lt - 3.6) / 2.8
		elif lt < 8.6:
			k = 1.0
			walking = false
		else:
			k = 1.0 - (lt - 8.6) / 2.0
		var a: Vector2 = WALK[0]
		var m: Vector2 = WALK[1]
		var e: Vector2 = WALK[2]
		var l1 := a.distance_to(m)
		var d := k * (l1 + m.distance_to(e))
		var pos := a.lerp(m, d / l1) if d < l1 else m.lerp(e, (d - l1) / m.distance_to(e))
		var dir := (m - a) if d < l1 else (e - m)
		if lt >= 8.6:
			dir = -dir
		var yaw := atan2(dir.x, dir.y)
		if not walking:
			# Stopped: she looks over your shoulder at the screen.
			var to := Vector2(0.0, -2.4) - e
			yaw = atan2(to.x, to.y)
		return {"pos": pos, "yaw": yaw, "walking": walking}

	func _pose(lt: float, caught: bool) -> void:
		var tabbed := _alt_tabbed(lt, caught)
		var strike := caught and lt >= 7.3 and lt < 10.0
		# A slow drift, like a camera on a shoulder; a jolt on the strike.
		var drift := Vector3(sin(t * 0.23) * 0.18, sin(t * 0.31) * 0.06, cos(t * 0.19) * 0.1)
		if strike:
			drift += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.02 * clampf(8.0 - lt, 0.0, 1.0)
		_cam.look_at_from_position(CAM_POS + drift, CAM_AT)
		# You: bopping along while you play; still and stiff once you alt-tab.
		var body: Node3D = _you.get_child(0)
		body.position.y = -0.42 + (absf(sin(lt * 6.0)) * 0.015 if not tabbed else 0.0)
		var bx := _boss_at(lt)
		var glance := 0.0
		if not bx.is_empty() and lt >= 4.2 and lt < 5.4:
			glance = -1.0
		_you_head.rotation.y = lerp_angle(_you_head.rotation.y, glance, 0.15)
		_boss3d.visible = not bx.is_empty()
		if _boss3d.visible:
			_boss3d.position = Vector3(bx.pos.x, 0.0, bx.pos.y)
			_boss3d.rotation.y = bx.yaw
			var bb: Node3D = _boss3d.get_child(0)
			bb.position.y = absf(sin(lt * 9.0)) * 0.04 if bx.walking else 0.0
			bb.rotation.z = sin(lt * 9.0) * 0.04 if bx.walking else 0.0
		_art.tabbed = tabbed
		_art.lt = lt
		_art.queue_redraw()

	## A world point in design-box coordinates (or null behind the camera).
	func _to_box(w: Vector3):
		if _cam.is_position_behind(w):
			return null
		var p := _cam.unproject_position(w) * float(SHRINK)
		return (p - _off) / _k

	## The marks the 3D can't draw: "!", speech, the ALT-TAB key, slack ticks.
	func _marks(lt: float, caught: bool, tabbed: bool) -> void:
		var bx := _boss_at(lt)
		if not bx.is_empty() and lt < 9.0 and (not caught or lt < 7.3):
			var at = _to_box(YOU_AT + Vector3(0, 1.62, 0))
			if at != null:
				var pop := 1.0 + 0.2 * maxf(0.0, sin(lt * 10.0))
				draw_string_outline(FONT, at - Vector2(10, 0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * pop), 8, Color.BLACK)
				draw_string(FONT, at - Vector2(10, 0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * pop), Color(1.0, 0.85, 0.2))
		if not bx.is_empty() and lt >= 6.4 and lt < 8.6:
			var at = _to_box(Vector3(bx.pos.x, 2.0, bx.pos.y))
			if at != null:
				at.x = clampf(at.x, 90.0, W - 90.0)
				at.y = maxf(at.y - 44.0, 70.0)
				_bubble(at, "A GAME?!" if caught else "...CARRY ON.", Color(1.0, 0.9, 0.9) if caught else Color(1, 1, 1))
		if _pc and (lt < 5.5 or lt > 10.6):
			var top = _to_box(_pc.screen.global_position + Vector3(0, 0.3, 0))
			if top != null:
				var f := fmod(lt, 1.2) / 1.2
				var p: Vector2 = top - Vector2(30, f * 34)
				draw_string_outline(FONT, p, "+0:10", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 5, Color(0, 0, 0, 1.0 - f))
				draw_string(FONT, p, "+0:10", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 1.0, 0.45, 1.0 - f))
		_key(lt, caught, Vector2(W - 150, 236))

	## The key you press: ALT-TAB.
	func _key(lt: float, caught: bool, at: Vector2) -> void:
		if caught or lt < 5.2 or lt >= 6.6:
			return
		var press := lt >= 5.5 and lt < 5.8
		var kr := Rect2(at + Vector2(0, 6 if press else 0), Vector2(120, 38))
		draw_rect(Rect2(kr.position + Vector2(4, 4), kr.size), Color(0, 0, 0, 0.5))
		draw_rect(kr, Color(1, 1, 1) if not press else Color(1.0, 0.86, 0.25))
		draw_rect(kr, Color(0.1, 0.1, 0.1), false, 3.0)
		draw_string(FONT, kr.position + Vector2(10, 26), "ALT-TAB", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.08, 0.08, 0.1))

	## What's on your monitor in the shot: Pong, or the spreadsheet.
	class ScreenArt:
		extends Control
		var demo
		var tabbed := false
		var lt := 0.0

		func _draw() -> void:
			var r := Rect2(Vector2.ZERO, size)
			draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(116, 80))
			var box := Rect2(0, 0, 116, 80)
			if tabbed:
				demo._sheet_on(self, box)
			else:
				demo._pong_on(self, box, lt)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if not tabbed:
				return
			# A title bar so it reads as a spreadsheet even small.
			draw_rect(Rect2(0, 0, r.size.x, 40), Color(0.06, 0.14, 0.6))
			draw_string(FONT, Vector2(12, 30), "Q3_TPS_FINAL.XLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1))

	# ------------------------------------------------------------ timeline

	## Boss x along the floor (or -1: not in the room).
	func _boss_x(lt: float) -> float:
		if lt < 3.6 or lt > 10.6:
			return -1.0
		if lt < 6.4:
			return lerpf(DOOR_X, STOP_X, (lt - 3.6) / 2.8)
		if lt < 8.6:
			return STOP_X
		return lerpf(STOP_X, DOOR_X, (lt - 8.6) / 2.0)

	func _door_open(lt: float) -> float:
		if lt < 3.3 or lt > 11.0:
			return 0.0
		if lt < 3.7:
			return (lt - 3.3) / 0.4
		if lt > 10.6:
			return 1.0 - (lt - 10.6) / 0.4
		return 1.0

	func _alt_tabbed(lt: float, caught: bool) -> bool:
		return not caught and lt >= 5.5 and lt < 10.4

	func _scene(lt: float, caught: bool) -> void:
		var bx := _boss_x(lt)
		var tabbed := _alt_tabbed(lt, caught)
		var strike := caught and lt >= 7.3 and lt < 10.0
		if _live:
			_marks(lt, caught, tabbed)
		else:
			_flat(lt, caught, tabbed, bx)
		_hud(lt, caught, tabbed, bx, strike)

	## The flat side view (no office to film).
	func _flat(lt: float, caught: bool, tabbed: bool, bx: float) -> void:
		# Room: wall, floor, clock (racing through the day), window.
		draw_rect(Rect2(0, 0, W, 292), Color(0.86, 0.79, 0.6))
		draw_rect(Rect2(0, 292, W, 68), Color(0.33, 0.4, 0.36))
		draw_rect(Rect2(0, 286, W, 6), Color(0.5, 0.38, 0.25))
		draw_rect(Rect2(420, 28, 130, 70), Color(0.62, 0.84, 0.98))
		draw_rect(Rect2(420, 28, 130, 70), Color(1, 1, 1), false, 4.0)
		draw_line(Vector2(485, 28), Vector2(485, 98), Color(1, 1, 1), 3.0)
		_clock(Vector2(320, 62), lt)
		# The door, swinging open toward you.
		var open := _door_open(lt)
		draw_rect(Rect2(DOOR_X - 48, 120, 96, 170), Color(0.25, 0.2, 0.16))
		draw_rect(Rect2(DOOR_X - 44, 124, 88 * (1.0 - 0.8 * open), 166), Color(0.58, 0.4, 0.24))
		draw_circle(Vector2(DOOR_X - 44 + 88 * (1.0 - 0.8 * open) - 10, 210), 4, Color(0.95, 0.8, 0.3))
		# The boss, behind you.
		if bx >= 0.0:
			_boss(bx, lt, caught)
		# Your desk: chair, you, the CRT.
		_desk(lt, tabbed, caught)

	func _hud(lt: float, caught: bool, tabbed: bool, bx: float, strike: bool) -> void:
		# Meters, top left (the same two bars as the real HUD).
		var slack := clampf(0.12 + minf(lt, 5.5) / 5.5 * 0.5 + (0.0 if lt < 10.6 else (lt - 10.6) * 0.1), 0.0, 1.0)
		var sus := 0.0
		if caught and lt >= 6.2:
			sus = clampf((lt - 6.2) / 1.1, 0.0, 1.0)
		if strike or (caught and lt >= 10.0):
			sus = 0.0
		_bar(Vector2(14, 14), "SLACKED", slack, Color(0.3, 0.85, 0.35))
		_bar(Vector2(14, 44), "SUSPICION", sus, Color(0.95, 0.25, 0.2))
		for i in 3:
			var r := Rect2(232 + i * 22, 46, 16, 16)
			draw_rect(r, Color(0.85, 0.15, 0.1) if caught and lt >= 7.3 and i == 0 else Color(0, 0, 0, 0.25))
			draw_rect(r, Color(0, 0, 0, 0.6), false, 2.0)
		# Danger at the edges while the boss is in the room and you're playing.
		if bx >= 0.0 and not tabbed and lt < 9.0:
			var a := 0.25 + 0.2 * sin(lt * 12.0)
			for e in 4:
				_edge(e, Color(1, 0.1, 0.05, a))
		if strike:
			draw_rect(Rect2(0, 0, W, H), Color(0.9, 0.05, 0.05, 0.25 if fmod(lt, 0.3) < 0.15 else 0.12))
			_stamp("STRIKE 1/3", Vector2(W * 0.5, 150), Color(0.95, 0.1, 0.08))
		# Your game ships: five pieces snap into a box.
		if lt >= 10.6:
			_ship(lt - 10.6)
		_caption(lt, caught)

	# ------------------------------------------------------------ pieces

	func _clock(c: Vector2, lt: float) -> void:
		draw_circle(c, 26, Color(0.98, 0.97, 0.92))
		draw_arc(c, 26, 0, TAU, 32, Color(0.2, 0.2, 0.2), 3.0)
		var m := lt / LOOP * TAU * 3.0
		draw_line(c, c + Vector2(sin(m), -cos(m)) * 20, Color(0.1, 0.1, 0.1), 2.0)
		draw_line(c, c + Vector2(sin(m / 12.0 + 0.3), -cos(m / 12.0 + 0.3)) * 13, Color(0.1, 0.1, 0.1), 3.0)

	func _boss(x: float, lt: float, caught: bool) -> void:
		var walking := (lt < 6.4 or lt > 8.6)
		var bob := absf(sin(lt * 9.0)) * 4.0 if walking else 0.0
		var y := 290.0 - bob
		var step := sin(lt * 9.0) * 8.0 if walking else 0.0
		draw_rect(Rect2(x - 14 + step, y - 52, 12, 52), Color(0.2, 0.18, 0.22))
		draw_rect(Rect2(x + 2 - step, y - 52, 12, 52), Color(0.2, 0.18, 0.22))
		draw_rect(Rect2(x - 20, y - 128, 40, 80), BOSS_SHIRT)
		draw_rect(Rect2(x - 3, y - 126, 6, 40), Color(0.2, 0.5, 0.9))
		draw_circle(Vector2(x, y - 146), 20, SKIN)
		draw_rect(Rect2(x - 22, y - 168, 44, 20), Color(0.55, 0.32, 0.16))
		draw_rect(Rect2(x - 22, y - 150, 8, 22), Color(0.55, 0.32, 0.16))
		var face := 1.0 if lt < 8.6 else -1.0
		draw_rect(Rect2(x + 2 * face - (0 if face > 0 else 14), y - 150, 14, 7), Color(0.1, 0.1, 0.1), false, 2.0)
		# She stops and looks.
		if lt >= 6.4 and lt < 8.6:
			if caught:
				_bubble(Vector2(x - 10, y - 200), "A GAME?!", Color(1.0, 0.9, 0.9))
			else:
				_bubble(Vector2(x - 10, y - 200), "...CARRY ON.", Color(1, 1, 1))

	func _desk(lt: float, tabbed: bool, caught: bool) -> void:
		# Chair and you, facing the screen (your back to the door).
		draw_rect(Rect2(318, 232, 50, 10), Color(0.15, 0.15, 0.18))
		draw_rect(Rect2(310, 176, 10, 64), Color(0.15, 0.15, 0.18))
		draw_rect(Rect2(338, 242, 8, 44), Color(0.15, 0.15, 0.18))
		var bob := sin(lt * 6.0) * 2.0 if not tabbed else 0.0
		draw_rect(Rect2(324, 178 + bob, 36, 58), MY_SHIRT)
		draw_rect(Rect2(352, 196 + bob, 40, 10), MY_SHIRT)
		draw_circle(Vector2(344, 160 + bob), 17, SKIN)
		draw_rect(Rect2(326, 142 + bob, 34, 10), Color(0.25, 0.18, 0.12))
		draw_rect(Rect2(330, 236, 36, 50), Color(0.2, 0.22, 0.3))
		# "!" over your head: you heard the door.
		var bx := _boss_x(lt)
		if bx >= 0.0 and lt < 9.0 and (not caught or lt < 7.3):
			var pop := 1.0 + 0.2 * maxf(0.0, sin(lt * 10.0))
			draw_string_outline(FONT, Vector2(338, 130), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * pop), 8, Color.BLACK)
			draw_string(FONT, Vector2(338, 130), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * pop), Color(1.0, 0.85, 0.2))
		# Desk and CRT.
		draw_rect(Rect2(372, 214, 200, 12), Color(0.55, 0.4, 0.26))
		draw_rect(Rect2(382, 226, 10, 62), Color(0.45, 0.32, 0.2))
		draw_rect(Rect2(552, 226, 10, 62), Color(0.45, 0.32, 0.2))
		draw_rect(Rect2(400, 112, 140, 100), Color(0.8, 0.76, 0.66))
		draw_rect(Rect2(400, 112, 140, 100), Color(0.4, 0.38, 0.33), false, 3.0)
		var scr := Rect2(412, 122, 116, 80)
		if tabbed:
			_sheet(scr)
		else:
			_pong(scr, lt)
		_key(lt, caught, Vector2(400, 240))

	func _pong(r: Rect2, lt: float) -> void:
		_pong_on(self, r, lt)
		# Slack ticking up.
		var f := fmod(lt, 1.2) / 1.2
		if lt < 5.5 or lt > 10.6:
			var p := r.position + Vector2(r.size.x * 0.5, -6 - f * 34)
			draw_string_outline(FONT, p - Vector2(30, 0), "+0:10", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 5, Color(0, 0, 0, 1.0 - f))
			draw_string(FONT, p - Vector2(30, 0), "+0:10", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 1.0, 0.45, 1.0 - f))

	func _sheet(r: Rect2) -> void:
		_sheet_on(self, r)

	func _pong_on(c: CanvasItem, r: Rect2, lt: float) -> void:
		c.draw_rect(r, Color(0.04, 0.05, 0.1))
		var px := fposmod(lt * 90.0, 2.0 * (r.size.x - 20))
		if px > r.size.x - 20:
			px = 2.0 * (r.size.x - 20) - px
		var py := fposmod(lt * 70.0, 2.0 * (r.size.y - 10))
		if py > r.size.y - 10:
			py = 2.0 * (r.size.y - 10) - py
		var ball := r.position + Vector2(10 + px, 5 + py)
		c.draw_rect(Rect2(ball - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1))
		c.draw_rect(Rect2(r.position + Vector2(4, clampf(ball.y - r.position.y - 12, 0, r.size.y - 24)), Vector2(4, 24)), Color(0.4, 1.0, 0.6))
		c.draw_rect(Rect2(r.position + Vector2(r.size.x - 8, clampf(ball.y - r.position.y - 12, 0, r.size.y - 24)), Vector2(4, 24)), Color(1.0, 0.5, 0.8))

	func _sheet_on(c: CanvasItem, r: Rect2) -> void:
		c.draw_rect(r, Color(0.98, 0.98, 0.96))
		c.draw_rect(Rect2(r.position, Vector2(r.size.x, 10)), Color(0.06, 0.14, 0.6))
		for i in 6:
			var y := r.position.y + 14 + i * 11
			c.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.6, 0.7, 0.7), 1.0)
		for i in 4:
			var x := r.position.x + 4 + i * 28
			c.draw_line(Vector2(x, r.position.y + 10), Vector2(x, r.end.y), Color(0.6, 0.7, 0.7), 1.0)
		c.draw_rect(Rect2(r.position + Vector2(33, 26), Vector2(26, 10)), Color(1.0, 0.9, 0.3))
		c.draw_rect(Rect2(r.position + Vector2(61, 48), Vector2(26, 10)), Color(1.0, 0.9, 0.3))

	func _ship(st: float) -> void:
		var box := Rect2(150, 110, 300, 120)
		draw_rect(Rect2(box.position + Vector2(6, 6), box.size), Color(0, 0, 0, 0.5))
		draw_rect(box, Color(0.18, 0.08, 0.22))
		draw_rect(box, Color(1.0, 0.45, 0.8), false, 4.0)
		draw_string(FONT, box.position + Vector2(0, 28), "YOUR GAME", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 16, Color(1.0, 0.45, 0.8))
		var cols := [Color(0.95, 0.4, 0.4), Color(1.0, 0.8, 0.3), Color(0.4, 0.85, 0.5), Color(0.4, 0.7, 1.0), Color(0.8, 0.5, 1.0)]
		for i in 5:
			var r := Rect2(box.position + Vector2(24 + i * 52, 44), Vector2(44, 34))
			draw_rect(r, Color(1, 1, 1, 0.12), false, 2.0)
			var at := 0.15 + i * 0.25
			if st >= at:
				var drop := clampf((st - at) / 0.15, 0.0, 1.0)
				draw_rect(Rect2(r.position - Vector2(0, (1.0 - drop) * 30), r.size), cols[i])
		if st >= 1.6:
			draw_string(FONT, box.position + Vector2(0, 104), "PRESS: 8.5/10", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 14, Color(1.0, 0.86, 0.25))

	func _bar(p: Vector2, label: String, k: float, col: Color) -> void:
		var r := Rect2(p, Vector2(210, 22))
		draw_rect(r, Color(0.08, 0.08, 0.1, 0.85))
		draw_rect(Rect2(p, Vector2(210 * k, 22)), col)
		draw_rect(r, Color(1, 1, 1, 0.8), false, 2.0)
		draw_string(FONT, p + Vector2(6, 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1))

	func _edge(e: int, col: Color) -> void:
		var clear := Color(col.r, col.g, col.b, 0.0)
		var d := 36.0
		var pts: PackedVector2Array
		match e:
			0: pts = PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W - d, d), Vector2(d, d)])
			1: pts = PackedVector2Array([Vector2(W, 0), Vector2(W, H), Vector2(W - d, H - d), Vector2(W - d, d)])
			2: pts = PackedVector2Array([Vector2(W, H), Vector2(0, H), Vector2(d, H - d), Vector2(W - d, H - d)])
			_: pts = PackedVector2Array([Vector2(0, H), Vector2(0, 0), Vector2(d, d), Vector2(d, H - d)])
		draw_polygon(pts, PackedColorArray([col, col, clear, clear]))

	func _bubble(p: Vector2, text: String, fill: Color) -> void:
		var w := text.length() * 13.0 + 20.0
		var r := Rect2(p - Vector2(w * 0.5, 0), Vector2(w, 32))
		draw_rect(r, fill)
		draw_rect(r, Color(0.1, 0.1, 0.1), false, 3.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 31), p + Vector2(8, 31), p + Vector2(0, 44)]), fill)
		draw_string(FONT, r.position + Vector2(0, 22), text, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.08, 0.08, 0.1))

	func _stamp(text: String, c: Vector2, col: Color) -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var k := minf(size.x / W, size.y / H)
		var off := (size - Vector2(W, H) * k) * 0.5
		draw_set_transform(off + c * k, -0.12, Vector2(k, k))
		var r := Rect2(-170, -34, 340, 60)
		draw_rect(r, Color(1, 1, 1, 0.92))
		draw_rect(r, col, false, 6.0)
		draw_string(FONT, Vector2(-170, 10), text, HORIZONTAL_ALIGNMENT_CENTER, 340, 26, col)
		draw_set_transform(off, 0.0, Vector2(k, k))

	func _caption(lt: float, caught: bool) -> void:
		var text := "1. PLAY GAMES AT WORK"
		if lt >= 10.6:
			text = "3. SHIP YOUR OWN GAME FRIDAY"
		elif caught and lt >= 7.3:
			text = "3 STRIKES = FIRED"
		elif caught and lt >= 5.5:
			text = "TOO SLOW..."
		elif lt >= 5.5:
			text = "2. ALT-TAB. LOOK BUSY."
		elif lt >= 3.6:
			text = "...THE BOSS IS COMING"
		draw_rect(Rect2(0, H - 50, W, 50), Color(0, 0, 0, 0.7))
		draw_string_outline(FONT, Vector2(0, H - 17), text, HORIZONTAL_ALIGNMENT_CENTER, W, 20, 8, Color.BLACK)
		draw_string(FONT, Vector2(0, H - 17), text, HORIZONTAL_ALIGNMENT_CENTER, W, 20, Color(1, 1, 1))
