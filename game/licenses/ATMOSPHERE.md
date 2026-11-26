# Atmospheric particle dependencies

The game's runtime particle effects use two independent, permissively licensed
third-party projects. No native extension, online service, or editor plugin is required.

## Particle Scene Compositor

- Author: ChiprChopr / tvenclovas96
- Source: https://github.com/tvenclovas96/particle-scene-compositor
- Asset listing: https://godotengine.org/asset-library/asset/3352
- Commit: `7454d1e3816af69d4c6a16a88df978760a1b4da0`
- License: MIT. Complete copyright and license text:
  `addons/particle_scene_compositor/LICENSE`.
  Packaged copy: `licenses/PARTICLE_SCENE_COMPOSITOR_MIT.txt`.
- Included unchanged: `sync_node_3d/gpu_particles/gpu_sync_node_3d.gd` and `Gpu3d.svg`.
- Used by every particle group in `scripts/atmosphere_particles.gd` for synchronized
  lifetime, looping, and zone stop/restart. Only the standalone GPU 3D runtime is included.

## Wind Driven Falling Particle Shader

- Author: Profesor Shader
- Source: https://github.com/profesorshader/shader-wind-driven-falling-leaves-petals-feathers
- Commit: `4b71810048bd86a9292b5b44b2cad0c7dd5d7956`
- Original file: `shaders/falling-leaves.gdshader`.
- License: MIT, as distributed in the source repository. Complete notice:
  `assets/atmosphere/third_party/PROFESOR_SHADER_LICENSE.txt`.
  Packaged copy: `licenses/PROFESOR_SHADER_MIT.txt`.
- The author also publishes the shader as CC0 at
  https://godotshaders.com/shader/wind-driven-falling-particles-leaves-petals-feathers/.
  This integration follows the repository's MIT notice.
- Unmodified reference: `assets/atmosphere/third_party/falling_leaves_original.gdshader.txt`.
- Active adaptation: `assets/atmosphere/shaders/wind_drift.gdshader`.
- Changes: disable vortex motion, use frame-rate-independent velocity response, preserve
  tint opacity, add gradual birth fade, configurable scale and the game's wind-gust input.
  The original seeded spawn, rotation, and wind variation form the particle simulation.
- Used for actual room dust, outdoor wisps, airborne seeds and moths around practical lights.

Retrieved 2026-10-06. The sprite renderer and atmosphere placement/controller are
authored for Interior. It uses soft depth intersections in Forward+ and a shader path
without depth sampling in Compatibility. All quality levels retain an atmosphere;
Low and Compatibility use smaller particle budgets. Exterior particles are excluded
from the hut interior, and broad wisps never rise to the upstairs rooms.

## Night neighborhood update (2026-10-07)

Rusty Metal 04 by Amal Kumar, from Poly Haven:
https://polyhaven.com/a/rusty_metal_04

CC0-1.0: https://polyhaven.com/license

The 1K diffuse, OpenGL normal and roughness maps live in
`assets/outdoor/textures/rusty_metal_04/`. `source.json` records download URLs and
SHA-256 hashes. They replace plain vehicle materials with photographed corrosion
and pitting, and add worn metal to gates, shutters, grilles and trim. Vehicle paint
and original UV textures are retained beneath local dirt, dust and rust variation.

Two more CC0 Poly Haven sets replace the neighborhood's plaster surfaces:
- Rough Plaster Broken, Rob Tuytel: https://polyhaven.com/a/rough_plaster_broken
- Damaged Plaster, Amal Kumar: https://polyhaven.com/a/damaged_plaster

Each uses 1K diffuse, OpenGL normal and roughness maps, with its own `source.json`
under `assets/outdoor/textures/`. The first supplies dusty chipped plaster; the second
supplies crumbling exposed patches. `tools/assets/fetch_neighborhood_wear.py`
downloads and verifies these sets using the provider's checksums.

The existing community systems remain active: Particle Scene Compositor manages
the particle groups; Profesor Shader's simulation moves airborne dust and seeds;
alghost's MIT gradient-noise mist supplies ground fog on Forward+.
Mist source: https://godotshaders.com/shader/moving-gradient-noise-fog-mist-for-godot-4/
The original mist source and license are in `assets/fields/fog/`.
VelvetKatana's CC0 cloud base remains in `scripts/night_sky.gdshader`, with the
reference and notice in `assets/fields/sky/clouds_velvetkatana_cc0.txt`.
These effects render locally; no network service is needed during play.
