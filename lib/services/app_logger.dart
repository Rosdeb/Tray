import 'package:logger/logger.dart';

import '../models/log_entry.dart';

class AppLogger {
  AppLogger() : _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  final Logger _logger;
  final List<LogEntry> _entries = <LogEntry>[];

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void verbose(String message) {
    _entries.add(LogEntry(timestamp: DateTime.now(), level: LogLevel.verbose, message: message));
    _logger.t(message);
  }

  void debug(String message) {
    _entries.add(LogEntry(timestamp: DateTime.now(), level: LogLevel.debug, message: message));
    _logger.d(message);
  }

  void info(String message) {
    _entries.add(LogEntry(timestamp: DateTime.now(), level: LogLevel.info, message: message));
    _logger.i(message);
  }

  void warning(String message) {
    _entries.add(LogEntry(timestamp: DateTime.now(), level: LogLevel.warning, message: message));
    _logger.w(message);
  }

  void error(String message, [Object? error]) {
    final text = error == null ? message : '$message: $error';
    _entries.add(LogEntry(timestamp: DateTime.now(), level: LogLevel.error, message: text));
    _logger.e(message, error: error);
  }

  void clear() {
    _entries.clear();
  }
}
