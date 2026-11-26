# 0.45 handoff: Old Salmonan, horror backstreets, online multiplayer lobby

Build: `builds/windows/Interior.exe` + `Interior.pck`. **Share `builds/windows/Sleep-0.45.0-windows.zip` (1.4 GB)**:
friends unzip it anywhere and run `Interior.exe`. Nothing is committed.

## What changed

**Old Salmonan.** The gate arch reads "OLD SALMONAN" and the curfew tarp reads "BARANGAY 23-C • OLD SALMONAN"
(approach.gd); the comments in street.gd and the review test follow.

**Backstreets horror pass** (new `game/scripts/coop/backstreets_horror.gd`, built from backstreets.gd before its
meshes commit; `tick` runs from `Backstreets.tick` on every peer):
- **Darker.** One wall lamp in three is dead, plus a few more at random. One pole lamp in three is dead. Half the
  arcade tubes are out. The remaining lamps are weaker: wall lamps 9 → 6, poles 11 → 7.5, tubes 6 → 4.2. Lit windows
  are halved. The gaps between the pools are dark enough that the flashlight matters. The grade is not touched.
- **Small light sources:**
  - a buzzing caged bulb over the service gate;
  - three dropped torches still on, each beam along the ground beside a drag or a body;
  - six groups of candles at doors;
  - four phones face up and lit (they die and come back);
  - five televisions flickering behind first-floor windows.
- **Flicker.** Light modes are BUZZ (fluorescent stutter), DYING, FLAME and TV. More of the lamps that are still on
  now fail now and then.
- **Sparks.** About a third of the dead fittings and two torn-down cables short-circuit now and then. Each short
  throws a burst of falling sparks (CPUParticles3D), a blue-white flash on the walls and the arc crackle
  (`nichols/arc_buzz.ogg`). Shorts come in twos and threes, then go quiet.
- **Blood, subtle.** One mark every 3.5–7.5 m of lane:
  - small pools and spatter;
  - drags into doorways and under shutters;
  - smears along the walls at hip height, using the floor decal turned to project into the wall.
  - No writing and no hand prints.
- **Far sounds.** Every 22–48 s a scream, groan, rattle or dog pack sounds 22–40 m away down another lane. This only
  happens while the camera is in the backstreets.

**Online multiplayer**:
- **Lobby relay** (new `game/scripts/coop/lobby_net.gd`). A small MQTT 3.1.1 client over TCP to a public broker
  (HiveMQ first; EMQX and Mosquitto are fallbacks). It needs no server or account. Topics live under
  `sleepgame-hk7q/v1/`:
  - `u/<id>`: retained presence holding the player's name, state, version and their hosted game. The relay clears
    it through the last will when the game closes or drops.
  - `chat`: the public lobby chat.
  - `to/<id>`: messages for one player, used for hole-punch requests.
- **Hosting** (`session.host_public`):
  1. STUN from UDP 25108, which tells the host its public address. The NAT on this PC keeps one external port per
     socket, so punching works.
  2. Open ENet.
  3. Ask the router for 25108 with UPnP, in a thread.
  4. Publish the listing: public ip:port, LAN addresses, player count, AI count and status.
- **Joining** (`session.join_listing`):
  - If the joiner has the same public IP as the host, it uses the host's LAN address.
  - Otherwise the joiner runs STUN from a random local port, then sends the host a punch request through the relay.
    The host fires 10 packets at the joiner from its ENet socket (`ENetConnection.socket_send`). The joiner then
    connects from that same local port.
  - The old Join by address is still there, for LAN or VPN.
- **Screens** (new `game/scripts/coop/lobby_ui.gd`). Full-screen and built in code, with Bahnschrift as a system
  font, a red accent and Primary, Ready and Ghost button styles. interior.gd shows it for the "multiplayer" page and
  hides the old centred window.
  - **Browse:**
    - the open games list, each with host, mission, player pips, status chip and a Join button (disabled when the
      game is started or full, or the version differs; double-click also joins);
    - the online players with what each is doing;
    - the live public lobby chat;
    - the name chip (Rename; names are cleaned, 2–18 characters, saved in `user://lobby.cfg`);
    - the connection pill;
    - Host game and Join by address.
  - **Room:**
    - five squad cards with name, character and outfit, You/Host/AI badges and Ready/Not ready;
    - Add/Fill/Remove AI for the host;
    - the survivor preview and look;
    - the squad chat, which only the squad sees (ENet RPC);
    - Ready up for players, and Start mission for the host, enabled when everyone is ready (shows "Waiting for N").
  - A full squad sends one AI home when a player joins.
- **In-mission chat.** T or Enter opens it (only when there are other humans). Enter sends, Esc cancels, and
  movement stops while typing. The text is small and bottom-left, and fades after 10 s (in line with the minimal-HUD
  rule).
- **Names.** Player names now appear on the name tags over heads and in the results table.
  `config/version="0.45.0"` is new in project.godot; lobby listings compare it.

## Tests
- New `game/tests/coop_lobby_ui.gd` (`-- --role=solo|host|join --tag=X --shots=dir`):
  - **solo:** 9/9.
  - **host + join:** two windows over the real online lobby. The joiner saw the host's game, joined with one click,
    readied, and both chats crossed; the mission started for both. Host 10/10, joiner 9/9.
- `coop_integration`: solo 34/34, network host 38/38, peer 4/4.
- `coop_backstreets_integration`: 9/9, including the walk through every stretch.
- The rest of the full suite was not run again this round.

**Not tested:** the internet path itself. Both test copies ran on this PC, so they joined over the LAN branch. Hole
punching and UPnP need two different networks. Strict NATs (some mobile or CGNAT lines) can still refuse; the error
then suggests trying again or using a VPN with Join by address.

## Things to tell friends
- On first Host, Windows Firewall asks about Interior.exe: **Allow** (private and public), or nobody can join.
- The lobby chat is public. Anyone running the game sees it, and the host's public address is in its listing.
- Everyone needs the same build (0.45.0). Games from other versions show as "UPDATE".

## Screenshots
| | |
|---|---|
| `work/v45/exe_lobby/sheet.jpg` | EXE: browser, squad room, squad chat in the mission |
| `work/v45/duo/sheet.jpg` | two-player run: listed game, joiner room (Ready ✓), host room, chat |
| `work/v45/exe_route/sheet.jpg` | EXE: Old Salmonan gate, darker lanes, flashlight, dropped torch |
| `work/v45/exe_route2/route_lane.png` | EXE: the buzzing bulb at the service gate |
| `work/v44/v45_dark2/sheet.jpg`, `work/v44/v45_lit/sheet.jpg` | editor: all six stretches dark, and with the torch on |
