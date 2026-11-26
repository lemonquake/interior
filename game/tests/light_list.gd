extends SceneTree
## 0.33: every lamp in the finished world: where it hangs, how far it reaches, what it is called.
##   godot --headless --path game --script res://tests/light_list.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i in 120:
		await process_frame
	var groups := {}
	for node in main.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light is DirectionalLight3D:
			continue
		var reach := 0.0
		if light is OmniLight3D:
			reach = (light as OmniLight3D).omni_range
		elif light is SpotLight3D:
			reach = (light as SpotLight3D).spot_range
		var path := str(main.get_path_to(light))
		var parts := path.split("/")
		var key := "%s | %s | %s" % ["/".join(parts.slice(0, mini(parts.size() - 1, 3))), String(light.name).rstrip("0123456789@"), light.get_class()]
		if not groups.has(key):
			groups[key] = {"n": 0, "energy": [], "reach": reach, "on": 0, "meta": light.get_meta_list(), "shadow": light.shadow_enabled, "vp": light.get_viewport() == root}
		groups[key].n += 1
		groups[key].on += 1 if light.is_visible_in_tree() and light.light_energy > .01 else 0
		if groups[key].energy.size() < 3:
			groups[key].energy.append(snappedf(light.light_energy, .01))
	for key: String in groups:
		print("LIGHT ", key, "  ", JSON.stringify(groups[key]))
	quit()
