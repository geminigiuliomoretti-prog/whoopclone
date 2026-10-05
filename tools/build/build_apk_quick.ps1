# Script di Compilazione Automatica 1-Click APK per Whoop 5.0 Clone
Write-Host "=== AVVIO COMPILAZIONE AUTOMATICA 1-CLICK WHOOP 5.0 APK ===" -ForegroundColor Cyan

$flutterDir = "C:\flutter"
if (-not (Test-Path "$flutterDir\bin\flutter.bat")) {
    Write-Host "Download in corso di Flutter SDK Portable..." -ForegroundColor Yellow
    $zipPath = "$env:TEMP\flutter.zip"
    Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.0-stable.zip" -OutFile $zipPath
    Write-Host "Estrazione in corso in C:\flutter..." -ForegroundColor Yellow
    Expand-Archive -Path $zipPath -DestinationPath "C:\" -Force
}

$scriptDir = $PSScriptRoot
Set-Location "$scriptDir\..\..\whoop_clone"

Write-Host "Compilazione dell'APK in corso (Release mode)..." -ForegroundColor Green
& "flutter" build apk --release

Write-Host "`n=== COMPILAZIONE COMPLETATA! ===" -ForegroundColor Green
Write-Host "File APK salvato in: $scriptDir\..\..\whoop_clone\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Cyan
