extends SceneTree
## 0.46: the store last stand with the debug "infected cannot hurt the team" on: nobody may go down, the mission may
## not fail, and every health change is logged with the stage (this is how the "everyone dies in the mart" bug was
## found).
var game
var session
var failed := []
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("STORE CHECK ",label," ",ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.add_bot()
	session.add_bot()
	session.start_game()
	await frames(10)
	var m = session.mission
	# STORE_HARMLESS=0 runs it for real; STORE_STAND="x,z" (street-local) is where the host stands.
	m.harmless = OS.get_environment("STORE_HARMLESS")!="0"
	m.log_hits = true
	for i in 4: m.debug_skip()
	var store: Vector3 = m.Street.ORIGIN+m.Street.STORE
	var stand: Vector3 = m.ground(store+Vector3(0,0,-2))
	if OS.get_environment("STORE_STAND")!="":
		var xz := OS.get_environment("STORE_STAND").split(",")
		stand = m.ground(m.Street.ORIGIN+Vector3(float(xz[0]),0,float(xz[1])))
	if not stand.is_finite(): stand = store
	game.player.reset_motion(stand)
	session.team[1].pos = stand
	m.wave_left = 0
	var last := {}
	for id in session.team: last[id] = int(session.team[id].hp)
	var seconds := float(OS.get_environment("STORE_SECONDS")) if OS.get_environment("STORE_SECONDS")!="" else 150.0
	var t := 0.0
	var report := 0.0
	var low := 100
	while t<seconds:
		await physics_frame
		var dt := 1.0/Engine.physics_ticks_per_second
		t += dt
		report += dt
		for id in session.team:
			var hp := int(session.team[id].hp)
			low = mini(low,hp)
			if hp!=int(last.get(id,hp)):
				print("STORE HP t=%.1f stage=%d id=%d %d -> %d pos=%s" % [t,m.stage,id,last[id],hp,session.team[id].pos])
			last[id] = hp
		if report>=5.0:
			report = 0.0
			var hps := []
			for id in session.team: hps.append(int(session.team[id].hp))
			var where := []
			for z in m.enemies.values(): where.append([(z.position-m.Street.ORIGIN).snapped(Vector3.ONE*.1),z.back,snappedf(z.stalled,.1),z.asleep])
			print("STORE enemies ",where)
			print("STORE t=%.0f stage=%d enemies=%d wave=%d back=%d hp=%s player=%s" % [t,m.stage,m.enemies.size(),m.wave_left,m.back_left,hps,game.player.global_position])
		if m.stage>=m.OVER:
			print("STORE OVER t=%.1f stage=%d text=%s" % [t,m.stage,m.text_line])
			break
		if m.stage>=6: break
	# 0.47: the owner's "the entrance on the right kills all players": the infected outside the shut back door hit
	# the squad in the stockroom doorway through the wall, and never broke the door.
	var through: Array = m.hit_log.filter(func(h): return (h[1] and not h[2]) or float(h[3])>1.8)
	check(through.is_empty(),"no hits through the wall from outside the back door %s" % [through])
	if m.back_left==0 and seconds>=60.0: check(bool(m.flags.get("backdoor",false)),"the back door gives way to the crowd at it (hp %.0f)" % m.street.back_door_hp)
	if OS.get_environment("STORE_HARMLESS")!="0": check(m.stage<m.OVER,"mission did not end in the mart (stage %d)" % m.stage)
	if m.harmless: check(low>0,"nobody went down with the infected harmless (lowest hp %d)" % low)
	print("STORE RESULT %d/%d %s" % [checks-failed.size(),checks,failed])
	quit(0 if failed.is_empty() else 1)
