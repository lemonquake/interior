extends SceneTree
## 0.57 diagnostic: where the fifth floor's horde (escape.gd, stage 12) gets to, and what stands next to those that
## stop short. Prints INTERIOR_HORDE_TRACE lines.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	var session = game.coop
	session.host()
	var sd := 57
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): sd = int(a.trim_prefix("--seed="))
	seed(sd)
	session.start_game()
	for i in 8: await physics_frame
	var m = session.mission
	session.harmless = true
	var r: Array = m.debug_jump("horde")
	game.player.reset_motion(r[0])
	var o: Vector3 = m.Street.ORIGIN
	var props = m.school.props
	for t in 75:
		for i in 60: await physics_frame
		if m.escape == null: continue
		for z in m.escape.horde:
			if is_instance_valid(z) and z.march_pace < 3.0:
				z.march_pace = 3.2
				z.stun = minf(z.stun, .4)
		var line := []
		for z in m.escape.horde:
			if not is_instance_valid(z) or z.dead: continue
			var p: Vector3 = z.position - o
			var near := ""
			if z.idle_mode == "march":
				var best := 9.0
				for j in props.props.size():
					var b: RigidBody3D = props.props[j].body
					if b == null: continue
					var dd := b.global_position.distance_to(z.position)
					if dd < best:
						best = dd
						near = "%s%d@%.1f%s" % [props.props[j].kind, j, dd, "z" if b.sleeping else ""]
				line.append("x%.1f z%.1f %s s%.1f %s" % [p.x, p.z, z.idle_mode, z.stalled, near])
		if t >= 70: print("INTERIOR_HORDE_TRACE t=%d stage %d horde=%d marching: %s" % [t + 1, m.stage, m.escape.horde.size(), line])
	for z in m.escape.horde:
		if not is_instance_valid(z) or z.idle_mode != "march": continue
		var hits := []
		for c in z.get_slide_collision_count():
			var sc: KinematicCollision3D = z.get_slide_collision(c)
			hits.append("%s n%s h%.2f" % [sc.get_collider().name if sc.get_collider() else "?", sc.get_normal().snapped(Vector3.ONE * .1), sc.get_position().y - z.global_position.y])
		print("INTERIOR_HORDE_TRACE stuck at %s march %d/%d next %s vel %s touching %s" % [(z.position - o).snapped(Vector3.ONE * .1), z.march_i, z.march.size(), (z.march[mini(z.march_i, z.march.size() - 1)] - o).snapped(Vector3.ONE * .1), z.velocity.snapped(Vector3.ONE * .1), hits])
		for j in props.props.size():
			var b: RigidBody3D = props.props[j].body
			if b != null and b.global_position.distance_to(z.position) < 1.2:
				print("INTERIOR_HORDE_TRACE   prop %s%d at %s up %.2f asleep %s" % [props.props[j].kind, j, (b.global_position - o).snapped(Vector3.ONE * .01), b.global_basis.y.y, b.sleeping])
		break
	quit()
