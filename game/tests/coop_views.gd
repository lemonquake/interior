extends SceneTree
## 0.40: rendered stills of co-op for the handoff: the squad AI fighting up Store Road, a body down as a ragdoll,
## the voice menu and radio feed, the rifle on its sights.
##   godot --path game --script res://tests/coop_views.gd -- --render-size=1920x1080 [--out=<dir>]
var main
var out := "res://../work/v40/screens"

func _initialize() -> void: call_deferred("_run")

func frames(n: int) -> void:
	for i in n: await process_frame

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(out).path_join(label+".png")
	main.get_viewport().get_texture().get_image().save_png(path)
	print("INTERIOR_COOP_VIEW ",path)

func look_at_point(p: Vector3) -> void:
	var player: InteriorPlayer = main.player
	var to := p-player.camera.global_position
	player.rotation = Vector3(0,atan2(-to.x,-to.z),0)
	player.set("_look_pitch",atan2(to.y,Vector2(to.x,to.z).length()))
	player.camera.rotation.x = player.get("_look_pitch")
	player.aim_offset = Vector2.ZERO

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
	var stand: Vector3 = m.ground(m.Street.ORIGIN+Vector3(0,0,22))
	var player: InteriorPlayer = main.player
	player.reset_motion(stand)
	s.team[1].pos = stand
	for id in s.bots.bots: s.bots.bots[id].body.global_position = stand+Vector3(randf_range(-1.5,1.5),.1,1.0+randf())
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	await frames(10)
	# Third person-ish: the squad from behind, the crowd up the road.
	for i in 8: m.spawn(m.ground(stand+Vector3(randf_range(-3,3),0,-12-i*1.2)))
	look_at_point(stand+Vector3(0,1.0,-14))
	await frames(150)
	await shot("coop_squad_fighting")
	await frames(140)
	await shot("coop_squad_fighting_2")
	# A body close up: one shotgun blast and the ragdoll.
	var gun: InteriorGun = main.story.gun
	gun.give_shotgun()
	gun.select("shotgun")
	await frames(80)
	for id in s.bots.bots: s.bots.bots[id].mag = 0
	for id in s.bots.bots: s.bots.bots[id].reserve = 0
	m.spawn(m.ground(stand+Vector3(0,0,-4)))
	var z = m.enemies[m.next_id]
	z.asleep = true
	await frames(30)
	look_at_point(z.global_position+Vector3.UP*1.0)
	await frames(10)
	await shot("coop_before_blast")
	gun.instant_hits = true
	var eye: Vector3 = player.camera.global_position
	var chest: Vector3 = (z.bodies["chest"] as Node3D).global_position
	for i in 9: gun._fire_round(eye,((chest-eye).normalized()+Vector3(randf_range(-.02,.02),randf_range(-.02,.02),0)).normalized(),InteriorGun.PROFILES.shotgun,i)
	await frames(12)
	await shot("coop_blast_ragdoll_falling")
	await frames(120)
	look_at_point(z.where()+Vector3.UP*.2)
	await frames(6)
	await shot("coop_ragdoll_down")
	# The voice menu and the feed.
	s.player_line("lets_go")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_QUOTELEFT
	ev.pressed = true
	s.voices._input(ev)
	await frames(20)
	await shot("coop_voice_menu")
	s.voices._input(ev)
	# The rifle on its sights.
	gun.give_rifle()
	gun.select("rifle")
	await frames(90)
	look_at_point(stand+Vector3(0,1.4,-20))
	Input.action_press("aim")
	await frames(70)
	await shot("coop_rifle_on_sights")
	Input.action_release("aim")
	await frames(50)
	await shot("coop_rifle_hip")
	s.end_session()
	quit()
