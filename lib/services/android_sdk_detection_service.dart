import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/utils/platform_paths.dart';
import '../models/android_sdk.dart';
import 'system_environment_service.dart';

class AndroidSdkDetectionService {
  AndroidSdkDetectionService([SystemEnvironmentService? systemEnvironmentService])
      : _systemEnvironmentService = systemEnvironmentService ?? SystemEnvironmentService();

  final SystemEnvironmentService _systemEnvironmentService;

  Future<List<AndroidSdk>> detect({String? preferredPath}) async {
    // If a custom preferredPath was specified, only validate that path and its resolved root.
    // Do NOT silently replace an explicitly chosen path with a fallback default candidate!
    if (preferredPath != null && preferredPath.trim().isNotEmpty) {
      final resolved = PlatformPaths.resolveSdkRoot(preferredPath);
      final preferredSdk = await validate(resolved);
      if (preferredSdk != null) {
        return <AndroidSdk>[preferredSdk];
      }
      if (resolved != preferredPath.trim()) {
        final directSdk = await validate(preferredPath.trim());
        if (directSdk != null) {
          return <AndroidSdk>[directSdk];
        }
      }
      return <AndroidSdk>[];
    }

    // Auto-detection mode: scan all candidates
    final candidates = PlatformPaths.androidSdkCandidates();
    final sdks = <AndroidSdk>[];
    for (final candidate in candidates) {
      final sdk = await validate(candidate);
      if (sdk != null) {
        sdks.add(sdk);
      }
    }
    return sdks;
  }

  Future<AndroidSdk?> validate(String sdkPath) async {
    final dir = Directory(sdkPath);
    if (!await dir.exists()) {
      return null;
    }

    final emulatorExe = Platform.isWindows ? 'emulator.exe' : 'emulator';
    final adbExe = Platform.isWindows ? 'adb.exe' : 'adb';
    final sdkManagerExe = Platform.isWindows ? 'sdkmanager.bat' : 'sdkmanager';
    final avdManagerExe = Platform.isWindows ? 'avdmanager.bat' : 'avdmanager';

    final emulatorPath = p.join(sdkPath, 'emulator', emulatorExe);
    final adbPath = p.join(sdkPath, 'platform-tools', adbExe);

    final hasEmulator = await File(emulatorPath).exists();
    final hasAdb = await File(adbPath).exists();

    // Check cmdline-tools (canonical latest first, then legacy, then versioned subdirs)
    String? sdkManagerPath;
    String? avdManagerPath;

    final candidateManagerPaths = <String>[
      p.join(sdkPath, 'cmdline-tools', 'latest', 'bin'),
      p.join(sdkPath, 'cmdline-tools', 'bin'),
      p.join(sdkPath, 'tools', 'bin'),
    ];

    // Scan any versioned subdirectories in cmdline-tools (e.g. 11.0, 12.0)
    final cmdlineDir = Directory(p.join(sdkPath, 'cmdline-tools'));
    if (await cmdlineDir.exists()) {
      try {
        final entries = cmdlineDir.listSync();
        for (final entry in entries) {
          if (entry is Directory) {
            candidateManagerPaths.add(p.join(entry.path, 'bin'));
          }
        }
      } catch (_) {}
    }

    for (final binDir in candidateManagerPaths) {
      final sm = p.join(binDir, sdkManagerExe);
      final am = p.join(binDir, avdManagerExe);
      if (await File(sm).exists() && await File(am).exists()) {
        sdkManagerPath = sm;
        avdManagerPath = am;
        break;
      }
    }

    // Detect valid Java Home
    final javaHome = await _systemEnvironmentService.findValidJavaHome(
      candidates: [
        p.join(sdkPath, 'jdk-17'),
        p.join(sdkPath, 'jdk'),
      ],
    );

    // If neither emulator nor adb nor cmdline-tools exists, not an Android SDK
    if (!hasEmulator && !hasAdb && sdkManagerPath == null) {
      return null;
    }

    // Read emulator version
    String? version;
    if (hasEmulator) {
      try {
        final verRes = await Process.run(emulatorPath, ['-version']);
        final firstLine = verRes.stdout.toString().split(RegExp(r'\r?\n')).first.trim();
        if (firstLine.isNotEmpty) {
          version = firstLine;
        }
      } catch (_) {}
    }

    return AndroidSdk(
      path: sdkPath,
      emulatorPath: hasEmulator ? emulatorPath : '',
      adbPath: hasAdb ? adbPath : '',
      sdkManagerPath: sdkManagerPath,
      avdManagerPath: avdManagerPath,
      javaHome: javaHome,
      version: version,
    );
  }
}
