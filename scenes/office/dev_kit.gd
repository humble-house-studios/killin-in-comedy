extends Control
## Look Busy's DEV KIT desk ("GAMEMAKER 95"): build your own game from this
## week's pieces (engine/game_maker.gd). One row per kind (genre, mechanic,
## art style, sound, character): tap a row to cycle through the pieces you
## have of that kind. The title, score and combos update live; PLAY TRAILER
## runs a short generated trailer. On Friday, SHIP IT ships the game early
## (otherwise it ships at 5 PM). 720x1280 in its own SubViewport on the desk's
## screen; Buttons only, so touch, mouse and the pad cursor all work.

const FONT := preload("res://fonts/press_start_2p.ttf")
const W := 720.0
const H := 1280.0
const BG := Color(0.1, 0.09, 0.16)
const GOLD := Color(1.0, 0.85, 0.3)
const PINK := Color(1.0, 0.4, 0.75)
const KIND_COLORS := {
	"genre": Color(0.95, 0.45, 0.3), "mechanic": Color(0.35, 0.75, 1.0), "art": Color(0.75, 0.5, 1.0),
	"sound": Color(0.4, 0.9, 0.55), "character": Color(1.0, 0.8, 0.35),
}

## The office's Look Busy node (it holds the GameMaker and the workday).
var busy: Node
var _title: Label
var _score: Label
var _combos: Label
var _info: Label
var _rows := {}
var _ship: Button
var _trailer: Control
var _trailer_label: Label
var _cards: Array = []
var _card_i := 0
var _card_t := 0.0
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _last_score := -1


func _init() -> void:
	size = Vector2(W, H)
	custom_minimum_size = size
	clip_contents = true


func _ready() -> void:
	for i in 3:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	var back := ColorRect.new()
	back.color = BG
	back.size = size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var head := _label("GAMEMAKER 95", 28, PINK)
	head.position = Vector2(20, 104)
	head.size = Vector2(W - 40, 40)
	add_child(head)
	_info = _label("", 15, Color(0.8, 0.8, 0.9))
	_info.position = Vector2(20, 152)
	_info.size = Vector2(W - 40, 50)
	add_child(_info)
	_title = _label("", 30, GOLD)
	_title.position = Vector2(20, 205)
	_title.size = Vector2(W - 40, 90)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title)
	_score = _label("", 56, Color.WHITE)
	_score.position = Vector2(20, 298)
	_score.size = Vector2(W - 40, 70)
	add_child(_score)
	_combos = _label("", 16, Color(0.6, 1.0, 0.7))
	_combos.position = Vector2(20, 376)
	_combos.size = Vector2(W - 40, 100)
	add_child(_combos)
	var y := 482.0
	for kind in GameMaker.KINDS:
		var b := _button("", KIND_COLORS[kind].darkened(0.6), KIND_COLORS[kind])
		b.position = Vector2(20, y)
		b.size = Vector2(W - 40, 102)
		b.pressed.connect(_cycle.bind(kind))
		add_child(b)
		_rows[kind] = b
		y += 114
	var trailer := _button("PLAY TRAILER", Color(0.3, 0.12, 0.35), PINK)
	trailer.position = Vector2(20, y + 6)
	trailer.size = Vector2((W - 56) * 0.5, 110)
	trailer.pressed.connect(play_trailer)
	add_child(trailer)
	_ship = _button("SHIP IT", Color(0.1, 0.32, 0.15), Color(0.4, 1.0, 0.5))
	_ship.position = Vector2(36 + (W - 56) * 0.5, y + 6)
	_ship.size = Vector2((W - 56) * 0.5, 110)
	_ship.pressed.connect(func():
		if busy:
			busy.ship_now())
	add_child(_ship)
	_build_trailer()
	add_child(preload("res://scenes/pad_cursor.gd").new())
	refresh()


## Everything from the GameMaker as it is now.
func refresh() -> void:
	if busy == null or _title == null:
		return
	var gm: GameMaker = busy.gm
	var s := gm.score()
	_title.text = gm.title() if not gm.build.is_empty() else "NO GAME YET"
	_score.text = "%d PTS" % s.score
	var lines: Array[String] = []
	for c in s.combos:
		lines.append("%s %s" % [c.name, c.text])
	_combos.text = "  ".join(lines) if not lines.is_empty() else ("BEAT DESKS TO EARN PIECES.\nPIECES THAT GO TOGETHER COMBO." if gm.pieces.is_empty() else "NO COMBOS YET. TRY OTHER PIECES.")
	for kind in GameMaker.KINDS:
		var have := gm.of_kind(kind).size()
		var name: String = gm.build.get(kind, "---")
		_rows[kind].text = "%s (%d)\n%s" % [GameMaker.KIND_NAMES[kind], have, name]
		_rows[kind].disabled = have == 0
	var wd: Workday = busy.wd
	_info.text = "%d PIECES THIS WEEK\n%s" % [gm.pieces.size(), "SHIPS TODAY 5 PM" if wd.is_friday() else "SHIPS FRIDAY 5 PM"]
	_ship.visible = wd.is_friday()
	if _last_score >= 0 and s.score > _last_score:
		_play(preload("res://audio/ding.wav"), -4.0, 1.0 + minf(0.5, (s.score - _last_score) / 100.0))
	_last_score = s.score


func set_active(on: bool) -> void:
	if on:
		_last_score = -1
		refresh()
	elif _trailer and _trailer.visible:
		_trailer.visible = false


func _cycle(kind: String) -> void:
	var gm: GameMaker = busy.gm
	var list := gm.of_kind(kind)
	if list.is_empty():
		return
	var at := -1
	for i in list.size():
		if list[i].name == gm.build.get(kind, ""):
			at = i
	# Cycle through each piece, then "none".
	if at + 1 < list.size():
		gm.pick(kind, list[at + 1].name)
	else:
		gm.clear_slot(kind)
	_play(preload("res://audio/click.wav"), -2.0)
	refresh()


# ---------------------------------------------------------------- trailer

func _build_trailer() -> void:
	_trailer = Button.new()
	_trailer.flat = true
	_trailer.focus_mode = Control.FOCUS_NONE
	_trailer.position = Vector2.ZERO
	_trailer.size = size
	_trailer.visible = false
	(_trailer as Button).pressed.connect(_next_card)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = size
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trailer.add_child(black)
	_trailer_label = _label("", 36, Color.WHITE)
	_trailer_label.position = Vector2(30, 300)
	_trailer_label.size = Vector2(W - 60, 600)
	_trailer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_trailer.add_child(_trailer_label)
	var skip := _label("TAP TO SKIP", 14, Color(1, 1, 1, 0.4))
	skip.position = Vector2(0, H - 80)
	skip.size = Vector2(W, 30)
	_trailer.add_child(skip)
	add_child(_trailer)


func play_trailer() -> void:
	if busy == null or busy.gm.build.is_empty():
		_combos.text = "PUT SOME PIECES IN FIRST."
		return
	_cards = busy.gm.trailer()
	_card_i = -1
	_trailer.visible = true
	_next_card()


func _next_card() -> void:
	_card_i += 1
	if _card_i >= _cards.size():
		_trailer.visible = false
		return
	_card_t = 0.0
	var last := _card_i >= _cards.size() - 2
	_trailer_label.text = _cards[_card_i]
	_trailer_label.add_theme_color_override("font_color", GOLD if last else [Color.WHITE, PINK, Color(0.4, 0.9, 1.0)][_card_i % 3])
	_trailer_label.add_theme_font_size_override("font_size", 46 if last else 34)
	_trailer_label.scale = Vector2(1.2, 1.2)
	_trailer_label.pivot_offset = _trailer_label.size * 0.5
	_trailer_label.modulate.a = 0.0
	if _card_i == _cards.size() - 2:
		_play(preload("res://audio/fanfare.wav"), -4.0)
	else:
		_play(preload("res://audio/thump.wav"), -2.0)


func _process(delta: float) -> void:
	if not _trailer or not _trailer.visible:
		return
	_card_t += delta
	_trailer_label.modulate.a = clampf(_card_t * 3.0, 0.0, 1.0)
	_trailer_label.scale = _trailer_label.scale.lerp(Vector2.ONE, minf(1.0, delta * 6.0))
	if _card_t > (2.2 if _card_i >= _cards.size() - 2 else 1.5):
		_next_card()


# ---------------------------------------------------------------- kit

func _play(stream: AudioStream, db := 0.0, pitch := 1.0) -> void:
	var p := _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


func _label(text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 8)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, fill: Color, rim: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_constant_override("line_spacing", 10)
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, _box(fill, rim))
	b.add_theme_stylebox_override("pressed", _box(fill.lightened(0.25), rim))
	b.add_theme_stylebox_override("disabled", _box(fill.darkened(0.5), Color(1, 1, 1, 0.2)))
	return b


func _box(fill: Color, rim: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = rim
	s.set_border_width_all(4)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	return s
