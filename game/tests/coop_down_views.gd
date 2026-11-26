extends SceneTree
## 0.43: the new prone and crouch clips in the game itself: survivors lying down and crawling (seen by the others),
## Dodong Sikma bent double, a downed player's own view while crawling, and a grenade thrown into a co-op crowd.
##   godot --path game --script res://tests/coop_down_views.gd -- --render-size=1600x900 [--out=<dir>]
var main
var out := "res://../work/v43/coop_down"

func _initialize() -> void: call_deferred("_run")

func frames(n: int) -> void:
	for i in n: await process_frame

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(out).path_join(label + ".png")
	main.get_viewport().get_texture().get_image().save_png(path)
	print("INTERIOR_COOP_DOWN_VIEW ", path)

func look_at_point(p: Vector3) -> void:
	var player: InteriorPlayer = main.player
	var to := p - player.camera.global_position
	player.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
	player.set("_look_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
	player.camera.rotation.x = player.get("_look_pitch")
	player.aim_offset = Vector2.ZERO

func figure(model: String, at: Vector3, yaw: float, title := ""):
	var f = load("res://scripts/coop/figure.gd").new()
	main.coop.add_child(f)
	f.setup(model, at, title)
	f.rotation.y = yaw
	return f

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40: await process_frame
	main.capturing = true
	var s = main.coop
	s.host()
	s.fill_bots()
	s.start_game()
	await frames(30)
	var m = s.mission
	for i in 4: m.debug_skip()
	m.harmless = true
	m.wave_left = 0
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	var stand: Vector3 = m.ground(m.Street.ORIGIN + Vector3(0, 0, 22))
	var player: InteriorPlayer = main.player
	player.reset_motion(stand)
	s.team[1].pos = stand
	await frames(10)
	# Three survivors in front of the lens: one crawling, one lying, one walking bent double (Dodong's clip).
	var ahead := Vector3(0, 0, -1)
	var crawler = figure("res://assets/characters/survivors/alex.glb", stand + ahead * 3.2 + Vector3(-1.1, 0, 0), 0.0)
	var lying = figure("res://assets/characters/survivors/clyde.glb", stand + ahead * 3.6 + Vector3(1.2, 0, 0), .6)
	var bent = figure("res://assets/characters/zombies/z_tanod.glb", stand + ahead * 5.5 + Vector3(.2, 0, 0), PI * .5)
	crawler.pose("crawl")
	lying.pose("down_idle")
	bent.pose("crouch_walk")
	main.story.flashlight.give()
	if not main.story.flashlight.on: main.story.flashlight.toggle()
	look_at_point(stand + ahead * 4.0 + Vector3.UP * .35)
	await frames(40)
	await shot("down_01_crawl_lie_crouch")
	await frames(17)
	await shot("down_02_crawl_lie_crouch")
	# From the side.
	player.reset_motion(stand + ahead * 3.4 + Vector3(3.2, 0, 0))
	await frames(2)
	look_at_point(stand + ahead * 3.8 + Vector3.UP * .4)
	await frames(20)
	await shot("down_03_side")
	await frames(13)
	await shot("down_04_side")
	crawler.queue_free()
	lying.queue_free()
	bent.queue_free()
	# The player goes down and crawls forward: their own view.
	player.reset_motion(stand)
	await frames(2)
	look_at_point(stand + ahead * 8.0 + Vector3.UP * .4)
	for id in s.team: s.team[id].kits = 0
	s.team[1].hp = 0
	await frames(30)
	Input.action_press("forward")
	await frames(70)
	print("INTERIOR_DOWN eye %.2f crawled %.2f m downed %s" % [player.camera.global_position.y - player.global_position.y, Vector2(player.global_position.x - stand.x, player.global_position.z - stand.z).length(), player.downed])
	await shot("down_05_own_view_crawling")
	Input.action_release("forward")
	s.team[1].hp = 200
	await frames(20)
	# A grenade into a co-op crowd: the infected thrown, wounded, torn.
	player.reset_motion(stand)
	await frames(2)
	for i in 6: m.spawn(m.ground(stand + ahead * (9.0 + (i % 2) * 1.2) + Vector3((i - 2.5) * .9, 0, 0)))
	for k in m.enemies.keys(): m.enemies[k].asleep = true
	look_at_point(stand + ahead * 9.5 + Vector3.UP * .8)
	await frames(60)
	await shot("down_06_crowd")
	main.grenades.give(1)
	main.grenades.call("_spawn", "test:1", player.camera.global_position + ahead * .5, ahead * 8.4 + Vector3.UP * 3.0, 1.5, true)
	await frames(95)
	await shot("down_07_blast")
	await frames(12)
	await shot("down_08_blast")
	await frames(120)
	await shot("down_09_after")
	print("INTERIOR_DOWN infected left %d bodies %d" % [m.enemies.size(), m.corpses.size()])
	s.end_session()
	quit()
