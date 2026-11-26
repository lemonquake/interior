extends SceneTree
## 0.66: eye-level photographs along the squad's way, chapter by chapter (rendered, the game's own night and grade),
## for judging the pathways and the empty or bland stretches.
##   godot --path game --script res://tests/route_views.gd -- --set=<name> [--jump=<place>] [--views=a,b]
## Views are [name, eye (world), aim (world)] in VIEWS[set]; saved to work/v66/views/<set>/<name>.jpg.
var main
var s
var m
var args := OS.get_cmdline_user_args()
const VIEWS := {
	"start": [
		["a_gate_east", Vector3(14.6, -1.25, 4.6), Vector3(40.0, -1.6, 4.0)],
		["b_gate_north", Vector3(14.6, -1.25, 4.6), Vector3(14.0, -1.6, -25.0)],
		["c_lane_south", Vector3(18.6, -1.25, 6.0), Vector3(18.6, -1.6, 30.0)],
		["d_junction_west", Vector3(18.6, -1.25, 15.8), Vector3(-15.0, -1.6, 16.5)],
		["e_junction_east", Vector3(18.6, -1.25, 15.8), Vector3(55.0, -1.6, 15.8)],
		["f_junction_south", Vector3(18.6, -1.25, 15.8), Vector3(18.6, -1.6, 50.0)],
		["g_road_lots_south", Vector3(5.0, -1.25, 16.5), Vector3(5.0, -1.8, 40.0)],
		["h_road_lots_north", Vector3(5.0, -1.25, 16.5), Vector3(5.0, -1.8, -10.0)],
		["i_road_far_west", Vector3(-15.0, -1.25, 17.4), Vector3(-45.0, -1.6, 19.0)],
		["j_bridge_south", Vector3(-38.0, -1.25, 18.2), Vector3(-40.0, -2.0, 50.0)],
		["k_bridge_north", Vector3(-38.0, -1.25, 18.2), Vector3(-40.0, -2.0, -10.0)],
		["l_bank_lane", Vector3(-51.4, -.45, 24.0), Vector3(-51.3, -.7, 45.0)],
	],
	"ch1": [
		["01_gate_dodong", Vector3(11.2, -1.25, 4.1), Vector3(14.4, -1.3, 4.4)],
		["02_lane_south", Vector3(18.9, -1.2, 7.0), Vector3(18.3, -1.6, 16.0)],
		["03_road_west", Vector3(12.0, -1.2, 16.5), Vector3(-20.0, -1.6, 17.5)],
		["04_road_mid", Vector3(-8.0, -1.2, 17.1), Vector3(-40.0, -1.4, 19.0)],
		["05_bridge", Vector3(-32.0, -1.2, 18.6), Vector3(-52.0, -1.0, 20.5)],
		["06_bank_lane", Vector3(-51.4, -.45, 22.0), Vector3(-51.3, -.7, 40.0)],
		["07_bank_north", Vector3(-51.6, -.45, 45.0), Vector3(-53.0, -.7, 59.0)],
		["08_plank_bridge", Vector3(-55.0, -.45, 59.6), Vector3(-80.0, -.6, 58.6)],
		["09_far_bank", Vector3(-80.6, -.45, 56.0), Vector3(-76.5, -.7, 40.0)],
		["10_dip", Vector3(-75.6, -.9, 36.0), Vector3(-74.4, -2.4, 24.0)],
		["11_dip_south", Vector3(-74.3, -2.3, 26.0), Vector3(-75.4, -2.4, 13.0)],
		["12_warren_in", Vector3(-75.8, -1.6, 12.3), Vector3(-79.5, -.9, 8.0)],
		["13_back_east", Vector3(-32.0, -1.2, 18.6), Vector3(10.0, -1.4, 16.5)],
		["14_town_north", Vector3(18.6, -1.2, 15.3), Vector3(18.6, -1.4, 50.0)],
		["15_town_east", Vector3(18.6, -1.2, 15.3), Vector3(60.0, -1.4, 16.0)],
	],
}

func _initialize() -> void: run.call_deferred()

func frames(n: int) -> void:
	for i in n: await physics_frame

func photo(dir: String, label: String, eye: Vector3, aim: Vector3) -> void:
	var player: InteriorPlayer = main.player
	player.reset_motion(eye - Vector3.UP * 1.62)
	player.look_at(Vector3(aim.x, eye.y - 1.62, aim.z))
	player.camera.look_at(aim)
	s.team[1].pos = eye - Vector3.UP * 1.62
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(dir + "/" + label + ".jpg", .88)
	print("VIEW ", label)

func run() -> void:
	var set := "ch1"
	var only: Array = []
	var jump := ""
	for a in args:
		if a.begins_with("--set="): set = a.trim_prefix("--set=")
		if a.begins_with("--views="): only = Array(a.trim_prefix("--views=").split(","))
		if a.begins_with("--jump="): jump = a.trim_prefix("--jump=")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	main.capturing = true
	s = main.coop
	s.host()
	s.start_game()
	m = s.mission
	s.harmless = true
	m.harmless = true
	m.next_spawn = 99999.0
	if jump != "": print("VIEWS > ", m.debug_command(1, "jump " + jump))
	await frames(60)
	main.hud.hide()
	main.story.gun.holster(true)
	if "--lit" in args:
		var sun := DirectionalLight3D.new()
		sun.light_energy = 1.6
		sun.rotation = Vector3(-.9, .6, 0)
		root.add_child(sun)
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(.55, .62, .72)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(.8, .8, .8)
		e.ambient_light_energy = .9
		for w in main.find_children("*", "WorldEnvironment", true, false): (w as WorldEnvironment).environment = e
	s.set_physics_process(false)
	var dir := ProjectSettings.globalize_path("res://../work/v66/views/" + set)
	DirAccess.make_dir_recursive_absolute(dir)
	for v: Array in VIEWS.get(set, []):
		if not only.is_empty() and not v[0] in only: continue
		await photo(dir, v[0], v[1], v[2])
	print("VIEWS done ", dir)
	quit()
