extends SceneTree
## Real scene checks for the third-party compositor, capped budgets, transitions and pause.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func frames(count: int) -> void:
	for i in count:
		await process_frame

func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(5)
	var particles: InteriorAtmosphereParticles = main.atmosphere_particles
	var player: InteriorPlayer = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var initial_children := particles.get_child_count()
	check(initial_children >= 6, "Scene owns actual particle groups")
	for hub in particles.get_children():
		check(hub is GPUSyncNode3D, "Particle group uses the third-party compositor")
	var high: Dictionary = particles.debug_state()
	particles.set_quality(0)
	var low: Dictionary = particles.debug_state()
	check(low.particles < high.particles * .5 and low.particles > 0, "Low reduces particle count while retaining effects")
	particles.set_quality(3)
	check(particles.debug_state().particles < 650, "Ultra remains within the fixed particle budget")
	particles.set_quality(2)
	for crossing in 3:
		player.camera.global_position = Vector3(20, -1.32, 35)
		particles._update_zones()
		await frames(105)
		check(particles.debug_state().outside, "Street activates outdoor particles")
		player.camera.global_position = Vector3(.6, 1.58, 1.3)
		particles._update_zones()
		await frames(105)
	check(particles.get_child_count() == initial_children, "Zone crossings reuse the same fixed emitter pool")
	var exterior_stopped := true
	var compositor_connections := true
	for entry in particles._groups:
		if entry.mode in ["mist", "air"]:
			exterior_stopped = exterior_stopped and not entry.active and not entry.hub.visible
		for particle: GPUParticles3D in entry.particles:
			if particle.finished.get_connections().size() > 1:
				compositor_connections = false
	check(exterior_stopped, "Exterior effects fade out and stop indoors")
	check(compositor_connections, "Repeated zone entry does not duplicate completion signals")
	var before: float = particles._elapsed
	var hub_before: float = particles.get_child(0).time_elapsed
	paused = true
	await frames(30)
	check(is_equal_approx(before, particles._elapsed), "Sprite motion clock freezes in pause")
	check(is_equal_approx(hub_before, particles.get_child(0).time_elapsed), "Third-party compositor clock freezes in pause")
	paused = false
	var hut: InteriorHutHouse = get_first_node_in_group("hut_house")
	player.camera.global_position = hut.global_transform * Vector3(0, 1.8, 0)
	particles._update_zones()
	check(not particles.debug_state().outside, "Hut interior suppresses exterior air")
	var hut_exclusion := true
	var lamp_found := false
	for entry in particles._groups:
		if entry.mode in ["mist", "air"]:
			for material: ShaderMaterial in entry.materials:
				hut_exclusion = hut_exclusion and material.get_shader_parameter("exclude_hut")
		if entry.mode == "lamp" and not lamp_found:
			lamp_found = true
			var light := entry.light as Light3D
			player.camera.global_position = light.global_position + Vector3(1, 0, 0)
			light.visible = false
			particles._update_zones()
			check(entry.target == 0.0, "Hidden practical lamp does not attract moth particles")
	check(hut_exclusion, "Outdoor sprite shader clips the hut interior")
	check(lamp_found, "Moth groups are attached to actual scene lights")
	main.queue_free()
	await frames(2)
	check(not is_instance_valid(particles), "Scene teardown frees the particle controller and its pools")
	print("INTERIOR_PARTICLES_INTEGRATION ", JSON.stringify({"passed": failures.is_empty(), "checks": checks,
		"high": high, "low": low, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
