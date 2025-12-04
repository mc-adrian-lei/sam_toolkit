# ==============================================================================
# Samsung Galaxy A15/A16 Anomaly Detection Script (PowerShell)
# Purpose: Detect suspicious activity post-hardening
# Author: Security Research
# Date: December 2025
# ==============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BaselineDir,
    
    [switch]$Verbose = $false
)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = "anomaly_report_$timestamp.txt"

# Logging function
function Write-Report {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $entry
    Add-Content -Path $reportFile -Value $entry
}

Write-Host ""
Write-Host "================================================================================"
Write-Host "Samsung A15/A16 Anomaly Detection"
Write-Host "Report: $reportFile"
Write-Host "Baseline: $BaselineDir"
Write-Host "================================================================================"
Write-Host ""

Write-Report "Anomaly Detection started"

# Verify baseline directory
if (-not (Test-Path $BaselineDir)) {
    Write-Report "Baseline directory not found: $BaselineDir" "ERROR"
    exit 1
}

# Verify device connection
Write-Report "Checking device connection..."
$devices = & adb devices 2>&1 | Select-String "device$" | Where-Object { $_ -notmatch "List of" }

if ($devices.Count -eq 0) {
    Write-Report "No ADB device connected!" "ERROR"
    exit 1
}

Write-Report "Device connected"
Write-Host ""

# ==============================================================================
# Anomaly Detection Checks
# ==============================================================================

Write-Report "================================================================================"
Write-Report "ANOMALY DETECTION REPORT"
Write-Report "================================================================================"

# Check 1: New packages
Write-Host "[*] Check 1: Detecting unexpected new packages..."
Write-Report "--- NEW PACKAGES CHECK ---"

$currentPackages = & adb shell pm list packages 2>&1
$baselinePackages = Get-Content "$BaselineDir\packages_baseline.txt"

$newPackages = @()
foreach ($line in $currentPackages) {
    if ($line -notin $baselinePackages -and $line.StartsWith("package:")) {
        $newPackages += $line
    }
}

if ($newPackages.Count -eq 0) {
    Write-Report "[+] No new packages detected"
    Write-Host "[+] No new packages detected"
} else {
    Write-Report "[!] NEW PACKAGES DETECTED:"
    Write-Host "[!] New packages detected:"
    foreach ($pkg in $newPackages) {
        Write-Report "    $pkg"
        Write-Host "    $pkg"
    }
}

# Check 2: Battery & System Stats
Write-Host "[*] Check 2: Analyzing battery and system stats..."
Write-Report "--- BATTERY AND SYSTEM STATS ---"

$battery = & adb shell dumpsys batterymanager 2>&1
$battery | ForEach-Object {
    Write-Report $_
}

# Check 3: Location Services
Write-Host "[*] Check 3: Checking location services..."
Write-Report "--- LOCATION SERVICES CHECK ---"

$location = & adb shell settings get secure location_providers_allowed 2>&1

if ([string]::IsNullOrWhiteSpace($location)) {
    Write-Report "[+] Location services disabled"
    Write-Host "[+] Location services disabled"
} else {
    Write-Report "[!] Location services active: $location"
    Write-Host "[!] Location services active: $location"
}

# Check 4: Suspicious Processes
Write-Host "[*] Check 4: Checking for suspicious processes..."
Write-Report "--- SUSPICIOUS PROCESS SCAN ---"

$suspiciousPatterns = @("ironsource", "aura", "appcloud", "tracking", "survey", "facebook")
$processes = & adb shell ps -aux 2>&1

$foundSuspicious = $false
foreach ($pattern in $suspiciousPatterns) {
    $matches = $processes | Select-String -Pattern $pattern -CaseSensitive:$false
    
    if ($matches) {
        Write-Report "[!] SUSPICIOUS PROCESS DETECTED: $pattern"
        Write-Host "[!] Suspicious process detected: $pattern"
        foreach ($match in $matches) {
            Write-Report "    $match"
            Write-Host "    $match"
        }
        $foundSuspicious = $true
    }
}

if (-not $foundSuspicious) {
    Write-Report "[+] No known suspicious processes found"
    Write-Host "[+] No known suspicious processes detected"
}

# Check 5: Network Activity
Write-Host "[*] Check 5: Checking active network connections..."
Write-Report "--- NETWORK CONNECTIONS ---"

$netstat = & adb shell netstat 2>&1
$established = $netstat | Select-String "ESTABLISHED"

if ($established) {
    Write-Report "Active established connections:"
    Write-Host "Active established connections:"
    foreach ($conn in $established) {
        Write-Report "    $conn"
        Write-Host "    $conn"
    }
} else {
    Write-Report "[+] No unusual network activity detected"
    Write-Host "[+] No unusual network activity detected"
}

# Check 6: Permission Changes
Write-Host "[*] Check 6: Checking permission changes..."
Write-Report "--- PERMISSIONS AUDIT ---"

$dumpsys = & adb shell dumpsys package 2>&1
$dangerous = @("RECORD_AUDIO", "CAMERA", "ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION")

$found = $false
foreach ($perm in $dangerous) {
    $matches = $dumpsys | Select-String $perm
    if ($matches) {
        Write-Report "[!] Dangerous permission detected: $perm"
        Write-Host "[!] Dangerous permission detected: $perm"
        $found = $true
    }
}

if (-not $found) {
    Write-Report "[+] No unexpected dangerous permissions found"
    Write-Host "[+] No unexpected dangerous permissions detected"
}

# ==============================================================================
# Summary
# ==============================================================================
Write-Host ""
Write-Host "================================================================================"
Write-Host "REPORT GENERATED: $reportFile"
Write-Host "================================================================================"
Write-Host ""
Write-Host "Recommendations:"
Write-Host "  - Review $reportFile for full details"
Write-Host "  - If suspicious packages detected, investigate:"
Write-Host "      adb shell pm dump <package_name>"
Write-Host "  - To uninstall suspicious packages:"
Write-Host "      adb shell pm uninstall --user 0 <package_name>"
Write-Host ""

Write-Report "================================================================================"
Write-Report "Anomaly detection completed"
Write-Report "================================================================================"
