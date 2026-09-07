@echo off
cd /d "%~dp0"
echo Fixed Rent.lk Flutter Web running from: %CD%
flutter clean
flutter pub get
flutter run -d chrome
pause
