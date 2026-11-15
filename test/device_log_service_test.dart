import 'package:flutter_test/flutter_test.dart';
import 'package:tray/models/log_entry.dart';
import 'package:tray/services/adb_service.dart';
import 'package:tray/services/device_log_service.dart';

void main() {
  group('DeviceLogService line parser', () {
    late DeviceLogService service;

    setUp(() {
      service = DeviceLogService(adbService: AdbService());
    });

    test('parses standard debug logcat line with tag and PID', () {
      const line = '05-18 14:23:45.678 D/ActivityManager( 1234): Starting: Intent { act=android.intent.action.MAIN }';
      final entry = service.parseLine(line);

      expect(entry.level, LogLevel.debug);
      expect(entry.tag, 'ActivityManager');
      expect(entry.pid, '1234');
      expect(entry.timeFormatted, '05-18 14:23:45.678');
      expect(entry.message, 'Starting: Intent { act=android.intent.action.MAIN }');
      expect(entry.level.shortCode, 'D');
    });

    test('parses error logcat line without PID and with colon in message', () {
      const line = '11-15 11:22:33.444 E/AndroidRuntime: FATAL EXCEPTION: main process error: code 5';
      final entry = service.parseLine(line);

      expect(entry.level, LogLevel.error);
      expect(entry.tag, 'AndroidRuntime');
      expect(entry.pid, isNull);
      expect(entry.timeFormatted, '11-15 11:22:33.444');
      expect(entry.message, 'FATAL EXCEPTION: main process error: code 5');
      expect(entry.level.shortCode, 'E');
      expect(entry.level.priority, 4);
    });

    test('parses warning and info logcat lines', () {
      const warnLine = '01-01 00:00:01.000 W/AudioTrack(  890): sample rate 48000';
      final warnEntry = service.parseLine(warnLine);
      expect(warnEntry.level, LogLevel.warning);
      expect(warnEntry.tag, 'AudioTrack');
      expect(warnEntry.pid, '890');

      const infoLine = '01-01 00:00:02.000 I/flutter( 4567): [INFO] User clicked button';
      final infoEntry = service.parseLine(infoLine);
      expect(infoEntry.level, LogLevel.info);
      expect(infoEntry.tag, 'flutter');
      expect(infoEntry.pid, '4567');
      expect(infoEntry.message, '[INFO] User clicked button');
    });

    test('handles system buffer markers gracefully', () {
      const line = '--------- beginning of main';
      final entry = service.parseLine(line);

      expect(entry.level, LogLevel.info);
      expect(entry.tag, 'system');
      expect(entry.message, '--------- beginning of main');
    });

    test('inherits previous entry metadata for multiline stack traces', () {
      const parentLine = '11-15 11:22:33.444 E/AndroidRuntime(1234): FATAL EXCEPTION: main';
      final parentEntry = service.parseLine(parentLine);

      const stackLine = '\tat com.example.MainActivity.onCreate(MainActivity.java:45)';
      final childEntry = service.parseLine(stackLine, previous: parentEntry);

      expect(childEntry.level, LogLevel.error);
      expect(childEntry.tag, 'AndroidRuntime');
      expect(childEntry.pid, '1234');
      expect(childEntry.timeFormatted, '11-15 11:22:33.444');
      expect(childEntry.message, stackLine);
    });
  });

  group('LogLevel priorities and short codes', () {
    test('verifies priority ordering for log level filtering', () {
      expect(LogLevel.verbose.priority < LogLevel.debug.priority, isTrue);
      expect(LogLevel.debug.priority < LogLevel.info.priority, isTrue);
      expect(LogLevel.info.priority < LogLevel.warning.priority, isTrue);
      expect(LogLevel.warning.priority < LogLevel.error.priority, isTrue);
      expect(LogLevel.error.priority < LogLevel.fatal.priority, isTrue);
    });

    test('verifies short codes', () {
      expect(LogLevel.verbose.shortCode, 'V');
      expect(LogLevel.debug.shortCode, 'D');
      expect(LogLevel.info.shortCode, 'I');
      expect(LogLevel.warning.shortCode, 'W');
      expect(LogLevel.error.shortCode, 'E');
      expect(LogLevel.fatal.shortCode, 'F');
    });
  });
}
