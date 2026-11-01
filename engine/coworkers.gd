class_name Coworkers
extends RefCounted
## The arcade coworkers: who trusts you how much, whose secrets you know, and
## what each conversation looks like. Talking is improv: every reply has a
## stance, each coworker loves one (+1 trust) and hates one (-1, and they close
## off until you play another machine round). Trust tiers 1-3 pay out a bonus,
## a lore secret and a perk. Callbacks (a secret from one coworker brought to
## another) and gifts from the prize counter are +1 each. Lines live in
## data/coworker_lines.gd; the office's talk box shows the talks this builds.
## Pure rules, saved in user://coworkers.cfg.

const SAVE_PATH := "user://coworkers.cfg"
const MAX_TIER := 3
## Ray only shows up once the lights dim: after this many machines are beaten.
const RAY_AFTER := 2

var trust := {}
## id -> machine rounds played when they closed off (they reopen after one more).
var closed := {}
## Coworker ids whose secret you know, in the order you learned them.
var secrets: Array[String] = []
var used_callbacks: Array[String] = []
var gifted: Array[String] = []
## Coworkers you've talked to at least once.
var met: Array[String] = []
## id -> machine rounds played the last time you talked to them.
var seen_at := {}
## Look Busy: coworkers you burned (they snitch until you make up).
var burned: Array[String] = []

var _path: String
var _rng := RandomNumberGenerator.new()


func _init(save_path := SAVE_PATH, rng_seed := -1) -> void:
	_path = save_path
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	load_save()


static func person(id: String) -> Dictionary:
	return CoworkerLines.PEOPLE.get(id, {})


func tier(id: String) -> int:
	return clampi(int(trust.get(id, 0)), 0, MAX_TIER)


## Look Busy (docs/look-busy.md): what this coworker does for (or to) you.
## "snitch" (burned), "collaborator" (trust 2+), "lookout" (trust 1+) or "".
func role(id: String) -> String:
	if burned.has(id):
		return "snitch"
	var t := tier(id)
	if t >= 2:
		return "collaborator"
	if t >= 1:
		return "lookout"
	return ""


## Everyone with this role (in CoworkerLines.ORDER). Lookouts include
## collaborators: anyone who trusts you keeps an eye out.
func with_role(r: String) -> Array[String]:
	var out: Array[String] = []
	for id in CoworkerLines.ORDER:
		var mine := role(id)
		if mine == r or (r == "lookout" and mine == "collaborator"):
			out.append(id)
	return out


const ROLE_NAMES := {"lookout": "LOOKOUT", "collaborator": "COLLABORATOR", "snitch": "SNITCH"}


## Is this coworker in the arcade right now? (Ray comes out after dark.)
static func present(id: String, beaten: int) -> bool:
	return id != "ray" or beaten >= RAY_AFTER


func is_closed(id: String, plays: int) -> bool:
	return closed.has(id) and plays <= int(closed[id])


## Is there something new to say to them? Never met, a gift to give, a
## callback to bring up, or more to learn since you last played a machine.
## Drives the "!" over their head.
func has_news(id: String, ctx: Dictionary) -> bool:
	if is_closed(id, int(ctx.get("plays", 0))):
		return false
	if not met.has(id) or not _gift_choice(id, ctx).is_empty() or not _callbacks_for(id).is_empty():
		return true
	# Still more to learn, and you've played since you last talked.
	return tier(id) < MAX_TIER and int(ctx.get("plays", 0)) > int(seen_at.get(id, -1))


## The next conversation with a coworker, in the talk box's shape:
## {id, title, steps}. A step is {"line": text} or {"choices": [...]}; each
## choice is {text, kind ("stance" / "gift" / "callback"), ...} and goes back
## to choose(). ctx: {plays, items (Array), beaten (int)}.
func talk(id: String, ctx: Dictionary) -> Dictionary:
	var p := person(id)
	var t := tier(id)
	var steps: Array = []
	var title := "%s  -  %s" % [p.name, p.title]
	if ctx.get("busy", false) and role(id) != "":
		title += "  (%s)" % ROLE_NAMES[role(id)]
	if not met.has(id):
		met.append(id)
	seen_at[id] = int(ctx.get("plays", 0))
	save()
	if is_closed(id, int(ctx.get("plays", 0))):
		steps.append({"line": p.closed})
		return {"id": id, "title": title, "steps": steps}
	steps.append({"line": p.hello[mini(t, p.hello.size() - 1)]})
	var choices: Array = []
	if t < MAX_TIER:
		var prompt: Dictionary = p.prompts[t]
		steps.append({"line": prompt.line})
		for stance in _offered(p):
			var r: Array = prompt.replies[stance]
			choices.append({"text": r[0], "kind": "stance", "stance": stance, "tag": CoworkerLines.STANCE_TAG[stance]})
	else:
		steps.append({"line": p.after[_rng.randi_range(0, p.after.size() - 1)]})
	# One extra: a gift you can give, else a callback you can bring up.
	var extra := _gift_choice(id, ctx)
	if extra.is_empty():
		var cbs := _callbacks_for(id)
		if not cbs.is_empty():
			var cb: Dictionary = cbs[0]
			extra = {"text": cb.text, "kind": "callback", "callback": cb.id, "tag": "CALLBACK"}
	if not extra.is_empty():
		choices.append(extra)
	if not choices.is_empty():
		steps.append({"choices": choices})
	return {"id": id, "title": title, "steps": steps}


## Say a reply. Returns {lines: [what they say back, then any payout lines],
## rewards: ["tokens:5", "item:x", "consume:plush", ...], delta: trust change,
## secret: the secret text if one was told, perk: perk text if earned,
## role: the Look Busy role it changed to ("" if unchanged; only when
## ctx.busy)}.
func choose(id: String, choice: Dictionary, ctx: Dictionary) -> Dictionary:
	var p := person(id)
	var out := {"lines": [], "rewards": [], "delta": 0, "secret": "", "perk": "", "role": ""}
	var before := tier(id)
	var role_before := role(id)
	match choice.get("kind", "stance"):
		"stance":
			var stance: String = choice.stance
			var prompt: Dictionary = p.prompts[mini(before, p.prompts.size() - 1)]
			out.lines.append(prompt.replies[stance][1])
			if stance == p.loves:
				out.delta = 1
			elif stance == p.hates:
				out.delta = -1
				closed[id] = int(ctx.get("plays", 0))
				# Look Busy: hated while they don't trust you at all burns them.
				if ctx.get("busy", false) and before == 0 and not burned.has(id):
					burned.append(id)
		"gift":
			out.lines.append(p.gift_reply)
			out.delta = 1
			gifted.append(id)
			if p.has("gift"):
				out.rewards.append("consume:" + p.gift)
		"callback":
			for cb in CoworkerLines.CALLBACKS:
				if cb.id == choice.callback:
					out.lines.append(cb.reply)
			used_callbacks.append(choice.callback)
			out.delta = 1
	trust[id] = clampi(before + out.delta, 0, MAX_TIER)
	# Any warm reply (loved, a gift, a callback) makes up for burning them.
	if out.delta > 0:
		burned.erase(id)
	# Every tier newly reached pays out.
	for t in range(before + 1, tier(id) + 1):
		var reward: Dictionary = p.rewards[t - 1]
		out.lines.append(reward.line)
		if reward.has("reward"):
			for r in str(reward.reward).split(","):
				out.rewards.append(r)
		if reward.has("secret"):
			if not secrets.has(id):
				secrets.append(id)
			out.secret = reward.secret
		if reward.has("perk"):
			out.perk = reward.perk
	if ctx.get("busy", false) and role(id) != role_before:
		out.role = role(id)
		var b: Dictionary = CoworkerLines.BUSY.get(id, {})
		match out.role:
			"lookout":
				out.lines.append("I'll keep an eye out for the boss. If you hear me cough, alt-tab.")
			"collaborator":
				out.lines.append(b.get("side", {}).get("pitch", ""))
			"snitch":
				out.lines.append(b.get("snitch", ""))
	save()
	return out


## The lore secrets you've learned, as text, in the order you learned them.
func secret_texts() -> Array[String]:
	var out: Array[String] = []
	for id in secrets:
		out.append(person(id).rewards[1].secret)
	return out


# Three stances per prompt: the loved one, the hated one and one of the others,
# shuffled, so reading the person matters.
func _offered(p: Dictionary) -> Array:
	var others: Array = []
	for s in CoworkerLines.STANCE_TAG:
		if s != p.loves and s != p.hates:
			others.append(s)
	var picks := [p.loves, p.hates, others[_rng.randi_range(0, others.size() - 1)]]
	for i in range(picks.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = picks[i]
		picks[i] = picks[j]
		picks[j] = tmp
	return picks


func _gift_choice(id: String, ctx: Dictionary) -> Dictionary:
	var p := person(id)
	if gifted.has(id) or tier(id) >= MAX_TIER:
		return {}
	if p.has("gift") and Array(ctx.get("items", [])).has(p.gift):
		return {"text": p.gift_text, "kind": "gift", "tag": "GIFT"}
	if p.get("gift_need", "") == "beaten" and int(ctx.get("beaten", 0)) > 0:
		return {"text": p.gift_text, "kind": "gift", "tag": "BRAG"}
	return {}


func _callbacks_for(id: String) -> Array:
	var out: Array = []
	for cb in CoworkerLines.CALLBACKS:
		if cb.at == id and secrets.has(cb.from) and not used_callbacks.has(cb.id):
			out.append(cb)
	return out


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	var t = cfg.get_value("coworkers", "trust", {})
	trust = t if t is Dictionary else {}
	var c = cfg.get_value("coworkers", "closed", {})
	closed = c if c is Dictionary else {}
	secrets.clear()
	for s in cfg.get_value("coworkers", "secrets", []):
		secrets.append(str(s))
	used_callbacks.clear()
	for s in cfg.get_value("coworkers", "callbacks", []):
		used_callbacks.append(str(s))
	gifted.clear()
	for s in cfg.get_value("coworkers", "gifted", []):
		gifted.append(str(s))
	met.clear()
	for s in cfg.get_value("coworkers", "met", []):
		met.append(str(s))
	var sa = cfg.get_value("coworkers", "seen_at", {})
	seen_at = sa if sa is Dictionary else {}
	burned.clear()
	for s in cfg.get_value("coworkers", "burned", []):
		burned.append(str(s))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("coworkers", "trust", trust)
	cfg.set_value("coworkers", "closed", closed)
	cfg.set_value("coworkers", "secrets", Array(secrets))
	cfg.set_value("coworkers", "callbacks", Array(used_callbacks))
	cfg.set_value("coworkers", "gifted", Array(gifted))
	cfg.set_value("coworkers", "met", Array(met))
	cfg.set_value("coworkers", "seen_at", seen_at)
	cfg.set_value("coworkers", "burned", Array(burned))
	cfg.save(_path)
