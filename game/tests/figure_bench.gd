extends SceneTree
## 0.65 (diagnostic): where an infected figure's setup goes, step by step, rendered.
##   godot --path game --script res://tests/figure_bench.gd [--rendering-method gl_compatibility]
const Figure := preload("res://scripts/coop/figure.gd")
const Mission := preload("res://scripts/coop/mission.gd")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 1.5, 6)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for i in 10: await process_frame
	var sums := {}
	var kinds: Array = Mission.INFECTED.slice(0, 12)
	for pass_i in 2:
		for kind: String in kinds:
			var asset := "res://assets/characters/zombies/z_%s.glb" % kind
			var t := Time.get_ticks_usec()
			var marks := {}
			var scene := load(asset) as PackedScene
			marks.load = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			var model := scene.instantiate() as Node3D
			marks.instantiate = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			var body := CharacterBody3D.new()
			holder.add_child(body)
			body.add_child(model)
			marks.add_to_tree = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			InteriorZombie._load_shared()
			var clips := AnimationPlayer.new()
			model.add_child(clips)
			clips.add_animation_library("", InteriorZombie._library)
			clips.play("idle_hurt")
			marks.animation = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
			var bodies := {}
			InteriorZombie.build_ragdoll(skeleton, body, bodies, Figure.HIT_BONES)
			marks.ragdoll = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			var sev := InteriorZombieGore.Sever.new()
			skeleton.add_child(sev)
			marks.sever = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			clips.advance(0.0)
			marks.first_advance = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			clips.advance(0.016)
			marks.second_advance = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			await process_frame
			marks.first_frame = Time.get_ticks_usec() - t
			t = Time.get_ticks_usec()
			await process_frame
			marks.empty_frame = Time.get_ticks_usec() - t
			if pass_i == 1:
				for k: String in marks: sums[k] = int(sums.get(k, 0)) + int(marks[k])
			body.queue_free()
			await process_frame
	var n := float(kinds.size())
	for k: String in sums: print("FIGURE_BENCH %-14s %.2f ms" % [k, sums[k] / n / 1000.0])
	var lib: AnimationLibrary = InteriorZombie._library
	var tracks := 0
	for a in lib.get_animation_list(): tracks += lib.get_animation(a).get_track_count()
	print("FIGURE_BENCH library: %d animations, %d tracks" % [lib.get_animation_list().size(), tracks])
	quit(0)
