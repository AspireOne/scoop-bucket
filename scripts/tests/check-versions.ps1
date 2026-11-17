$ErrorActionPreference = 'Stop'

$directory = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory $directory | Out-Null

try {
    $source = Join-Path $directory 'latest.txt'
    Set-Content $source '1.0.1'
    $path = Join-Path $directory 'example.json'
    $manifest = @{
        version = '1.0.1'
        homepage = ([uri]$source).AbsoluteUri
        checkver = '([0-9.]+)'
    }

    $cases = @(
        @{ Name = 'current version'; Version = '1.0.1'; Content = '1.0.1'; Error = $null },
        @{ Name = 'stale version without autoupdate'; Version = '1.0.0'; Content = '1.0.1'; Error = 'stale or could not be checked' },
        @{ Name = 'unparseable version'; Version = '1.0.1'; Content = 'unknown'; Error = 'stale or could not be checked' },
        @{ Name = 'unreadable source'; Version = '1.0.1'; Content = $null; Error = 'stale or could not be checked' },
        @{ Name = 'missing checkver'; Version = '1.0.1'; Content = '1.0.1'; WithoutCheckver = $true; Error = 'has no checkver definition' },
        @{ Name = 'empty bucket'; Version = '1.0.1'; Content = '1.0.1'; EmptyBucket = $true; Error = 'No Scoop manifests found' }
    )

    foreach ($case in $cases) {
        $manifest.version = $case.Version
        $manifest.checkver = if ($case.WithoutCheckver) { $null } else { '([0-9.]+)' }
        $manifest | ConvertTo-Json | Set-Content $path
        $before = Get-Content -Raw $path
        if ($null -eq $case.Content) {
            Remove-Item $source
        } else {
            Set-Content $source $case.Content
        }
        if ($case.EmptyBucket) {
            Remove-Item $path
        }

        $failure = $null
        try {
            & "$PSScriptRoot/../check-versions.ps1" -Directory $directory
        } catch {
            $failure = $_
        }

        if ([bool]$failure -ne [bool]$case.Error -or ($failure -and -not $failure.Exception.Message.Contains($case.Error))) {
            throw "$($case.Name): expected '$($case.Error)', got '$failure'."
        }
        if ((Test-Path $path) -and (Get-Content -Raw $path) -cne $before) {
            throw "$($case.Name): version checking modified the manifest."
        }
        Write-Host "PASS: $($case.Name)"
    }
} finally {
    Remove-Item -Recurse -Force $directory
}
