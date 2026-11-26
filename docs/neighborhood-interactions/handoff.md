# Neighborhood interactions

Updated October 8, 2026. Main Windows output: `builds/windows/Interior.exe`.

- 36 existing lot openings have two separately colliding gate leaves, rusted sheets, bars, hinges, handles and a sliding latch. Original fixed gate triangles and blockers are removed at runtime. The baked town and all other facade geometry remain intact.
- Tap E to unlock. Unlocking applies no angular motion. Hold E on a leaf and move/look to pull or push it, or walk against it to push. Release preserves damped momentum. The hinge creak follows motion and stops at rest. Leaves stop against the player.
- 21 existing house entrances have permanently locked timber doors with rusty hardware. The prompt reads “Open door”. Walk within arm's reach, then press E. The gun holsters, the matching sleeved hand makes three timed knocks, and one of seven remarks appears, starting with “I guess no one's home..”. Looking or moving away cancels the gesture and allows an immediate retry. The active gesture and dialogue prevent overlapping attempts; doors have no additional cooldown.
- Each entrance also has either an old doorbell or a rusty mailbox, with its own sound and response. These are physical targets mounted beside the actual entrance.
- A street crossing near the courtyard lane triggers a breathy “psst” once per scene. Two other crossings and occasional 42–72 second intervals produce a short run of quiet positional footsteps behind the player, with no character spawned. Facing the source stops the steps. Incidental sounds yield to story dialogue and the later siren sequence, stop indoors, pause with the game, and reset on Restart.
- Existing PBR rust and timber textures, the existing skinned player arms, and credited impact/footstep sounds are reused. New breath, knock and bell audio is generated in code; there are no new external asset dependencies.
- The stranger and older courtyard-gate tests now explicitly select the courtyard gate instead of assuming the town has only one push gate.

## Verification

`game/tests/neighborhood_interactions.gd` checks unlock-without-motion, manual opening/closing, walking pushes, locked resistance, actual ray targeting, timed knocks/dialogue, close-range and cooldown rules, mailbox/doorbell use, one-time scares, footsteps stopping when faced, indoor suppression, pause and restart.

All 29 checks pass. Windows release export completed, and the exported executable ran a 180-frame headless autoplay smoke check without script/runtime errors. See `windows-smoke.log` and `windows-build.json` for the build fingerprint.

Follow-up knocking fix: `neighborhood_knock_retry.gd` passes 37 checks using the player's E interaction. It covers immediate/mid-gesture walk-away, turning away, successful replay after each cancellation, repeated completed knocks, pose and audio cleanup, stable door contact during small movement, handle targeting and crouching. The pose is reset before each attempt and starts lowered, with one contact calculation shared by reach and animation. Door ray targeting replaces the old centre-angle cancellation rule. See `neighborhood_knock_retry.log`.

Native Forward+ review images: `01-knock.png`, `02-dialogue.png`, `03-gate-closed.png`, `04-gate-open.png`.

Passing regression suites: physics integration, room integration, tabletop stability, movement stress, hamster stress, upgrade integration, touch integration, balcony integration, gun integration, street integration, fields integration, stranger integration and neighborhood decay integration. Individual logs are in this folder (the first two are in `regression.log`).

Two existing room checks fail identically with neighborhood interactions disabled: `settling.gd` reports existing indoor prop drift (worst wake-all drift 233.6 mm), and `surroundings_integration.gd` expects 8434 room triangles where the current room has 7282. Baseline comparison logs are `settling-without-update.log` and `surroundings-without-update.log`. These are not caused by the neighborhood update; the complete build-test suite is therefore not wholly green.

The runtime conversion is deferred until the main scene exists and is skipped during editor bakes. Distant backdrop lots outside the existing playable collision area remain scenery. Android output is not rebuilt for this Windows update.
