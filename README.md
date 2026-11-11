# Simulation Tray (Tray)

<div align="center">

![Simulation Tray Logo](assets/icons/app_icon.png)

### The Lightweight, Studio-Free Android Emulator Manager for Windows & macOS

[![Release](https://img.shields.io/github/v/release/Rosdeb/Tray?style=for-the-badge&color=blue)](https://github.com/Rosdeb/Tray/releases)
[![Build & Release](https://img.shields.io/github/actions/workflow/status/Rosdeb/Tray/android-release.yml?style=for-the-badge&label=Build%20CI%2FCD)](https://github.com/Rosdeb/Tray/actions)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS-informational?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/Rosdeb/Tray/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.44+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Security Policy](https://img.shields.io/badge/Security-Policy-blueviolet?style=for-the-badge&logo=shield)](SECURITY.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

**Simulation Tray** is a modern, high-performance desktop emulator workstation that lets you create, download, configure, launch, monitor, and screen-mirror Android Virtual Devices (AVDs) **without needing Android Studio or heavy IDEs running in the background**.

[Download Latest Release](https://github.com/Rosdeb/Tray/releases/latest) • [Key Features](#-key-features) • [Installation](#-installation) • [Security Policy](SECURITY.md) • [Usage Guide](#-usage-guide) • [Architecture](#-architecture)

</div>

---

## 🚀 Why Simulation Tray?

Android Studio is a powerful IDE, but it consumes gigabytes of memory and substantial CPU resources just to manage and start virtual test devices.

**Simulation Tray** decouples emulator lifecycle and device management from the IDE:
- **Zero Android Studio Dependency**: Fully manages the Android SDK, Adoptium Temurin JDK 17, and command-line tools autonomously.
- **Ultra-Low Memory Footprint**: Uses only a fraction of RAM compared to heavyweight IDEs.
- **Instant Device Creation**: Choose from pre-configured Google Pixel, Foldable, Tablet, and Desktop profiles and download Google APIs system images on demand.
- **Direct Low-Latency Screen Mirroring**: Control and view running emulators or real Android hardware at 60+ FPS using integrated `scrcpy`.
- **Cross-Platform Native Experience**: Built for Windows 10/11 (`.exe` installer) and macOS Apple Silicon & Intel (`.dmg`).

---

## ✨ Key Features

### 1. 📦 Standalone SDK & Environment Manager (No Studio Needed)
- **1-Click Automated Setup**: Downloads and installs Eclipse Adoptium Temurin OpenJDK 17, Google Command-Line Tools (`cmdline-tools`), Android Emulator (QEMU engine), and Platform-Tools (ADB).
- **Automated License Agreement**: Generates and persists required SDK license hashes (`android-sdk-license`, etc.) automatically.
- **Flexible Path Detection**: Automatically discovers existing Android SDKs (`ANDROID_HOME`, `ANDROID_SDK_ROOT`, standard user directories) or allows you to specify a custom folder.

### 2. 📱 Modern Virtual Device Studio
- **Pre-Configured Hardware Profiles**:
  - **Phones**: Google Pixel 9 Pro, Pixel 9, Pixel 8 Pro, Pixel 8, Pixel 7 Pro, Pixel 7, Pixel 6 Pro, Pixel 6, Medium Phone.
  - **Foldables & Tablets**: Google Pixel Fold, Pixel Tablet, 10.1" WXGA Tablet, 7" WSVGA Tablet.
  - **Specialty Profiles**: Resizable Device (multi-form-factor testing) and Android TV (1080p).
- **Target OS Catalog**: Android 15 (API 35), Android 14 (API 34), Android 13 (API 33), Android 12L (API 32), Android 12 (API 31), Android 11 (API 30).
- **On-Demand System Image Downloader**: If a required system image is not on disk, Tray downloads and extracts it via `sdkmanager` in the background with real-time progress.
- **Advanced Hardware Customization**:
  - RAM allocation (1 GB up to 16 GB).
  - CPU cores assignment (1 to 16 cores).
  - Internal data partition sizing (2 GB up to 64 GB).
  - GPU rendering acceleration mode: `auto`, `host` (native GPU), `swiftshader_indirect` (software), `angle_indirect`.
  - Physical keyboard forwarding toggle.

### 3. 📺 Ultra-Fast Screen Mirroring (`scrcpy` Integration)
- **Direct Mirroring**: Stream running virtual emulators and connected physical Android devices in a responsive, low-latency window.
- **Deep Windows & macOS Auto-Detection**:
  - Scans system `PATH`, Windows Registry environment tables, WinGet links & packages, Scoop, and Chocolatey.
  - Recursively checks unzipped archives in `Downloads`, `Desktop`, `C:\scrcpy*`, and `Program Files`.
  - Scans macOS Homebrew (`/opt/homebrew`, `/usr/local/bin`) and MacPorts locations.
- **Conflict-Free ADB Integration**: Automatically coordinates with Tray's internal ADB server to prevent version mismatch disconnections.
- **Custom Executable & Folder Picker**: Manually choose your `scrcpy.exe` binary or folder anytime with instant validation.

### 4. ⚡ Process Manager & System Diagnostics
- **Live Hardware Acceleration Check**: Real-time detection of WHPX (Windows Hypervisor Platform), AEHD (Android Emulator Hypervisor Driver), macOS Hypervisor.framework, and Linux KVM.
- **Active Task Manager**: Real-time monitoring of all ADB, QEMU emulator, and `scrcpy` background processes with CPU/memory footprint and one-click termination of orphan/frozen processes.
- **Port Manager**: Prevents ADB port collisions by automatically assigning distinct emulator console and ADB ports.

### 5. 🎨 Desktop-First User Experience
- **Smooth Dashboard**: Clean, responsive layout with smooth skeleton loading animations and instant status filters (All, Running, Favorites).
- **System Tray Integration**: Minimize Tray to the Windows Notification Area or macOS Menu Bar; quickly access devices from the tray menu.
- **Theme Personalization**: Full Dark, Light, and System adaptive Material 3 themes with Cupertino visual accents.
- **Auto-Update Checker**: Built-in GitHub Release notifier that informs you when a new version is available.

---

## 📥 Installation

Download the latest pre-compiled binary for your operating system from the **[Releases Page](https://github.com/Rosdeb/Tray/releases)**.

### Windows (10 / 11)
1. Download **`Tray-Setup.exe`**.
2. Run the installer (built with Inno Setup) and follow the setup wizard.
   > **Note on Windows Defender SmartScreen ("Run anyway")**:
   > Because Simulation Tray is an open-source tool built on GitHub Actions without an expensive proprietary EV certificate, Windows SmartScreen may show *"Windows protected your PC — Microsoft Defender SmartScreen prevented an unrecognized app from starting"*.
   > 
   > **To proceed safely**:
   > 1. Click **"More info"**.
   > 2. Verify the application name is `Tray-Setup.exe`.
   > 3. Click **"Run anyway"**.
   > 
   > You can verify the file hash in PowerShell anytime against our official release SHA-256 checksums:
   > ```powershell
   > Get-FileHash .\Tray-Setup.exe -Algorithm SHA256
   > ```
3. Launch **Simulation Tray** from the Start Menu or Desktop shortcut. Subsequent in-app updates run automatically via the built-in update client.

### macOS (Apple Silicon & Intel)
1. Download **`Tray.dmg`** (or `Tray-macOS.zip`).
2. Open the `.dmg` disk image and drag **Tray** to your `/Applications` folder.
3. Open Tray from Applications or Spotlight. (On first launch, if prompted by macOS Gatekeeper, click *Open* or allow in *System Settings > Privacy & Security*).

---

## 📖 Usage Guide

### Initial Standalone Setup (Without Android Studio)
1. Open Tray and navigate to **Settings** (`⚙️` icon in sidebar).
2. Under **Standalone Android Environment**, click **Setup / Repair Android Environment**.
3. Select your desired SDK installation path (defaults to `%LOCALAPPDATA%\Android\Sdk` on Windows or `~/Library/Android/sdk` on macOS).
4. Click **Start Setup** — Tray will download OpenJDK 17, Google Command-Line Tools, accept licenses, install the emulator engine, and create your base device automatically.

### Creating a New Virtual Device
1. On the **Dashboard**, click the **Create Device** button (`+`).
2. **Select Device Profile**: Pick from the hardware catalog on the left (e.g., *Pixel 8 Pro*).
3. **Configure OS & Specs**:
   - Choose your target Android API level. If the system image is not yet installed, Tray will display a `Download on create` indicator and fetch it automatically.
   - Adjust RAM, CPU cores, storage size, and GPU rendering mode.
4. Click **Create Device**.

### Running & Mirroring
- **Run**: Click the **Run** (`▶`) button on any emulator card to boot.
- **Mirror**: Once running, click **Mirror** (`📺`) to open an ultra-low latency `scrcpy` mirroring window.
- **Cold Boot**: Click the `⋮` menu on any card and select **Cold boot (-no-snapshot-load)** to start with a clean snapshot state.
- **Stop**: Click **Stop** (`⏹`) to cleanly shut down the virtual device via `adb emu kill`.

---

## 🛠 Tech Stack & Architecture

- **Framework**: [Flutter Desktop](https://flutter.dev/multi-platform/desktop) (macOS & Windows Runner)
- **State Architecture**: [Riverpod 3](https://riverpod.dev) (`NotifierProvider`, `FutureProvider`, `StreamProvider`)
- **Desktop Window Management**: `window_manager` & `tray_manager`
- **Native Process Orchestration**: `dart:io` `Process.start` & `Process.run` with piped stdin streams
- **Packaging & Delivery**:
  - Windows: Inno Setup compiler (`.exe` installer)
  - macOS: `create-dmg` (`.dmg` disk image with volume icon)
  - CI/CD: Automated dual-runner GitHub Actions (`windows-latest` & `macos-14`)

```
lib/
├── core/
│   ├── constants/       # App constants, defaults, and API levels
│   ├── theme/           # Color schemes, typography, and dark/light themes
│   └── utils/           # Cross-platform paths, process helpers, container resolving
├── models/              # Immutable data models (Emulator, HardwareProfile, Process, Settings)
├── providers/           # Riverpod state controllers and reactive services
├── repositories/        # Hardware acceleration, emulator discovery, and device lifecycle
├── screens/
│   ├── dashboard/       # Main emulator grid, skeleton loaders, and quick stats
│   ├── settings/        # Standalone SDK setup, scrcpy configuration, and preferences
│   └── home_shell.dart  # Desktop shell navigation and window controls
├── services/            # ADB, QEMU, SdkInstaller, ScrcpyService, ProcessManager
└── widgets/             # CreateAvdDialog, SdkSetupDialog, EmulatorCard, StatTile
```

---

## 💻 Development & Building from Source

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.44.0` or higher)
- C++ Build Tools:
  - **Windows**: Visual Studio 2022 with Desktop development with C++
  - **macOS**: Xcode & Command Line Tools

### Clone & Run Locally

```bash
# Clone the repository
git clone https://github.com/Rosdeb/Tray.git
cd Tray

# Fetch dependencies
flutter pub get

# Run on macOS
flutter run -d macos

# Run on Windows
flutter run -d windows
```

### Run Tests & Analysis

```bash
# Static analysis (zero warnings target)
flutter analyze

# Unit and widget test suite
flutter test
```

---

## 🤝 Contributing

Contributions, bug reports, and feature suggestions are always welcome!
1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'feat: Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

Crafted with ❤️ by **[Rosdeb Koch](https://github.com/Rosdeb)**

</div>
