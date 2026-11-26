# Interior 0.38 — dead bodies fall again

Owner (2026-11-17): "massive gamebreaking bug and glitch!! what did you do to the zombies?! Where is the ultra
realism physics and destroyable bodies and body parts?????"

Build: `builds/windows/Interior.exe`, 0.38.0, exported 2026-11-17 20:51. Checked with its own captures
(`--capture-views=gore` in `work/v38/exe_gore/`, `--capture-views=zombies` in `work/v38/exe_zombies/`).
Before/after: `work/v38/ragdoll_before_after.jpg`.

## The bug

A zombie killed outright (a head shot, buckshot, a body coming apart) stayed **standing, frozen in its last
pose**, even with its head gone, while its physics bodies fell to the ground unseen. Knock-downs of living ones
were fine, which is why it looked like the ragdolls and gore had gone.

Cause: 0.30's crowd animation (`zombies.gd` `_crowd_tick_frame`) puts each figure's AnimationPlayer and Skeleton3D
modifiers on MANUAL and advances them itself, and `zombie.gd` `animate()` only switches them back to IDLE once it
sees the figure is ragdolled. But `_die()` takes the figure out of the "zombies" group in the same frame, and the
director only animates that group, so a figure killed outright was never switched back. With the skeleton's
modifiers on MANUAL the PhysicalBoneSimulator3D never reaches the mesh.

Every check passed: the tests measured the physics bodies (hips on the ground), not the drawn mesh.

## The fix

- `zombie.gd`: `_drive_by_hand(by_hand)` holds the switch; `_ragdoll()` and `_die()` call `_drive_by_hand(false)`
  at once, as well as `animate()` as before.
- `tests/zombies_integration.gd`: new check "The body drawn lies where the ragdoll lies": the skeleton's hips as
  drawn (read on `skeleton_updated`, the only moment modifier output is in the pose) within 0.3 m of the hips body.
  Without the fix it fails (drawn 0.74 m up, standing); with it 0.05 m apart.
- Same test: two checks flaked about one run in three since 0.37 (rounds leave from the breech, under the lens, so
  a hand in front of the forearm or a hung head over the chest sometimes took the round). `_aim_clear` picks a
  point on the part that both the lens and the bore reach first; the forearm rounds fire right after aiming.
  4 of 4 runs pass, 109/109.

All 33 `*_integration` tests pass (`python -I tools/run_tests.py`).

## Not checked

- I cannot play the game: the fix was checked by the captures and the test, not by hand in a real fight.
