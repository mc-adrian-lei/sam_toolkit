@echo off
REM ==============================================================================
REM Samsung Galaxy A15/A16 Hardening & Debloat Script (Windows Batch)
REM Purpose: Remove/disable bloatware and surveillance apps via ADB (non-root)
REM Author: Security Research
REM Date: December 2025
REM ==============================================================================

setlocal enabledelayedexpansion

REM Configuration
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set LOG_FILE=hardening_%TIMESTAMP%.log
set AUDIT_DIR=audit_baseline_%TIMESTAMP%

REM Colors (Windows 10+)
for /F %%A in ('echo prompt $H ^| cmd') do set "BS=%%A"

echo.
echo ================================================================================
echo Samsung Galaxy A15/A16 Hardening Script (Windows)
echo Started: %date% %time%
echo Log file: %LOG_FILE%
echo ================================================================================
echo.

REM ============================================================================
REM Verify ADB is installed and accessible
REM ============================================================================
echo [*] Verifying ADB installation...
where adb >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ADB not found in PATH. Please install Android Debug Bridge.
    echo         Download: https://developer.android.com/tools/adb
    pause
    exit /b 1
) else (
    echo [+] ADB found. Version:
    adb version >> "%LOG_FILE%"
)

REM ============================================================================
REM Verify device connection
REM ============================================================================
echo [*] Checking for connected device...
adb devices | findstr /r "^[^L].*device$" >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] No ADB device connected!
    echo         Steps:
    echo         1. Connect phone via USB
    echo         2. Enable Developer Options: Settings ^> About Phone ^> Build Number (tap 7x)
    echo         3. Enable USB Debugging: Settings ^> Developer Options ^> USB Debugging
    echo         4. Authorize USB debugging prompt on phone
    echo         5. Run this script again
    pause
    exit /b 1
) else (
    echo [+] Device detected:
    adb devices
    timeout /t 2 /nobreak
)

REM ============================================================================
REM Create audit baseline
REM ============================================================================
echo.
echo [*] Creating baseline audit...
mkdir "%AUDIT_DIR%" 2>nul

echo     - Capturing installed packages...
adb shell pm list packages > "%AUDIT_DIR%\packages_baseline.txt"

echo     - Capturing full package dump...
adb shell dumpsys package > "%AUDIT_DIR%\package_dump.txt" 2>nul

echo     - Capturing running processes...
adb shell ps -aux > "%AUDIT_DIR%\ps_baseline.txt" 2>nul

echo     - Capturing network state...
adb shell netstat > "%AUDIT_DIR%\netstat_baseline.txt" 2>nul || adb shell ss -tuln > "%AUDIT_DIR%\ss_baseline.txt" 2>nul

echo     - Capturing logcat (first 1000 lines)...
adb logcat -d > "%AUDIT_DIR%\logcat_baseline.txt" 2>nul

echo [+] Baseline saved to: %AUDIT_DIR%
echo     Verify baseline artifacts before proceeding.
pause

REM ============================================================================
REM Define core exclusions (NEVER REMOVE)
REM ============================================================================
setlocal enabledelayedexpansion

set /A CORE_COUNT=0
set CORE[0]=android
set CORE[1]=com.android.systemui
set CORE[2]=com.android.settings
set CORE[3]=com.android.packageinstaller
set CORE[4]=com.google.android.gms
set CORE[5]=com.android.vending
set /A CORE_COUNT=6

REM ============================================================================
REM Define bloatware to remove
REM ============================================================================

set /A PKG_COUNT=0

REM --- AppCloud / Aura ---
set PKG[0]=com.ironsource.aura
set PKG[1]=com.aura.oobe
set PKG[2]=com.aura.oobe.att
set PKG[3]=com.samsung.android.appcloud
set PKG[4]=com.samsung.android.app.appcloud

REM --- Carrier MSM ---
set PKG[5]=com.att.mobile_services_manager
set PKG[6]=com.samsung.attvvm
set PKG[7]=com.vzw.hss.myverizon
set PKG[8]=com.verizonwireless.messaging
set PKG[9]=com.samsung.vvm
set PKG[10]=com.t_mobile.tmo_mail
set PKG[11]=com.samsung.tmobileconfig

REM --- Facebook ---
set PKG[12]=com.facebook.system
set PKG[13]=com.facebook.appmanager
set PKG[14]=com.facebook.services

REM --- Samsung Promotional ---
set PKG[15]=com.samsung.android.app.news
set PKG[16]=com.samsung.android.game.gametools
set PKG[17]=com.samsung.android.game.gos
set PKG[18]=com.samsung.android.arzone
set PKG[19]=com.samsung.android.tvplus
set PKG[20]=com.samsung.android.oneconnect
set PKG[21]=com.samsung.android.app.watchmanager
set PKG[22]=com.samsung.android.app.watchmanagerstub
set PKG[23]=com.samsung.android.scloud
set PKG[24]=com.samsung.android.app.dressroom
set PKG[25]=com.samsung.android.aremoji
set PKG[26]=com.samsung.android.aremojieditor

REM --- Microsoft ---
set PKG[27]=com.microsoft.skydrive
set PKG[28]=com.microsoft.office.officehubrow

set /A PKG_COUNT=29

REM ============================================================================
REM Display removal plan
REM ============================================================================
echo.
echo ================================================================================
echo REMOVAL PLAN
echo ================================================================================
echo.
echo Core exclusions (PROTECTED - will NOT be touched):
for /L %%i in (0,1,!CORE_COUNT!) do (
    if defined CORE[%%i] (
        echo   - !CORE[%%i]!
    )
)

echo.
echo Packages to remove (total: !PKG_COUNT!):
for /L %%i in (0,1,!PKG_COUNT!) do (
    if defined PKG[%%i] (
        echo   - !PKG[%%i]!
    )
)

echo.
echo WARNING: This will disable/remove apps. Some may reappear after OTA updates.
echo All removals are non-root and reversible via: adb shell cmd package install-existing ^<pkg^>
echo.
set /p CONFIRM="Continue? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Cancelled.
    exit /b 0
)

REM ============================================================================
REM Remove bloatware
REM ============================================================================
echo.
echo ================================================================================
echo REMOVING BLOATWARE
echo ================================================================================
echo.

set /A REMOVED=0
set /A FAILED=0
set /A SKIPPED=0

for /L %%i in (0,1,!PKG_COUNT!) do (
    if defined PKG[%%i] (
        set PKG_NAME=!PKG[%%i]!
        
        REM Check if package exists
        adb shell pm list packages | findstr "!PKG_NAME!" >nul 2>&1
        if !errorlevel! equ 0 (
            echo [*] Removing: !PKG_NAME!
            adb shell pm uninstall --user 0 !PKG_NAME! > temp_output.txt 2>&1
            findstr "Success" temp_output.txt >nul 2>&1
            if !errorlevel! equ 0 (
                echo     [+] Removed successfully
                set /A REMOVED+=1
                echo [+] !PKG_NAME! - REMOVED >> "%LOG_FILE%"
            ) else (
                echo     [!] Uninstall failed (may be protected system app, trying disable...)
                adb shell pm disable-user --user 0 !PKG_NAME! > temp_output.txt 2>&1
                findstr "Success" temp_output.txt >nul 2>&1
                if !errorlevel! equ 0 (
                    echo     [+] Disabled instead
                    set /A REMOVED+=1
                    echo [+] !PKG_NAME! - DISABLED >> "%LOG_FILE%"
                ) else (
                    echo     [!] Failed to disable too
                    set /A FAILED+=1
                    echo [!] !PKG_NAME! - FAILED >> "%LOG_FILE%"
                )
            )
        ) else (
            echo [-] Skipped: !PKG_NAME! (not installed)
            set /A SKIPPED+=1
            echo [-] !PKG_NAME! - NOT INSTALLED >> "%LOG_FILE%"
        )
    )
)

del temp_output.txt 2>nul

REM ============================================================================
REM Permission Hardening
REM ============================================================================
echo.
echo ================================================================================
echo PERMISSION HARDENING
echo ================================================================================
echo.
echo [*] Exporting current permissions audit...
adb shell pm list packages > temp_pkgs.txt

setlocal enabledelayedexpansion
for /f "tokens=2 delims=:" %%A in (temp_pkgs.txt) do (
    adb shell dumpsys package %%A 2>nul | findstr "android.permission" >> "%AUDIT_DIR%\permissions_audit.txt"
)
del temp_pkgs.txt

echo [+] Permission audit saved to: %AUDIT_DIR%\permissions_audit.txt
echo [*] Manual permission hardening required:
echo     - Open Settings ^> Apps ^> Permissions
echo     - Review and deny Location, Camera, Microphone, SMS, Contacts access
echo     - Keep permissions only for necessary apps (Phone, Messaging, Maps, Camera)

REM ============================================================================
REM Create post-hardening snapshot
REM ============================================================================
echo.
echo [*] Creating post-hardening snapshot...
adb shell pm list packages > "%AUDIT_DIR%\packages_after.txt"
adb shell dumpsys package > "%AUDIT_DIR%\package_dump_after.txt" 2>nul
adb shell ps -aux > "%AUDIT_DIR%\ps_after.txt" 2>nul

REM ============================================================================
REM Summary
REM ============================================================================
echo.
echo ================================================================================
echo SUMMARY
echo ================================================================================
echo Removed/Disabled: %REMOVED%
echo Failed: %FAILED%
echo Skipped: %SKIPPED%
echo.
echo Audit directory: %AUDIT_DIR%
echo Log file: %LOG_FILE%
echo.
echo Next Steps:
echo   1. Review audit artifacts in %AUDIT_DIR%
echo   2. Test core functionality (calls, SMS, camera, etc.)
echo   3. Monitor battery and data usage for anomalies
echo   4. Re-run anomaly detection periodically (see anomaly_detect.bat)
echo.
echo To verify removals:
echo   adb shell pm list packages ^| findstr "aura facebook samsung news"
echo.
echo To restore a package:
echo   adb shell cmd package install-existing ^<package_name^>
echo.
echo ================================================================================
echo Hardening completed at: %date% %time%
echo ================================================================================
echo.

pause
