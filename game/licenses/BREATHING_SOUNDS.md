# Breathing sounds (0.36)

The player's breath (`game/scripts/body.gd`) is cut from two recordings, both released by their authors under
**Creative Commons 0 1.0 (public domain dedication)**: https://creativecommons.org/publicdomain/zero/1.0/
No credit is required; it is given here anyway.

| Files in `game/assets/audio/sfx/` | Recording | Author | Page |
|---|---|---|---|
| `breath_pant.wav` (the panting loop) | "Male_Breath_Fast_Loop_Stereo.wav" | Nox_Sound | https://freesound.org/s/554907/ |
| `breath_heavy_1.wav` to `breath_heavy_10.wav` (single slow breaths) | "Male Heavy Breathing.wav" | fadyhaddad | https://freesound.org/s/474647/ |

- Retrieved 2026-11-17. The licence was read on each recording's own page that day.
- What was downloaded is Freesound's high-quality preview of each recording (Ogg Vorbis), which needs no account;
  the copies are kept in `work/v36/dl_freesound/`.
- Changes made (`tools/breath_sounds.py`): mixed to mono, resampled to 44.1 kHz, rumble under 70 Hz removed,
  levelled, the ends eased. The slow recording was cut into its separate breaths; the silence between them and
  one breath with a voiced grunt in it were left out.
