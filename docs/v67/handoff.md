# 0.67 handoff: Options in the pause, holes audit, Outer Street's dread, the kiosk seal, search bursts capped

Owner's asks (2026-11-26): "players should be able to access Options when pausing the game. do intensive tests to make sure
the game is performing well and blazing fast with ultra buttery smooth FPS all across all maps and all missions, no holes,
no glitches, proper paths, proper triggers. then do intensive improvements on the Outer Streets level by adding more
details and more performance and more horror. then build APK EXE and update website and publish".

## What changed

| Area | Change | Files |
|---|---|---|
| Pause → Options | The squad game's pause (the only game now) is Resume / **Options** / Leave game. Options opens the same window as on the home menu; its Back and Esc return to the pause; the tree is never paused for one player's menu (the squad plays on) | interior.gd `_show_menu`, coop/session.gd `build_overlay`, `_unhandled_input` |
| Outer Street: the triage point | A rescue tent the night overran on the plaza's east carriageway (x 49.6..55.8, z 677.6..686.6): two canopies, cots, ten body bags (seven in a row on the road), drip stands, a waste bin, dressings, a spine board, two battery lanterns, a floodlight on its tripod knocked over and still burning low across the road toward the shutter, its generator. Two bags on the cots jerk now and then; within 5.5 m (host `outer_bags`) they split and two infected get up beside them. A healthkit lies by the boxes at the tent's north end (the plaza zone's drops) | coop/outer_dread.gd `triage`, `dread_host`, `dread_sync` |
| Outer Street: the first half's dead | Ten posed dead, let go limp like the row's (`DREAD_DEAD`): the avenue, the shutter, by the floodlight, the overpass, the terrace, the faregates, the power room's corner (where its drag ends), the platform, the track worker in the tunnel (his lantern on the ballast, his hard hat by the rail), the long stair | outer_dread.gd `dread_dead` |
| Outer Street: the train | The second car's tubes die when anyone reaches car one's far end (host `outer_train_dark`; a click, an arc's buzz, a growl); something comes out of the cab end through the dark | outer_world.gd `car(..., gate)`, outer_dread.gd |
| Outer Street: the long stair | Halfway up (x < 21) its lights die (host `outer_stair_dark`), the steel door at its foot bangs below, a scream from the tunnel, and three come up after the squad | outer_world.gd `long_stair`, outer_dread.gd |
| Outer Street: sounds | Once each per peer, where nobody can see the cause: a can across the dark concourse, a groan behind in the power room, a scream across the plaza from the overpass, something hitting the train's windows from inside, metal scraping at the tunnel's far end | outer_dread.gd `SCARES` |
| The kiosk seal (NOW standard) | Once every human is out on the river road (or anywhere on the row), the kiosk's steel door (now a hinged node standing open against the outside wall) slams shut (host `outer_kiosk_shut`); squad AI and students still inside are brought through first; what came up the stair beats on it. Every peer puts the avenue, the pile-up, the plaza, the hillside, the station and the tunnel away: roots hidden and stopped, their meshes let go of 2 ms a frame (mission `_free_stack`), the dead behind freed, the host drops the infected behind, the teleports back there are closed (`kept`). `_view` keeps them hidden | outer_dread.gd `_kiosk_check`, `_put_away_behind`; outer_street.gd `_view` |
| Holes fixed | Two floor slits over nothing found by the new audit: the concourse → power room doorway (the floors stopped at x 48.0 and 48.3) and under the kiosk's door to the river road (z 785.15..785.5). Dropped guns, kits, grenades and limbs could fall out of the world there | outer_world.gd `concourse`, `long_stair` |
| Outer Street perf | Lamps in a root the viewpoint has hidden are skipped (412 lamps were worked out every frame on every peer: Outer Street's script time -15..30 %). The posed dead (row and first half) throw no moon shadow (flat on the ground; each was drawn again in every shadow pass). The eight still bags are merged into the root's meshes (only the two that move are nodes) | outer_kit.gd `_lamps_tick`, `_lamp_root`; outer_dread.gd `quiet_shadows`, `_bag_still` |
| Outer Street nav premap | The chapter's ground is read into the nav's map in route order (`premap_outer`): the lane, avenue and plaza behind PILCST's board (a loading step, caption reused), the rest in the background at 0.8 ms a tick. The region's old cache is forgotten when the chapter is built (it was at the chapter's start, which would also have thrown the premap away) | coop/mission.gd, coop/session.gd |
| Search bursts capped | A waypoint link's search round a corner stops 1.5 ms past grow's budget and is retried later; the squad AI's path search stops after 4 ms and is retried next tick (what a stopped search read of the ground stays read). After a jump or a teleport one bot search was 20-57 ms | zombie_nav.gd `search_deadline`, waypoints.gd `grow`, coop/bots.gd |
| Version | 0.67.0, Android version code 67 | project.godot, export_presets.cfg |

## Checks

- New tests: tests/coop_pause_options.gd (in the suite: pause → Options → Back/Esc → pause → resume, never paused),
  tests/coop_hole_audit.gd (walk + climb flood fill at every chapter-one teleport and debug jump; void edges fail, drops
  listed), tests/hole_look.gd (captures at a reported spot), tests/outer_crowd_perf.gd (crowd frames per Outer Street
  place). coop_jumps checks the new flags behind each Outer Street jump and the kiosk seal (shut, six roots put away,
  no infected behind, the teleports back there closed).
- Test tools fixed: coop_perf_sweep's `_settled` (and the new tools) waited for a jump's catch-up before it had begun
  (it starts on the session's next frame): the 0.66 sweep rows for jumps that load a chapter could include the loading
  screen. tools/run_mission_suite.py takes SLEEP_SUITE_GAME (a frozen copy of game/, work/v67/snap: scripts and tests
  copied, the rest junctions) and SLEEP_SUITE_LOGS.
- Mission suite: baseline 24/24 (work/v67/suite_baseline.txt). Final: 24/24 (work/v67/suite_final.txt, logs in work/v67/suite_final/).
- Hole audit (radius 48 m, climbs on): before, 3 void edges (the two slits above) and drops at the canal banks (4-5 m,
  chapter one), the home's outer stair side (6 m) and a 5 cm slit between PILCST's east flight and its core (a ray
  threads it down five floors; nothing can fall through). Final: 0 void edges, the same 29 drops (work/v67/holes_final.log). The far bank lane teleport seeds no fill (0 cells: its spot is on a steep bank); the bank is covered from the bridge and the warren gate seeds.

## Performance (this PC: RTX 4060, Ryzen 7 5700X)

All numbers below were taken while an unknown `xcopy.exe` (parent `wmpnetwk.exe`, the WMP network service itself
stopped, paths hidden) used ~400 % CPU on the machine the whole session; frame times swing ±10-40 % run to run. Draw
counts are steady.

### PC: Forward+, High, 1920x1080, uncapped (0.66 snapshot -> 0.67 final; work/v67/perf/pc_before.log, pc_final2.log)

| Place | fps | 1% low | worst ms | draws | process ms | render ms |
|---|---|---|---|---|---|---|
| go courtyard | 98.1 -> 84.4 | 47.1 -> 53.1 | 28.0 -> 19.0 | 1261 -> 1249 | 1.11 -> 1.05 | 6.59 -> 6.07 |
| go bridge | 103.7 -> 104.4 | 67.4 -> 61.4 | 16.5 -> 19.7 | 2101 -> 2096 | 1.04 -> 1.08 | 7.08 -> 6.9 |
| go farbank | 105.3 -> 108.8 | 58.2 -> 53.3 | 29.3 -> 20.5 | 2074 -> 2072 | 1.07 -> 1.07 | 6.85 -> 6.62 |
| go warrengate | 149.2 -> 154.8 | 74.1 -> 87.5 | 16.3 -> 15.2 | 947 -> 943 | 1.07 -> 1.05 | 4.81 -> 4.63 |
| go plankbridge | 211.1 -> 194.3 | 80.4 -> 107.7 | 16.6 -> 10.6 | 533 -> 529 | 0.95 -> 1.01 | 3.45 -> 3.58 |
| go dodonghouse | 142.6 -> 144.0 | 80.6 -> 87.4 | 14.9 -> 12.6 | 1069 -> 1062 | 1.05 -> 1.04 | 4.94 -> 4.85 |
| jump ramp | 88.8 -> 97.4 | 46.7 -> 58.1 | 25.4 -> 19.1 | 2995 -> 3193 | 1.17 -> 1.07 | 8.68 -> 7.68 |
| jump gate | 92.5 -> 90.2 | 57.7 -> 49.9 | 17.7 -> 22.5 | 3045 -> 3201 | 1.05 -> 1.1 | 8.23 -> 8.4 |
| jump storeroad | 86.2 -> 81.9 | 52.2 -> 50.4 | 19.8 -> 20.8 | 2903 -> 3148 | 1.1 -> 1.17 | 8.45 -> 8.6 |
| jump mart | 140.6 -> 83.9 | 71.0 -> 57.7 | 17.1 -> 21.5 | 1613 -> 1516 | 1.0 -> 1.0 | 5.42 -> 5.33 |
| jump siege | 106.5 -> 105.9 | 65.4 -> 57.4 | 18.8 -> 17.7 | 2717 -> 2985 | 0.98 -> 0.97 | 7.13 -> 7.22 |
| jump office | 269.6 -> 247.1 | 104.5 -> 103.8 | 13.1 -> 10.5 | 457 -> 577 | 0.89 -> 0.91 | 2.82 -> 2.83 |
| jump jonna | 287.4 -> 245.3 | 132.2 -> 117.6 | 8.9 -> 10.8 | 340 -> 319 | 0.84 -> 0.95 | 2.6 -> 2.88 |
| jump backstreets | 127.5 -> 129.1 | 57.0 -> 67.2 | 18.3 -> 19.5 | 690 -> 802 | 1.4 -> 1.38 | 4.97 -> 4.75 |
| jump arcade | 166.9 -> 180.9 | 84.1 -> 92.6 | 15.0 -> 12.1 | 634 -> 661 | 1.33 -> 1.26 | 4.03 -> 3.76 |
| jump brickalley | 173.2 -> 162.9 | 92.1 -> 93.1 | 11.5 -> 12.6 | 955 -> 955 | 1.28 -> 1.33 | 4.11 -> 4.25 |
| jump school | 130.3 -> 135.7 | 73.5 -> 78.2 | 14.4 -> 13.0 | 1542 -> 1496 | 1.37 -> 1.32 | 5.5 -> 5.13 |
| jump lobby | 162.8 -> 154.3 | 68.9 -> 59.3 | 15.9 -> 21.2 | 823 -> 813 | 1.43 -> 1.47 | 4.21 -> 4.26 |
| jump floor2 | 82.6 -> 76.5 | 44.1 -> 32.8 | 22.9 -> 40.9 | 1160 -> 1242 | 1.78 -> 1.92 | 5.02 -> 5.42 |
| jump floor3 | 91.6 -> 100.4 | 48.2 -> 54.7 | 25.0 -> 20.1 | 1723 -> 1790 | 1.76 -> 1.58 | 6.28 -> 5.83 |
| jump floor4 | 92.0 -> 98.0 | 62.3 -> 64.8 | 19.5 -> 16.0 | 1871 -> 1991 | 1.5 -> 1.52 | 6.39 -> 6.14 |
| jump floor5 | 68.7 -> 69.4 | 40.9 -> 39.9 | 28.9 -> 26.7 | 1786 -> 2010 | 1.84 -> 1.84 | 7.29 -> 7.47 |
| jump horde | 225.9 -> 194.1 | 106.9 -> 96.1 | 12.6 -> 12.4 | 322 -> 385 | 1.27 -> 1.4 | 2.93 -> 3.39 |
| jump sneak | 100.0 -> 97.6 | 61.8 -> 53.5 | 17.7 -> 21.0 | 520 -> 607 | 1.82 -> 1.75 | 4.95 -> 4.98 |
| jump field | 90.3 -> 96.0 | 54.9 -> 56.5 | 19.6 -> 18.1 | 780 -> 753 | 1.93 -> 1.85 | 5.73 -> 5.59 |
| jump heavyarm | 122.3 -> 127.4 | 70.4 -> 69.2 | 24.8 -> 16.3 | 1037 -> 1105 | 1.67 -> 1.6 | 4.98 -> 4.8 |
| jump outerstreet | 105.0 -> 94.9 | 65.5 -> 59.2 | 20.7 -> 19.3 | 1484 -> 1552 | 2.18 -> 1.76 | 5.45 -> 5.72 |
| jump outerbus | 109.2 -> 95.1 | 69.7 -> 62.8 | 45.7 -> 19.2 | 1133 -> 1162 | 2.19 -> 1.94 | 5.05 -> 5.25 |
| jump outerplaza | 119.3 -> 100.4 | 60.5 -> 54.9 | 28.3 -> 29.9 | 778 -> 820 | 2.19 -> 2.01 | 4.56 -> 4.87 |
| jump outerterrace | 110.3 -> 96.8 | 59.9 -> 61.7 | 17.9 -> 20.3 | 866 -> 1173 | 2.39 -> 1.89 | 4.87 -> 5.24 |
| jump outerstation | 125.1 -> 108.1 | 68.9 -> 69.6 | 17.5 -> 16.4 | 652 -> 679 | 2.16 -> 2.02 | 4.6 -> 4.58 |
| jump outerplatform | 172.8 -> 171.3 | 88.6 -> 76.8 | 12.2 -> 15.4 | 321 -> 302 | 2.06 -> 1.73 | 3.29 -> 3.53 |
| jump outertunnel | 167.0 -> 169.0 | 85.3 -> 78.4 | 13.4 -> 16.3 | 284 -> 322 | 2.16 -> 1.67 | 3.22 -> 3.53 |
| jump outerriver | 184.6 -> 199.1 | 84.7 -> 80.3 | 12.8 -> 15.3 | 103 -> 105 | 2.16 -> 1.97 | 2.86 -> 2.74 |
| jump outerpizza | 200.5 -> 207.3 | 95.2 -> 86.0 | 12.2 -> 14.1 | 100 -> 101 | 2.03 -> 1.92 | 2.71 -> 2.72 |
| jump outermart | 84.3 -> 91.0 | 38.2 -> 56.1 | 31.6 -> 23.2 | 1695 -> 1437 | 2.39 -> 2.0 | 7.05 -> 5.71 |
| jump outerboutique | 94.3 -> 98.7 | 39.0 -> 49.2 | 44.8 -> 22.3 | 1654 -> 1381 | 2.27 -> 1.95 | 6.52 -> 5.59 |
| jump outerbridge | 162.6 -> 181.2 | 83.5 -> 85.3 | 13.9 -> 12.9 | 451 -> 448 | 2.08 -> 1.86 | 3.48 -> 3.29 |

- before: 38 places, worst > 25 ms at [('go courtyard', 28.0), ('go farbank', 29.3), ('jump ramp', 25.4), ('jump floor5', 28.9), ('jump outerbus', 45.7), ('jump outerplaza', 28.3), ('jump outermart', 31.6), ('jump outerboutique', 44.8)]; median < 144 at 25 places
- after: 38 places, worst > 25 ms at [('jump floor2', 40.9), ('jump floor5', 26.7), ('jump outerplaza', 29.9)]; median < 144 at 24 places

(`outerboutique` is not a jump name: that row re-measures the mart 3 s later. An earlier final run, pc_final.log,
overlapped the publish's chunking and is not used.)

Read: frames over 25 ms went from 8 places to 3; Market Row is smoother (the mart's 1 % low 38 -> 56, worst 31.6 ->
23.2 ms; the boutique's worst 44.8 -> 22.3 ms; draws -15 %), the bridge and the river road are faster, and script
time is down at every Outer Street place (lamps). The first half's medians are ~10-15 % lower than 0.66's (plaza
119 -> 100, terrace 110 -> 97): the new tent, dead and lights cost drawing there (render +0.3 ms). Chapter one and the
college move within the run-to-run noise.

### Phone mode: this PC on the phone renderer (gl_compatibility, --mobile-test, 1600x720, quality 0)

| Place | fps | 1% low | worst ms | draws | process ms | render ms |
|---|---|---|---|---|---|---|
| go courtyard | 80.2 -> 69.9 | 34.2 -> 47.9 | 32.6 -> 22.0 | 481 -> 480 | 1.11 -> 1.12 | 7.29 -> 6.77 |
| go bridge | 76.0 -> 76.8 | 54.1 -> 49.9 | 54.4 -> 20.8 | 834 -> 836 | 1.07 -> 1.07 | 10.04 -> 9.9 |
| go farbank | 70.2 -> 61.9 | 36.4 -> 42.1 | 32.8 -> 24.4 | 805 -> 805 | 1.11 -> 1.11 | 9.93 -> 9.46 |
| go warrengate | 88.7 -> 88.5 | 65.0 -> 63.4 | 15.9 -> 20.7 | 438 -> 438 | 1.09 -> 1.1 | 7.32 -> 7.43 |
| go plankbridge | 152.2 -> 167.6 | 84.6 -> 100.6 | 17.3 -> 10.9 | 172 -> 174 | 1.04 -> 1.02 | 4.61 -> 4.34 |
| go dodonghouse | 84.3 -> 84.2 | 60.8 -> 58.5 | 17.4 -> 17.3 | 591 -> 591 | 1.09 -> 1.11 | 7.89 -> 7.89 |
| jump ramp | 80.3 -> 71.2 | 52.9 -> 51.6 | 19.4 -> 21.9 | 671 -> 658 | 1.06 -> 1.1 | 8.47 -> 8.69 |
| jump gate | 114.9 -> 116.1 | 65.9 -> 75.8 | 20.6 -> 14.7 | 476 -> 474 | 1.09 -> 1.07 | 6.26 -> 6.07 |
| jump storeroad | 96.0 -> 94.8 | 54.6 -> 54.3 | 57.1 -> 70.0 | 481 -> 472 | 1.37 -> 1.38 | 6.73 -> 6.95 |
| jump mart | 138.7 -> 154.7 | 77.8 -> 85.9 | 15.7 -> 15.2 | 424 -> 426 | 1.04 -> 0.99 | 5.34 -> 4.88 |
| jump siege | 98.2 -> 98.9 | 64.7 -> 62.3 | 16.2 -> 16.6 | 651 -> 647 | 1.04 -> 1.04 | 7.84 -> 7.83 |
| jump office | 208.9 -> 180.7 | 103.4 -> 80.9 | 11.9 -> 15.4 | 216 -> 213 | 0.9 -> 0.99 | 3.66 -> 3.97 |
| jump jonna | 226.9 -> 204.1 | 114.3 -> 111.0 | 10.4 -> 9.6 | 175 -> 167 | 0.89 -> 0.96 | 3.39 -> 3.55 |
| jump backstreets | 109.5 -> 104.6 | 72.7 -> 74.0 | 19.4 -> 16.0 | 323 -> 314 | 1.35 -> 1.39 | 5.65 -> 5.74 |
| jump arcade | 147.6 -> 125.2 | 82.9 -> 77.7 | 64.8 -> 14.2 | 304 -> 299 | 1.27 -> 1.33 | 5.04 -> 5.13 |
| jump brickalley | 133.4 -> 143.9 | 74.5 -> 82.2 | 15.6 -> 15.7 | 316 -> 303 | 1.38 -> 1.32 | 5.15 -> 4.84 |
| jump school | 126.2 -> 123.5 | 71.5 -> 82.8 | 14.9 -> 13.3 | 425 -> 440 | 1.31 -> 1.3 | 5.66 -> 5.63 |
| jump lobby | 116.7 -> 115.2 | 63.2 -> 66.4 | 39.0 -> 16.6 | 285 -> 258 | 1.52 -> 1.48 | 5.0 -> 5.0 |
| jump floor2 | 69.6 -> 67.5 | 40.0 -> 38.3 | 31.1 -> 27.4 | 402 -> 387 | 2.02 -> 2.03 | 6.92 -> 6.5 |
| jump floor3 | 77.0 -> 84.0 | 40.9 -> 47.1 | 39.3 -> 22.5 | 590 -> 571 | 1.7 -> 1.64 | 7.42 -> 7.04 |
| jump floor4 | 90.5 -> 85.6 | 57.2 -> 51.3 | 20.9 -> 25.1 | 538 -> 550 | 1.45 -> 1.63 | 6.56 -> 6.89 |
| jump floor5 | 68.1 -> 74.3 | 30.4 -> 36.8 | 32.9 -> 32.3 | 530 -> 526 | 1.91 -> 1.74 | 7.66 -> 6.95 |
| jump horde | 189.1 -> 170.2 | 78.0 -> 78.6 | 14.2 -> 14.7 | 189 -> 197 | 1.3 -> 1.4 | 3.85 -> 4.28 |
| jump sneak | 87.0 -> 85.0 | 52.3 -> 51.9 | 22.9 -> 19.7 | 248 -> 223 | 1.75 -> 1.75 | 5.81 -> 5.85 |
| jump field | 83.8 -> 79.6 | 52.9 -> 53.0 | 26.2 -> 25.0 | 346 -> 328 | 1.94 -> 2.01 | 6.36 -> 6.5 |
| jump heavyarm | 124.5 -> 105.2 | 70.4 -> 60.8 | 22.9 -> 18.3 | 261 -> 301 | 1.52 -> 1.65 | 5.04 -> 5.81 |
| jump outerstreet | 94.3 -> 86.2 | 64.1 -> 57.9 | 16.8 -> 18.4 | 558 -> 605 | 2.08 -> 1.77 | 6.28 -> 6.9 |
| jump outerbus | 89.6 -> 78.9 | 53.4 -> 55.8 | 37.2 -> 29.7 | 513 -> 578 | 2.29 -> 1.99 | 6.51 -> 7.03 |
| jump outerplaza | 91.8 -> 78.6 | 58.8 -> 43.8 | 41.0 -> 31.7 | 501 -> 547 | 2.18 -> 2.05 | 6.27 -> 6.95 |
| jump outerterrace | 87.9 -> 75.8 | 61.5 -> 52.5 | 16.4 -> 20.6 | 583 -> 626 | 2.29 -> 2.01 | 6.58 -> 7.43 |
| jump outerstation | 77.0 -> 70.3 | 55.4 -> 51.1 | 19.2 -> 22.3 | 482 -> 497 | 2.21 -> 2.22 | 6.78 -> 7.25 |
| jump outerplatform | 140.7 -> 106.7 | 68.0 -> 60.2 | 16.6 -> 18.5 | 237 -> 249 | 2.07 -> 1.79 | 4.49 -> 4.99 |
| jump outertunnel | 134.3 -> 110.8 | 73.0 -> 62.6 | 15.2 -> 17.4 | 204 -> 233 | 2.18 -> 1.75 | 4.3 -> 4.63 |
| jump outerriver | 126.9 -> 105.0 | 76.8 -> 65.7 | 14.1 -> 16.7 | 141 -> 175 | 2.25 -> 2.26 | 4.32 -> 4.44 |
| jump outerpizza | 150.4 -> 142.7 | 82.2 -> 75.6 | 22.6 -> 13.7 | 140 -> 173 | 2.04 -> 1.96 | 3.95 -> 4.08 |
| jump outermart | 78.7 -> 75.3 | 46.9 -> 45.7 | 97.5 -> 24.6 | 817 -> 776 | 2.32 -> 2.12 | 8.28 -> 7.76 |
| jump outerboutique | 85.1 -> 77.2 | 58.4 -> 47.4 | 44.2 -> 22.0 | 811 -> 759 | 2.19 -> 2.11 | 7.34 -> 7.84 |
| jump outerbridge | 134.1 -> 115.9 | 81.1 -> 70.4 | 14.4 -> 18.1 | 269 -> 267 | 2.03 -> 1.96 | 4.39 -> 4.54 |

- before: 38 places, worst > 25 ms at [('go courtyard', 32.6), ('go bridge', 54.4), ('go farbank', 32.8), ('jump storeroad', 57.1), ('jump arcade', 64.8), ('jump lobby', 39.0), ('jump floor2', 31.1), ('jump floor3', 39.3), ('jump floor5', 32.9), ('jump field', 26.2), ('jump outerbus', 37.2), ('jump outerplaza', 41.0), ('jump outermart', 97.5), ('jump outerboutique', 44.2)]; median < 144 at 32 places
- after: 38 places, worst > 25 ms at [('jump storeroad', 70.0), ('jump floor2', 27.4), ('jump floor4', 25.1), ('jump floor5', 32.3), ('jump outerbus', 29.7), ('jump outerplaza', 31.7)]; median < 144 at 33 places

Every place holds a 60+ median (lowest 71.2 at the ramp). Frames over the phone budget (33 ms) went from 8 places to 1
(Store Road, a first-draw render spike). The worst single frames left on the phone path are render
spikes the first time a place is drawn (pipelines compiled on first sight: phones do not preload them) and the same
physics-script bursts as on PC.

## Not done / open

- PC median ≥ 144 fps is still not met at the heavy places (chapter one, Store Road, the mart siege, PILCST floors 3-5,
  Outer Street's first half and the mart: 85-115 fps). They are draw-bound (1,200-3,000 draws, render 5-8 ms); the next
  lever is merging or culling the town and Store Road districts, not scripts.
- No physical phone measured (as in 0.64-0.66).
- The bags only split for someone who walks into the tent (the healthkit there is the reason to).

## Text on screen added in 0.67

- Pause: the button "Options" (the window itself is the existing Options window).
- No new objective lines, captions or labels (Outer Street's new loading step reuses "Building Outer Street").
- Website (not in game): "Each gate and door shuts behind you"; "Esc (Pause on a phone) brings up the pause, and Options
  there changes the graphics, sound and display while the squad plays on."; the rice-fields tile replaced by an Outer
  Street shot. Release notes: tools/release/notes/0.67.0.md.

## Screenshots sent

| When | File |
|---|---|
| Outer Street WIP (triage, dead, stair lit/dark, dark train, kiosk shut) | work/v67/dread_sheet.jpg |
| The 0.67 EXE: the squad pause with Options, Options over the running game | work/v67/exe/exe_coop_pause_options.jpg |

## Builds and publish (2026-11-26)

- Windows: builds/windows/Interior.exe + Interior.pck (1,491 MB), Sleep-0.67.0-windows.zip, via tools/export_windows.py
  (re-exported once after `--capture-menus` gained the squad pause and its Options: `menu-coop-pause.png`,
  `menu-coop-options.png`, captured from the EXE in work/v67/exe/, tree not paused). EXE start-up: menu frame at 17.4 s.
- Android: builds/android/Interior.apk, `--export-debug "Android"`, 824,407,632 bytes, apksigner verifies, signer
  certificate SHA-256 749565e2... (the same as 0.64-0.66: installs over them).
- Published (owner's message: "then build APK EXE and update website and publish"): PC 0.67.0 staged (13 new chunks,
  0.02 GB), uploaded, activated; release.json reads 0.67.0 with four notes; APK at /downloads/Interior.apk (200, full
  length); downloads/index.json reads game 0.67.0, android 0.67.0; website republished (79 files).
