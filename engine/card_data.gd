class_name CardData
extends Resource
## One card. Its effect is described entirely by these numbers, so new cards
## are new .tres files in res://data/cards/, not new code.

@export var id := ""
@export var title := ""
@export var cost := 1
## One line of rules shown on the card.
@export_multiline var rules := ""
## What the comedian says when it's played (speech bubble).
@export var line := ""

@export var laughs := 0
## +combo_bonus laughs if at least combo_after cards were already played this turn.
@export var combo_after := 1
@export var combo_bonus := 0
## Laughs for each card played earlier this set / this turn.
@export var laughs_per_card_this_set := 0
@export var laughs_per_card_this_turn := 0
@export var crowd_energy := 0
@export var mic_gain := 0
@export var draw := 0
## Number of upcoming Punchlines this card doubles.
@export var setups := 0
@export var is_punchline := false
@export var reveals_intent := false

## Link: a bonus when the card played just before this one (same turn) is of
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
