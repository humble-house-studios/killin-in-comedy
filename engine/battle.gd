class_name Battle
extends RefCounted
## One set (the battle). Pure logic with no nodes: the UI calls play_card()
## and end_turn() and reads the state; tests drive it exactly the same way.

enum Result { ONGOING, WON, LOST }

var audience: AudienceData
var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []

var mic := 0
var crowd_energy := Balance.START_CROWD_ENERGY
var laughs := 0
var laughs_needed := 0
var turn := 0
var result := Result.ONGOING

var cards_played_this_turn := 0
var cards_played_this_set := 0
var setups_pending := 0
## The card played just before, this turn. Cards with a link bonus read it.
var last_card: CardData
## True if the card just played earned its link bonus (the UI celebrates it).
var last_play_linked := false
## True once Crowd Work (or similar) shows the intent after the current one.
var next_intent_revealed := false
## Plain-text record of the set, newest last. The UI turns these into bubbles.
var history: Array[String] = []

var _intent_index := 0
var _laughs_this_turn := 0
var _mic_penalty := 0
var _rng := RandomNumberGenerator.new()


func _init(p_audience: AudienceData, deck: Array[CardData], rng_seed := 0) -> void:
	audience = p_audience
	laughs_needed = audience.laughs_needed
	_rng.seed = rng_seed
	draw_pile.append_array(deck)
	_shuffle(draw_pile)
	_start_turn()


func current_intent() -> IntentData:
	return _intent_at(_intent_index)


func next_intent() -> IntentData:
	return _intent_at(_intent_index + 1)


func laugh_multiplier() -> float:
	if crowd_energy >= Balance.HOT_ENERGY:
		return Balance.HOT_MULTIPLIER
	if crowd_energy <= Balance.COLD_ENERGY:
		return Balance.COLD_MULTIPLIER
	return 1.0


## True if playing the card now would earn its link bonus.
func is_linked(card: CardData) -> bool:
	return card.link_from != "" and last_card != null and last_card.is_kind(card.link_from)


## Laughs the card would earn if played right now.
func laughs_for(card: CardData) -> int:
	var base := card.laughs
	if is_linked(card):
		base += card.link_laughs
	if card.combo_bonus != 0 and cards_played_this_turn >= card.combo_after:
		base += card.combo_bonus
	base += card.laughs_per_card_this_set * cards_played_this_set
	base += card.laughs_per_card_this_turn * cards_played_this_turn
	if card.is_punchline and setups_pending > 0:
		base *= Balance.SETUP_MULTIPLIER
	return int(floor(base * laugh_multiplier()))


func can_play(hand_index: int) -> bool:
	return result == Result.ONGOING \
		and hand_index >= 0 and hand_index < hand.size() \
		and hand[hand_index].cost <= mic


func play_card(hand_index: int) -> bool:
	if not can_play(hand_index):
		return false
	var card := hand[hand_index]
	hand.remove_at(hand_index)
	mic -= card.cost

	var gained := laughs_for(card)
	var linked := is_linked(card)
	if card.is_punchline and setups_pending > 0:
		setups_pending -= 1
	laughs += gained
	_laughs_this_turn += gained
	setups_pending += card.setups
	_change_energy(card.crowd_energy + (card.link_energy if linked else 0))
	mic += card.mic_gain
	if card.reveals_intent:
		next_intent_revealed = true
	cards_played_this_turn += 1
	cards_played_this_set += 1
	discard_pile.append(card)
	history.append("%s: \"%s\" (+%d laughs)%s" % [card.title, card.line, gained, " LINK!" if linked else ""])
	last_card = card
	last_play_linked = linked

	_draw(card.draw + (card.link_draw if linked else 0))
	_check_end()
	return true


func end_turn() -> void:
	if result != Result.ONGOING:
		return
	discard_pile.append_array(hand)
	hand.clear()
	if _laughs_this_turn <= 0:
		_change_energy(-Balance.BOMB_PENALTY)
		history.append("You bombed. (-%d Crowd Energy)" % Balance.BOMB_PENALTY)
	_change_energy(-Balance.ENERGY_DRIFT)
	history.append("The crowd cools off. (-%d Crowd Energy)" % Balance.ENERGY_DRIFT)
	_apply_intent(current_intent())
	_check_end()
	if result != Result.ONGOING:
		return
	_intent_index += 1
	_start_turn()


func _start_turn() -> void:
	turn += 1
	mic = maxi(0, Balance.MIC_PER_TURN - _mic_penalty)
	_mic_penalty = 0
	cards_played_this_turn = 0
	last_card = null
	last_play_linked = false
	_laughs_this_turn = 0
	next_intent_revealed = false
	_draw(Balance.HAND_SIZE)


func _draw(count: int) -> void:
	for i in count:
		if hand.size() >= Balance.MAX_HAND:
			return
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				return
			draw_pile.append_array(discard_pile)
			discard_pile.clear()
			_shuffle(draw_pile)
		hand.append(draw_pile.pop_back())


func _apply_intent(intent: IntentData) -> void:
	if intent == null:
		return
	match intent.kind:
		IntentData.Kind.DRAIN:
			_change_energy(-intent.amount)
		IntentData.Kind.RESTLESS:
			_mic_penalty += intent.amount
		IntentData.Kind.TOUGH_CROWD:
			laughs_needed += intent.amount
	history.append("%s: %s" % [audience.title, intent.text])


func _change_energy(amount: int) -> void:
	crowd_energy = clampi(crowd_energy + amount, 0, Balance.MAX_CROWD_ENERGY)


func _check_end() -> void:
	if laughs >= laughs_needed:
		result = Result.WON
		history.append("The room is roaring. You killed!")
	elif crowd_energy <= 0:
		result = Result.LOST
		history.append("You lost the room.")


func _intent_at(index: int) -> IntentData:
	if audience.intents.is_empty():
		return null
	return audience.intents[index % audience.intents.size()]


func _shuffle(cards: Array[CardData]) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
