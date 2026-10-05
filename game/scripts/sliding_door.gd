class_name InteriorSlidingDoor
extends InteriorHingedDoor
## A glass panel that slides along this node's local +X (behind its fixed twin) instead of
## swinging. Same interface as the hinged door: aim at it (or through the open gap) and press
## Hold (E) to toggle; it stops for the player and slows on props.

@export var slide_distance := 1.0

var _grab_offset := 0.0

func _ready() -> void:
	super._ready()
	label = "studio door" if label == "door" else label

func _grab_frame(local: Vector3) -> void:
	_grab_offset = local.x - slide_distance * _t

## Holding E slides the panel along with the hand.
func _hand_target(local: Vector3) -> float:
	if slide_distance <= .001:
		return _t
	return clampf((local.x - _grab_offset) / slide_distance, 0.0, 1.0)

func _overlaps_t(t: float) -> int:
	if _shape == null or _body == null or not is_inside_tree():
		return 0
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		_query.shape = _shape.shape
		_query.collision_mask = PLAYER_MASK | PROP_MASK
		_query.exclude = [_body.get_rid()]
	_query.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(slide_distance * t, 0, 0)) * _shape.transform
	var mask := 0
	for hit in get_world_3d().direct_space_state.intersect_shape(_query, 8):
		var collider := hit.get("collider") as CollisionObject3D
		if collider != null:
			mask |= collider.collision_layer & (PLAYER_MASK | PROP_MASK)
	return mask

func _apply_t(t: float) -> void:
	if _body == null:
		return
	_body.position = Vector3(slide_distance * t, 0, 0)
