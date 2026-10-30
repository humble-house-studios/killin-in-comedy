extends GutTest
## Plays every card after every other card (all 3-card orders, plus long random
## runs) through Patter and checks each line makes sense for what came before.

var _ids: Array = []


func before_all() -> void:
	_ids = CardLibrary.cards().keys()


func _joke_with_setup(setup: String) -> Dictionary:
	for joke in Jokes.JOKES:
		if joke.setup == setup:
			return joke
	return {}


func _is_punch_card(card: CardData) -> bool:
	return card.is_punchline


func _mentions(line: String, topic: String) -> bool:
	return line.to_lower().contains(topic.to_lower())


## Plays the sequence and returns a list of problems (empty = all fine).
func _check(seq: Array, seed: int, audience := "open_mic") -> Array:
	var p := Patter.new(seed)
	p.start_set()
	var problems: Array = []
	var pending: Array = []
	var joked: Array = []
	var thread := ""
	var prev := ""
	for id in seq:
		var card := CardLibrary.card(id)
		var line := p.line_for(card, audience)
		var where := "%s in %s: '%s'" % [id, str(seq), line]
		if line == "" or line.contains("{") or line.contains("}"):
			problems.append("empty or unfilled " + where)
		if line == prev:
			problems.append("repeats the line before " + where)
		prev = line
		if card.setups > 0:
			var joke := _joke_with_setup(line)
			if joke.is_empty():
				problems.append("setup isn't a joke setup " + where)
			else:
				pending.append(joke)
				thread = joke.topic
		elif _is_punch_card(card) and not pending.is_empty():
			var joke: Dictionary = pending.pop_front()
			if line != joke.punch:
				problems.append("punch doesn't match its setup (%s) %s" % [joke.punch, where])
			joked.append(joke.topic)
			thread = joke.topic
		elif card.is_punchline and card.id == "punchline":
			var one := {}
			for o in Jokes.ONE_LINERS:
				if o.line == line:
					one = o
			if one.is_empty():
				problems.append("lone punchline isn't a one-liner " + where)
			else:
				joked.append(one.topic)
				thread = one.topic
		elif card.laughs_per_card_this_set > 0:
			var options := joked.duplicate()
			if thread != "":
				options.append(thread)
			if options.is_empty():
				if not Patter.FALLBACK_CALLBACKS.has(line):
					problems.append("callback with nothing to call back " + where)
			elif not options.any(func(t): return _mentions(line, t)):
				problems.append("callback to something never joked about " + where)
			else:
				thread = options.filter(func(t): return _mentions(line, t))[0]
		elif Jokes.TOPIC_LINES.has(id) and thread != "":
			# Either riffs on the live joke, or is a stock line that names no
			# topic and so can't clash with it.
			var stock: Array = Jokes.CARD_LINES.get(id, []) + (Jokes.TAGS if id == "tag" else []) \
				+ (Jokes.CLOSERS if id == "big_finish" or id == "mic_drop" else [])
			if not _mentions(line, thread) and not stock.has(line):
				problems.append("neither on topic (%s) nor a stock line %s" % [thread, where])
			if id == "tag" and not _mentions(line, thread):
				problems.append("tag after a joke ignores it " + where)
		if p._thread != thread and not (card.laughs_per_card_this_set > 0):
			problems.append("thread is '%s', expected '%s' %s" % [p._thread, thread, where])
	return problems


func test_every_card_after_every_card() -> void:
	var bad: Array = []
	for a in _ids:
		for b in _ids:
			for audience in CardLibrary.audiences():
				for seed in 3:
					bad.append_array(_check([a, b], seed, audience))
	assert_eq(bad.size(), 0, "\n".join(bad.slice(0, 12)))


func test_every_three_card_order() -> void:
	var bad: Array = []
	for a in _ids:
		for b in _ids:
			for c in _ids:
				bad.append_array(_check([a, b, c], hash([a, b, c])))
	assert_eq(bad.size(), 0, "\n".join(bad.slice(0, 12)))


func test_every_card_after_a_setup_or_punchline() -> void:
	# The combos that matter most, many seeds each: Setup/Punchline then anything.
	var bad: Array = []
	for lead in ["setup", "bit", "double_down", "punchline", "tag", "big_finish"]:
		for b in _ids:
			for c in _ids:
				for seed in 6:
					bad.append_array(_check([lead, b, c], seed))
	assert_eq(bad.size(), 0, "\n".join(bad.slice(0, 12)))


func test_long_random_sets() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bad: Array = []
	for n in 1500:
		var seq: Array = []
		for i in rng.randi_range(4, 10):
			seq.append(_ids[rng.randi_range(0, _ids.size() - 1)])
		bad.append_array(_check(seq, n))
	assert_eq(bad.size(), 0, "\n".join(bad.slice(0, 12)))
