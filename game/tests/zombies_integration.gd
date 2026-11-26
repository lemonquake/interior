extends SceneTree
## 0.28: the automatic rifle, the shotgun, ballistics, the infected, their ragdolls and the blood, headless:
##   godot --headless --path game --script res://tests/zombies_integration.gd --fixed-fps 60
## The rifle keeps firing while the trigger is held, about ten rounds a second, and stops when it is let go; in
## single shots a held trigger fires nothing more; a string scatters both across and up and down. The shotgun
## throws nine pellets in a pattern and must be pumped between shots. Rounds drop and lose energy with distance,
## each by its own figures. An infected has twelve hit boxes that follow its animation; a chest hit wounds, bleeds
## and pushes it; a head shot kills and leaves a ragdoll on the ground with a pool; a knock-down gets up again; a
## shotgun blast at arm's length throws the body. Calm ones wander; one that sees the player comes and claws; the
## debug menu's buttons spawn, kill and clear them. No errors in the log.
## 0.29: a round no longer throws anybody: a pistol hit leaves it on its feet, buckshot close up knocks it down a
## step or two away. A wound goes on bleeding and drops fall from it. Parts come off: the rifle takes a forearm in
## two rounds (the arm lies there, the figure fights on with one), the sniper's round takes a leg in one (it cannot
## stand, and crawls after the player), buckshot takes a head apart. The sniper rifle: five and one, the bolt worked
## between shots, the scope at 8x narrowing the lens and slowing the mouse, the wheel turning it down and up.

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])
	func _log_message(message: String, error: bool) -> void:
		pass

const EYE := Vector3(20.6, -1.32, 30.0)
const AT := Vector3(23.6, -1.5, 36.0)

var checks := 0
var failures: Array[String] = []
var main: Node
var player: InteriorPlayer
var story: InteriorStory
var gun: InteriorGun
var zombies: InteriorZombies
var menu: InteriorDebugMenu
var catcher := ErrorCatcher.new()
var shots := 0
var directions: Array[Vector3] = []

func _initialize() -> void:
	OS.add_logger(catcher)
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL " + message)
	print(("PASS " if condition else "FAIL ") + message)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _seconds(s: float) -> void:
	await _frames(int(ceil(s * 60.0)))

func _look(eye: Vector3, at: Vector3) -> void:
	player.reset_motion(eye - Vector3(0, InteriorPlayer.STANDING_EYE, 0))
	await _frames(4)
	_aim(at)
	await _frames(2)

func _aim(at: Vector3) -> void:
	var to := at - player.camera.global_position
	player.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
	player.set("_look_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
	player.recoil = 0.0
	player.aim_offset = Vector2.ZERO
	player.camera.rotation.x = player.get("_look_pitch")

func _on_fired() -> void:
	shots += 1
	directions.append(gun.last_shot_direction)

func _ahead() -> Vector3:
	var ahead := AT - EYE
	ahead.y = 0.0
	return ahead.normalized()

func _spawn(distance: float, variant := "", kind := "runner") -> InteriorZombie:
	var ahead := _ahead()
	for extra: float in [0.0, .8, -.8, 1.6, 2.4]:
		var spot := zombies.ground(EYE + ahead * (distance + extra), false)
		if spot.is_finite():
			return zombies.spawn(spot, variant, atan2(ahead.x, ahead.z), false, kind)
	return null

## A round delivered by hand: `sever` of load into `bone`, from the front.
func _strike(zombie: InteriorZombie, bone: String, damage: float, sever: float) -> void:
	var body := _body(zombie, bone)
	zombie.shot(body, body.global_position - _ahead() * .05, _ahead(), damage, 40.0, "rifle", sever)

## 0.38: a point on `bone` that both the lens and the bore (0.37: rounds leave from the breech, under the lens)
## reach before any other part, aimed at; INF when none does. A hand in front of the forearm, or a head hung over
## the chest, would otherwise take the round now and then.
func _aim_clear(zombie: InteriorZombie, bone: String) -> Vector3:
	var body := _body(zombie, bone)
	var space := player.get_world_3d().direct_space_state
	for offset: Vector3 in [Vector3.ZERO, Vector3(0, .05, 0), Vector3(0, -.05, 0), Vector3(.05, 0, 0), Vector3(-.05, 0, 0),
			Vector3(0, .1, 0), Vector3(0, -.1, 0), Vector3(.04, .08, 0), Vector3(-.04, -.08, 0)]:
		var spot := body.global_position + body.global_basis * offset
		_aim(spot)
		var clear := true
		for from: Vector3 in [player.camera.global_position, gun.breech_world()]:
			var probe := PhysicsRayQueryParameters3D.create(from, spot + (spot - from).normalized() * .05, 16)
			var first := space.intersect_ray(probe)
			if first.is_empty() or first.collider != body:
				clear = false
				break
		if clear:
			return spot
	_aim(body.global_position)
	return Vector3.INF

func _body(zombie: InteriorZombie, bone: String) -> PhysicalBone3D:
	return zombie._bodies[bone] as PhysicalBone3D

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(6)
	player = main.player
	story = main.story
	zombies = main.zombies
	# 0.33: these checks are about the infected in the light (tests/senses_integration.gd has the dark).
	main.senses.daylight = true
	menu = main.get_node_or_null("DebugMenu") as InteriorDebugMenu
	check(story != null and story.gun != null and zombies != null and menu != null, "The scene has the gun, the infected's director and the debug menu")
	if story == null or zombies == null or menu == null:
		_finish()
		return
	var man := main.get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
	gun = story.gun
	gun.fired.connect(_on_fired)
	zombies.passive = true
	await _look(EYE, AT + Vector3(0, 6.0, 0))

	# ---- the debug menu's rifle, with its ammunition
	menu._summon_rifle()
	await _seconds(1.2)
	check(gun.rifle_owned and gun.drawn and gun.weapon == "rifle", "Summon AR-15 puts the rifle in the hands")
	check(gun.loaded() == 30 and gun.reserve == 300, "It comes loaded with 300 rounds more (%d + %d)" % [gun.loaded(), gun.reserve])
	check(gun.fires_automatic(), "Its selector is on automatic")

	# ---- automatic fire: the trigger held
	shots = 0
	directions.clear()
	Input.action_press("fire")
	await _seconds(1.0)
	Input.action_release("fire")
	var held := shots
	await _seconds(.4)
	check(held >= 9 and held <= 11, "A second with the trigger held fires about ten rounds (%d)" % held)
	check(shots == held, "Letting go stops it (%d after)" % (shots - held))
	check(gun.loaded() == 30 - held, "Every round came out of the magazine (%d left)" % gun.loaded())
	var yaw: Array[float] = []
	var pitch: Array[float] = []
	for d in directions:
		yaw.append(atan2(d.x, d.z))
		pitch.append(asin(clampf(d.y, -1.0, 1.0)))
	var yaw_range: float = (float(yaw.max()) - float(yaw.min())) if not yaw.is_empty() else 0.0
	var pitch_range: float = (float(pitch.max()) - float(pitch.min())) if not pitch.is_empty() else 0.0
	check(yaw_range > .006 and pitch_range > .006, "The string scatters across and up and down (%.3f, %.3f rad)" % [yaw_range, pitch_range])
	check(yaw_range < .35 and pitch_range < .35, "...without leaving the target altogether")
	gun.automatic = false
	shots = 0
	Input.action_press("fire")
	await _seconds(.5)
	Input.action_release("fire")
	check(shots == 0, "On single shots a held trigger fires nothing more (%d)" % shots)
	gun.automatic = true
	check(gun.reload(), "The rifle reloads")
	await _seconds(2.6)
	check(gun.loaded() == 31 and not gun.reloading, "A full magazine and the round that was chambered (%d)" % gun.loaded())

	# ---- ballistics
	var drops := {}
	for which: String in ["pistol", "rifle", "shotgun", "sniper"]:
		var p: Dictionary = InteriorGun.PROFILES[which]
		check(p.has("round") and float(p.velocity) > 100.0 and float(p.damage) > 0.0 and float(p.knock) > 0.0 and int(p.pellets) >= 1, "%s has its own round (%s)" % [which, p.round])
		drops[which] = -InteriorGun.path_point(Vector3.ZERO, Vector3.FORWARD, 60.0, float(p.velocity), float(p.drag)).y
	check(drops.rifle < drops.pistol and drops.pistol < drops.shotgun, "At 60 m the rifle round has dropped least and buckshot most (%.3f, %.3f, %.3f m)" % [drops.rifle, drops.pistol, drops.shotgun])
	var buck: Dictionary = InteriorGun.PROFILES.shotgun
	check(exp(-2.0 * 40.0 / float(buck.drag)) > .4 and exp(-2.0 * 80.0 / float(buck.drag)) < .4, "Buckshot still has two fifths of its energy at 40 m, and less than that at 80")
	check(float(buck.pattern) < .02 and bool(buck.limb_pierce) and float(buck.velocity_spread) > 0.0, "It is a tight pattern of lead balls, each at its own speed, that go through a limb")

	# ---- the shotgun
	gun.instant_hits = true
	menu._summon_shotgun()
	await _seconds(1.6)
	check(gun.shotgun_owned and gun.weapon == "shotgun" and gun.loaded() == 7 and gun.reserve == 64, "Summon shotgun: loaded, 64 shells more (%d + %d)" % [gun.loaded(), gun.reserve])
	await _look(EYE, EYE + _ahead() * 5.0 + Vector3(0, -1.3, 0))
	shots = 0
	gun.try_fire()
	check(shots == 1 and gun.last_hits.size() >= 7, "One shell lands as a load of pellets (%d hits)" % gun.last_hits.size())
	var spread := 0.0
	var eye_now := player.camera.global_position
	for a: Dictionary in gun.last_hits:
		spread = maxf(spread, ((a.position as Vector3) - eye_now).angle_to((gun.last_hits[0].position as Vector3) - eye_now))
	check(spread > .008 and spread < .12, "...in a pattern (%.3f rad across)" % spread)
	await _seconds(.3)
	gun.try_fire()
	check(shots == 1, "It will not fire again before it is pumped")
	await _seconds(.7)
	gun.try_fire()
	check(shots == 2, "Pumped, it fires")
	await _seconds(.9)
	check(gun.reload(), "Shells go back into the tube")
	await _seconds(2.0)
	check(gun.loaded() == 8, "...one at a time until the tube is full again (%d)" % gun.loaded())

	# ---- an infected: hit boxes, a wound, a push
	await _look(EYE, AT)
	gun.spread_scale = 0.0
	gun.select("rifle")
	await _seconds(1.3)
	var z := _spawn(6.0, "kuya")
	check(z != null and z._bodies.size() == 16, "One spawns with sixteen hit boxes (the hands and the feet have their own)")
	await _seconds(.6)
	var head := _body(z, "head")
	var over := head.global_position - z.global_position
	check(over.y > 1.25 and over.y < 1.95 and Vector2(over.x, over.z).length() < .7, "The head's hit box is on its head (%s)" % str(over.snapped(Vector3.ONE * .01)))
	var before := z.global_position
	# (Its head hangs forward, some of them far enough to cover the chest from here: take a part of the trunk
	# that the round can reach.)
	for part: String in ["chest", "spine", "hips"]:
		if _aim_clear(z, part).is_finite():
			break
	await _frames(2)
	gun.try_fire()
	await _frames(3)
	check(not gun.last_hit.is_empty() and str(gun.last_hit.get("surface", "")) == "flesh", "A round at its chest strikes flesh")
	check(z.health < 100.0 and z.alive(), "It is wounded, not dead (%d left)" % int(z.health))
	check(zombies.blood.count() >= 1, "Blood lands on what is behind and under it (%d decals)" % zombies.blood.count())
	check(z._shove.length() > .2 or z.global_position.distance_to(before) > .01, "The hit pushes it back")
	check(not z.ragdolled and z._shove.length() < 2.5, "...a step, not off its feet (%.2f m/s)" % z._shove.length())
	check(zombies.blood.bleeders() >= 1, "The wound goes on bleeding (%d bleeding)" % zombies.blood.bleeders())
	check(zombies.blood.flying() >= 3, "Drops fly from the hit (%d in the air)" % zombies.blood.flying())
	# ---- a head shot: dead, a ragdoll, a pool
	await _seconds(1.2)
	check(zombies.blood.spots() >= 3, "...and leave spots where they land (%d)" % zombies.blood.spots())
	_aim(_body(z, "head").global_position)
	await _frames(2)
	gun.try_fire()
	await _frames(4)
	check(z.state == InteriorZombie.State.DEAD and z.ragdolled, "A head shot kills it and lets the ragdoll go")
	check(zombies.kills == 1, "The kill is counted")
	var decals := zombies.blood.count()
	await _seconds(6.0)
	var hips := _body(z, "hips")
	check(hips.global_position.y - before.y < .55, "The body is on the ground (hips %.2f m up)" % (hips.global_position.y - before.y))
	check(hips.global_position.is_finite() and hips.global_position.distance_to(before) < 6.0, "...near where it fell")
	# 0.38: the body you see is the ragdoll (the 0.30 crowd animation left dead ones frozen standing).
	# (Modifier output is only in the pose while the skeleton reports it updated; a skeleton left on manual never
	# reports it, so that is a failure here, not a wait.)
	if z.skeleton.modifier_callback_mode_process == Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE:
		await z.skeleton.skeleton_updated
	var hip_bone := z.skeleton.find_bone(hips.bone_name)
	var drawn_hips := z.skeleton.global_transform * z.skeleton.get_bone_global_pose(hip_bone).origin
	check(z.skeleton.modifier_callback_mode_process == Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE and drawn_hips.distance_to(hips.global_position) < .3,
		"The body drawn lies where the ragdoll lies (%.2f m apart, %.2f m up)" % [drawn_hips.distance_to(hips.global_position), drawn_hips.y - before.y])
	check(zombies.blood.count() > decals, "A pool spreads under it")

	# ---- knocked down, it gets up
	var k := _spawn(7.0, "obrero")
	await _seconds(.5)
	k.shot(_body(k, "chest"), _body(k, "chest").global_position, _ahead(), 1.0, 450.0, "test")
	await _frames(4)
	check(k.state == InteriorZombie.State.DOWN and k.ragdolled, "A hard enough blow puts a living one down as a ragdoll")
	await _seconds(5.0)
	check(k.alive() and not k.ragdolled and k.state != InteriorZombie.State.DOWN, "It gets up again (%s)" % InteriorZombie.State.keys()[k.state])
	zombies.remove(k)

	# ---- the shotgun at arm's length throws the body
	gun.select("shotgun")
	await _seconds(1.6)
	var t := _spawn(2.6, "tambay")
	await _seconds(.5)
	var stood := t.global_position
	_aim(_body(t, "chest").global_position)
	await _frames(2)
	gun.try_fire()
	await _frames(4)
	check(t.state == InteriorZombie.State.DEAD, "A load of buckshot at arm's length kills")
	await _seconds(1.6)
	var thrown := Vector2(t.chest_position().x - stood.x, t.chest_position().z - stood.z).length()
	# 0.43: the owner wants heavy rounds to throw bodies hard (InteriorZombie.blow): metres, but not out of sight.
	check(thrown > 2.0 and thrown < 9.0, "...and throws the body back hard, but not out of sight (%.1f m)" % thrown)

	# ---- 0.29: the rifle takes a forearm off
	zombies.clear()
	await _frames(3)
	gun.select("rifle")
	await _seconds(1.6)
	var a := _spawn(5.0, "nanay")
	await _seconds(.6)
	for round_index in 4:
		if not a._bodies.has("forearm.L"):
			break
		# (Fired at once: the arm swings while it walks.)
		_aim_clear(a, "forearm.L")
		gun.try_fire()
		await _seconds(.25)
	check(a.missing("forearm.L") and not a._bodies.has("forearm.L"), "Rifle rounds into a forearm take it off (%s)" % str(a.severed.keys()))
	check(a.alive() and a._bodies.size() == 14, "The rest of it is alive, with fourteen hit boxes (%d, health %d)" % [a._bodies.size(), int(a.health)])
	check(zombies.blood.parts() >= 1 and get_nodes_in_group("zombie_parts").size() >= 1, "The arm is a thing of its own on the ground")
	check(a.pose.arm_limp.x >= 1.0 and a.pose.arm_limp.y < 1.0, "It reaches with the arm it has left")
	var stumps := a.skeleton.find_children("Stump*", "BoneAttachment3D", false, false).size()
	check(stumps == 1, "The cut end is a stump (%d)" % stumps)
	await _seconds(1.5)
	check(zombies.blood.bleeders() >= 2 and zombies.blood.spots() >= 6, "The stump pumps blood onto the ground (%d bleeding, %d spots)" % [zombies.blood.bleeders(), zombies.blood.spots()])
	zombies.remove(a)

	# ---- 0.29: the sniper rifle; its round takes a leg, and what is left crawls
	menu._summon_sniper()
	await _seconds(2.0)
	check(gun.sniper_owned and gun.weapon == "sniper" and gun.loaded() == 5 and gun.reserve == 40, "Summon sniper rifle: loaded, 40 rounds more (%d + %d)" % [gun.loaded(), gun.reserve])
	var far_drop := -InteriorGun.path_point(Vector3.ZERO, Vector3.FORWARD, 200.0, 915.0, 1500.0).y
	check(far_drop > .12 and far_drop < .45, "Its round has dropped a hand or two by 200 m (%.2f m)" % far_drop)
	var c := _spawn(6.0, "obrero")
	# 0.40: rounds go where the drawn weapon points; a shin with a sniper rifle is a shot taken through the scope.
	Input.action_press("aim")
	await _seconds(.9)
	_aim(_body(c, "shin.R").global_position)
	await _seconds(.35)
	_aim(_body(c, "shin.R").global_position)
	await _frames(2)
	shots = 0
	gun.try_fire()
	await _frames(4)
	Input.action_release("aim")
	check(shots == 1 and c.missing("shin.R"), "One round into a shin takes the leg off (%s)" % str(c.severed.keys()))
	check(c.alive() and c.ragdolled, "It is alive and on the ground (health %d)" % int(c.health))
	gun.try_fire()
	check(shots == 1, "The rifle will not fire again before the bolt is worked")
	await _seconds(1.2)
	gun.try_fire()
	check(shots == 2, "Worked, it fires")
	await _seconds(3.5)
	check(c.state == InteriorZombie.State.CRAWL, "Without a leg it does not get up (%s)" % InteriorZombie.State.keys()[c.state])
	var lay := c.where()
	zombies.passive = false
	await _seconds(4.0)
	zombies.passive = true
	var gained := lay.distance_to(player.global_position) - c.where().distance_to(player.global_position)
	check(gained > .25 and gained < 4.0, "It drags itself toward the player (%.2f m in 4 s)" % gained)
	# ---- the scope
	var base_fov := player.camera.fov
	Input.action_press("aim")
	await _seconds(1.2)
	var eight := rad_to_deg(2.0 * atan(tan(deg_to_rad(float(player.get("_base_fov"))) * .5) / 8.0))
	check(gun.scoped > .95 and gun.scope_zoom == 8.0, "The right button puts the eye to the scope, at 8x (%.2f)" % gun.scoped)
	check(absf(player.camera.fov - eight) < 1.0, "The lens narrows to an eighth (%.1f of %.1f degrees)" % [player.camera.fov, base_fov])
	check(player.look_scale < .2 and not player.free_aim, "The mouse slows by as much (%.3f)" % player.look_scale)
	check(main.hud.get_node_or_null("Scope") != null and (main.hud.get_node("Scope") as CanvasItem).visible, "The scope's tube and reticle are drawn over the picture")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await _seconds(.2)
	check(gun.scope_zoom == 7.0, "The wheel turns the power down a step (%.0fx)" % gun.scope_zoom)
	gun.turn_scope(-9)
	await _seconds(1.0)
	check(gun.scope_zoom == 2.0 and player.camera.fov > eight * 3.0, "...as far as 2x (%.1f degrees)" % player.camera.fov)
	gun.turn_scope(9)
	check(gun.scope_zoom == 8.0, "...and back up to 8x")
	Input.action_release("aim")
	await _seconds(1.6)
	check(gun.scoped == 0.0 and player.look_scale == 1.0 and absf(player.camera.fov - base_fov) < 1.5, "Letting go gives the plain view back (%.1f)" % player.camera.fov)
	check(not (main.hud.get_node("Scope") as CanvasItem).visible, "...and takes the scope away")
	zombies.remove(c)

	# ---- 0.29: buckshot takes a head apart
	var h := _spawn(4.0, "dalaga")
	await _seconds(.5)
	var pieces := zombies.blood.parts()
	for pellet in 6:
		h.shot(_body(h, "head"), _body(h, "head").global_position, _ahead(), 19.0, 85.0, "shotgun", 25.0)
	await _frames(4)
	check(h.missing("head") and h.state == InteriorZombie.State.DEAD, "Six pellets in the head: it has none, and is dead")
	check(zombies.blood.parts() >= pieces + 6, "The head came apart (%d pieces)" % (zombies.blood.parts() - pieces))
	gun.spread_scale = 1.0

	# ---- they wander; one that sees the player comes
	zombies.clear()
	await _frames(3)
	check(zombies.alive().is_empty() and zombies.blood.count() == 0, "Clear takes the bodies and the blood away")
	menu._spawn_zombies(5)
	# 0.33: the figures are built one every other frame.
	check(zombies.pending() >= 3, "Spawn 5 finds places in the neighbourhood (%d waiting)" % zombies.pending())
	while zombies.pending() > 0:
		await _frames(1)
	await _frames(3)
	var crowd := zombies.alive()
	check(crowd.size() >= 3, "Spawn 5 finds places in the neighbourhood (%d)" % crowd.size())
	var nearest := 999.0
	var starts := {}
	for one in crowd:
		nearest = minf(nearest, one.global_position.distance_to(player.global_position))
		starts[one] = one.global_position
	check(nearest >= 13.0, "...none of them on top of the player (nearest %.1f m)" % nearest)
	await _seconds(9.0)
	var wandered := 0
	for one in crowd:
		if is_instance_valid(one) and one.global_position.distance_to(starts[one]) > .5:
			wandered += 1
	check(wandered >= 1, "Left alone they wander (%d of %d moved)" % [wandered, crowd.size()])
	zombies.clear()
	gun.holster(true)
	await _look(EYE, AT)
	var hunter := _spawn(6.0, "tanod")
	zombies.passive = false
	await _seconds(1.0)
	var los := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(hunter.global_position + Vector3.UP * 1.5, player.camera.global_position, 2))
	print("HUNTER at ", hunter.global_position, " player ", player.global_position, " playing ", player.playing, " can_target ", zombies.can_target(), " sees ", hunter.sees,
		" facing ", (-hunter.global_basis.z).dot((player.global_position - hunter.global_position).normalized()), " los ", los.get("collider"), " ", los.get("position"))
	check(hunter.state == InteriorZombie.State.ALERT or hunter.state == InteriorZombie.State.CHASE, "One that sees the player screams and comes (%s)" % InteriorZombie.State.keys()[hunter.state])
	var reached := false
	for i in 480:
		await physics_frame
		if zombies.health < 100.0:
			reached = true
			break
	check(reached, "It reaches the player and claws (health %d)" % int(zombies.health))
	check(hunter.global_position.distance_to(player.global_position) < 2.2, "...from arm's length")
	menu._controls["zombies_passive"].button_pressed = true
	await _seconds(.5)
	check(zombies.passive and hunter.state != InteriorZombie.State.CHASE and hunter.state != InteriorZombie.State.ATTACK, "\"They ignore me\" calls it off")
	menu._spawn_zombies(0)
	await _frames(3)
	check(zombies.alive().size() == 2, "Spawn 1 ahead adds one")
	main.zombies.kill_all()
	await _frames(4)
	check(zombies.alive().is_empty() and get_nodes_in_group("zombie_corpses").size() == 2, "Kill all drops them where they stand")
	menu._arsenal()
	await _frames(2)
	check(gun.owned and gun.rifle_owned and gun.shotgun_owned and gun.sniper_owned, "Arsenal gives every weapon")

	# ---- 0.31: thirteen kinds, and a body that comes apart piece by piece
	zombies.clear()
	zombies.passive = true
	zombies.invulnerable = true
	menu._controls["zombies_passive"].button_pressed = true
	await _look(EYE, AT)
	await _frames(6)
	var kinds: Dictionary = InteriorZombie.KINDS
	var sound := true
	for key: String in kinds:
		var figures: Dictionary = kinds[key]
		sound = sound and figures.has("label") and figures.has("walk") and figures.has("chase") and float(figures.health) > 0.0 and float(figures.weight) > 0.0
	check(kinds.size() >= 10 and sound, "There are at least ten kinds, each with its own figures (%d)" % kinds.size())
	check(InteriorZombie.KINDS.has(InteriorZombie.pick_kind()), "A kind is picked by weight")
	var slow := _spawn(6.0, "kuya", "limper")
	var quick := _spawn(8.0, "kuya", "rager")
	check(slow != null and quick != null and slow.chase_speed < 1.4 and quick.chase_speed > 5.0 and not slow.runner and quick.runner,
		"A limper is slow and a rager is fast (%.1f, %.1f m/s)" % [slow.chase_speed if slow != null else 0.0, quick.chase_speed if quick != null else 0.0])
	var big := _spawn(10.0, "obrero", "brute")
	check(big != null and big.health > 200.0 and big.model.scale.x > 1.1 and big.tough > 1.0, "A brute is big and takes three times as much")
	zombies.clear()
	await _frames(6)
	# The hand, then the foot.
	var torn := _spawn(5.0, "kuya")
	await _seconds(.4)
	_strike(torn, "hand.R", 6.0, 18.0)
	await _frames(3)
	check(int(torn._chunked.get("hand.R", 0)) >= 1 and not torn.missing("hand.R"), "A hand that has taken some is torn, not off")
	_strike(torn, "hand.R", 6.0, 20.0)
	await _frames(3)
	check(torn.missing("hand.R") and not torn.missing("forearm.R") and torn._bodies.has("forearm.R") and torn.alive(), "The hand comes off at the wrist; the forearm stays")
	check(not torn._arm_gone["R"], "...and the arm still reaches")
	_strike(torn, "foot.L", 6.0, 50.0)
	await _frames(4)
	check(torn.missing("foot.L") and torn._foot_gone["L"] and not torn._legless and torn.alive(), "A foot comes off at the ankle; it is not legless")
	check(torn.ragdolled or torn.state == InteriorZombie.State.DOWN, "...and it goes over")
	var parts_before := get_nodes_in_group("zombie_parts").size()
	check(parts_before >= 2, "The hand and the foot lie where they fell (%d parts)" % parts_before)
	zombies.remove(torn)
	await _frames(4)
	# The chest: torn, torn again, and then apart.
	var burst := _spawn(5.0, "tambay")
	await _seconds(.4)
	_strike(burst, "chest", 4.0, 130.0)
	await _frames(3)
	check(int(burst._chunked.get("chest", 0)) == 1 and burst._bodies.has("chest"), "A chest that has taken two fifths of what it holds has a piece torn out of it")
	_strike(burst, "chest", 4.0, 100.0)
	await _frames(3)
	check(int(burst._chunked.get("chest", 0)) == 2, "...and another at three quarters")
	_strike(burst, "chest", 4.0, 90.0)
	await _frames(5)
	check(burst.missing("chest") and burst.missing("head") and burst.missing("upper_arm.L") and burst.missing("upper_arm.R"), "Then it comes apart: the arms and the head go (%s)" % str(burst.severed.keys()))
	check(not burst.alive() and burst.ragdolled and burst._bodies.has("hips") and burst._bodies.has("thigh.L"), "What is left is hips and legs, dead on the ground")
	zombies.remove(burst)
	await _frames(4)
	# The belly.
	var halved := _spawn(5.0, "tanod")
	await _seconds(.4)
	_strike(halved, "hips", 3.0, 300.0)
	await _frames(5)
	check(halved.missing("thigh.L") and halved.missing("thigh.R") and halved._legless, "A belly that gives way lets both legs go")
	check(halved.alive(), "...and what is left is still alive (health %d)" % int(halved.health))
	zombies.remove(halved)
	await _frames(4)
	# One that plays dead.
	var lurker := _spawn(9.0, "kuya", "lurker")
	await _seconds(1.6)
	check(lurker != null and lurker.ragdolled and lurker._playing_dead and lurker.alive() and lurker.state == InteriorZombie.State.DOWN, "A lurker lies among the dead, alive")
	await _seconds(2.0)
	check(lurker._playing_dead and lurker.state == InteriorZombie.State.DOWN, "...for as long as nobody comes near")
	_strike(lurker, "thigh.L", 5.0, 1.0)
	await _seconds(4.5)
	check(not lurker._playing_dead and (lurker.state != InteriorZombie.State.DOWN or not lurker.alive()), "Shot, it stops pretending (%s)" % InteriorZombie.State.keys()[lurker.state])
	zombies.remove(lurker)
	# One that only moves when it is not looked at.
	menu._controls["zombies_passive"].button_pressed = false
	zombies.passive = false
	await _look(EYE, AT)
	var stalker := _spawn(6.5, "tanod", "stalker")
	await _seconds(1.2)
	var stood_31 := stalker.global_position
	await _seconds(2.0)
	check(stalker.state == InteriorZombie.State.CHASE and stalker.global_position.distance_to(stood_31) < .6, "A stalker that is looked at does not move (%s, %.2f m)" % [InteriorZombie.State.keys()[stalker.state], stalker.global_position.distance_to(stood_31)])
	_aim(EYE - _ahead() * 6.0)
	var far_before := stalker.global_position.distance_to(player.global_position)
	await _seconds(1.5)
	check(stalker.global_position.distance_to(player.global_position) < far_before - 1.5, "Look away, and it comes (%.1f m closer)" % (far_before - stalker.global_position.distance_to(player.global_position)))
	zombies.remove(stalker)
	await _frames(4)
	# One that jumps.
	await _look(EYE, AT)
	var leaper := _spawn(6.8, "kuya", "leaper")
	var jumped := false
	var bitten := zombies.health
	for i in 600:
		await physics_frame
		if leaper.state == InteriorZombie.State.LEAP and leaper._leap_phase == 1:
			jumped = true
			break
	check(jumped, "A leaper that has come close gathers itself and jumps")
	check(not leaper.is_on_floor() or leaper.velocity.y > 0.0, "...off the ground")
	await _seconds(1.6)
	check(leaper.state != InteriorZombie.State.LEAP, "...and lands (%s)" % InteriorZombie.State.keys()[leaper.state])
	zombies.remove(leaper)
	menu._controls["zombies_passive"].button_pressed = true
	zombies.passive = true
	await _look(EYE, AT)
	var every: int = zombies.spawn_every_kind()
	await _seconds(1.0)
	check(every >= 9 and zombies.alive().size() == every, "One of every kind stands in an arc ahead (%d of %d)" % [every, kinds.size()])
	zombies.clear()
	await _frames(6)
	_finish()

func _finish() -> void:
	await _frames(4)
	check(catcher.errors.is_empty(), "No errors in the log (%d)" % catcher.errors.size())
	for line in catcher.errors.slice(0, 12):
		print("  ERROR ", line)
	print("ZOMBIES_INTEGRATION checks=%d failures=%d" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
