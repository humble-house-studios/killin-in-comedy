class_name Patter
extends RefCounted
## Picks what the comedian says for each card, from res://data/jokes.gd, so
## lines don't repeat until a pool runs out. A Setup starts a two-part joke
## that the next Punchline finishes; Callback brings back an earlier topic.
## Jokes link up: a Setup prefers the same theme as the last joke, and other
## cards riff on the joke that's live ("thread") so a turn hangs together.
## Lives for a whole run so later sets get fresh material.

## Cards whose lines only make sense after a joke. Played with nothing live,
## they tell a fresh one-liner instead, which becomes the joke to follow up.
const NEEDS_A_JOKE := ["yes_and", "heighten", "riff", "act_out", "spit_take", "rule_of_three",
	"crowd_favorite", "tag"]
## Chance a Setup/one-liner stays on the current theme, and that a card
## riffs on the live joke instead of using a stock line. Both are 1: a joke
## that's been started is followed through, so a turn always makes sense.
const THEME_CHANCE := 1.0
const RIFF_CHANCE := 1.0

var _rng := RandomNumberGenerator.new()
## Pool name -> indices not yet used this cycle.
var _bags := {}
## Jokes set up and waiting for a punchline, newest last. A Punchline finishes
## the newest, so it always answers the Setup you just heard.
var _pending: Array = []
## Topics joked about this set, for callbacks.
var _topics: Array[String] = []
## What the last joke was about, so other cards can riff on it. "" = nothing yet.
var _thread := ""
var _theme := ""


func _init(rng_seed := 0) -> void:
	_rng.seed = rng_seed


func start_set() -> void:
	_pending.clear()
	_topics.clear()
	_thread = ""
	_theme = ""


func opener() -> String:
	return _draw("opener", Jokes.CARD_LINES["opener"])


func line_for(card: CardData, audience_id := "") -> String:
	if card.setups > 0:
		var joke: Dictionary = _draw("jokes", Jokes.JOKES, _theme)
		_pending.append(joke)
		_set_thread(joke.topic)
		return joke.setup
	if card.is_punchline:
		return _punchline(card)
	if card.laughs_per_card_this_set > 0:
		return _callback()
	if _thread == "" and card.id in NEEDS_A_JOKE:
		return _fresh_bit()
	var threaded := _threaded(card.id)
	if threaded != "":
		return threaded
	if card.reveals_intent and card.id != "read_the_room":
		var pool: Array = Jokes.CROWD_WORK.get(audience_id, []) + Jokes.CROWD_WORK["any"]
		return _draw("crowd_" + audience_id, pool)
	if Jokes.CARD_LINES.has(card.id):
		return _draw(card.id, Jokes.CARD_LINES[card.id])
	return card.line


## A line about the live joke, or "" if there isn't one or this card has none.
func _threaded(card_id: String) -> String:
	if _thread == "" or not Jokes.TOPIC_LINES.has(card_id):
		return ""
	# A Tag only makes sense tacked onto something, so it always does.
	if card_id != "tag" and _rng.randf() >= RIFF_CHANCE:
		return ""
	return _fill(_draw("thread_" + card_id, Jokes.TOPIC_LINES[card_id]), _thread)


func _set_thread(topic: String) -> void:
	_thread = topic
	_theme = Jokes.theme_of(topic)


func _fill(template: String, topic: String) -> String:
	return template.replace("{Topic}", topic[0].to_upper() + topic.substr(1)) \
		.replace("{topic}", topic)


func _punchline(card: CardData) -> String:
	if not _pending.is_empty():
		var joke: Dictionary = _pending.pop_back()
		_topics.append(joke.topic)
		_set_thread(joke.topic)
		return joke.punch
	var threaded := _threaded(card.id)
	if threaded != "":
		return threaded
	if card.id == "tag":
		return _fresh_bit()
	if card.id == "big_finish" or card.id == "mic_drop":
		return _draw("closers", Jokes.CLOSERS)
	return _fresh_bit()


## A stand-alone one-liner. It becomes the live joke other cards riff on.
func _fresh_bit() -> String:
	var one: Dictionary = _draw("one_liners", Jokes.ONE_LINERS, _theme)
	if not _topics.has(one.topic):
		_topics.append(one.topic)
	_set_thread(one.topic)
	return one.line


func _callback() -> String:
	var options := _topics.duplicate()
	if _thread != "" and not options.has(_thread):
		options.append(_thread)
	if options.is_empty():
		return _fresh_bit()
	var topic: String = options[_rng.randi_range(0, options.size() - 1)]
	var template: String = _draw("callbacks", Jokes.CALLBACKS)
	_set_thread(topic)
	return _fill(template, topic)


## Next unused item from a pool; reshuffles once every item has been used.
## With a theme, takes an unused item of that theme if there is one.
func _draw(pool_name: String, pool: Array, theme := "") -> Variant:
	var bag: Array = _bags.get(pool_name, [])
	if bag.is_empty():
		bag = range(pool.size())
		for i in range(bag.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
		_bags[pool_name] = bag
	if theme != "" and _rng.randf() < THEME_CHANCE:
		for i in range(bag.size() - 1, -1, -1):
			if Jokes.theme_of(pool[bag[i]].topic) == theme:
				var picked: int = bag[i]
				bag.remove_at(i)
				return pool[picked]
	return pool[bag.pop_back()]
