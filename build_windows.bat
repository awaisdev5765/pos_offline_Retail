@echo off
echo Building Offline POS System for Windows...
echo.

REM Check if Flutter is installed
flutter --version
if %errorlevel% neq 0 (
    echo Flutter is not installed or not in PATH
    echo Please install Flutter from https://flutter.dev/docs/get-started/install/windows
    pause
    exit /b 1
)

echo.
echo Cleaning previous builds...
flutter clean

echo.
echo Getting dependencies...
flutter pub get

echo.
echo Building for Windows (Release)...
flutter build windows --release

if %errorlevel% equ 0 (
    echo.
    echo ✅ Build successful!
    echo.
    echo The Windows executable is located at:
    echo build\windows\x64\runner\Release\offline_pos_system.exe
    echo.
    echo You can now run the application by double-clicking the executable.
) else (
    echo.
    echo ❌ Build failed!
    echo Please check the error messages above.
)

echo.
pause
