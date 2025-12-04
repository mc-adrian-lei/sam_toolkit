# ==============================================================================
# Samsung Galaxy A15/A16 Hardening & Debloat Script (PowerShell)
# Purpose: Remove/disable bloatware and surveillance apps via ADB (non-root)
# Author: Security Research
# Date: December 2025
# ==============================================================================

param(
    [switch]$DryRun = $false,
    [switch]$SkipBaseline = $false,
    [switch]$Audit = $false
)

$ErrorActionPreference = "Continue"

# Configuration
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "hardening_$timestamp.log"
$auditDir = "audit_baseline_$timestamp"

# Define function to log
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry
}

# Define function to run ADB command
function Invoke-ADB {
    param(
        [string]$Arguments
    )
    
    try {
        $result = & adb $Arguments.Split() 2>&1
        return $result
    } catch {
        Write-Log "ADB execution failed: $_" "ERROR"
        return $null
    }
}

# ==============================================================================
# Header
# ==============================================================================
Write-Host ""
Write-Host "================================================================================"
Write-Host "Samsung Galaxy A15/A16 Hardening Script (PowerShell)"
Write-Host "Started: $(Get-Date)"
Write-Host "Log file: $logFile"
Write-Host "Dry Run: $DryRun"
Write-Host "================================================================================"
Write-Host ""

Write-Log "Samsung A15/A16 Hardening Script Started"

# ==============================================================================
# Verify ADB is installed
# ==============================================================================
Write-Log "Verifying ADB installation..."

$adbPath = (Get-Command adb -ErrorAction SilentlyContinue).Source

if (-not $adbPath) {
    Write-Log "ADB not found in PATH. Please install Android Debug Bridge." "ERROR"
    Write-Log "Download: https://developer.android.com/tools/adb" "ERROR"
    exit 1
}

Write-Log "ADB found at: $adbPath"
$adbVersion = Invoke-ADB "version"
Write-Log "ADB Version: $($adbVersion[0])"

# ==============================================================================
# Verify device connection
# ==============================================================================
Write-Log "Checking for connected device..."

$devices = Invoke-ADB "devices"
$deviceConnected = $devices -match "device$" | Where-Object { $_ -notmatch "List of" } | Measure-Object | Select-Object -ExpandProperty Count

if ($deviceConnected -eq 0) {
    Write-Log "No ADB device connected!" "ERROR"
    Write-Log "Steps:" "ERROR"
    Write-Log "  1. Connect phone via USB" "ERROR"
    Write-Log "  2. Enable Developer Options: Settings > About Phone > Build Number (tap 7x)" "ERROR"
    Write-Log "  3. Enable USB Debugging: Settings > Developer Options > USB Debugging" "ERROR"
    Write-Log "  4. Authorize USB debugging prompt on phone" "ERROR"
    exit 1
}

Write-Log "Device detected:"
$devices | Write-Host
Start-Sleep -Seconds 2

# ==============================================================================
# Create audit baseline
# ==============================================================================
if (-not $SkipBaseline) {
    Write-Log "Creating baseline audit..."
    
    if (-not (Test-Path $auditDir)) {
        New-Item -ItemType Directory -Path $auditDir | Out-Null
    }
    
    Write-Log "  - Capturing installed packages..."
    Invoke-ADB "shell pm list packages" | Out-File -FilePath "$auditDir\packages_baseline.txt"
    
    Write-Log "  - Capturing full package dump..."
    Invoke-ADB "shell dumpsys package" | Out-File -FilePath "$auditDir\package_dump.txt"
    
    Write-Log "  - Capturing running processes..."
    Invoke-ADB "shell ps -aux" | Out-File -FilePath "$auditDir\ps_baseline.txt" -ErrorAction SilentlyContinue
    
    Write-Log "  - Capturing network state..."
    Invoke-ADB "shell netstat" | Out-File -FilePath "$auditDir\netstat_baseline.txt" -ErrorAction SilentlyContinue
    
    Write-Log "  - Capturing logcat..."
    Invoke-ADB "logcat -d" | Out-File -FilePath "$auditDir\logcat_baseline.txt" -ErrorAction SilentlyContinue
    
    Write-Log "Baseline saved to: $auditDir"
    Write-Host "Review baseline artifacts before proceeding (press Enter to continue)..."
    Read-Host
}

# ==============================================================================
# Define core exclusions (NEVER REMOVE)
# ==============================================================================
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

# ==============================================================================
# Define bloatware packages to remove
# ==============================================================================
$bloatwarePackages = @(
    # AppCloud / Aura
    "com.ironsource.aura",
    "com.aura.oobe",
    "com.aura.oobe.att",
    "com.samsung.android.appcloud",
    "com.samsung.android.app.appcloud",
    
    # Carrier MSM
    "com.att.mobile_services_manager",
    "com.samsung.attvvm",
    "com.vzw.hss.myverizon",
    "com.verizonwireless.messaging",
    "com.samsung.vvm",
    "com.t_mobile.tmo_mail",
    "com.samsung.tmobileconfig",
    
    # Facebook
    "com.facebook.system",
    "com.facebook.appmanager",
    "com.facebook.services",
    
    # Samsung Promotional
    "com.samsung.android.app.news",
    "com.samsung.android.game.gametools",
    "com.samsung.android.game.gos",
    "com.samsung.android.arzone",
    "com.samsung.android.tvplus",
    "com.samsung.android.oneconnect",
    "com.samsung.android.app.watchmanager",
    "com.samsung.android.app.watchmanagerstub",
    "com.samsung.android.scloud",
    "com.samsung.android.app.dressroom",
    "com.samsung.android.aremoji",
    "com.samsung.android.aremojieditor",
    
    # Microsoft
    "com.microsoft.skydrive",
    "com.microsoft.office.officehubrow"
)

# ==============================================================================
# Display removal plan
# ==============================================================================
Write-Host ""
Write-Host "================================================================================"
Write-Host "REMOVAL PLAN"
Write-Host "================================================================================"
Write-Host ""
Write-Host "Core exclusions (PROTECTED - will NOT be touched):"
$coreExclusions | ForEach-Object { Write-Host "  - $_" }

Write-Host ""
Write-Host "Packages to remove (total: $($bloatwarePackages.Count)):"
$bloatwarePackages | ForEach-Object { Write-Host "  - $_" }

Write-Host ""
Write-Host "WARNING: This will disable/remove apps. Some may reappear after OTA updates."
Write-Host "All removals are non-root and reversible via: adb shell cmd package install-existing <pkg>"
Write-Host ""

if (-not $DryRun) {
    $confirm = Read-Host "Continue? (Y/N)"
    if ($confirm -ne "Y") {
        Write-Log "Cancelled by user"
        exit 0
    }
}

# ==============================================================================
# Remove bloatware
# ==============================================================================
Write-Host ""
Write-Host "================================================================================"
Write-Host "REMOVING BLOATWARE"
Write-Host "================================================================================"
Write-Host ""

$removed = 0
$failed = 0
$skipped = 0

foreach ($pkg in $bloatwarePackages) {
    # Check if package exists
    $installed = Invoke-ADB "shell pm list packages" | Select-String $pkg
    
    if ($installed) {
        Write-Log "Removing: $pkg"
        
        if ($DryRun) {
            Write-Host "  [DRY RUN] Would remove: $pkg"
            $removed++
        } else {
            $output = Invoke-ADB "shell pm uninstall --user 0 $pkg"
            
            if ($output -match "Success") {
                Write-Log "  [+] Removed successfully"
                $removed++
            } else {
                Write-Log "  [!] Uninstall failed, trying disable..."
                $output = Invoke-ADB "shell pm disable-user --user 0 $pkg"
                
                if ($output -match "Success") {
                    Write-Log "  [+] Disabled instead"
                    $removed++
                } else {
                    Write-Log "  [!] Failed to disable" "WARN"
                    $failed++
                }
            }
        }
    } else {
        Write-Log "  [-] Skipped: $pkg (not installed)"
        $skipped++
    }
}

# ==============================================================================
# Permission Hardening
# ==============================================================================
Write-Host ""
Write-Host "================================================================================"
Write-Host "PERMISSION HARDENING"
Write-Host "================================================================================"
Write-Host ""
Write-Log "Exporting current permissions audit..."

$packages = Invoke-ADB "shell pm list packages"
$permissionsFile = "$auditDir\permissions_audit.txt"

foreach ($line in $packages) {
    if ($line -match "package:(.+)") {
        $pkgName = $matches[1]
        $perms = Invoke-ADB "shell dumpsys package $pkgName"
        $perms | Select-String "android.permission" | Out-File -FilePath $permissionsFile -Append
    }
}

Write-Log "Permission audit saved to: $permissionsFile"
Write-Host "[*] Manual permission hardening required:"
Write-Host "    - Open Settings > Apps > Permissions"
Write-Host "    - Review and deny Location, Camera, Microphone, SMS, Contacts access"
Write-Host "    - Keep permissions only for necessary apps (Phone, Messaging, Maps, Camera)"

# ==============================================================================
# Create post-hardening snapshot
# ==============================================================================
Write-Log "Creating post-hardening snapshot..."
Invoke-ADB "shell pm list packages" | Out-File -FilePath "$auditDir\packages_after.txt"
Invoke-ADB "shell dumpsys package" | Out-File -FilePath "$auditDir\package_dump_after.txt"

# ==============================================================================
# Summary
# ==============================================================================
Write-Host ""
Write-Host "================================================================================"
Write-Host "SUMMARY"
Write-Host "================================================================================"
Write-Host "Removed/Disabled: $removed"
Write-Host "Failed: $failed"
Write-Host "Skipped: $skipped"
Write-Host ""
Write-Host "Audit directory: $auditDir"
Write-Host "Log file: $logFile"
Write-Host ""
Write-Host "Next Steps:"
Write-Host "  1. Review audit artifacts in $auditDir"
Write-Host "  2. Test core functionality (calls, SMS, camera, etc.)"
Write-Host "  3. Monitor battery and data usage for anomalies"
Write-Host "  4. Run anomaly detection periodically: .\anomaly_detect.ps1"
Write-Host ""
Write-Host "To verify removals:"
Write-Host "  adb shell pm list packages | Select-String 'aura|facebook|samsung'"
Write-Host ""
Write-Host "To restore a package:"
Write-Host "  adb shell cmd package install-existing <package_name>"
Write-Host ""
Write-Host "================================================================================"
Write-Host "Hardening completed at: $(Get-Date)"
Write-Host "================================================================================"
Write-Host ""

Write-Log "Hardening script completed successfully"
