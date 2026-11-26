extends SceneTree
## Rendered audit shared with the exact exported APK/EXE.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var audit = preload("res://scripts/performance_audit.gd").new()
	root.add_child(audit)
	audit.start(main)
