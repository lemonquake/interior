extends SceneTree
## 0.11: the usable Glock (scripts/gun.gd), headless:
##   godot --headless --path game --script res://tests/gun_integration.gd --fixed-fps 60 [-- --mobile-test]
## Draw and holster; empty: a dry click and "It's empty." and no shot; after the hooded man's 60 rounds 0 / 60,
## a reload makes it 17 / 43; 17 shots empty it and the 18th dry-clicks until the next reload; the fire-rate cap;
## a shot at a room prop knocks it and leaves one hole on it; holes are capped at 40; a shot at the hamster
## enclosure cracks the glass and leaves the hamsters and the enclosure alone; a shot TV stops on static;
## Hold (E) on a prop leaves the gun up; (mobile) the Gun, Fire and Reload buttons appear only when they apply;
## no errors in the log.

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])
	func _log_message(message: String, error: bool) -> void:
		pass

var checks := 0
var failures: Array[String] = []
var results := {}
var main: Node
var player: InteriorPlayer
var story: InteriorStory
var gun: InteriorGun
var catcher := ErrorCatcher.new()
var mobile := false

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

## Stand at `eye` (camera height) and look at `at`.
func _look(eye: Vector3, at: Vector3) -> void:
	player.reset_motion(eye - Vector3(0, InteriorPlayer.STANDING_EYE, 0))
	await _frames(4)
	var to := at - player.camera.global_position
	player.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
	player.set("_look_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
	player.recoil = 0.0
	player.camera.rotation.x = player.get("_look_pitch")
	await _frames(2)

func _fire_ok() -> bool:
	var before := gun.loaded()
	gun.try_fire()
	return gun.loaded() == before - 1

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(6)
	player = main.player
	story = main.story
	mobile = main.mobile
	check(story != null and story.gun != null, "The story owns the gun")
	if story == null:
		_finish()
		return
	gun = story.gun
	var touch: InteriorTouchControls = main.touch
	# 1. Not owned yet: nothing to draw.
	gun.draw()
	check(not gun.drawn, "Before the drawer, there is no gun to draw")
	if mobile:
		check(not touch._gun_button.visible and not touch._reload_button.visible and touch._throw_button.text == "Throw", "Mobile: no Gun or Reload button before the gun is owned")
	gun.give()
	story.has_gun = true
	check(gun.owned and gun.loaded() == 0 and gun.reserve == 0, "Out of the drawer it is empty (%s)" % gun.ammo_text())
	if mobile:
		check(touch._gun_button.visible and not touch._reload_button.visible, "Mobile: the Gun button appears once it is owned")
	# 2. Draw and holster (in the room, facing a wall).
	var eye := Vector3(.62, InteriorPlayer.STANDING_EYE + .02, 1.3)
	var wall := await _find_wall(eye)
	check(wall.is_finite(), "Found a bare wall to shoot at (%s)" % wall)
	await _look(eye, wall)
	gun.draw()
	await _seconds(.6)
	check(gun.drawn and gun._container.visible and gun.ammo_label.visible, "Drawn: the view model and the ammo readout show")
	check(gun.ammo_label.text == "0 / 0", "Readout %s" % gun.ammo_label.text)
	if mobile:
		check(touch._reload_button.visible and touch._throw_button.text == "Fire" and touch._gun_button.text == "Holster", "Mobile: drawn, Throw becomes Fire and Reload appears")
	gun.holster()
	await _seconds(.5)
	check(not gun.drawn and not gun._container.visible and not gun.ammo_label.visible, "Holstered: the view model is gone")
	if mobile:
		check(not touch._reload_button.visible and touch._throw_button.text == "Throw", "Mobile: holstered, back to Throw and no Reload")
	gun.draw()
	await _seconds(.6)
	# 3. Empty: a dry click, the toast, no shot.
	var holes := gun.bullet_holes()
	check(gun.try_fire(), "The click is the gun's while drawn (no throw)")
	await _frames(2)
	check(story.ui.last_notification() == InteriorGun.DRY_TOAST, "Empty: \"%s\" (%s)" % [InteriorGun.DRY_TOAST, story.ui.last_notification()])
	check(gun.bullet_holes() == holes and gun.loaded() == 0, "Empty: no shot, no hole")
	# 4. The hooded man's rounds, then a reload.
	story.receive_ammo()
	await _frames(2)
	check(gun.ammo_text() == "0 / 60" and story.ammo == 60, "Received 60: %s (story %d)" % [gun.ammo_text(), story.ammo])
	check(gun.reload(), "Reload starts")
	await _seconds(InteriorGun.RELOAD_TIME + .15)
	check(gun.ammo_text() == "17 / 43" and not gun.reloading, "After the reload: %s" % gun.ammo_text())
	check(gun.ammo_label.text == "17 / 43" and story.inventory_label.text.contains("60 rounds"), "Readout %s, inventory \"%s\"" % [gun.ammo_label.text, story.inventory_label.text])
	# "Now... run." is up: a click there moves the dialogue on and doesn't shoot.
	await _seconds(.4)
	if story.ui.dialogue_active():
		var before := gun.loaded()
		gun.try_fire()
		check(gun.loaded() == before, "A click on the dialogue doesn't fire")
		while story.ui.dialogue_active():
			story.ui.advance()
	# 5. Fire-rate cap: two clicks in the same frame are one shot.
	await _look(eye, wall)
	gun.try_fire()
	gun.try_fire()
	await _frames(1)
	check(gun.loaded() == 16, "Two clicks at once fire once (%d left)" % gun.loaded())
	check(gun.bullet_holes() == holes + 1, "The shot left a hole in the wall (%d)" % (gun.bullet_holes() - holes))
	var flash_seen := false
	for node in main.get_children():
		flash_seen = flash_seen or String(node.name).begins_with("MuzzleFlash")
	check(flash_seen, "The muzzle flash lights the world")
	check(player.recoil > 0.0, "The view kicks up")
	await _seconds(.05)
	check(not _fire_ok(), "No second shot inside the pistol's interval (a ninth of a second)")
	await _seconds(.2)
	# 6. A room prop: knocked, one hole on it.
	var prop := await _find_prop()
	check(prop != null, "Found a loose prop in clear view")
	if prop != null:
		var before := prop.global_position
		var on_prop := prop.find_children("BulletHole", "", true, false).size()
		check(_fire_ok(), "Shot at the %s" % prop.display_name)
		await _seconds(.4)
		var moved := prop.global_position.distance_to(before)
		results["prop_moved_m"] = snappedf(moved, .001)
		check(moved > .01 or prop.linear_velocity.length() > .05, "The prop is knocked (%.3f m)" % moved)
		check(prop.find_children("BulletHole", "", true, false).size() == on_prop + 1, "One hole on the prop")
	# 7. Empty the magazine: 17 shots in all, then the 18th dry-clicks until a reload.
	await _look(eye, wall)
	var shots := 17 - gun.loaded()
	var missed := 0
	while gun.loaded() > 0 and shots < 30:
		if not _fire_ok():
			missed += 1
		shots += 1
		await _seconds(.27)
	check(missed == 0, "Every click a quarter second apart fires (%d missed)" % missed)
	check(shots == 17 and gun.ammo_text() == "0 / 43", "17 shots empty it (%d, %s)" % [shots, gun.ammo_text()])
	story.ui.notify("-")
	await _seconds(.3)
	gun.try_fire()
	await _frames(2)
	check(gun.loaded() == 0 and story.ui.last_notification() == InteriorGun.DRY_TOAST, "The 18th dry-clicks: %s" % story.ui.last_notification())
	await _seconds(.3)
	gun.try_fire()
	check(gun.loaded() == 0, "Still empty until a reload")
	gun.reload()
	await _seconds(InteriorGun.RELOAD_TIME + .15)
	check(gun.ammo_text() == "17 / 26", "Reloaded: %s" % gun.ammo_text())
	# 8. Hole cap.
	for i in InteriorGun.DECAL_MAX:
		gun._decal(wall + Vector3(randf_range(-.3, .3), randf_range(-.3, .3), 0), Vector3(0, 0, 1), "stone", null)
	await _frames(2)
	results["holes_after_50_more"] = gun.bullet_holes()
	check(gun.bullet_holes() == InteriorGun.DECAL_MAX, "Holes are capped at %d (%d)" % [InteriorGun.DECAL_MAX, gun.bullet_holes()])
	# 9. The hamster enclosure: the glass stops it.
	var enclosure := main.find_child("pet_enclosure_11", true, false) as RigidBody3D
	check(enclosure != null, "Found the hamster enclosure")
	if enclosure != null:
		var habitat := enclosure.get_node_or_null("HamsterPlayground") as HamsterEnclosure
		var pets := habitat.residents.duplicate() if habitat != null else []
		var at := enclosure.global_position
		var glass_eye := enclosure.to_global(Vector3(.10, 1.20, 1.18))
		await _look(glass_eye, enclosure.to_global(Vector3(0, 1.06, 0)))
		var hit := player.ray_hit(InteriorGun.RANGE, InteriorGun.MASK)
		check(hit and hit.collider == enclosure, "Aiming at the enclosure glass (%s)" % (hit.get("collider") if hit else "nothing"))
		var cracks := enclosure.find_children("BulletHole", "", true, false).size()
		check(_fire_ok(), "Shot at the hamsters' glass")
		await _seconds(.5)
		check(enclosure.find_children("BulletHole", "", true, false).size() == cracks + 1, "The glass takes a crack")
		check(enclosure.global_position.distance_to(at) < .002 and enclosure.linear_velocity.length() < .01, "The enclosure isn't knocked")
		var safe := habitat != null and pets.size() == 3
		for pet in pets:
			safe = safe and is_instance_valid(pet) and habitat.contains_resident(pet)
		check(safe, "All three hamsters are untouched, still inside")
	# 10. A shot TV stops on static.
	var tv: InteriorTelevision = null
	for body in get_nodes_in_group("movable"):
		if body.has_meta("interactor") and body.get_meta("interactor") is InteriorTelevision:
			tv = body.get_meta("interactor")
	if tv != null:
		var screen_at: Vector3 = tv.screen.global_position if tv.screen != null else tv.body.global_position
		var tv_eye := screen_at + tv.body.global_basis.z.normalized() * 1.6 + Vector3(0, .1, 0)
		await _look(tv_eye, screen_at)
		var hit_tv := player.ray_hit(InteriorGun.RANGE, InteriorGun.MASK)
		if hit_tv and hit_tv.collider == tv.body:
			_fire_ok()
			await _frames(3)
			check(tv.broken and tv.powered and not tv.is_news(), "A shot TV stops on static")
		else:
			print("  (TV not in clear view from ", tv_eye, ": ", hit_tv.get("collider"), ")")
	# 11. Hold (E) on a prop picks it up and the gun stays in the hands (0.30: only G puts it away).
	prop = await _find_prop()
	if prop != null:
		gun.draw()
		await _seconds(.6)
		player.update_target()
		check(player.target == prop, "Aiming at a prop with the gun out")
		player.hold_pressed()
		await _frames(3)
		check(gun.drawn and player.held == prop, "Hold takes the prop and the gun stays up")
		player.hold_released()
		player.hold_pressed()
		await _frames(2)
		player.hold_released()
		check(gun.drawn and player.held == null, "Hold again drops the prop, the gun still up")
		gun.holster(true)
		player.hold_pressed()
		await _frames(3)
		player.hold_released()
		gun.draw()
		await _frames(2)
		check(gun.drawn and player.held == null, "Drawing drops what is held")
	results["errors"] = catcher.errors.slice(0, 5)
	check(catcher.errors.is_empty(), "No errors in the log (%d)" % catcher.errors.size())
	_finish()

## A direction from `eye` whose ray meets a static wall 1.2..4 m away, at eye height.
func _find_wall(from: Vector3) -> Vector3:
	await _look(from, from + Vector3(0, 0, -1))
	var space := player.get_world_3d().direct_space_state
	for k in 24:
		var a := TAU * k / 24.0
		var dir := Vector3(sin(a), -.05, -cos(a))
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * 4.0, InteriorGun.MASK)
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		if hit and hit.collider is StaticBody3D and from.distance_to(hit.position) > 1.2 and absf(hit.normal.y) < .2:
			return hit.position
	return Vector3.INF

## A light, loose prop the player can stand 1.3 m from and see, looking at it from there.
func _find_prop() -> InteriorObject:
	for body in get_nodes_in_group("movable"):
		var prop := body as InteriorObject
		if prop == null or prop.anchored or prop.mass > 4.0 or prop.mass < .1 or prop.global_position.y < -.5 or prop.grab_mode == "none":
			continue
		if prop.has_meta("interactor") or InteriorGun.is_pet_home(prop):
			continue
		var centre := prop.to_global(prop.center_of_mass)
		for k in 8:
			var a := TAU * k / 8.0
			var eye := centre + Vector3(sin(a), 0, cos(a)) * 1.3
			eye.y = InteriorPlayer.STANDING_EYE + .02
			if eye.x > 3.0 or eye.x < -3.0 or eye.z > 2.4 or eye.z < -2.3:
				continue
			await _look(eye, centre)
			var hit := player.ray_hit(InteriorPlayer.REACH, 6)
			if hit and hit.collider == prop and player.global_position.y > -.2:
				return prop
	return null

func _finish() -> void:
	print("GUN_INTEGRATION ", JSON.stringify({"checks": checks, "failures": failures, "results": results, "mobile": mobile}))
	quit(0 if failures.is_empty() else 1)
