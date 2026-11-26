extends SceneTree
## 0.39: the navy door, walked through in real time with the game's own lighting, grade and body-camera lens.
##   Godot --path game --script res://tests/doorway_review.gd -- --out=<dir>
## Saves a frame every quarter second from the middle of the room, out through the open door onto the balcony,
## turned round to look back in, and back inside again, and prints each frame's mean brightness and colour, so a
## jump at the doorway shows up as numbers, not only as a picture.
var main: Node
var out := "res://../work/v39/doorway"

func frames(n: int) -> void:
	for i in n: await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _stats(image: Image) -> Vector4:
	# Mean linear-ish brightness and channel means over a 64 x 36 grid (enough for a trend, cheap).
	var sum := Vector3.ZERO
	var n := 0
	for gy in 36:
		for gx in 64:
			var c := image.get_pixel(int((gx + .5) * image.get_width() / 64.0), int((gy + .5) * image.get_height() / 36.0))
			sum += Vector3(c.r, c.g, c.b)
			n += 1
	sum /= float(n)
	return Vector4(sum.x * .2126 + sum.y * .7152 + sum.z * .0722, sum.x, sum.y, sum.z)

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(40)
	var player: InteriorPlayer = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_physics_process(false)
	var stranger := main.get_node_or_null("Stranger")
	if stranger != null:
		stranger.process_mode = Node.PROCESS_MODE_DISABLED
		stranger.visible = false
	# Open the navy door (doorway x 1.39..2.43 in the wall at z = 2.9).
	for door in root.get_tree().get_nodes_in_group("interior_doors"):
		if door is InteriorHingedDoor and absf((door as Node3D).global_position.z - 2.9) < .6 and (door as Node3D).global_position.x > .8:
			(door as InteriorHingedDoor).snap(true)
	var camera: Camera3D = player.camera
	# [name, eye, look-at, seconds to get there]
	var path := [
		["01_room", Vector3(1.9, 1.6, .2), Vector3(1.9, 1.35, 4.0), 0.0],
		["02_room_hold", Vector3(1.9, 1.6, .2), Vector3(1.9, 1.35, 4.0), 2.0],
		["03_near_door", Vector3(1.9, 1.6, 2.2), Vector3(1.9, 1.35, 5.0), 1.0],
		["04_in_door", Vector3(1.9, 1.6, 2.9), Vector3(1.9, 1.35, 5.5), .6],
		["05_balcony", Vector3(1.9, 1.6, 3.7), Vector3(2.4, 1.2, 6.5), .7],
		["06_balcony_hold", Vector3(1.9, 1.6, 3.7), Vector3(2.4, 1.2, 6.5), 3.0],
		["07_look_back", Vector3(1.9, 1.6, 3.9), Vector3(1.9, 1.35, 0.0), .8],
		["08_look_back_hold", Vector3(1.9, 1.6, 3.9), Vector3(1.9, 1.35, 0.0), 3.0],
		["09_back_in", Vector3(1.9, 1.6, 1.4), Vector3(0.0, 1.3, -2.0), 1.4],
		["10_back_in_hold", Vector3(1.9, 1.6, 1.4), Vector3(0.0, 1.3, -2.0), 3.0],
	]
	var from_eye: Vector3 = path[0][1]
	var from_look: Vector3 = path[0][2]
	var index := 0
	var lines := PackedStringArray()
	for leg: Array in path:
		var steps := maxi(1, int(round(float(leg[3]) / .25)))
		for s in steps:
			var t := float(s + 1) / float(steps)
			var eye := from_eye.lerp(leg[1], t)
			var look := from_look.lerp(leg[2], t)
			player.global_position = eye - Vector3.UP * 1.58
			camera.global_position = eye
			camera.look_at(look, Vector3.UP)
			var until := Time.get_ticks_msec() + (250 if float(leg[3]) > 0.0 else 0)
			while Time.get_ticks_msec() < until:
				await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var st := _stats(image)
			var name := "%02d_%s_%d" % [index, leg[0], s]
			if s == steps - 1:
				image.save_png(out.path_join("%s.png" % name))
			var line := "DOORWAY %s z=%.2f luma=%.4f rgb=%.4f,%.4f,%.4f" % [name, eye.z, st.x, st.y, st.z, st.w]
			print(line)
			lines.append(line)
			index += 1
		from_eye = leg[1]
		from_look = leg[2]
	var file := FileAccess.open(out.path_join("doorway.txt"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	print("DOORWAY_REVIEW ", out)
	quit()
