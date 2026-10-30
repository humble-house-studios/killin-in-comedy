class_name Autopilot
## Plays a set with simple greedy rules. Used by tests to check that sets
## finish and by the demo screen until the real battle UI exists.


static func play_set(battle: Battle, max_turns := 40) -> Battle.Result:
	while battle.result == Battle.Result.ONGOING and battle.turn <= max_turns:
		play_turn(battle)
	return battle.result


static func play_turn(battle: Battle) -> void:
	while battle.result == Battle.Result.ONGOING:
		var best := -1
		var best_score := -INF
		for i in battle.hand.size():
			if not battle.can_play(i):
				continue
			var score := _score(battle, battle.hand[i])
			if score > best_score:
				best_score = score
				best = i
		if best < 0 or best_score < 0:
			break
		battle.play_card(best)
	battle.end_turn()


static func _score(battle: Battle, card: CardData) -> float:
	var gained := battle.laughs_for(card)
	var heat := card.crowd_energy + battle.taste(card) * Balance.LOVED_HEAT
	if battle.is_linked(card):
		heat += card.link_energy
	var mult := battle.bit_multiplier() + heat * Balance.HEAT_MULT_PER_POINT \
		+ (Balance.CHAIN_MULT if battle.chains(card) else 0.0)
	var projected := int(floor((battle.bit_laughs + gained) * mult))
	if battle.laughs + projected >= battle.laughs_needed:
		return 1000.0
	if battle.crowd_energy + heat <= 0:
		return -1.0
	var energy_weight := 3.0 if battle.crowd_energy <= 6 else 0.5
	var score := float(projected - battle.bit_score()) + heat * energy_weight \
		+ card.draw * 3.0 + card.mic_gain * 4.0
	if battle.is_linked(card):
		score += card.link_draw * 3.0
	if card.setups > 0 and _hand_has_punchline(battle):
		score += 8.0
	# Cheap cards first when scores tie, so mic time isn't wasted.
	return score - card.cost * 0.1


## Picks the reward with the most raw value; good enough for balance checks.
static func pick_reward(choices: Array[CardData]) -> CardData:
	var best: CardData = null
	var best_value := -INF
	for c in choices:
		var value := float(c.laughs + c.combo_bonus + c.crowd_energy * 2 + c.draw * 3 \
			+ c.mic_gain * 4 + c.setups * 5 + c.laughs_per_card_this_set * 6 \
			+ c.laughs_per_card_this_turn * 3 \
			+ c.link_laughs * 0.5 + c.link_energy + c.link_draw * 1.5) / maxf(1.0, c.cost)
		if value > best_value:
			best_value = value
			best = c
	return best


static func _hand_has_punchline(battle: Battle) -> bool:
	for c in battle.hand:
		if c.is_punchline:
			return true
	return false
