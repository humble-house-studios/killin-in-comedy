extends GutTest
## The goal marker: one target at a time, following the TO-DO chain from
## Dale's first chapter to the true ending, routed room by room.

const DALE := "user://test_goal_dale.cfg"
const LADDER := "user://test_goal_ladder.cfg"
const CREW := "user://test_goal_crew.cfg"

var story: DaleStory
var ladder: LadderState
var crew: Coworkers


func before_each() -> void:
	for p in [DALE, LADDER, CREW]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	story = DaleStory.new(DALE, 1)
	ladder = LadderState.new(LADDER)
	crew = Coworkers.new(CREW, 1)


func _goal(stats := {}) -> String:
	return GoalTarget.goal(story, stats, ladder, crew)


func _point(here: String, stats := {}, dist := {}) -> String:
	return GoalTarget.point(story, stats, ladder, crew, here, dist)


func _finish_story() -> void:
	for ch in DaleLines.CHAPTERS:
		story.finish(ch.id, {})


func _meet_everyone() -> void:
	for id in CoworkerLines.ORDER:
		crew.met.append(id)
		crew.trust[id] = Coworkers.MAX_TIER
		crew.seen_at[id] = 999


# ---------------------------------------------------------------- the office

func test_new_game_points_at_dale() -> void:
	assert_eq(_goal(), "dale")
	assert_eq(_point("office"), "dale")


func test_each_locked_chapter_points_at_its_desk() -> void:
	var desks := {"cube": "pong", "standup": "cube", "slots": "comedy", "proof": "loot", "ladder": "proof"}
	for ch in DaleLines.CHAPTERS:
		if ch.id == "pong":
			story.finish(ch.id, {})
			continue
		assert_eq(_goal(), desks[ch.id], "chapter %s, still locked" % ch.id)
		# Once its stat is in, Dale has news: talk to him.
		assert_eq(_goal(ch.need), "dale", "chapter %s unlocked" % ch.id)
		story.finish(ch.id, ch.need)


func test_partial_progress_still_points_at_the_desk() -> void:
	story.finish("pong", {})
	story.finish("cube", {})
	story.finish("standup", {})
	assert_eq(_goal({"comedy_sets": 1}), "comedy", "1 of 2 sets")
	assert_eq(_goal({"comedy_sets": 2}), "dale")


func test_story_done_points_at_the_office_door() -> void:
	_finish_story()
	assert_eq(_goal(), "door_office")
	assert_eq(_point("office"), "door_office")


# ---------------------------------------------------------------- the arcade

func test_short_on_tickets_points_at_the_nearest_unbeaten_cabinet() -> void:
	_finish_story()
	ladder.collect_paycheck({})
	assert_eq(_goal(), "cabinet")
	var dist := {"claw": 4.0, "pusher": 1.5, "ragdoll": 3.0}
	assert_eq(_point("arcade", {}, dist), "pusher")
	ladder.beat("pusher")
	assert_eq(_point("arcade", {}, dist), "ragdoll", "skips beaten ones")
	ladder.beat("ragdoll")
	ladder.beat("claw")
	assert_eq(_point("arcade", {}, dist), "pusher", "all beaten: nearest anyway")


func test_enough_tickets_points_at_the_prize_counter() -> void:
	_finish_story()
	ladder.collect_paycheck({})
	ladder.win_tickets(LadderState.DOOR_KEY_COST)
	assert_eq(_goal(), "counter")
	assert_eq(_point("arcade"), "counter")


# ---------------------------------------------------------------- up the ladder

func test_the_ladder_rooms_in_order() -> void:
	_finish_story()
	ladder.collect_paycheck({})
	ladder.items.append(LadderState.DOOR_KEY)
	assert_eq(_goal(), "trading")
	ladder.mark("market")
	assert_eq(_goal(), "pitch")
	ladder.mark("pitch")
	assert_eq(_goal(), "memo")
	ladder.mark("memo")
	assert_eq(_goal(), "stage")


func test_after_the_stage_the_archive_needs_rays_key() -> void:
	_finish_story()
	ladder.collect_paycheck({})
	ladder.items.append(LadderState.DOOR_KEY)
	for m in ["market", "pitch", "memo", "stage"]:
		ladder.mark(m)
	assert_eq(_goal(), "cabinet", "Ray's not out until two machines are beaten")
	ladder.beat("claw")
	ladder.beat("pusher")
	assert_eq(_goal(), "ray", "Ray's out and has news")
	ladder.items.append("archive_key")
	assert_eq(_goal(), "door_archive")
	ladder.mark("archive")
	_meet_everyone()
	assert_eq(_goal(), "", "all talked out, short on secrets: nothing to point at")
	crew.seen_at["kev"] = -1
	crew.trust["kev"] = 1
	assert_eq(_goal(), "kev", "a coworker with more to say")


func test_true_ending_points_at_dale_in_the_crowd_then_nothing() -> void:
	_finish_story()
	ladder.collect_paycheck({})
	for m in ["market", "pitch", "memo", "stage", "archive"]:
		ladder.mark(m)
	ladder.items.append(LadderState.DOOR_KEY)
	_meet_everyone()
	for i in LadderState.SECRETS_TOTAL:
		crew.secrets.append("s%d" % i)
	assert_eq(_goal(), "dale_stage")
	ladder.mark("true_end")
	assert_eq(_goal(), "")


# ---------------------------------------------------------------- routing

func test_hops_follow_the_doors() -> void:
	assert_eq(GoalTarget.hop("stage", "office"), "door_office")
	assert_eq(GoalTarget.hop("stage", "arcade"), "door_trading")
	assert_eq(GoalTarget.hop("stage", "trading"), "door_boardroom")
	assert_eq(GoalTarget.hop("stage", "boardroom"), "door_corner")
	assert_eq(GoalTarget.hop("stage", "corner"), "door_stage")
	assert_eq(GoalTarget.hop("stage", "stage"), "stage")
	assert_eq(GoalTarget.hop("dale", "trading"), "door_trading", "back the way you came")
	assert_eq(GoalTarget.hop("dale", "arcade"), "door_office")
	assert_eq(GoalTarget.hop("counter", "archive"), "door_archive", "out of the basement")
	assert_eq(GoalTarget.hop("stage", "archive"), "door_archive")


func test_in_another_room_points_at_the_next_door() -> void:
	_finish_story()
	ladder.collect_paycheck({})
	ladder.items.append(LadderState.DOOR_KEY)
	for m in ["market", "pitch"]:
		ladder.mark(m)
	assert_eq(_point("office"), "door_office")
	assert_eq(_point("arcade"), "door_trading")
	assert_eq(_point("trading"), "door_boardroom")
	assert_eq(_point("boardroom"), "door_corner")
	assert_eq(_point("corner"), "memo")
	assert_eq(_point("archive"), "door_archive")


func test_a_locked_door_on_the_way_points_at_what_opens_it() -> void:
	var open := {"door_office": true, "door_trading": false, "door_boardroom": false}
	var unlocks := {"door_trading": "counter", "door_boardroom": "trading"}
	assert_eq(GoalTarget.route("stage", "arcade", open, unlocks), "counter")
	assert_eq(GoalTarget.route("stage", "office", open, unlocks), "door_office", "the unlocker is a room ahead")
	open.door_trading = true
	assert_eq(GoalTarget.route("stage", "trading", open, unlocks), "trading", "boardroom shut: the terminal")
	assert_eq(GoalTarget.route("pitch", "arcade", open, unlocks), "door_trading")
	assert_eq(GoalTarget.route("", "arcade", open, unlocks), "")


func test_locked_trading_door_from_the_office_routes_to_the_arcade_first() -> void:
	_finish_story()
	ladder.collect_paycheck({})
	ladder.win_tickets(LadderState.DOOR_KEY_COST)
	assert_eq(_point("office"), "door_office")
	assert_eq(_point("arcade"), "counter")


func test_unlockers() -> void:
	assert_eq(GoalTarget.unlock("door_boardroom", story, {}, ladder, crew), "trading")
	assert_eq(GoalTarget.unlock("door_corner", story, {}, ladder, crew), "pitch")
	assert_eq(GoalTarget.unlock("door_stage", story, {}, ladder, crew), "memo")
	assert_eq(GoalTarget.unlock("door_trading", story, {}, ladder, crew), "cabinet")
	assert_eq(GoalTarget.unlock("door_office", story, {}, ladder, crew), "dale")


func test_every_key_has_a_room() -> void:
	for key in ["dale", "pong", "cube", "comedy", "proof", "loot", "door_office", "claw", "pusher",
			"ragdoll", "counter", "trading", "pitch", "memo", "stage", "dale_stage", "door_archive", "ray"]:
		assert_ne(GoalTarget.room_of(key), "", key)
