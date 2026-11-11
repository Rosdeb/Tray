import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/hardware_acceleration.dart';

class SystemEnvironmentService {
  /// Detects target Android ABI based on host architecture.
  /// Apple Silicon (M1/M2/M3/M4) -> arm64-v8a
  /// Windows ARM64 -> arm64-v8a
  /// Intel/AMD x64 -> x86_64
  String getHostAbi() {
    if (Platform.isMacOS) {
      final version = Platform.version.toLowerCase();
      if (version.contains('arm64') || version.contains('aarch64')) {
        return 'arm64-v8a';
      }
      try {
        final result = Process.runSync('uname', ['-m']);
        if (result.stdout.toString().trim().contains('arm64')) {
          return 'arm64-v8a';
        }
      } catch (_) {}
      return 'x86_64';
    }

    if (Platform.isWindows) {
      final arch = (Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '').toLowerCase();
      final arch64 = (Platform.environment['PROCESSOR_ARCHITEW6432'] ?? '').toLowerCase();
      if (arch.contains('arm64') || arch64.contains('arm64')) {
        return 'arm64-v8a';
      }
      return 'x86_64';
    }

    if (Platform.isLinux) {
      try {
        final result = Process.runSync('uname', ['-m']);
        final out = result.stdout.toString().trim().toLowerCase();
        if (out.contains('aarch64') || out.contains('arm64')) {
          return 'arm64-v8a';
        }
      } catch (_) {}
      return 'x86_64';
    }

    return 'x86_64';
  }

  /// Checks hardware acceleration status.
  Future<HardwareAccelerationInfo> checkHardwareAcceleration({
    String? emulatorPath,
  }) async {
    // 1. If emulator binary exists, run emulator -accel-check
    if (emulatorPath != null && await File(emulatorPath).exists()) {
      try {
        final result = await Process.run(
          emulatorPath,
          const ['-accel-check'],
          runInShell: false,
        ).timeout(const Duration(seconds: 10));

        final out = '${result.stdout}\n${result.stderr}'.toLowerCase();
        final isAccelActive = result.exitCode == 0 ||
            out.contains('accel: 1') ||
            out.contains('acceleration is active') ||
            out.contains('whpx is installed') ||
            out.contains('aehd is installed') ||
            out.contains('hypervisor.framework');

        if (isAccelActive) {
          String hypervisor = 'Hardware Acceleration Active';
          if (out.contains('whpx')) {
            hypervisor = 'WHPX (Windows Hypervisor Platform)';
          } else if (out.contains('aehd')) {
            hypervisor = 'AEHD (Android Emulator Hypervisor Driver)';
          } else if (out.contains('hypervisor.framework')) {
            hypervisor = 'macOS Hypervisor.framework';
          } else if (out.contains('kvm')) {
            hypervisor = 'Linux KVM';
          }

          return HardwareAccelerationInfo(
            status: AccelerationStatus.available,
            message: 'Hardware acceleration is active ($hypervisor).',
            details: result.stdout.toString().trim(),
            hypervisorType: hypervisor,
          );
        } else {
          return _buildUnavailableInfo(details: out);
        }
      } catch (e) {
        // Fall back to platform checks
      }
    }

    // 2. Pre-emulator heuristic checks based on OS
    if (Platform.isMacOS) {
      // macOS Hypervisor.framework is built into macOS
      return const HardwareAccelerationInfo(
        status: AccelerationStatus.available,
        message: 'macOS Hypervisor.framework is ready.',
        details: 'Apple Hypervisor is built into macOS.',
        hypervisorType: 'Hypervisor.framework',
      );
    }

    if (Platform.isLinux) {
      final kvm = File('/dev/kvm');
      if (await kvm.exists()) {
        try {
          // Check read/write permission
          final raf = await kvm.open(mode: FileMode.read);
          await raf.close();
          return const HardwareAccelerationInfo(
            status: AccelerationStatus.available,
            message: 'Linux KVM acceleration is ready (/dev/kvm).',
            details: '/dev/kvm exists and is accessible.',
            hypervisorType: 'KVM',
          );
        } catch (_) {
          return const HardwareAccelerationInfo(
            status: AccelerationStatus.unavailable,
            message: 'Linux KVM permission denied for /dev/kvm.',
            details: 'Current user cannot access /dev/kvm.',
            hypervisorType: 'KVM',
            howToFix: 'Run: sudo usermod -aG kvm \$USER && sudo chmod 666 /dev/kvm, then reboot.',
          );
        }
      } else {
        return const HardwareAccelerationInfo(
          status: AccelerationStatus.unavailable,
          message: 'Linux KVM device (/dev/kvm) not found.',
          details: 'Virtualization may be disabled in BIOS or KVM module not loaded.',
          hypervisorType: 'KVM',
          howToFix: 'Enable Virtualization (VT-x / AMD-V) in BIOS, then run: sudo apt install qemu-kvm && sudo modprobe kvm',
        );
      }
    }

    if (Platform.isWindows) {
      // Check Windows Hypervisor Platform
      return const HardwareAccelerationInfo(
        status: AccelerationStatus.unknown,
        message: 'Windows Hypervisor Platform (WHPX) or AEHD is required.',
        details: 'Requires WHPX feature enabled in Windows or AEHD driver for AMD/Intel.',
        hypervisorType: 'WHPX / AEHD',
        howToFix: 'Enable "Windows Hypervisor Platform" in "Turn Windows features on or off", or install the AEHD driver.',
      );
    }

    return const HardwareAccelerationInfo(
      status: AccelerationStatus.unknown,
      message: 'Acceleration check pending emulator installation.',
      details: 'Run accel-check after emulator is installed.',
    );
  }

  HardwareAccelerationInfo _buildUnavailableInfo({required String details}) {
    if (Platform.isWindows) {
      return HardwareAccelerationInfo(
        status: AccelerationStatus.unavailable,
        message: 'Hardware acceleration is disabled. The emulator will run extremely slowly.',
        details: details,
        hypervisorType: 'WHPX / AEHD',
        howToFix: '1. In Windows Features, enable "Windows Hypervisor Platform" (WHPX).\n'
            '2. Or install the AEHD driver from Google (HAXM is discontinued).\n'
            '3. Ensure Intel VT-x or AMD-V is enabled in your BIOS/UEFI.',
      );
    } else if (Platform.isLinux) {
      return HardwareAccelerationInfo(
        status: AccelerationStatus.unavailable,
        message: 'KVM acceleration not active.',
        details: details,
        hypervisorType: 'KVM',
        howToFix: 'Ensure /dev/kvm exists and run: sudo usermod -aG kvm \$USER',
      );
    } else {
      return HardwareAccelerationInfo(
        status: AccelerationStatus.unavailable,
        message: 'Hypervisor acceleration not active.',
        details: details,
        howToFix: 'Ensure virtualization is enabled.',
      );
    }
  }

  /// Estimates free disk space in GB for the given path.
  Future<double?> getFreeDiskSpaceGb(String targetPath) async {
    try {
      final dir = Directory(targetPath);
      final checkPath = await dir.exists() ? targetPath : dir.parent.path;

      if (Platform.isWindows) {
        final driveLetter = p.rootPrefix(p.canonicalize(checkPath)).replaceAll(r'\', '').replaceAll('/', '');
        final result = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-Command',
            '(Get-PSDrive | Where-Object { \$_.Root -match "^$driveLetter" }).Free / 1GB',
          ],
          runInShell: false,
        ).timeout(const Duration(seconds: 5));

        if (result.exitCode == 0) {
          final gb = double.tryParse(result.stdout.toString().trim());
          if (gb != null) return gb;
        }
      } else {
        final result = await Process.run(
          'df',
          ['-k', checkPath],
          runInShell: false,
        ).timeout(const Duration(seconds: 5));

        if (result.exitCode == 0) {
          final lines = result.stdout.toString().trim().split('\n');
          if (lines.length >= 2) {
            final parts = lines[1].trim().split(RegExp(r'\s+'));
            if (parts.length >= 4) {
              final availKb = double.tryParse(parts[3]);
              if (availKb != null) {
                return availKb / (1024 * 1024);
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Finds or validates Java 17+ home.
  /// Checks:
  /// 1. Candidate paths (e.g. portable JDK in app folder or SDK folder)
  /// 2. JAVA_HOME environment variable
  /// 3. System `java` in PATH
  Future<String?> findValidJavaHome({List<String> candidates = const []}) async {
    for (final candidate in candidates) {
      if (candidate.trim().isEmpty) continue;
      final home = await _resolveJavaHomeFromDir(candidate);
      if (home != null && await _isJava17Plus(home)) {
        return home;
      }
    }

    final envJavaHome = Platform.environment['JAVA_HOME'];
    if (envJavaHome != null && envJavaHome.trim().isNotEmpty) {
      final home = await _resolveJavaHomeFromDir(envJavaHome);
      if (home != null && await _isJava17Plus(home)) {
        return home;
      }
    }

    // Check system java in PATH
    try {
      final javaExe = Platform.isWindows ? 'java.exe' : 'java';
      final result = await Process.run(javaExe, ['-version']);
      final out = '${result.stdout}\n${result.stderr}';
      final version = _parseJavaVersion(out);
      if (version != null && version >= 17) {
        // Try finding java parent directory
        if (Platform.isMacOS) {
          final which = await Process.run('/usr/libexec/java_home', ['-v', '17+']);
          if (which.exitCode == 0 && which.stdout.toString().trim().isNotEmpty) {
            return which.stdout.toString().trim();
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<String?> _resolveJavaHomeFromDir(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return null;

    final javaExe = Platform.isWindows ? 'java.exe' : 'java';

    // Direct bin/java
    if (await File(p.join(dirPath, 'bin', javaExe)).exists()) {
      return dirPath;
    }

    // macOS Contents/Home
    if (await File(p.join(dirPath, 'Contents', 'Home', 'bin', javaExe)).exists()) {
      return p.join(dirPath, 'Contents', 'Home');
    }

    // Check subdirectories (e.g., extracted archive jdk-17.0.x/...)
    try {
      final entries = dir.listSync();
      for (final entry in entries) {
        if (entry is Directory) {
          if (await File(p.join(entry.path, 'bin', javaExe)).exists()) {
            return entry.path;
          }
          if (await File(p.join(entry.path, 'Contents', 'Home', 'bin', javaExe)).exists()) {
            return p.join(entry.path, 'Contents', 'Home');
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<bool> _isJava17Plus(String javaHome) async {
    final javaExe = Platform.isWindows ? 'java.exe' : 'java';
    final bin = p.join(javaHome, 'bin', javaExe);
    final file = File(bin);
    if (!await file.exists()) return false;

    try {
      final result = await Process.run(bin, ['-version']);
      final out = '${result.stdout}\n${result.stderr}';
      final major = _parseJavaVersion(out);
      return major != null && major >= 17;
    } catch (_) {
      return false;
    }
  }

  int? _parseJavaVersion(String output) {
    // Examples: "openjdk version \"17.0.9\"", "java version \"21.0.1\"", "openjdk version \"1.8.0_...\""
    final match = RegExp(r'version\s+"(\d+)(?:\.(\d+))?').firstMatch(output);
    if (match != null) {
      final first = int.tryParse(match.group(1) ?? '');
      if (first == 1) {
        return int.tryParse(match.group(2) ?? '');
      }
      return first;
    }
    return null;
  }

  /// Checks if scrcpy is installed on the machine.
  Future<String?> findScrcpy() async {
    try {
      final cmd = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(cmd, ['scrcpy']);
      if (result.exitCode == 0) {
        final path = result.stdout.toString().split(RegExp(r'\r?\n')).first.trim();
        if (path.isNotEmpty && await File(path).exists()) {
          return path;
        }
      }
    } catch (_) {}
    return null;
  }
}
