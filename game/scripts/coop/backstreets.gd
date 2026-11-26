extends Node3D
## 0.44: the backstreets, from the mart's service gate to the back gate of the Prof. Ivan Lawrence College (0.50), about 500 m
## on foot (the main road is jammed and burning; Jonna sends the team this way).
##
## Built from the owner's reference photos (work/Reference/Streets Stage): narrow lanes between three- to
## six-storey blocks, roll-up shutters, air-conditioners and drain pipes, wires strung everywhere, wet asphalt
## with manholes and puddles, sodium lamps on wall arms against cold teal tubes. Six stretches, each after one
## photo, in the order they are walked:
##   0 Service lane   brick backs of the shops, fire escapes, dumpsters, sodium wall lamps (the New York alley)
##   1 Tile street    tiled walls, painted edge lines, pole lamps, a manhole every few steps (the Japanese street)
##   2 Cinema arcade  a covered market under a truss roof of plastic sheets, tubes hanging on chains, shutters,
##                    bicycles, an old cinema's marquee, all in teal (the arcade photo)
##   3 Parol lane     tight, awnings, a teal shop sign, Christmas lights and a parol star someone hung in
##                    November as Davao does, graffiti at the dogleg (the Macau lane)
##   4 Pole street    wider, low houses with balconies, a pole carrying a nest of wires, a tower block behind
##                    with lit windows, green-teal light (the Tokyo corner)
##   5 Brick alley    brick and board siding, a row of poles with lamps going away, bins (the winter alley; wet,
##                    not snowy: this is Davao)
## Where a side street runs out to the main road it is blocked (cars, a jeepney, sheet fences) and the road
## shows only as fire-glow, smoke and noise past the barrier.
##
## The facades are made from the outline of the walkable lanes (CORRIDORS on a 1 m grid), so every turn closes
## itself. Each stretch has its own meshes and body, culled by distance (the store never draws all 500 m).
## Street-local coordinates (Street.ORIGIN added), floor at y 0. Everything random comes from the street's seed.
const CORRIDORS := [
	# [x0, x1, z0, z1, stretch]
	[-5, 1, 80, 142, 0], [-11, -5, 107, 112, 0],
	[-5, 52, 142, 149, 1], [14, 19, 149, 155, 1],
	[40, 46, 149, 232, 2], [46, 54, 188, 193, 2],
	[41, 46, 232, 270, 3], [26, 46, 270, 275, 3], [26, 31, 275, 310, 3],
	[23, 32, 310, 405, 4], [32, 41, 350, 356, 4],
	[25, 31, 405, 500, 5], [18, 25, 452, 457, 5],
]
const NAMES := ["Service lane", "Tile street", "Cinema arcade", "Parol lane", "Pole street", "Brick alley"]
## The far ends of the side streets toward the main road: [axis of the line ("x" or "z"), its value, from, to].
## They get a barrier, not a shopfront. SKIP: runs left bare (the school's wall closes the last lane).
const MOUTH_ENDS := [["x", -11, 107, 112], ["z", 155, 14, 19], ["x", 54, 188, 193], ["x", 41, 350, 356], ["x", 18, 452, 457], ["x", 52, 142, 149]]
const SKIP := [["z", 500, 25, 31]]
## Where the team arrives: in front of the school's back gate.
const SCHOOL_GATE := Vector3(28, 0, 499.6)
## Where the infected wait along the way (mission.gd wakes them as it does on Store Road).
const SPOTS := [Vector3(-2, 0, 96), Vector3(-1, 0, 128), Vector3(10, 0, 145.5), Vector3(30, 0, 146), Vector3(43, 0, 165),
	Vector3(42, 0, 190), Vector3(44, 0, 214), Vector3(43, 0, 250), Vector3(35, 0, 272.5), Vector3(28.5, 0, 296),
	Vector3(27, 0, 330), Vector3(29, 0, 362), Vector3(26, 0, 390), Vector3(28, 0, 425), Vector3(27, 0, 462), Vector3(29, 0, 482)]
## The dead along the way (as Street.STORE_DEAD): a vendor caught at her shutter, a man in the arcade, a rider.
const DEAD := [
	[Vector3(-3.9, 0, 121.5), 13, 1.2, "death_crumple", .9, Vector3.ZERO],
	[Vector3(42.4, 0, 205.0), 3, -2.2, "death_fwd", .95, Vector3(0, 0, 80)],
	[Vector3(29.7, 0, 371.0), 44, .6, "death_back", .95, Vector3.ZERO]]

## Per stretch: wall materials, storeys, how much of the ground floor is shutters, light colour.
const STYLE := [
	{"walls": ["red_brick", "brick_wall_02", "rough_plaster_brick_04|#b7a493", "concrete_wall_008|#8d8a80"], "floors": [3, 6], "lamp": Color(1.0, .64, .3), "glass": "#ffcf8a"},
	{"walls": ["beige_wall_001", "white_plaster_02|#d8cfbc", "concrete_wall_008|#b8b2a2", "painted_plaster_wall|#cfc6ae"], "floors": [2, 4], "lamp": Color(1.0, .66, .32), "glass": "#ffd9a0"},
	{"walls": ["worn_cracked_plaster|#9fb8b0", "painted_plaster_wall|#a9c4bb", "concrete_wall_008|#93a8a2", "peeling_painted_wall|#8fb0a8"], "floors": [2, 3], "lamp": Color(.55, 1.0, .9), "glass": "#9ff2e0"},
	{"walls": ["damaged_plaster|#c9a77a", "worn_mossy_plasterwall|#a8946e", "rough_plaster_broken|#b99b72", "peeling_painted_wall|#c4a07a"], "floors": [3, 5], "lamp": Color(1.0, .6, .26), "glass": "#ffc070"},
	{"walls": ["white_plaster_02|#c9d8cc", "beige_wall_001|#bfd2c4", "concrete_wall_008|#a9bcb0", "painted_plaster_wall|#d2dccf"], "floors": [2, 3], "lamp": Color(.62, 1.0, .82), "glass": "#c8ffe8"},
	{"walls": ["red_brick|#8a7f84", "brick_wall_02|#7f8590", "weathered_plank_siding|#7d8a96", "concrete_block_wall|#8f949c"], "floors": [3, 4], "lamp": Color(.75, .95, 1.0), "glass": "#cfe8ff"},
]
const SIGNS := [
	["PAWNSHOP", "BAKERY • PANADERIA", "LAUNDRY SHOP", "REPAIR • ELECTRONICS"],
	["BOTIKA NG BAYAN", "SARI-SARI", "KARINDERYA", "ROLLING STORE", "BIGASAN"],
	["AVENIDA ARCADE", "TAILORING", "E-LOAD DITO", "CELLPHONE REPAIR", "BARBERSHOP", "SALON"],
	["LECHON MANOK", "INTERNET CAFÉ", "SPA • MASSAGE", "PRINTING"],
	["WATER REFILLING", "SARI-SARI", "DENTAL CLINIC"],
	["HARDWARE", "AUTO PARTS", "WELDING SHOP"],
]

var s: Node3D
var rng := RandomNumberGenerator.new()
var _kits: Array = []
var _roots: Array[Node3D] = []
var _bodies: Array[StaticBody3D] = []
var _mats := {}
var _cells := {}
var _labels: Array = []
## Lights that flicker: [light, base energy, phase] (Street.sync runs them with its own).
var fires: Array = []
## 0.45: where a lamp is dead (some of them spark), and the horror pass (backstreets_horror.gd).
var dead_lamps: Array[Vector3] = []
var horror

func build(street: Node3D) -> void:
	s = street
	rng.seed = int(s.seed_value) * 31 + 7
	name = "Backstreets"
	for i in NAMES.size():
		var root := Node3D.new()
		root.name = NAMES[i]
		var c := _centre(i)
		root.position = c
		add_child(root)
		_roots.append(root)
		var body := StaticBody3D.new()
		body.collision_layer = 2
		root.add_child(body)
		_bodies.append(body)
		_kits.append({})
	for spec: Array in CORRIDORS:
		for x in range(int(spec[0]), int(spec[1])):
			for z in range(int(spec[2]), int(spec[3])):
				_cells[Vector2i(x, z)] = int(spec[4])
	for spec: Array in CORRIDORS: _ground(spec)
	_facades()
	_overhead()
	_props()
	_arcade_roof()
	_parol()
	_tower_blocks()
	_road_glimpses()
	_school_gate()
	_story()
	horror = preload("res://scripts/coop/backstreets_horror.gd").new()
	horror.build(self)
	# (0.65: materials alike but for their colour share one mesh: InteriorColourBatch.)
	var dress := func(mesh: MeshInstance3D, _id: String) -> void:
		mesh.layers = 1 | 8
		mesh.visibility_range_end = 150.0
		mesh.visibility_range_end_margin = 10.0
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for i in _kits.size():
		InteriorColourBatch.commit_kits(_roots[i], _kits[i], _material, dress)
	_kits.clear()

# ---------------------------------------------------------------- helpers

func _centre(stretch: int) -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for spec: Array in CORRIDORS:
		if int(spec[4]) != stretch: continue
		lo = Vector2(minf(lo.x, spec[0]), minf(lo.y, spec[2]))
		hi = Vector2(maxf(hi.x, spec[1]), maxf(hi.y, spec[3]))
	return Vector3((lo.x + hi.x) * .5, 0, (lo.y + hi.y) * .5)

func stretch_at(at: Vector3) -> int:
	var cell := Vector2i(floori(at.x), floori(at.z))
	if _cells.has(cell): return _cells[cell]
	return _nearest_stretch(at)

func _nearest_stretch(at: Vector3) -> int:
	var best := 0
	var d := INF
	for i in _roots.size():
		var c := _roots[i].position
		if c.distance_to(at) < d:
			d = c.distance_to(at)
			best = i
	return best

func _material(id: String) -> StandardMaterial3D:
	if _mats.has(id): return _mats[id]
	var m: StandardMaterial3D
	if id.begins_with("wet:"):
		m = (s.material(id.trim_prefix("wet:")) as StandardMaterial3D).duplicate()
		m.roughness = .3
		m.metallic_specular = .65
		m.albedo_color = m.albedo_color * Color(.82, .82, .86)
	else:
		m = s.material(id)
	_mats[id] = m
	return m

## A box in the merged mesh of the stretch that holds `at` (or `stretch`).
func bx(at: Vector3, size: Vector3, id: String, collide := false, basis := Basis.IDENTITY, stretch := -1) -> void:
	var i := stretch if stretch >= 0 else stretch_at(at)
	if not _kits[i].has(id): _kits[i][id] = InteriorBoxKit.new()
	var local := at - _roots[i].position
	_kits[i][id].box(size, Transform3D(basis, local))
	if collide:
		var c := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = size
		c.shape = b
		c.transform = Transform3D(basis, local)
		_bodies[i].add_child(c)

func cyl(at: Vector3, radius: float, h: float, id: String, basis := Basis.IDENTITY, sides := 10, stretch := -1) -> void:
	var i := stretch if stretch >= 0 else stretch_at(at)
	if not _kits[i].has(id): _kits[i][id] = InteriorBoxKit.new()
	_kits[i][id].cylinder(radius, h, sides, Transform3D(basis, at - _roots[i].position))

func bar(a: Vector3, b: Vector3, thick: float, id: String, stretch := -1) -> void:
	var d := b - a
	if d.length() < .001: return
	var up := Vector3.UP if absf(d.normalized().y) < .98 else Vector3.RIGHT
	bx((a + b) * .5, Vector3(thick, thick, d.length()), id, false, Basis.looking_at(d.normalized(), up), stretch if stretch >= 0 else stretch_at(a))

## A sagging wire between two points.
func wire(a: Vector3, b: Vector3, sag: float, thick := .016, id := "#0e0e0e") -> void:
	var last := a
	var i := stretch_at((a + b) * .5)
	for k in range(1, 7):
		var t := k / 6.0
		var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		bar(last, p, thick, id, i)
		last = p

func lamp(at: Vector3, color: Color, energy: float, reach: float, shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.3
	l.shadow_enabled = shadows
	l.distance_fade_enabled = true
	l.distance_fade_begin = 48.0
	l.distance_fade_length = 14.0
	l.set_meta("outdoor", true)
	add_child(l)
	return l

## A lamp that throws a pool: a spot aimed down (`toward` tilts it into the lane) and a faint omni round it.
func pool(at: Vector3, toward: Vector3, color: Color, energy: float, shadows := false) -> SpotLight3D:
	var sp := SpotLight3D.new()
	sp.position = at
	var down := (Vector3.DOWN + toward * .35).normalized()
	sp.basis = Basis.looking_at(down, Vector3.FORWARD if absf(down.z) < .9 else Vector3.RIGHT)
	sp.light_color = color
	sp.light_energy = energy
	sp.spot_range = at.y + 4.0
	sp.spot_angle = 52.0
	sp.spot_angle_attenuation = 1.6
	sp.spot_attenuation = .7
	sp.shadow_enabled = shadows
	sp.distance_fade_enabled = true
	sp.distance_fade_begin = 48.0
	sp.distance_fade_length = 14.0
	sp.set_meta("outdoor", true)
	add_child(sp)
	lamp(at + toward * .3, color, energy * .22, 9.0)
	return sp

func label(at: Vector3, words: String, height: float, yaw: float, color := Color.WHITE, lit := true) -> Label3D:
	var l := Label3D.new()
	l.text = words
	l.pixel_size = height / 64
	l.font_size = 64
	l.outline_size = 4 if lit else 0
	l.modulate = color
	l.shaded = not lit
	l.double_sided = false
	l.rotation.y = yaw
	l.position = at
	l.visibility_range_end = 60.0
	add_child(l)
	return l

func place(path: String, at: Vector3, yaw_deg := 0.0, scale := 1.0) -> Node3D:
	var n: Node3D = InteriorModelKit.place(self, path, at, yaw_deg, scale, "bottom", Vector3.ZERO)
	if n != null:
		for g in n.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).visibility_range_end = 70.0
	return n

# ---------------------------------------------------------------- ground

func _ground(spec: Array) -> void:
	var x0: float = spec[0]
	var x1: float = spec[1]
	var z0: float = spec[2]
	var z1: float = spec[3]
	var i: int = spec[4]
	var c := Vector3((x0 + x1) * .5, -.18, (z0 + z1) * .5)
	var surface: String = ["wet:asphalt_02", "wet:asphalt_02", "wet:dirty_concrete", "wet:damaged_concrete_floor", "wet:asphalt_02", "wet:asphalt_02"][i]
	bx(c, Vector3(x1 - x0 + .02, .36, z1 - z0 + .02), surface, true, Basis.IDENTITY, i)
	# Patches and cracks, manholes, drain grates, puddles that hold the lamps.
	var along_z := (z1 - z0) >= (x1 - x0)
	var length := maxf(z1 - z0, x1 - x0)
	var n := int(length / 7.0)
	for k in n:
		var t := (k + rng.randf_range(.2, .8)) / maxf(n, 1)
		var at := Vector3(lerpf(x0 + 1.2, x1 - 1.2, rng.randf()) if along_z else lerpf(x0, x1, t), .004, lerpf(z0, z1, t) if along_z else lerpf(z0 + 1.2, z1 - 1.2, rng.randf()))
		match k % 4:
			0:
				cyl(at + Vector3.UP * .008, .34, .014, "rusty_metal_03|#4a443c", Basis.IDENTITY, 18, i)
				cyl(at + Vector3.UP * .016, .3, .004, "#1e1c19", Basis.IDENTITY, 18, i)
			1: bx(at + Vector3.UP * .006, Vector3(rng.randf_range(1.0, 2.6), .012, rng.randf_range(.8, 1.8)), "wet:dirty_concrete", false, Basis(Vector3.UP, rng.randf() * TAU), i)
			_: cyl(at + Vector3.UP * .012, .5, .004, "puddle", Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rng.randf_range(1.2, 3.2), 1, rng.randf_range(.8, 1.8))), 18, i)
	# Painted edge lines on the tile street (the Japanese photo), a gutter elsewhere.
	if i == 1 and not along_z:
		for side in [z0 + .55, z1 - .55]:
			bx(Vector3(c.x, .006, side), Vector3(x1 - x0 - .4, .006, .12), "#d9d6c8", false, Basis.IDENTITY, i)

# ---------------------------------------------------------------- facades from the outline

func _facades() -> void:
	# Every edge between a lane cell and a cell outside: grouped into straight runs with the way out of the lane.
	var runs := {}
	for cell: Vector2i in _cells:
		for way: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _cells.has(cell + way): continue
			# The service alley behind the mart is the street's, not ours.
			if way == Vector2i(0, -1) and cell.y <= 80: continue
			var line := cell.x + (1 if way.x > 0 else 0) if way.x != 0 else cell.y + (1 if way.y > 0 else 0)
			var along := cell.y if way.x != 0 else cell.x
			var key := [way, line]
			if not runs.has(key): runs[key] = []
			runs[key].append(along)
	for key: Array in runs:
		var list: Array = runs[key]
		list.sort()
		var start: int = list[0]
		var prev: int = list[0]
		for k in range(1, list.size() + 1):
			if k < list.size() and int(list[k]) == prev + 1:
				prev = list[k]
				continue
			_run(key[0], int(key[1]), start, prev + 1)
			if k < list.size():
				start = list[k]
				prev = list[k]

## One straight facade line: buildings 4-9 m wide standing outward of it.
func _run(way: Vector2i, line: int, a: int, b: int) -> void:
	var out := Vector3(way.x, 0, way.y)
	var dir := Vector3(0, 0, 1) if way.x != 0 else Vector3(1, 0, 0)
	var origin := Vector3(line, 0, a) if way.x != 0 else Vector3(a, 0, line)
	var length := float(b - a)
	var stretch := stretch_at(origin - out * .5 + dir * .5)
	var style: Dictionary = STYLE[stretch]
	var axis := "x" if way.x != 0 else "z"
	for spec: Array in SKIP:
		if spec[0] == axis and int(spec[1]) == line and int(spec[2]) <= a and int(spec[3]) >= b: return
	var dead_end := false
	for spec: Array in MOUTH_ENDS:
		if spec[0] == axis and int(spec[1]) == line and int(spec[2]) <= a and int(spec[3]) >= b: dead_end = true
	var t := 0.0
	while t < length - .01:
		var w := minf(rng.randf_range(4.0, 9.0), length - t)
		if length - t - w < 3.0: w = length - t
		_building(origin + dir * t, dir, out, w, stretch, style, dead_end)
		t += w

func _building(at: Vector3, dir: Vector3, out: Vector3, w: float, stretch: int, style: Dictionary, dead_end: bool) -> void:
	var floors := rng.randi_range(int(style.floors[0]), int(style.floors[1]))
	var h := floors * 3.1 + rng.randf_range(.2, .8)
	var depth := 7.0
	var walls: Array = style.walls
	var wall: String = walls[rng.randi() % walls.size()]
	var yaw := atan2(-out.x, -out.z)
	var facing := Basis(Vector3.UP, yaw)
	var centre := at + dir * w * .5 + out * depth * .5
	var size := Vector3(w, h, depth) if out.z != 0 else Vector3(depth, h, w)
	bx(centre + Vector3.UP * h * .5, size, wall, true, Basis.IDENTITY, stretch)
	# The face, a few cm proud, takes the details; `p(u, y, o)` is a point on it: u along, y up, o out into the lane.
	var face := at - out * .0
	var p := func(u: float, y: float, o: float) -> Vector3: return face + dir * u + Vector3.UP * y - out * o
	# Parapet and roof furniture.
	bx(p.call(w * .5, h + .12, -depth * .5) , Vector3(w, .24, depth) if out.z != 0 else Vector3(depth, .24, w), "rough_concrete", false, Basis.IDENTITY, stretch)
	if rng.randf() < .35: cyl(p.call(rng.randf_range(1.0, w - 1.0), h + .9, -3.5), .6, 1.5, "#3a4a5a" if rng.randf() < .5 else "#8a8a84", Basis.IDENTITY, 12, stretch)
	if dead_end:
		_barrier(p, w, facing, stretch)
		return
	# Ground floor.
	var bays := maxi(1, int(w / 3.2))
	var bay := w / bays
	for k in bays:
		var u := (k + .5) * bay
		var roll := rng.randf()
		if roll < .55:
			_shutter(p, u, minf(bay - .5, 3.4), facing, stretch, rng.randf() < .1)
		elif roll < .78:
			_door(p, u, facing, stretch)
		else:
			_blank(p, u, bay, facing, stretch)
	# A painted or lit sign over the shop (some of them).
	if rng.randf() < .45 and w > 4.5:
		var words: String = SIGNS[stretch][rng.randi() % SIGNS[stretch].size()]
		var colour: String = ["#7a1717", "#1d3f73", "#245d3a", "#a9411e", "#1c6b72", "#5b2a6b"][rng.randi() % 6]
		var lit := rng.randf() < .18
		bx(p.call(w * .5, 3.15, .14), Vector3(minf(w - .6, 4.5), .55, .08), "glow%s*.9" % colour if lit else colour, false, facing, stretch)
		label(p.call(w * .5, 3.15, .19), words, .24, yaw, Color(1, .96, .88), lit)
	# A vertical light-box sign standing out from the wall (the arcade photo), on some.
	if rng.randf() < (.35 if stretch in [2, 3] else .12):
		var words: String = SIGNS[stretch][rng.randi() % SIGNS[stretch].size()]
		var at_u := rng.randf_range(.6, w - .6)
		var side_basis := Basis(Vector3.UP, yaw + PI * .5)
		var glow: String = ["glow#e8f6ff*1.6", "glow#9ff2e0*1.4", "glow#fff0b0*1.5", "glow#ffb0a0*1.3"][rng.randi() % 4]
		bx(p.call(at_u, 4.6, .75), Vector3(.16, 1.6, .55) if out.z != 0 else Vector3(.55, 1.6, .16), glow, false, Basis.IDENTITY, stretch)
		bar(p.call(at_u, 5.3, 0), p.call(at_u, 5.3, .5), .04, "#2a2b28", stretch)
		label(p.call(at_u, 4.6, .75) + dir * .09, words.replace(" • ", "\n").replace(" ", "\n"), .14, atan2(dir.x, dir.z), Color(.08, .1, .12), true)
	# Upper floors: windows (dark, or lit behind curtains), grilles, air-conditioners, pipes, balconies,
	# fire escapes.
	var cols := maxi(1, int(w / 2.4))
	var colw := w / cols
	var escape := stretch in [0, 5] and w > 5.5 and rng.randf() < .45
	for f in range(1, floors):
		var y := f * 3.1 + 1.5
		for k in cols:
			var u := (k + .5) * colw
			var lit := rng.randf() < .08
			var gl: String = "glow%s*%.2f" % [style.glass, rng.randf_range(.18, .34)] if lit else "glass#0c1012"
			bx(p.call(u, y, .02), Vector3(1.15, 1.3, .04) if out.z != 0 else Vector3(.04, 1.3, 1.15), gl, false, Basis.IDENTITY, stretch)
			# Frames and a cross bar; lit ones have a curtain half drawn across.
			bx(p.call(u, y, .045), Vector3(1.2, .05, .02) if out.z != 0 else Vector3(.02, .05, 1.2), "#2b2a27", false, Basis.IDENTITY, stretch)
			bx(p.call(u, y, .045), Vector3(.05, 1.3, .02) if out.z != 0 else Vector3(.02, 1.3, .05), "#2b2a27", false, Basis.IDENTITY, stretch)
			if lit:
				var cu: float = u + (-.3 if rng.randf() < .5 else .3)
				bx(p.call(cu, y, .035), Vector3(.55, 1.26, .01) if out.z != 0 else Vector3(.01, 1.26, .55), ["#6a4a32", "#3e5a6a", "#7a6a4a", "#5a2a2a"][rng.randi() % 4], false, Basis.IDENTITY, stretch)
			bx(p.call(u, y - .72, .08), Vector3(1.35, .08, .16) if out.z != 0 else Vector3(.16, .08, 1.35), "rough_concrete", false, Basis.IDENTITY, stretch)
			if stretch in [1, 3] and rng.randf() < .5:
				for g in 5: bx(p.call(u - .5 + g * .25, y, .07), Vector3(.025, 1.3, .025), "#2b2a27", false, Basis.IDENTITY, stretch)
			if rng.randf() < .3 and not escape:
				bx(p.call(u + .9 if u + .9 < w else u - .9, y - .9, .28), Vector3(.75, .5, .5) if out.z != 0 else Vector3(.5, .5, .75), "#d9d6cf", false, Basis.IDENTITY, stretch)
				bx(p.call(u + .9 if u + .9 < w else u - .9, y - .9, .54), Vector3(.5, .36, .01) if out.z != 0 else Vector3(.01, .36, .5), "#4a4b48", false, Basis.IDENTITY, stretch)
		if stretch == 4 and f == 1 and rng.randf() < .6:
			# A balcony across the front: slab, rail, a plant or a hung shirt.
			bx(p.call(w * .5, 3.1, .55), Vector3(w - .4, .14, 1.1) if out.z != 0 else Vector3(1.1, .14, w - .4), "rough_concrete", false, Basis.IDENTITY, stretch)
			for r in int((w - .4) / .14):
				bx(p.call(.3 + r * .14, 3.65, 1.05), Vector3(.02, 1.0, .02), "#2c3230", false, Basis.IDENTITY, stretch)
			bar(p.call(.2, 4.15, 1.05), p.call(w - .2, 4.15, 1.05), .04, "#2c3230", stretch)
	if escape: _fire_escape(p, w, floors, stretch)
	# A drain pipe down one edge, the electric meter and the wires into it.
	bx(p.call(.15, h * .5, .1), Vector3(.1, h, .1), "#3c3a35", false, Basis.IDENTITY, stretch)
	if rng.randf() < .5:
		bx(p.call(w - .5, 2.2, .1), Vector3(.3, .4, .16) if out.z != 0 else Vector3(.16, .4, .3), "#5e615a", false, Basis.IDENTITY, stretch)

func _shutter(p: Callable, u: float, width: float, facing: Basis, stretch: int, half: bool) -> void:
	var h := 2.7
	var down := 1.0 if half else 2.62
	bx(p.call(u, 2.7 - down * .5 + .06, .03), Vector3(width, down, .05), ["painted_metal_shutter|#9a9c95", "painted_metal_shutter|#7f8a86", "rusty_metal_sheet", "painted_metal_shutter|#a8a08a"][rng.randi() % 4], false, facing, stretch)
	bx(p.call(u, h + .18, .16), Vector3(width + .2, .34, .32), "rusty_metal_02", false, facing, stretch)
	bx(p.call(u, .05, .25), Vector3(width + .2, .1, .5), "rough_concrete", false, facing, stretch)
	if half:
		bx(p.call(u, .85, -.6), Vector3(width, 1.7, 1.2), "#070707", false, facing, stretch)
		lamp(p.call(u, 1.2, -.4), Color(.8, 1.0, .9), .5, 3.0)

func _door(p: Callable, u: float, facing: Basis, stretch: int) -> void:
	bx(p.call(u, 1.1, .02), Vector3(1.0, 2.2, .06), ["#3d4a52", "#5b3a20", "#2f4a33", "rusty_metal_sheet|#6a5c50"][rng.randi() % 4], false, facing, stretch)
	bx(p.call(u, 2.32, .05), Vector3(1.25, .12, .1), "rough_concrete", false, facing, stretch)
	bx(p.call(u + .32, 1.05, .07), Vector3(.1, .04, .04), "#9a9a92", false, facing, stretch)
	if rng.randf() < .4:
		bx(p.call(u, 2.75, .2), Vector3(.18, .12, .26), "#2a2b28", false, facing, stretch)
		bx(p.call(u, 2.69, .24), Vector3(.14, .02, .18), "glow#fff1c8*2.2", false, facing, stretch)

func _blank(p: Callable, u: float, width: float, facing: Basis, stretch: int) -> void:
	# Pipes, a meter box, an old poster, or nothing.
	if rng.randf() < .5:
		bx(p.call(u - .3, 1.6, .08), Vector3(.08, 3.2, .08), "#5a5f5c", false, facing, stretch)
		bx(p.call(u + .2, 1.6, .08), Vector3(.06, 3.2, .06), "#3a3d3a", false, facing, stretch)
	else:
		bx(p.call(u, 1.5, .015), Vector3(minf(width - .6, .7), .5, .01), ["#6f6650", "#7a7062", "#5f6a72"][rng.randi() % 3], false, facing * Basis(Vector3.FORWARD, rng.randf_range(-.08, .08)), stretch)

## A zig-zag of steel landings and stairs up the front (the New York photo).
func _fire_escape(p: Callable, w: float, floors: int, stretch: int) -> void:
	var u0 := w * .5 - 1.6
	var u1 := w * .5 + 1.6
	for f in range(1, floors):
		var y := f * 3.1
		bx(p.call(w * .5, y, .65), Vector3(3.4, .05, 1.2) if absf((p.call(1, 0, 0) - p.call(0, 0, 0)).x) > .5 else Vector3(1.2, .05, 3.4), "#2a2b29", false, Basis.IDENTITY, stretch)
		bar(p.call(u0, y + 1.0, 1.24), p.call(u1, y + 1.0, 1.24), .03, "#2a2b29", stretch)
		for r in 9: bar(p.call(u0 + r * .4, y, 1.24), p.call(u0 + r * .4, y + 1.0, 1.24), .02, "#2a2b29", stretch)
		if f < floors - 1:
			var a: Vector3 = p.call(u0 + .3 if f % 2 else u1 - .3, y, .5)
			var b: Vector3 = p.call(u1 - .3 if f % 2 else u0 + .3, y + 3.1, .5)
			bar(a, b, .06, "#2a2b29", stretch)
			bar(a + Vector3.UP * .9, b + Vector3.UP * .9, .03, "#2a2b29", stretch)
	# The drop ladder, pulled up.
	bar(p.call(u1 - .2, 3.1, 1.1), p.call(u1 - .2, 1.6, 1.1), .03, "#2a2b29", stretch)
	bar(p.call(u1 - .6, 3.1, 1.1), p.call(u1 - .6, 1.6, 1.1), .03, "#2a2b29", stretch)

## The far end of a side street toward the main road: shut with what came to hand.
func _barrier(p: Callable, w: float, facing: Basis, stretch: int) -> void:
	for k in int(w / .9):
		var u := .45 + k * .9
		bx(p.call(u, 1.3, .25), Vector3(.88, 2.6, .03), ["rusty_corrugated_iron", "corrugated_iron_02"][k % 2], false, facing * Basis(Vector3.FORWARD, rng.randf_range(-.06, .06)), stretch)
	# (0.49: no taller than the sheets: rounds over them went into a wall that was not there.)
	bx(p.call(w * .5, 1.27, .3), Vector3(w, 2.54, .2), "#000000", true, facing, stretch)
	_kits[stretch].erase("#000000")
	for k in 3: bar(p.call(.3 + k * (w - .6) * .5, 0, .6), p.call(.3 + k * (w - .6) * .5, 2.4, .32), .07, "weathered_planks", stretch)

# ---------------------------------------------------------------- wires, poles and lamps

func _overhead() -> void:
	for spec: Array in CORRIDORS:
		var x0: float = spec[0]
		var x1: float = spec[1]
		var z0: float = spec[2]
		var z1: float = spec[3]
		var i: int = spec[4]
		var along_z := (z1 - z0) >= (x1 - x0)
		var length := maxf(z1 - z0, x1 - x0)
		if length < 12.0: continue
		var colour: Color = STYLE[i].lamp
		# Wires across the lane, sagging, more of them than anyone counted.
		var t := 2.0
		while t < length - 2.0:
			var a := Vector3(x0 + .1, rng.randf_range(4.6, 7.5), z0 + t) if along_z else Vector3(x0 + t, rng.randf_range(4.6, 7.5), z0 + .1)
			var b := Vector3(x1 - .1, rng.randf_range(4.6, 7.5), z0 + t + rng.randf_range(-3, 3)) if along_z else Vector3(x0 + t + rng.randf_range(-3, 3), rng.randf_range(4.6, 7.5), z1 - .1)
			if i != 2: wire(a, b, rng.randf_range(.3, .9))
			t += rng.randf_range(2.5, 6.0)
		# Lamps: on wall arms (sodium) or poles (the pole street, the brick alley), the arcade's hang from its roof.
		var step: float = {0: 13.0, 1: 15.0, 2: 9.0, 3: 12.0, 4: 18.0, 5: 14.0}[i]
		var k := 0
		t = step * .5
		while t < length:
			var left := k % 2 == 0
			var wall_x := x0 + .05 if left else x1 - .05
			var wall_z := z0 + .05 if left else z1 - .05
			var at := Vector3(wall_x, 4.6, z0 + t) if along_z else Vector3(x0 + t, 4.6, wall_z)
			var inward := Vector3(1 if left else -1, 0, 0) if along_z else Vector3(0, 0, 1 if left else -1)
			if i in [4, 5]:
				_pole(at + inward * .5, inward, colour, i, k)
			elif i == 2:
				pass
			else:
				bar(at, at + inward * 1.1 + Vector3.UP * .2, .05, "#2c2d2a", i)
				bx(at + inward * 1.15 + Vector3.UP * .14, Vector3(.42, .14, .26) if along_z else Vector3(.26, .14, .42), "#2a2b28", false, Basis.IDENTITY, i)
				var dead := k % 3 == 1 or rng.randf() < .08
				bx(at + inward * 1.15 + Vector3.UP * .06, Vector3(.34, .02, .2) if along_z else Vector3(.2, .02, .34), "#3a3a36" if dead else "glow#%s*3.4" % colour.to_html(false), false, Basis.IDENTITY, i)
				if not dead:
					var l := pool(at + inward * 1.15 + Vector3.DOWN * .1, inward, colour, 6.0, k % 3 == 0)
					if rng.randf() < .3: fires.append([l, 6.0, rng.randf_range(2.0, 6.0)])
				else: dead_lamps.append(at + inward * 1.15)
			t += step
			k += 1

## A concrete or wooden utility pole with a lamp arm, a transformer now and then and its nest of wires.
func _pole(at: Vector3, inward: Vector3, colour: Color, stretch: int, k: int) -> void:
	var base := Vector3(at.x, 0, at.z)
	var wood := stretch == 5
	cyl(base + Vector3.UP * 4.6, .16 if not wood else .13, 9.2, "concrete_wall_008|#9a9890" if not wood else "dark_wooden_planks|#5b4b3b", Basis.IDENTITY, 10, stretch)
	var across := Vector3(inward.z, 0, inward.x)
	bx(base + Vector3.UP * 8.4, Vector3(1.8, .1, .1) if absf(across.x) > .5 else Vector3(.1, .1, 1.8), "dark_wooden_planks|#4b3b2b", false, Basis.IDENTITY, stretch)
	bar(base + Vector3.UP * 6.2, base + Vector3.UP * 6.5 + inward * 1.6, .05, "#3a3b37", stretch)
	bx(base + Vector3.UP * 6.45 + inward * 1.7, Vector3(.3, .12, .5) if absf(inward.z) > .5 else Vector3(.5, .12, .3), "#2a2b28", false, Basis.IDENTITY, stretch)
	var dead := k % 3 == 1
	bx(base + Vector3.UP * 6.38 + inward * 1.7, Vector3(.22, .02, .4) if absf(inward.z) > .5 else Vector3(.4, .02, .22), "#3a3a36" if dead else "glow#%s*3.6" % colour.to_html(false), false, Basis.IDENTITY, stretch)
	if dead: dead_lamps.append(base + Vector3.UP * 6.3 + inward * 1.7)
	else:
		var l := pool(base + Vector3.UP * 6.25 + inward * 1.7, inward, colour, 7.5, k % 2 == 0)
		if k % 4 == 2: fires.append([l, 7.5, rng.randf_range(2.0, 5.0)])
	if k % 2 == 1: cyl(base + Vector3.UP * 7.4 + inward * .35, .25, .7, "#6e726d", Basis.IDENTITY, 10, stretch)
	for w in 4:
		var off := across * (-.8 + w * .53) + Vector3.UP * 8.45
		var dir := Vector3(0, 0, 1) if absf(inward.x) > .5 else Vector3(1, 0, 0)
		wire(base + off, base + off + dir * 18.0 + Vector3.UP * rng.randf_range(-.3, .3), rng.randf_range(.5, 1.0))
		wire(base + off, base + off - inward * 6.0 + Vector3.UP * rng.randf_range(-2.0, -1.0), .3)

# ---------------------------------------------------------------- the arcade

func _arcade_roof() -> void:
	# The cinema arcade (stretch 2): a truss roof at 7 m with corrugated plastic panels, tubes hanging on chains,
	# the old cinema's marquee half way along.
	var x0 := 40.0
	var x1 := 46.0
	var z := 151.0
	while z < 230.0:
		bar(Vector3(x0, 6.2, z), Vector3((x0 + x1) * .5, 7.4, z), .1, "#26302e", 2)
		bar(Vector3((x0 + x1) * .5, 7.4, z), Vector3(x1, 6.2, z), .1, "#26302e", 2)
		bar(Vector3(x0, 6.2, z), Vector3(x1, 6.2, z), .07, "#26302e", 2)
		for k in 3:
			var u := .25 + k * .25
			var top := Vector3(lerpf(x0, x1, u), 6.2 + 1.2 * (1.0 - absf(u - .5) * 2.0), z)
			bar(Vector3(lerpf(x0, x1, u), 6.2, z), top, .04, "#26302e", 2)
		z += 4.0
	for side in [-1.0, 1.0]:
		var basis := Basis(Vector3.BACK, side * atan2(1.2, 3.0))
		var cx: float = (x0 + x1) * .5 + side * 1.5
		var panels := 0.0
		while panels < 79.0:
			var sheet := rng.randf() > .08
			if sheet:
				bx(Vector3(cx, 6.8, 151.0 + panels + 2.0), Vector3(3.25, .03, 4.0), "glass#8fd8c855" if rng.randf() > .2 else "glass#c8e8d855", false, basis, 2)
			panels += 4.0
	for z2 in range(154, 230, 6):
		var at := Vector3(43.0 + rng.randf_range(-.4, .4), 4.4, float(z2))
		bar(at + Vector3.UP * .1, at + Vector3.UP * 1.9, .012, "#1a1a1a", 2)
		bx(at, Vector3(.16, .08, 1.3), "#d8d9d2", false, Basis.IDENTITY, 2)
		var on := rng.randf() < .5
		bx(at + Vector3.DOWN * .045, Vector3(.1, .02, 1.2), "glow#bff8ea*2.6" if on else "#4b4c48", false, Basis.IDENTITY, 2)
		if on:
			var l := pool(at + Vector3.DOWN * .1, Vector3.ZERO, Color(.58, 1.0, .88), 4.2, z2 % 24 == 4)
			if rng.randf() < .45: fires.append([l, 4.2, rng.randf_range(3.0, 7.0)])
		else: dead_lamps.append(at)
	# The marquee of the Avenida (closed long before this), its letters half gone; its lobby behind a shutter.
	var m := Vector3(40.0, 4.2, 196.0)
	bx(m + Vector3(.6, 0, 0), Vector3(1.2, .9, 7.0), "#1c2a2a", false, Basis.IDENTITY, 2)
	bx(m + Vector3(1.22, 0, 0), Vector3(.02, .7, 6.6), "glow#e8fff6*.8", false, Basis.IDENTITY, 2)
	label(m + Vector3(1.24, .12, 0), "AVENIDA  CINEMA", .32, PI * .5, Color(.15, .2, .2), false)
	label(m + Vector3(1.24, -.2, 0), "NOW SHOWING:  — — —", .14, PI * .5, Color(.2, .25, .25), false)
	for k in 14: bx(m + Vector3(1.0, -.5, -3.3 + k * .5), Vector3(.05, .05, .05), "glow#ffe9a0*3.0" if rng.randf() < .4 else "#3a3a33", false, Basis.IDENTITY, 2)
	# Bicycles left against the shutters (the arcade photo).
	for spec in [[45.4, 170.0, PI * .5], [45.3, 171.0, PI * .5], [40.6, 222.0, -PI * .5]]:
		_bicycle(Vector3(spec[0], 0, spec[1]), spec[2])

func _bicycle(at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var i := stretch_at(at)
	for z in [-.52, .52]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = .3
		torus.outer_radius = .34
		torus.rings = 18
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = _material("#141414")
		ring.transform = Transform3D(b * Basis(Vector3.BACK, PI * .5), at + b * Vector3(0, .34, z))
		ring.visibility_range_end = 60.0
		add_child(ring)
	var lean := Basis(Vector3.FORWARD, .12)
	bar(at + b * Vector3(0, .34, -.52), at + b * Vector3(0, .75, -.05), .03, "#a1261b", i)
	bar(at + b * Vector3(0, .34, -.52), at + b * Vector3(0, .38, .05), .03, "#a1261b", i)
	bar(at + b * Vector3(0, .38, .05), at + b * Vector3(0, .8, .02), .03, "#a1261b", i)
	bar(at + b * Vector3(0, .75, -.05), at + b * Vector3(0, .72, .45), .03, "#a1261b", i)
	bar(at + b * Vector3(0, .72, .45), at + b * Vector3(0, .34, .52), .03, "#a1261b", i)
	bar(at + b * Vector3(-.25, .98, .42), at + b * Vector3(.25, .98, .42), .025, "#1a1a1a", i)
	bx(at + b * Vector3(0, .84, -.02), Vector3(.12, .05, .24), "#1a1a1a", false, b, i)
	bx(at + b * Vector3(0, .62, .62), Vector3(.3, .2, .25), "#3a4a3e", false, b * lean, i)

# ---------------------------------------------------------------- the parol lane

func _parol() -> void:
	# Christmas lights strung across the lane and a star lantern on a balcony: November in Davao. Some of the bulbs
	# still on (a battery pack on the rail).
	for k in 4:
		var z := 238.0 + k * 8.0
		var a := Vector3(41.1, 5.0 + rng.randf_range(-.4, .4), z)
		var b := Vector3(45.9, 5.0 + rng.randf_range(-.4, .4), z + rng.randf_range(-2, 2))
		wire(a, b, .5, .01)
		for j in 12:
			var t := (j + .5) / 12.0
			var at := a.lerp(b, t) + Vector3.DOWN * .5 * 4.0 * t * (1.0 - t) + Vector3.DOWN * .04
			var c: String = ["glow#ff3b3b*3.0", "glow#3bff6a*3.0", "glow#3b8bff*3.0", "glow#ffd23b*3.0"][(j + k) % 4]
			bx(at, Vector3(.06, .08, .06), c if rng.randf() < .7 else "#2a2a2a", false, Basis.IDENTITY, 3)
	var star := Vector3(45.3, 4.4, 252.0)
	bar(star + Vector3(.6, .7, 0), star, .015, "#1a1a1a", 3)
	for k in 5:
		var a := TAU * k / 5.0
		var tip := star + Vector3(0, cos(a), sin(a)) * .85
		var a2 := a + TAU / 10.0
		var a3 := a - TAU / 10.0
		bar(tip, star + Vector3(0, cos(a2), sin(a2)) * .36, .07, "glow#ff3a2a*2.6", 3)
		bar(tip, star + Vector3(0, cos(a3), sin(a3)) * .36, .07, "glow#ff3a2a*2.6", 3)
		bar(star, tip, .04, "glow#ffd25a*2.4", 3)
	bx(star, Vector3(.06, .42, .42), "glow#3bdc6a*2.0", false, Basis(Vector3.RIGHT, PI * .25), 3)
	bx(star, Vector3(.07, .22, .22), "glow#fff2c0*3.0", false, Basis.IDENTITY, 3)
	for k in 6:
		bar(star + Vector3(0, -.45, -.15 + k * .06), star + Vector3(0, -1.2 - rng.randf() * .3, -.15 + k * .06), .012, "glow#ffcf6a*1.2", 3)
	lamp(star + Vector3(-.6, 0, 0), Color(1.0, .55, .35), 1.8, 6.0)
	# The teal shop light at the dogleg, and the graffiti wall the lane turns at (the Macau photo).
	bx(Vector3(41.2, 3.5, 266.0), Vector3(.1, .8, 1.4), "glow#7fe8e0*1.6", false, Basis.IDENTITY, 3)
	lamp(Vector3(42.0, 3.0, 266.0), Color(.5, 1.0, .95), 1.6, 7.0)
	label(Vector3(41.26, 3.5, 266.0), "MOBILE\nREPAIR", .16, PI * .5, Color(.05, .15, .15), false)
	var tag := Vector3(44.0, 1.6, 275.0 - .03)
	for k in 9:
		bx(tag + Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-.8, .8), 0), Vector3(rng.randf_range(.4, 1.4), rng.randf_range(.06, .14), .01), ["#d9d9d4", "#2a2a2a", "#c8c8c0"][k % 3], false, Basis(Vector3.BACK, rng.randf_range(-.8, .8)), 3)
	label(tag + Vector3(0, .1, -.01), "J2 • 2026", .5, PI, Color(.85, .85, .8, .8), false)

# ---------------------------------------------------------------- the skyline

func _tower_blocks() -> void:
	# Tall blocks behind the low streets, a few windows lit (the Tokyo photo); their mass closes the sky.
	for spec in [[Vector3(55, 0, 330), 14.0, 12.0, 11], [Vector3(10, 0, 390), 16.0, 12.0, 13], [Vector3(-14, 0, 200), 12.0, 14.0, 9],
			[Vector3(62, 0, 160), 18.0, 12.0, 8], [Vector3(48, 0, 460), 14.0, 16.0, 12], [Vector3(-18, 0, 120), 14.0, 10.0, 7]]:
		var c: Vector3 = spec[0]
		var wx: float = spec[1]
		var wz: float = spec[2]
		var floors: int = spec[3]
		var h := floors * 3.0
		var i := _nearest_stretch(c)
		bx(c + Vector3.UP * h * .5, Vector3(wx, h, wz), "concrete_wall_008|#6f7470", false, Basis.IDENTITY, i)
		for f in range(2, floors):
			for side in [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)]:
				var span := wx if side.z != 0 else wz
				var n := int(span / 2.2)
				for k in n:
					var u := -span * .5 + (k + .5) * span / n
					var at := c + Vector3(u if side.z != 0 else side.x * (wx * .5 + .02), f * 3.0 + 1.4, side.z * (wz * .5 + .02) if side.z != 0 else u)
					var lit := rng.randf() < .1
					var tint: String = ["#ffd9a0", "#e8f6e0", "#bfe8ff", "#ffe8c0"][rng.randi() % 4]
					bx(at, Vector3(1.2, 1.2, .03) if side.z != 0 else Vector3(.03, 1.2, 1.2), "glow%s*%.2f" % [tint, rng.randf_range(.15, .32)] if lit else "#141817", false, Basis.IDENTITY, i)
		bx(c + Vector3.UP * (h + .6), Vector3(wx * .3, 1.2, wz * .3), "#5c605c", false, Basis.IDENTITY, i)
		bx(c + Vector3.UP * (h + 1.5), Vector3(.08, 3.0, .08), "#2a2a2a", false, Basis.IDENTITY, i)
		bx(c + Vector3.UP * (h + 3.0), Vector3(.12, .12, .12), "glow#ff2a1a*4.0", false, Basis.IDENTITY, i)

# ---------------------------------------------------------------- the main road, glimpsed

func _road_glimpses() -> void:
	# Past the barriers at the ends of the side streets: fire-glow, smoke, a siren, the crowd.
	for spec in [[Vector3(55.0, 3.0, 145.5), Vector3(1, 0, 0)], [Vector3(57.0, 3.0, 190.5), Vector3(1, 0, 0)],
			[Vector3(44.0, 3.0, 353.0), Vector3(1, 0, 0)], [Vector3(-12.5, 3.0, 109.5), Vector3(-1, 0, 0)]]:
		var at: Vector3 = spec[0]
		var l := lamp(at + spec[1] * 2.0, Color(1.0, .45, .15), 3.2, 14.0)
		fires.append([l, 3.2, rng.randf_range(9.0, 14.0)])
		var smoke := CPUParticles3D.new()
		smoke.position = at + spec[1] * 3.0
		smoke.amount = 18
		smoke.lifetime = 7.0
		smoke.direction = Vector3.UP
		smoke.spread = 25.0
		smoke.initial_velocity_min = .6
		smoke.initial_velocity_max = 1.4
		smoke.gravity = Vector3(0, .15, 0)
		smoke.scale_amount_min = 2.0
		smoke.scale_amount_max = 4.0
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		smoke.emission_box_extents = Vector3(3, .5, 3)
		var quad := QuadMesh.new()
		quad.size = Vector2(1, 1)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(.08, .07, .07, .32)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		quad.material = mat
		smoke.mesh = quad
		smoke.visibility_range_end = 90.0
		add_child(smoke)
	# The jeepney wedged across the pole street's side road, and the cars behind it.
	place("street/jeepney", Vector3(39.0, 0, 353.0), 90.0)
	for k in 2:
		bx(Vector3(37.5 + k * .3, .7, 351.2 + k * 3.6), Vector3(1.8, 1.4, 4.2), ["#2a3550", "#6a6d70"][k], false, Basis(Vector3.UP, .4 - k * .7), 4)
	var sounds := [["res://assets/audio/sfx/siren_wail.ogg", Vector3(60, 4, 250), -6.0, 40.0], ["res://assets/audio/siege/groan_b.ogg", Vector3(56, 2, 190), -2.0, 14.0],
		["res://assets/audio/siege/groan_c.ogg", Vector3(46, 2, 353), -2.0, 14.0], ["res://assets/audio/siege/rattle.ogg", Vector3(56, 2, 146), -8.0, 10.0]]
	for spec in sounds:
		var a := AudioStreamPlayer3D.new()
		var stream := load(spec[0]) as AudioStream
		if stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop = true
		a.stream = stream
		a.position = spec[1]
		a.volume_db = spec[2]
		a.unit_size = spec[3]
		a.max_distance = spec[3] * 4.0
		a.autoplay = true
		add_child(a)

# ---------------------------------------------------------------- props and story

func _props() -> void:
	var models := [["nichols/nh_trashbag", 0], ["nichols/nh_trashbag", 0], ["nichols/nh_wooden_crate_02", 0], ["nichols/nh_cardboard_box_01", 0],
		["street/oil_drum", 0], ["nichols/nh_old_tyre", 0], ["street/plastic_monobloc_chair_01", 0], ["street/power_box_01", 0]]
	for spec: Array in CORRIDORS:
		var x0: float = spec[0]
		var x1: float = spec[1]
		var z0: float = spec[2]
		var z1: float = spec[3]
		var i: int = spec[4]
		var along_z := (z1 - z0) >= (x1 - x0)
		var length := maxf(z1 - z0, x1 - x0)
		var t := rng.randf_range(2.0, 5.0)
		while t < length - 2.0:
			var left := rng.randf() < .5
			var at := Vector3((x0 + .55) if left else (x1 - .55), 0, z0 + t) if along_z else Vector3(x0 + t, 0, (z0 + .55) if left else (z1 - .55))
			var roll := rng.randf()
			if roll < .55:
				var m: Array = models[rng.randi() % models.size()]
				place(m[0], at, rng.randf_range(0, 360))
				if m[0] == "nichols/nh_trashbag":
					place("nichols/nh_trashbag", at + Vector3(rng.randf_range(-.4, .4), 0, rng.randf_range(-.4, .4)), rng.randf_range(0, 360))
			elif roll < .7 and i in [0, 5]:
				_bin(at, along_z, left, i)
			elif roll < .78 and i in [3, 4]:
				place("street/tricycle_b" if rng.randf() < .5 else "street/tricycle_a", at + (Vector3(.5 if left else -.5, 0, 0) if along_z else Vector3(0, 0, .5 if left else -.5)), 0.0 if along_z else 90.0)
				t += 3.0
			elif roll < .84:
				cyl(at + Vector3.UP * .3, .16, .6, "#e05a1e", Basis.IDENTITY, 8, i)
			t += rng.randf_range(3.0, 7.0)

func _bin(at: Vector3, along_z: bool, left: bool, stretch: int) -> void:
	var size := Vector3(1.0, 1.2, 1.8) if along_z else Vector3(1.8, 1.2, 1.0)
	var c := at + (Vector3(.15 if left else -.15, 0, 0) if along_z else Vector3(0, 0, .15 if left else -.15))
	bx(c + Vector3.UP * .65, size, ["#2f4a33", "#1f3550", "#3a3d3a"][rng.randi() % 3], true, Basis.IDENTITY, stretch)
	var lid := Basis(Vector3.BACK, -.5 if left else .5) if along_z else Basis(Vector3.RIGHT, .5 if left else -.5)
	bx(c + Vector3.UP * 1.35, size * Vector3(1.02, .04, 1.02), "#1f2420", false, lid, stretch)

func _story() -> void:
	# A shutter half down with drag marks going under it; a woman's slippers in the tile street; the bread the
	# bakery put out that morning still on its rack; a pram of sacks of rice someone pushed this far and left.
	s.drag_trail(Vector3(-2.6, 0, 117.0), Vector3(-4.85, 0, 121.4))
	s.stain("spatter_floor", Vector3(.2, 0, 145.0), .4, 1.4, 1.4, .8)
	for k in 2: bx(Vector3(11.0 + k * .4, .02, 146.2 + k * .3), Vector3(.1, .025, .26), "#c43b2b", false, Basis(Vector3.UP, .5 + k), 1)
	s.stain("pool_big", Vector3(42.6, 0, 205.6), 1.0, 1.7, 1.4)
	s.drag_trail(Vector3(28.5, 0, 368.0), Vector3(29.6, 0, 370.6), false)
	s.stain("spatter_floor", Vector3(40.4, 1.2, 353.0), 0.0, 1.0, 1.0, .7)

# ---------------------------------------------------------------- the college's back gate

## 0.50: the lane ends at the back wall and gate of the Prof. Ivan Lawrence College of Science and Technology. The
## school (school.gd) builds the wall, the gate and everything behind it when the backstreets are woken.
func _school_gate() -> void:
	pass

func tick(now: float) -> void:
	if horror != null: horror.tick(now)
	for f: Array in fires:
		var l: Light3D = f[0]
		var phase: float = f[2]
		if phase > 8.0: l.light_energy = float(f[1]) * (.75 + .25 * sin(now * phase * .7) + .1 * sin(now * phase * 2.3))
		else:
			var off := sin(now * phase * 7.0) > .7 and sin(now * phase) > .2
			l.light_energy = float(f[1]) * (.08 if off else 1.0)
