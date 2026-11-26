extends SceneTree
## 0.66: Dodong's walk from outside the house's courtyard gate to the warren (world coords): each leg between the
## blood arrows found on the ground (zombie_nav A*), then pulled straight where a body fits the whole way.
##   godot --headless --path game --script res://tests/dodong_gate_probe.gd
## Prints PROBE_ROUTE <points> for mission.gd's GATE_WALK.
var main
var session
var m
var space: PhysicsDirectSpaceState3D

func _initialize() -> void: run.call_deferred()

func frames(n: int) -> void:
	for i in n: await physics_frame

func ground(at: Vector3) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at + Vector3.DOWN * 1.2, 2))
	if hit.is_empty() or hit.normal.y < .65: return NAN
	return hit.position.y

var ball := SphereShape3D.new()
func room(at: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	ball.radius = .34
	q.shape = ball
	q.collision_mask = 2
	for h in [.75, 1.3]:
		q.transform = Transform3D(Basis(), at + Vector3.UP * h)
		if not space.intersect_shape(q, 1).is_empty(): return false
	return true

## A body walks straight from a to b: ground all the way, no step over 0.3 m, room for a body.
func clear(a: Vector3, b: Vector3) -> bool:
	var n := maxi(2, int(a.distance_to(b) / .25))
	var last := a.y
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var y := ground(Vector3(p.x, last, p.z))
		if is_nan(y) or absf(y - last) > .3: return false
		last = y
		if not room(Vector3(p.x, y, p.z)): return false
	return true

func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	session = main.coop
	session.host()
	session.start_game()
	m = session.mission
	session.harmless = true
	await frames(40)
	space = main.get_world_3d().direct_space_state
	m.nav.space = space
	var C = m.C
	var legs: Array[Vector3] = [Vector3(14.4, -2.9, 4.4), Vector3(18.6, -2.8, 6.5), Vector3(18.4, -2.8, 15.4), Vector3(3, -2.85, 16.4), Vector3(-19, -2.85, 17.2),
		Vector3(-36, -2.8, 18), C.at(C.LANE_U, C.FLOOR, 20), C.at(C.LANE_U, C.FLOOR, 38), C.at(C.LANE_U, C.FLOOR, 59),
		C.at(-12, C.FLOOR, 60), C.at(-14, C.FLOOR, 43), C.at(-14, C.FLOOR, 23), m.route[0]]
	for p in legs: print("PROBE mark ", p, " ground ", ground(p))
	var way: Array[Vector3] = [legs[0]]
	for i in legs.size() - 1:
		var a: Vector3 = way[way.size() - 1]
		var b: Vector3 = legs[i + 1]
		var p: PackedVector3Array = m.nav.path(a, b, 60000)
		var end: Vector3 = p[p.size() - 1] if p.size() > 0 else Vector3.INF
		print("PROBE leg %d n=%d end %s goal %s gap %.2f" % [i, p.size(), end, b, Vector2(end.x - b.x, end.z - b.z).length() if end.is_finite() else -1.0])
		for q in p: way.append(q)
		if Vector2(way[way.size() - 1].x - b.x, way[way.size() - 1].z - b.z).length() > .2: way.append(b)
	# Pull straight.
	var out: Array[Vector3] = [way[0]]
	var i := 0
	while i < way.size() - 1:
		var j := way.size() - 1
		while j > i + 1 and not clear(way[i], way[j]): j -= 1
		out.append(way[j])
		i = j
	var words := []
	var total := 0.0
	for k in out.size():
		var y := ground(out[k])
		if not is_nan(y): out[k].y = y
		words.append("Vector3(%.2f, %.2f, %.2f)" % [out[k].x, out[k].y, out[k].z])
		if k > 0: total += out[k].distance_to(out[k - 1])
	print("PROBE_ROUTE n=%d length %.1f m" % [out.size(), total])
	print("PROBE_ROUTE [", ", ".join(words), "]")
	quit()
