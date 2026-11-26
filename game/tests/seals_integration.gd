extends SceneTree
## 0.26: the world has no holes and no ways to wander off it (scripts/map_seals.gd), checked on the collision of a
## fresh game with the walkability fill of tests/world_audit.gd run over the whole world, rice-field road included:
## - no edge anywhere lets a standing or crouching body step off into nothing;
## - nowhere can only be reached by a fall (a place to drop into and not climb out of);
## - every key place is still reached from the courtyard gate: both street corners, the road to the fields and its
##   far end, the hut, the scarecrow islet, the canal catwalk, the warren entry, the Nichols gate and porch;
## - the ground that was sealed is not reached: the strip behind the west lots of the town, the dike north of the
##   canal district, the lots outside the north wall, the band round the Nichols fence;
## - the seals are built (sheets, colliders).
##   godot --headless --path game --script res://tests/seals_integration.gd --fixed-fps 60

const Audit := preload("res://tests/world_audit.gd")
const WORLD := Rect2(-130.0, -136.0, 230.0, 700.0)
## Reached (label -> where), and sealed (must not be within 1.5 m of any reached cell).
const REACHED := {
	"far end of the field road": Vector3(40.5, -2.9, 520.0),
	"hut footpath": Vector3(27.0, -2.9, 150.0),
	"scarecrow islet": Vector3(28.9, -3.06, 178.7),
	"canal far bank": Vector3(-73.0, -5.45, 20.0),
	"canal north bridge": Vector3(-66.0, -2.1, 60.2),
	"Nichols foyer": Vector3(-12.0, -1.7, -84.5),
}
const SEALED := {
	"strip behind the west lots (north)": Vector3(-34.5, -2.9, 40.0),
	"strip behind the west lots (south)": Vector3(-34.5, -2.9, 0.0),
	"dike north of the canal district": Vector3(-60.0, -2.9, 76.0),
	"west end of that dike": Vector3(-118.0, -2.9, 78.0),
	"outside the north wall of the town": Vector3(-12.0, -2.9, 60.0),
	"west of the start of the field road": Vector3(8.0, -2.9, 65.2),
	"behind the back wall of the warren": Vector3(-119.6, -2.1, 45.0),
	"outside the Nichols fence (west)": Vector3(-44.0, -2.9, -90.0),
	"outside the Nichols fence (south)": Vector3(-12.0, -2.9, -128.0),
}

var checks := 0
var failures: Array[String] = []
var results := {}

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _nearest(audit: Object, at: Vector3) -> float:
	var best := 1e9
	for key in audit.cells:
		var cell: Dictionary = audit.cells[key]
		var p: Vector2 = audit._centre(cell.c)
		best = minf(best, Vector2(at.x, at.z).distance_to(p) + absf(float(cell.y) - at.y) * .5)
	return best

func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	for i in 50: await process_frame
	var player: InteriorPlayer = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var stranger := main.get_node_or_null("Stranger")
	if stranger != null: stranger.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 12: await physics_frame
	var seals := main.find_child("Map seals", true, false)
	check(seals != null, "The map seals are built under the neighbourhood")
	if seals != null:
		var meta: Dictionary = seals.get_meta("map_seals", {})
		results["seals"] = meta
		check(int(meta.get("sheets", 0)) > 250, "Sheet-iron runs along the open edges (%d sheets)" % meta.get("sheets", 0))
		check(int(meta.get("edges", 0)) >= 12 and int(meta.get("slits", 0)) >= 15, "Edges and slits are all listed (%d, %d)" % [meta.get("edges", 0), meta.get("slits", 0)])
		check(seals.get_node("Map seal colliders").get_child_count() >= 30, "Every run collides")
	var audit: Object = Audit.new()
	audit.space = player.get_world_3d().direct_space_state
	audit.out = ProjectSettings.globalize_path("res://../work/v26/seals")
	DirAccess.make_dir_recursive_absolute(audit.out)
	audit.region = WORLD
	audit.want_voids = true
	audit.want_cells = true
	var report: Dictionary = audit._fill()
	results["summary"] = report.get("summary", {})
	results["voids"] = audit.void_count
	results["drops"] = audit.drop_count
	results["fall_only_cells"] = audit.fallen.size()
	results["void_spots"] = audit.void_spots.slice(0, 12)
	check(audit.void_count == 0, "No edge to step off into nothing (%d found, first %s)" % [audit.void_count, audit.void_spots.slice(0, 3)])
	check(audit.fallen.is_empty(), "No ground that can only be fallen into (%d cells)" % audit.fallen.size())
	var keys: Dictionary = report.get("keys", {})
	for label in keys:
		check(not keys[label] is String, "Reached from the gate: %s" % label)
	for label in REACHED:
		var off := _nearest(audit, REACHED[label])
		check(off < 2.0, "Reached from the gate: %s (nearest walkable cell %.1f m away)" % [label, off])
	for label in SEALED:
		var off := _nearest(audit, SEALED[label])
		check(off > 1.5, "Sealed: %s (a walkable cell %.1f m away)" % [label, off])
	var cells := int((report.get("summary", {}) as Dictionary).get("walkable_cells", 0))
	check(cells > 24000 and cells < 28500, "The walkable world is the size it should be (%d cells)" % cells)
	audit.free()
	print("INTERIOR_SEALS_INTEGRATION ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
