class_name InteriorLoadClock
extends RefCounted
## 0.30: start-up bookkeeping shared by the boot scene (scripts/boot.gd) and everything that builds the world.
##
## - `mark(label)`: one line per start-up step. `-- --load-report` prints them (milliseconds since the process
##   started, and since the previous mark); the loading screen moves its bar and caption from the same labels.
## - `staged`: true only while the boot scene is building the world behind the loading screen. Builders then
##   `await InteriorLoadClock.breathe()` between steps so a frame can be drawn. Without the boot scene (tests,
##   bakes, a scene reload) nothing ever waits and start-up runs in one go exactly as it did before 0.30.
## - `later(callable)`: what used to be `call_deferred` during start-up (settling props, installing gates, moon
##   beams). Unstaged it still is `call_deferred`; staged it is kept until the whole world stands, in the same
##   order, because those calls measure the finished world.
## - `kept`: every resource the boot scene read, held so a restart never reads the disk twice.

static var enabled := false
static var checked := false
static var previous := 0
static var marks: Array = []
static var staged := false
static var booted := false
static var screen: Node
static var kept: Array = []
static var _later: Array[Callable] = []
static var _last_yield := 0
static var _breath_ms := -1
## 0.35: the home menu is on the loading screen. A button pressed there before the world stands is kept here
## ("play" or "options") and carried out by scripts/interior.gd the moment it does; once it stands and until the
## loading screen has faded, the screen's buttons call `wish_ready` instead.
static var wish := ""
static var wish_ready := Callable()
## Profiling: microseconds spent in named helpers during start-up (printed by `-- --load-report`).
static var tallies: Dictionary = {}

static func mark(label: String) -> void:
	if not checked:
		checked = true
		# (0.64: a phone always writes its start-up times to the log: there is no command line to ask for them.)
		enabled = "--load-report" in OS.get_cmdline_user_args() or OS.has_feature("android")
		previous = 0
	var now := Time.get_ticks_msec()
	marks.append([label, now, now - previous])
	if enabled:
		print("INTERIOR_LOAD %6d ms  +%5d  %s" % [now, now - previous, label])
	previous = now
	if staged and is_instance_valid(screen):
		screen.call("stage", label)

## Lets one frame through when the last one was drawn more than a moment ago. Only ever called while `staged`.
static func breathe() -> void:
	if _breath_ms < 0:
		_breath_ms = 22
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--breathe-ms="):
				_breath_ms = int(argument.trim_prefix("--breathe-ms="))
	if Time.get_ticks_msec() - _last_yield < _breath_ms:
		return
	await (Engine.get_main_loop() as SceneTree).process_frame
	_last_yield = Time.get_ticks_msec()

static func tally(label: String, since_usec: int) -> void:
	tallies[label] = int(tallies.get(label, 0)) + Time.get_ticks_usec() - since_usec

static func later(callable: Callable) -> void:
	if staged:
		_later.append(callable)
	else:
		callable.call_deferred()

## The world stands: run what was put off, in order, and let the loading screen go.
static func finish() -> void:
	if not staged:
		return
	staged = false
	if is_instance_valid(screen) and screen.has_method("world_done"):
		screen.call("world_done")
	var list := _later.duplicate()
	_later.clear()
	for callable: Callable in list:
		if callable.is_valid():
			callable.call()
	mark("boot: done")
	if enabled:
		for label: String in tallies:
			print("INTERIOR_TALLY %7.1f ms  %s" % [float(tallies[label]) / 1000.0, label])
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.disable_3d = false
	var held := screen
	screen = null
	_reveal(tree, held)

## The first frames of the finished world compile its shaders: they are drawn under the loading screen, which only
## then fades. Captures and audits take the screen away at once, so it is never in their pictures.
static func _reveal(tree: SceneTree, held: Node) -> void:
	var unattended := false
	for argument in OS.get_cmdline_user_args():
		if (argument.begins_with("--capture") and argument != "--capture-loading") or argument in ["--performance-audit", "--benchmark", "--autoplay"]:
			unattended = true
	if unattended:
		if is_instance_valid(held):
			held.queue_free()
	else:
		for i in 3:
			await tree.process_frame
		mark("boot: first frames drawn")
		if is_instance_valid(held):
			held.call("finish")
	if "--load-quit" in OS.get_cmdline_user_args():
		_quit_soon()

## `-- --load-quit`: leaves once the menu has been on screen for a moment (tools/boot_manifest.py, timing runs).
static func _quit_soon() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for i in 3:
		await tree.process_frame
		mark("menu frame %d" % i)
	for i in 40:
		await tree.process_frame
	mark("40 more frames")
	for i in 60:
		await tree.process_frame
	inventory(tree)
	tree.quit()

## What the finished world consists of (`-- --load-report`): the staged and the one-go start must agree.
static func inventory(tree: SceneTree) -> void:
	var scene := tree.current_scene
	if scene == null:
		return
	var counts := {"nodes": 0, "meshes": 0, "multimeshes": 0, "lights": 0, "lights_on": 0, "decals": 0, "shapes": 0,
		"static_bodies": 0, "rigid_bodies": 0, "frozen": 0, "asleep": 0, "audio": 0, "particles": 0, "areas": 0,
		"movable": tree.get_nodes_in_group("movable").size(), "doors": tree.get_nodes_in_group("interior_doors").size()}
	var height := 0.0
	var masks := 0
	var todo: Array[Node] = [scene]
	while not todo.is_empty():
		var node: Node = todo.pop_back()
		todo.append_array(node.get_children())
		counts.nodes += 1
		if node is MultiMeshInstance3D: counts.multimeshes += 1
		elif node is MeshInstance3D: counts.meshes += 1
		elif node is Light3D:
			counts.lights += 1
			masks += (node as Light3D).light_cull_mask & 0xff
			if "--load-report-lights" in OS.get_cmdline_user_args():
				print("INTERIOR_LIGHT ", (node as Light3D).light_cull_mask & 0xff, " ", scene.get_path_to(node))
			if (node as Light3D).visible: counts.lights_on += 1
		elif node is Decal: counts.decals += 1
		elif node is CollisionShape3D: counts.shapes += 1
		elif node is StaticBody3D: counts.static_bodies += 1
		elif node is RigidBody3D:
			counts.rigid_bodies += 1
			height += (node as RigidBody3D).global_position.y
			if (node as RigidBody3D).freeze: counts.frozen += 1
			if (node as RigidBody3D).sleeping: counts.asleep += 1
		elif node is AudioStreamPlayer3D or node is AudioStreamPlayer: counts.audio += 1
		elif node is GPUParticles3D or node is CPUParticles3D: counts.particles += 1
		elif node is Area3D: counts.areas += 1
	counts["rigid_height_sum"] = snappedf(height, .1)
	counts["light_mask_sum"] = masks
	print("INTERIOR_INVENTORY ", JSON.stringify(counts))
