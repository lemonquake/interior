extends SceneTree
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func frames(n: int) -> void:
	for i in n: await physics_frame

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(12)
	var budget: Node = main.mobile_performance
	check(budget != null and budget.stats.get("geometry",0) > 3000,"Mobile budgets include the complete runtime world")
	check(budget.stats.get("range_culled",0) > 500,"Small world detail has distance limits")
	check(get_nodes_in_group("movable").size() >= 250,"All physical props remain present")
	for cycle in 2:
		main._apply_quality(2)
		await frames(35)
		check(is_equal_approx(root.mesh_lod_threshold,1.0),"High restores detailed mesh LOD")
		var restored_normals := 0
		for material: BaseMaterial3D in budget._materials:
			if budget._materials[material].normal:
				check(material.normal_enabled,"High restores authored normal maps")
				restored_normals += 1
		check(restored_normals > 10,"Normal-map restoration exercises real materials")
		main._apply_quality(0)
		await frames(35)
		check(is_equal_approx(root.mesh_lod_threshold,4.0),"Low uses cheaper mesh LOD")
		for material: BaseMaterial3D in budget._materials:
			check(not material.normal_enabled and not material.heightmap_enabled,"Low removes expensive surface features")
		for light in main.find_children("*","Light3D",true,false):
			check(not light.shadow_enabled,"Low never renders a dynamic shadow: "+str(light.name))
	root.size = Vector2i(3200,1440)
	main._apply_quality(0)
	await frames(2)
	check(root.scaling_3d_scale * 3200 <= 1281,"Dense phone screens stay within the Low 3D pixel budget")
	check(root.size == Vector2i(3200,1440),"3D scaling preserves native UI resolution")
	main._show_menu("pause")
	check(Engine.max_fps == 30,"Paused mobile rendering uses 30 FPS")
	main._play()
	check(Engine.max_fps == 60,"Mobile play restores the 60 FPS target")
	print("INTERIOR_MOBILE_BUDGET ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"budget":budget.stats}))
	quit(0 if failures.is_empty() else 1)
