extends SceneTree
## 0.40: co-op infected take real rounds on their own hit boxes, are pushed back, and fall as ragdolls (checked on
## the DRAWN skeleton, not only the physics bodies: see docs/v38); the host keeps the debug menu; the squad AI
## joins, fights, talks; the voice menu opens on ~.
var game
var session
var failed := []
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("SQUAD CHECK ",label," ",ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

## Where the head is DRAWN: the skeleton's pose after its modifiers (the ragdoll), read while it is updated.
func drawn_head(z) -> Vector3:
	var sk: Skeleton3D = z.skeleton
	if sk.modifier_callback_mode_process==Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE:
		await sk.skeleton_updated
	var id := sk.find_bone("head")
	return sk.global_transform*sk.get_bone_global_pose(id).origin

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	check(session.add_bot() and session.add_bot(),"host adds two AI squadmates in the lobby")
	check(session.team.size()==3 and session.humans()==1,"team of one player and two AI")
	session.start_game()
	await frames(10)
	var m = session.mission
	check(session.active and m!=null,"mission starts with AI")
	check(session.bots!=null and session.bots.bots.size()==2,"AI bodies on the host")
	var debug: Node = game.get_node_or_null("DebugMenu")
	check(debug!=null and debug.process_mode!=Node.PROCESS_MODE_DISABLED and debug.can_open(),"host keeps the Q W E R T Y menu")
	# Somewhere open on the far bank, out of the way of the story.
	m.debug_skip()
	m.debug_skip()
	m.debug_skip()
	m.debug_skip()                      # stage 4: the store run
	m.wave_left = 0
	m.harmless = true
	var stand: Vector3 = m.ground(m.Street.ORIGIN+Vector3(0,0,20))
	check(stand.is_finite(),"street floor")
	var player: InteriorPlayer = game.player
	player.reset_motion(stand)
	session.team[1].pos = stand
	await frames(5)
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	# One infected 6 m up the street, facing us.
	var at: Vector3 = m.ground(stand+Vector3(0,0,6))
	m.spawn(at)
	var key: int = m.next_id
	var z = m.enemies[key]
	z.asleep = true
	z.rotation.y = 0.0
	check(z.bodies.size()==InteriorZombie.BODIES.size(),"co-op infected carry the full solo ragdoll (%d bodies)"%z.bodies.size())
	await frames(12)
	var gun: InteriorGun = game.story.gun
	gun.instant_hits = true
	# 0.41: the squad holds its fire while the player's own rounds are measured (they would finish it first).
	var kept := {}
	for id in session.bots.bots:
		var b = session.bots.bots[id]
		kept[id] = [b.mag,b.reserve]
		b.mag = 0
		b.reserve = 0
	var blood_before: int = session.blood().count()
	var start: Vector3 = z.global_position
	var eye: Vector3 = stand+Vector3.UP*1.5
	var chest: Vector3 = (z.bodies["chest"] as Node3D).global_position
	gun._fire_round(eye,(chest-eye).normalized(),InteriorGun.PROFILES.pistol,0)
	await frames(1)
	check(z.hp<90.0 and z.hp>0.0,"a pistol round to the chest hurts (hp %.0f)"%z.hp)
	check(z.shove.length()>.3,"the round shoves it back (%.2f m/s)"%z.shove.length())
	check(session.blood().count()>blood_before,"blood flies from the wound")
	z.asleep = false
	await frames(20)
	var pushed: float = (z.global_position-start).dot((start-stand).normalized())
	check(pushed>.05,"it was driven back along the shot (%.2f m)"%pushed)
	# The shotgun close up puts it down for good: a ragdoll that falls the way the shot went.
	await frames(30)
	z = m.enemies.get(key)
	var standing_head: Vector3 = await drawn_head(z)
	var at_death: Vector3 = z.global_position
	eye = z.global_position-Vector3(0,0,2.5)+Vector3.UP*1.4
	chest = (z.bodies["chest"] as Node3D).global_position
	var way: Vector3 = (chest-eye).normalized()
	for i in 9: gun._fire_round(eye,(way+Vector3(randf_range(-.02,.02),randf_range(-.02,.02),0)).normalized(),InteriorGun.PROFILES.shotgun,i)
	await frames(2)
	check(not m.enemies.has(key),"buckshot kills it")
	check(z.dead and z.sim.is_simulating_physics(),"its bodies take over as a ragdoll")
	await frames(150)
	var lying_head: Vector3 = await drawn_head(z)
	check(standing_head.y-lying_head.y>.75,"the drawn body lies on the ground (head %.2f m lower)"%(standing_head.y-lying_head.y))
	var drawn_hips: Vector3 = z.skeleton.global_transform*z.skeleton.get_bone_global_pose(z.skeleton.find_bone("hips")).origin
	check(drawn_hips.distance_to((z.bodies["hips"] as Node3D).global_position)<.3,"the drawn hips are where the ragdoll's are")
	var hips: Vector3 = (z.bodies["hips"] as Node3D).global_position
	check((hips-at_death).dot(Vector3(way.x,0,way.z).normalized())>.15,"it went over away from the gun (%.2f m)"%(hips-at_death).dot(Vector3(way.x,0,way.z).normalized()))
	check(m.corpses.has(z),"the body is kept")
	await frames(300)
	var hips_now: Vector3 = (z.bodies["hips"] as Node3D).global_position
	check(z.sim.is_simulating_physics() and z.bodies["hips"].collision_layer==InteriorZombie.HITBOX,"seconds later it is still a live ragdoll that rounds can hit")
	gun._fire_round(hips_now+Vector3(0,.6,-1.5),(hips_now-(hips_now+Vector3(0,.6,-1.5))).normalized(),InteriorGun.PROFILES.shotgun,0)
	await frames(10)
	check((z.bodies["hips"] as Node3D).global_position.distance_to(hips_now)>.01 or (z.bodies["chest"] as Node3D).global_position.distance_to(hips_now)>.0,"a round into the body moves it")
	# The squad AI fights: a crowd comes up the street.
	for id in kept:
		session.bots.bots[id].mag = kept[id][0]
		session.bots.bots[id].reserve = kept[id][1]
	for id in session.bots.bots: session.bots.bots[id].body.global_position = stand+Vector3(randf_range(-1,1),.1,-1.5)
	var made := 0
	for i in 5:
		if m.spawn(m.ground(stand+Vector3(randf_range(-2,2),0,12+i*1.5))): made += 1
	var kills_before := 0
	var shots_before := 0
	for id in session.team:
		if session.is_bot(id):
			kills_before += int(session.team[id].kills)
			shots_before += int(session.team[id].shots)
	# Up to 30 s of play for the first kills (they reload, give ground and pick their moments).
	for wait in 60:
		await frames(30)
		var so_far := 0
		for id in session.team:
			if session.is_bot(id): so_far += int(session.team[id].kills)
		if so_far>=kills_before+2: break
	var kills := 0
	var shots := 0
	var lines := 0
	for id in session.team:
		if session.is_bot(id):
			kills += int(session.team[id].kills)
			shots += int(session.team[id].shots)
	check(shots>shots_before,"the AI shoots (%d)"%(shots-shots_before))
	check(kills>kills_before,"the AI kills (%d of %d)"%[kills-kills_before,made])
	check(session.voices.feed.get_child_count()>0,"the squad talks (radio feed)")
	check(session.voices.stream("Louie","reloading",0)!=null,"voice clips load")
	# Orders.
	session.player_line("hold")
	await frames(3)
	var held := true
	for b in session.bots.bots.values(): held = held and b.order=="hold"
	check(held,"AI take the hold order")
	# The voice menu.
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_QUOTELEFT
	ev.pressed = true
	session.voices._input(ev)
	check(session.voices.open and session.voices.panel.visible,"~ opens the voice menu")
	session.voices._input(ev)
	check(not session.voices.open,"~ closes it")
	# Removing one during play.
	session.remove_bot()
	await frames(4)
	check(session.team.size()==2 and session.bots.bots.size()==1,"host removes an AI during play")
	report()

func report() -> void:
	print("INTERIOR_SQUAD ",JSON.stringify({"passed":failed.is_empty(),"checks":checks,"failures":failed}))
	if is_instance_valid(session) and session.peer!=null: session.end_session()
	quit(0 if failed.is_empty() else 1)
