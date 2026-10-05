extends RefCounted
## Shared builders for the headless physics acceptance tests and the sandbox.

const PropPhysics = preload("res://scripts/prop_physics.gd")

static func static_box(parent: Node, center: Vector3, size: Vector3, material := "wood", rotation_deg := Vector3.ZERO) -> StaticBody3D:
	var body := PropPhysics.build_static({"id": "static_box", "physics_material": material,
		"colliders": [{"kind": "box", "center": [0, 0, 0], "size": [size.x, size.y, size.z]}]})
	body.transform = Transform3D(Basis.from_euler(rotation_deg * (PI / 180.0)), center)
	parent.add_child(body)
	return body

static func floor_slab(parent: Node, material := "wood") -> StaticBody3D:
	return static_box(parent, Vector3(0, -0.5, 0), Vector3(60, 1, 60), material)

## colliders: InteriorPropPhysics sidecar entries. Bodies spawn awake.
static func prop(parent: Node, colliders: Array, mass: float, material: String, position: Vector3, rotation_deg := Vector3.ZERO) -> InteriorObject:
	var body := InteriorObject.new()
	body.mass = mass
	body.physics_material = material
	body.transform = Transform3D(Basis.from_euler(rotation_deg * (PI / 180.0)), position)
	parent.add_child(body)
	PropPhysics.add_shapes(body, colliders)
	return body

static func ball(parent: Node, radius: float, mass: float, position: Vector3, material := "rubber") -> InteriorObject:
	return prop(parent, [{"kind": "sphere", "center": [0, 0, 0], "radius": radius}], mass, material, position)

static func block(parent: Node, size: Vector3, mass: float, position: Vector3, material := "wood", rotation_deg := Vector3.ZERO) -> InteriorObject:
	return prop(parent, [{"kind": "box", "center": [0, 0, 0], "size": [size.x, size.y, size.z]}], mass, material, position, rotation_deg)

static func tilt_deg(body: Node3D) -> float:
	return rad_to_deg(acos(clampf(body.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0)))

## Contact slip of a ball resting on a floor: |v + w x (-r up)|.
static func slip(body: RigidBody3D, radius: float) -> float:
	return (body.linear_velocity + body.angular_velocity.cross(Vector3.DOWN * radius)).length()
