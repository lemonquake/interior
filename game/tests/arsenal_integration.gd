extends SceneTree
## 0.48: the named arsenal (scripts/arsenal.gd), the drops scattered on the waypoint graph (scripts/waypoints.gd),
## sized healthkits and ammunition boxes, T shoving (infected, the ones behind them, tables), Enter for the chat.
## `-- --shots=<dir>` saves a frame of every weapon in the hands.
var game
var session
var failed := []
var checks := 0
var shots := ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("ARSENAL CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func seconds(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end: await physics_frame

func shot(name: String) -> void:
	if shots == "": return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_jpg(shots.path_join(name + ".jpg"), .9)
	print("ARSENAL SHOT ", shots.path_join(name + ".jpg"))

func stand(at: Vector3, yaw: float) -> void:
	var player: InteriorPlayer = game.player
	player.reset_motion(at)
	player.rotation.y = yaw
	session.team[1].pos = at
	session.team[1].yaw = yaw

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="): shots = a.trim_prefix("--shots=")
	if shots != "": DirAccess.make_dir_recursive_absolute(shots)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.set_mode("easy")
	session.start_game()
	await frames(20)
	session.harmless = true
	var m = session.mission
	var gun: InteriorGun = game.story.gun
	var o: Vector3 = m.Street.ORIGIN
	var road: Vector3 = m.ground(o + Vector3(0, 0, 30))
	stand(road, PI)
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	await frames(5)
	gun.instant_hits = true

	# ---------------------------------------------------------------- every weapon
	var counts := {"pistol": 0, "rifle": 0, "shotgun": 0, "sniper": 0}
	var names := {}
	for id: String in InteriorArsenal.WEAPONS:
		var cls := InteriorArsenal.class_of(id)
		counts[cls] += 1
		names[InteriorArsenal.display_name(id)] = true
		var p: Dictionary = gun.profile_of(id)
		gun.give_model(id, int(p.mag) * 2)
		gun.select(cls)
		await seconds(1.1)
		var shown := false
		if InteriorArsenal.is_stock(id):
			shown = gun.drawn
		elif cls == "pistol":
			shown = gun._pistol_kits.has(id) and (gun._pistol_kits[id].node as Node3D).visible
		else:
			shown = gun._longs.has(id) and (gun._longs[id].node as Node3D).visible and gun._rifle == gun._longs[id].node
		check(gun.weapon == cls and str(gun.models[cls]) == id and gun.drawn, "%s in the hands" % InteriorArsenal.display_name(id))
		check(shown, "%s shows its own model" % InteriorArsenal.display_name(id))
		check(gun.mag_size() == int(p.mag), "%s magazine %d" % [InteriorArsenal.display_name(id), int(p.mag)])
		var before := gun.loaded()
		gun.try_fire()
		await seconds(.6)
		var used := before - gun.loaded()
		var want := int(p.get("burst", 1)) if int(p.get("burst", 0)) > 1 else 1
		check(used == want, "%s fires %d a pull (%d)" % [InteriorArsenal.display_name(id), want, used])
		if str(p.get("cycle", "hand")) == "self":
			check(gun._pump_t < 0.0, "%s cycles itself" % InteriorArsenal.display_name(id))
		await shot("weapon_" + id)
		if id == "titan_b50" or id == "drakon_svd":
			gun.aiming = true
			Input.action_press("aim")
			await seconds(1.2)
			check(gun.scoped > .8 and gun.scope_zoom >= float(p.scope_min) and gun.scope_zoom <= float(p.scope_max), "%s scope %dx in %d-%d" % [InteriorArsenal.display_name(id), int(gun.scope_zoom), int(p.scope_min), int(p.scope_max)])
			await shot("scope_" + id)
			Input.action_release("aim")
			await seconds(.6)
	check(counts.pistol == 5 and counts.rifle == 11 and counts.shotgun == 5 and counts.sniper == 4, "4 + 10 + 4 + 3 new weapons beside the stock four %s" % str(counts))
	check(names.size() == InteriorArsenal.WEAPONS.size(), "every weapon has its own name")
	var eruption: Dictionary = gun.profile_of("eruption_ad15")
	check(float(eruption.damage) * float(eruption.sever) * float(eruption.head_pop) > InteriorZombie.HEAD_BURST * 2.0 and float(eruption.interval) > .5,
		"Eruption AD-15: a head shot bursts the head, and it is slow")
	check(float(gun.profile_of("viper_v9").interval) < float(gun.profile_of("gtk44").interval) and float(gun.profile_of("gtk44").interval) > float(gun.profile_of("hornet_mp9").interval),
		"rifles fire at very different rates")

	# ---------------------------------------------------------------- one of each kind: a swap leaves the other behind
	gun.give_model("glock17", 30)
	gun.select("pistol")
	await seconds(.8)
	var before_drops: int = m.drops.size()
	session.give_weapon(1, "beretta_hi91", [15, true, 15])
	await frames(10)
	var left := false
	for k in m.drops:
		if str(m.drops[k][1]) == "weapon:glock17": left = true
	check(str(gun.models.pistol) == "beretta_hi91" and left and m.drops.size() == before_drops + 1, "picking up a Beretta Hi-91 puts the Glock down")

	# ---------------------------------------------------------------- healthkits and ammunition
	var p1: Dictionary = session.team[1]
	p1.kits = 0
	p1.kit_sizes = []
	m.add_kit(p1, "small")
	m.add_kit(p1, "large")
	check(int(p1.kits) == 2, "two kits carried")
	check(m.take_kit(p1, 15) == "small" and m.take_kit(p1, 90) == "large" and int(p1.kits) == 0, "the smallest kit that covers it, else the largest")
	m.add_kit(p1, "large")
	p1.hp = 10
	m.start_heal(1, 1)
	await seconds(3.4)
	check(int(p1.hp) >= 85, "a large trauma kit gives 75-100 (hp %d)" % int(p1.hp))
	gun.select("rifle")
	await seconds(.8)
	var r0 := gun.reserve
	session.supplies("ammo:large")
	check(gun.reserve - r0 == int(InteriorArsenal.AMMO_BOX.rifle[2]), "a large box: %d rifle rounds" % (gun.reserve - r0))
	r0 = gun.reserve
	session.supplies("ammo:small")
	check(gun.reserve - r0 == int(InteriorArsenal.AMMO_BOX.rifle[0]), "a small box: %d rifle rounds" % (gun.reserve - r0))

	# ---------------------------------------------------------------- waypoints and the scattered drops
	var t0 := Time.get_ticks_msec()
	while m.nav.waypoints == null or m.nav.waypoints.pending() > 0:
		await physics_frame
		if Time.get_ticks_msec() - t0 > 60000: break
	var wp: InteriorWaypoints = m.nav.waypoints
	print("ARSENAL WAYPOINTS nodes %d links %d ms %d" % [wp.nodes.size(), wp.links, wp.usec / 1000])
	check(wp != null and wp.nodes.size() > 300 and wp.links > 600, "waypoint graph round the player (%d nodes, %d links)" % [wp.nodes.size() if wp else 0, wp.links if wp else 0])
	var way: PackedVector3Array = wp.route(road, m.ground(o + Vector3(0, 0, 8)))
	check(way.size() > 6, "a way along Store Road over the waypoints (%d nodes)" % way.size())
	var far_path: PackedVector3Array = m.nav.path(road, m.ground(o + Vector3(0, 0, 60)))
	check(not far_path.is_empty() and m.nav.routed > 0, "a far search goes by the waypoints (%d legs routed)" % m.nav.routed)
	await seconds(3.0)
	var joined: PackedInt32Array = wp.joined(road)
	var seeded := 0
	var weapons := 0
	var reachable := 0
	for k in m.drops:
		if int(k) <= 100000: continue
		var kind := str(m.drops[k][1])
		if kind == "weapon:glock17": continue
		seeded += 1
		if kind.begins_with("weapon:"): weapons += 1
		var n := wp.nearest(m.drops[k][0])
		if n >= 0 and n in joined: reachable += 1
	print("ARSENAL DROPS seeded %d weapons %d reachable %d" % [seeded, weapons, reachable])
	check(weapons >= 2, "weapons lie about the map (%d)" % weapons)
	check(seeded > 0 and reachable == seeded, "every scattered drop stands on the walk graph joined to the player (%d of %d)" % [reachable, seeded])

	# ---------------------------------------------------------------- T: the shove
	stand(road, PI)
	await frames(5)
	var forward := Vector3(-sin(PI), 0, -cos(PI))
	var front = m.spawn(m.ground(road + forward * 1.1))
	var behind = m.spawn(m.ground(road + forward * 1.9))
	var aside = m.spawn(m.ground(road + forward * -6.0))
	await frames(20)
	var at_front: Vector3 = front.position
	var at_behind: Vector3 = behind.position
	m.shove(1)
	await frames(2)
	check(front.stun > .4, "T: the one in front reels (%.2f)" % front.stun)
	check(behind.stun > .3, "it stumbles into the one behind it (%.2f)" % behind.stun)
	check(aside.stun <= 0.0, "nobody behind the player is shoved")
	await frames(40)
	var moved_front: float = front.position.distance_to(at_front)
	var moved_behind: float = behind.position.distance_to(at_behind)
	check(moved_front > .3 and moved_behind > .2, "both are driven back (%.2f m, %.2f m)" % [moved_front, moved_behind])
	for z in [front, behind, aside]:
		m.enemies.erase(z.key)
		z.queue_free()
	var table: RigidBody3D = m.street.tables[0]
	var t_at := table.global_position
	var to_table := Vector3(t_at.x, road.y, t_at.z) - forward * 1.1
	stand(m.ground(to_table + Vector3.UP), PI)
	await frames(10)
	t_at = table.global_position
	await seconds(.8)
	m._shove_ready.clear()
	m.shove(1)
	await seconds(1.0)
	check(table.global_position.distance_to(t_at) > .15, "a table is shoved along (%.2f m)" % table.global_position.distance_to(t_at))
	# T no longer opens the chat, Enter does (with someone to talk to).
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	key.keycode = KEY_T
	key.pressed = true
	session._shove_at = -10.0
	session._input(key)
	session._unhandled_input(key)
	check(not session.chatting and session._shove_at > 0.0, "T shoves and does not open the chat")
	var src: String = FileAccess.get_file_as_string("res://scripts/coop/session.gd")
	check(src.contains("keycode in [KEY_ENTER, KEY_KP_ENTER] and humans() > 1") and not src.contains("physical_keycode == KEY_T or"), "Enter opens the chat")

	print("INTERIOR_ARSENAL ", JSON.stringify({"passed": failed.is_empty(), "checks": checks, "failures": failed}))
	quit(0 if failed.is_empty() else 1)
