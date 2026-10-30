extends GutTest
## What the comedian says: enough material, no repeats, and jokes that
## connect (Setup -> Punchline, Callback -> earlier topic).


func _count_lines() -> int:
	var total := Jokes.JOKES.size() + Jokes.ONE_LINERS.size() + Jokes.TAGS.size() \
		+ Jokes.CLOSERS.size() + Jokes.CALLBACKS.size()
	for key in Jokes.CROWD_WORK:
		total += Jokes.CROWD_WORK[key].size()
	for key in Jokes.CARD_LINES:
		total += Jokes.CARD_LINES[key].size()
	return total


func test_at_least_100_jokes_and_lines() -> void:
	assert_gte(Jokes.JOKES.size(), 90)
	assert_gte(Jokes.ONE_LINERS.size(), 72)
	assert_gte(_count_lines(), 300)


func test_setup_then_punchline_tells_the_same_joke() -> void:
	var p := Patter.new(1)
	var setup := p.line_for(CardLibrary.card("setup"))
	var punch := p.line_for(CardLibrary.card("punchline"))
	var matched := false
	for joke in Jokes.JOKES:
		if joke.setup == setup:
			matched = joke.punch == punch
	assert_true(matched, "%s / %s" % [setup, punch])


func test_punchline_alone_is_a_one_liner() -> void:
	var p := Patter.new(1)
	var line := p.line_for(CardLibrary.card("punchline"))
	assert_true(Jokes.ONE_LINERS.any(func(o): return o.line == line), line)


func test_no_repeats_until_pool_is_used_up() -> void:
	var p := Patter.new(5)
	var seen := {}
	for i in Jokes.ONE_LINERS.size():
		p.start_set()  # nothing live, so each Punchline is a fresh one-liner
		seen[p.line_for(CardLibrary.card("punchline"))] = true
	assert_eq(seen.size(), Jokes.ONE_LINERS.size())


func test_callback_brings_back_an_earlier_topic() -> void:
	var p := Patter.new(2)
	p.line_for(CardLibrary.card("setup"))
	p.line_for(CardLibrary.card("punchline"))
	var topic: String = p._topics[0]
	var line := p.line_for(CardLibrary.card("callback"))
	assert_true(line.to_lower().contains(topic.to_lower()), "%s / %s" % [topic, line])
	assert_false(line.contains("{"), line)


func test_callback_with_nothing_to_call_back_tells_a_fresh_joke() -> void:
	var p := Patter.new(2)
	var line := p.line_for(CardLibrary.card("callback"))
	assert_true(Jokes.ONE_LINERS.any(func(o): return o.line == line), line)


func test_crowd_work_fits_the_crowd() -> void:
	var p := Patter.new(3)
	var line := p.line_for(CardLibrary.card("crowd_work"), "bachelorette")
	var pool: Array = Jokes.CROWD_WORK["bachelorette"] + Jokes.CROWD_WORK["any"]
	assert_has(pool, line)


func test_new_set_forgets_old_setups_and_topics() -> void:
	var p := Patter.new(4)
	p.line_for(CardLibrary.card("setup"))
	p.start_set()
	assert_eq(p._pending.size(), 0)
	assert_eq(p._topics.size(), 0)


func test_every_card_has_something_to_say() -> void:
	var p := Patter.new(6)
	for id in CardLibrary.cards():
		for audience in CardLibrary.audiences():
			assert_ne(p.line_for(CardLibrary.card(id), audience), "", id)


func test_every_joke_topic_has_a_theme() -> void:
	for joke in Jokes.JOKES + Jokes.ONE_LINERS:
		assert_ne(Jokes.theme_of(joke.topic), "", joke.topic)


func test_setups_stay_on_theme() -> void:
	for seed in 40:
		var p := Patter.new(seed)
		p.line_for(CardLibrary.card("setup"))
		var theme: String = p._theme
		p.line_for(CardLibrary.card("setup"))
		assert_eq(p._theme, theme)


func test_punchline_answers_the_newest_setup() -> void:
	var p := Patter.new(3)
	var first := p.line_for(CardLibrary.card("setup"))
	var second := p.line_for(CardLibrary.card("setup"))
	var punch := p.line_for(CardLibrary.card("punchline"))
	var joke := {}
	for j in Jokes.JOKES:
		if j.setup == second:
			joke = j
	assert_eq(punch, joke.punch, "after '%s' / '%s'" % [first, second])


func test_other_cards_riff_on_the_live_joke() -> void:
	var riffed := 0
	for seed in 40:
		var p := Patter.new(seed)
		p.line_for(CardLibrary.card("setup"))
		var topic: String = p._thread
		var line := p.line_for(CardLibrary.card("heighten"))
		assert_false(line.contains("{"), line)
		riffed += 1 if line.to_lower().contains(topic.to_lower()) else 0
	assert_eq(riffed, 40)


func test_follow_up_cards_with_no_joke_start_one() -> void:
	var p := Patter.new(8)
	var line := p.line_for(CardLibrary.card("heighten"))
	assert_true(Jokes.ONE_LINERS.any(func(o): return o.line == line), line)
	var next := p.line_for(CardLibrary.card("yes_and"))
	assert_true(next.to_lower().contains(p._thread.to_lower()), next)
