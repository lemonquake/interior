# Prop texture review

The seven PNG captures show actual game meshes and the integrated material assignments at 1280 × 720, High quality, Forward+. All seven were inspected directly after capture.

The bag liners retain visible folds and dirt at night. Worn paper and waterlogged cardboard show mottled surface variation. The crate uses the existing photographed wood texture. The pail and basin have scuffed coloured plastic, the pot has visibly tarnished metal, and the canal sacks have stained woven fabric. No missing textures or obvious UV stretching were observed in these views. Existing low polygon prop geometry and the town's dark lighting remain visible.

These are material inspection captures. They use the original night environment plus a warm camera-local fill light confined to the review process. The fill energy, camera position and target for each image are recorded in `render.json`. No source lighting was changed for the captures.

`integration.json` records the passing runtime material checks. Binding counts include overrides and active surfaces; they are not unique object counts.

The review process completed with exit code 0. Godot reported seven Texture RIDs retained during renderer shutdown; no script/runtime errors were reported during capture.
