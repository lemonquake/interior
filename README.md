# Interior

**By Aljay Leodones.** A first-person physics mystery in a recreation of the owner's living room.

The Blender model, Godot game, Windows EXE, and Android APK are built. Function and Form reviews were approved; review of the playable game is pending before GitHub publication. Open `room/runtime-review.html` for actual exported-game screenshots and measurements.

The room uses owner-approved estimated dimensions: 6.6 × 5.4 × 2.9 m. Unseen walls, ceiling, and object backs are inferred from one photograph. The layout and object identities follow the reference; fine shapes and materials differ. This is a procedural approximation, not a measured scan.

## Play

Run `builds/windows/Interior.exe`, or install `builds/android/Interior.apk` on Android. Both are self-contained. The APK is locally debug-signed for installation; it is not a Play Store release. Choose Low, Medium, or High in the menu.

| Action | Windows | Android |
|---|---|---|
| Move | WASD; Shift to move faster | Drag left side |
| Look | Mouse | Drag right side |
| Hold or drop | E | Hold / Drop |
| Throw held object | Left click | Throw |
| Inspect TV | F | Inspect |
| Notes | J or pause menu | Pause menu |
| Pause or resume | Esc | Pause / Resume |

Hold objects to discover three notes, then inspect the TV and solve its lock. Continue exploring and rearranging the room afterward. Restart restores the original room arrangement.

The 48 movable assemblies include furniture, plants, photos, loose cushions, a toy, and a keyboard. Assemblies contain small parts such as petals and fan wires. Wall-mounted props detach when grabbed. The structural room shell stays fixed.

Furnishings preserve their initial pose until grabbed, pushed, or touched by an active body. They then simulate normally, can sleep, and recover if they leave room bounds. Held objects retain room and furniture collisions; a bounded velocity servo moves them without teleporting. Throwing uses the same launch speed across masses.

## Edit and build

Open `room/living_room.blend` in Blender 5.2.1, or `game/project.godot` in Godot 4.7.2. The Godot project uses GDScript and the Compatibility renderer. Import the project before running it.

To regenerate the runtime asset from the final Blender source, run Blender in background mode with `--python tools/export_room.py`. Function and Form approval records are required by the exporter. Initial study and material scripts are historical production stages; they overwrite stage artifacts, so use the final `.blend` for further edits.

Run `tools/build.ps1 -GodotPath <Godot console executable>` to import, verify, and export both builds. Use `-TestsOnly` to skip exports. The script checks completed JSON test reports, not just process exit codes. Godot export templates, Java 21, and an Android SDK are required. Configure SDK and debug signing in Godot editor settings outside the repository. Private keys and local credentials are ignored.

Run the EXE with `--log-file <log path> -- --autoplay --benchmark` for the bounded rendered stress test; add `--quality-low` or `--quality-high`. Capture the actual EXE with `-- --autoplay --capture-play "--capture-path=<absolute directory>"`.

## Graphics and measurements

The runtime room has 73,784 triangles, shared meshes, compound collisions, 1K primary textures, 512-pixel textiles, and small portrait inserts. Static vertex lighting is baked from the same two fixture positions used by runtime lights. Movable furniture does not cast baked shadows into the room.

Android starts on Low at a 60 FPS cap. Low uses 65% 3D render scale, no antialiasing, and no dynamic shadows. Medium uses 85% scale and 2× antialiasing; High uses full scale and 4× antialiasing. Desktop caps at 120 FPS and adds dynamic shadows on High. VSync and display refresh rate can cap visible FPS lower.

`room/runtime/desktop-performance.json` contains the final exported EXE measurements on an NVIDIA RTX 4060 at 1280 × 720: a two-second warmup and a 20-second camera sweep with sixteen active furnishing bodies. This is a bounded test, not an exhaustive worst case or a guarantee on other hardware.

All 104 integration assertions and the four-second settling check pass. The ARM APK was installed in an Android 16 emulator and tested for Play, movement, look, clue grabbing, throwing, Pause, Resume, and Low/High settings. The software graphics emulator failed shader compilation; hardware graphics passed. No physical low-tier Android phone has been measured.

The APK includes ARMv7 and ARM64, minimum Android 7/API 24, target API 36, and requires GLES 3. Low quality reduces workload but cannot make unsupported hardware compatible. See [Godot's exported-project requirements](https://docs.godotengine.org/en/stable/about/system_requirements.html#exported-godot-project).

## Sources and review records

Meshes and custom materials were authored locally. Free CC0 wood and floor marble textures came from Poly Haven. Miniature portraits use the owner-supplied photo. See `room/asset-provenance.json` and `game/licenses/ASSET_LICENSES.md`. Godot's full bundled copyright notice is included in the game resources.

`room/milestone-reviews.json` records human Function, Form, and Runtime approval only after an explicit owner response. The Build 3D Game Rooms validator assumes paid Meshy assets and a browser runtime; its raw output is preserved. Documented project checks adapt those assumptions to free procedural Blender assets and native Godot builds while retaining human review gates. No provider task, credit spend, or approval is fabricated.
