# Horror prop textures and red liquid — Sleep 0.24

Six new imagegen albedo maps replace flat colours on refuse and loose props:
wrinkled black bin liners, scuffed plastic, water-damaged cardboard, discarded
newsprint, tarnished steel and stained woven fabric. They are applied to street
litter, canal rubbish heaps, bags, wrappers, cans, pails, basins, sacks, tarps,
slippers and covered bundles. The menu's broken crate uses an existing credited
photographic wood material. Existing photographic model materials retain their
original textures.

The shared material helper maps these surfaces in metres with triplanar mapping
and material-specific roughness. All nine new images use mipmaps and compressed
desktop S3TC / mobile ETC2 imports. Source PNGs are preserved unchanged.

Three new transparent RGBA graphics provide impact splatter with drips, a drag
smear and an irregular pool. They are integrated into 201 liquid decals across
the town and Nichols basement. Android's Compatibility renderer uses meshes
sampled against static receiving surfaces. These follow walls and pavements,
avoid bridging missing receivers and clear the town's decorative road surface.
Unsupported volumetric fog is skipped in Compatibility; the lighting remains.

## Artwork and prompts

- Final PNGs: `game/assets/horror_textures/props/` and `game/assets/horror_textures/liquid/`.
- Exact prompts: [prop-prompts.md](prop-prompts.md), [liquid-prompts.md](liquid-prompts.md).
- Generation mode: built-in imagegen. No CLI/API fallback or third-party image references.
- Source file hashes: [source-manifest.json](source-manifest.json).
- Source transparency measurements: [liquid-alpha.json](liquid-alpha.json).
- Attribution notice: `game/licenses/HORROR_TEXTURES.md`.

## Validation

The focused prop integration check passed 504 checks with all six texture
families in the running scene, 18 textured canal palette materials and three
textured baked street-litter batches. Physics integration (25), room integration
(271), touch controls (29), canal integration (57) and warren integration (87)
passed. See [checks-summary.json](checks-summary.json) and the accompanying logs.

Rendered liquid reviews cover Forward+ and Compatibility. Prop closeups and
liquid closeups use a camera-local review light to make surface detail visible;
that light is confined to the review scripts and does not change game lighting.
Reports and screenshots are in `props-review/`, `liquid-forward/` and
`liquid-compatibility/`.

The final Compatibility review passed with 201 generated liquid decals, 270
receiving-surface meshes and 8,226 triangles, with no runtime errors. The road
pool and smear were visually confirmed above the decorative asphalt. Seven
prop closeups were also inspected. The older Forward+ pool capture was occluded
by a vehicle; use the final Compatibility pool capture for that view.

The broader settling check failed with drift and a falling pail among loose
props. No causal before/after baseline comparison was performed, and physics
was not changed to resolve this separate check. The complete base test suite
therefore did not pass. The observed failure remains in [baseline.log](baseline.log).

## Builds

The updated main files are `builds/windows/Interior.exe` (Windows x64 release,
embedded PCK) and `builds/android/Interior.apk` (locally debug-signed, ARMv7 and
ARM64). Both identify as version 0.24.0; Android version code is 24.

Build output, package verification and hashes are recorded beside this file.
The packaged Windows executable launched successfully and exited with code 0.
Android APK v2/v3 signature and ZIP alignment checks passed. All nine generated
texture references resolve to packed mobile texture files, and both requested
ARM architectures are present. See [builds.json](builds.json),
[apk-texture-verification.json](apk-texture-verification.json) and
[apk-signature.log](apk-signature.log).

No physical Android device was connected, so device performance and installation
remain unverified.
