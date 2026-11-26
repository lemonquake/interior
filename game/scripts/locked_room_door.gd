extends Node3D
## A fixed door using the same E / touch Hold targeting as other usable objects.
signal tried_locked_door

func _ready() -> void:
	add_to_group("usables")

func prompt_text() -> String:
	return "Open door"

func toggle() -> void:
	tried_locked_door.emit()
