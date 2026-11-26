# Neighborhood review

The review compares the unchanged neighborhood with the abandoned-town update at the same six cameras, 1600 × 900 pixels, High quality, Forward+ renderer and a fixed random seed. The close views include wall bases, pavement and asphalt; the overview checks variation across the neighborhood. No image retouching is used.

Baseline captures are in `work/v13/baseline`. The camera definitions and capture implementation are in `game/tests/neighborhood_review.gd`. Each run writes six PNGs and a `review.json` with camera coordinates, render resolution, quality, render scale and short frame-time/draw-call samples. These samples include presentation and vsync; they do not establish a performance guarantee. Fog, grain, foliage and light animations retain their runtime behavior, so their pixel phases can differ.

Use the bundled Godot 4.7.2 console executable at `.local/tools/Godot_v4.7.2-stable_win64_console.exe`. A native renderer is required for screenshots. PowerShell example, from the repository root:

```powershell
$reviewOut = Join-Path (Get-Location) 'work/v13/final'
New-Item -ItemType Directory -Path $reviewOut -Force | Out-Null
$reviewGame = Join-Path (Get-Location) 'game'
$reviewEngine = Join-Path (Get-Location) '.local/tools/Godot_v4.7.2-stable_win64_console.exe'
$reviewArgs = @('--path', ('"' + $reviewGame + '"'), '--script', 'res://tests/neighborhood_review.gd', '--', ('"--out=' + $reviewOut + '"'), '--size=1600x900', '--quality=2')
$reviewProcess = Start-Process -FilePath $reviewEngine -ArgumentList $reviewArgs -WindowStyle Hidden -RedirectStandardOutput "$reviewOut/stdout.log" -RedirectStandardError "$reviewOut/stderr.log" -PassThru
```

Wait for `NEIGHBORHOOD_REVIEW_COMPLETE 6` in the stdout log and check the stderr log. Capture 1920 × 1080 by changing `--size`; keep both comparison runs at the same size. To inspect Compatibility, add `--rendering-method gl_compatibility` before `--` and write to a separate output directory. Do not run competing native captures concurrently.

Inspect each pair at full resolution for material scale, believable irregular weathering, wall and road crack depth, gutter dirt and plant placement, silhouette variety, light and shadow continuity, and readable route geometry. Check that patches sit on the surface without floating, z-fighting, repeated straight edges, obviously mirrored patterns, excessively uniform damage or flat unlit colors. The overview should have detail variation without a uniform noise coating.

The integration test `game/tests/neighborhood_decay_integration.gd` audits emitted triangle geometry rather than trusting generator counters: finite vertices/normals, Godot clockwise winding, zero-area triangles, outdoor light layers and street-camera-facing geometry. It also checks actual shader use, collision support, real-player lane/street traversal, the fields exit and indoor hiding. Camera-frustum checks establish candidate visibility; the rendered PNG review is required to assess occlusion and final appearance.

```powershell
& '.local/tools/Godot_v4.7.2-stable_win64_console.exe' --headless --fixed-fps 60 --path game --script res://tests/neighborhood_decay_integration.gd
```

Existing street, atmosphere and balcony integration tests should also be run when changes affect shared runtime behavior. Preserve the existing main-room, story and field layout.
