@echo off
echo ======================================
echo  School Manager - Build & Run Script
echo ======================================
echo.

:: Add Flutter to PATH
set PATH=C:\flutter\bin;%PATH%

:: Check Flutter
flutter --version
echo.

:: Get dependencies
echo Getting packages...
flutter pub get
echo.

:: Run the app
echo Starting app on connected device/emulator...
flutter run
