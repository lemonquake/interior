extends SceneTree
## 0.59: a sweep of PILCST from the back gate to the rear gate, for finding what is out of place. At every co-op
## debug jump from "school" to "pilcstout" (or `--only=a,b`): the jump as play leaves it, the torch on, four looks
## (the jump's facing, right, behind, left) put together on one 2x2 sheet, and a few checks printed per spot:
## standing on something (not falling), infected inside solid geometry, infected below the floor they belong to.
##   godot --path game --script res://tests/school_route_sweep.gd -- [--out=<dir>] [--only=a,b] [--size=1280x720]
##   (prints SWEEP <jump> ... lines and SWEEP_DONE problems=<n>)
var game
var problems := 0
const ROUTE := ["school", "lobby", "floor2", "fireescape", "floor3", "floor4", "ladder", "duct", "floor5", "teves",
	"horde", "sneak", "firedoor", "blast", "room208", "field", "heavyarm", "heavykey", "reargate", "pilcstout"]

func _initialize() -> void: run.call_deferred()

func note(jump: String, what: String) -> void:
	problems += 1
	print("SWEEP_PROBLEM %s %s" % [jump, what])

func run() -> void:
	var out := ProjectSettings.globalize_path("res://../work/v59/sweep")
	var only: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--only="): only = a.trim_prefix("--only=").split(",")
		if a.begins_with("--size="):
			var wh := a.trim_prefix("--size=").split("x")
			root.size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(out)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 30: await process_frame
	var s = game.coop
	s.host()
	s.start_game()
	for i in 20: await physics_frame
	game._apply_quality(2)
	var m = s.mission
	s.harmless = true
	var player: InteriorPlayer = game.player
	for jump: String in ROUTE:
		if not only.is_empty() and not jump in only: continue
		var r: Array = m.debug_jump(jump)
		if r.is_empty():
			note(jump, "jump refused: %s" % str(m.debug_note))
			continue
		s.debug_move_squad(r[0], float(r[1]), true, s.local_id())
		for i in 30: await physics_frame
		for i in 1500:
			if not s._catching: break
			await process_frame
		if s._chapter_screen != null: s._chapter_screen.visible = false
		for i in 40: await physics_frame
		game.story.gun.holster(true)
		game.story.flashlight.set_on(true)
		game.hud.visible = false
		var feet := player.global_position
		var yaw := player.rotation.y
		# Standing on something.
		var space := player.get_world_3d().direct_space_state
		var down := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * .3, feet + Vector3.DOWN * 1.5, 1 | 2)
		var hit := space.intersect_ray(down)
		if hit.is_empty(): note(jump, "nothing under the player at %s" % str(feet.snapped(Vector3.ONE * .01)))
		elif feet.y - hit.position.y > .25: note(jump, "player %.2f m above the floor" % (feet.y - hit.position.y))
		# The infected: inside something solid, or fallen below the level they stand on.
		var alive := 0
		for k in m.enemies.keys():
			var z = m.enemies[k]
			if not is_instance_valid(z) or z.hp <= 0: continue
			alive += 1
			var q := PhysicsPointQueryParameters3D.new()
			q.position = z.global_position + Vector3.UP * .9
			q.collision_mask = 2
			q.collide_with_bodies = true
			var inside := space.intersect_point(q, 4)
			for c in inside:
				if c.collider != z and not (c.collider is Node and z.is_ancestor_of(c.collider)):
					note(jump, "infected %s inside %s at %s" % [str(k), str(c.collider.name), str((z.global_position - m.Street.ORIGIN).snapped(Vector3.ONE * .01))])
					break
			var below := PhysicsRayQueryParameters3D.create(z.global_position + Vector3.UP * .5, z.global_position + Vector3.DOWN * 3.0, 1 | 2)
			if space.intersect_ray(below).is_empty():
				note(jump, "infected %s with no floor under it at %s" % [str(k), str((z.global_position - m.Street.ORIGIN).snapped(Vector3.ONE * .01))])
		var esc = m.get("escape")
		if esc != null and not esc.people.is_empty():
			var ds: Array = []
			for f in esc.people: ds.append(snappedf(Vector2(f.position.x - feet.x, f.position.z - feet.z).length(), .01))
			print("SWEEP %s survivors from the player %s" % [jump, str(ds)])
			for f in esc.people:
				if Vector2(f.position.x - feet.x, f.position.z - feet.z).length() < .8: note(jump, "a survivor within 0.8 m of the player")
		print("SWEEP %s stage %d at %s yaw %.2f alive %d result %s" % [jump, m.stage, str((feet - m.Street.ORIGIN).snapped(Vector3.ONE * .01)), yaw, alive, str(r)])
		var sheet: Image = null
		for turn in 4:
			player.rotation.y = yaw - turn * PI * .5
			player.camera.rotation.x = -.08
			for i in 8: await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var w := img.get_width() / 2
			var h := img.get_height() / 2
			img.resize(w, h, Image.INTERPOLATE_BILINEAR)
			if sheet == null: sheet = Image.create(w * 2, h * 2, false, img.get_format())
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((turn % 2) * w, (turn / 2) * h))
		player.rotation.y = yaw
		sheet.save_jpg("%s/%02d_%s.jpg" % [out, ROUTE.find(jump), jump], .88)
	print("SWEEP_DONE problems=%d" % problems)
	quit(0)
