extends GutTest
## Look Busy's coworkers: trust unlocks lookout and collaborator, burning
## someone makes a snitch, warm replies make up; the workday cues them.

const CREW := "user://test_busy_crew.cfg"
const DAY := "user://test_busy_day.cfg"
const BUSY := {"plays": 0, "items": [], "beaten": 0, "busy": true}


func before_each() -> void:
	for p in [CREW, DAY]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _stance(id: String, which: String) -> Dictionary:
	var p := Coworkers.person(id)
	return {"kind": "stance", "stance": p[which]}


func test_every_coworker_has_a_side_project_and_lines() -> void:
	for id in CoworkerLines.ORDER:
		var b: Dictionary = CoworkerLines.BUSY.get(id, {})
		assert_false(b.is_empty(), id)
		assert_true(b.side.pieces.size() >= 1, "%s's side project gives pieces" % id)
		for key in ["lookout", "cover", "snitch"]:
			assert_true(str(b.get(key, "")).length() > 0 and str(b[key]).length() <= 110, "%s %s line" % [id, key])
		assert_true(Coworkers.person(id).rewards[1].has("secret"), "%s has a secret" % id)


func test_trust_unlocks_roles() -> void:
	var c := Coworkers.new(CREW, 1)
	assert_eq(c.role("kev"), "")
	var out := c.choose("kev", _stance("kev", "loves"), BUSY)
	assert_eq(c.role("kev"), "lookout")
	assert_eq(out.role, "lookout")
	assert_eq(c.with_role("lookout"), ["kev"] as Array[String])
	out = c.choose("kev", _stance("kev", "loves"), BUSY)
	assert_eq(out.role, "collaborator")
	assert_true(out.lines.has(CoworkerLines.BUSY.kev.side.pitch), "they pitch their side project")
	assert_eq(c.with_role("lookout"), ["kev"] as Array[String], "collaborators keep watch too")


func test_burned_at_zero_trust_becomes_a_snitch_and_can_make_up() -> void:
	var c := Coworkers.new(CREW, 1)
	var out := c.choose("bernie", _stance("bernie", "hates"), BUSY)
	assert_eq(c.role("bernie"), "snitch")
	assert_eq(out.role, "snitch")
	out = c.choose("bernie", _stance("bernie", "loves"), BUSY)
	assert_ne(c.role("bernie"), "snitch", "a warm reply makes up")
	var again := Coworkers.new(CREW, 1)
	assert_false(again.burned.has("bernie"), "saved")


func test_no_burning_without_look_busy_or_with_trust() -> void:
	var c := Coworkers.new(CREW, 1)
	c.choose("theo", _stance("theo", "hates"), {"plays": 0, "items": [], "beaten": 0})
	assert_eq(c.role("theo"), "", "Look Busy off: just closed off, like before")
	c.trust["gloria"] = 2
	c.choose("gloria", _stance("gloria", "hates"), BUSY)
	assert_ne(c.role("gloria"), "snitch", "they still trusted you a little")


func test_workday_cues_lookouts_and_snitches() -> void:
	var w := Workday.new(DAY)
	var seen := {}
	for i in int(Workday.DAY_SECONDS) + 2:
		for ev in w.tick(1.0):
			seen[ev.type] = int(seen.get(ev.type, 0)) + 1
	assert_eq(int(seen.get("soon", 0)), int(seen.get("visit", 0)), "a lookout cue before every visit")
	assert_eq(int(seen.get("snitch", 0)), Workday.SNITCH_AT.size())


func test_a_lookout_covers_once_a_day() -> void:
	var w := Workday.new(DAY)
	assert_true(w.cover())
	assert_false(w.cover())
	w.next_day()
	assert_true(w.cover(), "a new day")
