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

  group('DeviceLogService app detection and parsing', () {
    late DeviceLogService service;

    setUp(() {
      service = DeviceLogService(adbService: AdbService());
    });

    test('parses dumpsys window mCurrentFocus output', () {
      const output = '  mCurrentFocus=Window{8ab9964 u0 com.example.myproject/com.example.myproject.MainActivity}';
      final result = service.parseFocusedAppOutput(output);

      expect(result, isNotNull);
      expect(result!.packageName, 'com.example.myproject');
      expect(result.activityName, 'com.example.myproject.MainActivity');
      expect(result.isLauncher, isFalse);
      expect(result.shortName, 'myproject');
    });

    test('parses dumpsys activity mResumedActivity output', () {
      const output = '  mResumedActivity: ActivityRecord{45fa7b2 u0 io.flutter.demo/.MainActivity t123}';
      final result = service.parseFocusedAppOutput(output);

      expect(result, isNotNull);
      expect(result!.packageName, 'io.flutter.demo');
      expect(result.activityName, '.MainActivity');
    });

    test('parses cmd activity get-current-focused-app output', () {
      const output = 'mCurrentFocus=com.whatsapp/com.whatsapp.HomeActivity';
      final result = service.parseFocusedAppOutput(output);

      expect(result, isNotNull);
      expect(result!.packageName, 'com.whatsapp');
      expect(result.activityName, 'com.whatsapp.HomeActivity');
    });

    test('identifies system launcher correctly', () {
      const output = '  mCurrentFocus=Window{37b9264 u0 com.google.android.apps.nexuslauncher/.NexusLauncherActivity}';
      final result = service.parseFocusedAppOutput(output);

      expect(result, isNotNull);
      expect(result!.packageName, 'com.google.android.apps.nexuslauncher');
      expect(result.isLauncher, isTrue);
    });

    test('returns null for empty or invalid output', () {
      expect(service.parseFocusedAppOutput(''), isNull);
      expect(service.parseFocusedAppOutput('mCurrentFocus=null'), isNull);
      expect(service.parseFocusedAppOutput('random text without packages'), isNull);
    });
  });

  group('DeviceLogService matchesAppFilter', () {
    final flutterEntry = LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.info,
      tag: 'flutter',
      pid: '5001',
      message: 'Counter tapped: 42',
    );

    final appProcessEntry = LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.debug,
      tag: 'MyNetworkService',
      pid: '5001',
      message: 'GET https://api.example.com/data HTTP/1.1 200 OK',
    );

    final systemNoiseEntry = LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.debug,
      tag: 'WifiStateMachine',
      pid: '1002',
      message: 'Scanning Wi-Fi networks in background...',
    );

    final rnEntry = LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.info,
      tag: 'ReactNativeJS',
      pid: '6002',
      message: 'Running "MyApp" with {"rootTag":1}',
    );

    final crashEntry = LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.error,
      tag: 'AndroidRuntime',
      pid: '5001',
      message: 'FATAL EXCEPTION: main process com.example.myproject crash pid 5001',
    );

    test('LogFilterMode.all matches every entry', () {
      expect(DeviceLogService.matchesAppFilter(entry: flutterEntry, mode: LogFilterMode.all), isTrue);
      expect(DeviceLogService.matchesAppFilter(entry: systemNoiseEntry, mode: LogFilterMode.all), isTrue);
      expect(DeviceLogService.matchesAppFilter(entry: rnEntry, mode: LogFilterMode.all), isTrue);
    });

    test('LogFilterMode.flutterOnly isolates Flutter logs', () {
      expect(DeviceLogService.matchesAppFilter(entry: flutterEntry, mode: LogFilterMode.flutterOnly), isTrue);
      expect(DeviceLogService.matchesAppFilter(entry: systemNoiseEntry, mode: LogFilterMode.flutterOnly), isFalse);
      expect(DeviceLogService.matchesAppFilter(entry: rnEntry, mode: LogFilterMode.flutterOnly), isFalse);
    });

    test('LogFilterMode.reactNativeOnly isolates React Native logs', () {
      expect(DeviceLogService.matchesAppFilter(entry: rnEntry, mode: LogFilterMode.reactNativeOnly), isTrue);
      expect(DeviceLogService.matchesAppFilter(entry: systemNoiseEntry, mode: LogFilterMode.reactNativeOnly), isFalse);
      expect(DeviceLogService.matchesAppFilter(entry: flutterEntry, mode: LogFilterMode.reactNativeOnly), isFalse);
    });

    test('LogFilterMode.appOnly filters by app PID and excludes system spam', () {
      expect(
        DeviceLogService.matchesAppFilter(
          entry: appProcessEntry,
          mode: LogFilterMode.appOnly,
          packageName: 'com.example.myproject',
          pid: '5001',
        ),
        isTrue,
      );

      // System noise has pid 1002, so it is strictly rejected!
      expect(
        DeviceLogService.matchesAppFilter(
          entry: systemNoiseEntry,
          mode: LogFilterMode.appOnly,
          packageName: 'com.example.myproject',
          pid: '5001',
        ),
        isFalse,
      );

      // Matches crash from the same app PID
      expect(
        DeviceLogService.matchesAppFilter(
          entry: crashEntry,
          mode: LogFilterMode.appOnly,
          packageName: 'com.example.myproject',
          pid: '5001',
        ),
        isTrue,
      );
    });

    test('LogFilterMode.appOnly matches package name when PID is not yet known', () {
      final mentionEntry = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        tag: 'ActivityTaskManager',
        pid: '1001',
        message: 'START u0 {act=android.intent.action.MAIN cmp=com.example.myproject/.MainActivity}',
      );

      expect(
        DeviceLogService.matchesAppFilter(
          entry: mentionEntry,
          mode: LogFilterMode.appOnly,
          packageName: 'com.example.myproject',
          pid: null,
        ),
        isTrue,
      );
    });
  });
}
