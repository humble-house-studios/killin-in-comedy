class_name Balance
## Every global game number in one place, so tuning never means hunting
## through code. Per-card and per-audience numbers live in res://data/.
## The set is live: times are in seconds.

## Card laughs in data are small (6, 12...); on screen they're ×this, so
## numbers feel big from the first joke.
const LAUGH_SCALE := 10

## Mic time recharges live, like elixir. Cards cost mic.
const MIC_MAX := 5.0
const MIC_START := 3.0
const MIC_PER_SECOND := 0.9

## Cards in hand. Playing one draws the next straight away.
const HAND_SIZE := 5
const MAX_HAND := 10

const START_CROWD_ENERGY := 10
const MAX_CROWD_ENERGY := 20
## Heat lost per second, always (the crowd cools off).
const HEAT_DRIFT := 0.12
## No bit landed for this long = dead air: Heat drains faster.
const DEAD_AIR_AFTER := 7.0
const DEAD_AIR_DRAIN := 0.6
## How much the Room line wanders on its own (Heat per second, at most).
const HEAT_WOBBLE := 0.9
## Landing a bit warms the room: +this Heat per chain link in it.
const LAND_HEAT_PER_LINK := 1

## Heat is the multiplier: 1 + Heat × this. Heat 10 = ×2.
const HEAT_MULT_PER_POINT := 0.1
## Each chain link (Setup → Punchline → Tag) multiplies the bit by this.
const CHAIN_X := 1.5
## A Tag that chains also re-fires the Punchline before it (this share of it).
const RETRIGGER_SHARE := 1.0
## A heckle while a bit is open cuts the pot to this share and breaks the chain.
const INTERRUPT_KEEP := 0.5

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

## Seconds between points on the Room chart.
const CHART_STEP := 0.2
const CHART_POINTS := 150

const REWARD_CHOICES := 3
const CREW_CHOICES := 3
const MAX_CREW := 3

## Card id -> copies in the starting deck.
const STARTER_DECK := {
	"punchline": 4,
	"yes_and": 3,
	"setup": 2,
	"crowd_work": 1,
}
