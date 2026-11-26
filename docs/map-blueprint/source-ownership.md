# Source ownership and focused checks

Read README.md first. Source-index.md lists every function/constant declaration and hashes the files used. These paths are relative to the repository root, not to this documentation directory.

| Area | Persistent source | Focused checks |
| --- | --- | --- |
| Startup and hierarchy | game/main.tscn; game/scripts/interior.gd | Cold source startup; room_integration.gd |
| Living room + original props | game/scenes/room/living_room.tscn; game/assets/room_manifest.json; game/scripts/room_builder.gd | room_integration.gd, room_furnishings.gd |
| Kitchen / walls / navy door | game/scripts/room_surroundings.gd; room_furnishings.gd; baked living_room.tscn | surroundings_integration.gd, room_furnishings.gd |
| Balcony / stair / courtyard | game/scenes/balcony/balcony.tscn; game/scripts/balcony_builder.gd, balcony.gd | balcony_integration.gd, street_integration.gd |
| Studio | game/scenes/studio/studio.tscn; game/scripts/studio_builder.gd, studio.gd, sliding_door.gd | Surroundings/upgrade tests plus targeted traversal |
| Base town | game/scripts/neighborhood_builder.gd; baked balcony scene; neighborhood.gd | street_integration.gd, neighborhood_decay_integration.gd |
| Gates / knocks / door objects | neighborhood_interactions.gd, neighborhood_usable.gd, push_gate.gd, neighborhood_encounters.gd | neighborhood_interactions.gd |
| Perimeter / exits / route hints | town_siege.gd; town_horror.gd; siege assets | siege_integration.gd, world_audit.gd |
| Canal and crossings | canal_settlement.gd; canal kit assets; canal_bank.gdshader | canal_integration.gd, canal_review.gd |
| Warren | canal_warren.gd, warren_door.gd, warren_usable.gd; shared Canal surfaces | warren_integration.gd, warren_review.gd |
| Nichols grounds and house | nichols_property.gd; assets/models/nichols/house/layout.json; house GLBs; tools/blender/nichols/build_nichols.py | nichols_integration.gd, nichols_review.gd |
| Basement and tunnel | nichols_basement.gd; same layout.json basement section; tools/blender/nichols/nichols_basement.py | basement_integration.gd, basement_review.gd |
| Fields / road / pond | fields_builder.gd; fields.gd; baked scenes/fields/fields.tscn | fields_integration.gd, night_route_audit.gd |
| Hut / dike / pickups | hut_house.gd; hut_usable.gd; story.gd; runtime children of Fields | hut_story_integration.gd, gun_integration.gd |
| Hooded man / progression | stranger.gd, stranger_cutscene.gd, story.gd; hut routes | stranger_integration.gd, siege_integration.gd |
| Loose props / physical chairs | physics_object.gd, prop_colliders.gd, loose_props.gd | physics_integration.gd, prop_spawn_audit.gd |
| Player clearance | player.gd; world_audit.gd query approximations | movement_stress.gd, world_audit.gd |
| Debug navigation | debug_menu.gd | debug_menu_integration.gd |


All bare GDScript names in the table are under game/scripts, except checks, which are under game/tests. Review/capture scripts may need rendering instead of --headless. This handoff ran a cold runtime export and world_audit.gd; the other listed tests are recommendations for future edits, not newly claimed passes.

## Collision and render layers

From builder code, outdoor static colliders commonly use collision_layer=2 and collision_mask=5. world_audit.gd queries mask 6. Room objects, player and door bodies have their exact current masks in runtime-scene.json. Do not confuse collision bits with visual layers: exterior visuals commonly render on mask 2, room/studio on 1, carried props may render on 3, Nichols interior on 1024, Nichols special shadow geometry on 2048, basement on 4096, and architecture-only beam raycasts on 524288. These are bit-mask values, not array indices.

The player nominal standing/crouching heights are 1.70/1.00 m, eyes 1.58/.88 m; walking speed 2.45 m/s, sprint 4.7, crouch 1.2. Hold/interaction reach is 3 m. A wall opening that admits the audit's reduced query capsule still needs the actual player checked.

## Original source versus current state

The saved scenes are current editable snapshots of older procedural builders. The README explicitly warns that rebaking the room overwrites manual edits. Current runtime code then replaces gate geometry, cuts ground, adds regions and creates gameplay objects. For precise object placement, consult the current baked scene and runtime node basis; consult the builder only to understand how it was authored. The historical room/room-layout.json, older docs, and prior screenshots can be visually useful but are not independent measurements of today's scene.

## Suggested handoff request

> Read docs/map-blueprint/README.md, then area-guide.md and location-register.md. Use the reference IDs to locate the requested part of the existing Sleep/Interior world. Match the current runtime node path and its persistent source. Preserve the coordinate convention (+Z north, Y up), the vertical connections, gated/crouch passages, physics and visibility layers, and unrelated working changes. Before editing a baked scene, check whether a runtime builder owns that geometry. Do not infer playable interiors from house shells or walkable ground from scenery. After the edit, run the focused area test and verify the actual player route. If a build is requested, update builds/windows/Interior.exe.
