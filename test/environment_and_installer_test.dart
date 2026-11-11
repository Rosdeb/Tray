import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tray/core/utils/platform_paths.dart';
import 'package:tray/services/emulator_service.dart';
import 'package:tray/services/sdk_installer_service.dart';
import 'package:tray/services/system_environment_service.dart';

void main() {
  group('SystemEnvironmentService', () {
    final envService = SystemEnvironmentService();

    test('detects host ABI accurately', () {
      final abi = envService.getHostAbi();
      expect(abi, anyOf('arm64-v8a', 'x86_64'));
    });

    test('checks hardware acceleration heuristic', () async {
      final accel = await envService.checkHardwareAcceleration();
      expect(accel.message, isNotEmpty);
      expect(accel.details, isNotEmpty);
    });
  });

  group('SdkInstallerService', () {
    final envService = SystemEnvironmentService();
    final installerService = SdkInstallerService(envService);

    test('generates valid Adoptium Temurin OpenJDK 17 download URL', () {
      final url = installerService.getTemurinJdkUrl();
      expect(url, contains('api.adoptium.net/v3/binary/latest/17/ga'));
      expect(url, contains('jdk/hotspot/normal/eclipse'));
    });

    test('generates valid Google cmdline-tools download URL', () {
      final url = installerService.getCmdlineToolsUrl();
      expect(url, contains('dl.google.com/android/repository/commandlinetools-'));
      expect(url, endsWith('_latest.zip'));
    });

    test('writes standard SDK license hashes', () async {
      final tempDir = Directory.systemTemp.createTempSync('sdk_lic_test_');
      try {
        await installerService.writeSdkLicenses(tempDir);
        final licenseFile = File('${tempDir.path}/licenses/android-sdk-license');
        expect(await licenseFile.exists(), isTrue);

        final content = await licenseFile.readAsString();
        expect(content, contains('24333f8a63b6825ea9c5514f83c2829b004d1fee'));
        expect(content, contains('8933bad161af4178b1185d1a37fbf41ea5269c55'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('EmulatorLaunchOptions & Ports', () {
    test('generates command-line arguments including ports and options', () {
      const options = EmulatorLaunchOptions(
        coldBoot: true,
        port: 5556,
        noWindow: true,
        wipeData: true,
        writableSystem: true,
      );

      final args = options.toArguments('Pixel_7_API_34');
      expect(args, contains('-avd'));
      expect(args, contains('Pixel_7_API_34'));
      expect(args, contains('-port'));
      expect(args, contains('5556'));
      expect(args, contains('-no-snapshot-load'));
      expect(args, contains('-wipe-data'));
      expect(args, contains('-writable-system'));
      expect(args, contains('-no-window'));
    });
  });

  group('PlatformPaths & SDK Root Resolution', () {
    test('resolves SDK root when user selects subdirectories', () {
      final tempSdk = Directory.systemTemp.createTempSync('sdk_resolve_test_');
      final emulatorDir = Directory('${tempSdk.path}/emulator')..createSync(recursive: true);
      final platformToolsDir = Directory('${tempSdk.path}/platform-tools')..createSync(recursive: true);

      try {
        expect(PlatformPaths.resolveSdkRoot(emulatorDir.path), equals(tempSdk.path));
        expect(PlatformPaths.resolveSdkRoot(platformToolsDir.path), equals(tempSdk.path));
        expect(PlatformPaths.resolveSdkRoot('${emulatorDir.path}/'), equals(tempSdk.path));
      } finally {
        tempSdk.deleteSync(recursive: true);
      }
    });

    test('cleans sandboxed macOS container paths to real user home', () {
      const containerPath =
          '/Users/testuser/Library/Containers/com.example.tray/Data/Library/Android/sdk';
      final resolved = PlatformPaths.resolveSdkRoot(containerPath);
      expect(resolved, equals('/Users/testuser/Library/Android/sdk'));
    });
  });
}
