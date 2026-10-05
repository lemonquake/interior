extends SceneTree

const NAMES := ["marble_table_2", "woven_tray_14", "potted_plant_15", "tissue_box_16"]
var checks := 0
var failures: Array[String] = []
var bodies: Array[InteriorObject] = []
var phases: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _settle(label: String, frames: int) -> void:
	var late_speed: Dictionary = {}
	var late_spin: Dictionary = {}
	var late_displacement: Dictionary = {}
	var late_start: Dictionary = {}
	for body in bodies:
		late_speed[body.name] = 0.0
		late_spin[body.name] = 0.0
		late_displacement[body.name] = 0.0
	for frame in frames:
		await physics_frame
		for body in bodies:
			check(body.global_position.is_finite() and body.linear_velocity.is_finite() and body.angular_velocity.is_finite(), label + ": tabletop transforms and velocities must stay finite")
			if frame >= frames - 120:
				if not late_start.has(body.name):
					late_start[body.name] = body.global_position
				late_speed[body.name] = maxf(late_speed[body.name], body.linear_velocity.length())
				late_spin[body.name] = maxf(late_spin[body.name], body.angular_velocity.length())
				late_displacement[body.name] = maxf(late_displacement[body.name], body.global_position.distance_to(late_start[body.name]))
	var states: Array[Dictionary] = []
	for body in bodies:
		check(not body.freeze and not body.dormant, label + ": active tabletop bodies must settle through physics, not freezing: " + str(body.name))
		check(late_speed[body.name] < 0.05 and late_spin[body.name] < 0.15, label + ": resting object must stop visible shaking: " + str(body.name))
		check(late_displacement[body.name] < 0.005, label + ": resting object must drift less than 5 mm over the final two seconds: " + str(body.name))
		if body != bodies[0]:
			check(body.position.y > 0.78 and body.position.y < 1.3, label + ": a gentle vertical drop must keep the object supported on the table: " + str(body.name))
		states.append({"name":str(body.name), "position":str(body.position), "late_max_speed_m_s":late_speed[body.name], "late_max_spin_rad_s":late_spin[body.name], "late_drift_m":late_displacement[body.name], "sleeping":body.sleeping, "frozen":body.freeze})
	phases.append({"phase":label, "simulated_seconds":frames / 60.0, "bodies":states})

func _run() -> void:
	Engine.physics_ticks_per_second = 60
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main._play()
	# Keep the production character clear while driving its real grab spring
	# deterministically. Rigid bodies and the collision solver continue normally.
	main.player.playing = false
	for i in 4:
		await physics_frame
	for label in NAMES:
		bodies.append(main.get_node(NodePath(label)) as InteriorObject)
	check(not main.control_lab and bodies.size() == 4, "Regression must use the actual marble table, tray, plant and tissue box")
	# The previous settling test only observed frozen props. Wake this complete
	# stack and let its contact with the table naturally wake the table too.
	for body in bodies.slice(1):
		body.activate()
	await _settle("wake_stack", 480)
	for body in bodies.slice(1):
		var initial_height: float = body.global_position.y
		var lift_position: Vector3 = body.global_position
		main.player.camera.global_position = lift_position + Vector3(0, 0.45, InteriorPlayer.HOLD_DISTANCE)
		main.player.camera.look_at(lift_position + Vector3(0, 0.45, 0))
		main.player.grab_object(body)
		check(main.player.held == body and body.held and not body.freeze, "Actual grab must activate and hold " + str(body.name))
		var lifted_height := initial_height
		for frame in 30:
			main.player.update_hold(1.0 / 60.0)
			await physics_frame
			lifted_height = maxf(lifted_height, body.global_position.y)
		check(lifted_height > initial_height + 0.08, "Real hold forces must visibly lift " + str(body.name))
		var released: InteriorObject = main.player.release_object()
		check(released == body and not body.held and not body.get_collision_exceptions().has(main.player), "Drop must release the object and restore its character collision")
		await _settle("grab_drop_" + str(body.name), 360)
	print("INTERIOR_TABLETOP_STABILITY ", JSON.stringify({"passed":failures.is_empty(), "checks":checks, "failures":failures, "simulated_seconds":27.5, "fixed_delta_seconds":1.0 / 60.0, "phases":phases}))
	quit(0 if failures.is_empty() else 1)
