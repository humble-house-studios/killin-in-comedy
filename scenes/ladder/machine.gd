extends Control
## Base for every screen past the office door (arcade cabinets, the trading
## terminal, the boardroom projector, the putting green, the stage, the
## archive). Each one runs in its own SubViewport (720x1280) on a screen in
## the office's 3D world, so sitting down, taps, mouse and the controller all
## arrive the same way as the office's other games.
##
## `hub` is the office's ladder controller (scenes/office/ladder.gd): it holds
## LadderState (tokens, tickets, items) and Coworkers, and hears about wins.
## `active` is true while you sit at this screen (time-based games pause
## otherwise). Controls are Buttons, so the pad cursor works on all of them.

const W := 720.0
const H := 1280.0
const FONT := preload("res://fonts/press_start_2p.ttf")
const SFX := {
	"coin": preload("res://audio/coin.wav"), "ding": preload("res://audio/ding.wav"),
	"jackpot": preload("res://audio/jackpot.wav"), "click": preload("res://audio/click.wav"),
	"chime": preload("res://audio/chime.wav"), "cheer": preload("res://audio/cheer.wav"),
	"thump": preload("res://audio/thump.wav"), "groan": preload("res://audio/groan.wav"),
	"fanfare": preload("res://audio/fanfare.wav"), "laugh_big": preload("res://audio/laugh_big.wav"),
	"laugh_small": preload("res://audio/laugh_small.wav"), "laugh_huge": preload("res://audio/laugh_huge.wav"),
	"rimshot": preload("res://audio/rimshot.wav"), "applause": preload("res://audio/applause.wav"),
	"sad_trombone": preload("res://audio/sad_trombone.wav"), "card": preload("res://audio/card.wav"),
}

var hub: Node
var active := false
var accent := Color(1.0, 0.35, 0.7)
var _players: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _top: Label
var _banner: Label
var _banner_time := 0.0


func _init() -> void:
	size = Vector2(W, H)
	custom_minimum_size = size
	clip_contents = true


func _ready() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	var pad := preload("res://scenes/pad_cursor.gd").new()
	add_child(pad)


# ---------------------------------------------------------------- kit

func sfx(name: String, db := 0.0, pitch := 1.0) -> void:
	if not SFX.has(name) or _players.is_empty():
		return
	var p := _players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _players.size()
	p.stream = SFX[name]
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


func label(text: String, font_size: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
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


func box(color: Color, border := Color(0, 0, 0, 0), width := 0, radius := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(14)
	return s


func button(text: String, font_size := 30, color := Color(0.2, 0.12, 0.3), border := Color(1, 1, 1, 0.85)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 110)
	var normal := box(color, border, 4, 6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("focus", normal)
	var down := box(color.lightened(0.3), border, 4, 6)
	b.add_theme_stylebox_override("pressed", down)
	var off := box(color.darkened(0.5), Color(1, 1, 1, 0.25), 4, 6)
	b.add_theme_stylebox_override("disabled", off)
	return b


func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## A plain background with a title bar: the machine's name and, below it, a
## line for tokens / tickets (refresh_top()).
func frame(title: String, bg: Color, title_color: Color) -> void:
	accent = title_color
	var back := ColorRect.new()
	back.color = bg
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Behind this Control's own _draw(), so machines can draw over it.
	back.show_behind_parent = true
	add_child(full(back))
	# Right of the office's STAND UP button, which sits over the top-left
	# corner of the screen while you're seated on a phone.
	var t := label(title, 30, title_color, HORIZONTAL_ALIGNMENT_RIGHT)
	t.position = Vector2(250, 40)
	t.size = Vector2(W - 270, 50)
	add_child(t)
	_top = label("", 20, Color(1.0, 0.92, 0.55), HORIZONTAL_ALIGNMENT_RIGHT)
	_top.position = Vector2(250, 100)
	_top.size = Vector2(W - 270, 40)
	add_child(_top)
	_banner = label("", 40, Color(1.0, 0.9, 0.3))
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 14)
	_banner.position = Vector2(20, 470)
	_banner.size = Vector2(W - 40, 240)
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner.z_index = 50
	add_child(_banner)
	refresh_top()


func refresh_top() -> void:
	if _top and hub:
		_top.text = "TOKENS %d  TICKETS %d" % [hub.state.tokens, hub.state.tickets]


## A big message across the middle that fades.
func banner(text: String, seconds := 2.2, color := Color(1.0, 0.9, 0.3)) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_time = seconds
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(1.15, 1.15)
	_banner.pivot_offset = _banner.size * 0.5


func _process(delta: float) -> void:
	if _banner and _banner_time > 0.0:
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time * 2.0, 0.0, 1.0)
		_banner.scale = _banner.scale.lerp(Vector2.ONE, minf(1.0, delta * 10.0))


## Pay one token for a play. Shows the petty-cash hint when you're out.
func pay_token() -> bool:
	if hub == null:
		return true
	if not hub.spend_token():
		banner("OUT OF TOKENS\nPETTY CASH AT\nTHE PRIZE COUNTER", 2.6, Color(1.0, 0.5, 0.4))
		sfx("groan", -6.0)
		return false
	sfx("coin", -4.0)
	refresh_top()
	return true


func win(tickets: int, machine: String, beats := false) -> void:
	if hub:
		hub.win_tickets(tickets, machine, beats)
	refresh_top()


func set_active(on: bool) -> void:
	active = on
	if on:
		refresh_top()
