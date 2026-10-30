class_name CardData
extends Resource
## One card. Its effect is described entirely by these numbers, so new cards
## are new .tres files in res://data/cards/, not new code.

enum Beat { NONE, SETUP, PUNCH, TAG }

## Topics a joke card can roll. Each matches a theme in res://data/jokes.gd.
const TOPICS := ["dating", "family", "work", "tech", "food", "animals"]
const TOPIC_NAMES := {
	"dating": "Dating", "family": "Family", "work": "Work",
	"tech": "Tech", "food": "Food", "animals": "Animals",
}

@export var id := ""
@export var title := ""
@export var cost := 1
## One line of rules shown on the card.
@export_multiline var rules := ""
## What the comedian says when it's played (speech bubble).
@export var line := ""

@export var laughs := 0
## Times the card fires when the bit lands (Rule of Three = 3).
@export var triggers := 1
## +combo_bonus laughs if at least combo_after cards were already played this bit.
@export var combo_after := 1
@export var combo_bonus := 0
## Laughs for each card played earlier this set / this bit.
@export var laughs_per_card_this_set := 0
@export var laughs_per_card_this_turn := 0
@export var crowd_energy := 0
@export var mic_gain := 0
@export var draw := 0
## Number of upcoming Punchlines this card doubles.
@export var setups := 0
@export var is_punchline := false
## Where it sits in a joke: Setup → Punchline → Tag. NONE = not a joke card.
@export var beat: Beat = Beat.NONE
## Rolled when the card joins your deck (joke cards only); "" = none.
@export var topic := ""
@export var reveals_intent := false

## Link: a bonus when the card played just before this one (same bit) is of
## the kind named here: "setup", "punchline" or "energy" (gives Crowd Energy).
@export var link_from := ""
@export var link_laughs := 0
@export var link_energy := 0
@export var link_draw := 0


## True if this card counts as the given kind for a link.
func is_kind(kind: String) -> bool:
	match kind:
		"setup":
			return setups > 0
		"punchline":
			return is_punchline
		"energy":
			return crowd_energy > 0
	return false


func is_joke() -> bool:
	return beat != Beat.NONE


## True if a card of beat `next` makes a chain link after one of beat `prev`.
static func follows(prev: Beat, next: Beat) -> bool:
	match next:
		Beat.PUNCH:
			return prev == Beat.SETUP
		Beat.TAG:
			return prev == Beat.PUNCH or prev == Beat.TAG
	return false


static func beat_name(b: Beat) -> String:
	match b:
		Beat.SETUP:
			return "SETUP"
		Beat.PUNCH:
			return "PUNCHLINE"
		Beat.TAG:
			return "TAG"
	return ""


## A copy of this card with the given topic (joke cards only).
func with_topic(t: String) -> CardData:
	var c: CardData = duplicate()
	c.topic = t if is_joke() else ""
	return c
