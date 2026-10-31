class_name DaleStory
extends RefCounted
## Dale, the coworker in the office: which conversation comes next, and what
## he remembers. Chapters (data/dale_lines.gd) unlock from the stats every
## office game writes to the shared save (user://office_relics.cfg). Pure
## rules, no scenes; Dale's own memory lives in user://dale.cfg.

const SAVE_PATH := "user://dale.cfg"
const SAVE_VERSION := 1
const RELICS_PATH := "user://office_relics.cfg"

## Chapter ids you've finished, in order.
var done: Array[String] = []
## How much Dale trusts you (goes up with kind answers).
var trust := 0
## The stats as they were the last time you talked, so he can notice news.
var seen := {}

var _path: String
var _rng := RandomNumberGenerator.new()


func _init(save_path := SAVE_PATH, rng_seed := -1) -> void:
	_path = save_path
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	load_save()


## The shared office stats ({"comedy_sets": 3, ...}), or {} if there's no save.
static func read_stats(path := RELICS_PATH) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return {}
	var s = cfg.get_value("stats", "all", {})
	return s if s is Dictionary else {}


static func unlocked(chapter: Dictionary, stats: Dictionary) -> bool:
	var need: Dictionary = chapter.get("need", {})
	if need.is_empty():
		return true
	var any: bool = chapter.get("any", false)
	for key in need:
		var ok := int(stats.get(key, 0)) >= int(need[key])
		if any and ok:
			return true
		if not any and not ok:
			return false
	return not any


## The first chapter you haven't finished, or {} when the story's over.
func next_chapter() -> Dictionary:
	for ch in DaleLines.CHAPTERS:
		if not done.has(ch.id):
			return ch
	return {}


## Is a new chapter waiting for you right now?
func has_news(stats: Dictionary) -> bool:
	var ch := next_chapter()
	return not ch.is_empty() and unlocked(ch, stats)


## "FILE 2/7" for the talk box.
func file_label() -> String:
	return "FILE %d/%d" % [mini(done.size() + 1, DaleLines.CHAPTERS.size()), DaleLines.CHAPTERS.size()]


## The next conversation: {id, title, steps}. id is "" when it's only small
## talk (a locked chapter's hint, or chatter after the finale).
func next_talk(stats: Dictionary) -> Dictionary:
	var steps: Array = []
	var react := _reaction(stats)
	if react != "":
		steps.append({"dale": react})
	var ch := next_chapter()
	if ch.is_empty():
		steps.append({"dale": _pick(DaleLines.AFTER)})
		return {"id": "", "title": "", "steps": steps}
	if unlocked(ch, stats):
		steps.append_array(ch.steps)
		return {"id": ch.id, "title": ch.title, "steps": steps}
	if react == "":
		steps.append({"dale": _pick(DaleLines.SMALL_TALK)})
	steps.append({"dale": ch.hint})
	return {"id": "", "title": "", "steps": steps}


func add_trust(n: int) -> void:
	trust += n


## A conversation ran to the end: remember it and the stats you had.
func finish(id: String, stats: Dictionary) -> void:
	if id != "" and not done.has(id):
		done.append(id)
	seen = stats.duplicate()
	save()


func _reaction(stats: Dictionary) -> String:
	if seen.is_empty():
		return ""
	for key in DaleLines.REACT:
		if int(stats.get(key, 0)) > int(seen.get(key, 0)):
			return _pick(DaleLines.REACT[key])
	return ""


func _pick(lines: Array) -> String:
	return lines[_rng.randi_range(0, lines.size() - 1)]


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	done.clear()
	for id in cfg.get_value("story", "done", []):
		done.append(str(id))
	trust = int(cfg.get_value("story", "trust", 0))
	var s = cfg.get_value("story", "seen", {})
	seen = s if s is Dictionary else {}


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", SAVE_VERSION)
	cfg.set_value("story", "done", Array(done))
	cfg.set_value("story", "trust", trust)
	cfg.set_value("story", "seen", seen)
	cfg.save(_path)
