# Sleep 0.31 — real hands, closer guns, gore, thirteen infected, darker menus

Owner requests (2026-11-16), over three sessions (the first hit the usage limit in the middle of the menu work):

1. With four reference photos: "Improve and polish how the player holds the guns especially the hands not being
   twisted and the fingers in proper place"; zombies "destroyed bit by bit" (hands, elbows, arms, feet, ankles,
   calves, bodies shattering, most of all to the shotgun); a shotgun that behaves "like an actual shotgun with heavy
   metal balls"; at least ten zombie variations with their own behaviour; flesh sound effects "via ElevenLabs MCP";
   "total improvement of the whole UI - make it really creepy and mysterious", blood splatters and drags on the main
   screen, blood dripping from the title; a fast build.
2. "zoom in more on the gun POV so we can somehow hide the hideous looking hands and mostly just the gun."
3. "you ... don't know how Hands look like. Download 3D models of Human hands Left and Right and use them to the
   fullest."

The Windows build at `builds/windows/Interior.exe` is **0.31.0** (1,242,789,624 bytes, SHA-256 `99221e4500b07da9c859938d17fb07f5c7e7b163f407fc9a3b4ecab8658b8eb0`), exported with `python -I tools/export_windows.py` and checked with its own captures (`work/v31/exe/`, `work/v31/exe.sh`). **The Android APK was not rebuilt** (still 0.25).

## What changed

### The hands are real hand models (request 3)
- The hands that were built by script (0.31's first attempt: tubes for fingers) are gone. The player's hands are the
  **Godot XR Tools hands** (DigitalN8m4r3, CC0; a MakeHuman hand, left and right, OpenXR hand rig, nails, skin /
  normal / roughness maps). `tools/assets/fetch_hands.py` downloads them (pinned commit) into
  `.local/downloads/xr_hands`; `tools/assets/prepare_hands.py` writes the three textures the game uses
  (`game/assets/characters/hands/`), the two skin tones mixed to a brown one.
- `tools/blender/human/fp_hands.py` fits each hand to its wrist on the arm rig at a 190 mm hand, takes the finger
  joints from the model (the hinge of each finger from the way the model's finger is already bent), and carries the
  wrist back into the sleeve. `scripts/gun.gd _skin_hands` gives the mesh its textures.
- **Fingers are closed by contact, not by guessed angles.** `-- --capture-review --capture-views=fit` (run by
  `work/v31/fit.sh`) puts each hand on each weapon and, finger by finger, searches every bend that does not go into
  the weapon's own surface for the one that lies closest against it along the finger; the trigger finger, the finger
  along the frame and the thumbs are sent to named places on the weapon instead (`REACH` in gun.gd). The result is
  `game/assets/hand_fits.json` ("<weapon>:<side>:<pose>"), which the game reads; `HAND_POSES` are only the general
  poses (relaxed, magazine, racking, a flat hand).
- **The Glock is its real size.** The model was 173 mm from tang to muzzle; a Glock 17 is 204 mm, and a real-size
  hand swallowed it. `tools/scale_glb_root.py` scaled it in place (backup `work/v31/glock17_v30_backup.glb`); the
  sights, grip and slide travel in gun.gd and the arm builder follow.
- The right hand sits where a hand does: the web between thumb and index finger in the hollow under the beavertail,
  the knuckle line down the grip, the hand come round the back of the grip so the wrist is behind the gun
  (`right_on_grip` in `tools/blender/human/build_fp_arms.py`). The left hand is its mirror image, canted, with its
  index knuckle under the trigger guard. Under a handguard or a pump the left palm is underneath, the fingers' first
  bones across the bottom and the rest up the far side.
- The sleeves are slimmer and stop just short of the wrist, as in the owner's pistol reference.

### The weapons are framed closer (request 2)
- The hands and weapon are drawn through a lens half as wide as the world's (`VIEW_SCALE` .5, it was .78) and every
  weapon is carried lower (`hip_at` in `PROFILES`): at the ready the screen shows the weapon's top and the hands are
  under the frame's edge. With the sights up the pistol is held further out and the shoulders drop (`ads_drop`).

### Gore, the shotgun, the infected, sounds (request 1, done in the first session)
- `scripts/zombie_gore.gd`, `zombie.gd`: hands come off at the wrist, forearms at the elbow, feet at the ankle, shins
  at the knee; the chest and belly tear open in stages and then come apart; what is left crawls, limps or dies by
  what it has lost.
- The shotgun fires nine 8.4 mm balls (00 buck) at about 400 m/s, each with its own speed, in a pattern an inch wide
  per yard; a ball goes through a limb into what is behind it, stops in a trunk and skips off stone and steel.
- Thirteen kinds of infected, each with its own behaviour (`KINDS` in `scripts/zombie.gd`): shambler, limper, freshly
  turned, runner, rager, leaper, slow-witted, crawler, lurker (lies among the dead), brute, twitcher, screamer and
  stalker (does not move while it is looked at), all in the debug menu's Zombies section.
- Nineteen flesh sounds (hits, wet hits, tears, bone, parts landing, bodies falling). **The ElevenLabs connector was
  not available in any of the sessions**, so `tools/gore_sounds.py` synthesises them into named files that a
  generated set can replace one for one.

### Menus
- The main screen has blood on it: `tools/ui_menu_blood.py` composes `assets/ui/menu_blood.png` from the game's own
  realistic liquid graphics (a spatter with runs in the upper right, a drag along the bottom, a pool off the corner),
  drawn thin over the street, the left of the screen clean.
- The title bleeds: `scripts/ui_blood.gd` (`InteriorBloodTitle`) draws a run under each letter, one still creeping
  and letting go of a drop now and then. The loading screen has the same title.
- Windows (Pause, Options, Notes) are near black with a dark red edge and a wet, running top edge; the entry under
  the pointer is blood red.

## Checks
- `python -I tools/run_tests.py`: all 25 integration tests pass (17 report "pass"; the other 8 print an older report line the runner shows as NO REPORT: basement 57/57, canal 57, debug menu 39, gun 42, hut story 75, Nichols 50/50, night 28, warren 87/87, zombies 107, none with a failure). Never run the suite while assets are being re-exported or imported: half the tests then end without a report.
- EXE captures, no script errors: menus (home, Options: centred, whole), the hands' views of all four weapons, the gun sequence (room, hut, road, street, house), the infected sequence.
- EXE start-up: loading screen at 1.2 s, menu at 9.6 s (0.30: 8.1 s; the hand textures and fits are read at start).
- Not measured again: frame rate in play (nothing in the frame loop changed; the fit runs off line).

## Screenshots
`work/v31/exe/sheet-menus.jpg`, `sheet-hands.jpg`, `sheet-gun.jpg`, `sheet-zombies.jpg` (from the EXE); `work/v31/hands/close-pistol.jpg`, `close-rifle.jpg` (the holds from outside); `work/v31/pov/j4.jpg` (sent to the owner during the run).

## Open
- The pistol's reload and the long guns' reloads use general finger poses (not fitted); the hands there are real
  but the fingers are approximate.
- With the pistol's sights up, both wrists are in the lower middle of the picture. That is what a two-handed hold
  looks like from behind, but it is the one place the hands are prominent.
- The debug menu, the notes and the story screens were not restyled.
- No flesh sounds from ElevenLabs (see above). The Android APK was not rebuilt (still 0.25). Nothing has been
  committed to git since 0.8.
