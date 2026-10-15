@echo off
echo ======================================
echo  School Manager - Build APK
echo ======================================
echo.

set PATH=C:\flutter\bin;%PATH%

echo Building release APK...
flutter build apk --release

echo.
echo APK location:
echo build\app\outputs\flutter-apk\app-release.apk
echo.
pause
