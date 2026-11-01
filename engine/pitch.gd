class_name Pitch
extends RefCounted
## The boardroom: you pitch your dream project to a board of five. Each turn
## one member raises an objection (BUDGET, RISK, TIMING, AUDIENCE, HEART) like
## a heckler; you answer with a card from your hand of three. A matching card,
## or a YES, AND wild card, wins their vote. Three yeses of five greenlight
## it. Theo's vote is a yes before you start; Bernie's HR badge lets you
## redraw your hand once. Pure rules: scenes/ladder/pitch_screen.gd draws it.

const NEED := 3
const HAND := 3
const WILD := "WILD"
const BOARD := [
	{"name": "MS. LEDGER", "kind": "BUDGET", "line": "How much is this going to cost us?"},
	{"name": "MR. HEDGE", "kind": "RISK", "line": "And what happens when it flops?"},
	{"name": "DR. CLOCK", "kind": "TIMING", "line": "Why now? Why not next year?"},
	{"name": "MS. METRICS", "kind": "AUDIENCE", "line": "Who is this even for?"},
	{"name": "OLD MAN BRIGGS", "kind": "HEART", "line": "Do you actually care about this, kid?"},
]
const ANSWERS := [
	{"kind": "BUDGET", "text": "It's cheap. One room, one mic."},
	{"kind": "BUDGET", "text": "Ticket sales pay for it."},
	{"kind": "RISK", "text": "We test it every Thursday."},
	{"kind": "RISK", "text": "Small bets. Fast fixes."},
	{"kind": "TIMING", "text": "Everyone's bored right now."},
	{"kind": "TIMING", "text": "Nobody's doing it yet."},
	{"kind": "AUDIENCE", "text": "Anyone who's ever been bored."},
	{"kind": "AUDIENCE", "text": "Office workers. All of them."},
	{"kind": "HEART", "text": "I'd do it for free."},
	{"kind": "HEART", "text": "It's the only thing I want."},
	{"kind": WILD, "text": "YES, AND..."},
	{"kind": WILD, "text": "YES, AND..."},
]

## Board members in the order they'll object (indices into BOARD).
var order: Array = []
var turn := 0
var yes := 0
var no := 0
var hand: Array = []
var deck: Array = []
var redraws := 0
## Per turn: true = they voted yes.
var votes: Array = []
var ally := false

var _rng := RandomNumberGenerator.new()


func _init(rng_seed := -1, theo_vote := false, hr_badge := false) -> void:
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	for i in BOARD.size():
		order.append(i)
	_shuffle(order)
	deck = ANSWERS.duplicate(true)
	_shuffle(deck)
	ally = theo_vote
	if theo_vote:
		yes = 1
	redraws = 1 if hr_badge else 0
	_fill()


func member() -> Dictionary:
	return BOARD[order[turn]] if turn < order.size() else {}


func done() -> bool:
	return turn >= order.size() or won() or lost()


func won() -> bool:
	return yes >= NEED


## No way to reach three yeses any more.
func lost() -> bool:
	return yes + (order.size() - turn) < NEED


## Answer with the card at this hand index. Returns true if it won the vote.
func answer(i: int) -> bool:
	if done() or i < 0 or i >= hand.size():
		return false
	var card: Dictionary = hand[i]
	hand.remove_at(i)
	var ok: bool = card.kind == WILD or card.kind == member().kind
	if ok:
		yes += 1
	else:
		no += 1
	votes.append(ok)
	turn += 1
	_fill()
	return ok


## Swap the whole hand for new cards (HR badge). False if none left.
func redraw() -> bool:
	if redraws <= 0 or done():
		return false
	redraws -= 1
	for c in hand:
		deck.append(c)
	hand.clear()
	_shuffle(deck)
	_fill()
	return true


func _fill() -> void:
	while hand.size() < HAND and not deck.is_empty():
		hand.append(deck.pop_back())


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
