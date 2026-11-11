import 'dart:io';

import '../models/android_sdk.dart';
import '../models/app_settings.dart';
import '../models/emulator.dart';
import '../models/hardware_acceleration.dart';
import '../models/sdk_install_progress.dart';
import '../services/android_sdk_detection_service.dart';
import '../services/emulator_service.dart';
import '../services/scrcpy_service.dart';
import '../services/sdk_installer_service.dart';
import '../services/system_environment_service.dart';

class EmulatorRepository {
  EmulatorRepository({
    required this.sdkDetectionService,
    required this.emulatorService,
    required this.sdkInstallerService,
    required this.systemEnvironmentService,
    required this.scrcpyService,
  });

  final AndroidSdkDetectionService sdkDetectionService;
  final EmulatorService emulatorService;
  final SdkInstallerService sdkInstallerService;
  final SystemEnvironmentService systemEnvironmentService;
  final ScrcpyService scrcpyService;

  Future<AndroidSdk?> detectSdk(AppSettings settings) async {
    final sdks = await sdkDetectionService.detect(preferredPath: settings.sdkPath);
    return sdks.isEmpty ? null : sdks.first;
  }

  Future<List<Emulator>> listEmulators({
    required AndroidSdk sdk,
    required AppSettings settings,
  }) async {
    final physicalFuture = sdk.hasAdb
        ? emulatorService.listPhysicalDevices(
            adbPath: sdk.adbPath,
            favorites: settings.favoriteEmulators,
            lastLaunchByName: settings.lastLaunchByName,
          )
        : Future.value(const <Emulator>[]);

    final avdsFuture = sdk.hasEmulator
        ? emulatorService.listAvds(
            emulatorPath: sdk.emulatorPath,
            sdkPath: sdk.path,
            favorites: settings.favoriteEmulators,
            lastLaunchByName: settings.lastLaunchByName,
            adbPath: sdk.adbPath,
          )
        : Future.value(const <Emulator>[]);

    final results = await Future.wait([physicalFuture, avdsFuture]);
    final physicals = results[0];
    final avds = results[1];

    return <Emulator>[...physicals, ...avds];
  }

  Future<int?> launch(AndroidSdk sdk, Emulator emulator, {bool coldBoot = false, int? port}) {
    return emulatorService.launch(
      emulatorPath: sdk.emulatorPath,
      name: emulator.name,
      adbPath: sdk.adbPath,
      options: EmulatorLaunchOptions(coldBoot: coldBoot, port: port),
    );
  }

  Future<void> stop(AndroidSdk sdk, Emulator emulator) {
    return emulatorService.stop(adbPath: sdk.adbPath, name: emulator.name);
  }

  Future<bool> waitForBoot(AndroidSdk sdk, Emulator emulator) {
    return emulatorService.waitForBootCompleted(
      adbPath: sdk.adbPath,
      avdName: emulator.name,
    );
  }

  Future<HardwareAccelerationInfo> checkHardwareAcceleration(AndroidSdk? sdk, {bool forceRefresh = false}) {
    return systemEnvironmentService.checkHardwareAcceleration(
      emulatorPath: sdk?.emulatorPath,
      forceRefresh: forceRefresh,
    );
  }

  Future<bool> isScrcpyAvailable() => scrcpyService.isAvailable();

  Future<Process?> mirrorScreen({
    required AndroidSdk sdk,
    required String serial,
    String? windowTitle,
    String? customPath,
  }) {
    return scrcpyService.startMirror(
      serial: serial,
      windowTitle: windowTitle,
      customPath: customPath,
      sdkPath: sdk.path,
      adbPath: sdk.adbPath,
    );
  }

  Stream<SdkInstallProgress> setupEnvironment({
    required String sdkPath,
    String? preferredJdkPath,
    String? avdName,
    String apiLevel = '34',
  }) {
    return sdkInstallerService.runFullSetup(
      sdkPath: sdkPath,
      preferredJdkPath: preferredJdkPath,
      avdName: avdName,
      apiLevel: apiLevel,
    );
  }

  Future<void> createCustomAvd({
    required AndroidSdk sdk,
    required String name,
    required String systemImage,
    String device = 'pixel_7',
    int ramMb = 4096,
    int cpuCores = 4,
    int internalStorageMb = 8192,
    String gpuMode = 'auto',
    bool hardwareKeyboard = true,
    void Function(String progress)? onProgress,
  }) async {
    final avdManager = sdk.avdManagerPath;
    if (avdManager == null) {
      throw StateError('avdmanager not found. Please install cmdline-tools first.');
    }
    final javaHome = sdk.javaHome ?? await systemEnvironmentService.findValidJavaHome();
    if (javaHome == null) {
      throw StateError('Java 17+ home not found. Please setup JDK 17.');
    }

    // Auto-download system image if not yet present on disk
    final isInstalled = sdkInstallerService.isSystemImageInstalled(
      sdkRoot: sdk.path,
      systemImagePkg: systemImage,
    );

    if (!isInstalled) {
      onProgress?.call('Downloading system image ($systemImage)...');
      await sdkInstallerService.installSystemImagePackage(
        sdkRoot: sdk.path,
        javaHome: javaHome,
        package: systemImage,
        onProgress: onProgress,
      );
    }

    onProgress?.call('Creating virtual device hardware profile...');
    await sdkInstallerService.createCustomAvd(
      avdManagerPath: avdManager,
      javaHome: javaHome,
      sdkRoot: sdk.path,
      name: name,
      systemImage: systemImage,
      device: device,
      ramMb: ramMb,
      cpuCores: cpuCores,
      internalStorageMb: internalStorageMb,
      gpuMode: gpuMode,
      hardwareKeyboard: hardwareKeyboard,
    );
  }
}
