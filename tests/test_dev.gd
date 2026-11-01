extends GutTest
## Dev tools: the shortcuts unlock exactly what playing would have.

const DALE := "user://test_dev_dale.cfg"
const LADDER := "user://test_dev_ladder.cfg"
const CREW := "user://test_dev_coworkers.cfg"


func before_each() -> void:
	for p in [DALE, LADDER, CREW]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_missing_tops_up_only_what_a_chapter_still_needs() -> void:
	var comedy: Dictionary = DaleLines.CHAPTERS.filter(func(c): return c.need.has("comedy_sets"))[0]
	assert_eq(Dev.missing(comedy, {}), {"comedy_sets": 2})
	assert_eq(Dev.missing(comedy, {"comedy_sets": 1}), {"comedy_sets": 1})
	assert_eq(Dev.missing(comedy, {"comedy_sets": 5}), {})
	assert_eq(Dev.missing(DaleLines.CHAPTERS[0], {}), {}, "the first chapter needs nothing")


func test_meeting_every_goal_walks_dale_to_the_door() -> void:
	var d := DaleStory.new(DALE, 1)
	var stats := {}
	while not d.next_chapter().is_empty():
		var ch := d.next_chapter()
		var add := Dev.missing(ch, stats)
		for k in add:
			stats[k] = int(stats.get(k, 0)) + add[k]
		assert_true(DaleStory.unlocked(ch, stats), "%s unlocks once its goal is met" % ch.id)
		d.finish(ch.id, stats)
	assert_eq(d.done.size(), DaleLines.CHAPTERS.size())
	assert_eq(d.objective(stats), "GO THROUGH THE DOOR BEHIND YOU")


func test_max_coworkers_pays_every_tier_once() -> void:
	var crew := Coworkers.new(CREW, 1)
	var state := LadderState.new(LADDER)
	Dev.max_coworkers(crew, state)
	assert_eq(crew.secrets.size(), LadderState.SECRETS_TOTAL)
	for id in CoworkerLines.ORDER:
		assert_eq(crew.tier(id), Coworkers.MAX_TIER, id)
	for perk in ["gloria_eye", "insider_tip", "hr_badge", "style", "theo_vote", "archive_key"]:
		assert_true(state.has(perk), perk)
	var tokens := state.tokens
	var tickets := state.tickets
	assert_gt(tokens, 0)
	Dev.max_coworkers(crew, state)
	assert_eq(state.tokens, tokens, "already maxed: nothing more paid")
	assert_eq(state.tickets, tickets)
	assert_eq(Coworkers.new(CREW, 1).secrets.size(), LadderState.SECRETS_TOTAL, "saved")


func test_open_ladder_unlocks_every_door() -> void:
	var state := LadderState.new(LADDER)
	Dev.open_ladder(state)
	for door in ["office", "trading", "archive", "boardroom", "corner", "stage"]:
		assert_true(state.door_open(door, true), door)
	assert_false(state.door_open("office", false), "the office door is still Dale's")
	Dev.beat_machines(state)
	assert_eq(state.beaten.size(), 3)
	assert_true(Coworkers.present("ray", state.beaten.size()), "Ray is out")


func test_dev_win_ends_the_set_as_a_win() -> void:
	var a: AudienceData = CardLibrary.audiences().values()[0]
	var b := Battle.new(a, CardLibrary.starter_deck(RandomNumberGenerator.new()), 1)
	b.dev_win()
	assert_eq(b.result, Battle.Result.WON)
	assert_gte(b.laughs, b.laughs_needed)
	assert_true(b.pop_events().has("won"))
	b.dev_win()
	assert_true(b.pop_events().is_empty(), "only once")


func test_dev_boost_fills_mic_heat_and_clock() -> void:
	var a: AudienceData = CardLibrary.audiences().values()[0]
	var b := Battle.new(a, CardLibrary.starter_deck(RandomNumberGenerator.new()), 1)
	var before := b.time_left
	b.dev_boost(30.0)
	assert_eq(b.mic, Balance.MIC_MAX)
	assert_eq(b.crowd_energy, float(Balance.MAX_CROWD_ENERGY))
	assert_eq(b.time_left, before + 30.0)
	assert_eq(b.set_length, before + 30.0, "the clock bar stays in range")
