# PowerShell script to build MSIX package for Windows Store distribution
# Requires: Windows SDK, MSIX Packaging Tool, or Visual Studio

param(
    [string]$Configuration = "Release",
    [string]$OutputPath = ".\build\msix",
    [string]$CertificatePath = "",
    [string]$CertificatePassword = ""
)

Write-Host "MSIX Package Builder for Offline POS System" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green

# Check if Flutter is available
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterPath) {
    Write-Host "Error: Flutter not found in PATH" -ForegroundColor Red
    exit 1
}

# Build Flutter app
Write-Host "`nBuilding Flutter app for Windows..." -ForegroundColor Yellow
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Flutter build failed" -ForegroundColor Red
    exit 1
}

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

Write-Host "`nMSIX Package Configuration:" -ForegroundColor Yellow
Write-Host "  Configuration: $Configuration" -ForegroundColor Cyan
Write-Host "  Output Path: $OutputPath" -ForegroundColor Cyan
Write-Host "  Certificate: $(if ($CertificatePath) { 'Provided' } else { 'Not provided (will need signing)' })" -ForegroundColor Cyan

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Use MSIX Packaging Tool or Visual Studio to create the package" -ForegroundColor White
Write-Host "2. Use the Package.appxmanifest file in the windows directory" -ForegroundColor White
Write-Host "3. Include the built files from build\windows\$Configuration\runner" -ForegroundColor White
Write-Host "4. Sign the package with a code signing certificate" -ForegroundColor White
Write-Host "5. Test the package before distribution" -ForegroundColor White

Write-Host "`nFor detailed instructions, see: windows\README_WINDOWS_FEATURES.md" -ForegroundColor Cyan

# Check for MSIX Packaging Tool
$msixTool = Get-Command "msixpackagingtool" -ErrorAction SilentlyContinue
if (-not $msixTool) {
    Write-Host "`nMSIX Packaging Tool not found in PATH." -ForegroundColor Yellow
    Write-Host "Download from: https://aka.ms/msixpackagingtool" -ForegroundColor Cyan
}

