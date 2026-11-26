extends Node
## 0.30: the first scene. It puts the loading screen up before anything heavy is touched, reads the whole game on
## background threads (main.tscn and every file the world builders ask for, listed in assets/boot_manifest.json by
## tools/boot_manifest.py), then adds the world and lets it build itself in steps (InteriorLoadClock.staged), so
## the bar keeps moving until the main menu is there. A restart comes back through here with everything still in
## memory.

const MAIN := "res://main.tscn"
const MANIFEST := "res://assets/boot_manifest.json"

var _screen: InteriorLoadingScreen
var _pending: Array[String] = []
var _total := 0
var _reading := false
var _main_done := false
var _asked := false
var _stall_at := 0

func _ready() -> void:
	InteriorLoadClock.mark("boot: engine up")
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--render-size="):
			var dimensions := argument.trim_prefix("--render-size=").split("x")
			if dimensions.size() == 2:
				get_window().mode = Window.MODE_WINDOWED
				get_window().borderless = true
				get_window().size = Vector2i(clampi(int(dimensions[0]), 640, 3840), clampi(int(dimensions[1]), 360, 2160))
	if GameSettings.get_value("fullscreen", false) and OS.get_cmdline_user_args().is_empty():
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	InteriorLoadClock.wish = ""
	InteriorLoadClock.wish_ready = Callable()
	_screen = InteriorLoadingScreen.new()
	add_child(_screen)
	var manifest: Variant = null
	if FileAccess.file_exists(MANIFEST):
		manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if manifest is Dictionary:
		_screen.shares = manifest.get("stages", {})
		# 0.64: never on a phone. Its renderer (Compatibility) finishes a texture on the main thread, so the image
		# threads waited on the main thread while it waited on them: the 0.63 APK stopped for good at 2% on the
		# loading screen. The preload also kept all 3,100 files (1.2 GB) in memory for the whole run, which a phone
		# cannot spare. There the world reads what it builds, step by step, and only what is still drawn stays.
		if not InteriorLoadClock.booted and not "--no-preload" in OS.get_cmdline_user_args() and not OS.has_feature("android"):
			for path: String in manifest.get("resources", []):
				_pending.append(path)
	# One frame with the screen on it before the disk is asked for anything.
	await get_tree().process_frame
	await get_tree().process_frame
	if "--capture-loading" in OS.get_cmdline_user_args():
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--capture-path="):
				_screen.capture(argument.trim_prefix("--capture-path="))
	# `-- --early-wish=play:3.0` (or options): that button of the early menu is clicked after so many seconds.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--early-wish="):
			var wish := argument.trim_prefix("--early-wish=").split(":")
			_screen.click(wish[0], wish[1] if wish.size() > 1 else "0")
	InteriorLoadClock.mark("boot: menu on screen")
	# 0.43: the preload no longer hands every file to Godot's loader threads at once. 2,623 parallel requests
	# deadlocked the engine on any PC without a warm shader cache (the materials and meshes compile shaders on the
	# worker threads while the main thread waits on them): the loading screen froze for good on every machine but
	# the one the game was made on. Now only images and sounds (pure data, no shaders) go to worker threads, a few
	# at a time; everything that can compile a shader is read here, on the main thread, a slice per frame.
	for path in _pending:
		if not ResourceLoader.exists(path):
			continue
		if path.get_extension() in THREADED and not _serial_only:
			_threaded.append(path)
		else:
			_serial.append(path)
	_pending.clear()
	_total = _threaded.size() + _serial.size()
	_reading = true
	_stall_at = Time.get_ticks_msec()

const THREADED := ["jpg", "png", "webp", "ogg", "wav", "mp3"]
## Images and sounds in flight on worker threads at once.
const IN_FLIGHT := 4
## Main-thread reading per frame (ms): the loading screen keeps moving between slices.
const SLICE_MS := 14
var _threaded: Array[String] = []
var _serial: Array[String] = []
var _done := 0
var _serial_only := "--serial-preload" in OS.get_cmdline_user_args()

func _process(_delta: float) -> void:
	if not _reading:
		return
	var started := Time.get_ticks_msec()
	# Worker threads: keep IN_FLIGHT images or sounds reading.
	var left: Array[String] = []
	for path in _pending:
		var state := ResourceLoader.load_threaded_get_status(path)
		if state == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			left.append(path)
		else:
			_done += 1
			if state == ResourceLoader.THREAD_LOAD_LOADED:
				InteriorLoadClock.kept.append(ResourceLoader.load_threaded_get(path))
	_pending = left
	while _pending.size() < IN_FLIGHT and not _threaded.is_empty():
		var path: String = _threaded.pop_front()
		if ResourceLoader.load_threaded_request(path, "", false) == OK:
			_pending.append(path)
		else:
			_done += 1
	# Main thread: one slice of materials, meshes, models and shaders.
	while not _serial.is_empty() and Time.get_ticks_msec() - started < SLICE_MS:
		var path: String = _serial.pop_front()
		var resource := ResourceLoader.load(path)
		if resource != null:
			InteriorLoadClock.kept.append(resource)
		_done += 1
	if _done != _last_done:
		_last_done = _done
		_stall_at = Time.get_ticks_msec()
	elif not _pending.is_empty() and Time.get_ticks_msec() - _stall_at > 8000:
		# A file the threads never finish: read it here instead of waiting for ever.
		_stall_at = Time.get_ticks_msec()
		push_warning("Loading: %d files stalled on threads, reading them on the main thread: %s" % [_pending.size(), ", ".join(_pending)])
		for path in _pending:
			_serial.append(path)
		_pending.clear()
	var files := 1.0 if _total == 0 else float(_done) / _total
	var reading_left := not (_pending.is_empty() and _threaded.is_empty() and _serial.is_empty())
	if not reading_left and not _asked:
		# Then the scene itself, alone: it compiles the scripts, and a script that preloads a file another thread
		# is half-way through reading fails to compile.
		InteriorLoadClock.mark("boot: files read")
		_asked = true
		ResourceLoader.load_threaded_request(MAIN, "PackedScene", false)
		_main_asked_at = Time.get_ticks_msec()
	var main_share := 0.0
	if _asked:
		var progress := []
		var status := ResourceLoader.load_threaded_get_status(MAIN, progress)
		_main_done = status != ResourceLoader.THREAD_LOAD_IN_PROGRESS
		main_share = 1.0 if _main_done else float(progress[0])
	_screen.set_files(files * .75 + main_share * .25)
	if _main_done:
		_reading = false
		_enter()

var _last_done := -1
var _main_asked_at := 0

func _enter() -> void:
	InteriorLoadClock.mark("boot: main scene read")
	var packed := ResourceLoader.load_threaded_get(MAIN) as PackedScene
	if packed == null:
		push_error("The game's main scene could not be read.")
		get_tree().quit(1)
		return
	# (0.64: not on a phone: the packed scene holds every district's meshes, so what the squad game drops there
	# would never leave memory.)
	if not packed in InteriorLoadClock.kept and not OS.has_feature("android"):
		InteriorLoadClock.kept.append(packed)
	await get_tree().process_frame
	var main := packed.instantiate()
	if main.get_script() == null:
		# 0.43: a script of the game failed to compile on this machine: say so instead of loading for ever.
		push_error("The game's main script could not be compiled.")
		_screen.set_caption("The game could not start (a script failed to load). Please send this file to the developer:
" + ProjectSettings.globalize_path("user://logs/godot.log"))
		return
	InteriorLoadClock.mark("boot: instantiated")
	await get_tree().process_frame
	var tree := get_tree()
	InteriorLoadClock.staged = true
	InteriorLoadClock.booted = true
	InteriorLoadClock.screen = _screen
	# The menu pauses the tree the moment the world is ready; pausing it now keeps everything exactly as still
	# while it is being built.
	tree.paused = true
	# Nothing of the half-built world is drawn (or has its shaders compiled) until it is whole.
	tree.root.disable_3d = true
	remove_child(_screen)
	tree.root.add_child(_screen)
	_screen.refocus()
	tree.root.add_child(main)
	tree.current_scene = main
	# 0.57: last under the root, so its `_input` sees every key and click first and keeps them from the half-built
	# world and its menu.
	tree.root.move_child(_screen, -1)
	queue_free()
