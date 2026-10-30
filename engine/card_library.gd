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


static func starter_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	for id in Balance.STARTER_DECK:
		for i in Balance.STARTER_DECK[id]:
			deck.append(card(id))
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
		picks.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picks


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
