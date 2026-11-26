class_name InteriorStaticInstancer
extends RefCounted
## 0.66 (the NOW standard): repeated static models drawn as one instanced draw per mesh per 24 m square.
##
## The canal settlement drew every reed, fern, rock, shrub, bamboo clump and snag as its own instance: from the canal
## bridge ~150 of its ~680 draws were the same dozen meshes over and over. Here the chosen children of a district
## (by name: `hints`) that are plain static models (no script, no physics body, no animation, light, particles or
## skin anywhere in them; trees never: performance.gd switches their shadows by distance) are gathered by mesh,
## materials and how they are drawn (layers, shadow, distance range), and each group of two or more in a CELL square
## becomes one MultiMeshInstance3D; the originals are freed. What is drawn is the same: the same meshes, materials and
## transforms, the distance range widened by the square's half diagonal (the range is measured to the square's
## centre). `-- --no-instancing` leaves them as they were (A/B).

const CELL := 24.0

## Instanced the children of `root` whose lower-case names contain one of `hints` (and none of `never`). Returns
## [originals replaced, instanced draws made].
static func batch(root: Node3D, hints: Array, never: Array = []) -> Array:
	if "--no-instancing" in OS.get_cmdline_user_args(): return [0, 0]
	var groups := {}
	var order: Array = []
	var replaced: Array[Node] = []
	for child in root.get_children():
		if not child is Node3D or child.get_script() != null: continue
		var label := String(child.name).to_lower()
		var wanted := false
		for h: String in hints:
			if label.contains(h): wanted = true
		for n: String in never:
			if label.contains(n): wanted = false
		if not wanted or InteriorPerformance._is_tree(child): continue
		var meshes := _plain_meshes(child as Node3D)
		if meshes.is_empty(): continue
		for mi: MeshInstance3D in meshes:
			var xf := _relative(mi, root)
			var mats := []
			for s in mi.mesh.get_surface_count(): mats.append(mi.get_active_material(s))
			var look := "%d|%d|%.2f|%.2f|%d|%d" % [mi.layers, mi.cast_shadow, mi.visibility_range_end, mi.visibility_range_end_margin, mi.visibility_range_fade_mode, mi.gi_mode]
			var ids := []
			for m in mats: ids.append(m.get_instance_id() if m != null else 0)
			var cell := Vector2i(floori(xf.origin.x / CELL), floori(xf.origin.z / CELL))
			var key := "%d|%s|%s|%s" % [mi.mesh.get_instance_id(), str(ids), look, str(cell)]
			if not groups.has(key):
				groups[key] = {"mesh": mi.mesh, "mats": mats, "proto": mi, "xfs": [], "nodes": []}
				order.append(key)
			groups[key].xfs.append(xf)
			groups[key].nodes.append(mi)
		replaced.append(child)
	var made := 0
	var gone := {}
	var shared := {}
	for key in order:
		var g: Dictionary = groups[key]
		if (g.xfs as Array).size() < 2: continue
		var proto: MeshInstance3D = g.proto
		var mesh: Mesh = g.mesh
		var mats: Array = g.mats
		# The materials the instances wore (overrides included) on a mesh of their own, shared by every square.
		var mkey := "%d|%s" % [mesh.get_instance_id(), str(mats.map(func(m): return m.get_instance_id() if m != null else 0))]
		if not shared.has(mkey): shared[mkey] = _dressed(mesh, mats)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = shared[mkey]
		mm.instance_count = (g.xfs as Array).size()
		for i in mm.instance_count: mm.set_instance_transform(i, g.xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Instanced %s" % String(proto.get_parent().name).rstrip("0123456789_ ")
		mmi.multimesh = mm
		mmi.layers = proto.layers
		mmi.cast_shadow = proto.cast_shadow
		mmi.gi_mode = proto.gi_mode
		if proto.visibility_range_end > 0.0:
			mmi.visibility_range_end = proto.visibility_range_end + CELL * .71
			mmi.visibility_range_end_margin = proto.visibility_range_end_margin
			mmi.visibility_range_fade_mode = proto.visibility_range_fade_mode
		root.add_child(mmi, true)
		made += 1
		for n: Node in g.nodes: gone[n] = true
	# The originals go: every mesh that went into a draw; a model left with no meshes goes whole.
	var count := 0
	for n: Node in gone.keys():
		n.get_parent().remove_child(n)
		n.free()
		count += 1
	for child in replaced:
		if is_instance_valid(child) and child.find_children("*", "GeometryInstance3D", true, false).is_empty():
			child.get_parent().remove_child(child)
			child.free()
	return [count, made]

## The MeshInstance3D nodes of a plain static model, or nothing when anything in it moves, simulates or is scripted.
static func _plain_meshes(node: Node3D) -> Array:
	var out: Array = []
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != node and n.get_script() != null: return []
		if n is PhysicsBody3D or n is AnimationPlayer or n is AnimationTree or n is Light3D or n is GPUParticles3D \
				or n is CPUParticles3D or n is Skeleton3D or n is AudioStreamPlayer3D or n is Area3D: return []
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null or mi.skin != null or mi.mesh.get_blend_shape_count() > 0 or mi.material_overlay != null: return []
			out.append(mi)
		elif n is GeometryInstance3D:
			return []
		for c in n.get_children(): stack.append(c)
	return out

static func _relative(n: Node3D, root: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t

## `mesh` with `mats` set on its surfaces (a copy only when they differ from its own).
static func _dressed(mesh: Mesh, mats: Array) -> Mesh:
	var same := true
	for s in mesh.get_surface_count():
		if mesh.surface_get_material(s) != mats[s]: same = false
	if same: return mesh
	var copy := ArrayMesh.new()
	for s in mesh.get_surface_count():
		copy.add_surface_from_arrays(mesh.surface_get_primitive_type(s), mesh.surface_get_arrays(s))
		copy.surface_set_material(copy.get_surface_count() - 1, mats[s])
	copy.custom_aabb = mesh.get_aabb()
	return copy
