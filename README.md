# Interior

By Aljay Leodones. A first-person physics mystery in a recreation of the owner's family room.

Version 0.6 opens the courtyard gate onto a walkable, fog-bound ghost town: empty streets in Davao City with parked Philippine tricycles, an abandoned jeepney, empty street-food carts and the rusted, bent sign of Malasugue Street. The TV now turns on to a "News Order - Davao City" emergency broadcast behind a CRT filter, every other channel is static, and the digital clock shows times that make no sense. Walking uses an adult stride with a head bob locked to the footsteps, which sound different on wood, carpet, tile, concrete, asphalt and grass. Version 0.3 relights and declutters the room, rebuilds prop physics on Jolt (rolling, toppling, physical holding and charged throws) and makes the room an editable scene. Version 0.2 added acceleration and momentum-based prop interactions, a connected three-level hamster playground, aquariums below its stand, and the kitchen, rear entrance and right wall from the owner's additional photographs. Eight supplied family photographs appear in the room's frames.

## Play

Run `builds/windows/Interior.exe`, or install `builds/android/Interior.apk`. Windows has an embedded PCK. The APK is locally debug-signed and includes ARMv7 and ARM64; it is an installable development build, not a Play Store release.

| Action | Windows | Android |
|---|---|---|
| Move / look | WASD / mouse | Left stick / right drag |
| Sprint | Hold Shift | Hold Sprint |
| Jump | Space | Jump |
| Crouch | Hold C | Crouch / Stand |
| Hold or drop; open or close a door; unlock the gate; TV on / off | E | Hold / Drop |
| Push the unlocked gate open | Walk into it | Walk into it |
| Change TV channel (aiming at the TV) | Q or mouse wheel | Throw |
| Throw | Left click | Throw |
| Inspect TV | F | Inspect |
| Notes | J or pause menu | Pause menu |
| Pause / resume | Esc | Pause / Resume |

The navy door opens onto the balcony from the owner's photographs: an aquarium beside the shoe rack, a railing with a frosted floral screen, and concrete stairs down to a small courtyard. Daylight there is lit separately, so the room looks the same while the door is closed. At the foot of the stair, E unlocks the white courtyard gate, but it only opens when you push it. Beyond it, the lane, Malasugue Street and the streets around the block can be walked. Police barricades close the streets at the edge of the play area.

Holding the clock, table plant and small cabinet photo reveals three notes. Inspect the TV and solve its lock, then keep exploring. Restart restores the room arrangement.

Movement builds speed from rest, brakes on the ground and carries momentum through jumps. Crouching changes the collision capsule and checks overhead clearance before standing. Prop pushes account for mass, approach speed, rotation and contact position. Carrying and throwing use bounded forces; objects keep their room and furniture collisions. Wall-mounted original props detach when grabbed. Assemblies stay in their photographed positions until first contact or pickup, then simulate and sleep normally.

Three skinned hamsters wander, use the playground and travel through the external tubes between enclosure levels. Their animation library includes walking, running, sniffing, grooming, rearing, resting, eating and digging. Two lower-shelf aquariums contain swimming fish. Animals and attached playground parts move with the stand and pause with the game.

## Edit and build

Open `game/project.godot` in Godot 4.7.2. `main.tscn` instances `scenes/room/living_room.tscn`: the whole furnished room is regular nodes (props, colliders, lights, environment) with meshes and materials stored as separate files under `game/assets/baked/`, so it can be edited directly in the editor. The game uses GDScript, Jolt Physics at 60 Hz with physics interpolation, Forward+ on desktop and the Compatibility renderer on Android.

The room scene was generated from `scripts/room_builder.gd` (the original `living_room.glb`, `room_manifest.json` and the procedural surroundings). `godot --headless --path game --script res://editor/bake_room.gd` regenerates it and overwrites manual edits, so only run it after changing the builder code. Run `tools/build.ps1 -GodotPath <Godot console executable>` to import, check completed test reports and export both platforms. Use `-TestsOnly` to skip exports. Godot export templates, Java 21 and an Android SDK are required. SDK paths and signing configuration belong in local Godot editor settings; credentials are excluded from Git.

Run the EXE with `--log-file <log path> -- --autoplay --benchmark --quality-high --render-size=1920x1080` for the 60-second rendered camera sweep after a two-second warmup. Sixteen props stay active during the sweep. Use `-- --capture-review "--capture-path=<absolute directory>" --render-size=1920x1080` for room and menu captures. `--mobile-test` exposes the touch interface on desktop.

## Graphics and verification

Low uses 65% 3D render scale without antialiasing or dynamic shadows; Medium uses 85% and 2× antialiasing; High uses full scale and 4× antialiasing. Android starts on Low with a 60 FPS cap; desktop caps at 120 FPS. These are settings, not performance guarantees. Android requires GLES 3, API 24 or newer; the APK targets API 36.

`room/runtime/integration-results.json` records current automated checks. `docs/production-status.md` distinguishes current runtime evidence from historical reviews. The owner's photographs guide the layout, but dimensions remain estimates and unseen geometry is inferred. This is a modeled approximation rather than a measured scan. Physical Android phone performance remains unmeasured.

## Asset sources

The hamster is adapted from Asia Matusik's CC BY 4.0 model, with a new skin rig and animation library. Free CC0 wood and marble textures came from Poly Haven. Other new geometry and surface maps are authored locally. Family photographs are owner-supplied. Attribution and source details are in `game/licenses/ASSET_LICENSES.md` and the asset provenance files. Godot's full copyright notice is included in the game resources.

The previous downloadable [v0.1.0 release](https://github.com/lemonquake/interior/releases/tag/v0.1.0) and `docs/delivery.json` are historical; they do not contain the 0.2 changes.