class_name Patter
extends RefCounted
## Picks what the comedian says for each card, from res://data/jokes.gd.
##
## A comedic state machine, so any order of cards makes sense:
##  - State: the live joke (`_thread`), the jokes still waiting for a punchline
##    (`_pending`, a stack) and the topics already told (`_topics`).
##  - Each card is rendered from that state, never from the card alone:
##    Setup opens a joke, Punchline finishes the newest open one, Callback
##    returns to something told, and every other card riffs on the live joke.
##    With no joke live, cards that need one tell a fresh one-liner first.
##  - Whenever the topic changes (a new Setup, or a Punchline finishing an older
##    joke) a bridge phrase is put in front, so the jump is always explained.
## Lives for a whole run so later sets get fresh material; no repeats until a
## pool runs out.

const NEEDS_A_JOKE := ["yes_and", "heighten", "riff", "act_out", "spit_take", "rule_of_three",
	"crowd_favorite", "tag"]
## Chance a new Setup/one-liner stays on the current theme. 1: stay on theme
## whenever an unused joke of that theme is left.
const THEME_CHANCE := 1.0

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
## True after a closer said goodnight; the next new joke is an encore.
var _closed := false
## Pool name -> index drawn last, so a reshuffle never repeats a line back to back.
var _last := {}


func _init(rng_seed := 0) -> void:
	_rng.seed = rng_seed


func start_set() -> void:
	_pending.clear()
	_topics.clear()
	_thread = ""
	_theme = ""
	_closed = false


func opener() -> String:
	return _draw("opener", Jokes.CARD_LINES["opener"])


func line_for(card: CardData, audience_id := "") -> String:
	if card.setups > 0:
		var joke: Dictionary = _draw("jokes", Jokes.JOKES, _theme)
		var bridge := _bridge_to_setup(joke)
		_pending.append(joke)
		_set_thread(joke.topic)
		return joke.setup if bridge == "" else bridge + " " + joke.setup
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
	var landed := _pending.is_empty()
	var pool: Array = Jokes.TOPIC_LINES[card_id].filter(
		func(l: String): return landed or not l.begins_with(Jokes.AFTER))
	var line: String = _draw("thread_%s_%s" % [card_id, landed], pool)
	return _fill(line.trim_prefix(Jokes.AFTER), _thread)


## Words that explain why a new Setup is coming, or "" if it follows on from nothing.
func _bridge_to_setup(joke: Dictionary) -> String:
	if _closed:
		_closed = false
		return _draw("bridge_encore", Jokes.BRIDGE_ENCORE)
	if _thread == "":
		return ""
	if not _pending.is_empty():
		return _draw("bridge_open", Jokes.BRIDGE_ANOTHER_OPEN)
	var theme := Jokes.theme_of(joke.topic)
	if theme != "" and theme == _theme:
		return _draw("bridge_same", Jokes.BRIDGE_SAME_THEME).replace("{theme}", Jokes.THEME_NAMES[theme])
	return _draw("bridge_new", Jokes.BRIDGE_NEW_THEME)


func _set_thread(topic: String) -> void:
	_thread = topic
	_theme = Jokes.theme_of(topic)


func _fill(template: String, topic: String) -> String:
	return template.replace("{Topic}", topic[0].to_upper() + topic.substr(1)) \
		.replace("{topic}", topic)


func _punchline(card: CardData) -> String:
	if not _pending.is_empty():
		var joke: Dictionary = _pending.pop_back()
		var resumed: bool = joke.topic != _thread
		_topics.append(joke.topic)
		_set_thread(joke.topic)
		if resumed:
			return _fill(_draw("bridge_resume", Jokes.BRIDGE_RESUME), joke.topic) + " " + joke.punch
		return joke.punch
	var threaded := _threaded(card.id)
	if threaded != "":
		_closed = _closed or card.id == "big_finish" or card.id == "mic_drop"
		return threaded
	if card.id == "tag":
		return _fresh_bit()
	if card.id == "big_finish" or card.id == "mic_drop":
		_closed = true
		return _draw("closers", Jokes.CLOSERS)
	return _fresh_bit()


## A stand-alone one-liner. It becomes the live joke other cards riff on.
func _fresh_bit() -> String:
	var one: Dictionary = _draw("one_liners", Jokes.ONE_LINERS, _theme)
	var encore := ""
	if _closed:
		_closed = false
		encore = _draw("bridge_encore", Jokes.BRIDGE_ENCORE) + " "
	if not _topics.has(one.topic):
		_topics.append(one.topic)
	_set_thread(one.topic)
	return encore + one.line


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
		# Never open a fresh cycle with the line that closed the last one.
		if pool.size() > 1 and bag.back() == _last.get(pool_name, -1):
			var tmp2 = bag[0]
			bag[0] = bag.back()
			bag[bag.size() - 1] = tmp2
		_bags[pool_name] = bag
	if theme != "" and _rng.randf() < THEME_CHANCE:
		for i in range(bag.size() - 1, -1, -1):
			if Jokes.theme_of(pool[bag[i]].topic) == theme:
				var picked: int = bag[i]
				bag.remove_at(i)
				_last[pool_name] = picked
				return pool[picked]
	var last: int = bag.pop_back()
	_last[pool_name] = last
	return pool[last]
