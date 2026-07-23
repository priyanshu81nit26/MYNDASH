@echo off
REM ============================================================
REM  DISTRICT — one-click build + install to your connected phone
REM  Requirements: Flutter installed, phone connected with
REM  USB debugging ON (Settings > Developer options).
REM ============================================================
cd /d "%~dp0"

echo.
echo [1/4] Fetching packages...
call flutter pub get
if errorlevel 1 goto :fail

echo.
echo [2/4] Checking connected devices...
call flutter devices

echo.
echo [3/4] Building release APK (first build takes a few minutes)...
REM Payment providers are disabled in v1. Resend credentials belong only in
REM Firebase Secret Manager and must never be passed into the Flutter build.
call flutter build apk --release
if errorlevel 1 goto :fail

echo.
echo [4/4] Installing on your phone...
call flutter install --release
if errorlevel 1 (
  echo Trying adb directly...
  call adb install -r build\app\outputs\flutter-apk\app-release.apk
  if errorlevel 1 goto :fail
)

echo.
echo ============================================================
echo   DONE! DISTRICT is on your phone. Go crush some puzzles.
echo ============================================================
pause
exit /b 0

:fail
echo.
echo ------------------------------------------------------------
echo  Build or install failed — read the error above.
echo  Common fixes:
echo   * Phone not detected: enable USB debugging + tap "Allow"
echo   * First time: run "flutter doctor" and fix what it lists
echo   * Package errors: run "flutter clean" then re-run this file
echo ------------------------------------------------------------
pause
exit /b 1
