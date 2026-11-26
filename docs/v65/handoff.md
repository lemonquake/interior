# 0.65 handoff: Market Row, the long bridge, new vehicles, and a phone/PC performance pass

Owner's asks (2026-11-25):
1. "research about 3D models of Bus and trains and completely overhaul the models in the game, and make sure there
   are VISIBLE paths like the door is broken or the windows are broken ... make sure there are no blockers. Also can
   you expand the Outer streets and make it more epic with buildings that have interiors? ... at least 6 enterable
   buildings ... A 2-story boutique "Azrin & Azrael", a Pizza parlor "Airah's Pizzahan", a 2-story Shopmart called
   "Nichols Davao Mart" ... drag a table just to reach something then they can vault over to reach the upper floor
   ... The Bridge should also be way longer than that with some broken cars and stuff. go and rebuild the EXE and APK"
2. (after the first half of the run was cut off by the usage cap) "continue. dont forget to make massive and
   intensive performance boosts to the mobile version without sacrificing Physics and gore for zombies as always.
   And as always, both PC and mobile will have massive ULTRA FAST BLAZING PERFORMANCE AND BUTTER SMOOTH FPS"

## Part 1 (first session, cut off at the cap): vehicles and Market Row

- New Blender vehicles (tools/blender/vehicles/build_vehicles.py, assets/models/vehicles/): a 12 m city bus with the
  back doors torn off and the front door folded in (walk-through and shut versions), two metro cars with a forced
  door, an open gangway and a cab, and sedan, taxi, van, pickup and box truck, each clean and wrecked (any can be
  burnt). Proportions from MAN Lion's City 12 / Mercedes Citaro / Siemens metro data sheets. Colliders unchanged.
- Market Row (scripts/coop/outer_row.gd, new, between outer_world.gd and outer_street.gd), after the long stair:
  Airah's Pizzahan (smashed door, vault the counter, out the kitchen's back door) -> the neon court -> the flats
  (family flat, children's room) -> the red-stair alley (optional upstairs eatery) -> Nichols Davao Mart (loading
  door, stockroom, two-floor atrium; the table puzzle under the broken escalator) -> the broken wall into Azrin &
  Azrael (two floors) -> out its smashed display window -> the funeral parlor (optional) -> the long bridge (270 m,
  four red arches, ~15 wrecks, the east half of the deck gone for 16 m). Stage 17 = the finale on the bridge.
- outer_street.gd: the new objectives, zones, steering through the buildings, the finale; debug jumps
  outerpizza/outermart/outermartup/outerboutique/outerbridge/outerbridgefar (debug menu "The mart", "The bridge").

## Part 2 (this session)

### Market Row fixes (found by the walk test)

| Problem | Fix |
|---|---|
| The dragged table swung diagonal and tipped on its edge 1.5 m short of the escalator's end; the puzzle never set | A wider "under the escalator" area (TABLE_ZONE 48.2..51.8 x 772.0..775.8); a table brought there and let go (or held still / right under the end) slides upright into TABLE_SPOT in 0.45 s and stays (outer_street.gd `_check_table`) |
| The broken escalator was one 30 degree slab: the climb (player.gd `_try_mantle`) only lands on flat tops, so the jump from the table never caught it | A 0.75 m flat landing at the broken end (real escalator treads), at 2.6 m: out of reach from the floor even off a jump (hands reach 2.38 m there, checked), in reach off a jump from the table (outer_row.gd `ESC_BREAK`, `ESC_LAND`) |
| The rubble in the breach into the boutique was a 0.45 m block: the feet step only 0.16 m (player.gd LIP_HEIGHT), so walking (and the squad) stopped there | Its collider is 0.14 m, the loose chunks lie low on it |
| The boutique's smashed display window (the way out) was a solid, drawn wall: the wall builder cut holes left to right and assumed no two holes share an x, so the band of upper-floor windows filled the whole ground floor in (doors and display windows, drawn and solid) | `_rects` cuts every hole out of every piece it overlaps (outer_row.gd). Only the boutique front had stacked holes; every other wall comes out the same |
| r18 review camera sat inside a shelf | moved into the aisle |

### Performance

Measured on this PC (Ryzen 7 5700X, RTX 4060) in phone mode (`--rendering-method gl_compatibility -- --mobile-test
--render-size=1600x720 --quality=0`, the phone's default level) and PC mode (Forward+, High, 1920x1080), with
`tests/coop_perf.gd` (now also reports where each frame goes: tests/frame_anatomy.gd).

**Where a phone frame went before** (squad fight): scripts 3.2 ms, physics engine 1.7, animation/process 2.0,
rendering 9.0 ms (of which ~5.6 CPU for ~750 draw calls). The Compatibility renderer pays per draw on the processor,
and a phone's processor is 3-4x slower: draw calls and script spikes were the phone's problem.

| Change | What it does | Files |
|---|---|---|
| Colour batch | Districts merged their boxes into one mesh per material id, but ~200 ids per district differ only in colour: each was its own draw. Kits whose materials match in everything but `albedo_color` (texture, triplanar, roughness, transparency, and how the builder dresses the mesh) now share one mesh per 24 m square, the colour carried by the vertices (sRGB in, as the uniform is). Glowing materials never merge (lamps flicker by changing their own material). A material alone keeps its mesh exactly as before. Store Road, the backstreets, PILCST, Outer Street. `-- --no-colour-batch` turns it off for comparisons | scripts/colour_batch.gd (new), box_kit.gd (`colors`, `take_shape`, shape starts), street.gd, backstreets.gd, school.gd, outer_kit.gd |
| Phone stains | On a phone each street blood stain (decals cannot be drawn by Compatibility) was its own mesh and material: ~190 draws along Store Road. Now one mesh per texture per 16 m square, each stain's tint and alpha on its vertices, the draw distance covering the square | horror_liquid.gd (`LiquidBatch`) |
| Waypoint seeding | `seed_around` walked a 59x59 lattice per player every half second (17k lookups, up to 11 ms): it now visits only the part of each player's circle outside the nearest circle already seeded. Checked to give the identical seen-set and queue (300 random steps) | waypoints.gd |
| Waypoint links | A new node's links (up to 16 walk checks, each maybe a search round a corner) ran 5-8 ms past the 0.7 ms budget in one go: they are queued and looked at a pair at a time inside the budget. Same links, a few frames later | waypoints.gd (`_link_todo`) |
| Phone model warm-up | A phone has no boot preload (0.64, the deadlock), so each infected type's model was read from storage the first time one came: 50-150 ms in the middle of the siege, again and again. While a menu is open (main menu, lobby, chapter board, pause) the phone reads the town's 57 infected types and the wound sounds one at a time on the main thread (no worker threads) and keeps them; a phone with under 3.5 GB keeps the first 24. `-- --phone-warm` runs it on a PC | phone_warm.gd (new), interior.gd |

Not changed (owner's rules): ragdolls, bodies, hit boxes, gore amounts, AI tick rates, physics rate.

**Results, phone mode on this PC** (before = colour batch off, before the waypoint and stain changes; after = all):

| View | fps median before -> after | 1% low before -> after | draw calls before -> after |
|---|---|---|---|
| Store run, squad of 5 | 100.5 -> 116.6 | 60.3 -> 71.0 | 523 -> 407 |
| 20 infected coming | 72.0 -> 84.0 | 44.5 -> 62.5 | 580 -> 463 |
| Squad shooting them down | 63.8 -> 73.1 | 40.7 -> 43.0 | 752 -> 687 |
| After: bodies and blood | 62.6 -> 78.8 | 35.5 -> 49.6 | 851 -> 702 |

Script time in the crowd 3.06 -> 2.00 ms, in the fight 3.56 -> 2.65 ms. The phone path's stains are not in these
rows (the test builds no street gore first); along Store Road they were ~190 of the draws.

**PC, Forward+ High 1080p** (colour batch off -> on; both with the waypoint changes): store run 90.0 -> 103.1 fps
(draws 2461 -> 1552), crowd 71.2 -> 76.6, fight 60.2 -> 69.2 (2970 -> 1790), after 61.3 -> 61.7 (3045 -> 1922).

What is left in a fight: the figures themselves (skinned, ~5 surfaces each), the waypoint walk checks over ground
never probed (one check up to ~6 ms on this PC, cannot be split without changing the graph), the infected's chase
(~1 ms per frame for 20, mostly `move_and_slide`), a first-use shader compile (~30-70 ms once per effect per run).

### Checks

- Picture unchanged: `tests/batch_views.gd` (fixed cameras, time stopped) on and off: Store Road, the store, the
  arcade, PILCST lobby and 2F, Outer Street, Pizzahan, the mart: same colours; differences only from lamps that
  flicker on the wall clock (a second run of each settles it). Phone renderer the same.
- Gore on the phone renderer (`--capture-views=gore`, gl_compatibility): wounds, splats, pools, the arm off and its
  stump, drips all drawn (work/v65/gore_compat/sheet.jpg).
- tests/phone_coop.gd: 26/26.
- Market Row walk (tests/outer_street_walk.gd, the real player body): from the start of Outer Street through the
  pizzeria, the court, the flats, the alley and into the mart: all passed (walk2); from the mart's loading door
  (`-- --from=mart`): table set, onto it, up the escalator, through the breach, down the boutique's stair, out of
  its window (stage 17, the horde coming), across the bridge past the hole: WON, 11/11 (walk7). Logs in work/v65/walk/.
- Table puzzle probe (tests/row_table_probe.gd): set, onto it, up; with `--no-table` the floor jump falls short.
- Run concurrent Godot tests with `SLEEP_COOP_PORT=<n>`: two hosts on the default port make the second test hang.

### New tools

tests/frame_anatomy.gd (per-frame split: physics scripts / physics engine / process / render, and the long frames),
tests/draw_census.gd (what the camera draws, by where it hangs; `--kits` the district's kit meshes),
tests/batch_views.gd, tests/figure_bench.gd, tests/row_table_probe.gd,
tools/prof_funcs.py (wraps every function of chosen scripts with a timer; `-- --prof` prints the top ones and every
frame over 6 ms of script: `INTERIOR_PROF_SPIKE`). Never export while it is applied.

## Builds (0.65.0, version code 65; not published)

- Windows: builds/windows/Interior.exe (109 MB, sha256 19111a8a44f93a92...) + Interior.pck (1,491 MB) +
  Sleep-0.65.0-windows.zip (1,601 MB), via tools/export_windows.py. The EXE's own start-up: menu at 17.6 s (the same
  as every build since 0.51). EXE captures in work/v65/exe/ (the mart's loading door with the 0.65 objective).
- Android: builds/android/Interior.apk, exported with `--export-debug "Android"` (owner: "no signing ... just build
  the APK like usual"): Godot signs a debug export with its own debug key from the editor settings, the same key the
  earlier APKs carry, so it installs over them. 824,366,338 bytes, sha256 caec4da51ea056ff..., apksigner verifies;
  signer certificate SHA-256 749565e2... (the same as the 0.64 build in work/v64/apk1). A release export
  (`--export-release`) stops at "Could not find release keystore": no release keystore is set anywhere now, so the
  0.65 APK uses Godot's debug template (0.64 used the release template).
- Published (owner: "Publish 0.65"): PC 0.65.0 staged, uploaded (18 new chunks, 0.03 GB) and activated: every
  launcher offers it (release.json checked live). APK to /downloads/Interior.apk (see "Published" below). Release
  notes: tools/release/notes/0.65.0.md (five plain lines, player-facing). The website needed no change.

## Text on screen added in 0.65

Shop names (owner's): "Airah's Pizzahan", "Nichols Davao Mart", "Azrin & Azrael". Objective lines (plain
directions): "The road east is buried. Go through Airah's Pizzahan." / "Over the counter, and out by the kitchen's
back door." / "Through the flats across the court." / "Into Nichols Davao Mart by its loading door." / "The way up is
the broken escalator. Drag a table under its end." / "Climb onto the table and jump for the escalator." / "The top
floor's east wall is down. Through it, into Azrin & Azrael." / "Down through the boutique and out of its broken
window." / "Everything on the row heard you. Across the bridge, everyone." The flats, eatery and funeral parlor have
blank/unreadable signs (no names given). Nothing new on screen from the performance work.

## Published (2026-11-25)

- PC 0.65.0 staged (1.60 GB, 1.07 GB compressed), uploaded (18 new chunks, 0.03 GB) and activated: the live
  release.json reads 0.65.0 with the five notes; a chunk spot-checked on the server.
- APK 0.65.0 (824,366,338 bytes, sha256 caec4da51ea056ff...) at /downloads/Interior.apk; Interior.apk.json and
  downloads/index.json list it (game 0.65.0, android 0.65.0); the download answers 200 with the full length.
- Website: unchanged (its download buttons read the version from the server). Windows zip (local only):
  builds/windows/Sleep-0.65.0-windows.zip, sha256 c0266335997a283f...

## Open / not verified

- No physical phone: phone numbers are this PC in phone mode. The menu warm-up's memory on a 2 GB phone is
  estimated (~3 MB a type), not measured.
- The colour batch on a phone: Compatibility lights each mesh with at most two lamps; merged meshes are kept to 24 m
  squares so they stay local, and the phone captures looked the same, but lamp flicker made a strict A/B impossible.
- First-use shader compiles (one hitch per effect per run) are still not pre-warmed for gore effects.
- Vehicles (a jeepney is ~17 material slots) are now the biggest draw source on Outer Street.

## Screenshots sent

| When | File |
|---|---|
| Market Row review views | work/v65/row1_sheet0..3.jpg |
| Colour batch on/off, fixed cameras | work/v65/batch_views/sheet.jpg |
| Phone-renderer gore | work/v65/gore_compat/sheet.jpg |
| Escalator landing, mart aisle, boutique window open | work/v65/row2_sheet.jpg |
| The built EXE: Store Road, the mart's loading door, the bridge | work/v65/exe/sheet.jpg |
