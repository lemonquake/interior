extends SceneTree

const FIXED_STEP := 1.0 / 60.0
const STRESS_STEPS := 10000
const SEED := 20261005
var failures: Array[String] = []
var checks := 0
var world: Node3D
var player: InteriorPlayer
var props: Array[InteriorObject] = []
var rng := RandomNumberGenerator.new()
var max_speed := 0.0
var max_prop_speed := 0.0
var max_prop_spin := 0.0
var stress_node_count := 0
var metrics: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _box(parent: Node3D, position: Vector3, dimensions: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	parent.add_child(collision)
	collision.position = position

func _static_box(position: Vector3, dimensions: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 5
	world.add_child(body)
	body.position = position
	_box(body, Vector3.ZERO, dimensions)
	return body

func _prop(position: Vector3, mass: float, dimensions: Vector3) -> InteriorObject:
	var body := InteriorObject.new()
	body.mass = mass
	world.add_child(body)
	body.position = position
	_box(body, Vector3.ZERO, dimensions)
	body.home_transform = body.global_transform
	props.append(body)
	return body

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _walk_axis(axis: Vector2, frames: int, sprint := false) -> void:
	player.touch_move = axis
	player.touch_sprinting = sprint
	await _frames(frames)

func _spinning_contact_regression() -> void:
	# Exercise engine-generated slide contacts with a rotating offset-COM body.
	# The engine's contact velocity is the independent oracle for separation.
	player.set_physics_process(false)
	var contact_metrics: Dictionary = {}
	for spin in [6.0, -6.0]:
		player.reset_motion(Vector3(0, 0.01, 0))
		var body := _prop(Vector3(0, 0.05, -2), 8.0, Vector3(1, 1.2, 0.6))
		(body.get_child(0) as CollisionShape3D).position.y = 0.7
		body.gravity_scale = 0.0
		body.linear_damp = 0.0
		body.angular_damp = 0.0
		body.can_sleep = false
		await _frames(2)
		body.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -2))
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		await _frames(2)
		body.center_of_mass = Vector3(0, 1.2, 0)
		body.angular_velocity = Vector3(-6, 0, 0)
		await _frames(2)
		player.position = Vector3(0, 0.01, -1.58)
		var approach := Vector3(0, 0, -0.8)
		var contact: KinematicCollision3D
		for i in 20:
			player.velocity = approach
			player.move_and_slide()
			for j in player.get_slide_collision_count():
				var hit := player.get_slide_collision(j)
				if hit.get_collider() == body:
					contact = hit
					break
			if contact != null:
				break
		check(contact != null, "Spinning prop regression must obtain a real player collision")
		if contact != null:
			check(absf(body.rotation.x) > 0.1, "Spinning prop must actually rotate through engine simulation before collision")
			check(contact.get_position().y > body.global_position.y + 0.1 and contact.get_position().y < body.to_global(body.center_of_mass).y - 0.1, "Regression contact must lie between the body origin and elevated center of mass")
			# Reverse angular momentum at the existing contact, as another impact
			# can do before the player responds; retain the real collision geometry.
			body.angular_velocity = Vector3(spin, 0, 0)
			var direct := PhysicsServer3D.body_get_direct_state(body.get_rid())
			var contact_speed := direct.get_velocity_at_local_position(contact.get_position() - body.global_position)
			var toward := -contact.get_normal()
			var engine_surface_speed := contact_speed.dot(toward)
			var before := direct.linear_velocity
			var before_spin := direct.angular_velocity
			player._push_contacts(approach)
			var velocity_change := direct.linear_velocity - before
			if spin > 0.0:
				check(engine_surface_speed > approach.dot(toward) + 2.0, "Engine must confirm that the spinning surface is moving away faster than the player")
				check(velocity_change.length() < 0.000001 and direct.angular_velocity.is_equal_approx(before_spin), "A separating offset-COM contact must receive neither spurious linear nor angular impulse")
				contact_metrics["separating_added_speed_m_s"] = velocity_change.length()
				contact_metrics["separating_surface_speed_m_s"] = engine_surface_speed
			else:
				check(engine_surface_speed < -2.0, "Engine must confirm that the opposite spin approaches the player")
				check(velocity_change.dot(toward) > 0.4, "An approaching offset-COM contact must receive a player push")
				check(velocity_change.is_finite() and velocity_change.length() * body.mass <= 115.0001 and direct.angular_velocity.is_finite(), "Spinning contact impulse must remain finite and within the player impulse limit")
				contact_metrics["approaching_added_speed_m_s"] = velocity_change.length()
				contact_metrics["approaching_surface_speed_m_s"] = engine_surface_speed
		props.erase(body)
		body.queue_free()
		await _frames(2)
	player.reset_motion(Vector3(0, 0.01, 2))
	player.set_physics_process(true)
	metrics["offset_center_of_mass_contacts"] = contact_metrics

func _run() -> void:
	rng.seed = SEED
	Engine.physics_ticks_per_second = 60
	for action in ["left", "right", "forward", "back", "run", "jump", "crouch", "hold", "throw", "inspect"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	world = Node3D.new()
	root.add_child(world)
	_static_box(Vector3(0, -0.15, 0), Vector3(18, 0.3, 18))
	_static_box(Vector3(0, 1.5, -8), Vector3(16, 3, 0.2))
	_static_box(Vector3(0, 1.5, 8), Vector3(16, 3, 0.2))
	_static_box(Vector3(-8, 1.5, 0), Vector3(0.2, 3, 16))
	_static_box(Vector3(8, 1.5, 0), Vector3(0.2, 3, 16))
	var ceiling := _static_box(Vector3(0, 1.3, -4), Vector3(1.8, 0.2, 1.2))
	player = InteriorPlayer.new()
	world.add_child(player)
	player.position = Vector3(0, 0.01, 2)
	player.playing = true
	await _frames(8)
	check(player.is_on_floor(), "Player must settle on a real floor")
	var unchanged_position := player.global_position
	player._physics_process(0.0)
	player._physics_process(NAN)
	check(player.global_position == unchanged_position and player.velocity.is_finite(), "Invalid or zero time steps must not mutate movement state")
	player.touch_move = Vector2(0, -1)
	await _frames(2)
	var first_speed := Vector2(player.velocity.x, player.velocity.z).length()
	check(first_speed > 0.05 and first_speed < InteriorPlayer.WALK_SPEED * 0.2, "Walking must accelerate gradually from rest")
	await _frames(30)
	var walk_speed := Vector2(player.velocity.x, player.velocity.z).length()
	check(absf(walk_speed - InteriorPlayer.WALK_SPEED) < 0.08, "Walking must converge to its intended speed")
	player.touch_sprinting = true
	await _frames(20)
	var sprint_speed := Vector2(player.velocity.x, player.velocity.z).length()
	check(sprint_speed > walk_speed + 1.5 and sprint_speed <= InteriorPlayer.RUN_SPEED + 0.02, "Sprint must build additional momentum")
	player.touch_move = Vector2.ZERO
	await _frames(2)
	var braking_speed := Vector2(player.velocity.x, player.velocity.z).length()
	check(braking_speed > 3.0 and braking_speed < sprint_speed, "Input release must brake momentum without snapping to rest")
	await _frames(35)
	check(Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "Ground friction must eventually bring the player to rest")
	metrics["first_walk_speed_m_s"] = first_speed
	metrics["walk_speed_m_s"] = walk_speed
	metrics["sprint_speed_m_s"] = sprint_speed
	metrics["two_frame_braking_speed_m_s"] = braking_speed
	player.reset_motion(Vector3(3, 0.01, 2))
	await _frames(6)
	await _walk_axis(Vector2(0, -1), 30, true)
	var takeoff_speed := Vector2(player.velocity.x, player.velocity.z).length()
	player.request_jump()
	player.touch_move = Vector2.ZERO
	var jump_apex := 0.0
	var airborne_speed := 0.0
	for i in 55:
		await physics_frame
		jump_apex = maxf(jump_apex, player.position.y)
		if i == 12:
			airborne_speed = Vector2(player.velocity.x, player.velocity.z).length()
	check(jump_apex > 0.6 and jump_apex < 1.1, "Jump must have a bounded visible ballistic arc")
	check(airborne_speed >= takeoff_speed * 0.9, "Jump must retain horizontal takeoff momentum")
	check(player.is_on_floor(), "Player must land after a jump")
	metrics["jump_apex_m"] = jump_apex
	metrics["airborne_horizontal_speed_m_s"] = airborne_speed
	# Leave a raised platform and press jump after the foot loses contact.
	var ledge := _static_box(Vector3(4, 1.0, 3), Vector3(2.0, 0.2, 2.0))
	player.reset_motion(Vector3(4, 1.11, 3))
	await _frames(5)
	check(player.is_on_floor(), "Coyote test must begin on the raised ledge")
	player.touch_move = Vector2(1, 0)
	var left_ledge := false
	for i in 60:
		await physics_frame
		if not player.is_on_floor() and player.position.x > 5.0:
			left_ledge = true
			break
	check(left_ledge, "Coyote test must actually leave its platform")
	player.request_jump()
	await _frames(3)
	check(player.velocity.y > 3.5, "Jump pressed just after leaving a ledge must be accepted")
	ledge.queue_free()
	player.reset_motion(Vector3(3, 1.0, 2))
	await _frames(3)
	player.position.y = 0.24
	player.velocity.y = -2.0
	player.request_jump()
	var buffered_peak_velocity := 0.0
	for i in 14:
		await physics_frame
		buffered_peak_velocity = maxf(buffered_peak_velocity, player.velocity.y)
	check(buffered_peak_velocity > 3.5, "Jump pressed shortly before landing must buffer until grounded")
	# The crouched capsule must fit under a real ceiling; standing is obstructed.
	player.reset_motion(Vector3(0, 0.01, -2.4))
	await _frames(5)
	player.touch_crouching = true
	await _walk_axis(Vector2(0, -1), 66)
	player.touch_move = Vector2.ZERO
	await _frames(8)
	check(player.crouching and player.position.z < -3.7, "Crouching must permit passage beneath a low ceiling")
	check(player.camera.position.y < 0.95, "Crouch eye height must smoothly lower")
	player.touch_crouching = false
	await _frames(10)
	check(player.crouching and not player.can_stand(), "Standing must remain blocked by the ceiling")
	await _walk_axis(Vector2(0, 1), 66)
	player.touch_move = Vector2.ZERO
	await _frames(15)
	check(not player.crouching and player.camera.position.y > 1.5, "Player must stand smoothly after clearing the ceiling")
	ceiling.queue_free()
	await _frames(2)
	player.reset_motion(Vector3(0, 0.01, -6.5))
	await _frames(4)
	await _walk_axis(Vector2(0, -1), 55, true)
	check(player.position.z > -7.68 and player.position.z < -7.5, "Sprint must stop at a static wall without tunnelling")
	player.touch_move = Vector2.ZERO
	# Comparable straight-line collisions test mass and approach momentum.
	var push_metrics: Array[float] = []
	for test_mass in [2.0, 40.0]:
		var body := _prop(Vector3(0, 0.36, -2), test_mass, Vector3(0.7, 0.7, 0.7))
		body.freeze = true
		body.dormant = true
		player.reset_motion(Vector3(0.16, 0.01, 1.0))
		await _frames(6)
		player.touch_move = Vector2(0, -1)
		player.touch_sprinting = true
		var peak_velocity := 0.0
		var peak_spin := 0.0
		for i in 65:
			await physics_frame
			peak_velocity = maxf(peak_velocity, body.linear_velocity.length())
			peak_spin = maxf(peak_spin, body.angular_velocity.length())
		check(not body.freeze and not body.dormant, "Player contact must activate unanchored props")
		check(body.position.z < -2.08 and peak_velocity > 0.3, "An approach with momentum must push a prop")
		check(peak_spin > 0.05, "Off-center contact must rotate the prop")
		push_metrics.append(peak_velocity)
		props.erase(body)
		body.queue_free()
		await _frames(2)
	check(push_metrics[0] > push_metrics[1], "A heavier prop must acquire less velocity from the same approach")
	metrics["light_push_peak_m_s"] = push_metrics[0]
	metrics["heavy_push_peak_m_s"] = push_metrics[1]
	await _spinning_contact_regression()
	# Repeated lifecycle changes must clear latent input and collision exclusions.
	var reset_body := _prop(Vector3(0, 1.1, -1), 1.0, Vector3(0.25, 0.25, 0.25))
	for cycle in 20:
		player.reset_motion(Vector3(0, 0.01, 2))
		reset_body.recover()
		player.grab_object(reset_body)
		player.request_jump()
		player.playing = false
		check(player.touch_move == Vector2.ZERO and not player.touch_sprinting, "Pause must clear held movement controls")
		player.reset_motion(Vector3(0, 0.01, 2))
		check(player.held == null and not reset_body.held and not reset_body.get_collision_exceptions().has(player), "Restart must release held state and collision exclusions")
		player.playing = true
		await _frames(3)
	reset_body.position.y = -5
	reset_body.recover()
	check(reset_body.global_transform.is_equal_approx(reset_body.home_transform), "Object recovery must restore its original transform")
	check(reset_body.linear_velocity == Vector3.ZERO and reset_body.angular_velocity == Vector3.ZERO, "Object recovery must clear momentum")
	props.erase(reset_body)
	reset_body.queue_free()
	await _frames(2)
	# Direct multi-finger input checks newly added mobile buttons together.
	player.reset_motion(Vector3(0, 0.01, 2))
	await _frames(5)
	var touch := InteriorTouchControls.new()
	root.add_child(touch)
	touch.player = player
	touch.set_enabled(true)
	var move_touch := InputEventScreenTouch.new()
	move_touch.index = 1
	move_touch.position = Vector2(80, 550)
	move_touch.pressed = true
	touch._input(move_touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(100, 495)
	touch._input(drag)
	var look_touch := InputEventScreenTouch.new()
	look_touch.index = 2
	look_touch.position = Vector2(700, 240)
	look_touch.pressed = true
	touch._input(look_touch)
	var sprint_touch := InputEventScreenTouch.new()
	sprint_touch.index = 3
	sprint_touch.position = touch._sprint_button.get_global_rect().get_center()
	sprint_touch.pressed = true
	touch._input(sprint_touch)
	check(player.touch_sprinting and player.touch_move.length() > 0.5 and touch.look_finger == 2, "Sprint finger must coexist with move and look fingers")
	var second_sprint_touch := InputEventScreenTouch.new()
	second_sprint_touch.index = 6
	second_sprint_touch.position = sprint_touch.position
	second_sprint_touch.pressed = true
	touch._input(second_sprint_touch)
	sprint_touch.pressed = false
	sprint_touch.position = Vector2.ZERO
	touch._input(sprint_touch)
	check(player.touch_sprinting, "One released sprint finger must not cancel another held sprint finger")
	second_sprint_touch.pressed = false
	touch._input(second_sprint_touch)
	check(not player.touch_sprinting and player.touch_move.length() > 0.5, "Releasing sprint outside the button must preserve movement")
	var jump_touch := InputEventScreenTouch.new()
	jump_touch.index = 4
	jump_touch.position = touch._buttons[4].get_global_rect().get_center()
	jump_touch.pressed = true
	touch._input(jump_touch)
	await _frames(3)
	check(player.velocity.y > 3.0 and touch.move_finger == 1 and touch.look_finger == 2, "Jump must work while move and look fingers remain held")
	var crouch_touch := InputEventScreenTouch.new()
	crouch_touch.index = 5
	crouch_touch.position = touch._crouch_button.get_global_rect().get_center()
	crouch_touch.pressed = true
	touch._input(crouch_touch)
	await _frames(2)
	check(player.touch_crouching and player.crouching, "Mobile crouch must switch the player capsule")
	touch.set_enabled(false)
	check(player.touch_move == Vector2.ZERO and not player.touch_sprinting and not player.touch_crouching and touch._button_fingers.is_empty(), "Disabling mobile controls must clear every held finger")
	touch.queue_free()
	await _frames(2)
	# Multi-object test keeps both engine contact dynamics and character movement active.
	for i in 12:
		var position := Vector3((i % 4 - 1.5) * 1.3, 0.45 + (i / 4) * 0.12, (i / 4 - 1) * 1.5)
		_prop(position, 0.5 + i * 2.5, Vector3(0.55, 0.55, 0.55))
	await _frames(6)
	stress_node_count = world.get_child_count()
	for step in STRESS_STEPS:
		if step % 400 == 0:
			player.reset_motion(Vector3(0, 0.05, 4))
			player.rotation.y = rng.randf_range(-PI, PI)
		if step % 37 == 0:
			player.touch_move = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).limit_length()
			player.touch_sprinting = step % 111 < 74
			player.touch_crouching = step % 222 < 37
		if step % 121 == 0:
			player.request_jump()
		if step % 600 == 0:
			var body := props[(step / 600) % props.size()]
			body.activate()
			body.apply_central_impulse(Vector3(rng.randf_range(-4, 4), 3, rng.randf_range(-4, 4)) * body.mass)
		await physics_frame
		check(player.global_position.is_finite() and player.velocity.is_finite() and player.global_basis.x.is_finite() and player.global_basis.y.is_finite() and player.global_basis.z.is_finite(), "Stress: all player transform and velocity components must remain finite")
		check(absf(player.position.x) <= 7.8 and absf(player.position.z) <= 7.8 and player.position.y > -0.05 and player.position.y < 3.0, "Stress: player must remain inside physical room bounds")
		max_speed = maxf(max_speed, player.velocity.length())
		for body in props:
			check(body.global_position.is_finite() and body.linear_velocity.is_finite() and body.angular_velocity.is_finite() and body.global_basis.x.is_finite() and body.global_basis.y.is_finite() and body.global_basis.z.is_finite(), "Stress: all rigid-body transform and velocity components must remain finite")
			check(body.global_position.y > -0.6 and body.linear_velocity.length() <= 20.1 and body.angular_velocity.length() <= 12.1, "Stress: rigid bodies must remain in collision and speed bounds")
			max_prop_speed = maxf(max_prop_speed, body.linear_velocity.length())
			max_prop_spin = maxf(max_prop_spin, body.angular_velocity.length())
		if step % 400 == 0:
			check(world.get_child_count() == stress_node_count, "Stress: reset must not allocate additional entities")
	check(STRESS_STEPS == 10000 and Engine.physics_ticks_per_second == 60, "Stress must execute 10000 steps at 60 Hz")
	metrics.merge({"max_player_speed_m_s":max_speed, "max_prop_speed_m_s":max_prop_speed, "max_prop_spin_rad_s":max_prop_spin, "stress_nodes":stress_node_count})
	print("INTERIOR_MOVEMENT_STRESS ", JSON.stringify({"passed":failures.is_empty(), "checks":checks, "failures":failures, "fixed_steps":STRESS_STEPS, "fixed_delta_seconds":FIXED_STEP, "simulated_seconds":STRESS_STEPS * FIXED_STEP, "seed":SEED, "metrics":metrics}))
	quit(0 if failures.is_empty() else 1)
