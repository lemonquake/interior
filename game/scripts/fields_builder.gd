class_name InteriorFieldsBuilder
extends RefCounted
## The moonlit rice fields north of the ghost town (0.7). Street B's asphalt ends past the last houses
## and a long dirt road (about half a kilometre, with wheel ruts, a grassy crown and puddles) winds through
## flooded paddies to a dead end under a giant tree. On the moon side an irrigation canal runs beside the
## road; halfway along, the road passes a pond with a little jetty. Paddies are mirrors (fallow), young
## rice or ripe rice; the near rice is real wind-swept geometry, far rice is drawn by the water shader.
## Coconut palms on the dikes, bamboo, talahib reeds, cattails, banana plants, an abandoned bahay kubo
## with a lantern, a scarecrow, leaning wooden power poles, fireflies over the pond.
##
## editor/bake_fields.gd bakes the result into res://scenes/fields/fields.tscn (runtime: scripts/fields.gd).
## Frame: street level y = -2.9 (GROUND); paddy water at WATER_Y; the town keeps z < 66.

const FieldsScript = preload("res://scripts/fields.gd")
const WATER_SHADER = preload("res://scripts/night_water.gdshader")
const BLADE_SHADER = preload("res://scripts/field_blades.gdshader")
const FIREFLY_SHADER = preload("res://scripts/firefly.gdshader")
const OUTDOOR_LAYER := 2
const GROUND := -2.9
const WATER_Y := GROUND - .42
const GRID_ORIGIN := Vector2(-150.0, 60.0)
const CELL_W := 28.0
const CELL_H := 22.0
## Water everywhere north of the town: x -150..180, z 66..640; west of x -14 the last lots reach z 80.
const FIELD_RECT := Rect2(-150.0, 66.0, 330.0, 574.0)
const TOWN_NOTCH := Rect2(-150.0, 66.0, 136.0, 14.0)
## Street B (x 21) leaves the town at z 55; the dirt road follows this spline to its dead end. The first
## point only shapes the start (sampling begins at the second, past street C's kerb).
const ROAD_POINTS := [Vector2(21, 40), Vector2(21, 54.5), Vector2(21, 66), Vector2(17, 110), Vector2(12, 150), Vector2(22, 185),
		Vector2(45, 215), Vector2(62, 250), Vector2(66, 290), Vector2(62, 340), Vector2(60, 390), Vector2(52, 440),
		Vector2(44, 490), Vector2(40, 530)]
const ROAD_HALF := 2.05
const VERGE := 3.1
## The walkable band: road plus verges. Invisible walls stand just outside it.
const WALK_HALF := 3.2
const RICE_REACH := 42.0
const CHUNK := 16.0
const POND_RADII := Vector2(15.0, 12.5)
const POND_OFFSET := 19.0
const MOON := InteriorNight.MOON_DIRECTION

var b: InteriorBalconyBuilder
var root: Node3D
var models: Node3D
var colliders: StaticBody3D
var rng := RandomNumberGenerator.new()
## Road samples (about 1 m apart): centre, unit tangent, moon-side normal, distance along.
var road: PackedVector2Array = []
var tangent: PackedVector2Array = []
var side: PackedVector2Array = []
var along: PackedFloat32Array = []
var _bucket: Dictionary = {}
var pond := Vector4.ZERO
var pond_index := 0
var hut := Vector2.ZERO
var jetty_index := 0
var dry: Array[Rect2] = []
var _stats := {"road_m": 0.0, "rice": 0, "grass": 0, "palms": 0, "dikes": 0, "fireflies": 0}
var _rice: Dictionary = {}
var _grass: Dictionary = {}
var audio_spots := {"frog": PackedVector3Array(), "owl": PackedVector3Array(), "gecko": PackedVector3Array(), "bamboo": PackedVector3Array()}

static func build(parent: Node3D) -> Dictionary:
	var f := InteriorFieldsBuilder.new()
	f.root = Node3D.new()
	f.root.name = "Fields"
	f.root.set_script(FieldsScript)
	parent.add_child(f.root)
	f.b = InteriorBalconyBuilder.new()
	f.b._root = f.root
	f.b._stats = {"triangles_added": 0, "static_batches": 0, "colliders": 0, "props": [], "features": [], "dynamic_props": 0}
	f.rng.seed = 20261007
	f.models = Node3D.new()
	f.models.name = "Models"
	f.root.add_child(f.models)
	f.colliders = StaticBody3D.new()
	f.colliders.name = "FieldsColliders"
	f.colliders.collision_layer = 2
	f.colliders.collision_mask = 5
	f.root.add_child(f.colliders)
	f._materials()
	f._sample_road()
	f._place_pond()
	f._road_mesh()
	f._town_bank()
	f._water()
	f._dikes()
	f._pond_details()
	f._jetty()
	f._puddles()
	f._hut()
	f._road_end()
	f._plants()
	f._poles()
	f._scarecrow()
	f._rice_and_grass()
	f._walls()
	f._fireflies()
	f._mist()
	f._commit()
	for key in f.audio_spots:
		f.root.set_meta("audio_" + key, f.audio_spots[key])
	f.root.set_meta("road_samples", f.road)
	f.root.set_meta("pond", f.pond)
	f._stats["road_m"] = snappedf(f.along[f.along.size() - 1], .1)
	f.root.set_meta("fields_stats", f._stats)
	f.b.free()
	print("INTERIOR_FIELDS_BUILT ", JSON.stringify(f._stats))
	return f._stats

# ---------------------------------------------------------------- shared helpers

## 0 fallow (open water), 1 young rice, 2 ripe rice. Must match cell_kind() in night_water.gdshader.
static func cell_kind(x: float, z: float) -> int:
	var i := floorf((x - GRID_ORIGIN.x) / CELL_W)
	var offset := fposmod(i * .6180339, 1.0) * CELL_H
	var j := floorf((z - GRID_ORIGIN.y - offset) / CELL_H)
	var k := fposmod(i * 7.0 + j * 13.0 + fposmod(i * j, 5.0), 10.0)
	if k < 3.0:
		return 0
	if k < 7.0 or k > 8.5:
		return 1
	return 2

static func in_water(p: Vector2) -> bool:
	return FIELD_RECT.has_point(p) and not TOWN_NOTCH.has_point(p)

func in_pond(p: Vector2, margin := 0.0) -> bool:
	if pond.z <= 0.0:
		return false
	var d := (p - Vector2(pond.x, pond.y)) / (Vector2(pond.z, pond.w) + Vector2.ONE * margin)
	return d.length_squared() < 1.0

func is_dry(p: Vector2) -> bool:
	for r in dry:
		if r.has_point(p):
			return true
	return false

func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)

## Nearest road sample within `limit` metres: [distance, index, signed offset toward the moon side].
func nearest(p: Vector2, limit := 64.0) -> Array:
	var cx := int(floorf(p.x / 8.0))
	var cz := int(floorf(p.y / 8.0))
	var best := INF
	var best_i := -1
	for ring in int(ceilf(limit / 8.0)) + 2:
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				for i: int in _bucket.get(Vector2i(cx + dx, cz + dz), []):
					var d := p.distance_squared_to(road[i])
					if d < best:
						best = d
						best_i = i
		if best_i >= 0 and sqrt(best) < (ring - .5) * 8.0:
			break
	if best_i < 0:
		return [INF, 0, 0.0]
	return [sqrt(best), best_i, (p - road[best_i]).dot(side[best_i])]

## Rough distance to the road from every sixth sample (for far placements).
func coarse_distance(p: Vector2) -> float:
	var best := INF
	for i in range(0, road.size(), 6):
		best = minf(best, p.distance_squared_to(road[i]))
	return sqrt(best)

## Spatial batch key for scattered field geometry (120 m tiles).
static func tile_key(p: Vector2, material: String) -> String:
	return "t%d_%d|%s" % [int(floorf(p.x / 120.0)), int(floorf(p.y / 120.0)), material]

func _materials() -> void:
	b._pbr("road", "muddy_tracks", 3.2, Color(.78, .74, .68), .85)
	b._pbr("verge", "withered_grass", 2.4, Color(.62, .7, .55))
	b._pbr("bank", "leafy_grass", 2.6, Color(.55, .62, .5))
	b._pbr("mud", "brown_mud_02", 2.5, Color(.55, .5, .45), .6)
	b._pbr("dike", "withered_grass", 2.0, Color(.58, .66, .5))
	b._pbr("planks", "dark_wooden_planks", 1.6, Color(.7, .64, .58))
	b._flat("post", Color(.16, .12, .09), .9)
	b._flat("lily", Color(.05, .11, .045), .45)
	b._flat("lily flower", Color(.85, .82, .9), .6)
	b._flat("wire", Color(.02, .02, .02), .7)
	b._image("sign", "res://assets/fields/sign_sirado.png", .85)
	var water := ShaderMaterial.new()
	water.resource_name = "Fields / paddy water"
	water.shader = WATER_SHADER
	InteriorNight.configure_sky(water)
	water.set_shader_parameter("ripple_a", _ripple_texture(11, .9))
	water.set_shader_parameter("ripple_b", _ripple_texture(23, 1.6))
	water.set_shader_parameter("grid_origin", GRID_ORIGIN)
	water.set_shader_parameter("cell_w", CELL_W)
	water.set_shader_parameter("cell_h", CELL_H)
	b._materials["water"] = water
	var puddle := water.duplicate() as ShaderMaterial
	puddle.resource_name = "Fields / puddle water"
	puddle.set_shader_parameter("paddies", false)
	puddle.set_shader_parameter("water_color", Color(.03, .025, .02))
	b._materials["puddle"] = puddle

func _ripple_texture(seed_value: int, frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = .012 * frequency
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.as_normal_map = true
	texture.bump_strength = 6.0
	texture.noise = noise
	return texture

# ---------------------------------------------------------------- road

func _sample_road() -> void:
	var pts := ROAD_POINTS
	for s in range(1, pts.size() - 1):
		var p0: Vector2 = pts[maxi(s - 1, 0)]
		var p1: Vector2 = pts[s]
		var p2: Vector2 = pts[s + 1]
		var p3: Vector2 = pts[mini(s + 2, pts.size() - 1)]
		var steps := maxi(2, int(ceilf(p1.distance_to(p2) / .9)))
		for k in steps:
			var t := float(k) / steps
			var t2 := t * t
			var t3 := t2 * t
			road.append(.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	road.append(pts[pts.size() - 1])
	var moon := Vector2(MOON.x, MOON.z).normalized()
	var total := 0.0
	for i in road.size():
		var a := road[maxi(i - 1, 0)]
		var c := road[mini(i + 1, road.size() - 1)]
		var t := (c - a).normalized()
		tangent.append(t)
		var l := Vector2(-t.y, t.x)
		side.append(l if l.dot(moon) >= 0.0 else -l)
		if i > 0:
			total += road[i].distance_to(road[i - 1])
		along.append(total)
		var key := Vector2i(int(floorf(road[i].x / 8.0)), int(floorf(road[i].y / 8.0)))
		if not _bucket.has(key):
			_bucket[key] = []
		_bucket[key].append(i)

## The pond lies on the moon side where the road runs across the moonlight (around (45, 215)).
func _place_pond() -> void:
	var best := 0
	var best_d := INF
	for i in road.size():
		var d := road[i].distance_to(Vector2(45, 215))
		if d < best_d:
			best_d = d
			best = i
	pond_index = best
	var centre := road[best] + side[best] * POND_OFFSET
	# Keep the whole shore clear of the road on its curves.
	for attempt in 12:
		var clear := true
		for i in road.size():
			if road[i].distance_to(centre) < POND_RADII.x + 4.6:
				clear = false
				break
		if clear:
			break
		centre += side[best] * 1.0
	pond = Vector4(centre.x, centre.y, POND_RADII.x, POND_RADII.y)
	(b._materials["water"] as ShaderMaterial).set_shader_parameter("pond", pond)

## Cross-section [offset toward the moon side, height above GROUND]. Strip k runs from point k to k+1.
const PROFILE := [[6.7, -.48], [6.15, -.15], [5.65, -.15], [5.35, -.75], [4.55, -.75], [4.15, -.47], [3.1, -.06],
		[2.05, 0.0], [.95, .015], [.8, -.025], [.62, .02], [0.0, .04], [-.62, .02], [-.8, -.025], [-.95, .015],
		[-2.05, 0.0], [-3.1, -.06], [-4.4, -.55]]
const STRIPS := ["dike", "dike", "mud", "mud", "mud", "bank", "verge", "road", "road", "road", "road", "road", "road",
		"road", "road", "verge", "bank"]
## Beside the pond the canal gives way to a grassy bank that slopes straight into the water.
const PROFILE_POND := [[6.7, -.75], [6.15, -.7], [5.65, -.66], [5.35, -.62], [4.55, -.55], [4.15, -.45], [3.1, -.06]]

func _profile_at(i: int) -> Array:
	var p: Vector2 = road[i]
	var result := []
	var pond_w := 0.0
	if pond.z > 0.0:
		var to_pond := road[i].distance_to(Vector2(pond.x, pond.y)) - POND_OFFSET
		pond_w = 1.0 - smoothstep(4.0, 14.0, absf(along[i] - along[pond_index]) - 6.0)
		pond_w *= 1.0 - smoothstep(4.0, 10.0, to_pond)
	# In town (z < 64) the road lies flat on the ground: no canal, no embankment.
	var town_w := 1.0 - smoothstep(60.0, 72.0, p.y)
	for k in PROFILE.size():
		var u: float = PROFILE[k][0]
		var y: float = PROFILE[k][1]
		if k < PROFILE_POND.size():
			y = lerpf(y, PROFILE_POND[k][1], pond_w)
		if town_w > 0.0:
			y = lerpf(y, maxf(y, -.004) if absf(u) > ROAD_HALF else y, town_w)
		result.append([u, y])
	return result

func _road_mesh() -> void:
	var profiles: Array = []
	for i in road.size():
		profiles.append(_profile_at(i))
	var walk_road := PackedVector3Array()
	var walk_verge := PackedVector3Array()
	for i in road.size() - 1:
		var chunk := int(along[i] / 60.0)
		for k in PROFILE.size() - 1:
			var a0 := _point(i, profiles[i][k])
			var a1 := _point(i, profiles[i][k + 1])
			var c0 := _point(i + 1, profiles[i + 1][k])
			var c1 := _point(i + 1, profiles[i + 1][k + 1])
			var key := "c%d|%s" % [chunk, STRIPS[k]]
			var tool := b._builder(key)
			var ua: float = profiles[i][k][0]
			var ub: float = profiles[i][k + 1][0]
			var va := along[i]
			var vc := along[i + 1]
			var tri := [[a0, Vector2(ua, va)], [c1, Vector2(ub, vc)], [a1, Vector2(ub, va)], [a0, Vector2(ua, va)], [c0, Vector2(ua, vc)], [c1, Vector2(ub, vc)]]
			# Same winding convention as InteriorRoomSurroundings._quad(): (a1 - a0) x (c0 - a0) faces out.
			var n := (a1 - a0).cross(c0 - a0).normalized()
			if n.y < 0.0:
				tri = [tri[0], tri[2], tri[1], tri[3], tri[5], tri[4]]
				n = -n
			for v: Array in tri:
				tool.set_normal(n)
				tool.set_uv(v[1])
				tool.add_vertex(v[0])
			var u_mid := (ua + ub) * .5
			if absf(u_mid) <= ROAD_HALF:
				for v: Array in tri:
					walk_road.append(v[0])
			elif absf(u_mid) <= WALK_HALF + .2:
				for v: Array in tri:
					walk_verge.append(v[0])
	_trimesh("Road surface", walk_road, "dirt")
	_trimesh("Road verges", walk_verge, "grass")
	b._feature("Fields: a %d m dirt road through moonlit rice paddies to a dead end" % int(along[along.size() - 1]))

func _point(i: int, uy: Array) -> Vector3:
	var p: Vector2 = road[i] + side[i] * float(uy[0])
	return Vector3(p.x, GROUND + float(uy[1]), p.y)

func _trimesh(label: String, faces: PackedVector3Array, surface: String) -> void:
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.name = label
	collision.shape = shape
	collision.set_meta("surface", surface)
	colliders.add_child(collision, true)

## Where the town's grass ends, a bank slopes down into the paddy water.
func _town_bank() -> void:
	for seg: Array in [[Vector2(-14, 66), Vector2(180, 66), Vector2(0, 1)], [Vector2(-150, 80), Vector2(-14, 80), Vector2(0, 1)],
			[Vector2(-14, 66), Vector2(-14, 80), Vector2(-1, 0)]]:
		var a: Vector2 = seg[0]
		var c: Vector2 = seg[1]
		var out: Vector2 = seg[2]
		var length := a.distance_to(c)
		var steps := int(ceilf(length / 4.0))
		for k in steps:
			var p0 := a.lerp(c, float(k) / steps)
			var p1 := a.lerp(c, float(k + 1) / steps)
			if float(nearest((p0 + p1) * .5, 12.0)[0]) < 9.0:
				continue
			var q0 := p0 - out * 1.2
			var q1 := p1 - out * 1.2
			var r0 := p0 + out * 2.2
			var r1 := p1 + out * 2.2
			var pts := [_v3(q0, GROUND - .01), _v3(q1, GROUND - .01), _v3(r1, WATER_Y - .15), _v3(r0, WATER_Y - .15)]
			var n: Vector3 = (pts[1] - pts[0]).cross(pts[3] - pts[0]).normalized()
			if n.y < 0.0:
				pts = [pts[1], pts[0], pts[3], pts[2]]
				n = -n
			b._quad(pts, n, tile_key(p0, "bank"), Vector2(length / steps, 3.4))

# ---------------------------------------------------------------- water, dikes, pond

func _water() -> void:
	var water_root := Node3D.new()
	water_root.name = "Water"
	root.add_child(water_root)
	for rect: Rect2 in [Rect2(-150, 80, 136, 560), Rect2(-14, 66, 194, 574)]:
		var x := rect.position.x
		while x < rect.end.x - .01:
			var z := rect.position.y
			var w := minf(60.0, rect.end.x - x)
			while z < rect.end.y - .01:
				var h := minf(60.0, rect.end.y - z)
				var mesh := PlaneMesh.new()
				mesh.size = Vector2(w, h)
				var tile := MeshInstance3D.new()
				tile.name = "Paddy water %d %d" % [int(x), int(z)]
				tile.mesh = mesh
				tile.material_override = b._materials["water"]
				tile.layers = OUTDOOR_LAYER
				tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				tile.visibility_range_end = 420.0
				water_root.add_child(tile, true)
				tile.position = Vector3(x + w * .5, WATER_Y, z + h * .5)
				z += h
			x += w

## Earthen dikes (pilapil) on the paddy grid, cut where the road, the canal or the pond pass.
func _dikes() -> void:
	var columns := int(ceilf(FIELD_RECT.size.x / CELL_W))
	for i in columns + 1:
		var x := GRID_ORIGIN.x + i * CELL_W
		_dike_line(Vector2(x, FIELD_RECT.position.y), Vector2(x, FIELD_RECT.end.y))
	for i in columns:
		var x0 := GRID_ORIGIN.x + i * CELL_W
		var offset := fposmod(i * .6180339, 1.0) * CELL_H
		var z := GRID_ORIGIN.y + offset
		while z < FIELD_RECT.end.y:
			if z > FIELD_RECT.position.y:
				_dike_line(Vector2(x0, z), Vector2(x0 + CELL_W, z))
			z += CELL_H

func _dike_clear(p: Vector2) -> bool:
	if not in_water(p) or in_pond(p, 2.0) or is_dry(p):
		return false
	var near := nearest(p, 8.0)
	var reach := 6.6 if float(near[2]) > 0.0 else 4.6
	return float(near[0]) > reach

func _dike_line(a: Vector2, c: Vector2) -> void:
	var length := a.distance_to(c)
	var steps := int(ceilf(length / 2.0))
	var run_start := -1
	for k in steps + 1:
		var p := a.lerp(c, float(k) / steps)
		var ok := k < steps and _dike_clear(a.lerp(c, (k + .5) / steps))
		if ok and run_start < 0:
			run_start = k
		elif not ok and run_start >= 0:
			_dike(a.lerp(c, float(run_start) / steps), p)
			run_start = -1

func _dike(a: Vector2, c: Vector2) -> void:
	var dir := (c - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	var top := GROUND - .16 + rng.randf_range(-.03, .03)
	var base := WATER_Y - .12
	var chunk_key := tile_key((a + c) * .5, "dike")
	var length := a.distance_to(c)
	var faces := [
		[_v3(a + n * .45, base), _v3(c + n * .45, base), _v3(c + n * .22, top), _v3(a + n * .22, top)],
		[_v3(a + n * .22, top), _v3(c + n * .22, top), _v3(c - n * .22, top), _v3(a - n * .22, top)],
		[_v3(a - n * .22, top), _v3(c - n * .22, top), _v3(c - n * .45, base), _v3(a - n * .45, base)],
	]
	for pts: Array in faces:
		var normal: Vector3 = (pts[1] - pts[0]).cross(pts[3] - pts[0]).normalized()
		if normal.y < 0.0:
			pts = [pts[1], pts[0], pts[3], pts[2]]
			normal = -normal
		b._quad(pts, normal, chunk_key, Vector2(length, .9))
	_stats.dikes += 1

func _pond_details() -> void:
	var centre := Vector2(pond.x, pond.y)
	var road_dir := (road[pond_index] - centre).normalized()
	# A soft grassy shore ring, except toward the road where the road bank meets the water.
	var segments := 40
	for k in segments:
		var a0 := TAU * k / segments
		var a1 := TAU * (k + 1) / segments
		var mid := Vector2(cos((a0 + a1) * .5), sin((a0 + a1) * .5))
		if mid.dot(road_dir) > .55:
			continue
		var inner0 := centre + Vector2(cos(a0) * pond.z, sin(a0) * pond.w)
		var inner1 := centre + Vector2(cos(a1) * pond.z, sin(a1) * pond.w)
		var outer0 := centre + Vector2(cos(a0) * (pond.z + 2.4), sin(a0) * (pond.w + 2.4))
		var outer1 := centre + Vector2(cos(a1) * (pond.z + 2.4), sin(a1) * (pond.w + 2.4))
		var pts := [_v3(inner0, WATER_Y - .1), _v3(inner1, WATER_Y - .1), _v3(outer1, GROUND - .2), _v3(outer0, GROUND - .2)]
		var n: Vector3 = (pts[1] - pts[0]).cross(pts[3] - pts[0]).normalized()
		if n.y < 0.0:
			pts = [pts[1], pts[0], pts[3], pts[2]]
			n = -n
		b._quad(pts, n, "c%d|bank" % int(along[pond_index] / 60.0), Vector2(inner0.distance_to(inner1), 2.4))
		var flat := [_v3(outer0, GROUND - .2), _v3(outer1, GROUND - .2), _v3(outer1 + mid * 1.6, WATER_Y - .1), _v3(outer0 + mid * 1.6, WATER_Y - .1)]
		n = (flat[1] - flat[0]).cross(flat[3] - flat[0]).normalized()
		if n.y < 0.0:
			flat = [flat[1], flat[0], flat[3], flat[2]]
			n = -n
		b._quad(flat, n, "c%d|bank" % int(along[pond_index] / 60.0), Vector2(outer0.distance_to(outer1), 1.6))
		if rng.randf() < .7:
			var at := centre + Vector2(cos(a0) * (pond.z + .3), sin(a0) * (pond.w + .3))
			_model("fields/cattails", _v3(at, WATER_Y - .05), rng.randf_range(0, 360), rng.randf_range(.8, 1.25), 90.0)
	# Lily pads in four drifts, each a notched disc.
	for group in 4:
		var angle := rng.randf_range(0, TAU)
		var spot := centre + Vector2(cos(angle) * pond.z * .55, sin(angle) * pond.w * .55)
		for k in rng.randi_range(10, 18):
			var p := spot + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.0, 2.0))
			if not in_pond(p, -1.0):
				continue
			_lily(p, rng.randf_range(.2, .42), rng.randf_range(0, TAU), rng.randf() < .12)
	for k in 3:
		var a := rng.randf_range(0, TAU)
		if Vector2(cos(a), sin(a)).dot(road_dir) > .4:
			a += PI
		var at := centre + Vector2(cos(a) * (pond.z + 1.6), sin(a) * (pond.w + 1.6))
		_model("fields/rock_moss_set" if k == 0 else "fields/boulder", _v3(at, WATER_Y - .25), rng.randf_range(0, 360), rng.randf_range(.5, .9), 160.0)
	var far_shore := centre - road_dir * (pond.w + 4.0)
	_islet(far_shore, 4.5)
	_model("nature/island_tree_01", _v3(far_shore, GROUND - .3), 40.0, 1.5, 0.0).set_meta("tree", true)
	for k in 3:
		_model("nature/banana_plant", _v3(far_shore + Vector2(rng.randf_range(-6, 6), rng.randf_range(-3, 3)), GROUND - .3), rng.randf_range(0, 360), rng.randf_range(.8, 1.1), 0.0).set_meta("tree", true)
	audio_spots.frog.append(_v3(centre, WATER_Y))
	audio_spots.owl.append(_v3(far_shore, GROUND + 9.0))

func _lily(p: Vector2, radius: float, yaw: float, flower: bool) -> void:
	var tool := b._builder("c%d|lily" % int(along[pond_index] / 60.0))
	var y := WATER_Y + .006
	var steps := 14
	for k in steps:
		var a0 := yaw + .35 + (TAU - .45) * k / steps
		var a1 := yaw + .35 + (TAU - .45) * (k + 1) / steps
		for q: Vector2 in [Vector2.ZERO, Vector2(cos(a0), sin(a0)) * radius, Vector2(cos(a1), sin(a1)) * radius]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(q)
			tool.add_vertex(Vector3(p.x + q.x, y, p.y + q.y))
	if flower:
		b._sphere(Vector3(p.x, y + .04, p.y), Vector3(.1, .07, .1), "c%d|lily flower" % int(along[pond_index] / 60.0), 6)

## A plank jetty from the road verge out over the pond, the one spot to stand at the moon's reflection.
func _jetty() -> void:
	jetty_index = pond_index
	var base := road[jetty_index]
	var out := side[jetty_index]
	var across := Vector2(-out.y, out.x)
	var deck_y := GROUND - .06
	var start := 2.6
	var to_centre := Vector2(pond.x, pond.y) - base
	var dir_local := out / Vector2(pond.z, pond.w)
	var radius_along := 1.0 / maxf(dir_local.length(), .001)
	var finish := to_centre.length() - radius_along + 4.5
	var length := finish - start
	var centre := base + out * (start + length * .5)
	var basis := Basis(Vector3(across.x, 0, across.y), Vector3.UP, Vector3(out.x, 0, out.y))
	var key := "c%d|planks" % int(along[jetty_index] / 60.0)
	var planks := int(length / .24)
	for k in planks:
		var at := base + out * (start + (k + .5) * length / planks)
		b._box("Jetty plank", _v3(at, deck_y - .025 + rng.randf_range(-.006, .006)), Vector3(1.35, .05, length / planks - .025), key, false, basis * Basis(Vector3.UP, rng.randf_range(-.02, .02)))
	for k in 4:
		for s in [-1.0, 1.0]:
			var at: Vector2 = base + out * (start + .3 + k * (length - .6) / 3.0) + across * s * .6
			b._rod(_v3(at, WATER_Y - .6), _v3(at, deck_y + (.5 if k == 3 else -.02)), .06, "c%d|post" % int(along[jetty_index] / 60.0), 6)
	var collision := CollisionShape3D.new()
	collision.name = "Jetty"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.45, .2, length + .3)
	collision.shape = shape
	collision.set_meta("surface", "wood")
	colliders.add_child(collision, true)
	collision.transform = Transform3D(basis, _v3(centre, deck_y - .1))
	# Low rails at the far end so the walk out ends at the water.
	_wall_box("Jetty end", _v3(base + out * (finish + .1), GROUND), Vector3(1.6, 2.4, .2), basis)
	for s in [-1.0, 1.0]:
		_wall_box("Jetty side", _v3(centre + across * s * .8, GROUND), Vector3(.12, 2.4, length - .6), basis)

func _puddles() -> void:
	var s := 30.0
	while s < along[along.size() - 1] - 20.0:
		var i := _index_at(s)
		var ruts := [-.8, .8]
		var u: float = ruts[rng.randi_range(0, 1)] + rng.randf_range(-.15, .15)
		var p := road[i] + side[i] * u
		var length := rng.randf_range(.6, 1.9)
		var width := rng.randf_range(.35, .62)
		var t := tangent[i]
		var n := side[i]
		var y := GROUND - .012
		var pts := [_v3(p - t * length * .5 - n * width * .5, y), _v3(p + t * length * .5 - n * width * .5, y), _v3(p + t * length * .5 + n * width * .5, y), _v3(p - t * length * .5 + n * width * .5, y)]
		var normal: Vector3 = (pts[1] - pts[0]).cross(pts[3] - pts[0]).normalized()
		if normal.y < 0.0:
			pts = [pts[1], pts[0], pts[3], pts[2]]
		b._quad(pts, Vector3.UP, "c%d|puddle" % int(s / 60.0), Vector2(length, width))
		s += rng.randf_range(14.0, 34.0)

func _index_at(distance: float) -> int:
	var lo := 0
	var hi := along.size() - 1
	while lo < hi:
		var mid := (lo + hi) / 2
		if along[mid] < distance:
			lo = mid + 1
		else:
			hi = mid
	return lo

# ---------------------------------------------------------------- places

## An abandoned bahay kubo on a dry patch off the far side of the road, a lantern still burning.
func _hut() -> void:
	var i := _nearest_index(Vector2(12, 150))
	hut = road[i] - side[i] * 21.0
	var yard := Rect2(hut - Vector2(7, 7), Vector2(14, 14))
	dry.append(yard)
	b._box("Hut yard", _v3(hut, GROUND - .5), Vector3(14, .7, 14), "c%d|bank" % int(along[i] / 60.0))
	b._box("Hut yard top", _v3(hut, GROUND - .14), Vector3(13.2, .02, 13.2), "c%d|verge" % int(along[i] / 60.0))
	var face := rad_to_deg(atan2(side[i].x, side[i].y))
	var kubo := _model("fields/bahay_kubo", _v3(hut, GROUND - .15), face, 1.0, 0.0)
	kubo.name = "BahayKubo"
	# Lantern hanging by the door, facing the road.
	var door := hut + side[i] * 3.4
	var lantern := _model("fields/lantern", _v3(door, GROUND + 1.55), face, 1.1, 120.0)
	lantern.name = "HutLantern"
	var light := OmniLight3D.new()
	light.name = "HutLanternLight"
	light.light_color = Color(1.0, .6, .28)
	light.light_energy = 1.1
	light.omni_range = 8.0
	light.omni_attenuation = 1.4
	light.light_cull_mask = OUTDOOR_LAYER
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 90.0
	light.distance_fade_length = 30.0
	light.set_meta("flicker", true)
	root.add_child(light)
	light.position = _v3(door, GROUND + 1.75)
	var glow := MeshInstance3D.new()
	glow.name = "HutLanternFlame"
	var sphere := SphereMesh.new()
	sphere.radius = .045
	sphere.height = .09
	glow.mesh = sphere
	var flame := StandardMaterial3D.new()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.albedo_color = Color(1.0, .72, .35)
	flame.emission_enabled = true
	flame.emission = Color(1.0, .6, .25)
	flame.emission_energy_multiplier = 6.0
	glow.material_override = flame
	glow.layers = OUTDOOR_LAYER
	root.add_child(glow)
	glow.position = _v3(door, GROUND + 1.72)
	for k in 5:
		var a := rng.randf_range(0, TAU)
		_model("nature/banana_plant" if k % 2 == 0 else "nature/banana_small", _v3(hut + Vector2(cos(a), sin(a)) * rng.randf_range(4.5, 6.2), GROUND - .15), rng.randf_range(0, 360), rng.randf_range(.8, 1.1), 0.0).set_meta("tree", true)
	_model("fields/bamboo_clump", _v3(hut - side[i] * 6.0 + tangent[i] * 4.0, GROUND - .15), rng.randf_range(0, 360), 1.05, 0.0).set_meta("tree", true)
	_model("fields/bucket", _v3(door + tangent[i] * 1.6, GROUND - .14), rng.randf_range(0, 360), 1.0, 60.0)
	_model("nature/tree_small_02", _v3(hut + tangent[i] * 6.0 - side[i] * 2.0, GROUND - .15), rng.randf_range(0, 360), 1.4, 0.0).set_meta("tree", true)
	audio_spots.gecko.append(_v3(hut, GROUND + 2.5))
	audio_spots.bamboo.append(_v3(hut - side[i] * 6.0 + tangent[i] * 4.0, GROUND + 4.0))
	root.set_meta("hut", _v3(hut, GROUND))

func _nearest_index(p: Vector2) -> int:
	return int(nearest(p, 64.0)[1])

## The road ends at a fallen tree and a barrier; beyond, a giant tree stands black against the moon.
func _road_end() -> void:
	var last := road.size() - 1
	var end := road[last]
	var t := tangent[last]
	var n := side[last]
	var key := "c%d|" % int(along[last] / 60.0)
	# The trunk model lies along its local X: turn X onto the road's cross direction.
	var across_yaw := rad_to_deg(atan2(-n.y, n.x))
	_model("fields/fallen_trunk", _v3(end + t * 1.5, GROUND - .05), across_yaw + rng.randf_range(-8, 8), 2.7, 0.0)
	# Barrier: two posts and a board with the sign, a little before the trunk.
	var bar := end - t * 1.2
	for s in [-1.0, 1.0]:
		b._rod(_v3(bar + n * s * 1.25, GROUND - .3), _v3(bar + n * s * 1.25, GROUND + 1.25), .06, key + "post", 6)
	var board_basis := Basis(Vector3(n.x, 0, n.y), Vector3.UP, Vector3(-t.x, 0, -t.y))
	b._box("Barrier rail", _v3(bar, GROUND + .55), Vector3(2.8, .12, .05), key + "planks", false, board_basis)
	var sign_basis := board_basis * Basis(Vector3.FORWARD, .05)
	var c := _v3(bar, GROUND + 1.0) - Vector3(t.x, 0, t.y) * .04
	var u := sign_basis.x * .8
	var v := sign_basis.y * .3
	var normal := sign_basis.z
	b._quad([c - u - v, c + u - v, c + u + v, c - u + v], normal, key + "sign", Vector2(1, 1))
	b._quad([c + u - v - normal * .02, c - u - v - normal * .02, c - u + v - normal * .02, c + u + v - normal * .02], -normal, key + "planks", Vector2(1.6, .6))
	# The dry knoll of the giant tree, in the moon's direction from the barrier.
	var moon := Vector2(MOON.x, MOON.z).normalized()
	var tree := end + moon * 26.0
	dry.append(Rect2(tree - Vector2(9, 9), Vector2(18, 18)))
	dry.append(Rect2(end - Vector2(6, 6), Vector2(12, 12)))
	b._box("Knoll", _v3(tree, GROUND - .45), Vector3(18, .8, 18), key + "bank")
	b._box("Road end ground", _v3(end + t * 4.0, GROUND - .45), Vector3(12, .8, 12), key + "bank")
	var giant := _model("nature/island_tree_01", _v3(tree, GROUND - .05), 200.0, 4.2, 0.0)
	giant.name = "GiantTree"
	giant.set_meta("tree", true)
	_model("fields/root_cluster", _v3(tree + moon * -2.5, GROUND - .1), 30.0, 1.6, 120.0)
	_model("fields/dead_trunk_b", _v3(tree + n * 5.0, GROUND - .08), 75.0, 1.4, 120.0)
	_model("fields/tree_stump", _v3(end + t * 4.0 - n * 3.0, GROUND - .06), 10.0, 1.2, 80.0)
	# A dark wall of bamboo beyond the dead end.
	for k in 7:
		var at := end + t * rng.randf_range(7.0, 14.0) + n * (k - 3) * 4.2 + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if at.distance_to(tree) < 8.0:
			continue
		dry.append(Rect2(at - Vector2(3, 3), Vector2(6, 6)))
		b._box("Bamboo knoll", _v3(at, GROUND - .5), Vector3(6, .7, 6), key + "bank")
		_model("fields/bamboo_clump", _v3(at, GROUND - .15), rng.randf_range(0, 360), rng.randf_range(.95, 1.3), 0.0).set_meta("tree", true)
		audio_spots.bamboo.append(_v3(at, GROUND + 4.0))
	audio_spots.owl.append(_v3(tree, GROUND + 14.0))
	root.set_meta("road_end", _v3(end, GROUND))
	root.set_meta("giant_tree", _v3(tree, GROUND))

# ---------------------------------------------------------------- planting

func _model(path: String, at: Vector3, yaw: float, scale: float, fade: float) -> Node3D:
	var node := InteriorModelKit.place(models, path, at, yaw, scale, "none")
	node.set_meta("fade", fade)
	return node

func _plants() -> void:
	var total := along[along.size() - 1]
	# Coconut palms on dikes near the road, in twos and threes; banana plants and bamboo on the far side.
	var s := 12.0
	while s < total - 25.0:
		var i := _index_at(s)
		var near_side := -1.0 if rng.randf() < .65 else 1.0
		var offset := rng.randf_range(7.5, 18.0) * near_side
		var base := road[i] + side[i] * offset
		var cluster := rng.randi_range(1, 3)
		for k in cluster:
			var p := base + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
			if in_pond(p, 3.0) or not in_water(p) or float(nearest(p, 8.0)[0]) < 6.5:
				continue
			_islet(p, 1.6)
			var kind := "palm_coconut_a" if rng.randf() < .55 else "palm_coconut_b"
			var palm := _model("nature/" + kind, _v3(p, GROUND - .16), rng.randf_range(0, 360), rng.randf_range(.85, 1.25) if kind == "palm_coconut_a" else rng.randf_range(.75, 1.05), 0.0)
			palm.set_meta("tree", true)
			_stats.palms += 1
		s += rng.randf_range(26.0, 48.0)
	# Bamboo clumps on the far bank every so often.
	s = 40.0
	while s < total - 40.0:
		var i := _index_at(s)
		var p := road[i] - side[i] * rng.randf_range(5.2, 7.0)
		if not in_pond(p, 3.0) and not is_dry(p):
			_islet(p, 2.6)
			_model("fields/bamboo_clump", _v3(p, GROUND - .2), rng.randf_range(0, 360), rng.randf_range(.85, 1.15), 0.0).set_meta("tree", true)
			audio_spots.bamboo.append(_v3(p, GROUND + 4.0))
		s += rng.randf_range(55.0, 95.0)
	# Talahib (wild sugarcane grass) along the far bank and the canal dike; cattails in the canal.
	s = 6.0
	while s < total - 10.0:
		var i := _index_at(s)
		var yaw := rad_to_deg(atan2(tangent[i].x, tangent[i].y)) + 90.0
		if rng.randf() < .6:
			_model("fields/reeds", _v3(road[i] - side[i] * 4.15, WATER_Y - .05), yaw + rng.randf_range(-12, 12), rng.randf_range(.6, .95), 110.0)
		var canal := road[i] + side[i] * 6.25
		if not in_pond(canal, 2.0) and canal.y > 70.0 and rng.randf() < .55:
			_model("fields/reeds", _v3(canal, GROUND - .17), yaw + rng.randf_range(-10, 10), rng.randf_range(.5, .8), 110.0)
		var reed := road[i] + side[i] * rng.randf_range(4.4, 5.3)
		if not in_pond(reed, 2.0) and reed.y > 70.0:
			_model("fields/cattails", _v3(reed, WATER_Y - .3), rng.randf_range(0, 360), rng.randf_range(.8, 1.2), 90.0)
		if rng.randf() < .45:
			var verge_side := 1.0 if rng.randf() < .5 else -1.0
			_model("fields/fern", _v3(road[i] + side[i] * verge_side * rng.randf_range(2.6, 3.0), GROUND - .04), rng.randf_range(0, 360), rng.randf_range(.45, .7), 70.0)
		s += rng.randf_range(9.0, 22.0)
	# Silhouettes: palms scattered over the far paddies, standing on dike corners.
	var placed := 0
	var tries := 0
	while placed < 55 and tries < 600:
		tries += 1
		var col := rng.randi_range(0, int(FIELD_RECT.size.x / CELL_W))
		var x := GRID_ORIGIN.x + col * CELL_W
		var z := rng.randf_range(FIELD_RECT.position.y + 20.0, FIELD_RECT.end.y - 10.0)
		var p := Vector2(x, z)
		var d := coarse_distance(p)
		if d < 25.0 or d > 230.0 or not in_water(p) or in_pond(p, 6.0) or is_dry(p):
			continue
		_islet(p, 1.4)
		var kind := "palm_coconut_a" if rng.randf() < .5 else "palm_coconut_b"
		_model("nature/" + kind, _v3(p, GROUND - .16), rng.randf_range(0, 360), rng.randf_range(.9, 1.35), 0.0).set_meta("tree", true)
		placed += 1
		_stats.palms += 1
		if rng.randf() < .3:
			audio_spots.owl.append(_v3(p, GROUND + 12.0))
	# A few broad trees (mango-like) on islets well off the road.
	for k in 6:
		var i := _index_at(rng.randf_range(60.0, total - 60.0))
		var p := road[i] - side[i] * rng.randf_range(28.0, 60.0)
		if not in_water(p) or in_pond(p, 6.0):
			continue
		_islet(p, 4.0)
		_model("nature/" + ["island_tree_02", "island_tree_01", "tree_small_02"][k % 3], _v3(p, GROUND - .2), rng.randf_range(0, 360), rng.randf_range(1.3, 1.8), 0.0).set_meta("tree", true)
		audio_spots.owl.append(_v3(p, GROUND + 8.0))
	# Frogs live in the paddies on both sides; a few banana plants mark the town edge.
	s = 20.0
	while s < total:
		var i := _index_at(s)
		audio_spots.frog.append(_v3(road[i] + side[i] * rng.randf_range(-35.0, 35.0), WATER_Y))
		s += 35.0
	for k in 4:
		var p := Vector2(rng.randf_range(4.0, 16.0) if k < 2 else rng.randf_range(26.0, 40.0), rng.randf_range(58.0, 64.0))
		_model("nature/banana_plant", _v3(p, GROUND), rng.randf_range(0, 360), rng.randf_range(.8, 1.1), 0.0).set_meta("tree", true)

## A small raised clump of earth for a tree standing in the paddies.
func _islet(p: Vector2, radius: float) -> void:
	dry.append(Rect2(p - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))
	var key := tile_key(p, "dike")
	var steps := 8
	for k in steps:
		var a0 := TAU * k / steps
		var a1 := TAU * (k + 1) / steps
		var top0 := p + Vector2(cos(a0), sin(a0)) * radius * .55
		var top1 := p + Vector2(cos(a1), sin(a1)) * radius * .55
		var low0 := p + Vector2(cos(a0), sin(a0)) * radius
		var low1 := p + Vector2(cos(a1), sin(a1)) * radius
		var pts := [_v3(low0, WATER_Y - .1), _v3(low1, WATER_Y - .1), _v3(top1, GROUND - .16), _v3(top0, GROUND - .16)]
		var n: Vector3 = (pts[1] - pts[0]).cross(pts[3] - pts[0]).normalized()
		if n.y < 0.0:
			pts = [pts[1], pts[0], pts[3], pts[2]]
			n = -n
		b._quad(pts, n, key, Vector2(radius, .8))
		var tool := b._builder(key)
		for q: Vector2 in [p, top1, top0] if (Vector3(top1.x - p.x, 0, top1.y - p.y).cross(Vector3(top0.x - p.x, 0, top0.y - p.y)).y < 0.0) else [p, top0, top1]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(q)
			tool.add_vertex(_v3(q, GROUND - .16))

## Wooden power poles lean along the far side of the road, wires sagging between them.
func _poles() -> void:
	var total := along[along.size() - 1]
	var previous: Array = []
	var s := 24.0
	while s < total - 12.0:
		var i := _index_at(s)
		var p := road[i] - side[i] * 3.65
		var yaw := rad_to_deg(atan2(tangent[i].x, tangent[i].y))
		var lean := Vector3(rng.randf_range(-3.5, 3.5), 0, rng.randf_range(-2.5, 2.5))
		if s > total - 70.0 and previous.size() > 0 and rng.randf() < .7:
			lean.x = 14.0  # the last ones sag toward the paddies
		var pole := InteriorModelKit.place(models, "fields/power_pole", _v3(p, GROUND - .25), yaw + 90.0, 1.0, "none", lean)
		pole.set_meta("fade", 260.0)
		var top := pole.global_transform * Vector3(0, 5.95, 0) if pole.is_inside_tree() else _v3(p, GROUND + 5.7)
		var arm := Vector3(side[i].x, 0, side[i].y) * .5
		var tips := [top + arm, top - arm]
		if previous.size() == 2:
			for k in 2:
				var a: Vector3 = previous[k]
				var c: Vector3 = tips[k]
				var pts: Array = []
				for q in 11:
					var t := float(q) / 10
					pts.append(a.lerp(c, t) + Vector3.DOWN * .75 * 4.0 * t * (1 - t))
				b._tube(pts, .012, "c%d|wire" % int(s / 60.0), 4)
		previous = tips
		s += rng.randf_range(34.0, 42.0)

func _scarecrow() -> void:
	var i := _nearest_index(Vector2(66, 300))
	var p := road[i] - side[i] * 11.0
	_islet(p, 1.0)
	var face := rad_to_deg(atan2(side[i].x, side[i].y))
	var crow := _model("fields/scarecrow", _v3(p, GROUND - .16), face, 1.05, 0.0)
	crow.name = "Scarecrow"
	crow.add_to_group("scarecrow", true)

# ---------------------------------------------------------------- rice and grass

func _blade_clump(blades: int, panicles: int, width: float, droop: float, seed_value: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in blades + panicles:
		var panicle := k >= blades
		var angle := TAU * k / blades + r.randf_range(-.3, .3)
		var out := Vector3(cos(angle), 0, sin(angle))
		var lean := r.randf_range(.12, .32) if not panicle else r.randf_range(.05, .15)
		var height := r.randf_range(.75, 1.0) if not panicle else r.randf_range(.92, 1.05)
		var w := width * r.randf_range(.8, 1.2) * (.6 if panicle else 1.0)
		var across := out.cross(Vector3.UP).normalized()
		var segments := 4
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for sgm in segments + 1:
			var t := float(sgm) / segments
			var bend := lean * t + (droop if not panicle else droop * 2.2) * t * t
			var centre := out * bend * height + Vector3.UP * height * (t - (droop * .6 if panicle else droop * .35) * t * t)
			var half := w * .5 * (1.0 - t * .85)
			var l := centre - across * half
			var rr := centre + across * half
			if sgm > 0:
				var n := (rr - prev_l).cross(l - prev_l).normalized()
				if n.dot(out) < 0.0:
					n = -n
				var t0 := float(sgm - 1) / segments
				for v: Array in [[prev_l, t0], [prev_r, t0], [rr, t], [prev_l, t0], [rr, t], [l, t]]:
					tool.set_normal(n.lerp(Vector3.UP, .35).normalized())
					tool.set_uv(Vector2(0.0, v[1]))
					tool.add_vertex(v[0])
			prev_l = l
			prev_r = rr
	tool.index()
	return tool.commit()

func _rice_and_grass() -> void:
	var meshes := {
		"young": _blade_clump(8, 0, .022, .1, 1),
		"ripe": _blade_clump(9, 4, .024, .22, 2),
		"grass": _blade_clump(11, 0, .014, .18, 3),
	}
	var columns := int(ceilf(FIELD_RECT.size.x / CELL_W))
	for i in columns:
		var x0 := GRID_ORIGIN.x + i * CELL_W
		var offset := fposmod(i * .6180339, 1.0) * CELL_H
		var z0 := GRID_ORIGIN.y + offset - CELL_H
		while z0 < FIELD_RECT.end.y:
			var cell := Rect2(x0, z0, CELL_W, CELL_H)
			z0 += CELL_H
			var centre := cell.get_center()
			if float(nearest(centre, RICE_REACH + 28.0)[0]) > RICE_REACH + 20.0:
				continue
			var kind := cell_kind(centre.x, centre.y)
			if kind == 0:
				continue
			var spacing := .36 if kind == 1 else .32
			var x := cell.position.x + .55
			while x < cell.end.x - .55:
				var z := cell.position.y + .55
				while z < cell.end.y - .55:
					var p := Vector2(x + rng.randf_range(-.05, .05), z + rng.randf_range(-.05, .05))
					z += spacing
					if not in_water(p) or in_pond(p, 1.5) or is_dry(p):
						continue
					var near := nearest(p, RICE_REACH + 2.0)
					var d := float(near[0])
					if d > RICE_REACH or d < (7.0 if float(near[2]) > 0.0 else 4.7):
						continue
					var height := (rng.randf_range(.48, .66) if kind == 1 else rng.randf_range(.9, 1.08))
					var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * height), _v3(p, WATER_Y - .03))
					var custom := Color(rng.randf(), height, rng.randf() * 6.0, 0.0 if kind == 1 else rng.randf_range(.55, .95))
					_add_instance(_rice, "young" if kind == 1 else "ripe", p, t, custom)
				x += spacing
	# Verge grass on both sides and the grassy crown between the ruts; sparser on the banks.
	for i in road.size():
		if road[i].y < 52.0:
			continue
		for k in 24:
			var u := 0.0
			var y := GROUND
			match k % 3:
				0:
					u = rng.randf_range(2.1, 3.05) * (1.0 if k < 12 else -1.0)
					y = GROUND - .03
				1:
					u = rng.randf_range(-.5, .5)
					y = GROUND + .035
				_:
					u = rng.randf_range(3.2, 4.0) * (1.0 if k < 12 else -1.0)
					y = GROUND - .1 - (absf(u) - 3.1) * .35
			var p := road[i] + side[i] * u + tangent[i] * rng.randf_range(-.45, .45)
			if in_pond(p, .5):
				continue
			var height := rng.randf_range(.3, .6) if k % 3 != 1 else rng.randf_range(.18, .32)
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * height), _v3(p, y))
			_add_instance(_grass, "grass", p, t, Color(rng.randf(), height, rng.randf() * 6.0, rng.randf_range(0.0, .45)))
	var rice_root := Node3D.new()
	rice_root.name = "Rice"
	root.add_child(rice_root)
	var material := ShaderMaterial.new()
	material.resource_name = "Fields / rice blades"
	material.shader = BLADE_SHADER
	var grass_material := material.duplicate() as ShaderMaterial
	grass_material.resource_name = "Fields / verge grass"
	grass_material.set_shader_parameter("root_color", Color(.05, .07, .035))
	grass_material.set_shader_parameter("tip_color", Color(.2, .26, .12))
	grass_material.set_shader_parameter("ripe_color", Color(.38, .34, .2))
	_stats.rice = _emit_chunks(_rice, meshes, material, rice_root, "Rice")
	_stats.grass = _emit_chunks(_grass, meshes, grass_material, rice_root, "Grass")

func _add_instance(store: Dictionary, kind: String, p: Vector2, t: Transform3D, custom: Color) -> void:
	var key := "%s|%d|%d" % [kind, int(floorf(p.x / CHUNK)), int(floorf(p.y / CHUNK))]
	if not store.has(key):
		store[key] = [[], []]
	store[key][0].append(t)
	store[key][1].append(custom)

func _emit_chunks(store: Dictionary, meshes: Dictionary, material: ShaderMaterial, parent: Node3D, label: String) -> int:
	var count := 0
	for key: String in store:
		var parts := key.split("|")
		var transforms: Array = store[key][0]
		var customs: Array = store[key][1]
		# Shuffle so the first half is an even subsample (Android draws half: visible_instance_count).
		var order := range(transforms.size())
		for k in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var tmp: int = order[k]
			order[k] = order[j]
			order[j] = tmp
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[parts[0]]
		mm.instance_count = transforms.size()
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for k in order.size():
			var t: Transform3D = transforms[order[k]]
			mm.set_instance_transform(k, t)
			mm.set_instance_custom_data(k, customs[order[k]])
			lo = lo.min(t.origin)
			hi = hi.max(t.origin)
		var node := MultiMeshInstance3D.new()
		node.name = "%s %s %s" % [label, parts[1], parts[2]]
		node.multimesh = mm
		node.material_override = material
		node.layers = OUTDOOR_LAYER
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 46.0 if label == "Rice" else 38.0
		node.visibility_range_end_margin = 6.0
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.custom_aabb = AABB(lo - Vector3(1, .2, 1), hi - lo + Vector3(2, 1.6, 2))
		parent.add_child(node, true)
		count += transforms.size()
	return count

# ---------------------------------------------------------------- walls and fireflies

func _wall_box(label: String, base: Vector3, size: Vector3, basis: Basis) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = label
	collision.shape = shape
	colliders.add_child(collision, true)
	collision.transform = Transform3D(basis, base + Vector3.UP * size.y * .5)

## Invisible walls just outside the verges (the jetty opens a gap on the moon side), and at the end.
func _walls() -> void:
	var step := 4
	for i in range(0, road.size() - step, step):
		var a := road[i]
		var c := road[i + step]
		var mid := (a + c) * .5
		var dir := (c - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		if n.dot(side[i]) < 0.0:
			n = -n
		var basis := Basis(Vector3(n.x, 0, n.y), Vector3.UP, Vector3(dir.x, 0, dir.y))
		for s in [-1.0, 1.0]:
			var a2: Vector2 = a + n * s * (WALK_HALF + .12)
			var c2: Vector2 = c + n * s * (WALK_HALF + .12)
			var pieces := [[a2, c2]]
			if s > 0.0 and absi(i + step / 2 - jetty_index) <= step:
				# Leave a deck-wide opening onto the jetty.
				var j := road[jetty_index] + side[jetty_index] * (WALK_HALF + .12)
				var along_j: float = (j - a2).dot(dir)
				pieces = [[a2, a2 + dir * (along_j - .78)], [a2 + dir * (along_j + .78), c2]]
			for piece: Array in pieces:
				var p0: Vector2 = piece[0]
				var p1: Vector2 = piece[1]
				var length := (p1 - p0).dot(dir)
				if length < .05:
					continue
				_wall_box("Road edge", _v3((p0 + p1) * .5, GROUND - .6), Vector3(.24, 3.6, length + (.3 if pieces.size() == 1 else .02)), basis)
	var last := road.size() - 1
	var t := tangent[last]
	var n2 := side[last]
	_wall_box("Road end", _v3(road[last] - t * .4, GROUND - .6), Vector3(WALK_HALF * 2.0 + .8, 3.6, .3), Basis(Vector3(n2.x, 0, n2.y), Vector3.UP, Vector3(t.x, 0, t.y)))

func _fireflies() -> void:
	var swarm := Node3D.new()
	swarm.name = "Fireflies"
	root.add_child(swarm)
	var draw := QuadMesh.new()
	draw.size = Vector2(.16, .16)
	var material := ShaderMaterial.new()
	material.resource_name = "Fields / firefly"
	material.shader = FIREFLY_SHADER
	draw.material = material
	var spots := [[_v3(Vector2(pond.x, pond.y), WATER_Y + 1.1), Vector3(pond.z + 2.0, .9, pond.w + 2.0), 90],
			[_v3(hut, GROUND + 1.2), Vector3(7, 1.3, 7), 34]]
	var end_tree: Vector3 = root.get_meta("giant_tree")
	spots.append([end_tree + Vector3.UP * 2.5, Vector3(10, 2.2, 10), 60])
	for k in mini(4, audio_spots.bamboo.size()):
		spots.append([audio_spots.bamboo[k] + Vector3.DOWN * 2.6, Vector3(4, 1.2, 4), 22])
	var canal_s := along[pond_index] - 45.0
	for k in 3:
		var i := _index_at(canal_s + k * 30.0)
		spots.append([_v3(road[i] + side[i] * 5.0, WATER_Y + .8), Vector3(5, .6, 5), 16])
	for spot: Array in spots:
		var particles := GPUParticles3D.new()
		particles.name = "Fireflies"
		particles.amount = int(spot[2])
		particles.lifetime = 9.0
		particles.preprocess = 9.0
		particles.fixed_fps = 30
		particles.randomness = .5
		particles.draw_pass_1 = draw
		particles.layers = OUTDOOR_LAYER
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.visibility_range_end = 85.0
		var extents: Vector3 = spot[1]
		particles.visibility_aabb = AABB(-extents - Vector3.ONE * 2.0, (extents + Vector3.ONE * 2.0) * 2.0)
		var process := ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = extents
		process.direction = Vector3.UP
		process.spread = 180.0
		process.initial_velocity_min = .03
		process.initial_velocity_max = .18
		process.gravity = Vector3(0, .015, 0)
		process.damping_min = .05
		process.damping_max = .2
		process.turbulence_enabled = true
		process.turbulence_noise_strength = 1.2
		process.turbulence_noise_scale = 3.5
		process.turbulence_noise_speed = Vector3(.05, .02, .05)
		process.turbulence_influence_min = .04
		process.turbulence_influence_max = .12
		particles.process_material = process
		swarm.add_child(particles, true)
		particles.position = spot[0]
		_stats.fireflies += particles.amount

## Low, wispy mist lying on the paddies (Forward+ volumetric fog; the global fog density stays 0).
func _mist() -> void:
	var mist := FogVolume.new()
	mist.name = "Paddy mist"
	mist.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	mist.size = Vector3(FIELD_RECT.size.x, 2.6, FIELD_RECT.size.y)
	var material := FogMaterial.new()
	material.resource_name = "Fields / paddy mist"
	material.density = .05
	material.albedo = Color(.74, .8, .95)
	material.height_falloff = 1.6
	material.edge_fade = .3
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = .09
	noise.fractal_octaves = 3
	var texture := NoiseTexture3D.new()
	texture.width = 64
	texture.height = 16
	texture.depth = 64
	texture.seamless = true
	texture.noise = noise
	material.density_texture = texture
	mist.material = material
	root.add_child(mist)
	mist.position = Vector3(FIELD_RECT.get_center().x, WATER_Y + 1.05, FIELD_RECT.get_center().y)

# ---------------------------------------------------------------- commit

func _commit() -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	root.add_child(ground)
	for key: String in b._batches:
		var parts := key.split("|")
		var mat_key := parts[1] if parts.size() > 1 else key
		var tool := b._batches[key] as SurfaceTool
		tool.index()
		tool.generate_tangents()
		var mesh := MeshInstance3D.new()
		mesh.name = "Fields %s - %s" % [parts[0], mat_key]
		mesh.mesh = tool.commit()
		mesh.material_override = b._materials[mat_key]
		mesh.layers = OUTDOOR_LAYER
		if mat_key in ["lily", "lily flower", "puddle", "wire"]:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.visibility_range_end = 120.0
		elif mat_key == "dike":
			mesh.visibility_range_end = 440.0
		ground.add_child(mesh, true)
	b._batches.clear()
