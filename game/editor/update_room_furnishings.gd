extends SceneTree
## Patch only the requested furniture and door; preserve other baked room edits.
func _initialize() -> void:
	_run.call_deferred()

func _own(node: Node, room: Node) -> void:
	for child in node.get_children():
		child.owner = room
		_own(child, room)

func _run() -> void:
	PhysicsServer3D.set_active(false)
	var room: Node3D = load("res://scenes/room/living_room.tscn").instantiate()
	root.add_child(room)
	preload("res://scripts/room_furnishings.gd").apply(room)
	# Keep the generated cloth geometry in editable binary resources, shared by
	# the four pillows, rather than repeating vertex data in the room scene.
	var folder := "res://assets/baked/furnishings"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var resources := {}
	for body in room.get_children():
		if not body.has_meta("white_pillow"):
			continue
		var mesh := InteriorRoomVisuals._first_mesh(body)
		var seam := mesh.get_node("White pillow stitched edge")
		for entry in [[mesh, "mesh", "white_pillow"], [seam, "mesh", "pillow_seam"], [body.get_child(1), "shape", "pillow_collision"]]:
			var key: String = entry[2]
			if not resources.has(key):
				var resource: Resource = entry[0].get(entry[1])
				var path := folder.path_join(key + ".res")
				var saved := ResourceSaver.save(resource, path, ResourceSaver.FLAG_CHANGE_PATH)
				if saved != OK:
					push_error("Could not save " + path)
					quit(1)
					return
				resources[key] = resource
			entry[0].set(entry[1], resources[key])
	_own(room, room)
	var packed := PackedScene.new()
	var error := packed.pack(room)
	if error == OK:
		error = ResourceSaver.save(packed, "res://scenes/room/living_room.tscn")
	print("ROOM_FURNISHINGS_SAVED ", error)
	quit(0 if error == OK else 1)
