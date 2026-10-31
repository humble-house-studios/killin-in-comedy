extends Node
## Dale's real voice chat. Hold TALK: the mic records (the "Mic" bus in
## default_bus_layout.tres has an AudioEffectRecord). Let go: the clip goes to
## the voice server (voice/, a free Cloudflare Worker) as a small 16 kHz WAV,
## which hears it, answers as Dale and sends his voice back to play here.
## Works the same on web, phones and desktop (plain HTTPRequest + mic input).

signal replied(heard: String, reply: String)
signal failed(message: String)

const MIC_BUS := "Mic"
## What the server gets: mono 16 kHz, plenty for speech and small to send.
const RATE := 16000
const MAX_SECONDS := 15.0
const MIN_SECONDS := 0.4

## The chat so far, [{role, content}], so Dale remembers what you just said.
var history: Array = []
## Waiting on the server.
var busy := false

var _mic: AudioStreamPlayer
var _record: AudioEffectRecord
var _out: AudioStreamPlayer
var _http: HTTPRequest
var _since := 0


static func available() -> bool:
	return VoiceServer.URL != ""


func _ready() -> void:
	var bus := AudioServer.get_bus_index(MIC_BUS)
	if bus < 0:
		bus = AudioServer.bus_count
		AudioServer.add_bus(bus)
		AudioServer.set_bus_name(bus, MIC_BUS)
		AudioServer.set_bus_mute(bus, true)
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectRecord:
			_record = AudioServer.get_bus_effect(bus, i)
	if _record == null:
		_record = AudioEffectRecord.new()
		AudioServer.add_bus_effect(bus, _record)
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = MIC_BUS
	_mic.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_mic)
	_out = AudioStreamPlayer.new()
	_out.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_out)
	_http = HTTPRequest.new()
	_http.timeout = 45.0
	add_child(_http)
	_http.request_completed.connect(_on_done)


func listening() -> bool:
	return _record != null and _record.is_recording_active()


func speaking() -> bool:
	return _out.playing


func start_listening() -> bool:
	if busy or not available():
		return false
	stop_speaking()
	_mic.play()
	_record.set_recording_active(true)
	_since = Time.get_ticks_msec()
	return true


## Let go of TALK: send what was said, with Dale's persona and the chat so far.
func stop_listening(persona: String) -> void:
	if not listening():
		return
	_record.set_recording_active(false)
	var clip := _record.get_recording()
	_mic.stop()
	var secs := (Time.get_ticks_msec() - _since) / 1000.0
	if clip == null or clip.data.size() < 1000 or secs < MIN_SECONDS:
		failed.emit("Hold TALK the whole time you're speaking.")
		return
	_send({"audio": Marshalls.raw_to_base64(to_wav16k(clip))}, persona)


func cancel() -> void:
	if listening():
		_record.set_recording_active(false)
		_mic.stop()
	if busy:
		_http.cancel_request()
		busy = false
	stop_speaking()


func stop_speaking() -> void:
	_out.stop()


func _process(_delta: float) -> void:
	# Don't record forever if the button gets stuck.
	if listening() and Time.get_ticks_msec() - _since > MAX_SECONDS * 1000.0:
		_record.set_recording_active(false)
		_mic.stop()
		failed.emit("That was a long one. Try something shorter.")


func _send(body: Dictionary, persona: String) -> void:
	body.persona = persona
	body.history = history.slice(maxi(0, history.size() - 10))
	busy = true
	var err := _http.request(VoiceServer.URL.trim_suffix("/") + "/talk", ["Content-Type: application/json"],
			HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		busy = false
		failed.emit("Couldn't reach Dale. Check the connection.")


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	var data = JSON.parse_string(body.get_string_from_utf8()) if body.size() > 0 else null
	if result != HTTPRequest.RESULT_SUCCESS or not data is Dictionary:
		failed.emit("Dale's line went dead. Try again in a sec.")
		return
	var reply := str(data.get("reply", ""))
	if code != 200 or reply == "":
		failed.emit(str(data.get("error", "Didn't catch that.")))
		return
	var heard := str(data.get("heard", ""))
	history.append({"role": "user", "content": heard})
	history.append({"role": "assistant", "content": reply})
	_play(str(data.get("audio", "")))
	replied.emit(heard, reply)


func _play(b64: String) -> void:
	if b64.length() < 100:
		return
	var bytes := Marshalls.base64_to_raw(b64)
	var stream: AudioStream
	if bytes.slice(0, 4).get_string_from_ascii() == "RIFF":
		stream = wav_stream(bytes)
	else:
		var mp3 := AudioStreamMP3.new()
		mp3.data = bytes
		stream = mp3
	if stream:
		_out.stream = stream
		_out.play()


## A recorded clip as a 16 kHz mono 16-bit WAV file.
static func to_wav16k(clip: AudioStreamWAV) -> PackedByteArray:
	var src := clip.data
	var ch := 2 if clip.stereo else 1
	var frames := src.size() / (2 * ch)
	var step := float(clip.mix_rate) / RATE
	var n := int(frames / step)
	var out := PackedByteArray()
	out.resize(44 + n * 2)
	out.encode_u32(0, 0x46464952)  # RIFF
	out.encode_u32(4, 36 + n * 2)
	out.encode_u32(8, 0x45564157)  # WAVE
	out.encode_u32(12, 0x20746d66)  # "fmt "
	out.encode_u32(16, 16)
	out.encode_u16(20, 1)
	out.encode_u16(22, 1)
	out.encode_u32(24, RATE)
	out.encode_u32(28, RATE * 2)
	out.encode_u16(32, 2)
	out.encode_u16(34, 16)
	out.encode_u32(36, 0x61746164)  # data
	out.encode_u32(40, n * 2)
	for i in n:
		var at := int(i * step) * 2 * ch
		var s := src.decode_s16(at)
		if ch == 2:
			s = (s + src.decode_s16(at + 2)) / 2
		out.encode_s16(44 + i * 2, s)
	return out


## A 16-bit PCM WAV file (as some voices come back) as a playable stream.
static func wav_stream(bytes: PackedByteArray) -> AudioStreamWAV:
	var at := 12
	var rate := 24000
	var stereo := false
	while at + 8 <= bytes.size():
		var id := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		if id == "fmt ":
			stereo = bytes.decode_u16(at + 10) == 2
			rate = bytes.decode_u32(at + 12)
		elif id == "data":
			var w := AudioStreamWAV.new()
			w.format = AudioStreamWAV.FORMAT_16_BITS
			w.mix_rate = rate
			w.stereo = stereo
			w.data = bytes.slice(at + 8, mini(bytes.size(), at + 8 + size))
			return w
		at += 8 + size + (size & 1)
	return null
