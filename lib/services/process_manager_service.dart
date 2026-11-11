import 'dart:convert';
import 'dart:io';

import '../models/system_process.dart';

class ProcessManagerService {
  /// Fetches running processes related to Android development, emulators,
  /// ADB, Java/Gradle, and Scrcpy.
  Future<List<SystemProcessItem>> getAndroidRelatedProcesses() async {
    try {
      if (Platform.isWindows) {
        return await _getWindowsProcesses();
      } else {
        return await _getUnixProcesses();
      }
    } catch (_) {
      return <SystemProcessItem>[];
    }
  }

  /// Categorizes a process based on its executable name and command line.
  static ProcessCategory categorizeProcess(String name, String commandLine) {
    final lowerName = name.toLowerCase();
    final lowerCmd = commandLine.toLowerCase();
    final lower = '$lowerName $lowerCmd';

    // Prioritize exact command executable checks first
    if (lowerName.contains('scrcpy') || lowerCmd.startsWith('scrcpy')) {
      return ProcessCategory.scrcpy;
    }
    if (lowerName.contains('adb') || lowerCmd.startsWith('adb')) {
      return ProcessCategory.adb;
    }
    if (lowerName.contains('qemu') || lowerName.contains('emulator') || lowerCmd.contains('qemu')) {
      return ProcessCategory.emulator;
    }
    if (lower.contains('gradle') || lower.contains('java') || lower.contains('javaw')) {
      return ProcessCategory.javaGradle;
    }
    if (lower.contains('scrcpy')) {
      return ProcessCategory.scrcpy;
    }
    return ProcessCategory.other;
  }

  /// Whether a process name/command matches Android/Emulator tooling.
  static bool isRelevantProcess(String name, String commandLine) {
    final lower = '$name $commandLine'.toLowerCase();
    final currentPidStr = pid.toString();
    if (lower.contains('tray') && lower.contains(currentPidStr)) {
      return false; // Don't list Tray itself
    }
    return lower.contains('emulator') ||
        lower.contains('qemu') ||
        lower.contains('adb') ||
        lower.contains('scrcpy') ||
        lower.contains('gradle') ||
        lower.contains('avdmanager') ||
        lower.contains('sdkmanager') ||
        (lower.contains('java') && (lower.contains('android') || lower.contains('gradle') || lower.contains('sdk')));
  }

  Future<List<SystemProcessItem>> _getUnixProcesses() async {
    final result = await Process.run(
      'ps',
      const ['-eo', 'pid,%cpu,rss,command'],
      runInShell: false,
    );

    if (result.exitCode != 0) return <SystemProcessItem>[];

    final lines = result.stdout.toString().split('\n');
    final items = <SystemProcessItem>[];
    final regex = RegExp(r'^\s*(\d+)\s+([\d.]+)\s+(\d+)\s+(.+)$');
    final currentPid = pid;

    for (final line in lines) {
      final match = regex.firstMatch(line);
      if (match == null) continue;

      final pId = int.tryParse(match.group(1)!) ?? -1;
      if (pId <= 0 || pId == currentPid) continue;

      final cpu = double.tryParse(match.group(2)!) ?? 0.0;
      final rssKb = int.tryParse(match.group(3)!) ?? 0;
      final command = match.group(4)!.trim();

      // Extract short name from command
      final firstToken = command.split(' ').first;
      final shortName = firstToken.contains('/') ? firstToken.split('/').last : firstToken;

      if (!isRelevantProcess(shortName, command)) continue;

      final category = categorizeProcess(shortName, command);
      items.add(
        SystemProcessItem(
          pid: pId,
          name: shortName,
          category: category,
          cpuPercent: cpu,
          memoryBytes: rssKb * 1024,
          commandLine: command,
        ),
      );
    }

    return items;
  }

  Future<List<SystemProcessItem>> _getWindowsProcesses() async {
    final items = <SystemProcessItem>[];
    final currentPid = pid;

    // Use PowerShell to get processes matching relevant keywords with CPU & WorkingSet
    const psScript = r'''
$keywords = 'qemu','emulator','adb','java','javaw','gradle','scrcpy'
Get-Process | Where-Object {
    $procName = $_.ProcessName
    $keywords | Where-Object { $procName -match $_ }
} | Select-Object Id, ProcessName, CPU, WorkingSet64 | ConvertTo-Json -Compress
''';

    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', psScript],
      );

      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final raw = result.stdout.toString().trim();
        dynamic decoded;
        try {
          decoded = jsonDecode(raw);
        } catch (_) {
          decoded = null;
        }

        final list = decoded is List ? decoded : (decoded != null ? [decoded] : []);
        for (final item in list) {
          if (item is! Map) continue;
          final pId = (item['Id'] as num?)?.toInt() ?? -1;
          if (pId <= 0 || pId == currentPid) continue;

          final name = (item['ProcessName'] ?? '').toString();
          final cpu = (item['CPU'] as num?)?.toDouble() ?? 0.0;
          final mem = (item['WorkingSet64'] as num?)?.toInt() ?? 0;

          final category = categorizeProcess(name, '');
          items.add(
            SystemProcessItem(
              pid: pId,
              name: name.endsWith('.exe') ? name : '$name.exe',
              category: category,
              cpuPercent: cpu,
              memoryBytes: mem,
              commandLine: name,
            ),
          );
        }
      }
    } catch (_) {
      // Fallback: tasklist CSV
      try {
        final taskResult = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
        if (taskResult.exitCode == 0) {
          final lines = taskResult.stdout.toString().split('\r\n');
          for (final line in lines) {
            final parts = line.split('","').map((s) => s.replaceAll('"', '').trim()).toList();
            if (parts.length < 5) continue;
            final name = parts[0];
            final pId = int.tryParse(parts[1]) ?? -1;
            if (pId <= 0 || pId == currentPid) continue;
            if (!isRelevantProcess(name, '')) continue;

            final memStr = parts[4].replaceAll(RegExp(r'[^0-9]'), '');
            final memKb = int.tryParse(memStr) ?? 0;

            items.add(
              SystemProcessItem(
                pid: pId,
                name: name,
                category: categorizeProcess(name, ''),
                cpuPercent: 0.0,
                memoryBytes: memKb * 1024,
                commandLine: name,
              ),
            );
          }
        }
      } catch (_) {}
    }

    return items;
  }

  /// Terminates a single process by its PID.
  Future<bool> killProcess(int pid) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('taskkill', ['/F', '/T', '/PID', pid.toString()]);
        return result.exitCode == 0;
      } else {
        final killed = Process.killPid(pid, ProcessSignal.sigkill);
        if (killed) return true;
        final res = await Process.run('kill', ['-9', pid.toString()]);
        return res.exitCode == 0;
      }
    } catch (_) {
      return false;
    }
  }

  /// Terminates multiple processes. Returns the number of processes successfully killed.
  Future<int> killProcesses(List<int> pids) async {
    var count = 0;
    for (final pId in pids) {
      final success = await killProcess(pId);
      if (success) count++;
    }
    return count;
  }

  /// Terminates all processes belonging to a specific category.
  Future<int> killGroup(ProcessCategory category, List<SystemProcessItem> allProcesses) async {
    final targetPids = allProcesses
        .where((p) => p.category == category)
        .map((p) => p.pid)
        .toList(growable: false);

    return killProcesses(targetPids);
  }
}
