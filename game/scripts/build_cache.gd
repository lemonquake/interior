class_name InteriorBuildCache
extends RefCounted
## 0.30: the merged meshes of the districts that are built at start-up (the canal settlement and its warren, the
## Nichols property, the siege wall, the street decay), kept in one file so start-up reads them instead of merging
## them again. Merging was the slowest part of every start: 2.6 s copying kit models into batches (each copy reads
## the model back from the graphics card) and 0.8 s indexing and generating tangents.
##
## The builders are seeded, so the same code always makes the same meshes. `signature()` covers the builder scripts
## and the kit models: run from the project (tests included), a file whose signature no longer matches is ignored
## and the meshes are merged as before. An exported game cannot check, so it trusts the file:
## ALWAYS re-bake before exporting (tools/boot_manifest.py does, and tools/export_windows.py runs it first).
##   bake:  godot --path game -- --bake-world-meshes --load-quit
##   skip:  -- --no-world-cache

const PATH := "res://assets/built/world_meshes.res"
## `InteriorBalconyBuilder._commit` prefixes whose batches are kept (each district commits exactly once).
const PREFIXES := ["Canal - ", "Nichols - ", "Siege - ", "Street decay - "]
const SOURCES := ["balcony_builder", "room_surroundings", "model_kit", "canal_settlement", "canal_warren",
	"nichols_property", "nichols_basement", "town_siege", "town_horror", "neighborhood_ground", "neighborhood",
	"build_cache", "night"]
const KIT_DIRS := ["res://assets/models/canal/kit/"]

static var baking := false
static var _checked := false
static var _index: Dictionary = {}
static var _baked: Dictionary = {}
static var _clashes: Dictionary = {}

static func _open() -> void:
	if _checked:
		return
	_checked = true
	var arguments := OS.get_cmdline_user_args()
	baking = "--bake-world-meshes" in arguments
	if baking or "--no-world-cache" in arguments or "--mobile-test" in arguments:
		return
	if RenderingServer.get_current_rendering_method() == "gl_compatibility" or not ResourceLoader.exists(PATH):
		return
	var library := load(PATH) as MeshLibrary
	if library == null:
		return
	if OS.has_feature("editor") and String(library.get_meta("signature", "")) != signature():
		print("InteriorBuildCache: the builders changed since the last bake; merging the meshes again (tools/boot_manifest.py re-bakes).")
		return
	for id in library.get_item_list():
		_index[library.get_item_name(id)] = library.get_item_mesh(id)

## True when the kept meshes are in use: the builders then skip the copying they would only throw away.
static func active() -> bool:
	_open()
	return not _index.is_empty()

static func mesh(label: String) -> Mesh:
	_open()
	return _index.get(label) as Mesh

static func store(label: String, built: Mesh) -> void:
	if not baking or built == null:
		return
	if _baked.has(label):
		_clashes[label] = true
	else:
		_baked[label] = built

## Bake run only: writes what was stored. A label that was committed twice is left out (it is not one mesh).
static func save() -> void:
	if not baking:
		return
	var library := MeshLibrary.new()
	var id := 0
	for label: String in _baked:
		if _clashes.has(label):
			continue
		library.create_item(id)
		library.set_item_name(id, label)
		library.set_item_mesh(id, _baked[label])
		id += 1
	library.set_meta("signature", signature())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	var error := ResourceSaver.save(library, PATH, ResourceSaver.FLAG_COMPRESS)
	print("INTERIOR_BUILD_CACHE ", JSON.stringify({"meshes": id, "left_out": _clashes.keys(), "error": error}))

static func signature() -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_MD5)
	for label: String in SOURCES:
		var path := "res://scripts/%s.gd" % label
		if FileAccess.file_exists(path):
			context.update(FileAccess.get_file_as_bytes(path))
	for folder: String in KIT_DIRS:
		var names := DirAccess.get_files_at(folder)
		for file in names:
			if file.ends_with(".glb"):
				context.update(("%s:%d" % [file, FileAccess.get_file_as_bytes(folder + file).size()]).to_utf8_buffer())
	return context.finish().hex_encode()
