class_name IntentData
extends Resource
## One audience move, shown to the player a turn ahead.

enum Kind {
	CALM,        ## does nothing
	DRAIN,       ## -amount Crowd Energy
	RESTLESS,    ## -amount mic time next turn
	TOUGH_CROWD, ## +amount laughs needed
}

@export var kind: Kind = Kind.CALM
@export var amount := 0
@export var text := ""
