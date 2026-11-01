class_name Battle
extends RefCounted
## One set, played live. Pure logic with no nodes: the UI calls tick(delta)
## every frame, play_card() and land_bit() on taps, and reads the state;
## tests drive it exactly the same way.
##
## The Room is a live line (Heat) that drifts, wobbles and jumps on crowd
## moves. Cards build a bit (a pot of laughs); landing it scores
## pot × Heat multiplier × chain multiplier. Land at a peak for a jackpot;
## hold too long and a heckle cuts the bit. Hit the target before the light.

enum Result { ONGOING, WON, LOST }
enum Loss { NONE, LIGHT, ROOM }

var audience: AudienceData
var crew: Array = []
var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var hand_size := Balance.HAND_SIZE

var mic := Balance.MIC_START
## Heat: the Room line. It's the bit multiplier; at 0 you lose the room.
var crowd_energy := float(Balance.START_CROWD_ENERGY)
## Recent Heat values for the Room chart, oldest first.
var heat_history: Array[float] = []
## Laughs scored so far this set (landed bits only).
var laughs := 0
var laughs_needed := 0
var set_length := 0.0
var time_left := 0.0
var elapsed := 0.0
var result := Result.ONGOING
var loss := Loss.NONE
## Set to 0 in tests for a Room line with no random wobble.
var wobble_scale := 1.0

## The bit being built: raw laughs, chain links, and every joke in it (for the
## landing cascade). Each joke: {card, laughs, retrigger}.
var bit_laughs := 0
var chain_links := 0
var bit_jokes: Array[Dictionary] = []
## The last landed bit, for the UI: its jokes, raw laughs, multiplier, score.
var landed_jokes: Array[Dictionary] = []
var landed_raw := 0
var landed_mult := 1.0
## The landed bit's multiplier, split up so the payout can name each part.
var landed_room := 1.0
var landed_chain := 1.0
var landed_links := 0
var landed_keep := 1.0
var last_landed := 0

var cards_played_this_bit := 0
var cards_played_this_set := 0
var setups_pending := 0
## The card played just before, this bit. Cards with a link bonus read it.
var last_card: CardData
## The beat of the last joke card this bit (NONE if none yet).
var last_beat := CardData.Beat.NONE
var last_play_linked := false
var last_play_chained := false
## True once Crowd Work (or the Manager) shows the move after the next one.
var next_intent_revealed := false
## Plain-text record of the set, newest last.
var history: Array[String] = []
## Things that just happened, for the UI to animate: "event", "interrupt",
## "landed", "won", "lost". Read with pop_events().
var _events: Array[String] = []

var _intent_index := 0
var _event_clock := 0.0
var _chart_clock := 0.0
var _since_land := 0.0
var _wobble := 0.0
var _wobble_clock := 0.0
var _last_punch_laughs := 0
var _keep := 1.0
var _rng := RandomNumberGenerator.new()


func _init(p_audience: AudienceData, deck: Array[CardData], rng_seed := 0, p_crew: Array = []) -> void:
	audience = p_audience
	crew = p_crew
	_keep = Crew.keep_share(crew)
	laughs_needed = audience.laughs_needed
	set_length = audience.seconds + (15.0 if crew.has("booker") else 0.0)
	time_left = set_length
	_event_clock = audience.event_every
	if crew.has("writer"):
		hand_size += 1
	if crew.has("hype"):
		crowd_energy += 5
	_rng.seed = rng_seed
	draw_pile.append_array(deck)
	_shuffle(draw_pile)
	_refill_hand()
	_reset_bit()
	heat_history.append(crowd_energy)


func current_intent() -> IntentData:
	return _intent_at(_intent_index)


func next_intent() -> IntentData:
	return _intent_at(_intent_index + 1)


## Seconds until the crowd's next move.
func event_in() -> float:
	return _event_clock


func sees_two_moves() -> bool:
	return next_intent_revealed or crew.has("manager")


## Share of each landed bit you keep after your crew's cut.
func keep_share() -> float:
	return _keep


func heat_multiplier() -> float:
	return 1.0 + crowd_energy * Balance.HEAT_MULT_PER_POINT


func chain_multiplier() -> float:
	return pow(Balance.CHAIN_X, chain_links)


## What the bit is multiplied by if landed now (before the crew's cut).
func bit_multiplier() -> float:
	return heat_multiplier() * chain_multiplier()


## Laughs the bit would score if landed now.
func bit_score() -> int:
	return int(floor(bit_laughs * bit_multiplier() * _keep))


func bit_open() -> bool:
	return not bit_jokes.is_empty()


## 1 if the audience loves the card's topic, -1 if it hates it, else 0.
func taste(card: CardData) -> int:
	if card.topic == "":
		return 0
	if audience.loves.has(card.topic):
		return 1
	if audience.hates.has(card.topic):
		return -1
	return 0


func is_linked(card: CardData) -> bool:
	return card.link_from != "" and last_card != null and last_card.is_kind(card.link_from)


## True if playing the card now makes a chain link: Setup → Punchline → Tag → Tag.
func chains(card: CardData) -> bool:
	return CardData.follows(last_beat, card.beat)


## Laughs one firing of the card adds to the bit right now.
func laughs_per_trigger(card: CardData) -> int:
	var base := float(card.laughs)
	if is_linked(card):
		base += card.link_laughs
	if card.combo_bonus != 0 and cards_played_this_bit >= card.combo_after:
		base += card.combo_bonus
	base += card.laughs_per_card_this_set * cards_played_this_set
	base += card.laughs_per_card_this_turn * cards_played_this_bit
	if card.is_punchline and setups_pending > 0:
		base *= Balance.SETUP_MULTIPLIER
	match taste(card):
		1:
			base *= Balance.LOVED_MULT
		-1:
			base *= Balance.HATED_MULT
	return int(floor(base * Balance.LAUGH_SCALE))


## Raw laughs the card adds to the bit if played now, retrigger included.
func laughs_for(card: CardData) -> int:
	var total := laughs_per_trigger(card) * maxi(1, card.triggers)
	if card.beat == CardData.Beat.TAG and chains(card):
		total += int(_last_punch_laughs * Balance.RETRIGGER_SHARE)
	return total


## Short reasons a card scores more (or less) than its printed laughs right
## now, e.g. ["SETUP ×2", "LOVED ×1.5"]. Shown in the landing payout.
func _reasons(card: CardData) -> Array:
	var why := []
	if card.is_punchline and setups_pending > 0:
		why.append("SETUP ×%d" % Balance.SETUP_MULTIPLIER)
	match taste(card):
		1:
			why.append("LOVED ×%s" % str(Balance.LOVED_MULT))
		-1:
			why.append("HATED ×%s" % str(Balance.HATED_MULT))
	if is_linked(card) and card.link_laughs > 0:
		why.append("LINK")
	if card.combo_bonus != 0 and cards_played_this_bit >= card.combo_after:
		why.append("COMBO")
	return why


func can_play(hand_index: int) -> bool:
	return result == Result.ONGOING \
		and hand_index >= 0 and hand_index < hand.size() \
		and hand[hand_index].cost <= mic + 0.0001


func play_card(hand_index: int) -> bool:
	if not can_play(hand_index):
		return false
	var card := hand[hand_index]
	hand.remove_at(hand_index)
	mic = maxf(0.0, mic - card.cost)

	var per := laughs_per_trigger(card)
	var linked := is_linked(card)
	var chained := chains(card)
	var why := _reasons(card)
	for i in maxi(1, card.triggers):
		if per > 0:
			bit_jokes.append({"card": card, "laughs": per, "retrigger": i > 0, "why": why})
			bit_laughs += per
	if card.beat == CardData.Beat.TAG and chained and _last_punch_laughs > 0:
		var again := int(_last_punch_laughs * Balance.RETRIGGER_SHARE)
		bit_jokes.append({"card": card, "laughs": again, "retrigger": true, "why": ["PUNCHLINE AGAIN"]})
		bit_laughs += again
	if card.is_punchline:
		_last_punch_laughs = per * maxi(1, card.triggers)
		if setups_pending > 0:
			setups_pending -= 1
	if per <= 0 and card.is_joke():
		# Setups score nothing alone, but they're still part of the bit.
		bit_jokes.append({"card": card, "laughs": 0, "retrigger": false, "why": why})
	if chained:
		chain_links += 1
	if card.is_joke():
		last_beat = card.beat
	setups_pending += card.setups
	var heat := card.crowd_energy + (card.link_energy if linked else 0)
	match taste(card):
		1:
			heat += Balance.LOVED_HEAT
		-1:
			heat += Balance.HATED_HEAT
	_change_energy(heat)
	mic = minf(Balance.MIC_MAX, mic + card.mic_gain)
	if card.reveals_intent:
		next_intent_revealed = true
	cards_played_this_bit += 1
	cards_played_this_set += 1
	discard_pile.append(card)
	history.append("%s (+%d)%s%s" % [card.title, per, " LINK!" if linked else "", " CHAIN!" if chained else ""])
	last_card = card
	last_play_linked = linked
	last_play_chained = chained

	_draw(card.draw + (card.link_draw if linked else 0))
	# The next card takes the played card's place, so the hand never shifts
	# under a thumb mid-set.
	if hand.size() < hand_size:
		var next := _take()
		if next:
			hand.insert(mini(hand_index, hand.size()), next)
	_refill_hand()
	if crowd_energy <= 0:
		_lose(Loss.ROOM)
	return true


## Scores the bit: raw laughs × Heat × chain, minus the crew's cut.
## Returns the score (0 if there was nothing to land).
func land_bit() -> int:
	if result != Result.ONGOING or not bit_open():
		return 0
	landed_jokes = bit_jokes.duplicate()
	landed_raw = bit_laughs
	landed_mult = bit_multiplier()
	landed_room = heat_multiplier()
	landed_chain = chain_multiplier()
	landed_links = chain_links
	landed_keep = _keep
	last_landed = bit_score()
	laughs += last_landed
	_change_energy(chain_links * Balance.LAND_HEAT_PER_LINK)
	history.append("The bit lands: %d × %.1f = %d" % [landed_raw, landed_mult, last_landed])
	_events.append("landed")
	_since_land = 0.0
	_reset_bit()
	if laughs >= laughs_needed:
		result = Result.WON
		history.append("The room is roaring. You killed!")
		_events.append("won")
	return last_landed


## Advances the set by `delta` seconds: mic recharges, the Room line moves,
## the crowd makes its moves, and the clock runs toward the light.
func tick(delta: float) -> void:
	if result != Result.ONGOING or delta <= 0.0:
		return
	elapsed += delta
	time_left -= delta
	_since_land += delta
	mic = minf(Balance.MIC_MAX, mic + Balance.MIC_PER_SECOND * delta)

	# The Room line: steady cooling, a random wander, and dead air.
	_wobble_clock -= delta
	if _wobble_clock <= 0.0:
		_wobble_clock = 0.6
		_wobble = _rng.randf_range(-1.0, 1.0) * Balance.HEAT_WOBBLE
	var change := -Balance.HEAT_DRIFT + _wobble * wobble_scale
	if _since_land > Balance.DEAD_AIR_AFTER and not bit_open():
		change -= Balance.DEAD_AIR_DRAIN
	_change_energy(change * delta)

	_event_clock -= delta
	if _event_clock <= 0.0:
		_event_clock += audience.event_every
		_apply_intent(current_intent())
		_intent_index += 1
		next_intent_revealed = false

	_chart_clock += delta
	while _chart_clock >= Balance.CHART_STEP:
		_chart_clock -= Balance.CHART_STEP
		heat_history.append(crowd_energy)
		if heat_history.size() > Balance.CHART_POINTS:
			heat_history.pop_front()

	if crowd_energy <= 0.0:
		_lose(Loss.ROOM)
		return
	if time_left <= 0.0:
		time_left = 0.0
		# The last bit squeezes in as the light goes on.
		land_bit()
		if result == Result.ONGOING:
			_lose(Loss.LIGHT)


## Dev tools: fill the meter and win the set right now.
func dev_win() -> void:
	if result != Result.ONGOING:
		return
	laughs = maxi(laughs, laughs_needed)
	result = Result.WON
	history.append("The room is roaring. You killed!")
	_events.append("won")


## Dev tools: full mic, the hottest room, and extra seconds on the clock.
func dev_boost(seconds: float) -> void:
	mic = Balance.MIC_MAX
	_change_energy(Balance.MAX_CROWD_ENERGY)
	time_left += seconds
	set_length += seconds


## Things that happened since the last call, oldest first.
func pop_events() -> Array[String]:
	var out := _events.duplicate()
	_events.clear()
	return out


func _lose(why: Loss) -> void:
	if result != Result.ONGOING:
		return
	result = Result.LOST
	loss = why
	history.append("You lost the room." if why == Loss.ROOM else "You got the light. Time's up.")
	_events.append("lost")


func _reset_bit() -> void:
	bit_laughs = 0
	chain_links = 0
	bit_jokes = []
	cards_played_this_bit = 0
	last_card = null
	last_beat = CardData.Beat.NONE
	last_play_linked = false
	last_play_chained = false
	_last_punch_laughs = 0
	setups_pending = 0


func _refill_hand() -> void:
	_draw(hand_size - hand.size())


func _draw(count: int) -> void:
	for i in count:
		if hand.size() >= Balance.MAX_HAND:
			return
		var c := _take()
		if c == null:
			return
		hand.append(c)


## Top card of the draw pile (reshuffling the discards in), or null.
func _take() -> CardData:
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			return null
		draw_pile.append_array(discard_pile)
		discard_pile.clear()
		_shuffle(draw_pile)
	return draw_pile.pop_back()


func _apply_intent(intent: IntentData) -> void:
	if intent == null:
		return
	match intent.kind:
		IntentData.Kind.DRAIN:
			_change_energy(-intent.amount)
			if bit_open():
				var keep := 0.75 if crew.has("lawyer") else Balance.INTERRUPT_KEEP
				bit_laughs = int(bit_laughs * keep)
				for j in bit_jokes.size():
					var cut: Dictionary = bit_jokes[j].duplicate()
					cut.laughs = int(cut.laughs * keep)
					bit_jokes[j] = cut
				chain_links = 0
				last_beat = CardData.Beat.NONE
				_events.append("interrupt")
				history.append("Interrupted! The bit loses steam.")
		IntentData.Kind.RESTLESS:
			mic = maxf(0.0, mic - intent.amount)
		IntentData.Kind.TOUGH_CROWD:
			laughs_needed = int(laughs_needed * (1.0 + intent.amount / 100.0))
		IntentData.Kind.SPIKE:
			_change_energy(intent.amount)
	history.append("%s: %s" % [audience.title, intent.text])
	_events.append("event")


func _change_energy(amount: float) -> void:
	crowd_energy = clampf(crowd_energy + amount, 0.0, Balance.MAX_CROWD_ENERGY)


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
