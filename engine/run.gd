class_name Run
extends RefCounted
## A whole run: the deck you're building and the line-up of sets ahead,
## ending with the boss.

var deck: Array[CardData] = []
var lineup: Array[AudienceData] = []
var set_index := 0
var battle: Battle

var _rng := RandomNumberGenerator.new()


func _init(rng_seed := 0) -> void:
	_rng.seed = rng_seed
	deck = CardLibrary.starter_deck(_rng)
	lineup = _make_lineup()


func current_audience() -> AudienceData:
	return lineup[set_index] if set_index < lineup.size() else null


func start_set() -> Battle:
	battle = Battle.new(current_audience(), deck, _rng.randi())
	return battle


func is_final_set() -> bool:
	return set_index == lineup.size() - 1


func reward_choices() -> Array[CardData]:
	return CardLibrary.reward_choices(_rng)


## Adds the picked card (or nothing, when skipped) and moves to the next set.
func finish_set(reward: CardData = null) -> void:
	if reward:
		deck.append(reward)
	set_index += 1


func is_complete() -> bool:
	return set_index >= lineup.size()


## Easiest crowd first, the other regulars shuffled, the boss last.
func _make_lineup() -> Array[AudienceData]:
	var regulars: Array[AudienceData] = []
	var bosses: Array[AudienceData] = []
	for a: AudienceData in CardLibrary.audiences().values():
		if a.is_boss:
			bosses.append(a)
		else:
			regulars.append(a)
	regulars.sort_custom(func(x, y): return x.laughs_needed < y.laughs_needed)
	var rest := regulars.slice(1)
	for i in range(rest.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = rest[i]
		rest[i] = rest[j]
		rest[j] = tmp
	var result: Array[AudienceData] = [regulars[0]]
	result.append_array(rest)
	result.append_array(bosses)
	return result
