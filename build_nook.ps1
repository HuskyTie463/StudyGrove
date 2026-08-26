# Build Study Grove and install to Downloads
# Run: .\build_nook.ps1
# Optional: .\build_nook.ps1 -Clean   (when you get "ZIP decompression failed" error)

param(
    [switch]$Clean  # Run flutter clean first (use when you hit Firebase ZIP errors)
)

$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$flutter = "C:\Users\adara\flutter\bin\flutter.bat"
$dart = "C:\Users\adara\flutter\bin\dart.bat"
$downloads = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
$msixDest = Join-Path $downloads "StudyGrove.msix"

Set-Location $projectRoot

# Remove old MSIX files so the new one is the only copy
Write-Host "Removing old installers..." -ForegroundColor Cyan
@("Nook*.msix", "StudyNook*.msix", "StudyGrow*.msix", "StudyGrove*.msix", "flutter_organiser*.msix") | ForEach-Object {
    Get-ChildItem -Path $downloads -Filter $_ -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}
$buildMsix = Join-Path $projectRoot "build\windows\x64\runner\Release\flutter_organiser.msix"
Remove-Item $buildMsix -Force -ErrorAction SilentlyContinue

if ($Clean) {
    Write-Host "Cleaning build cache (fixes Firebase ZIP errors)..." -ForegroundColor Cyan
    Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
    & $flutter clean 2>&1 | Out-Null
    & $flutter pub get | Out-Null
} else {
    & $flutter pub get 2>&1 | Out-Null
}

Write-Host "Building Study Grove (Windows release)..." -ForegroundColor Cyan
& $flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "`nCreating MSIX installer..." -ForegroundColor Cyan
Write-Host "(If asked 'Install certificate?', type y and press Enter)" -ForegroundColor Yellow
"y" | & $dart run msix:create --output-path $downloads --output-name StudyGrove
if ($LASTEXITCODE -ne 0) { exit 1 }

if (Test-Path $msixDest) {
    Write-Host "`nStudy Grove installer created at:" -ForegroundColor Green
    Write-Host $msixDest -ForegroundColor White
    Write-Host "`nTo install and pin to taskbar:" -ForegroundColor Cyan
    Write-Host "1. Double-click StudyGrove.msix in Downloads" -ForegroundColor White
    Write-Host "2. Click Install" -ForegroundColor White
    Write-Host "3. Open Start menu, find 'Study Grove', right-click -> Pin to taskbar" -ForegroundColor White
    Write-Host "`nOpening Downloads folder..." -ForegroundColor Cyan
    Start-Process "explorer.exe" -ArgumentList "/select,`"$msixDest`""
} else {
    # Fallback: check build folder
    $fallback = Get-ChildItem -Path $projectRoot -Recurse -Filter "*.msix" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($fallback) {
        Copy-Item $fallback.FullName $msixDest -Force
        Write-Host "`nStudy Grove installer copied to:" -ForegroundColor Green
        Write-Host $msixDest -ForegroundColor White
        Start-Process "explorer.exe" -ArgumentList "/select,`"$msixDest`""
    } else {
        Write-Host "MSIX not found. Check build output above." -ForegroundColor Red
        exit 1
    }
}
