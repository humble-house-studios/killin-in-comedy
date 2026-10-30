extends GutTest
## Every order of cards must read as one coherent set. This test keeps its own
## model of the bit being told and checks each line Patter produces against
## exactly what that state allows:
##   Setup     -> a joke's setup; a bridge first if something was already live
##   Punchline -> the newest open joke's punch ("back to X:" if it's an older one)
##   follow-up -> once landed: the live joke's own tags first, then templates;
##                while open: build-up templates; never a landed-only line early
##   Callback  -> an earlier topic (not the live one if there's another), using
##                that joke's tags when any are left
##   nothing left to say about the live joke -> a fresh one-liner with a bridge
##   (joke cards), a stock closer, or a stock line (crowd/meta cards)
## Plus: no line is said twice in a set, and no placeholder is left unfilled.

var _ids: Array = []
var _reps: Array = []
var _stock := {}


func before_all() -> void:
	_ids = CardLibrary.cards().keys()
	# One card per kind of behaviour, for deeper exhaustive runs.
	_reps = ["setup", "punchline", "tag", "big_finish", "callback", "yes_and", "heighten",
		"crowd_work", "read_the_room", "hype_man", "pause_for_effect", "scene_partner", "spit_take"]


# ---------------------------------------------------------------- helpers

func _joke_ending(line: String, key: String, pool: Array) -> Dictionary:
	for joke in pool:
		if line.ends_with(joke[key]):
			return joke
	return {}


func _cap(t: String) -> String:
	return t if t == "" else t[0].to_upper() + t.substr(1)


func _fill(t: String, topic: String, theme := "") -> String:
	return t.replace("{Topic}", _cap(topic)).replace("{topic}", topic) \
		.replace("{theme}", Jokes.THEME_NAMES.get(theme, ""))


func _is_bridge(prefix: String, pool: Array, topic := "", theme := "") -> bool:
	return pool.any(func(t): return _fill(t, topic, theme) == prefix)


func _mentions(line: String, topic: String) -> bool:
	return line.to_lower().contains(topic.to_lower())


## Stock lines a card may fall back to when it has nothing left about the joke.
func _stock_for(id: String, audience: String) -> Array:
	var out: Array = Jokes.CARD_LINES.get(id, []).duplicate()
	if CardLibrary.card(id).reveals_intent and id != "read_the_room":
		out += Jokes.CROWD_WORK.get(audience, []) + Jokes.CROWD_WORK["any"]
	if out.is_empty():
		out.append(CardLibrary.card(id).line)
	return out


class Model:
	var pending: Array = []
	var joked: Array = []
	var thread := ""
	var closed := false
	var tags_used := {}   # topic -> tags said this set
	var tmpl_used := {}   # card id -> template indices said this set
	var milked := 0       # template lines said about the live joke
	var again := false    # said "no, seriously, goodnight" since the last goodnight
	var early := false    # made the "big finish already?" joke this set
	var said := {}


## Index of the template this line came from (for the live topic), or -1.
func _template_index(id: String, line: String, topic: String, landed: bool) -> int:
	var lines: Array = Jokes.TOPIC_LINES.get(id, [])
	for i in lines.size():
		var l: String = lines[i]
		if landed and l.begins_with(Jokes.OPEN) or not landed and l.begins_with(Jokes.AFTER):
			continue
		if _fill(l.trim_prefix(Jokes.AFTER).trim_prefix(Jokes.OPEN), topic) == line:
			return i
	return -1


func _templates_left(m: Model, id: String, landed: bool) -> bool:
	var lines: Array = Jokes.TOPIC_LINES.get(id, [])
	for i in lines.size():
		var l: String = lines[i]
		if landed and l.begins_with(Jokes.OPEN) or not landed and l.begins_with(Jokes.AFTER):
			continue
		if not m.tmpl_used.get(id, []).has(i):
			return true
	return false


func _tags_left(m: Model, topic: String) -> Array:
	var used: Array = m.tags_used.get(topic, [])
	return Jokes.joke_about(topic).get("tags", []).filter(func(t): return not used.has(t))


## The unused tag of `topic` this line is built on, or "".
func _tag_in(m: Model, line: String, topic: String) -> String:
	for tag in _tags_left(m, topic):
		if line.contains(tag.substr(1)):
			return tag
	return ""


func _use_tag(m: Model, topic: String, tag: String) -> void:
	var used: Array = m.tags_used.get(topic, [])
	used.append(tag)
	m.tags_used[topic] = used


## The bridge the model expects before a new joke, as a check on `prefix`.
func _bridge_ok(m: Model, prefix: String, topic: String) -> bool:
	if m.closed:
		m.again = false
		return _is_bridge(prefix, Jokes.BRIDGE_ENCORE)
	if m.thread == "":
		return prefix == ""
	if not m.pending.is_empty():
		return _is_bridge(prefix, Jokes.BRIDGE_ANOTHER_OPEN)
	var theme := Jokes.theme_of(topic)
	if theme != "" and theme == Jokes.theme_of(m.thread):
		return _is_bridge(prefix, Jokes.BRIDGE_SAME_THEME, "", theme)
	return _is_bridge(prefix, Jokes.BRIDGE_NEW_THEME)


func _open(m: Model, topic: String) -> bool:
	return m.pending.any(func(j): return j.topic == topic)


func _move_to(m: Model, topic: String) -> void:
	if topic != m.thread:
		m.milked = 0
	m.thread = topic


## Checks a fresh one-liner (with its bridge) and moves the model onto it.
func _fresh(m: Model, line: String, where: String, problems: Array) -> void:
	var one := _joke_ending(line, "line", Jokes.ONE_LINERS)
	if one.is_empty():
		problems.append("should be a fresh one-liner " + where)
		return
	if not _bridge_ok(m, line.trim_suffix(one.line).strip_edges(), one.topic):
		problems.append("wrong bridge before a fresh one-liner " + where)
	m.closed = false
	if not m.joked.has(one.topic):
		m.joked.append(one.topic)
	_move_to(m, one.topic)


# ---------------------------------------------------------------- the model

## Plays the sequence and returns every way a line failed to fit.
func _check(seq: Array, seed: int, audience := "open_mic") -> Array:
	var p := Patter.new(seed)
	p.start_set()
	var m := Model.new()
	var problems: Array = []
	for id in seq:
		var card := CardLibrary.card(id)
		var line := p.line_for(card, audience)
		var where := "%s in %s: '%s'" % [id, str(seq), line]
		var closer: bool = id == "big_finish" or id == "mic_drop"
		if line == "" or line.contains("{") or line.contains("}") or line.contains("|"):
			problems.append("empty or unfilled " + where)
		if m.said.has(line):
			problems.append("said twice in one set " + where)
		m.said[line] = true

		if card.setups > 0:
			var joke := _joke_ending(line, "setup", Jokes.JOKES)
			if joke.is_empty():
				problems.append("setup isn't a joke setup " + where)
				continue
			if not _bridge_ok(m, line.trim_suffix(joke.setup).strip_edges(), joke.topic):
				problems.append("wrong bridge before a setup " + where)
			m.closed = false
			m.pending.append(joke)
			_move_to(m, joke.topic)

		elif card.is_punchline and not m.pending.is_empty():
			var joke: Dictionary = m.pending.pop_back()
			if not line.ends_with(joke.punch):
				problems.append("punch isn't the newest setup's (%s) %s" % [joke.punch, where])
			else:
				var prefix := line.trim_suffix(joke.punch).strip_edges()
				if joke.topic == m.thread and prefix != "":
					problems.append("needless 'back to' bridge " + where)
				if joke.topic != m.thread and not _is_bridge(prefix, Jokes.BRIDGE_RESUME, joke.topic):
					problems.append("finishing an older joke needs a 'back to' bridge " + where)
			if not m.joked.has(joke.topic):
				m.joked.append(joke.topic)
			_move_to(m, joke.topic)

		elif card.laughs_per_card_this_set > 0:
			var options := []
			for t in m.joked + ([m.thread] if m.thread != "" else []):
				if not options.has(t):
					options.append(t)
			if options.is_empty():
				_fresh(m, line, where, problems)
				continue
			var topic := p._thread
			if not options.has(topic):
				problems.append("callback to something never joked about " + where)
				continue
			if options.size() > 1 and topic == m.thread:
				problems.append("callback to the joke still being told " + where)
			if not _mentions(line, topic):
				problems.append("callback doesn't name its topic " + where)
			if not _open(m, topic) and not _tags_left(m, topic).is_empty():
				var tag := _tag_in(m, line, topic)
				if tag == "":
					problems.append("callback skipped that joke's own tags " + where)
				else:
					_use_tag(m, topic, tag)
			_move_to(m, topic)

		elif closer and m.closed and not m.again:
			if not Jokes.CLOSE_AGAIN.has(line):
				problems.append("second goodnight should say so " + where)
			m.again = true

		elif closer and m.closed:
			_fresh(m, line, where, problems)  # third goodnight: an encore joke

		elif closer and m.thread == "" and m.joked.is_empty() and not m.early:
			if not Jokes.CLOSE_EARLY.has(line):
				problems.append("closer before any joke should joke about it " + where)
			m.early = true

		elif closer and m.thread == "" and m.joked.is_empty():
			_fresh(m, line, where, problems)

		elif m.thread == "" and closer:
			if not Jokes.CLOSERS.has(line):
				problems.append("closer with nothing live should be a stock closer " + where)
			m.closed = true

		elif m.thread == "" and (card.is_punchline or id in Patter.NEEDS_A_JOKE):
			_fresh(m, line, where, problems)

		elif m.thread != "":
			var landed := not _open(m, m.thread)
			if landed and Jokes.CONNECT.has(id) and not _tags_left(m, m.thread).is_empty():
				var tag := _tag_in(m, line, m.thread)
				if tag == "":
					problems.append("didn't use the joke's own tags (%s) %s" % [m.thread, where])
				else:
					_use_tag(m, m.thread, tag)
					m.closed = m.closed or closer
			elif m.milked < Patter.TEMPLATES_PER_JOKE and _templates_left(m, id, landed):
				var i := _template_index(id, line, m.thread, landed)
				if i < 0 or m.tmpl_used.get(id, []).has(i):
					problems.append("doesn't follow the live joke (%s, %s) %s" % [
						m.thread, "landed" if landed else "open", where])
				else:
					var used: Array = m.tmpl_used.get(id, [])
					used.append(i)
					m.tmpl_used[id] = used
					m.milked += 1
					m.closed = m.closed or closer
			elif closer:
				if not Jokes.CLOSERS.has(line):
					problems.append("out of material, should close with a stock closer " + where)
				m.closed = true
			elif card.is_punchline or id in Patter.NEEDS_A_JOKE:
				_fresh(m, line, where, problems)
			elif not _stock_for(id, audience).has(line):
				problems.append("out of material, should be a stock line " + where)

		elif not _stock_for(id, audience).has(line):
			problems.append("nothing live, should be a stock line " + where)

		if p._thread != m.thread:
			problems.append("thread is '%s', expected '%s' %s" % [p._thread, m.thread, where])
		if p._pending.size() != m.pending.size():
			problems.append("open jokes: %d, expected %d %s" % [p._pending.size(), m.pending.size(), where])
		if p._closed != m.closed:
			problems.append("closed is %s, expected %s %s" % [p._closed, m.closed, where])
	return problems


func _report(bad: Array) -> String:
	return "%d problems, e.g.\n%s" % [bad.size(), "\n".join(bad.slice(0, 10))]


# ---------------------------------------------------------------- the runs

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
	var kinds := ["setup", "punchline", "callback", "yes_and", "tag", "crowd_work", "big_finish"]
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
	for n in 3000:
		var seq: Array = []
		for i in rng.randi_range(4, 20):
			seq.append(_ids[rng.randi_range(0, _ids.size() - 1)])
		bad.append_array(_check(seq, n))
	assert_eq(bad.size(), 0, _report(bad))


func test_one_card_spammed_all_set() -> void:
	# Worst case for running out of material: the same card ten times in a row.
	var bad: Array = []
	for id in _ids:
		for lead in ["setup", "punchline"]:
			for seed in 3:
				var seq: Array = [lead]
				for i in 10:
					seq.append(id)
				bad.append_array(_check(seq, seed))
	assert_eq(bad.size(), 0, _report(bad))
