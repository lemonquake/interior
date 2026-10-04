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

func _ready() -> void:
	collision_layer = 4
	collision_mask = 7
	continuous_cd = true
	can_sleep = true
	linear_damp = 0.7
	angular_damp = 1.5
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.7
	physics_material_override.bounce = 0.08
	home_transform = global_transform
	add_to_group("movable")
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)

func activate(detach := false) -> void:
	if anchored and freeze and not detach:
		return
	dormant = false
	freeze = false
	sleeping = false

func _on_body_entered(other: Node) -> void:
	# Contact impulses may already have reduced velocity when this signal fires.
	# Any simulated body can wake an unattached furnishing it touches.
	if not freeze and other is InteriorObject:
		other.activate()

func _physics_process(_delta: float) -> void:
	if global_position.y < -4.0:
		recover()

func recover() -> void:
	global_transform = home_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true
	dormant = true
	freeze = true
