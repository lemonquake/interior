# 0.49 handoff — patch-ups, bullet walls, the mart chapter

Owner's requests (2026-11-20):
1. The healed AI teammate walked off mid patch-up.
2. Invisible walls blocked bullets across the map, especially in the slums.
3. After the talk, Jonna shuts and locks the whole front; the map behind is soft-unloaded; the leaderboard shows a READY button and
   the run goes on when everyone is ready; while it shows, the next map loads and the previous one unloads.
4. Build the game.

## 1. Squad AI holds still for a patch-up
- `mission.in_heal(id)`: is this id at either end of a patch-up.
- `bots.gd _decide`: while `in_heal`, mode `patch`, dest = where it stands, nothing else runs (it still turns and shoots).
  It also no longer spends its own kit while a human with a kit stands within 2.6 m (`_medic_near`).
- `bots.gd _move`: in a patch-up the velocity is zeroed at once. Before, it slid on at running pace. It also no longer
  steps aside for the teammate who is patching it.
- `heal_tick`: a patch-up done by a squad AI is never broken off for distance; for a human healer the limit went from 3.0 m to 3.4 m.

## 2. Bullet walls
Tool: `tests/bullet_wall_audit.gd` (`--solo` for the solo map, `--step`, `--out`). It stands on a grid, casts the
round's ray (`InteriorSurfaces.seen_ray`, `InteriorGun.MASK`) eight ways, and reports hits with no drawn triangle
within 25 cm of the hit point.
Findings: the box colliders round models (jeepney, tricycles, food carts, the soldiers' truck, the stockroom racks)
and the solid box of the Old Salmonan gate (bars drawn, box solid). The backstreet barriers' colliders were taller
than their sheets. The solo street's vehicle and cart boxes had the same problem.
Fix:
- `InteriorModelKit.SHOT_LAYER` (64), added to `InteriorGun.MASK`, the squad AI's shot and the mission's fallback shot.
- `InteriorModelKit.shot_proxy(box, model)`: marks the walking box `unseen` (rounds pass) and gives the model a
  trimesh body on the shot layer, so rounds strike what is drawn.
- `InteriorSurfaces.unseen` honours meta `unseen` and names ending in ` void`. `seen_ray` steps 1 cm past an unseen
  hit (it was 28 cm, which jumped over things drawn inside a box), 8 tries.
- `street.shot_box` covers the truck. The gate has per-part shot shapes. The barrier colliders are 2.54 m tall.
- The solo map: `neighborhood._shot_proxies` (runtime: the street is baked).
- Squad AI sight and shots use `_sight` (through walking boxes), and still move by the real colliders.
Co-op audit: 28 offenders before, 20 after. The ones left are fridge and shelf fronts and barrier tops, a few hits each.
The solo audit still lists the siege walls, tree trunks and Nichols interiors: probably false positives (shader-displaced
sheets, alpha foliage), not looked into.

## 3. The mart chapter
- `street.front_shutter()`: a full-width roll-down shutter, rails and housing under the fascia, hasp and padlock.
  `flags.shutter` 0..1 drives it on every peer. Solid (layer 2) past 55 %. Sounds: scrape, then a metal slam, then the lock.
- `mission`: after the TALK lines, `_start_lockup` → `flags.lockup` 1 walk out (nav path), 2 pull down
  (`SHUTTER_TIME` 3.8 s), 3 padlock, 4 shut + board, 5 moved on. Jonna then walks back to her seat.
- `shut_front()` (every peer, when `flags.locked`): `_soft_unload` (the old `_leave_behind` body, generalised) keeps
  only z ≥ 55.6 (street-local). The infected outside are freed (host), and so are the dead outside.
- The backstreets are built at start as before but put away (`_put_ahead_away`): hidden, their sounds' processing off,
  their dead hidden. Colliders stay, because those dead are ragdolls. `wake_ahead()` runs when the board comes up, and
  from `backstreets()` (tests and debug call that directly).
- The board: `flags.board`; `session._board_tick` opens `coop_board` on every peer and rebuilds it when someone
  readies. READY sends `next_ready` (accepted even when downed); the squad AI are always ready. Host: all humans
  ready → `_board_done` → `backstreets()` (stage 8). ESC does nothing while the board is up.
- Debug "Next objective" at stage 7: lockup straight to the padlock, then (again) everyone ready.
- The final Match Results screen is unchanged (Leave game only). There is no next map after the school yet.

Test: `tests/coop_chapters.gd` (26 checks: patch-up stand-still, dormant/wake, jeepney/gate rounds, the lockup,
the board, READY → stage 8). EXE capture: `-- --capture-review --capture-views=coop_chapter --capture-path=<dir>`.
`coop_route` now wakes the backstreets before its backstreet shots.

## Gotchas
- Co-op tests that host cannot run in parallel: they share the ENet port and fail at `host()`.
- `find_child("jeepney")` finds the backstreets' road-glimpse jeepney first.
- An `AudioStreamPlayer3D` with autoplay ignores `stream_paused` set before it starts: use `process_mode` DISABLED.
- `model_kit.gd` is in the build cache's SOURCES: re-bake before export (export_windows.py does).

## Screenshots sent
| file | what |
|---|---|
| work/v49/screens/chapter_shutter_coming_down.png | EXE: Jonna at the front, shutter half down |
| work/v49/screens/chapter_board.png | EXE: chapter leaderboard, READY, AI already ready |
| work/v49/screens/chapter_backstreets_awake.png | EXE: after READY, the backstreets woken (stage 8) |

## Tests run (all headless, one at a time for the co-op ones)
coop_chapters 26/26, coop_kits_modes (one stale check fixed: the drop prompt now names the gun, e.g. "AR-15"),
coop_squad_integration 27/27, coop_backstreets_integration 9/9, fair_world_integration 53/53.
Build: builds/windows/Interior.exe 0.49.0 (export_windows.py, re-baked), zip Sleep-0.49.0-windows.zip.
Not tested: real two-PC play of the board (a client's READY goes over the existing `use` RPC).

## Follow-up (same day): shove nerf, debug menu in multiplayer
Owner: the T shove was far too strong; Q W E R T Y did nothing in multiplayer.
- Shove, co-op (`mission.shove/_stumble`) and solo (`body.shove`, `zombie.shoved`): reach 1.3 m (was 1.9 / 1.75),
  one body (the nearest in front), about 0.3 m back, a 0.35-0.65 s stagger. It only goes down if it was already
  reeling (20 %). Only one standing right behind it (< 0.75 m) gets a light jostle. Props get at most ~45 N s
  (was mass x 3, up to 190). Co-op cooldown is 1.0 s.
- Debug menu: in co-op, T is the shove and `session._input` swallowed it, so the sequence never finished. The
  six keys are now polled from the keyboard every frame (`_poll_sequence`), skipped while typing in a text box.
  `can_open` accepts a live co-op game. Any squad member can use the Co-op buttons: a client's press goes to the
  host (`session.debug_request`), which runs `coop_as(id, ...)` for that player ("+1 me", "hurt me", "5 round me",
  "next objective" teleports them back via `debug_teleport`). The player stands still while it is open.
- Test: tests/coop_shove_debug.gd (11 checks). debug_menu_integration 39/39 still.
- Not tested: a real client's debug buttons over the network.

## Follow-up 2: the mart siege never ended (no office, no Jonna)
Owner's screenshot: everything in the mart killed, objective still "push tables into the doorway" (stage 5).
Stage 5 needed `wave_left == 0 and back_left == 0 and enemies.is_empty()`, and three things could hold that open:
1. The back group still hammering at the shut (often table-braced) back door, outside the walls where nobody can
   see or reach them. Now: once the waves are in and nobody is left inside, after 4 s they break the door in
   ("The back door gives way!") and come in to be killed.
2. A wave whose spawns kept failing never counted down. Now 11 failures in a row (~6 s) count one off; the back
   group the same after 8.
3. Any straggler out of reach (asleep up the street, stuck) kept `enemies` non-empty. Now, with the waves done and
   nothing at the back door, 15 s with nobody in the mart lets them go (dead entries just stop counting).
`mission._mop_up`, logged as `INTERIOR_COOP_SIEGE` every 10 s. Test: tests/coop_siege_end.gd (7 checks, all three
cases, ends with Jonna calling them into the office). coop_store_survival still passes.

## Follow-up 3: debug missions (complete an objective, jump into a mission)
Host-side in coop/mission.gd, usable by any player (a client's request goes to the host and the reply comes back):
- `debug_complete()`: the objective in hand, done the way play would do it. One stage forward, at once:
  0 Dodong speaks; 1 Dodong walked home; 2 the keys taken; 3 the gate opened (open_road); 4 everyone in the mart,
  the siege starts; 5 the siege won (refill, office opens); 6 Jonna reached, the talk starts; 7 the talk, lockup
  and board done; 8 the school reached (WON).
- `debug_jump(place)`: forward to a place in `JUMPS` (or a stage 0-8). Every objective on the way is completed in
  turn, the infected are cleared and the whole squad (players and AI) is put there, facing the right way.
  Places: dodong, escort, keys, ramp, gate, storeroad, mart (in front of the convenience store), siege, office,
  jonna, board, backstreets, school. Backward jumps are refused (what is behind gets put away).
- `debug_command(id, line)`: the command line. help, places, complete/done/next, jump/goto <place>, stage,
  spawn [n], kill, heal, kits [n], god on/off, give <weapon id or class>, ammo, bots [n], tp <x> <y> <z>
  (street-local), where.
- Debug menu (Q W E R T Y): new **Missions** tab with Complete objective, Where am I, a button per jump, and the
  command line (Enter runs it; the host's answer shows under it). World > Co-op "Next objective" uses complete now.
- Launch straight into a mission: `Interior.exe -- --coop-jump=mart [--coop-bots=2] [--coop-mode=easy]`
  (`interior._coop_jump_start`; `--coop-jump-capture=<dir>` saves a picture and quits, for checks).
- session: `debug_move_one`, `debug_move_squad`, `debug_teleport(to, yaw)`; notices go to the open console.
Tests: tests/coop_jumps.gd `-- --walk` (43 checks: every jump in order) and `-- --direct` (23: mart from the start,
then every command and the menu's command line). debug_menu_integration's brightness check now waits for the
switch-on flicker (it read 9.1 = 26 x .35 when headless frames ran short).
