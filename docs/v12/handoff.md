# Interior 0.12: downloaded run and atmosphere

Updated 2026-10-06. Changes build on the existing uncommitted 0.9–0.11 work; no scene rebake or history reset was performed.

## Changes

- The hooded man's `run` is the owner's `models/generic_body_animation/animation_run.glb` / `Running`, retargeted through the two skeletons' rest poses. The downloaded source is unchanged. Existing character geometry, textures, skin and 37 other clips are retained. Playback follows travel speed, and footstep contacts follow animation time. See `docs/stranger-run.md` for the reproducible Blender pipeline and source hash.
- Actual third-party runtime dependencies: Particle Scene Compositor by ChiprChopr and Profesor Shader's wind-driven particle simulation, both MIT licensed. They drive room dust, window flecks, windblown seeds, low ground wisps and moths around lamps. Pinned source commits and full notices are in `game/licenses/ATMOSPHERE.md` and the two adjacent MIT text files, included in both exports.
- Particle pools are fixed, distance culled and faded by location. High configures 417 particles in 11 groups, Low 121; only nearby groups run. Exterior sprites exclude the hut. Forward+ has soft depth intersections; Compatibility omits depth sampling and reduces the counts. Animation and compositor clocks pause with gameplay.
- Doorway exposure, ambient colour and grading adapt gradually, including rapid back-and-forth crossings. Changing graphics quality outside preserves the outdoor grade and correctly updates volumetric mist without requiring movement. Ground mist has slightly more density; distance haze is slightly closer. Lamp ballast dips are slow and irregular, with normal exploration strobing removed.
- A restrained vignette and faint grain sit behind the HUD, with a gradual increase during the return-home alarm. Input and UI text remain unaffected. The FPS counter is hidden by default; F3 or `--show-fps` reveals it.
- Wildlife and regional reverb now fade smoothly. The hut shelters and muffles exterior sound. Occasional quiet intervals and the alarm reduce wildlife independently of dialogue, footsteps, wind and sirens. The house has a faint room tone and infrequent positional wood creaks.
- Landing compression, breathing and sprint FOV are bounded and gradual. The menu offers Camera motion: Normal / Reduced / Off. This setting affects presentation; crouching and weapon recoil retain their existing behavior.

## Verification

| Check | Result |
|---|---|
| Imported downloaded run: duration, loop, foot travel and height | 6 passed |
| Stranger route, pursuit, pause and hut arrival | 26 passed |
| Particle source instances, budgets, zone re-entry, pause, dark lamps, hut exclusion and teardown | 27 passed |
| Atmosphere transitions, quality changes, pause and HUD ordering | 15 headless / 16 Forward+ passed |
| Native mixer and camera feel | 20 passed; hut exposure 0.36, quiet wildlife −12.55 dB, landing compression 2.08 cm |
| Hut story and hand-over | 57 passed |
| Gun behavior | 41 passed |
| Room | 89 passed |
| Movement stress | 260,111 checks over 10,000 physics steps passed |
| Mobile touch and restart | 29 passed |
| Rendered review | Six locations each on Forward+ and Compatibility; no shader or runtime errors |
| Exported Windows smoke | Eight hut/story captures completed; no runtime errors |
| Android package | Version 0.12.0 / code 12, ARMv7 + ARM64, debug signature verified; notices present |

Root logs and rendered screenshots: `work/v12/`. Native sound/camera report: `work/atmosphere-audio/check.stdout.log`. Retarget facts and pose images: `work/run-fix/`. Additional tests are in `game/tests/stranger_run.gd`, `particles_integration.gd`, `atmosphere_integration.gd`, `atmosphere_feel_check.gd`, and `atmosphere_review.gd`.

The gun test reports ObjectDB/resources still in use at process shutdown after its successful checks; the atmosphere, particle and exported-game checks exit cleanly. Physical phone performance has not been measured. Compatibility review ran on the desktop GPU; it is not a phone test. No new performance guarantee is claimed.

## Builds and reproduction

- `builds/windows/Interior.exe`: Windows release with embedded resources.
- `builds/android/Interior.apk`: debug-signed Android development build.
- `builds/Interior-Windows-x64.zip`: Windows executable and notices.
- `builds/SHA256SUMS.txt`: current artifact checksums.

Use Godot 4.7.2. Tests use `--headless --fixed-fps 60 --path game --script res://tests/<name>.gd`, except the native audio test and rendered reviews, which require a native renderer. For review screenshots: `--path game --script res://tests/atmosphere_review.gd -- --out=<absolute output path>`. Add `--rendering-method gl_compatibility` before `--` and `--mobile-test` after it for the mobile renderer/UI review.
