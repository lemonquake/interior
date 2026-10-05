extends SceneTree
## Contract 8.7-8.10 with the real InteriorPlayer: holding follows and rotates,
## a held prop cannot pass a 0.1 m wall, a max throw never tunnels, walking into
## a light prop tips it while heavy furniture slides slowly, the player stands on
## props without being launched, out-of-world bodies recover.

const Common = preload("res://tests/physics_common.gd")
var checks := 0
var failures: Array[String] = []
var metrics := {}
var world: Node3D
var player: InteriorPlayer

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _place_player(position: Vector3, yaw := 0.0) -> void:
	player.rotation = Vector3(0, yaw, 0)
	player.reset_motion(position)
	player._look_pitch = 0.0
	player.camera.rotation = Vector3.ZERO
	await _frames(3)

func _run() -> void:
	for action in ["left", "right", "forward", "back", "run", "jump", "hold", "throw", "inspect"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	world = Node3D.new()
	root.add_child(world)
	Common.floor_slab(world)
	player = InteriorPlayer.new()
	world.add_child(player)
	player.playing = true
	await _place_player(Vector3(0, 0.01, 0))
	# 1. Hold follows the view.
	var crate := Common.block(world, Vector3(0.2, 0.2, 0.2), 0.8, Vector3(0, 0.1, -1.2))
	await _frames(10)
	player._look_pitch = -0.6
	player.camera.rotation.x = -0.6
	player.grab_object(crate)
	check(player.held == crate, "Grab must hold the crate")
	await _frames(40)
	var hand: Vector3 = player.camera.global_position - player.camera.global_basis.z * player._hold_distance
	metrics["hold_error_m"] = crate.to_global(player._grab_local).distance_to(hand)
	check(metrics.hold_error_m < 0.08, "Held crate must follow the hand")
	var before_basis := crate.global_basis
	for i in 20:
		player.rotate_held(Vector2(12, 0))
		await physics_frame
	await _frames(20)
	metrics["rotate_held_deg"] = rad_to_deg(before_basis.get_rotation_quaternion().angle_to(crate.global_basis.get_rotation_quaternion()))
	check(metrics.rotate_held_deg > 45.0, "rotate_held must turn the held prop")
	# Swing to face a 0.1 m wall at maximum mouse speed: the crate must stay on our side.
	var wall := Common.static_box(world, Vector3(-0.75, 1.0, 0), Vector3(0.1, 2.0, 4.0))
	var crossed := false
	for i in 12:
		player.look(Vector2(-0.5 / player.sensitivity * PI / 12.0 * 0.5 / 0.5, 0) * (1.0 if i < 12 else 0.0))
		await physics_frame
		if crate.global_position.x < -0.7:
			crossed = true
	for i in 60:
		await physics_frame
		if crate.global_position.x < -0.7:
			crossed = true
	check(not crossed, "A held prop must never pass through a 0.1 m wall")
	metrics["released_when_obstructed"] = player.held == null
	check(player.held == null, "An obstructed held prop must be released")
	wall.queue_free()
	crate.queue_free()
	# 2. Max-strength throw at a 0.1 m wall.
	await _place_player(Vector3(0, 0.01, 0))
	var wall2 := Common.static_box(world, Vector3(0, 1.0, -3.0), Vector3(3.0, 2.0, 0.1))
	var stone := Common.ball(world, 0.04, 0.12, Vector3(0, 0.04, -0.9), "stone")
	await _frames(5)
	player._look_pitch = -0.9
	player.camera.rotation.x = -0.9
	player.grab_object(stone)
	await _frames(30)
	player._look_pitch = 0.0
	player.camera.rotation.x = 0.0
	await _frames(30)
	player.charging_throw = true
	player.throw_charge = 0.0
	await _frames(45)
	metrics["throw_charge_after_0_75s"] = player.throw_charge
	check(player.throw_charge >= 0.99, "Throw must charge to full in about 0.6 s")
	player.throw_object()
	await physics_frame
	metrics["throw_speed_m_s"] = stone.linear_velocity.length()
	var tunnelled := false
	for i in 120:
		await physics_frame
		if stone.global_position.z < -3.05:
			tunnelled = true
	check(metrics.throw_speed_m_s > 8.0, "A full throw must be fast")
	check(not tunnelled, "A max throw must not tunnel through a 0.1 m wall")
	wall2.queue_free()
	stone.queue_free()
	# 3. Walking into a light tall prop tips it; heavy furniture slides slowly.
	var vase := Common.prop(world, [{"kind": "cylinder", "center": [0, 0, 0], "radius": 0.07, "height": 0.9}], 1.2, "ceramic", Vector3(0, 0.45, -1.5))
	var sofa := Common.block(world, Vector3(1.8, 0.8, 0.8), 45.0, Vector3(4, 0.4, -1.5), "fabric")
	await _frames(10)
	await _place_player(Vector3(0, 0.01, 0))
	player.touch_move = Vector2(0, -1)
	await _frames(90)
	player.touch_move = Vector2.ZERO
	await _frames(60)
	metrics["vase_tilt_deg"] = Common.tilt_deg(vase)
	check(metrics.vase_tilt_deg > 45.0, "Walking into a light tall prop must tip it")
	vase.queue_free()
	var sofa_start := sofa.global_position
	await _place_player(Vector3(4, 0.01, 0))
	player.touch_move = Vector2(0, -1)
	var sofa_peak := 0.0
	var player_peak_y := 0.0
	for i in 120:
		await physics_frame
		sofa_peak = maxf(sofa_peak, Vector2(sofa.linear_velocity.x, sofa.linear_velocity.z).length())
		player_peak_y = maxf(player_peak_y, player.velocity.y)
	player.touch_move = Vector2.ZERO
	await _frames(30)
	metrics["sofa_slide_m"] = sofa.global_position.distance_to(sofa_start)
	metrics["sofa_peak_speed_m_s"] = sofa_peak
	metrics["sofa_tilt_deg"] = Common.tilt_deg(sofa)
	check(metrics.sofa_slide_m > 0.1, "Heavy furniture must slide when pushed")
	check(sofa_peak < 1.8, "Heavy furniture must slide slower than the player walks")
	check(metrics.sofa_tilt_deg < 5.0, "Heavy furniture must stay upright when pushed")
	check(player_peak_y < 0.5, "Pushing must not launch the player")
	sofa.queue_free()
	# 4. Standing on a sturdy prop: no jitter, no launch.
	var chest := Common.block(world, Vector3(0.8, 0.45, 0.8), 12.0, Vector3(0, 0.225, 3))
	await _frames(20)
	await _place_player(Vector3(0, 0.47, 3))
	await _frames(30)
	var ys: Array[float] = []
	for i in 60:
		await physics_frame
		ys.append(player.global_position.y)
	metrics["stand_on_prop_jitter_mm"] = (ys.max() - ys.min()) * 1000.0
	check(metrics.stand_on_prop_jitter_mm < 2.0 and player.is_on_floor(), "Player must stand on a prop without jitter")
	check(chest.global_position.distance_to(Vector3(0, 0.225, 3)) < 0.01, "Standing on a prop must not shove it")
	# 5. Out-of-world recovery.
	var lost := Common.block(world, Vector3(0.2, 0.2, 0.2), 0.5, Vector3(6, 0.1, 3))
	await _frames(5)
	var home := lost.home_transform
	lost.global_position = Vector3(6, -8, 3)
	await _frames(3)
	check(lost.global_position.distance_to(home.origin) < 0.01, "Out-of-world bodies must recover home")
	print("INTERIOR_PHYSICS_INTERACTION ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "metrics": metrics}))
	quit(0 if failures.is_empty() else 1)
