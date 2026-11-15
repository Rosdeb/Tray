# Simulation Tray (Tray)

<div align="center">

![Simulation Tray Logo](assets/icons/app_icon.png)

### The Featherweight, Studio-Free Android Device Workstation for Windows & macOS

[![Release](https://img.shields.io/github/v/release/Rosdeb/Tray?style=for-the-badge&color=blue)](https://github.com/Rosdeb/Tray/releases)
[![Build & Release](https://img.shields.io/github/actions/workflow/status/Rosdeb/Tray/android-release.yml?style=for-the-badge&label=Build%20CI%2FCD)](https://github.com/Rosdeb/Tray/actions)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS-informational?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/Rosdeb/Tray/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.44+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Security Policy](https://img.shields.io/badge/Security-Policy-blueviolet?style=for-the-badge&logo=shield)](SECURITY.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

**Simulation Tray** is a modern, high-performance desktop workstation designed to create, configure, boot, screen-mirror, analyze, and inspect Android Virtual Devices (AVDs) and connected physical phones **without ever launching Android Studio or heavy IDEs**.

[Download Latest Release](https://github.com/Rosdeb/Tray/releases/latest) • [Why Use Tray?](#-why-use-simulation-tray) • [Key Features](#-key-features) • [Installation](#-installation) • [Usage Guide](#-usage-guide) • [Architecture](#-architecture)

</div>

---

## 🚀 Why Use Simulation Tray?

### The Problem with Traditional Android Emulation
When developing with modern cross-platform stacks—such as **Flutter, React Native, Expo, Kotlin Multiplatform (KMP), Ionic, or Unity**—most developers write code in lightweight editors like **VS Code, Cursor, Zed, Sublime Text, or Neovim**.

However, to start an emulator or view device logs, developers are typically forced to open **Android Studio**:
- **Memory Hog**: Android Studio routinely consumes **3 GB to 6 GB+ of RAM** just idling in the background.
- **Sluggish Launch Times**: Waiting 20–40 seconds just to open Device Manager and start an emulator.
- **Battery Drain & Thermal Throttling**: Heavy background indexing and Gradle daemons heat up laptops and drain batteries.
- **Bloated Workspace**: Unnecessary for developers who only need the emulator, screen mirroring, and logs.

---

### The Solution: Simulation Tray
**Simulation Tray** decouples the entire Android emulation and device management workflow from Android Studio:

| Capability | Standard Android Studio | Simulation Tray (Tray) |
| :--- | :---: | :---: |
| **RAM Footprint** | ~3,000 MB – 6,000+ MB | **~75 MB – 110 MB** (98% lighter!) |
| **Startup Time** | 20 – 45 seconds | **< 1 second** |
| **Studio Dependency** | Required | **Zero** (100% standalone) |
| **System Tray Control** | ❌ None | **Expo Orbit-style menu bar / tray dropdown** |
| **Screen Mirroring** | Basic embedded frame | **Ultra-low latency `scrcpy` (60+ FPS)** |
| **Real-time Logcat Console** | Studio Logcat tab only | **Integrated real-time logcat with level & tag filters** |
| **Telemetry & Waveforms** | Profiler requires build | **Live CPU/RAM sparklines & top process monitor** |
| **Wireless ADB / Wi-Fi** | Complex manual setup | **1-Click USB switch, pairing dialog & tray controls** |
| **Port Conflict Prevention** | Manual troubleshooting | **Automated console & ADB port allocator** |

---

## 🎯 Who is Simulation Tray For?

1. **Lightweight Editor Developers**: Anyone coding in **VS Code, Cursor, Zed, Sublime Text, or Terminal** who wants instant emulator controls without launching a heavyweight IDE.
2. **React Native & Expo Engineers**: Perfect companion for **Expo Orbit** workflows—quickly launch emulators, mirror screens, and inspect live device logs directly from the tray.
3. **Flutter & KMP Developers**: Seamlessly test across Android phones, tablets, foldables, and TV profiles with minimal system overhead.
4. **QA Engineers & Testers**: Effortlessly test on multiple virtual and physical Android devices, take screenshots, mirror displays, and stream logcat without touching code repositories.
5. **Resource-Constrained Laptops**: Maximizes performance on 8 GB / 16 GB machines where every megabyte of RAM counts.

---

## ✨ Key Features Explained

### 1. 📥 Standalone SDK & Environment Manager (No Studio Needed)
- **1-Click Automated Setup**: Downloads and installs official **Eclipse Adoptium Temurin OpenJDK 17**, Google **Command-Line Tools (`cmdline-tools`)**, **Android Emulator (QEMU engine)**, and **Platform-Tools (`adb`)**.
- **Automated License Agreement**: Generates and persists required SDK license hashes (`android-sdk-license`, etc.) automatically.
- **Smart Path Auto-Detection**: Discovers existing SDK installations via `ANDROID_HOME`, `ANDROID_SDK_ROOT`, standard directories, or allows custom folder assignment.

### 2. 📱 Modern Virtual Device Studio
- **Curated Hardware Catalog**:
  - **Phones**: Google Pixel 9 Pro, Pixel 9, Pixel 8 Pro, Pixel 8, Pixel 7 Pro, Pixel 7, Pixel 6 Pro, Pixel 6, Medium Phone.
  - **Foldables & Tablets**: Google Pixel Fold, Pixel Tablet, 10.1" WXGA Tablet, 7" WSVGA Tablet.
  - **Specialty Profiles**: Resizable Device (multi-form-factor testing) and Android TV (1080p).
- **Target OS Catalog**: Android 15 (API 35), Android 14 (API 34), Android 13 (API 33), Android 12L (API 32), Android 12 (API 31), Android 11 (API 30).
- **On-Demand System Image Downloader**: If a target system image is missing, Tray automatically downloads and extracts it via `sdkmanager` with live progress indication.
- **Granular Hardware Tuning**: Customize RAM allocation (1 GB – 16 GB), CPU cores (1 – 16), internal storage (2 GB – 64 GB), and GPU acceleration (`auto`, `host`, `swiftshader_indirect`, `angle_indirect`).

### 3. 🔍 Real-Time Device Logcat Viewer (Phones & Emulators)
- **Multi-Device Support**: Switch between connected physical Android phones via USB/Wi-Fi, running virtual emulators, or Tray system logs.
- **🎯 Project / App Log Isolation (No System Noise)**:
  - **Auto-Detect Active App**: One-click detection scans the device for the currently active foreground application, resolves its process PID, and automatically filters out thousands of unrelated Android OS logs (`ActivityManager`, `WifiStateMachine`, `AudioTrack`, etc.).
  - **Process PID Filtering**: Matches all logs emitted from inside the app's process in real-time, including custom log tags, `print()`, native crashes, and network requests.
  - **Framework Presets**: Instant one-click filter modes for **Flutter / Dart** (`flutter`, `dart`, `flutter_engine`) and **React Native** (`ReactNative`, `ReactNativeJS`).
  - **Installed App Picker**: Choose from all installed third-party user applications on the device or manually enter any custom package name.
- **Real-Time ADB Streaming**: Streams live logcat (`adb logcat -v time`) with high-throughput 60 FPS batched UI rendering.
- **Instant Search & Level Filtering**:
  - Filter by log severity: `Verbose+`, `Debug+`, `Info+`, `Warning+`, `Error+`, and `Fatal`.
  - Search query filtering across message text, component tags, and process IDs (PID).
- **Console Controls**: Play/Pause live output, auto-scroll to bottom, one-click clear (`adb logcat -c`), and copy all visible logs to clipboard.
- **Direct Tray & Dashboard Integration**: Click **"View Device Logs"** from any card or tray menu item to jump straight into live logs for that target.

### 4. 📺 Ultra-Fast Screen Mirroring (`scrcpy` Integration)
- **Fluid 60+ FPS Display**: Control and view running virtual devices or physical phones with negligible latency.
- **Deep System Auto-Detection**:
  - Windows: Checks system `PATH`, Windows Registry, WinGet packages, Scoop, Chocolatey, `Downloads`, and `Program Files`.
  - macOS: Scans Homebrew (`/opt/homebrew`, `/usr/local/bin`) and MacPorts locations.
- **Conflict-Free ADB Architecture**: Shares and coordinates with Tray's internal ADB daemon to prevent connection dropping or server restarts.
- **Flicker-Free Path Validation**: Cached background checks prevent UI reloading or progress spinners during device polling.

### 5. 📶 Lightweight Wireless ADB & Wi-Fi Pairing
- **1-Click USB-to-Wi-Fi Switch**: Seamlessly transition any USB-connected physical phone to wireless mode (`adb tcpip 5555` → `adb connect <ip>:5555`) with a single click. Unplug the USB cable and continue developing wirelessly!
- **Direct IP:Port Connect**: Connect to any Android device on the same local network by IP and port in seconds.
- **Android 11+ Wireless Pairing**: Built-in dialog for Android 11+ pairing codes (6-digit Wi-Fi pairing code and pairing port) without needing command-line prompts.
- **Ultra-Lightweight Architecture**: 100% on-demand execution with zero subnet ARP sweeps, zero background polling, and 0% idle CPU overhead. Perfect for low-spec laptops.
- **Tray & Card Shortcuts**: Switch to Wi-Fi, disconnect, or trigger pairing directly from device cards or the system tray menu.

### 6. 📊 Real-Time Device Telemetry & Waveform Monitor
- **Live Hardware Waveforms**: Real-time sparkline graphs for CPU utilization, RAM consumption, and network RX/TX bandwidth.
- **Hardware Metrics**: Battery percentage, battery temperature, battery health status, and live FPS rendering speed.
- **Active Top Processes**: View the top resource-consuming processes running inside the Android device or host machine.
- **Customizable Widgets**: Toggle individual telemetry tiles and configure polling intervals (1s, 2s, 5s).

### 7. ⚡ Process Manager & Port Collision Guard
- **Automatic Port Allocation**: Assigns free even ports (`5554`, `5556`, `5558`...) to eliminate port collisions when running multiple emulators simultaneously.
- **Active Process Monitor**: View all running `qemu-system`, `adb`, and `scrcpy` background processes with CPU/memory footprints and one-click termination.
- **Hardware Virtualization Check**: Detects Windows Hypervisor Platform (WHPX), Android Emulator Hypervisor Driver (AEHD), Apple Hypervisor.framework, and KVM.

### 8. 🪟 Desktop-First Window & Tray Experience
- **Expo Orbit-Style System Tray**: Left-click or right-click the menu bar / notification tray icon to start emulators, cold boot, mirror screens, view logs, or refresh devices without opening the main window.
- **Intelligent Resizing**: Native minimum window size (`1150 x 570` on macOS / `1100 x 560` on Windows) prevents UI collapsing while allowing free upward expansion, maximizing, and native macOS zoom.
- **Background Minimization**: Seamlessly minimizes to the system tray; restores smoothly when clicking "Open Manager" or the macOS Dock icon.
- **Native In-App Updater**: Checks GitHub Releases and performs in-place native app updates.

---

## 📥 Installation

Download the latest pre-compiled binary for your operating system from the **[Releases Page](https://github.com/Rosdeb/Tray/releases)**.

### Windows (10 / 11)
1. Download **`Tray-Setup.exe`**.
2. Run the installer and follow the setup wizard.
   > **Note on Windows Defender SmartScreen ("Run anyway")**:
   > Because Simulation Tray is an open-source project without a proprietary corporate EV code-signing certificate, Windows SmartScreen may show a warning on first install.
   > 
   > **To proceed safely**:
   > 1. Click **"More info"**.
   > 2. Verify the publisher and executable name (`Tray-Setup.exe`).
   > 3. Click **"Run anyway"**.
   > 
   > You can verify the file hash in PowerShell anytime against the official release SHA-256 checksum:
   > ```powershell
   > Get-FileHash .\Tray-Setup.exe -Algorithm SHA256
   > ```
3. Launch **Simulation Tray** from the Start Menu or Desktop shortcut.

### macOS (Apple Silicon & Intel)
1. Download **`Tray.dmg`**.
2. Open the `.dmg` file and drag **Tray** to your `/Applications` folder.
3. Open Tray from Applications or Spotlight. *(On first launch, if prompted by macOS Gatekeeper, click Open or allow in System Settings > Privacy & Security)*.

---

## 📖 Usage Guide

### 1. Initial Standalone Setup (Without Android Studio)
1. Open Tray and navigate to **Settings** (`⚙️` icon in sidebar).
2. Under **Standalone Android Environment**, click **Setup / Repair Android Environment**.
3. Choose your desired SDK directory (defaults to `%LOCALAPPDATA%\Android\Sdk` on Windows or `~/Library/Android/sdk` on macOS).
4. Click **Start Setup** — Tray will automatically download OpenJDK 17, Google Command-Line Tools, accept licenses, install the emulator engine, and create your base device.

### 2. Creating a Virtual Device
1. On the **Dashboard**, click **Create Device** (`+`).
2. **Select Hardware Profile**: Choose from the catalog (e.g., *Pixel 8 Pro* or *Pixel Tablet*).
3. **Configure OS & Specs**:
   - Pick your desired Android API version. If the system image is not yet on disk, Tray will show a `Download on create` badge and fetch it automatically.
   - Adjust RAM, CPU cores, internal disk size, and GPU acceleration mode.
4. Click **Create Device**.

### 3. Running, Mirroring & Viewing Logs
- **Run**: Click **Run** (`▶`) on any emulator card to boot.
- **Mirror**: Click **Mirror** (`📺`) to open an ultra-low latency `scrcpy` window.
- **Device Logs**: Click `⋮` on any running emulator or connected phone card and select **View Device Logs (logcat)** to open the live log console.
- **Cold Boot**: Click `⋮` and select **Cold boot (-no-snapshot-load)** to start clean without snapshot state.
- **Stop**: Click **Stop** (`⏹`) to cleanly terminate via `adb emu kill`.

---

## 🛠 Tech Stack & Architecture

- **UI Framework**: [Flutter Desktop](https://flutter.dev/multi-platform/desktop) (macOS & Windows Runner)
- **State Architecture**: [Riverpod 3](https://riverpod.dev) (`NotifierProvider`, `AsyncNotifier`, `FutureProvider`)
- **Desktop Window Management**: `window_manager` & `tray_manager`
- **Native Process Orchestration**: `dart:io` `Process.start` & `Process.run` with piped stdin streams
- **Packaging & Delivery**:
  - Windows: Inno Setup compiler (`.exe` installer)
  - macOS: `create-dmg` (`.dmg` disk image)
  - CI/CD: Automated dual-runner GitHub Actions (`windows-latest` & `macos-14`)

```
lib/
├── core/
│   ├── constants/       # App constants, defaults, and API levels
│   ├── theme/           # Color schemes, typography, and dark/light themes
│   └── utils/           # Cross-platform paths, process helpers, container resolving
├── models/              # Immutable data models (Emulator, LogEntry, DeviceMetrics, Settings)
├── providers/           # Riverpod state controllers (Emulator, DeviceLogs, DeviceMonitor)
├── repositories/        # Hardware acceleration, emulator discovery, and device lifecycle
├── screens/
│   ├── dashboard/       # Main emulator grid, skeleton loaders, and quick stats
│   ├── monitor/         # Real-time CPU, RAM, network, and process telemetry
│   ├── logs/            # Real-time multi-device logcat viewer & search console
│   ├── settings/        # Standalone SDK setup, scrcpy configuration, and preferences
│   └── home_shell.dart  # Desktop shell navigation, caption buttons, and tray lifecycle
├── services/            # ADB, QEMU, DeviceLogService, ScrcpyService, ProcessManager
└── widgets/             # CreateAvdDialog, SdkSetupDialog, EmulatorCard, StatTile
```

---

## 💻 Building from Source

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
