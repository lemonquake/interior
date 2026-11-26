class_name InteriorTownSiege
extends Node3D
## 0.23: the town under siege. Whoever was left fenced the block in with whatever sheet iron they could pull off the
## roofs: a sloppy, sagging wall of rusted and painted yero nailed to coco-lumber posts, two and three sheets high,
## braced from inside, topped with barbed wire, weighted with tyres and sandbags. Something on the other side still
## hits it now and then.
##
## Built at runtime under the neighbourhood (like the canal and the Nichols property), in the town frame (ground
## y -2.9). The wall follows the play-area bounds just inside the old invisible ones; where a house stands on the
## line its own walls close the gap. Three ways through:
## - the slum passage (west end of street A): a gate of sheets on a timber frame left open, a bulb over it and a
##   survivors' path of pallets along street A with a strung line of bulbs and spray-painted arrows leading to it
##   (scripts/canal_settlement.gd's estero settlement is behind it);
## - the hole (north end of street B, the old way to the rice fields): a sheet torn up from the bottom, low enough
##   that only a crouching body (C) gets through. The hooded man shows the way (scripts/stranger.gd);
## - a secret one toward the Nichols property (south end of street B), hidden behind sheets leaned on the wall.
## The horror dressing of the streets is scripts/town_horror.gd; the sounds are tools/assets/make_siege_sounds.py.

const GROUND := -2.9
const OUTDOOR_LAYER := 2
## The perimeter: four runs just inside the old bounds (x -24..26, z -18..55; the Nichols region's north edge
## is z -18.5). Corners NW, NE, SE, SW.
const NORTH_Z := 54.8
const EAST_X := 25.8
const SOUTH_Z := -18.55
const WEST_X := -23.85
## The hole in the north wall over street B's old way out (the road centre is x 21): opening x 20.85..21.8.
const HOLE_X := 21.32
const HOLE_WIDTH := .95
const HOLE_HEIGHT := 1.3        # crouching (1.0 m capsule) fits, standing (1.7 m) does not
## Where the hooded man waits for the player once the gate is open: in front of the hole, facing the town.
const STRANGER_WAIT := Vector3(21.32, GROUND, 53.35)
const STRANGER_OUT := Vector3(21.32, GROUND, 56.6)  # through the hole, standing again on the dirt road
## Street D's south end: a run across it and along the backs of the near lots (the open ground behind is out of bounds).
const INNER_Z := 8.95
const INNER_TO_X := -7.6
## The slum passage in the west wall (the canal's opening in its own bounds is z 15..20).
const PASSAGE_Z := Vector2(15.15, 20.85)
## The secret way to the Nichols property: under the south wall, behind leaned sheets (x 18.9..19.8).
const SECRET_X := 19.35
const SECRET_WIDTH := .9
## The survivors' path along street A, from the corner of street B to the passage.
const PATH_Z := 18.15
const PATH_FROM_X := 16.6
const PATH_TO_X := -23.2
const SHEETS_TEX := "res://assets/outdoor/textures/"
const SIEGE := "res://assets/siege/"
const AUDIO := "res://assets/audio/siege/"
const HORROR := preload("res://scripts/town_horror.gd")

var b: InteriorBalconyBuilder
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var solids: StaticBody3D
var town: Node3D
var stats := {"sheets": 0, "upper_sheets": 0, "posts": 0, "braces": 0, "skipped_for_houses": 0, "barbs": 0,
	"pallets": 0, "bulbs": 0, "colliders": 0}
## Houses and tall thin things (poles, lamp posts, trunks) on the town's collider body, as XZ rects.
var houses: Array[Rect2] = []
var thin: Array[Rect2] = []
## The yards' own gates (they become hinged gates at runtime): fences never close them.
var lot_gates: Array[Rect2] = []
## Sheet tools per 12 m chunk of wall, committed as separate meshes so they cull.
var _sheet_tools: Dictionary = {}
var _sheet_material: ShaderMaterial
## Wall points (outside face) where something hits the sheets: [position, outward normal, loose panel or null].
var knock_spots: Array = []
var _bulbs: Array[Dictionary] = []
var _time := 0.0
var _next_knock := 14.0
var _next_groan := 40.0
var _knock_player: AudioStreamPlayer3D
var _groan_player: AudioStreamPlayer3D
var _bang_streams: Array[AudioStream] = []
var _groan_streams: Array[AudioStream] = []
var _hint_text := ""
var _main: Node
var horror: Node3D

static func outward(run: String) -> Vector3:
	match run:
		"north": return Vector3.BACK
		"east": return Vector3.RIGHT
		"south", "inner": return Vector3.FORWARD
	return Vector3.LEFT

## True for a point inside the walled town (the play area the wall encloses).
static func inside(at: Vector3) -> bool:
	return at.x > WEST_X and at.x < EAST_X and at.z > SOUTH_Z and at.z < NORTH_Z

func build(parent_town: Node3D) -> void:
	name = "Town siege"
	town = parent_town
	add_to_group("town_siege")
	rng.seed = 230023
	noise.seed = 2323
	noise.frequency = .21
	b = InteriorBalconyBuilder.new()
	b._stats = {"triangles_added": 0, "static_batches": 0, "colliders": 0}
	solids = StaticBody3D.new()
	solids.name = "Siege colliders"
	solids.collision_layer = 2
	solids.collision_mask = 5
	solids.physics_material_override = PhysicsMaterial.new()
	solids.physics_material_override.friction = .8
	add_child(solids)
	_survey()
	InteriorLoadClock.mark("siege: survey")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_materials()
	InteriorLoadClock.mark("siege: materials")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_perimeter()
	InteriorLoadClock.mark("siege: perimeter")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_hole()
	InteriorLoadClock.mark("siege: hole")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_secret()
	InteriorLoadClock.mark("siege: secret")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_passage()
	InteriorLoadClock.mark("siege: passage")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_lot_fences()
	InteriorLoadClock.mark("siege: lot_fences")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_survivor_path()
	InteriorLoadClock.mark("siege: survivor_path")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	horror = HORROR.new()
	add_child(horror)
	horror.build(self)
	InteriorLoadClock.mark("siege: horror")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	b._commit(self, "Siege - ")
	InteriorLoadClock.mark("siege: b._commit")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_commit_sheets()
	InteriorLoadClock.mark("siege: commit_sheets")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	stats["triangles"] = b._stats.triangles_added
	set_meta("counts", stats)
	b.free()
	b = null
	_setup_audio()
	InteriorLoadClock.mark("siege: setup_audio")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()

# ------------------------------------------------------------------------------------------------ survey

## Reads the town's box colliders once: houses close the wall where they stand on its line, thin tall things push
## a sheet out of their way.
func _survey() -> void:
	var colliders := town.get_node_or_null("NeighbourhoodColliders")
	if colliders == null: return
	for child in colliders.get_children():
		if not child is CollisionShape3D or (child as CollisionShape3D).disabled: continue
		var c := child as CollisionShape3D
		if not c.shape is BoxShape3D: continue
		var size: Vector3 = (c.shape as BoxShape3D).size
		var rect := Rect2(c.position.x - size.x * .5, c.position.z - size.z * .5, size.x, size.z)
		var label := str(c.name)
		if label.begins_with("House"):
			houses.append(rect)
		elif label.begins_with("Lot gate"):
			lot_gates.append(rect)
		elif c.position.y + size.y * .5 > GROUND + 2.0 and size.x < .7 and size.z < .7:
			thin.append(rect)

func _house_at(p: Vector2, along: Vector2, half: float) -> bool:
	for r in houses:
		var hit := 0
		for t in [-half * .8, 0.0, half * .8]:
			if r.grow(.04).has_point(p + along * t): hit += 1
		if hit >= 2: return true
	return false

func _thin_near(p: Vector2, along: Vector2, half: float) -> bool:
	for r in thin:
		for t in [-half, -half * .5, 0.0, half * .5, half]:
			if r.grow(.12).has_point(p + along * t): return true
	return false

# ------------------------------------------------------------------------------------------------ materials

func _materials() -> void:
	b._pbr("post", "weathered_planks", 1.4, Color(.62, .56, .48))
	b._pbr("lumber", "dark_wooden_planks", 1.6, Color(.7, .64, .55))
	b._pbr("bamboo", "wood_peeling_paint_weathered", 1.2, Color(.62, .55, .34))
	b._pbr("plywood", "weathered_plank_siding", 1.8, Color(.66, .6, .52))
	b._pbr("sack", "fabric_pattern_07", .5, Color(.5, .46, .36))
	b._pbr("block", "concrete_block_wall", 2.0, Color(.66, .64, .6))
	b._pbr("rubber", "rusty_metal_sheet", 1.0, Color(.07, .07, .07), .85)
	b._pbr("rust", "rusty_metal_04", 1.5, Color(.75, .62, .5))
	b._pbr("tarp blue", "fabric_pattern_07", 1.2, Color(.12, .24, .42)).cull_mode = BaseMaterial3D.CULL_DISABLED
	b._flat("wire", Color(.06, .055, .05), .55).metallic = .7
	b._flat("cable", Color(.02, .02, .022), .6)
	b._flat("socket", Color(.08, .07, .06), .7)
	_sheet_material = ShaderMaterial.new()
	_sheet_material.resource_name = "Siege / sheet iron"
	_sheet_material.shader = load("res://scripts/siege_sheet.gdshader")
	for spec: Array in [["galv", "corrugated_iron"], ["rust", "rusty_metal_02"], ["deep", "rusty_corrugated_iron"]]:
		_sheet_material.set_shader_parameter(spec[0] + "_albedo", load(SHEETS_TEX + spec[1] + "/albedo.jpg"))
		_sheet_material.set_shader_parameter(spec[0] + "_normal", load(SHEETS_TEX + spec[1] + "/normal.jpg"))

# ------------------------------------------------------------------------------------------------ sheets

func _sheet_tool(at: Vector3) -> SurfaceTool:
	var key := "%d_%d" % [floori(at.x / 12.0), floori(at.z / 12.0)]
	if not _sheet_tools.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_sheet_tools[key] = tool
	return _sheet_tools[key]

## One corrugated sheet: `origin` its bottom-left corner, `right` / `up` its edges (unit), `normal` its outer face.
## `bulge` pushes the middle out (+) or in (-); `jag` tears the top edge; colour carries rust, paint, seed, rot.
func sheet(origin: Vector3, right: Vector3, up: Vector3, normal: Vector3, width: float, height: float, colour: Color,
		bulge := 0.0, jag := 0.0, tool: SurfaceTool = null) -> void:
	if tool == null: tool = _sheet_tool(origin)
	const PITCH := .076
	const DEPTH := .009
	var cols := maxi(4, ceili(width / (PITCH / 4.0)))
	var rows := 3 if absf(bulge) > .001 else 2
	var base_h := origin.y - GROUND
	var grid: Array = []
	for j in rows:
		var row: Array = []
		var v := height * float(j) / (rows - 1)
		for i in cols + 1:
			var u := width * float(i) / cols
			var vv := v
			if j == rows - 1 and jag > 0.0:
				vv -= jag * (.5 + .5 * noise.get_noise_2d(origin.x * 9.0 + u * 14.0, origin.z * 9.0))
			var phase := TAU * u / PITCH
			var bump := bulge * sin(PI * clampf(u / width, 0, 1)) * sin(PI * clampf(vv / height, 0, 1))
			var p := origin + right * u + up * vv + normal * (sin(phase) * DEPTH + bump)
			var n := (normal - right * (DEPTH * TAU / PITCH * cos(phase))).normalized()
			row.append([p, n, Vector2(u, vv)])
		grid.append(row)
	# The builder's winding puts the front face on right x up; where the given normal is the other way, wind the other
	# way too, or the lit side renders black.
	var order := [0, 2, 1, 0, 3, 2] if right.cross(up).dot(normal) >= 0.0 else [0, 1, 2, 0, 2, 3]
	for j in rows - 1:
		for i in cols:
			var quad := [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
			for k in order:
				var vert: Array = quad[k]
				tool.set_color(colour)
				tool.set_normal(vert[1])
				tool.set_uv(vert[2])
				tool.set_uv2(Vector2(base_h, 0))
				tool.add_vertex(vert[0])
	stats.sheets += 1

func _sheet_colour(rusty := -1.0) -> Color:
	var roll := rng.randf()
	var rust := rusty if rusty >= 0.0 else (rng.randf_range(.22, .55) if roll < .45 else rng.randf_range(.55, .98))
	var paint := 0.0
	if rng.randf() < .2: paint = [.15, .4, .65, .9][rng.randi() % 4]
	return Color(rust, paint, rng.randf(), rng.randf_range(.3, 1.0))

func _commit_sheets() -> void:
	var _t := Time.get_ticks_usec()
	_commit_sheets__timed()
	InteriorLoadClock.tally("siege sheets commit", _t)

func _commit_sheets__timed() -> void:
	for key: String in _sheet_tools:
		var tool := _sheet_tools[key] as SurfaceTool
		var built: Mesh = InteriorBuildCache.mesh("Siege sheets " + key)
		if built == null:
			tool.index()
			tool.generate_tangents()
			built = tool.commit()
			InteriorBuildCache.store("Siege sheets " + key, built)
		var mi := MeshInstance3D.new()
		mi.name = "Siege sheets " + key
		mi.mesh = built
		mi.material_override = _sheet_material
		mi.layers = OUTDOOR_LAYER
		add_child(mi)
	_sheet_tools.clear()

func _solid(label: String, p: Vector3, size: Vector3, surface := "metal", basis := Basis.IDENTITY) -> CollisionShape3D:
	var c := CollisionShape3D.new()
	c.name = label.validate_node_name()
	var shape := BoxShape3D.new()
	shape.size = size
	shape.margin = .002
	c.shape = shape
	c.transform = Transform3D(basis, p)
	c.set_meta("surface", surface)
	solids.add_child(c, true)
	stats.colliders += 1
	return c

# ------------------------------------------------------------------------------------------------ the wall

func _perimeter() -> void:
	var nw := Vector2(WEST_X, NORTH_Z)
	var ne := Vector2(EAST_X, NORTH_Z)
	var se := Vector2(EAST_X, SOUTH_Z)
	var sw := Vector2(WEST_X, SOUTH_Z)
	# Openings (along each run, in metres from its start) are built by _hole, _secret and _passage.
	_run("north", nw, ne, [[HOLE_X - WEST_X - HOLE_WIDTH * .5, HOLE_X - WEST_X + HOLE_WIDTH * .5]])
	_run("east", ne, se, [])
	_run("south", se, sw, [[EAST_X - SECRET_X - SECRET_WIDTH * .5, EAST_X - SECRET_X + SECRET_WIDTH * .5]])
	_run("west", sw, nw, [[PASSAGE_Z.x - SOUTH_Z, PASSAGE_Z.y - SOUTH_Z]])
	# Street D's south end looked out over the empty ground behind the houses: closed off as well.
	_run("inner", Vector2(WEST_X, INNER_Z), Vector2(INNER_TO_X, INNER_Z), [])

## Sheets along one run from a to c (XZ), leaving `gaps` ([from, to] metres along it) open. Posts, rails and
## braces go on the inside; colliders cover each continuous stretch.
func _run(label: String, a: Vector2, c: Vector2, gaps: Array) -> void:
	var along := (c - a).normalized()
	var length := a.distance_to(c)
	var out3 := outward(label)
	var along3 := Vector3(along.x, 0, along.y)
	# The sheets' outer face looks out; seen from outside, `right` runs along the run when out x along is up.
	var t := 0.0
	var stretch_start := -1.0
	var post_next := rng.randf_range(.3, 1.2)
	var index := 0
	while t < length - .05:
		var w := minf(rng.randf_range(.8, .95), length - t)
		var gap: Array = []
		for g: Array in gaps:
			if t + w > g[0] - .02 and t < g[1] - .001:
				gap = g
		if not gap.is_empty():
			if stretch_start >= 0.0:
				_wall_collider(label, a, along, stretch_start, minf(t, gap[0]), out3)
			stretch_start = -1.0
			t = gap[1]
			continue
		var mid := a + along * (t + w * .5)
		if _house_at(mid, along, w * .5):
			stats.skipped_for_houses += 1
			if stretch_start >= 0.0:
				_wall_collider(label, a, along, stretch_start, t, out3)
				stretch_start = -1.0
			t += maxf(w - .06, w * .5)
			continue
		if stretch_start < 0.0: stretch_start = t
		var push := .0
		if _thin_near(mid, along, w * .5): push = .42  # round a pole or a trunk on the outside
		_wall_bay(label, a + along * t, along3, out3, w, push, index)
		if t >= post_next:
			_post(Vector3(a.x + along.x * t, GROUND, a.y + along.y * t) - out3 * (.09 - push), out3, index)
			post_next = t + rng.randf_range(2.1, 2.7)
		index += 1
		t += maxf(w - .06, w * .5)
	if stretch_start >= 0.0:
		_wall_collider(label, a, along, stretch_start, length, out3)
	_rails(label, a, c, out3, gaps)

func _wall_collider(label: String, a: Vector2, along: Vector2, t0: float, t1: float, out3: Vector3) -> void:
	if t1 - t0 < .05: return
	var mid := a + along * ((t0 + t1) * .5)
	var size := Vector3(absf(along.x) * (t1 - t0) + absf(along.y) * .2, 4.4, absf(along.y) * (t1 - t0) + absf(along.x) * .2)
	_solid("Siege wall " + label, Vector3(mid.x, GROUND + 2.2, mid.y) + out3 * .02, size)

## One bay: a lower sheet, usually an upper one overlapping it, sometimes something else nailed up instead.
func _wall_bay(label: String, start: Vector2, along: Vector3, out3: Vector3, w: float, push: float, index: int) -> void:
	var lean := rng.randf_range(-.035, .05)                    # lean out (+) or in
	var yaw := Basis(Vector3.UP, rng.randf_range(-.03, .03))
	var right := yaw * along
	var up := (Vector3.UP + out3 * lean).normalized()
	var normal := right.cross(up).normalized()
	if normal.dot(out3) < 0.0: normal = -normal
	var depth := (.015 if index % 2 == 0 else -.004) + push
	var origin := Vector3(start.x, GROUND - .06 + rng.randf_range(0, .05), start.y) + out3 * depth
	var low_h := rng.randf_range(2.15, 2.5)
	var kind := rng.randf()
	if kind < .06:
		# A sheet of old plywood or a door's worth of planks instead of iron.
		b._box("Plywood patch", origin + right * w * .5 + up * low_h * .5, Vector3(w, low_h, .025), "plywood", false,
			Basis(right, up, normal))
	else:
		sheet(origin, right, up, normal, w, low_h, _sheet_colour(), rng.randf_range(-.04, .05) if rng.randf() < .3 else 0.0)
	var top := low_h
	if rng.randf() < .86:
		var up_h := rng.randf_range(.95, 1.3) if rng.randf() < .8 else rng.randf_range(.6, 1.55)
		var shift := rng.randf_range(-.08, .08)
		var tilt := Basis(normal, rng.randf_range(-.06, .06))
		var o2 := origin + up * (low_h - rng.randf_range(.18, .32)) + right * shift + normal * .018
		sheet(o2, tilt * right, tilt * up, normal, w * rng.randf_range(.85, 1.0), up_h, _sheet_colour(), 0.0,
			rng.randf_range(.0, .22) if rng.randf() < .35 else 0.0)
		stats.upper_sheets += 1
		top = low_h + up_h - .25
	# Barbed wire stakes every few bays (the strands are strung by _rails).
	if index % 3 == 0 and rng.randf() < .8:
		var stake := origin + up * top
		b._rod(stake - normal * .02, stake + up * .38 - normal * .02, .009, "wire", 4)
	# What holds the bottom down: a tyre, sandbags, a hollow block or two (inside).
	var foot := Vector3(origin.x, GROUND, origin.z) + right * w * .5 - out3 * (.22 + push)
	match rng.randi_range(0, 9):
		0: _tyre(foot - out3 * .2, rng.randf() < .5)
		1, 2: _sandbag(foot, along)
		3: b._box("Hollow block", foot + Vector3.UP * .1, Vector3(.4, .2, .2), "block", false, Basis(Vector3.UP, rng.randf_range(-.3, .3)) * Basis.looking_at(along))
	# Where something keeps hitting it from outside: remember the spot (the bangs come from here).
	if label != "inner" and rng.randf() < .045:
		knock_spots.append([origin + right * w * .5 + Vector3.UP * 1.1 + out3 * .4, out3, null])

func _post(at: Vector3, out3: Vector3, index: int) -> void:
	var h := rng.randf_range(2.6, 3.4)
	var lean := Vector3(rng.randf_range(-.05, .05), 0, rng.randf_range(-.05, .05))
	var top := at + Vector3.UP * h + lean
	if index % 4 == 1:
		b._rod(at, top, .055, "bamboo", 8)
	else:
		var axis := (top - at).normalized()
		var side := axis.cross(out3).normalized()
		b._box("Coco lumber post", (at + top) * .5, Vector3(.075, h, .075), "post", false, Basis(side, axis, side.cross(axis)))
	stats.posts += 1
	# A brace from the post to the ground inside, every few posts.
	if rng.randf() < .45:
		var foot := at - out3 * rng.randf_range(1.1, 1.5) + Vector3(rng.randf_range(-.3, .3), 0, rng.randf_range(-.3, .3)) * Vector3(absf(out3.z), 0, absf(out3.x))
		var hold := at + Vector3.UP * rng.randf_range(1.6, 2.1) - out3 * .03
		var dir := (hold - foot).normalized()
		var side2 := dir.cross(Vector3.UP).normalized()
		b._box("Brace", (foot + hold) * .5, Vector3(.06, foot.distance_to(hold), .045), "lumber", false, Basis(side2, dir, side2.cross(dir)))
		# Thin enough to step past, but the player cannot walk through it.
		_solid("Siege brace", (foot + hold) * .5, Vector3(.08, foot.distance_to(hold), .08), "wood", Basis(side2, dir, side2.cross(dir)))
		stats.braces += 1

## The two nailing rails (inside) and the barbed wire along the top of a run.
func _rails(label: String, a: Vector2, c: Vector2, out3: Vector3, gaps: Array) -> void:
	var along := (c - a).normalized()
	var length := a.distance_to(c)
	for spec: Array in [[.45, "low"], [2.02, "high"]]:
		# Rails stop at the openings, except the high one over the hole and the secret crawl (above head height).
		var crosses: bool = spec[1] == "high" and label != "west"
		var t := 0.0
		while t < length - .1:
			var seg := minf(rng.randf_range(2.4, 3.6), length - t)
			var resume := -1.0
			if not crosses:
				for g: Array in gaps:
					if t + seg > g[0] - .05 and t < g[1] + .05:
						seg = g[0] - .05 - t
						resume = g[1] + .05
			var p0 := a + along * t
			var p1 := a + along * (t + seg)
			if seg > .2 and not _house_at((p0 + p1) * .5, along, seg * .4):
				var y := GROUND + float(spec[0]) + rng.randf_range(-.04, .04)
				var q0 := Vector3(p0.x, y, p0.y) - out3 * .055
				var q1 := Vector3(p1.x, y + rng.randf_range(-.05, .05), p1.y) - out3 * .055
				b._box("Rail", (q0 + q1) * .5, Vector3(.045, .07, q0.distance_to(q1)), "lumber", false, Basis.looking_at((q1 - q0).normalized()))
			t = resume if resume > 0.0 else t + seg
	# Barbed wire: two strands sagging between the stakes, missing for stretches.
	var t2 := 0.0
	while t2 < length - 1.0:
		var seg := minf(rng.randf_range(2.0, 2.8), length - t2)
		var skip := rng.randf() < .2
		for g: Array in gaps:
			if label == "west" and t2 + seg > g[0] - .3 and t2 < g[1] + .3: skip = true
		var p0 := a + along * t2
		var p1 := a + along * (t2 + seg)
		if not skip and not _house_at((p0 + p1) * .5, along, seg * .4):
			for k in 2:
				var h := GROUND + 2.62 + k * .17 + rng.randf_range(-.05, .05)
				var q0 := Vector3(p0.x, h, p0.y) - out3 * .02
				var q1 := Vector3(p1.x, h + rng.randf_range(-.08, .08), p1.y) - out3 * .02
				_barbed(q0, q1, .06 + rng.randf() * .1)
		t2 += seg

func _barbed(a: Vector3, c: Vector3, sag: float) -> void:
	var points: Array = []
	for i in 9:
		var f := i / 8.0
		points.append(a.lerp(c, f) + Vector3.DOWN * sin(f * PI) * sag)
	b._tube(points, .0035, "wire", 3)
	var d := a.distance_to(c)
	var n := int(d / .28)
	for i in n:
		var f := (i + .5) / n
		var p: Vector3 = a.lerp(c, f) + Vector3.DOWN * sin(f * PI) * sag
		var spin := rng.randf() * PI
		var x := Vector3(cos(spin), .0, sin(spin)) * .028
		var y := Vector3(0, .028, 0).rotated((c - a).normalized(), spin)
		b._rod(p - x, p + x, .002, "wire", 3)
		b._rod(p - y, p + y, .002, "wire", 3)
		stats.barbs += 1

func _tyre(at: Vector3, flat: bool) -> void:
	var basis := Basis(Vector3.UP, rng.randf() * TAU) * (Basis.IDENTITY if flat else Basis(Vector3.RIGHT, PI * .5 + rng.randf_range(-.25, .25)))
	b._lathe(at + Vector3.UP * (.1 if flat else .3), [Vector2(.2, -.09), Vector2(.3, -.1), Vector2(.33, 0), Vector2(.3, .1), Vector2(.2, .09)], "rubber", 16, basis)

func _sandbag(at: Vector3, along: Vector3) -> void:
	for k in rng.randi_range(1, 3):
		var p := at + along * (k * .5 - .4) + Vector3.UP * (.1 + (.18 if k == 2 and rng.randf() < .4 else 0.0))
		b._sphere(p, Vector3(.48, .19, .3) * rng.randf_range(.9, 1.1), "sack", 8)

# ------------------------------------------------------------------------------------------------ the hole

## North wall, street B: the sheet over the old way to the rice fields was torn up from the bottom and bent out;
## the low rail was smashed through. A crouching body fits under what is left.
func _hole() -> void:
	var left := Vector3(HOLE_X - HOLE_WIDTH * .5, GROUND, NORTH_Z)
	var right := Vector3.RIGHT
	var normal := Vector3.BACK
	# What is left of the torn sheet above the opening: ragged bottom edge at HOLE_HEIGHT.
	var o := left + Vector3(-.04, HOLE_HEIGHT + .03, .016)
	sheet(o, right, Vector3.UP, normal, HOLE_WIDTH + .08, 2.25 - HOLE_HEIGHT, Color(.7, 0, .31, .9))
	# The torn-off lower part, bent outward and up like a lid, lying against the opening's outside.
	var flap_o := left + Vector3(.02, .05, .12)
	var flap_up := (Vector3.UP * .45 + Vector3.BACK * .89).normalized()
	sheet(flap_o, right, flap_up, flap_up.cross(right), HOLE_WIDTH - .04, 1.05, Color(.8, 0, .74, 1.0), .05, .12)
	# The upper row over the hole stays.
	sheet(left + Vector3(-.1, 2.0, .034), right, Vector3.UP, normal, HOLE_WIDTH + .2, 1.3, _sheet_colour(), 0.0, .15)
	# The lintel: the high rail and a crosspiece someone nailed above the gap after it was made.
	var y := GROUND + HOLE_HEIGHT + .06
	b._box("Hole crosspiece", Vector3(HOLE_X, y, NORTH_Z - .05), Vector3(HOLE_WIDTH + .5, .09, .05), "lumber", false, Basis(Vector3.FORWARD, .04))
	_solid("Siege hole lintel", Vector3(HOLE_X, GROUND + HOLE_HEIGHT + 1.65, NORTH_Z + .02), Vector3(HOLE_WIDTH + .1, 3.3, .24))
	# The low rail, smashed: two splintered ends hanging.
	for side: float in [-1.0, 1.0]:
		var end := Vector3(HOLE_X + side * (HOLE_WIDTH * .5 + .03), GROUND + .45, NORTH_Z - .055)
		var hang := end + Vector3(-side * .12, -.32, -.04)
		var dir := (hang - end).normalized()
		b._box("Broken rail", (end + hang) * .5, Vector3(.045, end.distance_to(hang), .07), "lumber", false, Basis(dir.cross(Vector3.FORWARD).normalized(), dir, Vector3.FORWARD))
	# Posts either side of the hole (the opening's frame).
	for side: float in [-1.0, 1.0]:
		var at := Vector3(HOLE_X + side * (HOLE_WIDTH * .5 + .07), GROUND, NORTH_Z - .1)
		b._box("Hole post", at + Vector3.UP * 1.5, Vector3(.08, 3.0, .08), "post", false)
		_solid("Siege hole post", at + Vector3.UP * 1.5, Vector3(.1, 3.0, .1), "wood")
	# A board through the gap on the ground (knees, mud).
	b._box("Kneeling board", Vector3(HOLE_X, GROUND + .012, NORTH_Z + .2), Vector3(.5, .025, 1.6), "plywood", false, Basis(Vector3.UP, .06))

# ------------------------------------------------------------------------------------------------ the secret

## South wall, street B: two sheets leaned against the inside of the wall look like more patching. Behind them
## the bottom of the wall was pried up: a crawl through to the Nichols side. Nothing points to it.
func _secret() -> void:
	var left := Vector3(SECRET_X - SECRET_WIDTH * .5, GROUND, SOUTH_Z)
	var out3 := Vector3.FORWARD
	var right := Vector3.LEFT  # seen from outside (south), the run goes east -> west
	# Above the gap: the pried sheet, its bottom bent out.
	var o := Vector3(SECRET_X + SECRET_WIDTH * .5 + .04, GROUND + HOLE_HEIGHT + .02, SOUTH_Z - .016)
	sheet(o, right, Vector3.UP, out3, SECRET_WIDTH + .08, 2.3 - HOLE_HEIGHT, _sheet_colour(.85))
	var flap := Vector3(SECRET_X + SECRET_WIDTH * .5, GROUND + .55, SOUTH_Z - .1)
	var flap_up := (Vector3.UP * .5 + Vector3.FORWARD * .87).normalized()
	sheet(flap, right, flap_up, right.cross(flap_up) * -1.0, SECRET_WIDTH - .06, .7, _sheet_colour(.9), .03, .08)
	sheet(Vector3(SECRET_X + SECRET_WIDTH * .5 + .1, GROUND + 2.05, SOUTH_Z - .034), right, Vector3.UP, out3, SECRET_WIDTH + .2, 1.2, _sheet_colour())
	_solid("Siege secret lintel", Vector3(SECRET_X, GROUND + HOLE_HEIGHT + 1.65, SOUTH_Z), Vector3(SECRET_WIDTH + .1, 3.3, .24))
	# The leaned sheets in front (inside): a lean-to 1.9 m deep at the foot, resting on the wall at 2 m, so a
	# crouching body fits between it and the wall. Its open end faces east; the west end is stacked with tyres.
	var lean_up := Vector3(0, 2.0, -1.8).normalized()
	var lean_n := Vector3.RIGHT.cross(lean_up)
	if lean_n.dot(Vector3.UP) < 0.0: lean_n = -lean_n
	for k in 2:
		var foot := Vector3(SECRET_X - .95 + k * .86, GROUND + .02, SOUTH_Z + 1.9)
		sheet(foot, Vector3.RIGHT, lean_up, lean_n, .9, 2.65, _sheet_colour(.75))
	_solid("Siege lean-to", Vector3(SECRET_X - .07, GROUND + 1.0, SOUTH_Z + 1.0), Vector3(1.75, 2.69, .1), "metal",
		Basis(Vector3.RIGHT, lean_up, Vector3.RIGHT.cross(lean_up)))
	# Clutter that makes the corner look like nobody's business: a drum, a tyre stack.
	for k in 3:
		_tyre(Vector3(SECRET_X - 1.25 + rng.randf_range(-.04, .04), GROUND + k * .19, SOUTH_Z + .75), true)
	_solid("Siege tyre stack", Vector3(SECRET_X - 1.25, GROUND + .3, SOUTH_Z + .75), Vector3(.66, .6, 1.0), "wood")

# ------------------------------------------------------------------------------------------------ the passage

## West end of street A: the way to the estero. A frame of coco lumber with a header, the two gate leaves (sheets
## on frames) dragged open, a bulb on the header fed by the cable that runs along the survivors' path.
func _passage() -> void:
	var z0 := PASSAGE_Z.x
	var z1 := PASSAGE_Z.y
	var x := WEST_X
	var top := GROUND + 2.9
	for z: float in [z0 - .05, z1 + .05]:
		b._box("Passage post", Vector3(x, GROUND + 1.6, z), Vector3(.12, 3.2, .12), "post", false, Basis(Vector3.FORWARD, rng.randf_range(-.03, .03)))
		_solid("Siege passage post", Vector3(x, GROUND + 1.6, z), Vector3(.14, 3.2, .14), "wood")
	b._box("Passage header", Vector3(x, top, (z0 + z1) * .5), Vector3(.1, .14, z1 - z0 + .5), "post", false, Basis(Vector3.RIGHT, .02))
	# Leaves: each a timber frame with two sheets, hung on the posts and swung open into the town.
	for spec: Array in [[z0, 1.0, 1.15], [z1, -1.0, -1.35]]:
		var hinge := Vector3(x + .08, GROUND + .08, spec[0])
		var swing := Basis(Vector3.UP, spec[2])
		var along := swing * Vector3(0, 0, spec[1])
		var leaf_w := 1.45
		var leaf_n := along.cross(Vector3.UP).normalized()
		for k in 2:
			sheet(hinge + along * (k * .72), along, Vector3.UP, leaf_n, .75, 2.05, _sheet_colour(), 0.0, .05 if k == 1 else 0.0)
		for y: float in [.15, 1.0, 1.9]:
			var c := hinge + along * leaf_w * .5 + Vector3.UP * y - leaf_n * .04
			b._box("Leaf rail", c, Vector3(.05, .06, leaf_w), "lumber", false, Basis.looking_at(along))
		var mid := hinge + along * leaf_w * .5 + Vector3.UP * 1.0
		_solid("Siege gate leaf", mid, Vector3(.08, 2.0, leaf_w), "metal", Basis.looking_at(along))
	# A strip of an old campaign tarpaulin over the header, torn (no lettering readable from here).
	b._plate([Vector3(x - .06, top + .08, z0 + .3), Vector3(x - .06, top + .08, z1 - .4), Vector3(x - .08, top - .55, z1 - .7),
		Vector3(x - .08, top - .5, z0 + .5)], "tarp blue")
	_bulb(Vector3(x + .35, top - .45, (z0 + z1) * .5), 0, Color(1.0, .7, .38), 7.5, 1.2, .12)

# ------------------------------------------------------------------------------------------------ lot fences

## The vacant lots across street A from the house: sheets raised behind their low front walls too, so the street
## runs between walls of iron; each lot's own gate stays clear (the middle lot is the evacuees' camp,
## scripts/town_horror.gd).
func _lot_fences() -> void:
	var z := 21.62
	var spans: Array = [[-15.9, -6.7], [-6.2, 3.9], [4.5, 17.4]]
	# Cut each lot's gate (with room to swing) out of its span.
	for gate in lot_gates:
		if gate.position.y > z + .6 or gate.end.y < z - 1.2: continue
		var cut := [gate.position.x - .35, gate.end.x + .35]
		var next: Array = []
		for span: Array in spans:
			if cut[1] <= span[0] or cut[0] >= span[1]:
				next.append(span)
				continue
			if cut[0] - span[0] > .5: next.append([span[0], cut[0]])
			if span[1] - cut[1] > .5: next.append([cut[1], span[1]])
		spans = next
	stats["lot_fence_spans"] = spans.size()
	for span: Array in spans:
		var t: float = span[0]
		var i := 0
		while t < span[1] - .1:
			var w := minf(rng.randf_range(.8, .95), span[1] - t)
			var lean := rng.randf_range(-.04, .04)
			var up := (Vector3.UP + Vector3.BACK * lean).normalized()
			var origin := Vector3(t, GROUND + .02, z + (.012 if i % 2 == 0 else 0.0))
			# Seen from the street (south), the sheet's outer face looks -Z: right runs -X.
			sheet(origin + Vector3.RIGHT * w, Vector3.LEFT, up, Vector3.FORWARD, w, rng.randf_range(1.9, 2.35), _sheet_colour(),
				rng.randf_range(-.03, .03) if rng.randf() < .25 else 0.0, rng.randf_range(0, .18) if rng.randf() < .3 else 0.0)
			if i % 3 == 0:
				b._box("Lot fence post", Vector3(t, GROUND + 1.25, z + .1), Vector3(.07, 2.5, .07), "post")
			t += maxf(w - .05, w * .5)
			i += 1
		_solid("Siege lot fence", Vector3((span[0] + span[1]) * .5, GROUND + 1.2, z + .05), Vector3(span[1] - span[0], 2.4, .16))

# ------------------------------------------------------------------------------------------------ survivors' path

## From the corner of streets A and B to the passage: pallets laid end to end (the asphalt there is buried under
## silt and debris), a cable strung on bamboo poles with bulbs every other pole, and orange arrows sprayed where
## someone might hesitate. The cable comes out of the estero settlement through the passage.
func _survivor_path() -> void:
	var x := PATH_FROM_X
	var i := 0
	while x > PATH_TO_X:
		var len := rng.randf_range(1.15, 1.25)
		var at := Vector3(x - len * .5, GROUND + .005, PATH_Z + rng.randf_range(-.12, .12))
		_pallet(at, Basis(Vector3.UP, PI * .5 + rng.randf_range(-.08, .08)), i)
		x -= len + rng.randf_range(.02, .2)
		i += 1
	# Bamboo poles on the north side of the street, the cable between them, bulbs on every other one.
	var poles: Array[Vector3] = []
	var px := 15.2
	while px > PATH_TO_X - 1.0:
		poles.append(Vector3(px, GROUND, 20.55 + rng.randf_range(-.08, .08)))
		px -= rng.randf_range(7.6, 8.6)
	poles.append(Vector3(WEST_X + .3, GROUND, PASSAGE_Z.y - .25))
	for k in poles.size():
		var p := poles[k]
		var top := p + Vector3(rng.randf_range(-.08, .08), 3.45, rng.randf_range(-.08, .08))
		b._rod(p, top, .045, "bamboo", 7)
		_solid("Siege path pole", p + Vector3.UP * 1.5, Vector3(.1, 3.0, .1), "wood")
		if k > 0:
			_cable(poles[k - 1] + Vector3.UP * 3.25, p + Vector3.UP * 3.25, .45)
		if k % 2 == 0 and k < poles.size() - 1:
			# The bulb hangs over the pallets, on a drop from the pole's crossarm.
			var arm := top + Vector3(0, -.15, -1.3)
			b._rod(top + Vector3.DOWN * .12, arm, .02, "bamboo", 5)
			_bulb(arm + Vector3.DOWN * .5, k / 2 + 1, Color(1.0, .66, .34), 6.0, .9 if k != 4 else .55, .5)
	# The cable's last run to the header bulb and into the settlement.
	_cable(poles[-1] + Vector3.UP * 3.25, Vector3(WEST_X + .3, GROUND + 2.95, (PASSAGE_Z.x + PASSAGE_Z.y) * .5), .2)
	_cable(Vector3(WEST_X + .3, GROUND + 2.95, (PASSAGE_Z.x + PASSAGE_Z.y) * .5), Vector3(WEST_X - 6.0, GROUND + 3.4, 17.8), .6)

func _pallet(at: Vector3, basis: Basis, index: int) -> void:
	# 1.2 x 1.0 m, three bearers and seven deck boards, some missing or broken.
	var tilt := Basis(Vector3.FORWARD, rng.randf_range(-.025, .025)) * Basis(Vector3.RIGHT, rng.randf_range(-.02, .02))
	var b2 := basis * tilt
	for k in 3:
		b._box("Pallet bearer", at + b2 * Vector3((k - 1) * .45, .045, 0), Vector3(.09, .085, 1.18), "lumber", false, b2)
	for k in 7:
		if rng.randf() < .08: continue
		var z := (k - 3) * .165
		var y := .1 + rng.randf_range(-.004, .004)
		b._box("Pallet board", at + b2 * Vector3(0, y, z), Vector3(1.0, .02, .1), "plywood" if index % 3 == 0 else "lumber", false, b2 * Basis(Vector3.UP, rng.randf_range(-.03, .03)))
	# A low ramped collider so the capsule rides up onto the deck (like the kerbs).
	var shape := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for sx: float in [-.5, .5]:
		for sz: float in [-.6, .6]:
			pts.append(Vector3(sx, 0.0, sz))
			pts.append(Vector3(sx * .66, .11, sz * .7))
	shape.points = pts
	var c := CollisionShape3D.new()
	c.name = "Siege pallet"
	c.shape = shape
	c.transform = Transform3D(b2, at)
	c.set_meta("surface", "wood")
	solids.add_child(c, true)
	stats.pallets += 1

func _cable(a: Vector3, c: Vector3, sag: float) -> void:
	var points: Array = []
	for i in 11:
		var f := i / 10.0
		points.append(a.lerp(c, f) + Vector3.DOWN * sin(f * PI) * sag)
	b._tube(points, .007, "cable", 4)

## A bare bulb on a cord with a warm omni. `flicker` 0..1 is how badly it is failing.
func _bulb(at: Vector3, index: int, colour: Color, reach: float, energy: float, flicker: float) -> void:
	b._rod(at + Vector3.UP * .5, at + Vector3.UP * .04, .004, "cable", 4)
	b._rod(at + Vector3.UP * .07, at + Vector3.UP * .0, .02, "socket", 8)
	var glass := MeshInstance3D.new()
	glass.name = "Siege bulb %d" % index
	var sphere := SphereMesh.new()
	sphere.radius = .035
	sphere.height = .085
	sphere.radial_segments = 10
	sphere.rings = 5
	glass.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.8, .7, .5)
	mat.emission_enabled = true
	mat.emission = colour
	mat.emission_energy_multiplier = 6.0
	glass.material_override = mat
	glass.layers = OUTDOOR_LAYER
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	glass.position = at - Vector3.UP * .04
	var light := OmniLight3D.new()
	light.name = "Siege bulb light %d" % index
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.light_cull_mask = OUTDOOR_LAYER
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = .6
	add_child(light)
	light.position = at - Vector3.UP * .12
	_bulbs.append({"light": light, "mat": mat, "energy": energy, "flicker": flicker, "phase": rng.randf() * 10.0, "out": 0.0})
	stats.bulbs += 1

# ------------------------------------------------------------------------------------------------ sound and motion

func _setup_audio() -> void:
	# Mostly blows; now and then something dragged slowly along the outside instead.
	for n in ["bang_a", "bang_b", "bang_c", "bang_d", "scrape"]:
		if ResourceLoader.exists(AUDIO + n + ".ogg"): _bang_streams.append(load(AUDIO + n + ".ogg"))
	for n in ["groan_a", "groan_b", "groan_c"]:
		if ResourceLoader.exists(AUDIO + n + ".ogg"): _groan_streams.append(load(AUDIO + n + ".ogg"))
	var bus := "Night" if AudioServer.get_bus_index("Night") >= 0 else "Master"
	_knock_player = AudioStreamPlayer3D.new()
	_knock_player.name = "Wall knocks"
	_knock_player.unit_size = 9.0
	_knock_player.max_distance = 80.0
	_knock_player.volume_db = -1.0
	_knock_player.bus = bus
	add_child(_knock_player)
	_groan_player = AudioStreamPlayer3D.new()
	_groan_player.name = "Beyond the wall"
	_groan_player.unit_size = 6.0
	_groan_player.max_distance = 90.0
	_groan_player.volume_db = -9.0
	_groan_player.bus = bus
	_groan_player.attenuation_filter_cutoff_hz = 1800.0
	add_child(_groan_player)
	# Loose top sheets that lift and clack in the wind, a few along the wall.
	for spot: Array in knock_spots.slice(0, 5):
		var rattle := AudioStreamPlayer3D.new()
		rattle.stream = load(AUDIO + "rattle.ogg") if ResourceLoader.exists(AUDIO + "rattle.ogg") else null
		rattle.unit_size = 2.5
		rattle.max_distance = 26.0
		rattle.volume_db = -14.0
		rattle.bus = bus
		rattle.autoplay = rattle.stream != null
		add_child(rattle)
		rattle.position = (spot[0] as Vector3) + Vector3.UP * 1.4

func _process(delta: float) -> void:
	_time += delta
	for bulb: Dictionary in _bulbs:
		var light := bulb.light as OmniLight3D
		var f: float = bulb.flicker
		var wobble := 1.0 - f * .35 * (.5 + .5 * sin(_time * 23.0 + bulb.phase) * sin(_time * 7.3 + bulb.phase * 2.0))
		if bulb.out > 0.0:
			bulb.out -= delta
			wobble = .04
		elif f > .3 and randf() < delta * f * .5:
			bulb.out = randf_range(.04, .5)
		light.light_energy = bulb.energy * wobble
		(bulb.mat as StandardMaterial3D).emission_energy_multiplier = 6.0 * wobble
	var main := _main_scene()
	if main == null or not ("player" in main) or main.player == null or not main.player.playing:
		return
	var player: Node3D = main.player
	_crouch_hint(main, player)
	if not inside(player.global_position) or player.global_position.y > -1.0:
		return
	_next_knock -= delta
	_next_groan -= delta
	if _next_knock <= 0.0:
		_next_knock = randf_range(22.0, 48.0)
		_knock(player)
	if _next_groan <= 0.0:
		_next_groan = randf_range(45.0, 95.0)
		_groan(player)

func _main_scene() -> Node:
	if _main == null or not is_instance_valid(_main):
		_main = get_tree().current_scene
	return _main

## Something hits the wall from outside, somewhere the player is not looking (never right next to them).
func _knock(player: Node3D) -> void:
	if _bang_streams.is_empty() or knock_spots.is_empty(): return
	var camera := get_viewport().get_camera_3d()
	var best: Array = []
	var best_score := -INF
	for spot: Array in knock_spots:
		var p: Vector3 = spot[0]
		var d := p.distance_to(player.global_position)
		if d < 7.0 or d > 34.0: continue
		var seen := camera != null and not camera.is_position_behind(p) and camera.is_position_in_frustum(p)
		var score := randf() - (1.5 if seen else 0.0) - absf(d - 16.0) * .03
		if score > best_score:
			best_score = score
			best = spot
	if best.is_empty(): return
	var stream: AudioStream = _bang_streams[randi() % _bang_streams.size()]
	_knock_player.global_position = best[0]
	_knock_player.stream = stream
	_knock_player.pitch_scale = randf_range(.9, 1.06)
	_knock_player.play()

func _groan(player: Node3D) -> void:
	if _groan_streams.is_empty(): return
	# Beyond the nearest run of wall, 8-20 m out.
	var p := player.global_position
	var runs := [["north", NORTH_Z - p.z], ["east", EAST_X - p.x], ["south", p.z - SOUTH_Z], ["west", p.x - WEST_X]]
	runs.sort_custom(func(a, c): return a[1] < c[1])
	var run: String = runs[randi() % 2][0]
	var out3 := outward(run)
	var at := Vector3(clampf(p.x + randf_range(-12, 12), WEST_X, EAST_X), GROUND + 1.4, clampf(p.z + randf_range(-12, 12), SOUTH_Z, NORTH_Z))
	match run:
		"north": at.z = NORTH_Z
		"south": at.z = SOUTH_Z
		"east": at.x = EAST_X
		_: at.x = WEST_X
	_groan_player.global_position = at + out3 * randf_range(8.0, 20.0)
	_groan_player.stream = _groan_streams[randi() % _groan_streams.size()]
	_groan_player.pitch_scale = randf_range(.88, 1.04)
	_groan_player.play()

## At the hole, a standing player gets the crouch prompt (the hooded man has just shown how).
func _crouch_hint(main: Node, player: Node3D) -> void:
	if not "context_prompt" in main: return
	var p := player.global_position
	var near := absf(p.x - HOLE_X) < 1.4 and p.z > NORTH_Z - 2.2 and p.z < NORTH_Z + 2.2 and p.y < -1.5
	var want := ""
	if near and player.get("crouching") != true:
		want = "Crouch • squeeze through" if main.get("mobile") == true else "Hold C • crouch to squeeze through"
	if want != _hint_text or main.context_prompt != want:
		main.context_prompt = want
		_hint_text = want
