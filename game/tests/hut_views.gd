extends SceneTree
## RENDERED review captures for the 0.10 hut sequence (do not run with --headless):
##   godot --path game --script res://tests/hut_views.gd -- --out=<dir> [--size=1280x720] [--only=a,b]
## The stranger turns off the road into the bahay kubo; inside: candle, dresser, sparkling key; key taken; drawer
## opens on the Glock; inspect screen; called outside; follows him to the scarecrow; ammo; "Now... run."; sirens and
## the street lamps going out. Prints HUT_VIEW <name> <stranger state> <story phase>.

func _initialize() -> void:
	_run.call_deferred()

func _arg(name: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--" + name + "="):
			return argument.get_slice("=", 1)
	return fallback

func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0 / Engine.time_scale)
	while Time.get_ticks_msec() < end:
		await process_frame

var main: Node
var player: InteriorPlayer
var camera: Camera3D
var stranger: InteriorStranger
var story: InteriorStory
var hut: InteriorHutHouse
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
	print("HUT_VIEW ", label, " ", state, " ", InteriorStory.Phase.keys()[story.phase], " ", stranger.global_position if is_instance_valid(stranger) else Vector3.ZERO)

func _hut_point(local: Vector3) -> Vector3:
	return hut.global_transform * local

func _run() -> void:
	out = _arg("out", "user://hut_views")
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
	camera = player.camera
	main.touch.visible = false
	stranger = main.get_node("Stranger") as InteriorStranger
	story = main.story
	hut = story.hut
	# 00: street B with its lamps lit (for the before/after).
	stranger.process_mode = Node.PROCESS_MODE_DISABLED
	# 0.11: the hooded man at the gate, from the stair and from the courtyard.
	var door := main.entry_door() as InteriorHingedDoor
	if door != null and not door.is_open():
		door.snap(true)
	_place(Vector3(5.25, 1.5, 3.3), Vector3(8.6, -1.9, 3.55), 62.0)
	await _wait(.6)
	await _shot("00a-gate-from-stair")
	_place(Vector3(10.6, -1.32, 4.0), stranger.global_position + Vector3(0, 1.45, 0), 55.0)
	await _wait(.4)
	await _shot("00b-gate-close")
	_place(Vector3(21.6, -1.32, 33.0), Vector3(20.6, -.2, 47.0), 66.0)
	await _wait(.6)
	await _shot("00-street-b-lamps-on")
	# He waits by pole 9; the player passes the cart and he runs. Watch from the road near the footpath.
	stranger.process_mode = Node.PROCESS_MODE_PAUSABLE
	stranger.state = InteriorStranger.State.WAITING
	stranger.global_position = InteriorStranger.WAIT_SPOT
	stranger._wait_time = 2.0
	player.global_position = Vector3(21.6, -2.9, 18.4)
	camera.global_position = Vector3(21.6, -1.32, 18.4)
	for i in 3:
		await process_frame
	var road0: PackedVector2Array = main.get_node("Fields").get_meta("road_samples")
	var watch_i := hut.road_index - 16
	var watch := Vector3(road0[watch_i].x, -1.32, road0[watch_i].y)
	Engine.time_scale = 3.0
	while stranger.global_position.distance_to(Vector3(road0[hut.road_index].x, -2.9, road0[hut.road_index].y)) > 14.0 and stranger.state == InteriorStranger.State.FLEEING:
		await process_frame
	Engine.time_scale = 1.0
	var path_mid := (hut.route_in[1] + hut.route_in[2]) * .5
	var cam_i := hut.road_index - 9
	_place(Vector3(road0[cam_i].x - 2.2, -1.25, road0[cam_i].y), path_mid + Vector3(0, 1.0, 0), 58.0)
	var k := 0
	while stranger.state == InteriorStranger.State.FLEEING and k < 12:
		await _wait(.55)
		await _shot("01-turn-to-hut-%02d" % k)
		k += 1
	await _wait(.5)
	await _shot("02-he-is-gone")
	# The hut from the footpath, the lantern by the door.
	var path_eye := _hut_point(Vector3(9.0, 1.6, -.3))
	_place(path_eye, _hut_point(Vector3(0, 1.3, -.3)), 62.0)
	await _wait(.6)
	await _shot("03-hut-from-footpath")
	_place(_hut_point(Vector3(3.4, 1.62, -.3)), _hut_point(Vector3(-1.5, 1.1, -.3)), 70.0)
	await _wait(.4)
	await _shot("04-doorway")
	_place(_hut_point(Vector3(.9, 2.0, -.1)), _hut_point(Vector3(-1.5, 1.2, -.35)), 70.0)
	await _wait(.4)
	await _shot("05-inside-dresser")
	_place(_hut_point(Vector3(-.6, 1.95, .9)), _hut_point(Vector3(1.2, .9, -.6)), 75.0)
	await _wait(.4)
	await _shot("06-inside-room")
	_place(_hut_point(Vector3(-.75, 1.75, -.3)), _hut_point(Vector3(-1.4, 1.26, -.45)), 55.0)
	await _wait(.3)
	await _shot("07-key-sparkle-a")
	await _wait(.45)
	await _shot("07-key-sparkle-b")
	# Take the key, open the drawer.
	_place(_hut_point(Vector3(-.5, 2.0, -.3)), _hut_point(Vector3(-1.4, 1.1, -.3)), 70.0)
	hut.use("drawer")
	await _wait(.4)
	await _shot("08-drawer-locked-toast")
	hut.use("key")
	await _wait(.5)
	await _shot("09-key-taken")
	hut.use("drawer")
	await _wait(.9)
	await _shot("10-drawer-opening")
	await _wait(1.4)
	_place(_hut_point(Vector3(-.62, 1.9, -.3)), _hut_point(Vector3(-1.1, 1.0, -.31)), 60.0)
	await _wait(.3)
	await _shot("11-drawer-open-glock")
	# Inspect.
	hut.use("gun")
	await _wait(.5)
	await _shot("12-inspect")
	story.ui.rotate_view(1.2, -.25)
	await _wait(.3)
	await _shot("13-inspect-rotated")
	story.ui.rotate_view(-1.2, .25)
	story.ui._rack()
	await _wait(.12)
	await _shot("14-inspect-rack")
	await _wait(.5)
	if "--short" in OS.get_cmdline_user_args():
		quit(0)
		return
	story.ui.close_inspect(true)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(1.6)
	_place(_hut_point(Vector3(.6, 2.0, -.3)), _hut_point(Vector3(4.6, 1.5, .3)), 70.0)
	await _wait(.6)
	await _shot("15-called-outside")
	story.ui.advance()
	story.ui.advance()
	await _wait(1.2)
	await _shot("16-follow-me")
	story.ui.advance()
	story.ui.advance()
	# 0.11: the scarecrow's new spot, the dike and the buried box (he holds still in the yard meanwhile).
	var road: PackedVector2Array = main.get_node("Fields").get_meta("road_samples")
	var crow := main.get_node("Fields").find_child("Scarecrow", true, false) as Node3D
	var frame := hut.crow_frame()
	var centre: Vector3 = frame[0]
	var to_road: Vector3 = frame[1]
	var across := Vector3(-to_road.z, 0, to_road.x)
	stranger.process_mode = Node.PROCESS_MODE_DISABLED
	_place(hut.route_in[1] + Vector3(0, 1.58, 0), crow.global_position + Vector3.UP * 1.0, 62.0)
	await _wait(.6)
	await _shot("17a-scarecrow-from-hut-path")
	var ri := hut.crow_index - 10
	_place(Vector3(road[ri].x, -1.32, road[ri].y), crow.global_position + Vector3.UP * .9, 62.0)
	await _wait(.4)
	await _shot("17b-scarecrow-from-road")
	_place(hut.crow_route[0] + Vector3(0, 1.62, 0) + to_road * .5, centre + Vector3.UP * .6, 62.0)
	await _wait(.4)
	await _shot("17c-dike")
	var box_at := hut.box_spot()
	_place(box_at + to_road * -.55 + across * .35 + Vector3.UP * .55, box_at, 55.0)
	await _wait(.3)
	await _shot("17d-box-at-foot-close")
	_place(Vector3(road[hut.crow_index].x, -1.32, road[hut.crow_index].y), box_at, 40.0)
	await _wait(.3)
	await _shot("17e-box-hidden-from-road")
	stranger.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Step out; then follow him at a distance down the road.
	player.global_position = _hut_point(Vector3(5.5, 0.05, -.3))
	await _wait(.4)
	Engine.time_scale = 3.0
	var shots := 0
	var elapsed := 0.0
	while stranger.state in [InteriorStranger.State.AWAITING, InteriorStranger.State.LEADING] and elapsed < 60.0:
		var s := stranger.global_position
		var back := Vector3(sin(stranger._yaw), 0, cos(stranger._yaw))
		player.global_position = Vector3(s.x, -2.9, s.z) - back * 7.0
		camera.global_position = player.global_position + Vector3(0, 1.58, 0)
		camera.look_at(s + Vector3.UP * 1.2)
		elapsed += .016 * Engine.time_scale
		await process_frame
		if shots < 2 and stranger.state == InteriorStranger.State.LEADING and elapsed > 3.0 + shots * 5.0:
			Engine.time_scale = 1.0
			await _shot("18-following-%d" % shots)
			Engine.time_scale = 3.0
			shots += 1
	Engine.time_scale = 1.0
	# He reaches under the scarecrow: filmed from the islet, standing beside him.
	# From the islet's back edge, beside and behind him (the scarecrow's arms reach out along `across`).
	var beside := centre - to_road * 1.12 + across * .38
	_place(Vector3(beside.x, -3.06 + 1.58, beside.z), stranger.global_position + Vector3.UP * .4 + to_road * .3, 72.0)
	await _wait(.5)
	await _shot("19-digging-from-islet-a")
	while stranger.state == InteriorStranger.State.DIGGING and not stranger.has_box():
		await process_frame
	await _wait(.15)
	await _shot("19-digging-from-islet-b-box")
	# Back onto the dike: he walks the box over.
	var wait_at := hut.crow_route[1].lerp(hut.crow_route[2], .55)
	player.global_position = Vector3(wait_at.x, -2.9, wait_at.z)
	while stranger.state == InteriorStranger.State.DIGGING:
		camera.global_position = player.global_position + Vector3(0, 1.58, 0)
		camera.look_at(stranger.global_position + Vector3.UP * 1.1)
		await process_frame
	await _wait(.6)
	camera.look_at(stranger.global_position + Vector3.UP * 1.1)
	await _shot("20-bringing-box")
	while stranger.state == InteriorStranger.State.BRINGING:
		camera.look_at(stranger.global_position + Vector3.UP * 1.3)
		await process_frame
	while not stranger._released and stranger.state == InteriorStranger.State.GIVING:
		camera.look_at(stranger.global_position + Vector3.UP * 1.3 - (stranger.global_position - camera.global_position).normalized() * .3)
		if stranger._anim.current_animation == "hand_over" and stranger._anim.current_animation_position > InteriorStranger.HAND_OVER_RELEASE - .06:
			break
		await process_frame
	await _shot("21-hand-over-reach")
	await _wait(.7)
	await _shot("22-received-ammo")
	await _wait(1.4)
	await _shot("23-now-run")
	await _wait(1.5)
	if is_instance_valid(stranger):
		camera.look_at(stranger.global_position + Vector3.UP * 1.3)
	await _shot("24-sirens")
	# Back in town: the lamps die.
	_place(Vector3(21.6, -1.32, 33.0), Vector3(20.6, -.2, 47.0), 66.0)
	await _wait(.4)
	await _shot("25-street-b-lamps-dying")
	await _wait(5.0)
	await _shot("26-street-b-moon-only")
	_place(Vector3(21.0, -1.32, 62.0), Vector3(19.0, -1.6, 110.0), 70.0)
	await _wait(.5)
	await _shot("27-road-moon-only")
	print("HUT_VIEWS lamps lit after: ", story.lamps_lit(), " ammo ", story.ammo, " gun ", story.has_gun)
	quit(0)
