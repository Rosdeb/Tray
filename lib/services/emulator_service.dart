import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/utils/platform_paths.dart';
import '../models/emulator.dart';
import 'adb_service.dart';

class EmulatorLaunchOptions {
  const EmulatorLaunchOptions({
    this.coldBoot = false,
    this.noSnapshot = false,
    this.writableSystem = false,
    this.gpu,
    this.memoryMb,
    this.dpi,
    this.landscape = false,
    this.port,
    this.noWindow = false,
    this.wipeData = false,
  });

  final bool coldBoot;
  final bool noSnapshot;
  final bool writableSystem;
  final String? gpu;
  final int? memoryMb;
  final int? dpi;
  final bool landscape;
  final int? port;
  final bool noWindow;
  final bool wipeData;

  List<String> toArguments(String name) {
    return <String>[
      '-avd',
      name,
      if (port != null) ...<String>['-port', port.toString()],
      if (coldBoot || noSnapshot) '-no-snapshot-load',
      if (wipeData) '-wipe-data',
      if (writableSystem) '-writable-system',
      if (noWindow) '-no-window',
      if (gpu != null && gpu!.trim().isNotEmpty) ...<String>['-gpu', gpu!],
      if (memoryMb != null) ...<String>['-memory', memoryMb.toString()],
      if (dpi != null) ...<String>['-dpi-device', dpi.toString()],
      if (landscape) ...<String>['-skin', 'landscape'],
    ];
  }
}

class EmulatorService {
  EmulatorService(this._adbService);
  final AdbService _adbService;

  Future<List<Emulator>> listPhysicalDevices({
    required String adbPath,
    required Set<String> favorites,
    required Map<String, DateTime> lastLaunchByName,
  }) async {
    final connected = await _adbService.listConnectedDevices(adbPath);
    final physicals = <Emulator>[];

    for (final dev in connected) {
      if (dev.isEmulator) continue;

      final mfr = dev.manufacturer ?? '';
      final model = dev.model ?? dev.serial;
      final displayName = mfr.isNotEmpty && !model.toLowerCase().contains(mfr.toLowerCase())
          ? '$mfr $model'
          : model;

      physicals.add(
        Emulator(
          name: displayName,
          serial: dev.serial,
          model: dev.model,
          manufacturer: dev.manufacturer,
          connectionType: dev.connectionType,
          isPhysical: true,
          status: dev.state == 'device'
              ? EmulatorStatus.running
              : (dev.state == 'unauthorized' ? EmulatorStatus.unauthorized : EmulatorStatus.offline),
          androidVersion: dev.androidVersion != null ? 'Android ${dev.androidVersion}' : null,
          apiLevel: dev.apiLevel,
          deviceType: EmulatorDeviceType.phone,
          isFavorite: favorites.contains(dev.serial) || favorites.contains(displayName),
          lastUsedAt: lastLaunchByName[dev.serial],
        ),
      );
    }
    return physicals;
  }

  Future<List<Emulator>> listAvds({
    required String emulatorPath,
    required String sdkPath,
    required Set<String> favorites,
    required Map<String, DateTime> lastLaunchByName,
    required String adbPath,
  }) async {
    final result = await Process.run(
      emulatorPath,
      const <String>['-list-avds'],
      runInShell: false,
    ).timeout(const Duration(seconds: 10));
    if (result.exitCode != 0) {
      throw ProcessException(emulatorPath, const <String>['-list-avds'], result.stderr.toString(), result.exitCode);
    }

    final runningNames = await _runningAvdNames(adbPath);
    final avdHome = _avdHome();
    return result.stdout
        .toString()
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((name) => _buildEmulator(
              name: name,
              avdPath: avdHome == null ? null : p.join(avdHome, '$name.avd'),
              isFavorite: favorites.contains(name),
              lastUsedAt: lastLaunchByName[name],
              status: runningNames.contains(name) ? EmulatorStatus.running : EmulatorStatus.offline,
            ))
        .toList(growable: false)
      ..sort(_sortEmulators);
  }

  /// Launch an emulator instance.
  /// If [options.port] is not specified and [adbPath] is provided, auto-assigns next free even port.
  Future<int?> launch({
    required String emulatorPath,
    required String name,
    String? adbPath,
    EmulatorLaunchOptions options = const EmulatorLaunchOptions(),
  }) async {
    int? port = options.port;
    if (port == null && adbPath != null && adbPath.isNotEmpty) {
      try {
        port = await _adbService.getNextAvailablePort(adbPath);
      } catch (_) {}
    }

    final finalOptions = port != null ? EmulatorLaunchOptions(
      coldBoot: options.coldBoot,
      noSnapshot: options.noSnapshot,
      writableSystem: options.writableSystem,
      gpu: options.gpu,
      memoryMb: options.memoryMb,
      dpi: options.dpi,
      landscape: options.landscape,
      port: port,
      noWindow: options.noWindow,
      wipeData: options.wipeData,
    ) : options;

    final args = finalOptions.toArguments(name);

    if (Platform.isWindows) {
      await _launchHiddenWindows(emulatorPath, args);
    } else {
      await Process.start(emulatorPath, args, mode: ProcessStartMode.detached);
    }

    return port;
  }

  Future<void> _launchHiddenWindows(String executable, List<String> arguments) async {
    final tempDir = Directory.systemTemp.createTempSync('emulator_launch_');
    final vbsFile = File(p.join(tempDir.path, 'run_hidden.vbs'));

    final argsString = arguments.map((arg) => '"${arg.replaceAll('"', '""')}"').join(' ');
    final command = '"$executable" $argsString';
    final escapedCommand = command.replaceAll('"', '""');

    final vbsContent = 'CreateObject("Wscript.Shell").Run "$escapedCommand", 0, False';
    vbsFile.writeAsStringSync(vbsContent);

    await Process.start('wscript.exe', [vbsFile.path]);

    Future.delayed(const Duration(seconds: 3), () {
      try {
        if (vbsFile.existsSync()) {
          vbsFile.deleteSync();
        }
        if (tempDir.existsSync()) {
          tempDir.deleteSync();
        }
      } catch (_) {}
    });
  }

  /// Stops an emulator cleanly using `adb emu kill`.
  Future<void> stop({
    required String adbPath,
    required String name,
  }) async {
    await _adbService.killByAvdName(adbPath, name);
  }

  /// Polls ADB until sys.boot_completed is 1 or timeout expires.
  Future<bool> waitForBootCompleted({
    required String adbPath,
    required String avdName,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final stopWatch = Stopwatch()..start();
    while (stopWatch.elapsed < timeout) {
      final serial = await _adbService.findSerialForAvd(adbPath, avdName);
      if (serial != null) {
        final isBooted = await _adbService.isBootCompleted(adbPath, serial);
        if (isBooted) {
          return true;
        }
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    return false;
  }

  Future<Set<String>> _runningAvdNames(String adbPath) async {
    try {
      final devices = await _adbService.devices(adbPath);
      final names = <String>{};
      for (final line in devices) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.isEmpty || !parts.first.startsWith('emulator-')) {
          continue;
        }
        final name = await _adbService.avdName(adbPath, parts.first);
        if (name != null && name.isNotEmpty && !name.startsWith('OK')) {
          names.add(name);
        }
      }
      return names;
    } catch (_) {
      return <String>{};
    }
  }

  Emulator _buildEmulator({
    required String name,
    required String? avdPath,
    required bool isFavorite,
    required DateTime? lastUsedAt,
    required EmulatorStatus status,
  }) {
    final config = _readAvdConfig(avdPath);
    final apiLevel = int.tryParse(config['image.sysdir.1']?.split('android-').last.split(RegExp(r'[\\/;]')).first ?? '');
    return Emulator(
      name: name,
      apiLevel: apiLevel,
      androidVersion: apiLevel == null ? null : 'API $apiLevel',
      architecture: config['abi.type'] ?? config['hw.cpu.arch'],
      path: avdPath,
      resolution: _resolution(config),
      ram: config['hw.ramSize'] == null ? null : '${config['hw.ramSize']} MB',
      internalStorage: config['disk.dataPartition.size'],
      snapshotEnabled: config['snapshot.present'] == 'true',
      createdAt: _createdAt(avdPath),
      lastUsedAt: lastUsedAt,
      isFavorite: isFavorite,
      status: status,
      deviceType: _deviceType(name, config),
    );
  }

  Map<String, String> _readAvdConfig(String? avdPath) {
    if (avdPath == null) {
      return const <String, String>{};
    }
    final file = File(p.join(avdPath, 'config.ini'));
    if (!file.existsSync()) {
      return const <String, String>{};
    }
    return Map.fromEntries(
      file
          .readAsLinesSync()
          .where((line) => line.contains('='))
          .map((line) {
            final index = line.indexOf('=');
            return MapEntry(line.substring(0, index).trim(), line.substring(index + 1).trim());
          }),
    );
  }

  String? _resolution(Map<String, String> config) {
    final width = config['hw.lcd.width'];
    final height = config['hw.lcd.height'];
    if (width == null || height == null) {
      return null;
    }
    return '${width}x$height';
  }

  DateTime? _createdAt(String? avdPath) {
    if (avdPath == null) {
      return null;
    }
    try {
      return Directory(avdPath).statSync().changed;
    } catch (_) {
      return null;
    }
  }

  EmulatorDeviceType _deviceType(String name, Map<String, String> config) {
    final text = '${name.toLowerCase()} ${config['tag.display']?.toLowerCase() ?? ''}';
    if (text.contains('tablet')) return EmulatorDeviceType.tablet;
    if (text.contains('fold')) return EmulatorDeviceType.foldable;
    if (text.contains('wear')) return EmulatorDeviceType.wear;
    if (text.contains('tv')) return EmulatorDeviceType.tv;
    if (text.contains('auto')) return EmulatorDeviceType.automotive;
    if (text.contains('phone') || text.contains('pixel')) return EmulatorDeviceType.phone;
    return EmulatorDeviceType.unknown;
  }

  String? _avdHome() {
    return PlatformPaths.defaultAvdHome();
  }

  int _sortEmulators(Emulator left, Emulator right) {
    final favoriteCompare = (right.isFavorite ? 1 : 0).compareTo(left.isFavorite ? 1 : 0);
    if (favoriteCompare != 0) return favoriteCompare;
    final runningCompare = (right.isRunning ? 1 : 0).compareTo(left.isRunning ? 1 : 0);
    if (runningCompare != 0) return runningCompare;
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }
}
