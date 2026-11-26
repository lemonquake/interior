extends SceneTree
## RENDERED review captures for the stranger (0.9): the man at the courtyard gate, his bolt when seen from
## the stair, the wait by utility pole 9 and the run down the dirt road (do not run with --headless).
##   godot --path game --script res://tests/stranger_views.gd -- --out=<dir> [--size=1280x720]
## Writes one PNG per view and prints STRANGER_VIEW <name> <state>.

func _initialize() -> void:
	_run.call_deferred()

func _arg(name: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--" + name + "="):
			return argument.get_slice("=", 1)
	return fallback

func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame

var main: Node
var player: Node3D
var camera: Camera3D
var stranger: InteriorStranger
var out := ""

func _place(eye: Vector3, target: Vector3, fov := 75.0) -> void:
	player.global_position = eye - Vector3(0, 1.58, 0)
	camera.fov = fov
	camera.global_position = eye
	camera.look_at(target)

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	var state: String = "freed" if not is_instance_valid(stranger) else InteriorStranger.State.keys()[stranger.state]
	var where: Vector3 = stranger.global_position if is_instance_valid(stranger) else Vector3.ZERO
	print("STRANGER_VIEW ", label, " ", state, " ", where)

func _run() -> void:
	out = _arg("out", "user://stranger")
	var size := _arg("size", "1280x720").split("x")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(int(size[0]), int(size[1]))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	for i in 6:
		await process_frame
	var lighting := InteriorLighting.find_in(main)
	if lighting != null:
		lighting.apply_quality(int(_arg("quality", "2")))
	player = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	camera = main.player.camera
	for layer in main.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	stranger = main.get_node("Stranger") as InteriorStranger
	# Stills of him at the gate: frozen so being looked at doesn't set him off.
	stranger.process_mode = Node.PROCESS_MODE_DISABLED
	for view: Array in [
			["01-gate-courtyard", Vector3(10.4, -1.32, 4.0), Vector3(13.0, -1.55, 4.1), 62.0],
			["02-gate-close", Vector3(11.6, -1.3, 3.5), Vector3(13.0, -1.45, 4.1), 55.0],
			["03-gate-from-stair-top", Vector3(5.25, 1.5, 3.3), Vector3(12.6, -1.6, 4.5), 75.0]]:
		_place(view[1], view[2], view[3])
		for i in 10:
			await process_frame
		await _shot(view[0])
	# Picture 1: at the top of the stair, looking away (toward the house), then turning to the gate.
	_place(Vector3(5.25, 1.5, 3.3), Vector3(1.0, 1.4, 2.0), 75.0)
	stranger.process_mode = Node.PROCESS_MODE_PAUSABLE
	await _wait(1.0)
	await _shot("04-not-seen-yet")
	_place(Vector3(5.25, 1.5, 3.3), Vector3(12.6, -1.6, 4.5), 75.0)
	var elapsed := 0.0
	for step in [.15, .3, .35, .5, .7]:
		await _wait(step)
		elapsed += step
		await _shot("05-bolt-%.2f" % elapsed)
	# He runs the lane and street B; watch from the lane mouth.
	_place(Vector3(18.0, -1.32, 6.5), Vector3(20.0, -1.6, 40.0), 72.0)
	await _wait(1.5)
	await _shot("06-running-up-street-b")
	var waited := 0.0
	while is_instance_valid(stranger) and stranger.state != InteriorStranger.State.WAITING and waited < 20.0:
		await _wait(.25)
		waited += .25
	await _wait(1.0)
	# From the corner, east of the cart (not past it, so he stays).
	_place(Vector3(21.8, -1.32, 13.0), Vector3(19.2, -1.75, 45.0), 75.0)
	await _wait(.6)
	await _shot("07-waiting-from-corner")
	_place(Vector3(21.8, -1.32, 13.0), Vector3(19.2, -1.75, 45.0), 22.0)
	await _wait(.6)
	await _shot("08-waiting-zoom")
	# Picture 2's viewpoint is past the cart: freeze him for this still.
	stranger.process_mode = Node.PROCESS_MODE_DISABLED
	_place(Vector3(20.0, -1.32, 34.0), Vector3(20.0, -1.6, 60.0), 75.0)
	for i in 8:
		await process_frame
	await _shot("08b-picture-2-view")
	stranger.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Walk past the cart: he goes.
	_place(Vector3(21.6, -1.32, 18.4), Vector3(20.6, -1.8, 50.0), 45.0)
	for k in 6:
		await _wait(.7)
		await _shot("09-flee-%d" % k)
	_place(Vector3(21.0, -1.32, 50.0), Vector3(19.0, -1.9, 100.0), 55.0)
	await _wait(.5)
	await _shot("10-dirt-road")
	await _wait(3.0)
	await _shot("11-dirt-road-later")
	quit(0)
