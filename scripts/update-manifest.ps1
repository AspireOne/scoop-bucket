param(
    [Parameter(Mandatory)][string]$App,
    [Parameter(Mandatory)][string]$Version,
    [string]$Directory = (Join-Path $PSScriptRoot '../bucket')
)

$ErrorActionPreference = 'Stop'

if ($App -cnotmatch '^[a-z0-9][a-z0-9+@._-]*$') {
    throw "Invalid app name: $App"
}
$path = Join-Path $Directory "$App.json"
if (-not (Test-Path $path -PathType Leaf)) {
    throw "Unknown app: $App"
}
if ($Version -cnotmatch '^v?[0-9]+\.[0-9]+\.[0-9]+$') {
    throw "Expected a stable release tag such as v1.9.2: $Version"
}

$manifest = Get-Content -Raw $path | ConvertFrom-Json
if ($manifest.checkver.github -cnotmatch '^https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/?$') {
    throw 'Automatic updates require checkver.github to identify the upstream repository.'
}
$repository = $Matches[1]
if (-not $manifest.autoupdate) {
    throw "$App has no autoupdate definition."
}

$target = $Version -creplace '^v', ''
if ([version]$target -lt [version]$manifest.version) {
    throw "Refusing to downgrade $App from $($manifest.version) to $target."
}

Write-Host "Checking $repository release $Version for $App (currently $($manifest.version))"
$releaseJson = gh api "repos/$repository/releases/tags/$Version"
if ($LASTEXITCODE -ne 0) {
    throw "Could not find published release $repository $Version."
}
$release = $releaseJson | ConvertFrom-Json
if ($release.draft -or $release.prerelease -or $release.tag_name -cne $Version) {
    throw "Release $Version must be published and stable."
}
if ($manifest.version -ceq $target) {
    Write-Host "$App is already at $Version."
    return
}

$scoopRoot = scoop prefix scoop
if ($LASTEXITCODE -ne 0) {
    throw 'Could not locate Scoop.'
}
$checkver = Join-Path $scoopRoot 'bin/checkver.ps1'
& $checkver -App (Resolve-Path $path).Path -Version $target -Update -ThrowError

$updated = Get-Content -Raw $path | ConvertFrom-Json
if ($updated.version -cne $target) {
    throw "Scoop did not update $App to $target."
}
Write-Host "Prepared $App $Version."
