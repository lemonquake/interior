extends "res://editor/bake_room.gd"
## Bakes the music studio into an editable scene.
##
##   godot --headless --path game --script res://editor/bake_studio.gd
##
## Writes res://scenes/studio/studio.tscn plus meshes/materials under res://assets/baked/studio/.
## Downloaded models stay linked to their GLBs (keep_instance). Re-running OVERWRITES manual edits
## to that scene; only re-run it after changing scripts/studio_builder.gd. main.tscn instances it.

const StudioBuilder = preload("res://scripts/studio_builder.gd")
const STUDIO_SCENE := "res://scenes/studio/studio.tscn"
const STUDIO_DIR := "res://assets/baked/studio"

func _bake() -> void:
	baked_dir = STUDIO_DIR
	PhysicsServer3D.set_active(false)
	var studio := Node3D.new()
	studio.name = "Studio"
	root.add_child(studio)
	var stats := StudioBuilder.build(studio)
	for i in 3:
		await process_frame
	_clear_directory(ProjectSettings.globalize_path(STUDIO_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STUDIO_SCENE.get_base_dir()))
	_flatten(studio, studio)
	_externalize_node(studio)
	var packed := PackedScene.new()
	var error := packed.pack(studio)
	if error == OK:
		error = ResourceSaver.save(packed, STUDIO_SCENE)
	if error != OK:
		push_error("Saving the studio scene failed: %s" % error)
		quit(1)
		return
	_stats["scene"] = STUDIO_SCENE
	_stats["static_batches"] = stats.get("static_batches", 0)
	_stats["colliders"] = stats.get("colliders", 0)
	_stats["triangles"] = stats.get("triangles_added", 0)
	_stats["models"] = stats.get("models", 0)
	print("INTERIOR_STUDIO_BAKE ", JSON.stringify(_stats))
	quit(0)
