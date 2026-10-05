class_name InteriorRoomBuilder
extends RefCounted
## Procedural assembly of the living room from living_room.glb + room_manifest.json.
## The game normally loads the baked, editable res://scenes/room/living_room.tscn instead;
## this builder is what editor/bake_room.gd runs to (re)generate that scene, and the
## runtime fallback when the baked scene is missing.

const ObjectScript = preload("res://scripts/physics_object.gd")
const PropColliders = preload("res://scripts/prop_colliders.gd")
const PropPhysics = preload("res://scripts/prop_physics.gd")
const RoomVisuals = preload("res://scripts/room_visuals.gd")
const EnclosureScript = preload("res://scripts/hamster_enclosure.gd")
const AquariumScript = preload("res://scripts/aquarium.gd")
const RoomSurroundings = preload("res://scripts/room_surroundings.gd")
const MANIFEST_PATH := "res://assets/room_manifest.json"

static func load_manifest() -> Dictionary:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

## Builds the room beneath `room`, which must already be inside the scene tree.
## Returns the manifest, or an empty dictionary when the source assets are missing.
static func build(room: Node3D) -> Dictionary:
	if not ResourceLoader.exists("res://assets/living_room.glb"):
		return {}
	var room_manifest := load_manifest()
	if room_manifest.is_empty():
		return {}
	var packed: PackedScene = load("res://assets/living_room.glb")
	var visual := packed.instantiate() as Node3D
	visual.name = "LivingRoomVisual"
	room.add_child(visual)
	for actor in room_manifest.actors:
		var mesh_node := visual.find_child(actor.nodeName, true, false) as Node3D
		if mesh_node == null:
			mesh_node = visual.find_child(str(actor.nodeName).replace(" ","_"),true,false) as Node3D
		if mesh_node == null:
			push_error("Missing room actor: " + str(actor.nodeName))
			continue
		var original := mesh_node.global_transform
		var asset_scale := original.basis.get_scale()
		original.basis = original.basis.orthonormalized()
		var body := ObjectScript.new() as InteriorObject
		body.name = actor.nodeName
		body.mass = float(actor.mass)
		body.display_name = actor.label
		body.anchored = bool(actor.anchored)
		if str(actor.assetId) == "photo_frame" and original.origin.y < 1.5:
			body.anchored = false
		body.set_meta("asset_id",str(actor.assetId))
		body.prop_id = str(actor.nodeName)
		body.physics_material = PropPhysics.material_for(str(actor.assetId), str(actor.label))
		# Heavy furniture is dragged at the grab point rather than carried.
		body.grab_mode = "drag" if body.mass >= 15.0 else "carry"
		body.start_asleep = true
		body.clue_digit = actor.get("clueDigit", "")
		body.clue_text = actor.get("clueText", "")
		room.add_child(body)
		body.add_to_group("original_room_props", true)
		body.global_transform = original
		mesh_node.reparent(body, true)
		mesh_node.transform = Transform3D(Basis.from_scale(asset_scale),Vector3.ZERO)
		for box in PropColliders.shapes_for(actor):
			var collision := CollisionShape3D.new()
			var shape: Shape3D
			if box.get("kind", "box") == "cylinder":
				var cylinder := CylinderShape3D.new()
				cylinder.height = float(box.height) * asset_scale.y
				cylinder.radius = float(box.radius) * asset_scale.x
				shape = cylinder
				collision.quaternion = Quaternion(Vector3.UP,_vector(box.axis).normalized())
			elif box.get("kind", "box") == "sphere":
				var sphere := SphereShape3D.new()
				sphere.radius = float(box.radius) * asset_scale.x
				shape = sphere
			else:
				var rectangle := BoxShape3D.new()
				rectangle.size = (_vector(box.size) * asset_scale).max(Vector3.ONE * 0.008)
				shape = rectangle
			shape.margin = 0.002
			collision.shape = shape
			body.add_child(collision)
			collision.position = _vector(box.center) * asset_scale
		if str(actor.assetId) == "pet_enclosure":
			EnclosureScript.attach_to(body)
			# The rebuilt wider trays need clearance from the left room wall.
			body.position.x = -2.60
		if str(actor.assetId) == "fish_bowl":
			# The aquarium shelf sits below the linked habitats, as in the reference.
			AquariumScript.attach_to(body)
			body.position.x = -2.76
			body.position.y = .15
		body.home_transform = body.global_transform
		# Start asleep (not frozen) at the photographed pose; Jolt wakes bodies on
		# contact. Wall-anchored frames/shelves freeze in InteriorObject until grabbed.
		body.sleeping = true
		if actor.get("console",false):
			body.add_to_group("mystery_console", true)
	var small_bowl := ObjectScript.new() as InteriorObject
	small_bowl.name = "SmallAquarium"
	room.add_child(small_bowl)
	AquariumScript.attach_to(small_bowl, .66)
	small_bowl.position = Vector3(-2.36,.15,-1.11)
	small_bowl.home_transform = small_bowl.global_transform
	small_bowl.physics_material = "glass"
	small_bowl.start_asleep = true
	small_bowl.sleeping = true
	var shell := StaticBody3D.new()
	shell.name = "RoomStructure"
	shell.collision_layer = 2
	shell.collision_mask = 5
	shell.physics_material_override = PhysicsMaterial.new()
	shell.physics_material_override.friction = .65
	shell.physics_material_override.bounce = 0.0
	room.add_child(shell)
	for item in room_manifest.staticColliders:
		if str(item.id) in RoomSurroundings.REPLACED_COLLIDERS:
			continue
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = _vector(item.size)
		shape.margin = 0.002
		collision.shape = shape
		shell.add_child(collision)
		collision.position = _vector(item.center)
	# Lighting rig (WorldEnvironment, downlights, LED strips, probes) owned by InteriorLighting.
	# Built for desktop; the rig itself switches to its mobile subset at runtime.
	InteriorLighting.create(room, {"lights": room_manifest.get("lights", [])}, false)
	var lights: Array = []
	RoomSurroundings.apply(room, visual, room_manifest)
	RoomVisuals.apply(room, visual, room_manifest, lights)
	print("INTERIOR_ROOM_READY ",JSON.stringify({"actors":room.get_tree().get_nodes_in_group("movable").size(),"original_actors":room.get_tree().get_nodes_in_group("original_room_props").size(),"expected_original":room_manifest.actors.size(),"base_triangles":room_manifest.geometryTriangles}))
	return room_manifest
