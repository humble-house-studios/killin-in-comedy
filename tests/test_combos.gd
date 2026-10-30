extends GutTest
## Every order of cards must read as one coherent set. This test keeps its own
## model of the bit being told (live joke, open setups, topics told) and checks
## each line Patter produces against it, including bridges and stage.
##   Setup    -> a joke's setup, with a bridge if a joke was already live
##   Punchline-> the newest open joke's punch, with a "back to" bridge if the
##               live joke is a different one
##   anything else with a joke live -> a line about the live joke
##   anything else with none live   -> a fresh one-liner (if it needs a joke)
##                                     or a stock line (if it doesn't)

var _ids: Array = []
var _reps: Array = []


func before_all() -> void:
	_ids = CardLibrary.cards().keys()
	# One card per kind of behaviour, for deeper exhaustive runs.
	_reps = ["setup", "punchline", "tag", "big_finish", "callback", "yes_and", "heighten",
		"crowd_work", "read_the_room", "hype_man", "pause_for_effect", "scene_partner", "spit_take"]


func _joke_ending(line: String, key: String) -> Dictionary:
	for joke in Jokes.JOKES:
		if line.ends_with(joke[key]):
			return joke
	return {}


func _fill(t: String, topic: String, theme := "") -> String:
	return t.replace("{Topic}", topic.capitalize() if topic == "" else topic[0].to_upper() + topic.substr(1)) \
		.replace("{topic}", topic).replace("{theme}", Jokes.THEME_NAMES.get(theme, ""))


func _is_bridge(prefix: String, pool: Array, topic := "", theme := "") -> bool:
	return pool.any(func(t): return _fill(t, topic, theme) == prefix)


func _mentions(line: String, topic: String) -> bool:
	return line.to_lower().contains(topic.to_lower())


## The one-liner a line ends with (an encore bridge may come before it).
func _one_liner(line: String) -> Dictionary:
	for o in Jokes.ONE_LINERS:
		if line.ends_with(o.line):
			return o
	return {}


## Checks the words before a fresh joke: nothing, or an encore if a closer just ran.
func _fresh_ok(line: String, one: Dictionary, closed: bool) -> bool:
	var prefix := line.trim_suffix(one.line).strip_edges()
	return _is_bridge(prefix, Jokes.BRIDGE_ENCORE) if closed else prefix == ""


## Plays the sequence and returns every way a line failed to fit.
func _check(seq: Array, seed: int, audience := "open_mic") -> Array:
	var p := Patter.new(seed)
	p.start_set()
	var problems: Array = []
	var pending: Array = []   # open jokes, newest last
	var joked: Array = []
	var thread := ""
	var closed := false
	var prev := ""
	for id in seq:
		var card := CardLibrary.card(id)
		var line := p.line_for(card, audience)
		var where := "%s in %s: '%s'" % [id, str(seq), line]
		if line == "" or line.contains("{") or line.contains("}") or line.contains("after|"):
			problems.append("empty or unfilled " + where)
		if line == prev:
			problems.append("repeats the line before " + where)
		prev = line
		if card.setups > 0:
			var joke := _joke_ending(line, "setup")
			if joke.is_empty():
				problems.append("setup isn't a joke setup " + where)
			else:
				var prefix := line.trim_suffix(joke.setup).strip_edges()
				if closed:
					if not _is_bridge(prefix, Jokes.BRIDGE_ENCORE):
						problems.append("new joke after goodnight needs an encore " + where)
				elif thread == "":
					if prefix != "":
						problems.append("bridge with nothing before " + where)
				elif not pending.is_empty():
					if not _is_bridge(prefix, Jokes.BRIDGE_ANOTHER_OPEN):
						problems.append("setup over an open joke needs 'hold that thought' " + where)
				elif Jokes.theme_of(joke.topic) == Jokes.theme_of(thread):
					if not _is_bridge(prefix, Jokes.BRIDGE_SAME_THEME, "", Jokes.theme_of(thread)) \
							and not _is_bridge(prefix, Jokes.BRIDGE_NEW_THEME):
						problems.append("bad same-theme bridge " + where)
				elif not _is_bridge(prefix, Jokes.BRIDGE_NEW_THEME):
					problems.append("changing theme needs a 'different note' bridge " + where)
				closed = false
				pending.append(joke)
				thread = joke.topic
		elif card.is_punchline and not pending.is_empty():
			var joke: Dictionary = pending.pop_back()
			if not line.ends_with(joke.punch):
				problems.append("punch isn't the newest setup's (%s) %s" % [joke.punch, where])
			else:
				var prefix := line.trim_suffix(joke.punch).strip_edges()
				if joke.topic == thread:
					if prefix != "":
						problems.append("needless 'back to' bridge " + where)
				elif not _is_bridge(prefix, Jokes.BRIDGE_RESUME, joke.topic):
					problems.append("finishing an older joke needs a 'back to' bridge " + where)
			joked.append(joke.topic)
			thread = joke.topic
		elif card.laughs_per_card_this_set > 0:
			var options := joked.duplicate()
			if thread != "":
				options.append(thread)
			if options.is_empty():
				var one := _one_liner(line)
				if one.is_empty():
					problems.append("nothing to call back, should be a fresh joke " + where)
				else:
					if not _fresh_ok(line, one, closed):
						problems.append("bad words before a fresh joke " + where)
					closed = false
					joked.append(one.topic)
					thread = one.topic
			elif not options.any(func(t): return _mentions(line, t)) or not p._thread in options:
				problems.append("callback to something never joked about " + where)
			else:
				thread = p._thread
				if not _mentions(line, thread):
					problems.append("callback doesn't name its topic " + where)
		elif thread == "" and (id == "big_finish" or id == "mic_drop"):
			if not Jokes.CLOSERS.has(line):
				problems.append("closer with nothing live should be a stock closer " + where)
			closed = true
		elif thread == "" and (card.is_punchline or card.id in Patter.NEEDS_A_JOKE):
			var one := _one_liner(line)
			if one.is_empty():
				problems.append("nothing live, should be a fresh one-liner " + where)
			else:
				if not _fresh_ok(line, one, closed):
					problems.append("bad words before a fresh joke " + where)
				closed = false
				joked.append(one.topic)
				thread = one.topic
		elif thread != "" and (card.is_punchline or Jokes.TOPIC_LINES.has(id)):
			if not _mentions(line, thread):
				problems.append("ignores the live joke (%s) %s" % [thread, where])
			closed = closed or id == "big_finish" or id == "mic_drop"
			if not pending.is_empty():
				for l in Jokes.TOPIC_LINES.get(id, []):
					if l.begins_with(Jokes.AFTER) and _fill(l.trim_prefix(Jokes.AFTER), thread) == line:
						problems.append("talks as if the joke landed, but it's still open " + where)
		if p._thread != thread:
			problems.append("thread is '%s', expected '%s' %s" % [p._thread, thread, where])
		if p._pending.size() != pending.size():
			problems.append("open jokes: %d, expected %d %s" % [p._pending.size(), pending.size(), where])
	return problems


func _report(bad: Array) -> String:
	return "%d problems, e.g.\n%s" % [bad.size(), "\n".join(bad.slice(0, 10))]


func test_every_card_after_every_card() -> void:
	var bad: Array = []
	for a in _ids:
		for b in _ids:
			for audience in CardLibrary.audiences():
				for seed in 3:
					bad.append_array(_check([a, b], seed, audience))
	assert_eq(bad.size(), 0, _report(bad))


func test_every_three_card_order() -> void:
	var bad: Array = []
	for a in _ids:
		for b in _ids:
			for c in _ids:
				for seed in 2:
					bad.append_array(_check([a, b, c], hash([a, b, c, seed])))
	assert_eq(bad.size(), 0, _report(bad))


func test_every_four_card_order_of_each_kind() -> void:
	var bad: Array = []
	for a in _reps:
		for b in _reps:
			for c in _reps:
				for d in _reps:
					bad.append_array(_check([a, b, c, d], hash([a, b, c, d])))
	assert_eq(bad.size(), 0, _report(bad))


func test_every_five_card_order_of_each_kind_that_matters() -> void:
	# Setups, punchlines and the cards that care about them, in every order.
	var kinds := ["setup", "punchline", "callback", "yes_and", "tag", "crowd_work"]
	var bad: Array = []
	for a in kinds:
		for b in kinds:
			for c in kinds:
				for d in kinds:
					for e in kinds:
						bad.append_array(_check([a, b, c, d, e], hash([a, b, c, d, e])))
	assert_eq(bad.size(), 0, _report(bad))


func test_long_random_sets() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bad: Array = []
	for n in 2000:
		var seq: Array = []
		for i in rng.randi_range(4, 14):
			seq.append(_ids[rng.randi_range(0, _ids.size() - 1)])
		bad.append_array(_check(seq, n))
	assert_eq(bad.size(), 0, _report(bad))
