extends SceneTree
## 0.31 (throwaway measuring tool): each weapon model's cross-sections in its own frame, and its sockets.

func _init() -> void:
	for spec: Array in [["glock17", "y", -.07, .08, .01], ["ar15", "z", -.5, .5, .04], ["shotgun", "z", -.6, .6, .05], ["sniper", "z", -.7, .7, .06]]:
		var scene := load("res://assets/models/story/%s.glb" % spec[0]) as PackedScene
		var root := scene.instantiate() as Node3D
		var points: PackedVector3Array = []
		_collect(root, Transform3D.IDENTITY, points)
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for p in points:
			lo = lo.min(p)
			hi = hi.max(p)
		print("MODEL ", spec[0], " points ", points.size(), " lo ", lo.snapped(Vector3.ONE * .001), " hi ", hi.snapped(Vector3.ONE * .001))
		for child in root.find_children("*", "Node3D", true, false):
			var node := child as Node3D
			if not (node is MeshInstance3D) and node.get_child_count() == 0:
				print("  SOCKET ", node.name, " ", _relative(node, root).origin.snapped(Vector3.ONE * .001))
		var axis := 1 if spec[1] == "y" else 2
		var at := float(spec[2])
		while at < float(spec[3]):
			var a := Vector3.INF
			var b := -Vector3.INF
			for p in points:
				if p[axis] >= at and p[axis] < at + float(spec[4]):
					a = a.min(p)
					b = b.max(p)
			if a.x < 1e9:
				if axis == 1:
					print("  y %.2f: x %.3f..%.3f  z %.3f..%.3f" % [at, a.x, b.x, a.z, b.z])
				else:
					print("  z %.2f: x %.3f..%.3f  y %.3f..%.3f" % [at, a.x, b.x, a.y, b.y])
			at += float(spec[4])
		root.free()
	quit()

func _collect(node: Node, xf: Transform3D, out: PackedVector3Array) -> void:
	var here := xf
	if node is Node3D and node.get_parent() != null:
		here = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				out.append(here * v)
	for child in node.get_children():
		_collect(child, here, out)

func _relative(node: Node3D, ancestor: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
