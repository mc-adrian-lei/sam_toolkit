# Samsung Galaxy A15/A16 Hardening Toolkit — Windows Scripts

## Overview

This toolkit provides **Windows-based scripts** (Batch and PowerShell) to:

1. **Harden** Samsung Galaxy A15/A16 devices by removing surveillance bloatware (AppCloud/Aura, Facebook, carrier MSM, etc.)
2. **Preserve** all critical system components and evidence chains
3. **Audit** and **detect anomalies** after hardening to catch misuse

All operations are **non-root** and execute through ADB (Android Debug Bridge), making them reversible and safe.

---

## Quick Start

### Prerequisites

1. **Android Debug Bridge (ADB)** installed and in your system PATH
   - Download: https://developer.android.com/tools/adb
   - Or install via: `choco install adb` (Windows via Chocolatey)

2. **Samsung Galaxy A15 or A16** connected via USB cable

3. **Developer Options enabled** on phone:
   - Settings > About Phone > Build Number (tap 7 times)
   - Settings > Developer Options > USB Debugging (toggle ON)
   - Authorize USB debugging when prompted

### Running the Hardening Script

**Option 1: Windows Batch (CMD)**

```batch
.\samsung_hardening.bat
```

Or from Command Prompt:

```cmd
cd \path\to\scripts
samsung_hardening.bat
```

**Option 2: PowerShell**

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\samsung_hardening.ps1
```

Both scripts will:
- ✓ Verify ADB and device connection
- ✓ Create a baseline audit (before state)
- ✓ Display removal plan for review
- ✓ Ask for user confirmation
- ✓ Remove/disable bloatware packages
- ✓ Create post-hardening snapshot (after state)
- ✓ Generate audit reports and logs

---

## Script Details

### samsung_hardening.bat

Pure Windows Batch script—no dependencies beyond ADB.

**Features:**
- Device connection verification
- Baseline capture and hashing
- Package removal with error handling
- Logging to timestamped file (`hardening_YYYYMMDD_HHMMSS.log`)
- Post-hardening snapshot for comparison
- Audit artifacts in `audit_baseline_YYYYMMDD_HHMMSS/` directory

**Usage:**
```batch
.\samsung_hardening.bat
```

**Output:**
```
hardening_20251204_134502.log
audit_baseline_20251204_134502/
  ├── packages_baseline.txt
  ├── packages_after.txt
  ├── package_dump.txt
  ├── ps_baseline.txt
  ├── netstat_baseline.txt
  └── logcat_baseline.txt
```

---

### samsung_hardening.ps1

PowerShell script with additional features and cleaner error handling.

**Features:**
- Device verification
- Baseline capture
- Configurable dry-run mode
- Skip-baseline option
- Detailed logging
- Post-hardening analysis

**Usage:**

```powershell
# Standard run
.\samsung_hardening.ps1

# Dry run (show what would be removed without making changes)
.\samsung_hardening.ps1 -DryRun

# Skip baseline (if already created)
.\samsung_hardening.ps1 -SkipBaseline

# Verbose output
.\samsung_hardening.ps1 -Verbose
```

**Output:**
```
hardening_20251204_134502.log
audit_baseline_20251204_134502/
  ├── packages_baseline.txt
  ├── packages_after.txt
  ├── package_dump.txt
  ├── package_dump_after.txt
  ├── ps_baseline.txt
  ├── permissions_audit.txt
  └── logcat_baseline.txt
```

---

### anomaly_detect.bat

Detects suspicious activity after hardening.

**Features:**
- Compares current state to baseline
- Detects new packages
- Checks location services, battery, network
- Scans for suspicious processes
- Audits dangerous permissions

**Usage:**
```batch
.\anomaly_detect.bat audit_baseline_20251204_134502
```

**Output:**
```
anomaly_report_20251204_140530.txt
```

**Example Report Content:**
```
[2025-12-04 14:05:30] [INFO] --- NEW PACKAGES CHECK ---
[2025-12-04 14:05:31] [INFO] [+] No new packages detected

[2025-12-04 14:05:32] [INFO] --- LOCATION SERVICES CHECK ---
[2025-12-04 14:05:32] [INFO] Location providers: 

[2025-12-04 14:05:33] [INFO] --- SUSPICIOUS PROCESS SCAN ---
[2025-12-04 14:05:33] [INFO] [+] No known suspicious processes found
```

---

### anomaly_detect.ps1

PowerShell anomaly detection with structured reporting.

**Usage:**
```powershell
.\anomaly_detect.ps1 -BaselineDir audit_baseline_20251204_134502

# With verbose output
.\anomaly_detect.ps1 -BaselineDir audit_baseline_20251204_134502 -Verbose
```

---

## What Gets Removed

### HIGH PRIORITY (Surveillance/Tracking)

**AppCloud / Aura (IronSource)** — Primary spyware concern
```
com.ironsource.aura
com.aura.oobe
com.aura.oobe.att
com.samsung.android.appcloud
com.samsung.android.app.appcloud
```

### Medium Priority (Carrier Bloat)

**Mobile Services Manager (MSM)**
```
com.att.mobile_services_manager
com.vzw.hss.myverizon
com.t_mobile.tmo_mail
com.samsung.attvvm
```

### Social/Ad-Tech

**Facebook Spyware Layers**
```
com.facebook.system
com.facebook.appmanager
com.facebook.services
```

### Samsung Promotional

```
com.samsung.android.app.news
com.samsung.android.game.gametools
com.samsung.android.tvplus
com.samsung.android.oneconnect
com.samsung.android.arzone
... (and 10+ more promo apps)
```

### Microsoft

```
com.microsoft.skydrive
com.microsoft.office.officehubrow
```

---

## What Does NOT Get Removed

### CORE EXCLUSIONS (Protected)

These are **never touched** to ensure stability and evidence preservation:

```
android                           # Android System Framework
com.android.systemui             # System UI
com.android.settings             # Settings App
com.android.packageinstaller     # Package Manager
com.google.android.gms           # Google Play Services
com.android.vending              # Google Play Store
com.android.keychain             # Credential Storage
com.samsung.android.ims          # IMS (calling)
com.sec.telephony                # Telephony
com.android.permission           # Permission Manager
... (and others for security/comms)
```

---

## Workflow

### Step 1: Create Baseline
```
Device State Before Hardening
        ↓
   Create Audit Snapshot
   (packages, permissions, processes, network)
        ↓
   Saved to: audit_baseline_YYYYMMDD_HHMMSS/
```

### Step 2: Review & Remove
```
Display Removal Plan
        ↓
   User Confirmation (Y/N)
        ↓
   For each package:
     1. Check if installed
     2. Attempt uninstall via adb shell pm uninstall --user 0
     3. If fails, disable via adb shell pm disable-user --user 0
        ↓
   Log results (removed, failed, skipped)
```

### Step 3: Create Post-Hardening Snapshot
```
Device State After Hardening
        ↓
   Capture packages_after.txt
   Capture package_dump_after.txt
        ↓
   User compares baseline/ vs. after for verification
```

### Step 4: Ongoing Monitoring
```
Run anomaly_detect.bat/ps1 weekly
        ↓
   Compare current state to baseline
   Detect new packages, suspicious processes
        ↓
   Generate report: anomaly_report_YYYYMMDD_HHMMSS.txt
```

---

## Commands Reference

### ADB Setup (on Phone)

Enable Developer Mode:
```
Settings > About Phone > Software Information > Build Number (tap 7 times)
```

Enable USB Debugging:
```
Settings > Developer Options > USB Debugging (toggle ON)
```

### Manual ADB Commands (if needed)

List all packages:
```cmd
adb shell pm list packages
```

Uninstall a package (non-root):
```cmd
adb shell pm uninstall --user 0 com.package.name
```

Disable a package:
```cmd
adb shell pm disable-user --user 0 com.package.name
```

Restore a package:
```cmd
adb shell cmd package install-existing com.package.name
```

Check if package exists:
```cmd
adb shell pm list packages | findstr "package_name"
```

Check package permissions:
```cmd
adb shell dumpsys package com.package.name | findstr "permission"
```

View running processes:
```cmd
adb shell ps -aux
```

Check network connections:
```cmd
adb shell netstat
adb shell ss -tuln
```

---

## Troubleshooting

### Error: "ADB not found in PATH"

**Solution:** Install Android Debug Bridge
- Download: https://developer.android.com/tools/adb
- Add to PATH or place `adb.exe` in same directory as scripts

### Error: "No ADB device connected"

**Steps:**
1. Connect phone via USB cable
2. On phone: Settings > Developer Options > USB Debugging (toggle ON)
3. Tap "Allow USB Debugging" when prompted
4. Run script again

### Error: "Failed to disable/remove package"

**Reason:** Package is protected system app (safe to skip)

**Solution:** Manually remove only if absolutely necessary
```cmd
adb shell pm uninstall --user 0 com.package.name
```

### Device keeps prompting for USB authorization

**Solution:** Uncheck "Always allow from this computer" option if checked, then reauthorize

### Script hangs waiting for device

**Solution:** 
1. Disconnect USB
2. Re-connect USB
3. Reauthorize on phone
4. Run script again

---

## Evidence Preservation & Reporting

### Audit Artifacts

Each hardening creates a timestamped audit directory with baseline snapshots:

```
audit_baseline_20251204_134502/
  ├── packages_baseline.txt         # All installed packages BEFORE
  ├── packages_after.txt            # All installed packages AFTER
  ├── package_dump.txt              # Full package metadata BEFORE
  ├── package_dump_after.txt        # Full package metadata AFTER
  ├── ps_baseline.txt               # Running processes BEFORE
  ├── netstat_baseline.txt          # Network state BEFORE
  ├── logcat_baseline.txt           # System logs BEFORE
  └── permissions_audit.txt         # Permission audit
```

**Comparisons:**
```cmd
fc packages_baseline.txt packages_after.txt > diff.txt
```

### Log Files

Each run generates a detailed log:
```
hardening_20251204_134502.log
anomaly_report_20251204_140530.txt
```

**For investigations/reporting:** Archive audit directories and logs with timestamps for chain of custody.

---

## Whistleblower & Safe Escalation

If anomaly detection reveals misuse:

### Preserve Evidence
1. Export audit logs and diffs
2. Take screenshots
3. Document timestamps and anomalies
4. Use separate device for research

### Report Channels
- **US:** FBI Tip Line, DOJ Corruption Hotline, GAO FraudNet, State AG
- **Whistleblower Protection:** Consult attorney before filing
- **Retaliation is actionable:** Document link between disclosure and adverse actions

---

## Safety & Recovery

### All Removals Are Reversible

The `--user 0` flag means:
- ✓ Non-root execution
- ✓ Can be reversed: `adb shell cmd package install-existing com.package.name`
- ✓ Factory reset restores all preloaded apps
- ✓ OTA updates may reinstall bloatware

### Core Stability

Scripts protect all critical Android and Samsung services:
- ✓ System framework and UI
- ✓ Telephony, IMS, messaging
- ✓ Security and keystore
- ✓ OTA/update mechanisms
- ✓ Google Play ecosystem (if used)

### If Device Breaks

**Factory Reset:**
```
Settings > General Management > Reset > Factory Reset
(Wipes data; restores all apps)
```

**Or restore from backup:**
```
Plug into PC with Samsung Kies/SmartSwitch
Restore from backup
```

---

## Advanced Usage

### Dry Run Mode (PowerShell)

Test without making changes:
```powershell
.\samsung_hardening.ps1 -DryRun
```

### Skip Baseline (Reuse Existing)

```powershell
.\samsung_hardening.ps1 -SkipBaseline
```

### Custom Baseline Location (Manual)

```cmd
copy audit_baseline_20251204_134502 my_custom_audit
.\anomaly_detect.bat my_custom_audit
```

### Export Audit for External Review

```cmd
7z a -r audit_archive.7z audit_baseline_20251204_134502 hardening_*.log
```

---

## FAQs

**Q: Will these scripts root my phone?**  
A: No. All operations use `pm uninstall --user 0` which is non-root and safe.

**Q: Can I undo changes?**  
A: Yes. Use `adb shell cmd package install-existing <pkg>` or factory reset.

**Q: Will OTA updates reinstall bloatware?**  
A: Possibly. Some preloaded apps may reappear; rerun hardening after major updates.

**Q: Can I use these scripts on other Samsung models?**  
A: Yes. Most bloatware packages are common across Samsung phones. Core exclusions may vary slightly by region/variant.

**Q: Does this affect functionality?**  
A: No. Only removes promo/telemetry/ad-tech apps. All core features (calls, SMS, camera, etc.) remain intact.

**Q: How often should I run anomaly detection?**  
A: Weekly or bi-weekly; more frequently if investigating suspected misuse.

---

## Support & Documentation

- **Android Security:** https://developer.android.com/privacy-and-security
- **ADB Documentation:** https://developer.android.com/tools/adb
- **Samsung Knox:** https://www.samsungknox.com/en
- **SMEX Research (AppCloud/Aura):** https://www.alestiklal.net/en/article/samsung-s-aura-israeli-spyware-in-your-pocket

---

## Version Info

**Version:** 1.0  
**Date:** December 4, 2025  
**Tested On:** Windows 10, Windows 11 (with ADB)  
**Compatible Devices:** Samsung Galaxy A15, A16 (and similar models)  
**Execution:** Non-root, user 0, reversible  

---

## Legal Disclaimer

This toolkit is for **personal device hardening and security research** purposes only.

- Users are responsible for their own devices
- Removing system apps may violate device warranties
- Always create backups before major changes
- Consult legal counsel if investigating suspected misuse or government abuse

---

## Changelog

### v1.0 (2025-12-04)
- Initial release
- Batch and PowerShell hardening scripts
- Anomaly detection (Batch and PowerShell)
- Comprehensive documentation
- Support for A15/A16
- AppCloud/Aura, Facebook, carrier MSM, Samsung promo removals
- Core component protection
- Audit and chain-of-custody support
# Batch version
.\samsung_hardening.bat

# Or PowerShell version
.\samsung_hardening.ps1

# Later, check for anomalies:
.\anomaly_detect.bat audit_baseline_20251204_134502
# or
.\anomaly_detect.ps1 -BaselineDir audit_baseline_20251204_134502
