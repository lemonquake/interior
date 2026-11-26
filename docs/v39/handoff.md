# Interior 0.39 — one night, inside and out

Owner (2026-11-17): "fix the lighting and make it consistent. when inside the room it seems that there is a daylight
kind of lighting because when you exit via the blue door, you can see the transition".

Build: `builds/windows/Interior.exe`, 0.39.0, exported 2026-11-17 21:10 with `python -I tools/export_windows.py`.
Checked with its own capture (`-- --capture-review`, frames in `work/v39/exe/`; `exe-door-open.png` here).
Before/after walk through the navy door: `doorway_before_after.png` (left 0.38, right 0.39).

## What was wrong

The room and the town shared one Environment, but the room set it up as **daytime**: ambient light from a warm
procedural sky at energy 1.0 (1.15 on Low), exposure 1.08, full saturation. `neighborhood.gd` saved those values and
swapped in the night grade (ambient 0.24 blue, exposure 1.02, saturation 0.80, less glow) when the camera crossed the
door line (`z > 2.62, x > .8`), blending over about a second. Two more things switched on the same line: the body
camera's night gain (`bodycam.gd`) and the light on the hands and gun (`gun.gd`). So every trip through the navy door
showed the room's daylight turn into night.

## What changed

- `scripts/night.gd`: `InteriorNight.apply_grade()` is the ONE night grade (ambient colour + energy, saturation,
  contrast, exposure, glow). The ambient colour only drifts toward the fields' blue with
  `InteriorFields.zone_weight`, never at a door. Outdoor values are exactly the old outdoor values.
- `scripts/room_lighting.gd`: `apply_quality()` applies that grade; the tier `"ambient"` values are now scale factors
  (Low 1.15, Medium 1.08, High/Ultra 1.0, Android 1.0). The warm sky no longer lights anything.
- `scripts/night.gd` `add_room_bounce()`: three faint warm omni lights (no shadow, no specular, render layer 1 only,
  desktop renderer only) stand in for lamplight bouncing off the pale floor onto the walls and ceiling. They belong
  to the room, so the room looks the same from the sofa and from the balcony.
- `scripts/neighborhood.gd`: no grade swap any more; outdoors only adds the ground mist, which now fades in and out
  with the doorway blend instead of switching on and off.
- `scripts/bodycam.gd`: the night gain is on everywhere (it only lifts dark pixels).
- `scripts/gun.gd`: the hands' room light falls off over the last metre to the door and the first step outside.
- `tests/atmosphere_integration.gd`: now asserts the grade is identical on both sides of the door.
- `tests/doorway_review.gd` (new): walks the camera through the door in real time and prints each frame's mean
  brightness (`work/v39/before`, `after2`, `doorway.txt` in each).

## Checks

atmosphere 15/15, balcony 66/66, canal 57/57, debug menu 39/39, gun 42/42, Android budget 3183/3183,
Nichols 50/50, night revision 28/28. The balcony frames measure the same brightness before and after (0.288), so the
outside is unchanged.

## Open

- The room is darker than before: lamp pools and warm walls instead of an evenly lit room. If it is too dark to
  play, raise `ROOM_BOUNCE` energies in `night.gd` (lights inside the room), not the shared ambient.
- The EXE's default `--capture-review` room views are taken over by the hooded man's gate cutscene (the Stranger
  is not disabled there). That bug was already there; only the balcony frames show the room correctly.
- Android: the bounce lights are off there (two-light budget), so the room is darker on the APK. The APK was not
  rebuilt.
