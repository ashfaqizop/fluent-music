<#
.SYNOPSIS
    Provisions/verifies the Fluent Music development environment on Windows.
.DESCRIPTION
    Idempotent: checks each required tool and only installs what's missing
    (via winget, where available). Safe to re-run at any time.

    Required tooling (Masterdoc §21):
      - Flutter 3.44.x stable
      - Visual Studio "Desktop development with C++" workload
      - rustup (required to build smtc_windows)
      - NSIS / makensis (installer packaging)
      - melos (monorepo tooling)
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Test-CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Write-Step { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok { param([string]$Message) Write-Host "    OK: $Message" -ForegroundColor Green }
function Write-Missing { param([string]$Message) Write-Host "    MISSING: $Message" -ForegroundColor Yellow }

# --- Flutter -----------------------------------------------------------
Write-Step 'Checking Flutter SDK (>= 3.44.0)'
if (Test-CommandExists 'flutter') {
    $flutterVersionLine = (flutter --version 2>$null | Select-Object -First 1)
    Write-Ok $flutterVersionLine
} else {
    Write-Missing 'Flutter not found on PATH.'
    Write-Host '    Install Flutter 3.44.x stable: https://docs.flutter.dev/get-started/install/windows'
    Write-Host '    (SDK location is a per-developer choice; not auto-installed by this script.)'
}

# --- Visual Studio C++ workload -----------------------------------------
Write-Step 'Checking Visual Studio "Desktop development with C++" workload'
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$hasCppWorkload = $false
if (Test-Path $vswhere) {
    $vsInfo = & $vswhere -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath
    if ($vsInfo) { $hasCppWorkload = $true }
}
if ($hasCppWorkload) {
    Write-Ok 'Desktop development with C++ workload is installed.'
} elseif (Test-CommandExists 'winget') {
    Write-Missing 'Desktop development with C++ workload not found. Installing via winget...'
    winget install --id Microsoft.VisualStudio.2022.Community --override `
        '--add Microsoft.VisualStudio.Workload.NativeDesktop --quiet --norestart' -e
} else {
    Write-Missing 'Desktop development with C++ workload not found.'
    Write-Host '    Install Visual Studio with that workload: https://visualstudio.microsoft.com/downloads/'
}

# --- rustup --------------------------------------------------------------
Write-Step 'Checking rustup (required to build smtc_windows)'
if (Test-CommandExists 'rustup') {
    Write-Ok (rustup --version | Select-Object -First 1)
} elseif (Test-CommandExists 'winget') {
    Write-Missing 'rustup not found. Installing via winget...'
    winget install --id Rustlang.Rustup -e
} else {
    Write-Missing 'rustup not found on PATH.'
    Write-Host '    Install rustup: https://rustup.rs/'
}

# --- NSIS ------------------------------------------------------------------
Write-Step 'Checking NSIS (makensis, required for the installer build)'
if (Test-CommandExists 'makensis') {
    Write-Ok 'makensis is available.'
} elseif (Test-CommandExists 'winget') {
    Write-Missing 'makensis not found. Installing NSIS via winget...'
    winget install --id NSIS.NSIS -e
} else {
    Write-Missing 'makensis not found on PATH.'
    Write-Host '    Install NSIS: https://nsis.sourceforge.io/Download'
}

# --- melos -----------------------------------------------------------------
Write-Step 'Checking melos (Dart global activation)'
$pubCacheBin = Join-Path $env:LOCALAPPDATA 'Pub\Cache\bin'
if (Test-Path (Join-Path $pubCacheBin 'melos.bat')) {
    Write-Ok 'melos is activated.'
} elseif (Test-CommandExists 'dart') {
    Write-Missing 'melos not activated. Activating via `dart pub global activate melos`...'
    dart pub global activate melos
} else {
    Write-Missing 'melos not activated and Dart is not on PATH.'
    Write-Host '    Install Flutter first, then run: dart pub global activate melos'
}
if ($env:Path -notlike "*$pubCacheBin*") {
    Write-Host "Note: add '$pubCacheBin' to your PATH to use the 'melos' command directly." -ForegroundColor Yellow
}

# --- Workspace bootstrap ---------------------------------------------------
Write-Step 'Bootstrapping the melos workspace (flutter pub get across all packages)'
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    flutter pub get

    Write-Step 'Running code generation (build_runner) for packages that need it'
    dart run melos exec --depends-on=build_runner -- dart run build_runner build
} finally {
    Pop-Location
}

Write-Host ''
Write-Host 'Setup check complete. Re-run this script any time to verify your environment.' -ForegroundColor Cyan
