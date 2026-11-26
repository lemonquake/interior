class_name InteriorNeighborhoodGround
extends RefCounted
## Deterministic, surface-aligned street decay. Kept separate from the photographed home.
## All small details are visual; the original bevelled kerbs and walking routes stay authoritative.

const GROUND := -2.9
const STREETS := [[true, 18.0, -24.0, 30.0], [false, 21.0, -18.0, 54.0],
	[true, 49.0, -24.0, 30.0], [false, -19.0, -18.0, 55.0]]
const GRASS_SHADER := preload("res://scripts/field_blades.gdshader")

var b: InteriorBalconyBuilder
var root: Node3D
var rng := RandomNumberGenerator.new()
var stats := {"crack_networks": 0, "dirt_patches": 0, "puddles": 0, "rubble": 0,
	"weed_clumps": 0, "drains": 0, "batches": 0, "triangles": 0}
var plants: Array[Transform3D] = []
var plant_colors: Array[Color] = []

static func build(parent: Node3D) -> Dictionary:
	var existing := parent.get_node_or_null("Abandoned town details")
	if existing != null:
		return existing.get_meta("decay_stats", {})
	var d := InteriorNeighborhoodGround.new()
	d.root = Node3D.new()
	d.root.name = "Abandoned town details"
	parent.add_child(d.root)
	d.b = InteriorBalconyBuilder.new()
	d.b._stats = {"triangles_added": 0, "static_batches": 0, "colliders": 0}
	d.rng.seed = 130061
	d._materials()
	for street: Array in STREETS:
		d._street(street)
	d._lane()
	d._commit_plants()
	d.b._commit(d.root, "Street decay - ")
	d.stats.batches = d.root.get_child_count()
	d.stats.triangles = d.b._stats.triangles_added
	d.root.set_meta("decay_stats", d.stats)
	d.root.set_meta("seed", 130061)
	d.b.free()
	return d.stats

func _materials() -> void:
	b._pbr("gutter earth", "brown_mud_02", 1.4, Color(.58, .53, .44), .98, .75)
	b._pbr("silt", "muddy_tracks", 2.4, Color(.40, .39, .33), .93, .7)
	b._pbr("spalled asphalt", "asphalt_02", .7, Color(.51, .50, .46), .98, 1.2)
	b._pbr("concrete chips", "concrete_wall_008", .55, Color(.60, .58, .51), 1.0, .8)
	b._pbr("brick fragments", "brick_wall_02", .8, Color(.53, .44, .32), 1.0, .7)
	b._pbr("rusted drain", "rusty_metal_02", .45, Color(.45, .42, .37), .92, .65)
	b._pbr("dead leaves", "leafy_grass", .35, Color(.48, .38, .24), 1.0, .65)
	for key: String in ["gutter earth", "silt"]:
		var earth := b._materials[key] as StandardMaterial3D
		earth.vertex_color_use_as_albedo = true
		earth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b._flat("fissure", Color(.012, .013, .012), 1.0)
	b._flat("crack shoulder", Color(.125, .119, .104), .98)
	var water := load("res://assets/baked/fields/materials/fields_puddle_water.tres").duplicate() as ShaderMaterial
	water.resource_name = "Street decay / shallow standing water"
	water.set_shader_parameter("water_color", Color(.016, .019, .017))
	water.set_shader_parameter("reflection_energy", .48)
	water.set_shader_parameter("glitter_energy", .15)
	water.set_shader_parameter("sparkle_energy", .0)
	water.set_shader_parameter("reflect_stars", false)
	water.set_shader_parameter("ripple_strength", .025)
	water.set_shader_parameter("wind_ripples", .04)
	b._materials["standing water"] = water

func _street(s: Array) -> void:
	var along_x: bool = s[0]
	var line: float = s[1]
	var start: float = s[2]
	var end: float = s[3]
	# Surface heights deliberately clear the asphalt, lane paint and raised pavement.
	var road_y := GROUND + .027
	var walk_y := GROUND + .127
	var step := start + rng.randf_range(1.0, 2.6)
	while step < end - 1.0:
		if _intersection(along_x, step):
			step += 1.5
			continue
		for side: float in [-1.0, 1.0]:
			var at := _at(along_x, line, step, side * 1.82, road_y)
			var length := rng.randf_range(.65, 2.2)
			var width := rng.randf_range(.11, .30)
			_patch(at, _size(along_x, length, width), "gutter earth", 14)
			stats.dirt_patches += 1
			if rng.randf() < .64:
				_patch(_at(along_x, line, step + .24, side * 2.88, walk_y), _size(along_x, length * .7, .095), "silt", 12)
				stats.dirt_patches += 1
			for i in rng.randi_range(3, 7):
				var drift := rng.randf_range(-length * .8, length * .8)
				var across := side * rng.randf_range(1.55, 1.92)
				var p := _at(along_x, line, step + drift, across, road_y + .005)
				if i % 3 == 0:
					_stone(p, rng.randf_range(.018, .055), "concrete chips")
				else:
					_leaf(p, rng.randf_range(.035, .10))
			if rng.randf() < .8:
				_plant(_at(along_x, line, step + .2, side * 1.96, road_y), rng.randf_range(.13, .30))
			if rng.randf() < .42:
				_plant(_at(along_x, line, step - .18, side * 2.92, walk_y), rng.randf_range(.16, .44))
		step += rng.randf_range(2.1, 4.7)
	# Branching faults are clusters spaced several metres apart, never a uniform grid.
	step = start + 3.2
	while step < end - 2.0:
		if not _intersection(along_x, step):
			var side := -1.0 if rng.randf() < .5 else 1.0
			var start_point := _at(along_x, line, step, side * rng.randf_range(.3, 1.0), road_y + .005)
			var direction := (Vector3(1, 0, side * .7) if along_x else Vector3(side * .7, 0, 1)).normalized()
			_fault(start_point, direction, rng.randf_range(.8, 1.55), rng.randf_range(.012, .027), 2)
			stats.crack_networks += 1
			var sidewalk := _at(along_x, line, step + .55, side * 2.48, walk_y + .002)
			var crosswalk := Vector3.FORWARD if along_x else Vector3.LEFT
			_fault(sidewalk, crosswalk, .39, .008, 1)
			_fault(sidewalk, -crosswalk, .39, .009, 1)
			stats.crack_networks += 1
			if rng.randf() < .6:
				_plant(sidewalk, rng.randf_range(.08, .19))
		step += rng.randf_range(6.0, 11.0)
	# Shallow irregular repairs and pockets of rainwater off the centre of the road.
	step = start + 5.5
	while step < end - 4.0:
		if not _intersection(along_x, step):
			var side := -1.0 if rng.randf() < .5 else 1.0
			var p := _at(along_x, line, step, side * 1.30, road_y + .003)
			var size := _size(along_x, rng.randf_range(.5, 1.2), rng.randf_range(.22, .43))
			_patch(p, size * 1.13, "spalled asphalt", 19)
			_patch(p + Vector3.UP * .002, size * .96, "silt", 19)
			if rng.randf() < .7:
				_patch(p + Vector3.UP * .004, size * .72, "standing water", 22)
				stats.puddles += 1
			for i in 8:
				var angle := TAU * i / 8.0
				_stone(p + Vector3(cos(angle) * size.x, .004, sin(angle) * size.y), rng.randf_range(.023, .063), "spalled asphalt")
		step += rng.randf_range(14.0, 21.0)
	# Drain covers sit on the carriageway side of the curb, so they do not float above steps.
	for offset in [8.4, 26.8, 43.6, 61.4]:
		var t: float = start + offset
		if t < end - 1.0 and not _intersection(along_x, t):
			_drain(_at(along_x, line, t, 1.70, road_y + .001), along_x)

func _lane() -> void:
	# Entrance lane: dirt and a few tufts against the boundary, clear of the gate's swing.
	for i in 10:
		var p := Vector3(13.5 + i * .43, GROUND + .024, 5.17 + rng.randf_range(-.05, .04))
		_patch(p, Vector2(.3, .10), "silt", 11)
		stats.dirt_patches += 1
		if i % 2 == 0:
			_plant(p, rng.randf_range(.12, .25))
		for j in 2:
			_stone(p + Vector3(rng.randf_range(-.2, .2), .002, rng.randf_range(-.1, .1)), .025, "concrete chips")

func _intersection(along_x: bool, t: float) -> bool:
	var crosses := [21.0, -19.0] if along_x else [18.0, 49.0]
	for c: float in crosses:
		if absf(t - c) < 4.2:
			return true
	return false

func _at(along_x: bool, line: float, t: float, cross: float, height: float) -> Vector3:
	return Vector3(t, height, line + cross) if along_x else Vector3(line + cross, height, t)

func _size(along_x: bool, length: float, width: float) -> Vector2:
	return Vector2(length, width) if along_x else Vector2(width, length)

func _triangle(a: Vector3, c: Vector3, d: Vector3, key: String, alpha := Vector3.ONE) -> void:
	var normal := (c - a).cross(d - a).normalized()
	# Godot front faces wind clockwise; normal calculation stays outward.
	var points := [a, d, c]
	var tool := b._builder(key)
	var opacity := [alpha.x, alpha.z, alpha.y]
	for index in 3:
		var p: Vector3 = points[index]
		tool.set_normal(normal)
		tool.set_uv(Vector2(p.x, p.z))
		tool.set_color(Color(1, 1, 1, opacity[index]))
		tool.add_vertex(p)
	b._stats.triangles_added += 1

func _patch(at: Vector3, radius: Vector2, key: String, segments: int) -> void:
	var outline: Array[Vector3] = []
	var phase := rng.randf() * TAU
	for i in segments:
		var angle := TAU * float(i) / segments
		var ragged := rng.randf_range(.79, 1.08) * (1.0 + .09 * sin(angle * 3.0 + phase))
		outline.append(at + Vector3(cos(angle) * radius.x * ragged, 0, sin(angle) * radius.y * ragged))
	var feather := key in ["gutter earth", "silt"]
	for i in segments:
		var next := (i + 1) % segments
		if feather:
			var inner_a := at.lerp(outline[i], .78)
			var inner_b := at.lerp(outline[next], .78)
			_triangle(at, inner_b, inner_a, key)
			_triangle(inner_a, inner_b, outline[next], key, Vector3(1, 1, 0))
			_triangle(inner_a, outline[next], outline[i], key, Vector3(1, 0, 0))
		else:
			_triangle(at, outline[next], outline[i], key)

func _fault(at: Vector3, direction: Vector3, length: float, width: float, branches: int) -> void:
	var p := at
	var count := maxi(6, int(length / .08))
	var normal := Vector3(-direction.z, 0, direction.x)
	for i in count:
		var progress := float(i) / count
		var q := p + direction * (length / count) + normal * rng.randf_range(-.05, .05)
		var thickness := width * rng.randf_range(.65, 1.25) * (1.0 - progress * .77)
		_strip(p, q, thickness * 1.9, "crack shoulder")
		_strip(p + Vector3.UP * .0015, q + Vector3.UP * .0015, thickness, "fissure")
		if branches > 0 and i == int(count * .53):
			var turn := rng.randf_range(.6, 1.0) * (-1.0 if rng.randf() < .5 else 1.0)
			_fault(p, direction.rotated(Vector3.UP, turn), length * .45, width * .56, branches - 1)
		p = q

func _strip(a: Vector3, c: Vector3, width: float, key: String) -> void:
	var side := (c - a).normalized().cross(Vector3.UP) * width * .5
	b._quad([a + side, c + side, c - side, a - side], Vector3.UP, key, Vector2(a.distance_to(c), width))

func _stone(at: Vector3, radius: float, key: String) -> void:
	# Angular chips with uneven silhouettes, not rounded spheres or scaled cubes.
	var ring: Array[Vector3] = []
	var count := rng.randi_range(4, 6)
	var height := radius * rng.randf_range(.45, 1.0)
	for i in count:
		var a := TAU * i / count
		ring.append(at + Vector3(cos(a) * radius * rng.randf_range(.65, 1.3), .001, sin(a) * radius * rng.randf_range(.65, 1.15)))
	var top := at + Vector3(radius * .13, height, radius * -.17)
	for i in count:
		_triangle(ring[i], top, ring[(i + 1) % count], key)
	stats.rubble += 1

func _leaf(at: Vector3, length: float) -> void:
	var basis := Basis(Vector3.UP, rng.randf() * TAU)
	var tip := at + basis * Vector3(0, .008, length)
	var stem := at + basis * Vector3(0, .003, -length * .65)
	var left := at + basis * Vector3(-length * .35, .002, .02)
	var right := at + basis * Vector3(length * .32, .002, .02)
	var ridge := at + Vector3.UP * .019
	_triangle(stem, left, ridge, "dead leaves")
	_triangle(left, tip, ridge, "dead leaves")
	_triangle(tip, right, ridge, "dead leaves")
	_triangle(right, stem, ridge, "dead leaves")

func _drain(at: Vector3, along_x: bool) -> void:
	var basis := Basis.IDENTITY if along_x else Basis(Vector3.UP, PI * .5)
	b._box("Drain recess", at, Vector3(.60, .01, .34), "fissure", false, basis)
	for x in [-.30, .30]:
		b._box("Drain rim", at + basis * Vector3(x, .008, 0), Vector3(.025, .016, .37), "rusted drain", false, basis)
	for z in [-.18, .18]:
		b._box("Drain rim", at + basis * Vector3(0, .008, z), Vector3(.62, .016, .025), "rusted drain", false, basis)
	for i in 9:
		b._box("Drain bar", at + basis * Vector3(-.25 + i * .063, .008, 0), Vector3(.024, .014, .34), "rusted drain", false, basis)
	for i in 5:
		_leaf(at + basis * Vector3(rng.randf_range(-.3, .3), .02, rng.randf_range(-.16, .16)), .07)
	stats.drains += 1

func _plant(at: Vector3, height: float) -> void:
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * height)
	plants.append(Transform3D(basis, at - Vector3.UP * .007))
	plant_colors.append(Color(rng.randf(), 1.0, rng.randf() * TAU, rng.randf_range(.15, .8)))
	stats.weed_clumps += 1

func _commit_plants() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Thin folded blades with varied lengths/lean; root width is only a few millimetres.
	for i in 9:
		var angle := i * 2.39996
		var side := Vector3(cos(angle), 0, sin(angle))
		var origin := side * rng.randf_range(.015, .16)
		var h := rng.randf_range(.45, 1.0)
		var bend := Vector3(-side.z, 0, side.x) * rng.randf_range(.12, .45)
		var pts := [origin - side * .035, origin + side * .035,
			origin + bend * .4 + Vector3.UP * h * .56 - side * .024,
			origin + bend * .4 + Vector3.UP * h * .56 + side * .024,
			origin + bend + Vector3.UP * h]
		var coords := [Vector2(0, 0), Vector2(1, 0), Vector2(0, .56), Vector2(1, .56), Vector2(.5, 1)]
		for index in [0, 2, 1, 1, 2, 3, 2, 4, 3]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(coords[index])
			tool.add_vertex(pts[index])
	var grass := ShaderMaterial.new()
	grass.resource_name = "Street decay / gutter weeds"
	grass.shader = GRASS_SHADER
	grass.set_shader_parameter("root_color", Color(.06, .075, .032))
	grass.set_shader_parameter("tip_color", Color(.26, .29, .12))
	grass.set_shader_parameter("ripe_color", Color(.36, .29, .16))
	grass.set_shader_parameter("sway", .006)
	grass.set_shader_parameter("gust_sway", .025)
	grass.set_shader_parameter("backlight", .28)
	# Partition by 16 m cells so the full town's grass never renders as one giant instance.
	var cells: Dictionary = {}
	for i in plants.size():
		var p := plants[i].origin
		var cell := Vector2i(floori(p.x / 16.0), floori(p.z / 16.0))
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(i)
	var mesh := tool.commit()
	for cell: Vector2i in cells:
		var ids: Array = cells[cell]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = mesh
		multi.instance_count = ids.size()
		for i in ids.size():
			multi.set_instance_transform(i, plants[ids[i]])
			multi.set_instance_custom_data(i, plant_colors[ids[i]])
		var node := MultiMeshInstance3D.new()
		node.name = "Weeds %d %d" % [cell.x, cell.y]
		node.multimesh = multi
		node.material_override = grass
		node.layers = 2
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 55.0
		node.visibility_range_end_margin = 8.0
		root.add_child(node)
