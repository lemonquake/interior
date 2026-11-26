extends Node
## 0.52: out of PILCST with the survivors of room 501 (mission stages 11-15; scripts/coop/school.gd builds the ways).
##
## 11  Room 501 opens: Ma'am Teves (STEM 12-B's adviser) and four of her students, Bea, Paolo, Jerome and Trisha.
##     She thanks them and warns them: at this hour a horde comes through the fifth floor. Lights off, everyone in
##     the room, nobody moves.
## 12  The horde: heard first, then the desks in the east stair give way and they come along the corridor past
##     501's door and stop there, standing in the dark (idle_mode "march", then "sleep"/"wander"/"feed"). A light
##     in the room while one of them is at the door, a shot, or a run gives the room away: they come through it.
## 13  They will not leave, and the way the squad came up (the ladder, the duct) is full of them: the way out is
##     the fire exit at the far (east) end of the corridor, chained by the students; Ma'am Teves has the key. Past
##     the standing horde in the dark (crouched: walking is heard, a shot wakes them all), the students following.
##     Halfway down the fire escape the kitchen's gas store goes up under room 208.
## 14  The fire escape ends at the second floor (the flight to the alley is torn off), and the blast has brought
##     the gallery down onto the grand stair. Room 208's outer wall is gone: down onto the lean-to's roof.
## 15  The school field, every one of them out there awake after the blast. Across it to the rear gate, which hangs
##     open onto the city: the chapter's board (everything behind put away, the dead too), then Davao City (next).
##
## The survivors follow the squad in a line (Teves behind the survivor nearest her, each student behind the one
## before), crouched while the horde is up there; the infected go for the squad, not them. Host moves them; the
## snapshot carries them to everyone (`state`, `apply`).
const Street := preload("res://scripts/coop/street.gd")
const Figure := preload("res://scripts/coop/figure.gd")
const SCHOOL := preload("res://scripts/coop/school.gd")
const HEAVY := preload("res://scripts/coop/heavyarm.gd")
const H := 3.6
const TEVES := 11
const HIDE := 12
const SNEAK := 13
const DOWN := 14
const FIELD := 15
## [model, caption, where they wait in 501 (street-local), facing, female]
const PEOPLE := [
	["pilcst_teves", "Ma'am Teves", Vector3(7.2, 4 * H, 520.2), PI, true],
	["pilcst_bea", "", Vector3(2.8, 4 * H, 515.8), 0.0, true],
	["pilcst_paolo", "", Vector3(4.4, 4 * H, 515.6), -.3, false],
	["pilcst_jerome", "", Vector3(1.4, 4 * H, 517.4), -PI * .5, false],
	["pilcst_trisha", "", Vector3(5.9, 4 * H, 515.7), .4, true],
]
const NAMES := ["Ma'am Teves", "Bea", "Paolo", "Jerome", "Trisha"]
## Ma'am Teves at the door. "{P}" is whoever knocked.
const TALK := [
	["Ma'am Teves", "Diyos ko... you're real. You're not from the barangay. Who sent you?"],
	["{P}", "Rommel, at the back gate. He said someone up here flashes a light every night."],
	["Ma'am Teves", "That was me. Three times, every night. Eleven of us came up here the first night. Some went down to find their parents. Five of us are left."],
	["Ma'am Teves", "Bea, Paolo, Jerome, Trisha. Up. Get your bags. These people are taking us out."],
	["{P}", "And Sir Ivan?"],
	["Ma'am Teves", "He brought us water on the second night, through the ceiling. He went back down for the others. We heard him on the stairs. Then we didn't."],
	["Ma'am Teves", "Listen to me. At this hour they come through. All of them. Up the east stairs and along this hall, every night, like the bell still rings for them."],
	["Ma'am Teves", "Every light off. Everyone inside, away from the door, and nobody moves until they've gone past. Not a sound. Please."],
]
## After the horde has stopped out there, in a whisper, one line after another (seconds each).
const AFTER := [
	["Ma'am Teves", "(whispering) They've stopped. They won't go now. Not until it's light.", 6.0],
	["Ma'am Teves", "(whispering) Hear that, in the ceiling? They're in the vent. The way you came is full of them.", 7.0],
	["Ma'am Teves", "(whispering) The fire exit, at the far end of this hall. We chained it ourselves the first night. Here, the key. Slowly. Lights off. If anyone fires, all of them come.", 10.0],
]
## Where the horde stops (street-local x, side of the corridor): the west end past 501's door, then along the hall,
## more of them toward the east, where they came up.
const SETTLE_WEST := [[1.6, -1], [2.6, 1], [3.9, -1], [4.8, 1]]

var mission
var session
var school
var people: Array = []
var _paths: Array = []
## Host: Teves's talk, the horde's clock, who is in the horde, the after-lines, the field's trickle.
var talk_index := -1
var talk_wait := 0.0
var talker := 1
var _clock := 0.0
var horde: Array = []
var _horde_made := false
var _after := -1
var _after_wait := 0.0
var _force_wait := 0.0
var _field_wait := 6.0
var _entered_two := false
var _gate_time := 0.0
## Every peer: what has been heard or done once (sounds, the shake).
var _heard := {}
var _bed: AudioStreamPlayer3D
var _groan_wait := 1.0
var _cleaned := false
## 0.53: Heavy-arm at the rear gate, the fuel drums, the key (scripts/coop/heavyarm.gd).
var fight

func setup(owner_mission) -> void:
	mission = owner_mission
	session = mission.session
	school = mission.school
	name = "PILCST way out"
	fight = HEAVY.new()
	add_child(fight)
	fight.setup(mission)

func w(at: Vector3) -> Vector3: return Street.ORIGIN + at

## Room 501 opened (host): stage 11, the door in, her talk begins.
func knocked(id: int) -> void:
	mission.stage = TEVES
	mission.stage_time = 0.0
	mission.flags.survivors = true
	mission.flags.door501 = 1
	talker = id
	talk_index = -1
	talk_wait = 1.6
	_ensure_people()
	mission.say("Room 501\nThe desks behind the door scrape aside. A teacher in a maroon blazer, and four students behind her.", 6)
	print("INTERIOR_COOP_ESCAPE 501 open")

func _ensure_people() -> void:
	if not people.is_empty() or school == null: return
	for i in PEOPLE.size():
		var spec: Array = PEOPLE[i]
		var f := Figure.new()
		mission.add_child(f)
		f.key = -500 - i
		f.session = session
		f.setup("res://assets/characters/survivors/%s.glb" % spec[0], w(spec[2]), spec[1])
		f.rotation.y = float(spec[3])
		f.speed = 1.0
		f.pose("idle_hurt" if i == 0 else "sit_hurt")
		# (Outside, the moon lights them as it does the infected: the outdoor layer.)
		for g in f.find_children("*", "GeometryInstance3D", true, false): (g as GeometryInstance3D).layers |= 2
		people.append(f)
		_paths.append({"path": PackedVector3Array(), "wait": 0.0, "goal": Vector3.INF, "stalled": 0.0, "last": w(spec[2])})

func female(i: int) -> bool: return bool(PEOPLE[i][4])

# ---------------------------------------------------------------- host

func tick(delta: float, living: Array) -> void:
	if school == null: return
	_ensure_people()
	match mission.stage:
		TEVES: _talk(delta)
		HIDE: _hide(delta)
		SNEAK: _sneak(delta)
		DOWN: _down(delta)
		FIELD: _field(delta, living)
	if mission.stage >= DOWN and mission.stage <= FIELD: fight.tick(delta, living)
	_move_people(delta)

func _talk(delta: float) -> void:
	talk_wait -= delta
	if talk_wait > 0.0: return
	talk_index += 1
	if talk_index >= TALK.size():
		_start_hide()
		return
	var line: Array = TALK[talk_index]
	var who: String = line[0]
	if who == "{P}":
		var slot: int = int(session.team[talker].slot) if session.team.has(talker) else 0
		who = session.NAMES[slot % session.NAMES.size()]
	var text: String = line[1]
	mission.say(who + "\n" + text, 60)
	talk_wait = clampf(2.6 + text.length() * .062, 4.5, 13.0)

func listen() -> void:
	talk_wait = minf(talk_wait, .05)

func _start_hide() -> void:
	mission.stage = HIDE
	mission.stage_time = 0.0
	_clock = 0.0
	mission.flags.horde = 0
	mission.say("Ma'am Teves\n(whispering) Inside. Lights off. Here they come.", 8)
	# The rest of the building does not matter now: what is left below lets go (the fifth's own stay).
	for k in mission.enemies.keys():
		var z = mission.enemies[k]
		if not is_instance_valid(z) or z.dead or z.hp <= 0: continue
		if school.floor_of(z.position) != SCHOOL.FLOORS - 1 or not z.asleep:
			if z.position.distance_to(w(SCHOOL.DOOR_501)) > 18.0:
				mission.enemies.erase(k)
				z.queue_free()
	session.gather_bots(w(Vector3(4.0, 4 * H, 517.0)))
	# The classes still shut in on this floor stay shut: the horde is what comes now.
	var fired: int = int(mission.flags.get("fired", 0))
	for i in school.doors.size():
		var d: Dictionary = school.doors[i]
		if int(d.k) == SCHOOL.FLOORS - 1 and d.kind == "ambush" and not d.broken: fired |= 1 << i
	mission.flags.fired = fired
	print("INTERIOR_COOP_ESCAPE hide")

## Everyone (and every survivor of the squad on their feet) inside room 501.
func all_inside() -> bool:
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		if int(p.hp) <= 0: continue
		if not in_501(p.pos): return false
	return true

func in_501(at: Vector3) -> bool:
	var p: Vector3 = at - Street.ORIGIN
	return p.x > .3 and p.x < 8.0 and p.z > 514.3 and p.z < 521.95 and absf(p.y - 4 * H) < 1.2

func _hide(delta: float) -> void:
	_clock += delta
	var phase: int = int(mission.flags.get("horde", 0))
	if phase == 0:
		if _clock > 22.0 and not _heard.has("hurry") and not all_inside():
			_heard["hurry"] = true
			mission.say("Ma'am Teves\n(whispering) Inside! Now! I can hear them on the stairs!", 6)
		# The door shuts once everyone is in (or the horde will not wait any longer).
		if all_inside() or _clock > 40.0:
			mission.flags.door501 = 0
			mission.flags.horde = 1
			_clock = 0.0
			mission.nav.forget_box(_door_box())
		return
	if phase == 1 and _clock > 8.0:
		mission.flags.horde = 2
		_clock = 0.0
		_make_horde()
		mission.say("Ma'am Teves\n(whispering) That's the east stairs. Don't. Move.", 7)
		return
	if phase == 2:
		_give_away(delta)
		var marching := 0
		for z in horde:
			if is_instance_valid(z) and not z.dead and z.asleep and z.idle_mode == "march": marching += 1
		if (marching == 0 and _clock > 12.0) or _clock > 75.0:
			mission.flags.horde = 3
			_start_sneak()

## What gives the room away while they go past: a light on in it with one of them at the door (it shows under the
## door and round its edges). Shots and running are heard as anywhere (mission `fired`, `sense`). Once they are
## awake and at the door, they force it.
func _give_away(delta: float) -> void:
	var door := w(SCHOOL.DOOR_501)
	var lit := false
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		if int(p.hp) > 0 and bool(p.light) and in_501(p.pos): lit = true
	if lit:
		for z in horde:
			if is_instance_valid(z) and z.asleep and not z.dead and z.position.distance_to(door) < 6.0:
				mission._wake(z)
				print("INTERIOR_COOP_ESCAPE light under the door")
				break
	_force(delta)

func _force(delta: float) -> void:
	if int(mission.flags.get("door501", 0)) != 0: return
	var door := w(SCHOOL.DOOR_501)
	var at_door := 0
	for z in mission.enemies.values():
		if is_instance_valid(z) and not z.asleep and not z.dead and z.hp > 0 and z.position.distance_to(door) < 2.8: at_door += 1
	_force_wait = _force_wait + delta if at_door > 0 else 0.0
	if _force_wait > (1.2 if at_door >= 3 else 3.0):
		mission.flags.door501 = 2
		mission.nav.forget_box(_door_box())
		mission.threat = 3.0
		print("INTERIOR_COOP_ESCAPE 501 forced")

func _door_box() -> AABB:
	return AABB(w(SCHOOL.DOOR_501 + Vector3(-1.1, 0, -1.2)), Vector3(2.2, 2.4, 2.4))

## The horde comes up the east stair (out of sight, on its last flight) and shuffles west along the corridor; each
## stops at its own spot: a few at the west end past 501's door, the rest along the hall, standing, a few wandering
## or feeding. Never under the ceiling's count plus a dozen, whatever was here before.
func _make_horde() -> void:
	if _horde_made: return
	_horde_made = true
	var team_n: int = session.team.size()
	var n := clampi(14 + 3 * team_n, 16, 26)
	n = mini(n, maxi(mission.SCHOOL_CEILING + 12 - mission._alive_count(), 8))
	var y := 4 * H
	var spots: Array = []
	for s: Array in SETTLE_WEST: spots.append(Vector3(float(s[0]), y, SCHOOL.CZ + float(s[1]) * mission.rng.randf_range(.75, 1.0)))
	var x := 10.0
	var side := 1
	while spots.size() < n:
		spots.append(Vector3(x + mission.rng.randf_range(-.4, .4), y, SCHOOL.CZ + side * mission.rng.randf_range(.72, 1.0)))
		side = -side
		x += mission.rng.randf_range(1.7, 2.6)
		if x > 49.5: x = mission.rng.randf_range(10.5, 13.0)
	# (0.66: a few a tick, mission `later`: a figure and its way along the corridor are a few ms each.)
	for i in n:
		mission.later(_horde_one.bind(i, y, spots))
	print("INTERIOR_COOP_ESCAPE horde %d coming" % n)

func _horde_one(i: int, y: float, spots: Array) -> void:
	# (Staggered: a column out of the stair door, a step or two apart.)
	var start := Vector3(mission.rng.randf_range(50.6, 52.3), y + .3, mission.rng.randf_range(525.4, 527.4))
	var z = mission.spawn(mission.ground(w(start)), true, true)
	if z == null: return
	var goal: Vector3 = spots[i % spots.size()]
	z.idle_mode = "march"
	# (Round what is in the corridor, the desks piled at the mechanical room's welded door among them: the nav's
	# way, not a straight line they would pile up against.)
	var path: Array[Vector3] = [w(Vector3(51.5, y, 525.4))]
	var from := w(Vector3(51.0, y, SCHOOL.CZ + mission.rng.randf_range(-.5, .5)))
	path.append(from)
	var way: PackedVector3Array = mission.nav.path(from, w(goal))
	if way.is_empty(): path.append(w(Vector3(goal.x, y, SCHOOL.CZ + (goal.z - SCHOOL.CZ) * .4)))
	else:
		for q in way: path.append(q)
	path.append(w(goal))
	z.march = path
	z.march_i = 0
	z.march_pace = mission.rng.randf_range(.95, 1.25)
	var roll: float = mission.rng.randf()
	z.march_then = "sleep" if roll < .72 else ("wander" if roll < .86 else "feed")
	if goal.x < 6.0: z.march_then = "sleep"
	# (They come up one behind another: the back of the column waits on the stair.)
	z.stun = float(i) * .55
	z.stun_clip = "idle_hurt"
	z.rotation.y = PI * .5
	horde.append(z)

## The pass is over: stage 13, her whispered lines one after another, the door open again.
func _start_sneak() -> void:
	mission.stage = SNEAK
	mission.stage_time = 0.0
	if int(mission.flags.get("door501", 0)) == 0: mission.flags.door501 = 1
	mission.nav.forget_box(_door_box())
	_after = 0
	_after_wait = 0.0
	# The way they came: the mechanical room and the duct, full of them.
	for at in [Vector3(26.0, 4 * H, 532.95), Vector3(31.0, 4 * H, 532.95), Vector3(34.0, 4 * H, 530.2), Vector3(37.2, 4 * H, 528.8)]:
		var z = mission.spawn(mission.ground(w(at)), true, true)
		if z != null:
			z.idle_mode = "feed" if at.x > 33.0 else "sleep"
			z.home = z.position
	print("INTERIOR_COOP_ESCAPE sneak")

func _sneak(delta: float) -> void:
	_force(delta)
	if _after >= 0 and _after < AFTER.size():
		_after_wait -= delta
		if _after_wait <= 0.0:
			var line: Array = AFTER[_after]
			mission.say(str(line[0]) + "\n" + str(line[1]), float(line[2]) + 1.0)
			_after_wait = float(line[2])
			_after += 1
	# The blast: once a survivor of the squad is on the way down the fire escape (below the fourth floor's landing),
	# or anywhere on the fire escape low down if they went back the long way.
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		if int(p.hp) <= 0 or session.is_bot(id): continue
		var l: Vector3 = p.pos - Street.ORIGIN
		if l.x > SCHOOL.FIRE_X0 + .1 and l.z > 520.0 and l.y < 3 * H - 1.0 and l.y > H - 1.0:
			blast()
			return

## Can `id` take the chain off the fifth floor's fire door (inside, at it)?
func at_fire_door(at: Vector3) -> bool:
	var p: Vector3 = at - Street.ORIGIN
	return mission.stage == SNEAK and not bool(mission.flags.get("fire5", false)) and absf(p.y - 4 * H) < 1.0 and p.x > 53.6 and p.x < 55.75 and absf(p.z - SCHOOL.CZ) < 1.5

func unchain() -> void:
	mission.flags.fire5 = true
	mission.nav.forget_box(AABB(w(Vector3(54.6, 4 * H, 522.0)), Vector3(3.2, 2.6, 3.0)))
	mission.say("The chain slides off the push bar. Cold air. The fire escape goes all the way down.", 6)
	print("INTERIOR_COOP_ESCAPE fire door open")

## The kitchen's gas store under room 208 goes up (host): the flags every peer acts on, 208's door off, the gallery
## down (the grand stair buried), and the field filled with what the noise brings.
func blast() -> void:
	if bool(mission.flags.get("blast", false)): return
	mission.flags.blast = true
	mission.flags.fire5 = true
	var i208 := -1
	for i in school.doors.size():
		if school.doors[i].room == "208": i208 = i
	if i208 >= 0:
		mission.flags.broke = int(mission.flags.get("broke", 0)) | (1 << i208)
		mission.flags.pound = int(mission.flags.get("pound", 0)) & ~(1 << i208)
		mission.flags.fired = int(mission.flags.get("fired", 0)) | (1 << i208)
		mission.nav.forget_box(school.door_box(i208))
	school.blast_now()
	mission.nav.forget_box(AABB(w(Vector3(SCHOOL.COLLAPSE[0] - .5, H, 524.5)), Vector3(SCHOOL.COLLAPSE[1] - SCHOOL.COLLAPSE[0] + 1.0, 3.0, 3.0)))
	mission.nav.forget_box(AABB(w(Vector3(5.0, H, 525.0)), Vector3(12.0, 3.2, 10.0)))
	mission.nav.forget_box(AABB(w(Vector3(4.0, 0, 533.5)), Vector3(15.0, 4.0, 14.0)))
	# (0.63: and the second floor's desk wall, thrown down by it.)
	mission.nav.forget_box(AABB(w(Vector3(38.5, H, 521.5)), Vector3(6.0, 3.2, 4.0)))
	mission.stage = DOWN
	mission.stage_time = 0.0
	mission.threat = 3.0
	mission.say("Ma'am Teves\nThe gas! The kitchen's gas store! Hold on to something!", 7)
	# Drawn to the noise and the fire: the field fills, wandering toward the flames.
	var n := clampi(8 + 3 * session.team.size(), 10, 20)
	for j in n:
		var at := Vector3(mission.rng.randf_range(-3.0, 58.0), 0, mission.rng.randf_range(546.0, 590.0))
		# (0.63: not on the rubble ramp down from the lean-to; a few metres out from its foot.)
		if j < n / 3: at = Vector3(mission.rng.randf_range(2.0, 22.0), 0, mission.rng.randf_range(549.0, 558.0))
		var z = mission.spawn(mission.ground(w(at)), true, true)
		if z == null: continue
		var roll: float = mission.rng.randf()
		z.idle_mode = "wander" if roll < .6 else ("feed" if roll < .8 else "sleep")
		z.home = z.position
		z.wander_wait = mission.rng.randf_range(0, 4)
	print("INTERIOR_COOP_ESCAPE blast, field %d" % n)

func _down(_delta: float) -> void:
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		if int(p.hp) <= 0 or session.is_bot(id): continue
		var l: Vector3 = p.pos - Street.ORIGIN
		if not _entered_two and l.x < 55.6 and l.x > 1.0 and absf(l.y - H) < 1.0 and l.z > 514.5 and l.z < 533.5:
			_entered_two = true
			mission.say("Paolo\nMa'am, look: the stairs are gone! There's smoke coming out of 208... the wall's gone, there's a roof under it!", 9)
		# Out through 208's wall: on the lean-to's roof, or down in the field.
		if l.z > 534.2 and l.x > -6.0 and l.x < 62.0:
			_into_field()
			return

func _into_field() -> void:
	mission.stage = FIELD
	mission.stage_time = 0.0
	mission.threat = 3.0
	mission.say("The field. The blast brought them all out here, and they've heard you. The rear gate is at the far end.", 9)
	# The ones near enough to hear it come at once; the rest as they notice.
	var drop := w(Vector3(11.0, 0, 541.0))
	for z in mission.enemies.values():
		if not is_instance_valid(z) or not z.asleep or z.dead: continue
		var l: Vector3 = z.position - Street.ORIGIN
		if l.z < 535.0: continue
		var d: float = z.position.distance_to(drop)
		if d < 38.0: mission._queue_wake(z, .3 + d * .05)
	print("INTERIOR_COOP_ESCAPE field")

## In the field: more come in over the walls and through the gate while the squad crosses; at the gate, the board.
func _field(delta: float, living: Array) -> void:
	if bool(mission.flags.get("board", false)):
		if mission.board_all_ready(): board_done()
		return
	# 0.53: while Heavy-arm is up, fewer come over the walls (his own come when he roars); the gate is shut till his key.
	var gate_open := bool(mission.flags.get("reargate", false))
	var fighting: bool = fight != null and fight.state != "none" and fight.state != "sit" and fight.state != "talk" and fight.state != "dead"
	_field_wait -= delta
	if _field_wait <= 0.0 and not living.is_empty():
		_field_wait = mission.rng.randf_range(2.2, 4.0) * (1.0 if session.team.size() > 1 else 1.3) * (2.2 if fighting else 1.0)
		var hunting := 0
		for z in mission.enemies.values():
			if is_instance_valid(z) and not z.asleep and not z.dead: hunting += 1
		var cap: int = (3 + session.team.size()) if fighting else (8 + 3 * session.team.size())
		if hunting < cap and mission._alive_count() < mission.SCHOOL_CEILING:
			for attempt in 8:
				var at := Vector3()
				var roll: float = mission.rng.randf()
				if roll < .35 or (not gate_open and roll < .5): at = Vector3(-5.2, 0, mission.rng.randf_range(548.0, 596.0))
				elif roll < .7 or not gate_open: at = Vector3(61.2, 0, mission.rng.randf_range(548.0, 596.0))
				else: at = Vector3(SCHOOL.REAR_GATE.x + mission.rng.randf_range(-6.0, 6.0), 0, 603.0 + mission.rng.randf_range(0, 6.0))
				var spot: Vector3 = w(at)
				var close: int = mission.nearest(spot, true)
				if close and spot.distance_to(session.team[close].pos) < 16.0: continue
				var z = mission.spawn(mission.ground(spot), false, true)
				if z != null:
					mission.threat = 3.0
					break
	# Every survivor of the squad on their feet at the gate (or out through it).
	var humans := 0
	var there := 0
	for id: int in session.team:
		if session.is_bot(id): continue
		var p: Dictionary = session.team[id]
		if int(p.hp) <= 0: continue
		humans += 1
		var l: Vector3 = p.pos - Street.ORIGIN
		if l.z > SCHOOL.REAR_GATE.z - 4.5 and absf(l.x - SCHOOL.REAR_GATE.x) < 7.0: there += 1
		elif l.z > SCHOOL.REAR_GATE.z: there += 1
	_gate_time = _gate_time + delta if humans > 0 and there == humans and gate_open else 0.0
	if _gate_time > .6 and not bool(mission.flags.get("board", false)): out()

## Out of the rear gate (host): the chapter's board on every peer, everything behind put away (`clean`).
func out() -> void:
	mission.flags.board = true
	mission.flags.pilcst_out = true
	for id: int in session.team: session.team[id].next_ready = session.is_bot(id)
	for k in mission.enemies.keys():
		var z = mission.enemies[k]
		if is_instance_valid(z): z.queue_free()
		mission.enemies.erase(k)
	mission.drops.clear()
	mission.threat = 0.0
	mission.say("", 0.1)
	print("INTERIOR_COOP_ESCAPE out of the rear gate: %d with the squad" % saved())
	clean()

## How many of the five are with the squad (all of them: the infected never go for them).
func saved() -> int: return people.size()

## Every peer, once: the school, its dead and every corpse of the night put away; only the gate and the street
## beyond stay. (The owner's call: at a chapter's end the mess goes, the dead with it.)
func clean() -> void:
	if _cleaned: return
	_cleaned = true
	var g: Vector3 = w(SCHOOL.REAR_GATE)
	for list in [mission.corpses, mission.victims]:
		for i in range(list.size() - 1, -1, -1):
			var v = list[i]
			if is_instance_valid(v): v.queue_free()
			list.remove_at(i)
	mission._soft_unload(g + Vector3(-60, -20, -12), g + Vector3(220, 45, 270), "pilcst")
	for f in people:
		if is_instance_valid(f) and f.position.distance_to(g) > 30.0: f.position = mission.ground(g + Vector3(randf_range(-2, 2), 0, randf_range(1, 4)))
	if mission.rommel != null: mission.rommel.visible = false
	print("INTERIOR_COOP_ESCAPE cleaned up")

## The board's READY from everyone: on into Outer Street.
func board_done() -> void:
	print("INTERIOR_COOP_ESCAPE pilcst board done -> outer street")
	mission.start_outer_street()

# ---------------------------------------------------------------- the survivors walking (host)

## Who the line follows: the survivor of the squad on their feet nearest Ma'am Teves (a human first).
func _lead() -> int:
	if people.is_empty(): return 0
	var at: Vector3 = people[0].position
	var best := 0
	var near := INF
	for human_first in [true, false]:
		for id: int in session.team:
			var p: Dictionary = session.team[id]
			if int(p.hp) <= 0 or (human_first and session.is_bot(id)): continue
			var d: float = at.distance_squared_to(p.pos)
			if d < near:
				near = d
				best = id
		if best != 0: return best
	return best

func _move_people(delta: float) -> void:
	if people.is_empty(): return
	var stage: int = mission.stage
	if stage == TEVES or stage == HIDE:
		# Teves at the door while she talks, then crouched beside it; the students on the mats, against the wall.
		for i in people.size():
			var f = people[i]
			_settle(f, delta)
			if i == 0:
				f.pose("idle" if stage == TEVES else "idle_hurt")
				if stage == TEVES and session.team.has(talker):
					var to: Vector3 = session.team[talker].pos - f.position
					f.rotation.y = lerp_angle(f.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-4.0 * delta))
			else: f.pose("sit_hurt")
		return
	if stage >= mission.OVER or bool(mission.flags.get("board", false)):
		for f in people:
			_settle(f, delta)
			f.pose("idle")
		return
	var lead := _lead()
	if lead == 0: return
	var ahead: Vector3 = session.team[lead].pos
	var quiet := stage == SNEAK
	for i in people.size():
		var follow: Vector3 = ahead if i == 0 else people[i - 1].position
		_walk(i, follow, 2.0 if i == 0 else 1.25, delta, quiet)

func _settle(f, delta: float) -> void:
	f.velocity.x = 0.0
	f.velocity.z = 0.0
	f.velocity.y = minf(0.0, f.velocity.y) - 16.0 * delta
	f.move_and_slide()

func _walk(i: int, follow: Vector3, gap: float, delta: float, quiet: bool) -> void:
	var f = people[i]
	var st: Dictionary = _paths[i]
	var at: Vector3 = f.position
	var far := at.distance_to(follow)
	var fem := female(i)
	# Lost (well behind, or stuck while the others go on): put back in the line behind the one it follows.
	if far > 30.0 or (float(st.stalled) > 6.0 and far > 3.5):
		var back: Vector3 = (at - follow)
		back.y = 0.0
		var spot: Vector3 = mission.ground(follow + (back.normalized() if back.length() > .1 else Vector3.BACK) * 1.2)
		if spot.is_finite():
			f.position = spot
			f.velocity = Vector3.ZERO
			f.reset_physics_interpolation()
		st.stalled = 0.0
		st.path = PackedVector3Array()
		return
	# 0.59: room for the squad and each other: they stood inside whoever they caught up with (0.2-0.8 m off the
	# player after a stop), the camera in a student's head.
	var crowd := _crowd(i, at)
	if far < gap and absf(follow.y - at.y) < 1.3:
		if crowd.length() > .2:
			var out := crowd.normalized() * minf(1.6, .6 + crowd.length() * 2.0)
			f.velocity.x = out.x
			f.velocity.z = out.z
			f.velocity.y = minf(0.0, f.velocity.y) - 16.0 * delta
			f.move_and_slide()
			f.pose("crouch_walk" if quiet else ("fem_walk" if fem else "walk"))
			st.stalled = 0.0
			return
		_settle(f, delta)
		f.pose("idle_hurt")
		var to: Vector3 = follow - at
		if to.length() > .3: f.rotation.y = lerp_angle(f.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-3.0 * delta))
		st.stalled = 0.0
		return
	var aim: Vector3 = mission.outer_street.steer(at, follow, mission.flags) if (mission.stage >= 16 and mission.outer_street != null) else school.steer(at, follow)
	if mission.stage < 16 and school.carry(f, aim, delta):
		f.pose("walk")
		st.stalled = 0.0
		return
	var crawl: bool = mission.stage < 16 and school.squeeze(f)
	var step := aim
	var space: PhysicsDirectSpaceState3D = mission.get_world_3d().direct_space_state
	var straight: bool = space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * .5, aim + Vector3.UP * .5, 2)).is_empty()
	st.wait = float(st.wait) - delta
	if straight or Vector2(aim.x - at.x, aim.z - at.z).length() < 1.0:
		st.path = PackedVector3Array()
	else:
		if (st.path.is_empty() or float(st.wait) <= 0.0 or (st.goal as Vector3).distance_to(aim) > 1.5) and float(st.wait) <= 0.0:
			st.path = mission.nav.path(at, aim)
			st.goal = aim
			st.wait = .8
		var path: PackedVector3Array = st.path
		while not path.is_empty() and Vector2(path[0].x - at.x, path[0].z - at.z).length() < .45: path.remove_at(0)
		st.path = path
		if not path.is_empty(): step = path[0]
	var dir := Vector3(step.x - at.x, 0, step.z - at.z).normalized()
	if crowd.length() > .05: dir = (dir + crowd * 1.5).normalized()
	var pace := 1.15 if quiet else (2.3 if far < 7.0 else 4.0)
	if crawl: pace = .7
	f.velocity.x = dir.x * pace
	f.velocity.z = dir.z * pace
	f.velocity.y = minf(0.0, f.velocity.y) - 16.0 * delta
	f.move_and_slide()
	if dir.length() > .1: f.rotation.y = lerp_angle(f.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-9.0 * delta))
	var moved := Vector2(f.position.x - (st.last as Vector3).x, f.position.z - (st.last as Vector3).z).length()
	st.stalled = float(st.stalled) + delta if moved < pace * delta * .25 else maxf(0.0, float(st.stalled) - delta)
	st.last = f.position
	if crawl: f.pose("crawl")
	elif quiet: f.pose("crouch_walk")
	elif pace > 3.0: f.pose("fem_run" if fem else "run")
	else: f.pose("fem_walk" if fem else "walk")

## 0.59: which way survivor `i` at `at` steps to keep out of the squad (1.1 m, strongly) and the other survivors
## (0.75 m, gently), stronger the closer; zero when nobody is that close (on the same floor).
func _crowd(i: int, at: Vector3) -> Vector3:
	var push := Vector3.ZERO
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		if int(p.hp) <= 0: continue
		push += _away(at, p.pos, 1.1) * 2.0
	# (Weaker among themselves: hemmed in between a player and a student, the two cancelled and Teves stayed put.)
	for j in people.size():
		if j != i and is_instance_valid(people[j]): push += _away(at, people[j].position, .75) * .4
	return push

func _away(at: Vector3, other: Vector3, room: float) -> Vector3:
	if absf(other.y - at.y) > 1.3: return Vector3.ZERO
	var off := Vector3(at.x - other.x, 0, at.z - other.z)
	var d := off.length()
	if d >= room: return Vector3.ZERO
	if d < .01: off = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	return off.normalized() * (1.0 - d / room)

# ---------------------------------------------------------------- every peer

func render(delta: float) -> void:
	if school == null: return
	var flags: Dictionary = mission.flags
	if bool(flags.get("survivors", false)): _ensure_people()
	# (0.55: a debug jump past them: what was heard back then is not heard again on arrival. mission `_settle`.)
	var settled: int = int(flags.get("settled", -1))
	if settled >= HIDE:
		_heard["bed"] = true
		_heard["crash"] = true
	if settled >= SNEAK: _heard["chain"] = true
	if settled >= DOWN: _heard["blast"] = true
	var phase: int = int(flags.get("horde", 0))
	var viewer: Vector3 = session.main.player.global_position if session.main.get("player") != null else Street.ORIGIN
	if phase >= 1 and not _heard.has("bed"):
		_heard["bed"] = true
		# Far off at first, under everything: a crowd on the stairs, coming up.
		_bed = AudioStreamPlayer3D.new()
		_bed.stream = load("res://assets/audio/siege/groan_b.ogg")
		_bed.unit_size = 4.0
		_bed.max_distance = 70.0
		_bed.volume_db = -30.0
		add_child(_bed)
		_bed.global_position = w(Vector3(53.0, 3 * H + 1.0, 530.0))
		_bed.play()
		_bed.finished.connect(func(): if is_instance_valid(_bed) and int(mission.flags.get("horde", 0)) < 3: _bed.play())
	if _bed != null and is_instance_valid(_bed):
		_bed.volume_db = move_toward(_bed.volume_db, -6.0 if phase == 1 else (-12.0 if phase == 2 else -60.0), delta * 4.0)
		if phase >= 3 and _bed.volume_db < -55.0:
			_bed.queue_free()
			_bed = null
	if phase >= 2 and not _heard.has("crash"):
		_heard["crash"] = true
		for path in ["res://assets/audio/siege/bang_d.ogg", "res://assets/audio/siege/rattle.ogg", "res://assets/audio/siege/scrape.ogg"]:
			_one(path, w(Vector3(52.9, 4 * H - .8, 529.0)), 2.0, 12.0)
	# The horde's own voices as it goes by (each peer picks its own: nobody needs the same groan).
	if phase == 2 or phase == 3:
		_groan_wait -= delta
		if _groan_wait <= 0.0:
			_groan_wait = randf_range(.6, 1.6)
			var near: Array = []
			for z in mission.enemies.values():
				if is_instance_valid(z) and not z.dead and z.position.distance_to(viewer) < 22.0: near.append(z)
			if not near.is_empty():
				var z = near.pick_random()
				z.sound(InteriorZombie._stream("groan_%d" % (1 + randi() % 4)), randf_range(-16.0, -9.0))
	if bool(flags.get("fire5", false)) and not _heard.has("chain"):
		_heard["chain"] = true
		_one("res://assets/audio/sfx/lock_turn.ogg", w(SCHOOL.FIRE_DOOR_5), -2.0, 6.0)
		_one("res://assets/audio/sfx/impactMetal_light_001.ogg", w(SCHOOL.FIRE_DOOR_5), -6.0, 6.0)
	if bool(flags.get("blast", false)) and not _heard.has("blast"):
		_heard["blast"] = true
		var at := w(Vector3(11.0, 1.0, 537.0))
		_one("res://assets/grenade/grenade_explosion1.ogg", at, 8.0, 30.0)
		_one("res://assets/grenade/bomb_explosion.mp3", at, 6.0, 60.0)
		_one("res://assets/audio/siege/bang_c.ogg", w(Vector3(28.0, H + 2.0, 526.0)), 4.0, 20.0)
		if session.main.get("player") != null:
			var d: float = viewer.distance_to(at)
			session.main.player.jolt(clampf(.32 - d * .004, .1, .3))
	if bool(flags.get("pilcst_out", false)): clean()
	if fight != null: fight.render(delta)

func _one(path: String, at: Vector3, volume: float, unit: float) -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = load(path)
	a.unit_size = unit
	a.max_distance = unit * 10.0
	a.volume_db = volume
	add_child(a)
	a.global_position = at
	a.play()
	a.finished.connect(a.queue_free)

## For the snapshot: where each of them is, which way they face, what they are doing.
func state() -> Array:
	var out: Array = []
	for f in people: out.append([f.position, f.rotation.y, f.anim_name])
	return out

func apply(data: Array) -> void:
	if data.is_empty(): return
	_ensure_people()
	for i in mini(data.size(), people.size()):
		var v: Array = data[i]
		var f = people[i]
		f.replicated = true
		f.follow(v[0], v[1])
		f.pose(v[2])

# ---------------------------------------------------------------- debug

## Forward one stage as play would leave it (mission.debug_complete).
func debug_step() -> void:
	match mission.stage:
		TEVES:
			talk_index = TALK.size()
			_start_hide()
		HIDE:
			mission.flags.door501 = 0
			mission.flags.horde = 2
			_make_horde()
			mission.flush_later()
			# Straight to where they stop.
			for z in horde:
				if not is_instance_valid(z) or z.march.is_empty(): continue
				z.position = mission.ground(z.march[z.march.size() - 1])
				z.march_i = z.march.size()
				z.stun = 0.0
			mission.flags.horde = 3
			_start_sneak()
			_after = AFTER.size()
		SNEAK:
			if not bool(mission.flags.get("fire5", false)): unchain()
			blast()
		DOWN:
			_into_field()
		FIELD:
			# 0.53: Heavy-arm down, his key taken, the gate unlocked; then out as before.
			fight.debug_finish()
			out()

## Debug: the survivors put with the squad standing at `at` (world): on the spots behind them (0.55: mission
## `squad_spots`, the squad's own first; a straight line behind used to run off a landing's edge or into a wall).
func debug_place(at: Vector3, yaw: float) -> void:
	_ensure_people()
	var squad: int = session.team.size()
	var spots: Array = mission.squad_spots(at, yaw, squad + people.size() + 8)
	# (A step or two off, as they stand when following, not at the host's shoulder: the far spots first.)
	var far: Array = []
	var near: Array = []
	for j in range(squad, spots.size()):
		var s: Vector3 = spots[j]
		if s.distance_to(spots[0]) >= 1.4 and not far.has(s): far.append(s)
		elif not near.has(s): near.append(s)
	spots = far + near
	while spots.size() < people.size(): spots.append(at)
	for i in people.size():
		var spot: Vector3 = spots[i]
		people[i].position = spot
		people[i].velocity = Vector3.ZERO
		people[i].reset_physics_interpolation()
		var st: Dictionary = _paths[i]
		st.path = PackedVector3Array()
		st.stalled = 0.0
		st.last = spot
