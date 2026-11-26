extends SceneTree
## 0.30: start-up profile without the boot screen: load, instantiate and enter the tree, each timed.
##   godot --path game --script res://tests/load_profile.gd -- --load-report

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	InteriorLoadClock.mark("engine up")
	var packed := load("res://main.tscn") as PackedScene
	InteriorLoadClock.mark("main.tscn loaded")
	var main := packed.instantiate()
	InteriorLoadClock.mark("instantiated")
	root.add_child(main)
	current_scene = main
	InteriorLoadClock.mark("entered the tree (all _ready)")
	for i in 3:
		await process_frame
		InteriorLoadClock.mark("frame %d" % i)
	for i in 40:
		await process_frame
	InteriorLoadClock.mark("40 more frames")
	for i in 60:
		await process_frame
	InteriorLoadClock.inventory(self)
	quit()
