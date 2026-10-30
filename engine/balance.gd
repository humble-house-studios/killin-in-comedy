class_name Balance
## Every global game number in one place, so tuning never means hunting
## through code. Per-card and per-audience numbers live in res://data/.

const MIC_PER_TURN := 3
const HAND_SIZE := 5
const MAX_HAND := 10

const START_CROWD_ENERGY := 10
const MAX_CROWD_ENERGY := 20
## Crowd Energy lost at the end of every turn.
const ENERGY_DRIFT := 1
## Extra Crowd Energy lost when a turn ends with no laughs.
const BOMB_PENALTY := 2

## Crowd Energy at or above HOT multiplies laughs up; at or below COLD, down.
const HOT_ENERGY := 15
const HOT_MULTIPLIER := 1.5
const COLD_ENERGY := 4
const COLD_MULTIPLIER := 0.75

## A Setup multiplies the base laughs of the next Punchline by this.
const SETUP_MULTIPLIER := 2

const REWARD_CHOICES := 3

## Card id -> copies in the starting deck.
const STARTER_DECK := {
	"punchline": 4,
	"yes_and": 3,
	"setup": 2,
	"crowd_work": 1,
}
