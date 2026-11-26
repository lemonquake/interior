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

func _shown(touch: InteriorTouchControls) -> int:
	var count := 0
	for button in touch._buttons:
		count += 1 if button.visible else 0
	return count

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
	# 0.64: the phone-shooter layout. Shown from the start: THROW (FIRE once a gun is drawn), JUMP, CROUCH, SHOVE, the
	# two LEANs and PAUSE; the rest only once they apply (USE and INSPECT when there is something to use).
	var always := ["THROW", "JUMP", "CROUCH", "SHOVE", "< LEAN", "LEAN >", "PAUSE"]
	var later := ["ADS", "RELOAD", "GRENADE", "MEDKIT", "DROP", "CHAT", "GUN", "SWAP", "LIGHT", "BIND", "FIRE"]
	var layout_ok := touch._buttons.size() == 20 and _control_count(main) == 1
	for label: String in always:
		layout_ok = layout_ok and _button(touch, label) != null and _button(touch, label).visible
	for label: String in later:
		layout_ok = layout_ok and _button(touch, label) != null and not _button(touch, label).visible
	check(layout_ok, "Production scene must have one touch controller: the always-shown buttons up, the rest hidden until they apply")
	# Round buttons, see-through: none of them a wide box.
	var round_ok := true
	for b: Button in touch._buttons:
		var box := b.get_global_rect()
		round_ok = round_ok and (absf(box.size.x - box.size.y) < .5 or b.text in ["GUN", "HOLSTER", "SWAP", "MEDKIT", "DROP"])
	check(round_ok, "Touch buttons are round (the weapon row is pills)")
	var lean_point := _button(touch, "LEAN >").get_global_rect().get_center()
	_finger(touch, 12, lean_point)
	check(player.touch_peek == 1.0, "A finger on LEAN > must lean right")
	_finger(touch, 12, lean_point, false)
	check(player.touch_peek == 0.0, "...until it lifts")
	touch.set_wound_state(true)
	var bind_point := _button(touch, "BIND").get_global_rect().get_center()
	_finger(touch, 12, bind_point)
	check(touch._bind_button.visible and player.touch_binding, "BIND shows with a wound open and holds while pressed")
	_finger(touch, 12, bind_point, false)
	touch.set_wound_state(false)
	check(not touch._bind_button.visible and not player.touch_binding, "...and goes when the wound is shut")
	check(player.is_on_floor(), "Integrated touch movement must begin on the actual room floor")
	var move_origin := Vector2(130, touch.size.y - 130)
	var look_origin := Vector2(touch.size.x * 0.56, touch.size.y * 0.35)
	var jump_point := _button(touch, "JUMP").get_global_rect().get_center()
	var crouch_point := _button(touch, "CROUCH").get_global_rect().get_center()
	# A light push on the stick is the quiet walk; all the way forward sprints.
	_finger(touch, 1, move_origin)
	_drag(touch, 1, move_origin + Vector2(0, -touch.radius * .3))
	check(player.touch_sneaking and not player.touch_sprinting and player.touch_move.length() > .2, "A light push on the stick must be the quiet walk")
	_drag(touch, 1, move_origin + Vector2(0, -touch.radius * .7))
	check(not player.touch_sneaking and not player.touch_sprinting, "A middle push must be the ordinary walk")
	_finger(touch, 2, look_origin)
	_drag(touch, 1, move_origin + Vector2(0, -touch.radius))
	var initial_yaw := player.rotation.y
	var initial_pitch := player.camera.rotation.x
	_drag(touch, 2, look_origin + Vector2(12, -4), Vector2(12, -4))
	check(touch.move_finger == 1 and touch.look_finger == 2 and player.touch_move.length() > 0.99, "Independent move and look fingers must be tracked simultaneously")
	check(player.rotation.y < initial_yaw and player.camera.rotation.x > initial_pitch, "Right-finger dragging must turn the actual player and camera while moving")
	await _frames(2)
	var first_speed := Vector2(player.velocity.x, player.velocity.z).length()
	await _frames(8)
	var accelerated_speed := Vector2(player.velocity.x, player.velocity.z).length()
	check(player.touch_sprinting and first_speed > 0.01 and accelerated_speed > first_speed + 0.5, "The stick pushed all the way forward must sprint the actual character across physics frames")
	_finger(touch, 4, jump_point)
	await _frames(3)
	check(player.velocity.y > 3.0 and not player.is_on_floor() and touch.move_finger == 1 and touch.look_finger == 2, "Jump finger must launch the player while move, look, and sprint remain held")
	_finger(touch, 5, crouch_point)
	await _frames(2)
	check(player.crouching and player.touch_crouching and touch.move_finger == 1 and touch.look_finger == 2, "Crouch finger must change the capsule without stealing the other active controls")
	check(touch._crouch_button.text == "STAND" and touch._crouch_button.button_pressed, "CROUCH must show its current toggle state")
	_drag(touch, 1, move_origin + Vector2(0, -touch.radius * .6))
	check(not player.touch_sprinting and player.touch_crouching and player.touch_move.length() > .5 and touch.look_finger == 2, "Easing off the stick must stop the sprint and keep move, look, and crouch")
	_finger(touch, 4, Vector2.ZERO, false)
	_finger(touch, 5, Vector2.ZERO, false)
	_finger(touch, 1, Vector2.ZERO, false)
	check(player.touch_move == Vector2.ZERO and touch.move_finger == -1 and touch.look_finger == 2 and player.touch_crouching, "Releasing movement must stop its input while look and crouch remain active")
	_finger(touch, 2, Vector2.ZERO, false)
	var released_yaw := player.rotation.y
	_drag(touch, 2, look_origin, Vector2(100, 100))
	check(touch.look_finger == -1 and is_equal_approx(player.rotation.y, released_yaw), "A released look finger must not turn the camera through stale drag events")
	# The thumb on FIRE (THROW until a gun is drawn) still aims.
	var fire_point := _button(touch, "THROW").get_global_rect().get_center()
	_finger(touch, 8, fire_point)
	var fire_yaw := player.rotation.y
	_drag(touch, 8, fire_point + Vector2(20, 0), Vector2(20, 0))
	check(player.rotation.y < fire_yaw and touch.look_finger == -1, "Dragging the thumb on FIRE must turn the camera")
	_finger(touch, 8, fire_point, false)
	_finger(touch, 1, move_origin)
	_drag(touch, 1, move_origin + Vector2(0, -touch.radius))
	_finger(touch, 2, look_origin)
	_finger(touch, 7, _button(touch, "PAUSE").get_global_rect().get_center())
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
	check(touch._crouch_button.text == "CROUCH" and not touch._crouch_button.button_pressed and not player.crouching, "Resume must restore standing controls and clear the toggle visuals")
	_finger(touch, 1, move_origin)
	_drag(touch, 1, move_origin + Vector2(0, -touch.radius))
	_finger(touch, 2, look_origin)
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(paused and main.current_menu == "pause" and _clear_inputs(touch,player), "Backgrounding the mobile app must pause and clear all held fingers")
	check(Engine.max_fps == 30, "Paused mobile menus must reduce their frame cap to 30")
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(player.playing and touch.enabled and Engine.max_fps == 60 and _clear_inputs(touch,player), "Android Back resumes the paused game with clean controls at 60 FPS")
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(paused and main.current_menu == "pause" and not quit_on_go_back, "Android Back pauses gameplay instead of closing the app")
	main._play()
	# Reload the actual scene through the menu's Restart callback twice. Verify
	# new control ownership and signal wiring, not a reset helper or mock scene.
	for cycle in 2:
		var previous_control_id := touch.get_instance_id()
		_finger(touch, 1, move_origin)
		_drag(touch, 1, move_origin + Vector2(0, -touch.radius))
		_finger(touch, 7, _button(touch, "PAUSE").get_global_rect().get_center())
		_menu_button(main, "Restart").pressed.emit()
		await _frames(5)
		main = current_scene
		touch = main.touch
		player = main.player
		check(main.mobile and main.current_menu == "home" and paused and not player.playing and touch.get_instance_id() != previous_control_id, "Restart must replace the actual mobile room and return to its home menu")
		check(_control_count(root) == 1 and touch._buttons.size() == 20 and touch.get_child_count() == 20, "Restart must retain exactly one touch controller and its twenty buttons without duplicates")
		var single_connections := touch.pause_pressed.get_connections().size() == 1 and touch.hold_pressed.get_connections().size() == 1
		for button in touch._buttons:
			single_connections = single_connections and button.pressed.get_connections().size() == 1
		check(single_connections and _clear_inputs(touch, player), "Reloaded controls must have one callback per signal and no stale fingers")
		_menu_button(main, "Play").pressed.emit()
		await _frames(4)
		_finger(touch, 5, _button(touch, "CROUCH").get_global_rect().get_center())
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
