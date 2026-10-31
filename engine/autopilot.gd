class_name Autopilot
## Plays a live set with simple rules, at human-ish speed. Used by tests and
## tools/tune.gd to check that sets are winnable but not free.

## Seconds between the bot's taps (a quick but human player).
const REACTION := 0.6
const STEP := 0.1


static func play_set(battle: Battle) -> Battle.Result:
	var wait := 0.0
	while battle.result == Battle.Result.ONGOING:
		battle.tick(STEP)
		wait -= STEP
		if wait > 0.0 or battle.result != Battle.Result.ONGOING:
			continue
		if _should_land(battle):
			battle.land_bit()
			wait = REACTION
			continue
		var best := _best_card(battle)
		if best >= 0:
			battle.play_card(best)
			wait = REACTION
	return battle.result


static func _should_land(battle: Battle) -> bool:
	if not battle.bit_open() or battle.bit_laughs <= 0:
		return false
	if battle.laughs + battle.bit_score() >= battle.laughs_needed:
		return true
	if battle.time_left < 1.5:
		return true
	var intent := battle.current_intent()
	if intent and intent.kind == IntentData.Kind.DRAIN and battle.event_in() < 1.2:
		return true
	# Nothing in hand continues the chain and the bit has some meat: cash out.
	for i in battle.hand.size():
		if battle.chains(battle.hand[i]):
			return false
	return battle.cards_played_this_bit >= 3


static func _best_card(battle: Battle) -> int:
	var best := -1
	var best_score := 0.0
	for i in battle.hand.size():
		if not battle.can_play(i):
			continue
		var s := _score(battle, battle.hand[i])
		if s > best_score:
			best_score = s
			best = i
	return best


static func _score(battle: Battle, card: CardData) -> float:
	var heat := card.crowd_energy + battle.taste(card) * Balance.LOVED_HEAT
	if battle.is_linked(card):
		heat += card.link_energy
	if battle.crowd_energy + heat <= 0:
		return -1.0
	var gained := battle.laughs_for(card)
	var mult := (1.0 + (battle.crowd_energy + heat) * Balance.HEAT_MULT_PER_POINT) \
		* battle.chain_multiplier() * (Balance.CHAIN_X if battle.chains(card) else 1.0)
	var value := (battle.bit_laughs + gained) * mult - battle.bit_laughs * battle.bit_multiplier()
	# Weights below were tuned with laughs ×10; k keeps them in step with LAUGH_SCALE.
	var k := Balance.LAUGH_SCALE / 10.0
	var energy_weight := (60.0 if battle.crowd_energy <= 6 else 15.0) * k
	value += heat * energy_weight + (card.draw * 30.0 + card.mic_gain * 40.0) * k
	if card.setups > 0 and _hand_has_punchline(battle):
		value += 150.0 * k
	return value / maxf(1.0, card.cost)


## Picks the reward with the most raw value; good enough for balance checks.
static func pick_reward(choices: Array[CardData]) -> CardData:
	var best: CardData = null
	var best_value := -INF
	for c in choices:
		var value := float(c.laughs * c.triggers + c.combo_bonus + c.crowd_energy * 2 + c.draw * 3 \
			+ c.mic_gain * 4 + c.setups * 5 + c.laughs_per_card_this_set * 6 \
			+ c.laughs_per_card_this_turn * 3 \
			+ c.link_laughs * 0.5 + c.link_energy + c.link_draw * 1.5) / maxf(1.0, c.cost)
		if value > best_value:
			best_value = value
			best = c
	return best


static func pick_crew(choices: Array) -> String:
	for id in ["writer", "hype", "lawyer", "manager", "booker"]:
		if choices.has(id):
			return id
	return ""


static func _hand_has_punchline(battle: Battle) -> bool:
	for c in battle.hand:
		if c.is_punchline:
			return true
	return false
