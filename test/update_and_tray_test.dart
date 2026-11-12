import 'package:flutter_test/flutter_test.dart';
import 'package:tray/models/emulator.dart';
import 'package:tray/services/tray_service.dart';
import 'package:tray/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('UpdateService Version Comparison', () {
    test('cleanVersion strips v prefixes, build metadata, and pre-release tags', () {
      expect(UpdateService.cleanVersion('v1.2.18'), '1.2.18');
      expect(UpdateService.cleanVersion('V1.2.18'), '1.2.18');
      expect(UpdateService.cleanVersion('1.2.17+1'), '1.2.17');
      expect(UpdateService.cleanVersion('v1.2.18-beta.2'), '1.2.18');
      expect(UpdateService.cleanVersion(' 1.2.19+99 '), '1.2.19');
    });

    test('isNewerVersion handles versions with build numbers without throwing FormatException', () {
      expect(UpdateService.isNewerVersion('v1.2.18', '1.2.17+1'), isTrue);
      expect(UpdateService.isNewerVersion('1.2.17', '1.2.17+1'), isFalse);
      expect(UpdateService.isNewerVersion('1.2.16', '1.2.17+1'), isFalse);
      expect(UpdateService.isNewerVersion('2.0.0', '1.9.99+5'), isTrue);
      expect(UpdateService.isNewerVersion('1.3.0', '1.2.99'), isTrue);
      expect(UpdateService.isNewerVersion('1.2.17', '1.2.18'), isFalse);
    });

    test('selectPlatformAsset strictly matches the current platform and ignores checksums', () {
      final mixedAssets = [
        {"name": "Tray-Setup.exe.sha256", "browser_download_url": "https://example.com/sha"},
        {"name": "Tray-Setup.exe", "browser_download_url": "https://example.com/exe"},
        {"name": "Tray.dmg.sha256", "browser_download_url": "https://example.com/dmg_sha"},
        {"name": "Tray.dmg", "browser_download_url": "https://example.com/dmg"},
      ];

      // Windows selection
      final winAsset = UpdateService.selectPlatformAsset(mixedAssets, isWindows: true, isMacOS: false);
      expect(winAsset["name"], "Tray-Setup.exe");

      // macOS selection
      final macAsset = UpdateService.selectPlatformAsset(mixedAssets, isWindows: false, isMacOS: true);
      expect(macAsset["name"], "Tray.dmg");

      // If release only has Windows exe, macOS selection MUST return null and NEVER fall back to .exe
      final windowsOnlyAssets = [
        {"name": "Tray-Setup.exe", "browser_download_url": "https://example.com/exe"},
        {"name": "Tray-Setup.exe.sha256", "browser_download_url": "https://example.com/sha"},
      ];
      final macNull = UpdateService.selectPlatformAsset(windowsOnlyAssets, isWindows: false, isMacOS: true);
      expect(macNull, isNull);
    });
  });

  group('AppTrayService', () {
    test('initialize and updateMenu handle diverse emulator states without throwing', () async {
      final trayService = AppTrayService();

      final emulators = <Emulator>[
        const Emulator(
          name: 'pixel_7_pro',
          status: EmulatorStatus.running,
        ),
        const Emulator(
          name: 'pixel_6a',
          status: EmulatorStatus.offline,
        ),
        const Emulator(
          name: 'Galaxy S24',
          isPhysical: true,
          serial: 'R58M12345',
          manufacturer: 'Samsung',
          model: 'Galaxy S24',
          connectionType: 'usb',
          status: EmulatorStatus.running,
        ),
      ];

      expect(emulators[0].displayName, 'pixel 7 pro');
      expect(emulators[2].displayName, 'Samsung Galaxy S24');

      // Update menu should safely format physical, running, stopped, and booting devices
      await trayService.updateMenu(
        emulators: emulators,
        booting: {'pixel_6a'},
      );

      // Verify dispose is safe
      await trayService.dispose();
    });
  });
}
