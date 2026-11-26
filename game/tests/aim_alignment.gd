extends SceneTree
## 0.40: the weapon on the screen points where its rounds land. On the sights the rear notch and the front post
## sit in the middle of the picture and the round lands there; at the hip the round lands where the drawn sight line
## vanishes; and a quick string of shots lands where the weapon was drawn pointing at each trigger pull.
##   godot --headless --fixed-fps 60 --path game --script res://tests/aim_alignment.gd [-- --legacy-aim]
var main
var gun: InteriorGun
var failed := []
var checks := 0
var rows := {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("AIM CHECK ",label," ",ok)

func frames(n: int) -> void:
	for i in n: await process_frame

func screen_of(world: Vector3) -> Vector2:
	var cam: Camera3D = main.player.camera
	var size := Vector2(main.get_viewport().get_visible_rect().size)
	return (cam.unproject_position(world)-size*.5)/size.y

func view_screen(local: Vector3) -> Vector2:
	var cam: Camera3D = gun._view_camera
	var size := Vector2(gun._viewport.size)
	return (cam.unproject_position(cam.global_transform*local)-size*.5)/size.y

func sights() -> Array:
	if gun.weapon=="pistol":
		var inv: Transform3D = gun._view_camera.global_transform.affine_inverse()*gun._glock.global_transform
		return [inv*InteriorGun.PISTOL_REAR_SIGHT,inv*InteriorGun.PISTOL_FRONT_SIGHT]
	return [gun._rifle.transform*(gun._rifle_at["rear_sight"] as Vector3),gun._rifle.transform*(gun._rifle_at["front_sight"] as Vector3)]

func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	main._play()
	var stranger: Node = main.get_node_or_null("Stranger")
	if stranger!=null: stranger.process_mode = Node.PROCESS_MODE_DISABLED
	gun = main.story.gun
	main.story.debug_give_gun()
	gun.give_rifle()
	gun.give_shotgun()
	gun.infinite_ammo = true
	gun.instant_hits = true
	# A wall 12 m ahead in the open street.
	var player: InteriorPlayer = main.player
	var stand := Vector3(20.3,-2.9,6.0)
	player.reset_motion(stand)
	player.rotation = Vector3.ZERO
	player.set("_look_pitch",0.0)
	player.camera.rotation.x = 0.0
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(14,8,.3)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 2
	main.add_child(wall)
	await physics_frame
	wall.global_position = player.camera.global_position+Vector3(0,0,-12)
	await frames(4)
	for weapon in ["pistol","rifle","shotgun"]:
		gun.select(weapon)
		await frames(70)
		if not gun.drawn: gun.draw()
		await frames(60)
		player.aim_offset = Vector2.ZERO
		gun.spread_scale = 0.0
		# On the sights.
		Input.action_press("aim")
		await frames(90)
		var s: Array = sights()
		var rear := view_screen(s[0])
		var front := view_screen(s[1])
		check(rear.length()<.015 and front.length()<.008,"%s: on the sights the notch and the post are in the middle (rear %s, front %s)"%[weapon,rear.snapped(Vector2.ONE*.001),front.snapped(Vector2.ONE*.001)])
		gun._hitscan()
		await frames(1)
		var hit: Vector2 = screen_of(gun.last_hit.position) if not gun.last_hit.is_empty() else Vector2.ONE
		check(hit.distance_to(front)<(.03 if weapon=="shotgun" else .008),"%s: on the sights the round lands on the post (%.4f of the screen apart)"%[weapon,hit.distance_to(front)])
		# At the hip.
		Input.action_release("aim")
		await frames(90)
		var vanish := screen_of(player.camera.global_position+gun.drawn_aim()*50.0) if gun.drawn_aim().is_finite() else Vector2.ONE
		gun._hitscan()
		hit = Vector2.ZERO
		for h in gun.last_hits: hit += screen_of(h.position)/float(gun.last_hits.size())
		if gun.last_hits.is_empty(): hit = Vector2.ONE
		await frames(1)
		check(hit.distance_to(vanish)<(.03 if weapon=="shotgun" else .01) and vanish.length()<.05,"%s: from the hip the round lands where the barrel points (%.4f apart, %.3f off centre)"%[weapon,hit.distance_to(vanish),vanish.length()])
		# A quick string on the sights: each round goes where the weapon was drawn pointing.
		Input.action_press("aim")
		await frames(60)
		var worst := 0.0
		var spots: Array[Vector3] = []
		for i in 6:
			var before := gun.drawn_aim()
			var expect := screen_of(player.camera.global_position+before*50.0) if before.is_finite() else Vector2.ZERO
			gun.last_hit = {}
			if gun.ready_to_fire(): gun.try_fire()
			if not gun.last_hit.is_empty():
				# Read before the shot's kick moves the lens.
				var at := screen_of(gun.last_hit.position)
				spots.append(gun.last_hit.position)
				worst = maxf(worst,at.distance_to(expect))
			await frames(int(float(InteriorGun.PROFILES[weapon].interval)*60.0)+1)
		var spread := 0.0
		for a in spots:
			for b in spots: spread = maxf(spread,a.distance_to(b))
		rows[weapon] = {"string_spread_m_at_12m": snappedf(spread,.001),"worst_vs_drawn": snappedf(worst,.0001)}
		print("AIM ROW ",weapon," ",JSON.stringify(rows[weapon]))
		if not gun.legacy_aim and weapon!="shotgun":
			check(worst<.01,"%s: quick shots land where the weapon was drawn (worst %.4f)"%[weapon,worst])
		Input.action_release("aim")
	print("INTERIOR_AIM ",JSON.stringify({"passed":failed.is_empty(),"checks":checks,"failures":failed,"rows":rows,"legacy":gun.legacy_aim}))
	quit(0 if failed.is_empty() else 1)
