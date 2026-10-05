# Interior 0.2 production status

The requested movement, physics, family photographs, connected hamster habitat, lower aquariums and additional room sides are implemented. The Windows x64 EXE and ARMv7/ARM64 Android APK compile successfully with Godot 4.7.2. Android remains locally debug-signed.

The scene contains 48 original physical prop assemblies, a second aquarium and six loose kitchen props (55 total), three skinned hamsters and four animated fish. The new room sides add 35,224 triangles in 37 material batches and replace 6,126 original shell triangles. They include a real walkable kitchen entrance. The original Blender file is preserved; new geometry is maintained in the runtime scripts.

All nine automated suites pass: physics, original room/mystery interaction, settling, tabletop stability, 10,000-step movement, 10,000-step hamster simulation, new surroundings, combined lifecycle, and multitouch controls. Current reports are in `room/runtime/integration-results.json`. Tests exercise actual engine collisions, rotating contact velocity, overhead clearance, all three enclosure levels, actual skin-vertex deformation, open tube ports, pause/resume and repeated scene teardown/restart.

The owner's final tabletop jitter report was reproduced with the complete awakened stack. The thin tray cylinder was replaced with a broad box support, permitted contact penetration was reduced to 1 mm, and the table, tray, plant and tissue box use non-bouncy contact materials. The new 6,310-check regression wakes the stack, then uses actual grab springs to lift and drop each small object. All four bodies settle naturally without freezing, with zero drift during each final two-second observation.

Output review found and corrected the rear orientation, missing shared-material geometry, annular mesh winding and overstretched hamster forepaws. The final room is captured at 3840×2160; sampled poses demonstrate visible skin deformation. These images do not establish motion smoothness by themselves. A small green decorative bag above the storage cupboard still has a slight visible gap underneath; this is a known cosmetic limitation.

The supplied photographs define the requested layout, but the result remains a simplified modeled reconstruction with estimated dimensions. It is not a measured scan. The earlier blind commercial comparison favored Gone Home for lighting depth; no commercial-superiority pass is claimed. No comparable Half-Life 2 measurement trace was available, so movement is verified against explicit numerical and interaction invariants, not claimed to match Valve physics exactly. Overall lemondev commercial benchmark status remains IMPLEMENTED — UNVERIFIED; the functional test results above are separate verified evidence.

The owner explicitly requested the main-branch push and native builds, then requested that work wrap up. This is not recorded as new human approval of the rendered appearance. Historical Function/Form/Runtime approvals and release v0.1.0 records apply to that older release only.

Final artifact hashes, cold-launch checks and bounded desktop measurements are recorded in `docs/builds-0.2.json`. Android emulator checks do not establish performance on a physical phone. Local diagnostics and full-size captures are kept in the ignored `work/lemondev/2026-10-05/` directory.
