extends SceneTree
## 0.44: photographs of the way from the road bridge to the Old Salmonan gate, the mart's back office and the backstreets.
## `-- --set=<name>` names the output folder work/v44/<name>/; `-- --views=a,b` picks views (default: all).
var main
var session
var player: InteriorPlayer
var m
var args := OS.get_cmdline_user_args()
var out := "approach"
var only: Array = []

func _initialize() -> void: run.call_deferred()

func frames(n: int) -> void:
	for i in n: await physics_frame

## `at` and `aim` are street-local (Street.ORIGIN is added); `at` is where the feet are.
func photo(label: String, at: Vector3, aim: Vector3) -> void:
	if not only.is_empty() and not label in only: return
	var o: Vector3 = m.Street.ORIGIN
	player.reset_motion(o+at)
	player.look_at(Vector3(o.x+aim.x,o.y+at.y,o.z+aim.z))
	player.camera.look_at(o+aim)
	for i in 24:
		m.street.sync(m.flags)
		await process_frame
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://../work/v44/"+out)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_jpg(dir+"/"+label+".jpg",.9)
	print("photo ",label)

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
	await frames(90)
	var G: float = m.Street.APPROACH.G
	if "--bright" in args:
		var sun := DirectionalLight3D.new()
		sun.light_energy = 2.5
		sun.rotation = Vector3(-1.2,.4,0)
		root.add_child(sun)
		await photo("top",Vector3(-4,30,-6),Vector3(-4,-3,-5.9))
	for spot in m.street.find_children("*","SpotLight3D",true,false):
		print("SPOT ",spot.global_position-m.Street.ORIGIN," vis ",spot.is_visible_in_tree()," e ",spot.light_energy," mask ",spot.light_cull_mask)
	await photo("beam",Vector3(9.6,G,-6.2),Vector3(3.6,G+1.5,-.6))
	await photo("aerial",Vector3(-6,9,-21),Vector3(5,-3,-4))
	await photo("yard",Vector3(-6.2,G,-16.0),Vector3(3,-1,-3))
	await photo("checkpoint",Vector3(5.6,G,-12.6),Vector3(9.2,G+.4,-7))
	await photo("ramp_foot",Vector3(11.6,G,-5.2),Vector3(2,-1.2,-1.8))
	await photo("ramp_up",Vector3(9.8,-2.2,-1.8),Vector3(-1,.9,-1.6))
	await photo("landing",Vector3(1.8,0,-2.3),Vector3(0,1.5,1))
	await photo("gate_back",Vector3(.5,0,5),Vector3(0,.2,-8))
	# The back office: shut, opened by Jonna, inside with her sat against the wall.
	m.street.sync(m.flags)
	await photo("office_shut",Vector3(4.0,0,65.8),Vector3(4.3,1.5,69.5))
	m.stage = 6
	m.flags.office = true
	m.jonna.visible = true
	for i in 90:
		m.street.sync(m.flags)
		await physics_frame
	await photo("office_door",Vector3(4.1,0,66.4),Vector3(4.4,1.3,70.0))
	m.jonna.position = m.Street.ORIGIN+m.BackOffice.SEAT
	m.jonna.rotation.y = 0.0
	m.jonna.pose("sit_hurt")
	await photo("office_in",Vector3(6.9,0,70.0),Vector3(2.4,.5,73.0))
	await photo("office_desk",Vector3(4.4,0,70.6),Vector3(6.4,1.0,73.3))
	await photo("office_jonna",Vector3(3.0,0,71.1),Vector3(2.35,.6,72.9))
	await photo("jonna_close",Vector3(2.75,-.5,71.2),Vector3(2.35,.45,72.95))
	await photo("office_shelf",Vector3(6.6,0,71.2),Vector3(8.15,2.0,73.2))
	m.flags.backdoor_open = true
	m.flags.alley = true
	for i in 120:
		m.street.sync(m.flags)
		await physics_frame
	await photo("alley_gate",Vector3(-2.6,0,75.0),Vector3(-2.6,1.6,84))
	await photo("bs0",Vector3(-2,0,84),Vector3(-2,2.2,120))
	await photo("bs0_turn",Vector3(-2,0,128),Vector3(6,2.4,145.5))
	await photo("bs1",Vector3(1,0,145.5),Vector3(40,2.2,145.5))
	await photo("bs1_mouth",Vector3(36,0,145.5),Vector3(52,2.0,145.5))
	await photo("bs2",Vector3(43,0,152),Vector3(43,2.6,200))
	await photo("bs2_cinema",Vector3(45,0,188),Vector3(40.5,3.6,197))
	await photo("bs3",Vector3(43.5,0,236),Vector3(43.5,3.0,268))
	await photo("bs3_parol",Vector3(43.5,0,244),Vector3(45,4.0,253))
	await photo("parol_close",Vector3(43.0,1.0,247.5),Vector3(45.3,4.4,252))
	await photo("bs3_dogleg",Vector3(44,0,268),Vector3(30,2.6,273))
	await photo("bs3_north",Vector3(28.5,0,279),Vector3(28.5,3,310))
	await photo("bs4",Vector3(27.5,0,314),Vector3(27.5,3.2,380))
	await photo("bs4_jeepney",Vector3(30,0,353),Vector3(40,1.6,353))
	await photo("bs5",Vector3(28,0,410),Vector3(28,3.0,470))
	await photo("school",Vector3(28,0,489),Vector3(28,2.6,500))
	# 0.45: the horror pass: a dropped torch, the candles, the torn cable sparking, a smeared wall.
	await photo("h_flash",Vector3(-1.2,0,111.5),Vector3(-3.4,.3,119.0))
	await photo("h_candles",Vector3(-1.5,0,97.5),Vector3(-4.5,.4,101.0))
	await photo("h_spark",Vector3(28.5,0,337.5),Vector3(26.4,1.0,344.5))
	await photo("h_arcade_dark",Vector3(43,0,170),Vector3(43,1.8,215))
	main.story.flashlight.set_on(true)
	await photo("lit_bs0",Vector3(-2,0,100),Vector3(-2.6,-.4,108))
	await photo("lit_flash",Vector3(-1.2,0,111.5),Vector3(-3.4,-.2,118.0))
	await photo("lit_bs4",Vector3(27.5,0,320),Vector3(27.0,-.3,328))
	await photo("lit_bs5",Vector3(28,0,415),Vector3(28.5,-.2,423))
	print("INTERIOR_APPROACH_REVIEW {\"passed\":true}")
	quit(0)
