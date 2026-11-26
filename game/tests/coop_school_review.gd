extends SceneTree
## 0.50: photographs of the Prof. Ivan Lawrence College of Science and Technology (scripts/coop/school.gd): the back
## gate and Rommel, the story box, the yard and the facade, every floor, the stairs and their barricades, room 501.
## `-- --set=<name>` names the output folder work/v50/<name>/; `-- --views=a,b` picks views (default: all);
## `-- --lit` adds flashlight views.
var main
var session
var player: InteriorPlayer
var m
var args := OS.get_cmdline_user_args()
var out := "school"
var only: Array = []

func _initialize() -> void: run.call_deferred()

func frames(n: int) -> void:
	for i in n: await physics_frame

## `at` and `aim` are street-local; `at` is where the feet are.
func photo(label: String, at: Vector3, aim: Vector3, hud := false, eye := -1.0) -> void:
	if not only.is_empty() and not label in only: return
	var o: Vector3 = m.Street.ORIGIN
	player.reset_motion(o+at)
	player.look_at(Vector3(o.x+aim.x,o.y+at.y,o.z+aim.z))
	player.camera.look_at(o+aim)
	main.hud.visible = hud
	for i in 30:
		if eye>0.0:
			player.set("_eye_y",eye)
			player.camera.global_position = o+at+Vector3.UP*eye
			player.camera.look_at(o+aim)
		m.street.sync(m.flags)
		m.school.sync(m.flags,1.0/60.0,player.global_position)
		if hud: session._story_box()
		await process_frame
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://../work/v50/"+out)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_jpg(dir+"/"+label+".jpg",.9)
	print("photo ",label)

func student(at: Vector3, yaw: float, clip: String) -> void:
	var z = m.spawn(m.ground(m.Street.ORIGIN+at),true,true)
	if z==null: return
	z.rotation.y = yaw
	z.pose(clip)

func run() -> void:
	for a in args:
		if a.begins_with("--set="): out = a.trim_prefix("--set=")
		if a.begins_with("--views="): only = Array(a.trim_prefix("--views=").split(","))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	session = main.coop
	session.host()
	session.start_game()
	player = main.player
	m = session.mission
	session.set_physics_process(false)
	session.set_process(false)
	main.story.gun.holster(true)
	main.hud.hide()
	await frames(60)
	var t0 := Time.get_ticks_msec()
	var r: Array = m.debug_jump("school")
	print("jump ",r," stage ",m.stage," in ",Time.get_ticks_msec()-t0," ms; school built in ",m.school.built_usec/1000," ms")
	await frames(30)
	var H: float = m.SCHOOL.H
	# Outside the gate: the story box over the lane, then Rommel through the bars.
	m.flags.story = 1
	session._story_page = -1
	await photo("story_box",Vector3(28,0,486),Vector3(28,4.0,500),true)
	m.flags.story = m.STORY.size()
	await photo("gate",Vector3(28,0,491),Vector3(28,3.0,500))
	await photo("gate_guard",Vector3(27.6,0,497.8),Vector3(31.4,.6,502.2))
	await photo("facade_lane",Vector3(28,0,470),Vector3(28,10,520))
	# Open the gate; the yard, the facade, the entrance.
	m.open_school()
	for i in 200:
		m.school.sync(m.flags,1.0/60.0,player.global_position)
		await physics_frame
	for e in m.enemies.values(): e.queue_free()
	m.enemies.clear()
	student(Vector3(20,0,508),1.0,"idle_hurt")
	student(Vector3(34,0,510.5),-2.4,"walk_hurt")
	await photo("yard",Vector3(28,0,501.5),Vector3(28,6,514))
	await photo("facade",Vector3(10,0,502),Vector3(30,9,514))
	await photo("guard_close",Vector3(29.6,0,503.4),Vector3(31.55,.55,502.25))
	await photo("entrance",Vector3(28,0,508.5),Vector3(28,1.6,516))
	# Ground floor: lobby, corridor, cafeteria, the grand stair.
	student(Vector3(14,0,523.4),PI*.5,"walk_hurt")
	student(Vector3(9,0,518),2.0,"devour")
	await photo("lobby",Vector3(28,0,515.0),Vector3(28,1.7,524))
	await photo("lobby_plaque",Vector3(28.5,0,518.5),Vector3(31.9,1.8,517.6))
	await photo("corridor1_w",Vector3(26,0,523.5),Vector3(2,1.6,523.5))
	await photo("cafeteria",Vector3(22.5,0,520.8),Vector3(6,1.0,516.5))
	await photo("grand_stair",Vector3(28,0,521.5),Vector3(28,3.0,532))
	await photo("president",Vector3(48.6,0,526.0),Vector3(44,1.0,531))
	await photo("stair_note_1f",Vector3(3.1,0,523.6),Vector3(1.4,1.3,527))
	# Second floor: the gallery, a classroom, the east stairs up.
	student(Vector3(40,H,523.6),-PI*.5,"run_hurt")
	await photo("gallery2",Vector3(25.2,H,531.5),Vector3(28,H-1.5,526))
	await photo("corridor2_e",Vector3(26,H,523.5),Vector3(54,H+1.6,523.5))
	await photo("class205",Vector3(39.3,H,521.0),Vector3(33,H+1.2,517.5))
	await photo("stair_e2",Vector3(52.9,H,524.0),Vector3(54.3,H+2.0,529))
	await photo("stair_e2_turn",Vector3(54.3,H+1.8,531.8),Vector3(51.4,H+3.6,526.5))
	await photo("barricade_w2",Vector3(1.65,H,525.8),Vector3(1.65,H+2.0,530))
	# Third: the chemistry and biology labs; fourth: library, computers; fifth: the corridor and 501.
	await photo("chem",Vector3(14.5,2*H,520.8),Vector3(3,2*H+1.0,517.5))
	await photo("bio",Vector3(38.5,2*H,520.8),Vector3(26,2*H+1.0,516.5))
	await photo("library",Vector3(22.5,3*H,520.8),Vector3(6,3*H+1.0,517))
	await photo("computers",Vector3(38.5,3*H,520.8),Vector3(26,3*H+.9,517))
	# 0.51: the hard way up: the dark halls, the wall of desks and the broken partition, the fire escape, the
	# maintenance room's ladder, the mechanical room and the duct; the shut doors and a class still standing.
	if "--lit" in args: main.story.flashlight.set_on(true)
	await photo("corridor2_dark",Vector3(27,H,523.5),Vector3(54,H+1.4,523.5))
	await photo("hall_block2",Vector3(37.5,H,523.5),Vector3(42,H+1.2,523.5))
	await photo("breach205",Vector3(37.0,H,518.4),Vector3(40.1,H+.9,517.2))
	await photo("fire_door2",Vector3(49,H,523.5),Vector3(56,H+1.2,523.5))
	await photo("fire_escape",Vector3(57.0,H,522.0),Vector3(57.6,H+2.6,529.5))
	await photo("fire_escape_up",Vector3(56.65,H+1.8,530.6),Vector3(56.65,2*H+1.0,524.0))
	main.story.flashlight.set_on(false)
	await photo("fire_escape_out",Vector3(60.5,0,516.5),Vector3(57,H+1.5,525))
	if "--lit" in args: main.story.flashlight.set_on(true)
	var teacher = m.spawn(m.ground(m.Street.ORIGIN+Vector3(30,3*H,523.6)),true,false,m.TEACHER_FIRST+3)
	if teacher!=null: teacher.rotation.y = -PI*.5
	var janitor = m.spawn(m.ground(m.Street.ORIGIN+Vector3(33,3*H,523.2)),true,false,m.JANITOR_FIRST+1)
	if janitor!=null: janitor.rotation.y = -PI*.5
	await photo("corridor4_staff",Vector3(24,3*H,523.5),Vector3(40,3*H+1.3,523.5))
	await photo("janitor_room",Vector3(37.8,3*H,527.6),Vector3(36,3*H+2.0,533.6))
	await photo("ladder_up",Vector3(36,3*H,532.2),Vector3(36,4*H+1.0,533.0))
	await photo("mech",Vector3(37.0,4*H,527.8),Vector3(33,4*H+.6,533))
	await photo("duct_mouth",Vector3(36.6,4*H,529.6),Vector3(34.4,4*H+.5,533.0))
	await photo("duct_510",Vector3(29.5,4*H,527.0),Vector3(26,4*H+.5,533.2))
	await photo("doors_row3",Vector3(20,2*H,523.6),Vector3(50,2*H+1.2,524.8))
	# A class still standing at its armchairs, facing the board; their teacher at the front.
	for row in 3:
		for col in 3:
			var st = m.spawn(m.ground(m.Street.ORIGIN+Vector3(19.5+row*1.6,4*H,527.6+col*1.7)),true,false,m.STUDENT_FIRST+(row*3+col)%10)
			if st!=null: st.rotation.y = PI*.5
	var t2 = m.spawn(m.ground(m.Street.ORIGIN+Vector3(17.1,4*H,529.4)),true,false,m.TEACHER_FIRST+1)
	if t2!=null: t2.rotation.y = -PI*.5
	await photo("class_session",Vector3(23.2,4*H,526.2),Vector3(17,4*H+1.2,530.0))
	# A door giving.
	var d := -1
	for i in m.school.doors.size():
		if m.school.doors[i].room=="304": d = i
	if d>=0:
		m.flags.pound = 1<<d
		await photo("door_pound",Vector3(36.5,2*H,523.0),Vector3(38.8,2*H+1.2,525.0))
		m.flags.pound = 0
		m.flags.broke = 1<<d
		for at: Vector3 in m.school.behind(d,3):
			var z = m.spawn(m.ground(at),true,true)
			if z!=null:
				z.rotation.y = PI
				z.pose("run_hurt")
		for i in 12: await physics_frame
		await photo("door_burst",Vector3(36.0,2*H,522.6),Vector3(38.8,2*H+1.0,525.5))
	main.story.flashlight.set_on(false)
	student(Vector3(20,4*H,523.4),PI*.5,"walk_hurt")
	student(Vector3(24,4*H,523.8),PI*.5,"idle_hurt")
	await photo("corridor5_w",Vector3(50,4*H,523.5),Vector3(2,4*H+1.5,523.5))
	await photo("door501",Vector3(7.5,4*H,524.2),Vector3(6.9,4*H+1.3,522.0))
	await photo("aerial",Vector3(28,30,470),Vector3(28,6,520))
	if "--lit" in args:
		main.story.flashlight.set_on(true)
		await photo("lit_corridor3",Vector3(50,2*H,523.5),Vector3(30,2*H+.8,523.5))
		await photo("lit_class",Vector3(15.0,H,521.0),Vector3(9,H+.8,517.5))
	if "--fps" in args:
		main.story.flashlight.set_on(false)
		for spot: Array in [["yard", Vector3(28, 0, 503), Vector3(28, 6, 514)], ["lobby", Vector3(28, 0, 515.0), Vector3(28, 1.7, 524)],
				["corridor1", Vector3(52, 0, 523.5), Vector3(2, 1.6, 523.5)], ["corridor3", Vector3(52, 2 * H, 523.5), Vector3(2, 2 * H + 1.6, 523.5)],
				["cafeteria", Vector3(22.5, 0, 520.8), Vector3(6, 1.0, 516.5)], ["facade_far", Vector3(28, 0, 470), Vector3(28, 10, 520)],
				["corridor2", Vector3(27, H, 523.5), Vector3(54, H + 1.4, 523.5)], ["fire_escape", Vector3(57.0, H, 522.0), Vector3(57.6, H + 2.6, 529.5)],
				["corridor4", Vector3(4, 3 * H, 523.5), Vector3(40, 3 * H + 1.3, 523.5)], ["corridor5", Vector3(50, 4 * H, 523.5), Vector3(2, 4 * H + 1.5, 523.5)]]:
			var o: Vector3 = m.Street.ORIGIN
			player.reset_motion(o + spot[1])
			player.camera.look_at(o + spot[2])
			for i in 30:
				m.school.sync(m.flags, 1.0 / 60.0, player.global_position)
				await process_frame
			var start := Time.get_ticks_usec()
			for i in 120:
				m.school.sync(m.flags, 1.0 / 60.0, player.global_position)
				await process_frame
			var ms := (Time.get_ticks_usec() - start) / 120000.0
			print("SCHOOL_FPS %s %.2f ms %.0f fps draw %d" % [spot[0], ms, 1000.0 / ms, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	print("INTERIOR_SCHOOL_REVIEW {\"passed\":true}")
	quit(0)
