extends SceneTree
## 0.67: holes in the squad game's world. At every chapter-one teleport and every debug jump, as play leaves the world
## there (the jump settles what is behind; the chapter boards load what is ahead), a walkability flood fill out to
## RADIUS metres round the spot: 0.75 m cells, the player's capsule (standing, or crouching under low roofs), steps
## of 0.45 m, and (`--climb`, on by default) every climb the player's own mantle code allows from each cell. Loose
## props, doors and gates do not stop it (they can be pushed or opened).
## Then every reachable cell's four sides: a side a body can step over (nothing at chest height between) with no
## floor under it for 40 m is an edge over the VOID (a hole in the world: fail); a floor more than 4 m down is a DROP
## (listed, for a look: a fall the squad might not climb back from).
##   godot --headless --path game --script res://tests/coop_hole_audit.gd -- [--only=a,b] [--radius=36] [--no-climb]
## Prints HOLE void|drop <place> <street-local x,y,z> lines, a summary per place and INTERIOR_HOLE_AUDIT ok|FAIL <n>.
const CELL := .75
const STEP := .45
const JUMP_UP := .75
const JUMP_APEX := .8
const STEP_DOWN := 1.2
const GO := ["courtyard", "bridge", "farbank", "warrengate", "plankbridge", "dodonghouse"]
const JUMP := ["ramp", "gate", "storeroad", "mart", "siege", "office", "jonna", "backstreets", "arcade", "brickalley",
	"school", "lobby", "floor2", "floor3", "floor4", "floor5", "horde", "sneak", "field", "heavyarm",
	"outerstreet", "outerbus", "outerplaza", "outerterrace", "outerstation", "outerplatform", "outertunnel", "outerriver",
	"outerpizza", "outermart", "outerboutique", "outerbridge"]
var main
var s
var m
var space: PhysicsDirectSpaceState3D
var stand := CapsuleShape3D.new()
var crouch := CapsuleShape3D.new()
var climber: InteriorPlayer
var climb := true
var radius := 36.0
var only: Array = []
var voids := {}
var drops := {}
var void_rows: Array = []
var drop_rows: Array = []
var climbs_found := 0

func _initialize() -> void: call_deferred("_run")

func frames(n: int) -> void:
	for i in n: await process_frame

func _settled() -> void:
	# (A jump's catch-up starts on the session's next frame: wait for it to begin before waiting for its end.)
	await frames(10)
	for i in 3600:
		var cs = s.get("_chapter_screen")
		if s.get("_catching") != true and (cs == null or not cs.visible) and not bool(s.get("board_open")): break
		await process_frame
	await frames(30)
	for i in 10: await physics_frame

func _key(c: Vector2i, y: float) -> String: return "%d,%d,%d" % [c.x, c.y, roundi(y * 1.5)]
func _cell_of(x: float, z: float) -> Vector2i: return Vector2i(floori(x / CELL), floori(z / CELL))
func _centre(c: Vector2i) -> Vector2: return Vector2((c.x + .5) * CELL, (c.y + .5) * CELL)

func _solid(hit: Dictionary) -> bool:
	var body: Object = hit.get("collider")
	if body == null: return false
	if body is RigidBody3D or body is AnimatableBody3D or body is CharacterBody3D or body is PhysicalBone3D: return false
	if body is Node and ((body as Node).is_in_group("interior_doors") or (body as Node).get_parent() is InteriorPushGate): return false
	return true

func _floor(x: float, z: float, y: float, up := STEP) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, y + up + .05, z), Vector3(x, y - 1.6, z), 6)
	var exclude: Array[RID] = []
	for attempt in 5:
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty(): return NAN
		if _solid(hit):
			if (hit.normal as Vector3).y < .6: return NAN
			return (hit.position as Vector3).y
		exclude.append(hit.rid)
	return NAN

func _fits(x: float, z: float, floor_y: float) -> int:
	for i in 2:
		var shape: CapsuleShape3D = stand if i == 0 else crouch
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.collision_mask = 6
		query.margin = .02
		query.transform = Transform3D(Basis.IDENTITY, Vector3(x, floor_y + .2 + shape.height * .5, z))
		var blocked := false
		for hit in space.intersect_shape(query, 16):
			if _solid(hit):
				blocked = true
				break
		if not blocked: return i + 1
	return 0

func _passes(from: Vector2, to: Vector2, y: float) -> bool:
	for t: float in [.25, .5, .75]:
		var p := from.lerp(to, t)
		if _fits(p.x, p.y, y) == 0: return false
	return true

## What is under (x, z) below `y`: the first solid floor's height within 40 m, or NAN.
func _landing(x: float, z: float, y: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, y + .3, z), Vector3(x, y - 40.0, z), 6)
	var exclude: Array[RID] = []
	for attempt in 6:
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty(): return NAN
		if _solid(hit): return (hit.position as Vector3).y
		exclude.append(hit.rid)
	return NAN

func _fill(place: String, seed: Vector3) -> void:
	var c0 := _cell_of(seed.x, seed.z)
	var y0 := _floor(seed.x, seed.z, seed.y + .2, .8)
	if is_nan(y0):
		print("HOLE_SEED no floor under %s (%s)" % [place, str(_local(seed))])
		return
	var queue: Array = [[c0, y0]]
	var seen := {}
	var cells := {}
	var head := 0
	var t0 := Time.get_ticks_msec()
	while head < queue.size():
		var item: Array = queue[head]
		head += 1
		var c: Vector2i = item[0]
		var y: float = item[1]
		var key := _key(c, y)
		if seen.has(key): continue
		seen[key] = true
		var p := _centre(c)
		if Vector2(seed.x, seed.z).distance_to(p) > radius: continue
		if _fits(p.x, p.y, y) == 0: continue
		cells[key] = [c, y]
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + off
			var q := _centre(n)
			var fy := _floor(q.x, q.y, y, JUMP_UP if climb else STEP)
			if is_nan(fy): continue
			if climb:
				if fy - y > JUMP_UP or y - fy > STEP_DOWN: continue
			elif absf(fy - y) > STEP: continue
			if seen.has(_key(n, fy)): continue
			if not _passes(p, q, maxf(y, fy)): continue
			queue.append([n, fy])
		if climb: _climbs(p, y, queue, seen)
	var nv := 0
	var nd := 0
	for k: String in cells:
		var c: Vector2i = cells[k][0]
		var y: float = cells[k][1]
		var here := _centre(c)
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := _centre(c + off)
			var near := _floor(q.x, q.y, y)
			if not is_nan(near) and absf(near - y) <= STEP: continue
			var above := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, y + 1.3, q.y), Vector3(q.x, y + .05, q.y), 6))
			if not above.is_empty() and (above.normal as Vector3).y > .6: continue
			if _fits(q.x, q.y, y) == 0 or not _passes(here, q, y): continue
			var landed := _landing(q.x, q.y, y)
			var at := _local(Vector3(q.x, y, q.y)).snapped(Vector3.ONE * .1)
			var spot := "%d,%d,%d" % [roundi(q.x), roundi(y), roundi(q.y)]
			if is_nan(landed):
				nv += 1
				if not voids.has(spot):
					voids[spot] = place
					void_rows.append([place, at])
					print("HOLE void %s %s" % [place, str(at)])
			elif y - landed > 4.0:
				nd += 1
				if not drops.has(spot):
					drops[spot] = place
					drop_rows.append([place, at, snappedf(y - landed, .1)])
					print("HOLE drop %s %s fall %.1f m" % [place, str(at), y - landed])
	print("HOLE_PLACE %s cells %d voids %d drops %d climbs %d (%d ms)" % [place, cells.size(), nv, nd, climbs_found, Time.get_ticks_msec() - t0])
	climbs_found = 0

func _climbs(p: Vector2, y: float, queue: Array, seen: Dictionary) -> void:
	for turn in 8:
		var yaw := TAU * turn / 8.0
		for grounded: bool in [true, false]:
			climber.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y + (0.0 if grounded else JUMP_APEX), p.y))
			climber.force_update_transform()
			climber.mantling = false
			if not climber._try_mantle(grounded): continue
			var mt: Dictionary = climber._mantle
			var to: Vector3 = mt.to
			climber.mantling = false
			climber.crouching = false
			climber._capsule.height = InteriorPlayer.STANDING_HEIGHT
			climber._collision.position.y = InteriorPlayer.STANDING_HEIGHT * .5
			var cell := _cell_of(to.x, to.z)
			if seen.has(_key(cell, to.y)): continue
			climbs_found += 1
			queue.append([cell, to.y])

func _local(w: Vector3) -> Vector3: return w - m.Street.ORIGIN

func _quiet() -> void:
	for k in m.enemies.keys():
		if m.enemies[k].has_meta("boss"): continue
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	m.wave_left = 0
	m.next_spawn = 9999.0

func _audit(place: String) -> void:
	_quiet()
	for i in 5: await physics_frame
	var seed: Vector3 = main.player.global_position
	space = main.player.get_world_3d().direct_space_state
	# (Kept in the physics space while its processing is off: the mantle probe moves it by test motions.)
	main.player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	main.player.process_mode = Node.PROCESS_MODE_DISABLED
	_fill(place, seed)
	main.player.process_mode = Node.PROCESS_MODE_INHERIT
	main.player.reset_motion(seed)
	await frames(2)

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = Array(a.trim_prefix("--only=").split(","))
		if a.begins_with("--radius="): radius = float(a.trim_prefix("--radius="))
		if a == "--no-climb": climb = false
	stand.radius = .24
	stand.height = 1.45
	crouch.radius = .24
	crouch.height = .8
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	s = main.coop
	s.host()
	s.add_bot()
	s.start_game()
	await frames(40)
	m = s.mission
	m.harmless = true
	s.harmless = true
	climber = main.player
	for place in GO:
		if not only.is_empty() and not place in only: continue
		print("HOLE > go ", place, " -> ", m.debug_command(1, "go " + place))
		await frames(30)
		await _audit("go " + place)
	for place in JUMP:
		if not only.is_empty() and not place in only: continue
		print("HOLE > jump ", place, " -> ", m.debug_command(1, "jump " + place))
		await _settled()
		await _audit("jump " + place)
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../work/v67/holes.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"voids": void_rows.map(func(r): return [r[0], str(r[1])]), "drops": drop_rows.map(func(r): return [r[0], str(r[1]), r[2]])}, "\t"))
	print("INTERIOR_HOLE_AUDIT ", ("ok" if voids.is_empty() else "FAIL"), " voids %d drops %d" % [voids.size(), drops.size()])
	s.end_session()
	quit(0 if voids.is_empty() else 1)
