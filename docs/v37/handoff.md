# Interior 0.37 — the weapon, the infected and the world agree

The owner's list, items 12 to 17 (2026-11-17): bullets from a physically valid weapon position, projectiles that
meet moving targets correctly, no sight or melee through barriers, one rule for what the player and the infected
perceive, readable investigation, and navigation that follows doors and changes in the world.

Build: `builds/windows/Interior.exe`, 0.37.0, exported 2026-11-17 20:25,
SHA-256 `ac7814be9b71ba7a97fc5e592f630da2ada29bdd06e7572abc414bc7844d53b5`. Checked with its own capture (`--capture-views=zombies`, frames in `work/v37/exe/`).

Tests: `game/tests/fair_world_integration.gd` (new, 53 checks). All 33 `*_integration` tests pass (`python -I tools/run_tests.py`).

## 12. The round leaves from the weapon (`game/scripts/gun.gd`)

- `BARREL` gives the weapon's real place in the lens' frame for each weapon, at the hip, on the sights and
  tucked: the breech (firing hand or shoulder) and the barrel's length. The camera is on the forehead, so even on
  the sights the bore is 0.12–0.16 m under the lens; at the hip it is about 0.25–0.27 m under and to the right.
- `_hitscan` now lays the bore from the breech to the first thing the lens' line meets (where the two agree). The
  framing and the no-crosshair rule are unchanged: the view model is still drawn where it was; only the round's
  start moved.
- What follows: a wall top the lens sees over but the barrel is under, at the hip, takes the round; on the
  sights the same wall is cleared. Measured in the test: at the hip the round left 0.27 m under the lens and went
  into a wall 0.2 m under the lens' line; on the sights it left 0.12 m under and cleared it.
- `breech_world()` never puts the breech on the far side of something from the lens. `_wall_ahead` (the tuck)
  now also tests the real barrel at the hip, so the weapon tucks when the barrel, not just the lens, would go
  into a wall. A round fired while tucked goes into the wall.
- `last_shot_origin` (new) and `last_shot_direction` record the bore.

## 13. Rounds fly tick by tick (`gun.gd`, `Round`, `_fly`, `_strike`)

- Before: the whole path was tested the instant the trigger broke, and what it met was struck after the time of
  flight, wherever that had moved since.
- Now each round is a projectile (`Round`) moved on every physics tick by the distance it covers in that time
  (`path_reach`, the inverse of the existing drag/time model), and each step is tested against the world as it is
  at that moment. Drop, drag, energy, pierce through bodies and thin cover, window panes, lamps on the path, water
  splashes and buckshot skipping off stone (now a projectile of its own) all work as before, per step.
- A shot at arm's length still lands at once (the first tick's distance is flown when the trigger breaks).
  `instant_hits` (tests) flies the whole path at once, as before. `rounds_in_flight()` is new.
- Test: a target 60 m off that steps aside a tick after the shot is missed; one that steps into the path while
  the round flies is struck; one standing still is struck.

## 14. No knowing or clawing through barriers (`zombie.gd`, `zombies.gd`, `body.gd`)

- Sight within 1.25 m no longer skips the line test: it knows someone is there whichever way it faces, but not
  through a wall or a shut door.
- `InteriorZombies.within_reach(zombie)` is the one rule for hands both ways: a clear line from its shoulder or
  chest to the player's head or chest. The claw swing, entering a swing, the leaper's jump and landing blow, and
  the player's shove (V) all ask it. Over a waist-high rail: yes. Through a wall, a door leaf, a fence or a pane:
  no. It is looked at no more than every 0.15 s per figure, and fresh at the moment a blow lands.
- Test: forced to swing four times through a wall at arm's length, nothing lands, and the shove does not reach
  it; with the wall gone the next swing lands; over a 0.95 m rail both reach.

## 15. One rule for what is between (`senses.gd`, `sound_stage.gd`)

- `InteriorSenses.between(a, b)` counts what stands on the line: walls, panes, door or gate leaves (and hung
  cloth). The unseen walls do not count; a broken pane or an open doorway is open air. Built from it:
  - `sight_clear`: nothing but glass between (they see through windows, not walls or shut doors);
  - `reach_clear`: nothing at all between;
  - `muffle`: a wall 1, a door or gate 0.6, a pane 0.45, adding up to 2.5; `carry(m)` is the share of a
    sound's reach left (a wall leaves about three fifths, as before).
- The infected's hearing and the player's own ears (the sound stage's muffling of each voice) use `muffle`.
  Gunshots no longer skip it: a shot behind a wall carries about 32 m instead of 55. A shot muffled to almost
  nothing turns a head instead of bringing it over.
- Light on a place (`light_at`) is shaded by the same rule: lamps light through glass, not through walls.
- The torch: before, it made the player fully visible from every side. Now `exposure_to(eye)` is full only for
  eyes inside its beam; elsewhere the player shows by what the beam throws back (more when it lights something a
  step away). And the lit spot itself (`beam_spot`) is something they see: a glance across it turns a head, held
  on something near one it goes to look at the spot, not at the player.
- Found on the way: a second muzzle flash before the first was freed got a generated name, so the senses took
  it for a lamp (and the player stayed "lit"). The flash light is now marked `no_shoot`.

## 16. Investigation you can read (`zombie.gd`)

- `certainty` (0–1) says how sure it is where the player is: 1 while it sees them. It is not shown on screen;
  it shows in how it moves and sounds. `awareness()` names it: calm, suspicious, searching, hunting.
- A faint sound: it stops dead mid-step (the clip freezes), the head snaps round toward the sound with the chin
  up, then the body follows slowly; a short questioning sound, not the hunting growl.
- A loud sound (or the torch's spot held on something near): it goes to look, as sure as the sound was plain.
  Unsure, it walks, and stops dead every few seconds to listen; sure (it just lost sight of them) it goes
  quickly and straight. Test: a loud sound never makes it run; a sure search covers ground faster than an
  unsure one.
- At the place: it stands over it and looks down at it, then looks about, the head sweeping slower and wider
  the less sure it is, the body turning after the head; then a long low breath out and it wanders off.
- Hunting still sounds and moves as before (the scream, the run). So "it heard something" (stop, head turn,
  low questioning sound, walk) and "it knows where I am" (scream, run) look and sound different.

## 17. Navigation follows the changing world (`zombie_nav.gd`, `zombies.gd`, `zombie.gd`)

- Doors and gates are AnimatableBody3D leaves in the fixed world's layer, which the route finder remembers. The
  director now watches every one (`watch_movers`, found once the world stands and as any is added). When one has
  moved (checked every 0.2 s), the remembered ground where it was and where it is is dropped (`forget_box`), and
  `epoch` counts the change. A figure walking a found way looks again if a change touches that way (`touched`).
- Loose things (chairs, crates, a shoved wardrobe: layer 4) stay out of the map. Where a figure has tried for two
  seconds and got no half metre further, the cell it was making for is shut for 8 s (`shut_for`) and it goes by
  a found way, not straight, until then.
- A cell where a body fits only off its middle (a narrow railed boardwalk, a gap off the grid) is kept, with
  where in it to stand (`spot`). Points half way between cells may only move across the way, so thin walls and
  shut doors between two cells are still found.
- Test, all built in street B: a door across the street shut, no way; opened, the way is found at once and one
  called from the far side comes through; shut again, gone. Stairs up to a 0.7 m railed boardwalk are found and
  walked. A crate in one of two gaps: it shuts that cell and goes by the other gap.
- The stairs and boardwalk in the test are built by the test, not the real Nichols stairs or canal boardwalks.

## Tests changed

- `senses_integration`: "the torch on: the player shows plainly" now asks the figure the torch points at.
- `glass_integration`: a pane is chosen only if the weapon at the hip has a line to it too (not only the lens),
  and "the light beside it is still whole" counts the whole panes near it before and after.

## Not done / open

- Real-map pursuit over the Nichols stairs and the canal boardwalks was not driven; the built stand-ins pass.
- A figure at a shut door does not bang on it or try it; it goes as close as it can and searches.
- Glass between figure and player: it sees through and cannot reach; it does not yet break the pane to get in.
- I cannot see or hear the game: the head turns and sounds were checked by numbers, not watched.
