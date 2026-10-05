class_name InteriorObject
extends RigidBody3D

var display_name := "Object"
var clue_digit := ""
var clue_text := ""
var home_transform := Transform3D.IDENTITY
var held := false
var discovered := false
var anchored := false
var dormant := false
var _physics_configured := false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 7
	continuous_cd = true
	can_sleep = true
	# Contact friction supplies most drag; air resistance stays modest.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.16
	angular_damp = 0.65
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.68
	physics_material_override.bounce = 0.025
	physics_material_override.rough = false
	home_transform = global_transform
	add_to_group("movable")
	contact_monitor = true
	max_contacts_reported = 12
	body_entered.connect(_on_body_entered)
	# Manifest collision shapes are appended immediately after add_child().
	_configure_mass_distribution.call_deferred()

func _configure_mass_distribution() -> void:
	if _physics_configured:
		return
	_physics_configured = true
	var weighted_center := Vector3.ZERO
	var volume := 0.0
	var minimum_y := INF
	var maximum_y := -INF
	for child in get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.shape == null:
			continue
		var shape := collision.shape
		var weight := 0.001
		var half_height := 0.01
		if shape is BoxShape3D:
			var dimensions: Vector3 = shape.size
			weight = dimensions.x * dimensions.y * dimensions.z
			half_height = dimensions.y * 0.5
		elif shape is CylinderShape3D:
			weight = PI * shape.radius * shape.radius * shape.height
			half_height = shape.height * 0.5
		elif shape is SphereShape3D:
			weight = 4.0 / 3.0 * PI * pow(shape.radius, 3)
			half_height = shape.radius
		weighted_center += collision.position * weight
		volume += weight
		minimum_y = minf(minimum_y, collision.position.y - half_height)
		maximum_y = maxf(maximum_y, collision.position.y + half_height)
	if volume > 0.0:
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = weighted_center / volume
		# Slightly lower dense framing helps chairs and tables settle on their feet.
		if mass >= 4.0 and maximum_y - minimum_y > 0.3:
			center_of_mass.y = maxf(minimum_y + 0.04, center_of_mass.y - (maximum_y - minimum_y) * 0.08)
	var label := (display_name + " " + str(name)).to_lower()
	if "fan" in label and volume > 0.0:
		# A standing fan carries its dense motor/counterweight in the foot. The
		# rotor collision cylinder is hollow and should not dominate its mass.
		center_of_mass.y = minimum_y + (maximum_y - minimum_y) * 0.2
		physics_material_override.friction = 0.6
		angular_damp = 1.1
	elif "cushion" in label or "pillow" in label or "sofa" in label:
		physics_material_override.friction = 0.88
		angular_damp = 1.0
	elif str(get_meta("asset_id", "")) in ["marble_table", "woven_tray", "potted_plant", "tissue_box"]:
		# Small stacked household props need non-bouncy support contacts. Even
		# mild restitution can keep a light tray rocking under its contents.
		physics_material_override.friction = 0.68
		physics_material_override.bounce = 0.0
	elif "metal" in label or "glass" in label:
		physics_material_override.friction = 0.48
		physics_material_override.bounce = 0.045
	elif "ball" in label:
		physics_material_override.friction = 0.42
		physics_material_override.bounce = 0.25
		angular_damp = 0.12

func activate(detach := false) -> void:
	if anchored and freeze and not detach:
		return
	dormant = false
	freeze = false
	sleeping = false

func _on_body_entered(other: Node) -> void:
	# Real contacts wake neighbouring furnishings; attached frames stay fixed.
	if not freeze and other is InteriorObject:
		other.activate()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not state.transform.origin.is_finite() or not state.linear_velocity.is_finite() or not state.angular_velocity.is_finite():
		state.transform = home_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		return
	# CCD handles throws; bounds prevent exceptional solver explosions.
	if state.linear_velocity.length_squared() > 400.0:
		state.linear_velocity = state.linear_velocity.limit_length(20.0)
	if state.angular_velocity.length_squared() > 144.0:
		state.angular_velocity = state.angular_velocity.limit_length(12.0)

func _physics_process(_delta: float) -> void:
	if not global_position.is_finite() or global_position.y < -4.0:
		recover()

func recover() -> void:
	held = false
	global_transform = home_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true
	dormant = true
	freeze = true
