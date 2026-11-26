extends SceneTree
## 0.44: the way up the floodwall ramp, the back office door, and the backstreets walked end to end: every lane
## has floor, a survivor can walk each stretch, the infected can find a way along it, and nothing of the old
## ramp blocks the yard.
var main
var session
var player: InteriorPlayer
var m
var failed := []
var checks := 0
var notes := {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("BACKSTREETS CHECK ", label, " ", ok)

func frames(n: int) -> void:
	for i in n: await physics_frame

## Walks the local player from `from` facing `yaw` for `count` frames; returns where it got to (street-local).
func walk(from: Vector3, yaw: float, count: int) -> Vector3:
	var o: Vector3 = m.Street.ORIGIN
	player.reset_motion(o + from)
	await frames(6)
	player.rotation.y = yaw
	player.touch_move = Vector2(0, -1)
	player.touch_sprinting = true
	await frames(count)
	player.touch_move = Vector2.ZERO
	return player.global_position - o

func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	session = main.coop
	session.host()
	session.start_game()
	player = main.player
	m = session.mission
	session.set_physics_process(false)
	session.set_process(false)
	main.story.gun.holster(true)
	await frames(30)
	var o: Vector3 = m.Street.ORIGIN
	var G: float = m.Street.APPROACH.G
	# The ramp: from its foot to the landing in front of the gate.
	m.flags.gate = true
	m.street.sync(m.flags)
	var up: Vector3 = await walk(Vector3(12.0, G + .1, -1.75), PI * .5, 200)
	notes.ramp_top = up
	check(up.x < 3.0 and up.y > -.4, "ramp climbs to the landing (%s)" % str(up))
	var through: Vector3 = await walk(Vector3(.2, .1, -1.8), PI, 120)
	check(through.z > 3.0, "through the open gate into the lane (%s)" % str(through))
	# The yard: from the warren's exit to the foot of the ramp, through the trampled wire.
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var route: Array[Vector3] = [Vector3(-6.0, G, -16.0), Vector3(2.0, G, -11.5), Vector3(2.0, G, -8.0), Vector3(6.5, G, -4.6), Vector3(12.2, G, -3.6), Vector3(12.0, G, -1.8)]
	var blocked := 0
	for i in route.size() - 1:
		var a: Vector3 = o + route[i] + Vector3.UP * .9
		var b: Vector3 = o + route[i + 1] + Vector3.UP * .9
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 2))
		if not hit.is_empty():
			blocked += 1
			print("YARD BLOCK ", route[i], " ", hit.position - o, " ", hit.collider)
	check(blocked == 0, "yard path from the warren to the ramp is open (%d blocked)" % blocked)
	# The office door: shut until Jonna opens it, then swung clear.
	var door: StaticBody3D = m.street.office_door
	check(absf(door.rotation.y) < .01, "office shut during the fight")
	m.flags.office = true
	for i in 90: m.street.sync(m.flags)
	await frames(3)
	check(absf(door.rotation.y - m.BackOffice.OPEN_YAW) < .05, "office door swings open")
	var gap: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(4.4, 1.0, 68.6), o + Vector3(4.4, 1.0, 71.0), 2))
	if not gap.is_empty(): print("DOOR BLOCK ", gap.position - o, " ", gap.collider, " ", gap.shape)
	check(gap.is_empty(), "office doorway clear once open")
	# The backstreets: floor under every lane cell centre, one stretch after another walked.
	var bs = m.street.backstreets
	var holes := 0
	for spec: Array in bs.CORRIDORS:
		var x: float = spec[0] + .5
		while x < float(spec[1]):
			var z: float = spec[2] + .5
			while z < float(spec[3]):
				var at := o + Vector3(x, 1.0, z)
				var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 2.0, 2))
				if hit.is_empty() or absf(hit.position.y - o.y) > .1: holes += 1
				z += 2.0
			x += 2.0
	check(holes == 0, "every backstreet cell has floor (%d holes)" % holes)
	m.flags.backdoor_open = true
	m.flags.alley = true
	for i in 120: m.street.sync(m.flags)
	var legs := [[Vector3(-2.6, .1, 76.0), PI, Vector3(-2.6, 0, 100.0)], [Vector3(-2.0, .1, 130.0), PI, Vector3(-2.0, 0, 140.0)],
		[Vector3(0.0, .1, 145.5), -PI * .5, Vector3(30.0, 0, 145.5)], [Vector3(43.0, .1, 152.0), PI, Vector3(43.0, 0, 200.0)],
		[Vector3(43.5, .1, 236.0), PI, Vector3(43.5, 0, 262.0)], [Vector3(44.0, .1, 272.5), PI * .5, Vector3(30.0, 0, 272.5)],
		[Vector3(28.5, .1, 278.0), PI, Vector3(28.5, 0, 305.0)], [Vector3(27.5, .1, 312.0), PI, Vector3(27.5, 0, 380.0)],
		[Vector3(28.0, .1, 408.0), PI, Vector3(28.0, 0, 480.0)]]
	var stuck := []
	for leg: Array in legs:
		var start: Vector3 = leg[0]
		var goal: Vector3 = leg[2]
		var got: Vector3 = await walk(start, leg[1], 150)
		var progress := Vector2(got.x - start.x, got.z - start.z).length()
		if progress < 8.0: stuck.append("%s->%.1f" % [str(start), progress])
	notes.stuck = stuck
	check(stuck.is_empty(), "every stretch can be walked (%s)" % str(stuck))
	# The infected find their way along a lane and round a corner (the nav sees our floors).
	m.nav.space = space
	var path: PackedVector3Array = m.nav.path(o + Vector3(-2.0, 0, 128.0), o + Vector3(6.0, 0, 145.5))
	check(path.size() >= 2 and path[path.size() - 1].distance_to(o + Vector3(6.0, 0, 145.5)) < 1.5, "infected path round the first corner (%d points)" % path.size())
	print("INTERIOR_BACKSTREETS ", JSON.stringify({"passed": failed.is_empty(), "checks": checks, "failures": failed, "notes": notes}))
	quit(0 if failed.is_empty() else 1)
