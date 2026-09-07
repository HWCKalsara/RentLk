@echo off
echo Rent.lk Flutter Web Runner
flutter create . --platforms=android,ios,web
flutter pub get
flutter run -d chrome
pause
