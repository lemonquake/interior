class_name InteriorPropPhysics
extends RefCounted

## Shared Jolt collider builder and physical material table for interior props.
## Used by InteriorObject.configure() (dynamic / wall_anchored) and build_static().

const LAYER_PLAYER := 1
const LAYER_ROOM := 2
const LAYER_OBJECTS := 4
const STATIC_MASK := 5
# Upper bound for Jolt's convex radius. Jolt also caps it at
# collision_margin_fraction of the shortest axis, so small props stay crisp.
const SHAPE_MARGIN := 0.004
# Rolling resistance assumed for surfaces that carry no material metadata.
const DEFAULT_SURFACE_ROLLING := 0.01

## friction / bounce: Jolt contact coefficients (friction combines as a geometric
## mean, bounce as the maximum of both bodies).
## linear_damp / angular_damp: air drag added to the small project defaults
## (DAMP_MODE_COMBINE), so contacts and rolling resistance do the real work.
## rolling: rolling-resistance coefficient C_rr (moment = C_rr * N * r), added to
## the coefficient of the surface it rolls on. spin: torsional resistance about
## the contact normal. sound: impact sound class for audio.
const MATERIALS := {
	"wood": {"friction": 0.50, "bounce": 0.15, "linear_damp": 0.0, "angular_damp": 0.0, "rolling": 0.012, "spin": 0.05, "sound": "wood"},
	"stone": {"friction": 0.60, "bounce": 0.06, "linear_damp": 0.0, "angular_damp": 0.0, "rolling": 0.006, "spin": 0.05, "sound": "stone"},
	"fabric": {"friction": 0.85, "bounce": 0.02, "linear_damp": 0.05, "angular_damp": 0.10, "rolling": 0.09, "spin": 0.25, "sound": "soft"},
	"leather": {"friction": 0.70, "bounce": 0.04, "linear_damp": 0.02, "angular_damp": 0.05, "rolling": 0.06, "spin": 0.20, "sound": "soft"},
	"plastic": {"friction": 0.42, "bounce": 0.35, "linear_damp": 0.0, "angular_damp": 0.0, "rolling": 0.014, "spin": 0.05, "sound": "plastic"},
	"metal": {"friction": 0.38, "bounce": 0.22, "linear_damp": 0.0, "angular_damp": 0.0, "rolling": 0.005, "spin": 0.04, "sound": "metal"},
	"glass": {"friction": 0.32, "bounce": 0.25, "linear_damp": 0.0, "angular_damp": 0.0, "rolling": 0.006, "spin": 0.04, "sound": "glass"},
	"ceramic": {"friction": 0.50, "bounce": 0.15, "linear_damp": 0.0, "angular_damp": 0.0, "rolling": 0.008, "spin": 0.05, "sound": "ceramic"},
	"rubber": {"friction": 0.90, "bounce": 0.70, "linear_damp": 0.0, "angular_damp": 0.0, "rolling": 0.020, "spin": 0.08, "sound": "rubber"},
	"paper": {"friction": 0.60, "bounce": 0.03, "linear_damp": 0.30, "angular_damp": 0.30, "rolling": 0.05, "spin": 0.20, "sound": "paper"},
	"foliage": {"friction": 0.80, "bounce": 0.05, "linear_damp": 0.20, "angular_damp": 0.40, "rolling": 0.12, "spin": 0.30, "sound": "foliage"},
	"cardboard": {"friction": 0.55, "bounce": 0.08, "linear_damp": 0.05, "angular_damp": 0.05, "rolling": 0.04, "spin": 0.15, "sound": "cardboard"},
	"foam": {"friction": 0.90, "bounce": 0.30, "linear_damp": 0.40, "angular_damp": 0.40, "rolling": 0.10, "spin": 0.30, "sound": "soft"},
}

## Physical material of the existing living-room actors (room_manifest assetId).
const ASSET_MATERIALS := {
	"fabric_sofa": "fabric", "leather_sofa": "leather", "marble_table": "stone",
	"tv_console": "wood", "television": "plastic", "standing_fan": "plastic",
	"computer_desk": "wood", "monitor": "plastic", "computer_tower": "metal",
	"baby_crib": "wood", "high_chair": "wood", "pet_enclosure": "metal",
	"fish_bowl": "glass", "bass_guitar": "wood", "woven_tray": "wood",
	"potted_plant": "ceramic", "tissue_box": "cardboard", "digital_clock": "plastic",
	"red_flowers": "ceramic", "purple_flowers": "ceramic", "yellow_flowers": "ceramic",
	"photo_frame": "wood", "wall_shelf": "wood", "storage_bin": "plastic",
}

## Material key for a room actor; loose components are classified by label.
static func material_for(asset_id: String, label := "") -> String:
	if ASSET_MATERIALS.has(asset_id):
		return ASSET_MATERIALS[asset_id]
	var text := label.to_lower()
	for pair in [["cushion", "fabric"], ["pillow", "fabric"], ["keyboard", "plastic"], ["toy", "rubber"],
			["ball", "rubber"], ["rack", "metal"], ["cup", "ceramic"], ["mug", "ceramic"], ["bottle", "glass"],
			["can", "metal"], ["book", "paper"], ["box", "cardboard"], ["pot", "ceramic"], ["vase", "ceramic"]]:
		if pair[0] in text:
			return pair[1]
	return "wood"

static var _material_cache: Dictionary = {}

## Material parameters for a key; unknown keys fall back to wood with a warning.
static func params(key: String) -> Dictionary:
	if MATERIALS.has(key):
		return MATERIALS[key]
	if not key.is_empty():
		push_warning("Unknown physics_material '%s'; using wood." % key)
	return MATERIALS["wood"]

## Shared PhysicsMaterial per key (bodies never mutate it).
static func physics_material(key: String) -> PhysicsMaterial:
	if not MATERIALS.has(key):
		key = "wood"
	if _material_cache.has(key):
		return _material_cache[key]
	var values: Dictionary = MATERIALS[key]
	var material := PhysicsMaterial.new()
	material.friction = values.friction
	material.bounce = values.bounce
	material.rough = false
	material.absorbent = false
	_material_cache[key] = material
	return material

static func vec3(value, fallback := Vector3.ZERO) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback

static func _axis_basis(axis) -> Basis:
	if axis is Array or axis is Vector3:
		var direction := vec3(axis, Vector3.UP).normalized()
		if direction.is_zero_approx() or direction.is_equal_approx(Vector3.UP):
			return Basis.IDENTITY
		if direction.is_equal_approx(Vector3.DOWN):
			return Basis(Vector3.RIGHT, PI)
		return Basis(Quaternion(Vector3.UP, direction))
	match str(axis):
		"x":
			return Basis(Vector3.BACK, -PI * 0.5)
		"z":
			return Basis(Vector3.RIGHT, PI * 0.5)
	return Basis.IDENTITY

## One CollisionShape3D from a sidecar collider entry (box, cylinder, sphere,
## capsule, hull). Returns null for malformed entries.
static func make_shape(entry: Dictionary) -> CollisionShape3D:
	var kind := str(entry.get("kind", "box"))
	var shape: Shape3D
	var basis := Basis.IDENTITY
	var origin := vec3(entry.get("center", [0, 0, 0]))
	match kind:
		"box":
			var box := BoxShape3D.new()
			box.size = vec3(entry.get("size", [0.1, 0.1, 0.1]), Vector3.ONE * 0.1).max(Vector3.ONE * 0.004)
			shape = box
		"cylinder":
			var cylinder := CylinderShape3D.new()
			cylinder.radius = maxf(float(entry.get("radius", 0.05)), 0.003)
			cylinder.height = maxf(float(entry.get("height", 0.1)), 0.004)
			shape = cylinder
			basis = _axis_basis(entry.get("axis", "y"))
		"sphere":
			var sphere := SphereShape3D.new()
			sphere.radius = maxf(float(entry.get("radius", 0.05)), 0.003)
			shape = sphere
		"capsule":
			var capsule := CapsuleShape3D.new()
			capsule.radius = maxf(float(entry.get("radius", 0.05)), 0.003)
			# Godot capsule height is the full height including both caps.
			capsule.height = maxf(float(entry.get("height", 0.2)), capsule.radius * 2.0 + 0.001)
			shape = capsule
			basis = _axis_basis(entry.get("axis", "y"))
		"hull":
			var points := PackedVector3Array()
			for point in entry.get("points", []):
				points.append(vec3(point))
			if points.size() < 4:
				push_warning("Hull collider needs at least four points.")
				return null
			var hull := ConvexPolygonShape3D.new()
			hull.points = points
			shape = hull
		_:
			push_warning("Unknown collider kind '%s'." % kind)
			return null
	shape.margin = SHAPE_MARGIN
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var rotation_deg := vec3(entry.get("rotation_deg", [0, 0, 0]))
	if not rotation_deg.is_zero_approx():
		basis = Basis.from_euler(rotation_deg * (PI / 180.0)) * basis
	collision.transform = Transform3D(basis, origin)
	return collision

## Adds every collider of a sidecar to a body; returns the created nodes.
static func add_shapes(body: CollisionObject3D, colliders: Array) -> Array[CollisionShape3D]:
	var created: Array[CollisionShape3D] = []
	for entry in colliders:
		if not entry is Dictionary:
			continue
		var collision := make_shape(entry)
		if collision == null:
			continue
		collision.name = "Collider%d" % created.size()
		body.add_child(collision)
		created.append(collision)
	return created

## Local-space bounds of a body's collision shapes (used for CCD and spin limits).
static func shape_bounds(body: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child in body.get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.shape == null:
			continue
		var local := collision.transform * _shape_aabb(collision.shape)
		bounds = local if first else bounds.merge(local)
		first = false
	return bounds

## Smallest radius among round shapes (spheres, cylinders, capsules); 0 if none.
static func smallest_round_radius(body: Node3D) -> float:
	var smallest := 0.0
	for child in body.get_children():
		var collision := child as CollisionShape3D
		if collision == null:
			continue
		var radius := 0.0
		if collision.shape is SphereShape3D:
			radius = (collision.shape as SphereShape3D).radius
		elif collision.shape is CylinderShape3D:
			radius = (collision.shape as CylinderShape3D).radius
		elif collision.shape is CapsuleShape3D:
			radius = (collision.shape as CapsuleShape3D).radius
		if radius > 0.0 and (smallest == 0.0 or radius < smallest):
			smallest = radius
	return smallest

static func _shape_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var size: Vector3 = shape.size
		return AABB(-size * 0.5, size)
	if shape is SphereShape3D:
		var r: float = shape.radius
		return AABB(-Vector3.ONE * r, Vector3.ONE * r * 2.0)
	if shape is CylinderShape3D:
		var r: float = shape.radius
		var h: float = shape.height
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	if shape is CapsuleShape3D:
		var r: float = shape.radius
		var h: float = shape.height
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	if shape is ConvexPolygonShape3D:
		var points: PackedVector3Array = shape.points
		var box := AABB(points[0], Vector3.ZERO)
		for point in points:
			box = box.expand(point)
		return box
	return AABB(-Vector3.ONE * 0.05, Vector3.ONE * 0.1)

## Never-moving prop or architecture piece: StaticBody3D on the Room layer.
static func build_static(spec: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	var asset_id := str(spec.get("id", "static_prop"))
	body.name = asset_id.to_pascal_case() if not asset_id.is_empty() else "StaticProp"
	body.collision_layer = LAYER_ROOM
	body.collision_mask = STATIC_MASK
	var key := str(spec.get("physics_material", "wood"))
	var values := params(key)
	body.physics_material_override = physics_material(key)
	body.set_meta("asset_id", asset_id)
	body.set_meta("physics_material", key)
	body.set_meta("rolling_resistance", float(values.rolling))
	add_shapes(body, spec.get("colliders", []))
	return body
