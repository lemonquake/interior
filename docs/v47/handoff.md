# 0.47 handoff: the stockroom doorway that killed the squad

Build: `builds/windows/Interior.exe` + `Interior.pck` (0.47.0). Share `builds/windows/Sleep-0.47.0-windows.zip`.
Nothing is committed.

## The bug

Owner: "at the entrance at the right side inside the convenience this place kills all players". That is the
stockroom doorway under the green EXIT sign (street-local x -3.9..-2.05, z 69.5), which leads to the steel back door.

**Cause** (`mission.gd` tick, the last stand's back-door wave):
- The infected sent round the back (`z.back`) walk to the shut back door, and their target becomes the door spot.
- Only those within 1.15 m hammered the door.
- The ones crowding just behind (1.15–1.32 m) were inside attack reach of the door spot, so `chase()` reported an
  attack. That attack was charged to `nearest(z)`, the player nearest the back door, wherever they stood. That
  player is whoever holds the stockroom doorway.
- 4–6 infected doing that took about 30 HP a second, through the wall, from infected outside that nobody could see
  or shoot. The nearest player went down, then the next nearest, and so on, until "The whole team is down".
- They never broke the door either, because the crowd "attacked" instead of hammering. With the debug
  invulnerability on, the last stand therefore never ended (5–6 infected stuck outside forever).

Measured before the fix (`tests/coop_store_survival.gd`, host standing in the stockroom doorway): the squad was dead
at 30 s, and every one of the AI's hits came from infected at x -5.6..-4.7, z 74.5..75.5 (outside the back wall).

**Fix:**
- Everyone within 1.6 m of the shut back door hammers it. The front rank does full damage and those behind do 30%.
- An infected whose target is the door can never hurt a player.
- Any infected hit now also needs the player within 1.75 m of the infected, so no other target swap can send damage
  across the map.

After the fix:
- With the host in the stockroom doorway, no hits came through the wall.
- The back door gives way (about 35 s of hammering).
- The last stand completes again with invulnerability on.
- The only hits left came from infected that walked in through the broken door and stood next to the host, who does
  not shoot in the test.

## Tests

- `tests/coop_store_survival.gd`:
  - new checks: "no hits through the wall from outside the back door"; "the back door gives way".
  - `STORE_HARMLESS=0` runs it for real.
  - `STORE_STAND="x,z"` (street-local) places the host.
  - `mission.log_hits` / `hit_log` record every hit the infected land.
- `tests/coop_office_entry.gd` (new): walks through Jonna's office door and the stockroom doorway at the office stage.
  It logs everyone's health; nothing there hurts anyone.

## Not verified

- No real two-PC game. The damage is decided on the host only, so clients get the same fix.

## Build check (second session, after the first was cut off before the export)

- Re-ran: `coop_backstreets_integration` 9/9, `coop_store_survival` 4/4, `coop_office_entry` 4/4
  (logs in `work/v47/`). `coop_integration` 34/34 and `coop_squad_integration` 27/27 were run before the cut-off.
- Exported with `python -I tools/export_windows.py` (`work/v47/export.log`): EXE 109 MB, PCK 1308 MB, shaders
  baked, EXE start-up report shows the menu at 16.4 s with no errors, zip 1417 MB.
- EXE captures: `Interior.exe -- --capture-review --capture-views=coop_route --capture-path=work/v47/exe`
  (12 shots, `work/v47/exe/`).

## Screenshots sent

| File | Shows |
|---|---|
| work/v47/exe/route_office.png | EXE: Jonna's office, door open, Jonna sat |
| work/v47/exe/route_gate.png | EXE: the Old Salmonan gate |
