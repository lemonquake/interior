extends SceneTree
## 0.68 debug probe: jump to a hospital place and print the mission's state for a while.
##   godot --headless --path game --script res://tests/hospital_probe.gd -- --place=hosplobby
var game
var session
var m

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	var place := "hospital"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--place="): place = a.trim_prefix("--place=")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.add_bot()
	session.start_game()
	await frames(30)
	m = session.mission
	session.harmless = true
	print("PROBE > ", m.debug_command(1, "jump " + place))
	for a2 in OS.get_cmdline_user_args():
		if a2.begins_with("--tp="):
			await frames(200)
			var v := a2.trim_prefix("--tp=").split(",")
			var hh = m.hospital
			var to: Vector3 = hh.world(hh.HO + Vector3(float(v[0]), float(v[1]), float(v[2])))
			print("PROBE tp to ", to, " before ", game.player.global_position)
			session.debug_teleport(to, PI)
			await frames(5)
			print("PROBE tp after ", game.player.global_position)
	for i in 12:
		await frames(60 if i > 0 else 2)
		if m.hospital != null:
			var hh = m.hospital
			var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
			var from: Vector3 = hh.world(hh.HO + Vector3(-12, 6.0, 23.3))
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20.0, 2))
			print("PROBE ray ", hit.get("collider"), " at ", (hh.local(hit.get("position", Vector3.ZERO)) - hh.HO).snapped(Vector3.ONE * .01) if not hit.is_empty() else "none",
				" body F2 can_process ", hh.bodies[hh.R_F2].can_process(), " street can_process ", m.street.can_process(), " hosp can_process ", hh.can_process(), " inside_tree ", hh.bodies[hh.R_F2].is_inside_tree())
		var hp = m.hospital
		var l: Vector3 = (hp.local(game.player.global_position) - hp.HO) if hp != null else Vector3.ZERO
		var keys: Array = []
		for k in m.flags.keys():
			if str(k).begins_with("hosp") or str(k) in ["lab_open", "bridge_out", "board", "lucky_out"]: keys.append("%s=%s" % [k, str(m.flags[k]).left(20)])
		print("PROBE t%d stage %d text '%s' here %s cand '%s' gone %s screen %s flags %s" % [i, m.stage, m.text_line.left(30).replace("\n", "|"), str(l.snapped(Vector3.ONE * .1)), m.candidate(1), str(hp.gone) if hp != null else "-", str(session._chapter_screen != null and session._chapter_screen.visible), str(keys)])
	quit(0)
