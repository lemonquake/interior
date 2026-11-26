# 0.60 handoff: real litter in the slum, hurt shake + red flash, ElevenLabs voices, zombie/gore load report

Owner's request (2026-11-23):
- "check out the slums area map and see those 3D trash models, they don't really look like Trash ... create ultra
  efficient 3D models of Trash and Stuff scattered and messy like empty cups ... ULTRA EFFICIENT, ULTRA BLAZING FAST"
- "do a comprehensive report on the performance when there are tons of zombies and tons of limbs and blood, and how
  much should we take like for every 20 zombies killed we reset and remove the older dead zombies"
- "The player's vision should vibrate/shake just a bit ... and have a subtle red flash (not too much)"
- "I am now on Elevenlabs so create and use the proper voice lines for everything ... proper and necessary emotions"
- mid-run: NO Filipino accents or Filipino flavour in the voices, no "Diyos ko"/"Salamat sa Diyos" etc. in anything
  new (normal reactions: "Oh my...", "Oh, thank God"); use Lemon Voice for Aljay and narration -> Lemon Voice is an
  instant clone the free plan can't use, owner said use a different voice; "Don't use Chris for Aljay".

## Litter (scripts/trash_kit.gd, `InteriorTrash`)

The slum = the canal squatter settlement past the Slum passage (scripts/canal_settlement.gd + canal_warren.gd). Its
litter was Blender `litter_a/b` kit pieces (blobs, boxes, rods) merged into the kit batches.

- 12 kinds made in code, vertex colours only (no textures, no UVs): paper cup (printed band, dark inside), milk-tea
  cup (dome lid, straw), styrofoam noodle cup (foil torn back, dark inside), take-out clamshell (sauce in it, lid
  flopped open), crushed can, 500 ml PET bottle (label, cap), knotted plastic bag with handles, sachets, crumpled
  paper, folded cardboard/newspaper, juice box with straw, "bits" (cigarette butts, bent straw, caps, spoon).
  4..129 triangles each; the whole kit is ~2,100 vertices (~59 KB), shared by every map (static cache).
- Each piece is a MultiMesh instance (transform + one vec4: tint and grime) = 64 bytes. One shader for all of it.
  No shadows, no colliders, no GI, visibility range 36 m. Grouped per kind per 16 m square; each square's node
  sits at its centre (Godot measures visibility ranges to the node).
- Poses per kind (upright, on its side, stepped flat), lie with the ground's slope, random tint + grime.
- Scatter: `cluster` (a heap), `line` (drift along a gutter/wall, knotted), `floating` (light stuff on water).
- Canal: every `litter_*` kit call now becomes a heap of real pieces (canal + warren); new drifts along both lane
  edges against the house fronts, loose pieces across the lane, knots, the foot of the wall on the catwalk, both
  edges of the far-bank path, the rubble bank, the far bank; the river's 70 floating blobs/rods are now floating
  cups/bottles/bags/boxes (same rng calls, so nothing else moved). 4,192 pieces in 263 squares.
- Cost, measured (same 7 views, with vs `-- --no-trash`): +65..83 draw calls (~4 %), +~100k triangles (~1 %), GPU
  time within noise, +1.7 MB RAM, +8 MB video memory.
- Gotcha: Godot front faces wind CLOCKWISE; the kit computes normals for that. With the opposite winding the
  double-sided shading flips every lit face away from the light and the pieces render black at night (looked fine
  under ambient light in the review scene).
- Review: `godot --path game --resolution 1280x720 --script res://tests/trash_kit_review.gd -- [--dark] [--out=..]`
  (line-up + a messy patch, prints triangle counts). Canal views 6/7 (`--capture-views=canal`) are litter
  close-ups with a fill light; each view prints `INTERIOR_CANAL_FRAME` stats.

## Hurt feedback (scripts/hurt_feedback.gd, player.gd `shake`)

- Being hit: a small fast shudder of the view (~0.4 s, at most ~0.6 degrees, respects the camera-motion option) and
  a faint red flash, stronger at the edges (centre alpha .07, edge .33 at full strength), gone in 0.42 s.
- Solo: zombies.gd `hurt_player` (severity from the damage; the old edge flash halved, .5 -> .25). Co-op: session.gd
  when the local survivor's HP drops (severity = HP lost / 30).

## Voices (ElevenLabs website, Eleven v4, stability 30 %)

- Every line has acting directions (v4 audio tags and punctuation): tools/dialogue_directions.py. No accent tags.
- tools/dialogue_lines.py gathers every spoken line from the scripts into game/assets/audio/voices/dialogue.json
  (key = sha1("speaker\ntext")[:12]); scripts/voice_lines.gd (`InteriorVoiceLines`) plays
  voices/dialogue/<key>.ogg when the co-op subtitle (session.gd `_set_dialogue`) or the solo dialogue box
  (story_ui.gd) shows the line. Lines without a clip stay text only.
- Takes: one generation per voice, all its lines as paragraphs; tools/split_voice_takes.py cuts them using local
  speech recognition (faster-whisper small.en word timestamps; silence alone failed: dramatic pauses inside lines
  are as long as the breaks); tools/verify_voice_split.py transcribes every clip back; tools/install_voices.py does
  it all from work/Voices (where the owner saves the downloads).
- Cast: Jonna Sarah, Ma'am Teves Matilda, Rommel Bill, Dodong Roger, hooded man Eric, Paolo Liam, the solo
  protagonist ("You") Chris, narration captions George, survivors Alex Adam, Aljay Will, Louie Harry (Charlie was
  Australian), Anthony Brian, Clyde Callum.
- Free plan (10k credits): voiced everything except Louie/Anthony/Clyde's story replies (their {P} lines stay text)
  and the 2nd/3rd takes of Alex/Louie/Anthony/Clyde's call-outs (voices.gd now falls back to take 1; the old Windows
  placeholder .wav files are deleted). Aljay has every take. ~20 credits left.
- Text changed in-game (owner's rule, lines not yet voiced): Dodong "keep watch for the barangay" -> "for the
  neighbourhood", "my barangay gate keys" -> "my gate keys"; "Sa likod! Behind us, ..." -> "Behind us! They're coming
  up behind us!"; "Tao po? ...Nobody." -> "Hello? ...Nobody.". Already-voiced lines keep "Diyos ko"/"Salamat sa
  Diyos"/"Hoy" (owner: no need to redo).
- Check: `godot --headless --path game --script res://tests/voice_lines_check.gd`.

## Zombie / gore load

Full report: work/v60/perf/report.md (test: tests/zombie_load_perf.gd). Live infected, not corpses, are the cost:
a settled corpse ~0.055 ms, a live chasing infected ~0.3-0.45 ms; solo 25 alive = 100 FPS, 50 = 62; co-op host is
already 81 FPS empty. Recommended (not applied, awaiting the owner): rolling caps instead of "20 every 20 kills":
solo corpses 16 removing the oldest out of view; co-op 12 with the host choosing; limbs 20 -> 12 and freed with
their body; decals keep; solo MAX_ALIVE ~20 for 100+ FPS in gore fights.

## On-screen text added

- The four changed lines above. No other strings.

## Screenshots sent

| Image | What |
|---|---|
| work/v60/t2/canal-6-lane-trash_b.jpg | the canal lane's litter at night (brightened, fill light) |
| work/v60/trash-dark/trash-patch-close.png | the kit under neutral light |
| work/v60/exe/canal-6-lane-trash_b.jpg | the same lane from the 0.60.0 EXE's own capture |

## Build

builds/windows/Interior.exe + Interior.pck 0.60.0 (tools/export_windows.py, 2026-11-23 18:15), zip
Sleep-0.60.0-windows.zip. EXE canal capture checked (litter drawn). 111 dialogue clips + 167 call-out clips imported.

## Open

- Louie/Anthony/Clyde story replies + alternate call-out takes need ~5,300 more ElevenLabs credits.
- Lemon Voice (owner's clone) needs a paid plan; re-voice Aljay/narration with it then if wanted.
