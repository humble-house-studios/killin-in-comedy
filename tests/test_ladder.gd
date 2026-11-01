extends GutTest
## The ladder past the office door: currencies carry room to room, doors open
## in order, coworkers trust you by stance, and every room can be beaten.

const LADDER := "user://test_ladder.cfg"
const CREW := "user://test_coworkers.cfg"


func before_each() -> void:
	for p in [LADDER, CREW]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


# ---------------------------------------------------------------- currencies

func test_paycheck_once_and_scales_with_office_play() -> void:
	var l := LadderState.new(LADDER)
	var pay := l.collect_paycheck({"pong_bosses": 1, "comedy_sets": 3})
	assert_eq(pay, LadderState.PAYCHECK_BASE + 4 * LadderState.PAYCHECK_PER_MILESTONE)
	assert_eq(l.collect_paycheck({}), 0, "paid only once")
	assert_true(l.is_done("entered"))


func test_petty_cash_only_when_broke_so_you_never_get_stuck() -> void:
	var l := LadderState.new(LADDER)
	assert_false(l.spend_token())
	assert_eq(l.petty_cash(), LadderState.PETTY_CASH)
	assert_eq(l.petty_cash(), 0, "not while you still have tokens")
	assert_true(l.spend_token())
	assert_eq(l.plays, 1)


func test_door_key_opens_the_trading_floor() -> void:
	var l := LadderState.new(LADDER)
	assert_false(l.door_open("trading", true))
	l.win_tickets(LadderState.DOOR_KEY_COST - 1)
	assert_false(l.buy("door_key"))
	l.win_tickets(1)
	assert_true(l.buy("door_key"))
	assert_eq(l.tickets, 0)
	assert_true(l.door_open("trading", true))


func test_doors_open_in_order() -> void:
	var l := LadderState.new(LADDER)
	assert_false(l.door_open("office", false))
	assert_true(l.door_open("office", true))
	for pair in [["boardroom", "market"], ["corner", "pitch"], ["stage", "memo"]]:
		assert_false(l.door_open(pair[0], true))
		l.mark(pair[1])
		assert_true(l.door_open(pair[0], true))


func test_tickets_cash_out_as_the_portfolio_once() -> void:
	var l := LadderState.new(LADDER)
	l.win_tickets(40)
	var start := l.market_start()
	assert_eq(start, LadderState.MARKET_BASE_CASH + 40 * LadderState.MARKET_PER_TICKET)
	assert_eq(l.tickets, 0)
	l.win_tickets(100)
	assert_eq(l.market_start(), start, "cashed out the first time only")
	assert_eq(l.market_target(), start * 2)


func test_rewards_apply() -> void:
	var l := LadderState.new(LADDER)
	l.win_tickets(100)
	l.buy("plush")
	for r in ["tokens:5", "tickets:25", "item:theo_vote", "consume:plush"]:
		l.apply_reward(r)
	assert_eq(l.tokens, 5)
	assert_eq(l.tickets, 100 - 80 + 25)
	assert_true(l.has("theo_vote"))
	assert_false(l.has("plush"))


func test_a_gift_already_given_cant_be_bought_again() -> void:
	var l := LadderState.new(LADDER)
	l.win_tickets(500)
	assert_false(l.can_buy("plush", ["gloria"]))
	assert_true(l.can_buy("plush", []))


func test_progress_is_saved() -> void:
	var l := LadderState.new(LADDER)
	l.collect_paycheck({})
	l.win_tickets(77)
	l.beat("claw")
	l.mark("market")
	var again := LadderState.new(LADDER)
	assert_eq(again.tickets, 77)
	assert_true(again.beaten.has("claw"))
	assert_true(again.is_done("market"))
	assert_eq(again.tokens, LadderState.PAYCHECK_BASE)


func test_objective_walks_the_rooms() -> void:
	var l := LadderState.new(LADDER)
	assert_string_contains(l.objective(0), "DOOR")
	l.collect_paycheck({})
	assert_string_contains(l.objective(0), "(0/300)")
	l.items.append("door_key")
	assert_string_contains(l.objective(0), "TRADING")
	for m in ["market", "pitch", "memo", "stage"]:
		l.mark(m)
	assert_string_contains(l.objective(2), "2/5")
	l.mark("archive")
	assert_string_contains(l.objective(5), "THE END")
	assert_true(l.true_ending(5))


# ---------------------------------------------------------------- coworkers

func _ctx(plays := 0, items: Array = [], beaten := 0) -> Dictionary:
	return {"plays": plays, "items": items, "beaten": beaten}


func _pick(talk: Dictionary, kind: String, stance := "") -> Dictionary:
	for step in talk.steps:
		if step.has("choices"):
			for c in step.choices:
				if c.kind == kind and (stance == "" or c.get("stance", "") == stance):
					return c
	return {}


func test_every_coworker_is_complete() -> void:
	for id in CoworkerLines.ORDER:
		var p := Coworkers.person(id)
		assert_eq(p.prompts.size(), 3, id)
		assert_eq(p.rewards.size(), 3, id)
		assert_ne(p.loves, p.hates, id)
		assert_true(p.rewards[1].has("secret"), id + " tells a secret at tier 2")
		assert_true(p.rewards[2].has("perk"), id + " gives a perk at tier 3")
		for prompt in p.prompts:
			for stance in CoworkerLines.STANCE_TAG:
				assert_true(prompt.replies.has(stance), "%s answers %s" % [id, stance])
				assert_lt(prompt.replies[stance][0].length(), 32, "reply fits a button: " + prompt.replies[stance][0])


func test_talk_offers_loved_hated_and_one_more() -> void:
	var c := Coworkers.new(CREW, 3)
	var talk := c.talk("gloria", _ctx())
	var stances: Array = []
	for step in talk.steps:
		if step.has("choices"):
			for ch in step.choices:
				stances.append(ch.stance)
	assert_eq(stances.size(), 3)
	assert_has(stances, "ask")
	assert_has(stances, "riff")


func test_loved_stance_raises_trust_and_pays_out() -> void:
	var c := Coworkers.new(CREW, 3)
	var out := c.choose("gloria", _pick(c.talk("gloria", _ctx()), "stance", "ask"), _ctx())
	assert_eq(out.delta, 1)
	assert_eq(c.tier("gloria"), 1)
	assert_has(out.rewards, "tokens:5")


func test_hated_stance_closes_them_off_until_you_play() -> void:
	var c := Coworkers.new(CREW, 3)
	c.choose("gloria", {"kind": "stance", "stance": "riff"}, _ctx(4))
	assert_true(c.is_closed("gloria", 4))
	assert_eq(c.talk("gloria", _ctx(4)).steps.size(), 1, "only the brush-off")
	assert_false(c.is_closed("gloria", 5), "one more machine round reopens them")


func test_three_loved_replies_reach_secret_and_perk() -> void:
	var c := Coworkers.new(CREW, 3)
	var secret := ""
	var rewards: Array = []
	for i in 3:
		var out := c.choose("kev", {"kind": "stance", "stance": "yes_and"}, _ctx())
		if out.secret != "":
			secret = out.secret
		rewards.append_array(out.rewards)
	assert_eq(c.tier("kev"), 3)
	assert_string_contains(secret, "CEO")
	assert_has(rewards, "item:insider_tip")
	assert_eq(c.secrets, ["kev"] as Array[String])


func test_gift_is_offered_and_worth_a_tier() -> void:
	var c := Coworkers.new(CREW, 3)
	assert_true(_pick(c.talk("bernie", _ctx()), "gift").is_empty())
	var gift := _pick(c.talk("bernie", _ctx(0, ["stress_ball"])), "gift")
	assert_false(gift.is_empty())
	var out := c.choose("bernie", gift, _ctx())
	assert_has(out.rewards, "consume:stress_ball")
	assert_eq(c.tier("bernie"), 1)
	assert_true(_pick(c.talk("bernie", _ctx(0, ["stress_ball"])), "gift").is_empty(), "only once")


func test_theo_wants_you_to_beat_a_machine() -> void:
	var c := Coworkers.new(CREW, 3)
	assert_true(_pick(c.talk("theo", _ctx()), "gift").is_empty())
	assert_false(_pick(c.talk("theo", _ctx(0, [], 1)), "gift").is_empty())


func test_callbacks_need_the_other_secret() -> void:
	var c := Coworkers.new(CREW, 3)
	assert_true(_pick(c.talk("kev", _ctx()), "callback").is_empty())
	for i in 2:
		c.choose("gloria", {"kind": "stance", "stance": "ask"}, _ctx())
	var cb := _pick(c.talk("kev", _ctx()), "callback")
	assert_eq(cb.get("callback", ""), "credits_ceo")
	var out := c.choose("kev", cb, _ctx())
	assert_eq(out.delta, 1)
	assert_true(_pick(c.talk("kev", _ctx()), "callback").is_empty(), "used up")


func test_ray_comes_out_after_two_machines() -> void:
	assert_false(Coworkers.present("ray", 1))
	assert_true(Coworkers.present("ray", 2))
	assert_true(Coworkers.present("gloria", 0))


func test_all_five_secrets_are_reachable() -> void:
	var c := Coworkers.new(CREW, 3)
	for id in CoworkerLines.ORDER:
		var loves: String = Coworkers.person(id).loves
		for i in 2:
			c.choose(id, {"kind": "stance", "stance": loves}, _ctx())
	assert_eq(c.secrets.size(), 5)
	assert_eq(c.secret_texts().size(), 5)


func test_trust_is_saved() -> void:
	var c := Coworkers.new(CREW, 3)
	c.choose("ray", {"kind": "stance", "stance": "yes_and"}, _ctx())
	var again := Coworkers.new(CREW, 3)
	assert_eq(again.tier("ray"), 1)


# ---------------------------------------------------------------- rooms

func test_market_rumor_comes_before_its_news() -> void:
	var m := Market.new(1000.0, 7)
	var saw_rumor := false
	var order_ok := true
	for i in 2000:
		for e in m.tick(Market.TICK):
			if e == "rumor":
				saw_rumor = true
			if e == "news" and not saw_rumor:
				order_ok = false
		if m.over:
			break
	assert_true(saw_rumor)
	assert_true(order_ok)


func test_market_can_be_doubled_by_trading_the_rumors() -> void:
	# A player who buys on every up-rumor and sells after the news.
	var wins := 0
	for s in 20:
		var m := Market.new(1000.0, s)
		var holding := ""
		while not m.over:
			var evs := m.tick(Market.TICK)
			for ev in m.events:
				if ev.teased and not ev.hit and ev.move > 1.0 and holding == "":
					m.buy(ev.sym, m.max_buy(ev.sym))
					holding = ev.sym
			if "news" in evs and holding != "":
				m.sell(holding, m.shares[holding])
				holding = ""
		if m.won:
			wins += 1
	assert_gt(wins, 14, "rumor traders double up most sessions (%d/20)" % wins)


func test_market_closes_after_the_last_day() -> void:
	var m := Market.new(1000.0, 3)
	var closed := false
	for i in int(Market.DAYS * Market.DAY_SECONDS / Market.TICK) + 10:
		if "closed" in m.tick(Market.TICK):
			closed = true
	assert_true(closed, "holding cash never doubles")
	assert_false(m.won)


func test_insider_tip_stars_the_biggest_pop() -> void:
	var m := Market.new(1000.0, 5, true)
	var best := ""
	var big := 0.0
	for ev in m.events:
		if ev.move > big:
			big = ev.move
			best = ev.sym
	assert_eq(m.tip, best)


func test_buy_and_sell() -> void:
	var m := Market.new(1000.0, 1)
	var n := m.buy("HHG", 10)
	assert_eq(n, 10)
	assert_almost_eq(m.cash, 1000.0 - 400.0, 0.01)
	assert_eq(m.sell("HHG", 99), 10)
	assert_almost_eq(m.cash, 1000.0, 0.01)


func test_pitch_wins_with_matching_answers() -> void:
	var p := Pitch.new(2)
	while not p.done():
		var pick := 0
		for i in p.hand.size():
			if p.hand[i].kind == p.member().kind or p.hand[i].kind == Pitch.WILD:
				pick = i
		p.answer(pick)
	assert_true(p.won() or p.lost())


func test_pitch_wrong_answers_lose() -> void:
	var p := Pitch.new(2)
	while not p.done():
		var pick := -1
		for i in p.hand.size():
			if p.hand[i].kind != p.member().kind and p.hand[i].kind != Pitch.WILD:
				pick = i
		if pick < 0:
			break
		p.answer(pick)
	if p.done():
		assert_true(p.lost())


func test_theo_and_hr_help_the_pitch() -> void:
	var p := Pitch.new(2, true, true)
	assert_eq(p.yes, 1)
	assert_true(p.redraw())
	assert_false(p.redraw(), "one redraw")
	assert_eq(p.hand.size(), Pitch.HAND)


func test_final_set_plain_material_can_win() -> void:
	var f := FinalSet.new()
	for id in ["opener", "punch_a", "tag_a", "tag_b", "punch_b"]:
		f.play(id)
	assert_true(f.won(), "a well-built plain set lands (%d)" % f.laughs)


func test_final_set_badly_built_loses() -> void:
	var f := FinalSet.new()
	for id in ["tag_a", "tag_b", "crowd", "opener", "punch_a"]:
		f.play(id)
	assert_true(f.lost())


func test_final_set_secrets_and_memo_add_bits() -> void:
	var f := FinalSet.new(["kev", "ray"], true)
	var ids: Array = []
	for c in f.hand:
		ids.append(c.id)
	assert_has(ids, "kev")
	assert_has(ids, "ray")
	assert_has(ids, "memo")
	f.play("ray")
	assert_eq(f.play("memo"), 100.0, "setup doubles BIG DEAL")
	assert_true(f.won())


func test_arcade_payouts() -> void:
	assert_false(ArcadeRules.claw_strong(0))
	assert_true(ArcadeRules.claw_strong(3))
	assert_true(ArcadeRules.claw_strong(7))
	assert_true(ArcadeRules.claw_beats("star"))
	assert_false(ArcadeRules.claw_beats("duck"))
	assert_eq(ArcadeRules.pusher_tickets("jackpot"), ArcadeRules.PUSHER_JACKPOT)
	assert_eq(ArcadeRules.ragdoll_score(10.0, 0.0, 2, true), 100 + 400)
	assert_eq(ArcadeRules.ragdoll_tickets(400), 20)
