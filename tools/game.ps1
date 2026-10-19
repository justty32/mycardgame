[CmdletBinding()]
param(
    [ValidateSet('Run', 'Import', 'Smoke')]
    [string]$Mode = 'Run',
    [string]$GodotPath,
    [switch]$ForceFailure
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = Join-Path $projectRoot '.tools/godot-4.6/Godot_v4.6-stable_win64_console.exe'
}
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$gamePath = Join-Path $projectRoot 'game'
if (-not (Test-Path -LiteralPath (Join-Path $gamePath 'project.godot'))) {
    throw 'Missing game/project.godot. See wf/workflows/dev-env.md.'
}
$logDirectory = Join-Path $projectRoot 'artifacts/startup'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$godotVersion = & $GodotPath --version
if ($LASTEXITCODE -ne 0 -or $godotVersion -notmatch '^4\.6\.') {
    throw "Expected Godot 4.6; received: $godotVersion"
}
$engineArguments = @('--path', $gamePath, '--log-file', (Join-Path $logDirectory "$($Mode.ToLowerInvariant()).log"))
switch ($Mode) {
    'Import' { $engineArguments += @('--headless', '--editor', '--import') }
    'Smoke' {
        if (-not (Test-Path -LiteralPath (Join-Path $gamePath '.godot/global_script_class_cache.cfg'))) {
            throw 'Run -Mode Import before -Mode Smoke.'
        }
        $engineArguments += @('--headless', '--script', (Join-Path $projectRoot 'tests/framework_smoke.gd'))
        if ($ForceFailure) { $engineArguments += @('--', '--force-failure') }
    }
}
& $GodotPath @engineArguments
$gameExitCode = $LASTEXITCODE
if ($Mode -eq 'Smoke' -and $gameExitCode -eq 0) {
    $smokeLog = Get-Content -LiteralPath (Join-Path $logDirectory 'smoke.log') -Raw
    if ($smokeLog -notmatch 'SMOKE PASS:' -or $smokeLog -match 'SCRIPT ERROR:|FAIL:') {
        throw 'Smoke did not produce a clean PASS marker; inspect artifacts/startup/smoke.log.'
    }
}
exit $gameExitCode
