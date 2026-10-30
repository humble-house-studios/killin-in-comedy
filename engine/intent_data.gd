class_name IntentData
extends Resource
## One audience move. The next one is shown with a live countdown.
## DRAIN also interrupts a bit you haven't landed yet.

enum Kind {
	CALM,        ## does nothing
	DRAIN,       ## -amount Crowd Energy
	RESTLESS,    ## -amount mic time next turn
	TOUGH_CROWD, ## +amount% laughs needed
	SPIKE,       ## +amount Heat (the room pops)
}

@export var kind: Kind = Kind.CALM
@export var amount := 0
@export var text := ""
