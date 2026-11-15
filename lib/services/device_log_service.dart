import 'dart:async';
import 'dart:io';

import '../models/log_entry.dart';
import 'adb_service.dart';

class DeviceLogService {
  DeviceLogService({required this.adbService});

  final AdbService adbService;

  static final _logcatRegex = RegExp(
    r'^(\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3})\s+([VDIWEFA])\s*/\s*([^(:]+?)(?:\(\s*(\d+)\s*\))?:\s*(.*)$',
  );

  LogEntry parseLine(String line, {LogEntry? previous}) {
    final trimmed = line.trimRight();
    final match = _logcatRegex.firstMatch(trimmed);

    if (match != null) {
      final timeStr = match.group(1)!;
      final levelChar = match.group(2)!;
      final tag = match.group(3)?.trim();
      final pid = match.group(4)?.trim();
      final msg = match.group(5) ?? '';

      final level = switch (levelChar) {
        'V' => LogLevel.verbose,
        'D' => LogLevel.debug,
        'I' => LogLevel.info,
        'W' => LogLevel.warning,
        'E' => LogLevel.error,
        'F' || 'A' => LogLevel.fatal,
        _ => LogLevel.info,
      };

      return LogEntry(
        timestamp: DateTime.now(),
        timeFormatted: timeStr,
        level: level,
        tag: tag,
        pid: pid,
        message: msg,
        raw: trimmed,
      );
    }

    if (trimmed.startsWith('--------- beginning of')) {
      return LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        tag: 'system',
        message: trimmed,
        raw: trimmed,
      );
    }

    // Continuation line (e.g. multi-line message or stack trace)
    return LogEntry(
      timestamp: previous?.timestamp ?? DateTime.now(),
      timeFormatted: previous?.timeFormatted,
      level: previous?.level ?? LogLevel.verbose,
      tag: previous?.tag,
      pid: previous?.pid,
      message: trimmed,
      raw: trimmed,
    );
  }

  Future<Process> startLogcat({
    required String adbPath,
    required String serial,
  }) {
    return adbService.startLogcat(adbPath: adbPath, serial: serial);
  }

  Future<void> clearLogcat({
    required String adbPath,
    required String serial,
  }) {
    return adbService.clearLogcat(adbPath: adbPath, serial: serial);
  }

  static final _focusRegex = RegExp(
    r'(?:mCurrentFocus|mFocusedApp|topResumedActivity|mResumedActivity|mFocusedWindow)[^\n]*?(?:u\d+\s+)?([a-zA-Z][a-zA-Z0-9_]*(?:\.[a-zA-Z0-9_]+)+)(?:/([a-zA-Z0-9_.]+))?',
  );

  static final _packageActivityRegex = RegExp(
    r'\b([a-zA-Z][a-zA-Z0-9_]*(?:\.[a-zA-Z0-9_]+)+)/([a-zA-Z0-9_.]+)',
  );

  AppProcessInfo? parseFocusedAppOutput(String output) {
    if (output.trim().isEmpty) return null;

    final match = _focusRegex.firstMatch(output);
    if (match != null) {
      final pkg = match.group(1)!;
      final act = match.group(2);
      return AppProcessInfo(packageName: pkg, activityName: act);
    }

    final fallbackMatch = _packageActivityRegex.firstMatch(output);
    if (fallbackMatch != null) {
      final pkg = fallbackMatch.group(1)!;
      final act = fallbackMatch.group(2);
      return AppProcessInfo(packageName: pkg, activityName: act);
    }

    return null;
  }

  /// On-demand detection of the currently running foreground/focused app on the device.
  Future<AppProcessInfo?> detectForegroundApp({
    required String adbPath,
    required String serial,
  }) async {
    try {
      // 1. Check dumpsys window (lightweight and fast)
      final windowRes = await Process.run(
        adbPath,
        <String>['-s', serial, 'shell', 'dumpsys', 'window'],
        runInShell: false,
      ).timeout(const Duration(seconds: 4));

      var appInfo = parseFocusedAppOutput(windowRes.stdout.toString());

      // 2. Fallback to dumpsys activity activities if needed
      if (appInfo == null) {
        final actRes = await Process.run(
          adbPath,
          <String>['-s', serial, 'shell', 'dumpsys', 'activity', 'activities'],
          runInShell: false,
        ).timeout(const Duration(seconds: 4));
        appInfo = parseFocusedAppOutput(actRes.stdout.toString());
      }

      // 3. Fallback to cmd activity get-current-focused-app (Android 13+)
      if (appInfo == null) {
        final cmdRes = await Process.run(
          adbPath,
          <String>['-s', serial, 'shell', 'cmd', 'activity', 'get-current-focused-app'],
          runInShell: false,
        ).timeout(const Duration(seconds: 3));
        appInfo = parseFocusedAppOutput(cmdRes.stdout.toString());
      }

      if (appInfo != null) {
        final pid = await getPidForPackage(
          adbPath: adbPath,
          serial: serial,
          packageName: appInfo.packageName,
        );
        return AppProcessInfo(
          packageName: appInfo.packageName,
          activityName: appInfo.activityName,
          pid: pid,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Queries the PID of a running package on the device.
  Future<String?> getPidForPackage({
    required String adbPath,
    required String serial,
    required String packageName,
  }) async {
    try {
      final res = await Process.run(
        adbPath,
        <String>['-s', serial, 'shell', 'pidof', '-s', packageName],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));

      final rawPid = res.stdout.toString().trim();
      final pid = rawPid.split(RegExp(r'\s+')).firstOrNull;
      if (pid != null && int.tryParse(pid) != null) {
        return pid;
      }

      // Fallback via ps -A
      final psRes = await Process.run(
        adbPath,
        <String>['-s', serial, 'shell', 'ps', '-A'],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));

      final lines = psRes.stdout.toString().split('\n');
      for (final line in lines) {
        if (line.contains(packageName)) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final cand = parts[1];
            if (int.tryParse(cand) != null) {
              return cand;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Lists third-party installed packages on the device without background polling.
  Future<List<String>> getInstalledPackages({
    required String adbPath,
    required String serial,
  }) async {
    try {
      final res = await Process.run(
        adbPath,
        <String>['-s', serial, 'shell', 'pm', 'list', 'packages', '-3'],
        runInShell: false,
      ).timeout(const Duration(seconds: 4));

      final packages = <String>[];
      for (final line in res.stdout.toString().split('\n')) {
        final trimmed = line.trim();
        if (trimmed.startsWith('package:')) {
          final pkg = trimmed.substring('package:'.length).trim();
          if (pkg.isNotEmpty) {
            packages.add(pkg);
          }
        }
      }
      packages.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return packages;
    } catch (_) {
      return const <String>[];
    }
  }

  /// Matches a log entry against the active filter mode (Project App, Flutter, React Native, or All).
  static bool matchesAppFilter({
    required LogEntry entry,
    required LogFilterMode mode,
    String? packageName,
    String? pid,
  }) {
    switch (mode) {
      case LogFilterMode.all:
        return true;

      case LogFilterMode.flutterOnly:
        final tag = entry.tag?.toLowerCase() ?? '';
        final msg = entry.message.toLowerCase();
        return tag == 'flutter' ||
            tag.startsWith('flutter') ||
            tag == 'dart' ||
            tag == 'flutter_engine' ||
            msg.contains('[verbose-2:ui_dart_state') ||
            msg.contains('flutter:') ||
            msg.contains('══╡ flutter error');

      case LogFilterMode.reactNativeOnly:
        final tag = entry.tag?.toLowerCase() ?? '';
        final msg = entry.message.toLowerCase();
        return tag.contains('reactnative') ||
            msg.contains('reactnative') ||
            tag == 'javascript';

      case LogFilterMode.appOnly:
        if ((packageName == null || packageName.isEmpty) && (pid == null || pid.isEmpty)) {
          return true;
        }

        // 1. Direct PID match (most accurate for everything logged inside app process)
        if (pid != null && pid.isNotEmpty && entry.pid != null && entry.pid == pid) {
          return true;
        }

        // 2. Package name match in tag or message
        if (packageName != null && packageName.isNotEmpty) {
          final pkgLower = packageName.toLowerCase();
          final tagLower = entry.tag?.toLowerCase() ?? '';
          final msgLower = entry.message.toLowerCase();

          if (tagLower == pkgLower || tagLower.contains(pkgLower)) {
            return true;
          }
          if (msgLower.contains(pkgLower)) {
            return true;
          }

          final parts = pkgLower.split('.');
          if (parts.length > 1) {
            final shortName = parts.last;
            if (shortName.length >= 3 && tagLower == shortName) {
              return true;
            }
          }
        }

        // 3. App crash exception match (AndroidRuntime)
        if (entry.tag == 'AndroidRuntime' &&
            (entry.level == LogLevel.error || entry.level == LogLevel.fatal)) {
          if (pid != null && pid.isNotEmpty && (entry.raw?.contains(pid) == true || entry.message.contains(pid))) {
            return true;
          }
          if (packageName != null && packageName.isNotEmpty && entry.message.toLowerCase().contains(packageName.toLowerCase())) {
            return true;
          }
        }

        return false;
    }
  }
}
