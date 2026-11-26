class_name InteriorWaypoints
extends RefCounted
## 0.48: a waypoint graph over the whole map, so the infected and the squad AI find their way round and never stand
## pressed against a wall for good.
##
## scripts/zombie_nav.gd looks at the ground cell by cell (0.6 m) and searches only 26 m round where a figure stands,
## giving up after 900 cells: past a long wall, a fenced yard or a building between it and its target, a figure
## walked to the cell nearest the target it had found, and there it stayed. This graph is the map at large: a
## node every 1.8 m (every third cell) wherever a body can stand, one per floor, linked to its neighbours when a
## body can walk between them (straight, or round a corner in a few steps). It is built in the background a little
## every physics tick, outward from the players (`grow`), and kept. `route` is A* over it; zombie_nav.gd asks it
## for a way whenever the target is far or its own search did not get there, and walks cell by cell only to the
## next waypoint a few metres on.
##
## It also says where is reachable: `reachable_in` (scripts/coop/mission.gd scatters the dropped weapons, ammunition
## and healthkits only on nodes joined to where the players stand).

const SPACING := 3                  # cells between nodes (1.8 m)
const RADIUS := 52.0                # m round a player that is filled in
const FLOORS := 3                   # floors looked for under one place
const LINK_EXPAND := 70             # cells a link round a corner may search
const RISE := 2.6                   # m: no link between floors further apart than this

var nav: InteriorZombieNav
## id -> [position, lattice Vector2i, links PackedInt32Array]
var nodes: Array = []
var _at := {}                       # lattice Vector2i -> PackedInt32Array of node ids (one per floor)
var _queue: Array[Vector2i] = []
var _seen := {}                     # lattice points looked at or queued
var _top := 0.0
var built := 0
var links := 0
var usec := 0
var _component := PackedInt32Array()
var _component_dirty := true

func _init(owner_nav: InteriorZombieNav) -> void:
	nav = owner_nav

static func lattice_of(at: Vector3) -> Vector2i:
	var c := InteriorZombieNav.cell_of(at)
	return Vector2i(int(floor(float(c.x) / SPACING)), int(floor(float(c.y) / SPACING)))

static func cell_of_lattice(l: Vector2i) -> Vector2i:
	return Vector2i(l.x * SPACING + 1, l.y * SPACING + 1)

## Queues the lattice round `points` (nearest first) that has not been looked at.
## 0.65: the middles of the circles seeded so far. Every point of a seeded circle is in `_seen`, so a player who has
## moved only looks at the part of the new circle outside the nearest old one (the same points as walking the whole
## circle and skipping those seen: a 59 by 59 walk per player every half second was up to 11 ms on a PC).
var _seeded: Array[Vector2i] = []

func seed_around(points: Array) -> void:
	var span := int(ceil(RADIUS / (InteriorZombieNav.CELL * SPACING)))
	var fresh: Array = []
	for p: Vector3 in points:
		if not p.is_finite():
			continue
		_top = maxf(_top, p.y)
		var mid := lattice_of(p)
		var old := Vector2i(1 << 30, 1 << 30)
		var best := span * span + 1
		for m: Vector2i in _seeded:
			var d2 := (m - mid).length_squared()
			if d2 < best:
				best = d2
				old = m
		if best == 0:
			continue
		var cover := best <= span * span
		for dx in range(-span, span + 1):
			var reach := int(floor(sqrt(float(span * span - dx * dx))))
			# (The old circle's row at the same x, in this circle's terms: skipped, it is all seen.)
			var skip_lo := 1
			var skip_hi := 0
			if cover:
				var ox := mid.x + dx - old.x
				if ox * ox <= span * span:
					var oreach := int(floor(sqrt(float(span * span - ox * ox))))
					skip_lo = old.y - oreach - mid.y
					skip_hi = old.y + oreach - mid.y
			for dz in range(-reach, reach + 1):
				if dz >= skip_lo and dz <= skip_hi:
					continue
				var l := mid + Vector2i(dx, dz)
				if _seen.has(l):
					continue
				_seen[l] = p.y
				fresh.append([dx * dx + dz * dz, l])
		_seeded.append(mid)
		if _seeded.size() > 64:
			_seeded.remove_at(0)
	if fresh.is_empty():
		return
	fresh.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	for f in fresh:
		_queue.append(f[1])

## Builds for at most `budget` microseconds. Returns true while there is more to do.
## 0.65: a new node's links (node, neighbour pairs) are looked at here, a pair at a time inside the budget: one
## node's links (up to sixteen walks, each maybe a search round a corner over ground never probed) ran 5-8 ms past
## the budget in one go. The same links come out, a few frames later.
var _link_todo := PackedInt32Array()
var _link_head := 0

func grow(budget: int) -> bool:
	if nav == null or nav.space == null:
		return not _queue.is_empty() or _link_head < _link_todo.size()
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < budget:
		if _link_head < _link_todo.size():
			var a := _link_todo[_link_head]
			var b := _link_todo[_link_head + 1]
			_link_head += 2
			# (0.67: a walk round a corner over ground never read could still run several ms past the budget in one
			# search: it stops 1.5 ms past it, and the pair is tried again later; what it read is remembered.)
			nav.search_aborted = false
			nav.search_deadline = start + budget + 1500
			var walked := _walk(nodes[a][0], nodes[b][0])
			nav.search_deadline = 0
			if nav.search_aborted:
				nav.search_aborted = false
				_link_todo.append(a)
				_link_todo.append(b)
				break
			if walked:
				_link(a, b)
				_component_dirty = true
			continue
		if _link_head > 0:
			_link_todo = PackedInt32Array()
			_link_head = 0
		if _queue.is_empty():
			break
		var l: Vector2i = _queue.pop_front()
		_build(l, float(_seen.get(l, _top)))
	usec += Time.get_ticks_usec() - start
	return not _queue.is_empty() or _link_head < _link_todo.size()

func pending() -> int:
	return _queue.size() + (_link_todo.size() - _link_head) / 2

## Every floor at lattice point `l` (rays down from well above the player's height), as nodes, linked to the
## neighbours already built.
func _build(l: Vector2i, near_y: float) -> void:
	var cell := cell_of_lattice(l)
	var c := InteriorZombieNav.centre(cell, 0.0)
	var from_y := near_y + 9.0
	var floors: Array[float] = []
	for k in FLOORS:
		var hit := nav.space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(c.x, from_y, c.z), Vector3(c.x, near_y - 14.0, c.z), InteriorZombieNav.MASK))
		if hit.is_empty():
			break
		var y: float = (hit.position as Vector3).y
		if (hit.normal as Vector3).y > .64:
			var fy := nav.floor_at(cell, y)
			if not is_nan(fy):
				floors.append(fy)
		from_y = y - .35
	var ids := PackedInt32Array()
	for fy in floors:
		var id := nodes.size()
		nodes.append([nav.spot(cell, fy), l, PackedInt32Array()])
		ids.append(id)
		built += 1
	if ids.is_empty():
		return
	_at[l] = ids
	_component_dirty = true
	for id in ids:
		for way: Vector2i in InteriorZombieNav.WAYS:
			var other: Variant = _at.get(l + way)
			if other == null:
				continue
			for o: int in other:
				if absf((nodes[o][0] as Vector3).y - (nodes[id][0] as Vector3).y) > RISE:
					continue
				_link_todo.append(id)
				_link_todo.append(o)

## The world changed in `box` (a door, a gate, the back door broken in): the links there are looked at again.
func refresh_box(box: AABB) -> void:
	var lo := lattice_of(box.position) - Vector2i.ONE
	var hi := lattice_of(box.end) + Vector2i.ONE
	var touched: Array[int] = []
	for lx in range(lo.x, hi.x + 1):
		for lz in range(lo.y, hi.y + 1):
			var here: Variant = _at.get(Vector2i(lx, lz))
			if here == null:
				continue
			for id: int in here:
				touched.append(id)
	for id in touched:
		for o: int in (nodes[id][2] as PackedInt32Array):
			var lo_links: PackedInt32Array = nodes[o][2]
			var at := lo_links.find(id)
			if at >= 0:
				lo_links.remove_at(at)
				nodes[o][2] = lo_links
		nodes[id][2] = PackedInt32Array()
	for id in touched:
		var l: Vector2i = nodes[id][1]
		for way: Vector2i in InteriorZombieNav.WAYS:
			var other: Variant = _at.get(l + way)
			if other == null:
				continue
			for o: int in other:
				if absf((nodes[o][0] as Vector3).y - (nodes[id][0] as Vector3).y) <= RISE and _walk(nodes[id][0], nodes[o][0]):
					_link(id, o)
	_component_dirty = true

func _link(a: int, b: int) -> void:
	var la: PackedInt32Array = nodes[a][2]
	if b in la:
		return
	la.append(b)
	nodes[a][2] = la
	var lb: PackedInt32Array = nodes[b][2]
	lb.append(a)
	nodes[b][2] = lb
	links += 1

## Can a body walk from `a` to `b` (neighbouring nodes)? Cell by cell along the line; else round a corner in a few
## steps (a doorway off the lattice line).
func _walk(a: Vector3, b: Vector3) -> bool:
	var here := InteriorZombieNav.cell_of(a)
	var goal := InteriorZombieNav.cell_of(b)
	var y := a.y
	var straight := true
	var guard := 0
	while here != goal and guard < 12:
		guard += 1
		var way := Vector2i(signi(goal.x - here.x), signi(goal.y - here.y))
		var next := here + way
		var ny := nav.floor_at(next, y)
		if is_nan(ny) or not nav._open(here, way, y, ny):
			straight = false
			break
		if way.x != 0 and way.y != 0:
			var s1 := nav.floor_at(here + Vector2i(way.x, 0), y)
			var s2 := nav.floor_at(here + Vector2i(0, way.y), y)
			if is_nan(s1) or is_nan(s2):
				straight = false
				break
		here = next
		y = ny
	if straight and here == goal:
		return true
	var way_round := nav.path(a, b, LINK_EXPAND)
	return not way_round.is_empty() and way_round.size() <= 9 and InteriorZombieNav.cell_of(way_round[way_round.size() - 1]) == goal

## The node nearest `at` (same floor first), or -1.
func nearest(at: Vector3, reach := 2) -> int:
	var mid := lattice_of(at)
	var best := -1
	var best_d := INF
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var here: Variant = _at.get(mid + Vector2i(dx, dz))
			if here == null:
				continue
			for id: int in here:
				var p: Vector3 = nodes[id][0]
				var d := Vector2(p.x - at.x, p.z - at.z).length() + absf(p.y - at.y) * 3.0
				if d < best_d:
					best_d = d
					best = id
	return best

## The way from `from` to `to` over the graph, as node positions (from the first node after the one `from` is
## nearest), or nothing when either end is off the graph or they are not joined.
var _routes := {}
func route(from: Vector3, to: Vector3, max_nodes := 4000) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a := nearest(from)
	var b := nearest(to, 4)
	if a < 0 or b < 0:
		return out
	# The same two nodes asked again within a second (a crowd after one player): the answer already found.
	var key := Vector2i(a, b)
	var now := Time.get_ticks_msec()
	if _routes.has(key) and now - int(_routes[key][0]) < 1000:
		return _routes[key][1]
	if _routes.size() > 256:
		_routes.clear()
	out = _route(a, b, max_nodes)
	_routes[key] = [now, out]
	return out

func _route(a: int, b: int, max_nodes: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	if a == b:
		out.append(nodes[b][0])
		return out
	var goal: Vector3 = nodes[b][0]
	var open: Array = []
	var cost := {a: 0.0}
	var parent := {}
	var closed := {}
	var order := 0
	InteriorZombieNav._push(open, [(nodes[a][0] as Vector3).distance_to(goal), order, a])
	var expanded := 0
	var found := false
	while not open.is_empty() and expanded < max_nodes:
		var here: int = InteriorZombieNav._pop(open)[2]
		if closed.has(here):
			continue
		closed[here] = true
		expanded += 1
		if here == b:
			found = true
			break
		var hp: Vector3 = nodes[here][0]
		var g: float = cost[here]
		for next: int in (nodes[here][2] as PackedInt32Array):
			if closed.has(next):
				continue
			var np: Vector3 = nodes[next][0]
			var shut := 4.0 if nav.is_shut(InteriorZombieNav.cell_of(np)) else 0.0
			var ng := g + hp.distance_to(np) + shut
			if cost.has(next) and float(cost[next]) <= ng:
				continue
			cost[next] = ng
			parent[next] = here
			order += 1
			InteriorZombieNav._push(open, [ng + np.distance_to(goal), order, next])
	if not found:
		return out
	var back: Array[Vector3] = []
	var at := b
	while at != a:
		back.append(nodes[at][0])
		at = parent[at]
	back.reverse()
	out.append_array(PackedVector3Array(back))
	return out

## A node a few links away from `at`, away from `away` (a figure that has pushed against something too long backs
## off to there and looks again).
func detour(at: Vector3, away: Vector3, hops := 3) -> Vector3:
	var here := nearest(at)
	if here < 0:
		return Vector3.INF
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in hops:
		var choices: PackedInt32Array = nodes[here][2]
		if choices.is_empty():
			break
		var best := -1
		var best_score := -INF
		for c: int in choices:
			var p: Vector3 = nodes[c][0]
			var score := p.distance_to(away) + rng.randf() * 1.5
			if score > best_score:
				best_score = score
				best = c
		here = best
	return nodes[here][0]

## Every node joined (through links) to the node nearest `at`.
func joined(at: Vector3) -> PackedInt32Array:
	var start := nearest(at)
	var out := PackedInt32Array()
	if start < 0:
		return out
	var seen := {start: true}
	var stack: Array[int] = [start]
	while not stack.is_empty():
		var here: int = stack.pop_back()
		out.append(here)
		for n: int in (nodes[here][2] as PackedInt32Array):
			if not seen.has(n):
				seen[n] = true
				stack.append(n)
	return out

## Positions of joined nodes inside the box (x/z), with at least `links_min` links (not a ledge's end).
func reachable_in(ids: PackedInt32Array, lo: Vector2, hi: Vector2, links_min := 3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for id: int in ids:
		var p: Vector3 = nodes[id][0]
		if p.x < lo.x or p.x >= hi.x or p.z < lo.y or p.z >= hi.y:
			continue
		if (nodes[id][2] as PackedInt32Array).size() < links_min:
			continue
		out.append(p)
	return out
