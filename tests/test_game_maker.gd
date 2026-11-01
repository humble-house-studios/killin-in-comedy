extends GutTest
## Look Busy's own game: pieces from desks, the build, combos, the score, the
## title and trailer, and the week.

const PATH := "user://test_game_maker.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_desks_hand_out_their_genre_first_then_the_rest() -> void:
	var g := GameMaker.new(PATH, 1)
	assert_eq(g.earn("comedy"), {"kind": "genre", "name": "COMEDY"})
	assert_eq(g.earn("comedy").name, "CALLBACKS")
	for i in 5:
		g.earn("comedy")
	assert_eq(g.earn("comedy"), {}, "nothing left from that desk this week")
	assert_eq(g.build.genre, "COMEDY", "the first piece of a kind goes in the build")


func test_every_piece_has_a_kind() -> void:
	for src in GameMaker.SOURCES:
		for p in GameMaker.SOURCES[src]:
			assert_has(GameMaker.KINDS, p[0], p[1])
			assert_eq(GameMaker.kind_of(p[1]), p[0])
	for c in GameMaker.COMBOS:
		for n in c.needs:
			assert_ne(GameMaker.kind_of(n), "", "%s needs a real piece: %s" % [c.name, n])


func test_every_combo_fits_one_build() -> void:
	for c in GameMaker.COMBOS:
		var kinds := {}
		for n in c.needs:
			kinds[GameMaker.kind_of(n)] = true
		assert_eq(kinds.size(), c.needs.size(), "%s needs pieces of different kinds" % c.name)


func test_combos_score_like_jokers() -> void:
	var heckle := GameMaker.score_of({"genre": "COMEDY", "mechanic": "PADDLES"})
	assert_eq(heckle.base, 2 * GameMaker.BASE)
	assert_eq(heckle.score, 2 * GameMaker.BASE + 30, "HECKLE PONG adds 30")
	var laugh := GameMaker.score_of({"genre": "COMEDY", "mechanic": "SLOT REELS"})
	assert_eq(laugh.score, 2 * GameMaker.BASE * 2, "LAUGH SLOTS doubles")
	assert_eq(GameMaker.score_of({"genre": "PUZZLE", "mechanic": "PADDLES"}).combos, [])
	var full := GameMaker.score_of({"genre": "CASINO", "mechanic": "RELICS", "art": "CASINO NEON", "sound": "DING DING", "character": "KEV"})
	assert_true(full.combos.any(func(c): return c.name == "FULL KIT"))
	assert_eq(full.score, int(round((50 + 25) * 1.5 * 1.25)))


func test_build_picks_and_title_and_trailer() -> void:
	var g := GameMaker.new(PATH, 1)
	g.earn("cube")
	g.earn("cube")
	assert_eq(g.title(), "WORLD RECORD BAIT %s" % GameMaker.title_of(g.build).get_slice(" ", 3))
	g.clear_slot("mechanic")
	assert_eq(g.title(), "PUZZLE: THE GAME")
	g.pick("mechanic", "SPEEDRUN")
	g.pick("genre", "SPEEDRUN")
	assert_eq(g.build.genre, "PUZZLE", "a piece only fits its own kind")
	var cards := g.trailer()
	assert_eq(cards[0], "HUMBLE HOUSE GAMES PRESENTS")
	assert_eq(cards.back(), "SHIPS FRIDAY")
	assert_true(cards.has("IN A WORLD OF PUZZLE..."))


func test_desk_wins_from_stat_changes() -> void:
	var g := GameMaker.new(PATH, 1)
	assert_eq(g.desk_wins({"comedy_sets": 3}, ["claw"]), [], "the first look only remembers")
	assert_eq(g.desk_wins({"comedy_sets": 4, "pong_bosses": 1}, ["claw", "ragdoll"]), ["comedy", "pong", "ragdoll"])
	assert_eq(g.desk_wins({"comedy_sets": 4, "pong_bosses": 1}, ["claw", "ragdoll"]), [])
	var again := GameMaker.new(PATH, 1)
	assert_eq(again.desk_wins({"comedy_sets": 5, "pong_bosses": 1}, ["claw", "ragdoll"]), ["comedy"], "remembered across saves")


func test_fake_work_and_collaborators() -> void:
	var g := GameMaker.new(PATH, 1)
	assert_eq(g.cell_wins(GameMaker.CELLS_PER_PIECE - 1), 0)
	assert_eq(g.cell_wins(GameMaker.CELLS_PER_PIECE * 2 + 3), 2)
	assert_eq(g.cell_wins(GameMaker.CELLS_PER_PIECE * 2 + 5), 0)
	var got := g.collaborate(["theo"])
	assert_eq(got.size(), 2)
	assert_true(g.has("COOKING") and g.has("THEO"))
	assert_eq(g.collaborate(["theo"]), [], "no duplicates")


func test_new_week_empties_the_kit() -> void:
	var g := GameMaker.new(PATH, 1)
	g.earn("loot")
	g.new_week()
	assert_eq(g.pieces, [])
	assert_eq(g.build, {})
	var again := GameMaker.new(PATH, 1)
	assert_eq(again.pieces, [])
