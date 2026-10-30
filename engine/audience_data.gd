class_name AudienceData
extends Resource
## One audience (enemy). Its intents play in order and loop.

@export var id := ""
@export var title := ""
@export var laughs_needed := 40
@export var is_boss := false
@export var intents: Array[IntentData] = []
