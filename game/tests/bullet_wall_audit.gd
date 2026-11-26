extends SceneTree
## 0.49: invisible walls that stop rounds. Starts co-op, stands on a grid over the whole co-op map (Store Road,
## the ramp, the far bank, the backstreets), fires rays the way a round goes (InteriorGun.MASK) in eight
## directions from eye height, and for every hit asks whether anything DRAWN is there: the same short segment
## through the hit point is tested against the triangles of every visible mesh (and multimesh instance) nearby.
## A hit with nothing drawn within a few centimetres is an invisible wall; they are grouped by collider and shape.
##   godot --headless --path game --script res://tests/bullet_wall_audit.gd -- [--step=2.5] [--reach=30] [--out=file]
## Prints INTERIOR_BULLET_WALLS <count> and, per offender, the shape's owner path, its size and the hits.

var game
var session
var space: PhysicsDirectSpaceState3D
var step := 2.5
var reach := 30.0
var out := ""
## Only stand on floors whose collider path contains this ("/Coop/" by default: where co-op players walk).
var only := "/Coop/"
var solo := false
## [mesh rid key] -> TriangleMesh
var tris := {}
## Each drawn thing: [AABB world, Transform3D, Mesh, VisualInstance3D]
var drawn: Array = []
## Spatial hash: Vector2i(4 m cell) -> Array of indices in `drawn`.
var cells := {}
const CELL := 4.0
const MASK := 2 | 4 | 16

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--step="): step = float(a.trim_prefix("--step="))
		if a.begins_with("--reach="): reach = float(a.trim_prefix("--reach="))
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--only="): only = a.trim_prefix("--only=")
		if a == "--solo":
			solo = true
			only = ""
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	var m = null
	if not solo:
		session.host()
		session.start_game()
		for i in 30: await physics_frame
		m = session.mission
		session.harmless = true
		for k in m.enemies.keys():
			m.enemies[k].queue_free()
			m.enemies.erase(k)
	for i in 10: await physics_frame
	space = game.get_world_3d().direct_space_state
	_collect(game)
	print("AUDIT drawn pieces ", drawn.size())
	# The co-op world: everything the street node and its builders put down.
	var area := AABB(Vector3(-130, -8, -136), Vector3(190, 20, 200)) if solo else _area(m.street)
	print("AUDIT area ", area)
	var offenders := {}
	var shots := 0
	var stands := 0
	var x := area.position.x
	while x < area.end.x:
		var z := area.position.z
		while z < area.end.z:
			for floor_y in _floors(Vector3(x, area.end.y + 2.0, z), area.position.y - 2.0):
				var eye := Vector3(x, floor_y + 1.5, z)
				if not _clear(eye): continue
				stands += 1
				for k in 8:
					var a := TAU * k / 8.0 + .3
					var dir := Vector3(sin(a), -.03 + .06 * (k % 2), cos(a)).normalized()
					shots += 1
					var hit := InteriorSurfaces.seen_ray(space, eye, eye + dir * reach, MASK, [])
					if hit.is_empty(): continue
					var col: Object = hit.collider
					if col is CharacterBody3D or col is RigidBody3D: continue
					var p: Vector3 = hit.position
					if _seen(p, dir): continue
					var owner_node := _shape_owner(col, int(hit.shape))
					var key := str(owner_node.get_path()) if owner_node != null else str(col.get_path())
					if not offenders.has(key):
						offenders[key] = {"hits": 0, "at": [], "size": _shape_size(col, int(hit.shape)), "where": owner_node.global_position if owner_node is Node3D else Vector3.ZERO}
					offenders[key].hits += 1
					if offenders[key].at.size() < 4: offenders[key].at.append(p.snapped(Vector3(.1, .1, .1)))
			z += step
		x += step
	print("AUDIT stands %d shots %d" % [stands, shots])
	var keys := offenders.keys()
	keys.sort_custom(func(a, b): return offenders[a].hits > offenders[b].hits)
	var lines: Array = []
	for key in keys:
		var o: Dictionary = offenders[key]
		var local: Vector3 = (o.where - (Vector3.ZERO if solo else session.mission.Street.ORIGIN)).snapped(Vector3(.05, .05, .05))
		var line := "BULLET WALL %4d hits  %s  size %s  at %s (street-local %s)  e.g. %s" % [o.hits, key, str(o.size), str(o.where.snapped(Vector3(.1, .1, .1))), str(local), str(o.at)]
		print(line)
		lines.append(line)
	print("INTERIOR_BULLET_WALLS %d" % keys.size())
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
	quit(0)

func _area(street: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in street.find_children("*", "CollisionShape3D", true, false):
		var c := n as CollisionShape3D
		if c.shape == null or c.disabled: continue
		var b: AABB = c.global_transform * _local_aabb(c.shape)
		if b.size.length() > 400.0: continue
		box = b if first else box.merge(b)
		first = false
	return box

func _local_aabb(s: Shape3D) -> AABB:
	if s is BoxShape3D: return AABB(-(s as BoxShape3D).size * .5, (s as BoxShape3D).size)
	var m := s.get_debug_mesh()
	return m.get_aabb() if m != null else AABB()

## Every floor under (x, z) between top and bottom: rays down, one after another through each.
func _floors(top: Vector3, bottom: float) -> Array:
	var found: Array = []
	var from := top
	for i in 4:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(from.x, bottom, from.z), 2))
		if hit.is_empty(): break
		var n: Vector3 = hit.normal
		if n.y > .7 and (only == "" or str((hit.collider as Node).get_path()).contains(only)): found.append(float(hit.position.y))
		from = (hit.position as Vector3) + Vector3.DOWN * .3
	return found

var _cap := CapsuleShape3D.new()
func _clear(eye: Vector3) -> bool:
	_cap.radius = .3
	_cap.height = 1.4
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _cap
	q.collision_mask = 2
	q.transform = Transform3D(Basis.IDENTITY, eye + Vector3.DOWN * .62)
	return space.intersect_shape(q, 1).is_empty()

func _shape_owner(col: Object, shape: int) -> Node:
	if not col is CollisionObject3D: return null
	var co := col as CollisionObject3D
	var owner_id := co.shape_find_owner(shape)
	return co.shape_owner_get_owner(owner_id) as Node

func _shape_size(col: Object, shape: int) -> Vector3:
	if not col is CollisionObject3D: return Vector3.ZERO
	var co := col as CollisionObject3D
	var owner_id := co.shape_find_owner(shape)
	var s: Shape3D = co.shape_owner_get_shape(owner_id, 0)
	if s is BoxShape3D: return (s as BoxShape3D).size.snapped(Vector3(.01, .01, .01))
	return _local_aabb(s).size.snapped(Vector3(.01, .01, .01)) if s != null else Vector3.ZERO

func _collect(n: Node) -> void:
	if n is Node3D and not (n as Node3D).visible: return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		_add(mi.global_transform, mi.mesh, mi)
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null and (n as MultiMeshInstance3D).multimesh.mesh != null:
		var mm := (n as MultiMeshInstance3D).multimesh
		var count := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		for i in count:
			_add((n as Node3D).global_transform * mm.get_instance_transform(i), mm.mesh, n)
	elif n is CSGShape3D:
		pass
	for c in n.get_children(): _collect(c)

func _add(xf: Transform3D, mesh: Mesh, vi: Node) -> void:
	var box: AABB = xf * mesh.get_aabb()
	if box.size.length() > 2000.0: return
	var idx := drawn.size()
	drawn.append([box, xf, mesh, vi])
	var lo := Vector2i(floori(box.position.x / CELL), floori(box.position.z / CELL))
	var hi := Vector2i(floori(box.end.x / CELL), floori(box.end.z / CELL))
	if (hi.x - lo.x + 1) * (hi.y - lo.y + 1) > 4000:
		cells.get_or_add(Vector2i(999999, 999999), []).append(idx)
		return
	for cx in range(lo.x, hi.x + 1):
		for cz in range(lo.y, hi.y + 1):
			cells.get_or_add(Vector2i(cx, cz), []).append(idx)

func _tri(mesh: Mesh) -> TriangleMesh:
	var key := mesh.get_rid().get_id()
	if not tris.has(key): tris[key] = mesh.generate_triangle_mesh()
	return tris[key]

## Anything drawn within a few centimetres of `p` along the way the round went.
func _seen(p: Vector3, dir: Vector3) -> bool:
	var probe := AABB(p - Vector3.ONE * .3, Vector3.ONE * .6)
	var list: Array = cells.get(Vector2i(floori(p.x / CELL), floori(p.z / CELL)), []).duplicate()
	list.append_array(cells.get(Vector2i(999999, 999999), []))
	for idx in list:
		var d: Array = drawn[idx]
		if not (d[0] as AABB).intersects(probe): continue
		var tm := _tri(d[2])
		if tm == null: continue
		var inv: Transform3D = (d[1] as Transform3D).affine_inverse()
		var a: Vector3 = inv * (p - dir * .25)
		var b: Vector3 = inv * (p + dir * .25)
		if not tm.intersect_segment(a, b).is_empty(): return true
		# Thin cards (a sheet drawn one-sided, at a slant): try across as well.
		if not tm.intersect_segment(inv * (p + Vector3.UP * .2), inv * (p + Vector3.DOWN * .2)).is_empty() and (d[0] as AABB).size.y < .3: return true
	return false
