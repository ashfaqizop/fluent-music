<#
.SYNOPSIS
    Builds a portable Fluent Music release and zips it for phase-gate
    testing on the reference laptop (Masterdoc §0.3, §14, §17).
.DESCRIPTION
    Runs `flutter build windows --release` for app/, then zips the release
    runner output (fluent_music.exe + required assets/DLLs) under dist/.
#>

[CmdletBinding()]
param(
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $repoRoot 'app'
if (-not $OutputDir) {
    $OutputDir = Join-Path $repoRoot 'dist'
}

Write-Host '==> Building app/ in release mode' -ForegroundColor Cyan
Push-Location $appDir
try {
    flutter build windows --release
} finally {
    Pop-Location
}

$releaseDir = Join-Path $appDir 'build\windows\x64\runner\Release'
if (-not (Test-Path $releaseDir)) {
    throw "Release output not found at $releaseDir"
}

$exePath = Join-Path $releaseDir 'fluent_music.exe'
if (-not (Test-Path $exePath)) {
    throw "Expected fluent_music.exe not found at $exePath - check windows/CMakeLists.txt BINARY_NAME."
}

$pubspecPath = Join-Path $appDir 'pubspec.yaml'
$versionLine = Get-Content $pubspecPath | Where-Object { $_ -match '^version:\s*(\S+)' }
$version = if ($versionLine -match '^version:\s*(\S+)') { $matches[1] } else { '0.0.0' }
# Strip the Flutter build-number suffix (+N) for a clean zip name.
$version = $version.Split('+')[0]

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$zipName = "fluent-music-$version-portable-windows-x64.zip"
$zipPath = Join-Path $OutputDir $zipName

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Write-Host "==> Zipping $releaseDir -> $zipPath" -ForegroundColor Cyan
Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $zipPath

Write-Host ''
Write-Host "Portable build ready: $zipPath" -ForegroundColor Green
Write-Host 'Copy this zip to the reference laptop (Core i3-3110M / 4GB DDR3 / HDD / HD 4000) and confirm it launches smoothly (Masterdoc §14).'
