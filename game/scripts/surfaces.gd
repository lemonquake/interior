class_name InteriorSurfaces
extends RefCounted
## What the player is standing on, for footstep sounds. A collider (or its CollisionShape3D) may carry
## a "surface" meta; otherwise the answer comes from the room / balcony / street layout.
## Keys: wood, carpet, tile, concrete, asphalt, grass, metal, dirt (the fields road, 0.7).

const ROOM_FLOOR_TOP := 1.0
static var _rugs: Array[Rect2] = []
static var _rugs_scanned := false

static func under(body: Node3D) -> String:
	if body == null or not body.is_inside_tree():
		return "wood"
	var from := body.global_position + Vector3.UP * .25
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * .7, 6)
	if body is CollisionObject3D:
		query.exclude = [(body as CollisionObject3D).get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		var collider := hit.collider as Object
		if collider != null and collider.has_meta("surface"):
			return str(collider.get_meta("surface"))
		var owner_node := _shape_node(collider, int(hit.get("shape", 0)))
		if owner_node != null and owner_node.has_meta("surface"):
			return str(owner_node.get_meta("surface"))
		if collider is InteriorObject:
			match str((collider as InteriorObject).physics_material):
				"fabric", "foam", "cardboard", "rubber":
					return "carpet"
				"metal", "steel":
					return "metal"
				"ceramic", "glass", "stone":
					return "tile"
			return "wood"
	return at(body.global_position, body.get_tree())

## 0.33: is this shape one of the world's unseen walls? The road and path edges in the fields, the "Bound" blocks
## round the play area, the guards over a rail or a gap: they keep feet where the ground is, and nothing else
## should take them for a wall (a round, a sound, a hand looking for a ledge). Told by the shape's name.
static var _unseen := {}

static func unseen(collider: Object, shape_index: int) -> bool:
	if not collider is CollisionObject3D:
		return false
	var key := Vector2i(collider.get_instance_id() & 0x7fffffff, shape_index)
	if _unseen.has(key):
		return _unseen[key]
	var node := _shape_node(collider, shape_index)
	var answer := false
	if node != null and (node.has_meta("unseen") or collider.has_meta("unseen")):
		answer = true
	elif node != null:
		var low := String(node.name).to_lower().rstrip("0123456789@ ")
		answer = low.begins_with("bound ") or low == "boundary" or low.ends_with(" bound") or low.begins_with("road edge") 			or low == "road end" or low.ends_with(" edge") or low.begins_with("edge") or low.ends_with("guard") or low == "jetty end" or low.ends_with(" void")
	if _unseen.size() > 4000:
		_unseen.clear()
	_unseen[key] = answer
	return answer

## 0.34: where the hands do not take the body (scripts/player.gd, `_try_mantle`): a climb, a catch off a jump or a
## vault that would end inside one of these is not made. Found with tests/climb_integration.gd, which asks the
## player's own climbing code from every cell of the world.
## - The canal district and the warren, from 1.35 m above the lane: off a perch (the culvert headwall, a crate) a
##   jump caught the top of the boundary wall or a roof, and from there the far side was a drop out of the world
##   or into the dead ground behind the warren. Crates, carts, low walls and the headwall are still climbed.
const NO_PERCH := [AABB(Vector3(-125.0, -.75, -20.0), Vector3(88.0, 30.0, 96.0))]

## 0.34: is this shape a rail (a boardwalk's, a catwalk's, a bridge's, a balcony's)? Nobody stands on one: the
## warren's are 1.2 m high and 0.4 m wide, and from the top of one the drop on the far side was into its drain,
## which leads out behind its walls. A rail low enough is still vaulted. Told by the shape's name, like `unseen`.
static var _rails := {}

static func rail(collider: Object, shape_index: int) -> bool:
	if not collider is CollisionObject3D:
		return false
	var key := Vector2i(collider.get_instance_id() & 0x7fffffff, shape_index)
	if _rails.has(key):
		return _rails[key]
	var node := _shape_node(collider, shape_index)
	var answer := false
	if node != null:
		var low := String(node.name).to_lower()
		answer = low.contains("rail") or low.contains("baluster")
	if _rails.size() > 4000:
		_rails.clear()
	_rails[key] = answer
	return answer

static func no_perch(to: Vector3) -> bool:
	for box: AABB in NO_PERCH:
		if box.has_point(to):
			return true
	return false

## A ray against `mask` that goes on through the unseen walls. Returns the hit, or {}.
static func seen_ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int, exclude: Array[RID] = []) -> Dictionary:
	var start := from
	for i in 8:
		var query := PhysicsRayQueryParameters3D.create(start, to, mask)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty() or not unseen(hit.collider, int(hit.get("shape", 0))):
			return hit
		var on: Vector3 = hit.position
		if on.distance_to(to) < .3:
			return {}
		# 0.49: just inside it (a ray from inside a box does not meet that box): what is drawn inside a walking box
		# (a gate's lower sheet in its frame) is met; the old .28 m step went clean over it.
		start = on + (to - on).normalized() * .01
	return {}

static func _shape_node(collider: Object, shape_index: int) -> Node:
	if not collider is CollisionObject3D:
		return null
	var body := collider as CollisionObject3D
	var owner_id := body.shape_find_owner(shape_index)
	if owner_id < 0:
		return null
	return body.shape_owner_get_owner(owner_id) as Node

## Layout fallback (metres; room floor y=0, street level y=-2.9).
static func at(p: Vector3, tree: SceneTree = null) -> String:
	if p.y > -.6:
		if p.x > 5.6 and p.z > 2.85:
			return "concrete"  # top of the stair
		if p.z > 2.75 and p.x > .9:
			return "tile"  # balcony
		if p.x > -5.7 and p.x < -1.2 and p.z > 2.85:
			return "carpet"  # black-foam studio with its rug
		if p.x < -3.3:
			return "tile"  # kitchen
		if _on_rug(p, tree):
			return "carpet"
		return "wood"
	if p.x > 5.5 and p.x < 9.7 and p.z < 3.95:
		return "concrete"  # stair
	if p.x > 9.5 and p.x < 12.65 and p.z > 2.85 and p.z < 5.35:
		return "concrete"  # courtyard
	for street: Array in InteriorNeighborhoodBuilder.STREETS:
		var along_x: bool = street[0] == "x"
		var across: float = p.z if along_x else p.x
		var along: float = p.x if along_x else p.z
		if along < float(street[2]) or along > float(street[3]):
			continue
		var offset := absf(across - float(street[1]))
		var width: float = street[4]
		if offset <= width * .5 - 1.0:
			return "asphalt"
		if offset <= width * .5:
			return "concrete"  # sidewalk
	return "grass"

static func _on_rug(p: Vector3, tree: SceneTree) -> bool:
	if not _rugs_scanned and tree != null and tree.current_scene != null:
		_rugs_scanned = true
		for node in tree.current_scene.find_children("*rug*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var box := mesh.global_transform * mesh.get_aabb()
			# Only flat floor rugs (not rugged textures on tall furniture).
			if box.size.y < .08 and box.position.y < .1 and box.size.x * box.size.z > .5:
				_rugs.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
	for rect in _rugs:
		if rect.has_point(Vector2(p.x, p.z)):
			return true
	return false
