# Interior 0.10: the hut, the key, the Glock and the run home (handoff)

Branch: `main`, uncommitted (on top of the uncommitted 0.9 stranger work). Written 2026-10-05. The previous handoff is
`docs/v9/handoff.md`.

## Owner request (2026-10-05, summary)

Instead of running straight down the dirt road, the hooded man takes a sharp turn to the bahay kubo and goes inside
(disappearing as soon as he is inside, without the player noticing). The kubo becomes an actual house with a wooden
interior and a lit candle on a drawer. A key sparkles on top of the drawer; taking it shows a notification; the key
unlocks the drawer, which opens (animated) on a Glock. The player takes the gun and inspects it on screen (drag to
rotate, OK to take it). Then he is called outside by the hooded man in a dialogue box: "I know your father. I knew Alex
when we were kids.", "Please.. we don't have much time! Follow me and I'll give you what's left." The man runs to the
scarecrow, reaches for something below it and gives it to the player ("received 60 glock ammo"), then says "Now... run."
as sirens sound all over, the player must get back home, and the street lights turn off so only the moon lights the road.
Mid-run: "give me screenshots as you go, then build EXE and APK", and "for the glock can you download an actual glock
3d model with animations".

## What was built

| Part | Where | Notes |
|---|---|---|
| Hut house | `game/scripts/hut_house.gd` (`InteriorHutHouse`), attached at runtime under the baked Fields by `interior.gd` (`--no-hut` skips it) | The fields bake is unchanged. The kubo turns 90 deg so its doorway (local +X) and its lantern (moved from mid-air to a hook under the eave beside the door) face the road. An earthen causeway (grass top, mud banks) runs straight from the road to the door; the road's invisible edge wall is cut for it; low invisible walls line the path and the 13 m yard. Two wooden steps with a ramp collider up to the floor. Inside (measured from the model: floor 0.42 m, inner walls x -1.734 / 1.695, z -1.64 / 1.691, doorway 0.64 m on +X): oak plank floor, dark plank wall lining around the door and window, corner posts, wall plates, ceiling joists, a woven sleeping mat with pillow and blanket, a low walnut table with clay cup and tin plate, a stool, a shelf of jars, a big water jar, two sacks, a bamboo clothes pole with a shirt. Colliders for floor, walls (doorway open), dresser, table, stool, jar, sacks. |
| Dresser, candle, key | same | Walnut dresser against the back wall facing the door; two fixed lower drawers and a real top drawer (tray with a brass keyhole). A candle on a brass dish with a flickering warm omni light (shadows on desktop). A brass key (ring, shaft, bit) with four twinkling star sparkles (`scripts/sparkle.gdshader`, additive billboards). |
| Using things | `game/scripts/hut_usable.gd` (`InteriorHutUsable`, group "usables"); `player.gd` (`update_target` accepts "usables") | Key: "E • Take the key". Drawer: "Locked drawer" ("It's locked. There must be a key somewhere.") until the key is held, then "Unlock the drawer": lock click, then the drawer slides out 0.3 m over 1.1 s with a wooden drawer sound. Open drawer / gun: "Pick up the Glock" (aiming anywhere at the open drawer reaches the gun). |
| Glock 17 | `game/assets/models/story/glock17.glb`, made by `tools/blender/process_glock.py` | "[ FREE ] Rigged Semi-Auto Pistol G17" by nixo_design (CC BY 4.0, Objaverse mirror). Its parts (frame, grip, slide, trigger, trigger safety, slide lock, magazine, a round) stay separate objects with the source's 16-frame firing animation ("fire": trigger pull, slide cycles, the round is thrown out). The 100k-polygon shells are decimated (525k -> 128k polygons, custom normals rebuilt) and the flat grey materials are repainted as a black polymer frame, dark steel slide, brass case. 186 mm long. First choice MarkkuK's static G17 was swapped for this animated one at the owner's request. |
| Inspect screen | `game/scripts/story_ui.gd` (`InteriorStoryUI`) | Dimmed overlay with a SubViewport (own world, three lights): drag (mouse or touch) to rotate with a little spin inertia; "Rack the slide" plays the model's animation at 0.3x; "OK" takes the gun, "Put back" / Esc leaves it in the drawer. The game keeps running (not paused); player input is off while it is open. |
| Notifications, dialogue, inventory | same, and `story.gd` | Toasts at the top centre ("You now have the key.", "You unlocked the drawer.", "You took the Glock 17.", "Received 60 Glock ammo", "You made it home."). Dialogue box with the speaker "Hooded man", typed out; E / click / tap continues, or it moves on by itself after 7 s. Inventory line under the notes count ("Key • Glock 17 • 60 rounds"). |
| Story | `game/scripts/story.gd` (`InteriorStory`) | Phases EXPLORE, HAVE_KEY, DRAWER_OPEN, INSPECTING, CALLED, FOLLOWING, RUN_HOME, HOME. After "Now... run.": objective "Get back home.", four looping civil-defence sirens far out (over the town, west and east over the paddies, far up the road), fading in one after another; the three lit street lamps stutter and die one by one (furthest first), then the lamp lenses go dark; only the moon is left. Home = inside the courtyard gate, the stair, the balcony or the house (x < 12.4, -4 < z < 9): "You made it home.", the sirens fall to about half. |
| Stranger | `game/scripts/stranger.gd` | New states HIDDEN, CALLING, AWAITING, LEADING, DIGGING, BRINGING, GIVING, LEAVING. FLEEING now runs the road to just short of the footpath, turns sharply onto it, up the steps and through the doorway, then hides (if the player is 120 m+ away and can't see him, he is put inside directly). Taking the gun: he stands in the yard facing the door (talk clip) while the two lines play; once the player is out of the hut he runs back down the path and the road to the scarecrow, stopping to wait (facing the player) whenever they are more than 20 m behind; the last metres he wades through the paddy (knee deep, 2 m/s, no footsteps); clip pickup under the scarecrow; he wades back to the player, hands over the box, and after "Now... run." runs away up the road and is removed out of sight. |
| Sounds | `tools/assets/fetch_hut_sfx.py` -> `game/assets/audio/sfx/` | siren_wail (Commons, public domain, looped), drawer_open (Gravity Sound, CC BY 4.0), lock_turn / key_pickup / gun_pickup / ammo_pickup synthesised. Credits in `game/licenses/NIGHT_SOUNDS.md`; the Glock in `game/licenses/THIRD_PARTY_MODELS.md`. |
| Fix | `game/scripts/balcony.gd` | `_mask_room_lights` stripped the outdoor layer from every light outside the balcony, so the fields' hut lantern (since 0.7) and the new candle lit nothing. Outdoor-only lights (cull mask exactly the outdoor layer) are now left alone, so the hut lantern glows on the yard again. |

## Tests

- New `tests/hut_story_integration.gd` (headless, `--fixed-fps 60`): 48/48. The hut faces the road; lantern and candle
  light the outdoor layer; the real player walks from the road along the footpath, up the steps and into the hut, is
  stopped by the back and side walls, walks back out, and the yard edge keeps them out of the paddy; the stranger turns
  onto the footpath and hides inside; locked drawer, key via crosshair + Hold, unlock, drawer slides 0.30 m; gun via the
  crosshair; inspect (Put back keeps it, OK takes it); call-out lines 1 and 2 advanced with Hold; he waits while the
  player is inside, leads once they are out, stops when they drop 30 m back, digs within 0.94 m of the scarecrow,
  brings the box, 60 rounds, "Now... run.", 4 sirens playing, objective, 0 lamps lit, he leaves, home.
- `stranger_integration` updated (he now ends HIDDEN inside the hut instead of freed far down the road): 25/25.
- Regression: `fields_integration` 25/25, `street_integration` 27/27, `balcony_integration` 63/63, `room_integration`
  89/89, `touch_integration` 29/29 (`-- --mobile-test`).
- Review renders: `godot --path game --script res://tests/hut_views.gd -- --out=<dir>` (windowed) plays the whole
  sequence and saves stills.

## Screenshots sent to the owner

| File | What it shows |
|---|---|
| `work/v10/glock/decimate_compare2.jpg` | The animated G17: raw source, game-ready at rest, slide back mid-animation |
| `work/v10/screens/sheet_b.jpg` | First in-game pass: hut from the path, doorway, candle-lit interior, the sparkling key |
| `work/v10/screens/sheet_c.jpg` | Notifications, the inspect screen (before the black repaint), the call-out dialogue, following |
| `work/v10/screens/sheet_d.jpg` | Scarecrow, the ammo, "Now... run.", "Get back home.", street B before/after the lamps die |

| `work/v10/screens/03-hut-sequence-polished.jpg` | After polish: the turn off the road, the hut, the room, the key, the Glock in the open drawer, the black Glock on screen, the call-out, the ammo, the moonlit road |
| `work/v10/screens/04-exe-hut-smoke.jpg` | From the exported 0.10.0 EXE (`--capture-views=hut`): footpath, room, key, open drawer, inspect |
| `work/v10/screens/05-android-look-hut.jpg` | The same views under the Compatibility renderer in mobile mode (the Android look) |

## Builds (2026-10-05)

| File | Size | SHA-256 |
|---|---|---|
| `builds/windows/Interior.exe` (0.10.0, release, embedded PCK) | 637 MB | `356ecd2bf161a17abf10de4735f9d3220c19f5b9b57030aabf1f6b2d1d3e0d33` |
| `builds/android/Interior.apk` (0.10.0, code 10, debug-signed) | 585 MB | `443a98ffe5ebf78f07e5d988bb06d8af9763c6f9d43e0ea867de801c62de7ed3` |

`export_presets.cfg` is 0.10.0 (Android code 10; `aapt2 dump badging` confirms versionCode 10 / versionName 0.10.0).
The EXE's own `-- --capture-review --capture-views=hut` (new in `interior.gd`) rendered all five hut views, and
`--capture-views=balcony` all six balcony views. The exported EXE ignores `--script`, so this built-in capture is the
way to check a build. The APK has not been installed on a phone.

## Known gaps

- The hooded man keeps the 0.9 outfit: a black hoodie with the hood down (his face shows at close range when he hands
  over the ammo). Putting the hood up means a new hood shell in `tools/blender/human/build_human.py`.
- He has no "hand over" clip and the ammo box is not modelled. **Bug found after shipping:** `stranger.gd` asks for
  clips `pickup` / `talk`, but `stranger.glb` names them `interact_pickup` / `interact_talk`. So he does *not* reach
  under the scarecrow (he stands still for the dig timer) and calls in `stand_stare`. Fix is item 1 of `docs/v11/brief.md`.
- The gun is not equipped or usable yet (inventory only); the ejected round in "Rack the slide" flies out of view and the
  animation stays at its last frame until the next rack.
- The scarecrow is where 0.7 put it, about 170 m further down the road from the hut, so following him is a long run.
- Sirens are positional sounds on the Night bus; the room's walls don't muffle them.
- After a Restart everything replays from the gate; there is no save.

**All four gaps above (hood, ammo box and hand-over, scarecrow distance, usable gun) and the clip-name bug are specified
for the next run in `docs/v11/brief.md`.**

## How to resume

1. Hut layout constants are at the top of `hut_house.gd` (floor, walls, doorway, window, yard); the stranger's way in
   is `route_in`, built in `_footpath()`.
2. Story text and timings: constants at the top of `story.gd` (`CALL_LINES`, `RUN_LINE`, `AMMO_GIVEN`, `SIREN_SPOTS`).
3. Re-make the Glock: `blender -b --factory-startup -P tools/blender/process_glock.py [-- render]` (needs
   `.local/downloads/objaverse/glock_g17_rigged.glb` from `tools/assets/fetch_fields.py`), then `godot --headless --path game --import`.
4. Builds: `.local\tools\Godot_v4.7.2-stable_win64_console.exe --headless --path game --export-release "Windows Desktop" <abs>\builds\windows\Interior.exe`
   and `--export-debug "Android" <abs>\builds\android\Interior.apk`.
