param(
    [string]$GodotPath,
    [switch]$TestsOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = Join-Path $projectRoot '.local\tools\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath pointing to Godot 4.7.2.' }
$gamePath = Join-Path $projectRoot 'game'
& $GodotPath --headless --path $gamePath --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
$testReports = @{}
foreach ($test in @('physics_integration','room_integration','settling')) {
    $testOutput = & $GodotPath --headless --fixed-fps 60 --path $gamePath --script "res://tests/$test.gd" --quit-after 600 2>&1
    $testOutput | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "$test failed" }
    $marker = @{physics_integration='INTERIOR_INTEGRATION ';room_integration='INTERIOR_ROOM_INTEGRATION ';settling='INTERIOR_SETTLING '}[$test]
    $reportLine = $testOutput | Where-Object { "$_".StartsWith($marker) } | Select-Object -Last 1
    if (-not $reportLine) { throw "$test did not complete; inspect Godot diagnostics" }
    $report = "$reportLine".Substring($marker.Length) | ConvertFrom-Json
    if (-not $report.passed) { throw "$test reported failures" }
    $testReports[$test] = $report
}
$testReports | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $projectRoot 'room\runtime\integration-results.json') -Encoding utf8
if ($TestsOnly) { exit 0 }
# Human gate records are checked before any final game build.
$review = Get-Content -LiteralPath (Join-Path $projectRoot 'room\milestone-reviews.json') -Raw | ConvertFrom-Json
if ($review.function.status -ne 'approved' -or $review.form.status -ne 'approved') {
    throw 'Final builds require recorded Function and Form approvals.'
}
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'builds\windows'),(Join-Path $projectRoot 'builds\android') -Force | Out-Null
& $GodotPath --headless --path $gamePath --export-release 'Windows Desktop' (Join-Path $projectRoot 'builds\windows\Interior.exe')
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed' }
& $GodotPath --headless --path $gamePath --export-debug 'Android' (Join-Path $projectRoot 'builds\android\Interior.apk')
if ($LASTEXITCODE -ne 0) { throw 'Android export failed' }
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'builds') -File -Recurse | Get-FileHash -Algorithm SHA256
