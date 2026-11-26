# 0.54 handoff — Heavy-arm's tells from his night round, the game's own type, menus and HUD

Owner's request (2026-11-22): "Heavy-arms' attack indicators are too damn common and bland!! No taste, yuck!!! Create
very unique attack indicators that is SPECIAL and CAN ONLY BE FOUND IN THIS GAME. Also, those fonts you use for this
game are ATROCIOUS AND UGLY, NO TASTE. At least use fonts that can be unique for this game, and UI/UX unique for this
game. Make this game really special and make the players feel they are playing a $60 triple A game with designs that
are really made with love and effort and theme."

Before: a flat red stripe for the charge, three red rings for the throw, a red triangle with "They're coming from
behind!" for the roar, a red bar for his health; Godot's default Noto Sans everywhere and Windows' Bahnschrift in the
lobby.

## Heavy-arm's tells: Mang Dado's night round

He was the guard who kept the rear gate (0.53). His tells now come from the things a Davao security guard carries on
the night shift, which he still has on him. Each one has a visible reason in the world.

- **The flashlight** (heavyarm_body.gd `_torch`): a cheap right-angle guard's flashlight clipped high on the left
  strap of his lanyard (black plastic, electrical tape round a crack, chrome bezel, an old yellow bulb). heavyarm.gd
  `_torch_render` drives it on every peer from his state: a SpotLight3D with the reflector's ring pattern as its
  projector (`torch_cookie.png`), a volumetric-looking cone (`scripts/coop/torch_beam.gdshader`: dust motes drifting,
  soft sides, faded where it meets the ground), and the lens glowing.
  - sat at the gate / talking: on, weak, at the ground in front of him (a small light by the gate);
  - fighting: on, low, swinging ahead of his walk;
  - **charge**: it snaps on (a click) and hunts the one he wants. Its light lies long down the ground where he will
    run (`_lane`: a Decal with `torch_lane.png`, the cheap reflector's rings drawn out down the lane). While hunting it
    lags the target and cuts out now and then on a bad contact; for the last second it holds dead still and steady
    (a second click): that is the lane. He runs down his own light, the pool going ahead of him;
  - **looking into the beam** whites out the body camera: a hot core and a flat streak where his flashlight is on the
    screen (`glare.png`) and a warm wash over the frame, by how squarely it points at the lens (a ray checks nothing
    stands between);
  - dazed: sputtering; dead: wherever his chest fell, a few last flickers, out after ~8 s.
- **The throw: "anino"** (shadow). While he tears the slab up (the flashlight down in the hole), the slab's and the two
  chunks' shadows are already on the ground where they will land (`_marks`): a blot the slab's shape, turning slowly,
  in a faint pool of cold moonlit grit with a pale broken rim at the edge of what each piece will hit
  (`anino.png` + `anino_rim.png`), darker as the throw comes, steady for the last half second. Each shadow stays
  under its piece while it is in the air (`_falls`), blacker the nearer it is.
- **The roar: the whistle.** Breathing in, he turns the flashlight straight up into the sky (a beacon, brighter as he
  breathes in) and you hear the pea of his guard's whistle rattle (`whistle_inhale.wav`); then the whistle (short,
  short, long: a guard calling for help, `whistle_call.wav`) and the roar. The pack comes from behind the squad as
  before; the dogs on that side go off as it comes through (`assets/audio/night/dog_bark_*`), one of the squad shouts
  "Sa likod! Behind us, they're coming up behind us!", and the arrow at the screen's edge is **one of the survivors'
  orange spray-painted arrows** from the town (`assets/siege/spray_arrow_albedo.png`), sprayed on and breathing, with
  BEHIND YOU in street-sign capitals.
- **His health is the rear gate's chain** (`ChainBar`, drawn): links out to both sides of the gate's brass padlock; as
  he is hurt they go from the far ends inward (the next to go rusts red and shivers, then snaps off and falls); a thin
  rust line under the chain is his health exactly, with a pale trail of what was just taken; a glint runs along the
  steel. Dead, the shackle springs open. Over it "Heavy-arm" in the serif's italic; under it MANG DADO · BANTAY,
  REAR GATE.
- Art and sounds: `python -I tools/ui/heavyarm_tells.py` writes `game/assets/coop/heavyarm/*.png` (procedural:
  reflector rings, the lane pool, the shadow and its rim, beam dust, the menu's light pool, the lens glare) and
  `game/assets/audio/heavyarm/*.wav` (synthesised: the pea whistle through a ruined mouth, the breath in through it,
  the flashlight's switch). The decal textures are imported lossless with mipmaps.
- The Compatibility renderer (Android) has no decals: the lane and the shadows fall back to flat quads there.
- Networking: `flags.boss` gains `wk` (how far into a wind-up) and `run` (the lane while he runs); the rest is drawn
  from what was already sent.

## The game's own type

Four faces, each with one job (`scripts/ui_type.gd`, class `SleepType`; all SIL OFL, `game/licenses/FONTS.md`):

| Face | Job |
|---|---|
| **Instrument Serif** (and italic) | the story's voice: the title, chapter names, headings, menu items, the story box, Heavy-arm's name |
| **Vina Sans** | street-sign capitals, cut from hand-painted shop and road signs: small labels, the speaker's name over a line, the lobby, BEHIND YOU. Its lower case is drawn as other caps, so it is only ever set in capitals |
| **Familjen Grotesk** (variable, 500) | the default for every Control and Label3D (`gui/theme/custom_font` = `assets/fonts/sleep_text.tres`): dialogue, the objective, menus' text, world labels |
| **Xanh Mono** | the record: numbers on the boards, the loading percentage, the story's page count |

Colours shared: bone (paper, old paint), sodium (Davao's orange street lamps: names, what is chosen), rust (yero and
dried blood: rules, danger), moon (the cold side), ink (the panels).

## Menus and HUD

- **Home menu and loading screen** (one shared block, `scripts/ui_menu.gd` `SleepMenu`, so the loading screen still
  fades into the menu without a jump; checked pixel for pixel): A NIGHT IN DAVAO CITY in small sodium capitals, "Sleep"
  in the serif with the blood still running from it (ui_blood.gd now draws in the serif), the byline in italic, then
  Play / Multiplayer / Options / Quit in the serif. The loading bar is sodium, its caption italic, the percentage mono.
- **The cursor is a flashlight**: the chosen button is lit by a warm pool of light (`menu_pool.png`), drifting after the
  choice like a hand-held light, flickering faintly (`SleepMenu.MenuLight`; home menu, loading screen, every window).
- **Windows** (pause, options, notes, the chapter board, match results): cut from the dark with a hairline edge and a
  rust rule along the top (the blood drip on the top edge stays); headings (`_label` 30 px and up) in the serif, larger;
  sub-headings (24-29) in its italic; buttons in the serif; option pickers in the text face. The boards: column heads in
  small street capitals, names in the text face, numbers in the mono, READY in green capitals, the next chapter's
  loading as a mono line over a thin sodium bar (no more ■□).
- **Dialogue** is subtitles: no box, a soft band of dark fading out to both sides, the speaker's name over the line in
  sodium street capitals ("Ma'am Teves\n..." is split at the first line break, `session._set_dialogue`).
- **Story box** (the school's pages): heading in street capitals, the words in the serif's italic, page count in mono.
- **Chapter screen**: NEXT in small capitals, the chapter's name large in the serif (no longer forced to capitals), a
  sodium bar, READY.
- **Lobby**: Bahnschrift is gone: its condensed labels and buttons are the street-sign capitals (OLIVAR FAMILY MART now
  reads like the store's painted sign), the rest the text face. The look pickers no longer size themselves to their
  longest choice (that pushed the squad chat off the screen's right edge; it fits now, long names end in an ellipsis).
- HUD otherwise as minimal as before (no new lines; no crosshair added).

## Checks

- Project renders: `work/v54/cap3` (`--capture-review --capture-views=coop_heavyarm`, three new views:
  heavy_charge_track, heavy_charge_glare, heavy_roar_beacon), `work/v54/menus` (`--capture-menus`, now home, options and
  pause), `work/v54/loading` (`--capture-loading`), `work/v54/lobby` (`--capture-views=coop_lobby`).
- Tests: see Results.

## Results

- Tests (headless, one at a time, project build): coop_heavyarm 48/48, coop_chapters 26/26, coop_school 44/44,
  coop_integration 39/39, touch_integration 39/39, debug_menu_integration 39/39, gun_integration 42/42,
  hut_story_integration 75/75, coop_escape 38/38 on a second run (the first run failed "crouched past it" and "a shot
  wakes the rest": a randomly wandering infected stood in the test's crouch lane; flaky, not from 0.54).
  sleep_review hung without a report: it is not in the suite and already expected the pre-Multiplayer home menu.
- Export: `python -I tools/export_windows.py` was started (log `work/v54/export.log`); the session hit its usage
  limit before it finished. **Not verified**: whether `builds/windows/Interior.exe` 0.54.0 was written, and no EXE
  captures were taken yet. Next: check the log's last line, then run `bash work/v54/exe.sh` and look at
  `work/v54/exe/*` before calling the build done.

## Screenshots sent

| file | what |
|---|---|
| work/v54/progress_1.jpg | project renders: home menu, pause window, the charge's flashlight hunting and held, the lens glare, the slabs' shadows, the roar's beacon, the spray arrow, the dialogue subtitles, the chapter screen |

## Open

- The single-player HUD (house, town) only changed font; its own windows use the shared window look.
- The debug menu keeps its own layout (the default font changed).
- Not tested on two real PCs; the flashlight's state is derived per peer from the boss flags, as the old tells were.
