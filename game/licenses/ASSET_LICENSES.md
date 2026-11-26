# Interior asset sources

Horror props and red liquid 0.24: nine textures generated for this project with
OpenAI imagegen. See HORROR_TEXTURES.md for the file list and provenance.

Interior, authored meshes, custom textures, and code: Aljay Leodones, 2026.
No license granting redistribution of the original work is implied by this notice.

Wood Floor by Dimitrios Savva: https://polyhaven.com/a/wood_floor
Marble 01 by Rob Tuytel: https://polyhaven.com/a/marble_01
Both are CC0: https://polyhaven.com/license
Source receipts and file hashes are in room/asset-provenance.json.

All eight current frame inserts use photographs supplied by the owner. The
originals were preserved; full-image resampling and paper margins are recorded
in assets/family/provenance.json. No general redistribution license is granted
for these family photographs.

Hamster mesh: **Hamster by Asia Matusik**, licensed **CC BY 4.0**.
Original: https://sketchfab.com/3d-models/hamster-c6a24007915a4aa9ae47fd912191c7b4
Author: https://sketchfab.com/asiam
License: https://creativecommons.org/licenses/by/4.0/
Downloaded via the Allen Institute's public Objaverse distribution. Changes:
engine scale, coat colors and fur texture, rounded ear tips, fine whiskers,
quadruped skinning and animation clips. The derivative and original hashes
are recorded in assets/hamsters/provenance.json. No endorsement is implied.

People (0.9): the base body `models/generic_body.obj` / `.jpg` (a Tripo-converted
figure) and its clips in `models/generic_body_animation/` were supplied by the
owner. Its skeleton, skinning, action library and hair models come from the
owner's own Beyond Heroes project (tools/blender/hero). The stranger's clothes
(hoodie, hood, pocket, drawstrings, jeans, sneakers) and the gate_grip and
stand_stare clips were made for Interior by tools/blender/human/build_human.py.

Furniture, connected enclosure, aquarium and room-extension geometry,
authored surface textures, procedural sounds and runtime behavior were created
locally for this project. Surface generation uses deterministic seeds.

Godot Engine and bundled third-party components: see GODOT_COPYRIGHT.txt.

Atmospheric particles: Particle Scene Compositor by ChiprChopr / tvenclovas96
and Wind Driven Falling Particle Shader by Profesor Shader, both MIT licensed.
These third-party systems run the room dust, ground wisps, airborne seeds, and
lamp moths. See ATMOSPHERE.md for pinned source URLs, the modifications, and
PARTICLE_SCENE_COMPOSITOR_MIT.txt / PROFESOR_SHADER_MIT.txt for full notices.

Neighborhood 0.14: Rusty Metal 04 and Damaged Plaster by Amal Kumar, and Rough
Plaster Broken by Rob Tuytel (Poly Haven, CC0). Used on vehicles and exterior
surfaces. ATMOSPHERE.md and each texture directory's source.json record sources,
licenses and file hashes.

Canal settlement 0.16: new Poly Haven CC0 trashbag and wooden crate models,
existing credited foliage and props, original architecture and graffiti, and
surface-specific footstep derivatives of Kenney CC0 recordings. See CANAL.md
and game/assets/models/canal/*/source.json for provenance and file hashes.
