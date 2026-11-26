extends SceneTree
## 0.10: the hut sequence (scripts/hut_house.gd, story.gd, stranger.gd), headless:
## - the hut faces the road; its footpath, steps, floor and walls are solid; the road wall is open at the path;
## - the player can walk from the road up the footpath, into the hut and out again (real player physics);
## - the stranger, set running from pole 9, turns into the hut and hides inside;
## - the key, the locked drawer, unlocking, the drawer sliding open on the gun, the inspect screen (Put back keeps
##   the gun; OK takes it), the call-out dialogue, following him to the scarecrow, the ammo (60), "Now... run.",
##   sirens, every street lamp out, and reaching home.
##   godot --headless --path game --script res://tests/hut_story_integration.gd --fixed-fps 60

var checks := 0
var failures: Array[String] = []
var results := {}
var main: Node
var player: InteriorPlayer
var stranger: InteriorStranger
var story: InteriorStory
var hut: InteriorHutHouse

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
	print(("PASS " if condition else "FAIL ") + message)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _state() -> String:
	return InteriorStranger.State.keys()[stranger.state] if is_instance_valid(stranger) else "FREED"

func _wait_state(want: Array, max_frames: int) -> int:
	for i in max_frames:
		if _state() in want:
			return i
		await physics_frame
	return -1

## Walks the real player toward `target` (xz) with its own physics; returns the closest distance reached.
func _walk_to(target: Vector3, max_frames := 600, run := false) -> float:
	var best := INF
	for i in max_frames:
		var to := target - player.global_position
		to.y = 0.0
		best = minf(best, to.length())
		if to.length() < .3:
			break
		player.rotation.y = atan2(-to.x, -to.z)
		player.touch_move = Vector2(0, -1)
		player.touch_sprinting = run
		await physics_frame
	player.touch_move = Vector2.ZERO
	player.touch_sprinting = false
	await _frames(3)
	return best

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(4)
	player = main.player
	stranger = main.get_node_or_null("Stranger") as InteriorStranger
	story = main.story
	check(story != null, "The story is running")
	if story == null:
		_finish()
		return
	hut = story.hut
	check(main.mobile == false, "Desktop run")
	# 1. The hut faces the road.
	var road: PackedVector2Array = main.get_node("Fields").get_meta("road_samples")
	var door_dir := hut.global_transform.basis.x
	var to_road := Vector3(road[hut.road_index].x, 0, road[hut.road_index].y) - hut.global_position
	to_road.y = 0.0
	check(door_dir.normalized().dot(to_road.normalized()) > .97, "The hut's doorway faces the road")
	check(hut.route_in.size() >= 6, "The stranger has a way into the hut (%d points)" % hut.route_in.size())
	var lantern := main.get_node("Fields").find_child("HutLanternLight", true, false) as OmniLight3D
	check(lantern.light_cull_mask & 2 != 0, "The hut lantern lights the outdoor layer")
	check(hut.candle_light.light_cull_mask & 2 != 0, "The candle lights the outdoor layer")
	# 2. Walk from the road up the footpath into the hut and back out, with real physics.
	var start := hut.route_in[0]
	player.reset_motion(Vector3(start.x, -2.75, start.z - 2.0))
	await _frames(20)
	var reached := INF
	for k in range(1, hut.route_in.size()):
		reached = await _walk_to(hut.route_in[k], 500)
	results["walk_in_last_gap_m"] = snappedf(reached, .01)
	check(hut.is_inside(player.global_position), "The player walks from the road along the footpath, up the steps and into the hut (%s)" % player.global_position)
	check(player.global_position.y > -2.75, "Inside, the player stands on the hut floor (y %.2f)" % player.global_position.y)
	# Walls hold: walking at the back wall stops at it.
	await _walk_to(hut.global_transform * Vector3(-3.0, 0, -.3), 150)
	var local := hut.global_transform.affine_inverse() * player.global_position
	check(local.x > InteriorHutHouse.BACK, "The back wall stops the player (local x %.2f)" % local.x)
	await _walk_to(hut.global_transform * Vector3(-3.0, 0, 1.2), 150)
	local = hut.global_transform.affine_inverse() * player.global_position
	check(local.z < InteriorHutHouse.SIDE_POS and local.x > InteriorHutHouse.BACK, "The side walls and furniture stop the player (local %s)" % local)
	await _walk_to(hut.global_transform * Vector3(0.4, 0, -.3), 200)
	await _walk_to(hut.door_point(), 300)
	await _walk_to(hut.global_transform * Vector3(5.0, 0, -.3), 200)
	check(not hut.is_inside(player.global_position) and player.global_position.y > -3.3, "The player walks back out and down the steps (y %.2f)" % player.global_position.y)
	# The yard edge and the footpath edges hold (no falling into the paddy).
	await _walk_to(hut.global_transform * Vector3(9.0, 0, 6.0), 240)
	check(player.global_position.y > -3.3, "The yard edge keeps the player out of the paddy (y %.2f)" % player.global_position.y)
	await _walk_to(hut.global_transform * Vector3(0, 0, -.3), 400)
	# 3. The stranger (0.23) crouches out through the hole in the town wall, runs into the hut and hides.
	if stranger != null:
		stranger.to_hole()
		player.reset_motion(Vector3(21.3, -2.75, 46.0))
		await _frames(3)
		check(await _wait_state(["CRAWLING"], 90) >= 0, "Close to the hole, he crouches through it")
		check(await _wait_state(["FLEEING"], 400) >= 0, "Out on the dirt road he runs")
		player.reset_motion(hut.global_transform * Vector3(-.5, .5, 1.0))  # out of the way, inside
		var turned := false
		for i in 3600:
			await physics_frame
			if _state() == "HIDDEN":
				break
			var p := stranger.global_position
			if Vector2(p.x - hut.route_in[1].x, p.z - hut.route_in[1].z).length() < 1.0:
				turned = true
		check(turned, "He turns off the road onto the footpath")
		check(_state() == "HIDDEN" and not stranger.visible, "He runs into the hut and disappears (%s)" % _state())
		check(hut.is_inside(stranger.global_position), "He disappears inside, behind the walls")
	# 4. Key and drawer.
	player.reset_motion(hut.global_transform * Vector3(-.6, .5, -.3))
	await _frames(10)
	check(hut.usable_prompt("drawer") == "Locked drawer", "The drawer is locked")
	hut.use("drawer")
	await _frames(2)
	check(story.ui.last_notification().begins_with("It's locked"), "Trying the drawer without the key says it's locked")
	check(not hut.drawer_open, "Without the key it stays shut")
	# Aim at the key and press Hold, as the player would.
	var key := hut.get_node("Key") as Node3D
	await _aim(key.global_position + Vector3(0, .02, 0))
	check(player.door_target != null and player.door_target.is_in_group("usables"), "The key is targeted by the crosshair")
	check(main.prompt.text.contains("Take the key"), "The prompt offers the key (%s)" % main.prompt.text)
	player.hold_pressed()
	player.hold_released()
	await _frames(3)
	check(story.has_key and story.ui.last_notification() == "You now have the key.", "Taking the key: \"You now have the key.\"")
	check(main.prompt.text == "" or not main.prompt.text.contains("key"), "The key is gone from the dresser")
	await _aim(hut.get_node("Dresser/TopDrawer").global_position + Vector3(.02, .1, 0))
	check(main.prompt.text.contains("Unlock the drawer"), "With the key, the drawer offers to unlock (%s)" % main.prompt.text)
	var closed_x := (hut.get_node("Dresser/TopDrawer") as Node3D).position.x
	player.hold_pressed()
	player.hold_released()
	await _frames(150)
	var opened := (hut.get_node("Dresser/TopDrawer") as Node3D).position.x - closed_x
	check(hut.drawer_open and opened > .25, "Unlocking slides the drawer open (%.2f m)" % opened)
	# 5. The gun and the inspect screen.
	await _aim(hut.get_node("Dresser/TopDrawer/GunUse/GunBody").global_position)
	var hit := player.ray_hit(InteriorPlayer.REACH, 6)
	var gun_body := hut.get_node("Dresser/TopDrawer/GunUse/GunBody") as StaticBody3D
	print("  gun aim hit ", hit.get("collider"), " ", (hit.get("collider") as Node).get_path() if hit.has("collider") else "", " gun body mode ", gun_body.process_mode, " in tree ", gun_body.is_inside_tree(), " eye ", player.camera.global_position)
	check(main.prompt.text.contains("Pick up the Glock"), "The open drawer offers the Glock (%s)" % main.prompt.text)
	player.hold_pressed()
	player.hold_released()
	await _frames(3)
	check(story.ui.inspect_active() and not player.playing, "Picking it up shows it on screen (player paused)")
	story.ui.rotate_view(.8, .2)
	story.ui._rack()
	await _frames(20)
	story.ui.close_inspect(false)
	await _frames(3)
	check(not story.has_gun and player.playing and not hut.gun_taken, "Put back: the gun stays in the drawer")
	hut.use("gun")
	await _frames(2)
	story.ui.close_inspect(true)
	await _frames(3)
	check(story.has_gun and hut.gun_taken, "OK: the player takes the Glock")
	check(story.inventory_label.text.contains("Glock 17"), "The inventory shows the Glock (%s)" % story.inventory_label.text)
	# 5b. 0.12: the flashlight beside it.
	check(hut.has_node("Dresser/TopDrawer/Flashlight"), "A flashlight lies in the drawer beside the Glock")
	await _aim(hut.get_node("Dresser/TopDrawer/FlashlightUse/FlashlightBody").global_position)
	check(main.prompt.text.contains("Pick up the flashlight"), "The open drawer offers the flashlight (%s)" % main.prompt.text)
	check(not story.flashlight.owned and not story.flashlight.light.visible, "No flashlight before it is taken")
	player.hold_pressed()
	player.hold_released()
	await _frames(3)
	check(story.has_flashlight and hut.flashlight_taken and story.flashlight.owned, "E takes the flashlight")
	check(story.ui.last_notification().contains("flashlight"), "\"%s\"" % story.ui.last_notification())
	check(story.inventory_label.text.contains("Flashlight"), "The inventory shows the flashlight (%s)" % story.inventory_label.text)
	check(not hut.has_node("Dresser/TopDrawer/Flashlight"), "The flashlight is gone from the drawer")
	var press := InputEventAction.new()
	press.action = "flashlight"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(12)
	var beam := story.flashlight.light
	var ahead := -player.camera.global_transform.basis.z
	check(story.flashlight.on and beam.visible and beam.light_energy > 3.0, "L switches it on (energy %.2f)" % beam.light_energy)
	check(beam.light_cull_mask & 3 == 3, "The beam lights indoor and outdoor layers")
	check(beam.global_position.distance_to(player.camera.global_position) < .4 and (-beam.global_transform.basis.z).dot(ahead) > .97, "The beam rides at the eye and points where the player looks")
	results["flashlight_energy"] = beam.light_energy
	var release := InputEventAction.new()
	release.action = "flashlight"
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)
	Input.parse_input_event(press)
	await _frames(2)
	check(not story.flashlight.on and not beam.visible, "L again switches it off")
	Input.parse_input_event(release)
	story.flashlight.set_on(true)  # on for the walk to the scarecrow
	# 6. Called outside.
	await _frames(90)
	check(_state() == "CALLING" and stranger.visible, "He calls the player out from the yard (%s)" % _state())
	check(story.ui.dialogue_active() and story.ui.current_line() == InteriorStory.CALL_LINES[0], "Line 1: %s" % story.ui.current_line())
	player.hold_pressed()  # E finishes typing
	player.hold_pressed()  # E: next line
	await _frames(2)
	check(story.ui.current_line() == InteriorStory.CALL_LINES[1], "Line 2: %s" % story.ui.current_line())
	player.hold_pressed()
	player.hold_pressed()
	await _frames(2)
	check(story.ui.current_line() == InteriorStory.CALL_LINES[2], "Line 3: %s" % story.ui.current_line())
	player.hold_pressed()
	player.hold_pressed()
	await _frames(2)
	check(not story.ui.dialogue_active(), "The dialogue closes")
	await _frames(30)
	check(_state() == "AWAITING", "He waits while the player is inside (%s)" % _state())
	# 7. Out of the hut: he leads. Follow him at about 8 m; check he waits when the player drops back.
	player.reset_motion(hut.global_transform * Vector3(5.2, .3, -.3))
	await _frames(10)
	check(await _wait_state(["LEADING"], 60) >= 0, "Outside, he runs (\"Follow me\")")
	# 0.11: the scarecrow is near: within 60 m of the hut path along the road, on its own dike.
	var crow_along := 0.0
	for k in range(mini(hut.road_index, hut.crow_index), maxi(hut.road_index, hut.crow_index)):
		crow_along += road[k].distance_to(road[k + 1])
	results["scarecrow_past_hut_path_m"] = snappedf(crow_along, .1)
	check(hut.crow_index >= 0 and crow_along < 60.0, "The scarecrow is within 60 m of the hut path along the road (%.1f m)" % crow_along)
	check(hut.crow_route.size() == 4, "A dike leads from the road to the scarecrow's islet")
	var lead_frames := 0
	var waited := false
	var frames := 0
	var log_every := 0
	while _state() == "LEADING" and frames < 60 * 120:
		frames += 1
		if not stranger._paused_for_player:
			lead_frames += 1
		var s := stranger.global_position
		if frames == 300:
			# Drop back 30 m: he should stop and wait.
			var back := Vector3(sin(stranger._yaw), 0, cos(stranger._yaw))
			player.reset_motion(Vector3(s.x, -2.75, s.z) - back * 30.0)
			for i in 30:
				await physics_frame
			waited = stranger._paused_for_player
		elif frames % 20 == 0:
			var back := Vector3(sin(stranger._yaw), 0, cos(stranger._yaw))
			var follow := Vector3(s.x, -2.75, s.z) - back * 8.0
			if not stranger._wading:
				player.reset_motion(follow)
		log_every += 1
		if log_every % 600 == 0:
			print("  leading ", stranger.global_position, " paused ", stranger._paused_for_player, " wading ", stranger._wading, " path ", stranger.path.size())
		await physics_frame
	check(waited, "He stops and waits when the player falls far behind")
	check(_state() == "DIGGING", "He reaches the scarecrow and digs under it (%s after %d frames)" % [_state(), frames])
	results["lead_seconds"] = snappedf(lead_frames / 60.0, .1)
	check(lead_frames < 25 * 60, "Following, he reaches the scarecrow in under 25 s (%.1f s)" % (lead_frames / 60.0))
	var crow := main.get_node("Fields").find_child("Scarecrow", true, false) as Node3D
	results["dig_from_scarecrow_m"] = snappedf(Vector2(stranger.global_position.x - crow.global_position.x, stranger.global_position.z - crow.global_position.z).length(), .01)
	check(results["dig_from_scarecrow_m"] < 1.4, "He is at the scarecrow's foot (%.2f m)" % results["dig_from_scarecrow_m"])
	check(crow.get_parent() != null and main.get_node("Fields").crow_frozen, "The scarecrow holds still while he digs")
	# The real player walks from the road along the dike onto the islet, next to the scarecrow (he holds still).
	stranger.process_mode = Node.PROCESS_MODE_DISABLED
	player.reset_motion(hut.crow_route[0] + Vector3(0, .15, 0))
	await _frames(5)
	for k in [1, 2]:
		await _walk_to(hut.crow_route[k], 400)
	var frame := hut.crow_frame()
	var beside: Vector3 = frame[0] + frame[1] * .75 + Vector3(-frame[1].z, 0, frame[1].x) * .55
	await _walk_to(beside, 300)
	var on_islet := Vector2(player.global_position.x - frame[0].x, player.global_position.z - frame[0].z).length()
	results["player_from_scarecrow_m"] = snappedf(on_islet, .01)
	check(on_islet < 1.3 and player.global_position.y > -3.15, "The player walks from the road along the dike onto the islet beside the scarecrow (%.2f m, y %.2f)" % [on_islet, player.global_position.y])
	await _walk_to(frame[0] - frame[1] * 3.0, 120)
	var kept := Vector2(player.global_position.x - frame[0].x, player.global_position.z - frame[0].z).length()
	check(kept < InteriorHutHouse.ISLET_TOP + .2 and player.global_position.y > -3.15, "The islet's edge keeps the player out of the paddy (%.2f m)" % kept)
	# Then waits at the islet's end of the dike, so he has to bring the box a few steps.
	await _walk_to(hut.crow_route[1].lerp(hut.crow_route[2], .7), 300)
	stranger.process_mode = Node.PROCESS_MODE_PAUSABLE
	var giving := -1
	var carried := false
	var carried_by_hand := false
	for i in 60 * 30:
		if _state() in ["GIVING", "LEAVING"]:
			giving = i
			break
		if _state() == "BRINGING" and stranger.has_box():
			carried = true
			var node: Node = stranger._box
			while node != null and not node is BoneAttachment3D:
				node = node.get_parent()
			carried_by_hand = carried_by_hand or (node != null and (node as BoneAttachment3D).bone_name == "hand.R")
		if i % 120 == 0:
			print("  bringing ", _state(), " ", stranger.global_position, " wading ", stranger._wading, " speed ", stranger.speed)
		await physics_frame
	check(carried and carried_by_hand, "He carries the box in his right hand (hand.R) while bringing it")
	check(giving >= 0, "He brings the box back to the player (%s)" % _state())
	var ammo_before_release := -1
	for i in 60 * 4:
		if stranger._released:
			break
		ammo_before_release = story.ammo
		await physics_frame
	check(ammo_before_release == 0, "No rounds before the hand-over's release frame (%d)" % ammo_before_release)
	await _frames(150)
	check(not is_instance_valid(stranger._box) and not is_instance_valid(hut.ammo_box), "The box is gone after the hand-over")
	check(story.ammo == 60 and story.ui.last_notification().contains("Received 60 Glock ammo"), "\"Received 60 Glock ammo\" (%d)" % story.ammo)
	await _frames(60)
	check(story.ui.dialogue_active() and story.ui.current_line() == InteriorStory.RUN_LINE, "Return-home warning: %s" % story.ui.current_line())
	await _frames(60 * 2)
	check(story.lights_out and story._sirens.size() == 4, "Sirens start all over (%d)" % story._sirens.size())
	var playing := 0
	for siren in story._sirens:
		playing += 1 if siren.playing else 0
	check(playing == 4, "All sirens are playing (%d)" % playing)
	check(main.status_label.text == "Get back home.", "Objective: %s" % main.status_label.text)
	await _frames(60 * 8)
	check(story.lamps_lit() == 0, "Every street lamp is out (%d lit)" % story.lamps_lit())
	await _frames(60 * 3)
	check(_state() in ["LEAVING", "FREED"], "He runs off (%s)" % _state())
	# 8. Home.
	player.reset_motion(Vector3(10.0, -2.75, 4.0))
	await _frames(10)
	check(story.phase == InteriorStory.Phase.RUN_HOME and story._sirens[0].playing, "Courtyard does not stop the alarm")
	var door: InteriorHingedDoor = main.entry_door()
	door.toggle()
	await _frames(65)
	player.reset_motion(Vector3(1.5, .05, 1.0))
	await _frames(10)
	check(story.phase == InteriorStory.Phase.RUN_HOME and story._sirens[0].playing and main.status_label.text == "Close the door.", "Indoors with the door open: sirens continue")
	door.toggle()
	await _frames(2)
	check(story.phase == InteriorStory.Phase.RUN_HOME, "Sirens continue during the door swing")
	await _frames(80)
	check(story.phase == InteriorStory.Phase.HOME and main.status_label.text == "You made it home.", "Inside with the door fully closed: home")
	var stopped := true
	for siren in story._sirens:
		stopped = stopped and not siren.playing
	check(stopped, "All four siren streams stop completely")
	door.toggle()
	await _frames(70)
	check(not story._sirens[0].playing, "Opening the door again does not restart the alarm")
	_finish()

func _aim(at: Vector3) -> void:
	var eye := player.camera.global_position
	var to := at - eye
	player.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
	player.set("_look_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
	player.camera.rotation.x = player.get("_look_pitch")
	await _frames(3)
	player.update_target()
	main._on_target_changed(player.target)

func _finish() -> void:
	print("HUT_STORY ", JSON.stringify({"checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
