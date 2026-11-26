# 0.48 handoff: the named arsenal, drops, waypoints, T shove

Build: `builds/windows/Interior.exe` + `Interior.pck` (0.48.0). Nothing is committed (as since 0.8).

Owner asked (2026-11-20): many more guns from downloaded models with unique names (Beretta Hi-91, Gausser
Double-Barrel, GTK-44 ...): 4 pistols, 10 rifles, 3 sniper rifles, 4 shotguns, each different (rate of fire, sights,
scopes, damage; the Eruption AD-15 pistol blows heads off but fires slowly); random weapon drops in reachable spots;
ammo drops of different sizes; healthkits small/medium/large; smarter AI on a waypoint system so it never gets stuck;
Enter opens the chat, T shoves infected (who stumble into each other) and objects (tables).

## The arsenal (`game/scripts/arsenal.gd`)

21 new weapons, each a downloaded Sketchfab model (CC BY 4.0, credits in `game/licenses/THIRD_PARTY_MODELS.md`) on one
of the four mechanisms `gun.gd` already had. One weapon of each kind is carried (keys 1-4 as before); taking another
of the same kind puts the old one down where you stand.

| Kind | Weapon | What sets it apart |
|---|---|---|
| Pistol | Beretta Hi-91 | 15 rds, soft recoil, tight group |
| Pistol | Eruption AD-15 | .50, 7 rds, 0.62 s between shots, huge flip; a head hit always bursts the head; goes through 2 |
| Pistol | Kessler P9 Auto | machine pistol, 20 rds, ~880 rpm with the trigger held |
| Pistol | Vex .357 Revolver | 6 rds, heavy, often takes a limb off |
| Rifle | GTK-44 | 7.62x39, 600 rpm, hard climb |
| Rifle | Kestrel K-74 | 5.45, 650 rpm, low recoil |
| Rifle | Viper V9 | .45 SMG, 1200 rpm, short range |
| Rifle | Hornet MP9 | 9 mm SMG, 800 rpm, very controllable |
| Rifle | Bastion S-17 | 7.62x51, 20 rds, 3x optic (ADS closes the view much further) |
| Rifle | Garrison M1 | semi-auto, 8 rds, heavy hitter, pierces 2 |
| Rifle | Corsair M4 | 3-round burst per pull, holo |
| Rifle | Sentry SK-45 | semi-auto, 10 rds |
| Rifle | Auger A3 | bullpup, 42 rds, 1.5x |
| Rifle | Talon P90 | 50 rds, 900 rpm, piercing round |
| Sniper | Longreach M40 | bolt, 10 rds, 3-9x, duplex reticle |
| Sniper | Drakon SVD | semi-auto (no bolt), fixed 4x, chevron reticle |
| Sniper | Titan B-50 | .50 BMG bolt, 5 rds, 5-16x, through 5 bodies, enormous recoil |
| Shotgun | Gausser Double-Barrel | 2 shells fired as fast as you pull, 12 wide pellets |
| Shotgun | Spartan S-12 | pump, 8 shells, tight pattern |
| Shotgun | Tempest A-14 | semi-auto, 7 shells |
| Shotgun | Ironside M37 Slug | pump, one heavy slug: rifle-like reach |

How it works: `gun.weapon` is still the mechanism; `gun.models[kind]` is which weapon it is; `gun._prof()` is the
mechanism's PROFILES entry with the weapon's own figures over it. Long guns are built with `_build_long` from the
processed model's sockets; pistols sit on the Glock's frame (its meshes hidden). New profile keys: `burst`,
`cycle: "self"`, `scope_min/max`, `reticle` (scope.gdshader `style`), `head_pop`, `slug`.
Debug menu (Items tab): a button for every weapon by kind.

Models: `tools/assets/fetch_guns.py` (Objaverse mirror) → `tools/blender/story/process_guns.py` (orientation from the
shape + `gun_overrides.json`, real length, loose parts cut, sockets) → `game/assets/models/guns/*.glb`.
Six first picks were replaced after the preview sheet (exploded parts, a gun in its case, a diagonal pose).

## Drops (`scripts/coop/mission.gd`)

- The map is scattered as the waypoint graph reaches each 22 m square: 60% a weapon (rarer guns less often), 45% an
  ammo box, 30% a healthkit, only on graph nodes joined to where the players stand (so always reachable), never within
  10 m of a player or 2.6 m of another drop.
- Ammo boxes: small / medium / large (pistol 12/24/45, rifle 30/60/120, shotgun 8/16/30, sniper 5/10/20), for the
  weapon in the hands. Kills drop sized boxes and kits too.
- Healthkits: small (20-30 HP), medium (40-60), large trauma kit (75-100); `kit_sizes` beside `kits`; a patch-up uses
  the smallest kit that covers what is missing, else the largest.

## Waypoints (`scripts/waypoints.gd`)

A node every 1.8 m on every floor where a body fits, linked to its neighbours when walkable (straight, or round a
corner in a few cells), built in the background (1.4 ms a tick, round the players, 52 m). `zombie_nav.gd path()` now
goes by the graph when the target is far or its own search did not get there, and only walks cells to the waypoint a
leg (7 m) ahead. Doors/gates changing (`forget_box`) re-link the nodes there. A figure (co-op) or zombie (solo)
pressed against something too long backs off to a waypoint a few links away (`detour`) and looks again.
Measured round Store Road: ~3900 nodes, ~11000 links, ~3 s of build time spread over the ticks.

## Shove and chat

- T shoves (co-op and solo; V was the solo key). Co-op: the host reels the infected within 1.9 m in front
  (knockdown sometimes), and the ones they fall into stumble too (two more ranks, weaker each); tables and loose
  things are pushed by weight. Solo: the same chain through `zombie.shoved`, and InteriorObjects are pushed.
- Enter opens the chat; T no longer does.

## Tests

- `tests/arsenal_integration.gd` (new): 127/127. Every weapon in the hands with its own model, its magazine, its
  rounds a pull (Corsair 3), self-loaders, scope ranges; the swap leaves the old weapon down; kit sizes; ammo boxes;
  ~3900 waypoint nodes round Store Road; scattered drops all on the graph joined to the player; T shove (front one
  reels and is driven back ~0.7 m, the one behind stumbles, nobody behind the player); a table shoved 2 m; T does not
  open the chat.
- Full suite (`python -I tools/run_tests.py`), then the co-op tests one at a time:
  - pass: everything except the items below. `nav_integration` 9/9 and `senses_integration` 29/29 after making the
    waypoints a fallback (first version routed every far search and broke two nav checks).
  - `coop_integration` / `coop_backstreets_integration` timed out only when run 3 at a time (two hosts on one port);
    alone: 34/34 and 9/9. `coop_squad` 27/27, `coop_store_survival` and `coop_office_entry` all pass.
  - `upgrade_integration`: restart one node off, known since 0.43 (menu state).
  - `zombies_integration`: flaky, a different 1-4 checks each run; the same with the 0.47 gun.gd and with the
    waypoints off, so not from this run.
  - `coop_kits_modes` 30/35: "the teammate is held still while patched up" and "did not walk off" fail the same with
    the 0.47 co-op scripts (pre-existing: the patched AI walks off); "the rifle lies on the ground" was updated for the
    drop now naming the weapon ("weapon:ar15"); "E offers it back"/"picked it back up" follow from the AI standing
    hurt next to the drop (the patch-up prompt wins). Not fixed here.
- Captures: `Interior.exe -- --capture-review --capture-views=arsenal --capture-path=<dir>` (optional
  `--capture-weapons=id,id`): every weapon at the hip, on its sights, firing; then the drops on Store Road.
  0.48.0 EXE run: `work/v48/exe2/` (76 frames).

## Fixes after the first EXE look

- Three optics put the eye inside the sight body (Bastion, Corsair, Talon): the Bastion now uses the scope overlay
  (fixed 3x, duplex); the Corsair and Talon sight over the top (`sight_z` in `gun_overrides.json`).
- Hand sockets are now set from the sight line as on ar15.glb (gun.gd lowers the weapon until the hands are under the
  frame edge, so hands set high pushed some models out of view); compact/bullpup guns hold further out (`hip_at`).
  At the hip every long gun shows like the stock AR-15: its front end at the bottom edge.

## Screenshots sent

| File | What |
|---|---|
| work/v48/exe2/sights_sheet.jpg | 12 weapons on their sights / through their scopes (0.48.0 EXE) |
| work/v48/exe2/hip_sheet.jpg | 12 weapons at the hip (0.48.0 EXE) |
| work/v48/exe2/drops-store-road.png | dropped weapons, small/medium/large healthkits and ammo boxes |
| work/v48/preview/sheet.jpg | the downloaded models after processing (first pass) |

## Not verified

- No real two-PC game.
- Hands are not fitted to each new model (owner: gun-only view, hands mostly under the frame).
- Reload animations are the mechanism's (the revolver reloads like a magazine pistol).
