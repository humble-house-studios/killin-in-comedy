class_name Crew
## Your crew, hired between sets. Each one helps every set but takes a cut of
## every bit you land (like the consultants in a trading sim).

const ALL := {
	"manager": {
		"title": "The Manager",
		"perk": "Always see the crowd's next two moves.",
		"cut": 0.10,
	},
	"writer": {
		"title": "The Writer",
		"perk": "+1 card in hand.",
		"cut": 0.10,
	},
	"booker": {
		"title": "The Booker",
		"perk": "+15 seconds on every set.",
		"cut": 0.15,
	},
	"hype": {
		"title": "The Hype Guy",
		"perk": "Start every set with +5 Heat.",
		"cut": 0.10,
	},
	"lawyer": {
		"title": "The Lawyer",
		"perk": "Heckles only cut your bit by a quarter.",
		"cut": 0.10,
	},
}


static func info(id: String) -> Dictionary:
	return ALL.get(id, {})


## Share of each landed bit you keep with this crew.
static func keep_share(crew: Array) -> float:
	var cut := 0.0
	for id in crew:
		cut += info(id).get("cut", 0.0)
	return maxf(0.1, 1.0 - cut)
