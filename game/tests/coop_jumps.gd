extends SceneTree
## 0.49: the debug missions (coop/mission.gd debug_complete / debug_jump / debug_command).
##   godot --headless --path game --script res://tests/coop_jumps.gd -- --walk     every jump in order, one game
##   godot --headless --path game --script res://tests/coop_jumps.gd -- --direct   straight to the mart front, then the commands
## 0.55: every checkpoint before a jump settled as play leaves it; the teleports.
##   ... -- --each[=place,place]   each place jumped to straight from the start, in a game of its own (all by default)
##   ... -- --go                   the teleports (`go`, `squad`), what is put away, the Missions tab's buttons
## Prints INTERIOR_COOP_JUMPS ok|FAIL.
var game
var session
var m
var failed := []
var checks := 0
const EACH := ["escort", "keys", "ramp", "storeroad", "mart", "siege", "office", "jonna", "board", "backdoor", "backstreets",
	"arcade", "brickalley", "school", "lobby", "floor2", "fireescape", "floor3", "floor4", "ladder", "duct", "floor5", "teves",
	"horde", "sneak", "firedoor", "blast", "room208", "field", "heavyarm", "heavykey", "reargate", "pilcstout"]

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("JUMPS CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func cmd(line: String) -> String:
	var reply: String = m.debug_command(1, line)
	print("JUMPS > %s  ->  %s" % [line, reply])
	return reply

func standing_near(spot: Vector3, reach := 2.5) -> bool:
	var p: Vector3 = game.player.global_position
	return Vector2(p.x - spot.x, p.z - spot.z).length() < reach and absf(p.y - spot.y) < 2.0

func here() -> String:
	return str((game.player.global_position - m.Street.ORIGIN).snapped(Vector3.ONE * .1))

func bot_id() -> int:
	for id: int in session.team:
		if session.is_bot(id): return id
	return 0

func open_game() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.add_bot()
	session.start_game()
	await frames(30)
	m = session.mission
	session.harmless = true

func close_game() -> void:
	var peer = session.peer
	var api: MultiplayerAPI = session.multiplayer
	game.queue_free()
	game = null
	for i in 4: await process_frame
	if peer != null: peer.close()
	api.multiplayer_peer = null
	for i in 2: await process_frame

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var each: Array = []
	for a in args:
		if a == "--each": each = EACH.duplicate()
		elif a.begins_with("--each="): each = Array(a.trim_prefix("--each=").split(",", false))
	if not each.is_empty():
		for place: String in each:
			await open_game()
			await check_place(place)
			await close_game()
		finish()
		return
	await open_game()
	if "--go" in args: await check_go()
	elif "--walk" in args: await walk()
	else: await direct()
	finish()

func finish() -> void:
	print("INTERIOR_COOP_JUMPS %s (%d checks) %s" % ["ok" if failed.is_empty() else "FAIL", checks, str(failed)])
	quit(0 if failed.is_empty() else 1)

func walk() -> void:
	var o: Vector3 = m.Street.ORIGIN
	for place: String in ["dodong", "escort", "keys", "ramp", "gate", "storeroad", "mart", "siege", "office", "jonna", "board",
			"backdoor", "backstreets", "arcade", "brickalley", "school", "lobby", "floor2", "fireescape", "floor3", "floor4",
			"ladder", "duct", "floor5", "teves", "horde", "sneak", "firedoor", "blast", "room208", "field", "heavyarm",
			"heavykey", "reargate"]:
		var want := int(m.JUMPS[place][0])
		cmd("jump " + place)
		await frames(20)
		var spot: Vector3 = (o + (m.JUMPS[place][1] as Vector3)) if m.JUMPS[place][1] is Vector3 else game.player.global_position
		var stage_ok: bool = m.stage == want
		if place == "board": stage_ok = m.stage == 7 and bool(m.flags.get("board", false))
		check(stage_ok, "%s: stage %d (wanted %d)" % [place, m.stage, want])
		check(standing_near(spot), "%s: the host is there (%s)" % [place, here()])
		check(game.player.global_position.y > o.y - 6.0, "%s: on the ground, not fallen through" % place)
		if place == "board":
			check(session.board_open, "board: it is on screen")
			await frames(90)
			session._board_ready()
			await frames(6)
			check(m.stage == 8, "board: READY moves the run on (stage %d)" % m.stage)
	check(m.flags.get("keys", false) and m.flags.get("unlocked", false) and m.flags.get("locked", false), "the run's flags are all set on the way (keys, gate unlocked, front locked)")
	check(session.chapters_loaded.has("backstreets"), "the mart's board loaded the next chapter (nothing to catch up)")
	# 0.52 -> 0.63: PILCST rear gate board transitions into Outer Street (stage 16 -> stage 17 -> WON 18).
	check(cmd("complete").contains("-> 15") and bool(m.flags.get("board", false)), "complete at the rear gate brings up the board (stage %d)" % m.stage)
	await frames(10)
	session._board_ready()
	await frames(35)
	check(m.stage == 16 and m.outer_street != null, "READY on PILCST board enters Outer Street (stage %d)" % m.stage)
	for o_place: String in ["outerstreet", "outerhillside", "outeroverpass", "outersubway", "outerembank", "outergate"]:
		var owant := int(m.JUMPS[o_place][0])
		cmd("jump " + o_place)
		await frames(16)
		check(m.stage == owant, "%s: stage %d (wanted %d)" % [o_place, m.stage, owant])
		var ospot: Vector3 = o + (m.JUMPS[o_place][1] as Vector3)
		check(standing_near(ospot), "%s: the host stands cleanly on destination (%s)" % [o_place, here()])
	cmd("complete")
	await frames(10)
	# 0.68: across the bridge the hospital (stage 18), then the flare wins the run.
	check(m.stage == m.HOSPITAL and m.hospital != null, "complete past the bridge goes on into the hospital (stage %d)" % m.stage)
	cmd("complete")
	await frames(20)
	check(m.stage == m.WON, "complete in the hospital: the flare, the run won (stage %d)" % m.stage)

func direct() -> void:
	var o: Vector3 = m.Street.ORIGIN
	check(cmd("jump mart").contains("Stage 4"), "jump mart from the very start")
	await frames(20)
	check(m.stage == 4 and m.flags.get("gate", false) and m.flags.get("keys", false), "stage 4, keys taken and the gate open")
	check(m.guide.position.distance_to(m.route[m.route.size() - 1]) < .5, "Dodong is home")
	check(standing_near(o + Vector3(0, 0, 51.5)), "the host stands in front of the mart (%s)" % here())
	check((session.team[bot_id()].pos as Vector3).distance_to(game.player.global_position) < 4.0, "the squad AI came too")
	check(cmd("where").begins_with("Stage 4"), "where")
	check(cmd("help").contains("jump") and cmd("help").contains("go <place>"), "help lists the commands")
	var listed := cmd("places")
	check(listed.contains("backstreets") and listed.contains("heavykey") and listed.contains("nicholsfoyer"), "places lists the jumps and the teleports")
	check(cmd("jump keys").contains("forward"), "jumping back is refused")
	check(cmd("jump nowhere").begins_with("Unknown place"), "an unknown place is named as such")
	check(cmd("spawn 3") == "3 infected" or m.enemies.size() >= 1, "spawn 3 (%d)" % m.enemies.size())
	cmd("kill")
	await frames(4)
	check(m.enemies.is_empty(), "kill puts them all down")
	check(cmd("god on").begins_with("Squad invulnerable") and session.harmless and game.get_node("DebugMenu").god, "god on (the menu's box follows)")
	var drops: int = m.drops.size()
	check(cmd("give shotgun").contains("Pump") and m.drops.size() == drops + 1, "give lays a weapon at your feet")
	check(cmd("give nothing").begins_with("No such weapon"), "give: an unknown weapon")
	cmd("kits 2")
	check(int(session.team[1].kits) == 2, "kits 2")
	check(cmd("tp 0 0 30").begins_with("Moved"), "tp")
	await frames(4)
	check(standing_near(o + Vector3(0, 0, 30)), "tp put the host there")
	check(cmd("complete").contains("-> 5"), "complete: everyone in the mart, the siege starts (stage %d)" % m.stage)
	check(cmd("complete").contains("-> 6"), "complete: the siege won (stage %d)" % m.stage)
	await frames(10)
	check(m.flags.get("office", false), "the office opens")
	check(bool(session.team[1].rifle) and game.story.gun.has_weapon("rifle"), "past the siege the host carries one of the mart's rifles")
	check(cmd("frobnicate").begins_with("Unknown command"), "an unknown command is named as such")
	# The menu itself: the Missions tab is there and its command line runs the same commands.
	var menu = game.get_node("DebugMenu")
	menu.show_menu()
	menu._console.text = "stage"
	menu._run_console()
	await frames(4)
	check(menu._console_out.text.begins_with("Stage 6"), "the menu's command line answers (%s)" % menu._console_out.text)
	menu.close()

## 0.55: one place, straight from the start of a new game: the stage, the spot, the squad, and everything a run that got
## there has behind it.
func check_place(place: String) -> void:
	var o: Vector3 = m.Street.ORIGIN
	var H: float = m.SCHOOL.H
	var spec: Array = m.JUMPS[place]
	var want := int(spec[0])
	var how: Dictionary = spec[4]
	var fresh := bool(how.get("fresh", false))
	var reply := cmd("jump " + place)
	var said: String = m.text_line
	check(reply.begins_with("Stage %d" % want), "%s: the jump goes (%s)" % [place, reply])
	await frames(20)
	var spot: Vector3 = (o + (spec[1] as Vector3)) if spec[1] is Vector3 else m._stage_spot(m.stage)
	check(m.stage == want, "%s: stage %d (wanted %d)" % [place, m.stage, want])
	check(standing_near(spot), "%s: the host is there (%s)" % [place, here()])
	var host: Vector3 = game.player.global_position
	for id: int in session.team:
		check(int(session.team[id].hp) == 200, "%s: %d on their feet (%d)" % [place, id, int(session.team[id].hp)])
		if not session.is_bot(id): continue
		var b: Vector3 = session.team[id].pos
		check(b.distance_to(host) < 6.0 and absf(b.y - host.y) < 1.6, "%s: the squad AI beside the host, same floor (%s)" % [place, str((b - o).snapped(Vector3.ONE * .1))])
	if not fresh and not bool(how.get("line", false)): check(said == "", "%s: nothing left on screen from before (%s)" % [place, said])
	var f: Dictionary = m.flags
	if want >= 2: check(m.guide.position.distance_to(m.route[m.route.size() - 1]) < .5 and m.waypoint == m.route.size(), "%s: Dodong home" % place)
	if want >= 3: check(f.get("keys", false), "%s: the keys taken" % place)
	if want >= 4: check(f.get("unlocked", false), "%s: the road gate unlocked" % place)
	if want >= 6:
		check(bool(session.team[1].rifle) and game.story.gun.has_weapon("rifle"), "%s: the host carries one of the mart's rifles" % place)
		check(bool(session.team[bot_id()].rifle), "%s: so does the squad AI" % place)
		check(f.get("rifle0", false) and f.get("rifle1", false), "%s: two gone from the rack" % place)
	if want >= 8:
		check(f.get("locked", false) and int(f.get("lockup", 0)) == 5 and f.get("alley_key", false), "%s: the front locked, the lockup over, the service gate's key given" % place)
		check(m.jonna.position.distance_to(o + m.BackOffice.SEAT) < .3 and m.jonna.anim_name == "sit_hurt", "%s: Jonna in her seat (%s)" % [place, m.jonna.anim_name])
	if want >= 9 or how.get("outback", false):
		check((f.get("backdoor_open", false) or f.get("backdoor", false)) and f.get("alley", false), "%s: out the back door and through the service gate" % place)
	if want == 8 and not how.get("outback", false):
		check(not f.get("alley", false) and not f.get("backdoor_open", false), "%s: the back door and the service gate still to open" % place)
	if want >= 9: check(int(f.get("story", -1)) == m.STORY.size(), "%s: the school's story told" % place)
	if want >= 10:
		check(f.get("school_gate", false) and f.get("school_shut", false), "%s: Rommel's gate opened and shut behind the squad" % place)
		var floors := int(how.get("floors", 5))
		for k in floors:
			check(f.get("floor%d" % k, false) and (int(f.get("quiet_floors", 0)) & (1 << k)) != 0, "%s: floor %d crossed (quietly)" % [place, k + 1])
		var bell = m.school._bell
		check(bell == null or not bell.playing or floors < 5, "%s: no bell for the floors behind" % place)
	if how.get("kuya", false):
		# (Feeding; at the duct the squad lands beside him and he may look up, as coming up the ladder in play.)
		var boy := false
		for z in m.enemies.values():
			if int(z.get_meta("kind")) == m.JANITOR_FIRST and z.position.y > o.y + 4 * H - 1.0 and (z.asleep or place == "duct"): boy = true
		check(f.get("kuya", false) and boy, "%s: Kuya Boy in the mechanical room" % place)
	if want == 12 or want == 13:
		check(not bool(session.team[1].light) and not game.story.flashlight.on, "%s: every light out in the fifth floor's dark" % place)
	if want >= 11: check(f.get("survivors", false) and int(f.get("door501", 0)) >= 0, "%s: 501 opened" % place)
	if want >= 13: check(int(f.get("horde", 0)) == 3, "%s: the horde has gone by (%d)" % [place, int(f.get("horde", 0))])
	if want == 13:
		var standing := 0
		for z in m.enemies.values():
			if z.asleep and absf(z.position.y - (o.y + 4 * H)) < 1.0: standing += 1
		check(standing >= 8, "%s: the horde standing in the fifth floor's corridor (%d)" % [place, standing])
	if want >= 14: check(f.get("blast", false) and f.get("fire5", false), "%s: the fire door open, the gas store gone up" % place)
	if want == 14 or place == "field":
		var out_there := 0
		for z in m.enemies.values():
			if (z.position - o).z > 535.0: out_there += 1
		check(out_there >= 5, "%s: the field full of them (%d)" % [place, out_there])
	if want >= 15 or place == "room208": check(m.escape._entered_two, "%s: Paolo has seen the stairs are gone" % place)
	match place:
		"heavykey":
			check(m.escape.fight.state == "dead" and f.get("heavy_key") is Vector3 and not f.get("heavy_key_taken", false), "heavykey: Heavy-arm dead, his key on the ground")
		"reargate":
			check(m.escape.fight.state == "dead" and f.get("heavy_key_taken", false) and f.get("reargate", false), "reargate: him dead, the key taken, the gate unlocked")
		"pilcstout":
			check(f.get("pilcst_out", false) and f.get("board", false), "pilcstout: out of the rear gate, the board up")
		"board":
			check(f.get("board", false) and int(f.get("lockup", 0)) == 4, "board: the chapter board up")
		"storeroad":
			var ahead := 0
			for z in m.enemies.values():
				if z.asleep and (z.position - o).z > 7.0: ahead += 1
			check(m.wave_left > 0 and ahead >= 3, "storeroad: the pack following and Store Road's own waiting further up (%d, wave %d)" % [ahead, m.wave_left])
		"mart":
			check(m.wave_left == 0, "mart: nothing follows any more (wave %d)" % m.wave_left)
		"backdoor", "backstreets", "arcade", "brickalley":
			var behind := 0
			var ahead := 0
			for z in m.enemies.values():
				if (z.position - o).z < spot.z - o.z + 4.0: behind += 1
				elif z.asleep: ahead += 1
			check(behind == 0 and ahead >= (1 if place == "brickalley" else 3), "%s: the backstreets' own waiting ahead, none behind (%d ahead, %d behind)" % [place, ahead, behind])
			check(m.wave_left > 0, "%s: the backstreets' trickle stands (%d)" % [place, m.wave_left])
	if want >= 13 and want < m.HOSPITAL:
		for p in m.escape.people:
			check(p.position.distance_to(host) < 9.0 and absf(p.position.y - host.y) < 1.6, "%s: %s with the squad, same floor" % [place, p.name])
	# A while later: still standing there, the chapter caught up, what is behind put away, nothing rushing in.
	await frames(170)
	# (0.66: the mart's board also maps the college's ground for the nav, ~10 ms a frame: the catch-up runs longer.)
	for i in 900:
		if session._chapter_screen == null or not session._chapter_screen.visible: break
		await frames(1)
	check(standing_near(spot, 3.0) and game.player.global_position.y > minf(o.y - 6.0, spot.y - 2.0), "%s: still there, on the ground (%s)" % [place, here()])
	if want >= m.HOSPITAL:
		# 0.68: the bridge's board loaded the hospital; Outer Street put away; what the place's flags say is behind.
		check(session.chapters_loaded.has("hospital") and m.hospital != null, "%s: the hospital loaded as at the bridge's board" % place)
		check(bool(f.get("outer_left_here", false)), "%s: Outer Street put away" % place)
		var hp = m.hospital
		var upto: Array = how.get("hosp", [])
		if "hosp_inside" in upto: check(hp.R_OUT in hp.gone and not hp.shutter_shape.disabled, "%s: the shutters down, the street put away" % place)
		else: check(hp.gone.is_empty() and hp.people.size() == 6, "%s: the street and the people outside still there" % place)
		if "hosp_upstairs" in upto: check(hp.R_F1 in hp.gone and hp._fire_door != null, "%s: the fire door shut, the ground floor put away" % place)
		if "hosp_third" in upto: check(hp.R_F2 in hp.gone and hp.R_LOBBY in hp.gone, "%s: the second floor and the lobby put away" % place)
		if "hosp_records" in upto and not ("hosp_third" in upto): check(hp._doc_local().distance_to(Vector3(-8.6, hp.F2, 28.0)) < 3.0, "%s: Doctor Berido in the records room" % place)
		if "lab_open" in upto: check(hp._door_t > .5, "%s: the laboratory's door open" % place)
		if place == "lucky": check(hp.lucky != null, "lucky: Doctor Lucky out of his pod")
	elif want >= 16:
		# 0.66: Outer Street: PILCST's board loaded it ("city") and the college is put away behind the rear gate.
		check(session.chapters_loaded.has("city"), "%s: the city's chapter loaded as at PILCST's board" % place)
		check(m.escape == null or m.escape._cleaned, "%s: the college put away behind the rear gate" % place)
		# 0.67: outer_dread.gd: what the squad passed on the way is settled; past the river road the kiosk is shut and
		# the first half put away on this peer.
		var os = m.outer_street
		var upto: Array = how.get("outer", [])
		if "outer_shutter" in upto: check(bool(f.get("outer_bags", false)), "%s: the triage bags split behind" % place)
		if "outer_train" in upto: check(bool(f.get("outer_train_dark", false)), "%s: the train's lights died behind" % place)
		if "outer_up" in upto:
			check(bool(f.get("outer_stair_dark", false)), "%s: the long stair gone dark behind" % place)
			check(bool(f.get("outer_kiosk_shut", false)) and not os.kiosk_shape.disabled, "%s: the kiosk's door shut behind the squad" % place)
			check(os.gone.size() == 6 and not os.roots[os.R_STATION].visible and not os.roots[os.R_PLAZA].visible, "%s: the first half put away (%d roots)" % [place, os.gone.size()])
			check(m.place_closed("outerconcourse") != "" and m.place_closed("outerplaza") != "" and m.place_closed("outerriver") == "", "%s: the teleports back there closed" % place)
			var behind := 0
			for z in m.enemies.values():
				if is_instance_valid(z) and not os.past_kiosk(os.local(z.global_position)): behind += 1
			check(behind == 0, "%s: no infected left behind the kiosk (%d)" % [place, behind])
		elif upto.size() > 0:
			check(not bool(f.get("outer_kiosk_shut", false)) and os.gone.is_empty(), "%s: the kiosk still open, nothing put away yet" % place)
	elif want >= 8:
		check(session.chapters_loaded.has("backstreets") or place == "pilcstout", "%s: the mart's chapter loaded as at its board" % place)
		check(session._chapter_screen == null or not session._chapter_screen.visible or place == "pilcstout", "%s: the chapter screen gone" % place)
	if want >= 9 or place in ["arcade", "brickalley"]: check(m.cleaned, "%s: the town, the canal and Store Road put away" % place)
	# (Out of the rear gate the college's own unload, which keeps only the gate and the street beyond, has them too.)
	if want >= 10 and want < 16: check(m.school_unloaded or (m.escape != null and m.escape._cleaned), "%s: the backstreets put away behind the shut gate" % place)
	if want >= 9 and want < m.OVER: check(m.wave_left == 0, "%s: no stray wave from before (%d)" % [place, m.wave_left])
	if want >= 13 and int(f.get("settled", -1)) >= 12: check(m.escape._heard.has("crash"), "%s: the horde's crash on the stairs not heard again" % place)
	if want >= 14 and int(f.get("settled", -1)) >= 14: check(m.escape._heard.has("blast"), "%s: the blast not heard again" % place)
	# (Outer Street wakes each part's own as the squad reaches it: not checked there.)
	if want >= 11 and want < 16 and not place in ["field", "heavyarm"]:
		var close := 0
		for z in m.enemies.values():
			if is_instance_valid(z) and not z.asleep and not z.dead and z.position.distance_to(game.player.global_position) < 15.0: close += 1
		check(close == 0, "%s: nothing hunting the squad on arrival (%d)" % [place, close])
	if place in ["lobby", "floor2", "floor3", "floor4", "floor5"]:
		var k := int(how.get("floors", 0))
		check(f.get("floor%d" % k, false), "%s: the floor itself reached on arrival, as in play" % place)

## 0.55: the teleports: ahead of the run and back, one survivor or the squad, put away places refused, the Missions tab.
func check_go() -> void:
	var o: Vector3 = m.Street.ORIGIN
	var H: float = m.SCHOOL.H
	check(cmd("go lobby").contains("Lobby") and m.stage == 0, "go lobby from the start: the run stays at stage 0")
	await frames(20)
	check(m.ahead_awake and m.school != null and bool(m.flags.get("woken", false)), "the college woken early for it")
	check(standing_near(o + Vector3(28, 0, 515)), "the host in the lobby (%s)" % here())
	check((session.team[bot_id()].pos as Vector3).distance_to(game.player.global_position) < 5.0, "the squad AI with them")
	check(cmd("go fire2").contains("Fire escape"), "go fire2")
	await frames(20)
	var host: Vector3 = game.player.global_position
	var b: Vector3 = session.team[bot_id()].pos
	check(standing_near(o + Vector3(57.0, H, 522.0)) and absf(b.y - host.y) < 1.0 and b.distance_to(host) < 4.0, "the fire escape's landing: both on it (host %s, AI %s)" % [here(), str((b - o).snapped(Vector3.ONE * .1))])
	check(cmd("go dodonghouse").contains("Dodong"), "go back to Dodong's house")
	await frames(20)
	var house: Vector3 = game.player.global_position
	check(cmd("go in501 me").begins_with("You:"), "go in501 me: only the host")
	# (Only the host is moved; the squad AI then catch up by themselves, as they do with anyone 32 m off: bots.gd.)
	check((session.team[bot_id()].pos as Vector3).distance_to(house) < 4.0, "the squad AI not moved by it")
	await frames(20)
	check(standing_near(o + Vector3(3.6, 4 * H, 517.4)), "the host in 501 (%s)" % here())
	check(cmd("squad").contains("with you"), "squad")
	await frames(10)
	check((session.team[bot_id()].pos as Vector3).distance_to(game.player.global_position) < 4.0, "the squad AI brought to the host")
	check(cmd("go home").contains("Living room"), "go home (the house)")
	check(cmd("go nowhere").begins_with("Unknown place"), "an unknown place is named as such")
	check(m.stage == 0, "the run never moved (stage %d)" % m.stage)
	cmd("jump school")
	await frames(240)
	check(m.cleaned and m.place_closed("bridge") != "" and m.place_closed("martfront") != "" and m.place_closed("lobby") == "", "at the school: the canal and Store Road put away, the college not")
	check(cmd("go bridge").contains("put away"), "go bridge refused (%s)" % m.place_closed("bridge"))
	# The Missions tab: a button for every jump and every place, greyed where they cannot be used.
	var menu = game.get_node("DebugMenu")
	menu.show_menu()
	await process_frame
	check(menu._jump_buttons.size() == m.JUMPS.size(), "a jump button for every mission (%d of %d)" % [menu._jump_buttons.size(), m.JUMPS.size()])
	check(menu._go_buttons.size() == m.places().size(), "a teleport button for every place (%d of %d)" % [menu._go_buttons.size(), m.places().size()])
	check(menu._jump_buttons["mart"].disabled and not menu._jump_buttons["school"].disabled and not menu._jump_buttons["heavyarm"].disabled, "behind the run greyed, the rest not")
	check(menu._go_buttons["bridge"].disabled and not menu._go_buttons["yard"].disabled, "put away places greyed")
	check(menu._mission_now.text.begins_with("Now: stage 9"), "where the run stands (%s)" % menu._mission_now.text)
	(menu._go_buttons["yard"] as Button).pressed.emit()
	await frames(20)
	check(standing_near(o + Vector3(28.6, 0, 504.4)) and m.stage == 9, "the Yard button: there, the run still at 9 (%s)" % here())
	(menu._jump_buttons["lobby"] as Button).pressed.emit()
	await frames(20)
	check(m.stage == 10 and menu._jump_buttons["school"].disabled, "the Lobby jump button: stage 10, the school gate greyed now")
	menu.close()
	# Complete from inside: on to 501 with the floors behind settled (no rush at Ma'am Teves's door).
	check(cmd("complete").contains("-> 11"), "complete in the school: 501 opens")
	await frames(150)
	var close := 0
	for z in m.enemies.values():
		if is_instance_valid(z) and not z.asleep and not z.dead and z.position.distance_to(game.player.global_position) < 15.0: close += 1
	check(close == 0 and m.flags.get("floor4", false), "at 501: the fifth floor long reached, nothing rushing in (%d)" % close)
	check(not session.hint_queue.has("stairs") and (session._hint_key != "stairs" or session.hint_time <= .6), "the stairs hint (stage 10's) gone with the stage")
