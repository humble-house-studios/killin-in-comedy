class_name Patter
extends RefCounted
## Picks what the comedian says for each card, from res://data/jokes.gd.
##
## A comedic state machine, so any order of cards makes sense:
##  - State: the live joke (`_thread`), the jokes still waiting for a punchline
##    (`_pending`, a stack) and the topics already told (`_topics`).
##  - Each card is rendered from that state, never from the card alone:
##    Setup opens a joke, Punchline finishes the newest open one, Callback
##    returns to something told, and every other card follows up the live joke.
##    With no joke live, cards that need one tell a fresh one-liner first.
##  - Follow-ups after a joke lands use that joke's own written tags first,
##    led in by a phrase that fits the card ("Yes! And...", "But wait:").
##    Generic templates only fill in once those run out, and only a couple per
##    joke: then the comedian moves on (a new bit, or a topic-free crowd line)
##    instead of milking it.
##  - Whenever the topic changes (a new Setup, a Punchline finishing an older
##    joke, an encore after a closer) a bridge phrase explains the jump.
##  - No line is said twice in one set, and nothing repeats across the run
##    until its pool is used up.

const NEEDS_A_JOKE := ["yes_and", "heighten", "riff", "act_out", "spit_take", "rule_of_three",
	"crowd_favorite", "tag"]
## Chance a new Setup/one-liner stays on the current theme. 1: stay on theme
## whenever an unused joke of that theme is left.
const THEME_CHANCE := 1.0
## Generic template lines allowed per joke before the comedian moves on. A
## joke's own written tags don't count: those are always worth saying.
const TEMPLATES_PER_JOKE := 2

var _rng := RandomNumberGenerator.new()
## Pool name -> indices not yet drawn this cycle (across the whole run).
var _bags := {}
## Pool name -> indices drawn this set, so a set never repeats itself.
var _set_used := {}
## Pool name -> index drawn last, so a new cycle never opens with it.
var _last := {}
## Jokes set up and waiting for a punchline, newest last. A Punchline finishes
## the newest, so it always answers the Setup you just heard.
var _pending: Array = []
## Topics joked about this set, oldest first, for callbacks.
var _topics: Array[String] = []
## What the live joke is about, so other cards can follow it up. "" = nothing yet.
var _thread := ""
var _theme := ""
## True after a closer said goodnight; the next new joke is an encore.
var _closed := false
## Generic template lines said about the live joke so far.
var _milked := 0
## Said "no, seriously, goodnight" since the last goodnight / an early closer this set.
var _again := false
var _early := false


func _init(rng_seed := 0) -> void:
	_rng.seed = rng_seed


func start_set() -> void:
	_pending.clear()
	_topics.clear()
	_set_used.clear()
	_thread = ""
	_theme = ""
	_closed = false
	_milked = 0
	_again = false
	_early = false


func opener() -> String:
	return _draw("opener", Jokes.CARD_LINES["opener"])


func line_for(card: CardData, audience_id := "") -> String:
	# A joke card with a topic opens jokes on that topic.
	var want := card.topic if card.topic != "" else _theme
	if card.setups > 0:
		var joke: Dictionary = _draw("jokes", Jokes.JOKES, want)
		var bridge := _bridge_to(joke)
		_pending.append(joke)
		_set_thread(joke.topic)
		return joke.setup if bridge == "" else bridge + " " + joke.setup
	if card.is_punchline:
		return _punchline(card, want)
	if card.laughs_per_card_this_set > 0:
		return _callback()
	if _thread == "" and card.id in NEEDS_A_JOKE:
		return _fresh_bit(want)
	var follow := _follow_up(card.id)
	if follow != "":
		return follow
	if card.id in NEEDS_A_JOKE:
		# Said everything it can about the live joke: move on to a new one.
		return _fresh_bit(want)
	if card.reveals_intent and card.id != "read_the_room":
		var pool: Array = Jokes.CROWD_WORK.get(audience_id, []) + Jokes.CROWD_WORK["any"]
		return _draw("crowd_" + audience_id, pool)
	if Jokes.CARD_LINES.has(card.id):
		return _draw(card.id, Jokes.CARD_LINES[card.id])
	return card.line


## A line following up the live joke, or "" if nothing is live or this card
## has nothing to say about it.
func _follow_up(card_id: String) -> String:
	if _thread == "":
		return ""
	var landed := not _is_open(_thread)
	if landed and Jokes.CONNECT.has(card_id):
		var tag := _next_tag(_thread)
		if tag != "":
			return _connect(card_id, tag, _thread)
	if not Jokes.TOPIC_LINES.has(card_id) or _milked >= TEMPLATES_PER_JOKE:
		return ""
	var skip := Jokes.OPEN if landed else Jokes.AFTER
	var allow := func(l: String): return not l.begins_with(skip)
	var pool: Array = Jokes.TOPIC_LINES[card_id]
	if not _has_fresh("thread_" + card_id, pool, allow):
		return ""
	var line: String = _draw("thread_" + card_id, pool, "", allow)
	_milked += 1
	return _fill(line.trim_prefix(Jokes.AFTER).trim_prefix(Jokes.OPEN), _thread)


func _punchline(card: CardData, want := "") -> String:
	if not _pending.is_empty():
		var joke: Dictionary = _pending.pop_back()
		var resumed: bool = joke.topic != _thread
		_remember(joke.topic)
		_set_thread(joke.topic)
		if resumed:
			return _fill(_draw("bridge_resume", Jokes.BRIDGE_RESUME), joke.topic) + " " + joke.punch
		return joke.punch
	var closer := card.id == "big_finish" or card.id == "mic_drop"
	if closer and _closed:
		# Can't leave the stage: "no, seriously, goodnight", then an encore.
		if not _again:
			_again = true
			return _draw("close_again", Jokes.CLOSE_AGAIN)
		return _fresh_bit(want)
	if closer and _thread == "" and _topics.is_empty():
		if not _early:
			_early = true
			return _draw("close_early", Jokes.CLOSE_EARLY)
		return _fresh_bit(want)
	if _thread != "":
		var follow := _follow_up(card.id)
		if follow != "":
			_closed = _closed or closer
			return follow
	if closer:
		_closed = true
		return _draw("closers", Jokes.CLOSERS)
	return _fresh_bit(want)


## A stand-alone one-liner. It becomes the live joke other cards follow up.
func _fresh_bit(theme := "") -> String:
	var one: Dictionary = _draw("one_liners", Jokes.ONE_LINERS, theme if theme != "" else _theme)
	var bridge := _bridge_to(one)
	_remember(one.topic)
	_set_thread(one.topic)
	return one.line if bridge == "" else bridge + " " + one.line


## Goes back to something told earlier (not the joke being told right now, if
## there's anything else), with a fresh tag from that joke when one is left.
func _callback() -> String:
	var options := _topics.duplicate()
	if _thread != "" and not options.has(_thread):
		options.append(_thread)
	if options.is_empty():
		return _fresh_bit()
	if options.size() > 1:
		options.erase(_thread)
	var topic: String = options[_rng.randi_range(0, options.size() - 1)]
	_set_thread(topic)
	if not _is_open(topic):
		var tag := _next_tag(topic)
		if tag != "":
			return _connect("callback", tag, topic)
	return _fill(_draw("callbacks", Jokes.CALLBACKS), topic)


## Words that explain why a new joke is starting, or "" if it follows on from nothing.
func _bridge_to(joke: Dictionary) -> String:
	if _closed:
		_closed = false
		_again = false
		return _draw("bridge_encore", Jokes.BRIDGE_ENCORE)
	if _thread == "":
		return ""
	if not _pending.is_empty():
		return _draw("bridge_open", Jokes.BRIDGE_ANOTHER_OPEN)
	var theme := Jokes.theme_of(joke.topic)
	if theme != "" and theme == _theme:
		return _draw("bridge_same", Jokes.BRIDGE_SAME_THEME).replace("{theme}", Jokes.THEME_NAMES[theme])
	return _draw("bridge_new", Jokes.BRIDGE_NEW_THEME)


## The next unused tag written for the joke about `topic` this set, or "".
func _next_tag(topic: String) -> String:
	var tags: Array = Jokes.joke_about(topic).get("tags", [])
	var pool_name := "tags_" + topic
	if tags.is_empty() or _set_used.get(pool_name, []).size() >= tags.size():
		return ""
	return _draw(pool_name, tags)


## Leads a tag in with a phrase that fits the card that's saying it.
func _connect(card_id: String, tag: String, topic: String) -> String:
	var template: String = _draw("connect_" + card_id, Jokes.CONNECT[card_id])
	return _fill(template.replace("{tag}", tag).replace("{Tag}", tag[0].to_upper() + tag.substr(1)), topic)


func _remember(topic: String) -> void:
	if not _topics.has(topic):
		_topics.append(topic)


## True if the joke about `topic` is set up and still waiting for its punchline.
func _is_open(topic: String) -> bool:
	return _pending.any(func(j): return j.topic == topic)


func _set_thread(topic: String) -> void:
	if topic != _thread:
		_milked = 0
	_thread = topic
	_theme = Jokes.theme_of(topic)


func _fill(template: String, topic: String) -> String:
	return template.replace("{Topic}", topic[0].to_upper() + topic.substr(1)) \
		.replace("{topic}", topic)


## True if the pool still has an item (passing `allow`) not said this set.
func _has_fresh(pool_name: String, pool: Array, allow := Callable()) -> bool:
	var used: Array = _set_used.get(pool_name, [])
	for i in pool.size():
		if not used.has(i) and (not allow.is_valid() or allow.call(pool[i])):
			return true
	return false


## Next item from a pool: never one already said this set (until the pool is
## used up), never a repeat across the run until every item has had a turn,
## and with a theme, an item of that theme when one is available. `allow`
## limits which items may be picked.
func _draw(pool_name: String, pool: Array, theme := "", allow := Callable()) -> Variant:
	var ok := func(i: int) -> bool: return not allow.is_valid() or allow.call(pool[i])
	var used: Array = _set_used.get(pool_name, [])
	var bag: Array = _bags.get(pool_name, [])
	var fresh := bag.filter(func(i): return not used.has(i) and ok.call(i))
	if fresh.is_empty():
		var left := range(pool.size()).filter(func(i): return not used.has(i) and ok.call(i))
		if left.is_empty():
			# Everything allowed was said this set: start over, not with the last line.
			for i in pool.size():
				if ok.call(i):
					used.erase(i)
			left = range(pool.size()).filter(func(i): return ok.call(i))
			if left.size() > 1:
				left.erase(_last.get(pool_name, -1))
		for i in range(left.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp = left[i]
			left[i] = left[j]
			left[j] = tmp
		bag = bag.filter(func(i): return not left.has(i)) + left
		fresh = left.duplicate()
	var pick: int = fresh.back()
	if theme != "" and _rng.randf() < THEME_CHANCE:
		for i in range(fresh.size() - 1, -1, -1):
			if Jokes.theme_of(pool[fresh[i]].topic) == theme:
				pick = fresh[i]
				break
	bag.erase(pick)
	_bags[pool_name] = bag
	used.append(pick)
	_set_used[pool_name] = used
	_last[pool_name] = pick
	return pool[pick]
