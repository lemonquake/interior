extends "res://editor/bake_room.gd"
## Bakes the balcony, stair and courtyard into an editable scene.
##
##   godot --headless --path game --script res://editor/bake_balcony.gd
##
## Writes res://scenes/balcony/balcony.tscn plus meshes/materials/textures under
## res://assets/baked/balcony/. Re-running OVERWRITES manual edits to that scene; only
## re-run it after changing scripts/balcony_builder.gd. main.tscn instances the scene.

const BalconyBuilder = preload("res://scripts/balcony_builder.gd")
const BALCONY_SCENE := "res://scenes/balcony/balcony.tscn"
const BALCONY_DIR := "res://assets/baked/balcony"

func _bake() -> void:
	baked_dir = BALCONY_DIR
	PhysicsServer3D.set_active(false)
	var balcony := Node3D.new()
	balcony.name = "Balcony"
	root.add_child(balcony)
	var stats := BalconyBuilder.build(balcony)
	for i in 3:
		await process_frame
	await _settle(balcony)
	_clear_directory(ProjectSettings.globalize_path(BALCONY_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BALCONY_SCENE.get_base_dir()))
	_convert_pets(balcony)
	_flatten(balcony, balcony)
	_externalize_node(balcony)
	var packed := PackedScene.new()
	var error := packed.pack(balcony)
	if error == OK:
		error = ResourceSaver.save(packed, BALCONY_SCENE)
	if error != OK:
		push_error("Saving the balcony scene failed: %s" % error)
		quit(1)
		return
	_stats["scene"] = BALCONY_SCENE
	_stats["static_batches"] = stats.get("static_batches", 0)
	_stats["colliders"] = stats.get("colliders", 0)
	_stats["triangles"] = stats.get("triangles_added", 0)
	print("INTERIOR_BALCONY_BAKE ", JSON.stringify(_stats))
	quit(0)
