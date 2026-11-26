class_name InteriorHutUsable
extends Node3D
## 0.10: something in the hut the player can use with E / Hold (the key, the drawer, the gun). The player's view ray
## finds it through a StaticBody3D child (players.gd: the "usables" group); prompt_text() and toggle() go to the hut.

var hut: InteriorHutHouse
var kind := ""

func _ready() -> void:
	add_to_group("usables")

func prompt_text() -> String:
	return hut.usable_prompt(kind) if is_instance_valid(hut) else ""

func toggle() -> void:
	if is_instance_valid(hut):
		hut.use(kind)
