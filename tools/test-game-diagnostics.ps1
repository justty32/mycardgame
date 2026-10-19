function Get-ExitCodeHex {
    param([AllowNull()]$ExitCode)
    if ($null -eq $ExitCode) { return $null }
    $unsigned = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$ExitCode), 0)
    return ('0x{0:X8}' -f $unsigned)
}

function Get-NativeCrashSignatures {
    param([string]$Text)
    # Exact Godot native-handler lines, not generic mentions of crashes or leaks.
    return @([regex]::Matches($Text,
        '(?m)^(?:CrashHandlerException|handle_crash): Program crashed with signal \d+[^\r\n]*\r?$') |
        ForEach-Object { $_.Value.TrimEnd("`r") } | Select-Object -Unique)
}

function Save-VerificationManifest {
    param([System.Collections.IDictionary]$Manifest, [string]$Path)
    $pending = $Path + '.pending'
    $json = $Manifest | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($pending, $json, [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($pending, $Path, $true)
}

function Confirm-EngineLogWritable {
    param([string]$Path)
    try {
        # Open the exact target without truncating it. This is a preflight, not a
        # guarantee against later permissions changes or failures during rotation.
        $stream = [IO.File]::Open($Path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
        $stream.Dispose()
    }
    catch { throw "Engine log write preflight failed for '$Path': $($_.Exception.Message)" }
}

function Get-GameCheckoutMetadata {
    param([string]$SourceGame, [string]$ProjectRoot)
    # A source lock identifies upstream. Git here describes only the local layout;
    # an outer repository commit must never be reported as the upstream commit.
    $source = [IO.Path]::GetFullPath($SourceGame).TrimEnd([char[]]'\/')
    $outer = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd([char[]]'\/')
    $metadata = [ordered]@{ layout = 'unversioned_source'; repository_root = $null; commit = $null; changes = @() }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $metadata }
    $repository = & git -C $source rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { return $metadata }
    $repository = [IO.Path]::GetFullPath($repository).TrimEnd([char[]]'\/')
    if ($repository -eq $source) {
        $metadata.layout = 'independent_game_checkout'
        $metadata.changes = @(& git -C $source diff --name-only)
    }
    elseif ($repository -eq $outer -and $source -eq (Join-Path $outer 'game')) {
        $metadata.layout = 'outer_repository_snapshot'
        $metadata.changes = @(& git -C $outer diff --name-only -- game)
    }
    else {
        # A preserved artifacts copy can live inside an outer repository while
        # having no relationship to that repository's current game checkout.
        $metadata.layout = 'isolated_source_snapshot'
        return $metadata
    }
    $metadata.repository_root = $repository
    $commit = & git -C $repository rev-parse --verify HEAD 2>$null
    if ($LASTEXITCODE -eq 0) { $metadata.commit = $commit }
    return $metadata
}
