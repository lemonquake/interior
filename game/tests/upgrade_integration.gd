extends SceneTree

var failures: Array[String] = []
var checks := 0
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

func _node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _node_count(child)
	return count

func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var main = packed.instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(4)
	check(not main.control_lab,"The production room must cold-load")
	var stats: Dictionary = main.room.get_meta("room_visuals_stats",{})
	check(int(stats.get("family_photos",0)) == 8,"All eight family photos must appear on actual frame surfaces")
	check(int(stats.get("detail_meshes",0)) >= 20,"Attached room object detail must load")
	for i in 8:
		var texture := load("res://assets/family/family_%d.jpg" % i) as Texture2D
		check(texture != null and texture.get_width() >= 512,"Photo must have a usable imported texture: " + str(i))
	var movable := get_nodes_in_group("movable")
	check(get_nodes_in_group("original_room_props").size() == InteriorRoomBuilder.load_manifest().actors.size(),"Every manifest actor (45 after decluttering) must be one original physical prop assembly")
	check(get_nodes_in_group("aquariums").size() == 2,"Both aquariums must be below the linked habitats")
	var aquariums := get_nodes_in_group("aquariums")
	for aquarium in aquariums:
		check(aquarium.global_position.y < .3,"Aquariums must occupy the lower shelf")
		check(aquarium.fish.size() == 2,"Each aquarium must contain two live fish")
	for body: InteriorObject in movable:
		# Small or light props use CCD so throws cannot tunnel; large furniture does not need it.
		check(body.continuous_cd or body.mass >= 6.0,"Small movable props must use continuous collision detection: " + str(body.name))
		check(body.physics_material_override != null,"Prop friction must be defined: " + str(body.name))
		check(body.center_of_mass.is_finite(),"Prop center of mass must be finite: " + str(body.name))
	var fan := main.room.get_node("standing_fan_5") as InteriorObject
	check(fan != null,"The standing fan must be present")
	if fan != null:
		var shapes := 0
		for child in fan.get_children():
			if child is CollisionShape3D:
				shapes += 1
		check(shapes == 3,"Fan collisions must follow base, pole and guard")
	var frame := main.room.get_node("photo_frame_19") as InteriorObject
	check(not frame.anchored,"A table photo frame must be movable by contact")
	main.player.target = frame
	main.player.grab_object(frame)
	main._process(1.0/60.0)
	check(main.prompt.text.contains("Drop"),"A held object must show its drop action")
	main.player.release_object()
	main._process(1.0/60.0)
	check(main.prompt.text.contains("Hold") and not main.prompt.text.contains("Throw"),"Dropping without changing target must refresh the hold action")
	frame.recover()
	var enclosure := main.room.get_node("pet_enclosure_11") as InteriorObject
	var habitat := enclosure.get_node_or_null("HamsterPlayground")
	check(habitat != null,"Rebuilt hamster playground must replace the old enclosure")
	var pets := get_nodes_in_group("hamsters")
	check(pets.size() == 3,"Exactly three live hamsters must cold-load")
	var positions: Array[Vector3] = []
	var elapsed_values: Array[float] = []
	for pet in pets:
		positions.append(pet.position)
		elapsed_values.append(pet.elapsed)
		check(pet.skeleton != null and pet.skeleton.get_bone_count() >= 9,"Hamster must use the imported skin skeleton")
		check(pet.animation_player != null and pet.animation_player.get_animation_list().size() >= 8,"Hamster must have walk/run, four idles and play clips")
		check(pet.process_mode == Node.PROCESS_MODE_PAUSABLE,"Hamster must pause with the room")
	main._show_menu("pause")
	var aquarium_time: float = aquariums[0].elapsed
	for i in 12:
		await process_frame
	check(is_equal_approx(aquariums[0].elapsed,aquarium_time),"Pause must stop aquarium animation")
	for i in pets.size():
		check(pets[i].position.is_equal_approx(positions[i]) and is_equal_approx(pets[i].elapsed,elapsed_values[i]),"Pause must freeze hamster position and pose time")
	main._play()
	await _frames(30)
	check(aquariums[0].elapsed > aquarium_time,"Resume must restart aquarium animation")
	for i in pets.size():
		check(pets[i].elapsed > elapsed_values[i],"Resume must restart hamster state and animation time")
	if habitat != null:
		var pet_local: Vector3 = pets[0].position
		enclosure.global_position += Vector3(.08,.04,.06)
		check(pets[0].position.is_equal_approx(pet_local),"Pet transforms must stay relative when enclosure moves")
		enclosure.recover()
	for index in 3:
		main._apply_quality(index)
		check(main.quality == index,"Every graphics setting must update")
	main.mobile = true
	main._apply_quality(0)
	check(main.get_viewport().msaa_3d == Viewport.MSAA_DISABLED,"Android Low must disable multisample antialiasing")
	for light in main._room_lights:
		check(not light.shadow_enabled,"Android Low must avoid dynamic light shadows")
	results["visuals"] = stats
	results["hamsters"] = pets.size()
	results["movable_props"] = movable.size()
	var baseline_nodes := _node_count(main)
	results["cold_scene_nodes"] = baseline_nodes
	main._restart()
	await _frames(4)
	main = current_scene
	check(main != null and not main.player.playing,"Restart must reload the actual main scene into its home menu")
	check(get_nodes_in_group("hamsters").size() == 3,"Actual Restart must restore exactly three pets")
	main._play()
	await _frames(4)
	check(_node_count(main) == baseline_nodes,"Actual Restart must have stable entity allocation")
	# Real teardown/recreation catches duplicate actor/listener ownership.
	for cycle in 3:
		paused = false
		main.queue_free()
		await _frames(3)
		check(get_nodes_in_group("movable").is_empty() and get_nodes_in_group("hamsters").is_empty(),"Teardown must release every prop and pet")
		main = packed.instantiate()
		root.add_child(main)
		current_scene = main
		main._play()
		await _frames(4)
		check(get_nodes_in_group("original_room_props").size() == InteriorRoomBuilder.load_manifest().actors.size() and get_nodes_in_group("hamsters").size() == 3,"Restart must recreate exactly one room and three pets")
		check(_node_count(main) == baseline_nodes,"Restart must have stable node allocation")
	main.queue_free()
	paused = false
	await _frames(3)
	print("INTERIOR_UPGRADE_INTEGRATION ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"results":results}))
	quit(0 if failures.is_empty() else 1)
