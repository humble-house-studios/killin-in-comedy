class_name AudienceData
extends Resource
## One audience (enemy). Its intents play in order and loop.

@export var id := ""
@export var title := ""
@export var laughs_needed := 40
@export var is_boss := false
## Length of the set in seconds before the light.
@export var seconds := 75.0
## Seconds between crowd moves.
@export var event_every := 7.0
## Topics this crowd loves / hates (see CardData.TOPICS).
@export var loves: Array[String] = []
@export var hates: Array[String] = []
@export var intents: Array[IntentData] = []
