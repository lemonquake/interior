extends Node
## 0.65: a phone reads the town's infected (their models and textures) and the sounds of the wounds while a menu is
## open (the main menu, the lobby, a chapter board, pause), one file at a time, on the main thread (no worker threads:
## a phone's renderer finishes textures on the main thread, boot.gd), and keeps them for the run. Without it each
## infected's model was read from storage the first time one of its kind came: 50-150 ms of a frame on a phone, in
## the middle of the store's siege, again and again. A phone with less than 3.5 GB keeps the first KINDS_SMALL kinds.
## (A PC reads everything at boot already. The college's people are read at the mart's chapter board.)
## `-- --phone-warm` runs it on a PC (for tests).

const KINDS_SMALL := 24
const GAP := .12
var main: Node
var queue: Array[String] = []
var kept: Array = []
var _wait := 0.0

func setup(scene: Node) -> void:
	main = scene
	name = "Phone warm"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for file in DirAccess.get_files_at("res://assets/audio/zombies"):
		var sound := file.trim_suffix(".import").trim_suffix(".remap")
		if sound.get_extension() in ["ogg", "wav"] and not ("res://assets/audio/zombies/" + sound) in queue:
			queue.append("res://assets/audio/zombies/" + sound)
	var mission := load("res://scripts/coop/mission.gd") as GDScript
	if mission == null:
		return
	var consts := mission.get_script_constant_map()
	var infected: Array = consts.get("INFECTED", [])
	var count := mini(int(consts.get("STUDENT_FIRST", infected.size())), infected.size())
	var memory: Dictionary = OS.get_memory_info()
	if int(memory.get("physical", 0)) > 0 and int(memory.get("physical", 0)) < 3500 * 1024 * 1024:
		count = mini(count, KINDS_SMALL)
	for i in count:
		var path := "res://assets/characters/zombies/z_%s.glb" % infected[i]
		if ResourceLoader.exists(path):
			queue.append(path)
	print("INTERIOR_PHONE_WARM %d files to read in the menus (%d MB of memory)" % [queue.size(), int(memory.get("physical", 0)) / 1048576])

func _process(delta: float) -> void:
	if queue.is_empty():
		set_process(false)
		print("INTERIOR_PHONE_WARM done")
		return
	var menu: Control = main.get("menu")
	if menu == null or not menu.visible or InteriorLoadClock.staged:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = GAP
	var path: String = queue.pop_front()
	var resource := ResourceLoader.load(path)
	if resource != null:
		kept.append(resource)
