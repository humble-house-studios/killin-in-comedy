class_name BusyLines
## Look Busy (docs/look-busy.md): the bosses, one per floor, and what they
## say when they catch you. Rules: engine/workday.gd; the office side:
## scenes/office/look_busy.gd.
##
## Boss fields:
##   kind: "walk" (patrols the office on a route) or "call" (works from home:
##     video-calls your screen instead of walking by).
##   at / every: first visit, then one every `every`, in game minutes after
##     9:00 (no visits over lunch, 12-1). Fixed, so you can learn them.
##   habit: the one-line tip on the morning card.
##   speed (m/s), range (m), cone (degrees either side of where they face),
##   rate: suspicion per second while they watch you play a game.
##   creak: the door creaks when they come in. steps_db: how loud they walk.
##   ring / call: seconds a video call rings, then stays connected.
##   route: office spots (x, z) in order; wait = seconds they stop there,
##     look = what they stare at, desk = they check that you're at a desk.
##   look_body: how they're built (ladder.gd's _person look).

const FLOORS := 3

const MAIN_DESK := Vector2(0.0, -2.4)

## The patrol on floors with a walking boss: in through the office door,
## past your desk, Dale, the Pong desk and the right wall, and back out.
const ROUTE := [
	{"p": Vector2(1.8, 5.2)},
	{"p": Vector2(1.8, 3.3)},
	{"p": Vector2(0.9, 1.5)},
	{"p": Vector2(0.15, -1.2), "wait": 2.6, "look": Vector2(0.0, -2.4), "desk": true},
	{"p": Vector2(-1.9, -0.3), "wait": 1.8, "look": Vector2(-3.05, -0.6)},
	{"p": Vector2(-2.0, 1.9), "wait": 1.6, "look": Vector2(-3.05, 2.0)},
	{"p": Vector2(0.6, 2.0), "wait": 1.8, "look": Vector2(3.0, 0.2)},
	{"p": Vector2(1.8, 3.3)},
	{"p": Vector2(1.8, 5.2)},
]

const BOSSES := [
	{
		"id": "marge", "name": "MARGE", "title": "FLOOR MANAGER", "kind": "walk",
		"habit": "MARGE WALKS THE FLOOR EVERY 90 MINUTES: 9:20, 10:50, 1:50, 3:20, 4:50.",
		"at": 20, "every": 90, "speed": 1.1, "range": 6.0, "cone": 55.0, "rate": 30.0,
		"creak": true, "steps_db": -8.0,
		"look_body": {"skin": Color(0.9, 0.72, 0.6), "shirt": Color(0.62, 0.18, 0.24), "pants": Color(0.2, 0.18, 0.22),
			"hair": Color(0.55, 0.32, 0.16), "hair_style": "bob", "glasses": true, "lanyard": true},
		"hello": "MARGE. FLOOR MANAGER. MICROMANAGER.",
		"warning": ["Is that... a GAME? On my floor? Verbal warning.", "I see you. I always see you. Consider this a warning."],
		"writeup": ["That's a write-up. In ink. HR gets a copy.", "Twice now. I'm writing this one down. In triplicate."],
		"fired": ["Clear your desk. Security will walk you out.", "Three strikes. Badge on the desk, please."],
		"desk": ["Where is... whoever sits here?", "Empty desk again."],
	},
	{
		"id": "chad", "name": "CHAD", "title": "VP, WORKING FROM HOME", "kind": "call",
		"habit": "CHAD WORKS FROM HOME. HE VIDEO-CALLS YOUR SCREEN AT :45 EVERY HOUR. BE AT A DESK, LOOKING BUSY.",
		"at": 45, "every": 60, "ring": 4.0, "call": 5.0, "rate": 45.0,
		"hello": "CHAD. VP. WORKING FROM HOME (HIS BOAT).",
		"warning": ["Bro. Is that Pong behind your spreadsheet? Warning, bro.", "Quick sync: stop gaming. That's a warning."],
		"writeup": ["Circling back: you're written up. Per my last email.", "Not a great look, champ. That's a write-up."],
		"fired": ["We're going to have to let you go. My boat's breaking up.", "Synergy says: you're fired. Peace."],
		"desk": ["You're on mute. And also not at your desk.", "Hello? Is anyone at this desk?"],
	},
	{
		"id": "ceo", "name": "THE CEO", "title": "NOBODY HAS MET HIM", "kind": "walk",
		"habit": "THE CEO. NOBODY HAS MET HIM. NO CREAK, SOFT STEPS. 10:05, 2:05, 4:05.",
		"at": 65, "every": 120, "speed": 1.5, "range": 7.5, "cone": 65.0, "rate": 50.0,
		"creak": false, "steps_db": -20.0,
		"look_body": {"skin": Color(0.55, 0.5, 0.5), "shirt": Color(0.06, 0.06, 0.08), "pants": Color(0.05, 0.05, 0.06),
			"hair": Color(0.04, 0.04, 0.05), "hair_style": "slick", "tie": Color(0.05, 0.05, 0.06), "wide": 1.1},
		"hello": "THE CEO. NOBODY HAS MET HIM.",
		"warning": ["...", "I see."],
		"writeup": ["...Noted.", "Hm."],
		"fired": ["You may go.", "Goodbye."],
		"desk": ["...", "Hm. Empty."],
	},
]

const DAYS := ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]

## Morning card headlines, by day.
const MORNING := [
	"NEW WEEK. SHIP SOMETHING BY FRIDAY.",
	"TUESDAY. NOBODY LIKES TUESDAY.",
	"WEDNESDAY. HUMP DAY. LOOK BUSY.",
	"THURSDAY. ONE MORE DAY TO BUILD.",
	"FRIDAY. SHIP DAY. 5 PM.",
]
