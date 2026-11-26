extends "res://tests/canal_review.gd"
## Regression for shared world lighting changing as the camera moves west.
func _run() -> void:
	out = ProjectSettings.globalize_path("res://../docs/canal-darkness")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600,900)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	main._apply_quality(2)
	await frames(10)
	player = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("Stranger").process_mode = Node.PROCESS_MODE_DISABLED
	for layer: CanvasLayer in main.find_children("*","CanvasLayer",true,false): layer.visible = false
	var town := get_first_node_in_group("neighbourhood")
	var env: Environment = town._environment()
	var samples: Array[Dictionary] = []
	for x in [-23.0,-33.0,-43.0,-55.5,-23.0]:
		player.global_position = Vector3(x,-2.1,18)
		player.camera.global_position = Vector3(x,-.52,18)
		player.camera.look_at(Vector3(0,-.52,18))
		await frames(230)
		samples.append({"x":x,"energy":env.ambient_light_energy,"source":env.ambient_light_source,
			"color":str(env.ambient_light_color),"exposure":env.tonemap_exposure})
		assert(is_equal_approx(env.ambient_light_energy,.24),"Town ambient must remain dark at every westward position")
		assert(env.ambient_light_color.is_equal_approx(Color(.24,.28,.36)),"Canal must not lift shared ambient color")
		assert(is_equal_approx(env.tonemap_exposure,1.02),"Canal must not increase shared exposure")
		assert(env.ambient_light_source==samples[0].source,"Ambient source must not change entering canal")
	await shot("01-dark-boardwalk",Vector3(-55.5,-.38,20.5),Vector3(-54.8,-.4,39))
	await shot("02-old-street-from-canal",Vector3(-43.5,-.52,18),Vector3(-10,-.4,18))
	await shot("03-sparse-bulb",Vector3(-54.7,-.38,18),Vector3(-52.9,.35,19.9),66)
	var file := FileAccess.open(out.path_join("lighting.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"checks":20,"samples":samples,"views":measures},"\t"))
	print("CANAL_DARKNESS_REVIEW passed 20 checks")
	quit()
