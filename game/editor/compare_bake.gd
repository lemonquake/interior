extends SceneTree
## Renders the same views from the procedural builder and from the baked scene.
##   godot --path game --script res://editor/compare_bake.gd -- --source=baked|builder --capture-path=<dir>

const RoomBuilder = preload("res://scripts/room_builder.gd")
const VIEWS := [
	["room-wide", Vector3(.62,1.58,1.30), Vector3(-.20,1.30,-2.35)],
	["room-reverse", Vector3(.75,1.58,-1.30), Vector3(-.30,1.20,2.70)],
	["kitchen", Vector3(-2.3,1.6,1.70), Vector3(-5.15,1.20,-.25)],
	["pets", Vector3(-1.2,1.5,0.4), Vector3(-2.7,1.0,-1.6)],
]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source := "baked"
	var directory := ProjectSettings.globalize_path("res://../work/v3/editable/compare")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source="):
			source = argument.trim_prefix("--source=")
		elif argument.begins_with("--capture-path="):
			directory = argument.trim_prefix("--capture-path=")
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1280, 720)
	var room: Node3D
	if source == "builder":
		room = Node3D.new()
		room.name = "LivingRoom"
		root.add_child(room)
		RoomBuilder.build(room)
	else:
		room = (load("res://scenes/room/living_room.tscn") as PackedScene).instantiate()
		root.add_child(room)
	var camera := Camera3D.new()
	camera.fov = 75
	root.add_child(camera)
	camera.make_current()
	for i in 30:
		await process_frame
	var report := {"source": source, "movable": get_nodes_in_group("movable").size(), "hamsters": get_nodes_in_group("hamsters").size(), "aquariums": get_nodes_in_group("aquariums").size(), "mystery_console": get_nodes_in_group("mystery_console").size(), "original_room_props": get_nodes_in_group("original_room_props").size()}
	for view in VIEWS:
		camera.global_position = view[1]
		camera.look_at(view[2])
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("%s-%s.png" % [view[0], source]))
	print("INTERIOR_BAKE_COMPARE ", JSON.stringify(report))
	quit()
