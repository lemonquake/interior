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
foreach ($test in @('physics_integration','room_integration','settling','tabletop_stability','movement_stress','hamster_stress','surroundings_integration','upgrade_integration','touch_integration')) {
    $stepBudget = if ($test -like '*stress' -or $test -eq 'tabletop_stability') { 16000 } else { 1200 }
    $testArguments = @('--headless','--fixed-fps','60','--path',$gamePath,'--script',"res://tests/$test.gd",'--quit-after',"$stepBudget")
    if ($test -eq 'touch_integration') { $testArguments += @('--','--mobile-test') }
    $testOutput = & $GodotPath @testArguments 2>&1
    $testOutput | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "$test failed" }
    $marker = @{physics_integration='INTERIOR_INTEGRATION ';room_integration='INTERIOR_ROOM_INTEGRATION ';settling='INTERIOR_SETTLING ';tabletop_stability='INTERIOR_TABLETOP_STABILITY ';movement_stress='INTERIOR_MOVEMENT_STRESS ';hamster_stress='INTERIOR_HAMSTER_STRESS ';surroundings_integration='INTERIOR_SURROUNDINGS_INTEGRATION ';upgrade_integration='INTERIOR_UPGRADE_INTEGRATION ';touch_integration='INTERIOR_TOUCH_INTEGRATION '}[$test]
    $reportLine = $testOutput | Where-Object { "$_".StartsWith($marker) } | Select-Object -Last 1
    if (-not $reportLine) { throw "$test did not complete; inspect Godot diagnostics" }
    $report = "$reportLine".Substring($marker.Length) | ConvertFrom-Json
    if (-not $report.passed) { throw "$test reported failures" }
    $testReports[$test] = $report
}
$testReports | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $projectRoot 'room\runtime\integration-results.json') -Encoding utf8
if ($TestsOnly) { exit 0 }
# Automated checks above verify this revision. Historical layout reviews remain
# historical records; the current owner request authorizes these native builds.
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'builds\windows'),(Join-Path $projectRoot 'builds\android') -Force | Out-Null
& $GodotPath --headless --path $gamePath --export-release 'Windows Desktop' (Join-Path $projectRoot 'builds\windows\Interior.exe')
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed' }
& $GodotPath --headless --path $gamePath --export-debug 'Android' (Join-Path $projectRoot 'builds\android\Interior.apk')
if ($LASTEXITCODE -ne 0) { throw 'Android export failed' }
$windowsPath = Join-Path $projectRoot 'builds\windows'
Copy-Item -LiteralPath (Join-Path $gamePath 'licenses\ASSET_LICENSES.md'),(Join-Path $gamePath 'licenses\GODOT_COPYRIGHT.txt') -Destination $windowsPath -Force
@'
Interior 0.2 by Aljay Leodones

Run Interior.exe. WASD moves, mouse looks, Shift sprints, Space jumps, C crouches.
E holds/drops; left click throws; F inspects; J opens notes; Esc pauses.
Choose Low, Medium or High graphics in the menu. Restart restores the room.

See ASSET_LICENSES.md and GODOT_COPYRIGHT.txt for asset and engine notices.
'@ | Set-Content -LiteralPath (Join-Path $windowsPath 'README.txt') -Encoding utf8
$zipPath = Join-Path $projectRoot 'builds\Interior-Windows-x64.zip'
Compress-Archive -Path (Join-Path $windowsPath '*') -DestinationPath $zipPath -Force
$artifacts = @((Join-Path $windowsPath 'Interior.exe'),(Join-Path $projectRoot 'builds\android\Interior.apk'),$zipPath)
$hashLines = foreach ($artifact in $artifacts) { '{0}  {1}' -f (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant(),(Split-Path -Leaf $artifact) }
$hashLines | Set-Content -LiteralPath (Join-Path $projectRoot 'builds\SHA256SUMS.txt') -Encoding ascii
$hashLines | ForEach-Object { Write-Host $_ }
