# Sleep 0.35 — the menu is there in a second

Owner request (2026-11-17): "continue". This run first finished 0.34, which had been cut off before its last
export, and then took the item that has been open since 0.30: the wait before the game can be used.

Build: `builds/windows/Interior.exe`, 0.35.0, exported 2026-11-17 11:09,
SHA-256 `00aee9b944c80d4c7151229c4a43709a0be3de024c6a5387dcd5b763a1507fdc`.

## 0.34 was not finished: it is now

The 0.34 EXE on disk was older than the touch buttons and the climbing fixes, and `docs/v34/handoff.md` still had
its blanks. The EXE was exported again (10:52), the glass pictures were taken from it
(`docs/v34/captures/glass-*.png`), and the handoff was filled in. All 32 tests had passed after the last change.

The question 0.34 left about the Nichols house is answered: upstairs is meant to be reached, on foot, by the
stairs (centre flight, landing, west return flight; `docs/nichols-v21/handoff.md`), and `nichols_integration`
walks it. The 230 cells the climbing audit marks as "only by climbing" are the audit's own fill not following
that stair on foot. Nothing was changed in the house.

## The menu on the loading screen

Measured first, in the EXE: the menu was on screen 8.5 to 9.1 s after the game started. 3.8 s of that passes
before anything is built (engine 1.2, files 1.4, main scene .9, instantiating .4) and 4.3 s is the builders.
The frame the builders give up between steps costs nothing (tried with `-- --breathe-ms=22 / 90 / 400`: the same
within the noise), so the 4.3 s is real work, spread over some seventy steps of which the largest is .7 s. No
change short of baking the whole world gets the old kind of start under 4 s.

So the menu no longer waits for the world:

- `scripts/loading_screen.gd` is the home menu as well. From its first frame, **1.3 s after the game starts**, it
  shows the title, Play, Options and Quit exactly where the real menu has them (same sizes, colours and focus
  box; compared pixel for pixel in `docs/v35/captures/early-menu-vs-real-menu.png`), over a still of the menu's
  street.
- The still is `game/assets/ui/menu_still.jpg`: the game's own home menu with the title and buttons taken off
  (`-- --capture-menu-still=<file>`), taken by `tools/menu_still.py`, which `tools/export_windows.py` now runs
  before every export. A game window is on screen for about twelve seconds while it does.
- The caption, the bar and the tip are still there, smaller and lower so they clear Quit at 720 lines.
- **Play or Options pressed before the world stands** is kept (`InteriorLoadClock.wish`): the buttons fade, the
  bar finishes, and the game goes straight into play (or to Options) without stopping at the menu again. Quit
  leaves at once.
- **Nothing pressed**: when the world stands the screen fades as before and the real menu is underneath in the
  same place, with the street now alive. A click during the fade lands on the real button; a button held down in
  the very frame the fade starts counts as pressed (it would otherwise lose its release).
- A restart from the pause menu comes back the same way.

What this does and does not buy: the menu can be used after 1.3 s instead of 8.5 s. The world still takes its 8 s.
Someone who presses Play the instant the menu appears waits for the bar exactly as long as before; someone who
takes a few seconds over the menu never sees a wait.

### Checked from the EXE

| Run | Result |
|-----|--------|
| `-- --load-report --load-quit` | menu on screen 1273 ms, world done 7688 ms, real menu drawn 8053 ms |
| `-- --early-wish=play:3.0` (a real click on Play at 3.0 s, while the files are read) | "play: the game begins" at 7896 ms |
| `-- --early-wish=options:ready+0.2` (a click during the fade) | lands on the real menu |
| `-- --capture-loading` | `docs/v35/captures/loading-01..05.png` |
| `-- --capture-menus` | `menu-home.png`, `menu-options.png`: Options is centred and whole (797 x 698 at x 245, y 14) |

In the project also: Play clicked at 0 s, 6.5 s (mid-build) and in the hand-over frame; Options at 5 s.

`--early-wish=<play|options>:<seconds since start | ready | ready+seconds>` sends a real mouse click to that
button of the early menu. It uses the wall clock: a scene-tree timer loses time in every long frame of the build
(an 8.3 s timer had not fired after 10 s).

## Not done

- **The world itself in under 4 s.** Needs the districts baked to a scene, or built in the background after the
  menu's street (canal, Nichols and the warren cannot be seen from the menu's camera: about 2.3 s of the 4.3).
- **Breathing sounds.** Still needs a CC0 recording downloaded; not done without being asked.
- Glass in the player's own house and the canal houses.
- The climbing audit's on-foot fill does not follow the Nichols stair (above).
- The Android APK has not been rebuilt since 0.8. The early menu leaves Quit out on a phone
  (`touch_integration` passes) but has not been seen on one.
- Nothing has been committed to git since 0.8.

## Tests

`python -I tools/run_tests.py`: all 32 passed after the last change to a script (logs in `work/v30/tests/`; the
runner prints "NO REPORT" for the tests whose last line is not `INTERIOR_*`, those are read from their logs).
The tests start the game without the boot scene, so the early menu is covered by the EXE runs above, not by them.

## Captures (from the EXE)

- `captures/loading-02.png`: the early menu at 21 % of the load.
- `captures/early-menu-vs-real-menu.png`: the early menu (left) and the real one (right).
- `captures/menu-home.png`, `captures/menu-options.png`: the real menus.
