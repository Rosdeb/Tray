import 'dart:async';
import 'dart:io';

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
