import 'dart:io';

import 'package:path/path.dart' as p;

import '../constants/app_constants.dart';

class PlatformPaths {
  const PlatformPaths._();

  /// Resolves the true SDK root if the user selected a subfolder (like `emulator`,
  /// `platform-tools`, `cmdline-tools`) or a parent folder that contains an `Sdk` folder.
  static String resolveSdkRoot(String inputPath) {
    var normalized = p.normalize(inputPath.trim());
    if (normalized.endsWith('/') || normalized.endsWith(r'\')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    // If a sandboxed container path was previously stored or selected on macOS, resolve back to real home
    if (Platform.isMacOS && normalized.contains('/Library/Containers/')) {
      final parts = normalized.split('/Library/Containers/');
      final prefix = parts[0];
      final afterContainers = parts.sublist(1).join('/Library/Containers/');
      if (afterContainers.contains('/Data/')) {
        final afterData = afterContainers.split('/Data/').sublist(1).join('/Data/');
        final realCandidate = p.normalize(p.join(prefix, afterData));
        if (Directory(realCandidate).existsSync() || !Directory(normalized).existsSync()) {
          normalized = realCandidate;
        }
      }
    }

    final basename = p.basename(normalized).toLowerCase();

    // 1. If user selected a known subfolder inside SDK
    if (['emulator', 'platform-tools', 'cmdline-tools', 'tools', 'build-tools'].contains(basename)) {
      final parent = p.dirname(normalized);
      if (Directory(parent).existsSync()) {
        return parent;
      }
    }

    // If user selected inside cmdline-tools/latest/bin or similar deep subfolder
    if (basename == 'bin') {
      final parent = p.dirname(normalized);
      final grandParent = p.dirname(parent);
      if (p.basename(grandParent).toLowerCase() == 'cmdline-tools') {
        final sdkRoot = p.dirname(grandParent);
        if (Directory(sdkRoot).existsSync()) return sdkRoot;
      }
    }

    // 2. If user selected a parent folder that directly contains 'Sdk' or 'sdk'
    for (final sub in ['Sdk', 'sdk', 'android-sdk', 'Android-sdk']) {
      final child = p.join(normalized, sub);
      if (Directory(child).existsSync()) {
        if (Directory(p.join(child, 'platform-tools')).existsSync() ||
            Directory(p.join(child, 'emulator')).existsSync() ||
            Directory(p.join(child, 'cmdline-tools')).existsSync()) {
          return child;
        }
      }
    }

    return normalized;
  }

  static List<String> androidSdkCandidates() {
    final env = Platform.environment;
    final candidates = <String>[
      if ((env['ANDROID_HOME'] ?? '').trim().isNotEmpty) env['ANDROID_HOME']!,
      if ((env['ANDROID_SDK_ROOT'] ?? '').trim().isNotEmpty)
        env['ANDROID_SDK_ROOT']!,
    ];

    // Try resolving from which/where adb or emulator in system PATH
    try {
      final whichCmd = Platform.isWindows ? 'where.exe' : 'which';
      for (final bin in ['emulator', 'adb']) {
        final binExe = Platform.isWindows ? '$bin.exe' : bin;
        final res = Process.runSync(whichCmd, [binExe]);
        if (res.exitCode == 0) {
          final lines = res.stdout.toString().split(RegExp(r'\r?\n'));
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty && File(trimmed).existsSync()) {
              final parent = p.dirname(trimmed);
              final sdkRoot = p.dirname(parent);
              if (Directory(sdkRoot).existsSync()) {
                candidates.add(sdkRoot);
              }
            }
          }
        }
      }
    } catch (_) {}

    if (Platform.isWindows) {
      final userProfile = env['USERPROFILE'];
      if (userProfile != null && userProfile.trim().isNotEmpty) {
        candidates.add(p.join(userProfile, AppConstants.defaultWindowsSdkSuffix));
        candidates.add(p.join(userProfile, 'Android', 'Sdk'));
        candidates.add(p.join(userProfile, 'AppData', 'Local', 'Android', 'Sdk'));
      }
      final localAppData = env['LOCALAPPDATA'];
      if (localAppData != null && localAppData.trim().isNotEmpty) {
        candidates.add(p.join(localAppData, 'Android', 'Sdk'));
      }
      // Common Windows drive roots
      for (final drive in ['C:', 'D:', 'E:']) {
        candidates.add(p.join(drive, 'Android', 'Sdk'));
        candidates.add(p.join(drive, 'Android', 'sdk'));
        candidates.add(p.join(drive, 'Android', 'android-sdk'));
        candidates.add(p.join(drive, 'tools', 'android-sdk'));
      }
    } else if (Platform.isMacOS) {
      final home = userHomeDir();
      if (home.isNotEmpty) {
        candidates.add(p.join(home, 'Library', 'Android', 'sdk'));
        candidates.add(p.join(home, 'Android', 'Sdk'));
        candidates.add(p.join(home, '.android', 'sdk'));
      }
    } else if (Platform.isLinux) {
      final home = userHomeDir();
      if (home.isNotEmpty) {
        candidates.add(p.join(home, 'Android', 'Sdk'));
        candidates.add(p.join(home, '.android', 'sdk'));
        candidates.add(p.join(home, 'Android', 'sdk'));
      }
      candidates.add('/opt/android-sdk');
      candidates.add('/usr/lib/android-sdk');
    }

    return candidates.toSet().toList(growable: false);
  }

  /// Safely resolves the user's home directory.
  /// On macOS, sandboxed apps point HOME to `~/Library/Containers/<bundle-id>/Data`.
  /// This method resolves the true user home directory (`/Users/<username>`).
  static String userHomeDir() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      return (env['USERPROFILE'] ?? env['HOME'] ?? '').trim();
    }
    final rawHome = (env['HOME'] ?? '').trim();
    if (Platform.isMacOS) {
      if (rawHome.contains('/Library/Containers/')) {
        final realHome = rawHome.split('/Library/Containers/').first;
        if (realHome.isNotEmpty) {
          return realHome;
        }
      }
      final user = env['USER'];
      if (user != null && user.trim().isNotEmpty) {
        final userHome = '/Users/${user.trim()}';
        if (Directory(userHome).existsSync()) {
          return userHome;
        }
      }
    }
    return rawHome;
  }

  static String defaultSdkPath() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      final localAppData = env['LOCALAPPDATA'] ?? env['USERPROFILE'];
      if (localAppData != null && localAppData.trim().isNotEmpty) {
        return p.join(localAppData, 'Android', 'Sdk');
      }
      return r'C:\Android\Sdk';
    } else if (Platform.isMacOS) {
      final home = userHomeDir();
      return p.join(home, 'Library', 'Android', 'sdk');
    } else {
      final home = userHomeDir();
      return p.join(home, 'Android', 'Sdk');
    }
  }

  static String defaultAvdHome() {
    final home = userHomeDir();
    return p.join(home, '.android', 'avd');
  }
}
