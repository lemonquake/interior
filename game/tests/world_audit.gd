extends SceneTree
## 0.23 world audit: where can the player actually walk, and where is the town just empty space?
##   Godot --path game --script res://tests/world_audit.gd -- [--out=<dir>] [--no-map] [--no-fill]
## 1. Top-down orthographic maps (work light) of the town, the canal, the Nichols estate and the road out.
## 2. A walkability flood fill on a 0.75 m grid from the lane outside the courtyard gate: every cell the
##    standing (or, where the roof is low, crouching) capsule fits on a floor reached by a step of at most
##    0.45 m. Loose props, chairs and gates are ignored (they can be pushed or opened).
## 3. Clearance: for each reachable cell, the distance to the nearest unwalkable cell. Cells with more than
##    OPEN_CLEARANCE metres of free floor all round are "vast emptiness"; they are clustered and reported.
## 4. Geodesic distance from the gate to each key area, so the audit can say whether it is reachable at all.
## Writes audit.json, reach.png (the fill coloured by clearance) and the map PNGs.

const CELL := .75
const REGION := Rect2(-130.0, -136.0, 190.0, 200.0)   # x -130..60, z -136..64 (fields excluded past z 64)
const OPEN_CLEARANCE := 5.0
const STEP := .45
const KEYS := {
	"courtyard gate (outside)": Vector3(14.0, -2.9, 4.6),
	"street A / B corner": Vector3(21.0, -2.9, 18.0),
	"road to the rice fields": Vector3(21.0, -2.9, 60.0),
	"canal settlement (street A mouth)": Vector3(-30.0, -2.9, 18.4),
	"canal catwalk": Vector3(-60.0, -4.4, 20.0),
	"warren entry (z 8)": Vector3(-86.0, -2.05, 8.0),
	"Nichols gate": Vector3(-12.0, -2.9, -58.0),
	"Nichols porch": Vector3(-12.0, -1.7, -76.0),
}

## 0.26: doorways narrower than the grid can resolve (a 0.96 m tin door between two posts). The fill is continued
## from just inside each one, provided the cell just outside it was reached. [outside, inside]
const PORTALS := [
	[Vector3(-93.2, -2.1, 8.0), Vector3(-95.6, -2.1, 8.0)],      # warren entry sheet
	[Vector3(-92.6, -2.1, 54.7), Vector3(-95.0, -2.1, 54.7)],    # warren exit sheet
	[Vector3(-12.0, -1.7, -77.9), Vector3(-12.0, -1.7, -84.5)],  # the Nichols porch and front door
]

var main: Node
var out := "res://../work/v23/audit"
var space: PhysicsDirectSpaceState3D
var stand := CapsuleShape3D.new()
var crouch := CapsuleShape3D.new()
## false: only where a standing body goes (tests/siege_integration.gd checks the wall closes the town that way).
var allow_crouch := true
var nx := 0
var nz := 0
## 0.26: `--voids` / `--cells`, or set by a test: look for edges to step off, write the cell dump.
var want_voids := false
var want_cells := false
var void_count := 0
var drop_count := 0
## Ground reached only by a fall of more than 1.2 m.
var fallen := {}
## [x, z, y] of every void edge found.
var void_spots: Array = []
## 0.26: also test the way between neighbouring cells (off: the 0.23 behaviour, which could hop a thin sheet).
var strict := true
## 0.26: the audited rectangle; `--region=x,z,w,h` widens it (the rice fields lie north of z 64).
var region := REGION
## 0.34: also go where the body of 0.33 can: a jump up of three quarters of a metre, a step down of 1.2 m (it can
## be climbed again), and every climb, catch off a jump and vault scripts/player.gd would allow from a cell, asked of
## the player itself (`climber`). tests/climb_integration.gd.
var climb := false
var climber: InteriorPlayer
const JUMP_UP := .75
const JUMP_APEX := .8
const STEP_DOWN := 1.2
## Cells first reached by a climb, a catch or a vault: key -> [from x, from z, from y, height, over].
var climbed := {}
## key "ix,iz,ylevel" -> {y, crouch, dist}
var cells := {}

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n: await process_frame

func _run() -> void:
	var want_map := true
	var want_fill := true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg == "--no-map": want_map = false
		if arg == "--no-fill": want_fill = false
		if arg == "--voids": want_voids = true
		if arg == "--cells": want_cells = true
		if arg.begins_with("--region="):
			var v := arg.trim_prefix("--region=").split_floats(",")
			if v.size() == 4: region = Rect2(v[0], v[1], v[2], v[3])
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(2048, 2048)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(10)
	var player: InteriorPlayer = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var stranger := main.get_node_or_null("Stranger")
	if stranger != null: stranger.process_mode = Node.PROCESS_MODE_DISABLED
	for layer: CanvasLayer in main.find_children("*", "CanvasLayer", true, false): layer.visible = false
	# Let the deferred runtime builders (interactions, chairs, the 0.23 siege) finish and physics settle.
	await frames(30)
	for i in 10: await physics_frame
	space = player.get_world_3d().direct_space_state
	var report := {}
	if want_fill:
		report = _fill()
	if want_map:
		_work_light()
		var camera: Camera3D = player.camera
		await _map(camera, "map-town", Vector3(0, 0, 18), 110.0)
		await _map(camera, "map-west", Vector3(-75, 0, 25), 120.0)
		await _map(camera, "map-south", Vector3(-8, 0, -75), 130.0)
		await _map(camera, "map-wide", Vector3(-35, 0, -30), 210.0)
	var file := FileAccess.open(out.path_join("audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("WORLD_AUDIT ", JSON.stringify(report.get("summary", {})))
	print("WORLD_AUDIT_COMPLETE")
	quit()

# ------------------------------------------------------------------------------------------------ the fill

func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - region.position.x) / CELL), floori((p.z - region.position.y) / CELL))

func _centre(c: Vector2i) -> Vector2:
	return Vector2(region.position.x + (c.x + .5) * CELL, region.position.y + (c.y + .5) * CELL)

func _solid(hit: Dictionary) -> bool:
	var body: Object = hit.get("collider")
	if body == null: return false
	if body is RigidBody3D or body is AnimatableBody3D: return false
	if body is Node and ((body as Node).is_in_group("interior_doors") or (body as Node).get_parent() is InteriorPushGate): return false
	return true

## The floor under (x, z) within reach of a body standing at `y`, or NAN.
func _floor(x: float, z: float, y: float, up := STEP) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, y + up + .05, z), Vector3(x, y - 1.6, z), 6)
	var exclude: Array[RID] = []
	for attempt in 4:
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty(): return NAN
		if _solid(hit):
			if (hit.normal as Vector3).y < .6: return NAN
			return (hit.position as Vector3).y
		exclude.append(hit.rid)
	return NAN

## 0 = blocked, 1 = standing fits, 2 = only crouching fits.
func _fits(x: float, z: float, floor_y: float) -> int:
	for pass_index in (2 if allow_crouch else 1):
		var shape: CapsuleShape3D = stand if pass_index == 0 else crouch
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.collision_mask = 6
		query.margin = .02
		# Lifted 0.2 m: the player rides up sloped kerb edges, which a capsule resting on the floor would clip.
		query.transform = Transform3D(Basis.IDENTITY, Vector3(x, floor_y + .2 + shape.height * .5, z))
		var blocked := false
		for hit in space.intersect_shape(query, 16):
			if _solid(hit):
				blocked = true
				break
		if not blocked:
			return pass_index + 1
	return 0

## Breadth-first walk from the queued [cell, floor y, metres so far] items into `into`.
func _flood(queue: Array, seen: Dictionary, into: Dictionary) -> void:
	var head := 0
	while head < queue.size():
		var item: Array = queue[head]
		head += 1
		var c: Vector2i = item[0]
		var y: float = item[1]
		var key := "%d,%d,%d" % [c.x, c.y, roundi(y * 1.5)]
		if seen.has(key): continue
		var p := _centre(c)
		var fit := _fits(p.x, p.y, y)
		seen[key] = true
		if fit == 0: continue
		into[key] = {"c": c, "y": y, "crouch": fit == 2, "d": item[2]}
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + off
			if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= nz: continue
			var q := _centre(n)
			var fy := _floor(q.x, q.y, y, JUMP_UP if climb else STEP)
			if is_nan(fy): continue
			if climb:
				if fy - y > JUMP_UP or y - fy > STEP_DOWN: continue
			elif absf(fy - y) > STEP: continue
			var nkey := "%d,%d,%d" % [n.x, n.y, roundi(fy * 1.5)]
			if not seen.has(nkey):
				# 0.26: nothing thin (a sheet, a rail) may stand between the two cell centres.
				if strict and not _passes(p, q, maxf(y, fy)): continue
				queue.append([n, fy, float(item[2]) + CELL])
		if climb and climber != null:
			_climbs(p, y, float(item[2]), queue, seen)

## Every climb the player's own code allows from the middle of a cell: eight ways to face, from the ground and
## from the top of a jump.
func _climbs(p: Vector2, y: float, so_far: float, queue: Array, seen: Dictionary) -> void:
	for turn in 8:
		var yaw := TAU * turn / 8.0
		for grounded: bool in [true, false]:
			climber.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y + (0.0 if grounded else JUMP_APEX), p.y))
			climber.force_update_transform()
			climber.mantling = false
			if not climber._try_mantle(grounded):
				continue
			var m: Dictionary = climber._mantle
			var to: Vector3 = m.to
			climber.mantling = false
			climber.crouching = false
			climber._capsule.height = InteriorPlayer.STANDING_HEIGHT
			climber._collision.position.y = InteriorPlayer.STANDING_HEIGHT * .5
			var cell := _cell_of(to)
			if cell.x < 0 or cell.y < 0 or cell.x >= nx or cell.y >= nz:
				continue
			var key := "%d,%d,%d" % [cell.x, cell.y, roundi(to.y * 1.5)]
			if seen.has(key) or climbed.has(key):
				continue
			climbed[key] = [snappedf(p.x, .01), snappedf(p.y, .01), snappedf(y, .01), snappedf(float(m.height) + (0.0 if grounded else JUMP_APEX), .01), bool(m.over)]
			queue.append([cell, to.y, so_far + 1.5])

## True when a body can actually slide from one cell centre to the next at floor `y` (no rail or sheet between).
func _passes(from: Vector2, to: Vector2, y: float) -> bool:
	for t: float in [.25, .5, .75]:
		var p := from.lerp(to, t)
		if _fits(p.x, p.y, y) == 0: return false
	return true

func _fill() -> Dictionary:
	# Tops at 1.65 m (standing) and 1.0 m (crouching) above the floor, like the player's capsule.
	stand.radius = .24
	stand.height = 1.45
	crouch.radius = .24
	crouch.height = .8
	nx = ceili(region.size.x / CELL)
	nz = ceili(region.size.y / CELL)
	var start := KEYS["courtyard gate (outside)"] as Vector3
	var c0 := _cell_of(start)
	var y0 := _floor(start.x, start.z, start.y)
	var seen := {}
	var begin := Time.get_ticks_msec()
	_flood([[c0, y0, 0.0]], seen, cells)
	for portal: Array in PORTALS:
		var outside: Vector3 = portal[0]
		var inside: Vector3 = portal[1]
		var from_d := -1.0
		for k in cells:
			if _centre(cells[k].c).distance_to(Vector2(outside.x, outside.z)) < 1.2 and absf(float(cells[k].y) - outside.y) < .6:
				from_d = float(cells[k].d)
				break
		var fy := _floor(inside.x, inside.z, inside.y)
		if from_d >= 0.0 and not is_nan(fy):
			_flood([[_cell_of(inside), fy, from_d + 2.4]], seen, cells)
	print("FILL cells ", cells.size(), " in ", Time.get_ticks_msec() - begin, " ms")
	if want_voids:
		# 0.26: edges the player can step off. "void": nothing under the next cell for 9 m (a hole in the world).
		# "drop": a floor more than 1.2 m lower (a one-way fall); the ground only reached by such a fall is then
		# walked too ("fall" rows in cells.csv), because a place you can drop into and not leave is a trap.
		var voids := FileAccess.open(out.path_join("voids.csv"), FileAccess.WRITE)
		voids.store_line("kind,x,z,y,fall,from_x,from_z")
		void_count = 0
		drop_count = 0
		void_spots.clear()
		fallen.clear()
		var landings: Array = []
		for k in cells.keys():
			var c: Vector2i = cells[k].c
			var y: float = cells[k].y
			var here := _centre(c)
			for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := c + off
				if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= nz: continue
				var q := _centre(n)
				var near := _floor(q.x, q.y, y)
				if not is_nan(near) and absf(near - y) <= STEP: continue
				# A floor right overhead (the lip of a higher terrace) is a step up, not an edge.
				var above := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, y + 1.3, q.y), Vector3(q.x, y + .05, q.y), 6))
				if not above.is_empty() and (above.normal as Vector3).y > .6: continue
				if _fits(q.x, q.y, y) == 0 or not _passes(here, q, y): continue
				var query := PhysicsRayQueryParameters3D.create(Vector3(q.x, y + .3, q.y), Vector3(q.x, y - 14.0, q.y), 6)
				var exclude: Array[RID] = []
				var landed := NAN
				for attempt in 4:
					query.exclude = exclude
					var hit := space.intersect_ray(query)
					if hit.is_empty(): break
					if _solid(hit):
						landed = (hit.position as Vector3).y
						break
					exclude.append(hit.rid)
				if is_nan(landed) or landed < -12.0:
					void_count += 1
					void_spots.append([snappedf(q.x, .01), snappedf(q.y, .01), snappedf(y, .01)])
					voids.store_line("void,%.2f,%.2f,%.2f,14,%.2f,%.2f" % [q.x, q.y, y, here.x, here.y])
				elif y - landed > 1.2:
					drop_count += 1
					voids.store_line("drop,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f" % [q.x, q.y, y, y - landed, here.x, here.y])
					landings.append([n, landed, 0.0])
		_flood(landings, seen, fallen)
		print("WORLD_AUDIT_VOIDS void=", void_count, " drop=", drop_count, " fall_only_cells=", fallen.size())
		var fall_dump := FileAccess.open(out.path_join("fall_cells.csv"), FileAccess.WRITE)
		fall_dump.store_line("x,z,y,crouch,d")
		for k in fallen:
			var centre := _centre(fallen[k].c)
			fall_dump.store_line("%.3f,%.3f,%.2f,%d,%.1f" % [centre.x, centre.y, fallen[k].y, 1 if fallen[k].crouch else 0, fallen[k].d])
	if want_cells:
		# 0.26: every reached cell (centre x, z, floor y, crouch-only, walking distance from the gate).
		var dump := FileAccess.open(out.path_join("cells.csv"), FileAccess.WRITE)
		dump.store_line("x,z,y,crouch,d")
		for k in cells:
			var centre := _centre(cells[k].c)
			dump.store_line("%.3f,%.3f,%.2f,%d,%.1f" % [centre.x, centre.y, cells[k].y, 1 if cells[k].crouch else 0, cells[k].d])
	# Clearance (per 2D column; multi-level spots take the lowest walkable level's grid): multi-source BFS
	# from every unwalkable cell bordering a walkable one.
	var walk := PackedByteArray()
	walk.resize(nx * nz)
	for k in cells:
		var c: Vector2i = cells[k].c
		walk[c.y * nx + c.x] = 1
	var dist := PackedFloat32Array()
	dist.resize(nx * nz)
	dist.fill(1e9)
	var frontier: Array[int] = []
	for i in nx * nz:
		if walk[i] == 0:
			dist[i] = 0.0
			frontier.append(i)
	var fh := 0
	while fh < frontier.size():
		var i := frontier[fh]
		fh += 1
		var cx := i % nx
		var cz := i / nx
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var mx := cx + off.x
			var mz := cz + off.y
			if mx < 0 or mz < 0 or mx >= nx or mz >= nz: continue
			var j := mz * nx + mx
			if dist[j] > dist[i] + CELL:
				dist[j] = dist[i] + CELL
				frontier.append(j)
	# Open patches: connected walkable cells with clearance >= OPEN_CLEARANCE.
	var open_seen := {}
	var patches: Array = []
	for i in nx * nz:
		if walk[i] == 0 or dist[i] < OPEN_CLEARANCE or open_seen.has(i): continue
		var stack: Array[int] = [i]
		open_seen[i] = true
		var count := 0
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		var peak := 0.0
		while not stack.is_empty():
			var j: int = stack.pop_back()
			count += 1
			var p := _centre(Vector2i(j % nx, j / nx))
			lo = lo.min(p)
			hi = hi.max(p)
			peak = maxf(peak, dist[j])
			for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var mx := j % nx + off.x
				var mz := j / nx + off.y
				if mx < 0 or mz < 0 or mx >= nx or mz >= nz: continue
				var m := mz * nx + mx
				if walk[m] == 1 and dist[m] >= OPEN_CLEARANCE and not open_seen.has(m):
					open_seen[m] = true
					stack.append(m)
		patches.append({"cells": count, "area_m2": snappedf(count * CELL * CELL, .1), "x": [snappedf(lo.x, .1), snappedf(hi.x, .1)],
			"z": [snappedf(lo.y, .1), snappedf(hi.y, .1)], "peak_clearance": snappedf(peak, .1)})
	patches.sort_custom(func(a, b): return a.cells > b.cells)
	# Key areas: geodesic metres from the gate (nearest walkable cell within 2 m), or "unreachable".
	var keys := {}
	for label in KEYS:
		var at: Vector3 = KEYS[label]
		var best := -1.0
		var best_off := 1e9
		for k in cells:
			var cell: Dictionary = cells[k]
			var p := _centre(cell.c)
			var off := Vector2(at.x, at.z).distance_to(p) + absf(float(cell.y) - at.y) * .5
			if off < 2.0 and off < best_off:
				best_off = off
				best = cell.d
		keys[label] = snappedf(best, .1) if best >= 0.0 else "unreachable"
	var crouch_cells := 0
	for k in cells:
		if cells[k].crouch: crouch_cells += 1
	_draw_reach(walk, dist)
	return {"summary": {"walkable_cells": cells.size(), "walkable_m2": snappedf(cells.size() * CELL * CELL, 1.0),
		"crouch_only_cells": crouch_cells, "open_patches": patches.size(),
		"open_m2": snappedf(patches.reduce(func(s, p): return s + p.area_m2, 0.0), 1.0)},
		"keys": keys, "open_patches": patches.slice(0, 40)}

func _draw_reach(walk: PackedByteArray, dist: PackedFloat32Array) -> void:
	var scale := 4
	var image := Image.create(nx * scale, nz * scale, false, Image.FORMAT_RGB8)
	image.fill(Color(.08, .08, .09))
	var crouch_cols := {}
	for k in cells:
		if cells[k].crouch:
			var c: Vector2i = cells[k].c
			crouch_cols[c.y * nx + c.x] = true
	for i in nx * nz:
		if walk[i] == 0: continue
		var colour := Color(.42, .45, .48)
		if crouch_cols.has(i): colour = Color(.2, .55, 1.0)
		elif dist[i] >= OPEN_CLEARANCE + 2.0: colour = Color(.95, .1, .1)
		elif dist[i] >= OPEN_CLEARANCE: colour = Color(1.0, .55, .1)
		elif dist[i] >= 3.0: colour = Color(.75, .7, .35)
		image.fill_rect(Rect2i((i % nx) * scale, (i / nx) * scale, scale, scale), colour)
	# Grid lines every 10 m, labels are in audit.json.
	for gx in range(ceili(region.position.x / 10.0) * 10, int(region.end.x), 10):
		var px := int((gx - region.position.x) / CELL * scale)
		image.fill_rect(Rect2i(px, 0, 1, nz * scale), Color(.2, .3, .2) if gx != 0 else Color(.2, .8, .2))
	for gz in range(ceili(region.position.y / 10.0) * 10, int(region.end.y), 10):
		var pz := int((gz - region.position.y) / CELL * scale)
		image.fill_rect(Rect2i(0, pz, nx * scale, 1), Color(.2, .3, .2) if gz != 0 else Color(.2, .8, .2))
	for label in KEYS:
		var c := _cell_of(KEYS[label])
		image.fill_rect(Rect2i(c.x * scale - 4, c.y * scale - 4, 9, 9), Color(0, 1, 1))
	image.save_png(out.path_join("reach.png"))

# ------------------------------------------------------------------------------------------------ maps

func _work_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	sun.light_energy = 2.0
	main.add_child(sun)
	for env_node: WorldEnvironment in main.find_children("*", "WorldEnvironment", true, false):
		env_node.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env_node.environment.ambient_light_color = Color(.8, .8, .8)
		env_node.environment.ambient_light_energy = 1.5
		env_node.environment.fog_enabled = false
		env_node.environment.volumetric_fog_enabled = false

func _map(camera: Camera3D, label: String, centre: Vector3, size: float) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	camera.far = 400.0
	camera.global_position = centre + Vector3.UP * 120.0
	camera.look_at(centre, Vector3.FORWARD)
	for n: Node in main.find_children("*", "Node3D", true, false):
		if n.has_method("_update_visibility"):
			n.process_mode = Node.PROCESS_MODE_DISABLED
			n.visible = true
	await frames(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("AUDIT_MAP ", label)
