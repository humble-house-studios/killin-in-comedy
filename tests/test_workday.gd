extends GutTest
## Look Busy's workday: the clock, the boss's schedule and route, suspicion,
## strikes up to getting fired, and the week.

const PATH := "user://test_look_busy.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_clock_reads_like_an_office_clock() -> void:
	var w := Workday.new(PATH)
	assert_eq(w.clock_text(), "MON 9:00 AM")
	w.minutes = 200.0
	assert_eq(w.clock_text(), "MON 12:20 PM")
	w.day = 4
	w.minutes = 479.0
	assert_eq(w.clock_text(), "FRI 4:59 PM")


func test_a_day_takes_day_seconds_and_ends_at_five() -> void:
	var w := Workday.new(PATH)
	var ended := false
	var visits := 0
	for i in int(Workday.DAY_SECONDS) + 2:
		for ev in w.tick(1.0):
			if ev.type == "day_end":
				ended = true
			elif ev.type == "visit":
				visits += 1
	assert_true(ended)
	assert_true(w.day_over())
	assert_eq(visits, Workday.visits(w.boss()).size(), "every visit fires once")
	assert_eq(w.tick(1.0), [], "the clock waits at 5 PM")


func test_visits_are_fixed_and_skip_lunch() -> void:
	var marge := Workday.boss_for(1)
	assert_eq(Workday.visits(marge), [20.0, 110.0, 290.0, 380.0, 470.0], "9:20, 10:50, 1:50, 3:20, 4:50")
	for b in BusyLines.BOSSES:
		for t in Workday.visits(b):
			assert_false(t >= Workday.LUNCH[0] and t < Workday.LUNCH[1], "%s skips lunch" % b.id)
	assert_eq(Workday.boss_for(2).kind, "call", "floor 2 works from home")
	assert_eq(Workday.boss_for(99).id, Workday.boss_for(BusyLines.FLOORS).id)


func test_patrol_walks_the_route_and_stops_at_your_desk() -> void:
	var route: Array = BusyLines.ROUTE
	var start := Workday.patrol_at(route, 1.0, 0.0)
	assert_eq(start.pos, route[0].p)
	var total := Workday.route_time(route, 1.0)
	assert_true(Workday.patrol_at(route, 1.0, total + 0.1).done)
	var saw_desk := false
	var t := 0.0
	while t < total:
		var pa := Workday.patrol_at(route, 1.0, t)
		if pa.desk:
			saw_desk = true
			assert_almost_eq(pa.pos.distance_to(route[3].p), 0.0, 0.001)
		t += 0.1
	assert_true(saw_desk, "stops at your desk")
	# Halfway down the first leg, facing the way they walk (toward -z).
	var mid := Workday.patrol_at(route, 1.0, route[0].p.distance_to(route[1].p) * 0.5)
	assert_almost_eq(absf(mid.yaw), PI, 0.01)


func test_sight_cone() -> void:
	var at := Vector2.ZERO
	assert_true(Workday.sees(at, 0.0, Vector2(0, 3), 6.0, 55.0), "straight ahead (+z)")
	assert_false(Workday.sees(at, 0.0, Vector2(0, -3), 6.0, 55.0), "behind")
	assert_false(Workday.sees(at, 0.0, Vector2(0, 7), 6.0, 55.0), "too far")
	assert_true(Workday.sees(at, 0.0, Vector2(0, -0.8), 6.0, 55.0), "right next to them")
	assert_true(Workday.sees(at, PI / 2, Vector2(3, 0.5), 6.0, 55.0), "turned to +x")


func test_suspicion_strikes_then_fired() -> void:
	var w := Workday.new(PATH)
	var levels: Array = []
	for i in 2000:
		var level := w.watch(0.1, "slacking", true, true)
		if level != "":
			levels.append(level)
			w.tick(Workday.GRACE + 0.1)  # let the grace run out
		if w.fired:
			break
	assert_eq(levels, ["warning", "writeup", "fired"])
	assert_true(w.fired)
	assert_eq(w.watch(10.0, "slacking", true, true), "", "nothing after fired")


func test_working_cools_and_unseen_decays() -> void:
	var w := Workday.new(PATH)
	w.suspicion = 50.0
	w.watch(1.0, "working", true, true)
	assert_lt(w.suspicion, 50.0, "fake work while watched")
	var s := w.suspicion
	w.watch(1.0, "slacking", false, true)
	assert_lt(w.suspicion, s, "not seen: it fades")
	w.suspicion = 0.0
	w.watch(1.0, "idle", true, true)
	assert_gt(w.suspicion, 0.0, "standing around while watched")


func test_grace_after_a_strike() -> void:
	var w := Workday.new(PATH)
	assert_eq(w.add(150.0), "warning")
	assert_true(w.in_grace())
	assert_eq(w.add(150.0), "", "no second strike right away")
	w.watch(1.0, "slacking", true, true)
	assert_eq(w.suspicion, 0.0)


func test_week_and_start_over() -> void:
	var w := Workday.new(PATH)
	for d in 4:
		assert_true(w.next_day())
	assert_true(w.is_friday())
	assert_false(w.next_day(), "Friday ends the week")
	w.strike()
	w.new_week(true)
	assert_eq(w.floor_i, 2)
	assert_eq(w.day, 0)
	assert_eq(w.strikes, 0)
	assert_eq(w.best_floor, 2)
	w.fired = true
	w.start_over()
	assert_eq(w.floor_i, 1)
	assert_eq(w.week, 1)
	assert_false(w.fired)
	assert_eq(w.best_floor, 2, "best floor stays")
	assert_eq(w.runs, 2)


func test_saves() -> void:
	var w := Workday.new(PATH)
	w.minutes = 123.0
	w.strike()
	w.next_day()
	w.minutes = 77.0
	w.save()
	var again := Workday.new(PATH)
	assert_eq(again.day, 1)
	assert_eq(again.strikes, 1)
	assert_almost_eq(again.minutes, 77.0, 0.01)
