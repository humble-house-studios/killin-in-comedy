class_name Sound
extends Node
## Sound effects and the lounge music loop (made by tools/make_audio.py).
## Music starts on the first Start tap, since browsers block sound before a
## tap. The mute choice is saved to user://.

const SETTINGS_PATH := "user://settings.cfg"
const SAVE_VERSION := 1
const MUSIC_DB := -11.0
const NAMES := [
	"laugh_small", "laugh_big", "laugh_huge", "applause", "cheer", "crickets",
	"groan", "rimshot", "sad_trombone", "fanfare", "click", "card", "chime", "thump",
	"ding", "coin", "jackpot",
]
## Casino sounds fire in fast runs, so they get more voices.
const RAPID := ["ding", "coin"]

var muted := false

var _players := {}
var _music: AudioStreamPlayer


func _ready() -> void:
	for sfx in NAMES:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://audio/%s.wav" % sfx)
		player.max_polyphony = 8 if sfx in RAPID else 3
		add_child(player)
		_players[sfx] = player
	var music := load("res://audio/music.ogg") as AudioStreamOggVorbis
	music.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = music
	_music.volume_db = MUSIC_DB
	add_child(_music)
	_load_settings()
	AudioServer.set_bus_mute(0, muted)


func play(sfx: String, volume_db := 0.0, pitch := 1.0) -> void:
	var player: AudioStreamPlayer = _players.get(sfx)
	if player == null:
		return
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Plays after `delay` seconds, e.g. a laugh landing after the rimshot.
func play_later(sfx: String, delay: float, volume_db := 0.0) -> void:
	await get_tree().create_timer(delay).timeout
	play(sfx, volume_db)


func start_music() -> void:
	if not _music.playing:
		_music.play()


func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	write_settings("audio", {"muted": muted})


## One value from user://settings.cfg (the office's pause menu keeps its
## volumes and look settings here too, in section "office").
static func read_setting(section: String, key: String, default: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return default
	return cfg.get_value(section, key, default)


## Saves values into user://settings.cfg, keeping everything else in it.
static func write_settings(section: String, values: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("meta", "save_version", SAVE_VERSION)
	for key in values:
		cfg.set_value(section, key, values[key])
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		muted = cfg.get_value("audio", "muted", false)
