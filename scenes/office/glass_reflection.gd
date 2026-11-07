extends Node
## A real reflection in a CRT's glass (the Pong desk's for now). A second
## camera sits mirrored behind the glass with an off-axis frustum whose near
## plane IS the glass, so its picture lines up exactly with the screen: the
## room behind you, the window, a stand-in you (head and shoulders, seen only
## in reflections) and the boss walking up behind you while you play.
## Like the game itself it is drawn twice: a world copy on the glass, and a
## screen-pass copy that fades in up close so it sits over the crisp game.
## It only renders while you're near and facing the glass, at a small size,
## and stops while the office is paused.

const SHADER := preload("res://scenes/office/glass_reflection.gdshader")
## Height of the reflection film in pixels (width follows the glass).
const RES_Y := 180
## How strong the glass is. Kept faint so the game stays easy to read.
const STRENGTH := 0.26
## Renders only within this distance of the glass (metres).
const RANGE := 3.2
## Darker than the room: you are lit from behind (the window), so you read
## as a soft silhouette and the boss behind you stands out.
const MY_SHIRT := Color(0.12, 0.2, 0.36)

var office: Node
var screen: Node3D
var _vp: SubViewport
var _cam: Camera3D
var _world_q: MeshInstance3D
var _near_q: MeshInstance3D
var _world_m: ShaderMaterial
var _near_m: ShaderMaterial
var _you: Node3D
var _amt := 0.0
var _mesh := QuadMesh.new()


func setup(o: Node, s: Node3D) -> void:
	office = o
	screen = s
	_vp = SubViewport.new()
	_vp.world_3d = office._world_vp.world_3d
	_vp.gui_disable_input = true
	_vp.audio_listener_enable_3d = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.size = Vector2i(240, RES_Y)
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.cull_mask = office.LAYER_WORLD | office.LAYER_REFLECT
	_cam.projection = Camera3D.PROJECTION_FRUSTUM
	_vp.add_child(_cam)
	_cam.current = true
	var tex := _vp.get_texture()
	_world_m = _material(tex)
	_near_m = _material(tex)
	_world_q = _quad(_world_m, office.LAYER_WORLD)
	_near_q = _quad(_near_m, office.LAYER_SCREEN)
	_build_you()


func _material(tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.render_priority = 1
	m.set_shader_parameter("room", tex)
	m.set_shader_parameter("strength", 0.0)
	return m


func _quad(m: Material, layer: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = m
	mi.layers = layer
	# Just in front of the game's two copies (0 and 0.001).
	mi.position.z = 0.004
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.add_child(mi)
	return mi


## You, as the glass sees you: head, hair and shoulders around the camera.
## Only the reflection camera draws this layer.
func _build_you() -> void:
	_you = Node3D.new()
	office._world_vp.add_child(_you)
	var skin: Material = office._mat(Color(0.6, 0.46, 0.38))
	var hair: Material = office._mat(Color(0.14, 0.1, 0.08))
	var shirt: Material = office._mat(MY_SHIRT, 6, Color.BLACK, 40.0)
	var parts: Array[MeshInstance3D] = [
		office._box(Vector3(0.19, 0.24, 0.21), Vector3(0, -0.02, 0.06), skin, false, Vector3.ZERO, _you),
		office._box(Vector3(0.21, 0.07, 0.23), Vector3(0, 0.11, 0.07), hair, false, Vector3.ZERO, _you),
		office._box(Vector3(0.21, 0.16, 0.06), Vector3(0, 0.03, 0.17), hair, false, Vector3.ZERO, _you),
		office._box(Vector3(0.1, 0.12, 0.1), Vector3(0, -0.19, 0.08), skin, false, Vector3.ZERO, _you),
		office._box(Vector3(0.46, 0.4, 0.24), Vector3(0, -0.45, 0.1), shirt, false, Vector3.ZERO, _you),
	]
	for p in parts:
		p.layers = office.LAYER_REFLECT
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _glass() -> Vector2:
	return office.TV_GLASS if office._look_i == 1 else office.CRT_GLASS


func _process(delta: float) -> void:
	if screen == null or office._camera == null:
		return
	var main: Camera3D = office._camera
	var g := screen.global_transform
	var b := g.basis.orthonormalized()
	var r := b.x
	var u := b.y
	var n := b.z
	var o := g.origin
	var p := main.global_position
	var d := (p - o).dot(n)
	var facing := -main.global_transform.basis.z.dot(-n)
	var on := screen.is_visible_in_tree() and d > 0.05 and p.distance_to(o) < RANGE and facing > 0.1
	_amt = move_toward(_amt, STRENGTH if on else 0.0, delta * 0.8)
	_world_q.visible = _amt > 0.0
	_near_q.visible = _amt > 0.0
	if not _world_q.visible:
		return
	var glass := _glass()
	_mesh.size = glass
	# The crisp game copy fades in from 4 m to 2.5 m; the near glass with it.
	var near_fade := clampf((4.0 - p.distance_to(o)) / 1.5, 0.0, 1.0)
	_world_m.set_shader_parameter("strength", _amt)
	_near_m.set_shader_parameter("strength", _amt * near_fade)
	if not on or d <= 0.05:
		return
	# You, where the camera is, turned the way it faces (yaw only).
	var fwd := -main.global_transform.basis.z
	_you.global_position = p
	_you.rotation = Vector3(0, atan2(-fwd.x, -fwd.z), 0)
	# Mirror the camera across the glass; look straight out of it.
	var mp := p - 2.0 * d * n
	var foot := p - d * n
	_cam.global_transform = Transform3D(Basis(-r, u, -n), mp)
	var off := Vector2(-(o - foot).dot(r), (o - foot).dot(u))
	_cam.set_frustum(glass.y, off, d, 30.0)
	_vp.size = Vector2i(int(RES_Y * glass.x / glass.y), RES_Y)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
