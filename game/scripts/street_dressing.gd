class_name InteriorStreetDressing
extends RefCounted
## Ghost-town dressing for the walkable neighbourhood (run 6), built inside the neighbourhood bake:
## parked Philippine tricycles and an abandoned jeepney, empty street-food carts and stalls,
## the rusted "Malasugue Street" sign bent almost to the ground, police barricades where the
## streets leave the play area, and litter. Nobody is around.
## Every model is checked against roads, sidewalks, walls and houses the same way trees are, and
## reserves its footprint so no tree is planted through it.

const GROUND := -2.9
const SIGN_TEXTURE := "res://assets/outdoor/street/sign_malasugue.png"

var n: InteriorNeighborhoodBuilder
var b: InteriorBalconyBuilder
var placed: Array[Rect2] = []

static func build(neighbourhood: InteriorNeighborhoodBuilder) -> void:
	var d := InteriorStreetDressing.new()
	d.n = neighbourhood
	d.b = neighbourhood.b
	d._materials()
	d._vehicles()
	d._stalls()
	d._street_sign()
	d._barricades()
	d._litter()

func _materials() -> void:
	var sign := b._image("sd sign", SIGN_TEXTURE, .55)
	sign.metallic = .25
	b._flat("sd stripe yellow", Color(.95, .72, .08), .6)
	b._flat("sd stripe black", Color(.05, .05, .05), .7)
	b._flat("sd paper", Color(.82, .8, .74), .9)
	b._flat("sd plastic bag", Color(.88, .88, .86), .4)
	b._flat("sd cardboard", Color(.55, .42, .28), .9)
	b._flat("sd leaf", Color(.36, .3, .14), .9)

# ---------------------------------------------------------------- placement guard

## Places a model by its bottom centre if its footprint stays clear of houses, walls and other
## props (roads are fine for vehicles); otherwise tries nearby spots along `slide`. Returns the
## node or null.
func _place(path: String, at: Vector3, yaw: float, scale: float, slide := Vector3.ZERO, collide := true, label := "") -> Node3D:
	if not ResourceLoader.exists(InteriorModelKit.ROOT + path + ".glb"):
		push_warning("Street dressing: missing model " + path)
		return null
	for attempt in 7:
		var offset := slide * (float((attempt + 1) / 2) * (1.0 if attempt % 2 == 1 else -1.0))
		var node := InteriorModelKit.place(n.models, path, at + offset, yaw, scale, "bottom", Vector3.ZERO, label)
		var box := InteriorModelKit.bounds_in(node, n.models)
		var foot := Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(-.05)
		if _blocked(foot):
			node.free()
			continue
		placed.append(foot)
		# Trees keep their trunks out of the footprint.
		n._no_trunk.append(foot.grow(.4))
		if collide:
			InteriorModelKit.add_box_collider(n.solids, node, Vector3(.04, 0, .04), String(node.name) + " collider")
		node.set_meta("fade", 120.0)
		return node
	push_warning("Street dressing: no room for " + path + " near " + str(at))
	return null

func _blocked(foot: Rect2) -> bool:
	for r in n._no_canopy:
		# _no_canopy holds every house footprint (with overhang) and our own house.
		if r.grow(-.3).intersects(foot):
			return true
	for r in placed:
		if r.intersects(foot):
			return true
	for collision in n.solids.get_children():
		var shape := (collision as CollisionShape3D).shape as BoxShape3D
		var name := String(collision.name)
		if shape == null or not (name.begins_with("Fence") or name.begins_with("Lot gate") or name.begins_with("House") or name.begins_with("Utility")):
			continue
		var p := (collision as Node3D).position
		if Rect2(p.x - shape.size.x * .5, p.z - shape.size.z * .5, shape.size.x, shape.size.z).intersects(foot):
			return true
	return false

# ---------------------------------------------------------------- vehicles and stalls

## Tricycles parked at the kerb, nose along the street; an abandoned jeepney on street C.
func _vehicles() -> void:
	b._feature("Ghost town: parked tricycles, a jeepney, empty food stalls, the bent Malasugue Street sign, barricades")
	# [model, position, yaw degrees (model faces +Z at 0), slide direction]
	for spec: Array in [
			["street/tricycle_a", Vector3(19.85, GROUND, 11.0), 180.0, Vector3(0, 0, 1.5)],
			["street/tricycle_b", Vector3(22.15, GROUND, 27.5), 0.0, Vector3(0, 0, 1.5)],
			["street/tricycle_a", Vector3(3.5, GROUND, 16.85), 90.0, Vector3(1.5, 0, 0)],
			["street/tricycle_b", Vector3(-17.85, GROUND, 31.0), 3.0, Vector3(0, 0, 1.5)],
			["street/jeepney", Vector3(4.0, GROUND, 47.85), 88.0, Vector3(2.0, 0, 0)],
			["street/tricycle_a", Vector3(13.5, GROUND, 50.15), -86.0, Vector3(1.5, 0, 0)]]:
		_place(spec[0], spec[1], spec[2], 1.0, spec[3])

## Street-food carts and a stall, all empty: one just outside the courtyard gate, others at the kerbs.
func _stalls() -> void:
	var stall := _place("street/food_cart_b", Vector3(14.9, GROUND, 6.9), 180.0, 1.0, Vector3(.5, 0, 0))
	if stall != null:
		_place("street/plastic_monobloc_chair_01", stall.position + Vector3(-1.4, 0, -.9), 120.0, 1.0, Vector3(.3, 0, .3), false)
	var cart := _place("street/food_cart_a", Vector3(19.7, GROUND, 17.0), 90.0, 1.0, Vector3(0, 0, .8))
	if cart != null:
		_tipped_chair(cart.position + Vector3(-.2, 0, 1.6))
	_place("street/food_stall_c", Vector3(9.5, GROUND, 19.5), 180.0, 1.0, Vector3(1.0, 0, 0))
	_place("street/food_cart_a", Vector3(-3.0, GROUND, 50.6), 0.0, 1.0, Vector3(1.0, 0, 0))
	_place("street/food_cart_a", Vector3(-15.0, GROUND, 20.6), 180.0, 1.0, Vector3(1.0, 0, 0))
	_place("street/oil_drum", Vector3(16.5, GROUND, 7.1), 30.0, 1.0, Vector3(.4, 0, 0))
	_place("street/oil_drum", Vector3(21.0, GROUND, 33.4), 0.0, 1.0, Vector3(0, 0, .5))

func _tipped_chair(at: Vector3) -> void:
	var path := "street/plastic_monobloc_chair_01"
	if not ResourceLoader.exists(InteriorModelKit.ROOT + path + ".glb"):
		return
	var chair := InteriorModelKit.place(n.models, path, at, 35.0, 1.0, "bottom", Vector3(0, 0, 88.0), "Tipped chair")
	chair.set_meta("fade", 80.0)
	var box := InteriorModelKit.bounds_in(chair, n.models)
	placed.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))

# ---------------------------------------------------------------- the street sign

## A rusted green street-name sign at the lane mouth on street B, its pole snapped over so the
## plate hangs diagonally, almost touching the sidewalk.
func _street_sign() -> void:
	var base := Vector3(18.5, GROUND + .12, 7.35)
	var bend := base + Vector3(-.05, 1.62, .04)
	var u := Vector3(-.14, -.62, .77).normalized()  # down the bent arm; the text reads along it
	var tip := bend + u * 1.15
	b._rod(base + Vector3.DOWN * .1, base + Vector3(-.02, .8, .02), .032, "n rust", 10)
	b._rod(base + Vector3(-.02, .8, .02), bend, .03, "n rust", 10)
	# The kink: a short crushed section.
	b._sphere(bend, Vector3(.075, .075, .075), "n rust", 8)
	b._rod(bend, tip, .028, "n rust", 10)
	b._rod(base + Vector3.DOWN * .02, base + Vector3(0, .02, 0), .09, "n concrete", 10)
	n._no_trunk.append(Rect2(base.x - .6, base.z - .6, 1.2, 2.2))
	n.solid("Street sign pole", base + Vector3.UP * .8, Vector3(.08, 1.6, .08))
	# Plate under the arm, facing the lane (-X), long axis along the arm.
	var normal := (Vector3.LEFT - u * u.dot(Vector3.LEFT)).normalized()
	var v := normal.cross(u)
	var half_l := .52
	var half_h := .135
	var c := bend + u * .6 - v * (half_h + .03) + normal * .035
	var bl := c - u * half_l - v * half_h
	var br := c + u * half_l - v * half_h
	var tr := c + u * half_l + v * half_h
	var tl := c - u * half_l + v * half_h
	b._quad([bl, br, tr, tl], normal, "sd sign")
	# Double-sided like real street signs: the back carries the same name, readable from street B.
	var back := -normal * .008
	# Seen from behind, the plate's corners swap left and right: BL, BR, TR, TL = br, bl, tl, tr.
	b._quad([br + back, bl + back, tl + back, tr + back], -normal, "sd sign")
	for k in [-.38, .38]:
		var clamp_at: Vector3 = c + u * k + v * half_h
		b._rod(clamp_at - normal * .01, clamp_at + v * .05 - normal * .01, .012, "n rust", 6)
	solid_sign_plate(c, u, v, normal, half_l, half_h)

func solid_sign_plate(c: Vector3, u: Vector3, v: Vector3, normal: Vector3, half_l: float, half_h: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(half_l * 2.0, half_h * 2.0, .03)
	var collision := CollisionShape3D.new()
	collision.name = "Street sign plate"
	collision.shape = shape
	n.solids.add_child(collision, true)
	collision.transform = Transform3D(Basis(u, v, normal), c)

# ---------------------------------------------------------------- barricades

## Yellow-and-black police sawhorses across each street where it leaves the play area.
func _barricades() -> void:
	var area := InteriorNeighborhoodBuilder.PLAY_AREA
	for street: Array in InteriorNeighborhoodBuilder.STREETS:
		var along_x: bool = street[0] == "x"
		var centre: float = street[1]
		var w: float = street[4]
		var ends := [area.position.x + .9, area.end.x - .9] if along_x else [area.position.y + .9, area.end.y - .9]
		for e: float in ends:
			if e < float(street[2]) or e > float(street[3]):
				continue
			var mid := Vector3(e, GROUND, centre) if along_x else Vector3(centre, GROUND, e)
			var across := Vector3.BACK if along_x else Vector3.RIGHT
			var count := 4
			# Street B's north end is the way out to the rice fields (0.7): the middle sawhorses
			# were dragged aside.
			var way_out := not along_x and is_equal_approx(centre, 21.0) and e > area.get_center().y
			for k in count:
				if way_out and (k == 1 or k == 2):
					continue
				var t := (float(k) + .5) / count - .5
				var p := mid + across * t * (w - .3)
				var y := GROUND + (.12 if absf(t * w) > w * .5 - 1.0 else 0.0)
				_sawhorse(Vector3(p.x, y, p.z), across, k)

func _sawhorse(at: Vector3, across: Vector3, index: int) -> void:
	var length := 1.35
	var along := Vector3.UP.cross(across).normalized()
	for side in [-1.0, 1.0]:
		var foot: Vector3 = at + across * side * (length * .5 - .1)
		b._rod(foot + along * .28, foot + Vector3.UP * .95, .025, "sd stripe black", 6)
		b._rod(foot - along * .28, foot + Vector3.UP * .95, .025, "sd stripe black", 6)
	for y in [.88, .55]:
		var stripes := 6
		for s in stripes:
			var t0 := -length * .5 + s * length / stripes
			var centre: Vector3 = at + across * (t0 + length / stripes * .5) + Vector3.UP * y
			var basis := Basis(across, Vector3.UP, along)
			b._box("Barricade stripe", centre, Vector3(length / stripes, .16, .025), "sd stripe yellow" if (s + index) % 2 == 0 else "sd stripe black", false, basis)
	n.solid("Barricade", at + Vector3.UP * .5, (across * length + along * .5 + Vector3.UP).abs())

# ---------------------------------------------------------------- litter

func _litter() -> void:
	var rng := n.rng
	var spots := 0
	var tries := 0
	while spots < 70 and tries < 400:
		tries += 1
		var p := Vector3(rng.randf_range(-22.0, 24.0), GROUND, rng.randf_range(0.5, 53.0))
		if p.x < 12.7 and p.z < 8.6:
			continue  # our own courtyard stays tidy
		var surface := InteriorSurfaces.at(p)
		if surface != "asphalt" and surface != "concrete":
			continue
		var on_kerb := surface == "concrete"
		var y := GROUND + (.123 if on_kerb else .017)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		match rng.randi_range(0, 4):
			0, 1:
				b._box("Newspaper", Vector3(p.x, y + .002, p.z), Vector3(rng.randf_range(.25, .45), .004, rng.randf_range(.2, .35)), "sd paper", false, basis * Basis(Vector3.RIGHT, rng.randf_range(-.08, .08)))
			2:
				b._sphere(Vector3(p.x, y + .06, p.z), Vector3(.22, .12, .18), "sd plastic bag", 7)
			3:
				b._box("Flattened box", Vector3(p.x, y + .005, p.z), Vector3(.5, .01, .38), "sd cardboard", false, basis)
			_:
				for k in 6:
					var q := p + Vector3(rng.randf_range(-.6, .6), 0, rng.randf_range(-.6, .6))
					b._box("Dry leaf", Vector3(q.x, y + .003, q.z), Vector3(.09, .003, .05), "sd leaf", false, Basis(Vector3.UP, rng.randf() * TAU))
		spots += 1
