class_name Patter
extends RefCounted
## Picks what the comedian says for each card, from res://data/jokes.gd, so
## lines don't repeat until a pool runs out. A Setup starts a two-part joke
## that the next Punchline finishes; Callback brings back an earlier topic.
## Lives for a whole run so later sets get fresh material.

const FALLBACK_CALLBACK := "Remember the guy at the bar?"

var _rng := RandomNumberGenerator.new()
## Pool name -> indices not yet used this cycle.
var _bags := {}
## Jokes set up and waiting for a punchline, oldest first.
var _pending: Array = []
## Topics joked about this set, for callbacks.
var _topics: Array[String] = []


func _init(rng_seed := 0) -> void:
	_rng.seed = rng_seed


func start_set() -> void:
	_pending.clear()
	_topics.clear()


func opener() -> String:
	return _draw("opener", Jokes.CARD_LINES["opener"])


func line_for(card: CardData, audience_id := "") -> String:
	if card.setups > 0:
		var joke: Dictionary = _draw("jokes", Jokes.JOKES)
		_pending.append(joke)
		return joke.setup
	if card.is_punchline:
		return _punchline(card)
	if card.laughs_per_card_this_set > 0:
		return _callback()
	if card.reveals_intent and card.id != "read_the_room":
		var pool: Array = Jokes.CROWD_WORK.get(audience_id, []) + Jokes.CROWD_WORK["any"]
		return _draw("crowd_" + audience_id, pool)
	if Jokes.CARD_LINES.has(card.id):
		return _draw(card.id, Jokes.CARD_LINES[card.id])
	return card.line


func _punchline(card: CardData) -> String:
	if not _pending.is_empty():
		var joke: Dictionary = _pending.pop_front()
		_topics.append(joke.topic)
		return joke.punch
	if card.id == "tag":
		return _draw("tags", Jokes.TAGS)
	if card.id == "big_finish" or card.id == "mic_drop":
		return _draw("closers", Jokes.CLOSERS)
	var one: Dictionary = _draw("one_liners", Jokes.ONE_LINERS)
	_topics.append(one.topic)
	return one.line


func _callback() -> String:
	if _topics.is_empty():
		return FALLBACK_CALLBACK
	var topic := _topics[_rng.randi_range(0, _topics.size() - 1)]
	var template: String = _draw("callbacks", Jokes.CALLBACKS)
	return template.replace("{Topic}", topic[0].to_upper() + topic.substr(1)) \
		.replace("{topic}", topic)


## Next unused item from a pool; reshuffles once every item has been used.
func _draw(pool_name: String, pool: Array) -> Variant:
	var bag: Array = _bags.get(pool_name, [])
	if bag.is_empty():
		bag = range(pool.size())
		for i in range(bag.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
		_bags[pool_name] = bag
	return pool[bag.pop_back()]
