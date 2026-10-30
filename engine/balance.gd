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

## Heat (Crowd Energy) is the bit multiplier: 1 + Heat × this. Heat 10 = ×2.
const HEAT_MULT_PER_POINT := 0.1
## Each chain link (Setup → Punchline → Tag) adds this to the bit multiplier.
const CHAIN_MULT := 0.5
## Topic the crowd loves / hates: laughs × this, and Heat change.
const LOVED_MULT := 1.5
const HATED_MULT := 0.5
const LOVED_HEAT := 1
const HATED_HEAT := -1
## Mood thresholds for the UI only ("on fire" / "dying").
const HOT_ENERGY := 15
const COLD_ENERGY := 4

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
