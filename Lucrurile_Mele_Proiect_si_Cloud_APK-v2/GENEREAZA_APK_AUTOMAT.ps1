# Script 1-Click pentru generarea automata a fisierului APK pe Windows
$ErrorActionPreference = "Stop"
Write-Host "=== Generare automata APK: Lucrurile mele ===" -ForegroundColor Cyan

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter nu este instalat local pe acest PC. Urca fisierele din arhiva pe GitHub pentru a primi APK-ul automat din Cloud!" -ForegroundColor Yellow
    exit
}

Copy-Item "lib\main.dart" -Destination "main_backup.dart" -Force
Copy-Item "pubspec.yaml" -Destination "pubspec_backup.yaml" -Force

flutter create --org com.lorean --project-name lucrurile_mele .

Move-Item "main_backup.dart" -Destination "lib\main.dart" -Force
Move-Item "pubspec_backup.yaml" -Destination "pubspec.yaml" -Force

flutter pub get
flutter build apk --release

$apkPath = Join-Path (Get-Location) "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    Copy-Item $apkPath -Destination "$env:USERPROFILE\Desktop\Lucrurile_Mele.apk" -Force
    Write-Host "SUCCES! Fisierul Lucrurile_Mele.apk a fost salvat direct pe Desktop-ul tau!" -ForegroundColor Green
}
