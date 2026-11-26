# Sleep 0.32 — the weapon, not the hands

Owner request (2026-11-16): "just mostly show the gun because the hands are atrocious ... find a way to make this
still look beautiful despite showing mostly just the gun pointing. The point of the POV of my game is that he has an
Action camera attached to his forehead ... it is kinda zoomed in a bit for the gun." The first line of the same
message asked to tighten the shotgun support hand and the reload finger poses; the owner then said "forget the shotgun
changes", and later "the guns are still not zoomed in enough" (said of the 0.31 build, the 0.32 export having been
cut off).

## What changed

### The frame's lower edge crops the hands (`scripts/gun.gd`)
- `_hands_over_edge`: every frame, the places on both hands that stand highest (wrist, palm, knuckles, the first
  finger bones: `HAND_SPOTS`; for the hand under a long gun also where its fingers and thumb end: `GUARD_SPOTS`) are
  measured against the lower edge of the picture where the body camera's lens puts it, and the weapon goes down by
  what is over (`_floor`: quickly down, slowly back). It holds in every stance, wherever the muzzle is swung, through
  recoil and through the reloads, at any field of view, with the lens on or off. `CROP_MARGIN` is how far under the
  edge; a profile's `"crop"` moves one weapon's line (the pistol: -.02).
- The camera is on the forehead, so the shoulders are well under it (`shoulders` in `PROFILES`, y -.25 / -.27): the
  forearms come up from below and never cross the corners.
- With the sights up the weapon comes up and out but is not brought to the lens: the pistol's `ads_drop` is gone, the
  rifle's rear sight is no longer a ring across the picture (`ads_at`). The muzzle still points where the round goes.
- The lens the weapons are drawn through is longer: `VIEW_SCALE` .37 (it was .5), and the pistol and the shotgun are
  held closer (`hip_at`, `ads_at`). The pistol is canted a little at the ready, so its side shows.
- The rifle and the sniper rifle are held by the magazine well, not by the handguard (`_build_long` reach -.05 /
  -.1): both hands are at the near end, and the whole handguard is in the picture. The shotgun's hands were not moved.
- The rifle's bolt catch is pressed with a closed hand (`HAND_POSES.slap`): the flat hand stood up into the picture.

### What is nearest the lens is soft and dark (`scripts/gun_near.gdshader`)
- On the weapon's view only: toward the lower edge the picture goes out of focus (twelve taps) and loses light, as the
  near end of a weapon does under a fixed-focus camera on the wearer's own head. What little of a hand reaches the
  edge is in that.

### The weapons themselves
- Reflections: the weapon's view had nothing round it, so steel showed nothing. `_studio_sky` is a soft box low all
  round, a dimmer ceiling and a dark floor, used for reflections only and kept as dim as the place
  (`_light_like_the_scene`, `background_energy_multiplier`). A second light from ahead (`Rim`) runs along the tops.
- Finishes: the long guns were flat colours (the rifle a light grey). `_finish` gives them black anodising,
  parkerised steel and polymer (`FINISHES`), each with a fine unevenness in the roughness.

### Captures
- A review capture's window takes no focus and no mouse (`capturing` in interior.gd, player.gd): captures can run
  while the PC is in use, and a click no longer fires the weapon in the middle of one.
- `work/v31/pov.sh <weapons> <name>` (the camera's view of each weapon), `work/v31/low.py` (the lower part of chosen
  frames side by side), `work/v32/exe.sh` (the same from the EXE).

### After the first 0.32 export (same day)
- The rim light sat at the mirror angle of a slide's top and turned the pistol pale, most of all at night: it now
  comes from the side, with a third of the highlight, and is gone in the dark. What the weapon reflects follows the
  place by the sky material's own energy, in steps (`_studio`).
- The crop goes down at once (a shot's kick is faster than any easing) and the pistol's near end dips with each shot
  (`_recoil`): the arms' clip is read a frame late, and a fist showed in the flash frame.

## Build
`builds/windows/Interior.exe` is **0.32.0** (1,242,797,120 bytes, 2026-11-16 20:27, SHA-256
`2c5318e33bd9117df399e458c9bf680c35c681e3032cd891f2be5a090ee5cc5f`), exported with `python -I tools/export_windows.py`
and checked with its own captures (`work/v32/exe.sh` -> `work/v32/exe/`): 20 weapon views and the 17-frame gun
sequence, no script errors. Start-up: menu at 9.5 s.

## Checks
- `python -I tools/run_tests.py gun debug_menu zombies`: gun 42 checks, debug menu 39, zombies 107, no failures (the
  runner prints NO REPORT for these three; the counts are in `work/v30/tests/*.log`). The other 22 tests were not run.
- Looked at from the EXE: every weapon at the ready, sights up and in its reload in the lit room; the pistol on the
  night road, with the torch, in the hut and at the shot. No hand in any of them.

## Screenshots
`work/v32/exe/low-hands.jpg` (EXE, the four weapons), `work/v32/exe/sheet-gun.jpg` (EXE, room / hut / road / street),
`work/v31/pov/k6-low.jpg` (sent during the run).

## Open
- The reload finger poses were not tightened: the hands are under the frame through every reload, so nothing of them
  is seen. The rifle's and the sniper rifle's left hand moved to the magazine well without the finger fit being run
  again (`work/v31/fit.sh`); it is out of the picture.
- The shotgun's hands and poses are as they were (owner: "forget the shotgun changes"); only its framing changed, and
  because the pump hand is far forward, what shows of it is the front of the barrel and the pump.
- The pistol goes under the frame for about a second in the middle of its reload.
- With the sights up nothing marks the point of aim: the sights are below the lens, as on a forehead camera, and
  there is no dot. Rounds still go where the muzzle is drawn pointing.
- Godot prints one leaked shader RID at exit since this version (the weapon view's new shader or sky); nothing shows
  in play.
- The Android APK was not rebuilt (still 0.25). Nothing has been committed to git since 0.8.
