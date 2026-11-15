import 'dart:async';
import 'dart:io';

class AdbWirelessResult {
  const AdbWirelessResult({
    required this.success,
    this.ip,
    this.port = 5555,
    this.message,
  });

  final bool success;
  final String? ip;
  final int port;
  final String? message;
}

class AdbWirelessService {
  const AdbWirelessService();

  /// Queries the device's local Wi-Fi IP address on-demand without background polling.
  Future<String?> getDeviceWifiIp(String adbPath, String serial) async {
    try {
      // 1. Fast query via getprop (takes ~30ms)
      final propRes = await Process.run(
        adbPath,
        <String>['-s', serial, 'shell', 'getprop', 'dhcp.wlan0.ipaddress'],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));

      final propIp = propRes.stdout.toString().trim();
      if (isValidIpv4(propIp)) {
        return propIp;
      }

      // 2. Query via ip addr show wlan0
      final ipRes = await Process.run(
        adbPath,
        <String>['-s', serial, 'shell', 'ip', '-f', 'inet', 'addr', 'show', 'wlan0'],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));

      final match = RegExp(r'inet\s+(\d+\.\d+\.\d+\.\d+)').firstMatch(ipRes.stdout.toString());
      if (match != null && isValidIpv4(match.group(1)!)) {
        return match.group(1);
      }

      // 3. Fallback check for any active wlan or ap interface
      final allIpRes = await Process.run(
        adbPath,
        <String>['-s', serial, 'shell', 'ip', 'route'],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));

      final routeMatch = RegExp(r'src\s+(\d+\.\d+\.\d+\.\d+)').firstMatch(allIpRes.stdout.toString());
      if (routeMatch != null && isValidIpv4(routeMatch.group(1)!)) {
        return routeMatch.group(1);
      }
    } catch (_) {}
    return null;
  }

  /// Switches a USB-connected phone to TCP/IP mode and connects via Wi-Fi.
  Future<AdbWirelessResult> switchUsbToWifi(
    String adbPath,
    String serial, {
    int port = 5555,
  }) async {
    try {
      // 1. Find device Wi-Fi IP
      final ip = await getDeviceWifiIp(adbPath, serial);
      if (ip == null || ip.isEmpty) {
        return const AdbWirelessResult(
          success: false,
          message: 'Could not detect Wi-Fi IP on phone. Ensure phone is connected to Wi-Fi.',
        );
      }

      // 2. Switch phone ADB daemon to TCP/IP mode
      final tcpRes = await Process.run(
        adbPath,
        <String>['-s', serial, 'tcpip', port.toString()],
        runInShell: false,
      ).timeout(const Duration(seconds: 5));

      if (tcpRes.exitCode != 0) {
        return AdbWirelessResult(
          success: false,
          ip: ip,
          port: port,
          message: 'Failed to switch to TCP/IP mode: ${tcpRes.stderr.toString().trim()}',
        );
      }

      // Brief delay for the ADB daemon on phone to restart in network mode
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // 3. Connect wirelessly
      final connectRes = await Process.run(
        adbPath,
        <String>['connect', '$ip:$port'],
        runInShell: false,
      ).timeout(const Duration(seconds: 6));

      final connectOut = connectRes.stdout.toString();
      if (connectRes.exitCode == 0 && connectOut.toLowerCase().contains('connected to')) {
        return AdbWirelessResult(
          success: true,
          ip: ip,
          port: port,
          message: 'Connected wirelessly to $ip:$port! You can now unplug the USB cable.',
        );
      } else {
        return AdbWirelessResult(
          success: false,
          ip: ip,
          port: port,
          message: connectOut.isNotEmpty ? connectOut.trim() : 'Connection timed out. Check if PC and phone are on the same Wi-Fi.',
        );
      }
    } catch (e) {
      return AdbWirelessResult(
        success: false,
        message: 'Wireless connection error: $e',
      );
    }
  }

  /// Connects to an Android device directly via IP:Port.
  Future<AdbWirelessResult> connect(
    String adbPath,
    String ip, {
    int port = 5555,
  }) async {
    final cleanIp = ip.trim();
    if (!isValidIpv4(cleanIp)) {
      return const AdbWirelessResult(
        success: false,
        message: 'Invalid IP address format. Example: 192.168.1.100',
      );
    }

    try {
      final res = await Process.run(
        adbPath,
        <String>['connect', '$cleanIp:$port'],
        runInShell: false,
      ).timeout(const Duration(seconds: 6));

      final out = res.stdout.toString();
      final isConnected = res.exitCode == 0 &&
          (out.toLowerCase().contains('connected to') || out.toLowerCase().contains('already connected'));

      return AdbWirelessResult(
        success: isConnected,
        ip: cleanIp,
        port: port,
        message: out.trim(),
      );
    } catch (e) {
      return AdbWirelessResult(
        success: false,
        ip: cleanIp,
        port: port,
        message: 'Connection failed: $e',
      );
    }
  }

  /// Disconnects a wireless Android device.
  Future<bool> disconnect(
    String adbPath,
    String ip, {
    int port = 5555,
  }) async {
    try {
      final target = ip.contains(':') ? ip.trim() : '${ip.trim()}:$port';
      final res = await Process.run(
        adbPath,
        <String>['disconnect', target],
        runInShell: false,
      ).timeout(const Duration(seconds: 5));

      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Pairs an Android 11+ device using the 6-digit wireless pairing code.
  Future<AdbWirelessResult> pair(
    String adbPath,
    String ip,
    int pairPort,
    String pairingCode,
  ) async {
    final cleanIp = ip.trim();
    final cleanCode = pairingCode.trim();

    if (!isValidIpv4(cleanIp)) {
      return const AdbWirelessResult(success: false, message: 'Invalid IP address');
    }
    if (cleanCode.length != 6 || int.tryParse(cleanCode) == null) {
      return const AdbWirelessResult(success: false, message: 'Pairing code must be a 6-digit number');
    }

    try {
      final res = await Process.run(
        adbPath,
        <String>['pair', '$cleanIp:$pairPort', cleanCode],
        runInShell: false,
      ).timeout(const Duration(seconds: 8));

      final out = res.stdout.toString();
      final isPaired = res.exitCode == 0 && out.toLowerCase().contains('successfully paired');

      return AdbWirelessResult(
        success: isPaired,
        ip: cleanIp,
        port: pairPort,
        message: out.trim(),
      );
    } catch (e) {
      return AdbWirelessResult(
        success: false,
        message: 'Pairing failed: $e',
      );
    }
  }

  static bool isValidIpv4(String ip) {
    if (ip.isEmpty || ip.contains(' ')) return false;
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final val = int.tryParse(part);
      if (val == null || val < 0 || val > 255) return false;
    }
    return true;
  }
}
