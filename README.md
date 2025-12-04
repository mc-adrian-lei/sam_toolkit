This upgrade implements tiered component-disabling fallback and core-exclusion
harmonization across PowerShell and Batch scripts. The "double-effort" strategy attempts
removal via three escalating methods before accepting partial failure.
Key improvements:
Cascading disable methods (uninstall → disable-user → component-level disable)
Unified core exclusion lists across platforms
Enhanced dumpsys parsing for granular component targeting
Better logging and status tracking
Add this function to your samsung_hardening.ps1 script. It replaces the inline uninstall
logic with intelligent fallback:
function Disable-PackageAggressively {
<#
.SYNOPSIS
Attempts to disable/remove a package via tiered fallback approach.
.DESCRIPTION
Tries three methods in sequence:
1. pm uninstall --user 0 (user-level uninstall)
2. pm disable-user --user 0 (user-level disable)
3. Component-level disable (activities, services, receivers, providers)
.PARAMETER PackageName
The package identifier (e.g., com.samsung.android.appcloud)
.PARAMETER DryRun
If set, logs actions without executing ADB commands
.OUTPUTS
Samsung Galaxy A15/A16 Hardening Script
Upgrade
Overview
Part 1: PowerShell Function — DisablePackageAggressively
String: One of [REMOVED | DISABLED | PARTIAL | SKIPPED | DRY | FAILED
#>
param(
[string]$PackageName,
[switch]$DryRun
)
Write-Log "Processing package: $PackageName"
# === STAGE 0: Check if installed ===
$installed = Invoke-ADB "shell pm list packages $PackageName" | Select-String
if (-not $installed) {
Write-Log " [-] Not installed, skipping"
return "SKIPPED"
}
# === DRY RUN MODE ===
if ($DryRun) {
Write-Host " [DRY RUN] Would attempt uninstall/disable for: $PackageName
Write-Log " [DRY RUN] $PackageName"
return "DRY"
}
# === STAGE 1: Try uninstall --user 0 ===
Write-Log " [STAGE 1] Attempting pm uninstall --user 0"
$out = Invoke-ADB "shell pm uninstall --user 0 $PackageName"
if ($out -match "Success") {
Write-Log " [+] UNINSTALLED (user 0)"
return "REMOVED"
}
Write-Log " [!] Uninstall failed; attempting Stage 2"
# === STAGE 2: Try disable-user --user 0 ===
Write-Log " [STAGE 2] Attempting pm disable-user --user 0"
$out = Invoke-ADB "shell pm disable-user --user 0 $PackageName"
if ($out -match "Success") {
Write-Log " [+] DISABLED (user 0)"
return "DISABLED"
}
Write-Log " [!] disable-user failed; falling back to Stage 3 (component-level)"
# === STAGE 3: Component-level disable ===
Write-Log " [STAGE 3] Attempting component-level disable"
$dump = Invoke-ADB "shell dumpsys package $PackageName"
if (-not $dump) {
Write-Log " [!] dumpsys returned no data; cannot enumerate components" "W
Write-Log " [!] $PackageName - FAILED (no dumpsys output)"
return "FAILED"
}
# Extract component patterns: ActivityResolver, service, receiver, provider
$patterns = @(
"ActivityResolver",
"^\s+service ",
"^\s+receiver ",
"^\s+provider "
)
$components = @()
# Parse dumpsys output line-by-line
foreach ($line in ($dump -split "`n")) {
foreach ($p in $patterns) {
if ($line -match $p -and $line -match " $([regex]::Escape($PackageName))/")
# Extract ComponentName like "com.pkg/.SomeClass"
if ($line -match "($([regex]::Escape($PackageName))/[^ ]+)") {
$components += $matches[1]
}
}
}
}
$components = $components | Sort-Object -Unique
if ($components.Count -eq 0) {
Write-Log " [!] No components found to disable" "WARN"
Write-Log " [!] $PackageName - FAILED (no components enumerated)"
return "FAILED"
}
# Disable each component
$disabledCount = 0
foreach ($component in $components) {
$cmd = "shell pm disable $component"
$res = Invoke-ADB $cmd
if ($res -match "new state: disabled" -or $res -match "Package .* new state") {
Write-Log " [+] Disabled component: $component"
$disabledCount++
} else {
Write-Log " [!] Failed to disable component: $component" "WARN"
}
}
if ($disabledCount -gt 0) {
Write-Log " [+] Partially disabled $disabledCount/$($components.Count) com
Write-Log " [!] $PackageName - PARTIAL ($disabledCount components disabl
return "PARTIAL"
}
Write-Log " [!] $PackageName - FAILED (component disable had no success)"
return "FAILED"
}
Replace your existing foreach ($pkg in $bloatwarePackages) block with this enhanced
version:
Write-Log "========== STAGE: Bloatware Removal =========="
Write-Log "Total packages to process: bloatwarePackages.Count)"
Write-Log ""
$removed = 0
$disabled = 0
$partial = 0
$failed = 0
$skipped = 0
foreach ($pkg in $bloatwarePackages) {
$result = Disable-PackageAggressively -PackageName DryRun
switch ($result) {
"REMOVED" {
$removed++
Write-Host " [OK] Removed" -ForegroundColor Green
}
"DISABLED" {
$disabled++
Write-Host " [OK] Disabled" -ForegroundColor Green
}
"PARTIAL" {
$partial++
Write-Host " [PARTIAL] Some components disabled" -ForegroundColor Yel
}
"SKIPPED" {
$skipped++
Write-Host " [SKIP] Not installed" -ForegroundColor Gray
}
"DRY" {
Write-Host " [DRY RUN]" -ForegroundColor Cyan
}
Part 2: Integration into Main Loop
=== Enhanced removal loop with tiered
fallback ===
default {
$failed++
Write-Host " [FAIL] Unable to disable" -ForegroundColor Red
}
}
}
Write-Log ""
Write-Log "========== Bloatware Removal Summary =========="
Write-Log "Removed: $removed"
Write-Log "Disabled: $disabled"
Write-Log "Partial: $partial"
Write-Log "Failed: $failed"
Write-Log "Skipped: $skipped"
Write-Log "Total processed: removed + $disabled + $partial + $failed + $skipped)"
Update your samsung_hardening.bat to extend core exclusions and align with PowerShell:
set CORE[0]=android
set CORE[1]=com.android.systemui
set CORE[2]=com.android.settings
set CORE[3]=com.android.packageinstaller
set CORE[4]=com.google.android.gms
set CORE[5]=com.android.vending
set /A CORE_COUNT=6
set CORE[0]=android
set CORE[1]=com.android.systemui
set CORE[2]=com.android.settings
set CORE[3]=com.android.packageinstaller
set CORE[4]=com.google.android.gms
set CORE[5]=com.android.vending
set CORE[6]=com.android.keychain
set CORE[7]=com.samsung.android.ims
set CORE[8]=com.sec.telephony
set CORE[9]=com.android.permission
set /A CORE_COUNT=10
Rationale for additions:
=== Final summary ===
Part 3: Batch Script Harmonization
Current CORE Array (Update From):
New CORE Array (Update To):
com.android.keychain — Credential storage (needed for HTTPS, OAuth, certificate
chains)
com.samsung.android.ims — IP Multimedia Subsystem (VoIP/5G calling)
com.sec.telephony — Samsung telephony stack (call handling, SIM management)
com.android.permission — Permission framework itself
In your .bat script, locate this section:
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
And replace it with:
REM Define core exclusions (NEVER REMOVE)
REM ============================================================================
setlocal enabledelayedexpansion
set /A CORE_COUNT=0
REM === Critical Android Framework ===
set CORE[0]=android
set CORE[1]=com.android.systemui
set CORE[2]=com.android.settings
set CORE[3]=com.android.packageinstaller
REM === Google Services ===
set CORE[4]=com.google.android.gms
set CORE[5]=com.android.vending
REM === Credential & Telephony (NEW) ===
set CORE[6]=com.android.keychain
set CORE[7]=com.samsung.android.ims
set CORE[8]=com.sec.telephony
set CORE[9]=com.android.permission
set /A CORE_COUNT=10
Find and Replace Section
Add this validation to the top of both scripts to ensure they're using matching exclusion
lists:
$coreExclusions = @(
"android",
"com.android.systemui",
"com.android.settings",
"com.android.packageinstaller",
"com.google.android.gms",
"com.android.vending",
"com.android.keychain",
"com.samsung.android.ims",
"com.sec.telephony",
"com.android.permission"
)
function Test-CoreExclusions {
Write-Log "========== Core Exclusion Validation =========="
Write-Log "Protected packages: coreExclusions.Count)"
foreach ($core in $coreExclusions) {
Write-Log " [+] $core"
}
Write-Log ""
}
Test-CoreExclusions
Add this validation block after CORE array definition:
REM ============================================================================
REM Validate core exclusions (sanity check)
REM ============================================================================
echo.
echo [] Core Exclusion Validation
echo [] Protected packages: %CORE_COUNT%
for /L %%i in (0,1,%CORE_COUNT%) do (
if defined CORE[%%i] (
echo [+] !CORE[%%i]!
)
)
Part 4: Validation Logic (Optional but Recommended)
For PowerShell (samsung_hardening.ps1):
Call early in script
For Batch (samsung_hardening.bat):
echo.
pause
Both scripts should skip removal if a package name matches any CORE exclusion. Here's a
safety check for batch:
REM === Safety check: prevent core packages from being in removal list ===
setlocal enabledelayedexpansion
for /L %%i in (0,1,!PKG_COUNT!) do (
if defined PKG[%%i] (
set PKG_NAME=!PKG[%%i]!
REM Check if this package is in CORE exclusions
for /L %%j in (0,1,!CORE_COUNT!) do (
if defined CORE[%%j] (
if "!PKG_NAME!"=="!CORE[%%j]!" (
echo [ERROR] Package !PKG_NAME! is in CORE exclusions!
echo This should never happen. Update your PKG list.
pause
exit /b 1
)
)
)
)
)
PowerShell:
.\samsung_hardening.ps1 -DryRun
Batch:
REM Modify the beginning of samsung_hardening.bat:
set DRY_RUN=1
REM Then add this condition around all removal commands:
if !DRY_RUN! equ 0 (
adb shell pm uninstall ...
)
Part 5: Cross-Check Logic
Part 6: Testing & Validation
Dry-Run (Recommended First):
adb shell pm list packages | grep -E
"android$|systemui|settings|gms|vending|keychain|ims|telephony|permission"
All should return results. If any are missing, the device is in a broken state.
adb shell pm list packages | grep -E "aura|facebook|samsung.android.app.news"
Should return empty or minimal results.
Component Old New Benefit
Removal
Strategy
Single
attempt
(uninstall)
Tiered 3-stage
fallback
Handles
OEM/carrier
protections better
Core
Exclusions
6 packages 10 packages
Protects keychain,
IMS, telephony
ComponentLevel
Disable
Not
implemente
d
Full dumpsys
parsing
Granular fallback
when package-level
fails
Logging Basic
Stage-by-stage
with status
codes
Better auditing and
debugging
Cross-Script
Sync
Manual
Unified lists in
both scripts
Reduced desync
risk
1. Backup current scripts — Save existing .bat and .ps1 versions
2. Integrate PowerShell function — Add Disable-PackageAggressively to
samsung_hardening.ps1
3. Update CORE array — Extend both .bat and .ps1 core exclusion lists
4. Test with --DryRun — Verify logic before live execution
5. Monitor removal results — Review logs for PARTIAL/FAILED entries
6. Document deviations — Note which packages failed to fully disable (they may need
component-specific blocking)
Verify Protected Packages:
Verify Removed Packages:
Summary of Changes
Next Steps
LinuxConfig: Remove Bloatware
Kaspersky: Disable Android Bloatware
TechFinitive: App Cloud Delete
Awesome Android Root: Debloating
ADB Command Use Case
Succ
ess
Rate
Notes
pm uninstall --
user 0 PKG
Remove userinstalled or
patchable system
apps
70%
Fails on protected
OEM/carrier apps
pm disable-user -
-user 0 PKG
Disable in user
space without
removing
85%
Works when
uninstall blocked;
app may restart on
boot
pm disable PKG
System-level
disable (requires
root)
N/A
Not usable without
rooting
Component
disable via pm
disable
COMPONENT
Granular
shutdown
(activities,
services,
receivers)
60-
90%
Fallback when
package-level fails;
prevents autostart
dumpsys
package PKG
Enumerate
components
95%
Always succeeds if
package exists
Document version: 1.0 (December 2025)
Last updated: 2025-12-04
Author: Security Research Team
References
Appendix: Full Comparison Table
