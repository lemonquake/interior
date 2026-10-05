# Interior 0.8: subtle ground mist, better clouds, twenty stars, distant dogs, calm water (handoff)

Branch: `main`. Written 2026-10-05. The previous handoff is `docs/v7/handoff.md`.

## Owner request (2026-10-05, summary)

The fog on the long dirt road was "so ugly and not atmospheric at all". The clouds were low quality. Too many stars:
cut them to about 20 slightly twinkling stars that don't move. Add dog barks far from the player at random times, not
often enough to annoy. Fix the water glitch that makes it move extremely fast. Use a third-party fog system or effect if
one exists: subtle fog outside the player's house, just enough for atmosphere.

## What changed

| Part | Where | Notes |
|---|---|---|
| Water speed bug | `scripts/night_water.gdshader` | The ripple scroll was `TIME * time_scale * (1 + gust)`. Each wind gust scaled the whole elapsed time, so the longer you played the further the ripples jumped during a gust (after 10 minutes, several texture tiles a second). Scrolling is now constant; gusts only roughen the surface (`wind_ripples`). |
| Fog | `scripts/night_mist.gdshader` (new), `scripts/neighborhood.gd`, `scripts/fields.gd` | Third-party base: alghost's MIT "Moving gradient noise fog/ mist" fog shader (godotshaders.com; reference copy and licence in `assets/fields/fog/mist_alghost_mit.gdshader.txt`). Adapted: broader and slower octaves, density never fully clears (so it reads as one layer, not puffs), rests on the ground (y -2.9), gone by y -0.2 so the balcony and the rooms stay clear, faded at the edges of its box. One 180 x 5 x 180 m FogVolume follows the camera (snapped to 4 m; the noise is in world space so the mist itself doesn't move with you) everywhere outdoors, in town and in the fields alike. Density 0.0075 in town, 0.008 out on the road. Desktop High and Ultra only (volumetric fog, froxel grid 128x96 on Ultra, 96x64 on High). The 0.7 paddy mist (dense FogVolume with a noise texture) is removed, and the depth haze is lighter: 8-150 m in town, 24-340 m in the fields, steeper curve. |
| Clouds | `scripts/night_sky.gdshader`, `assets/fields/sky/cloud_noise.png`, `tools/assets/make_cloud_noise.py` | After Velvet Katana Studios' CC0 "AAA Fake Volumetric Clouds" (notes in `assets/fields/sky/clouds_velvetkatana_cc0.txt`). Replaces the 0.7 sin-hash value noise. A cloud deck of two layers of a seamless 1024 px spectral noise texture (generated, equalised channels: big shapes, fine detail, warp), lightly domain-warped, slowly drifting and evolving. Detail only frays thin edges; thick bodies are dark, thin parts and anything near the moon glow silver; the moon dims behind thick cloud and shines through thin veils; clouds hide the stars behind them and fade toward the horizon. Cover 0.34, scale 0.22, speed 0.0015 (`InteriorNight.SKY_PARAMS`, `configure_sky`). |
| Stars | `scripts/night_common.gdshaderinc` (`night_stars()`), sky and water shaders | The two hashed star grids (hundreds of stars) are replaced by `star_count` = 20 fixed stars: golden-angle azimuths, 20-78 degrees up, pushed away from the moon. They are fixed to the sky (the dome follows the camera position only) and twinkle gently (+/- 14 %). Pixel-size aware, so each is a crisp one- or two-pixel point with a faint glow at any resolution. The paddies reflect the same stars. |
| Dog barks | `scripts/night_audio.gd` (`_update_dogs()`, `_bark()`), `assets/audio/night/dog_*.ogg`, `tools/assets/fetch_dogs.py` | Six phrases cut from four Wikimedia Commons recordings (CC BY-SA, credits in `licenses/NIGHT_SOUNDS.md`), band-passed 220-3200 Hz so they sound far off. One dog barks 70-130 m away in a random direction every 40-110 s (first after 25-55 s); about a third of the time a second dog answers 1.5-5 s later from 110-170 m in another direction. Never the same clip twice in a row. Strong distance low-pass and the Night bus reverb; muffled indoors like the rest of the night. |
| Road colour seam | `scripts/fields.gd`, `scripts/balcony.gd` | Owner follow-up (with a screenshot): a flat, hard colour change across the dirt road a few metres ahead. Cause: under the low moon the rutted road shadowed itself, darker in the sharp near shadow cascade (first ~7 m) than in the next, so the cascade edge showed as a line. The ground meshes (road, verges, dikes, banks, mud, puddles) no longer cast moon shadows (set at runtime, no re-bake), and the moon now blends its cascades (`directional_shadow_blend_splits`, fade from 70 %). Brightness along the road is now continuous (measured down the road centre). |
| Version | `export_presets.cfg` | 0.8.0, Android version code 8. |

## Tests

- `fields_integration` 25/25, `balcony_integration` 63/63, `street_integration` 27/27 (all `--headless --fixed-fps 60`).
- New `tests/dog_bark_check.gd` (windowed, not headless; night audio is off in headless): four barks in a row all play,
  75-119 m away, no clip repeated back to back. Passed.
- Review renders: `tests/v7_views.gd` (unchanged) on Forward+ and with `--rendering-method gl_compatibility`: the new sky
  shader compiles and renders on both.

## Builds (2026-10-05)

| File | Size | SHA-256 |
|---|---|---|
| `builds/windows/Interior.exe` (0.8.0, release, embedded PCK) | 637 MB | `f259e79f3b1487899aaac1b6e45f48e6bb4885f85e1cfef2f4b50db287b1de90` |
| `builds/android/Interior.apk` (0.8.0, code 8, debug-signed) | 585 MB | `d933f24d6a41ab50c0e2ccd44a523f09e4944e0ad9355aed64ab931c9dddd778` |

Rebuilt after the road-seam fix. The EXE's own `-- --capture-review --capture-views=balcony` run rendered all six views
(`work/v8/exe-smoke/`). Note: an export fails with "Failed to rename temporary file" while the old EXE is running.

## Known gaps

- Android (Compatibility) and desktop Low/Medium have no ground mist (no volumetric fog there); they keep the lighter depth haze.
- Distant coconut palms still read a little pale against the horizon, as in 0.7.
- The water fix can't be shown in a still; the cause and the change are above. Godot's `TIME` still wraps every hour
  (project default), which gives one invisible jump of the ripples.
- Not play-tested on a phone this run.

## Screenshots sent to the owner

| File | What it shows |
|---|---|
| `work/v8/screens/01-sky-fog-before-after.jpg` | 0.7 vs 0.8: the road toward the moon, the balcony view, the road start, the way out of town |
| `work/v8/screens/02-road-seam-before-after.png` | The dirt road at the start of the fields: the cascade seam (top) and the fix (bottom) |

## How to resume

1. Mist: density and colour in `neighborhood.gd` `_set_mist()`; shape (height, patchiness, drift) in `night_mist.gdshader`.
2. Clouds: `cloud_cover`, `cloud_speed` in `InteriorNight.SKY_PARAMS`, `cloud_scale` in `configure_sky()`, colours in
   `night_sky.gdshader`. Regenerate the texture with `python tools/assets/make_cloud_noise.py`.
3. Stars: `star_count` / `star_energy` in `SKY_PARAMS`.
4. Dogs: intervals and distances in `night_audio.gd` `_update_dogs()`; add phrases in `tools/assets/fetch_dogs.py` and `DOG_CLIPS`.
