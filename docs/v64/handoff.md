# 0.64 handoff: phones (performance, gore, co-op, cross-play)

Owner's ask (2026-11-25): intensive mobile performance work so low-end phones enjoy the game without losing gore or
physics; compile the APK and update the site. During the run: in phone multiplayer unload the Nichols property and
the rice fields and close the holes to them; Easy by default on phones; phones and PCs must play together.

## What was wrong on phones (0.63 and the last APK, 0.32)

- The APK never got past 2% on the loading screen: the 0.30 threaded preload deadlocks on the phone renderer
  (Compatibility finishes textures on the main thread). Seen on the 2 GB emulator, all threads asleep.
- The preload also pinned all ~3,100 files (1.26 GB of sources) in memory for the whole run.
- Gore was switched off on phones: no splats, spots, pools, wounds, drips, torn-off parts, gibs, craters (blood.gd,
  zombie.gd, figure.gd returned early on `mobile`), because Decal nodes cannot be drawn by Compatibility.
- Co-op did not exist on phones (`if not mobile: coop = ...`), and the APK had no INTERNET permission.
- The PC frame-rate layer (performance.gd: zones, light fades, trees, adaptive scale) never ran on phones.
- The picture was pillarboxed on wide phones (stretch aspect "keep").
- Squad-game textures (characters, infected, school, Nichols props, mart stock atlas) had no phone budget and most
  were imported lossless: ~366 MB of uncompressed GPU memory if all drawn.

## What 0.64 does

| Area | Change | Files |
|---|---|---|
| Loading | No bulk preload on Android; main.tscn not pinned on Android, so what is freed leaves memory | boot.gd |
| Gore | Flat blood marks: splats/spots/pools as quads batched per 12 m patch in one MultiMesh each (atlas of all blood pictures, normal map, wet roughness); marks on moving props get their own mesh; wounds are flattened blobs in the skin. Drop arcs on a phone: at most 40 a frame | blood_marks.gd (new), blood.gd, tools/blood_atlas.py, assets/zombies/blood/mobile_atlas_*.png |
| Gore | Gates removed: wounds, drops, bleeding, pools, sever bursts, chunks/craters, shatter gibs, limb gibs | blood.gd, zombie.gd, coop/figure.gd |
| Co-op | Squad game on phones, Easy default (setup and host) | interior.gd, coop/session.gd |
| Controls | Rewritten as a phone-shooter layout after the owner rejected the 0.64 draft grid of text buttons ("those arent mobile controls for FPS games"): floating stick (full forward = sprint, light push = quiet walk), drag right to look, round see-through buttons: big FIRE bottom-right (hold = trigger held, the thumb on it also aims), left FIRE, ADS toggle, RELOAD, JUMP, CROUCH, SHOVE, GRENADE (hold); contextual USE / INSPECT / BIND; weapon row top centre (GUN-HOLSTER, SWAP, MEDKIT hold = F, DROP hold = G); PAUSE, LIGHT, CHAT top right. Shove = co-op T, Pause = co-op pause in the squad game | mobile_controls.gd (rewritten), interior.gd, gun.gd (`touch_aim`, `cycle_weapon`), tests/touch_integration.gd |
| Co-op | Prompts/hints name the touch buttons on phones (`session.phone()`), squad-talk hint skipped on phones | coop/session.gd |
| Seals | Squad game on every platform: sheets nailed across the crouch hole (north wall, to the rice fields) and the secret crawl (south wall, to the Nichols property) | map_seals.gd (`seal_for_squad`, `SQUAD_RUNS`), coop/session.gd |
| Unload | Phone squad game frees `Fields` and `Balcony/Neighbourhood/Nichols property` (`session.drop_far_places`) | coop/session.gd; freed-node guards in atmosphere_particles.gd, performance.gd, hut_house.gd |
| Frame rate | performance.gd runs on phones (zones, trees, light fades; mobile_performance.gd keeps its small-thing ranges); render scale follows frame time on phones (`_phone_scale`, 72%..100% of the level's pixel ceiling); physics catch-up capped at 3 steps | performance.gd, mobile_performance.gd (`ceiling`), interior.gd |
| Textures | Phone budget v3: characters, school, nichols, zombies, grenade, fields at 1024 and coop at 2048, and lossless imports there cut to ETC2 | addons/mobile_texture_budget/texture_export.gd |
| APK | Release template (faster scripts) signed with the same debug key as before; INTERNET, network and Wi-Fi permissions; `assets/built/*` (PC-only mesh cache) left out; expand aspect on phones | export_presets.cfg, project.godot |
| Text | Loading tips by touch button names on phones; start-up times always logged on Android | loading_screen.gd, load_clock.gd |

Version 0.64.0 for both (lobby joins need the exact same version). Android version code 64.

## Checks

- `tests/phone_coop.gd` (new, windowed, `--rendering-method gl_compatibility ... -- --mobile-test`): 26/26.
- Cross-play, `tests/coop_integration.gd`: PC host + phone-mode client 44/44 + 4/4; phone-mode host + PC client
  44/44 + 4/4, clean logs.
- Gore capture on the phone renderer (`--capture-views=gore` with gl_compatibility): splats, pools, wounds, arm/leg
  off, head burst all drawn (work/v64/gore_compat/sheet.jpg).
- Emulator (medium_phone AVD, 2 GB, Android 16, data partition raised to 14 GB): 0.63-style build stuck at 2%; 0.64
  reaches the menu. The ARM build crashed after ~70 s inside the emulator's ARM translator (SIGILL in translated
  code, not Godot), so emulator runs use a test-only x86_64 export (work/, never published).

## Measurements (this PC, phone mode: Compatibility renderer, `--mobile-test`, 1600x720)

`tests/coop_perf.gd -- --quality=0` (the phone's default level; the script defaults to High):

| View | fps median | 1% low | draw calls | render CPU / GPU ms |
|---|---:|---:|---:|---:|
| Store run, squad of 5 | 94.0 | 58.1 | 497 | 4.6 / 2.5 |
| 20 infected coming | 65.3 | 40.2 | 553 | 5.5 / 3.4 |
| Squad shooting them down | 59.6 | 25.5 | 712 | 5.9 / 3.9 |
| After: bodies and blood | 64.6 | 33.6 | 742 | 6.0 / 3.8 |

On High the same views were 3,500-4,400 draw calls before mobile_performance.gd budgeted late geometry (4,200-5,400
before that). Script time in a fight ~6 ms here (`tools/prof_frame.py`), of which the squad game's own
`session.gd:_physics_process` (AI, director) is 2-3.7 ms: on a phone CPU (3-4x slower) that and physics are the
limit, so a crowd fight on a low-end phone is expected around 20-30 fps; the governor holds resolution down only
for GPU load. Not changed: AI tick rate (it would change how the infected play).

## Screenshots sent

| When | File |
|---|---|
| Phone-renderer gore capture | work/v64/gore_compat/sheet.jpg |
| Phone-shooter controls in the squad game (20:9) | work/v64/hud/coop_jump_storeroad.png |

## Open / not verified

- No physical phone was available: no real-device FPS, thermal or memory numbers. On the 2 GB emulator the game's
  heap is ~0.9 GB and the system swaps hard (menu after ~2.5 min); part of that heap is likely the emulator's GL
  layer keeping copies of GPU buffers.
- First-use shader compile hitches on a phone's first run are not pre-warmed (Godot caches them after the first run).
- Debug teleports to the Nichols property in a phone's squad game lead nowhere (the place is gone there).
- The squad-talk menu (~) has no touch button.

## Published (2026-11-25)

- PC 0.64.0 staged, uploaded (14 changed chunks, 0.02 GB) and activated: every launcher offers it.
- APK 0.64.0 (816,027,466 bytes, sha256 42aecfa806e1a000...) at /downloads/Interior.apk; downloads/index.json lists it.
- Website republished: the Android buttons are live; added one line to the Android card ("Phones and PCs play in the
  same squads when both are on the same version."). Release notes: tools/release/notes/0.64.0.md.
