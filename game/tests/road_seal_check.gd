extends SceneTree
## 0.66: chapter one put away behind the Old Salmonan gate. Through the gate (stage 4), the squad goes up Store Road;
## past the seal's line the gate rolls shut, and on every peer the home, the town, the canal and the warren are put
## away (hidden, their meshes let go of); the pack that follows comes from this side of the gate; the gate is solid;
## the teleports back there are closed; the mart siege still starts and ends as before.
##   godot --headless --path game --script res://tests/road_seal_check.gd
## Prints INTERIOR_ROAD_SEAL ok|FAIL.
var game
var session
var m
var failed := []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failed.append(label)
	print("SEAL CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func put(local: Vector3) -> void:
	var at: Vector3 = m.ground(m.Street.ORIGIN + local)
	game.player.reset_motion(at)
	session.team[1].pos = at

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.add_bot()
	session.start_game()
	await frames(30)
	m = session.mission
	session.harmless = true
	m.harmless = true
	check(game.get_node_or_null("Fields") == null, "the rice fields let go of at the start (PC too)")
	check(game.get_node_or_null("Balcony/Neighbourhood/Nichols property") == null, "the Nichols property let go of at the start")
	print("SEAL > ", m.debug_command(1, "jump storeroad"))
	await frames(20)
	check(m.stage == 4 and bool(m.flags.get("gate", false)), "stage 4, the gate open")
	check(not bool(m.flags.get("road_shut", false)), "not shut while the squad stands at the gate")
	var room: Node3D = game.get("room")
	put(Vector3(0, 0, 6))
	await frames(30)
	check(not bool(m.flags.get("road_shut", false)), "not shut short of the seal's line")
	put(Vector3(0, 0, 16))
	await frames(40)
	check(bool(m.flags.get("road_shut", false)), "shut once everyone is past the line")
	check(not bool(m.flags.get("gate", false)) and m.street.gate.position.x == 0.0, "the gate rolled shut")
	check(m.road_unloaded, "chapter one put away on this peer")
	check(not m.guide.visible, "Dodong (at home in the warren) put away")
	if room != null: check(not room.is_visible_in_tree(), "the home put away")
	var town: Node3D = game.get_node_or_null("Balcony/Neighbourhood")
	if town != null: check(not town.is_visible_in_tree() or _hidden_share(town) > .8, "the town put away (%.0f%% of its drawn pieces hidden)" % (_hidden_share(town) * 100.0))
	check(m.place_closed("farbank") != "", "the far bank teleport closed (%s)" % m.place_closed("farbank"))
	check(m.place_closed("martfront") == "", "the mart front still open")
	# The gate is solid: a ray along the road at chest height stops at it.
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var o: Vector3 = m.Street.ORIGIN + m.Street.GATE
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(.5, 1.2, 3.0), o + Vector3(.5, 1.2, -3.0), 2))
	check(not hit.is_empty(), "the shut gate stops a body")
	# The pack: spawned on this side of the gate.
	m.next_spawn = 0.0
	m.wave_left = 4
	var behind := 0
	var made := 0
	for i in 8:
		m.next_spawn = 0.0
		var before: int = m.enemies.size()
		var p: Dictionary = session.team[1]
		if m.spawn_near(p):
			made += 1
		await frames(2)
	for z in m.enemies.values():
		if (z.position - m.Street.ORIGIN).z < m.Street.GATE.z - .5: behind += 1
	check(made > 0 and behind == 0, "the pack comes from this side of the gate (%d spawned, %d behind it)" % [made, behind])
	# Leaving the run: the siege still starts at the mart.
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	m.wave_left = 0
	for who in session.team: session.team[who].pos = m.Street.ORIGIN + m.Street.STORE
	put(m.Street.STORE)
	await frames(30)
	check(m.stage == 5, "the siege starts at the mart (stage %d)" % m.stage)
	print("INTERIOR_ROAD_SEAL ", "ok" if failed.is_empty() else "FAIL " + str(failed))
	quit(0 if failed.is_empty() else 1)

func _hidden_share(n: Node) -> float:
	var all := 0
	var hidden := 0
	for c in n.find_children("*", "MeshInstance3D", true, false):
		all += 1
		if not (c as Node3D).is_visible_in_tree() or (c as MeshInstance3D).mesh == null: hidden += 1
	return float(hidden) / maxf(1.0, all)
