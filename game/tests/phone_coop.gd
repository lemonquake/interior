extends SceneTree
## 0.64: the squad game on a phone. Run windowed on the phone's renderer:
##   Godot --path game --rendering-method gl_compatibility --script res://tests/phone_coop.gd -- --mobile-test
## Checks: the squad game exists on a phone and starts on Easy; the town's ways to the rice fields and the Nichols
## property are open before it and shut once it begins; both places are gone from a phone; the squad game's touch
## buttons are up; the phone's frame-rate layer runs; blood lands as flat marks (splats, spots, a pool) and parts can
## be torn off; nothing in the log errors.
var game
var session
var failed := []
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed.append(label)
	print("PHONE CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

## A ray across the gap at crouching height: does anything solid (layer 2) stand in it?
func gap_shut(a: Vector3, b: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 2))

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(30)
	check(bool(game.mobile), "running as a phone (-- --mobile-test)")
	session = game.coop
	check(session != null, "the squad game exists on a phone")
	if session == null:
		report()
		return
	check(session.mode == "easy", "a phone's squad game starts on Easy")
	check(Engine.max_physics_steps_per_frame == 3, "physics catch-up capped at three steps")
	check(game.performance != null and game.performance.mobile, "the frame-rate layer runs on the phone")
	var g := InteriorTownSiege.GROUND
	var hole := [Vector3(InteriorTownSiege.HOLE_X, g + .55, InteriorTownSiege.NORTH_Z - 1.0), Vector3(InteriorTownSiege.HOLE_X, g + .55, InteriorTownSiege.NORTH_Z + 1.0)]
	var crawl := [Vector3(InteriorTownSiege.SECRET_X, g + .5, InteriorTownSiege.SOUTH_Z + .7), Vector3(InteriorTownSiege.SECRET_X, g + .5, InteriorTownSiege.SOUTH_Z - 1.0)]
	check(gap_shut(hole[0], hole[1]).is_empty(), "the crouch hole is open before the squad game")
	check(gap_shut(crawl[0], crawl[1]).is_empty(), "the secret crawl is open before the squad game")
	session.page()
	session.host()
	check(session.mode == "easy", "a phone's room is Easy")
	session.start_game()
	await frames(20)
	await create_timer(.5).timeout
	check(session.active, "the squad game began")
	check(game.get_node_or_null("Fields") == null, "the rice fields are gone")
	check(game.get_node_or_null("Balcony/Neighbourhood/Nichols property") == null, "the Nichols property is gone")
	var seals: Node = game.get_node_or_null("Balcony/Neighbourhood/Squad seals")
	check(seals != null, "squad seals built")
	for gap: Array in [["the crouch hole", hole], ["the secret crawl", crawl]]:
		var hit := gap_shut(gap[1][0], gap[1][1])
		check(not hit.is_empty() and seals != null and seals.is_ancestor_of(hit.collider), "%s is shut" % gap[0])
	await create_timer(.6).timeout
	var touch: Node = game.touch
	check(touch.visible, "touch controls up in the squad game")
	for b: String in ["_grenade_button", "_kit_button", "_drop_button"]:
		check((touch.get(b) as Button).visible, "%s shown" % b)
	check(not (touch.get("_chat_button") as Button).visible, "no Chat with nobody to talk to")
	# Fire held keeps the trigger down (an automatic weapon goes on firing) and lifts with the finger.
	touch.fire_held.emit(true)
	check(game.story.gun.trigger_held == game.story.gun.drawn, "Fire held holds the trigger")
	touch.fire_held.emit(false)
	check(not game.story.gun.trigger_held, "Fire lifted lets it go")
	var blood: InteriorBlood = game.zombies.blood
	check(blood.flat == (RenderingServer.get_current_rendering_method() == "gl_compatibility"), "flat blood on the phone renderer")
	var eye: Vector3 = (game.player.global_position as Vector3) + Vector3(0, 1.2, 0)
	var ahead: Vector3 = -(game.player.global_basis.z as Vector3)
	for i in 6:
		blood.wound(null, null, eye + ahead * 1.5, (ahead + Vector3(0, -.6, 0)).normalized(), 60.0, i == 0)
		await frames(2)
	blood.pool(game.player.global_position + ahead * 2.0)
	await frames(90)
	print("PHONE BLOOD splats ", blood.count(), " spots ", blood.spots(), " flying ", blood.flying(),
		" marks ", JSON.stringify(blood.marks.stats) if blood.marks != null else "{}")
	check(blood.count() > 0, "splats landed")
	check(blood.spots() > 0, "drops landed as spots")
	if blood.flat:
		check(int(blood.marks.stats.marks) > 0 and int(blood.marks.stats.sheets) > 0, "marks batched into patches")
	check(blood.spots() + blood.count() > 10, "a good deal of blood")
	report()

func report() -> void:
	print("PHONE COOP %d checks, %d failed: %s" % [checks, failed.size(), ", ".join(failed)])
	quit(1 if not failed.is_empty() else 0)
