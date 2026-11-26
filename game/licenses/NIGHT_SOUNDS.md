# Night sounds (0.7)

Recordings from Wikimedia Commons, downloaded and processed by `tools/assets/fetch_fields.py` (trimmed, mixed to mono,
high-passed at 120 Hz, normalised; looping beds crossfaded) into `game/assets/audio/night/`. Played by
`game/scripts/night_audio.gd`. The adaptations are shared under the same licence as each original.

| File | Original | Author | Licence |
|---|---|---|---|
| owl_tawny.ogg | [Strix aluco male.oga](https://commons.wikimedia.org/wiki/File:Strix_aluco_male.oga) | Vianney Bajart | CC BY-SA 4.0 |
| owl_barn_screech.ogg | [Tyto alba - Western Barn Owl XC436946.mp3](https://commons.wikimedia.org/wiki/File:Tyto_alba_-_Western_Barn_Owl_XC436946.mp3) | Joost van Bruggen (xeno-canto) | CC BY-SA 4.0 |
| gecko_tokay.ogg | [Mating call of a male Tokay gecko (Gekko gecko).ogg](https://commons.wikimedia.org/wiki/File:Mating_call_of_a_male_Tokay_gecko_(Gekko_gecko).ogg) | Richard Ling | Public domain |
| frog_kaloula.ogg | [Kaloula pulchra - dringsim - 1446567.ogg](https://commons.wikimedia.org/wiki/File:Kaloula_pulchra_-_dringsim_-_1446567.ogg) | dringsim | CC0 |
| frog_chorus.ogg | [Frogs croak calling chorus at night.ogg](https://commons.wikimedia.org/wiki/File:Frogs_croak_calling_chorus_at_night.ogg) | JogiAsad | CC BY-SA 4.0 |
| frog_chorus_b.ogg | [Night Chorus of Frogs and Toads in Niger Delta.ogg](https://commons.wikimedia.org/wiki/File:Night_Chorus_of_Frogs_and_Toads_in_Niger_Delta.ogg) | ElemePodcast | CC BY 4.0 |
| toad_bufo.ogg | [Bufo bufo call1.ogg](https://commons.wikimedia.org/wiki/File:Bufo_bufo_call1.ogg) | Wikimedia Commons contributor (see source page) | CC BY-SA 3.0 |
| cricket_field.ogg | [Field cricket unedited.ogg](https://commons.wikimedia.org/wiki/File:Field_cricket_unedited.ogg) | Thatcher | CC BY-SA 3.0 |
| cricket_gryllus.ogg | [Cricket Gryllus bimaculatus Chirps.oga](https://commons.wikimedia.org/wiki/File:Cricket_Gryllus_bimaculatus_Chirps.oga) | Rickjpelleg | CC BY-SA 4.0 |

Dog barks (0.8), cut by `tools/assets/fetch_dogs.py` (trimmed, mono, band-passed 220-3200 Hz so they sound far off,
normalised) and played far from the player by `night_audio.gd`:

| File | Original | Author | Licence |
|---|---|---|---|
| dog_bark_a.ogg, dog_bark_b.ogg | [Barking dog in Rome.ogg](https://commons.wikimedia.org/wiki/File:Barking_dog_in_Rome.ogg) | Nicholas Gemini | CC BY-SA 3.0 |
| dog_bark_c.ogg | [Barking of a dog 2.ogg](https://commons.wikimedia.org/wiki/File:Barking_of_a_dog_2.ogg) | Amada44 | CC BY-SA 3.0 |
| dog_bark_d.ogg, dog_bark_e.ogg | [Rottweiler Barking.oga](https://commons.wikimedia.org/wiki/File:Rottweiler_Barking.oga) | MichaeltheFox8621 | CC BY-SA 4.0 |
| dog_pack.ogg | [Seis perros ladrando.wav](https://commons.wikimedia.org/wiki/File:Seis_perros_ladrando.wav) | Luis Alvaz | CC BY-SA 4.0 |

Licences: https://creativecommons.org/licenses/by-sa/4.0/, https://creativecommons.org/licenses/by-sa/3.0/,
https://creativecommons.org/licenses/by/4.0/, https://creativecommons.org/publicdomain/zero/1.0/.
The wind, the low drone and the bamboo creak are synthesised at runtime.

## 0.10: the hut sequence

Cut or made by `tools/assets/fetch_hut_sfx.py` into `game/assets/audio/sfx/`:

| File | Source | Author | Licence |
|---|---|---|---|
| siren_wail.ogg | [Civil-defense-siren-waver.ogg](https://commons.wikimedia.org/wiki/File:Civil-defense-siren-waver.ogg) (48 s cut, looped) | Techtonic | Public domain |
| drawer_open.ogg | [Open drawer (Gravity Sound).wav](https://commons.wikimedia.org/wiki/File:Open_drawer_%28Gravity_Sound%29.wav) | Gravity Sound | CC BY 4.0 |
| lock_turn.ogg, key_pickup.ogg, gun_pickup.ogg, ammo_pickup.ogg | synthesised in the script | this project | - |

## 0.11: the Glock

Neighborhood interactions: the whispered breath ("psst"), resonant wood knocks and worn doorbell are original procedural PCM sounds synthesized by `scripts/neighborhood_encounters.gd`. Rusty hinge stick/slip audio is synthesized by `scripts/push_gate.gd` and shared by the gates. Latches, mailbox rattles and distant footsteps reuse the project's existing credited/synthesized effects. No new third-party audio was added.

Cut or made by `tools/assets/fetch_hut_sfx.py` into `game/assets/audio/sfx/` (played by `game/scripts/gun.gd`):

| File | Source | Author | Licence |
|---|---|---|---|
| gun_shot.ogg | [9 mm gunshot-mike-koenig-123.wav](https://commons.wikimedia.org/wiki/File:9_mm_gunshot-mike-koenig-123.wav) (trimmed, high-passed) | Dantedun (recording by Mike Koenig) | CC BY-SA 4.0 |
| gun_rack.ogg | [Gun Cocking Slow-Mike Koenig-1019236976.wav](https://commons.wikimedia.org/wiki/File:Gun_Cocking_Slow-Mike_Koenig-1019236976.wav) | Dantedun (recording by Mike Koenig) | CC BY-SA 4.0 |
| gun_tail.ogg | the far echo, made from gun_shot.ogg in the script | this project (derived from the above) | CC BY-SA 4.0 |
| gun_dry.ogg, gun_mag_out.ogg, gun_mag_in.ogg, gun_ricochet.ogg, hit_wood.ogg, hit_stone.ogg, hit_metal.ogg, hit_dirt.ogg, hit_glass.ogg, hit_water.ogg | synthesised in the script (Commons has no free magazine recordings) | this project | - |
