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
}
