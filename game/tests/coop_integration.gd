extends SceneTree
## Run normally for mission checks. Pass -- --peer or --network-host for the loopback session.
var game
var session
var failed := []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("COOP CHECK ",label," ",ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	session = game.coop
	session.page()
	check(game.current_menu=="multiplayer","menu opens lobby")
	if "--peer" in OS.get_cmdline_user_args():
		session.address = "127.0.0.1"
		session.join_game()
		var limit := Time.get_ticks_msec()+85000
		while not session.active and Time.get_ticks_msec()<limit: await process_frame
		check(session.active,"client entered mission")
		if session.active:
			game.story.flashlight.set_on(true)
			while not session.last_results and Time.get_ticks_msec()<limit: await process_frame
			check(session.last_results,"replicated results")
			check(session.team.size()>=2 and session.avatars.size()>=1,"remote survivor exists")
		await create_timer(.8,true).timeout
		report()
		return
	session.host()
	if "--network-host" in OS.get_cmdline_user_args():
		var limit := Time.get_ticks_msec()+85000
		var expected := 5 if "--five" in OS.get_cmdline_user_args() else 2
		while session.team.size()<expected and Time.get_ticks_msec()<limit: await process_frame
		check(session.team.size()==expected,"all peers joined")
	session.start_game()
	await frames(8)
	if "--network-host" in OS.get_cmdline_user_args():
		var until := Time.get_ticks_msec()+30000
		while session.network_ready.size()<session.team.size() and Time.get_ticks_msec()<until: await process_frame
		check(session.network_ready.size()==session.team.size(),"all peers ready")
		await frames(45)
		var names := {}
		var lights := 0
		# 0.44: both processes run uncapped; give the client's first pose (its flashlight) up to 5 s to arrive.
		var light_until := Time.get_ticks_msec()+5000
		while Time.get_ticks_msec()<light_until:
			lights = 0
			for peer_id: int in session.team:
				if session.team[peer_id].light: lights += 1
			if lights==session.team.size()-1: break
			await process_frame
		for peer_id: int in session.team:
			names[session.team[peer_id].slot] = true
		check(names.size()==session.team.size(),"unique survivor per peer")
		check(lights==session.team.size()-1,"client flashlight state received")
	var m = session.mission
	check(m!=null and not game.has_node("Stranger"),"co-op starts without stranger")
	check(game.story.flashlight.owned and game.story.gun.owned,"starting equipment")
	for i in 5:
		check(ResourceLoader.exists("res://assets/characters/survivors/"+session.NAMES[i].to_lower()+".glb"),session.NAMES[i])
	var id := 1
	var p: Dictionary = session.team[id]
	var start: Vector3 = p.pos
	p.pos = m.guide.position
	m.interact(id,"talk")
	check(m.stage==1,"escort begins")
	# (0.66: from the courtyard gate now, ~260 m at his pace.)
	for i in 4000:
		if m.stage!=1: break
		p.pos = m.guide.position
		m.escort(.1)
	check(m.stage==2,"escort reaches altar")
	p.pos = m.street.key.global_position
	m.interact(id,"keys")
	check(m.stage==3 and m.flags.keys,"altar key acquired")
	p.pos = m.street.ORIGIN+m.street.GATE
	m.interact(id,"gate")
	check(m.wave_left==10 and m.flags.gate,"pursuit starts")
	m.nav.space = m.get_world_3d().direct_space_state
	var floor_test: Vector3 = m.ground(m.street.ORIGIN+Vector3(0,0,15))
	check(floor_test.is_finite(),"street has floor")
	check(m.spawn_near(p),"director finds a legal position")
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	p.pos = m.street.rifles[2].global_position
	var rifle: String = m.candidate(id)
	m.interact(id,rifle)
	check(p.rifle and game.story.gun.rifle_owned,"rifle claimed")
	p.pos = m.street.tables[0].global_position
	m.interact(id,"table0")
	check(int(p.drag)==0,"table taken in hand")
	m.interact(id,"letgo")
	check(int(p.drag)==-1,"table let go")
	p.hp = 18
	# 0.46: a healthkit is a three-second patch-up (0.58: 80-120 of 200).
	m.heal(id)
	for i in 40: m.heal_tick(.1)
	check(p.hp>=98 and p.hp<=138 and p.kits==0,"healthkit heals once (%d)" % p.hp)
	var chase_kills := clear_wave(m,p,m.street.ORIGIN+Vector3(0,0,17))
	check(chase_kills>=10 and m.wave_left==0,"ten pursuit enemies spawned and killed")
	for who in session.team: session.team[who].pos = m.street.ORIGIN+m.street.STORE
	m.tick(.016)
	check(m.stage==5 and m.wave_total>=15,"store starts final wave")
	var final_kills := clear_wave(m,p,m.street.ORIGIN+m.street.STORE)
	check(final_kills>=m.wave_total,"entire final wave spawned and killed")
	m.tick(.016)
	await frames(20)
	check(m.stage==6 and p.hp==200 and not m.flags.gate and not session.last_results,"healed team, gate closed, mission goes on")
	# 0.44: Jonna opens the office, talks, gives the service gate key; the backstreets to the school.
	for i in 60: m.tick(.1)
	check(m.flags.get("office",false) and m.jonna.visible,"Jonna opens the office door")
	p.pos = m.jonna.position+Vector3(0,0,-1.5)
	check(m.candidate(id)=="jonna","Jonna can be spoken to")
	m.interact(id,"jonna")
	check(m.stage==7,"conversation starts")
	var lines := {}
	for i in 900:
		if m.stage!=7: break
		m.tick(.1)
		if m.text_line!="": lines[m.text_line] = true
		if i%30==29 and m.candidate(id)=="listen": m.interact(id,"listen")
		# 0.49: after the talk she shuts the front; the chapter board waits for READY.
		if m.flags.get("board",false):
			for who: int in session.team: session.team[who].next_ready = true
			if m.board_all_ready(): m._board_done()
	check(m.stage==8 and lines.size()>=m.TALK.size(),"Jonna says it all (%d lines)"%lines.size())
	check(m.jonna.anim_name=="sit_hurt","Jonna sat down against the wall")
	m.flush_later()   # (0.66: made a few a tick in play.)
	check(m.enemies.size()>=8,"infected wait in the backstreets (%d)"%m.enemies.size())
	p.pos = m.street.ORIGIN+m.street.BACK_DOOR+Vector3(0,0,-1.0)
	m.interact(id,m.candidate(id))
	m.street.sync(m.flags)
	check(m.flags.get("backdoor_open",false) and m.street.back_door.collision_layer==0,"back door opened")
	p.pos = m.street.ORIGIN+m.street.ALLEY_GATE+Vector3(0,0,-1.5)
	m.interact(id,m.candidate(id))
	for i in 120: m.street.sync(m.flags)
	check(m.flags.get("alley",false) and absf(m.street.alley_gate.position.x-m.street.ALLEY_GATE.x)>2.5,"service gate unlocked and slid aside")
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	# 0.50: the college: its story near the back gate, Rommel, the gate, room 501 on the fifth floor.
	for who in session.team: session.team[who].pos = m.street.ORIGIN+Vector3(28,0,472)
	m.wave_left = 0
	for i in 600:
		if m.stage!=8: break
		m.tick(.1)
		if i%10==9 and m.candidate(id)=="story": m.interact(id,"story")
	check(m.stage==9 and m.school!=null,"the college's story is told near its back gate")
	for who in session.team: session.team[who].pos = m.street.ORIGIN+m.SCHOOL.GATE+Vector3(.6,0,-1.6)
	check(m.candidate(id)=="guard","the guard behind the gate can be spoken to")
	m.interact(id,"guard")
	for i in 900:
		if m.stage!=9: break
		m.tick(.1)
		if i%30==29 and m.candidate(id)=="listen": m.interact(id,"listen")
	check(m.stage==10 and m.flags.get("school_gate",false),"Rommel talks, then opens the school gate")
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	for who in session.team: session.team[who].pos = m.street.ORIGIN+m.SCHOOL.DOOR_501+Vector3(0,0,.9)
	m.interact(id,"survivors")
	await frames(20)
	check(m.stage==11 and m.escape.people.size()==5,"room 501 opens: Ma'am Teves and four students (stage %d)" % m.stage)
	# 0.52: out again: the horde, the fire exit, the blast, the field, the rear gate (tests/coop_escape.gd plays them).
	for i in 8:
		if m.flags.get("board",false): break
		m.debug_complete()
		await frames(4)
	check(m.flags.get("board",false) and m.flags.get("pilcst_out",false),"out of the rear gate: the chapter's board")
	for who in session.team: session.team[who].next_ready = true
	for i in 10:
		m.tick(.1)
		await frames(2)
	await frames(20)
	check(m.stage==16 and m.outer_street!=null and not bool(m.flags.get("board",false)),"everyone ready: entered Outer Street (stage %d)" % m.stage)
	m.debug_complete()
	m.debug_complete()
	await frames(10)
	check(m.stage==m.WON and session.last_results,"Outer Street complete -> final campaign results")
	check(start.distance_to(Vector3.ZERO)<6,"starts inside house")
	if "--network-host" in OS.get_cmdline_user_args(): await create_timer(2,true).timeout
	report()

func clear_wave(m, p: Dictionary, at: Vector3) -> int:
	var before := int(p.kills)
	var peak := 0
	for i in 600:
		p.pos = at
		if m.wave_left==0 and m.back_left==0 and m.enemies.is_empty(): break
		m.tick(.12)
		peak = maxi(peak,m.enemies.size())
		for k in m.enemies.keys():
			var target = m.enemies[k]
			# Exercise the standard shot and kill path with a clear, close head shot.
			var eye: Vector3 = target.position+Vector3(0,1.78,0)
			p.pos = target.position
			p.shot_at = 0
			m.shot(1,eye,Vector3.DOWN,false)
	p.pos = at
	check(peak<=maxi(8,5*session.team.size())+12,"director respects per-player cap")
	return int(p.kills)-before

func report() -> void:
	print("INTERIOR_COOP ",JSON.stringify({"passed":failed.is_empty(),"checks":checks,"failures":failed}))
	if is_instance_valid(session) and session.peer!=null: session.end_session()
	quit(0 if failed.is_empty() else 1)

