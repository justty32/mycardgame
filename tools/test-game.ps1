#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('All', 'Dictionary', 'Combat', 'SaveLoad', 'Smoke', 'ResourceLifecycle')]
    [string]$Suite = 'All',
    [string]$GodotPath,
    [string]$SourceGame,
    [switch]$HistoricalBaseline,
    [switch]$DiagnosticVerbose,
    [ValidateRange(10, 900)]
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'test-game-diagnostics.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceGame = if ($SourceGame) { (Resolve-Path -LiteralPath $SourceGame).Path } else { Join-Path $projectRoot 'game' }
if (-not $GodotPath) {
    $GodotPath = Join-Path $projectRoot '.tools/godot-4.6/Godot_v4.6-stable_win64_console.exe'
}
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$runRoot = Join-Path $projectRoot "artifacts/verification/$runId"
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-Engine {
    param(
        [string]$Name, [string]$Directory, [string[]]$EngineArgs, [string]$Marker,
        [switch]$ColdImport, [int[]]$KnownShutdownResources = @(), [switch]$SaveRejections,
        [switch]$VersionProbe
    )
    $engineLog = Join-Path $Directory "$Name.log"
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $GodotPath
    $startInfo.WorkingDirectory = $Directory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $arguments = if ($VersionProbe) { $EngineArgs } else { @('--log-file', $engineLog) + $(if ($DiagnosticVerbose) { @('--verbose') } else { @() }) + $EngineArgs }
    foreach ($argument in $arguments) {
        $startInfo.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $started = $false
    $phaseRecord = [ordered]@{
        name = $Name; directory = $Directory; executable = $GodotPath
        launched_pid = $null
        launched_pid_kind = $(if ($GodotPath -match '(?i)(?:_|\.)console\.exe$') { 'console_wrapper' } else { 'invoked_executable' })
        started_utc = $null; ended_utc = $null; status = 'starting'
        exit_code = $null; exit_code_hex = $null; timed_out = $false; passed = $false
        native_crash_signatures = @(); cold_cache_uid_requires_recheck = $false
        log_write_preflight = 'pending'
        shutdown_resources = @(); seconds = 0; command_arguments = @($startInfo.ArgumentList)
    }
    $results.Add($phaseRecord)
    Save-VerificationManifest $manifest (Join-Path $runRoot 'results.json')
    try {
        $phaseRecord.log_write_preflight = 'failed'
        Confirm-EngineLogWritable $engineLog
        $phaseRecord.log_write_preflight = 'passed'
        if (-not $process.Start()) { throw "Cannot start $Name" }
        $started = $true
        $phaseRecord.launched_pid = $process.Id
        $phaseRecord.started_utc = $process.StartTime.ToUniversalTime().ToString('o')
        $phaseRecord.status = 'running'
        Save-VerificationManifest $manifest (Join-Path $runRoot 'results.json')
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        $phaseRecord.timed_out = $timedOut
        if ($timedOut) {
            # This process object belongs to this invocation; never kill by executable name.
            $process.Kill($true)
            if (-not $process.WaitForExit(5000)) { throw "$Name did not exit after timeout termination" }
        }
        # A wrapper can exit while an inherited output handle remains open in a child.
        if (-not [System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]@($stdout, $stderr), 5000)) {
            throw "$Name output streams remained open after launched process exit"
        }
        $output = $stdout.GetAwaiter().GetResult() + "`n" + $stderr.GetAwaiter().GetResult()
        $output | Set-Content -LiteralPath (Join-Path $Directory "$Name.console.log") -Encoding utf8
        $code = $process.ExitCode
        $log = if (Test-Path -LiteralPath $engineLog) { Get-Content -LiteralPath $engineLog -Raw } else { '' }
        $combined = $output + "`n" + $log
        $crashSignatures = @(Get-NativeCrashSignatures $combined)
        $phaseRecord.native_crash_signatures = $crashSignatures
        $passed = -not $timedOut -and $code -eq 0 -and $combined -notmatch 'SCRIPT ERROR:|FAIL:' -and $crashSignatures.Count -eq 0
        if ($Marker) { $passed = $passed -and $combined -match [regex]::Escape($Marker) }
        if ($VersionProbe) {
            $versionMatch = [regex]::Match($combined, '(?m)^4\.6\.[^\r\n]+')
            $phaseRecord.engine_version = $versionMatch.Value
            $passed = $passed -and $versionMatch.Success
        }
        $errors = @($combined -split '\r?\n' | Where-Object { $_ -match '^ERROR:' })
        $shutdownCounts = @([regex]::Matches($combined, '(?m)^ERROR: (\d+) resources still in use at exit') |
            ForEach-Object { [int]$_.Groups[1].Value } | Select-Object -Unique)
        foreach ($count in $shutdownCounts) {
            if ($KnownShutdownResources -contains $count) {
                $errors = @($errors | Where-Object { $_ -notmatch "^ERROR: $count resources still in use at exit" })
                Write-Warning "$Name retains $count resources at shutdown; tracked issue, not a clean resource-lifetime result."
            }
        }
        if ($SaveRejections) {
            # Canonical engine log preserves stdout/stderr order, unlike the separate console streams.
            $cases = @('missing', 'malformed', 'array', 'scalar', 'null', 'no_properties',
                'array_properties', 'empty_properties', 'array_patch_metadata', 'unknown_character')
            $blocks = [regex]::Matches($log, '(?ms)^EXPECTED SAVE REJECTION BEGIN: (\w+)\r?\n(.*?)^EXPECTED SAVE REJECTION END: \1\r?$')
            $validBlocks = $blocks.Count -eq $cases.Count
            foreach ($caseName in $cases) {
                $matching = @($blocks | Where-Object { $_.Groups[1].Value -eq $caseName })
                $validBlocks = $validBlocks -and $matching.Count -eq 1
                if ($matching.Count -eq 1) {
                    $validBlocks = $validBlocks -and [regex]::Matches($matching[0].Groups[2].Value,
                        '(?m)^ERROR: FileLoader\.load_game\(\): Save rejected ').Count -eq 1
                }
            }
            $validBlocks = $validBlocks -and [regex]::Matches($log,
                '(?m)^ERROR: FileLoader\.load_game\(\): Save rejected ').Count -eq $cases.Count
            if ($validBlocks) {
                $errors = @($errors | Where-Object { $_ -notmatch '^ERROR: FileLoader\.load_game\(\): Save rejected ' })
            }
            else { $passed = $false }
        }
        $coldCacheUid = $false
        if ($ColdImport) {
            # This exact SoundManager UID is present in its .gd.uid but not yet in a fresh cache.
            $coldCacheUid = @($errors | Where-Object { $_ -eq 'ERROR: Unrecognized UID: "uid://bjkhgdroa1wwd".' }).Count -gt 0
            $errors = @($errors | Where-Object { $_ -ne 'ERROR: Unrecognized UID: "uid://bjkhgdroa1wwd".' })
        }
        $passed = $passed -and $errors.Count -eq 0
        if (-not $HistoricalBaseline -and $combined -match 'ObjectDB instances leaked at exit') { $passed = $false }
        $phaseRecord.passed = $passed
        $phaseRecord.status = if ($passed) { 'passed' } else { 'failed' }
        $phaseRecord.cold_cache_uid_requires_recheck = $coldCacheUid
        $phaseRecord.shutdown_resources = $shutdownCounts
        Write-Host "$Name : exit=$code, passed=$passed ($([math]::Round($timer.Elapsed.TotalSeconds, 1))s)"
        if (-not $passed) { throw "$Name failed. Inspect $engineLog and $Name.console.log" }
    }
    catch {
        $phaseRecord.status = 'failed'
        $phaseRecord.error = $_.Exception.Message
        throw
    }
    finally {
        if ($started -and -not $process.HasExited) {
            $process.Kill($true)
            [void]$process.WaitForExit(5000)
        }
        if ($started -and $process.HasExited) {
            $phaseRecord.exit_code = $process.ExitCode
            $phaseRecord.exit_code_hex = Get-ExitCodeHex $process.ExitCode
        }
        $phaseRecord.ended_utc = [DateTime]::UtcNow.ToString('o')
        $phaseRecord.seconds = [math]::Round($timer.Elapsed.TotalSeconds, 2)
        Save-VerificationManifest $manifest (Join-Path $runRoot 'results.json')
        $process.Dispose()
    }
}

function Copy-IsolatedGame {
    param([string]$Destination)
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    # Unique destination, no /MIR or delete. Exclude real user data before autoload ready.
    $copyArguments = @(
        $sourceGame, $Destination, '/E', '/R:0', '/W:0', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/XJ',
        '/XD', '.git', '.godot', '.import', '.saves', '.screenshots', (Join-Path $sourceGame 'external/saves'),
        '/XF', 'profile.json', 'user_settings.json'
    )
    & robocopy @copyArguments | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Isolated copy failed: robocopy exit $LASTEXITCODE" }
    if (Test-Path -LiteralPath (Join-Path $Destination 'external/saves/save.json')) {
        throw 'Isolation failed: existing save was copied.'
    }
    # Give each test its own user:// too; source project.godot remains untouched.
    $projectFile = Join-Path $Destination 'project.godot'
    $projectText = Get-Content -LiteralPath $projectFile -Raw
    $projectText = $projectText -replace '(?m)^config/use_custom_user_dir=.*\r?\n', ''
    $projectText = $projectText -replace '(?m)^config/custom_user_dir_name=.*\r?\n', ''
    $isolatedName = 'mycardgame-tests/' + $runId + '/' + (Split-Path (Split-Path $Destination -Parent) -Leaf)
    $userDirectory = Join-Path $env:APPDATA $isolatedName
    New-Item -ItemType Directory -Path $userDirectory -Force | Out-Null
    Confirm-EngineLogWritable (Join-Path $userDirectory 'write-preflight.txt')
    $projectText = $projectText -replace '\[application\]', "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$isolatedName`""
    $projectText | Set-Content -LiteralPath $projectFile -Encoding utf8
}

$sourceLock = Get-Content -LiteralPath (Join-Path $projectRoot 'tools/upstream.json') -Raw | ConvertFrom-Json
$checkoutMetadata = Get-GameCheckoutMetadata -SourceGame $sourceGame -ProjectRoot $projectRoot
$manifest = [ordered]@{
    suite = $Suite; run_id = $runId; source_game = $sourceGame
    upstream_commit = $sourceLock.commit
    source_lock_sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot 'tools/upstream.json')).Hash
    checkout = $checkoutMetadata
    historical_baseline = [bool]$HistoricalBaseline
    source_hashes = @{}; test_hashes = @{}
    engine = $GodotPath; completed = $false; results = $results
}
try {
    Save-VerificationManifest $manifest (Join-Path $runRoot 'results.json')
    Invoke-Engine -Name 'version' -Directory $runRoot -EngineArgs @('--headless', '--log-file', (Join-Path $runRoot 'version.log'), '--version') -VersionProbe
    $manifest.engine_version = $results[$results.Count - 1].engine_version
    $manifest.source_changes = $checkoutMetadata.changes
    $suites = if ($Suite -eq 'All') { @('ResourceLifecycle', 'Dictionary', 'Smoke', 'CombatVictory', 'CombatDefeat', 'SaveLoad') }
        elseif ($Suite -eq 'Combat') { @('CombatVictory', 'CombatDefeat') } else { @($Suite) }
    foreach ($selected in $suites) {
        $directory = Join-Path $runRoot $selected
        $isolatedGame = Join-Path $directory 'game'
        Copy-IsolatedGame -Destination $isolatedGame
        $hashPaths = @('scripts/action_interceptors/ActionInterceptorProcessor.gd', 'scripts/actions/BaseAsyncAction.gd', 'autoload/ActionHandler.gd', 'scripts/Root.gd', 'scripts/ui/menus/BaseMenu.gd', 'scripts/actions/card_actions/pick_card_actions/ActionBasePickCards.gd', 'scripts/actions/card_actions/pick_card_actions/ActionPickCards.gd', 'scripts/actions/card_actions/pick_card_actions/ActionPickDuplicateCards.gd', 'scripts/actions/card_actions/pick_card_actions/ActionPickUpgradeCards.gd', 'scripts/actions/card_actions/pick_card_actions/ActionCreateCards.gd', 'scripts/ui/Map.gd', 'autoload/FileLoader.gd', 'data/SerializableData.gd')
        $manifest.source_hashes[$selected] = @($hashPaths | ForEach-Object { $file = Join-Path $isolatedGame $_; if (-not (Test-Path -LiteralPath $file)) { throw "Missing source hash target: $file" }; @{ path = $_; sha256 = (Get-FileHash -LiteralPath $file).Hash } })
        $isolatedTests = Join-Path $directory 'tests'
        New-Item -ItemType Directory -Path $isolatedTests -Force | Out-Null
        Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests') -Filter '*.gd' | Copy-Item -Destination $isolatedTests
        $manifest.test_hashes[$selected] = @(Get-ChildItem -LiteralPath $isolatedTests -Filter '*.gd' | ForEach-Object { @{ path = $_.Name; sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash } })
        $importArguments = @('--headless', '--path', $isolatedGame, '--editor', '--import')
        Invoke-Engine -Name 'import' -Directory $directory -EngineArgs $importArguments -ColdImport -KnownShutdownResources $(if ($HistoricalBaseline) { @(1) } else { @() })
        if ($results[$results.Count - 1].cold_cache_uid_requires_recheck) {
            Invoke-Engine -Name 'import-verified' -Directory $directory -EngineArgs $importArguments -KnownShutdownResources $(if ($HistoricalBaseline) { @(1) } else { @() })
        }
        $scriptName = switch ($selected) {
            'ResourceLifecycle' { 'resource_lifecycle.gd' }
            'Dictionary' { 'dictionary_regression.gd' }
            'Smoke' { 'framework_smoke.gd' }
            'CombatVictory' { 'combat_flow.gd' }
            'CombatDefeat' { 'combat_flow.gd' }
            'SaveLoad' { 'save_load_flow.gd' }
        }
        $scriptPath = Join-Path $isolatedTests $scriptName
        $testArguments = @('--headless', '--path', $isolatedGame, '--script', $scriptPath)
        if ($selected -eq 'CombatVictory') { $testArguments += @('--', '--scenario=victory') }
        if ($selected -eq 'CombatDefeat') { $testArguments += @('--', '--scenario=defeat') }
        if ($selected -eq 'SaveLoad') {
            foreach ($phase in @('write', 'read', 'rejected')) {
                $knownCounts = @()
                Invoke-Engine -Name "save-$phase" -Directory $directory -EngineArgs ($testArguments + @('--', "--phase=$phase", "--source-game-path=$sourceGame")) -Marker 'SAVELOAD PASS:' -KnownShutdownResources $knownCounts -SaveRejections:($phase -eq 'rejected')
            }
        }
        else {
            $knownCounts = @()
            $marker = if ($selected -eq 'ResourceLifecycle') { 'RESOURCE PASS:' } elseif ($selected.StartsWith('Combat')) { 'COMBAT PASS:' } else { "$($selected.ToUpperInvariant()) PASS:" }
            Invoke-Engine -Name $selected.ToLowerInvariant() -Directory $directory -EngineArgs $testArguments -Marker $marker -KnownShutdownResources $knownCounts
        }
    }
    $manifest.completed = $true
    $manifest.known_shutdown_issues = @($results | Where-Object { $_.shutdown_resources.Count -gt 0 }).Count -gt 0
    $manifest.verdict = if ($manifest.known_shutdown_issues) { 'PASS_WITH_KNOWN_SHUTDOWN_ISSUES' } else { 'PASS' }
    Write-Host "VERIFICATION $($manifest.verdict): $runRoot"
}
catch {
    $manifest.error = $_.Exception.Message
    throw
}
finally {
    Save-VerificationManifest $manifest (Join-Path $runRoot 'results.json')
    Write-Host "Evidence: $runRoot"
}
