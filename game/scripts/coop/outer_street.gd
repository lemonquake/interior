class_name OuterStreet
extends "res://scripts/coop/outer_dread.gd"
## 0.63: Outer Street, the chapter past PILCST's rear gate (mission stages 16 and 17; 18 WON). Owner's brief
## (2026-11-24): "tons of objectives, unique pathways, a broken bus where the players can enter then exit to the other
## door, a broken subway with flickering lights and all those creepy horror vibes" (references: work/Reference/Outer
## Street). Built on every peer at the chapter board after Heavy-arm (session.gd's loading steps), never before.
## 0.65: the bus and the train are models (tools/blender/vehicles), and the chapter runs on past the long stair
## through Market Row (outer_row.gd) to the long bridge.
##
## The way (outer_world.gd and outer_row.gd lay it down):
##   lane -> avenue under the elevated highway -> the pile-up: a span of the highway down across the road, the only
##   way through a city bus wedged along the west lane (in at its back door, along the aisle, out at the front) ->
##   the plaza: the road north buried under the next span; the subway's shutter chained -> bolt cutters from the
##   hardware store on the hillside terrace (up the yellow-railed stair, or round by the covered overpass; what was
##   shut in its back room comes out) -> cut the chain, down the well -> the station dead: the power room, the main
##   breaker (the lights come back flickering, the faregates open, and what was down on the platform comes up) ->
##   the platform; the stalled train fills the tunnel past it: in at its one forced door, through both cars, out of
##   the cab's front door onto the track -> the tunnel to the emergency exit, the long stair up -> the river road,
##   buried past the pizza place -> Airah's Pizzahan, the neon court, the flats, the red-stair alley -> Nichols Davao
##   Mart (a table dragged under the broken escalator, the climb) -> through the wall into Azrin & Azrael, down and out
##   of its window -> stage 17: the long bridge with everything on the row behind them.
##
## Host: `host_tick` (progress from where the squad is, the infected as each part is reached, the table, the finale,
## the win), `take_cutters` / `cut_chain` / `power_on` (from mission.interact). Every peer: `sync`, `steer`.

const START_Z := 600.0
## The objectives, in order: the flag that marks one done, and its line (the HUD's objective).
const STEPS := [
	["outer_avenue", "Out of the lane and onto the avenue."],
	["outer_pileup", "The highway came down across the avenue. The only way through is the bus: in at the back door, out at the front."],
	["outer_shutter_seen", "The road north is buried. Get down into the subway."],
	["outer_cutters", "The subway's shutter is chained. Find something to cut the chain: try the hardware store up the yellow stairs."],
	["outer_shutter", "Cut the chain on the subway's shutter."],
	["outer_power", "The station is dead. Find its power room and switch the power back on."],
	["outer_platform", "The faregates are open. Down to the platform."],
	["outer_train", "The train fills the tunnel. Go through it, car to car, and out at the front."],
	["outer_exit", "Follow the tunnel to the emergency exit."],
	["outer_up", "Up the emergency stairs."],
	["outer_pizza", "The road east is buried. Go through Airah's Pizzahan."],
	["outer_court", "Over the counter, and out by the kitchen's back door."],
	["outer_alley", "Through the flats across the court."],
	["outer_mart", "Into Nichols Davao Mart by its loading door."],
	["outer_table", "The way up is the broken escalator. Drag a table under its end."],
	["outer_upstairs", "Climb onto the table and jump for the escalator."],
	["outer_boutique", "The top floor's east wall is down. Through it, into Azrin & Azrael."],
	["outer_out", "Down through the boutique and out of its broken window."],
]
## The row's flags in order (reaching one counts the ones before it).
const ROW := ["outer_up", "outer_pizza", "outer_court", "outer_alley", "outer_mart", "outer_table", "outer_upstairs", "outer_boutique", "outer_out"]
const FINALE := "Everything on the row heard you. Across the bridge, everyone."
const PROMPTS := {"outer_cutters": "E  •  Take the bolt cutters", "outer_chain": "E  •  Cut the chain",
	"outer_chained": "Chained and padlocked. Bolt cutters would cut it.", "outer_power": "E  •  Throw the main breaker"}
## The food court's tables (kind, street-local foot, yaw): none of them starts under the escalator's end.
const TABLES := [["long", Vector3(47.4, .15, 770.6), .1], ["long", Vector3(57.6, .15, 772.4), 1.45], ["square", Vector3(47.6, .15, 777.4), 0.0], ["square", Vector3(58.4, .15, 775.6), .4]]
## The row's dead (street-local foot, kind (mission.INFECTED), yaw, clip, how far into it, the push as they go limp).
const DEAD := [
	[Vector3(21.6, .15, 784.6), 0, 1.2, "death_fwd", .9, Vector3(0, 0, 40)],
	[Vector3(26.2, .15, 772.6), 10, -.4, "death_crumple", .9, Vector3.ZERO],
	[Vector3(25.0, .15, 768.4), 4, 2.6, "death_back", .95, Vector3(0, 0, -60)],
	[Vector3(35.6, .15, 760.4), 3, PI * .5, "devour", .55, Vector3(200, 0, 0)],
	[Vector3(60.0, .15, 756.0), 1, -1.0, "death_fwd", .3, Vector3(300, 40, 0)],
	[Vector3(52.2, 4.15, 742.4), 4, .3, "death_crumple", .9, Vector3.ZERO],
	[Vector3(49.6, 4.15, 742.8), 3, -2.2, "death_back", .95, Vector3(0, 0, 60)],
	[Vector3(57.0, 4.15, 741.9), 5, 2.0, "death_fwd", .9, Vector3(0, 0, -40)],
	[Vector3(49.6, .15, 780.8), 13, PI, "death_back", .95, Vector3(0, 0, -80)],
	[Vector3(52.6, .15, 772.0), 1, .7, "death_fwd", .9, Vector3.ZERO],
	[Vector3(58.0, .15, 762.6), 2, -PI * .5, "death_crumple", .9, Vector3.ZERO],
	[Vector3(61.0, 4.55, 780.2), 6, 1.5, "death_fwd", .9, Vector3(0, 0, 50)],
	[Vector3(69.2, .15, 771.2), 5, 0.0, "death_crumple", .9, Vector3.ZERO],
	[Vector3(91.0, .15, 771.4), 0, -1.2, "death_back", .9, Vector3.ZERO],
	[Vector3(92.0, 2.0, 852.0), 14, .4, "death_fwd", .9, Vector3(0, 0, 80)],
	[Vector3(95.6, 2.0, 1012.0), 11, 2.8, "death_back", .95, Vector3.ZERO],
]

var built_usec := 0
var _shutter_at := 0.0
var _cutters_done := false
var _power_seen := false
var _thump_wait := 2.0
var _rock_t := 0.0
## Host.
var _zones_done := {}
var _waves: Array = []
var _finale_t := 0.0

func build(street: Node3D) -> void:
	var t0 := Time.get_ticks_usec()
	s = street
	name = "OuterStreet"
	rng.seed = int(s.get("seed_value") if s.get("seed_value") != null else 508) * 61 + 6301
	make_roots(ROOT_NAMES + ROW_NAMES)
	under = [R_STATION, R_TUNNEL]
	ground()
	lane()
	avenue()
	viaduct()
	pileup()
	plaza()
	yellow_stair()
	terrace()
	overpass()
	entrance()
	concourse()
	power_room()
	platform()
	train()
	tunnel()
	long_stair()
	riverside()
	build_row()
	dread()
	backdrop()
	_make_areas()
	commit(300.0, 140.0, [R_SKY, R_BRIDGE], 1800.0)
	built_usec = Time.get_ticks_usec() - t0
	print("INTERIOR_COOP_OUTER_STREET built in %d ms (%d lamps)" % [int(built_usec / 1000), lamps.size()])

## (every peer, after `build`) The row's loose tables (into the street's synced tables, in the same order
## everywhere) and its dead (posed, let go limp).
func after_build(m) -> void:
	for spec: Array in TABLES: row_table(str(spec[0]), spec[1], float(spec[2]))
	var Fig = load("res://scripts/coop/figure.gd")
	for i in DEAD.size():
		var spec: Array = DEAD[i]
		var v = Fig.new()
		m.add_child(v)
		v.key = -300 - i
		v.session = m.session
		v.setup("res://assets/characters/zombies/z_%s.glb" % m.INFECTED[int(spec[1])], world(spec[0]), "", true)
		v.rotation.y = float(spec[2])
		var clip: String = spec[3]
		v.clips.play(clip)
		v.clips.seek(v.clips.get_animation(clip).length * float(spec[4]), true)
		v.go_limp(spec[5] as Vector3)
		quiet_shadows(v)
		m.victims.append(v)
	# 0.67: the first half's dead (outer_dread.gd).
	dread_dead(m)

# ---------------------------------------------------------------- objectives and the E key

func objective(flags: Dictionary, stage: int) -> String:
	if stage >= 17: return FINALE
	for st: Array in STEPS:
		if not bool(flags.get(st[0], false)): return st[1]
	return STEPS[STEPS.size() - 1][1]

func candidate(at_w: Vector3, flags: Dictionary) -> String:
	var p := local(at_w)
	if not bool(flags.get("outer_cutters", false)) and p.distance_to(CUTTERS) < 1.8: return "outer_cutters"
	if not bool(flags.get("outer_shutter", false)) and p.y > -.6 and p.z < SHUTTER.z and Vector2(p.x - SHUTTER.x, p.z - (SHUTTER.z - .8)).length() < 2.2:
		return "outer_chain" if bool(flags.get("outer_cutters", false)) else "outer_chained"
	if bool(flags.get("outer_shutter", false)) and not bool(flags.get("outer_power", false)) and p.distance_to(PANEL + Vector3(-.5, 0, 0)) < 1.7:
		return "outer_power"
	return ""

## (host) Off the counter: and the back room's door gives; what was shut in there comes out.
func take_cutters(m) -> void:
	if bool(m.flags.get("outer_cutters", false)): return
	m.flags.outer_cutters = true
	m.threat = 3.0
	m.nav.forget_box(AABB(world(Vector3(-2.8, TERRACE_Y, 683.4)), Vector3(1.8, 3.0, 2.8)))
	var n := clampi(3 + m.session.team.size(), 4, 7)
	for i in n:
		var at := Vector3(rng.randf_range(BACK_ROOM[0], BACK_ROOM[1]), TERRACE_Y, rng.randf_range(BACK_ROOM[2], BACK_ROOM[3]))
		_spawn(m, at, "awake")
	print("INTERIOR_COOP_OUTER cutters taken, back room %d" % n)

## (host) The chain cut: the shutter rolls up; the station below is waking.
func cut_chain(m) -> void:
	if bool(m.flags.get("outer_shutter", false)) or not bool(m.flags.get("outer_cutters", false)): return
	m.flags.outer_shutter = true
	m.flags.outer_shutter_seen = true
	m.nav.forget_box(AABB(world(Vector3(30.4, -6.0, 669.5)), Vector3(5.2, 7.0, 14.0)))
	print("INTERIOR_COOP_OUTER shutter open")

## (host) The main breaker: the lights come back (flickering), the faregates open, the platform comes up the stair.
func power_on(m) -> void:
	if bool(m.flags.get("outer_power", false)) or not bool(m.flags.get("outer_shutter", false)): return
	m.flags.outer_power = true
	m.threat = 3.0
	m.nav.forget_box(AABB(world(Vector3(23.5, CON_Y - .5, 696.0)), Vector3(17.0, 3.0, 2.0)))
	var n := clampi(5 + m.session.team.size(), 6, 10)
	for i in n:
		_spawn(m, Vector3(rng.randf_range(26.0, 32.0), PLAT_Y, rng.randf_range(714.0, 731.0)), "awake")
	print("INTERIOR_COOP_OUTER power on, %d up from the platform" % n)

# ---------------------------------------------------------------- the host's night

func _flag(m, key: String) -> void:
	if bool(m.flags.get(key, false)): return
	m.flags[key] = true
	print("INTERIOR_COOP_OUTER ", key)

## A row flag, and every one before it (someone got ahead of the others, or round).
func _row(m, key: String) -> void:
	var i := ROW.find(key)
	for k in i + 1: _flag(m, ROW[k])

func host_tick(m, delta: float, living: Array) -> void:
	var humans: Array = []
	var anyone: Array = []
	for id: int in living:
		var lp := local(m.session.team[id].pos)
		anyone.append(lp)
		if not m.session.is_bot(id): humans.append(lp)
	var who: Array = humans if not humans.is_empty() else anyone
	for lp: Vector3 in who:
		if lp.z > 616.0 and lp.z < 760.0: _flag(m, "outer_avenue")
		if lp.z > 663.0 and lp.z < 705.0 and lp.y > -1.0 and lp.x > 22.0 and lp.x < 70.0:
			_flag(m, "outer_avenue")
			_flag(m, "outer_pileup")
		if lp.y > -1.0 and lp.z < SHUTTER.z and Vector2(lp.x - SHUTTER.x, lp.z - SHUTTER.z).length() < 5.0: _flag(m, "outer_shutter_seen")
		if lp.y < -8.5 and lp.z < 734.0 and lp.x < 33.2: _flag(m, "outer_platform")
		if lp.y < -9.0 and lp.z > 751.5: _flag(m, "outer_train")
		if lp.y < -8.0 and lp.x < 32.9 and lp.z > 779.5 and lp.z < 784.5: _flag(m, "outer_exit")
		if m.stage != 16: continue
		if lp.y > -1.0 and lp.z > 776.0 and lp.z < 810.0 and lp.x < 16.0: _row(m, "outer_up")
		if lp.x > 17.2 and lp.x < 31.0 and lp.z > 771.2 and lp.z < 777.4 and lp.y > -1.0 and lp.y < 3.0: _row(m, "outer_pizza")
		if lp.x > 17.0 and lp.x < 31.0 and lp.z > 757.0 and lp.z < 770.9 and lp.y > -1.0 and lp.y < 6.0: _row(m, "outer_court")
		if lp.x > 39.1 and lp.x < 67.0 and lp.z > 748.0 and lp.z < 760.0 and lp.y > -1.0: _row(m, "outer_alley")
		if lp.x > 39.0 and lp.x < 67.0 and lp.z > 760.3 and lp.z < 786.0 and lp.y > -1.0 and lp.y < 3.5: _row(m, "outer_mart")
		if lp.x > 39.0 and lp.x < 67.0 and lp.z > 760.0 and lp.z < 786.0 and lp.y > 4.0: _row(m, "outer_upstairs")
		if lp.x > 67.2 and lp.x < 79.0 and lp.z > 770.0 and lp.z < 786.0 and lp.y > 4.0: _row(m, "outer_boutique")
		if lp.x > 40.0 and lp.z > 786.3 and lp.z < 810.0 and lp.y > -1.0 and lp.y < 3.0:
			_row(m, "outer_out")
			_finale(m)
	# 0.67: the bags, the train's lights, the stair's dark; the kiosk's seal (outer_dread.gd).
	dread_host(m, who)
	if m.stage == 16: _check_table(m)
	for zn: Dictionary in _zones():
		if _zones_done.has(zn.id): continue
		if zn.has("gate") and not bool(m.flags.get(zn.gate, false)): continue
		var hit := false
		for lp: Vector3 in anyone:
			for t: Vector3 in zn.at:
				if lp.distance_to(t) < float(zn.r): hit = true
		if not hit: continue
		_zones_done[zn.id] = true
		# (0.66: a few a tick: mission `later`.)
		for z: Array in zn.z:
			var at: Vector3 = z[0]
			var kind: String = z[1]
			m.later(func() -> void: _spawn(m, at, kind))
		for d: Array in zn.d: _drop(m, d[0], d[1])
		print("INTERIOR_COOP_OUTER zone %s: %d" % [zn.id, zn.z.size()])
	if m.stage == 17:
		_finale_t += delta
		while not _waves.is_empty() and _finale_t >= float(_waves[0]):
			_waves.pop_front()
			_horde(m, clampi(4 + 2 * m.session.team.size(), 6, 12))
		var past := 0
		for lp: Vector3 in who:
			if lp.z > GOAL_Z and lp.x > GOAL_X0 and lp.x < GOAL_X1 and lp.y > 1.0: past += 1
		if not who.is_empty() and past == who.size(): m._win_outer_street()

## (host) A food-court table brought under the broken escalator's end (anywhere near it, at rest or let go, even
## knocked on its side by the drag): it slides into place there, upright (TABLE_SPOT), and stays for good (frozen, a
## step of the fixed world on every peer: `sync`); the way up is open.
func _check_table(m) -> void:
	if m.flags.has("outer_table_at"): return
	for i: int in row_tables:
		if i >= s.tables.size(): continue
		var t: RigidBody3D = s.tables[i]
		var p := local(t.global_position)
		if p.x < float(TABLE_ZONE[0]) or p.x > float(TABLE_ZONE[1]) or p.z < float(TABLE_ZONE[2]) or p.z > float(TABLE_ZONE[3]): continue
		if p.y > 1.2: continue
		var held := false
		for id: int in m.draggers.keys():
			if int(m.draggers[id][0]) == i: held = true
		# (Held: it counts once it is right under the end, or the dragger stops; let go: once it is slow.)
		var under := absf(p.x - TABLE_SPOT.x) < 1.0 and p.z > TABLE_SPOT.z - 1.4
		if held and not under and t.linear_velocity.length() > .25: continue
		if not held and t.linear_velocity.length() > 1.5: continue
		for id: int in m.draggers.keys():
			if int(m.draggers[id][0]) == i: m.release(id)
		t.linear_velocity = Vector3.ZERO
		t.angular_velocity = Vector3.ZERO
		t.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		t.freeze = true
		var goal := Transform3D(Basis.IDENTITY, world(TABLE_SPOT))
		var slide := t.create_tween()
		slide.tween_property(t, "global_transform", goal, .45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		m.flags.outer_table_at = [i, TABLE_SPOT.x, TABLE_SPOT.y, TABLE_SPOT.z, 0.0]
		_row(m, "outer_table")
		print("INTERIOR_COOP_OUTER table set under the escalator (brought to %s)" % str(p.snapped(Vector3.ONE * .01)))
		return

## (host) Out of the boutique onto the road: everything on the row comes after them; the bridge.
func _finale(m) -> void:
	_row(m, "outer_out")
	m.stage = 17
	m.stage_time = 0.0
	m.threat = 3.0
	_finale_t = 0.0
	_waves = [14.0, 30.0, 48.0, 66.0]
	_horde(m, clampi(8 + 3 * m.session.team.size(), 10, 20))
	print("INTERIOR_COOP_OUTER finale")

func _horde(m, n: int) -> void:
	for i in n:
		_spawn(m, Vector3(rng.randf_range(40.5, 48.0), 0, rng.randf_range(789.0, 801.0)), "awake")

func _spawn(m, at: Vector3, kind: String) -> void:
	var wp: Vector3 = m.ground(world(at) + Vector3.UP * .3)
	if not wp.is_finite(): wp = world(at)
	var z = m.spawn(wp, kind != "awake")
	if z == null: return
	if kind == "awake":
		z.asleep = false
		return
	z.idle_mode = kind
	z.home = z.position
	z.rotation.y = rng.randf_range(-PI, PI)
	z.wander_wait = rng.randf_range(0, 4)

func _drop(m, at: Vector3, kind: String) -> void:
	var dp: Vector3 = m.ground(world(at) + Vector3.UP * .3)
	if not dp.is_finite(): dp = world(at)
	m.next_drop += 1
	match kind:
		"gun":
			var wid := InteriorArsenal.pick(rng)
			var mag := int(InteriorArsenal.stats(wid).get("mag", 12))
			m.drops[m.next_drop] = [dp, "weapon:" + wid, [mag, true, mag * 2]]
		"kit": m.drops[m.next_drop] = [dp, "healthkit:medium"]
		_: m.drops[m.next_drop] = [dp, "ammo:large"]

## Where the infected are, woken as each part of the way is reached ("at": any of the squad within `r`).
func _zones() -> Array:
	return [
		{"id": "avenue", "at": [Vector3(44, 0, 606)], "r": 10.0, "z": [[Vector3(38.5, 0, 626.0), "sleep"], [Vector3(53.5, 0, 631.0), "wander"], [Vector3(33.5, .15, 637.0), "feed"], [Vector3(58.0, .15, 642.0), "sleep"], [Vector3(46.0, 0, 644.6), "wander"]],
			"d": [[Vector3(33.8, .15, 623.0), "ammo"], [Vector3(58.6, .15, 633.0), "kit"]]},
		{"id": "bus", "at": [Vector3(40.3, 0, 648.0)], "r": 6.0, "z": [[Vector3(38.0, .4, 656.6), "sleep"], [Vector3(38.0, .4, 658.8), "sleep"]], "d": [[Vector3(38.0, .4, 654.2), "ammo"]]},
		{"id": "plaza", "at": [Vector3(40.3, 0, 663.0)], "r": 6.0, "z": [[Vector3(30.0, .15, 690.8), "wander"], [Vector3(49.0, 0, 683.0), "wander"], [Vector3(58.5, .15, 693.0), "sleep"], [Vector3(26.5, .15, 699.0), "feed"], [Vector3(43.0, 0, 699.5), "sleep"], [Vector3(61.5, .15, 676.0), "wander"]],
			"d": [[Vector3(24.2, .15, 684.6), "ammo"], [Vector3(63.0, .15, 669.5), "gun"], [Vector3(52.9, 0, 686.2), "kit"]]},
		{"id": "terrace", "at": [Vector3(17.0, 5, 667.0), Vector3(22.0, 5.6, 690.0), Vector3(63.0, 5.6, 688.0)], "r": 7.0,
			"z": [[Vector3(11.5, 5, 677.0), "feed"], [Vector3(13.0, 5, 692.0), "wander"], [Vector3(9.0, 5, 701.0), "sleep"], [Vector3(38.0, 5.6, 690.0), "sleep"], [Vector3(55.0, 5.6, 689.5), "wander"]],
			"d": [[Vector3(10.6, 5.78, 671.4), "kit"], [Vector3(15.0, 5, 702.0), "ammo"]]},
		{"id": "concourse", "at": [Vector3(33.0, -2.0, 676.0)], "r": 5.0, "gate": "outer_shutter", "z": [[Vector3(24.0, -5.2, 695.0), "sleep"], [Vector3(38.0, -5.2, 690.0), "feed"], [Vector3(44.0, -5.2, 693.0), "sleep"], [Vector3(30.0, -5.2, 688.5), "wander"]],
			"d": [[Vector3(52.0, -5.2, 689.0), "kit"], [Vector3(21.0, -5.2, 694.0), "ammo"]]},
		{"id": "platform", "at": [Vector3(29.5, -8.0, 707.0)], "r": 5.0, "z": [[Vector3(27.5, -10.2, 724.0), "sleep"], [Vector3(31.0, -10.2, 731.0), "feed"], [Vector3(27.0, -10.2, 692.5), "sleep"]], "d": [[Vector3(26.4, -10.2, 716.0), "ammo"]]},
		{"id": "train", "at": [Vector3(32.4, -10.2, OPEN_DOOR)], "r": 4.0, "z": [[Vector3(34.6, -10.1, 740.0), "sleep"], [Vector3(34.6, -10.1, 745.6), "sleep"], [Vector3(34.6, -10.1, 736.4), "wander"]], "d": [[Vector3(34.6, -10.1, 728.6), "ammo"]]},
		{"id": "tunnel", "at": [Vector3(34.6, BED_Y, 754.0)], "r": 4.5, "z": [[Vector3(34.8, BED_Y, 766.0), "wander"], [Vector3(34.2, BED_Y, 774.0), "sleep"], [Vector3(35.4, BED_Y, 789.0), "feed"]], "d": [[Vector3(31.6, BED_Y, 782.6), "kit"]]},
		{"id": "river_w", "at": [Vector3(6.5, 0, 788.0)], "r": 6.0, "z": [[Vector3(-4.0, 0, 795.0), "wander"], [Vector3(12.0, 0, 799.0), "wander"], [Vector3(26.0, 0, 796.0), "feed"], [Vector3(19.0, .15, 787.6), "sleep"]], "d": [[Vector3(8.5, 0, 800.5), "ammo"]]},
		{"id": "pizza", "at": [PIZZA_DOOR + Vector3(0, 0, 1.4)], "r": 4.0, "z": [[Vector3(20.6, G0, 781.8), "feed"], [Vector3(27.6, G0, 784.6), "sleep"], [Vector3(24.8, G0, 772.2), "feed"], [Vector3(28.8, G0, 773.2), "sleep"]], "d": [[Vector3(20.4, G0, 776.4), "kit"]]},
		{"id": "court", "at": [PIZZA_BACK + Vector3(0, 0, -1.6)], "r": 3.5, "z": [[Vector3(26.0, G0, 760.0), "wander"], [Vector3(20.0, G0, 765.0), "sleep"], [Vector3(28.6, G0, 769.4), "feed"]], "d": []},
		{"id": "flats", "at": [FLATS_IN + Vector3(1.6, 0, 0)], "r": 3.5, "z": [[Vector3(35.6, G0, 772.0), "sleep"], [Vector3(34.6, G0, 782.0), "sleep"], [Vector3(36.0, G0, 753.4), "wander"]], "d": [[Vector3(37.0, G0, 769.0), "ammo"]]},
		{"id": "alley", "at": [FLATS_OUT + Vector3(1.6, 0, 0)], "r": 4.0, "z": [[Vector3(48.0, G0, 755.0), "wander"], [Vector3(56.0, G0, 757.0), "feed"], [Vector3(63.0, G0, 753.0), "sleep"], [Vector3(52.0, G0, 751.0), "sleep"]], "d": [[Vector3(64.0, G0, 750.0), "ammo"]]},
		{"id": "eatery", "at": [Vector3(55.6, 4.15, 749.0)], "r": 3.5, "z": [[Vector3(52.0, 4.15, 742.0), "feed"], [Vector3(48.6, 4.15, 739.6), "feed"], [Vector3(58.0, 4.15, 738.0), "sleep"]],
			"d": [[Vector3(53.0, 4.95, 740.6), "gun"], [Vector3(48.6, 4.95, 744.0), "ammo"], [Vector3(58.0, 4.95, 736.4), "kit"]]},
		{"id": "mart", "at": [LOADING + Vector3(0, 0, 1.6)], "r": 5.0, "z": [[Vector3(48.0, G0, 774.0), "wander"], [Vector3(55.0, G0, 776.0), "sleep"], [Vector3(44.0, G0, 778.0), "feed"], [Vector3(52.0, G0, 782.6), "sleep"], [Vector3(63.6, G0, 768.0), "sleep"], [Vector3(47.0, G0, 766.6), "wander"]],
			"d": [[Vector3(64.0, G0, 769.0), "kit"], [Vector3(53.0, G0, 780.0), "ammo"], [Vector3(40.6, G0, 762.0), "ammo"]]},
		{"id": "mart2", "at": [ESC_TOP + Vector3(0, 0, 1.2)], "r": 4.0, "z": [[Vector3(55.0, F1, 783.0), "sleep"], [Vector3(64.0, F1, 777.0), "feed"], [Vector3(48.0, F1, 763.0), "wander"], [Vector3(41.0, F1, 774.0), "sleep"]], "d": [[Vector3(41.0, F1, 770.0), "ammo"]]},
		{"id": "bout", "at": [BREACH + Vector3(1.6, 0, 0)], "r": 4.0, "z": [[Vector3(76.0, F1, 781.0), "sleep"], [Vector3(70.4, G0, 780.0), "sleep"], [Vector3(75.0, G0, 772.4), "wander"]], "d": [[Vector3(68.1, G0 + 1.05, 776.0), "kit"]]},
		{"id": "funeral", "at": [FUNERAL_DOOR + Vector3(0, 0, 1.0)], "r": 5.0, "z": [[Vector3(86.0, G0, 781.0), "sleep"], [Vector3(93.6, G0, 783.0), "sleep"], [Vector3(90.0, G0, 772.0), "feed"]],
			"d": [[Vector3(85.5, G0, 775.0), "kit"], [Vector3(95.6, G0, 771.2), "kit"], [Vector3(88.0, G0, 784.6), "ammo"]]},
		{"id": "bridge_a", "at": [Vector3(94.0, 2.0, 816.0)], "r": 6.0, "gate": "outer_out", "z": [[Vector3(91.0, 2.0, 852.0), "feed"], [Vector3(97.0, 2.0, 866.0), "wander"], [Vector3(92.0, 2.0, 884.0), "feed"], [Vector3(96.0, 2.0, 840.0), "sleep"]], "d": [[Vector3(89.4, 2.15, 850.0), "ammo"]]},
		{"id": "bridge_b", "at": [Vector3(94.0, 2.0, 880.0)], "r": 7.0, "gate": "outer_out", "z": [[Vector3(92.0, 2.0, 912.0), "wander"], [Vector3(97.0, 2.0, 920.0), "feed"], [Vector3(91.0, 2.0, 952.0), "feed"], [Vector3(92.6, 2.0, 940.0), "sleep"], [Vector3(96.0, 2.0, 965.0), "wander"]], "d": [[Vector3(89.4, 2.15, 935.0), "kit"]]},
		{"id": "bridge_c", "at": [Vector3(94.0, 2.0, 960.0)], "r": 7.0, "gate": "outer_out", "z": [[Vector3(92.0, 2.0, 1000.0), "feed"], [Vector3(97.0, 2.0, 1010.0), "wander"], [Vector3(91.0, 2.0, 1026.0), "feed"], [Vector3(96.0, 2.0, 1040.0), "sleep"], [Vector3(93.0, 2.0, 1055.0), "wander"]], "d": [[Vector3(98.6, 2.15, 1000.0), "ammo"]]},
	]

## (host, debug) The chapter done as play would do it: every objective's flag, then the finale.
func debug_finish(m) -> void:
	for st: Array in STEPS:
		if st[0] != "outer_out": m.flags[st[0]] = true
	for k in ["avenue", "bus", "plaza", "terrace", "concourse", "platform", "train", "tunnel", "river_w", "pizza", "court", "flats", "alley", "eatery", "mart", "mart2", "bout"]: _zones_done[k] = true
	if m.stage == 16 or (m.stage == 17 and _waves.is_empty() and _finale_t == 0.0): _finale(m)

## (host, debug) A jump into the chapter: the flags up to there set, and the parts behind counted as reached.
func debug_settle(m, upto: Array) -> void:
	for k: String in upto: m.flags[k] = true
	var behind := {"outer_pileup": ["avenue", "bus"], "outer_shutter_seen": ["plaza"], "outer_cutters": ["terrace"], "outer_power": ["concourse"], "outer_platform": ["platform"], "outer_train": ["train"], "outer_exit": ["tunnel"],
		"outer_pizza": ["river_w"], "outer_court": ["pizza"], "outer_alley": ["court", "flats"], "outer_mart": ["alley"], "outer_upstairs": ["mart"], "outer_boutique": ["mart2"], "outer_out": ["bout"]}
	for k: String in upto:
		for zid: String in behind.get(k, []): _zones_done[zid] = true
	dread_settle(m, upto)

# ---------------------------------------------------------------- every peer

func sync(flags: Dictionary, delta: float, viewer := Vector3.INF) -> void:
	_lamps_tick(flags)
	dread_sync(flags, delta, viewer)
	if bool(flags.get("outer_shutter", false)) and _shutter_at < 1.0:
		if _shutter_at == 0.0:
			chain.visible = false
			for c in shutter_body.get_children():
				if c is CollisionShape3D: (c as CollisionShape3D).disabled = true
			sound(world(SHUTTER + Vector3.UP), "res://assets/audio/siege/rattle.ogg", 2.0, 8.0)
			sound(world(SHUTTER + Vector3.UP * .3), "res://assets/audio/sfx/impactMetal_light_001.ogg", -2.0, 6.0)
		_shutter_at = move_toward(_shutter_at, 1.0, delta / 2.4)
		shutter_curtain.scale.y = lerpf(1.0, .05, _shutter_at)
	if bool(flags.get("outer_cutters", false)) and not _cutters_done:
		_cutters_done = true
		if cutters != null: cutters.visible = false
		cutters_glint["gate"] = "outer_never"
		back_door.collision_layer = 0
		back_door.rotation.y = -1.75
		back_door.position.x += .1
		sound(world(back_door.position), "res://assets/audio/siege/bang_c.ogg", 4.0, 9.0)
		sound(world(back_door.position), "res://assets/audio/zombies/scream_2.ogg", 0.0, 9.0)
	if bool(flags.get("outer_power", false)) and not _power_seen:
		_power_seen = true
		flaps.visible = false
		flaps_shape.disabled = true
		lever.rotation.z = .5
		sound(world(PANEL + Vector3.UP * 1.3), "res://assets/audio/nichols/switch_click.ogg", 4.0, 6.0)
		sound(world(Vector3(34.0, -3.0, 696.0)), "res://assets/audio/nichols/arc_buzz.ogg", 4.0, 20.0)
		sound(world(Vector3(29.5, -7.0, 715.0)), "res://assets/audio/siege/bang_d.ogg", 2.0, 20.0)
		hum(R_STATION, Vector3(34.0, -2.0, 692.0), "res://assets/audio/nichols/bulb_hum.ogg", -18.0, 10.0)
		hum(R_STATION, Vector3(29.0, -6.5, 720.0), "res://assets/audio/nichols/arc_buzz.ogg", -20.0, 6.0)
	# The table under the escalator: once set, a step of the fixed world here too (the climb needs one).
	if table_step == null and flags.has("outer_table_at"):
		var a: Array = flags.outer_table_at
		var i := int(a[0])
		if i >= 0 and i < s.tables.size():
			var t: RigidBody3D = s.tables[i]
			t.set_meta("locked", true)
			var half: Vector3 = t.get_meta("half", Vector3(1.0, .4, .4))
			table_step = StaticBody3D.new()
			table_step.name = "Table under the escalator"
			table_step.collision_layer = 2
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(half.x * 2.0, .76, half.z * 2.0)
			cs.shape = bs
			cs.position = Vector3.UP * .38
			table_step.add_child(cs)
			table_step.transform = Transform3D(Basis(Vector3.UP, float(a[4])), Vector3(float(a[1]), float(a[2]), float(a[3])))
			roots[R_MART].add_child(table_step)
			sound(world(Vector3(float(a[1]), 1.0, float(a[3]))), "res://assets/audio/sfx/impactMetal_light_001.ogg", -4.0, 6.0)
	if not viewer.is_finite(): return
	var v := local(viewer)
	_view(v)
	# Behind the hardware store's back door, until it gives: something throwing itself at it.
	if not _cutters_done and v.distance_to(Vector3(-2.0, TERRACE_Y + 1.0, 684.8)) < 16.0:
		_thump_wait -= delta
		if _thump_wait <= 0.0:
			_thump_wait = rng.randf_range(2.5, 6.5)
			sound(world(Vector3(-2.3, TERRACE_Y + 1.1, 684.8)), ["res://assets/audio/siege/bang_a.ogg", "res://assets/audio/siege/bang_b.ogg", "res://assets/audio/siege/groan_a.ogg"][rng.randi() % 3], -9.0, 4.0)
	# The row's knocking (a boarded door, the flat at the back, a casket) and the rocking chair, near them.
	for th: Array in thumps:
		var at: Vector3 = th[0]
		if v.distance_to(at) > float(th[1]): continue
		th[2] = float(th[2]) - delta
		if float(th[2]) <= 0.0:
			th[2] = rng.randf_range(3.0, 8.0)
			sound(world(at), ["res://assets/audio/siege/bang_a.ogg", "res://assets/audio/siege/bang_b.ogg", "res://assets/audio/siege/groan_a.ogg"][rng.randi() % 3], -10.0, 4.0)
	_rock_t += delta
	for rc: Array in rocking:
		var n: Node3D = rc[0]
		if not is_instance_valid(n) or v.distance_to(n.position) > 12.0: continue
		var base: Vector3 = rc[1]
		n.rotation = base + Vector3(sin(_rock_t * 1.7) * .09, 0, 0)

## Only what can be seen from where the viewer is: under the street the street goes (and the reverse), except at the
## two ways between them (the entrance's well, the exit kiosk at the top of the long stair).
func _view(v: Vector3) -> void:
	var deep := v.y < -1.5
	var at_well := v.x > 24.0 and v.x < 42.0 and v.z > 662.0 and v.z < 693.0 and v.y > -6.0
	var at_kiosk := v.x < 22.0 and v.z > 770.0 and v.z < 792.0
	var vis := []
	vis.resize(roots.size())
	vis.fill(false)
	if deep:
		vis[R_STATION] = v.z < 735.0 or at_well
		vis[R_TUNNEL] = true
		vis[R_PLAZA] = at_well
		vis[R_SKY] = at_well or at_kiosk
		vis[R_RIVER] = at_kiosk
		vis[R_ROW] = at_kiosk
	else:
		vis[R_SKY] = true
		vis[R_SOUTH] = v.z < 735.0
		vis[R_PILEUP] = v.z < 745.0
		vis[R_PLAZA] = v.z < 770.0
		vis[R_HILL] = v.z < 770.0
		vis[R_RIVER] = v.z > 735.0
		vis[R_STATION] = at_well
		vis[R_TUNNEL] = at_kiosk or (v.z > 735.0 and v.x < 30.0 and v.z < 800.0)
		vis[R_ROW] = v.z > 728.0
		vis[R_MART] = v.z > 728.0
		vis[R_BOUT] = v.z > 740.0
		vis[R_BRIDGE] = v.z > 760.0
	# (0.67: what was put away behind the kiosk's door stays away.)
	for g: int in gone: vis[g] = false
	for i in roots.size():
		if roots[i].visible != vis[i]: roots[i].visible = vis[i]

# ---------------------------------------------------------------- the way, for the infected, the bots and the students

## Areas (street-local boxes, first match wins) and the ways between them (points from one to the other, a flag
## that must be set for the way to be open). `steer` returns where to head next: the target itself in the same
## area, else the next point on the first way toward its area.
var areas: Array = []
var links: Array = []
var _hops := {}
const GATES := ["outer_shutter", "outer_power", "outer_table"]

func _box(lo: Vector3, hi: Vector3) -> AABB: return AABB(lo, hi - lo)

func _make_areas() -> void:
	areas = [
		["bus", [_box(Vector3(36.6, -.5, 649.45), Vector3(39.1, 3.0, 661.55))]],
		["well", [_box(Vector3(30.5, -5.8, 671.2), Vector3(35.5, .8, 682.6))]],
		["train", [_box(Vector3(33.1, -10.6, 712.9), Vector3(36.1, -6.9, 751.1))]],
		["long", [_box(Vector3(9.3, -11.6, 780.6), Vector3(14.5, 1.0, 783.4)), _box(Vector3(14.5, -11.6, 780.6), Vector3(30.4, -1.5, 783.4))]],
		["overpass", [_box(Vector3(17.5, 4.6, 688.2), Vector3(63.05, 8.0, 691.8)), _box(Vector3(62.9, 4.6, 683.9), Vector3(67.1, 8.0, 692.1))]],
		["terrace", [_box(Vector3(-8.5, 3.5, 661.5), Vector3(22.3, 10.0, 706.5)), _box(Vector3(15.0, 2.0, 665.0), Vector3(22.0, 6.0, 669.0))]],
		["platform", [_box(Vector3(24.6, -11.0, 687.6), Vector3(33.1, -6.5, 733.6)), _box(Vector3(27.4, -10.6, 699.9), Vector3(31.6, -5.0, 711.2))]],
		["concourse", [_box(Vector3(19.6, -6.0, 682.6), Vector3(56.4, -1.0, 712.4))]],
		["tunnel", [_box(Vector3(32.6, -12.0, 751.0), Vector3(37.0, -6.5, 796.0)), _box(Vector3(30.3, -12.0, 780.2), Vector3(33.1, -8.5, 783.8))]],
		["avenue", [_box(Vector3(28.0, -1.0, 596.0), Vector3(64.0, 6.0, 649.45)), _box(Vector3(39.1, -1.0, 649.4), Vector3(41.25, 6.0, 653.6))]],
		["plaza", [_box(Vector3(22.0, -1.0, 661.55), Vector3(70.0, 4.0, 704.0)), _box(Vector3(39.1, -1.0, 658.6), Vector3(41.25, 4.0, 661.6)), _box(Vector3(67.0, -1.0, 680.0), Vector3(80.0, 4.0, 694.0)), _box(Vector3(62.0, -1.0, 672.4), Vector3(67.5, 6.2, 684.2))]],
		["pizza_din", [_box(Vector3(17.2, -.5, 777.7), Vector3(31.0, 3.6, 786.2))]],
		["pizza_kit", [_box(Vector3(17.2, -.5, 771.2), Vector3(31.0, 3.6, 777.7))]],
		["court", [_box(Vector3(17.0, -.5, 757.0), Vector3(31.0, 6.0, 771.2))]],
		["flats", [_box(Vector3(31.0, -.5, 748.0), Vector3(39.0, 3.4, 786.0))]],
		["eatery", [_box(Vector3(45.0, 3.5, 734.0), Vector3(61.0, 7.5, 748.0))]],
		["alley", [_box(Vector3(39.0, -.5, 748.0), Vector3(67.0, 6.0, 760.0))]],
		["mart_back", [_box(Vector3(39.0, -.5, 760.0), Vector3(67.0, 3.5, 764.0))]],
		["mart_2f", [_box(Vector3(39.0, 3.8, 760.0), Vector3(67.0, 9.0, 786.0))]],
		["mart_gf", [_box(Vector3(39.0, -.5, 764.0), Vector3(67.0, 3.8, 786.0))]],
		["bout_2f", [_box(Vector3(67.0, 3.8, 770.0), Vector3(79.0, 9.0, 786.0))]],
		["bout_gf", [_box(Vector3(67.0, -.5, 770.0), Vector3(79.0, 3.8, 786.0))]],
		["funeral", [_box(Vector3(83.0, -.5, 770.0), Vector3(97.0, 4.0, 786.0))]],
		["bridge", [_box(Vector3(88.0, 1.0, 812.0), Vector3(100.0, 9.0, 1100.0))]],
		["river_w", [_box(Vector3(-14.0, -1.0, 778.6), Vector3(31.0, 8.0, 808.0))]],
		["river_e", [_box(Vector3(39.5, -1.0, 786.0), Vector3(106.0, 8.0, 812.0))]],
	]
	var i := func(n: String) -> int:
		for k in areas.size():
			if areas[k][0] == n: return k
		return -1
	var bf := BUS_O.z + BUS_DOORS[0]
	var ff := BUS_O.z + BUS_DOORS[1]
	links = [
		{"a": i.call("avenue"), "b": i.call("bus"), "pts": [Vector3(40.3, 0, 648.6), Vector3(40.3, 0, bf), Vector3(38.0, BUS_FLOOR, bf)], "gate": ""},
		{"a": i.call("bus"), "b": i.call("plaza"), "pts": [Vector3(38.0, BUS_FLOOR, ff - .8), Vector3(38.3, BUS_FLOOR, ff), Vector3(40.3, 0, ff), Vector3(40.3, 0, 663.6)], "gate": ""},
		{"a": i.call("plaza"), "b": i.call("terrace"), "pts": [Vector3(28.6, .15, 667.0), Vector3(27.0, .4, 667.0), Vector3(16.0, 4.8, 667.0), Vector3(13.5, TERRACE_Y, 667.0)], "gate": ""},
		{"a": i.call("terrace"), "b": i.call("overpass"), "pts": [Vector3(16.4, TERRACE_Y, 690.0), Vector3(18.5, 5.15, 690.0), Vector3(23.0, OVP_Y, 690.0)], "gate": ""},
		{"a": i.call("overpass"), "b": i.call("plaza"), "pts": [Vector3(62.0, OVP_Y, 690.0), Vector3(65.0, OVP_Y, 687.0), Vector3(65.0, OVP_Y, 684.6), Vector3(65.0, .15, 672.2), Vector3(65.0, .15, 670.5)], "gate": ""},
		{"a": i.call("plaza"), "b": i.call("well"), "pts": [Vector3(33.0, .15, 669.8), Vector3(33.0, .15, 672.2)], "gate": "outer_shutter"},
		{"a": i.call("well"), "b": i.call("concourse"), "pts": [Vector3(33.0, CON_Y, 681.8), Vector3(33.0, CON_Y, 684.4)], "gate": ""},
		{"a": i.call("concourse"), "b": i.call("platform"), "pts": [Vector3(33.0, CON_Y, 693.5), Vector3(32.0, CON_Y, 698.6), Vector3(29.5, CON_Y, 699.6), Vector3(29.5, PLAT_Y, 711.4), Vector3(29.5, PLAT_Y, 713.0)], "gate": "outer_power"},
		{"a": i.call("platform"), "b": i.call("train"), "pts": [Vector3(31.6, PLAT_Y, OPEN_DOOR), Vector3(33.9, TRAIN_FLOOR, OPEN_DOOR), Vector3(34.6, TRAIN_FLOOR, OPEN_DOOR + .6)], "gate": ""},
		{"a": i.call("train"), "b": i.call("tunnel"), "pts": [Vector3(34.6, TRAIN_FLOOR, 748.2), Vector3(34.6, TRAIN_FLOOR, 750.6), Vector3(34.6, BED_Y, 753.6), Vector3(34.6, BED_Y, 755.0)], "gate": ""},
		{"a": i.call("tunnel"), "b": i.call("long"), "pts": [Vector3(34.4, BED_Y, EXIT_Z), Vector3(31.6, BED_Y, EXIT_Z), Vector3(29.8, BED_Y + .3, EXIT_Z)], "gate": ""},
		{"a": i.call("long"), "b": i.call("river_w"), "pts": [Vector3(29.9, BED_Y, EXIT_Z), Vector3(9.6, 0, EXIT_Z), Vector3(6.5, 0, 783.5), Vector3(6.5, 0, 787.6)], "gate": ""},
		{"a": i.call("river_w"), "b": i.call("pizza_din"), "pts": [PIZZA_DOOR + Vector3(0, -G0, 3.6), PIZZA_DOOR + Vector3(0, 0, .8), PIZZA_DOOR + Vector3(0, 0, -1.0)], "gate": ""},
		{"a": i.call("pizza_din"), "b": i.call("pizza_kit"), "pts": [Vector3(PIZZA_DOOR.x, G0, 779.4), Vector3(PIZZA_DOOR.x, G0, 778.3), Vector3(PIZZA_DOOR.x, G0, 776.6)], "gate": ""},
		{"a": i.call("pizza_kit"), "b": i.call("court"), "pts": [PIZZA_BACK + Vector3(0, 0, 1.6), PIZZA_BACK, PIZZA_BACK + Vector3(0, 0, -1.6)], "gate": ""},
		{"a": i.call("court"), "b": i.call("flats"), "pts": [FLATS_IN + Vector3(-1.4, 0, 0), FLATS_IN, FLATS_IN + Vector3(1.6, 0, -.6)], "gate": ""},
		{"a": i.call("flats"), "b": i.call("alley"), "pts": [FLATS_OUT + Vector3(-2.4, 0, 0), FLATS_OUT, FLATS_OUT + Vector3(1.6, 0, 0)], "gate": ""},
		{"a": i.call("alley"), "b": i.call("eatery"), "pts": [Vector3(45.4, G0, 749.0), Vector3(46.4, G0, 749.0), Vector3(53.4, 4.15, 749.0), Vector3(55.6, 4.15, 749.2), Vector3(55.6, 4.15, 747.2)], "gate": ""},
		{"a": i.call("alley"), "b": i.call("mart_back"), "pts": [LOADING + Vector3(0, 0, -1.4), LOADING, LOADING + Vector3(-1.2, 0, 1.8)], "gate": ""},
		{"a": i.call("mart_back"), "b": i.call("mart_gf"), "pts": [STOCK_DOOR + Vector3(0, 0, -1.4), STOCK_DOOR, STOCK_DOOR + Vector3(0, 0, 1.6)], "gate": ""},
		{"a": i.call("mart_gf"), "b": i.call("mart_2f"), "pts": [Vector3(ESC_BREAK.x, G0, 772.6), Vector3(ESC_BREAK.x, .91, 774.3), Vector3(ESC_BREAK.x, ESC_BREAK.y, ESC_BREAK.z + .3), ESC_TOP + Vector3(0, 0, .2), ESC_TOP + Vector3(0, 0, 1.4)], "gate": "outer_table"},
		{"a": i.call("mart_2f"), "b": i.call("bout_2f"), "pts": [Vector3(61.6, F1, 774.8), Vector3(65.8, F1, BREACH.z), BREACH, BREACH + Vector3(1.6, 0, 0)], "gate": ""},
		{"a": i.call("bout_2f"), "b": i.call("bout_gf"), "pts": [BOUT_STAIR_TOP + Vector3(-1.4, 0, -.9), BOUT_STAIR_TOP + Vector3(0, 0, -.7), BOUT_STAIR_TOP, BOUT_STAIR_FOOT, BOUT_STAIR_FOOT + Vector3(-.8, 0, 1.2)], "gate": ""},
		{"a": i.call("bout_gf"), "b": i.call("river_e"), "pts": [BOUT_WINDOW + Vector3(0, 0, -1.6), BOUT_WINDOW, BOUT_WINDOW + Vector3(0, 0, 1.8)], "gate": ""},
		{"a": i.call("river_e"), "b": i.call("funeral"), "pts": [FUNERAL_DOOR + Vector3(0, 0, 1.8), FUNERAL_DOOR, FUNERAL_DOOR + Vector3(0, 0, -1.6)], "gate": ""},
		{"a": i.call("river_e"), "b": i.call("bridge"), "pts": [Vector3(94.0, 0, 798.0), Vector3(94.0, 2.0, 814.0), Vector3(94.0, 2.0, 816.0)], "gate": ""},
	]

func area_of(p: Vector3) -> int:
	for k in areas.size():
		for b: AABB in areas[k][1]:
			if b.has_point(p): return k
	return -1

func steer(from_w: Vector3, to_w: Vector3, flags: Dictionary) -> Vector3:
	if areas.is_empty(): return to_w
	var f := local(from_w)
	var t := local(to_w)
	var fa := area_of(f)
	var ta := area_of(t)
	if fa < 0 or ta < 0 or fa == ta: return to_w
	var gates := 0
	for g in GATES.size():
		if bool(flags.get(GATES[g], false)): gates |= 1 << g
	var key := (fa * 64 + ta) * 8 + gates
	if not _hops.has(key): _hops[key] = _first_hop(fa, ta, gates)
	var hop: Vector2i = _hops[key]
	if hop.x < 0: return to_w
	var pts: Array = links[hop.x].pts
	if hop.y == 0:
		pts = pts.duplicate()
		pts.reverse()
	return world(_along(f, pts))

## The first way to take from area `fa` toward `ta` (breadth first over the open ways): (link, 1 forward / 0 back).
func _first_hop(fa: int, ta: int, gates: int) -> Vector2i:
	var came := {fa: Vector2i(-1, -1)}
	var queue: Array = [fa]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		if at == ta: break
		for li in links.size():
			var ln: Dictionary = links[li]
			var g: String = ln.gate
			if g != "" and gates & (1 << GATES.find(g)) == 0: continue
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

# ---------------------------------------------------------------- review

## Views for tests/v63_views.gd: [name, eye, aim (street-local), flags set before it].
func review_views() -> Array:
	return [
		["o01_lane_from_gate", Vector3(44.0, 1.7, 601.6), Vector3(44.5, 3.0, 630.0)],
		["o02_avenue", Vector3(39.5, 1.7, 617.0), Vector3(45.0, 4.5, 652.0)],
		["o03_pileup", Vector3(44.0, 1.7, 637.0), Vector3(42.0, 2.2, 655.0)],
		["o04_bus_rear_door", Vector3(40.5, 1.7, 647.8), Vector3(38.4, 1.3, 652.6)],
		["o05_bus_aisle", Vector3(38.0, 2.0, 652.4), Vector3(38.0, 1.3, 661.2)],
		["o06_bus_front_door", Vector3(37.9, 2.0, 658.4), Vector3(40.4, 1.0, 661.8)],
		["o07_plaza", Vector3(40.6, 1.7, 664.6), Vector3(34.0, 2.2, 688.0)],
		["o08_shutter", Vector3(33.0, 1.8, 667.6), Vector3(33.0, 1.1, 671.6)],
		["o09_yellow_stair", Vector3(30.5, 1.8, 667.0), Vector3(15.0, 5.8, 667.0)],
		["o10_terrace", Vector3(18.0, 6.7, 676.0), Vector3(8.0, 5.8, 670.5)],
		["o11_hardware", Vector3(4.6, 6.7, 686.9), Vector3(.6, 5.9, 684.0)],
		["o12_overpass", Vector3(23.5, 7.3, 690.0), Vector3(60.0, 6.8, 690.0)],
		["o13_plaza_from_above", Vector3(41.0, 7.3, 688.9), Vector3(41.0, 0.0, 668.0)],
		["o14_concourse_dark", Vector3(33.0, -3.4, 684.2), Vector3(32.0, -4.6, 700.0), {"outer_shutter": true, "outer_cutters": true}],
		["o15_power_room", Vector3(49.4, -3.6, 690.6), Vector3(55.5, -4.0, 686.6)],
		["o16_concourse_lit", Vector3(33.0, -3.4, 684.2), Vector3(32.0, -4.6, 700.0), {"outer_power": true}],
		["o17_platform", Vector3(29.0, -8.6, 712.6), Vector3(31.2, -9.0, 730.0)],
		["o18_train_door", Vector3(30.6, -8.6, 719.2), Vector3(34.4, -9.0, 722.6)],
		["o19_train_inside", Vector3(34.6, -8.6, 723.8), Vector3(34.6, -8.9, 749.0)],
		["o20_tunnel", Vector3(34.8, -9.7, 753.6), Vector3(34.6, -9.9, 786.0)],
		["o21_long_stair", Vector3(29.8, -9.6, 782.0), Vector3(10.0, -1.0, 782.0)],
		["o22_riverside", Vector3(8.0, 1.7, 789.2), Vector3(30.0, 2.4, 792.0)],
		["r01_pile_and_pizzahan", Vector3(6.0, 1.7, 795.0), Vector3(26.0, 2.6, 786.0)],
		["r02_pizzahan_front", Vector3(23.0, 1.7, 792.0), Vector3(23.0, 2.6, 786.0)],
		["r03_pizzahan_dining", Vector3(23.0, 1.75, 785.2), Vector3(23.0, 1.0, 777.6)],
		["r04_pizzahan_counter", Vector3(22.0, 1.75, 780.0), Vector3(23.0, .8, 775.0)],
		["r05_pizzahan_kitchen", Vector3(22.2, 1.75, 776.4), Vector3(27.6, 1.2, 772.4)],
		["r06_court", Vector3(22.1, 1.7, 770.0), Vector3(29.0, 3.4, 762.0)],
		["r07_court_up", Vector3(24.0, 1.6, 764.0), Vector3(24.5, 13.6, 765.0)],
		["r08_flats_hall", Vector3(31.8, 1.75, 763.0), Vector3(38.0, 1.4, 756.0)],
		["r09_flats_living", Vector3(34.0, 1.75, 766.8), Vector3(36.0, 1.0, 775.0)],
		["r10_flats_children", Vector3(35.6, 1.75, 777.0), Vector3(32.0, 1.0, 783.0)],
		["r11_alley", Vector3(40.6, 1.7, 755.4), Vector3(56.0, 3.0, 752.0)],
		["r12_red_stair", Vector3(44.0, 1.7, 756.0), Vector3(53.0, 4.0, 749.0)],
		["r13_eatery", Vector3(55.6, 5.9, 747.2), Vector3(52.0, 4.8, 740.0)],
		["r14_loading_door", Vector3(56.0, 1.7, 754.0), Vector3(58.25, 1.4, 760.0)],
		["r15_mart_atrium", Vector3(53.2, 1.75, 766.2), Vector3(52.0, 4.0, 778.0)],
		["r16_escalator_break", Vector3(47.6, 1.75, 771.6), Vector3(50.0, 2.0, 776.0)],
		["r17_mart_up", Vector3(53.0, 1.6, 773.0), Vector3(53.0, 11.0, 773.5)],
		["r18_mart_aisles", Vector3(42.85, 1.6, 765.0), Vector3(42.6, 1.0, 778.0)],
		["r19_mart_gallery", Vector3(50.0, 6.3, 781.0), Vector3(58.0, 4.0, 770.0)],
		["r20_breach", Vector3(61.0, 6.3, 775.0), Vector3(68.0, 5.4, 774.5)],
		["r21_boutique_top", Vector3(68.6, 6.3, 774.5), Vector3(75.0, 5.4, 774.5)],
		["r22_boutique_ground", Vector3(78.0, 3.0, 778.6), Vector3(74.0, .9, 784.0)],
		["r23_boutique_window", Vector3(76.0, 1.7, 791.0), Vector3(73.0, 3.0, 786.0)],
		["r24_funeral", Vector3(91.3, 1.75, 785.0), Vector3(90.0, 1.0, 777.0)],
		["r25_bridge", Vector3(94.0, 3.7, 816.0), Vector3(94.0, 4.0, 880.0)],
		["r26_bridge_gap", Vector3(92.0, 3.7, 918.0), Vector3(94.0, 2.0, 950.0)],
		["r27_bridge_far", Vector3(94.0, 3.7, 1040.0), Vector3(94.0, 3.0, 1080.0)],
		["r28_row_aerial", Vector3(60.0, 40.0, 830.0), Vector3(55.0, 0.0, 770.0)],
		# 0.67: outer_dread.gd (the flags last: the kiosk's seal puts the first half away).
		["d01_triage", Vector3(46.5, 1.7, 676.0), Vector3(53.0, .6, 682.0)],
		["d02_triage_bags", Vector3(52.9, 1.7, 676.6), Vector3(51.6, .4, 680.6)],
		["d03_floodlight", Vector3(40.0, 1.7, 673.5), Vector3(49.0, .6, 686.0)],
		["d04_triage_from_shutter", Vector3(33.0, 1.8, 669.0), Vector3(50.0, 1.0, 683.0)],
		["d05_faregate_dead", Vector3(33.0, -3.6, 692.0), Vector3(34.6, -5.2, 696.0), {"outer_power": false}],
		["d06_power_room_dead", Vector3(50.0, -3.6, 689.0), Vector3(55.0, -5.0, 683.8)],
		["d07_track_worker", Vector3(34.6, -9.7, 764.6), Vector3(35.2, -11.0, 769.8)],
		["d08_long_stair_lit", Vector3(27.0, -7.6, 782.0), Vector3(12.0, -1.0, 782.0)],
		["d09_triage_split", Vector3(52.9, 1.7, 676.6), Vector3(51.6, .4, 680.6), {"outer_bags": true}],
		["d10_train_dark", Vector3(34.6, -8.6, 729.0), Vector3(34.6, -8.9, 749.0), {"outer_power": true, "outer_train_dark": true}],
		["d11_long_stair_dark", Vector3(27.0, -7.6, 782.0), Vector3(12.0, -1.0, 782.0), {"outer_stair_dark": true}],
		["d12_kiosk_open", Vector3(9.5, 1.7, 791.0), Vector3(6.5, 1.0, 785.4)],
		["d13_kiosk_shut", Vector3(9.5, 1.7, 791.0), Vector3(6.5, 1.0, 785.4), {"outer_up": true, "outer_kiosk_shut": true}],
	]
