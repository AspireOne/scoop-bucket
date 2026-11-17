$ErrorActionPreference = 'Stop'

$directory = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory $directory | Out-Null
$metadataState = @{ Release = $null }

# Control GitHub metadata; these cases must finish before Scoop edits a file.
function gh {
    param($Command, $Endpoint)
    if ($null -eq $metadataState.Release) {
        $global:LASTEXITCODE = 1
        return
    }
    $global:LASTEXITCODE = 0
    $metadataState.Release | ConvertTo-Json
}

try {
    $path = Join-Path $directory 'codex-manage.json'
    $manifest = Get-Content -Raw "$PSScriptRoot/../../bucket/codex-manage.json" | ConvertFrom-Json
    $manifest.version = '1.0.0'
    $manifest | ConvertTo-Json -Depth 10 | Set-Content $path
    $before = Get-Content -Raw $path

    $cases = @(
        @{ App = 'codex-manage'; Version = 'v1.0.0'; Error = $null },
        @{ App = 'codex-manage'; Version = 'v0.9.9'; Error = 'Refusing to downgrade' },
        @{ App = 'codex-manage'; Version = 'v1.0.1-rc.1'; Error = 'Expected a stable release tag' },
        @{ App = '../codex-manage'; Version = 'v1.0.0'; Error = 'Invalid app name' },
        @{ App = 'unknown'; Version = 'v1.0.0'; Error = 'Unknown app' },
        @{ App = 'codex-manage'; Version = 'v1.0.1'; Draft = $true; Error = 'must be published and stable' },
        @{ App = 'codex-manage'; Version = 'v1.0.1'; Prerelease = $true; Error = 'must be published and stable' },
        @{ App = 'codex-manage'; Version = 'v1.0.1'; Missing = $true; Error = 'Could not find published release' }
    )

    foreach ($case in $cases) {
        $metadataState.Release = if ($case.Missing) {
            $null
        } else {
            @{ tag_name = $case.Version; draft = [bool]$case.Draft; prerelease = [bool]$case.Prerelease }
        }
        $failure = $null
        try {
            & "$PSScriptRoot/../update-manifest.ps1" -App $case.App -Version $case.Version -Directory $directory
        } catch {
            $failure = $_
        }

        if ([bool]$failure -ne [bool]$case.Error -or ($failure -and -not $failure.Exception.Message.Contains($case.Error))) {
            throw "$($case.App) $($case.Version): expected '$($case.Error)', got '$failure'."
        }
        if ((Get-Content -Raw $path) -cne $before) {
            throw "Rejected or duplicate request modified the manifest: $($case.Version)"
        }
        Write-Host "PASS: $($case.App) $($case.Version) draft=$($case.Draft) prerelease=$($case.Prerelease) missing=$($case.Missing)"
    }
} finally {
    Remove-Item -Recurse -Force $directory
}

exit 0
