extends GutTest
## Look Busy's Friday: reviews, Theo, payout and promotion.

const GREAT := {"genre": "COMEDY", "mechanic": "SLOT REELS", "art": "CASINO NEON", "sound": "DING DING", "character": "KEV"}


func test_a_great_game_beats_theo_and_promotes() -> void:
	var r := ShipDay.review(GREAT, {}, 1, 1)
	assert_true(r.shipped)
	assert_eq(r.press.size(), ShipDay.OUTLETS.size())
	assert_gt(r.press_avg, ShipDay.PROMOTE_AT)
	assert_true(r.beat_theo)
	assert_true(r.promoted)
	assert_gt(r.tokens, ShipDay.BEAT_THEO_TOKENS)
	assert_eq(r.tickets, r.score * ShipDay.TICKETS_PER_SCORE)
	assert_eq(r.theo.title, ShipDay.THEO[0][0])


func test_nothing_shipped_is_zero_and_no_promotion() -> void:
	var r := ShipDay.review({}, {"kev": "lookout"}, 1, 1)
	assert_false(r.shipped)
	assert_eq(r.press_avg, 0.0)
	assert_false(r.promoted)
	assert_eq(r.crew, [], "nobody reviews nothing")


func test_a_thin_game_misses() -> void:
	var r := ShipDay.review({"genre": "PUZZLE"}, {}, 1, 1)
	assert_lt(r.press_avg, ShipDay.PROMOTE_AT)
	assert_false(r.promoted)


func test_higher_floors_expect_more() -> void:
	var low := ShipDay.review({"genre": "COMEDY", "mechanic": "PADDLES"}, {}, 1, 3)
	var high := ShipDay.review({"genre": "COMEDY", "mechanic": "PADDLES"}, {}, 3, 3)
	assert_gt(low.press_avg, high.press_avg)
	assert_gt(float(ShipDay.THEO[2][1]), float(ShipDay.THEO[0][1]), "Theo gets better too")


func test_crew_reviews_lean_on_their_role_and_theo_never_reviews() -> void:
	var r := ShipDay.review(GREAT, {"gloria": "collaborator", "bernie": "snitch", "theo": "lookout"}, 2, 1)
	var by := {}
	for c in r.crew:
		by[c.who] = c.score
	assert_false(by.has("THEO"))
	assert_gt(by.GLORIA, by.BERNIE)


func test_reviews_are_steady_for_the_same_week() -> void:
	assert_eq(ShipDay.review(GREAT, {}, 1, 4), ShipDay.review(GREAT, {}, 1, 4))


func test_workday_remembers_what_shipped() -> void:
	var path := "user://test_ship_wd.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var w := Workday.new(path)
	w.record_ship(ShipDay.review(GREAT, {}, 1, 1))
	var again := Workday.new(path)
	assert_eq(again.shipped.size(), 1)
	assert_true(bool(again.shipped[0].promoted))
