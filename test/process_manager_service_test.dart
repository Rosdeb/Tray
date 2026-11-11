import 'package:flutter_test/flutter_test.dart';
import 'package:tray/models/system_process.dart';
import 'package:tray/services/process_manager_service.dart';

void main() {
  group('ProcessManagerService', () {
    test('categorizes processes correctly', () {
      expect(
        ProcessManagerService.categorizeProcess('qemu-system-x86_64', ''),
        equals(ProcessCategory.emulator),
      );
      expect(
        ProcessManagerService.categorizeProcess('emulator.exe', '-avd Pixel_7'),
        equals(ProcessCategory.emulator),
      );
      expect(
        ProcessManagerService.categorizeProcess('adb', 'fork-server server'),
        equals(ProcessCategory.adb),
      );
      expect(
        ProcessManagerService.categorizeProcess('java', 'org.gradle.launcher.daemon.bootstrap.GradleDaemon'),
        equals(ProcessCategory.javaGradle),
      );
      expect(
        ProcessManagerService.categorizeProcess('scrcpy', '-s emulator-5554'),
        equals(ProcessCategory.scrcpy),
      );
    });

    test('relevance filter captures Android tooling and ignores unrelated', () {
      expect(ProcessManagerService.isRelevantProcess('adb', ''), isTrue);
      expect(ProcessManagerService.isRelevantProcess('qemu-system-aarch64', ''), isTrue);
      expect(ProcessManagerService.isRelevantProcess('java', 'GradleDaemon'), isTrue);
      expect(ProcessManagerService.isRelevantProcess('chrome', ''), isFalse);
      expect(ProcessManagerService.isRelevantProcess('spotify', ''), isFalse);
    });

    test('SystemProcessItem memory formatting', () {
      const item1 = SystemProcessItem(
        pid: 100,
        name: 'adb',
        category: ProcessCategory.adb,
        memoryBytes: 50 * 1024 * 1024,
      );
      expect(item1.formattedMemory, equals('50 MB'));

      const item2 = SystemProcessItem(
        pid: 101,
        name: 'qemu',
        category: ProcessCategory.emulator,
        memoryBytes: 2500 * 1024 * 1024,
      );
      expect(item2.formattedMemory, equals('2.4 GB'));
    });
  });
}
