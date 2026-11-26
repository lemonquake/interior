extends SceneTree
## Render the actual night lighting, materials, cleared path, dialogue and lamp outage.
var main: Node
var player: InteriorPlayer
var out := ""

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await process_frame

func shot(label: String, eye: Vector3, target: Vector3, fov := 68.0) -> void:
	player.global_position = eye - Vector3.UP * 1.58
	player.camera.global_position = eye
	player.camera.look_at(target)
	player.camera.fov = fov
	await frames(150)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("NIGHT_VIEW ", label)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	out = "user://night-revision"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600,900)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	main._apply_quality(2)
	await frames(8)
	player = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var man: InteriorStranger = main.get_node("Stranger")
	man.process_mode = Node.PROCESS_MODE_DISABLED
	for layer: CanvasLayer in main.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	await shot("01-street",Vector3(20.2,-1.32,6),Vector3(20.5,-1.65,31))
	await shot("02-tricycle",Vector3(17.9,-1.5,13),Vector3(19.8,-1.85,11.3),58)
	await shot("03-gate-and-tricycle",Vector3(7,-1.32,18.2),Vector3(3,-1.4,16.85),66)
	var hut: InteriorHutHouse = main.story.hut
	await shot("04-hut-path",hut.route_in[0]+Vector3(0,1.62,-1),hut.door_point()+Vector3.UP*.9)
	await shot("05-ammo-dike",hut.crow_route[0]+Vector3.UP*1.65,hut.crow_route[3]+Vector3.UP*.5)
	var centre: Vector3 = hut.crow_route[3]
	await shot("06-ammo-ground",centre+Vector3(1.8,2.25,1.7),centre,65)
	man.call_out(hut)
	man._anim.advance(.7)
	main.story.ui.say(InteriorStory.SPEAKER,InteriorStory.CALL_LINES,100.0)
	main.story.ui.advance()
	main.story.ui.advance()
	main.story.ui.advance()
	for layer: CanvasLayer in main.find_children("*", "CanvasLayer", true, false):
		layer.visible = true
	main.touch.visible = false
	await shot("07-family-dialogue",hut.door_point()+Vector3.UP*1.58,man.global_position+Vector3.UP*1.25,62)
	main.story.ui.say(InteriorStory.SPEAKER,[InteriorStory.RUN_LINE],100.0)
	main.story.ui.advance()
	await shot("08-ammo-dialogue",hut.door_point()+Vector3.UP*1.58,man.global_position+Vector3.UP*1.25,62)
	for layer: CanvasLayer in main.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	main.story.start_alarm()
	await frames(650)
	await shot("09-alarm-street",Vector3(21.6,-1.32,33),Vector3(20.6,-.2,47),66)
	print("NIGHT_REVIEW_COMPLETE ", RenderingServer.get_current_rendering_method())
	quit()
