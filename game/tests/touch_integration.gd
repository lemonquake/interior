extends SceneTree

var checks := 0
var failures: Array[String] = []
var results: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame

func _finger(touch: InteriorTouchControls, index: int, position: Vector2, pressed := true) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	touch._input(event)

func _drag(touch: InteriorTouchControls, index: int, position: Vector2, relative := Vector2.ZERO) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	touch._input(event)

func _button(touch: InteriorTouchControls, label: String) -> Button:
	for button in touch._buttons:
		if button.text == label:
			return button
	return null

func _menu_button(main: Node, label: String) -> Button:
	for child in main.menu_content.get_children():
		if child is Button and child.text == label:
			return child
	return null

func _control_count(node: Node) -> int:
	var count := 1 if node is InteriorTouchControls else 0
	for child in node.get_children():
		count += _control_count(child)
	return count

func _clear_inputs(touch: InteriorTouchControls, player: InteriorPlayer) -> bool:
	return touch.move_finger == -1 and touch.look_finger == -1 and touch._button_fingers.is_empty() and player.touch_move == Vector2.ZERO and not player.touch_sprinting and not player.touch_crouching

func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var main = packed.instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(3)
	check(main.mobile and not main.control_lab, "Launch with --mobile-test must cold-load the production room in mobile mode")
	check(paused and main.current_menu == "home" and not main.touch.enabled, "Cold-start home menu must keep touch movement disabled")
	_menu_button(main, "Play").pressed.emit()
	await _frames(12)
	var touch: InteriorTouchControls = main.touch
	var player: InteriorPlayer = main.player
	check(not paused and player.playing and touch.enabled and touch.visible, "Play button must enable the actual mobile controls")
	check(touch._buttons.size() == 7 and _control_count(main) == 1, "Production scene must have one touch controller with exactly seven buttons")
	check(player.is_on_floor(), "Integrated touch movement must begin on the actual room floor")
	var move_origin := Vector2(110, touch.size.y - 115)
	var look_origin := Vector2(touch.size.x * 0.56, touch.size.y * 0.35)
	var sprint_point := _button(touch, "Sprint").get_global_rect().get_center()
	var jump_point := _button(touch, "Jump").get_global_rect().get_center()
	var crouch_point := _button(touch, "Crouch").get_global_rect().get_center()
	_finger(touch, 1, move_origin)
	_finger(touch, 2, look_origin)
	_drag(touch, 1, move_origin + Vector2(0, -touch.radius))
	var initial_yaw := player.rotation.y
	var initial_pitch := player.camera.rotation.x
	_drag(touch, 2, look_origin + Vector2(12, -4), Vector2(12, -4))
	check(touch.move_finger == 1 and touch.look_finger == 2 and player.touch_move.length() > 0.99, "Independent move and look fingers must be tracked simultaneously")
	check(player.rotation.y < initial_yaw and player.camera.rotation.x > initial_pitch, "Right-finger dragging must turn the actual player and camera while moving")
	_finger(touch, 3, sprint_point)
	_finger(touch, 6, sprint_point)
	await _frames(2)
	var first_speed := Vector2(player.velocity.x, player.velocity.z).length()
	await _frames(8)
	var accelerated_speed := Vector2(player.velocity.x, player.velocity.z).length()
	check(player.touch_sprinting and first_speed > 0.01 and accelerated_speed > first_speed + 0.5, "Held mobile sprint must accelerate the actual character across physics frames")
	_finger(touch, 4, jump_point)
	await _frames(3)
	check(player.velocity.y > 3.0 and not player.is_on_floor() and touch.move_finger == 1 and touch.look_finger == 2, "Jump finger must launch the player while move, look, and sprint remain held")
	_finger(touch, 5, crouch_point)
	await _frames(2)
	check(player.crouching and player.touch_crouching and player.touch_sprinting and touch.move_finger == 1 and touch.look_finger == 2, "Crouch finger must change the capsule without stealing the other active controls")
	check(touch._crouch_button.text == "Stand" and touch._crouch_button.button_pressed, "Crouch button must show its current toggle state")
	_finger(touch, 3, Vector2.ZERO, false)
	check(player.touch_sprinting and touch._button_fingers.has(6), "Releasing one sprint finger outside the button must preserve the second sprint finger")
	_finger(touch, 6, Vector2.ZERO, false)
	check(not player.touch_sprinting and player.touch_crouching and player.touch_move.length() > 0.99 and touch.look_finger == 2, "Releasing the final sprint finger must preserve move, look, and crouch")
	_finger(touch, 4, Vector2.ZERO, false)
	_finger(touch, 5, Vector2.ZERO, false)
	_finger(touch, 1, Vector2.ZERO, false)
	check(player.touch_move == Vector2.ZERO and touch.move_finger == -1 and touch.look_finger == 2 and player.touch_crouching, "Releasing movement must stop its input while look and crouch remain active")
	_finger(touch, 2, Vector2.ZERO, false)
	var released_yaw := player.rotation.y
	_drag(touch, 2, look_origin, Vector2(100, 100))
	check(touch.look_finger == -1 and is_equal_approx(player.rotation.y, released_yaw), "A released look finger must not turn the camera through stale drag events")
	_finger(touch, 1, move_origin)
	_drag(touch, 1, move_origin + Vector2(0, -touch.radius))
	_finger(touch, 2, look_origin)
	_finger(touch, 3, sprint_point)
	_finger(touch, 7, _button(touch, "Pause").get_global_rect().get_center())
	check(paused and main.current_menu == "pause" and not player.playing and not touch.enabled, "Touch Pause must invoke the production pause menu and disable gameplay input")
	check(_clear_inputs(touch, player), "Pause must clear every move, look, sprint, crouch, and button finger")
	var paused_position := player.global_position
	var paused_yaw := player.rotation.y
	_finger(touch, 1, move_origin)
	_drag(touch, 1, move_origin + Vector2(0, -touch.radius))
	_finger(touch, 2, look_origin)
	_drag(touch, 2, look_origin, Vector2(100, 100))
	await _frames(4)
	check(player.global_position.is_equal_approx(paused_position) and is_equal_approx(player.rotation.y, paused_yaw) and _clear_inputs(touch, player), "Disabled touch events must not move or turn the paused player")
	_menu_button(main, "Resume").pressed.emit()
	await _frames(3)
	check(not paused and player.playing and touch.enabled and _clear_inputs(touch, player), "Resume must enable clean controls without restoring stale held fingers")
	check(touch._crouch_button.text == "Crouch" and not touch._crouch_button.button_pressed and not touch._sprint_button.button_pressed and not player.crouching, "Resume must restore standing controls and clear both toggle visuals")
	# Reload the actual scene through the menu's Restart callback twice. Verify
	# new control ownership and signal wiring, not a reset helper or mock scene.
	for cycle in 2:
		var previous_control_id := touch.get_instance_id()
		_finger(touch, 1, move_origin)
		_drag(touch, 1, move_origin + Vector2(0, -touch.radius))
		_finger(touch, 7, _button(touch, "Pause").get_global_rect().get_center())
		_menu_button(main, "Restart").pressed.emit()
		await _frames(5)
		main = current_scene
		touch = main.touch
		player = main.player
		check(main.mobile and main.current_menu == "home" and paused and not player.playing and touch.get_instance_id() != previous_control_id, "Restart must replace the actual mobile room and return to its home menu")
		check(_control_count(root) == 1 and touch._buttons.size() == 7 and touch.get_child_count() == 7, "Restart must retain exactly one touch controller and seven buttons without duplicates")
		var single_connections := touch.pause_pressed.get_connections().size() == 1 and touch.hold_pressed.get_connections().size() == 1
		for button in touch._buttons:
			single_connections = single_connections and button.pressed.get_connections().size() == 1
		check(single_connections and _clear_inputs(touch, player), "Reloaded controls must have one callback per signal and no stale fingers")
		_menu_button(main, "Play").pressed.emit()
		await _frames(4)
		_finger(touch, 5, _button(touch, "Crouch").get_global_rect().get_center())
		await _frames(2)
		check(touch.enabled and player.crouching and player.touch_crouching, "Reloaded Crouch must toggle once through its actual button callback")
		_finger(touch, 5, Vector2.ZERO, false)
	results = {"mobile_mode":main.mobile, "buttons":touch._buttons.size(), "actual_scene_restarts":2, "first_sprint_speed_m_s":first_speed, "later_sprint_speed_m_s":accelerated_speed, "viewport":str(root.get_visible_rect().size)}
	paused = false
	main.queue_free()
	await _frames(3)
	check(_control_count(root) == 0, "Final scene teardown must release the integrated touch controller")
	print("INTERIOR_TOUCH_INTEGRATION ", JSON.stringify({"passed":failures.is_empty(), "checks":checks, "failures":failures, "results":results}))
	quit(0 if failures.is_empty() else 1)
