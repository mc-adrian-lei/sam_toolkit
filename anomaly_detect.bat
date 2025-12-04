@echo off
REM ==============================================================================
REM Samsung Galaxy A15/A16 Anomaly Detection Script (Windows Batch)
REM Purpose: Detect suspicious activity post-hardening
REM Author: Security Research
REM Date: December 2025
REM ==============================================================================

setlocal enabledelayedexpansion

set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set AUDIT_REPORT=anomaly_report_%TIMESTAMP%.txt
set BASELINE_DIR=%1

if "%BASELINE_DIR%"=="" (
    echo [ERROR] Usage: anomaly_detect.bat ^<baseline_audit_directory^>
    echo.
    echo Example: anomaly_detect.bat audit_baseline_20251204_123456
    echo.
    echo Baseline directories are created by samsung_hardening.bat
    exit /b 1
)

if not exist "%BASELINE_DIR%" (
    echo [ERROR] Baseline directory not found: %BASELINE_DIR%
    exit /b 1
)

echo.
echo ================================================================================
echo Samsung A15/A16 Anomaly Detection
echo Report: %AUDIT_REPORT%
echo ================================================================================
echo.

REM Check device connection
echo [*] Checking device connection...
adb devices | findstr /r "^[^L].*device$" >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] No ADB device connected!
    exit /b 1
)

echo [+] Device connected
echo.

REM ============================================================================
REM Anomaly Detection Checks
REM ============================================================================

echo [*] Anomaly Detection Run: %date% %time% >> "%AUDIT_REPORT%"
echo. >> "%AUDIT_REPORT%"
echo ================================================================================ >> "%AUDIT_REPORT%"
echo ANOMALY DETECTION REPORT
echo ================================================================================ >> "%AUDIT_REPORT%"
echo. >> "%AUDIT_REPORT%"

REM --- Check 1: New packages ---
echo.
echo [*] Check 1: Detecting unexpected new packages...
echo. >> "%AUDIT_REPORT%"
echo --- NEW PACKAGES CHECK --- >> "%AUDIT_REPORT%"
echo. >> "%AUDIT_REPORT%"

adb shell pm list packages > temp_current_packages.txt

fc /b "%BASELINE_DIR%\packages_baseline.txt" temp_current_packages.txt > temp_package_diff.txt 2>&1

if %errorlevel% equ 0 (
    echo [+] No new packages detected >> "%AUDIT_REPORT%"
    echo No new packages detected
) else (
    echo [!] NEW PACKAGES DETECTED - See report for details >> "%AUDIT_REPORT%"
    echo [!] New packages detected:
    type temp_package_diff.txt >> "%AUDIT_REPORT%"
    type temp_package_diff.txt
)

del temp_current_packages.txt temp_package_diff.txt 2>nul

REM --- Check 2: Battery Usage ---
echo.
echo [*] Check 2: Analyzing battery and system stats...
echo. >> "%AUDIT_REPORT%"
echo --- BATTERY AND SYSTEM STATS --- >> "%AUDIT_REPORT%"
echo. >> "%AUDIT_REPORT%"

adb shell dumpsys batterymanager > temp_battery.txt
type temp_battery.txt >> "%AUDIT_REPORT%"
del temp_battery.txt

REM --- Check 3: Location Services ---
echo.
echo [*] Check 3: Checking location services...
echo. >> "%AUDIT_REPORT%"
echo --- LOCATION SERVICES CHECK --- >> "%AUDIT_REPORT%"
echo. >> "%AUDIT_REPORT%"

adb shell settings get secure location_providers_allowed > temp_location.txt
set /p LOCATION_STATUS=<temp_location.txt
echo Location providers: %LOCATION_STATUS% >> "%AUDIT_REPORT%"
echo Location providers: %LOCATION_STATUS%

if "%LOCATION_STATUS%"=="" (
    echo [+] Location services disabled
) else (
    echo [!] Location services active - verify if expected
)

del temp_location.txt

REM --- Check 4: Running Processes ---
echo.
echo [*] Check 4: Checking for suspicious processes...
echo. >> "%AUDIT_REPORT%"
echo --- SUSPICIOUS PROCESS SCAN --- >> "%AUDIT_REPORT%"
echo. >> "%AUDIT_REPORT%"

adb shell ps -aux | findstr /i "ironsource aura appcloud tracking survey facebook" > temp_procs.txt

if %errorlevel% equ 0 (
    echo [!] SUSPICIOUS PROCESSES DETECTED >> "%AUDIT_REPORT%"
    echo [!] Suspicious processes found:
    type temp_procs.txt >> "%AUDIT_REPORT%"
    type temp_procs.txt
) else (
    echo [+] No suspicious processes found >> "%AUDIT_REPORT%"
    echo [+] No known suspicious processes detected
)

del temp_procs.txt 2>nul

REM --- Check 5: Network Activity ---
echo.
echo [*] Check 5: Checking network connections...
echo. >> "%AUDIT_REPORT%"
echo --- NETWORK CONNECTIONS --- >> "%AUDIT_REPORT%"
echo. >> "%AUDIT_REPORT%"

adb shell ss -tuln 2>nul | findstr "ESTABLISHED" > temp_net.txt

if %errorlevel% equ 0 (
    type temp_net.txt >> "%AUDIT_REPORT%"
    type temp_net.txt
    echo.
) else (
    adb shell netstat 2>nul | findstr "ESTABLISHED" >> "%AUDIT_REPORT%"
    adb shell netstat 2>nul | findstr "ESTABLISHED"
)

del temp_net.txt 2>nul

REM --- Check 6: Permissions Changes ---
echo.
echo [*] Check 6: Checking permission changes...
echo. >> "%AUDIT_REPORT%"
echo --- PERMISSIONS AUDIT --- >> "%AUDIT_REPORT%"
echo. >> "%AUDIT_REPORT%"

adb shell dumpsys package > temp_perms.txt
findstr "android.permission.RECORD_AUDIO" temp_perms.txt > temp_perms_filtered.txt

if errorlevel 1 (
    echo [+] No unexpected microphone permissions found >> "%AUDIT_REPORT%"
) else (
    echo [!] MICROPHONE PERMISSIONS DETECTED >> "%AUDIT_REPORT%"
    type temp_perms_filtered.txt >> "%AUDIT_REPORT%"
    type temp_perms_filtered.txt
)

del temp_perms.txt temp_perms_filtered.txt 2>nul

REM --- Summary ---
echo.
echo ================================================================================
echo REPORT GENERATED: %AUDIT_REPORT%
echo ================================================================================
echo.
echo Recommendations:
echo   - Review %AUDIT_REPORT% for full details
echo   - If suspicious packages detected, investigate:
echo       adb shell pm dump ^<package_name^>
echo       adb shell pm list packages --uid
echo   - To uninstall suspicious packages:
echo       adb shell pm uninstall --user 0 ^<package_name^>
echo   - For persistent tracking: enable USB logging and network monitoring
echo.
echo To restore from baseline if needed:
echo   Compare %BASELINE_DIR% with current state
echo.
