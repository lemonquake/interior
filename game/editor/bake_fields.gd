extends "res://editor/bake_room.gd"
## Bakes the moonlit rice fields (0.7) into an editable scene.
##
##   godot --headless --path game --script res://editor/bake_fields.gd
##
## Writes res://scenes/fields/fields.tscn plus meshes, MultiMeshes and materials under
## res://assets/baked/fields/. Re-running OVERWRITES manual edits to that scene; only re-run it after
## changing scripts/fields_builder.gd. main.tscn instances the scene.

const FieldsBuilder = preload("res://scripts/fields_builder.gd")
const FIELDS_SCENE := "res://scenes/fields/fields.tscn"
const FIELDS_DIR := "res://assets/baked/fields"

func _bake() -> void:
	baked_dir = FIELDS_DIR
	PhysicsServer3D.set_active(false)
	var holder := Node3D.new()
	holder.name = "FieldsHolder"
	root.add_child(holder)
	var started := Time.get_ticks_msec()
	var stats := FieldsBuilder.build(holder)
	var fields := holder.get_node("Fields") as Node3D
	for i in 3:
		await process_frame
	_clear_directory(ProjectSettings.globalize_path(FIELDS_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIELDS_SCENE.get_base_dir()))
	holder.remove_child(fields)
	root.add_child(fields)
	_flatten(fields, fields)
	_externalize_node(fields)
	var packed := PackedScene.new()
	var error := packed.pack(fields)
	if error == OK:
		error = ResourceSaver.save(packed, FIELDS_SCENE)
	if error != OK:
		push_error("Saving the fields scene failed: %s" % error)
		quit(1)
		return
	_stats["scene"] = FIELDS_SCENE
	_stats["fields"] = stats
	_stats["seconds"] = (Time.get_ticks_msec() - started) / 1000.0
	print("INTERIOR_FIELDS_BAKE ", JSON.stringify(_stats))
	quit(0)
