# 0.43 handoff: loading on other PCs, sound options, Low default, blood and throws, grenades, crawl

Owner's request (2026-11-19): mute all sound while testing; Options volumes per kind of sound; "thoroughly and utterly"
fix the loading screen that never finished on every other PC; package it like Aetherion; Low graphics by default;
better performance, especially co-op; blood and wounds on hit; bodies blown away by shotgun / sniper / grenades;
grenades with "fire in the hole"; a real crawl for downed players and a real crouch for Dodong Sikma; build the game
differently.

## 1. The loading hang (root cause found and reproduced)

- Reproduced on this PC by moving the shader caches aside (`%APPDATA%\Godot\app_userdata\Sleep` ->
  `Sleep.devcache-bak`, 310 MB of shader + Vulkan pipeline cache): the EXE and the project both froze for good
  right after "boot: menu on screen", 3 runs out of 3, with 16 or 4 CPU threads.
- Cause: `boot.gd` handed all 2,623 preload files (295 materials, 765 meshes, 252 models, 27 shaders...) to
  `ResourceLoader.load_threaded_request` at once. With no shader cache the materials compile shaders on the worker
  threads while the main thread waits on them: Godot deadlocks and the main thread never draws another frame. On the
  owner's PC the warm cache made the race window tiny, so it always loaded there and nowhere else.
- Fix (`scripts/boot.gd`): only images and sounds (pure data) go to worker threads, four at a time; everything that
  can compile a shader is read on the main thread in 14 ms slices, so the bar keeps moving. A file stuck on a thread
  for 8 s is read on the main thread instead. Cold start now: ~21 s in the project (was: never); warm ~15 s.
- `--serial-preload` reads everything on the main thread (diagnosis).
- If loading ever stops anyway, the loading screen says so after 75 s and shows the log path
  (`loading_screen.gd _check_stuck`); a main script that fails to compile is reported at once (`boot.gd _enter`).

## 2. Packaging, Aetherion-style ("build it differently")

- Aetherion's release is `Aetherion.exe` + `Aetherion.pck` side by side (export preset "Windows Release",
  `embed_pck=false`), not one 1.2 GB EXE. Sleep now ships the same way: `builds/windows/Interior.exe` (small) +
  `Interior.pck`, plus `Sleep-0.43.0-windows.zip` (the folder to share; both files must travel together).
- The export bakes shaders into the package (`shader_baker/enabled=true`), so a PC that never ran the game skips
  most first-start shader compiling. The baker needs a rendering device: `tools/export_windows.py` now exports with
  a window (not --headless; `--headless` still possible).
- `application/*_version` 0.43.0.

## 3. Sound

- `scripts/settings.gd` (autoload `GameSettings`): `user://settings.cfg`, sound categories as buses under Master:
  Guns, Effects, Zombies, Voices, Background. Existing buses are routed (Gun -> Guns, Night/Wildlife -> Background,
  Steps -> Effects); players left on Master are sorted by the script that owns them when they enter the tree.
- Options: "Sound" sliders (All sound + the five), kept between runs. Graphics level, frame cap, head bob and
  fullscreen are kept too.
- Every run with game arguments (`-- --anything`: tests, captures, audits, bakes) or `INTERIOR_MUTE=1` is silent;
  `-- --sound` keeps sound for such a run.

## 4. Graphics and performance

- Low is the default (saved choice wins). Scripted tests (`--script`) keep the old High default they were written for.
- Low now also turns the moon shadow off and draws less far (`RANGE_SCALE` .5, trees 70 m): ~400 fewer draw calls.
- Measured co-op (RTX 4060 / Ryzen 7 5700X, 1600x900): Low and High give the same frame rate: the game is CPU bound.
  Scripts are only ~3 ms a frame (`tools/prof_frame.py apply|revert` + `-- --prof`, prints INTERIOR_PROF);
  renderer CPU ~3.5 ms, GPU ~3 ms; physics 7-15 ms with ragdolls. Ragdolls were left alone (owner's rule).
- `tests/coop_perf.gd` rows now include render_cpu_ms / render_gpu_ms / objects.

## 5. Blood, wounds, throws

- Blood spray denser and darker (it read as a faint pink puff), more drops, bigger wound marks. Co-op infected now
  get wound marks that stay on the struck part (`InteriorBlood.mark_wound`); they had none.
- `InteriorZombie.blow` (shared by solo zombies and co-op figures): a heavy blow (knock summed per instant above 140)
  throws the whole body. Measured: buckshot point blank 6.2 m, sniper 2.4 m, grenade 5-11 m with limbs torn off.
  A dead-on-its-feet zombie hit that hard falls at once instead of staggering. Corpses are thrown too.
- `tests/zombies_integration.gd` buckshot check now expects 2-9 m (was "a step or two").

## 6. Grenades (`scripts/grenade.gd`, key 5)

- Hold 5: pin out (click), fuse 3.6 s runs while held; let go to throw (sights up: underhand lob); held too long it
  goes off in the hand. Bounces, rolls. Blast: fireball + smoke flipbooks, flash, dirt, sparks, scorch decal, bang
  (+ far tail), lens shake, glass broken within 7.5 m, props thrown, zombies within 10 m with a clear line wounded,
  torn and thrown (kill radius 4 m); the player is hurt too. Senses hear it.
- Shout: "Fire in the hole!" in the squad voice (new line `fire_in_the_hole` in `assets/audio/voices/lines.json`,
  Windows placeholder voices made by `tools/squad_voices.py --engine sapi`, like every other squad line until an
  ElevenLabs key is given). Solo uses Aljay's voice.
- Co-op: the thrower simulates and deals the damage through the same `shot` path as rounds (host keeps the count);
  `session.grenade_out` / `grenade_boom` show it to everyone; `blast_hurt` takes blast damage off a player on the
  host. Everyone starts with 3; an ammo pickup adds one when you have fewer than 2.
- Debug menu: "Summon 10 grenades"; Arsenal adds 10. HUD: "N frag" after the ammo while a gun is out.
- Assets from the owner's Aetherion Project (`game/assets/grenade/`): frag_grenade.glb + texture (Blender script
  there), explosion/smoke flipbooks (made from code there), grenade_explosion1.ogg, bomb_explosion.mp3 (from
  Aetherion's audio folder; provenance as recorded in that project).
- Review: `-- --capture-review --capture-views=grenade --capture-path=<dir>` (also shotgun and sniper throws).

## 7. Crawl and crouch

- New clips in `zombie_anims.glb` (all characters share it): `crouch_walk` (the hooded man's, from
  `build_human.make_crouch_walk`), `crawl` and `down_idle` (new, `tools/blender/human/crawl_clips.py`: armature-space
  turns over the idle pose, face down, elbow crawl). Previews: `tools/blender/human/crawl_preview.py` ->
  `work/v43/crawl/`. Rebuild: `blender -b --factory-startup --python tools/blender/human/build_zombies.py -- export
  only=anims`. The old library is kept at `work/v43/zombie_anims.before.glb`.
- Dodong Sikma under the fallen roof plays `crouch_walk` (he was squashed to 61 % height).
- Downed in co-op: the player is not frozen any more; they crawl (eye 0.36 m, 0.55 m/s, no gun, no grenades); the
  host accepts their moves; others see the fall, then `crawl` or `down_idle`. Bots lie in `down_idle`.

## Proof on a "fresh PC" (the exported game, caches removed)

| Run (no shader / pipeline cache) | Old 0.42 EXE | 0.43 EXE |
|---|---|---|
| 4 CPU threads | hung for good after "menu on screen" | menu (world done) at 17.9 s |
| 16 threads | hung | 15.1 s |
| 4 threads again | - | 18.1 s |
| 2 threads | - | 27.1 s |

The early menu (Play / Options / Quit) is usable from ~1.3 s as before.

## Tests

`INTERIOR_MUTE=1 python -I tools/run_tests.py`: 34 of 35 pass. `upgrade_integration` reports the restarted scene one
node off (9788 vs 9787); a census of both shows it is only the menu (the first instance is on the pause menu with 5
buttons, the restarted one on the home menu with 4 buttons and 2 spacers), no leaked world nodes. 0.43 does not
touch those menus; it was not run in 0.42 so I cannot say when it began.

Reviews: `--capture-views=grenade` (work/v43/grenade), `tests/coop_down_views.gd` (work/v43/coop_down: survivors
crawling / lying, the crouch walk on a figure, the downed player's own view at eye 0.36 m crawling, a grenade into a
co-op crowd). A limb torn off by one fragment used to be looked up again by the next (script error); fixed.

## Open

- Downed crawl and crouch checked in a scripted co-op scene with AI squadmates, not in a real two-PC match.
- The grenade shout is the placeholder Windows voice (as all squad lines).
- The CPU cost of physics with many ragdolls remains the main limit on weak CPUs.
- The owner's old shader caches are in `%APPDATA%\Godot\app_userdata\Sleep.devcache-bak` (310 MB, safe to delete).
