extends Node3D
## Solid, permanently locked entrances and small objects attached to the real facades.
var kind := "door"
var index := 0
var controller: Node
var uses := 0
var cooldown := 0.0

func _ready() -> void:
	add_to_group("usables")
	add_to_group("neighborhood_usables")
	set_process(false)

func prompt_text() -> String:
	if kind == "door" and is_instance_valid(controller) and not controller.within_knocking_reach(self):
		return "Move closer to open door"
	match kind:
		"bell": return "Press doorbell"
		"mailbox": return "Check mailbox"
		_: return "Open door"

func toggle() -> void:
	if cooldown > 0.0 or not is_instance_valid(controller):
		return
	if controller.use_object(self):
		uses += 1
		# The controller prevents overlapping knocks. A cancelled knock is immediately retryable.
		cooldown = 0.0 if kind == "door" else 6.0
		set_process(cooldown > 0.0)

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown <= 0.0:
		set_process(false)
