extends SceneTree
func _init() -> void:
	var scene := (load("res://assets/models/story/glock17.glb") as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	var total := AABB()
	var first := true
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var to_root := Transform3D.IDENTITY
		var n: Node = mesh
		while n != scene:
			to_root = (n as Node3D).transform * to_root
			n = n.get_parent()
		var box := to_root * mesh.get_aabb()
		print(mesh.get_parent().name, "/", mesh.name, "  y ", snappedf(box.position.y, .001), "..", snappedf(box.end.y, .001), "  z ", snappedf(box.position.z, .001), "..", snappedf(box.end.z, .001), "  x ", snappedf(box.position.x, .001), "..", snappedf(box.end.x, .001))
		total = box if first else total.merge(box)
		first = false
	print("TOTAL y ", total.position.y, "..", total.end.y, " z ", total.position.z, "..", total.end.z)
	print("KIT ", InteriorModelKit.local_bounds(scene))
	quit()
