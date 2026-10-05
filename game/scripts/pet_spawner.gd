class_name InteriorPetSpawner
extends Node
## Rebuilds a procedural pet habitat on its parent body when the room loads.
## Baked scenes keep a static "...Preview" copy of the habitat so it is visible in the
## editor; at runtime the preview is replaced by the live, animated habitat.

@export_enum("hamsters", "aquarium") var kind := "hamsters"
@export var aquarium_scale := 1.0
## Non-zero: a rectangular tank of this inner size instead of the round bowl.
@export var tank_size := Vector3.ZERO
## Render layers for the rebuilt meshes (the balcony uses its outdoor layer too).
@export_flags_3d_render var visual_layers := 1

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# The parent is still adding its children; rebuild once it is ready.
	_attach.call_deferred()

func _attach() -> void:
	var body := get_parent() as RigidBody3D
	if body == null:
		return
	for child in body.get_children():
		if str(child.name).ends_with("Preview"):
			body.remove_child(child)
			child.queue_free()
	if kind == "hamsters":
		HamsterEnclosure.attach_to(body)
	elif body is InteriorObject:
		InteriorAquarium.attach_to(body as InteriorObject, aquarium_scale, tank_size)
	if visual_layers != 1:
		for node in body.find_children("*", "GeometryInstance3D", true, false):
			(node as GeometryInstance3D).layers = visual_layers
	body.reset_physics_interpolation()
