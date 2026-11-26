# Source index

Generated from the current working files. Line numbers are for this snapshot; hashes identify it.
## game/scripts/interior.gd

SHA-256: `92358bdfd7569c45d2772881460e2902c51c76be0bfc7e3c3ee813ca2dcc712f`

- L3: `const PlayerScript = preload("res://scripts/player.gd")`
- L4: `const RoomBuilder = preload("res://scripts/room_builder.gd")`
- L5: `const BAKED_ROOM := "res://scenes/room/living_room.tscn"`
- L6: `const ObjectScript = preload("res://scripts/physics_object.gd")`
- L7: `const TouchScript = preload("res://scripts/mobile_controls.gd")`
- L8: `const RoomAudioScript = preload("res://scripts/room_audio.gd")`
- L9: `const PropColliders = preload("res://scripts/prop_colliders.gd")`
- L10: `const RoomVisuals = preload("res://scripts/room_visuals.gd")`
- L11: `const EnclosureScript = preload("res://scripts/hamster_enclosure.gd")`
- L12: `const AquariumScript = preload("res://scripts/aquarium.gd")`
- L13: `const RoomSurroundings = preload("res://scripts/room_surroundings.gd")`
- L14: `const NightAudioScript = preload("res://scripts/night_audio.gd")`
- L15: `const StrangerScript = preload("res://scripts/stranger.gd")`
- L16: `const StoryScript = preload("res://scripts/story.gd")`
- L17: `const AtmosphereScript = preload("res://scripts/atmosphere.gd")`
- L18: `const AtmosphereParticlesScript = preload("res://scripts/atmosphere_particles.gd")`
- L56: `func _ready() -> void:`
- L157: `func _setup_inputs() -> void:`
- L187: `func _mat(color: Color) -> StandardMaterial3D:`
- L193: `func _box(parent: Node3D, location: Vector3, dimensions: Vector3, color: Color, collide := true) -> MeshInstance3D:`
- L210: `func _vector(values: Array) -> Vector3:`
- L213: `func _build_living_room() -> bool:`
- L236: `func _setup_living_props() -> void:`
- L249: `func _on_locked_room_door() -> void:`
- L253: `func _build_control_test_room() -> void:`
- L310: `func _build_ui() -> void:`
- L436: `func _label(text: String, font_size: int) -> Label:`
- L442: `func _button(text: String, callable: Callable) -> Button:`
- L450: `func _show_menu(kind: String) -> void:`
- L522: `func _focus_menu() -> void:`
- L529: `func _layout_menu() -> void:`
- L539: `func _home_button(text: String, callback: Callable) -> void:`
- L554: `func _build_options() -> void:`
- L577: `func _play() -> void:`
- L591: `func _restart() -> void:`
- L595: `func _apply_quality(index: int) -> void:`
- L621: `func _notification(what: int) -> void:`
- L634: `func _on_grabbed(body: InteriorObject) -> void:`
- L644: `func _on_target_changed(body: InteriorObject) -> void:`
- L665: `func _show_console() -> void:`
- L684: `func try_unlock(code: String) -> String:`
- L693: `func _capture_control_lab() -> void:`
- L715: `func _capture_review() -> void:`
- L814: `const BALCONY_VIEWS := [`
- L823: `func _capture_neighborhood_views(directory: String) -> void:`
- L859: `func _capture_balcony_views(directory: String) -> void:`
- L879: `func _capture_hut_views(directory: String) -> void:`
- L953: `func _capture_canal_views(directory: String) -> void:`
- L982: `func _capture_siege_views(directory: String) -> void:`
- L1021: `func _capture_nichols_views(directory: String) -> void:`
- L1057: `func _capture_basement_views(directory: String) -> void:`
- L1107: `func _capture_warren_views(directory: String) -> void:`
- L1138: `func _capture_debug_views(directory: String) -> void:`
- L1162: `func _capture_eye(eye: Vector3, at: Vector3) -> void:`
- L1169: `func _capture_gun_views(directory: String) -> void:`
- L1234: `func _gun_look(eye: Vector3, at: Vector3) -> void:`
- L1242: `func _save_review_image(directory: String, label: String) -> void:`
- L1248: `func _unhandled_input(event: InputEvent) -> void:`
- L1264: `func _process(delta: float) -> void:`
- L1307: `func entry_door() -> InteriorHingedDoor:`
## game/scripts/room_builder.gd

SHA-256: `9407cc9be4c478e165702bc0400b09d9b73cba85d1270c07f22236070f9c23eb`

- L8: `const ObjectScript = preload("res://scripts/physics_object.gd")`
- L9: `const PropColliders = preload("res://scripts/prop_colliders.gd")`
- L10: `const PropPhysics = preload("res://scripts/prop_physics.gd")`
- L11: `const RoomVisuals = preload("res://scripts/room_visuals.gd")`
- L12: `const EnclosureScript = preload("res://scripts/hamster_enclosure.gd")`
- L13: `const AquariumScript = preload("res://scripts/aquarium.gd")`
- L14: `const RoomSurroundings = preload("res://scripts/room_surroundings.gd")`
- L15: `const MANIFEST_PATH := "res://assets/room_manifest.json"`
- L17: `static func load_manifest() -> Dictionary:`
- L24: `static func _vector(values: Array) -> Vector3:`
- L29: `static func build(room: Node3D) -> Dictionary:`
## game/scripts/room_surroundings.gd

SHA-256: `97f0c35c6ea1558351153b49cf20c5d2668920c5fa00691841ebb4d534766408`

- L6: `const ObjectScript = preload("res://scripts/physics_object.gd")`
- L7: `const DoorScript = preload("res://scripts/hinged_door.gd")`
- L10: `const ENTRY_HINGE := Vector3(2.43, 0, 2.6335)`
- L11: `const DOOR_PREFIX := "door|"`
- L12: `const TOY_BALL := Vector3(-1.05, .112, 1.05)`
- L13: `const TOY_TENNIS := Vector3(-.62, .036, 1.28)`
- L14: `const REPLACED_COLLIDERS := ["Left wall", "Right wall", "Rear wall", "Ceiling"]`
- L22: `static func apply(room: Node3D, visual: Node3D, _manifest: Dictionary) -> Dictionary:`
- L45: `func _strip_old_shell(visual: Node3D) -> void:`
- L91: `func _build() -> void:`
- L136: `func _build_entry_door() -> AnimatableBody3D:`
- L161: `func _build_rear_mirrored() -> void:`
- L201: `func _prepare_materials() -> void:`
- L252: `func _material(key: String, color: Color, roughness: float, texture := "") -> StandardMaterial3D:`
- L272: `func _feature(label: String) -> void:`
- L275: `func _builder(base_key: String) -> SurfaceTool:`
- L283: `func _quad(points: Array, normal: Vector3, key: String, uv := Vector2.ONE) -> void:`
- L292: `func _box(label: String, center: Vector3, size: Vector3, key: String, collide := false, basis := Basis.IDENTITY) -> void:`
- L301: `func _collider(label: String, center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:`
- L312: `func _rod(a: Vector3, b: Vector3, radius: float, key: String, sides := 8, top_radius := -1.0) -> void:`
- L336: `func _tube(points: Array, radius: float, key: String, sides := 7) -> void:`
- L340: `func _lathe(center: Vector3, profile: Array, key: String, sides := 20, basis := Basis.IDENTITY) -> void:`
- L353: `func _sphere(center: Vector3, size: Vector3, key: String, segments := 12) -> void:`
- L360: `func _frame(center: Vector3, width: float, height: float, photo: int, facing: Basis) -> void:`
- L367: `func _build_shell() -> void:`
- L399: `func _build_kitchen() -> void:`
- L473: `func _counter_bottle(p: Vector3, variant: int) -> void:`
- L479: `func _loose_kitchen_prop(label: String, p: Vector3, mass: float, size: Vector3, key: String, cup: bool) -> void:`
- L525: `func _build_rear() -> void:`
- L561: `func _build_right() -> void:`
- L588: `func _curtain(origin: Vector3, width: float, height: float, key: String, along_z: bool) -> void:`
- L606: `func _rack(p: Vector3, size: Vector3, key: String, shelves: int) -> void:`
- L612: `func _basket(p: Vector3, size: Vector3, key: String) -> void:`
- L625: `func _flower_mat(p: Vector3, radius: float) -> void:`
- L633: `func _lathe_mesh(profile: Array, sides := 24) -> ArrayMesh:`
- L653: `func _toy_body(label: String, p: Vector3, mass: float, mesh: Mesh, key: String, shapes: Array, material_hint: String, rolls: bool) -> InteriorObject:`
- L683: `func _sphere_toy(label: String, p: Vector3, radius: float, mass: float, key: String, hint: String) -> void:`
- L693: `func _build_toys() -> void:`
## game/scripts/room_furnishings.gd

SHA-256: `07c38ab1a90514875aa80b2e8bcac60b79106292f3ba1adf8dc93e99f4cc0df9`

- L3: `const LockedDoor = preload("res://scripts/locked_room_door.gd")`
- L5: `static func apply(room: Node3D) -> void:`
- L24: `static func _pillow(body: InteriorObject) -> void:`
- L78: `static func _pillow_point(uv: Vector2, side: float) -> Vector3:`
- L86: `static func _box(parent: Node3D, label: String, center: Vector3, size: Vector3, material: Material) -> void:`
- L96: `static func _door(room: Node3D) -> void:`
## game/scripts/balcony_builder.gd

SHA-256: `eaa4a1f83aaebb2abcdde21d01210447d0e1100bbca1c229dc14df6c0937b9e1`

- L14: `const BalconyScript = preload("res://scripts/balcony.gd")`
- L15: `const PetSpawnerScript = preload("res://scripts/pet_spawner.gd")`
- L16: `const OUTDOOR_LAYER := 2`
- L18: `const PROP_LAYERS := 3`
- L19: `const X0 := .95`
- L20: `const X_END := 5.6`
- L21: `const Z_WALL := 2.9`
- L22: `const Z_LEDGE := 4.55`
- L23: `const Z_OUT := 4.75`
- L24: `const CEIL := 2.75`
- L25: `const STAIR_Z := 3.85`
- L26: `const RISERS := 16`
- L27: `const RISE := 2.9 / 16.0`
- L28: `const TREAD := .27`
- L29: `const GROUND := -2.9`
- L30: `const YARD_X := 9.65`
- L31: `const FENCE_X := 12.6`
- L32: `const YARD_Z := 5.3`
- L40: `static func build(root: Node3D) -> Dictionary:`
- L51: `func _build_all() -> void:`
- L70: `func _prepare_balcony_materials() -> void:`
- L138: `func _lib(key: String, library_key: String, tint: Color) -> void:`
- L145: `func _flat(key: String, color: Color, roughness: float) -> StandardMaterial3D:`
- L153: `func _image(key: String, path: String, roughness: float) -> StandardMaterial3D:`
- L164: `func _pbr(key: String, id: String, tile: float, tint := Color(1, 1, 1), roughness := 1.0, normal := 1.0) -> StandardMaterial3D:`
- L185: `func _static_body(label: String, at: Vector3, yaw := 0.0) -> StaticBody3D:`
- L199: `func _begin_prop(label: String, at: Vector3, yaw := 0.0) -> StaticBody3D:`
- L206: `func _end_prop() -> void:`
- L212: `func _commit(parent: Node3D, prefix: String) -> void:`
- L227: `func _plate(points: Array, key: String) -> void:`
- L233: `func _ring(center: Vector3, radius: float, key: String, axis_basis: Basis, thickness := .006, segments := 14) -> void:`
- L242: `func _build_balcony_shell() -> void:`
- L253: `func _build_end_wall() -> void:`
- L272: `func _sign(center: Vector3, width: float, height: float, key: String) -> void:`
- L278: `func _build_house_wall() -> void:`
- L304: `func _window(center: Vector3, width: float, height: float) -> void:`
- L315: `func _build_railing() -> void:`
- L343: `func _build_stair() -> void:`
- L379: `func _build_courtyard() -> void:`
- L413: `const GATE_MID := 4.1`
- L414: `const PushGateScript = preload("res://scripts/push_gate.gd")`
- L416: `func _build_gate() -> void:`
- L472: `const MOON_DIRECTION := InteriorNight.MOON_DIRECTION`
- L474: `func _build_neighbourhood() -> void:`
- L478: `func _wire(a: Vector3, b: Vector3, sag: float) -> void:`
- L487: `func _build_bounds() -> void:`
- L501: `func _build_props() -> void:`
- L520: `func _shoe_rack() -> void:`
- L544: `func _flower_vase() -> void:`
- L556: `func _aquarium() -> void:`
- L583: `func _ring_planter(label: String, at: Vector3, yaw: float) -> void:`
- L599: `func _greenery_panel() -> void:`
- L621: `func _plant_print() -> void:`
- L630: `func _rattan_chair(label: String, at: Vector3, yaw: float) -> void:`
- L645: `func _blue_bottle() -> void:`
- L685: `func _ladder() -> void:`
- L698: `func _covered_cabinet() -> void:`
- L704: `func _plank_stack() -> void:`
- L713: `func _build_lights() -> void:`
- L769: `func _lamp_glow(label: String, at: Vector3, color: Color, radius: float) -> void:`
## game/scripts/balcony.gd

SHA-256: `41a993ee43037e2832382a059e85f8ab5fc36a1cf557c362cdfaee718f3307be`

- L8: `const OUTDOOR_LAYER := 2`
- L19: `func _ready() -> void:`
- L25: `func _setup_night_lamps() -> void:`
- L45: `func _sync_lenses() -> void:`
- L52: `func _street_flicker(lamp: Light3D, delta: float) -> float:`
- L74: `func _mask_room_lights() -> void:`
- L83: `func sun() -> DirectionalLight3D:`
- L88: `func _update_visibility() -> void:`
- L104: `func _flicker(delta: float) -> void:`
- L125: `func _process(delta: float) -> void:`
## game/scripts/studio_builder.gd

SHA-256: `2c82ca9655133be9e13f3790794f9bb18c7803bd18342b013e2745f890cc9a0b`

- L12: `const StudioScript = preload("res://scripts/studio.gd")`
- L13: `const SlidingDoorScript = preload("res://scripts/sliding_door.gd")`
- L14: `const SX0 := -5.65`
- L15: `const SX1 := -1.25`
- L16: `const SZ0 := 2.9`
- L17: `const SZ1 := 7.3`
- L18: `const SH := 2.9`
- L19: `const FOAM := .05`
- L20: `const DOOR_X0 := -3.25`
- L21: `const DOOR_X1 := -1.24`
- L22: `const DOOR_H := 2.4`
- L23: `const DESK := Vector3(-2.6, 0, 6.745)`
- L24: `const DESK_TOP := .692`
- L26: `static func build(root: Node3D) -> Dictionary:`
- L38: `func _build_all() -> void:`
- L56: `func _prepare_studio_materials() -> void:`
- L109: `func _build_shell() -> void:`
- L140: `func _foam_wall(origin: Vector3, right: Vector3, normal: Vector3, width: float, height: float, up := Vector3.UP, skip := Rect2()) -> void:`
- L155: `func _foam_tile(corner: Vector3, right: Vector3, up: Vector3, normal: Vector3, vertical: bool, key: String) -> void:`
- L174: `func _tri_quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, key: String, hint: Vector3) -> void:`
- L179: `func _tri(p0: Vector3, p1: Vector3, p2: Vector3, key: String, hint: Vector3) -> void:`
- L193: `func _build_foam() -> void:`
- L210: `func _build_led_cove() -> void:`
- L222: `func _hanger(at: Vector3) -> void:`
- L230: `func _build_fixed_glass() -> void:`
- L236: `func _glass_panel(origin: Vector3, width: float, height: float, handle: bool) -> void:`
- L251: `func _build_door() -> void:`
- L283: `func _model(label: String, path: String, at: Vector3, yaw := 0.0, scale := 1.0, anchor := "bottom", tilt := Vector3.ZERO, collide := true, inset := Vector3.ZERO) -> Node3D:`
- L293: `func _build_furniture() -> void:`
- L313: `func _build_instruments() -> void:`
- L354: `func _build_desk() -> void:`
- L388: `func _build_studio_lights() -> void:`
## game/scripts/studio.gd

SHA-256: `201b4523513369dc3f124bad9ce8e8caa4308258cdd9e80a736c6cf0ebb2cebe`

- L10: `func _ready() -> void:`
- L18: `func _process(delta: float) -> void:`
- L39: `func _light_screen(model: Node, kind: String) -> void:`
- L54: `static func _screen_image(kind: String) -> Image:`
## game/scripts/neighborhood_builder.gd

SHA-256: `4ed86c8047ae52b5a107b0bd711a6d9e829517f786f9fb02771e5304cf5872da`

- L12: `const NeighborhoodScript = preload("res://scripts/neighborhood.gd")`
- L13: `const GROUND := -2.9`
- L14: `const STOREY := 2.95`
- L17: `const STREETS := [["x", 18.0, -70.0, 80.0, 6.0], ["z", 21.0, -40.0, 54.5, 6.0], ["x", 49.0, -70.0, 80.0, 6.0], ["z", -19.0, -40.0, 66.0, 6.0]]`
- L19: `const ROWS := [`
- L33: `const WALL_COLOURS := [Color(.95, .92, .84), Color(.86, .93, .86), Color(.97, .84, .74), Color(.80, .88, .95), Color(.94, .90, .70),`
- L35: `const ROOF_COLOURS := [Color(.62, .18, .14), Color(.20, .38, .56), Color(.24, .44, .30), Color(.55, .55, .56), Color(.42, .24, .16)]`
- L56: `const PLAY_AREA := Rect2(-24.0, -18.0, 50.0, 73.0)`
- L58: `static func build(builder: InteriorBalconyBuilder, parent: Node3D, sun_direction: Vector3) -> Dictionary:`
- L101: `func _materials() -> void:`
- L161: `func _ground() -> void:`
- L170: `func _streets() -> void:`
- L196: `func _lots() -> void:`
- L213: `func _lot(along_x: bool, line: float, start: float, frontage: float, facing: int, depth: float, max_storeys: int) -> void:`
- L266: `func _sized(basis: Basis, size: Vector3) -> Vector3:`
- L270: `func _wall_segment(a: Vector3, c: Vector3, height: float, key: String) -> void:`
- L282: `func _gate(a: Vector3, c: Vector3, height: float) -> void:`
- L299: `func _house(centre: Vector3, basis: Basis, w: float, d: float, storeys: int) -> void:`
- L362: `func _window(to_world: Callable, basis: Basis, local: Vector3, ww: float, wh: float, frame: String, face: int) -> void:`
- L379: `func _side_window(to_world: Callable, basis: Basis, local: Vector3, frame: String, side: float) -> void:`
- L384: `func _door(to_world: Callable, basis: Basis, local: Vector3, frame: String, style: int) -> void:`
- L395: `func _gable_roof(to_world: Callable, basis: Basis, w: float, d: float, top: float, key: String, gable_key: String) -> void:`
- L427: `func _hip_roof(to_world: Callable, basis: Basis, w: float, d: float, top: float, key: String) -> void:`
- L445: `func _flat_roof(to_world: Callable, basis: Basis, w: float, d: float, top: float, wall: String, unfinished: bool) -> void:`
- L468: `func _our_house_shell() -> void:`
- L476: `func _model(path: String, at: Vector3, yaw: float, scale: float, fade := 0.0) -> Node3D:`
- L482: `func _want(at: Vector3, kind: String, scale: float, search: float) -> void:`
- L485: `func _plant() -> void:`
- L513: `func _hits_point(rects: Array[Rect2], p: Vector3, margin: float) -> bool:`
- L519: `func _hits_rect(rects: Array[Rect2], crown: Rect2) -> bool:`
- L526: `func _crowded(crown: Rect2) -> bool:`
- L534: `func _hero_trees() -> void:`
- L564: `func _poles() -> void:`
- L599: `func _street_lamp(base: Vector3, toward: Vector3, height: float, state: String) -> void:`
- L626: `func _wire(a: Vector3, c: Vector3, sag: float) -> void:`
- L635: `func _sky(_moon_direction: Vector3) -> void:`
- L655: `func solid(label: String, center: Vector3, size: Vector3) -> CollisionShape3D:`
- L668: `func _curb_collider(center: Vector3, size: Vector3, along_x: bool) -> void:`
- L690: `func _near_play_area(center: Vector3, size: Vector3) -> bool:`
- L693: `func _trunk_collider(spot: Vector3, kind: String, scale: float) -> void:`
- L715: `func _play_bounds() -> void:`
## game/scripts/neighborhood.gd

SHA-256: `1082079109eb181397353a6b9f0254eac0622494f3b2402feb641c0a84d06f02`

- L18: `const OUTDOOR_LAYER := 2`
- L19: `const FAR := 900.0`
- L20: `const MIST_SHADER := preload("res://scripts/night_mist.gdshader")`
- L21: `const MIST_SIZE := Vector3(180.0, 5.0, 180.0)`
- L22: `const GROUND_Y := -2.9`
- L23: `const WEATHERING := preload("res://scripts/neighborhood_weathering.gd")`
- L24: `const STREET_DECAY := preload("res://scripts/neighborhood_ground.gd")`
- L25: `const DERELICT := preload("res://scripts/neighborhood_derelict.gd")`
- L39: `func _ready() -> void:`
- L73: `func _install_interactions() -> void:`
- L108: `func _darken_windows() -> void:`
- L122: `func _process(delta: float) -> void:`
- L162: `func _environment() -> Environment:`
- L170: `func _apply_fog(on: bool) -> void:`
- L190: `func _apply_outdoors(on: bool) -> void:`
- L205: `func _blend_grade() -> void:`
- L241: `func refresh_quality() -> void:`
- L251: `func _update_zone(weight: float) -> void:`
- L267: `func _set_mist(on: bool) -> void:`
## game/scripts/neighborhood_interactions.gd

SHA-256: `230ab616fbff85d7ff67e5143f6fa6bb6bdd78305d8178f555c12d3a036e9d9d`

- L3: `const Usable := preload("res://scripts/neighborhood_usable.gd")`
- L4: `const Encounters := preload("res://scripts/neighborhood_encounters.gd")`
- L13: `func build(town: Node3D) -> void:`
- L43: `func _material(texture: String, tint: Color, metal: float) -> StandardMaterial3D:`
- L59: `func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:`
- L71: `func _collision(parent: Node3D, at: Vector3, size: Vector3, movable := false) -> PhysicsBody3D:`
- L84: `func _make_gate(bounds: AABB) -> void:`
- L129: `func _extract_gates(instance: MeshInstance3D) -> void:`
- L153: `func _find_doors(instance: MeshInstance3D, houses: Array[AABB], controller: Node) -> void:`
- L178: `func _make_door(point: Vector3, normal: Vector3, controller: Node) -> void:`
## game/scripts/neighborhood_usable.gd

SHA-256: `923dd413a974e134c9f315593ceb04011f2c89513d2c212948e2666497a544f5`

- L9: `func _ready() -> void:`
- L13: `func prompt_text() -> String:`
- L21: `func toggle() -> void:`
- L29: `func _process(delta: float) -> void:`
## game/scripts/neighborhood_encounters.gd

SHA-256: `5b3a2e7332a0910f9b046c3e21fdad1748b21f71be6483cc28c9bff0d84905a1`

- L3: `const LINES := ["I guess no one's home..", "Hello? ...Anyone there?", "Locked. No answer, either.",`
- L6: `const ZONES := [Vector3(20.5, -2.9, 10.5), Vector3(-8, -2.9, 18), Vector3(21, -2.9, 39)]`
- L8: `const PSST_APPROACH := Rect2(18.0, 5.5, 6.0, 11.0)`
- L9: `const PSST_SOURCE := Vector3(23.4, -1.45, 10.5)`
- L35: `func _ready() -> void:`
- L53: `func _voice(label: String, reach: float) -> AudioStreamPlayer3D:`
- L62: `func _resolve() -> bool:`
- L69: `func _outside() -> bool:`
- L75: `func use_object(object: Node3D) -> bool:`
- L97: `func within_knocking_reach(object: Node3D) -> bool:`
- L101: `func _contact_point(object: Node3D) -> Vector3:`
- L107: `func _reset_hand_pose() -> void:`
- L113: `func _place_hand(object: Node3D) -> void:`
- L122: `func _update_hand_pose() -> void:`
- L133: `func _process(delta: float) -> void:`
- L160: `func trigger_zone(index: int) -> bool:`
- L173: `func _start_steps() -> void:`
- L183: `func _update_steps(delta: float) -> void:`
- L196: `func _update_action(delta: float) -> void:`
- L236: `func _cancel_action() -> void:`
- L248: `func _ensure_arms() -> void:`
- L276: `func _play(voice: AudioStreamPlayer3D, stream: AudioStream, db: float, pitch: float) -> void:`
- L282: `func _synthesize(kind: String, duration: float) -> AudioStreamWAV:`
## game/scripts/street_dressing.gd

SHA-256: `43dcfa2372a86a496153a4b4727154aef38d45d526d86082b8a8044e49f4a510`

- L10: `const GROUND := -2.9`
- L11: `const SIGN_TEXTURE := "res://assets/outdoor/street/sign_malasugue.png"`
- L17: `static func build(neighbourhood: InteriorNeighborhoodBuilder) -> void:`
- L28: `func _materials() -> void:`
- L44: `func _place(path: String, at: Vector3, yaw: float, scale: float, slide := Vector3.ZERO, collide := true, label := "") -> Node3D:`
- L66: `func _blocked(foot: Rect2) -> bool:`
- L87: `func _vehicles() -> void:`
- L100: `func _stalls() -> void:`
- L113: `func _tipped_chair(at: Vector3) -> void:`
- L126: `func _street_sign() -> void:`
- L159: `func solid_sign_plate(c: Vector3, u: Vector3, v: Vector3, normal: Vector3, half_l: float, half_h: float) -> void:`
- L171: `func _barricades() -> void:`
- L195: `func _sawhorse(at: Vector3, across: Vector3, index: int) -> void:`
- L213: `func _litter() -> void:`
## game/scripts/town_siege.gd

SHA-256: `4cfb741e3a2b74e2da15af77ac514c0fe11e3f52d3139b017dbe190ded590f42`

- L19: `const GROUND := -2.9`
- L20: `const OUTDOOR_LAYER := 2`
- L23: `const NORTH_Z := 54.8`
- L24: `const EAST_X := 25.8`
- L25: `const SOUTH_Z := -18.55`
- L26: `const WEST_X := -23.85`
- L28: `const HOLE_X := 21.32`
- L29: `const HOLE_WIDTH := .95`
- L30: `const HOLE_HEIGHT := 1.3        # crouching (1.0 m capsule) fits, standing (1.7 m) does not`
- L32: `const STRANGER_WAIT := Vector3(21.32, GROUND, 53.35)`
- L33: `const STRANGER_OUT := Vector3(21.32, GROUND, 56.6)  # through the hole, standing again on the dirt road`
- L35: `const INNER_Z := 8.95`
- L36: `const INNER_TO_X := -7.6`
- L38: `const PASSAGE_Z := Vector2(15.15, 20.85)`
- L40: `const SECRET_X := 19.35`
- L41: `const SECRET_WIDTH := .9`
- L43: `const PATH_Z := 18.15`
- L44: `const PATH_FROM_X := 16.6`
- L45: `const PATH_TO_X := -23.2`
- L46: `const SHEETS_TEX := "res://assets/outdoor/textures/"`
- L47: `const SIEGE := "res://assets/siege/"`
- L48: `const AUDIO := "res://assets/audio/siege/"`
- L49: `const HORROR := preload("res://scripts/town_horror.gd")`
- L80: `static func outward(run: String) -> Vector3:`
- L88: `static func inside(at: Vector3) -> bool:`
- L91: `func build(parent_town: Node3D) -> void:`
- L130: `func _survey() -> void:`
- L147: `func _house_at(p: Vector2, along: Vector2, half: float) -> bool:`
- L155: `func _thin_near(p: Vector2, along: Vector2, half: float) -> bool:`
- L163: `func _materials() -> void:`
- L185: `func _sheet_tool(at: Vector3) -> SurfaceTool:`
- L195: `func sheet(origin: Vector3, right: Vector3, up: Vector3, normal: Vector3, width: float, height: float, colour: Color,`
- L233: `func _sheet_colour(rusty := -1.0) -> Color:`
- L240: `func _commit_sheets() -> void:`
- L253: `func _solid(label: String, p: Vector3, size: Vector3, surface := "metal", basis := Basis.IDENTITY) -> CollisionShape3D:`
- L268: `func _perimeter() -> void:`
- L283: `func _run(label: String, a: Vector2, c: Vector2, gaps: Array) -> void:`
- L326: `func _wall_collider(label: String, a: Vector2, along: Vector2, t0: float, t1: float, out3: Vector3) -> void:`
- L333: `func _wall_bay(label: String, start: Vector2, along: Vector3, out3: Vector3, w: float, push: float, index: int) -> void:`
- L374: `func _post(at: Vector3, out3: Vector3, index: int) -> void:`
- L397: `func _rails(label: String, a: Vector2, c: Vector2, out3: Vector3, gaps: Array) -> void:`
- L437: `func _barbed(a: Vector3, c: Vector3, sag: float) -> void:`
- L455: `func _tyre(at: Vector3, flat: bool) -> void:`
- L459: `func _sandbag(at: Vector3, along: Vector3) -> void:`
- L468: `func _hole() -> void:`
- L503: `func _secret() -> void:`
- L534: `func _passage() -> void:`
- L567: `func _lot_fences() -> void:`
- L605: `func _survivor_path() -> void:`
- L637: `func _pallet(at: Vector3, basis: Basis, index: int) -> void:`
- L664: `func _cable(a: Vector3, c: Vector3, sag: float) -> void:`
- L672: `func _bulb(at: Vector3, index: int, colour: Color, reach: float, energy: float, flicker: float) -> void:`
- L709: `func _setup_audio() -> void:`
- L743: `func _process(delta: float) -> void:`
- L772: `func _main_scene() -> Node:`
- L778: `func _knock(player: Node3D) -> void:`
- L799: `func _groan(player: Node3D) -> void:`
- L819: `func _crouch_hint(main: Node, player: Node3D) -> void:`
## game/scripts/town_horror.gd

SHA-256: `ddfe90bb3e9511f7d4bdd3051a572890725324b89ec611782ee2787e9ad69bb7`

- L15: `const GROUND := -2.9`
- L16: `const LAYER := 2`
- L17: `const SIEGE := "res://assets/siege/"`
- L18: `const NICHOLS_BLOOD := "res://assets/nichols/blood/"`
- L19: `const MODELS := "res://assets/models/"`
- L20: `const FLIES := "res://assets/audio/nichols/flies.ogg"`
- L21: `const HorrorLiquid := preload("res://scripts/horror_liquid.gd")`
- L33: `func build(siege: InteriorTownSiege) -> void:`
- L52: `func _materials() -> void:`
- L96: `func _model(file: String, at: Vector3, yaw: float, scale := 1.0, label := "", tilt := Vector3.ZERO, solid := false) -> Node3D:`
- L107: `func _texture_set(kind: String) -> Array:`
- L119: `func decal(kind: String, at: Vector3, along: Vector3, up: Vector3, size: Vector3, alpha := 1.0, fade := 34.0) -> Decal:`
- L144: `func wall_decal(kind: String, at: Vector3, n: Vector3, width: float, height: float, alpha := 1.0) -> Decal:`
- L148: `func ground_decal(kind: String, at: Vector3, along: Vector3, length: float, width: float, alpha := 1.0) -> Decal:`
- L152: `func trail(points: Array, width := .62, start_pool := true, alpha := .95) -> void:`
- L174: `func covered_body(at: Vector3, yaw: float, cover := "sheet white", stain := .8, flies := true, candles := false) -> void:`
- L274: `func _body_height(x: float, z: float) -> float:`
- L292: `func _bodies() -> void:`
- L305: `func _camp() -> void:`
- L357: `func _line(a: Vector3, c: Vector3, items: int) -> void:`
- L383: `func _checkpoint() -> void:`
- L428: `func _bunting() -> void:`
- L445: `func _flags(a: Vector3, c: Vector3, sag: float, across: bool) -> void:`
- L475: `func _tyre_fire() -> void:`
- L489: `func _reinforcements() -> void:`
- L513: `func _belongings() -> void:`
- L535: `func _on_pavement(p: Vector3) -> bool:`
- L541: `func ground_y(p: Vector3) -> float:`
- L569: `func _slipper(at: Vector3, yaw: float, key: String) -> void:`
- L580: `func _umbrella(at: Vector3, yaw: float) -> void:`
- L587: `func _creatures() -> void:`
- L600: `func _ground_marks() -> void:`
- L630: `func _late() -> void:`
- L638: `func _place_late() -> void:`
- L648: `func _wall_hit(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:`
- L657: `func _wall_splatter(space: PhysicsDirectSpaceState3D) -> void:`
- L694: `func _near_home(p: Vector3) -> bool:`
- L699: `func _route_arrows(space: PhysicsDirectSpaceState3D) -> void:`
- L714: `func _door_marks(space: PhysicsDirectSpaceState3D) -> void:`
- L733: `func _gate_trails() -> void:`
- L755: `func _process(delta: float) -> void:`
## game/scripts/canal_settlement.gd

SHA-256: `8898c35a0df5ae8186d00ce3996c5daa3fb8bc919ce52c06879ff1d74a45ab8d`

- L11: `const FLOOR := -2.10        # bank top: the lanes and the house floors`
- L12: `const CATWALK := -4.40      # catwalk deck`
- L13: `const WATER := -6.00`
- L14: `const BED := -6.55`
- L15: `const PATH := -5.45         # the far-bank footpath`
- L16: `const Z_SOUTH := -16.0`
- L17: `const Z_NORTH := 70.0`
- L18: `const WALL_U := 5.6         # east bank edge`
- L19: `const CAT_IN := 5.58        # catwalk deck spans u CAT_OUT..CAT_IN`
- L20: `const CAT_OUT := 3.72`
- L21: `const CAT_END := 50.0       # the catwalk climbs to the bridge from here`
- L22: `const STAIR_Z := 22.2       # trench stair from the lane down to the catwalk`
- L23: `const BRIDGE_Z := 60.2`
- L24: `const BRIDGE_HALF := 2.2`
- L25: `const FOOT_Z := -9.0        # plank footbridge to the far bank`
- L26: `const LANE_U := 12.9        # lane between the river houses and the lane houses`
- L27: `const BACK_U := 16.9`
- L28: `const KIT := "res://assets/models/canal/kit/"`
- L29: `const WARREN := preload("res://scripts/canal_warren.gd")`
- L30: `const TAGS := "res://assets/outdoor/canal/tags/"`
- L48: `static func rx(z: float) -> float:`
- L51: `static func rslope(z: float) -> float:`
- L54: `static func at(u: float, y: float, z: float) -> Vector3:`
- L58: `static func east_basis(z: float) -> Basis:`
- L62: `static func west_basis(z: float) -> Basis:`
- L67: `static func path_y(z: float) -> float:`
- L70: `static func stair_y(u: float) -> float:`
- L73: `func ground(u: float, z: float) -> float:`
- L115: `func build(town: Node3D) -> void:`
- L177: `func _materials() -> void:`
- L272: `func _kit_material(key: String) -> Material:`
- L279: `func _decal_material(tag: String, mirrored := false) -> Material:`
- L297: `func _solid(label: String, p: Vector3, size: Vector3, surface := "wood", basis := Basis.IDENTITY) -> CollisionShape3D:`
- L310: `func _box(label: String, p: Vector3, size: Vector3, mat: String, solid := false, surface := "wood", basis := Basis.IDENTITY) -> void:`
- L315: `func _beam(label: String, a: Vector3, c: Vector3, width: float, thick: float, mat: String, solid := false, surface := "wood") -> void:`
- L323: `func _ramp(label: String, a: Vector3, c: Vector3, width: float, surface: String) -> void:`
- L330: `func _decal(p: Vector3, normal: Vector3, width: float, tag := "") -> void:`
- L343: `func _model(path: String, p: Vector3, scale: float, yaw: float, label: String, collision := false, tilt := Vector3.ZERO) -> Node3D:`
- L356: `func _kit(name_: String, p: Vector3, basis: Basis, _label: String) -> void:`
- L373: `func _kit_parts(path: String) -> Array:`
- L389: `func _commit_kit() -> void:`
- L402: `func _bind(node: Node) -> void:`
- L413: `func _wire(a: Vector3, c: Vector3, sag: float, radius := .008) -> void:`
- L423: `func _terrain() -> void:`
- L502: `func _dedupe(values: Array[float]) -> Array[float]:`
- L508: `func _water() -> void:`
- L531: `func _catwalk() -> void:`
- L594: `func _stairs() -> void:`
- L637: `func _footbridge() -> void:`
- L663: `func _road_bridge() -> void:`
- L699: `func _headwalls() -> void:`
- L737: `func _houses() -> void:`
- L780: `func _place_house(spec: Dictionary, p: Vector3, basis: Basis, label: String) -> void:`
- L790: `func _lane() -> void:`
- L878: `func _lane_details() -> void:`
- L909: `func _hanging_wires_over_river() -> void:`
- L921: `func _wall_dressing() -> void:`
- L948: `func _vine(p: Vector3, out: Vector3) -> void:`
- L965: `func _rubbish() -> void:`
- L1009: `func _occupied(z: float) -> bool:`
- L1014: `func _flora() -> void:`
- L1083: `func _bounds() -> void:`
- L1108: `func _hanging_bulb(p: Vector3, index: int, mount: String) -> void:`
- L1156: `func _bulb(parent: Node3D, offset: Vector3, index: int, color: Color, reach: float, energy := .8) -> void:`
- L1184: `func _bridge_lamp(base: Vector3, index: int) -> void:`
- L1199: `func _shrine(p: Vector3, index: int) -> void:`
- L1226: `func _mist_and_reflections() -> void:`
- L1254: `func _process(delta: float) -> void:`
- L1291: `const HOLE := Rect2(-123.5, -18.5, 88.1, 91.0)`
- L1293: `func _open_connection(town: Node3D) -> void:`
- L1353: `func _split_ground(parent: Node, c: CollisionShape3D) -> void:`
- L1381: `func _carve_mesh(mi: MeshInstance3D, hole := HOLE) -> void:`
- L1446: `func _append_interp(dst: Variant, src: Variant, t: Array, w: Vector3, kind: int) -> Variant:`
- L1475: `func _outside_pieces(poly: Array, hole := HOLE) -> Array:`
- L1482: `func _clip(poly: Array, axis: int, value: float, below: bool) -> Array:`
## game/scripts/canal_warren.gd

SHA-256: `f6a9b06a57d2dd46ab9b9cbcb0703759ea11b1b6c95ad5ba94aea964fe2f90d2`

- L18: `const LooseProps := preload("res://scripts/loose_props.gd")`
- L19: `const Usable := preload("res://scripts/neighborhood_usable.gd")`
- L20: `const WarrenUsable := preload("res://scripts/warren_usable.gd")`
- L21: `const WarrenDoor := preload("res://scripts/warren_door.gd")`
- L23: `const FLOOR := -2.10`
- L24: `const DECK := -2.05          # boardwalk top`
- L25: `const COVER := FLOOR + 2.32  # underside of the tunnel roof`
- L26: `const EW := -3.55            # estero water`
- L27: `const EBED := -4.10`
- L28: `const Z0 := -15.6            # the warren's south and north walls (the estero runs into culverts there)`
- L29: `const Z1 := 58.6`
- L30: `const WEST_U := -53.2`
- L31: `const FENCE_U := -28.5`
- L32: `const ENTRY_Z := 8.0`
- L33: `const EXIT_Z := 54.7`
- L34: `const B1_Z := -11.0`
- L35: `const B2_Z := 52.6`
- L36: `const EAST_SOUTH := Vector2(-11.9, 9.2)  # z span of the east boardwalk's south part`
- L37: `const EAST_NORTH := Vector2(51.6, 55.8)`
- L38: `const WEST_WALK := Vector2(-11.9, 53.5)`
- L39: `const HOUSE_D := 2.45        # house fronts stand this far from the centre line`
- L40: `const WALK_IN := .85         # boardwalks reach this far over the water`
- L41: `const ROOMS := [["family", 1.0, 6.0], ["altar", 18.0, 23.0], ["store", 40.0, 45.0]]`
- L42: `const ROOM_BACK := -6.5`
- L43: `const YARD := Vector2(28.0, 34.0)`
- L44: `const SAG := Vector2(-2.2, -.3)  # the caved-in stretch of the east boardwalk`
- L45: `const SLITS := [Vector2(-6.9, -6.3), Vector2(12.4, 13.1), Vector2(36.2, 36.9), Vector2(47.4, 48.0), Vector2(-14.2, -13.4),`
- L49: `const SPILLS := [-6.6, 12.75, 36.55, 47.7, -9.35, -3.15, 2.55, 6.8, 9.85, 15.55, 25.35, 38.55, 50.55]`
- L50: `const LINES := ["Tao po? ...Nobody.", "Padlocked. From the outside.", "Something moved in there. Or I imagined it.",`
- L68: `static func rx(z: float) -> float:`
- L71: `static func ec(z: float) -> float:`
- L75: `static func slope(z: float) -> float:`
- L78: `static func at(u: float, y: float, z: float) -> Vector3:`
- L81: `static func pos(d: float, y: float, z: float) -> Vector3:`
- L85: `static func along(z: float) -> Basis:`
- L90: `static func faces_west(z: float) -> Basis:`
- L95: `static func faces_east(z: float) -> Basis:`
- L99: `static func ground(u: float, z: float, n: float) -> float:`
- L107: `static func in_spans(z: float, spans: Array) -> bool:`
- L114: `func build(settlement: Node3D) -> void:`
- L138: `func _materials() -> void:`
- L172: `func _along_box(label: String, d: float, y: float, z: float, size: Vector3, mat: String, solid := false, surface := "wood", tilt := Basis.IDENTITY) -> void:`
- L176: `func _strip(label: String, d: float, y: float, z0: float, z1: float, across: float, height: float, mat: String, solid := false, surface := "wood", step := 2.0) -> void:`
- L184: `func _water() -> void:`
- L205: `func _banks() -> void:`
- L240: `func _houses() -> void:`
- L291: `func _house(spec: Dictionary, row: String, zc: float, walk: bool) -> void:`
- L311: `func _colliders(spec: Dictionary, p: Vector3, basis: Basis) -> void:`
- L318: `func _locked_door(front: Vector3, normal: Vector3, style: String, size := Vector2(.9, 2.0), centre_y := FLOOR + 1.0) -> Node3D:`
- L350: `func _static(parent: Node3D, centre: Vector3, size: Vector3) -> StaticBody3D:`
- L364: `func _mesh_box(parent: Node3D, centre: Vector3, size: Vector3, mat: String, basis := Basis.IDENTITY) -> MeshInstance3D:`
- L375: `func _mesh_tube(parent: Node3D, centre: Vector3, radius: float, height: float, mat: String, basis := Basis.IDENTITY, top := -1.0) -> MeshInstance3D:`
- L391: `func _walks() -> void:`
- L403: `func _deck(d0: float, d1: float, z0: float, z1: float) -> void:`
- L435: `func _rail(d: float, z0: float, z1: float, gaps: Array) -> void:`
- L458: `func _bridges() -> void:`
- L479: `func _covers() -> void:`
- L498: `func _cover(d0: float, d1: float, z0: float, z1: float, open: Array) -> void:`
- L536: `func _rag(a: Vector3, c: Vector3) -> void:`
- L543: `func _rooms() -> void:`
- L550: `func _room_shell(kind: String, z0: float, z1: float) -> void:`
- L599: `func _hinged_door(hinge: Vector3, basis: Basis, width: float, height: float, mat: String, label: String, angle: float) -> Node3D:`
- L638: `func _family_room(z0: float, z1: float) -> void:`
- L686: `func _altar_room(z0: float, z1: float) -> void:`
- L719: `func _store(z0: float, z1: float) -> void:`
- L766: `func _usable(kind: String, p: Vector3, basis: Basis, size: Vector3) -> Node3D:`
- L780: `func _yard() -> void:`
- L830: `func _cage(c: Vector3, a: Basis) -> void:`
- L840: `func _ends() -> void:`
- L857: `func _barricade(d0: float, d1: float, z: float) -> void:`
- L868: `func _gates() -> void:`
- L920: `func _bounds() -> void:`
- L937: `func _dressing() -> void:`
- L971: `func _room_or_yard(z: float) -> bool:`
- L976: `func _props() -> void:`
- L1021: `func _lights() -> void:`
- L1057: `func _tube_light(p: Vector3, a: Basis) -> void:`
- L1085: `func _light(parent: Node3D, offset: Vector3, color: Color, reach: float, energy: float, kind: String, shadows: bool) -> void:`
- L1113: `func _sounds() -> void:`
- L1126: `static func _hum() -> AudioStreamWAV:`
- L1136: `static func _drips(seed_value: int) -> AudioStreamWAV:`
- L1152: `func usable_changed(_node: Node) -> void:`
- L1155: `func _process(delta: float) -> void:`
- L1189: `func _crouch_hint() -> void:`
## game/scripts/warren_door.gd

SHA-256: `4f8519b085f356a90c6a1cfdf1dec198b1e933199356b6df8bbc3ebb2a032ec9`

- L10: `func _ready() -> void:`
- L23: `func _physics_process(delta: float) -> void:`
- L36: `static func _make_creak() -> AudioStreamWAV:`
## game/scripts/warren_usable.gd

SHA-256: `6fad637c32cd238f7e9b4c67c2b97d304b93c6b431a6d6e4ae7ff2aad09e2ff7`

- L15: `func _ready() -> void:`
- L35: `func prompt_text() -> String:`
- L42: `func toggle() -> void:`
- L63: `func _process(delta: float) -> void:`
- L75: `static func _wav(samples: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:`
- L91: `static func _radio_loop() -> AudioStreamWAV:`
- L117: `static func _click() -> AudioStreamWAV:`
## game/scripts/nichols_property.gd

SHA-256: `50f372e7ec1d7e759f416b655ce2e9fb7beb2b29c0e1e37e98cc1bc15505765f`

- L12: `const GROUND := -2.9`
- L13: `const HOUSE_POS := Vector3(-12.0, GROUND + 1.2, -82.0)   # front facade centre, ground-floor boards`
- L14: `const GATE := Vector3(-12.0, GROUND, -60.0)`
- L15: `const GATE_HALF := 2.95`
- L16: `const ESTATE := Rect2(-40.0, -124.0, 54.0, 64.0)          # x -40..14, z -124..-60`
- L17: `const REGION := Rect2(-46.0, -130.0, 72.0, 112.0)         # walkable south region, x -46..26, z -130..-18`
- L18: `const DIR := "res://assets/models/nichols/"`
- L19: `const HOUSE_DIR := "res://assets/models/nichols/house/"`
- L20: `const TEX := "res://assets/outdoor/textures/"`
- L21: `const INTERIOR_LAYER := 1 << 10`
- L22: `const OUTDOOR_LAYER := 2`
- L23: `const SURFACE := preload("res://scripts/nichols_surface.gdshader")`
- L24: `const WALLPAPER := preload("res://scripts/nichols_wallpaper.gdshader")`
- L25: `const MARBLE := preload("res://scripts/nichols_marble.gdshader")`
- L26: `const GROUND_SHADER := preload("res://scripts/nichols_ground.gdshader")`
- L27: `const DoorScript := preload("res://scripts/nichols_door.gd")`
- L28: `const LockedScript := preload("res://scripts/nichols_locked.gd")`
- L29: `const ENTRY_LINE := "I've never been inside of the Nichols property.."`
- L31: `const PATH := [Vector2(20.6, -24.0), Vector2(20.2, -33.0), Vector2(17.0, -40.5), Vector2(10.0, -47.0), Vector2(1.0, -52.5), Vector2(-6.5, -57.0), Vector2(-12.0, -59.6)]`
- L49: `const SHADOW_LAYER := 1 << 11`
- L51: `const BASEMENT_LAYER := 1 << 12`
- L52: `const BasementScript := preload("res://scripts/nichols_basement.gd")`
- L54: `const BEAM := preload("res://scripts/nichols_beam.gdshader")`
- L56: `const ARCH_LAYER := 1 << 19`
- L58: `const BASEMENT_FLOOR := -2.7`
- L61: `static func local(x: float, depth: float, up := 0.0) -> Vector3:`
- L65: `func build(town: Node3D) -> void:`
- L105: `func _noise() -> void:`
- L117: `func _tex(id: String, map: String) -> Texture2D:`
- L121: `func _surface(key: String, id: String, tile: float, opts := {}) -> ShaderMaterial:`
- L135: `func _wallpaper(key: String, channel: int, paper: Color, ink: Color, opts := {}) -> void:`
- L152: `func _flat(key: String, color: Color, rough: float, metal := 0.0) -> StandardMaterial3D:`
- L161: `func _materials() -> void:`
- L257: `func _basement_materials() -> void:`
- L328: `func _lace_texture() -> ImageTexture:`
- L350: `func _material_for(key: String) -> Material:`
- L353: `func _bind(node: Node, layers: int, shadows := true) -> void:`
- L371: `func _house() -> void:`
- L407: `func _v(a: Array) -> Vector3:`
- L411: `func is_inside(p: Vector3) -> bool:`
- L416: `func is_below(p: Vector3) -> bool:`
- L421: `func _door(hinge: Vector3, latch: Vector3, swing: Vector3, height: float, width: float, leaf_path: String, label: String,`
- L465: `func _doors() -> void:`
- L513: `func _interior_light() -> void:`
- L576: `func _update_light() -> void:`
- L605: `func _beams() -> void:`
- L673: `func _card(st: SurfaceTool, a: Vector3, c: Vector3, fc: Vector3, fa: Vector3, L: Vector3) -> void:`
- L687: `const STATIC_PROPS := ["chandelier_01", "chandelier_02", "bench_vice_01", "hatchet"]`
- L689: `const PROP_SPECS := {`
- L737: `func _physical(visual: Node3D, name_: String, hung := false, floor_clip := false) -> InteriorObject:`
- L777: `const SEATS := {"dining_chair_02": .47, "rockingchair_01": .42, "wheelchair_01": .45, "old_bed_frame": .4, "gothicbed_01": .42}`
- L779: `func _box_shape(body: CollisionObject3D, box: AABB, shrink := Vector3.ONE) -> void:`
- L788: `func _seat_shapes(body: InteriorObject, visual: Node3D, seat_frac: float) -> void:`
- L829: `func _model(name_: String, p: Vector3, yaw: float, scale := 1.0, collide := true, tilt := Vector3.ZERO, layer := INTERIOR_LAYER) -> Node3D:`
- L859: `func _age(node: Node) -> void:`
- L876: `func _tint(node: Node, c: Color) -> void:`
- L888: `func _dust_pass() -> ShaderMaterial:`
- L909: `func _furnish() -> void:`
- L1007: `func _sheet(name_: String, p: Vector3, yaw: float) -> void:`
- L1019: `func C0() -> float: return 4.0`
- L1020: `func F1() -> float: return 4.4`
- L1023: `func _rubble() -> void:`
- L1091: `func _webs() -> void:`
- L1157: `func _open_street(town: Node3D) -> void:`
- L1197: `func _sawhorse(at: Vector3, basis: Basis) -> void:`
- L1205: `func _path_dist(p: Vector2) -> float:`
- L1214: `func _drive_dist(p: Vector2) -> float:`
- L1223: `func _terrain() -> void:`
- L1289: `func _solid(label: String, p: Vector3, size: Vector3, surface := "grass", basis := Basis.IDENTITY) -> CollisionShape3D:`
- L1302: `func _bounds() -> void:`
- L1316: `func _estate() -> void:`
- L1423: `func _railing_wall(a: Vector3, c: Vector3) -> void:`
- L1451: `func _fountain(c: Vector3) -> void:`
- L1466: `func _grounds() -> void:`
- L1498: `func _overgrowth() -> void:`
- L1573: `func _fog_inside(delta: float) -> void:`
- L1586: `func _process(delta: float) -> void:`
## game/scripts/nichols_basement.gd

SHA-256: `5e4c8e7c98c262fb0edbd2d6e2b50935e56789bd376d02d16049b47cbab061c9`

- L13: `const INTERIOR_LAYER := 1 << 10`
- L14: `const BASEMENT_LAYER := 1 << 12`
- L15: `const OUTDOOR_LAYER := 2`
- L16: `const BLOOD := "res://assets/nichols/blood/"`
- L17: `const AUDIO := "res://assets/audio/nichols/"`
- L18: `const SIGHT_LINES := ["Shit..", "I thought this place was empty decades ago?"]`
- L19: `const LOCK_LINES := ["Chained shut.", "That padlock is new.", "Someone comes down here."]`
- L21: `const HOLE := Rect2(-25.0, -102.0, 26.0, 20.0)`
- L22: `const BULB_COLOR := Color(1.0, .7, .43)`
- L23: `const LockedScript := preload("res://scripts/nichols_locked.gd")`
- L24: `const HorrorLiquid := preload("res://scripts/horror_liquid.gd")`
- L50: `func build(property: Node3D, town: Node3D) -> void:`
- L71: `func _v(a: Array) -> Vector3:`
- L74: `func _at(a: Array) -> Vector3:`
- L78: `func bl(x: float, depth: float, up := 0.0) -> Vector3:`
- L84: `func _cut_ground(town: Node3D) -> void:`
- L101: `func _split_box(parent: Node, c: CollisionShape3D) -> void:`
- L130: `func _door() -> void:`
- L140: `func _switch() -> void:`
- L200: `func set_basement_lights(on: bool, instant := false) -> void:`
- L224: `func is_lit() -> bool:`
- L229: `func _cyl(top: float, bottom: float, height: float, segments := 10) -> CylinderMesh:`
- L238: `func _mesh(parent: Node3D, mesh: Mesh, material: Material, at := Vector3.ZERO, basis := Basis.IDENTITY, layers := BASEMENT_LAYER) -> MeshInstance3D:`
- L248: `func _rod(parent: Node3D, a: Vector3, b: Vector3, r: float, material: Material, layers := BASEMENT_LAYER) -> void:`
- L257: `func _bulbs() -> void:`
- L353: `func _flicker(b: Dictionary, delta: float) -> void:`
- L392: `func _air() -> void:`
- L424: `func _room_light(room: String) -> float:`
- L436: `const RETINT := {"old_tyre": Color(.035, .033, .032), "metal_office_desk": Color(.2, .21, .2)}`
- L438: `func _p(name_: String, x: float, depth: float, up: float, yaw := 0.0, scale := 1.0, tilt := Vector3.ZERO) -> Node3D:`
- L455: `func _props() -> void:`
- L509: `func _bundle_on_hook() -> void:`
- L590: `func _locked_door() -> void:`
- L614: `func _kitchen() -> void:`
- L679: `func _texture_set(kind: String) -> Array:`
- L687: `func decal(kind: String, at: Vector3, along: Vector3, up: Vector3, size: Vector3, alpha := 1.0, mask := INTERIOR_LAYER | BASEMENT_LAYER) -> Decal:`
- L711: `const DRAGS := ["drag_a", "drag_b", "drag_c"]`
- L713: `func _blood() -> void:`
- L802: `func _audio(clip: String, loop := false) -> AudioStream:`
- L812: `func _sounds() -> void:`
- L839: `func _process(delta: float) -> void:`
- L877: `func _check_sight(cam: Camera3D) -> void:`
## game/scripts/nichols_door.gd

SHA-256: `777deb043279fcda0ad65f46c8ec354c934ccb43bd5c86a5fcdccf5123a88a87`

- L8: `const OPENS := ["door_open_a", "door_open_b", "door_open_c", "door_open_d"]`
- L9: `const SHUTS := ["door_close_a", "door_close_b"]`
- L18: `func _ready() -> void:`
- L41: `func _physics_process(delta: float) -> void:`
- L58: `func _play(stream: AudioStream, pitch: float) -> void:`
- L63: `func prompt_text() -> String:`
## game/scripts/nichols_locked.gd

SHA-256: `1314da9bf481ae1ce2ee809db3c3754154638e219e0b5223495ef0786a3897b8`

- L10: `func _ready() -> void:`
- L22: `func prompt_text() -> String:`
- L25: `func toggle() -> void:`
- L37: `func _process(delta: float) -> void:`
## game/scripts/fields_builder.gd

SHA-256: `04ff88da0fd396a15289979f6ae90fc6342298580dc227df11e784be27f09afc`

- L14: `const FieldsScript = preload("res://scripts/fields.gd")`
- L15: `const WATER_SHADER = preload("res://scripts/night_water.gdshader")`
- L16: `const BLADE_SHADER = preload("res://scripts/field_blades.gdshader")`
- L17: `const FIREFLY_SHADER = preload("res://scripts/firefly.gdshader")`
- L18: `const OUTDOOR_LAYER := 2`
- L19: `const GROUND := -2.9`
- L20: `const WATER_Y := GROUND - .42`
- L21: `const GRID_ORIGIN := Vector2(-150.0, 60.0)`
- L22: `const CELL_W := 28.0`
- L23: `const CELL_H := 22.0`
- L25: `const FIELD_RECT := Rect2(-150.0, 66.0, 330.0, 574.0)`
- L26: `const TOWN_NOTCH := Rect2(-150.0, 66.0, 136.0, 14.0)`
- L29: `const ROAD_POINTS := [Vector2(21, 40), Vector2(21, 54.5), Vector2(21, 66), Vector2(17, 110), Vector2(12, 150), Vector2(22, 185),`
- L32: `const ROAD_HALF := 2.05`
- L33: `const VERGE := 3.1`
- L35: `const WALK_HALF := 3.2`
- L36: `const RICE_REACH := 42.0`
- L37: `const CHUNK := 16.0`
- L38: `const POND_RADII := Vector2(15.0, 12.5)`
- L39: `const POND_OFFSET := 19.0`
- L40: `const MOON := InteriorNight.MOON_DIRECTION`
- L63: `static func build(parent: Node3D) -> Dictionary:`
- L113: `static func cell_kind(x: float, z: float) -> int:`
- L124: `static func in_water(p: Vector2) -> bool:`
- L127: `func in_pond(p: Vector2, margin := 0.0) -> bool:`
- L133: `func is_dry(p: Vector2) -> bool:`
- L139: `func _v3(p: Vector2, y: float) -> Vector3:`
- L143: `func nearest(p: Vector2, limit := 64.0) -> Array:`
- L165: `func coarse_distance(p: Vector2) -> float:`
- L172: `static func tile_key(p: Vector2, material: String) -> String:`
- L175: `func _materials() -> void:`
- L203: `func _ripple_texture(seed_value: int, frequency: float) -> NoiseTexture2D:`
- L220: `func _sample_road() -> void:`
- L252: `func _place_pond() -> void:`
- L276: `const PROFILE := [[6.7, -.48], [6.15, -.15], [5.65, -.15], [5.35, -.75], [4.55, -.75], [4.15, -.47], [3.1, -.06],`
- L279: `const STRIPS := ["dike", "dike", "mud", "mud", "mud", "bank", "verge", "road", "road", "road", "road", "road", "road",`
- L282: `const PROFILE_POND := [[6.7, -.75], [6.15, -.7], [5.65, -.66], [5.35, -.62], [4.55, -.55], [4.15, -.45], [3.1, -.06]]`
- L284: `func _profile_at(i: int) -> Array:`
- L304: `func _road_mesh() -> void:`
- L344: `func _point(i: int, uy: Array) -> Vector3:`
- L348: `func _trimesh(label: String, faces: PackedVector3Array, surface: String) -> void:`
- L361: `func _town_bank() -> void:`
- L387: `func _water() -> void:`
- L413: `func _dikes() -> void:`
- L427: `func _dike_clear(p: Vector2) -> bool:`
- L434: `func _dike_line(a: Vector2, c: Vector2) -> void:`
- L447: `func _dike(a: Vector2, c: Vector2) -> void:`
- L467: `func _pond_details() -> void:`
- L520: `func _lily(p: Vector2, radius: float, yaw: float, flower: bool) -> void:`
- L535: `func _jetty() -> void:`
- L571: `func _puddles() -> void:`
- L590: `func _index_at(distance: float) -> int:`
- L604: `func _hut() -> void:`
- L658: `func _nearest_index(p: Vector2) -> int:`
- L662: `func _road_end() -> void:`
- L712: `func _model(path: String, at: Vector3, yaw: float, scale: float, fade: float) -> Node3D:`
- L717: `func _plants() -> void:`
- L803: `func _islet(p: Vector2, radius: float) -> void:`
- L827: `func _poles() -> void:`
- L858: `const SCARECROW_PAST_HUT := 38       # road samples (~1 m each) past the hut's own sample`
- L859: `const SCARECROW_OFF_ROAD := 9.0`
- L860: `const SCARECROW_ISLET := 2.2         # radius at the waterline; the flat top is 0.55 of it`
- L862: `func _scarecrow() -> void:`
- L882: `func _blade_clump(blades: int, panicles: int, width: float, droop: float, seed_value: int) -> ArrayMesh:`
- L919: `func _rice_and_grass() -> void:`
- L994: `func _add_instance(store: Dictionary, kind: String, p: Vector2, t: Transform3D, custom: Color) -> void:`
- L1001: `func _emit_chunks(store: Dictionary, meshes: Dictionary, material: ShaderMaterial, parent: Node3D, label: String) -> int:`
- L1043: `func _wall_box(label: String, base: Vector3, size: Vector3, basis: Basis) -> void:`
- L1053: `func _walls() -> void:`
- L1085: `func _fireflies() -> void:`
- L1142: `func _commit() -> void:`
## game/scripts/fields.gd

SHA-256: `accd24f26db66470bb8e4fdae413bdbd41b058e40d987ff7d7eaed498871965d`

- L17: `const OUTDOOR_LAYER := 2`
- L29: `func _ready() -> void:`
- L56: `func _mobile_budget() -> void:`
- L71: `static func zone_weight(position: Vector3) -> float:`
- L76: `func _process(delta: float) -> void:`
- L92: `func _scarecrow(camera: Camera3D) -> void:`
## game/scripts/hut_house.gd

SHA-256: `add05517aa99bf8d69f4e9173579e40ca451beca09dd6c1ad8b8e9517172e4d0`

- L22: `const OUTDOOR_LAYER := 2`
- L23: `const GROUND := -2.9`
- L24: `const WATER_Y := GROUND - .42`
- L25: `const FLOOR := .42`
- L26: `const BACK := -1.734`
- L27: `const FRONT := 1.695`
- L28: `const SIDE_POS := 1.691`
- L29: `const SIDE_NEG := -1.64`
- L30: `const DOOR_Z0 := -.62`
- L31: `const DOOR_Z1 := .02`
- L32: `const DOOR_Z := -.3`
- L33: `const DOOR_TOP := 2.3`
- L34: `const WINDOW_Z := Vector2(.62, 1.28)`
- L35: `const WINDOW_Y := Vector2(1.45, 2.18)`
- L36: `const YARD := 6.6`
- L37: `const PATH_HALF := 1.15`
- L38: `const WALK_HALF := 3.2`
- L39: `const GLOCK := preload("res://assets/models/story/glock17.glb")`
- L40: `const AMMO_BOX := "res://assets/models/story/ammo_box.glb"`
- L42: `const ISLET_TOP := 2.0`
- L43: `const DIKE_HALF := 1.05`
- L44: `const SPARKLE_SHADER := preload("res://scripts/sparkle.gdshader")`
- L45: `const DRAWER_TRAVEL := .3`
- L77: `static func attach(fields_root: Node3D) -> InteriorHutHouse:`
- L90: `func _ready() -> void:`
- L125: `func _road_samples() -> PackedVector2Array:`
- L128: `static func _nearest(points: PackedVector2Array, p: Vector2) -> int:`
- L140: `func _tex_mat(key: String, albedo: String, normal: String, rough: String, tile: float, tint: Color, roughness := 1.0) -> StandardMaterial3D:`
- L159: `func _flat(key: String, color: Color, roughness := .8, metallic := 0.0) -> StandardMaterial3D:`
- L168: `func _materials() -> void:`
- L203: `func _box(parent: Node3D, label: String, lo: Vector3, hi: Vector3, mat: String, collide := false) -> MeshInstance3D:`
- L217: `func _solid(label: String, center: Vector3, size: Vector3, basis := Basis.IDENTITY, body: CollisionObject3D = null) -> CollisionShape3D:`
- L227: `func _cylinder(parent: Node3D, label: String, at: Vector3, radius: float, height: float, mat: String, top_radius := -1.0, segments := 24) -> MeshInstance3D:`
- L245: `func _move_lantern() -> void:`
- L265: `func _shell() -> void:`
- L311: `func _steps() -> void:`
- L334: `func _furniture() -> void:`
- L399: `const DRESSER_W := 1.0`
- L400: `const DRESSER_D := .46`
- L401: `const DRESSER_H := .84`
- L405: `func _dresser() -> void:`
- L503: `func _knob(parent: Node3D, at: Vector3) -> void:`
- L515: `func _candle() -> void:`
- L565: `func _key_on_top() -> void:`
- L617: `func _footpath(road: PackedVector2Array) -> void:`
- L640: `func _scarecrow_dike() -> void:`
- L648: `func _clear_approach() -> void:`
- L698: `func crow_frame() -> Array:`
- L708: `func box_spot() -> Vector3:`
- L716: `func _hide_ammo_box() -> void:`
- L731: `static func make_ammo_box() -> Node3D:`
- L752: `func is_inside(world: Vector3) -> bool:`
- L757: `func call_spot() -> Vector3:`
- L760: `func door_point() -> Vector3:`
- L764: `func route_out() -> Array[Vector3]:`
- L771: `func usable_prompt(kind: String) -> String:`
- L786: `func use(kind: String) -> void:`
- L817: `func _unlock_and_open() -> void:`
- L833: `func remove_flashlight() -> void:`
- L841: `func take_gun() -> void:`
- L848: `func _play_sfx(path: String, at: Vector3, pitch := 1.0, volume := 0.0) -> void:`
- L857: `func _process(delta: float) -> void:`
## game/scripts/hut_usable.gd

SHA-256: `31e04716c1998e5d984590fe5a575c7a9719ea814527f88979be4e3442fe6418`

- L9: `func _ready() -> void:`
- L12: `func prompt_text() -> String:`
- L15: `func toggle() -> void:`
## game/scripts/stranger.gd

SHA-256: `18157f413f47454de8f90aef9d8a1c6bd2e49f36b4631c1cc0769b51af8c8524`

- L46: `const MODEL := preload("res://assets/characters/stranger.glb")`
- L47: `const CutsceneScript := preload("res://scripts/stranger_cutscene.gd")`
- L48: `const OUTDOOR_LAYER := 2`
- L49: `const GROUND := -2.9`
- L51: `const GATE_SPOT := Vector3(13.0, GROUND, 4.1)`
- L53: `const WAIT_SPOT := Vector3(19.05, GROUND, 45.1)`
- L55: `const CART := Vector3(19.7, GROUND, 17.0)`
- L58: `const ROUTE_TO_ROAD := [Vector3(14.0, GROUND, 4.6), Vector3(16.5, GROUND, 5.5), Vector3(18.9, GROUND, 6.0),`
- L62: `const ROUTE_TO_FIELDS := [Vector3(20.4, GROUND, 49.0), Vector3(21.0, GROUND, 54.1), Vector3(21.0, GROUND, 58.0)]`
- L63: `const RUN_SPEED := 5.7          # m/s; the player runs 4.7`
- L66: `const RUN_CLIP_SPEED := 5.62`
- L67: `const RUN_STEPS := [6.0 / 30.0, 16.0 / 30.0] # contacts in the authored 19-frame cycle`
- L68: `const ACCELERATION := 9.0`
- L69: `const TURN_RATE := 9.0`
- L70: `const REACTION := .25           # seconds he must be in view before he bolts`
- L71: `const SEE_DISTANCE := 48.0`
- L72: `const CART_PASS := .6           # metres past the cart (northward) that count as passing it`
- L73: `const NEAR_FLEE := 20.0`
- L74: `const ROAD_RUN := 230.0         # metres down the dirt road before he may vanish`
- L77: `const LOOPS := ["gate_grip", "stand_stare", "run", "idle", "idle_look", "walk", "hero_run", "hero_walk", "interact_talk", "walk_back",`
- L79: `const CLIPS := ["gate_grip", "stand_stare", "run", "walk", "interact_talk", "interact_pickup", "idle_adjust", "hand_over",`
- L81: `const WADE_SPEED := 2.0         # m/s through the flooded paddy`
- L82: `const WADE_DEPTH := .62         # feet below the road level while wading (water at GROUND - 0.42)`
- L83: `const FOLLOW_GAP := 20.0        # he waits when the player is further behind than this`
- L84: `const FOLLOW_RESUME := 12.0`
- L87: `const PICKUP_RATE := .8`
- L88: `const PICKUP_LOW := .333        # frame 10 of 30; hand.R is then 0.36 m up (a deep crouch, not the ground)`
- L89: `const PICKUP_HAND := Vector2(.108, .025)`
- L90: `const BOX_LIFT := .22           # s for the box to come up out of the mud into his fist`
- L92: `const HAND_OVER_RELEASE := 1.2`
- L93: `const BOX_POCKET_TIME := .35`
- L94: `const WALK_SPEED := 1.45`
- L95: `const WALK_CLIP_SPEED := 1.6`
- L96: `const BRING_WALK := 4.0         # the last metres back to the player are walked, box in hand`
- L97: `const GIVE_DISTANCE := 1.15     # he stops this far from the player to hold the box out`
- L99: `const CUT_LOOK := 2.9           # his head turns toward the player`
- L100: `const CUT_LET_GO := 3.7         # hands off the bars, backing off`
- L101: `const CUT_TURN := 5.1           # turns away and walks`
- L102: `const BACK_SPEED := .5          # m/s backing off (walk_back played slow)`
- L103: `const BACK_CLIP_SPEED := 1.2`
- L105: `const CRAWL_SPEED := .78`
- L106: `const CRAWL_CLIP_SPEED := 1.15`
- L107: `const HOLE_REACTION := .6       # s in view before he goes through`
- L108: `const HOLE_NEAR := 12.0`
- L110: `const BOX_IN_HAND := Transform3D(Basis.IDENTITY, Vector3(0, .09, .03))`
- L147: `func _ready() -> void:`
- L168: `func _own_loops() -> void:`
- L182: `func _setup_audio() -> void:`
- L205: `func _require_clip(clip: String) -> bool:`
- L211: `func _play(clip: String, blend: float, rate := 1.0) -> void:`
- L218: `func _face(yaw: float) -> void:`
- L223: `static func yaw_toward(direction: Vector3) -> float:`
- L226: `func _find_player() -> Node3D:`
- L233: `func _find_gate() -> void:`
- L246: `func _physics_process(delta: float) -> void:`
- L351: `static func passed_cart(at: Vector3) -> bool:`
- L354: `func _bolt() -> void:`
- L363: `func _flee() -> void:`
- L383: `func road_path() -> Array[Vector3]:`
- L402: `func road_range(from_z: float, to_index: int, start_index := -1) -> Array[Vector3]:`
- L421: `static func nearest_road_index(samples: PackedVector2Array, at: Vector3) -> int:`
- L431: `func _road_samples() -> PackedVector2Array:`
- L435: `func _face_player(player: Node3D, delta: float, rate: float) -> void:`
- L443: `func _start_cutscene() -> void:`
- L454: `func _act(delta: float) -> void:`
- L479: `func end_cutscene() -> void:`
- L492: `func in_cutscene() -> bool:`
- L496: `func _gate_opened() -> bool:`
- L504: `func to_hole() -> void:`
- L518: `func _start_crawl() -> void:`
- L525: `func _crawl(delta: float) -> void:`
- L543: `func _flee_from_hole() -> void:`
- L562: `func _setup_look() -> void:`
- L599: `func _set_look(weight: float, seconds: float) -> void:`
- L605: `func _process(_delta: float) -> void:`
- L615: `func _hide_in_hut() -> void:`
- L623: `func call_out(hut: InteriorHutHouse) -> void:`
- L636: `func lead_to_scarecrow(hut: InteriorHutHouse) -> void:`
- L641: `func _start_leading() -> void:`
- L673: `func dig_spot() -> Vector3:`
- L684: `func _start_digging() -> void:`
- L703: `func _dig(delta: float) -> void:`
- L723: `func _safe_path_to(target: Vector3) -> Array[Vector3]:`
- L768: `func _supported_link(from: Vector3, to: Vector3) -> bool:`
- L788: `func _handover_clear(target: Vector3) -> bool:`
- L796: `func _project_route(route: Array[Vector3], at: Vector3) -> Dictionary:`
- L809: `func _take_box() -> void:`
- L829: `func has_box() -> bool:`
- L832: `func _freeze_scarecrow(frozen: bool) -> void:`
- L837: `func _start_giving() -> void:`
- L848: `func _give(player: Node3D, delta: float) -> void:`
- L862: `func _hand_over_box() -> void:`
- L885: `func leave() -> void:`
- L905: `func _run_along(delta: float) -> bool:`
- L939: `func _ground_at(at: Vector3) -> float:`
- L954: `func _footsteps(_delta: float) -> void:`
- L979: `func _sees_me(delta: float) -> bool:`
- L987: `func _in_view(strict: bool) -> bool:`
## game/scripts/story.gd

SHA-256: `c7d532a7848e1988db1bf8b93e9f34b00defc432ee920d8520554b99037505b0`

- L17: `const SPEAKER := "Hooded man"`
- L18: `const CALL_LINES := ["You have to hurry!",`
- L21: `const RUN_LINE := "Now, take these with you and go back! Hurry, before they notice!"`
- L22: `const AMMO_GIVEN := 60`
- L23: `const SIREN := "res://assets/audio/sfx/siren_wail.ogg"`
- L25: `const SIREN_SPOTS := [Vector3(4.0, 22.0, 36.0), Vector3(-95.0, 22.0, 170.0), Vector3(115.0, 22.0, 255.0), Vector3(40.0, 22.0, 470.0)]`
- L50: `func setup(main_node: Node, hut_house: InteriorHutHouse) -> void:`
- L87: `func stranger() -> InteriorStranger:`
- L90: `func notify(text: String) -> void:`
- L94: `func consume_hold() -> bool:`
- L102: `func _unhandled_input(event: InputEvent) -> void:`
- L107: `func _update_inventory() -> void:`
- L117: `func _play(path: String, volume := 0.0, pitch := 1.0) -> void:`
- L126: `func _on_key_taken() -> void:`
- L132: `func _on_drawer_opened() -> void:`
- L136: `func _on_flashlight_picked() -> void:`
- L142: `func _on_gun_requested() -> void:`
- L151: `func _on_inspect_closed(taken: bool) -> void:`
- L170: `func _on_dialogue_finished() -> void:`
- L186: `func receive_ammo() -> void:`
- L197: `func _on_ammo_changed() -> void:`
- L202: `func inspect_carried_gun() -> void:`
- L213: `func debug_give_key() -> void:`
- L226: `func debug_give_gun() -> void:`
- L236: `func debug_give_flashlight() -> void:`
- L248: `func start_alarm() -> void:`
- L256: `func _start_sirens() -> void:`
- L287: `func _kill_street_lamps() -> void:`
- L315: `func _darken_lenses() -> void:`
- L328: `func lamps_lit() -> int:`
- L336: `static func is_home(at: Vector3) -> bool:`
- L340: `static func is_inside_house(at: Vector3) -> bool:`
- L343: `func _process(_delta: float) -> void:`
## game/scripts/player.gd

SHA-256: `e49ea7625fe41aae9f12ffb3953efedf6fa6f7e36d509b8046deebac9f94de49`

- L13: `const WALK_SPEED := 2.45`
- L14: `const RUN_SPEED := 4.7`
- L15: `const CROUCH_SPEED := 1.2`
- L17: `const WALK_STEP := 1.05`
- L18: `const RUN_STEP := 1.55`
- L19: `const CROUCH_STEP := .7`
- L21: `const BOB_HEIGHT := .034`
- L22: `const BOB_SWAY := .022`
- L23: `const BOB_ROLL := .011`
- L24: `const GROUND_ACCELERATION := 10.5`
- L25: `const SPRINT_ACCELERATION := 13.5`
- L26: `const GROUND_BRAKING := 12.0`
- L27: `const AIR_ACCELERATION := 1.8`
- L28: `const GRAVITY := 14.0`
- L29: `const JUMP_SPEED := 4.8`
- L30: `const PLAYER_MASS := 78.0`
- L31: `const COYOTE_TIME := 0.11`
- L32: `const JUMP_BUFFER_TIME := 0.14`
- L33: `const STANDING_HEIGHT := 1.70`
- L34: `const CROUCH_HEIGHT := 1.00`
- L35: `const STANDING_EYE := 1.58`
- L36: `const CROUCH_EYE := 0.88`
- L37: `const REACH := 3.0`
- L38: `const HOLD_DISTANCE := 1.55`
- L39: `const HOLD_MIN_DISTANCE := 0.7`
- L40: `const HOLD_MAX_DISTANCE := 2.4`
- L41: `const CARRY_FORCE := 420.0          # N; heavier props lag and sag, ~40 kg cannot be lifted`
- L42: `const DRAG_FORCE := 520.0           # N at the grab point for heavy furniture`
- L43: `const PUSH_FORCE := 520.0           # N sustained shove into props`
- L44: `const THROW_CHARGE_TIME := 0.6`
- L45: `const OBSTRUCT_DISTANCE := 0.55`
- L46: `const OBSTRUCT_TIME := 0.3`
- L49: `const TAP_TIME := 0.28`
- L140: `func _ready() -> void:`
- L176: `func _register_actions() -> void:`
- L183: `func _save_spawn() -> void:`
- L187: `func set_fov(deg: float) -> void:`
- L191: `func _view_basis() -> Basis:`
- L195: `func _sync_camera(origin: Vector3) -> void:`
- L205: `func _process(delta: float) -> void:`
- L213: `func kick(degrees: float) -> void:`
- L217: `func look(motion: Vector2) -> void:`
- L225: `func rotate_held(delta: Vector2) -> void:`
- L232: `func _unhandled_input(event: InputEvent) -> void:`
- L273: `func _interactor_with(method: String) -> Object:`
- L279: `func change_channel(step: int) -> void:`
- L285: `func touch_throw() -> void:`
- L293: `func request_jump() -> void:`
- L297: `func inspect_object() -> void:`
- L302: `func _physics_process(delta: float) -> void:`
- L377: `func hold_pressed() -> void:`
- L400: `func hold_released() -> void:`
- L418: `func is_pulling() -> bool:`
- L421: `func _update_pull(delta: float) -> void:`
- L432: `func _update_stance() -> void:`
- L443: `func can_stand() -> bool:`
- L453: `func _push_contacts(approach_velocity: Vector3, delta: float) -> void:`
- L492: `func _update_camera(delta: float, sprinting: bool) -> void:`
- L541: `func _fly(delta: float) -> void:`
- L557: `func _end_teleport() -> void:`
- L563: `func reset_motion(spawn_position: Vector3, restore_stance := true) -> void:`
- L602: `func ray_hit(distance: float, mask: int, exclude: Array[RID] = []) -> Dictionary:`
- L608: `func update_target() -> void:`
- L633: `func toggle_hold() -> void:`
- L653: `func grab_object(body: InteriorObject) -> void:`
- L677: `func update_hold(delta: float) -> void:`
- L722: `func release_object() -> InteriorObject:`
- L740: `func throw_object() -> void:`
## game/scripts/debug_menu.gd

SHA-256: `c24772ae77b416f55d3d4297e650e291902096a413daeecf579a066ccfeab04b`

- L15: `const SEQUENCE := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y]`
- L16: `const SEQUENCE_GAP := 2.0`
- L17: `const PANEL_WIDTH := 460.0`
- L18: `const C := preload("res://scripts/canal_settlement.gd")`
- L19: `const NICHOLS := preload("res://scripts/nichols_property.gd")`
- L20: `const W := preload("res://scripts/canal_warren.gd")`
- L44: `func setup(main_node: Node) -> void:`
- L66: `func _input(event: InputEvent) -> void:`
- L90: `func can_open() -> bool:`
- L97: `func show_menu() -> void:`
- L107: `func close() -> void:`
- L115: `func _build() -> void:`
- L175: `func _tab(tabs: TabContainer, label: String) -> VBoxContainer:`
- L186: `func _section(box: VBoxContainer, text: String) -> void:`
- L193: `func _note(box: VBoxContainer, text: String) -> void:`
- L202: `func _buttons(box: VBoxContainer, specs: Array) -> void:`
- L216: `func _check(box: VBoxContainer, key: String, text: String, apply: Callable) -> CheckBox:`
- L227: `func _slider(box: VBoxContainer, key: String, text: String, lo: float, hi: float, value: float, apply: Callable, step := .05) -> HSlider:`
- L256: `func _items_tab(box: VBoxContainer) -> void:`
- L275: `func _draw_gun() -> void:`
- L279: `func _fill_magazine() -> void:`
- L283: `func _toggle_flashlight() -> void:`
- L287: `func _give_everything() -> void:`
- L293: `func _rounds(count: int) -> void:`
- L300: `func _lighting_tab(box: VBoxContainer) -> void:`
- L330: `func _environment() -> Environment:`
- L339: `func _set_exposure(v: float) -> void:`
- L347: `func _moon_lights() -> Array[DirectionalLight3D]:`
- L355: `func _set_moon(v: float) -> void:`
- L362: `func _street_lamps() -> Array[Light3D]:`
- L368: `func _set_lamps(on: bool) -> void:`
- L378: `func _reset_lighting() -> void:`
- L388: `func _player_tab(box: VBoxContainer) -> void:`
- L414: `func _toggle_cellar_lights() -> void:`
- L420: `func _stranger_to_hole() -> void:`
- L426: `func _to_scarecrow() -> void:`
- L431: `func _teleport(at: Vector3, drop := true) -> void:`
- L445: `func _world_tab(box: VBoxContainer) -> void:`
- L455: `func _open_drawer() -> void:`
- L460: `func _restart() -> void:`
- L466: `func _refresh() -> void:`
- L482: `func _update_info() -> void:`
- L492: `func _process(delta: float) -> void:`
