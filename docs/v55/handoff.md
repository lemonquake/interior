# 0.55 handoff — co-op mission skips settle everything behind them; every mission and every place in the debug menu

Owner's request (2026-11-22): "Let's polish the Mission skips in the Debug options in Multiplayer. When the player
jumps and skips to a specific mission, make sure that all prior triggers and checkpoints are marked as finished and
checked thoroughly so that the mission will start cleanly. ... And also add all the known places in the Debug options
for the player and his team to teleport into."

## What was wrong with the skips (0.49-0.54)

A jump ran `debug_complete` once per stage (one objective each) and then cleared every infected. Play does more than
one objective's worth on the way, so a jump straight from the start left the run half-finished:

- **The service gate**: no jump set `backdoor_open` / `alley`. Past the mart the back door and the service gate stayed
  shut behind the squad, and since `_leave_behind` waits for `alley`, the town, the canal and Store Road were never
  put away for the rest of the run.
- **PILCST's floors**: a floor is "reached" (`flags.floor<k>`) only by walking onto it. A jump to Ma'am Teves (or any
  later place) left all five unvisited: arriving on the fifth floor spawned its sleepers, a class and a **rush down the
  corridor at 501's door**, and the bell rang. (tests/coop_escape.gd had been patching the flags by hand.)
- **Rommel's gate** never shut behind a jump into the school (`school_shut`), so the backstreets stayed loaded too.
- **The mart's rifles**: the rack is only offered during stages 4-5. Past the mart nobody had a rifle, and never could.
- **The mart's chapter board**: a jump passes the board within one call, so the board (and its loading: freeing the
  street behind, waking the backstreets, loading the college's people) never ran.
- **Kuya Boy** (the janitor in the mechanical room) is spawned when the fourth floor is first reached: a jump to the
  ladder or the duct had no one there.
- Jumps to Store Road or the backstreets **deleted the sleepers ahead** of the squad (the stage's own content).
- **Stale dialogue**: whatever the last step said stayed up (Dodong's "This is my house" at the mart front).
- **Placement**: the squad was set side by side across the facing; on a 2.6 m fire-escape landing or in a corridor the
  third and fourth went into a wall or over the edge; Ma'am Teves's students were put in a straight line behind (off
  the landing).
- The **Missions tab** only had buttons up to the school gate; the rest of the 0.50-0.53 jumps were command-line only.
- `reargate` (0.52) had become the same place as `heavyarm` once Heavy-arm sat there (0.53).

## What a jump does now (`scripts/coop/mission.gd`)

`debug_jump(place)`: every objective before the place's stage done the way play does it (`debug_complete`, now sharing
play's own code: `_dodong_talks`, `_dodong_home`, `_keys_taken`, `_open_back_door`, `_open_alley`, `_kuya_boy`), then
`_clear_behind` and `_settle`, then the squad (and the survivors) put on clear ground there.

Each JUMPS entry has a fifth field saying how the place is left:

| key | meaning |
|---|---|
| `fresh` | the stage as it begins in play: its own sleepers, waves and opening line stand |
| `outback` | out of the mart's back door and through the service gate (Jonna's key) |
| `floors` | how many PILCST floors were crossed on the way up (reached, rushes and classes behind, doors met, bells quiet); the floor the place is on, if not among them, is reached on arrival as in play |
| `kuya` | Kuya Boy feeding in the mechanical room |
| `heavy` | `down` Heavy-arm dead, key on the ground; `open` key taken, gate unlocked; `out` through it, the board up |
| `line` | keep the last line (it says where things stand) |

`_settle` (everything a run that got there has behind it): everyone at 100 HP, tables let go, patch-ups stopped;
Dodong's warren doors open (as `escort` opens them); past the siege each survivor without one carries a rack rifle
(people first, `flags.rifle<i>` marked); Jonna seated, the front locked, the lockup over; out the back; the story told;
Rommel's gate opened and shut behind; the floors crossed (`_floors_crossed`: `flags.floor<k>`, their doors in `fired`,
pending bursts dropped, `flags.quiet_floors` so no peer rings their bells); Kuya Boy; Paolo's line about the stairs
(`escape._entered_two`); Heavy-arm as far as `heavy` says (`heavyarm.gd debug_down` / `debug_finish`, `escape.out`).
The music's threat is reset, the last line cleared unless the place begins its stage, and `flags.settled` (the stage
whose start is already behind) keeps every peer from hearing again what is behind it (`escape.render`: the horde's bed
and crash, the chain, the blast).

`_clear_behind`: infected behind the spot go; what play has waiting ahead stays (asleep further up Store Road and the
backstreets, the horde standing on the fifth floor, the field's, Heavy-arm). Waves stand only where they belong (the
siege, the backstreets' trickle, the pack following up Store Road from its foot). Store Road's houses already passed
count as forced.

`jump_blocked(place)`: forward only. Same-stage jumps are allowed except the board once it is up and the rear gate's
fight going backwards (HEAVY_STEPS). A stage number jumps to the place it begins at (`stage_place`).

`complete` (the menu's "Complete current objective") is now the jump to the next stage's start, so it settles the same
way (from the lobby it used to bring the fifth floor's rush down on 501's door).

New and changed places: `backdoor` (stage 8 begins: the key in hand, the back door and the gate still to open),
`arcade` (halfway along the backstreets), `heavykey` (him down, the key where he fell), `reargate` (now: him down, the
key taken, the gate open), `pilcstout` (out, the chapter board up). 35 in all; `jump 0`..`jump 15` still work.

**The chapter loading after a jump** (`session.gd`): `chapters_loaded` records each board's loading finished; a game
whose run is past the mart's board without it (stage 8+) runs the same steps behind the chapter screen held up
(`_catch_up`: "The backstreets", the step, the bar), then fades it as after the board. Every peer does this from the
snapshot's stage.

**Placement** (`mission.squad_spots`): side by side where there is room, then rows behind, then one ahead; each on
ground at the same level, in sight of the first spot (not through a wall), 0.7 m apart. `session.debug_move_squad`
uses it (whoever asked gets the spot itself) and so does `escape.debug_place` for Ma'am Teves and the students.

## Teleports

`mission.places()`: 63 known places in eight groups (the canal and Dodong's warren, Old Salmonan and Store Road, the
mart, the backstreets, PILCST grounds to the third floor, the fourth and fifth floors, the field and the rear gate, and
the town the run starts in: the house, the Nichols property, the wall's ways through). The school's spots are ones its
review captures stood on.

`debug_go(id, key, alone)` (command `go <place> [me]`): the squad (or only you) there, the run left as it is. A place
put away behind the run (outside any box `_soft_unload` kept: `kept`) is refused; a place in the backstreets or the
college ahead of the run wakes them early on every peer (`flags.woken`). `squad` brings the squad to you. The squad AI
warp back to their leader when 32 m off (bots.gd), so after `go <place> me` they follow you there by themselves.

## The Missions tab (`scripts/debug_menu.gd`)

- Objective: where the run stands (stage and objective), Complete current objective, Where am I?
- Command line (moved up), `help` lists everything.
- Jump to a mission: 35 buttons under five chapter headings, greyed (with the reason as a tooltip) once behind the run.
- Teleport: "Bring the squad" (on by default; off moves only you), "Bring the squad to me", then 63 buttons under the
  eight groups, greyed once put away.
- The command-line note says any mission by name, or a stage 0-15 (`Interior.exe -- --coop-jump=<place>`).

## Checks

- `tests/coop_jumps.gd` (INTERIOR_COOP_JUMPS):
  - `--each`: every place but Dodong (33) straight from the start of a game of its own: stage, spot, squad beside on the
    same floor, everyone at 100, no stale line, and per stage: Dodong home, keys, gate, rifles (host and AI), Jonna
    seated, out the back, story, Rommel's gate shut, floors crossed quietly, Kuya Boy, 501, the horde gone by (and
    standing for the sneak), the blast, the field full, Paolo's line, Heavy-arm's state, Store Road's and the
    backstreets' sleepers ahead (none behind) and their waves; then 170 frames later: still there, the chapter
    caught up and its screen gone, the town / backstreets put away, no stray wave, the horde's crash and the blast not
    heard again, nothing hunting the squad on arrival, the place's own floor reached on arrival.
  - `--go`: teleports ahead (the college woken) and back, `me`, `squad`, `go home`, unknown places, put-away places
    refused after a jump, the Missions tab's buttons (one per jump and place, greyed right, the Yard and Lobby buttons
    work), and `complete` from inside the school to 501 with no rush.
  - `--walk` (every jump in order in one game) and `--direct` (the commands) as before, with the new places.

## Results

- `coop_jumps --each` (33 places, a fresh game each): first run 862/864. The two failures were real and are fixed:
  "sneak" put the squad in the corridor beside the standing horde with flashlights on (one woke): it now starts
  inside 501 at its door, where play starts it, and a jump into the dark stages (12, 13) puts every light out;
  "duct": Kuya Boy was there but noticed the squad landing 2.7 m from him (as coming up the ladder does in play: the
  check was too strict). Rerun of duct, horde, sneak, firedoor: 143/143.
- `coop_jumps --walk` 108/108, `--go` 26/26, `--direct` 24/24.
- coop_escape 38/38, coop_heavyarm 48/48, coop_school 44/44, coop_chapters 26/26, coop_integration 39/39,
  debug_menu_integration (solo) 39/39. All headless, one at a time (the ENet port).
- Found on the way, not from this work: `blood.gd _drop_lands` let a drop land on a body freed while it was in the air
  (a freed object compares equal to null in Godot 4, so the `!= null` guard passed it) and `_spot` raised a type error
  (seen once in coop_heavyarm when a drum went up). Now `is_instance_valid(hit.collider)`; coop_heavyarm 48/48 clean.
- Button names: the teleports are 18 characters at most so three fit a row untrimmed.
- The stages' own hints (tables and guns at the mart, stack and push in the siege, the back door, the stairs at
  PILCST: `session.HINT_STAGES`) leave the queue, and fade out if up, once the run is past their stretch. The first
  EXE capture showed the stairs hint still up at Ma'am Teves, the blast and Heavy-arm after successive jumps; the back
  door's hint could also be queued after the siege. `--go` checks it (27/27); chapters 26/26, direct 24/24 after it.

- Ma'am Teves and the students take spots at least 1.4 m from the player where there are any (the second EXE capture
  had a student 0.95 m in front of the lens on the blast's landing). `--each` for every stage 13+ place: 290/290.

## The built game

- `python -I tools/export_windows.py`: `builds/windows/Interior.exe` 0.55.0 replaced (and `Sleep-0.55.0-windows.zip`),
  then exported again after the hint change.
- `bash work/v55/exe.sh`: `--capture-views=coop_jumps` (work/v55/exe/jumps: the chapter screen while the mart's
  loading is caught up, the brick alley, the Missions tab top / jumps / teleports, the third floor on arrival, Ma'am
  Teves at 501 with nothing rushing in, the blast's landing, Heavy-arm's key, the covered court by teleport) and two
  `--coop-jump=` launches from the command line (teves with 2 AI, ladder with 1: work/v55/exe/cli).

## Screenshots sent

| file | what |
|---|---|
| work/v55/exe/jumps_sheet.jpg | the final EXE's captures above, one sheet |
| work/v55/exe/jumps/jump_4_missions_jumps.png | the Missions tab's jumps at stage 8 (behind the run greyed) |
| work/v55/exe/jumps/jump_5_missions_teleports.png | the Missions tab's teleports (Bring the squad, put-away places greyed) |

The two `--coop-jump=` captures (work/v55/exe/cli) caught the chapter screen still up over the catch-up: the capture
is taken 90 frames after the jump, before the screen's 1.6 s fade. That is the loading as designed, not a fault.

## Open

- Not tried with a second real PC: the settling is host-side and reaches clients through the snapshot's flags (the
  chapter catch-up, the quiet bells and one-shot sounds read them on every peer; the flashlight is put out by RPC).
- A jump heals everyone to 100 and gives each survivor without one a rack rifle once past the siege; if the owner
  wants jumps to keep health or loadout as they are, that is two lines in `_settle`.
- The squad AI warp back to their leader 32 m off (bots.gd), so `go <place> me` is followed by them; "Bring the
  squad" off only decides who is moved by the button itself.

## Part 2 (same day): invulnerability, heal, healthkits

Owner: "Fix the debug Invulnerability to ACTUALLY make the player invulnerable to any damage and all damage, fix the
heal debug to actually heal the player, add a debug function to give healthkits."

**Why none of it worked in co-op**: the debug menu is built (interior.gd line ~213) before the co-op session exists
(line ~238), and its World tab only built the co-op section `if main.coop != null`, so "Team invulnerable", "Team:
full health + ammo", the healthkit buttons and "Hurt me 40" never existed in a game. What was there were the single
player's: Player > "Heal me" healed the single-player body (not the squad's health) and Zombies > "They cannot hurt
me" only stopped the single-player infected. In co-op also, every hard landing hurt the switched-off single-player
body (its grunt, shove and stumble), invulnerable or not.

**Now (`scripts/debug_menu.gd`, Player tab, first section "Health")**, the same buttons in single player and co-op,
decided when pressed:
- **Invulnerable: no damage of any kind** (`god`): single player: the director refuses every hurt (claws, falls,
  grenades) and the body's bleeding is stopped; co-op: the host's session and mission refuse every hurt to every
  player and squad AI (the infected, Heavy-arm's charge, slabs, fists and pack, grenades, fuel drums). Kept on every
  frame while ticked (`_keep_god`: a game hosted after ticking it, a restart). `god on/off` on the command line moves
  the box too. "Hurt me" / "To critical" are refused while it is on.
- **Heal me** / **Heal the squad**: co-op: 100 HP, up again if down, any patch-up on them ended; single player: 100,
  the bleeding stopped, rest's ceiling back to full. `heal` on the command line revives too.
- **Healthkit +1 (me)**, **Healthkits: full (me)**, **Healthkits: full (squad)** (sized "medium", up to 3 each);
  `kits [n] [squad]` on the command line. Single player has no kits (wounds are bound with H): the buttons say so.
- The World tab's co-op section (squad AI, infected, full ammo, next objective) is built always now.
- body.gd: no single-player fall damage inside a co-op game. Removed: Zombies > "They cannot hurt me" (superseded).
- `mission.blocked_hits` / `zombies.blocked_hits` count refused hurts (tests).
- grenade.gd: a smoke or fire card whose material was dropped when the run put the street away (free_unloaded) is
  let go instead of erroring every frame.
- session.gd `host_port` (or env SLEEP_COOP_PORT) lets the co-op tests run while a game is hosting on 25108.

**Test**: `tests/god_heal_debug.gd -- --coop` (20: the switch; 19 infected blows, 3 blasts, a 14 m fall, 14 of
Heavy-arm's blows and a fuel drum all refused with host and AI at 100; heal the squad, heal me from down, +1 kit, full
squad kits, `kits 2`, a given kit patching up) and `-- --solo` (7: 33 hurts refused with bleeding set, then off:
hurt and bleeding; Heal me to 100 with the bleeding stopped).

**Suites after part 2** (beside a running game, SLEEP_COOP_PORT=25131): god_heal_debug coop 20/20, solo 7/7,
debug_menu_integration 39/39, zombies_integration 109/109, coop_kits_modes 35/35, coop_heavyarm 48/48,
coop_integration 39/39, coop_jumps walk 108/108, go 27/27, direct 24/24; no script errors.
**EXE**: re-exported (20:36; the owner's open Interior.exe was closed by the export, AGENTS.md); `bash
work/v55/exe_debug.sh` -> work/v55/exe/debug (debug-3-player.png: the Health section; debug-4-world.png: the co-op
section). Not checked in a live co-op game on the EXE by hand: the switches are the same code the tests press.
