extends Node
## Dale's real voice chat. Hold TALK: the mic plays into the muted "Mic" bus,
## whose AudioEffectCapture we drain every frame into a 16 kHz mono clip
## (AudioEffectRecord needs threads, and the web build has none). Let go: the clip goes to
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
var _capture: AudioEffectCapture
var _listening := false
## What you've said so far (16-bit mono at RATE), and where the resampler is.
var _pcm := PackedByteArray()
var _phase := 0.0
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
		if AudioServer.get_bus_effect(bus, i) is AudioEffectCapture:
			_capture = AudioServer.get_bus_effect(bus, i)
	if _capture == null:
		_capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(bus, _capture)
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
	return _listening


func speaking() -> bool:
	return _out.playing


## Dale's story lines, pre-recorded with his voice by the build
## (tools/dale_voice_lines.mjs). Plays the line and returns true if there's a
## clip for it.
func play_line(text: String) -> bool:
	var path := "res://audio/dale/%s.mp3" % text.md5_text().left(12)
	if not ResourceLoader.exists(path):
		path = path.replace(".mp3", ".wav")
		if not ResourceLoader.exists(path):
			return false
	_out.stream = load(path)
	_out.play()
	return true


func start_listening() -> bool:
	if busy or not available():
		return false
	stop_speaking()
	# The mic stays open for the rest of the chat: the first time, the browser
	# asks for permission and the stream takes a moment to arrive.
	if not _mic.playing:
		_mic.play()
	_capture.clear_buffer()
	_pcm = PackedByteArray()
	_phase = 0.0
	_listening = true
	_since = Time.get_ticks_msec()
	return true


## Let go of TALK: send what was said, with Dale's persona and the chat so far.
func stop_listening(persona: String) -> void:
	if not listening():
		return
	_drain()
	_listening = false
	var secs := (Time.get_ticks_msec() - _since) / 1000.0
	if secs < MIN_SECONDS:
		failed.emit("Hold TALK the whole time you're speaking.")
		return
	if _pcm.size() < RATE * 2 * MIN_SECONDS * 0.5 or silent(_pcm):
		failed.emit("I can't hear you. If your browser asked about the mic, tap Allow, then hold TALK again.")
		return
	_send({"audio": Marshalls.raw_to_base64(wav16k(_pcm))}, persona)


func cancel() -> void:
	_listening = false
	_mic.stop()
	if busy:
		_http.cancel_request()
		busy = false
	stop_speaking()


func stop_speaking() -> void:
	_out.stop()


func _process(_delta: float) -> void:
	if not _listening:
		if _capture and _capture.get_frames_available() > 0:
			_capture.clear_buffer()
		return
	_drain()
	# Don't record forever if the button gets stuck.
	if Time.get_ticks_msec() - _since > MAX_SECONDS * 1000.0:
		_listening = false
		failed.emit("That was a long one. Try something shorter.")


## Move what the mic captured since last frame into the 16 kHz clip.
func _drain() -> void:
	var n := _capture.get_frames_available()
	if n <= 0:
		return
	var step := AudioServer.get_mix_rate() / RATE
	_phase = add_frames(_pcm, _capture.get_buffer(n), step, _phase)


## Appends stereo float frames to a 16-bit mono clip, keeping one frame every
## `step` (mix rate / RATE). Returns the resampler phase to carry over.
static func add_frames(pcm: PackedByteArray, frames: PackedVector2Array, step: float, phase: float) -> float:
	var at := pcm.size()
	pcm.resize(at + (int((frames.size() + phase) / step) + 1) * 2)
	var i := phase
	var n := frames.size()
	while i < n:
		var f := frames[int(i)]
		pcm.encode_s16(at, clampi(int((f.x + f.y) * 0.5 * 32767.0), -32768, 32767))
		at += 2
		i += step
	pcm.resize(at)
	return i - n


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


## True when the clip is all (near) zeros: the mic stream hasn't arrived yet.
static func silent(pcm: PackedByteArray) -> bool:
	for i in range(0, pcm.size() - 1, 64):
		if absi(pcm.decode_s16(i)) > 40:
			return false
	return true


## 16-bit mono samples at RATE as a WAV file.
static func wav16k(pcm: PackedByteArray) -> PackedByteArray:
	var n := pcm.size() / 2
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
	for i in n * 2:
		out[44 + i] = pcm[i]
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

