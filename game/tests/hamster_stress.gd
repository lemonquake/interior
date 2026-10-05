extends SceneTree

const Enclosure = preload("res://scripts/hamster_enclosure.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _run() -> void:
	var enclosure_body := RigidBody3D.new()
	enclosure_body.freeze = true
	root.add_child(enclosure_body)
	var habitat := Enclosure.attach_to(enclosure_body)
	await process_frame
	var ring_probe := Node3D.new()
	habitat.add_child(ring_probe)
	habitat._ring(ring_probe, Vector3.ZERO, 1.0, 0.8, 0.2, "blue")
	var ring_mesh := ring_probe.get_child(0) as MeshInstance3D
	var ring_arrays := ring_mesh.mesh.surface_get_arrays(0)
	var ring_vertices: PackedVector3Array = ring_arrays[Mesh.ARRAY_VERTEX]
	var ring_normals: PackedVector3Array = ring_arrays[Mesh.ARRAY_NORMAL]
	check(ring_normals[0].dot(Vector3(ring_vertices[0].x, 0, ring_vertices[0].z)) > 0, "Ring outer wall must face outward in Godot clockwise winding")
	check(ring_normals[6].dot(Vector3(ring_vertices[6].x, 0, ring_vertices[6].z)) < 0, "Ring inner wall must face inward")
	check(ring_normals[12].y > 0, "Ring upper rim must face up")
	check(ring_normals[18].y < 0, "Ring lower rim must face down")
	ring_probe.queue_free()
	check(habitat.residents.size() == 3, "Exactly three living residents are required")
	check(get_nodes_in_group("hamsters").size() == 3, "All residents must be registered")
	check(habitat.process_mode == Node.PROCESS_MODE_PAUSABLE, "Habitat must explicitly pause")
	var colliders := 0
	for child in enclosure_body.get_children():
		if child is CollisionShape3D:
			colliders += 1
	check(colliders >= 150, "Enclosure has hollow tube collisions, physical walls, shelves and supports")
	await physics_frame
	await physics_frame
	for level in 3:
		for side in [-1.0, 1.0]:
			if (side > 0 and level < 2) or (side < 0 and level > 0):
				var query := PhysicsRayQueryParameters3D.create(habitat.to_global(Vector3(side * 0.415, Enclosure.FLOORS[level] + 0.046, Enclosure.PORT_Z)), habitat.to_global(Vector3(side * 0.33, Enclosure.FLOORS[level] + 0.046, Enclosure.PORT_Z)))
				check(root.world_3d.direct_space_state.intersect_ray(query).is_empty(), "Physical side-wall ports must be open into hollow connectors")
	var animation_names: Dictionary = {}
	var poses: Array[Transform3D] = []
	for pet in habitat.residents:
		pet.set_physics_process(false)
		check(pet.animation_player != null, "Resident must use real AnimationPlayer")
		check(pet.skeleton != null and pet.skeleton.get_bone_count() == 9, "Resident must use a nine-bone skin")
		for clip in ["walk", "run", "idle_sniff", "idle_groom", "idle_rear", "idle_rest", "eat", "dig"]:
			check(pet._animation_names.has(clip), "Missing rig clip: " + clip)
		pet._play("walk", 0.73)
		check(is_equal_approx(pet.animation_player.get_playing_speed(), 0.73), "First-frame clip rate must equal requested speed")
		pet._play("walk", 0.73)
		check(is_equal_approx(pet.animation_player.get_playing_speed(), 0.73), "Subsequent clip rate must not square requested speed")
		pet._play("run", 1.22)
		check(is_equal_approx(pet.animation_player.get_playing_speed(), 1.22), "Transition must replace previous clip rate")
		pet.reset_resident()
		poses.append(pet.skeleton.get_bone_global_pose(0))
	var deformation: Dictionary = {}
	for pet in habitat.residents:
		var coat := pet._model.find_child("HamsterCoat", true, false) as MeshInstance3D
		check(coat != null and coat.skin != null, "Imported visible coat must have a Skin resource")
		var colors: PackedColorArray = coat.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var low := 1.0
		var high := 0.0
		for color in colors:
			low = minf(low, color.r)
			high = maxf(high, color.r)
		check(high - low > 0.3 and low < 0.08, "Imported COLOR_0 must include coat and dark eyes instead of synthetic white")
		for clip in ["walk", "run", "idle_sniff", "idle_groom", "idle_rear", "idle_rest", "eat", "dig"]:
			pet.animation_player.stop()
			pet.active_clip = ""
			pet._play(clip, 1.0)
			pet.animation_player.seek(0.0, true)
			var baseline := _skinned_vertices(pet, coat)
			var maximum := 0.0
			var total := 0.0
			for sample_index in range(1, 9):
				var clip_resource := pet.animation_player.get_animation(pet._animation_names[clip])
				pet.animation_player.seek(clip_resource.length * float(sample_index) / 9.0, true)
				var sample := _skinned_vertices(pet, coat)
				for i in sample.size():
					var displacement := baseline[i].distance_to(sample[i]) * 0.95
					maximum = maxf(maximum, displacement)
					total += displacement
			check(maximum > 0.0007, "Visible skinned vertices must deform, not just clip names: " + clip)
			deformation[str(pet.resident_id) + ":" + clip] = {"max_displacement_m":maximum, "mean_displacement_m":total / (8 * baseline.size()), "vertex_samples":baseline.size()}
		pet.reset_resident()
	var max_speed := 0.0
	var closest_residents := INF
	var max_blocked_seconds := 0.0
	var route_vertices_max := 0
	var started_usec := Time.get_ticks_usec()
	for step in 10000:
		for pet in habitat.residents:
			var previous_position := pet.position
			pet.simulate_step(1.0 / 60.0)
			check(pet.position.distance_to(previous_position) <= 0.006, "Resident must physically traverse the path without a floor teleport")
			check(habitat.contains_resident(pet), "Resident escaped its bounds")
			check(pet.position.is_finite() and pet.rotation.is_finite(), "Resident pose must remain finite")
			check(pet.speed <= 0.191, "Resident movement must stay bounded")
			max_speed = maxf(max_speed, pet.speed)
			max_blocked_seconds = maxf(max_blocked_seconds, pet._blocked_time)
			route_vertices_max = maxi(route_vertices_max, pet._route.size())
			check(pet._blocked_time < 12.0, "Residents must resolve traffic without a persistent deadlock")
			for other in habitat.residents:
				if other != pet:
					closest_residents = minf(closest_residents, pet.position.distance_to(other.position))
					check(pet.position.distance_to(other.position) >= Enclosure.PET_CLEARANCE - 0.002, "Residents must keep physical body clearance")
			animation_names[pet.active_clip] = true
			for bone in pet.skeleton.get_bone_count():
				check(pet.skeleton.get_bone_global_pose(bone).origin.is_finite(), "Skinned bone pose must stay finite")
	var stress_usec := Time.get_ticks_usec() - started_usec
	var snapshots: Array[Dictionary] = []
	for pet in habitat.residents:
		for activity in ["wheel", "tunnel", "bridge", "sand", "food", "water", "hide", "idle"]:
			check(pet.visited.has(activity), "Resident must visit activity: " + activity)
		snapshots.append(pet.snapshot())
		check(pet.visited_levels.size() == 3, "Every pet must walk through connectors and visit every floor")
	for clip in ["walk", "run", "idle_sniff", "idle_groom", "idle_rear", "idle_rest", "eat", "dig"]:
		check(animation_names.has(clip), "Stress run must exercise animation: " + clip)
	# A pushed or held parent carries all residents and playground pieces.
	var locals: Array[Vector3] = []
	for pet in habitat.residents:
		locals.append(pet.position)
	enclosure_body.global_position = Vector3(2.0, 1.0, -0.7)
	enclosure_body.rotation = Vector3(0.08, 0.73, -0.12)
	for i in 3:
		var pet := habitat.residents[i]
		check(pet.position.is_equal_approx(locals[i]), "Parent motion cannot detach pet")
		check(pet.global_position.is_equal_approx(habitat.to_global(locals[i])), "Pet must inherit parent transform")
	# Reset two complete runs and compare behavior and animation phase, not just RNG.
	habitat.reset_residents()
	for pet in habitat.residents:
		check(is_zero_approx(pet.animation_player.current_animation_position), "Reset must clear animation phase")
		check(pet.rotation == Vector3.ZERO, "Reset must clear resident heading")
	for step in 300:
		for pet in habitat.residents:
			pet.simulate_step(1.0 / 60.0)
	var repeat: Array[Dictionary] = []
	var phases: Array[float] = []
	var bone_poses: Array[Transform3D] = []
	for pet in habitat.residents:
		repeat.append(pet.snapshot())
		phases.append(pet.animation_player.current_animation_position)
		bone_poses.append(pet.skeleton.get_bone_global_pose(2))
	habitat.reset_residents()
	for step in 300:
		for pet in habitat.residents:
			pet.simulate_step(1.0 / 60.0)
	for i in 3:
		var pet := habitat.residents[i]
		check(pet.snapshot() == repeat[i], "Seeded reset must exactly reproduce resident behavior")
		check(is_equal_approx(pet.animation_player.current_animation_position, phases[i]), "Seeded reset must reproduce animation phase")
		check(pet.skeleton.get_bone_global_pose(2).is_equal_approx(bone_poses[i]), "Seeded reset must reproduce skinned pose")
	# Exercise actual scene callbacks for pause/resume after direct stress stepping.
	for pet in habitat.residents:
		pet.set_physics_process(true)
	await physics_frame
	await physics_frame
	paused = true
	var paused_time: Array[float] = []
	var paused_phases: Array[float] = []
	for pet in habitat.residents:
		paused_time.append(pet.elapsed)
		paused_phases.append(pet.animation_player.current_animation_position)
	for frame in 6:
		await physics_frame
	for i in 3:
		check(habitat.residents[i].elapsed == paused_time[i], "Pause must freeze pet simulation")
		check(habitat.residents[i].animation_player.current_animation_position == paused_phases[i], "Pause must freeze skeletal animation")
	paused = false
	await physics_frame
	await physics_frame
	for i in 3:
		check(habitat.residents[i].elapsed > paused_time[i], "Resume must restart pet simulation")
	var report := {"passed":failures.is_empty(), "checks":checks, "failures":failures, "steps":10000, "simulation_hz":60, "residents":3, "colliders":colliders, "max_speed_mps":max_speed, "animations":animation_names.keys(), "cpu_stress_ms":float(stress_usec)/1000.0, "snapshots":snapshots, "skinned_vertex_deformation":deformation, "min_resident_separation_m":closest_residents, "max_blocked_seconds":max_blocked_seconds, "max_route_vertices":route_vertices_max, "connector_count":habitat.connector_paths.size()}
	print("INTERIOR_HAMSTER_STRESS ", JSON.stringify(report))
	var output := FileAccess.open("res://../work/lemondev/2026-10-05/hamsters/stress-results.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
	if "--capture" in OS.get_cmdline_user_args():
		await _capture_evidence(habitat, enclosure_body)
	enclosure_body.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

# CPU evaluation of the actual imported coat vertices using Godot's runtime
# bone poses and skin inverse bind matrices. This detects a static/misbound skin
# even when AnimationPlayer reports correct clip names and time progression.
func _skinned_vertices(pet: InteriorHamster, coat: MeshInstance3D) -> PackedVector3Array:
	var arrays := coat.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var output := PackedVector3Array()
	var influences := bones.size() / vertices.size()
	var transforms: Array[Transform3D] = []
	for bind in coat.skin.get_bind_count():
		var bone := pet.skeleton.find_bone(coat.skin.get_bind_name(bind))
		if bone < 0:
			bone = coat.skin.get_bind_bone(bind)
		transforms.append(pet.skeleton.get_bone_global_pose(bone) * coat.skin.get_bind_pose(bind))
	for i in range(0, vertices.size(), 3):
		var deformed := Vector3.ZERO
		for j in influences:
			var at: int = i * influences + j
			deformed += (transforms[bones[at]] * vertices[i]) * weights[at]
		output.append(deformed)
	return output

func _capture_evidence(habitat: HamsterEnclosure, enclosure_body: RigidBody3D) -> void:
	root.size = Vector2i(1200, 900)
	root.content_scale_size = Vector2i(1200, 900)
	var directory := ProjectSettings.globalize_path("res://../work/lemondev/2026-10-05/hamsters/pass4-captures")
	DirAccess.make_dir_recursive_absolute(directory)
	for pet in habitat.residents:
		pet.set_physics_process(false)
	enclosure_body.transform = Transform3D.IDENTITY
	habitat.reset_residents()
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.10, 0.13, 0.17)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.90, 1)
	environment.ambient_light_energy = 0.38
	environment_node.environment = environment
	root.add_child(environment_node)
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.light_energy = 0.95
	light.shadow_enabled = true
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(1.12, 1.32, 2.5)
	camera.look_at(Vector3(0, 0.95, 0))
	camera.fov = 45
	camera.current = true
	for step in 600:
		for pet in habitat.residents:
			pet.simulate_step(1.0 / 60.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("connected-habitat.png"))
	var pet := habitat.residents[0]
	pet.reparent(root)
	pet.position = Vector3.ZERO
	pet.rotation = Vector3.ZERO
	pet._visual_pivot.rotation = Vector3.ZERO
	enclosure_body.hide()
	camera.position = Vector3(0.135, 0.092, 0.175)
	camera.look_at(Vector3(0, 0.035, 0))
	camera.fov = 43
	for clip in ["walk", "idle_sniff", "idle_groom", "idle_rear", "idle_rest"]:
		pet.animation_player.stop()
		pet.active_clip = ""
		pet._play(clip, 1.0)
		for frame in 4:
			var animation := pet.animation_player.get_animation(pet._animation_names[clip])
			pet.animation_player.seek(animation.length * float(frame) / 4.0, true)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join(clip + "-" + str(frame) + ".png"))
	pet.queue_free()
