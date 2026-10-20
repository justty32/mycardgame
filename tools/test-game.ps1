#requires -Version 7.0
<#
.SYNOPSIS
Thin PowerShell wrapper around tools/test_game.py (the cross-platform runner).

.DESCRIPTION
Parameter names are kept from the previous PowerShell runner so existing commands
and documentation keep working on Windows. All pass/fail rules live in
tools/test_game.py; this file only maps parameters and forwards the exit code.
Requires Python 3.10+ on PATH (python, py -3 or python3). Never opens a window.

.EXAMPLE
./tools/test-game.ps1 -Suite All
./tools/test-game.ps1 -Suite Smoke -GodotPath 'C:/path/to/Godot_v4.7.2-stable_win64_console.exe'
./tools/test-game.ps1 -Suite Smoke -ForceFailure   # must exit 1
./tools/test-game.ps1 -Suite Smoke -ContentProfile pack -Pack games/<game>/pack -PackTests games/<game>/tests
#>
[CmdletBinding()]
param(
    [ValidateSet('All', 'Dictionary', 'Combat', 'SaveLoad', 'Smoke', 'ResourceLifecycle', 'CombatVictory', 'CombatDefeat', 'Ctb', 'Board', 'Wave')]
    [string]$Suite = 'All',
    [string]$GodotPath,
    [string]$SourceGame,
    [switch]$HistoricalBaseline,
    [switch]$DiagnosticVerbose,
    [switch]$ForceFailure,
    [switch]$NoIsolateAppData,
    [string[]]$AcceptEngineVersion,
    [string[]]$Pack,
    [string[]]$PackTests,
    [ValidateSet('test', 'pack')]
    [string]$ContentProfile,
    [string]$ArtifactsRoot,
    [ValidateRange(10, 900)]
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'test_game.py'
if (-not (Test-Path -LiteralPath $runner)) { throw "Missing runner: $runner" }

# Resolve a Python 3.10+ interpreter without triggering the Windows Store alias.
$pythonExe = $null
$pythonArgs = @()
foreach ($candidate in @(@{ Name = 'python'; Args = @() }, @{ Name = 'py'; Args = @('-3') }, @{ Name = 'python3'; Args = @() })) {
    $command = Get-Command $candidate.Name -ErrorAction SilentlyContinue
    if (-not $command) { continue }
    if ($command.Source -match '(?i)\\WindowsApps\\python') { continue }
    $probe = & $command.Source @($candidate.Args) -c 'import sys; print(sys.version_info >= (3, 10))' 2>$null
    if ($LASTEXITCODE -eq 0 -and "$probe".Trim() -eq 'True') { $pythonExe = $command.Source; $pythonArgs = @($candidate.Args); break }
}
if (-not $pythonExe) { throw 'Python 3.10+ not found (tried python, py -3, python3). Install is not performed by this wrapper.' }

$arguments = @($runner, '--suite', $Suite, '--timeout-seconds', $TimeoutSeconds)
if ($GodotPath) { $arguments += @('--godot-path', $GodotPath) }
if ($SourceGame) { $arguments += @('--source-game', $SourceGame) }
if ($HistoricalBaseline) { $arguments += '--historical-baseline' }
if ($DiagnosticVerbose) { $arguments += '--diagnostic-verbose' }
if ($ForceFailure) { $arguments += '--force-failure' }
if ($NoIsolateAppData) { $arguments += '--no-isolate-appdata' }
if ($ArtifactsRoot) { $arguments += @('--artifacts-root', $ArtifactsRoot) }
# -Pack/-PackTests/-ContentProfile map to --pack/--pack-tests/--content-profile. Verified on Windows 2026-10-20.
foreach ($dir in @($Pack)) { if ($dir) { $arguments += @('--pack', $dir) } }
foreach ($dir in @($PackTests)) { if ($dir) { $arguments += @('--pack-tests', $dir) } }
if ($ContentProfile) { $arguments += @('--content-profile', $ContentProfile) }
foreach ($pattern in @($AcceptEngineVersion)) { if ($pattern) { $arguments += @('--accept-engine-version', $pattern) } }

& $pythonExe @pythonArgs @arguments
exit $LASTEXITCODE
