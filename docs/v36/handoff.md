# Sleep 0.36 — the breath is heard

Owner (2026-11-17), asked whether a CC0 breathing recording may be downloaded for the hurt and out-of-breath
sounds: "Yes, download". This closes the last sound left over from 0.33's "body in danger".

Build: `builds/windows/Interior.exe`, 0.36.0, exported 2026-11-17 11:28,
SHA-256 `f3cec880e51883a595c060ce1eb49beef65fd98ecc1ded99856ba9a8a5f4f769`.

## What was downloaded

Two recordings from Freesound, both **Creative Commons 0** (read on each recording's own page that day). Full
note: `game/licenses/BREATHING_SOUNDS.md` (a copy is beside the EXE).

| Used for | Recording | Author |
|---|---|---|
| Panting | "Male_Breath_Fast_Loop_Stereo.wav", https://freesound.org/s/554907/ | Nox_Sound |
| Slow heavy breaths | "Male Heavy Breathing.wav", https://freesound.org/s/474647/ | fadyhaddad |

Freesound's high-quality previews were taken (they need no account); the two files are kept in
`work/v36/dl_freesound/`. Five other recordings were downloaded, measured and thrown away: one from OpenGameArt
(only three breaths, 14 dB above its own hiss) and four from Freesound with a room or a noise floor in them.

`tools/breath_sounds.py <folder>` cuts them into `game/assets/audio/sfx/breath_pant.wav` (the loop, 5.2 s) and
`breath_heavy_1..10.wav` (one breath each, in then out, about 1.1 s). An eleventh breath had a voiced grunt in
it and is left out by a test for a tone between 80 and 500 Hz.

## What the player hears (`game/scripts/body.gd`, `_breathe`)

- **Running.** About four seconds into a run (two thirds of the breath left) the panting comes in quietly; it
  is loudest and fastest when the lungs are nearly empty. When the run stops it goes on, slowing and fading, for
  about three seconds while the breath comes back.
- **Hurt.** Under about 58 health, or while a wound is bleeding, single slow breaths: one every 3.8 s when it
  is slight, every 2.2 s and louder near death. Never the same breath twice in a row. Under panting they are
  not played.
- Nothing is heard when well and rested, at the menu, or when down.
- The infected do not hear it.

## Measured, not listened to

**Nobody has heard these yet: I cannot listen.** What was done instead: `game/tests/breath_probe.gd` records the
game's own Master bus in four states and `work/v36/breath_levels.py` reads the recordings.

| State | Loudest tenth of a second |
|---|---|
| The room, rested and well | -49 dB |
| Panting, lungs empty (heart muted for the measurement) | -29.5 dB |
| Slow breaths at 25 health (heart muted) | -29.5 dB |
| The heart at those states | about -26 dB |
| Running on the field road: footsteps / the gaps between them | -25 dB / -40 dB |

So the breath sits a few decibels under the heart and under a footstep, and ten above the gaps between steps.
The loop repeats with no gap (checked in the recording and by the playback position wrapping at 5.18 s). If it
is too quiet or too loud by ear, the four numbers are in `_breathe`: `-34.0, -12.0` (panting, from first to
full) and `-25.0, -10.0` (slow breaths).

## Tests and checks

- `python -I tools/run_tests.py`: all 32 pass. `body_integration` has five new checks (37): the recordings are
  there and the loop loops; slow breaths at critical health and no panting; quiet when healed; panting with the
  lungs empty; stopped when rested.
- EXE: the eleven files are in the pack and in the boot's read-ahead list; `-- --capture-review
  --capture-views=body` runs through with no script error; start-up report: menu on screen 1.2 s, world 8.4 s.

## Still open (unchanged from 0.35)

- The world itself in under 4 s; glass in the player's own house and the canal houses; the climbing audit's fill
  on the Nichols stair; the Android APK (not rebuilt since 0.8); nothing committed to git since 0.8.
- The sniper's held breath (Shift in the scope) does not silence the breathing.
