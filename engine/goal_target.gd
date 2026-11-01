class_name GoalTarget
extends RefCounted
## Where the goal marker points. Follows the same chain as the TO-DO (Dale's
## chapters, then the ladder): goal() names the one thing to do next, and
## point() turns it into what to walk to from the room you're in (the thing
## itself, or the next door on the way; a locked door points at whatever
## unlocks it). Pure rules, no scenes: the office maps each key to a spot.
##
## Keys: dale, pong, cube, comedy, proof, loot (office desks); door_office,
## door_trading, door_boardroom, door_corner, door_stage, door_archive;
## claw, pusher, ragdoll (arcade cabinets), counter, trading, pitch, memo,
## stage, dale_stage and the coworkers (gloria, kev, bernie, theo, ray).
## "cabinet" (from goal()) means "the nearest unbeaten arcade cabinet".

## Which office desk earns each stat Dale's chapters ask for.
const DESK := {
	"pong_bosses": "pong", "cube_records": "cube", "comedy_sets": "comedy",
	"comedy_shows": "comedy", "loot_runs": "loot", "loot_wins": "loot", "proof_wins": "proof",
}
const CABINETS := ["claw", "pusher", "ragdoll"]
## Rooms in walking order (same as the ladder's ORDER) and the door at the
## far end of each.
const ORDER := ["office", "arcade", "trading", "boardroom", "corner", "stage"]
const EXIT := {
	"office": "door_office", "arcade": "door_trading", "trading": "door_boardroom",
	"boardroom": "door_corner", "corner": "door_stage",
}
## The room each key stands in (doors: the room you open them from).
const ROOM := {
	"dale": "office", "pong": "office", "cube": "office", "comedy": "office",
	"proof": "office", "loot": "office", "door_office": "office",
	"claw": "arcade", "pusher": "arcade", "ragdoll": "arcade", "counter": "arcade",
	"door_trading": "arcade", "door_archive": "arcade", "cabinet": "arcade",
	"gloria": "arcade", "kev": "arcade", "bernie": "arcade", "theo": "arcade", "ray": "arcade",
	"trading": "trading", "door_boardroom": "trading",
	"pitch": "boardroom", "door_corner": "boardroom",
	"memo": "corner", "door_stage": "corner",
	"stage": "stage", "dale_stage": "stage",
}


static func room_of(key: String) -> String:
	return ROOM.get(key, "")


## The next thing to do, as a key ("" when there's nothing left to point at).
static func goal(story: DaleStory, stats: Dictionary, ladder: LadderState, crew: Coworkers) -> String:
	var ch := story.next_chapter()
	if not ch.is_empty():
		if DaleStory.unlocked(ch, stats):
			return "dale"
		var need: Dictionary = ch.get("need", {})
		for key in need:
			if int(stats.get(key, 0)) < int(need[key]):
				return DESK.get(key, "dale")
		return "dale"
	if not ladder.is_done("entered"):
		return "door_office"
	if not ladder.has(LadderState.DOOR_KEY):
		return unlock("door_trading", story, stats, ladder, crew)
	if not ladder.is_done("market"):
		return "trading"
	if not ladder.is_done("pitch"):
		return "pitch"
	if not ladder.is_done("memo"):
		return "memo"
	if not ladder.is_done("stage"):
		return "stage"
	if not ladder.is_done("archive"):
		return "door_archive" if ladder.has("archive_key") else unlock("door_archive", story, stats, ladder, crew)
	var secrets := crew.secrets.size()
	if ladder.true_ending(secrets):
		return "" if ladder.is_done("true_end") else "dale_stage"
	# Still short on secrets: whoever has something new to say.
	var ctx := context(ladder)
	for id in CoworkerLines.ORDER:
		if Coworkers.present(id, ladder.beaten.size()) and crew.has_news(id, ctx):
			return id
	return ""


## What opens a locked door: the key ("" if it's open, or nothing does).
static func unlock(door: String, story: DaleStory, stats: Dictionary, ladder: LadderState, crew: Coworkers) -> String:
	match door:
		"door_office":
			# Dale's story: whatever his next chapter needs.
			return "" if story.next_chapter().is_empty() else goal(story, stats, ladder, crew)
		"door_trading":
			return "counter" if ladder.tickets >= LadderState.DOOR_KEY_COST else "cabinet"
		"door_archive":
			# Ray has the key; he only comes out once two machines are beaten.
			var ctx := context(ladder)
			if Coworkers.present("ray", ladder.beaten.size()) and crew.has_news("ray", ctx):
				return "ray"
			return "cabinet"
		"door_boardroom":
			return "trading"
		"door_corner":
			return "pitch"
		"door_stage":
			return "memo"
	return ""


## The ladder's doors, open or not, as {key: bool}.
static func open_doors(story: DaleStory, ladder: LadderState) -> Dictionary:
	var office_done := story.next_chapter().is_empty()
	var out := {}
	for door in ["office", "trading", "archive", "boardroom", "corner", "stage"]:
		out["door_" + door] = ladder.door_open(door, office_done)
	return out


## The next hop from room `here` toward key: the key itself when it's in
## this room, else the door toward it.
static func hop(key: String, here: String) -> String:
	var there := room_of(key)
	if there == "" or there == here:
		return key
	if here == "archive":
		return "door_archive"
	var i := ORDER.find(here)
	var j := ORDER.find(there)
	if i < 0 or j < 0:
		return key
	return EXIT[ORDER[i]] if j > i else EXIT[ORDER[i - 1]]


## What to walk to right now: goal, routed from `here`, past locked doors.
## dist: {cabinet key: metres} so "cabinet" becomes the nearest unbeaten one.
static func point(story: DaleStory, stats: Dictionary, ladder: LadderState, crew: Coworkers, here: String, dist := {}) -> String:
	var open := open_doors(story, ladder)
	var unlocks := {}
	for door in open:
		if not open[door]:
			unlocks[door] = unlock(door, story, stats, ladder, crew)
	var key := route(goal(story, stats, ladder, crew), here, open, unlocks)
	return cabinet(ladder.beaten, dist) if key == "cabinet" else key


## Route key from room `here`: the next hop toward it; a shut door on the way
## (open[door] false) sends you to unlocks[door] instead, routed the same way.
static func route(key: String, here: String, open: Dictionary, unlocks: Dictionary) -> String:
	for _i in 8:
		if key == "":
			return ""
		var next := hop(key, here)
		if not open.get(next, true):
			var by: String = unlocks.get(next, "")
			if by == "" or by == key:
				return next
			key = by
			continue
		return next
	return key


## The nearest arcade cabinet you haven't beaten (all beaten: the nearest).
static func cabinet(beaten: Array, dist := {}) -> String:
	var best := ""
	var best_d := INF
	for pass_i in 2:
		for id in CABINETS:
			if pass_i == 0 and beaten.has(id):
				continue
			var d := float(dist.get(id, CABINETS.find(id)))
			if d < best_d:
				best_d = d
				best = id
		if best != "":
			return best
	return best


## The coworkers' talk context, as the ladder builds it.
static func context(ladder: LadderState) -> Dictionary:
	return {"plays": ladder.plays, "items": Array(ladder.items), "beaten": ladder.beaten.size()}
