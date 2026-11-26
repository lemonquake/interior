extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var exporter = preload("res://addons/mobile_texture_budget/texture_export.gd").new()
	var failures: Array[String] = []
	var paths := ["res://assets/models/nature/tree_small_02_tree_small_02_leaves_diff_1k.png",
		"res://assets/models/nature/island_tree_01_island_tree_01_nor_gl_1k.jpg"]
	var rows: Array[Dictionary] = []
	for path in paths:
		var original := load(path) as Texture2D
		var before := original.get_size()
		var converted: Texture2D = exporter._customize_resource(original,path)
		if converted == null or converted.get_width() > 512 or original.get_size() != before:
			failures.append(path+" did not create an independent 512-pixel export copy")
			continue
		var image := converted.get_image()
		if not image.is_compressed() or not image.has_mipmaps(): failures.append(path+" lacks compressed mipmaps")
		var output := "user://android-texture-budget-check.res"
		if ResourceSaver.save(converted,output) != OK: failures.append("Texture resource could not serialize")
		var reloaded := ResourceLoader.load(output,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if reloaded == null or reloaded.get_size() != converted.get_size(): failures.append("Texture export copy failed round-trip")
		rows.append({"path":path,"source":str(before),"android":str(converted.get_size()),"format":image.get_format(),"bytes":image.get_data_size()})
	var report := {"passed":failures.is_empty(),"failures":failures,"textures":rows}
	FileAccess.open("res://../docs/mobile-performance/texture-export-check.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ANDROID_TEXTURE_EXPORT_CHECK ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
