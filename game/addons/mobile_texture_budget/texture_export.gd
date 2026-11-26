@tool
extends EditorExportPlugin
## Android-only export copies. The desktop imports and original images are untouched.
var converted: Array[Dictionary] = []
var _cache: Dictionary = {}

func _get_name() -> String: return "Android texture budget"
func _begin_customize_resources(_platform: EditorExportPlatform, features: PackedStringArray) -> bool:
	return "android" in features
func _get_customization_configuration_hash() -> int:
	return hash("interior-android-texture-budget-v3-characters-coop-school-nichols-raw-to-etc2")

## Imported as VRAM-compressed (its .import says compress/mode=2): the export already carries an ETC2 copy.
func _gpu_compressed(source: String) -> bool:
	var settings := FileAccess.get_file_as_string(source + ".import")
	return settings.is_empty() or settings.contains("compress/mode=2") or settings.contains("compress/mode=3") or settings.contains("compress/mode=4")

func _customize_resource(resource: Resource, path: String) -> Resource:
	if not resource is Texture2D: return null
	var original := resource as Texture2D
	var source := path if not path.is_empty() else original.resource_path
	var limit := 0
	if source.begins_with("res://assets/models/"):
		limit = 512
	elif source.begins_with("res://assets/outdoor/") or source.begins_with("res://assets/surfaces/") or source.begins_with("res://assets/horror_textures/") or source.begins_with("res://assets/materials/"):
		limit = 1024
	# 0.64: the squad game's own pictures had no phone budget at all, and most of them were imported lossless, so a
	# phone held them uncompressed (four bytes a pixel): the infected and the survivors alone ~370 MB of graphics
	# memory if all were drawn. Here they are cut to ETC2 (a quarter of that) and, past the limit, made smaller.
	elif source.begins_with("res://assets/characters/") or source.begins_with("res://assets/school/") or source.begins_with("res://assets/nichols/") or source.begins_with("res://assets/zombies/") or source.begins_with("res://assets/grenade/") or source.begins_with("res://assets/fields/"):
		limit = 1024
	elif source.begins_with("res://assets/coop/"):
		limit = 2048
	if limit == 0: return null
	var oversize := maxi(original.get_width(),original.get_height()) > limit
	if not oversize and _gpu_compressed(source): return null
	if _cache.has(source): return _cache[source]
	var key := source+str(FileAccess.get_modified_time(source))+str(FileAccess.get_modified_time(source+".import"))+str(limit)+"etc2-shared-v3"
	var folder := "res://.godot/mobile_texture_budget"
	var cached_path := folder.path_join(key.md5_text()+".res")
	if FileAccess.file_exists(cached_path):
		var cached := ResourceLoader.load(cached_path,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if cached != null:
			cached.set_path_cache(source)
			_cache[source] = cached
			converted.append({"path":source,"source_size":str(original.get_size()),"android_size":str(cached.get_size()),"bytes":cached.get_image().get_data_size(),"cached":true})
			return cached
	var image := original.get_image()
	if image == null or image.is_empty(): return null
	if image.is_compressed() and image.decompress() != OK:
		push_error("Cannot decode Android texture: "+source)
		return null
	image.clear_mipmaps()
	if oversize:
		var ratio := float(limit)/maxi(image.get_width(),image.get_height())
		image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	if image.compress(Image.COMPRESS_ETC2) != OK:
		push_error("Cannot compress Android texture: "+source)
		return null
	var texture := ImageTexture.create_from_image(image)
	texture.resource_name = original.resource_name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var saved := ResourceSaver.save(texture,cached_path)
	if saved != OK: push_error("Could not cache Android texture: "+source)
	# Keep external references shared. An unnamed replacement would be embedded
	# independently in every model scene, duplicating both download and GPU memory.
	texture.set_path_cache(source)
	_cache[source] = texture
	converted.append({"path":source,"source_size":str(original.get_size()),"android_size":str(texture.get_size()),"bytes":image.get_data_size()})
	if converted.size()%50 == 0: print("ANDROID_TEXTURE_PROGRESS ",converted.size()," ",source)
	return texture

func _end_customize_resources() -> void:
	_write_manifest()

func _export_end() -> void:
	if not converted.is_empty(): _write_manifest()

func _write_manifest() -> void:
	if converted.is_empty(): return
	var directory := ProjectSettings.globalize_path("res://../docs/mobile-performance")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("android-texture-budget.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"customized":converted.size(),"textures":converted},"\t"))
	print("ANDROID_TEXTURE_BUDGET ",converted.size())
	_cache.clear()
	converted.clear()
