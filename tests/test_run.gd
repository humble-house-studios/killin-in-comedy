extends GutTest
## A run: line-up order, rewards growing the deck, and reaching the boss.


func test_lineup_starts_easy_and_ends_with_the_boss() -> void:
	var run := Run.new(3)
	assert_eq(run.lineup.size(), 4)
	assert_eq(run.lineup[0].id, "open_mic")
	assert_true(run.lineup[-1].is_boss)
	assert_true(run.is_final_set() == false)


func test_reward_adds_to_deck_and_advances() -> void:
	var run := Run.new(3)
	var pick := run.reward_choices()[0]
	run.finish_set(pick)
	assert_eq(run.deck.size(), 11)
	assert_true(run.deck.has(pick))
	assert_eq(run.set_index, 1)


func test_skipping_a_reward_keeps_the_deck() -> void:
	var run := Run.new(3)
	run.finish_set()
	assert_eq(run.deck.size(), 10)


func test_new_set_uses_the_run_deck() -> void:
	var run := Run.new(3)
	run.finish_set(CardLibrary.card("mic_drop"))
	var b := run.start_set()
	assert_eq(b.audience, run.lineup[1])
	assert_eq(b.hand.size() + b.draw_pile.size(), 11)


func test_run_completes_after_the_boss() -> void:
	var run := Run.new(3)
	for i in run.lineup.size():
		assert_false(run.is_complete())
		run.finish_set()
	assert_true(run.is_complete())


## Balance guard: a decent player (the autopilot, taking the best-looking
## reward) should usually clear the regulars and sometimes beat the boss.
func test_runs_are_winnable_but_not_free() -> void:
	var boss_wins := 0
	var reached_boss := 0
	for s in 60:
		var run := Run.new(s)
		while not run.is_complete():
			if Autopilot.play_set(run.start_set()) != Battle.Result.WON:
				break
			run.finish_set(Autopilot.pick_reward(run.reward_choices()))
		if run.set_index >= run.lineup.size() - 1:
			reached_boss += 1
		if run.is_complete():
			boss_wins += 1
	gut.p("reached boss %d/60, beat boss %d/60" % [reached_boss, boss_wins])
	assert_gte(reached_boss, 40)
	assert_between(boss_wins, 6, 54)
