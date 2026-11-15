enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
  fatal;

  String get shortCode => switch (this) {
        LogLevel.verbose => 'V',
        LogLevel.debug => 'D',
        LogLevel.info => 'I',
        LogLevel.warning => 'W',
        LogLevel.error => 'E',
        LogLevel.fatal => 'F',
      };

  int get priority => switch (this) {
        LogLevel.verbose => 0,
        LogLevel.debug => 1,
        LogLevel.info => 2,
        LogLevel.warning => 3,
        LogLevel.error => 4,
        LogLevel.fatal => 5,
      };
}

enum LogFilterMode {
  all('All Device Logs'),
  appOnly('Project App'),
  flutterOnly('Flutter / Dart'),
  reactNativeOnly('React Native');

  const LogFilterMode(this.label);
  final String label;
}

class AppProcessInfo {
  const AppProcessInfo({
    required this.packageName,
    this.pid,
    this.activityName,
  });

  final String packageName;
  final String? pid;
  final String? activityName;

  bool get isLauncher =>
      packageName.contains('launcher') ||
      packageName.contains('nexuslauncher') ||
      packageName == 'com.android.systemui';

  String get shortName {
    final parts = packageName.split('.');
    return parts.isNotEmpty ? parts.last : packageName;
  }
}

class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
    this.pid,
    this.raw,
    this.timeFormatted,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? tag;
  final String? pid;
  final String? raw;
  final String? timeFormatted;
}
