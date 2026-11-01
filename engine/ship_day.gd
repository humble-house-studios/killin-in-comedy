class_name ShipDay
extends RefCounted
## Look Busy's Friday (docs/look-busy.md): you ship your game (engine/
## game_maker.gd's build); the press and your coworkers review it; Theo, the
## rival, ships his; the reviews pay out (ladder tokens and tickets); a good
## week (press average at least PROMOTE_AT and better than Theo's) promotes
## you to the next floor and its new boss. Pure rules, no scenes.

## Press average needed to be promoted (and Theo's to beat).
const PROMOTE_AT := 6.0
## The score that reads as a 7/10, by floor: each floor expects more.
const PAR := [60.0, 100.0, 150.0]
const OUTLETS := ["PIXEL GAZETTE", "GAMESPOTTY", "INDIE GAMES MONTHLY"]
## Theo ships Knife Fight Kitchen, a little better every floor: [title, score /10].
const THEO := [["KNIFE FIGHT KITCHEN", 5.8], ["KNIFE FIGHT KITCHEN 2: SECONDS", 6.6], ["KNIFE FIGHT KITCHEN III: SOUS VIDE", 7.4]]
## What a coworker's role adds to their review.
const ROLE_BIAS := {"collaborator": 2.0, "lookout": 1.0, "": 0.0, "snitch": -3.0}
const TOKENS_PER_POINT := 4
const BEAT_THEO_TOKENS := 15
const TICKETS_PER_SCORE := 1

const PRESS_QUOTES := {
	"rave": ["\"%s is the game of the year. Of this week, anyway.\"", "\"We stopped working to play %s. Our boss noticed.\"", "\"%s: a triumph. Cried twice.\""],
	"mixed": ["\"%s has ideas. Some of them work.\"", "\"Solid. %s won't change your life, but it's a nice Friday.\"", "\"%s is fine. We've played worse. Recently.\""],
	"pan": ["\"%s feels like it was made on company time.\"", "\"We could not finish %s. We did not want to.\"", "\"%s: technically a game.\""],
	"none": ["\"Nothing shipped. We waited by the inbox all day.\"", "\"No game this week. Bold.\"", "\"Did they forget it was Friday?\""],
}
const CREW_QUOTES := {
	"collaborator": "I'm biased. I helped. Ten out of ten.",
	"lookout": "I kept watch while you made this. Worth it.",
	"": "Played it at lunch. Not bad, new hire.",
	"snitch": "I showed it to the boss. On purpose.",
}


## Your week's reviews. build: kind -> piece (GameMaker.build). crew: {id:
## role} for coworkers you've met (Theo is the rival, so he doesn't review).
## Returns {title, score, press: [{who, score, quote}], crew: [...],
## press_avg, theo: {title, score}, beat_theo, promoted, tokens, tickets}.
static func review(build: Dictionary, crew: Dictionary, floor_n: int, week: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([week, floor_n, build])
	var shipped := not build.is_empty()
	var s := GameMaker.score_of(build) if shipped else {"score": 0}
	var title := GameMaker.title_of(build) if shipped else "NOTHING"
	var par: float = PAR[clampi(floor_n, 1, PAR.size()) - 1]
	var quality := clampf(float(s.score) / par * 7.0, 0.0, 10.0) if shipped else 0.0
	var press: Array = []
	var total := 0.0
	var pick := rng.randi_range(0, 2)
	for outlet in OUTLETS:
		var sc := clampf(snappedf(quality + rng.randf_range(-1.2, 1.2), 0.1), 0.0, 10.0) if shipped else 0.0
		total += sc
		var bracket := "none" if not shipped else ("rave" if sc >= 8.0 else ("mixed" if sc >= 5.0 else "pan"))
		var lines: Array = PRESS_QUOTES[bracket]
		# Each outlet a different line.
		var line: String = lines[(pick + press.size()) % lines.size()]
		press.append({"who": outlet, "score": sc, "quote": line % title if line.contains("%s") else line})
	var press_avg := snappedf(total / OUTLETS.size(), 0.1)
	var reviews: Array = []
	if shipped:
		for id in CoworkerLines.ORDER:
			if id == "theo" or not crew.has(id):
				continue
			var role: String = crew[id]
			var sc := clampf(snappedf(quality + float(ROLE_BIAS.get(role, 0.0)) + rng.randf_range(-0.5, 0.5), 0.1), 0.0, 10.0)
			reviews.append({"who": Coworkers.person(id).name, "score": sc, "quote": CREW_QUOTES.get(role, CREW_QUOTES[""])})
	var theo_spec: Array = THEO[clampi(floor_n, 1, THEO.size()) - 1]
	var theo_score := clampf(snappedf(float(theo_spec[1]) + rng.randf_range(-0.4, 0.4), 0.1), 0.0, 10.0)
	var beat := shipped and press_avg > theo_score
	var promoted := beat and press_avg >= PROMOTE_AT
	var tokens := int(round(press_avg * TOKENS_PER_POINT)) + (BEAT_THEO_TOKENS if beat else 0)
	return {
		"title": title, "score": int(s.score), "shipped": shipped, "press": press, "crew": reviews,
		"press_avg": press_avg, "theo": {"title": theo_spec[0], "score": theo_score},
		"beat_theo": beat, "promoted": promoted, "tokens": tokens, "tickets": int(s.score) * TICKETS_PER_SCORE,
	}


## "8.3" style.
static func fmt(score: float) -> String:
	return "%.1f" % score
