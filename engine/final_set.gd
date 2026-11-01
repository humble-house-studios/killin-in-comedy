class_name FinalSet
extends RefCounted
## The stage, last room of the ladder: an open mic down the street. You get
## five picks from your material and need 100 laughs. A Setup doubles the next
## Punchline; every Tag right after a Punchline lands at x1.5. The secrets you
## learned from your coworkers become killer bits, and the founder's memo
## gives you BIG DEAL. Plain material can still win if you build the bit
## right, so nobody gets stuck. Pure rules: scenes/ladder/final_set.gd.

const PICKS := 5
const TARGET := 100
const SETUP_X := 2.0
const TAG_X := 1.5

const BASE := [
	{"id": "opener", "name": "OPENER", "beat": "setup", "laughs": 10, "text": "So I work at a game studio..."},
	{"id": "punch_a", "name": "PUNCHLINE", "beat": "punch", "laughs": 20, "text": "...my job is playing games. My boss calls it research."},
	{"id": "punch_b", "name": "PUNCHLINE", "beat": "punch", "laughs": 20, "text": "...the claw machine has better benefits than I do."},
	{"id": "tag_a", "name": "TAG", "beat": "tag", "laughs": 15, "text": "And it still won't let go of my quarters."},
	{"id": "tag_b", "name": "TAG", "beat": "tag", "laughs": 15, "text": "I put that on my resume. Twice."},
	{"id": "crowd", "name": "CROWD WORK", "beat": "", "laughs": 12, "text": "Anybody here work in an office? I'm sorry."},
]
## One killer bit per coworker secret, keyed by coworker id.
const SECRET_BITS := {
	"gloria": {"id": "gloria", "name": "THE BLANK CREDITS", "beat": "punch", "laughs": 35, "text": "First game we ever made, nobody signed it. Who does that? A genius. Or a coward."},
	"kev": {"id": "kev", "name": "THE INVISIBLE CEO", "beat": "punch", "laughs": 35, "text": "Our CEO's so hands-off, his own nephew has never met him."},
	"bernie": {"id": "bernie", "name": "THE BLANK FILE", "beat": "punch", "laughs": 35, "text": "HR pulled one guy's file. Empty. Fifteen years. Legend."},
	"theo": {"id": "theo", "name": "THE CHEF", "beat": "tag", "laughs": 30, "text": "My rival wants the promotion so bad. He'd rather make risotto."},
	"ray": {"id": "ray", "name": "THE BRICK WALL", "beat": "setup", "laughs": 25, "text": "Fun fact: my office used to be a comedy club. So you're all trespassing."},
}
const MEMO_BIT := {"id": "memo", "name": "BIG DEAL", "beat": "punch", "laughs": 50, "text": "My mentor did stand-up for one week. Then he bought the club. That's commitment."}

var hand: Array = []
var played: Array = []
var laughs := 0.0
## What each played card scored, for the casino-style pop-up.
var last_score := 0.0
var last_reason := ""

var _setup := false
var _after_punch := false


func _init(secrets: Array = [], memo := false) -> void:
	hand = BASE.duplicate(true)
	for id in secrets:
		if SECRET_BITS.has(id):
			hand.append(SECRET_BITS[id].duplicate())
	if memo:
		hand.append(MEMO_BIT.duplicate())


func picks_left() -> int:
	return PICKS - played.size()


func done() -> bool:
	return played.size() >= PICKS or won()


func won() -> bool:
	return laughs >= TARGET


func lost() -> bool:
	return played.size() >= PICKS and not won()


## Play a card by id. Returns the laughs it scored (0 if it can't be played).
func play(id: String) -> float:
	if done():
		return 0.0
	var card := {}
	for c in hand:
		if c.id == id:
			card = c
	if card.is_empty():
		return 0.0
	hand.erase(card)
	played.append(card)
	var score := float(card.laughs)
	last_reason = ""
	match card.beat:
		"setup":
			_setup = true
			_after_punch = false
		"punch":
			if _setup:
				score *= SETUP_X
				last_reason = "SETUP x2"
			_setup = false
			_after_punch = true
		"tag":
			if _after_punch:
				score *= TAG_X
				last_reason = "TAG x1.5"
			_setup = false
		_:
			_setup = false
			_after_punch = false
	laughs += score
	last_score = score
	return score
