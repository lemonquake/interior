# Mobile performance QA — Sleep 0.25

This revision reduces render work and texture memory without removing rooms, routes, interactions or physical props. Both main builds are updated at `builds/windows/Interior.exe` and `builds/android/Interior.apk`. The APK remains locally debug-signed with ARMv7 and ARM64 support.

## Changes

- Converted 730 standalone 3D texture imports from lossless storage to GPU compression with mipmaps. Source images and desktop texture dimensions are preserved.
- Android export copies use at most 512 pixels per axis for model textures and 1024 for tiled surfaces and generated prop/liquid artwork. Family photo files and UI assets retain their original dimensions. External texture references stay shared across model scenes.
- Mobile Low disables every dynamic shadow and expensive standard-material surface features. High restores authored normal maps. Mesh LOD thresholds and distance limits reduce distant detail while retaining world geometry and collisions.
- Phone 3D resolution has a pixel ceiling: Low 1280×720, Medium 1600×900, High 1920×1080. UI resolution stays native. A wide 2400×1080 screen renders Low 3D at 1280×576.
- Mobile menus use 30 FPS; play restores the 60 FPS target. App focus loss pauses and clears held touch input. Android Back pauses/resumes instead of closing the app.
- Small loose props embedded beneath static clutter are raised onto its receiving surface during setup. This fixes a pail being pushed below the canal terrain. Pickup, drops and throws retain normal physics.
- Corrected room triangle-count metadata after the removed curtain, and freed an auxiliary SceneTree in the siege test.

## Measured desktop comparison

The same Low-quality camera route ran at 1280×720 with Compatibility rendering on an RTX 4060. Frame caps and VSync were disabled. Each steady sample followed at least 90 warmup frames. These results describe this desktop, not an Android phone. Other local work may affect timing; render counts and memory are the stronger comparisons.

| View | Before median | After median | Before draws | After draws |
|---|---:|---:|---:|---:|
| Room | 8.37 ms | 7.00 ms | 1,323 | 741 |
| Street | 12.95 ms | 8.91 ms | 851 | 511 |
| Town | 17.56 ms | 10.35 ms | 1,323 | 700 |
| Canal | 11.96 ms | 8.90 ms | 762 | 626 |
| Warren | 12.59 ms | 7.98 ms | 701 | 410 |
| Fields | 10.51 ms | 5.94 ms | 931 | 452 |
| Nichols exterior | 14.02 ms | 11.11 ms | 924 | 775 |

Reported peak graphics memory fell from 3,179.8 MiB to 1,389.2 MiB (56.3%). Scene setup in these runs fell from 37.9 to 19.1 seconds. This is neither a cold-storage nor a startup-time guarantee. The Android texture budget applies an additional reduction that is absent from this desktop comparison.

Raw reports and screenshots: `baseline/` (first traversal with compilation stalls), `baseline-warm/`, `optimized/` (first optimization pass), and `final/`. `comparison.json` excludes the basement timing comparison because its final camera was corrected to the actual cellar floor. Warmup and first-use stalls remain recorded separately from steady samples; no claim that all stutter is eliminated is made.

## Gameplay checks

`checks/summary.json` records 20 suites. Nineteen pass, including 10,000-step movement and hamster checks, physics, room, tabletop stability, touch/restart/background/Back controls, mobile budgets, balcony, fields, gun, stranger, canal, warren, Nichols, basement, siege and textured props. The new mobile-budget check covers 3,053 assertions and repeated Low/High transitions. The original failure report is retained in `checks/summary-initial.json`.

The full settling suite still fails its strict initial 3 mm drift and wake-all criteria. Several newer loose props and chairs settle or tip from authored poses, and some room items drift by a few millimetres. The falling pail was reproduced independently and fixed; remaining settling failures were not hidden or relaxed. The strict default build script therefore still stops on settling. Explicit exports here follow the recorded QA review rather than claiming that every suite passes.

## Reproduce

Run `tools/mobile-qa.ps1` for the full suite, or pass `-Tests` with the relevant names for a focused rerun. It retains each log and merges refreshed results into the summary.

Run Godot with `--path game --rendering-method gl_compatibility --script res://tests/mobile_performance.gd -- --mobile-test --out=res://../docs/mobile-performance/repeat`. Do not use `--fixed-fps` for performance measurement.

The exported executable also accepts `-- --performance-audit --mobile-test --out=<absolute directory>`. A debug Android APK starts the same audit when `user://performance-audit.json` exists; it consumes that marker once and writes its report and eight screenshots under `user://mobile-performance/`. Create the marker through `adb shell run-as com.aljayleodones.interior` and pull results through the same debug application account. Normal launches do not run the audit.

## Measurement limits

No physical Android phone has been measured. Emulator compatibility, physical-phone FPS, sustained thermal behavior and battery consumption are different checks. Real-device acceptance should include at least a 15-minute route through the town, canal, fields and basement with touch movement, props, flashlight and gun, on representative 2–4 GB and 6–8 GB phones. Capture frame times, memory, temperature and crashes, including background/resume and repeated restarts. A steady 60 FPS target requires 16.67 ms frames; a desktop median alone cannot establish that result.

The Android exporter can emit Godot 4.7.2 getter diagnostics for unused GPUParticles draw-pass properties while recursively customizing resources. Those export diagnostics are recorded in the export log and are separate from runtime validation.

Godot references used for the implementation: [3D resolution scaling](https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html), [export resource customization](https://docs.godotengine.org/en/stable/classes/class_editorexportplugin.html), and [shared resource paths](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource-method-set-path-cache).
