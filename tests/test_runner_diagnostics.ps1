#requires -Version 7.0
# Does not execute Godot. Extract the real runner function and use hidden pwsh fixtures.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $projectRoot 'tools/test-game-diagnostics.ps1')
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $projectRoot 'tools/test-game.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$function = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-Engine' }, $true)
. ([scriptblock]::Create($function.Extent.Text))
$runRoot = Join-Path $projectRoot ('artifacts/runner-diagnostics/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$results = [Collections.Generic.List[object]]::new()
$manifest = [ordered]@{ completed = $false; results = $results; note = 'Synthetic diagnostics only; no Godot executed.' }
$GodotPath = (Get-Command pwsh).Source
$TimeoutSeconds = 10
$checks = 0

function Assert-That([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERT FAIL: $Message" }
    $script:checks++
    Write-Host "PASS: $Message"
}

function Invoke-Fixture([string]$Name, [string]$Body, [bool]$ExpectedPass) {
    $fixture = Join-Path $runRoot "$Name.ps1"
    # Confirm running evidence is already durable while the child is alive.
    $prefix = @'
$deadline = [DateTime]::UtcNow.AddSeconds(2)
$observed = $false
do {
    $saved = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'results.json') -Raw | ConvertFrom-Json
    $last = @($saved.results)[-1]
    $observed = $last.status -eq 'running' -and $last.launched_pid -eq $PID
    if (-not $observed) { Start-Sleep -Milliseconds 10 }
} while (-not $observed -and [DateTime]::UtcNow -lt $deadline)
if (-not $observed) { Write-Output 'FAIL: missing running evidence'; exit 3 }
Write-Output '4.6.synthetic'
'@
    ($prefix + "`n" + $Body) | Set-Content -LiteralPath $fixture -Encoding utf8
    $caught = $false
    try {
        Invoke-Engine -Name $Name -Directory $runRoot -EngineArgs @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $fixture) -VersionProbe -Marker 'SYNTHETIC PASS:'
    }
    catch { $caught = $true }
    $row = $results[$results.Count - 1]
    Assert-That ($row.passed -eq $ExpectedPass -and $caught -eq (-not $ExpectedPass)) "$Name verdict and exception agree"
    Assert-That ($row.launched_pid -gt 0 -and $row.launched_pid_kind -eq 'invoked_executable') "$Name records launched PID without claiming child engine identity"
    Assert-That ($row.started_utc.EndsWith('Z') -and $row.ended_utc.EndsWith('Z')) "$Name records UTC start/end"
    $durable = Get-Content -LiteralPath (Join-Path $runRoot 'results.json') -Raw | ConvertFrom-Json
    Assert-That (@($durable.results)[-1].status -eq $row.status -and -not $durable.completed) "$Name result durable before whole run completion"
}

Assert-That ((Get-ExitCodeHex -1073741819) -eq '0xC0000005') 'signed access-violation status preserves all 32 bits'
Assert-That ((Get-ExitCodeHex 0) -eq '0x00000000') 'zero exit code formatting'
Assert-That ($null -eq (Get-ExitCodeHex $null)) 'unobserved exit is not converted to success'
Assert-That (@(Get-NativeCrashSignatures 'NOTE: CrashHandlerException is a handler; ObjectDB instances leaked').Count -eq 0) 'generic crash mention and leak are not native crash signatures'
Assert-That (@(Get-NativeCrashSignatures "handle_crash: Program crashed with signal 11`n").Count -eq 1) 'native Unix-style handler signature recognized'
$preflightPath = Join-Path $runRoot 'preflight-existing.log'
[IO.File]::WriteAllText($preflightPath, 'existing evidence')
Confirm-EngineLogWritable $preflightPath
Assert-That ([IO.File]::ReadAllText($preflightPath) -eq 'existing evidence') 'log preflight opens exact target without truncating evidence'
New-Item -ItemType Directory -Path (Join-Path $runRoot 'blocked-log.log') | Out-Null
$blockedCaught = $false
try { Invoke-Engine -Name 'blocked-log' -Directory $runRoot -EngineArgs @('--version') } catch { $blockedCaught = $true }
$blocked = $results[$results.Count - 1]
Assert-That ($blockedCaught -and $blocked.log_write_preflight -eq 'failed' -and $null -eq $blocked.launched_pid -and $blocked.error.Contains('blocked-log.log')) 'unwritable log target fails before any process starts with path-specific evidence'
Invoke-Fixture 'normal' "Write-Output 'SYNTHETIC PASS:'; exit 0" $true
Invoke-Fixture 'native-text' "Write-Output 'SYNTHETIC PASS:'; Write-Output 'CrashHandlerException: Program crashed with signal 11'; exit 0" $false
Assert-That ($results[$results.Count - 1].exit_code_hex -eq '0x00000000' -and $results[$results.Count - 1].native_crash_signatures.Count -eq 1) 'native marker overrides successful exit and PASS text'
Invoke-Fixture 'nonzero' "Write-Output 'SYNTHETIC PASS:'; exit 7" $false
Assert-That ($results[$results.Count - 1].exit_code_hex -eq '0x00000007') 'ordinary failure exit retains hexadecimal evidence'
Invoke-Fixture 'missing-marker' 'exit 0' $false
Invoke-Fixture 'resource-leak' "Write-Output 'SYNTHETIC PASS:'; Write-Output 'ERROR: 1 resources still in use at exit'; exit 0" $false
Invoke-Fixture 'object-leak' "Write-Output 'SYNTHETIC PASS:'; Write-Output 'WARNING: ObjectDB instances leaked at exit'; exit 0" $false
$TimeoutSeconds = 1
Invoke-Fixture 'timeout' "Write-Output 'SYNTHETIC PASS:'; Start-Sleep -Seconds 30" $false
Assert-That ($results[$results.Count - 1].timed_out) 'timeout remains failure even with prior PASS text'
$GodotPath = Join-Path $runRoot 'missing-engine.exe'
try { Invoke-Engine -Name 'start-failure' -Directory $runRoot -EngineArgs @('--version') -VersionProbe } catch { }
$last = $results[$results.Count - 1]
Assert-That ($last.status -eq 'failed' -and $null -eq $last.launched_pid -and $null -eq $last.exit_code_hex) 'start failure is durable with no invented PID or exit'
Assert-That ($function.Extent.Text.Contains('$startInfo.CreateNoWindow = $true')) 'real fixture process launcher disables new windows'
# Model Git's two supported layouts without creating commits or touching a repo.
$fakeSource = Join-Path $projectRoot 'game'
$fakeRepository = $fakeSource
function git {
    $global:LASTEXITCODE = 0
    if ($args -contains '--show-toplevel') { return $script:fakeRepository }
    if ($args -contains '--verify') { return 'test-checkout-commit' }
    if ($args -contains 'diff') { return 'test-modified-path' }
    throw 'Unexpected synthetic Git command'
}
try {
    $checkout = Get-GameCheckoutMetadata -SourceGame $fakeSource -ProjectRoot $projectRoot
    Assert-That ($checkout.layout -eq 'independent_game_checkout' -and $checkout.commit -eq 'test-checkout-commit') 'independent game Git layout records a separate checkout identity'
    $fakeRepository = $projectRoot
    $checkout = Get-GameCheckoutMetadata -SourceGame $fakeSource -ProjectRoot $projectRoot
    Assert-That ($checkout.layout -eq 'outer_repository_snapshot' -and $checkout.commit -eq 'test-checkout-commit') 'outer snapshot layout labels its commit as outer checkout metadata'
    $checkout = Get-GameCheckoutMetadata -SourceGame (Join-Path $runRoot 'game') -ProjectRoot $projectRoot
    Assert-That ($checkout.layout -eq 'isolated_source_snapshot' -and $null -eq $checkout.commit) 'artifacts copy does not inherit outer checkout commit identity'
    Assert-That ($ast.Extent.Text.Contains('upstream_commit = $sourceLock.commit')) 'upstream identity is always read from the source lock'
}
finally { Remove-Item Function:git }
$manifest.completed = $true
$manifest.checks = $checks
Save-VerificationManifest $manifest (Join-Path $runRoot 'results.json')
Write-Host "RUNNER DIAGNOSTICS PASS: $checks checks; evidence $runRoot"
