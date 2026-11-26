class_name InteriorWindowGlass
extends Node3D
## 0.34: window glass breaks.
##
## The panes are part of merged meshes and have no collider of their own, so this keeps a list of where each one
## is (`panes`) and scripts/gun.gd asks it about every place a round lands (`pane_at`).
##
## The town's houses (`solid` panes): the builder's dark panes on a solid house. They are found while the facades
## are dressed (scripts/neighborhood_derelict.gd, "window_panes"). A front or back window is two lights either side
## of its mullion. A broken one is drawn over the old pane: the black of the room behind, and what glass is left
## in the frame. The round stops in the house.
##
## The Nichols house (open panes): four lights to a sash window, real see-through glass in house_glass.glb. Each
## light's place comes from the window's record in layout.json, worked out the way the Blender script laid it; its
## triangles are found in the mesh and taken out of it when it breaks. Lights the house was built with broken are
## openings from the start. A round that meets an opening goes on into the room (or out of it): the window's
## collider, which fills the whole frame, still stops feet and hands.
##
## A thing thrown hard enough breaks a pane too (`thing_hit`, from scripts/senses.gd). Breaking glass is heard
## sixteen metres off by the infected.

const CELL := 4.0
const OUTDOOR_LAYER := 2
## How far the glass sits behind the outer face of a Nichols wall (tools/blender/nichols/nichols_plan.py).
const SASH_SET_BACK := .09
const LOUD := 16.0

var main: Node
## {at, x, y, n, w, h, solid, broken, body, shape, layers, tris, material, parent}
var panes: Array[Dictionary] = []
var broken := 0
## Lights that were openings when the game began (the Nichols house's old damage).
var open_from_the_start := 0
var built := false
var _grid := {}
## The Nichols glass: [{instance, arrays: [per surface], gone: [per surface {triangle: true}]}]
var _sheets: Array[Dictionary] = []
var _hole_material: StandardMaterial3D
var _town_glass: StandardMaterial3D
var _bit_mesh: QuadMesh
var _sound: AudioStream
var _rng := RandomNumberGenerator.new()

func setup(scene: Node) -> void:
	main = scene
	name = "WindowGlass"
	_rng.seed = 340034
	if ResourceLoader.exists("res://assets/audio/sfx/hit_glass.ogg"):
		_sound = load("res://assets/audio/sfx/hit_glass.ogg")
	InteriorLoadClock.later(build)

func build() -> void:
	if built or not is_inside_tree():
		return
	built = true
	var town := get_tree().get_first_node_in_group("neighbourhood") as Node3D
	if town != null:
		var facades := town.get_node_or_null("Derelict facades")
		var body := town.get_node_or_null("NeighbourhoodColliders")
		if facades != null and body != null:
			_town_panes(town, body, facades.get_meta("window_panes", []))
	for property in get_tree().get_nodes_in_group("nichols_property"):
		_nichols_panes(property)
	InteriorLoadClock.mark("deferred: window glass")

# ---------------------------------------------------------------- the list

func _add(pane: Dictionary) -> int:
	pane["broken"] = bool(pane.get("broken", false))
	panes.append(pane)
	var at: Vector3 = pane.at
	var cell := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
	if not _grid.has(cell):
		_grid[cell] = []
	(_grid[cell] as Array).append(panes.size() - 1)
	return panes.size() - 1

func _town_panes(town: Node3D, body: Node, records: Array) -> void:
	var frame := town.global_transform
	for record: Dictionary in records:
		if int(record.cover) == 2:
			continue       # behind a sheet of roofing iron: never seen, never struck
		var n := (frame.basis * (record.normal as Vector3)).normalized()
		var x := Vector3.UP.cross(n).normalized()
		var at: Vector3 = frame * (record.at as Vector3)
		var w := float(record.width)
		var h := float(record.height)
		var lights: Array = [[0.0, w]]
		if w >= .95:
			# Front and back windows have a 4 cm mullion down the middle: two lights.
			var each := (w - .04) * .5
			lights = [[-(each * .5 + .02), each], [each * .5 + .02, each]]
		for light: Array in lights:
			_add({"at": at + x * float(light[0]), "x": x, "y": Vector3.UP, "n": n, "w": float(light[1]), "h": h, "solid": true,
				"body": body, "layers": OUTDOOR_LAYER, "reach": .2, "boarded": int(record.cover) == 1})

func _nichols_panes(property: Node) -> void:
	var house := property.get("house") as Node3D
	var layout: Dictionary = property.get("layout")
	var solids := property.get("solids") as Node
	if house == null or solids == null or layout.is_empty():
		return
	var glass_root := house.get_node_or_null("house_glass")
	if glass_root == null:
		return
	# The glass as the importer left it: every triangle's middle, in the world.
	var middles: Array = []      # [sheet, surface, triangle, Vector3 middle, area]
	for node in glass_root.find_children("*", "MeshInstance3D", true, false) + ([glass_root] if glass_root is MeshInstance3D else []):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		var sheet := {"instance": instance, "arrays": [], "gone": []}
		var to_world := instance.global_transform
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_INDEX] == null or (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
				var all := PackedInt32Array()
				all.resize(vertices.size())
				for i in vertices.size():
					all[i] = i
				arrays[Mesh.ARRAY_INDEX] = all
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			sheet.arrays.append(arrays)
			sheet.gone.append({})
			for t in indices.size() / 3:
				var a := to_world * vertices[indices[t * 3]]
				var b := to_world * vertices[indices[t * 3 + 1]]
				var c := to_world * vertices[indices[t * 3 + 2]]
				middles.append([_sheets.size(), surface, t, (a + b + c) / 3.0, (b - a).cross(c - a).length() * .5])
		_sheets.append(sheet)
	var shapes: Array[CollisionShape3D] = []
	for child in solids.get_children():
		if child is CollisionShape3D and str(child.get_meta("surface", "")) == "glass":
			shapes.append(child)
	var place := house.global_transform
	for window: Dictionary in layout.get("windows", []):
		if bool(window.get("boarded", false)):
			continue
		var n := (place.basis * _v(window.normal)).normalized()
		var x := (place.basis * _v(window.along)).normalized()
		var w := float(window.width)
		var h := float(window.height)
		var arch := bool(window.get("arch", false))
		var foot: Vector3 = place * _v(window.bottom) - n * SASH_SET_BACK
		var raised := float(window.get("raised", 0.0)) * (h * .5 - .1)
		# The collider that fills this window's frame.
		var centre: Vector3 = place * _v(window.center)
		var shape: CollisionShape3D = null
		for candidate in shapes:
			if candidate.global_position.distance_to(centre) < .12:
				shape = candidate
				break
		if shape == null:
			continue
		var sashes: Array = [[.06 + raised, h * .5 + raised, .025], [h * .5, h - (0.0 if arch else .08), -.025]]
		for sash: Array in sashes:
			var z0 := float(sash[0]) + .06
			var z1 := float(sash[1]) - .05
			for side: Array in [[-w * .5 + .125, -.011], [.011, w * .5 - .125]]:
				var pw := float(side[1]) - float(side[0])
				var ph := z1 - z0
				var at := foot + x * (float(side[0]) + float(side[1])) * .5 + Vector3.UP * (z0 + z1) * .5 + n * float(sash[2])
				var tris: Array = []
				var area := 0.0
				var materials := {}
				for m: Array in middles:
					var off: Vector3 = (m[3] as Vector3) - at
					if absf(off.dot(n)) < .012 and absf(off.dot(x)) < pw * .5 + .004 and absf(off.dot(Vector3.UP)) < ph * .5 + .004:
						tris.append([m[0], m[1], m[2]])
						area += float(m[4])
						materials[Vector2i(int(m[0]), int(m[1]))] = float(materials.get(Vector2i(int(m[0]), int(m[1])), 0.0)) + float(m[4])
				# Two faces to a light. Less than most of it: a shard in a corner, the light was built broken.
				var whole := area * .5 > pw * ph * .7
				var most := Vector2i(-1, -1)
				for key: Vector2i in materials:
					if most.x < 0 or float(materials[key]) > float(materials[most]):
						most = key
				var material: Material = null
				var parent: Node = glass_root
				var layers := OUTDOOR_LAYER
				if most.x >= 0:
					var instance := _sheets[most.x].instance as MeshInstance3D
					material = instance.get_active_material(most.y)
					layers = instance.layers
				if not whole:
					open_from_the_start += 1
				_add({"at": at, "x": x, "y": Vector3.UP, "n": n, "w": pw, "h": ph, "solid": false, "broken": not whole,
					"body": solids, "shape": shape, "layers": layers, "tris": tris if whole else [], "material": material,
					"parent": parent, "reach": .34})

static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

# ---------------------------------------------------------------- asking

## The pane a round meets when it lands at `point` on `collider` going `dir`; -1 for none. The point is on the
## collider's face, a few centimetres off the glass: it is carried along the round's way to the glass first.
func pane_at(collider: Object, shape_index: int, point: Vector3, dir: Vector3) -> int:
	if not built or collider == null:
		return -1
	var cell := Vector2i(floori(point.x / CELL), floori(point.z / CELL))
	var shape_node: Node = null
	var asked := false
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var here: Variant = _grid.get(cell + Vector2i(dx, dz))
			if here == null:
				continue
			for i: int in here:
				var pane := panes[i]
				if pane.body != collider:
					continue
				var off: Vector3 = point - (pane.at as Vector3)
				var n: Vector3 = pane.n
				var depth := off.dot(n)
				if absf(depth) > float(pane.reach):
					continue
				var facing := dir.dot(n)
				if absf(facing) < .06:
					continue
				var on := off - dir * (depth / facing)
				if absf(on.dot(pane.x)) > float(pane.w) * .5 or absf(on.dot(pane.y)) > float(pane.h) * .5:
					continue
				if pane.has("shape"):
					if not asked:
						asked = true
						shape_node = InteriorSurfaces._shape_node(collider, shape_index)
					if shape_node != pane.shape:
						continue
				return i
	return -1

func is_solid(i: int) -> bool:
	return bool(panes[i].solid)

func is_broken(i: int) -> bool:
	return bool(panes[i].broken)

## How far along `dir` from `point` (on the frame's collider) a round is through an open pane's frame.
func way_out(i: int, point: Vector3, dir: Vector3) -> float:
	var pane := panes[i]
	var shape := pane.get("shape") as CollisionShape3D
	if shape == null or not shape.shape is BoxShape3D:
		return -1.0
	var inverse := shape.global_transform.affine_inverse()
	var p := inverse * point
	var d := inverse.basis * dir
	var half := (shape.shape as BoxShape3D).size * .5 + Vector3.ONE * .002
	var out := INF
	for axis in 3:
		if absf(d[axis]) < 1e-6:
			continue
		var t := ((half[axis] if d[axis] > 0.0 else -half[axis]) - p[axis]) / d[axis]
		out = minf(out, t)
	return out if out > 0.0 and out < 3.0 else -1.0

## A round meets pane `i` at `point`. Breaks it if it is whole (true), the sight and sound of it after `delay`
## seconds (the round's flight). The pane counts as broken at once, so the next ball of the same shot goes through.
func strike(i: int, point: Vector3, dir: Vector3, delay := 0.0) -> bool:
	var pane := panes[i]
	if bool(pane.broken):
		return false
	pane.broken = true
	broken += 1
	if delay < .02:
		_shatter(i, point, dir)
	else:
		get_tree().create_timer(delay, false).timeout.connect(_shatter.bind(i, point, dir))
	return true

## A thrown thing came down at `at` with a blow of `strength` (scripts/physics_object.gd's measure).
func thing_hit(at: Vector3, strength: float, mass: float) -> bool:
	if not built or strength < 2.5 or strength / maxf(mass, .05) < 3.0:
		return false
	var cell := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var here: Variant = _grid.get(cell + Vector2i(dx, dz))
			if here == null:
				continue
			for i: int in here:
				var pane := panes[i]
				if bool(pane.broken):
					continue
				var off: Vector3 = at - (pane.at as Vector3)
				var depth := off.dot(pane.n)
				if absf(depth) > .4 or absf(off.dot(pane.x)) > float(pane.w) * .5 + .05 or absf(off.dot(pane.y)) > float(pane.h) * .5 + .05:
					continue
				var n: Vector3 = pane.n
				return strike(i, at - n * depth, -n if depth > 0.0 else n)
	return false

## The nearest whole pane within `reach` of `at` (the debug menu and the tests); -1 for none.
func nearest(at: Vector3, reach := 30.0, solid_only := false, open_only := false) -> int:
	var best := -1
	var best_far := reach
	for i in panes.size():
		var pane := panes[i]
		if bool(pane.broken) or (solid_only and not bool(pane.solid)) or (open_only and bool(pane.solid)):
			continue
		var far := (pane.at as Vector3).distance_to(at)
		if far < best_far:
			best = i
			best_far = far
	return best

# ---------------------------------------------------------------- breaking

func _shatter(i: int, point: Vector3, dir: Vector3) -> void:
	if not is_inside_tree():
		return
	var pane := panes[i]
	var at: Vector3 = pane.at
	var n: Vector3 = pane.n
	var x: Vector3 = pane.x
	var y: Vector3 = pane.y
	var facing := dir.dot(n)
	var off := point - at
	var on := off - dir * (off.dot(n) / facing) if absf(facing) > .06 else off - n * off.dot(n)
	var struck := Vector2(clampf(on.dot(x), -float(pane.w) * .5, float(pane.w) * .5), clampf(on.dot(y), -float(pane.h) * .5, float(pane.h) * .5))
	var left := _left_in_frame(pane, struck)
	var holder := MeshInstance3D.new()
	holder.name = "Broken pane %d" % i
	holder.layers = int(pane.layers)
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := ArrayMesh.new()
	if bool(pane.solid):
		# Drawn a hair in front of the old pane: the dark of the room where the glass is gone. What still stands in
		# the frame is the old pane itself, showing round the hole; its broken edge catches the light.
		_surface(mesh, left.hole, .0022, _hole())
		_surface(mesh, left.rim, .003, _glass_left())
	else:
		_cut(pane)
		_surface(mesh, left.glass, 0.0, pane.material if pane.material != null else _glass_left())
		_surface(mesh, left.rim, .001, _glass_left())
	holder.mesh = mesh
	var parent: Node = pane.get("parent", null) if is_instance_valid(pane.get("parent", null)) else self
	parent.add_child(holder)
	holder.global_transform = Transform3D(Basis(x, y, n), at)
	pane["left"] = holder
	_bits(pane, struck, -1.0 if (bool(pane.solid) or facing > 0.0) else 1.0)
	_ring(at + x * struck.x + y * struck.y + n * .05, float(pane.h))
	var senses: Variant = main.get("senses") if main != null else null
	if senses != null and senses is InteriorSenses:
		(senses as InteriorSenses).noise(at, LOUD, "glass")

## What stays in the frame, in the pane's own flat (x across, y up, the middle at nought). A star about a point
## between the blow and the middle: where its arm reaches the frame nothing is left, where it stops short a
## tooth of glass stands in from the edge. Corners keep theirs oftenest.
func _left_in_frame(pane: Dictionary, struck: Vector2) -> Dictionary:
	var hw := float(pane.w) * .5
	var hh := float(pane.h) * .5
	var c := Vector2(clampf(struck.x * .6, -hw * .55, hw * .55), clampf(struck.y * .6, -hh * .55, hh * .55))
	var arms: Array = []       # [angle, is corner]
	for corner: Vector2 in [Vector2(hw, hh), Vector2(-hw, hh), Vector2(-hw, -hh), Vector2(hw, -hh)]:
		arms.append([(corner - c).angle(), true])
	var count := 15
	for k in count:
		arms.append([TAU * (float(k) + _rng.randf_range(.2, .8)) / float(count) - PI, false])
	arms.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var edge := PackedVector2Array()
	var inner := PackedVector2Array()
	var whole: Array[bool] = []
	for arm: Array in arms:
		var d := Vector2.from_angle(float(arm[0]))
		var tx := INF if absf(d.x) < 1e-6 else ((hw if d.x > 0.0 else -hw) - c.x) / d.x
		var ty := INF if absf(d.y) < 1e-6 else ((hh if d.y > 0.0 else -hh) - c.y) / d.y
		var t := minf(tx, ty)
		var gone := _rng.randf() < (.25 if bool(arm[1]) else .5)
		edge.append(c + d * t)
		inner.append(c + d * t * (1.0 if gone else _rng.randf_range(.38, .82)))
		whole.append(gone)
	var hole := PackedVector2Array()
	var glass := PackedVector2Array()
	var rim := PackedVector2Array()
	for k in arms.size():
		var next := (k + 1) % arms.size()
		hole.append_array([c, inner[k], inner[next]])
		if whole[k] and whole[next]:
			continue
		glass.append_array([inner[k], edge[k], edge[next]])
		if not whole[next]:
			glass.append_array([inner[k], edge[next], inner[next]])
		# The broken edge: a few millimetres of it, on the glass's side of the break.
		var a := inner[k]
		var b := inner[next]
		var a2 := a + (a - c).normalized() * (0.0 if whole[k] else .005)
		var b2 := b + (b - c).normalized() * (0.0 if whole[next] else .005)
		rim.append_array([a, a2, b2, a, b2, b])
	return {"hole": hole, "glass": glass, "rim": rim}

func _surface(mesh: ArrayMesh, flat: PackedVector2Array, forward: float, material: Material) -> void:
	if flat.is_empty():
		return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for p in flat:
		vertices.append(Vector3(p.x, p.y, forward))
		normals.append(Vector3.BACK)
		uvs.append(p)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)

func _hole() -> StandardMaterial3D:
	if _hole_material == null:
		_hole_material = StandardMaterial3D.new()
		_hole_material.resource_name = "Broken window, the room behind"
		_hole_material.albedo_color = Color(.004, .004, .005)
		_hole_material.roughness = 1.0
		_hole_material.metallic_specular = 0.0
		_hole_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _hole_material

func _glass_left() -> StandardMaterial3D:
	if _town_glass == null:
		_town_glass = StandardMaterial3D.new()
		_town_glass.resource_name = "Broken window, the broken edge"
		_town_glass.albedo_color = Color(.3, .36, .37)
		_town_glass.roughness = .22
		_town_glass.metallic_specular = .8
		_town_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _town_glass

## Takes a light's triangles out of the Nichols glass.
func _cut(pane: Dictionary) -> void:
	var touched := {}
	for tri: Array in pane.tris:
		(_sheets[int(tri[0])].gone[int(tri[1])] as Dictionary)[int(tri[2])] = true
		touched[int(tri[0])] = true
	for s: int in touched:
		var sheet := _sheets[s]
		var instance := sheet.instance as MeshInstance3D
		if not is_instance_valid(instance):
			continue
		var old := instance.mesh
		var mesh := ArrayMesh.new()
		for surface in sheet.arrays.size():
			var arrays: Array = (sheet.arrays[surface] as Array).duplicate()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var gone: Dictionary = sheet.gone[surface]
			var kept := PackedInt32Array()
			for t in indices.size() / 3:
				if not gone.has(t):
					kept.append_array([indices[t * 3], indices[t * 3 + 1], indices[t * 3 + 2]])
			if kept.is_empty():
				kept = PackedInt32Array([0, 0, 0])      # keeps the surface, and so the materials' order
			arrays[Mesh.ARRAY_INDEX] = kept
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			if old != null and surface < old.get_surface_count():
				mesh.surface_set_material(surface, old.surface_get_material(surface))
		instance.mesh = mesh

## The pieces that fall.
func _bits(pane: Dictionary, struck: Vector2, way: float) -> void:
	if _bit_mesh == null:
		_bit_mesh = QuadMesh.new()
		_bit_mesh.size = Vector2(.011, .03)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(.42, .5, .52, .5)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = .1
		m.metallic_specular = .9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_bit_mesh.material = m
	var bits := CPUParticles3D.new()
	bits.mesh = _bit_mesh
	bits.layers = int(pane.layers)
	bits.one_shot = true
	bits.explosiveness = .9
	bits.amount = 22 + int(float(pane.w) * float(pane.h) * 46.0)
	bits.lifetime = 1.25
	bits.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bits.emission_box_extents = Vector3(float(pane.w) * .46, float(pane.h) * .46, .01)
	bits.direction = Vector3(0, .15, way)
	bits.spread = 48.0
	bits.initial_velocity_min = .3
	bits.initial_velocity_max = 2.6
	bits.gravity = Vector3(0, -9.8, 0)
	bits.scale_amount_min = .4
	bits.scale_amount_max = 1.7
	bits.particle_flag_align_y = true
	add_child(bits)
	bits.global_transform = Transform3D(Basis(pane.x, pane.y, pane.n), (pane.at as Vector3) + (pane.n as Vector3) * (.03 * way))
	bits.emitting = true
	get_tree().create_timer(2.2, false).timeout.connect(bits.queue_free)

## The crack of the pane, then the pieces on the ground.
func _ring(at: Vector3, height: float) -> void:
	if _sound == null:
		return
	for part: Array in [[0.0, .82, 4.0], [.04, 1.12, 2.0], [.1, 1.45, 0.0], [.42 + height * .1, 1.75, -7.0], [.6 + height * .1, 1.3, -9.0]]:
		var voice := AudioStreamPlayer3D.new()
		voice.stream = _sound
		voice.unit_size = 10.0
		voice.max_distance = 80.0
		voice.volume_db = float(part[2])
		voice.pitch_scale = float(part[1]) * _rng.randf_range(.94, 1.06)
		if AudioServer.get_bus_index("Gun") >= 0:
			voice.bus = "Gun"
		add_child(voice)
		voice.global_position = at
		voice.finished.connect(voice.queue_free)
		if float(part[0]) <= 0.0:
			voice.play()
		else:
			get_tree().create_timer(float(part[0]), false).timeout.connect(voice.play)
