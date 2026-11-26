extends SceneTree
## 0.56: every box, cylinder and chair PILCST lays down (school.gd `auditing`), checked for two faults:
##  - FLOAT: something standing in the air: nothing under its bottom (no collider within a few cm, and no other
##    piece whose top it rests on), and it is not on a wall or under the ceiling;
##  - GHOST: something a body would walk into (standing on the floor, knee-high or more, wider than a hand) with no
##    collider anywhere in it.
## Grouped by the line that laid it. Exit code 1 when anything is found (`--report` only prints).
##   godot --headless --path game --script res://tests/school_props_audit.gd [-- --report] [-- --list]
var game
const THIN := .13

func _initialize() -> void: run.call_deferred()

static func box_aabb(at: Vector3, size: Vector3, basis: Basis) -> AABB:
	var h := size * .5
	var out := AABB(at, Vector3.ZERO)
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				out = out.expand(at + basis * Vector3(h.x * sx, h.y * sy, h.z * sz))
	return out

func run() -> void:
	var report := "--report" in OS.get_cmdline_user_args()
	var listing := "--list" in OS.get_cmdline_user_args()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	var s = game.coop
	s.host()
	s.start_game()
	for i in 10: await physics_frame
	var m = s.mission
	s.harmless = true
	m.SCHOOL.auditing = true
	m.debug_jump("floor2")
	m.SCHOOL.auditing = false
	for i in 20: await physics_frame
	var school = m.school
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var off: Vector3 = school.s.position
	var H: float = school.H
	# Every piece as a world box: [aabb, item]
	var pieces: Array = []
	for it: Dictionary in school.audit:
		var r: int = it.r
		if r >= 5 and r < 10: continue   # lights, decals, words
		pieces.append([box_aabb(it.at + off, it.size, it.basis), it])
	# The chairs (one mesh for all: legs to the floor at y 0, the back up to .91).
	for k in school._chairs.size():
		for t: Transform3D in school._chairs[k]:
			var a := AABB(t.origin, Vector3.ZERO)
			for c in [Vector3(-.22, 0, -.21), Vector3(.22, 0, -.21), Vector3(-.22, 0, .25), Vector3(.22, 0, .25), Vector3(-.22, .91, -.21), Vector3(.22, .91, -.21), Vector3(-.22, .91, .25), Vector3(.22, .91, .25), Vector3(.36, .7, -.28), Vector3(.36, .7, .18)]:
				a = a.expand(t * c)
			a.position += off
			pieces.append([a, {"r": k, "kind": "chair", "collide": false, "who": "chair", "id": "chair"}])
	# 501's barricade (pieces of their own).
	if school._barricade_501 != null:
		for d in school._barricade_501.get_children():
			if d is MeshInstance3D:
				pieces.append([(d as MeshInstance3D).global_transform * (d as MeshInstance3D).get_aabb(), {"r": 4, "kind": "piece", "collide": false, "who": "501 barricade", "id": "desk"}])
	var floats := {}
	var ghosts := {}
	var examples := {}
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 2 | 4
	var fit := PhysicsShapeQueryParameters3D.new()
	var probe := BoxShape3D.new()
	fit.shape = probe
	fit.collision_mask = 2 | 4
	for p: Array in pieces:
		var a: AABB = p[0]
		var it: Dictionary = p[1]
		var r: int = it.r
		var ext := a.size
		var thin := minf(ext.x, ext.z) < THIN
		var bottom := a.position.y
		var top := a.end.y
		var floor_y := (r * H + off.y) if r < 5 else NAN
		var near_ceiling := r < 5 and top > floor_y + 2.75
		# --- floating
		if not thin and not near_ceiling and ext.y > .015 and (is_nan(floor_y) or bottom > floor_y + .045):
			var held := false
			var c := a.get_center()
			for q in [Vector2.ZERO, Vector2(-.3, -.3), Vector2(.3, -.3), Vector2(-.3, .3), Vector2(.3, .3)]:
				var at := Vector3(c.x + q.x * ext.x, bottom + .03, c.z + q.y * ext.z)
				ray.from = at
				ray.to = at + Vector3.DOWN * .12
				if not space.intersect_ray(ray).is_empty():
					held = true
					break
			if not held:
				for o: Array in pieces:
					var b: AABB = o[0]
					if o[1] == it: continue
					if b.end.y < bottom - .1 or b.end.y > bottom + .03: continue
					if b.position.x > a.end.x - .02 or b.end.x < a.position.x + .02 or b.position.z > a.end.z - .02 or b.end.z < a.position.z + .02: continue
					held = true
					break
			if not held:
				var key: String = it.who
				floats[key] = int(floats.get(key, 0)) + 1
				if not examples.has("F " + key): examples["F " + key] = [a.get_center() - off, it.id]
		# --- ghost blocker
		if not it.collide and ext.y > .45 and minf(ext.x, ext.z) > .2 and maxf(ext.x, ext.z) > .3 and (is_nan(floor_y) or bottom < floor_y + .4):
			probe.size = ext * .7
			fit.transform = Transform3D(Basis.IDENTITY, a.get_center())
			if space.intersect_shape(fit, 1).is_empty():
				var key: String = it.who
				ghosts[key] = int(ghosts.get(key, 0)) + 1
				if not examples.has("G " + key): examples["G " + key] = [a.get_center() - off, it.id]
	var nf := 0
	var ng := 0
	for k in floats: nf += int(floats[k])
	for k in ghosts: ng += int(ghosts[k])
	print("SCHOOL_PROPS pieces %d  floating %d  ghost blockers %d" % [pieces.size(), nf, ng])
	var fk: Array = floats.keys()
	fk.sort_custom(func(x, y): return int(floats[x]) > int(floats[y]))
	for k in fk: print("SCHOOL_PROPS FLOAT %4d  %s  e.g. %s %s" % [int(floats[k]), k, str((examples["F " + k][0] as Vector3).snapped(Vector3.ONE * .01)), examples["F " + k][1]])
	var gk: Array = ghosts.keys()
	gk.sort_custom(func(x, y): return int(ghosts[x]) > int(ghosts[y]))
	for k in gk: print("SCHOOL_PROPS GHOST %4d  %s  e.g. %s %s" % [int(ghosts[k]), k, str((examples["G " + k][0] as Vector3).snapped(Vector3.ONE * .01)), examples["G " + k][1]])
	if listing: pass
	s.end_session()
	quit(0 if report or (nf == 0 and ng == 0) else 1)
