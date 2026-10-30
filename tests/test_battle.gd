extends GutTest
## Rules of a single set. Each test builds a battle, sets up the exact hand it
## needs, and checks the numbers.


func _audience(intents: Array[IntentData] = [], needed := 100) -> AudienceData:
	var a := AudienceData.new()
	a.title = "Test Crowd"
	a.laughs_needed = needed
	a.intents = intents
	return a


func _intent(kind: IntentData.Kind, amount: int) -> IntentData:
	var i := IntentData.new()
	i.kind = kind
	i.amount = amount
	return i


## A battle whose hand is exactly the given card ids, with a filler draw pile.
func _battle_with_hand(ids: Array, audience: AudienceData = null) -> Battle:
	var b := Battle.new(audience if audience else _audience(), CardLibrary.starter_deck(), 1)
	b.draw_pile.append_array(b.hand)
	b.hand.clear()
	for id in ids:
		b.hand.append(CardLibrary.card(id))
	return b


func test_battle_starts_with_full_hand_and_mic() -> void:
	var b := Battle.new(_audience(), CardLibrary.starter_deck(), 1)
	assert_eq(b.hand.size(), Balance.HAND_SIZE)
	assert_eq(b.draw_pile.size(), 10 - Balance.HAND_SIZE)
	assert_eq(b.mic, Balance.MIC_PER_TURN)
	assert_eq(b.crowd_energy, Balance.START_CROWD_ENERGY)
	assert_eq(b.turn, 1)
	assert_eq(b.result, Battle.Result.ONGOING)


func test_punchline_gives_six_laughs_and_costs_mic() -> void:
	var b := _battle_with_hand(["punchline"])
	assert_true(b.play_card(0))
	assert_eq(b.laughs, 6)
	assert_eq(b.mic, 2)
	assert_eq(b.discard_pile.size(), 1)


func test_cannot_play_without_mic() -> void:
	var b := _battle_with_hand(["punchline", "punchline", "punchline", "punchline"])
	for i in 3:
		assert_true(b.play_card(0))
	assert_false(b.can_play(0))
	assert_false(b.play_card(0))
	assert_eq(b.laughs, 18)


func test_setup_doubles_only_the_next_punchline() -> void:
	var b := _battle_with_hand(["setup", "punchline", "punchline"])
	b.play_card(0)
	b.play_card(0)
	assert_eq(b.laughs, 12)
	b.play_card(0)
	assert_eq(b.laughs, 18)


func test_segue_bonus_needs_an_earlier_card() -> void:
	var b := _battle_with_hand(["segue", "segue"])
	b.play_card(0)
	assert_eq(b.laughs, 4)
	b.play_card(0)
	assert_eq(b.laughs, 4 + 7)


func test_callback_counts_cards_played_this_set() -> void:
	var b := _battle_with_hand(["punchline", "callback"])
	b.play_card(0)
	b.play_card(0)
	assert_eq(b.laughs, 6 + 2)


func test_crowd_work_raises_energy_and_reveals_next_intent() -> void:
	var b := _battle_with_hand(["crowd_work"])
	b.play_card(0)
	assert_eq(b.crowd_energy, Balance.START_CROWD_ENERGY + 3)
	assert_true(b.next_intent_revealed)


func test_pause_for_effect_is_free() -> void:
	var b := _battle_with_hand(["pause_for_effect"])
	b.play_card(0)
	assert_eq(b.mic, Balance.MIC_PER_TURN)
	assert_eq(b.crowd_energy, Balance.START_CROWD_ENERGY + 2)


func test_hot_crowd_multiplies_laughs() -> void:
	var b := _battle_with_hand(["punchline"])
	b.crowd_energy = Balance.HOT_ENERGY
	b.play_card(0)
	assert_eq(b.laughs, int(6 * Balance.HOT_MULTIPLIER))


func test_cold_crowd_reduces_laughs() -> void:
	var b := _battle_with_hand(["punchline"])
	b.crowd_energy = Balance.COLD_ENERGY
	b.play_card(0)
	assert_eq(b.laughs, int(floor(6 * Balance.COLD_MULTIPLIER)))


func test_end_turn_discards_hand_drifts_and_redraws() -> void:
	var b := _battle_with_hand(["punchline", "punchline"])
	b.play_card(0)
	b.end_turn()
	assert_eq(b.turn, 2)
	assert_eq(b.mic, Balance.MIC_PER_TURN)
	assert_eq(b.hand.size(), Balance.HAND_SIZE)
	assert_eq(b.crowd_energy, Balance.START_CROWD_ENERGY - Balance.ENERGY_DRIFT)


func test_bombing_costs_extra_energy() -> void:
	var b := _battle_with_hand(["setup"])
	b.end_turn()
	assert_eq(b.crowd_energy,
		Balance.START_CROWD_ENERGY - Balance.ENERGY_DRIFT - Balance.BOMB_PENALTY)


func test_drain_intent_lowers_energy() -> void:
	var b := _battle_with_hand(["punchline"], _audience([_intent(IntentData.Kind.DRAIN, 4)]))
	b.play_card(0)
	b.end_turn()
	assert_eq(b.crowd_energy, Balance.START_CROWD_ENERGY - Balance.ENERGY_DRIFT - 4)


func test_restless_intent_cuts_next_turns_mic() -> void:
	var b := _battle_with_hand(["punchline"], _audience([_intent(IntentData.Kind.RESTLESS, 1)]))
	b.play_card(0)
	b.end_turn()
	assert_eq(b.mic, Balance.MIC_PER_TURN - 1)
	b.end_turn()
	assert_eq(b.mic, Balance.MIC_PER_TURN - 1, "restless repeats because it's the only intent")


func test_tough_crowd_raises_laughs_needed() -> void:
	var b := _battle_with_hand(["punchline"], _audience([_intent(IntentData.Kind.TOUGH_CROWD, 5)], 40))
	b.play_card(0)
	b.end_turn()
	assert_eq(b.laughs_needed, 45)


func test_intents_cycle_in_order() -> void:
	var drain := _intent(IntentData.Kind.DRAIN, 1)
	var calm := _intent(IntentData.Kind.CALM, 0)
	var b := _battle_with_hand(["punchline"], _audience([drain, calm]))
	assert_eq(b.current_intent(), drain)
	assert_eq(b.next_intent(), calm)
	b.end_turn()
	assert_eq(b.current_intent(), calm)
	b.end_turn()
	assert_eq(b.current_intent(), drain)


func test_filling_the_laugh_meter_wins() -> void:
	var b := _battle_with_hand(["punchline"], _audience([], 6))
	b.play_card(0)
	assert_eq(b.result, Battle.Result.WON)
	assert_false(b.can_play(0))


func test_zero_energy_loses_the_room() -> void:
	var b := _battle_with_hand(["setup"], _audience([_intent(IntentData.Kind.DRAIN, 20)]))
	b.end_turn()
	assert_eq(b.crowd_energy, 0)
	assert_eq(b.result, Battle.Result.LOST)


func test_spit_take_can_lose_the_room() -> void:
	var b := _battle_with_hand(["spit_take"])
	b.crowd_energy = 2
	b.play_card(0)
	assert_eq(b.result, Battle.Result.LOST)


func test_draw_pile_reshuffles_discard_when_empty() -> void:
	var b := Battle.new(_audience(), CardLibrary.starter_deck(), 1)
	b.end_turn()
	b.end_turn()
	assert_eq(b.hand.size(), Balance.HAND_SIZE)
	assert_eq(b.hand.size() + b.draw_pile.size() + b.discard_pile.size(), 10)


func test_draw_cards_and_second_wind() -> void:
	var b := _battle_with_hand(["set_list", "second_wind"])
	var pile_before := b.draw_pile.size()
	b.play_card(0)
	assert_eq(b.hand.size(), 3)
	assert_eq(b.draw_pile.size(), pile_before - 2)
	b.play_card(b.hand.find(CardLibrary.card("second_wind")))
	assert_eq(b.mic, Balance.MIC_PER_TURN + 1)


func test_same_seed_same_shuffle() -> void:
	var a := Battle.new(_audience(), CardLibrary.starter_deck(), 42)
	var b := Battle.new(_audience(), CardLibrary.starter_deck(), 42)
	assert_eq(a.hand, b.hand)
	assert_eq(a.draw_pile, b.draw_pile)


# ---- links: a bonus for playing a card right after the right kind of card

func test_tag_after_a_punchline_is_linked() -> void:
	var b := _battle_with_hand(["punchline", "tag"])
	b.play_card(0)
	assert_true(b.is_linked(b.hand[0]))
	b.play_card(0)
	assert_eq(b.laughs, 6 + 2 + 5)
	assert_true(b.last_play_linked)


func test_tag_without_a_punchline_before_it_is_not_linked() -> void:
	var b := _battle_with_hand(["segue", "tag"])
	b.play_card(0)
	assert_false(b.is_linked(b.hand[0]))
	b.play_card(0)
	assert_false(b.last_play_linked)


func test_link_only_counts_the_card_just_before() -> void:
	var b := _battle_with_hand(["punchline", "segue", "tag"])
	b.play_card(0)
	b.play_card(0)
	assert_false(b.is_linked(b.hand[0]))


func test_link_resets_each_turn() -> void:
	var b := _battle_with_hand(["punchline", "tag"])
	b.play_card(0)
	b.end_turn()
	assert_null(b.last_card)


func test_energy_link_gives_energy_and_draw_link_draws() -> void:
	var b := _battle_with_hand(["punchline", "crowd_work"])
	b.play_card(0)
	var before := b.crowd_energy
	b.play_card(0)
	assert_eq(b.crowd_energy, before + 3 + 2)
	var c := _battle_with_hand(["setup", "riff"])
	c.play_card(0)
	c.play_card(0)
	assert_eq(c.hand.size(), 2, "riff drew 1 plus 1 from the link")


func test_spit_take_after_crowd_work_costs_no_energy() -> void:
	var b := _battle_with_hand(["crowd_work", "spit_take"])
	b.play_card(0)
	var before := b.crowd_energy
	b.play_card(0)
	assert_eq(b.crowd_energy, before)
