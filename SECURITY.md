# Security Policy

The **Simulation Tray** (Tray) development team takes the security of our application, our users, and their development environments very seriously. This document outlines our security policies, supported versions, vulnerability reporting process, and guidance on binary verification and Windows Defender SmartScreen.

---

## 🛡️ Supported Versions

We provide security updates and patches for the current major release series. Users are strongly encouraged to update to the latest release to receive the newest security enhancements and bug fixes.

| Version | Supported          | Status                                 |
| :------ | :----------------- | :------------------------------------- |
| 1.2.x   | :white_check_mark: | Active support and maintenance         |
| 1.1.x   | :x:                | Superseded (upgrade to 1.2.x)          |
| < 1.1.0 | :x:                | End of life                            |

---

## 🔒 Reporting a Vulnerability

If you discover a security vulnerability or potential threat in Simulation Tray, **please report it privately**. Do not disclose security vulnerabilities publicly through public GitHub issues, discussions, or social media until a fix has been prepared and released.

### Preferred Method: GitHub Private Vulnerability Reporting
You can report a vulnerability directly and securely through GitHub Advisories:
👉 **[Open a Private Security Advisory](https://github.com/Rosdeb/Tray/security/advisories/new)**

### Alternative Method
If you are unable to use GitHub Advisories, you may email our security team directly:
- **Email**: `security@simulationtray.internal` *(or open a confidential inquiry via repository maintainer profile)*
- Please include **[SECURITY]** in the subject line.

### What to Include in Your Report
To help us triage and resolve the issue quickly, please provide as much detail as possible:
- **Summary**: Description of the vulnerability and its potential impact.
- **Affected Component**: E.g., ADB orchestrator, Inno Setup installer, UpdateService, Process Manager, scrcpy integration.
- **Steps to Reproduce**: Detailed step-by-step instructions or a minimal Proof of Concept (PoC).
- **Environment**: Operating System version (Windows 10/11 or macOS Intel/Apple Silicon), Tray version.
- **Mitigation**: Any known workarounds or suggested fixes.

---

## ⏱️ Response Timelines & SLA

When a security report is submitted:

| Milestone | Target Response Time | Action |
| :--- | :--- | :--- |
| **Initial Acknowledgement** | Within 24–48 hours | Confirmation of report receipt and initial assessment |
| **Triage & Validation** | Within 3–5 business days | Reproduction and severity classification (CVSS) |
| **Fix Development** | Within 7–14 days | Implementation and internal regression testing |
| **Public Release & Advisory** | Coordinated | Release of patched installer and publication of GitHub Security Advisory |

---

## 💻 Windows Defender SmartScreen & "Run Anyway" Notice

### Why Does SmartScreen Show "Unrecognized App"?
When downloading and running `Tray-Setup.exe` on Windows 10 or 11, you may encounter a prompt:
> **"Windows protected your PC — Microsoft Defender SmartScreen prevented an unrecognized app from starting."**

**This is completely normal for newly released open-source applications.**
- Simulation Tray is fully open-source and built transparently on GitHub Actions.
- Commercial Extended Validation (EV) code-signing certificates cost hundreds of dollars per year. As an open-source project, binaries establish SmartScreen reputation automatically as downloads increase across users.
- Our code does **not** contain telemetry, spyware, adware, or unauthorized background miners.

### How to Safely Run the Installer:
1. When the SmartScreen dialog appears, click **"More info"**.
2. Verify that the Application says **`Tray-Setup.exe`** (or `tray.exe`).
3. Click the **"Run anyway"** button.

### How to Cryptographically Verify Release Binaries
Every official release publishes SHA-256 checksums generated directly by the GitHub Actions builder. You can verify the integrity of your download before executing:

**On Windows (PowerShell):**
```powershell
# Calculate SHA-256 hash
Get-FileHash .\Tray-Setup.exe -Algorithm SHA256
```

**On macOS (Terminal):**
```bash
# Calculate SHA-256 hash
shasum -a 256 Tray.dmg
```

Compare the calculated hash with the hash published in the official [GitHub Release](https://github.com/Rosdeb/Tray/releases). If the hashes match, your file is authentic, clean, and has not been altered.

---

## 🔄 Automatic In-App Updates & Process Safety

Simulation Tray includes an integrated update client (`UpdateService`):
- Updates are fetched strictly over secure **HTTPS** from official GitHub Release endpoints.
- During installation, the updater safely signals running `tray.exe` instances to terminate (`/CLOSEAPPLICATIONS`) to avoid file-lock errors.
- Binaries are extracted to standard non-privileged directories (`%LOCALAPPDATA%\Programs\Tray` or `Program Files`) with atomic file replacements.

---

## ⚙️ Hardware, BIOS & System Security Boundary

1. **No Direct Motherboard Flashing**: Tray deliberately **does not** flash motherboard firmware or write raw data to UEFI flash memory. Flashing firmware without vendor-signed cryptographic signatures risks permanent hardware damage ("bricking").
2. **Safe UEFI Reboot**: The app uses standard Windows administrative APIs (`shutdown.exe /r /fw`) to restart directly into UEFI setup, giving full control to the user.
3. **Localhost Socket Isolation**: ADB daemon communication and emulator console ports are bound strictly to `127.0.0.1` (localhost), preventing remote access over local networks.

---

*Thank you for helping keep Simulation Tray and our developer community safe!*
