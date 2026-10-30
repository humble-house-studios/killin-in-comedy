extends SceneTree
## Balance check: plays many autopilot runs and prints win rates per set.
## godot --headless -s res://tools/tune.gd

func _init() -> void:
	var n := 300
	# Optional overrides: TUNE="open_mic=3000:60,the_critic=20000:90" (laughs:seconds)
	for pair in OS.get_environment("TUNE").split(",", false):
		var kv := pair.split("=")
		var parts := kv[1].split(":")
		var a := CardLibrary.audience(kv[0])
		a.laughs_needed = int(parts[0])
		if parts.size() > 1:
			a.seconds = float(parts[1])
	var reached := {}
	var won := {}
	var scores := {}
	for s in n:
		var run := Run.new(s)
		while not run.is_complete():
			var a := run.current_audience()
			reached[a.id] = reached.get(a.id, 0) + 1
			var b := run.start_set()
			var r := Autopilot.play_set(b)
			scores[a.id] = scores.get(a.id, 0) + b.laughs
			if r != Battle.Result.WON:
				break
			won[a.id] = won.get(a.id, 0) + 1
			run.finish_set(Autopilot.pick_reward(run.reward_choices()))
			run.hire(Autopilot.pick_crew(run.crew_choices()))
	for id in reached:
		var aud := CardLibrary.audience(id)
		print("%-16s need %6d in %ds | reached %3d  won %3d (%d%%)  avg laughs %d" % [id, aud.laughs_needed, aud.seconds,
			reached[id], won.get(id, 0), 100 * won.get(id, 0) / reached[id], scores[id] / reached[id]])
	quit()
