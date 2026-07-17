# Tray

A modern Windows desktop application built with Flutter to manage Android Emulators (AVDs) from a single interface.

The application automatically detects installed Android SDKs and emulators, allowing developers to launch, stop, monitor, and manage Android Virtual Devices without opening Android Studio.

---

## ✨ Features

- 🚀 Detect installed Android SDK automatically
- 📱 List all Android Virtual Devices (AVDs)
- ▶️ Launch emulator
- ❄️ Cold Boot emulator
- ⏹ Stop running emulator
- ⭐ Mark favorite emulators
- 🔄 Auto refresh emulator status
- 🔍 Search and filter emulators
- 📊 Dashboard with statistics
- 🖥 Native Windows desktop experience
- 🔔 System tray support
- 🌙 Light & Dark theme
- ⚙️ Configurable application settings
- 🔕 Windows notifications
- 📂 Custom Android SDK path support

---

## 📷 Screenshots

> Add screenshots here

- Dashboard
- Settings
- Logs
- System Tray

---

## 🛠 Built With

- Flutter
- Riverpod
- Shared Preferences
- Window Manager
- System Tray
- Flutter Local Notifications

---

## 📁 Project Structure

```
lib/
│
├── core/
├── models/
├── providers/
├── repositories/
├── screens/
├── services/
├── widgets/
└── main.dart
```

---

## Requirements

- Windows 10/11
- Flutter 3.44+
- Android SDK
- Android Emulator
- ADB

---

## Installation

Clone the repository

```bash
git clone https://github.com/your-username/android-emulator-manager.git
```

Go to the project

```bash
cd android-emulator-manager
```

Install dependencies

```bash
flutter pub get
```

Enable Windows desktop

```bash
flutter config --enable-windows-desktop
```

Run the application

```bash
flutter run -d windows
```

---

## Build Release (.exe)

```bash
flutter build windows --release
```

Output:

```
build/windows/x64/runner/Release/
```

The generated executable:

```
Android Emulator Manager.exe
```

---

## Features Planned

- Multi emulator launch
- Batch start/stop
- Quick Boot
- Snapshot Manager
- RAM & CPU usage monitor
- Device screenshots
- Logcat viewer
- Wireless ADB
- Emulator grouping
- Keyboard shortcuts
- Update checker

---

## License

This project is licensed under the MIT License.

---

## Author

**Rosdeb Koch**

Flutter Developer

GitHub: https://github.com/your-github