param([string[]]$Tests = @(
    'physics_integration','room_integration','settling','tabletop_stability',
    'movement_stress','hamster_stress','surroundings_integration','upgrade_integration',
    'touch_integration','balcony_integration','fields_integration','gun_integration',
    'stranger_integration','canal_integration','warren_integration','nichols_integration',
    'basement_integration','siege_integration','horror_props_integration','mobile_budget_integration'
))
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$directory = Join-Path $project 'docs/mobile-performance/checks'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$results = $Tests | ForEach-Object -Parallel {
    $test = $_
    $project = $using:project
    $directory = $using:directory
    $godot = Join-Path $project '.local/tools/Godot_v4.7.2-stable_win64_console.exe'
    $args = @('--headless','--fixed-fps','60','--path',(Join-Path $project 'game'),
        '--script',"res://tests/$test.gd",'--quit-after','18000')
    if ($test -in @('touch_integration','mobile_budget_integration')) { $args += @('--','--mobile-test') }
    $begin = Get-Date
    $lines = & $godot @args 2>&1
    $code = $LASTEXITCODE
    $log = $lines | ForEach-Object { "$_" }
    $log | Set-Content -LiteralPath (Join-Path $directory "$test.log") -Encoding utf8
    $reports = @($log | Where-Object { $_ -match '^\w+ \{' })
    $errors = @($log | Where-Object { $_ -match '^(SCRIPT ERROR|ERROR:)' })
    $complete = $reports.Count -gt 0
    $passed = $code -eq 0 -and $complete -and $errors.Count -eq 0
    [pscustomobject]@{ test=$test; passed=$passed; exitCode=$code; completed=$complete;
        seconds=[math]::Round(((Get-Date)-$begin).TotalSeconds,1); reports=$reports; errors=$errors }
} -ThrottleLimit 2
$summaryPath = Join-Path $directory 'summary.json'
$previous = if (Test-Path -LiteralPath $summaryPath) { @(Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json) } else { @() }
$allResults = @($previous | Where-Object { $_.test -notin $Tests }) + @($results)
$allResults | Sort-Object test | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding utf8
$results | Sort-Object test | Select-Object test,passed,exitCode,completed,seconds | Format-Table -AutoSize
if (@($results | Where-Object { -not $_.passed }).Count -gt 0) { exit 1 }
