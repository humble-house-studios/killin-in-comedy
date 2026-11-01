extends SubViewportContainer
## A little 3D world for an arcade screen (claw, coin pusher, Fall Guy, the
## putting course). Its own World3D (so its physics and lights never touch the
## office), rendered small and blown up with chunky pixels, every surface in
## retro3d.gdshader (per-vertex light, fog, dither) and a grain/scanline pass
## on top (retro_post.gdshader). Make it with setup(), then build with mat(),
## box(), ball(), cyl(), solid() and set_light().
##
## It renders only while its machine runs (the ladder pauses machines in rooms
## you can't see), so a whole arcade of these stays cheap.

const SHADER := preload("res://scenes/ladder/retro3d.gdshader")
const POST := preload("res://scenes/ladder/retro_post.gdshader")
const FONT := preload("res://fonts/press_start_2p.ttf")
const LIGHTS := 6

var vp: SubViewport
var root: Node3D
var cam: Camera3D
var post: ColorRect
var mats: Array[ShaderMaterial] = []
var _look := {}
var _l_pos := PackedVector3Array()
var _l_col := PackedVector3Array()
var _l_range := PackedFloat32Array()
var _dirty := true


## look: sky, ambient, sun_dir, sun_col, fog_col, fog_near, fog_far, levels,
## grain, vignette, scan, tint, flicker.
func setup(at: Vector2, area: Vector2, shrink: int, look: Dictionary) -> void:
	_look = look
	position = at
	size = area
	stretch = true
	stretch_shrink = shrink
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.handle_input_locally = false
	vp.size = Vector2i(area / shrink)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = look.get("sky", Color.BLACK)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	root = Node3D.new()
	vp.add_child(root)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.03
	cam.far = 120.0
	vp.add_child(cam)
	cam.current = true
	for i in LIGHTS:
		_l_pos.append(Vector3.ZERO)
		_l_col.append(Vector3.ZERO)
		_l_range.append(0.0)


## The grain/scanline pass, placed over this view. Add it after setup() and
## after the view itself is in the tree (it goes in as the view's sibling).
func add_post(parent: Control) -> ColorRect:
	post = ColorRect.new()
	post.position = position
	post.size = size
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = POST
	m.set_shader_parameter("grain", _look.get("grain", 0.05))
	m.set_shader_parameter("vignette", _look.get("vignette", 0.5))
	m.set_shader_parameter("scan", _look.get("scan", 0.06))
	m.set_shader_parameter("tint", _look.get("tint", Color(0, 0, 0, 0)))
	m.set_shader_parameter("flicker", _look.get("flicker", 0.0))
	m.set_shader_parameter("px", Vector2(vp.size))
	post.material = m
	parent.add_child(post)
	return post


func _notification(what: int) -> void:
	# Paused machine (room out of sight): stop drawing its world too.
	if vp == null:
		return
	if what == NOTIFICATION_DISABLED:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	elif what == NOTIFICATION_ENABLED:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func set_light(i: int, at: Vector3, color: Color, reach: float, energy := 1.0) -> void:
	_l_pos[i] = at
	_l_col[i] = Vector3(color.r, color.g, color.b) * energy
	_l_range[i] = reach
	_dirty = true


func set_sun(dir: Vector3, color: Color) -> void:
	_look["sun_dir"] = dir
	_look["sun_col"] = color
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		for m in mats:
			_apply(m)


func _apply(m: ShaderMaterial) -> void:
	var amb: Color = _look.get("ambient", Color(0.3, 0.3, 0.3))
	var sun: Color = _look.get("sun_col", Color.BLACK)
	var fog: Color = _look.get("fog_col", Color.BLACK)
	m.set_shader_parameter("ambient", Vector3(amb.r, amb.g, amb.b))
	m.set_shader_parameter("sun_dir", _look.get("sun_dir", Vector3(0.3, 1, 0.4)))
	m.set_shader_parameter("sun_col", Vector3(sun.r, sun.g, sun.b))
	m.set_shader_parameter("fog_col", Vector3(fog.r, fog.g, fog.b))
	m.set_shader_parameter("fog_near", _look.get("fog_near", 4.0))
	m.set_shader_parameter("fog_far", _look.get("fog_far", 20.0))
	m.set_shader_parameter("levels", _look.get("levels", 24.0))
	m.set_shader_parameter("snap", Vector2(vp.size) * 0.5)
	m.set_shader_parameter("l_pos", _l_pos)
	m.set_shader_parameter("l_col", _l_col)
	m.set_shader_parameter("l_range", _l_range)


## A surface. opts: col2, pattern (0 flat, 1 checker, 2 stripes, 3 speckle,
## 4 tiles), texel (pattern cells per metre), glow (emission colour), shine.
func mat(color: Color, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("albedo2", opts.get("col2", color.darkened(0.3)))
	m.set_shader_parameter("pattern", opts.get("pattern", 0))
	m.set_shader_parameter("texel", opts.get("texel", 8.0))
	m.set_shader_parameter("emission", opts.get("glow", Color.BLACK))
	m.set_shader_parameter("shine", opts.get("shine", 0.0))
	_apply(m)
	mats.append(m)
	return m


func glow(color: Color) -> ShaderMaterial:
	return mat(Color.BLACK, {"glow": color})


func _place(mi: Node3D, at: Vector3, parent: Node, rot: Vector3) -> void:
	mi.position = at
	mi.rotation = rot
	(parent if parent else root).add_child(mi)


## A box, subdivided so the per-vertex light has points to land on.
func box(dims: Vector3, at: Vector3, m: Material, parent: Node = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dims
	mesh.subdivide_width = clampi(int(dims.x / 0.35), 0, 64)
	mesh.subdivide_height = clampi(int(dims.y / 0.35), 0, 64)
	mesh.subdivide_depth = clampi(int(dims.z / 0.35), 0, 64)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	_place(mi, at, parent, rot)
	return mi


func ball(r: float, at: Vector3, m: Material, parent: Node = null, segs := 8) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = segs
	mesh.rings = maxi(3, segs / 2)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	_place(mi, at, parent, Vector3.ZERO)
	return mi


func cyl(r_top: float, r_bottom: float, h: float, at: Vector3, m: Material, parent: Node = null, rot := Vector3.ZERO, segs := 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bottom
	mesh.height = h
	mesh.radial_segments = segs
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	_place(mi, at, parent, rot)
	return mi


## A box you can bump into (StaticBody3D). m = null: invisible (glass).
func solid(dims: Vector3, at: Vector3, m: Material, parent: Node = null, rot := Vector3.ZERO, bounce := 0.1, friction := 0.7) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = dims
	shape.shape = b
	body.add_child(shape)
	var pm := PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = friction
	body.physics_material_override = pm
	_place(body, at, parent, rot)
	if m:
		box(dims, Vector3.ZERO, m, body)
	return body


func text(t: String, at: Vector3, px: int, color: Color, parent: Node = null, rot := Vector3.ZERO, pixel := 0.004) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = FONT
	l.font_size = px
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_place(l, at, parent, rot)
	return l


## Physics queries in this little world.
func ray(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = exclude
	return vp.find_world_3d().direct_space_state.intersect_ray(q)
