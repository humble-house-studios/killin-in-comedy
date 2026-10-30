class_name CardLibrary
## Loads cards and audiences from res://data/ and builds decks and rewards.

const CARD_DIR := "res://data/cards/"
const AUDIENCE_DIR := "res://data/audiences/"

static var _cards := {}
static var _audiences := {}


static func cards() -> Dictionary:
	if _cards.is_empty():
		_cards = _load_dir(CARD_DIR)
	return _cards


static func audiences() -> Dictionary:
	if _audiences.is_empty():
		_audiences = _load_dir(AUDIENCE_DIR)
	return _audiences


static func card(id: String) -> CardData:
	return cards().get(id)


static func audience(id: String) -> AudienceData:
	return audiences().get(id)


## The starting deck. With an rng, each joke card rolls a topic, spread so the
## deck covers every topic; without one, cards are topic-free (for tests).
static func starter_deck(rng: RandomNumberGenerator = null) -> Array[CardData]:
	var deck: Array[CardData] = []
	var topics := _topic_bag(rng)
	for id in Balance.STARTER_DECK:
		for i in Balance.STARTER_DECK[id]:
			var c := card(id)
			if rng and c.is_joke():
				if topics.is_empty():
					topics = _topic_bag(rng)
				c = c.with_topic(topics.pop_back())
			deck.append(c)
	return deck


## Every card that can be offered as a reward (anything not in the starter deck).
static func reward_pool() -> Array[CardData]:
	var pool: Array[CardData] = []
	for id in cards():
		if not Balance.STARTER_DECK.has(id):
			pool.append(cards()[id])
	return pool


static func reward_choices(rng: RandomNumberGenerator, count := Balance.REWARD_CHOICES) -> Array[CardData]:
	var pool := reward_pool()
	var picks: Array[CardData] = []
	while picks.size() < count and not pool.is_empty():
		var c: CardData = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		if c.is_joke():
			c = c.with_topic(CardData.TOPICS[rng.randi_range(0, CardData.TOPICS.size() - 1)])
		picks.append(c)
	return picks


static func _topic_bag(rng: RandomNumberGenerator) -> Array:
	var bag := CardData.TOPICS.duplicate()
	if rng:
		for i in range(bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
	return bag


static func _load_dir(dir_path: String) -> Dictionary:
	var found := {}
	var files := DirAccess.get_files_at(dir_path)
	files.sort()
	for file in files:
		# Exported builds list "x.tres.remap"; load() resolves the real path.
		file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var res = load(dir_path + file)
		if res and res.get("id"):
			found[res.id] = res
	return found
