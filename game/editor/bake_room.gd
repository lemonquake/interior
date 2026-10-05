extends SceneTree
## Bakes the procedurally assembled living room into an editable scene.
##
##   godot --headless --path game --script res://editor/bake_room.gd
##
## Writes res://scenes/room/living_room.tscn plus its meshes, materials and textures under
## res://assets/baked/. After baking, the scene is the source of truth: edit it in the Godot
## editor. Re-running this script OVERWRITES manual edits to that scene and the baked folder.

const RoomBuilder = preload("res://scripts/room_builder.gd")
const PetSpawner = preload("res://scripts/pet_spawner.gd")
const OUT_SCENE := "res://scenes/room/living_room.tscn"
const BAKED_DIR := "res://assets/baked"
const SETTLE_FRAMES := 120

## Folder for externalized resources; bake_balcony.gd reuses this script with its own.
var baked_dir := BAKED_DIR
var _done: Dictionary = {}
var _used_paths: Dictionary = {}
var _stats := {"nodes": 0, "meshes": 0, "materials": 0, "textures": 0, "shaders": 0, "shapes": 0, "pet_spawners": 0}

func _initialize() -> void:
	_bake.call_deferred()

func _bake() -> void:
	# Bodies must stay exactly where the builder placed them.
	PhysicsServer3D.set_active(false)
	var room := Node3D.new()
	room.name = "LivingRoom"
	root.add_child(room)
	var manifest := RoomBuilder.build(room)
	if manifest.is_empty():
		push_error("Room sources are missing; nothing was baked.")
		quit(1)
		return
	for i in 3:
		await process_frame
	await _settle(room)
	# The balcony scene keeps its own resources under assets/baked/balcony.
	_clear_directory(ProjectSettings.globalize_path(BAKED_DIR), ["balcony"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_SCENE.get_base_dir()))
	_convert_pets(room)
	_flatten(room, room)
	_externalize_node(room)
	var packed := PackedScene.new()
	var error := packed.pack(room)
	if error != OK:
		push_error("Packing the room failed: %s" % error)
		quit(1)
		return
	error = ResourceSaver.save(packed, OUT_SCENE)
	if error != OK:
		push_error("Saving the room scene failed: %s" % error)
		quit(1)
		return
	_stats["scene"] = OUT_SCENE
	print("INTERIOR_BAKE ", JSON.stringify(_stats))
	quit(0)

## Authored poses can float a few millimetres above their supports. Let loose props
## drop onto them so nothing jumps when first touched. Props that move far or tilt
## (an unstable stack) keep their authored pose instead.
func _settle(room: Node) -> void:
	var bodies: Array[Node] = []
	_collect(room, func(node: Node) -> bool: return node is InteriorObject and not node.anchored, bodies)
	var start: Dictionary = {}
	PhysicsServer3D.set_active(true)
	for body: InteriorObject in bodies:
		start[body] = body.global_transform
		body.dormant = false
		body.freeze = false
		body.sleeping = false
	var restless: Dictionary = {}
	for i in SETTLE_FRAMES:
		await physics_frame
		if i >= SETTLE_FRAMES - 30:
			for body: InteriorObject in bodies:
				if body.linear_velocity.length() > 0.02 or body.angular_velocity.length() > 0.2:
					restless[body] = true
	var kept := 0
	var reverted: Array[String] = []
	var anchored: Array[String] = []
	for body: InteriorObject in bodies:
		var before: Transform3D = start[body]
		var after := body.global_transform
		var tilt := rad_to_deg(before.basis.get_rotation_quaternion().angle_to(after.basis.get_rotation_quaternion()))
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		if restless.has(body) or before.origin.distance_to(after.origin) > 0.05 or tilt > 15.0:
			# Unstable authored arrangement: keep the authored pose (asleep). Heavy furniture
			# is also held until grabbed, so a bump does not leave it rocking or toppling.
			body.global_transform = before
			reverted.append(String(body.name))
			if body.mass >= 8.0:
				body.anchored = true
				body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
				body.freeze = true
				anchored.append(String(body.name))
		else:
			kept += 1
		body.start_asleep = true
		body.home_transform = body.global_transform
	PhysicsServer3D.set_active(false)
	_stats["settled"] = kept
	_stats["kept_authored_pose"] = reverted
	_stats["anchored_unstable"] = anchored

## Animated pets are rebuilt at runtime by InteriorPetSpawner; keep a static preview.
func _convert_pets(room: Node) -> void:
	var habitats: Array[Node] = []
	_collect(room, func(node: Node) -> bool: return node is HamsterEnclosure or node is InteriorAquarium, habitats)
	for habitat in habitats:
		var body := habitat.get_parent()
		var spawner := PetSpawner.new()
		if habitat is HamsterEnclosure:
			spawner.name = "HamsterSpawner"
			spawner.kind = "hamsters"
		else:
			spawner.name = "AquariumSpawner"
			spawner.kind = "aquarium"
			spawner.aquarium_scale = (habitat as InteriorAquarium).bowl_scale
			spawner.tank_size = (habitat as InteriorAquarium).tank_size
			spawner.visual_layers = int(body.get_meta("visual_layers", 1))
		var runtime_only: Array[Node] = []
		_collect(habitat, func(node: Node) -> bool: return node is InteriorHamster, runtime_only)
		for node in runtime_only:
			node.get_parent().remove_child(node)
			node.free()
		for group in ["hamster_habitats", "aquariums"]:
			habitat.remove_from_group(group)
		habitat.set_script(null)
		habitat.name = String(habitat.name) + "Preview"
		body.add_child(spawner)
		_stats.pet_spawners += 1

func _collect(node: Node, predicate: Callable, into: Array[Node]) -> void:
	for child in node.get_children():
		if predicate.call(child):
			into.append(child)
		_collect(child, predicate, into)

## Every node becomes part of the room scene (instanced GLB content is inlined) and
## keeps its groups when saved.
func _flatten(node: Node, room: Node) -> void:
	for child in node.get_children():
		if child.has_meta("keep_instance"):
			# Downloaded GLB models stay linked instances (InteriorModelKit.place).
			child.owner = room
			_stats.nodes += 1
			continue
		child.scene_file_path = ""
		child.owner = room
		for group in child.get_groups():
			if not String(group).begins_with("_"):
				# add_to_group() ignores the persistent flag for existing membership.
				child.remove_from_group(group)
				child.add_to_group(group, true)
		_stats.nodes += 1
		_flatten(child, room)

func _externalize_node(node: Node) -> void:
	for property in node.get_property_list():
		if property.type != TYPE_OBJECT or not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = node.get(property.name)
		if value is Resource and not value is Script:
			var replacement := _externalize(value)
			if replacement != value:
				node.set(property.name, replacement)
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.get_surface_override_material_count():
			var material := mesh_instance.get_surface_override_material(i)
			if material != null:
				mesh_instance.set_surface_override_material(i, _externalize(material))
	for child in node.get_children():
		if not child.has_meta("keep_instance"):
			_externalize_node(child)

func _is_clean(path: String) -> bool:
	return path.begins_with("res://") and not "::" in path and not path.begins_with("res://.godot")

## Saves generated or import-internal resources as standalone files so the scene stays
## small and every mesh/material can be opened and edited on its own.
func _externalize(resource: Resource) -> Resource:
	if resource == null or _is_clean(resource.resource_path):
		return resource
	var id := resource.get_instance_id()
	if _done.has(id):
		return _done[id]
	_done[id] = resource
	for property in resource.get_property_list():
		if property.type != TYPE_OBJECT or not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		var nested: Variant = resource.get(property.name)
		if nested is Resource and not nested is Script:
			var replacement := _externalize(nested)
			if replacement != nested:
				resource.set(property.name, replacement)
	if resource is ArrayMesh:
		for i in (resource as ArrayMesh).get_surface_count():
			var material := (resource as ArrayMesh).surface_get_material(i)
			if material != null:
				(resource as ArrayMesh).surface_set_material(i, _externalize(material))
	var folder := ""
	var extension := ""
	var counter := ""
	if resource is Material:
		folder = "materials"; extension = "tres"; counter = "materials"
	elif resource is Texture2D and not resource is ViewportTexture:
		folder = "textures"; extension = "res"; counter = "textures"
	elif resource is Shader:
		folder = "shaders"; extension = "gdshader"; counter = "shaders"
	elif resource is ArrayMesh or resource is MultiMesh:
		folder = "meshes"; extension = "res"; counter = "meshes"
	elif resource is ConcavePolygonShape3D or (resource is ConvexPolygonShape3D and (resource as ConvexPolygonShape3D).points.size() > 64):
		folder = "shapes"; extension = "res"; counter = "shapes"
	if folder.is_empty():
		# Primitive meshes, small shapes, environments and physics materials stay embedded.
		return resource
	var path := _unique_path(folder, resource.resource_name if not resource.resource_name.is_empty() else resource.get_class(), extension)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var flags := ResourceSaver.FLAG_CHANGE_PATH
	if extension == "res":
		flags |= ResourceSaver.FLAG_COMPRESS
	var error := ResourceSaver.save(resource, path, flags)
	if error != OK:
		push_error("Could not save %s (%s)" % [path, error])
		return resource
	resource.take_over_path(path)
	_stats[counter] += 1
	return resource

func _unique_path(folder: String, base_name: String, extension: String) -> String:
	var clean := base_name.to_snake_case().validate_filename().replace(" ", "_").replace("-", "_")
	while "__" in clean:
		clean = clean.replace("__", "_")
	clean = clean.trim_prefix("_").trim_suffix("_")
	if clean.is_empty():
		clean = "resource"
	var path := "%s/%s/%s.%s" % [baked_dir, folder, clean, extension]
	var index := 2
	while _used_paths.has(path):
		path = "%s/%s/%s_%d.%s" % [baked_dir, folder, clean, index, extension]
		index += 1
	_used_paths[path] = true
	return path

func _clear_directory(absolute: String, keep: Array = []) -> void:
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	for sub in directory.get_directories():
		if sub in keep:
			continue
		_clear_directory(absolute.path_join(sub))
		DirAccess.remove_absolute(absolute.path_join(sub))
	for file in directory.get_files():
		DirAccess.remove_absolute(absolute.path_join(file))
