import 'dart:async';
import 'dart:io';

class AdbDeviceInfo {
  const AdbDeviceInfo({
    required this.serial,
    required this.state,
    this.model,
    this.product,
    this.device,
    this.isEmulator = false,
    this.androidVersion,
    this.apiLevel,
    this.manufacturer,
    this.connectionType = 'USB',
  });

  final String serial;
  final String state;
  final String? model;
  final String? product;
  final String? device;
  final bool isEmulator;
  final String? androidVersion;
  final int? apiLevel;
  final String? manufacturer;
  final String connectionType;

  bool get isAuthorized => state == 'device';
}

class AdbService {
  Future<List<String>> devices(String adbPath) async {
    final result = await Process.run(adbPath, const <String>['devices'], runInShell: false)
        .timeout(const Duration(seconds: 8));
    if (result.exitCode != 0) {
      throw ProcessException(adbPath, const <String>['devices'], result.stderr.toString(), result.exitCode);
    }

    return result.stdout
        .toString()
        .split(RegExp(r'\r?\n'))
        .skip(1)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  /// Lists all devices connected to ADB with parsed metadata.
  /// Distinguishes between emulators and real physical devices.
  Future<List<AdbDeviceInfo>> listConnectedDevices(String adbPath) async {
    final devList = <AdbDeviceInfo>[];
    try {
      final result = await Process.run(
        adbPath,
        const <String>['devices', '-l'],
        runInShell: false,
      ).timeout(const Duration(seconds: 8));

      if (result.exitCode != 0) return devList;

      final lines = result.stdout
          .toString()
          .split(RegExp(r'\r?\n'))
          .skip(1)
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty);

      for (final line in lines) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length < 2) continue;

        final serial = parts[0];
        final state = parts[1];
        final isEmu = serial.startsWith('emulator-');

        String? model;
        String? product;
        String? device;

        for (int i = 2; i < parts.length; i++) {
          final part = parts[i];
          if (part.startsWith('model:')) {
            model = part.substring('model:'.length).replaceAll('_', ' ');
          } else if (part.startsWith('product:')) {
            product = part.substring('product:'.length);
          } else if (part.startsWith('device:')) {
            device = part.substring('device:'.length);
          }
        }

        final connectionType = serial.contains(':') ? 'Wi-Fi' : 'USB';

        String? androidVersion;
        int? apiLevel;
        String? manufacturer;

        if (!isEmu && state == 'device') {
          try {
            final propRes = await Process.run(
              adbPath,
              <String>[
                '-s',
                serial,
                'shell',
                'getprop ro.product.model; getprop ro.product.manufacturer; getprop ro.build.version.release; getprop ro.build.version.sdk'
              ],
              runInShell: false,
            ).timeout(const Duration(seconds: 3));

            if (propRes.exitCode == 0) {
              final propLines = propRes.stdout.toString().split(RegExp(r'\r?\n'));
              if (propLines.isNotEmpty && propLines[0].trim().isNotEmpty) {
                model = propLines[0].trim();
              }
              if (propLines.length > 1 && propLines[1].trim().isNotEmpty) {
                manufacturer = propLines[1].trim();
              }
              if (propLines.length > 2 && propLines[2].trim().isNotEmpty) {
                androidVersion = propLines[2].trim();
              }
              if (propLines.length > 3 && propLines[3].trim().isNotEmpty) {
                apiLevel = int.tryParse(propLines[3].trim());
              }
            }
          } catch (_) {}
        }

        devList.add(AdbDeviceInfo(
          serial: serial,
          state: state,
          model: model,
          product: product,
          device: device,
          isEmulator: isEmu,
          androidVersion: androidVersion,
          apiLevel: apiLevel,
          manufacturer: manufacturer,
          connectionType: connectionType,
        ));
      }
    } catch (_) {}
    return devList;
  }

  Future<String?> avdName(String adbPath, String serial) async {
    final result = await Process.run(
      adbPath,
      <String>['-s', serial, 'emu', 'avd', 'name'],
      runInShell: false,
    ).timeout(const Duration(seconds: 8));
    if (result.exitCode != 0) {
      return null;
    }
    return result.stdout.toString().split(RegExp(r'\r?\n')).first.trim();
  }

  /// Checks if Android has completely booted using `sys.boot_completed`.
  Future<bool> isBootCompleted(String adbPath, String serial) async {
    try {
      final result = await Process.run(
        adbPath,
        <String>['-s', serial, 'shell', 'getprop', 'sys.boot_completed'],
        runInShell: false,
      ).timeout(const Duration(seconds: 5));

      return result.exitCode == 0 && result.stdout.toString().trim() == '1';
    } catch (_) {
      return false;
    }
  }

  /// Finds the serial (e.g. "emulator-5554") for a given AVD name.
  Future<String?> findSerialForAvd(String adbPath, String targetAvdName) async {
    try {
      final devLines = await devices(adbPath);
      for (final line in devLines) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.isEmpty || !parts.first.startsWith('emulator-')) {
          continue;
        }
        final serial = parts.first;
        final name = await avdName(adbPath, serial);
        if (name == targetAvdName) {
          return serial;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Gets the set of even ports currently occupied by running emulators.
  Future<Set<int>> getOccupiedPorts(String adbPath) async {
    final occupied = <int>{};
    try {
      final devLines = await devices(adbPath);
      for (final line in devLines) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.isEmpty) continue;
        final serial = parts.first;
        if (serial.startsWith('emulator-')) {
          final port = int.tryParse(serial.substring('emulator-'.length));
          if (port != null) {
            occupied.add(port);
          }
        }
      }
    } catch (_) {}
    return occupied;
  }

  /// Finds the next available even port for an emulator (5554, 5556, 5558...).
  Future<int> getNextAvailablePort(String adbPath, {int startPort = 5554}) async {
    final occupied = await getOccupiedPorts(adbPath);
    var candidate = startPort;
    if (candidate % 2 != 0) candidate++;

    while (occupied.contains(candidate)) {
      candidate += 2;
    }
    return candidate;
  }

  /// Stops an emulator by device serial using `emu kill`.
  Future<void> kill(String adbPath, String serial) async {
    await Process.run(
      adbPath,
      <String>['-s', serial, 'emu', 'kill'],
      runInShell: false,
    ).timeout(const Duration(seconds: 8));
  }

  /// Stops an emulator by its AVD name.
  Future<bool> killByAvdName(String adbPath, String avdName) async {
    final serial = await findSerialForAvd(adbPath, avdName);
    if (serial != null) {
      await kill(adbPath, serial);
      return true;
    }
    return false;
  }
}
