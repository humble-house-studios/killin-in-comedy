extends GutTest
## The data in res://data/ loads, is consistent, and sets can be finished.


func test_starter_deck_matches_the_plan() -> void:
	var deck := CardLibrary.starter_deck()
	assert_eq(deck.size(), 10)
	var counts := {}
	for c in deck:
		assert_not_null(c)
		counts[c.id] = counts.get(c.id, 0) + 1
	assert_eq(counts, {"punchline": 4, "yes_and": 3, "setup": 2, "crowd_work": 1})


func test_every_card_is_complete() -> void:
	for id in CardLibrary.cards():
		var c: CardData = CardLibrary.cards()[id]
		assert_ne(c.title, "", id)
		assert_ne(c.rules, "", id)
		assert_between(c.cost, 0, 3, id)


func test_reward_pool_has_at_least_15_cards_and_no_starters() -> void:
	var pool := CardLibrary.reward_pool()
	assert_gte(pool.size(), 15)
	for c in pool:
		assert_false(Balance.STARTER_DECK.has(c.id), c.id)


func test_reward_choices_are_three_different_cards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var picks := CardLibrary.reward_choices(rng)
	assert_eq(picks.size(), 3)
	assert_ne(picks[0], picks[1])
	assert_ne(picks[1], picks[2])
	assert_ne(picks[0], picks[2])


func test_three_audiences_and_one_boss() -> void:
	var regular := 0
	var bosses := 0
	for id in CardLibrary.audiences():
		var a: AudienceData = CardLibrary.audiences()[id]
		assert_gt(a.intents.size(), 0, id)
		if a.is_boss:
			bosses += 1
		else:
			regular += 1
	assert_eq(regular, 3)
	assert_eq(bosses, 1)


func test_autopilot_finishes_every_audience() -> void:
	for id in CardLibrary.audiences():
		for s in 20:
			var b := Battle.new(CardLibrary.audience(id), CardLibrary.starter_deck(), s)
			assert_ne(Autopilot.play_set(b), Battle.Result.ONGOING, "%s seed %d" % [id, s])


func test_starter_deck_usually_beats_the_open_mic() -> void:
	var wins := 0
	for s in 50:
		var b := Battle.new(CardLibrary.audience("open_mic"), CardLibrary.starter_deck(), s)
		if Autopilot.play_set(b) == Battle.Result.WON:
			wins += 1
	assert_gte(wins, 35, "won %d of 50" % wins)
