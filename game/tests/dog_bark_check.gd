extends SceneTree
## Windowed check (not --headless): the far dogs bark, far away, and never repeat a clip back to back.
##   godot --path game --script res://tests/dog_bark_check.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await process_frame
	var audio := main.find_children("*", "InteriorNightAudio", true, false)
	var voice: InteriorNightAudio = audio[0] if not audio.is_empty() else null
	var ok := voice != null
	var clips: Array[String] = []
	var distances: Array[float] = []
	if ok:
		for k in 4:
			voice._dog.stop()
			voice._dog_answer.stop()
			voice._answer_wait = -1.0
			voice._exposure = 1.0
			voice._dog_wait = 0.0
			# The game may sit paused on its menu: drive the dog logic directly.
			voice._update_dogs(.016, voice.player.camera.global_position)
			await process_frame
			ok = ok and voice._dog.playing
			clips.append(voice._last_dog)
			distances.append(snappedf(voice._dog.global_position.distance_to(voice.player.camera.global_position), .1))
		for k in range(1, clips.size()):
			ok = ok and clips[k] != clips[k - 1]
		for d in distances:
			ok = ok and d > 60.0
	print("DOG_BARK_CHECK ", JSON.stringify({"passed": ok, "clips": clips, "distances": distances}))
	quit(0 if ok else 1)
