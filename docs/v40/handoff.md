# 0.40 — co-op: real hits, knockback, ragdolls; host debug menu; squad AI with voices; sights that tell the truth

Owner's request (2026-11-18): fix co-op infected not being pushed by gunfire and not ragdolling on death; let the host
open the Q W E R T Y debug menu in co-op; a big co-op polish pass toward 200 FPS; host-added AI squadmates that are
really smart (retreat, protect the player); ElevenLabs voice lines (set the MCP up if missing), also playable by the
player with `~`; make the weapon view match where the rounds land, especially on the iron sights; build the game.

Mid-run correction from the owner: **no fixed poses, never trade ragdoll physics for frame rate** (100+ FPS is
fine). A "set down" that froze settled corpses was removed within minutes; co-op bodies are now the full 16-body
solo ragdoll and stay live for as long as they are kept (16, the solo limit).

## What changed

### Co-op infected (scripts/coop/figure.gd, mission.gd, session.gd)
- Cause of the bug: co-op infected were lightweight `Figure` bodies with no hit boxes. Hits were sphere maths on
  the host, death played `death_fwd`, nothing pushed anything.
- Now every co-op infected carries the solo ragdoll (`InteriorZombie.build_ragdoll`, extracted from zombie.gd's
  `_build_bodies`; same 16 bodies, joints and masses). Each peer's own gun rounds land on those bodies (gun.gd
  `_land` → `Figure.shot`): blood and a flinch at once on that peer, the hit goes to the host (`report_hit` /
  `hit_report`, validated), which owns health (90, solo bone multipliers: head ×4) and the push (`knock_back`).
- Knockback: every hit shoves the body back; rounds in the same tick add up: a reel clip, a heavy stagger past 140,
  and buckshot close up (420+) knocks it off its feet and it gets up again. Other peers see the hit through
  `struck` (blood + flinch); state goes out at 20 Hz and figures follow with dead reckoning.
- Death: `fallen` (now with the push and the bone) makes every peer hand the figure to its ragdoll
  (`go_limp`): clips handed back to the engine first (the 0.38 lesson), pushed the way the shots went, thud and
  blood pool. Bodies stay live ragdolls (rounds and pellets still move them).

### Host debug menu
- The host keeps Q W E R T Y in co-op (clients do not). World tab → "Co-op (host)": add / fill / remove AI,
  infected ahead / round me, kill all, team full health + ammo, next objective (teleports the host), infected
  cannot hurt the team. The info line shows objective, squad and infected counts.

### Squad AI (scripts/coop/bots.gd)
- Lobby: "Add AI squadmate", "Fill with AI", "Remove AI" (host). Also during play from the debug menu.
- Team members with negative ids, simulated on the host, drawn on every peer as survivors with "• AI" tags,
  muzzle flash and gunshot per shot.
- Thinks every 1/8 s: leader = nearest standing player; threats by line of sight ranked by distance to leader,
  Dodong and itself; gives ground (backs off along the open direction that gains the most room while staying near
  the team, shooting); covers a leader under attack from their side, square to the threat; never fires with a
  friend in the line; real magazines and reloads (tactical when quiet); revives the downed with healthkits; heals
  when safe; picks up rifles, ammo and kits; formation round the leader with the rear slot watching behind;
  catches up when lost or stuck. Takes orders from the voice menu: hold, follow / let's go, backup, fall back,
  check this out.
- Calls out: spotted / horde, behind you, reloading, low / out of ammo, guns / ammo / medkit found, covering,
  fall back, backup, down, reviving, thanks, kill, clear, hit, healing, copy.

### Voices (scripts/coop/voices.gd, assets/audio/voices/, tools/squad_voices.py)
- 24 line types (52 takes) × 5 survivors from `assets/audio/voices/lines.json`. Heard positionally from the
  speaker, written in a radio feed lower left. `~` opens the voice menu (1-9, 0; Shift+1..6 for the rest).
- **ElevenLabs:** no key or MCP was on this machine. The official ElevenLabs connector was offered in the app
  (Connect card). Until a key exists the clips are Windows-voice placeholders (`.wav`). To replace them with
  ElevenLabs voices: `setx ELEVENLABS_API_KEY <key>`, open a new terminal, then
  `python -I tools/squad_voices.py --engine elevenlabs` and `python -I tools/export_windows.py`. The game prefers
  `.mp3` over the placeholder `.wav` automatically.

### Sights (scripts/gun.gd)
- The weapon is squared to the lens' axis in every stance (no more inward-toed hip pose). On the sights the rear
  sight sits on the axis (breathing turns the weapon instead of sliding it across the lens; the pistol's notch is
  pulled back onto the axis from where the arms' clip actually draws it), and nothing pulls it down off the axis.
- Each round goes along the sight line **as drawn** (`drawn_aim`: the view model's line through the view lens
  mapped into the world lens), so kick, sway and free aim are where the rounds go. `-- --legacy-aim` restores
  the 0.39 rule for A/B.
- Measured (tests/aim_alignment.gd): on the sights notch and post within 0.5% of the screen centre, round on the
  post within 0.2-0.4% (pistol, rifle); at the hip rounds land where the barrel points (≤0.04%).

### Performance (no physics cuts)
- Far or out-of-view co-op figures are posed every 2nd-4th frame (still 50-100 times a second at 200 FPS);
  the street no longer re-moves its static bodies every frame; AI straight-line checks cached 0.2 s; state only
  packed when someone is there to receive it. `-- --coop-timing` prints the host's tick costs.
- Tried and removed: turning off far shadows (4× draw calls), freezing settled corpses (owner: never).
- `tests/coop_perf.gd`, 1920×1080 High, this PC: squad of 5 alone 390 FPS; 20 infected coming 210 (1% low 97);
  squad shooting them down with 16 live ragdolls 160 (1% low 81); afterwards 175.

### HUD (owner, mid-run: "the UI in this game is supposed to be very very minimal like almost nothing")
- Co-op HUD is the objective line only (16 px), plus "Down • ..." while down. The name / HP / healthkits line,
  Dodong's HP, infected count and the key list are gone. Radio feed and voice menu text 13-14 px.

## Tests
- `tests/coop_squad_integration.gd` (27): hit boxes, pistol hurts and shoves, blood, driven back, buckshot kills,
  ragdoll in the DRAWN pose, falls away from the gun, still a live ragdoll seconds later, AI shoot/kill/talk,
  voice clips load, hold order, `~` menu, remove AI.
- `tests/coop_integration.gd` 24/24 alone, host 28/28 + client 4/4 over loopback ENet.
- `tests/aim_alignment.gd` (11). `tests/coop_views.gd` renders the stills below.
- Regression: gun 42/42, zombies 109/109, debug menu 39/39, pierce 10/10, glass 20/20, touch 39/39, fair world
  53/53. Adapted for "rounds follow the drawn weapon": fair_world's 60 m shots and the zombies sniper shin shot are
  now taken on the sights (a winded body's weapon wanders at the hip; a snapped turn swings it), and `_level`
  lets the weapon settle. senses_integration's "stays out ... darker" light check is flaky with the old aim too
  (failed 2 of 3 with `--legacy-aim`).
- Built game: `Interior.exe -- --capture-review --capture-views=coop --capture-path=<dir>` (new) — work/v40/exe/:
  squad 5, ragdoll live after the buckshot kill, voice clips load, host debug menu on.

## Screenshots sent (work/v40/screens/)
coop_squad_fighting, coop_blast_ragdoll_falling, coop_ragdoll_down, coop_voice_menu, coop_rifle_on_sights.

## Open
- ElevenLabs voices need the owner's key (or the connector) — placeholders until then.
- Co-op still has no friendly fire and no gore (dismemberment) on co-op infected; blood and ragdolls only.
- The AI does not open doors itself; it catches up past them when lost.
