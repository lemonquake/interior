# Interior 0.11 brief: hood up, ammo box and hand-over, scarecrow nearer, a usable Glock

Written 2026-10-06 for the next agent, from the owner's request after 0.10 ("I want these fully implemented by the
next agent"). Read this whole file, then `docs/v10/handoff.md` (the 0.10 hut sequence this builds on) and
`docs/v9/handoff.md` (the stranger and the human pipeline). Everything below is in scope; nothing is optional unless
marked "owner decision", where a default is given so you can build without waiting.

## 0. Ground rules for this project (from the owner and past runs)

- Repo: `A:\3rd Harmonik\interior`, branch `main`. Work directly in the main tree and leave changes uncommitted
  unless the owner asks. 0.9 and 0.10 are also uncommitted: don't revert or reformat them.
- Godot: `.local/tools/Godot_v4.7.2-stable_win64_console.exe` (the project path has a space: quote it). Blender 5.2:
  `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`.
- Before any headless run, parse-check every changed script:
  `godot --headless --path game --check-only --script res://scripts/<file>.gd`. A parse error makes runs hang.
  After adding a new `class_name`, run `godot --headless --path game --import` first. The console build often
  crashes on exit after `--import` (exit 139) once it has finished. That is harmless: check that the `.import` files
  were written.
- Never stop Godot by name (`taskkill /IM`). The owner's editor may be open. Stop only the PID you started (wrap
  runs in `timeout`).
- **Send screenshots as you go** (SendUserFile), not only at the end: contact sheets of real in-game renders. List
  every sent image in the handoff's "Screenshots sent" table.
- **The owner plays the EXE.** After every gameplay or visual change that you report, re-export
  `builds/windows/Interior.exe`. Prove the change with the EXE's own capture
  (`Interior.exe -- --capture-review --capture-views=hut --capture-path=<dir>`). The exported EXE ignores
  `--script`. Say plainly in the reply which build contains what. The owner also asked for the APK.
- Subtle atmosphere: no hard colour seams, no glowing auras. Downloaded models must fit a Davao, Philippines
  setting, and every new third-party asset gets a credit row in `game/licenses/`.
- Runtime-created nodes have no owner, so `find_child(name)` misses them. Use `find_child(name, true, false)`.
- The owner is on a Claude Pro plan. Keep to at most 1–2 sub-agents at medium effort. Wide fan-out kills the
  5-hour window.
- Tests that must stay green (run headless with `--fixed-fps 60`): `hut_story_integration` (48),
  `stranger_integration` (25), `fields_integration` (25), `street_integration` (27), `balcony_integration` (63; one
  throw check is known flaky), `room_integration` (89), `touch_integration` (29, needs `-- --mobile-test`).

## 1. Bug to fix first: the stranger's pickup and talk clips never play

`game/scripts/stranger.gd` asks for clips named `"pickup"` and `"talk"`, but `game/assets/characters/stranger.glb`
names them `interact_pickup` and `interact_talk`. Every `_anim.has_animation("talk" / "pickup")` check fails, so he
**stands still under the scarecrow instead of reaching down**, and calls the player out in `stand_stare`. The 0.10
story test passed anyway because those calls fall back silently.

- Use the real names everywhere (`call_out`, `_start_digging`, `_start_giving`, and `LOOPS`, which must loop
  `interact_talk`).
- Make missing clips loud: a `_require_clip(name)` that `push_error`s, and a test check that every clip name the
  stranger uses exists in the GLB.
- Acceptance: in `hut_views` renders he visibly crouches and reaches at the scarecrow's foot, and gestures while
  calling.

## 2. Hood up: the hooded man's face is hidden

**Now:** `tools/blender/human/build_human.py` builds a black hoodie with the hood *down* (`hood()` makes a fold on the
upper back) and gives him visible side-part hair (`hair()`). His face is fully readable at 1.5 m when he hands over
the ammo (`work/v10/screens/run3/19-received-ammo.png`). The owner calls him "the hooded man / hooded figure".

**Build:**
- Add a hood-up shell in `build_human.py`, made like the other clothes: a closed hood around the skull and the back
  of the neck, built from the body's head and neck region (cut and inflate, roughly 3–4 cm off the scalp; more at the
  crown and back), with a face opening. The front edge (brim) sticks out 8–10 cm past the forehead and comes down to
  the eyebrows, and the sides come forward to the cheekbones. Give it a hem, a seam along the crown, the drawstring
  channel round the opening, and the two white drawstrings hanging from the opening instead of the collar.
- Weights: skin the hood with `skin_to()` like the other shells, then override it: the top and brim 100 % `head`,
  blending into `neck` and `spine.003` / the upper chest at the back and the opening's lower edge, so the hood turns
  with the head but stays on the shoulders.
- Delete the hair mesh, or keep only a fringe that doesn't poke through. No scalp may show through the hood in any
  clip.
- Shadow the face: give the inside of the hood a near-black material, and darken the face itself with a cheap
  occluder: a dark, inward-facing shell under the brim, or vertex-colour darkening of the face skin (multiply about
  0.25 around the eyes and forehead). At night, under the lantern or the moon, the face should read as a dark oval
  with a hint of jaw and mouth. Keep the face lit enough that he isn't a featureless void when he talks. Don't use
  an unlit black disc.
- Keep a `HOOD = "up"` switch (constant or CLI arg) so `-- preview export` can still build the old hood-down look.
- Rebuild: `blender -b --factory-startup --python tools/blender/human/build_human.py -- preview export`, then
  `godot --headless --path game --import`.

**Acceptance:**
- Blender preview sheet (`work/v11/human/`): front, three-quarter, side and back in `idle`, `run`, `gate_grip`
  (he looks up 14°: the hood must not lift off the head) and `interact_pickup` (bent down). The hood never clips
  into the head or shoulders.
- In-game renders: at the gate from the stair, in the hut yard while calling, and at 1.5 m during the hand-over.
  The face is shadowed in all of them.
- `stranger_integration` still passes (the mesh is on outdoor layer 2: check the material count and layers in the
  test).

## 3. An ammo box and a real hand-over

**Now:** nothing is modelled. In `stranger.gd` `DIGGING` waits a timer (the clip-name bug, above), `BRINGING` walks
him back, and `GIVING` plays a talk clip and calls `story.receive_ammo()` after 1.1 s. No box appears.

**Build:**
- **The box:** a weathered 9×19 mm cardboard cartridge box, about 120 × 75 × 40 mm. No real brand: make a generic
  label texture with PIL (off-white or olive card, "9×19 mm", "60", a cartridge silhouette, some wear and a
  water stain). Wrap it in a crumpled clear plastic bag, since it was buried in a wet paddy. Make it in Blender
  (`tools/blender/story/ammo_box.py` → `game/assets/models/story/ammo_box.glb`) with bevelled edges, a lid seam
  and a slightly crushed corner. Keep it under 3k triangles. A downloaded CC model is fine instead if it fits;
  credit it.
- **Hidden under the scarecrow:** place the box at the scarecrow's foot, half-buried and tilted, in
  `hut_house.gd`/`story.gd` at runtime (or in the fields builder; see item 4). It must be invisible from the road,
  so it doesn't give the twist away.
- **New clip `hand_over`**, baked in `build_human.py` like `gate_grip` (`make_loop`, plus an IK helper like
  `add_grip_ik`), 2.6 s, not looped. The right hand comes up from his side, holding a box-sized grip, to 0.45 m in
  front of the chest at about 1.25 m height. The palm faces up and the arm is slightly bent. He leans in a little,
  and his head drops to look at the player's hands. He holds that for about 0.8 s, then withdraws his empty hand.
  Mark the release frame (the extended hold, about 1.2 s) in a comment and a constant. Optionally add `carry_box`, a
  walk with the right forearm raised holding the box close to the chest, for `BRINGING`. If you skip it, use
  `walk` and keep the box at hip height in the hand.
- **In Godot (`stranger.gd`):**
  - DIGGING plays `interact_pickup`. At its lowest point (find the frame where `hand.R` is lowest; put it in a
    constant) the box leaves the ground and is reparented to a `BoneAttachment3D` on `hand.R`, with its offset
    tuned so it sits in the fist. Brush off: one `idle_adjust` beat.
  - BRINGING walks for the last 4 m (not a run), carrying it.
  - GIVING: face the player, play `hand_over`. At the release frame, move the box from his hand to in front of the
    camera and tween it down out of view over 0.35 s (it goes into the player's pocket). Then call
    `story.receive_ammo()` and play the pickup sound.
  - On mobile the same. Keep `RUN_LINE` timing as in 0.10.

**Acceptance:**
- `hut_views` renders: the box at the scarecrow's foot (close shot), in his hand walking back, at full reach in
  `hand_over`, and the frame right after the toast.
- `hut_story_integration`: the box is attached to `hand.R` while BRINGING. `story.ammo` becomes 60 only after the
  hand-over release frame. The box is freed or hidden afterwards.

## 4. The scarecrow near the hut, and a way to follow him there

**Now:** `fields_builder.gd` `_scarecrow()` puts it about 300 m down the road (`_nearest_index(Vector2(66, 300))`,
11 m off the road on a 1 m islet), about 170 m past the hut's footpath (hut path at road sample 108; scarecrow nearest
sample 293). The player can't leave the road, so they wait while he wades. The owner found the run too long.

**Build:**
- Move it in the builder: place the scarecrow about **40 m past the hut's footpath**, on the same (east, `-side`)
  side, about 9 m off the road. That is roughly road sample 108 + 40 (around world (19, 185)). Check the spot with
  `in_pond(p, 6)` and keep it clear of the pond (on the moon side, around road sample 182), the jetty and the power
  poles. Make the islet 2.4 m across so two people fit.
- Re-bake: `godot --path game --script res://editor/bake_fields.gd --resolution 320x180`. **Not `--headless`**: the
  dummy renderer drops MultiMesh data and the rice saves empty. Then re-run `fields_integration`.
- **A path to it:** generalise the hut's runtime causeway (`InteriorHutHouse._footpath()` and
  `_open_road_wall()`) into a reusable helper, e.g. `scripts/footpath.gd`
  (`InteriorFootpath.build(fields, from_road_index, to_point, width)`, returning the route points). Use it for a
  narrow dike from the road to the scarecrow islet, with edge walls and a road-wall gap like the hut path. The
  player can now actually follow him, and he walks the dike instead of wading. Keep wading only if the dike can't
  fit.
- The scarecrow's "turns to face you when unseen" behaviour (`fields.gd` `_scarecrow`) stays. Freeze it while he
  digs (from DIGGING to GIVING) so it doesn't spin during the scene.
- Update `stranger.gd` `_start_leading()` to use the new path. Re-tune `FOLLOW_GAP` (20 m) if it feels wrong at the
  shorter distance.

**Acceptance:**
- `hut_story_integration` gains checks: the scarecrow is within 60 m of the hut path along the road. The real player
  walks from the road onto the islet next to the scarecrow. He reaches the scarecrow in under 25 s of following.
  The digging is filmed from the islet.
- Renders: the new spot from the hut path and from the road, the dike, and him digging with the player beside him.
- `fields_integration` 25/25 after the re-bake, and no empty rice chunks (compare a road render with
  `work/v10/screens/run3/24-road-moon-only.png`).

## 5. The Glock is usable

**Now:** taking it only sets `story.has_gun` and the inventory label; `story.ammo` becomes 60 at the hand-over.
`game/assets/models/story/glock17.glb` is animated: the clip `fire` (16 frames at 24 fps) pulls the trigger, cycles the
slide and throws a round, and its parts are separate nodes (`slide rig _18`, `trigger_21`, `magazine_7`,
`magazine_001_8`, `Cylinder.004_22` = the round). `story_ui.gd` already renders it in a SubViewport for inspection.

**Design (defaults; each is an owner decision you can build now and report):**
- **Ammo:** the gun comes out of the drawer **empty**. Pulling the trigger dry-clicks and shows "It's empty." This
  gives "I'll give you what's left" its meaning. The 60 rounds go to reserve. The magazine holds 17 plus 1 in the
  chamber. The first reload after receiving the ammo loads 17 and racks the slide, so 17 are loaded and 43 are in
  reserve.
- **Equip:** `1` or `G` toggles draw and holster on desktop. On mobile a new **Gun** button appears once the gun is
  owned, and while it is drawn the Throw button becomes **Fire** and a **Reload** button appears. Drawing drops
  whatever prop is held. Pressing Hold (E) on a prop or door holsters first, then acts. Left click fires while it's
  drawn (instead of throw). `R` reloads. `F` (inspect) while drawn opens the existing inspect screen.
- **Not a weapon against people:** there are no enemies, and the stranger has no collider. Shots never hit him.
  Pets (hamsters, fish) are never harmed: the enclosure glass stops the ray and takes a crack decal.
- **Firing:** hitscan from the camera centre, 80 m range, collision mask 2|4. Sub-second semi-auto: one shot per
  click, at most 4 shots/s.

**Build:**
- **`scripts/gun.gd` (`InteriorGun`)**, owned by `story.gd`, carrying the state (`owned`, `drawn`, `mag`,
  `chambered`, `reserve`) and the signals `fired`, `reloaded` and `ammo_changed`. Hook it into `player.gd`:
  `hold_hook`-style gates for fire and throw, and holster on grab.
- **A first-person view model** in its own SubViewport overlay (own world, transparent, camera FOV 55, synced to
  the player's camera bob and sway), so it never clips into walls. It goes in the HUD under the toasts and dialogue.
  Light it to roughly match where the player is: a dim moon blue outside, a warm candle colour in the hut, the room
  colour indoors. Lerp with `InteriorFields.zone_weight` and an indoors flag. Never light it brighter than the
  scene.
- **Arms:** build first-person forearms and hands from `models/generic_body` with `build_human.py`-style code
  (`tools/blender/human/build_fp_arms.py` → `game/assets/characters/fp_arms.glb`). Use dark grey long sleeves; the
  player's outfit isn't defined, so this is an owner decision (default: long sleeves). Bake clips with IK onto the
  Glock's grip: `fp_draw` (0.45 s), `fp_holster` (0.35 s), `fp_idle` (breathing loop), `fp_fire` (0.12 s recoil),
  `fp_reload` (1.6 s: the magazine drops, a new one goes in, the slide is racked), `fp_dry` (trigger only). The
  body's hands are fists, which wrap the grip acceptably. In Godot, attach the Glock to the right hand with a
  `BoneAttachment3D`. Drive the Glock's own `fire` clip with `fp_fire`. For the reload, animate `magazine_7`
  out and in on the Glock in sync with `fp_reload`.
- **Effects per shot:**
  - a muzzle flash: a quick additive card plus a 40 ms omni light (warm, energy about 6, range 6) in the main world
    at the muzzle's world position, so walls light up;
  - a short camera kick (pitch up about 1.6°, back over 0.25 s);
  - the round thrown from the view model;
  - a 3D gunshot on its own bus, with a distant echo outdoors (reuse `night_audio.gd`'s echo approach);
  - an impact by surface (`InteriorSurfaces`): a bullet-hole decal (`Decal`, 6 cm, max 40, oldest recycled), dust
    or splinters (a small `GPUParticles3D` burst, half on Android), and a ricochet on metal;
  - an impulse on any `InteriorObject` hit (about 6 N·s along the ray), and a hit TV stops on static.
  - Water: a splash, no decal.
- **Dry fire:** click sound plus the "It's empty." toast (once per 3 s).
- **HUD:** a small ammo readout bottom-right while drawn (`17 / 43`), hidden when holstered. The inventory line keeps
  "Glock 17 • N rounds", total rounds.
- **Sounds:** extend `tools/assets/fetch_hut_sfx.py`. Find public-domain or CC0/CC-BY pistol recordings on
  Wikimedia Commons (search "pistol shot", "9mm", "handgun"): a dry shot, a magazine out/in and a slide rack. Make a
  far echo tail and the dry click in the script. Credit them in `game/licenses/NIGHT_SOUNDS.md`.
- **Inputs:** add `fire`, `reload` and `gun` actions in `interior._setup_inputs()`, and the buttons in
  `mobile_controls.gd`, laid out so nothing overlaps the existing seven buttons at 1280×720 and at a phone aspect
  (2400×1080). Update the controls text in `interior._show_menu()` for both desktop and mobile.
- **Story hooks:** the gun can be drawn any time after it's taken. "Now... run." doesn't force it. Firing near the
  stranger while he's present does nothing to him (keep it that way).

**Acceptance:**
- New `tests/gun_integration.gd` (headless, `--fixed-fps 60`):
  - draw and holster;
  - empty → dry click + toast, no hitscan;
  - after `receive_ammo()`: 0 / 60 → reload → 17 / 43;
  - 17 shots empty the magazine, then the 18th dry-clicks until a reload;
  - fire-rate cap;
  - a shot at a room prop moves it and leaves one decal;
  - decals are capped at 40;
  - a shot at the hamster enclosure leaves the hamsters untouched;
  - holster-on-grab;
  - Fire, Reload and Gun buttons exist only when they apply (`-- --mobile-test`);
  - no errors in the log.
- `hut_views` (or a new `tests/v11_views.gd`): the drawn gun in the room, the hut and on the moonlit road. Show the
  muzzle flash lighting a wall, a decal close-up, mid-reload, and the mobile layout with the Gun, Fire and Reload
  buttons.
- Add `--capture-views=gun` to `interior._capture_review` (draw, fire once at a wall, save) and run it from the
  exported EXE.

## 6. Finishing

- Version 0.11.0: `game/export_presets.cfg` file and product version, Android `version/code=11` and
  `version/name="0.11.0"`.
- Export both:
  - EXE: `--export-release "Windows Desktop" <abs>\builds\windows\Interior.exe`
  - APK: `--export-debug "Android" <abs>\builds\android\Interior.apk`
  - Confirm with `aapt2 dump badging` (`%LOCALAPPDATA%\Android\Sdk\build-tools\36.0.0\aapt2.exe`).
  - Copy `game/licenses/*.md` into `builds/windows/`.
- EXE proof: `--capture-views=hut` and `--capture-views=gun` from the built EXE. Android look: the same captures from
  the project with `--rendering-method gl_compatibility -- --mobile-test`. Check the hood, the box and the gun read
  well under Compatibility. `story_ui.gd` already dims its inspect lights on mobile for the same reason.
- Write `docs/v11/handoff.md`: what was built and where, tests with counts, the screenshots-sent table, build sizes
  and SHA-256, known gaps. Update the Interior memory notes.

## Suggested order

1 (clip names, about 30 min) → 4 (scarecrow move and re-bake, so later renders are final) → 2 and 3 together (one
Blender rebuild of `stranger.glb` with the hood and `hand_over`, then the box and the Godot hand-over) → 5 (gun:
state and inputs first, then the view model and arms, then effects and sound, then mobile) → 6. Send a contact sheet
after each numbered item.
