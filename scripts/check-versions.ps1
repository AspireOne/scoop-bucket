param(
    [string]$Directory = (Join-Path $PSScriptRoot '../bucket')
)

$ErrorActionPreference = 'Stop'

$manifests = @(Get-ChildItem -Path $Directory -Filter '*.json' -File)
if ($manifests.Count -eq 0) {
    throw "No Scoop manifests found in $Directory"
}

foreach ($path in $manifests) {
    $manifest = Get-Content -Raw $path.FullName | ConvertFrom-Json
    if (-not $manifest.checkver) {
        throw "$($path.Name) has no checkver definition."
    }
}

$scoopRoot = scoop prefix scoop
if ($LASTEXITCODE -ne 0) {
    throw 'Could not locate Scoop.'
}

# Scoop stays quiet with -SkipUpdated only when every lookup succeeds and matches.
$checkver = Join-Path $scoopRoot 'bin/checkver.ps1'
$output = @(& $checkver -Dir $Directory -SkipUpdated -ThrowError *>&1)
$output | ForEach-Object { Write-Host $_ }
if ($output.Count -gt 0) {
    throw 'One or more Scoop manifests are stale or could not be checked. See the output above.'
}

Write-Host 'All Scoop manifests are current.'
