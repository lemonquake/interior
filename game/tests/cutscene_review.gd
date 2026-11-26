extends SceneTree
## 0.23: frames of the hooded man's cutscene and of him crouching out through the hole in the town wall
## (Forward+, High, 1600x900, the game's own night lighting).
##   Godot --path game --script res://tests/cutscene_review.gd -- [--out=<dir>]
## Writes cut-<s>.png at moments of the film, then hole-<n>.png as he goes through the hole (seen from street B).

var main: Node
var player: InteriorPlayer
var stranger: InteriorStranger
var out := "res://../work/v23/cutscene"

func _initialize() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n: await process_frame

func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("CUTSCENE_FRAME ", label, " state=", InteriorStranger.State.keys()[stranger.state], " t=", snappedf(float(stranger.get("_cut_time")), .01))

func _look(at: Vector3, target: Vector3) -> void:
	player.reset_motion(at)
	var eye := at + Vector3.UP * 1.58
	var to := target - eye
	player.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
	player.set("_look_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
	player.camera.rotation.x = player.get("_look_pitch")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	main._apply_quality(2)
	await _frames(30)
	player = main.player
	stranger = main.get_node("Stranger") as InteriorStranger
	# On the stair, looking down at the gate: he is seen.
	var stair := Vector3(5.25, -.08, 3.3)
	_look(stair, Vector3(12.6, -1.6, 4.4))
	for i in 240:
		await physics_frame
		if stranger.state == InteriorStranger.State.CUTSCENE: break
	var marks := [.4, 1.6, 2.5, 3.2, 3.9, 4.6, 5.4, 6.4, 7.6, 8.4]
	for mark: float in marks:
		while float(stranger.get("_cut_time")) < mark and stranger.state == InteriorStranger.State.CUTSCENE:
			await process_frame
		await _save("cut-%04.1f" % mark)
	await _frames(60)
	await _save("cut-after")
	# The gate opens: he is at the hole. From the corner of streets A and B, then close, as he goes through.
	var gate: Node = stranger.get("_gate")
	gate.unlock()
	gate.snap_open()
	await _frames(5)
	_look(Vector3(20.2, -2.9, 30.0), Vector3(21.3, -1.6, 53.5))
	await _frames(20)
	await _save("hole-0-waiting")
	_look(Vector3(18.6, -2.9, 46.5), Vector3(21.3, -2.0, 54.3))
	for i in 600:
		await physics_frame
		if stranger.state == InteriorStranger.State.CRAWLING: break
	var shots := 0
	var begin := Time.get_ticks_msec()
	while shots < 6 and stranger.state in [InteriorStranger.State.CRAWLING, InteriorStranger.State.FLEEING]:
		await process_frame
		if (Time.get_ticks_msec() - begin) / 1000.0 >= .7 * shots:
			await _save("hole-%d" % (shots + 1))
			shots += 1
	print("CUTSCENE_REVIEW_COMPLETE")
	quit()
