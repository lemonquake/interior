extends "res://tests/sleep_review.gd"
## Refresh guide annotations without rerunning unrelated gameplay checks.
func _run() -> void:
	directory = ProjectSettings.globalize_path("res://../docs/sleep-menu")
	root.size = Vector2i(1600,900)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await wait_for(1)
	main.ui.hide()
	var player: InteriorPlayer = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(20.8,-2.89,5.1)
	player.camera.global_position = Vector3(20.8,-1.3,5.1)
	player.camera.look_at(Vector3(22.8,-1.2,11.5))
	await wait_for(2)
	var enc = get_first_node_in_group("neighbourhood").get_node("Neighborhood interactions/Quiet encounters")
	mark(enc.PSST_SOURCE,"Psst comes from behind this wall")
	await shot("06-psst-location")
	quit()
