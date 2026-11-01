extends "res://scenes/ladder/machine.gd"
## The basement archive terminal: games the studio shelved, each with a note
## that fills in the founder's story. Ray's key opens the door; finding this
## room counts toward the true ending.

const SHELF := [
	{"title": "BRICK WALL: THE GAME (2011)", "note": "A stand-up game, made in one week by the founder. Never shipped. The save file is called BIGDEAL.SAV."},
	{"title": "COFFEE POT SIM (2011)", "note": "The studio's first ever test case. 400 bugs logged, all of them by someone named Gloria."},
	{"title": "THE CORNER OFFICE (2012)", "note": "A game about climbing a ladder. The top floor was never finished. A sticky note: 'too scary. later.'"},
	{"title": "HR: THE FLINGENING (2020)", "note": "A ragdoll prototype. The dummy wears glasses and a purple tie. Approved by HR."},
	{"title": "FIFTEEN YEARS (2026)", "note": "One desk. One window. One guy waiting for somebody to climb the ladder. Last edited by: D."},
]

var _note: Label


func _ready() -> void:
	super._ready()
	frame("SHELVED", Color(0.04, 0.04, 0.06), Color(0.75, 0.75, 0.85))
	_top.text = "C:\\GAMES\\NEVER_SHIPPED"
	var list := VBoxContainer.new()
	list.position = Vector2(24, 170)
	list.size = Vector2(W - 48, 680)
	list.add_theme_constant_override("separation", 12)
	add_child(list)
	for i in SHELF.size():
		var b := button(SHELF[i].title, 22, Color(0.12, 0.12, 0.16), Color(0.75, 0.75, 0.85, 0.7))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 118)
		b.pressed.connect(func():
			_note.text = SHELF[i].note
			sfx("click", -6.0))
		if i == 0:
			b.set_meta("pad_default", true)
		list.add_child(b)
	_note = label("Pick a game. Read the label.", 26, Color(0.85, 0.85, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	_note.position = Vector2(40, 900)
	_note.size = Vector2(W - 80, 340)
	add_child(_note)


func refresh_top() -> void:
	pass
