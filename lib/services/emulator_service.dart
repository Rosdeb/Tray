import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

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
  });

  final bool coldBoot;
  final bool noSnapshot;
  final bool writableSystem;
  final String? gpu;
  final int? memoryMb;
  final int? dpi;
  final bool landscape;

  List<String> toArguments(String name) {
    return <String>[
      '-avd',
      name,
      if (coldBoot || noSnapshot) '-no-snapshot-load',
      if (writableSystem) '-writable-system',
      if (gpu != null && gpu!.trim().isNotEmpty) ...<String>['-gpu', gpu!],
      if (memoryMb != null) ...<String>['-memory', memoryMb.toString()],
      if (dpi != null) ...<String>['-dpi-device', dpi.toString()],
      if (landscape) '-skin',
      if (landscape) 'landscape',
    ];
  }
}

class EmulatorService {
  EmulatorService(this._adbService);
  final AdbService _adbService;

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

  Future<void> launch({
    required String emulatorPath,
    required String name,
    EmulatorLaunchOptions options = const EmulatorLaunchOptions(),
  }) async {
    final args = options.toArguments(name);

    if (Platform.isWindows) {
      await _launchHiddenWindows(emulatorPath, args);
    } else {
      await Process.start(emulatorPath, args, mode: ProcessStartMode.detached);
    }
  }
  Future<void> _launchHiddenWindows(String executable, List<String> arguments) async {
    // for hide cmd use the wscript.exe for background process run :
    final tempDir = Directory.systemTemp.createTempSync('emulator_launch_');
    final vbsFile = File(p.join(tempDir.path, 'run_hidden.vbs'));

    final argsString = arguments.map((arg) => '"${arg.replaceAll('"', '""')}"').join(' ');
    final command = '"$executable" $argsString';
    final escapedCommand = command.replaceAll('"', '""');

    final vbsContent = 'CreateObject("Wscript.Shell").Run "$escapedCommand", 0, False';
    vbsFile.writeAsStringSync(vbsContent);

    await Process.start('wscript.exe', [vbsFile.path]);


    Future.delayed(const Duration(seconds: 2), () {
      try {
        if (vbsFile.existsSync()) {
          vbsFile.deleteSync();
        }
        if (tempDir.existsSync()) {
          tempDir.deleteSync();
        }
      } catch (_) {

      }
    });
  }


  Future<void> stop({
    required String adbPath,
    required String name,
  }) async {
    final devices = await _adbService.devices(adbPath);
    for (final line in devices) {
      final parts = line.split(RegExp(r'\s+'));
      if (parts.isEmpty || !parts.first.startsWith('emulator-')) {
        continue;
      }
      final avdName = await _adbService.avdName(adbPath, parts.first);
      if (avdName == name) {
        await _adbService.kill(adbPath, parts.first);
        return;
      }
    }
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
    final env = Platform.environment;
    final home = env[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    if (home == null || home.trim().isEmpty) {
      return null;
    }
    return p.join(home, '.android', 'avd');
  }

  int _sortEmulators(Emulator left, Emulator right) {
    final favoriteCompare = (right.isFavorite ? 1 : 0).compareTo(left.isFavorite ? 1 : 0);
    if (favoriteCompare != 0) return favoriteCompare;
    final runningCompare = (right.isRunning ? 1 : 0).compareTo(left.isRunning ? 1 : 0);
    if (runningCompare != 0) return runningCompare;
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }
}
