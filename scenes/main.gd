extends Node
## Killin' in Comedy, the phone app: the shared stand-up mini game
## (addons/hh_minigames/standup) as the whole screen. That folder is a copy
## synced from humble-house-studios/Look-busy; edit the game there.

## Dev shortcuts in the pause menu and the next-set screen. Set false before shipping.
const DEV := true


func _ready() -> void:
	var game: Node = load(HHMinigames.scene_for("standup")).instantiate()
	game.start({"dev": DEV})
	add_child(game)
