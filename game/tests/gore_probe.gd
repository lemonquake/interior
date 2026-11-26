extends SceneTree
## 0.29 probe (not a test): how the hinges bend, how a body falls, what a part does when it comes off.
##   godot --headless --path game --script res://tests/gore_probe.gd --fixed-fps 60

const EYE := Vector3(20.6, -1.32, 30.0)

var main: Node
var zombies: InteriorZombies
var player: InteriorPlayer

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

## The angle a hinge is closed by, signed: positive the way it should bend.
func _bend(zombie: InteriorZombie, upper: String, lower: String, forward_sign: float) -> float:
	var a := zombie._bodies[upper] as PhysicalBone3D
	var b := zombie._bodies[lower] as PhysicalBone3D
	var a_dir := -(a.global_basis * (a.body_offset.basis.inverse() * Vector3(0, 0, 1))).normalized()
	var b_dir := -(b.global_basis * (b.body_offset.basis.inverse() * Vector3(0, 0, 1))).normalized()
	var ahead := -zombie.global_basis.z
	var angle := rad_to_deg(a_dir.angle_to(b_dir))
	# Which way the lower part has gone relative to the upper: ahead of it or behind.
	var side := signf((b_dir - a_dir * b_dir.dot(a_dir)).dot(ahead))
	return angle * side * forward_sign

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(6)
	player = main.player
	zombies = main.zombies
	zombies.passive = true
	zombies.invulnerable = true
	var man := main.get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
	player.reset_motion(EYE - Vector3(0, InteriorPlayer.STANDING_EYE, 0))
	await _frames(4)
	var spot := Vector3.INF
	for far: float in [5.0, 4.0, 6.0, 3.0, 7.0]:
		spot = zombies.ground(EYE + (Vector3(23.6, -1.5, 36.0) - EYE).normalized() * far, false)
		if spot.is_finite():
			break
	if not spot.is_finite():
		print("no spot")
		quit()
		return
	print("spot ", spot)
	# ---- hinges: force each one half closed and see which way the lower part went
	var z0 := zombies.spawn(spot, "tambay", 0.0)
	await _frames(20)
	for bone: String in ["shin.L", "shin.R", "forearm.L", "forearm.R"]:
		var body := z0._bodies[bone] as PhysicalBone3D
		body.set("joint_constraints/angular_limit_lower", 70.0)
		body.set("joint_constraints/angular_limit_upper", 110.0)
	z0._ragdoll([], Vector3.ZERO)
	for f in 40:
		for bone: String in ["hips", "spine", "chest", "thigh.L", "thigh.R", "upper_arm.L", "upper_arm.R"]:
			var body := z0._bodies[bone] as PhysicalBone3D
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
		await physics_frame
	var ahead0 := -z0.global_basis.z
	for pair: Array in [["thigh.L", "shin.L"], ["thigh.R", "shin.R"], ["upper_arm.L", "forearm.L"], ["upper_arm.R", "forearm.R"]]:
		var a0 := z0._bodies[pair[0]] as PhysicalBone3D
		var b0 := z0._bodies[pair[1]] as PhysicalBone3D
		var a_dir := (a0.global_basis * Vector3(0, 0, -1)).normalized()
		var b_dir := (b0.global_basis * Vector3(0, 0, -1)).normalized()
		print("HINGE ", pair[1], " closed ", snappedf(rad_to_deg(a_dir.angle_to(b_dir)), .1), " deg; lower part went ", "AHEAD" if (b_dir - a_dir * b_dir.dot(a_dir)).dot(ahead0) > 0.0 else "BEHIND",
			" (upper points ", a_dir.snapped(Vector3.ONE * .01), ", lower ", b_dir.snapped(Vector3.ONE * .01), ", ahead ", ahead0.snapped(Vector3.ONE * .01), ")")
	zombies.clear()
	await _frames(3)
	# ---- a death: how long until it lies still, how far it went, how fast its parts turned
	for load: Array in [["head shot", "head", 60.0, 34.0], ["buckshot", "chest", 765.0, 170.0]]:
		var z := zombies.spawn(spot, "kuya", 0.0)
		await _frames(30)
		var body := z._bodies[load[1]] as PhysicalBone3D
		var from := z.global_position
		if str(load[0]) == "buckshot":
			for k in 9:
				z.shot(body, body.global_position, -z.global_basis.z * -1.0, 19.0, 85.0, "shotgun", 25.0)
		else:
			z.shot(body, body.global_position, z.global_basis.z, float(load[3]), float(load[2]), "pistol", 10.0)
		var spin := 0.0
		var still := -1
		for f in 240:
			await physics_frame
			if not z.ragdolled:
				continue
			for part: PhysicalBone3D in z._bodies.values():
				spin = maxf(spin, part.angular_velocity.length())
			var hips := z._bodies["hips"] as PhysicalBone3D
			if still < 0 and f > 20 and hips.linear_velocity.length() < .05:
				still = f
		print("DEATH ", load[0], ": state ", InteriorZombie.State.keys()[z.state], " moved ", snappedf(z.where().distance_to(from), .01), " m, hips y ",
			snappedf(z.where().y - from.y, .01), ", still after ", still, " frames, fastest turn ", snappedf(spin, .1), " rad/s, severed ", z.severed.keys())
		zombies.clear()
		await _frames(3)
	# ---- parts coming off
	var z := zombies.spawn(spot, "nanay", 0.0)
	await _frames(30)
	var arm := z._bodies["forearm.L"] as PhysicalBone3D
	z.shot(arm, arm.global_position, z.global_basis.z, 46.0, 95.0, "rifle", 32.0)
	z.shot(arm, arm.global_position, z.global_basis.z, 46.0, 95.0, "rifle", 32.0)
	await _frames(30)
	print("ARM severed ", z.severed.keys(), " state ", InteriorZombie.State.keys()[z.state], " health ", snappedf(z.health, .1), " parts ", zombies.blood.parts(),
		" bleeders ", zombies.blood.bleeders(), " flying ", zombies.blood.flying(), " spots ", zombies.blood.spots())
	var leg := z._bodies["shin.R"] as PhysicalBone3D
	z.shot(leg, leg.global_position, z.global_basis.z, 160.0, 300.0, "sniper", 270.0)
	await _frames(240)
	print("after the leg: state ", InteriorZombie.State.keys()[z.state], " health ", snappedf(z.health, .1))
	var before := z.where()
	zombies.passive = false
	player.reset_motion(spot + Vector3(-6.0, 0, 0))
	await _frames(360)
	print("LEG severed ", z.severed.keys(), " state ", InteriorZombie.State.keys()[z.state], " health ", snappedf(z.health, .1), " crawled ",
		snappedf(z.where().distance_to(before), .01), " m in 6 s, spots ", zombies.blood.spots(), " parts ", zombies.blood.parts())
	zombies.passive = true
	var head := z._bodies.get("head") as PhysicalBone3D
	if head != null:
		for k in 6:
			z.shot(head, head.global_position, Vector3.DOWN, 19.0, 85.0, "shotgun", 25.0)
		await _frames(60)
		print("HEAD severed ", z.severed.keys(), " state ", InteriorZombie.State.keys()[z.state], " parts ", zombies.blood.parts(), " decals ", zombies.blood.count(), " spots ", zombies.blood.spots())
	quit()
