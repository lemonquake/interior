extends "res://scripts/coop/outer_row.gd"
## 0.67: Outer Street's first half made worse (owner, 2026-11-26: "intensive improvements on the Outer Streets level by
## adding more details and more performance and more horror"). Layered over the built chapter (outer_street.gd
## extends this; outer_world.gd and outer_row.gd lay the chapter down):
##  - the plaza's triage point: a rescue tent the night overran on the east carriageway, cots, body bags in a row, a
##    floodlight knocked over and still burning across the road. Two of the bags on the cots move; when the squad
##    comes close they split and what was zipped in them gets up (host `outer_bags`).
##  - the dead along the first half (posed and let go limp, as the row's are): the avenue, the shutter, the triage
##    point, the overpass, the terrace, the faregates, the power room, the platform, the track worker in the tunnel
##    with his lantern still on, the long stair.
##  - the train: the second car's tubes die as the squad reaches the gangway (host `outer_train_dark`), and something
##    comes out of the cab end through the dark.
##  - the long stair: halfway up, its lights die (host `outer_stair_dark`), the steel door at its foot bangs open
##    below, and what was in the tunnel comes up after them.
##  - sounds where nobody can see their cause yet (each peer, once): a can rolling across the dark concourse, a groan
##    behind you in the power room, a scream across the plaza from the overpass, something hitting the train's windows
##    from inside, metal scraping at the tunnel's far end.
##  - the seal (the NOW standard): once every survivor is out on the river road, the kiosk's steel door slams shut
##    behind them (host `outer_kiosk_shut`; what came up the stair after them beats on it), and on every peer the
##    avenue, the pile-up, the plaza, the hillside, the station, the train and the tunnel are put away: hidden,
##    processing off, their dead and infected freed, their meshes let go of a little each frame (mission
##    `_unload_tick`).

const TRIAGE := Vector3(52.7, 0, 682.1)
## A body bag's pieces: [centre, size, material] (the head and feet showing through, the zip along the top).
const BAG_PIECES := [[Vector3(0, .1, 0), Vector3(1.82, .2, .58), "#1b1f24"], [Vector3(.7, .2, 0), Vector3(.34, .12, .4), "#1b1f24"],
	[Vector3(-.12, .19, 0), Vector3(.9, .1, .46), "#1b1f24"], [Vector3(-.78, .16, 0), Vector3(.26, .12, .36), "#1b1f24"],
	[Vector3(0, .262, .08), Vector3(1.7, .012, .02), "#6a6e70"]]
## The cots (street-local z, along x at 51.0); the first two carry the bags that move.
const COTS := [678.5, 680.3, 683.2, 685.2]
## The roots put away behind the kiosk's door.
const BEHIND := [0, 1, 2, 3, 4, 5]
## What the squad keeps once the kiosk is shut (street-local): the river road, Market Row, the long bridge.
const KEEP_LO := Vector3(-20, -1.4, 733.0)
const KEEP_HI := Vector3(125, 82, 1200.0)
## The first half's dead (street-local foot, kind (mission.INFECTED), yaw, clip, how far into it, the push as they go
## limp), as `DEAD` in outer_street.gd.
const DREAD_DEAD := [
	[Vector3(33.4, .15, 628.2), 14, 1.3, "death_back", .95, Vector3(0, 0, 30)],
	[Vector3(30.2, .15, 669.6), 13, -.3, "death_crumple", .9, Vector3.ZERO],
	[Vector3(48.9, 0, 687.2), 8, 2.0, "death_fwd", .9, Vector3(0, 0, -40)],
	[Vector3(36.5, 5.6, 689.4), 6, .8, "death_back", .95, Vector3.ZERO],
	[Vector3(12.2, 5.0, 674.8), 4, -2.0, "death_crumple", .9, Vector3.ZERO],
	[Vector3(34.6, -5.2, 695.9), 11, PI, "death_fwd", .9, Vector3(0, 0, 60)],
	[Vector3(55.0, -5.2, 683.8), 15, 2.4, "death_crumple", .95, Vector3.ZERO],
	[Vector3(30.8, -10.2, 729.6), 5, 1.0, "death_back", .9, Vector3.ZERO],
	[Vector3(34.6, -11.3, 769.4), 1, .2, "death_fwd", .9, Vector3.ZERO],
	[Vector3(19.0, -4.9, 782.3), 0, -PI * .5, "death_back", .95, Vector3.ZERO],
]
## [id, where the viewer must be (street-local), within, flag gate ("" none, "!flag" while not set), sound, from where,
## volume dB, unit size].
const SCARES := [
	["can", Vector3(33.0, -5.2, 684.6), 3.0, "!outer_power", "res://assets/audio/sfx/impactMetal_light_001.ogg", Vector3(29.5, -5.2, 707.0), -4.0, 9.0],
	["groan", Vector3(52.0, -5.2, 687.5), 2.6, "!outer_power", "res://assets/audio/siege/groan_b.ogg", Vector3(40.0, -4.5, 700.0), -6.0, 10.0],
	["scream", Vector3(40.0, 5.6, 690.0), 4.0, "", "res://assets/audio/zombies/scream_3.ogg", Vector3(74.0, 1.0, 687.0), -8.0, 16.0],
	["windows", Vector3(30.5, -10.2, 718.0), 3.5, "", "res://assets/audio/siege/bang_d.ogg", Vector3(33.2, -9.0, 727.0), -2.0, 8.0],
	["scrape", Vector3(34.6, -11.3, 760.0), 3.0, "", "res://assets/audio/siege/scrape.ogg", Vector3(34.8, -10.0, 791.0), -4.0, 10.0],
]

var bag_nodes: Array[Node3D] = []
var torn_nodes: Array[Node3D] = []
var kiosk_door: Node3D
var kiosk_shape: CollisionShape3D
var _mission = null
var _bags_torn := false
var _train_dark_seen := false
var _stair_dark_seen := false
var _kiosk_seen := false
var _door_t := -1.0
var _dread_t := 0.0
var _scares_done := {}
## Roots put away behind the kiosk (`_view` keeps them hidden).
var gone: Array = []

# ---------------------------------------------------------------- build (every peer, in `build`, before `commit`)

func dread() -> void:
	triage()
	track_worker()
	kiosk_door_build()

## The rescue tent on the east carriageway, north of the crossing (x 49.6..55.8, z 677.6..686.6): two canopies end to
## end, cots down the west half, the bags in a row down the east half, an aisle between.
func triage() -> void:
	var r := R_PLAZA
	var x0 := 49.6
	var x1 := 55.8
	var xm := 52.7
	var z0 := 677.6
	var zm := 682.1
	var z1 := 686.6
	# The frames: poles round the edge (none in the aisle), eaves, ridges; tarps pitched over them.
	for px: float in [x0, xm, x1]:
		for pz: float in [z0, zm, z1]:
			if px == xm and pz == zm: continue
			var top := 3.0 if px == xm else 2.3
			pipe(r, Vector3(px, 0, pz), Vector3(px, top, pz), .035, "#9a9e9c", 6)
			solid(r, Vector3(px, top * .5, pz), Vector3(.08, top, .08))
	for pz: float in [z0, zm, z1]:
		bar(r, Vector3(x0, 2.3, pz), Vector3(xm, 3.0, pz), .04, "#9a9e9c")
		bar(r, Vector3(xm, 3.0, pz), Vector3(x1, 2.3, pz), .04, "#9a9e9c")
	for px: float in [x0, x1]: bar(r, Vector3(px, 2.3, z0), Vector3(px, 2.3, z1), .04, "#9a9e9c")
	bar(r, Vector3(xm, 3.0, z0), Vector3(xm, 3.0, z1), .05, "#9a9e9c")
	var tilt := atan2(.7, xm - x0)
	var half := sqrt(.7 * .7 + (xm - x0) * (xm - x0)) + .1
	for tent: Array in [[z0, zm, "#2a4a86"], [zm, z1, "#c4c8c4"]]:
		var a: float = tent[0]
		var b: float = tent[1]
		bx(r, Vector3((x0 + xm) * .5, 2.68, (a + b) * .5), Vector3(half, .03, b - a + .2), str(tent[2]), false, Basis(Vector3.BACK, tilt))
		bx(r, Vector3((xm + x1) * .5, 2.68, (a + b) * .5), Vector3(half, .03, b - a + .2), str(tent[2]), false, Basis(Vector3.BACK, -tilt))
	# The back wall's tarp, one of its ties gone; a side flap torn loose.
	bx(r, Vector3(x1 + .02, 1.45, (z0 + zm) * .5), Vector3(.03, 1.7, zm - z0 - .2), "#2a4a86", false, Basis(Vector3.FORWARD, .05))
	bx(r, Vector3(x1 + .2, .85, zm + 1.6), Vector3(.03, 1.5, 1.9), "#c4c8c4", false, Basis(Vector3.UP, .5) * Basis(Vector3.FORWARD, .25))
	# The cots: aluminium legs and rails, olive canvas; the last one kicked onto its side.
	for i in COTS.size():
		var cz: float = COTS[i]
		if i == 3:
			bx(r, Vector3(51.0, .36, cz), Vector3(1.9, .7, .06), "#4a5a3a", false, Basis(Vector3.RIGHT, .1))
			bar(r, Vector3(50.05, .02, cz - .1), Vector3(51.95, .02, cz - .1), .03, "#a8aca8")
			bar(r, Vector3(50.05, .7, cz + .05), Vector3(51.95, .7, cz + .05), .03, "#a8aca8")
			solid(r, Vector3(51.0, .36, cz), Vector3(1.9, .72, .2))
			continue
		bx(r, Vector3(51.0, .45, cz), Vector3(1.9, .05, .66), "#4a5a3a")
		for side: float in [-.34, .34]: bar(r, Vector3(50.05, .45, cz + side), Vector3(51.95, .45, cz + side), .03, "#a8aca8")
		for lx: float in [50.15, 51.85]:
			bar(r, Vector3(lx, 0, cz - .3), Vector3(lx, .45, cz + .3), .025, "#a8aca8")
			bar(r, Vector3(lx, 0, cz + .3), Vector3(lx, .45, cz - .3), .025, "#a8aca8")
		solid(r, Vector3(51.0, .25, cz), Vector3(1.9, .5, .7))
	# The bags on the cots: the first two move (`dread_sync`) until they split; the third is still.
	for i in 3:
		var at := Vector3(51.0, .48, COTS[i])
		if i == 2:
			_bag_still(r, at, .06)
			continue
		var bag := _bag(r, at, 0.0)
		if i < 2:
			bag_nodes.append(bag)
			var torn := Node3D.new()
			torn.name = "Split bag %d" % i
			torn.position = at
			torn.visible = false
			roots[r].add_child(torn)
			for side: float in [-1.0, 1.0]:
				var flap: MeshInstance3D = s.piece(torn, Vector3(0, .03, .2 * side), Vector3(1.8, .04, .26), "#1b1f24")
				flap.rotation.x = .35 * side
			s.piece(torn, Vector3(0, .015, 0), Vector3(1.7, .01, .3), "#4a1210")
			torn_nodes.append(torn)
	# The row on the road: seven bags side by side, a gap at the canopies' seam.
	for k in 7:
		var bz: float = [678.3, 679.1, 679.9, 680.7, 681.5, 683.4, 684.2][k]
		_bag_still(r, Vector3(54.7, .13, bz), rng.randf_range(-.04, .04))
	solid(r, Vector3(54.7, .15, 679.9), Vector3(1.95, .3, 4.0))
	solid(r, Vector3(54.7, .15, 683.8), Vector3(1.95, .3, 1.6))
	# A drip stand still upright by the first cot, another down in the aisle; the bin, boxes of dressings.
	for st: Array in [[Vector3(52.2, 0, 679.4), false], [Vector3(52.5, .05, 684.6), true]]:
		var at: Vector3 = st[0]
		if bool(st[1]):
			pipe(r, at, at + Vector3(1.7, 0, .3), .015, "#c8ccc8", 6)
			bx(r, at + Vector3(1.75, .05, .31), Vector3(.16, .05, .1), "glass#c8d8d8a0")
			continue
		pipe(r, at, at + Vector3.UP * 1.9, .015, "#c8ccc8", 6)
		for k in 4:
			var a := k * PI * .5 + .4
			bar(r, at + Vector3(0, .04, 0), at + Vector3(cos(a) * .28, .02, sin(a) * .28), .02, "#9a9e9c")
		bar(r, at + Vector3(0, 1.88, 0), at + Vector3(.18, 1.88, 0), .015, "#c8ccc8")
		bx(r, at + Vector3(.18, 1.72, 0), Vector3(.12, .2, .05), "glass#c8d8d8a0")
		pipe(r, at + Vector3(.18, 1.6, 0), at + Vector3(-1.1, .52, -.85), .004, "#d8dcd8", 4)
	cyl(r, Vector3(55.2, .3, 685.7), .24, .6, "#d8b81a", Basis.IDENTITY, 12)
	solid(r, Vector3(55.2, .3, 685.7), Vector3(.48, .6, .48))
	for k in 5: bx(r, Vector3(54.1 + (k % 2) * .52, .18 + int(k / 2) * .36, 686.1), Vector3(.48, .34, .4), "#e8e6e0", false, Basis(Vector3.UP, rng.randf_range(-.15, .15)))
	solid(r, Vector3(54.36, .55, 686.1), Vector3(1.0, 1.1, .45))
	# The spine board dropped by the way in; chairs knocked over; dressings and gloves underfoot.
	bx(r, Vector3(48.2, .03, 679.5), Vector3(.46, .05, 1.85), "#d8641a", false, Basis(Vector3.UP, .15))
	place(r, "street/plastic_monobloc_chair_01", Vector3(49.0, 0, 682.4), 40.0, 1.0, Vector3(85, 0, 0))
	place(r, "street/plastic_monobloc_chair_01", Vector3(48.5, 0, 677.9), 200.0, 1.0, Vector3(0, 0, 80))
	litter(r, Vector3(52.7, 0, 682.0), Vector2(2.8, 4.2), 46, ["#e8e6e0", "#dcdad2", "#3a6ab0", "#c8c4b8", "#e8e6e0"])
	# Under the moving cots, and from the row out across the road toward the subway.
	stain(r, "pool_big", Vector3(51.0, 0, 680.3), .4, 1.6, 1.2)
	stain(r, "spatter_floor", Vector3(51.2, 0, 678.6), 1.9, 1.2, 1.0)
	drag(r, Vector3(53.6, 0, 681.6), Vector3(47.6, 0, 683.8), false)
	# The floodlight on its tripod, down on the road, still burning low across it toward the shutter; its generator.
	var head := Vector3(48.9, .28, 686.0)
	for k in 3:
		var a := k * TAU / 3.0
		bar(r, head + Vector3(.1, -.2, .3), head + Vector3(.1 + cos(a) * .5, -.25, 1.6 + sin(a) * .4), .03, "#2a2a2a")
	bx(r, head, Vector3(.5, .36, .3), "#2a2a2a", false, Basis(Vector3.UP, .75) * Basis(Vector3.RIGHT, .2))
	var lens := glow_piece(r, head + Basis(Vector3.UP, .75) * Vector3(0, 0, -.16), Vector3(.42, .28, .02), Color(.92, .96, 1.0), 3.2, Basis(Vector3.UP, .75))
	var beam := spot(r, head + Vector3(-.25, .05, -.25), Vector3(38.0, .9, 673.0), Color(.9, .95, 1.0), 3.0, 26.0, 26.0, false)
	lamp_light(beam, 3.0, 2, "", lens, 3.2)
	bx(r, Vector3(50.4, .35, 688.2), Vector3(1.0, .7, .6), "#3a5a3a", true)
	bx(r, Vector3(50.4, .72, 688.2), Vector3(.9, .04, .5), "#2a2a2a")
	bar(r, Vector3(49.9, .02, 688.0), head + Vector3(.2, -.26, .2), .015, "#121212")
	# Battery lanterns hung from the ridges, one still steady, one going.
	for ln: Array in [[Vector3(xm, 2.72, 679.6), 1, .9], [Vector3(xm, 2.72, 684.4), 2, .7]]:
		var at: Vector3 = ln[0]
		bar(r, at + Vector3(0, .26, 0), at + Vector3(0, .1, 0), .01, "#2a2a2a")
		lamp(r, at, Color(1.0, .8, .55), float(ln[2]), 7.5, int(ln[1]), Vector3(.12, .18, .12))
	hum(r, Vector3(50.4, .5, 688.2), "res://assets/audio/nichols/fridge_hum.ogg", -20.0, 5.0)
	hum(r, Vector3(52.7, 1.0, 682.0), "res://assets/audio/nichols/flies.ogg", -22.0, 4.0)

## A body bag: black, zipped, the head and the feet showing through it. Its own node (it can move and be torn).
func _bag(r: int, at: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Body bag"
	n.position = at
	n.rotation.y = yaw
	roots[r].add_child(n)
	for pc: Array in BAG_PIECES: s.piece(n, pc[0] as Vector3, pc[1] as Vector3, str(pc[2]))
	return n

## The same bag, still: into the root's merged meshes (no node, no draw of its own).
func _bag_still(r: int, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	for pc: Array in BAG_PIECES: bx(r, at + b * (pc[0] as Vector3), pc[1] as Vector3, str(pc[2]), false, b)

## The track worker's lantern by him on the ballast, still on; his hard hat rolled against the rail.
func track_worker() -> void:
	var r := R_TUNNEL
	var at := Vector3(35.9, BED_Y + .12, 769.6)
	bx(r, at, Vector3(.16, .22, .14), "#c8641a")
	bar(r, at + Vector3(-.06, .14, 0), at + Vector3(.06, .14, 0), .02, "#2a2a2a")
	lamp(r, at + Vector3(0, .06, -.075), Color(1.0, .78, .48), .7, 5.5, 2, Vector3(.1, .1, .01))
	cyl(r, Vector3(35.05, BED_Y + .22, 771.0), .15, .12, "#e0b020", Basis(Vector3.RIGHT, 1.2), 12)
	cyl(r, Vector3(35.05, BED_Y + .2, 771.05), .2, .02, "#e0b020", Basis(Vector3.RIGHT, 1.2), 12)
	place(r, "nichols/nh_pipe_wrench", Vector3(34.2, BED_Y + .15, 768.2), 60.0, 1.0, Vector3(90, 0, 0))

## The kiosk's steel door out onto the river road: standing open against the wall outside (hinged at the doorway's
## east jamb) until the seal slams it.
func kiosk_door_build() -> void:
	kiosk_door = Node3D.new()
	kiosk_door.name = "Kiosk door"
	kiosk_door.position = Vector3(7.4, 0, 785.48)
	kiosk_door.rotation.y = 2.9
	roots[R_RIVER].add_child(kiosk_door)
	s.piece(kiosk_door, Vector3(-.89, 1.08, 0), Vector3(1.78, 2.14, .06), "#5a6a6a")
	s.piece(kiosk_door, Vector3(-1.62, 1.05, -.06), Vector3(.05, .26, .05), "#2a2a2a")
	s.piece(kiosk_door, Vector3(-.89, 1.08, .032), Vector3(1.5, .04, .005), "#3a4444")
	var body := StaticBody3D.new()
	body.name = "Kiosk door body"
	body.collision_layer = 2
	roots[R_RIVER].add_child(body)
	kiosk_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.9, 2.25, .3)
	kiosk_shape.shape = bs
	kiosk_shape.position = Vector3(6.5, 1.12, 785.3)
	kiosk_shape.disabled = true
	body.add_child(kiosk_shape)

# ---------------------------------------------------------------- every peer, after `build`

## The first half's dead (`DREAD_DEAD`), posed and let go limp, like the row's.
func dread_dead(m) -> void:
	_mission = m
	var Fig = load("res://scripts/coop/figure.gd")
	for i in DREAD_DEAD.size():
		var spec: Array = DREAD_DEAD[i]
		var v = Fig.new()
		m.add_child(v)
		v.key = -340 - i
		v.session = m.session
		v.setup("res://assets/characters/zombies/z_%s.glb" % m.INFECTED[int(spec[1])], world(spec[0]), "", true)
		v.rotation.y = float(spec[2])
		var clip: String = spec[3]
		v.clips.play(clip)
		v.clips.seek(v.clips.get_animation(clip).length * float(spec[4]), true)
		v.go_limp(spec[5] as Vector3)
		quiet_shadows(v)
		m.victims.append(v)

## (0.67) A body lying on the ground throws no shadow anyone sees, but it is drawn again in every shadow pass.
static func quiet_shadows(v: Node) -> void:
	for g in v.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------------------------------------------------------------- the host

func _dread_spawn(m, at: Vector3) -> void:
	var wp: Vector3 = m.ground(world(at) + Vector3.UP * .3)
	if not wp.is_finite(): wp = world(at)
	var z = m.spawn(wp, false)
	if z != null: z.asleep = false

## Where the squad is (`who`, street-local): the bags, the train, the stair; then the kiosk's seal.
func dread_host(m, who: Array) -> void:
	if m.stage != 16: return
	var f: Dictionary = m.flags
	for lp: Vector3 in who:
		if not bool(f.get("outer_bags", false)) and lp.y > -1.0 and lp.y < 2.0 and Vector2(lp.x - TRIAGE.x, lp.z - TRIAGE.z).length() < 5.5:
			f.outer_bags = true
			m.threat = 3.0
			for i in 2: _dread_spawn(m, Vector3(52.95, 0, float(COTS[i])))
			print("INTERIOR_COOP_OUTER the bags split")
		if not bool(f.get("outer_train_dark", false)) and lp.y < -8.5 and lp.y > -10.8 and lp.x > TRAIN_X0 and lp.x < TRAIN_X1 and lp.z > 728.0 and lp.z < 751.0:
			f.outer_train_dark = true
			_dread_spawn(m, Vector3(34.6, TRAIN_FLOOR, 749.2))
			print("INTERIOR_COOP_OUTER the train's lights die")
		if not bool(f.get("outer_stair_dark", false)) and lp.x > 9.6 and lp.x < 21.0 and lp.z > 780.6 and lp.z < 783.4 and lp.y > -7.0 and lp.y < 1.0:
			f.outer_stair_dark = true
			m.threat = 3.0
			for at: Vector3 in [Vector3(31.0, BED_Y, 781.4), Vector3(31.8, BED_Y, 782.6), Vector3(34.4, BED_Y, 778.0)]: _dread_spawn(m, at)
			print("INTERIOR_COOP_OUTER the stair goes dark")
	_kiosk_check(m)

## Out on the river side of the kiosk's door (or anywhere on the row past it).
static func past_kiosk(p: Vector3) -> bool:
	return p.y > -1.5 and p.z > 733.0 and not (p.x < 14.6 and p.z < 785.7)

## (host) Every survivor out of the kiosk: its door shut behind them for good. The squad AI and the students still
## inside come through it first.
func _kiosk_check(m) -> void:
	if bool(m.flags.get("outer_kiosk_shut", false)) or not bool(m.flags.get("outer_up", false)): return
	var any := false
	for id: int in m.session.team:
		if m.session.is_bot(id): continue
		any = true
		if not past_kiosk(local(m.session.team[id].pos)): return
	if not any: return
	m.flags.outer_kiosk_shut = true
	_bring_through(m)
	m.nav.forget_box(AABB(world(Vector3(4.8, -.5, 784.4)), Vector3(3.4, 3.2, 2.2)))
	print("INTERIOR_COOP_OUTER the kiosk shut behind the squad")

func _bring_through(m) -> void:
	var out := world(Vector3(7.0, 0, 788.2))
	var n := 0
	for id: int in m.session.team:
		if not m.session.is_bot(id) or past_kiosk(local(m.session.team[id].pos)): continue
		var spot: Vector3 = m.ground(out + Vector3(float(n % 3) * 1.2 - 1.2, .6, float(n / 3) * 1.1))
		n += 1
		if not spot.is_finite(): continue
		if m.session.bots != null and m.session.bots.bots.has(id): m.session.bots.bots[id].body.global_position = spot
		m.session.team[id].pos = spot
	if m.escape != null:
		for fig in m.escape.people:
			if not is_instance_valid(fig) or past_kiosk(local(fig.position)): continue
			var gp: Vector3 = m.ground(out + Vector3(float(n % 4) * 1.0 - 1.5, .6, 1.4 + float(n / 4) * 1.0))
			n += 1
			if gp.is_finite(): fig.position = gp

## (host, debug) A jump past these places: their flags set, nothing spawned for them.
func dread_settle(m, upto: Array) -> void:
	if "outer_shutter" in upto: m.flags.outer_bags = true
	if "outer_train" in upto: m.flags.outer_train_dark = true
	if "outer_up" in upto: m.flags.outer_stair_dark = true
	if "outer_pizza" in upto: m.flags.outer_kiosk_shut = true

# ---------------------------------------------------------------- every peer

func dread_sync(flags: Dictionary, delta: float, viewer: Vector3) -> void:
	_dread_t += delta
	if bool(flags.get("outer_bags", false)) and not _bags_torn:
		_bags_torn = true
		for i in bag_nodes.size():
			bag_nodes[i].visible = false
			torn_nodes[i].visible = true
		sound(world(TRIAGE + Vector3(-1.7, .6, -2.8)), "res://assets/audio/zombies/tear_2.ogg", 2.0, 8.0)
		sound(world(TRIAGE + Vector3(-1.7, .6, -1.0)), "res://assets/audio/zombies/scream_2.ogg", 0.0, 10.0)
	if bool(flags.get("outer_train_dark", false)) and not _train_dark_seen:
		_train_dark_seen = true
		if is_instance_valid(train_hum): train_hum.stop()
		sound(world(Vector3(34.6, -8.0, 741.0)), "res://assets/audio/nichols/switch_click.ogg", 6.0, 8.0)
		sound(world(Vector3(34.6, -8.0, 744.0)), "res://assets/audio/nichols/arc_buzz.ogg", 2.0, 8.0)
		sound(world(Vector3(34.6, -9.0, 749.0)), "res://assets/audio/zombies/growl_2.ogg", -2.0, 9.0)
	if bool(flags.get("outer_stair_dark", false)) and not _stair_dark_seen:
		_stair_dark_seen = true
		sound(world(Vector3(25.0, -7.0, EXIT_Z)), "res://assets/audio/nichols/switch_click.ogg", 4.0, 10.0)
		sound(world(Vector3(32.0, BED_Y + 1.0, 781.0)), "res://assets/audio/siege/bang_c.ogg", 6.0, 14.0)
		sound(world(Vector3(33.0, BED_Y + 1.0, 776.0)), "res://assets/audio/zombies/scream_1.ogg", 0.0, 14.0)
	if bool(flags.get("outer_kiosk_shut", false)) and not _kiosk_seen:
		_kiosk_seen = true
		_door_t = 0.0
		kiosk_shape.disabled = false
		sound(world(Vector3(6.5, 1.2, 785.6)), "res://assets/audio/nichols/door_close_b.ogg", 6.0, 12.0)
		sound(world(Vector3(6.5, 1.2, 785.6)), "res://assets/audio/siege/bang_a.ogg", 4.0, 12.0)
		# What came up the stair after them, on the other side of it.
		thumps.append([Vector3(6.5, 1.2, 785.7), 16.0, 2.5])
		_put_away_behind()
	if _door_t >= 0.0 and _door_t < 1.0:
		_door_t = minf(_door_t + delta / .45, 1.0)
		kiosk_door.rotation.y = lerpf(2.9, 0.0, 1.0 - pow(1.0 - _door_t, 3.0))
	if not viewer.is_finite(): return
	var v := local(viewer)
	# The bags that move: still, then a jerk, as something inside tries the zip.
	if not _bags_torn and v.distance_to(TRIAGE) < 14.0 and roots[R_PLAZA].visible:
		for i in bag_nodes.size():
			var ph := float(i) * 2.3
			var jerk := sin(_dread_t * 21.0 + ph) * sin(_dread_t * 2.7 + ph * 1.7)
			var amount := (jerk - .82) * 2.2 if jerk > .82 else 0.0
			bag_nodes[i].rotation = Vector3(amount * .5, 0, amount * sin(_dread_t * 37.0 + ph) * .3)
			bag_nodes[i].position.y = .48 + amount * .05
	for sc: Array in SCARES:
		var id: String = sc[0]
		if _scares_done.has(id): continue
		var gate: String = sc[3]
		if gate != "":
			if gate.begins_with("!") and bool(flags.get(gate.trim_prefix("!"), false)): continue
			if not gate.begins_with("!") and not bool(flags.get(gate, false)): continue
		if v.distance_to(sc[1] as Vector3) > float(sc[2]): continue
		_scares_done[id] = true
		sound(world(sc[5] as Vector3), str(sc[4]), float(sc[6]), float(sc[7]))

## The kiosk is shut: everything behind it put away on this peer. The roots behind hidden and stopped (their meshes
## let go of a little each frame by the mission's unload job); the dead back there freed; the host drops the infected
## back there (clients drop them with the host's next snapshot); the teleports back there are closed (`kept`).
func _put_away_behind() -> void:
	var m = _mission
	var t := Time.get_ticks_usec()
	for r: int in BEHIND:
		if r in gone: continue
		gone.append(r)
		roots[r].visible = false
		roots[r].process_mode = Node.PROCESS_MODE_DISABLED
		if m != null: m._free_stack.append(roots[r])
	if m == null: return
	var keep := AABB(world(KEEP_LO), KEEP_HI - KEEP_LO)
	m.kept.append([keep])
	for list: Array in [m.victims, m.corpses]:
		for i in range(list.size() - 1, -1, -1):
			var fig = list[i]
			if is_instance_valid(fig) and not past_kiosk(local(fig.where())):
				fig.queue_free()
				list.remove_at(i)
	if m.multiplayer.is_server():
		for k in m.enemies.keys():
			if not past_kiosk(local(m.enemies[k].global_position)):
				m.enemies[k].queue_free()
				m.enemies.erase(k)
	print("INTERIOR_COOP_OUTER put away behind the kiosk (%.1f ms; bodies left %d)" % [(Time.get_ticks_usec() - t) / 1000.0, m.victims.size() + m.corpses.size()])
