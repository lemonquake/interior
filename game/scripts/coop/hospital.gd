extends "res://scripts/coop/hospital_world.gd"
## 0.68: the hospital chapter (mission stage 18; scripts/coop/hospital_world.gd lays it down). Built on every peer
## behind the long bridge's chapter board, never before. The way:
##   the street outside: ambulances, police, doctors and nurses who stay there; every way blocked but the doors ->
##   inside (the lockdown shutter comes down behind the squad; the street is put away) -> the lobby: the grand stair
##   fell, the west corridor is barricaded to the ceiling, the way north came down -> the east hall, through the ER
##   to the back corridor, west to the stairwell, up -> the second floor (its fire door slams behind the squad; the
##   ground floor is put away but for the lobby the balcony looks down into) -> Doctor Berido, hiding in the sterile
##   supply room behind the theatre, in only through the low hole in its partition -> the cafeteria's kitchen, the
##   ladder into the duct, the crawl to the records room's grille -> the bookcase, the hidden stair -> the third
##   floor, quiet (the second floor put away): five things for the laboratory's door -> the laboratory: its people,
##   the doctor's story, Doctor Lucky -> the catwalk's ladder to the roof, the flare.
##
## Host: `host_tick` (progress from where the squad is, the people, the seals' flags, the zones' infected, the talk),
## `interact`. Every peer: `sync` (the shutter, the fire door, the bookcase, the big door, the pod, the put-away
## floors, what is drawn from where the viewer is), `steer` for the infected, the squad AI and the doctor.

const LUCKY := preload("res://scripts/coop/lucky.gd")
const Shine := preload("res://scripts/pickup_shine.gd")
const START_Z := 1290.0

const STEPS := [
	["hosp_talked", "Speak to the doctors by the ambulances."],
	["hosp_inside", "Get inside the hospital."],
	["hosp_upstairs", "The stairs in the lobby came down. Find another way up to the second floor."],
	["hosp_berido", "Find Doctor Berido. He is hiding somewhere on the second floor."],
	["hosp_berido_talk", "Listen to Doctor Berido."],
	["hosp_ladder", "Through the cafeteria to its kitchen, and up the ladder into the vents."],
	["hosp_records", "Crawl through the vents to the records room."],
	["hosp_bookcase", "The records room. Find the hidden way up."],
	["hosp_third", "Up the hidden stairs to the third floor."],
	["hosp_items", ""],
	["lab_open", "Stand back while Doctor Berido opens the door."],
	["hosp_lab_clear", "Kill everything in the laboratory."],
	["hosp_story", "Listen to Doctor Berido."],
	["hosp_lucky_dead", "Kill Doctor Lucky."],
	["hosp_roof", "Up the ladder on the catwalk to the roof."],
	["hosp_flare", "Fire the flare to signal for help."],
]
const PROMPTS := {"hosp_talk": "E  •  Speak to the doctors", "hosp_listen": "E  •  Go on", "hosp_berido": "E  •  Speak to Doctor Berido",
	"hosp_bookcase": "E  •  Pull the bookcase", "hosp_give": "E  •  Give Doctor Berido what you found", "hosp_flare": "E  •  Fire the flare"}
## Who is outside (the survivors' models) and how each stands.
const PEOPLE := [["doctor_m", "idle"], ["nurse_f", "idle_hurt"], ["police_1", "idle"], ["doctor_f", "idle_look"], ["police_2", "idle"], ["nurse_m", "idle_hurt"]]
const OUTSIDE_TALK := [
	["Doctor", "You came across the bridge? Then you've seen what the city is now."],
	["Officer", "We pulled back to the ambulances an hour ago. Every street out of here is blocked. The only way anywhere is through those doors."],
	["Nurse", "There are still people inside. Someone was on the radio from the second floor until it went quiet."],
	["Doctor", "Doctor Berido was on duty upstairs. If anyone is still alive in there, he'll be with them."],
	["Officer", "The radios are dead down here. The only place anyone will see us from is the roof."],
	["Doctor", "Get to the roof and signal for help. Find Doctor Berido on the way. We'll hold the street and bring the shutters down behind you."],
]
const BERIDO_TALK := [
	["Doctor Berido", "Don't shoot! Please. I'm not one of them. I'm a doctor."],
	["{P}", "Doctor Berido? The people outside sent us. We're going up to the roof."],
	["Doctor Berido", "The roof... The only way up is through the third floor, and the stairs to it were sealed the first night."],
	["Doctor Berido", "There is another way. The cafeteria's kitchen has a ladder up into the ventilation ducts. They run over to the records room."],
	["Doctor Berido", "Take me with you. There's something on the third floor I have to see for myself."],
]
const STORY := [
	["Doctor Berido", "These were my colleagues. I worked beside every one of them."],
	["Doctor Berido", "This laboratory was never on the hospital's plans. We were told it was research into brain injury. Bringing dead brain tissue back."],
	["Doctor Berido", "We took brains from the morgue and kept them alive in those tanks. Then we tried to wake them. To bring them back to consciousness."],
	["Doctor Berido", "One of them woke. Something in it was alive, and it was hungry. It was in the staff before anyone understood what it was."],
	["Doctor Berido", "The director sealed this floor and kept working. He said we were close."],
	["Doctor Berido", "That pod at the end. That was Doctor Lucky. He volunteered first."],
]
const GIVE_LINES := {"keycard": "The director's keycard.", "logbook": "The door's code is in his logbook.", "override": "The override key. They kept this from us for a reason.",
	"fuse": "The door's own fuse.", "battery": "Enough to move the door with the power out."}
## The infected waiting in each part, woken as the squad reaches it: [id, triggers, radius, gate, [[spot, mode, pool]], drops].
const POOL_F1 := [83, 84, 82, 81, 85, 9, 50, 8, 7, 86]
const POOL_F2 := [75, 76, 85, 83, 84, 8, 7, 9, 50, 81]
const POOL_CAFE := [27, 39, 85, 83, 9, 50, 7]
const POOL_LAB := [77, 78, 79, 80, 75, 76, 77, 79]

var lucky
var people: Array = []
var doc
var gone: Array = []
var _m
var _shutter_t := 0.0
var _fire_door: Node3D
var _book_t := 0.0
var _door_t := 0.0
var _pod_broken := false
var _flare_t := -1.0
var _flare: Node3D
var _seen := {}
var _bob := 0.0
## Host.
var _zones_done := {}
var _talk_q: Array = []
var _talk_wait := 0.0
var _talker := 0
var _doc_state := "hide"
var _doc_path := PackedVector3Array()
var _doc_path_wait := 0.0
var _doc_stall := 0.0
var _doc_last := Vector3.ZERO
var _work_t := 0.0
var _lab_spawned := false
var _wave_sent := false
var _lucky_at := -1.0
var _win_t := -1.0

func build(street: Node3D) -> void:
	var t0 := Time.get_ticks_usec()
	s = street
	name = "Hospital"
	rng.seed = int(s.get("seed_value") if s.get("seed_value") != null else 508) * 71 + 6811
	build_hospital()
	_make_areas()
	commit(220.0, 90.0, [R_SKY], 600.0)
	print("INTERIOR_COOP_HOSPITAL built in %d ms (%d lamps)" % [int((Time.get_ticks_usec() - t0) / 1000), lamps.size()])

## (every peer, after `build`) The people outside, the dead, Doctor Berido in his hiding place, the five things.
func after_build(m) -> void:
	_m = m
	var Fig = load("res://scripts/coop/figure.gd")
	for i in PEOPLE.size():
		var spec: Array = PEOPLE[i]
		var f = Fig.new()
		roots[R_OUT].add_child(f)
		f.setup("res://assets/characters/survivors/hosp_%s.glb" % spec[0], hv(NPC_AT[i]), "")
		var to: Vector3 = Vector3(0, 0, 0) - NPC_AT[i]
		f.rotation.y = atan2(-to.x, -to.z) + rng.randf_range(-.6, .6)
		f.pose(str(spec[1]))
		people.append(f)
	for i in dead_spots.size():
		var spec: Array = dead_spots[i]
		var v = Fig.new()
		v.set_meta("never_prune", true)
		m.add_child(v)
		v.key = -400 - i
		v.session = m.session
		v.setup("res://assets/characters/zombies/z_%s.glb" % m.INFECTED[int(spec[1])], world(hv(spec[0])), "", true)
		v.rotation.y = float(spec[2])
		var clip: String = spec[3]
		v.clips.play(clip)
		v.clips.seek(v.clips.get_animation(clip).length * float(spec[4]), true)
		v.go_limp(Vector3.ZERO)
		m.victims.append(v)
	doc = Fig.new()
	doc.set_meta("never_prune", true)
	m.add_child(doc)
	doc.setup("res://assets/characters/survivors/hosp_berido.glb", world(hv(BERIDO_AT)), "Doctor Berido")
	doc.rotation.y = PI * .75
	doc.pose("sit_hurt")
	for it: Array in ITEMS:
		var n := _item_mesh(str(it[0]))
		n.set_meta("never_prune", true)
		n.position = world(hv(it[2]))
		m.add_child(n)
		Shine.apply(n)
		item_nodes[str(it[0])] = n

func _item_mesh(kind: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Item " + kind
	var parts: Array = []
	match kind:
		"keycard": parts = [[Vector3(.09, .005, .055), Vector3(0, .003, 0), "#e8e8e4"], [Vector3(.09, .006, .015), Vector3(0, .004, -.012), "#1d4ea8"]]
		"logbook": parts = [[Vector3(.22, .04, .3), Vector3(0, .02, 0), "#2a2a30"], [Vector3(.2, .03, .28), Vector3(.012, .02, 0), "#e8e2d0"]]
		"override": parts = [[Vector3(.02, .012, .1), Vector3(0, .006, 0), "#c8a040"], [Vector3(.05, .012, .05), Vector3(0, .006, -.06), "#c8a040"], [Vector3(.03, .02, .03), Vector3(0, .01, -.06), "#b81e1e"]]
		"fuse": parts = [[Vector3(.04, .14, .04), Vector3(0, .07, 0), "#d8d4c8"], [Vector3(.05, .025, .05), Vector3(0, .012, 0), "#b8bcc0"], [Vector3(.05, .025, .05), Vector3(0, .13, 0), "#b8bcc0"]]
		_: parts = [[Vector3(.3, .2, .18), Vector3(0, .1, 0), "#2a2c2e"], [Vector3(.2, .03, .04), Vector3(0, .23, 0), "#1a1a1a"], [Vector3(.1, .04, .01), Vector3(0, .12, -.091), "#d8b81a"]]
	for p: Array in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.position = p[1]
		mi.material_override = s.material(str(p[2]))
		n.add_child(mi)
	return n

# ---------------------------------------------------------------- objectives and the E key

func got(flags: Dictionary) -> int:
	var n := 0
	for it: Array in ITEMS:
		if bool(flags.get("hosp_gave_" + str(it[0]), false)): n += 1
	return n

func objective(flags: Dictionary) -> String:
	if bool(flags.get("hosp_flare", false)): return "The flare is up."
	for st: Array in STEPS:
		if bool(flags.get(st[0], false)): continue
		if st[0] == "hosp_items":
			var carried := 0
			for it: Array in ITEMS:
				if bool(flags.get("hosp_got_" + str(it[0]), false)) and not bool(flags.get("hosp_gave_" + str(it[0]), false)): carried += 1
			var line := "Find what Doctor Berido needs to open the laboratory's door: the keycard, the logbook, the override key, the fuse, the battery pack (%d of 5)." % got(flags)
			if carried > 0: line += " Bring what you have to him."
			return line
		if st[0] == "hosp_berido_talk" and not _talk_q.is_empty(): return st[1]
		return st[1]
	return STEPS[STEPS.size() - 1][1]

func prompt(action: String) -> String:
	if action.begins_with("hosp_item_"):
		var k := action.trim_prefix("hosp_item_")
		for it: Array in ITEMS:
			if str(it[0]) == k: return "E  •  Take the " + str(it[1])
	return PROMPTS.get(action, "")

func _doc_local() -> Vector3: return local(doc.position) - HO if doc != null else Vector3.INF

func candidate(at_w: Vector3, flags: Dictionary, talking: bool) -> String:
	var p := local(at_w) - HO
	if talking and not _talk_q.is_empty(): return "hosp_listen"
	if not bool(flags.get("hosp_talked", false)) and not bool(flags.get("hosp_shut", false)):
		for a: Vector3 in NPC_AT:
			if p.distance_to(a) < 3.0: return "hosp_talk"
	var d := _doc_local()
	if not bool(flags.get("hosp_berido", false)) and d.is_finite() and p.distance_to(d) < 3.4 and absf(p.y - d.y) < 1.5: return "hosp_berido"
	if bool(flags.get("hosp_records", false)) and not bool(flags.get("hosp_bookcase", false)) and p.distance_to(BOOKCASE + Vector3(0, 0, -.6)) < 1.8: return "hosp_bookcase"
	if bool(flags.get("hosp_third", false)) and not bool(flags.get("lab_open", false)):
		for it: Array in ITEMS:
			var k := str(it[0])
			if not bool(flags.get("hosp_got_" + k, false)) and p.distance_to(it[2]) < 1.7: return "hosp_item_" + k
		var carried := false
		for it: Array in ITEMS:
			if bool(flags.get("hosp_got_" + str(it[0]), false)) and not bool(flags.get("hosp_gave_" + str(it[0]), false)): carried = true
		if carried and d.is_finite() and p.distance_to(d) < 2.8: return "hosp_give"
	if bool(flags.get("hosp_lucky_dead", false)) and not bool(flags.get("hosp_flare", false)) and p.distance_to(FLARE + Vector3(0, 0, 7.0)) < 2.2: return "hosp_flare"
	return ""

func interact(m, id: int, action: String) -> void:
	var f: Dictionary = m.flags
	if action == "hosp_talk":
		f.hosp_talked = true
		_say_all(m, OUTSIDE_TALK, id)
	elif action == "hosp_listen":
		_talk_wait = minf(_talk_wait, .05)
	elif action == "hosp_berido":
		f.hosp_berido = true
		_doc_state = "talk"
		_say_all(m, BERIDO_TALK, id)
		print("INTERIOR_COOP_HOSPITAL berido found")
	elif action == "hosp_bookcase":
		f.hosp_bookcase = true
		m.nav.forget_box(AABB(world(h(-11.5, F2 - .5, 32.0)), Vector3(3.0, 3.0, 3.0)))
		m.say("Doctor Berido\nThis stair was never on any floor plan.", 6)
		print("INTERIOR_COOP_HOSPITAL bookcase")
	elif action.begins_with("hosp_item_"):
		f["hosp_got_" + action.trim_prefix("hosp_item_")] = true
	elif action == "hosp_give":
		var said := ""
		for it: Array in ITEMS:
			var k := str(it[0])
			if bool(f.get("hosp_got_" + k, false)) and not bool(f.get("hosp_gave_" + k, false)):
				f["hosp_gave_" + k] = true
				said = GIVE_LINES[k]
		if got(f) >= ITEMS.size():
			f.hosp_items = true
			_doc_state = "work"
			_work_t = 0.0
			said = "That's everything. Stand back. I don't know what's still alive behind it."
		if said != "": m.say("Doctor Berido\n" + said, 7)
	elif action == "hosp_flare":
		f.hosp_flare = true
		_win_t = 4.0
		print("INTERIOR_COOP_HOSPITAL flare")

## The host's talk: one line at a time on everyone's screen; E (or time) goes on.
func _say_all(m, lines: Array, who: int) -> void:
	_talk_q = lines.duplicate()
	_talker = who
	_talk_wait = .2

func _talk_tick(m, delta: float) -> void:
	if _talk_q.is_empty(): return
	_talk_wait -= delta
	if _talk_wait > 0.0: return
	var line: Array = _talk_q.pop_front()
	var who: String = line[0]
	if who == "{P}":
		var slot: int = int(m.session.team[_talker].slot) if m.session.team.has(_talker) else 0
		who = m.session.NAMES[slot % m.session.NAMES.size()]
	var text: String = line[1]
	m.say(who + "\n" + text, 60)
	_talk_wait = clampf(2.6 + text.length() * .062, 4.5, 13.0)
	if _talk_q.is_empty(): _talk_wait = -1.0

func talking() -> bool: return not _talk_q.is_empty()

# ---------------------------------------------------------------- the host's night

func _flag(m, key: String) -> void:
	if bool(m.flags.get(key, false)): return
	m.flags[key] = true
	print("INTERIOR_COOP_HOSPITAL ", key)

func host_tick(m, delta: float, living: Array) -> void:
	var humans: Array = []
	var anyone: Array = []
	for id: int in living:
		var lp: Vector3 = local(m.session.team[id].pos) - HO
		anyone.append(lp)
		if not m.session.is_bot(id): humans.append(lp)
	var who: Array = humans if not humans.is_empty() else anyone
	var f: Dictionary = m.flags
	_talk_tick(m, delta)
	if _talk_q.is_empty() and _talk_wait < 0.0:
		_talk_wait = 0.0
		if bool(f.get("hosp_berido", false)) and not bool(f.get("hosp_berido_talk", false)):
			_flag(m, "hosp_berido_talk")
			_doc_state = "follow"
			_berido_wave(m)
	var inside := 0
	var up := 0
	var third := 0
	for lp: Vector3 in who:
		if lp.z > 1.2 and lp.y < 3.0 and absf(lp.x) < 24.0: inside += 1
		if lp.y > 3.8 and lp.x > -15.8: up += 1
		if lp.y > 3.8: _flag(m, "hosp_upstairs")
		if lp.y > 6.6 and lp.y < 8.2 and lp.x < -21.0 and lp.z > 19.0: _flag(m, "hosp_ladder")
		if lp.y > 3.8 and lp.y < 6.6 and lp.x > -11.0 and lp.x < -3.0 and lp.z > 25.0 and lp.z < 33.5 and bool(f.get("hosp_ladder", false)): _records(m)
		if lp.y > 8.0 and lp.y < 12.0 and lp.x < 4.0: third += 1
		if lp.y > 15.5: _flag(m, "hosp_roof")
	if inside > 0: _flag(m, "hosp_inside")
	if not who.is_empty() and inside == who.size() and not bool(f.get("hosp_shut", false)):
		_flag(m, "hosp_talked")
		_flag(m, "hosp_shut")
		m.session.gather_bots(world(h(0, 0, 6)))
		m.say("Officer\nThe shutters are coming down behind you! Go!", 6)
	if not who.is_empty() and up == who.size() and not bool(f.get("hosp_f1_shut", false)):
		_flag(m, "hosp_f1_shut")
		m.session.gather_bots(world(h(-12, F2, 23)))
		_free_enemies(m, func(p: Vector3) -> bool: return p.y < 3.5)
	if third > 0: _flag(m, "hosp_third")
	if not who.is_empty() and third == who.size() and not bool(f.get("hosp_f2_shut", false)):
		_flag(m, "hosp_f2_shut")
		m.session.gather_bots(world(h(-7, F3, 29)))
		if _doc_local().y < 8.0: _put_doc(m, Vector3(-6.0, F3, 30.0))
		_doc_state = "door"
		m.say("Doctor Berido\nNobody was supposed to come up here. This whole floor belongs to the laboratory.", 8)
		_free_enemies(m, func(p: Vector3) -> bool: return p.y < 8.0)
	_doctor(m, delta, who)
	if _doc_state == "work":
		_work_t += delta
		if _work_t > 6.0 and not bool(f.get("lab_open", false)):
			_flag(m, "lab_open")
			m.nav.forget_box(AABB(world(h(2.5, F3 - .5, 21.0)), Vector3(3.0, 5.0, 6.0)))
			_doc_state = "door"
	if bool(f.get("lab_open", false)) and not _lab_spawned:
		_lab_spawned = true
		_lab_wave(m)
	if _lab_spawned and not bool(f.get("hosp_lab_clear", false)) and m._later.is_empty():
		var left := 0
		for z in m.enemies.values():
			if is_instance_valid(z) and z.hp > 0 and not z.has_meta("boss"): left += 1
		if left == 0:
			_flag(m, "hosp_lab_clear")
			_doc_state = "mourn"
	if _doc_state == "story" and _talk_q.is_empty() and _talk_wait <= 0.0 and not bool(f.get("hosp_story", false)):
		_flag(m, "hosp_story")
		_lucky_at = 1.5
	if _lucky_at > 0.0:
		_lucky_at -= delta
		if _lucky_at <= 0.0:
			f.lucky_out = true
			if lucky == null:
				lucky = LUCKY.new()
				add_child(lucky)
				lucky.setup(m, self)
			_doc_state = "hide2"
	if lucky != null and not bool(f.get("hosp_lucky_dead", false)):
		lucky.tick(delta, living)
		if lucky.state == "dead":
			_flag(m, "hosp_lucky_dead")
			m.say("Doctor Berido\nIt's over... The roof. The ladder is up on the catwalk. Go, signal them.", 9)
	_zones_tick(m, anyone)
	if _win_t > 0.0:
		_win_t -= delta
		if _win_t <= 0.0: m._win_hospital()

func _records(m) -> void:
	if bool(m.flags.get("hosp_records", false)): return
	_flag(m, "hosp_records")
	m.session.gather_bots(world(h(-6.0, F2, 28.6)))
	_put_doc(m, Vector3(-8.6, F2, 28.0))
	m.say("Doctor Berido\nThe bookcase against the far wall. Pull it.", 8)

func _put_doc(m, at: Vector3) -> void:
	var g: Vector3 = m.ground(world(hv(at)) + Vector3.UP * .4)
	doc.position = g if g.is_finite() else world(hv(at))
	doc.velocity = Vector3.ZERO
	doc.reset_physics_interpolation()
	_doc_path = PackedVector3Array()

func _free_enemies(m, below: Callable) -> void:
	for k in m.enemies.keys():
		var z = m.enemies[k]
		if not is_instance_valid(z) or z.has_meta("boss"): continue
		if below.call(local(z.position) - HO):
			z.queue_free()
			m.enemies.erase(k)

## Doctor Berido (host): hiding, talking, following the nearest of the squad, at the laboratory's door, working its
## panel, then into the laboratory to the tanks, and away from the fight.
func _doctor(m, delta: float, who: Array) -> void:
	if doc == null: return
	var at := _doc_local()
	match _doc_state:
		"hide":
			doc.pose("sit_hurt")
			_settle_doc(delta)
		"talk":
			doc.pose("idle_hurt")
			_settle_doc(delta)
			if m.session.team.has(_talker): _face_doc(m.session.team[_talker].pos, delta)
		"follow":
			_follow(m, delta, who)
		"door", "work":
			var spot := BERIDO_DOOR
			if at.distance_to(spot) > .5: _walk_doc(m, world(hv(spot)), delta, 2.0)
			else:
				_settle_doc(delta)
				doc.pose("idle" if _doc_state == "work" else "idle_hurt")
				_face_doc(world(hv(BIG_DOOR)) if _doc_state == "work" else world(h(-10.0, F3, 24.0)), delta)
		"mourn":
			var spot := Vector3(10.6, F3, 24.0)
			if at.distance_to(spot) > .5: _walk_doc(m, world(hv(spot)), delta, 1.4)
			else:
				_settle_doc(delta)
				doc.pose("sit_hurt")
				_face_doc(world(h(14.0, F3, 24.0)), delta)
				if not bool(m.flags.get("hosp_story", false)) and _talk_q.is_empty():
					_say_all(m, STORY, _talker)
					_doc_state = "story"
		"story":
			_settle_doc(delta)
			doc.pose("sit_hurt")
		"hide2":
			var spot := Vector3(-1.0, F3, 24.0)
			if at.distance_to(spot) > .6: _walk_doc(m, world(hv(spot)), delta, 3.2)
			else:
				_settle_doc(delta)
				doc.pose("idle_hurt")
				_face_doc(world(hv(BIG_DOOR)), delta)
	m.flags.hosp_doc = [doc.position.x, doc.position.y, doc.position.z, doc.rotation.y, doc.anim_name]

func _settle_doc(delta: float) -> void:
	doc.velocity.x = 0.0
	doc.velocity.z = 0.0
	doc.velocity.y = minf(0.0, doc.velocity.y) - 16.0 * delta
	doc.move_and_slide()

func _face_doc(at: Vector3, delta: float) -> void:
	var to: Vector3 = at - doc.position
	to.y = 0.0
	if to.length() > .3: doc.rotation.y = lerp_angle(doc.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-4.0 * delta))

func _follow(m, delta: float, who: Array) -> void:
	var lead := Vector3.INF
	var best := INF
	for lp: Vector3 in who:
		var d: float = lp.distance_to(_doc_local())
		if d < best:
			best = d
			lead = lp
	if not lead.is_finite():
		_settle_doc(delta)
		return
	var at := _doc_local()
	# Out of the supply room the only way there is: on hands and knees through the hole in the partition.
	if at.x > 14.0 and at.z > 30.0 and at.y > 3.8 and at.y < 6.5 and not (lead.x > 15.0 and lead.z > 30.0):
		var hole_out := Vector3(13.6, F2, 32.7)
		var hole_in := Vector3(16.6, F2, 32.7)
		var target := hole_in if (at.x > 17.2 or absf(at.z - hole_in.z) > .35) else hole_out
		var step := target - at
		step.y = 0.0
		if step.length() < .1:
			if target == hole_out: doc.position = world(hv(hole_out))
		else:
			doc.position += step.normalized() * minf(step.length(), (1.6 if at.x > 16.5 else .9) * delta)
			doc.rotation.y = atan2(-step.x, -step.z)
		doc.pose("walk" if at.x > 16.5 else "crawl")
		return
	# Lost (well behind, or stuck): put back behind whoever he follows.
	if best > 26.0 or _doc_stall > 6.0:
		var back := (at - lead)
		back.y = 0.0
		var spot: Vector3 = m.ground(world(hv(lead)) + (back.normalized() if back.length() > .1 else Vector3.BACK) * 1.4 + Vector3.UP * .4)
		if spot.is_finite():
			doc.position = spot
			doc.reset_physics_interpolation()
		_doc_stall = 0.0
		_doc_path = PackedVector3Array()
		return
	if best < 2.4 and absf(lead.y - at.y) < 1.3:
		_settle_doc(delta)
		doc.pose("idle_hurt")
		_face_doc(world(hv(lead)), delta)
		_doc_stall = 0.0
		return
	_walk_doc(m, world(hv(lead)), delta, 2.6 if best > 6.0 else 1.6)

func _walk_doc(m, to_w: Vector3, delta: float, speed: float) -> void:
	var aim := steer(doc.position, to_w, m.flags)
	_doc_path_wait -= delta
	if _doc_path_wait <= 0.0 or _doc_path.is_empty():
		_doc_path_wait = .7
		m.nav.space = m.get_world_3d().direct_space_state
		_doc_path = m.nav.path(doc.position, aim)
	var goal := aim
	while not _doc_path.is_empty() and Vector2(_doc_path[0].x - doc.position.x, _doc_path[0].z - doc.position.z).length() < .45:
		_doc_path.remove_at(0)
	if not _doc_path.is_empty(): goal = _doc_path[0]
	var dir: Vector3 = goal - doc.position
	dir.y = 0.0
	if dir.length() < .05:
		_settle_doc(delta)
		return
	dir = dir.normalized()
	doc.velocity.x = dir.x * speed
	doc.velocity.z = dir.z * speed
	doc.velocity.y = minf(0.0, doc.velocity.y) - 16.0 * delta
	doc.move_and_slide()
	doc.rotation.y = lerp_angle(doc.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-8.0 * delta))
	doc.pose("run" if speed > 2.4 else "walk")
	var moved: float = doc.position.distance_to(_doc_last)
	_doc_last = doc.position
	_doc_stall = _doc_stall + delta if moved < speed * delta * .2 else 0.0

## When the doctor is found, his voice and the squad's carried: they come up the corridor from both ends.
func _berido_wave(m) -> void:
	if _wave_sent: return
	_wave_sent = true
	var n := clampi(3 + m.session.team.size(), 4, 8)
	for i in n:
		var at := Vector3(-14.0 + rng.randf_range(-1, 1), F2, 23.0 + rng.randf_range(-1, 1)) if i % 2 == 0 else Vector3(22.0 + rng.randf_range(-1, 1), F2, 23.0 + rng.randf_range(-1, 1))
		var kind: int = POOL_F2[rng.randi() % POOL_F2.size()]
		m.later(func() -> void: _spawn(m, at, "awake", kind))

## The laboratory's people, all at once when its door opens: out from among the tanks, the benches, the pods.
func _lab_wave(m) -> void:
	var n := clampi(10 + 2 * m.session.team.size(), 12, 18)
	for i in n:
		var at := Vector3(rng.randf_range(7.0, 21.0), F3, rng.randf_range(15.0, 32.5))
		if Vector2(at.x - 14.0, at.z - 24.0).length() < 4.0: at.x = 7.5 if at.x < 14.0 else 20.5
		var kind: int = POOL_LAB[rng.randi() % POOL_LAB.size()]
		m.later(func() -> void: _spawn(m, at, "awake", kind))
	print("INTERIOR_COOP_HOSPITAL laboratory open, %d inside" % n)

func _spawn(m, at: Vector3, mode: String, kind: int) -> void:
	var wp: Vector3 = m.ground(world(hv(at)) + Vector3.UP * .4)
	if not wp.is_finite(): wp = world(hv(at))
	var z = m.spawn(wp, mode != "awake", false, kind)
	if z == null: return
	if mode == "awake":
		z.asleep = false
		return
	z.idle_mode = mode
	z.home = z.position
	z.rotation.y = rng.randf_range(-PI, PI)
	z.wander_wait = rng.randf_range(0, 4)

func _drop(m, at: Vector3, kind: String) -> void:
	var dp: Vector3 = m.ground(world(hv(at)) + Vector3.UP * .4)
	if not dp.is_finite(): dp = world(hv(at))
	m.next_drop += 1
	match kind:
		"gun":
			var wid := InteriorArsenal.pick(rng)
			var mag := int(InteriorArsenal.stats(wid).get("mag", 12))
			m.drops[m.next_drop] = [dp, "weapon:" + wid, [mag, true, mag * 2]]
		"kit": m.drops[m.next_drop] = [dp, "healthkit:medium"]
		_: m.drops[m.next_drop] = [dp, "ammo:large"]

func _zones() -> Array:
	return [
		{"id": "lobby", "at": [Vector3(0, 0, 2.0)], "r": 6.0, "gate": "", "z": [[Vector3(-6, 0, 13), "sleep", POOL_F1], [Vector3(4, 0, 13.5), "feed", POOL_F1], [Vector3(7, 0, 4), "wander", POOL_F1], [Vector3(-3, 0, 8), "sleep", POOL_F1], [Vector3(-8, 0, 12), "wander", POOL_F1]], "d": [[Vector3(-2.0, 0, 9.6), "ammo"]]},
		{"id": "hall", "at": [Vector3(11, 0, 8)], "r": 5.0, "gate": "", "z": [[Vector3(15, 0, 7.5), "feed", POOL_F1], [Vector3(17, 0, 9), "sleep", POOL_F1], [Vector3(13, 0, 9.2), "wander", POOL_F1]], "d": []},
		{"id": "er", "at": [Vector3(14, 0, 11.5)], "r": 4.0, "gate": "", "z": [[Vector3(11.8, 0, 19.0), "sleep", POOL_F1], [Vector3(18.2, 0, 19.0), "feed", POOL_F1], [Vector3(21, 0, 17), "wander", POOL_F1], [Vector3(16, 0, 15.8), "feed", POOL_F1], [Vector3(22, 0, 12.5), "sleep", POOL_F1], [Vector3(12, 0, 15.6), "wander", POOL_F1]], "d": [[Vector3(17.0, 1.1, 13.6), "kit"]]},
		{"id": "back", "at": [Vector3(22, 0, 25)], "r": 5.0, "gate": "", "z": [[Vector3(10, 0, 31.5), "wander", POOL_F1], [Vector3(2, 0, 31.5), "feed", POOL_F1], [Vector3(-6, 0, 31.4), "sleep", POOL_F1], [Vector3(9, 0, 34.6), "sleep", POOL_F1], [Vector3(-12, 0, 31.5), "wander", POOL_F1]], "d": [[Vector3(18.0, 0, 31.5), "ammo"]]},
		{"id": "stairs", "at": [Vector3(-15, 0, 31.5)], "r": 4.0, "gate": "", "z": [[Vector3(-19, 0, 29.5), "sleep", POOL_F1], [Vector3(-19.5, F2, 23.2), "wander", POOL_F1]], "d": []},
		{"id": "f2c", "at": [Vector3(-14, F2, 23)], "r": 4.0, "gate": "", "z": [[Vector3(-6, F2, 23), "wander", POOL_F2], [Vector3(8, F2, 22.6), "feed", POOL_F2], [Vector3(14, F2, 23.6), "sleep", POOL_F2], [Vector3(20, F2, 22.8), "wander", POOL_F2]], "d": [[Vector3(-10.0, F2, 24.4), "ammo"]]},
		{"id": "cafe", "at": [Vector3(-13, F2, 19.5)], "r": 4.0, "gate": "", "z": [[Vector3(-17, F2, 4), "sleep", POOL_CAFE], [Vector3(-14.4, F2, 7), "feed", POOL_CAFE], [Vector3(-12.2, F2, 9.6), "sleep", POOL_CAFE], [Vector3(-12, F2, 13), "wander", POOL_CAFE], [Vector3(-16, F2, 16), "wander", POOL_CAFE], [Vector3(-21.6, F2, 18.6), "feed", POOL_CAFE], [Vector3(-11.6, F2, 3), "sleep", POOL_CAFE]], "d": [[Vector3(-19.4, F2 + 1.05, 9.0), "kit"]]},
		{"id": "warda", "at": [Vector3(-13.5, F2, 25.6)], "r": 3.0, "gate": "", "z": [[Vector3(-13.5, F2, 30.0), "sleep", POOL_F2], [Vector3(-12.2, F2, 34.6), "feed", POOL_F2]], "d": []},
		{"id": "wardb", "at": [Vector3(1.5, F2, 25.6)], "r": 3.0, "gate": "", "z": [[Vector3(-1.5, F2, 30.4), "sleep", POOL_F2], [Vector3(3, F2, 29), "wander", POOL_F2], [Vector3(4.5, F2, 34.6), "feed", POOL_F2]], "d": [[Vector3(-2.2, F2, 26.2), "ammo"]]},
		{"id": "or", "at": [Vector3(10.5, F2, 25.6)], "r": 3.0, "gate": "", "z": [[Vector3(9.0, F2, 29.0), "feed", [75, 76]], [Vector3(12.4, F2, 33.0), "sleep", [75, 76]], [Vector3(7.4, F2, 31.0), "wander", [75, 76, 85]]], "d": []},
		{"id": "nurse", "at": [Vector3(14, F2, 20.5)], "r": 3.5, "gate": "", "z": [[Vector3(16, F2, 13.6), "sleep", POOL_F2], [Vector3(20, F2, 18), "wander", POOL_F2], [Vector3(12, F2, 17), "feed", POOL_F2]], "d": [[Vector3(22.0, F2, 12.0), "kit"], [Vector3(20.0, F2, 12.0), "ammo"]]},
		{"id": "balcony", "at": [Vector3(0, F2, 21)], "r": 5.0, "gate": "", "z": [[Vector3(-5, F2, 14.4), "wander", POOL_F2], [Vector3(6, F2, 17), "feed", POOL_F2]], "d": []},
		{"id": "third", "at": [Vector3(-7, F3, 30)], "r": 6.0, "gate": "", "z": [], "d": [[Vector3(-8.0, F3, 28.0), "ammo"], [Vector3(-9.0, F3, 28.4), "kit"], [Vector3(-20.0, F3, 24.0), "gun"]]},
	]

func _zones_tick(m, anyone: Array) -> void:
	for zn: Dictionary in _zones():
		if _zones_done.has(zn.id): continue
		if str(zn.gate) != "" and not bool(m.flags.get(zn.gate, false)): continue
		var hit := false
		for lp: Vector3 in anyone:
			for t: Vector3 in zn.at:
				if lp.distance_to(t) < float(zn.r): hit = true
		if not hit: continue
		_zones_done[zn.id] = true
		for z: Array in zn.z:
			var at: Vector3 = z[0]
			var mode: String = z[1]
			var pool: Array = z[2]
			var kind: int = int(pool[rng.randi() % pool.size()])
			m.later(func() -> void: _spawn(m, at, mode, kind))
		for d: Array in zn.d: _drop(m, d[0], d[1])
		print("INTERIOR_COOP_HOSPITAL zone %s: %d" % [zn.id, zn.z.size()])

# ---------------------------------------------------------------- every peer

func sync(flags: Dictionary, delta: float, viewer := Vector3.INF) -> void:
	_lamps_tick(flags)
	# The doctor where the host has him.
	if doc != null and not _m.multiplayer.is_server() and flags.has("hosp_doc"):
		var a: Array = flags.hosp_doc
		var to := Vector3(float(a[0]), float(a[1]), float(a[2]))
		doc.position = doc.position.lerp(to, 1.0 - exp(-12.0 * delta)) if doc.position.distance_to(to) < 4.0 else to
		doc.rotation.y = lerp_angle(doc.rotation.y, float(a[3]), 1.0 - exp(-10.0 * delta))
		doc.pose(str(a[4]))
	# The lockdown shutter down over the whole front, then the street put away.
	if bool(flags.get("hosp_shut", false)) and _shutter_t < 1.0:
		if _shutter_t == 0.0:
			sound(world(h(0, 6.0, .5)), "res://assets/audio/siege/rattle.ogg", 4.0, 16.0)
			sound(world(h(0, 2.0, .5)), "res://assets/audio/sfx/siren_wail.ogg", -6.0, 30.0)
			shutter_shape.disabled = false
		_shutter_t = move_toward(_shutter_t, 1.0, delta / 3.0)
		shutter.scale.y = maxf(.02, _shutter_t)
		if _shutter_t >= 1.0:
			sound(world(h(0, .2, .5)), "res://assets/audio/sfx/impactMetal_heavy_001.ogg", 4.0, 14.0)
			_put_away([R_OUT], "the street outside")
	# The fire door at the top of the stairwell slams behind the squad; the ground floor goes (not the lobby).
	if bool(flags.get("hosp_f1_shut", false)) and _fire_door == null:
		_fire_door = StaticBody3D.new()
		_fire_door.collision_layer = 2
		_fire_door.position = world(h(-16.0, F2, 23.3)) - s.position
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(.12, 2.4, 1.6)
		cs.shape = bs
		cs.position = Vector3(0, 1.2, 0)
		_fire_door.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(.08, 2.36, 1.56)
		mi.mesh = bm
		mi.position = Vector3(0, 1.18, 0)
		mi.material_override = s.material("#b81e1e")
		_fire_door.add_child(mi)
		roots[R_F2].add_child(_fire_door)
		sound(world(h(-16.0, F2 + 1.2, 23.3)), "res://assets/audio/nichols/door_close_b.ogg", 6.0, 12.0)
		sound(world(h(-20.0, F2, 28.0)), "res://assets/audio/siege/bang_d.ogg", 2.0, 12.0)
		_put_away([R_F1, R_OUT], "the ground floor")
	if bool(flags.get("hosp_bookcase", false)) and _book_t < 1.0:
		if _book_t == 0.0: sound(world(hv(BOOKCASE) + Vector3.UP), "res://assets/audio/siege/scrape.ogg", 4.0, 8.0)
		_book_t = move_toward(_book_t, 1.0, delta / 1.6)
		bookcase.position = hv(BOOKCASE) + Vector3(1.55 * _book_t, 0, 0)
	if bool(flags.get("hosp_f2_shut", false)) and not (R_F2 in gone):
		_put_away([R_F2, R_LOBBY, R_F1, R_OUT], "the second floor")
	# The laboratory's door: the panel goes green, the leaves slide apart, the hall's lights come on.
	if bool(flags.get("lab_open", false)) and _door_t < 1.0:
		if _door_t == 0.0:
			door_light.emission = Color(.2, 1.0, .3)
			door_light.albedo_color = Color(.2, .8, .3)
			sound(world(hv(BIG_DOOR) + Vector3.UP * 2.0), "res://assets/audio/sfx/impactMetal_heavy_000.ogg", 6.0, 16.0)
			sound(world(hv(BIG_DOOR) + Vector3.UP * 2.0), "res://assets/audio/nichols/arc_buzz.ogg", 4.0, 12.0)
			sound(world(h(14.0, F3 + 2.0, 24.0)), "res://assets/audio/zombies/scream_3.ogg", 4.0, 20.0)
		_door_t = move_toward(_door_t, 1.0, delta / 3.2)
		big_door_n.position = h(4.0, F3, 25.0 + 2.0 * _door_t)
		big_door_s.position = h(4.0, F3, 23.0 - 2.0 * _door_t)
	elif bool(flags.get("hosp_items", false)) and not bool(flags.get("lab_open", false)):
		door_light.emission = Color(1.0, .7, .1) if int(Time.get_ticks_msec() / 250) % 2 == 0 else Color(1.0, .1, .05)
	if bool(flags.get("lucky_out", false)) and not _pod_broken:
		_pod_broken = true
		if lucky_pod_glass != null: lucky_pod_glass.visible = false
		sound(world(hv(POD_LUCKY) + Vector3.UP * 1.3), "res://assets/audio/sfx/hit_glass.ogg", 8.0, 20.0)
		sound(world(hv(POD_LUCKY) + Vector3.UP * 1.3), "res://assets/audio/zombies/scream_1.ogg", 8.0, 30.0)
		sparks(R_LAB, hv(POD_LUCKY) + Vector3(0, 2.4, -.6))
	if lucky != null and not _m.multiplayer.is_server(): pass
	if not _m.multiplayer.is_server() and bool(flags.get("lucky_out", false)) and lucky == null:
		lucky = LUCKY.new()
		add_child(lucky)
		lucky.setup(_m, self)
	if lucky != null: lucky.render(delta)
	for it: Array in ITEMS:
		var k := str(it[0])
		var n: Node3D = item_nodes.get(k)
		if n != null and n.visible and bool(flags.get("hosp_got_" + k, false)):
			n.visible = false
			if viewer.is_finite() and viewer.distance_to(n.global_position) < 6.0: sound(n.global_position, "res://assets/audio/sfx/key_pickup.ogg", -2.0, 4.0)
	# The specimens turning in their tanks.
	_bob += delta
	if not (R_LAB in gone) and roots[R_LAB].visible:
		for b: Array in brains:
			var n: Node3D = b[0]
			if not is_instance_valid(n): continue
			n.position = (b[1] as Vector3) + Vector3.UP * sin(_bob * .6 + float(b[2])) * .12
			n.rotation.y += delta * .15
	if bool(flags.get("hosp_flare", false)): _flare_tick(delta)
	if not viewer.is_finite(): return
	_view(local(viewer) - HO, flags)

## Roots put away on every peer: hidden, stopped, their meshes let go of a little each frame; the dead lying there and
## (host) the infected there freed.
func _put_away(list: Array, label_text: String) -> void:
	var t := Time.get_ticks_usec()
	var boxes: Array = []
	for r: int in list:
		if r in gone: continue
		gone.append(r)
		roots[r].visible = false
		roots[r].process_mode = Node.PROCESS_MODE_DISABLED
		if _m != null: _m._free_stack.append(roots[r])
		boxes.append(r)
	if boxes.is_empty() or _m == null: return
	if R_OUT in boxes:
		for f in people:
			if is_instance_valid(f): f.queue_free()
		people.clear()
	var keep_y := 3.5 if R_F1 in boxes and not (R_F2 in boxes) else (8.0 if R_F2 in boxes else -1.0)
	for lst: Array in [_m.victims, _m.corpses]:
		for i in range(lst.size() - 1, -1, -1):
			var fig = lst[i]
			if not is_instance_valid(fig): continue
			var p: Vector3 = local(fig.where()) - HO
			var lobby: bool = p.x > -10.0 and p.x < 10.0 and p.z > 0.0 and p.z < 16.0 and p.y < 3.0 and not (R_LOBBY in boxes)
			if (p.z < 0.0 and R_OUT in boxes) or (p.y < keep_y and not lobby):
				fig.queue_free()
				lst.remove_at(i)
	print("INTERIOR_COOP_HOSPITAL put away %s (%.1f ms)" % [label_text, (Time.get_ticks_usec() - t) / 1000.0])

## What is drawn from where the viewer is (hospital-local): their own floor, the lobby from its balcony, the next
## floor from the stairs that lead to it.
func _view(v: Vector3, flags: Dictionary) -> void:
	var vis := []
	vis.resize(roots.size())
	vis.fill(false)
	vis[R_SKY] = true
	var lobby_x := absf(v.x) < 14.0 and v.z < 26.0
	if v.y < 3.6:
		vis[R_OUT] = true
		vis[R_LOBBY] = true
		vis[R_F1] = true
		vis[R_F2] = (absf(v.x) < 10.0 and v.z > 0.0 and v.z < 16.0) or (v.x < -16.0 and v.z > 22.0)
	elif v.y < 8.0:
		vis[R_F2] = true
		vis[R_LOBBY] = lobby_x
		vis[R_OUT] = lobby_x and v.z < 22.0
		vis[R_F1] = v.x < -15.0 or lobby_x
		vis[R_F3] = v.x > -11.0 and v.x < -3.0 and v.z > 33.4
	else:
		vis[R_F3] = true
		vis[R_LAB] = v.x > 2.0 or bool(flags.get("lab_open", false))
		vis[R_F2] = v.y < 9.5 and v.x > -11.0 and v.x < -2.0 and v.z > 33.4
	for g: int in gone: vis[g] = false
	for i in roots.size():
		if roots[i].visible != vis[i]: roots[i].visible = vis[i]
	# The doctor and the infected on floors not drawn are not drawn either.
	var f: int = 0 if v.y < 3.6 else (1 if v.y < 8.0 else 2)
	if doc != null:
		var dl := _doc_local()
		var df: int = 0 if dl.y < 3.6 else (1 if dl.y < 8.0 else 2)
		doc.visible = absi(df - f) <= 1

func _flare_tick(delta: float) -> void:
	if _flare_t < 0.0:
		_flare_t = 0.0
		_flare = Node3D.new()
		add_child(_flare)
		var g := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = .18
		sm.height = .36
		g.mesh = sm
		var mt := StandardMaterial3D.new()
		mt.emission_enabled = true
		mt.emission = Color(1.0, .2, .1)
		mt.emission_energy_multiplier = 12.0
		mt.albedo_color = Color(1.0, .3, .2)
		g.material_override = mt
		_flare.add_child(g)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, .25, .15)
		l.light_energy = 6.0
		l.omni_range = 60.0
		_flare.add_child(l)
		_flare.position = h(14.0, LAB_ROOF + 1.4, 31.0)
		smoke(R_SKY, h(14.0, LAB_ROOF + 1.0, 31.0), 30, 1.0, false)
		sound(world(h(14.0, LAB_ROOF + 1.0, 31.0)), "res://assets/audio/sfx/gun_shot.ogg", 4.0, 40.0)
	_flare_t += delta
	_flare.position = h(14.0, LAB_ROOF + 1.4 + minf(_flare_t, 6.0) * 14.0 - maxf(0.0, _flare_t - 6.0) * 1.5, 31.0)

# ---------------------------------------------------------------- the way, for the infected, the squad AI and the doctor

var areas: Array = []
var links: Array = []
var _hops := {}
const GATES := ["hosp_bookcase", "lab_open", "hosp_f1_shut"]

func _box(lo: Vector3, hi: Vector3) -> AABB: return AABB(lo, hi - lo)

func _make_areas() -> void:
	areas = [
		["street", [_box(Vector3(-30, -1, -30), Vector3(30, 3, 0))]],
		["stairs", [_box(Vector3(-24, -1, 22), Vector3(-16, 5.6, 36))]],
		["f1", [_box(Vector3(-24, -1, 0), Vector3(24, 3.6, 36))]],
		["records", [_box(Vector3(-11, 3.6, 25), Vector3(-3, 8.0, 36))]],
		["f2", [_box(Vector3(-24, 3.6, 0), Vector3(24, 7.0, 36))]],
		["lab", [_box(Vector3(4, 8.0, 12), Vector3(24, 16.0, 36))]],
		["f3", [_box(Vector3(-24, 8.0, 0), Vector3(4, 11.6, 36))]],
	]
	var i := func(n: String) -> int:
		for k in areas.size():
			if areas[k][0] == n: return k
		return -1
	links = [
		{"a": i.call("street"), "b": i.call("f1"), "pts": [Vector3(0, 0, -3.0), Vector3(0, 0, -.6), Vector3(0, 0, 1.6), Vector3(0, 0, 4.0)], "gate": ""},
		{"a": i.call("f1"), "b": i.call("stairs"), "pts": [Vector3(-13.5, 0, 31.5), Vector3(-16.0, 0, 31.5), Vector3(-18.5, 0, 33.0)], "gate": ""},
		{"a": i.call("stairs"), "b": i.call("f2"), "pts": [Vector3(-19.0, 0, 34.6), Vector3(-22.4, 0, 35.3), Vector3(-22.4, F2, 24.0), Vector3(-18.0, F2, 23.3), Vector3(-14.8, F2, 23.3)], "gate": "!hosp_f1_shut"},
		{"a": i.call("records"), "b": i.call("f3"), "pts": [Vector3(-10.1, F2, 31.4), Vector3(-10.1, F2, 34.0), Vector3(-9.4, F2, 34.75), Vector3(-3.6, F3, 34.75), Vector3(-2.8, F3, 32.6), Vector3(-7.0, F3, 27.0)], "gate": "hosp_bookcase"},
		{"a": i.call("f3"), "b": i.call("lab"), "pts": [Vector3(1.6, F3, 24.0), Vector3(4.0, F3, 24.0), Vector3(6.6, F3, 24.0)], "gate": "lab_open"},
	]

func area_of(p: Vector3) -> int:
	for k in areas.size():
		for b: AABB in areas[k][1]:
			if b.has_point(p): return k
	return -1

func steer(from_w: Vector3, to_w: Vector3, flags: Dictionary) -> Vector3:
	if areas.is_empty(): return to_w
	var f := local(from_w) - HO
	var t := local(to_w) - HO
	var fa := area_of(f)
	var ta := area_of(t)
	if fa < 0 or ta < 0 or fa == ta: return to_w
	var gates := 0
	for g in GATES.size():
		if bool(flags.get(GATES[g], false)): gates |= 1 << g
	var key := (fa * 64 + ta) * 16 + gates
	if not _hops.has(key): _hops[key] = _first_hop(fa, ta, gates)
	var hop: Vector2i = _hops[key]
	if hop.x < 0: return to_w
	var pts: Array = links[hop.x].pts
	if hop.y == 0:
		pts = pts.duplicate()
		pts.reverse()
	return world(hv(_along(f, pts)))

func _open(gate: String, gates: int) -> bool:
	if gate == "": return true
	if gate.begins_with("!"): return gates & (1 << GATES.find(gate.trim_prefix("!"))) == 0
	return gates & (1 << GATES.find(gate)) != 0

func _first_hop(fa: int, ta: int, gates: int) -> Vector2i:
	var came := {fa: Vector2i(-1, -1)}
	var queue: Array = [fa]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		if at == ta: break
		for li in links.size():
			var ln: Dictionary = links[li]
			if not _open(str(ln.gate), gates): continue
			var nb := -1
			if int(ln.a) == at: nb = int(ln.b)
			elif int(ln.b) == at: nb = int(ln.a)
			if nb < 0 or came.has(nb): continue
			came[nb] = Vector2i(li, 1 if int(ln.a) == at else 0)
			came[nb + 1000] = Vector2i(at, 0)
			queue.append(nb)
	if not came.has(ta): return Vector2i(-1, -1)
	var cur := ta
	var step: Vector2i = came[cur]
	while int((came[cur + 1000] as Vector2i).x) != fa:
		cur = int((came[cur + 1000] as Vector2i).x)
		step = came[cur]
	return step

func _along(f: Vector3, pts: Array) -> Vector3:
	var best := 0
	var bd := INF
	for k in pts.size() - 1:
		var d := _seg_dist(f, pts[k], pts[k + 1])
		if d < bd:
			bd = d
			best = k
	if bd > 2.4: return pts[0]
	var nx := best + 1
	if nx < pts.size() - 1 and f.distance_to(pts[nx]) < .8: nx += 1
	return pts[nx]

static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), .0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Where a spot (hospital-local) is in the world.
func spot_w(at: Vector3) -> Vector3: return world(hv(at))

# ---------------------------------------------------------------- debug

## (host, debug) The chapter done as play would do it: up to the flare.
func debug_finish(m) -> void:
	for st: Array in STEPS: m.flags[st[0]] = true
	for it: Array in ITEMS:
		m.flags["hosp_got_" + str(it[0])] = true
		m.flags["hosp_gave_" + str(it[0])] = true
	m.flags.hosp_shut = true
	m.flags.hosp_f1_shut = true
	m.flags.hosp_f2_shut = true
	m.flags.lucky_out = true
	_lab_spawned = true
	if lucky != null: lucky.debug_kill()
	_win_t = .05

## (host, debug) A jump into the chapter: the flags up to there set, the parts behind counted as reached, the doctor
## where play would have him.
func debug_settle(m, upto: Array) -> void:
	for k: String in upto: m.flags[k] = true
	var f: Dictionary = m.flags
	if "hosp_inside" in upto:
		f.hosp_talked = true
		f.hosp_shut = true
		_shutter_t = .999
	var behind := {"hosp_inside": ["lobby"], "hosp_upstairs": ["hall", "er", "back", "stairs"], "hosp_berido": ["f2c", "wardb", "or", "nurse", "balcony"],
		"hosp_ladder": ["cafe", "warda"], "hosp_third": ["third"]}
	for k: String in upto:
		for zid: String in behind.get(k, []): _zones_done[zid] = true
	if "hosp_upstairs" in upto: f.hosp_f1_shut = true
	if "hosp_third" in upto: f.hosp_f2_shut = true
	if "hosp_items" in upto:
		for it: Array in ITEMS:
			f["hosp_got_" + str(it[0])] = true
			f["hosp_gave_" + str(it[0])] = true
	if "lab_open" in upto: _lab_spawned = "hosp_lab_clear" in upto
	if "hosp_lab_clear" in upto: _lab_spawned = true
	if "hosp_berido_talk" in upto:
		_wave_sent = true
		_doc_state = "follow"
	if "hosp_records" in upto: _put_doc(m, Vector3(-8.6, F2, 28.0))
	if "hosp_third" in upto:
		_put_doc(m, BERIDO_DOOR)
		_doc_state = "door"
	if "hosp_story" in upto:
		_put_doc(m, Vector3(10.6, F3, 24.0))
		_doc_state = "story"
		_lucky_at = .5
	if "hosp_lucky_dead" in upto:
		f.lucky_out = true
		_lucky_at = -1.0
		_doc_state = "hide2"
	elif not ("hosp_story" in upto) and "hosp_berido_talk" in upto and not ("hosp_records" in upto):
		_put_doc(m, Vector3(13.0, F2, 31.0))
