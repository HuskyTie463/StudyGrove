# Build Flutter Windows. Uses default Visual Studio (2026 if installed).
# CMake 4.x from VS 2026 is supported via CMAKE_POLICY_VERSION_MINIMUM in windows/CMakeLists.txt.
# Run this in a terminal where "flutter" works.

$ErrorActionPreference = "Stop"

# Optional: force VS 2022 (only if you hit Firebase linker errors with VS 2026):
# $env:CMAKE_GENERATOR = "Visual Studio 17 2022"
# $env:CMAKE_GENERATOR_PLATFORM = "x64"

Write-Host "Building Windows app..." -ForegroundColor Cyan
if ($env:CMAKE_GENERATOR) {
    Write-Host "CMAKE_GENERATOR=$env:CMAKE_GENERATOR" -ForegroundColor Gray
}
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

flutter clean
flutter pub get
flutter build windows

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Build succeeded." -ForegroundColor Green
} else {
    exit 1
}
