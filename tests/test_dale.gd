extends GutTest
## Dale's story: chapters unlock in order from the shared office stats, he
## notices what you did since you last talked, and he remembers it.

const PATH := "user://test_dale.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_first_talk_is_the_first_chapter() -> void:
	var d := DaleStory.new(PATH, 1)
	var talk := d.next_talk({})
	assert_eq(talk.id, "pong")
	assert_eq(talk.steps, DaleLines.CHAPTERS[0].steps)


func test_locked_chapter_gives_its_hint() -> void:
	var d := DaleStory.new(PATH, 1)
	d.finish("pong", {})
	var talk := d.next_talk({})
	assert_eq(talk.id, "")
	assert_eq(talk.steps.back().dale, DaleLines.CHAPTERS[1].hint)
	assert_false(d.has_news({}))
	assert_true(d.has_news({"pong_bosses": 1}))


func test_the_story_follows_the_desks() -> void:
	var ids: Array = []
	for ch in DaleLines.CHAPTERS:
		ids.append(ch.id)
	assert_eq(ids, ["pong", "cube", "standup", "slots", "proof", "ladder"])


func test_chapters_unlock_in_order() -> void:
	var d := DaleStory.new(PATH, 1)
	var maxed := {"comedy_sets": 99, "pong_stages": 99, "loot_runs": 99, "loot_wins": 99, "comedy_shows": 99,
		"pong_bosses": 99, "cube_records": 99, "cube_solves": 99, "proof_wins": 99}
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
	d.finish("pong", {"pong_bosses": 0})
	var talk := d.next_talk({"pong_bosses": 1})
	assert_has(DaleLines.REACT.pong_bosses, talk.steps[0].dale)
	assert_eq(talk.id, "cube")


func test_memory_survives_a_reload() -> void:
	var d := DaleStory.new(PATH, 1)
	d.add_trust(2)
	d.finish("pong", {"pong_stages": 4})
	var again := DaleStory.new(PATH, 1)
	assert_eq(again.done, ["pong"] as Array[String])
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
	d.finish("pong", {})
	var p := d.persona({"comedy_sets": 2})
	var told := p.find(DaleLines.CHAPTERS[0].fact)
	var secret := p.find("Secrets you have NOT told yet")
	assert_gt(told, -1)
	assert_gt(secret, told)
	assert_gt(p.find(DaleLines.CHAPTERS.back().fact), secret)
	assert_string_contains(p, "comedy sets 2")
	for ch in DaleLines.CHAPTERS:
		assert_gt(ch.fact.length(), 20, ch.id)


func test_old_story_saves_start_over() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", 1)
	cfg.set_value("story", "done", ["notes", "open_mic"])
	cfg.set_value("story", "trust", 3)
	cfg.save(PATH)
	var d := DaleStory.new(PATH, 1)
	assert_true(d.done.is_empty())
	assert_eq(d.next_talk({}).id, "pong")


func test_todo_says_what_dale_wants_next() -> void:
	var d := DaleStory.new(PATH, 1)
	assert_eq(d.objective({}), "TALK TO DALE (BY THE WINDOW)")
	d.finish("pong", {})
	assert_eq(d.objective({}), "BEAT THE PONG BOSS (STAGE 4)")
	assert_eq(d.objective({"pong_bosses": 1}), "TALK TO DALE")
	for id in ["cube", "standup"]:
		d.finish(id, {})
	assert_eq(d.objective({"comedy_sets": 1}), "CLEAR 2 COMEDY SETS (1/2)")
	for id in ["slots", "proof", "ladder"]:
		d.finish(id, {})
	assert_string_contains(d.objective({}), "DOOR")
	for ch in DaleLines.CHAPTERS.slice(1):
		assert_ne(ch.goal, "", ch.id)


func test_goals_spot_a_pong_boss() -> void:
	var g := OfficeGoals.new()
	assert_eq(g.pong(1, false), 0)
	assert_eq(g.pong(4, false), 0)
	assert_eq(g.pong(5, false), 1)  # cleared the stage 4 boss
	assert_eq(g.pong(5, false), 0)
	assert_eq(g.pong(1, false), 0)  # new run
	assert_eq(g.pong(9, false), 2)
	assert_eq(g.pong(1, false), 0)
	assert_eq(g.pong(5, true), 0)  # test menu


func test_goals_spot_the_cube_record_and_a_proof() -> void:
	var g := OfficeGoals.new()
	assert_eq(g.cube(3, 9), 0)  # already solved before the office looked
	assert_eq(g.cube(4, 5), 0)
	assert_eq(g.cube(5, 9), 1)
	assert_eq(g.cube(5, 9), 0)
	var blind := RefCounted.new()
	assert_eq(g.proof(blind, false), 0)
	assert_eq(g.proof(blind, true), 1)
	assert_eq(g.proof(blind, true), 0)
	assert_eq(g.proof(RefCounted.new(), true), 1)
	assert_eq(g.proof(null, true), 0)


func test_voice_clip_becomes_a_small_wav_and_back() -> void:
	var Voice = load("res://scenes/office/dale_voice.gd")
	# One second of a 48 kHz tone, fed in uneven chunks like real frames.
	var pcm := PackedByteArray()
	var phase := 0.0
	var made := 0
	for chunk in [1000, 4096, 777, 48000 - 5873]:
		var frames := PackedVector2Array()
		for k in chunk:
			var v := sin((made + k) * 0.05) * 0.4
			frames.append(Vector2(v, v))
		phase = Voice.add_frames(pcm, frames, 3.0, phase)
		made += chunk
	assert_eq(pcm.size(), 16000 * 2)
	assert_eq(pcm.decode_s16(2 * 10), int(sin(30 * 0.05) * 0.4 * 32767.0))
	assert_false(Voice.silent(pcm))
	var quiet := PackedByteArray()
	quiet.resize(3200)
	assert_true(Voice.silent(quiet))
	var wav: PackedByteArray = Voice.wav16k(pcm)
	assert_eq(wav.size(), 44 + 16000 * 2)
	assert_eq(wav.slice(0, 4).get_string_from_ascii(), "RIFF")
	var back: AudioStreamWAV = Voice.wav_stream(wav)
	assert_eq(back.mix_rate, 16000)
	assert_false(back.stereo)
	assert_eq(back.data, pcm)


func test_quiet_voice_gets_turned_up() -> void:
	var Voice = load("res://scenes/office/dale_voice.gd")
	var pcm := PackedByteArray()
	pcm.resize(800)
	for i in 400:
		pcm.encode_s16(i * 2, int(sin(i * 0.1) * 2000))
	Voice.normalize(pcm)
	assert_between(Voice.peak(pcm), 20000, 26100)
