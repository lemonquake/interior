extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main._play()
	for i in 240:
		await physics_frame
	var moved: Array[Dictionary] = []
	for body in get_nodes_in_group("movable"):
		var distance: float = body.global_position.distance_to(body.home_transform.origin)
		var tilt: float = rad_to_deg(acos(clampf(body.global_basis.y.normalized().dot(body.home_transform.basis.y.normalized()),-1,1)))
		if distance > .08 or tilt > 12:
			moved.append({"object":body.name,"distance":distance,"tilt":tilt,"position":str(body.global_position)})
	print("INTERIOR_SETTLING ",JSON.stringify({"passed":moved.is_empty(),"moved":moved,"seconds":4}))
	quit(0 if moved.is_empty() else 1)
