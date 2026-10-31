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
## Web: waiting for the browser's recorder to finish, how long TALK was held,
## and the persona to send once it has.
var _web_wait := false
var _held := 0.0
var _web_persona := ""
## What you've said so far (16-bit mono at RATE), and where the resampler is.
var _pcm := PackedByteArray()
var _phase := 0.0
var _out: AudioStreamPlayer
var _http: HTTPRequest
var _since := 0
## What the last TALK picked up, shown when Dale can't hear you (helps tell
## a closed mic from a quiet one).
var mic_report := ""


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


## On the web the browser records (window.kicRec in the page, see
## export_presets.cfg): reading the mic through Godot's audio gives silence
## on some iPhones. Everywhere else, Godot's mic.
func _web_rec() -> bool:
	return OS.has_feature("web") and str(JavaScriptBridge.eval("typeof window.kicRec", true)) == "object"


## Open the mic ahead of time (the browser may ask for permission), so
## the first HOLD TO TALK catches every word.
func warm_up() -> void:
	if available() and _web_rec():
		JavaScriptBridge.eval("window.kicRec.warm()", true)


func start_listening() -> bool:
	if busy or not available():
		return false
	stop_speaking()
	if _web_rec():
		JavaScriptBridge.eval("window.kicRec.start()", true)
		_web_wait = false
		_listening = true
		_since = Time.get_ticks_msec()
		return true
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
	if _web_rec():
		_listening = false
		_held = (Time.get_ticks_msec() - _since) / 1000.0
		if _held < MIN_SECONDS:
			JavaScriptBridge.eval("window.kicRec.stop()", true)
			failed.emit(DaleLines.MIC_LINES[0])
			return
		JavaScriptBridge.eval("window.kicRec.stop()", true)
		_web_wait = true
		_web_persona = persona
		_since = Time.get_ticks_msec()
		busy = true
		return
	_drain()
	_listening = false
	var secs := (Time.get_ticks_msec() - _since) / 1000.0
	mic_report = "HELD %.1fs  GOT %.1fs  LEVEL %d" % [secs, _pcm.size() / 2.0 / RATE, peak(_pcm)]
	if secs < MIN_SECONDS:
		failed.emit(DaleLines.MIC_LINES[0])
		return
	if _pcm.size() < RATE * 2 * MIN_SECONDS * 0.5 or silent(_pcm):
		failed.emit(DaleLines.MIC_LINES[1])
		return
	# Phone mics come in quiet; turn it up so the hearing AI gets clear words.
	normalize(_pcm)
	_send({"audio": Marshalls.raw_to_base64(wav16k(_pcm))}, persona)


func cancel() -> void:
	_listening = false
	_mic.stop()
	if _web_wait:
		_web_wait = false
		busy = false
	if OS.has_feature("web") and _web_rec():
		JavaScriptBridge.eval("window.kicRec.close()", true)
	if busy:
		_http.cancel_request()
		busy = false
	stop_speaking()


func stop_speaking() -> void:
	_out.stop()


func _process(_delta: float) -> void:
	if _web_wait:
		_poll_web()
		return
	if _listening and OS.has_feature("web") and _web_rec():
		if Time.get_ticks_msec() - _since > MAX_SECONDS * 1000.0:
			_listening = false
			JavaScriptBridge.eval("window.kicRec.stop()", true)
			failed.emit(DaleLines.MIC_LINES[2])
		return
	if not _listening:
		if _capture and _capture.get_frames_available() > 0:
			_capture.clear_buffer()
		return
	_drain()
	# Don't record forever if the button gets stuck.
	if Time.get_ticks_msec() - _since > MAX_SECONDS * 1000.0:
		_listening = false
		failed.emit(DaleLines.MIC_LINES[2])


## Waiting for the browser to hand back the recording.
func _poll_web() -> void:
	var state := str(JavaScriptBridge.eval("window.kicRec.state()", true))
	var info := str(JavaScriptBridge.eval("window.kicRec.info()", true))
	if state == "done":
		_web_wait = false
		busy = false
		var url := str(JavaScriptBridge.eval("window.kicRec.take()", true))
		var comma := url.find(",")
		var mime := url.substr(5, url.find(";") - 5) if url.begins_with("data:") else "audio/mp4"
		var b64 := url.substr(comma + 1) if comma >= 0 else ""
		mic_report = "HELD %.1fs  GOT %s  %dKB %s" % [_held, info, b64.length() * 3 / 4 / 1024, mime.replace("audio/", "")]
		if b64.length() < 800:
			failed.emit(DaleLines.MIC_LINES[1])
			return
		_send({"audio": b64, "mime": mime}, _web_persona)
	elif state == "error" or Time.get_ticks_msec() - _since > 6000:
		_web_wait = false
		busy = false
		mic_report = "HELD %.1fs  MIC %s" % [_held, info.to_upper().left(40)]
		failed.emit(DaleLines.MIC_LINES[1])


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
		failed.emit(DaleLines.MIC_LINES[3])


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	var data = JSON.parse_string(body.get_string_from_utf8()) if body.size() > 0 else null
	if result != HTTPRequest.RESULT_SUCCESS or not data is Dictionary:
		failed.emit(DaleLines.MIC_LINES[4])
		return
	var reply := str(data.get("reply", ""))
	if code != 200 or reply == "":
		failed.emit(str(data.get("error", DaleLines.MIC_LINES[5])))
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


## Turns a quiet clip up so its loudest sample sits near 80% (at most 12x).
static func normalize(pcm: PackedByteArray) -> void:
	var p := peak(pcm)
	if p <= 0:
		return
	var gain := minf(26000.0 / p, 12.0)
	if gain <= 1.05:
		return
	for i in range(0, pcm.size() - 1, 2):
		pcm.encode_s16(i, clampi(int(pcm.decode_s16(i) * gain), -32768, 32767))


## Loudest sample in a 16-bit clip (0 to 32767).
static func peak(pcm: PackedByteArray) -> int:
	var p := 0
	for i in range(0, pcm.size() - 1, 8):
		p = maxi(p, absi(pcm.decode_s16(i)))
	return p


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


## A WAV file (as some voices come back) as a playable stream: 16-bit or
## 32-bit float PCM, and streamed files whose data size is left blank.
static func wav_stream(bytes: PackedByteArray) -> AudioStreamWAV:
	var at := 12
	var rate := 24000
	var stereo := false
	var bits := 16
	var fmt := 1
	while at + 8 <= bytes.size():
		var id := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		if id == "fmt ":
			fmt = bytes.decode_u16(at + 8)
			stereo = bytes.decode_u16(at + 10) == 2
			rate = bytes.decode_u32(at + 12)
			bits = bytes.decode_u16(at + 22)
		elif id == "data":
			var end := bytes.size() if size == 0 or at + 8 + size > bytes.size() else at + 8 + size
			var data := bytes.slice(at + 8, end)
			if bits == 32 and fmt == 3:
				var pcm := PackedByteArray()
				pcm.resize(data.size() / 2)
				for k in data.size() / 4:
					pcm.encode_s16(k * 2, clampi(int(data.decode_float(k * 4) * 32767.0), -32768, 32767))
				data = pcm
			elif bits != 16:
				return null
			var w := AudioStreamWAV.new()
			w.format = AudioStreamWAV.FORMAT_16_BITS
			w.mix_rate = rate
			w.stereo = stereo
			w.data = data
			return w
		if size == 0 or size > bytes.size():
			return null
		at += 8 + size + (size & 1)
	return null