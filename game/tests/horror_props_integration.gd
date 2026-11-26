extends SceneTree
## Checks the generated prop textures in the actual town, canal batches and movable props.
## Godot --headless --path game --script res://tests/horror_props_integration.gd
var main: Node
var failures: Array[String] = []
var families: Dictionary = {}
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _record(material: Material) -> void:
	if material is StandardMaterial3D and material.has_meta("horror_prop_family"):
		var family: String = material.get_meta("horror_prop_family")
		families[family] = int(families.get(family, 0)) + 1
		check(material.albedo_texture != null, "Textured %s prop retains its image" % family)

func _run() -> void:
	for family: String in InteriorHorrorPropMaterials.FILES:
		var path: String = InteriorHorrorPropMaterials.ROOT + InteriorHorrorPropMaterials.FILES[family]
		check(ResourceLoader.exists(path), "Imported prop texture exists: " + path)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 12: await process_frame
	for child in main.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		_record(mesh.material_override)
		if mesh.mesh == null: continue
		for i in mesh.mesh.get_surface_count():
			_record(mesh.get_active_material(i))
	for family: String in InteriorHorrorPropMaterials.FILES:
		check(int(families.get(family, 0)) > 0, "Live props use the %s texture" % family)
	var town := get_first_node_in_group("neighbourhood")
	var decay: Dictionary = town.get_meta("abandoned_town", {})
	check(int(decay.get("textured_street_litter", 0)) >= 3, "Baked street paper, bags and cardboard are textured")
	var canal := main.find_child("Canal settlement", true, false)
	var canal_counts: Dictionary = canal.get_meta("counts", {})
	check(int(canal_counts.get("textured_prop_materials", 0)) >= 18, "Canal refuse and loose prop palette uses the artwork")
	print("INTERIOR_HORROR_PROPS ", JSON.stringify({"passed": failures.is_empty(), "checks": checks,
		"failures": failures, "families": families, "street_batches": decay.get("textured_street_litter", 0),
		"canal_materials": canal_counts.get("textured_prop_materials", 0)}))
	quit(0 if failures.is_empty() else 1)
