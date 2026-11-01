class_name GameMaker
extends RefCounted
## Look Busy's "your own game" (docs/look-busy.md, Pillar 2), abstract for
## now: beating desks hands you pieces (a genre, a mechanic, an art style, a
## sound, a character); at the DEV KIT desk you put one of each kind in your
## build, pieces that go together combo (Balatro-joker style), and the build
## gets a score, a title and a short generated trailer. Pieces are per week:
## you ship on Friday and start the next week empty (collaborators' pieces
## come back while they still collaborate). Pure rules; saved in
## user://look_busy.cfg (section "game").

const SAVE_PATH := "user://look_busy.cfg"
const KINDS := ["genre", "mechanic", "art", "sound", "character"]
const KIND_NAMES := {"genre": "GENRE", "mechanic": "MECHANIC", "art": "ART STYLE", "sound": "SOUND", "character": "CHARACTER"}
## What each desk can hand you. The first piece is that desk's genre (or
## signature piece), the rest come in order after it.
const SOURCES := {
	"comedy": [["genre", "COMEDY"], ["mechanic", "CALLBACKS"], ["sound", "LAUGH TRACK"], ["art", "SPOTLIGHT"]],
	"pong": [["genre", "SPORTS"], ["mechanic", "PADDLES"], ["sound", "BLEEPS"], ["art", "VECTOR"]],
	"cube": [["genre", "PUZZLE"], ["mechanic", "SPEEDRUN"], ["art", "SIX COLORS"], ["sound", "CLICKY"]],
	"proof": [["genre", "MATH"], ["mechanic", "DECKBUILDING"], ["art", "CHALKBOARD"], ["sound", "ELEVATOR JAZZ"]],
	"loot": [["mechanic", "SLOT REELS"], ["genre", "CASINO"], ["mechanic", "RELICS"], ["art", "CASINO NEON"], ["sound", "DING DING"]],
	"claw": [["mechanic", "CLAW GRAB"], ["art", "PLUSH"]],
	"pusher": [["mechanic", "PUSH YOUR LUCK"], ["sound", "COIN RAIN"]],
	"ragdoll": [["mechanic", "RAGDOLL"], ["genre", "PHYSICS"]],
	"spreadsheet": [["art", "SPREADSHEET"], ["mechanic", "BUSYWORK"]],
}
## The shared office stats that count as beating a desk, and which desk.
const STAT_SOURCE := {
	"comedy_sets": "comedy", "comedy_shows": "comedy", "pong_bosses": "pong", "cube_records": "cube",
	"proof_wins": "proof", "loot_runs": "loot", "loot_wins": "loot",
}
## Spreadsheet cells for one piece of fake work.
const CELLS_PER_PIECE := 20
## Base points per piece in the build.
const BASE := 10
## Combos: every piece in `needs` in the build. `add` points, then `mult`.
const COMBOS := [
	{"name": "LAUGH SLOTS", "needs": ["COMEDY", "SLOT REELS"], "mult": 2.0},
	{"name": "PRATFALL", "needs": ["COMEDY", "RAGDOLL"], "add": 40},
	{"name": "HECKLE PONG", "needs": ["COMEDY", "PADDLES"], "add": 30},
	{"name": "SITCOM", "needs": ["COMEDY", "LAUGH TRACK"], "add": 25},
	{"name": "THE ORIGINAL", "needs": ["SPORTS", "PADDLES"], "add": 25},
	{"name": "RETRO", "needs": ["VECTOR", "BLEEPS"], "add": 25},
	{"name": "WORLD RECORD BAIT", "needs": ["PUZZLE", "SPEEDRUN"], "add": 30},
	{"name": "FIDGET TOY", "needs": ["SIX COLORS", "CLICKY"], "add": 20},
	{"name": "PROOF HAND", "needs": ["MATH", "DECKBUILDING"], "mult": 1.5},
	{"name": "BIG BRAIN", "needs": ["MATH", "CHALKBOARD"], "add": 30},
	{"name": "LOOT MACHINE", "needs": ["CASINO", "RELICS"], "mult": 1.5},
	{"name": "VIBE CASINO", "needs": ["CASINO", "VAPORWAVE"], "mult": 1.5},
	{"name": "AUDIO VISUAL", "needs": ["CASINO NEON", "DING DING"], "add": 25},
	{"name": "CLAW KING", "needs": ["CLAW GRAB", "PLUSH"], "add": 30},
	{"name": "FLOPPY PHYSICS", "needs": ["PHYSICS", "RAGDOLL"], "add": 30},
	{"name": "KITCHEN CHAOS", "needs": ["COOKING", "RAGDOLL"], "mult": 2.0},
	{"name": "CHEF THEO", "needs": ["COOKING", "THEO"], "mult": 1.5},
	{"name": "EXCEL RPG", "needs": ["RPG", "SPREADSHEET"], "mult": 2.0},
	{"name": "COMPLIANCE QUEST", "needs": ["RPG", "BERNIE"], "add": 35},
	{"name": "TPS REPORTS", "needs": ["BUSYWORK", "SPREADSHEET"], "add": 25},
	{"name": "QA SIMULATOR", "needs": ["GLITCH HUNT", "GLORIA"], "add": 35},
	{"name": "NIGHT SHIFT", "needs": ["MOP BEATS", "RAY"], "mult": 1.5},
	{"name": "NEPOTISM TYCOON", "needs": ["PUSH YOUR LUCK", "KEV"], "add": 35},
	{"name": "COIN OP", "needs": ["PUSH YOUR LUCK", "COIN RAIN"], "add": 25},
]
## A full build (one piece of every kind).
const FULL_KIT := 1.25

## Pieces this week: [{"kind": .., "name": .., "from": ..}, ...].
var pieces: Array = []
## The build: kind -> piece name.
var build := {}
## Stats as last seen, so a desk win shows up as a change.
var seen := {}
var beaten_seen: Array = []
var cells_used := 0

var _path: String
var _primed := false
var _rng := RandomNumberGenerator.new()


func _init(save_path := SAVE_PATH, rng_seed := -1) -> void:
	_path = save_path
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	load_save()


func has(name: String) -> bool:
	for p in pieces:
		if p.name == name:
			return true
	return false


static func kind_of(name: String) -> String:
	for src in SOURCES:
		for p in SOURCES[src]:
			if p[1] == name:
				return p[0]
	for id in CoworkerLines.BUSY:
		for p in CoworkerLines.BUSY[id].side.pieces:
			if p[1] == name:
				return p[0]
	return ""


## Add a piece (no duplicates). True if it's new.
func add(kind: String, name: String, from := "") -> bool:
	if has(name):
		return false
	pieces.append({"kind": kind, "name": name, "from": from})
	# The first piece of a kind goes straight into the build.
	if not build.has(kind):
		build[kind] = name
	save()
	return true


## A desk was beaten: hand over its next piece. Returns the piece
## ({kind, name}) or {} when that desk has nothing left this week.
func earn(source: String) -> Dictionary:
	for p in SOURCES.get(source, []):
		if not has(p[1]):
			add(p[0], p[1], source)
			return {"kind": p[0], "name": p[1]}
	return {}


## Collaborators' side projects (and themselves) join the kit. Returns the
## pieces that were new.
func collaborate(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		for p in CoworkerLines.BUSY.get(id, {}).get("side", {}).get("pieces", []):
			if add(p[0], p[1], id):
				out.append({"kind": p[0], "name": p[1], "from": id})
	return out


## New stats since last time: the desks they mean, one per win. The first
## look just remembers (no pieces for what you did before).
func desk_wins(stats: Dictionary, beaten: Array) -> Array:
	var out: Array = []
	if seen.is_empty() and beaten_seen.is_empty() and not _primed:
		_primed = true
		seen = stats.duplicate()
		beaten_seen = beaten.duplicate()
		save()
		return out
	for key in STAT_SOURCE:
		var d := int(stats.get(key, 0)) - int(seen.get(key, 0))
		for i in maxi(0, d):
			out.append(STAT_SOURCE[key])
	for m in beaten:
		if not beaten_seen.has(m):
			out.append(m)
	if not out.is_empty() or stats.hash() != seen.hash():
		seen = stats.duplicate()
		beaten_seen = beaten.duplicate()
		save()
	return out


## Spreadsheet cells filled today: a piece of "busywork" every CELLS_PER_PIECE.
func cell_wins(cells_today: int) -> int:
	var n := cells_today / CELLS_PER_PIECE - cells_used
	if n > 0:
		cells_used += n
		save()
	return maxi(n, 0)


func pick(kind: String, name: String) -> void:
	if has(name) and kind_of_piece(name) == kind:
		build[kind] = name
		save()


func clear_slot(kind: String) -> void:
	build.erase(kind)
	save()


func kind_of_piece(name: String) -> String:
	for p in pieces:
		if p.name == name:
			return p.kind
	return ""


func of_kind(kind: String) -> Array:
	return pieces.filter(func(p): return p.kind == kind)


## The build's names, in KINDS order.
func names() -> Array:
	var out: Array = []
	for k in KINDS:
		if build.has(k):
			out.append(build[k])
	return out


## {score, base, combos: [{name, text}]} for a build (kind -> name).
static func score_of(b: Dictionary) -> Dictionary:
	var have: Array = b.values()
	var base := BASE * have.size()
	var add := 0
	var mult := 1.0
	var combos: Array = []
	for c in COMBOS:
		var ok := true
		for n in c.needs:
			if not have.has(n):
				ok = false
				break
		if not ok:
			continue
		if c.has("add"):
			add += int(c.add)
			combos.append({"name": c.name, "text": "+%d" % int(c.add)})
		if c.has("mult"):
			mult *= float(c.mult)
			combos.append({"name": c.name, "text": "x" + String.num(float(c.mult))})
	if have.size() >= KINDS.size():
		mult *= FULL_KIT
		combos.append({"name": "FULL KIT", "text": "x1.25"})
	return {"score": int(round((base + add) * mult)), "base": base, "combos": combos}


func score() -> Dictionary:
	return score_of(build)


## The game's title: its best combo's name, or its genre and mechanic.
static func title_of(b: Dictionary) -> String:
	if b.is_empty():
		return "UNTITLED"
	var s := score_of(b)
	if not s.combos.is_empty() and s.combos[0].name != "FULL KIT":
		return "%s %s" % [s.combos[0].name, ["DELUXE", "95", "TURBO", "ULTRA", "II"][abs(str(b.values()).hash()) % 5]]
	var g: String = b.get("genre", "")
	var m: String = b.get("mechanic", "")
	if g != "" and m != "":
		return "%s %s" % [g, m]
	return "%s: THE GAME" % str(b.values()[0])


func title() -> String:
	return title_of(build)


## The trailer: one card per line, built from the pieces.
static func trailer_of(b: Dictionary) -> Array:
	var cards: Array = ["HUMBLE HOUSE GAMES PRESENTS"]
	if b.has("genre"):
		cards.append("IN A WORLD OF %s..." % b.genre)
	if b.has("character"):
		cards.append("ONE %s..." % b.character)
	if b.has("mechanic"):
		cards.append("MUST MASTER %s." % b.mechanic)
	var looks: Array = []
	if b.has("art"):
		looks.append("%s GRAPHICS" % b.art)
	if b.has("sound"):
		looks.append("%s SOUND" % b.sound)
	if not looks.is_empty():
		cards.append(". ".join(looks) + ".")
	var s := score_of(b)
	for c in s.combos:
		cards.append("%s! (%s)" % [c.name, c.text])
	cards.append(title_of(b))
	cards.append("SHIPS FRIDAY")
	return cards


func trailer() -> Array:
	return trailer_of(build)


## A new week: an empty kit (stats keep counting from where they are).
func new_week() -> void:
	pieces.clear()
	build.clear()
	cells_used = 0
	save()


## Fired: start over completely.
func reset() -> void:
	new_week()


func new_day() -> void:
	cells_used = 0
	save()


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	var p = cfg.get_value("game", "pieces", [])
	pieces = p if p is Array else []
	var b = cfg.get_value("game", "build", {})
	build = b if b is Dictionary else {}
	var s = cfg.get_value("game", "seen", {})
	seen = s if s is Dictionary else {}
	var bs = cfg.get_value("game", "beaten_seen", [])
	beaten_seen = bs if bs is Array else []
	cells_used = int(cfg.get_value("game", "cells_used", 0))
	_primed = bool(cfg.get_value("game", "primed", false))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_path)
	cfg.set_value("game", "pieces", pieces)
	cfg.set_value("game", "build", build)
	cfg.set_value("game", "seen", seen)
	cfg.set_value("game", "beaten_seen", beaten_seen)
	cfg.set_value("game", "cells_used", cells_used)
	cfg.set_value("game", "primed", _primed)
	cfg.save(_path)
