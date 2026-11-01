class_name Dev
extends RefCounted
## Testing shortcuts: the DEV button in the office and DEV TOOLS in the comedy
## game's pause menu, so later parts can be tested without playing through.
## Pure rules, no scenes. Set ON to false to hide every dev button before
## shipping.

const ON := true

## Story saves the WIPE button deletes (the office look choice stays).
const SAVES := [
	"user://dale.cfg", "user://ladder.cfg", "user://coworkers.cfg",
	"user://office_relics.cfg", "user://tips.cfg",
]
const MACHINES := ["claw", "pusher", "ragdoll"]


## Stat -> how much to add so a Dale chapter's `need` is met ({} if it is).
static func missing(chapter: Dictionary, stats: Dictionary) -> Dictionary:
	var out := {}
	var need: Dictionary = chapter.get("need", {})
	for key in need:
		var short := int(need[key]) - int(stats.get(key, 0))
		if short > 0:
			out[key] = short
	return out


## Every coworker straight to full trust, paying out each tier on the way
## (tokens, tickets, perks, their secret) as if you'd talked them all up.
static func max_coworkers(crew: Coworkers, state: LadderState) -> void:
	for id in CoworkerLines.ORDER:
		var p := Coworkers.person(id)
		if p.is_empty():
			continue
		for t in range(crew.tier(id) + 1, Coworkers.MAX_TIER + 1):
			var reward: Dictionary = p.rewards[t - 1]
			if reward.has("reward"):
				for r in str(reward.reward).split(","):
					state.apply_reward(r)
			if reward.has("secret") and not crew.secrets.has(id):
				crew.secrets.append(id)
		crew.trust[id] = Coworkers.MAX_TIER
		crew.closed.erase(id)
		if not crew.met.has(id):
			crew.met.append(id)
	crew.save()


## Every machine's big prize won (two of them bring Ray out).
static func beat_machines(state: LadderState) -> void:
	for m in MACHINES:
		state.beat(m)


## Every ladder door unlocked: both keys in your pocket and each room's goal
## done. Dale's story (the office door) is finished separately.
static func open_ladder(state: LadderState) -> void:
	for item in [LadderState.DOOR_KEY, "archive_key"]:
		state.apply_reward("item:" + item)
	for m in ["market", "pitch", "memo"]:
		state.mark(m)


static func wipe() -> void:
	for path in SAVES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
