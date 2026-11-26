extends SceneTree
## 0.47: the owner's report: "at the entrance of the office of the convenience this place kills all players".
## Plays the mart to the office stage, then walks the host (and the squad AI) through Jonna's door and into the
## office, logging everyone's health, the stage and anything that hurts. Nobody may lose health and the mission may
## not fail. `-- --shots=<dir>` saves frames.
var game
var session
var failed := []
var checks := 0
var shots := ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("OFFICE CHECK ",label," ",ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func shot(name: String) -> void:
	if shots=="": return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_jpg(shots.path_join(name+".jpg"),.9)
	print("OFFICE SHOT ",shots.path_join(name+".jpg"))

func log_state(m, tag: String) -> void:
	var p: InteriorPlayer = game.player
	var hp := []
	for id in session.team: hp.append([id,int(session.team[id].hp)])
	var solo = game.get("zombies")
	print("OFFICE %s stage %d pos %s team %s solo_hp %s down %s enemies %d" % [tag,m.stage,(p.global_position-m.Street.ORIGIN).snapped(Vector3.ONE*.01),hp,
		str(solo.health) if solo!=null else "-",str(solo.get("_down")) if solo!=null else "-",m.enemies.size()])

## Walks the player toward a street-local point with the real movement keys.
func walk_to(m, local: Vector3, limit: float) -> void:
	var p: InteriorPlayer = game.player
	var end := Time.get_ticks_msec()+int(limit*1000.0)
	var last := -1.0
	while Time.get_ticks_msec()<end:
		var to: Vector3 = m.Street.ORIGIN+local-p.global_position
		to.y = 0.0
		if to.length()<.3: break
		p.rotation.y = atan2(-to.x,-to.z)
		Input.action_press("forward")
		await physics_frame
		var t := Time.get_ticks_msec()/250
		if t!=last:
			last = t
			log_state(m,"walk")
	Input.action_release("forward")

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="): shots = a.trim_prefix("--shots=")
	if shots!="": DirAccess.make_dir_recursive_absolute(shots)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.harmless = false
	session.add_bot()
	session.start_game()
	await frames(20)
	var m = session.mission
	m.debug_skip()
	m.debug_skip()
	m.debug_skip()
	m.debug_skip()
	m.wave_left = 0
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	var store: Vector3 = m.Street.ORIGIN+m.Street.STORE
	var p: InteriorPlayer = game.player
	p.reset_motion(m.ground(store+Vector3(0,0,1.0)))
	session.team[1].pos = p.global_position
	for i in 200:
		await physics_frame
		if m.stage==5: break
	log_state(m,"in-mart")
	m.debug_skip()  # 5 -> 6 (the last wave killed)
	for i in 200:
		await physics_frame
		if m.stage==6: break
	m.debug_skip()  # 6: the office door opens
	await frames(30)
	log_state(m,"office-open")
	check(m.stage==6,"office stage (%d)" % m.stage)
	var before := {}
	for id in session.team: before[id] = int(session.team[id].hp)
	# In through the mart to the partition, then through the doorway into the office, then round it.
	var door: Vector3 = m.BackOffice.DOORWAY
	await walk_to(m,door+Vector3(0,0,-2.5),8.0)
	await shot("01-at-the-office-door")
	await walk_to(m,door+Vector3(0,0,-.6),5.0)
	await walk_to(m,door+Vector3(0,0,.6),5.0)
	await shot("02-in-the-doorway")
	await walk_to(m,door+Vector3(0,0,1.8),5.0)
	await walk_to(m,door+Vector3(-1.4,0,2.3),5.0)
	await walk_to(m,door+Vector3(2.0,0,2.3),5.0)
	await walk_to(m,door+Vector3(0,0,-1.5),6.0)
	# 0.47: the owner meant the doorway on the right inside the mart: the stockroom (EXIT sign) to the back door.
	var exit := Vector3(-2.975,0,69.5)
	await walk_to(m,exit+Vector3(0,0,-2.5),8.0)
	await shot("03-at-the-stockroom-door")
	await walk_to(m,exit+Vector3(0,0,-.5),5.0)
	await walk_to(m,exit+Vector3(0,0,.8),5.0)
	await shot("04-in-the-stockroom-door")
	await walk_to(m,exit+Vector3(-2.0,0,2.0),5.0)
	await walk_to(m,m.Street.BACK_DOOR+Vector3(0,0,-.8),5.0)
	await walk_to(m,exit+Vector3(-4.5,0,1.2),5.0)
	await walk_to(m,exit+Vector3(0,0,-2.0),8.0)
	for i in 20:
		await frames(15)
		log_state(m,"wait")
	var lost := []
	for id in session.team:
		if int(session.team[id].hp)<int(before.get(id,200)): lost.append([id,before.get(id),int(session.team[id].hp)])
	check(lost.is_empty(),"nobody hurt going through the office door %s" % [lost])
	check(m.stage<m.OVER,"the mission goes on (stage %d)" % m.stage)
	var solo = game.get("zombies")
	check(solo==null or float(solo.health)>=99.0,"the solo health untouched (%s)" % (str(solo.health) if solo!=null else "-"))
	print("OFFICE RESULT %d/%d %s" % [checks-failed.size(),checks,failed])
	quit(0 if failed.is_empty() else 1)
