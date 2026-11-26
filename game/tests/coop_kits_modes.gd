extends SceneTree
## 0.46: game modes (start loadouts), healthkits (held F on yourself, held E on a teammate who is held still, 40-70
## HP, three at most), G held drops the weapon with its rounds, grenades lying in the mart, the debug invulnerability
## covering blasts, and the world behind the team put away once they are in the backstreets.
## `-- --shots=<dir>` saves review frames.
var game
var session
var failed := []
var checks := 0
var shots := ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("KITS CHECK ",label," ",ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

## (0.66: game time, in physics ticks: with --fixed-fps the wall clock ran ahead of or behind the game by load.)
func seconds(t: float) -> void:
	for i in int(round(t*Engine.physics_ticks_per_second)): await physics_frame

func shot(name: String) -> void:
	if shots=="": return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_jpg(shots.path_join(name+".jpg"),.9)
	print("KITS SHOT ",shots.path_join(name+".jpg"))

func stand(m, at: Vector3, yaw: float) -> void:
	var player: InteriorPlayer = game.player
	player.reset_motion(at)
	player.rotation.y = yaw
	session.team[1].pos = at
	session.team[1].yaw = yaw

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
	session.set_mode("easy")
	session.add_bot()
	check(session.mode=="easy","host picks Easy in the room")
	session.start_game()
	await frames(20)
	var m = session.mission
	var gun: InteriorGun = game.story.gun
	var rifle_total: int = gun.loaded()+gun.reserve if gun.weapon=="rifle" else -1
	check(gun.rifle_owned and rifle_total==100,"Easy: rifle with 100 rounds (%d)" % rifle_total)
	check(gun.total()==60,"Easy: Glock with 60 rounds (%d)" % gun.total())
	check(int(game.grenades.count)==1,"Easy: one grenade (%d)" % int(game.grenades.count))
	check(int(session.team[1].kits)==1,"Easy: one healthkit")
	var bot_id: int = session.team.keys().filter(func(i): return i<0)[0]
	check(session.bots.bots[bot_id].gun.rifle,"Easy: the squad AI carry rifles too")
	session.harmless = true
	m.debug_skip()
	m.debug_skip()
	m.debug_skip()
	m.debug_skip()
	m.wave_left = 0
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	var store: Vector3 = m.Street.ORIGIN+m.Street.STORE
	var here: Vector3 = m.ground(store+Vector3(-2.5,0,-2.0))
	stand(m,here,PI)
	await frames(10)
	# --- F held: a healthkit on yourself.
	session.team[1].hp = 60
	session._send("heal")
	await seconds(1.2)
	check(int(session.team[1].hp)==60 and float(session.team[1].heal_t)>0.2,"F held: patching up, not done yet at 1.2 s")
	await seconds(2.2)
	var hp := int(session.team[1].hp)
	check(hp>=140 and hp<=180,"F held 3 s: +80..120 HP of 200 (60 -> %d)" % hp)
	check(int(session.team[1].kits)==0,"the healthkit is used up")
	session._send("heal_stop")
	# --- let go early: nothing used.
	session.team[1].kits = 1
	session.team[1].hp = 50
	session._send("heal")
	await seconds(1.0)
	session._send("heal_stop")
	await seconds(2.5)
	check(int(session.team[1].hp)==50 and int(session.team[1].kits)==1,"letting go of F early keeps the kit")
	# --- three healthkits at most.
	session.team[1].kits = 2
	for i in 2:
		m.drops[90000+i] = [here,"healthkit"]
		m.interact(1,m.candidate(1))
	check(int(session.team[1].kits)==3,"picked up to three healthkits")
	check(m.drops.has(90001),"a fourth stays on the ground")
	m.drops.clear()
	# --- E held on a teammate: they are held still and patched up.
	var b = session.bots.bots[bot_id]
	var beside: Vector3 = m.ground(here+Vector3(1.2,0,0))
	b.body.global_position = beside
	session.team[bot_id].pos = beside
	session.team[bot_id].hp = 50
	session.team[bot_id].kits = 0    # (or it patches itself up first)
	await frames(2)
	var action: String = m.candidate(1)
	check(action=="patch%d" % bot_id,"E on a hurt teammate offers the patch-up (%s)" % action)
	check(m.prompt_for(action).begins_with("Hold E"),"prompt says hold E")
	var kits_before := int(session.team[1].kits)
	m.interact(1,action)
	await seconds(1.0)
	check(bool(session.team[bot_id].held),"the teammate is held still while patched up")
	var moved: float = b.body.global_position.distance_to(beside)
	await seconds(2.3)
	check(int(session.team[bot_id].hp)>=130,"teammate patched up (50 -> %d)" % int(session.team[bot_id].hp))
	check(not bool(session.team[bot_id].held),"and free to move again")
	check(int(session.team[1].kits)==kits_before-1,"the healer's kit is used")
	check(moved<.35,"the teammate did not walk off mid patch-up (%.2f m)" % moved)
	# --- a downed teammate: held E brings them up.
	session.team[bot_id].hp = 0
	session.team[bot_id].pos = beside
	await frames(2)
	action = m.candidate(1)
	m.interact(1,action)
	await seconds(3.3)
	check(action.begins_with("revive") and int(session.team[bot_id].hp)>=80,"held E helps a downed teammate up with 80-120 (%d)" % int(session.team[bot_id].hp))
	# --- debug invulnerability covers grenade blasts.
	session.team[1].hp = 200
	session.blast_hurt(160)
	check(int(session.team[1].hp)==200,"invulnerable: a blast does nothing")
	session.harmless = false
	session.blast_hurt(160,false)
	check(int(session.team[1].hp)==155,"a teammate's frag takes at most 45 (%d)" % int(session.team[1].hp))
	session.blast_hurt(160,true)
	check(int(session.team[1].hp)==70,"your own close frag takes at most 85 of the 200 (%d)" % int(session.team[1].hp))
	session.team[1].hp = 200
	session.harmless = true
	# --- G held: the weapon goes down with its rounds, and comes back with them.
	gun.select("rifle")
	await seconds(1.0)
	var before: int = gun.loaded()+gun.reserve
	session._drop_weapon()
	await frames(4)
	check(not gun.rifle_owned,"G held: the rifle is out of the hands")
	var dk := -1
	for k in m.drops:
		# (0.48: the drop names the weapon, "weapon:ar15"; its kind is the rifle.)
		if str(m.drops[k][1]).begins_with("weapon:") and InteriorArsenal.class_of(str(m.drops[k][1]).trim_prefix("weapon:"))=="rifle": dk = k
	check(dk>=0,"the rifle lies on the ground")
	if dk>=0:
		var ammo: Array = m.drops[dk][2]
		check(int(ammo[0])+(1 if ammo[1] else 0)+int(ammo[2])==before,"with every round it had (%d)" % before)
		check(gun.weapon=="pistol" and gun.drawn,"the Glock comes up instead")
		await seconds(.6)
		m.render(.016)
		if shots!="":
			var player: InteriorPlayer = game.player
			player.camera.rotation.x = -.7
			await seconds(.3)
			await shot("01-dropped-rifle")
			player.camera.rotation.x = 0.0
		action = m.candidate(1)
		check(action=="drop%d" % dk and m.prompt_for(action).begins_with("E  •  Take"),"E offers it back (%s)" % m.prompt_for(action))
		m.interact(1,action)
		await seconds(1.2)
		check(gun.rifle_owned and gun.weapon=="rifle","picked it back up (%s, %s)" % [gun.rifle_owned,gun.weapon])
		var back: int = gun.loaded()+gun.reserve if gun.weapon=="rifle" else -1
		check(back==before,"the rounds came back with it (%d)" % back)
	# --- grenades lying in the mart.
	var nade: Vector3 = m.Street.ORIGIN+(m.GRENADE_SPOTS[0] as Vector3)
	stand(m,m.ground(nade+Vector3(-1.0,0,0)),-PI*.5)
	await frames(6)
	m.render(.016)
	if shots!="":
		game.player.camera.rotation.x = -.55
		await seconds(.3)
		await shot("02-grenades-in-mart")
		game.player.camera.rotation.x = 0.0
	var count := int(game.grenades.count)
	action = m.candidate(1)
	check(action=="nade0","E offers the grenades by the crates (%s)" % action)
	m.interact(1,action)
	await frames(3)
	check(int(game.grenades.count)==count+1,"one more frag grenade")
	if shots!="":
		stand(m,m.ground(store+Vector3(1.2,0,1.0)),PI)
		game.player.camera.rotation.x = -.18
		await seconds(.5)
		await shot("03-sandbags")
		game.player.camera.rotation.x = 0.0
	# --- the backstreets: the world behind them is put away.
	m.debug_skip()  # 5
	await frames(4)
	await seconds(.5)
	m.backstreets()
	await frames(4)
	m.flags.alley = true
	m.flags.backdoor_open = true
	var out: Vector3 = m.ground(m.Street.ORIGIN+Vector3(-1.5,0,96))
	stand(m,out,PI)
	for id in session.team:
		session.team[id].pos = out+Vector3(.5,0,0) if id!=1 else out
		if id<0: session.bots.bots[id].body.global_position = out+Vector3(.5,0,0)
	await frames(4)
	var t0 := Time.get_ticks_usec()
	m.render(.016)
	print("KITS cleanup took %.1f ms" % ((Time.get_ticks_usec()-t0)/1000.0))
	check(m.cleaned,"the world behind them is put away once everyone is out back")
	check(m.ground(m.Street.ORIGIN+Vector3(-2,0,128)).is_finite(),"the backstreets are still underfoot")
	await seconds(1.0)
	check(int(session.team[1].hp)>0 and m.stage==8,"still playing after the cleanup")
	if shots!="":
		await seconds(.5)
		await shot("04-backstreets-after-cleanup")
	print("KITS RESULT %d/%d %s" % [checks-failed.size(),checks,failed])
	quit(0 if failed.is_empty() else 1)
