extends SceneTree
var main: Node
var failures: Array[String] = []
var checks := 0
var directory := ""
var steps := 0

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func wait_for(seconds: float) -> void: await create_timer(seconds).timeout
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
func button(label: String) -> Button:
	for child in main.menu_content.get_children():
		if child is Button and child.text == label: return child
	return null
func menu_fits() -> bool:
	return Rect2(Vector2.ZERO, main.menu.get_parent().size).encloses(main.menu.get_rect())

func mark(at: Vector3, text: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var point: Vector2 = main.player.camera.unproject_position(at)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",24)
	label.add_theme_color_override("font_outline_color",Color(.01,.02,.025))
	label.add_theme_constant_override("outline_size",8)
	label.position = Vector2(clampf(point.x-160,30,820),maxf(point.y-105,40))
	layer.add_child(label)
	var line := Line2D.new()
	line.width = 3
	line.default_color = Color(.81,.91,.83)
	line.points = PackedVector2Array([label.position+Vector2(150,35),point,point+Vector2(-10,-15),point,point+Vector2(13,-12)])
	layer.add_child(line)
	return layer

func audio_sample(voice: Node, action: Callable, filename: String, seconds: float) -> float:
	var old_bus: String = voice.bus
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, "Review output")
	AudioServer.set_bus_send(index, "Master")
	voice.bus = "Review output"
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(index, record)
	record.set_recording_active(true)
	action.call()
	var peak := -100.0
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		await process_frame
		peak = maxf(peak, maxf(AudioServer.get_bus_peak_volume_left_db(index, 0), AudioServer.get_bus_peak_volume_right_db(index, 0)))
	record.set_recording_active(false)
	var recording := record.get_recording()
	check(recording != null and not recording.data.is_empty(), filename + " produces PCM samples")
	if recording != null:
		recording.save_to_wav(directory.path_join(filename + ".wav"))
		# Use all recorded samples: sparse render frames can miss a short heel-strike peak.
		var data := recording.data
		var sample_peak := 0
		for i in range(0, data.size(), 2): sample_peak = maxi(sample_peak, absi(data.decode_s16(i)))
		peak = linear_to_db(maxf(float(sample_peak) / 32768.0, .000001))
	voice.bus = old_bus
	AudioServer.remove_bus(index)
	return peak

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://../docs/sleep-menu")
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1600,900)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await wait_for(3)
	Input.warp_mouse(Vector2(1500,850))
	check(main.menu_street.camera.is_current(), "Home uses the live neighborhood camera")
	check(not main.player.playing and paused, "Home does not advance player or story")
	check(menu_fits(), "Home fits the viewport")
	check(main.menu_content.get_child_count() == 6, "Home has only title, credit, spacing and three buttons")
	check(main.menu_content.get_child(0).text == "Sleep", "Game title is Sleep")
	var town := get_first_node_in_group("neighbourhood")
	var enc = town.get_node("Neighborhood interactions/Quiet encounters")
	check(enc.fired.is_empty(), "Menu does not consume encounters")
	check(town.get_node("Tattered slipper and street litter/Single worn tsinelas") != null, "One 3D slipper exists in the actual town")
	var before: float = main.menu_street.elapsed
	var flicker: float = main.get_node("Balcony")._flicker_time
	await shot("01-main-menu")
	await wait_for(1)
	check(main.menu_street.elapsed > before and main.get_node("Balcony")._flicker_time > flicker, "Camera and street lighting animate while menu is open")
	await shot("02-menu-live-later")
	root.size = Vector2i(1280,720)
	await wait_for(.2)
	check(menu_fits(), "Home fits 1280 by 720")
	root.size = Vector2i(1600,900)
	await wait_for(.2)
	button("Options").pressed.emit()
	await wait_for(.3)
	check(main.current_menu == "options" and menu_fits(), "Options opens and fits")
	check(main.menu_street.active and paused, "Home options keep live street without starting game")
	await shot("03-options")
	for child in main.menu_content.get_children():
		if child is OptionButton and child.get_item_text(0).begins_with("Camera"):
			child.select(2)
			child.item_selected.emit(2)
	check(main.player.camera_motion == 0.0, "Motion Off option applies")
	button("Back").pressed.emit()
	await wait_for(.15)
	check(main.current_menu == "home", "Options Back returns home")
	button("Play").pressed.emit()
	await wait_for(.5)
	check(main.player.camera.is_current() and main.player.playing and not paused, "Play restores player camera and simulation")
	check(not main.menu_street.active and not main.menu_shade.visible, "Menu overlay and animation end on Play")
	check(not main.get_node("Balcony").visible, "Closed room restores outdoor visibility")
	await shot("04-play-in-room")
	main._show_menu("pause")
	await wait_for(.1)
	button("Options").pressed.emit()
	await wait_for(.1)
	var escape := InputEventAction.new()
	escape.action = "pause"
	escape.pressed = true
	main._unhandled_input(escape)
	check(main.current_menu == "pause" and paused, "Escape from paused Options returns to Pause")
	button("Resume").pressed.emit()
	await wait_for(.1)
	# Real movement, signal delivery and audio output, including Camera motion Off.
	var player: InteriorPlayer = main.player
	player.reset_motion(Vector3(21,-2.85,22))
	player.rotation.y = PI
	player.stepped.connect(func(_surface, _strength): steps += 1)
	await wait_for(.4)
	var room_audio = main.get_node("RoomAudio")
	var walking_peak := await audio_sample(room_audio.footsteps, func(): player.touch_move = Vector2(0,-1), "walking-footsteps", 2.5)
	player.touch_move = Vector2.ZERO
	check(steps >= 3 and walking_peak > -24, "Walking produces audible heel strikes with motion off")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(21,-2.89,4.8)
	player.camera.global_position = Vector3(21,-1.3,4.8)
	player.camera.look_at(Vector3(21,-1.3,12))
	await wait_for(.3)
	enc.fired.clear()
	enc._zone_wait = 0.0
	enc._step_time = -1.0
	enc._event_voice.stop()
	var psst_peak := await audio_sample(enc._whisper_voice, func():
		player.global_position.z = 6.0
		player.camera.global_position.z = 6.0, "psst-at-lane", 1.25)
	check(enc.fired.has(0), "Walking into lane approach automatically triggers psst")
	check(psst_peak > -25, "Psst reaches audible output at the approach")
	check(not enc.trigger_zone(0), "Psst remains once per playthrough")
	enc.set_process(false)
	enc._start_steps()
	var distant_peak := await audio_sample(enc._event_voice, func(): enc._update_steps(.02), "distant-footsteps", .7)
	check(distant_peak > -25 and enc._step_index == 1, "Distant footsteps reach audible output")
	player.camera.look_at(enc._step_origin)
	enc._update_steps(.02)
	check(enc._step_time < 0.0 and not enc._event_voice.playing, "Looking toward footsteps stops the sequence")
	# In-game route screenshots, with normal game lighting and no inserted image backdrop.
	main.ui.hide()
	var gate := main.get_node("Balcony/CourtyardGate")
	gate.snap_open()
	player.camera.global_position = Vector3(11.5,-1.32,4.1)
	player.camera.look_at(Vector3(21,-1.45,4.1))
	await wait_for(1)
	var marker := mark(Vector3(18.0,-1.4,4.1),"Follow the lane to the street")
	await shot("05-leave-white-gate")
	marker.queue_free()
	player.camera.global_position = Vector3(20.8,-1.3,5.1)
	player.camera.look_at(Vector3(22.8,-1.2,11.5))
	await wait_for(.7)
	marker = mark(enc.PSST_SOURCE,"Psst comes from behind this wall")
	await shot("06-psst-location")
	marker.queue_free()
	player.camera.global_position = Vector3(20.45,-2.43,44.1)
	player.camera.look_at(main.menu_street.SLIPPER)
	player.camera.fov = 52
	await wait_for(.5)
	await shot("07-slipper-detail")
	print("SLEEP_REVIEW ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"walking_steps":steps,"walking_peak_db":walking_peak,"psst_peak_db":psst_peak,"distant_peak_db":distant_peak}))
	var report := FileAccess.open(directory.path_join("verification.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"walking_steps":steps,"walking_peak_db":walking_peak,"psst_peak_db":psst_peak,"distant_peak_db":distant_peak},"\t"))
	quit(0 if failures.is_empty() else 1)
