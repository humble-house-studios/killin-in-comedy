extends GutTest
## The app is the shared stand-up game, full screen, owning its window.


func test_the_app_runs_the_shared_standup_game() -> void:
	var app: Node = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(app)
	await wait_frames(2)
	assert_eq(app.get_child_count(), 1)
	var game: Node = app.get_child(0)
	assert_eq(game.get_script().resource_path, HHMinigames.script_for("standup"))
	assert_true(game.has_signal("finished"))
	assert_eq(game.dev_tools, app.DEV)
