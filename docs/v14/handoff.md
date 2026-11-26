# Interior 0.14: darker neighborhood and ammo route

Updated 2026-10-07. Changes extend the existing working tree; the photographed room and baked fields were not regenerated.

The exterior uses weaker moonlight, much less sky fill, darker ambient light and haze, and subdued clouds. The three surviving street lamps illuminate smaller areas and occasionally fail twice before recovering, each on its own 9–24 second interval. Their visible lenses follow their actual brightness, including the story blackout. Flicker stops during pause. All neighboring window batches are dark and non-emissive. Indoor lighting is restored when returning through the doorway.

New 1K CC0 Poly Haven surfaces replace plain vehicle materials and the old plaster base: Rusty Metal 04 and Damaged Plaster by Amal Kumar, and Rough Plaster Broken by Rob Tuytel. Rust, pitting, chipped paint, dusty upper surfaces and mud affect 72 surfaces across 12 tricycles, jeepney, carts and drums. Gates, grilles, shutters and trim use the new rust maps too. Source URLs, checksums and credits are in `game/licenses/ATMOSPHERE.md` and the texture directories' `source.json`. Downloads are reproducible through `tools/assets/fetch_neighborhood_wear.py`.

Existing community atmosphere systems remain in use: Particle Scene Compositor, Profesor Shader's wind-driven particles, alghost's moving ground mist, and VelvetKatana's cloud base. All run locally. Forward+ uses volumetric mist; Compatibility keeps the particle/haze fallback.

The hut path is now 2.3 metres wide, the ammo dike 2.1 metres, and the scarecrow's flat island 4 metres across. Seven obstructing plants were removed, including the tree by the hut and bamboo crossing the footpath. Rice and grass are cleared from the wider route. Path rendering and collision share their top vertices, triangle winding is corrected, and the road and island boundary openings allow the wider approach. The man uses the dry route to bring the box back and leave, and can go around the post to reach a player standing on any side of the island.

Dialogue is exactly:

1. "You have to hurry!"
2. "Your wife and 2 daughters are with the association, so you can breathe easy."
3. "Now, I have to give you something. Please follow me."
4. After the ammo: "Now, take these with you and go back! Hurry, before they notice!"

Returning to the courtyard no longer completes the alarm sequence. The player must enter the house and fully close the navy entry door. All four siren streams then stop, their fade tweens are cancelled, and reopening the door does not restart them.

## Verification

- Night revision: 28 checks, including continuous real-player walks both ways, side tracks, circle around the scarecrow, matching ground/collision heights, triangle orientation, eight island handoff positions, road handoff, independent flicker, pause, and dark windows.
- Hut story: 63 checks for key, drawer, gun inspection, exact dialogue sequence, following, ammo handoff, blackout, returning indoors and stopping every siren.
- Atmosphere transitions: 15 checks.
- Neighborhood geometry and movement: 32 checks.
- Street behavior: 27 checks.
- Balcony/entry door behavior: 63 checks.
- Native Forward+ and Compatibility visual reviews at 1600 × 900 include the street, tricycles, hut path, dike, island, dialogue and alarm blackout. Final plaster has an additional street-wall review.
- Total: 228 passing automated checks. `work/v14/verification.json` records the reports and confirms the ZIP contains the exact final executable.
- Exported Windows 0.14.0: six neighborhood views and eight hut/story views completed with no runtime or shader errors. Evidence: `work/v14/exe-neighborhood.log`, `work/v14/exe-hut.log` and adjacent image directories. Build hashes are in `builds/SHA256SUMS.txt`.

Logs and screenshots are in `work/v14/`. Initial iterations are retained separately from final runs. One earlier accelerated story run reported audio resources at shutdown; the final story run completed without that diagnostic. Compatibility was tested on the desktop RTX 4060; physical Android performance was not measured.

The Windows executable is `builds/windows/Interior.exe` (0.14.0); the Android APK remains the previous 0.12 build. Built-in exported-game reviews use:

```text
Interior.exe --log-file <log-file> -- --capture-review --capture-views=neighborhood --capture-path=<directory> --render-size=1600x900
```

Source checks use Godot 4.7.2:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tests/night_revision_integration.gd
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tests/hut_story_integration.gd
```
