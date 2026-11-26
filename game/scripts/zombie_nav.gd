class_name InteriorZombieNav
extends RefCounted
## 0.33: a way round. The infected used to walk straight at what they hunted and feel along whatever stopped
## them; a wall with wings, a fenced yard or a parked car's corner held them for good.
##
## Nothing is baked. The ground is looked at where a search needs it, on a 0.6 m grid, and remembered: a cell is
## somewhere to stand when there is fixed floor under it (not steeper than a ramp) and room for a body. A search
## is A* over those cells, eight ways, never cutting a corner. Between two cells the ground half way is looked at
## too: each half may rise or drop a foot (stairs, kerbs, ramps; not a ledge they could not step up), and a thin
## wall standing between two cells is found. It gives up after EXPAND cells and then returns the way to the cell nearest the
## goal, so one that cannot reach the player still comes as close as it can. scripts/zombies.gd lets one search
## run per physics tick; scripts/zombie.gd asks only when the straight way is shut.
##
## 0.37: the world changes under it. What it remembers is only the fixed world (layer 2); of that, door leaves and
## gate leaves move. scripts/zombies.gd watches every one of them (`watch_movers`) and when one has moved, drops
## what is remembered of the ground where it was and where it is now (`forget_box`); `epoch` counts the changes and
## `touched` tells a figure whether one of them lies along the way it is walking, so it looks again. Loose things
## (chairs, crates, a wardrobe the player shoved: layer 4) are not in the map at all: a figure walks round them by
## feel (zombie.gd `_avoid`), and where it has pushed for a second and a half and got nowhere it shuts that cell
## for a while (`shut_for`) and looks for another way.

const CELL := .6
const STEP := .32            # per half cell: what scripts/zombie.gd's legs take
const EXPAND := 900
const REACH := 44           # cells from where it stands: 26 m
const MASK := 2             # the fixed world; what is loose gets shoved aside
const WAYS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var space: PhysicsDirectSpaceState3D
var searches := 0
var probes := 0
var last_expanded := 0
## Vector3i(ix, iz, level) -> the floor's height there, or NAN where nothing can stand.
var _cells := {}
## 0.37: places where a body fits only off the middle: Vector3i(hx, hz, floor in decimetres) -> offset.
var _nudge := {}
const NUDGES: Array[Vector2] = [Vector2(.15, 0), Vector2(-.15, 0), Vector2(0, .15), Vector2(0, -.15), Vector2(.28, 0), Vector2(-.28, 0), Vector2(0, .28), Vector2(0, -.28)]
## 0.37: changes to the world so far, and the last few of them as [epoch, AABB].
var epoch := 0
var _changes: Array = []
## Vector2i cell -> the time (ms) until which it is shut.
var _closed := {}
const CHANGES_KEPT := 16
var _shape := CapsuleShape3D.new()
var _fit := PhysicsShapeQueryParameters3D.new()
## 0.48: the map at large (scripts/waypoints.gd): long ways go by it, and a search that cannot get there asks it.
var waypoints: InteriorWaypoints
var routed := 0
## How far (m) a figure walks cell by cell toward the next waypoint before looking again.
const LEG := 7.0

func _init() -> void:
	_shape.radius = .27
	_shape.height = 1.4
	_fit.shape = _shape
	_fit.collision_mask = MASK

## Drops what is remembered of the ground in `box` (and a cell round it). Returns how many places were dropped.
func forget_box(box: AABB) -> int:
	var half := CELL * .5
	var lo_x := floori((box.position.x - CELL) / half)
	var hi_x := ceili((box.end.x + CELL) / half)
	var lo_z := floori((box.position.z - CELL) / half)
	var hi_z := ceili((box.end.z + CELL) / half)
	var lo_l := floori((box.position.y - 1.6) / 1.1)
	var hi_l := floori((box.end.y + .8) / 1.1)
	var dropped := 0
	if not _cells.is_empty():
		for hx in range(lo_x, hi_x + 1):
			for hz in range(lo_z, hi_z + 1):
				for level in range(lo_l, hi_l + 1):
					if _cells.erase(Vector3i(hx, hz, level)):
						dropped += 1
	for key: Vector3i in _nudge.keys():
		if key.x >= lo_x and key.x <= hi_x and key.y >= lo_z and key.y <= hi_z:
			_nudge.erase(key)
	epoch += 1
	_changes.append([epoch, box.grow(CELL)])
	if waypoints != null:
		waypoints.refresh_box(box)
	if _changes.size() > CHANGES_KEPT:
		_changes.pop_front()
	return dropped

## Has the world changed since `since` anywhere along `way` from point `from` on? (When too much has changed to
## remember, yes.)
func touched(since: int, way: PackedVector3Array, from: int) -> bool:
	if since >= epoch:
		return false
	if _changes.is_empty() or int((_changes[0] as Array)[0]) > since + 1:
		return true
	for change: Array in _changes:
		if int(change[0]) <= since:
			continue
		var box: AABB = change[1]
		for i in range(maxi(from, 0), way.size()):
			var p := way[i]
			if p.x >= box.position.x and p.x <= box.end.x and p.z >= box.position.z and p.z <= box.end.z \
					and p.y > box.position.y - 2.0 and p.y < box.end.y + 1.0:
				return true
	return false

## Nothing walks through `cell` for `seconds`.
func shut_for(cell: Vector2i, seconds: float) -> void:
	_closed[cell] = Time.get_ticks_msec() + int(seconds * 1000.0)

func is_shut(cell: Vector2i) -> bool:
	if not _closed.has(cell):
		return false
	if Time.get_ticks_msec() > int(_closed[cell]):
		_closed.erase(cell)
		return false
	return true

static func cell_of(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / CELL), floori(at.z / CELL))

static func centre(cell: Vector2i, y: float) -> Vector3:
	return Vector3((cell.x + .5) * CELL, y, (cell.y + .5) * CELL)

## The floor of `cell` nearest `near_y` (within a stride above and a little more below), or NAN.
func floor_at(cell: Vector2i, near_y: float) -> float:
	return _floor(cell.x * 2 + 1, cell.y * 2 + 1, near_y)

## Can it walk from `here` (floor `y`) to the next cell `way` on (floor `ny`)? The ground half way decides.
func _open(here: Vector2i, way: Vector2i, y: float, ny: float) -> bool:
	var mid := _floor(here.x * 2 + 1 + way.x, here.y * 2 + 1 + way.y, y)
	return not is_nan(mid) and absf(mid - y) <= STEP and absf(ny - mid) <= STEP

## The same on the half-cell grid (`hx`, `hz` count 0.3 m: cells sit on the odd ones).
func _floor(hx: int, hz: int, near_y: float) -> float:
	var key := Vector3i(hx, hz, floori(near_y / 1.1))
	if _cells.has(key):
		return _cells[key]
	probes += 1
	var x := hx * CELL * .5
	var z := hz * CELL * .5
	var y := NAN
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, near_y + .75, z), Vector3(x, near_y - 1.0, z), MASK))
	if hit and (hit.normal as Vector3).y > .64:
		y = (hit.position as Vector3).y
		_fit.transform = Transform3D(Basis.IDENTITY, Vector3(x, y + .16 + _shape.height * .5, z))
		if not space.intersect_shape(_fit, 1).is_empty():
			# 0.37: a body may fit a little to one side (a railed boardwalk narrower than two cells, a gap in a
			# fence off the grid): the place is kept, with where in it to stand.
			# A cell's middle may move either way; a point half way between two cells only across the way between
			# them (so a thin wall or a shut door between two cells is still found).
			var fits := false
			for nudge: Vector2 in NUDGES:
				if (hx & 1) == 0 and (hz & 1) == 0:
					break
				if (hz & 1) == 0 and nudge.y != 0.0:
					continue
				if (hx & 1) == 0 and nudge.x != 0.0:
					continue
				var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x + nudge.x, y + .4, z + nudge.y), Vector3(x + nudge.x, y - .4, z + nudge.y), MASK))
				if ground.is_empty() or (ground.normal as Vector3).y < .64:
					continue
				var gy: float = (ground.position as Vector3).y
				_fit.transform = Transform3D(Basis.IDENTITY, Vector3(x + nudge.x, gy + .16 + _shape.height * .5, z + nudge.y))
				if space.intersect_shape(_fit, 1).is_empty():
					_nudge[Vector3i(hx, hz, roundi(y * 10.0))] = nudge
					fits = true
					break
			if not fits:
				y = NAN
	_cells[key] = y
	return y

## Where in `cell` (floor `y`) to stand: its middle, or to one side where only that fits.
func spot(cell: Vector2i, y: float) -> Vector3:
	var at := centre(cell, y)
	var nudge: Variant = _nudge.get(Vector3i(cell.x * 2 + 1, cell.y * 2 + 1, roundi(y * 10.0)))
	if nudge != null:
		at += Vector3((nudge as Vector2).x, 0.0, (nudge as Vector2).y)
	return at

## The way from `from` to `to` as points to walk through (the first is the next cell, not where it stands), or
## nothing when it stands on no cell at all. Ends at the goal's cell, or at the nearest cell to it that was reached.
func path(from: Vector3, to: Vector3, limit := EXPAND) -> PackedVector3Array:
	if limit != EXPAND:
		return _search(from, to, limit)
	searches += 1
	# 0.56: a goal further than a search can reach (REACH cells) is never reached by the search toward it: the leg
	# along the waypoints is tried first, and the search toward the goal runs only if that fails (the same answer
	# as before, without a whole failed search every time the player is far off).
	var sc := cell_of(from)
	var gc := cell_of(to)
	if waypoints != null and maxi(absi(gc.x - sc.x), absi(gc.y - sc.y)) > REACH + 1:
		var far_leg := _leg(from, to)
		if far_leg.is_finite() and cell_of(far_leg) != cell_of(from):
			var to_far_leg := _search(from, far_leg, limit)
			if not to_far_leg.is_empty() and cell_of(to_far_leg[to_far_leg.size() - 1]) == cell_of(far_leg):
				routed += 1
				return to_far_leg
		return _search(from, to, limit)
	var way := _search(from, to, limit)
	# 0.48: a search that did not get there (a wall it cannot see past, or the target past its reach): the waypoints
	# (scripts/waypoints.gd) give the way, and the cells are walked only to the waypoint a leg ahead.
	if waypoints == null or (not way.is_empty() and cell_of(way[way.size() - 1]) == cell_of(to)):
		return way
	var leg := _leg(from, to)
	if leg.is_finite() and cell_of(leg) != cell_of(from):
		var to_leg := _search(from, leg, limit)
		if not to_leg.is_empty() and cell_of(to_leg[to_leg.size() - 1]) == cell_of(leg):
			routed += 1
			return to_leg
	return way

## The waypoint a leg ahead along the graph's way to `to` (INF when the graph has none).
func _leg(from: Vector3, to: Vector3) -> Vector3:
	var way := waypoints.route(from, to)
	if way.is_empty():
		return Vector3.INF
	for p in way:
		if Vector2(p.x - from.x, p.z - from.z).length() >= LEG:
			return p
	return way[way.size() - 1]

## 0.56: the same search as before (same cells, same order, same way back) on flat arrays over the window it can
## reach (REACH cells either side of where it starts) instead of dictionaries keyed by cell, with the ground it
## reads remembered for the search's own length. It was 4-16 ms a search in GDScript; it is a fraction of that.
const SIDE := REACH * 2 + 1
const HALF_SIDE := REACH * 4 + 3
var _w_cost := PackedFloat64Array()
var _w_height := PackedFloat64Array()
var _w_parent := PackedInt32Array()
var _w_state := PackedByteArray()   # 1 open (has a cost), 2 closed: only where _w_gen holds this search's number
var _w_gen := PackedInt32Array()
var _m_gen := PackedInt32Array()
var _h_gen := PackedInt32Array()
var _gen := 0
var _m_floor := PackedFloat64Array()  # floor_at for a window cell, at level _m_level
var _m_level := PackedInt32Array()
var _h_floor := PackedFloat64Array()  # the ground half way between two cells (the half-cell grid)
var _h_level := PackedInt32Array()
var _heap_f := PackedFloat64Array()
var _heap_o := PackedInt32Array()
var _heap_i := PackedInt32Array()
var _heap_n := 0

func _window() -> void:
	if _w_cost.size() == SIDE * SIDE:
		return
	_w_cost.resize(SIDE * SIDE)
	_w_height.resize(SIDE * SIDE)
	_w_parent.resize(SIDE * SIDE)
	_w_state.resize(SIDE * SIDE)
	_w_gen.resize(SIDE * SIDE)
	_m_gen.resize(SIDE * SIDE)
	_h_gen.resize(HALF_SIDE * HALF_SIDE)
	_m_floor.resize(SIDE * SIDE)
	_m_level.resize(SIDE * SIDE)
	_h_floor.resize(HALF_SIDE * HALF_SIDE)
	_h_level.resize(HALF_SIDE * HALF_SIDE)

## 0.67: a time limit for the next searches (Time usec, 0: none): past it a search stops where it is, answers empty and
## sets `search_aborted` (what it read of the ground stays read; the caller tries again later, cheaper). The caller
## clears the flag before and reads it after (a `path` may run several searches).
var search_deadline := 0
var search_aborted := false

func _search(from: Vector3, to: Vector3, limit: int) -> PackedVector3Array:
	last_expanded = 0
	var result := PackedVector3Array()
	if space == null:
		return result
	var start := cell_of(from)
	var start_y := floor_at(start, from.y + .2)
	if is_nan(start_y):
		# Pressed against something: any neighbour it could step to.
		for way: Vector2i in WAYS:
			start_y = floor_at(start + way, from.y + .2)
			if not is_nan(start_y):
				start += way
				break
		if is_nan(start_y):
			return result
	_window()
	# (Nothing is cleared between searches: a slot counts only when it carries this search's number.)
	_gen += 1
	var gen := _gen
	_heap_n = 0
	var sx := start.x - REACH
	var sz := start.y - REACH
	var hsx := start.x * 2 + 1 - REACH * 2 - 1   # half-cell window origin
	var hsz := start.y * 2 + 1 - REACH * 2 - 1
	var shut := not _closed.is_empty()
	var goal := cell_of(to)
	var gx := goal.x
	var gz := goal.y
	var si := REACH * SIDE + REACH
	_w_cost[si] = 0.0
	_w_height[si] = start_y
	_w_state[si] = 1
	_w_gen[si] = gen
	var order := 0
	_heap_push(_guess(start, goal), order, si)
	var best := si
	var best_left := _guess(start, goal)
	while _heap_n > 0 and last_expanded < limit:
		var hi := _heap_pop()
		if _w_state[hi] == 2:
			continue
		_w_state[hi] = 2
		last_expanded += 1
		if search_deadline > 0 and last_expanded % 6 == 0 and Time.get_ticks_usec() > search_deadline:
			search_aborted = true
			return PackedVector3Array()
		var hx := hi / SIDE + sx
		var hz := hi % SIDE + sz
		var ddx := absi(hx - gx)
		var ddz := absi(hz - gz)
		var left := float(maxi(ddx, ddz)) + .4142 * float(mini(ddx, ddz))
		if left < best_left:
			best_left = left
			best = hi
		if hx == gx and hz == gz:
			break
		var y: float = _w_height[hi]
		var g: float = _w_cost[hi]
		var level := floori(y / 1.1)
		for i in 8:
			var wx: int = WX[i]
			var wz: int = WZ[i]
			var nx := hx + wx
			var nz := hz + wz
			if absi(nx - start.x) > REACH or absi(nz - start.y) > REACH:
				continue
			var ni := (nx - sx) * SIDE + (nz - sz)
			var seen := _w_gen[ni] == gen
			if seen and _w_state[ni] == 2:
				continue
			if shut and not (nx == gx and nz == gz) and is_shut(Vector2i(nx, nz)):
				continue
			# floor_at(next, y), remembered for this search
			var ny: float
			if _m_gen[ni] == gen and _m_level[ni] == level:
				ny = _m_floor[ni]
			else:
				ny = _floor(nx * 2 + 1, nz * 2 + 1, y)
				_m_gen[ni] = gen
				_m_level[ni] = level
				_m_floor[ni] = ny
			if is_nan(ny):
				continue
			# _open: the ground half way
			var mhx := hx * 2 + 1 + wx
			var mhz := hz * 2 + 1 + wz
			var mi := (mhx - hsx) * HALF_SIDE + (mhz - hsz)
			var mid: float
			if _h_gen[mi] == gen and _h_level[mi] == level:
				mid = _h_floor[mi]
			else:
				mid = _floor(mhx, mhz, y)
				_h_gen[mi] = gen
				_h_level[mi] = level
				_h_floor[mi] = mid
			if is_nan(mid) or absf(mid - y) > STEP or absf(ny - mid) > STEP:
				continue
			if i >= 4:
				# Diagonally only where both cells beside the corner are open at this height.
				var ai := (nx - sx) * SIDE + (hz - sz)
				var a: float
				if _m_gen[ai] == gen and _m_level[ai] == level:
					a = _m_floor[ai]
				else:
					a = _floor(nx * 2 + 1, hz * 2 + 1, y)
					_m_gen[ai] = gen
					_m_level[ai] = level
					_m_floor[ai] = a
				if is_nan(a) or absf(a - y) > STEP * 2.0:
					continue
				var bi := (hx - sx) * SIDE + (nz - sz)
				var b: float
				if _m_gen[bi] == gen and _m_level[bi] == level:
					b = _m_floor[bi]
				else:
					b = _floor(hx * 2 + 1, nz * 2 + 1, y)
					_m_gen[bi] = gen
					_m_level[bi] = level
					_m_floor[bi] = b
				if is_nan(b) or absf(b - y) > STEP * 2.0:
					continue
			var ng := g + (1.0 if i < 4 else 1.4142)
			if seen and _w_state[ni] == 1 and _w_cost[ni] <= ng:
				continue
			_w_gen[ni] = gen
			_w_cost[ni] = ng
			_w_height[ni] = ny
			_w_parent[ni] = hi
			_w_state[ni] = 1
			order += 1
			var ex := absi(nx - gx)
			var ez := absi(nz - gz)
			_heap_push(ng + (float(maxi(ex, ez)) + .4142 * float(mini(ex, ez))), order, ni)
	var at := best
	var back: Array[Vector3] = []
	while at != si:
		back.append(spot(Vector2i(at / SIDE + sx, at % SIDE + sz), _w_height[at]))
		at = _w_parent[at]
	back.reverse()
	result.append_array(PackedVector3Array(back))
	return result

const WX: Array[int] = [1, -1, 0, 0, 1, 1, -1, -1]
const WZ: Array[int] = [0, 0, 1, -1, 1, -1, 1, -1]

## The open list: a binary heap on flat arrays; lowest f first, the later of two equal ones first (as before).
func _heap_push(f: float, o: int, idx: int) -> void:
	if _heap_n >= _heap_f.size():
		var grow := maxi(256, _heap_f.size() * 2)
		_heap_f.resize(grow)
		_heap_o.resize(grow)
		_heap_i.resize(grow)
	var i := _heap_n
	_heap_n += 1
	while i > 0:
		var up := (i - 1) >> 1
		var uf: float = _heap_f[up]
		if f < uf or (f == uf and o > _heap_o[up]):
			_heap_f[i] = uf
			_heap_o[i] = _heap_o[up]
			_heap_i[i] = _heap_i[up]
			i = up
		else:
			break
	_heap_f[i] = f
	_heap_o[i] = o
	_heap_i[i] = idx

func _heap_pop() -> int:
	var top := _heap_i[0]
	_heap_n -= 1
	if _heap_n > 0:
		var f: float = _heap_f[_heap_n]
		var o: int = _heap_o[_heap_n]
		var idx: int = _heap_i[_heap_n]
		var i := 0
		var count := _heap_n
		while true:
			var l := i * 2 + 1
			if l >= count:
				break
			var r := l + 1
			var c := l
			var cf: float = _heap_f[l]
			if r < count:
				var rf: float = _heap_f[r]
				if rf < cf or (rf == cf and _heap_o[r] > _heap_o[l]):
					c = r
					cf = rf
			if cf < f or (cf == f and _heap_o[c] > o):
				_heap_f[i] = cf
				_heap_o[i] = _heap_o[c]
				_heap_i[i] = _heap_i[c]
				i = c
			else:
				break
		_heap_f[i] = f
		_heap_o[i] = o
		_heap_i[i] = idx
	return top

static func _guess(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dz := absi(a.y - b.y)
	return float(maxi(dx, dz)) + .4142 * float(mini(dx, dz))

## (The waypoint graph's search, scripts/waypoints.gd, keeps using this heap of [f, order, item].)
static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var up := (i - 1) >> 1
		if _before(heap[i], heap[up]):
			var swap: Array = heap[i]
			heap[i] = heap[up]
			heap[up] = swap
			i = up
		else:
			break

static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		var count := heap.size()
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var least := i
			if l < count and _before(heap[l], heap[least]):
				least = l
			if r < count and _before(heap[r], heap[least]):
				least = r
			if least == i:
				break
			var swap: Array = heap[i]
			heap[i] = heap[least]
			heap[least] = swap
			i = least
	return top

static func _before(a: Array, b: Array) -> bool:
	return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) > int(b[1]))
