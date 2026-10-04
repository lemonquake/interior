# Interior production status

Interior by Aljay Leodones recreates the owner-approved estimated room with a native Godot physics mystery, Windows EXE, and Android APK.

Function approval: the owner approved the estimated layout and all 24 prop references. Form approval: the owner said “I like it” while reviewing the final Blender room. Runtime approval: the owner explicitly replied “Approve game and publish.” All human review gates are now approved.

Final source: `room/living_room.blend`. Runtime: `game/assets/living_room.glb` and `room_manifest.json`, 48 movable assemblies, 73,784 triangles. Technical corrections after Form approval add the photographed black side rack, adjust its supported bins/plants, separate loose components, and refine collision supports. These corrections are documented in the Runtime review.

Both exports are built. The actual Windows EXE was captured and measured on the RTX 4060. Android ARM was installed and tested in the Android 16 emulator with hardware GLES. Its software driver rejected engine shader defaults. Real APK taps also exposed menu and multi-finger button handling issues, now corrected. All 104 assertions and a four-second arrangement-settling check pass.

The 60–120 FPS goal is met in the measured desktop scenario; physical low-tier phone FPS remains unmeasured. Android has conservative defaults and optional higher graphics. Unsupported GLES hardware remains unsupported.

Custom meshes and free CC0 textures replace paid Meshy generation. The upstream skill validator's hardcoded Meshy and browser fields do not fit this method. Its raw outputs and the adapted native-runtime checks are retained. Zero paid generations or credits were used.

Java, SDK paths, signing credentials, local tools, and build binaries are outside Git source tracking. Windows uses an embedded PCK. Android is locally debug-signed. Downloadable builds can be published in a GitHub release after the playable-game review.
