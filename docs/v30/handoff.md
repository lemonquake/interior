# Sleep 0.30 — loading screen, faster start, steadier frames

Owner requests (2026-11-16, in this order):
1. "create a proper loading screen, faster blazing fast loading, blazing fast gameplay"
2. "pressing E should not make the player hide their gun. The player will always show their gun unless the player
   presses G to hide gun."
3. "also the windows are not aligned properly and they dont fit the screen" (screenshot: the Options window with its
   title and Back button cut off at the top and bottom of a 1920x1080 screen).
4. "the loading screen is getting stuck" (they saw a test window of the first, unfinished boot scene hang; see
   Gotchas).

This run also picked up 0.29 (dismemberment, bleeding, sniper and scope), whose session stopped at the usage limit
right after starting its export, with no handoff. 0.28 and 0.29 are summarised at the end.

The Windows build at `builds/windows/Interior.exe` is **0.30.0** (1,239,324,840 bytes, SHA-256 `6e14286efba0493a609b1079326a9f5ec0870f8442b5a7113ced23b2982058d5`).
**The Android APK was not rebuilt** (it is still 0.25).

## What changed

### Loading screen and start-up
Before: the window stayed blank for about 16.5 s (15-16 s measured on the 0.29 EXE), then the menu appeared.

- `game/boot.tscn` + `scripts/boot.gd` is now the project's main scene. It shows `scripts/loading_screen.gd` on the
  first frame: black, the title **Sleep** and the byline exactly where the main menu has them, a thin bar with a
  percentage, a line saying what is being done ("Digging the estero", "Unlocking the Nichols house", ...) and one line
  about the controls. When the world is ready the screen fades and the menu's street is under the same title.
- **Files are read on background threads.** `assets/boot_manifest.json` lists every texture, mesh, model and sound the
  game touches at start (2,573 files) plus what is first used in play (zombies, weapons, their sounds), so the first
  zombie or the first shot never stops the game to read a file. The main scene is read after them, alone.
- **The world is built in steps** (`scripts/load_clock.gd`, `InteriorLoadClock`): the districts that are put together
  by script at start (decay, canal settlement and warren, Nichols property, siege wall, seals, then the house, hut,
  story, interactions) yield a frame between steps so the bar moves. Nothing of the half-built world is drawn.
- **The merged district meshes are baked** (`scripts/build_cache.gd`, `assets/built/world_meshes.res`, 400 meshes,
  43 MB): merging the canal's rubbish and house kits (2.6 s, each copy read the model back from the graphics card)
  and indexing/tangents (0.8 s) now happens at build time, not at every start.
- Restart goes back through the loading screen with every file still in memory.
- The Godot logo splash is gone (black until the loading screen).

Start-up, RTX 4060, NVMe, from process start:

| | 0.29 | 0.30 project | 0.30 EXE |
| --- | ---: | ---: | ---: |
| Something on screen | ~16 s (the menu) | 1.1 s | 1.0 s |
| Main menu usable | ~16.5 s | ~10.4 s | 8.1-8.9 s |

What is left of the time (project run): engine 1.1 s, reading files 1.2 s, main scene and scripts 1.6 s, instancing
0.4 s, building the districts ~4.3 s, house/hut/story/interactions ~1.7 s, first frames (shader pipelines) 0.4 s.

### Frame rate while playing
- `scripts/nichols_property.gd` walked the entire scene tree for directional lights every 15 frames and for the sky
  environment on every frame, from anywhere on the map: a 5 ms hitch twelve times a second. Both are cached now.
- New measurement `tests/play_perf.gd` (rendered, 1920x1080, High, uncapped, adaptive resolution off, RTX 4060):

| Street view | median | slowest 1 % | worst frame |
| --- | ---: | ---: | ---: |
| empty, before | 206 FPS | 86 FPS | 16.3 ms |
| empty, after | 212 | 121-128 | 8.4-9.7 ms |
| 10 zombies coming, before | 160 | 73 | 18.0 ms |
| 10 zombies coming, after | 167 | 101 | 11.5 ms |
| shooting them (hits every 6th frame), before | 133 | 57 | 33.2 ms |
| shooting them, after | 128 | 78 | 25.9 ms |
| bodies and blood left, after | 165 | 97 | 12.6 ms |

- The eight-view audit (`-- --performance-audit --audit-quality=2`, 1280x720): medians 2.4-4.6 ms (217-417 FPS);
  99th-percentile frames 3.7-6.5 ms (0.26: 9-14 ms).

### Gun
- **E never puts the gun away.** `gun.gd` `_before_use` no longer holsters: E opens, pulls, picks up and drops with the
  gun still in the hands. Only G / 1 (or the weapon's own key 2, 3, 4) puts it away.
- One exception by necessity: knocking on a locked door (E) plays the two-handed knock; the gun is lowered for the
  knock and **comes back up by itself** when it ends (`neighborhood_encounters.gd`).
- Scripted moments still take it out of the hands: waking at home after being killed, and the captures.

### Menus
- Options is two columns of selectors and a shorter controls list: 649 logical pixels tall on a 720-line screen (it
  was taller than the screen, so its title and Back button were cut off).
- `_layout_menu` now scales any menu window down, whole, if it would still be taller or wider than the screen.
- "Aim: Body camera (the muzzle leads)" is now "Aim: The muzzle leads"; "Keep the frame rate" has its explanation
  under the controls.

### Debug menu
- The debug menu (Q W E R T Y) was docked to the right edge and wider than its dock, so its right side and the Close
  button were off the screen. It is now a 640 x 660 window in the middle of the screen (`debug_menu.gd` `_fit`), is
  never larger than the screen, and its status text can no longer widen it. `-- --capture-review
  --capture-views=debug` prints `INTERIOR_DEBUG_WINDOW` with its position and size for each tab.

## How to build (changed)
`python -I tools/export_windows.py` — imports, **re-bakes the meshes and the manifest**, closes a running
`Interior.exe`, exports, prints the EXE's start-up report. Do not export by hand without
`python -I tools/boot_manifest.py` first: an exported game cannot tell that `world_meshes.res` is stale (project runs
and tests can, and fall back to merging).

Flags (after `--`): `--load-report` (start-up timings), `--load-quit`, `--capture-loading`, `--capture-menus`,
`--no-preload`, `--no-world-cache`, `--bake-world-meshes`.

## Checks
- `python -I tools/run_tests.py`: all 25 `*_integration` tests pass (zombies 81/81, gun 42, debug menu 39, touch 33,
  hut story 75, canal 57, warren 87, basement 57, Nichols 50, seals 30, siege 35, ...), no script errors.
  `gun_integration` step 11 now asserts that Hold takes the prop **with the gun still up**.
- EXE: version resource 0.30.0; `-- --load-report --load-quit` reaches the menu in 8.1 s with no errors;
  `-- --capture-loading --capture-menus` (loading screen at five points of its bar, home menu, Options: 760 x 649 at
  scale 1.0); `-- --capture-review --capture-views=gun` (17 frames: room, road, sights, torch, house);
  `-- --capture-review --capture-views=gore` (67 frames: wounds, severed arm and leg, crawler, buckshot, the scope at
  8x and 3x). Captures are in `work/v30/exe/`.
- The staged start and the old one-go start build the same world: `-- --load-report --load-quit` and
  `tests/load_profile.gd -- --load-report` print identical `INTERIOR_INVENTORY` lines (9,843 nodes, 3,613 meshes,
  3,213 collision shapes, 260 bodies, 108 lights and the same light masks).

## Not done, or not verified
- **Loading is faster, not instant.** About eight seconds remain in the EXE (ten in the project), five of them the
  districts still being assembled by script. The real fix is baking those districts to scenes like the room, balcony and fields; that is a larger job.
- **Low-end PCs** are still unmeasured (only the RTX 4060 here).
- Shooting a crowd still has single frames of ~26 ms (ragdoll and severed-part creation).
- `zombies_integration` failed 8 checks once when run alongside two other tests ("The head's hit box is on its
  head" and the three that follow it) and passed 81/81 on four other runs, two of them alone straight after: an
  intermittent failure in the 0.28/0.29 test, not looked into.
- With the gun up and a prop carried, left click fires (it does not throw); E drops the prop.
- 0.28/0.29 items still open: no licence/README entries for the synthesised zombie voices and blood decals; the
  zombie capture's rifle scene aims between the zombies; the shotgun view model distance was never re-checked.
- The Android APK is not rebuilt. `tools/build.ps1` still stops at `settling` (failing since 0.3).

## Gotchas
- `ResourceLoader.load_threaded_request("res://main.tscn", "", true)` (sub-threads) deadlocks: that was the stuck
  loading screen. Asking for other files while main.tscn compiles its scripts makes `preload` fail. Hence: leaf files
  first (parallel), then the scene alone.
- Applying the graphics level after the world has been drawn once recompiles every pipeline (4.5 s): the boot scene
  keeps `root.disable_3d` on until the world is whole.
- Start-up hooks that were `call_deferred` (prop settling, gates, moon beams, light masks) go through
  `InteriorLoadClock.later`, so behind the loading screen they still run after everything stands, in order.
- Test windows are visible on the owner's desktop: run them through `work/v30/run.py <seconds> <log> <cmd>`.

## 0.28 and 0.29 (no handoff was written)
- 0.28: AR-15 automatic while the mouse is held, pump shotgun, per-round ballistics (drop, drag, pierce), zombies
  built on generic_body (7 variants) that roam, see, hear and attack, ragdolls, persistent blood, debug-menu spawner.
- 0.29: hinged ragdolls, wounds that bleed where they were hit, severed limbs and heads by impact and calibre,
  crawling when legless, .338 bolt-action sniper with an 8x scope (mouse wheel 3x-8x, blur while moving).
  `--capture-views=zombies`, `--capture-views=gore`.

## Screenshots sent
| File | What |
| --- | --- |
| `work/v30/loading/loading-04.png` | Loading screen at 66 % (project) |
| `work/v30/menus/menu-options.png` | Options window fitting the screen (project) |
| `work/v30/exe-sheet-a.jpg` | EXE: loading screen, main menu, Options, room / street / house with the gun up |
| `work/v30/exe-sheet-b.jpg` | EXE: 0.29 wounds, severed arm, crawler, 8x scope |
| `work/v30/exe/debug/debug-1-items.png` | EXE: the debug menu centred and whole |
