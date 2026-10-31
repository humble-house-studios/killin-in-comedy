extends GutTest
## Rules of a live set. Each test builds a battle with no random wobble, sets
## up the exact hand it needs, and checks the numbers.

const S := Balance.LAUGH_SCALE


func _audience(intents: Array[IntentData] = [], needed := 1000000, seconds := 999.0) -> AudienceData:
	var a := AudienceData.new()
	a.title = "Test Crowd"
	a.laughs_needed = needed
	a.intents = intents
	a.seconds = seconds
	a.event_every = 5.0
	return a


func _intent(kind: IntentData.Kind, amount: int) -> IntentData:
	var i := IntentData.new()
	i.kind = kind
	i.amount = amount
	return i


## A battle whose hand is exactly the given card ids, with full mic.
func _battle_with_hand(ids: Array, audience: AudienceData = null, crew: Array = []) -> Battle:
	var b := Battle.new(audience if audience else _audience(), CardLibrary.starter_deck(), 1, crew)
	b.wobble_scale = 0.0
	b.draw_pile.append_array(b.hand)
	b.hand.clear()
	b.hand_size = 0  # no auto-refill, so the hand stays exactly as given
	for id in ids:
		b.hand.append(CardLibrary.card(id))
	b.mic = Balance.MIC_MAX
	return b


func test_battle_starts_with_full_hand_and_mic() -> void:
	var b := Battle.new(_audience(), CardLibrary.starter_deck(), 1)
	assert_eq(b.hand.size(), Balance.HAND_SIZE)
	assert_eq(b.mic, Balance.MIC_START)
	assert_eq(b.crowd_energy, float(Balance.START_CROWD_ENERGY))
	assert_eq(b.result, Battle.Result.ONGOING)


func test_playing_a_card_draws_the_next_one() -> void:
	var b := Battle.new(_audience(), CardLibrary.starter_deck(), 1)
	b.mic = Balance.MIC_MAX
	var second := b.hand[1]
	b.play_card(0)
	assert_eq(b.hand.size(), Balance.HAND_SIZE)
	assert_eq(b.hand[1], second, "the other cards keep their places")


func test_mic_recharges_over_time() -> void:
	var b := _battle_with_hand(["punchline"])
	b.mic = 0.0
	assert_false(b.can_play(0))
	b.tick(1.0 / Balance.MIC_PER_SECOND + 0.01)
	assert_true(b.can_play(0))
	b.tick(100.0)


func test_punchline_adds_scaled_laughs_to_the_bit() -> void:
	var b := _battle_with_hand(["punchline"])
	assert_true(b.play_card(0))
	assert_eq(b.bit_laughs, 6 * S)
	assert_eq(b.laughs, 0, "laughs only score when the bit lands")


func test_landing_scores_pot_times_heat() -> void:
	var b := _battle_with_hand(["punchline"])
	b.crowd_energy = 10.0
	b.play_card(0)
	assert_almost_eq(b.bit_multiplier(), 2.0, 0.001)
	assert_eq(b.land_bit(), 12 * S)
	assert_eq(b.laughs, 12 * S)
	assert_false(b.bit_open())


func test_landing_nothing_scores_nothing() -> void:
	var b := _battle_with_hand([])
	assert_eq(b.land_bit(), 0)


func test_setup_doubles_the_next_punchline() -> void:
	var b := _battle_with_hand(["setup", "punchline", "punchline"])
	b.play_card(0)
	b.play_card(0)
	assert_eq(b.bit_laughs, 12 * S)
	b.play_card(0)
	assert_eq(b.bit_laughs, 18 * S)


func test_chains_multiply_and_tags_refire_the_punchline() -> void:
	var b := _battle_with_hand(["setup", "punchline", "tag"])
	b.crowd_energy = 10.0
	b.play_card(0)
	assert_true(b.chains(b.hand[0]))
	b.play_card(0)
	assert_true(b.last_play_chained)
	b.play_card(0)
	assert_eq(b.chain_links, 2)
	# Punchline 120 (doubled), tag 20 + 50 link, plus the punchline again: 120.
	assert_eq(b.bit_laughs, 12 * S + 7 * S + 12 * S)
	assert_almost_eq(b.bit_multiplier(), 2.0 * Balance.CHAIN_X * Balance.CHAIN_X, 0.001)
	var retriggers := b.bit_jokes.filter(func(j): return j.retrigger)
	assert_eq(retriggers.size(), 1)


func test_wrong_order_does_not_chain() -> void:
	var b := _battle_with_hand(["punchline", "setup", "tag"])
	b.play_card(0)
	b.play_card(0)
	assert_false(b.chains(b.hand[0]))
	b.play_card(0)
	assert_eq(b.chain_links, 0)


func test_other_cards_do_not_break_a_chain() -> void:
	var b := _battle_with_hand(["setup", "pause_for_effect", "punchline"])
	b.play_card(0)
	b.play_card(0)
	assert_true(b.chains(b.hand[0]))


func test_rule_of_three_fires_three_times() -> void:
	var b := _battle_with_hand(["rule_of_three"])
	b.play_card(0)
	assert_eq(b.bit_jokes.size(), 3)
	assert_eq(b.bit_laughs, 3 * 3 * S)


func test_topper_bonus_needs_an_earlier_card() -> void:
	var b := _battle_with_hand(["yes_and", "yes_and"])
	b.play_card(0)
	assert_eq(b.bit_laughs, 4 * S)
	b.play_card(0)
	assert_eq(b.bit_laughs, 4 * S + 7 * S, "chains as a tag after a tag, but no punchline to re-fire")
	assert_eq(b.chain_links, 1)


func test_loved_and_hated_topics() -> void:
	var a := _audience()
	a.loves = ["dating"] as Array[String]
	a.hates = ["work"] as Array[String]
	var b := _battle_with_hand([], a)
	b.hand.append(CardLibrary.card("punchline").with_topic("dating"))
	b.hand.append(CardLibrary.card("punchline").with_topic("work"))
	b.hand.append(CardLibrary.card("punchline").with_topic("food"))
	assert_eq(b.laughs_for(b.hand[0]), 9 * S)
	assert_eq(b.laughs_for(b.hand[1]), 3 * S)
	assert_eq(b.laughs_for(b.hand[2]), 6 * S)
	var heat := b.crowd_energy
	b.play_card(0)
	assert_eq(b.crowd_energy, heat + Balance.LOVED_HEAT)


func test_only_joke_cards_get_topics() -> void:
	assert_eq(CardLibrary.card("crowd_work").with_topic("food").topic, "")
	assert_eq(CardLibrary.card("setup").with_topic("food").topic, "food")


func test_heat_cools_off_over_time() -> void:
	var b := _battle_with_hand([])
	b.tick(1.0)
	assert_almost_eq(b.crowd_energy, Balance.START_CROWD_ENERGY - Balance.HEAT_DRIFT, 0.001)


func test_dead_air_drains_faster() -> void:
	var b := _battle_with_hand([])
	b.tick(Balance.DEAD_AIR_AFTER)
	var before := b.crowd_energy
	b.tick(1.0)
	assert_almost_eq(before - b.crowd_energy, Balance.HEAT_DRIFT + Balance.DEAD_AIR_DRAIN, 0.01)


func test_crowd_moves_fire_on_their_clock() -> void:
	var b := _battle_with_hand([], _audience([_intent(IntentData.Kind.SPIKE, 5)]))
	b.tick(4.9)
	var before := b.crowd_energy
	b.tick(0.2)
	assert_almost_eq(b.crowd_energy, before + 5 - Balance.HEAT_DRIFT * 0.2, 0.01)
	assert_has(b.pop_events(), "event")


func test_heckle_interrupts_an_open_bit() -> void:
	var b := _battle_with_hand(["setup", "punchline"], _audience([_intent(IntentData.Kind.DRAIN, 2)]))
	b.play_card(0)
	b.play_card(0)
	var pot := b.bit_laughs
	b.tick(5.1)
	assert_eq(b.bit_laughs, int(pot * Balance.INTERRUPT_KEEP))
	assert_eq(b.chain_links, 0)
	assert_has(b.pop_events(), "interrupt")


func test_lawyer_softens_heckles() -> void:
	var b := _battle_with_hand(["punchline"], _audience([_intent(IntentData.Kind.DRAIN, 2)]), ["lawyer"])
	b.play_card(0)
	b.tick(5.1)
	assert_eq(b.bit_laughs, int(6 * S * 0.75))


func test_restless_drains_mic_and_tough_crowd_raises_target() -> void:
	var b := _battle_with_hand([], _audience([_intent(IntentData.Kind.RESTLESS, 2), _intent(IntentData.Kind.TOUGH_CROWD, 10)], 1000))
	b.mic = 0.0
	b.tick(5.0)
	assert_almost_eq(b.mic, 5.0 * Balance.MIC_PER_SECOND - 2.0, 0.01)
	b.tick(5.0)
	assert_eq(b.laughs_needed, 1100)


func test_filling_the_target_wins_when_the_bit_lands() -> void:
	var b := _battle_with_hand(["punchline"], _audience([], 50))
	b.play_card(0)
	assert_eq(b.result, Battle.Result.ONGOING)
	b.land_bit()
	assert_eq(b.result, Battle.Result.WON)
	assert_false(b.can_play(0))


func test_the_light_ends_the_set() -> void:
	var b := _battle_with_hand([], _audience([], 1000000, 10.0))
	b.crowd_energy = 20.0
	b.tick(10.1)
	assert_eq(b.result, Battle.Result.LOST)
	assert_eq(b.loss, Battle.Loss.LIGHT)


func test_last_bit_lands_as_the_light_goes_on() -> void:
	var b := _battle_with_hand(["punchline"], _audience([], 50, 2.0))
	b.play_card(0)
	b.tick(2.1)
	assert_eq(b.result, Battle.Result.WON)


func test_zero_heat_loses_the_room() -> void:
	var b := _battle_with_hand([], _audience([_intent(IntentData.Kind.DRAIN, 20)]))
	b.tick(5.1)
	assert_eq(b.result, Battle.Result.LOST)
	assert_eq(b.loss, Battle.Loss.ROOM)


func test_spit_take_can_lose_the_room() -> void:
	var b := _battle_with_hand(["spit_take"])
	b.crowd_energy = 2.0
	b.play_card(0)
	assert_eq(b.result, Battle.Result.LOST)


func test_crew_perks_and_cut() -> void:
	var b := Battle.new(_audience([], 1000000, 60.0), CardLibrary.starter_deck(), 1, ["writer", "booker", "hype"])
	assert_eq(b.hand.size(), Balance.HAND_SIZE + 1)
	assert_eq(b.time_left, 75.0)
	assert_eq(b.crowd_energy, Balance.START_CROWD_ENERGY + 5.0)
	assert_almost_eq(b.keep_share(), 1.0 - 0.35, 0.001)


func test_room_chart_records_heat() -> void:
	var b := _battle_with_hand([])
	b.tick(1.0)
	assert_eq(b.heat_history.size(), 1 + int(1.0 / Balance.CHART_STEP))


func test_same_seed_same_shuffle() -> void:
	var a := Battle.new(_audience(), CardLibrary.starter_deck(), 42)
	var b := Battle.new(_audience(), CardLibrary.starter_deck(), 42)
	assert_eq(a.hand, b.hand)
	assert_eq(a.draw_pile, b.draw_pile)


func test_tag_after_a_punchline_is_linked() -> void:
	var b := _battle_with_hand(["punchline", "tag"])
	b.play_card(0)
	assert_true(b.is_linked(b.hand[0]))
	b.play_card(0)
	assert_true(b.last_play_linked)


func test_link_resets_when_the_bit_lands() -> void:
	var b := _battle_with_hand(["punchline", "tag"])
	b.play_card(0)
	b.land_bit()
	assert_null(b.last_card)
	assert_false(b.is_linked(b.hand[0]))


func test_energy_link_gives_heat_and_draw_link_draws() -> void:
	var b := _battle_with_hand(["punchline", "crowd_work"])
	b.play_card(0)
	var before := b.crowd_energy
	b.play_card(0)
	assert_eq(b.crowd_energy, before + 3 + 2)
	var c := _battle_with_hand(["setup", "riff"])
	c.play_card(0)
	c.play_card(0)
	assert_eq(c.hand.size(), 2, "riff drew 1 plus 1 from the link")
