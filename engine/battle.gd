class_name Battle
extends RefCounted
## One set (the battle). Pure logic with no nodes: the UI calls play_card()
## and land_bit() and reads the state; tests drive it exactly the same way.
##
## Each turn is one minute of the set. Cards build a bit (bit_laughs); landing
## it scores bit_laughs × the bit multiplier (Heat + chain links). Hit
## laughs_needed before the minutes run out ("the light") to win.

enum Result { ONGOING, WON, LOST }
enum Loss { NONE, LIGHT, ROOM }

var audience: AudienceData
var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []

var mic := 0
## Heat: the crowd's mood. It's the bit multiplier; at 0 you lose the room.
var crowd_energy := Balance.START_CROWD_ENERGY
## Laughs scored so far this set (landed bits only).
var laughs := 0
var laughs_needed := 0
## Length of the set. Turn N is minute N.
var minutes := 0
var turn := 0
var result := Result.ONGOING
var loss := Loss.NONE

## The bit being built this minute: raw laughs and chain links so far.
var bit_laughs := 0
var chain_links := 0
## Score of the last landed bit, for the UI.
var last_landed := 0
var last_landed_mult := 1.0

var cards_played_this_turn := 0
var cards_played_this_set := 0
var setups_pending := 0
## The card played just before, this turn. Cards with a link bonus read it.
var last_card: CardData
## The beat of the last joke card this minute (NONE if none yet).
var last_beat := CardData.Beat.NONE
## True if the card just played earned its link bonus (the UI celebrates it).
var last_play_linked := false
## True if the card just played made a chain link.
var last_play_chained := false
## True once Crowd Work (or similar) shows the intent after the current one.
var next_intent_revealed := false
## Plain-text record of the set, newest last. The UI turns these into bubbles.
var history: Array[String] = []

var _intent_index := 0
var _mic_penalty := 0
var _rng := RandomNumberGenerator.new()


func _init(p_audience: AudienceData, deck: Array[CardData], rng_seed := 0) -> void:
	audience = p_audience
	laughs_needed = audience.laughs_needed
	minutes = audience.minutes
	_rng.seed = rng_seed
	draw_pile.append_array(deck)
	_shuffle(draw_pile)
	_start_turn()


func current_intent() -> IntentData:
	return _intent_at(_intent_index)


func next_intent() -> IntentData:
	return _intent_at(_intent_index + 1)


## Minutes left including this one. 1 = the last minute before the light.
func minutes_left() -> int:
	return maxi(0, minutes - turn + 1)


## The multiplier Heat alone gives: Heat 10 = ×2.
func heat_multiplier() -> float:
	return 1.0 + crowd_energy * Balance.HEAT_MULT_PER_POINT


## What the bit being built is multiplied by when it lands.
func bit_multiplier() -> float:
	return heat_multiplier() + chain_links * Balance.CHAIN_MULT


## Laughs the bit would score if landed now.
func bit_score() -> int:
	return int(floor(bit_laughs * bit_multiplier()))


## 1 if the audience loves the card's topic, -1 if it hates it, else 0.
func taste(card: CardData) -> int:
	if card.topic == "":
		return 0
	if audience.loves.has(card.topic):
		return 1
	if audience.hates.has(card.topic):
		return -1
	return 0


## True if playing the card now would earn its own link bonus.
func is_linked(card: CardData) -> bool:
	return card.link_from != "" and last_card != null and last_card.is_kind(card.link_from)


## True if playing the card now makes a chain link: Setup → Punchline → Tag → Tag.
func chains(card: CardData) -> bool:
	return CardData.follows(last_beat, card.beat)


## Raw laughs the card adds to the bit if played right now (before the multiplier).
func laughs_for(card: CardData) -> int:
	var base := float(card.laughs)
	if is_linked(card):
		base += card.link_laughs
	if card.combo_bonus != 0 and cards_played_this_turn >= card.combo_after:
		base += card.combo_bonus
	base += card.laughs_per_card_this_set * cards_played_this_set
	base += card.laughs_per_card_this_turn * cards_played_this_turn
	if card.is_punchline and setups_pending > 0:
		base *= Balance.SETUP_MULTIPLIER
	match taste(card):
		1:
			base *= Balance.LOVED_MULT
		-1:
			base *= Balance.HATED_MULT
	return int(floor(base))


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
	var chained := chains(card)
	if card.is_punchline and setups_pending > 0:
		setups_pending -= 1
	bit_laughs += gained
	if chained:
		chain_links += 1
	if card.beat != CardData.Beat.NONE:
		last_beat = card.beat
	setups_pending += card.setups
	var heat := card.crowd_energy + (card.link_energy if linked else 0)
	match taste(card):
		1:
			heat += Balance.LOVED_HEAT
		-1:
			heat += Balance.HATED_HEAT
	_change_energy(heat)
	mic += card.mic_gain
	if card.reveals_intent:
		next_intent_revealed = true
	cards_played_this_turn += 1
	cards_played_this_set += 1
	discard_pile.append(card)
	history.append("%s: \"%s\" (+%d laughs)%s%s" % [card.title, card.line, gained,
		" LINK!" if linked else "", " CHAIN!" if chained else ""])
	last_card = card
	last_play_linked = linked
	last_play_chained = chained

	_draw(card.draw + (card.link_draw if linked else 0))
	if crowd_energy <= 0:
		_lose(Loss.ROOM)
	return true


## Lands the bit and ends the minute. (end_turn() is the same thing.)
func land_bit() -> void:
	if result != Result.ONGOING:
		return
	discard_pile.append_array(hand)
	hand.clear()
	last_landed_mult = bit_multiplier()
	last_landed = bit_score()
	laughs += last_landed
	if bit_laughs > 0:
		history.append("The bit lands: %d × %.1f = %d laughs" % [bit_laughs, last_landed_mult, last_landed])
	if laughs >= laughs_needed:
		result = Result.WON
		history.append("The room is roaring. You killed!")
		return
	if bit_laughs <= 0:
		_change_energy(-Balance.BOMB_PENALTY)
		history.append("You bombed. (-%d Heat)" % Balance.BOMB_PENALTY)
	_change_energy(-Balance.ENERGY_DRIFT)
	history.append("The crowd cools off. (-%d Heat)" % Balance.ENERGY_DRIFT)
	_apply_intent(current_intent())
	if crowd_energy <= 0:
		_lose(Loss.ROOM)
		return
	if turn >= minutes:
		_lose(Loss.LIGHT)
		return
	_intent_index += 1
	_start_turn()


func end_turn() -> void:
	land_bit()


func _lose(why: Loss) -> void:
	result = Result.LOST
	loss = why
	history.append("You lost the room." if why == Loss.ROOM else "You got the light. Time's up.")


func _start_turn() -> void:
	turn += 1
	mic = maxi(0, Balance.MIC_PER_TURN - _mic_penalty)
	_mic_penalty = 0
	cards_played_this_turn = 0
	last_card = null
	last_beat = CardData.Beat.NONE
	last_play_linked = false
	last_play_chained = false
	bit_laughs = 0
	chain_links = 0
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
