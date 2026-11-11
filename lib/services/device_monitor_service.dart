import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

import '../models/device_metrics.dart';
import 'adb_service.dart';

class MonitorTargetInfo {
  const MonitorTargetInfo({
    required this.id,
    required this.displayName,
    required this.isEmulator,
  });

  final String id;
  final String displayName;
  final bool isEmulator;
}

// ==========================================
// macOS Mach Kernel FFI Definitions
// ==========================================
final class _HostCpuLoadInfo extends Struct {
  @Array(4)
  external Array<Uint32> cpuTicks;
}

final class _VmStatistics64 extends Struct {
  @Uint32()
  external int freeCount;
  @Uint32()
  external int activeCount;
  @Uint32()
  external int inactiveCount;
  @Uint32()
  external int wireCount;
  @Uint64()
  external int zeroFillCount;
  @Uint64()
  external int reactivations;
  @Uint64()
  external int pageins;
  @Uint64()
  external int pageouts;
  @Uint64()
  external int faults;
  @Uint64()
  external int cowFaults;
  @Uint64()
  external int lookups;
  @Uint64()
  external int hits;
  @Uint64()
  external int purges;
  @Uint32()
  external int purgeableCount;
  @Uint32()
  external int speculativeCount;
  @Uint64()
  external int decompressions;
  @Uint64()
  external int compressions;
  @Uint64()
  external int swapins;
  @Uint64()
  external int swapouts;
  @Uint32()
  external int compressorPageCount;
  @Uint32()
  external int throttledCount;
  @Uint32()
  external int externalPageCount;
  @Uint32()
  external int internalPageCount;
  @Uint64()
  external int totalUncompressedPagesInCompressor;
}

final class _SockAddr extends Struct {
  @Uint8()
  external int saLen;
  @Uint8()
  external int saFamily;
}

final class _IfData extends Struct {
  @Uint8()
  external int ifiType;
  @Uint8()
  external int ifiTypelen;
  @Uint8()
  external int ifiPhysical;
  @Uint8()
  external int ifiAddrlen;
  @Uint8()
  external int ifiHdrlen;
  @Uint8()
  external int ifiRecvquota;
  @Uint8()
  external int ifiXmitquota;
  @Uint8()
  external int ifiUnused1;
  @Uint32()
  external int ifiMtu;
  @Uint32()
  external int ifiMetric;
  @Uint32()
  external int ifiBaudrate;
  @Uint32()
  external int ifiIpackets;
  @Uint32()
  external int ifiIerrors;
  @Uint32()
  external int ifiOpackets;
  @Uint32()
  external int ifiOerrors;
  @Uint32()
  external int ifiCollisions;
  @Uint32()
  external int ifiIbytes;
  @Uint32()
  external int ifiObytes;
}

final class _IfAddrs extends Struct {
  external Pointer<_IfAddrs> ifaNext;
  external Pointer<Utf8> ifaName;
  @Uint32()
  external int ifaFlags;
  external Pointer<_SockAddr> ifaAddr;
  external Pointer<_SockAddr> ifaNetmask;
  external Pointer<_SockAddr> ifaDstaddr;
  external Pointer<Uint8> ifaData;
}

class DeviceMonitorService {
  DeviceMonitorService(this._adbService);

  final AdbService _adbService;

  // Cached hardware total memory
  int _cachedHostTotalRam = 0;

  // macOS CPU ticks state
  int _prevMacUserTicks = -1;
  int _prevMacSysTicks = -1;
  int _prevMacIdleTicks = -1;
  int _prevMacNiceTicks = -1;

  // Windows CPU ticks state
  int _prevWinIdleTime = -1;
  int _prevWinKernelTime = -1;
  int _prevWinUserTime = -1;

  // Linux CPU ticks state
  int _prevLinuxBusyTicks = -1;
  int _prevLinuxTotalTicks = -1;

  // Track network byte deltas for Host
  int _prevHostRxBytes = -1;
  int _prevHostTxBytes = -1;
  DateTime? _prevHostNetworkTime;

  // Track CPU ticks deltas for Device
  int _prevDevUserTicks = -1;
  int _prevDevNiceTicks = -1;
  int _prevDevSysTicks = -1;
  int _prevDevIdleTicks = -1;
  int _prevDevIoWaitTicks = -1;

  // Track network byte deltas for Device
  int _prevDeviceRxBytes = -1;
  int _prevDeviceTxBytes = -1;
  DateTime? _prevDeviceNetworkTime;

  /// Resets deltas when switching targets
  void resetDeltas() {
    _prevHostRxBytes = -1;
    _prevHostTxBytes = -1;
    _prevHostNetworkTime = null;

    _prevDevUserTicks = -1;
    _prevDevNiceTicks = -1;
    _prevDevSysTicks = -1;
    _prevDevIdleTicks = -1;
    _prevDevIoWaitTicks = -1;

    _prevDeviceRxBytes = -1;
    _prevDeviceTxBytes = -1;
    _prevDeviceNetworkTime = null;
  }

  /// Fetches available monitoring targets: Host Machine + all running ADB devices.
  Future<List<MonitorTargetInfo>> getAvailableTargets(String? adbPath) async {
    final list = <MonitorTargetInfo>[
      const MonitorTargetInfo(
        id: 'host',
        displayName: 'Host System (PC / Mac)',
        isEmulator: false,
      ),
    ];

    if (adbPath != null && adbPath.trim().isNotEmpty && File(adbPath).existsSync()) {
      try {
        final rawDevices = await _adbService.devices(adbPath);
        for (final line in rawDevices) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 2 && parts[1] == 'device') {
            final serial = parts[0];
            String name = serial;
            try {
              final avd = await _adbService.avdName(adbPath, serial);
              if (avd != null && avd.isNotEmpty && !avd.startsWith('OK')) {
                name = '$avd ($serial)';
              }
            } catch (_) {}
            list.add(
              MonitorTargetInfo(
                id: serial,
                displayName: name,
                isEmulator: true,
              ),
            );
          }
        }
      } catch (_) {}
    }

    return list;
  }

  /// Polls real-time metrics for either the host or a connected Android device.
  Future<DeviceRealtimeMetrics> pollMetrics({
    required String targetId,
    required String targetName,
    String? adbPath,
  }) async {
    final now = DateTime.now();

    if (targetId == 'host' || adbPath == null || adbPath.isEmpty) {
      return _pollHostMetrics(targetName: targetName, now: now);
    } else {
      return _pollDeviceMetrics(
        serial: targetId,
        targetName: targetName,
        adbPath: adbPath,
        now: now,
      );
    }
  }

  // ==========================================
  // HOST REAL-TIME METRICS (Mac, Windows, Linux)
  // ==========================================
  Future<DeviceRealtimeMetrics> _pollHostMetrics({
    required String targetName,
    required DateTime now,
  }) async {
    double cpu = 0.0;
    int totalRam = _cachedHostTotalRam > 0 ? _cachedHostTotalRam : 16 * 1024 * 1024 * 1024;
    int usedRam = (totalRam * 0.5).toInt();
    double rxSpeed = 0.0;
    double txSpeed = 0.0;
    int batteryLevel = 100;
    double batteryTemp = 28.0;
    String batteryStatus = 'AC Power';
    var topProcesses = <TopProcessItem>[];

    if (Platform.isMacOS) {
      // 1. Host CPU on macOS via Mach Kernel host_statistics64 (Instantaneous & Real-Time)
      try {
        cpu = _getMacCpuInstantaneous();
      } catch (_) {
        // Fallback to top or ps
        try {
          final res = await Process.run('ps', ['-A', '-o', '%cpu']);
          final lines = res.stdout.toString().trim().split('\n');
          double sum = 0.0;
          for (final line in lines.skip(1)) {
            sum += double.tryParse(line.trim()) ?? 0.0;
          }
          final cores = Platform.numberOfProcessors > 0 ? Platform.numberOfProcessors : 8;
          cpu = (sum / cores).clamp(0.0, 100.0);
        } catch (_) {}
      }

      // 2. Host RAM on macOS via Mach VM Statistics & sysctl
      try {
        final (tRam, uRam) = await _getMacRamInstantaneous();
        totalRam = tRam;
        usedRam = uRam;
        _cachedHostTotalRam = tRam;
      } catch (_) {}

      // 3. Host Network Bandwidth on macOS via getifaddrs
      try {
        final (rx, tx) = _getMacNetworkInstantaneous(now);
        rxSpeed = rx;
        txSpeed = tx;
      } catch (_) {}

      // 4. Host Top Active Processes on macOS (lightweight ps)
      try {
        final psRes = await Process.run('ps', ['-eo', 'pid,%cpu,rss,comm', '-r']);
        final lines = psRes.stdout.toString().trim().split('\n');
        final items = <TopProcessItem>[];
        for (final line in lines.skip(1).take(5)) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final pid = int.tryParse(parts[0]) ?? 0;
            final procCpu = double.tryParse(parts[1]) ?? 0.0;
            final rssKb = int.tryParse(parts[2]) ?? 0;
            final rawCmd = parts.sublist(3).join(' ');
            final name = rawCmd.contains('/') ? rawCmd.split('/').last : rawCmd;

            items.add(
              TopProcessItem(
                pid: pid,
                name: name,
                cpuPercent: procCpu,
                memoryMb: rssKb / 1024.0,
                user: 'host',
              ),
            );
          }
        }
        topProcesses = items;
      } catch (_) {}

      // 5. Host Battery on macOS
      try {
        final battRes = await Process.run('pmset', ['-g', 'batt']);
        final out = battRes.stdout.toString();
        final match = RegExp(r'(\d+)%').firstMatch(out);
        if (match != null) {
          batteryLevel = int.tryParse(match.group(1)!) ?? 100;
        }
        if (out.toLowerCase().contains('charging')) {
          batteryStatus = 'Charging';
        } else if (out.toLowerCase().contains('discharging')) {
          batteryStatus = 'Discharging';
        } else {
          batteryStatus = 'AC Power';
        }
      } catch (_) {}
    } else if (Platform.isWindows) {
      // 1. Host CPU on Windows via Win32 GetSystemTimes (Instantaneous)
      try {
        cpu = _getWindowsCpuInstantaneous();
      } catch (_) {}

      // 2. Host RAM on Windows via Win32 GlobalMemoryStatusEx (Instantaneous)
      try {
        final (tRam, uRam) = _getWindowsRamInstantaneous();
        totalRam = tRam;
        usedRam = uRam;
        _cachedHostTotalRam = tRam;
      } catch (_) {}

      // 3. Host Battery on Windows via Win32 GetSystemPowerStatus (Instantaneous)
      try {
        final (bLvl, bStatus) = _getWindowsBatteryInstantaneous();
        batteryLevel = bLvl;
        batteryStatus = bStatus;
      } catch (_) {}

      // 4. Host Network on Windows (via netstat.exe -e)
      try {
        final netRes = await Process.run('netstat.exe', ['-e']);
        final out = netRes.stdout.toString();
        final bytesMatch = RegExp(r'Bytes\s+(\d+)\s+(\d+)').firstMatch(out);
        if (bytesMatch != null) {
          final curRx = int.tryParse(bytesMatch.group(1)!) ?? 0;
          final curTx = int.tryParse(bytesMatch.group(2)!) ?? 0;

          if (_prevHostRxBytes >= 0 && _prevHostTxBytes >= 0 && _prevHostNetworkTime != null) {
            final elapsedSec = now.difference(_prevHostNetworkTime!).inMilliseconds / 1000.0;
            if (elapsedSec > 0.2) {
              rxSpeed = ((curRx - _prevHostRxBytes) / 1024.0) / elapsedSec;
              txSpeed = ((curTx - _prevHostTxBytes) / 1024.0) / elapsedSec;
              if (rxSpeed < 0) rxSpeed = 0.0;
              if (txSpeed < 0) txSpeed = 0.0;
            }
          }
          _prevHostRxBytes = curRx;
          _prevHostTxBytes = curTx;
          _prevHostNetworkTime = now;
        }
      } catch (_) {}

      // 5. Host Top Processes on Windows (Fast tasklist fallback)
      try {
        final res = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
        if (res.exitCode == 0) {
          final lines = res.stdout.toString().trim().split('\r\n');
          final parsed = <TopProcessItem>[];
          for (final line in lines) {
            final parts = line.split('","').map((s) => s.replaceAll('"', '').trim()).toList();
            if (parts.length >= 5) {
              final name = parts[0];
              final pid = int.tryParse(parts[1]) ?? 0;
              final memClean = parts[4].replaceAll(RegExp(r'[^\d]'), '');
              final memKb = int.tryParse(memClean) ?? 0;
              parsed.add(
                TopProcessItem(
                  pid: pid,
                  name: name,
                  cpuPercent: 0.0,
                  memoryMb: memKb / 1024.0,
                  user: 'windows',
                ),
              );
            }
          }
          parsed.sort((a, b) => b.memoryMb.compareTo(a.memoryMb));
          topProcesses = parsed.take(5).toList();
        }
      } catch (_) {}
    } else if (Platform.isLinux) {
      // 1. Host CPU on Linux via /proc/stat
      try {
        final statFile = File('/proc/stat');
        if (await statFile.exists()) {
          final firstLine = (await statFile.readAsLines()).firstOrNull ?? '';
          final parts = firstLine.trim().split(RegExp(r'\s+'));
          if (parts.length >= 5 && parts[0] == 'cpu') {
            final user = int.tryParse(parts[1]) ?? 0;
            final nice = int.tryParse(parts[2]) ?? 0;
            final sys = int.tryParse(parts[3]) ?? 0;
            final idle = int.tryParse(parts[4]) ?? 0;
            final iowait = parts.length > 5 ? (int.tryParse(parts[5]) ?? 0) : 0;

            final busy = user + nice + sys;
            final total = busy + idle + iowait;

            if (_prevLinuxBusyTicks >= 0 && _prevLinuxTotalTicks >= 0) {
              final dBusy = busy - _prevLinuxBusyTicks;
              final dTotal = total - _prevLinuxTotalTicks;
              if (dTotal > 0) {
                cpu = ((dBusy / dTotal) * 100.0).clamp(0.0, 100.0);
              }
            }
            _prevLinuxBusyTicks = busy;
            _prevLinuxTotalTicks = total;
          }
        }
      } catch (_) {}

      // 2. RAM on Linux via /proc/meminfo
      try {
        final memFile = File('/proc/meminfo');
        if (await memFile.exists()) {
          final lines = await memFile.readAsLines();
          int tKb = 0;
          int aKb = 0;
          for (final line in lines) {
            if (line.startsWith('MemTotal:')) {
              tKb = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '') ?? 0;
            } else if (line.startsWith('MemAvailable:')) {
              aKb = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '') ?? 0;
            }
          }
          if (tKb > 0) {
            totalRam = tKb * 1024;
            usedRam = (tKb - aKb) * 1024;
          }
        }
      } catch (_) {}

      // 3. Network via /proc/net/dev
      try {
        final netFile = File('/proc/net/dev');
        if (await netFile.exists()) {
          final lines = await netFile.readAsLines();
          int curRx = 0;
          int curTx = 0;
          for (final line in lines) {
            if (line.contains(':') && !line.contains('lo:')) {
              final parts = line.split(':')[1].trim().split(RegExp(r'\s+'));
              if (parts.length >= 9) {
                curRx += int.tryParse(parts[0]) ?? 0;
                curTx += int.tryParse(parts[8]) ?? 0;
              }
            }
          }
          if (_prevHostRxBytes >= 0 && _prevHostTxBytes >= 0 && _prevHostNetworkTime != null) {
            final elapsedSec = now.difference(_prevHostNetworkTime!).inMilliseconds / 1000.0;
            if (elapsedSec > 0.2) {
              rxSpeed = ((curRx - _prevHostRxBytes) / 1024.0) / elapsedSec;
              txSpeed = ((curTx - _prevHostTxBytes) / 1024.0) / elapsedSec;
            }
          }
          _prevHostRxBytes = curRx;
          _prevHostTxBytes = curTx;
          _prevHostNetworkTime = now;
        }
      } catch (_) {}
    }

    return DeviceRealtimeMetrics(
      targetName: targetName,
      isEmulatorOrDevice: false,
      cpuPercent: cpu,
      totalRamBytes: totalRam,
      usedRamBytes: usedRam,
      networkRxSpeedKbps: rxSpeed,
      networkTxSpeedKbps: txSpeed,
      batteryLevel: batteryLevel,
      batteryTempC: batteryTemp,
      batteryStatus: batteryStatus,
      fps: 60.0,
      topProcesses: topProcesses,
      timestamp: now,
    );
  }

  // ==========================================
  // DEVICE / EMULATOR REAL-TIME METRICS (via ADB)
  // ==========================================
  Future<DeviceRealtimeMetrics> _pollDeviceMetrics({
    required String serial,
    required String targetName,
    required String adbPath,
    required DateTime now,
  }) async {
    double cpu = 0.0;
    int totalRam = 4 * 1024 * 1024 * 1024;
    int usedRam = 2 * 1024 * 1024 * 1024;
    double rxSpeed = 0.0;
    double txSpeed = 0.0;
    int batteryLevel = 100;
    double batteryTemp = 28.0;
    String batteryStatus = 'Charging';
    var topProcesses = <TopProcessItem>[];

    // Combine CPU ticks, Meminfo, and Netstat in 1 ultra-fast ADB command (~30ms)
    // Run battery and top processes concurrently with 2s timeout
    final results = await Future.wait([
      // 0: Combined core proc telemetry (/proc/stat, /proc/meminfo, /proc/net/dev)
      Process.run(adbPath, [
        '-s',
        serial,
        'shell',
        'cat /proc/stat; echo "==M=="; cat /proc/meminfo; echo "==N=="; cat /proc/net/dev',
      ]).timeout(const Duration(seconds: 2), onTimeout: () => ProcessResult(0, -1, '', 'timeout')),

      // 1: Top processes
      Process.run(adbPath, ['-s', serial, 'shell', 'top', '-b', '-n', '1', '-m', '6'])
          .timeout(const Duration(seconds: 2), onTimeout: () => ProcessResult(0, -1, '', 'timeout')),

      // 2: Battery status
      Process.run(adbPath, ['-s', serial, 'shell', 'dumpsys', 'battery'])
          .timeout(const Duration(seconds: 2), onTimeout: () => ProcessResult(0, -1, '', 'timeout')),
    ]);

    // Parse Combined Telemetry
    try {
      final combinedOut = results[0].stdout.toString();
      final sections = combinedOut.split(RegExp(r'==[MN]==\n?'));

      if (sections.isNotEmpty) {
        // Section 0: /proc/stat CPU Ticks
        final statLines = sections[0].split('\n');
        for (final line in statLines) {
          final match = RegExp(r'^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)').firstMatch(line);
          if (match != null) {
            final user = int.tryParse(match.group(1)!) ?? 0;
            final nice = int.tryParse(match.group(2)!) ?? 0;
            final sys = int.tryParse(match.group(3)!) ?? 0;
            final idle = int.tryParse(match.group(4)!) ?? 0;
            final iowait = int.tryParse(match.group(5)!) ?? 0;

            if (_prevDevUserTicks >= 0) {
              final dUser = user - _prevDevUserTicks;
              final dNice = nice - _prevDevNiceTicks;
              final dSys = sys - _prevDevSysTicks;
              final dIdle = idle - _prevDevIdleTicks;
              final dIoWait = iowait - _prevDevIoWaitTicks;

              final dBusy = dUser + dNice + dSys;
              final dTotal = dBusy + dIdle + dIoWait;
              if (dTotal > 0) {
                cpu = ((dBusy / dTotal) * 100.0).clamp(0.0, 100.0);
              }
            }
            _prevDevUserTicks = user;
            _prevDevNiceTicks = nice;
            _prevDevSysTicks = sys;
            _prevDevIdleTicks = idle;
            _prevDevIoWaitTicks = iowait;
            break;
          }
        }
      }

      if (sections.length >= 2) {
        // Section 1: /proc/meminfo RAM
        final memLines = sections[1].split('\n');
        int tKb = 0;
        int aKb = 0;
        int fKb = 0;
        int bKb = 0;
        int cKb = 0;

        for (final line in memLines) {
          if (line.startsWith('MemTotal:')) {
            tKb = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '') ?? 0;
          } else if (line.startsWith('MemAvailable:')) {
            aKb = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '') ?? 0;
          } else if (line.startsWith('MemFree:')) {
            fKb = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '') ?? 0;
          } else if (line.startsWith('Buffers:')) {
            bKb = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '') ?? 0;
          } else if (line.startsWith('Cached:')) {
            cKb = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '') ?? 0;
          }
        }

        if (tKb > 0) {
          totalRam = tKb * 1024;
          final effectiveAvailKb = aKb > 0 ? aKb : (fKb + bKb + cKb);
          usedRam = ((tKb - effectiveAvailKb) * 1024).clamp(0, totalRam);
        }
      }

      if (sections.length >= 3) {
        // Section 2: /proc/net/dev Network I/O
        final netLines = sections[2].split('\n');
        int curRx = 0;
        int curTx = 0;
        for (final line in netLines) {
          if (line.contains(':') && !line.contains('lo:')) {
            final parts = line.split(':')[1].trim().split(RegExp(r'\s+'));
            if (parts.length >= 9) {
              curRx += int.tryParse(parts[0]) ?? 0;
              curTx += int.tryParse(parts[8]) ?? 0;
            }
          }
        }

        if (_prevDeviceRxBytes >= 0 && _prevDeviceTxBytes >= 0 && _prevDeviceNetworkTime != null) {
          final elapsedSec = now.difference(_prevDeviceNetworkTime!).inMilliseconds / 1000.0;
          if (elapsedSec > 0.1) {
            rxSpeed = ((curRx - _prevDeviceRxBytes) / 1024.0) / elapsedSec;
            txSpeed = ((curTx - _prevDeviceTxBytes) / 1024.0) / elapsedSec;
            if (rxSpeed < 0) rxSpeed = 0.0;
            if (txSpeed < 0) txSpeed = 0.0;
          }
        }
        _prevDeviceRxBytes = curRx;
        _prevDeviceTxBytes = curTx;
        _prevDeviceNetworkTime = now;
      }
    } catch (_) {}

    // Parse Top Processes
    try {
      final lines = results[1].stdout.toString().split('\n');
      final items = <TopProcessItem>[];
      for (final line in lines) {
        final procMatch = RegExp(
          r'^\s*(\d+)\s+(\S+)\s+\S+\s+\S+\s+\S+\s+(\S+)\s+\S+\s+\S+\s+([\d.]+)\s+[\d.]+\s+\S+\s+(\S+)',
        ).firstMatch(line);
        if (procMatch != null) {
          final pid = int.tryParse(procMatch.group(1)!) ?? 0;
          final user = procMatch.group(2)!;
          final resStr = procMatch.group(3)!;
          final procCpu = double.tryParse(procMatch.group(4)!) ?? 0.0;
          final name = procMatch.group(5)!;

          double resMb = 0.0;
          if (resStr.endsWith('M') || resStr.endsWith('m')) {
            resMb = double.tryParse(resStr.substring(0, resStr.length - 1)) ?? 0.0;
          } else if (resStr.endsWith('K') || resStr.endsWith('k')) {
            resMb = (double.tryParse(resStr.substring(0, resStr.length - 1)) ?? 0.0) / 1024;
          }

          if (name != 'top') {
            items.add(
              TopProcessItem(
                pid: pid,
                name: name,
                cpuPercent: procCpu,
                memoryMb: resMb,
                user: user,
              ),
            );
          }
        }
      }
      topProcesses = items;
    } catch (_) {}

    // Parse Battery
    try {
      final out = results[2].stdout.toString();
      final lvl = RegExp(r'level:\s*(\d+)').firstMatch(out);
      if (lvl != null) {
        batteryLevel = int.tryParse(lvl.group(1)!) ?? 100;
      }
      final temp = RegExp(r'temperature:\s*(\d+)').firstMatch(out);
      if (temp != null) {
        batteryTemp = (int.tryParse(temp.group(1)!) ?? 250) / 10.0;
      }
      final statusMatch = RegExp(r'status:\s*(\d+)').firstMatch(out);
      if (statusMatch != null) {
        batteryStatus = statusMatch.group(1) == '2' ? 'Charging' : 'Discharging';
      }
    } catch (_) {}

    return DeviceRealtimeMetrics(
      targetName: targetName,
      isEmulatorOrDevice: true,
      deviceSerial: serial,
      cpuPercent: cpu,
      totalRamBytes: totalRam,
      usedRamBytes: usedRam,
      networkRxSpeedKbps: rxSpeed,
      networkTxSpeedKbps: txSpeed,
      batteryLevel: batteryLevel,
      batteryTempC: batteryTemp,
      batteryStatus: batteryStatus,
      fps: 60.0,
      topProcesses: topProcesses,
      timestamp: now,
    );
  }

  // ==========================================
  // macOS NATIVE FFI METHODS
  // ==========================================
  double _getMacCpuInstantaneous() {
    final dylib = DynamicLibrary.process();
    final machHostSelf = dylib.lookupFunction<IntPtr Function(), int Function()>('mach_host_self');
    final hostStats = dylib.lookupFunction<
        Int32 Function(IntPtr, Int32, Pointer<Uint32>, Pointer<Uint32>),
        int Function(int, int, Pointer<Uint32>, Pointer<Uint32>)>('host_statistics64');

    final host = machHostSelf();
    final pCount = calloc<Uint32>();
    pCount.value = 4;
    final pInfo = calloc<_HostCpuLoadInfo>();

    try {
      final ret = hostStats(host, 3, pInfo.cast<Uint32>(), pCount); // 3 = HOST_CPU_LOAD_INFO
      if (ret != 0) return 0.0;

      final user = pInfo.ref.cpuTicks[0];
      final sys = pInfo.ref.cpuTicks[1];
      final idle = pInfo.ref.cpuTicks[2];
      final nice = pInfo.ref.cpuTicks[3];

      double cpu = 0.0;
      if (_prevMacUserTicks >= 0) {
        final dUser = user - _prevMacUserTicks;
        final dSys = sys - _prevMacSysTicks;
        final dIdle = idle - _prevMacIdleTicks;
        final dNice = nice - _prevMacNiceTicks;
        final total = dUser + dSys + dIdle + dNice;
        if (total > 0) {
          cpu = (((dUser + dSys + dNice) / total) * 100.0).clamp(0.0, 100.0);
        }
      }

      _prevMacUserTicks = user;
      _prevMacSysTicks = sys;
      _prevMacIdleTicks = idle;
      _prevMacNiceTicks = nice;

      return cpu;
    } finally {
      calloc.free(pCount);
      calloc.free(pInfo);
    }
  }

  Future<(int, int)> _getMacRamInstantaneous() async {
    int totalRam = _cachedHostTotalRam;
    if (totalRam <= 0) {
      final sysctlRes = await Process.run('sysctl', ['-n', 'hw.memsize']);
      totalRam = int.tryParse(sysctlRes.stdout.toString().trim()) ?? (16 * 1024 * 1024 * 1024);
    }

    final dylib = DynamicLibrary.process();
    final machHostSelf = dylib.lookupFunction<IntPtr Function(), int Function()>('mach_host_self');
    final hostStats = dylib.lookupFunction<
        Int32 Function(IntPtr, Int32, Pointer<Uint32>, Pointer<Uint32>),
        int Function(int, int, Pointer<Uint32>, Pointer<Uint32>)>('host_statistics64');

    final host = machHostSelf();
    final pCount = calloc<Uint32>();
    pCount.value = 38; // HOST_VM_INFO64_COUNT
    final pInfo = calloc<_VmStatistics64>();

    try {
      final ret = hostStats(host, 4, pInfo.cast<Uint32>(), pCount); // 4 = HOST_VM_INFO64
      if (ret != 0) return (totalRam, (totalRam * 0.5).toInt());

      const pageSize = 16384; // standard Apple Silicon page size (or 4096 on Intel)
      final freePages = pInfo.ref.freeCount + pInfo.ref.speculativeCount;
      final freeBytes = freePages * pageSize;
      final usedRam = (totalRam - freeBytes).clamp(0, totalRam);
      return (totalRam, usedRam);
    } finally {
      calloc.free(pCount);
      calloc.free(pInfo);
    }
  }

  (double, double) _getMacNetworkInstantaneous(DateTime now) {
    final dylib = DynamicLibrary.process();
    final getifaddrs = dylib.lookupFunction<
        Int32 Function(Pointer<Pointer<_IfAddrs>>),
        int Function(Pointer<Pointer<_IfAddrs>>)>('getifaddrs');
    final freeifaddrs = dylib.lookupFunction<
        Void Function(Pointer<_IfAddrs>),
        void Function(Pointer<_IfAddrs>)>('freeifaddrs');

    final ppIfap = calloc<Pointer<_IfAddrs>>();
    try {
      final ret = getifaddrs(ppIfap);
      if (ret != 0) return (0.0, 0.0);

      var cur = ppIfap.value;
      int curRx = 0;
      int curTx = 0;

      while (cur != nullptr) {
        final name = cur.ref.ifaName != nullptr ? cur.ref.ifaName.toDartString() : '';
        // Family 18 is AF_LINK on macOS
        if (!name.startsWith('lo') && cur.ref.ifaAddr != nullptr && cur.ref.ifaAddr.ref.saFamily == 18) {
          if (cur.ref.ifaData != nullptr) {
            final data = cur.ref.ifaData.cast<_IfData>();
            curRx += data.ref.ifiIbytes;
            curTx += data.ref.ifiObytes;
          }
        }
        cur = cur.ref.ifaNext;
      }

      double rxSpeed = 0.0;
      double txSpeed = 0.0;

      if (_prevHostRxBytes >= 0 && _prevHostTxBytes >= 0 && _prevHostNetworkTime != null) {
        final elapsedSec = now.difference(_prevHostNetworkTime!).inMilliseconds / 1000.0;
        if (elapsedSec > 0.2) {
          rxSpeed = ((curRx - _prevHostRxBytes) / 1024.0) / elapsedSec;
          txSpeed = ((curTx - _prevHostTxBytes) / 1024.0) / elapsedSec;
          if (rxSpeed < 0) rxSpeed = 0.0;
          if (txSpeed < 0) txSpeed = 0.0;
        }
      }

      _prevHostRxBytes = curRx;
      _prevHostTxBytes = curTx;
      _prevHostNetworkTime = now;

      freeifaddrs(ppIfap.value);
      return (rxSpeed, txSpeed);
    } finally {
      calloc.free(ppIfap);
    }
  }

  // ==========================================
  // Windows NATIVE FFI METHODS
  // ==========================================
  double _getWindowsCpuInstantaneous() {
    final lpIdle = calloc<win32.FILETIME>();
    final lpKernel = calloc<win32.FILETIME>();
    final lpUser = calloc<win32.FILETIME>();

    try {
      if (win32.GetSystemTimes(lpIdle, lpKernel, lpUser) != 0) {
        final idle = (lpIdle.ref.dwHighDateTime << 32) | lpIdle.ref.dwLowDateTime;
        final kernel = (lpKernel.ref.dwHighDateTime << 32) | lpKernel.ref.dwLowDateTime;
        final user = (lpUser.ref.dwHighDateTime << 32) | lpUser.ref.dwLowDateTime;

        double cpu = 0.0;
        if (_prevWinKernelTime >= 0 && _prevWinUserTime >= 0) {
          final deltaKernel = kernel - _prevWinKernelTime;
          final deltaUser = user - _prevWinUserTime;
          final deltaIdle = idle - _prevWinIdleTime;
          final totalSys = deltaKernel + deltaUser;
          if (totalSys > 0) {
            cpu = (((totalSys - deltaIdle) / totalSys) * 100.0).clamp(0.0, 100.0);
          }
        }

        _prevWinIdleTime = idle;
        _prevWinKernelTime = kernel;
        _prevWinUserTime = user;
        return cpu;
      }
      return 0.0;
    } finally {
      calloc.free(lpIdle);
      calloc.free(lpKernel);
      calloc.free(lpUser);
    }
  }

  (int, int) _getWindowsRamInstantaneous() {
    final mem = calloc<win32.MEMORYSTATUSEX>();
    mem.ref.dwLength = sizeOf<win32.MEMORYSTATUSEX>();

    try {
      if (win32.GlobalMemoryStatusEx(mem) != 0) {
        final totalRam = mem.ref.ullTotalPhys;
        final freeRam = mem.ref.ullAvailPhys;
        final usedRam = (totalRam - freeRam).clamp(0, totalRam);
        return (totalRam, usedRam);
      }
      final fallbackTotal = _cachedHostTotalRam > 0 ? _cachedHostTotalRam : (16 * 1024 * 1024 * 1024);
      return (fallbackTotal, (fallbackTotal * 0.5).toInt());
    } finally {
      calloc.free(mem);
    }
  }

  (int, String) _getWindowsBatteryInstantaneous() {
    final power = calloc<win32.SYSTEM_POWER_STATUS>();
    try {
      if (win32.GetSystemPowerStatus(power) != 0) {
        int lvl = 100;
        final pct = power.ref.BatteryLifePercent;
        if (pct <= 100) lvl = pct;
        final ac = power.ref.ACLineStatus;
        final status = ac == 1 ? 'AC Connected' : (ac == 0 ? 'Discharging' : 'Battery');
        return (lvl, status);
      }
      return (100, 'AC Power');
    } finally {
      calloc.free(power);
    }
  }
}
