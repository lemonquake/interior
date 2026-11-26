# 0.62 handoff: online play through the Sleep server, the launcher with signed updates, the game page

Owner's request (2026-11-23): stop hosting Beyond Heroes and Aetherion on the VPS, host Sleep there "so we no longer need
any virtual lan like Radmin", give players an Aetherion-style launcher that updates the game, and a game page with the
best screenshots (the infected's modular bodies, the atmosphere, multiplayer).

## The server (VPS 15.235.246.87, Ubuntu 24.04, OVH Singapore)

Beyond Heroes and Aetherion were removed (databases archived on the owner's PC first:
`A:\Python\vps-archive-20261123\vps-archive.tgz`). What runs now:

| Service | What | Ports |
|---|---|---|
| `sleep-relay` | `server/relay/sleep_relay.py`: the co-op relay and the live room list | TCP 25109 (control), UDP 25110-25159 (rooms), UDP 25200-25599 (one per friend), 127.0.0.1:8480 (GET /rooms) |
| `mosquitto` | the online lobby's MQTT broker (players, hosted games, lobby chat); only `sleepgame-hk7q/#` topics | TCP 1883 |
| `caddy` | https://sleep.15-235-246-87.sslip.io: the game page, `/updates` (signed releases), `/downloads`, `/api/rooms` | TCP 80/443 |
| `cgk-linens` | the owner's CGK Linens Discord bot (separate project, `A:\Python\cgk-linens`) | outbound only |

Set up or refresh: copy `server/deploy` and `server/relay` up and run `sudo bash install.sh` (safe to run again).

## Why a relay and not a dedicated server

Co-op runs the whole night (mission, infected, physics) on the host's PC, and about 130 places in `scripts/coop`
assume the host is also survivor 1. A headless server would mean rewriting that and keeping it rewritten for every new
chapter. The relay keeps the game exactly as it plays and only changes how people reach the host:

- `Host game` opens the ENet server as before and `scripts/coop/relay.gd` asks the relay for a room (`hello` -> `room P`).
- The listing in the lobby now carries `relay: true, ip: <server>, port: P, hip: <host's public IP>`.
- A friend's ENet connects to `<server>:P`. The relay gives that friend a port Q and tells the host `open Q`; the host
  sends `SLR1<token>` from its game socket to `<server>:Q` (`ENetConnection.socket_send`), which is what lets the relay's
  packets back in through the host's router. From then on every ENet packet passes through unchanged.
- Friends behind the same router as the host (their STUN address equals `hip`) still connect straight to its LAN address.
- If the relay can't be reached, hosting falls back to the old STUN/UPnP/hole-punching path.
- The lobby tries the server's broker first (`lobby_net.gd` BROKERS), then the public ones.

Traffic: a squad of five is a few tens of KB/s through the server; the VPS allowance is 500 GB a month.

## The launcher and updates

`launcher/windows` is the Aetherion launcher (1.5.0) rebranded: Sleep's fonts and palette, the mart at night behind it,
"PLAYING NOW" from `/api/rooms`, the game in `<drive>\AzAz Games\Sleep`, the launcher itself in
`%LocalAppData%\Sleep` with Start menu and desktop shortcuts and an Apps entry. Every release is chunked
(content-defined, `tools/release/chunker.py`), stored once by SHA-256 and signed with an RSA-3072 key that lives only at
`%USERPROFILE%\.sleep-private\update-signing-key.pem` (back it up: losing it means shipping a new launcher). The
launcher pins the public half (`tools/release/update-public-key.json`), checks every chunk and file, and downloads only
the chunks that changed. A newer launcher in a release replaces the installed one.

Shipping an update:

    python -I tools/export_windows.py                       # builds/windows (bump config/version and the preset's versions first)
    python -I tools/release/publish.py stage --notes tools/release/notes/<version>.md
    python -I tools/release/publish.py upload
    python -I tools/release/publish.py activate             # players get it the next time the launcher opens
    python -I tools/release/build_launcher.py               # only when launcher/ changed (then stage again)
    python -I tools/release/make_launcher_art.py            # launcher art and the page's pictures
    python -I tools/release/publish.py site                 # website/

## The game page

`website/` (static: `index.html`, `site.css`, `site.js`, the game's fonts): co-op, the infected (twelve of the people
they used to be and the dismemberment), Heavy-arm, the night, and downloads with live squad count, version, size and
release notes from `/downloads/index.json`. Android shows "coming soon": the only APK (26 October) predates co-op and the
relay, and a new Android export rewrites texture imports.

## Checks

- `tests/coop_relay.gd` (two processes, see its header): a host and a friend through a relay on this PC, then through the
  real server from behind this PC's router: the room, the join, the mission start, the friend's live state at the host,
  still connected after play, and the lobby on the server's broker. All passed.
- The launcher builds (`dotnet`, .NET Framework 4.8) and renders (`--snap`).
