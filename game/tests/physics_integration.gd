extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	main.control_lab = true
	root.add_child(main)
	main._play()
	await physics_frame
	await physics_frame
	var player: InteriorPlayer = main.player
	var body: InteriorObject = main.get_node("Clue2")
	player.grab_object(body)
	check(player.held == body and body.held, "Hold must select an object")
	check(body.get_collision_exceptions().has(player), "Held object must exclude player collision")
	check(body.collision_mask & 2 != 0, "Held object must retain wall collision")
	player.toggle_hold()
	check(player.held == null and not body.held, "Same hold key must drop")
	check(not body.get_collision_exceptions().has(player), "Drop must restore player collision")
	player.grab_object(body)
	player.throw_object()
	await physics_frame
	await physics_frame
	check(player.held == null, "Throw must release object")
	check(body.linear_velocity.length() > 2.0, "Throw must impart velocity")
	# Dormant furnishings must wake on a real rigid-body impact.
	var dormant := InteriorObject.new()
	main.add_child(dormant)
	dormant.position = Vector3(-2.0,1.5,1.2)
	main._box(dormant,Vector3.ZERO,Vector3(.3,.3,.3),Color.WHITE)
	dormant.dormant = true
	dormant.freeze = true
	var striker := InteriorObject.new()
	main.add_child(striker)
	striker.position = Vector3(-2.0,1.5,1.85)
	striker.gravity_scale = 0.0
	main._box(striker,Vector3.ZERO,Vector3(.3,.3,.3),Color.WHITE)
	striker.linear_velocity = Vector3(0,0,-3)
	for i in 30:
		await physics_frame
	check(not dormant.freeze and not dormant.dormant,"Thrown objects must wake dormant furnishings on impact")
	dormant.anchored = true
	dormant.freeze = true
	dormant.activate()
	check(dormant.freeze,"An impact must preserve a wall attachment")
	dormant.activate(true)
	check(not dormant.freeze,"Grabbing must detach a wall attachment")
	dormant.queue_free()
	striker.queue_free()
	main._show_menu("pause")
	check(not player.playing and paused, "Pause must stop gameplay")
	main._play()
	check(player.playing and not paused, "Resume must restore gameplay")
	check(main.clues.size() == 1, "Repeated grabs must not duplicate clue discovery")
	main.try_unlock("508")
	check(not main.solved, "Code alone must not bypass finding notes")
	main._on_grabbed(main.get_node("Clue1"))
	main._on_grabbed(main.get_node("Clue3"))
	main.try_unlock("999")
	check(not main.solved, "Wrong code must not unlock recording")
	main.try_unlock("508")
	check(main.solved, "All clues and correct code must solve mystery")
	# A real physics ray must stop at intervening static structure.
	body.global_position = player.camera.global_position - Vector3(0,0,1.4)
	body.freeze = true
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 2
	main.add_child(blocker)
	blocker.global_position = player.camera.global_position - Vector3(0,0,0.75)
	main._box(blocker,Vector3.ZERO,Vector3(0.65,0.65,0.10),Color.WHITE)
	await physics_frame
	await physics_frame
	player.update_target()
	check(player.target == null, "Grab ray must not select through a wall")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	player.update_target()
	check(player.target == body, "Unobstructed grab ray must select the object")
	body.freeze = false
	main.touch.set_enabled(true)
	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 1
	touch_down.position = Vector2(80, 550)
	touch_down.pressed = true
	main.touch._input(touch_down)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(130, 500)
	main.touch._input(drag)
	check(player.touch_move.length() > 0.1 and player.touch_move.length() <= 1.01, "Mobile movement must be bounded")
	var look_touch := InputEventScreenTouch.new()
	look_touch.index = 2
	look_touch.position = Vector2(820,300)
	look_touch.pressed = true
	main.touch._input(look_touch)
	check(main.touch.move_finger == 1 and main.touch.look_finger == 2, "Mobile move and look must support two fingers")
	look_touch.pressed = false
	main.touch._input(look_touch)
	check(player.touch_move.length() > 0.1, "Releasing look finger must preserve movement")
	player.grab_object(body)
	main.mobile = true
	var emulated_click := InputEventMouseButton.new()
	emulated_click.button_index = MOUSE_BUTTON_LEFT
	emulated_click.pressed = true
	player._unhandled_input(emulated_click)
	check(player.held == body,"Touch-generated mouse clicks must not throw held objects")
	var throw_touch := InputEventScreenTouch.new()
	throw_touch.index = 3
	throw_touch.position = main.touch._buttons[1].get_global_rect().get_center()
	throw_touch.pressed = true
	main.touch._input(throw_touch)
	check(player.held == null and player.touch_move.length() > .1,"Another finger must throw while the movement finger stays held")
	main.mobile = false
	touch_down.pressed = false
	main.touch._input(touch_down)
	check(player.touch_move == Vector2.ZERO, "Finger release must stop mobile movement")
	main.touch.set_enabled(false)
	main.player.playing = false
	paused = false
	body.global_position.y = -6
	body.recover()
	check(body.global_transform.is_equal_approx(body.home_transform), "Dropped objects must recover from bounds")
	print("INTERIOR_INTEGRATION ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"checks":checks,"scene":"control lab"}))
	quit(0 if failures.is_empty() else 1)
