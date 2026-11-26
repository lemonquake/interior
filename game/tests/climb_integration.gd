extends SceneTree
## 0.34: can the body of 0.33 get out of the world? Headless:
##   godot --headless --path game --script res://tests/climb_integration.gd --fixed-fps 60
## The walkability fill of tests/world_audit.gd, twice over the whole world: once on foot as before, once with
## everything 0.33 added (a jump up, a step down that can be climbed again, and every climb, catch off a jump and
## vault the player's own code allows from each cell). The sealed places of tests/seals_integration.gd must stay
## sealed, there must be no edge to step off into nothing, and the ground only climbing reaches is listed in
## clusters (work/v34/climb/climb_only.csv) so it can be looked at.

const Audit := preload("res://tests/world_audit.gd")
const Seals := preload("res://tests/seals_integration.gd")

var checks := 0
var failures: Array[String] = []
var results := {}

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures.append(message)

func _nearest(audit: Object, at: Vector3, also: Dictionary = {}) -> float:
	var best := 1e9
	for set_: Dictionary in [audit.cells, also]:
		for key in set_:
			var cell: Dictionary = set_[key]
			var p: Vector2 = audit._centre(cell.c)
			best = minf(best, Vector2(at.x, at.z).distance_to(p) + absf(float(cell.y) - at.y) * .5)
	return best

func _audit(player: InteriorPlayer, climbing: bool) -> Object:
	var audit: Object = Audit.new()
	audit.space = player.get_world_3d().direct_space_state
	audit.out = ProjectSettings.globalize_path("res://../work/v34/climb/" + ("climb" if climbing else "walk"))
	DirAccess.make_dir_recursive_absolute(audit.out)
	audit.region = Seals.WORLD
	audit.want_voids = true
	audit.want_cells = true
	audit.climb = climbing
	audit.climber = player
	audit._fill()
	return audit

func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	for i in 50: await process_frame
	var player: InteriorPlayer = main.player
	# Stopped, but left in the physics world: its own climbing code is asked from every cell.
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var stranger := main.get_node_or_null("Stranger")
	if stranger != null: stranger.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 12: await physics_frame
	var home := player.global_transform

	var walk: Object = _audit(player, false)
	var climb: Object = _audit(player, true)
	player.global_transform = home
	results["walk_cells"] = walk.cells.size()
	results["climb_cells"] = climb.cells.size()
	results["climbs_used"] = climb.climbed.size()
	results["voids"] = climb.void_count
	results["void_spots"] = climb.void_spots.slice(0, 12)
	results["fall_only_cells"] = climb.fallen.size()
	check(climb.cells.size() >= walk.cells.size(), "Climbing reaches at least what walking does (%d cells, %d on foot)" % [climb.cells.size(), walk.cells.size()])
	check(climb.void_count == 0, "No edge to step off into nothing, climbing included (%d found, first %s)" % [climb.void_count, climb.void_spots.slice(0, 4)])
	for label in Seals.REACHED:
		var off := _nearest(climb, Seals.REACHED[label])
		check(off < 2.0, "Still reached: %s (%.1f m)" % [label, off])
	for label in Seals.SEALED:
		var off := _nearest(climb, Seals.SEALED[label], climb.fallen)
		check(off > 1.5, "Still sealed with climbing: %s (a reachable cell %.1f m away)" % [label, off])

	# Every climb that opened new ground: where from, how high, where to.
	var climbs := FileAccess.open(String(climb.out).path_join("climbs.csv"), FileAccess.WRITE)
	climbs.store_line("to_x,to_z,to_level,from_x,from_z,from_y,height,over")
	for key: String in climb.climbed:
		var parts := key.split(",")
		var to: Vector2 = climb._centre(Vector2i(int(parts[0]), int(parts[1])))
		var c: Array = climb.climbed[key]
		climbs.store_line("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d" % [to.x, to.y, float(parts[2]) / 1.5, c[0], c[1], c[2], c[3], 1 if c[4] else 0])
	climbs = null
	# What only climbing reaches, in clusters of touching cells.
	var foot := {}
	for key in walk.cells:
		var cell: Dictionary = walk.cells[key]
		foot[Vector3i(cell.c.x, cell.c.y, roundi(float(cell.y) * 1.5))] = true
	var extra := {}
	for set_: Dictionary in [climb.cells, climb.fallen]:
		for key in set_:
			var cell: Dictionary = set_[key]
			var id := Vector3i(cell.c.x, cell.c.y, roundi(float(cell.y) * 1.5))
			var known := false
			for level in [-1, 0, 1]:
				known = known or foot.has(id + Vector3i(0, 0, level))
			if not known:
				extra[id] = cell
	var clusters: Array = []
	var done := {}
	for id: Vector3i in extra:
		if done.has(id):
			continue
		var group: Array = []
		var todo: Array = [id]
		done[id] = true
		while not todo.is_empty():
			var at: Vector3i = todo.pop_back()
			group.append(at)
			for off: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
				for level in [-2, -1, 0, 1, 2]:
					var next := at + off + Vector3i(0, 0, level)
					if extra.has(next) and not done.has(next):
						done[next] = true
						todo.append(next)
		var low := Vector3(1e9, 1e9, 1e9)
		var high := Vector3(-1e9, -1e9, -1e9)
		for at: Vector3i in group:
			var cell: Dictionary = extra[at]
			var p: Vector2 = climb._centre(cell.c)
			low = low.min(Vector3(p.x, float(cell.y), p.y))
			high = high.max(Vector3(p.x, float(cell.y), p.y))
		clusters.append([group.size(), low, high])
	clusters.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var file := FileAccess.open(String(climb.out).path_join("climb_only.csv"), FileAccess.WRITE)
	file.store_line("cells,x0,z0,x1,z1,y0,y1")
	for cluster: Array in clusters:
		var low: Vector3 = cluster[1]
		var high: Vector3 = cluster[2]
		file.store_line("%d,%.1f,%.1f,%.1f,%.1f,%.2f,%.2f" % [cluster[0], low.x, low.z, high.x, high.z, low.y, high.y])
	file = null
	results["climb_only_cells"] = extra.size()
	results["climb_only_clusters"] = clusters.size()
	for cluster: Array in clusters.slice(0, 25):
		var low: Vector3 = cluster[1]
		var high: Vector3 = cluster[2]
		print("CLIMB_ONLY %5d cells  x %.1f..%.1f  z %.1f..%.1f  y %.2f..%.2f" % [cluster[0], low.x, high.x, low.z, high.z, low.y, high.y])
	# The world the body can reach is still the world: the far sides stay shut.
	var world := Rect2(-123.0, -131.0, 180.0, 660.0)
	var outside := 0
	var first := []
	for id: Vector3i in extra:
		var p: Vector2 = climb._centre((extra[id] as Dictionary).c)
		if not world.has_point(p):
			outside += 1
			if first.size() < 4:
				first.append(p.snapped(Vector2.ONE * .1))
	check(outside == 0, "Nothing reached by climbing lies beyond the edge of the world (%d cells, first %s)" % [outside, first])
	walk.free()
	climb.free()
	print("INTERIOR_CLIMB ", JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures, "results": results}))
	quit(1 if not failures.is_empty() else 0)
