class_name InteriorSlidingDoor
extends InteriorHingedDoor
## A glass panel that slides along this node's local +X (behind its fixed twin) instead of
## swinging. Same interface as the hinged door: aim at it (or through the open gap) and press
## Hold (E) to toggle; it stops for the player and slows on props.

@export var slide_distance := 1.0

func _ready() -> void:
	super._ready()
	label = "studio door" if label == "door" else label

func _overlaps(p: float) -> int:
	if _shape == null or _body == null or not is_inside_tree():
		return 0
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		_query.shape = _shape.shape
		_query.collision_mask = PLAYER_MASK | PROP_MASK
		_query.exclude = [_body.get_rid()]
	var t := p * p * (3.0 - 2.0 * p)
	_query.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(slide_distance * t, 0, 0)) * _shape.transform
	var mask := 0
	for hit in get_world_3d().direct_space_state.intersect_shape(_query, 8):
		var collider := hit.get("collider") as CollisionObject3D
		if collider != null:
			mask |= collider.collision_layer & (PLAYER_MASK | PROP_MASK)
	return mask

func _apply() -> void:
	if _body == null:
		return
	var t := _progress * _progress * (3.0 - 2.0 * _progress)
	_body.position = Vector3(slide_distance * t, 0, 0)
