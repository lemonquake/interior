extends SceneTree
## 0.58: survivors' health doubled (Mission.MAX_HP), a teammate in the red has a red, beating tag, a downed teammate
## has the downed marker (scripts/world_markers.gd), a live grenade is marked with its fuse and distance, and
## everything that can be picked up shines white (scripts/pickup_shine.gdshader). Checks, and review frames.
##   godot --path game --script res://tests/coop_markers_review.gd -- --render-size=1600x900 [--out=<dir>]
var main
var out := "res://../work/v58/markers"
var results := []

func _initialize() -> void: call_deferred("_run")

func frames(n: int) -> void:
	for i in n: await process_frame

func check(ok: bool, what: String) -> void:
	print("MARKERS CHECK ", what, " ", ok)
	if not ok: results.append(what)

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(out).path_join(label + ".png")
	main.get_viewport().get_texture().get_image().save_png(path)
	print("MARKERS SHOT ", path)

func look_at_point(p: Vector3) -> void:
	var player: InteriorPlayer = main.player
	var to := p - player.camera.global_position
	player.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
	player.set("_look_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
	player.camera.rotation.x = player.get("_look_pitch")
	player.aim_offset = Vector2.ZERO

## The squad AI kept where the frame wants them (they would walk off otherwise).
func pin(s, id: int, at: Vector3, yaw: float) -> void:
	var b = s.bots.bots[id]
	b.body.global_position = at
	b.body.velocity = Vector3.ZERO
	s.team[id].pos = at
	s.team[id].yaw = yaw

func hold(s, places: Dictionary, n: int) -> void:
	for i in n:
		for id in places: pin(s, id, places[id][0], places[id][1])
		await process_frame

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
	s.harmless = true
	m.wave_left = 0
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	check(int(s.team[1].hp) == 200 and m.MAX_HP == 200, "a survivor starts with 200 HP (%d)" % int(s.team[1].hp))
	var stand: Vector3 = m.ground(m.Street.ORIGIN + Vector3(0, 0, 22))
	var player: InteriorPlayer = main.player
	player.reset_motion(stand)
	s.team[1].pos = stand
	main.story.flashlight.give()
	if not main.story.flashlight.on: main.story.flashlight.toggle()
	await frames(10)
	var bots: Array = s.bots.bots.keys()
	check(bots.size() >= 2, "two squad AI to show (%d)" % bots.size())
	var ahead := Vector3(0, 0, -1)
	var hurt_id: int = bots[0]
	var down_id: int = bots[1]
	var places := {
		hurt_id: [m.ground(stand + ahead * 6.0 + Vector3(-1.6, 0, 0)), PI * .1],
		down_id: [m.ground(stand + ahead * 9.0 + Vector3(2.2, 0, 0)), -PI * .4],
	}
	for k in range(2, bots.size()): places[bots[k]] = [m.ground(stand + Vector3(-2.0 - k, 0, 3.0)), 0.0]
	for id in bots: s.team[id].kits = 0
	s.team[hurt_id].hp = 45
	s.team[down_id].hp = 0
	# Drops on the street between: a kit, ammunition, a rifle, and the shine on all of them.
	m.drops[90001] = [m.ground(stand + ahead * 2.6 + Vector3(-.5, 0, 0)), "healthkit:medium"]
	m.drops[90002] = [m.ground(stand + ahead * 2.9 + Vector3(.45, 0, 0)), "ammo:large"]
	m.drops[90003] = [m.ground(stand + ahead * 3.7 + Vector3(-.1, 0, 0)), "weapon:rifle", [30, true, 60]]
	await hold(s, places, 40)
	var shines := 0
	for k in [90001, 90002, 90003]:
		var node: Node = m.drop_nodes.get(k)
		if node == null: continue
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			if (mesh as MeshInstance3D).material_overlay != null: shines += 1
	check(shines >= 3, "the drops shine (%d meshes)" % shines)
	var hurt_tag: Label3D = s.avatars[hurt_id].caption
	check(hurt_tag.modulate.r > .9 and hurt_tag.modulate.g < .6, "a teammate in the red has a red tag (%s)" % hurt_tag.modulate)
	check(s.avatars[down_id].caption.text == "", "a downed teammate's tag gives way to the marker")
	var marks = main.get_node_or_null("WorldMarkers")
	check(marks != null and marks.shown("down") == 1, "one downed marker")
	look_at_point(stand + ahead * 6.0 + Vector3.UP * .6)
	await hold(s, places, 20)
	await shot("01_red_tag_down_marker_shine")
	# A grenade lobbed toward them: highlighted, its fuse and distance marked.
	main.grenades.call("_spawn", "test:1", player.camera.global_position + ahead * .5, ahead * 5.0 + Vector3.UP * 2.6, 3.4, false)
	await hold(s, places, 26)
	check(marks.shown("grenade") == 1, "the live grenade is marked")
	await shot("02_grenade_in_flight")
	await hold(s, places, 40)
	await shot("03_grenade_landed")
	# Turned away: both pinned to the edge of the view.
	look_at_point(stand - ahead * 6.0 + Vector3(4.0, .8, 0))
	await hold(s, places, 6)
	await shot("04_behind_pinned")
	await hold(s, places, 120)
	check(marks.shown("grenade") == 0, "gone once it has gone off")
	# Close up on the shine.
	look_at_point(stand + ahead * 3.0 + Vector3.DOWN * .3)
	await hold(s, places, 10)
	await shot("05_shine_close")
	await hold(s, places, 25)
	await shot("06_shine_close_glint")
	print("MARKERS RESULT %d failed %s" % [results.size(), results])
	s.end_session()
	quit()
