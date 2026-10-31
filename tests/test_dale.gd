extends GutTest
## Dale's story: chapters unlock in order from the shared office stats, he
## notices what you did since you last talked, and he remembers it.

const PATH := "user://test_dale.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_first_talk_is_the_first_chapter() -> void:
	var d := DaleStory.new(PATH, 1)
	var talk := d.next_talk({})
	assert_eq(talk.id, "notes")
	assert_eq(talk.steps, DaleLines.CHAPTERS[0].steps)


func test_locked_chapter_gives_its_hint() -> void:
	var d := DaleStory.new(PATH, 1)
	d.finish("notes", {})
	var talk := d.next_talk({})
	assert_eq(talk.id, "")
	assert_eq(talk.steps.back().dale, DaleLines.CHAPTERS[1].hint)
	assert_false(d.has_news({}))
	assert_true(d.has_news({"comedy_sets": 1}))


func test_chapters_unlock_in_order() -> void:
	var d := DaleStory.new(PATH, 1)
	var maxed := {"comedy_sets": 99, "pong_stages": 99, "loot_runs": 99, "loot_wins": 99, "comedy_shows": 99}
	for ch in DaleLines.CHAPTERS:
		var talk := d.next_talk(maxed)
		assert_eq(talk.id, ch.id)
		d.finish(talk.id, maxed)
	assert_true(d.next_chapter().is_empty())
	assert_eq(d.next_talk(maxed).id, "")


func test_any_needs_only_one() -> void:
	var ch := {"need": {"loot_wins": 1, "comedy_sets": 8}, "any": true}
	assert_false(DaleStory.unlocked(ch, {"comedy_sets": 7}))
	assert_true(DaleStory.unlocked(ch, {"loot_wins": 1}))
	assert_true(DaleStory.unlocked(ch, {"comedy_sets": 8}))
	assert_false(DaleStory.unlocked({"need": {"a": 1, "b": 1}}, {"a": 1}))


func test_he_notices_what_you_did() -> void:
	var d := DaleStory.new(PATH, 1)
	d.finish("notes", {"comedy_sets": 0})
	var talk := d.next_talk({"comedy_sets": 1})
	assert_has(DaleLines.REACT.comedy_sets, talk.steps[0].dale)
	assert_eq(talk.id, "open_mic")


func test_memory_survives_a_reload() -> void:
	var d := DaleStory.new(PATH, 1)
	d.add_trust(2)
	d.finish("notes", {"pong_stages": 4})
	var again := DaleStory.new(PATH, 1)
	assert_eq(again.done, ["notes"] as Array[String])
	assert_eq(again.trust, 2)
	assert_eq(int(again.seen.pong_stages), 4)


func test_every_line_fits_the_talk_box() -> void:
	var lines: Array = DaleLines.SMALL_TALK + DaleLines.AFTER
	for key in DaleLines.REACT:
		lines += DaleLines.REACT[key]
	for ch in DaleLines.CHAPTERS:
		lines.append(ch.hint)
		var has_choice := false
		for step in ch.steps:
			if step.has("choices"):
				has_choice = true
				assert_eq(step.choices.size(), 3, ch.id)
				for c in step.choices:
					lines.append(c.text)
					lines.append(c.reply)
					assert_lt(c.text.length(), 28, c.text)
			else:
				lines.append(step.dale)
		assert_true(has_choice, ch.id)
	for line in lines:
		assert_lt(line.length(), 112, line)


func test_persona_keeps_later_chapters_secret() -> void:
	var d := DaleStory.new(PATH, 1)
	d.finish("notes", {})
	var p := d.persona({"comedy_sets": 2})
	var told := p.find(DaleLines.CHAPTERS[0].fact)
	var secret := p.find("Secrets you have NOT told yet")
	assert_gt(told, -1)
	assert_gt(secret, told)
	assert_gt(p.find(DaleLines.CHAPTERS[6].fact), secret)
	assert_string_contains(p, "comedy sets 2")
	for ch in DaleLines.CHAPTERS:
		assert_gt(ch.fact.length(), 20, ch.id)


func test_voice_clip_becomes_a_small_wav_and_back() -> void:
	var Voice = load("res://scenes/office/dale_voice.gd")
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.stereo = true
	clip.mix_rate = 48000
	var pcm := PackedByteArray()
	pcm.resize(48000 * 4)
	for i in 48000:
		var v := int(sin(i * 0.05) * 12000)
		pcm.encode_s16(i * 4, v)
		pcm.encode_s16(i * 4 + 2, v)
	clip.data = pcm
	var wav: PackedByteArray = Voice.to_wav16k(clip)
	assert_eq(wav.size(), 44 + 16000 * 2)
	assert_eq(wav.slice(0, 4).get_string_from_ascii(), "RIFF")
	var back: AudioStreamWAV = Voice.wav_stream(wav)
	assert_eq(back.mix_rate, 16000)
	assert_false(back.stereo)
	assert_eq(back.data.size(), 16000 * 2)
	assert_eq(back.data.decode_s16(2 * 10), int(sin(30 * 0.05) * 12000))
