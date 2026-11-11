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

  /// Resolves an input file or folder path into a valid scrcpy executable path.
  static String? resolveScrcpyExecutable(String inputPath) {
    final trimmed = inputPath.trim();
    if (trimmed.isEmpty) return null;

    final file = File(trimmed);
    if (file.existsSync()) {
      return file.absolute.path;
    }

    final dir = Directory(trimmed);
    if (dir.existsSync()) {
      if (Platform.isWindows) {
        final exe = File(p.join(trimmed, 'scrcpy.exe'));
        if (exe.existsSync()) return exe.absolute.path;
        final bat = File(p.join(trimmed, 'scrcpy.bat'));
        if (bat.existsSync()) return bat.absolute.path;
      } else {
        final bin = File(p.join(trimmed, 'scrcpy'));
        if (bin.existsSync()) return bin.absolute.path;
      }

      // Check immediate child directories (e.g. extracted scrcpy-win64 folder inside selected folder)
      try {
        for (final entity in dir.listSync(followLinks: false)) {
          if (entity is Directory) {
            final target = Platform.isWindows
                ? File(p.join(entity.path, 'scrcpy.exe'))
                : File(p.join(entity.path, 'scrcpy'));
            if (target.existsSync()) return target.absolute.path;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Opens the official scrcpy releases download page in the system browser.
  static Future<void> openScrcpyDownloadPage() async {
    const url = 'https://github.com/Genymobile/scrcpy/releases';
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (_) {}
  }

  /// Checks if scrcpy is installed on the machine.
  /// Looks in:
  /// 1. Custom user path if provided
  /// 2. Active PATH (where.exe on Windows, which on macOS/Linux)
  /// 3. Windows Registry PATH (HKCU & HKLM environment keys)
  /// 4. Windows Package managers (WinGet links & packages, Scoop, Chocolatey)
  /// 5. Standard Windows installation and extraction directories (C:\scrcpy, Downloads\scrcpy*, Desktop\scrcpy*, Program Files)
  /// 6. Android SDK directory if known
  /// 7. macOS / Linux standard paths (/opt/homebrew, /usr/local, /snap, etc.)
  Future<String?> findScrcpy({String? customPath, String? sdkPath}) async {
    // 1. Explicit custom path from settings
    if (customPath != null && customPath.trim().isNotEmpty) {
      final resolved = resolveScrcpyExecutable(customPath.trim());
      if (resolved != null) return resolved;
    }

    // 2. PATH resolution via where.exe / which
    final pathFromPath = await _findScrcpyFromSystemPath();
    if (pathFromPath != null) return pathFromPath;

    // 3. Platform-specific deep search
    if (Platform.isWindows) {
      final winPath = await _findScrcpyOnWindows(sdkPath: sdkPath);
      if (winPath != null) return winPath;
    } else if (Platform.isMacOS) {
      final macPath = await _findScrcpyOnMac(sdkPath: sdkPath);
      if (macPath != null) return macPath;
    } else if (Platform.isLinux) {
      final linuxPath = await _findScrcpyOnLinux(sdkPath: sdkPath);
      if (linuxPath != null) return linuxPath;
    }

    return null;
  }

  static Future<String?> _findScrcpyFromSystemPath() async {
    try {
      if (Platform.isWindows) {
        for (final bin in ['scrcpy.exe', 'scrcpy']) {
          final res = await Process.run('where.exe', [bin], runInShell: true);
          if (res.exitCode == 0) {
            final lines = res.stdout.toString().split(RegExp(r'\r?\n'));
            for (final line in lines) {
              final trimmed = line.trim();
              if (trimmed.isNotEmpty && File(trimmed).existsSync()) {
                return trimmed;
              }
            }
          }
        }
      } else {
        final res = await Process.run('which', ['scrcpy']);
        if (res.exitCode == 0) {
          final trimmed = res.stdout.toString().trim();
          if (trimmed.isNotEmpty && File(trimmed).existsSync()) {
            return trimmed;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _findScrcpyOnWindows({String? sdkPath}) async {
    final env = Platform.environment;
    final userProfile = env['USERPROFILE'] ?? '';
    final localAppData = env['LOCALAPPDATA'] ?? '';
    final appData = env['APPDATA'] ?? '';
    final programFiles = env['ProgramFiles'] ?? r'C:\Program Files';
    final programFilesX86 = env['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
    final programData = env['ProgramData'] ?? r'C:\ProgramData';

    final directCandidates = <String>[
      // WinGet links
      if (localAppData.isNotEmpty)
        p.join(localAppData, 'Microsoft', 'WinGet', 'Links', 'scrcpy.exe'),
      // Scoop
      if (userProfile.isNotEmpty) ...[
        p.join(userProfile, 'scoop', 'shims', 'scrcpy.exe'),
        p.join(userProfile, 'scoop', 'apps', 'scrcpy', 'current', 'scrcpy.exe'),
      ],
      // Chocolatey
      p.join(programData, 'chocolatey', 'bin', 'scrcpy.exe'),
      p.join(programData, 'chocolatey', 'lib', 'scrcpy', 'tools', 'scrcpy.exe'),
      r'C:\tools\scrcpy\scrcpy.exe',
      // Standard folders
      p.join(programFiles, 'scrcpy', 'scrcpy.exe'),
      p.join(programFilesX86, 'scrcpy', 'scrcpy.exe'),
      if (localAppData.isNotEmpty)
        p.join(localAppData, 'Programs', 'scrcpy', 'scrcpy.exe'),
      if (appData.isNotEmpty)
        p.join(appData, 'scrcpy', 'scrcpy.exe'),
      if (userProfile.isNotEmpty) ...[
        p.join(userProfile, 'scrcpy', 'scrcpy.exe'),
        p.join(userProfile, 'scrcpy-win64', 'scrcpy.exe'),
      ],
      // Drive roots
      r'C:\scrcpy\scrcpy.exe',
      r'C:\scrcpy-win64\scrcpy.exe',
      r'D:\scrcpy\scrcpy.exe',
      r'D:\scrcpy-win64\scrcpy.exe',
      r'E:\scrcpy\scrcpy.exe',
      // SDK subfolders
      if (sdkPath != null && sdkPath.isNotEmpty) ...[
        p.join(sdkPath, 'platform-tools', 'scrcpy.exe'),
        p.join(sdkPath, 'scrcpy', 'scrcpy.exe'),
        p.join(sdkPath, 'tools', 'scrcpy.exe'),
      ],
    ];

    for (final c in directCandidates) {
      if (File(c).existsSync()) return c;
    }

    // Check Windows Registry PATH
    try {
      final regKeys = [
        r'HKCU\Environment',
        r'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
      ];
      for (final key in regKeys) {
        final res = await Process.run('reg', ['query', key, '/v', 'Path']);
        if (res.exitCode == 0) {
          final out = res.stdout.toString();
          final lines = out.split(RegExp(r'\r?\n'));
          for (final line in lines) {
            final trimmedLine = line.trim();
            if (trimmedLine.toLowerCase().startsWith('path')) {
              final parts = trimmedLine.split(RegExp(r'\s{2,}|\t+'));
              if (parts.length >= 3) {
                final rawPathVal = parts.sublist(2).join(' ');
                for (final item in rawPathVal.split(';')) {
                  var dir = item.trim();
                  if (dir.isNotEmpty) {
                    if (dir.contains('%')) {
                      for (final entry in Platform.environment.entries) {
                        dir = dir.replaceAll('%${entry.key}%', entry.value);
                      }
                    }
                    final target = File(p.join(dir, 'scrcpy.exe'));
                    if (target.existsSync()) return target.path;
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    // Check WinGet Packages
    if (localAppData.isNotEmpty) {
      try {
        final packagesDir = Directory(p.join(localAppData, 'Microsoft', 'WinGet', 'Packages'));
        if (packagesDir.existsSync()) {
          for (final entity in packagesDir.listSync(followLinks: false)) {
            if (entity is Directory && p.basename(entity.path).toLowerCase().contains('scrcpy')) {
              final direct = File(p.join(entity.path, 'scrcpy.exe'));
              if (direct.existsSync()) return direct.path;
              for (final sub in entity.listSync(recursive: true, followLinks: false)) {
                if (sub is File && p.basename(sub.path).toLowerCase() == 'scrcpy.exe') {
                  return sub.path;
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    // Scan user directories (Downloads, Desktop, Documents) and root drives for extracted folders
    final searchRoots = <String>[
      if (userProfile.isNotEmpty) p.join(userProfile, 'Downloads'),
      if (userProfile.isNotEmpty) p.join(userProfile, 'Desktop'),
      if (userProfile.isNotEmpty) p.join(userProfile, 'Documents'),
      r'C:\',
      r'D:\',
    ];

    for (final root in searchRoots) {
      try {
        final dir = Directory(root);
        if (dir.existsSync()) {
          for (final entity in dir.listSync(followLinks: false)) {
            if (entity is Directory) {
              final name = p.basename(entity.path).toLowerCase();
              if (name.contains('scrcpy')) {
                final direct = File(p.join(entity.path, 'scrcpy.exe'));
                if (direct.existsSync()) return direct.path;
                for (final sub in entity.listSync(followLinks: false)) {
                  if (sub is File && p.basename(sub.path).toLowerCase() == 'scrcpy.exe') {
                    return sub.path;
                  }
                  if (sub is Directory && p.basename(sub.path).toLowerCase().contains('scrcpy')) {
                    final subExe = File(p.join(sub.path, 'scrcpy.exe'));
                    if (subExe.existsSync()) return subExe.path;
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }

  static Future<String?> _findScrcpyOnMac({String? sdkPath}) async {
    final home = Platform.environment['HOME'] ?? '';
    final candidates = <String>[
      '/opt/homebrew/bin/scrcpy',
      '/usr/local/bin/scrcpy',
      if (home.isNotEmpty) p.join(home, '.homebrew', 'bin', 'scrcpy'),
      '/opt/local/bin/scrcpy',
      '/Applications/scrcpy.app/Contents/MacOS/scrcpy',
      if (sdkPath != null && sdkPath.isNotEmpty) ...[
        p.join(sdkPath, 'platform-tools', 'scrcpy'),
        p.join(sdkPath, 'scrcpy', 'scrcpy'),
      ],
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  static Future<String?> _findScrcpyOnLinux({String? sdkPath}) async {
    final home = Platform.environment['HOME'] ?? '';
    final candidates = <String>[
      '/usr/bin/scrcpy',
      '/usr/local/bin/scrcpy',
      '/snap/bin/scrcpy',
      if (home.isNotEmpty) ...[
        p.join(home, '.local', 'bin', 'scrcpy'),
        p.join(home, '.cargo', 'bin', 'scrcpy'),
      ],
      if (sdkPath != null && sdkPath.isNotEmpty) ...[
        p.join(sdkPath, 'platform-tools', 'scrcpy'),
        p.join(sdkPath, 'scrcpy', 'scrcpy'),
      ],
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }
}
