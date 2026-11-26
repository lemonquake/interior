extends SceneTree
## 0.31 (measuring tool): the Glock's outline in its own frame (+Z the muzzle, +Y up, +X its left), slice by slice.

func _init() -> void:
	var scene := load("res://assets/models/story/glock17.glb") as PackedScene
	var root := scene.instantiate() as Node3D
	var points: PackedVector3Array = []
	_collect(root, Transform3D.IDENTITY, points)
	for found in root.find_children("*", "MeshInstance3D", true, false):
		var part: PackedVector3Array = []
		_collect_one(found, root, part)
		var plo := Vector3.INF
		var phi := -Vector3.INF
		for p in part:
			plo = plo.min(p)
			phi = phi.max(p)
		print("PART ", found.get_parent().name, "/", found.name, " ", plo.snapped(Vector3.ONE * .001), " .. ", phi.snapped(Vector3.ONE * .001))
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	print("GLOCK lo ", lo.snapped(Vector3.ONE * .001), " hi ", hi.snapped(Vector3.ONE * .001))
	var y := -.07
	while y < .08:
		var a := Vector3.INF
		var b := -Vector3.INF
		for p in points:
			if p.y >= y and p.y < y + .008:
				a = a.min(p)
				b = b.max(p)
		if a.x < 1e9:
			print("  y %.3f: x %.3f..%.3f  z %.3f..%.3f" % [y, a.x, b.x, a.z, b.z])
		y += .008
	var z := -.1
	while z < .12:
		var a := Vector3.INF
		var b := -Vector3.INF
		for p in points:
			if p.z >= z and p.z < z + .008:
				a = a.min(p)
				b = b.max(p)
		if a.x < 1e9:
			print("  z %.3f: x %.3f..%.3f  y %.3f..%.3f" % [z, a.x, b.x, a.y, b.y])
		z += .008
	root.free()
	quit()

func _collect(node: Node, xf: Transform3D, out: PackedVector3Array) -> void:
	var here := xf
	if node is Node3D and node.get_parent() != null:
		here = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and not String(node.get_parent().name).contains("Cylinder_004"):
		for vertex in (node as MeshInstance3D).mesh.get_faces():
			out.append(here * vertex)
	for child in node.get_children():
		_collect(child, here, out)

func _collect_one(node: Node, root: Node3D, out: PackedVector3Array) -> void:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != root:
		xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	for vertex in (node as MeshInstance3D).mesh.get_faces():
		out.append(xf * vertex)
