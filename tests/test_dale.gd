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
