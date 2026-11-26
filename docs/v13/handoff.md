# Interior 0.13: abandoned neighborhood

Updated 2026-10-06. This builds on the existing 0.9–0.12 working tree without resetting or rebaking the photographed room, balcony, fields or story.

The neighborhood now uses instance-local weathering over its existing photographic Poly Haven PBR sets. Original metre-scaled UVs, albedo, normal and roughness maps remain in use. The shader adds irregular peeling plaster, rain runoff, rising damp, moss, salt deposits, rust, timber wear, fine fractures and variable ground moisture. Road paint is worn away selectively. Exterior shadow fill is slightly less blue while preserving the indoor/fields transitions.

Street-level geometry includes 24 broken boundary-wall tops, 187 irregular exposed-masonry areas, 118 larger wall fractures, and 98 boarded or sheet-covered windows (281 splintered timber boards and 10 bent corrugated sheets). Debris follows the road and raised-pavement heights. These are closed boundary walls; their original blocking collision remains in place beneath the decorative top damage.

Ground dressing contains 44 branching road/pavement fracture clusters, 195 dirt/silt patches with feathered edges, 10 leaf-filled drainage grates, 6 shallow puddles, 321 small aggregate pieces and 163 wind-moving weed clumps. Puddles reuse the existing night-water shader and its credited analytic sky reflection. Detail is deterministic and batched; grass is partitioned into 16-metre cells. The new ordinary meshes contain 59,613 triangles, plus 4,401 instanced weed triangles. Original boundary-wall geometry is removed where its damaged replacement is inserted. The owner's room and play routes are preserved.

## Verification

- Neighborhood emitted geometry and real-player traversal: 32 checks passed. Includes winding, normals, zero-area triangles, visibility, collision support, route to the fields, and hiding the exterior indoors.
- Existing street behavior: 27 checks passed.
- Existing balcony behavior: 63 checks passed.
- Existing atmosphere transitions: 15 headless checks passed.
- Six matching native views at 1600 × 900 in Forward+ and Compatibility completed without shader/runtime errors. Baseline, final source captures and metadata are in `work/v13/baseline`, `work/v13/final`, and `work/v13/compatibility`.
- Exported Windows 0.13.0: all six built-in neighborhood captures completed at 1920 × 1080, with matching packed detail counts and no runtime/shader errors. Evidence: `work/v13/exe-final/game.log` and adjacent PNGs.
- The fast headless traversal test sometimes reports existing grass-footstep Ogg playback resources still active at shutdown. Verbose evidence is in `work/v13/teardown.log`; there are no failed assertions. Native rendered reviews exit cleanly.

The short source-camera timing samples on this RTX 4060 were approximately 16.7 ms and limited by vsync; they do not establish an uncapped performance improvement or a phone performance guarantee. Compatibility was reviewed on the desktop GPU. The Android APK was not rebuilt for this request.

## Files and reproduction

- `game/scripts/neighborhood_weathering.gd` and `.gdshader`: instance-local PBR weathering.
- `game/scripts/neighborhood_ground.gd`: street detail geometry and weed instances.
- `game/scripts/neighborhood_derelict.gd`: architectural wear, matched to baked windows and boundary walls.
- `game/scripts/neighborhood.gd`: runtime integration and outdoor ambient transition.
- `game/tests/neighborhood_review.gd`: source-camera comparison and render metadata.
- `game/tests/neighborhood_decay_integration.gd`: geometry and walking validation.

Use Godot 4.7.2. Export with `--headless --path game --export-release "Windows Desktop" <output-exe>`.

The executable has its own capture route, because release templates do not run the editor's `--script` harness:

```text
Interior.exe --log-file <log-path> -- --capture-review --capture-views=neighborhood --capture-path=<absolute-directory> --render-size=1920x1080
```

This prints the packed scene's detail counts, captures six street/overview views, then exits. Add `--headless` before `--` for a packed-resource startup check without pictures. Output and checksums for the finished Windows build are recorded in `work/v13` and `builds/SHA256SUMS.txt`.
