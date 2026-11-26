extends SceneTree
## 0.41: Store Road and Mabini Mart. Walks over the old floodwall, then checks what the infected do with the tables
## (shove, climb, two deep), a dragged table, the stockroom's back door giving way, parts coming off the living and the
## dead, the unaware noticing a beam (and not a dark, still survivor), the hint line; then photographs the way to the
## store and its inside. `-- --only-photos` skips the checks; `-- --no-photos` the photographs.
var main
var session
var player: InteriorPlayer
var m
var misses := []
var notes := {}
var args := OS.get_cmdline_user_args()
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func photo(label: String, at: Vector3, aim: Vector3) -> void:
	if DisplayServer.get_name()=="headless" or "--no-photos" in args: return
	var o: Vector3 = m.Street.ORIGIN
	player.reset_motion(o+at)
	player.look_at(Vector3(o.x+aim.x,o.y+at.y,o.z+aim.z))
	player.camera.look_at(o+aim)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(ProjectSettings.globalize_path("res://../tmp/coop_"+label+".jpg"),.91)
func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	session = main.coop
	session.host()
	session.start_game()
	player = main.player
	m = session.mission
	session.set_physics_process(false)
	session.set_process(false)
	m.flags.gate = true
	m.street.sync(m.flags)
	main.story.gun.holster(true)
	var origin: Vector3 = m.Street.ORIGIN
	await frames(8)
	if not "--only-photos" in args: await checks(origin)
	main.hud.hide()
	for i in m.street.tables.size():
		var spec: Array = m.Street.TABLE_SPECS[i]
		m.street.tables[i].freeze = false
		m.street.tables[i].global_position = origin+(spec[1] as Vector3)+Vector3.UP*.06
		m.street.tables[i].rotation = Vector3(0,spec[2],0)
	m.flags.erase("backdoor")
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	if "--store" in args:
		await frames(120)
		await store_photos()
		print("INTERIOR_COOP_STREET ",JSON.stringify({"passed":misses.is_empty(),"failures":misses,"notes":notes}))
		quit(0)
		return
	await photo("aerial",Vector3(0,16,4),Vector3(0,0,40))
	await photo("lane",Vector3(-.4,.15,2.6),Vector3(.6,1.9,16))
	await photo("lane_mid",Vector3(1.5,.15,11.0),Vector3(-1.0,1.4,20))
	await photo("road",Vector3(.6,.15,18.4),Vector3(-.3,1.6,40))
	await photo("jeepney",Vector3(2.6,.15,23.6),Vector3(-1.2,1.0,31))
	await photo("side_alley",Vector3(4.2,.15,31.6),Vector3(10,1.4,31.6))
	await photo("checkpoint",Vector3(.3,.15,42.8),Vector3(0,1.2,52))
	await photo("front",Vector3(1,.15,47),Vector3(0,2.5,59))
	await photo("forecourt",Vector3(-6.5,.15,50.5),Vector3(2,1.0,55))
	await photo("inside",Vector3(.2,.15,57.4),Vector3(0,1.6,70))
	await photo("aisles",Vector3(-3.5,.15,59.4),Vector3(-3.4,1.3,69))
	await photo("counter",Vector3(-1.5,.15,58.8),Vector3(6,1.1,63.5))
	await photo("window_bar",Vector3(-3.4,.15,61.2),Vector3(-6.5,1.2,56.8))
	await photo("stockroom",Vector3(-2.8,.15,68.3),Vector3(-6,1.3,73))
	await store_photos()
	print("INTERIOR_COOP_STREET ",JSON.stringify({"passed":misses.is_empty(),"failures":misses,"notes":notes}))
	quit(0 if misses.is_empty() else 1)

## 0.42: Olivar Family Mart close up: the stock, the mess, the dead.
func store_photos() -> void:
	var dead := []
	for v in m.victims:
		var w: Vector3 = v.where()-m.Street.ORIGIN
		dead.append("%.1f,%.2f,%.1f"%[w.x,w.y,w.z])
	notes["dead"] = dead
	await photo("store_door",Vector3(.4,.15,56.9),Vector3(-.5,1.0,64))
	await photo("store_fridges",Vector3(.6,.15,64.2),Vector3(1.0,1.0,69.5))
	await photo("store_cashier",Vector3(4.8,.15,57.0),Vector3(5.2,.2,59.8))
	await photo("store_counter",Vector3(1.6,.15,62.2),Vector3(4.0,.6,59.4))
	await photo("store_pantry",Vector3(-6.4,.15,59.6),Vector3(-6.2,.8,67))
	await photo("store_snacks",Vector3(-3.4,.15,59.6),Vector3(-3.6,.6,66))
	await photo("store_household",Vector3(3.2,.15,62.4),Vector3(2.4,.9,67.5))
	await photo("store_freezer",Vector3(-4.3,.15,62.6),Vector3(-7.6,.5,65.4))
	await photo("store_wall",Vector3(-6.0,.15,62.0),Vector3(-8.2,1.0,60.6))
	await photo("store_staff",Vector3(3.2,.15,66.6),Vector3(4.4,.4,69.8))
	await photo("store_name",Vector3(0,.15,49.5),Vector3(0,3.6,56.4))

func checks(origin: Vector3) -> void:
	# 0.44: up the barangay ramp along the floodwall (approach.gd): from its foot, west, to the landing, then
	# north through the open gate.
	player.reset_motion(origin+Vector3(12.0,-3.05,-1.75))
	await frames(12)
	player.rotation.y = PI*.5
	player.touch_move = Vector2(0,-1)
	player.touch_sprinting = true
	await frames(170)
	player.rotation.y = PI
	await frames(120)
	player.touch_move = Vector2.ZERO
	notes.floodwall = player.position-origin
	if player.position.z<origin.z+2: misses.append("ramp")
	# A plain chase up the road.
	var z = m.make_enemy(721,0,m.ground(origin+Vector3(0,0,20)))
	var start: Vector3 = z.position
	for i in 150:
		await physics_frame
		z.chase(1.0/60,origin+Vector3(0,0,27),m.nav,false,[])
	notes.chase = z.position.distance_to(start)
	if z.position.distance_to(start)<2: misses.append("chase")
	var p: Dictionary = session.team[1]
	var eye: Vector3 = z.position+Vector3(0,1.56,-2.8)
	p.pos = eye-Vector3.UP*1.56
	m.shot(1,eye,Vector3.BACK,false)
	if p.kills!=1: misses.append("shot")
	# One table in the open: it gets over it (or shoves it out of the way).
	var t: RigidBody3D = m.street.tables[0]
	t.global_position = origin+Vector3(0,.06,44.5)
	t.rotation = Vector3.ZERO
	# Braced (as it is in a doorway): it cannot be shoved, so it has to be climbed.
	t.freeze = true
	await frames(30)
	var climber = m.make_enemy(722,1,m.ground(origin+Vector3(0,0,43.1)))
	climber.nerve = 1.0
	climber.sway = 0.0
	var vaulted := false
	for i in 360:
		await physics_frame
		climber.chase(1.0/60,origin+Vector3(0,0,48),m.nav,false,[])
		if climber.vault_time>=0: vaulted = true
	notes.climbed = vaulted
	notes.climber_z = climber.position.z-origin.z
	if climber.position.z<t.global_position.z+.5 or not vaulted: misses.append("over_table")
	t.freeze = false
	# Two tables, one behind the other: it cannot land, so it shoves them.
	var t2: RigidBody3D = m.street.tables[1]
	t.global_position = origin+Vector3(0,.06,44.5)
	t.rotation = Vector3.ZERO
	t2.global_position = origin+Vector3(0,.06,45.35)
	t2.rotation = Vector3.ZERO
	await frames(30)
	var pusher = m.make_enemy(723,2,m.ground(origin+Vector3(0,0,43.1)))
	pusher.nerve = 1.0
	pusher.sway = 0.0
	var second = m.make_enemy(724,3,m.ground(origin+Vector3(.7,0,43.0)))
	second.sway = 0.0
	var from := t.global_position
	var climbed := false
	for i in 420:
		await physics_frame
		pusher.chase(1.0/60,origin+Vector3(0,0,49),m.nav,false,[])
		second.chase(1.0/60,origin+Vector3(.7,0,49),m.nav,false,[])
		if pusher.vault_time>=0 or second.vault_time>=0: climbed = true
	notes.two_deep_shoved = t.global_position.distance_to(from)
	notes.two_deep_climbed = climbed
	if t.global_position.distance_to(from)<.25: misses.append("shove")
	for k in [722,723,724]:
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	# A table dragged by the host.
	m.stage = 4
	var drag: RigidBody3D = m.street.tables[2]
	p.pos = drag.global_position+Vector3(0,0,-1.2)
	p.yaw = 0.0
	p.hp = 200
	m.grab(1,2)
	var was := drag.global_position
	for i in 150:
		await physics_frame
		p.pos += Vector3(0,0,-1.2/60.0)
		m.drag_tick()
	notes.dragged = drag.global_position.distance_to(was)
	if drag.global_position.distance_to(was)<1.0: misses.append("drag")
	m.release(1)
	if int(p.drag)!=-1: misses.append("letgo")
	# The back door: hammered until it gives.
	var back = m.spawn(m.ground(origin+m.Street.BACK_DOOR+Vector3(0,0,.8)))
	back.back = true
	var hits := 0
	for i in 1800:
		await physics_frame
		m._hammer(back,1.0/60)
		m.street.sync(m.flags)
		if m.flags.get("backdoor",false):
			hits = int(m.flags.backhits)
			break
	notes.back_door_hits = hits
	if not m.flags.get("backdoor",false): misses.append("back_door")
	m.enemies.erase(back.key)
	back.queue_free()
	# Parts off the living (a head that comes apart) and the dead (an arm).
	m.stage = 4
	var victim = m.spawn(m.ground(origin+Vector3(0,0,30)))
	await frames(6)
	m.damage(1,victim.key,"head",victim.global_position+Vector3.UP*1.6,Vector3.FORWARD,30.0,60.0,140.0)
	await frames(30)
	notes.head_off = victim.severed.has("head")
	if not victim.dead or not victim.severed.has("head"): misses.append("head_off")
	m.tear(victim,"forearm.L",Vector3.LEFT,80.0,60.0)
	await frames(6)
	notes.corpse_arm_off = victim.severed.has("forearm.L")
	if not victim.severed.has("forearm.L"): misses.append("corpse_arm")
	var street_dead = m.victims[0]
	m.tear(street_dead,"shin.R",Vector3.RIGHT,80.0,90.0)
	if not street_dead.severed.has("shin.R"): misses.append("street_dead_tear")
	# Senses: a still, dark survivor ten metres off is not noticed; the beam on it is.
	var sleeper = m.spawn(m.ground(origin+Vector3(2.5,0,36)),true)
	sleeper.idle_mode = "wander"
	sleeper.wander_wait = 99.0
	sleeper.rotation.y = 0.0
	p.pos = m.ground(origin+Vector3(2.5,0,26))
	p.light = false
	m.moving.clear()
	for i in 90:
		await physics_frame
		m.sense(1.0/60)
	notes.dark_unnoticed = sleeper.asleep
	if not sleeper.asleep: misses.append("noticed_in_dark")
	p.light = true
	p.yaw = PI
	p.pitch = 0.0
	for i in 60:
		await physics_frame
		m.sense(1.0/60)
	notes.beam_noticed = not sleeper.asleep
	if sleeper.asleep: misses.append("beam_unnoticed")
	p.light = false
	# A gunshot wakes the street.
	var other = m.spawn(m.ground(origin+Vector3(-2,0,40)),true)
	p.shot_at = 0
	m.fired(1)
	for i in 120:
		await physics_frame
		m.sense(1.0/60)
	notes.shot_woke = not other.asleep
	if other.asleep: misses.append("shot_unheard")
	# The hint line.
	session.hint_wait = 0.0
	session._hints(.1)
	notes.hint = session.hint_label.text
	if session.hint_label.text=="": misses.append("hint")
	m.stage = 0
