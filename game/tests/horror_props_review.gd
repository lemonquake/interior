extends SceneTree
## Closeups of the actual menu litter, canal refuse batches and movable props.
## A small camera fill is confined to this review process, so texture wear is visible.
const Canal := preload("res://scripts/canal_settlement.gd")
const Warren := preload("res://scripts/canal_warren.gd")
var main: Node
var player: InteriorPlayer
var fill: OmniLight3D
var out := "res://../docs/horror-textures/props-review"
var views: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for i in count: await process_frame

func shot(label: String, eye: Vector3, target: Vector3, fov := 62.0, fill_energy := .8) -> void:
	player.global_position = eye - Vector3.UP * 1.58
	player.camera.global_position = eye
	player.camera.look_at(target)
	player.camera.fov = fov
	fill.light_energy = fill_energy
	await frames(20)
	await RenderingServer.frame_post_draw
	var path := out.path_join(label + ".png")
	root.get_texture().get_image().save_png(path)
	views.append({"name": label, "eye": [eye.x, eye.y, eye.z], "target": [target.x, target.y, target.z],
		"fill_energy": fill_energy, "fov": fov, "path": path,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	print("HORROR_PROP_VIEW ", label, " ", target)

func nearest_kit_point(family: String, anchor: Vector3) -> Vector3:
	var best := anchor
	var distance := INF
	for child in main.find_children("Canal kit - *", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.material_override == null or mesh.material_override.get_meta("horror_prop_family", "") != family:
			continue
		var arrays := mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var point := mesh.global_transform * vertex
			var squared := point.distance_squared_to(anchor)
			if squared < distance:
				distance = squared
				best = point
	return best

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	main._apply_quality(2)
	await frames(20)
	player = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var stranger := main.get_node_or_null("Stranger")
	if stranger != null: stranger.process_mode = Node.PROCESS_MODE_DISABLED
	for layer: CanvasLayer in main.find_children("*", "CanvasLayer", true, false): layer.visible = false
	for body in get_nodes_in_group("movable"):
		if body is RigidBody3D: body.freeze = true
	fill = OmniLight3D.new()
	fill.name = "Review fill only"
	fill.light_color = Color(1.0, .93, .82)
	fill.omni_range = 4.0
	fill.light_cull_mask = 2
	fill.shadow_enabled = true
	player.camera.add_child(fill)
	await shot("01-menu-bags-crate", Vector3(19.85, -1.55, 44.7), Vector3(18.62, -2.62, 46.15), 62, .65)
	await shot("02-slipper-wrappers-cans", Vector3(20.55, -1.95, 44.0), Vector3(19.80, -2.82, 45.15), 65, .55)
	var cardboard := nearest_kit_point("cardboard", Canal.at(14.8, Canal.FLOOR, -3.0))
	await shot("03-canal-cardboard-refuse", Canal.at(14.8, cardboard.y + 1.25, cardboard.z - 1.7), cardboard + Vector3.UP * .1, 65, 1.1)
	var bag := nearest_kit_point("bag", Canal.at(14.8, Canal.FLOOR, 28.0))
	await shot("04-canal-bag-heap", Canal.at(14.8, bag.y + 1.2, bag.z - 1.5), bag + Vector3.UP * .2, 65, 1.1)
	var canal := main.find_child("Canal settlement", true, false)
	var pail: Node3D
	var pot: Node3D
	for body in get_nodes_in_group("movable"):
		if body.get_meta("loose_prop", "") == "bucket" and body.get_parent() == canal and pail == null:
			pail = body
		if body.get_meta("loose_prop", "") == "pot" and body.global_position.z > 28.0:
			pot = body
	if pail != null:
		var target := pail.global_position + Vector3.UP * .2
		await shot("05-canal-pail", Canal.at(14.8, target.y + .75, target.z - 1.0), target, 62, .8)
	if pot != null:
		var target := pot.global_position + Vector3.UP * .15
		await shot("06-warren-dented-pot", target + Warren.along(target.z) * Vector3(.9, .7, -.8), target, 60, .75)
	var fabric := nearest_kit_point("fabric", Canal.at(14.8, Canal.FLOOR + 1.3, 32.0))
	await shot("07-canal-stained-fabric", Canal.at(14.8, fabric.y + .5, fabric.z - 1.8), fabric, 62, .85)
	var report := {"renderer": RenderingServer.get_current_rendering_method(), "resolution": "1280x720", "quality": "High",
		"lighting": "Original night lighting plus camera-local warm review fill; no source lighting changes", "views": views}
	FileAccess.open(out.path_join("render.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("HORROR_PROPS_REVIEW_COMPLETE ", JSON.stringify({"views": views.size(), "out": out}))
	quit()
