extends Node
## Gamepad (and arrow-key) control for a touch UI, with no changes to how the
## game handles taps. A glowing frame jumps between the buttons you could tap
## right now; the D-pad or left stick moves it, A presses the button under it.
## A tap or click hides it again.
##
## Add one as a child of the game's root Control. It reads events from its own
## viewport, so inside the office (where the seated game gets its input pushed
## in) it only sees the controller while you sit at that computer.
##
## Buttons can carry meta:
##   "pad_button": a JOY_BUTTON_* that presses it from anywhere on screen
##                 (e.g. X = LAND IT, Start = pause, B = back / skip).
##   "pad_default": true to start the frame there when a screen opens.
##   "pad_skip": true to leave it out.
## A button counts only if a tap on its centre would reach it, so buttons
## under an open overlay are skipped. Greyed-out buttons can hold the frame
## (so it doesn't jump around while a card is unaffordable) but don't press.

const DEADZONE := 0.5
const REPEAT_DELAY := 0.38
const REPEAT_EVERY := 0.11
const RING := Color(1.0, 0.86, 0.25)
const DIRS := {
	"ui_left": Vector2.LEFT, "ui_right": Vector2.RIGHT,
	"ui_up": Vector2.UP, "ui_down": Vector2.DOWN,
}

## The frame is showing (the player last used a pad or the arrow keys).
var active := false
## While true the frame hides and directions / A are left for the game
## (say, to steer something on screen); "pad_button" shortcuts still work.
var hold := false
var _target = null
## Last frame centre (viewport canvas coords), to stay put when a screen rebuilds.
var _pos := Vector2(-1, -1)
## Buttons on screen last frame (instance ids), to tell a fresh screen
## from the same screen with a few buttons rebuilt.
var _seen := {}
var _held := {}
var _repeat_dir := ""
var _repeat_time := 0.0
var _flash := 0.0
var _layer: CanvasLayer
var _ring: Control


## Gives the ui_* actions controller buttons: A accepts, B cancels. Safe to
## call more than once, from any game sharing the InputMap.
static func add_pad_actions() -> void:
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var have := false
		for e in InputMap.action_get_events(pair[0]):
			if e is InputEventJoypadButton and e.button_index == pair[1]:
				have = true
		if not have:
			var ev := InputEventJoypadButton.new()
			ev.button_index = pair[1]
			InputMap.action_add_event(pair[0], ev)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_pad_actions()
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	_ring = Control.new()
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_layer.add_child(_ring)


## Put the frame on this button (and show it if a pad is in use).
func focus(button: BaseButton) -> void:
	_target = button
	if button == null:
		return
	# Scroll lists along so the framed button is on screen.
	var up := button.get_parent()
	while up and not up is Viewport:
		if up is ScrollContainer:
			up.ensure_control_visible(button)
			break
		up = up.get_parent()
	_pos = _center(button)


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		active = false
		_ring.queue_redraw()
		return
	var pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if not pad and not event is InputEventKey:
		return
	if event is InputEventKey and event.is_echo():
		if active and _is_nav(event):
			get_viewport().set_input_as_handled()
		return
	# Direct shortcuts (pad only).
	if event is InputEventJoypadButton and event.pressed:
		for b in _candidates():
			if b.get_meta("pad_button", -1) == event.button_index:
				# Press it without moving the frame off what you were on.
				if not hold:
					_wake()
				_press(b)
				get_viewport().set_input_as_handled()
				return
	if hold:
		return
	# A stick axis matches both its directions (one at strength 0), so check all.
	var nav := false
	for action in DIRS:
		if not event.is_action(action):
			continue
		nav = true
		var on: bool = event.get_action_strength(action) > DEADZONE
		var was: bool = _held.get(action, false)
		_held[action] = on
		if on and not was:
			if not active:
				_wake()
			else:
				_step(DIRS[action])
			_repeat_dir = action
			_repeat_time = REPEAT_DELAY
		elif not on and _repeat_dir == action:
			_repeat_dir = ""
	if nav:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		if not active:
			_wake()
		elif _valid(_target):
			_press(_target)
		get_viewport().set_input_as_handled()


func _is_nav(event: InputEvent) -> bool:
	for action in DIRS:
		if event.is_action(action):
			return true
	return event.is_action("ui_accept")


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 4.0)
	if not active or hold:
		_ring.queue_redraw()
		return
	if _repeat_dir != "":
		_repeat_time -= delta
		if _repeat_time <= 0.0:
			_repeat_time = REPEAT_EVERY
			_step(DIRS[_repeat_dir])
	if not _valid(_target):
		_settle()
	elif _blocked(_target, _controls()):
		_settle()
	if _valid(_target):
		_pos = _center(_target)
	_seen.clear()
	for b in _candidates():
		_seen[b.get_instance_id()] = true
	_ring.queue_redraw()


func _wake() -> void:
	active = true
	if not _valid(_target):
		_settle()


## Pick a button when the current one went away. Same screen (some buttons
## were rebuilt, like a played card): the nearest to where the frame was.
## A new screen: its default, else the nearest one that works.
func _settle() -> void:
	var list := _candidates()
	_target = null
	if list.is_empty():
		return
	var same := false
	for b in list:
		if _seen.has(b.get_instance_id()):
			same = true
			break
	var pool := list
	if not same:
		for b in list:
			if b.get_meta("pad_default", false):
				focus(b)
				return
		var live := list.filter(func(b): return not b.disabled)
		if not live.is_empty():
			pool = live
	if _pos.x < 0:
		focus(pool[0])
		return
	var best: BaseButton
	var best_d := INF
	for b in pool:
		var d := _center(b).distance_squared_to(_pos)
		if d < best_d:
			best_d = d
			best = b
	focus(best)


func _step(dir: Vector2) -> void:
	if not _valid(_target):
		_settle()
		return
	var from := _center(_target)
	var best: BaseButton
	var best_score := INF
	for b in _candidates():
		if b == _target:
			continue
		var d := _center(b) - from
		var along := d.dot(dir)
		if along <= 4.0:
			continue
		var across := absf(d.dot(Vector2(-dir.y, dir.x)))
		var score := along + across * 2.5
		if score < best_score:
			best_score = score
			best = b
	if best:
		focus(best)
		_flash = 0.4


func _press(b: BaseButton) -> void:
	if b.disabled:
		return
	_flash = 1.0
	b.button_down.emit()
	if b.toggle_mode:
		b.button_pressed = not b.button_pressed
	b.pressed.emit()
	b.button_up.emit()


# ---------------------------------------------------------------- what's tappable

func _valid(b) -> bool:
	return b != null and is_instance_valid(b) and b is BaseButton and b.is_inside_tree() and not b.is_queued_for_deletion() \
		and b.is_visible_in_tree() and not b.get_meta("pad_skip", false) \
		and b.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _center(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


func _rect(c: Control) -> Rect2:
	var xf := c.get_global_transform_with_canvas()
	return Rect2(xf * Vector2.ZERO, Vector2.ZERO).expand(xf * Vector2(c.size.x, 0)) \
		.expand(xf * Vector2(0, c.size.y)).expand(xf * c.size)


## Every visible Control that takes taps, in draw order (bottom first),
## as [control, layer, tree index].
func _controls() -> Array:
	var out := []
	_collect(get_viewport(), 0, out)
	out.sort_custom(func(a, b): return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]))
	return out


func _collect(node: Node, layer: int, out: Array) -> void:
	for child in node.get_children():
		if child is Viewport or child == _layer:
			continue
		var l := layer
		if child is CanvasLayer:
			if not child.visible:
				continue
			l = child.layer
		elif child is CanvasItem and not child.visible:
			continue
		if child is Control and child.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			out.append([child, l, out.size()])
		_collect(child, l, out)


## Buttons a tap could reach right now, in tree order.
func _candidates() -> Array[BaseButton]:
	var controls := _controls()
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var out: Array[BaseButton] = []
	for entry in controls:
		var b = entry[0]
		if b is BaseButton and _valid(b) and (view.has_point(_center(b)) or _scrolls(b)) \
				and not _blocked(b, controls):
			out.append(b)
	return out


## Inside a scrolling list (so it can be brought on screen).
func _scrolls(b: Control) -> bool:
	var up := b.get_parent()
	while up and not up is Viewport:
		if up is ScrollContainer:
			return true
		up = up.get_parent()
	return false


## True if a tap on the button's centre would land on something drawn above it.
func _blocked(b: BaseButton, controls: Array) -> bool:
	var p := _center(b)
	var seen := false
	for entry in controls:
		var c: Control = entry[0]
		if c == b:
			seen = true
			continue
		if not seen or b.is_ancestor_of(c) or c.is_ancestor_of(b):
			continue
		if _rect(c).has_point(p):
			return true
	return false


func _draw_ring() -> void:
	if not active or hold or not _valid(_target):
		return
	var r := _rect(_target).grow(6.0 + 6.0 * _flash)
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 160.0)
	var col := RING.lerp(Color.WHITE, _flash)
	if _target.disabled:
		col = col.darkened(0.45)
	col.a = pulse
	_ring.draw_rect(r, Color(0, 0, 0, 0.5 * pulse), false, 10.0)
	_ring.draw_rect(r, col, false, 5.0)
