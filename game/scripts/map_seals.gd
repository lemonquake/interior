class_name InteriorMapSeals
extends Node3D
## 0.26: closes the ways the player could wander that lead nowhere.
##
## Found with tests/world_audit.gd (`--cells`) on the 0.75 m walkability grid:
## - SLITS: gaps one cell wide between two lot walls, between a house and the perimeter sheets, or behind the east
##   wall of street B. Each ran a few metres and stopped (or let the player squeeze round the back of a row of
##   houses). Every mouth that opened on a street, a lane or a yard gets a leaned sheet of roofing iron wedged
##   across it, the way the rest of the town was shut (scripts/town_siege.gd).
## - FENCES: the open ground all the way round the outside of the Nichols estate fence (a 5-10 m band on three
##   sides, nothing in it). The front fence line now carries on to the boundary on both sides.
## - EDGES (found with `--voids` over the whole world): places where the ground simply stopped with nothing in the
##   way. The canal district's upper lane ended in an open 0.8 m lip on the east (a strip behind the town's west
##   lots ran from the Nichols side to the dike north of the district, whose own edges were open air), had no wall
##   on its north-west and north-east corners or along the west side north of z 34; and beside the start of the
##   rice-field road the wall stopped short, letting the player round it onto that dike. All are fenced now.
## The three ways through the town wall, the pallet path, the canal's boardwalks and the Nichols approach are not
## touched; tests/seals_integration.gd checks that every key place is still reached and that the sealed ground is not.
## Everything is real geometry with collision (layer 2), merged into one mesh per material.

const OUTDOOR_LAYER := 2
const TEX := "res://assets/outdoor/textures/"
const GROUND := -2.9
## [x, z, runs along z (0) or x (1)]: the mouth cell of a slit.
const SLITS := [
	[-23.12, 20.38, 0], [-23.12, 25.62, 0], [-23.12, 28.62, 0], [-23.12, 33.12, 0], [-23.12, 36.12, 0],
	[-7.38, 43.62, 0], [-5.88, 42.88, 0], [-5.12, 13.62, 0], [3.88, 12.12, 0], [3.88, 27.12, 0], [3.88, 30.12, 0],
	[4.62, 43.62, 0], [5.38, 12.12, 0], [17.38, 43.62, 0], [24.88, -14.12, 0], [24.88, -6.62, 0], [24.88, 6.12, 0],
	[-4.38, 22.62, 1],
]
## [from x, from z, to x, to z]: a run of sheet fence.
const FENCES := [
	[-47.4, -59.6, -40.3, -59.6],
	[14.3, -59.6, 26.4, -59.6],
]

## [from x, from z, to x, to z, ground y, height]: sheet fence along an edge of the world.
const EDGES := [
	[-36.95, -17.7, -36.95, 15.0, -2.1, 2.4],     # canal lane, east lip south of the street A mouth
	[-36.95, 21.0, -36.95, 71.2, -2.1, 2.4],      # ... and north of it
	[-36.95, 71.2, -44.6, 71.2, -2.1, 2.4],       # canal north-east corner
	[-95.4, 71.2, -121.45, 71.2, -2.1, 2.4],      # canal north-west corner
	[-121.45, 71.2, -120.65, 65.0, -2.1, 2.4],    # canal west side (the ground's edge follows the river's curve)
	[-120.65, 65.0, -120.0, 59.5, -2.1, 2.4],
	[-120.0, 59.6, -117.6, 59.6, -2.1, 2.4],      # ... and the sliver behind the warren's back wall
	[-104.45, 56.9, -104.45, 59.2, -2.1, 2.2],    # the drop into the warren's drain from outside its north wall
	[-37.0, -17.95, -32.7, -17.95, -2.9, 2.5],    # the strip behind the west lots, south end (Nichols side)
	[-37.0, 71.5, -32.7, 71.5, -2.9, 2.5],        # ... and north end
	[17.3, 62.6, 17.3, 74.5, -2.9, 2.5],          # west of the rice-field road where the block wall stops
	[-36.95, 14.9, -33.2, 14.9, -2.9, 2.5],       # the same strip where street A crosses it, south side
	[-36.95, 22.6, -33.2, 22.6, -2.9, 2.5],       # ... and north side (past the open yard on the corner)
	# 0.34 (tests/climb_integration.gd): round the east end of the canal's south boundary wall a strip of the lane
	# ran on behind it, and west of x -47 its lip was an open 0.8 m step down onto the bare plain south of the
	# district (the 0.26 fill never stepped down more than 0.45 m, so it never saw where that led).
	[-44.55, -16.5, -44.55, -18.3, -2.1, 2.4],
]

## [centre, size, yaw degrees]: unseen colliders where a baked boundary left a gap.
const GUARDS := [
	# The scarecrow islet's rim skipped the segment beside the dike's north shoulder: one step off it and the
	# player fell through the paddy for ever (the water has no bed).
	[Vector3(28.39, -2.6, 180.79), Vector3(.24, 2.4, 1.3), -105.0],
]

var _tools := {}
## 0.34: the boxes of each material, added to its tool in one go (scripts/box_kit.gd).
var _kits := {}
var _materials := {}
var _body: StaticBody3D
var _rng := RandomNumberGenerator.new()
var sheets := 0

## 0.64: the squad game shuts the town's two ways out that lead nowhere in it: the crouch hole in the north wall (the
## old way to the rice fields) and the secret crawl under the south wall (to the Nichols property). A phone drops
## those places from memory for the squad game, so no one, on a phone or a PC, may walk where a phone's squadmates
## have nothing. Sheets nailed across each gap on the town side, the way the rest of the town was shut.
## [from x, from z, to x, to z, height]
const SQUAD_RUNS := [
	[InteriorTownSiege.HOLE_X - .78, InteriorTownSiege.NORTH_Z - .13, InteriorTownSiege.HOLE_X + .78, InteriorTownSiege.NORTH_Z - .13, 2.25],
	[InteriorTownSiege.SECRET_X - .74, InteriorTownSiege.SOUTH_Z + .12, InteriorTownSiege.SECRET_X + .74, InteriorTownSiege.SOUTH_Z + .12, 2.1],
]

static func seal_for_squad(neighbourhood: Node3D) -> InteriorMapSeals:
	if neighbourhood == null or neighbourhood.has_node("Squad seals"):
		return null
	var seals := InteriorMapSeals.new()
	seals.name = "Squad seals"
	neighbourhood.add_child(seals)
	seals._squad()
	return seals

func _squad() -> void:
	_rng.seed = 20261125
	_begin()
	for run: Array in SQUAD_RUNS:
		_run(Vector2(float(run[0]), float(run[1])), Vector2(float(run[2]), float(run[3])), float(run[4]), "Squad seal %.0f" % float(run[1]))
	_commit("Squad seals")
	set_meta("squad_seals", SQUAD_RUNS.size())

static func attach(neighbourhood: Node3D) -> InteriorMapSeals:
	if neighbourhood == null or neighbourhood.has_node("Map seals"):
		return null
	var seals := InteriorMapSeals.new()
	seals.name = "Map seals"
	neighbourhood.add_child(seals)
	seals._build()
	return seals

func _material(key: String, folder: String, tint: Color, metres: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Map seals / " + key
	mat.albedo_color = tint
	var base := TEX + folder + "/"
	if ResourceLoader.exists(base + "albedo.jpg"):
		mat.albedo_texture = load(base + "albedo.jpg")
	if ResourceLoader.exists(base + "normal.jpg"):
		mat.normal_enabled = true
		mat.normal_texture = load(base + "normal.jpg")
		mat.normal_scale = 1.3
	if ResourceLoader.exists(base + "roughness.jpg"):
		mat.roughness_texture = load(base + "roughness.jpg")
	mat.metallic_specular = .3
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / metres
	_materials[key] = mat

func _box(key: String, centre: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	if not _tools.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = tool
		_kits[key] = InteriorBoxKit.new()
	(_kits[key] as InteriorBoxKit).box(size, Transform3D(basis, centre))

func _collide(centre: Vector3, size: Vector3, yaw: float, label: String) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = label
	collision.shape = shape
	collision.transform = Transform3D(Basis(Vector3.UP, yaw), centre)
	collision.set_meta("surface", "metal")
	_body.add_child(collision)

## Sheets of roofing iron from `a` to `b` on the ground: overlapping, none quite upright or the same height, nailed
## to rough posts with a rail behind.
func _run(a: Vector2, b: Vector2, height: float, label: String, ground := GROUND) -> void:
	var length := a.distance_to(b)
	if length < .05:
		return
	var dir := (b - a) / length
	var yaw := atan2(-dir.y, dir.x)
	var basis := Basis(Vector3.UP, yaw)
	var count := maxi(1, ceili(length / .82))
	var width := length / count + .1
	for k in count:
		var t := (k + .5) / count
		var p := a.lerp(b, t)
		var tall := height + _rng.randf_range(-.22, .28)
		var lean := Basis(Vector3.RIGHT, _rng.randf_range(-.07, .07)) * Basis(Vector3.BACK, _rng.randf_range(-.035, .035))
		var key := "iron" if _rng.randf() < .7 else "iron dark"
		_box(key, Vector3(p.x, ground + tall * .5 - .03, p.y) + basis * Vector3(0, 0, _rng.randf_range(-.025, .025)), Vector3(width, tall, .012), basis * lean)
		sheets += 1
	var posts := maxi(2, ceili(length / 2.2) + 1)
	for k in posts:
		var p := a.lerp(b, float(k) / (posts - 1))
		_box("wood", Vector3(p.x, ground + (height + .15) * .5, p.y) + basis * Vector3(0, 0, .06), Vector3(.075, height + .15, .075), basis * Basis(Vector3.BACK, _rng.randf_range(-.03, .03)))
	var mid := (a + b) * .5
	for y in [.55, height - .35]:
		_box("wood", Vector3(mid.x, ground + y, mid.y) + basis * Vector3(0, 0, .11), Vector3(length + .1, .09, .035), basis * Basis(Vector3.BACK, _rng.randf_range(-.012, .012)))
	_collide(Vector3(mid.x, ground + (height + .4) * .5, mid.y), Vector3(length + .16, height + .4, .22), yaw, label)

func _begin() -> void:
	_material("iron", "rusty_corrugated_iron", Color(.62, .56, .5), 1.5)
	_material("iron dark", "rusty_metal_sheet", Color(.48, .42, .38), 1.7)
	_material("wood", "weathered_planks", Color(.5, .44, .38), 1.2)
	_body = StaticBody3D.new()
	_body.name = "Map seal colliders"
	_body.collision_layer = 2
	_body.collision_mask = 0
	_body.set_meta("surface", "metal")
	add_child(_body)

func _build() -> void:
	_rng.seed = 20261110
	_begin()
	for slit: Array in SLITS:
		var x := float(slit[0])
		var z := float(slit[1])
		# Wedged across the gap, a little wider than it (the ends bite into the walls either side).
		if int(slit[2]) == 0:
			_run(Vector2(x - .72, z), Vector2(x + .72, z), 2.05, "Slit %.1f %.1f" % [x, z])
		else:
			_run(Vector2(x, z - .72), Vector2(x, z + .72), 2.05, "Slit %.1f %.1f" % [x, z])
	for fence: Array in FENCES:
		_run(Vector2(float(fence[0]), float(fence[1])), Vector2(float(fence[2]), float(fence[3])), 2.5, "Fence %.0f %.0f" % [float(fence[0]), float(fence[1])])
	for edge: Array in EDGES:
		_run(Vector2(float(edge[0]), float(edge[1])), Vector2(float(edge[2]), float(edge[3])), float(edge[5]), "Edge %.0f %.0f" % [float(edge[0]), float(edge[1])], float(edge[4]))
	for guard: Array in GUARDS:
		_collide(guard[0], guard[1], deg_to_rad(float(guard[2])), "Guard %.0f %.0f" % [(guard[0] as Vector3).x, (guard[0] as Vector3).z])
	_commit("Map seals")
	set_meta("map_seals", {"slits": SLITS.size(), "fences": FENCES.size(), "edges": EDGES.size(), "sheets": sheets})

func _commit(label: String) -> void:
	for key: String in _tools:
		var tool: SurfaceTool = _tools[key]
		(_kits[key] as InteriorBoxKit).pour(tool)
		tool.generate_tangents()
		var instance := MeshInstance3D.new()
		instance.name = label + " - " + key
		instance.mesh = tool.commit()
		instance.material_override = _materials[key]
		instance.layers = OUTDOOR_LAYER
		instance.set_meta("no_range", true)
		add_child(instance)
	_tools.clear()
