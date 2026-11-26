# 0.58 handoff: double health, red and downed teammate markers, grenade markers, shining pickups

Owner's request (2026-11-23):
- "make the players' HP 2x higher than previous"
- "Teammates can now also see critical HP players as their indicators would be Red"
- "there are special indicators for "Downed" players"
- "Grenades thrown will also be highlighted and with indicator with distance so players are aware"
- "Items and other pickable weapons, ammos, healthkits, etc will be with white highlights like shining"

## Health (scripts/coop/mission.gd `MAX_HP`, `CRITICAL_HP`)

- A survivor's full health is `Mission.MAX_HP = 200` (was a hard-coded 100 in a dozen places: start, heal caps,
  revive-on-stage, debug heal, patch-up offers). Damage is unchanged, so everyone takes twice as many hits.
- Healthkits heal twice as much (arsenal.gd `KITS`: small 40-60, medium 80-120, large 150-200; fallback
  `HEAL_MIN/MAX` 80-140) so a kit is the same share of the bar as before. A revive gives what the kit gives.
- `Mission.CRITICAL_HP = 60` (30 %, the old limp line of 30/100): at or under it you limp, can't run, the figure
  walks hurt, and your tag turns red for the others. Squad AI lines scaled the same way (self-heal at 45 %,
  retreat / "backup" at 35 %, "hit" call at 55 %).
- Frag caps (85 own / 45 teammate) are unchanged: one of your own frags no longer downs you from full.

## Teammate tags (scripts/coop/session.gd `update_avatars`)

- Normal: the 0.53 tag as before (name, HP, distance, seen at any distance).
- In the red (hp <= CRITICAL_HP): the tag is red with a dark red outline and beats like a heart (two thumps, a rest).
- Down: the tag is blanked and the downed marker takes over (below).

## Screen markers (scripts/world_markers.gd, new)

A CanvasLayer (layer 4) under `main` (`WorldMarkers`, made on first use by `Markers.of(main)`). Callers `mark()`
an entry every frame; one not marked again is dropped. Shown through walls; off the view (or behind you) a marker
sits on an inner ellipse (`PIN` = 30 % x 37 % of the screen from centre, clear of the chat and ammo corners) with a
small pointer toward it. Faces: SleepType street (DOWN), text (names), mono (distances).
- **grenade** (fed by grenade.gd `_mark_live`, every peer, every live frag within 30 m): a drawn frag inside a ring
  that is its fuse burning down; distance under it. Sodium amber, warming to red as the fuse runs out; inside the
  blast radius (8 m, `PLAYER_RADIUS`) it is red, bigger, and pulses faster.
- **down** (fed by session.gd): a figure lying on its side inside a ring that beats red, "DOWN" above, "name · N m"
  below.
- The grenade itself is lit in flight and on the ground: the shine overlay in a warm, quick variant
  (`_hot_material`).

## Shine on pickups (scripts/pickup_shine.gd + pickup_shine.gdshader + pickup_twinkle.gdshader, new)

- `Shine.apply(node)`: every MeshInstance3D under the item gets one shared overlay: a white rim, a faint breathing
  fill and a glint sweeping diagonally across it every 2.4 s (offset per item by position). A twinkle quad
  (camera-facing four-point glint) flares on it every 2.2 s.
- Applied to: co-op drops (healthkits, ammunition: mission.gd `render`), dropped weapons (`_lay_weapon`), grenade
  pouches (`_grenades_lying`), the stage-2 gate keys (street.gd), Heavy-arm's rear-gate key (heavyarm.gd).
- Not applied to the single-player story's pickups (gun, ammo, flashlight, hut key): ask the owner.

## On-screen text added

- "DOWN" (downed marker), "<name>  ·  <N> m" (downed marker), "<N> m" (grenade marker). Nothing else.

## Tests

- New `tests/coop_markers_review.gd` (renders; `-- --render-size=1600x900 [--out=<dir>]`, frames in
  work/v58/markers/): 200 HP start, drops shine, red tag, downed tag blank + one downed marker, grenade marked and
  gone after the blast. 10/10.
- Updated for 200 HP: coop_kits_modes (35/35), coop_integration (39/39), coop_squad_integration (27/27),
  coop_chapters (pass), and `hp = 100` -> 200 in coop_heavyarm, coop_down_views, coop_street_review, coop_jumps,
  coop_office_entry (those not rerun).

## Screenshots sent

| file | shows |
|---|---|
| work/v58/markers/02_grenade_in_flight.png | red tag (45 HP), DOWN marker, grenade with fuse ring and distance, drops glinting |
| work/v58/markers/04_behind_pinned.png | turned away: downed and grenade markers pinned on the ellipse |
| work/v58/markers/05_shine_close.png | kit, ammo, rifle with the shine and twinkles |

## Open

- Real two-PC play not tested (markers are local per peer from synced state; nothing new is sent on the wire).
- Shine strength was tuned on Store Road at night; check it against brightly lit interiors (school corridors).
