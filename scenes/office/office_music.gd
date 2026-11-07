extends Node
## The office's own soundtrack: vintage 8-bit jazz (tools/make_audio.py,
## make_office_jazz()).
##   office_title.ogg  "Clock-In Ballad", while Look Busy's title screen is up.
##   office_jazz.ogg   "Golden Hour Shuffle", the loop you walk around to.
## The office crossfades it against the desk games' own music: office.gd sets
## `game_mix` each frame (0..1, how loud the nearest game's own music is, after
## its distance fade and a fade-in when the music starts), and the jazz dips
## by the same amount (equal power). Walk away from a game whose music is
## still going and the jazz comes back up as that music fades out. The song
## keeps running underneath, like a radio across the room.
## Plays on the Music bus (the pause menu's MUSIC volume) and keeps playing
## while the tree is paused (title screen, pause menu, pop-ups).
## Browsers hold sound until the first tap or key, so on web it starts on the
## first press (the title screen shows a hint until then).

const TITLE := "res://audio/office_title.ogg"
const LOOP := "res://audio/office_jazz.ogg"
const DB := -12.0
## Seconds for a full fade between the title tune, the loop and a game.
const FADE := 1.4
## Seated at a game with no music of its own: the jazz sits back a little.
const SEATED_QUIET := 0.6
## Dale (or a coworker) speaking: the jazz ducks under the voice.
const UNDER_VOICE := 0.45

var office: Node
var started := false
## Set by office.gd every frame it runs.
var game_mix := 0.0
var seated := false
var voice := false

var _title: AudioStreamPlayer
var _loop: AudioStreamPlayer
var _tv := 0.0
var _lv := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title = _player(TITLE)
	_loop = _player(LOOP)
	if not OS.has_feature("web"):
		start()


func _player(path: String) -> AudioStreamPlayer:
	var stream := load(path) as AudioStreamOggVorbis
	stream.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func start() -> void:
	started = true


func _input(event: InputEvent) -> void:
	if started:
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch \
			or event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		start()


func title_showing() -> bool:
	if office == null or office.get("_busy") == null:
		return false
	var t: Node = office._busy.get("title_screen")
	return t != null and (t.visible or bool(t.get("_waiting_menu")))


func _process(delta: float) -> void:
	if not started:
		return
	var on_title := title_showing()
	var hub := cos(clampf(game_mix, 0.0, 1.0) * PI * 0.5)
	if seated and game_mix < 0.05:
		hub *= SEATED_QUIET
	if voice:
		hub *= UNDER_VOICE
	var step := delta / FADE
	_tv = move_toward(_tv, 1.0 if on_title else 0.0, step)
	_lv = move_toward(_lv, 0.0 if on_title else hub, step)
	_drive(_title, _tv)
	_drive(_loop, _lv)


## Starts a tune when it's wanted, stops the title tune once it has faded out
## (so it starts from the top next time); the loop keeps running underneath.
func _drive(p: AudioStreamPlayer, v: float) -> void:
	if v > 0.001 and not p.playing:
		p.play()
	elif v <= 0.001 and p.playing and p == _title:
		p.stop()
	p.volume_db = DB + linear_to_db(maxf(v, 0.0001))
