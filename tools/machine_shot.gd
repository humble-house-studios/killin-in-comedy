extends SceneTree
## Renders one arcade machine on its own (no office) and saves PNGs, for
## checking the 3D machines quickly (needs a display):
##   MACHINE=claw OUT=/some/dir xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 --resolution 720x1280 -s res://tools/machine_shot.gd
## MACHINE: claw, pusher, ragdoll or putt. It plays a little (drops, flings,
## putts) between shots. The machine sits in a 2D-only SubViewport, the same
## way the ladder hosts it.

var m: Control
var n := 0
var out := ""


func _init() -> void:
	out = OS.get_environment("OUT")
	var id := OS.get_environment("MACHINE")
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var show := TextureRect.new()
	show.texture = vp.get_texture()
	show.size = Vector2(720, 1280)
	root.add_child(show)
	var scr = load("res://scenes/ladder/%s.gd" % id)
	if scr == null or not scr.can_instantiate():
		quit(1)
		return
	m = scr.new()
	vp.add_child(m)
	m.set_active(true)
	await _frames(90)
	await _shot(id + "_start")
	match id:
		"claw":
			m._nudge(-0.3, 0.2)
			m._on_drop()
			await _frames(70)
			await _shot("claw_drop")
			await _frames(240)
			await _shot("claw_carry")
			await _frames(200)
			await _shot("claw_end")
		"pusher":
			for i in 5:
				m._on_drop()
				await _frames(25)
			await _shot("pusher_drops")
			await _frames(400)
			await _shot("pusher_later")
		"ragdoll":
			m._power_t = 0.9
			m._on_fling()
			await _frames(40)
			await _shot("ragdoll_fly")
			await _frames(120)
			await _shot("ragdoll_mid")
			await _frames(400)
			await _shot("ragdoll_end")
		"putt":
			m._t = 0.5
			m._on_putt()
			await _frames(40)
			await _shot("putt_roll")
			await _frames(300)
			await _shot("putt_end")
	print("tickets/state: ", m.get("_strokes"), " ", m.get("_last_score"))
	quit()


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("shot ", name)
