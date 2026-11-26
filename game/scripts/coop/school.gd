extends Node3D
## 0.50: the Prof. Ivan Lawrence College of Science and Technology (PILCST), at the end of the backstreets.
##
## Ivan Lawrence built it in 2009 out of a two-room review centre; by 2026 it was five storeys of senior high and
## college students. Three days ago the sickness started in the cafeteria at lunch, Ivan had the gates locked to keep
## the street out, and four thousand students were shut in with it. Rommel, the night guard, still holds the back
## gate; there are survivors somewhere on the fifth floor (mission.gd tells it, scripts/coop/session.gd shows it).
##
## The look comes from the owner's reference photos (work/Reference/School): long double-loaded corridors, cream
## walls over a gloss green wainscot, black-and-cream checker in the lobby, pendant and tube lights, a grand stair
## up from the lobby, classrooms of steel-framed armchairs. Everything here is left as it was when it went wrong:
## chairs thrown about, papers everywhere, bags and shoes, blood pooled and dragged, most tubes dead and the rest
## failing on a generator that is running out.
##
## The building: x 0..56, z 514..534 (street-local), five floors of 3.6 m. South rooms z 514.3..521.9, the corridor
## z 522.1..524.9, north rooms z 525.1..533.7. Three stairs: the grand stair from the lobby (ground floor to the
## second only), and a switchback stairwell at each end. The students piled desks into the stairs to keep the
## infected from coming up, so only one way is open between each pair of floors and the squad has to cross every
## floor: grand stair 1F->2F, east 2F->3F, west 3F->4F, east 4F->5F (UP). The survivors are in room 501, the west
## end of the fifth floor.
##
## The infected walk by zombie_nav.gd, which searches one floor at a time; `steer` gives them (and the squad AI)
## the stairs as a chain of points (`chain`) when what they follow is on another floor.
##
## Every peer builds the same school from the street's seed (built when the backstreets are woken, mission.gd
## `wake_ahead`). Floors out of sight are hidden (`view`): inside, the floor you are on and the ones above and below;
## outside, every floor's walls but only the ground floor's and the fifth floor's lights.

const H := 3.6
const FLOORS := 5
const ZS := 521.9
const ZN := 525.1
const CZ := 523.5
const GATE := Vector3(28, 0, 500.42)
const GUARD_SEAT := Vector3(31.55, 0, 502.25)
const ENTRANCE := Vector3(28, 0, 513.2)
## The fifth floor's room 501: the survivors, behind a door they have barred (where to knock, corridor side).
const DOOR_501 := Vector3(6.9, 4 * H, 522.55)
const STAIR_W := 0
const STAIR_E := 1
const STAIR_G := 2
## Which interior stair is open from floor k up to k+1 (0.51: -1 where none is: the fire escape outside the east
## end takes the second floor to the third, the janitor's ladder and the air duct the fourth to the fifth).
const UP := [STAIR_G, -1, STAIR_W, -1]
const ROUTE_FIRE := 1
const ROUTE_VENT := 3
## [stair, floor]: the flights the students blocked (desks piled on the turn).
const BLOCKED := [[STAIR_W, 0], [STAIR_E, 0], [STAIR_W, 1], [STAIR_E, 1], [STAIR_E, 2], [STAIR_W, 3], [STAIR_E, 3]]
## 0.51: the fire escape (street-local): landings outside the east end at the second and third floors.
const FIRE_X0 := 56.0
const FIRE_X1 := 58.6
## 0.51: the maintenance room on the fourth floor (406's place), its ladder up through a hatch into the fifth floor's
## mechanical room, and the supply duct from there west along the back of 510 and 509 (crawl: 1.2 m inside).
const LADDER := Vector3(36.0, 0, 533.25)
const HATCH := [35.2, 36.8, 532.45, 533.7]
const DUCT := [18.2, 34.2, 532.3, 533.7]
const DUCT_H := 1.2
## 0.51: the corridor walls of desks (floor, x) and the broken partitions that get round them (floor, side, x, z0, z1).
const HALL_BLOCKS := [[1, 41.6], [3, 17.4]]
const BREACHES := [[1, "s", 40.1, 516.3, 518.1], [3, "n", 16.0, 528.9, 530.7]]
## 0.51: closed classroom doors with a class behind them. Each group bursts together when a survivor comes close
## (mission.gd); `SCARES` only pound, and never open.
const AMBUSH := [["204", "205", "210"], ["304", "305"], ["301", "302", "303"], ["403", "404", "405"], ["502", "503", "504"], ["507", "511"]]
const SCARES := ["201", "208", "401", "402", "505", "506"]
const FLOOR_NAMES := ["Ground floor", "Second floor", "Third floor", "Fourth floor", "Fifth floor"]
## 0.52: the way out with the survivors of 501. The fire escape goes on up to the fourth and fifth floors (their fire
## doors chained from inside: the students did it the first night); Ma'am Teves has the key to the fifth floor's.
## `ROUTE_ESC` is the whole fire escape from the second floor's door to the fifth's, once that door is open. Halfway
## down the gas store in the kitchen's lean-to goes up: room 208 above it is blown open (`BREACH`), the grand stair's
## gallery comes down (`COLLAPSE`), and the way off the second floor is out through 208 onto the lean-to's roof and
## down into the school field; the rear gate at its far end (`REAR_GATE`) opens onto the city (0.53: shut, chained and
## padlocked, until Heavy-arm's key opens it).
const ROUTE_ESC := 4
const ROUTE_JUMP := 5
const BREACH := [6.7, 15.3]
const LEAN := [4.6, 17.6, 534.0, 539.4]
const LEAN_TOP := 3.05
const LEAN_EAVE := 2.45
const FIELD_END := 600.0
const REAR_GATE := Vector3(44.0, 0, 600.0)
const FIRE_DOOR_5 := Vector3(55.6, 4 * H, 523.5)
## The gallery's opening onto the second floor's corridor, where the ceiling comes down: [x0, x1].
const COLLAPSE := [24.1, 31.9]
## [x0, x1, side, kind, words]
const ROOMS := [
	[[0.3, 23.9, "s", "cafeteria", "CAFETERIA"], [24.1, 31.9, "s", "lobby", ""], [32.1, 39.9, "s", "clinic", "CLINIC"],
		[40.1, 55.7, "s", "registrar", "REGISTRAR  •  CASHIER"], [6.1, 15.9, "n", "kitchen", "KITCHEN  •  STAFF ONLY"],
		[16.1, 23.9, "n", "guidance", "GUIDANCE OFFICE"], [24.1, 31.9, "n", "grand", ""], [32.1, 39.9, "n", "faculty", "FACULTY ROOM"],
		[40.1, 49.9, "n", "president", "OFFICE OF THE PRESIDENT"]],
	[[0.3, 8.0, "s", "class", "201"], [8.2, 16.0, "s", "class", "202"], [16.2, 23.9, "s", "class", "203"], [24.1, 31.9, "s", "class", "204"],
		[32.1, 40.0, "s", "class", "205"], [40.2, 48.0, "s", "class", "206"], [48.2, 55.7, "s", "class", "207"], [6.1, 15.9, "n", "class", "208"],
		[16.1, 23.9, "n", "class", "209"], [24.1, 31.9, "n", "gallery", ""], [32.1, 39.9, "n", "class", "210"], [40.1, 49.9, "n", "faculty", "FACULTY ROOM 2"]],
	[[0.3, 15.9, "s", "chem", "CHEMISTRY LABORATORY"], [16.1, 23.9, "s", "stock", "LAB STOCKROOM"], [24.1, 39.9, "s", "bio", "BIOLOGY LABORATORY"],
		[40.1, 55.7, "s", "physics", "PHYSICS LABORATORY"], [6.1, 15.9, "n", "class", "301"], [16.1, 23.9, "n", "class", "302"],
		[24.1, 31.9, "n", "class", "303"], [32.1, 39.9, "n", "class", "304"], [40.1, 49.9, "n", "class", "305"]],
	[[0.3, 23.9, "s", "library", "LIBRARY"], [24.1, 39.9, "s", "computer", "COMPUTER LABORATORY"], [40.1, 48.0, "s", "class", "401"],
		[48.2, 55.7, "s", "class", "402"], [6.1, 15.9, "n", "class", "403"], [16.1, 23.9, "n", "class", "404"], [24.1, 31.9, "n", "class", "405"],
		[32.1, 39.9, "n", "janitor", "MAINTENANCE  •  STAFF ONLY"], [40.1, 49.9, "n", "avr", "AUDIO-VISUAL ROOM"]],
	[[0.3, 8.0, "s", "refuge", "501"], [8.2, 16.0, "s", "class", "502"], [16.2, 23.9, "s", "class", "503"], [24.1, 31.9, "s", "class", "504"],
		[32.1, 40.0, "s", "class", "505"], [40.2, 48.0, "s", "class", "506"], [48.2, 55.7, "s", "class", "507"], [6.1, 15.9, "n", "class", "508"],
		[16.1, 23.9, "n", "class", "509"], [24.1, 31.9, "n", "class", "510"], [32.1, 39.9, "n", "mech", "MECHANICAL ROOM"], [40.1, 49.9, "n", "class", "511"]],
]
## Chalkboards: what each class was in the middle of (and, here and there, what someone wrote after).
const BOARDS := ["GEN. CHEMISTRY 1\nQuiz #4 - Stoichiometry\nNov. 17, 2026", "EARTH & LIFE SCIENCE\nreview: mitosis vs meiosis",
	"PRE-CALCULUS\nconic sections, p. 142\nseatwork 1-15", "ORAL COMMUNICATION\nGroup 3 reporting\n- Dela Cruz\n- Pagaduan\n- Uy",
	"STATISTICS & PROBABILITY\nLONG TEST FRIDAY\nbring calculators", "PHYSICAL SCIENCE\nhow stars make the elements",
	"INTRO TO PROGRAMMING\nfor (int i = 0; i < n; i++)\n  sum += a[i];", "KOMUNIKASYON AT PANANALIKSIK\nTakdang-aralin: pahina 58",
	"GENERAL PHYSICS 1\nF = ma\nfree body diagrams", "CLASSES SUSPENDED\nSTAY INSIDE YOUR ROOMS\nWAIT FOR THE ADMIN\n- Ma'am Teves",
	"ROOM IS NOT SAFE\nWE WENT UP\n- STEM 12-B", "EMPOWERMENT TECHNOLOGIES\nproject due Monday"]
## Where the dead students lie (as Street.STORE_DEAD): [street-local spot, which of the ten, yaw, clip, how far into
## it, push].
const DEAD := [
	[Vector3(6.0, 0, 517.6), 1, .8, "death_crumple", .9, Vector3.ZERO],
	[Vector3(15.6, 0, 520.5), 7, 2.4, "death_back", .95, Vector3.ZERO],
	[Vector3(23.6, 0, 508.6), 3, -1.2, "death_fwd", .95, Vector3(0, 0, -60)],
	[Vector3(35.4, 0, 516.9), 8, .3, "death_crumple", .9, Vector3.ZERO],
	[Vector3(40.0, H, 523.3), 5, 1.6, "death_fwd", .95, Vector3(40, 0, 0)],
	[Vector3(7.2, 2 * H, 518.2), 2, -.6, "death_back", .95, Vector3.ZERO],
	[Vector3(12.4, 3 * H, 517.2), 6, 2.0, "death_crumple", .9, Vector3.ZERO],
	[Vector3(30.2, 4 * H, 523.8), 9, -1.9, "death_fwd", .95, Vector3.ZERO],
	[Vector3(51.4, H, 525.9), 0, 3.0, "death_back", .95, Vector3.ZERO],
	[Vector3(18.0, 2 * H, 523.2), 4, 1.2, "death_crumple", .9, Vector3.ZERO],
	[Vector3(44.0, 3 * H, 529.0), 1, -2.6, "death_fwd", .95, Vector3.ZERO],
	[Vector3(9.5, 0, 523.9), 6, .4, "death_back", .95, Vector3(0, 0, 30)],
	[Vector3(36.0, 4 * H, 518.0), 8, 2.2, "death_crumple", .9, Vector3.ZERO],
	# 0.51 (10.. are the staff: mission.INFECTED from STUDENT_FIRST): a teacher in the faculty room, one in the computer
	# lab, Ate Marites by the second floor's fire door, a student halfway along the duct.
	[Vector3(35.0, 0, 528.6), 13, 2.2, "death_crumple", .9, Vector3.ZERO],
	[Vector3(30.0, 3 * H, 518.0), 10, -.8, "death_back", .95, Vector3.ZERO],
	[Vector3(53.8, H, 523.1), 17, 1.4, "death_fwd", .95, Vector3.ZERO],
	[Vector3(26.0, 4 * H, 532.95), 4, PI * .5, "death_fwd", .95, Vector3.ZERO],
]
const SIZES := {"checker": 1.2, "corridor": 1.2, "classroom": 1.2, "ceiling": 1.2, "board": 2.0, "cream": 2.6, "green": 2.0}
const ROUGH := {"checker": .34, "corridor": .48, "classroom": .7, "ceiling": .95, "board": .92, "cream": .88, "green": .45}
const TUBE := Color(.82, .93, 1.0)
const HorrorLiquid := preload("res://scripts/horror_liquid.gd")
const SchoolProps := preload("res://scripts/coop/school_props.gd")

var s: Node3D
var rng := RandomNumberGenerator.new()
## 0..4 the floors' walls and things, 5..9 the floors' lights, decals and words, 10 the shell, 11 the yard, 12 the
## school field behind the building (0.52).
var roots: Array[Node3D] = []
var bodies: Array[StaticBody3D] = []
var _kits: Array = []
var _mats := {}
var _chairs: Array = []
## 0.61: every classroom doorway [floor, x, wall z, into the room (+1/-1)]: `_commit` keeps chairs out of it.
var _door_lanes: Array = []
var _papers: Array = []
var _books: Array = []
## Lamps that flicker: [light, base energy, mode, phase, tube material or null].
var lamps: Array = []
## Per floor (street-local): where the infected come out of the rooms, where they lie about before anyone comes,
## and where a rush comes from on arrival.
var spawn_points: Array = []
var sleep_spots: Array = []
var gate: StaticBody3D
var gate_open := 0.0
var _gate_sound: AudioStreamPlayer3D
var shown := -9
var built_usec := 0
var _one_shot_wait := 6.0
var _one_shots: Array[AudioStreamPlayer3D] = []
## 0.51: which shut door (index in `doors`, or -1) each spawn point is behind; the shut doors themselves:
## {k, x, south, room, kind ("ambush" / "scare"), group, body, leaf, rest, inside, half, broken, bang, sound};
## `_door_at` finds one by "floor:x". `groups[g]` lists a burst group's doors.
var spawn_doors: Array = []
var doors: Array = []
var groups: Array = []
var _door_at := {}
## 0.51: per floor, classrooms a class can still be standing in ([x0, x1, z0, z1], street-local).
var class_rooms: Array = []
## 0.51: the hanging fixtures that swing on their wires: [pivot, phase, amplitude]; the TVs' static.
var swings: Array = []
var _tv_mat: StandardMaterial3D
var _bell_rung := {}
var _bell: AudioStreamPlayer3D
## 0.51: ladders (street-local): [foot, top, step off]; set as InteriorPlayer ladders when built.
var ladders: Array = []
## 0.52: what the way out changes, every peer from the host's flags (`sync`): the fifth floor's fire door unchained
## (`flags.fire5`), the blast (`flags.blast`), 501's door (`flags.door501`: 0 shut, 1 open, 2 forced).
var escape_open := false
var blasted := false
var _door_501: StaticBody3D
var _door_501_at := 0.0
var _barricade_501: Node3D
var _fire_5: StaticBody3D
var _fire_5_at := 0.0
var _chain_5: Node3D
var _collapse: Node3D
var _collapse_body: StaticBody3D
var _fires: Array = []
## 0.53: the rear gate shut (chained and padlocked) until `flags.reargate` (scripts/coop/heavyarm.gd has its key).
var _rear_body: StaticBody3D
var _rear_leaves: Array = []
var _rear_chain: Node3D
var _rear_at := 0.0
var _rear_sealed := false
var _rear_stub: Node3D
var _rear_stub_body: StaticBody3D
var _stub_kits := {}
var _stub_lamps: Array = []
var _smoke: Array = []
## 0.63: built hidden, shown when the gas store goes up (`blast_now`).
var _blast_show: Array = []
## 0.57: the chairs and the classroom doors as bodies, host-simulated and followed everywhere (school_props.gd).
var props: SchoolProps

func build(street: Node3D) -> void:
	var t0 := Time.get_ticks_usec()
	s = street
	name = "PILCST"
	rng.seed = int(s.seed_value) * 53 + 2009
	props = SchoolProps.new()
	add_child(props)
	props.setup(self, bool(s.get("authority")) if s.get("authority") != null else true)
	# (0.63: a 14th root, "2F desk wall", inside the second floor's: the wall of desks across its corridor, which the
	# blast throws down: `_blast_hall`.)
	for i in 14:
		var r := Node3D.new()
		r.name = _root_name(i)
		if i == 13: roots[1].add_child(r)
		else: add_child(r)
		roots.append(r)
		_kits.append({})
		_chairs.append([])
		_papers.append([])
		_books.append([])
		var b := StaticBody3D.new()
		b.collision_layer = 2
		b.name = _root_name(i) + " body"
		add_child(b)
		bodies.append(b)
	for k in FLOORS:
		spawn_points.append([])
		spawn_doors.append([])
		sleep_spots.append([])
		class_rooms.append([])
	for g in AMBUSH: groups.append([])
	_tv_mat = StandardMaterial3D.new()
	var noise := Image.create(48, 36, false, Image.FORMAT_L8)
	for i in 48 * 36: noise.set_pixel(i % 48, i / 48, Color.from_hsv(0, 0, rng.randf() * rng.randf_range(.4, 1.0)))
	_tv_mat.albedo_color = Color(.05, .05, .06)
	_tv_mat.emission_enabled = true
	_tv_mat.emission_texture = ImageTexture.create_from_image(noise)
	_tv_mat.emission = Color(.75, .8, .9)
	_tv_mat.emission_energy_multiplier = 1.4
	_tv_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for k in FLOORS: _floor(k)
	_shell()
	_fire_escape()
	_yard()
	_way_out()
	_commit()
	ladders.append([LADDER + Vector3.UP * 3 * H, LADDER + Vector3.UP * 4 * H, Vector3(LADDER.x, 4 * H, HATCH[2] - .75)])
	InteriorPlayer.ladders.clear()
	for l: Array in ladders:
		var foot: Vector3 = world(l[0])
		InteriorPlayer.ladders.append([AABB(foot + Vector3(-.4, -.2, -.75), Vector3(.8, H + 1.4, 1.2)), Vector3(0, 0, -1), world(l[2])])
	for g in roots[12].find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).layers |= 2
	built_usec = Time.get_ticks_usec() - t0
	print("INTERIOR_COOP_SCHOOL built in %d ms" % int(built_usec / 1000))

func _root_name(i: int) -> String:
	if i < 5: return "Floor %d" % (i + 1)
	if i < 10: return "Floor %d lights" % (i - 4)
	return ["Shell", "Yard", "Field", "2F desk wall"][i - 10]

func _commit() -> void:
	var chair_mesh := _chair_mesh()
	var paper_mesh := _paper_mesh()
	var book_mesh := _book_mesh()
	# 0.61 (owner: chairs heaped in a classroom doorway left no way past): no chair stands in a doorway or just either
	# side of it; the class's rows start further in. (Taken out after the build, so the rng order is the same.)
	for lane: Array in _door_lanes:
		var k := int(lane[0])
		var kept: Array = []
		for t: Transform3D in _chairs[k]:
			var inside := (t.origin.z - float(lane[2])) * float(lane[3])
			if absf(t.origin.x - float(lane[1])) < 1.0 and inside > -1.3 and inside < 1.9 and t.origin.y > k * H - .3 and t.origin.y < k * H + 2.5: continue
			kept.append(t)
		_chairs[k] = kept
	# (0.61: and none of the corridor's loose chairs inside a wall of desks (`_hall_block`): woken, they burst out.)
	for block: Array in HALL_BLOCKS:
		var k := int(block[0])
		_chairs[k] = _chairs[k].filter(func(t: Transform3D): return not (absf(t.origin.x - float(block[1])) < 1.0 and absf(t.origin.z - CZ) < 1.75 and t.origin.y < k * H + 3.2))
	for i in _kits.size():
		# (0.65: materials alike but for their colour share one mesh: InteriorColourBatch.)
		var dress := func(mesh: MeshInstance3D, id: String) -> void:
			mesh.layers = 1 | 8
			# (0.52: behind the building the moon lights the field, the lean-to and the street, and the fire
			# escape's steel: the moon only reaches the outdoor layer, 2.)
			if i == 12 or id.begins_with("rusty_metal_02|#8a7c6c"): mesh.layers = 1 | 2 | 8
			mesh.visibility_range_end = 160.0
			if id.begins_with("glass"): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		InteriorColourBatch.commit_kits(roots[i], _kits[i], mat, dress)
		var chairs := _multi(i, _chairs[i], chair_mesh, true)
		if chairs != null: props.add_chairs(_chairs[i], chairs)
		_multi(i, _papers[i], paper_mesh, false, true)
		_multi(i, _books[i], book_mesh, false, true)
	_kits.clear()

func _multi(i: int, items: Array, mesh: Mesh, shadows: bool, colours := false) -> MultiMesh:
	if items.is_empty(): return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colours
	mm.mesh = mesh
	mm.instance_count = items.size()
	for n in items.size():
		if colours:
			mm.set_instance_transform(n, items[n][0])
			mm.set_instance_color(n, items[n][1])
		else:
			mm.set_instance_transform(n, items[n])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 60.0
	roots[i].add_child(mi)
	return mm

# ---------------------------------------------------------------- materials and helpers

func mat(id: String) -> Material:
	if _mats.has(id): return _mats[id]
	var m: StandardMaterial3D
	if id.begins_with("s:"):
		var base := id.trim_prefix("s:")
		var tint := Color.WHITE
		if "|" in base:
			tint = Color(base.get_slice("|", 1))
			base = base.get_slice("|", 0)
		m = StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/school/%s.png" % base)
		m.albedo_color = tint
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / float(SIZES.get(base, 2.0))
		m.roughness = float(ROUGH.get(base, .85))
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		m = s.material(id)
	_mats[id] = m
	return m

## 0.56 (tests/school_props_audit.gd): with `auditing` on, every box and cylinder laid down is kept with who laid it,
## so a test can find what floats and what stands in the way with nothing to stop a body.
static var auditing := false
var audit: Array = []
func _audit(r: int, at: Vector3, size: Vector3, id: String, collide: bool, basis: Basis, kind: String) -> void:
	var who := ""
	for f: Dictionary in get_stack():
		var fn: String = f.get("function", "")
		if fn in ["_audit", "bx", "cyl", "bar", "holed", "solid"]: continue
		who = "%s:%d" % [fn, int(f.get("line", 0))]
		break
	audit.append({"r": r, "at": at, "size": size, "id": id, "collide": collide, "basis": basis, "kind": kind, "who": who})

## A box in root `r` (0..4 a floor, 10 the shell, 11 the yard); `collide` gives it a collider in that root's body.
## 0.63: while set, what is laid down in root `_redirect[0]` goes to root `_redirect[1]` instead (the 2F desk wall).
var _redirect := Vector2i(-1, -1)
func bx(r: int, at: Vector3, size: Vector3, id: String, collide := false, basis := Basis.IDENTITY) -> CollisionShape3D:
	if r == _redirect.x: r = _redirect.y
	if auditing: _audit(r, at, size, id, collide, basis, "box")
	if not _kits[r].has(id): _kits[r][id] = InteriorBoxKit.new()
	_kits[r][id].box(size, Transform3D(basis, at))
	if not collide: return null
	return solid(r, at, size, basis)

func solid(r: int, at: Vector3, size: Vector3, basis := Basis.IDENTITY) -> CollisionShape3D:
	var c := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	c.shape = b
	c.transform = Transform3D(basis, at)
	bodies[r].add_child(c)
	return c

## 0.51: a flat box (slab, ceiling) with a rectangular hole [x0, x1, z0, z1] cut out of it.
func holed(r: int, at: Vector3, size: Vector3, hole: Array, id: String, collide: bool) -> void:
	var ax := at.x - size.x * .5
	var bxx := at.x + size.x * .5
	var az := at.z - size.z * .5
	var bz := at.z + size.z * .5
	var h0: float = hole[0]
	var h1: float = hole[1]
	var hz0: float = hole[2]
	var hz1: float = minf(hole[3], bz)
	for part: Array in [[ax, h0, az, bz], [h1, bxx, az, bz], [h0, h1, az, hz0], [h0, h1, hz1, bz]]:
		var w: float = float(part[1]) - float(part[0])
		var d: float = float(part[3]) - float(part[2])
		if w < .01 or d < .01: continue
		bx(r, Vector3((float(part[0]) + float(part[1])) * .5, at.y, (float(part[2]) + float(part[3])) * .5), Vector3(w, size.y, d), id, collide)

## 0.51: what came out of a wall someone broke through: chunks, dust, a bent stud.
func _rubble(k: int, at: Vector3) -> void:
	for i in 9:
		var p := at + Vector3(rng.randf_range(-1.1, 1.1), rng.randf_range(.04, .14), rng.randf_range(-1.0, 1.0))
		bx(k, p, Vector3(rng.randf_range(.12, .34), rng.randf_range(.06, .16), rng.randf_range(.1, .3)), "concrete_wall_008|#cfc6ac", false, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.4, .4)))
	bx(k, at + Vector3(0, .006, 0), Vector3(2.0, .008, 1.8), "#9a958a")
	bar(k, at + Vector3(0, 2.05, -.6), at + Vector3(.5, 1.2, -.3), .05, "#6a6a66")
	stain(lit(k), "spatter_floor", at + Vector3(.6, 0, .3), rng.randf() * TAU, 1.2, 1.0, .7)

func cyl(r: int, at: Vector3, radius: float, h: float, id: String, basis := Basis.IDENTITY, sides := 10) -> void:
	if r == _redirect.x: r = _redirect.y
	if auditing: _audit(r, at, Vector3(radius * 2.0, h, radius * 2.0), id, false, basis, "cyl")
	if not _kits[r].has(id): _kits[r][id] = InteriorBoxKit.new()
	_kits[r][id].cylinder(radius, h, sides, Transform3D(basis, at))

func bar(r: int, a: Vector3, b: Vector3, thick: float, id: String) -> void:
	var d := b - a
	if d.length() < .001: return
	var up: Vector3 = Vector3.UP if absf(d.normalized().y) < .98 else Vector3.RIGHT
	bx(r, (a + b) * .5, Vector3(thick, thick, d.length()), id, false, Basis.looking_at(d.normalized(), up))

## Root index of a floor's lights, decals and words.
func lit(k: int) -> int: return 5 + k

func label(r: int, at: Vector3, words: String, height: float, yaw: float, color := Color(.92, .9, .84), glow := false, reach := 22.0) -> Label3D:
	var l := Label3D.new()
	l.text = words
	l.pixel_size = height / 64
	l.font_size = 64
	l.outline_size = 3 if glow else 0
	l.modulate = color
	l.shaded = not glow
	l.double_sided = false
	l.rotation.y = yaw
	l.position = at
	l.visibility_range_end = reach
	roots[r].add_child(l)
	return l

func stain(r: int, kind: String, at: Vector3, yaw: float, length: float, width: float, alpha := .92) -> void:
	var t: Array = HorrorLiquid.texture_set(kind)
	var generated: bool = not t.is_empty()
	if not generated:
		var root := "res://assets/siege/"
		if not ResourceLoader.exists(root + kind + "_albedo.png"): return
		t = [load(root + kind + "_albedo.png"), load(root + kind + "_normal.png"), load(root + kind + "_orm.png")]
	var d := Decal.new()
	d.size = Vector3(length, .36, width)
	d.texture_albedo = t[0]
	d.texture_normal = t[1]
	d.texture_orm = t[2]
	d.modulate = Color(1, 1, 1, alpha)
	d.cull_mask = 8
	d.normal_fade = .35
	d.upper_fade = .2
	d.lower_fade = .2
	d.distance_fade_enabled = true
	d.distance_fade_begin = 26.0
	d.distance_fade_length = 6.0
	roots[r].add_child(d)
	d.position = at + Vector3.UP * .06
	d.rotation.y = yaw
	HorrorLiquid.finish(d, generated)

## Blood on a wall: `normal` points out of the wall into the room.
func smear(r: int, kind: String, at: Vector3, normal: Vector3, length: float, width: float, alpha := .9) -> void:
	var t: Array = HorrorLiquid.texture_set(kind)
	var generated: bool = not t.is_empty()
	if not generated:
		var root := "res://assets/siege/"
		if not ResourceLoader.exists(root + kind + "_albedo.png"): return
		t = [load(root + kind + "_albedo.png"), load(root + kind + "_normal.png"), load(root + kind + "_orm.png")]
	var d := Decal.new()
	d.texture_albedo = t[0]
	d.texture_normal = t[1]
	d.texture_orm = t[2]
	d.modulate = Color(1, 1, 1, alpha)
	d.size = Vector3(length, .3, width)
	d.cull_mask = 8
	d.normal_fade = .4
	d.distance_fade_enabled = true
	d.distance_fade_begin = 24.0
	d.distance_fade_length = 6.0
	roots[r].add_child(d)
	var up := normal.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < .95 else Vector3.RIGHT).normalized()
	d.transform = Transform3D(Basis(up, rng.randf_range(-.4, .4)) * Basis(side, up, side.cross(up)), at)
	HorrorLiquid.finish(d, generated)

func drag(r: int, a: Vector3, b: Vector3, pool := true) -> void:
	if pool: stain(r, "pool_big", a, rng.randf() * TAU, 1.5, 1.2)
	var d := b - a
	var n := maxi(1, ceili(Vector2(d.x, d.z).length() / 1.3))
	for i in n:
		var at := a.lerp(b, (i + .5) / n) + Vector3(rng.randf_range(-.08, .08), 0, rng.randf_range(-.08, .08))
		stain(r, ["drag_body_a", "drag_body_b", "drag_a"][i % 3], at, atan2(d.x, d.z) - PI * .5 + rng.randf_range(-.15, .15), 1.5, .6)

func omni(r: int, at: Vector3, color: Color, energy: float, reach: float, shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	l.distance_fade_enabled = true
	l.distance_fade_begin = 34.0
	l.distance_fade_length = 10.0
	l.light_specular = .35
	roots[r].add_child(l)
	return l

func place(r: int, path: String, at: Vector3, yaw_deg := 0.0, scale := 1.0) -> Node3D:
	var n: Node3D = InteriorModelKit.place(roots[r], path, at, yaw_deg, scale, "bottom", Vector3.ZERO)
	if n != null:
		for g in n.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).visibility_range_end = 60.0
	return n

func hum(r: int, at: Vector3, path: String, volume: float, unit: float) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	a.stream = load(path)
	a.volume_db = volume
	a.unit_size = unit
	a.max_distance = unit * 4.0
	a.autoplay = true
	a.position = at
	if a.stream is AudioStreamOggVorbis: (a.stream as AudioStreamOggVorbis).loop = true
	roots[r].add_child(a)
	return a

# ---------------------------------------------------------------- the clutter meshes (MultiMesh)

## The steel-framed armchair every Filipino classroom has: seat, back, the writing arm on the right.
func _chair_mesh() -> ArrayMesh:
	var frame := InteriorBoxKit.new()
	var wood := InteriorBoxKit.new()
	wood.box(Vector3(.44, .025, .42), Transform3D(Basis.IDENTITY, Vector3(0, .45, 0)))
	wood.box(Vector3(.42, .26, .022), Transform3D(Basis(Vector3.RIGHT, -.12), Vector3(0, .78, .21)))
	wood.box(Vector3(.26, .02, .46), Transform3D(Basis.IDENTITY, Vector3(.31, .7, -.05)))
	for p in [Vector3(-.2, .225, -.18), Vector3(.2, .225, -.18), Vector3(-.2, .225, .19), Vector3(.2, .225, .19)]:
		frame.box(Vector3(.024, .45, .024), Transform3D(Basis.IDENTITY, p))
	for x in [-.2, .2]: frame.box(Vector3(.022, .44, .022), Transform3D(Basis(Vector3.RIGHT, -.12), Vector3(x, .66, .2)))
	frame.box(Vector3(.02, .26, .02), Transform3D(Basis.IDENTITY, Vector3(.36, .57, .05)))
	frame.box(Vector3(.4, .02, .02), Transform3D(Basis.IDENTITY, Vector3(0, .12, -.18)))
	var mesh := ArrayMesh.new()
	for kit in [frame, wood]:
		var part: ArrayMesh = kit.commit()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part.surface_get_arrays(0))
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("#33403a")
	steel.roughness = .55
	steel.metallic = .4
	mesh.surface_set_material(0, steel)
	var top := StandardMaterial3D.new()
	top.albedo_texture = load("res://assets/outdoor/textures/dark_wooden_planks/albedo.jpg")
	top.albedo_color = Color("#c59a6a")
	top.roughness = .7
	mesh.surface_set_material(1, top)
	return mesh

func _paper_mesh() -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(.21, .297)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/school/paper.png")
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = .9
	p.material = m
	return p

func _book_mesh() -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(.17, .035, .24)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = .8
	b.material = m
	return b

## A chair at `at` (floor height), as it was left: upright and pushed about, on its side, or on its back.
## (0.56: on its side always on the plain side: on the other its writing arm went 22 cm into the floor; and no
## longer upside down: it stood on the top of its back with the rest of it in the air.)
func chair(k: int, at: Vector3, yaw: float, mess := .5) -> void:
	var b := Basis(Vector3.UP, yaw)
	var lift := 0.0
	var roll := rng.randf()
	if roll < mess * .48:
		b = b * Basis(Vector3.FORWARD, -PI * .5)
		lift = .225
	elif roll < mess * .62:
		b = b * Basis(Vector3.RIGHT, -PI * .5)
		lift = .185
	_chairs[k].append(Transform3D(b, at + Vector3.UP * lift))

## 0.56: a school desk (top and four legs) standing at `at` (floor height), or upside down on it (`upside`).
func _desk(k: int, at: Vector3, yaw: float, upside := false) -> void:
	var b := Basis(Vector3.UP, yaw)
	var top_y := .02 if upside else .74
	var leg_y := .4 if upside else .36
	bx(k, at + Vector3.UP * top_y, Vector3(1.2, .04, .6), "dark_wooden_planks|#8a6a4a", false, b)
	for p in [Vector3(-.55, 0, -.25), Vector3(.55, 0, -.25), Vector3(-.55, 0, .25), Vector3(.55, 0, .25)]:
		bx(k, at + b * p + Vector3.UP * leg_y, Vector3(.03, .72, .03), "#33403a", false, b)

## 0.56: furniture piled the way people pile it in a hurry, in `size` (x, z) round `c` (floor height): desks on the
## floor, desks upside down on those, desks standing on their legs on top, chairs on the top; a cabinet here and
## there instead of a desk. Everything rests on the floor or on what is under it (it used to hang in the air in a
## cloud, chairs and desks at any angle). `layers` 1..3; `crown` puts the chairs on top.
func _pile(k: int, c: Vector3, size: Vector2, layers: int, crown := true) -> void:
	var along_z := size.y > size.x
	var step := Vector2(.66, 1.26) if along_z else Vector2(1.26, .66)
	var nx := maxi(1, int(size.x / step.x))
	var nz := maxi(1, int(size.y / step.y))
	var base_yaw := PI * .5 if along_z else 0.0
	var tops: Array = []
	for i in nx:
		for j in nz:
			var at := c + Vector3((i - (nx - 1) * .5) * step.x + rng.randf_range(-.04, .04), 0, (j - (nz - 1) * .5) * step.y + rng.randf_range(-.04, .04))
			var yaw := base_yaw + rng.randf_range(-.12, .12)
			if rng.randf() < .2:
				# A filing cabinet stood in the gap.
				bx(k, at + Vector3.UP * .55, Vector3(.5, 1.1, .45), ["#5d6b64", "#7a7466", "#3e6b55"][rng.randi() % 3], false, Basis(Vector3.UP, yaw))
				if crown and layers == 1: tops.append(at + Vector3.UP * 1.1)
				continue
			_desk(k, at, yaw)
			var top := at + Vector3.UP * .76
			if layers >= 2:
				_desk(k, top + Vector3(rng.randf_range(-.03, .03), 0, rng.randf_range(-.03, .03)), yaw + rng.randf_range(-.08, .08), true)
				top = at + Vector3.UP * 1.52
				if layers >= 3:
					_desk(k, top, yaw + rng.randf_range(-.1, .1))
					top = at + Vector3.UP * 2.28
			tops.append(top)
	# Desk tops stood on edge along both faces of every layer, on the floor or on the desks under them: the pile is a
	# wall seen from either side, not a frame to look (and try to walk) through.
	var levels: Array = [0.0]
	if layers >= 2: levels.append(.76)
	if layers >= 3: levels.append_array([1.52, 2.28])
	var span := size.y if along_z else size.x
	var boards := maxi(1, ceili(span / 1.0))
	for lv: float in levels:
		for face: float in [-1.0, 1.0]:
			for n in boards:
				var u := (n - (boards - 1) * .5) * 1.0
				var off: float = face * (((nx - 1) * .5 * step.x if along_z else (nz - 1) * .5 * step.y) + .27)
				var at := c + (Vector3(off, lv + .3, u) if along_z else Vector3(u, lv + .3, off))
				var board_yaw := (PI * .5 if along_z else 0.0) + rng.randf_range(-.06, .06)
				bx(k, at + Vector3(rng.randf_range(-.02, .02), 0, rng.randf_range(-.02, .02)), Vector3(1.2, .6, .04), "dark_wooden_planks|#8a6a4a", false, Basis(Vector3.UP, board_yaw))
	if not crown: return
	for t: Vector3 in tops:
		if rng.randf() < .7: chair(k, t + Vector3(rng.randf_range(-.15, .15), 0, rng.randf_range(-.15, .15)), rng.randf() * TAU, .7)

func papers(k: int, centre: Vector3, spread: Vector2, n: int, bloody := .1) -> void:
	for i in n:
		var at := centre + Vector3(rng.randf_range(-spread.x, spread.x), .009 + rng.randf() * .006, rng.randf_range(-spread.y, spread.y))
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.06, .06))
		var c := Color(.92, .91, .86)
		var roll := rng.randf()
		if roll < bloody: c = Color(.62, .2, .17)
		elif roll < bloody + .25: c = Color(.8, .76, .64)
		_papers[k].append([Transform3D(b, at), c])

func books(k: int, centre: Vector3, spread: Vector2, n: int) -> void:
	var colours := [Color("#7a2a26"), Color("#24406a"), Color("#2f5a3a"), Color("#a08a3a"), Color("#3a3a3a"), Color("#6a4a7a"), Color("#c8c0aa")]
	for i in n:
		var at := centre + Vector3(rng.randf_range(-spread.x, spread.x), .026 + rng.randf() * .04, rng.randf_range(-spread.y, spread.y))
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, rng.randf_range(-.25, .25))
		_books[k].append([Transform3D(b, at), colours[rng.randi() % colours.size()]])

## Bags, shoes, notebooks, a water bottle: what students drop when they run (`centre` is on the floor).
func belongings(r: int, centre: Vector3, spread: Vector2, n: int) -> void:
	var bags := ["#1f2a44", "#2b2b2e", "#5a1e24", "#3b4a2a", "#6a5a4a", "#24345a"]
	for i in n:
		var at := centre + Vector3(rng.randf_range(-spread.x, spread.x), 0, rng.randf_range(-spread.y, spread.y))
		var roll := rng.randf()
		var yaw := rng.randf() * TAU
		if roll < .45:
			var flat := rng.randf() < .6
			var tip: Basis = Basis(Vector3.UP, yaw) * (Basis(Vector3.RIGHT, -PI * .5) if flat else Basis.IDENTITY)
			bx(r, at + Vector3.UP * (.09 if flat else .22), Vector3(.32, .42, .16), bags[rng.randi() % bags.size()], false, tip)
		elif roll < .7:
			for j in (1 if rng.randf() < .6 else 2):
				bx(r, at + Vector3(j * .14, .05, j * .05), Vector3(.1, .08, .26), "#151515" if rng.randf() < .7 else "#d9d6cc", false, Basis(Vector3.UP, yaw + j * .4))
		elif roll < .85:
			bx(r, at + Vector3.UP * .02, Vector3(.17, .02, .24), ["#c43b2b", "#2a5a9a", "#e0c040", "#3a8a5a"][rng.randi() % 4], false, Basis(Vector3.UP, yaw))
		else:
			cyl(r, at + Vector3.UP * .045, .035, .22, "glass#9fc7e090", Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, PI * .5), 8)

## A ceiling fixture: two tubes in a white housing. `state` 0 dead, 1 steady, 2 flickering, 3 dying, 4 hanging dead.
func fixture(k: int, at: Vector3, along_x: bool, state: int, shadows := false, energy := 1.25, reach := 6.5) -> void:
	var size: Vector3 = Vector3(1.25, .07, .26) if along_x else Vector3(.26, .07, 1.25)
	var tube: Vector3 = Vector3(1.18, .03, .035) if along_x else Vector3(.035, .03, 1.18)
	if state == 4:
		var tilt := Basis(Vector3.FORWARD if along_x else Vector3.RIGHT, .55)
		bx(k, at + Vector3(0, -.35, 0), size, "#cfcfc6", false, tilt)
		bar(k, at + (Vector3(.55, 0, 0) if along_x else Vector3(0, 0, .55)), at + Vector3(0, -.05, 0) + (Vector3(.55, 0, 0) if along_x else Vector3(0, 0, .55)), .01, "#111111")
		return
	bx(k, at, size, "#cfcfc6")
	var off: Vector3 = Vector3(0, 0, .06) if along_x else Vector3(.06, 0, 0)
	if state == 0:
		for sgn in [-1, 1]: bx(k, at + off * sgn + Vector3.DOWN * .045, tube, "#8e918c")
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(.85, .9, .92)
	m.emission_enabled = true
	m.emission = TUBE
	m.emission_energy_multiplier = 2.4
	for sgn in [-1, 1]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = tube
		mi.mesh = bm
		mi.material_override = m
		mi.position = at + off * sgn + Vector3.DOWN * .045
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		roots[lit(k)].add_child(mi)
	var l := omni(lit(k), at + Vector3.DOWN * .25, TUBE, energy, reach, shadows)
	lamps.append([l, energy, state, rng.randf_range(.6, 2.4), m])

# ---------------------------------------------------------------- walls

## A wall plane: along x (constant z = `c`) when `along_x`, else along z (constant x). From `a` to `b`, height `hgt`
## from `y0`, `thick` thick, with `holes` [[u0, u1, v0, v1]] cut out (u along the wall, v up from y0). `core` is the
## wall's own material; interior walls get the green wainscot on both faces, exterior walls (`skin` -1/+1) a cream
## skin with the wainscot on that face only (into the floor root `k`), their core in the shell.
func wall(k: int, along_x: bool, c: float, a: float, b: float, y0: float, hgt: float, holes: Array, thick := .2, core := "s:cream", skin := 0, r := -1, collide := true) -> void:
	var cuts: Array = [a, b]
	for h: Array in holes:
		cuts.append(clampf(h[0], a, b))
		cuts.append(clampf(h[1], a, b))
	cuts.sort()
	var rr: int = k if r < 0 else r
	for i in cuts.size() - 1:
		var u0: float = cuts[i]
		var u1: float = cuts[i + 1]
		if u1 - u0 < .005: continue
		var spans: Array = [[0.0, hgt]]
		for h: Array in holes:
			if h[0] <= u0 + .001 and h[1] >= u1 - .001:
				var next: Array = []
				for sp: Array in spans:
					if h[3] <= sp[0] or h[2] >= sp[1]: next.append(sp)
					else:
						if h[2] > sp[0]: next.append([sp[0], h[2]])
						if h[3] < sp[1]: next.append([h[3], sp[1]])
				spans = next
		for sp: Array in spans:
			var v0: float = sp[0]
			var v1: float = sp[1]
			if v1 - v0 < .005: continue
			var mid: Vector3 = Vector3((u0 + u1) * .5, y0 + (v0 + v1) * .5, c) if along_x else Vector3(c, y0 + (v0 + v1) * .5, (u0 + u1) * .5)
			var size: Vector3 = Vector3(u1 - u0, v1 - v0, thick) if along_x else Vector3(thick, v1 - v0, u1 - u0)
			bx(rr, mid, size, core, collide)
			var faces: Array = [-1, 1] if skin == 0 else [skin]
			for f: int in faces:
				var n: Vector3 = Vector3(0, 0, f) if along_x else Vector3(f, 0, 0)
				var face := mid + n * (thick * .5)
				if skin != 0:
					bx(k, face + n * .008, size * (Vector3(1, 1, 0) if along_x else Vector3(0, 1, 1)) + n.abs() * .016, "s:cream")
				if v0 < 1.25:
					var top := minf(v1, 1.25)
					var w_mid := Vector3(mid.x, y0 + (v0 + top) * .5, mid.z) + n * (thick * .5 + .012)
					var w_size: Vector3 = Vector3(u1 - u0, top - v0, .024) if along_x else Vector3(.024, top - v0, u1 - u0)
					bx(k, w_mid, w_size, "s:green")
					if top >= 1.24:
						bx(k, Vector3(mid.x, y0 + 1.25, mid.z) + n * (thick * .5 + .02), w_size * Vector3(1, 0, 1) + Vector3(0, .035, 0) + (Vector3(0, 0, .014) if along_x else Vector3(.014, 0, 0)), "#24392e")
				if v0 < .01:
					var base := Vector3(mid.x, y0 + .05, mid.z) + n * (thick * .5 + .026)
					bx(k, base, (Vector3(u1 - u0, .1, .02) if along_x else Vector3(.02, .1, u1 - u0)), "#1b1f1c")

# ---------------------------------------------------------------- a floor

func _floor(k: int) -> void:
	var y := k * H
	_slab(k)
	# Drop ceiling: the rooms and the corridor (not the stairwells, nor over the grand stair's well).
	var ceil_y := y + 3.22
	bx(k, Vector3(28, ceil_y, 518.1), Vector3(55.4, .025, 7.6), "s:ceiling")
	bx(k, Vector3(28, ceil_y, CZ), Vector3(55.4, .025, 3.2), "s:ceiling")
	if k == 0:
		bx(k, Vector3(15.1, ceil_y, 529.4), Vector3(18.0, .025, 8.6), "s:ceiling")
		bx(k, Vector3(40.9, ceil_y, 529.4), Vector3(18.0, .025, 8.6), "s:ceiling")
	elif k == 3:
		holed(k, Vector3(28, ceil_y, 529.4), Vector3(43.8, .025, 8.6), HATCH, "s:ceiling", false)
	else:
		bx(k, Vector3(28, ceil_y, 529.4), Vector3(43.8, .025, 8.6), "s:ceiling")
	# A few tiles down: the grid shows, wires hang.
	for i in 3:
		var at := Vector3(rng.randf_range(8, 48), y, CZ + rng.randf_range(-.9, .9))
		bx(k, at + Vector3.UP * .03, Vector3(.6, .02, .6), "s:ceiling", false, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.2, .2)))
		bx(k, Vector3(at.x, ceil_y - .005, at.z), Vector3(.58, .02, .58), "#14120f")
		bar(k, Vector3(at.x, ceil_y, at.z), Vector3(at.x + .1, ceil_y - .7, at.z + .05), .012, "#111111")
	_corridor_walls(k)
	_partitions(k)
	_stairs(k)
	for room: Array in ROOMS[k]: _room(k, room)
	_corridor(k)

func _slab(k: int) -> void:
	var y := k * H
	var t: float = .4 if k == 0 else .3
	var top := Vector3.UP * (y - t * .5)
	# South rooms, the corridor, the north rooms between the stairwells (the grand stair's well open on the 2nd).
	bx(k, Vector3(28, 0, 518.1) + top, Vector3(55.4, t, 7.6), "s:classroom", true)
	bx(k, Vector3(28, 0, CZ) + top, Vector3(55.4, t, 3.2), "s:corridor", true)
	if k == 1:
		bx(k, Vector3(15.05, 0, 529.4) + top, Vector3(17.9, t, 8.6), "s:classroom", true)
		bx(k, Vector3(40.95, 0, 529.4) + top, Vector3(17.9, t, 8.6), "s:classroom", true)
		# The grand stair's galleries and landing.
		bx(k, Vector3(25.15, 0, 528.55) + top, Vector3(2.1, t, 6.9), "s:checker", true)
		bx(k, Vector3(30.85, 0, 528.55) + top, Vector3(2.1, t, 6.9), "s:checker", true)
		bx(k, Vector3(28, 0, 532.85) + top, Vector3(7.8, t, 1.7), "s:checker", true)
	elif k == 4:
		# The hatch the janitor's ladder comes up through.
		holed(k, Vector3(28, 0, 529.4) + top, Vector3(43.8, t, 8.6), HATCH, "s:classroom", true)
	else:
		bx(k, Vector3(28, 0, 529.4) + top, Vector3(43.8, t, 8.6), "s:classroom", true)
		if k == 0: bx(k, Vector3(28, y + .003, 529.4), Vector3(7.8, .006, 8.6), "s:checker")
	# Stairwells: the ground under them, or each floor's landing strip.
	for x0 in [0.3, 50.1]:
		if k == 0:
			bx(k, Vector3(x0 + 2.8, 0, 529.4) + top, Vector3(5.6, t, 8.6), "concrete_floor_02|#8a8780", true)
		else:
			bx(k, Vector3(x0 + 2.8, 0, 525.75) + top, Vector3(5.6, t, 1.3), "concrete_floor_02|#8a8780", true)

## The corridor's two walls, with every room's door, the stairwells' openings, the lobby and the grand stair.
func _corridor_walls(k: int) -> void:
	var y := k * H
	var south: Array = []
	var north: Array = []
	for room: Array in ROOMS[k]:
		var kind: String = room[3]
		var x0: float = room[0]
		var x1: float = room[1]
		var list: Array = south if room[2] == "s" else north
		if kind == "lobby":
			list.append([x0 + .2, x1 - .2, 0.0, 2.9])
		elif kind == "grand":
			list.append([x0 + .2, x1 - .2, 0.0, 2.9])
		elif kind == "gallery":
			list.append([24.3, 26.1, 0.0, 2.3])
			list.append([29.9, 31.7, 0.0, 2.3])
			list.append([26.1, 29.9, 1.05, 2.9])
		else:
			for dx in _doors(room): list.append([dx - .5, dx + .5, 0.0, 2.15])
	north.append([.8, 5.4, 0.0, 2.4])
	north.append([50.6, 55.2, 0.0, 2.4])
	wall(k, true, 522.0, 0.3, 55.7, y, H - .3, south)
	wall(k, true, 525.0, 0.3, 55.7, y, H - .3, north)

## A place along a corridor wall (south or north) where `width` of wall is solid: no door, no stair opening, not the
## lobby or the grand stair. NAN when none was found.
func _free_x(k: int, south: bool, width: float) -> float:
	var holes: Array = []
	for room: Array in ROOMS[k]:
		if (room[2] == "s") != south: continue
		if room[3] in ["lobby", "grand", "gallery"]: holes.append([float(room[0]), float(room[1])])
		else:
			for dx in _doors(room): holes.append([float(dx) - .6, float(dx) + .6])
	if not south:
		holes.append([0.0, 6.2])
		holes.append([49.8, 56.0])
	for attempt in 24:
		var x := rng.randf_range(2.0, 54.0)
		var ok := true
		for h: Array in holes:
			if x + width * .5 > float(h[0]) and x - width * .5 < float(h[1]): ok = false
		if ok: return x
	return NAN

func _doors(room: Array) -> Array:
	var x0: float = room[0]
	var x1: float = room[1]
	if x1 - x0 > 12.0: return [x0 + 1.3, x1 - 1.3]
	return [x1 - 1.1]

## The walls between the rooms, and the stairwells' side walls.
func _partitions(k: int) -> void:
	var y := k * H
	for side in ["s", "n"]:
		var list: Array = []
		for room: Array in ROOMS[k]:
			if room[2] == side: list.append(room)
		list.sort_custom(func(p, q): return float(p[0]) < float(q[0]))
		for i in list.size() - 1:
			var cx: float = (float(list[i][1]) + float(list[i + 1][0])) * .5
			var holes: Array = []
			for br: Array in BREACHES:
				if int(br[0]) == k and br[1] == side and absf(float(br[2]) - cx) < .3:
					holes.append([br[3], br[4], 0.0, 2.05])
					_rubble(k, Vector3(cx, y, (float(br[3]) + float(br[4])) * .5))
			if k == 4 and side == "n" and cx > DUCT[0] and cx < DUCT[1]:
				holes.append([DUCT[2], DUCT[3], 0.0, DUCT_H + .08])
			if side == "s": wall(k, false, cx, 514.3, ZS - .1, y, H - .3, holes)
			else: wall(k, false, cx, ZN + .1, 533.7, y, H - .3, holes)
	wall(k, false, 6.0, ZN + .1, 533.7, y, H - .3, [])
	wall(k, false, 50.0, ZN + .1, 533.7, y, H - .3, [])
	# The grand stair's well on the second floor: half walls round it.
	if k == 1:
		bx(k, Vector3(26.2, y + .5, 528.55), Vector3(.14, 1.0, 6.9), "s:cream", true)
		bx(k, Vector3(29.8, y + .5, 528.55), Vector3(.14, 1.0, 6.9), "s:cream", true)
		for x in [26.2, 29.8]: bx(k, Vector3(x, y + 1.02, 528.55), Vector3(.2, .05, 6.95), "dark_wooden_planks|#5a3a24")

# ---------------------------------------------------------------- stairs

func _ramp(k: int, a: Vector3, b: Vector3, width: float, steps: int, collide := true, id := "") -> void:
	var d := b - a
	var run := Vector2(d.x, d.z).length()
	var dir := Vector3(d.x, 0, d.z).normalized()
	var angle := atan2(d.y, run)
	var yaw := atan2(dir.x, dir.z)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -angle)
	var length := d.length()
	var mid := (a + b) * .5 - basis.y * .1
	bx(k, mid, Vector3(width, .2, length), "concrete_floor_02|#77746d" if id == "" else id, collide, basis)
	var rise := d.y / steps
	var tread := run / steps
	for i in steps:
		var c := a + dir * (tread * (i + .5)) + Vector3.UP * (rise * (i + .5))
		var step: Vector3 = Vector3(width, absf(rise), tread) if absf(dir.z) > .5 else Vector3(tread, absf(rise), width)
		bx(k, c, step, "s:classroom|#bdb6a8" if id == "" else id)
		var nose := a + dir * (tread * i) + Vector3.UP * (rise * (i + 1))
		var strip: Vector3 = Vector3(width, .02, .06) if absf(dir.z) > .5 else Vector3(.06, .02, width)
		bx(k, nose + dir * .03, strip, "#2b2b28")

func _stairs(k: int) -> void:
	var y := k * H
	for st in [STAIR_W, STAIR_E]:
		var a_x: float = 1.65 if st == STAIR_W else 54.35
		var b_x: float = 4.55 if st == STAIR_W else 51.45
		var core_x: float = 3.1 if st == STAIR_W else 52.9
		var x0: float = 0.3 if st == STAIR_W else 50.1
		if k < 4:
			# Flight A up toward the north wall, the turn, flight B back to the next floor's landing.
			_ramp(k, Vector3(a_x, y, 526.4), Vector3(a_x, y + 1.8, 529.4), 2.3, 11)
			_ramp(k, Vector3(b_x, y + 1.8, 529.4), Vector3(b_x, y + H, 526.4), 2.3, 11)
			bx(k, Vector3(x0 + 2.8, y + 1.65, 531.55), Vector3(5.6, .3, 4.3), "concrete_floor_02|#8a8780", true)
			bx(k, Vector3(core_x, y + H * .5, 527.9), Vector3(.5, H, 3.0), "s:cream", true)
			# Handrails along the core.
			var a_side: float = -1.0 if st == STAIR_W else 1.0
			bar(k, Vector3(core_x + a_side * .27, y + .95, 526.4), Vector3(core_x + a_side * .27, y + 2.75, 529.4), .04, "#2b3a30")
			bar(k, Vector3(core_x - a_side * .27, y + H + .95, 526.4), Vector3(core_x - a_side * .27, y + 2.75, 529.4), .04, "#2b3a30")
			if k == 0:
				bx(k, Vector3(x0 + 2.8, y + .75, 531.55), Vector3(5.6, 1.5, 4.3), "s:cream", true)
			if [st, k] in BLOCKED: _barricade(k, st)
			else:
				# Emergency light on the turn: the generator keeps it red.
				var e := Vector3(x0 + 2.8, y + 3.2, 533.45)
				bx(k, e, Vector3(.3, .12, .12), "#cfcfc6")
				bx(k, e + Vector3(0, -.07, -.02), Vector3(.22, .04, .06), "glow#ff5a3a*3.0")
				lamps.append([omni(lit(k), e + Vector3(0, -.3, -.4), Color(1.0, .38, .26), .9, 6.5), .9, 2 if rng.randf() < .4 else 1, rng.randf_range(.6, 2.0), null])
		else:
			# The top floor: no flight up, a rail where flight A would start.
			bx(k, Vector3(a_x, y + .5, 526.45), Vector3(2.3, 1.0, .1), "s:cream", true)
		# Signs and the EXIT light over the opening (on the corridor side).
		var sign_x: float = 3.1 if st == STAIR_W else 52.9
		bx(k, Vector3(sign_x, y + 2.62, 524.86), Vector3(.62, .2, .05), "#141414")
		bx(k, Vector3(sign_x, y + 2.62, 524.83), Vector3(.56, .15, .02), "glow#29d26b*2.2")
		label(lit(k), Vector3(sign_x, y + 2.62, 524.81), "EXIT", .13, PI, Color(.05, .2, .08), false, 30.0)
		omni(lit(k), Vector3(sign_x, y + 2.45, 524.4), Color(.3, 1.0, .5), .22, 3.2)
		label(lit(k), Vector3(sign_x, y + 2.92, 524.82), ("WEST" if st == STAIR_W else "EAST") + " STAIRS  •  " + FLOOR_NAMES[k].to_upper(), .075, PI)
	if k == 0:
		# The grand stair: lobby to the second floor, straight up the north bay.
		_ramp(k, Vector3(28, 0, 526.0), Vector3(28, H, 532.0), 3.2, 22)
		for x in [26.35, 29.65]:
			for seg: Array in [[526.9, 528.5, .55], [528.5, 529.7, 1.5], [529.7, 530.9, 2.2], [530.9, 532.0, 2.9]]:
				bx(k, Vector3(x, float(seg[2]) * .5, (float(seg[0]) + float(seg[1])) * .5), Vector3(.1, float(seg[2]), float(seg[1]) - float(seg[0])), "s:cream", true)
		bx(k, Vector3(28, 1.45, 531.95), Vector3(3.2, 2.9, .1), "s:cream", true)
		for x in [26.3, 29.7]:
			var basis := Basis(Vector3.RIGHT, -atan2(H, 6.0))
			bx(k, Vector3(x, H * .5 + .5, 529.0), Vector3(.12, 1.0, 7.0), "s:cream", true, basis)
			bx(k, Vector3(x, H * .5 + 1.02, 529.0), Vector3(.18, .05, 7.0), "dark_wooden_planks|#5a3a24", false, basis)
		label(lit(k), Vector3(28, 2.75, 524.85), "TO THE SECOND FLOOR", .1, PI)

## Desks, armchairs and a cabinet jammed into the turn of a stairwell: nobody gets past it either way.
func _barricade(k: int, st: int) -> void:
	var y := k * H + 1.8
	var x0: float = 0.3 if st == STAIR_W else 50.1
	var c := Vector3(x0 + 2.8, y, 531.5)
	# (0.59: 1.52 m, the pile's own top, was 1.7: the chairs crowning it stood 18 cm inside it and jumped out when woken.)
	var shape := solid(k, c + Vector3.UP * .76, Vector3(5.6, 1.52, 4.3))
	# The pile spills onto the top of flight A and the foot of flight B: blocked to everyone.
	var a_x: float = 1.65 if st == STAIR_W else 54.35
	var b_x: float = 4.55 if st == STAIR_W else 51.45
	solid(k, Vector3(a_x, y + .3, 528.6), Vector3(2.3, 1.9, 1.4))
	solid(k, Vector3(b_x, y + .5, 528.7), Vector3(2.3, 2.2, 1.2))
	# (0.56: piled on the landing, two high, chairs on top; the spill down the flights sits on the steps. All of it
	# used to hang in the air at any angle.)
	_pile(k, c, Vector2(5.0, 3.6), 2)
	bx(k, c + Vector3(rng.randf_range(-1, 1), .225, 1.95), Vector3(1.8, .45, .9), "#5d6b64", false, Basis(Vector3.UP, rng.randf_range(-.2, .2)))
	var y0 := k * H
	for i in 6:
		var on_a := i < 3
		var sx: float = (a_x if on_a else b_x) + rng.randf_range(-.6, .6)
		# (0.59: on the steps below the spill's colliders, 526.8-527.8; 527.4-528.8 put them inside those.)
		var sz := rng.randf_range(526.8, 527.8)
		# (0.59: standing on the flight's slope, its collider (`_ramp`: 1.8 m over 526.4-529.4), tilted with it, where
		# friction holds them. On the treads they stood 9 cm over the slope and slid off down the stairs once woken.)
		var sy := (y0 + .6 * (sz - 526.4)) if on_a else (y0 + 1.8 + .6 * (529.4 - sz))
		var tilt := atan(.6) * (-1.0 if on_a else 1.0)
		_chairs[k].append(Transform3D(Basis(Vector3.RIGHT, tilt) * Basis(Vector3.UP, rng.randf() * TAU), Vector3(sx, sy + .01, sz)))
	var e := Vector3(x0 + 2.8, k * H + 3.2, 533.45)
	bx(k, e, Vector3(.3, .12, .12), "#cfcfc6")
	bx(k, e + Vector3(0, -.07, -.02), Vector3(.22, .04, .06), "glow#ff5a3a*2.0")
	lamps.append([omni(lit(k), e + Vector3(0, -.4, -.6), Color(1.0, .38, .26), .8, 6.0), .8, 3, rng.randf_range(.6, 2.0), null])
	# A note taped to the wall at the foot, in marker: where to go instead.
	var other: String = ["BLOCKED\nuse the MAIN stairs (lobby)", "BLOCKED\nBOTH STAIRS\nfire exit - east end\nof the hall", "BLOCKED\nuse WEST stairs",
		"BLOCKED. BOTH.\nKuya Boy's ladder\nin MAINTENANCE\ngoes up to 5th\n(the vent)"][k]
	var note_x: float = (0.4 if st == STAIR_W else 55.6)
	var note_at := Vector3(note_x, k * H + 1.5, 526.0)
	bx(k, note_at, Vector3(.01, .36, .42), "#ece8dc")
	label(lit(k), note_at + Vector3(.012 if st == STAIR_W else -.012, 0, 0), other, .05, PI * .5 if st == STAIR_W else -PI * .5, Color(.08, .08, .1))

# ---------------------------------------------------------------- the corridor

func _corridor(k: int) -> void:
	var y := k * H
	# Tubes down the middle (0.51: the generator is nearly gone: most of the hall is dark, a tube stutters here and
	# there far ahead, one hangs by its wires and swings).
	var x := 3.6
	var n := 0
	var swung := false
	while x < 53.0:
		var roll := rng.randf()
		var state := 0
		if roll < .05: state = 1
		elif roll < .15: state = 2
		elif roll < .27: state = 3
		elif roll < .4: state = 4
		if state == 4 and not swung and x > 10.0:
			swung = true
			_swinging(k, Vector3(x, y + 3.18, CZ))
		else:
			fixture(k, Vector3(x, y + 3.18, CZ), true, state, false, 1.1, 6.5)
		if state > 0: n += 1
		x += rng.randf_range(4.4, 6.2)
	if not swung: _swinging(k, Vector3(rng.randf_range(12, 44), y + 3.18, CZ))
	# Near the way on, a tube still stutters: something to walk toward in the dark.
	fixture(k, Vector3(way_on_x(k), y + 3.18, CZ - .4), true, 2, false, .9, 6.0)
	if k >= ROUTE_FIRE:
		# The fire exit at the east end: the door kicked out, its sign still green. (0.52: every floor above the
		# ground has one now: the fire escape goes up to the fifth.)
		bx(k, Vector3(55.6, y + 2.62, CZ), Vector3(.05, .2, .7), "#141414")
		bx(k, Vector3(55.57, y + 2.62, CZ), Vector3(.02, .15, .62), "glow#29d26b*2.2")
		label(lit(k), Vector3(55.55, y + 2.62, CZ), "FIRE EXIT", .1, -PI * .5, Color(.05, .2, .08), false, 40.0)
		omni(lit(k), Vector3(55.2, y + 2.4, CZ), Color(.3, 1.0, .5), .3, 4.0)
	for hb: Array in HALL_BLOCKS:
		if int(hb[0]) == k: _hall_block(k, float(hb[1]))
	# Room numbers over the doors, a fire hose cabinet, notice boards, bins, a bench.
	for room: Array in ROOMS[k]:
		if room[4] == "" or room[3] in ["lobby", "grand", "gallery"]: continue
		var south: bool = room[2] == "s"
		var wz: float = (522.0 + .12) if south else (525.0 - .12)
		var yaw: float = 0.0 if south else PI
		var dx: float = _doors(room)[0]
		var words: String = room[4]
		if words.is_valid_int(): words = "ROOM " + words
		bx(k, Vector3(dx, y + 2.45, wz - (.01 if south else -.01)), Vector3(maxf(.7, words.length() * .075), .2, .02), "#e6e0cc")
		label(lit(k), Vector3(dx, y + 2.45, wz + (.005 if south else -.005)), words, .085, yaw, Color(.12, .12, .14))
	for i in 2:
		var on_south := rng.randf() < .5
		var bx_at := _free_x(k, on_south, 2.1)
		if is_nan(bx_at): continue
		var wz2: float = (522.0 + .115) if on_south else (525.0 - .115)
		bx(k, Vector3(bx_at, y + 1.65, wz2), Vector3(2.0, 1.1, .03), "#8a6a46")
		for j in 9:
			var p := Vector3(bx_at + rng.randf_range(-.85, .85), y + 1.65 + rng.randf_range(-.4, .4), wz2 + (.02 if on_south else -.02))
			bx(k, p, Vector3(.21, .29, .004), "#ece8dc" if rng.randf() < .7 else "#f0d070", false, Basis(Vector3.FORWARD, rng.randf_range(-.15, .15)))
		label(lit(k), Vector3(bx_at, y + 2.32, wz2 + (.02 if on_south else -.02)), ["ANNOUNCEMENTS", "STEM 12 CLASS SCHEDULE", "LOST AND FOUND", "FOUNDATION WEEK 2026", "SSG ELECTION RESULTS"][rng.randi() % 5], .07, 0.0 if on_south else PI)
	var hose_x := _free_x(k, false, .8)
	if is_nan(hose_x): hose_x = 33.0
	bx(k, Vector3(hose_x, y + 1.3, 525.0 - .16), Vector3(.7, .9, .12), "#a3231c")
	bx(k, Vector3(hose_x, y + 1.3, 525.0 - .23), Vector3(.58, .78, .01), "glass")
	label(lit(k), Vector3(hose_x, y + 1.82, 525.0 - .23), "FIRE HOSE", .06, PI, Color(.95, .9, .85))
	# The mess: papers, chairs dragged out, what was dropped, blood pooled and pulled along.
	papers(k, Vector3(28, y, CZ), Vector2(26.5, 1.25), 150, .14)
	belongings(k, Vector3(28, y, CZ), Vector2(26.0, 1.2), 22)
	for i in 10: chair(k, Vector3(rng.randf_range(2, 54), y, CZ + rng.randf_range(-1.2, 1.2)), rng.randf() * TAU, .9)
	for i in 5:
		var a := Vector3(rng.randf_range(6, 50), y, CZ + rng.randf_range(-.8, .8))
		drag(lit(k), a, a + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-.8, .8)))
	for i in 6: stain(lit(k), ["spatter_floor", "splat_a", "splat_b", "pool"][i % 4], Vector3(rng.randf_range(4, 52), y, CZ + rng.randf_range(-.9, .9)), rng.randf() * TAU, rng.randf_range(1.0, 1.6), rng.randf_range(1.0, 1.5), .85)
	for i in 6:
		var on_s := rng.randf() < .5
		smear(lit(k), "smear_wall", Vector3(rng.randf_range(6, 50), y + rng.randf_range(.7, 1.5), 522.1 if on_s else 524.9), Vector3(0, 0, 1 if on_s else -1), 1.4, .8)
	# A leak where a pipe gave: water down the wall and over the floor.
	var leak := Vector3(rng.randf_range(10, 46), y, 524.4)
	bx(k, leak + Vector3.UP * .004, Vector3(1.6, .004, 1.1), "puddle")
	if k == 0 or k == 3: hum(lit(k), leak + Vector3.UP * 3.0, "res://assets/audio/nichols/drip.ogg", -18.0, 4.0)
	# Where they come out of on this floor: just inside every doorway (0.51: the shut ones count once broken).
	for room: Array in ROOMS[k]:
		if room[3] in ["lobby", "grand", "gallery", "refuge", "mech", "janitor"]: continue
		for dx in _doors(room):
			var inside := Vector3(dx, y, 520.8 if room[2] == "s" else 526.3)
			spawn_points[k].append(inside)
			spawn_doors[k].append(int(_door_at.get("%d:%.2f" % [k, dx], -1)))
	for xx in [3.0, 15.0, 28.0, 41.0, 53.0]: sleep_spots[k].append(Vector3(xx + rng.randf_range(-2, 2), y, CZ + rng.randf_range(-.8, .8)))

# ---------------------------------------------------------------- rooms

func _room(k: int, room: Array) -> void:
	var kind: String = room[3]
	var x0: float = room[0]
	var x1: float = room[1]
	var south: bool = room[2] == "s"
	var z0: float = 514.3 if south else ZN
	var z1: float = ZS if south else 533.7
	var y := k * H
	var c := Vector3((x0 + x1) * .5, y, (z0 + z1) * .5)
	var half := Vector2((x1 - x0) * .5 - .5, (z1 - z0) * .5 - .5)
	if kind in ["grand", "gallery"]: return
	# The door leaf: open, ajar, off its hinges; 501's is shut and barred.
	for dx in _doors(room):
		if kind == "lobby": break
		var wz: float = 522.0 if south else 525.0
		var into: float = -1.0 if south else 1.0
		bx(k, Vector3(dx - .52, y + 1.08, wz), Vector3(.06, 2.16, .24), "#2a3b31")
		bx(k, Vector3(dx + .52, y + 1.08, wz), Vector3(.06, 2.16, .24), "#2a3b31")
		bx(k, Vector3(dx, y + 2.18, wz), Vector3(1.1, .06, .24), "#2a3b31")
		var leaf := "#3e6b55"
		if kind == "mech":
			# Barred from the corridor side (a bar across), desk tops piled against it outside. 0.63 (owner: up the
			# ladder there was a door that would not open): it can be forced from inside (`flags.mechdoor`, loud).
			_mech_door(k, dx, wz, into, south)
			# (The twelve rng calls the old static heap made, kept so everything built after it lands where it did.)
			for j in 12: rng.randf()
			continue
		_door_lanes.append([k, dx, wz, into])
		var shut := _shut_kind(String(room[4]))
		if shut != "":
			_shut_door(k, dx, south, shut, String(room[4]), c, half)
			continue
		if kind == "refuge":
			_refuge_door(k, dx, wz, into, south)
			continue
		var roll := rng.randf()
		# (0.57: real bodies now, school_props.gd: the leaf off its hinges lies loose, the open and ajar ones swing
		# on their hinges and can be pushed, pulled and shut. The hinge stands just inside the frame's depth.)
		if roll < .25:
			props.add_leaf(roots[k], Vector3(dx, y + .03, wz + into * 1.0), rng.randf_range(-.3, .3), mat(leaf))
		else:
			var swing: float = PI * .5 if roll < .7 else rng.randf_range(.5, 1.1)
			props.add_door(roots[k], Vector3(dx - .49, y + 1.06, wz + into * .14), 1.0 if south else -1.0, swing, mat(leaf))
	var behind_shut := _shut_kind(String(room[4])) != "" or kind == "mech"
	if kind == "class" and not behind_shut: class_rooms[k].append([x0, x1, z0, z1])
	match kind:
		"class", "refuge":
			if String(room[4]) == "208": _bombed(k, x0, x1, z0, z1)
			else: _classroom(k, x0, x1, z0, z1, south, kind == "refuge")
		"janitor": _janitor(k, x0, x1, z0, z1)
		"mech": _mech(k, x0, x1, z0, z1)
		"cafeteria": _cafeteria(k, x0, x1, z0, z1)
		"lobby": _lobby(k, x0, x1, z0, z1)
		"clinic": _clinic(k, x0, x1, z0, z1)
		"registrar": _registrar(k, x0, x1, z0, z1)
		"kitchen": _kitchen(k, x0, x1, z0, z1)
		"guidance", "faculty": _office(k, x0, x1, z0, z1, kind)
		"president": _president(k, x0, x1, z0, z1)
		"chem", "bio", "physics": _lab(k, x0, x1, z0, z1, kind)
		"stock": _stockroom(k, x0, x1, z0, z1)
		"library": _library(k, x0, x1, z0, z1)
		"computer": _computers(k, x0, x1, z0, z1)
		"avr", "music": _hall(k, x0, x1, z0, z1, kind)
	if kind != "refuge" and kind != "lobby":
		papers(k, c, half, int(18 + (x1 - x0) * 3), .12)
		for i in 2:
			var spot := c + Vector3(rng.randf_range(-half.x, half.x) * .7, 0, rng.randf_range(-half.y, half.y) * .7)
			if not behind_shut and kind != "janitor": sleep_spots[k].append(spot)
		for j in (1 if rng.randf() < .5 else 2):
			stain(lit(k), ["pool_big", "pool", "spatter_floor", "splat_c"][rng.randi() % 4], c + Vector3(rng.randf_range(-half.x, half.x) * .6, 0, rng.randf_range(-half.y, half.y) * .6), rng.randf() * TAU, rng.randf_range(1.0, 1.8), rng.randf_range(.9, 1.5))
		if rng.randf() < .45:
			var on_back := rng.randf() < .5
			var wz: float = (z0 + .02) if on_back else (z1 - .02)
			smear(lit(k), "smear_wall", Vector3(rng.randf_range(x0 + 1, x1 - 1), y + rng.randf_range(.6, 1.6), wz), Vector3(0, 0, 1 if on_back else -1), rng.randf_range(1.0, 1.8), .8)
	# Light: two fixtures a room (more in the big ones), most of them dead.
	var nfix := maxi(1, int((x1 - x0) / 5.5))
	for i in nfix:
		var fx := x0 + (x1 - x0) * (i + .5) / nfix
		for fz in [z0 + (z1 - z0) * .3, z0 + (z1 - z0) * .7]:
			var roll := rng.randf()
			var state := 0
			if kind == "refuge" or kind == "mech" or String(room[4]) == "208": state = 0
			elif roll < .05: state = 1
			elif roll < .14: state = 2
			elif roll < .24: state = 3
			elif roll < .34: state = 4
			fixture(k, Vector3(fx, y + 3.18, fz), false, state, false, 1.0, 6.0)

func _board(k: int, x: float, zc: float, faces: float, words: String) -> void:
	var y := k * H
	bx(k, Vector3(x, y + 1.6, zc), Vector3(.05, 1.25, 4.2), "#3a2a1c")
	bx(k, Vector3(x + faces * .03, y + 1.6, zc), Vector3(.02, 1.12, 4.05), "s:board")
	bx(k, Vector3(x + faces * .08, y + .97, zc), Vector3(.12, .03, 4.0), "#3a2a1c")
	if words == "": return
	label(lit(k), Vector3(x + faces * .045, y + 1.72, zc), words, .085, PI * .5 if faces > 0 else -PI * .5, Color(.88, .9, .86, .9))

## Rows of armchairs facing the board on the room's west wall; the teacher's desk; what the class left.
func _classroom(k: int, x0: float, x1: float, z0: float, z1: float, south: bool, refuge: bool) -> void:
	var y := k * H
	var zc := (z0 + z1) * .5
	# 0.59: 501's own board is blank (it said they were in 501); "we went up" is never on the top floor.
	var words := ""
	if not refuge:
		var pick := rng.randi() % BOARDS.size()
		words = BOARDS[pick]
		if k == FLOORS - 1 and words.contains("WENT UP"): words = BOARDS[(pick + 1) % BOARDS.size()]
	_board(k, x0 + .03, zc, 1.0, words)
	bx(k, Vector3(x0 + 1.4, y + .38, zc + 1.4), Vector3(.7, .76, 1.4), "dark_wooden_planks|#7a5a3a", true)
	bx(k, Vector3(x0 + 1.4, y + .77, zc + 1.4), Vector3(.76, .03, 1.46), "#3a2a1c")
	papers(k, Vector3(x0 + 1.4, y + .79, zc + 1.4), Vector2(.25, .5), 6, .1)
	if refuge:
		# Desks piled against the inside of the door (0.52: a node of their own: they are dragged aside when the door
		# opens); a camp lantern; water; mats.
		_barricade_501 = Node3D.new()
		_barricade_501.name = "501 barricade"
		roots[k].add_child(_barricade_501)
		# (0.56: stacked the way they were wedged: desk tops on their edges against the door, more laid across
		# them, more on edge on those; they used to hang in the air at any angle.)
		for i in 10:
			var layer := i / 3
			var row := i % 3
			var flat := layer % 2 == 1
			# Bottoms: on edge .0, laid across .6, on edge .72, laid across 1.32 (each laid board on the one below).
			var at := Vector3(x1 - 1.4 + rng.randf_range(-.05, .05), y + [.3, .62, 1.02, 1.34][layer], z1 - .35 - row * .3 + rng.randf_range(-.02, .02))
			if flat: at = Vector3(x1 - 1.4 + (row - 1) * .06, y + [.3, .62, 1.02, 1.34][layer] + row * .04, z1 - .65)
			var desk: MeshInstance3D = s.piece(_barricade_501, at, Vector3(1.2, .04, .6) if flat else Vector3(1.2, .6, .04), "dark_wooden_planks|#8a6a4a")
			desk.basis = Basis(Vector3.UP, rng.randf_range(-.06, .06))
		for i in 6: bx(k, Vector3(x0 + 2.5 + i * .8, y + .03, z0 + 1.6), Vector3(.7, .05, 1.8), ["#6a2a2a", "#2a3a5a", "#3a4a2a"][i % 3])
		cyl(k, Vector3(x0 + 4.0, y + .15, zc), .08, .3, "#2b2b28")
		bx(k, Vector3(x0 + 4.0, y + .33, zc), Vector3(.1, .08, .1), "glow#ffd08a*5.0")
		omni(lit(k), Vector3(x0 + 4.0, y + .8, zc), Color(1.0, .72, .4), 1.6, 9.0, true)
		for i in 8: cyl(k, Vector3(x0 + 5.5 + (i % 4) * .14, y + .15, z0 + .5 + (i / 4) * .14), .045, .3, "glass#9fc7e090", Basis.IDENTITY, 8)
		return
	var rows := 0
	var x := x0 + 2.7
	var mess := rng.randf_range(.35, .9)
	while x < x1 - .6:
		var z := z0 + .85
		while z < z1 - .7:
			var at := Vector3(x + rng.randf_range(-.3, .3) * mess, y, z + rng.randf_range(-.3, .3) * mess)
			if rng.randf() > mess * .25: chair(k, at, -PI * .5 + rng.randf_range(-.6, .6) * mess, mess)
			z += .88
		x += 1.0
		rows += 1
	belongings(k, Vector3((x0 + x1) * .5 + 1.0, y, zc), Vector2((x1 - x0) * .4, (z1 - z0) * .4), int(4 + mess * 8))
	if rng.randf() < .4:
		# 0.51: the room's TV on its bracket, still on the generator: nothing but static, and the hiss.
		var tv := Vector3(x0 + .45, y + 2.45, (z1 - .9) if south else (z0 + .9))
		bar(k, Vector3(x0 + .03, y + 2.75, tv.z), tv + Vector3(0, .2, 0), .04, "#2a2a28")
		bx(k, tv, Vector3(.32, .52, .8), "#151515")
		var screen := MeshInstance3D.new()
		var sm := QuadMesh.new()
		sm.size = Vector2(.7, .42)
		screen.mesh = sm
		screen.material_override = _tv_mat
		screen.position = tv + Vector3(.165, 0, 0)
		screen.rotation.y = PI * .5
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		roots[lit(k)].add_child(screen)
		var glow := omni(lit(k), tv + Vector3(.8, -.3, 0), Color(.7, .78, .95), .45, 4.5)
		lamps.append([glow, .45, 6, rng.randf_range(0, 9), null])
		hum(lit(k), tv, "res://assets/school/audio/static.wav", -22.0, 2.5)
	if rng.randf() < .3:
		# 0.51: chairs and a desk stacked under a pulled-out ceiling tile: they tried to get up into the ceiling.
		var under := Vector3(rng.randf_range(x0 + 3.0, x1 - 1.5), y, zc + rng.randf_range(-1.5, 1.5))
		# (0.59: the class's own chairs where the desk and the stack now stand are cleared: they stood in the desk,
		# and woken they burst out of it into the stack and brought it down.)
		var kept: Array = []
		for c: Transform3D in _chairs[k]:
			if absf(c.origin.x - under.x) < 1.15 and absf(c.origin.z - under.z) < .95 and absf(c.origin.y - y) < 1.0: continue
			kept.append(c)
		_chairs[k] = kept
		bx(k, under + Vector3(0, .38, 0), Vector3(1.2, .76, .6), "dark_wooden_planks|#8a6a4a", true)
		# (0.56: each chair sits on the seat of the one under it; they floated apart, tipped every way.)
		# (0.59: each set back and to the left on the one under it, square to it, so its seat clears the lower one's
		# back and writing arm: overlapping, the stack burst apart the moment anything woke it.)
		var spin := rng.randf() * TAU
		var t := Transform3D(Basis(Vector3.UP, spin), under + Vector3(0, .765, 0))
		for j in 4:
			_chairs[k].append(t)
			t = Transform3D(t.basis * Basis(Vector3.UP, rng.randf_range(-.03, .03)), t.origin + Vector3.UP * .475 + t.basis * Vector3(-.065, 0, -.065))
		bx(k, Vector3(under.x, y + 3.215, under.z), Vector3(.6, .03, .6), "#0b0a09")
		bx(k, under + Vector3(.9, .03, .5), Vector3(.6, .02, .6), "s:ceiling", false, Basis(Vector3.UP, .4))
		bx(k, under + Vector3(-.7, .05, -.4), Vector3(.1, .08, .26), "#151515", false, Basis(Vector3.UP, 1.2))
		stain(lit(k), "spatter_floor", under + Vector3(.2, 0, .3), rng.randf() * TAU, 1.4, 1.2, .8)
	# A wall fan by the board, a broom, the class's bulletin corner.
	bx(k, Vector3(x0 + .2, y + 2.6, z0 + .6), Vector3(.2, .4, .4), "#d8d4c6")
	if rng.randf() < .5: bar(k, Vector3(x1 - .3, y, z0 + .5), Vector3(x1 - .2, y + 1.3, z0 + .55), .03, "#a88a5a")
	if rng.randf() < .45:
		# Someone barricaded in the corner and did not make it out: tables on their sides, a blanket, blood.
		var corner := Vector3(x1 - 1.6, y, z0 + 1.6)
		for i in 3: bx(k, corner + Vector3(rng.randf_range(-.8, .8), .4, rng.randf_range(-.8, .8)), Vector3(1.2, .76, .04), "dark_wooden_planks|#8a6a4a", true, Basis(Vector3.UP, i * 1.1 + rng.randf()))
		stain(lit(k), "pool_big", corner, rng.randf() * TAU, 1.8, 1.5)
		smear(lit(k), "smear_wall", Vector3(x1 - .02, y + 1.0, z0 + 1.6), Vector3(-1, 0, 0), 1.6, .9)

func _cafeteria(k: int, x0: float, x1: float, z0: float, z1: float) -> void:
	var y := k * H
	bx(k, Vector3((x0 + x1) * .5, y + .003, (z0 + z1) * .5), Vector3(x1 - x0, .006, z1 - z0), "s:classroom|#e8dcc4")
	# The counter along the west wall, sneeze glass, the menu.
	bx(k, Vector3(x0 + .55, y + .48, (z0 + z1) * .5), Vector3(.9, .96, 6.2), "#9aa09a", true)
	bx(k, Vector3(x0 + .55, y + .98, (z0 + z1) * .5), Vector3(.95, .04, 6.3), "#c8ccc8")
	bx(k, Vector3(x0 + 1.0, y + 1.3, (z0 + z1) * .5), Vector3(.02, .6, 6.0), "glass")
	for i in 5: bx(k, Vector3(x0 + .45, y + 1.04, z0 + 1.2 + i * 1.2), Vector3(.5, .1, .9), "#b8bcb8")
	bx(k, Vector3(x0 + .02, y + 2.3, (z0 + z1) * .5), Vector3(.03, .9, 3.4), "#1d2a22")
	label(lit(k), Vector3(x0 + .04, y + 2.35, (z0 + z1) * .5), "TODAY'S MENU\nAdobo .......... 45\nSinigang ....... 50\nPancit .......... 35\nRice ............. 12", .075, PI * .5, Color(.95, .92, .8))
	# Long tables and benches, mostly shoved and tipped: where it started, at lunch.
	var x := x0 + 3.2
	while x < x1 - 1.5:
		for zz in [z0 + 1.7, z1 - 1.7]:
			var tip := rng.randf() < .35
			var yaw := rng.randf_range(-.35, .35)
			var at := Vector3(x + rng.randf_range(-.4, .4), y, zz + rng.randf_range(-.5, .5))
			if tip:
				bx(k, at + Vector3(0, .4, 0), Vector3(2.4, .8, .05), "#9b8a6a", true, Basis(Vector3.UP, yaw))
			else:
				bx(k, at + Vector3(0, .74, 0), Vector3(2.4, .04, .8), "#9b8a6a", true, Basis(Vector3.UP, yaw))
				for lx in [-1.05, 1.05]: bx(k, at + Basis(Vector3.UP, yaw) * Vector3(lx, .36, 0), Vector3(.06, .72, .7), "#3c3f3c", false, Basis(Vector3.UP, yaw))
				for tr in 3: bx(k, at + Basis(Vector3.UP, yaw) * Vector3(rng.randf_range(-.95, .95), .7725, rng.randf_range(-.22, .22)), Vector3(.35, .025, .26), ["#c8642a", "#3a7a9a", "#d8d4c6"][tr % 3], false, Basis(Vector3.UP, yaw + rng.randf_range(-.4, .4)))
			for side in [-1, 1]:
				var bench := at + Basis(Vector3.UP, yaw) * Vector3(0, .22, side * .65)
				# (0.56: the benches have their legs, and are solid; the seats used to hang in the air on their own.)
				if rng.randf() < .3:
					var tb := Basis(Vector3.UP, yaw + rng.randf_range(-.6, .6))
					var tat := bench + Vector3(rng.randf_range(-.5, .5), -.07, side * .3)
					bx(k, tat, Vector3(2.2, .3, .05), "#9b8a6a", true, tb)
					for lx in [-.95, .95]: bx(k, tat + tb * Vector3(lx, -.13, -side * .2), Vector3(.05, .04, .4), "#3c3f3c", false, tb)
				else:
					var bb := Basis(Vector3.UP, yaw)
					bx(k, bench + Vector3(0, .2, 0), Vector3(2.2, .05, .3), "#9b8a6a", true, bb)
					for lx in [-.95, .95]: bx(k, bench + bb * Vector3(lx, -.01, 0), Vector3(.05, .4, .26), "#3c3f3c", false, bb)
		x += 3.1
	# Food and trays on the floor, a lot of blood, the drag marks out to the corridor.
	for i in 30:
		var at := Vector3(rng.randf_range(x0 + 2, x1 - 1), y + .015, rng.randf_range(z0 + .6, z1 - .6))
		bx(k, at, Vector3(.35, .02, .26) if i % 2 == 0 else Vector3(.18, .03, .18), ["#c8642a", "#3a7a9a", "#d8d4c6", "#7a5a2a", "#e8e0c0"][i % 5], false, Basis(Vector3.UP, rng.randf() * TAU))
	for i in 6: stain(lit(k), ["pool_big", "pool", "spatter_floor"][i % 3], Vector3(rng.randf_range(x0 + 3, x1 - 2), y, rng.randf_range(z0 + 1, z1 - 1)), rng.randf() * TAU, rng.randf_range(1.4, 2.4), rng.randf_range(1.2, 2.0))
	drag(lit(k), Vector3(9.0, y, 519.0), Vector3(22.4, y, 521.4))
	drag(lit(k), Vector3(12.0, y, 516.0), Vector3(1.6, y, 521.4))
	smear(lit(k), "smear_wall", Vector3(14.0, y + 1.1, 514.32), Vector3(0, 0, 1), 2.0, 1.0)
	hum(lit(k), Vector3(10, y + 1.0, 518), "res://assets/audio/nichols/flies.ogg", -14.0, 5.0)
	bx(k, Vector3(x1 - .5, y + .9, z0 + .6), Vector3(.7, 1.8, .7), "#b8262a", true)
	bx(k, Vector3(x1 - .5, y + 1.1, z0 + .96), Vector3(.5, 1.0, .02), "glow#f2e2c0*.6")
	omni(lit(k), Vector3(x1 - .6, y + 1.1, z0 + 1.4), Color(1.0, .86, .7), .45, 3.0)
	label(lit(k), Vector3(x1 - .5, y + 1.75, z0 + .975), "COLD DRINKS", .07, 0.0, Color(.95, .95, .9))
	for i in 12: chair(k, Vector3(rng.randf_range(x0 + 2, x1 - 1), y, rng.randf_range(z0 + .5, z1 - .5)), rng.randf() * TAU, .9)
	for i in 4: sleep_spots[k].append(Vector3(rng.randf_range(x0 + 3, x1 - 2), y, rng.randf_range(z0 + 1.2, z1 - 1.2)))

func _lobby(k: int, x0: float, x1: float, z0: float, z1: float) -> void:
	var y := k * H
	var cx := (x0 + x1) * .5
	bx(k, Vector3(cx, y + .003, (z0 + z1) * .5), Vector3(x1 - x0, .006, z1 - z0), "s:checker")
	bx(k, Vector3(cx, y + .003, CZ), Vector3(x1 - x0, .006, 3.0), "s:checker")
	# The founder's plaque and the school's name in steel letters over it.
	var px := x1 - .14
	bx(k, Vector3(px, y + 1.65, 517.6), Vector3(.05, 1.1, 1.9), "#7a5a26")
	label(lit(k), Vector3(px - .03, y + 1.7, 517.6), "PROF. IVAN LAWRENCE\nCOLLEGE OF SCIENCE AND TECHNOLOGY\n\nFounded 2009 by Prof. Ivan Lawrence\nfor the young people of the barangays.\n\"Science for every barangay.\"", .055, -PI * .5, Color(.95, .85, .55))
	label(lit(k), Vector3(px - .03, y + 2.75, 517.6), "P I L C S T", .26, -PI * .5, Color(.82, .82, .8))
	cyl(k, Vector3(x0 + .16, y + 2.3, 518.0), .45, .04, "#5a1218", Basis(Vector3.FORWARD, PI * .5), 24)
	cyl(k, Vector3(x0 + .19, y + 2.3, 518.0), .36, .03, "#c8a040", Basis(Vector3.FORWARD, PI * .5), 24)
	cyl(k, Vector3(x0 + .21, y + 2.3, 518.0), .3, .03, "#5a1218", Basis(Vector3.FORWARD, PI * .5), 24)
	# The trophy case, its glass in pieces on the checker; the guard's desk; the memo.
	bx(k, Vector3(x0 + .4, y + 1.0, 516.0), Vector3(.6, 2.0, 2.2), "#4a3424", true)
	for i in 6: cyl(k, Vector3(x0 + .4, y + .9 + (i / 3) * .6, 515.3 + (i % 3) * .7), .06, .28, "#c8a040", Basis.IDENTITY, 10)
	for i in 14: bx(k, Vector3(x0 + 1.0 + rng.randf() * 1.2, y + .01, 515.0 + rng.randf() * 2.2), Vector3(.12, .006, .09), "glass", false, Basis(Vector3.UP, rng.randf() * TAU))
	bx(k, Vector3(x1 - 1.4, y + .4, 515.4), Vector3(1.4, .8, .6), "dark_wooden_planks|#6a4a30", true)
	bx(k, Vector3(x1 - 1.4, y + .82, 515.4), Vector3(.4, .03, .3), "#1f3a5a")
	label(lit(k), Vector3(x1 - 1.4, y + .84, 515.4), "LOGBOOK", .04, 0.0, Color(.9, .9, .85))
	var memo := Vector3(x0 + .12, y + 1.55, 520.2)
	bx(k, memo, Vector3(.01, .5, .38), "#ece8dc")
	label(lit(k), memo + Vector3(.01, 0, 0), "MEMORANDUM No. 47, s. 2026\n\nALL CLASSES ARE SUSPENDED.\nStudents are to REMAIN\nin their classrooms.\nThe gates are closed until\nthe ambulances arrive.\n\nOffice of the President", .03, PI * .5, Color(.1, .1, .12))
	# Benches, papers, the dead pushed against the doors, the wreck of the entrance.
	for i in 2: bx(k, Vector3(x0 + 2.0 + i * 3.6, y + .22, 520.6), Vector3(1.8, .45, .5), "#4a5a4a", true, Basis(Vector3.UP, rng.randf_range(-.4, .4)))
	papers(k, Vector3(cx, y, 518.5), Vector2(3.6, 3.6), 70, .15)
	belongings(k, Vector3(cx, y, 518.5), Vector2(3.5, 3.0), 12)
	drag(lit(k), Vector3(cx + 1.0, y, 515.2), Vector3(cx - 2.0, y, 523.2))
	stain(lit(k), "spatter_floor", Vector3(cx - 1.4, y, 517.0), .5, 1.6, 1.6)
	# Pendant globes like the old hall in the photos; one still lit.
	for i in 3:
		var at := Vector3(cx + (i - 1) * 2.6, y + 2.7, 518.2)
		bar(k, at, at + Vector3.UP * .5, .012, "#1a1a1a")
		cyl(k, at + Vector3.UP * .05, .18, .06, "#c8a040", Basis.IDENTITY, 12)
		if i == 1:
			cyl(k, at - Vector3.UP * .1, .17, .3, "glow#fff0d0*2.4", Basis.IDENTITY, 14)
			lamps.append([omni(lit(k), at - Vector3.UP * .3, Color(1.0, .88, .7), 1.6, 8.5, false), 1.6, 2, 1.7, null])
		else:
			cyl(k, at - Vector3.UP * .1, .17, .3, "#d8d4c6", Basis.IDENTITY, 14)

func _clinic(k: int, x0: float, x1: float, z0: float, z1: float) -> void:
	var y := k * H
	bx(k, Vector3((x0 + x1) * .5, y + .003, (z0 + z1) * .5), Vector3(x1 - x0, .006, z1 - z0), "s:corridor|#e0ece8")
	for i in 3:
		var at := Vector3(x0 + 1.4 + i * 2.4, y, z0 + 1.3)
		bx(k, at + Vector3(0, .5, 0), Vector3(.9, .1, 1.9), "#c8ccc8", true)
		bx(k, at + Vector3(0, .58, 0), Vector3(.85, .08, 1.85), "#e8e6dc" if i != 1 else "#b8504a", false, Basis(Vector3.UP, rng.randf_range(-.08, .08)))
		for p in [Vector3(-.4, .25, -.85), Vector3(.4, .25, -.85), Vector3(-.4, .25, .85), Vector3(.4, .25, .85)]: bx(k, at + p, Vector3(.04, .5, .04), "#9a9e9a")
		bx(k, at + Vector3(.7, 1.0, 0), Vector3(.02, 1.9, 2.0), "#9ac4b4", true, Basis(Vector3.UP, rng.randf_range(-.2, .2)))
	bx(k, Vector3(x1 - .3, y + 1.0, z0 + 2.0), Vector3(.4, 2.0, 1.4), "#d8dcd8", true)
	bx(k, Vector3(x1 - .51, y + 1.3, z0 + 2.0), Vector3(.01, 1.2, 1.2), "glass")
	for i in 12: cyl(k, Vector3(rng.randf_range(x0 + 1, x1 - 1), y + .03, rng.randf_range(z0 + 1, z1 - 1)), .025, .07, "#e8e4d8", Basis(Vector3.FORWARD, PI * .5) * Basis(Vector3.UP, rng.randf() * TAU), 6)
	for i in 3: stain(lit(k), "pool_big", Vector3(x0 + 1.4 + i * 2.4 + rng.randf_range(-.5, .5), y, z0 + 2.6), rng.randf() * TAU, 1.6, 1.3)
	smear(lit(k), "smear_wall", Vector3(x0 + 3.0, y + 1.0, 514.32), Vector3(0, 0, 1), 1.8, .9)
	label(lit(k), Vector3(x1 - .6, y + 2.4, z1 - .12), "WASH YOUR HANDS\nCOVER YOUR COUGH", .07, PI, Color(.15, .3, .5))

func _registrar(k: int, x0: float, x1: float, z0: float, z1: float) -> void:
	var y := k * H
	# The service counter splitting the room, its glass and the window signs.
	bx(k, Vector3((x0 + x1) * .5, y + .55, 517.6), Vector3(x1 - x0 - 1.4, 1.1, .5), "#6a6e66", true)
	bx(k, Vector3((x0 + x1) * .5, y + 1.75, 517.6), Vector3(x1 - x0 - 1.4, 1.3, .02), "glass")
	for i in 3:
		var wx := x0 + 3.0 + i * 4.5
		label(lit(k), Vector3(wx, y + 2.5, 517.62), ["WINDOW 1  •  REGISTRAR", "WINDOW 2  •  CASHIER", "WINDOW 3  •  RECORDS"][i], .07, 0.0, Color(.92, .9, .8))
		bx(k, Vector3(wx, y + 2.5, 517.6), Vector3(2.0, .22, .03), "#1f3a5a")
	for i in 8:
		var at := Vector3(x0 + 1.0 + i * 1.8, y + .7, z0 + .5)
		var tip := rng.randf() < .3
		bx(k, at + (Vector3(0, -.45, .6) if tip else Vector3.ZERO), Vector3(.5, 1.4, .6), "#5d6b64", true, Basis(Vector3.RIGHT, -PI * .5) if tip else Basis.IDENTITY)
	papers(k, Vector3((x0 + x1) * .5, y, 516.0), Vector2((x1 - x0) * .45, 1.4), 220, .08)
	papers(k, Vector3((x0 + x1) * .5, y, 520.0), Vector2((x1 - x0) * .45, 1.4), 90, .12)
	stain(lit(k), "pool_big", Vector3(x0 + 6, y, 519.5), 1.0, 2.0, 1.4)

func _kitchen(k: int, x0: float, x1: float, z0: float, z1: float) -> void:
	var y := k * H
	bx(k, Vector3((x0 + x1) * .5, y + .45, z1 - .45), Vector3(x1 - x0 - .4, .9, .8), "#a8aca8", true)
	bx(k, Vector3(x0 + .45, y + .45, (z0 + z1) * .5), Vector3(.8, .9, 5.0), "#a8aca8", true)
	for i in 4: cyl(k, Vector3(x0 + 2.0 + i * 1.9, y + 1.15, z1 - .45), .32, .5, "#8a8e8a", Basis.IDENTITY, 14)
	# Gas tanks (one knocked over, lying on the floor: 0.56, it hung 23 cm up) and the rice sacks, solid now.
	for i in 3:
		var tank := Vector3(x1 - .8, y + (.4 if i != 2 else .17), z0 + .8 + i * .7)
		cyl(k, tank, .17, .8, "#c8302a" if i != 1 else "#2a6ac8", Basis.IDENTITY if i != 2 else Basis(Vector3.FORWARD, PI * .5), 12)
		solid(k, tank, Vector3(.32, .8, .32) if i != 2 else Vector3(.8, .32, .32))
	for i in 10: bx(k, Vector3(x0 + 1.2 + (i % 5) * .55, y + .25 + (i / 5) * .5, z0 + .5), Vector3(.5, .5, .32), "#d8ccaa", false, Basis(Vector3.UP, rng.randf_range(-.08, .08)))
	solid(k, Vector3(x0 + 2.3, y + .5, z0 + .5), Vector3(2.7, 1.0, .34))
	label(lit(k), Vector3(x0 + 2.3, y + 1.3, z0 + .68), "BIGAS", .12, 0.0, Color(.3, .2, .15))
	stain(lit(k), "pool_big", Vector3((x0 + x1) * .5, y, (z0 + z1) * .5), .3, 2.2, 1.6)
	hum(lit(k), Vector3((x0 + x1) * .5, y + 2.0, z1 - .5), "res://assets/audio/nichols/drip.ogg", -16.0, 4.0)

func _office(k: int, x0: float, x1: float, z0: float, z1: float, kind: String) -> void:
	var y := k * H
	var n: int = 4 if kind == "faculty" else 1
	for i in n:
		var at := Vector3(x0 + 1.6 + (i % 2) * 3.2, y, z0 + 1.8 + (i / 2) * 3.2)
		bx(k, at + Vector3(0, .38, 0), Vector3(1.4, .76, .7), "#6a6e66", true, Basis(Vector3.UP, rng.randf_range(-.3, .3)))
		papers(k, at + Vector3(0, .78, 0), Vector2(.5, .25), 14, .05)
		chair(k, at + Vector3(0, 0, .8), PI + rng.randf_range(-.8, .8), .7)
	if kind == "guidance":
		bx(k, Vector3(x1 - 1.6, y + .25, z1 - .8), Vector3(2.0, .5, .8), "#5a3a3a", true)
		var poster := Vector3(x1 - .12, y + 1.7, (z0 + z1) * .5)
		bx(k, poster, Vector3(.01, .8, .6), "#7aa0c8")
		label(lit(k), poster - Vector3(.012, 0, 0), "YOU ARE\nNOT ALONE\n\nGuidance Office\nRm. 112", .06, -PI * .5, Color(.98, .98, .95))
	else:
		bx(k, Vector3(x1 - .4, y + .9, z0 + .6), Vector3(.5, 1.8, .9), "#5d6b64", true)
		cyl(k, Vector3(x1 - .5, y + .6, z1 - .5), .16, 1.2, "#e8e8e4", Basis.IDENTITY, 12)
		solid(k, Vector3(x1 - .5, y + .78, z1 - .5), Vector3(.32, 1.56, .32))
		cyl(k, Vector3(x1 - .5, y + 1.38, z1 - .5), .13, .36, "glass#7ab0d8a0", Basis.IDENTITY, 12)
	smear(lit(k), "smear_wall", Vector3(x0 + .02, y + 1.2, (z0 + z1) * .5), Vector3(1, 0, 0), 1.4, .8, .8)

## Prof. Ivan Lawrence's office: his desk, his chair turned to the window, the letter he left for Aljay.
func _president(k: int, x0: float, x1: float, z0: float, z1: float) -> void:
	var y := k * H
	bx(k, Vector3((x0 + x1) * .5, y + .003, (z0 + z1) * .5), Vector3(x1 - x0, .006, z1 - z0), "old_wood_floor")
	var desk := Vector3(x0 + 5.0, y, z1 - 2.6)
	bx(k, desk + Vector3(0, .4, 0), Vector3(2.0, .8, .95), "dark_paneled_wood|#6a4028", true)
	bx(k, desk + Vector3(0, .81, 0), Vector3(2.06, .03, 1.0), "#2a1a10")
	bx(k, desk + Vector3(.3, .9, .3), Vector3(.5, .14, .16), "#c8c0aa")
	label(lit(k), desk + Vector3(.3, .9, .21), "PROF. IVAN LAWRENCE\nFounder & President", .028, PI, Color(.25, .18, .08))
	bx(k, desk + Vector3(1.2, .62, -.6), Vector3(.6, 1.2, .6), "#2a1a12", true, Basis(Vector3.UP, 2.4))
	var letter := desk + Vector3(-.4, .83, .1)
	bx(k, letter, Vector3(.21, .003, .297), "#ece8dc", false, Basis(Vector3.UP, .2))
	var note := label(lit(k), letter + Vector3(0, .004, 0), "Aljay,\nI locked the gates at 1:40.\nI thought it would keep them safe.\nThe Grade 12s are on the fifth floor\nwith Ma'am Teves. I am going up.\nIf you get this, don't come here.\n- Ivan", .012, .2, Color(.08, .08, .16), false, 6.0)
	note.rotation = Vector3(-PI * .5, .2, 0)
	bx(k, desk + Vector3(-.75, .95, -.2), Vector3(.03, .25, .03), "#2a2a2a")
	cyl(k, desk + Vector3(-.75, 1.08, -.2), .12, .12, "glow#ffd8a0*2.0", Basis.IDENTITY, 10)
	lamps.append([omni(lit(k), desk + Vector3(-.75, 1.4, 0), Color(1.0, .78, .5), 1.1, 6.0, true), 1.1, 1, 1.0, null])
	bx(k, Vector3(x1 - .25, y + 1.1, z1 - 2.0), Vector3(.4, 2.2, 2.4), "dark_paneled_wood|#5a3420", true)
	books(k, Vector3(x1 - 1.0, y, z1 - 2.0), Vector2(.7, 1.0), 26)
	for i in 3:
		var at := Vector3(x0 + 1.4 + i * 1.6, y + 2.0, z0 + .13)
		bx(k, at, Vector3(.9, .65, .03), "#3a2a1a")
		bx(k, at + Vector3(0, 0, .02), Vector3(.78, .53, .01), "#e8e0c8")
		label(lit(k), at + Vector3(0, 0, .03), ["DOCTOR OF PHILOSOPHY\nin Physics", "PILCST\nFounding Day 2009", "CHED Recognition\n2018"][i], .04, 0.0, Color(.2, .15, .1))
	cyl(k, Vector3(x0 + .7, y + 1.1, z1 - .7), .02, 2.2, "#c8a040", Basis.IDENTITY, 8)
	bx(k, Vector3(x0 + 1.05, y + 1.85, z1 - .7), Vector3(.7, .45, .01), "#5a1218", false, Basis(Vector3.UP, .3))
	papers(k, Vector3((x0 + x1) * .5, y, (z0 + z1) * .5), Vector2(3.0, 2.5), 40, .05)

func _lab(k: int, x0: float, x1: float, z0: float, z1: float, kind: String) -> void:
	var y := k * H
	bx(k, Vector3((x0 + x1) * .5, y + .003, (z0 + z1) * .5), Vector3(x1 - x0, .006, z1 - z0), "s:classroom|#d8d8d0")
	_board(k, x0 + .03, (z0 + z1) * .5, 1.0, {"chem": "BALANCING EQUATIONS\nCH4 + 2O2 -> CO2 + 2H2O\nGoggles ON", "bio": "THE CELL\nnucleus - mitochondria - ribosome\nLab report due Thursday", "physics": "PROJECTILE MOTION\nR = v^2 sin(2t) / g"}[kind])
	# Benches with black tops, a sink in each, stools about; glassware broken over everything.
	var x := x0 + 2.8
	while x < x1 - 1.6:
		for zz in [z0 + 2.0, z1 - 2.0]:
			var at := Vector3(x, y, zz)
			bx(k, at + Vector3(0, .43, 0), Vector3(2.6, .86, .9), "#c9c2ae", true)
			bx(k, at + Vector3(0, .88, 0), Vector3(2.7, .04, 1.0), "#161616")
			bx(k, at + Vector3(.8, .87, 0), Vector3(.45, .03, .35), "#4a4e4e")
			bar(k, at + Vector3(.8, .9, -.2), at + Vector3(.8, 1.2, -.2), .025, "#9a9e9a")
			for g in 4:
				var gp := at + Vector3(rng.randf_range(-1.1, .5), .9, rng.randf_range(-.35, .35))
				if rng.randf() < .5: cyl(k, gp + Vector3.UP * .08, .04, .16, "glass#c8e0e870", Basis.IDENTITY, 10)
				else: cyl(k, gp + Vector3.UP * .03, .04, .16, "glass#c8e0e870", Basis(Vector3.FORWARD, PI * .5) * Basis(Vector3.UP, rng.randf() * TAU), 10)
			for st in 3:
				var sp := at + Vector3(rng.randf_range(-1.2, 1.2), 0, (.75 if zz < (z0 + z1) * .5 else -.75) + rng.randf_range(-.2, .2))
				if rng.randf() < .35: cyl(k, sp + Vector3(0, .2, 0), .17, .04, "#3a3a3a", Basis(Vector3.RIGHT, PI * .5) * Basis(Vector3.UP, rng.randf() * TAU), 10)
				else:
					cyl(k, sp + Vector3(0, .62, 0), .17, .04, "#3a3a3a", Basis.IDENTITY, 10)
					cyl(k, sp + Vector3(0, .3, 0), .025, .6, "#8a8e8a", Basis.IDENTITY, 6)
		x += 3.6
	for i in 40: bx(k, Vector3(rng.randf_range(x0 + 1, x1 - 1), y + .012, rng.randf_range(z0 + .8, z1 - .8)), Vector3(rng.randf_range(.03, .09), .005, rng.randf_range(.03, .08)), "glass#c8e0e870", false, Basis(Vector3.UP, rng.randf() * TAU))
	# The back wall: a fume hood, the specimen shelf (biology), the chart, the eyewash.
	bx(k, Vector3(x1 - .55, y + 1.2, (z0 + z1) * .5), Vector3(1.0, 2.4, 1.8), "#c8ccc8", true)
	bx(k, Vector3(x1 - 1.06, y + 1.3, (z0 + z1) * .5), Vector3(.02, .9, 1.6), "glass")
	if kind == "bio":
		# (0.56: an open shelf, back, sides and boards: the jars used to stand inside a solid block.)
		var shelf := Vector3((x0 + x1) * .5, y, z0 + .3)
		solid(k, shelf + Vector3.UP * 1.0, Vector3(4.0, 2.0, .4))
		bx(k, shelf + Vector3(0, 1.0, -.18), Vector3(4.0, 2.0, .03), "dark_wooden_planks|#6a4a30")
		for sx in [-1.99, 1.99]: bx(k, shelf + Vector3(sx, 1.0, 0), Vector3(.03, 2.0, .4), "dark_wooden_planks|#6a4a30")
		for sy in [.03, .535, 1.235, 1.985]: bx(k, shelf + Vector3(0, sy, 0), Vector3(4.0, .03, .4), "dark_wooden_planks|#6a4a30")
		for i in 18:
			var jp := Vector3((x0 + x1) * .5 - 1.8 + (i % 9) * .45, y + .55 + (i / 9) * .7, z0 + .3)
			if rng.randf() < .8: cyl(k, jp + Vector3.UP * .12, .09, .24, "glass#c8b46ac0" if rng.randf() < .6 else "glass#a8c890c0", Basis.IDENTITY, 10)
	elif kind == "chem":
		var ch := Vector3((x0 + x1) * .5, y + 1.9, z0 + .14)
		bx(k, ch, Vector3(3.6, 1.6, .02), "#e8e4d8")
		for i in 18:
			for j in 7:
				if j == 0 and i > 0 and i < 17: continue
				if j < 3 and i > 1 and i < 12: continue
				bx(k, ch + Vector3(-1.6 + i * .19, .55 - j * .17, .012), Vector3(.17, .15, .005), ["#e8b0a0", "#b0c8e8", "#c8e8b0", "#e8e0a0"][(i + j) % 4])
		label(lit(k), ch + Vector3(0, .7, .016), "PERIODIC TABLE OF THE ELEMENTS", .06, 0.0, Color(.1, .1, .12))
	var ew := Vector3(x1 - .14, y + 1.7, z0 + 1.0)
	bx(k, ew, Vector3(.01, .3, .5), "#2a9a4a")
	label(lit(k), ew - Vector3(.012, 0, 0), "EMERGENCY\nEYEWASH", .05, -PI * .5, Color(.98, .98, .95))
	for i in 2: stain(lit(k), "pool_big", Vector3(rng.randf_range(x0 + 2, x1 - 2), y, (z0 + z1) * .5 + rng.randf_range(-.6, .6)), rng.randf() * TAU, 1.8, 1.4)
	smear(lit(k), "smear_wall", Vector3((x0 + x1) * .5, y + 1.3, z1 - .02 if z1 < 522 else z0 + .02), Vector3(0, 0, -1 if z1 < 522 else 1), 2.2, 1.0)

func _stockroom(k: int, x0: float, x1: float, z0: float, z1: float) -> void:
	var y := k * H
	for i in 3:
		var at := Vector3(x0 + 1.2 + i * 2.6, y, (z0 + z1) * .5)
		bx(k, at + Vector3(0, 1.0, 0), Vector3(.5, 2.0, 5.0), "#7a7e7a", true)
		for j in 24:
			var p := at + Vector3(rng.randf_range(-.15, .15), .45 + (j % 4) * .5, -2.2 + (j / 4) * .8)
			if rng.randf() < .7: cyl(k, p + Vector3.UP * .1, .05, .2, ["glass#8a5a2ac0", "glass#c8e0e870", "glass#6a8a3ac0"][j % 3], Basis.IDENTITY, 8)
	for i in 25: bx(k, Vector3(rng.randf_range(x0 + .5, x1 - .5), y + .015, rng.randf_range(z0 + .5, z1 - .5)), Vector3(.06, .005, .05), "glass#c8e0e870", false, Basis(Vector3.UP, rng.randf() * TAU))
	label(lit(k), Vector3(x1 - .12, y + 1.8, (z0 + z1) * .5), "CHEMICALS\nAUTHORIZED PERSONNEL ONLY", .06, -PI * .5, Color(.8, .15, .1))

func _library(k: int, x0: float, x1: float, z0: float, z1: float) -> void:
	var y := k * H
	bx(k, Vector3((x0 + x1) * .5, y + .003, (z0 + z1) * .5), Vector3(x1 - x0, .006, z1 - z0), "wood_floor_worn")
	# Shelves in rows; some went over, into the next; books everywhere.
	var x := x0 + 3.0
	var i := 0
	while x < x1 - 6.0:
		var fallen := rng.randf() < .3
		var at := Vector3(x, y, z0 + 2.4)
		if fallen:
			bx(k, at + Vector3(.5, .35, 0), Vector3(.4, 2.0, 3.6), "dark_wooden_planks|#7a5a3a", true, Basis(Vector3.FORWARD, -1.2))
			books(k, at + Vector3(1.0, y * 0.0, 0), Vector2(1.0, 1.7), 60)
		else:
			bx(k, at + Vector3(0, 1.0, 0), Vector3(.4, 2.0, 3.6), "dark_wooden_planks|#7a5a3a", true)
			for sh in 5:
				for b in 18:
					if rng.randf() < .55:
						var bp := at + Vector3(rng.randf_range(-.1, .1), .12 + sh * .4, -1.7 + b * .2)
						_books[k].append([Transform3D(Basis(Vector3.FORWARD, PI * .5) * Basis(Vector3.UP, PI * .5 + rng.randf_range(-.2, .2)), bp), [Color("#7a2a26"), Color("#24406a"), Color("#2f5a3a"), Color("#a08a3a"), Color("#3a3a3a")][rng.randi() % 5]])
			books(k, at + Vector3(.8, 0, 0), Vector2(.5, 1.6), 16)
		x += 2.2
		i += 1
	for tz in [z1 - 1.3]:
		for tx in [x1 - 5.0, x1 - 2.4]:
			bx(k, Vector3(tx, y + .74, tz), Vector3(1.8, .04, .9), "dark_wooden_planks|#8a6a4a", true)
			for p in [Vector3(-.8, .37, -.35), Vector3(.8, .37, -.35), Vector3(-.8, .37, .35), Vector3(.8, .37, .35)]: bx(k, Vector3(tx, y, tz) + p, Vector3(.05, .74, .05), "#4a3424")
			books(k, Vector3(tx, y + .74, tz), Vector2(.6, .3), 6)
	bx(k, Vector3(x1 - 1.4, y + .55, z0 + 1.2), Vector3(2.2, 1.1, .6), "dark_wooden_planks|#6a4a30", true)
	var sign_at := Vector3(x1 - .13, y + 2.4, (z0 + z1) * .5)
	label(lit(k), sign_at, "PLEASE OBSERVE SILENCE", .09, -PI * .5, Color(.85, .82, .7))
	books(k, Vector3((x0 + x1) * .5, y, (z0 + z1) * .5), Vector2((x1 - x0) * .45, 3.0), 90)
	for j in 2: stain(lit(k), "pool_big", Vector3(rng.randf_range(x0 + 3, x1 - 3), y, rng.randf_range(z0 + 1.5, z1 - 1.5)), rng.randf() * TAU, 1.8, 1.4)
	for j in 6: chair(k, Vector3(rng.randf_range(x1 - 6, x1 - 1), y, rng.randf_range(z1 - 2.5, z1 - .5)), rng.randf() * TAU, .8)

func _computers(k: int, x0: float, x1: float, z0: float, z1: float) -> void:
	var y := k * H
	bx(k, Vector3((x0 + x1) * .5, y + .003, (z0 + z1) * .5), Vector3(x1 - x0, .006, z1 - z0), "s:corridor|#b8c4c8")
	var lit_one := false
	for row in 3:
		var zz := z0 + 1.5 + row * 2.3
		bx(k, Vector3((x0 + x1) * .5 + .8, y + .74, zz), Vector3(x1 - x0 - 3.4, .04, .75), "#c8c8c0", true)
		bx(k, Vector3((x0 + x1) * .5 + .8, y + .37, zz + .3), Vector3(x1 - x0 - 3.4, .74, .04), "#9a9a92")
		var x := x0 + 2.4
		while x < x1 - 1.2:
			var roll := rng.randf()
			var mon := Vector3(x, y + .76, zz - .1)
			if roll < .2:
				bx(k, Vector3(x + rng.randf_range(-.3, .3), y + .05, zz - .9), Vector3(.48, .34, .06), "#1a1a1c", false, Basis(Vector3.RIGHT, -1.4) * Basis(Vector3.UP, rng.randf_range(-.5, .5)))
			else:
				bx(k, mon + Vector3(0, .22, 0), Vector3(.5, .32, .05), "#1a1a1c", false, Basis(Vector3.UP, rng.randf_range(-.15, .15)))
				if not lit_one and roll > .8 and row == 1:
					lit_one = true
					bx(k, mon + Vector3(0, .22, -.03), Vector3(.45, .27, .005), "glow#3a6ab8*1.8")
					label(lit(k), mon + Vector3(0, .24, -.04), "PILCST-LAN\nNo connection", .022, PI, Color(.9, .95, 1.0), true, 8.0)
					omni(lit(k), mon + Vector3(0, .3, -.5), Color(.5, .7, 1.0), .5, 3.0)
			bx(k, mon + Vector3(0, .02, -.3), Vector3(.44, .02, .15), "#2a2a2c", false, Basis(Vector3.UP, rng.randf_range(-.3, .3)))
			bx(k, Vector3(x + .35, y + .22, zz + .1), Vector3(.18, .42, .42), "#2a2a2c")
			chair(k, Vector3(x, y, zz - .7), PI + rng.randf_range(-.7, .7), .6)
			x += .95
	for i in 6: bar(k, Vector3(rng.randf_range(x0 + 2, x1 - 2), y + .01, rng.randf_range(z0 + 1, z1 - 1)), Vector3(rng.randf_range(x0 + 2, x1 - 2), y + .01, rng.randf_range(z0 + 1, z1 - 1)), .012, "#111111")
	bx(k, Vector3(x0 + .1, y + 1.8, (z0 + z1) * .5), Vector3(.02, 1.6, 2.6), "#e8e8e4")
	for i in 2: stain(lit(k), "spatter_floor", Vector3(rng.randf_range(x0 + 3, x1 - 3), y, rng.randf_range(z0 + 1, z1 - 1)), rng.randf() * TAU, 1.4, 1.4)

## The audio-visual room and the music room: chairs facing the screen, or in a circle; the dark ones.
func _hall(k: int, x0: float, x1: float, z0: float, z1: float, kind: String) -> void:
	var y := k * H
	bx(k, Vector3((x0 + x1) * .5, y + .003, (z0 + z1) * .5), Vector3(x1 - x0, .006, z1 - z0), "dirty_carpet|#6a3a3a" if kind == "avr" else "wood_floor_worn")
	if kind == "avr":
		bx(k, Vector3(x0 + .1, y + 1.8, (z0 + z1) * .5), Vector3(.02, 2.0, 3.4), "#e8e8e4")
		bx(k, Vector3(x1 - 2.5, y + 3.0, (z0 + z1) * .5), Vector3(.4, .15, .3), "#2a2a2c")
		var x := x0 + 2.2
		while x < x1 - 1.0:
			var z := z0 + .8
			while z < z1 - .6:
				chair(k, Vector3(x, y, z), -PI * .5 + rng.randf_range(-.4, .4), .5)
				z += .7
			x += .9
		for i in 2: bx(k, Vector3((x0 + x1) * .5 + i * 3.0, y + 1.6, 525.4 if z0 > 524 else z1 - .1), Vector3(2.4, 3.0, .04), "velour_velvet|#5a1a1a")
	else:
		bx(k, Vector3(x1 - 1.0, y + .6, z1 - 1.0), Vector3(1.5, 1.2, .6), "#1a1410", true)
		var c := Vector3((x0 + x1) * .5, y, (z0 + z1) * .5)
		for i in 14: chair(k, c + Vector3(cos(i * TAU / 14) * 2.4, 0, sin(i * TAU / 14) * 2.4), -i * TAU / 14 - PI * .5, .6)
		place(k, "studio/guitar_acoustic_a", c + Vector3(.6, 0, .4), 70.0)
		place(k, "studio/drum_kit", Vector3(x0 + 1.6, y, z1 - 1.6), 140.0)
		solid(k, Vector3(x0 + 1.6, y + .5, z1 - 1.6), Vector3(1.5, 1.0, 1.3), Basis(Vector3.UP, deg_to_rad(140.0)))
	stain(lit(k), "pool_big", Vector3((x0 + x1) * .5, y, (z0 + z1) * .5), 1.0, 2.0, 1.6)

# ---------------------------------------------------------------- 0.51: the hard way up

## Where the way on is along floor `k`'s corridor (x): the grand stair, the fire exit, the west stair, the
## maintenance room's door; on the fifth, 501.
func way_on_x(k: int) -> float:
	return [28.0, 54.6, 3.1, 38.8, 7.0][k]

func _shut_kind(words: String) -> String:
	if words in SCARES: return "scare"
	for g: Array in AMBUSH:
		if words in g: return "ambush"
	return ""

## A classroom door that is shut, with them behind it: its own body (it shakes, and comes off), the little window.
func _shut_door(k: int, dx: float, south: bool, kind: String, words: String, centre: Vector3, half: Vector2) -> void:
	var y := k * H
	var wz: float = 522.0 if south else 525.0
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.name = "Door %s" % words
	body.position = Vector3(dx, y + 1.06, wz)
	roots[k].add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(.98, 2.1, .06)
	cs.shape = bs
	body.add_child(cs)
	var leaf := Node3D.new()
	body.add_child(leaf)
	for part: Array in [[Vector3.ZERO, bs.size, "#3e6b55"], [Vector3(.18, .42, 0), Vector3(.3, .42, .07), "glass#0a0c0ee8"], [Vector3(-.36, -.06, 0), Vector3(.05, .12, .1), "#b8a878"]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[1]
		mi.mesh = bm
		mi.material_override = mat(part[2])
		mi.position = part[0]
		leaf.add_child(mi)
	var group := -1
	for g in AMBUSH.size():
		if words in AMBUSH[g]: group = g
	var i := doors.size()
	doors.append({"k": k, "x": dx, "south": south, "room": words, "kind": kind, "group": group, "body": body, "leaf": leaf,
		"inside": centre, "half": half, "broken": false, "bang": 0.0, "sound": null, "prop": props.reserve()})
	_door_at["%d:%.2f" % [k, dx]] = i
	if group >= 0: groups[group].append(i)
	# Scratched paint and a smear at the handle height: they have been at it from inside.
	smear(lit(k), "smear_wall", Vector3(dx + .3, y + 1.0, wz + (.13 if south else -.13)), Vector3(0, 0, 1 if south else -1), .9, .5, .6)

## Whether door `i` is shut (a spawn point behind it is no way out).
func door_shut(i: int) -> bool:
	return i >= 0 and i < doors.size() and not doors[i].broken

## Every peer: a shut door pounded from inside, or coming off its hinges (the host says which, mission `flags`).
func _doors_sync(flags: Dictionary, delta: float) -> void:
	var pound: int = int(flags.get("pound", 0))
	var broke: int = int(flags.get("broke", 0))
	if pound == 0 and broke == 0 and not _doors_moving: return
	_doors_moving = pound != 0
	for i in doors.size():
		var d: Dictionary = doors[i]
		if d.broken: continue
		if broke & (1 << i):
			_break(i)
			continue
		var leaf: Node3D = d.leaf
		if pound & (1 << i):
			d.bang = float(d.bang) - delta
			if d.bang <= 0.0:
				d.bang = rng.randf_range(.28, .85)
				leaf.position = Vector3(rng.randf_range(-.02, .02), 0, rng.randf_range(.03, .07) * (1.0 if d.south else -1.0))
				leaf.rotation = Vector3(0, rng.randf_range(-.03, .03), rng.randf_range(-.015, .015))
				_door_sound(d, ["res://assets/audio/siege/bang_a.ogg", "res://assets/audio/siege/bang_c.ogg", "res://assets/audio/siege/rattle.ogg"][rng.randi() % 3], -2.0)
			else:
				leaf.position = leaf.position.lerp(Vector3.ZERO, 1.0 - exp(-14.0 * delta))
		else:
			leaf.position = Vector3.ZERO
			leaf.rotation = Vector3.ZERO

var _doors_moving := false

func _door_sound(d: Dictionary, path: String, volume: float) -> void:
	var a: AudioStreamPlayer3D = d.sound
	if a == null:
		a = AudioStreamPlayer3D.new()
		a.unit_size = 7.0
		a.max_distance = 45.0
		(d.body as Node3D).get_parent().add_child(a)
		a.global_position = (d.body as Node3D).global_position
		d.sound = a
	a.stream = load(path)
	a.volume_db = volume
	a.pitch_scale = rng.randf_range(.85, 1.1)
	a.play()

## The door comes off: a loose leaf flung into the corridor (a real body: it slides, it is kicked about).
func _break(i: int) -> void:
	var d: Dictionary = doors[i]
	d.broken = true
	var body: StaticBody3D = d.body
	var at := body.global_transform
	var parent := body.get_parent()
	_door_sound(d, "res://assets/audio/siege/bang_c.ogg", 4.0)
	var leaf: Node3D = d.leaf
	body.remove_child(leaf)
	body.queue_free()
	var loose := RigidBody3D.new()
	loose.collision_layer = 4
	loose.collision_mask = 2 | 4
	loose.mass = 22.0
	loose.name = "Door %s (off)" % d.room
	parent.add_child(loose)
	loose.global_transform = at
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(.98, 2.1, .06)
	cs.shape = bs
	loose.add_child(cs)
	loose.add_child(leaf)
	leaf.position = Vector3.ZERO
	leaf.rotation = Vector3.ZERO
	var out := Vector3(0, 0, 1.0 if d.south else -1.0)
	# (0.57: the host throws it and says where it went; everyone else follows that, school_props.gd.)
	var throw := out * rng.randf_range(70.0, 110.0) + Vector3.UP * 25.0
	var spin := Vector3(rng.randf_range(-14, 14), rng.randf_range(-6, 6), rng.randf_range(-10, 10))
	if props.host and loose.is_inside_tree():
		loose.apply_central_impulse(throw)
		loose.apply_torque_impulse(spin)
	props.fill(int(d.get("prop", -1)), loose)

## Where those behind door `i` stand when it gives (world): spread through the room behind it.
func behind(i: int, n: int) -> Array[Vector3]:
	var d: Dictionary = doors[i]
	var out: Array[Vector3] = []
	var c: Vector3 = d.inside
	var half: Vector2 = d.half
	for j in n:
		# The front of them close to the door, the rest further back in the room.
		var near_door := Vector3(float(d.x) + rng.randf_range(-1.2, 1.2), c.y, (ZS - rng.randf_range(.8, 2.2)) if d.south else (ZN + rng.randf_range(.8, 2.2)))
		out.append(near_door if j < 2 else c + Vector3(rng.randf_range(-half.x, half.x) * .7, 0, rng.randf_range(-half.y, half.y) * .7))
	for j in out.size(): out[j] = world(out[j])
	return out

## The door's opening (world), for nav.forget_box.
func door_box(i: int) -> AABB:
	var d: Dictionary = doors[i]
	return AABB(world(Vector3(float(d.x) - .7, int(d.k) * H, (522.0 if d.south else 525.0) - .6)), Vector3(1.4, 2.3, 1.2))

## Desks, cabinets and armchairs wedged across the corridor to the ceiling at `x`: the way round is through the rooms
## (BREACHES: a partition someone broke through).
## 0.63: the second floor's desk wall, and what the blast leaves of it (`_blast_hall`).
var _hall_2f_shape: CollisionShape3D
var _hall_2f_down: Node3D
func _hall_block(k: int, x: float) -> void:
	var y := k * H
	var wall := solid(k, Vector3(x, y + 1.6, CZ), Vector3(1.4, 3.2, 2.9))
	# (0.63: on the second floor it is built into its own root, so the blast can throw it down.)
	if k == 1:
		_hall_2f_shape = wall
		_redirect = Vector2i(1, 13)
	# (0.56: stacked, three high to the ceiling: it was a cloud of desks, cabinets and chairs hanging in the air.)
	# (0.59: no chairs crowning it: they stood inside the collider and burst out when a round or a blast woke them.)
	_pile(k, Vector3(x, y, CZ), Vector2(1.3, 2.7), 3, false)
	bx(k, Vector3(x - .45, y + 1.0, CZ + 1.15), Vector3(.45, 2.0, .5), "#5d6b64", false, Basis(Vector3.UP, .15))
	_redirect = Vector2i(-1, -1)
	if k == 1: _hall_down(k, x)
	for i in 5:
		var side := -1.0 if i % 2 == 0 else 1.0
		chair(k, Vector3(x + side * rng.randf_range(.95, 1.4), y, CZ + rng.randf_range(-1.1, 1.1)), rng.randf() * TAU, .9)
	stain(lit(k), "pool_big", Vector3(x - 1.6, y, CZ + .3), rng.randf() * TAU, 1.8, 1.4)
	papers(k, Vector3(x, y, CZ), Vector2(2.5, 1.2), 30, .2)

## 0.63 (owner: after the explosion there was no proper, visible way down): the blast came up through 208 and along
## the second floor's corridor and threw its desk wall down: desks on their sides and backs strewn west along the
## floor toward 208, low enough to walk over and round. Nothing here collides; shown by `_blast_hall`.
func _hall_down(k: int, x: float) -> void:
	var y := k * H
	var root := Node3D.new()
	root.name = "2F desk wall down"
	root.visible = false
	roots[k].add_child(root)
	var plank := "dark_wooden_planks|#8a6a4a"
	var tops := [Vector3(-1.4, .03, -.7), Vector3(-2.3, .03, .6), Vector3(-3.6, .03, -.2), Vector3(.6, .03, .9), Vector3(-5.2, .03, .8), Vector3(-1.0, .32, 1.05)]
	for i in tops.size():
		var t: Vector3 = tops[i]
		var top: MeshInstance3D = s.piece(root, Vector3(x, y, CZ) + t, Vector3(1.2, .04, .6), plank)
		top.rotation = Vector3(0 if i != 5 else PI * .5, .3 + i * .7, 0)
		for leg in [Vector3(-.55, .05, -.25), Vector3(.55, .05, .25)]:
			var l: MeshInstance3D = s.piece(root, Vector3(x, y, CZ) + t + Basis(Vector3.UP, .3 + i * .7) * leg + Vector3(0, .06, 0), Vector3(.72, .03, .03), "#33403a")
			l.rotation.y = .3 + i * .7
	for i in 9:
		var at := Vector3(x - 1.0 - i * .8, y + .03, CZ + (i % 3 - 1) * .8)
		var b: MeshInstance3D = s.piece(root, at, Vector3(1.2, .03, .6) * (.6 if i % 2 == 0 else .9), plank)
		b.rotation.y = i * 1.3
	var cab: MeshInstance3D = s.piece(root, Vector3(x - .2, y + .25, CZ - 1.0), Vector3(1.1, .5, .45), "#5d6b64")
	cab.rotation.y = .2
	_hall_2f_down = root

## 0.63 (every peer, once, with the blast): the desk wall down, its collider gone.
func _blast_hall() -> void:
	if _hall_2f_shape != null: _hall_2f_shape.disabled = true
	if roots.size() > 13: roots[13].visible = false
	if _hall_2f_down != null: _hall_2f_down.visible = true

## A fixture hanging by one wire, swinging: its light (with shadows) moves the dark about.
func _swinging(k: int, at: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = at + Vector3(.6, 0, 0)
	roots[lit(k)].add_child(pivot)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(.85, .9, .92)
	m.emission_enabled = true
	m.emission = TUBE
	m.emission_energy_multiplier = 2.4
	for part: Array in [[Vector3(0, -.5, 0), Vector3(.07, 1.0, .01), null], [Vector3(-.0, -1.05, 0), Vector3(.26, 1.25, .07), mat("#cfcfc6")], [Vector3(.05, -1.05, 0), Vector3(.035, 1.18, .03), m]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[1]
		mi.mesh = bm
		mi.material_override = part[2] if part[2] != null else mat("#111111")
		mi.position = part[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
	# (A spot down from the tube, not an omni: one shadow view to redraw as it swings, not six.)
	var l := SpotLight3D.new()
	l.position = Vector3(.1, -1.12, 0)
	l.rotation.x = -PI * .5
	l.light_color = TUBE
	l.light_energy = 1.6
	l.spot_range = 7.5
	l.spot_angle = 72.0
	l.spot_attenuation = 1.2
	l.shadow_enabled = true
	l.distance_fade_enabled = true
	l.distance_fade_begin = 30.0
	l.distance_fade_length = 8.0
	pivot.add_child(l)
	lamps.append([l, 1.0, 2, rng.randf_range(.6, 2.4), m])
	swings.append([pivot, rng.randf() * TAU, rng.randf_range(.35, .55)])
	hum(lit(k), at, "res://assets/audio/siege/rattle.ogg", -30.0, 3.0)

## 406 is the maintenance room now: Kuya Boy's. His ladder up the north wall, through the hatch into the mechanical
## room on the fifth floor (the only way up left).
func _janitor(k: int, x0: float, x1: float, z0: float, z1: float) -> void:
	var y := k * H
	var lx := LADDER.x
	# The ladder: two steel rails and rungs, from the floor through the hatch to a metre over the fifth floor.
	for side in [-.24, .24]:
		bar(k, Vector3(lx + side, y, 533.62), Vector3(lx + side, y + H + 1.05, 533.62), .045, "#c8a020")
	var r := 0.3
	while r < H + 1.0:
		bar(k, Vector3(lx - .24, y + r, 533.6), Vector3(lx + .24, y + r, 533.6), .03, "#b89018")
		r += .3
	# The hatch frame in the ceiling and its lid thrown back.
	bx(k, Vector3(lx, y + 3.2, HATCH[2] - .03), Vector3(HATCH[1] - HATCH[0], .1, .06), "#4a4a46")
	bx(k, Vector3(lx, y + H + .02, HATCH[2] - .4), Vector3(HATCH[1] - HATCH[0] - .1, .04, .8), "#5a5a55", false, Basis(Vector3.RIGHT, -.25))
	# Shelves of supplies, buckets, mops, a cot; his things.
	for i in 3:
		bx(k, Vector3(x0 + .35, y + .4 + i * .6, (z0 + z1) * .5), Vector3(.5, .03, 3.0), "#5d6b64", true)
		for j in 6: bx(k, Vector3(x0 + .35, y + .55 + i * .6, (z0 + z1) * .5 - 1.3 + j * .5), Vector3(.22, .26, .22), ["#e8e4d8", "#2a5aa0", "#d8c040", "#3a8a5a"][rng.randi() % 4])
	cyl(k, Vector3(x1 - 1.0, y + .2, z0 + 1.2), .2, .4, "#d8b020", Basis.IDENTITY, 12)
	for i in 3: bar(k, Vector3(x1 - .3 - i * .25, y, z0 + .3), Vector3(x1 - .2 - i * .25, y + 1.4, z0 + .45), .03, "#a88a5a")
	bx(k, Vector3(x0 + 2.4, y + .3, z1 - .6), Vector3(1.9, .1, .7), "#3a4a3a", true)
	bx(k, Vector3(x0 + 2.4, y + .38, z1 - .6), Vector3(1.8, .06, .65), "#6a6a5a")
	bx(k, Vector3(x1 - .4, y + 1.6, z1 - 2.0), Vector3(.06, .8, .5), "#1a2a50")
	label(lit(k), Vector3(lx + .4, y + 1.55, 533.58), "AKYAT\n5th flr - mech room\nduct goes to 509\n(gapang, low)\n- B.", .05, PI, Color(.08, .08, .1))
	bx(k, Vector3(lx + .4, y + 1.55, 533.6), Vector3(.42, .34, .01), "#ece8dc")
	drag(lit(k), Vector3(x1 - 1.2, y, z0 + .5), Vector3(lx, y, 532.8), false)
	stain(lit(k), "pool", Vector3(lx, y, 532.6), 0.0, 1.0, .9)
	# One bulb left in here, on a cord, failing.
	var bulb := omni(lit(k), Vector3(x0 + 3.0, y + 2.6, (z0 + z1) * .5), Color(1.0, .8, .55), 1.1, 7.0, true)
	lamps.append([bulb, 1.1, 2, rng.randf_range(.6, 2.4), null])
	cyl(k, Vector3(x0 + 3.0, y + 2.7, (z0 + z1) * .5), .04, .08, "glow#ffd8a0*2.6", Basis.IDENTITY, 8)
	bar(k, Vector3(x0 + 3.0, y + 3.2, (z0 + z1) * .5), Vector3(x0 + 3.0, y + 2.75, (z0 + z1) * .5), .01, "#111111")

## 0.63: the mechanical room's door. Shut, a bar across it on the corridor side and desk tops stood against it; from
## inside it can be forced (`flags.mechdoor`): it bursts out into the corridor, the bar and the desk tops go down
## flat, and the bang wakes what sleeps near it on the fifth floor (mission.gd `_force_mech_door`). The duct stays
## the quiet way.
var _mech_leaf: StaticBody3D
var _mech_heap: StaticBody3D
var _mech_down: Node3D
var _mech_at := 0.0
var mech_open := false
var mech_door_x := 0.0
func _mech_door(k: int, dx: float, wz: float, into: float, south: bool) -> void:
	var y := k * H
	mech_door_x = dx
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.name = "Mech door"
	body.position = Vector3(dx - .49, y + 1.06, wz)
	roots[k].add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(.98, 2.1, .05)
	cs.shape = bs
	cs.position = Vector3(.49, 0, 0)
	body.add_child(cs)
	s.piece(body, Vector3(.49, 0, 0), bs.size, "#3e6b55")
	s.piece(body, Vector3(.83, -.06, into * .04), Vector3(.05, .12, .05), "#b8a878")
	s.piece(body, Vector3(.83, -.06, -into * .04), Vector3(.05, .12, .05), "#b8a878")
	# Kicked and shouldered from inside before: dents, a boot print's dust low down.
	s.piece(body, Vector3(.5, -.62, into * .028), Vector3(.34, .22, .004), "#5a6a5c")
	var note := Label3D.new()
	note.text = "DO NOT OPEN\nTHEY'RE IN THE\nHALL - Kuya Boy"
	note.pixel_size = .05 / 64
	note.font_size = 64
	note.modulate = Color(.1, .08, .08)
	note.outline_size = 0
	note.position = Vector3(.49, .54, -into * .03)
	note.rotation.y = 0.0 if south else PI
	note.double_sided = false
	note.visibility_range_end = 22.0
	body.add_child(note)
	_mech_leaf = body
	# The heap outside: the bar in its brackets, three desk tops on edge, two laid over them, a desk behind.
	var heap := StaticBody3D.new()
	heap.collision_layer = 2
	heap.name = "Mech door heap"
	roots[k].add_child(heap)
	var plank := "dark_wooden_planks|#8a6a4a"
	s.piece(heap, Vector3(dx, y + 1.1, wz - into * .06), Vector3(1.3, .1, .06), "#4a4a46")
	for side in [-.68, .68]: s.piece(heap, Vector3(dx + side, y + 1.1, wz - into * .05), Vector3(.06, .2, .1), "#3a3a36")
	for j in 3:
		var at := Vector3(dx + (j - 1) * .03, y + .3, wz - into * (.1 + j * .07))
		s.piece(heap, at, Vector3(1.2, .6, .04), plank)
	for j in 2: s.piece(heap, Vector3(dx + (j - .5) * .1, y + .62 + j * .04, wz - into * .3), Vector3(1.2, .04, .6), plank)
	var hc := CollisionShape3D.new()
	var hs := BoxShape3D.new()
	hs.size = Vector3(1.3, .7, .62)
	hc.shape = hs
	hc.position = Vector3(dx, y + .35, wz - into * .32)
	heap.add_child(hc)
	_desk(k, Vector3(dx - 1.7, y, wz - into * 1.15), .25)
	_mech_heap = heap
	# What the heap is once the door has gone through it: flat on the corridor floor, nothing to trip on.
	var down := Node3D.new()
	down.name = "Mech door heap down"
	down.visible = false
	roots[k].add_child(down)
	for j in 3:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, .04, .6)
		mi.mesh = bm
		mi.material_override = mat(plank)
		mi.position = Vector3(dx + .3 + j * .25, y + .025 + j * .041, wz - into * (1.3 + j * .35))
		mi.rotation.y = .4 + j * .5
		down.add_child(mi)
	var barm := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.3, .1, .06)
	barm.mesh = bb
	barm.material_override = mat("#4a4a46")
	barm.position = Vector3(dx + .9, y + .05, wz - into * .7)
	barm.rotation.y = 1.1
	down.add_child(barm)
	_mech_down = down

## 0.63 (every peer, from `flags.mechdoor`): the mechanical room's door bursts out into the corridor.
func _mech_sync(flags: Dictionary, delta: float) -> void:
	if _mech_leaf == null or not bool(flags.get("mechdoor", false)): return
	if not mech_open:
		mech_open = true
		_mech_heap.collision_layer = 0
		_mech_heap.visible = false
		_mech_down.visible = true
		var a := AudioStreamPlayer3D.new()
		a.stream = load("res://assets/audio/siege/bang_c.ogg")
		a.volume_db = 4.0
		a.unit_size = 9.0
		a.max_distance = 60.0
		a.position = Vector3(mech_door_x, 4 * H + 1.0, 524.6)
		roots[4].add_child(a)
		a.play()
		a.finished.connect(a.queue_free)
	if _mech_at < 1.0:
		_mech_at = move_toward(_mech_at, 1.0, delta * 3.2)
		# Out into the corridor (the corridor is -z of this north-side room), stopped short of the wall.
		_mech_leaf.rotation.y = PI * .48 * ease(_mech_at, .4)

## The fifth floor's mechanical room: the air handler, the supply duct west along the back wall (its end panel off: the
## way in), the hatch from below. 0.63: its door to the corridor can be forced from inside (`_mech_door`).
func _mech(k: int, x0: float, x1: float, z0: float, z1: float) -> void:
	var y := k * H
	bx(k, Vector3(38.6, y + 1.1, 530.6), Vector3(2.2, 2.2, 3.0), "#7a8078", true)
	bx(k, Vector3(37.45, y + 1.4, 530.6), Vector3(.05, 1.0, 1.2), "#2a2e2c")
	cyl(k, Vector3(38.6, y + 2.6, 530.6), .3, .8, "#6a706a")
	# The hatch's rail on three sides.
	for seg: Array in [[Vector3(HATCH[0] - .05, y, HATCH[2] - .05), Vector3(HATCH[0] - .05, y, 533.6)], [Vector3(HATCH[1] + .05, y, HATCH[2] - .05), Vector3(HATCH[1] + .05, y, 533.6)]]:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		bx(k, (a + b) * .5 + Vector3.UP * .55, Vector3(.05, 1.1, b.z - a.z), "#c8a020", true)
	bx(k, Vector3(36.0, y + .02, HATCH[2] - .02), Vector3(HATCH[1] - HATCH[0], .04, .04), "#c8a020")
	# The duct: galvanised steel along the back wall from here west into 510 and 509, 1.2 m inside.
	var dx0: float = DUCT[0]
	var dx1: float = DUCT[1]
	var len := dx1 - dx0
	var mid := (dx0 + dx1) * .5
	bx(k, Vector3(mid, y + DUCT_H + .03, (DUCT[2] + DUCT[3]) * .5), Vector3(len, .06, DUCT[3] - DUCT[2] + .1), "#8a9096", true)
	bx(k, Vector3(mid, y + DUCT_H * .5, DUCT[2] - .03), Vector3(len, DUCT_H + .06, .06), "#8a9096", true)
	var rib := dx0 + .6
	while rib < dx1:
		bx(k, Vector3(rib, y + DUCT_H * .5, DUCT[2] - .07), Vector3(.05, DUCT_H + .1, .03), "#70767c")
		bx(k, Vector3(rib, y + DUCT_H + .07, (DUCT[2] + DUCT[3]) * .5), Vector3(.05, .03, 1.45), "#70767c")
		rib += 1.2
	# Its end panel, off and on the floor; a hand-written arrow.
	bx(k, Vector3(dx1 + .6, y + .03, 531.6), Vector3(.06, 1.2, 1.3), "#8a9096", false, Basis(Vector3.FORWARD, PI * .5) * Basis(Vector3.UP, .3))
	label(lit(k), Vector3(dx1 - .4, y + .8, DUCT[2] - .07), "<- 509\ngapang lang", .07, 0.0, Color(.08, .08, .1))
	# 509's end of it: the grille kicked out.
	bx(k, Vector3(dx0 - .7, y + .03, 531.7), Vector3(1.0, .04, 1.1), "#9aa0a6", false, Basis(Vector3.UP, .5))
	stain(lit(k), "drag_a", Vector3(26.0, y, 532.95), PI * .5, 1.6, .5, .8)
	stain(lit(k), "spatter_floor", Vector3(dx0 - 1.0, y, 531.8), 1.0, 1.3, 1.1, .8)
	hum(k, Vector3(38.6, y + 1.5, 530.6), "res://assets/audio/nichols/bulb_hum.ogg", -24.0, 4.0)
	# The emergency light over the hatch, red.
	var e := Vector3(36.0, y + 3.1, 531.6)
	bx(k, e, Vector3(.3, .12, .12), "#cfcfc6")
	bx(k, e + Vector3(0, -.07, -.02), Vector3(.22, .04, .06), "glow#ff5a3a*2.4")
	lamps.append([omni(lit(k), e + Vector3(0, -.3, 0), Color(1.0, .38, .26), .8, 6.0), .8, 3, rng.randf_range(.6, 2.0), null])

## The fire escape outside the east end: the second floor's landing, two flights and a turn to the third floor's.
## The flight from the ground lies in the alley where it came down; the one on up hangs off the third floor's landing.
func _fire_escape() -> void:
	var r := 10
	var steel := "rusty_metal_02|#8a7c6c"
	var xm := (FIRE_X0 + FIRE_X1) * .5
	var w := FIRE_X1 - FIRE_X0
	var y2 := H
	var y3 := 2 * H
	# 0.52: landings at the second to the fifth floor, and the switchback between each pair (it used to end at the
	# third, the flight on up hanging off it).
	for k in range(1, FLOORS):
		bx(r, Vector3(xm, k * H - .04, 523.5), Vector3(w, .08, 4.2), steel, true)
	for k in range(1, FLOORS - 1):
		var y := k * H
		bx(r, Vector3(xm, y + 1.76, 530.6), Vector3(w, .08, 1.6), steel, true)
		_ramp(r, Vector3(57.95, y, 525.6), Vector3(57.95, y + 1.8, 529.8), 1.2, 10, true, steel)
		_ramp(r, Vector3(56.65, y + 1.8, 529.8), Vector3(56.65, y + H, 525.6), 1.2, 10, true, steel)
	# Rails (colliders, a hand higher than the rail itself: nobody goes over them into the alley): the landings'
	# outer edges, the open side of the second's and the fifth's, the turns.
	var rails: Array = []
	for k in range(1, FLOORS):
		var y := k * H
		rails.append([Vector3(FIRE_X1, y, 521.4), Vector3(FIRE_X1, y, 525.6)])
		rails.append([Vector3(FIRE_X0, y, 521.4), Vector3(FIRE_X1, y, 521.4)])
		if k == 1: rails.append([Vector3(FIRE_X0, y, 525.6), Vector3(57.3, y, 525.6)])
		if k == FLOORS - 1: rails.append([Vector3(57.3, y, 525.6), Vector3(FIRE_X1, y, 525.6)])
		if k < FLOORS - 1:
			rails.append([Vector3(FIRE_X0, y + 1.8, 531.4), Vector3(FIRE_X1, y + 1.8, 531.4)])
			rails.append([Vector3(FIRE_X1, y + 1.8, 529.8), Vector3(FIRE_X1, y + 1.8, 531.4)])
	for rl: Array in rails:
		var a: Vector3 = rl[0]
		var b: Vector3 = rl[1]
		var mid := (a + b) * .5 + Vector3.UP * .8
		var size: Vector3 = Vector3(absf(b.x - a.x) + .05, 1.6, .05) if absf(b.x - a.x) > .1 else Vector3(.05, 1.6, absf(b.z - a.z) + .05)
		solid(r, mid, size)
		bar(r, a + Vector3.UP * 1.05, b + Vector3.UP * 1.05, .04, steel)
		bar(r, a + Vector3.UP * .5, b + Vector3.UP * .5, .025, steel)
		var n := int((a.distance_to(b)) / .9)
		for i in n + 1: bar(r, a.lerp(b, float(i) / maxf(n, 1)), a.lerp(b, float(i) / maxf(n, 1)) + Vector3.UP * 1.05, .03, steel)
	for k in range(1, FLOORS - 1):
		var y := k * H
		# Between the two flights, and along the first's outer side.
		solid(r, Vector3(57.3, y + 1.5, 527.7), Vector3(.05, 3.0, 4.2))
		solid(r, Vector3(FIRE_X1, y + 1.4, 527.7), Vector3(.05, 2.8, 4.2))
		for i in 5:
			var t := i / 4.0
			var yy := lerpf(y, y + 1.8, t)
			bar(r, Vector3(FIRE_X1, yy, lerpf(525.6, 529.8, t)), Vector3(FIRE_X1, yy + 1.0, lerpf(525.6, 529.8, t)), .03, steel)
			bar(r, Vector3(57.3, yy, lerpf(525.6, 529.8, t)), Vector3(57.3, yy + 1.0, lerpf(525.6, 529.8, t)), .03, steel)
		bar(r, Vector3(FIRE_X1, y + 1.0, 525.6), Vector3(FIRE_X1, y + 2.8, 529.8), .04, steel)
		bar(r, Vector3(57.3, y + 1.0, 525.6), Vector3(57.3, y + 2.8, 529.8), .04, steel)
	# Brackets into the wall.
	for z in [521.6, 525.4, 530.6]:
		for k in range(1, FLOORS): bar(r, Vector3(FIRE_X0, k * H - .1, z), Vector3(FIRE_X1 - .1, k * H - .5, z), .06, steel)
	# The flight up from the alley: torn off, lying across the paving.
	bx(r, Vector3(58.3, .35, 518.0), Vector3(1.2, .2, 4.4), steel, true, Basis(Vector3.UP, .3) * Basis(Vector3.RIGHT, .16))
	bx(r, Vector3(59.6, .2, 522.6), Vector3(1.2, .2, 2.4), steel, true, Basis(Vector3.UP, -.5) * Basis(Vector3.FORWARD, .2))
	bar(r, Vector3(FIRE_X1 - .2, y2 - .1, 521.6), Vector3(FIRE_X1 - .4, y2 - 1.4, 520.8), .06, steel)
	# The doors: the second floor's kicked out onto its landing, the third floor's hanging open; the fourth's and the
	# fifth's shut, a chain through their push bars on the inside (the fifth's comes off with Ma'am Teves's key).
	bx(r, Vector3(57.2, y2 + .05, 522.9), Vector3(1.0, .05, 2.1), "#8a2a24", false, Basis(Vector3.UP, .25))
	bx(r, Vector3(56.45, y3 + 1.06, 522.5), Vector3(.05, 2.1, 1.0), "#8a2a24", true, Basis(Vector3.UP, -1.1))
	# The frames (0.56: a steel bar used to run across every doorway at the push bar's height, also where the door is
	# gone or hangs open, in the way of nothing: now the jambs and the head).
	for k in range(1, FLOORS):
		bx(r, Vector3(55.98, k * H + 2.3, 523.5), Vector3(.06, .1, 1.3), "#2a2a28")
		for jz in [522.9, 524.1]: bx(r, Vector3(55.98, k * H + 1.15, jz), Vector3(.08, 2.3, .06), "#2a2a28")
	_fire_door(3, false)
	_fire_door(4, true)
	# A sodium lamp on the wall over the second floor's door, failing; blood down the steps.
	bx(r, Vector3(56.1, y2 + 2.8, 521.9), Vector3(.25, .14, .3), "#2a2a28")
	var sodium := omni(r, Vector3(56.5, y2 + 2.6, 521.9), Color(1.0, .62, .3), 1.4, 9.0)
	sodium.set_meta("outdoor", true)
	lamps.append([sodium, 1.4, 2, rng.randf_range(.6, 2.4), null])
	stain(r, "drag_a", Vector3(56.8, y3, 524.0), .2, 1.6, .6)
	stain(r, "spatter_floor", Vector3(57.4, y2 + 1.8, 530.4), 1.0, 1.4, 1.2)

## 0.52: a fire door at the east end of floor `k`, shut, chained through its push bar on the inside. The fifth's
## (`opens`) is a body of its own that swings out onto the landing once the chain is off (`flags.fire5`).
func _fire_door(k: int, opens: bool) -> void:
	var y := k * H
	var hinge := Vector3(55.85, y + 1.1, 522.97)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.name = "Fire door %d" % (k + 1)
	body.position = hinge
	roots[k].add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(.06, 2.2, 1.06)
	cs.shape = bs
	cs.position = Vector3(0, 0, .53)
	body.add_child(cs)
	for part: Array in [[Vector3(0, 0, .53), bs.size, "#8a2a24"], [Vector3(.04, .45, .53), Vector3(.02, .5, .32), "glass#141a1ee0"],
			[Vector3(-.06, -.05, .53), Vector3(.06, .06, .9), "#c8c4b8"]]:
		s.piece(body, part[0], part[1], part[2])
	# The chain and the padlock, on the inside.
	var chain := Node3D.new()
	chain.name = "Chain"
	body.add_child(chain)
	for i in 9:
		var t := i / 8.0
		s.piece(chain, Vector3(-.1 - sin(t * PI) * .05, -.05 + sin(t * PI) * -.12, .1 + t * .86), Vector3(.03, .05, .09), "#4a4a44")
	s.piece(chain, Vector3(-.13, -.24, .56), Vector3(.05, .09, .07), "#b8a040")
	label(lit(k), Vector3(55.55, y + 1.75, 523.5), "CHAINED\nwag buksan\n- 12-B", .05, -PI * .5, Color(.1, .08, .08))
	if opens:
		_fire_5 = body
		_chain_5 = chain

# ---------------------------------------------------------------- the shell: outer walls, windows, roof, signs

func _shell() -> void:
	for k in FLOORS:
		var y := k * H
		var south_holes: Array = []
		var north_holes: Array = []
		for m in 14:
			var wx := m * 4.0
			if k == 0 and (m == 6 or m == 7):
				continue
			south_holes.append([wx + .7, wx + 3.3, 1.0, 2.6])
			if not (m <= 1 or m >= 12): north_holes.append([wx + .7, wx + 3.3, 1.0, 2.6])
		if k == 0: south_holes.append([26.2, 29.8, 0.0, 2.75])
		wall(k, true, 514.15, 0.0, 56.0, y, H, south_holes, .3, "concrete_wall_008|#d6ccb0", 1, 10)
		var north_cut: Array = north_holes.duplicate()
		if k == 1:
			north_cut = north_cut.filter(func(h): return not (float(h[1]) > BREACH[0] and float(h[0]) < BREACH[1]))
			north_cut.append([BREACH[0], BREACH[1], 0.0, 3.05])
		wall(k, true, 533.85, 0.0, 56.0, y, H, north_cut, .3, "concrete_wall_008|#d6ccb0", -1, 10)
		var end_holes := [[522.6, 524.4, .9, 2.7]]
		# (0.52: a fire door at the east end of every floor above the ground: the fire escape goes up to the fifth.)
		var fire_door := k >= ROUTE_FIRE
		wall(k, false, .15, 514.3, 533.7, y, H, end_holes, .3, "concrete_wall_008|#d6ccb0", 1, 10)
		wall(k, false, 55.85, 514.3, 533.7, y, H, [[522.95, 524.05, 0.0, 2.25]] if fire_door else end_holes, .3, "concrete_wall_008|#d6ccb0", -1, 10)
		for h: Array in south_holes:
			if h[2] > .5: _window(k, true, 514.15, h, 1.0)
		for h: Array in north_holes:
			# (0.52: 208's windows went with the wall: `_breach` does that opening.)
			if k == 1 and float(h[1]) > BREACH[0] and float(h[0]) < BREACH[1]: continue
			_window(k, true, 533.85, h, -1.0)
		for x in [.15, 55.85]:
			if x > 1.0 and fire_door: continue
			_window(k, false, x, end_holes[0], 1.0 if x < 1 else -1.0)
		# Slab edge band: the school's maroon.
		bx(10, Vector3(28, y + .02, 513.98), Vector3(56.2, .26, .06), "#5a1a20")
		bx(10, Vector3(28, y + .02, 534.02), Vector3(56.2, .26, .06), "#5a1a20")
	# Roof: the slab, the parapet, the water tank, the school's name across the top.
	var top := FLOORS * H
	bx(10, Vector3(28, top - .15, 524), Vector3(56, .3, 20), "concrete_floor_02|#6a6a66", true)
	for z in [514.15, 533.85]: bx(10, Vector3(28, top + .5, z), Vector3(56, 1.0, .3), "concrete_wall_008|#d6ccb0", true)
	for x in [.15, 55.85]: bx(10, Vector3(x, top + .5, 524), Vector3(.3, 1.0, 20), "concrete_wall_008|#d6ccb0", true)
	cyl(10, Vector3(44, top + 2.0, 529), 1.4, 2.4, "#3a5a8a", Basis.IDENTITY, 18)
	for p in [Vector3(43, top + .4, 528), Vector3(45, top + .4, 528), Vector3(43, top + .4, 530), Vector3(45, top + .4, 530)]: bx(10, p, Vector3(.12, .8, .12), "#4a4a46")
	bx(10, Vector3(28, top + 1.55, 513.85), Vector3(44, 1.1, .12), "#5a1a20")
	label(10, Vector3(28, top + 1.62, 513.78), "PROF. IVAN LAWRENCE COLLEGE OF SCIENCE AND TECHNOLOGY", .62, PI, Color(.95, .86, .55), false, 200.0)
	label(10, Vector3(28, top + 1.12, 513.78), "EST. 2009  •  PILCST  •  DAVAO CITY", .22, PI, Color(.9, .88, .8), false, 200.0)
	cyl(10, Vector3(28, top + 2.75, 513.9), .7, .08, "#5a1218", Basis(Vector3.RIGHT, PI * .5), 28)
	cyl(10, Vector3(28, top + 2.75, 513.85), .56, .06, "#c8a040", Basis(Vector3.RIGHT, PI * .5), 28)
	cyl(10, Vector3(28, top + 2.75, 513.82), .46, .05, "#5a1218", Basis(Vector3.RIGHT, PI * .5), 28)
	bx(10, Vector3(28, top + 2.2, 513.95), Vector3(.2, 1.0, .1), "#5a1a20")
	for x in [16.0, 40.0]:
		var sp := SpotLight3D.new()
		sp.position = Vector3(x, top + 1.1, 511.6)
		sp.transform = Transform3D(Basis.looking_at((Vector3(28.0 + (x - 28.0) * .2, top + 1.5, 513.9)) - sp.position, Vector3.UP), sp.position)
		sp.light_color = Color(1.0, .86, .62)
		sp.light_energy = 6.0
		sp.spot_range = 24.0
		sp.spot_angle = 34.0
		sp.distance_fade_enabled = true
		sp.distance_fade_begin = 140.0
		sp.set_meta("outdoor", true)
		roots[10].add_child(sp)
		bar(10, Vector3(x, top + .6, 513.9), Vector3(x, top + 1.1, 511.6), .05, "#3a3a36")
		if x > 30.0: lamps.append([sp, 6.0, 2, 1.1, null])
	for x in [9.0, 47.0]:
		var fl := SpotLight3D.new()
		fl.position = Vector3(x, 4.4, 513.6)
		fl.transform = Transform3D(Basis.looking_at((Vector3(x + (28.0 - x) * .3, 0, 505.0)) - fl.position, Vector3.UP), fl.position)
		fl.light_color = Color(.86, .93, 1.0)
		fl.light_energy = 3.5
		fl.spot_range = 22.0
		fl.spot_angle = 55.0
		fl.shadow_enabled = true
		fl.distance_fade_enabled = true
		fl.distance_fade_begin = 90.0
		fl.set_meta("outdoor", true)
		roots[10].add_child(fl)
		bx(10, Vector3(x, 4.45, 513.75), Vector3(.45, .3, .3), "#2a2a28")
		bx(10, Vector3(x, 4.38, 513.58), Vector3(.38, .22, .02), "glow#e8f0ff*3.0")
		lamps.append([fl, 3.5, 2 if x < 28.0 else 1, 1.6, null])
	for x in [12.0, 44.0]:
		var up := SpotLight3D.new()
		up.position = Vector3(x, .35, 511.2)
		up.transform = Transform3D(Basis.looking_at((Vector3(x, 14.0, 514.0)) - up.position, Vector3.UP), up.position)
		up.light_color = Color(1.0, .78, .55)
		up.light_energy = 3.2
		up.spot_range = 20.0
		up.spot_angle = 22.0
		up.distance_fade_enabled = true
		up.distance_fade_begin = 140.0
		up.set_meta("outdoor", true)
		roots[10].add_child(up)
		bx(10, Vector3(x, .15, 511.2), Vector3(.35, .3, .35), "#2a2a28")
	# The entrance: a concrete canopy, the main doors (one leaf gone), steps of tile.
	bx(10, Vector3(28, 3.05, 512.3), Vector3(6.0, .22, 3.6), "concrete_wall_008|#d6ccb0", true)
	bx(10, Vector3(28, 2.85, 510.55), Vector3(6.0, .28, .1), "#5a1a20")
	label(10, Vector3(28, 2.86, 510.49), "PILCST  •  MAIN ENTRANCE", .14, PI, Color(.95, .86, .55), false, 60.0)
	for x in [25.3, 30.7]: bx(10, Vector3(x, 1.5, 510.7), Vector3(.28, 3.0, .28), "concrete_wall_008|#c8bea2", true)
	bx(10, Vector3(27.1, 1.35, 514.15), Vector3(1.75, 2.7, .05), "glass", false)
	bx(10, Vector3(29.9, 1.35, 513.2), Vector3(.05, 2.7, 1.75), "glass", false, Basis(Vector3.UP, .3))
	for x in [26.25, 29.75, 28.0]: bx(10, Vector3(x, 1.4, 514.15), Vector3(.08, 2.8, .1), "#2a2a2a")
	var canopy_light := Vector3(28, 2.88, 512.3)
	bx(10, canopy_light, Vector3(1.25, .06, .26), "#cfcfc6")
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(.85, .9, .92)
	cm.emission_enabled = true
	cm.emission = TUBE
	cm.emission_energy_multiplier = 2.4
	var tube := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.18, .03, .04)
	tube.mesh = tm
	tube.material_override = cm
	tube.position = canopy_light + Vector3.DOWN * .045
	roots[10].add_child(tube)
	var cl := omni(10, canopy_light + Vector3.DOWN * .3, TUBE, 1.6, 9.0, true)
	cl.set_meta("outdoor", true)
	lamps.append([cl, 1.6, 2, 1.3, cm])
	# The foundation week tarpaulin, torn, across the second floor.
	bx(10, Vector3(14, H + 1.9, 513.9), Vector3(9.0, 2.2, .02), "#e8d8a8", false, Basis(Vector3.FORWARD, .02))
	bx(10, Vector3(11.2, H + 1.2, 513.88), Vector3(3.0, .9, .02), "#5a1a20")
	label(10, Vector3(14, H + 2.3, 513.86), "PILCST FOUNDATION WEEK 2026", .32, PI, Color(.45, .08, .1), false, 120.0)
	label(10, Vector3(14, H + 1.75, 513.86), "17 years of science for every barangay  •  Nov. 14-21", .14, PI, Color(.2, .15, .1), false, 120.0)
	# Room 501: the lantern in the window, and the bedsheet they hung out of it.
	var sheet := Vector3(4.0, 4 * H + .2, 513.85)
	bx(10, sheet, Vector3(2.4, 2.6, .02), "#ece8dc", false, Basis(Vector3.FORWARD, -.03))
	label(10, sheet + Vector3(0, .2, -.02), "TULONG\n5TH FLOOR\nMAY BUHAY PA", .3, PI, Color(.08, .08, .1), false, 200.0)
	omni(10, Vector3(4.0, 4 * H + 1.6, 515.0), Color(1.0, .72, .42), 1.2, 6.0).set_meta("outdoor", true)

## Glass (some panes gone), the steel grille every school's windows have, blinds part way down here and there, and a
## collider over the opening that rounds go through.
func _window(k: int, along_x: bool, c: float, h: Array, outward: float) -> void:
	var y := k * H
	var u0: float = h[0]
	var u1: float = h[1]
	var v0: float = y + float(h[2])
	var v1: float = y + float(h[3])
	var mid_u := (u0 + u1) * .5
	var w := u1 - u0
	var hh := v1 - v0
	var at: Vector3 = Vector3(mid_u, (v0 + v1) * .5, c) if along_x else Vector3(c, (v0 + v1) * .5, mid_u)
	var n: Vector3 = Vector3(0, 0, -outward) if along_x else Vector3(-outward, 0, 0)
	var span: Vector3 = Vector3(w, hh, .3) if along_x else Vector3(.3, hh, w)
	var shape := solid(10, at, span)
	shape.set_meta("unseen", true)
	var panes := 3
	for i in panes:
		if rng.randf() < .22: continue
		var pu := u0 + w * (i + .5) / panes
		var p: Vector3 = Vector3(pu, at.y, c) if along_x else Vector3(c, at.y, pu)
		var pane: Vector3 = Vector3(w / panes - .04, hh - .06, .012) if along_x else Vector3(.012, hh - .06, w / panes - .04)
		bx(10, p, pane, "glass#2a3238b0")
	var gp := at + n * .14
	for i in 6:
		var pu := u0 + w * (i + .5) / 6.0
		var p: Vector3 = Vector3(pu, at.y, gp.z) if along_x else Vector3(gp.x, at.y, pu)
		bx(10, p, Vector3(.02, hh, .02), "#2a2f2c")
	for v in [v0 + hh * .33, v0 + hh * .66]:
		var p2: Vector3 = Vector3(mid_u, v, gp.z) if along_x else Vector3(gp.x, v, mid_u)
		var rail: Vector3 = Vector3(w, .02, .02) if along_x else Vector3(.02, .02, w)
		bx(10, p2, rail, "#2a2f2c")
	var sill: Vector3 = Vector3(w + .1, .05, .12) if along_x else Vector3(.12, .05, w + .1)
	bx(10, at + n * .17 + Vector3(0, -hh * .5 - .03, 0), sill, "#cfc6ac")
	var glow_roll := rng.randf()
	if glow_roll < .16 or (k == 4 and along_x and c < 515.0 and u0 < 8.0):
		var warm := glow_roll < .07 or k == 4
		var gb := at - n * .22
		var gsize: Vector3 = Vector3(w - .1, hh - .1, .01) if along_x else Vector3(.01, hh - .1, w - .1)
		bx(10, gb, gsize, "glow#e8b878*0.7" if warm else "glow#9cc0d8*0.45")
		return
	if rng.randf() < .45:
		var drop := rng.randf_range(.3, 1.0) * hh
		var bp := at - n * .19 + Vector3(0, hh * .5 - drop * .5, 0)
		var blind: Vector3 = Vector3(w - .1, drop, .015) if along_x else Vector3(.015, drop, w - .1)
		bx(10, bp, blind, "#d9d2bc", false, Basis(Vector3.UP, rng.randf_range(-.03, .03)))

# ---------------------------------------------------------------- the yard: wall, gate, guard house, the walk

func _yard() -> void:
	var r := 11
	bx(r, Vector3(28, -.2, 507.2), Vector3(68.6, .4, 13.8), "concrete_pavement", true)
	bx(r, Vector3(-3.0, -.2, 524), Vector3(6.0, .4, 20), "concrete_pavement", true)
	bx(r, Vector3(59.0, -.2, 524), Vector3(6.0, .4, 20), "concrete_pavement", true)
	bx(r, Vector3(28, -.2, 537.0), Vector3(68.6, .4, 6.0), "concrete_pavement", true)
	# The perimeter wall: cream over green, broken bottles set in the top (as walls here have), the gate.
	var wall_id := "painted_plaster_wall|#e6dcb8"
	for span in [[-6.3, 26.0], [30.0, 62.3]]:
		var cx: float = (span[0] + span[1]) * .5
		var len: float = span[1] - span[0]
		bx(r, Vector3(cx, 1.6, 500.15), Vector3(len, 3.2, .3), wall_id, true)
		bx(r, Vector3(cx, .45, 500.32), Vector3(len, .9, .04), "s:green")
		bx(r, Vector3(cx, .45, 499.98), Vector3(len, .9, .04), "s:green")
		bx(r, Vector3(cx, 3.28, 500.15), Vector3(len, .16, .36), "#2f6a3a")
		for i in int(len / .35):
			cyl(r, Vector3(span[0] + .2 + i * .35, 3.42, 500.15 + rng.randf_range(-.08, .08)), .03, .14, "glass#5a8a5ad0", Basis(Vector3.FORWARD, rng.randf_range(-.4, .4)), 5)
	for side in [[-6.15, 1.0], [62.15, -1.0]]:
		bx(r, Vector3(side[0], 1.6, 520.2), Vector3(.3, 3.2, 40.0), wall_id, true)
	# 0.63: seal the two dead-end side alleys behind the building (no stray dead-end alley traps). Do NOT wall across the
	# lean-to drop at z=540.15 — the Room 208 chute drops down straight onto the open field!
	for ax in [-3.0, 59.0]:
		bx(r, Vector3(ax, 1.6, 534.0), Vector3(6.0, 3.2, .3), "rusty_corrugated_iron", true)
		bx(r, Vector3(ax, .4, 534.25), Vector3(5.4, .8, .5), "concrete_block_wall|#7a766c", true)
	# Chain-link and sheets closing the alleys beside the building.
	for x0 in [-6.0, 56.0]:
		bx(r, Vector3(x0 + 3.0, 1.2, 514.6), Vector3(6.0, 2.4, .05), "rusty_corrugated_iron", true)
	for x in [26.0, 30.0]: bx(r, Vector3(x, 1.9, 500.1), Vector3(.5, 3.8, .5), wall_id, true)
	bx(r, Vector3(28, 3.95, 500.05), Vector3(4.6, .7, .1), "#5a1a20")
	label(r, Vector3(28, 4.06, 499.98), "PROF. IVAN LAWRENCE COLLEGE", .2, PI, Color(.98, .9, .62), false, 80.0)
	label(r, Vector3(28, 3.8, 499.98), "OF SCIENCE AND TECHNOLOGY  •  BACK GATE", .09, PI, Color(.92, .9, .82), false, 80.0)
	bx(r, Vector3(32.6, 2.5, 499.98), Vector3(2.3, 1.5, .02), "#e9e6dc", false, Basis(Vector3.FORWARD, .03))
	label(r, Vector3(32.6, 2.5, 499.96), "MAY TAO DITO\nSURVIVORS INSIDE", .19, PI, Color(.12, .12, .14), false, 60.0)
	# The gate: a steel frame of bars on rollers; it slides west behind the wall when Rommel opens it.
	gate = StaticBody3D.new()
	gate.collision_layer = 2
	gate.name = "School gate"
	gate.position = GATE
	add_child(gate)
	var gc := CollisionShape3D.new()
	var gs := BoxShape3D.new()
	gs.size = Vector3(3.5, 2.6, .12)
	gc.shape = gs
	gc.position = Vector3(0, 1.3, 0)
	gc.set_meta("unseen", true)
	gate.add_child(gc)
	for i in 13: s.piece(gate, Vector3(-1.62 + i * .27, 1.3, 0), Vector3(.035, 2.5, .035), "#2f6a3a")
	for v in [.15, 1.3, 2.5]: s.piece(gate, Vector3(0, v, 0), Vector3(3.5, .07, .06), "#2f6a3a")
	s.piece(gate, Vector3(0, .6, 0), Vector3(3.4, .9, .02), "#2f6a3a")
	s.piece(gate, Vector3(1.6, 1.2, -.07), Vector3(.1, .18, .06), "#8c8c84")
	_gate_sound = AudioStreamPlayer3D.new()
	_gate_sound.stream = preload("res://assets/audio/siege/scrape.ogg")
	_gate_sound.unit_size = 6.0
	_gate_sound.max_distance = 40.0
	gate.add_child(_gate_sound)
	# The guard house: concrete, a window to the gate, a desk with the log and the radio, a bulb.
	bx(r, Vector3(33.75, 1.3, 502.5), Vector3(3.5, 2.6, .2), "concrete_wall_008|#d6ccb0", true)
	bx(r, Vector3(35.4, 1.3, 501.4), Vector3(.2, 2.6, 2.2), "concrete_wall_008|#d6ccb0", true)
	bx(r, Vector3(32.1, .5, 501.4), Vector3(.2, 1.0, 2.2), "concrete_wall_008|#d6ccb0", true)
	bx(r, Vector3(32.1, 2.4, 501.4), Vector3(.2, .4, 2.2), "concrete_wall_008|#d6ccb0", true)
	bx(r, Vector3(33.75, 2.68, 501.4), Vector3(3.7, .12, 2.6), "rusty_corrugated_iron", true)
	bx(r, Vector3(33.7, .4, 501.0), Vector3(1.6, .8, .6), "dark_wooden_planks|#6a4a30", true)
	bx(r, Vector3(33.4, .82, 501.0), Vector3(.35, .03, .25), "#1f3a5a")
	bx(r, Vector3(34.1, .88, 501.0), Vector3(.12, .14, .06), "#1a1a1a")
	bx(r, Vector3(34.1, .9, 500.97), Vector3(.02, .02, .01), "glow#ff3020*3.0")
	label(r, Vector3(33.75, 2.3, 502.62), "GUARD HOUSE", .1, 0.0, Color(.9, .88, .8))
	var bulb := omni(r, Vector3(33.6, 2.3, 501.5), Color(1.0, .8, .55), 1.0, 7.0, true)
	bulb.set_meta("outdoor", true)
	lamps.append([bulb, 1.0, 2, 2.2, null])
	cyl(r, Vector3(33.6, 2.45, 501.5), .05, .1, "glow#ffd8a0*3.0", Basis.IDENTITY, 8)
	# His cap where it came off, the blood from where he was bitten to where he sits.
	bx(r, Vector3(30.2, .04, 501.3), Vector3(.26, .08, .3), "#11151f", false, Basis(Vector3.UP, .7))
	drag(r, Vector3(29.0, 0, 504.5), GUARD_SEAT + Vector3(-.3, 0, -.1), true)
	var torch := Vector3(30.75, .06, 501.55)
	cyl(r, torch, .03, .22, "#151515", Basis(Vector3.UP, -.7) * Basis(Vector3.RIGHT, PI * .5), 8)
	var beam := SpotLight3D.new()
	beam.position = torch + Vector3(.05, .05, .05)
	beam.transform = Transform3D(Basis.looking_at((GUARD_SEAT + Vector3(0, .7, 0)) - beam.position, Vector3.UP), beam.position)
	beam.light_color = Color(1.0, .93, .8)
	beam.light_energy = 2.2
	beam.spot_range = 5.0
	beam.spot_angle = 30.0
	beam.shadow_enabled = true
	beam.set_meta("outdoor", true)
	roots[r].add_child(beam)
	var spill := omni(r, GUARD_SEAT + Vector3(-.6, .8, -.6), Color(1.0, .9, .75), .5, 3.5)
	spill.set_meta("outdoor", true)
	# The covered walk from the gate to the main doors: steel posts and a yero roof.
	for z in [502.5, 506.0, 509.5]:
		for x in [26.5, 29.5]: bx(r, Vector3(x, 1.4, z), Vector3(.1, 2.8, .1), "#3a5a4a", true)
		bx(r, Vector3(28, 2.85, z), Vector3(3.2, .08, .08), "#3a5a4a")
	bx(r, Vector3(28, 2.95, 506.0), Vector3(3.6, .03, 8.6), "rusty_corrugated_iron", false, Basis(Vector3.FORWARD, .04))
	var walk_light := Vector3(28, 2.82, 506.0)
	cyl(r, walk_light, .06, .1, "glow#ffd8a0*2.6", Basis.IDENTITY, 8)
	var wl := omni(r, walk_light + Vector3.DOWN * .2, Color(1.0, .78, .5), 1.0, 6.5)
	wl.set_meta("outdoor", true)
	lamps.append([wl, 1.0, 3, 1.9, null])
	# The flagpole, the flag at half mast and torn; the school service jeepney that tried to get out.
	cyl(r, Vector3(12, 4.5, 506.5), .05, 9.0, "#b8b8b0", Basis.IDENTITY, 8)
	bx(r, Vector3(12, .3, 506.5), Vector3(1.6, .6, 1.6), "concrete_wall_008|#c8bea2", true)
	bx(r, Vector3(12.7, 5.6, 506.5), Vector3(1.4, .8, .01), "#2a3a8a", false, Basis(Vector3.UP, .3))
	bx(r, Vector3(12.7, 5.2, 506.5), Vector3(1.2, .4, .01), "#b8262a", false, Basis(Vector3.UP, .3))
	var jeep := place(r, "street/jeepney", Vector3(8.5, 0, 509.5), 75.0)
	if jeep != null:
		var jc := solid(r, Vector3(8.5, 1.2, 509.5), Vector3(2.0, 2.4, 6.4), Basis(Vector3.UP, deg_to_rad(75.0)))
		InteriorModelKit.shot_proxy(jc, jeep)
		label(r, Vector3(8.5, 2.45, 509.5) + Basis(Vector3.UP, deg_to_rad(75.0)) * Vector3(1.05, 0, 0), "PILCST SCHOOL SERVICE", .13, deg_to_rad(75.0) + PI * .5, Color(.95, .9, .7), false, 40.0)
	# Litter across the yard: papers, bags, shoes; the blood from the gate to the doors.
	papers(r, Vector3(28, 0, 507), Vector2(18, 5.5), 160, .12)
	belongings(r, Vector3(28, 0, 507), Vector2(16, 5.0), 18)
	drag(r, Vector3(27.5, 0, 511.5), Vector3(28.2, 0, 514.0), false)
	stain(r, "pool_big", Vector3(23.4, 0, 508.2), 1.2, 1.8, 1.4)
	stain(r, "spatter_floor", Vector3(31.0, 0, 509.6), .3, 1.6, 1.6)
	for i in 6: chair(r, Vector3(rng.randf_range(14, 44), 0, rng.randf_range(503, 512)), rng.randf() * TAU, .9)
	# A sodium lamp on a pole by the guard house, failing.
	cyl(r, Vector3(37.0, 3.0, 503.0), .07, 6.0, "#4a4a46", Basis.IDENTITY, 8)
	bar(r, Vector3(37.0, 5.9, 503.0), Vector3(35.8, 5.9, 503.6), .05, "#4a4a46")
	bx(r, Vector3(35.7, 5.82, 503.65), Vector3(.5, .12, .25), "#3a3a36")
	var sodium := omni(r, Vector3(35.7, 5.5, 503.8), Color(1.0, .62, .3), 2.2, 16.0, true)
	sodium.set_meta("outdoor", true)
	lamps.append([sodium, 2.2, 2, .8, null])
	hum(r, Vector3(35.7, 5.5, 503.8), "res://assets/audio/nichols/bulb_hum.ogg", -20.0, 6.0)

# ---------------------------------------------------------------- 0.52: the way out

## 501's door: shut and barred from inside until the knock; it swings in (the desks dragged aside) when Ma'am Teves
## opens it, shut again for the horde, and in for good if the horde forces it (`flags.door501`).
func _refuge_door(k: int, dx: float, wz: float, into: float, south: bool) -> void:
	var y := k * H
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.name = "Door 501"
	body.position = Vector3(dx - .49, y + 1.06, wz)
	roots[k].add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(.98, 2.1, .05)
	cs.shape = bs
	cs.position = Vector3(.49, 0, 0)
	body.add_child(cs)
	s.piece(body, Vector3(.49, 0, 0), bs.size, "#3e6b55")
	s.piece(body, Vector3(.17, -.06, -into * .03), Vector3(.05, .12, .05), "#b8a878")
	s.piece(body, Vector3(.49, .39, -into * .035), Vector3(.3, .4, .005), "#ece8dc")
	var note := Label3D.new()
	note.text = "MAY TAO DITO\nkatok 3x\nwe have no bites\n- STEM 12-B"
	note.pixel_size = .045 / 64
	note.font_size = 64
	note.modulate = Color(.06, .06, .1)
	note.outline_size = 0
	note.position = Vector3(.49, .39, -into * .04)
	note.rotation.y = 0.0 if south else PI
	note.double_sided = false
	note.visibility_range_end = 22.0
	body.add_child(note)
	bx(k, Vector3(dx, y + .012, wz + .12 * -into), Vector3(.9, .02, .05), "glow#ffb35a*1.4")
	_door_501 = body

## Room 208, over the kitchen's gas store: when the store went up the blast came through the floor at the back of
## the room and took the whole outer wall with it. What was in the room is against the corridor wall, burnt.
func _bombed(k: int, x0: float, x1: float, z0: float, z1: float) -> void:
	var y := k * H
	var zc := (z0 + z1) * .5
	_board(k, x0 + .03, zc, 1.0, "GEN. CHEMISTRY 1\nQuiz #4 - Stoich")
	# Soot up the walls and across the ceiling from the opening; the floor black near it.
	for i in 14:
		var at := Vector3(rng.randf_range(x0 + .6, x1 - .6), y + .006, rng.randf_range(z1 - 3.2, z1 - .2))
		bx(k, at, Vector3(rng.randf_range(.8, 2.2), .006, rng.randf_range(.6, 1.6)), "#0c0a08", false, Basis(Vector3.UP, rng.randf() * TAU))
	for i in 8:
		var at := Vector3(rng.randf_range(x0 + .6, x1 - .6), y + 3.2, rng.randf_range(z0 + 1.0, z1 - .4))
		bx(k, at, Vector3(rng.randf_range(1.2, 2.6), .01, rng.randf_range(1.0, 2.2)), "#0b0907", false, Basis(Vector3.UP, rng.randf() * TAU))
	for x in [x0 + .05, x1 - .05]:
		bx(k, Vector3(x, y + 2.0, z1 - 1.6), Vector3(.012, 2.4, 3.0), "#100d0a")
	# The ceiling: tiles down, the grid hanging, a fixture swinging on one wire, dead.
	for i in 12:
		var at := Vector3(rng.randf_range(x0 + .5, x1 - .5), y + .03, rng.randf_range(z0 + .5, z1 - .5))
		bx(k, at, Vector3(.6, .02, .6), "s:ceiling|#6a645a", false, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.3, .3)))
	for i in 6:
		var a := Vector3(rng.randf_range(x0 + 1, x1 - 1), y + 3.2, rng.randf_range(z0 + 1, z1 - 1))
		bar(k, a, a + Vector3(rng.randf_range(-.5, .5), -rng.randf_range(.6, 1.6), rng.randf_range(-.5, .5)), .015, "#2a2a28")
	# The armchairs thrown against the corridor wall, piled and bent, a desk on its back — kept west of the
	# diagonal walking lane from 208's doorway (x 14.8, z 525.0) to the center breach chute (x 9.2..12.8, z 533.85).
	for i in 3:
		for row in 2:
			if rng.randf() < .2: continue
			chair(k, Vector3(x0 + .75 + i * .9 + rng.randf_range(-.05, .05), y, z0 + 1.0 + row * 1.05 + rng.randf_range(-.05, .05)), PI * float(rng.randi() % 2) + rng.randf_range(-.15, .15), 1.0)
	for i in 2:
		chair(k, Vector3(x1 - .85 + rng.randf_range(-.08, .08), y, z0 + 3.4 + i * 1.15), PI * .5 + rng.randf_range(-.25, .25), 1.0)
	# (0.63: clear of the armchairs: it stood in the first one, which burst out when woken.)
	bx(k, Vector3(x0 + 3.4, y + .4, z0 + 3.6), Vector3(1.4, .1, .7), "dark_wooden_planks|#3a2a1c", true, Basis(Vector3.FORWARD, PI * .92))
	# Glass and concrete thrown across the floor; the bags, burnt.
	for i in 40:
		var at := Vector3(rng.randf_range(x0 + .4, x1 - .4), y + .01, rng.randf_range(z0 + .4, z1 - .3))
		bx(k, at, Vector3(rng.randf_range(.03, .12), .006, rng.randf_range(.03, .1)), "glass#5a6a70c0", false, Basis(Vector3.UP, rng.randf() * TAU))
	for i in 14:
		var at := Vector3(rng.randf_range(x0 + .6, x1 - .6), y + rng.randf_range(.04, .12), rng.randf_range(z1 - 3.0, z1 - .2))
		bx(k, at, Vector3(rng.randf_range(.12, .4), rng.randf_range(.06, .18), rng.randf_range(.1, .3)), "concrete_wall_008|#8a8270", false, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.4, .4)))
	belongings(k, Vector3(x0 + 2.2, y, z0 + 2.4), Vector2(1.4, .8), 8)
	# The opening itself, the whole width of the room: 0.63 (owner: no proper, visible way down after the blast) the
	# floor's broken edge has slumped onto the lean-to's roof as a slope of slab and rubble, walkable both ways.
	var zw := 533.85
	# (Its head flush with the floor and the wall top under the breach at z 533.95, its foot on the roof at z 536.7.)
	var top0 := Vector2(533.95, y + .01)
	var top1 := Vector2(536.7, LEAN_TOP - (536.7 - LEAN[2]) * (LEAN_TOP - LEAN_EAVE) / (LEAN[3] - LEAN[2]) + .035)
	var drop := atan2(top0.y - top1.y, top1.x - top0.x)
	var slope_n := Vector3(0, cos(drop), sin(drop))
	var slope_mid := Vector3(11.0, (top0.y + top1.y) * .5, (top0.x + top1.x) * .5)
	bx(10, slope_mid - slope_n * .12, Vector3(7.4, .24, (top1 - top0).length() + .06), "concrete_floor_02|#8a8274", true, Basis(Vector3.RIGHT, drop))
	for i in 7:
		var at := Vector3(7.8 + i * 1.08 + rng.randf_range(-.2, .2), y - .3 + rng.randf_range(-.06, .1), zw + rng.randf_range(-.6, .7))
		bx(10, at, Vector3(rng.randf_range(.6, 1.2), .16, rng.randf_range(.5, 1.0)), "concrete_floor_02|#7e776a", false, Basis(Vector3.RIGHT, drop + rng.randf_range(-.15, .15)) * Basis(Vector3.UP, rng.randf_range(-.4, .4)))
	for i in 16:
		var at := Vector3(rng.randf_range(7.2, 14.8), y - .25 + rng.randf_range(-.1, .12), zw + rng.randf_range(-.9, 1.0))
		at.y = lerpf(y, LEAN_TOP, clampf((at.z - (zw - 1.1)) / 2.2, 0.0, 1.0)) + .06
		bx(10, at, Vector3(rng.randf_range(.12, .32), rng.randf_range(.08, .18), rng.randf_range(.1, .28)), "concrete_wall_008|#b8ae94", false, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.5, .5)))
	# The broken lintel and wall ends hanging over it.
	for i in 18:
		var t := rng.randf()
		var at := Vector3(lerpf(BREACH[0], BREACH[1], t), y + 3.05 - rng.randf_range(0, .35), zw + rng.randf_range(-.12, .12))
		bx(10, at, Vector3(rng.randf_range(.3, .8), rng.randf_range(.15, .4), .32), "concrete_wall_008|#b8ae94", false, Basis(Vector3.FORWARD, rng.randf_range(-.3, .3)))
	for side in [BREACH[0], BREACH[1]]:
		for i in 5:
			var at := Vector3(side + rng.randf_range(-.15, .15), y + rng.randf_range(.3, 2.8), zw + rng.randf_range(-.1, .1))
			bx(10, at, Vector3(rng.randf_range(.2, .45), rng.randf_range(.3, .7), .32), "concrete_wall_008|#b8ae94", false, Basis(Vector3.UP, rng.randf_range(-.4, .4)))
	for i in 9:
		var a := Vector3(rng.randf_range(BREACH[0], BREACH[1]), y + 3.0, zw)
		bar(10, a, a + Vector3(rng.randf_range(-.3, .3), -rng.randf_range(.3, .75), rng.randf_range(.3, .8)), .016, "#4a3a30")
	for x in [BREACH[0] + 1.2, BREACH[1] - 1.6]:
		bx(10, Vector3(x, y + 1.4, zw + .9), Vector3(1.8, 1.6, .03), "#2a2f2c", false, Basis(Vector3.RIGHT, -1.0) * Basis(Vector3.FORWARD, .2))
	# Soot up the outside of the wall above it, to the third floor's windows, and soot outside 208's corridor door.
	bx(10, Vector3((BREACH[0] + BREACH[1]) * .5, y + 3.6, zw + .17), Vector3(BREACH[1] - BREACH[0] + 1.0, 2.2, .01), "#0d0b09")
	bx(10, Vector3((BREACH[0] + BREACH[1]) * .5, y - 1.2, zw + .17), Vector3(BREACH[1] - BREACH[0] + 2.0, 2.6, .01), "#0d0b09")
	stain(lit(k), "pool_big", Vector3(14.8, y, 524.0), 0.3, 1.8, 1.5, .85)
	# 0.63: blast-activated guidance inside Room 208 so its doorway and breach chute glow unmistakably from the 2F hall.
	for glow_at: Vector3 in [Vector3(14.6, y + 1.9, 526.0), Vector3(11.0, y + 1.8, 532.6)]:
		var gl := omni(lit(k), glow_at, Color(1.0, .48, .18), 2.6, 13.0, glow_at.z > 530.0)
		gl.visible = false
		_fires.append([gl, rng.randf() * TAU])
	var door_smoke := _smoke_column(Vector3(14.6, y + 2.3, 525.8))
	door_smoke.amount = 24
	door_smoke.scale = Vector3.ONE * .45
	roots[lit(k)].add_child(door_smoke)
	door_smoke.emitting = false
	_smoke.append(door_smoke)
	# 0.63: what the blast threw out of 208's door across the corridor: glass, plaster, a ceiling tile, soot up the
	# door frame (shown with the blast, `blast_now`). Seen from the fire escape's door down the whole corridor.
	var spill := Node3D.new()
	spill.name = "208 spill"
	spill.visible = false
	roots[k].add_child(spill)
	for i in 34:
		var at := Vector3(14.8 + rng.randf_range(-2.6, 2.6), y + .012, rng.randf_range(522.2, 525.0))
		var big := i % 4 == 0
		var p: MeshInstance3D = s.piece(spill, at, Vector3(rng.randf_range(.15, .5), .02 if not big else .08, rng.randf_range(.1, .4)), "concrete_wall_008|#a89e86" if big else "glass#5a6a70c0")
		p.rotation.y = rng.randf() * TAU
	var tile: MeshInstance3D = s.piece(spill, Vector3(13.6, y + .03, 523.4), Vector3(.6, .02, .6), "#6a645a")
	tile.material_override = mat("s:ceiling|#6a645a")
	tile.rotation = Vector3(.1, .7, 0)
	s.piece(spill, Vector3(14.8, y + 2.24, 524.96), Vector3(1.3, .5, .02), "#0c0a08")
	_blast_show.append(spill)

## 0.52: everything behind the building: the kitchen's lean-to (the gas store) under 208, the field, the covered
## court, the garden, the rear gate and the street beyond it; and, put away until the blast, the second floor's
## gallery brought down onto the grand stair.
func _way_out() -> void:
	_lean_to()
	_field()
	_rear_gate()
	_commit_stub()
	_collapse_gallery()

func _lean_to() -> void:
	var r := 12
	var x0: float = LEAN[0]
	var x1: float = LEAN[1]
	var z0: float = LEAN[2]
	var z1: float = LEAN[3]
	var drop := LEAN_TOP - LEAN_EAVE
	var depth := z1 - z0
	var tilt := atan2(drop, depth)
	var roof_basis := Basis(Vector3.RIGHT, tilt)
	var mid := Vector3((x0 + x1) * .5, (LEAN_TOP + LEAN_EAVE) * .5, (z0 + z1) * .5)
	# The roof: yero on purlins, buckled and scorched by what went off under it, but it holds.
	bx(r, mid, Vector3(x1 - x0, .06, depth / cos(tilt)), "rusty_corrugated_iron", true, roof_basis)
	for i in 6:
		var at := mid + Vector3(rng.randf_range(-5.5, 5.5), .05, rng.randf_range(-2.2, 2.2))
		at.y = lerpf(LEAN_TOP, LEAN_EAVE, (at.z - z0) / depth) + .04
		bx(r, at, Vector3(rng.randf_range(1.0, 2.4), .012, rng.randf_range(.8, 1.8)), "#0e0c0a", false, roof_basis * Basis(Vector3.UP, rng.randf_range(-.4, .4)))
	bx(r, Vector3(x1 - 1.4, LEAN_EAVE + .25, z1 - .5), Vector3(2.4, .05, 1.2), "rusty_corrugated_iron", false, Basis(Vector3.RIGHT, .5) * Basis(Vector3.FORWARD, -.2))
	# 0.63 (owner: no proper, visible way down after the blast): the blast blew the middle of the lean-to's front wall
	# out into the field and the roof's middle sheets slid down after it: a heap of hollow blocks with the yero over it,
	# a ramp from the eave to the ground, walkable both ways. The fires either side and the field's floodlight light it.
	var rz0 := z1
	var rz1 := z1 + 6.2
	var ramp_tilt := atan2(LEAN_EAVE, rz1 - rz0)
	var ramp_len := Vector2(rz1 - rz0, LEAN_EAVE).length()
	var ramp_n := Vector3(0, cos(ramp_tilt), sin(ramp_tilt))
	var ramp_mid := Vector3(11.0, LEAN_EAVE * .5, (rz0 + rz1) * .5)
	var ramp_basis := Basis(Vector3.RIGHT, ramp_tilt)
	# (Its head flush with the roof's top at the eave: anything taller there is a lip nobody walks up over.)
	bx(r, ramp_mid + Vector3(0, .035, 0) - ramp_n * .16, Vector3(3.8, .32, ramp_len + .12), "concrete_block_wall|#6e695f", true, ramp_basis)
	# The yero sheets that came down with it, lying over the blocks, buckled.
	for i in 4:
		var u := (i + .5) / 4.0
		var at := Vector3(lerpf(9.6, 12.4, float(i % 2)) + rng.randf_range(-.3, .3), lerpf(LEAN_EAVE, 0.0, u) + .05, lerpf(rz0, rz1, u))
		bx(r, at, Vector3(1.6, .03, 1.9), "rusty_corrugated_iron", false, ramp_basis * Basis(Vector3.UP, rng.randf_range(-.35, .35)) * Basis(Vector3.FORWARD, rng.randf_range(-.12, .12)))
	# The broken blocks heaped along both sides of it and spilled into the field.
	for i in 26:
		var u := rng.randf()
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(11.0 + side * rng.randf_range(1.9, 2.8), lerpf(LEAN_EAVE, 0.0, u) * rng.randf_range(.4, .95) + .1, lerpf(rz0 + .2, rz1, u))
		bx(r, at, Vector3(.4, .2, .2) * rng.randf_range(.8, 1.4), "concrete_block_wall|#8a867c", false, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.6, .6)))
	for side in [-1.0, 1.0]:
		bx(r, Vector3(11.0 + side * 2.35, .55, rz0 + 1.6), Vector3(.9, 1.1, 3.0), "concrete_block_wall|#5e5a52", true, Basis(Vector3.UP, side * .12))
	# The roof's middle torn open over the ramp's head, the purlins showing.
	for i in 3: bar(r, Vector3(9.4 + i * 1.1, LEAN_EAVE + .1, z1 - 1.4), Vector3(9.5 + i * 1.1, LEAN_EAVE - .25, z1 + .4), .05, "#4a3a30")
	# Its walls: hollow blocks; the north face under the eave is sealed by collapsed masonry so players in the field
	# cannot crawl into the burning LPG tanks and get wedged.
	for x in [x0, x1]:
		bx(r, Vector3(x, LEAN_EAVE * .5, (z0 + z1) * .5), Vector3(.2, LEAN_EAVE, depth), "concrete_block_wall|#9a968c", true)
	for x in [x0 + .8, x1 - .9]:
		bx(r, Vector3(x, .9, z1), Vector3(1.4, 1.8, .2), "concrete_block_wall|#6a665c", true)
	bx(r, Vector3((x0 + x1) * .5, 1.1, z1 - .18), Vector3(x1 - x0 - .4, 2.2, .35), "concrete_block_wall|#524d46", true)
	for i in 18:
		var at := Vector3(rng.randf_range(x0, 8.2) if i % 2 == 0 else rng.randf_range(13.8, x1), rng.randf_range(.05, .2), z1 + rng.randf_range(.2, 4.5))
		bx(r, at, Vector3(.4, .2, .2), "concrete_block_wall|#8a867c", false, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.6, .6)))
	# Inside: the cylinders (one split open), the regulator rack, the shelves, all black.
	for i in 7:
		var at := Vector3(rng.randf_range(x0 + 1.0, x1 - 1.0), .55, rng.randf_range(z0 + .8, z1 - .8))
		var b := Basis(Vector3.FORWARD, PI * .5) * Basis(Vector3.UP, rng.randf() * TAU) if i % 2 == 0 else Basis.IDENTITY
		if i % 2 == 0: at.y = .32
		cyl(r, at, .3, 1.1, "#1a1816", b, 12)
		solid(r, at, Vector3(.56, 1.1, .56), b)   # 0.59: they were walked through (no collider)
	bx(r, Vector3((x0 + x1) * .5, 1.2, z0 + .3), Vector3(5.0, .1, .5), "#141210")
	bx(r, Vector3((x0 + x1) * .5, .01, (z0 + z1) * .5), Vector3(x1 - x0 - .3, .01, depth - .3), "#0b0a08")
	label(r, Vector3(x0 - .11, 1.9, (z0 + z1) * .5 - 1.4), "LPG STORAGE\nNO SMOKING", .09, -PI * .5, Color(.7, .1, .08))
	# The fires still burning on the flanks once it goes up (lit by the blast: `sync`), and the smoke.
	# (0.63: and a third down at the ramp's foot, burning in what was thrown out with the wall: it lights the way down.)
	for at in [Vector3(7.1, 3.05, z0 + 2.4), Vector3(14.9, 2.9, z1 - 1.5), Vector3(14.0, .15, z1 + 4.6)]:
		var f := omni(r, at + Vector3.UP * .7, Color(1.0, .55, .22), 0.0, 14.0, _fires.is_empty())
		f.distance_fade_begin = 90.0
		f.set_meta("outdoor", true)
		f.visible = false
		_fires.append([f, rng.randf() * TAU])
		var flame := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = .45
		fm.height = .8
		flame.mesh = fm
		flame.material_override = mat("glow#ff7a2a*4.0")
		flame.position = at
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.visible = false
		roots[r].add_child(flame)
		_fires.append([flame, 0.0])
		var smoke := _smoke_column(at + Vector3.UP * .8)
		roots[r].add_child(smoke)
		smoke.emitting = false
		_smoke.append(smoke)
	# The landing apron in front of the center drop-off is cleared dirt/ash.
	bx(r, Vector3(11.0, .007, 543.0), Vector3(5.2, .014, 5.2), "brown_mud_02|#5a4d3e")
	papers(r, Vector3(11.0, 0, 542.5), Vector2(3, 2), 20, .05)

func _smoke_column(at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = at
	p.amount = 40
	p.lifetime = 7.0
	p.preprocess = 4.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(.1, 1, .25)
	pm.spread = 14.0
	pm.initial_velocity_min = .8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, .35, .15)
	pm.scale_min = 1.2
	pm.scale_max = 2.8
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = .6
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, .15, 1.0])
	fade.colors = PackedColorArray([Color(.08, .075, .07, 0.0), Color(.1, .095, .09, .5), Color(.07, .07, .07, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 2.4)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_texture = _soft_dot()
	quad.material = sm
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 30, 18))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

var _dot: ImageTexture
func _soft_dot() -> ImageTexture:
	if _dot != null: return _dot
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) * clampf(1.0 - d, 0.0, 1.0)))
	_dot = ImageTexture.create_from_image(img)
	return _dot

## The school field: grass worn to dirt in the goal mouths, the covered court with its stage, bleachers, the
## Gulayan sa Paaralan garden, palms and an acacia along the walls, a few lamps (most out).
func _field() -> void:
	var r := 12
	var z0 := 540.0
	var z1 := FIELD_END
	bx(r, Vector3(28, -.2, (z0 + z1) * .5), Vector3(68.6, .4, z1 - z0), "sparse_grass|#7e8a6a", true)
	for spot in [Vector3(20, 0, 546), Vector3(20, 0, 594), Vector3(20, 0, 570), Vector3(8, 0, 560), Vector3(30, 0, 582)]:
		bx(r, spot + Vector3.UP * .005, Vector3(rng.randf_range(5, 9), .01, rng.randf_range(3, 6)), "brown_mud_02|#6a5a48", false, Basis(Vector3.UP, rng.randf_range(-.3, .3)))
	# The walls: on round the field from the yard's, and across its far end with the gate in it.
	var wall_id := "painted_plaster_wall|#e6dcb8"
	for x in [-6.15, 62.15]:
		bx(r, Vector3(x, 1.6, (z0 + z1) * .5), Vector3(.3, 3.2, z1 - z0), wall_id, true)
		bx(r, Vector3(x, .45, (z0 + z1) * .5), Vector3(.34, .9, z1 - z0), "s:green")
	for span in [[-6.3, REAR_GATE.x - 2.2], [REAR_GATE.x + 2.2, 62.3]]:
		var cx: float = (span[0] + span[1]) * .5
		var len: float = span[1] - span[0]
		bx(r, Vector3(cx, 1.6, z1 + .15), Vector3(len, 3.2, .3), wall_id, true)
		bx(r, Vector3(cx, .45, z1 - .02), Vector3(len, .9, .04), "s:green")
		bx(r, Vector3(cx, 3.28, z1 + .15), Vector3(len, .16, .36), "#2f6a3a")
	# Football goals, nets torn.
	for gz in [544.0, 596.0]:
		var into: float = 1.0 if gz < 570 else -1.0
		for gx in [16.3, 23.7]: cyl(r, Vector3(gx, 1.2, gz), .06, 2.4, "#d8d6cc", Basis.IDENTITY, 8)
		bx(r, Vector3(20, 2.42, gz), Vector3(7.5, .1, .1), "#d8d6cc")
		# The net: strings on a slope back from the bar, torn through in places.
		for i in 25:
			if rng.randf() < .12: continue
			var nx := 16.4 + i * .3
			bar(r, Vector3(nx, 2.4, gz), Vector3(nx, 0.0, gz - into * 1.4), .012, "#b8b6ae")
		for j in 8:
			var t := (j + .5) / 8.0
			bx(r, Vector3(20, 2.4 * (1.0 - t), gz - into * 1.4 * t), Vector3(7.4, .012, .012), "#b8b6ae")
	# The covered court: the slab, its lines, the hoops, the steel roof on its columns, the stage at the north end.
	var cx0 := 38.0
	var cx1 := 60.0
	var cz0 := 552.0
	var cz1 := 582.0
	var cc := Vector3((cx0 + cx1) * .5, 0, (cz0 + cz1) * .5)
	bx(r, cc + Vector3(0, .05, 0), Vector3(cx1 - cx0, .1, cz1 - cz0), "concrete_floor_02|#8a8a84", true)
	for line: Array in [[Vector3(0, .105, 0), Vector3(15.0, .005, .08)], [Vector3(-7.5, .105, 0), Vector3(.08, .005, 26.0)], [Vector3(7.5, .105, 0), Vector3(.08, .005, 26.0)],
			[Vector3(0, .105, -13.0), Vector3(15.0, .005, .08)], [Vector3(0, .105, 13.0), Vector3(15.0, .005, .08)]]:
		bx(r, cc + line[0], line[1], "#d8d0b0")
	for hz in [cz0 + 1.4, cz1 - 1.4]:
		var face: float = 1.0 if hz < cc.z else -1.0
		cyl(r, Vector3(cc.x, 1.6, hz - face * .9), .09, 3.2, "#2a4a6a", Basis.IDENTITY, 10)
		bx(r, Vector3(cc.x, 3.3, hz), Vector3(1.8, 1.05, .05), "#e8e8e0")
		cyl(r, Vector3(cc.x, 3.05, hz + face * .3), .23, .02, "#c85020", Basis.IDENTITY, 16)
	for x in [cx0, cx1]:
		for i in 4:
			var z := lerpf(cz0, cz1, i / 3.0)
			bx(r, Vector3(x, 3.75, z), Vector3(.3, 7.5, .3), "#5a5a56", true)
	bx(r, Vector3(cc.x, 7.6, cc.z), Vector3(cx1 - cx0 + 1.5, .08, cz1 - cz0 + 1.5), "corrugated_iron_02|#7a7a74", false)
	for i in 6:
		var z := lerpf(cz0, cz1, i / 5.0)
		bx(r, Vector3(cc.x, 7.35, z), Vector3(cx1 - cx0, .25, .12), "#4a4a46")
	bx(r, Vector3(cc.x, .55, cz1 + 2.2), Vector3(cx1 - cx0 - 4.0, 1.1, 4.4), "concrete_wall_008|#b8ae94", true)
	bx(r, Vector3(cc.x, 3.6, cz1 + 4.35), Vector3(cx1 - cx0 - 4.0, 5.0, .2), "concrete_wall_008|#b8ae94", true)
	bx(r, Vector3(cc.x, 3.6, cz1 + 4.22), Vector3(12.0, 3.0, .02), "#e8d8a8", false, Basis(Vector3.FORWARD, .02))
	label(r, Vector3(cc.x, 4.3, cz1 + 4.2), "PILCST INTRAMURALS 2026", .5, PI, Color(.45, .08, .1), false, 90.0)
	label(r, Vector3(cc.x, 3.5, cz1 + 4.2), "Galing ng Agham, Lakas ng Kabataan  •  Nov. 14-21", .2, PI, Color(.2, .15, .1), false, 90.0)
	# Bleachers on the court's west side, chairs left on them.
	for i in 4:
		bx(r, Vector3(cx0 - 1.2 - i * .7, .25 + i * .45, cc.z), Vector3(.7, .5 + i * .9, 18.0), "concrete_wall_008|#a8a090", true)
	for i in 8: chair(r, Vector3(rng.randf_range(cx0 + 2, cx1 - 2), .1, rng.randf_range(cz0 + 2, cz1 - 2)), rng.randf() * TAU, .9)
	# The garden: raised plots of pechay and okra, the sign, bamboo along the west wall, palms and an acacia.
	for i in 5:
		var at := Vector3(-1.5, .18, 552.0 + i * 3.4)
		bx(r, at, Vector3(4.2, .36, 2.2), "brown_mud_02|#4a3a2a", true)
		for j in 10: bx(r, at + Vector3(rng.randf_range(-1.8, 1.8), .26, rng.randf_range(-.8, .8)), Vector3(.25, rng.randf_range(.15, .4), .25), "#3a5a2a")
	bx(r, Vector3(1.6, 1.0, 550.4), Vector3(1.6, 1.0, .05), "#e8e0c8")
	label(r, Vector3(1.6, 1.05, 550.36), "GULAYAN SA PAARALAN\nSTEM 11-A", .12, PI, Color(.1, .3, .1), false, 40.0)
	cyl(r, Vector3(1.6, .25, 550.4), .04, .5, "#4a4a46")
	for i in 3: place(r, "fields/bamboo_clump", Vector3(-4.6, 0, 568.0 + i * 9.0), rng.randf() * 360.0, 1.0)
	for spot in [Vector3(4, 0, 586), Vector3(-3, 0, 596), Vector3(33, 0, 542.5), Vector3(60, 0, 590), Vector3(12, 0, 596.5)]:
		place(r, "nature/palm_coconut_a" if rng.randf() < .5 else "nature/palm_coconut_b", spot, rng.randf() * 360.0, rng.randf_range(.9, 1.15))
	place(r, "nature/island_tree_01", Vector3(28, 0, 590), 40.0, 1.3)
	place(r, "nature/banana_plant", Vector3(-3.5, 0, 547.5), 0.0, 1.0)
	# Lamps on poles: one sodium still lit (failing), the others dark.
	for spec: Array in [[Vector3(2, 0, 543), true], [Vector3(30, 0, 566), false], [Vector3(10, 0, 598), false], [Vector3(36, 0, 598), true]]:
		var at: Vector3 = spec[0]
		cyl(r, at + Vector3.UP * 3.5, .08, 7.0, "#4a4a46", Basis.IDENTITY, 8)
		bx(r, at + Vector3(0, 7.0, .5), Vector3(.5, .14, .9), "#3a3a36")
		if spec[1]:
			var l := omni(r, at + Vector3(0, 6.6, .6), Color(1.0, .62, .3), 2.6, 24.0, true)
			l.set_meta("outdoor", true)
			l.distance_fade_begin = 70.0
			lamps.append([l, 2.6, 2, rng.randf_range(.6, 2.4), null])
	# On the back of the building, on the generator like the front's: floodlights over the field, one failing, plus one aimed straight down the Room 208 escape chute.
	var chute_fl := SpotLight3D.new()
	chute_fl.position = Vector3(11.0, 5.2, 534.3)
	chute_fl.transform = Transform3D(Basis.looking_at(Vector3(11.0, 0.0, 544.0) - chute_fl.position, Vector3.UP), chute_fl.position)
	chute_fl.light_color = Color(1.0, .86, .66)
	chute_fl.light_energy = 3.4
	chute_fl.spot_range = 28.0
	chute_fl.spot_angle = 42.0
	chute_fl.shadow_enabled = false
	chute_fl.distance_fade_enabled = true
	chute_fl.distance_fade_begin = 90.0
	chute_fl.set_meta("outdoor", true)
	roots[r].add_child(chute_fl)
	bx(r, Vector3(11.0, 5.25, 534.2), Vector3(.45, .3, .3), "#2a2a28")
	bx(r, Vector3(11.0, 5.18, 534.37), Vector3(.38, .22, .02), "glow#ffe8c0*3.0")
	lamps.append([chute_fl, 3.4, 1, .5, null])
	for x in [17.0, 41.0]:
		var fl := SpotLight3D.new()
		fl.position = Vector3(x, 4.6, 534.3)
		fl.transform = Transform3D(Basis.looking_at(Vector3(x + (28.0 - x) * .25, 0, 556.0) - fl.position, Vector3.UP), fl.position)
		fl.light_color = Color(.86, .93, 1.0)
		fl.light_energy = 3.2
		fl.spot_range = 34.0
		fl.spot_angle = 52.0
		fl.shadow_enabled = x > 30.0
		fl.distance_fade_enabled = true
		fl.distance_fade_begin = 90.0
		fl.set_meta("outdoor", true)
		roots[r].add_child(fl)
		bx(r, Vector3(x, 4.65, 534.2), Vector3(.45, .3, .3), "#2a2a28")
		bx(r, Vector3(x, 4.58, 534.37), Vector3(.38, .22, .02), "glow#e8f0ff*3.0")
		lamps.append([fl, 3.2, 2 if x < 30.0 else 1, 1.3, null])
	# The fifth floor's fire door: a sodium lamp over it on the outside, failing.
	bx(r, Vector3(56.1, 4 * H + 2.8, 521.9), Vector3(.25, .14, .3), "#2a2a28")
	var sodium5 := omni(r, Vector3(56.6, 4 * H + 2.6, 522.2), Color(1.0, .62, .3), 1.2, 8.0)
	sodium5.set_meta("outdoor", true)
	lamps.append([sodium5, 1.2, 2, rng.randf_range(.6, 2.4), null])
	# What was left out there: bags, a sports banner down, a ball.
	papers(r, Vector3(26, 0, 566), Vector2(24, 18), 120, .06)
	belongings(r, Vector3(26, 0, 566), Vector2(22, 16), 20)
	bx(r, Vector3(28, .05, 560), Vector3(5.0, .02, 1.2), "#5a1a20", false, Basis(Vector3.UP, .4))
	cyl(r, Vector3(24, .11, 575), .11, .22, "#c87830", Basis.IDENTITY, 12)
	for i in 4:
		var a := Vector3(rng.randf_range(4, 36), 0, rng.randf_range(546, 592))
		drag(r, a, a + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)))

## The rear gate at the far end of the field (0.53: shut, chained and padlocked; its key is on Heavy-arm, the guard who
## kept it); beyond it a street of the city, dark, a fire somewhere toward downtown.
func _rear_gate() -> void:
	var r := 12
	var g := REAR_GATE
	var wall_id := "painted_plaster_wall|#e6dcb8"
	for x in [g.x - 2.2, g.x + 2.2]: bx(r, Vector3(x, 1.9, g.z + .15), Vector3(.5, 3.8, .5), wall_id, true)
	bx(r, Vector3(g.x, 3.95, g.z + .1), Vector3(4.9, .7, .1), "#5a1a20")
	label(r, Vector3(g.x, 4.02, g.z), "PILCST  •  REAR GATE", .2, PI, Color(.98, .9, .62), false, 80.0)
	label(r, Vector3(g.x, 4.02, g.z + .2), "PILCST  •  REAR GATE", .2, 0.0, Color(.98, .9, .62), false, 80.0)
	# 0.53: shut. Chained and padlocked on the field's side; the guard who kept it (Heavy-arm, scripts/coop/heavyarm.gd)
	# still has its key on his lanyard. Two leaves hung at the posts that swing out onto the street once unlocked.
	_rear_body = StaticBody3D.new()
	_rear_body.name = "Rear gate leaves"
	_rear_body.collision_layer = 2
	_rear_body.collision_mask = 0
	roots[r].add_child(_rear_body)
	var shut := CollisionShape3D.new()
	var shut_box := BoxShape3D.new()
	shut_box.size = Vector3(4.0, 3.0, .3)
	shut.shape = shut_box
	shut.position = Vector3(g.x, 1.5, g.z)
	_rear_body.add_child(shut)
	_rear_leaves.clear()
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "Rear gate hinge"
		roots[r].add_child(hinge)
		hinge.position = Vector3(g.x + side * 1.97, 0, g.z)
		var leaf := Node3D.new()
		hinge.add_child(leaf)
		leaf.position = Vector3(-side * .98, 1.3, 0)
		for i in 8: s.piece(leaf, Vector3(-.9 + i * .26, 0, 0), Vector3(.035, 2.4, .035), "#2f6a3a")
		for v in [-1.1, 0.0, 1.1]: s.piece(leaf, Vector3(0, v, 0), Vector3(1.9, .07, .06), "#2f6a3a")
		s.piece(leaf, Vector3(0, -.62, .01), Vector3(1.9, .9, .015), "#3a5e40")
		_rear_leaves.append([hinge, side])
	_rear_chain = Node3D.new()
	_rear_chain.name = "Rear gate chain"
	roots[r].add_child(_rear_chain)
	for i in 10: s.piece(_rear_chain, Vector3(g.x - .34 + i * .075, 1.3 + .06 * sin(i * 1.3), g.z - .06), Vector3(.065, .035, .022), "#6a6a64")
	s.piece(_rear_chain, Vector3(g.x + .03, 1.13, g.z - .09), Vector3(.075, .095, .04), "#8a7a40")
	s.piece(_rear_chain, Vector3(g.x + .03, 1.2, g.z - .09), Vector3(.05, .05, .012), "#9a9a92")
	drag(r, Vector3(g.x - .5, 0, g.z - 6.0), Vector3(g.x + .2, 0, g.z - .8), false)
	# The temporary stub street outside (replaced when Outer Street loads: `drop_rear_stub()`).
	_rear_stub = Node3D.new()
	_rear_stub.name = "RearStub"
	roots[r].add_child(_rear_stub)
	_rear_stub_body = StaticBody3D.new()
	_rear_stub_body.name = "RearStubBody"
	_rear_stub_body.collision_layer = 2
	_rear_stub_body.collision_mask = 0
	_rear_stub.add_child(_rear_stub_body)
	_stub_bx(Vector3(g.x, -.2, g.z + 7.0), Vector3(90.0, .4, 13.4), "asphalt_02", true)
	_stub_bx(Vector3(g.x, -.15, g.z + 1.0), Vector3(90.0, .3, 1.4), "concrete_pavement", true)
	for i in 12: _stub_bx(Vector3(g.x - 40.0 + i * 7.0, .005, g.z + 7.0), Vector3(3.0, .01, .12), "#c8c0a0")
	var jeep: Node3D = InteriorModelKit.place(_rear_stub, "street/jeepney", Vector3(g.x - 9.0, 0, g.z + 5.5), 100.0, 1.0, "bottom", Vector3.ZERO)
	if jeep != null:
		for gm in jeep.find_children("*", "GeometryInstance3D", true, false): (gm as GeometryInstance3D).layers |= 2
		_stub_solid(Vector3(g.x - 9.0, 1.2, g.z + 5.5), Vector3(2.0, 2.4, 6.4), Basis(Vector3.UP, deg_to_rad(100.0)))
	var trike: Node3D = InteriorModelKit.place(_rear_stub, "street/tricycle_a", Vector3(g.x + 7.5, 0, g.z + 9.5), 160.0, 1.0, "bottom", Vector3.ZERO)
	if trike != null:
		for gm in trike.find_children("*", "GeometryInstance3D", true, false): (gm as GeometryInstance3D).layers |= 2
		_stub_solid(Vector3(g.x + 7.5, .8, g.z + 9.5), Vector3(1.6, 1.6, 2.4), Basis(Vector3.UP, deg_to_rad(160.0)))
	for i in 9:
		var bx0 := g.x - 44.0 + i * 11.0
		var floors_up := 2 + rng.randi() % 4
		var tall := floors_up * 3.2
		var col := Color.from_hsv(rng.randf_range(.05, .14), rng.randf_range(.08, .2), rng.randf_range(.22, .34))
		_stub_bx(Vector3(bx0, tall * .5, g.z + 19.5), Vector3(10.4, tall, 6.0), "concrete_wall_008|#%s" % col.to_html(false), true)
		_stub_bx(Vector3(bx0, 3.0, g.z + 16.3), Vector3(10.4, .15, .8), "#3a3a36")
		for f in floors_up:
			for w in 3:
				if rng.randf() < .12:
					_stub_bx(Vector3(bx0 - 3.2 + w * 3.2, f * 3.2 + 1.7, g.z + 16.48), Vector3(1.4, 1.1, .02), "glow#e8b070*0.8")
				else:
					_stub_bx(Vector3(bx0 - 3.2 + w * 3.2, f * 3.2 + 1.7, g.z + 16.48), Vector3(1.4, 1.1, .02), "#0c0d0e")
	var glow := _stub_omni(Vector3(g.x + 24.0, 9.0, g.z + 40.0), Color(1.0, .45, .18), 3.0, 60.0)
	glow.distance_fade_enabled = false
	_stub_lamps.append([glow, 3.0, 6, 1.7, null])
	var city_smoke := _smoke_column(Vector3(g.x + 24.0, 12.0, g.z + 38.0))
	city_smoke.amount = 30
	city_smoke.scale = Vector3.ONE * 3.0
	_rear_stub.add_child(city_smoke)
	# A caged bulb over the gate, still lit on the generator: the way out, from across the field.
	bx(r, Vector3(g.x, 3.45, g.z - .2), Vector3(.22, .14, .22), "#2a2a28")
	cyl(r, Vector3(g.x, 3.33, g.z - .2), .06, .1, "glow#ffd8a0*3.0", Basis.IDENTITY, 8)
	var gate_bulb := omni(r, Vector3(g.x, 3.1, g.z - .8), Color(1.0, .78, .5), 1.6, 12.0, true)
	gate_bulb.set_meta("outdoor", true)
	gate_bulb.distance_fade_begin = 80.0
	lamps.append([gate_bulb, 1.6, 2, .7, null])
	var street_lamp := _stub_omni(Vector3(g.x - 3.0, 6.0, g.z + 2.0), Color(1.0, .7, .4), 1.6, 16.0, true)
	_stub_lamps.append([street_lamp, 1.6, 2, .9, null])
	_stub_cyl(Vector3(g.x - 3.0, 3.2, g.z + 1.6), .08, 6.4, "#4a4a46", Basis.IDENTITY, 8)
	# The far side of the stub street: freed when Outer Street takes over (`drop_rear_stub`).
	_stub_solid(Vector3(g.x, 3.0, g.z + 16.0), Vector3(90.0, 6.0, .3))
	for x in [g.x - 44.0, g.x + 44.0]: _stub_solid(Vector3(x, 3.0, g.z + 8.0), Vector3(.3, 6.0, 16.0))
	_stub_solid(Vector3((62.3 + g.x + 44.0) * .5, 1.6, g.z + .15), Vector3(g.x + 44.0 - 62.3, 3.2, .3))

## The second floor's gallery comes down when the gas store goes up: the ceiling slab and its beam across the
## gallery's openings onto the corridor, the desks and rubble piled under them. Built now, kept hidden and not solid
## until `flags.blast` (`sync`).
func _collapse_gallery() -> void:
	var k := 1
	var y := k * H
	_collapse = Node3D.new()
	_collapse.name = "Gallery collapse"
	_collapse.visible = false
	roots[k].add_child(_collapse)
	_collapse_body = StaticBody3D.new()
	_collapse_body.collision_layer = 0
	_collapse_body.name = "Gallery collapse body"
	roots[k].add_child(_collapse_body)
	var x0: float = COLLAPSE[0]
	var x1: float = COLLAPSE[1]
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(x1 - x0 + .4, 3.4, 2.2)
	cs.shape = bs
	cs.position = Vector3((x0 + x1) * .5, y + 1.7, 525.85)
	_collapse_body.add_child(cs)
	for i in 3:
		var slab: MeshInstance3D = s.piece(_collapse, Vector3(x0 + 1.4 + i * 2.6, y + 1.3, 526.1), Vector3(2.8, .25, 2.6), "concrete_floor_02|#8a8274")
		slab.basis = Basis(Vector3.RIGHT, rng.randf_range(.7, 1.1)) * Basis(Vector3.FORWARD, rng.randf_range(-.3, .3))
	var beam: MeshInstance3D = s.piece(_collapse, Vector3((x0 + x1) * .5, y + 1.6, 525.6), Vector3(x1 - x0 + .4, .4, .35), "concrete_wall_008|#9a927e")
	beam.basis = Basis(Vector3.FORWARD, .12)
	for i in 30:
		var at := Vector3(rng.randf_range(x0, x1), y + rng.randf_range(.1, 1.2), rng.randf_range(525.2, 527.0))
		var chunk: MeshInstance3D = s.piece(_collapse, at, Vector3(rng.randf_range(.2, .7), rng.randf_range(.15, .4), rng.randf_range(.2, .6)), "concrete_wall_008|#a89e86")
		if i % 3 == 0: chunk.material_override = mat("s:ceiling")
		chunk.basis = Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.6, .6))
	for i in 8:
		var a := Vector3(rng.randf_range(x0, x1), y + 3.2, rng.randf_range(525.0, 526.5))
		var wire: MeshInstance3D = s.piece(_collapse, a + Vector3(0, -.6, 0), Vector3(.015, 1.2, .015), "#1a1a1a")
		wire.basis = Basis(Vector3.FORWARD, rng.randf_range(-.4, .4))
	# Dust still coming down.
	var dust := _smoke_column(Vector3((x0 + x1) * .5, y + 2.6, 524.8))
	(dust.process_material as ParticleProcessMaterial).gravity = Vector3(0, -.25, 0)
	(dust.process_material as ParticleProcessMaterial).direction = Vector3(0, -1, 0)
	dust.amount = 24
	_collapse.add_child(dust)
	dust.position = Vector3((x0 + x1) * .5, y + 2.6, 524.8)

func _stub_bx(at: Vector3, size: Vector3, id: String, collide := false, basis := Basis.IDENTITY) -> void:
	if not _stub_kits.has(id): _stub_kits[id] = InteriorBoxKit.new()
	_stub_kits[id].box(size, Transform3D(basis, at))
	if collide: _stub_solid(at, size, basis)

func _stub_cyl(at: Vector3, radius: float, h: float, id: String, basis := Basis.IDENTITY, sides := 10) -> void:
	if not _stub_kits.has(id): _stub_kits[id] = InteriorBoxKit.new()
	_stub_kits[id].cylinder(radius, h, sides, Transform3D(basis, at))

func _stub_solid(at: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	if _rear_stub_body == null: return
	var c := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	c.shape = b
	c.transform = Transform3D(basis, at)
	_rear_stub_body.add_child(c)

func _stub_omni(at: Vector3, color: Color, energy: float, reach: float, shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	l.distance_fade_enabled = true
	l.distance_fade_begin = 34.0
	l.distance_fade_length = 10.0
	l.light_specular = .35
	l.set_meta("outdoor", true)
	_rear_stub.add_child(l)
	return l

func _commit_stub() -> void:
	if _rear_stub == null: return
	for id: String in _stub_kits:
		var mesh := MeshInstance3D.new()
		mesh.mesh = _stub_kits[id].commit()
		mesh.material_override = mat(id)
		mesh.layers = 1 | 2 | 8
		mesh.visibility_range_end = 160.0
		if id.begins_with("glass"): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rear_stub.add_child(mesh)
	_stub_kits.clear()

func drop_rear_stub() -> void:
	_stub_lamps.clear()
	_stub_kits.clear()
	_rear_stub_body = null
	if _rear_stub != null and is_instance_valid(_rear_stub):
		_rear_stub.queue_free()
	_rear_stub = null

func seal_rear_gate() -> void:
	_rear_sealed = true
	_rear_at = 0.0
	if _rear_body != null: _rear_body.collision_layer = 2
	if _rear_chain != null: _rear_chain.visible = true
	for l: Array in _rear_leaves: (l[0] as Node3D).rotation.y = 0.0

# ---------------------------------------------------------------- every frame (every peer)

func sync(flags: Dictionary, delta: float, viewer: Vector3) -> void:
	var want: float = 1.0 if bool(flags.get("school_gate", false)) and not bool(flags.get("school_shut", false)) else 0.0
	if not is_equal_approx(gate_open, want):
		if absf(want - gate_open) > .02 and not _gate_sound.playing: _gate_sound.play()
		gate_open = move_toward(gate_open, want, delta / 2.6)
		gate.position = GATE + Vector3(-3.6 * gate_open, 0, 0)
	var now := Time.get_ticks_msec() * .001
	for l: Array in lamps:
		var light: Light3D = l[0]
		if not is_instance_valid(light) or not light.is_visible_in_tree(): continue
		var base: float = l[1]
		var mode: int = l[2]
		var ph: float = l[3]
		var on := 1.0
		if mode == 2:
			# A failing tube: steady, then a burst of stutter every few seconds.
			var cycle := fmod(now * (.18 + ph * .05) + ph * 7.0, 1.0)
			if cycle < .16: on = 1.0 if sin(now * (38.0 + ph * 9.0)) > .1 else .05
			else: on = .92 + .08 * sin(now * 2.0 + ph)
		elif mode == 3:
			# Dying: mostly dark, a weak blink now and then.
			var cycle := fmod(now * (.23 + ph * .04) + ph * 3.0, 1.0)
			on = (.75 if sin(now * 47.0 + ph) > -.2 else 0.0) if cycle < .12 else 0.0
		elif mode == 6:
			# A TV's static: it never settles.
			on = .55 + .45 * sin(now * 31.0 + ph) * sin(now * 7.3 + ph * 2.0)
		light.light_energy = base * on
		if l[4] != null: (l[4] as StandardMaterial3D).emission_energy_multiplier = 2.4 * maxf(on, .02)
	if _rear_stub != null and is_instance_valid(_rear_stub):
		for l: Array in _stub_lamps:
			var light: Light3D = l[0]
			if not is_instance_valid(light) or not light.is_visible_in_tree(): continue
			var base: float = l[1]
			var mode: int = l[2]
			var ph: float = l[3]
			var on := 1.0
			if mode == 2:
				var cycle := fmod(now * (.18 + ph * .05) + ph * 7.0, 1.0)
				if cycle < .16: on = 1.0 if sin(now * (38.0 + ph * 9.0)) > .1 else .05
				else: on = .92 + .08 * sin(now * 2.0 + ph)
			elif mode == 6:
				on = .55 + .45 * sin(now * 31.0 + ph) * sin(now * 7.3 + ph * 2.0)
			light.light_energy = base * on
	for sw: Array in swings:
		var pivot: Node3D = sw[0]
		if not pivot.is_visible_in_tree(): continue
		pivot.rotation.x = float(sw[2]) * sin(now * 1.25 + float(sw[1])) + .08 * sin(now * 3.1 + float(sw[1]))
	if _tv_mat != null: _tv_mat.uv1_offset = Vector3(rng.randf(), rng.randf(), 0)
	_doors_sync(flags, delta)
	_mech_sync(flags, delta)
	_way_out_sync(flags, delta, now)
	_bells(flags, viewer)
	view(viewer)
	_ambience(delta, viewer)

## 0.52 (every peer, once; the host as soon as it happens): the gas store has gone up: the gallery down and solid,
## the fires lit, the smoke rising. (`route(0)` is the way out through 208 from now on.)
func blast_now() -> void:
	if blasted: return
	blasted = true
	_blast_hall()
	for n: Node3D in _blast_show: n.visible = true
	if _collapse != null: _collapse.visible = true
	if _collapse_body != null: _collapse_body.collision_layer = 2
	for f: Array in _fires: (f[0] as Node3D).visible = true
	for sm: GPUParticles3D in _smoke: sm.emitting = true

## 0.52 (every peer): 501's door and its desks, the fifth floor's fire door and its chain, the blast's fires, smoke
## and the gallery brought down, from the host's flags.
func _way_out_sync(flags: Dictionary, delta: float, now: float) -> void:
	escape_open = bool(flags.get("fire5", false))
	var door: int = int(flags.get("door501", 0))
	var want := 0.0 if door == 0 else (1.0 if door == 1 else 1.35)
	if _door_501 != null and not is_equal_approx(_door_501_at, want):
		_door_501_at = move_toward(_door_501_at, want, delta * (3.0 if door == 2 else 1.1))
		_door_501.rotation.y = PI * .5 * _door_501_at
		if _barricade_501 != null: _barricade_501.position = Vector3(-1.5, 0, -.5) * minf(_door_501_at, 1.0)
	if _fire_5 != null and escape_open and _fire_5_at < 1.0:
		_fire_5_at = move_toward(_fire_5_at, 1.0, delta * .9)
		_fire_5.rotation.y = PI * .5 * _fire_5_at
		if _chain_5 != null: _chain_5.visible = false
	_rear_gate_sync(flags, delta)
	if bool(flags.get("blast", false)): blast_now()
	if not blasted: return
	for f: Array in _fires:
		var node: Node3D = f[0]
		if not node.is_visible_in_tree(): continue
		var ph: float = f[1]
		var flick := .75 + .25 * sin(now * 13.0 + ph) * sin(now * 7.7 + ph * 1.7)
		if node is OmniLight3D: (node as OmniLight3D).light_energy = 2.6 * flick
		else: node.scale = Vector3(1.0, .8 + .4 * flick, 1.0)

## 0.53: the rear gate unlocked: the chain off, the leaves swung out onto the street, the way clear.
func _rear_gate_sync(flags: Dictionary, delta: float) -> void:
	if _rear_body == null: return
	if _rear_sealed or bool(flags.get("outer_sealed_behind", false)):
		if not _rear_sealed: seal_rear_gate()
		return
	if not bool(flags.get("reargate", false)) or _rear_at >= 1.0: return
	if _rear_at == 0.0:
		_rear_body.collision_layer = 0
		if _rear_chain != null: _rear_chain.visible = false
		var creak := AudioStreamPlayer3D.new()
		creak.stream = load("res://assets/audio/sfx/impactMetal_heavy_000.ogg")
		creak.unit_size = 8.0
		creak.pitch_scale = .7
		_rear_body.add_child(creak)
		creak.position = REAR_GATE + Vector3.UP
		creak.play()
	_rear_at = move_toward(_rear_at, 1.0, delta * .45)
	var swing := smoothstep(0.0, 1.0, _rear_at) * 1.75
	for l: Array in _rear_leaves: (l[0] as Node3D).rotation.y = float(l[1]) * swing

## 0.51: a floor reached for the first time: the class bell rings through the building on the last of the
## generator (it was wired to the same line), and cuts out.
func _bells(flags: Dictionary, viewer: Vector3) -> void:
	# (0.55: floors a debug jump crossed on the way up rang long ago: `flags.quiet_floors`, mission `_floors_crossed`.)
	var quiet: int = int(flags.get("quiet_floors", 0))
	for k in FLOORS:
		if _bell_rung.has(k) or not bool(flags.get("floor%d" % k, false)): continue
		_bell_rung[k] = true
		if k == 0 or quiet & (1 << k): continue
		if _bell == null:
			_bell = AudioStreamPlayer3D.new()
			_bell.stream = load("res://assets/school/audio/bell.wav")
			_bell.unit_size = 14.0
			_bell.max_distance = 90.0
			_bell.volume_db = -4.0
			add_child(_bell)
		_bell.global_position = world(Vector3(28, k * H + 3.0, CZ))
		_bell.play()

## Which floors are drawn for someone standing at `viewer` (world).
func view(viewer: Vector3) -> void:
	var p := viewer - s.position
	var inside := p.x > .2 and p.x < 55.8 and p.z > 514.2 and p.z < 533.8 and p.y > -1.0 and p.y < FLOORS * H + .5
	if p.x >= 55.8 and p.x < FIRE_X1 + .4 and p.z > 520.0 and p.z < 532.0 and p.y > 2.0: inside = true
	var f: int = clampi(roundi(p.y / H), 0, FLOORS - 1) if inside else -1
	# (0.51: the floors above and below have their lights, decals and words drawn only from where they can be seen:
	# a stairwell, the grand stair's gallery, the fire escape, the hatch. Elsewhere a slab is between.)
	# (The lights only from right in the openings: a light upstairs reaches down a stairwell, not along a corridor.)
	var open := f >= 0 and _sees_between(p, f)
	var lights := f >= 0 and (_stairwell(p) >= 0 or p.x >= 55.4 or (f >= 3 and p.x > 33.5 and p.x < 38.5 and p.z > 530.5))
	# (0.52: the field behind the building is drawn only from where it can be seen: behind the building, from its
	# north rooms and their windows, from the fire escape, from the east and west ends.)
	var field: bool = f < 0 or p.z > 524.0 or p.x > 54.0 or p.x < 2.0
	if roots.size() > 12 and roots[12].visible != field: roots[12].visible = field
	# (0.52: behind the building, the second floor shows through 208's blown-out wall.)
	var back := f < 0 and p.z > 533.0 and p.y < 2 * H
	var key := f * 4 + (2 if open else 0) + (1 if lights else 0) if f >= 0 else (-2 if back else -1)
	if key == _view_key: return
	_view_key = key
	shown = f
	for k in FLOORS:
		roots[k].visible = (k == f or (open and absi(k - f) == 1)) if f >= 0 else (k == 0 or (back and k == 1))
		roots[lit(k)].visible = (k == f or (lights and absi(k - f) == 1)) if f >= 0 else (k == 0 or k == FLOORS - 1 or (back and k == 1))

## 0.51: whether the floors above and below can be seen from `p` (street-local) on floor `f`: in or near a stairwell's
## opening, by the grand stair and its gallery, on the fire escape or at its doors, at the hatch.
func _sees_between(p: Vector3, f: int) -> bool:
	if _stairwell(p) >= 0 or p.x >= 53.5: return true
	if p.z > 521.0 and (p.x < 9.5 or p.x > 46.5): return true
	if f <= 1 and p.x > 21.0 and p.x < 35.0 and p.z > 519.0: return true
	return f >= 3 and p.x > 32.0 and p.x < 40.0 and p.z > 525.0

## 0.51: whether floor `k` is being drawn (mission.gd hides the figures on the floors that are not).
func draws_floor(k: int) -> bool:
	return k >= 0 and k < FLOORS and roots[k].visible

var _view_key := -9

## Sounds of the building at the one who is listening: a bang on the floor above, a scream far off down a corridor.
func _ambience(delta: float, viewer: Vector3) -> void:
	var p := viewer - s.position
	if p.z < 498.0: return
	_one_shot_wait -= delta
	if _one_shot_wait > 0.0: return
	_one_shot_wait = rng.randf_range(7.0, 16.0)
	var a := AudioStreamPlayer3D.new()
	a.stream = load(["res://assets/audio/siege/bang_a.ogg", "res://assets/audio/siege/bang_c.ogg", "res://assets/audio/siege/groan_b.ogg",
		"res://assets/audio/zombies/scream_2.ogg", "res://assets/audio/siege/rattle.ogg", "res://assets/audio/siege/groan_c.ogg"][rng.randi() % 6])
	a.unit_size = 9.0
	a.max_distance = 60.0
	a.volume_db = -10.0
	var f := clampi(roundi(p.y / H), 0, FLOORS - 1)
	var up: int = 1 if f < FLOORS - 1 and rng.randf() < .6 else -1
	if f == 0 and p.z < 514.0: up = 1
	a.position = Vector3(rng.randf_range(3, 53), clampi(f + up, 0, FLOORS - 1) * H + 1.5, CZ)
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

# ---------------------------------------------------------------- where things are (world <-> the school)

func local(world: Vector3) -> Vector3: return world - s.position
func world(at: Vector3) -> Vector3: return at + s.position

## The floor a point is on (world), or -1 outside the building.
func floor_of(world_at: Vector3) -> int:
	var p := world_at - s.position
	if p.x < 0 or p.x > 56 or p.z < 514 or p.z > 534: return -1
	return clampi(roundi(p.y / H), 0, FLOORS - 1)

func in_grounds(world_at: Vector3) -> bool:
	var p := world_at - s.position
	return p.x > -6.5 and p.x < 62.5 and p.z > 500.3 and p.z < FIELD_END + .5

func _stairwell(p: Vector3) -> int:
	if p.z < ZN - .3 or p.z > 533.8: return -1
	if p.x > .2 and p.x < 5.95: return STAIR_W
	if p.x > 50.05 and p.x < 55.8: return STAIR_E
	if p.x > 24.0 and p.x < 32.0 and p.y < H + .4: return STAIR_G
	return -1

## The stair from floor `k` to `k+1` as points to walk through (street-local): the corridor at its opening, the
## foot of the first flight, the turn (both sides), the top of the second flight, the corridor above.
func chain(st: int, k: int) -> Array[Vector3]:
	var y0 := k * H
	var y1 := (k + 1) * H
	if st == STAIR_G:
		var g: Array[Vector3] = [Vector3(28, y0, CZ), Vector3(28, y0, 525.7), Vector3(28, y1, 532.7), Vector3(25.15, y1, 532.7), Vector3(25.15, y1, 525.6), Vector3(25.15, y1, CZ)]
		return g
	var a: float = 1.65 if st == STAIR_W else 54.35
	var b: float = 4.55 if st == STAIR_W else 51.45
	var door: float = 3.1 if st == STAIR_W else 52.9
	var out: Array[Vector3] = [Vector3(door, y0, CZ), Vector3(a, y0, 525.9), Vector3(a, y0 + 1.8, 530.4), Vector3(b, y0 + 1.8, 530.4), Vector3(b, y1, 525.9), Vector3(door, y1, CZ)]
	return out

## 0.51: the way from floor `k` up to `k+1` as points (street-local): an open stair's `chain`, or the fire escape
## (out the east end's fire door, up two flights, in at the third floor), or the maintenance room's ladder (its foot,
## its top beside the hatch: `carry` takes figures up it) and the duct along the back of 510 and 509.
func route(k: int) -> Array[Vector3]:
	return _route_c(k).duplicate()

## 0.56: the routes are the same points every time (until the blast changes the way down from the second floor): built
## once and kept, with a box round each so a point nowhere near a stair is not measured against it. (steer runs for
## every infected on every tick; building and measuring every route each time was most of its cost.) Read-only.
var _routes := {}
var _route_boxes := {}
func _route_key(k: int) -> int:
	return k * 2 + (1 if (blasted and k == 0) or (mech_open and k == ROUTE_VENT) else 0)

func _route_c(k: int) -> Array[Vector3]:
	var key := _route_key(k)
	if not _routes.has(key):
		var c := _route_build(k)
		_routes[key] = c
		var box := AABB(c[0], Vector3.ZERO)
		for p in c: box = box.expand(p)
		_route_boxes[key] = box.grow(1.6)
	return _routes[key]

func _route_box(k: int) -> AABB:
	_route_c(k)
	return _route_boxes[_route_key(k)]

func _route_build(k: int) -> Array[Vector3]:
	var y0 := k * H
	var y1 := (k + 1) * H
	if k == ROUTE_FIRE:
		var f: Array[Vector3] = [Vector3(52.0, y0, CZ), Vector3(55.1, y0, 523.5), Vector3(56.8, y0, 523.5), Vector3(57.95, y0, 525.1),
			Vector3(57.95, y0 + 1.8, 530.4), Vector3(56.65, y0 + 1.8, 530.4), Vector3(56.65, y1, 525.1), Vector3(56.8, y1, 523.5),
			Vector3(55.1, y1, 523.5), Vector3(52.0, y1, CZ)]
		return f
	if k == ROUTE_VENT and mech_open:
		# 0.63: the mechanical room's door forced: up the ladder, out of the room by its door into the corridor.
		var md: Array[Vector3] = [Vector3(38.8, y0, CZ), Vector3(38.8, y0, 526.4), Vector3(36.4, y0, 531.2), Vector3(LADDER.x, y0, LADDER.z),
			Vector3(LADDER.x, y1, HATCH[2] - .75), Vector3(36.0, y1, 528.2), Vector3(mech_door_x, y1, 526.3), Vector3(mech_door_x, y1, CZ)]
		return md
	if k == ROUTE_VENT:
		var v: Array[Vector3] = [Vector3(38.8, y0, CZ), Vector3(38.8, y0, 526.4), Vector3(36.4, y0, 531.2), Vector3(LADDER.x, y0, LADDER.z),
			Vector3(LADDER.x, y1, HATCH[2] - .75), Vector3(34.7, y1, 532.2), Vector3(33.6, y1, 532.95), Vector3(18.6, y1, 532.95), Vector3(17.6, y1, 531.3),
			Vector3(22.8, y1, 526.4), Vector3(22.8, y1, CZ)]
		return v
	if k == ROUTE_ESC:
		# 0.52: the whole fire escape, the second floor's door to the fifth's (once the fifth's chain is off).
		var e: Array[Vector3] = [Vector3(52.0, H, CZ), Vector3(55.1, H, 523.5), Vector3(56.8, H, 523.5)]
		for f in range(1, FLOORS - 1):
			var y := f * H
			e.append_array([Vector3(57.95, y, 525.1), Vector3(57.95, y + 1.8, 530.4), Vector3(56.65, y + 1.8, 530.4), Vector3(56.65, y + H, 525.1)])
		e.append_array([Vector3(56.8, 4 * H, 523.5), Vector3(55.1, 4 * H, 523.5), Vector3(52.0, 4 * H, CZ)])
		return e
	if k == 0 and blasted:
		# 0.52: after the blast the grand stair is buried: the way between the ground and the second floor is out
		# through 208's wall, onto the lean-to's roof and (0.63) down the rubble ramp off its eave into the field.
		var j: Array[Vector3] = [Vector3(11.0, 0, 548.0), Vector3(11.0, 0, 546.0), Vector3(11.0, 1.25, 542.5), Vector3(11.0, LEAN_EAVE + .06, 539.2),
			Vector3(11.0, LEAN_TOP, 535.4), Vector3(11.0, H, 533.0), Vector3(12.6, H, 529.5), Vector3(14.8, H, 526.2), Vector3(14.8, H, CZ)]
		return j
	return chain(UP[k], k)

## 0.51: a figure (an infected on the host, a squad bot) at the maintenance ladder whose way goes up or down it: moved
## by hand (rung by rung, no physics) until it is off at the other end. True while it is on the ladder.
func carry(body: CharacterBody3D, aim: Vector3, delta: float) -> bool:
	if ladders.is_empty(): return false
	var l: Array = ladders[0]
	var foot: Vector3 = l[0]
	var top: Vector3 = l[1]
	var off: Vector3 = l[2]
	var p := local(body.global_position)
	var a := local(aim)
	var st: int = int(body.get_meta("ladder", 0))
	var to_line := Vector2(p.x - foot.x, p.z - foot.z).length()
	if st == 0:
		if absf(p.y - foot.y) < .5 and to_line < 1.0 and a.y > p.y + 1.5: st = 1
		elif absf(p.y - top.y) < .5 and to_line < 1.9 and a.y < p.y - 1.5: st = -1
		else: return false
	var np := p
	match st:
		1:
			np.x = move_toward(p.x, foot.x, 2.0 * delta)
			np.z = move_toward(p.z, foot.z, 2.0 * delta)
			np.y += 1.5 * delta
			if np.y >= top.y:
				np.y = top.y + .02
				st = 2
		2:
			np.x = move_toward(p.x, off.x, 1.3 * delta)
			np.z = move_toward(p.z, off.z, 1.3 * delta)
			if Vector2(np.x - off.x, np.z - off.z).length() < .05: st = 0
		-1:
			if to_line > .06:
				np.x = move_toward(p.x, foot.x, 1.3 * delta)
				np.z = move_toward(p.z, foot.z, 1.3 * delta)
			else:
				np.y -= 1.6 * delta
				if np.y <= foot.y + .02:
					np.y = foot.y + .02
					st = 0
	body.set_meta("ladder", st)
	body.global_position = world(np)
	body.velocity = Vector3.ZERO
	return true

## 0.51: in (or at the mouth of) the duct on the fifth floor (world).
func in_duct(at: Vector3) -> bool:
	var p := local(at)
	return p.y > 4 * H - .5 and p.y < 4 * H + .7 and p.x > DUCT[0] - 1.1 and p.x < DUCT[1] + 1.1 and p.z > DUCT[2] - .45 and p.z < DUCT[3] + .1

## 0.51: an infected in the duct goes on hands and knees (a short capsule, slow); out of it, it stands again.
func squeeze(fig: CharacterBody3D) -> bool:
	var inside := in_duct(fig.global_position)
	if not fig.has_meta("capsule"):
		for c in fig.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape is CapsuleShape3D:
				fig.set_meta("capsule", c)
				fig.set_meta("pace", fig.get("speed"))
				break
	var shape: CollisionShape3D = fig.get_meta("capsule", null)
	if shape == null: return inside
	var cap := shape.shape as CapsuleShape3D
	if inside and cap.height > 1.0:
		cap.height = .9
		shape.position.y = .45
		fig.set("speed", float(fig.get_meta("pace")) * .45)
	elif not inside and cap.height < 1.0:
		cap.height = 1.52
		shape.position.y = .76
		fig.set("speed", float(fig.get_meta("pace")))
	return inside

## Where something at `from` should head to reach `to` (world): `to` itself on the same floor, otherwise the next
## point on the way up or down the open stair. Used for the infected (mission.gd) and the squad AI (bots.gd).
## Both ends are looked for on the open stairs' chains (`on_chain`): on the same chain, along it to the target's
## segment; else along the chain it is on to the floor the target is on, or from the floor to the open stair.
func steer(from_w: Vector3, to_w: Vector3) -> Vector3:
	var f := from_w - s.position
	var t := to_w - s.position
	if not _near(f) and not _near(t): return to_w
	if escape_open:
		var by_esc := _steer_esc(f, t, to_w)
		if by_esc.is_finite(): return by_esc
	var zc := on_chain(f)
	var tc := on_chain(t)
	# 0.52: the mechanical room is sealed (its door welded): whatever is in it, off the way, and wants anywhere else
	# on the fifth floor goes back to the ladder's top and by the duct (it used to walk at the welded door).
	if not mech_open and zc.x < 0 and _in_mech(f) and not _in_mech(t) and absf(t.y - 4 * H) < 1.0 and absf(f.y - 4 * H) < .6:
		return _along(f, _route_c(ROUTE_VENT), 4, to_w)
	if zc.x >= 0 and zc.x == tc.x:
		if zc.y == tc.y: return to_w
		var same := route(zc.x)
		if tc.y > zc.y: return _along(f, same, zc.y + 1, to_w, tc.y)
		same.reverse()
		return _along(f, same, same.size() - 1 - zc.y, to_w, same.size() - 2 - tc.y)
	var ft := clampi(roundi(t.y / H), 0, FLOORS - 1)
	if tc.x >= 0: ft = tc.x if tc.y <= 1 else tc.x + 1
	# (0.52: out through 208 everything from the breach on counts as below: the roof is lower than the floor.)
	if tc.x == 0 and blasted: ft = 0 if tc.y <= 3 else 1
	if zc.x >= 0:
		var on := route(zc.x)
		if ft > zc.x: return _along(f, on, zc.y + 1, to_w)
		on.reverse()
		return _along(f, on, on.size() - 1 - zc.y, to_w)
	var ff := clampi(roundi(f.y / H), 0, FLOORS - 1)
	if ff == ft: return to_w
	if ft > ff: return _along(f, _route_c(ff), 0, to_w)
	var down := route(ff - 1)
	down.reverse()
	return _along(f, down, 0, to_w)

## 0.52: the fire escape from the fifth floor down (`ROUTE_ESC`), when the way to go is along it: a target on it, or
## between the fifth floor and the second (or the field below). INF when it is not the way (then `steer` goes on as
## before: the open stairs, the fire escape's lower part, the ladder and the duct, 208 after the blast).
func _steer_esc(f: Vector3, t: Vector3, to_w: Vector3) -> Vector3:
	var e := _route_c(ROUTE_ESC)
	var ec := _segment(f, e)
	var et := _segment(t, e)
	var ff := clampi(roundi(f.y / H), 0, FLOORS - 1)
	var ft := clampi(roundi(t.y / H), 0, FLOORS - 1)
	var inside := f.x > .2 and f.x < 55.8 and f.z > 514.2 and f.z < 533.8
	if et >= 0:
		if ec >= 0:
			if ec == et: return to_w
			if et > ec: return _along(f, e, ec + 1, to_w, et)
			var back := route(ROUTE_ESC)
			back.reverse()
			return _along(f, back, back.size() - 1 - ec, to_w, back.size() - 2 - et)
		if inside and ff == FLOORS - 1:
			var down := route(ROUTE_ESC)
			down.reverse()
			return _along(f, down, 0, to_w, down.size() - 2 - et)
		if inside and ff == 1: return _along(f, e, 0, to_w, et)
		return Vector3.INF
	if ec >= 0:
		if ft >= FLOORS - 1: return _along(f, e, ec + 1, to_w)
		if ft <= 1:
			var back := route(ROUTE_ESC)
			back.reverse()
			return _along(f, back, back.size() - 1 - ec, to_w)
		return Vector3.INF
	if inside and ff == FLOORS - 1 and ft <= 1:
		var down := route(ROUTE_ESC)
		down.reverse()
		return _along(f, down, 0, to_w)
	if inside and ff == 1 and ft >= FLOORS - 1: return _along(f, e, 0, to_w)
	return Vector3.INF

## 0.63: can someone at `world_at` force the mechanical room's door (just inside it, or just outside in the corridor)?
func at_mech_door(world_at: Vector3) -> bool:
	if _mech_leaf == null or mech_open: return false
	var p := world_at - s.position
	return absf(p.y - 4 * H) < 1.0 and absf(p.x - mech_door_x) < 1.1 and p.z > 523.2 and p.z < 527.0

## 0.52: inside the fifth floor's mechanical room (street-local).
func _in_mech(p: Vector3) -> bool:
	if p.x < DUCT[1] + .2 and p.z > DUCT[2] - .1: return false
	return p.x > 32.1 and p.x < 39.9 and p.z > 525.1 and p.z < 533.7 and absf(p.y - 4 * H) < 1.2

## The segment of `c` a point (street-local) is on, or -1.
func _segment(p: Vector3, c: Array[Vector3]) -> int:
	var best := -1
	var bd := 1.0
	for i in c.size() - 1:
		var d := _seg_dist(p, c[i], c[i + 1])
		if d < bd:
			bd = d
			best = i
	return best

## Which open stair chain a point (street-local) is on: (the pair, the segment), or (-1, -1).
func on_chain(p: Vector3) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 1.5 if _stairwell(p) >= 0 else 1.0
	for k in UP.size():
		if not _route_box(k).has_point(p): continue
		var c := _route_c(k)
		for i in c.size() - 1:
			var d := _seg_dist(p, c[i], c[i + 1])
			if d < bd:
				bd = d
				best = Vector2i(k, i)
	return best

## The chain's next point from `idx` on that is not yet underfoot (cutting a corner at a turn runs into the core);
## past `limit` (the target's own segment), the target itself.
func _along(f: Vector3, c: Array[Vector3], idx: int, to_w: Vector3, limit := 99) -> Vector3:
	while idx < c.size():
		# (The last point is out in the corridor: reached from further off, or it is walked back and forth over.)
		var reach := 1.3 if idx == c.size() - 1 else .7
		if Vector2(c[idx].x - f.x, c[idx].z - f.z).length() >= reach or absf(c[idx].y - f.y) >= .6: break
		idx += 1
	if idx >= c.size() or idx > limit: return to_w
	return c[idx] + s.position

func _near(p: Vector3) -> bool:
	return p.x > -8 and p.x < 64 and p.z > 499 and p.z < FIELD_END + 2.0

static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), .0001), 0.0, 1.0)
	var q := a + ab * t
	return Vector2(p.x - q.x, p.z - q.z).length() + absf(p.y - q.y) * 1.5

## Spots for a rush on arrival at floor `k` (street-local): the far end of the corridor from the stair they came up.
func rush_points(k: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var y := k * H
	# (Where the floor is reached from: the grand stair's gallery, the fire exit at the east end, the west stair, the
	# duct's end in 509.)
	var far_x: float = [6.0 if rng.randf() < .5 else 50.0, 50.0, 6.0, 13.0, 46.0][k]
	if k == 1: far_x = 6.0 if rng.randf() < .5 else 36.0
	for i in 10: out.append(Vector3(far_x + rng.randf_range(-3.5, 3.5), y, CZ + rng.randf_range(-1.0, 1.0)))
	return out
