@echo off
setlocal enabledelayedexpansion

set PROJECT_DIR=E:\Automoation-Secretariat-Railways-System-Flutter
set RELEASE_DIR=%PROJECT_DIR%\build\windows\x64\runner\Release
set VERSION=1.0.5_6
set DATETIME=%DATE:~10,4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set DATETIME=%DATETIME: =0%
set PROD_DIR=%PROJECT_DIR%\production_%VERSION%_%DATETIME%\windows

echo =====================================================
echo  Railway Secretariat - Windows Production Packager
echo =====================================================
echo.

if not exist "%RELEASE_DIR%\RailwaySecretariat.exe" (
    echo [ERROR] Build output not found at:
    echo         %RELEASE_DIR%
    echo.
    echo Please run the build first:
    echo   flutter build windows --release
    echo.
    pause
    exit /b 1
)

echo [INFO] Creating production folder: %PROD_DIR%
mkdir "%PROD_DIR%"

echo [INFO] Copying build artifacts...
xcopy /E /I /Y "%RELEASE_DIR%\*" "%PROD_DIR%\"

echo [INFO] Writing BUILD_INFO.txt...
(
    echo Project: railway_secretariat
    echo Version: 1.0.5+6
    echo Build Date: %DATE% %TIME%
    echo Production Directory: %PROD_DIR%
    echo Artifacts:
    echo - windows/
) > "%PROJECT_DIR%\production_%VERSION%_%DATETIME%\BUILD_INFO.txt"

echo.
echo =====================================================
echo  DONE! Production folder created:
echo  production_%VERSION%_%DATETIME%\
echo =====================================================
echo.
echo  Server URL to configure in the app:
echo  https://fibre-should-confidential-specialist.trycloudflare.com
echo.
pause
